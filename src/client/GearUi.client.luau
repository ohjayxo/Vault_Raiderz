--!strict
-- Gear menu (pickaxe upgrades, respec, armor/skin) and the gadget bar (step 5).
-- Armor and skins are picked in the Bag's Gear tab (InventoryUi): the two
-- buttons here never grow with what you own (Josh, 2026-09-23).
-- 02-core-loop.md § Pickaxe upgrade tree, § Gadgets; 05-items.md § Armor.
--
-- Display and intents only: every buy / respec / equip / use is decided by
-- the server, which answers ok or a reason code (R5). Gear score is never
-- sent here (05-items.md § Gear score).
-- The Gear button is hidden until the server shows it (a Player attribute,
-- Config.Combat.Ui.GearVisibleAttribute): the FTUE controls it (R4). The
-- gadget bar only appears when you own a gadget.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))

local player = Players.LocalPlayer
local combatCfg = Config.Combat
local gadgetCfg = Config.Gadgets
local SIZE = combatCfg.Ui.ButtonSize

local buyRemote = Remotes.getFunction("BuyUpgrade")
local respecRemote = Remotes.getFunction("RespecUpgrades")
local gadgetRemote = Remotes.getFunction("UseGadget")

local REASON_TEXT: { [string]: string } = {
	Busy = "Too fast",
	Invalid = "Can't do that",
	Failed = "Something went wrong, try again",
	MaxRank = "Already maxed",
	NoPoints = "No points left: a better pickaxe gives more",
	CantAfford = "Not enough resources",
	NothingToRespec = "Nothing to respec",
	NotFound = "You don't have that any more",
	NoArt = "That skin's model is missing (see Output)",
	Dead = "You're down",
	Carrying = "No gadgets while carrying loot",
	NoDefense = "No defense to disrupt",
	TooManyTraps = "Too many traps out",
	NoneLeft = "None left",
}

type UpgradeConfig = { Id: string, Name: string, Ranks: number, PerRank: number }

local state: Types.GearState? = nil
local busy = false

-- ── Helpers ──────────────────────────────────────────────────────────────

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

local function makeButton(parent: Instance, text: string, width: number, height: number, order: number?): TextButton
	local button = Instance.new("TextButton")
	button.LayoutOrder = order or 0
	button.Size = UDim2.fromOffset(width, height)
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	button.BackgroundTransparency = 0.1
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextWrapped = true
	button.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	button.Parent = parent
	return button
end

local function makeList(parent: Instance, horizontal: boolean, order: number?): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order or 0
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.fromOffset(0, 0)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	frame.Parent = parent
	return frame
end

