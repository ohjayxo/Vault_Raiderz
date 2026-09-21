--!strict
-- THROWAWAY (build step 0B): on-screen FPS + memory readout and test controls
-- for the mobile performance spike. Delete with src/server/PerfSpike (see the
-- list at the top of src/server/PerfSpike/init.luau).
--
-- The client only DISPLAYS things and sends an intent (a preset NAME). All
-- scene numbers it shows (triangles, parts...) are published by the server as
-- Workspace attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

ReplicatedStorage:WaitForChild("Shared")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local cfg = Config.PerfSpike
if not cfg.Enabled then
	return
end

local player = Players.LocalPlayer
local setPresetEvent = Remotes.getEvent("PerfSpikeSetPreset")

-- Rough cost of one R15 rig in draw calls (about 15 body parts). Only used for
-- the crude draw-call estimate; the real number has to come from Studio's stats.
local R15_PARTS = 15
local KILO = 1000
local CORE_GUI_RETRIES = 10

-- Real counters straight from the engine (script-readable, per the API dump).
-- Draw calls/triangles are the same measures the docs' budget uses; the CPU/GPU
-- frame times are how much of each frame is actually spent, which (unlike FPS)
-- keeps moving below the frame-rate cap. They might not be populated on every
-- device, so probe once and fall back to "not available".
local renderStatsAvailable = pcall(function()
	return Stats.SceneDrawcallCount
		+ Stats.ShadowsDrawcallCount
		+ Stats.SceneTriangleCount
		+ Stats.ShadowsTriangleCount
		+ Stats.RenderCPUFrameTime
		+ Stats.RenderGPUFrameTime
end)

type Recording = {
	Deltas: { number },
	Elapsed: number,
	Version: number,
	View: string,
	Preset: string,
	-- Sums of per-frame Stats readings (divide by frame count at the end).
	Cpu: number,
	Gpu: number,
	DrawCalls: number,
	Triangles: number,
}

-- ── State ───────────────────────────────────────────────────────────────

local viewMode = "Ground" -- "Ground" | "Overview"
local settleUntil = 0 -- os.clock() time before which readings are unreliable
local recording: Recording? = nil
local results: { string } = {}
local resultsVisible = true

-- Rolling window of recent frame times (seconds), oldest at `first`.
local window: { [number]: number } = {}
local first, last, windowTotal = 1, 0, 0

local function clearWindow()
	table.clear(window)
	first, last, windowTotal = 1, 0, 0
end

-- ── Helpers ─────────────────────────────────────────────────────────────

local function attr(name: string): any
	return workspace:GetAttribute("PerfSpike_" .. name)
end

local function num(name: string): number
	local value = attr(name)
	return if typeof(value) == "number" then value else 0
end

