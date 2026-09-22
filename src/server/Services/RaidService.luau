--!strict
-- RaidService: raiding end to end. The only service that writes the RaidLog
-- section.
--
-- Docs: 02-core-loop.md § Raiding (preconditions, raid sequence, lockpick
-- skill model, theft math), § The Chase, § Raid escort (D101), § Raid log
-- path map (D105), § Tiered raid interaction (tiers 1-7); 06 § Broadcast
-- priority queue (D58); 01 R1 R2 R5 R6; 13-build-guide.md § Part D "The
-- hard part". Josh's calls (step 7): offline bases on free plots, escape =
-- off the victim's plot AND its bridge, escort = one Roblox friend who opts
-- in, one grab takes the whole share.
--
-- The raid: Breach (at the victim's plot; starts the 90 s window) ->
-- Lockpick (server-timed dial, speed not failure) -> Grab (Exposed only) ->
-- the Chase -> Escape. Any player's hit, death, leaving or running out of
-- time sends the loot home.
--
-- WHY NOTHING DUPLICATES (full list: the step 7 plan in the chat log and
-- docs-build/backlog.md):
-- * Nothing moves at grab. The victim is debited only at escape, clamped
--   to what they still have, and the raider gets 80% of what was ACTUALLY
--   taken. A crash, leave or knock-loose before that moves nothing.
-- * One raid per victim at a time: in memory on this server, plus the
--   MemoryStore raid lock for offline raids.
-- * Offline: presence -> lock -> presence again -> read-only view (only if
--   the save is released). At escape the theft is SENT (ProfileStore
--   message) while the lock is still held, THEN the lock becomes "pending"
--   (no second offline raid until the victim's login applies it: review
--   H2), THEN the raider is credited. A login waits while a raid lock
--   exists and applies messages before anything can act.
-- * Victim leaves mid-Chase (review H1): their loot is taken from their
--   still-live save as they leave. Escape pays the raider 80% of that;
--   a failed raid sends it back by message.
-- * Messages carry the raid id; the victim's profile remembers applied ids.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NodeMath = require(ReplicatedStorage.Shared.NodeMath)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local AnomalyLog = require(ServerScriptService.Util.AnomalyLog)
local RaidLock = require(ServerScriptService.Util.RaidLock)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PresenceService = require(script.Parent.PresenceService)
local VaultService = require(script.Parent.VaultService)
local PlotService = require(script.Parent.PlotService)
local DefenseService = require(script.Parent.DefenseService)
local MovementService = require(script.Parent.MovementService)
local CombatService = require(script.Parent.CombatService)
local PickaxeService = require(script.Parent.PickaxeService)
local BroadcastQueue = require(script.Parent.BroadcastQueue)

local OWNER = "RaidService"
local raidCfg = Config.Raiding
local pickCfg = raidCfg.Lockpick
local RAIDING_ATTR = Config.Defenses.RaidingAttribute
local CARRYING_ATTR = Config.Gadgets.CarryingLootAttribute
local MARK_NAME = "RaidCarrierMark"

type Loot = VaultService.Loot
type Raid = {
	id: string,
	raider: Player,
	escort: Player?,
	offered: { [Player]: boolean },
	offerUntil: number,
	victimId: number,
	victimName: string,
	victim: Player?, -- set while the victim is online on THIS server
	offline: boolean, -- offline raid: theft goes by message
	lockHeld: boolean,
	taken: Loot?, -- victim left mid-Chase: what was taken from them as they left
	view: Types.ProfileData?, -- offline: read-only last save
	tier: number,
	plotHitbox: BasePart,
	phase: string, -- "Breached" | "Unlocked" | "Carrying" | "Over"
	endsAt: number,
	pins: number,
	pinsDone: number,
	sweet: number, -- the secret angle for this pin (0..1)
	tolerance: number,
	progress: number, -- 0..1 of the current pin
	holdToken: number, -- newest "stand still while picking" timer
	warmth: number, -- how close the last turn was (0 = lock didn't move)
	lastTurnAt: number,
	loot: Loot?,
	sabotaged: boolean,
	path: { { number } },
	triggers: { { any } },
}

local raids: { [string]: Raid } = {}
local raidOf: { [Player]: Raid } = {} -- raider and escort -> their raid
local raidOnVictim: { [number]: Raid | boolean } = {} -- true = being set up
local breaching: { [Player]: boolean } = {} -- a Breach call is in flight (review H3)
local rng = Random.new()
local logAnomaly = AnomalyLog.new("Raid")

local RaidService = {}

-- ── Step 8 fills these in (Breach Charges, band, shields) ────────────────

-- Can `raider` breach this base? Step 8: Breach Charges held, target in the
-- raider's band (R6, D66), no 48-hour / post-raid shield (D67, D75).
function RaidService.checkBreach(_raider: Player, _base: PlotService.BaseInfo): (boolean, string?)
	return true, nil
end
-- Spends the Breach Charges (step 8). Called once the raid is certain.
function RaidService.consumeBreach(_raider: Player, _base: PlotService.BaseInfo) end

-- ── Small helpers ────────────────────────────────────────────────────────

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

local function coreOf(ownerId: number): BasePart?
	for _, core in CollectionService:GetTagged(Config.Bank.VaultCoreTag) do
		if core:GetAttribute("OwnerUserId") == ownerId and core:IsDescendantOf(workspace) then
			local hitbox = core:FindFirstChild("Hitbox")
			if hitbox and hitbox:IsA("BasePart") then
				return hitbox
			end
		end
	end
	return nil
end

local function describe(loot: Loot): string
	local totals: { [string]: number } = {}
	for resource, grades in loot.Resources do
		for _, amount in grades do
			totals[resource] = (totals[resource] or 0) + amount
		end
	end
	local parts = {}
	for _, resource in Config.Resources.Types do
		if (totals[resource] or 0) > 0 then
			table.insert(parts, `{totals[resource]} {resource}`)
		end
	end
	if loot.Scrap > 0 then
		table.insert(parts, `{loot.Scrap} Scrap`)
	end
	return if #parts > 0 then table.concat(parts, ", ") else "nothing"
end

local function totalsOf(loot: Loot?): { [string]: number }
	local totals: { [string]: number } = {}
	if loot then
		for resource, grades in loot.Resources do
			for _, amount in grades do
				totals[resource] = (totals[resource] or 0) + amount
			end
		end
		if loot.Scrap > 0 then
			totals.Scrap = loot.Scrap
		end
	end
	return totals
end

local function alertVictim(raid: Raid, kind: string, text: string)
	if raid.victim and raid.victim.Parent then
		Remotes.getEvent("BaseAlert"):FireClient(raid.victim, kind, text)
	end
end

-- ── What each side sees ──────────────────────────────────────────────────

local function viewFor(raid: Raid, role: string): Types.RaidView
	local canSabotage = role == "Raider" and not raid.sabotaged and raid.tier >= raidCfg.SabotageMinTier
	return {
		Id = raid.id,
		Role = role,
		Phase = raid.phase,
		EndsAt = raid.endsAt,
		RaiderName = raid.raider.Name,
		VictimName = raid.victimName,
		Lockpick = if role == "Raider" and raid.phase == "Breached"
			then { Pins = raid.pins, PinsDone = raid.pinsDone, Progress = raid.progress, Warmth = raid.warmth }
			else nil,
		Loot = if raid.loot then totalsOf(raid.loot) else nil,
		CanSabotage = canSabotage,
	}
end

local function sendState(raid: Raid)
	local event = Remotes.getEvent("RaidState")
	if raid.raider.Parent then
		event:FireClient(raid.raider, if raid.phase == "Over" then nil else viewFor(raid, "Raider"))
	end
	if raid.escort and raid.escort.Parent then
		event:FireClient(raid.escort, if raid.phase == "Over" then nil else viewFor(raid, "Escort"))
	end
	if raid.victim and raid.victim.Parent then
		event:FireClient(raid.victim, if raid.phase == "Over" then nil else viewFor(raid, "Victim"))
	end
end

-- ── Raid log (D105) ──────────────────────────────────────────────────────

local function logEntry(raid: Raid, outcome: string, taken: Loot?): Types.RaidLogEntry
	return {
		Id = raid.id,
		At = os.time(),
		RaiderName = raid.raider.Name,
		Offline = raid.offline,
		Outcome = outcome,
		Taken = totalsOf(taken),
		Path = raid.path,
		Triggers = raid.triggers,
	}
end

-- Adds an entry (newest first, capped) and remembers the raid id.
local function addEntry(log: { Entries: { Types.RaidLogEntry }, Applied: { string } }, entry: Types.RaidLogEntry)
	table.insert(log.Entries, 1, entry)
	while #log.Entries > raidCfg.LogEntries do
		table.remove(log.Entries)
	end
	table.insert(log.Applied, 1, entry.Id)
	while #log.Applied > raidCfg.AppliedRaidMemory do
		table.remove(log.Applied)
	end
end

-- ── The carrier's look (server-wide marker + trail, 02 § The Chase 4) ────

local function markCarrier(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root then
		return
	end
	local mark = Instance.new("Folder")
	mark.Name = MARK_NAME
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 200, 40)
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3.fromRGB(255, 220, 80)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = mark
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(90, 30)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 2000
	billboard.Adornee = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(150, 110, 20)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "LOOT"
	label.Parent = billboard
	billboard.Parent = mark
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 1, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -1, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 3
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 40))
	trail.LightEmission = 1
	trail.Parent = mark
	mark:SetAttribute("TopAttachment", true)
	mark.Parent = character
	-- Attachments live in the root; remember them to clean up.
	top.Name = MARK_NAME
	bottom.Name = MARK_NAME
