--!strict
-- Banked/Exposed meter. 02-core-loop.md § Bank vs Exposed; § FTUE spec
-- (appears at 2:30-4:00, hidden before: R4).
--
-- Display only: every number comes from the server (R5). Shown or hidden
-- only by the server, through a Player attribute
-- (Config.Bank.Meter.VisibleAttribute, set by VaultService.setMeterVisible).
-- Tapping it opens the Bag on Resources (InventoryUi): the meter shows
-- totals, the Bag shows what they're made of.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))
local UiStyle = require(Shared:WaitForChild("UiStyle"))

local player = Players.LocalPlayer
local meterCfg = Config.Bank.Meter
local style = Config.UiStyle
local colors = style.Colors
local money = UiStyle.money

-- ── UI ───────────────────────────────────────────────────────────────────
-- Look: Shared/UiStyle (Config.UiStyle, look only). A small translucent card
-- in the top-left: a Banked meter, then two one-line stats.

local TOP_BAR_CLEARANCE = 60 -- [PH] invented look-only: px, keeps the card under Roblox's top-bar icons

local gui = Instance.new("ScreenGui")
gui.Name = "VaultMeter"
gui.ResetOnSpawn = false
gui.Enabled = false -- hidden until the server says otherwise

local panel = UiStyle.hudPanel(gui, true)
panel.Position = UDim2.fromOffset(style.Window.EdgePad, TOP_BAR_CLEARANCE)
panel.Size = UDim2.fromOffset(meterCfg.Width, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y

-- The name takes only the width it needs and the value takes the rest, so
-- "10,000 / 10,000  ›" is never cut short on a narrow card.
local function fitValue(name: TextLabel, value: TextLabel)
	name.AutomaticSize = Enum.AutomaticSize.X
	name.Size = UDim2.fromScale(0, 1)
	value.AutomaticSize = Enum.AutomaticSize.None
	value.Size = UDim2.fromScale(0, 1)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextWrapped = false
	value.TextTruncate = Enum.TextTruncate.AtEnd
	local flex = Instance.new("UIFlexItem")
	flex.FlexMode = Enum.UIFlexMode.Fill
	flex.Parent = value
end

local bankedMeter = UiStyle.meter(panel, "Banked", 0, meterCfg.BankedColor, 1)
bankedMeter.value.TextColor3 = colors.Text
fitValue(bankedMeter.label, bankedMeter.value)

-- One line: a coloured name on the left, its value on the right.
local function statRow(order: number, name: string, nameColor: Color3, valueColor: Color3): (Frame, TextLabel)
	local row = UiStyle.row(panel, style.Meter.LabelHeight, order)
	local nameLabel = UiStyle.label(row, name, style.TextSize.Small, nameColor, true)
	local valueLabel = UiStyle.label(row, "", style.TextSize.Small, valueColor, false)
	fitValue(nameLabel, valueLabel)
	return row, valueLabel
end

local exposedRow, exposedValue = statRow(2, "Exposed", meterCfg.ExposedColor, colors.Text)
local scrapRow, scrapValue = statRow(3, "Scrap", colors.TextDim, colors.TextDim)

gui.Parent = player:WaitForChild("PlayerGui")

panel.Activated:Connect(function()
	local bag = player.PlayerGui:FindFirstChild("InventoryUi")
	local open = bag and bag:FindFirstChild("Open")
	if open and open:IsA("BindableEvent") then
		open:Fire("Resources")
	end
end)

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

local function render(state: Types.VaultState?)
	if not state then
		UiStyle.setMeter(bankedMeter, 0, "...")
		exposedRow.Visible = false
		scrapRow.Visible = false
		return
	end
	local banked = totalUnits(state.Banked)
	local fill = if state.Capacity > 0 then math.clamp(banked / state.Capacity, 0, 1) else 0
	UiStyle.setMeter(bankedMeter, fill, `{money(banked)} / {money(state.Capacity)}  ›`)
	exposedRow.Visible = true
	scrapRow.Visible = true
	exposedValue.Text = money(totalUnits(state.Exposed))
	scrapValue.Text = `{money(state.ScrapBanked)} / {money(state.ScrapCapacity)}  ·  {money(state.ScrapExposed)} exposed`
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
