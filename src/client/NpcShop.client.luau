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
local resetAt: number? = nil -- os.clock() time the prices reset (from the quote's ResetsIn)
local credits: number? = nil
local busy = false
local noteLabel: TextLabel? = nil

-- ── Window shell ─────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "NpcShop"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- children always draw above their parent
gui.DisplayOrder = ui.DisplayOrder

-- The shared window frame (UiStyle.window): header strip with the title and the
-- Credits pill, red X in the corner, body in an inset well.
local win = UiStyle.window(gui, "Buyer", 0.92, 0.88, ui.PanelMaxSize)
local panel = win.panel
local content = win.content
local closeButton = win.close
local creditsPill = UiStyle.pill(win.header, "Credits 0", colors.Accent)
creditsPill.LayoutOrder = 2

-- The sale result or a refusal, at the bottom of the window.
local toast = UiStyle.toast(panel, true)

gui.Parent = player:WaitForChild("PlayerGui")

local function showMessage(text: string, good: boolean)
	toast.show(text, ui.MessageSeconds, if good then "good" else "warn")
end

-- "5h 12m" / "12m" / "under a minute": when the daily price decay resets (D94).
local function resetText(): string
	local at = resetAt
	if not at then
		return "prices reset daily"
	end
	local minutes = math.max(0, math.ceil((at - os.clock()) / 60))
	if minutes >= 60 then
		return `prices reset in {minutes // 60}h {minutes % 60}m`
	elseif minutes >= 1 then
		return `prices reset in {minutes}m`
	end
	return "prices reset in under a minute"
end

-- ── Selling ──────────────────────────────────────────────────────────────

local render: () -> ()

local function setQuote(newQuote: Types.SellQuote)
	quote = newQuote
	resetAt = os.clock() + newQuote.ResetsIn
end

local function sell(resource: string, grade: string, count: number)
	if busy then
		return
	end
	busy = true
	local ok, accepted, reason, earned, newQuote, sold = pcall(function()
		return Remotes.getFunction("SellUnits"):InvokeServer(resource, grade, count)
	end)
	busy = false
	if not ok then
		showMessage(REASON_TEXT.Failed, false)
	elseif not accepted then
		showMessage(REASON_TEXT[reason] or REASON_TEXT.Failed, false)
	else
		showMessage(`Sold {money(sold or 0)} {grade} {resource} for {money(earned or 0)} Credits`, true)
	end
	if ok and newQuote then
		setQuote(newQuote)
	end
	render()
end

-- One sell chip: the action on the first line, what it pays on the second. The
-- payout comes from the server's quote (decay included), never worked out here.
local function chipText(label: string, payoutCredits: number): string
	local second = if payoutCredits >= 1 then `{money(payoutCredits)} Credits` else "too cheap"
	return `{label}\n<font size="{style.TextSize.Small}" color="#{colors.Accent:ToHex()}">{second}</font>`
end

-- One Grade you hold: a row (Grade colour stripe, name, "You have N", price
-- each) with the sell chips underneath.
local function gradeBlock(parent: Instance, order: number, resource: string, grade: string, entry: { Have: number, Price: number, PayoutOne: number, PayoutTen: number, PayoutAll: number })
	local block = Instance.new("Frame")
	block.LayoutOrder = order
	block.Size = UDim2.new(1, 0, 0, 0)
	block.AutomaticSize = Enum.AutomaticSize.Y
	block.BackgroundTransparency = 1
	block.Parent = parent
	UiStyle.list(block, false, 4)

	local gradeColor = UiStyle.gradeColor(grade)
	local row = UiStyle.itemRow(block, grade, `You have {money(entry.Have)}`, 1, false, gradeColor)
	row.title.TextColor3 = gradeColor
	local each = UiStyle.label(row.trailing, `{entry.Price} each`, style.TextSize.Body, colors.Accent, true)
	each.AutomaticSize = Enum.AutomaticSize.XY
	each.Size = UDim2.fromOffset(0, 0)
	each.TextWrapped = false
	each.TextXAlignment = Enum.TextXAlignment.Right

	-- Chips: "Sell 1", "Sell 10" (only if it isn't just "All"), "All". The last
	-- chip is the green main action.
	local amounts: { { text: string, amount: number, credits: number } } = { { text = "Sell 1", amount = 1, credits = entry.PayoutOne } }
	if entry.Have > 10 then
		table.insert(amounts, { text = "Sell 10", amount = 10, credits = entry.PayoutTen })
	end
	if entry.Have > 1 then
		local allCount = math.min(entry.Have, cfg.MaxUnitsPerSale) -- one sale is capped, and PayoutAll is for that many
		table.insert(amounts, { text = `All ({money(allCount)})`, amount = allCount, credits = entry.PayoutAll })
	end
	local chips = UiStyle.row(block, style.MinTap, 2)
	for index, chipInfo in amounts do
		local kind: UiStyle.ButtonKind = if chipInfo.credits < 1 then "disabled" elseif index == #amounts then "primary" else "chip"
		local chip = UiStyle.button(chips, "", kind, 0, style.MinTap)
		chip.RichText = true
		chip.Text = chipText(chipInfo.text, chipInfo.credits)
		chip.Size = UDim2.new(1 / #amounts, -6, 1, 0)
		chip.Activated:Connect(function()
			sell(resource, grade, chipInfo.amount)
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

	-- The rule of the shop, up top where it is seen (the countdown is refreshed by the loop below).
	local note = UiStyle.label(content, `At-risk pile sells first · {resetText()}`, style.TextSize.Small, colors.TextDim, false)
	note.LayoutOrder = 0
	noteLabel = note

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
				gradeBlock(card, gradeOrder, resource, grade, entry)
			end
		end
	end

	if not anything then
		order += 1
		UiStyle.emptyState(content, "Nothing to sell yet", "Mine some Stone or Ore, then come back.", order)
	end
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
			setQuote(result)
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
		local note = noteLabel
		if panel.Visible and note and note.Parent then
			note.Text = `At-risk pile sells first · {resetText()}`
		end
	end
end)