end

local function unmarkCarrier(player: Player)
	local character = player.Character
	if not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if descendant.Name == MARK_NAME then
			descendant:Destroy()
		end
	end
end

-- ── Ending a raid ────────────────────────────────────────────────────────

local function releaseParticipant(player: Player?)
	if not player then
		return
	end
	raidOf[player] = nil
	if player.Parent then
		player:SetAttribute(RAIDING_ATTR, nil)
		player:SetAttribute(CARRYING_ATTR, nil)
		MovementService.setEnforced(player, false)
		unmarkCarrier(player)
		local _, humanoid = rootOf(player)
		if humanoid then
			MovementService.setMultiplier(humanoid, "RaidCarry", nil)
			MovementService.setMultiplier(humanoid, "Lockpick", nil)
		end
	end
end

local function cleanup(raid: Raid)
	raid.phase = "Over"
	sendState(raid)
	releaseParticipant(raid.raider)
	releaseParticipant(raid.escort)
	raids[raid.id] = nil
	if raidOnVictim[raid.victimId] == raid then
		raidOnVictim[raid.victimId] = nil
	end
	if raid.plotHitbox.Parent then
		local plot = raid.plotHitbox.Parent :: Instance
		if plot:GetAttribute("RaidId") == raid.id then
			plot:SetAttribute("RaidId", nil)
		end
	end
