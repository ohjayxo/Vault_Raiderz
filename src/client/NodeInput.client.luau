--!strict
-- Tap/click a resource node -> ask the server to mine it (an intent; R5).
-- Also plays Grade effects the server announces (GradeFx).
--
-- Greybox contract: only Hitbox parts are raycast against; the Visual folder
-- is never read or changed. Effects go in a client-only folder.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local NodeMath = require(Shared:WaitForChild("NodeMath"))

local player = Players.LocalPlayer
local mineEvent = Remotes.getEvent("MineNode")

local look = Config.Grade.FxLook

-- ── "Walk closer" hint ───────────────────────────────────────────────────

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "MineHint"
hintGui.ResetOnSpawn = false
local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 0.8, 0)
hint.Size = UDim2.fromOffset(240, 32)
hint.BackgroundColor3 = Color3.new(0, 0, 0)
hint.BackgroundTransparency = 0.4
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextScaled = true
hint.Text = "Walk closer to mine"
hint.Visible = false
hint.Parent = hintGui
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintToken = 0
local function showHint()
	hintToken += 1
	local token = hintToken
	hint.Visible = true
	task.delay(Config.Nodes.WalkCloserHintSeconds, function()
		if hintToken == token then
			hint.Visible = false
		end
	end)
end

-- ── Picking a node ───────────────────────────────────────────────────────

local function nodeHitboxes(): { Instance }
	local hitboxes = {}
	for _, node in CollectionService:GetTagged(Config.Nodes.Tag) do
		local hitbox = node:FindFirstChild("Hitbox")
		if hitbox and node:IsDescendantOf(workspace) then
			table.insert(hitboxes, hitbox)
		end
	end
	return hitboxes
end

local function tryMineAt(screenPosition: Vector2)
	-- In build mode a tap means "put it here" (BuildMode.client.luau).
	if player:GetAttribute(Config.Base.BuildUi.ClientModeAttribute) then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- Tap/click positions are GUI coordinates (below the top bar), which is
	-- what ScreenPointToRay expects (backlog L4, fixed in step 5).
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = nodeHitboxes()
	local result = workspace:Raycast(ray.Origin, ray.Direction * Config.Nodes.PickRangeStuds, params)
	if not result then
		return
	end
	local hitbox = result.Instance :: BasePart
	local node = hitbox.Parent
	if not node then
		return
	end

	-- UX only: the server re-checks everything.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and NodeMath.distanceToHitbox(hitbox, root.Position) > Config.Nodes.MineDistance then
		showHint()
		return
	end
	mineEvent:FireServer(node)
end

-- Mouse (PC). Right-drag is camera, so left click is free.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local position = input.Position
	tryMineAt(Vector2.new(position.X, position.Y))
end)

-- Touch (mobile): a tap, not a camera drag or the thumbstick.
UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processedByUI: boolean)
	if not processedByUI then
		tryMineAt(position)
	end
end)

-- ── Grade effects (seen by everyone; Config.Grade.Fx) ────────────────────

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientFx"
fxFolder.Parent = workspace

type FxConfig = { Seconds: number, BeamHeight: number, Color: Color3 }
local fxConfigs: { [string]: FxConfig } = Config.Grade.Fx :: any

local function anchorPart(position: Vector3, size: Vector3, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Size = size
	part.Position = position
	part.Parent = fxFolder
	return part
end

local function playGradeFx(grade: string, position: Vector3)
	local fx = fxConfigs[grade]
	if not fx then
		return -- Standard: no effect
	end

	-- Sparkle burst at the node (every non-Standard grade).
	local core = anchorPart(position, Vector3.new(1, 1, 1), fx.Color, 1)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(fx.Color)
	emitter.LightEmission = 1
	emitter.Speed = look.ParticleSpeed
	emitter.SpreadAngle = Vector2.new(look.SpreadDegrees, look.SpreadDegrees)
	emitter.Lifetime = look.ParticleLifetime
	emitter.Size = NumberSequence.new(look.ParticleSize, 0)
	emitter.Rate = 0 -- one burst via Emit, no continuous stream
	emitter.Parent = core
	emitter:Emit(if grade == "Dense" then look.ParticlesDense else look.ParticlesOther)
	local light = Instance.new("PointLight")
	light.Color = fx.Color
	light.Range = look.LightRange
	light.Brightness = look.LightBrightness
	light.Parent = core
	Debris:AddItem(core, fx.Seconds)

	-- A column of light for the big grades, visible across the map.
	if fx.BeamHeight > 0 then
		local beam = anchorPart(
			position + Vector3.new(0, fx.BeamHeight / 2, 0),
			Vector3.new(look.BeamWidth, fx.BeamHeight, look.BeamWidth),
			fx.Color,
			look.BeamTransparency
		)
		Debris:AddItem(beam, fx.Seconds)
		if grade == "Vaultborn" then
			-- Faint, blinking, fading: missable at a glance, findable if you
			-- watch closely (Config.Grade.VaultbornBeam).
			local look2 = Config.Grade.VaultbornBeam
			beam.Size = Vector3.new(look2.Width, fx.BeamHeight, look2.Width)
			local started = os.clock()
			local connection: RBXScriptConnection
			connection = RunService.RenderStepped:Connect(function()
				if not beam.Parent then
					connection:Disconnect()
					return
				end
				local age = os.clock() - started
				local on = (age % look2.BlinkSeconds) < look2.BlinkSeconds * look2.OnFraction
				local fade = math.clamp(age / fx.Seconds, 0, 1)
				beam.Transparency = if on then look2.Transparency + (1 - look2.Transparency) * fade else 1
			end)
		elseif grade == "Prismatic" then
			-- Rainbow: cycle the hue until the beam is removed.
			local connection: RBXScriptConnection
			connection = RunService.RenderStepped:Connect(function()
				if not beam.Parent then
					connection:Disconnect()
					return
				end
				local hue = (os.clock() / Config.Grade.RainbowCycleSeconds) % 1
				beam.Color = Color3.fromHSV(hue, 0.8, 1)
			end)
		end
	end
end

Remotes.getEvent("GradeFx").OnClientEvent:Connect(function(grade: string, position: Vector3)
	playGradeFx(grade, position)
end)
