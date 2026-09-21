--!strict
-- Banked/Exposed meter. 02-core-loop.md § Bank vs Exposed; § FTUE spec
-- (appears at 2:30-4:00, hidden before: R4).
--
-- Display only: every number comes from the server (R5). Shown or hidden
-- only by the server, through a Player attribute
-- (Config.Bank.Meter.VisibleAttribute, set by VaultService.setMeterVisible).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))

local player = Players.LocalPlayer
local meterCfg = Config.Bank.Meter

-- ── UI (greybox) ─────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "VaultMeter"
gui.ResetOnSpawn = false
gui.Enabled = false -- hidden until the server says otherwise

local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(12, 60)
panel.Size = UDim2.fromOffset(meterCfg.Width, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 0.35
panel.Parent = gui
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel

local function makeLabel(order: number, color: Color3, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, size + 4)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = panel
	return label
end

local bankedLabel = makeLabel(1, meterCfg.BankedColor, 14)

local barBack = Instance.new("Frame")
barBack.LayoutOrder = 2
barBack.Size = UDim2.new(1, 0, 0, meterCfg.BarHeight)
barBack.BackgroundColor3 = meterCfg.BarBackColor
barBack.BorderSizePixel = 0
barBack.Parent = panel
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = meterCfg.BankedColor
barFill.BorderSizePixel = 0
barFill.Parent = barBack

local exposedLabel = makeLabel(3, meterCfg.ExposedColor, 14)
local scrapLabel = makeLabel(4, Color3.fromRGB(200, 200, 200), 12)

gui.Parent = player:WaitForChild("PlayerGui")

-- ── Rendering ────────────────────────────────────────────────────────────

local function totalUnits(store: Types.ResourceStore): number
	local total = 0
	for _, grades in store do
		for _, count in grades do
			total += count
		end
	end
	return total
end

-- 12345 -> "12,345"
local function withCommas(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function render(state: Types.VaultState?)
	if not state then
		bankedLabel.Text = "Banked ..."
		exposedLabel.Text = ""
		scrapLabel.Text = ""
		return
	end
	local banked = totalUnits(state.Banked)
	bankedLabel.Text = `Banked {withCommas(banked)} / {withCommas(state.Capacity)}`
	local fill = if state.Capacity > 0 then math.clamp(banked / state.Capacity, 0, 1) else 0
	barFill.Size = UDim2.fromScale(fill, 1)
	exposedLabel.Text = `Exposed {withCommas(totalUnits(state.Exposed))}`
	scrapLabel.Text =
		`Scrap {withCommas(state.ScrapBanked)} / {withCommas(state.ScrapCapacity)}  ·  exposed {withCommas(state.ScrapExposed)}`
end

-- ── Visibility (server-controlled) ───────────────────────────────────────

local function applyVisibility()
	gui.Enabled = player:GetAttribute(meterCfg.VisibleAttribute) == true
end
player:GetAttributeChangedSignal(meterCfg.VisibleAttribute):Connect(applyVisibility)
applyVisibility()

-- ── Data ─────────────────────────────────────────────────────────────────

local received = false
Remotes.getEvent("VaultChanged").OnClientEvent:Connect(function(state: Types.VaultState)
	received = true
	render(state)
end)

render(nil)
local getVaultState = Remotes.getFunction("GetVaultState")
-- The profile may still be loading when we start (Config.Bank.HudStartup*).
for _ = 1, Config.Bank.HudStartupTries do
	if received then
		break
	end
	local ok, result = pcall(function()
		return getVaultState:InvokeServer()
	end)
	if ok and result and not received then
		received = true
		render(result)
		break
	end
	task.wait(Config.Bank.HudStartupRetrySeconds)
end
