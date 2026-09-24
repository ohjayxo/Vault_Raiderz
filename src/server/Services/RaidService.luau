--!strict
-- RaidService: raiding end to end. The only service that writes the RaidLog
-- section.
--
-- Docs: 02-core-loop.md § Raiding (preconditions, raid sequence, lockpick
-- skill model, theft math), § The Chase, § Raid escort (D101), § Raid log
-- path map (D105), § Tiered raid interaction (tiers 1-7); 06 § Broadcast
-- priority queue (D58); 01 R1 R2 R5 R6; 13-build-guide.md § Part D "The
-- hard part". Josh's calls (step 7): offline bases on free plots, escort =
-- one Roblox friend who opts in, one grab takes the whole share. Escape =
-- a radius around the victim's plot; any carrier death drops the loot (D114).
--
-- The raid: Breach (at the victim's plot; starts the 90 s window) ->
-- Lockpick (server-run Skyrim-style lock, speed not failure) -> Grab (Exposed only) ->
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
local LockpickModel = require(ReplicatedStorage.Shared.LockpickModel)
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
local InventoryService = require(script.Parent.InventoryService)
local ArmorService = require(script.Parent.ArmorService)
local BroadcastQueue = require(script.Parent.BroadcastQueue)
local RaidProtectionService = require(script.Parent.RaidProtectionService)

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
	targetBand: number, -- the victim's band at breach: an escort must be in band too (R6)
	plotHitbox: BasePart,
	phase: string, -- "Breached" | "Unlocked" | "Carrying" | "Over"
	endsAt: number,
	-- Lockpick (shared/LockpickModel). Only this server knows the sweet spot.
	stages: { LockpickModel.StageConfig }, -- this lock's stages (tier + Lock Upgrades)
	stage: number, -- the stage being picked, 1..#stages
	center: number, -- the secret sweet-spot angle for this stage (degrees)
	side: number, -- which side of centre it's on (-1 / 1)
	prevSide: number?, -- the last SOLVED stage's side (same-side rule)
	lock: LockpickModel.State,
	pickBreakScale: number, -- this pick's durability roll (BreakVariance)
	picking: boolean, -- kneeling at the lock: can't move until it opens or they cancel
	feelAt: number, -- when the raider was last sent a LockpickFeel
	loot: Loot?,
	-- D112: the grab also takes the victim's best spare armor piece
	-- (Josh's call 2026-09-23). armorTaken = taken from a victim who left.
	armorId: string?,
	armor: Types.ArmorPiece?,
	armorTaken: Types.ArmorPiece?,
	chaseStuds: number?, -- Carrying: the distance last sent to the raid's players (steps)
	halfwayAlerted: boolean,
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

-- ── Step 8: Breach Charges, band, shields ────────────────────────────────

local chargeCfg = Config.BreachCharges

-- Can `raider` breach this base? Breach Charges held (02 § Preconditions),
-- target in the raider's band and not shielded (R6; D66, D67, D75), and a
-- shielded raider has confirmed giving their shield up (Josh's call).
-- An OFFLINE target's band and shields come from its save, which is only
-- read after the raid lock is taken: breachInner re-checks them there.
function RaidService.checkBreach(raider: Player, base: PlotService.BaseInfo): (boolean, string?)
	if InventoryService.count(raider, chargeCfg.ItemId) < chargeCfg.PerRaid then
		return false, "NoCharges"
	end
	if not base.offline then
		local victim = Players:GetPlayerByUserId(base.ownerId)
		if not victim then
			return false, "NoBase"
		end
		local allowed, reason = RaidProtectionService.canRaid(raider, RaidProtectionService.targetOf(victim))
		if not allowed then
			return false, reason
		end
	end
	return RaidProtectionService.confirmOwnShield(raider)
end

-- Spends the Breach Charges and ends the raider's own shields. Called once
-- the raid is certain; nothing after it can refuse. False = the charges
-- were gone by now (the breach is then cancelled, nothing spent).
function RaidService.consumeBreach(raider: Player, _base: PlotService.BaseInfo): boolean
	if not InventoryService.consume(raider, chargeCfg.ItemId, chargeCfg.PerRaid) then
		return false
	end
	RaidProtectionService.forfeit(raider)
	return true
end

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

local function describe(loot: Loot, armor: Types.ArmorPiece?): string
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
	if armor then
		table.insert(parts, ArmorService.describe(armor))
	end
	return if #parts > 0 then table.concat(parts, ", ") else "nothing"
end

local function totalsOf(loot: Loot?, armor: Types.ArmorPiece?): { [string]: number }
	local totals: { [string]: number } = {}
	if armor then
		totals[ArmorService.describe(armor)] = 1
	end
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
			then {
				Picking = raid.picking,
				Stage = raid.stage,
				Stages = #raid.stages,
				Picks = InventoryService.count(raid.raider, pickCfg.ItemId),
			}
			else nil,
		Loot = if raid.loot then totalsOf(raid.loot, raid.armor) else nil,
		CanSabotage = canSabotage,
		ChaseStuds = if raid.phase == "Carrying" then raid.chaseStuds else nil,
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

-- Map points are plot-local studs (negative on half the plot), but a
-- profile never stores a negative number (PlayerDataService validate), so
-- they're saved shifted by LogCoordOffset. RaidUi shifts them back. (Bug
-- found 2026-09-23: every entry with a negative point was being rejected,
-- raid id and all.)
local function shifted(v: number): number
	local offset = raidCfg.LogCoordOffset
	return math.clamp(v + offset, 0, 2 * offset)
end

local function logEntry(raid: Raid, outcome: string, taken: Loot?, armor: Types.ArmorPiece?): Types.RaidLogEntry
	local path: { { number } } = {}
	for _, point in raid.path do
		table.insert(path, { shifted(point[1]), shifted(point[2]) })
	end
	local triggers: { { any } } = {}
	for _, trigger in raid.triggers do
		table.insert(triggers, { shifted(trigger[1]), shifted(trigger[2]), trigger[3] })
	end
	return {
		Id = raid.id,
		At = os.time(),
		RaiderName = raid.raider.Name,
		Offline = raid.offline,
		Outcome = outcome,
		Taken = totalsOf(taken, armor),
		Path = path,
		Triggers = triggers,
	}
end

local addEntry: (log: { Entries: { Types.RaidLogEntry }, Applied: { string } }, entry: Types.RaidLogEntry) -> ()

-- The raider's own log (Josh, 2026-09-23: Raids shows raids you did too):
-- what they got, or why it failed. Only while they're loaded here.
local function logForRaider(raid: Raid, outcome: string, got: Loot?, armor: Types.ArmorPiece?, note: string?)
	if not raid.raider.Parent or not PlayerDataService.isLoaded(raid.raider) then
		return
	end
	local entry = logEntry(raid, outcome, got, armor)
	entry.AsRaider = true
	entry.VictimName = raid.victimName
	entry.Note = note
	local logged = PlayerDataService.update(raid.raider, "RaidLog", OWNER, function(log)
		addEntry(log, entry)
		return log
	end)
	if not logged then
		warn(`[Raid] {raid.id}: couldn't write {raid.raider.Name}'s raid log`)
	end
end

-- Adds an entry (newest first, capped) and remembers the raid id.
addEntry = function(log: { Entries: { Types.RaidLogEntry }, Applied: { string } }, entry: Types.RaidLogEntry)
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
	local look = raidCfg.CarrierMark
	local mark = Instance.new("Folder")
	mark.Name = MARK_NAME
	local highlight = Instance.new("Highlight")
	highlight.FillColor = look.Color
	highlight.FillTransparency = look.FillTransparency
	highlight.OutlineColor = look.OutlineColor
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = mark
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(look.LabelSize.X, look.LabelSize.Y)
	billboard.StudsOffset = Vector3.new(0, look.LabelHeight, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = look.MaxDistance
	billboard.Adornee = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = look.LabelColor
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
	trail.Lifetime = look.TrailSeconds
	trail.Color = ColorSequence.new(look.Color)
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

-- Only if `player` is still in THIS raid: ending one raid must never strip
-- the carry rules from someone who has since started another (review
-- 2026-09-22 #7).
local function releaseParticipant(player: Player?, raid: Raid)
	if not player or raidOf[player] ~= raid then
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
	releaseParticipant(raid.raider, raid)
	releaseParticipant(raid.escort, raid)
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
local victimLeft: (player: Player) -> () -- defined below failRaid
local stopPicking: (raid: Raid) -> () -- lets a raider move again

local function failRaid(raid: Raid, outcome: string, text: string)
	-- Once an escape is settling (message in flight), only escape() may
	-- finish the raid: a second path would race it for the lock.
	if raid.phase == "Over" or raid.phase == "Settling" then
		return
	end
	local hadLoot = raid.loot ~= nil
	local takenOnLeave = raid.taken
	local armorOnLeave = raid.armorTaken
	cleanup(raid)
	print(`[Raid] {raid.raider.Name} -> {raid.victimName}: {outcome} ({text})`)
	if hadLoot then
		BroadcastQueue.push("ChasePing", `The loot went back to {raid.victimName}'s vault!`)
	end
	alertVictim(raid, "RaidOver", `Raid over: {text}. You lost nothing.`)
	local entry = logEntry(raid, "Recovered", nil)
	entry.Note = text
	logForRaider(raid, "Recovered", nil, nil, text)
	if takenOnLeave then
		-- The victim left mid-Chase and we already took the loot from their
		-- save: send it back. If this send fails they lose it (never a dupe).
		task.spawn(function()
			local sent = PlayerDataService.messageAsync(raid.victimId, { Kind = "RaidReturn", RaidId = raid.id, Loot = takenOnLeave, Armor = armorOnLeave, Entry = entry })
			if not sent then
				warn(`[Raid] couldn't return {describe(takenOnLeave, armorOnLeave)} to {raid.victimName} (raid {raid.id})`)
			end
		end)
	elseif raid.victim and raid.victim.Parent and PlayerDataService.isLoaded(raid.victim) then
		local logged = PlayerDataService.update(raid.victim, "RaidLog", OWNER, function(log)
			addEntry(log, entry)
			return log
		end)
		if not logged then
			warn(`[Raid] {raid.id}: couldn't write {raid.victimName}'s raid log`)
		end
	elseif raid.lockHeld then
		-- Offline: a log-only message, then free the lock (not "pending": nothing stolen).
		task.spawn(function()
			PlayerDataService.messageAsync(raid.victimId, { Kind = "RaidLog", RaidId = raid.id, Entry = entry })
			RaidLock.finish(raid.victimId, raid.id, false)
		end)
	end
end

-- Offline raids: renew the raid lock for the WHOLE raid, not just while the
-- theft saves; it only lives Lock.TtlSeconds (review 2026-09-22 #2). If it
-- can't be renewed before settlement starts, another server may read the
-- same save, so the raid fails and nothing moves.
local function keepLockAlive(raid: Raid)
	task.spawn(function()
		while raid.phase ~= "Over" do
			task.wait(raidCfg.Lock.KeepAliveSeconds)
			local phase = raid.phase
			if phase == "Over" then
				break
			elseif phase == "Settling" then
				-- The theft is saving: keep it ours. Once it's "pending" this
				-- quietly does nothing.
				RaidLock.extend(raid.victimId, raid.id)
			elseif not RaidLock.extend(raid.victimId, raid.id) then
				failRaid(raid, "Failed", "the raid lock was lost")
				return
			end
		end
	end)
end

-- 02 § The raid sequence step 5 (D114): the carrier has escaped once they
-- stand EscapeRadiusStuds (horizontal) from the victim plot's centre. The
-- same distance on every plot, whatever the layout. Only while standing on
-- something: jumping off an island can't cross the line in mid-air and then
-- fall to a respawn with the loot (the fall fails the raid, § Escape and
-- carrier death).
local function chaseDistance(raid: Raid, root: BasePart): number
	local offset = root.Position - raid.plotHitbox.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

local function hasEscaped(raid: Raid, root: BasePart, humanoid: Humanoid): boolean
	return chaseDistance(raid, root) > raidCfg.EscapeRadiusStuds and humanoid.FloorMaterial ~= Enum.Material.Air
end

-- Chase progress for the raid's players (Josh, 2026-09-23): their banners
-- show the carrier's distance in steps, and the victim is told once when
-- the carrier passes the halfway mark. Display only; hasEscaped decides.
local function updateChaseProgress(raid: Raid, root: BasePart)
	local distance = chaseDistance(raid, root)
	local step = raidCfg.ChaseProgressStepStuds
	local shown = math.min(math.floor(distance / step) * step, raidCfg.EscapeRadiusStuds)
	if shown ~= raid.chaseStuds then
		raid.chaseStuds = shown
		sendState(raid)
	end
	if not raid.halfwayAlerted and distance >= raidCfg.EscapeRadiusStuds * raidCfg.ChaseHalfwayFraction then
		raid.halfwayAlerted = true
		alertVictim(raid, "RaidAlert", `{raid.raider.Name} is halfway out with your loot! Hit them now`)
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
	local takenArmor: Types.ArmorPiece? = nil
	if raid.taken then
		-- The victim left mid-Chase: already taken from their save as they left.
		taken = raid.taken
		takenArmor = raid.armorTaken
		local entry = logEntry(raid, "Stolen", taken, takenArmor)
		task.spawn(PlayerDataService.messageAsync, raid.victimId, { Kind = "RaidLog", RaidId = raid.id, Entry = entry })
	elseif not raid.offline and raid.victim and raid.victim.Parent and PlayerDataService.isLoaded(raid.victim) then
		-- Online: the victim's profile is live here.
		taken = VaultService.takeLoot(raid.victim, loot)
		-- Clamped like resources: nothing if they've put that piece on since.
		takenArmor = if raid.armorId then ArmorService.takeSpare(raid.victim, raid.armorId) else nil
		local entry = logEntry(raid, "Stolen", taken, takenArmor)
		local logged = PlayerDataService.update(raid.victim, "RaidLog", OWNER, function(log)
			addEntry(log, entry)
			return log
		end)
		if not logged then
			warn(`[Raid] {raid.id}: couldn't write {raid.victimName}'s raid log`)
		end
	elseif raid.lockHeld then
		-- Offline: send while still holding the raid lock, THEN mark pending.
		taken = loot
		takenArmor = raid.armor
		local entry = logEntry(raid, "Stolen", loot, takenArmor)
		-- Still ours? (keepLockAlive renews it for the whole raid.) If it
		-- lapsed, someone else may be reading the same save: don't steal.
		if not RaidLock.extend(raid.victimId, raid.id) then
			raid.phase = "Carrying"
			failRaid(raid, "Failed", "the raid lock was lost")
			return
		end
		local sent = PlayerDataService.messageAsync(raid.victimId, { Kind = "RaidTheft", RaidId = raid.id, Loot = loot, ArmorId = raid.armorId, Entry = entry })
		if not sent then
			raid.phase = "Carrying" -- back out of Settling so failRaid can run
			failRaid(raid, "Failed", "the theft couldn't be saved")
			return
		end
		if not RaidLock.finish(raid.victimId, raid.id, true) then -- "pending" until their login (H2)
			warn(`[Raid] {raid.id}: theft sent but the lock couldn't be marked pending`)
		end
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
		-- A single piece arrives whole (no in-transit destruction).
		if takenArmor then
			ArmorService.grant(raid.raider, takenArmor.Tier, takenArmor.Slot)
		end
	end
	logForRaider(raid, "Stolen", credit, takenArmor, nil)
	print(`[Raid] {raid.raider.Name} escaped from {raid.victimName}: victim lost {describe(taken, takenArmor)}, raider got {describe(credit, takenArmor)}`)
	BroadcastQueue.push("ChasePing", `{raid.raider.Name} escaped with loot from {raid.victimName}'s base!`)
	alertVictim(raid, "RaidLost", `{raid.raider.Name} escaped with {describe(taken, takenArmor)} from your base`)
	cleanup(raid)
end

-- A victim leaving. Called from BOTH leave paths (PlayerDataService's
-- before-release hook and PlayerRemoving), whichever fires first; the
-- second call does nothing. Mid-Chase their loot is taken while their save
-- is still live, and the raider still has to escape with it (review H1).
-- Before the grab there's nothing at stake, so the raid is cancelled.
victimLeft = function(player: Player)
	local victimRaid = raidOnVictim[player.UserId]
	if type(victimRaid) ~= "table" then
		return
	end
	local raid = victimRaid :: Raid
	if raid.victim ~= player then
		return -- already settled by the other path
	end
	raid.victim = nil
	if raid.phase == "Carrying" and raid.loot and PlayerDataService.isLoaded(player) then
		raid.taken = VaultService.takeLoot(player, raid.loot :: Loot)
		raid.armorTaken = if raid.armorId then ArmorService.takeSpare(player, raid.armorId) else nil
		print(`[Raid] {player.Name} left mid-Chase: took {describe(raid.taken :: Loot, raid.armorTaken)} from their save; {raid.raider.Name} still has to escape`)
	else
		print(`[Raid] {player.Name} left during {raid.phase}: cancelling the raid`)
		failRaid(raid, "Cancelled", `{player.Name} left`)
	end
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
				-- R6: an escort is a raider too, so the band applies to them
				-- (a strong friend can't escort into a beginner's base).
				if ok and friends and raid.phase ~= "Over" and RaidProtectionService.inBand(other, raid.targetBand) then
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

-- A fresh sweet spot for the current stage (on a new stage, and when the
-- raider cancels: walking away can't keep a half-found spot, guide §6).
local function newStage(raid: Raid)
	raid.center, raid.side = LockpickModel.rollCenter(rng, raid.prevSide, raid.stages[raid.stage].SweetWidth)
end

-- A fresh pick: its own durability roll (Josh's pick from the guide's extras).
local function newPick(raid: Raid)
	raid.pickBreakScale = 1 + (rng:NextNumber() * 2 - 1) * pickCfg.BreakVariance
end

-- Always the same number of stages; vault tier and the victim's Lock
-- Upgrades only make each one harder (Josh's call, 2026-09-22).
local function newLock(raid: Raid, lockUpgradeSteps: number)
	raid.stages = LockpickModel.stagesFor(math.max(0, raid.tier - 1) + lockUpgradeSteps)
	raid.stage = 1
	raid.prevSide = nil
	raid.lock = LockpickModel.newState()
	newPick(raid)
	newStage(raid)
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
	-- Online: checkBreach just read it from the live profile (no yield since).
	local victimTarget = if victim then RaidProtectionService.targetOf(victim) else nil
	local targetBand: number = if victimTarget then victimTarget.band else 0
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
			return giveUp("Locked") -- another raid, or a theft not applied yet (one per absence)
		end
		if PresenceService.getPresence(base.ownerId) ~= "offline" then
			return giveUp("Online")
		end
		local data, sessionActive = PlayerDataService.viewAsync(base.ownerId)
		if not data or sessionActive then
			return giveUp("Busy")
		end
		view = data
		-- R6 on the saved data: band + shields, checked on every attempt.
		local target = RaidProtectionService.targetOfData(data)
		local allowedNow, whyNot = RaidProtectionService.canRaid(player, target)
		if not allowedNow or not target then
			return giveUp(whyNot or "Busy")
		end
		targetBand = target.band
		-- The raider may have moved or died while we waited.
		local stillRoot = rootOf(player)
		if not stillRoot or not player.Parent or NodeMath.distanceToHitbox(base.hitbox, stillRoot.Position) > raidCfg.BreachRecheckRange then
			return giveUp("TooFar")
		end
		-- The waits above can take a while: start the raid on a fresh lock
		-- lifetime, or not at all (review 2026-09-22 #2).
		if not RaidLock.extend(base.ownerId, raidId) then
			return giveUp("Busy")
		end
	elseif not victim then
		raidOnVictim[base.ownerId] = nil
		return false, "NoBase"
	end

	-- They may have joined someone's raid as escort while this breach was
	-- waiting (review 2026-09-22 #7).
	if raidOf[player] then
		if lockHeld then
			task.spawn(RaidLock.finish, base.ownerId, raidId, false)
		end
		raidOnVictim[base.ownerId] = nil
		return false, "InRaid"
	end

	-- Last step before the raid exists: spend the charges (02 § The raid
	-- sequence 2, "consume charges").
	if not RaidService.consumeBreach(player, base) then
		if lockHeld then
			task.spawn(RaidLock.finish, base.ownerId, raidId, false)
		end
		raidOnVictim[base.ownerId] = nil
		return false, "NoCharges"
	end
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
		targetBand = targetBand,
		plotHitbox = base.hitbox,
		phase = "Breached",
		endsAt = now() + raidCfg.WindowSeconds,
		stages = {},
		stage = 1,
		center = 0,
		side = 1,
		prevSide = nil,
		lock = LockpickModel.newState(),
		pickBreakScale = 1,
		picking = false,
		feelAt = 0,
		loot = nil,
		armorId = nil,
		armor = nil,
		armorTaken = nil,
		chaseStuds = nil,
		halfwayAlerted = false,
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
	newLock(raid, DefenseService.useLockUpgrades(base.ownerId))

	print(`[Raid] {player.Name} breached {base.ownerName}'s base ({if base.offline then "offline" else "online"}, tier {base.tier})`)
	alertVictim(raid, "RaidAlert", `RAID! {player.Name} breached your base`)
	BroadcastQueue.push("RaidAlert", `{player.Name} is raiding {base.ownerName}'s base!`)
	offerEscort(raid)
	startPathSampler(raid)
	if raid.lockHeld then
		keepLockAlive(raid)
	end
	sendState(raid)
	task.delay(raidCfg.WindowSeconds, function()
		if raid.phase ~= "Over" and raid.phase ~= "Settling" then
			failRaid(raid, "Timeout", "time ran out")
		end
	end)
	return true, nil
end

-- ── Lockpick: Skyrim-style lock (speed, never fail-locked) ──────────────
-- The raider streams (pick angle, holding Turn). This server runs the lock
-- every frame with the secret sweet spot and sends back only how the lock
-- responds (LockpickFeel). Dead on, a stage takes FullTurn / TurnSpeed
-- seconds, which is also the floor no script can beat.

local function nearCore(player: Player, raid: Raid): boolean
	local root = rootOf(player)
	local core = coreOf(raid.victimId)
	return root ~= nil and core ~= nil and NodeMath.distanceToHitbox(core, root.Position) <= raidCfg.CoreRange
end

local function roundTo(value: number, step: number): number
	return math.floor(value / step + 0.5) * step
end

local function sendFeel(raid: Raid, event: string?)
	raid.feelAt = now()
	if not raid.raider.Parent then
		return
	end
	local s = raid.lock
	local stage = raid.stages[raid.stage]
	local feel: Types.LockpickFeel = {
		Stage = raid.stage,
		Stages = #raid.stages,
		-- Rounded: enough for the dial and the shake, too coarse for a script
		-- to work the exact distance to the sweet spot back out (review
		-- 2026-09-22 #10).
		LockAngle = roundTo(s.lockAngle, pickCfg.FeelAngleStep),
		Stalled = s.stalled,
		-- Only while stalled: otherwise sweeping the pick without turning
		-- would read out the sweet spot for free.
		Closeness = if s.stalled then roundTo(s.closeness, pickCfg.FeelClosenessStep) else 0,
		Damage = s.damage,
		Lockout = s.lockout,
		Picks = InventoryService.count(raid.raider, pickCfg.ItemId),
		Event = event,
		Debug = if RunService:IsStudio() and pickCfg.StudioOverlay and stage
			then { Center = raid.center, SweetWidth = stage.SweetWidth, PartialWidth = stage.PartialWidth }
			else nil,
	}
	Remotes.getEvent("LockpickFeel"):FireClient(raid.raider, feel)
end

-- Kneeling at the lock: both hands busy, so no walking (Josh's call).
local function startPicking(player: Player): (boolean, string?)
	local raid = raidOf[player]
	if not raid or raid.raider ~= player or raid.phase ~= "Breached" then
		return false, "NotPicking"
	end
	if not nearCore(player, raid) then
		return false, "TooFar"
	end
	local _, humanoid = rootOf(player)
	if not humanoid then
		return false, "Dead"
	end
	raid.picking = true
	raid.lock.tension = false
	raid.lock.needsRelease = false
	MovementService.setMultiplier(humanoid, "Lockpick", 0)
	sendState(raid)
	sendFeel(raid, nil)
	return true, nil
end

stopPicking = function(raid: Raid)
	raid.picking = false
	raid.lock.tension = false
	raid.lock.stalled = false
	raid.lock.lockAngle = 0
	local _, humanoid = rootOf(raid.raider)
	if humanoid then
		MovementService.setMultiplier(humanoid, "Lockpick", nil)
	end
end

-- Standing up re-rolls this stage's sweet spot but keeps the pick's damage,
-- so walking away never resets a nearly-snapped pick (guide §6).
local function cancelPicking(player: Player): (boolean, string?)
	local raid = raidOf[player]
	if not raid or raid.raider ~= player or not raid.picking then
		return false, "NotPicking"
	end
	stopPicking(raid)
	newStage(raid)
	sendState(raid)
	return true, nil
end

-- (pick angle, holding Turn): intents only. The model ignores angle changes
-- while Turn is held (both hands on the lock).
local function lockpickInput(player: Player, angleArg: unknown, tensionArg: unknown)
	local raid = raidOf[player]
	if not raid or raid.raider ~= player or raid.phase ~= "Breached" or not raid.picking then
		return
	end
	if typeof(angleArg) ~= "number" or angleArg ~= angleArg or typeof(tensionArg) ~= "boolean" then
		logAnomaly(player, "sent a bad lockpick input")
		return
	end
	if not nearCore(player, raid) then
		LockpickModel.setInput(raid.lock, raid.lock.pickAngle, false)
		return
	end
	LockpickModel.setInput(raid.lock, angleArg :: number, tensionArg :: boolean)
end

-- One server frame of a raider's lock (Heartbeat).
local function stepLock(raid: Raid, dt: number)
	local s = raid.lock
	local stage = raid.stages[raid.stage]
	local hasPick = InventoryService.count(raid.raider, pickCfg.ItemId) > 0
	-- No picks left: improvising is slow, never impossible (02 § Lockpick
	-- skill model).
	local turnSpeed = pickCfg.TurnSpeed * (if hasPick then 1 else pickCfg.NoPickTurnScale)
	local result = LockpickModel.step(s, dt, raid.center, stage, turnSpeed, stage.BreakSeconds * raid.pickBreakScale)
	if result == "broke" then
		-- A snapped pick costs one pick and a refit; the sweet spot stays.
		local hadPick = InventoryService.consume(raid.raider, pickCfg.ItemId, 1)
		LockpickModel.onBreak(s, if hadPick then pickCfg.RefitSeconds else pickCfg.NoPickRefitSeconds)
		newPick(raid)
		sendFeel(raid, "broke")
	elseif result == "solved" then
		LockpickModel.onSolved(s)
		raid.prevSide = raid.side
		if raid.stage >= #raid.stages then
			sendFeel(raid, "open")
			raid.phase = "Unlocked"
			stopPicking(raid) -- they can move again
			alertVictim(raid, "RaidAlert", `{raid.raider.Name} picked your vault's lock!`)
		else
			raid.stage += 1
			newStage(raid)
			sendFeel(raid, "solved")
		end
		sendState(raid)
	elseif now() - raid.feelAt >= pickCfg.FeelSendSeconds then
		sendFeel(raid, nil)
	end
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
	-- D112: plus their best spare armor piece (never the worn one, R1).
	local armorId, armor = ArmorService.bestSpareIn(if raid.view then raid.view.Armor elseif raid.victim then ArmorService.get(raid.victim) else nil)
	if next(loot.Resources) == nil and loot.Scrap == 0 and not armor then
		failRaid(raid, "Empty", "their Exposed was empty")
		return true, "Empty"
	end
	raid.loot = loot
	raid.armorId, raid.armor = armorId, armor
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
	print(`[Raid] {player.Name} grabbed {describe(loot, armor)} from {raid.victimName}`)
	alertVictim(raid, "RaidAlert", `{player.Name} grabbed {describe(loot, armor)}! Hit them to get it back`)
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
	if breaching[player] then
		return false, "Busy" -- their own breach is still starting (review 2026-09-22 #7)
	end
	if not raid.offered[player] or raid.escort or raidOf[player] or player.UserId == raid.victimId then
		return false, "NotOffered"
	end
	if not RaidProtectionService.inBand(player, raid.targetBand) then
		return false, "OutOfBand" -- their band rose since the offer
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
	local takenArmor = if type(message.ArmorId) == "string" then ArmorService.takeSpareVia(update, message.ArmorId) else nil
	local entry = message.Entry
	entry.Taken = totalsOf(taken, takenArmor)
	update("RaidLog", OWNER, function(log)
		addEntry(log, entry)
		return log
	end)
	-- D1 / 02 § Theft math: the 30-min shield starts now, at the login that
	-- applies the theft (consistency decision #13).
	RaidProtectionService.startPostRaidVia(update)
	print(`[Raid] applied offline raid {raidId} to {player.Name}: lost {describe(taken, takenArmor)}; 30-min shield started`)
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
	local armor = ArmorService.clean(message.Armor)
	if armor then
		ArmorService.grantVia(update, armor)
	end
	update("RaidLog", OWNER, function(log)
		addEntry(log, message.Entry)
		return log
	end)
	print(`[Raid] returned {describe(loot, armor)} to {player.Name} (raid {raidId})`)
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
	-- Whichever leave-handler runs first settles it (the order of
	-- PlayerRemoving connections isn't something to rely on).
	PlayerDataService.setBeforeRelease(victimLeft)

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

	-- Escape check + deaths + the lockpick.
	RunService.Heartbeat:Connect(function(dt: number)
		for _, raid in raids do
			if raid.phase == "Carrying" then
				-- D114: a carrier who dies for any reason (hit, fall, reset)
				-- drops the loot home, the same path as a knock-loose hit.
				-- Leaving the game is PlayerRemoving below. The server checks
				-- every frame; no client "I escaped" is ever trusted.
				local root, humanoid = rootOf(raid.raider)
				if not root or not humanoid then
					task.spawn(failRaid, raid, "Died", `{raid.raider.Name} went down`)
				elseif MovementService.checkNow(raid.raider) then
					-- Checked first: an escape is never judged on a teleport
					-- the movement check would undo (review 2026-09-22 #6).
					if hasEscaped(raid, root, humanoid) then
						task.spawn(escape, raid)
					else
						updateChaseProgress(raid, root)
					end
				end
			elseif raid.phase ~= "Over" and raid.phase ~= "Settling" and not rootOf(raid.raider) then
				task.spawn(failRaid, raid, "Died", `{raid.raider.Name} went down`)
			elseif raid.phase == "Breached" and raid.picking then
				stepLock(raid, dt)
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
		victimLeft(player)
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
	Remotes.getFunction("StartLockpick").OnServerInvoke = guarded(startPicking)
	Remotes.getFunction("CancelLockpick").OnServerInvoke = guarded(cancelPicking)
	Remotes.getFunction("Grab").OnServerInvoke = guarded(grab)
	Remotes.getFunction("Sabotage").OnServerInvoke = guarded(sabotage)
	Remotes.getFunction("JoinEscort").OnServerInvoke = guarded(joinEscort)
	-- Lockpick input streams while picking: its own, looser limit.
	local allowInput = RateLimiter.newBucket("LockpickInput", pickCfg.InputBurst, pickCfg.InputPerSecond)
	Remotes.getEvent("LockpickInput").OnServerEvent:Connect(function(player: Player, angle: unknown, tension: unknown)
		if allowInput(player) then
			lockpickInput(player, angle, tension)
		end
	end)
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
