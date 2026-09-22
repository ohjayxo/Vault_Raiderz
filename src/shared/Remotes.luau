--!strict
-- The one place every RemoteEvent / RemoteFunction is defined (CLAUDE.md
-- § Architecture rules). The SERVER creates them all at startup via
-- Remotes.init(); clients only look them up with getEvent / getFunction.
--
-- Remotes carry INTENTS ("I want to mine this node"), never values (R5).
-- Every remote handler must validate distance, ownership, cooldowns,
-- existence and apply a rate limit on the server
-- (docs/13-build-guide.md § Part D, § Anti-exploit baseline).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemoteKind = "Event" | "Function"

local FOLDER_NAME = "Remotes"
-- How long a client waits for the server to create a remote before erroring.
-- Not a gameplay number, so it lives here rather than in Config.
local CLIENT_WAIT_SECONDS = 10

-- name -> kind. Each build step adds its own remotes here, e.g.
--   MineNode = "Event",
--   GetProfileSummary = "Function",
local definitions: { [string]: RemoteKind } = {
	-- THROWAWAY (build step 0B): client asks for a perf-spike test preset by
	-- name. Delete with src/server/PerfSpike.
	PerfSpikeSetPreset = "Event",
	-- Studio-only debug commands (client sends a command NAME; the server
	-- ignores it outside Studio). Step 1.
	DebugCommand = "Event",

	-- Step 2: nodes, resources, broadcasts.
	MineNode = "Event", -- client -> server: (node: Model) "I want to mine this"
	MineResult = "Event", -- server -> miner: (resource, grade, amount, hitsLeft)
	GradeFx = "Event", -- server -> all: (grade, position) play the Grade effect there
	Announcement = "Event", -- server -> clients: (kind, text) from BroadcastQueue (D58)

	-- Step 3: Vault Core + Bank/Exposed. (Banking itself is the Vault Core's
	-- ProximityPrompt, which the server listens to directly: no remote.)
	VaultChanged = "Event", -- server -> owner: (VaultState) their own Banked/Exposed/Scrap
	GetVaultState = "Function", -- client -> server: () -> VaultState? (for meter start-up)

	-- Step 4: plots + base building. Each build intent returns (ok, reason?);
	-- reason is a short code the build UI turns into text.
	PlacePiece = "Function", -- (kind, x, z, rot) -> (ok, reason?)
	MovePiece = "Function", -- (pieceId, x, z, rot) -> (ok, reason?)
	RemovePiece = "Function", -- (pieceId) -> (ok, reason?)
	UpgradeVault = "Function", -- () -> (ok, reason?)
	GetBaseState = "Function", -- () -> BaseState? (build UI start-up)
	BaseChanged = "Event", -- server -> owner: (BaseState)

	-- Step 5: combat, pickaxe upgrades, armor, gadgets.
	Swing = "Event", -- client -> server: () "I swing" (the server picks the target)
	HitFx = "Event", -- server -> all: (position, comboStep) a hit landed here
	BuyUpgrade = "Function", -- (upgradeId) -> (ok, reason?)
	RespecUpgrades = "Function", -- () -> (ok, reason?)
	EquipArmor = "Function", -- (pieceId or "") -> (ok, reason?)
	UseGadget = "Function", -- (gadgetId) -> (ok, reason?)
	GetGearState = "Function", -- () -> GearState? (Gear menu start-up)
	GearChanged = "Event", -- server -> owner: (GearState)

	-- Step 6: defenses + Scav Waves.
	RefillDefense = "Function", -- (pieceId) -> (ok, reason?)
	BaseAlert = "Event", -- server -> owner: (kind, text) about their own base

	-- Pickaxe skins.
	EquipSkin = "Function", -- (skinId or "") -> (ok, reason?)

	-- Step 7: raiding. All intents; the server picks the target base itself.
	Breach = "Function", -- () -> (ok, reason?) raid the base you're standing at
	LockpickTurn = "Function", -- (angle 0..1) -> (ok, "turning"|"stuck"|reason) while holding Turn
	Grab = "Function", -- () -> (ok, reason?)
	Sabotage = "Function", -- (defense: Model) -> (ok, reason?) tiers 5-7
	JoinEscort = "Function", -- (raidId) -> (ok, reason?)
	RaidState = "Event", -- server -> raider/escort/victim: (RaidView?) nil = raid over
	EscortOffer = "Event", -- server -> a raider's friend: (raidId, raiderName, seconds)
	GetRaidLog = "Function", -- () -> { RaidLogEntry }
}

local Remotes = {}

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing :: Folder
	end
	assert(RunService:IsServer(), "Remotes folder missing on the client - has the server run Remotes.init()?")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

-- Server only. Creates every defined remote. Safe to call more than once.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init() may only run on the server")
	local folder = getFolder()
	for name, kind in definitions do
		if folder:FindFirstChild(name) then
			continue
		end
		local remote: Instance = if kind == "Event" then Instance.new("RemoteEvent") else Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
end

local function getRemote(name: string, kind: RemoteKind): Instance
	assert(definitions[name] == kind, `Remote "{name}" is not defined as a {kind} in Remotes.luau`)
	local folder = getFolder()
	if RunService:IsServer() then
		local found = folder:FindFirstChild(name)
		assert(found, `Remote "{name}" not created - call Remotes.init() first`)
		return found
	end
	local found = folder:WaitForChild(name, CLIENT_WAIT_SECONDS)
	assert(found, `Remote "{name}" never appeared - did the server create it?`)
	return found
end

function Remotes.getEvent(name: string): RemoteEvent
	return getRemote(name, "Event") :: RemoteEvent
end

function Remotes.getFunction(name: string): RemoteFunction
	return getRemote(name, "Function") :: RemoteFunction
end

return Remotes
