--!strict
-- CombatService: melee combat with the pickaxe, health, death and respawn.
--
-- Docs: 02-core-loop.md § Combat (melee only, the pickaxe is the weapon),
-- § Combat feel (3-hit combo, generous hitboxes, light aim assist, short
-- knockback; fights 5-10 s [PH]); 01-pillars.md R5, R8.
--
-- * The client sends only "I swing" (Swing remote). The server checks
--   timing (swing interval + anti-spam), then itself picks the best target
--   in front of the attacker: range, facing cone, line of sight (walls block
--   hits), smoke. The client can't name a target, so it can't fake a hit.
-- * Damage = pickaxe damage x combo multiplier, minus the target's armor
--   reduction. Hit 3 of a combo is a finisher with bigger knockback.
-- * Targets: other players and NPCs tagged Config.Combat.CombatTag (Scavs,
--   step 6). FTUE rule 3: players with the PvpProtected attribute can't hit
--   or be hit by players (step 14 sets it).
-- * Dying costs time only: respawn next to your own plot (Josh's call, step 5).
-- * The pickaxe is a greybox Tool always in hand; the swing animation is
--   Roblox's built-in "Slash" (the server drops a "toolanim" value in the
--   tool and the default Animate script plays it).
-- * Hit fires for other systems: the Chase (step 7, "any player who lands a
--   hit knocks the loot loose") and Scavs (step 6).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local PickaxeService = require(script.Parent.PickaxeService)
local ArmorService = require(script.Parent.ArmorService)
local MovementService = require(script.Parent.MovementService)
local GadgetService = require(script.Parent.GadgetService)
local PlotService = require(script.Parent.PlotService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CosmeticService = require(script.Parent.CosmeticService)

local combatCfg = Config.Combat
local TOOL_NAME = "Pickaxe"
local COS_CONE = math.cos(math.rad(combatCfg.AimConeDegrees))

local lastSwingAt: { [Player]: number } = {}
local comboStep: { [Player]: number } = {}
local diedOnce: { [Player]: boolean } = {}
local losParams = RaycastParams.new()
local hitEvent = Instance.new("BindableEvent")

local CombatService = {}

-- Fires (attacker: Player, targetModel: Model, damage: number, comboStep).
CombatService.Hit = hitEvent.Event

-- ── The pickaxe tool (greybox: stick + block, coloured by tier) ──────────

local function buildTool(player: Player): Tool
	local look = combatCfg.ToolLook
	local tier = PickaxeService.getTier(player)
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true -- swings go through the Swing remote only
	-- Held like the classic sword: the long axis (Z) points out of the fist.
	tool.GripPos = Vector3.new(0, 0, -look.HandleSize.Z / 2 + 0.4)
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)

	-- An equipped skin replaces the whole look (Josh's call, 2026-09-22);
	-- otherwise the tier's template (ServerStorage.PickaxeTiers.<Tier>).
	-- Template contract: Handle = the grip, Visual = the art. Welding the art
	-- to the Handle is the only thing code does with a Visual. No template
	-- at all = the code greybox below.
	local tierFolder = ServerStorage:FindFirstChild(combatCfg.TierFolderName)
	local tierName = combatCfg.PickaxeTiers[math.clamp(tier, 1, #combatCfg.PickaxeTiers)]
	local tierTemplate = tierFolder and tierFolder:FindFirstChild(tierName)
	local skin: Instance? = CosmeticService.equippedTemplate(player)
		or (if tierTemplate and tierTemplate:FindFirstChild("Handle") then tierTemplate else nil)
	if skin then
		local clone = skin:Clone()
		local skinHandle = clone:FindFirstChild("Handle") :: BasePart
		local visual = clone:FindFirstChild("Visual")
		skinHandle.CanCollide = false
		skinHandle.CanQuery = false
		skinHandle.CanTouch = false
		skinHandle.Massless = true
		if visual then
			for _, descendant in visual:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Anchored = false
					descendant.Massless = true
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = skinHandle
					weld.Part1 = descendant
					weld.Parent = descendant
				end
			end
			visual.Parent = tool
		end
		skinHandle.Parent = tool
		clone:Destroy()
		return tool
	end

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = look.HandleSize
	handle.Color = look.TierColors[1] -- the shaft is always wood
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = look.HeadSize
	head.Color = look.TierColors[math.clamp(tier, 1, #look.TierColors)]
	head.Material = Enum.Material.Metal
	head.CanCollide = false
	head.CanQuery = false
	head.CanTouch = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 0, look.HandleSize.Z / 2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = head
	head.Parent = tool
	return tool
end

-- Gives the character a fresh pickaxe (on spawn and when the tier changes).
local function equipTool(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local containers: { Instance } = { character }
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end
	for _, container in containers do
		local old = container:FindFirstChild(TOOL_NAME)
		if old then
			old:Destroy()
		end
	end
	humanoid:EquipTool(buildTool(player))
end

-- Plays the built-in swing animation (also used by mining).
function CombatService.playSwing(player: Player)
	local character = player.Character
	local tool = character and character:FindFirstChild(TOOL_NAME)
	if not tool then
		return
	end
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	Debris:AddItem(anim, 1) -- the Animate script normally removes it first
end

-- ── Targets ──────────────────────────────────────────────────────────────

type Target = { model: Model, humanoid: Humanoid, root: BasePart, player: Player? }

local function asTarget(model: Instance): Target?
	if not model:IsA("Model") or not model:IsDescendantOf(workspace) then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return { model = model, humanoid = humanoid, root = root, player = Players:GetPlayerFromCharacter(model) }
end

local function isProtected(player: Player): boolean
	return player:GetAttribute(combatCfg.PvpProtectedAttribute) == true
end

-- The best target in front of `attacker`, or nil. Server-side aim assist:
-- nearest to the centre of the cone wins.
local function pickTarget(attacker: Player, root: BasePart): Target?
	local candidates: { Target } = {}
	for _, other in Players:GetPlayers() do
		if other ~= attacker and other.Character and not isProtected(other) and not isProtected(attacker) then
			local target = asTarget(other.Character)
			if target then
				table.insert(candidates, target)
			end
		end
	end
	for _, npc in CollectionService:GetTagged(combatCfg.CombatTag) do
		local target = asTarget(npc)
		if target then
			table.insert(candidates, target)
		end
	end

	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude == 0 then
		return nil
	end
	look = look.Unit
	local best: Target? = nil
	local bestScore = math.huge
	for _, target in candidates do
		local offset = target.root.Position - root.Position
		local distance = offset.Magnitude
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if distance > combatCfg.Range then
			continue
		end
		-- Standing right on top of each other counts as "in front".
		local facing = if flat.Magnitude < 1 then 1 else look:Dot(flat.Unit)
		if facing < COS_CONE then
			continue
		end
		if GadgetService.hiddenBySmoke(target.root.Position, root.Position) then
			continue
		end
		if workspace:Raycast(root.Position, offset, losParams) then
			continue -- a wall or the ground is in the way
		end
		local score = distance * (2 - facing)
		if score < bestScore then
			best, bestScore = target, score
		end
	end
	return best
end

-- ── Hits ─────────────────────────────────────────────────────────────────

local function knockback(target: Target, from: Vector3, speed: number)
	local flat = Vector3.new(target.root.Position.X - from.X, 0, target.root.Position.Z - from.Z)
	local direction = if flat.Magnitude > 0 then flat.Unit else Vector3.zAxis
	local kb = combatCfg.Knockback
	-- A short-lived velocity constraint. It replicates, so it also moves
	-- player characters (whose physics their own client runs).
	local attachment = Instance.new("Attachment")
	attachment.Parent = target.root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = direction * speed + Vector3.new(0, kb.UpSpeed, 0)
	velocity.Parent = attachment
	Debris:AddItem(attachment, kb.Seconds)
end

local function hit(attacker: Player, root: BasePart, target: Target, step: number)
	local damage = PickaxeService.damage(attacker) * combatCfg.ComboDamageMultipliers[step]
	local resist = 0
	if target.player then
		damage *= 1 - ArmorService.damageReduction(target.player)
		resist = ArmorService.knockbackResist(target.player)
	end
	damage = math.floor(damage * 10 + 0.5) / 10
	target.humanoid:TakeDamage(damage)

	local kb = combatCfg.Knockback
	local speed = (if step == #combatCfg.ComboDamageMultipliers then kb.FinisherSpeed else kb.Speed)
		* PickaxeService.knockbackMultiplier(attacker)
		* (1 - resist)
	knockback(target, root.Position, speed)

	Remotes.getEvent("HitFx"):FireAllClients(target.root.Position, step)
	hitEvent:Fire(attacker, target.model, damage, step)
end

local function onSwing(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or MovementService.isStunned(humanoid) then
		return
	end
	-- Faster than the swing interval: a human mashing; ignored quietly.
	local now = os.clock()
	local last = lastSwingAt[player]
	if last and now - last < PickaxeService.swingInterval(player) then
		return
	end
	local combo = #combatCfg.ComboDamageMultipliers
	local step = if last and now - last <= combatCfg.ComboWindowSeconds then (comboStep[player] or 0) % combo + 1 else 1
	lastSwingAt[player] = now
	comboStep[player] = step

	CombatService.playSwing(player)
	local target = pickTarget(player, root)
	if target then
		hit(player, root, target, step)
	end
end

-- ── Health, death, respawn ───────────────────────────────────────────────

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	humanoid.MaxHealth = combatCfg.MaxHealth
	humanoid.Health = combatCfg.MaxHealth
	humanoid.Died:Connect(function()
		diedOnce[player] = true
		comboStep[player] = nil
	end)
	-- After a death, come back next to your own plot. (The very first
	-- spawn stays at the Homestead spawn; the FTUE owns that, step 14.)
	if diedOnce[player] then
		local spawnAt = PlotService.getSpawnCFrame(player)
		if spawnAt then
			character:PivotTo(spawnAt)
		end
	end
	equipTool(player)
end

function CombatService.start()
	Players.RespawnTime = combatCfg.RespawnSeconds

	local world = workspace:WaitForChild(Config.World.FolderName)
	losParams.FilterType = Enum.RaycastFilterType.Include
	local function refreshLos()
		local include: { Instance } = { world }
		local pieces = workspace:FindFirstChild(Config.Base.LiveFolderName)
		if pieces then
			table.insert(include, pieces)
		end
		losParams.FilterDescendantsInstances = include
	end
	refreshLos()
	workspace.ChildAdded:Connect(refreshLos) -- BasePieces is created by PlotService

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwingAt[player] = nil
		comboStep[player] = nil
		diedOnce[player] = nil
	end)
	-- New tier = new head colour; the first spawn may come before the
	-- profile (and so the real tier) has loaded.
	PickaxeService.Changed:Connect(equipTool)
	CosmeticService.Changed:Connect(equipTool)
	PlayerDataService.Loaded:Connect(equipTool)

	local rate = combatCfg.SwingRateLimit
	local allow = RateLimiter.newBucket("Swing", rate.Burst, rate.PerSecond)
	Remotes.getEvent("Swing").OnServerEvent:Connect(function(player: Player)
		if allow(player) then
			onSwing(player)
		end
	end)
end

return CombatService
