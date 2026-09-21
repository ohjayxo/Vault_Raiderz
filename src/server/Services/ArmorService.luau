--!strict
-- ArmorService: armor pieces (D112). The only service that writes the
-- Armor section (Config.Data.SectionOwners).
--
-- Docs: 05-items.md § Armor; 07-decisions.md § D112.
-- * Pieces are unique items (GUID ids) with a tier (pickaxe tier names) and
--   a slot (one Chest slot in the slice). A piece never upgrades.
-- * The worn piece gives knockback resistance + a small damage reduction
--   (Config.Combat.Armor*). It is never stealable (R1); spares are (step 7).
-- * Pieces come from Workshop I crafting (step 10; Josh's call, step 5).
--   Until then only Studio debug grants them.
-- * Gear score counts the highest tier OWNED, worn or not (BandMetric).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local AnomalyLog = require(ServerScriptService.Util.AnomalyLog)
local PlayerDataService = require(script.Parent.PlayerDataService)

local OWNER = "ArmorService"
local combatCfg = Config.Combat
local VISUAL_NAME = "ArmorVisual" -- greybox chest plate on the character

type ArmorData = { Equipped: { [string]: string }, Pieces: { [string]: Types.ArmorPiece } }

local changedEvent = Instance.new("BindableEvent")
local logAnomaly = AnomalyLog.new("Armor")

local ArmorService = {}

-- Fires (player) after their armor changes.
ArmorService.Changed = changedEvent.Event

function ArmorService.get(player: Player): ArmorData?
	return PlayerDataService.get(player, "Armor")
end

-- Tier of the worn piece in `slot`, 0 if none.
local function wornTier(player: Player, slot: string): number
	local armor = ArmorService.get(player)
	if not armor then
		return 0
	end
	local piece = armor.Pieces[armor.Equipped[slot] or ""]
	return if piece then piece.Tier else 0
end

local function tierValue(list: { number }, tier: number): number
	return if tier >= 1 then list[math.min(tier, #list)] else 0
end

-- 0..1 share of damage removed by worn armor. Players only.
function ArmorService.damageReduction(player: Player): number
	return tierValue(combatCfg.ArmorDamageReduction, wornTier(player, combatCfg.ArmorSlots[1]))
end

-- 0..1 share of knockback removed by worn armor.
function ArmorService.knockbackResist(player: Player): number
	return tierValue(combatCfg.ArmorKnockbackResist, wornTier(player, combatCfg.ArmorSlots[1]))
end

-- Greybox look: a plate on the chest, coloured by tier (same colours as
-- the pickaxe). Nothing reads it; it's a visual only.
local function updateVisual(player: Player)
	local character = player.Character
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not character or not torso then
		return
	end
	local old = character:FindFirstChild(VISUAL_NAME)
	if old then
		old:Destroy()
	end
	local tier = wornTier(player, combatCfg.ArmorSlots[1])
	if tier < 1 then
		return
	end
	local plate = Instance.new("Part")
	plate.Name = VISUAL_NAME
	plate.Size = Vector3.new(torso.Size.X + 0.3, torso.Size.Y * 0.8, torso.Size.Z + 0.3)
	plate.Color = combatCfg.ToolLook.TierColors[math.min(tier, #combatCfg.ToolLook.TierColors)]
	plate.Material = Enum.Material.Metal
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.Massless = true
	plate.CFrame = torso.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = plate
	weld.Part1 = torso
	weld.Parent = plate
	plate.Parent = character
end

-- Creates a new piece (Workshop crafting in step 10; debug now). Returns its id.
function ArmorService.grant(player: Player, tier: number, slot: string): string?
	assert(tier >= 1 and tier <= #combatCfg.PickaxeTiers and tier == math.floor(tier), `ArmorService.grant: bad tier {tier}`)
	assert(table.find(combatCfg.ArmorSlots, slot), `ArmorService.grant: unknown slot "{slot}"`)
	local id = HttpService:GenerateGUID(false)
	local ok = PlayerDataService.update(player, "Armor", OWNER, function(armor: ArmorData)
		armor.Pieces[id] = { Tier = tier, Slot = slot }
		return armor
	end)
	if not ok then
		return nil
	end
	changedEvent:Fire(player)
	return id
end

-- Wears piece `pieceId` in its slot, or takes the chest piece off with "".
local function equip(player: Player, pieceArg: unknown): (boolean, string?)
	if typeof(pieceArg) ~= "string" then
		logAnomaly(player, "sent a bad armor id")
		return false, "Invalid"
	end
	local pieceId = pieceArg :: string
	local armor = ArmorService.get(player)
	if not armor then
		return false, "Failed"
	end
	local slot = combatCfg.ArmorSlots[1]
	if pieceId ~= "" then
		local piece = armor.Pieces[pieceId]
		if not piece then
			return false, "NotFound" -- not theirs, or already gone (stolen spare)
		end
		slot = piece.Slot
	end
	local ok = PlayerDataService.update(player, "Armor", OWNER, function(current: ArmorData)
		current.Equipped[slot] = pieceId
		return current
	end)
	if not ok then
		return false, "Failed"
	end
	updateVisual(player)
	changedEvent:Fire(player)
	return true, nil
end

function ArmorService.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("UpperTorso", 5)
			updateVisual(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	PlayerDataService.Loaded:Connect(updateVisual)

	local allow = RateLimiter.new("EquipArmor", combatCfg.GearRequestCooldownSeconds)
	Remotes.getFunction("EquipArmor").OnServerInvoke = function(player: Player, pieceArg: unknown): (boolean, string?)
		if not allow(player) then
			return false, "Busy"
		end
		return equip(player, pieceArg)
	end
end

return ArmorService
