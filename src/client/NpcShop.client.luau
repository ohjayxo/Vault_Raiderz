--!strict
-- The NPC buyer's Sell panel (06-economy.md § Two tiers of selling, § NPC
-- price decay D94). Opens when you use the buyer's "Sell" prompt (the server
-- fires OpenNpcShop after checking you're close).
--
-- Display and intents only: every price and count comes from the server
-- (GetSellQuote / SellUnits, R5). Tapping Sell sends "this resource, this
-- Grade, this many"; the server decides what actually sells and for how much.
-- Greybox UI: big buttons, no art (UI templates pass comes before step 14).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))

local player = Players.LocalPlayer
local cfg = Config.NpcSelling
local ui = cfg.Ui
local NOTE = Color3.fromRGB(170, 170, 190)
local GOLD = Color3.fromRGB(255, 220, 120)

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

-- ── UI (greybox) ─────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "NpcShop"
gui.ResetOnSpawn = false
gui.DisplayOrder = ui.DisplayOrder

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

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.9, 0.85)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = ui.PanelMaxSize
limit.Parent = panel
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -60, 0, 34)
title.BackgroundTransparency = 1
title.TextColor3 = GOLD
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Buyer"
title.Parent = panel

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
message.Size = UDim2.fromOffset(360, 28)
message.BackgroundColor3 = Color3.new(0, 0, 0)
message.BackgroundTransparency = 0.2
message.TextColor3 = Color3.new(1, 1, 1)
message.Font = Enum.Font.GothamBold
message.TextSize = 14
message.Visible = false
message.ZIndex = 5
message.Parent = panel

gui.Parent = player:WaitForChild("PlayerGui")

local messageToken = 0
local function showMessage(text: string)
	messageToken += 1
	local token = messageToken
	message.Text = text
	message.Visible = true
	task.delay(ui.MessageSeconds, function()
		if messageToken == token then
			message.Visible = false
		end
	end)
end

local function withCommas(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
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
		showMessage(REASON_TEXT.Failed)
	elseif not accepted then
		showMessage(REASON_TEXT[reason] or REASON_TEXT.Failed)
	else
		showMessage(`Sold for {withCommas(earned or 0)} Credits`)
	end
	if ok and newQuote then
		quote = newQuote
	end
	render()
end

local function rowFrame(order: number): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, ui.RowHeight)
	frame.BackgroundTransparency = 1
	frame.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

local function label(parent: Instance, text: string, width: number, color: Color3?, order: number)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.Size = UDim2.fromOffset(width, ui.RowHeight)
	l.BackgroundTransparency = 1
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
end

render = function()
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	title.Text = `Buyer   ·   Credits {withCommas(credits or 0)}`
	local q = quote
	if not q then
		label(rowFrame(1), "Loading...", 300, NOTE, 1)
		return
	end
	local order = 0
	local anything = false
	for _, resource in Config.Resources.Types do
		local data = q.Resources[resource]
		if not data then
			continue
		end
		order += 1
		label(rowFrame(order), `{resource}   (today's price {data.Percent}% of full)`, 500, NOTE, 1)
		for _, grade in Config.Grade.Names do
			local entry = data.Grades[grade]
			if entry and entry.Have > 0 then
				anything = true
				order += 1
				local frame = rowFrame(order)
				label(frame, `{grade} x{withCommas(entry.Have)}  @ {entry.Price}`, 250, nil, 1)
				for i, amount in { 1, 10, entry.Have } do
					local text = if i == 3 then "All" else `Sell {amount}`
					if i == 2 and entry.Have <= 10 then
						continue -- "Sell 10" would just be "All"
					end
					if i == 3 and entry.Have <= 1 then
						continue
					end
					local b = makeButton(frame, text, 84, ui.RowHeight - 2)
					b.LayoutOrder = i + 1
					b.Activated:Connect(function()
						sell(resource, grade, amount)
					end)
				end
			end
		end
	end
	if not anything then
		order += 1
		label(rowFrame(order), "You have nothing the buyer wants. Mine some resources first.", 560, NOTE, 1)
	end
	order += 1
	label(rowFrame(order), "Sells from your at-risk pile first, then your bank. Prices drop as you sell and reset each day.", 560, NOTE, 1)
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
