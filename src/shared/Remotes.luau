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
local definitions: { [string]: RemoteKind } = {}

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
