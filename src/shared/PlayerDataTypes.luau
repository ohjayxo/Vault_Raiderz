--!strict
-- The shape of a saved player profile. Shared so later UI code can type what
-- the server tells it; only the server ever writes a profile (R5).
--
-- ProfileStore can only save plain data: numbers, strings, booleans, and
-- tables keyed by strings or by 1..n with no gaps. No Instances, Vector3s, etc.

-- grade name (Config.Grade.Names) -> count
export type GradeCounts = { [string]: number }
-- resource name (Config.Resources.Types) -> grade -> count
export type ResourceStore = { [string]: GradeCounts }
-- The Resources section of a profile.
export type ResourceSnapshot = { Banked: ResourceStore, Exposed: ResourceStore }
-- What the owner's Banked/Exposed meter gets (VaultChanged / GetVaultState).
-- Capacities are totals in units (Config.Bank.CapacityByTier).
export type VaultState = {
	Banked: ResourceStore,
	Exposed: ResourceStore,
	Capacity: number,
	ScrapBanked: number,
	ScrapExposed: number,
	ScrapCapacity: number,
}

-- One placed base piece (step 4). Id = GUID so remove/move target one exact
-- piece. Kind = a key of Config.Base.Pieces. X/Z = the footprint's lowest
-- grid cell on the owner's plot (0-based); Rot = quarter turns 0-3.
export type PlacedPiece = { Id: string, Kind: string, X: number, Z: number, Rot: number }

-- What the owner's build UI gets (BaseChanged / GetBaseState).
-- UpgradeCost is nil at the top tier or before a Vault Core exists.
export type BaseState = {
	Tier: number,
	MaxTier: number,
	HasVaultCore: boolean,
	BudgetUsed: number,
	Budget: number,
	UpgradeCost: { [string]: number }?,
	DefenseSlotsUsed: number,
	DefenseSlots: number,
}

-- One raid on your base (02 § Raid log path map, D105). Path and Triggers
-- are plot-local {x, z} in studs from the plot centre, rounded.
-- Outcome: "Stolen" (they escaped), "Recovered" (knocked loose / ran out of
-- time / left). Taken: resource -> units the victim lost.
export type RaidLogEntry = {
	Id: string,
	At: number,
	RaiderName: string,
	Offline: boolean,
	Outcome: string,
	Taken: { [string]: number },
	Path: { { number } },
	Triggers: { { any } },
}

-- How the lock responds, server -> raider only (LockpickFeel remote), ~15x
-- a second while picking. Never carries the sweet spot outside Studio (R5):
-- Closeness is only sent while the lock is stalled (it drives the shake),
-- so sweeping the pick without turning reveals nothing.
export type LockpickFeel = {
	Stage: number,
	Stages: number,
	LockAngle: number, -- degrees, 0 .. Config FullTurn
	Stalled: boolean,
	Closeness: number, -- 0..1, only while Stalled (else 0)
	Damage: number, -- 0..1 wear on the current pick
	Lockout: number, -- seconds left fitting a fresh pick (0 = ready)
	Picks: number,
	Event: string?, -- "solved" | "broke" | "open" on the update that caused it
	Debug: { Center: number, SweetWidth: number, PartialWidth: number }?, -- Studio overlay only
}

-- What a raid's raider / escort / victim sees (RaidState remote). Times are
-- workspace:GetServerTimeNow(). Lockpick is only sent to the raider; the
-- dial's live feel comes separately (LockpickFeel).
export type RaidView = {
	Id: string,
	Role: string, -- "Raider" | "Escort" | "Victim"
	Phase: string, -- "Breached" | "Unlocked" | "Carrying"
	EndsAt: number,
	RaiderName: string,
	VictimName: string,
	-- Picking = at the lock and unable to move until it opens or they cancel.
	-- Stage = the stage being picked (1..Stages); Picks = lockpicks left.
	Lockpick: { Picking: boolean, Stage: number, Stages: number, Picks: number }?,
	Loot: { [string]: number }?,
	CanSabotage: boolean,
}

