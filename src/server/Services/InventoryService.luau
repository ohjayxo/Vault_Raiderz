--!strict
-- InventoryService: counted items (gadgets now; Breach Charges and
-- components later). The only service that writes the Items section
-- (Config.Data.SectionOwners). 05-items.md § Taxonomy.
--
-- Only server code calls this, with amounts the server decided (R5).

local PlayerDataService = require(script.Parent.PlayerDataService)

local OWNER = "InventoryService"

local changedEvent = Instance.new("BindableEvent")

local InventoryService = {}

-- Fires (player) after their items change.
InventoryService.Changed = changedEvent.Event

local function checkAmount(amount: number, caller: string)
	assert(amount > 0 and amount == math.floor(amount), `InventoryService.{caller}: bad amount {amount}`)
end

-- All the player's counted items (a copy), or nil if not loaded.
function InventoryService.getAll(player: Player): { [string]: number }?
	return PlayerDataService.get(player, "Items")
end

function InventoryService.count(player: Player, itemId: string): number
	local items = InventoryService.getAll(player)
	return if items then items[itemId] or 0 else 0
end

function InventoryService.add(player: Player, itemId: string, amount: number): boolean
	checkAmount(amount, "add")
	local ok = PlayerDataService.update(player, "Items", OWNER, function(items: { [string]: number })
		items[itemId] = (items[itemId] or 0) + amount
		return items
	end)
	if ok then
		changedEvent:Fire(player)
	end
	return ok
end

-- Takes `amount` if the player has that many. All or nothing.
function InventoryService.consume(player: Player, itemId: string, amount: number): boolean
	checkAmount(amount, "consume")
	local taken = false
	local ok = PlayerDataService.update(player, "Items", OWNER, function(items: { [string]: number })
		local have = items[itemId] or 0
		if have >= amount then
			-- Drop the key at zero so the saved table stays small.
			local counts: { [string]: number? } = items
			counts[itemId] = if have == amount then nil else have - amount
			taken = true
		end
		return items
	end)
	if ok and taken then
		changedEvent:Fire(player)
		return true
	end
	return false
end

return InventoryService
