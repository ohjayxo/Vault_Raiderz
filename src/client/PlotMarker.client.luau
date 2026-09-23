--!strict
-- "Your plot" marker (Josh, 2026-09-23). Plots are given, not picked (02 §
-- Slice layout, D113), and you spawn mid-street, so nothing told a new player
-- which plot was theirs, and the Build button only shows ON your own plot.
-- This draws a pulsing light beam and a bouncing arrow over your plot, for
-- you only, while you're off it. No words (02 § FTUE hard rule 1).
--
-- Visual only: the parts are made here on this client (other players never
-- see them), can't be hit, touched or raycast, and gameplay never reads them.
-- Shown only while the Build UI is (Config.Base.BuildUi.VisibleAttribute), so
-- the FTUE (step 14) controls both together (R4).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NodeMath = require(Shared:WaitForChild("NodeMath"))

local player = Players.LocalPlayer
local uiCfg = Config.Base.BuildUi
local cfg = uiCfg.PlotMarker

-- ── The marker (built once, moved onto whichever plot is yours) ─────────

local folder = Instance.new("Folder")
folder.Name = "MyPlotMarker"

local function inert(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false -- node taps, build raycasts and swings pass through
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = cfg.BeamColor
end

-- A cylinder's length runs along its X axis: rotated to stand upright.
local beam = Instance.new("Part")
beam.Name = "Beam"
beam.Shape = Enum.PartType.Cylinder
beam.Size = Vector3.new(cfg.BeamHeight, cfg.BeamWidth, cfg.BeamWidth)
inert(beam)
beam.Transparency = cfg.BeamTransparency[1]
beam.Parent = folder

local anchor = Instance.new("Part")
anchor.Name = "ArrowAnchor"
anchor.Size = Vector3.one
anchor.Transparency = 1
inert(anchor)
anchor.Parent = folder

local billboard = Instance.new("BillboardGui")
billboard.Size = UDim2.fromOffset(cfg.ArrowPixels, cfg.ArrowPixels)
billboard.AlwaysOnTop = true -- findable from anywhere on the street
billboard.LightInfluence = 0
billboard.Adornee = anchor
billboard.Parent = anchor

local arrow = Instance.new("TextLabel")
arrow.Size = UDim2.fromScale(1, 1)
arrow.BackgroundTransparency = 1
arrow.Text = "▼" -- a shape, not words (FTUE hard rule 1)
arrow.TextScaled = true
arrow.Font = Enum.Font.GothamBold
arrow.TextColor3 = cfg.BeamColor
arrow.TextStrokeTransparency = 0.3
arrow.Parent = billboard

-- Repeat forever (-1), reversing each time: a pulse and a bounce.
local pulse = TweenInfo.new(cfg.PulseSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
TweenService:Create(beam, pulse, { Transparency = cfg.BeamTransparency[2] }):Play()
TweenService:Create(billboard, pulse, { StudsOffset = Vector3.new(0, cfg.ArrowBounceStuds, 0) }):Play()

-- ── Which plot is mine, and am I on it? ──────────────────────────────────

-- Same lookup as BuildMode: the server sets PlotIndex on you and on the plot.
local function myPlotHitbox(): BasePart?
	local index = player:GetAttribute("PlotIndex")
	if index == nil then
		return nil
	end
	for _, plot in CollectionService:GetTagged(Config.Plots.Tag) do
		if plot:GetAttribute("PlotIndex") == index and plot:IsDescendantOf(workspace) then
			local hitbox = plot:FindFirstChild("Hitbox")
			return if hitbox and hitbox:IsA("BasePart") then hitbox else nil
		end
	end
	return nil
end

local placedOn: BasePart? = nil

local function placeOn(hitbox: BasePart)
	if placedOn == hitbox then
		return
	end
	placedOn = hitbox
	local top = hitbox.Position + Vector3.new(0, hitbox.Size.Y / 2, 0)
	beam.CFrame = CFrame.new(top + Vector3.new(0, cfg.BeamHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	anchor.CFrame = CFrame.new(top + Vector3.new(0, cfg.ArrowHeight, 0))
end

local function update()
	local shown = false
	local hitbox = myPlotHitbox()
	if hitbox and player:GetAttribute(uiCfg.VisibleAttribute) == true then
		placeOn(hitbox)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- Same "on my plot" distance as the Build button, so the marker
		-- disappears exactly when the button appears.
		shown = not (root and NodeMath.distanceToHitbox(hitbox, root.Position) <= uiCfg.ShowWithinStuds)
	end
	folder.Parent = if shown then workspace else nil
end

task.spawn(function()
	while true do
		update()
		task.wait(cfg.CheckSeconds)
	end
end)
