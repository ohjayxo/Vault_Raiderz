--!strict
-- DefenseService: the six base defenses. The only service that writes the
-- DefenseUse section (charges used per defense piece).
--
-- Docs: 02-core-loop.md § Defenses (D108): "defenses delay and detect. They
-- never hard-block." Limited slots (PlotService enforces them at
-- placement), charges that deplete when triggered and cost resources to
-- refill.
--
-- * Defenses are base pieces tagged Config.Defenses.Tag, carrying Kind,
--   PieceId and OwnerUserId (PlotService spawns them).
-- * Only intruders set them off (Josh's call, step 6): Scavs attacking this
--   base, and from step 7 players raiding it (Player attribute
--   Config.Defenses.RaidingAttribute = the owner's UserId). Visitors never
--   burn charges or get hurt.
-- * Charges show on the model (attributes Charges / MaxCharges): 02 calls
--   defense "a loadout puzzle raiders can read and counter".
--
--   TripwireAlarm  intruder in range -> alert owner, highlight intruder.
--                  Range shrinks with the intruder's Silent movement ranks.
--   SpikeFloor     slows intruders standing on it (MovementService).
--   ShockFence     brief stun on contact.
--   DecoyVault     Scavs go there first and waste time (raids: step 7).
--   GuardDrone     zaps the nearest intruder for a little damage.
--   LockUpgrade    makes lockpicking harder (step 7 reads lockBonus).
-- A Disruptor gadget switches one defense off for a while (disruptNearest).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NodeMath = require(ReplicatedStorage.Shared.NodeMath)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local AnomalyLog = require(ServerScriptService.Util.AnomalyLog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local VaultService = require(script.Parent.VaultService)
local MovementService = require(script.Parent.MovementService)
local PickaxeService = require(script.Parent.PickaxeService)
local ArmorService = require(script.Parent.ArmorService)

local OWNER = "DefenseService"
local defenseCfg = Config.Defenses
local kindCfgs: { [string]: any } = defenseCfg.Kinds :: any
local SILENT_PER_RANK = (function(): number
	for _, upgrade in (Config.Combat.Upgrades :: any).Mobility do
		if upgrade.Id == "SilentMovement" then
			return upgrade.PerRank
		end
	end
	return 0
end)()

type Defense = {
	model: Model,
	hitbox: BasePart,
	kind: string,
	pieceId: string,
	ownerId: number,
	lastHit: { [Model]: number }, -- intruder -> last time this defense fired at it
	slowed: { [Humanoid]: boolean }, -- SpikeFloor: who it's slowing now
	nextZapAt: number,
	disabledUntil: number,
}
type Intruder = { model: Model, humanoid: Humanoid, root: BasePart, player: Player? }

local defenses: { [Model]: Defense } = {}
local logAnomaly = AnomalyLog.new("Defense")

local DefenseService = {}

-- ── Charges ──────────────────────────────────────────────────────────────

local function usedOf(ownerId: number, pieceId: string): number
	local owner = Players:GetPlayerByUserId(ownerId)
	local use = owner and PlayerDataService.get(owner, "DefenseUse")
	return if use then use[pieceId] or 0 else 0
end

local function chargesLeft(defense: Defense): number
	return math.max(0, kindCfgs[defense.kind].Charges - usedOf(defense.ownerId, defense.pieceId))
end

local function showCharges(defense: Defense)
	defense.model:SetAttribute("Charges", chargesLeft(defense))
	defense.model:SetAttribute("MaxCharges", kindCfgs[defense.kind].Charges)
end

local function alertOwner(ownerId: number, kind: string, text: string)
	local owner = Players:GetPlayerByUserId(ownerId)
	if owner then
		Remotes.getEvent("BaseAlert"):FireClient(owner, kind, text)
	end
end

-- Uses one charge. False (and nothing happens) if it's empty or its owner
-- isn't loaded.
local function spendCharge(defense: Defense): boolean
	local owner = Players:GetPlayerByUserId(defense.ownerId)
	if not owner or chargesLeft(defense) <= 0 then
		return false
	end
	local ok = PlayerDataService.update(owner, "DefenseUse", OWNER, function(use: { [string]: number })
		use[defense.pieceId] = (use[defense.pieceId] or 0) + 1
		return use
	end)
	if not ok then
		return false
	end
	showCharges(defense)
	if chargesLeft(defense) == 0 then
		alertOwner(defense.ownerId, "DefenseEmpty", `Your {defense.kind} is out of charges: refill it in Build > Edit`)
	end
	return true
end

local function isActive(defense: Defense): boolean
	return defense.model.Parent ~= nil
		and workspace:GetServerTimeNow() >= defense.disabledUntil
		and chargesLeft(defense) > 0
end

-- ── Intruders ────────────────────────────────────────────────────────────

-- Scavs attacking this owner's base, and (step 7) players raiding it.
local function intrudersOf(ownerId: number): { Intruder }
	local list: { Intruder } = {}
	local function add(model: Model, player: Player?)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(list, { model = model, humanoid = humanoid, root = root, player = player })
		end
	end
	for _, scav in CollectionService:GetTagged(Config.Scavs.Tag) do
		if scav:IsA("Model") and scav:GetAttribute("TargetUserId") == ownerId and scav:IsDescendantOf(workspace) then
			add(scav, nil)
		end
	end
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(defenseCfg.RaidingAttribute) == ownerId and player.Character then
			add(player.Character, player)
		end
	end
	return list
end

local function readyFor(defense: Defense, intruder: Intruder, now: number, gap: number): boolean
	local last = defense.lastHit[intruder.model]
	return last == nil or now - last >= gap
end

-- ── Per-defense behaviour ────────────────────────────────────────────────

local function markIntruder(model: Model, seconds: number)
	local old = model:FindFirstChild("TripwireMark")
	if old then
		old:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "TripwireMark"
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.fromRGB(255, 60, 60)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- seen through walls
	highlight.Parent = model
	Debris:AddItem(highlight, seconds)
end

local function tripwire(defense: Defense, intruders: { Intruder }, now: number)
	local cfg = kindCfgs.TripwireAlarm
	for _, intruder in intruders do
		local radius = cfg.Radius
		if intruder.player then
			radius *= math.max(0, 1 - SILENT_PER_RANK * PickaxeService.rank(intruder.player, "SilentMovement"))
		end
		if NodeMath.distanceToHitbox(defense.hitbox, intruder.root.Position) <= radius
			and readyFor(defense, intruder, now, cfg.RetriggerSeconds)
			and spendCharge(defense)
		then
			defense.lastHit[intruder.model] = now
			markIntruder(intruder.model, cfg.MarkSeconds)
			alertOwner(defense.ownerId, "Tripwire", "Tripwire! Someone is at your base")
		end
	end
end

-- Standing on the plate: inside its footprint, up to a few studs above.
local function onPlate(hitbox: BasePart, position: Vector3): boolean
	local localPoint = hitbox.CFrame:PointToObjectSpace(position)
	return math.abs(localPoint.X) <= hitbox.Size.X / 2 and math.abs(localPoint.Z) <= hitbox.Size.Z / 2
		and localPoint.Y >= -1 and localPoint.Y <= 6
end

local function spikeFloor(defense: Defense, intruders: { Intruder })
	local cfg = kindCfgs.SpikeFloor
	local key = `Spike:{defense.pieceId}`
	local still: { [Humanoid]: boolean } = {}
	for _, intruder in intruders do
		if onPlate(defense.hitbox, intruder.root.Position) then
			-- One charge per entry; someone already on it stays slowed.
			if defense.slowed[intruder.humanoid] or spendCharge(defense) then
				still[intruder.humanoid] = true
				if not defense.slowed[intruder.humanoid] then
					MovementService.setMultiplier(intruder.humanoid, key, cfg.SlowMultiplier)
				end
			end
		end
	end
	for humanoid in defense.slowed do
		if not still[humanoid] then
			MovementService.setMultiplier(humanoid, key, nil)
		end
	end
	defense.slowed = still
end

local function releaseSlowed(defense: Defense)
	for humanoid in defense.slowed do
		MovementService.setMultiplier(humanoid, `Spike:{defense.pieceId}`, nil)
	end
	defense.slowed = {}
end

local function shockFence(defense: Defense, intruders: { Intruder }, now: number)
	local cfg = kindCfgs.ShockFence
	for _, intruder in intruders do
		if NodeMath.distanceToHitbox(defense.hitbox, intruder.root.Position) <= cfg.Radius
			and readyFor(defense, intruder, now, cfg.RetriggerSeconds)
			and spendCharge(defense)
		then
			defense.lastHit[intruder.model] = now
			MovementService.stun(intruder.humanoid, cfg.StunSeconds)
		end
	end
end

local function zapBeam(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 80, 80)
	beam.Size = Vector3.new(0.2, 0.2, length)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	beam.Parent = workspace
	Debris:AddItem(beam, 0.15)
end

local function guardDrone(defense: Defense, intruders: { Intruder }, now: number)
	local cfg = kindCfgs.GuardDrone
	if now < defense.nextZapAt then
		return
	end
	local best: Intruder? = nil
	local bestDistance = cfg.Radius
	for _, intruder in intruders do
		local distance = NodeMath.distanceToHitbox(defense.hitbox, intruder.root.Position)
		if distance <= bestDistance then
			best, bestDistance = intruder, distance
		end
	end
	if not best or not spendCharge(defense) then
		return
	end
	defense.nextZapAt = now + cfg.ZapSeconds
	local damage = cfg.ZapDamage
	if best.player then
		damage *= 1 - ArmorService.damageReduction(best.player)
	end
	best.humanoid:TakeDamage(damage)
	local top = defense.hitbox.Position + Vector3.new(0, defense.hitbox.Size.Y / 2 - 1, 0)
	zapBeam(top, best.root.Position)
end

local function tick()
	local now = os.clock()
	-- One intruder list per owner per tick, shared by their defenses.
	local byOwner: { [number]: { Intruder } } = {}
	for _, defense in defenses do
		if defense.kind == "DecoyVault" or defense.kind == "LockUpgrade" then
			continue -- used on demand, not by zones
		end
		if not isActive(defense) then
			if next(defense.slowed) then
				releaseSlowed(defense)
			end
			continue
		end
		local intruders = byOwner[defense.ownerId]
		if not intruders then
			intruders = intrudersOf(defense.ownerId)
			byOwner[defense.ownerId] = intruders
		end
		if #intruders == 0 and not next(defense.slowed) then
			continue
		end
		if defense.kind == "TripwireAlarm" then
			tripwire(defense, intruders, now)
		elseif defense.kind == "SpikeFloor" then
			spikeFloor(defense, intruders)
		elseif defense.kind == "ShockFence" then
			shockFence(defense, intruders, now)
		elseif defense.kind == "GuardDrone" then
			guardDrone(defense, intruders, now)
		end
	end
end

-- ── Used by other services ───────────────────────────────────────────────

-- A charged, working Decoy Vault on this owner's base, using one charge
-- (ScavService sends a Scav there first). nil if there is none.
function DefenseService.claimDecoy(ownerId: number): BasePart?
	for _, defense in defenses do
		if defense.kind == "DecoyVault" and defense.ownerId == ownerId and isActive(defense) and spendCharge(defense) then
			return defense.hitbox
		end
	end
	return nil
end

-- Extra lockpick difficulty from this owner's working Lock Upgrades
-- (step 7 calls this at the start of a lockpick and spends a charge each).
function DefenseService.lockBonus(ownerId: number): number
	local bonus = 0
	for _, defense in defenses do
		if defense.kind == "LockUpgrade" and defense.ownerId == ownerId and isActive(defense) then
			bonus += kindCfgs.LockUpgrade.ExtraDifficulty
		end
	end
	return bonus
end

-- The nearest working defense on someone ELSE's base within Disruptor
-- range of `position`, or nil.
function DefenseService.findDisruptTarget(player: Player, position: Vector3): Model?
	local best: Model? = nil
	local bestDistance = defenseCfg.DisruptorRange
	for model, defense in defenses do
		if defense.ownerId ~= player.UserId and isActive(defense) then
			local distance = NodeMath.distanceToHitbox(defense.hitbox, position)
			if distance <= bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

-- Switches a defense off for `seconds` (Disruptor gadget).
function DefenseService.disable(model: Model, seconds: number)
	local defense = defenses[model]
	if not defense then
		return
	end
	defense.disabledUntil = workspace:GetServerTimeNow() + seconds
	model:SetAttribute("DisabledUntil", defense.disabledUntil)
	releaseSlowed(defense)
	alertOwner(defense.ownerId, "Disrupted", `Your {defense.kind} was disrupted for {seconds} s`)
end

-- ── Refill ───────────────────────────────────────────────────────────────

local function refill(player: Player, pieceArg: unknown): (boolean, string?)
	if typeof(pieceArg) ~= "string" then
		logAnomaly(player, "sent a bad defense id")
		return false, "Invalid"
	end
	local pieceId = pieceArg :: string
	local base = PlayerDataService.get(player, "Base")
	local use = PlayerDataService.get(player, "DefenseUse")
	if not base or not use then
		return false, "Failed"
	end
	local kind: string? = nil
	for _, piece: Types.PlacedPiece in base.Pieces do
		if piece.Id == pieceId then
			kind = piece.Kind
		end
	end
	if not kind or not kindCfgs[kind] then
		return false, "NotFound" -- not theirs, or not a defense
	end
	if (use[pieceId] or 0) == 0 then
		return false, "Full"
	end
	local cost = kindCfgs[kind].RefillCost
	if not VaultService.spend(player, cost) then
		return false, "CantAfford"
	end
	local ok = PlayerDataService.update(player, "DefenseUse", OWNER, function(current: { [string]: number? })
		current[pieceId] = nil
		return current
	end)
	if not ok then
		VaultService.grant(player, cost)
		return false, "Failed"
	end
	for _, defense in defenses do
		if defense.pieceId == pieceId then
			showCharges(defense)
		end
	end
	return true, nil
end

-- Drops charge records for pieces that no longer exist (removed defenses).
local function prune(player: Player)
	local base = PlayerDataService.get(player, "Base")
	if not base then
		return
	end
	local exists: { [string]: boolean } = {}
	for _, piece: Types.PlacedPiece in base.Pieces do
		exists[piece.Id] = true
	end
	PlayerDataService.update(player, "DefenseUse", OWNER, function(use: { [string]: number? })
		for pieceId in use do
			if not exists[pieceId] then
				use[pieceId] = nil
			end
		end
		return use
	end)
end

-- ── Start-up ─────────────────────────────────────────────────────────────

local function onAdded(instance: Instance)
	if not instance:IsA("Model") or not instance:IsDescendantOf(workspace) then
		return
	end
	local hitbox = instance:FindFirstChild("Hitbox")
	local kind = instance:GetAttribute("Kind")
	local pieceId = instance:GetAttribute("PieceId")
	local ownerId = instance:GetAttribute("OwnerUserId")
	if not (hitbox and hitbox:IsA("BasePart")) or typeof(kind) ~= "string" or not kindCfgs[kind]
		or typeof(pieceId) ~= "string" or typeof(ownerId) ~= "number"
	then
		warn(`[Defense] {instance:GetFullName()} is tagged {defenseCfg.Tag} but is missing Hitbox/Kind/PieceId/OwnerUserId`)
		return
	end
	local defense: Defense = {
		model = instance,
		hitbox = hitbox,
		kind = kind,
		pieceId = pieceId,
		ownerId = ownerId,
		lastHit = {},
		slowed = {},
		nextZapAt = 0,
		disabledUntil = 0,
	}
	defenses[instance] = defense
	showCharges(defense)
end

local function onRemoved(instance: Instance)
	local defense = defenses[instance :: any]
	if defense then
		releaseSlowed(defense)
		defenses[instance :: any] = nil
	end
end

function DefenseService.start()
	for _, instance in CollectionService:GetTagged(defenseCfg.Tag) do
		onAdded(instance)
	end
	CollectionService:GetInstanceAddedSignal(defenseCfg.Tag):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(defenseCfg.Tag):Connect(onRemoved)
	PlayerDataService.Loaded:Connect(prune)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= defenseCfg.TickSeconds then
			elapsed = 0
			tick()
		end
	end)

	local allow = RateLimiter.new("RefillDefense", defenseCfg.RefillCooldownSeconds)
	Remotes.getFunction("RefillDefense").OnServerInvoke = function(player: Player, pieceArg: unknown): (boolean, string?)
		if not allow(player) then
			return false, "Busy"
		end
		return refill(player, pieceArg)
	end
end

return DefenseService
