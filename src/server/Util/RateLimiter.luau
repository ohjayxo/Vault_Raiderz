--!strict
-- Per-player cooldown for a remote. 13-build-guide.md § Part D: "Every remote
-- has a server-side rate limit. Impossible requests get logged."

local Players = game:GetService("Players")

-- Warn on the first rejected call, then every Nth, so spam doesn't flood Output.
local LOG_EVERY = 20

local RateLimiter = {}

-- Returns allow(player) -> boolean for one remote.
function RateLimiter.new(name: string, cooldownSeconds: number): (Player) -> boolean
	local lastAllowed: { [Player]: number } = {}
	local rejected: { [Player]: number } = {}

	Players.PlayerRemoving:Connect(function(player)
		lastAllowed[player] = nil
		rejected[player] = nil
	end)

	return function(player: Player): boolean
		local now = os.clock()
		local last = lastAllowed[player]
		if last and now - last < cooldownSeconds then
			local count = (rejected[player] or 0) + 1
			rejected[player] = count
			if count % LOG_EVERY == 1 then
				warn(`[RateLimit] {name}: {player.Name} ({player.UserId}) over the limit ({count} rejected)`)
			end
			return false
		end
		lastAllowed[player] = now
		return true
	end
end

return RateLimiter
