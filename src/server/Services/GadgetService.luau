--!strict
-- GadgetService: the four single-use gadgets. 02-core-loop.md § Gadgets
-- (D108): "Skill expression without twitch aim."
--
-- * The client asks "use a Smoke Bomb"; the server checks the player has
--   one, isn't carrying raid loot (02 § The Chase point 2, step 7), respects
--   a cooldown, consumes it (InventoryService), then makes the effect.
-- * R8: no gadget touches damage.
-- * Gadgets come from Workshop crafting (step 10); Studio debug only now.
--
--   Smoke Bomb   cloud at your feet; nobody can target a player inside it
--                from further than SeeThroughStuds (CombatService asks).
--   Sprint Serum speed boost via MovementService.
--   Shock Trap   thrown ahead, lands, arms; the first other player or NPC
--                to touch it is stunned (Josh's call, step 5).
--   Disruptor    switches off the nearest defense on someone else's base
--                (DefenseService). Not consumed if there's none in range.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local AnomalyLog = require(ServerScriptService.Util.AnomalyLog)
local InventoryService = require(script.Parent.InventoryService)
local MovementService = require(script.Parent.MovementService)
local DefenseService = require(script.Parent.DefenseService)

local gadgetCfg = Config.Gadgets
local combatCfg = Config.Combat

type Cloud = { position: Vector3, radius: number, untilTime: number }

local clouds: { Cloud } = {}
local activeTraps: { [Player]: number } = {}
local effectsFolder: Folder
local logAnomaly = AnomalyLog.new("Gadget")

local GadgetService = {}

-- True if smoke hides `targetPosition` from someone at `fromPosition`.
function GadgetService.hiddenBySmoke(targetPosition: Vector3, fromPosition: Vector3): boolean
	local now = os.clock()
	for _, cloud in clouds do
		if now < cloud.untilTime
			and (targetPosition - cloud.position).Magnitude <= cloud.radius
			and (targetPosition - fromPosition).Magnitude > gadgetCfg.Smoke.SeeThroughStuds
		then
			return true
		end
	end
	return false
end

-- ── Effects (greybox visuals, server-made so everyone sees them) ─────────

local function effectPart(name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Position = position
	part.Color = color
	part.Parent = effectsFolder
	return part
end

local function smokeBomb(root: BasePart)
	local smoke = gadgetCfg.Smoke
	local position = root.Position
	table.insert(clouds, { position = position, radius = smoke.Radius, untilTime = os.clock() + smoke.Seconds })

	local cloud = effectPart("SmokeCloud", Vector3.new(1, 1, 1), position, Color3.fromRGB(200, 200, 200))
	cloud.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(190, 190, 195))
	emitter.Size = NumberSequence.new(smoke.Radius * 0.6, smoke.Radius * 0.9)
	emitter.Transparency = NumberSequence.new(0.1, 0.5)
	emitter.Lifetime = NumberRange.new(2, 3)
	emitter.Rate = 40
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = cloud
	task.delay(smoke.Seconds - 2, function()
		emitter.Enabled = false -- let the last puffs fade out
	end)
	Debris:AddItem(cloud, smoke.Seconds + 1)
	-- Forget expired clouds so the list never grows.
	task.delay(smoke.Seconds, function()
		local now = os.clock()
		for i = #clouds, 1, -1 do
			if clouds[i].untilTime <= now then
				table.remove(clouds, i)
			end
		end
	end)
end

local function humanoidOf(part: BasePart): Humanoid?
	local model = part:FindFirstAncestorOfClass("Model")
	return if model then model:FindFirstChildOfClass("Humanoid") else nil
end

local function shockTrap(player: Player, root: BasePart)
	local trapCfg = gadgetCfg.ShockTrap
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local ahead = root.Position + (if flat.Magnitude > 0 then flat.Unit else Vector3.zAxis) * trapCfg.ThrowDistance

	-- Land on whatever's below: the world or base pieces, never players.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local include: { Instance } = { workspace:FindFirstChild(Config.World.FolderName) :: Instance }
	local pieces = workspace:FindFirstChild(Config.Base.LiveFolderName)
	if pieces then
		table.insert(include, pieces)
	end
	params.FilterDescendantsInstances = include
	local hit = workspace:Raycast(ahead + Vector3.new(0, 10, 0), Vector3.new(0, -60, 0), params)
	local ground = if hit then hit.Position else root.Position - Vector3.new(0, 3, 0)

	-- The trap's look: ServerStorage.GadgetTemplates.ShockTrap (Hitbox =
	-- the pad that stuns on touch, Visual = art; the model gets an "Armed"
	-- attribute when live), else a greybox pad.
	local templates = ServerStorage:FindFirstChild(gadgetCfg.TemplateFolderName)
	local template = templates and templates:FindFirstChild("ShockTrap")
	local templateHitbox = template and template:FindFirstChild("Hitbox")
	local trap: Instance
	local pad: BasePart
	local greybox: BasePart? = nil
	if template and template:IsA("Model") and templateHitbox and templateHitbox:IsA("BasePart") then
		local model = template:Clone()
		local hitbox = model:FindFirstChild("Hitbox") :: BasePart
		model:PivotTo(CFrame.new(ground + Vector3.new(0, hitbox.Size.Y / 2, 0)) * hitbox.CFrame:ToObjectSpace(model:GetPivot()))
		hitbox.CanCollide = false
		hitbox.CanTouch = false
		model.Parent = effectsFolder
		trap, pad = model, hitbox
	else
		local part = effectPart("ShockTrap", trapCfg.Size, ground + Vector3.new(0, trapCfg.Size.Y / 2, 0), Color3.fromRGB(255, 220, 60))
		part.Material = Enum.Material.Neon
		part.Transparency = 0.4 -- arming
		trap, pad, greybox = part, part, part
	end
	activeTraps[player] = (activeTraps[player] or 0) + 1

	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		trap:Destroy()
		activeTraps[player] = math.max(0, (activeTraps[player] or 1) - 1)
	end

	task.delay(trapCfg.ArmSeconds, function()
		if done then
			return
		end
		if greybox then
			greybox.Transparency = 0
		end
		trap:SetAttribute("Armed", true)
		pad.CanTouch = true
		pad.Touched:Connect(function(other: BasePart)
			if done then
				return
			end
			local humanoid = humanoidOf(other)
			if not humanoid or humanoid.Health <= 0 or humanoid.Parent == player.Character then
				return
			end
			local victim = Players:GetPlayerFromCharacter(humanoid.Parent)
			if victim then
				-- FTUE rule 3: protected players can't be hurt by players, and
				-- can't hurt them either.
				local protectedAttr = combatCfg.PvpProtectedAttribute
				if victim:GetAttribute(protectedAttr) or player:GetAttribute(protectedAttr) then
					return
				end
			elseif not CollectionService:HasTag(humanoid.Parent :: Instance, combatCfg.CombatTag) then
				return
			end
			MovementService.stun(humanoid, trapCfg.StunSeconds)
			finish()
		end)
	end)
	task.delay(trapCfg.LifetimeSeconds, finish)
