--!strict
-- ShardService: which neighborhood a player belongs in. 02-core-loop.md
-- § Server sharding (D56, keyed to the D66 band by D79).
--
-- STUB (14 § Prompt 4): one neighborhood per server, so every player gets
-- "Default". The band metric itself is real (Util/BandMetric) because
-- raiding (step 7-8) and real sharding both use it.

local ServerScriptService = game:GetService("ServerScriptService")

local BandMetric = require(ServerScriptService.Util.BandMetric)
local PlayerDataService = require(script.Parent.PlayerDataService)

local STUB_NEIGHBORHOOD = "Default"

local ShardService = {}

-- The player's band, or nil if their profile isn't loaded. Server-only.
function ShardService.getBand(player: Player): number?
	local base = PlayerDataService.get(player, "Base")
	local gear = PlayerDataService.get(player, "Gear")
	local armor = PlayerDataService.get(player, "Armor")
	local peak = PlayerDataService.getPacked(player, "LifetimePeakVaultTier")
	if not base or not gear or not armor or not peak then
		return nil
	end
	return BandMetric.band({ VaultTier = base.VaultTier, LifetimePeakVaultTier = peak, Gear = gear, Armor = armor })
end

-- Where this player's plot should live. Stub: always the one neighborhood.
function ShardService.getNeighborhood(player: Player): string
	local band = ShardService.getBand(player)
	print(`[Shard] {player.Name} band {band} -> neighborhood "{STUB_NEIGHBORHOOD}" (stub: one per server)`)
	return STUB_NEIGHBORHOOD
end

return ShardService
