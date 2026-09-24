--!strict
-- The Bag (Josh, 2026-09-23): everything you own in one panel, split into
-- SAFE (banked / worn) and AT RISK (exposed / spare armor), with tabs
-- Resources | Gear | Skins | Items. 02-core-loop.md § Bank vs Exposed; 05-items.md
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
-- Studio only: a small Debug button at the top centre of the screen opens the
-- Bag on a Debug tab (every key in Shared/DebugKeyList with a Run button); the
-- tab is not in the tab bar. Small X buttons also delete items / armor. It all
-- goes away with the debug tools.
-- Other scripts open it with the "Open" BindableEvent inside this ScreenGui
-- (argument: tab name): the vault meter and the Gear menu's Armor/Skin rows
-- (Armor opens Gear, Skin opens Skins).
-- Look: Shared/UiStyle (Config.UiStyle, look only). Cards and rows instead of
-- text cells; two columns on wide windows, one on phones; the tab bar moves up
-- into the header when there is room, and short windows (phone landscape) drop
-- the explanatory notes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))
local DebugKeyList = require(Shared:WaitForChild("DebugKeyList"))
local UiStyle = require(Shared:WaitForChild("UiStyle"))

local player = Players.LocalPlayer
local bagCfg = Config.Inventory
local meterCfg = Config.Bank.Meter
local combatCfg = Config.Combat
local style = Config.UiStyle
local colors = style.Colors
local windowCfg = style.Window
local TAP = style.MinTap
local SAFE = meterCfg.BankedColor
local RISK = meterCfg.ExposedColor
local SHIELD = bagCfg.ShieldColor
local money = UiStyle.money

