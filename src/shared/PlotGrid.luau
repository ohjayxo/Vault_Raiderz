--!strict
-- Build-grid math shared by the server (which decides) and the build UI
-- (which only previews). 02-core-loop.md § Base / Home; Config.Plots.
--
-- A plot's Hitbox top face is the grid. Cell (0, 0) is its corner at local
-- -X/-Z; a piece is stored by the lowest cell of its footprint plus quarter
-- turns (Types.PlacedPiece). Works in the plot's own space, so rotated plots
-- would work too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

type PieceConfig = { Cells: { number }, Height: number, Cost: { [string]: number }, BudgetCost: number }
local pieceConfigs: { [string]: PieceConfig } = Config.Base.Pieces :: any
local GRID = Config.Plots.GridStuds

local PlotGrid = {}

function PlotGrid.pieceConfig(kind: string): PieceConfig?
	return pieceConfigs[kind]
end

-- Footprint in cells after `rot` quarter turns (odd turns swap W and D).
function PlotGrid.footprint(kind: string, rot: number): (number, number)
	local cells = pieceConfigs[kind].Cells
	if rot % 2 == 1 then
		return cells[2], cells[1]
	end
	return cells[1], cells[2]
end

-- Cells along the plot's X and Z.
function PlotGrid.gridSize(plotHitbox: BasePart): (number, number)
	return math.floor(plotHitbox.Size.X / GRID), math.floor(plotHitbox.Size.Z / GRID)
end

function PlotGrid.inBounds(plotHitbox: BasePart, x: number, z: number, w: number, d: number): boolean
	local cellsX, cellsZ = PlotGrid.gridSize(plotHitbox)
	return x >= 0 and z >= 0 and x + w <= cellsX and z + d <= cellsZ
end

-- Where a piece's Hitbox centre goes, given its Hitbox height.
function PlotGrid.pieceCFrame(plotHitbox: BasePart, kind: string, x: number, z: number, rot: number, height: number): CFrame
	local w, d = PlotGrid.footprint(kind, rot)
	local size = plotHitbox.Size
	local localX = -size.X / 2 + (x + w / 2) * GRID
	local localZ = -size.Z / 2 + (z + d / 2) * GRID
	local localY = size.Y / 2 + height / 2
	return plotHitbox.CFrame * CFrame.new(localX, localY, localZ) * CFrame.Angles(0, rot * math.pi / 2, 0)
end

-- The footprint anchor whose centre is nearest `worldPoint`, clamped onto
-- the plot. Client preview only.
function PlotGrid.anchorNear(plotHitbox: BasePart, worldPoint: Vector3, w: number, d: number): (number, number)
	local cellsX, cellsZ = PlotGrid.gridSize(plotHitbox)
	local localPoint = plotHitbox.CFrame:PointToObjectSpace(worldPoint)
	local u = (localPoint.X + plotHitbox.Size.X / 2) / GRID
	local v = (localPoint.Z + plotHitbox.Size.Z / 2) / GRID
	local x = math.clamp(math.floor(u - w / 2 + 0.5), 0, cellsX - w)
	local z = math.clamp(math.floor(v - d / 2 + 0.5), 0, cellsZ - d)
	return x, z
end

-- "x,z" keys of every cell a piece covers.
function PlotGrid.cellsOf(kind: string, x: number, z: number, rot: number): { string }
	local w, d = PlotGrid.footprint(kind, rot)
	local keys = {}
	for i = x, x + w - 1 do
		for j = z, z + d - 1 do
			table.insert(keys, `{i},{j}`)
		end
	end
	return keys
end

return PlotGrid
