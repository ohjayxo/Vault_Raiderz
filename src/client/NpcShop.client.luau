--!strict
-- The NPC buyer's Sell panel (06-economy.md § Two tiers of selling, § NPC
-- price decay D94). Opens when you use the buyer's "Sell" prompt (the server
-- fires OpenNpcShop after checking you're close).
--
-- Display and intents only: every price and count comes from the server
-- (GetSellQuote / SellUnits, R5). Tapping Sell sends "this resource, this
-- Grade, this many"; the server decides what actually sells and for how much.
-- Look: Shared/UiStyle (Config.UiStyle, look only). One card per resource
-- with a price bar (today's price as a share of full), one block per Grade.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))
local UiStyle = require(Shared:WaitForChild("UiStyle"))

local player = Players.LocalPlayer
local cfg = Config.NpcSelling
local ui = cfg.Ui
local style = Config.UiStyle
local colors = style.Colors
local money = UiStyle.money

local REASON_TEXT: { [string]: string } = {
	Busy = "Too fast",
	Invalid = "Can't do that",
	TooFar = "Walk closer to the buyer",
	NothingToSell = "You have none of that",
	TooCheap = "The price has dropped too low for that many today",
	Failed = "Something went wrong, try again",
}

local quote: Types.SellQuote? = nil
local credits: number? = nil
local busy = false

-- ── Window shell ─────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "NpcShop"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- children always draw above their parent
gui.DisplayOrder = ui.DisplayOrder

local panel = UiStyle.panel(gui, 0.92, 0.88, ui.PanelMaxSize)

-- Header: title, Credits pill, close button.
local header = Instance.new("Frame")
header.Position = UDim2.fromOffset(12, 10)
header.Size = UDim2.new(1, -24 - style.MinTap - 8, 0, style.MinTap)
header.BackgroundTransparency = 1
header.Parent = panel
UiStyle.list(header, true, 10)
local title = UiStyle.title(header, "Buyer")
title.AutomaticSize = Enum.AutomaticSize.XY
title.Size = UDim2.fromOffset(0, 0)
title.LayoutOrder = 1
local creditsPill = UiStyle.pill(header, "Credits 0", colors.Accent)
creditsPill.LayoutOrder = 2
-- The close button sits in the corner, outside the header row, so a narrow
-- phone screen can never push it off the panel.
local closeButton = UiStyle.button(panel, "X", "neutral", style.MinTap, style.MinTap)
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 10)

local content = UiStyle.scroller(panel, UDim2.fromOffset(10, 10 + style.MinTap + 8), UDim2.new(1, -20, 1, -(10 + style.MinTap + 8 + 10)))

-- A short message that fades away (the sale result or a refusal).
local message = UiStyle.pill(panel, "", colors.Text, Color3.new(0, 0, 0))
message.AnchorPoint = Vector2.new(0.5, 1)
message.Position = UDim2.new(0.5, 0, 1, -12)
message.Visible = false
message.ZIndex = 5
message.TextWrapped = true
message.TextSize = style.TextSize.Body
local messageLimit = Instance.new("UISizeConstraint")
messageLimit.MaxSize = Vector2.new(300, math.huge)
messageLimit.Parent = message

gui.Parent = player:WaitForChild("PlayerGui")

local messageToken = 0
local function showMessage(text: string, good: boolean)
	messageToken += 1
	local token = messageToken
	message.Text = text
	message.TextColor3 = if good then colors.Good else colors.Warn
	message.Visible = true
	task.delay(ui.MessageSeconds, function()
		if messageToken == token then
			message.Visible = false
		end
	end)
end

-- ── Selling ──────────────────────────────────────────────────────────────

local render: () -> ()

local function sell(resource: string, grade: string, count: number)
	if busy then
		return
	end
	busy = true
	local ok, accepted, reason, earned, newQuote = pcall(function()
		return Remotes.getFunction("SellUnits"):InvokeServer(resource, grade, count)
	end)
	busy = false
	if not ok then
		showMessage(REASON_TEXT.Failed, false)
	elseif not accepted then
		showMessage(REASON_TEXT[reason] or REASON_TEXT.Failed, false)
	else
		showMessage(`Sold for {money(earned or 0)} Credits`, true)
	end
	if ok and newQuote then
		quote = newQuote
	end
	render()
end

