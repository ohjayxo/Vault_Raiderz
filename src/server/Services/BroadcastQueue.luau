--!strict
-- BroadcastQueue: the ONE queue every server-wide announcement goes through.
-- 06-economy.md § Broadcast priority queue (D58):
--   * rate-limited: at most one announcement per Config.Broadcast.MinGapSeconds
--   * prioritized: the most important waiting item goes next
--   * overflow: past MaxPending the LEAST important item is dropped, and a
--     top-priority item (raid-owner alerts, Chase pings) is never dropped
--
-- Step 2 only sends Vaultborn announcements. Steps 7+ add raid alerts and
-- Chase pings by calling push() with their kind (priorities live in Config).
-- This queue delivers to this server only. Cross-server messages, if ever
-- needed, must also go through here (and MessagingService is only a hint).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local cfg = Config.Broadcast
local priorities: { [string]: number } = cfg.Priorities :: any

type Item = {
	kind: string,
	priority: number,
	text: string,
	recipients: { Player }?, -- nil = everyone on the server
	seq: number, -- arrival order, so equal priorities go first-come first-served
}

local pending: { Item } = {}
local nextSeq = 0
local pumpThread: thread? = nil
local pumpIdle = false

local BroadcastQueue = {}

local function describe(item: Item): string
	return `{item.kind} (priority {item.priority}): "{item.text}"`
end

-- Index of the item to drop on overflow: least important, oldest among ties.
-- Never a top-priority item.
local function findDroppable(): number?
	local worstIndex: number? = nil
	for i, item in pending do
		if item.priority <= cfg.NeverDropPriority then
			continue
		end
		local worst = if worstIndex then pending[worstIndex] else nil
		if not worst or item.priority > worst.priority or (item.priority == worst.priority and item.seq < worst.seq) then
			worstIndex = i
		end
	end
	return worstIndex
end

-- Index of the next item to send: most important, oldest among ties.
local function findNext(): number?
	local bestIndex: number? = nil
	for i, item in pending do
		local best = if bestIndex then pending[bestIndex] else nil
		if not best or item.priority < best.priority or (item.priority == best.priority and item.seq < best.seq) then
			bestIndex = i
		end
	end
	return bestIndex
end

local function deliver(item: Item)
	local event = Remotes.getEvent("Announcement")
	if item.recipients then
		for _, player in item.recipients do
			if player.Parent == Players then -- skip anyone who left while it waited
				event:FireClient(player, item.kind, item.text)
			end
		end
	else
		event:FireAllClients(item.kind, item.text)
	end
	print(`[Broadcast] sent {describe(item)}`)
end

local function pump()
	while true do
		local index = findNext()
		if index then
			deliver(table.remove(pending, index) :: Item)
			task.wait(cfg.MinGapSeconds)
		else
			pumpIdle = true
			coroutine.yield() -- push() wakes us
			pumpIdle = false
		end
	end
end

-- Queue an announcement. `kind` must be a key of Config.Broadcast.Priorities.
-- Returns false if it was dropped because the queue is full of more
-- important items.
function BroadcastQueue.push(kind: string, text: string, recipients: { Player }?): boolean
	local priority = priorities[kind]
	if priority == nil then
		error(`BroadcastQueue: unknown kind "{kind}" (add it to Config.Broadcast.Priorities)`, 2)
	end
	nextSeq += 1
	local item: Item = { kind = kind, priority = priority, text = text, recipients = recipients, seq = nextSeq }

	if #pending >= cfg.MaxPending and priority > cfg.NeverDropPriority then
		local dropIndex = findDroppable()
		local drop = if dropIndex then pending[dropIndex] else nil
		if not drop or drop.priority <= priority then
			-- Nothing waiting is less important than this one: drop the newcomer.
			print(`[Broadcast] queue full, dropped new {describe(item)}`)
			return false
		end
		table.remove(pending, dropIndex :: number)
		print(`[Broadcast] queue full, dropped {describe(drop)} for a more important one`)
	end
	-- Top priority is appended even past MaxPending (D58: never dropped).
	table.insert(pending, item)

	if pumpThread and pumpIdle then
		task.spawn(pumpThread)
	end
	return true
end

function BroadcastQueue.start()
	pumpThread = task.spawn(pump)
end

return BroadcastQueue
