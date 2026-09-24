--!strict
-- The Bag (Josh, 2026-09-23): everything you own in one panel, split into
-- SAFE (banked / worn) and AT RISK (exposed / spare armor), with tabs
-- Resources | Gear | Items. 02-core-loop.md § Bank vs Exposed; 05-items.md
-- § Armor (D112).
--
-- Display and intents only: every number comes from the server (VaultChanged
-- / GearChanged, R5); Wear / Take off / Equip use the same remotes as the
-- Gear menu, which the server validates.
-- Shown with the vault meter (Config.Bank.Meter.VisibleAttribute): the FTUE
-- controls it (R4). The Gear tab follows the Gear button's attribute; the
-- Items tab only shows once you own an item.
-- Step 8: the Resources tab shows your raid shields with a countdown (Josh's
-- call: in the Bag, not on the HUD, so the FTUE's no-text rule holds), and
-- the Items tab has a Craft row for Breach Charges (shown once you have
-- Riftsalt or charges). The server owns the recipe; this only asks (R5).
-- Studio only: a Debug tab with every debug key (Shared/DebugKeyList) and a
-- Run button for each, plus small X buttons that delete items / armor.
-- Other scripts open it with the "Open" BindableEvent inside this ScreenGui
-- (argument: tab name): the vault meter and the Gear menu's Armor/Skin rows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))
local DebugKeyList = require(Shared:WaitForChild("DebugKeyList"))

local player = Players.LocalPlayer
local bagCfg = Config.Inventory
local meterCfg = Config.Bank.Meter
local combatCfg = Config.Combat
local SIZE = combatCfg.Ui.ButtonSize
local SAFE = meterCfg.BankedColor
local RISK = meterCfg.ExposedColor
local SHIELD = bagCfg.ShieldColor
local NOTE = Color3.fromRGB(170, 170, 190)

local equipRemote = Remotes.getFunction("EquipArmor")
-- Studio only (Josh's test request): a small X on item and armor rows that
-- deletes them. The server re-checks IsStudio (DebugService).
local STUDIO_DELETE = RunService:IsStudio()
local debugEvent = Remotes.getEvent("DebugCommand")
local skinRemote = Remotes.getFunction("EquipSkin")

local REASON_TEXT: { [string]: string } = {
	Busy = "Too fast",
	Invalid = "Can't do that",
	Failed = "Something went wrong, try again",
	NotFound = "You don't have that any more",
	NoArt = "That skin's model is missing (see Output)",
	CantAfford = "Not enough Riftsalt",
}

type Tab = "Resources" | "Gear" | "Items" | "Debug"
local TABS: { Tab } = { "Resources", "Gear", "Items", "Debug" }

local vault: Types.VaultState? = nil
local gear: Types.GearState? = nil
local shields: Types.ShieldState? = nil
local credits: number? = nil -- step 9: Credits (CreditsChanged)
local reputation: Types.ReputationState? = nil -- step 9: Level + tracks (ReputationChanged)
local shieldsAt = 0 -- os.clock() when `shields` arrived (it counts down from there)
local shieldLabel: TextLabel? = nil -- the Resources tab's shield row, ticked every second
local currentTab: Tab = "Resources"
local openResource: string? = nil -- the resource whose Grades are showing
local busy = false

-- ── UI (greybox) ─────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "InventoryUi"
gui.ResetOnSpawn = false
gui.DisplayOrder = bagCfg.DisplayOrder
local openEvent = Instance.new("BindableEvent")
openEvent.Name = "Open"
openEvent.Parent = gui

local function makeButton(parent: Instance, text: string, width: number, height: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, height)
	b.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	b.BackgroundTransparency = 0.1
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	b.Parent = parent
	return b
end

-- Next to the Raids button (RaidUi: 12, 170, SIZE*1.2 x SIZE*0.5). Its own
-- HUD-level ScreenGui, so open menus (Gear) draw over it; the open Bag
-- itself is above them (bagCfg.DisplayOrder).
local buttonGui = Instance.new("ScreenGui")
buttonGui.Name = "InventoryButton"
buttonGui.ResetOnSpawn = false
buttonGui.DisplayOrder = bagCfg.ButtonDisplayOrder
local bagButton = makeButton(buttonGui, bagCfg.ButtonLabel, SIZE * 1.2, SIZE * 0.5)
bagButton.Position = UDim2.fromOffset(12 + SIZE * 1.2 + 8, 170)
bagButton.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
bagButton.Visible = false

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.9, 0.9)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = bagCfg.PanelMaxSize
limit.Parent = panel
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

-- Header: tabs on the left, close on the right.
local header = Instance.new("Frame")
header.Size = UDim2.new(1, -16, 0, 34)
header.Position = UDim2.fromOffset(8, 8)
header.BackgroundTransparency = 1
header.Parent = panel
local headerLayout = Instance.new("UIListLayout")
headerLayout.FillDirection = Enum.FillDirection.Horizontal
headerLayout.Padding = UDim.new(0, 6)
headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
headerLayout.Parent = header
local tabButtons: { [string]: TextButton } = {}
for order, tab in TABS do
	local b = makeButton(header, tab, 110, 34)
	b.LayoutOrder = order
	tabButtons[tab] = b
end
local closeButton = makeButton(panel, "X", 34, 34)
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -8, 0, 8)

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.fromOffset(8, 50)
content.Size = UDim2.new(1, -16, 1, -58)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 6
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new()
content.Parent = panel
local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 4)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

