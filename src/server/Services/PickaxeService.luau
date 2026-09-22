--!strict
-- PickaxeService: the pickaxe tier and its upgrade tree. The only service
-- that writes the Gear section (Config.Data.SectionOwners).
--
-- Docs: 02-core-loop.md § The pickaxe is the weapon, § Pickaxe upgrade tree
-- (D108); 05-items.md § Pickaxe tiers, § Gear score (D92), § Pickaxes are
-- not tradeable (D111).
-- * The pickaxe is a per-player tier, not an item (D111).
-- * Each tier gives a point budget; each node (one rank of an upgrade) costs
--   1 point + resources; respec gives every point back for a resource fee
--   (Josh's call, step 5). Nodes are saved as Gear.Upgrades[branch]
--   ["<UpgradeId><rank>"] = true, so gear score counts them directly.
-- * Other services read the effects through the stat functions below;
--   nothing else looks inside Gear.
-- * Also sends the owner's Gear menu state (GearState: pickaxe + armor +
--   gadgets + skins). Gear score is never in it.
-- * Better tiers come from Workshop crafting (step 10); Studio debug only now.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local AnomalyLog = require(ServerScriptService.Util.AnomalyLog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local VaultService = require(script.Parent.VaultService)
local ArmorService = require(script.Parent.ArmorService)
local InventoryService = require(script.Parent.InventoryService)
local CosmeticService = require(script.Parent.CosmeticService)

local OWNER = "PickaxeService"
local combatCfg = Config.Combat

type GearData = { PickaxeTier: number, Upgrades: { [string]: { [string]: boolean } } }
type UpgradeConfig = { Id: string, Name: string, Ranks: number, PerRank: number }

-- upgrade id -> its branch and config
local upgradeInfo: { [string]: { branch: string, cfg: UpgradeConfig } } = {}
for branch, list in combatCfg.Upgrades :: any do
	for _, cfg in list :: { UpgradeConfig } do
		upgradeInfo[cfg.Id] = { branch = branch, cfg = cfg }
	end
end

local changedEvent = Instance.new("BindableEvent")
local logAnomaly = AnomalyLog.new("Pickaxe")

local PickaxeService = {}

-- Fires (player) after their pickaxe tier or upgrades change.
PickaxeService.Changed = changedEvent.Event

-- ── Reading ──────────────────────────────────────────────────────────────

local function gearOf(player: Player): GearData?
	return PlayerDataService.get(player, "Gear")
end

local function rankIn(gear: GearData, upgradeId: string): number
	local info = upgradeInfo[upgradeId]
	local nodes = gear.Upgrades[info.branch] or {}
	local rank = 0
	for r = 1, info.cfg.Ranks do
		if nodes[`{upgradeId}{r}`] then
			rank = r
		end
	end
	return rank
end

local function pointsUsed(gear: GearData): number
	local used = 0
	for _, nodes in gear.Upgrades do
		for _, bought in nodes do
			if bought then
				used += 1
			end
		end
	end
	return used
end

local function pointsFor(tier: number): number
	local list = combatCfg.PointsByTier
	return list[math.clamp(tier, 1, #list)]
end

function PickaxeService.getTier(player: Player): number
	local gear = gearOf(player)
	return if gear then gear.PickaxeTier else combatCfg.StartingPickaxeTier
end

function PickaxeService.rank(player: Player, upgradeId: string): number
	local gear = gearOf(player)
	return if gear then rankIn(gear, upgradeId) else 0
end

local function perRank(upgradeId: string): number
	return upgradeInfo[upgradeId].cfg.PerRank
end

-- ── Stats other services use ─────────────────────────────────────────────

-- Seconds between mining hits that count (Extraction: Mine speed).
function PickaxeService.mineCooldown(player: Player): number
	return Config.Nodes.MineCooldownSeconds * (1 - perRank("MineSpeed") * PickaxeService.rank(player, "MineSpeed"))
end

-- Ranks of the Grade-odds bonus; NodeService applies the server-only value.
function PickaxeService.gradeOddsRanks(player: Player): number
	return PickaxeService.rank(player, "GradeOdds")
end

-- Chance (0..1) that a mining hit also strikes one nearby node.
function PickaxeService.multiStrikeChance(player: Player): number
	return perRank("MultiStrike") * PickaxeService.rank(player, "MultiStrike")
end

-- Seconds between swings that count (Combat: Swing speed).
function PickaxeService.swingInterval(player: Player): number
	return combatCfg.SwingIntervalSeconds * (1 - perRank("SwingSpeed") * PickaxeService.rank(player, "SwingSpeed"))
end

-- Base damage of one hit before combo and armor (tier + Combat: Damage).
function PickaxeService.damage(player: Player): number
	local tiers = combatCfg.DamageByTier
	local tier = PickaxeService.getTier(player)
	return tiers[math.clamp(tier, 1, #tiers)] + perRank("Damage") * PickaxeService.rank(player, "Damage")
end

-- Knockback multiplier (Combat: Knockback).
function PickaxeService.knockbackMultiplier(player: Player): number
	return 1 + perRank("Knockback") * PickaxeService.rank(player, "Knockback")
end

-- 0..1 share cut from stuns and slows on this player (Mobility: Stun recovery).
function PickaxeService.stunRecovery(player: Player): number
	return math.clamp(perRank("StunRecovery") * PickaxeService.rank(player, "StunRecovery"), 0, 1)
end

-- ── Gear menu state (never includes gear score) ──────────────────────────

function PickaxeService.getState(player: Player): Types.GearState?
	local gear = gearOf(player)
	local armor = ArmorService.get(player)
	local items = InventoryService.getAll(player)
	local cosmetics = CosmeticService.get(player)
	if not gear or not armor or not items or not cosmetics then
		return nil
	end
	local ranks: { [string]: number } = {}
	for upgradeId in upgradeInfo do
		ranks[upgradeId] = rankIn(gear, upgradeId)
	end
	local pieces = {}
	for id, piece in armor.Pieces do
		table.insert(pieces, { Id = id, Tier = piece.Tier, Slot = piece.Slot })
	end
	table.sort(pieces, function(a, b)
		return if a.Tier ~= b.Tier then a.Tier > b.Tier else a.Id < b.Id
	end)
	local gadgets: { [string]: number } = {}
	for _, gadgetId in Config.Gadgets.Order do
		gadgets[gadgetId] = items[gadgetId] or 0
	end
	return {
		PickaxeTier = gear.PickaxeTier,
		Points = pointsFor(gear.PickaxeTier),
		PointsUsed = pointsUsed(gear),
		Ranks = ranks,
		ArmorEquipped = armor.Equipped[combatCfg.ArmorSlots[1]] or "",
		ArmorPieces = pieces,
		Gadgets = gadgets,
		Skins = cosmetics.PickaxeSkins,
		EquippedSkin = cosmetics.EquippedPickaxeSkin,
	}
end

function PickaxeService.refresh(player: Player)
	local state = PickaxeService.getState(player)
	if state then
		Remotes.getEvent("GearChanged"):FireClient(player, state)
	end
end

-- Shows or hides this player's Gear menu button (R4: the FTUE decides).
function PickaxeService.setMenuVisible(player: Player, visible: boolean)
	player:SetAttribute(combatCfg.Ui.GearVisibleAttribute, visible)
end

-- ── Writes ───────────────────────────────────────────────────────────────

-- Sets the pickaxe tier (Workshop crafting in step 10; Studio debug now).
-- Tiers never go down in play; nodes already bought are kept.
function PickaxeService.setTier(player: Player, tier: number): boolean
	assert(tier >= 1 and tier <= #combatCfg.PickaxeTiers and tier == math.floor(tier), `PickaxeService.setTier: bad tier {tier}`)
	local ok = PlayerDataService.update(player, "Gear", OWNER, function(gear: GearData)
		gear.PickaxeTier = tier
		return gear
	end)
	if ok then
		changedEvent:Fire(player)
		PickaxeService.refresh(player)
	end
	return ok
end

local function buy(player: Player, upgradeArg: unknown): (boolean, string?)
	if typeof(upgradeArg) ~= "string" or not upgradeInfo[upgradeArg :: string] then
		logAnomaly(player, "tried to buy an unknown upgrade")
		return false, "Invalid"
	end
	local upgradeId = upgradeArg :: string
	local info = upgradeInfo[upgradeId]
	local gear = gearOf(player)
	if not gear then
		return false, "Failed"
	end
	local rank = rankIn(gear, upgradeId)
	if rank >= info.cfg.Ranks then
		return false, "MaxRank"
	end
	if pointsUsed(gear) >= pointsFor(gear.PickaxeTier) then
		return false, "NoPoints"
	end
	local cost = combatCfg.NodeCostByRank[rank + 1]
	if not VaultService.spend(player, cost) then
		return false, "CantAfford"
	end
	-- Nothing above yields, so the checks still hold.
	local ok = PlayerDataService.update(player, "Gear", OWNER, function(current: GearData)
		current.Upgrades[info.branch] = current.Upgrades[info.branch] or {}
		current.Upgrades[info.branch][`{upgradeId}{rank + 1}`] = true
		return current
	end)
	if not ok then
		VaultService.grant(player, cost)
		return false, "Failed"
	end
	changedEvent:Fire(player)
	PickaxeService.refresh(player)
	return true, nil
end

local function respec(player: Player): (boolean, string?)
	local gear = gearOf(player)
	if not gear then
		return false, "Failed"
	end
	if pointsUsed(gear) == 0 then
		return false, "NothingToRespec"
	end
	if not VaultService.spend(player, combatCfg.RespecCost) then
		return false, "CantAfford"
	end
	local ok = PlayerDataService.update(player, "Gear", OWNER, function(current: GearData)
		for _, branch in combatCfg.PickaxeBranches do
			current.Upgrades[branch] = {}
		end
		return current
	end)
	if not ok then
		VaultService.grant(player, combatCfg.RespecCost)
		return false, "Failed"
	end
	changedEvent:Fire(player)
	PickaxeService.refresh(player)
	return true, nil
end

function PickaxeService.start()
	-- The menu shows armor and gadgets too, so refresh when they change.
	ArmorService.Changed:Connect(PickaxeService.refresh)
	InventoryService.Changed:Connect(PickaxeService.refresh)
	CosmeticService.Changed:Connect(PickaxeService.refresh)
	PlayerDataService.Loaded:Connect(function(player: Player)
		if combatCfg.Ui.ShowBeforeFtue then
			PickaxeService.setMenuVisible(player, true)
		end
		PickaxeService.refresh(player)
	end)

	local allowGear = RateLimiter.new("GearRequest", combatCfg.GearRequestCooldownSeconds)
	Remotes.getFunction("BuyUpgrade").OnServerInvoke = function(player: Player, upgradeArg: unknown): (boolean, string?)
		if not allowGear(player) then
			return false, "Busy"
		end
		return buy(player, upgradeArg)
	end
	Remotes.getFunction("RespecUpgrades").OnServerInvoke = function(player: Player): (boolean, string?)
		if not allowGear(player) then
			return false, "Busy"
		end
		return respec(player)
	end

	local allowState = RateLimiter.new("GetGearState", Config.Bank.SnapshotCooldownSeconds)
	Remotes.getFunction("GetGearState").OnServerInvoke = function(player: Player): Types.GearState?
		if not allowState(player) then
			return nil
		end
		return PickaxeService.getState(player)
	end
end

return PickaxeService
