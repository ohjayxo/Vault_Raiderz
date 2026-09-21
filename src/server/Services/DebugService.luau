--!strict
-- Studio-only debug commands (CLAUDE.md: gated behind RunService:IsStudio()).
-- The client sends a command NAME; the server re-checks IsStudio, so a live
-- server ignores these completely (R5).
--
-- Keys (src/client/DebugKeys.client.luau): P = print profile,
-- C = +credits, L = print presence, X = +Miner XP (to test the level curve).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PresenceService = require(script.Parent.PresenceService)

local DebugService = {}

local commands: { [string]: (Player) -> () } = {
	PrintProfile = function(player)
		print(PlayerDataService.debugDescribe(player))
	end,
	GrantCredits = function(player)
		local ok = PlayerDataService.debugUpdate(player, "Credits", function(credits: number)
			return credits + Config.Data.DebugCreditGrant
		end)
		print(`[Debug] +{Config.Data.DebugCreditGrant} Credits for {player.Name}: {if ok then "ok" else "FAILED"}, now {PlayerDataService.get(player, "Credits")}`)
	end,
	GrantMinerXP = function(player)
		local current = PlayerDataService.getPacked(player, "MinerXP") or 0
		local ok = PlayerDataService.debugSetPacked(player, "MinerXP", current + Config.Data.DebugXPGrant)
		print(`[Debug] +{Config.Data.DebugXPGrant} Miner XP for {player.Name}: {if ok then "ok" else "FAILED"}, now {PlayerDataService.getPacked(player, "MinerXP")} (press P for levels)`)
	end,
	PrintPresence = function(player)
		local presence, jobId = PresenceService.getPresence(player.UserId)
		print(`[Debug] presence of {player.Name}: {presence}{if jobId then ` (server "{jobId}")` else ""}`)
	end,
}

function DebugService.start()
	local allow = RateLimiter.new("DebugCommand", Config.Data.DebugCooldownSeconds)
	Remotes.getEvent("DebugCommand").OnServerEvent:Connect(function(player: Player, command: unknown)
		-- Rate limit first, so spamming this on a live server can't flood the logs.
		if not allow(player) then
			return
		end
		if not RunService:IsStudio() then
			warn(`[Debug] {player.Name} ({player.UserId}) sent a debug command on a live server`)
			return
		end
		if typeof(command) ~= "string" then
			return
		end
		local handler = commands[command]
		if handler then
			handler(player)
		end
	end)
end

return DebugService
