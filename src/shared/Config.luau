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
	Data = {
		-- DataStore name for player profiles. Changing it means every player
		-- starts fresh, so only change it on purpose.
		StoreName = "PlayerData",
		-- Studio Play/tests use separate stores, so debug Credits/XP and test
		-- players never reach the live game's saves.
		StudioStoreName = "PlayerData_Studio",
		KeyPrefix = "Player_", -- profile key = KeyPrefix .. UserId (also the presence key)
		-- Bump when a migration is added in PlayerDataService/Migrations.luau.
		-- Adding a NEW field doesn't need a bump: Reconcile() fills it in.
		SchemaVersion = 2, -- 2: SprintRecovery upgrade nodes renamed StunRecovery

		-- Which service may write each profile section. CLAUDE.md: "Only a
		-- system's own service mutates its data." Services that don't exist
		-- yet are named after the build step that creates them.
		SectionOwners = {
			Meta = "PlayerDataService",
			Packed = "PlayerDataService", -- written only through setPacked (per-field owners below)
			Resources = "VaultService", -- step 3 (02-core-loop.md § Bank vs Exposed)
			Scrap = "VaultService", -- step 3 (separate small Scrap cap)
			Credits = "EconomyService", -- step 9 (06-economy.md § Currencies)
			NpcSales = "EconomyService", -- step 9: units sold to the NPC today, per resource (D94)
			TradeHistory = "TradeService", -- step 9: newest direct trades (06 § Trade Safety)
			Items = "InventoryService", -- charges, gadgets, components (05-items.md § Taxonomy)
			Base = "PlotService", -- step 4 (02-core-loop.md § Base / Home; named in 14 § Prompt 4)
			Gear = "PickaxeService", -- step 5 (02-core-loop.md § Pickaxe upgrade tree)
			Armor = "ArmorService", -- step 5 (D112: craftable armor pieces)
			TechPath = "TechPathService", -- step 10 (Tier 1 only, permanent - D72)
			Blueprints = "ResearchService", -- step 10 (Common only)
			Crew = "CrewService", -- step 11
			Shields = "RaidProtectionService", -- step 8 (R6, D67, D75)
			DefenseUse = "DefenseService", -- step 6: charges used per defense piece
			Cosmetics = "CosmeticService", -- pickaxe skins (05 § Cosmetics; R1: never lootable)
			RaidLog = "RaidService", -- step 7: raid log + applied raid ids (D105)
		},

		-- D80: small per-player fields bitpacked from the start. Each word is one
		-- saved number (max 53 bits). Bit widths are [PH] invented; a value past
		-- its maximum is clamped and logged, and widening one needs a migration.
		Packed = {
			-- 03-progression.md § Reputation tracks (D81). Level is
			-- the sum of these tracks (D82), so it is derived, not stored.
			Reputation = {
				{ Name = "MinerXP", Bits = 17, Owner = "ReputationService" }, -- [PH] invented: max 131,071
				{ Name = "TraderXP", Bits = 17, Owner = "ReputationService" }, -- [PH] invented
				{ Name = "RaiderXP", Bits = 17, Owner = "ReputationService" }, -- [PH] invented
			},
			-- R6 / D66: raid band uses lifetime peak vault tier.
			Progress = {
				{ Name = "LifetimePeakVaultTier", Bits = 4, Owner = "PlotService" }, -- tiers 0-10 fit in 4 bits
			},
		},

		-- D55 / 02-core-loop.md § Plot lifecycle: archive after ~1 year [PH].
		ArchiveAfterDays = 365,

		-- Retries for DataStore/MemoryStore calls (CLAUDE.md; 13-build-guide.md
		-- § B8: Studio quota is tiny, never spam). All [PH] invented.
		Backoff = {
			BaseSeconds = 1, -- first retry waits ~1 s, then 2, 4, 8...
			MaxSeconds = 30,
			MaxAttempts = 5,
			Jitter = 0.25, -- +/- 25% so many servers don't retry in lockstep
		},

		-- Presence keys for offline raids (13-build-guide.md § Part D, step 1).
		Presence = {
			MapName = "Presence",
			StudioMapName = "Presence_Studio", -- Studio presence can't block live offline raids
			TtlSeconds = 60, -- [PH] invented: a crashed server's keys vanish within a minute
			RefreshSeconds = 20, -- [PH] invented: 3 writes/min/player, well inside quota
		},

		-- Login after an offline raid: how long to wait for the save that
		-- pulls the theft in before loading anyway (review 2026-09-22 #1).
		MessagePullTimeoutSeconds = 10, -- [PH] invented
		-- Studio-only debug commands.
		DebugCooldownSeconds = 0.5, -- [PH] invented
		DebugCreditGrant = 1000, -- [PH] invented (step 9: enough to test trades)
		DebugXPGrant = 500, -- [PH] invented: 7 presses = Miner level 10 (3,162 XP)
		DebugSprintSerumGrant = 999, -- Studio key 0: to EVERY player on the server (Josh's test request)
	},

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
	-- Resources: Stone, Ore, Riftsalt. 05-items.md § Resources (Voltstone is
	-- out of the slice, 10-roadmap.md § Vertical Slice).
	Resources = {
		Types = { "Stone", "Ore", "Riftsalt" },
		-- 05-items.md § The Riftsalt rule: may only spawn in Contested zones
		-- (Config.World.Zones). NodeService refuses to start otherwise.
		ContestedOnly = { Riftsalt = true },
	},
	-- Node mining, respawn. 05-items.md § Node respawn (D38). Rich-node
	-- landmarks (D39) are Voltstone, which is out of the slice: nothing here.
	Nodes = {
		Tag = "ResourceNode", -- greybox contract (13-build-guide.md § Part D)
		LiveFolderName = "Nodes", -- Workspace folder the server spawns live nodes into
		TemplateFolderName = "NodeTemplates", -- ServerStorage (src/assets/NodeTemplates)
		SpawnFolderName = "NodeSpawns", -- spawn-point folder inside each island model
		-- Studs from the character to the nearest point of the node's Hitbox.
		-- The client also checks this, only to say "walk closer".
		MineDistance = 12, -- [PH] invented
		-- Seconds between two hits that count. Step 5's Extraction "mine speed"
		-- upgrade will shorten it (02-core-loop.md § Pickaxe upgrade tree).
		-- Taps faster than this are ignored quietly (not an anomaly).
		MineCooldownSeconds = 0.5, -- [PH] invented
		-- Anti-spam on the MineNode remote (13-build-guide.md § Part D: "every
		-- remote has a server-side rate limit"). A burst bucket set above what a
		-- human can tap; going over it is logged as an anomaly.
		MineRateLimit = {
			Burst = 10, -- [PH] invented: requests allowed back-to-back
			PerSecond = 8, -- [PH] invented: sustained requests per second
		},
		-- Per resource: hits before the node is used up, units per hit.
		-- Grade does NOT change the amount: it's a value multiplier (05 § Roll 1).
		Types = {
			Stone = { Hits = 6, YieldPerHit = 3 }, -- [PH] invented ("abundant", 05 § Resources)
			Ore = { Hits = 5, YieldPerHit = 2 }, -- [PH] invented
			Riftsalt = { Hits = 4, YieldPerHit = 1 }, -- [PH] invented
		},
		-- D38: Homestead nodes keep a fixed respawn (FTUE predictability).
		FixedRespawnSeconds = 30, -- [PH] invented
		-- D38: Reaches nodes "deplete and migrate": they come back after a
		-- random delay at a DIFFERENT spawn point, not on a predictable clock.
		MigrateDelaySeconds = { Min = 45, Max = 90 }, -- [PH] invented
		DebugSpamCount = 50, -- Studio-only rate-limit test (key M)
		-- Client tap handling. UX only; the server re-checks distance.
		-- [PH] invented, REVISIT (step 2 review L2).
		PickRangeStuds = 1000, -- how far a tap ray looks for a node
		WalkCloserHintSeconds = 1.5, -- how long "Walk closer to mine" shows
	},
	-- Grade rolls + Vaultborn announcement. 05-items.md § Roll 1 - Grade.
	-- Server-only odds stay out of this file (R5, D46): they live in
	-- src/server/ServerConfig.luau. Names and visuals only here.
	-- Rolled once PER HIT ("every tap is a lottery ticket"): Josh's call, step 2.
	Grade = {
		Names = { "Standard", "Dense", "Volatile", "Prismatic", "Vaultborn" }, -- 05-items.md § Roll 1
		-- Greybox effects at the node, seen by every player (Josh's call, step 2:
		-- "Rainbow, visible across the map", "Beam of light", 05 § Roll 1).
		-- Standard has no effect. All numbers [PH] invented.
		Fx = {
			Dense = { Seconds = 1.5, BeamHeight = 0, Color = Color3.fromRGB(230, 240, 255) }, -- faint shimmer
			Volatile = { Seconds = 2, BeamHeight = 0, Color = Color3.fromRGB(255, 220, 90) }, -- crackling
			Prismatic = { Seconds = 5, BeamHeight = 250, Color = Color3.fromRGB(255, 255, 255) }, -- rainbow (color cycles)
			Vaultborn = { Seconds = 8, BeamHeight = 500, Color = Color3.fromRGB(255, 235, 170) }, -- beam of light
		},
		RainbowCycleSeconds = 1.5, -- [PH] invented: Prismatic hue loop
		-- Vaultborn beam (Josh's call, 2026-09-21, review M2): faint, blinking
		-- and fading, so you can miss it if you're scanning quickly but a
		-- hypervigilant player can spot where the strike was. Tune by eye.
		VaultbornBeam = { -- [PH] invented
			Transparency = 0.8, -- when "on", at the start (1 = invisible)
			BlinkSeconds = 0.8, -- one on/off cycle
			OnFraction = 0.3, -- share of each cycle it's visible
			Width = 1.5, -- studs (other beams use FxLook.BeamWidth)
		},
		-- Client-side look of every Grade burst. Visual only, never gameplay.
		-- [PH] invented, REVISIT with real art (step 2 review L2).
		FxLook = {
			ParticlesDense = 12, -- Dense is a "faint shimmer" (05 § Roll 1)
			ParticlesOther = 40, -- Volatile / Prismatic / Vaultborn
			ParticleSpeed = NumberRange.new(4, 10),
			ParticleLifetime = NumberRange.new(0.5, 1),
			ParticleSize = 0.4, -- studs, shrinking to 0
			SpreadDegrees = 180,
			LightRange = 16, -- studs
			LightBrightness = 2,
			BeamWidth = 3, -- studs
			BeamTransparency = 0.3,
		},
	},

	-- ── World ───────────────────────────────────────────────────────────
	-- Homestead + small Reaches, server sharding / neighborhoods.
	-- 02-core-loop.md § World Structure, § Server sharding (D56, D79).
	-- Greybox layout lives in docs-build/worldgen/gen_world.py (-> src/world).
	World = {
		FolderName = "World", -- Workspace folder (Rojo: src/world)
		-- Keyed by each island model's Zone attribute.
		--   Respawn "Fixed": every spawn point always has a node (Homestead, D38)
		--   Respawn "Migrate": only ActiveNodes per type are live; they move (D38)
		--   Contested: 05-items.md § The Riftsalt rule ("contested zones only").
		--   Josh's call, 2026-09-21: a zone flag. The Homestead is never
		--   contested, even though PvP is on there.
		-- Placeholder spots in the south plaza (02 § Slice layout, D113):
		-- invisible tagged parts, no behaviour yet.
		Slots = {
			NpcBuyer = "NpcBuyerSlot", -- step 9
			DerelictVault = "DerelictVaultSlot", -- step 14 (FTUE 4:00-6:00)
		},
		Zones = {
			Homestead = { DisplayName = "the Homestead Ring", Respawn = "Fixed", Contested = false },
			Reaches = {
				DisplayName = "the Reaches",
				Respawn = "Migrate",
				Contested = true,
				ActiveNodes = { Ore = 3, Riftsalt = 2 }, -- [PH] invented (6 and 5 spawn points)
			},
		},
	},

	-- ── Broadcasts ──────────────────────────────────────────────────────
	-- One rate-limited, prioritized queue for every server-wide announcement.
	-- 06-economy.md § Broadcast priority queue (D58).
	Broadcast = {
		-- Lower number = more important. D58 fixes the ends: raid-owner alerts
		-- and Chase pings highest, cosmetic flex lowest (dropped first).
		-- Vaultborn in the middle: Josh's call, step 2.
		Priorities = {
			RaidAlert = 1, -- step 7
			ChasePing = 1, -- step 7
			Vaultborn = 2,
			CosmeticFlex = 3,
		},
		NeverDropPriority = 1, -- D58: "never a raid alert"; kept even past MaxPending
		MinGapSeconds = 4, -- [PH] invented: at most one banner per this many seconds
		MaxPending = 6, -- [PH] invented: waiting-line length before drops start
		BannerSeconds = 4, -- [PH] invented: how long the client shows one banner
		-- Banner colour per kind; unlisted kinds use DefaultBannerColor.
		-- [PH] invented, REVISIT with real UI (step 2 review L2).
		BannerColors = {
			RaidAlert = Color3.fromRGB(170, 30, 30),
			ChasePing = Color3.fromRGB(170, 30, 30),
			Vaultborn = Color3.fromRGB(150, 115, 20),
		},
		DefaultBannerColor = Color3.fromRGB(40, 40, 50),
		-- 05-items.md § Vaultborn announcement: "Holder gets ~30 seconds [PH]
		-- of head start" = the announcement goes out this long after the strike.
		VaultbornHeadStartSeconds = 30,
	},

	-- ── Step 3 ── Vault Core + Bank/Exposed ────────────────────────────
	-- Bank capacity, Exposed, separate Scrap cap. 02-core-loop.md § Bank vs Exposed.
	Bank = {
		-- Banked capacity in TOTAL units (Stone + Ore + Riftsalt, any Grade),
		-- indexed by Vault Core tier. Tier 0 = no Vault Core = nothing can be
		-- banked. "Capped, upgradeable" (02 § Bank vs Exposed); the unit
		-- measure is Josh's call, step 3. Tiers 1-7 only in the slice
		-- (10-roadmap.md § Vertical Slice); a higher tier uses the last entry.
		CapacityByTier = { 500, 1_000, 2_000, 3_500, 5_000, 7_500, 10_000 }, -- [PH] invented
		-- 02 § Special cases: Research Scrap has its own, much smaller cap,
		-- "~20% [PH] of normal" (Q38). Rounded down.
		ScrapCapFraction = 0.2,
		-- 02 § Special cases; 05-items.md § Auto-bank protection: these
		-- Grades go straight into the bank on pickup if there's room.
		AutoBankGrades = { "Prismatic", "Vaultborn" },
		-- Pressing Bank moves Exposed into the bank, best first, until full
		-- (Josh's call, step 3): Grade first, then the rarer resource.
		BankOrderGrades = { "Vaultborn", "Prismatic", "Volatile", "Dense", "Standard" },
		BankOrderResources = { "Riftsalt", "Ore", "Stone" },
		-- Paying for something (building, step 4) takes Exposed before Banked,
		-- lowest Grade first (Josh's call, step 4): "use it before you lose it".
		SpendOrderGrades = { "Standard", "Dense", "Volatile", "Prismatic", "Vaultborn" },

		-- Banking happens at your own Vault Core (Josh's call, step 3). Each is
		-- a placed base piece with an OwnerUserId attribute (step 4).
		VaultCoreTag = "VaultCore", -- greybox contract (13-build-guide.md § Part D)
		BankDistance = 12, -- [PH] invented: studs from the core's Hitbox
		BankCooldownSeconds = 1, -- [PH] invented: per-player limit on banking
		PromptHoldSeconds = 0.5, -- [PH] invented: hold time on the Bank prompt

		-- Per-player limit on the GetVaultState remote.
		SnapshotCooldownSeconds = 0.5, -- [PH] invented
		-- Meter start-up: ask for the vault state until the profile has
		-- loaded. Must wait longer than SnapshotCooldownSeconds between tries.
		-- [PH] invented, REVISIT (step 2 review L2).
		HudStartupTries = 10,
		HudStartupRetrySeconds = 1,

		-- The Banked/Exposed meter. 02-core-loop.md § FTUE spec: it appears at
		-- 2:30-4:00, hidden before that (R4). The server shows/hides it by
		-- setting this attribute on the Player (VaultService.setMeterVisible).
		Meter = {
			VisibleAttribute = "HudVaultMeter",
			-- TEMPORARY until step 14 (FTUE): show the meter as soon as the
			-- profile loads so it can be tested. Step 14 sets this false and
			-- reveals the meter at 2:30 instead.
			ShowBeforeFtue = true,
			-- Look only. [PH] invented, REVISIT with real UI (step 2 review L2).
			Width = 230,
			BarHeight = 14,
			BankedColor = Color3.fromRGB(70, 170, 230),
			ExposedColor = Color3.fromRGB(235, 90, 80),
			BarBackColor = Color3.fromRGB(35, 35, 45),
		},

		-- Studio-only debug grants (keys F and G).
		-- Standard grade, into Exposed. [PH] invented: enough for a Vault Core,
		-- a tier 2 upgrade and some walls/gates in one or two presses.
		DebugResourceGrant = { Stone = 200, Ore = 100, Riftsalt = 20 },
		DebugScrapGrant = 25, -- [PH] invented: Scrap has no source until step 6
	},

	-- ── Step 4 ── Plots, base building + build budget ──────────────────
	-- 02-core-loop.md § World Structure (Homestead Ring = player plots).
	-- Count and SizeStuds must match docs-build/worldgen/gen_world.py (it
	-- checks). Layout: 02 § Slice layout (D113): two rows of four.
	Plots = {
		Tag = "Plot", -- greybox contract: Hitbox = build surface
		-- One plot per player on a server, so set the place's Max Players to
		-- this (Game Settings) or later joiners get no plot.
		Count = 8, -- [PH] invented
		SizeStuds = 48, -- [PH] invented
		GridStuds = 4, -- [PH] invented: one build cell (12 x 12 cells per plot)
		-- Studs from your character to your plot's edge within which you may
		-- build (a fair client builds while standing on it).
		BuildReach = 30, -- [PH] invented
	},
	-- Walls, gates, Vault Core. 02-core-loop.md § Base / Home, § Build budget (D57).
	Base = {
		LiveFolderName = "BasePieces", -- Workspace folder placed pieces go into
		TemplateFolderName = "PieceTemplates", -- ServerStorage (src/assets/PieceTemplates)
		PieceTag = "BasePiece",
		GateTag = "BaseGate",
		-- Per piece: footprint in grid cells {W, D} before rotation, ghost
		-- height (client preview), price, and budget cost.
		-- BudgetCost is RENDER weight (D57's "piece/draw-call budget"): the
		-- step 0B spike showed identical pieces batch almost free and that
		-- triangles and unique materials are what cost frame time, so cost
		-- is meant to track those, not piece count (docs-build/perfspike/
		-- results.md). All [PH] invented until a cheap-phone test.
		Pieces = {
			VaultCore = { Cells = { 2, 2 }, Height = 8, Cost = { Stone = 50 }, BudgetCost = 5 },
			-- Edge = true: sits on the line between cells, so walls meet at
			-- corners (PlotGrid). Cells is unused for edge pieces.
			Wall = { Cells = { 1, 1 }, Height = 6, Cost = { Stone = 20 }, BudgetCost = 2, Edge = true },
			Gate = { Cells = { 1, 1 }, Height = 6, Cost = { Stone = 30, Ore = 10 }, BudgetCost = 3, Edge = true },
			-- Step 6 defenses (02 § Defenses). Behaviour in Config.Defenses.
			TripwireAlarm = { Cells = { 1, 1 }, Height = 2, Cost = { Stone = 30, Ore = 10 }, BudgetCost = 2 },
			SpikeFloor = { Cells = { 2, 2 }, Height = 1, Cost = { Stone = 60, Ore = 20 }, BudgetCost = 3 },
			ShockFence = { Cells = { 1, 1 }, Height = 5, Cost = { Stone = 40, Ore = 30 }, BudgetCost = 3, Edge = true },
			DecoyVault = { Cells = { 2, 2 }, Height = 7, Cost = { Stone = 80, Ore = 20 }, BudgetCost = 4 },
			GuardDrone = { Cells = { 1, 1 }, Height = 6, Cost = { Stone = 60, Ore = 40 }, BudgetCost = 4 },
			LockUpgrade = { Cells = { 1, 1 }, Height = 2, Cost = { Stone = 50, Ore = 50 }, BudgetCost = 2 },
		},
		PieceOrder = { -- build menu order
			"VaultCore", "Wall", "Gate",
			"TripwireAlarm", "SpikeFloor", "ShockFence", "DecoyVault", "GuardDrone", "LockUpgrade",
		},
		-- Build menu tabs, so the row fits a phone screen.
		PieceGroups = {
			{ Name = "Structures", Kinds = { "VaultCore", "Wall", "Gate" } },
			{ Name = "Defenses", Kinds = { "TripwireAlarm", "SpikeFloor", "ShockFence", "DecoyVault", "GuardDrone", "LockUpgrade" } },
		},
		MaxVaultCores = 1, -- one Vault Core per plot
		-- D57: budget per Vault Core tier (index = tier; tier 0 uses tier 1's).
		-- Same length as Config.Bank.CapacityByTier (tiers 1-7 in the slice).
		BudgetByTier = { 40, 60, 90, 130, 180, 240, 300 }, -- [PH] invented
		-- Placing the Vault Core = tier 1 (FTUE "BUILD VAULT", 02 § FTUE spec).
		-- Upgrading to tier n costs UpgradeCostByTier[n]; [1] is unused.
		UpgradeCostByTier = { -- [PH] invented
			{},
			{ Stone = 150, Ore = 30 },
			{ Stone = 300, Ore = 80 },
			{ Stone = 500, Ore = 150 },
			{ Stone = 800, Ore = 250 },
			{ Stone = 1_200, Ore = 400 },
			{ Stone = 1_800, Ore = 600 },
		},
		-- Removing a piece refunds this share of its price, as Standard, to
		-- Exposed (Josh's call, step 4). Under 1 so walls can't be used to hide
		-- resources from raiders and dismantle them later (a bank bypass).
		-- The Vault Core can be moved but never removed.
		RemoveRefundFraction = 0.5, -- [PH] invented
		-- Anti-spam on the build remotes (13-build-guide.md § Part D).
		BuildRateLimit = { Burst = 6, PerSecond = 3 }, -- [PH] invented
		StateCooldownSeconds = 0.5, -- [PH] invented: GetBaseState limit

		-- Build UI. Hidden until shown by the server (player attribute), like
		-- the vault meter, so the FTUE (step 14) can control it (R4).
		BuildUi = {
			VisibleAttribute = "HudBuildButton",
			-- The Build button only shows while you stand on your own plot
			-- (Josh, 2026-09-23); walking off closes build mode. The server's
			-- own limit is Config.Plots.BuildReach. [PH] invented: studs,
			-- measured from your character to the plot's build surface.
			ShowWithinStuds = 6,
			ShowBeforeFtue = true, -- TEMPORARY until step 14, same as Bank.Meter
			-- Set by the build UI on its own client only; NodeInput ignores taps
			-- while it's true. Never replicated, never trusted by the server.
			ClientModeAttribute = "ClientBuildMode",
			-- Look only. [PH] invented, REVISIT with real UI (step 2 review L2).
			ButtonSize = 72, -- px: big enough for thumbs
			GhostTransparency = 0.5,
			EdgeGhostThickness = 1, -- studs: walls/gates/fences are 1 thick
			PiecesPerRow = 3, -- build menu grid, so 6 defenses don't cover Done
			GhostColor = Color3.fromRGB(80, 220, 120),
			SelectColor = Color3.fromRGB(255, 210, 60),
			MessageSeconds = 2,
			-- "Your plot" marker (Josh, 2026-09-23): plots are given, not
			-- picked (02 § Slice layout, D113), and you spawn mid-street, so a
			-- light beam + bouncing arrow only you can see shows which plot is
			-- yours while you're off it. No words (FTUE hard rule 1: arrows and
			-- glows only). Shown with the Build UI, so step 14 controls it too.
			-- Look only. [PH] invented, REVISIT with real effects.
			PlotMarker = {
				BeamHeight = 80, -- studs above the plot surface
				BeamWidth = 3,
				BeamColor = Color3.fromRGB(80, 220, 120),
				BeamTransparency = { 0.35, 0.75 }, -- pulses between these
				PulseSeconds = 1.2,
				ArrowHeight = 14, -- studs above the plot surface
				ArrowBounceStuds = 3,
				ArrowPixels = 64, -- same size on screen at any distance
				CheckSeconds = 0.25, -- how often to re-check "am I on my plot?"
			},
		},
	},

	-- Neighborhood sharding + the raid band. 02-core-loop.md § Server
	-- sharding (D56, D79); § Preconditions (D66); 05-items.md § Gear score (D92).
	Sharding = {
		-- D66 takes the highest of vault tier, lifetime peak and gear score, but
		-- gear score is on a ~10x bigger scale. Josh's call, step 4: convert it
		-- to tier units first: floor(gear score / this).
		GearScorePerBandTier = 10,
	},

	-- ── Step 5 ── Combat + pickaxe + upgrade tree ──────────────────────
	-- 3-hit combo, knockback, upgrade branches, respec, gear score.
	-- 02-core-loop.md § Combat, § Pickaxe upgrade tree, § Combat feel;
	-- 05-items.md § Gear score (D92).
	Combat = {
		PickaxeTiers = { "Wooden", "Iron", "Voltsteel", "Riftedge" }, -- 05-items.md § Pickaxe tiers
		StartingPickaxeTier = 1, -- index into PickaxeTiers (Wooden)
		-- D92 / 05-items.md § Gear score: tier index x 10 + 1 per purchased
		-- PICKAXE upgrade node (the three branches above). Server-only use,
		-- never shown to players. Coefficients [PH] per D92. Built in step 5.
		GearScore = {
			PointsPerTier = 10,
			PointsPerUpgradeNode = 1,
			-- D112: highest armor tier OWNED (worn or spare), so taking armor
			-- off can't lower your raid band (R6). [PH]
			PointsPerArmorTier = 10,
		},
		PickaxeBranches = { "Extraction", "Combat", "Mobility" }, -- 02-core-loop.md § Pickaxe upgrade tree
		-- D112: armor pieces use the same tier names as the pickaxe
		-- (PickaxeTiers). One slot in the slice; add slots here later.
		ArmorSlots = { "Chest" },

		-- Health and death. Dying costs time only: you respawn next to your own
		-- plot and lose nothing (Josh's call, step 5).
		MaxHealth = 100, -- [PH] invented
		RespawnSeconds = 5, -- [PH] invented

		-- 02 § Combat feel (D108): "3-hit combo, generous hitboxes, light aim
		-- assist, short knockback"; fights resolve in 5-10 s [PH]. With these
		-- numbers a Wooden pickaxe kills in 3 combos (~9 swings, ~4.5 s of
		-- solid hits); with misses and movement that's ~6-8 s.
		SwingIntervalSeconds = 0.5, -- [PH] invented: fastest swing that counts
		ComboWindowSeconds = 1.0, -- [PH] invented: swing again within this to continue the combo
		ComboDamageMultipliers = { 1, 1, 1.6 }, -- [PH] invented: hit 3 is the finisher
		DamageByTier = { 10, 13, 16, 20 }, -- [PH] invented: index = PickaxeTiers
		-- Server hit check: target's root within Range studs of yours and within
		-- AimConeDegrees of where you face (either side). Generous on purpose:
		-- the client turns you toward the target (aim assist) but the server
		-- may see that turn a moment late.
		Range = 8, -- [PH] invented
		AimConeDegrees = 75, -- [PH] invented
		-- Client aim assist: on swing, turn to face the nearest target this
		-- close and within this cone. Look only; the server re-checks.
		AimAssistRange = 10, -- [PH] invented
		AimAssistConeDegrees = 100, -- [PH] invented
		Knockback = { -- [PH] invented: studs/second, applied for Seconds
			Speed = 25,
			FinisherSpeed = 55, -- combo hit 3
			UpSpeed = 12,
			Seconds = 0.15,
		},
		SwingRateLimit = { Burst = 6, PerSecond = 4 }, -- [PH] invented: anti-spam on Swing

		-- 02 § Pickaxe upgrade tree (D108): three branches, limited points.
		-- Points come with the pickaxe tier; each node (= one rank of an
		-- upgrade) costs 1 point + resources; respec gives every point back
		-- for a resource fee (Josh's call, step 5). "Respec costs resources,
		-- never Robux." All numbers [PH] invented.
		PointsByTier = { 3, 6, 9, 12 },
		NodeCostByRank = {
			{ Stone = 40 },
			{ Stone = 80, Ore = 20 },
			{ Stone = 150, Ore = 50 },
		},
		RespecCost = { Stone = 100, Ore = 30 },
		-- Per branch, in menu order. PerRank = the effect of each rank:
		--   MineSpeed: mine cooldown -10%/rank    GradeOdds: see ServerConfig
		--   MultiStrike: chance/rank that a hit also mines one nearby node
		--   SwingSpeed: swing interval -8%/rank   Damage: +2 per rank
		--   Knockback: +20%/rank
		--   StunRecovery: stuns and slows on you are 15% shorter/weaker per
		--   rank (was "Sprint recovery"; the docs have no sprint - Josh's call).
		--   CarrySpeed / SilentMovement: Silent movement shrinks tripwire range
		--   (step 6); Carry speed arrives with the Chase (step 7).
		Upgrades = {
			Extraction = {
				{ Id = "MineSpeed", Name = "Mine speed", Ranks = 3, PerRank = 0.1 },
				{ Id = "GradeOdds", Name = "Grade odds", Ranks = 3, PerRank = 0 }, -- value is server-only
				{ Id = "MultiStrike", Name = "Multi-node strike", Ranks = 3, PerRank = 0.15 },
			},
			Combat = {
				{ Id = "SwingSpeed", Name = "Swing speed", Ranks = 3, PerRank = 0.08 },
				{ Id = "Damage", Name = "Damage", Ranks = 3, PerRank = 2 },
				{ Id = "Knockback", Name = "Knockback", Ranks = 3, PerRank = 0.2 },
			},
			Mobility = {
				{ Id = "CarrySpeed", Name = "Carry speed", Ranks = 3, PerRank = 0.1 },
				{ Id = "StunRecovery", Name = "Stun recovery", Ranks = 3, PerRank = 0.15 }, -- [PH] invented
				{ Id = "SilentMovement", Name = "Silent movement", Ranks = 3, PerRank = 0.2 },
			},
		},
		MultiStrikeRadius = 12, -- [PH] invented: studs from the struck node

		-- D112 armor, per tier (index = PickaxeTiers). Kept small so fights
		-- still resolve in 5-10 s. [PH] invented.
		ArmorDamageReduction = { 0.05, 0.1, 0.15, 0.2 },
		ArmorKnockbackResist = { 0.15, 0.3, 0.45, 0.6 },

		GearRequestCooldownSeconds = 0.3, -- [PH] invented: buy/respec/equip limit
		CombatTag = "CombatTarget", -- NPCs (Scavs, step 6) that swings can hit
		-- FTUE hard rule 3 "PvE before PvP": while this Player attribute is true
		-- the player can't hit or be hit by players. Step 14 sets it.
		PvpProtectedAttribute = "PvpProtected",

		-- Stick-and-block greybox pickaxe (14 § Prompt 5). Look only.
		-- Art templates (art-ready pass; docs-build/art-guide.md). Each look
		-- loads its template if present, else falls back to the code greybox.
		TierFolderName = "PickaxeTiers", -- ServerStorage: one Handle+Visual per tier name
		ArmorFolderName = "ArmorTemplates", -- ServerStorage: "<Tier>Chest" = Attach+Visual
		-- Fallback greybox only (used when a PickaxeTiers template is missing).
		ToolLook = { -- [PH] invented, REVISIT with real art
			HandleSize = Vector3.new(0.3, 0.3, 3.5),
			HeadSize = Vector3.new(0.5, 2.4, 0.5), -- across the shaft
			TierColors = {
				Color3.fromRGB(150, 110, 70), -- Wooden
				Color3.fromRGB(170, 170, 180), -- Iron
				Color3.fromRGB(90, 200, 255), -- Voltsteel
				Color3.fromRGB(190, 90, 255), -- Riftedge
			},
		},

		-- Gear menu + attack button. Hidden until the server shows them (R4:
		-- the upgrade tree is depth the FTUE hides). Look values [PH], REVISIT.
		Ui = {
			GearMinScale = 0.5, -- [PH] the Gear menu shrinks to fit small screens, never below this
			GearVisibleAttribute = "HudGearMenu",
			ShowBeforeFtue = true, -- TEMPORARY until step 14
			ButtonSize = 72,
		},
	},

	-- Pickaxe skins. 05-items.md § Pickaxes are not tradeable (D111: the
	-- skins are the tradeable product), § Cosmetics; R1 (never lootable).
	-- A skin = a template model in ServerStorage.PickaxeSkins (src/assets/
	-- PickaxeSkins): a "Handle" part (the grip) + a "Visual" folder (the art).
	-- Adding one = a new model + one line here. A skin replaces the whole
	-- look: the pickaxe tier isn't shown (Josh's call, 2026-09-22).
	-- The Bag (Josh, 2026-09-23): one panel showing everything you own,
	-- split into safe (banked / worn) and at risk (exposed / spare). Opened
	-- from the Bag button, the vault meter, or the Gear menu's Armor/Skin
	-- buttons. Shown with the vault meter (Config.Bank.Meter.VisibleAttribute,
	-- R4). Look only, all [PH] invented.
	Inventory = {
		ButtonLabel = "Bag",
		PanelMaxSize = Vector2.new(640, 340), -- px; the panel also shrinks to 90% of small screens
		RowHeight = 30,
		DisplayOrder = 11, -- the open Bag: above the Gear menu (10) and the raid UI (8)
		ButtonDisplayOrder = 8, -- the Bag BUTTON: HUD level with Raids, under open menus
		-- Counted items on the Items tab, in this order. Gadgets use
		-- Config.Gadgets.Names; others are named here.
		ItemOrder = { "BreachCharge", "Lockpick", "SmokeBomb", "SprintSerum", "ShockTrap", "Disruptor" },
		ItemNames = { BreachCharge = "Breach Charges", Lockpick = "Lockpicks" },
		ShowCredits = true, -- step 9: Credits + Level in the Bag. TEMPORARY until step 14 (FTUE hard rule 5 hides 06)
		ShieldColor = Color3.fromRGB(120, 200, 255), -- look only [PH], REVISIT with real UI
	},
	Cosmetics = {
		SkinFolderName = "PickaxeSkins",
		-- id -> display name. The id is the template model's name.
		PickaxeSkins = {
			CaptainsCleaver = { Name = "Captain's Cleaver" }, -- [PH] name (v5.8)
		},
		SkinOrder = { "CaptainsCleaver" }, -- menu order
		DefaultSkinName = "Standard", -- the plain tier-coloured pickaxe
		DebugSkin = "CaptainsCleaver", -- Studio key 7
	},

	-- Walk speed modifiers (gadgets now; Chase loot slow + carry speed in
	-- step 7). One owner, MovementService, so modifiers never fight.
	Movement = {
		BaseWalkSpeed = 16, -- Roblox default
		BaseJumpPower = 50, -- Roblox default
	},

	-- 02 § Gadgets (D108): single-use; crafted at Workshop I in step 10
	-- (Josh's call, step 5). R8: none of them touches damage.
	Gadgets = {
		TemplateFolderName = "GadgetTemplates", -- ServerStorage (art-ready pass)
		Order = { "SmokeBomb", "SprintSerum", "ShockTrap", "Disruptor" },
		Names = { SmokeBomb = "Smoke Bomb", SprintSerum = "Sprint Serum", ShockTrap = "Shock Trap", Disruptor = "Disruptor" },
		UseCooldownSeconds = 1, -- [PH] invented: per player, any gadget
		-- Smoke Bomb: "breaks line of sight, escape tool". A cloud at your
		-- feet; nobody can target a player inside it from further than
		-- SeeThroughStuds (swings or aim assist).
		Smoke = { Radius = 12, Seconds = 8, SeeThroughStuds = 4 }, -- [PH] invented
		-- Sprint Serum: "8s [PH] speed boost".
		SprintSerum = { Seconds = 8, SpeedMultiplier = 1.5 }, -- multiplier [PH] invented
		-- Shock Trap: "Throwable, brief stun". Thrown ahead, lands, arms; the
		-- first other player or Scav to touch it is stunned (Josh's call, step 5).
		ShockTrap = {
			ThrowDistance = 14, -- [PH] invented
			ArmSeconds = 0.5, -- [PH] invented
			StunSeconds = 1.5, -- [PH] invented
			LifetimeSeconds = 30, -- [PH] invented
			MaxActivePerPlayer = 3, -- [PH] invented
			Size = Vector3.new(3, 0.4, 3),
		},
		-- Disruptor: "Disables one base defense for 15s [PH]". Defenses are
		-- step 6; until then it can't be used (and isn't consumed).
		Disruptor = { Seconds = 15 },
		-- While carrying raid loot, gadgets are disabled (02 § The Chase, 2).
		-- Step 7 sets this Player attribute.
		CarryingLootAttribute = "CarryingLoot",
	},

	-- ── Step 6 ── Defenses + Scav Waves + Scav Captain ─────────────────
	-- 02-core-loop.md § Defenses (D108): "defenses delay and detect. They
	-- never hard-block." Limited slots; charges deplete when triggered and
	-- cost resources to refill. Placed as base pieces (Config.Base.Pieces).
	-- Triggered only by Scavs and, from step 7, raiders of THIS base (Josh's
	-- call, step 6): visitors never burn charges.
	Defenses = {
		Tag = "Defense", -- on every defense piece (plus BasePiece)
		-- D57 lists "Defense slots" among buildables: a cap per vault tier on
		-- top of the build budget (index = tier; tier 0 uses tier 1's).
		SlotsByTier = { 2, 2, 3, 3, 4, 4, 5 }, -- [PH] invented
		TickSeconds = 0.2, -- [PH] invented: how often trigger zones are checked
		-- Per defense. Charges: how many triggers a full refill gives.
		-- RefillCost: price of topping it back up to full. All [PH] invented.
		Kinds = {
			-- "Alerts owner + marks intruder". Radius shrinks with the
			-- intruder's Mobility "Silent movement" ranks (step 5).
			TripwireAlarm = { Charges = 5, RefillCost = { Stone = 20 }, Radius = 10, MarkSeconds = 8, RetriggerSeconds = 10 },
			-- "Slows movement in a zone": the piece's footprint, 1 charge per entry.
			SpikeFloor = { Charges = 8, RefillCost = { Stone = 30 }, SlowMultiplier = 0.45 },
			-- "Brief stun on contact".
			ShockFence = { Charges = 6, RefillCost = { Stone = 20, Ore = 10 }, StunSeconds = 1, Radius = 3.5, RetriggerSeconds = 3 },
			-- "Wastes ~20s [PH] of the 90s window" (raids, step 7). Scavs go
			-- to a charged decoy first and waste this long there.
			DecoyVault = { Charges = 3, RefillCost = { Stone = 40 }, WasteSeconds = 20 },
			-- "NPC harasser": a hovering drone that zaps the nearest intruder.
			GuardDrone = { Charges = 20, RefillCost = { Stone = 30, Ore = 20 }, Radius = 16, ZapSeconds = 1.5, ZapDamage = 4 },
			-- "Increases lockpick difficulty": each charge used = one lockpick
			-- difficulty step (Config.Raiding.Lockpick WidthScalePerStep).
			LockUpgrade = { Charges = 3, RefillCost = { Ore = 30 }, ExtraDifficulty = 1 },
		},
		RefillCooldownSeconds = 0.5, -- [PH] invented
		-- Disruptor gadget (02 § Gadgets): switches off the nearest defense on
		-- someone else's base within this range.
		DisruptorRange = 20, -- [PH] invented
		-- Player attribute step 7 sets on a raider: the UserId of the base
		-- they're raiding. Only then do that base's defenses fire at them.
		RaidingAttribute = "RaidingUserId",
	},

	-- 04-world-content.md § Scav Waves (D108), § Concurrent wave ceiling
	-- (D59), § The PvE ladder (Homestead: Scavs + Scav Captain), § Loot
	-- table structure; D107 (Captain loot goes to the defending owner).
	-- Captain loot odds are server-only (ServerConfig.CaptainLoot).
	Scavs = {
		Tag = "Scav", -- plus Config.Combat.CombatTag so swings hit them
		-- Artist rigs: ServerStorage.NpcTemplates.Scav / .Captain (any R15 rig
		-- with a Humanoid + HumanoidRootPart). Missing = the greybox rig below.
		TemplateFolderName = "NpcTemplates",
		FolderName = "Scavs", -- Workspace folder
		-- 02 § FTUE spec: a Scav "dies in 2-3 hits" (Wooden: 10, 10, 16).
		Scav = { Health = 30, WalkSpeed = 12, Damage = 5, AttackSeconds = 1.5, Scale = 1 }, -- [PH] invented
		Captain = { Health = 150, WalkSpeed = 11, Damage = 10, AttackSeconds = 1.5, Scale = 1.35 }, -- [PH] invented
		AggroRange = 12, -- [PH] invented: a Scav turns on a player this close
		AttackRange = 5, -- [PH] invented
		ThinkSeconds = 0.25, -- [PH] invented: AI update rate
		-- "Never hard-block": a Scav that makes no progress this long hops
		-- over whatever is in its way.
		StuckSeconds = 3, -- [PH] invented
		-- Scavs arrive along your plot's bridge (in front of the plot,
		-- PlotGrid.front), this far from the plot centre, so a wave gives
		-- ~5-8 s of warning before reaching the core. gen_world.py checks
		-- it lands on the bridge; with no ground there they start at the plot
		-- edge instead.
		SpawnDistance = 60, -- [PH] invented
		HopStuds = 7, -- [PH] invented
		-- Failing costs Exposed only (04 § Scav Waves). Josh's call, step 6:
		-- each Scav that survives this long at your Vault Core takes this
		-- share of your Exposed resources and Scrap, then leaves.
		LootRange = 7, -- [PH] invented: studs from the Vault Core Hitbox
		LootSeconds = 10, -- [PH] invented (was 5: whole waves were lost in ~7 s)
		LootShare = 0.02, -- [PH] invented: 2% (an offline raid takes 8%, D3)
		-- Mobs: "PvP-free income floor", and Research Scrap comes from mob
		-- drops (06 § Currencies). Goes to whoever landed the killing blow.
		KillDrop = { Stone = 5, Ore = 2 }, -- [PH] invented
		KillScrap = 2, -- [PH] invented
		Colors = { -- look only
			Scav = Color3.fromRGB(150, 95, 60),
			Captain = Color3.fromRGB(120, 40, 40),
		},
	},
	ScavWaves = {
		-- Josh's call, step 6: every 8-12 min [PH] while you're online, once
		-- you have a Vault Core. Captain leads about 1 in 4 waves [PH].
		IntervalSeconds = { Min = 480, Max = 720 },
		CaptainChance = 0.25,
		-- "Scale waves to base tier": Scavs = Base + PerTier x (tier - 1).
		ScavsBase = 2, -- [PH] invented
		ScavsPerTier = 1, -- [PH] invented
		SpawnGapSeconds = 0.6, -- [PH] invented: between Scavs of one wave
		MaxWaveSeconds = 180, -- [PH] invented: leftover Scavs wander off after this
		-- D59: server-wide cap on waves running at once; the rest queue.
		MaxConcurrent = 3, -- [PH] invented
		QueueCheckSeconds = 1,
		-- "Successful defense yields resources + Reputation": resources x tier.
		-- Reputation: Config.Progression.XP.RaiderPerWaveDefended (step 9).
		SuccessRewardPerTier = { Stone = 30, Ore = 10 }, -- [PH] invented
		-- Captain Guaranteed bucket: "materials scaled to tier" (x tier).
		CaptainMaterialsPerTier = { Stone = 60, Ore = 25, Riftsalt = 3 }, -- [PH] invented
		-- TEMPORARY stand-in (Josh's call, step 6) until step 10 adds Common
		-- blueprints: Rare bucket = Research Scrap instead of a blueprint.
		CaptainRareScrap = 40,
		-- Signature bucket: the Captain pickaxe skin (v5.8, 04 § The PvE
		-- ladder). A duplicate is kept as a tradeable spare (Josh's call).
		CaptainSignatureSkin = "CaptainsCleaver",
		FloodCount = 6, -- Studio key: waves queued at once to test the cap
	},

	-- ── Step 7 ── Raiding + lockpick + Chase + escort ──────────────────
	-- 02-core-loop.md § Raiding, § Lockpick skill model, § Theft math,
	-- § The Chase, § Raid log path map (D105); tiers 1-7 only in the slice.
	Raiding = {
		-- 02 § The raid sequence: breach -> lockpick -> grab (Exposed only) ->
		-- escape. The window covers the whole raid, from breach (02 §
		-- Defenses: the Decoy "wastes ~20s of the 90s window").
		WindowSeconds = 90, -- [PH] per doc
		-- 02 § Theft math (D108; values PH). One grab takes the whole share
		-- (Josh's call, step 7), capped per victim vault tier [PH] invented.
		OnlineShare = 0.25,
		OfflineShare = 0.08,
		DestroyedInTransit = 0.2, -- ~20%: the raider gets the other 80%
		CapByTier = { 250, 500, 900, 1_400, 2_000, 2_800, 3_800 }, -- [PH] invented
		BreachRange = 10, -- [PH] invented: studs from the victim's plot edge
		-- After an offline breach's waits, the raider must still be this close.
		BreachRecheckRange = 20, -- [PH] invented
		CoreRange = 10, -- [PH] invented: studs from the Vault Core Hitbox (pick / grab)
		-- 02 § Lockpick skill model: speed, never fail-locked. Skyrim-style
		-- (Josh's calls, 2026-09-22; tuned from his LOCKPICKING GUIDE, see
		-- docs-build/design-changes.md). Point the pick at an angle, hold Turn:
		--   sweet spot     the lock turns all the way -> the stage is solved
		--   partial zone   it turns part way, further the closer you are
		--   outside        it barely budges
		-- Holding Turn against a stop wears the pick until it snaps. The
		-- server runs the lock (shared/LockpickModel); the sweet spot never
		-- leaves it (R5). Angles in degrees: pick -90..90 (0 = straight up),
		-- lock 0 (resting) .. FullTurn (open). All [PH] invented unless noted.
		Lockpick = {
			-- Always 3 stages (Josh). Tier 1 values = the guide's §10.2 table.
			Stages = {
				{ SweetWidth = 9.0, PartialWidth = 20, BreakSeconds = 1.3 },
				{ SweetWidth = 6.5, PartialWidth = 17, BreakSeconds = 1.0 },
				{ SweetWidth = 4.5, PartialWidth = 14, BreakSeconds = 0.75 },
			},
			-- 02 § The raid sequence "difficulty scales with vault tier": every
			-- tier above 1, and every working Lock Upgrade (Config.Defenses
			-- ExtraDifficulty), is one difficulty step. Each step narrows the
			-- zones and shortens break time; stages never get added (Josh).
			WidthScalePerStep = 0.9,
			BreakScalePerStep = 0.92,
			MinSweetWidth = 2.5,
			MinPartialWidth = 8,
			MinBreakSeconds = 0.4,
			-- Each stage re-rolls its sweet spot. After stage 1 it stays on the
			-- same side of centre only this often (Josh: "low"). If players learn
			-- to always try the other side first, 0.3-0.4 is less predictable.
			SameSideChance = 0.12,
			MinOffset = 12, -- sweet spots keep off dead centre so "side" means something
			PickLimit = 90,
			FullTurn = 90,
			-- "Getting warm" (Josh): in a partial zone the lock turns up to
			-- NearMax, shaped by Curve (<1 = turns further earlier, a generous
			-- hint). Completely wrong, it budges MinBudge.
			NearMax = 80,
			MinBudge = 4,
			Curve = 0.7,
			Epsilon = 0.5, -- degrees: "at the stop"
			TurnSpeed = 110, -- deg/s: dead on, a stage takes ~0.8 s (the floor no script beats)
			ReturnSpeed = 300, -- deg/s: the lock springs back when Turn is let go
			-- Each new pick lasts BreakSeconds x (1 +/- this), so picks don't all
			-- feel the same (Josh's pick from the guide's extras).
			BreakVariance = 0.15,
			-- Lockpicks are items (Josh, 2026-09-22; crafted from Ore at
			-- Workshop I, step 10). A snapped pick costs one and a refit. With
			-- none left you improvise: slower, never impossible (02 § Lockpick
			-- skill model stands).
			ItemId = "Lockpick",
			RefitSeconds = 0.8,
			NoPickTurnScale = 0.35, -- turn speed while improvising
			NoPickRefitSeconds = 3,
			DebugPickGrant = 5, -- Studio key 9
			-- Input stream: the client sends (angle, holding Turn) at most this
			-- often; the server's limit is a little looser.
			InputSendSeconds = 0.05,
			InputBurst = 30,
			InputPerSecond = 25,
			FeelSendSeconds = 1 / 15, -- server -> raider lock updates
			-- Studio only: the dial tints the sweet spot and partial zones
			-- (guide §7). Live servers never send them.
			StudioOverlay = true,
			-- What the raider's client is told is rounded to these steps:
			-- fine for the dial and shake, too coarse for a script to work the
			-- exact sweet spot back out (review 2026-09-22 #10).
			FeelAngleStep = 2, -- [PH] invented: degrees
			FeelClosenessStep = 0.1, -- [PH] invented
			-- The dial (client look only).
			Ui = {
				ShakeNear = 0.8, -- degrees of shake when stalled close to the spot
				ShakeFar = 3.5, -- ... and far from it: shakes less the closer you are
				ShakeHz = 28,
				PickShakeScale = 0.6,
				AimDeadzone = 0.35, -- gamepad right stick
				-- PLACEHOLDER sounds: Studio's few built-in clips. Swap for real
				-- asset ids later; each event picks one of its list at random.
				Sounds = {
					Scrape = { "rbxasset://sounds/volume_slider.ogg" },
					TurnStart = { "rbxasset://sounds/volume_slider.ogg" },
					Grind = "rbxasset://sounds/action_footsteps_plastic.mp3", -- loops while stalled
					Snap = { "rbxasset://sounds/action_jump_land.mp3" },
					Stage = { "rbxasset://sounds/volume_slider.ogg" },
					Open = { "rbxasset://sounds/action_get_up.mp3" },
				},
				ScrapeSeconds = 0.07, -- at most one scrape this often while moving the pick
				StageFlashSeconds = 0.6, -- "Pin set!"
				SoundCleanupSeconds = 5, -- a clip that never loads is removed after this
			},
		},
		-- The Chase (02 § The Chase).
		CarrySpeedMultiplier = 0.6, -- [PH] invented: "movement speed drops sharply"
		-- 02 § The Chase point 5 (D115): other players' hits (not the escort's)
		-- wear down the carrier's grip by the damage dealt after armor; at 0
		-- the loot is knocked loose. No recovery; full again on a new grab.
		GripDamage = 30, -- [PH] per D115: about one Wooden 3-hit combo
		-- 02 § The raid sequence step 5 + § Escape and carrier death (D114):
		-- the carrier escapes this far (horizontal) from the victim plot's
		-- centre: ~15 s at carry speed on every plot. gen_world.py checks
		-- a plot and its bridge sit inside it.
		EscapeRadiusStuds = 140, -- [PH] per doc
		-- Chase progress (Josh, 2026-09-23): the raid's players see the
		-- carrier's distance in their banner, in steps; the victim gets one
		-- alert when the carrier passes this share of the radius.
		ChaseProgressStepStuds = 10, -- [PH] invented
		ChaseHalfwayFraction = 0.5, -- [PH] 70 of 140 studs
		-- 02 § Tiered raid interaction (D23), tiers 5-7: knock one defense
		-- offline for 15 min [PH]; it comes back by itself, free.
		SabotageMinTier = 5,
		SabotageSeconds = 900,
		SabotageRange = 10, -- [PH] invented
		-- 02 § Raid log path map (D105).
		PathSampleSeconds = 0.5, -- [PH] invented
		-- Raid log map points are saved as studs + this, because a profile
		-- never stores negative numbers. Must exceed EscapeRadiusStuds.
		LogCoordOffset = 256,
		MaxPathPoints = 180, -- [PH] invented (= the 90 s window)
		LogEntries = 10, -- [PH] invented: raid log keeps the newest N
		AppliedRaidMemory = 30, -- raid ids remembered so a message never applies twice
		-- 13-build-guide.md § Part D: the raid lock (MemoryStore, short TTL).
		-- Must outlast a raid; a login waits for it (up to its TTL).
		Lock = {
			MapName = "RaidLocks",
			StudioMapName = "RaidLocks_Studio",
			TtlSeconds = 150, -- [PH] invented: > WindowSeconds + margin
			-- After an offline raid the victim is "theft pending" until their
			-- next login applies it: no second offline raid can read their old
			-- save and take the same loot twice (review H2). Cleared on login.
			-- (D75's 30-min post-raid shield is step 8's RaidProtectionService.)
			PendingSeconds = 7 * 24 * 3600, -- = Offline.TtlSeconds: bases aren't shown longer
			LoginPollSeconds = 2,
			-- While a theft is being saved, the lock is renewed this often so
			-- a slow DataStore can't let it expire mid-save (review M1).
			KeepAliveSeconds = 30, -- [PH] invented, < TtlSeconds; renewed for the whole raid
			ReleasedTtlSeconds = 5, -- [PH] invented: how long a "released" marker lingers
			-- A login waits at most this many lock lifetimes (review M2).
			LoginWaitLifetimes = 3,
		},
		-- Offline bases shown on free plots (Josh's call, step 7).
		Offline = {
			MapName = "RecentlyOffline",
			StudioMapName = "RecentlyOffline_Studio",
			TtlSeconds = 7 * 24 * 3600, -- [PH] invented: offline this long -> no longer shown
			FillSeconds = 30, -- [PH] invented: how often free plots are refilled
			Candidates = 20, -- [PH] invented: newest leavers looked at per fill
			KeepFreePlots = 1, -- [PH] invented: always leave a plot for a joiner
		},
		RequestCooldownSeconds = 0.25, -- [PH] invented: per player, raid remotes
		-- 13-build-guide.md § Anti-exploit baseline / backlog M1: raid
		-- participants who move impossibly fast are logged and snapped back.
		-- Review 2026-09-22 (#6/#8): raid participants are held to their
		-- REAL server WalkSpeed (the carry slow included) with a distance
		-- budget: time earns WalkSpeed x EnforcedSpeedTolerance, movement
		-- spends it, unspent allowance carries over up to BurstStuds +
		-- LagAllowanceSeconds of walking (laggy updates pass; a speed hack
		-- runs dry). A carrier's position is checked before every escape
		-- check.
		Movement = {
			CheckSeconds = 0.25, -- everyone else: log-only sampling
			SpeedTolerance = 1.6, -- x WalkSpeed, log-only players
			EnforcedSpeedTolerance = 1.2, -- [PH] invented: x current WalkSpeed, raid participants
			BurstStuds = 8, -- knockback, jumps, lag spikes
			LagAllowanceSeconds = 0.5, -- [PH] invented: walking a raid participant may "catch up" at once
			PushDecayPerSecond = 30, -- [PH] invented: unused knockback allowance drains this fast
		},
		Ui = {
			RaidLogVisibleAttribute = "HudRaidLog",
			-- D115 grip bar under the raid banner (carrier + owner only).
			-- Look only [PH], REVISIT with real UI.
			GripBarHeight = 8,
			GripColor = Color3.fromRGB(255, 200, 60),
			ShowBeforeFtue = true, -- TEMPORARY until step 14
			MessageSeconds = 2, -- [PH] invented: raid UI toasts
			MapStudsScale = 1.8, -- [PH] invented: raid log map shows this x the plot size
		},
		-- The carrier's server-wide marker (02 § The Chase 4). Look only.
		-- [PH] invented. (Backlog: draw it on the client from the
		-- CarryingLoot attribute instead.)
		CarrierMark = {
			Color = Color3.fromRGB(255, 200, 40),
			OutlineColor = Color3.fromRGB(255, 220, 80),
			FillTransparency = 0.5,
			LabelColor = Color3.fromRGB(150, 110, 20),
			LabelSize = Vector2.new(90, 30), -- px
			LabelHeight = 4, -- studs above the root
			MaxDistance = 2000, -- studs: seen from across the map
			TrailSeconds = 3,
		},
	},
	-- 02-core-loop.md § Raid escort (D101).
	-- 02 § Raid escort (D101): one Roblox friend who opts in (Josh's call).
	RaidEscort = {
		Max = 1,
		OfferSeconds = 15, -- [PH] invented: how long friends can accept
	},

	-- ── Step 8 ── Breach Charges, Riftsalt, bands, shields ─────────────
	-- 05-items.md § The Riftsalt rule; 02-core-loop.md § Preconditions.
	-- Riftsalt spawns only in Contested zones (NodeService enforces it), is
	-- used for nothing else, and a raid needs charges (02 § Preconditions).
	-- Crafted anywhere from the Bag's Items tab until Workshop I exists
	-- (Josh's call, step 8); spent Exposed first, lowest Grade first (the
	-- step 4 spend order, VaultService.spend).
	BreachCharges = {
		ItemId = "BreachCharge", -- an Items count (InventoryService)
		Name = "Breach Charge",
		Cost = { Riftsalt = 3 }, -- [PH] invented: a little under one Riftsalt node (4)
		PerRaid = 1, -- [PH] invented: flat per raid (Josh's call, step 8)
		CraftCooldownSeconds = 0.3, -- [PH] invented: rate limit on the Craft remote (not gameplay)
		DebugGrant = 3, -- Studio key 5
	},
	-- Band matchmaking + shields. 01-pillars.md R6; D66, D67, D75, D79, D92.
	RaidProtection = {
		-- 02 § Preconditions: the target must be in the raider's band (band =
		-- highest of vault tier, lifetime peak, gear score in tier units:
		-- Util/BandMetric). Josh's call, step 8: raiding UP is always
		-- allowed; raiding DOWN at most this many bands. [PH] invented.
		MaxBandsBelow = 1,
		-- Both shields block every raid on you, online or offline. Neither
		-- can be removed by a "drop all shields" event such as Blackout
		-- (D67, D75: ExemptFromDropAll). Blackout isn't in the slice; the
		-- flag and RaidProtectionService.dropAllShields exist so it can't be
		-- added later without honouring them.
		Shields = {
			-- 02 § FTUE hard rule 6: from first login (Meta.FirstLoginAt).
			NewAccount = { Seconds = 48 * 3600, ExemptFromDropAll = true },
			-- D1 / 02 § Theft math: after an offline raid, starting at the
			-- victim's next login (consistency decision #13). [PH] 30 min.
			PostRaid = { Seconds = 30 * 60, ExemptFromDropAll = true },
		},
		-- Josh's call, step 8: breaching a player's base ends YOUR shields.
		-- The first Breach while shielded is refused with a warning; Breach
		-- again within this many seconds to confirm. [PH] invented.
		ConfirmSeconds = 10,
		StateCooldownSeconds = 1, -- [PH] invented: GetShieldState rate limit (not gameplay)
		-- Studio-only test keys: fast-forward steps for Util/Clock.
		DebugSkipSeconds = { Hour = 3600, Day = 24 * 3600 },
		DebugDropAllSeconds = 10 * 60, -- simulated Blackout (04 § Events: 10 min)
	},

	-- ── Step 9 ── NPC selling, direct trade, Level/Reputation ──────────
	-- 06-economy.md § Two tiers of selling, § NPC price decay (D94).
	-- Josh's calls (step 9): the NPC buys from Exposed first, then Banked, in
	-- the Grade the player picks; the decay counts units per RESOURCE per UTC
	-- day (one shared counter was the rejected option).
	NpcSelling = {
		BuyerTag = "NpcBuyer", -- the tagged Model (Hitbox + Visual) in the plaza
		-- Credits for ONE Standard-grade unit at full price. The Grade
		-- multiplier (server-only) scales it. [PH] invented.
		BasePrice = { Stone = 2, Ore = 6, Riftsalt = 25 },
		-- D94: every unit sold that day multiplies that resource's price by
		-- this, down to PriceFloor of full price. [PH] invented: 100 units
		-- sold leaves ~37% (floor 25% reached after ~138 units).
		DecayPerUnit = 0.99,
		PriceFloor = 0.25,
		DaySeconds = 24 * 3600, -- the day boundary is UTC midnight (D94 "resets daily")
		MaxUnitsPerSale = 500, -- [PH] invented: one Sell request
		SellRangeStuds = 16, -- [PH] invented: how close you must stand to the buyer
		SellCooldownSeconds = 0.25, -- [PH] invented: rate limit on Sell (not gameplay)
		QuoteCooldownSeconds = 0.5, -- [PH] invented: rate limit on GetSellQuote
		PromptText = "Sell",
		PromptHoldSeconds = 0,
		Ui = {
			DisplayOrder = 12,
			MessageSeconds = 2.5, -- [PH] invented: toast time
			CloseCheckSeconds = 0.5, -- [PH] invented: how often the open panel checks you're still near
			PanelMaxSize = Vector2.new(560, 380), -- look only [PH]
			RowHeight = 34,
			CloseDistanceStuds = 24, -- the panel closes if you walk this far away
		},
	},
	-- 06-economy.md § Zero-chat trade (D61), § Trade Safety, § Access gating (D82).
	-- Same-server only in the slice (the estimate's assumption). Josh's calls,
	-- step 9: Credits can go in an offer; resources, Breach Charges, gadgets,
	-- Lockpicks and pickaxe skins trade; never Scrap, pickaxes or armor
	-- (05 § Taxonomy, D111, D112); the D98 trade hold is NOT built (below).
	Trade = {
		-- Counted Items (Config.Inventory.ItemOrder) that may be offered.
		TradeableItems = { "BreachCharge", "Lockpick", "SmokeBomb", "SprintSerum", "ShockTrap", "Disruptor" },
		-- D98 (value-threshold trade holds) is out of this step: it isn't in the
		-- step 9 prompt and non-resource items have no value yet. When built,
		-- the hold check goes in TradeService.validateOffer.
		HoldsBuilt = false,
		InviteRangeStuds = 30, -- [PH] invented: who shows in the Nearby list / can be invited
		WindowRangeStuds = 45, -- [PH] invented: the window closes if you drift this far apart
		InviteSeconds = 20, -- [PH] invented: an invite lapses
		IdleSeconds = 180, -- [PH] invented: a window with no change closes
		ConfirmLockSeconds = 5, -- 06 § Trade Safety: "5-second lock before Confirm becomes clickable"
		CheckSeconds = 1, -- how often open windows are checked (range, death, raid)
		MaxOfferLines = 12, -- [PH] invented: distinct lines per side
		MaxUnitsPerLine = 100000, -- [PH] invented
		MaxCreditsPerOffer = 10000000, -- [PH] invented
		InviteCooldownSeconds = 2, -- [PH] invented: rate limit on inviting
		NearbyCooldownSeconds = 0.5, -- [PH] invented: rate limit on the Nearby list
		HistoryCooldownSeconds = 0.6, -- [PH] invented: rate limit on GetTradeHistory
		-- After a decline or a lapsed invite, the same player can't invite the
		-- same target again for this long (stops re-invite spam; step 9 review).
		ReinviteCooldownSeconds = 30, -- [PH] invented
		RequestCooldownSeconds = 0.15, -- [PH] invented: rate limit on offer/confirm/cancel/respond
		HistoryMax = 20, -- [PH] invented: newest trades kept per player (06 § Trade Safety: history log)
		-- Below-market warning (06 § Trade Safety). Josh's call: the reference
		-- price is the NPC base price (undecayed, x Grade multiplier). It only
		-- prices resources and Credits; charges, gadgets and skins have no
		-- reference, so a trade that receives one never warns.
		BelowMarketRatio = 0.5, -- [PH] invented: warn if you'd get < 50% of what you give
		-- Trader XP from trades (03 § Reputation tracks): only when BOTH sides
		-- offer something, and only the first N trades each UTC day, so two
		-- Level-10 accounts can't farm it.
		XPPerTrade = 10, -- [PH] invented
		XPTradesPerDay = 10, -- [PH] invented
		Ui = {
			ButtonLabel = "Trade",
			ShowBeforeFtue = true, -- TEMPORARY until step 14
			VisibleAttribute = "HudTradeButton",
			DisplayOrder = 13,
			PanelMaxSize = Vector2.new(720, 420), -- look only [PH]
			NearbyPanelMaxSize = Vector2.new(460, 420), -- look only [PH]
			HistoryRowsShown = 8, -- [PH] invented: recent trades listed in the Nearby panel
			FooterRefreshSeconds = 0.25, -- [PH] invented: lock countdown tick
			RowHeight = 30,
			MessageSeconds = 2.5,
			CompleteMessageSeconds = 7, -- [PH] invented: the "Trade complete!" bubble stays up longer, it lists what you received
			Colors = {
				Give = Color3.fromRGB(255, 190, 110),
				Get = Color3.fromRGB(120, 220, 140),
				Warn = Color3.fromRGB(255, 110, 90),
			},
		},
	},
	-- 03-progression.md § Reputation tracks, § Level (D81, D82).
	Progression = {
		-- Level = sum of the three track levels (D82). Each track
		-- (Miner/Trader/Raider, D81) turns XP into a track level with:
		--   XP needed to REACH track level n = floor(BaseXP * n ^ Exponent)
		-- Exponent > 1 makes each level cost more than the last, which also
		-- makes hybrid play faster to Level 10 than one track alone (03 § Ranked
		-- ladder: "a hybrid gets there faster"). Everyone starts at Level 0.
		--   Level 10 from one track: 3,162 XP. Spread 4/3/3: 1,838 XP.
		-- Target: Level 10 in ~2-3 sessions of active play (06-economy.md §
		-- Access gating) = ~90-135 min, so step 9 should grant roughly
		-- 15-30 XP per minute of active play. Track max at the 17-bit XP cap
		-- (Config.Data.Packed) is level 119.
		LevelCurve = {
			BaseXP = 100, -- [PH] invented
			Exponent = 1.5, -- [PH] invented
		},
		TradeUnlockLevel = 10, -- 06-economy.md § Access gating (D82) [PH]
		-- XP grants (server-validated actions only, R5). Sized for ~15-30 XP
		-- per minute of active play (see above). All [PH] invented.
		-- Josh's call, step 9: a defended Scav Wave feeds the Raider track.
		XP = {
			MinerPerNodeFinished = 3, -- the hit that finishes a node
			TraderPerTenCredits = 1, -- NPC sales: 1 XP per 10 Credits earned (the price decay throttles it)
			RaiderPerEscape = 40, -- a raider who gets away with loot
			RaiderPerWaveDefended = 20, -- a Scav Wave beaten with no Scav escaping
		},
		-- Stub (step 9 prompt: "cosmetic/title rewards stubbed"): nothing is
		-- granted yet. ReputationService logs the reward a track level WOULD
		-- give. Titles are identity, never lootable (R1) and never stats (D81).
		-- [PH] invented names.
		TrackRewards = {
			Miner = { [5] = "Prospector", [10] = "Deep Miner" },
			Trader = { [5] = "Peddler", [10] = "Merchant" },
			Raider = { [5] = "Scrapper", [10] = "Raider" },
		},
		Tracks = { "Miner", "Trader", "Raider" }, -- Config.Data.Packed "<Track>XP" words
		-- Studio key ` (backtick; O/I are camera zoom): track levels that add up to Level 10 (4 + 3 + 3).
		DebugLevelSplit = { Miner = 4, Trader = 3, Raider = 3 },
		StateCooldownSeconds = 0.5, -- [PH] invented: GetProgressState rate limit
	},

	-- ── Shared look for the step 9 screens (NPC buyer, trade window, Bag
	-- Level block) via Shared/UiStyle. LOOK ONLY, all [PH] invented: REVISIT
	-- with the UI template pass (before step 14). Nothing here is gameplay.
	UiStyle = {
		Font = Enum.Font.GothamMedium,
		FontBold = Enum.Font.GothamBold,
		TextSize = { Title = 20, Body = 15, Small = 13 },
		MinTap = 44, -- px: the smallest button height (thumb friendly, phones)
		Corner = 12, -- panels
		CardCorner = 10, -- cards and buttons
		Pad = 10, -- inside cards
		Gap = 8, -- between cards / rows
		StrokeThickness = 1.5,
		WideBreakpoint = 620, -- px: a window at least this wide uses two columns
		Colors = {
			Panel = Color3.fromRGB(17, 18, 28),
			PanelStroke = Color3.fromRGB(78, 82, 120),
			Card = Color3.fromRGB(28, 30, 46),
			CardStroke = Color3.fromRGB(52, 56, 84),
			Text = Color3.fromRGB(240, 242, 250),
			TextDim = Color3.fromRGB(160, 166, 190),
			Accent = Color3.fromRGB(255, 208, 96), -- Credits, Level
			Good = Color3.fromRGB(96, 214, 138),
			Warn = Color3.fromRGB(255, 176, 72),
			Bad = Color3.fromRGB(240, 96, 88),
			BarTrack = Color3.fromRGB(14, 15, 24),
			ButtonNeutral = Color3.fromRGB(52, 56, 84),
			ButtonPrimary = Color3.fromRGB(46, 140, 86),
			ButtonDisabled = Color3.fromRGB(58, 60, 74),
			ButtonDanger = Color3.fromRGB(150, 56, 56),
			ButtonChip = Color3.fromRGB(40, 43, 66),
		},
		-- Grade name colors (text + chips), matching the node bursts.
		GradeColors = {
			Standard = Color3.fromRGB(196, 200, 214),
			Dense = Color3.fromRGB(150, 212, 255),
			Volatile = Color3.fromRGB(255, 220, 90),
			Prismatic = Color3.fromRGB(255, 150, 236),
			Vaultborn = Color3.fromRGB(255, 235, 170),
		},
		-- The buyer's price bar: green while the price is at or above GoodFrom of
		-- full, amber down to WarnFrom, then red.
		PriceBar = { GoodFrom = 0.6, WarnFrom = 0.35, Height = 10 },
		InviteSlide = { Seconds = 0.3, HiddenY = -140, ShownY = 96 }, -- the invite popup's slide-in
		AvatarSize = 40, -- px: Nearby list and trade header avatars
		Level = { BadgeSize = 76, BarHeight = 14 }, -- the Bag's Level block (the XP text sits inside the bar)
		ShortWindowHeight = 400, -- px: a trade window shorter than this drops its status line (phone landscape)
		WarningStripHeight = 40, -- px: the fixed below-market warning above the trade list
	},

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
