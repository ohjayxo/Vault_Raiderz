--!strict
-- PlotService: player plots, base building, the build budget and the Vault
-- Core tier. The only service that writes the Base section and the
-- LifetimePeakVaultTier field (Config.Data.SectionOwners / Packed).
--
-- Docs: 02-core-loop.md § World Structure, § Base / Home, § Buildable
-- elements, § Build budget (D57); 14 § Prompt 4.
--
-- * Each player gets a free plot while they're on this server; their saved
--   pieces are rebuilt on it. Sharding is a stub (ShardService).
-- * The client sends intents only: "place a Wall at cell (x, z), rotation r".
--   The server checks the plot is theirs and they're on it, the cell is on
--   the grid, nothing overlaps, the budget, one Vault Core, and the price,
--   then saves and spawns the piece (R5).
-- * Placing the Vault Core makes tier 1; upgrading raises it (max = the
--   last Config.Bank.CapacityByTier tier). The tier only ever goes up (R2).
-- * Removing refunds half (Config.Base.RemoveRefundFraction) so walls can't
--   hide resources from raiders. The Vault Core can only be moved.
-- * Greybox contract: pieces are clones of ServerStorage.PieceTemplates;
--   code uses Hitbox, never Visual.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NodeMath = require(ReplicatedStorage.Shared.NodeMath)
local PlotGrid = require(ReplicatedStorage.Shared.PlotGrid)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local AnomalyLog = require(ServerScriptService.Util.AnomalyLog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local VaultService = require(script.Parent.VaultService)
local ShardService = require(script.Parent.ShardService)

local OWNER = "PlotService"
local baseCfg = Config.Base
local plotCfg = Config.Plots
local MAX_TIER = #Config.Bank.CapacityByTier
local VAULT_CORE = "VaultCore"

type BaseData = { VaultTier: number, Archived: boolean, Pieces: { Types.PlacedPiece } }
type Slot = { index: number, model: Model, hitbox: BasePart, owner: Player? }

local slots: { Slot } = {}
local slotOf: { [Player]: Slot } = {}
local modelsOf: { [Player]: { [string]: Model } } = {} -- piece id -> model
local templates: { [string]: Model } = {}
local liveFolder: Folder

local logAnomaly = AnomalyLog.new("Build")

local PlotService = {}

-- ── Helpers ──────────────────────────────────────────────────────────────

local function budgetFor(tier: number): number
	local budgets = baseCfg.BudgetByTier
	return budgets[math.clamp(tier, 1, #budgets)]
end

local function budgetUsed(pieces: { Types.PlacedPiece }): number
	local used = 0
	for _, piece in pieces do
		local cfg = PlotGrid.pieceConfig(piece.Kind)
		if cfg then
			used += cfg.BudgetCost
		end
	end
	return used
end

local defenseKinds: { [string]: any } = Config.Defenses.Kinds :: any

-- D57 "Defense slots": a cap per vault tier on top of the budget.
local function defenseSlotsFor(tier: number): number
	local slots = Config.Defenses.SlotsByTier
	return slots[math.clamp(tier, 1, #slots)]
end

local function countDefenses(pieces: { Types.PlacedPiece }): number
	local count = 0
	for _, piece in pieces do
		if defenseKinds[piece.Kind] then
			count += 1
		end
	end
	return count
end

local function countKind(pieces: { Types.PlacedPiece }, kind: string): number
	local count = 0
	for _, piece in pieces do
		if piece.Kind == kind then
			count += 1
		end
	end
	return count
end

local function findPiece(pieces: { Types.PlacedPiece }, id: string): (Types.PlacedPiece?, number?)
	for i, piece in pieces do
		if piece.Id == id then
			return piece, i
		end
	end
	return nil, nil
end

-- True if the footprint is free, ignoring the piece with id `ignoreId`.
local function isFree(pieces: { Types.PlacedPiece }, kind: string, x: number, z: number, rot: number, ignoreId: string?): boolean
	local taken: { [string]: boolean } = {}
	for _, piece in pieces do
		if piece.Id ~= ignoreId and PlotGrid.pieceConfig(piece.Kind) then
			for _, key in PlotGrid.cellsOf(piece.Kind, piece.X, piece.Z, piece.Rot) do
				taken[key] = true
			end
		end
	end
	for _, key in PlotGrid.cellsOf(kind, x, z, rot) do
		if taken[key] then
			return false
		end
	end
	return true
end

local function isWholeNumber(value: unknown): boolean
	return typeof(value) == "number" and value == math.floor(value :: number) and value == value
end

local function raisePeak(player: Player, tier: number)
	local peak = PlayerDataService.getPacked(player, "LifetimePeakVaultTier") or 0
	if tier > peak then
		PlayerDataService.setPacked(player, "LifetimePeakVaultTier", OWNER, tier)
	end
end

-- ── State for the owner's build UI ───────────────────────────────────────

function PlotService.getState(player: Player): Types.BaseState?
	local base: BaseData? = PlayerDataService.get(player, "Base")
	if not base then
		return nil
	end
	local hasCore = countKind(base.Pieces, VAULT_CORE) > 0
	local canUpgrade = hasCore and base.VaultTier >= 1 and base.VaultTier < MAX_TIER
	return {
		Tier = base.VaultTier,
		MaxTier = MAX_TIER,
		HasVaultCore = hasCore,
		BudgetUsed = budgetUsed(base.Pieces),
		Budget = budgetFor(base.VaultTier),
		UpgradeCost = if canUpgrade then baseCfg.UpgradeCostByTier[base.VaultTier + 1] else nil,
		DefenseSlotsUsed = countDefenses(base.Pieces),
		DefenseSlots = defenseSlotsFor(base.VaultTier),
	}
end

-- Sends the owner their build state. Also call after any tier change made
-- outside this service (Studio debug).
function PlotService.refresh(player: Player)
	local state = PlotService.getState(player)
	if state then
		Remotes.getEvent("BaseChanged"):FireClient(player, state)
	end
end

-- Where this player respawns: on their plot, at the edge nearest the
-- Homestead (the bridge end), dropped from a little above so they land on
-- whatever is built there. nil if they have no plot. (Josh's call, step 5.)
function PlotService.getSpawnCFrame(player: Player): CFrame?
	local slot = slotOf[player]
	if not slot then
		return nil
	end
	local hitbox = slot.hitbox
	local centre = hitbox.Position
	local toHome = Vector3.new(-centre.X, 0, -centre.Z)
	local direction = if toHome.Magnitude > 0 then toHome.Unit else Vector3.xAxis
	local edge = centre + direction * (math.min(hitbox.Size.X, hitbox.Size.Z) / 2 - plotCfg.GridStuds)
	local position = edge + Vector3.new(0, hitbox.Size.Y / 2 + 4, 0)
	return CFrame.lookAt(position, position + direction * -1) -- face into the plot
end

-- The build surface of this player's plot, or nil (Scav Waves use it).
function PlotService.getPlotHitbox(player: Player): BasePart?
	local slot = slotOf[player]
	return if slot then slot.hitbox else nil
end

-- Shows or hides this player's Build button (R4: the FTUE decides, step 14).
function PlotService.setBuildUiVisible(player: Player, visible: boolean)
	player:SetAttribute(baseCfg.BuildUi.VisibleAttribute, visible)
end

-- ── Piece models ─────────────────────────────────────────────────────────

local function spawnPiece(player: Player, slot: Slot, piece: Types.PlacedPiece)
	local model = templates[piece.Kind]:Clone()
	local hitbox = model:FindFirstChild("Hitbox") :: BasePart
	local target = PlotGrid.pieceCFrame(slot.hitbox, piece.Kind, piece.X, piece.Z, piece.Rot, hitbox.Size.Y)
	model:PivotTo(target * hitbox.CFrame:ToObjectSpace(model:GetPivot()))
	model.Name = piece.Kind
	-- Set before parenting: VaultService sets up a Vault Core as soon as it
	-- appears and checks OwnerUserId.
	model:SetAttribute("PieceId", piece.Id)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("BudgetCost", (PlotGrid.pieceConfig(piece.Kind) :: any).BudgetCost)
	model.Parent = liveFolder
	modelsOf[player][piece.Id] = model
end

local function movePieceModel(player: Player, slot: Slot, piece: Types.PlacedPiece)
	local model = modelsOf[player][piece.Id]
	if not model then
		return
	end
	local hitbox = model:FindFirstChild("Hitbox") :: BasePart
	local target = PlotGrid.pieceCFrame(slot.hitbox, piece.Kind, piece.X, piece.Z, piece.Rot, hitbox.Size.Y)
	model:PivotTo(target * hitbox.CFrame:ToObjectSpace(model:GetPivot()))
end

-- A saved piece this server can build. Anything else stays in the save
-- untouched (R2: never delete a player's things) and is just not shown.
local function isBuildable(slot: Slot, piece: any): boolean
	if type(piece) ~= "table" or type(piece.Kind) ~= "string" or not templates[piece.Kind] then
		return false
	end
	if not isWholeNumber(piece.X) or not isWholeNumber(piece.Z) or not isWholeNumber(piece.Rot) then
		return false
	end
	local w, d = PlotGrid.footprint(piece.Kind, piece.Rot)
	return PlotGrid.inBounds(slot.hitbox, piece.X, piece.Z, w, d)
end

-- ── Plot assignment ──────────────────────────────────────────────────────

local function assignPlot(player: Player)
	ShardService.getNeighborhood(player) -- stub: logs the band, one neighborhood
	local slot: Slot? = nil
	for _, candidate in slots do
		if candidate.owner == nil then
			slot = candidate
			break
		end
	end
	if not slot then
		warn(`[Plots] no free plot for {player.Name}: set Max Players to {plotCfg.Count} (Config.Plots.Count)`)
		return
	end
	slot.owner = player
	slotOf[player] = slot
	modelsOf[player] = {}
	slot.model:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("PlotIndex", slot.index)

	local base: BaseData = PlayerDataService.get(player, "Base")
	local skipped = 0
	for _, piece in base.Pieces do
		if isBuildable(slot, piece) then
			spawnPiece(player, slot, piece)
		else
			skipped += 1
		end
	end
	if skipped > 0 then
		warn(`[Plots] {player.Name}: {skipped} saved piece(s) can't be built here and were left in the save`)
	end
	raisePeak(player, base.VaultTier)
	print(`[Plots] {player.Name} -> Plot{slot.index} ({#base.Pieces - skipped} pieces, tier {base.VaultTier})`)

	if baseCfg.BuildUi.ShowBeforeFtue then
		PlotService.setBuildUiVisible(player, true)
	end
	PlotService.refresh(player)
end

local function releasePlot(player: Player)
	local models = modelsOf[player]
	if models then
		for _, model in models do
			model:Destroy()
		end
	end
	modelsOf[player] = nil
	local slot = slotOf[player]
	if slot then
		slot.owner = nil
		slot.model:SetAttribute("OwnerUserId", nil)
	end
	slotOf[player] = nil
end

-- ── Validation shared by every build intent ──────────────────────────────

-- The player's plot if they're alive and standing on/near it.
local function builderSlot(player: Player): (Slot?, string?)
	local slot = slotOf[player]
	if not slot then
		return nil, "NoPlot"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, "TooFar"
	end
	local distance = NodeMath.distanceToHitbox(slot.hitbox, root.Position)
	if distance > plotCfg.BuildReach then
		-- The UI only builds on your own plot, so this is either a player who
		-- walked off mid-build or a modified client. Logged, throttled.
		logAnomaly(player, "built away from their plot", `{math.floor(distance)} > {plotCfg.BuildReach} studs`)
		return nil, "TooFar"
	end
	return slot, nil
end

-- Returns x, z, rot if they're sane grid values, else nil.
local function parseCell(player: Player, x: unknown, z: unknown, rot: unknown): (number?, number, number)
	if not isWholeNumber(x) or not isWholeNumber(z) or not isWholeNumber(rot) or (rot :: number) < 0 or (rot :: number) > 3 then
		logAnomaly(player, "sent a bad grid cell")
		return nil, 0, 0
	end
	return x :: number, z :: number, rot :: number
end

-- ── Build intents ────────────────────────────────────────────────────────

local function place(player: Player, kindArg: unknown, xArg: unknown, zArg: unknown, rotArg: unknown): (boolean, string?)
	if typeof(kindArg) ~= "string" or not templates[kindArg :: string] then
		logAnomaly(player, "tried to place an unknown piece")
		return false, "Invalid"
	end
	local kind = kindArg :: string
	local x, z, rot = parseCell(player, xArg, zArg, rotArg)
	if not x then
		return false, "Invalid"
	end
	local slot, reason = builderSlot(player)
	if not slot then
		return false, reason
	end
	local base: BaseData? = PlayerDataService.get(player, "Base")
	if not base then
		return false, "Failed"
	end
	local cfg = PlotGrid.pieceConfig(kind) :: any
	local w, d = PlotGrid.footprint(kind, rot)
	if not PlotGrid.inBounds(slot.hitbox, x, z, w, d) then
		return false, "OutOfBounds"
	end
	if kind == VAULT_CORE and countKind(base.Pieces, VAULT_CORE) >= baseCfg.MaxVaultCores then
		return false, "OneVaultCore"
	end
	if defenseKinds[kind] and countDefenses(base.Pieces) >= defenseSlotsFor(base.VaultTier) then
		return false, "NoDefenseSlot"
	end
	if not isFree(base.Pieces, kind, x, z, rot, nil) then
		return false, "Overlap"
	end
	if budgetUsed(base.Pieces) + cfg.BudgetCost > budgetFor(base.VaultTier) then
		return false, "OverBudget"
	end
	if not VaultService.spend(player, cfg.Cost) then
		return false, "CantAfford"
	end

	-- Nothing above yields, so the checks still hold when we write.
	local piece: Types.PlacedPiece = { Id = HttpService:GenerateGUID(false), Kind = kind, X = x, Z = z, Rot = rot }
	local tierBefore = base.VaultTier
	local newTier = tierBefore
	local ok = PlayerDataService.update(player, "Base", OWNER, function(current: BaseData)
		table.insert(current.Pieces, piece)
		if kind == VAULT_CORE and current.VaultTier < 1 then
			current.VaultTier = 1 -- FTUE "BUILD VAULT" (02 § FTUE spec)
		end
		newTier = current.VaultTier
		return current
	end)
	if not ok then
		VaultService.grant(player, cfg.Cost) -- give the price back
		return false, "Failed"
	end
	spawnPiece(player, slot, piece)
	if newTier ~= tierBefore then
		raisePeak(player, newTier)
		VaultService.refresh(player) -- capacity changed
	end
	PlotService.refresh(player)
	return true, nil
end

local function move(player: Player, idArg: unknown, xArg: unknown, zArg: unknown, rotArg: unknown): (boolean, string?)
	if typeof(idArg) ~= "string" then
		logAnomaly(player, "sent a bad piece id")
		return false, "Invalid"
	end
	local x, z, rot = parseCell(player, xArg, zArg, rotArg)
	if not x then
		return false, "Invalid"
	end
	local slot, reason = builderSlot(player)
	if not slot then
		return false, reason
	end
	local base: BaseData? = PlayerDataService.get(player, "Base")
	if not base then
		return false, "Failed"
	end
	local piece = findPiece(base.Pieces, idArg :: string)
	if not piece or not templates[piece.Kind] then
		return false, "NotFound" -- also: someone else's piece id
	end
	local w, d = PlotGrid.footprint(piece.Kind, rot)
	if not PlotGrid.inBounds(slot.hitbox, x, z, w, d) then
		return false, "OutOfBounds"
	end
	if not isFree(base.Pieces, piece.Kind, x, z, rot, piece.Id) then
		return false, "Overlap"
	end

	local moved: Types.PlacedPiece? = nil
	local ok = PlayerDataService.update(player, "Base", OWNER, function(current: BaseData)
		local target = findPiece(current.Pieces, piece.Id)
		if target then
			target.X, target.Z, target.Rot = x, z, rot
			moved = target
		end
		return current
	end)
	if not ok or not moved then
		return false, "Failed"
	end
	movePieceModel(player, slot, moved)
	return true, nil
end

local function remove(player: Player, idArg: unknown): (boolean, string?)
	if typeof(idArg) ~= "string" then
		logAnomaly(player, "sent a bad piece id")
		return false, "Invalid"
	end
	local slot, reason = builderSlot(player)
	if not slot then
		return false, reason
	end
	local base: BaseData? = PlayerDataService.get(player, "Base")
	if not base then
		return false, "Failed"
	end
	local piece = findPiece(base.Pieces, idArg :: string)
	if not piece then
		return false, "NotFound"
	end
	if piece.Kind == VAULT_CORE then
		return false, "CantRemoveCore" -- the tier and the bank must never drop (R2)
	end

	local removed = false
	local ok = PlayerDataService.update(player, "Base", OWNER, function(current: BaseData)
		local _, index = findPiece(current.Pieces, piece.Id)
		if index then
			table.remove(current.Pieces, index)
			removed = true
		end
		return current
	end)
	if not ok or not removed then
		return false, "Failed"
	end
	local model = modelsOf[player][piece.Id]
	if model then
		model:Destroy()
		modelsOf[player][piece.Id] = nil
	end

	local cfg = PlotGrid.pieceConfig(piece.Kind)
	if cfg then
		local refund: { [string]: number } = {}
		for resource, amount in cfg.Cost do
			local back = math.floor(amount * baseCfg.RemoveRefundFraction)
			if back > 0 then
				refund[resource] = back
			end
		end
		if next(refund) then
			VaultService.grant(player, refund)
		end
	end
	PlotService.refresh(player)
	return true, nil
end

local function upgradeVault(player: Player): (boolean, string?)
	local _, reason = builderSlot(player)
	if reason then
		return false, reason
	end
	local base: BaseData? = PlayerDataService.get(player, "Base")
	if not base then
		return false, "Failed"
	end
	if countKind(base.Pieces, VAULT_CORE) == 0 or base.VaultTier < 1 then
		return false, "NoVaultCore"
	end
	if base.VaultTier >= MAX_TIER then
		return false, "MaxTier"
	end
	local nextTier = base.VaultTier + 1
	local cost = baseCfg.UpgradeCostByTier[nextTier]
	if not VaultService.spend(player, cost) then
		return false, "CantAfford"
	end
	local ok = PlayerDataService.update(player, "Base", OWNER, function(current: BaseData)
		current.VaultTier = nextTier
		return current
	end)
	if not ok then
		VaultService.grant(player, cost)
		return false, "Failed"
	end
	print(`[Plots] {player.Name} upgraded their Vault Core to tier {nextTier}`)
	raisePeak(player, nextTier)
	VaultService.refresh(player)
	PlotService.refresh(player)
	return true, nil
end

-- ── Start-up ─────────────────────────────────────────────────────────────

local function loadSlots()
	local world = workspace:WaitForChild(Config.World.FolderName)
	for _, instance in CollectionService:GetTagged(plotCfg.Tag) do
		if instance:IsA("Model") and instance:IsDescendantOf(world) then
			local hitbox = instance:FindFirstChild("Hitbox")
			local index = instance:GetAttribute("PlotIndex")
			assert(hitbox and hitbox:IsA("BasePart"), `{instance:GetFullName()} has no Hitbox part`)
			assert(typeof(index) == "number", `{instance:GetFullName()} has no PlotIndex attribute`)
			table.insert(slots, { index = index, model = instance, hitbox = hitbox, owner = nil })
		end
	end
	table.sort(slots, function(a, b)
		return a.index < b.index
	end)
	if #slots ~= plotCfg.Count then
		warn(`[Plots] found {#slots} plots in the world, Config.Plots.Count is {plotCfg.Count} (re-run gen_world.py?)`)
	end
end

local function loadTemplates()
	local folder = ServerStorage:WaitForChild(baseCfg.TemplateFolderName)
	for kind in baseCfg.Pieces :: any do
		local template = folder:FindFirstChild(kind)
		assert(template and template:IsA("Model"), `ServerStorage.{baseCfg.TemplateFolderName}.{kind} is missing`)
		assert(template:FindFirstChild("Hitbox"), `piece template {kind} has no Hitbox`)
		templates[kind] = template
	end
end

function PlotService.start()
	assert(#baseCfg.BudgetByTier == MAX_TIER, "Config.Base.BudgetByTier must match Config.Bank.CapacityByTier's length")
	assert(#baseCfg.UpgradeCostByTier == MAX_TIER, "Config.Base.UpgradeCostByTier must match Config.Bank.CapacityByTier's length")
	assert(#Config.Defenses.SlotsByTier == MAX_TIER, "Config.Defenses.SlotsByTier must match Config.Bank.CapacityByTier's length")
	loadTemplates()
	loadSlots()

	liveFolder = Instance.new("Folder")
	liveFolder.Name = baseCfg.LiveFolderName
	liveFolder.Parent = workspace

	PlayerDataService.Loaded:Connect(assignPlot)
	Players.PlayerRemoving:Connect(releasePlot)

	-- One burst bucket for every build intent: a human taps a few times a
	-- second at most; scripts get cut off and logged.
	local rate = baseCfg.BuildRateLimit
	local allowBuild = RateLimiter.newBucket("Build", rate.Burst, rate.PerSecond)
	local function guarded(handler: (Player, ...unknown) -> (boolean, string?)): (Player, ...unknown) -> (boolean, string?)
		return function(player: Player, ...: unknown): (boolean, string?)
			if not allowBuild(player) then
				return false, "Busy"
			end
			return handler(player, ...)
		end
	end
	Remotes.getFunction("PlacePiece").OnServerInvoke = guarded(place)
	Remotes.getFunction("MovePiece").OnServerInvoke = guarded(move)
	Remotes.getFunction("RemovePiece").OnServerInvoke = guarded(remove)
	Remotes.getFunction("UpgradeVault").OnServerInvoke = guarded(upgradeVault)

	local allowState = RateLimiter.new("GetBaseState", baseCfg.StateCooldownSeconds)
	Remotes.getFunction("GetBaseState").OnServerInvoke = function(player: Player): Types.BaseState?
		if not allowState(player) then
			return nil
		end
		return PlotService.getState(player)
	end
end

return PlotService
