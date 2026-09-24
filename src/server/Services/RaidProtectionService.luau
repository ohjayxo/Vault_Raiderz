--!strict
-- RaidProtectionService: who may be raided (R6). The only service that
-- writes the Shields section (Config.Data.SectionOwners).
--
-- Docs: 01-pillars.md R6; 02-core-loop.md § Preconditions, § FTUE hard
-- rules (rule 6), § Theft math; D1, D66, D67, D75, D79, D92.
--
-- * Band (D66): highest of current vault tier, lifetime peak vault tier and
--   gear score in tier units (Util/BandMetric). Raiding up is always
--   allowed; down by at most Config.RaidProtection.MaxBandsBelow (Josh's
--   call, step 8). Checked on EVERY breach, on the server, from the
--   target's live data (online) or saved data (offline).
-- * 48-hour new-account shield: from Meta.FirstLoginAt (set at first login).
-- * 30-minute post-raid shield: after an offline raid, starting when the
--   victim's next login applies the theft (RaidService's theft handler).
-- * Both block every raid on you, and neither can be dropped by a "drop all
--   shields" event (D67, D75): see dropAllShields.
-- * Breaching someone's base ends your own shields, after one confirm
--   (Josh's call, step 8).
-- Times are Util/Clock (Unix seconds + the Studio offset), never a client's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)
local BandMetric = require(ServerScriptService.Util.BandMetric)
local Clock = require(ServerScriptService.Util.Clock)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ShardService = require(script.Parent.ShardService)

local OWNER = "RaidProtectionService"
local cfg = Config.RaidProtection
local shieldCfg = cfg.Shields
-- The same table viewed as a map, to look kinds up by name.
local shieldKinds: { [string]: { Seconds: number, ExemptFromDropAll: boolean } } = shieldCfg :: any

type ShieldsData = { PostRaidUntil: number, NewAccountEnded: boolean }
type ShieldKind = "NewAccount" | "PostRaid"

-- What a raid check needs to know about a target.
export type Target = {
	band: number,
	shieldUntil: number, -- Clock time the last active shield ends (0 = none)
}

-- A "drop all shields" event (Blackout, not in the slice) suspends every
-- shield kind WITHOUT ExemptFromDropAll until this Clock time.
local dropAllUntil = 0
-- Raiders who were warned their shield will end: os.clock() deadline.
local confirmUntil: { [Player]: number } = {}

local RaidProtectionService = {}

-- ── Shields ──────────────────────────────────────────────────────────────

-- When each shield kind ends (0 = none), before any drop-all event.
local function shieldEnds(meta: { FirstLoginAt: number }, shields: ShieldsData): { [ShieldKind]: number }
	local newAccount = 0
	if meta.FirstLoginAt > 0 and not shields.NewAccountEnded then
		newAccount = meta.FirstLoginAt + shieldCfg.NewAccount.Seconds
	end
	return { NewAccount = newAccount, PostRaid = shields.PostRaidUntil }
end

-- Is this kind of shield up at `now`? A drop-all event only suspends kinds
-- that aren't exempt; both slice shields are (D67, D75).
local function isUp(kind: string, ends: number, now: number): boolean
	if ends <= now then
		return false
	end
	return shieldKinds[kind].ExemptFromDropAll or now >= dropAllUntil
end

-- The latest time any active shield ends, or 0 if none is up.
local function activeUntil(meta: { FirstLoginAt: number }, shields: ShieldsData, now: number): number
	local latest = 0
	for kind, ends in shieldEnds(meta, shields) do
		if isUp(kind, ends, now) then
			latest = math.max(latest, ends)
		end
	end
	return latest
end

local function stateOf(player: Player): Types.ShieldState?
	local meta = PlayerDataService.get(player, "Meta")
	local shields: ShieldsData? = PlayerDataService.get(player, "Shields")
	if not meta or not shields then
		return nil
	end
	local now = Clock.now()
	local ends = shieldEnds(meta, shields)
	local function left(kind: ShieldKind): number
		return if isUp(kind, ends[kind], now) then ends[kind] - now else 0
	end
	return { NewAccountSeconds = left("NewAccount"), PostRaidSeconds = left("PostRaid") }
end

-- Sends the player their own shield timers (for the Bag).
function RaidProtectionService.refresh(player: Player)
	local state = stateOf(player)
	if state then
		Remotes.getEvent("ShieldState"):FireClient(player, state)
	end
end

function RaidProtectionService.isShielded(player: Player): boolean
	local meta = PlayerDataService.get(player, "Meta")
	local shields = PlayerDataService.get(player, "Shields")
	return meta ~= nil and shields ~= nil and activeUntil(meta, shields, Clock.now()) > 0
end

-- Starts the 30-min post-raid shield from inside a profile message handler
-- (the offline theft is applied at the victim's login: D1, § Theft math).
function RaidProtectionService.startPostRaidVia(update: PlayerDataService.Update)
	local untilTime = Clock.now() + shieldCfg.PostRaid.Seconds
	update("Shields", OWNER, function(shields: ShieldsData)
		shields.PostRaidUntil = math.max(shields.PostRaidUntil, untilTime)
		return shields
	end)
end

-- The raider breached someone: their own shields end (Josh's call, step 8).
function RaidProtectionService.forfeit(player: Player)
	confirmUntil[player] = nil
	if not RaidProtectionService.isShielded(player) then
		return
	end
	local ok = PlayerDataService.update(player, "Shields", OWNER, function(shields: ShieldsData)
		shields.NewAccountEnded = true
		shields.PostRaidUntil = 0
		return shields
	end)
	print(`[Protection] {player.Name} breached a base: their shields ended ({if ok then "ok" else "FAILED"})`)
	RaidProtectionService.refresh(player)
end

-- A server-wide "drop all shields" event (Blackout, 04 § Events: not in the
-- slice). Suspends only shield kinds WITHOUT ExemptFromDropAll, so the
-- 48-hour and post-raid shields always stay up (D67, D75).
function RaidProtectionService.dropAllShields(seconds: number, eventName: string)
	dropAllUntil = math.max(dropAllUntil, Clock.now() + seconds)
	local spared = {}
	for kind, kindCfg in shieldKinds do
		if kindCfg.ExemptFromDropAll then
			table.insert(spared, kind)
		end
	end
	table.sort(spared)
	print(`[Protection] {eventName}: non-exempt shields down for {seconds} s; spared: {table.concat(spared, ", ")}`)
	for _, player in Players:GetPlayers() do
		RaidProtectionService.refresh(player)
	end
end

-- ── Band + raid checks ───────────────────────────────────────────────────

function RaidProtectionService.targetOf(player: Player): Target?
	local band = ShardService.getBand(player)
	local meta = PlayerDataService.get(player, "Meta")
	local shields = PlayerDataService.get(player, "Shields")
	if not band or not meta or not shields then
		return nil
	end
	return { band = band, shieldUntil = activeUntil(meta, shields, Clock.now()) }
end

-- The same from saved data (an offline player's read-only view). Missing or
-- damaged data gives nil: a raid is then refused, never allowed.
function RaidProtectionService.targetOfData(data: Types.ProfileData): Target?
	local ok, target = pcall(function(): Target
		local band = BandMetric.band({
			VaultTier = data.Base.VaultTier,
			LifetimePeakVaultTier = PlayerDataService.readPacked(data, "LifetimePeakVaultTier"),
			Gear = data.Gear,
			Armor = data.Armor,
		})
		-- An old save may miss the step 8 field; Reconcile adds it at login.
		local shields: ShieldsData = {
			PostRaidUntil = data.Shields.PostRaidUntil or 0,
			NewAccountEnded = data.Shields.NewAccountEnded == true,
		}
		return { band = band, shieldUntil = activeUntil(data.Meta, shields, Clock.now()) }
	end)
	if not ok then
		warn(`[Protection] couldn't read a saved profile's band/shields: {target}`)
		return nil
	end
	return target
end

local function bandAllows(raiderBand: number, targetBand: number): boolean
	return targetBand >= raiderBand - cfg.MaxBandsBelow
end

-- Is a target of `targetBand` in this player's band? (Raid escorts, D101.)
function RaidProtectionService.inBand(player: Player, targetBand: number): boolean
	local band = ShardService.getBand(player)
	return band ~= nil and bandAllows(band, targetBand)
end

-- May `raider` raid `target`? Reason codes go to RaidUi.
function RaidProtectionService.canRaid(raider: Player, target: Target?): (boolean, string?)
	local raiderBand = ShardService.getBand(raider)
	if not raiderBand or not target then
		return false, "Busy"
	end
	if not bandAllows(raiderBand, target.band) then
		return false, "OutOfBand"
	end
	if target.shieldUntil > Clock.now() then
		return false, "Shielded"
	end
	return true, nil
end

-- Could anyone on this server raid `target`? (OfflineBaseService only shows
-- offline bases someone here can actually raid: D79's band-matched plots.)
function RaidProtectionService.raidableByAnyone(target: Target, exceptUserId: number): boolean
	if target.shieldUntil > Clock.now() then
		return false
	end
	for _, player in Players:GetPlayers() do
		local band = if player.UserId ~= exceptUserId then ShardService.getBand(player) else nil
		if band and bandAllows(band, target.band) then
			return true
		end
	end
	return false
end

-- A shielded raider must confirm (Breach twice) before giving it up.
function RaidProtectionService.confirmOwnShield(raider: Player): (boolean, string?)
	if not RaidProtectionService.isShielded(raider) then
		return true, nil
	end
	local deadline = confirmUntil[raider]
	if deadline and os.clock() <= deadline then
		return true, nil
	end
	confirmUntil[raider] = os.clock() + cfg.ConfirmSeconds
	return false, "ConfirmShield"
end

-- ── Studio-only test helpers (DebugService) ─────────────────────────────

-- Restarts the 48-hour shield as if this were the first login.
function RaidProtectionService.debugRestartNewAccount(player: Player): boolean
	assert(RunService:IsStudio(), "debugRestartNewAccount is Studio-only")
	local ok = PlayerDataService.debugUpdate(player, "Meta", function(meta)
		meta.FirstLoginAt = Clock.now()
		return meta
	end) and PlayerDataService.update(player, "Shields", OWNER, function(shields: ShieldsData)
		shields.NewAccountEnded = false
		return shields
	end)
	RaidProtectionService.refresh(player)
	return ok
end

-- Starts the 30-min shield as if an offline raid had just been applied.
function RaidProtectionService.debugStartPostRaid(player: Player): boolean
	assert(RunService:IsStudio(), "debugStartPostRaid is Studio-only")
	local untilTime = Clock.now() + shieldCfg.PostRaid.Seconds
	local ok = PlayerDataService.update(player, "Shields", OWNER, function(shields: ShieldsData)
		shields.PostRaidUntil = untilTime
		return shields
	end)
	RaidProtectionService.refresh(player)
	return ok
end

-- Ends both of this player's shields now (Josh: an easy way out of a test).
function RaidProtectionService.debugClear(player: Player): boolean
	assert(RunService:IsStudio(), "debugClear is Studio-only")
	local ok = PlayerDataService.update(player, "Shields", OWNER, function(shields: ShieldsData)
		shields.NewAccountEnded = true
		shields.PostRaidUntil = 0
		return shields
	end)
	RaidProtectionService.refresh(player)
	return ok
end

-- "N: 47h 59m, raid: none" for Output.
function RaidProtectionService.debugDescribe(player: Player): string
	local state = stateOf(player)
	if not state then
		return "not loaded"
	end
	local function hm(seconds: number): string
		if seconds <= 0 then
			return "none"
		end
		return string.format("%dh %02dm %02ds", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return `new-account {hm(state.NewAccountSeconds)}, post-raid {hm(state.PostRaidSeconds)} (clock offset {Clock.getOffset()} s)`
end

-- ── Start-up ─────────────────────────────────────────────────────────────

function RaidProtectionService.start()
	PlayerDataService.Loaded:Connect(RaidProtectionService.refresh)
	Players.PlayerRemoving:Connect(function(player)
		confirmUntil[player] = nil
	end)
	local allow = RateLimiter.new("GetShieldState", cfg.StateCooldownSeconds)
	Remotes.getFunction("GetShieldState").OnServerInvoke = function(player: Player): Types.ShieldState?
		if not allow(player) then
			return nil
		end
		return stateOf(player)
	end
end

return RaidProtectionService
