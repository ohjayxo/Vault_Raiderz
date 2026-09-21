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

	-- ── Step 0B ── THROWAWAY mobile performance spike ──────────────────
	-- Delete this whole section with src/server/PerfSpike,
	-- src/client/PerfSpikeHud.client.luau, the PerfSpikeSetPreset remote and
	-- docs-build/perfspike/ once the numbers are recorded.
	-- 10-roadmap.md § Known Risks #3; 09-research.md § Rendering & Mobile
	-- Performance Budget; 13-build-guide.md § Step 0.
	PerfSpike = {
		Enabled = false, -- off while building step 1; set true to run the phone test again
		DefaultPreset = "Solo", -- first in the run order (the button steps down Presets)
		-- Set false and the server just skips building the scene.

		-- The budget under test. Straight from the docs (baseline device target).
		Budget = {
			Triangles = 1_000_000, -- 09-research.md § Rendering & Mobile Performance Budget
			DrawCalls = 1_000, -- same section
			MeshPartTriangles = 20_000, -- same section (hard import cap, ~20-21k)
		},

		-- The docs give NO frame-rate target, so these are [PH] invented pass lines.
		-- Judge them on the cheapest phone, in Baseline + Overview.
		Fps = {
			Pass = 30, -- [PH] invented: average FPS at or above this passes
			WorstPass = 20, -- [PH] invented: "1% low" (slowest 1% of frames) at or above this
			Comfortable = 45, -- [PH] invented: average FPS that feels good
		},

		-- HUD sampling. [PH] invented.
		RecordSeconds = 15,
		LowWindowSeconds = 10,
		LowPercentile = 0.01, -- "1% low" = the slowest 1% of frames (stutter, not the average)
		-- After a preset/view change the phone is still downloading parts and
		-- warming up; readings taken sooner would be misleading.
		SettleSeconds = 8,
		ResultsShown = 6, -- how many Record results stay on screen (2 lines each)

		-- Tags keep spike objects apart from real systems (greybox contract,
		-- CLAUDE.md). Real systems use ResourceNode / VaultCore / etc.
		Tags = {
			Base = "PerfSpikeBase",
			Node = "PerfSpikeNode",
			Npc = "PerfSpikeNpc",
		},

		-- Where the imported meshes live in the place file (ServerStorage).
		KitFolderName = "PerfSpikeKit",

		-- Floating-island layout. 02-core-loop.md § Server sharding gives no
		-- distances, so all of these are [PH] invented.
		Layout = {
			GridSize = 3, -- 3x3 = the player's base + 8 neighbors (prompt 0B)
			IslandSpacing = 180, -- [PH] invented: studs between neighboring island centers
			BaseHeight = 120, -- [PH] invented: studs above the baseplate
			HeightJitter = 30, -- [PH] invented: +/- studs so it reads as an archipelago
			YawJitterDegrees = 180, -- [PH] invented
			Seed = 4242, -- same layout every run so results compare
			PlateSize = Vector3.new(56, 1, 56), -- the Hitbox "ground" each base stands on
			WallRingRadius = 22, -- [PH] invented
			WallRingStep = 3, -- [PH] invented: studs between extra wall rings
			DefenseRingRadius = 12, -- [PH] invented
			DecorMinRadius = 8, -- [PH] invented
			DecorMaxRadius = 30, -- [PH] invented
			WorkshopOffset = Vector3.new(-12, 0, -12), -- [PH] invented
			SpawnOffset = Vector3.new(0, 0.5, 17), -- [PH] invented
			SpawnSize = Vector3.new(6, 1, 6), -- [PH] invented
			NodeRingRadius = 26, -- [PH] invented
			NpcWanderRadius = 20, -- [PH] invented
		},

		-- Stand-in "mid-tier base" (ASSUMPTION - no doc gives piece counts; D57
		-- only says a tier-scaled budget exists). ~25,100 triangles in 28 pieces
		-- at 1x. Tris MUST match docs-build/perfspike/gen_meshes.py.
		--   Scales = true  -> count is multiplied by the preset's PieceMultiplier
		--   (bases grow by adding walls/defenses/decor, which is what D57 caps).
		Kit = {
			{ Key = "Island", Count = 1, Tris = 5000, Size = Vector3.new(64, 26, 64), Material = "Slate", Color = Color3.fromRGB(110, 100, 90), Scales = false },
			{ Key = "Vault", Count = 1, Tris = 4000, Size = Vector3.new(14, 10, 14), Material = "Metal", Color = Color3.fromRGB(150, 150, 160), Scales = false },
			{ Key = "Wall", Count = 12, Tris = 500, Size = Vector3.new(8, 5, 1), Material = "Concrete", Color = Color3.fromRGB(160, 160, 155), Scales = true },
			{ Key = "Gate", Count = 2, Tris = 1000, Size = Vector3.new(8, 7, 2), Material = "WoodPlanks", Color = Color3.fromRGB(140, 100, 60), Scales = true },
			{ Key = "Defense", Count = 3, Tris = 800, Size = Vector3.new(3, 5, 3), Material = "DiamondPlate", Color = Color3.fromRGB(200, 90, 80), Scales = true },
			{ Key = "Workshop", Count = 1, Tris = 2500, Size = Vector3.new(10, 6, 8), Material = "Brick", Color = Color3.fromRGB(170, 110, 90), Scales = false },
			{ Key = "Decor", Count = 8, Tris = 400, Size = Vector3.new(2.5, 2.5, 2.5), Material = "Granite", Color = Color3.fromRGB(120, 130, 120), Scales = true },
		},

		-- Built-in materials handed out at random in Varied presets. Each different
		-- material is a separate draw batch, so this stands in for "many different
		-- assets". It is capped at (#meshes x #materials) combinations, so it shows
		-- the trend but not the full cost of hundreds of truly unique models.
		-- [PH] invented list.
		VariedMaterials = {
			"Slate", "Concrete", "Brick", "WoodPlanks", "Metal", "DiamondPlate",
			"Granite", "Cobblestone", "Marble", "Limestone", "Pebble", "CorrodedMetal",
		},

		-- Resource nodes: a dozen, spread over the built islands (prompt 0B).
		Nodes = {
			Count = 12,
			Tris = 300, -- matches gen_meshes.py
			Size = Vector3.new(4, 5, 4),
			Material = "Slate",
			Types = { "Stone", "Ore", "Riftsalt" }, -- 05-items.md § Resources
			GradeTiers = 4, -- spike-only visual tiers; not the real Grade table (R5)
		},

		-- Grade-style particle effects, built-in emitters only. Two per node
		-- gives ~60 live particles per node (~720 across 12). [PH] invented.
		Fx = {
			GlowRate = 15,
			GlowLifetime = NumberRange.new(1.5, 2.5),
			GlowSpeed = NumberRange.new(0.5, 1),
			GlowSize = 1.5, -- studs, shrinking to 0 over the particle's life
			GlowTransparency = 0.3, -- fading to fully transparent
			GlowLightEmission = 0.7,
			SparkRate = 30,
			SparkLifetime = NumberRange.new(0.8, 1.2),
			SparkSpeed = NumberRange.new(4, 8),
			SparkSize = 0.3,
			SparkSpread = 180, -- degrees
			SparkAcceleration = Vector3.new(0, -6, 0), -- gravity-ish arc
		},

		-- Default R15 rigs wandering around (prompt 0B).
		Npc = {
			WalkSpeed = 10, -- [PH] invented
			RepathSeconds = 2, -- [PH] invented
		},

		-- Overview camera: sits above/behind your base so all 9 islands are in
		-- frame at once (the "scout your neighbors" worst case).
		Overview = {
			Offset = Vector3.new(0, 330, 330), -- [PH] invented, relative to your base
		},

		-- Per-player limit on preset changes (server rebuilds the scene).
		PresetCooldownSeconds = 3, -- [PH] invented

		-- Each preset is one test condition. Switch on the phone with the HUD.
		-- Listed in the order you should run them (the button steps down this list).
		--   Neighbors: 0..8 other bases built around yours
		--   PieceMultiplier: multiplies the Scales=true kit counts (D57's dial)
		--   Fx: node particle emitters on/off
		--   Npcs: wandering rigs
		--   Varied: every piece gets one of VariedMaterials instead of its kit
		--     material (tests how draw calls climb once pieces stop being identical)
		--   RenderFidelity: recorded label only; scripts can't set it (Plugin capability)
		Presets = {
			{ Name = "Solo", Neighbors = 0, PieceMultiplier = 1, Fx = false, Npcs = 0, Varied = false, RenderFidelity = "Automatic" },
			{ Name = "Baseline", Neighbors = 8, PieceMultiplier = 1, Fx = true, Npcs = 4, Varied = false, RenderFidelity = "Automatic" },
			-- Same pieces and layout as Baseline; only the materials differ.
			{ Name = "Varied", Neighbors = 8, PieceMultiplier = 1, Fx = true, Npcs = 4, Varied = true, RenderFidelity = "Automatic" },
			{ Name = "Extreme", Neighbors = 8, PieceMultiplier = 4, Fx = true, Npcs = 4, Varied = false, RenderFidelity = "Automatic" },
			-- Past the docs' budget on purpose, to find where this phone gives in.
			-- 8x is ~109% and 16x ~207% of the 1M triangle budget (server-claimed).
			{ Name = "Limit", Neighbors = 8, PieceMultiplier = 8, Fx = true, Npcs = 4, Varied = false, RenderFidelity = "Automatic" },
			{ Name = "Over", Neighbors = 8, PieceMultiplier = 16, Fx = true, Npcs = 4, Varied = false, RenderFidelity = "Automatic" },
			-- Extras: earlier presets, saturated the frame cap on a flagship phone.
			{ Name = "Heavy", Neighbors = 8, PieceMultiplier = 2, Fx = true, Npcs = 4, Varied = false, RenderFidelity = "Automatic" },
			{ Name = "NoFx", Neighbors = 8, PieceMultiplier = 1, Fx = false, Npcs = 0, Varied = false, RenderFidelity = "Automatic" },
			{ Name = "Shard", Neighbors = 3, PieceMultiplier = 1, Fx = true, Npcs = 4, Varied = false, RenderFidelity = "Automatic" },
			-- Identical to Baseline (see RenderFidelity note above); kept only so old notes line up.
			{ Name = "Precise", Neighbors = 8, PieceMultiplier = 1, Fx = true, Npcs = 4, Varied = false, RenderFidelity = "Precise" },
		},
	},

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
