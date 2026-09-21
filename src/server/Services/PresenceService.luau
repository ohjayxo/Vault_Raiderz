--!strict
-- PresenceService (STUB for build step 7's offline raids).
--
-- 13-build-guide.md § Part D, "The hard part", step 1: each online player's
-- server writes a short-lived "online on server X" key in MemoryStore and
-- keeps refreshing it. A raiding server will read it: an offline raid is only
-- allowed when there is NO key. MemoryStore is the authority for this
-- short-lived state; the TTL means a crashed server's keys expire by themselves.
--
-- Nothing reads presence yet. Callers must treat "unknown" (a failed read) as
-- "don't raid": failing safe beats letting two servers touch one profile.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Backoff = require(ServerScriptService.Util.Backoff)

local cfg = Config.Data.Presence

export type Presence = "online" | "offline" | "unknown"

local PresenceService = {}

local map = MemoryStoreService:GetHashMap(if RunService:IsStudio() then cfg.StudioMapName else cfg.MapName)
-- Each join gets a fresh token. A "left" mark only applies if the key still
-- holds OUR token, so a slow leave from an old session (this server or
-- another) can never wipe the key a newer session just wrote. Without this, a
-- player who hops servers could briefly look offline while online, which is
-- exactly the state that would allow an offline raid (step 7).
local tokens: { [number]: string } = {} -- userId -> current join token
local writing: { [string]: boolean } = {} -- token -> write in flight

local function keyFor(userId: number): string
	return Config.Data.KeyPrefix .. userId
end

local function markLeft(userId: number, token: string)
	Backoff.retry(`presence leave {userId}`, function()
		return map:UpdateAsync(keyFor(userId), function(current: any): any
			if type(current) == "table" and current.Token == token then
				return { Left = true, Token = token }
			end
			return nil -- a newer session owns the key: leave it alone
		end, cfg.TtlSeconds)
	end)
end

local function write(userId: number)
	local token = tokens[userId]
	if not token or writing[token] then
		return
	end
	writing[token] = true
	Backoff.retry(`presence write {userId}`, function()
		if tokens[userId] ~= token then
			return nil -- left (or rejoined) while we were backing off
		end
		return map:SetAsync(
			keyFor(userId),
			{ JobId = game.JobId, PlaceId = game.PlaceId, At = os.time(), Token = token },
			cfg.TtlSeconds
		)
	end)
	writing[token] = nil
	-- The player left while our write was in flight, so it may have landed
	-- after their leave mark: mark it left again, then restore any newer session.
	if tokens[userId] ~= token then
		markLeft(userId, token)
		if tokens[userId] then
			write(userId)
		end
	end
end

-- Is this player online on some server? Yields (MemoryStore read with retries).
-- Returns the JobId of their server when online.
function PresenceService.getPresence(userId: number): (Presence, string?)
	local ok, value = Backoff.retry(`presence read {userId}`, function()
		return map:GetAsync(keyFor(userId))
	end)
	if not ok then
		return "unknown", nil
	elseif type(value) == "table" and not value.Left then
		return "online", value.JobId
	end
	return "offline", nil
end

function PresenceService.start()
	assert(RunService:IsServer(), "PresenceService.start() may only run on the server")

	local function onJoin(player: Player)
		tokens[player.UserId] = HttpService:GenerateGUID(false)
		task.spawn(write, player.UserId) -- as early as possible: blocks offline raids while loading
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end

	-- Also fires for everyone when the server shuts down.
	Players.PlayerRemoving:Connect(function(player)
		local token = tokens[player.UserId]
		tokens[player.UserId] = nil
		if token then
			task.spawn(markLeft, player.UserId, token)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(cfg.RefreshSeconds)
			for userId in tokens do
				task.spawn(write, userId)
			end
		end
	end)
end

return PresenceService
