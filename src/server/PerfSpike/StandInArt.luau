--!strict
-- THROWAWAY (build step 0B). The ONLY file that puts things in a `Visual`
-- folder: it builds the placeholder art for the perf-spike scene, once, at
-- spawn time. Nothing else reads or writes `Visual` (CLAUDE.md § Greybox
-- contract); real systems will fill `Visual` with real art the same way.
--
-- Art comes from real MeshParts you import into ServerStorage.PerfSpikeKit
-- (docs-build/perfspike/README.md). If they're missing we fall back to plain
-- blocks so the layout can still be checked, but the triangle numbers are then
-- NOT valid and the HUD says so.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)

local cfg = Config.PerfSpike
local layoutCfg = cfg.Layout

export type Preset = typeof(Config.PerfSpike.Presets[1])

export type Kit = {
	Templates: { [string]: MeshPart },
	Mode: string, -- "Imported" | "Partial" | "Primitives"
	Missing: { string },
}

export type Stats = {
	Tris: number, -- triangles claimed by imported meshes (primitives claim 0)
	Parts: number, -- visible art parts (transparent Hitboxes not counted)
	Emitters: number,
}

-- Any large prime; keeps each base's random decor independent of the others.
local BASE_SEED_STRIDE = 7919

-- Offsets so the material dice never share a sequence with the layout dice
-- (which would move pieces around between Baseline and Varied).
local MATERIAL_SEED_OFFSET = 1
local NODE_MATERIAL_SEED_STRIDE = 104729

-- Visual-only colours for the four spike "grade" tiers (not the real Grade table).
local TIER_COLORS = {
	Color3.fromRGB(200, 200, 200),
	Color3.fromRGB(90, 200, 120),
	Color3.fromRGB(80, 150, 255),
	Color3.fromRGB(255, 120, 220),
}

local StandInArt = {}

local function enumItem(enum: any, name: string, fallback: any): any
	local ok, item = pcall(function()
		return enum[name]
	end)
	return if ok and item then item else fallback
end

-- Imported models are named after the .obj files (spike_wall etc.); accept the
-- key anywhere in the MeshPart's name or its parents' names, up to the kit folder.
local function matchKey(instance: Instance, stopAt: Instance, keys: { string }): string?
	local current: Instance? = instance
	while current and current ~= stopAt do
		local lowered = string.lower(current.Name)
		for _, key in keys do
			if string.find(lowered, string.lower(key), 1, true) then
				return key
			end
		end
		current = current.Parent
	end
	return nil
end

function StandInArt.loadKit(): Kit
	local keys: { string } = { "Node" }
	for _, entry in cfg.Kit do
		table.insert(keys, entry.Key)
	end

	local templates: { [string]: MeshPart } = {}
	local folder = ServerStorage:FindFirstChild(cfg.KitFolderName)
	if folder then
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("MeshPart") then
				local key = matchKey(descendant, folder, keys)
				if key and not templates[key] then
					templates[key] = descendant
				end
			end
		end
	end

	local missing: { string } = {}
	for _, key in keys do
		if not templates[key] then
			table.insert(missing, key)
		end
	end
	local mode = if #missing == 0 then "Imported" elseif #missing == #keys then "Primitives" else "Partial"
	return { Templates = templates, Mode = mode, Missing = missing }
end

