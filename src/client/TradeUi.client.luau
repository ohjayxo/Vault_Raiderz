--!strict
-- Direct trade UI (06-economy.md § Zero-chat trade D61, § Trade Safety).
-- A Trade button (once you're Level 10), a Nearby list to invite someone, an
-- invite popup, and the trade window: what you give and what you get, listed
-- exactly as the server holds them, a 5-second lock before Confirm, and a
-- below-market warning.
--
-- Display and intents only (R5): the client asks "set this line to N",
-- "Confirm this version" or "Cancel"; the server keeps the offers, checks
-- ownership, the lock and the swap. Nothing typed here is a value the server
-- trusts.
-- Look: Shared/UiStyle (Config.UiStyle, look only). The window is two columns
-- (You give | You get) on wide screens and one stacked column on phones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))
local UiStyle = require(Shared:WaitForChild("UiStyle"))

local player = Players.LocalPlayer
local tradeCfg = Config.Trade
local ui = tradeCfg.Ui
local style = Config.UiStyle
local colors = style.Colors
local TAP = style.MinTap
local money = UiStyle.money

local REASON_TEXT: { [string]: string } = {
	Busy = "Too fast",
	Invalid = "Can't do that",
	Locked = `Trading unlocks at Level {Config.Progression.TradeUnlockLevel}`,
	TargetLocked = "They haven't reached the trading level yet",
	TargetBusy = "They're busy right now",
	TooFar = "You're too far apart",
	InRaid = "Can't trade during a raid",
	Dead = "Can't trade right now",
	Unavailable = "Can't trade right now",
	NotFound = "That player isn't here",
	NoTrade = "No trade is open",
	NotEnough = "You don't have that many",
	NotTradeable = "That can't be traded",
	TooMany = "Too many different items in the offer",
	Changed = "The offer just changed: look again",
	WaitLock = "Wait for the lock to finish",
	Empty = "Add something to the offer first",
	Expired = "That invite ran out",
	Cooldown = "Give them a moment before asking again",
	Failed = "Something went wrong, try again",
}

local vault: Types.VaultState? = nil
local gear: Types.GearState? = nil
local credits = 0
local reputation: Types.ReputationState? = nil
local view: Types.TradeView? = nil
local inviteId: string? = nil
local busy = false

-- ── Shells ───────────────────────────────────────────────────────────────

local playerGui = player:WaitForChild("PlayerGui")

local windowGui = Instance.new("ScreenGui")
windowGui.Name = "TradeWindow"
windowGui.ResetOnSpawn = false
-- Sibling z-order: a child always draws above its parent. (The default for a
-- script-made ScreenGui is Global, where the invite popup's ZIndex = 10 drew
-- OVER its own text and buttons, leaving an empty box.)
windowGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
windowGui.DisplayOrder = ui.DisplayOrder

-- HUD button: one slot in the shared dock (Raids / Bag / Trade / Gear).
local tradeButton = UiStyle.dockButton(playerGui, ui.ButtonLabel, "neutral", style.Dock.Order.Trade)
tradeButton.Visible = false

-- Short messages (declines, timeouts), always on screen: the shared HUD toast spot.
local hudToast = UiStyle.toast(windowGui)
local function showToast(text: string, seconds: number?)
	hudToast.show(text, seconds or ui.MessageSeconds)
end

-- ── Names, avatars ───────────────────────────────────────────────────────

local function itemName(id: string): string
	local gadgetNames: { [string]: string } = Config.Gadgets.Names :: any
	local bagNames: { [string]: string } = Config.Inventory.ItemNames :: any
	return gadgetNames[id] or bagNames[id] or id
end

local function skinName(id: string): string
	local skins: { [string]: { Name: string } } = Config.Cosmetics.PickaxeSkins :: any
	return if skins[id] then skins[id].Name else id
end

local function lineText(line: Types.TradeLine): string
	if line.Kind == "Resource" then
		return `{money(line.Amount)} {line.Id} ({line.Grade})`
	elseif line.Kind == "Skin" then
		return `{money(line.Amount)} x {skinName(line.Id)} skin`
	end
	return `{money(line.Amount)} x {itemName(line.Id)}`
end

local function offerText(offer: Types.TradeOffer): string
	local parts: { string } = {}
	if offer.Credits > 0 then
		table.insert(parts, `{money(offer.Credits)} Credits`)
	end
	for _, line in offer.Lines do
		table.insert(parts, lineText(line))
	end
	return if #parts > 0 then table.concat(parts, ", ") else "nothing"
end

-- Head-shot thumbnails, fetched once per player. Studio's test players have
-- negative UserIds (no thumbnail), and any fetch can fail: the initial stays.
local thumbnails: { [number]: string } = {}
local thumbnailFailed: { [number]: boolean } = {}