end

-- ── Using a gadget ───────────────────────────────────────────────────────

local isGadget: { [string]: boolean } = {}
for _, gadgetId in gadgetCfg.Order do
	isGadget[gadgetId] = true
end

local function use(player: Player, gadgetArg: unknown): (boolean, string?)
	if typeof(gadgetArg) ~= "string" or not isGadget[gadgetArg :: string] then
		logAnomaly(player, "tried to use an unknown gadget")
		return false, "Invalid"
	end
	local gadgetId = gadgetArg :: string
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false, "Dead"
	end
	if player:GetAttribute(gadgetCfg.CarryingLootAttribute) then
		return false, "Carrying" -- 02 § The Chase point 2
	end
	local disruptTarget: Model? = nil
	if gadgetId == "Disruptor" then
		disruptTarget = DefenseService.findDisruptTarget(player, root.Position)
		if not disruptTarget then
			return false, "NoDefense"
		end
	end
	if gadgetId == "ShockTrap" and (activeTraps[player] or 0) >= gadgetCfg.ShockTrap.MaxActivePerPlayer then
		return false, "TooManyTraps"
	end
	if not InventoryService.consume(player, gadgetId, 1) then
		return false, "NoneLeft"
	end

	if gadgetId == "SmokeBomb" then
		smokeBomb(root)
	elseif gadgetId == "SprintSerum" then
		local serum = gadgetCfg.SprintSerum
		MovementService.setMultiplierFor(humanoid, "SprintSerum", serum.SpeedMultiplier, serum.Seconds)
	elseif gadgetId == "ShockTrap" then
		shockTrap(player, root)
	elseif gadgetId == "Disruptor" and disruptTarget then
		DefenseService.disable(disruptTarget, gadgetCfg.Disruptor.Seconds)
	end
	print(`[Gadget] {player.Name} used a {gadgetCfg.Names[gadgetId]}`)
	return true, nil
end

function GadgetService.start()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "GadgetEffects"
	effectsFolder.Parent = workspace

	Players.PlayerRemoving:Connect(function(player)
		activeTraps[player] = nil
	end)

	local allow = RateLimiter.new("UseGadget", gadgetCfg.UseCooldownSeconds)
	Remotes.getFunction("UseGadget").OnServerInvoke = function(player: Player, gadgetArg: unknown): (boolean, string?)
		if not allow(player) then
			return false, "Busy"
		end
		return use(player, gadgetArg)
	end
end

return GadgetService
