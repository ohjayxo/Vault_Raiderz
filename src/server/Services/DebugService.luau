--!strict
-- Studio-only debug commands (CLAUDE.md: gated behind RunService:IsStudio()).
-- The client sends a command NAME; the server re-checks IsStudio, so a live
-- server ignores these completely (R5).
--
-- Keys (src/client/DebugKeys.client.luau): P = print profile,
-- C = +credits, L = print presence, X = +Miner XP (to test the level curve),
-- V = next hit is Vaultborn, B = burst of test broadcasts (D58 drop rule),
-- T = next Vault Core tier (0-7, wraps), F = +Stone/Ore/Riftsalt into Exposed,
-- G = +Research Scrap into Exposed, H = show/hide the Banked/Exposed meter,
-- N = print your raid/neighborhood band and gear score (server-only numbers),
-- K = next pickaxe tier (wraps), J = +1 of every gadget, U = +1 armor piece
-- (alternates Wooden / Iron), Y = toggle PvP protection (FTUE rule 3 hook),
-- Q = Scav Wave on your base now, 6 = wave led by a Scav Captain,
-- Z = queue many waves at once (D59 cap test), 7 = +1 Captain's Cleaver skin,
-- 8 = fill free plots with offline bases now (instead of waiting 30 s),
-- 9 = +5 lockpicks (crafted at Workshop I from step 10),
-- 0 = 999 Sprint Serum for EVERY player on the server.
-- Step 8 (shields + charges): 5 = +3 Breach Charges, [ = fast-forward the
-- server clock 1 hour, ] = 24 hours, . = undo the fast-forward, ; = restart
-- your 48-hour shield, ' = start your 30-min post-raid shield, = = simulate
-- Blackout (drop all shields: yours must stay up), , = reset your lifetime
-- peak to your current tier (band tests), - = clear your shields now.
-- N also prints shields.
-- The Bag's small X buttons (Studio only) send DeleteItem / DeleteArmor
-- with an argument (item id / armor piece id).
-- (M = mine-remote spam lives entirely on the client: it fires the real
-- MineNode remote, exactly like an exploit script would.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local BandMetric = require(ServerScriptService.Util.BandMetric)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PresenceService = require(script.Parent.PresenceService)
local NodeService = require(script.Parent.NodeService)
local BroadcastQueue = require(script.Parent.BroadcastQueue)
local VaultService = require(script.Parent.VaultService)
local PlotService = require(script.Parent.PlotService)
local ShardService = require(script.Parent.ShardService)
local PickaxeService = require(script.Parent.PickaxeService)
local ArmorService = require(script.Parent.ArmorService)
local InventoryService = require(script.Parent.InventoryService)
local ScavWaveService = require(script.Parent.ScavWaveService)
local CosmeticService = require(script.Parent.CosmeticService)
local OfflineBaseService = require(script.Parent.OfflineBaseService)
local RaidProtectionService = require(script.Parent.RaidProtectionService)
local Clock = require(ServerScriptService.Util.Clock)

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

-- Moves Util/Clock's Studio offset (every shield timer reads it) and
-- re-sends everyone's shield timers so the Bag updates.
local function skipClock(seconds: number)
	Clock.setStudioOffset(Clock.getOffset() + seconds)
	for _, target in game:GetService("Players"):GetPlayers() do
		RaidProtectionService.refresh(target)
		print(`[Debug] {target.Name}: shields {RaidProtectionService.debugDescribe(target)}`)
	end
end

local commands: { [string]: (Player, any) -> () } = {
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
	-- Vault tier belongs to PlotService, so this writes it through the
	-- Studio debug path, then tells both UIs. It skips the lifetime peak on
	-- purpose (only real upgrades raise it; rejoining syncs it).
	NextVaultTier = function(player)
		local tierCount = #Config.Bank.CapacityByTier
		local ok = PlayerDataService.debugUpdate(player, "Base", function(base)
			base.VaultTier = (base.VaultTier + 1) % (tierCount + 1)
			return base
		end)
		VaultService.refresh(player)
		PlotService.refresh(player)
		local state = VaultService.getState(player)
		local base = PlayerDataService.get(player, "Base")
		print(`[Debug] {player.Name} Vault tier: {if ok then "ok" else "FAILED"}, now {base and base.VaultTier}, capacity {state and state.Capacity}, Scrap cap {state and state.ScrapCapacity}`)
	end,
	GrantExposedResources = function(player)
		local grant = Config.Bank.DebugResourceGrant
		local ok = VaultService.grant(player, grant)
		print(`[Debug] +{grant.Stone} Stone, +{grant.Ore} Ore, +{grant.Riftsalt} Riftsalt (Standard, Exposed) for {player.Name}: {if ok then "ok" else "FAILED"}`)
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
	PrintBand = function(player)
		local gear = PlayerDataService.get(player, "Gear")
		local armor = PlayerDataService.get(player, "Armor")
		local base = PlayerDataService.get(player, "Base")
		local peak = PlayerDataService.getPacked(player, "LifetimePeakVaultTier")
		local score = if gear and armor then BandMetric.gearScore(gear, armor) else nil
		print(`[Debug] {player.Name}: band {ShardService.getBand(player)} = highest of vault tier {base and base.VaultTier}, peak {peak}, gear score {score} / {Config.Sharding.GearScorePerBandTier}`)
		print(`[Debug] {player.Name}: shields {RaidProtectionService.debugDescribe(player)}`)
	end,
	-- ── Step 8: Breach Charges + shields ──
	GrantBreachCharges = function(player)
		local amount = Config.BreachCharges.DebugGrant
		local ok = InventoryService.add(player, Config.BreachCharges.ItemId, amount)
		print(`[Debug] +{amount} Breach Charges for {player.Name}: {if ok then "ok" else "FAILED"}`)
	end,
	SkipHour = function(_player)
		skipClock(Config.RaidProtection.DebugSkipSeconds.Hour)
	end,
	SkipDay = function(_player)
		skipClock(Config.RaidProtection.DebugSkipSeconds.Day)
	end,
	ResetClock = function(_player)
		skipClock(-Clock.getOffset())
	end,
	RestartNewAccountShield = function(player)
		local ok = RaidProtectionService.debugRestartNewAccount(player)
		print(`[Debug] {player.Name}: 48-hour shield restarted ({if ok then "ok" else "FAILED"}): {RaidProtectionService.debugDescribe(player)}`)
	end,
	StartPostRaidShield = function(player)
		local ok = RaidProtectionService.debugStartPostRaid(player)
		print(`[Debug] {player.Name}: 30-min shield started ({if ok then "ok" else "FAILED"}): {RaidProtectionService.debugDescribe(player)}`)
	end,
	-- The band uses the LIFETIME peak (D66), which key T never lowers and
	-- which rejoining raises to your current tier. This resets it to your
	-- current tier so band tests can be repeated.
	ResetPeak = function(player)
		local base = PlayerDataService.get(player, "Base")
		local tier = if base then base.VaultTier else 0
		local ok = PlayerDataService.debugSetPacked(player, "LifetimePeakVaultTier", tier)
		print(`[Debug] {player.Name}: lifetime peak reset to {tier} ({if ok then "ok" else "FAILED"}), band now {ShardService.getBand(player)}`)
	end,
	ClearShields = function(player)
		local ok = RaidProtectionService.debugClear(player)
		print(`[Debug] {player.Name}: shields cleared ({if ok then "ok" else "FAILED"}): {RaidProtectionService.debugDescribe(player)}`)
	end,
	SimulateBlackout = function(player)
		RaidProtectionService.dropAllShields(Config.RaidProtection.DebugDropAllSeconds, "Simulated Blackout (Studio)")
		print(`[Debug] {player.Name}'s shields after the drop: {RaidProtectionService.debugDescribe(player)}`)
	end,
	-- Pickaxes, armor and gadgets come from Workshop crafting (step 10).
	NextPickaxeTier = function(player)
		local tier = PickaxeService.getTier(player) % #Config.Combat.PickaxeTiers + 1
		local ok = PickaxeService.setTier(player, tier)
		print(`[Debug] {player.Name} pickaxe: {if ok then "ok" else "FAILED"}, now {Config.Combat.PickaxeTiers[tier]} ({Config.Combat.PointsByTier[tier]} points)`)
	end,
	GrantSprintSerum = function(_player)
		local amount = Config.Data.DebugSprintSerumGrant
		for _, target in game:GetService("Players"):GetPlayers() do
			local ok = InventoryService.add(target, "SprintSerum", amount)
			print(`[Debug] +{amount} Sprint Serum for {target.Name}: {if ok then "ok" else "FAILED"}`)
		end
	end,
	-- The Bag's X on an item row: delete all of that item.
	DeleteItem = function(player, itemId)
		if type(itemId) ~= "string" then
			return
		end
		local count = InventoryService.count(player, itemId)
		if count > 0 then
			InventoryService.consume(player, itemId, count)
		end
		print(`[Debug] deleted {count} {itemId} from {player.Name}`)
	end,
	-- The Bag's X on an armor row: delete that piece (worn or not).
	DeleteArmor = function(player, pieceId)
		if type(pieceId) ~= "string" then
			return
		end
		local ok = ArmorService.debugDelete(player, pieceId)
		print(`[Debug] deleted armor {pieceId} from {player.Name}: {if ok then "ok" else "not found"}`)
	end,
	GrantGadgets = function(player)
		for _, gadgetId in Config.Gadgets.Order do
			InventoryService.add(player, gadgetId, 1)
		end
		print(`[Debug] +1 of every gadget for {player.Name}`)
	end,
	GrantArmor = function(player)
		local armor = ArmorService.get(player)
		local owned = 0
		if armor then
			for _ in armor.Pieces do
				owned += 1
			end
		end
		local tier = owned % 2 + 1 -- Wooden, Iron, Wooden, ... (the slice's reachable tiers)
		local id = ArmorService.grant(player, tier, Config.Combat.ArmorSlots[1])
		print(`[Debug] +1 {Config.Combat.PickaxeTiers[tier]} armor for {player.Name}: {if id then "ok" else "FAILED"} (equip it in the Gear menu)`)
	end,
	TogglePvpProtection = function(player)
		local attribute = Config.Combat.PvpProtectedAttribute
		local protected = not player:GetAttribute(attribute)
		player:SetAttribute(attribute, protected)
		print(`[Debug] {player.Name} PvP protection {if protected then "ON (can't hit or be hit by players)" else "OFF"}`)
	end,
	GrantSkin = function(player)
		local skinId = Config.Cosmetics.DebugSkin
		local ok = CosmeticService.grantSkin(player, skinId)
		print(`[Debug] +1 {skinId} skin for {player.Name}: {if ok then "ok" else "FAILED"} (equip it in the Gear menu)`)
	end,
	FillOfflineBases = function(player)
		print(`[Debug] {player.Name}: filling free plots with offline bases...`)
		task.spawn(OfflineBaseService.refill)
	end,
	GrantLockpicks = function(player)
		local amount = Config.Raiding.Lockpick.DebugPickGrant
		local ok = InventoryService.add(player, Config.Raiding.Lockpick.ItemId, amount)
		print(`[Debug] +{amount} lockpicks for {player.Name}: {if ok then "ok" else "FAILED"}`)
	end,
	StartWave = function(player)
		ScavWaveService.debugStartWave(player, false)
		print(`[Debug] Scav Wave queued on {player.Name}'s base: {ScavWaveService.debugStatus()}`)
	end,
	StartCaptainWave = function(player)
		ScavWaveService.debugStartWave(player, true)
		print(`[Debug] Captain wave queued on {player.Name}'s base: {ScavWaveService.debugStatus()}`)
	end,
	FloodWaves = function(player)
		ScavWaveService.debugFlood(player)
		print(`[Debug] flooded waves on {player.Name}: {ScavWaveService.debugStatus()}`)
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
	Remotes.getEvent("DebugCommand").OnServerEvent:Connect(function(player: Player, command: unknown, argument: unknown)
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
			handler(player, argument)
		end
	end)
end

return DebugService