end

-- The loot goes home (knocked loose, died, left, timed out, cancelled).
-- Nothing was ever taken from the victim, so there's nothing to give back:
-- only the log entry and the lock. Yields for offline raids.
local function failRaid(raid: Raid, outcome: string, text: string)
	-- Once an escape is settling (message in flight), only escape() may
	-- finish the raid: a second path would race it for the lock.
	if raid.phase == "Over" or raid.phase == "Settling" then
		return
	end
	local hadLoot = raid.loot ~= nil
	local takenOnLeave = raid.taken
	cleanup(raid)
	print(`[Raid] {raid.raider.Name} -> {raid.victimName}: {outcome} ({text})`)
	if hadLoot then
		BroadcastQueue.push("ChasePing", `The loot went back to {raid.victimName}'s vault!`)
	end
	alertVictim(raid, "RaidOver", `Raid over: {text}. You lost nothing.`)
	local entry = logEntry(raid, "Recovered", nil)
	if takenOnLeave then
		-- The victim left mid-Chase and we already took the loot from their
		-- save: send it back. If this send fails they lose it (never a dupe).
		task.spawn(function()
			local sent = PlayerDataService.messageAsync(raid.victimId, { Kind = "RaidReturn", RaidId = raid.id, Loot = takenOnLeave, Entry = entry })
			if not sent then
				warn(`[Raid] couldn't return {describe(takenOnLeave)} to {raid.victimName} (raid {raid.id})`)
			end
		end)
	elseif raid.victim and raid.victim.Parent and PlayerDataService.isLoaded(raid.victim) then
		PlayerDataService.update(raid.victim, "RaidLog", OWNER, function(log)
			addEntry(log, entry)
			return log
		end)
	elseif raid.lockHeld then
		-- Offline: a log-only message, then free the lock (not "pending": nothing stolen).
		task.spawn(function()
			PlayerDataService.messageAsync(raid.victimId, { Kind = "RaidLog", RaidId = raid.id, Entry = entry })
			RaidLock.finish(raid.victimId, raid.id, false)
		end)
	end
end

-- The carrier got away. Debit the victim (clamped), credit the raider 80%
-- of what was actually taken. Yields for offline raids.
local function escape(raid: Raid)
	if raid.phase ~= "Carrying" then
		return
	end
	local loot = raid.loot :: Loot
	raid.phase = "Settling" -- no second escape / knock-loose from here on

	local taken: Loot
	if raid.taken then
		-- The victim left mid-Chase: already taken from their save as they left.
		taken = raid.taken
		local entry = logEntry(raid, "Stolen", taken)
		task.spawn(PlayerDataService.messageAsync, raid.victimId, { Kind = "RaidLog", RaidId = raid.id, Entry = entry })
	elseif not raid.offline and raid.victim and raid.victim.Parent and PlayerDataService.isLoaded(raid.victim) then
		-- Online: the victim's profile is live here.
		taken = VaultService.takeLoot(raid.victim, loot)
		local entry = logEntry(raid, "Stolen", taken)
		PlayerDataService.update(raid.victim, "RaidLog", OWNER, function(log)
			addEntry(log, entry)
			return log
		end)
	elseif raid.lockHeld then
		-- Offline: send while still holding the raid lock, THEN mark pending.
		taken = loot
		local entry = logEntry(raid, "Stolen", loot)
		-- Keep the lock alive while the save is in flight (review M1).
		local saving = true
		task.spawn(function()
			while saving do
				task.wait(raidCfg.Lock.KeepAliveSeconds)
				if saving then
					RaidLock.extend(raid.victimId, raid.id)
				end
			end
		end)
		local sent = PlayerDataService.messageAsync(raid.victimId, { Kind = "RaidTheft", RaidId = raid.id, Loot = loot, Entry = entry })
		saving = false
		if not sent then
			raid.phase = "Carrying" -- back out of Settling so failRaid can run
			failRaid(raid, "Failed", "the theft couldn't be saved")
			return
		end
		RaidLock.finish(raid.victimId, raid.id, true) -- "pending" until their login (H2)
	else
		raid.phase = "Carrying"
		failRaid(raid, "Cancelled", "the victim's save wasn't reachable")
		return
	end

	-- Raider gets 80% (02 § Theft math: ~20% destroyed in transit, a sink).
	local keep = 1 - raidCfg.DestroyedInTransit
	local credit: Loot = { Resources = {}, Scrap = math.floor(taken.Scrap * keep) }
	for resource, grades in taken.Resources do
		for grade, amount in grades do
			local share = math.floor(amount * keep)
			if share > 0 then
				credit.Resources[resource] = credit.Resources[resource] or {}
				credit.Resources[resource][grade] = share
			end
		end
	end
	if raid.raider.Parent and PlayerDataService.isLoaded(raid.raider) then
		VaultService.depositLoot(raid.raider, credit)
	end
	print(`[Raid] {raid.raider.Name} escaped from {raid.victimName}: victim lost {describe(taken)}, raider got {describe(credit)}`)
	BroadcastQueue.push("ChasePing", `{raid.raider.Name} escaped with loot from {raid.victimName}'s base!`)
	alertVictim(raid, "RaidLost", `{raid.raider.Name} escaped with {describe(taken)} from your Exposed`)
	cleanup(raid)
