--!strict
-- MovementService: the only code that sets a Humanoid's WalkSpeed and
-- JumpPower on the server. Every effect (Sprint Serum, Shock Trap stun, and
-- in step 7 the Chase loot slow and carry-speed upgrade) registers a
-- modifier here instead of writing WalkSpeed itself, so effects stack
-- predictably and never overwrite each other.
--
-- Docs: 02-core-loop.md § Gadgets, § The Chase (loot slow, step 7).
-- The server-side movement / teleport check (docs-build/backlog.md M1, due
-- by step 7) belongs here too.
--
-- Works for players and NPCs (Scavs, step 6): an NPC's base speed is
-- whatever its WalkSpeed was when first touched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
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
	task.delay(seconds, function()
		if states[humanoid] == state and state.stunToken == token then
			apply(humanoid)
		end
	end)
end

-- ── Movement check (backlog M1; 13-build-guide.md § Anti-exploit baseline)
-- Each client moves its own character, so an exploiter can teleport. The
-- server samples every player's position; a horizontal jump bigger than
-- their WalkSpeed allows (plus a burst for knockback/lag) is logged.
-- Players in a raid (`enforce`) are also snapped back to their last good
-- spot: that's where a teleport would steal. They're held to their real
-- server WalkSpeed (the carry slow included), and the burst is an allowance
-- that refills slowly rather than slack on every sample (review 2026-09-22
-- #6/#8). Everyone else is only logged, so a lag spike never punishes
-- normal play.

local AnomalyLog = require(game:GetService("ServerScriptService").Util.AnomalyLog)
local logMovement = AnomalyLog.new("Movement")
local moveCfg = Config.Raiding.Movement

type Track = { root: BasePart, lastGood: CFrame, lastPosition: Vector3, lastAt: number, burst: number }
local tracks: { [Player]: Track } = {}
local enforced: { [Player]: boolean? } = {}

-- Snap this player back on impossible moves while true (raid participants).
function MovementService.setEnforced(player: Player, on: boolean)
	enforced[player] = if on then true else nil
end

-- Call after moving a player on purpose (respawn, script teleport).
function MovementService.expectTeleport(player: Player)
	tracks[player] = nil
end

-- Checks one player's move since their last check. Returns false if it
-- was impossible (and, for enforced players, they were snapped back).
local function checkPlayer(player: Player, now: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		tracks[player] = nil
		return true
	end
	local track = tracks[player]
	if not track or track.root ~= root then
		tracks[player] = { root = root, lastGood = root.CFrame, lastPosition = root.Position, lastAt = now, burst = moveCfg.BurstStuds }
		return true
	end
	local dt = now - track.lastAt
	track.lastAt = now
	local delta = root.Position - track.lastPosition
	local moved = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local ok: boolean
	if enforced[player] then
		-- A distance budget: time earns WalkSpeed x tolerance, movement
		-- spends it. Unspent allowance carries over (up to a burst plus
		-- LagAllowanceSeconds of walking), so positions that arrive in
		-- laggy bursts pass, while any sustained speed above the real
		-- WalkSpeed runs it dry.
		local rate = humanoid.WalkSpeed * moveCfg.EnforcedSpeedTolerance
		local cap = moveCfg.BurstStuds + rate * moveCfg.LagAllowanceSeconds
		if track.burst > cap then
			-- Left over from a knockback (expectPush): gone within a second.
			track.burst = math.max(cap, track.burst - moveCfg.PushDecayPerSecond * dt)
		else
			track.burst = math.min(cap, track.burst + rate * dt)
		end
		track.burst -= moved
		ok = track.burst >= 0
		if not ok then
			track.burst = 0
		end
	else
		local allowed = math.max(humanoid.WalkSpeed, Config.Movement.BaseWalkSpeed) * moveCfg.SpeedTolerance * dt
			+ moveCfg.BurstStuds
		ok = moved <= allowed
	end
	if not ok then
		logMovement(player, "moved faster than possible", `{math.floor(moved)} studs in {math.floor(dt * 100) / 100} s`)
		if enforced[player] then
			character:PivotTo(track.lastGood)
			track.lastPosition = track.lastGood.Position
			return false
		end
	end
	track.lastGood = root.CFrame
	track.lastPosition = root.Position
	return ok
end

-- The server is about to push this player `studs` (knockback): add it to
-- their burst allowance so the push isn't read as a speed hack.
function MovementService.expectPush(player: Player, studs: number)
	local track = tracks[player]
	if track then
		track.burst = math.max(track.burst, 0) + studs
	end
end

-- Checks this player's position right now. RaidService calls it before
-- deciding a carrier has escaped, so an escape is only ever judged on a
-- position the server accepted (review 2026-09-22 #6). False = the move
-- was impossible and (if enforced) undone.
function MovementService.checkNow(player: Player): boolean
	return checkPlayer(player, os.clock())
end

function MovementService.start()
	local elapsed = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
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
	end)
end

function MovementService.isStunned(humanoid: Humanoid): boolean
	local state = states[humanoid]
	return state ~= nil and os.clock() < state.stunUntil
end

return MovementService
