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
--   Build -> Place tab: pick a piece -> a green ghost follows the centre of the
--   screen (PC: the mouse; phone: the last spot you tapped) -> Rotate / Place.
--   Edit tab: tap one of your pieces -> Move or Remove.
--   A tile you can't build right now is greyed and says why ("Built", "No slot",
--   "Over budget", or its cost in red); the server still decides.
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
local NodeMath = require(Shared:WaitForChild("NodeMath"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))
local UiStyle = require(Shared:WaitForChild("UiStyle"))

local player = Players.LocalPlayer
local uiCfg = Config.Base.BuildUi
local style = Config.UiStyle
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
local vaultState: Types.VaultState? = nil -- for "can I afford it" hints on the tiles
local shortScreen = false -- phone landscape: keep the panel low
local busy = false

-- ── UI ───────────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "BuildUi"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10 -- menus draw above HUD
gui.Enabled = false

local SIZE = uiCfg.ButtonSize
local BUTTON_SIZE = SIZE * 1.3
-- [PH] invented look-only: the old layout's margins, kept so the Build button
-- and panel sit where they did (above the jump button, clear of the right column).
local BUTTON_MARGIN = 16 -- px: Build/Done from the screen edge
local BOTTOM_GAP = 12 -- px: panel from the bottom edge

-- Right end of the shared right-thumb column's bottom row (Attack sits to its left).
local buildButton = UiStyle.hudButton(UiStyle.thumbColumn(player:WaitForChild("PlayerGui")).main, "Build", "primary", BUTTON_SIZE, BUTTON_SIZE, true)
buildButton.LayoutOrder = 2
buildButton.Visible = false

local panel = UiStyle.dockPanel(gui)
panel.AutomaticSize = Enum.AutomaticSize.Y -- fixed width (set by layoutPanel) so rows can wrap on a phone
panel.AnchorPoint = Vector2.new(0, 1)

-- A centred row that wraps onto more lines when the panel is narrow.
local function wrapRow(order: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.BackgroundTransparency = 1
	row.Parent = panel
	local layout = UiStyle.list(row, true, style.Gap)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Wraps = true
	return row
end

-- Place | Edit: a two-way switch at the top of the panel, so the mode is obvious
-- and the buttons below only show what belongs to it.
local modeBar = UiStyle.tabBar(panel, { "Place", "Edit" }, 0)
do
	local layout = modeBar.frame:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
end

local infoRow = wrapRow(1)
local tierPill = UiStyle.pill(infoRow, "...")
tierPill.LayoutOrder = 1
local budgetPill = UiStyle.pill(infoRow, "")
budgetPill.LayoutOrder = 2
local defensePill = UiStyle.pill(infoRow, "")
defensePill.LayoutOrder = 3

-- "TripwireAlarm" -> "Tripwire Alarm"
local function displayName(pieceKind: string): string
	return (pieceKind:gsub("(%l)(%u)", "%1 %2"))
end

-- Build menu tabs (Config.Base.PieceGroups) so the grid fits a phone.
local groupOf: { [string]: number } = {}
local groupNames: { string } = {}
for index, group in Config.Base.PieceGroups do
	groupNames[index] = group.Name
	for _, pieceKind in group.Kinds do
		groupOf[pieceKind] = index
	end
end
local currentGroup = 1
local tabBar = UiStyle.tabBar(panel, groupNames, 2)
do
	local layout = tabBar.frame:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Wraps = true -- a narrow phone drops the last tab to a second line
	end
	tabBar.frame.AutomaticSize = Enum.AutomaticSize.Y
end

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

-- Piece tiles in a grid (Config PiecesPerRow per row): six defenses side by
-- side were wider than a phone.
local pieceGrid = UiStyle.tileGrid(panel, 3)
do
	local layout = pieceGrid:FindFirstChildOfClass("UIGridLayout")
	if layout then
		layout.FillDirectionMaxCells = uiCfg.PiecesPerRow
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
end
local pieceTiles: { [string]: UiStyle.Tile } = {}
for order, pieceKind in Config.Base.PieceOrder do
	local cfg = PlotGrid.pieceConfig(pieceKind) :: any
	pieceTiles[pieceKind] = UiStyle.tile(pieceGrid, displayName(pieceKind), costText(cfg.Cost), order)
end

-- Edit mode with nothing picked: say what to do.
local editHint = UiStyle.label(panel, "Tap one of your pieces", style.TextSize.Small, style.Colors.TextDim, false)
editHint.LayoutOrder = 3
editHint.TextXAlignment = Enum.TextXAlignment.Center
editHint.Visible = false

local actionRow = wrapRow(4)

-- Chip-width action button: sizes to its text, never under MinTap tall.
local function actionButton(text: string, kind: UiStyle.ButtonKind, order: number, twoLine: boolean?): TextButton
	local button = UiStyle.button(actionRow, text, kind, 0, style.MinTap)
	button.LayoutOrder = order
	button.AutomaticSize = Enum.AutomaticSize.X
	button.Size = UDim2.fromOffset(0, style.MinTap)
	button.TextWrapped = false
	if twoLine then
		button.TextSize = style.TextSize.Small
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, style.Tab.PadX)
	pad.PaddingRight = UDim.new(0, style.Tab.PadX)
	pad.Parent = button
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(style.Tab.MinWidth, 0)
	limit.Parent = button
	return button
