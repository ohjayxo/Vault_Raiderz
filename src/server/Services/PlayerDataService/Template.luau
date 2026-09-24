--!strict
-- Default profile for a brand-new player. ProfileStore copies this for new
-- players, and Profile:Reconcile() fills in any key added here later, so new
-- fields in later build steps don't need a migration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)

local function emptyResourceStore(): Types.ResourceStore
	local store: Types.ResourceStore = {}
	for _, resource in Config.Resources.Types do
		local grades: Types.GradeCounts = {}
		for _, grade in Config.Grade.Names do
			grades[grade] = 0
		end
		store[resource] = grades
	end
	return store
end

local function emptyUpgrades(): { [string]: { [string]: boolean } }
	local upgrades = {}
	for _, branch in Config.Combat.PickaxeBranches do
		upgrades[branch] = {}
	end
	return upgrades
end

local function emptyArmorSlots(): { [string]: string }
	local slots = {}
	for _, slot in Config.Combat.ArmorSlots do
		slots[slot] = "" -- nothing equipped
	end
	return slots
end

local function emptyPackedWords(): { [string]: number }
	local words = {}
	local packedConfig: { [string]: any } = Config.Data.Packed :: any
	for word in packedConfig do
		words[word] = 0
	end
	return words
end

local Template: Types.ProfileData = {
	Meta = { Version = Config.Data.SchemaVersion, FirstLoginAt = 0, LastActiveAt = 0 },
	Resources = { Banked = emptyResourceStore(), Exposed = emptyResourceStore() },
	Scrap = { Banked = 0, Exposed = 0 },
	Credits = 0,
	NpcSales = { Day = 0, Units = {}, EverSold = false },
	TradeHistory = {},
	Items = {},
	Base = { VaultTier = 0, Archived = false, Pieces = {} },
	Gear = { PickaxeTier = Config.Combat.StartingPickaxeTier, Upgrades = emptyUpgrades() },
	Armor = { Equipped = emptyArmorSlots(), Pieces = {} },
	TechPath = { T1 = {} },
	Blueprints = { Common = {} },
	Crew = { Id = "", JoinedAt = 0 },
	Shields = { PostRaidUntil = 0, NewAccountEnded = false },
	DefenseUse = {},
	Cosmetics = { PickaxeSkins = {}, EquippedPickaxeSkin = "" },
	RaidLog = { Entries = {}, Applied = {} },
	Packed = emptyPackedWords(),
}

return Template
