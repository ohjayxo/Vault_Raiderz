--!strict
-- ScavService: Scav and Scav Captain NPCs (default R15 rigs) with simple
-- server-side AI. ScavWaveService decides when and where they spawn.
--
-- Docs: 04-world-content.md § The PvE ladder (Homestead: Scavs, Scav
-- Captain), § Mobs vs bosses ("PvP-free income floor", material drops),
-- § Scav Waves; 02-core-loop.md § FTUE spec (a Scav "dies in 2-3 hits;
-- drops loot"), § Defenses ("never hard-block").
--
-- AI, every ThinkSeconds:
--   1. A player within AggroRange? Chase and hit them (armor applies).
--   2. Otherwise walk onto the owner's plot (the bridge end, so it doesn't
--      step off the bridge), then to a charged Decoy Vault first (waste
--      time there), then to the owner's Vault Core.
--   3. Survive LootSeconds at the core, in range AND with nothing built in
--      between -> take a share of Exposed and leave (the caller's onLooted
--      does the taking). A wall next to the core stops looting through it.
--   4. No progress for StuckSeconds (walls) -> hop over: defenses delay,
--      they never block. Near the goal there may be no room to land between
--      the walls and it, so the Scav climbs on top of the goal instead.
-- Tagged Config.Combat.CombatTag, so pickaxe swings, aim assist and Shock
-- Traps work on them (step 5). A plain Scav's kill drop goes to whoever
-- landed the last hit (the base owner if a defense did it).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NodeMath = require(ReplicatedStorage.Shared.NodeMath)
local VaultService = require(script.Parent.VaultService)
local ArmorService = require(script.Parent.ArmorService)
local MovementService = require(script.Parent.MovementService)
local CombatService = require(script.Parent.CombatService)
local DefenseService = require(script.Parent.DefenseService)

local scavCfg = Config.Scavs

export type Kind = "Scav" | "Captain"
export type Callbacks = {
	-- A Scav survived at the Vault Core and is about to leave.
	onLooted: (model: Model) -> (),
	-- The Scav is gone: "killed" (killer = last player to hit it, if any),
	-- "looted", or "despawned" (wave ended, owner left).
	onGone: (model: Model, reason: string, killer: Player?) -> (),
}

local lastHitBy: { [Model]: Player } = {}
local folder: Folder
local blockParams = RaycastParams.new()
blockParams.FilterType = Enum.RaycastFilterType.Include

-- True if world geometry or a base piece (other than the goal itself) is
-- between the Scav and its goal.
local function blocked(root: BasePart, goal: BasePart): boolean
	local include: { Instance } = {}
	for _, name in { Config.World.FolderName, Config.Base.LiveFolderName } do
		local found = workspace:FindFirstChild(name)
		if found then
			table.insert(include, found)
		end
	end
	blockParams.FilterDescendantsInstances = include
	local result = workspace:Raycast(root.Position, goal.Position - root.Position, blockParams)
	local goalModel = goal.Parent
	return result ~= nil and not (goalModel and result.Instance:IsDescendantOf(goalModel))
end

local ScavService = {}

-- ── Spawning ─────────────────────────────────────────────────────────────

local function buildRig(kind: Kind): Model
	local stats = if kind == "Captain" then scavCfg.Captain else scavCfg.Scav
	local color = if kind == "Captain" then scavCfg.Colors.Captain else scavCfg.Colors.Scav
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = color
	description.TorsoColor = color
	description.LeftArmColor = color
	description.RightArmColor = color
	description.LeftLegColor = color
	description.RightLegColor = color
	description.HeightScale = stats.Scale
	description.WidthScale = stats.Scale
	description.DepthScale = stats.Scale
	description.HeadScale = stats.Scale
	local rig = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	rig.Name = if kind == "Captain" then "Scav Captain" else "Scav"
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = stats.Health
	humanoid.Health = stats.Health
	humanoid.WalkSpeed = stats.WalkSpeed
	humanoid.DisplayName = rig.Name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	return rig
end

