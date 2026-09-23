--!strict
-- Studio-only debug keys. Sends a command NAME; the server decides what
-- happens and prints the result in Output (R5).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local debugEvent = Remotes.getEvent("DebugCommand")
local mineEvent = Remotes.getEvent("MineNode")

-- The keys live in Shared/DebugKeyList (also the Bag's Debug tab). They
-- avoid I/O (camera zoom: Roblox marks them as handled, so they never reach
-- this script), WASD/Space, E (prompts), R (build rotate), 1-4 (gadgets).
local DebugKeyList = require(Shared:WaitForChild("DebugKeyList"))
local KEYS: { [Enum.KeyCode]: string } = {}
for _, entry in DebugKeyList do
	if entry.Command ~= "" then
		KEYS[entry.Key] = entry.Command
	end
end

-- Key M: the rate-limit test. Fires the REAL MineNode remote many times in
-- one frame at the nearest node, exactly what an exploit script would do.
-- Expected: at most one hit lands, and the server logs [RateLimit] MineNode.
local function spamNearestNode()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local nearest: Instance? = nil
	local nearestDistance = math.huge
	for _, node in CollectionService:GetTagged(Config.Nodes.Tag) do
		local hitbox = node:FindFirstChild("Hitbox")
		if hitbox and hitbox:IsA("BasePart") and node:IsDescendantOf(workspace) then
			local distance = (hitbox.Position - root.Position).Magnitude
			if distance < nearestDistance then
				nearest, nearestDistance = node, distance
			end
		end
	end
	if not nearest then
		warn("[Debug] no node found to spam")
		return
	end
	print(`[Debug] firing MineNode {Config.Nodes.DebugSpamCount}x at {nearest.Name} ({math.floor(nearestDistance)} studs away)`)
	for _ = 1, Config.Nodes.DebugSpamCount do
		mineEvent:FireServer(nearest)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return -- typing in chat etc.
	end
	if input.KeyCode == Enum.KeyCode.M then
		spamNearestNode()
		return
	end
	local command = KEYS[input.KeyCode]
	if command then
		debugEvent:FireServer(command)
	end
end)

local parts = {}
for _, entry in DebugKeyList do
	table.insert(parts, `{entry.Label} = {entry.Text}`)
end
print("[Debug] Studio keys (also in the Bag's Debug tab): " .. table.concat(parts, ", ") .. "; Bag X = delete")
