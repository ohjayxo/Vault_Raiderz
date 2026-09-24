--!strict
-- ReputationService: the Miner / Trader / Raider XP tracks and the Level.
-- The only service that writes the packed XP fields (Config.Data.Packed).
--
-- Docs: 03-progression.md § Reputation tracks (D81), § Level (D82);
-- 06-economy.md § Access gating (trading unlocks at Level 10 [PH]);
-- 07-decisions.md D80 (Level is derived from the packed XP, never stored).
--
-- * XP is only ever granted by server code that has just validated an action
--   (a node finished, a sale made, a raid escaped, a wave defended): R5.
-- * Rewards are titles/cosmetics only, never stats (D81). They are STUBBED
--   this step: reaching a track level logs what it would unlock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)
local LevelCurve = require(ReplicatedStorage.Shared.LevelCurve)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local OWNER = "ReputationService"
local progCfg = Config.Progression

local levelUpEvent = Instance.new("BindableEvent")

local ReputationService = {}

-- Fires (player, track, newTrackLevel) each time a track level is reached.
ReputationService.LevelUp = levelUpEvent.Event

-- Each track's XP field and its largest storable value (its bit width).
local fieldOf: { [string]: string } = {}
local maxXpOf: { [string]: number } = {}
do
	local words: { [string]: { { Name: string, Bits: number } } } = Config.Data.Packed :: any
	for _, track in progCfg.Tracks do
		local field = `{track}XP`
		for _, slot in words.Reputation do
			if slot.Name == field then
				fieldOf[track] = field
				maxXpOf[track] = 2 ^ slot.Bits - 1
			end
		end
		assert(fieldOf[track], `Config.Data.Packed.Reputation has no "{field}"`)
	end
end

-- The player's Level and tracks, or nil if their profile isn't loaded.
function ReputationService.getState(player: Player): Types.ReputationState?
	local tracks: { [string]: Types.TrackState } = {}
	local level = 0
	for _, track in progCfg.Tracks do
		local xp = PlayerDataService.getPacked(player, fieldOf[track])
		if not xp then
			return nil
		end
		local trackLevel = LevelCurve.trackLevel(xp)
		tracks[track] = {
			Level = trackLevel,
			XP = xp,
			Prev = LevelCurve.xpForTrackLevel(trackLevel),
			Next = LevelCurve.xpForTrackLevel(trackLevel + 1),
		}
		level += trackLevel
	end
	return { Level = level, Tracks = tracks, TradeUnlocked = level >= progCfg.TradeUnlockLevel }
end

-- 0 if the profile isn't loaded, so a gate check fails closed.
function ReputationService.getLevel(player: Player): number
	local state = ReputationService.getState(player)
	return if state then state.Level else 0
end

-- The Level-10 gate for direct trading (06 § Access gating, D82).
function ReputationService.isTradeUnlocked(player: Player): boolean
	return ReputationService.getLevel(player) >= progCfg.TradeUnlockLevel
end

function ReputationService.refresh(player: Player)
	local state = ReputationService.getState(player)
	if state then
		Remotes.getEvent("ReputationChanged"):FireClient(player, state)
	end
end

-- Adds XP to one track (server code only, after it validated the action).
-- `reason` is for the log. Returns true if saved.
function ReputationService.grant(player: Player, track: string, xp: number, reason: string): boolean
	assert(fieldOf[track], `ReputationService.grant: unknown track "{track}"`)
	assert(xp > 0 and xp == math.floor(xp), `ReputationService.grant: bad xp {xp}`)
	local field = fieldOf[track]
	local before = PlayerDataService.getPacked(player, field)
	if not before then
		return false
	end
	-- Past the bit width the value would clamp with a warning: stop at the cap.
	local after = math.min(before + xp, maxXpOf[track])
	if after == before then
		return true
	end
	if not PlayerDataService.setPacked(player, field, OWNER, after) then
		return false
	end

	local levelBefore, levelAfter = LevelCurve.trackLevel(before), LevelCurve.trackLevel(after)
	if levelAfter > levelBefore then
		local rewards: { [string]: { [number]: string } } = progCfg.TrackRewards :: any
		for reached = levelBefore + 1, levelAfter do
			local reward = rewards[track] and rewards[track][reached]
			print(`[Reputation] {player.Name}: {track} level {reached} (Level {ReputationService.getLevel(player)}){if reward then `, would unlock title "{reward}" (stub)` else ""}`)
			levelUpEvent:Fire(player, track, reached)
		end
	end
	ReputationService.refresh(player)
	return true
end

-- Studio debug: sets a track's XP directly (DebugService, key `).
function ReputationService.debugSetTrackLevel(player: Player, track: string, level: number)
	assert(game:GetService("RunService"):IsStudio(), "debugSetTrackLevel is Studio-only")
	local xp = math.min(LevelCurve.xpForTrackLevel(level), maxXpOf[track])
	PlayerDataService.debugSetPacked(player, fieldOf[track], xp)
	ReputationService.refresh(player)
end

function ReputationService.start()
	PlayerDataService.Loaded:Connect(function(player: Player)
		ReputationService.refresh(player)
	end)

	-- Start-up snapshot for the Bag / Trade button, in case they missed the push.
	local allow = RateLimiter.new("GetProgressState", progCfg.StateCooldownSeconds)
	Remotes.getFunction("GetProgressState").OnServerInvoke = function(player: Player): (number?, Types.ReputationState?)
		if not allow(player) then
			return nil, nil
		end
		local credits = PlayerDataService.get(player, "Credits")
		return credits, ReputationService.getState(player)
	end
end

return ReputationService
