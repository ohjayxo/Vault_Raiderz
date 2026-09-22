--!strict
-- VaultService: Banked vs Exposed. The only service that writes the
-- Resources and Scrap sections (Config.Data.SectionOwners; CLAUDE.md "only a
-- system's own service mutates its data").
--
-- Docs: 02-core-loop.md § Bank vs Exposed (incl. § Special cases),
-- § Buildable elements (Vault Core); 05-items.md § Auto-bank protection.
--
-- * Everything mined lands in Exposed (stealable). The player banks it by
--   using a Vault Core; it moves in best-first until capacity is full, and
--   the rest stays Exposed (Josh's calls, step 3).
-- * Prismatic and Vaultborn skip the walk: they go straight into the bank
--   on pickup if there's room (§ Special cases).
-- * Capacity = total units of all resources, set by Base.VaultTier. Research
--   Scrap has its own, smaller cap (~20% [PH], Q38) and is banked the same way.
-- * Capacity only ever gates what goes IN. If it were ever lower than what's
--   already banked, nothing is pushed back out to Exposed (R2).
-- * Vault tier belongs to PlotService (step 4). This service only reads it.
-- * Paying for things (spend) takes Exposed before Banked, lowest Grade first.
-- * The Banked/Exposed meter is hidden until the FTUE reveals it (R4,
--   02 § FTUE spec). setMeterVisible is the switch.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NodeMath = require(ReplicatedStorage.Shared.NodeMath)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local AnomalyLog = require(ServerScriptService.Util.AnomalyLog)
local PlayerDataService = require(script.Parent.PlayerDataService)

local OWNER = "VaultService"
local bankCfg = Config.Bank

local isResource: { [string]: boolean } = {}
for _, name in Config.Resources.Types do
	isResource[name] = true
end
local isGrade: { [string]: boolean } = {}
for _, name in Config.Grade.Names do
	isGrade[name] = true
end
local isAutoBank: { [string]: boolean } = {}
for _, name in bankCfg.AutoBankGrades do
	isAutoBank[name] = true
end

local logAnomaly = AnomalyLog.new("Vault")

local VaultService = {}

-- ── Capacity ─────────────────────────────────────────────────────────────

local function capacityForTier(tier: number): number
	if tier < 1 then
		return 0 -- no Vault Core yet
	end
	local caps = bankCfg.CapacityByTier
	return caps[math.min(tier, #caps)]
end

local function scrapCapacityFor(capacity: number): number
	return math.floor(capacity * bankCfg.ScrapCapFraction)
end

local function vaultTier(player: Player): number?
	local base = PlayerDataService.get(player, "Base")
	return if base then base.VaultTier else nil
end

local function totalUnits(store: Types.ResourceStore): number
	local total = 0
	for _, grades in store do
		for _, count in grades do
			total += count
		end
	end
	return total
end

-- ── State for the owner's meter ──────────────────────────────────────────

-- The player's own vault, or nil if their profile isn't loaded.
function VaultService.getState(player: Player): Types.VaultState?
	local resources: Types.ResourceSnapshot? = PlayerDataService.get(player, "Resources")
	local scrap = PlayerDataService.get(player, "Scrap")
	local tier = vaultTier(player)
	if not resources or not scrap or not tier then
		return nil
	end
	local capacity = capacityForTier(tier)
	return {
		Banked = resources.Banked,
		Exposed = resources.Exposed,
		Capacity = capacity,
		ScrapBanked = scrap.Banked,
		ScrapExposed = scrap.Exposed,
		ScrapCapacity = scrapCapacityFor(capacity),
	}
end

-- Sends the player their vault state. Call after anything that changes it,
-- including a vault tier change (PlotService).
function VaultService.refresh(player: Player)
	local state = VaultService.getState(player)
	if state then
		Remotes.getEvent("VaultChanged"):FireClient(player, state)
	end
end

-- ── Writes (server code only, with values the server decided: R5) ────────

-- Adds `amount` units of `resource` at `grade` for this player. Prismatic /
-- Vaultborn go into the bank as far as room allows; everything else, and
-- whatever didn't fit, goes to Exposed. Returns true if it was saved.
function VaultService.deposit(player: Player, resource: string, grade: string, amount: number): boolean
	-- Bad arguments here are a server bug, never player input: fail loudly.
	assert(isResource[resource], `VaultService.deposit: unknown resource "{resource}"`)
	assert(isGrade[grade], `VaultService.deposit: unknown grade "{grade}"`)
	assert(amount > 0 and amount == math.floor(amount), `VaultService.deposit: bad amount {amount}`)

	local tier = vaultTier(player)
	if not tier then
		return false
	end
	local capacity = capacityForTier(tier)

	local banked = 0
	local ok = PlayerDataService.update(player, "Resources", OWNER, function(resources: Types.ResourceSnapshot)
		if isAutoBank[grade] then
			local room = math.max(0, capacity - totalUnits(resources.Banked))
			banked = math.min(amount, room)
		end
		local bankedGrades, exposedGrades = resources.Banked[resource], resources.Exposed[resource]
		bankedGrades[grade] = (bankedGrades[grade] or 0) + banked
		exposedGrades[grade] = (exposedGrades[grade] or 0) + amount - banked
		return resources
	end)
	if ok then
		if isAutoBank[grade] then
			print(`[Vault] {player.Name}: {grade} {resource} x{amount} auto-banked {banked}, exposed {amount - banked}`)
		end
		VaultService.refresh(player)
	end
	return ok
end

-- Adds Research Scrap to Exposed (Scav drops etc., step 6+). Scrap never
-- auto-banks; the player banks it at the Vault Core like everything else.
function VaultService.depositScrap(player: Player, amount: number): boolean
	assert(amount > 0 and amount == math.floor(amount), `VaultService.depositScrap: bad amount {amount}`)
	local ok = PlayerDataService.update(player, "Scrap", OWNER, function(scrap)
		scrap.Exposed += amount
		return scrap
	end)
	if ok then
		VaultService.refresh(player)
	end
	return ok
end

local function checkAmounts(amounts: { [string]: number }, caller: string)
	for resource, amount in amounts do
		assert(isResource[resource], `VaultService.{caller}: unknown resource "{resource}"`)
		assert(amount >= 0 and amount == math.floor(amount), `VaultService.{caller}: bad amount {amount}`)
	end
end

-- Takes a price (resource -> units) from Exposed before Banked, lowest
-- Grade first (Config.Bank.SpendOrderGrades; Josh's call, step 4). All or
-- nothing: returns false and takes nothing if the player can't afford it.
function VaultService.spend(player: Player, cost: { [string]: number }): boolean
	checkAmounts(cost, "spend")
	local affordable = false
	local ok = PlayerDataService.update(player, "Resources", OWNER, function(resources: Types.ResourceSnapshot)
		for resource, amount in cost do
			local have = 0
			for _, count in resources.Exposed[resource] do
				have += count
			end
			for _, count in resources.Banked[resource] do
				have += count
			end
			if have < amount then
				return resources -- unchanged
			end
		end
		for resource, amount in cost do
			local left = amount
			for _, store in { resources.Exposed[resource], resources.Banked[resource] } do
				for _, grade in bankCfg.SpendOrderGrades do
					local take = math.min(store[grade] or 0, left)
					store[grade] = (store[grade] or 0) - take
					left -= take
				end
			end
		end
		affordable = true
		return resources
	end)
	if ok and affordable then
		VaultService.refresh(player)
		return true
	end
	return false
end

-- Adds Standard-grade units to Exposed (refunds). One save, one refresh.
function VaultService.grant(player: Player, amounts: { [string]: number }): boolean
	checkAmounts(amounts, "grant")
	local standard = Config.Grade.Names[1]
	local ok = PlayerDataService.update(player, "Resources", OWNER, function(resources: Types.ResourceSnapshot)
		for resource, amount in amounts do
			local grades = resources.Exposed[resource]
			grades[standard] = (grades[standard] or 0) + amount
		end
		return resources
	end)
	if ok then
		VaultService.refresh(player)
	end
	return ok
end

-- Removes `share` (0..1) of every Exposed pile, resources and Scrap, rounded
-- down per pile. Banked is never touched (02 § Bank vs Exposed). Used when a
-- Scav gets away (04 § Scav Waves: "failing one costs Exposed resources");
-- what it takes is gone (a sink). Returns units taken (resources, scrap).
function VaultService.takeExposedShare(player: Player, share: number): (number, number)
	assert(share > 0 and share <= 1, `VaultService.takeExposedShare: bad share {share}`)
	local takenResources, takenScrap = 0, 0
	local ok = PlayerDataService.update(player, "Resources", OWNER, function(resources: Types.ResourceSnapshot)
		for _, grades in resources.Exposed do
			for grade, count in grades do
				local take = math.floor(count * share)
				grades[grade] = count - take
				takenResources += take
			end
		end
		return resources
	end)
	if not ok then
		takenResources = 0
	end
	ok = PlayerDataService.update(player, "Scrap", OWNER, function(scrap)
		takenScrap = math.floor(scrap.Exposed * share)
		scrap.Exposed -= takenScrap
		return scrap
	end)
	if not ok then
		takenScrap = 0
	end
	VaultService.refresh(player)
	return takenResources, takenScrap
end

-- Moves Exposed into the bank, best first, until full. Resources and Scrap
-- fill their own separate caps. Returns units moved (resources, scrap).
local function bankAll(player: Player): (number, number)
	local tier = vaultTier(player)
	if not tier then
		return 0, 0
	end
	local capacity = capacityForTier(tier)

	local movedResources = 0
	local ok = PlayerDataService.update(player, "Resources", OWNER, function(resources: Types.ResourceSnapshot)
		local room = math.max(0, capacity - totalUnits(resources.Banked))
		for _, grade in bankCfg.BankOrderGrades do
			for _, resource in bankCfg.BankOrderResources do
				if room <= 0 then
					return resources
				end
				local exposedGrades, bankedGrades = resources.Exposed[resource], resources.Banked[resource]
				local move = math.min(exposedGrades[grade] or 0, room)
				exposedGrades[grade] = (exposedGrades[grade] or 0) - move
				bankedGrades[grade] = (bankedGrades[grade] or 0) + move
				room -= move
				movedResources += move
			end
		end
		return resources
	end)
	if not ok then
		movedResources = 0
	end

	local movedScrap = 0
	local scrapCapacity = scrapCapacityFor(capacity)
	ok = PlayerDataService.update(player, "Scrap", OWNER, function(scrap)
		movedScrap = math.min(scrap.Exposed, math.max(0, scrapCapacity - scrap.Banked))
		scrap.Exposed -= movedScrap
		scrap.Banked += movedScrap
		return scrap
	end)
	if not ok then
		movedScrap = 0
	end

	return movedResources, movedScrap
end

-- ── Meter visibility (R4: hidden until the FTUE reveals it) ──────────────

-- Shows or hides this player's Banked/Exposed meter. A Player attribute
-- replicates by itself, so a client script that starts late still sees it.
function VaultService.setMeterVisible(player: Player, visible: boolean)
	player:SetAttribute(bankCfg.Meter.VisibleAttribute, visible)
end

function VaultService.isMeterVisible(player: Player): boolean
	return player:GetAttribute(bankCfg.Meter.VisibleAttribute) == true
end

-- ── Vault Core interaction ───────────────────────────────────────────────

local allowBank = RateLimiter.new("Bank", bankCfg.BankCooldownSeconds)

-- The client can fire a ProximityPrompt from anywhere with an exploit, so
-- the server re-checks everything (13-build-guide.md § Anti-exploit baseline).
local function onBankTriggered(core: Model, hitbox: BasePart, player: Player)
	if not allowBank(player) then
		return
	end
	-- Every Vault Core is a placed base piece with its owner's UserId. Clients
	-- hide the prompt on other people's cores (OwnBase.client.luau), but a
	-- fair press can still slip through as it hides, so this isn't logged.
	if core:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	-- The prompt measures to the Hitbox centre and this to its surface, so a
	-- fair press always passes; a far one means a modified client.
	local distance = NodeMath.distanceToHitbox(hitbox, root.Position)
	if distance > bankCfg.BankDistance then
		logAnomaly(player, "banked too far from a Vault Core", `{math.floor(distance)} > {bankCfg.BankDistance} studs`)
		return
	end

	local tier = vaultTier(player)
	if tier == 0 then
		print(`[Vault] {player.Name} has no Vault Core yet (tier 0): nothing banked`)
		return
	end
	local movedResources, movedScrap = bankAll(player)
	print(`[Vault] {player.Name} banked {movedResources} resources, {movedScrap} Scrap`)
	VaultService.refresh(player)
end

-- Greybox contract: code uses the Hitbox and never touches Visual.
local function setUpCore(instance: Instance)
	if not instance:IsA("Model") or not instance:IsDescendantOf(workspace) then
		return
	end
	local hitbox = instance:FindFirstChild("Hitbox")
	if not hitbox or not hitbox:IsA("BasePart") then
		warn(`[Vault] {instance:GetFullName()} is tagged {bankCfg.VaultCoreTag} but has no Hitbox part`)
		return
	end
	if hitbox:FindFirstChildOfClass("ProximityPrompt") then
		return -- already set up
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Bank"
	prompt.HoldDuration = bankCfg.PromptHoldSeconds
	prompt.MaxActivationDistance = bankCfg.BankDistance
	prompt.Parent = hitbox
	prompt.Triggered:Connect(function(player: Player)
		onBankTriggered(instance, hitbox, player)
	end)
end

-- A Grade or resource missing from these orders could never be banked/spent.
local function selfTestBankOrder()
	local function sameSet(listed: { string }, all: { string }, what: string)
		local seen: { [string]: boolean } = {}
		for _, name in listed do
			seen[name] = true
		end
		assert(#listed == #all, `Config.Bank.{what} has {#listed} entries, expected {#all}`)
		for _, name in all do
			assert(seen[name], `Config.Bank.{what} is missing "{name}"`)
		end
	end
	sameSet(bankCfg.BankOrderGrades, Config.Grade.Names, "BankOrderGrades")
	sameSet(bankCfg.BankOrderResources, Config.Resources.Types, "BankOrderResources")
	-- A Grade missing from the spend order could never be spent.
	sameSet(bankCfg.SpendOrderGrades, Config.Grade.Names, "SpendOrderGrades")
end

function VaultService.start()
	selfTestBankOrder()

	PlayerDataService.Loaded:Connect(function(player: Player)
		if bankCfg.Meter.ShowBeforeFtue then
			VaultService.setMeterVisible(player, true)
		end
		VaultService.refresh(player)
	end)

	for _, core in CollectionService:GetTagged(bankCfg.VaultCoreTag) do
		setUpCore(core)
	end
	CollectionService:GetInstanceAddedSignal(bankCfg.VaultCoreTag):Connect(setUpCore)

	-- The meter asks once at start-up, in case it missed the Loaded push.
	local allow = RateLimiter.new("GetVaultState", bankCfg.SnapshotCooldownSeconds)
	Remotes.getFunction("GetVaultState").OnServerInvoke = function(player: Player): Types.VaultState?
		if not allow(player) then
			return nil
		end
		return VaultService.getState(player)
	end
end

return VaultService
