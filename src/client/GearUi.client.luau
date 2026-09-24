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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))
local UiStyle = require(Shared:WaitForChild("UiStyle"))

local player = Players.LocalPlayer
local combatCfg = Config.Combat
local gadgetCfg = Config.Gadgets
local style = Config.UiStyle
local colors = style.Colors
local SIZE = combatCfg.Ui.ButtonSize

-- [PH] invented look-only: widths of the Gear menu (its height comes from its
-- content). Two columns of GEAR_COLUMN_WIDTH when the window is wide, one
-- GEAR_NARROW_CONTENT column on a phone in portrait.
local GEAR_COLUMN_WIDTH = 240
local GEAR_NARROW_CONTENT = 300
-- [PH] invented look-only: the ">" on the Armor / Skin rows, and the message's
-- distance from the top (it sat at 70 before, clear of the vault meter).
local ARROW_WIDTH = 16
local MESSAGE_TOP = 70
local GEAR_SCREEN_MARGIN = 12 -- [PH] invented look-only: air kept above and below the open menu
local HUD_MARGIN = 16 -- gap between the Gear button / gadget bar and the screen edge

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
type UpgradeRow = { row: UiStyle.ItemRow, rank: TextLabel }

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

-- A tappable Armor / Skin row: name, what's worn under it, ">" on the right.
local function wearRow(parent: Instance, name: string, order: number): (UiStyle.ItemRow, TextButton)
	local row = UiStyle.itemRow(parent, name, "", order, true)
	local arrow = UiStyle.label(row.trailing, ">", style.TextSize.Title, colors.TextDim, true)
	arrow.AutomaticSize = Enum.AutomaticSize.None
	arrow.Size = UDim2.new(0, ARROW_WIDTH, 1, 0)
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	return row, row.root :: TextButton
end

-- ── Layout ───────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "GearUi"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10 -- menus draw above HUD (the vault meter was covering this)

-- Invisible full-screen frame, only so UiStyle.isWide / isShort can read the
-- window size. It takes no input.
local screen = Instance.new("Frame")
screen.Name = "Screen"
screen.Size = UDim2.fromScale(1, 1)
screen.BackgroundTransparency = 1
screen.BorderSizePixel = 0
screen.Active = false
screen.Selectable = false
screen.Parent = gui

local gearButton = UiStyle.hudButton(gui, "Gear", "neutral", SIZE, SIZE * 0.6)
gearButton.AnchorPoint = Vector2.new(1, 0)
gearButton.Position = UDim2.new(1, -HUD_MARGIN, 0, HUD_MARGIN)
gearButton.Visible = false

local panel = UiStyle.dockPanel(gui)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AutomaticSize = Enum.AutomaticSize.Y -- fixed width (set by applyLayout), height follows the content

-- Header: pickaxe name, Points pill, close.
local header = UiStyle.row(panel, style.MinTap, 1)
local titleLabel = UiStyle.title(header, "")
titleLabel.LayoutOrder = 1
titleLabel.AutomaticSize = Enum.AutomaticSize.None
titleLabel.Size = UDim2.fromScale(0, 1)
titleLabel.TextWrapped = false
titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
local titleFlex = Instance.new("UIFlexItem")
titleFlex.FlexMode = Enum.UIFlexMode.Fill
titleFlex.Parent = titleLabel
local pointsPill = UiStyle.pill(header, "", colors.Accent)
pointsPill.LayoutOrder = 2
pointsPill.Visible = false
local closeButton = UiStyle.button(header, "X", "neutral", style.MinTap, style.MinTap)
closeButton.LayoutOrder = 3

local headerDivider = UiStyle.divider(panel, 2)

-- Everything under the header scrolls, so a short screen gets a shorter body
-- instead of a shrunken (tiny-tap-target) menu. fitPanel sets its height.
local body = UiStyle.scroller(panel, UDim2.new(), UDim2.new(1, 0, 0, 0))
body.LayoutOrder = 3

