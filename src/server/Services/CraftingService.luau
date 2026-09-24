--!strict
-- CraftingService: turns resources into counted items. Step 8 has one
-- recipe, Breach Charges from Riftsalt (05-items.md § The Riftsalt rule;
-- 02-core-loop.md § Preconditions). Workshop I (step 10) adds its recipes
-- here (lockpicks, gadgets: docs-build/backlog.md).
--
-- The client only names what it wants to craft (R5). Recipes, costs and
-- the spend order live on the server: VaultService.spend takes Exposed
-- first, lowest Grade first (the step 4 rule), all or nothing.
-- Crafting works anywhere for now (Josh's call, step 8: a row on the Bag's
-- Items tab); a station check would go in `craft` once Workshop I exists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local VaultService = require(script.Parent.VaultService)
local InventoryService = require(script.Parent.InventoryService)

type Recipe = { Cost: { [string]: number }, Amount: number }

local chargeCfg = Config.BreachCharges

-- item id -> recipe. Only what's listed here can ever be crafted.
local recipes: { [string]: Recipe } = {
	[chargeCfg.ItemId] = { Cost = chargeCfg.Cost, Amount = 1 },
}

local CraftingService = {}

local function craft(player: Player, itemArg: unknown): (boolean, string?)
	if type(itemArg) ~= "string" then
		return false, "Invalid"
	end
	local recipe = recipes[itemArg]
	if not recipe then
		return false, "Invalid"
	end
	if not PlayerDataService.isLoaded(player) then
		return false, "Busy"
	end
	if not VaultService.spend(player, recipe.Cost) then
		return false, "CantAfford"
	end
	if not InventoryService.add(player, itemArg, recipe.Amount) then
		-- Refund (as Standard Exposed units, like every other refund).
		VaultService.grant(player, recipe.Cost)
		return false, "Failed"
	end
	print(`[Craft] {player.Name} crafted {recipe.Amount} {itemArg}`)
	return true, nil
end

function CraftingService.start()
	local allow = RateLimiter.new("Craft", chargeCfg.CraftCooldownSeconds)
	Remotes.getFunction("Craft").OnServerInvoke = function(player: Player, itemArg: unknown): (boolean, string?)
		if not allow(player) then
			return false, "Busy"
		end
		return craft(player, itemArg)
	end
end

return CraftingService
