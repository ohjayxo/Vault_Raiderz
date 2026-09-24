--!strict
-- NodeService: resource nodes. Spawning, server-validated mining, Grade
-- rolls, depletion and respawn/migration.
--
-- Docs: 05-items.md § Resources, § The Riftsalt rule, § Node respawn (D38),
-- § Roll 1 - Grade, § Odds are not published in-game (D46), § Vaultborn
-- announcement; 02-core-loop.md § World Structure; 13-build-guide.md § Part D.
--
-- * The client only sends "I want to mine this node" (MineNode). The server
--   checks rate limit, that the node is live, alive + distance, line of
--   sight, cooldown, and only then rolls and pays out (R5).
-- * Grade is rolled per hit, on the server, from ServerConfig (never
--   replicated: D46). The client only learns the Grade it got.
-- * Greybox contract: nodes are clones of ServerStorage.NodeTemplates. Code
--   uses the Hitbox and never touches the Visual folder.
-- * Rich-node landmarks (D39) and the Voltstone trickle are Voltstone, which
--   is out of the slice (10-roadmap.md § Vertical Slice), so they're absent.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NodeMath = require(ReplicatedStorage.Shared.NodeMath)
local ServerConfig = require(ServerScriptService.ServerConfig)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local AnomalyLog = require(ServerScriptService.Util.AnomalyLog)
local VaultService = require(script.Parent.VaultService)
local PickaxeService = require(script.Parent.PickaxeService)
local CombatService = require(script.Parent.CombatService)
local BroadcastQueue = require(script.Parent.BroadcastQueue)
local ReputationService = require(script.Parent.ReputationService)

local nodeCfg = Config.Nodes
type TypeConfig = { Hits: number, YieldPerHit: number }
type ZoneConfig = { DisplayName: string, Respawn: string, Contested: boolean, ActiveNodes: { [string]: number }? }
local typeConfigs: { [string]: TypeConfig } = nodeCfg.Types :: any
local zoneConfigs: { [string]: ZoneConfig } = Config.World.Zones :: any

type SpawnPoint = { part: BasePart, zone: string, nodeType: string, occupied: boolean }
type Node = { model: Model, hitbox: BasePart, spawn: SpawnPoint, hitsLeft: number }

local rng = Random.new()
local liveNodes: { [Model]: Node } = {} -- the server's list of minable nodes
local pools: { [string]: { SpawnPoint } } = {} -- "Zone/NodeType" -> spawn points
local templates: { [string]: Model } = {}
local lastMineAt: { [Player]: number } = {}
local forcedGrade: { [Player]: string } = {} -- Studio debug only
local nodesFolder: Folder
local losParams = RaycastParams.new()

local NodeService = {}

-- ── Grade roll (05-items.md § Roll 1; odds only in ServerConfig) ─────────

-- `bonusRanks` = the miner's Extraction "Grade odds" ranks: every
-- non-Standard weight is multiplied by (1 + bonus x ranks), then the table
-- is renormalised (ServerConfig.GradeOddsBonusPerRank, server-only).
local function rollGrade(bonusRanks: number): string
	local boost = 1 + ServerConfig.GradeOddsBonusPerRank * bonusRanks
	local total = 0
	for i, entry in ServerConfig.Grade do
		total += if i == 1 then entry.Weight else entry.Weight * boost
	end
	local roll = rng:NextNumber() * total
	local cumulative = 0
	for i, entry in ServerConfig.Grade do
		cumulative += if i == 1 then entry.Weight else entry.Weight * boost
		if roll < cumulative then
			return entry.Name
		end
	end
	-- Only reachable through float rounding at the very top of the range.
	return ServerConfig.Grade[1].Name
end

