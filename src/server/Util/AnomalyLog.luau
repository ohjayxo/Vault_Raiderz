--!strict
-- Logs requests that a fair client would never send (too far, unknown node,
-- bad arguments). 13-build-guide.md § Part D, § Anti-exploit baseline;
-- 10-roadmap.md § Known Risks #1. Throttled per player + reason so an
-- exploiter can't flood Output.

local Players = game:GetService("Players")

-- Log the first of each reason, then every Nth.
local LOG_EVERY = 20

local AnomalyLog = {}

-- Returns log(player, reason) for one system.
function AnomalyLog.new(system: string): (Player, string) -> ()
	local counts: { [Player]: { [string]: number } } = {}

	Players.PlayerRemoving:Connect(function(player)
		counts[player] = nil
	end)

	return function(player: Player, reason: string)
		local perPlayer = counts[player]
		if not perPlayer then
			perPlayer = {}
			counts[player] = perPlayer
		end
		local count = (perPlayer[reason] or 0) + 1
		perPlayer[reason] = count
		if count % LOG_EVERY == 1 then
			warn(`[Anomaly] {system}: {player.Name} ({player.UserId}) {reason} (x{count})`)
		end
	end
end

return AnomalyLog
