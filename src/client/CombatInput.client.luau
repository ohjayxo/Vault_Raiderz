--!strict
-- Swinging the pickaxe (step 5). 02-core-loop.md § Combat feel: "3-hit
-- combo, generous hitboxes, light aim assist".
--
-- The client only says "I swing" (Swing remote). Before sending, it turns
-- the character toward the nearest target (light aim assist: your own
-- client moves your character, so this is instant for you). The server
-- then picks the target itself and decides everything (R5).
--
-- Controls: phone = one big context button (Josh, 2026-09-24): Attack when an
-- enemy is in reach, otherwise Mine on the nearest node in reach, and holding it
-- repeats. Tapping a node directly still mines it too (NodeInput.client.luau).
-- PC = click anywhere that isn't a resource node (clicking a node mines it).
-- Either way the client only sends intents (Swing / MineNode); the server checks
-- distance, cooldowns and rate limits (R5).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local NodeMath = require(Shared:WaitForChild("NodeMath"))
local UiStyle = require(Shared:WaitForChild("UiStyle"))

local player = Players.LocalPlayer
local combatCfg = Config.Combat
local swingEvent = Remotes.getEvent("Swing")
local mineEvent = Remotes.getEvent("MineNode")
local contextCfg = combatCfg.Ui.ContextButton
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
	-- Players under FTUE PvP protection can't be hit (or hit anyone), so they
	-- are not targets: they must not steal the button from a node either.
	local protectedAttr = combatCfg.PvpProtectedAttribute
	if player:GetAttribute(protectedAttr) ~= true then
		for _, other in Players:GetPlayers() do
			if other ~= player and other:GetAttribute(protectedAttr) ~= true then
				add(other.Character)
			end
		end
	end
	for _, npc in CollectionService:GetTagged(combatCfg.CombatTag) do
		add(npc)
	end
	return roots
end

local function findTarget(root: BasePart): BasePart?
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude == 0 then
		return nil
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
	return best
end

local function faceNearestTarget(root: BasePart)
	local best = findTarget(root)
	if best then
		local at = Vector3.new(best.Position.X, root.Position.Y, best.Position.Z)
		root.CFrame = CFrame.lookAt(root.Position, at)
	end
end

-- The closest live node within mining reach (depleted nodes are destroyed by
-- the server, so a tagged node is always minable). Same distance the server
-- and the "walk closer" hint use.
local function nearestNodeInReach(root: BasePart): Instance?
	local best: Instance? = nil
	local bestDistance = Config.Nodes.MineDistance
	for _, node in CollectionService:GetTagged(Config.Nodes.Tag) do
		local hitbox = node:FindFirstChild("Hitbox")
		if hitbox and hitbox:IsA("BasePart") and node:IsDescendantOf(workspace) then
			local distance = NodeMath.distanceToHitbox(hitbox, root.Position)
			if distance <= bestDistance then
				best, bestDistance = node, distance
			end
		end
	end
	return best
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

-- ── Context button (big, bottom right, above Jump) ──────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "CombatUi"
gui.ResetOnSpawn = false

local size = combatCfg.Ui.ButtonSize * 1.3
local attackButton = UiStyle.hudButton(gui, "Attack", "danger", size, size, true)
attackButton.Name = "Attack"
attackButton.AnchorPoint = Vector2.new(1, 1)
-- Left of the Build button, same height, so the thumb reaches both.
attackButton.Position = UDim2.new(1, -32 - size, 1, -16 - combatCfg.Ui.ButtonSize * 1.6)
attackButton.TextSize = Config.UiStyle.TextSize.Title
-- PC players click instead; the button only appears on touch screens.
attackButton.Visible = UserInputService.TouchEnabled
gui.Parent = player:WaitForChild("PlayerGui")

type Action = "Attack" | "Mine"
local shown: Action = "Attack" -- what the label says; a press does the same

local function playerRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- What a press does right now: an enemy in reach always wins (a Scav hitting
-- you matters more than a rock); otherwise Mine only while the label says Mine,
-- so the button never does something other than what it shows.
local function currentAction(): (Action, Instance?)
	local root = playerRoot()
	if root and not findTarget(root) and shown == "Mine" then
		local node = nearestNodeInReach(root)
		if node then
			return "Mine", node
		end
	end
	return "Attack", nil
end

local function act()
	if player:GetAttribute(Config.Base.BuildUi.ClientModeAttribute) then
		return -- a tap in build mode means "put it here"
	end
	local action, node = currentAction()
	if action == "Mine" and node then
		mineEvent:FireServer(node)
	else
		swing()
	end
end

-- The label follows what is near. An enemy flips it to Attack at once; going
-- back to Mine waits a moment, so it doesn't flicker mid-fight.
local lastEnemySeen = -math.huge
local function refreshLabel()
	local root = playerRoot()
	local action: Action = "Attack"
	if root then
		if findTarget(root) then
			lastEnemySeen = os.clock()
		elseif os.clock() - lastEnemySeen >= contextCfg.FlipBackSeconds and nearestNodeInReach(root) then
			action = "Mine"
		end
	end
	if action ~= shown then
		shown = action
		attackButton.Text = action
		UiStyle.setButtonKind(attackButton, if action == "Mine" then "primary" else "danger")
	end
end
if UserInputService.TouchEnabled then
	task.spawn(function()
		while true do
			task.wait(contextCfg.CheckSeconds)
			if not attackButton.Visible then
				continue
			end
			refreshLabel()
		end
	end)
end

-- Hold to repeat, at the same pace the server accepts (its cooldowns still
-- decide; anything faster is ignored quietly).
local holdToken = 0
attackButton.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	holdToken += 1
	local token = holdToken
	task.spawn(function()
		while holdToken == token and attackButton.Visible do
			act()
			local action = currentAction()
			task.wait(if action == "Mine" then Config.Nodes.MineCooldownSeconds else combatCfg.SwingIntervalSeconds)
		end
	end)
	local ended: RBXScriptConnection
	ended = input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
			ended:Disconnect()
			if holdToken == token then
				holdToken += 1
			end
		end
	end)
end)

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
