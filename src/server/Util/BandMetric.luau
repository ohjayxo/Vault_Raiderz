--!strict
-- The raid / neighborhood band (R6). Server-only: gear score is never shown
-- to players (05-items.md § Gear score, D92).
--
-- band = highest of: current vault tier, lifetime peak vault tier, and gear
-- score converted to tier units (D66, D79; conversion = Josh's call, step 4,
-- Config.Sharding.GearScorePerBandTier).
--
-- gear score = pickaxe tier index x 10 + 1 per purchased pickaxe upgrade
-- node + highest armor tier OWNED x 10 (D92, D112). [PH] coefficients in
-- Config.Combat.GearScore.
--
-- Pure functions over profile data, so offline raids (step 7) can run them
-- on a victim's saved profile without the victim being online.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)

export type GearData = { PickaxeTier: number, Upgrades: { [string]: { [string]: boolean } } }
export type ArmorData = { Equipped: { [string]: string }, Pieces: { [string]: Types.ArmorPiece } }
export type Inputs = {
	VaultTier: number,
	LifetimePeakVaultTier: number,
	Gear: GearData,
	Armor: ArmorData,
}

local BandMetric = {}

function BandMetric.gearScore(gear: GearData, armor: ArmorData): number
	local points = Config.Combat.GearScore
	local upgradeNodes = 0
	for _, nodes in gear.Upgrades do
		for _, bought in nodes do
			if bought then
				upgradeNodes += 1
			end
		end
	end
	local bestArmorTier = 0
	for _, piece in armor.Pieces do
		bestArmorTier = math.max(bestArmorTier, piece.Tier)
	end
	return gear.PickaxeTier * points.PointsPerTier
		+ upgradeNodes * points.PointsPerUpgradeNode
		+ bestArmorTier * points.PointsPerArmorTier
end

function BandMetric.band(inputs: Inputs): number
	local gearTiers = math.floor(BandMetric.gearScore(inputs.Gear, inputs.Armor) / Config.Sharding.GearScorePerBandTier)
	return math.max(inputs.VaultTier, inputs.LifetimePeakVaultTier, gearTiers)
end

return BandMetric
