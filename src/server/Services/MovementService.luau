--!strict
-- MovementService: the only code that sets a Humanoid's WalkSpeed and
-- JumpPower on the server. Every effect (Sprint Serum, Shock Trap stun, and
-- in step 7 the Chase loot slow and carry-speed upgrade) registers a
-- modifier here instead of writing WalkSpeed itself, so effects stack
-- predictably and never overwrite each other.
--
-- Docs: 02-core-loop.md § Gadgets, § The Chase (loot slow, step 7).
-- It also owns movement trust (REWORK §14 R1-00, backlog M1): the server's
-- check that a player really could have moved where they are, and
-- isPositionTrusted(player), which every position-based action asks.
--
-- Works for players and NPCs (Scavs, step 6): an NPC's base speed is
-- whatever its WalkSpeed was when first touched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local AnomalyLog = require(ServerScriptService.Util.AnomalyLog)
local PickaxeService = require(script.Parent.PickaxeService)

type State = {
	baseSpeed: number,
	baseJump: number,
	multipliers: { [string]: number? },
	tokens: { [string]: number }, -- bumps so an old timer can't end a refreshed effect
	stunUntil: number,
	stunToken: number,
}

local states: { [Humanoid]: State } = {}

local MovementService = {}

-- Movement trust (below) caps a stunned player's saved-up distance.
local onStunned: (humanoid: Humanoid) -> ()

local function stateOf(humanoid: Humanoid): State
	local existing = states[humanoid]
	if existing then
		return existing
	end
	local isPlayer = Players:GetPlayerFromCharacter(humanoid.Parent) ~= nil
	local state: State = {
		baseSpeed = if isPlayer then Config.Movement.BaseWalkSpeed else humanoid.WalkSpeed,
		baseJump = if isPlayer then Config.Movement.BaseJumpPower else humanoid.JumpPower,
		multipliers = {},
		tokens = {},
		stunUntil = 0,
		stunToken = 0,
	}
	states[humanoid] = state
	humanoid.Destroying:Connect(function()
		states[humanoid] = nil
	end)
	return state
end

local function apply(humanoid: Humanoid)
	local state = stateOf(humanoid)
	if os.clock() < state.stunUntil then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		return
	end
	local speed = state.baseSpeed
	for _, multiplier in state.multipliers do
		speed *= multiplier :: number
	end
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = state.baseJump
end

-- Sets (or with nil, clears) a named speed multiplier.
function MovementService.setMultiplier(humanoid: Humanoid, key: string, multiplier: number?)
	local state = stateOf(humanoid)
	state.multipliers[key] = multiplier
	state.tokens[key] = (state.tokens[key] or 0) + 1
	apply(humanoid)
end

