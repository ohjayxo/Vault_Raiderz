--!strict
-- Server entry point. Every system's service gets started from here as the
-- build steps add them (docs/13-build-guide.md § Part D). R5: the server is
-- the only authority, so this is where all logic boots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

print("Vaultbreakers server up")

-- Remotes must exist before any client asks for them (clients WaitForChild).
Remotes.init()

-- THROWAWAY build step 0B (mobile perf spike). Delete with src/server/PerfSpike.
if Config.PerfSpike.Enabled then
	require(script.Parent.PerfSpike).start()
end
