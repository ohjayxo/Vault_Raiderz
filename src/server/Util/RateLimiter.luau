--!strict
-- Per-player rate limits for remotes. 13-build-guide.md § Part D: "Every
-- remote has a server-side rate limit. Impossible requests get logged."
--
--   RateLimiter.new     - simple cooldown: one call per N seconds.
--   RateLimiter.newBucket - burst bucket: up to `burst` calls back-to-back,
--     refilling at `perSecond`. Use it where humans legitimately act fast
--     (tapping nodes) so only scripted spam trips it.

local Players = game:GetService("Players")

-- Warn on the first rejected call, then every Nth, so spam doesn't flood Output.
local LOG_EVERY = 20

local RateLimiter = {}

local function makeRejectLogger(name: string): ((Player) -> (), { [Player]: number })
	local rejected: { [Player]: number } = {}
	return function(player: Player)
		local count = (rejected[player] or 0) + 1
		rejected[player] = count
		if count % LOG_EVERY == 1 then
			warn(`[RateLimit] {name}: {player.Name} ({player.UserId}) over the limit ({count} rejected)`)
		end
	end, rejected
end

-- Returns allow(player) -> boolean for one remote.
function RateLimiter.new(name: string, cooldownSeconds: number): (Player) -> boolean
	local lastAllowed: { [Player]: number } = {}
	local logReject, rejected = makeRejectLogger(name)

	Players.PlayerRemoving:Connect(function(player)
		lastAllowed[player] = nil
		rejected[player] = nil
	end)

	return function(player: Player): boolean
		local now = os.clock()
		local last = lastAllowed[player]
		if last and now - last < cooldownSeconds then
			logReject(player)
			return false
		end
		lastAllowed[player] = now
		return true
	end
end

-- Returns allow(player) -> boolean for one remote (token bucket).
function RateLimiter.newBucket(name: string, burst: number, perSecond: number): (Player) -> boolean
	assert(burst >= 1 and perSecond > 0, "RateLimiter.newBucket needs burst >= 1 and perSecond > 0")
	local tokens: { [Player]: number } = {}
	local updatedAt: { [Player]: number } = {}
	local logReject, rejected = makeRejectLogger(name)

	Players.PlayerRemoving:Connect(function(player)
		tokens[player] = nil
		updatedAt[player] = nil
		rejected[player] = nil
	end)

	return function(player: Player): boolean
		local now = os.clock()
		local last = updatedAt[player]
		local available = if last then math.min(burst, tokens[player] + (now - last) * perSecond) else burst
		updatedAt[player] = now
		if available < 1 then
			tokens[player] = available
			logReject(player)
			return false
		end
		tokens[player] = available - 1
		return true
	end
end

return RateLimiter