local function avatar(parent: Instance, userId: number?, name: string, size: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = colors.ButtonNeutral
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UiStyle.corner(frame, 999)
	local initial = UiStyle.label(frame, string.upper(string.sub(name, 1, 1)), style.TextSize.Title, colors.Text, true)
	initial.Size = UDim2.fromScale(1, 1)
	initial.AutomaticSize = Enum.AutomaticSize.None
	initial.TextXAlignment = Enum.TextXAlignment.Center

	local function show(content: string)
		if not frame.Parent then
			return
		end
		local image = Instance.new("ImageLabel")
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = content
		image.Parent = frame
		UiStyle.corner(image, 999)
		initial.Visible = false
	end
	if userId and userId > 0 and not thumbnailFailed[userId] then
		local cached = thumbnails[userId]
		if cached then
			show(cached)
		else
			task.spawn(function()
				local ok, content, ready = pcall(function()
					return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				end)
				if ok and ready and type(content) == "string" then
					thumbnails[userId] = content
					show(content)
				else
					thumbnailFailed[userId] = true
				end
			end)
		end
	end
	return frame
end

local function userIdOfName(name: string): number?
	local found = Players:FindFirstChild(name)
	return if found and found:IsA("Player") then found.UserId else nil
end

-- ── Helpers ──────────────────────────────────────────────────────────────

local function clear(list: Instance)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Refusals the server already explained with its own message (TradeState nil +
-- text), so the generic reason toast would just replace a better one.
local SERVER_TELLS: { [string]: { [string]: boolean } } = { TradeRespond = { Cancelled = true, TooFar = true } }

local function ask(remote: string, ...: any): (boolean, string?)
	if busy then
		return false, "Busy"
	end
	busy = true
	local ok, accepted, reason = pcall(function(...)
		return Remotes.getFunction(remote):InvokeServer(...)
	end, ...)
	busy = false
	if not ok then
		showToast(REASON_TEXT.Failed)
		return false, "Failed"
	elseif not accepted then
		local told = SERVER_TELLS[remote]
		if not (told and told[reason]) then
			showToast(REASON_TEXT[reason] or REASON_TEXT.Failed)
		end
		return false, reason
	end
	return true, nil
end

-- A one-line "name .... value" row inside a card.
local function twoCol(parent: Instance, order: number, left: string, leftColor: Color3, right: string?, rightColor: Color3?): Frame
	local row = UiStyle.row(parent, 24, order)
	local l = UiStyle.label(row, left, style.TextSize.Body, leftColor, true)
	l.Size = UDim2.new(0.62, 0, 1, 0)
	l.AutomaticSize = Enum.AutomaticSize.None
	l.TextWrapped = false
	l.TextTruncate = Enum.TextTruncate.AtEnd
	if right then
		local r = UiStyle.label(row, right, style.TextSize.Small, rightColor or colors.TextDim, false)
		r.Size = UDim2.new(0.38, -6, 1, 0)
		r.AutomaticSize = Enum.AutomaticSize.None
		r.TextXAlignment = Enum.TextXAlignment.Right
		r.TextWrapped = false
		r.TextTruncate = Enum.TextTruncate.AtEnd
	end
	return row
end

-- ── Nearby list + history ────────────────────────────────────────────────

local nearbyWin = UiStyle.window(windowGui, "Trade", 0.92, 0.85, ui.NearbyPanelMaxSize)
local nearbyPanel = nearbyWin.panel
local nearbyClose = nearbyWin.close
local nearbyList = nearbyWin.content
-- Refresh sits in the header, so it doesn't split the two lists.
local nearbyRefresh = UiStyle.button(nearbyWin.header, "Refresh", "chip", 88, TAP)
nearbyRefresh.LayoutOrder = 2

local renderNearby: () -> ()

local nearbyToken = 0
-- The server rate-limits both lists (and answers {} when limited), so a fetch
-- newer than this many seconds is reused instead of asked for again: a quick
-- double tap on Refresh can't turn a real list into a false "nobody nearby".
local NEARBY_REFETCH_SECONDS = math.max(tradeCfg.NearbyCooldownSeconds, tradeCfg.HistoryCooldownSeconds) + 0.1
local lastNearbyFetch = -math.huge
local cachedPeople: { { UserId: number, Name: string } } = {}
local cachedRecords: { Types.TradeRecord } = {}

renderNearby = function()
	-- Fetch first (these yield), then build in one go. A second call while the
	-- first is still fetching supersedes it.
	nearbyToken += 1
	local token = nearbyToken
	if os.clock() - lastNearbyFetch >= NEARBY_REFETCH_SECONDS then
		lastNearbyFetch = os.clock()
		local ok, list = pcall(function()
			return Remotes.getFunction("GetNearbyTraders"):InvokeServer()
		end)
		local okHistory, history = pcall(function()
			return Remotes.getFunction("GetTradeHistory"):InvokeServer()
		end)
		if token ~= nearbyToken then
			return
		end
		if ok and type(list) == "table" then
			cachedPeople = list
		end
		if okHistory and type(history) == "table" then
			cachedRecords = history
		end
	end
	local people = cachedPeople
	local records = cachedRecords

	clear(nearbyList)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	UiStyle.label(nearbyList, "Walk close to a player who has reached Level 10, then tap Invite.", style.TextSize.Small, colors.TextDim, false).LayoutOrder = nextOrder()
	UiStyle.sectionHeader(nearbyList, "Nearby", nextOrder(), nil, tostring(#people))

	if #people == 0 then
		local empty = UiStyle.card(nearbyList, nextOrder())
		UiStyle.label(empty, "Nobody nearby can trade right now.", style.TextSize.Body, colors.TextDim, false)
	end
	for _, person in people do
		local card = UiStyle.card(nearbyList, nextOrder())
		local row = UiStyle.row(card, style.AvatarSize + 4, 1)
		avatar(row, person.UserId, person.Name, style.AvatarSize)
		local name = UiStyle.label(row, person.Name, style.TextSize.Body, colors.Text, true)
		name.Size = UDim2.new(1, -(style.AvatarSize + 96 + 12), 1, 0)
		name.AutomaticSize = Enum.AutomaticSize.None
		name.TextWrapped = false
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local invite = UiStyle.button(row, "Invite", "primary", 96, TAP)
		invite.Activated:Connect(function()
			if ask("TradeInvite", person.UserId) then
				showToast(`Invite sent to {person.Name}`)
				nearbyPanel.Visible = false
			end
		end)
	end

	-- 06 § Trade Safety: your saved trade history (newest first).
	UiStyle.sectionHeader(nearbyList, "Recent trades", nextOrder(), nil, `last {math.min(#records, ui.HistoryRowsShown)} (UTC)`)
	if #records == 0 then
		local none = UiStyle.card(nearbyList, nextOrder())
		UiStyle.label(none, "No trades yet.", style.TextSize.Body, colors.TextDim, false)
	end
	for i, record in records do
		if i > ui.HistoryRowsShown then
			break
		end
		local card = UiStyle.card(nearbyList, nextOrder())
		local when = os.date("!%m/%d %H:%M", record.At)
		twoCol(card, 1, `With {record.WithName}`, colors.Text, when, colors.TextDim)
		UiStyle.label(card, `You gave: {offerText(record.Gave)}`, style.TextSize.Small, ui.Colors.Give, false).LayoutOrder = 2
		UiStyle.label(card, `You got: {offerText(record.Got)}`, style.TextSize.Small, ui.Colors.Get, false).LayoutOrder = 3
	end
end

-- ── Invite popup ─────────────────────────────────────────────────────────

local invitePanel = UiStyle.card(windowGui, 0)
invitePanel.AnchorPoint = Vector2.new(0.5, 0)
invitePanel.Size = UDim2.new(0.94, 0, 0, 0)
local inviteLimit = Instance.new("UISizeConstraint")
inviteLimit.MaxSize = Vector2.new(340, math.huge)
inviteLimit.Parent = invitePanel
invitePanel.Position = UDim2.new(0.5, 0, 0, style.InviteSlide.HiddenY)
invitePanel.BackgroundColor3 = colors.Panel
invitePanel.Visible = false
invitePanel.ZIndex = 10
local inviteWho = UiStyle.row(invitePanel, style.AvatarSize + 4, 1)
local inviteAvatarHolder = Instance.new("Frame")
inviteAvatarHolder.Size = UDim2.fromOffset(style.AvatarSize, style.AvatarSize)
inviteAvatarHolder.BackgroundTransparency = 1
inviteAvatarHolder.Parent = inviteWho
local inviteText = UiStyle.label(inviteWho, "", style.TextSize.Body, colors.Text, true)
inviteText.Size = UDim2.new(1, -(style.AvatarSize + 6), 1, 0)
inviteText.AutomaticSize = Enum.AutomaticSize.None
local inviteBar = UiStyle.bar(invitePanel, 6, 1, colors.Accent)
inviteBar.LayoutOrder = 2
local inviteButtons = UiStyle.row(invitePanel, TAP, 3)
local acceptButton = UiStyle.button(inviteButtons, "Accept", "primary", 0, TAP)
acceptButton.Size = UDim2.new(0.5, -4, 1, 0)
local declineButton = UiStyle.button(inviteButtons, "Decline", "danger", 0, TAP)
declineButton.Size = UDim2.new(0.5, -4, 1, 0)

local function respond(accept: boolean)
	local id = inviteId
	inviteId = nil
	invitePanel.Visible = false
	if id then
		ask("TradeRespond", id, accept)
	end
end
acceptButton.Activated:Connect(function()
	respond(true)
end)
declineButton.Activated:Connect(function()
	respond(false)
end)

Remotes.getEvent("TradeInviteOffer").OnClientEvent:Connect(function(id: string, fromName: string, seconds: number)
	inviteId = id
	inviteText.Text = `{fromName} wants to trade with you`
	clear(inviteAvatarHolder)
	avatar(inviteAvatarHolder, userIdOfName(fromName), fromName, style.AvatarSize)

	-- Slide in from the top; the bar drains over the invite's lifetime.
	invitePanel.Position = UDim2.new(0.5, 0, 0, style.InviteSlide.HiddenY)
	invitePanel.Visible = true
	TweenService:Create(
		invitePanel,
		TweenInfo.new(style.InviteSlide.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, style.InviteSlide.ShownY) }
	):Play()
	UiStyle.setBar(inviteBar, 1, colors.Accent)
	local fill = inviteBar:FindFirstChild("Fill")
	if fill and fill:IsA("Frame") then
		TweenService:Create(fill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) }):Play()
	end
	task.delay(seconds, function()
		if inviteId == id then
			inviteId = nil
			invitePanel.Visible = false
		end
	end)
end)

