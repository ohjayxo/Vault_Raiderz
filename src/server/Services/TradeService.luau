--!strict
-- TradeService: the direct trade window. The only service that writes the
-- TradeHistory section (Config.Data.SectionOwners). It moves goods only by
-- calling the services that own them (Vault, Inventory, Cosmetics, Economy).
--
-- Docs: 06-economy.md § Zero-chat trade (D61), § Trade Safety, § Access
-- gating (D82); 05-items.md § Taxonomy (what trades), D111, D112.
--
-- How a trade stays atomic (no dupes, no loss):
--  1. The server owns the window. Clients send intents ("set 5 Ore",
--     "Confirm"); the server keeps both offers and pushes the full state to
--     both players on every change.
--  2. Any change bumps the offer VERSION, clears both Confirms and restarts
--     the 5-second lock (06 § Trade Safety). A Confirm only counts with the
--     current version, and the server checks the lock time itself.
--  3. The commit re-checks that both sides still own everything, then does
--     every debit and credit in ONE run with no yielding. Each step has an
--     undo; if any step fails, the finished steps are undone and the trade is
--     cancelled with nothing changed. Nothing can interleave with it, so a
--     player leaving or acting can't split the swap.
--  4. Both profiles are saved right after (PlayerDataService.saveNow) and
--     each gets a history entry with the same trade id.
-- Same-server only in the slice: profiles are session-locked, so a player
-- can't be in two servers at once. Remaining risk (logged in the step 9
-- summary): the two profile saves are separate DataStore writes, so a
-- server crash in the moments between them could lose or duplicate one side;
-- the shared trade id in both histories is what settles such a dispute.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)
local Clock = require(ServerScriptService.Util.Clock)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local AnomalyLog = require(ServerScriptService.Util.AnomalyLog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local VaultService = require(script.Parent.VaultService)
local InventoryService = require(script.Parent.InventoryService)
local CosmeticService = require(script.Parent.CosmeticService)
local EconomyService = require(script.Parent.EconomyService)
local ReputationService = require(script.Parent.ReputationService)
local RaidService = require(script.Parent.RaidService)

local OWNER = "TradeService"
local tradeCfg = Config.Trade
local skinCfgs: { [string]: { Name: string } } = Config.Cosmetics.PickaxeSkins :: any

local isTradeableItem: { [string]: boolean } = {}
for _, itemId in tradeCfg.TradeableItems do
	isTradeableItem[itemId] = true
end
local isResource: { [string]: boolean } = {}
for _, name in Config.Resources.Types do
	isResource[name] = true
end
local isGrade: { [string]: boolean } = {}
for _, name in Config.Grade.Names do
	isGrade[name] = true
end

local logAnomaly = AnomalyLog.new("Trade")

type Offer = Types.TradeOffer
type Line = Types.TradeLine

type Session = {
	id: string,
	a: Player,
	b: Player,
	offers: { [Player]: Offer },
	confirmed: { [Player]: boolean },
	version: number,
	lockedUntil: number, -- os.clock() when Confirm unlocks
	lockEndsAt: number, -- the same moment as workspace:GetServerTimeNow(), for the clients
	lastChange: number, -- os.clock()
	closed: boolean,
}

type Invite = { id: string, from: Player, to: Player }

-- inviter -> target -> os.clock() of the last decline / lapse (weak keys, so a
-- player who leaves is forgotten).
local lastRefused: { [Player]: { [Player]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function noteRefused(inviter: Player, target: Player)
	local perTarget = lastRefused[inviter]
	if not perTarget then
		perTarget = setmetatable({}, { __mode = "k" }) :: any
		lastRefused[inviter] = perTarget
	end
	perTarget[target] = os.clock()
end

local sessions: { [string]: Session } = {}
local sessionOf: { [Player]: Session } = {}
local inviteFrom: { [Player]: Invite } = {} -- one outgoing invite per player
local inviteTo: { [Player]: Invite } = {} -- one incoming invite per player

local TradeService = {}

-- ── Small helpers ────────────────────────────────────────────────────────

local function emptyOffer(): Offer
	return { Credits = 0, Lines = {} }
end

local function offerIsEmpty(offer: Offer): boolean
	return offer.Credits == 0 and #offer.Lines == 0
end

local function copyOffer(offer: Offer): Offer
	local lines: { Line } = {}
	for _, line in offer.Lines do
		table.insert(lines, { Kind = line.Kind, Id = line.Id, Grade = line.Grade, Amount = line.Amount })
	end
	return { Credits = offer.Credits, Lines = lines }
end

local function otherOf(session: Session, player: Player): Player
	return if session.a == player then session.b else session.a
end

local function positionOf(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return root.Position
end

-- Why this player can't be in a trade right now (nil = fine). Trading in the
-- middle of a raid or a Chase would let loot change hands outside the
-- raid's own rules (R1, R5).
local function blockedReason(player: Player): string?
	if not PlayerDataService.isLoaded(player) then
		return "Unavailable"
	end
	if not positionOf(player) then
		return "Dead"
	end
	if player:GetAttribute(Config.Gadgets.CarryingLootAttribute) == true or RaidService.isInRaid(player) then
		return "InRaid"
	end
	return nil
end

-- Units of a line's goods the player holds right now.
local function held(player: Player, line: Line): number
	if line.Kind == "Resource" then
		return VaultService.countUnits(player, line.Id, line.Grade or "")
	elseif line.Kind == "Item" then
		return InventoryService.count(player, line.Id)
	elseif line.Kind == "Skin" then
		return CosmeticService.count(player, line.Id)
	end
	return 0
end

-- Does the player still own everything in the offer? Two lines never name
-- the same pile (setOffer replaces), so a plain per-line check is exact.
local function canCover(player: Player, offer: Offer): boolean
	if offer.Credits > EconomyService.getCredits(player) then
		return false
	end
	for _, line in offer.Lines do
		if held(player, line) < line.Amount then
			return false
		end
	end
	return true
end

-- ── Below-market warning (06 § Trade Safety) ─────────────────────────────

-- Josh's call: the reference price is the NPC base price. Only resources and
-- Credits have one; anything else marks the side as "unpriced".
local function referenceValue(offer: Offer): (number, boolean)
	local value, unpriced = offer.Credits, false
	for _, line in offer.Lines do
		local price = if line.Kind == "Resource" then EconomyService.referencePrice(line.Id, line.Grade or "") else nil
		if price then
			value += price * line.Amount
		else
			unpriced = true
		end
	end
	return value, unpriced
end

-- True when you'd get far less than you give. A side that receives an
-- unpriced item never warns: we can't tell what it's worth.
local function belowMarket(gives: Offer, gets: Offer): boolean
	local giveValue = referenceValue(gives)
	local getValue, getUnpriced = referenceValue(gets)
	return giveValue > 0 and not getUnpriced and getValue < giveValue * tradeCfg.BelowMarketRatio
end

-- ── Talking to clients ───────────────────────────────────────────────────

local function viewFor(session: Session, player: Player): Types.TradeView
	local other = otherOf(session, player)
	return {
		Id = session.id,
		Version = session.version,
		YourName = player.Name,
		TheirName = other.Name,
		Yours = copyOffer(session.offers[player]),
		Theirs = copyOffer(session.offers[other]),
		YouConfirmed = session.confirmed[player] == true,
		TheyConfirmed = session.confirmed[other] == true,
		LockEndsAt = session.lockEndsAt,
		BelowMarket = belowMarket(session.offers[player], session.offers[other]),
	}
end

local function broadcast(session: Session)
	for _, player in { session.a, session.b } do
		if player.Parent then
			Remotes.getEvent("TradeState"):FireClient(player, viewFor(session, player))
		end
	end
end

-- Any change to either offer: new version, both Confirms cleared, lock restarts.
local function touch(session: Session)
	session.version += 1
	session.confirmed = {}
	session.lockedUntil = os.clock() + tradeCfg.ConfirmLockSeconds
	session.lockEndsAt = workspace:GetServerTimeNow() + tradeCfg.ConfirmLockSeconds
	session.lastChange = os.clock()
	broadcast(session)
end

-- Ends a window (or an invite) with a short message for the toast.
-- `received` (a finished trade only) is what THIS player got, so the "Trade
-- complete!" message can list it. Display only: the swap already happened.
local function tell(player: Player, text: string, received: Offer?)
	-- A stale invite message (declined, lapsed, cancelled) must not hide a
	-- window the player has open with someone else. close() clears sessionOf
	-- BEFORE telling, so real window closes still get through.
	if sessionOf[player] then
		return
	end
	if player.Parent then
		Remotes.getEvent("TradeState"):FireClient(player, nil, text, received)
	end
end

local function close(session: Session, text: string, received: { [Player]: Offer }?)
	if session.closed then
		return
	end
	session.closed = true
	sessions[session.id] = nil
	if sessionOf[session.a] == session then
		sessionOf[session.a] = nil
	end
	if sessionOf[session.b] == session then
		sessionOf[session.b] = nil
	end
	tell(session.a, text, if received then received[session.a] else nil)
	tell(session.b, text, if received then received[session.b] else nil)
end

-- ── The commit ───────────────────────────────────────────────────────────

type Step = { run: () -> boolean, undo: () -> () }

-- Steps that take an offer's goods out of `giver`.
local function debitSteps(giver: Player, offer: Offer, steps: { Step })
	local requests: { VaultService.UnitRequest } = {}
	for _, line in offer.Lines do
		if line.Kind == "Resource" then
			table.insert(requests, { Resource = line.Id, Grade = line.Grade :: string, Amount = line.Amount })
		end
	end
	if #requests > 0 then
		local receipt: VaultService.Receipt? = nil
		table.insert(steps, {
			run = function()
				receipt = VaultService.takeUnits(giver, requests)
				return receipt ~= nil
			end,
			undo = function()
				if receipt then
					VaultService.restoreUnits(giver, receipt)
				end
			end,
		})
	end
	for _, line in offer.Lines do
		if line.Kind == "Item" then
			table.insert(steps, {
				run = function()
					return InventoryService.consume(giver, line.Id, line.Amount)
				end,
				undo = function()
					InventoryService.add(giver, line.Id, line.Amount)
				end,
			})
		elseif line.Kind == "Skin" then
			table.insert(steps, {
				run = function()
					return CosmeticService.takeSkin(giver, line.Id, line.Amount)
				end,
				undo = function()
					CosmeticService.grantSkin(giver, line.Id, line.Amount)
				end,
			})
		end
	end
	if offer.Credits > 0 then
		table.insert(steps, {
			run = function()
				return EconomyService.spend(giver, offer.Credits)
			end,
			undo = function()
				EconomyService.add(giver, offer.Credits)
			end,
		})
	end
end

-- Steps that hand an offer's goods to `receiver` (resources land in Exposed,
-- with the usual auto-bank for Prismatic / Vaultborn).
local function creditSteps(receiver: Player, offer: Offer, steps: { Step })
	for _, line in offer.Lines do
		if line.Kind == "Resource" then
			table.insert(steps, {
				run = function()
					return VaultService.deposit(receiver, line.Id, line.Grade :: string, line.Amount)
				end,
				undo = function()
					VaultService.takeUnits(receiver, { { Resource = line.Id, Grade = line.Grade :: string, Amount = line.Amount } })
				end,
			})
		elseif line.Kind == "Item" then
			table.insert(steps, {
				run = function()
					return InventoryService.add(receiver, line.Id, line.Amount)
				end,
				undo = function()
					InventoryService.consume(receiver, line.Id, line.Amount)
				end,
			})
		elseif line.Kind == "Skin" then
			table.insert(steps, {
				run = function()
					return CosmeticService.grantSkin(receiver, line.Id, line.Amount)
				end,
				undo = function()
					CosmeticService.takeSkin(receiver, line.Id, line.Amount)
				end,
			})
		end
	end
	if offer.Credits > 0 then
		table.insert(steps, {
			run = function()
				return EconomyService.add(receiver, offer.Credits)
			end,
			undo = function()
				EconomyService.spend(receiver, offer.Credits)
			end,
		})
	end
end

-- Newest first, capped. Returns how many trades the player already made on
-- this UTC day (before this one) for the Trader XP limit.
local function writeHistory(player: Player, record: Types.TradeRecord): number
	local madeToday = 0
	local dayStart = (Clock.now() // Config.NpcSelling.DaySeconds) * Config.NpcSelling.DaySeconds
	local ok = PlayerDataService.update(player, "TradeHistory", OWNER, function(history: { Types.TradeRecord })
		for _, entry in history do
			-- Only two-way trades count toward the daily Trader XP limit, so a
			-- run of one-sided gifts can't use it up.
			if entry.At >= dayStart and not offerIsEmpty(entry.Gave) and not offerIsEmpty(entry.Got) then
				madeToday += 1
			end
		end
		table.insert(history, 1, record)
		while #history > tradeCfg.HistoryMax do
			table.remove(history)
		end
		return history
	end)
	if not ok then
		warn(`[Trade] couldn't write {player.Name}'s trade history for {record.Id}`)
	end
	return madeToday
end

local function commit(session: Session)
	local a, b = session.a, session.b
	local offerA, offerB = session.offers[a], session.offers[b]

	-- Nothing below yields until the swap is finished or undone.
	if not a.Parent or not b.Parent or blockedReason(a) or blockedReason(b) then
		close(session, "Trade cancelled: someone can't trade right now")
		return
	end
	if not canCover(a, offerA) or not canCover(b, offerB) then
		close(session, "Trade cancelled: something you offered is no longer available")
		return
	end

	local steps: { Step } = {}
	debitSteps(a, offerA, steps)
	debitSteps(b, offerB, steps)
	creditSteps(b, offerA, steps)
	creditSteps(a, offerB, steps)

	local finished = 0
	local failed = false
	for _, step in steps do
		local ok, result = pcall(step.run)
		if not ok or result ~= true then
			failed = true
			if not ok then
				warn(`[Trade] {session.id}: step threw: {result}`)
			end
			break
		end
		finished += 1
	end
	if failed then
		for index = finished, 1, -1 do
			local undo = steps[index].undo
			local ok, problem = pcall(function(): any
				undo()
				return nil
			end)
			if not ok then
				warn(`[Trade] {session.id}: UNDO of step {index} threw: {problem}`)
			end
		end
		warn(`[Trade] {session.id} between {a.Name} and {b.Name} failed at step {finished + 1}/{#steps}; undone`)
		close(session, "Trade failed: nothing changed")
		return
	end

	-- Done. History for both (same id), Trader XP, then both saves back to back.
	local now = Clock.now()
	local recordA: Types.TradeRecord = { Id = session.id, At = now, WithName = b.Name, WithUserId = tostring(b.UserId), Gave = copyOffer(offerA), Got = copyOffer(offerB) }
	local recordB: Types.TradeRecord = { Id = session.id, At = now, WithName = a.Name, WithUserId = tostring(a.UserId), Gave = copyOffer(offerB), Got = copyOffer(offerA) }
	local madeA = writeHistory(a, recordA)
	local madeB = writeHistory(b, recordB)
	if not offerIsEmpty(offerA) and not offerIsEmpty(offerB) then
		-- 03 § Reputation tracks: only real two-way trades, first N per day.
		if madeA < tradeCfg.XPTradesPerDay then
			ReputationService.grant(a, "Trader", tradeCfg.XPPerTrade, "trade")
		end
		if madeB < tradeCfg.XPTradesPerDay then
			ReputationService.grant(b, "Trader", tradeCfg.XPPerTrade, "trade")
		end
	end
	PlayerDataService.saveNow(a)
	PlayerDataService.saveNow(b)
	print(`[Trade] {session.id}: {a.Name} <-> {b.Name} complete ({#offerA.Lines} lines + {offerA.Credits} Credits for {#offerB.Lines} lines + {offerB.Credits} Credits)`)
	close(session, "Trade complete!", { [a] = copyOffer(offerB), [b] = copyOffer(offerA) })
end

-- ── Intents ──────────────────────────────────────────────────────────────

local allowRequest = RateLimiter.new("Trade", tradeCfg.RequestCooldownSeconds)
local allowInvite = RateLimiter.new("TradeInvite", tradeCfg.InviteCooldownSeconds)
local allowNearby = RateLimiter.new("GetNearbyTraders", tradeCfg.NearbyCooldownSeconds)

local function clearInvite(invite: Invite)
	if inviteFrom[invite.from] == invite then
		inviteFrom[invite.from] = nil
	end
	if inviteTo[invite.to] == invite then
		inviteTo[invite.to] = nil
	end
end

local function openSession(a: Player, b: Player)
	-- Drop every other pending invite either player has, so a stale invite can
	-- never lapse or be answered while they are in this window.
	for _, p in { a, b } do
		local outgoing = inviteFrom[p]
		if outgoing then
			clearInvite(outgoing)
		end
		local incoming = inviteTo[p]
		if incoming then
			clearInvite(incoming)
		end
	end
	local session: Session = {
		id = HttpService:GenerateGUID(false),
		a = a,
		b = b,
		offers = { [a] = emptyOffer(), [b] = emptyOffer() },
		confirmed = {},
		version = 0,
		lockedUntil = 0,
		lockEndsAt = 0,
		lastChange = os.clock(),
		closed = false,
	}
	sessions[session.id] = session
	sessionOf[a] = session
	sessionOf[b] = session
	touch(session)
end

-- Can this player start or accept a trade at all (Level gate, not busy)?
local function tradeBlock(player: Player): string?
	if not ReputationService.isTradeUnlocked(player) then
		return "Locked"
	end
	if sessionOf[player] then
		return "Busy"
	end
	return blockedReason(player)
end

local function invite(player: Player, targetArg: unknown): (boolean, string?)
	if not allowInvite(player) then
		return false, "Busy"
	end
	if typeof(targetArg) ~= "number" then
		logAnomaly(player, "sent a bad trade invite")
		return false, "Invalid"
	end
	local target = Players:GetPlayerByUserId(targetArg :: number)
	if not target or target == player then
		return false, "NotFound"
	end
	local mine = tradeBlock(player)
	if mine then
		return false, mine
	end
	local theirs = tradeBlock(target)
	if theirs == "Locked" then
		return false, "TargetLocked"
	elseif theirs then
		return false, "TargetBusy"
	end
	if inviteTo[target] then
		return false, "TargetBusy"
	end
	local refused = lastRefused[player] and lastRefused[player][target]
	if refused and os.clock() - refused < tradeCfg.ReinviteCooldownSeconds then
		return false, "Cooldown"
	end
	local myPosition, theirPosition = positionOf(player), positionOf(target)
	if not myPosition or not theirPosition or (myPosition - theirPosition).Magnitude > tradeCfg.InviteRangeStuds then
		return false, "TooFar"
	end

	-- A new invite replaces your own earlier one.
	local previous = inviteFrom[player]
	if previous then
		clearInvite(previous)
	end
	local pending: Invite = { id = HttpService:GenerateGUID(false), from = player, to = target }
	inviteFrom[player] = pending
	inviteTo[target] = pending
	Remotes.getEvent("TradeInviteOffer"):FireClient(target, pending.id, player.Name, tradeCfg.InviteSeconds)
	task.delay(tradeCfg.InviteSeconds, function()
		if inviteTo[target] == pending then
			clearInvite(pending)
			noteRefused(player, target)
			tell(player, `{target.Name} didn't answer your trade invite`)
		end
	end)
	return true, nil
end

local function respond(player: Player, inviteIdArg: unknown, acceptArg: unknown): (boolean, string?)
	if not allowRequest(player) then
		return false, "Busy"
	end
	if typeof(inviteIdArg) ~= "string" or typeof(acceptArg) ~= "boolean" then
		logAnomaly(player, "sent a bad trade response")
		return false, "Invalid"
	end
	local pending = inviteTo[player]
	if not pending or pending.id ~= inviteIdArg then
		return false, "Expired"
	end
	clearInvite(pending)
	local from = pending.from
	if acceptArg == false then
		noteRefused(from, player)
		tell(from, `{player.Name} declined the trade`)
		return true, nil
	end
	-- Everything is checked again now: a lot can change in 20 seconds.
	if not from.Parent or tradeBlock(from) or tradeBlock(player) then
		tell(player, "Trade cancelled: someone can't trade right now")
		tell(from, "Trade cancelled: someone can't trade right now")
		return false, "Cancelled" -- the client must not replace the message above with "Too fast"
	end
	local myPosition, theirPosition = positionOf(player), positionOf(from)
	if not myPosition or not theirPosition or (myPosition - theirPosition).Magnitude > tradeCfg.InviteRangeStuds then
		tell(player, "Trade cancelled: you're too far apart")
		tell(from, "Trade cancelled: you're too far apart")
		return false, "TooFar"
	end
	openSession(from, player)
	return true, nil
end

-- The session a remote call belongs to, if it's still open.
local function openSessionOf(player: Player): Session?
	local session = sessionOf[player]
	if session and not session.closed then
		return session
	end
	return nil
end

-- Sets one line (or removes it with amount 0). Changing anything restarts the
-- lock and clears both Confirms.
local function setOffer(player: Player, kindArg: unknown, idArg: unknown, gradeArg: unknown, amountArg: unknown): (boolean, string?)
	if not allowRequest(player) then
		return false, "Busy"
	end
	local session = openSessionOf(player)
	if not session then
		return false, "NoTrade"
	end
	if typeof(kindArg) ~= "string" or typeof(idArg) ~= "string" or typeof(amountArg) ~= "number" or (gradeArg ~= nil and typeof(gradeArg) ~= "string") then
		logAnomaly(player, "sent a bad trade offer")
		return false, "Invalid"
	end
	local kind, id, amount = kindArg :: string, idArg :: string, amountArg :: number
	local grade: string? = if typeof(gradeArg) == "string" and gradeArg ~= "" then gradeArg :: string else nil
	if amount ~= amount or amount < 0 or amount ~= math.floor(amount) or amount > tradeCfg.MaxUnitsPerLine then
		logAnomaly(player, "sent an impossible trade amount")
		return false, "Invalid"
	end

	local valid = false
	if kind == "Resource" then
		valid = isResource[id] == true and grade ~= nil and isGrade[grade] == true
	elseif kind == "Item" then
		valid = isTradeableItem[id] == true and grade == nil
	elseif kind == "Skin" then
		valid = skinCfgs[id] ~= nil and grade == nil
	end
	if not valid then
		logAnomaly(player, "offered something that can't be traded", `{kind} {id}`)
		return false, "NotTradeable"
	end

	local line: Line = { Kind = kind, Id = id, Grade = grade, Amount = amount }
	if amount > 0 and held(player, line) < amount then
		return false, "NotEnough"
	end

	local offer = session.offers[player]
	local index: number? = nil
	for i, existing in offer.Lines do
		if existing.Kind == kind and existing.Id == id and existing.Grade == grade then
			index = i
			break
		end
	end
	if amount == 0 then
		if index then
			table.remove(offer.Lines, index)
			touch(session)
		end
		return true, nil
	end
	if index then
		if offer.Lines[index].Amount == amount then
			return true, nil -- no change: don't restart the lock
		end
		offer.Lines[index].Amount = amount
	else
		if #offer.Lines >= tradeCfg.MaxOfferLines then
			return false, "TooMany"
		end
		table.insert(offer.Lines, line)
	end
	touch(session)
	return true, nil
end

local function setCredits(player: Player, amountArg: unknown): (boolean, string?)
	if not allowRequest(player) then
		return false, "Busy"
	end
	local session = openSessionOf(player)
	if not session then
		return false, "NoTrade"
	end
	if typeof(amountArg) ~= "number" then
		logAnomaly(player, "sent a bad Credits amount")
		return false, "Invalid"
	end
	local amount = amountArg :: number
	if amount ~= amount or amount < 0 or amount ~= math.floor(amount) or amount > tradeCfg.MaxCreditsPerOffer then
		logAnomaly(player, "sent an impossible Credits amount")
		return false, "Invalid"
	end
	if amount > EconomyService.getCredits(player) then
		return false, "NotEnough"
	end
	local offer = session.offers[player]
	if offer.Credits ~= amount then
		offer.Credits = amount
		touch(session)
	end
	return true, nil
end

local function confirm(player: Player, versionArg: unknown): (boolean, string?)
	if not allowRequest(player) then
		return false, "Busy"
	end
	local session = openSessionOf(player)
	if not session then
		return false, "NoTrade"
	end
	if typeof(versionArg) ~= "number" then
		logAnomaly(player, "sent a bad Confirm")
		return false, "Invalid"
	end
	if versionArg ~= session.version then
		return false, "Changed" -- the offers moved since the client looked
	end
	if os.clock() < session.lockedUntil then
		return false, "WaitLock" -- the 5-second lock (06 § Trade Safety)
	end
	if offerIsEmpty(session.offers[session.a]) and offerIsEmpty(session.offers[session.b]) then
		return false, "Empty"
	end
	session.confirmed[player] = true
	if session.confirmed[session.a] and session.confirmed[session.b] then
		commit(session)
	else
		broadcast(session)
	end
	return true, nil
end

local function cancel(player: Player): (boolean, string?)
	if not allowRequest(player) then
		return false, "Busy"
	end
	local session = openSessionOf(player)
	if session then
		close(session, `{player.Name} cancelled the trade`)
		return true, nil
	end
	local pending = inviteFrom[player]
	if pending then
		clearInvite(pending)
		tell(pending.to, `{player.Name} cancelled the trade invite`)
	end
	return true, nil
end

local function nearbyTraders(player: Player): { { UserId: number, Name: string } }
	local list: { { UserId: number, Name: string } } = {}
	local myPosition = positionOf(player)
	if not myPosition or tradeBlock(player) then
		return list
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and not tradeBlock(other) then
			local position = positionOf(other)
			if position and (position - myPosition).Magnitude <= tradeCfg.InviteRangeStuds then
				table.insert(list, { UserId = other.UserId, Name = other.Name })
			end
		end
	end
	return list
end

-- ── Watching open windows ────────────────────────────────────────────────

local function checkSessions()
	for _, session in sessions do
		if session.closed then
			continue
		end
		local a, b = session.a, session.b
		local pa, pb = positionOf(a), positionOf(b)
		if not a.Parent or not b.Parent then
			close(session, "Trade cancelled: someone left")
		elseif not pa or not pb then
			close(session, "Trade cancelled: someone died")
		elseif (pa - pb).Magnitude > tradeCfg.WindowRangeStuds then
			close(session, "Trade cancelled: you drifted too far apart")
		elseif blockedReason(a) or blockedReason(b) then
			close(session, "Trade cancelled: someone is in a raid")
		elseif os.clock() - session.lastChange > tradeCfg.IdleSeconds then
			close(session, "Trade timed out")
		end
	end
end

local function onPlayerRemoving(player: Player)
	local session = sessionOf[player]
	if session then
		close(session, `Trade cancelled: {player.Name} left`)
	end
	sessionOf[player] = nil
	local outgoing = inviteFrom[player]
	if outgoing then
		clearInvite(outgoing)
	end
	local incoming = inviteTo[player]
	if incoming then
		clearInvite(incoming)
	end
end

function TradeService.start()
	-- A tradeable id nobody can hold would just be a dead line in the Bag.
	local known: { [string]: boolean } = {}
	for _, itemId in Config.Inventory.ItemOrder do
		known[itemId] = true
	end
	for _, itemId in tradeCfg.TradeableItems do
		assert(known[itemId], `Config.Trade.TradeableItems lists "{itemId}", which isn't in Config.Inventory.ItemOrder`)
	end

	PlayerDataService.Loaded:Connect(function(player: Player)
		if tradeCfg.Ui.ShowBeforeFtue then
			player:SetAttribute(tradeCfg.Ui.VisibleAttribute, true)
		end
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	local remote = Remotes.getFunction
	remote("TradeInvite").OnServerInvoke = invite
	remote("TradeRespond").OnServerInvoke = respond
	remote("TradeSetOffer").OnServerInvoke = setOffer
	remote("TradeSetCredits").OnServerInvoke = setCredits
	remote("TradeConfirm").OnServerInvoke = confirm
	remote("TradeCancel").OnServerInvoke = cancel
	remote("GetNearbyTraders").OnServerInvoke = function(player: Player)
		if not allowNearby(player) then
			return {}
		end
		return nearbyTraders(player)
	end
	local allowHistory = RateLimiter.new("GetTradeHistory", tradeCfg.HistoryCooldownSeconds)
	remote("GetTradeHistory").OnServerInvoke = function(player: Player)
		if not allowHistory(player) then
			return {}
		end
		return PlayerDataService.get(player, "TradeHistory") or {}
	end

	task.spawn(function()
		while true do
			task.wait(tradeCfg.CheckSeconds)
			checkSessions()
		end
	end)
end

return TradeService