local message = Instance.new("TextLabel")
message.AnchorPoint = Vector2.new(0.5, 1)
message.Position = UDim2.new(0.5, 0, 1, -8)
message.Size = UDim2.fromOffset(340, 28)
message.BackgroundColor3 = Color3.new(0, 0, 0)
message.BackgroundTransparency = 0.2
message.TextColor3 = Color3.new(1, 1, 1)
message.Font = Enum.Font.GothamBold
message.TextSize = 14
message.Visible = false
message.ZIndex = 5
message.Parent = panel

gui.Parent = player:WaitForChild("PlayerGui")
buttonGui.Parent = player:WaitForChild("PlayerGui")

-- ── Row builders ─────────────────────────────────────────────────────────

local rowCount = 0

-- One row: text cells of given widths, an optional button at the end, and
-- optionally the whole row tappable (onTap).
local function row(cells: { { text: string, width: number, color: Color3? } }, action: string?, onAction: (() -> ())?, indent: number?, onTap: (() -> ())?, onDelete: (() -> ())?): GuiObject
	rowCount += 1
	local frame: GuiObject
	if onTap then
		local tappable = Instance.new("TextButton")
		tappable.Text = ""
		tappable.AutoButtonColor = false
		tappable.Activated:Connect(onTap)
		frame = tappable
	else
		frame = Instance.new("Frame")
	end
	frame.LayoutOrder = rowCount
	frame.Size = UDim2.new(1, -8, 0, bagCfg.RowHeight)
	frame.BackgroundTransparency = 1
	frame.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	if indent then
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, indent)
		pad.Parent = frame
	end
	for i, cell in cells do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = i
		label.Size = UDim2.fromOffset(cell.width, bagCfg.RowHeight)
		label.BackgroundTransparency = 1
		label.TextColor3 = cell.color or Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = cell.text
		label.Parent = frame
	end
	if action and onAction then
		local b = makeButton(frame, action, 100, bagCfg.RowHeight - 4)
		b.LayoutOrder = #cells + 1
		b.Activated:Connect(onAction)
	end
	if onDelete and STUDIO_DELETE then
		local x = makeButton(frame, "X", bagCfg.RowHeight - 6, bagCfg.RowHeight - 6)
		x.LayoutOrder = #cells + 2
		x.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
		x.TextSize = 12
		x.Activated:Connect(onDelete)
	end
	return frame
end

local function heading(text: string)
	row({ { text = text, width = 400, color = Color3.fromRGB(170, 170, 190) } })
