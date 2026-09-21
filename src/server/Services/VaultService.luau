--!strict
-- VaultService: the only service that writes the Resources section
-- (Config.Data.SectionOwners; CLAUDE.md "only a system's own service
-- mutates its data").
--
-- STEP 2 = MINIMAL. deposit() puts everything into Exposed. Step 3 adds the
-- Vault Core cap, overflow and the Prismatic/Vaultborn auto-bank
-- (02-core-loop.md § Bank vs Exposed, § Special cases; 05-items.md
-- § Auto-bank protection). Until then nothing can be stolen (no raiding
-- yet), so Exposed-only is harmless.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local OWNER = "VaultService"

local isResource: { [string]: boolean } = {}
for _, name in Config.Resources.Types do
	isResource[name] = true
end
local isGrade: { [string]: boolean } = {}
for _, name in Config.Grade.Names do
	isGrade[name] = true
end

local VaultService = {}

-- The player's own Banked/Exposed counts, or nil if their profile isn't loaded.
function VaultService.getSnapshot(player: Player): Types.ResourceSnapshot?
	return PlayerDataService.get(player, "Resources")
end

local function pushSnapshot(player: Player)
	local snapshot = VaultService.getSnapshot(player)
	if snapshot then
		Remotes.getEvent("ResourcesChanged"):FireClient(player, snapshot)
	end
end

-- Adds `amount` units of `resource` at `grade`. Only server code calls this,
-- with values the server decided (R5). Returns true if it was saved.
function VaultService.deposit(player: Player, resource: string, grade: string, amount: number): boolean
	-- Bad arguments here are a server bug, never player input: fail loudly.
	assert(isResource[resource], `VaultService.deposit: unknown resource "{resource}"`)
	assert(isGrade[grade], `VaultService.deposit: unknown grade "{grade}"`)
	assert(amount > 0 and amount == math.floor(amount), `VaultService.deposit: bad amount {amount}`)

	local ok = PlayerDataService.update(player, "Resources", OWNER, function(resources: Types.ResourceSnapshot)
		local grades = resources.Exposed[resource]
		grades[grade] = (grades[grade] or 0) + amount
		return resources
	end)
	if ok then
		pushSnapshot(player)
	end
	return ok
end

function VaultService.start()
	PlayerDataService.Loaded:Connect(pushSnapshot)

	-- The HUD asks once at start-up, in case it missed the Loaded push.
	local allow = RateLimiter.new("GetResources", Config.Bank.SnapshotCooldownSeconds)
	Remotes.getFunction("GetResources").OnServerInvoke = function(player: Player): Types.ResourceSnapshot?
		if not allow(player) then
			return nil
		end
		return VaultService.getSnapshot(player)
	end
end

return VaultService