-- Tier = index into Config.Combat.PickaxeTiers; Slot = one of Config.Combat.ArmorSlots.
export type ArmorPiece = { Tier: number, Slot: string }

-- What the owner's Gear menu gets (GearChanged / GetGearState). Gear score is
-- deliberately NOT here: it's never sent to clients (05-items.md § Gear score).
-- Ranks: upgrade id -> ranks bought. Armor.Pieces lists every owned piece.
export type GearState = {
	PickaxeTier: number,
	Points: number,
	PointsUsed: number,
	Ranks: { [string]: number },
	ArmorEquipped: string, -- piece id, "" = none
	ArmorPieces: { { Id: string, Tier: number, Slot: string } },
	Gadgets: { [string]: number },
	Skins: { [string]: number }, -- skin id -> owned count
	EquippedSkin: string, -- "" = the plain pickaxe
}

export type ProfileData = {
	-- Owned by PlayerDataService. Times are Unix seconds from Util/Clock.
	Meta: { Version: number, FirstLoginAt: number, LastActiveAt: number },
	-- 02-core-loop.md § Bank vs Exposed. Grade is kept per unit (05-items.md § Roll 1).
	Resources: ResourceSnapshot,
	-- Research Scrap has its own separate small bank cap (§ Special cases).
	Scrap: { Banked: number, Exposed: number },
	Credits: number,
	-- Breach Charges, gadgets, components: item id -> count.
	Items: { [string]: number },
	-- VaultTier 0 = no Vault Core built yet (FTUE builds it). Archived = D55.
	Base: { VaultTier: number, Archived: boolean, Pieces: { PlacedPiece } },
	-- Pickaxe is a tier index, not an item (only its skins trade, later).
	-- Upgrades: branch name -> set of purchased node ids.
	Gear: { PickaxeTier: number, Upgrades: { [string]: { [string]: boolean } } },
	-- D112: armor pieces, each a unique item (id = GUID, so a stolen spare is
	-- one exact item and can't be copied). Equipped: slot -> piece id ("" =
	-- empty). The worn piece is never stealable (R1); spares are.
	Armor: { Equipped: { [string]: string }, Pieces: { [string]: ArmorPiece } },
	-- Tier 1 only in the slice; permanent (D72). Set of node ids.
	TechPath: { T1: { [string]: boolean } },
	-- Common only in the slice. Set of blueprint ids.
	Blueprints: { Common: { [string]: boolean } },
	-- Id "" = not in a crew. JoinedAt feeds the tenure lockout (D25, D109).
	Crew: { Id: string, JoinedAt: number },
	-- The 48-hour new-account shield is derived from Meta.FirstLoginAt.
	Shields: { PostRaidUntil: number },
	-- Step 6: charges USED per defense piece id (missing = full). Stored as
	-- "used" so a new defense needs no setup and a refill just deletes the key.
	DefenseUse: { [string]: number },
	-- Pickaxe skins: skin id -> how many you own (spares trade in step 9).
	-- EquippedPickaxeSkin "" = the plain tier-coloured pickaxe. R1: never lootable.
	Cosmetics: { PickaxeSkins: { [string]: number }, EquippedPickaxeSkin: string },
	-- Step 7 (D105): newest raids on this player's base, and the raid ids
	-- already applied (so an offline-raid message can never apply twice).
	RaidLog: { Entries: { RaidLogEntry }, Applied: { string } },
	-- D80 bitpacked words (layouts in Config.Data.Packed). Use get/setPacked.
	Packed: { [string]: number },
}

export type SectionName =
	"Meta"
	| "Resources"
	| "Scrap"
	| "Credits"
	| "Items"
	| "Base"
	| "Gear"
	| "Armor"
	| "TechPath"
	| "Blueprints"
	| "Crew"
	| "Shields"
	| "DefenseUse"
	| "Cosmetics"
	| "RaidLog"
	| "Packed"

return {}