end

local rotateButton = actionButton("Rotate", "neutral", 1)
local placeButton = actionButton("Place", "primary", 2)
local moveButton = actionButton("Move", "neutral", 4)
local removeButton = actionButton("Remove", "danger", 5)
local upgradeButton = actionButton("Upgrade", "info", 6, true)
local refillButton = actionButton("Refill", "neutral", 7, true)

local toast = UiStyle.toast(gui) -- the shared HUD spot

gui.Parent = player:WaitForChild("PlayerGui")

local function showMessage(text: string, tone: UiStyle.ToastTone?)
	toast.show(text, uiCfg.MessageSeconds, tone)
end

-- The panel is a fixed width so its rows can wrap: as wide as PiecesPerRow
-- tiles, but never wider than the space left of the right-hand button column
-- (Build/Done, Attack, Jump), so it never covers them. Phone landscape (short
-- window) drops the status pills to save height.
local function layoutPanel()
	local screen = gui.AbsoluteSize
	if screen.X <= 0 then
		return -- not laid out yet; the AbsoluteSize signal calls us again
	end
	local wanted = uiCfg.PiecesPerRow * style.Tile.Width + (uiCfg.PiecesPerRow - 1) * style.Gap + 2 * style.Pad
	local narrowest = style.Tile.Width + 2 * style.Pad -- always room for one tile
	local region = math.max(narrowest, screen.X - (BUTTON_SIZE + 2 * BUTTON_MARGIN) - style.Window.EdgePad)
	local width = math.min(wanted, region)
	panel.Size = UDim2.fromOffset(width, 0)
	-- A narrow phone still gets two tiles per row (shrunk to fit) so the six
	-- defenses don't stack into a panel taller than the screen.
	local inner = width - 2 * style.Pad
	local perRow = math.clamp(math.floor((inner + style.Gap) / (style.Tile.Width + style.Gap)), 2, uiCfg.PiecesPerRow)
	local cellWidth = math.min(style.Tile.Width, math.floor((inner - (perRow - 1) * style.Gap) / perRow))
	local grid = pieceGrid:FindFirstChildOfClass("UIGridLayout")
	if grid then
		grid.FillDirectionMaxCells = perRow
		grid.CellSize = UDim2.fromOffset(cellWidth, style.Tile.Height)
	end
	panel.Position = UDim2.new(0, style.Window.EdgePad + (region - width) / 2, 1, -BOTTOM_GAP)
	-- Phone landscape keeps only the budget pill (and Upgrade stays in the action row).
	shortScreen = screen.Y < style.ShortWindowHeight
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

local function unitsOf(store: Types.ResourceStore, resource: string): number
	local sum = 0
	local grades = store[resource]
	if grades then
		for _, count in grades do
			sum += count
		end
	end
	return sum
end

-- Why a piece can't be built right now, or nil. A hint only: the server checks
-- every rule itself when you press Place (R5).
local function blockedReason(pieceKind: string): (string?, boolean)
	local state = baseState
	if not state then
		return nil, false
	end
	local cfg = PlotGrid.pieceConfig(pieceKind) :: any
	if pieceKind == "VaultCore" and state.HasVaultCore then
		return "Built", false
	end
	if (Config.Defenses.Kinds :: any)[pieceKind] and state.DefenseSlotsUsed >= state.DefenseSlots then
		return "No slot", false
	end
	if state.BudgetUsed + cfg.BudgetCost > state.Budget then
		return "Over budget", false
	end
	local vault = vaultState
	if vault then
		for resource, amount in cfg.Cost do
			if unitsOf(vault.Banked, resource) + unitsOf(vault.Exposed, resource) < amount then
				return costText(cfg.Cost), true -- the cost itself, in red
			end
		end
	end
	return nil, false
end