local function vaultCoreOf(ownerId: number): BasePart?
	for _, core in CollectionService:GetTagged(Config.Bank.VaultCoreTag) do
		if core:GetAttribute("OwnerUserId") == ownerId and core:IsDescendantOf(workspace) then
			local hitbox = core:FindFirstChild("Hitbox")
			if hitbox and hitbox:IsA("BasePart") then
				return hitbox
			end
		end
	end
	return nil
end

-- ── AI ───────────────────────────────────────────────────────────────────

local function nearestPlayer(root: BasePart, range: number): (Player?, BasePart?)
	local best: Player?, bestRoot: BasePart? = nil, nil
	local bestDistance = range
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local otherRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and humanoid.Health > 0 and otherRoot then
			local distance = (otherRoot.Position - root.Position).Magnitude
			if distance <= bestDistance then
				best, bestRoot, bestDistance = player, otherRoot, distance
			end
		end
	end
	return best, bestRoot
end

local function faceTowards(root: BasePart, target: Vector3)
	local at = Vector3.new(target.X, root.Position.Y, target.Z)
	if (at - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, at)
	end
end

local function runAi(model: Model, kind: Kind, ownerId: number, entry: Vector3, callbacks: Callbacks)
	local stats = if kind == "Captain" then scavCfg.Captain else scavCfg.Scav
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local nextAttackAt = 0
	local decoy: BasePart? = DefenseService.claimDecoy(ownerId)
	local decoyUntil: number? = nil
	local lootTime = 0
	local bestDistance = math.huge
	local progressAt = os.clock()
	local onPlot = false

	while model.Parent and humanoid.Health > 0 do
		local dt = task.wait(scavCfg.ThinkSeconds)
		if not model.Parent or humanoid.Health <= 0 then
			break
		end
		if MovementService.isStunned(humanoid) then
			continue
		end
		local now = os.clock()

		-- 1. Fight any player who comes close.
		local player, playerRoot = nearestPlayer(root, scavCfg.AggroRange)
		if player and playerRoot then
			if (playerRoot.Position - root.Position).Magnitude <= scavCfg.AttackRange then
				humanoid:MoveTo(root.Position) -- stop
				faceTowards(root, playerRoot.Position)
				if now >= nextAttackAt then
					nextAttackAt = now + stats.AttackSeconds
					local victim = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if victim then
						victim:TakeDamage(stats.Damage * (1 - ArmorService.damageReduction(player)))
						Remotes.getEvent("HitFx"):FireAllClients(playerRoot.Position, 1)
					end
				end
			else
				humanoid:MoveTo(playerRoot.Position)
			end
			progressAt = now -- chasing isn't being stuck
			continue
		end

		-- 2a. Get onto the plot first (walk along the bridge).
		if not onPlot then
			local flat = Vector3.new(entry.X - root.Position.X, 0, entry.Z - root.Position.Z)
			if flat.Magnitude <= 4 then
				onPlot = true
				bestDistance = math.huge
				progressAt = now
			else
				humanoid:MoveTo(entry)
				if flat.Magnitude < bestDistance - 1 then
					bestDistance = flat.Magnitude
					progressAt = now
				elseif now - progressAt >= scavCfg.StuckSeconds then
					model:PivotTo(CFrame.new(entry + Vector3.new(0, 3, 0))) -- blocked on the way in
					onPlot = true
				end
				continue
			end
		end

		-- 2b. Decoy first, then the Vault Core.
		local goal: BasePart? = nil
		if decoy and decoy.Parent then
			goal = decoy
		else
			decoy = nil
			goal = vaultCoreOf(ownerId)
		end
		if not goal then
			humanoid:MoveTo(root.Position) -- nothing to attack: wait
			continue
		end

		local distance = NodeMath.distanceToHitbox(goal, root.Position)
		local reachable = distance <= scavCfg.LootRange and not blocked(root, goal)
		if reachable then
			humanoid:MoveTo(root.Position)
			progressAt = now
			if goal == decoy then
				-- Wasting time at the decoy (02 § Defenses).
				decoyUntil = decoyUntil or now + (Config.Defenses.Kinds :: any).DecoyVault.WasteSeconds
				if now >= (decoyUntil :: number) then
					decoy = nil
					bestDistance = math.huge
				end
			else
				-- 3. Looting the real core.
				lootTime += dt
				if lootTime >= scavCfg.LootSeconds then
					callbacks.onLooted(model)
					callbacks.onGone(model, "looted", nil)
					model:Destroy()
					return
				end
			end
			continue
		end
		lootTime = 0
		humanoid:MoveTo(goal.Position)

		-- 4. Stuck behind something: hop over it.
		if distance < bestDistance - 1 then
			bestDistance = distance
			progressAt = now
		elseif now - progressAt >= scavCfg.StuckSeconds then
			local flat = Vector3.new(goal.Position.X - root.Position.X, 0, goal.Position.Z - root.Position.Z)
			if distance <= scavCfg.LootRange + scavCfg.HopStuds then
				-- Walled in close: no room to land in between, so climb onto it.
				local target = goal.Position + Vector3.new(0, goal.Size.Y / 2 + 3, 0)
				model:PivotTo(CFrame.new(target))
			elseif flat.Magnitude > 0 then
				local target = root.Position + flat.Unit * scavCfg.HopStuds + Vector3.new(0, 6, 0)
				model:PivotTo(CFrame.lookAt(target, target + flat.Unit))
			end
			progressAt = now
			bestDistance = math.huge
		end
	end
