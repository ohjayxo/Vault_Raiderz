--!strict
-- Every tunable number in the game lives here (CLAUDE.md § Architecture
-- rules). Rules for adding a value:
--   * Put it in the section for the system that owns it.
--   * Comment it with its doc section and D#, e.g.  -- 02-core-loop.md § Theft math (D3)
--   * If the docs give no number, invent one and mark it:  -- [PH] invented
--     (and list it in the step summary).
--   * All docs numbers are [PH] until playtested (docs/00-README.md).
-- No magic numbers in game logic. Odds/roll tables that must stay hidden
-- (R5) belong in server-only modules, NOT here, because this module
-- replicates to clients.
--
-- Sections follow docs/10-roadmap.md § Vertical Slice (D107), in build order
-- (docs/13-build-guide.md § Part E). Sections are empty until their step.

local Config = {
	-- ── Step 0 / infrastructure ─────────────────────────────────────────
	-- DataStore/MemoryStore retry + backoff, presence/raid-lock TTLs, per-remote
	-- rate limits. docs/13-build-guide.md § Part D; 06-economy.md § The hard
	-- architectural constraint; D54, D55, D80.
	Data = {},

	-- ── Step 1 ── Server-authoritative data layer ──────────────────────
	-- Profile template defaults, autosave. 05-items.md § Taxonomy; R5.
	-- (Covered mostly by Data above; split out if it grows.)

	-- ── Step 2 ── Node collection + Grade ──────────────────────────────
	-- Resources: Stone, Ore, Riftsalt. 05-items.md § Resources.
	Resources = {},
	-- Node mining, respawn, rich-node landmarks. 05-items.md § Node respawn,
	-- § Rich-node landmarks; D46.
	Nodes = {},
	-- Grade rolls + Vaultborn announcement. 05-items.md § Roll 1 - Grade.
	-- Server-only odds stay out of this file (R5).
	Grade = {},

	-- ── World ───────────────────────────────────────────────────────────
	-- Homestead + small Reaches, server sharding / neighborhoods.
	-- 02-core-loop.md (world zones), § Server sharding (D56, D79).
	World = {},

	-- ── Step 3 ── Vault Core + Bank/Exposed ────────────────────────────
	-- Bank capacity, Exposed, separate Scrap cap. 02-core-loop.md § Bank vs Exposed.
	Bank = {},

	-- ── Step 4 ── Base building + build budget ─────────────────────────
	-- Walls, gates, Vault Core placement, budget. 02-core-loop.md § Base / Home,
	-- § Build budget (D57).
	Base = {},

	-- ── Step 5 ── Combat + pickaxe + upgrade tree ──────────────────────
	-- 3-hit combo, knockback, upgrade branches, respec, gear score.
	-- 02-core-loop.md § Combat, § Pickaxe upgrade tree, § Combat feel;
	-- 05-items.md § Gear score (D92).
	Combat = {},

	-- ── Step 6 ── Defenses + Scav Waves + Scav Captain ─────────────────
	-- 02-core-loop.md § Defenses.
	Defenses = {},
	-- 04-world-content.md § Scav Waves (D59, D87), § Loot table structure;
	-- Scav Captain (D107).
	Scavs = {},

	-- ── Step 7 ── Raiding + lockpick + Chase + escort ──────────────────
	-- 02-core-loop.md § Raiding, § Lockpick skill model, § Theft math,
	-- § The Chase, § Raid log path map (D105); tiers 1-7 only in the slice.
	Raiding = {},
	-- 02-core-loop.md § Raid escort (D101).
	RaidEscort = {},

	-- ── Step 8 ── Breach Charges, Riftsalt, bands, shields ─────────────
	-- 05-items.md § The Riftsalt rule; 02-core-loop.md § Preconditions.
	BreachCharges = {},
	-- Band matchmaking + shields. 01-pillars.md R6; D66, D67, D75, D79, D92.
	RaidProtection = {},

	-- ── Step 9 ── NPC selling, direct trade, Level/Reputation ──────────
	-- 06-economy.md § Two tiers of selling, § NPC price decay (D94).
	NpcSelling = {},
	-- 06-economy.md § Zero-chat trade (D61), § Trade Safety, § Access gating (D82).
	Trade = {},
	-- 03-progression.md § Reputation tracks, § Vaultbreaker Level (D81, D82).
	Progression = {},

	-- ── Step 10 ── Workshop I, Tech Path T1, Research, Blueprints ──────
	-- 03-progression.md § The Workshop (Tier I only).
	Workshop = {},
	-- 03-progression.md § The Tech Path (Tier 1, permanent - D72),
	-- § Tech Path respec (D109), § Node visibility.
	TechPath = {},
	-- 03-progression.md § Research Bench.
	ResearchBench = {},
	-- 03-progression.md § Blueprints (Common only).
	Blueprints = {},

	-- ── Step 11 ── Crews ───────────────────────────────────────────────
	-- 03-progression.md § Crews; 06-economy.md § Crew Vault; D25, D90, D91, D109.
	Crews = {},

	-- ── Step 12 ── Offline production ──────────────────────────────────
	-- One Harvester Drone. 02-core-loop.md § Automation (D110).
	HarvesterDrone = {},

	-- ── Step 13 ── Analytics ───────────────────────────────────────────
	-- 10-roadmap.md § Success criteria (D108).
	Analytics = {},

	-- ── Step 14 ── FTUE ────────────────────────────────────────────────
	-- 02-core-loop.md § FTUE spec, § FTUE hard rules.
	Ftue = {},
}

-- Freeze recursively so no script can accidentally change a tuning value at
-- runtime (Config is read-only; tuning happens in this file).
local function deepFreeze(value: any)
	if type(value) == "table" and not table.isfrozen(value) then
		table.freeze(value)
		for _, child in value do
			deepFreeze(child)
		end
	end
end
deepFreeze(Config)

return Config
