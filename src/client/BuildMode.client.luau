--!strict
-- Build UI (step 4). 02-core-loop.md § Base / Home; 14 § Prompt 4 ("a
-- simple mobile-friendly build UI (big buttons)").
--
-- The client only previews and asks. Every placement, move, removal and
-- upgrade is decided by the server (PlotService), which answers ok or a
-- reason code (R5). Hidden until the server shows it via a Player
-- attribute (Config.Base.BuildUi.VisibleAttribute), so the FTUE controls it.
--
-- How it works:
--   Build -> pick a piece -> a green ghost follows the centre of the screen
--   (PC: the mouse; phone: the last spot you tapped) -> Rotate / Place.
--   Edit -> tap one of your pieces -> Move or Remove.
-- Greybox contract: raycasts only hit Hitbox parts; Visual is never touched.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local PlotGrid = require(Shared:WaitForChild("PlotGrid"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))

local player = Players.LocalPlayer
local uiCfg = Config.Base.BuildUi
local GRID = Config.Plots.GridStuds
local RAY_LENGTH = Config.Nodes.PickRangeStuds

local placeRemote = Remotes.getFunction("PlacePiece")
local moveRemote = Remotes.getFunction("MovePiece")
local removeRemote = Remotes.getFunction("RemovePiece")
local upgradeRemote = Remotes.getFunction("UpgradeVault")
local refillRemote = Remotes.getFunction("RefillDefense")

-- Server reason codes -> short text. Build mode is after the FTUE's 2:30
-- no-text window except "BUILD VAULT" (step 14 decides what shows then).
local REASON_TEXT: { [string]: string } = {
	Busy = "Too fast",
	Invalid = "Can't do that",
	NoPlot = "You don't have a plot",
	TooFar = "Stand on your plot",
	OutOfBounds = "Off your plot",
	Overlap = "Something's in the way",
	OverBudget = "Build budget full: upgrade your Vault",
	CantAfford = "Not enough resources",
	OneVaultCore = "You already have a Vault Core",
	NotFound = "That piece is gone",
	CantRemoveCore = "The Vault Core can be moved, not removed",
	NoVaultCore = "Build a Vault Core first",
	MaxTier = "Your Vault is at max tier",
	NoDefenseSlot = "No free defense slot: upgrade your Vault",
	Full = "Already fully charged",
	Failed = "Something went wrong, try again",
}

-- ── State ────────────────────────────────────────────────────────────────

local active = false
local mode: "place" | "select" = "place"
local kind: string = Config.Base.PieceOrder[1]
local rot = 0
local movingId: string? = nil
local selected: Model? = nil
local aimTap: Vector2? = nil -- last tap on a phone (GUI coordinates)
local targetX: number?, targetZ: number? = nil, nil
local baseState: Types.BaseState? = nil
local busy = false

-- ── UI (greybox) ─────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "BuildUi"
gui.ResetOnSpawn = false
gui.Enabled = false

local SIZE = uiCfg.ButtonSize

local function makeButton(parent: Instance, text: string, order: number, width: number?): TextButton
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(width or SIZE, SIZE)
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	button.BackgroundTransparency = 0.1
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextWrapped = true
	button.Text = text
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	button.Parent = parent
	return button
end

local function makeRow(parent: Instance, order: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.Size = UDim2.fromOffset(0, 0)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	row.Parent = parent
	return row
end

local buildButton = makeButton(gui, "Build", 0, SIZE * 1.3)
buildButton.AnchorPoint = Vector2.new(1, 1)
buildButton.Position = UDim2.new(1, -16, 1, -16 - SIZE * 1.6) -- above the jump button
buildButton.Size = UDim2.fromOffset(SIZE * 1.3, SIZE * 1.3)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -12)
panel.AutomaticSize = Enum.AutomaticSize.XY
panel.Size = UDim2.fromOffset(0, 0)
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 0.4
panel.Visible = false
panel.Parent = gui
local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingLeft = UDim.new(0, 8)
panelPadding.PaddingRight = UDim.new(0, 8)
panelPadding.PaddingTop = UDim.new(0, 6)
panelPadding.PaddingBottom = UDim.new(0, 8)
panelPadding.Parent = panel
local panelLayout = Instance.new("UIListLayout")
panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
panelLayout.Padding = UDim.new(0, 6)
panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
panelLayout.Parent = panel

local infoLabel = Instance.new("TextLabel")
infoLabel.LayoutOrder = 1
infoLabel.Size = UDim2.fromOffset(SIZE * 5, 20)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.new(1, 1, 1)
infoLabel.Font = Enum.Font.GothamBold
infoLabel.TextSize = 15
infoLabel.Parent = panel

local tabRow = makeRow(panel, 2)
local pieceRow = makeRow(panel, 3)
local actionRow = makeRow(panel, 4)

-- "TripwireAlarm" -> "Tripwire Alarm"
local function displayName(pieceKind: string): string
	return (pieceKind:gsub("(%l)(%u)", "%1 %2"))
end

-- Build menu tabs (Config.Base.PieceGroups) so the row fits a phone.
local groupOf: { [string]: number } = {}
local currentGroup = 1
local tabButtons: { TextButton } = {}

local function costText(cost: { [string]: number }): string
	local parts = {}
	for _, resource in Config.Resources.Types do
		local amount = cost[resource]
		if amount and amount > 0 then
			table.insert(parts, `{amount} {resource}`)
		end
	end
	return table.concat(parts, ", ")
end

local pieceButtons: { [string]: TextButton } = {}
for order, pieceKind in Config.Base.PieceOrder do
	local cfg = PlotGrid.pieceConfig(pieceKind) :: any
	pieceButtons[pieceKind] = makeButton(pieceRow, `{displayName(pieceKind)}\n{costText(cfg.Cost)}`, order, SIZE * 1.4)
end
for index, group in Config.Base.PieceGroups do
	for _, pieceKind in group.Kinds do
		groupOf[pieceKind] = index
	end
	tabButtons[index] = makeButton(tabRow, group.Name, index, SIZE * 1.8)
	tabButtons[index].Size = UDim2.fromOffset(SIZE * 1.8, 30)
end

local rotateButton = makeButton(actionRow, "Rotate", 1)
local placeButton = makeButton(actionRow, "Place", 2)
local editButton = makeButton(actionRow, "Edit", 3)
local moveButton = makeButton(actionRow, "Move", 4)
local removeButton = makeButton(actionRow, "Remove", 5)
local upgradeButton = makeButton(actionRow, "Upgrade", 6, SIZE * 1.8)
local refillButton = makeButton(actionRow, "Refill", 7, SIZE * 1.6)

local message = Instance.new("TextLabel")
message.AnchorPoint = Vector2.new(0.5, 1)
message.Position = UDim2.new(0.5, 0, 0.62, 0)
message.Size = UDim2.fromOffset(360, 30)
message.BackgroundColor3 = Color3.new(0, 0, 0)
message.BackgroundTransparency = 0.35
message.TextColor3 = Color3.new(1, 1, 1)
message.Font = Enum.Font.GothamBold
message.TextSize = 16
message.Visible = false
message.Parent = gui

gui.Parent = player:WaitForChild("PlayerGui")

local messageToken = 0
local function showMessage(text: string)
	messageToken += 1
	local token = messageToken
	message.Text = text
	message.Visible = true
	task.delay(uiCfg.MessageSeconds, function()
		if messageToken == token then
			message.Visible = false
		end
	end)
end

-- ── Ghost preview + selection highlight (client-only) ────────────────────

local ghost = Instance.new("Part")
ghost.Name = "BuildGhost"
ghost.Anchored = true
ghost.CanCollide = false
ghost.CanQuery = false
ghost.CanTouch = false
ghost.CastShadow = false
ghost.Material = Enum.Material.ForceField
ghost.Color = uiCfg.GhostColor
ghost.Transparency = uiCfg.GhostTransparency

local highlight = Instance.new("Highlight")
highlight.FillTransparency = 1
highlight.OutlineColor = uiCfg.SelectColor
highlight.DepthMode = Enum.HighlightDepthMode.Occluded

local function myPlotHitbox(): BasePart?
	local index = player:GetAttribute("PlotIndex")
	if index == nil then
		return nil
	end
	for _, plot in CollectionService:GetTagged(Config.Plots.Tag) do
		if plot:GetAttribute("PlotIndex") == index and plot:IsDescendantOf(workspace) then
			local hitbox = plot:FindFirstChild("Hitbox")
			return if hitbox and hitbox:IsA("BasePart") then hitbox else nil
		end
	end
	return nil
end

-- Input positions (taps, clicks) are in GUI coordinates, below the top bar:
-- ScreenPointToRay. GetMouseLocation and the viewport centre include the top
-- bar: ViewportPointToRay.
local function aimRay(camera: Camera): Ray
	if aimTap then
		return camera:ScreenPointToRay(aimTap.X, aimTap.Y)
	end
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local mouse = UserInputService:GetMouseLocation()
		return camera:ViewportPointToRay(mouse.X, mouse.Y)
	end
	local centre = camera.ViewportSize / 2
	return camera:ViewportPointToRay(centre.X, centre.Y)
end

local function updateGhost()
	targetX, targetZ = nil, nil
	local plotHitbox = myPlotHitbox()
	local camera = workspace.CurrentCamera
	if not active or mode ~= "place" or not plotHitbox or not camera then
		ghost.Parent = nil
		return
	end
	local ray = aimRay(camera)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plotHitbox }
	local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	if not result then
		ghost.Parent = nil
		return
	end
	local cfg = PlotGrid.pieceConfig(kind) :: any
	local x, z = PlotGrid.anchorNear(plotHitbox, result.Position, kind, rot)
	targetX, targetZ = x, z
	-- Unrotated size; pieceCFrame applies the rotation.
	ghost.Size = if PlotGrid.isEdge(kind)
		then Vector3.new(GRID, cfg.Height, uiCfg.EdgeGhostThickness)
		else Vector3.new(cfg.Cells[1] * GRID, cfg.Height, cfg.Cells[2] * GRID)
	ghost.CFrame = PlotGrid.pieceCFrame(plotHitbox, kind, x, z, rot, cfg.Height)
	ghost.Parent = camera