end

-- ── Breach ───────────────────────────────────────────────────────────────

local function offerEscort(raid: Raid)
	raid.offerUntil = now() + Config.RaidEscort.OfferSeconds
	for _, other in Players:GetPlayers() do
		if other ~= raid.raider and other.UserId ~= raid.victimId and not raidOf[other] then
			task.spawn(function()
				local ok, friends = pcall(raid.raider.IsFriendsWith, raid.raider, other.UserId)
				-- Studio test players are never Roblox friends: in Studio only,
				-- everyone counts as a friend so the escort can be tested.
				if RunService:IsStudio() then
					ok, friends = true, true
				end
				if ok and friends and raid.phase ~= "Over" then
					raid.offered[other] = true
					Remotes.getEvent("EscortOffer"):FireClient(other, raid.id, raid.raider.Name, Config.RaidEscort.OfferSeconds)
				end
			end)
		end
	end
end

local function startPathSampler(raid: Raid)
	task.spawn(function()
		while raid.phase ~= "Over" and #raid.path < raidCfg.MaxPathPoints do
			local root = rootOf(raid.raider)
			if root and raid.plotHitbox.Parent then
				local localPoint = raid.plotHitbox.CFrame:PointToObjectSpace(root.Position)
				table.insert(raid.path, { math.floor(localPoint.X + 0.5), math.floor(localPoint.Z + 0.5) })
			end
			task.wait(raidCfg.PathSampleSeconds)
		end
	end)
end

local function newPin(raid: Raid)
	raid.sweet = rng:NextNumber(0, 1)
	raid.progress = 0
	raid.warmth = 0
	raid.lastTurnAt = 0
end

local function newLockpick(raid: Raid, bonusPins: number)
	local tierSteps = math.max(0, raid.tier - 1)
	raid.pins = pickCfg.PinsBase + pickCfg.PinsPerTier * tierSteps + pickCfg.LockUpgradeExtraPins * bonusPins
	raid.pinsDone = 0
	raid.tolerance = math.max(pickCfg.MinTolerance, pickCfg.Tolerance + pickCfg.TolerancePerTier * tierSteps)
	newPin(raid)
end

local breachInner: (Player) -> (boolean, string?)

-- One Breach at a time per player: breachInner yields on MemoryStore for
-- offline raids, and a second call must not start a second raid (H3).
local function breach(player: Player): (boolean, string?)
	if breaching[player] then
		return false, "Busy"
	end
	breaching[player] = true
	local ok, allowed, reason = pcall(breachInner, player)
	breaching[player] = nil
	if not ok then
		warn(`[Raid] breach by {player.Name} failed: {allowed}`)
		return false, "Failed"
	end
	return allowed, reason
end

