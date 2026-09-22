--!strict
-- Server-only tunables: numbers clients must NEVER see. This module lives in
-- ServerScriptService, which doesn't replicate, unlike src/shared/Config.luau.
-- CLAUDE.md: "Random rolls happen only on the server; odds never replicate
-- to clients." 05-items.md § Odds are not published in-game (D46).
-- Same rules as Config.luau: every value cites its doc section / D#.

local ServerConfig = {
	-- 05-items.md § Roll 1 - GRADE. Order must match Config.Grade.Names.
	-- Weights must sum to 1 (checked by NodeService's Studio self-test).
	-- Multiplier = sell value; unused until NPC selling (step 9).
	Grade = {
		{ Name = "Standard", Weight = 0.85, Multiplier = 1 }, -- [PH] per doc
		{ Name = "Dense", Weight = 0.10, Multiplier = 3 }, -- [PH] per doc
		{ Name = "Volatile", Weight = 0.04, Multiplier = 10 }, -- [PH] per doc
		{ Name = "Prismatic", Weight = 0.009, Multiplier = 50 }, -- [PH] per doc
		{ Name = "Vaultborn", Weight = 0.001, Multiplier = 200 }, -- [PH] per doc
	},

	-- 02 § Pickaxe upgrade tree, Extraction "Grade-odds bonus". Each rank
	-- multiplies every non-Standard weight by (1 + this), then the table is
	-- renormalised. Server-only because it's part of the odds (D46). [PH]
	-- invented: 3 ranks turn 15% non-Standard into ~19%.
	GradeOddsBonusPerRank = 0.1,

	-- 04-world-content.md § Loot table structure (D108; odds PH): the Scav
	-- Captain rolls every bucket separately. Guaranteed = 100%. Server-only.
	CaptainLoot = {
		Common = 0.6, -- "~60%": a gadget (Cases are out of the slice)
		Rare = 0.25, -- "~25%": blueprints (TEMPORARY stand-in, Config.ScavWaves)
		Signature = 0.06, -- "~5-8%": the tier's identity item (TEMPORARY stand-in)
	},
}

local function deepFreeze(value: any)
	if type(value) == "table" and not table.isfrozen(value) then
		table.freeze(value)
		for _, child in value do
			deepFreeze(child)
		end
	end
end
deepFreeze(ServerConfig)

return ServerConfig
