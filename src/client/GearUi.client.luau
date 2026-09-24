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

-- [PH] invented look-only: the Gear window's largest size (a phone gets 90% of the screen instead),
-- the ">" on the Armor / Skin rows, and the width of the upgrade buy button.
local GEAR_MAX_SIZE = Vector2.new(480, 440)
local ARROW_WIDTH = 16
local BUY_WIDTH = 104
local HUD_MARGIN = 16 -- gap between the gadget bar and the screen edge

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

type UpgradeConfig = { Id: string, Name: string, Ranks: number, PerRank: number, Desc: string }
type UpgradeRow = { row: UiStyle.ItemRow, rank: TextLabel, buy: TextButton }

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

-- ── Layout ──────────────────────────────────────────────────────────────

local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "GearUi"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10 -- menus draw above HUD (the vault meter was covering this)

-- Invisible full-screen frame, only so UiStyle.isShort can read the window
-- size. It takes no input.
local screen = Instance.new("Frame")
screen.Name = "Screen"
screen.Size = UDim2.fromScale(1, 1)
screen.BackgroundTransparency = 1
screen.BorderSizePixel = 0
screen.Active = false
screen.Selectable = false
screen.Parent = gui

-- One slot in the shared dock (Raids / Bag / Trade / Gear).
local gearButton = UiStyle.dockButton(playerGui, "Gear", "neutral", style.Dock.Order.Gear)
gearButton.Visible = false

-- The shared window frame: pickaxe name, Points pill, red X, scrolling body.
local win = UiStyle.window(gui, "", 0.9, 0.9, GEAR_MAX_SIZE)
local panel = win.panel
local titleLabel = win.title
local pointsPill = UiStyle.pill(win.header, "", colors.Accent)
pointsPill.LayoutOrder = 2
pointsPill.Visible = false
local closeButton = win.close
local body = win.content

-- One column: each upgrade is a row with what it does, its rank, and ONE
-- button that says what tapping it costs (or "MAX" / "No points").
local upgradeButtons: { [string]: TextButton } = {}
local upgradeConfigs: { [string]: UpgradeConfig } = {}
local upgradeRows: { [string]: UpgradeRow } = {}
local branchHeaders: { [string]: TextLabel } = {}
local branchUpgrades: { [string]: { UpgradeConfig } } = {}
for index, branch in combatCfg.PickaxeBranches do
	local base = index * 100
	branchHeaders[branch] = UiStyle.sectionHeader(body, branch, base)
	local list = (combatCfg.Upgrades :: any)[branch] :: { UpgradeConfig }
	branchUpgrades[branch] = list
	for i, cfg in list do
		upgradeConfigs[cfg.Id] = cfg
		local row = UiStyle.itemRow(body, cfg.Name, cfg.Desc, base + i, false)
		local rank = UiStyle.pill(row.trailing, "", colors.Text)
		rank.LayoutOrder = 1
		local buy = UiStyle.button(row.trailing, "", "primary", BUY_WIDTH, style.MinTap)
		buy.LayoutOrder = 2
		buy.TextSize = style.TextSize.Small
		buy.TextWrapped = true
		upgradeRows[cfg.Id] = { row = row, rank = rank, buy = buy }
		upgradeButtons[cfg.Id] = buy
	end
end

local WORN_ORDER = 1000
local wornHeader = UiStyle.sectionHeader(body, "Worn", WORN_ORDER)
local armorRow, armorButton = wearRow(body, "Armor", WORN_ORDER + 1)
local skinRow, skinButton = wearRow(body, "Skin", WORN_ORDER + 2)

local respecButton = UiStyle.button(body, "Respec", "neutral", 0, style.MinTap)
respecButton.LayoutOrder = 2000
respecButton.Size = UDim2.new(1, 0, 0, style.MinTap)
respecButton.TextWrapped = true

-- Gadget bar: a column on the right edge. Buttons only for gadgets you own.
local gadgetBar = Instance.new("Frame")
gadgetBar.AnchorPoint = Vector2.new(1, 0)
gadgetBar.Position = UDim2.new(1, -HUD_MARGIN, 0, HUD_MARGIN)
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

-- Messages: at the bottom of the window while it is open, else the HUD spot
-- (gadget use works with the menu closed).
local windowToast = UiStyle.toast(panel, true)
local hudToast = UiStyle.toast(gui)

gui.Parent = playerGui

local function showMessage(text: string, tone: UiStyle.ToastTone?)
	local toast = if panel.Visible then windowToast else hudToast
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
		local locked = not maxed and pointsLeft <= 0
		entry.row.title.Text = cfg.Name
		entry.rank.Text = `{rank}/{cfg.Ranks}`
		entry.rank.TextColor3 = if maxed then colors.Good else colors.Text
		-- The state is on the button: what it costs, "No points", or "MAX". Green
		-- is only for a button that would do something.
		entry.buy.Text = if maxed then "MAX" elseif locked then "No points" else costText(nextCost)
		UiStyle.setButtonKind(entry.buy, if maxed or locked then "disabled" else "primary")
	end
	for branch, header in branchHeaders do
		local got, total = 0, 0
		for _, cfg in branchUpgrades[branch] do
			got += current.Ranks[cfg.Id] or 0
			total += cfg.Ranks
		end
		UiStyle.setSectionSummary(header, `{got}/{total} ranks`)
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
-- A short window (phone landscape) drops the "Worn" heading so the menu stays low.
local function applyLayout()
	wornHeader.Visible = not UiStyle.isShort(screen)
end
screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
applyLayout()
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
