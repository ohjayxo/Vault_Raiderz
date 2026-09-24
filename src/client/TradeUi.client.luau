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
-- trusts. Greybox UI: one scrolling column so it fits a phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))

local player = Players.LocalPlayer
local tradeCfg = Config.Trade
local ui = tradeCfg.Ui
local ROW = ui.RowHeight
local SIZE = Config.Combat.Ui.ButtonSize
local NOTE = Color3.fromRGB(170, 170, 190)
local GIVE = ui.Colors.Give
local GET = ui.Colors.Get
local WARN = ui.Colors.Warn

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

-- ── UI shell (greybox) ───────────────────────────────────────────────────

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

local function makePanel(gui: ScreenGui, widthScale: number, heightScale: number, maxSize: Vector2?): Frame
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(widthScale, heightScale)
	panel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	if maxSize then
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = maxSize
		limit.Parent = panel
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	return panel
end

local function makeList(parent: Frame, position: UDim2, size: UDim2): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Position = position
	list.Size = size
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end

local function makeLabel(parent: Instance, text: string, size: UDim2, position: UDim2?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	if position then
		l.Position = position
	end
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

local windowGui = Instance.new("ScreenGui")
windowGui.Name = "TradeWindow"
windowGui.ResetOnSpawn = false
windowGui.DisplayOrder = ui.DisplayOrder

local buttonGui = Instance.new("ScreenGui")
buttonGui.Name = "TradeButton"
buttonGui.ResetOnSpawn = false
buttonGui.DisplayOrder = Config.Inventory.ButtonDisplayOrder

-- HUD button under the Raids button (RaidUi puts Raids at 12, 170).
local tradeButton = makeButton(buttonGui, ui.ButtonLabel, SIZE * 1.2, SIZE * 0.5)
tradeButton.Position = UDim2.fromOffset(12, 170 + SIZE * 0.5 + 8)
tradeButton.Visible = false

-- Toast for short messages (declines, timeouts, "Trade complete!"), always on screen.
local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 60)
toast.Size = UDim2.fromOffset(380, 32)
toast.BackgroundColor3 = Color3.new(0, 0, 0)
toast.BackgroundTransparency = 0.2
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Font = Enum.Font.GothamBold
toast.TextSize = 14
toast.TextWrapped = true
toast.Visible = false
toast.ZIndex = 20
toast.Parent = windowGui

