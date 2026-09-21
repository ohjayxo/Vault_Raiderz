--!strict
-- Shows server announcements from BroadcastQueue (06-economy.md § Broadcast
-- priority queue, D58). The server already spaces and prioritizes them, so
-- this just shows the latest one for Config.Broadcast.BannerSeconds.
-- Greybox styling.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

-- Banner colour by kind; anything unlisted uses DEFAULT_COLOR.
local KIND_COLORS: { [string]: Color3 } = {
	RaidAlert = Color3.fromRGB(170, 30, 30),
	ChasePing = Color3.fromRGB(170, 30, 30),
	Vaultborn = Color3.fromRGB(150, 115, 20),
}
local DEFAULT_COLOR = Color3.fromRGB(40, 40, 50)

local gui = Instance.new("ScreenGui")
gui.Name = "AnnouncementBanner"
gui.ResetOnSpawn = false

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 12)
banner.Size = UDim2.new(0.6, 0, 0, 40)
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

local showToken = 0
Remotes.getEvent("Announcement").OnClientEvent:Connect(function(kind: string, text: string)
	showToken += 1
	local token = showToken
	banner.Text = text
	banner.BackgroundColor3 = KIND_COLORS[kind] or DEFAULT_COLOR
	banner.Visible = true
	task.delay(Config.Broadcast.BannerSeconds, function()
		if showToken == token then
			banner.Visible = false
		end
	end)
end)
