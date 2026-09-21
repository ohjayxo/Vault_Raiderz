--!strict
-- THROWAWAY (build step 0B). Pure position math for the perf-spike scene: no
-- Instances are created here. Delete with the rest of src/server/PerfSpike.
--
-- All distances are [PH] invented values in Config.PerfSpike.Layout
-- (02-core-loop.md § Server sharding gives none).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local layoutCfg = Config.PerfSpike.Layout

export type BaseSpot = {
	Index: number, -- 1 = the player's own base
	IsOwn: boolean,
	CFrame: CFrame, -- ground level (top of the Hitbox plate) at the base centre
}

export type Slot = { X: number, Z: number, Yaw: number }

local Layout = {}

-- Returns the player's base first, then `neighborCount` neighbors, nearest
-- first. The same seed always gives the same jitter, and a smaller neighbor
-- count is always a subset of a larger one, so presets compare fairly.
function Layout.baseSpots(neighborCount: number): { BaseSpot }
	local rng = Random.new(layoutCfg.Seed)
	local half = (layoutCfg.GridSize - 1) / 2

	local neighbors: { BaseSpot & { Distance: number } } = {}
	local nextIndex = 2
	for gx = -half, half do
		for gz = -half, half do
			if gx == 0 and gz == 0 then
				continue
			end
			-- Roll jitter for every cell in a fixed order, even ones we drop later.
			local dy = rng:NextNumber(-layoutCfg.HeightJitter, layoutCfg.HeightJitter)
			local yaw = math.rad(rng:NextNumber(-layoutCfg.YawJitterDegrees, layoutCfg.YawJitterDegrees))
			local position = Vector3.new(gx * layoutCfg.IslandSpacing, layoutCfg.BaseHeight + dy, gz * layoutCfg.IslandSpacing)
			table.insert(neighbors, {
				Index = nextIndex,
				IsOwn = false,
				CFrame = CFrame.new(position) * CFrame.Angles(0, yaw, 0),
				Distance = math.sqrt(gx * gx + gz * gz),
			})
			nextIndex += 1
		end
	end
	-- Nearest first; the index breaks ties so the order never changes between runs.
	table.sort(neighbors, function(a, b)
		if a.Distance ~= b.Distance then
			return a.Distance < b.Distance
		end
		return a.Index < b.Index
	end)

	local spots: { BaseSpot } = {
		{ Index = 1, IsOwn = true, CFrame = CFrame.new(0, layoutCfg.BaseHeight, 0) },
	}
	for i = 1, math.min(neighborCount, #neighbors) do
		local n = neighbors[i]
		table.insert(spots, { Index = n.Index, IsOwn = false, CFrame = n.CFrame })
	end
	return spots
end

local function ringSlots(count: number, radius: number, angleOffset: number, yawFor: (number) -> number): { Slot }
	local slots: { Slot } = {}
	for i = 0, count - 1 do
		local angle = angleOffset + (i / count) * math.pi * 2
		table.insert(slots, { X = radius * math.cos(angle), Z = radius * math.sin(angle), Yaw = yawFor(angle) })
	end
	return slots
end

-- Yaw that lays a piece's long (local X) axis along the ring's tangent.
local function tangentYaw(angle: number): number
	return -angle - math.pi / 2
end

-- Where `count` pieces of kit entry `key` go, in base-local X/Z (ground level).
-- `pieceLength` is the long side of the piece, used to fit walls around rings.
function Layout.slots(key: string, count: number, rng: Random, pieceLength: number): { Slot }
	if key == "Vault" then
		return { { X = 0, Z = 0, Yaw = 0 } }
	elseif key == "Workshop" then
		return { { X = layoutCfg.WorkshopOffset.X, Z = layoutCfg.WorkshopOffset.Z, Yaw = 0 } }
	elseif key == "Wall" then
		-- Fill the first ring, then step outward ring by ring (bigger bases
		-- with more walls need more rings).
		local slots: { Slot } = {}
		local ring = 0
		while #slots < count do
			local radius = layoutCfg.WallRingRadius + ring * layoutCfg.WallRingStep
			local capacity = math.max(1, math.floor(2 * math.pi * radius / pieceLength))
			local placing = math.min(count - #slots, capacity)
			for _, slot in ringSlots(placing, radius, ring * 0.3, tangentYaw) do
				table.insert(slots, slot)
			end
			ring += 1
		end
		return slots
	elseif key == "Gate" then
		return ringSlots(count, layoutCfg.WallRingRadius, 0.25, tangentYaw)
	elseif key == "Defense" then
		return ringSlots(count, layoutCfg.DefenseRingRadius, 0.6, function()
			return 0
		end)
	end
	-- Decor and anything else: scattered in an annulus.
	local slots: { Slot } = {}
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(layoutCfg.DecorMinRadius, layoutCfg.DecorMaxRadius)
		table.insert(slots, { X = radius * math.cos(angle), Z = radius * math.sin(angle), Yaw = rng:NextNumber(0, math.pi * 2) })
	end
	return slots
end

-- Where the k-th node on a base goes (spread around the island's edge).
function Layout.nodeSlot(k: number, baseIndex: number): Slot
	local goldenAngle = 2.399963 -- radians; spreads points evenly without clumping
	local angle = (k + baseIndex * 3) * goldenAngle
	return { X = layoutCfg.NodeRingRadius * math.cos(angle), Z = layoutCfg.NodeRingRadius * math.sin(angle), Yaw = 0 }
end

-- A random walkable point on a base, for NPC wandering (base-local X/Z).
function Layout.wanderPoint(rng: Random): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(0, layoutCfg.NpcWanderRadius)
	return Vector3.new(radius * math.cos(angle), 0, radius * math.sin(angle))
end

return Layout
