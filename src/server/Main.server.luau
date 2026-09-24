--!strict
-- Server entry point. Every system's service gets started from here as the
-- build steps add them (docs/13-build-guide.md § Part D). R5: the server is
-- the only authority, so this is where all logic boots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

print("Vault Raiderz server up")

-- Remotes must exist before any client asks for them (clients WaitForChild).
Remotes.init()

local Services = script.Parent.Services

-- Step 1: data layer first; everything else sits on it.
require(Services.PlayerDataService).start()
require(Services.PresenceService).start()
-- Step 7: raiding. Started right after the data layer: it installs the
-- login gate + message handlers every profile load must go through.
require(Services.RaidService).start()
require(Services.MovementService).start()

-- Step 2: nodes, Grade rolls, broadcasts. Step 3: VaultService (Bank/Exposed).
require(Services.VaultService).start()
require(Services.BroadcastQueue).start()
require(Services.NodeService).start()

-- Step 4: plots, base building, build budget (sharding is a stub inside).
require(Services.PlotService).start()

-- Step 5: combat, pickaxe upgrades, armor, gadgets. (MovementService and
-- InventoryService have nothing to start.)
require(Services.ArmorService).start()
require(Services.CosmeticService).start()
require(Services.PickaxeService).start()
require(Services.GadgetService).start()
require(Services.CombatService).start()

-- Step 6: defenses, Scavs, Scav Waves (+ Captain).
require(Services.DefenseService).start()
require(Services.ScavService).start()
require(Services.ScavWaveService).start()
require(Services.OfflineBaseService).start()

-- Step 8: Breach Charges (crafting), raid band + shields.
require(Services.RaidProtectionService).start()
require(Services.CraftingService).start()

-- Step 9: Reputation/Level, Credits + NPC buyer, direct trade. Reputation
-- first: the other two grant Trader XP through it.
require(Services.ReputationService).start()
require(Services.EconomyService).start()
require(Services.TradeService).start()

require(Services.DebugService).start() -- ignores commands outside Studio

-- THROWAWAY build step 0B (mobile perf spike). Delete with src/server/PerfSpike.
if Config.PerfSpike.Enabled then
	require(script.Parent.PerfSpike).start()
end
