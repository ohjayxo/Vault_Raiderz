--!strict
-- Swinging the pickaxe (step 5). 02-core-loop.md § Combat feel: "3-hit
-- combo, generous hitboxes, light aim assist".
--
-- The client only says "I swing" (Swing remote). Before sending, it turns
-- the character toward the nearest target (light aim assist: your own
-- client moves your character, so this is instant for you). The server
-- then picks the target itself and decides everything (R5).
--
-- Controls: phone = the big Attack button; PC = click anywhere that isn't a
-- resource node (clicking a node mines it, NodeInput.client.luau).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local combatCfg = Config.Combat
local swingEvent = Remotes.getEvent("Swing")
local COS_ASSIST = math.cos(math.rad(combatCfg.AimAssistConeDegrees))

-- The pickaxe is always in hand; there's nothing to pick from a hotbar.
task.spawn(function()
	-- SetCoreGuiEnabled can fail for a moment while the core scripts load.
	for _ = 1, 10 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
			return
		end
		task.wait(1)
	end
end)

-- ── Aim assist (look only) ───────────────────────────────────────────────

local function targetRoots(): { BasePart }
	local roots = {}
	local function add(model: Instance?)
		if not model then
			return
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(roots, root)
		end
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			add(other.Character)
		end
	end
	for _, npc in CollectionService:GetTagged(combatCfg.CombatTag) do
		add(npc)
	end
	return roots
end

local function faceNearestTarget(root: BasePart)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude == 0 then
		return
	end
	look = look.Unit
	local best: BasePart? = nil
	local bestDistance = combatCfg.AimAssistRange
	for _, target in targetRoots() do
		local flat = Vector3.new(target.Position.X - root.Position.X, 0, target.Position.Z - root.Position.Z)
		local distance = flat.Magnitude
		if distance > 0.1 and distance <= bestDistance and look:Dot(flat.Unit) >= COS_ASSIST then
			best, bestDistance = target, distance
		end
	end
	if best then
		local at = Vector3.new(best.Position.X, root.Position.Y, best.Position.Z)
		root.CFrame = CFrame.lookAt(root.Position, at)
	end
end

local function swing()
	-- A tap in build mode means "put it here", not "attack".
	if player:GetAttribute(Config.Base.BuildUi.ClientModeAttribute) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		faceNearestTarget(root)
	end
	swingEvent:FireServer()
end

-- ── Attack button (big, bottom right, above Jump) ────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "CombatUi"
gui.ResetOnSpawn = false

local size = combatCfg.Ui.ButtonSize * 1.3
local attackButton = Instance.new("TextButton")
attackButton.Name = "Attack"
attackButton.AnchorPoint = Vector2.new(1, 1)
-- Left of the Build button, same height, so the thumb reaches both.
attackButton.Position = UDim2.new(1, -32 - size, 1, -16 - combatCfg.Ui.ButtonSize * 1.6)
attackButton.Size = UDim2.fromOffset(size, size)
attackButton.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
attackButton.BackgroundTransparency = 0.1
attackButton.TextColor3 = Color3.new(1, 1, 1)
attackButton.Font = Enum.Font.GothamBold
attackButton.TextSize = 18
attackButton.Text = "Attack"
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = attackButton
attackButton.Parent = gui
-- PC players click instead; the button only appears on touch screens.
attackButton.Visible = UserInputService.TouchEnabled
gui.Parent = player:WaitForChild("PlayerGui")

attackButton.Activated:Connect(swing)

-- ── PC: click anywhere that isn't a node ─────────────────────────────────

local function clickedNode(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local hitboxes = {}
	for _, node in CollectionService:GetTagged(Config.Nodes.Tag) do
		local hitbox = node:FindFirstChild("Hitbox")
		if hitbox then
			table.insert(hitboxes, hitbox)
		end
	end
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = hitboxes
	return workspace:Raycast(ray.Origin, ray.Direction * Config.Nodes.PickRangeStuds, params) ~= nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if not clickedNode(input.Position) then
		swing()
	end
end)

-- ── Hit flash (everyone sees hits land) ──────────────────────────────────

local fxFolder = Instance.new("Folder")
fxFolder.Name = "HitFx"
fxFolder.Parent = workspace

Remotes.getEvent("HitFx").OnClientEvent:Connect(function(position: Vector3, step: number)
	local finisher = step == #combatCfg.ComboDamageMultipliers
	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = if finisher then Color3.fromRGB(255, 170, 60) else Color3.fromRGB(255, 255, 255)
	flash.Transparency = 0.3
	local diameter = if finisher then 3 else 1.8
	flash.Size = Vector3.new(diameter, diameter, diameter)
	flash.Position = position
	flash.Parent = fxFolder
	game:GetService("Debris"):AddItem(flash, 0.15)
end)
