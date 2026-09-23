--!strict
-- Build-grid math shared by the server (which decides) and the build UI
-- (which only previews). 02-core-loop.md § Base / Home; Config.Plots.
--
-- A plot's Hitbox top face is the grid. Cell (0, 0) is its corner at local
-- -X/-Z. Two kinds of piece:
--   * Cell pieces (Vault Core, Spike Floor, ...) fill W x D cells. X/Z = the
--     lowest cell of the footprint.
--   * Edge pieces (Config.Base.Pieces[kind].Edge: Wall, Gate, Shock Fence)
--     sit ON the line between cells, so rotated walls meet cleanly at
--     corners (fix for the corner gap found in step 4 testing).
--     Rot 0/2: along X, on the line z = Z, spanning cell X.
--     Rot 1/3: along Z, on the line x = X, spanning cell Z.
-- Overlap works on "keys": cells ("c:x,z") and edges ("h:x,z" / "v:x,z").
-- An edge piece also can't sit on the border of a cell piece: they'd
-- physically overlap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

type PieceConfig = { Cells: { number }, Height: number, Cost: { [string]: number }, BudgetCost: number, Edge: boolean? }
local pieceConfigs: { [string]: PieceConfig } = Config.Base.Pieces :: any
local GRID = Config.Plots.GridStuds

local PlotGrid = {}

function PlotGrid.pieceConfig(kind: string): PieceConfig?
	return pieceConfigs[kind]
end

function PlotGrid.isEdge(kind: string): boolean
	return pieceConfigs[kind].Edge == true
end

-- Footprint in cells after `rot` quarter turns (odd turns swap W and D).
-- Cell pieces only.
function PlotGrid.footprint(kind: string, rot: number): (number, number)
	local cells = pieceConfigs[kind].Cells
	if rot % 2 == 1 then
		return cells[2], cells[1]
	end
	return cells[1], cells[2]
end

-- The plot's front: its local -Z edge (grid row z = 0), flattened. Every
-- plot is rotated so its front faces its bridge (02 § Slice layout, D113),
-- so a gate built on row 0 faces the bridge on whichever plot you get.
-- Scavs arrive and players respawn on this side.
function PlotGrid.front(plotHitbox: BasePart): Vector3
	local look = plotHitbox.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0 then flat.Unit else -Vector3.zAxis
end

-- Cells along the plot's X and Z.
function PlotGrid.gridSize(plotHitbox: BasePart): (number, number)
	return math.floor(plotHitbox.Size.X / GRID), math.floor(plotHitbox.Size.Z / GRID)
end

function PlotGrid.inBounds(plotHitbox: BasePart, kind: string, x: number, z: number, rot: number): boolean
	local cellsX, cellsZ = PlotGrid.gridSize(plotHitbox)
	if PlotGrid.isEdge(kind) then
		if rot % 2 == 0 then
			return x >= 0 and x < cellsX and z >= 0 and z <= cellsZ
		end
		return x >= 0 and x <= cellsX and z >= 0 and z < cellsZ
	end
	local w, d = PlotGrid.footprint(kind, rot)
	return x >= 0 and z >= 0 and x + w <= cellsX and z + d <= cellsZ
end

-- Where a piece's Hitbox centre goes, given its Hitbox height.
function PlotGrid.pieceCFrame(plotHitbox: BasePart, kind: string, x: number, z: number, rot: number, height: number): CFrame
	local size = plotHitbox.Size
	local localX, localZ
	if PlotGrid.isEdge(kind) then
		if rot % 2 == 0 then
			localX, localZ = (x + 0.5) * GRID, z * GRID
		else
			localX, localZ = x * GRID, (z + 0.5) * GRID
		end
	else
		local w, d = PlotGrid.footprint(kind, rot)
		localX, localZ = (x + w / 2) * GRID, (z + d / 2) * GRID
	end
	local localY = size.Y / 2 + height / 2
	return plotHitbox.CFrame
		* CFrame.new(-size.X / 2 + localX, localY, -size.Z / 2 + localZ)
		* CFrame.Angles(0, rot * math.pi / 2, 0)
end

-- The placement nearest `worldPoint`, clamped onto the plot. Client
-- preview only (the server checks the real request).
function PlotGrid.anchorNear(plotHitbox: BasePart, worldPoint: Vector3, kind: string, rot: number): (number, number)
	local cellsX, cellsZ = PlotGrid.gridSize(plotHitbox)
	local localPoint = plotHitbox.CFrame:PointToObjectSpace(worldPoint)
	local u = (localPoint.X + plotHitbox.Size.X / 2) / GRID
	local v = (localPoint.Z + plotHitbox.Size.Z / 2) / GRID
	if PlotGrid.isEdge(kind) then
		if rot % 2 == 0 then
			return math.clamp(math.floor(u), 0, cellsX - 1), math.clamp(math.floor(v + 0.5), 0, cellsZ)
		end
		return math.clamp(math.floor(u + 0.5), 0, cellsX), math.clamp(math.floor(v), 0, cellsZ - 1)
	end
	local w, d = PlotGrid.footprint(kind, rot)
	local x = math.clamp(math.floor(u - w / 2 + 0.5), 0, cellsX - w)
	local z = math.clamp(math.floor(v - d / 2 + 0.5), 0, cellsZ - d)
	return x, z
end

local function edgeKey(x: number, z: number, rot: number): string
	return if rot % 2 == 0 then `h:{x},{z}` else `v:{x},{z}`
end

-- The keys a placed piece takes up.
function PlotGrid.keysOf(kind: string, x: number, z: number, rot: number): { string }
	if PlotGrid.isEdge(kind) then
		return { edgeKey(x, z, rot) }
	end
	local w, d = PlotGrid.footprint(kind, rot)
	local keys = {}
	for i = x, x + w - 1 do
		for j = z, z + d - 1 do
			table.insert(keys, `c:{i},{j}`)
		end
	end
	return keys
end

-- The keys that must be free to place this piece: its own keys, plus for
-- an edge the two cells beside it, and for a cell piece every edge on or
-- inside its footprint.
function PlotGrid.blockersOf(kind: string, x: number, z: number, rot: number): { string }
	local keys = PlotGrid.keysOf(kind, x, z, rot)
	if PlotGrid.isEdge(kind) then
		if rot % 2 == 0 then
			table.insert(keys, `c:{x},{z - 1}`)
			table.insert(keys, `c:{x},{z}`)
		else
			table.insert(keys, `c:{x - 1},{z}`)
			table.insert(keys, `c:{x},{z}`)
		end
		return keys
	end
	local w, d = PlotGrid.footprint(kind, rot)
	for i = x, x + w - 1 do
		for j = z, z + d do
			table.insert(keys, `h:{i},{j}`)
		end
	end
	for i = x, x + w do
		for j = z, z + d - 1 do
			table.insert(keys, `v:{i},{j}`)
		end
	end
	return keys
end

return PlotGrid