local toastToken = 0
local function showToast(text: string)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.Visible = true
	task.delay(ui.MessageSeconds, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

-- ── Nearby list + history ────────────────────────────────────────────────

local nearbyPanel = makePanel(windowGui, 0.8, 0.8, ui.NearbyPanelMaxSize)
local nearbyTitle = makeLabel(nearbyPanel, "Trade with a nearby player", UDim2.new(1, -60, 0, 34), UDim2.fromOffset(12, 8))
nearbyTitle.TextSize = 16
local nearbyClose = makeButton(nearbyPanel, "X", 34, 34)
nearbyClose.AnchorPoint = Vector2.new(1, 0)
nearbyClose.Position = UDim2.new(1, -8, 0, 8)
local nearbyList = makeList(nearbyPanel, UDim2.fromOffset(8, 50), UDim2.new(1, -16, 1, -58))

local function money(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

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

local function clear(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- One row: text cells then buttons. Returns the row frame.
type Cell = { text: string, width: number, color: Color3? }
type Action = { text: string, width: number, run: () -> () }
local function addRow(list: ScrollingFrame, order: number, cells: { Cell }, actions: { Action }?): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, ROW)
	frame.BackgroundTransparency = 1
	frame.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	for i, cell in cells do
		local l = makeLabel(frame, cell.text, UDim2.fromOffset(cell.width, ROW))
		l.LayoutOrder = i
		l.TextWrapped = false
		l.TextColor3 = cell.color or Color3.new(1, 1, 1)
	end
	local buttons: { Action } = actions or {}
	for i, action in buttons do
		local b = makeButton(frame, action.text, action.width, ROW - 4)
		b.LayoutOrder = #cells + i
		b.Activated:Connect(action.run)
	end
	return frame
end

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
		showToast(REASON_TEXT[reason] or REASON_TEXT.Failed)
		return false, reason
	end
	return true, nil
end

local renderNearby: () -> ()

renderNearby = function()
	clear(nearbyList)
	addRow(nearbyList, 1, { { text = "Walk close to a player who has reached Level 10, then tap Invite.", width = 420, color = NOTE } })
	local order = 1
	local ok, list = pcall(function()
		return Remotes.getFunction("GetNearbyTraders"):InvokeServer()
	end)
	local people: { { UserId: number, Name: string } } = if ok and type(list) == "table" then list else {}
	if #people == 0 then
		order += 1
		addRow(nearbyList, order, { { text = "Nobody nearby can trade right now.", width = 420 } })
	end
	for _, person in people do
		order += 1
		addRow(nearbyList, order, { { text = person.Name, width = 250 } }, {
			{
				text = "Invite",
				width = 90,
				run = function()
					if ask("TradeInvite", person.UserId) then
						showToast(`Invite sent to {person.Name}`)
						nearbyPanel.Visible = false
					end
				end,
			},
		})
	end
	order += 1
	addRow(nearbyList, order, { { text = "", width = 4 } }, {
		{ text = "Refresh", width = 100, run = function() renderNearby() end },
	})

	-- 06 § Trade Safety: your saved trade history (newest first).
	order += 1
	addRow(nearbyList, order, { { text = "RECENT TRADES", width = 300, color = NOTE } })
	local okHistory, history = pcall(function()
		return Remotes.getFunction("GetTradeHistory"):InvokeServer()
	end)
	local records: { Types.TradeRecord } = if okHistory and type(history) == "table" then history else {}
	if #records == 0 then
		order += 1
		addRow(nearbyList, order, { { text = "none yet", width = 300, color = NOTE } })
	end
	for i, record in records do
		if i > ui.HistoryRowsShown then
			break
		end
		order += 1
		local when = os.date("!%m/%d %H:%M", record.At)
		local frame = addRow(nearbyList, order, { { text = `{when} UTC  with {record.WithName}: gave {offerText(record.Gave)}; got {offerText(record.Got)}`, width = 400, color = NOTE } })
		local text = frame:FindFirstChildOfClass("TextLabel")
		if text then
			text.TextWrapped = true
			text.Size = UDim2.new(1, -8, 0, ROW * 2)
			frame.Size = UDim2.new(1, -8, 0, ROW * 2)
		end
	end
end

-- ── Invite popup ─────────────────────────────────────────────────────────

local invitePanel = Instance.new("Frame")
invitePanel.AnchorPoint = Vector2.new(0.5, 0)
invitePanel.Position = UDim2.new(0.5, 0, 0, 100)
invitePanel.Size = UDim2.fromOffset(340, 96)
invitePanel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
invitePanel.BackgroundTransparency = 0.05
invitePanel.Visible = false
invitePanel.Parent = windowGui
local inviteCorner = Instance.new("UICorner")
inviteCorner.CornerRadius = UDim.new(0, 10)
inviteCorner.Parent = invitePanel
local inviteText = makeLabel(invitePanel, "", UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 6))
local acceptButton = makeButton(invitePanel, "Accept", 150, 38)
acceptButton.Position = UDim2.fromOffset(8, 50)
acceptButton.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
local declineButton = makeButton(invitePanel, "Decline", 150, 38)
declineButton.Position = UDim2.fromOffset(182, 50)
declineButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)

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
	invitePanel.Visible = true
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

local window = makePanel(windowGui, 0.96, 0.94, ui.PanelMaxSize)
local windowTitle = makeLabel(window, "Trade", UDim2.new(1, -60, 0, 34), UDim2.fromOffset(12, 8))
windowTitle.TextSize = 16
local windowList = makeList(window, UDim2.fromOffset(8, 46), UDim2.new(1, -16, 1, -46 - 104))

local footer = Instance.new("Frame")
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.new(0, 8, 1, -8)
footer.Size = UDim2.new(1, -16, 0, 96)
footer.BackgroundTransparency = 1
footer.Parent = window
local statusLabel = makeLabel(footer, "", UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 0))
local confirmButton = makeButton(footer, "Confirm", 200, 44)
confirmButton.Position = UDim2.fromOffset(0, 50)
confirmButton.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
local cancelButton = makeButton(footer, "Cancel trade", 150, 44)
cancelButton.Position = UDim2.fromOffset(212, 50)
cancelButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)

local renderWindow: () -> ()

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

