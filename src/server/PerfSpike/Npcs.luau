--!strict
-- THROWAWAY (build step 0B). Default R15 rigs that wander around an island, so
-- the spike includes character-rendering and Humanoid cost. Delete with the
-- rest of src/server/PerfSpike.
--
-- Greybox contract note: a Humanoid needs its body parts as direct children of
-- the Model, so the rig's body IS its own visual. The Model still gets the tag,
-- attributes and a Hitbox; `Visual` is left empty.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)

local cfg = Config.PerfSpike

-- Any prime; gives each NPC its own wander sequence.
local NPC_SEED_STRIDE = 131

local Npcs = {}

-- Yields (creating a rig is an async call). `isCurrent` lets the caller cancel
-- us if the scene was rebuilt while we waited.
function Npcs.spawn(parent: Instance, spot: Layout.BaseSpot, number: number, isCurrent: () -> boolean)
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[PerfSpike] could not create an NPC rig:", result)
		return
	end
	if not isCurrent() then
		(result :: Model):Destroy()
		return
	end

	local model = result :: Model
	model.Name = `PerfSpikeNpc{number}`
	model:SetAttribute("BaseIndex", spot.Index)
	CollectionService:AddTag(model, cfg.Tags.Npc)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		warn("[PerfSpike] NPC rig had no Humanoid/HumanoidRootPart")
		model:Destroy()
		return
	end
	humanoid.WalkSpeed = cfg.Npc.WalkSpeed

	local rng = Random.new(cfg.Layout.Seed + number * NPC_SEED_STRIDE)
	local start = spot.CFrame:PointToWorldSpace(Layout.wanderPoint(rng) + Vector3.new(0, 3, 0))
	model:PivotTo(CFrame.new(start))

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(2, 5, 2)
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.Massless = true
	hitbox.CFrame = root.CFrame
	hitbox.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hitbox
	weld.Part1 = root
	weld.Parent = hitbox

	local visual = Instance.new("Folder")
	visual.Name = "Visual"
	visual.Parent = model

	model.Parent = parent
	root:SetNetworkOwner(nil) -- keep the server in charge of NPC movement (R5)

	task.spawn(function()
		while model.Parent and isCurrent() do
			local target: Vector3 = spot.CFrame:PointToWorldSpace(Layout.wanderPoint(rng))
			humanoid:MoveTo(target)
			task.wait(cfg.Npc.RepathSeconds)
		end
	end)
end

return Npcs