-- The material a piece uses: its kit material, or in Varied presets a random one
-- from Config so neighbouring pieces can't share a draw batch.
local function materialFor(preset: Preset, kitMaterial: string, dice: Random): string
	if not preset.Varied then
		return kitMaterial
	end
	local list = cfg.VariedMaterials
	return list[dice:NextInteger(1, #list)]
end

-- One piece of placeholder art. Returns the part and the triangles it claims.
local function createPiece(
	kit: Kit,
	key: string,
	tris: number,
	size: Vector3,
	materialName: string,
	color: Color3,
	cframe: CFrame,
	fidelity: Enum.RenderFidelity,
	parent: Instance
): (BasePart, number)
	local part: BasePart
	local claimed = 0
	local template = kit.Templates[key]
	if template then
		local clone = template:Clone()
		-- RenderFidelity and CollisionFidelity can't be written from a running
		-- script (Plugin capability); the clone keeps whatever is set on the kit
		-- mesh in Studio.
		part = clone
		claimed = tris
	else
		local block = Instance.new("Part")
		block.Shape = if key == "Decor" or key == "Node" then Enum.PartType.Ball else Enum.PartType.Block
		part = block
	end
	part.Name = key
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 0
	part.Size = size -- scales the mesh to this many studs whatever the import scale
	part.CFrame = cframe
	part.Material = enumItem(Enum.Material, materialName, Enum.Material.Plastic)
	part.Color = color
	part.Parent = parent
	return part, claimed
end

local function addNodeEmitters(part: BasePart, color: Color3)
	local fx = cfg.Fx

	local glow = Instance.new("ParticleEmitter")
	glow.Name = "Glow"
	glow.Rate = fx.GlowRate
	glow.Lifetime = fx.GlowLifetime
	glow.Speed = fx.GlowSpeed
	glow.Size = NumberSequence.new(fx.GlowSize, 0)
	glow.Transparency = NumberSequence.new(fx.GlowTransparency, 1)
	glow.LightEmission = fx.GlowLightEmission
	glow.Color = ColorSequence.new(color)
	glow.Parent = part

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Rate = fx.SparkRate
	sparks.Lifetime = fx.SparkLifetime
	sparks.Speed = fx.SparkSpeed
	sparks.SpreadAngle = Vector2.new(fx.SparkSpread, fx.SparkSpread)
	sparks.Acceleration = fx.SparkAcceleration
	sparks.Size = NumberSequence.new(fx.SparkSize)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(color)
	sparks.Parent = part
end

-- One base: the greybox-contract Model (tag + attributes + Hitbox + Visual).
-- The Hitbox is the flat ground plate everything stands on; the pieces and the
-- floating-island rock are the Visual.
function StandInArt.buildBase(parent: Instance, spot: Layout.BaseSpot, kit: Kit, preset: Preset): (Stats, Model)
	local model = Instance.new("Model")
	model.Name = `PerfSpikeBase{spot.Index}`
	model:SetAttribute("BaseIndex", spot.Index)
	model:SetAttribute("IsOwn", spot.IsOwn)
	model:SetAttribute("PieceMultiplier", preset.PieceMultiplier)
	CollectionService:AddTag(model, cfg.Tags.Base)

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = layoutCfg.PlateSize
	hitbox.Anchored = true
	hitbox.Transparency = 1
	hitbox.CFrame = spot.CFrame * CFrame.new(0, -layoutCfg.PlateSize.Y / 2, 0)
	hitbox.Parent = model
	model.PrimaryPart = hitbox

	local visual = Instance.new("Folder")
	visual.Name = "Visual"
	visual.Parent = model

	local fidelity: Enum.RenderFidelity = enumItem(Enum.RenderFidelity, preset.RenderFidelity, Enum.RenderFidelity.Automatic)
	local rng = Random.new(layoutCfg.Seed + spot.Index * BASE_SEED_STRIDE)
	local materialDice = Random.new(layoutCfg.Seed + spot.Index * BASE_SEED_STRIDE + MATERIAL_SEED_OFFSET)
	local stats: Stats = { Tris = 0, Parts = 0, Emitters = 0 }

	for _, entry in cfg.Kit do
		local count = entry.Count * (if entry.Scales then preset.PieceMultiplier else 1)
		if entry.Key == "Island" then
			-- Hangs below the plate so the plate's top is the walkable ground.
			local cframe = spot.CFrame * CFrame.new(0, -layoutCfg.PlateSize.Y - entry.Size.Y / 2, 0)
			local material = materialFor(preset, entry.Material, materialDice)
			local _, claimed = createPiece(kit, entry.Key, entry.Tris, entry.Size, material, entry.Color, cframe, fidelity, visual)
			stats.Tris += claimed
			stats.Parts += 1
		else
			for _, slot in Layout.slots(entry.Key, count, rng, entry.Size.X) do
				local cframe = spot.CFrame * CFrame.new(slot.X, entry.Size.Y / 2, slot.Z) * CFrame.Angles(0, slot.Yaw, 0)
				local material = materialFor(preset, entry.Material, materialDice)
				local _, claimed = createPiece(kit, entry.Key, entry.Tris, entry.Size, material, entry.Color, cframe, fidelity, visual)
				stats.Tris += claimed
				stats.Parts += 1
			end
		end
	end

	model:SetAttribute("Triangles", stats.Tris)
	model:SetAttribute("Parts", stats.Parts)
	model.Parent = parent
	return stats, model
end

-- One resource node (Model + tag + attributes + Hitbox + Visual), with Grade-style
-- particle emitters when the preset asks for them.
function StandInArt.buildNode(parent: Instance, spot: Layout.BaseSpot, k: number, kit: Kit, preset: Preset): Stats
	local nodeCfg = cfg.Nodes
	local slot = Layout.nodeSlot(k, spot.Index)
	local tier = (k - 1) % nodeCfg.GradeTiers + 1
	local color = TIER_COLORS[(tier - 1) % #TIER_COLORS + 1]
	local cframe = spot.CFrame * CFrame.new(slot.X, nodeCfg.Size.Y / 2, slot.Z)

	local model = Instance.new("Model")
	model.Name = `PerfSpikeNode{k}`
	model:SetAttribute("NodeType", nodeCfg.Types[(k - 1) % #nodeCfg.Types + 1])
	model:SetAttribute("PerfTier", tier)
	model:SetAttribute("BaseIndex", spot.Index)
	CollectionService:AddTag(model, cfg.Tags.Node)

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = nodeCfg.Size + Vector3.new(1, 1, 1)
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.Transparency = 1
	hitbox.CFrame = cframe
	hitbox.Parent = model
	model.PrimaryPart = hitbox

	local visual = Instance.new("Folder")
	visual.Name = "Visual"
	visual.Parent = model

	local fidelity: Enum.RenderFidelity = enumItem(Enum.RenderFidelity, preset.RenderFidelity, Enum.RenderFidelity.Automatic)
	local nodeDice = Random.new(layoutCfg.Seed + k * NODE_MATERIAL_SEED_STRIDE + spot.Index)
	local nodeMaterial = materialFor(preset, nodeCfg.Material, nodeDice)
	local part, claimed = createPiece(kit, "Node", nodeCfg.Tris, nodeCfg.Size, nodeMaterial, color, cframe, fidelity, visual)
	local stats: Stats = { Tris = claimed, Parts = 1, Emitters = 0 }
	if preset.Fx then
		addNodeEmitters(part, color)
		stats.Emitters = 2
	end

	model.Parent = parent
	return stats
end

return StandInArt