-- The three upgrade branches split over two columns (one column when narrow);
-- the worn Armor / Skin rows fill the right column under the last branch.
local cols = UiStyle.columns(body, 1)
local upgradeButtons: { [string]: TextButton } = {}
local upgradeConfigs: { [string]: UpgradeConfig } = {}
local upgradeRows: { [string]: UpgradeRow } = {}
local leftBranches = math.ceil(#combatCfg.PickaxeBranches / 2)
for index, branch in combatCfg.PickaxeBranches do
	local side = if index <= leftBranches then cols.left else cols.right
	local base = index * 100
	UiStyle.sectionHeader(side, branch, base)
	for i, cfg in (combatCfg.Upgrades :: any)[branch] :: { UpgradeConfig } do
		upgradeConfigs[cfg.Id] = cfg
		local row = UiStyle.itemRow(side, cfg.Name, "", base + i, true)
		local rank = UiStyle.pill(row.trailing, "", colors.Text)
		upgradeRows[cfg.Id] = { row = row, rank = rank }
		upgradeButtons[cfg.Id] = row.root :: TextButton
	end
end

local WORN_ORDER = 1000
local wornHeader = UiStyle.sectionHeader(cols.right, "Worn", WORN_ORDER)
local armorRow, armorButton = wearRow(cols.right, "Armor", WORN_ORDER + 1)
local skinRow, skinButton = wearRow(cols.right, "Skin", WORN_ORDER + 2)

local respecButton = UiStyle.button(body, "Respec", "neutral", 0, style.MinTap)
respecButton.LayoutOrder = 2
respecButton.Size = UDim2.new(1, 0, 0, style.MinTap)
respecButton.TextWrapped = true

-- Gadget bar: a column on the right edge, under the Gear button. Buttons
-- only for gadgets you own.
local gadgetBar = Instance.new("Frame")
gadgetBar.AnchorPoint = Vector2.new(1, 0)
gadgetBar.Position = UDim2.new(1, -HUD_MARGIN, 0, HUD_MARGIN + math.max(SIZE * 0.6, style.MinTap) + style.Gap)
gadgetBar.AutomaticSize = Enum.AutomaticSize.XY
gadgetBar.Size = UDim2.fromOffset(0, 0)
gadgetBar.BackgroundTransparency = 1
gadgetBar.Parent = gui
UiStyle.list(gadgetBar, false, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
local gadgetButtons: { [string]: TextButton } = {}
for order, gadgetId in gadgetCfg.Order do
	local button = UiStyle.hudButton(gadgetBar, gadgetCfg.Names[gadgetId], "chip", SIZE, SIZE * 0.8)
	button.LayoutOrder = order
	button.TextSize = style.TextSize.Small -- two-word names wrap inside a 72px button
	gadgetButtons[gadgetId] = button
end

local toast = UiStyle.toast(gui)
toast.frame.Position = UDim2.new(0.5, 0, 0, MESSAGE_TOP)

gui.Parent = player:WaitForChild("PlayerGui")

local function showMessage(text: string, tone: UiStyle.ToastTone?)
	toast.show(text, Config.Base.BuildUi.MessageSeconds, tone)
end

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

-- ── Rendering ────────────────────────────────────────────────────────────

local function tierName(tier: number): string
	return combatCfg.PickaxeTiers[math.clamp(tier, 1, #combatCfg.PickaxeTiers)]
end

local function render()
	local current = state
	if not current then
		titleLabel.Text = "..."
		pointsPill.Visible = false
		gadgetBar.Visible = false
		return
	end
	local pointsLeft = current.Points - current.PointsUsed
	titleLabel.Text = `{tierName(current.PickaxeTier)} pickaxe`
	pointsPill.Text = `Points {pointsLeft} / {current.Points}`
	pointsPill.Visible = true

	for upgradeId, entry in upgradeRows do
		local cfg = upgradeConfigs[upgradeId]
		local rank = current.Ranks[upgradeId] or 0
		local nextCost = combatCfg.NodeCostByRank[rank + 1]
		local maxed = rank >= cfg.Ranks
		entry.row.title.Text = cfg.Name
		entry.row.detail.Text = if maxed then "MAX" else costText(nextCost)
		entry.row.detail.Visible = true
		entry.rank.Text = `{rank}/{cfg.Ranks}`
		-- Maxed = green card, no points left = sunken and dim, otherwise a normal card.
		local locked = not maxed and pointsLeft <= 0
		entry.row.root.BackgroundColor3 = if maxed then colors.ButtonPrimary elseif locked then colors.BarTrack else colors.Card
		entry.row.title.TextColor3 = if locked then colors.TextDim else colors.Text
		entry.row.detail.TextColor3 = if maxed then colors.Text else colors.TextDim
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
	armorRow.detail.Text = `{wornName}{if spares > 0 then ` (+{spares} spare)` else ""}`
	armorRow.detail.Visible = true
	local skinCfgs: { [string]: { Name: string } } = Config.Cosmetics.PickaxeSkins :: any
	local skinCfg = skinCfgs[current.EquippedSkin]
	skinRow.detail.Text = if current.EquippedSkin == "" then Config.Cosmetics.DefaultSkinName elseif skinCfg then skinCfg.Name else current.EquippedSkin
	skinRow.detail.Visible = true

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
-- Armor opens the Bag's Gear tab, Skin its Skins tab (above this menu).
local function openBag(tab: string)
	local bag = player.PlayerGui:FindFirstChild("InventoryUi")
	local open = bag and bag:FindFirstChild("Open")
	if open and open:IsA("BindableEvent") then
		open:Fire(tab)
	end
end
armorButton.Activated:Connect(function()
	openBag("Gear")
end)
skinButton.Activated:Connect(function()
	openBag("Skins")
end)
-- Cap the body height to what is left of the screen under the header. Early on
-- Roblox can report a tiny viewport: ignore that reading.
local function fitPanel()
	local view = screen.AbsoluteSize
	if view.Y < 200 then
		return
	end
	local chrome = header.AbsoluteSize.Y + 2 * style.Pad + 2 * style.Gap + 2 * GEAR_SCREEN_MARGIN
	local room = math.max(view.Y - chrome, style.MinTap * 2)
	body.Size = UDim2.new(1, 0, 0, math.min(body.AbsoluteCanvasSize.Y, room))
end

-- Two columns on a wide window, one on a phone in portrait. A short window
-- (phone landscape) drops the extra headings and divider so the menu stays low.
local function applyLayout()
	local wide = UiStyle.isWide(screen)
	local short = UiStyle.isShort(screen)
	UiStyle.setColumns(cols, wide)
	local content = if wide then 2 * GEAR_COLUMN_WIDTH + style.Gap else GEAR_NARROW_CONTENT
	panel.Size = UDim2.fromOffset(content + 2 * style.Pad, 0)
	wornHeader.Visible = not short
	headerDivider.Visible = not short
	task.defer(fitPanel) -- after the layout has re-sized it
end
screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
applyLayout()
body:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(fitPanel)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	task.defer(fitPanel)
end)
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
		showMessage("All points returned", "good")
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
