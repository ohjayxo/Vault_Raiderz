--!strict
-- The one server clock. Every timestamp saved to a profile (last active,
-- shields, crew tenure, drone payouts...) comes from here, never from a
-- client (R5).
--
-- The Studio-only offset lets you test long timers without waiting, e.g. the
-- ~1 year plot-archive age (D55). From Studio's Command Bar while playing
-- (server side):
--   require(game.ServerScriptService.Util.Clock).setStudioOffset(400 * 86400)

local RunService = game:GetService("RunService")

local Clock = {}

local offsetSeconds = 0

-- Unix time in seconds (UTC), plus the Studio offset.
function Clock.now(): number
	return os.time() + offsetSeconds
end

function Clock.setStudioOffset(seconds: number)
	assert(RunService:IsStudio(), "Clock.setStudioOffset is Studio-only")
	offsetSeconds = seconds
	print(string.format("[Clock] Studio offset is now %d s (%.1f days)", seconds, seconds / 86400))
end

function Clock.getOffset(): number
	return offsetSeconds
end

return Clock
