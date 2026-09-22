--!strict
-- MovementService: the only code that sets a Humanoid's WalkSpeed and
-- JumpPower on the server. Every effect (Sprint Serum, Shock Trap stun, and
-- in step 7 the Chase loot slow and carry-speed upgrade) registers a
-- modifier here instead of writing WalkSpeed itself, so effects stack
-- predictably and never overwrite each other.
--
-- Docs: 02-core-loop.md § Gadgets, § The Chase (loot slow, step 7).
-- The server-side movement / teleport check (docs-build/backlog.md M1, due
-- by step 7) belongs here too.
--
-- Works for players and NPCs (Scavs, step 6): an NPC's base speed is
-- whatever its WalkSpeed was when first touched.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PickaxeService = require(script.Parent.PickaxeService)

type State = {
	baseSpeed: number,
	baseJump: number,
	multipliers: { [string]: number? },
	tokens: { [string]: number }, -- bumps so an old timer can't end a refreshed effect
	stunUntil: number,
	stunToken: number,
}

local states: { [Humanoid]: State } = {}

local MovementService = {}

local function stateOf(humanoid: Humanoid): State
	local existing = states[humanoid]
	if existing then
		return existing
	end
	local isPlayer = Players:GetPlayerFromCharacter(humanoid.Parent) ~= nil
	local state: State = {
		baseSpeed = if isPlayer then Config.Movement.BaseWalkSpeed else humanoid.WalkSpeed,
		baseJump = if isPlayer then Config.Movement.BaseJumpPower else humanoid.JumpPower,
		multipliers = {},
		tokens = {},
		stunUntil = 0,
		stunToken = 0,
	}
	states[humanoid] = state
	humanoid.Destroying:Connect(function()
		states[humanoid] = nil
	end)
	return state
end

local function apply(humanoid: Humanoid)
	local state = stateOf(humanoid)
	if os.clock() < state.stunUntil then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		return
	end
	local speed = state.baseSpeed
	for _, multiplier in state.multipliers do
		speed *= multiplier :: number
	end
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = state.baseJump
end

-- Sets (or with nil, clears) a named speed multiplier.
function MovementService.setMultiplier(humanoid: Humanoid, key: string, multiplier: number?)
	local state = stateOf(humanoid)
	state.multipliers[key] = multiplier
	state.tokens[key] = (state.tokens[key] or 0) + 1
	apply(humanoid)
end

-- How much of a stun/slow to cut for this humanoid: a player's Mobility
-- "Stun recovery" ranks (Josh's call, 2026-09-21). NPCs get none.
local function recoveryOf(humanoid: Humanoid): number
	local player = Players:GetPlayerFromCharacter(humanoid.Parent)
	return if player then PickaxeService.stunRecovery(player) else 0
end

-- A slowing multiplier (below 1), softened by Stun recovery. nil clears it.
function MovementService.setSlow(humanoid: Humanoid, key: string, multiplier: number?)
	if multiplier == nil then
		MovementService.setMultiplier(humanoid, key, nil)
		return
	end
	local recovery = recoveryOf(humanoid)
	MovementService.setMultiplier(humanoid, key, 1 - (1 - multiplier) * (1 - recovery))
end

-- A multiplier that ends by itself. Using it again refreshes the duration.
function MovementService.setMultiplierFor(humanoid: Humanoid, key: string, multiplier: number, seconds: number)
	MovementService.setMultiplier(humanoid, key, multiplier)
	local state = stateOf(humanoid)
	local token = state.tokens[key]
	task.delay(seconds, function()
		if states[humanoid] == state and state.tokens[key] == token then
			MovementService.setMultiplier(humanoid, key, nil)
		end
	end)
end

-- No walking or jumping for `seconds` (shortened by Stun recovery). A
-- longer stun already running wins.
function MovementService.stun(humanoid: Humanoid, seconds: number)
	seconds *= 1 - recoveryOf(humanoid)
	local state = stateOf(humanoid)
	state.stunUntil = math.max(state.stunUntil, os.clock() + seconds)
	state.stunToken += 1
	local token = state.stunToken
	apply(humanoid)
	task.delay(seconds, function()
		if states[humanoid] == state and state.stunToken == token then
			apply(humanoid)
		end
	end)
end

function MovementService.isStunned(humanoid: Humanoid): boolean
	local state = states[humanoid]
	return state ~= nil and os.clock() < state.stunUntil
end

return MovementService