-- [PH] invented look-only: the Bag needs more height than the old 340px cap
-- now that the tab bar and 56px rows are in (width keeps Config's cap).
local BAG_MAX_HEIGHT = 560
-- [PH] invented look-only: width of the track name ("Miner 4") in the Level block.
local TRACK_NAME_WIDTH = 78
-- [PH] invented look-only: button widths inside item rows (height is MinTap).
local ROW_BUTTON_WIDTH = 92
local ROW_BUTTON_SHORT = 64

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

type Tab = "Resources" | "Gear" | "Skins" | "Items" | "Debug"
local TABS: { string } = { "Resources", "Gear", "Skins", "Items", "Debug" }

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

-- ── UI ───────────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "InventoryUi"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- children always draw above their parent (toast, bar text)
gui.DisplayOrder = bagCfg.DisplayOrder
local openEvent = Instance.new("BindableEvent")
openEvent.Name = "Open"
openEvent.Parent = gui

-- One slot in the shared dock (Raids / Bag / Trade / Gear). The dock is its
-- own HUD-level ScreenGui, so open menus (Gear) draw over it; the open Bag
-- itself is above them (bagCfg.DisplayOrder).
local playerGui = player:WaitForChild("PlayerGui")
local bagButton = UiStyle.dockButton(playerGui, bagCfg.ButtonLabel, "neutral", style.Dock.Order.Bag)
bagButton.Visible = false

-- Studio only, goes away with the debug tools: the last slot in the dock, which
-- opens the Bag on its Debug tab (wired below, once `open` exists).
local debugButton = UiStyle.dockButton(playerGui, "Debug", "info", 9)
debugButton.Visible = STUDIO_DELETE

local win = UiStyle.window(gui, "Bag", 0.9, 0.9, Vector2.new(bagCfg.PanelMaxSize.X, BAG_MAX_HEIGHT))
local panel = win.panel
local header = win.header
local closeButton = win.close
local content = win.content

local tabs = UiStyle.tabBar(panel, TABS)
local tabButtons = tabs.buttons

-- Short messages ("Too fast", "Not enough Riftsalt") along the panel's bottom.
local toast = UiStyle.toast(panel, true)

gui.Parent = playerGui

-- Wide windows have room for the tabs beside the title; narrow ones give them
-- their own row and the list starts lower.
local function layoutChrome()
	local wide = UiStyle.isWide(panel)
	local rowTop = windowCfg.HeaderPad * 2 + TAP + windowCfg.BodyGap
	tabs.frame.Parent = if wide then header else panel
	tabs.frame.LayoutOrder = 2
	tabs.frame.AutomaticSize = Enum.AutomaticSize.X
	tabs.frame.Size = UDim2.fromOffset(0, TAP)
	tabs.frame.Position = UDim2.fromOffset(windowCfg.HeaderInset, rowTop)
	local top = if wide then rowTop else rowTop + TAP + windowCfg.BodyGap
	local bodyPos = UDim2.fromOffset(windowCfg.EdgePad, top)
	local bodySize = UDim2.new(1, -2 * windowCfg.EdgePad, 1, -(top + windowCfg.EdgePad))
	content.Position = bodyPos
	content.Size = bodySize
	win.well.Position = bodyPos
	win.well.Size = bodySize
end
layoutChrome()

-- ── Row builders ─────────────────────────────────────────────────────────

-- Hands out 1, 2, 3... for LayoutOrder inside one parent.
local function sequence(): () -> number
	local n = 0
	return function(): number
		n += 1
		return n
	end
end

-- The columns of the tab being shown (nil when it has none), so a resize can
-- switch them between one and two without rebuilding.
local activeColumns: UiStyle.Columns? = nil

local function makeColumns(order: number): UiStyle.Columns
	local cols = UiStyle.columns(content, order)
	UiStyle.setColumns(cols, UiStyle.isWide(panel))
	activeColumns = cols
	return cols
end

local function clearRows()
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	activeColumns = nil
end

local function note(parent: Instance, text: string, order: number, color: Color3?): TextLabel
	local label = UiStyle.label(parent, text, style.TextSize.Small, color or colors.TextDim, false)
	label.LayoutOrder = order
	return label
end

local function addButton(r: UiStyle.ItemRow, text: string, kind: UiStyle.ButtonKind, width: number, order: number, onTap: () -> ()): TextButton
	local b = UiStyle.button(r.trailing, text, kind, width, TAP)
	b.LayoutOrder = order
	b.Activated:Connect(onTap)
	return b
end

-- Studio only: the small X that deletes an item / armor piece (Josh's test request).
local function addDelete(r: UiStyle.ItemRow, order: number, onDelete: (() -> ())?)
	if onDelete and STUDIO_DELETE then
		addButton(r, "X", "danger", TAP, order, onDelete)
	end
end

local function loadingCard()
	UiStyle.emptyState(content, "Loading...", nil, 1)
end

local function total(grades: Types.GradeCounts?): number
	local sum = 0
	for _, count in grades or ({} :: Types.GradeCounts) do
		sum += count
	end
	return sum
end

-- "Standard 90 · Dense 8" (only Grades you have, best last like the docs), each
-- Grade in its own colour (rich text) like the buyer and trade screens.
local function gradeText(grades: Types.GradeCounts?): string
	local parts = {}
	for _, grade in Config.Grade.Names do
		local count = (grades or ({} :: Types.GradeCounts))[grade] or 0
		if count > 0 then
			table.insert(parts, `<font color="#{UiStyle.gradeColor(grade):ToHex()}">{grade} {money(count)}</font>`)
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

local function showMessage(text: string)
	toast.show(text, Config.Base.BuildUi.MessageSeconds, "bad")
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
local shortWindow = false -- phone landscape: drop the explanatory notes

-- Step 9: Credits and Level (06 § Currencies; 03 § Level). Shown while
-- Config.Inventory.ShowCredits is on; the FTUE turns it off (step 14).
local function levelBlock(parent: Instance, order: number)
	local rep = reputation
	local badgeSize = style.Level.BadgeSize
	local card = UiStyle.card(parent, order)
	local top = Instance.new("Frame")
	top.LayoutOrder = 1
	top.Size = UDim2.new(1, 0, 0, 0)
	top.AutomaticSize = Enum.AutomaticSize.Y
	top.BackgroundTransparency = 1
	top.Parent = card
	UiStyle.list(top, true, style.Gap)

	-- Level badge on the left.
	local badge = Instance.new("Frame")
	badge.LayoutOrder = 1
	badge.Size = UDim2.fromOffset(badgeSize, badgeSize)
	badge.BackgroundColor3 = colors.BarTrack
	badge.BorderSizePixel = 0
	badge.Parent = top
	UiStyle.corner(badge, style.CardCorner)
	UiStyle.stroke(badge, colors.Accent, 2)
	local badgeList = UiStyle.list(badge, false, 0)
	badgeList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	badgeList.VerticalAlignment = Enum.VerticalAlignment.Center
	local levelNumber = UiStyle.label(badge, if rep then tostring(rep.Level) else "...", style.TextSize.Huge, colors.Accent, true)
	levelNumber.LayoutOrder = 1
	levelNumber.TextXAlignment = Enum.TextXAlignment.Center
	local levelCaption = UiStyle.label(badge, "LEVEL", style.TextSize.Small, colors.TextDim, true)
	levelCaption.LayoutOrder = 2
	levelCaption.TextXAlignment = Enum.TextXAlignment.Center

	-- Credits pill + one bar per track on the right.
	local right = Instance.new("Frame")
	right.LayoutOrder = 2
	right.Size = UDim2.new(1, -(badgeSize + style.Gap), 0, 0)
	right.AutomaticSize = Enum.AutomaticSize.Y
	right.BackgroundTransparency = 1
	right.Parent = top
	UiStyle.list(right, false, style.Gap / 2)
	local creditsPill = UiStyle.pill(right, `Credits {money(credits or 0)}`, colors.Accent)
	creditsPill.LayoutOrder = 1
	if rep then
		for index, track in Config.Progression.Tracks do
			local t = rep.Tracks[track]
			local trackRow = UiStyle.row(right, style.Level.BarHeight + 2, index + 1)
			local name = UiStyle.label(trackRow, `{track} {t.Level}`, style.TextSize.Small, colors.Text, true)
			name.Size = UDim2.fromOffset(TRACK_NAME_WIDTH, style.Level.BarHeight + 2)
			name.AutomaticSize = Enum.AutomaticSize.None
			name.TextTruncate = Enum.TextTruncate.AtEnd
			name.TextWrapped = false
			name.LayoutOrder = 1
			local span = math.max(1, t.Next - t.Prev)
			-- The bar takes whatever width is left (never negative on a narrow
			-- phone); the XP numbers sit inside it.
			local bar = UiStyle.bar(trackRow, style.Level.BarHeight, (t.XP - t.Prev) / span, colors.Good)
			bar.LayoutOrder = 2
			bar.Size = UDim2.fromOffset(0, style.Level.BarHeight)
			local flex = Instance.new("UIFlexItem")
			flex.FlexMode = Enum.UIFlexMode.Fill
			flex.Parent = bar
			UiStyle.barLabel(bar, `{money(t.XP - t.Prev)}/{money(span)}`)
		end
	end
	if rep and not rep.TradeUnlocked then
		note(card, `Trading unlocks at Level {Config.Progression.TradeUnlockLevel}.`, 2)
	end
end

-- Your raid shields (01 R6; D67, D75). The top label is ticked every second.
local function shieldCard(parent: Instance, order: number, text: string)
	local card = UiStyle.card(parent, order)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = SHIELD
	end
	local label = UiStyle.label(card, text, style.TextSize.Body, SHIELD, true)
	label.LayoutOrder = 1
	shieldLabel = label
	if not shortWindow then
		note(card, "Breaching someone's base ends your shield.", 2)
	end
end


-- SAFE / AT RISK share the row's detail line (two pills squeezed the name on a
-- 360px phone). The bank cap, when given, shows as "SAFE 120 / 500".
local function setSafeRisk(row: UiStyle.ItemRow, safe: number, risk: number, cap: number?)
	local safeText = if cap then `{money(safe)} / {money(cap)}` else money(safe)
	row.detail.RichText = true
	row.detail.Text = `<font color="#{SAFE:ToHex()}">SAFE {safeText}</font>  ·  <font color="#{RISK:ToHex()}">AT RISK {money(risk)}</font>`
	row.detail.Visible = true
end

local function renderResources()
	local v = vault
	if not v then
		loadingCard()
		return
	end
	local nextOrder = sequence()
	shieldLabel = nil
	local cols = makeColumns(nextOrder())
	local left, right = cols.left, cols.right
	local leftOrder, rightOrder = sequence(), sequence()

	if bagCfg.ShowCredits then
		levelBlock(left, leftOrder())
	end
	local shieldNow = shieldText()
	if shieldNow then
		shieldCard(left, leftOrder(), shieldNow)
	end

	local bankedTotal = 0
	for _, grades in v.Banked do
		bankedTotal += total(grades)
	end
	local vaultCard = UiStyle.card(left, leftOrder())
	local vaultMeter = UiStyle.meter(vaultCard, "Vault", 0, SAFE, 1)
	UiStyle.setMeter(vaultMeter, bankedTotal / math.max(1, v.Capacity), `{money(bankedTotal)} / {money(v.Capacity)}`)
	if not shortWindow then
		note(vaultCard, "At-risk items can be stolen in raids. Bank them at your Vault Core.", 2)
	end

	local exposedAll = 0
	for _, grades in v.Exposed do
		exposedAll += total(grades)
	end
	UiStyle.sectionHeader(right, "Resources", rightOrder(), nil, if exposedAll > 0 then `{money(exposedAll)} at risk` else nil)
	for _, resource in Config.Resources.Types do
		local banked, exposed = total(v.Banked[resource]), total(v.Exposed[resource])
		if banked > 0 or exposed > 0 or resource == Config.Resources.Types[1] then
			local open = openResource == resource
			-- Tap a resource to see its Grades (depth only when asked: R4).
			local r = UiStyle.itemRow(right, resource, "", rightOrder(), true)
			-- The arrow sits on the right so the names stay lined up when a row opens.
			local arrow = UiStyle.label(r.trailing, if open then "▼" else "▶", style.TextSize.Body, colors.TextDim, true)
			arrow.AutomaticSize = Enum.AutomaticSize.None
			arrow.Size = UDim2.new(0, 20, 1, 0)
			arrow.TextXAlignment = Enum.TextXAlignment.Center
			setSafeRisk(r, banked, exposed)
			local tap = r.root :: TextButton -- tappable => a TextButton
			tap.Activated:Connect(function()
				openResource = if open then nil else resource
				render()
			end)
			if open then
				local indent = Instance.new("Frame")
				indent.LayoutOrder = rightOrder()
				indent.Size = UDim2.new(1, 0, 0, 0)
				indent.AutomaticSize = Enum.AutomaticSize.Y
				indent.BackgroundTransparency = 1
				indent.Parent = right
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, style.Pad * 2)
				pad.Parent = indent
				local grades = UiStyle.card(indent, 1)
				grades.Size = UDim2.new(1, 0, 0, 0)
				local safeLine = UiStyle.label(grades, `<font color="#{SAFE:ToHex()}">safe:</font> {gradeText(v.Banked[resource])}`, style.TextSize.Small, colors.Text, true)
				safeLine.RichText = true
				safeLine.LayoutOrder = 1
				local riskLine = UiStyle.label(grades, `<font color="#{RISK:ToHex()}">at risk:</font> {gradeText(v.Exposed[resource])}`, style.TextSize.Small, colors.Text, true)
				riskLine.RichText = true
				riskLine.LayoutOrder = 2
			end
		end
	end
	local scrap = UiStyle.itemRow(right, "Scrap", "", rightOrder())
	setSafeRisk(scrap, v.ScrapBanked, v.ScrapExposed, v.ScrapCapacity)