-- How much of a stun/slow to cut for this humanoid: a player's Mobility
-- "Stun recovery" ranks (Josh's call, 2026-09-21). NPCs get none.
local function recoveryOf(humanoid: Humanoid): number
	local player = Players:GetPlayerFromCharacter(humanoid.Parent)
	return if player then PickaxeService.stunRecovery(player) else 0
end

-- A slowing multiplier (below 1), softened by Stun recovery. nil clears it.
function MovementService.setSlow(humanoid: Humanoid, key: string, multiplier: number?)
	if multiplier == nil then
		MovementService.setMultiplier(humanoid, key, nil)
		return
	end
	local recovery = recoveryOf(humanoid)
	MovementService.setMultiplier(humanoid, key, 1 - (1 - multiplier) * (1 - recovery))
end

-- A multiplier that ends by itself. Using it again refreshes the duration.
function MovementService.setMultiplierFor(humanoid: Humanoid, key: string, multiplier: number, seconds: number)
	MovementService.setMultiplier(humanoid, key, multiplier)
	local state = stateOf(humanoid)
	local token = state.tokens[key]
	task.delay(seconds, function()
		if states[humanoid] == state and state.tokens[key] == token then
			MovementService.setMultiplier(humanoid, key, nil)
		end
	end)
end

-- No walking or jumping for `seconds` (shortened by Stun recovery). A
-- longer stun already running wins.
function MovementService.stun(humanoid: Humanoid, seconds: number)
	seconds *= 1 - recoveryOf(humanoid)
	local state = stateOf(humanoid)
	state.stunUntil = math.max(state.stunUntil, os.clock() + seconds)
	state.stunToken += 1
	local token = state.stunToken
	apply(humanoid)
	onStunned(humanoid)
	task.delay(seconds, function()
		if states[humanoid] == state and state.stunToken == token then
			apply(humanoid)
		end
	end)
end

function MovementService.isStunned(humanoid: Humanoid): boolean
	local state = states[humanoid]
	return state ~= nil and os.clock() < state.stunUntil
end

-- ── Movement trust (REWORK §14 R1-00; backlog M1; 13-build-guide.md
-- § Anti-exploit baseline) ───────────────────────────────────────────────
-- Each client moves its own character, so an exploiter can speed, teleport,
-- fly or walk through walls. The server samples every player's position
-- and checks each move since the last sample:
--   * Speed: a distance budget. Time earns WalkSpeed x tolerance, movement
--     spends it, and unspent budget carries over up to a burst plus a
--     little lag, so laggy updates pass while a speed hack runs dry. The
--     WalkSpeed is the server's own, the fastest in the last round trip, so
--     a stun or slow the client hasn't heard about yet isn't a fail. Raid
--     participants are held tighter (review 2026-09-22 #6/#8).
--   * Rise: in the air, height must stay under a real jump arc (the
--     server's jump power and gravity). Flying, hovering and a low-gravity
--     glide over a void all fail. Falling is never limited.
--   * Walls: moving through a wall taller than the player could have
--     jumped over, with no way around it.
-- A failed move is snapped back to the last spot they stood on, and they
-- stay untrusted for a few seconds (REWORK §18: everyone is snapped back,
-- with looser numbers outside a raid; EnforceOutsideRaid = false turns
-- that back into log-only). Timings that depend on a late client add a
-- round trip (2 x ping), so phones don't trip it.

local logMovement = AnomalyLog.new("Movement")
local moveCfg = Config.Raiding.Movement

type Sample = { at: number, position: Vector3 }
type SpeedSample = { at: number, walk: number, jump: number }
type Track = {
	root: BasePart,
	lastPosition: Vector3,
	lastAt: number,
	movedAt: number, -- when lastPosition was first seen (a stalled client's updates bunch up)
	budget: number, -- studs they may still move
	push: number, -- extra studs from a knockback (expectPush), never more than the biggest one
	pushHoldUntil: number,
	pushGranted: number, -- the biggest recent knockback, for isPositionTrusted's window
	speeds: { SpeedSample }, -- the server's WalkSpeed / jump speed, recent
	samples: { Sample }, -- accepted positions, recent (isPositionTrusted)
	groundedAt: number, -- last sample standing on something
	groundedPosition: Vector3,
	airAt: number?, -- first sample in the air since then: the jump was in between
	airPosition: Vector3?,
	safe: CFrame, -- last accepted spot standing on something: where a failed move goes back to
	untrustedUntil: number,
	settleUntil: number, -- after a snap-back or server move, late client updates are ignored
	settleAt: CFrame?,
	settleSlack: number,
	settleStartedAt: number,
	settleFromFail: boolean, -- a snap-back (movement during it is charged), not a server teleport
}

local tracks: { [Player]: Track } = {}
local enforced: { [Player]: boolean? } = {}
local spawning: { [Player]: Model? } = {} -- character not placed yet: don't judge it

-- The world and placed base pieces: what counts as a wall.
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include
wallParams.RespectCanCollide = true
-- Anything solid but the player: ground, nodes, other players, Scavs.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true

local function flat(v: Vector3): number
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

local function bodyOf(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character or not character:IsDescendantOf(workspace) then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, root, humanoid
end

-- A round trip to this player's client, capped.
local function roundTrip(player: Player): number
	return 2 * math.clamp(player:GetNetworkPing(), 0, moveCfg.MaxPingSeconds)
end

-- Take-off speed of a jump, from the server's values (a client that
-- changes its own JumpPower changes nothing here).
local function jumpSpeedOf(humanoid: Humanoid): number
	if humanoid.UseJumpPower then
		return humanoid.JumpPower
	end
	return math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight)
end

local function rootToFeet(humanoid: Humanoid, root: BasePart): number
	return humanoid.HipHeight + root.Size.Y / 2
end

-- Standing on anything solid (ground, a node, another player, a seat)? A
-- box the root's width, so a heel over a ledge still counts.
local function standing(character: Model, root: BasePart, humanoid: Humanoid): boolean
	if humanoid.SeatPart then
		return true
	end
	groundParams.FilterDescendantsInstances = { character }
	local width = math.max(root.Size.X, root.Size.Z)
	local reach = rootToFeet(humanoid, root) + moveCfg.GroundProbeSlack
	local hit = workspace:Blockcast(CFrame.new(root.Position), Vector3.new(width, 0.2, width), Vector3.new(0, -reach, 0), groundParams)
	return hit ~= nil
end

-- Nothing solid and fixed between a and b.
local function clear(a: Vector3, b: Vector3): boolean
	local hit = workspace:Raycast(a, b - a, wallParams)
	return hit == nil or not hit.Instance.Anchored
end

-- Could they have walked from a to b? Straight, or around something on
-- either side (a fast turn past a corner cuts it between two samples).
local function walkable(a: Vector3, b: Vector3): boolean
	if clear(a, b) then
		return true
	end
	local offset = b - a
	local side = Vector3.new(-offset.Z, 0, offset.X) / 2
	local middle = (a + b) / 2
	for _, sign in { 1, -1 } do
		local via = middle + side * sign
		if clear(a, via) and clear(via, b) then
			return true
		end
	end
	return false
end

local function newTrack(root: BasePart, at: CFrame, now: number): Track
	return {
		root = root,
		lastPosition = at.Position,
		lastAt = now,
		movedAt = now,
		budget = moveCfg.BurstStuds,
		push = 0,
		pushHoldUntil = 0,
		pushGranted = 0,
		speeds = {},
		samples = { { at = now, position = at.Position } },
		groundedAt = now,
		groundedPosition = at.Position,
		airAt = nil,
		airPosition = nil,
		safe = at,
		untrustedUntil = 0,
		settleUntil = 0,
		settleAt = nil,
		settleSlack = 0,
		settleStartedAt = 0,
		settleFromFail = false,
	}
end

-- A fresh start from `position` (after a settle), keeping how long they
-- stay untrusted. `safe` is the spot they were put on.
local function rebase(track: Track, position: Vector3, safe: CFrame, now: number)
	track.lastPosition = position
	track.lastAt = now
	track.movedAt = now
	track.budget = moveCfg.BurstStuds
	track.samples = { { at = now, position = position } }
	track.groundedAt = now
	track.groundedPosition = safe.Position
	track.airAt = nil
	track.airPosition = nil
	track.safe = safe
end

-- Records the server's current speeds and returns the fastest WalkSpeed
-- and jump speed of the last SpeedHistorySeconds + a round trip. The
-- oldest entry is kept while it was still in force at the window's start.
local function recentSpeeds(track: Track, humanoid: Humanoid, now: number, rtt: number): (number, number)
	local speeds = track.speeds
	table.insert(speeds, { at = now, walk = humanoid.WalkSpeed, jump = jumpSpeedOf(humanoid) })
	local since = now - moveCfg.SpeedHistorySeconds - rtt
	while #speeds > 1 and speeds[2].at <= since do
		table.remove(speeds, 1)
	end
	local walk, jump = 0, 0
	for _, sample in speeds do
		walk = math.max(walk, sample.walk)
		jump = math.max(jump, sample.jump)
	end
	return walk, jump
end

-- Ignore client updates until the client has had time to hear about a
-- move the server made (snap-back or teleport) to `at`.
local function settle(player: Player, track: Track, at: CFrame, now: number, walk: number, fromFail: boolean)
	local seconds = math.clamp(roundTrip(player) + moveCfg.SettleExtraSeconds, moveCfg.SettleMinSeconds, moveCfg.SettleMaxSeconds)
	track.settleUntil = now + seconds
	track.settleAt = at
	track.settleSlack = moveCfg.SettleStuds + walk * moveCfg.SpeedTolerance * seconds
	track.settleStartedAt = now
	track.settleFromFail = fromFail
end

local function fail(player: Player, track: Track, character: Model, now: number, walk: number, reason: string, detail: string, teleport: boolean): boolean
	logMovement(player, reason, detail)
	if RunService:IsStudio() then
		print(`[Movement] {player.Name} {reason} ({detail})`) -- every one; the anomaly log is throttled
	end
	local untrusted = if teleport then moveCfg.TeleportUntrustedSeconds else moveCfg.UntrustedSeconds
	track.untrustedUntil = math.max(track.untrustedUntil, now + untrusted)
	if enforced[player] or moveCfg.EnforceOutsideRaid then
		character:PivotTo(track.safe)
		track.root.AssemblyLinearVelocity = Vector3.zero
		settle(player, track, track.safe, now, walk, true)
	else
		-- Log-only fallback: where they are becomes the new baseline.
		local here = track.root.CFrame
		rebase(track, here.Position, here, now)
	end
	return false
end

-- Checks one player's move since their last check. False = it was
-- impossible (and they were snapped back), or a snap-back is still
-- settling. True for a player with no live character (nothing to judge).
local function checkPlayer(player: Player, now: number): boolean
	local character, root, humanoid = bodyOf(player)
	if not character or not root or not humanoid then
		tracks[player] = nil
		return true
	end
	if spawning[player] == character then
		return true
	end
	local track = tracks[player]
	if not track or track.root ~= root then
		tracks[player] = newTrack(root, root.CFrame, now)
		return true
	end

	local rtt = roundTrip(player)
	local walk, jump = recentSpeeds(track, humanoid, now, rtt)
	if now < track.settleUntil then
		return false
	end
	local settleAt = track.settleAt
	if settleAt then
		track.settleAt = nil
		local away = flat(root.Position - settleAt.Position)
		if away > track.settleSlack + track.push then
			return fail(player, track, character, now, walk, "ignored a snap-back", `{math.floor(away)} studs away`, false)
		end
		if not track.settleFromFail then
			-- The server put them here (spawn, teleport): start fresh.
			rebase(track, root.Position, settleAt, now)
			return true
		end
		-- After a snap-back, movement during the settle is paid for from an
		-- empty budget (review 2026-09-25 #2): otherwise every fail -> snap ->
		-- settle cycle would hand out free distance and a fresh burst.
		rebase(track, settleAt.Position, settleAt, track.settleStartedAt)
		track.budget = 0
	end

	local dt = now - track.lastAt
	local from = track.lastPosition
	local position = root.Position
	local moved = flat(position - from)

	-- Speed: the distance budget. Knockback allowance is spent first.
	local strict = enforced[player] == true
	local rate = walk * (if strict then moveCfg.EnforcedSpeedTolerance else moveCfg.SpeedTolerance)
	local cap = moveCfg.BurstStuds + rate * (if strict then moveCfg.LagAllowanceSeconds else moveCfg.NormalLagSeconds)
	track.budget = math.min(cap, track.budget + rate * dt)
	if now >= track.pushHoldUntil then
		track.push = math.max(0, track.push - moveCfg.PushDecayPerSecond * dt)
	end
	local fromPush = math.min(track.push, moved)
	track.push -= fromPush
	track.budget -= moved - fromPush
	if track.budget < 0 then
		track.budget = 0
		local teleport = moved > math.max(moveCfg.TeleportStuds, rate * moveCfg.TeleportRateSeconds)
		local detail = `{math.floor(moved)} studs in {math.floor(dt * 100) / 100} s`
		return fail(player, track, character, now, walk, if teleport then "teleported" else "moved faster than possible", detail, teleport)
	end

	-- Rise: the jump started somewhere between the last sample on the
	-- ground and the first in the air, and positions may arrive late, so
	-- allow the highest point of any jump in that window.
	local gravity = workspace.Gravity
	local late = moveCfg.RiseLagSeconds + rtt
	-- Walking up a slope since the last ground sample, no further than
	-- walking could have gone in that time (saved budget doesn't buy height).
	local function climbTo(point: Vector3): number
		local walked = math.min(flat(point - track.groundedPosition), rate * (now - track.groundedAt + late))
		return walked * moveCfg.ClimbRatio
	end
	local onGround = standing(character, root, humanoid)
	if onGround then
		track.airAt = nil
		track.airPosition = nil
		-- Landing somewhere high is a rise too (review 2026-09-25 #3): no
		-- higher than a full jump from the last ground, plus the climb.
		local apex = if gravity > 0 then jump * jump / (2 * gravity) else math.huge
		local ceiling = track.groundedPosition.Y + climbTo(position) + apex + moveCfg.RiseSlackStuds
		if position.Y > ceiling then
			local detail = `{math.floor(position.Y - track.groundedPosition.Y)} studs up, landed`
			return fail(player, track, character, now, walk, "rose higher than a jump", detail, false)
		end
	else
		local airAt = track.airAt or now
		local airPosition = track.airPosition or position
		track.airAt = airAt
		track.airPosition = airPosition
		local earliest = math.max(0, now - airAt - late)
		local latest = now - track.groundedAt + late
		local apexTime = if gravity > 0 then jump / gravity else latest
		local t = math.clamp(apexTime, earliest, latest)
		local rise = jump * t - gravity * t * t / 2
		-- Walking up a slope between the last ground sample and the jump.
		local ceiling = track.groundedPosition.Y + climbTo(airPosition) + rise + moveCfg.RiseSlackStuds
		if position.Y > ceiling then
			local detail = `{math.floor(position.Y - track.groundedPosition.Y)} studs up`
			return fail(player, track, character, now, walk, "rose higher than a jump", detail, false)
		end
	end

	-- Walls: blocked straight and around, and too tall for the highest
	-- their feet could have been in between (a jump arc over the time
	-- since `from` was first seen, a round trip and late positions).
	if moved > 0 and not humanoid.SeatPart and not walkable(from, position) then
		local window = now - track.movedAt + rtt + moveCfg.RiseLagSeconds
		local apex = if gravity > 0 then jump * jump / (2 * gravity) else math.huge
		local lift = math.min(apex, gravity * window * window / 8) + moveCfg.StepSlackStuds
		local feetY = math.max(from.Y, position.Y) - rootToFeet(humanoid, root) + lift
		if not clear(Vector3.new(from.X, feetY, from.Z), Vector3.new(position.X, feetY, position.Z)) then
			return fail(player, track, character, now, walk, "walked through a wall", `{math.floor(moved)} studs`, false)
		end
	end

	if onGround then
		track.groundedAt = now
		track.groundedPosition = position
		track.safe = root.CFrame
	end
	if position ~= from then
		track.movedAt = now
	end
	track.lastPosition = position
	track.lastAt = now
	local samples = track.samples
	table.insert(samples, { at = now, position = position })
	local since = now - moveCfg.TrustWindowSeconds
	while #samples > 1 and samples[2].at <= since do
		table.remove(samples, 1)
	end
	return true
end

-- Raid participants (raider, escort) are held to the strict numbers.
function MovementService.setEnforced(player: Player, on: boolean)
	enforced[player] = if on then true else nil
end

-- Call just before the server moves a player on purpose (respawn, script
-- teleport), with where they're going. Their client's updates from before
-- the move are ignored until it has heard about it.
function MovementService.expectTeleport(player: Player, destination: CFrame)
	local _, root, humanoid = bodyOf(player)
	if not root or not humanoid then
		tracks[player] = nil
		return
	end
	local now = os.clock()
	local old = tracks[player]
	local track = newTrack(root, destination, now)
	if old and old.root == root then
		track.untrustedUntil = old.untrustedUntil
	end
	tracks[player] = track
	spawning[player] = nil
	settle(player, track, destination, now, humanoid.WalkSpeed, false)
end

-- The server is about to push this player `studs` (knockback): extra
-- allowance, held until their client can have felt it, then draining.
-- Knockbacks don't add up (review 2026-09-25 #1): a player who cancels the
-- push on their own client would otherwise bank a long blink from repeated
-- hits (an escort hitting their carrier costs no grip).
function MovementService.expectPush(player: Player, studs: number)
	local track = tracks[player]
	if track then
		local now = os.clock()
		if now >= track.pushHoldUntil + moveCfg.TrustWindowSeconds + moveCfg.CheckSeconds then
			track.pushGranted = 0
		end
		track.push = math.max(track.push, studs)
		track.pushGranted = math.max(track.pushGranted, studs)
		track.pushHoldUntil = now + roundTrip(player) + moveCfg.PushHoldSeconds
	end
end

-- A stun reaches the client a round trip later; after that, saved-up
-- distance can't be spent walking through it (review 2026-09-25 #5).
onStunned = function(humanoid: Humanoid)
	local player = Players:GetPlayerFromCharacter(humanoid.Parent)
	if not player then
		return
	end
	task.delay(roundTrip(player), function()
		local track = tracks[player]
		if track and MovementService.isStunned(humanoid) then
			track.budget = math.min(track.budget, moveCfg.BurstStuds)
		end
	end)
end

-- Studio only: says why an action was refused, so a tester can tell a
-- real catch from a false one (the anomaly log above is throttled).
local function refused(player: Player, why: string): boolean
	if RunService:IsStudio() then
		print(`[MovementTrust] {player.Name} refused: {why}`)
	end
	return false
end

-- The question every position-based action asks first (mining, lockpick,
-- grabs, escapes, hits, breach, sabotage, placed gadgets; later pedestals,
-- camp grabs and bounty hits). Checks the move since the last sample right
-- now, so "teleport, act" in between samples fails. False while dead, just
-- snapped back or untrusted, or when the last TrustWindowSeconds covered
-- more ground than walking (plus a recent knockback) could (a blink paid
-- for with saved-up budget; refused, not punished, so a lag burst only
-- delays the action). When true, their HumanoidRootPart's position is one
-- the server accepted.

function MovementService.isPositionTrusted(player: Player): boolean
	local _, root = bodyOf(player)
	if not root then
		return false
	end
	local now = os.clock()
	if not checkPlayer(player, now) then
		local track = tracks[player]
		return refused(player, if track and now < track.settleUntil then "settling after a snap-back" else "this move failed the check")
	end
	local track = tracks[player]
	if not track or track.root ~= root then
		return refused(player, `new character not placed yet (spawning: {spawning[player] ~= nil})`)
	end
	if now < track.untrustedUntil then
		return refused(player, `untrusted for {math.floor((track.untrustedUntil - now) * 10) / 10} s more`)
	end
	local oldest = track.samples[1]
	local walk = 0
	for _, sample in track.speeds do
		walk = math.max(walk, sample.walk)
	end
	local allowed = moveCfg.TrustSlackStuds + walk * moveCfg.EnforcedSpeedTolerance * (now - oldest.at)
	-- A knockback moved them (the oldest sample can be a check older than
	-- the window): allow that one push, not a free pass.
	if now < track.pushHoldUntil + moveCfg.TrustWindowSeconds + moveCfg.CheckSeconds then
		allowed += track.pushGranted
	end
	local moved = flat(root.Position - oldest.position)
	if moved > allowed then
		return refused(player, `moved {math.floor(moved)} studs in {math.floor((now - oldest.at) * 100) / 100} s (allowed {math.floor(allowed)})`)
	end
	return true
end

-- Standing on something solid, judged by the server (a client's own
-- Humanoid.FloorMaterial is whatever it says).
function MovementService.isGrounded(player: Player): boolean
	local character, root, humanoid = bodyOf(player)
	return character ~= nil and root ~= nil and humanoid ~= nil and standing(character, root, humanoid)
end

function MovementService.start()
	local function refreshWalls()
		local include: { Instance } = {}
		for _, name in { Config.World.FolderName, Config.Base.LiveFolderName } do
			local folder = workspace:FindFirstChild(name)
			if folder then
				table.insert(include, folder)
			end
		end
		wallParams.FilterDescendantsInstances = include
	end
	refreshWalls()
	workspace.ChildAdded:Connect(refreshWalls) -- BasePieces is created by PlotService

	-- A new character is judged from where the server placed it, one frame
	-- after it enters the world, never from where its client first says.
	local function onCharacter(player: Player, character: Model)
		spawning[player] = character
		if not character:IsDescendantOf(workspace) then
			character.AncestryChanged:Wait()
		end
		RunService.Heartbeat:Wait()
		if spawning[player] ~= character then
			return -- expectTeleport already placed them
		end
		spawning[player] = nil
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and player.Character == character then
			local now = os.clock()
			local track = newTrack(root, root.CFrame, now)
			tracks[player] = track
			settle(player, track, root.CFrame, now, Config.Movement.BaseWalkSpeed, false)
		end
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= moveCfg.CheckSeconds then
			elapsed = 0
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				checkPlayer(player, now)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
		enforced[player] = nil
		spawning[player] = nil
	end)
end

return MovementService