local function makeLabel(parent: Instance, text: string, width: number, order: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order or 0
	label.Size = UDim2.fromOffset(width, 22)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.Text = text
	label.Parent = parent
	return label
end

-- ── Layout ───────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "GearUi"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10 -- menus draw above HUD (the vault meter was covering this)

local gearButton = makeButton(gui, "Gear", SIZE, SIZE * 0.6)
gearButton.AnchorPoint = Vector2.new(1, 0)
gearButton.Position = UDim2.new(1, -16, 0, 16)
gearButton.Visible = false

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AutomaticSize = Enum.AutomaticSize.XY
panel.Size = UDim2.fromOffset(0, 0)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = gui
local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingLeft = UDim.new(0, 10)
panelPadding.PaddingRight = UDim.new(0, 10)
panelPadding.PaddingTop = UDim.new(0, 8)
panelPadding.PaddingBottom = UDim.new(0, 10)
panelPadding.Parent = panel
local panelLayout = Instance.new("UIListLayout")
panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
panelLayout.Padding = UDim.new(0, 8)
panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
panelLayout.Parent = panel

local header = makeList(panel, true, 1)
local titleLabel = makeLabel(header, "", 380, 1)
local closeButton = makeButton(header, "Close", SIZE, 28, 2)

local COLUMN_WIDTH = SIZE * 2.2
local branches = makeList(panel, true, 2)
local upgradeButtons: { [string]: TextButton } = {}
local upgradeConfigs: { [string]: UpgradeConfig } = {}
for order, branch in combatCfg.PickaxeBranches do
	local column = makeList(branches, false, order)
	makeLabel(column, branch, COLUMN_WIDTH, 0)
	for i, cfg in (combatCfg.Upgrades :: any)[branch] :: { UpgradeConfig } do
		upgradeConfigs[cfg.Id] = cfg
		upgradeButtons[cfg.Id] = makeButton(column, cfg.Name, COLUMN_WIDTH, SIZE * 0.8, i)
	end
end

local respecButton = makeButton(panel, "Respec", SIZE * 4, 34, 3)

-- Worn armor and skin: fixed-size buttons that open the Bag's Gear tab.
local wearRow = makeList(panel, true, 4)
local armorButton = makeButton(wearRow, "Armor", COLUMN_WIDTH * 1.4, 40, 1)
local skinButton = makeButton(wearRow, "Skin", COLUMN_WIDTH * 1.4, 40, 2)

-- Never spill off a small screen: shrink the panel to fit.
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

-- Gadget bar: a column on the right edge, under the Gear button. Buttons
-- only for gadgets you own.
local gadgetBar = makeList(gui, false)
gadgetBar.AnchorPoint = Vector2.new(1, 0)
gadgetBar.Position = UDim2.new(1, -16, 0, 16 + SIZE * 0.6 + 12)
local gadgetButtons: { [string]: TextButton } = {}
for order, gadgetId in gadgetCfg.Order do
	gadgetButtons[gadgetId] = makeButton(gadgetBar, gadgetCfg.Names[gadgetId], SIZE, SIZE * 0.8, order)
end

local message = Instance.new("TextLabel")
message.AnchorPoint = Vector2.new(0.5, 0)
message.Position = UDim2.new(0.5, 0, 0, 70)
message.Size = UDim2.fromOffset(380, 30)
message.BackgroundColor3 = Color3.new(0, 0, 0)
message.BackgroundTransparency = 0.35
message.TextColor3 = Color3.new(1, 1, 1)
message.Font = Enum.Font.GothamBold
message.TextSize = 16
message.Visible = false
message.ZIndex = 5
message.Parent = gui

gui.Parent = player:WaitForChild("PlayerGui")

local messageToken = 0
local function showMessage(text: string)
	messageToken += 1
	local token = messageToken
	message.Text = text
	message.Visible = true
	task.delay(Config.Base.BuildUi.MessageSeconds, function()
		if messageToken == token then
			message.Visible = false
		end
	end)
end

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

-- ── Rendering ────────────────────────────────────────────────────────────

local function tierName(tier: number): string
	return combatCfg.PickaxeTiers[math.clamp(tier, 1, #combatCfg.PickaxeTiers)]
end

local function render()
	local current = state
	if not current then
		titleLabel.Text = "..."
		gadgetBar.Visible = false
		return
	end
	local pointsLeft = current.Points - current.PointsUsed
	titleLabel.Text = `{tierName(current.PickaxeTier)} pickaxe   ·   Points {pointsLeft} / {current.Points}`

	for upgradeId, button in upgradeButtons do
		local cfg = upgradeConfigs[upgradeId]
		local rank = current.Ranks[upgradeId] or 0
		local nextCost = combatCfg.NodeCostByRank[rank + 1]
		local costLine = if rank >= cfg.Ranks then "MAX" else costText(nextCost)
		button.Text = `{cfg.Name}  {rank}/{cfg.Ranks}\n{costLine}`
		button.BackgroundColor3 = if rank >= cfg.Ranks
			then Color3.fromRGB(40, 110, 70)
			elseif pointsLeft <= 0 then Color3.fromRGB(35, 35, 40)
			else Color3.fromRGB(45, 45, 60)
	end
	respecButton.Text = `Respec (all points back): {costText(combatCfg.RespecCost)}`
	respecButton.Visible = current.PointsUsed > 0

	local wornName = "none"
	local spares = 0
	for _, piece in current.ArmorPieces do
		if piece.Id == current.ArmorEquipped then
			wornName = `{tierName(piece.Tier)} {piece.Slot:lower()}`
		else
			spares += 1
		end
	end
	armorButton.Text = `Armor: {wornName}{if spares > 0 then ` (+{spares} spare)` else ""}  >`
	local skinCfgs: { [string]: { Name: string } } = Config.Cosmetics.PickaxeSkins :: any
	local skinCfg = skinCfgs[current.EquippedSkin]
	skinButton.Text = `Skin: {if current.EquippedSkin == "" then Config.Cosmetics.DefaultSkinName elseif skinCfg then skinCfg.Name else current.EquippedSkin}  >`

	local anyGadget = false
	for gadgetId, button in gadgetButtons do
		local count = current.Gadgets[gadgetId] or 0
		button.Visible = count > 0
		button.Text = `{gadgetCfg.Names[gadgetId]}\nx{count}`
		anyGadget = anyGadget or count > 0
	end
	gadgetBar.Visible = anyGadget
end

-- ── Input ────────────────────────────────────────────────────────────────

gearButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)
-- Armor / skin: open the Bag on its Gear tab (above this menu).
local function openBagGear()
	local bag = player.PlayerGui:FindFirstChild("InventoryUi")
	local open = bag and bag:FindFirstChild("Open")
	if open and open:IsA("BindableEvent") then
		open:Fire("Gear")
	end
end
armorButton.Activated:Connect(openBagGear)
skinButton.Activated:Connect(openBagGear)
-- Shrink the menu to fit the screen when it opens or the screen changes.
-- Early on Roblox can report a tiny viewport: ignore that, and never go
-- below MinScale (a bad reading must never hide the menu).
local function fitPanel()
	local camera = Workspace.CurrentCamera
	if not camera or not panel.Visible then
		return
	end
	local view = camera.ViewportSize
	local size = panel.AbsoluteSize / panelScale.Scale -- unscaled
	if view.X < 200 or view.Y < 200 or size.X <= 0 or size.Y <= 0 then
		return
	end
	panelScale.Scale = math.clamp(math.min((view.X - 24) / size.X, (view.Y - 24) / size.Y), combatCfg.Ui.GearMinScale, 1)
end
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	task.defer(fitPanel) -- after the layout has sized it
end)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(fitPanel)
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanel)
end
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
for upgradeId, button in upgradeButtons do
	button.Activated:Connect(function()
		ask(buyRemote, upgradeId)
	end)