-- One Grade you hold: name + count + price on top, sell chips underneath.
local function gradeBlock(parent: Instance, order: number, resource: string, grade: string, have: number, price: number)
	local block = Instance.new("Frame")
	block.LayoutOrder = order
	block.Size = UDim2.new(1, 0, 0, 0)
	block.AutomaticSize = Enum.AutomaticSize.Y
	block.BackgroundTransparency = 1
	block.Parent = parent
	UiStyle.list(block, false, 4)

	local top = UiStyle.row(block, 22, 1)
	local name = UiStyle.label(top, grade, style.TextSize.Body, UiStyle.gradeColor(grade), true)
	name.Size = UDim2.new(0.3, 0, 1, 0)
	name.AutomaticSize = Enum.AutomaticSize.None
	local count = UiStyle.label(top, `You have {money(have)}`, style.TextSize.Body, colors.Text, true)
	count.Size = UDim2.new(0.42, 0, 1, 0)
	count.AutomaticSize = Enum.AutomaticSize.None
	local each = UiStyle.label(top, `{price} each`, style.TextSize.Body, colors.Accent, true)
	each.Size = UDim2.new(0.28, -12, 1, 0)
	each.AutomaticSize = Enum.AutomaticSize.None
	each.TextXAlignment = Enum.TextXAlignment.Right

	-- Chips: "Sell 1", "Sell 10" (only if it isn't just "All"), "All".
	local amounts: { { text: string, amount: number } } = { { text = "Sell 1", amount = 1 } }
	if have > 10 then
		table.insert(amounts, { text = "Sell 10", amount = 10 })
	end
	if have > 1 then
		table.insert(amounts, { text = `All ({money(have)})`, amount = have })
	end
	local chips = UiStyle.row(block, style.MinTap, 2)
	for _, entry in amounts do
		local chip = UiStyle.button(chips, entry.text, "chip", 0, style.MinTap)
		chip.Size = UDim2.new(1 / #amounts, -6, 1, 0)
		chip.Activated:Connect(function()
			sell(resource, grade, entry.amount)
		end)
	end
end

render = function()
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	creditsPill.Text = `Credits {money(credits or 0)}`
	local q = quote
	if not q then
		local loading = UiStyle.label(content, "Loading prices...", style.TextSize.Body, colors.TextDim, false)
		loading.LayoutOrder = 1
		return
	end

	local order = 0
	local anything = false
	for _, resource in Config.Resources.Types do
		local data = q.Resources[resource]
		if not data then
			continue
		end
		local haveAny = false
		for _, grade in Config.Grade.Names do
			local entry = data.Grades[grade]
			if entry and entry.Have > 0 then
				haveAny = true
			end
		end
		if not haveAny then
			continue
		end
		anything = true

		order += 1
		local card = UiStyle.card(content, order)
		local headRow = UiStyle.row(card, 24, 1)
		local resourceName = UiStyle.label(headRow, resource, style.TextSize.Title, colors.Text, true)
		resourceName.Size = UDim2.new(0.5, 0, 1, 0)
		resourceName.AutomaticSize = Enum.AutomaticSize.None
		local percent = UiStyle.label(headRow, `Today: {data.Percent}%`, style.TextSize.Body, UiStyle.priceColor(data.Percent / 100), true)
		percent.Size = UDim2.new(0.5, -6, 1, 0)
		percent.AutomaticSize = Enum.AutomaticSize.None
		percent.TextXAlignment = Enum.TextXAlignment.Right
		local bar = UiStyle.bar(card, style.PriceBar.Height, data.Percent / 100, UiStyle.priceColor(data.Percent / 100))
		bar.LayoutOrder = 2

		local gradeOrder = 2
		for _, grade in Config.Grade.Names do
			local entry = data.Grades[grade]
			if entry and entry.Have > 0 then
				gradeOrder += 1
				gradeBlock(card, gradeOrder, resource, grade, entry.Have, entry.Price)
			end
		end
	end

	if not anything then
		order += 1
		local empty = UiStyle.card(content, order)
		UiStyle.label(empty, "Nothing to sell yet", style.TextSize.Title, colors.Text, true).LayoutOrder = 1
		UiStyle.label(empty, "Mine some Stone or Ore, then come back.", style.TextSize.Body, colors.TextDim, false).LayoutOrder = 2
	end
	order += 1
	local note = UiStyle.label(content, "Sells from your at-risk pile first, then your bank. Prices drop as you sell and reset each day.", style.TextSize.Small, colors.TextDim, false)
	note.LayoutOrder = order
end

-- ── Opening / closing ────────────────────────────────────────────────────

local function nearestBuyerDistance(): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return math.huge
	end
	local best = math.huge
	for _, model in CollectionService:GetTagged(cfg.BuyerTag) do
		local hitbox = model:FindFirstChild("Hitbox")
		if hitbox and hitbox:IsA("BasePart") then
			best = math.min(best, (hitbox.Position - root.Position).Magnitude)
		end
	end
	return best
end

local function close()
	panel.Visible = false
end

local function open()
	panel.Visible = true
	render()
	task.spawn(function()
		local ok, result = pcall(function()
			return Remotes.getFunction("GetSellQuote"):InvokeServer()
		end)
		if ok and result then
			quote = result
		end
		if credits == nil then
			local okCredits, gotCredits = pcall(function()
				return Remotes.getFunction("GetProgressState"):InvokeServer()
			end)
			if okCredits and gotCredits then
				credits = gotCredits
			end
		end
		render()
	end)
end

closeButton.Activated:Connect(close)
Remotes.getEvent("OpenNpcShop").OnClientEvent:Connect(open)
Remotes.getEvent("CreditsChanged").OnClientEvent:Connect(function(amount: number)
	credits = amount
	if panel.Visible then
		render()
	end
end)

-- Walk away and the panel closes (the server would refuse the sale anyway).
task.spawn(function()
	while true do
		task.wait(ui.CloseCheckSeconds)
		if panel.Visible and nearestBuyerDistance() > ui.CloseDistanceStuds then
			close()
		end
	end
end)
