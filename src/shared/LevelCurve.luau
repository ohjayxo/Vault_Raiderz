--!strict
-- XP -> level math for the Reputation tracks and the player Level
-- (03-progression.md § Reputation tracks, § Level; D81, D82).
-- Pure functions, shared so UI can draw progress bars. The server is still the
-- only one that grants XP (R5). Numbers live in Config.Progression.LevelCurve.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local curve = Config.Progression.LevelCurve

local LevelCurve = {}

-- Total XP a track needs to reach `level` (level 0 = 0 XP).
function LevelCurve.xpForTrackLevel(level: number): number
	if level <= 0 then
		return 0
	end
	return math.floor(curve.BaseXP * level ^ curve.Exponent)
end

-- The track level reached with `xp` XP.
function LevelCurve.trackLevel(xp: number): number
	if xp <= 0 then
		return 0
	end
	-- Invert the formula, then nudge by one either way to undo float rounding.
	local level = math.floor((xp / curve.BaseXP) ^ (1 / curve.Exponent))
	while level > 0 and LevelCurve.xpForTrackLevel(level) > xp do
		level -= 1
	end
	while LevelCurve.xpForTrackLevel(level + 1) <= xp do
		level += 1
	end
	return level
end

-- Level = the sum of the three track levels (D82).
function LevelCurve.playerLevel(minerXP: number, traderXP: number, raiderXP: number): number
	return LevelCurve.trackLevel(minerXP) + LevelCurve.trackLevel(traderXP) + LevelCurve.trackLevel(raiderXP)
end

-- Checks the inverse matches the formula at every level up to `maxLevel`.
function LevelCurve.selfTest(maxLevel: number)
	for level = 0, maxLevel do
		local xp = LevelCurve.xpForTrackLevel(level)
		assert(LevelCurve.trackLevel(xp) == level, `LevelCurve self-test: level {level} at exactly {xp} XP`)
		if level > 0 then
			assert(LevelCurve.trackLevel(xp - 1) == level - 1, `LevelCurve self-test: just below level {level}`)
		end
	end
	print(`[LevelCurve] self-test passed (levels 0-{maxLevel})`)
end

return LevelCurve
