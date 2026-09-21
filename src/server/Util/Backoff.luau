--!strict
-- Retry with exponential backoff for DataStore / MemoryStore calls.
-- CLAUDE.md: "Wrap every DataStore/MemoryStore call in pcall with
-- retries/backoff." 13-build-guide.md § B8: Studio's MemoryStore quota is
-- tiny, so failures must slow down, never loop fast.
--
-- Yields. Call it from a task.spawn'ed thread when you can't wait.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local cfg = Config.Data.Backoff
local rng = Random.new()

local Backoff = {}

-- Seconds to wait after the `attempt`-th failure (1-based): 1, 2, 4, 8... capped.
function Backoff.delayFor(attempt: number): number
	local raw = math.min(cfg.BaseSeconds * 2 ^ (attempt - 1), cfg.MaxSeconds)
	return raw * (1 + rng:NextNumber(-cfg.Jitter, cfg.Jitter))
end

-- Calls `fn` until it succeeds or attempts run out.
-- Returns (true, fn's result) or (false, last error message).
function Backoff.retry(label: string, fn: () -> any): (boolean, any)
	local lastError = ""
	for attempt = 1, cfg.MaxAttempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		if attempt < cfg.MaxAttempts then
			warn(`[Backoff] {label} failed (attempt {attempt}/{cfg.MaxAttempts}): {lastError}`)
			task.wait(Backoff.delayFor(attempt))
		end
	end
	warn(`[Backoff] {label} gave up after {cfg.MaxAttempts} attempts: {lastError}`)
	return false, lastError
end

return Backoff