breachInner = function(player: Player): (boolean, string?)
	if raidOf[player] then
		return false, "InRaid"
	end
	local root = rootOf(player)
	if not root then
		return false, "Dead"
	end
	local base = PlotService.baseNear(root.Position, raidCfg.BreachRange)
	if not base then
		return false, "NoBase"
	end
	if base.ownerId == player.UserId then
		return false, "OwnBase"
	end
	if base.tier < 1 or not coreOf(base.ownerId) then
		return false, "NoVault"
	end
	if raidOnVictim[base.ownerId] then
		return false, "AlreadyRaided"
	end
	local allowed, reason = RaidService.checkBreach(player, base)
	if not allowed then
		return false, reason
	end
	raidOnVictim[base.ownerId] = true -- reserve before anything yields

	local raidId = HttpService:GenerateGUID(false)
	local victim = Players:GetPlayerByUserId(base.ownerId)
	local view: Types.ProfileData? = nil
	local lockHeld = false
	if base.offline then
		-- 13 § Part D: presence -> lock -> presence again -> released view.
		local function giveUp(why: string): (boolean, string?)
			if lockHeld then
				task.spawn(RaidLock.finish, base.ownerId, raidId, false)
			end
			raidOnVictim[base.ownerId] = nil
			return false, why
		end
		if PresenceService.getPresence(base.ownerId) ~= "offline" then
			return giveUp("Online")
		end
		lockHeld = RaidLock.acquire(base.ownerId, raidId)
		if not lockHeld then
			return giveUp("Locked") -- another raid, or the 30-min post-raid shield
		end
		if PresenceService.getPresence(base.ownerId) ~= "offline" then
			return giveUp("Online")
		end
		local data, sessionActive = PlayerDataService.viewAsync(base.ownerId)
		if not data or sessionActive then
			return giveUp("Busy")
		end
		view = data
		-- The raider may have moved or died while we waited.
		local stillRoot = rootOf(player)
		if not stillRoot or not player.Parent or NodeMath.distanceToHitbox(base.hitbox, stillRoot.Position) > raidCfg.BreachRange * 2 then
			return giveUp("TooFar")
		end
	elseif not victim then
		raidOnVictim[base.ownerId] = nil
		return false, "NoBase"
	end

	RaidService.consumeBreach(player, base)
	local raid: Raid = {
		id = raidId,
		raider = player,
		escort = nil,
		offered = {},
		offerUntil = 0,
		victimId = base.ownerId,
		victimName = base.ownerName,
		victim = victim,
		offline = base.offline,
		lockHeld = lockHeld,
		taken = nil,
		view = view,
		tier = base.tier,
		plotHitbox = base.hitbox,
		phase = "Breached",
		endsAt = now() + raidCfg.WindowSeconds,
		pins = 0,
		pinsDone = 0,
		sweet = 0,
		tolerance = 0.2,
		progress = 0,
		warmth = 0,
		holdToken = 0,
		lastTurnAt = 0,
		loot = nil,
		sabotaged = false,
		path = {},
		triggers = {},
	}
	raids[raidId] = raid
	raidOf[player] = raid
	raidOnVictim[base.ownerId] = raid
	base.plot:SetAttribute("RaidId", raidId) -- an offline base mid-raid is never evicted
	player:SetAttribute(RAIDING_ATTR, base.ownerId) -- defenses fire at raiders (step 6)
	MovementService.setEnforced(player, true)
	newLockpick(raid, DefenseService.useLockUpgrades(base.ownerId))

	print(`[Raid] {player.Name} breached {base.ownerName}'s base ({if base.offline then "offline" else "online"}, tier {base.tier})`)
	alertVictim(raid, "RaidAlert", `RAID! {player.Name} breached your base`)
	BroadcastQueue.push("RaidAlert", `{player.Name} is raiding {base.ownerName}'s base!`)
	offerEscort(raid)
	startPathSampler(raid)
	sendState(raid)
	task.delay(raidCfg.WindowSeconds, function()
		if raid.phase ~= "Over" and raid.phase ~= "Settling" then
			failRaid(raid, "Timeout", "time ran out")
		end
	end)
	return true, nil
end

-- ── Lockpick: Skyrim-style dial (speed, never fail-locked) ───────────────

local function nearCore(player: Player, raid: Raid): boolean
	local root = rootOf(player)
	local core = coreOf(raid.victimId)
	return root ~= nil and core ~= nil and NodeMath.distanceToHitbox(core, root.Position) <= raidCfg.CoreRange
end