end

-- ── Public ───────────────────────────────────────────────────────────────

-- Spawns one Scav attacking `owner`'s base at `position`; it walks to
-- `entry` (the plot's bridge end) before heading for the core.
function ScavService.spawn(kind: Kind, owner: Player, position: Vector3, entry: Vector3, callbacks: Callbacks): Model
	local model = buildRig(kind)
	model:SetAttribute("ScavKind", kind)
	model:SetAttribute("TargetUserId", owner.UserId)
	CollectionService:AddTag(model, scavCfg.Tag)
	CollectionService:AddTag(model, Config.Combat.CombatTag)
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root:SetNetworkOwner(nil) -- the server moves NPCs, never a client

	local parts = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
		end
	end
	local at = root.Position
	print(`[Scavs] spawned {model.Name} for {owner.Name} at ({math.floor(at.X)}, {math.floor(at.Y)}, {math.floor(at.Z)}), {parts} parts`)

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local gone = false
	humanoid.Died:Connect(function()
		if gone then
			return
		end
		gone = true
		local killer = lastHitBy[model]
		lastHitBy[model] = nil
		-- Plain Scavs pay their killer (or the owner, if a defense did it).
		-- The Captain's loot is the wave's job (D107: to the defender).
		if kind == "Scav" then
			local receiver = killer or (if owner.Parent then owner else nil)
			if receiver then
				VaultService.grant(receiver, scavCfg.KillDrop)
				VaultService.depositScrap(receiver, scavCfg.KillScrap)
			end
		end
		callbacks.onGone(model, "killed", killer)
		Debris:AddItem(model, 3)
	end)
	-- Anything else that removes it (despawn) also counts as gone once.
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) and not gone then
			gone = true
			lastHitBy[model] = nil
			callbacks.onGone(model, "despawned", nil)
		end
	end)

	task.spawn(runAi, model, kind, owner.UserId, entry, {
		onLooted = callbacks.onLooted,
		onGone = function(m, reason, killer)
			gone = true -- set before Destroy so AncestryChanged doesn't report twice
			callbacks.onGone(m, reason, killer)
		end,
	})
	return model
end

function ScavService.start()
	folder = Instance.new("Folder")
	folder.Name = scavCfg.FolderName
	folder.Parent = workspace

	-- Remember who hit each Scav last, for kill drops.
	CombatService.Hit:Connect(function(attacker: Player, target: Model)
		if CollectionService:HasTag(target, scavCfg.Tag) then
			lastHitBy[target] = attacker
		end
	end)
end

return ScavService