local function refreshPanel()
	layoutPanel()
	panel.Visible = active
	buildButton.Text = if active then "Done" else "Build"
	UiStyle.setButtonKind(buildButton, if active then "neutral" else "primary")
	local placing = mode == "place"
	UiStyle.setActiveTab(modeBar, if placing then "Place" else "Edit")
	tabBar.frame.Visible = placing
	pieceGrid.Visible = placing
	editHint.Visible = not placing and selected == nil
	for pieceKind, tile in pieceTiles do
		local chosen = placing and movingId == nil and pieceKind == kind
		local reason, isCost = blockedReason(pieceKind)
		local cfg = PlotGrid.pieceConfig(pieceKind) :: any
		tile.sub.Text = if reason then reason else costText(cfg.Cost)
		tile.sub.TextColor3 = if reason and isCost then style.Colors.Bad else style.Colors.TextDim
		UiStyle.setTileState(tile, if chosen then "selected" elseif reason then "disabled" else "normal")
		tile.button.Visible = groupOf[pieceKind] == currentGroup
	end
	UiStyle.setActiveTab(tabBar, groupNames[currentGroup])
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
	placeButton.Text = if movingId then "Put here" else "Place"
	rotateButton.Visible = mode == "place"
	placeButton.Visible = mode == "place"
	moveButton.Visible = mode == "select" and selected ~= nil
	removeButton.Visible = mode == "select" and selected ~= nil and selected:GetAttribute("Kind") ~= "VaultCore"

	local state = baseState
	if state then
		tierPill.Text = `Vault tier {state.Tier}/{state.MaxTier}`
		budgetPill.Text = `Budget {state.BudgetUsed}/{state.Budget}`
		defensePill.Text = `Defenses {state.DefenseSlotsUsed}/{state.DefenseSlots}`
		-- Amber when a limit is reached: that's what OverBudget / NoDefenseSlot answer.
		budgetPill.TextColor3 = if state.BudgetUsed >= state.Budget then style.Colors.Warn else style.Colors.Text
		defensePill.TextColor3 = if state.DefenseSlotsUsed >= state.DefenseSlots then style.Colors.Warn else style.Colors.Text
		-- The budget always shows (it is what "Over budget" answers); the tier and the
		-- defense count only where there is room, and the defense count only on the Defenses tab.
		local defenseTab = false
		for _, groupKind in Config.Base.PieceGroups[currentGroup].Kinds do
			if (Config.Defenses.Kinds :: any)[groupKind] then
				defenseTab = true
			end
		end
		tierPill.Visible = not shortScreen
		budgetPill.Visible = true
		defensePill.Visible = defenseTab and not shortScreen
		upgradeButton.Visible = state.UpgradeCost ~= nil
		-- Upgrade sits by the tier info; on a short screen it stays in the action row (room).
		upgradeButton.Parent = if shortScreen then actionRow else infoRow
		upgradeButton.LayoutOrder = if shortScreen then 6 else 4
		if state.UpgradeCost then
			upgradeButton.Text = `Upgrade Vault\n{costText(state.UpgradeCost)}`
		end
	else
		tierPill.Text = "..."
		tierPill.Visible = not shortScreen
		budgetPill.Visible = false
		defensePill.Visible = false
		upgradeButton.Visible = false
	end
end

-- Rotating or resizing re-applies the short-screen layout (pills, Upgrade button), not just the panel size.
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshPanel)

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
		showMessage(REASON_TEXT.Failed, "bad")
		return false
	end
	if not accepted then
		showMessage(REASON_TEXT[reason] or REASON_TEXT.Failed, "warn")
		return false
	end
	return true
end

local function doPlace()
	if not targetX or not targetZ then
		showMessage(REASON_TEXT.OutOfBounds, "warn")
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

for pieceKind, tile in pieceTiles do
	tile.button.Activated:Connect(function()
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

for name, button in modeBar.buttons do
	button.Activated:Connect(function()
		mode = if name == "Edit" then "select" else "place"
		movingId = nil
		select(nil)
	end)
end

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

for index, name in groupNames do
	tabBar.buttons[name].Activated:Connect(function()
		currentGroup = index
		refreshPanel()
	end)
end

refillButton.Activated:Connect(function()
	local model = selected
	local id = model and model:GetAttribute("PieceId")
	if typeof(id) == "string" and ask(refillRemote, id) then
		showMessage("Refilled", "good")
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
		showMessage("Vault upgraded", "good")
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

-- Only on your own plot (a hint: the server checks reach itself).
local function onOwnPlot(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hitbox = myPlotHitbox()
	return root ~= nil and hitbox ~= nil and NodeMath.distanceToHitbox(hitbox, root.Position) <= uiCfg.ShowWithinStuds
end

RunService.RenderStepped:Connect(function()
	local onPlot = onOwnPlot()
	if active and not onPlot then
		setActive(false) -- walked off your plot
	end
	buildButton.Visible = onPlot and player:GetAttribute(uiCfg.VisibleAttribute) == true
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

Remotes.getEvent("VaultChanged").OnClientEvent:Connect(function(state: Types.VaultState)
	vaultState = state
	refreshPanel()
end)
task.spawn(function()
	local ok, result = pcall(function()
		return Remotes.getFunction("GetVaultState"):InvokeServer()
	end)
	if ok and result and not vaultState then
		vaultState = result
		refreshPanel()
	end
end)

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