end
respecButton.Activated:Connect(function()
	if ask(respecRemote) then
		showMessage("All points returned")
	end
end)
for gadgetId, button in gadgetButtons do
	button.Activated:Connect(function()
		ask(gadgetRemote, gadgetId)
	end)
end
-- PC: number keys 1-4 use gadgets in bar order.
local GADGET_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local index = table.find(GADGET_KEYS, input.KeyCode)
	local gadgetId = index and gadgetCfg.Order[index]
	if gadgetId then
		ask(gadgetRemote, gadgetId)
	end
end)

-- ── Visibility + state from the server ───────────────────────────────────

local function applyVisibility()
	local visible = player:GetAttribute(combatCfg.Ui.GearVisibleAttribute) == true
	gearButton.Visible = visible
	if not visible then
		panel.Visible = false
	end
end
player:GetAttributeChangedSignal(combatCfg.Ui.GearVisibleAttribute):Connect(applyVisibility)
applyVisibility()

local received = false
Remotes.getEvent("GearChanged").OnClientEvent:Connect(function(newState: Types.GearState)
	received = true
	state = newState
	render()
end)

render()
local getGearState = Remotes.getFunction("GetGearState")
for _ = 1, Config.Bank.HudStartupTries do
	if received then
		break
	end
	local ok, result = pcall(getGearState.InvokeServer, getGearState)
	if ok and result and not received then
		received = true
		state = result
		render()
		break
	end
	task.wait(Config.Bank.HudStartupRetrySeconds)
end
