--!strict
-- OfflineBaseService: shows offline players' bases on free plots, so a
-- raider can scout and raid them (Josh's call, step 7; 02 § The raid
-- sequence "Scout — bases are visually tiered", D56/D79: a server hosts a
-- set of plots). Band matching comes with step 8; for now any recent
-- leaver can appear.
--
-- * When a player leaves, they're added to a MemoryStore sorted map
--   ("recently offline", newest first, expires after Offline.TtlSeconds).
-- * Every FillSeconds, free plots (beyond KeepFreePlots) are filled from it:
--   only players who are offline everywhere (PresenceService), whose save is
--   released (no active session: the last save finished) and who have a
--   Vault Core. The base is a read-only copy (PlotService.hostOffline).
-- * A shown player who comes online anywhere is taken down again (unless a
--   raid is running on it: RaidService handles that case).
-- MemoryStore is only ever the authority for this short-lived list; every
-- call is wrapped with retries (CLAUDE.md).

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Backoff = require(ServerScriptService.Util.Backoff)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PresenceService = require(script.Parent.PresenceService)
local PlotService = require(script.Parent.PlotService)

local cfg = Config.Raiding.Offline
local list = MemoryStoreService:GetSortedMap(if RunService:IsStudio() then cfg.StudioMapName else cfg.MapName)

local filling = false

local OfflineBaseService = {}

local function recordLeave(player: Player)
	local userId, name = player.UserId, player.Name
	task.spawn(function()
		Backoff.retry(`offline list add {userId}`, function()
			return list:SetAsync(tostring(userId), { Name = name }, cfg.TtlSeconds, os.time())
		end)
	end)
end

local function hasVaultCore(data: any): boolean
	if type(data) ~= "table" or type(data.Base) ~= "table" or data.Base.VaultTier < 1 then
		return false
	end
	for _, piece in data.Base.Pieces do
		if piece.Kind == "VaultCore" then
			return true
		end
	end
	return false
end

-- One pass: take down bases whose owner came back, then fill free plots.
-- Yields (MemoryStore + DataStore reads).
function OfflineBaseService.refill()
	if filling then
		return
	end
	filling = true

	for _, userId in PlotService.offlineIds() do
		local presence = PresenceService.getPresence(userId)
		if presence ~= "offline" then
			PlotService.releaseOffline(userId) -- refused while being raided
		end
	end

	local ok, entries = Backoff.retry("offline list read", function()
		return list:GetRangeAsync(Enum.SortDirection.Descending, cfg.Candidates)
	end)
	if ok and type(entries) == "table" then
		local shown: { [number]: boolean } = {}
		for _, userId in PlotService.offlineIds() do
			shown[userId] = true
		end
		for _, entry in entries do
			local userId = tonumber(entry.key)
			local name = type(entry.value) == "table" and entry.value.Name or "?"
			if userId and not shown[userId] and not Players:GetPlayerByUserId(userId) then
				if PresenceService.getPresence(userId) == "offline" then
					local data, sessionActive = PlayerDataService.viewAsync(userId)
					if data and not sessionActive and hasVaultCore(data) then
						if not PlotService.hostOffline(userId, name, data) then
							break -- no free plot left
						end
					end
				end
			end
		end
	end
	filling = false
end

function OfflineBaseService.start()
	Players.PlayerRemoving:Connect(recordLeave)
	task.spawn(function()
		while true do
			task.wait(cfg.FillSeconds)
			OfflineBaseService.refill()
		end
	end)
end

return OfflineBaseService
