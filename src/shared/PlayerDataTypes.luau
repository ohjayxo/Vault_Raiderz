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
-- Both sides get an entry (Josh, 2026-09-23): AsRaider = a raid you did
-- (Taken = what you got), else a raid on your base (Taken = what you lost).
export type RaidLogEntry = {
	Id: string,
	At: number,
	RaiderName: string,
	VictimName: string?,
	AsRaider: boolean?,
	Note: string?, -- why a raid failed ("knocked loose", "time ran out", ...)
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
	-- Carrying: the carrier's distance from the victim plot's centre, in
	-- Config.Raiding.ChaseProgressStepStuds steps (the server's number).
	ChaseStuds: number?,
	-- D115: the carrier's grip left (0..Config.Raiding.GripDamage). Only sent
	-- to the raider and the victim while Carrying.
	Grip: number?,
}

-- Your own raid shields (ShieldState / GetShieldState), as seconds left
-- (0 = none), so the client's clock never matters. 01 R6; D67, D75.
export type ShieldState = { NewAccountSeconds: number, PostRaidSeconds: number }

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
	Items: { [string]: number }, -- every counted item you own (gadgets, lockpicks...): the Bag shows them
}

-- One line of a trade offer (TradeService). Kind: "Resource" (Id = resource,
-- Grade set), "Item" (a counted item), "Skin" (a pickaxe skin). Credits are a
-- separate number, not a line.
export type TradeLine = { Kind: string, Id: string, Grade: string?, Amount: number }

-- What one side puts in the window: Credits plus lines.
export type TradeOffer = { Credits: number, Lines: { TradeLine } }

-- One finished trade in your history (06 § Trade Safety: dispute log).
-- Gave/Got are from YOUR side. Id is shared by both players' entries.
export type TradeRecord = {
	Id: string,
	At: number,
	WithName: string,
	-- A string: Studio "Clients and Servers" players have NEGATIVE UserIds,
	-- which a profile can't hold as a number (PlayerDataService.validate).
	WithUserId: string,
	Gave: TradeOffer,
	Got: TradeOffer,
}

-- What each trade window client gets (TradeState). Times are
-- workspace:GetServerTimeNow(). BelowMarket is per viewer: true when YOU
-- would get far less than you give by the NPC reference price.
export type TradeView = {
	Id: string,
	Version: number,
	YourName: string,
	TheirName: string,
	Yours: TradeOffer,
	Theirs: TradeOffer,
	YouConfirmed: boolean,
	TheyConfirmed: boolean,
	LockEndsAt: number,
	BelowMarket: boolean,
}

-- The three Reputation tracks (D81) and the Level (D82), all derived from
-- the packed XP. Prev/Next = XP at this track level / the next one.
export type TrackState = { Level: number, XP: number, Prev: number, Next: number }
export type ReputationState = {
	Level: number,
	Tracks: { [string]: TrackState },
	TradeUnlocked: boolean,
}

-- The NPC buyer's panel (GetSellQuote / SellUnits). Price = Credits for the
-- NEXT unit of that Grade; Percent = today's price as a share of full.
-- PayoutOne / PayoutTen / PayoutAll = what the server would pay right now for
-- 1 / 10 / all of that Grade (price decay included, so the Sell chips can show
-- the real number). ResetsIn = seconds until prices reset (D94, UTC midnight).
export type SellQuote = {
	ResetsIn: number,
	Resources: {
		[string]: {
			Percent: number,
			Grades: { [string]: { Have: number, Price: number, PayoutOne: number, PayoutTen: number, PayoutAll: number } },
		},
	},
}

export type ProfileData = {
	-- Owned by PlayerDataService. Times are Unix seconds from Util/Clock.
	Meta: { Version: number, FirstLoginAt: number, LastActiveAt: number },
	-- 02-core-loop.md § Bank vs Exposed. Grade is kept per unit (05-items.md § Roll 1).
	Resources: ResourceSnapshot,
	-- Research Scrap has its own separate small bank cap (§ Special cases).
	Scrap: { Banked: number, Exposed: number },
	Credits: number,
	-- D94: NPC units sold on UTC day `Day` (Clock.now() // 86400), per
	-- resource. A new day starts a fresh count (EconomyService).
	-- EverSold: the player has made at least one NPC sale (the HUD shows the
	-- Credits line only after that: FTUE hard rule 5 hides 06-economy at first).
	NpcSales: { Day: number, Units: { [string]: number }, EverSold: boolean },
	-- Newest first, capped at Config.Trade.HistoryMax (TradeService).
	TradeHistory: { TradeRecord },
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
	-- Owned by RaidProtectionService (step 8). The 48-hour new-account shield
	-- is derived from Meta.FirstLoginAt; NewAccountEnded = the player gave it
	-- up early by breaching someone (Josh's call). PostRaidUntil = Clock time
	-- the 30-min post-offline-raid shield ends (0 = none).
	Shields: { PostRaidUntil: number, NewAccountEnded: boolean },
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
	| "NpcSales"
	| "TradeHistory"
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
