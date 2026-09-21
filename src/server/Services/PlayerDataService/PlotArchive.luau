--!strict
-- D55 / 02-core-loop.md § Plot lifecycle: a plot inactive past ~1 year [PH]
-- archives to compressed cold storage and restores fully when the player
-- returns. Hibernation, never deletion (R2).
--
-- STUB (Prompt 1): only the staleness check is real. The archive job and the
-- restore path log and do nothing until the storage cap actually matters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SECONDS_PER_DAY = 86400

local PlotArchive = {}

-- True if a plot last active at `lastActiveAt` would be archived at `now`.
function PlotArchive.isStale(lastActiveAt: number, now: number): boolean
	return lastActiveAt > 0 and now - lastActiveAt >= Config.Data.ArchiveAfterDays * SECONDS_PER_DAY
end

-- Would move an offline player's plot to cold storage. Not built yet.
function PlotArchive.archive(profileKey: string): boolean
	warn(`[PlotArchive] archive({profileKey}) is a stub (D55); nothing archived`)
	return false
end

-- Called on every load. Would bring an archived plot back before the player
-- sees their base. Not built yet; nothing is ever archived today.
function PlotArchive.restoreIfArchived(data: any)
	if data.Base.Archived then
		warn("[PlotArchive] profile is marked archived, but restore is a stub (D55)")
	end
end

return PlotArchive
