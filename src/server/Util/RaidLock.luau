--!strict
-- The raid lock (13-build-guide.md § Part D, "The hard part", step 2): a
-- short-lived MemoryStore key per victim that says "a raid is running on
-- this player". MemoryStore is the authority for this state (06 § The hard
-- architectural constraint); the TTL frees it if a raiding server crashes.
--
-- A key holds { Kind, RaidId, JobId }:
--   Kind "raid"      a raid is in progress: nobody else may raid, and the
--                    victim's login waits until it's gone.
--   Kind "pending"   a theft message was sent and not applied yet: no new
--                    raid (it would read the old save and double-take), but
--                    the victim may log in; their login clears it.
--   Kind "released"  a raid ended with nothing stolen (short TTL).
-- Every call retries with backoff. A failed read means "locked": failing
-- safe beats two servers touching one profile.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Backoff = require(ServerScriptService.Util.Backoff)

local cfg = Config.Raiding.Lock
local RELEASED_TTL = 5 -- seconds a "released" marker lingers (then the key is gone)

local map = MemoryStoreService:GetHashMap(if RunService:IsStudio() then cfg.StudioMapName else cfg.MapName)

export type LockState = "free" | "raid" | "pending" | "unknown"

local RaidLock = {}

local function keyFor(userId: number): string
	return Config.Data.KeyPrefix .. userId
end

local function stateOf(value: any): LockState
	if type(value) ~= "table" then
		return "free"
	elseif value.Kind == "raid" then
		return "raid"
	elseif value.Kind == "pending" then
		return "pending"
	end
	return "free"
end

-- Yields.
function RaidLock.read(userId: number): LockState
	local ok, value = Backoff.retry(`raid lock read {userId}`, function()
		return map:GetAsync(keyFor(userId))
	end)
	return if ok then stateOf(value) else "unknown"
end

-- Compare-and-set: takes the lock only if it's free. True if WE hold it now.
-- Yields.
function RaidLock.acquire(userId: number, raidId: string): boolean
	local ok, result = Backoff.retry(`raid lock acquire {userId}`, function()
		return map:UpdateAsync(keyFor(userId), function(current: any): any
			if stateOf(current) ~= "free" then
				return nil -- someone else's raid, or a theft still pending: don't touch it
			end
			return { Kind = "raid", RaidId = raidId, JobId = game.JobId }
		end, cfg.TtlSeconds)
	end)
	return ok and type(result) == "table" and result.RaidId == raidId
end

-- Our raid is over. `stolen` = a theft message was sent, so switch to
-- "pending" until the victim's next login; otherwise release. Only touches
-- OUR lock. Yields.
function RaidLock.finish(userId: number, raidId: string, stolen: boolean): boolean
	local ok, result = Backoff.retry(`raid lock finish {userId}`, function()
		return map:UpdateAsync(keyFor(userId), function(current: any): any
			if type(current) ~= "table" or current.RaidId ~= raidId then
				return nil
			end
			return { Kind = if stolen then "pending" else "released", RaidId = raidId }
		end, if stolen then cfg.PendingSeconds else RELEASED_TTL)
	end)
	return ok and result ~= nil
end

-- Renews OUR raid lock's lifetime (a theft is still being saved). Yields.
function RaidLock.extend(userId: number, raidId: string): boolean
	local ok, result = Backoff.retry(`raid lock extend {userId}`, function()
		return map:UpdateAsync(keyFor(userId), function(current: any): any
			if type(current) ~= "table" or current.RaidId ~= raidId or current.Kind ~= "raid" then
				return nil
			end
			return current
		end, cfg.TtlSeconds)
	end)
	return ok and result ~= nil
end

-- Login gate: wait while a raid runs on this player (a few lock lifetimes
-- at most, since a lock being renewed means a theft is mid-save). Yields.
function RaidLock.waitUntilNoRaid(userId: number)
	local deadline = os.clock() + cfg.TtlSeconds * cfg.LoginWaitLifetimes
	while os.clock() < deadline do
		local state = RaidLock.read(userId)
		if state == "free" or state == "pending" then
			return
		end
		task.wait(cfg.LoginPollSeconds)
	end
end

-- The victim logged in and their pending theft messages are applied: they
-- can be raided offline again later. Yields.
function RaidLock.clearPending(userId: number)
	Backoff.retry(`raid lock clear {userId}`, function()
		return map:UpdateAsync(keyFor(userId), function(current: any): any
			if stateOf(current) ~= "pending" then
				return nil
			end
			return { Kind = "released" }
		end, RELEASED_TTL)
	end)
end

return RaidLock