local function lowFps(deltas: { number }): number
	if #deltas == 0 then
		return 0
	end
	table.sort(deltas, function(a, b)
		return a > b -- slowest frames first
	end)
	local index = math.max(1, math.ceil(#deltas * cfg.LowPercentile))
	return 1 / deltas[index]
end

local function verdict(avg: number, low: number): string
	if avg >= cfg.Fps.Comfortable and low >= cfg.Fps.WorstPass then
		return "GOOD"
	elseif avg >= cfg.Fps.Pass and low >= cfg.Fps.WorstPass then
		return "PASS"
	end
	return "FAIL"
end

-- settings().Rendering.QualityLevel is Plugin-only, so show what scripts CAN read:
-- the saved graphics setting and Roblox's own dynamic quality level.
local function qualityText(): string
	local saved, harmony = "?", "?"
	pcall(function()
		local gameSettings: any = UserSettings().GameSettings
		saved = gameSettings.SavedQualityLevel.Name
	end)
	pcall(function()
		harmony = tostring(Stats:GetHarmonyQualityLevel())
	end)
	return `saved {saved} / harmony {harmony}`
end

local function whole(value: number): string
	return string.format("%d", math.floor(value + 0.5))
end

-- ── UI ──────────────────────────────────────────────────────────────────

-- The default player list sits where our buttons go. Roblox ignores this until
-- its own scripts have registered, so retry for a few seconds.
task.spawn(function()
	for _ = 1, CORE_GUI_RETRIES do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false) then
			return
		end
		task.wait(1)
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "PerfSpikeHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets -- stay clear of the notch and Roblox's top bar
gui.Parent = player:WaitForChild("PlayerGui")

local function styleText(object: GuiObject, size: number)
	local label = object :: TextLabel -- TextButton has the same text properties
	label.Font = Enum.Font.Code
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 0.35
	label.BorderSizePixel = 0
end

-- Left column: stats on top, Record results underneath.
local column = Instance.new("Frame")
column.Name = "Column"
column.BackgroundTransparency = 1
column.Position = UDim2.fromOffset(8, 8)
column.Size = UDim2.fromOffset(330, 0)
column.AutomaticSize = Enum.AutomaticSize.Y
column.Parent = gui
local columnLayout = Instance.new("UIListLayout")
columnLayout.Padding = UDim.new(0, 4)
columnLayout.Parent = column

local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "Stats"
styleText(statsLabel, 14)
statsLabel.Size = UDim2.fromScale(1, 0)
statsLabel.AutomaticSize = Enum.AutomaticSize.Y
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Parent = column

local resultsLabel = Instance.new("TextLabel")
resultsLabel.Name = "Results"
styleText(resultsLabel, 12)
resultsLabel.Size = UDim2.fromScale(1, 0)
resultsLabel.AutomaticSize = Enum.AutomaticSize.Y
resultsLabel.TextXAlignment = Enum.TextXAlignment.Left
resultsLabel.TextYAlignment = Enum.TextYAlignment.Top
resultsLabel.Parent = column

-- Right column: buttons.
local buttons = Instance.new("Frame")
buttons.Name = "Buttons"
buttons.BackgroundTransparency = 1
buttons.AnchorPoint = Vector2.new(1, 0)
buttons.Position = UDim2.new(1, -8, 0, 8)
buttons.Size = UDim2.fromOffset(170, 0)
buttons.AutomaticSize = Enum.AutomaticSize.Y
buttons.Parent = gui
local buttonLayout = Instance.new("UIListLayout")
buttonLayout.Padding = UDim.new(0, 6)
buttonLayout.Parent = buttons

local function makeButton(order: number): TextButton
	local button = Instance.new("TextButton")
	styleText(button, 15)
	button.BackgroundTransparency = 0.2
	button.Size = UDim2.new(1, 0, 0, 44) -- big enough for a thumb
	button.LayoutOrder = order
	button.AutoButtonColor = true
	button.Parent = buttons
	return button
end

local presetButton = makeButton(1)
local viewButton = makeButton(2)
local recordButton = makeButton(3)
local resultsButton = makeButton(4)

-- ── Actions ─────────────────────────────────────────────────────────────

local function applyView()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if viewMode == "Overview" then
		local center = attr("OwnCenter")
		if typeof(center) == "Vector3" then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(center + cfg.Overview.Offset, center)
		end
	else
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function startSettling()
	settleUntil = os.clock() + cfg.SettleSeconds
	clearWindow()
	recording = nil
end

local function isBusy(): boolean
	return attr("Building") == true or os.clock() < settleUntil
end

presetButton.Activated:Connect(function()
	if isBusy() then
		return
	end
	local count = num("PresetCount")
	if count == 0 then
		return
	end
	local nextIndex = num("PresetIndex") % count + 1
	setPresetEvent:FireServer(cfg.Presets[nextIndex].Name)
end)

viewButton.Activated:Connect(function()
	viewMode = if viewMode == "Ground" then "Overview" else "Ground"
	applyView()
	startSettling()
end)

recordButton.Activated:Connect(function()
	if recording then
		recording = nil -- tap again to cancel
		return
	end
	if isBusy() then
		return
	end
	recording = {
		Deltas = {},
		Elapsed = 0,
		Version = num("Version"),
		View = viewMode,
		Preset = tostring(attr("Preset")),
		Cpu = 0,
		Gpu = 0,
		DrawCalls = 0,
		Triangles = 0,
	}
end)

resultsButton.Activated:Connect(function()
	resultsVisible = not resultsVisible
end)

local function finishRecording(current: Recording)
	local frames = #current.Deltas
	local avg = frames / current.Elapsed
	local low = lowFps(current.Deltas)
	local tris = num("Tris")
	local first = string.format(
		"%d %s/%s %s|%s %s %sMB %s/%dp",
		#results + 1,
		current.Preset,
		current.View,
		whole(avg),
		whole(low),
		verdict(avg, low),
		whole(Stats:GetTotalMemoryUsageMb()),
		if tris >= 0 then whole(tris / KILO) .. "k" else "n/a",
		num("Parts")
	)
	local second = "  render counters n/a"
	if renderStatsAvailable then
		second = string.format(
			"  cpu %.4f gpu %.4f dc %s tri %sk",
			current.Cpu / frames,
			current.Gpu / frames,
			whole(current.DrawCalls / frames),
			whole(current.Triangles / frames / KILO)
		)
	end
	table.insert(results, first .. "\n" .. second)
	print("[PerfSpike] " .. first .. " |" .. second .. " | QL " .. qualityText())
	recording = nil
end

-- ── Sampling ────────────────────────────────────────────────────────────

RunService.PreRender:Connect(function(dt: number)
	last += 1
	window[last] = dt
	windowTotal += dt
	while windowTotal > cfg.LowWindowSeconds and first < last do
		windowTotal -= window[first]
		window[first] = nil
		first += 1
	end

	local current = recording
	if current then
		table.insert(current.Deltas, dt)
		current.Elapsed += dt
		if renderStatsAvailable then
			current.Cpu += Stats.RenderCPUFrameTime
			current.Gpu += Stats.RenderGPUFrameTime
			current.DrawCalls += Stats.SceneDrawcallCount + Stats.ShadowsDrawcallCount
			current.Triangles += Stats.SceneTriangleCount + Stats.ShadowsTriangleCount
		end
		if os.clock() < settleUntil or current.Version ~= num("Version") or current.View ~= viewMode then
			recording = nil -- the scene changed under us; that reading would be junk
		elseif current.Elapsed >= cfg.RecordSeconds then
			finishRecording(current)
		end
	end
end)

workspace:GetAttributeChangedSignal("PerfSpike_Version"):Connect(startSettling)
player.CharacterAdded:Connect(function()
	task.defer(applyView) -- respawning can hand the camera back to the default script
end)

-- ── Display loop ────────────────────────────────────────────────────────

local function refresh()
	local count = last - first + 1
	local fps = if windowTotal > 0 then count / windowTotal else 0
	local deltas: { number } = {}
	for i = first, last do
		table.insert(deltas, window[i])
	end
	local low = lowFps(deltas)

	local tris = num("Tris")
	local parts, emitters, npcs = num("Parts"), num("Emitters"), num("Npcs")
	local drawCalls = parts + emitters + npcs * R15_PARTS
	local kitMode = tostring(attr("KitMode"))

	local lines: { string } = {}
	if kitMode ~= "Imported" then
		table.insert(lines, `!! KIT: {kitMode} - TRIANGLES NOT VALID`)
	end
	table.insert(lines, `{tostring(attr("Preset"))} ({num("PresetIndex")}/{num("PresetCount")})  view: {viewMode}`)
	table.insert(lines, `FPS {whole(fps)}   1% low {whole(low)}`)
	table.insert(
		lines,
		string.format(
			"Mem  %s MB  (scripts %s MB)",
			whole(Stats:GetTotalMemoryUsageMb()),
			-- By-category memory returns 0 and logs a warning when tracking is off.
			if Stats.MemoryTrackingEnabled then whole(Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Script)) else "n/a"
		)
	)
	if tris >= 0 then
		table.insert(
			lines,
			string.format("Tris claimed %sk / %sk  %s%%", whole(tris / KILO), whole(cfg.Budget.Triangles / KILO), whole(100 * tris / cfg.Budget.Triangles))
		)
	else
		table.insert(lines, "Tris n/a (plain-block fallback)")
	end
	table.insert(lines, string.format("~DC guess %d (parts+fx+rigs)", drawCalls))
	if renderStatsAvailable then
		local dc = Stats.SceneDrawcallCount + Stats.ShadowsDrawcallCount
		local tri = Stats.SceneTriangleCount + Stats.ShadowsTriangleCount
		table.insert(lines, string.format("Scene  dc %d  tri %sk", Stats.SceneDrawcallCount, whole(Stats.SceneTriangleCount / KILO)))
		table.insert(lines, string.format("Shadow dc %d  tri %sk", Stats.ShadowsDrawcallCount, whole(Stats.ShadowsTriangleCount / KILO)))
		table.insert(
			lines,
			string.format(
				"REAL dc %d/%d %s%%  tri %sk/%sk %s%%",
				dc,
				cfg.Budget.DrawCalls,
				whole(100 * dc / cfg.Budget.DrawCalls),
				whole(tri / KILO),
				whole(cfg.Budget.Triangles / KILO),
				whole(100 * tri / cfg.Budget.Triangles)
			)
		)
		table.insert(
			lines,
			string.format("CPU %.4f  GPU %.4f  (raw) FT %.4f", Stats.RenderCPUFrameTime, Stats.RenderGPUFrameTime, Stats.FrameTime)
		)
		if dc == 0 and tri == 0 and Stats.RenderGPUFrameTime == 0 then
			table.insert(lines, "!! render counters read 0 on this device")
		end
	else
		table.insert(lines, "!! render counters not available here")
	end
	table.insert(lines, string.format("bases %d  parts %d  fx %d  npcs %d", num("Bases"), parts, emitters, npcs))
	table.insert(lines, `pieces x{num("PieceMultiplier")}{if attr("Varied") == true then " VARIED" else ""}  LOD {tostring(attr("RenderFidelity"))}  touch {UserInputService.TouchEnabled}`)
	table.insert(lines, `QL {qualityText()}`)

	if attr("Building") == true then
		table.insert(lines, ">> REBUILDING SCENE...")
	elseif os.clock() < settleUntil then
		table.insert(lines, string.format(">> SETTLING %ds - wait before recording", math.ceil(settleUntil - os.clock())))
	end
	statsLabel.Text = table.concat(lines, "\n")

	-- Buttons
	local nextIndex = num("PresetIndex") % math.max(1, num("PresetCount")) + 1
	presetButton.Text = `Next preset > {cfg.Presets[nextIndex].Name}`
	viewButton.Text = `View: {viewMode} (tap)`
	local current = recording
	if current then
		recordButton.Text = string.format("Recording %ds (cancel)", math.ceil(cfg.RecordSeconds - current.Elapsed))
	else
		recordButton.Text = `Record {cfg.RecordSeconds}s`
	end
	resultsButton.Text = if resultsVisible then "Hide results" else "Show results"

	-- Results (newest last; screenshot this)
	resultsLabel.Visible = resultsVisible
	local shown: { string } = { "# preset/view avg|low verdict mem tris/parts" }
	for i = math.max(1, #results - cfg.ResultsShown + 1), #results do
		table.insert(shown, results[i])
	end
	resultsLabel.Text = table.concat(shown, "\n")
end

task.spawn(function()
	while true do
		refresh()
		task.wait(0.5)
	end
end)

startSettling() -- a fresh join is still downloading the scene