renderWindow = function()
	local v = view
	if not v then
		return
	end
	clear(windowList)
	windowTitle.Text = `Trading with {v.TheirName}`
	local order = 0
	local function add(cells: { Cell }, actions: { Action }?)
		order += 1
		return addRow(windowList, order, cells, actions)
	end

	-- What YOU give.
	add({ { text = "YOU GIVE", width = 300, color = GIVE } })
	if v.Yours.Credits == 0 and #v.Yours.Lines == 0 then
		add({ { text = "nothing yet: add from the list below", width = 420, color = NOTE } })
	end
	if v.Yours.Credits > 0 then
		add({ { text = `{money(v.Yours.Credits)} Credits`, width = 320, color = GIVE } }, {
			{ text = "Remove", width = 80, run = function() ask("TradeSetCredits", 0) end },
		})
	end
	for _, line in v.Yours.Lines do
		add({ { text = lineText(line), width = 320, color = GIVE } }, {
			{ text = "Remove", width = 80, run = function() setLine(line.Kind, line.Id, line.Grade, 0) end },
		})
	end

	-- What THEY give (read-only: the server sends exactly what will swap).
	add({ { text = `YOU GET (from {v.TheirName})`, width = 400, color = GET } })
	if v.Theirs.Credits == 0 and #v.Theirs.Lines == 0 then
		add({ { text = "nothing yet", width = 420, color = NOTE } })
	end
	if v.Theirs.Credits > 0 then
		add({ { text = `{money(v.Theirs.Credits)} Credits`, width = 420, color = GET } })
	end
	for _, line in v.Theirs.Lines do
		add({ { text = lineText(line), width = 420, color = GET } })
	end

	-- Add from your stuff.
	add({ { text = "ADD FROM YOUR STUFF", width = 300, color = NOTE } })
	local creditsOffered = v.Yours.Credits
	add({ { text = `Credits ({money(credits)})`, width = 190 } }, {
		{ text = "+100", width = 64, run = function() ask("TradeSetCredits", math.min(credits, creditsOffered + 100)) end },
		{ text = "+1,000", width = 72, run = function() ask("TradeSetCredits", math.min(credits, creditsOffered + 1000)) end },
		{ text = "All", width = 56, run = function() ask("TradeSetCredits", credits) end },
	})
	for _, h in holdings() do
		local offered = offeredAmount(v.Yours, h.kind, h.id, h.grade)
		add({ { text = `{h.label}  x{money(h.have)}`, width = 250 } }, {
			{ text = "+1", width = 50, run = function() setLine(h.kind, h.id, h.grade, math.min(h.have, offered + 1)) end },
			{ text = "+10", width = 56, run = function() setLine(h.kind, h.id, h.grade, math.min(h.have, offered + 10)) end },
			{ text = "All", width = 56, run = function() setLine(h.kind, h.id, h.grade, h.have) end },
		})
	end
	add({ { text = "Resources come from your at-risk pile first, then your bank. Everything you get lands at risk until you bank it.", width = 560, color = NOTE } })
end

-- Status text + Confirm button, refreshed every 0.25 s for the lock countdown.
local function refreshFooter()
	local v = view
	if not v then
		return
	end
	local left = math.max(0, v.LockEndsAt - workspace:GetServerTimeNow())
	local lines: { string } = {}
	if v.BelowMarket then
		table.insert(lines, "WARNING: you're giving much more than you get, by the buyer's prices.")
		statusLabel.TextColor3 = WARN
	else
		statusLabel.TextColor3 = Color3.new(1, 1, 1)
	end
	if v.YouConfirmed then
		table.insert(lines, `You confirmed. Waiting for {v.TheirName}...`)
	elseif v.TheyConfirmed then
		table.insert(lines, `{v.TheirName} has confirmed. Check the lists, then Confirm.`)
	elseif left > 0 then
		table.insert(lines, "The offer changed: wait for the lock, then check both lists.")
	else
		table.insert(lines, "Check both lists. Confirm when you're happy.")
	end
	statusLabel.Text = table.concat(lines, "\n")

	if v.YouConfirmed then
		confirmButton.Text = "Confirmed"
		confirmButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	elseif left > 0 then
		confirmButton.Text = `Confirm ({math.ceil(left)})`
		confirmButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	else
		confirmButton.Text = "Confirm"
		confirmButton.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
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

Remotes.getEvent("TradeState").OnClientEvent:Connect(function(state: Types.TradeView?, text: string?)
	view = state
	if state then
		nearbyPanel.Visible = false
		invitePanel.Visible = false
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
		if text then
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

windowGui.Parent = player:WaitForChild("PlayerGui")
buttonGui.Parent = player:WaitForChild("PlayerGui")

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
