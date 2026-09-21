--!strict
-- Studio-only debug keys. Sends a command NAME; the server decides what
-- happens and prints the result in Output (R5).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then
	return
end

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local debugEvent = Remotes.getEvent("DebugCommand")

-- Avoids I/O (camera zoom) and WASD/Space.
local KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.P] = "PrintProfile",
	[Enum.KeyCode.C] = "GrantCredits",
	[Enum.KeyCode.L] = "PrintPresence",
	[Enum.KeyCode.X] = "GrantMinerXP",
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return -- typing in chat etc.
	end
	local command = KEYS[input.KeyCode]
	if command then
		debugEvent:FireServer(command)
	end
end)

print("[Debug] Studio keys: P = print profile, C = +Credits, L = presence, X = +Miner XP")
