--!strict
-- Alerts about YOUR base only (BaseAlert remote): Scav Wave incoming / won /
-- lost, tripwires, empty defenses, Captain loot. Server-wide announcements
-- are AnnouncementBanner's job (D58).
--
-- 02-core-loop.md § HUD priority (D64): one compact, priority-ordered
-- "threat strip". Raid alerts jump the queue, then Scav Waves, then
-- everything else; lower ones wait. (Raid status itself is RaidUi's banner.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiStyle = require(Shared:WaitForChild("UiStyle"))

-- Look only: each kind maps to a shared tone (UiStyle.tone), so alerts, the
-- announcement banner and the raid banner all use one palette.
local TONES: { [string]: UiStyle.Tone } = {
	WaveIncoming = "warn",
	Tripwire = "critical",
	ScavLooted = "critical",
	WaveLost = "bad",
	WaveWon = "good",
	CaptainLoot = "info",
	DefenseEmpty = "muted",
	Disrupted = "special",
	RaidAlert = "critical",
	RaidLost = "bad",
	RaidOver = "good",
}
-- D64 priority: lower number shows first. Unlisted kinds = 3.
local PRIORITY: { [string]: number } = {
	RaidAlert = 1,
	RaidLost = 1,
	RaidOver = 1,
	Tripwire = 1,
	WaveIncoming = 2,
	ScavLooted = 2,
	WaveLost = 2,
	WaveWon = 2,
	CaptainLoot = 2,
}

-- One slot in the shared top stack, under the raid status and above announcements,
-- so all of them can show at once without overlapping.
local banner = UiStyle.banner(UiStyle.topStack(Players.LocalPlayer:WaitForChild("PlayerGui")), nil, Config.UiStyle.TopStack.Order.BaseAlerts)

-- Alerts queue and show one after another, so a quick follow-up (e.g.
-- "Scav Wave defeated!" right after the Captain's loot) can't hide one.
local MAX_WAITING = 4 -- [PH] invented: older extras are dropped past this
local waiting: { { kind: string, text: string, priority: number } } = {}
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
	banner.BackgroundColor3 = UiStyle.tone(TONES[nextAlert.kind] or "muted")
	banner.Visible = true
	task.delay(Config.Broadcast.BannerSeconds, showNext)
end

Remotes.getEvent("BaseAlert").OnClientEvent:Connect(function(kind: string, text: string)
	local priority = PRIORITY[kind] or 3
	-- Insert after everything at the same or higher priority.
	local at = #waiting + 1
	for i, waitingAlert in waiting do
		if waitingAlert.priority > priority then
			at = i
			break
		end
	end
	table.insert(waiting, at, { kind = kind, text = text, priority = priority })
	if #waiting > MAX_WAITING then
		table.remove(waiting) -- drop the least important
	end
	if not showing then
		showNext()
	end
end)
