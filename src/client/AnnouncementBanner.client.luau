--!strict
-- Shows server announcements from BroadcastQueue (06-economy.md § Broadcast
-- priority queue, D58). The server already spaces and prioritizes them, so
-- this just shows the latest one for Config.Broadcast.BannerSeconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiStyle = require(Shared:WaitForChild("UiStyle"))

-- Look only: colours stay in Config.Broadcast; this just builds the shared banner.
local bannerColors: { [string]: Color3 } = Config.Broadcast.BannerColors :: any

local function colorFor(kind: string): Color3
	return bannerColors[kind] or Config.Broadcast.DefaultBannerColor
end

local gui = Instance.new("ScreenGui")
gui.Name = "AnnouncementBanner"
gui.ResetOnSpawn = false

local banner = UiStyle.banner(gui)
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local showToken = 0
Remotes.getEvent("Announcement").OnClientEvent:Connect(function(kind: string, text: string)
	showToken += 1
	local token = showToken
	banner.Text = text
	banner.BackgroundColor3 = colorFor(kind)
	banner.Visible = true
	task.delay(Config.Broadcast.BannerSeconds, function()
		if showToken == token then
			banner.Visible = false
		end
	end)
end)