local function selfTestGrades()
	local total = 0
	for i, entry in ServerConfig.Grade do
		assert(entry.Name == Config.Grade.Names[i], `ServerConfig.Grade[{i}] is {entry.Name}, Config.Grade.Names[{i}] is {Config.Grade.Names[i]}`)
		total += entry.Weight
	end
	assert(#ServerConfig.Grade == #Config.Grade.Names, "ServerConfig.Grade and Config.Grade.Names differ in length")
	assert(math.abs(total - 1) < 1e-9, `Grade weights sum to {total}, not 1`)
end

-- ── Spawning ─────────────────────────────────────────────────────────────

local function poolKey(zone: string, nodeType: string): string
	return `{zone}/{nodeType}`
end

local function spawnNode(point: SpawnPoint)
	local model = templates[point.nodeType]:Clone()
	local hitbox = model:FindFirstChild("Hitbox") :: BasePart
	-- Stand the Hitbox on the spawn point (ground level), random yaw so
	-- repeated nodes don't look stamped. Move the whole model with it.
	local target = CFrame.new(point.part.Position + Vector3.new(0, hitbox.Size.Y / 2, 0))
		* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	model:PivotTo(target * hitbox.CFrame:ToObjectSpace(model:GetPivot()))

	local hits = typeConfigs[point.nodeType].Hits
	model:SetAttribute("Zone", point.zone)
	model:SetAttribute("HitsLeft", hits)
	model.Parent = nodesFolder

	point.occupied = true
	liveNodes[model] = { model = model, hitbox = hitbox, spawn = point, hitsLeft = hits }
end

-- A free spawn point in the same pool, preferring any but `avoid` (D38:
-- "migrate" means the node comes back somewhere else).
local function pickMigrationPoint(pool: { SpawnPoint }, avoid: SpawnPoint?): SpawnPoint?
	local free: { SpawnPoint } = {}
	for _, point in pool do
		if not point.occupied and point ~= avoid then
			table.insert(free, point)
		end
	end
	if #free == 0 then
		return if avoid and not avoid.occupied then avoid else nil
	end
	return free[rng:NextInteger(1, #free)]
end

local function deplete(node: Node)
	liveNodes[node.model] = nil
	node.model:Destroy()
	local point = node.spawn
	point.occupied = false

	local zoneCfg = zoneConfigs[point.zone]
	if zoneCfg.Respawn == "Fixed" then
		-- D38: Homestead nodes keep fixed respawns, same place.
		task.delay(nodeCfg.FixedRespawnSeconds, function()
			if not point.occupied then
				spawnNode(point)
			end
		end)
	else
		-- D38: Reaches nodes migrate, after an unpredictable delay.
		local delaySeconds = rng:NextNumber(nodeCfg.MigrateDelaySeconds.Min, nodeCfg.MigrateDelaySeconds.Max)
		task.delay(delaySeconds, function()
			local target = pickMigrationPoint(pools[poolKey(point.zone, point.nodeType)], point)
			if target then
				spawnNode(target)
			end
		end)
	end
end

-- ── Mining ───────────────────────────────────────────────────────────────

local logAnomaly = AnomalyLog.new("MineNode")

-- Defined below onMineRequest, which uses them.
local strike: (player: Player, node: Node) -> boolean
local nearestOtherNode: (node: Node, radius: number) -> Node?

local function onMineRequest(player: Player, allowRate: (Player) -> boolean, nodeArg: unknown)
	-- 1. Rate limit first, so spam costs the server almost nothing.
	if not allowRate(player) then
		return
	end

	-- 2. The node must be one the server spawned and hasn't depleted.
	if typeof(nodeArg) ~= "Instance" then
		logAnomaly(player, "sent a non-Instance instead of a node", typeof(nodeArg))
		return
	end
	local instance = nodeArg :: Instance
	local node = liveNodes[instance :: any]
	if not node then
		-- A node depleted a moment ago is a normal race (lag, two miners):
		-- ignore quietly. Anything else is not a node at all.
		if not CollectionService:HasTag(instance, nodeCfg.Tag) then
			logAnomaly(player, "tried to mine a non-node", instance:GetFullName())
		end
		return
	end

	-- 3. Alive and close enough. The client pre-checks distance for its
	-- "walk closer" hint, so a far request means a modified client.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local distance = NodeMath.distanceToHitbox(node.hitbox, root.Position)
	if distance > nodeCfg.MineDistance then
		logAnomaly(player, "too far from a node", `{math.floor(distance)} > {nodeCfg.MineDistance} studs`)
		return
	end

	-- 4. Line of sight: no island/world geometry between player and node
	-- (13-build-guide.md § Anti-exploit baseline).
	local from = root.Position
	if workspace:Raycast(from, node.hitbox.Position - from, losParams) then
		logAnomaly(player, "mined through world geometry")
		return
	end

	-- 5. Mining cooldown: faster taps are normal, just ignored.
	local now = os.clock()
	local last = lastMineAt[player]
	if last and now - last < PickaxeService.mineCooldown(player) then
		return
	end

	-- All checks passed. Nothing below yields, so two players hitting the
	-- same node can't both take its last hit.
	if not strike(player, node) then
		return -- profile not loaded: don't consume the hit
	end
	lastMineAt[player] = now
	CombatService.playSwing(player)

	-- Extraction "multi-node strike": sometimes one other node nearby is
	-- struck too (its own Grade roll). Picked by the server, never the client.
	if rng:NextNumber() < PickaxeService.multiStrikeChance(player) then
		local extra = nearestOtherNode(node, Config.Combat.MultiStrikeRadius)
		if extra then
			strike(player, extra)
		end
	end
end

-- Rolls a Grade and pays out one hit on `node`. Returns false (and changes
-- nothing) if the player's profile isn't loaded.
strike = function(player: Player, node: Node): boolean
	local nodeType = node.spawn.nodeType
	local grade = forcedGrade[player] or rollGrade(PickaxeService.gradeOddsRanks(player))
	local amount = typeConfigs[nodeType].YieldPerHit
	if not VaultService.deposit(player, nodeType, grade, amount) then
		return false
	end
	forcedGrade[player] = nil

	node.hitsLeft -= 1
	node.model:SetAttribute("HitsLeft", node.hitsLeft)
	local position = node.hitbox.Position
	local zone = node.spawn.zone

	Remotes.getEvent("MineResult"):FireClient(player, nodeType, grade, amount, node.hitsLeft)
	if grade ~= Config.Grade.Names[1] then
		-- Everyone sees the Grade effect at the node (Josh's call, step 2).
		Remotes.getEvent("GradeFx"):FireAllClients(grade, position)
	end
	if grade == "Vaultborn" then
		-- 05-items.md § Vaultborn announcement: zone only, never coordinates,
		-- after the holder's head start.
		local text = `A Vaultborn strike was detected in {zoneConfigs[zone].DisplayName}.`
		print(`[Nodes] {player.Name} struck Vaultborn in {zone}; announcing in {Config.Broadcast.VaultbornHeadStartSeconds} s`)
		task.delay(Config.Broadcast.VaultbornHeadStartSeconds, function()
			BroadcastQueue.push("Vaultborn", text)
		end)
	end

	if node.hitsLeft <= 0 then
		deplete(node)
		-- 03 § Reputation tracks: Miner XP for the hit that finishes a node.
		ReputationService.grant(player, "Miner", Config.Progression.XP.MinerPerNodeFinished, "node finished")
	end
	return true
end

-- The closest other live node within `radius` studs of `node`.
nearestOtherNode = function(node: Node, radius: number): Node?
	local best: Node? = nil
	local bestDistance = radius
	for _, other in liveNodes do
		if other ~= node then
			local distance = (other.hitbox.Position - node.hitbox.Position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

-- ── Studio debug ─────────────────────────────────────────────────────────

-- The player's next successful hit gets this Grade (tests FX/announcement
-- without mining ~1,000 times).
function NodeService.debugForceNextGrade(player: Player, grade: string)
	assert(RunService:IsStudio(), "debugForceNextGrade is Studio-only")
	assert(table.find(Config.Grade.Names, grade), `unknown grade "{grade}"`)
	forcedGrade[player] = grade
end

-- ── Start-up ─────────────────────────────────────────────────────────────

local function loadTemplates()
	local folder = ServerStorage:WaitForChild(nodeCfg.TemplateFolderName)
	for nodeType in typeConfigs do
		local template = folder:FindFirstChild(`{nodeType}Node`)
		assert(template and template:IsA("Model"), `missing node template {nodeType}Node in ServerStorage.{nodeCfg.TemplateFolderName}`)
		local hitbox = template:FindFirstChild("Hitbox")
		assert(hitbox and hitbox:IsA("BasePart"), `{template.Name} has no Hitbox part`)
		assert(template:GetAttribute("NodeType") == nodeType, `{template.Name} NodeType attribute should be {nodeType}`)
		assert(CollectionService:HasTag(template, nodeCfg.Tag), `{template.Name} is missing the {nodeCfg.Tag} tag`)
		templates[nodeType] = template
	end
end

local function loadSpawnPoints(world: Instance)
	for _, island in world:GetChildren() do
		local zone = island:GetAttribute("Zone")
		local spawnFolder = island:FindFirstChild(nodeCfg.SpawnFolderName)
		if type(zone) ~= "string" or not spawnFolder then
			continue -- bridges, decor
		end
		assert(zoneConfigs[zone], `{island.Name} has Zone "{zone}", which isn't in Config.World.Zones`)
		for _, part in spawnFolder:GetChildren() do
			local nodeType = part:GetAttribute("NodeType")
			assert(part:IsA("BasePart") and type(nodeType) == "string" and typeConfigs[nodeType], `bad node spawn point {part:GetFullName()}`)
			-- 05-items.md § The Riftsalt rule, enforced here, not just by the map.
			local contestedOnly: { [string]: boolean } = Config.Resources.ContestedOnly :: any
			assert(
				not contestedOnly[nodeType] or zoneConfigs[zone].Contested,
				`{part:GetFullName()} is a {nodeType} spawn in {zone}, which isn't a Contested zone (05-items.md § The Riftsalt rule)`
			)
			local key = poolKey(zone, nodeType)
			pools[key] = pools[key] or {}
			table.insert(pools[key], { part = part, zone = zone, nodeType = nodeType, occupied = false })
		end
	end
end

local function spawnInitialNodes()
	for _, pool in pools do
		local zone, nodeType = pool[1].zone, pool[1].nodeType
		local zoneCfg = zoneConfigs[zone]
		if zoneCfg.Respawn == "Fixed" then
			for _, point in pool do
				spawnNode(point)
			end
		else
			local active = zoneCfg.ActiveNodes and zoneCfg.ActiveNodes[nodeType] or 0
			for _ = 1, math.min(active, #pool) do
				local point = pickMigrationPoint(pool, nil)
				if point then
					spawnNode(point)
				end
			end
		end
	end
end

function NodeService.start()
	if RunService:IsStudio() then
		selfTestGrades()
	end
	loadTemplates()

	local world = workspace:WaitForChild(Config.World.FolderName)
	loadSpawnPoints(world)
	losParams.FilterType = Enum.RaycastFilterType.Include
	losParams.FilterDescendantsInstances = { world } -- only static world geometry blocks

	nodesFolder = Instance.new("Folder")
	nodesFolder.Name = nodeCfg.LiveFolderName
	nodesFolder.Parent = workspace
	spawnInitialNodes()

	local count = 0
	for _ in liveNodes do
		count += 1
	end
	print(`[Nodes] {count} nodes spawned`)

	Players.PlayerRemoving:Connect(function(player)
		lastMineAt[player] = nil
		forcedGrade[player] = nil
	end)

	local allowRate = RateLimiter.newBucket("MineNode", nodeCfg.MineRateLimit.Burst, nodeCfg.MineRateLimit.PerSecond)
	Remotes.getEvent("MineNode").OnServerEvent:Connect(function(player: Player, nodeArg: unknown)
		onMineRequest(player, allowRate, nodeArg)
	end)
end

return NodeService
