--!strict
-- EconomyService: Credits and the NPC buyer. The only service that writes the
-- Credits and NpcSales sections (Config.Data.SectionOwners).
--
-- Docs: 06-economy.md § Currencies (Credits), § Two tiers of selling,
-- § NPC price decay (D94); 02-core-loop.md § Slice layout (the buyer stands
-- in the south plaza); 06 § No indirect Credits -> Scrap route (D69): selling
-- never yields Scrap.
--
-- * The NPC is always available (no Level gate): zero friction from minute one.
-- * Josh's calls (step 9): it buys from Exposed first, then Banked, in the
--   Grade the player picks; the daily decay counts units per RESOURCE and
--   resets at the UTC day boundary. The counters are saved in the profile,
--   so leaving and rejoining can't reset a price (D94: the flat price was
--   an unlimited faucet).
-- * The client only asks "sell this many of this resource + Grade". The
--   server checks distance, the amount held and the price (R5).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NodeMath = require(ReplicatedStorage.Shared.NodeMath)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)
local ServerConfig = require(ServerScriptService.ServerConfig)
local Clock = require(ServerScriptService.Util.Clock)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local AnomalyLog = require(ServerScriptService.Util.AnomalyLog)
local PlayerDataService = require(script.Parent.PlayerDataService)
local VaultService = require(script.Parent.VaultService)
local ReputationService = require(script.Parent.ReputationService)

local OWNER = "EconomyService"
local cfg = Config.NpcSelling
local basePrice: { [string]: number } = cfg.BasePrice :: any

-- Grade -> sell multiplier (server-only; ServerConfig.Grade).
local gradeMultiplier: { [string]: number } = {}
for _, entry in ServerConfig.Grade do
	gradeMultiplier[entry.Name] = entry.Multiplier
end

local logAnomaly = AnomalyLog.new("Economy")

type Sales = { Day: number, Units: { [string]: number } }

local EconomyService = {}

-- ── Credits ──────────────────────────────────────────────────────────────

local function sendCredits(player: Player)
	local credits = PlayerDataService.get(player, "Credits")
	if credits then
		Remotes.getEvent("CreditsChanged"):FireClient(player, credits)
	end
end

function EconomyService.getCredits(player: Player): number
	return PlayerDataService.get(player, "Credits") or 0
end

-- Adds Credits (server code only, amounts the server decided: R5).
function EconomyService.add(player: Player, amount: number): boolean
	assert(amount > 0 and amount == math.floor(amount), `EconomyService.add: bad amount {amount}`)
	local ok = PlayerDataService.update(player, "Credits", OWNER, function(credits: number)
		return credits + amount
	end)
	if ok then
		sendCredits(player)
	end
	return ok
end

-- Takes Credits if the player has them. All or nothing.
function EconomyService.spend(player: Player, amount: number): boolean
	assert(amount > 0 and amount == math.floor(amount), `EconomyService.spend: bad amount {amount}`)
	local paid = false
	local ok = PlayerDataService.update(player, "Credits", OWNER, function(credits: number)
		if credits >= amount then
			paid = true
			return credits - amount
		end
		return credits
	end)
	if ok and paid then
		sendCredits(player)
		return true
	end
	return false
end

-- ── Prices ───────────────────────────────────────────────────────────────