end

local function myPieceHitboxes(): { Instance }
	local hitboxes = {}
	for _, piece in CollectionService:GetTagged(Config.Base.PieceTag) do
		if piece:GetAttribute("OwnerUserId") == player.UserId and piece:IsDescendantOf(workspace) then
			local hitbox = piece:FindFirstChild("Hitbox")
			if hitbox then
				table.insert(hitboxes, hitbox)
			end
		end
	end
	return hitboxes
end

-- ── Refreshing the panel ─────────────────────────────────────────────────

local function refreshPanel()
	panel.Visible = active
	buildButton.Text = if active then "Done" else "Build"
	for pieceKind, button in pieceButtons do
		local chosen = mode == "place" and movingId == nil and pieceKind == kind
		button.BackgroundColor3 = if chosen then Color3.fromRGB(40, 120, 70) else Color3.fromRGB(45, 45, 60)
		button.Visible = groupOf[pieceKind] == currentGroup
	end
	for index, button in tabButtons do
		button.BackgroundColor3 = if index == currentGroup then Color3.fromRGB(70, 70, 100) else Color3.fromRGB(45, 45, 60)
	end
	-- Defenses show their charges (public: 02 § Defenses "a loadout puzzle
	-- raiders can read") and can be refilled in Edit mode.
	local charges = selected and selected:GetAttribute("Charges")
	local maxCharges = selected and selected:GetAttribute("MaxCharges")
	local selectedKind = selected and selected:GetAttribute("Kind")
	local defenseCfg = if typeof(selectedKind) == "string" then (Config.Defenses.Kinds :: any)[selectedKind] else nil
	refillButton.Visible = mode == "select" and defenseCfg ~= nil and typeof(charges) == "number"
	if refillButton.Visible and defenseCfg then
		refillButton.Text = `Refill {charges}/{maxCharges}\n{costText(defenseCfg.RefillCost)}`
	end
	editButton.BackgroundColor3 = if mode == "select" then Color3.fromRGB(40, 120, 70) else Color3.fromRGB(45, 45, 60)
	placeButton.Text = if movingId then "Put here" else "Place"
	rotateButton.Visible = mode == "place"
	placeButton.Visible = mode == "place"
	moveButton.Visible = mode == "select" and selected ~= nil
	removeButton.Visible = mode == "select" and selected ~= nil and selected:GetAttribute("Kind") ~= "VaultCore"

	local state = baseState
	if state then
		infoLabel.Text = `Vault tier {state.Tier}/{state.MaxTier}   ·   Budget {state.BudgetUsed}/{state.Budget}   ·   Defenses {state.DefenseSlotsUsed}/{state.DefenseSlots}`
		upgradeButton.Visible = state.UpgradeCost ~= nil
		if state.UpgradeCost then
			upgradeButton.Text = `Upgrade Vault\n{costText(state.UpgradeCost)}`
		end
	else
		infoLabel.Text = "..."
		upgradeButton.Visible = false
	end
end

local chargesConnection: RBXScriptConnection? = nil
local function select(model: Model?)
	selected = model
	highlight.Adornee = model
	highlight.Parent = if model then model else nil
	if chargesConnection then
		chargesConnection:Disconnect()
		chargesConnection = nil
	end
	if model then
		chargesConnection = model:GetAttributeChangedSignal("Charges"):Connect(refreshPanel)
	end
	refreshPanel()
end

local function setActive(on: boolean)
	active = on
	player:SetAttribute(uiCfg.ClientModeAttribute, on)
	mode = "place"
	movingId = nil
	aimTap = nil
	select(nil)
	updateGhost()
	refreshPanel()
end

-- ── Asking the server ────────────────────────────────────────────────────

local function ask(remote: RemoteFunction, ...: any): boolean
	if busy then
		return false
	end
	busy = true
	local ok, accepted, reason = pcall(remote.InvokeServer, remote, ...)
	busy = false
	if not ok then
		showMessage(REASON_TEXT.Failed)
		return false
	end
	if not accepted then
		showMessage(REASON_TEXT[reason] or REASON_TEXT.Failed)
		return false
	end
	return true
end

local function doPlace()
	if not targetX or not targetZ then
		showMessage(REASON_TEXT.OutOfBounds)
		return
	end
	if movingId then
		if ask(moveRemote, movingId, targetX, targetZ, rot) then
			movingId = nil
			mode = "select"
			select(nil)
			updateGhost()
		end
	else
		ask(placeRemote, kind, targetX, targetZ, rot)
	end
end

-- `guiPoint` = an input position (GUI coordinates).
local function trySelect(guiPoint: Vector2)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local ray = camera:ScreenPointToRay(guiPoint.X, guiPoint.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = myPieceHitboxes()
	local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	local model = if result and result.Instance.Parent and result.Instance.Parent:IsA("Model") then result.Instance.Parent else nil
	select(model :: Model?)
end

-- ── Buttons and input ────────────────────────────────────────────────────

buildButton.Activated:Connect(function()
	setActive(not active)
end)

for pieceKind, button in pieceButtons do
	button.Activated:Connect(function()
		kind = pieceKind
		mode = "place"
		movingId = nil
		select(nil)
	end)
end

rotateButton.Activated:Connect(function()
	rot = (rot + 1) % 4
end)

placeButton.Activated:Connect(doPlace)

editButton.Activated:Connect(function()
	mode = if mode == "select" then "place" else "select"
	movingId = nil
	select(nil)
end)

moveButton.Activated:Connect(function()
	local model = selected
	if not model then
		return
	end
	local id = model:GetAttribute("PieceId")
	local pieceKind = model:GetAttribute("Kind")
	if typeof(id) ~= "string" or typeof(pieceKind) ~= "string" then
		return
	end
	movingId = id
	kind = pieceKind
	mode = "place"
	refreshPanel()
end)

for index, button in tabButtons do
	button.Activated:Connect(function()
		currentGroup = index
		refreshPanel()
	end)
end

refillButton.Activated:Connect(function()
	local model = selected
	local id = model and model:GetAttribute("PieceId")
	if typeof(id) == "string" and ask(refillRemote, id) then
		showMessage("Refilled")
	end
end)

removeButton.Activated:Connect(function()
	local model = selected
	local id = model and model:GetAttribute("PieceId")
	if typeof(id) == "string" and ask(removeRemote, id) then
		select(nil)
	end
end)

upgradeButton.Activated:Connect(function()
	if ask(upgradeRemote) then
		showMessage("Vault upgraded")
	end
end)

-- PC: click to place / select, R to rotate.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not active or gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if mode == "place" then
			doPlace()
		else
			trySelect(Vector2.new(input.Position.X, input.Position.Y))
		end
	elseif input.KeyCode == Enum.KeyCode.R and mode == "place" then
		rot = (rot + 1) % 4
	end
end)

-- Phone: a tap aims the ghost (then press Place) or selects a piece.
UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processedByUI: boolean)
	if not active or processedByUI then
		return
	end
	if mode == "place" then
		aimTap = position
	else
		trySelect(position)
	end
end)

RunService.RenderStepped:Connect(function()
	if active then
		updateGhost()
	end
end)

-- ── Visibility + state from the server ───────────────────────────────────

local function applyVisibility()
	local visible = player:GetAttribute(uiCfg.VisibleAttribute) == true
	gui.Enabled = visible
	if not visible and active then
		setActive(false)
	end
end
player:GetAttributeChangedSignal(uiCfg.VisibleAttribute):Connect(applyVisibility)
applyVisibility()

local received = false
Remotes.getEvent("BaseChanged").OnClientEvent:Connect(function(state: Types.BaseState)
	received = true
	baseState = state
	refreshPanel()
end)

refreshPanel()
local getBaseState = Remotes.getFunction("GetBaseState")
for _ = 1, Config.Bank.HudStartupTries do
	if received then
		break
	end
	local ok, result = pcall(getBaseState.InvokeServer, getBaseState)
	if ok and result and not received then
		received = true
		baseState = result
		refreshPanel()
		break
	end
	task.wait(Config.Bank.HudStartupRetrySeconds)
end
