--!strict
-- Client-side rules for base pieces, for THIS player only:
--   * Your own gates let you through; everyone else's are solid.
--     02-core-loop.md § Buildable elements ("Walls & Gates — path control").
--   * The "Bank" prompt only shows on your own Vault Core (you can only
--     bank into your own vault; VaultService re-checks the owner).
--
-- Each client moves its own character and draws its own prompts, so these
-- changes affect only this player; the server and other players still see a
-- solid gate. Raiders get past gates by breaching (step 7), never by this.
-- (A modified client could noclip through any wall anyway: that's the
-- movement check in docs-build/backlog.md M1, due by step 7.)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local player = Players.LocalPlayer

local function isMine(model: Instance): boolean
	return model:GetAttribute("OwnerUserId") == player.UserId
end

local function onGate(gate: Instance)
	if not isMine(gate) then
		return
	end
	local hitbox = gate:WaitForChild("Hitbox", 5)
	if hitbox and hitbox:IsA("BasePart") then
		hitbox.CanCollide = false
	end
end

-- The server adds the prompt right after the core appears, so watch for it.
local function onVaultCore(core: Instance)
	if isMine(core) then
		return
	end
	local hitbox = core:WaitForChild("Hitbox", 5)
	if not hitbox then
		return
	end
	local function hide(child: Instance)
		if child:IsA("ProximityPrompt") then
			child.Enabled = false
		end
	end
	for _, child in hitbox:GetChildren() do
		hide(child)
	end
	hitbox.ChildAdded:Connect(hide)
end

for _, gate in CollectionService:GetTagged(Config.Base.GateTag) do
	task.spawn(onGate, gate)
end
CollectionService:GetInstanceAddedSignal(Config.Base.GateTag):Connect(onGate)

for _, core in CollectionService:GetTagged(Config.Bank.VaultCoreTag) do
	task.spawn(onVaultCore, core)
end
CollectionService:GetInstanceAddedSignal(Config.Bank.VaultCoreTag):Connect(onVaultCore)