-- Full price (undecayed) of one unit: base price x Grade multiplier. The
-- direct trade window's below-market warning uses this as its reference
-- (Josh's call, step 9). Nil for something the NPC doesn't price.
function EconomyService.referencePrice(resource: string, grade: string): number?
	local base, multiplier = basePrice[resource], gradeMultiplier[grade]
	if not base or not multiplier then
		return nil
	end
	return base * multiplier
end

local function today(): number
	return Clock.now() // cfg.DaySeconds
end

-- The player's sales for today (a fresh count once the UTC day has changed).
local function salesToday(player: Player): Sales?
	local sales: Sales? = PlayerDataService.get(player, "NpcSales")
	if not sales then
		return nil
	end
	if sales.Day ~= today() then
		return { Day = today(), Units = {} }
	end
	return sales
end

-- D94: each unit sold today multiplies the price by DecayPerUnit, down to a floor.
local function priceFactor(unitsAlreadySold: number): number
	return math.max(cfg.PriceFloor, cfg.DecayPerUnit ^ unitsAlreadySold)
end

-- Credits for selling `count` units of one Grade after `alreadySold` units of
-- that resource went today. Rounded DOWN, so splitting a sale into several
-- small ones can never pay more than selling it together (floor(a) + floor(b)
-- <= floor(a + b)); step 9 review: rounding to nearest let "Sell 1" beat the
-- price floor.
local function payout(resource: string, grade: string, alreadySold: number, count: number): number
	local full = basePrice[resource] * gradeMultiplier[grade]
	local total = 0
	for i = 0, count - 1 do
		total += full * priceFactor(alreadySold + i)
	end
	return math.floor(total)
end

function EconomyService.getQuote(player: Player): Types.SellQuote?
	local sales = salesToday(player)
	local resources: Types.ResourceSnapshot? = PlayerDataService.get(player, "Resources")
	if not sales or not resources then
		return nil
	end
	local quote: Types.SellQuote = { Resources = {} }
	for _, resource in Config.Resources.Types do
		local factor = priceFactor(sales.Units[resource] or 0)
		local grades: { [string]: { Have: number, Price: number } } = {}
		for _, grade in Config.Grade.Names do
			local have = (resources.Exposed[resource][grade] or 0) + (resources.Banked[resource][grade] or 0)
			grades[grade] = { Have = have, Price = math.floor(basePrice[resource] * gradeMultiplier[grade] * factor * 100 + 0.5) / 100 }
		end
		quote.Resources[resource] = { Percent = math.floor(factor * 100 + 0.5), Grades = grades }
	end
	return quote
end

-- ── The buyer ────────────────────────────────────────────────────────────

local function nearestBuyerDistance(point: Vector3): number
	local best = math.huge
	for _, model in CollectionService:GetTagged(cfg.BuyerTag) do
		local hitbox = model:FindFirstChild("Hitbox")
		if hitbox and hitbox:IsA("BasePart") and hitbox:IsDescendantOf(workspace) then
			best = math.min(best, NodeMath.distanceToHitbox(hitbox, point))
		end
	end
	return best
end

-- Where the player stands, or nil if they're dead / have no character.
local function livePosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return root.Position
end

local function atBuyer(player: Player): boolean
	local position = livePosition(player)
	return position ~= nil and nearestBuyerDistance(position) <= cfg.SellRangeStuds
end

local function sell(player: Player, resourceArg: unknown, gradeArg: unknown, countArg: unknown): (boolean, string?, number?, Types.SellQuote?)
	if typeof(resourceArg) ~= "string" or typeof(gradeArg) ~= "string" or typeof(countArg) ~= "number" then
		logAnomaly(player, "sent bad Sell arguments")
		return false, "Invalid"
	end
	local resource, grade, requested = resourceArg :: string, gradeArg :: string, countArg :: number
	-- NaN / infinity / fractions / non-positive: never a fair client.
	if requested ~= requested or requested < 1 or requested == math.huge or not basePrice[resource] or not gradeMultiplier[grade] then
		logAnomaly(player, "sent an impossible Sell request")
		return false, "Invalid"
	end
	if not atBuyer(player) then
		logAnomaly(player, "sold from too far away")
		return false, "TooFar"
	end
	local sales = salesToday(player)
	if not sales then
		return false, "Failed"
	end

	local have = VaultService.countUnits(player, resource, grade)
	local count = math.min(math.floor(requested), have, cfg.MaxUnitsPerSale)
	if count < 1 then
		return false, "NothingToSell"
	end
	local alreadySold = sales.Units[resource] or 0
	local earned = payout(resource, grade, alreadySold, count)
	if earned < 1 then
		return false, "TooCheap" -- the price has decayed to nothing for this many units
	end

	-- Nothing below yields, so the sale is all-or-nothing: units out, counter
	-- up, Credits in; if a step fails the earlier ones are put back.
	local receipt = VaultService.takeUnits(player, { { Resource = resource, Grade = grade, Amount = count } })
	if not receipt then
		return false, "Failed"
	end
	local counted = PlayerDataService.update(player, "NpcSales", OWNER, function(current: Sales)
		if current.Day ~= today() then
			current = { Day = today(), Units = {} }
		end
		current.Units[resource] = (current.Units[resource] or 0) + count
		return current
	end)
	if not counted then
		VaultService.restoreUnits(player, receipt)
		return false, "Failed"
	end
	if not EconomyService.add(player, earned) then
		PlayerDataService.update(player, "NpcSales", OWNER, function(current: Sales)
			current.Units[resource] = math.max(0, (current.Units[resource] or 0) - count)
			return current
		end)
		VaultService.restoreUnits(player, receipt)
		return false, "Failed"
	end

	print(`[Economy] {player.Name} sold {count} {grade} {resource} for {earned} Credits ({alreadySold} {resource} sold today before this)`)
	-- 03 § Reputation tracks: Trader XP scales with Credits earned, so the
	-- daily decay also throttles it.
	local xp = math.floor(earned * Config.Progression.XP.TraderPerTenCredits / 10)
	if xp > 0 then
		ReputationService.grant(player, "Trader", xp, "NPC sale")
	end
	return true, nil, earned, EconomyService.getQuote(player)
end

local function setUpBuyer(instance: Instance)
	if not instance:IsA("Model") or not instance:IsDescendantOf(workspace) then
		return
	end
	local hitbox = instance:FindFirstChild("Hitbox")
	if not hitbox or not hitbox:IsA("BasePart") then
		warn(`[Economy] {instance:GetFullName()} is tagged {cfg.BuyerTag} but has no Hitbox part`)
		return
	end
	if hitbox:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = cfg.PromptText
	prompt.ObjectText = "Buyer"
	prompt.HoldDuration = cfg.PromptHoldSeconds
	prompt.MaxActivationDistance = cfg.SellRangeStuds
	prompt.Parent = hitbox
	prompt.Triggered:Connect(function(player: Player)
		-- The prompt measures to the Hitbox centre and atBuyer to its surface,
		-- so a fair press always passes.
		if atBuyer(player) then
			Remotes.getEvent("OpenNpcShop"):FireClient(player)
		end
	end)
end

-- A resource or Grade missing from the price tables could never be sold
-- (or would error mid-sale), so check them once at start-up.
local function selfTest()
	for _, resource in Config.Resources.Types do
		assert(basePrice[resource], `Config.NpcSelling.BasePrice is missing "{resource}"`)
	end
	for _, grade in Config.Grade.Names do
		assert(gradeMultiplier[grade], `ServerConfig.Grade has no multiplier for "{grade}"`)
	end
	assert(cfg.DecayPerUnit > 0 and cfg.DecayPerUnit < 1, "Config.NpcSelling.DecayPerUnit must be between 0 and 1")
	assert(cfg.PriceFloor > 0 and cfg.PriceFloor <= 1, "Config.NpcSelling.PriceFloor must be in (0, 1]")
end

function EconomyService.start()
	selfTest()
	PlayerDataService.Loaded:Connect(sendCredits)

	for _, model in CollectionService:GetTagged(cfg.BuyerTag) do
		setUpBuyer(model)
	end
	CollectionService:GetInstanceAddedSignal(cfg.BuyerTag):Connect(setUpBuyer)

	local allowQuote = RateLimiter.new("GetSellQuote", cfg.QuoteCooldownSeconds)
	Remotes.getFunction("GetSellQuote").OnServerInvoke = function(player: Player): Types.SellQuote?
		if not allowQuote(player) or not atBuyer(player) then
			return nil
		end
		return EconomyService.getQuote(player)
	end

	local allowSell = RateLimiter.new("SellUnits", cfg.SellCooldownSeconds)
	Remotes.getFunction("SellUnits").OnServerInvoke = function(player: Player, resource: unknown, grade: unknown, count: unknown): (boolean, string?, number?, Types.SellQuote?)
		if not allowSell(player) then
			return false, "Busy"
		end
		return sell(player, resource, grade, count)
	end
end

return EconomyService
