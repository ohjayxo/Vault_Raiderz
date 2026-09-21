--!strict
-- Studio-only debug commands (CLAUDE.md: gated behind RunService:IsStudio()).
-- The client sends a command NAME; the server re-checks IsStudio, so a live
-- server ignores these completely (R5).
--
-- Keys (src/client/DebugKeys.client.luau): P = print profile,
-- C = +credits, L = print presence, X = +Miner XP (to test the level curve),
-- V = next hit is Vaultborn, B = burst of test broadcasts (D58 drop rule),
-- T = next Vault Core tier (0-7, wraps), F = +Stone into Exposed,
-- G = +Research Scrap into Exposed, H = show/hide the Banked/Exposed meter.
-- (M = mine-remote spam lives entirely on the client: it fires the real
-- MineNode remote, exactly like an exploit script would.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PresenceService = require(script.Parent.PresenceService)
local NodeService = require(script.Parent.NodeService)
local BroadcastQueue = require(script.Parent.BroadcastQueue)
local VaultService = require(script.Parent.VaultService)

-- Key B: more items than MaxPending (6), mixed priorities, all at once.
-- Expected with the step 2 Config: flex 1 goes out at once; Vaultborn 2
-- evicts flex 2; flex 7 is dropped on arrival; both raid alerts are kept
-- past the cap. Send order: flex 1, raid 1, raid 2, Vaultborn 1, Vaultborn 2,
-- flex 3, 4, 5, 6.
local BROADCAST_TEST: { { kind: string, text: string } } = {
	{ kind = "CosmeticFlex", text = "[TEST] flex 1" },
	{ kind = "CosmeticFlex", text = "[TEST] flex 2" },
	{ kind = "CosmeticFlex", text = "[TEST] flex 3" },
	{ kind = "Vaultborn", text = "[TEST] Vaultborn 1" },
	{ kind = "CosmeticFlex", text = "[TEST] flex 4" },
	{ kind = "CosmeticFlex", text = "[TEST] flex 5" },
	{ kind = "CosmeticFlex", text = "[TEST] flex 6" },
	{ kind = "Vaultborn", text = "[TEST] Vaultborn 2" },
	{ kind = "RaidAlert", text = "[TEST] raid alert 1" },
	{ kind = "CosmeticFlex", text = "[TEST] flex 7" },
	{ kind = "RaidAlert", text = "[TEST] raid alert 2" },
}

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
	ForceVaultborn = function(player)
		NodeService.debugForceNextGrade(player, "Vaultborn")
		print(`[Debug] {player.Name}'s next successful hit will be Vaultborn`)
	end,
	-- Vault tier belongs to BaseService (step 4), so this writes it through
	-- the Studio debug path, then tells VaultService the capacity changed.
	NextVaultTier = function(player)
		local tierCount = #Config.Bank.CapacityByTier
		local ok = PlayerDataService.debugUpdate(player, "Base", function(base)
			base.VaultTier = (base.VaultTier + 1) % (tierCount + 1)
			return base
		end)
		VaultService.refresh(player)
		local state = VaultService.getState(player)
		local base = PlayerDataService.get(player, "Base")
		print(`[Debug] {player.Name} Vault tier: {if ok then "ok" else "FAILED"}, now {base and base.VaultTier}, capacity {state and state.Capacity}, Scrap cap {state and state.ScrapCapacity}`)
	end,
	GrantExposedStone = function(player)
		local ok = VaultService.deposit(player, "Stone", Config.Grade.Names[1], Config.Bank.DebugResourceGrant)
		print(`[Debug] +{Config.Bank.DebugResourceGrant} Standard Stone (Exposed) for {player.Name}: {if ok then "ok" else "FAILED"}`)
	end,
	GrantScrap = function(player)
		local ok = VaultService.depositScrap(player, Config.Bank.DebugScrapGrant)
		print(`[Debug] +{Config.Bank.DebugScrapGrant} Scrap (Exposed) for {player.Name}: {if ok then "ok" else "FAILED"}`)
	end,
	ToggleMeter = function(player)
		local visible = not VaultService.isMeterVisible(player)
		VaultService.setMeterVisible(player, visible)
		print(`[Debug] {player.Name}'s Banked/Exposed meter {if visible then "shown" else "hidden"}`)
	end,
	BroadcastTest = function(player)
		print(`[Debug] {player.Name} pushed {#BROADCAST_TEST} test broadcasts`)
		for _, entry in BROADCAST_TEST do
			BroadcastQueue.push(entry.kind, entry.text)
		end
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
