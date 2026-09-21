--!strict
-- Geometry shared by server (authority) and client (the "walk closer" hint).
-- Only ever reads a node's Hitbox (greybox contract).

local NodeMath = {}

-- Distance from `point` to the nearest point of `hitbox`'s box (0 if inside).
-- Measuring to the edge, not the center, keeps big and small nodes fair.
function NodeMath.distanceToHitbox(hitbox: BasePart, point: Vector3): number
	local localPoint = hitbox.CFrame:PointToObjectSpace(point)
	local half = hitbox.Size / 2
	local closest = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	return (localPoint - closest).Magnitude
end

return NodeMath
