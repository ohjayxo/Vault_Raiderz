--!strict
-- LockpickModel: the lockpick's physics, pure math with no Roblox services.
-- Adapted from Josh's LOCKPICKING GUIDE (Skyrim / Fallout research, §3/§10).
-- 02-core-loop.md § Lockpick skill model: speed, never fail-locked.
--
-- Only the SERVER runs step() with a real sweet spot (R5): the client never
-- learns where it is, only how far the lock turned and how hard it shakes.
-- Angles in degrees. Pick: -90..+90, 0 = straight up. Lock: 0 = resting,
-- Config FullTurn = open.
--
--   sweet spot     the lock turns all the way -> this stage is solved
--   partial zone   the lock turns part way, further the closer you are
--   outside        the lock barely budges (MinBudge)
-- Holding the turn at a limit short of open = "stalled": the pick takes
-- damage (dt / breakSeconds) and snaps at 1. Releasing lets the lock spring
-- back but keeps the damage (no tap-spam trick).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local cfg = Config.Raiding.Lockpick

export type StageConfig = {
	SweetWidth: number, -- full width of the sweet spot (degrees)
	PartialWidth: number, -- width of EACH partial zone beside it (degrees)
	BreakSeconds: number, -- seconds of stalling that snap a fresh pick
}

export type State = {
	pickAngle: number,
	lockAngle: number,
	damage: number, -- 0..1 on the current pick; kept when the turn is released
	tension: boolean, -- turn input held
	needsRelease: boolean, -- after a break or a solved stage, ignore the held turn until released
	stalled: boolean,
	closeness: number, -- 0 (outside) .. 1 (sweet spot): feeds the shake
	lockout: number, -- seconds left fitting a fresh pick
}

export type StepResult = "solved" | "broke"

local LockpickModel = {}

function LockpickModel.newState(): State
	return {
		pickAngle = 0,
		lockAngle = 0,
		damage = 0,
		tension = false,
		needsRelease = false,
		stalled = false,
		closeness = 0,
		lockout = 0,
	}
end

-- This lock's stages: always #cfg.Stages of them, each narrowed by
-- `difficultySteps` (vault tier above 1 + Lock Upgrades; Config comment).
function LockpickModel.stagesFor(difficultySteps: number): { StageConfig }
	local widthScale = cfg.WidthScalePerStep ^ difficultySteps
	local breakScale = cfg.BreakScalePerStep ^ difficultySteps
	local stages: { StageConfig } = {}
	for i, base in cfg.Stages do
		stages[i] = {
			SweetWidth = math.max(cfg.MinSweetWidth, base.SweetWidth * widthScale),
			PartialWidth = math.max(cfg.MinPartialWidth, base.PartialWidth * widthScale),
			BreakSeconds = math.max(cfg.MinBreakSeconds, base.BreakSeconds * breakScale),
		}
	end
	return stages
end

-- The raider's input. The pick can't move while Turn is held (guide §2 #3):
-- both hands are on the lock.
function LockpickModel.setInput(s: State, pickAngle: number, tension: boolean)
	if not (s.tension and tension) then
		s.pickAngle = math.clamp(pickAngle, -cfg.PickLimit, cfg.PickLimit)
	end
	s.tension = tension
end

-- How far the lock may turn with the pick here, and closeness 0..1.
function LockpickModel.turnLimit(pickAngle: number, center: number, stage: StageConfig): (number, number)
	local d = math.abs(pickAngle - center)
	local half = stage.SweetWidth / 2
	if d <= half then
		return cfg.FullTurn, 1
	end
	local t = (d - half) / stage.PartialWidth
	if t >= 1 then
		return cfg.MinBudge, 0
	end
	local closeness = 1 - t
	return cfg.MinBudge + (cfg.NearMax - cfg.MinBudge) * closeness ^ cfg.Curve, closeness
end

-- Advances one step of `dt` seconds. `breakSeconds` is this pick's own
-- (stage value with the pick's durability roll). Returns "solved", "broke"
-- or nil.
function LockpickModel.step(s: State, dt: number, center: number, stage: StageConfig, turnSpeed: number, breakSeconds: number): StepResult?
	if s.lockout > 0 then
		s.lockout = math.max(0, s.lockout - dt)
	end
	local applying = s.tension and not s.needsRelease and s.lockout <= 0
	if not s.tension then
		s.needsRelease = false
	end

	local limit, closeness = LockpickModel.turnLimit(s.pickAngle, center, stage)
	s.closeness = closeness

	if not applying then
		-- Spring back. Damage is NOT reset (guide pitfall 1).
		s.stalled = false
		s.lockAngle = math.max(0, s.lockAngle - cfg.ReturnSpeed * dt)
		return nil
	end

	if s.lockAngle > limit then
		s.lockAngle = math.max(limit, s.lockAngle - cfg.ReturnSpeed * dt)
	else
		s.lockAngle = math.min(limit, s.lockAngle + turnSpeed * dt)
	end

	-- Solved only when fully turned AND the pick is in the sweet spot
	-- (guide pitfall 7).
	if closeness >= 1 and s.lockAngle >= cfg.FullTurn - cfg.Epsilon then
		s.stalled = false
		return "solved"
	end

	s.stalled = math.abs(s.lockAngle - limit) <= cfg.Epsilon
	if s.stalled then
		s.damage += dt / breakSeconds -- frame-rate independent (pitfall 2)
		if s.damage >= 1 then
			return "broke"
		end
	end
	return nil
end

-- After a break (the pick count is handled by the caller). The pick keeps
-- its angle: it follows the pointer, so recentring it would only snap back.
function LockpickModel.onBreak(s: State, lockoutSeconds: number)
	s.damage = 0
	s.stalled = false
	s.needsRelease = true
	s.lockout = lockoutSeconds
	s.lockAngle = 0
end

-- After a solved stage: the lock resets for the next pin. The pick keeps
-- its damage (it's the same pick) and Turn must be let go first.
function LockpickModel.onSolved(s: State)
	s.stalled = false
	s.needsRelease = true
	s.lockAngle = 0
	s.closeness = 0
end

-- A stage's sweet-spot centre. side = -1 (left) / 1 (right). After the
-- first stage it stays on the same side only SameSideChance of the time
-- (Josh's goal, guide §1). Always fully reachable (pitfall 5).
function LockpickModel.rollCenter(rng: Random, prevSide: number?, sweetWidth: number): (number, number)
	local side: number
	if prevSide then
		side = if rng:NextNumber() < cfg.SameSideChance then prevSide else -prevSide
	else
		side = if rng:NextInteger(0, 1) == 0 then -1 else 1
	end
	local maxOffset = cfg.PickLimit - sweetWidth / 2
	local lo = math.min(cfg.MinOffset, maxOffset)
	return side * (lo + rng:NextNumber() * (maxOffset - lo)), side
end

return LockpickModel
