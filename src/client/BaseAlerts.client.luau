--!strict
-- Alerts about YOUR base only (BaseAlert remote): Scav Wave incoming / won /
-- lost, tripwires, empty defenses, Captain loot. Server-wide announcements
-- are AnnouncementBanner's job (D58).
--
-- 02-core-loop.md § HUD priority (D64) wants one priority-ordered "threat
-- strip" once raids exist (step 7); until then this is a simple banner
-- under the announcement one. Greybox styling.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

-- Look only. [PH] invented, REVISIT with the D64 threat strip.
local COLORS: { [string]: Color3 } = {
	WaveIncoming = Color3.fromRGB(170, 90, 30),
	Tripwire = Color3.fromRGB(170, 30, 30),
	ScavLooted = Color3.fromRGB(170, 30, 30),
	WaveLost = Color3.fromRGB(140, 40, 40),
	WaveWon = Color3.fromRGB(40, 120, 60),
	CaptainLoot = Color3.fromRGB(150, 115, 20),
	DefenseEmpty = Color3.fromRGB(90, 90, 110),
	Disrupted = Color3.fromRGB(90, 60, 140),
}

local gui = Instance.new("ScreenGui")
gui.Name = "BaseAlerts"
gui.ResetOnSpawn = false

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 60)
banner.Size = UDim2.new(0.5, 0, 0, 34)
banner.BackgroundTransparency = 0.15
banner.TextColor3 = Color3.new(1, 1, 1)
banner.Font = Enum.Font.GothamBold
banner.TextScaled = true
banner.Visible = false
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = banner
banner.Parent = gui
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Alerts queue and show one after another, so a quick follow-up (e.g.
-- "Scav Wave defeated!" right after the Captain's loot) can't hide one.
local MAX_WAITING = 4 -- [PH] invented: older extras are dropped past this
local waiting: { { kind: string, text: string } } = {}
local showing = false

local function showNext()
	local nextAlert = table.remove(waiting, 1)
	if not nextAlert then
		showing = false
		banner.Visible = false
		return
	end
	showing = true
	banner.Text = nextAlert.text
	banner.BackgroundColor3 = COLORS[nextAlert.kind] or Config.Broadcast.DefaultBannerColor
	banner.Visible = true
	task.delay(Config.Broadcast.BannerSeconds, showNext)
end

Remotes.getEvent("BaseAlert").OnClientEvent:Connect(function(kind: string, text: string)
	table.insert(waiting, { kind = kind, text = text })
	if #waiting > MAX_WAITING then
		table.remove(waiting, 1)
	end
	if not showing then
		showNext()
	end
end)