end

local function clearRows()
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	rowCount = 0
end

-- 12345 -> "12,345"
local function withCommas(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function total(grades: Types.GradeCounts?): number
	local sum = 0
	for _, count in grades or ({} :: Types.GradeCounts) do
		sum += count
	end
	return sum
end

-- "Standard 90 · Dense 8" (only Grades you have, best last like the docs).
local function gradeText(grades: Types.GradeCounts?): string
	local parts = {}
	for _, grade in Config.Grade.Names do
		local count = (grades or ({} :: Types.GradeCounts))[grade] or 0
		if count > 0 then
			table.insert(parts, `{grade} {withCommas(count)}`)
		end
	end
	return if #parts > 0 then table.concat(parts, " · ") else "none"
end

local function tierName(tier: number): string
	return combatCfg.PickaxeTiers[math.clamp(tier, 1, #combatCfg.PickaxeTiers)]
end

local function itemCount(itemId: string): number
	return if gear and gear.Items then gear.Items[itemId] or 0 else 0
end

local function anyItem(): boolean
	for _, itemId in bagCfg.ItemOrder do
		if itemCount(itemId) > 0 then
			return true
		end
	end
	return false
end

-- Riftsalt you hold (safe + at risk): crafting shows up once you have some.
local function riftsaltHeld(): number
	if not vault then
		return 0
	end
	return total(vault.Banked.Riftsalt) + total(vault.Exposed.Riftsalt)
end

-- "Shield 47h 12m" / "Shield 29m 05s", or nil when no shield is up.
local function shieldText(): string?
	local s = shields
	if not s then
		return nil
	end
	local elapsed = os.clock() - shieldsAt
	local newAccount = math.max(0, s.NewAccountSeconds - elapsed)
	local postRaid = math.max(0, s.PostRaidSeconds - elapsed)
	local left = math.floor(math.max(newAccount, postRaid))
	if left <= 0 then
		return nil
	end
	local why = if newAccount >= postRaid then "new player" else "after a raid"
	local time = if left >= 3600
		then string.format("%dh %02dm", left // 3600, (left % 3600) // 60)
		else string.format("%dm %02ds", left // 60, left % 60)
	return `SHIELD {time} ({why}): nobody can raid you`
end

-- ── Messages + intents ───────────────────────────────────────────────────

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

local function ask(remote: RemoteFunction, ...: any)
	if busy then
		return
	end
	busy = true
	local ok, accepted, reason = pcall(remote.InvokeServer, remote, ...)
	busy = false
	if not ok then
		showMessage(REASON_TEXT.Failed)
	elseif not accepted then
		showMessage(REASON_TEXT[reason] or REASON_TEXT.Failed)
	end
end

-- ── Tabs ─────────────────────────────────────────────────────────────────

local render: () -> ()

local function renderResources()
	local v = vault
	if not v then
		heading("Loading...")
		return
	end
	-- Step 9: Credits and Level (06 § Currencies; 03 § Level). Shown while
	-- Config.Inventory.ShowCredits is on; the FTUE turns it off (step 14).
	if bagCfg.ShowCredits then
		local rep = reputation
		row({
			{ text = `Credits {withCommas(credits or 0)}`, width = 200, color = Color3.fromRGB(255, 220, 120) },
			{ text = if rep then `Level {rep.Level}` else "Level ...", width = 150 },
		})
		if rep then
			local cells = {}
			for _, track in Config.Progression.Tracks do
				local t = rep.Tracks[track]
				table.insert(cells, { text = `{track} {t.Level}  ({withCommas(t.XP - t.Prev)}/{withCommas(t.Next - t.Prev)})`, width = 190, color = NOTE })
			end
			row(cells)
			if not rep.TradeUnlocked then
				row({ { text = `Trading unlocks at Level {Config.Progression.TradeUnlockLevel}.`, width = 560, color = NOTE } })
			end
		end
	end
	-- Your raid shields first (01 R6; D67, D75).
	local shieldNow = shieldText()
	shieldLabel = nil
	if shieldNow then
		local shieldRow = row({ { text = shieldNow, width = 560, color = SHIELD } })
		shieldLabel = shieldRow:FindFirstChildOfClass("TextLabel")
		row({ { text = "Breaching someone's base ends your shield.", width = 560, color = NOTE } }, nil, nil, 20)
	end
	row({
		{ text = "", width = 150 },
		{ text = "SAFE (banked)", width = 150, color = SAFE },
		{ text = "AT RISK (exposed)", width = 150, color = RISK },
	})
	for _, resource in Config.Resources.Types do
		local banked, exposed = total(v.Banked[resource]), total(v.Exposed[resource])
		if banked > 0 or exposed > 0 or resource == Config.Resources.Types[1] then
			local open = openResource == resource
			-- Tap a resource to see its Grades (depth only when asked: R4).
			row({
				{ text = (if open then "v " else "> ") .. resource, width = 150 },
				{ text = withCommas(banked), width = 150, color = SAFE },
				{ text = withCommas(exposed), width = 150, color = RISK },
			}, nil, nil, nil, function()
				openResource = if open then nil else resource
				render()
			end)
			if open then
				row({ { text = "safe:    " .. gradeText(v.Banked[resource]), width = 560, color = SAFE } }, nil, nil, 20)
				row({ { text = "at risk: " .. gradeText(v.Exposed[resource]), width = 560, color = RISK } }, nil, nil, 20)
			end
		end
	end
	row({
		{ text = "Scrap", width = 150 },
		{ text = `{withCommas(v.ScrapBanked)} / {withCommas(v.ScrapCapacity)}`, width = 150, color = SAFE },
		{ text = withCommas(v.ScrapExposed), width = 150, color = RISK },
	})
	local bankedTotal = 0
	for _, grades in v.Banked do
		bankedTotal += total(grades)
	end
	row({ { text = `Vault {withCommas(bankedTotal)} / {withCommas(v.Capacity)}`, width = 400, color = SAFE } })
	row({ { text = "At-risk items can be stolen in raids. Bank them at your Vault Core.", width = 560, color = Color3.fromRGB(170, 170, 190) } })
end

local function renderGear()
	local g = gear
	if not g then
		heading("Loading...")
		return
	end
	local skinCfgs: { [string]: { Name: string } } = Config.Cosmetics.PickaxeSkins :: any
	local skinName = if g.EquippedSkin == "" then Config.Cosmetics.DefaultSkinName else (skinCfgs[g.EquippedSkin] and skinCfgs[g.EquippedSkin].Name or g.EquippedSkin)
	row({ { text = `Pickaxe: {tierName(g.PickaxeTier)}   ·   Skin: {skinName}`, width = 500 } })

	heading("ARMOR")
	if #g.ArmorPieces == 0 then
		row({ { text = "none", width = 300, color = Color3.fromRGB(170, 170, 190) } })
	end
	-- The worn piece, then spares grouped by tier + slot ("Wooden chest x3").
	-- Same-tier pieces are identical (D112), so Wear sends the first one.
	type Group = { tier: number, slot: string, ids: { string } }
	local groups: { Group } = {}
	for _, piece in g.ArmorPieces do
		if piece.Id == g.ArmorEquipped then
			row({
				{ text = `{tierName(piece.Tier)} {piece.Slot:lower()}`, width = 170 },
				{ text = "worn · safe", width = 200, color = SAFE },
			}, "Take off", function()
				ask(equipRemote, "")
			end, nil, nil, function()
				debugEvent:FireServer("DeleteArmor", piece.Id)
			end)
		else
			local found: Group? = nil
			for _, group in groups do
				if group.tier == piece.Tier and group.slot == piece.Slot then
					found = group
				end
			end
			if found then
				table.insert(found.ids, piece.Id)
			else
				table.insert(groups, { tier = piece.Tier, slot = piece.Slot, ids = { piece.Id } })
			end
		end
	end
	for _, group in groups do
		local count = #group.ids
		row({
			{ text = `{tierName(group.tier)} {group.slot:lower()}{if count > 1 then ` x{count}` else ""}`, width = 170 },
			{ text = "spare · can be stolen", width = 200, color = RISK },
		}, "Wear", function()
			ask(equipRemote, group.ids[1])
		end, nil, nil, function()
			debugEvent:FireServer("DeleteArmor", group.ids[1])
		end)
	end

	heading("SKINS")
	local function skinRow(skinId: string, label: string)
		local equipped = g.EquippedSkin == skinId
		row({
			{ text = label, width = 170 },
			{ text = if equipped then "equipped" else "", width = 200, color = SAFE },
		}, if equipped then nil else "Equip", function()
			ask(skinRemote, skinId)
		end)
	end
	skinRow("", Config.Cosmetics.DefaultSkinName)
	for _, skinId in Config.Cosmetics.SkinOrder do
		local count = g.Skins[skinId] or 0
		if count > 0 then
			skinRow(skinId, skinCfgs[skinId].Name .. (if count > 1 then ` x{count}` else ""))
		end
	end
end

local function renderItems()
	if not gear then
		heading("Loading...")
		return
	end
	local shown = false
	-- Breach Charges: crafted from Riftsalt anywhere (Josh's call, step 8;
	-- Workshop I takes over crafting in step 10).
	local chargeCfg = Config.BreachCharges
	if riftsaltHeld() > 0 or itemCount(chargeCfg.ItemId) > 0 then
		shown = true
		heading("CRAFT")
		local costParts = {}
		for resource, amount in chargeCfg.Cost do
			table.insert(costParts, `{amount} {resource}`)
		end
		row({
			{ text = chargeCfg.Name, width = 200 },
			{ text = table.concat(costParts, " + "), width = 120, color = NOTE },
		}, "Craft", function()
			ask(Remotes.getFunction("Craft"), chargeCfg.ItemId)
		end)
		heading("ITEMS")
	end
	for _, itemId in bagCfg.ItemOrder do
		local count = itemCount(itemId)
		if count > 0 then
			shown = true
			local names: { [string]: string } = bagCfg.ItemNames :: any
			local gadgetNames: { [string]: string } = Config.Gadgets.Names :: any
			row({ { text = names[itemId] or gadgetNames[itemId] or itemId, width = 200 }, { text = `x{count}`, width = 100 } }, nil, nil, nil, nil, function()
				debugEvent:FireServer("DeleteItem", itemId)
			end)
		end
	end
	if not shown then
		row({ { text = "No items yet", width = 300, color = Color3.fromRGB(170, 170, 190) } })
	end
end

-- Studio only: every debug key, grouped, with a Run button (same command
-- as the key; DebugService re-checks IsStudio).
local function renderDebug()
	heading("STUDIO ONLY: press the key, or Run. Results print in Output.")
	local group = ""
	for _, entry in DebugKeyList do
		if entry.Group ~= group then
			group = entry.Group
			heading(group:upper())
		end
		local command = entry.Command
		row({
			{ text = `[{entry.Label}]`, width = 44, color = Color3.fromRGB(255, 210, 90) },
			{ text = entry.Text, width = 330 },
		}, if command ~= "" then "Run" else nil, function()
			debugEvent:FireServer(command)
		end)
	end
	heading("Bag: the small X on Items / Gear rows deletes them.")
end

local function gearTabAllowed(): boolean
	return player:GetAttribute(combatCfg.Ui.GearVisibleAttribute) == true
end

render = function()
	-- Tabs you can't use yet stay hidden (R4).
	tabButtons.Gear.Visible = gearTabAllowed()
	tabButtons.Items.Visible = anyItem() or riftsaltHeld() > 0
	tabButtons.Debug.Visible = STUDIO_DELETE
	if not tabButtons[currentTab].Visible then
		currentTab = "Resources"
	end
	for tab, b in tabButtons do
		b.BackgroundColor3 = if tab == currentTab then Color3.fromRGB(40, 110, 70) else Color3.fromRGB(45, 45, 60)
	end
	if not panel.Visible then
		return
	end
	clearRows()
	if currentTab == "Resources" then
		renderResources()
	elseif currentTab == "Gear" then
		renderGear()
	elseif currentTab == "Items" then
		renderItems()
	else
		renderDebug()
	end
end

-- ── Opening + data ───────────────────────────────────────────────────────

-- The HUD scripts already fetched these at start-up; only ask again if
-- nothing has arrived yet (the snapshot remotes are rate limited).
local function fetchMissing()
	if not vault then
		local ok, result = pcall(function()
			return Remotes.getFunction("GetVaultState"):InvokeServer()
		end)
		if ok and result and not vault then
			vault = result
		end
	end
	if not gear then
		local ok, result = pcall(function()
			return Remotes.getFunction("GetGearState"):InvokeServer()
		end)
		if ok and result and not gear then
			gear = result
		end
	end
	if credits == nil or not reputation then
		local ok, gotCredits, gotState = pcall(function()
			return Remotes.getFunction("GetProgressState"):InvokeServer()
		end)
		if ok and gotState then
			credits, reputation = gotCredits, gotState
		end
	end
	if not shields then
		local ok, result = pcall(function()
			return Remotes.getFunction("GetShieldState"):InvokeServer()
		end)
		if ok and result and not shields then
			shields, shieldsAt = result, os.clock()
		end
	end
end

local function open(tab: Tab?)
	if not bagButton.Visible then
		return
	end
	currentTab = tab or currentTab
	panel.Visible = true
	render()
	if not vault or not gear or not shields or credits == nil or not reputation then
		task.spawn(function()
			fetchMissing()
			render()
		end)
	end
end

bagButton.Activated:Connect(function()
	if panel.Visible then
		panel.Visible = false
	else
		open(nil)
	end
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
for _, tab in TABS do
	tabButtons[tab].Activated:Connect(function()
		currentTab = tab :: Tab
		render()
	end)
end
openEvent.Event:Connect(function(tab: any)
	open(if tab == "Gear" or tab == "Items" or tab == "Resources" or tab == "Debug" then tab :: Tab else nil)
end)

Remotes.getEvent("VaultChanged").OnClientEvent:Connect(function(state: Types.VaultState)
	vault = state
	render()
end)
Remotes.getEvent("GearChanged").OnClientEvent:Connect(function(state: Types.GearState)
	gear = state
	render()
end)
Remotes.getEvent("CreditsChanged").OnClientEvent:Connect(function(amount: number)
	credits = amount
	render()
end)
Remotes.getEvent("ReputationChanged").OnClientEvent:Connect(function(state: Types.ReputationState)
	reputation = state
	render()
end)
Remotes.getEvent("ShieldState").OnClientEvent:Connect(function(state: Types.ShieldState)
	shields, shieldsAt = state, os.clock()
	render()
end)

-- Tick the shield countdown while the Bag shows it (no rebuild each second).
task.spawn(function()
	while true do
		task.wait(1)
		local label = shieldLabel
		if label and label.Parent and panel.Visible then
			local text = shieldText()
			if text then
				label.Text = text
			else
				render() -- it just ran out: drop the row
			end
		end
	end
end)

-- ── Visibility (server-controlled, R4) ───────────────────────────────────

local function applyVisibility()
	-- In Studio the Bag stays reachable even with the meter hidden (key H),
	-- so the Debug tab can always turn it back on.
	local visible = player:GetAttribute(meterCfg.VisibleAttribute) == true or STUDIO_DELETE
	bagButton.Visible = visible
	if not visible then
		panel.Visible = false
	end
	render()
end
player:GetAttributeChangedSignal(meterCfg.VisibleAttribute):Connect(applyVisibility)
player:GetAttributeChangedSignal(combatCfg.Ui.GearVisibleAttribute):Connect(render)
applyVisibility()