-- The raider holds Turn and sends the pick's angle a few times a second.
-- The lock only moves while the angle is within `tolerance` of this pin's
-- secret sweet angle, fastest dead on it. Time, not luck: at the sweet
-- angle a pin takes SecondsPerPin, which is also the floor no script can
-- beat, so a bot is never faster than a good player.
local function turn(player: Player, angleArg: unknown): (boolean, string?)
	local raid = raidOf[player]
	if not raid or raid.raider ~= player or raid.phase ~= "Breached" then
		return false, "NotPicking"
	end
	if typeof(angleArg) ~= "number" or angleArg ~= angleArg then
		logAnomaly(player, "sent a bad pick angle")
		return false, "Invalid"
	end
	if not nearCore(player, raid) then
		return false, "TooFar"
	end
	local angle = math.clamp(angleArg :: number, 0, 1)
	local t = now()
	-- Both hands on the lock: the raider stands still while working it, and
	-- can move again shortly after they stop (Josh's call, 2026-09-22).
	local _, humanoid = rootOf(player)
	if humanoid then
		MovementService.setMultiplier(humanoid, "Lockpick", 0)
		local hold = raid.holdToken + 1
		raid.holdToken = hold
		task.delay(pickCfg.HoldStillSeconds, function()
			if raid.holdToken == hold then
				local _, stillThere = rootOf(player)
				if stillThere then
					MovementService.setMultiplier(stillThere, "Lockpick", nil)
				end
			end
		end)
	end
	-- First update of a hold (or after a pause) only starts the clock.
	local step = if raid.lastTurnAt > 0 then math.min(t - raid.lastTurnAt, pickCfg.MaxTurnStepSeconds) else 0
	raid.lastTurnAt = t

	local off = math.abs(angle - raid.sweet) / raid.tolerance
	if off >= 1 then
		raid.warmth = 0
		sendState(raid)
		return true, "stuck" -- the lock doesn't budge
	end
	-- Full speed dead on, EdgeRate at the edge of tolerance.
	local rate = pickCfg.EdgeRate + (1 - pickCfg.EdgeRate) * (1 - off)
	raid.warmth = 1 - off
	raid.progress += step * rate / pickCfg.SecondsPerPin
	if raid.progress >= 1 then
		raid.pinsDone += 1
		newPin(raid)
		if raid.pinsDone >= raid.pins then
			raid.phase = "Unlocked"
			raid.holdToken += 1 -- free their feet at once
			local _, freed = rootOf(player)
			if freed then
				MovementService.setMultiplier(freed, "Lockpick", nil)
			end
			alertVictim(raid, "RaidAlert", `{player.Name} picked your vault's lock!`)
		end
	end
	sendState(raid)
	return true, "turning"
end

-- ── Grab + the Chase ─────────────────────────────────────────────────────

-- The whole theft share of Exposed (02 § Theft math), capped by tier.
local function planLoot(raid: Raid): Loot
	local exposed: Types.ResourceStore
	local scrap: number
	if raid.view then
		exposed, scrap = raid.view.Resources.Exposed, raid.view.Scrap.Exposed
	else
		local state = raid.victim and VaultService.getState(raid.victim)
		if not state then
			return { Resources = {}, Scrap = 0 }
		end
		exposed, scrap = state.Exposed, state.ScrapExposed
	end
	local share = if raid.offline then raidCfg.OfflineShare else raidCfg.OnlineShare
	local loot: Loot = { Resources = {}, Scrap = math.floor(scrap * share) }
	local total = 0
	for resource, grades in exposed do
		for grade, count in grades do
			local take = math.floor(count * share)
			if take > 0 then
				loot.Resources[resource] = loot.Resources[resource] or {}
				loot.Resources[resource][grade] = take
				total += take
			end
		end
	end
	local caps = raidCfg.CapByTier
	local cap = caps[math.clamp(raid.tier, 1, #caps)]
	if total > cap then
		local scale = cap / total
		for _, grades in loot.Resources do
			for grade, amount in grades do
				grades[grade] = math.floor(amount * scale)
			end
		end
	end
	return loot
end

local function grab(player: Player): (boolean, string?)
	local raid = raidOf[player]
	if not raid or raid.raider ~= player or raid.phase ~= "Unlocked" then
		return false, "NotReady" -- only the raider grabs, never the escort (D101)
	end
	if not nearCore(player, raid) then
		return false, "TooFar"
	end
	local loot = planLoot(raid)
	if next(loot.Resources) == nil and loot.Scrap == 0 then
		failRaid(raid, "Empty", "their Exposed was empty")
		return true, "Empty"
	end
	raid.loot = loot
	raid.phase = "Carrying"
	local _, humanoid = rootOf(player)
	if humanoid then
		-- 02 § The Chase 1: speed drops sharply; Mobility "Carry speed" softens it.
		local carryRank = PickaxeService.rank(player, "CarrySpeed")
		local perRank = 0
		for _, upgrade in (Config.Combat.Upgrades :: any).Mobility do
			if upgrade.Id == "CarrySpeed" then
				perRank = upgrade.PerRank
			end
		end
		local slow = 1 - (1 - raidCfg.CarrySpeedMultiplier) * math.max(0, 1 - carryRank * perRank)
		MovementService.setMultiplier(humanoid, "RaidCarry", slow)
	end
	player:SetAttribute(CARRYING_ATTR, true) -- 02 § The Chase 2: gadgets off
	markCarrier(player)
	print(`[Raid] {player.Name} grabbed {describe(loot)} from {raid.victimName}`)
	alertVictim(raid, "RaidAlert", `{player.Name} grabbed {describe(loot)}! Hit them to get it back`)
	BroadcastQueue.push("ChasePing", `{player.Name} is escaping with loot from {raid.victimName}'s base! Hit them to knock it loose`)
	sendState(raid)
	return true, nil
end

-- ── Sabotage (tiers 5-7, 02 § Tiered raid interaction) ───────────────────

local function sabotage(player: Player, defenseArg: unknown): (boolean, string?)
	local raid = raidOf[player]
	if not raid or raid.raider ~= player or raid.phase == "Over" or raid.phase == "Settling" then
		return false, "NotRaiding"
	end
	if raid.tier < raidCfg.SabotageMinTier or raid.sabotaged then
		return false, "NoSabotage"
	end
	if typeof(defenseArg) ~= "Instance" or not (defenseArg :: Instance):IsA("Model") then
		logAnomaly(player, "sent a bad sabotage target")
		return false, "Invalid"
	end
	local model = defenseArg :: Model
	if not CollectionService:HasTag(model, Config.Defenses.Tag) or model:GetAttribute("OwnerUserId") ~= raid.victimId then
		return false, "Invalid"
	end
	local hitbox = model:FindFirstChild("Hitbox")
	local root = rootOf(player)
	if not hitbox or not hitbox:IsA("BasePart") or not root or NodeMath.distanceToHitbox(hitbox, root.Position) > raidCfg.SabotageRange then
		return false, "TooFar"
	end
	raid.sabotaged = true
	DefenseService.disable(model, raidCfg.SabotageSeconds)
	sendState(raid)
	return true, nil
end

-- ── Escort (D101) ────────────────────────────────────────────────────────

local function joinEscort(player: Player, raidArg: unknown): (boolean, string?)
	if typeof(raidArg) ~= "string" then
		return false, "Invalid"
	end
	local raid = raids[raidArg :: string]
	if not raid or raid.phase == "Over" or raid.phase == "Settling" or now() > raid.offerUntil then
		return false, "Expired"
	end
	if not raid.offered[player] or raid.escort or raidOf[player] or player.UserId == raid.victimId then
		return false, "NotOffered"
	end
	raid.escort = player
	raidOf[player] = raid
	player:SetAttribute(RAIDING_ATTR, raid.victimId) -- defenses treat them as an intruder
	MovementService.setEnforced(player, true)
	print(`[Raid] {player.Name} is escorting {raid.raider.Name}`)
	sendState(raid)
	return true, nil
end

-- ── Profile messages (offline thefts, 13 § Part D step 4) ────────────────

local function cleanLoot(raw: any): Loot
	local loot: Loot = { Resources = {}, Scrap = 0 }
	if type(raw) ~= "table" then
		return loot
	end
	local isResource: { [string]: boolean } = {}
	for _, name in Config.Resources.Types do
		isResource[name] = true
	end
	if type(raw.Resources) == "table" then
		for resource, grades in raw.Resources do
			if isResource[resource] and type(grades) == "table" then
				for grade, amount in grades do
					if table.find(Config.Grade.Names, grade) and type(amount) == "number" and amount > 0 then
						loot.Resources[resource] = loot.Resources[resource] or {}
						loot.Resources[resource][grade] = math.floor(amount)
					end
				end
			end
		end
	end
	if type(raw.Scrap) == "number" and raw.Scrap > 0 then
		loot.Scrap = math.floor(raw.Scrap)
	end
	return loot
end

local function alreadyApplied(update: PlayerDataService.Update, raidId: string): boolean
	local seen = false
	update("RaidLog", OWNER, function(log)
		seen = table.find(log.Applied, raidId) ~= nil
		return log
	end)
	return seen
end

local function onTheftMessage(player: Player, message: { [string]: any }, update: PlayerDataService.Update): boolean
	local raidId = message.RaidId
	if type(raidId) ~= "string" or type(message.Entry) ~= "table" then
		return true -- malformed: drop it
	end
	if alreadyApplied(update, raidId) then
		return true
	end
	local taken = VaultService.takeLootVia(update, cleanLoot(message.Loot))
	local entry = message.Entry
	entry.Taken = totalsOf(taken)
	update("RaidLog", OWNER, function(log)
		addEntry(log, entry)
		return log
	end)
	print(`[Raid] applied offline raid {raidId} to {player.Name}: lost {describe(taken)}`)
	if PlayerDataService.isLoaded(player) then
		task.defer(VaultService.refresh, player)
	end
	return true
end

-- A raid's loot coming back to a victim who had left mid-Chase (H1).
local function onReturnMessage(player: Player, message: { [string]: any }, update: PlayerDataService.Update): boolean
	local raidId = message.RaidId
	if type(raidId) ~= "string" or type(message.Entry) ~= "table" then
		return true
	end
	if alreadyApplied(update, raidId) then
		return true
	end
	local loot = cleanLoot(message.Loot)
	VaultService.depositLootVia(update, loot)
	update("RaidLog", OWNER, function(log)
		addEntry(log, message.Entry)
		return log
	end)
	print(`[Raid] returned {describe(loot)} to {player.Name} (raid {raidId})`)
	if PlayerDataService.isLoaded(player) then
		task.defer(VaultService.refresh, player)
	end
	return true
end

local function onLogMessage(_player: Player, message: { [string]: any }, update: PlayerDataService.Update): boolean
	if type(message.RaidId) ~= "string" or type(message.Entry) ~= "table" then
		return true
	end
	if not alreadyApplied(update, message.RaidId) then
		update("RaidLog", OWNER, function(log)
			addEntry(log, message.Entry)
			return log
		end)
	end
	return true
end

-- ── Start-up ─────────────────────────────────────────────────────────────

function RaidService.start()
	-- A login waits out a raid in progress; then messages apply first.
	PlayerDataService.setLoadGate(RaidLock.waitUntilNoRaid)
	PlayerDataService.onMessage("RaidTheft", onTheftMessage)
	PlayerDataService.onMessage("RaidLog", onLogMessage)
	PlayerDataService.onMessage("RaidReturn", onReturnMessage)

	-- H1: a victim leaving mid-Chase. Their save is still live here, so take
	-- the loot now; escape() pays the raider from exactly this.
	PlayerDataService.setBeforeRelease(function(player: Player)
		local victimRaid = raidOnVictim[player.UserId]
		if type(victimRaid) ~= "table" then
			return
		end
		local vr = victimRaid :: Raid
		if vr.victim ~= player then
			return
		end
		vr.victim = nil -- no more alerts to them
		if vr.phase == "Carrying" and vr.loot then
			vr.taken = VaultService.takeLoot(player, vr.loot :: Loot)
			print(`[Raid] {player.Name} left mid-Chase: took {describe(vr.taken :: Loot)} from their save; {vr.raider.Name} still has to escape`)
		else
			-- Nothing is at stake before the grab.
			print(`[Raid] {player.Name} left during {vr.phase}: cancelling the raid`)
			failRaid(vr, "Cancelled", `{player.Name} left`)
		end
	end)

	-- 02 § The Chase 5: any player's hit knocks the loot loose, except the
	-- raider's own escort (D101: they're on the raider's side).
	CombatService.Hit:Connect(function(attacker: Player, target: Model)
		for _, raid in raids do
			if raid.phase == "Carrying" and raid.raider.Character == target and attacker ~= raid.raider and attacker ~= raid.escort then
				task.spawn(failRaid, raid, "KnockedLoose", `{attacker.Name} knocked the loot loose`)
			end
		end
	end)

	-- Where defenses fired, for the raid log's path map.
	DefenseService.Triggered:Connect(function(ownerId: number, kind: string, position: Vector3, intruder: Model?)
		local raid = raidOnVictim[ownerId]
		if type(raid) == "table" and raid.phase ~= "Over" and raid.plotHitbox.Parent then
			local participant = intruder == nil or intruder == raid.raider.Character or (raid.escort and intruder == raid.escort.Character)
			if participant then
				local localPoint = raid.plotHitbox.CFrame:PointToObjectSpace(position)
				local point: { any } = { math.floor(localPoint.X + 0.5), math.floor(localPoint.Z + 0.5), kind }
				table.insert(raid.triggers, point)
			end
		end
	end)

	-- Escape check + deaths.
	RunService.Heartbeat:Connect(function()
		for _, raid in raids do
			if raid.phase == "Carrying" then
				local root = rootOf(raid.raider)
				if not root then
					task.spawn(failRaid, raid, "Died", `{raid.raider.Name} went down`)
				elseif not PlotService.isOnBase(raid.victimId, root.Position, raidCfg.Lock.EscapeMarginStuds) then
					task.spawn(escape, raid)
				end
			elseif raid.phase ~= "Over" and raid.phase ~= "Settling" and not rootOf(raid.raider) then
				task.spawn(failRaid, raid, "Died", `{raid.raider.Name} went down`)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		breaching[player] = nil
		local raid = raidOf[player]
		if raid and raid.raider == player then
			task.spawn(failRaid, raid, "Left", `{player.Name} left`)
		elseif raid and raid.escort == player then
			raid.escort = nil
			raidOf[player] = nil
		end
		-- A victim leaving is handled in setBeforeRelease above, while their
		-- profile is still live (H1). If that never ran (no profile loaded),
		-- there was nothing to take, so cancel.
		local victimRaid = raidOnVictim[player.UserId]
		if type(victimRaid) == "table" and (victimRaid :: Raid).victim == player then
			local vr = victimRaid :: Raid
			vr.victim = nil
			-- The hook didn't run (see the [PlayerData] line above). Their
			-- profile may still be live for a moment: try to settle anyway.
			if vr.phase == "Carrying" and vr.loot and PlayerDataService.isLoaded(player) then
				vr.taken = VaultService.takeLoot(player, vr.loot :: Loot)
				warn(`[Raid] {player.Name} left mid-Chase; the hook didn't run, took {describe(vr.taken :: Loot)} in the fallback`)
			else
				warn(`[Raid] {player.Name} left ({vr.phase}) and nothing could be taken: cancelling`)
				task.spawn(failRaid, vr, "Cancelled", `{player.Name} left`)
			end
		end
	end)

	local allow = RateLimiter.new("Raid", raidCfg.RequestCooldownSeconds)
	local function guarded(handler: (Player, ...any) -> (boolean, string?))
		return function(player: Player, ...: any): (boolean, string?)
			if not allow(player) then
				return false, "Busy"
			end
			return handler(player, ...)
		end
	end
	Remotes.getFunction("Breach").OnServerInvoke = guarded(breach)
	Remotes.getFunction("Grab").OnServerInvoke = guarded(grab)
	Remotes.getFunction("Sabotage").OnServerInvoke = guarded(sabotage)
	Remotes.getFunction("JoinEscort").OnServerInvoke = guarded(joinEscort)
	-- Turn updates stream while the button is held: their own, looser limit.
	local allowTurn = RateLimiter.newBucket("LockpickTurn", 20, 15)
	Remotes.getFunction("LockpickTurn").OnServerInvoke = function(player: Player, angle: unknown): (boolean, string?)
		if not allowTurn(player) then
			return false, "Busy"
		end
		return turn(player, angle)
	end
	local allowLog = RateLimiter.new("GetRaidLog", Config.Bank.SnapshotCooldownSeconds)
	Remotes.getFunction("GetRaidLog").OnServerInvoke = function(player: Player): { Types.RaidLogEntry }?
		if not allowLog(player) then
			return nil
		end
		local log = PlayerDataService.get(player, "RaidLog")
		return if log then log.Entries else nil
	end
	PlayerDataService.Loaded:Connect(function(player: Player)
		-- Their pending thefts are applied by now (before Loaded): they can
		-- be raided offline again next time they're away (H2).
		task.spawn(RaidLock.clearPending, player.UserId)
		if raidCfg.Ui.ShowBeforeFtue then
			player:SetAttribute(raidCfg.Ui.RaidLogVisibleAttribute, true)
		end
	end)
end

return RaidService