end

local function renderGear()
	local g = gear
	if not g then
		loadingCard()
		return
	end
	local nextOrder = sequence()
	local skinCfgs: { [string]: { Name: string } } = Config.Cosmetics.PickaxeSkins :: any
	local skinName = if g.EquippedSkin == "" then Config.Cosmetics.DefaultSkinName else (skinCfgs[g.EquippedSkin] and skinCfgs[g.EquippedSkin].Name or g.EquippedSkin)
	UiStyle.itemRow(content, `Pickaxe: {tierName(g.PickaxeTier)}`, `Skin: {skinName}`, nextOrder())

	if #g.ArmorPieces == 0 then
		UiStyle.sectionHeader(content, "Armor", nextOrder())
		UiStyle.emptyState(content, "No armor", nil, nextOrder())
	end
	-- The worn piece, then spares grouped by tier + slot ("Wooden chest x3").
	-- Same-tier pieces are identical (D112), so Wear sends the first one.
	type Group = { tier: number, slot: string, ids: { string } }
	local groups: { Group } = {}
	for _, piece in g.ArmorPieces do
		if piece.Id == g.ArmorEquipped then
			UiStyle.sectionHeader(content, "Worn · safe", nextOrder(), SAFE)
			local r = UiStyle.itemRow(content, `{tierName(piece.Tier)} {piece.Slot:lower()}`, nil, nextOrder())
			addButton(r, "Take off", "neutral", ROW_BUTTON_WIDTH, 1, function()
				ask(equipRemote, "")
			end)
			addDelete(r, 2, function()
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
	local spareCount = 0
	for _, group in groups do
		spareCount += #group.ids
	end
	if spareCount > 0 then
		UiStyle.sectionHeader(content, "Spare · can be stolen", nextOrder(), RISK, `{spareCount} {if spareCount == 1 then "piece" else "pieces"}`)
	end
	for _, group in groups do
		local count = #group.ids
		local r = UiStyle.itemRow(content, `{tierName(group.tier)} {group.slot:lower()}{if count > 1 then ` x{count}` else ""}`, nil, nextOrder())
		addButton(r, "Wear", "primary", ROW_BUTTON_WIDTH, 1, function()
			ask(equipRemote, group.ids[1])
		end)
		addDelete(r, 2, function()
			debugEvent:FireServer("DeleteArmor", group.ids[1])
		end)
	end
end

-- Pickaxe skins are cosmetics (R1: identity, never lootable). Its own tab so
-- it can grow (more skins, previews) without crowding Gear.
local function renderSkins()
	local g = gear
	if not g then
		loadingCard()
		return
	end
	local nextOrder = sequence()
	local skinCfgs: { [string]: { Name: string } } = Config.Cosmetics.PickaxeSkins :: any
	local ownedSkins = 1 -- the default skin
	for _, skinId in Config.Cosmetics.SkinOrder do
		if (g.Skins[skinId] or 0) > 0 then
			ownedSkins += 1
		end
	end
	UiStyle.sectionHeader(content, "Pickaxe skins", nextOrder(), nil, `{ownedSkins} owned`)
	local function skinRow(skinId: string, label: string)
		local equipped = g.EquippedSkin == skinId
		local r = UiStyle.itemRow(content, label, nil, nextOrder())
		if equipped then
			UiStyle.pill(r.trailing, "EQUIPPED", colors.BarTrack, colors.Good).LayoutOrder = 1
		else
			addButton(r, "Equip", "primary", ROW_BUTTON_WIDTH, 1, function()
				ask(skinRemote, skinId)
			end)
		end
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
		loadingCard()
		return
	end
	local nextOrder = sequence()
	-- Breach Charges: crafted from Riftsalt anywhere (Josh's call, step 8;
	-- Workshop I takes over crafting in step 10).
	local chargeCfg = Config.BreachCharges
	local craftShown = riftsaltHeld() > 0 or itemCount(chargeCfg.ItemId) > 0
	local itemsParent: Instance = content
	local itemsOrder = sequence()
	if craftShown then
		-- Craft on the left, what you own on the right (stacked on phones).
		local cols = makeColumns(nextOrder())
		local craftOrder = sequence()
		UiStyle.sectionHeader(cols.left, "Craft", craftOrder())
		local costParts = {}
		for resource, amount in chargeCfg.Cost do
			table.insert(costParts, `{amount} {resource}`)
		end
		-- Grey out Craft when you're short, and say by how much. The server still checks the real cost (R5).
		local shortOf: string? = nil
		local v = vault
		if v then
			for resource, amount in (chargeCfg.Cost :: any) :: { [string]: number } do
				local have = total(v.Banked[resource]) + total(v.Exposed[resource])
				if have < amount then
					shortOf = `Need {table.concat(costParts, " + ")} (have {have})`
					break
				end
			end
		end
		local craft = UiStyle.itemRow(cols.left, chargeCfg.Name, shortOf or table.concat(costParts, " + "), craftOrder())
		addButton(craft, "Craft", if shortOf then "disabled" else "primary", ROW_BUTTON_WIDTH, 1, function()
			ask(Remotes.getFunction("Craft"), chargeCfg.ItemId)
		end)
		itemsParent = cols.right
		local kinds = 0
		for _, itemId in bagCfg.ItemOrder do
			if itemCount(itemId) > 0 then
				kinds += 1
			end
		end
		UiStyle.sectionHeader(itemsParent, "Items", itemsOrder(), nil, if kinds > 0 then tostring(kinds) else nil)
	end
	local shown = false
	for _, itemId in bagCfg.ItemOrder do
		local count = itemCount(itemId)
		if count > 0 then
			shown = true
			local names: { [string]: string } = bagCfg.ItemNames :: any
			local gadgetNames: { [string]: string } = Config.Gadgets.Names :: any
			local r = UiStyle.itemRow(itemsParent, names[itemId] or gadgetNames[itemId] or itemId, nil, if craftShown then itemsOrder() else nextOrder())
			UiStyle.pill(r.trailing, `x{count}`, colors.Text).LayoutOrder = 1
			addDelete(r, 2, function()
				debugEvent:FireServer("DeleteItem", itemId)
			end)
		end
	end
	if not shown then
		UiStyle.emptyState(itemsParent, "No items yet", nil, if craftShown then itemsOrder() else nextOrder())
	end
end

-- Studio only: every debug key, grouped, with a Run button (same command
-- as the key; DebugService re-checks IsStudio).
local function renderDebug()
	local nextOrder = sequence()
	note(content, "STUDIO ONLY: press the key, or Run. Results print in Output.", nextOrder())
	local group = ""
	for _, entry in DebugKeyList do
		if entry.Group ~= group then
			group = entry.Group
			UiStyle.sectionHeader(content, group, nextOrder())
		end
		local command = entry.Command
		local r = UiStyle.itemRow(content, entry.Text, nil, nextOrder())
		UiStyle.pill(r.trailing, `[{entry.Label}]`, colors.Accent).LayoutOrder = 1
		if command ~= "" then
			addButton(r, "Run", "info", ROW_BUTTON_SHORT, 2, function()
				debugEvent:FireServer(command)
			end)
		end
	end
	note(content, "Bag: the small X on Items / Gear rows deletes them.", nextOrder())
end

local function gearTabAllowed(): boolean
	return player:GetAttribute(combatCfg.Ui.GearVisibleAttribute) == true
end

render = function()
	-- Tabs you can't use yet stay hidden (R4).
	tabButtons.Gear.Visible = gearTabAllowed()
	tabButtons.Skins.Visible = gearTabAllowed()
	tabButtons.Items.Visible = anyItem() or riftsaltHeld() > 0
	tabButtons.Debug.Visible = false -- reached from the top-centre Debug button, not the tab bar
	if not tabButtons[currentTab].Visible and not (currentTab == "Debug" and STUDIO_DELETE) then
		currentTab = "Resources"
	end
	UiStyle.setActiveTab(tabs, currentTab)
	if not panel.Visible then
		return
	end
	layoutChrome()
	shortWindow = UiStyle.isShort(panel)
	clearRows()
	if currentTab == "Resources" then
		renderResources()
	elseif currentTab == "Gear" then
		renderGear()
	elseif currentTab == "Skins" then
		renderSkins()
	elseif currentTab == "Items" then
		renderItems()
	else
		renderDebug()
	end
end

-- Rotating or resizing: re-flow the chrome and columns; the short-window notes
-- need a rebuild.
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if not panel.Visible then
		return
	end
	layoutChrome()
	local cols = activeColumns
	if cols then
		UiStyle.setColumns(cols, UiStyle.isWide(panel))
	end
	if UiStyle.isShort(panel) ~= shortWindow then
		render()
	end
end)

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
debugButton.Activated:Connect(function()
	if panel.Visible and currentTab == "Debug" then
		panel.Visible = false
	else
		open("Debug")
	end
end)
for _, tab in TABS do
	tabButtons[tab].Activated:Connect(function()
		currentTab = tab :: Tab
		render()
	end)
end
openEvent.Event:Connect(function(tab: any)
	open(if tab == "Gear" or tab == "Skins" or tab == "Items" or tab == "Resources" or tab == "Debug" then tab :: Tab else nil)
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
