--!strict
-- TEMPORARY debug HUD (step 2): your resources by Grade + your last hit.
-- Delete once step 3's Banked/Exposed meter exists. Display only: every
-- number comes from the server (R5).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))

local player = Players.LocalPlayer

local STARTUP_TRIES = 10 -- profile may still be loading when we start
local STARTUP_RETRY_SECONDS = 1

local gui = Instance.new("ScreenGui")
gui.Name = "DebugResourceHud"
gui.ResetOnSpawn = false

local label = Instance.new("TextLabel")
label.Position = UDim2.fromOffset(12, 60)
label.AutomaticSize = Enum.AutomaticSize.XY
label.Size = UDim2.fromOffset(0, 0)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.35
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.Code
label.TextSize = 14
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.RichText = true
label.Text = "DEBUG resources: loading..."
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.Parent = label
label.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local snapshot: Types.ResourceSnapshot? = nil
local lastHit = "-"

local function sumGrades(grades: Types.GradeCounts?): number
	local total = 0
	if grades then
		for _, count in grades do
			total += count
		end
	end
	return total
end

local function render()
	local lines = { "<b>DEBUG resources</b> (Banked + Exposed)" }
	if snapshot then
		for _, resource in Config.Resources.Types do
			local banked = snapshot.Banked[resource]
			local exposed = snapshot.Exposed[resource]
			local total = sumGrades(banked) + sumGrades(exposed)
			local parts = {}
			for _, grade in Config.Grade.Names do
				local count = (if banked then banked[grade] or 0 else 0) + (if exposed then exposed[grade] or 0 else 0)
				if count > 0 then
					table.insert(parts, `{grade} {count}`)
				end
			end
			local breakdown = if #parts > 0 then `  ({table.concat(parts, ", ")})` else ""
			table.insert(lines, `{resource}: {total}{breakdown}`)
		end
	else
		table.insert(lines, "(profile not loaded)")
	end
	table.insert(lines, `Last hit: {lastHit}`)
	label.Text = table.concat(lines, "\n")
end

Remotes.getEvent("ResourcesChanged").OnClientEvent:Connect(function(newSnapshot: Types.ResourceSnapshot)
	snapshot = newSnapshot
	render()
end)

Remotes.getEvent("MineResult").OnClientEvent:Connect(function(resource: string, grade: string, amount: number, hitsLeft: number)
	lastHit = `+{amount} {resource} ({grade}), node hits left {hitsLeft}`
	render()
end)

render()
local getResources = Remotes.getFunction("GetResources")
for _ = 1, STARTUP_TRIES do
	if snapshot then
		break
	end
	local ok, result = pcall(function()
		return getResources:InvokeServer()
	end)
	if ok and result then
		snapshot = result
		render()
		break
	end
	task.wait(STARTUP_RETRY_SECONDS)
end
