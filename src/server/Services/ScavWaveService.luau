--!strict
-- ScavWaveService: periodic Scav Waves on player bases, the server-wide
-- concurrent cap, and the Scav Captain's loot.
--
-- Docs: 04-world-content.md § Scav Waves (D108), § Concurrent wave ceiling
-- (D59), § Loot table structure (four buckets), § Respawn cadence (Captain
-- "appears in waves, no schedule"); 07-decisions.md § D107 (Captain loot
-- goes to the defending owner), D87 (mobs never destroy).
--
-- * Every 8-12 min [PH] while you're online with a Vault Core, one wave
--   targets your base (Josh's call, step 6). Size scales with vault tier.
-- * D59: at most MaxConcurrent waves run on the server; the rest wait in a
--   first-come queue. A late wave is invisible to its target; a frame drop
--   isn't.
-- * Failing costs Exposed only: each Scav that survives at your Vault Core
--   takes LootShare of your Exposed resources and Scrap (Josh's call).
--   Kill every Scav = success = resources (+ Reputation in step 9).
-- * Mobs never destroy or even damage structures (D87).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ServerConfig = require(ServerScriptService.ServerConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local VaultService = require(script.Parent.VaultService)
local InventoryService = require(script.Parent.InventoryService)
local ArmorService = require(script.Parent.ArmorService)
local PlotService = require(script.Parent.PlotService)
local ScavService = require(script.Parent.ScavService)

local waveCfg = Config.ScavWaves
local scavCfg = Config.Scavs

type Wave = {
	owner: Player,
	tier: number,
	scavs: { [Model]: boolean },
	toSpawn: number, -- still waiting to appear
	escaped: number,
	lostResources: number,
	lostScrap: number,
	ended: boolean,
}
type Queued = { owner: Player, captain: boolean }

local rng = Random.new()
local queue: { Queued } = {}
local active: { Wave } = {}
local nextWaveAt: { [Player]: number } = {}

local ScavWaveService = {}

local function alert(owner: Player, kind: string, text: string)
	if owner.Parent then
		Remotes.getEvent("BaseAlert"):FireClient(owner, kind, text)
	end
end

local function scaled(perTier: { [string]: number }, tier: number): { [string]: number }
	local out = {}
	for resource, amount in perTier do
		out[resource] = amount * tier
	end
	return out
end

local function describe(amounts: { [string]: number }): string
	local parts = {}
	for _, resource in Config.Resources.Types do
		if (amounts[resource] or 0) > 0 then
			table.insert(parts, `{amounts[resource]} {resource}`)
		end
	end
	return table.concat(parts, ", ")
end

local function hasVaultCore(player: Player): boolean
	local state = PlotService.getState(player)
	return state ~= nil and state.HasVaultCore and state.Tier >= 1
end

local function scheduleNext(player: Player)
	nextWaveAt[player] = os.clock() + rng:NextNumber(waveCfg.IntervalSeconds.Min, waveCfg.IntervalSeconds.Max)
end

local function isBusy(player: Player): boolean
	for _, wave in active do
		if wave.owner == player then
			return true
		end
	end
	for _, entry in queue do
		if entry.owner == player then
			return true
		end
	end
	return false
end

-- ── Captain loot (four buckets, 04 § Loot table structure) ───────────────

local function captainLoot(owner: Player, tier: number)
	local odds = ServerConfig.CaptainLoot
	local lines = {}
	-- Guaranteed: "materials scaled to tier".
	local materials = scaled(waveCfg.CaptainMaterialsPerTier, tier)
	VaultService.grant(owner, materials)
	table.insert(lines, describe(materials))
	-- Common (~60%): a gadget. (Cases and components aren't in the slice.)
	if rng:NextNumber() < odds.Common then
		local gadgetId = Config.Gadgets.Order[rng:NextInteger(1, #Config.Gadgets.Order)]
		InventoryService.add(owner, gadgetId, 1)
		table.insert(lines, `a {Config.Gadgets.Names[gadgetId]}`)
	end
	-- Rare (~25%): TEMPORARY Research Scrap until Common blueprints (step 10).
	if rng:NextNumber() < odds.Rare then
		VaultService.depositScrap(owner, waveCfg.CaptainRareScrap)
		table.insert(lines, `{waveCfg.CaptainRareScrap} Research Scrap`)
	end
	-- Signature (~5-8%): TEMPORARY Iron armor until a signature item is named.
	if rng:NextNumber() < odds.Signature then
		local armorTier = waveCfg.CaptainSignatureArmorTier
		ArmorService.grant(owner, armorTier, Config.Combat.ArmorSlots[1])
		table.insert(lines, `a {Config.Combat.PickaxeTiers[armorTier]} chest armor (rare!)`)
	end
	print(`[Waves] Scav Captain loot for {owner.Name}: {table.concat(lines, "; ")}`)
	alert(owner, "CaptainLoot", `Scav Captain defeated! Loot: {table.concat(lines, "; ")}`)
end

-- ── Running a wave ───────────────────────────────────────────────────────

local function finish(wave: Wave, reason: string?)
	if wave.ended then
		return
	end
	wave.ended = true
	local index = table.find(active, wave)
	if index then
		table.remove(active, index)
	end
	for model in wave.scavs do
		model:Destroy() -- leftovers wander off (despawned, not "escaped")
	end
	local owner = wave.owner
	if not owner.Parent then
		return
	end
	if reason then
		print(`[Waves] wave on {owner.Name} ended: {reason}`)
	elseif wave.escaped == 0 then
		local reward = scaled(waveCfg.SuccessRewardPerTier, wave.tier)
		VaultService.grant(owner, reward)
		-- 04 § Scav Waves: "+ Reputation". ReputationService arrives in step 9.
		print(`[Waves] {owner.Name} defended a tier {wave.tier} wave: +{describe(reward)} (Reputation: step 9)`)
		alert(owner, "WaveWon", `Scav Wave defeated! +{describe(reward)}`)
	else
		print(`[Waves] {owner.Name} lost a wave: {wave.escaped} Scav(s) took {wave.lostResources} resources, {wave.lostScrap} Scrap`)
		alert(owner, "WaveLost", `Scavs got away with {wave.lostResources} resources and {wave.lostScrap} Scrap from your Exposed`)
	end
	scheduleNext(owner)
end

-- Where a wave's Scavs appear and the plot edge they walk to first. They
-- come along the plot's bridge (the line from the Homestead centre to the
-- plot centre), SpawnDistance from the plot centre, so the owner sees them
-- coming. Falls back to the plot edge if there's no ground there.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local function approach(hitbox: BasePart): (Vector3, Vector3)
	local centre = hitbox.Position
	local toHome = Vector3.new(-centre.X, 0, -centre.Z)
	local inward = if toHome.Magnitude > 0 then toHome.Unit else -Vector3.xAxis
	local top = hitbox.Size.Y / 2
	local half = math.min(hitbox.Size.X, hitbox.Size.Z) / 2
	local entry = centre + inward * (half - 2) + Vector3.new(0, top, 0)

	local start = centre + inward * scavCfg.SpawnDistance
	groundParams.FilterDescendantsInstances = { workspace:FindFirstChild(Config.World.FolderName) :: Instance }
	local ground = workspace:Raycast(start + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), groundParams)
	if not ground then
		return entry, entry
	end
	return ground.Position, entry
end

local function startWave(entry: Queued)
	local owner = entry.owner
	local hitbox = PlotService.getPlotHitbox(owner)
	local base = PlayerDataService.get(owner, "Base")
	if not owner.Parent or not hitbox or not base or not hasVaultCore(owner) then
		-- Dropped: they left, have no plot, or have no Vault Core any more.
		print(`[Waves] skipped a wave on {owner.Name}: {if not hitbox then "no plot" elseif not hasVaultCore(owner) then "no Vault Core" else "not loaded"}`)
		return
	end
	local tier = math.max(1, base.VaultTier)
	local count = waveCfg.ScavsBase + waveCfg.ScavsPerTier * (tier - 1)
	local kinds: { ScavService.Kind } = {}
	if entry.captain then
		table.insert(kinds, "Captain")
	end
	for _ = 1, count do
		table.insert(kinds, "Scav")
	end

	local wave: Wave = {
		owner = owner,
		tier = tier,
		scavs = {},
		toSpawn = #kinds,
		escaped = 0,
		lostResources = 0,
		lostScrap = 0,
		ended = false,
	}
	table.insert(active, wave)
	print(`[Waves] wave on {owner.Name}: {count} Scavs{if entry.captain then " + Captain" else ""} (tier {tier}); {#active} running, {#queue} queued`)
	alert(owner, "WaveIncoming", if entry.captain then "A Scav Captain leads a wave on your base!" else "Scav Wave incoming!")

	local callbacks: ScavService.Callbacks = {
		onLooted = function(_model)
			wave.escaped += 1
			local resources, scrap = VaultService.takeExposedShare(owner, scavCfg.LootShare)
			wave.lostResources += resources
			wave.lostScrap += scrap
			alert(owner, "ScavLooted", `A Scav stole {resources} resources from your Exposed!`)
		end,
		onGone = function(model, reason, _killer)
			wave.scavs[model] = nil
			if reason == "killed" and model:GetAttribute("ScavKind") == "Captain" and owner.Parent then
				captainLoot(owner, tier) -- D107: to the defender, whoever killed it
			end
			if not wave.ended and wave.toSpawn == 0 and next(wave.scavs) == nil then
				finish(wave, nil)
			end
		end,
	}

	for i, kind in kinds do
		task.delay((i - 1) * waveCfg.SpawnGapSeconds, function()
			wave.toSpawn -= 1
			if wave.ended or not owner.Parent then
				return
			end
			local start, entry = approach(hitbox)
			local model = ScavService.spawn(kind :: ScavService.Kind, owner, start, entry, callbacks)
			wave.scavs[model] = true
		end)
	end
	task.delay(waveCfg.MaxWaveSeconds, function()
		finish(wave, "time ran out; the rest wandered off")
	end)
end

-- ── Scheduling + the D59 cap ─────────────────────────────────────────────

local function enqueue(owner: Player, captain: boolean?)
	local isCaptain = if captain == nil then rng:NextNumber() < waveCfg.CaptainChance else captain
	table.insert(queue, { owner = owner, captain = isCaptain })
	nextWaveAt[owner] = nil -- set again when this wave ends
end

local function pump()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		if hasVaultCore(player) and not isBusy(player) then
			local due = nextWaveAt[player]
			if not due then
				scheduleNext(player)
			elseif now >= due then
				enqueue(player, nil)
			end
		end
	end
	while #active < waveCfg.MaxConcurrent and #queue > 0 do
		startWave(table.remove(queue, 1) :: Queued)
	end
end

-- ── Studio debug ─────────────────────────────────────────────────────────

-- A wave on this player's base right away (still goes through the cap).
function ScavWaveService.debugStartWave(player: Player, captain: boolean)
	assert(RunService:IsStudio(), "debugStartWave is Studio-only")
	if not PlotService.getPlotHitbox(player) then
		print(`[Waves] can't start a wave on {player.Name}: no plot (see [Plots] lines at join)`)
		return
	elseif not hasVaultCore(player) then
		print(`[Waves] can't start a wave on {player.Name}: place a Vault Core on your plot first`)
		return
	end
	enqueue(player, captain)
	pump()
end

-- Many waves at once on this player's base, to watch the D59 cap queue them.
function ScavWaveService.debugFlood(player: Player)
	assert(RunService:IsStudio(), "debugFlood is Studio-only")
	for _ = 1, waveCfg.FloodCount do
		enqueue(player, false)
	end
	pump()
end

function ScavWaveService.debugStatus(): string
	return `{#active} running (max {waveCfg.MaxConcurrent}), {#queue} queued`
end

function ScavWaveService.start()
	Players.PlayerRemoving:Connect(function(player)
		nextWaveAt[player] = nil
		for i = #queue, 1, -1 do
			if queue[i].owner == player then
				table.remove(queue, i)
			end
		end
		for _, wave in table.clone(active) do
			if wave.owner == player then
				finish(wave, "owner left")
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(waveCfg.QueueCheckSeconds)
			pump()
		end
	end)
end

return ScavWaveService
