--!strict
-- THROWAWAY (build step 0B): mobile performance spike. Builds one player base
-- plus up to 8 neighbors on floating islands, a dozen particle-emitting nodes
-- and a few wandering NPCs, so a phone can show whether the render budget
-- (09-research.md § Rendering & Mobile Performance Budget; ~1,000 draw calls,
-- ~1,000,000 triangles) holds up.
--
-- TO DELETE LATER (nothing else depends on this):
--   1. src/server/PerfSpike/                 (this folder)
--   2. src/client/PerfSpikeHud.client.luau
--   3. Config.PerfSpike in src/shared/Config.luau
--   4. PerfSpikeSetPreset in src/shared/Remotes.luau
--   5. the "PerfSpike" lines in src/server/Main.server.luau
--   6. docs-build/perfspike/ and ServerStorage.PerfSpikeKit in the place file
--
-- R5: the client only asks for a preset by NAME. The server whitelists the
-- name, rate-limits, and only obeys the place owner (or Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Layout)
local Npcs = require(script.Npcs)
local StandInArt = require(script.StandInArt)

local cfg = Config.PerfSpike

local PerfSpike = {}

local kit: StandInArt.Kit
local sceneRoot: Folder? = nil
local currentSpawn: SpawnLocation? = nil
local generation = 0 -- bumps on every rebuild so stale NPC tasks can stop
local lastRequestAt: { [number]: number } = {}

-- The HUD reads these from Workspace attributes; they replicate to clients.
local function publish(name: string, value: any)
	workspace:SetAttribute("PerfSpike_" .. name, value)
end

local function findPreset(name: string): number?
	for index, preset in cfg.Presets do
		if preset.Name == name then
			return index
		end
	end
	return nil
end

local function makeSpawn(base: Model, spot: Layout.BaseSpot): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = cfg.Layout.SpawnSize
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no spawn forcefield
	spawn.Transparency = 1
	spawn.CFrame = spot.CFrame * CFrame.new(cfg.Layout.SpawnOffset)
	spawn.Parent = base
	return spawn
end

local function respawnEveryone()
	for _, player in Players:GetPlayers() do
		if currentSpawn then
			player.RespawnLocation = currentSpawn
		end
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

local function buildScene(presetIndex: number)
	generation += 1
	local myGeneration = generation
	local function isCurrent(): boolean
		return generation == myGeneration
	end

	publish("Building", true)
	if sceneRoot then
		sceneRoot:Destroy()
	end

	local preset = cfg.Presets[presetIndex]
	local folder = Instance.new("Folder")
	folder.Name = "PerfSpikeRoot"

	local spots = Layout.baseSpots(preset.Neighbors)
	local tris, parts, emitters = 0, 0, 0

	for _, spot in spots do
		local stats, base = StandInArt.buildBase(folder, spot, kit, preset)
		tris += stats.Tris
		parts += stats.Parts
		if spot.IsOwn then
			currentSpawn = makeSpawn(base, spot)
		end
	end
	for k = 1, cfg.Nodes.Count do
		local stats = StandInArt.buildNode(folder, spots[(k - 1) % #spots + 1], k, kit, preset)
		tris += stats.Tris
		parts += stats.Parts
		emitters += stats.Emitters
	end

	sceneRoot = folder
	folder.Parent = workspace

	for n = 1, preset.Npcs do
		task.spawn(Npcs.spawn, folder, spots[(n - 1) % #spots + 1], n, isCurrent)
	end

	-- Triangle totals only mean something when the real meshes are in use.
	publish("Tris", if kit.Mode == "Imported" then tris else -1)
	publish("Parts", parts)
	publish("Emitters", emitters)
	publish("Npcs", preset.Npcs)
	publish("Bases", #spots)
	publish("Preset", preset.Name)
	publish("PresetIndex", presetIndex)
	publish("PresetCount", #cfg.Presets)
	publish("PieceMultiplier", preset.PieceMultiplier)
	publish("Varied", preset.Varied)
	publish("RenderFidelity", preset.RenderFidelity)
	publish("KitMode", kit.Mode)
	publish("OwnCenter", spots[1].CFrame.Position)
	publish("Version", generation)
	publish("Building", false)

	print(
		string.format(
			"[PerfSpike] preset %s: %d bases, %d art parts, %d emitters, %s triangles (kit: %s)",
			preset.Name,
			#spots,
			parts,
			emitters,
			if kit.Mode == "Imported" then tostring(tris) else "n/a",
			kit.Mode
		)
	)

	respawnEveryone()
end

function PerfSpike.start()
	assert(RunService:IsServer(), "PerfSpike.start() may only run on the server")

	kit = StandInArt.loadKit()
	if kit.Mode ~= "Imported" then
		warn(
			`[PerfSpike] mesh kit is {kit.Mode} (missing: {table.concat(kit.Missing, ", ")}). Using plain blocks, so triangle numbers are NOT valid. See docs-build/perfspike/README.md.`
		)
	end

	Players.PlayerAdded:Connect(function(player)
		if currentSpawn then
			player.RespawnLocation = currentSpawn
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player.UserId] = nil
	end)

	Remotes.getEvent("PerfSpikeSetPreset").OnServerEvent:Connect(function(player: Player, presetName: unknown)
		if typeof(presetName) ~= "string" then
			return
		end
		-- Owner-only: this rebuilds the world for everyone. (Studio always allowed.)
		if not (RunService:IsStudio() or player.UserId == game.CreatorId) then
			return
		end
		local now = os.clock()
		local last = lastRequestAt[player.UserId]
		if last and now - last < cfg.PresetCooldownSeconds then
			return
		end
		lastRequestAt[player.UserId] = now

		local index = findPreset(presetName)
		if index then
			buildScene(index)
		end
	end)

	buildScene(findPreset(cfg.DefaultPreset) or 1)
end

return PerfSpike