-- Your holdings come from the vault/gear pushes; if this script missed them
-- (they're rate limited), ask once more when a window is about to show.
local function ensureData(): boolean
	local changed = false
	if not vault then
		local ok, result = pcall(function()
			return Remotes.getFunction("GetVaultState"):InvokeServer()
		end)
		if ok and result and not vault then
			vault, changed = result, true
		end
	end
	if not gear then
		local ok, result = pcall(function()
			return Remotes.getFunction("GetGearState"):InvokeServer()
		end)
		if ok and result and not gear then
			gear, changed = result, true
		end
	end
	return changed
end

-- ── The trade window ─────────────────────────────────────────────────────

local tradeWin = UiStyle.window(windowGui, "Trade", 0.96, 0.94, ui.PanelMaxSize)
local window = tradeWin.panel
local HEADER_BOTTOM = style.Window.HeaderPad * 2 + TAP + style.Window.BodyGap -- where the body starts with no warning strip
-- No X on this window: a trade ends with Cancel or Confirm, never by hiding it.
tradeWin.close.Visible = false

local windowHeader = tradeWin.header
local headerAvatarHolder = Instance.new("Frame")
headerAvatarHolder.LayoutOrder = 0
headerAvatarHolder.Size = UDim2.fromOffset(style.AvatarSize, style.AvatarSize)
headerAvatarHolder.BackgroundTransparency = 1
headerAvatarHolder.Parent = windowHeader
local windowTitle = tradeWin.title
windowTitle.Size = UDim2.new(1, -(style.AvatarSize + style.Window.HeaderGap), 1, 0)
windowTitle.AutomaticSize = Enum.AutomaticSize.None
windowTitle.TextWrapped = false
windowTitle.TextTruncate = Enum.TextTruncate.AtEnd

-- The below-market warning is a FIXED strip under the header (not inside the
-- scrolling list), so it can't scroll out of sight while Confirm is on screen.
local warningStrip = Instance.new("Frame")
warningStrip.Position = UDim2.fromOffset(10, HEADER_BOTTOM)
warningStrip.Size = UDim2.new(1, -20, 0, style.WarningStripHeight)
warningStrip.BackgroundColor3 = Color3.fromRGB(64, 28, 30)
warningStrip.BorderSizePixel = 0
warningStrip.Visible = false
warningStrip.Parent = window
UiStyle.corner(warningStrip, style.CardCorner)
UiStyle.stroke(warningStrip, colors.Bad, 1)
UiStyle.padding(warningStrip, 6)
local warningText = UiStyle.label(warningStrip, "Warning: you're giving much more than you get, going by the buyer's prices.", style.TextSize.Small, colors.Bad, true)
warningText.Size = UDim2.fromScale(1, 1)
warningText.AutomaticSize = Enum.AutomaticSize.None
warningText.TextTruncate = Enum.TextTruncate.AtEnd

local windowBody = tradeWin.content

local footer = Instance.new("Frame")
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.new(0, 14, 1, -12)
footer.BackgroundTransparency = 1
footer.Parent = window
UiStyle.list(footer, false, 6)
local statusLabel = UiStyle.label(footer, "", style.TextSize.Small, colors.TextDim, false)
statusLabel.LayoutOrder = 1
statusLabel.Size = UDim2.new(1, 0, 0, 30)
statusLabel.AutomaticSize = Enum.AutomaticSize.None
local lockBar = UiStyle.bar(footer, 8, 1, colors.Good)
lockBar.LayoutOrder = 2
local footerButtons = UiStyle.row(footer, TAP, 3)
local confirmButton = UiStyle.button(footerButtons, "Confirm", "primary", 0, TAP)
confirmButton.Size = UDim2.new(0.6, -4, 1, 0)
local cancelButton = UiStyle.button(footerButtons, "Cancel trade", "danger", 0, TAP)
cancelButton.Size = UDim2.new(0.4, -4, 1, 0)

local renderWindow: () -> ()

-- Sizes the body and footer from the window's height and whether the warning
-- strip is up. On a short window (phone landscape) the footer drops its status
-- line (the CONFIRMED tags and the Confirm button already say the same thing),
-- so the list keeps room.
local shortWindow = false
local function layoutWindow()
	shortWindow = window.AbsoluteSize.Y > 0 and window.AbsoluteSize.Y < style.ShortWindowHeight
	statusLabel.Visible = not shortWindow
	local footerHeight = 8 + 6 + TAP + (if shortWindow then 0 else 30 + 6)
	footer.Size = UDim2.new(1, -28, 0, footerHeight)
	local warning = warningStrip.Visible
	local bodyTop = HEADER_BOTTOM + (if warning then style.WarningStripHeight + 6 else 0)
	local bodyPos = UDim2.fromOffset(10, bodyTop)
	local bodySize = UDim2.new(1, -20, 1, -(bodyTop + footerHeight + 12 + 6))
	windowBody.Position = bodyPos
	windowBody.Size = bodySize
	tradeWin.well.Position = bodyPos
	tradeWin.well.Size = bodySize
end
layoutWindow()

-- What you hold that can be offered, as { kind, id, grade?, have, label }.
type Holding = { kind: string, id: string, grade: string?, have: number, label: string }
local function holdings(): { Holding }
	local list: { Holding } = {}
	local v = vault
	if v then
		for _, resource in Config.Resources.Types do
			for _, grade in Config.Grade.Names do
				local have = ((v.Banked[resource] or {})[grade] or 0) + ((v.Exposed[resource] or {})[grade] or 0)
				if have > 0 then
					table.insert(list, { kind = "Resource", id = resource, grade = grade, have = have, label = `{resource} ({grade})` })
				end
			end
		end
	end
	local g = gear
	if g then
		for _, id in tradeCfg.TradeableItems do
			local have = (g.Items or {})[id] or 0
			if have > 0 then
				table.insert(list, { kind = "Item", id = id, have = have, label = itemName(id) })
			end
		end
		local skins: { [string]: number } = g.Skins or {}
		for id, have in skins do
			if have > 0 then
				table.insert(list, { kind = "Skin", id = id, have = have, label = `{skinName(id)} skin` })
			end
		end
	end
	return list
end

local function offeredAmount(offer: Types.TradeOffer, kind: string, id: string, grade: string?): number
	for _, line in offer.Lines do
		if line.Kind == kind and line.Id == id and line.Grade == grade then
			return line.Amount
		end
	end
	return 0
end

local function setLine(kind: string, id: string, grade: string?, amount: number)
	ask("TradeSetOffer", kind, id, grade or "", amount)
end

local lastWide = false
local headerAvatarFor = "" -- whose avatar the header currently shows

-- One thing you can offer: an item row (Grade stripe, name, "You have N ·
-- Offering M") with its -/+ buttons on the right. A row that is already in the
-- offer gets a green outline. A greyed button can't do anything right now.
type Step = { text: string, width: number, off: boolean, run: () -> () }
local function pickerRow(parent: Instance, order: number, title: string, titleColor: Color3, stripe: Color3?, have: number, offered: number, steps: { Step })
	local row = UiStyle.itemRow(parent, title, `You have {money(have)} · Offering {money(offered)}`, order, false, stripe)
	row.title.TextColor3 = titleColor
	if offered > 0 then
		local stroke = row.root:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = colors.Good
			stroke.Thickness = 2
		end
	end
	for index, step in steps do
		local button = UiStyle.button(row.trailing, step.text, if step.off then "disabled" else "chip", step.width, TAP)
		button.LayoutOrder = index
		button.Activated:Connect(step.run)
	end
end

-- One side of the trade: a titled card listing exactly what that side gives.
-- `mine` = your side (lines get a Remove button); otherwise read-only.
local function sideCard(parent: Instance, order: number, wide: boolean, heading: string, headingColor: Color3, offer: Types.TradeOffer, confirmed: boolean, mine: boolean)
	local card = UiStyle.card(parent, order)
	card.Size = if wide then UDim2.new(0.5, -4, 0, 0) else UDim2.new(1, 0, 0, 0)

	local head = UiStyle.row(card, 26, 1)
	local title = UiStyle.label(head, heading, style.TextSize.Body, headingColor, true)
	title.Size = UDim2.new(1, if confirmed then -116 else 0, 1, 0)
	title.AutomaticSize = Enum.AutomaticSize.None
	title.TextWrapped = false
	title.TextTruncate = Enum.TextTruncate.AtEnd
	if confirmed then
		local pill = UiStyle.pill(head, "CONFIRMED", Color3.fromRGB(12, 40, 24), colors.Good)
		pill.LayoutOrder = 2
	end

	local lineOrder = 1
	if offer.Credits == 0 and #offer.Lines == 0 then
		lineOrder += 1
		UiStyle.label(card, if mine then "Nothing yet: add from the list below." else "Nothing yet.", style.TextSize.Small, colors.TextDim, false).LayoutOrder = lineOrder
	end
	local function itemRow(text: string, color: Color3, remove: (() -> ())?)
		lineOrder += 1
		local row = UiStyle.row(card, if remove then TAP else 28, lineOrder)
		local label = UiStyle.label(row, text, style.TextSize.Body, color, true)
		label.Size = UDim2.new(1, if remove then -90 else 0, 1, 0)
		label.AutomaticSize = Enum.AutomaticSize.None
		label.TextWrapped = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
		if remove then
			local button = UiStyle.button(row, "Remove", "chip", 84, TAP)
			button.Activated:Connect(remove)
		end
	end
	if offer.Credits > 0 then
		itemRow(`{money(offer.Credits)} Credits`, colors.Accent, if mine then function()
			ask("TradeSetCredits", 0)
		end else nil)
	end
	for _, line in offer.Lines do
		local color = if line.Kind == "Resource" and line.Grade then UiStyle.gradeColor(line.Grade) else colors.Text
		itemRow(lineText(line), color, if mine then function()
			setLine(line.Kind, line.Id, line.Grade, 0)
		end else nil)
	end
end

renderWindow = function()
	local v = view
	if not v then
		return
	end
	clear(windowBody)
	windowTitle.Text = `Trading with {v.TheirName}`
	if headerAvatarFor ~= v.TheirName then
		headerAvatarFor = v.TheirName
		clear(headerAvatarHolder)
		avatar(headerAvatarHolder, userIdOfName(v.TheirName), v.TheirName, style.AvatarSize)
	end
	warningStrip.Visible = v.BelowMarket
	layoutWindow()

	local wide = window.AbsoluteSize.X >= style.WideBreakpoint
	lastWide = wide
	local order = 0

	-- The two offers, side by side on wide screens, stacked on phones.
	order += 1
	local sides = Instance.new("Frame")
	sides.LayoutOrder = order
	sides.Size = UDim2.new(1, 0, 0, 0)
	sides.AutomaticSize = Enum.AutomaticSize.Y
	sides.BackgroundTransparency = 1
	sides.Parent = windowBody
	local sidesLayout = UiStyle.list(sides, wide, style.Gap)
	sidesLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	sideCard(sides, 1, wide, "YOU GIVE", ui.Colors.Give, v.Yours, v.YouConfirmed, true)
	sideCard(sides, 2, wide, `YOU GET (from {v.TheirName})`, ui.Colors.Get, v.Theirs, v.TheyConfirmed, false)

	-- Add from your stuff, grouped: Credits / Resources / Items / Skins. Each row
	-- says what you have and how much of it is already in the offer.
	local function nextPick(): number
		order += 1
		return order
	end
	local creditsOffered = v.Yours.Credits
	local held = holdings()
	local buckets: { [string]: { Holding } } = { Resource = {}, Item = {}, Skin = {} }
	for _, h in held do
		table.insert(buckets[h.kind], h)
	end
	local anythingToOffer = credits > 0 or #held > 0

	if credits > 0 then
		UiStyle.sectionHeader(windowBody, "Credits", nextPick(), nil, if creditsOffered > 0 then `{money(creditsOffered)} in offer` else nil)
		pickerRow(windowBody, nextPick(), "Credits", colors.Accent, nil, credits, creditsOffered, {
			{ text = "-100", width = 60, off = creditsOffered <= 0, run = function() ask("TradeSetCredits", math.max(0, creditsOffered - 100)) end },
			{ text = "+100", width = 60, off = creditsOffered >= credits, run = function() ask("TradeSetCredits", math.min(credits, creditsOffered + 100)) end },
			{ text = "+1,000", width = 72, off = creditsOffered >= credits, run = function() ask("TradeSetCredits", math.min(credits, creditsOffered + 1000)) end },
			{ text = "All", width = 56, off = creditsOffered >= credits, run = function() ask("TradeSetCredits", credits) end },
		})
	end
	for _, group in { { kind = "Resource", heading = "Resources" }, { kind = "Item", heading = "Items" }, { kind = "Skin", heading = "Skins" } } do
		local list = buckets[group.kind]
		if #list == 0 then
			continue
		end
		local inOffer = 0
		for _, line in v.Yours.Lines do
			if line.Kind == group.kind then
				inOffer += 1
			end
		end
		UiStyle.sectionHeader(windowBody, group.heading, nextPick(), nil, if inOffer > 0 then `{inOffer} in offer` else nil)
		for _, h in list do
			local offered = offeredAmount(v.Yours, h.kind, h.id, h.grade)
			local isGrade = h.kind == "Resource" and h.grade ~= nil
			local color = if isGrade then UiStyle.gradeColor(h.grade :: string) else colors.Text
			local steps: { Step } = {
				{ text = "-1", width = 48, off = offered <= 0, run = function() setLine(h.kind, h.id, h.grade, math.max(0, offered - 1)) end },
				{ text = "+1", width = 48, off = offered >= h.have, run = function() setLine(h.kind, h.id, h.grade, math.min(h.have, offered + 1)) end },
			}
			if h.have > 10 then
				table.insert(steps, { text = "+10", width = 52, off = offered >= h.have, run = function() setLine(h.kind, h.id, h.grade, math.min(h.have, offered + 10)) end })
			end
			table.insert(steps, { text = "All", width = 56, off = offered >= h.have, run = function() setLine(h.kind, h.id, h.grade, h.have) end })
			pickerRow(windowBody, nextPick(), h.label, color, if isGrade then color else nil, h.have, offered, steps)
		end
	end
	if not anythingToOffer then
		UiStyle.emptyState(windowBody, "Nothing to offer yet", "Mine something, then come back.", nextPick())
	end
	UiStyle.label(windowBody, "Resources come from your at-risk pile first, then your bank. Everything you get lands at risk until you bank it.", style.TextSize.Small, colors.TextDim, false).LayoutOrder = nextPick()
end

-- Status text, lock bar and Confirm button, refreshed every FooterRefreshSeconds.
local function refreshFooter()
	local v = view
	if not v then
		return
	end
	local left = math.max(0, v.LockEndsAt - workspace:GetServerTimeNow())
	statusLabel.TextColor3 = if v.BelowMarket then colors.Bad else colors.TextDim
	if v.YouConfirmed then
		statusLabel.Text = `You confirmed. Waiting for {v.TheirName}...`
	elseif v.TheyConfirmed then
		statusLabel.Text = `{v.TheirName} has confirmed. Check both lists, then Confirm.`
	elseif left > 0 then
		statusLabel.Text = "The offer changed: wait for the lock, then check both lists."
	else
		statusLabel.Text = "Check both lists. Confirm when you're happy."
	end

	-- The lock bar fills as the 5 seconds run out, amber while locked, green when ready.
	local locked = left > 0 and not v.YouConfirmed
	UiStyle.setBar(lockBar, if locked then 1 - left / tradeCfg.ConfirmLockSeconds else 1, if locked then colors.Warn else colors.Good)

	if v.YouConfirmed then
		confirmButton.Text = "Confirmed"
		UiStyle.setButtonKind(confirmButton, "disabled")
	elseif left > 0 then
		confirmButton.Text = `Confirm ({math.ceil(left)})`
		UiStyle.setButtonKind(confirmButton, "disabled")
	else
		confirmButton.Text = "Confirm"
		UiStyle.setButtonKind(confirmButton, "primary")
	end
end

confirmButton.Activated:Connect(function()
	local v = view
	if v and not v.YouConfirmed then
		ask("TradeConfirm", v.Version)
	end
end)
cancelButton.Activated:Connect(function()
	ask("TradeCancel")
end)

-- Switching between the phone and wide layouts (rotate, resize) re-lays it out.
window:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if not window.Visible then
		return
	end
	layoutWindow()
	if view and (window.AbsoluteSize.X >= style.WideBreakpoint) ~= lastWide then
		renderWindow()
	end
end)

-- The receipt after a completed trade: what you gave and what you got, in the
-- same colours as the trade window, until you tap OK (a toast was easy to miss).
local receipt = UiStyle.card(windowGui, 0)
receipt.AnchorPoint = Vector2.new(0.5, 0.5)
receipt.Position = UDim2.fromScale(0.5, 0.5)
receipt.Size = UDim2.new(0.8, 0, 0, 0)
receipt.BackgroundColor3 = colors.Panel
receipt.Visible = false
receipt.ZIndex = 12
local receiptLimit = Instance.new("UISizeConstraint")
receiptLimit.MaxSize = Vector2.new(380, math.huge)
receiptLimit.Parent = receipt

local function offerLines(parent: Instance, order: number, heading: string, headingColor: Color3, offer: Types.TradeOffer): number
	UiStyle.sectionHeader(parent, heading, order, headingColor)
	local n = order
	local function line(text: string, color: Color3)
		n += 1
		UiStyle.label(parent, text, style.TextSize.Body, color, true).LayoutOrder = n
	end
	if offer.Credits > 0 then
		line(`{money(offer.Credits)} Credits`, colors.Accent)
	end
	for _, entry in offer.Lines do
		line(lineText(entry), if entry.Kind == "Resource" and entry.Grade then UiStyle.gradeColor(entry.Grade) else colors.Text)
	end
	if n == order then
		line("nothing", colors.TextDim)
	end
	return n
end

local function showReceipt(text: string, gave: Types.TradeOffer?, got: Types.TradeOffer)
	clear(receipt)
	local head = UiStyle.label(receipt, text, style.TextSize.Title, colors.Good, true)
	head.LayoutOrder = 1
	local n = 1
	if gave then
		n = offerLines(receipt, n + 1, "YOU GAVE", ui.Colors.Give, gave)
	end
	n = offerLines(receipt, n + 1, "YOU GOT", ui.Colors.Get, got)
	local ok = UiStyle.button(receipt, "OK", "primary", 0, TAP)
	ok.Size = UDim2.new(1, 0, 0, TAP)
	ok.LayoutOrder = n + 1
	ok.Activated:Connect(function()
		receipt.Visible = false
	end)
	receipt.Visible = true
end

Remotes.getEvent("TradeState").OnClientEvent:Connect(function(state: Types.TradeView?, text: string?, received: Types.TradeOffer?)
	local finished = view -- the last offers you saw: what you gave
	view = state
	if state then
		nearbyPanel.Visible = false
		invitePanel.Visible = false
		receipt.Visible = false
		window.Visible = true
		renderWindow()
		refreshFooter()
		if not vault or not gear then
			task.spawn(function()
				if ensureData() and view then
					renderWindow()
				end
			end)
		end
	else
		window.Visible = false
		headerAvatarFor = ""
		warningStrip.Visible = false
		if text and received then
			showReceipt(text, if finished then finished.Yours else nil, received)
		elseif text then
			showToast(text)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(ui.FooterRefreshSeconds)
		if window.Visible then
			refreshFooter()
		end
	end
end)

-- ── Data + the HUD button ────────────────────────────────────────────────

Remotes.getEvent("VaultChanged").OnClientEvent:Connect(function(state: Types.VaultState)
	vault = state
	if window.Visible then
		renderWindow()
	end
end)
Remotes.getEvent("GearChanged").OnClientEvent:Connect(function(state: Types.GearState)
	gear = state
	if window.Visible then
		renderWindow()
	end
end)
Remotes.getEvent("CreditsChanged").OnClientEvent:Connect(function(amount: number)
	credits = amount
	if window.Visible then
		renderWindow()
	end
end)

local function applyButton()
	-- R4: the Trade button doesn't exist until Level 10 (and the FTUE lets it show).
	local unlocked = reputation ~= nil and reputation.TradeUnlocked
	tradeButton.Visible = unlocked and player:GetAttribute(ui.VisibleAttribute) == true
	if not tradeButton.Visible then
		nearbyPanel.Visible = false
	end
end
Remotes.getEvent("ReputationChanged").OnClientEvent:Connect(function(state: Types.ReputationState)
	reputation = state
	applyButton()
end)
player:GetAttributeChangedSignal(ui.VisibleAttribute):Connect(applyButton)

tradeButton.Activated:Connect(function()
	if view then
		window.Visible = true
		layoutWindow()
		return
	end
	nearbyPanel.Visible = not nearbyPanel.Visible
	if nearbyPanel.Visible then
		renderNearby()
	end
end)
nearbyClose.Activated:Connect(function()
	nearbyPanel.Visible = false
end)
nearbyRefresh.Activated:Connect(function()
	renderNearby()
end)

windowGui.Parent = playerGui

-- Start-up snapshots, in case the pushes were missed (rate limited: once).
task.spawn(function()
	local okProgress, gotCredits, gotState = pcall(function()
		return Remotes.getFunction("GetProgressState"):InvokeServer()
	end)
	if okProgress and gotState then
		credits = gotCredits or 0
		reputation = gotState
		applyButton()
	end
	ensureData()
end)
