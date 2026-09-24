--!strict
-- Raid UI (step 7): context buttons, the lockpick bar, the raid timer, the
-- escort offer and the raid log with its path map.
-- 02-core-loop.md § Raiding, § Lockpick skill model, § The Chase, § Raid
-- escort (D101), § Raid log path map (D105).
--
-- Display + intents only. The server picks the target base, runs the lock
-- itself, and decides every outcome (R5). The lockpick dial sends only
-- (pick angle, holding Turn) and draws how the server's lock responds
-- (LockpickFeel); the sweet spot never reaches this client outside Studio.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local NodeMath = require(Shared:WaitForChild("NodeMath"))
local Types = require(Shared:WaitForChild("PlayerDataTypes"))

local player = Players.LocalPlayer
local raidCfg = Config.Raiding
local pickCfg = raidCfg.Lockpick
local pickUi = pickCfg.Ui
local SIZE = Config.Combat.Ui.ButtonSize

local REASON_TEXT: { [string]: string } = {
	Busy = "Too fast",
	Invalid = "Can't do that",
	InRaid = "You're already in a raid",
	Dead = "You're down",
	NoBase = "Stand at someone's plot to breach it",
	OwnBase = "That's your own base",
	NoVault = "They have no Vault Core to raid",
	AlreadyRaided = "Someone is already raiding that base",
	Online = "They just came online",
	Locked = "That base was raided recently",
	-- Step 8 (02 § Preconditions; R6). The band is never shown as a number (D92).
	NoCharges = "You need a Breach Charge (craft it in the Bag)",
	OutOfBand = "That base is out of your range",
	Shielded = "That player is shielded",
	ConfirmShield = "This ends YOUR shield. Tap Breach again",
	TooFar = "Get closer",
	NotPicking = "Not picking a lock",
	Wait = "Steady...",
	NotReady = "Pick the lock first",
	NotRaiding = "You're not raiding",
	NoSabotage = "Can't sabotage here",
	Expired = "Too late",
	NotOffered = "You weren't invited",
	Failed = "Something went wrong",
}

local state: Types.RaidView? = nil
local busy = false

-- ── UI ───────────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "RaidUi"
gui.ResetOnSpawn = false
gui.DisplayOrder = 8 -- above the HUD, below menus

local function button(text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(SIZE * 1.8, SIZE * 0.9)
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.Text = text
	b.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = b
	b.Parent = gui
	return b
end

local function label(size: UDim2, position: UDim2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Size = size
	l.Position = position
	l.BackgroundColor3 = Color3.new(0, 0, 0)
	l.BackgroundTransparency = 0.35
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextWrapped = true
	l.Visible = false
	l.Parent = gui
	return l
end

-- Context buttons stack above the Attack/Build buttons (bottom right).
local actionButton = button("Breach", Color3.fromRGB(170, 60, 40))
actionButton.AnchorPoint = Vector2.new(1, 1)
actionButton.Position = UDim2.new(1, -16, 1, -16 - SIZE * 3.1)
local sabotageButton = button("Sabotage", Color3.fromRGB(110, 60, 150))
sabotageButton.AnchorPoint = Vector2.new(1, 1)
sabotageButton.Position = UDim2.new(1, -16, 1, -16 - SIZE * 4.1)

local banner = label(UDim2.fromOffset(420, 44), UDim2.new(0.5, 0, 0, 104), 18)
-- D115 grip bar, right under the banner (carrier + owner only: the server
-- only sends Grip to them).
local gripBack = Instance.new("Frame")
gripBack.AnchorPoint = Vector2.new(0.5, 0)
gripBack.Position = UDim2.new(0.5, 0, 0, 104 + 44)
gripBack.Size = UDim2.fromOffset(420, raidCfg.Ui.GripBarHeight)
gripBack.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
gripBack.BorderSizePixel = 0
gripBack.Visible = false
gripBack.Parent = gui
local gripFill = Instance.new("Frame")
gripFill.Size = UDim2.fromScale(1, 1)
gripFill.BackgroundColor3 = raidCfg.Ui.GripColor
gripFill.BorderSizePixel = 0
gripFill.Parent = gripBack
local message = label(UDim2.fromOffset(360, 30), UDim2.new(0.5, 0, 0.62, 0), 16)
message.AutomaticSize = Enum.AutomaticSize.Y -- longer refusals wrap onto a second line

-- Lockpick dial (Skyrim-style, Josh's call + his LOCKPICKING GUIDE): point
-- the pick (mouse, drag, or right stick), hold Turn. Near the secret angle
-- the lock turns further; dead on it opens the stage.
-- The lock plate (square, like Skyrim's), with the lock in the middle.
local dial = Instance.new("Frame")
dial.AnchorPoint = Vector2.new(0.5, 1)
dial.Position = UDim2.new(0.5, 0, 1, -SIZE * 1.6)
dial.Size = UDim2.fromOffset(200, 200)
dial.BackgroundColor3 = Color3.fromRGB(58, 58, 64)
dial.BackgroundTransparency = 0.1
dial.Visible = false
dial.Parent = gui
local plateRound = Instance.new("UICorner")
plateRound.CornerRadius = UDim.new(0, 10)
plateRound.Parent = dial

-- The lock face turns as the pin gives.
local face = Instance.new("Frame")
face.AnchorPoint = Vector2.new(0.5, 0.5)
face.Position = UDim2.fromScale(0.5, 0.5)
face.Size = UDim2.fromOffset(128, 128)
face.BackgroundColor3 = Color3.fromRGB(150, 120, 60) -- brass
face.Parent = dial
local faceRound = Instance.new("UICorner")
faceRound.CornerRadius = UDim.new(1, 0)
faceRound.Parent = face
local keyway = Instance.new("Frame") -- the keyhole, turns with the lock
keyway.AnchorPoint = Vector2.new(0.5, 0.5)
keyway.Position = UDim2.fromScale(0.5, 0.5)
keyway.Size = UDim2.fromOffset(16, 62)
keyway.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
keyway.Parent = face
local keyholeRound = Instance.new("UICorner")
keyholeRound.CornerRadius = UDim.new(0, 6)
keyholeRound.Parent = keyway

-- The tension wrench sits in the keyway and turns with the lock.
local wrench = Instance.new("Frame")
wrench.AnchorPoint = Vector2.new(0.5, 0.5)
wrench.Position = UDim2.fromScale(0.5, 0.5)
wrench.Size = UDim2.fromOffset(10, 54)
wrench.BackgroundColor3 = Color3.fromRGB(120, 120, 140)
wrench.ZIndex = 2
wrench.Parent = dial

-- The pick pivots on ONE point: the middle of the keyhole. Roblox rotates a
-- frame around its own centre, so the pick lives inside an invisible pivot
-- frame centred on the keyhole; rotating the pivot swings the pick's free
-- end while its tip stays put in the hole.
local PICK_LENGTH = 92
local pickPivot = Instance.new("Frame")
pickPivot.AnchorPoint = Vector2.new(0.5, 0.5)
pickPivot.Position = UDim2.fromScale(0.5, 0.5) -- = the keyhole
pickPivot.Size = UDim2.fromOffset(PICK_LENGTH * 2, PICK_LENGTH * 2)
pickPivot.BackgroundTransparency = 1
pickPivot.ZIndex = 3
pickPivot.Parent = dial

local pickArm = Instance.new("Frame")
pickArm.AnchorPoint = Vector2.new(0.5, 1) -- its bottom end sits at the pivot
pickArm.Position = UDim2.fromScale(0.5, 0.5)
pickArm.Size = UDim2.fromOffset(5, PICK_LENGTH)
pickArm.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
pickArm.ZIndex = 3
pickArm.Parent = pickPivot
local pickTip = Instance.new("Frame") -- the bit in the hole
pickTip.AnchorPoint = Vector2.new(0.5, 1)
pickTip.Position = UDim2.fromScale(0.5, 1)
pickTip.Size = UDim2.fromOffset(9, 14)
pickTip.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
pickTip.ZIndex = 3
pickTip.Parent = pickArm

local pinsLabel = Instance.new("TextLabel")
pinsLabel.AnchorPoint = Vector2.new(0.5, 1)
pinsLabel.Position = UDim2.new(0.5, 0, 0, -6)
pinsLabel.Size = UDim2.fromOffset(240, 22)
pinsLabel.BackgroundTransparency = 1
pinsLabel.TextColor3 = Color3.new(1, 1, 1)
pinsLabel.Font = Enum.Font.GothamBold
pinsLabel.TextSize = 16
pinsLabel.Parent = dial

-- Studio only (guide §7): tick marks round the plate tint the sweet spot
-- (green) and partial zones (yellow), for tuning. Live servers never send
-- the data, so these stay hidden there.
local OVERLAY_STEP = 2 -- degrees between ticks
local OVERLAY_RADIUS = 94
local overlayTicks: { [number]: Frame } = {}
if RunService:IsStudio() and pickCfg.StudioOverlay then
	for angle = -pickCfg.PickLimit, pickCfg.PickLimit, OVERLAY_STEP do
		local tick = Instance.new("Frame")
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		local radians = math.rad(angle)
		tick.Position = UDim2.new(0.5, math.sin(radians) * OVERLAY_RADIUS, 0.5, -math.cos(radians) * OVERLAY_RADIUS)
		tick.Size = UDim2.fromOffset(4, 9)
		tick.Rotation = angle
		tick.BorderSizePixel = 0
		tick.Visible = false
		tick.Parent = dial
		overlayTicks[angle] = tick
	end
end

-- Turn the lock: one hold button (phone), or hold D / W / Space (PC) or
-- the right trigger (gamepad).
local turnButton = button("TURN", Color3.fromRGB(60, 150, 80))
turnButton.AnchorPoint = Vector2.new(0, 0.5)
turnButton.Position = UDim2.new(0.5, 112, 1, -SIZE * 1.6 - 100)
turnButton.Size = UDim2.fromOffset(SIZE * 1.3, SIZE * 1.3)
turnButton.TextSize = 20
local cancelPick = button("Cancel", Color3.fromRGB(90, 60, 60))
cancelPick.AnchorPoint = Vector2.new(0.5, 1)
cancelPick.Position = UDim2.new(0.5, 0, 1, -SIZE * 0.6)
cancelPick.Size = UDim2.fromOffset(SIZE * 1.6, SIZE * 0.7)
cancelPick.TextSize = 16

-- Lockpick sounds: PLACEHOLDERS (Config ...Lockpick.Ui.Sounds). Each play
-- picks a random clip and jitters the pitch so it never sounds looped.
local function newSound(id: string): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Parent = gui -- not in a part: plays flat, only for this player
	return sound
end
local function playSound(ids: { string }, volume: number, pitch: number)
	local sound = newSound(ids[math.random(1, #ids)])
	sound.Volume = volume
	sound.PlaybackSpeed = pitch * (0.95 + math.random() * 0.1)
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(pickUi.SoundCleanupSeconds, function() -- in case a clip never loads
		if sound.Parent then
			sound:Destroy()
		end
	end)
end
local grindSound = newSound(pickUi.Sounds.Grind)
grindSound.Looped = true

-- Escort offer.
local offer = button("Join as escort", Color3.fromRGB(40, 110, 170))
offer.AnchorPoint = Vector2.new(0.5, 0)
offer.Position = UDim2.new(0.5, 0, 0, 156)
offer.Size = UDim2.fromOffset(SIZE * 4, SIZE * 0.9)

-- Raid log button + panel.
local logButton = button("Raids", Color3.fromRGB(45, 45, 60))
logButton.Position = UDim2.fromOffset(12, 170)
logButton.Size = UDim2.fromOffset(SIZE * 1.2, SIZE * 0.5)
local logPanel = Instance.new("Frame")
logPanel.AnchorPoint = Vector2.new(0.5, 0.5)
logPanel.Position = UDim2.fromScale(0.5, 0.5)
logPanel.Size = UDim2.fromOffset(560, 300)
logPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
logPanel.Visible = false
logPanel.Parent = gui
local logList = Instance.new("ScrollingFrame")
logList.Position = UDim2.fromOffset(8, 8)
logList.Size = UDim2.fromOffset(290, 284)
logList.BackgroundTransparency = 1
logList.AutomaticCanvasSize = Enum.AutomaticSize.Y
logList.CanvasSize = UDim2.new()
logList.Parent = logPanel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = logList
local map = Instance.new("Frame")
map.Position = UDim2.fromOffset(306, 8)
map.Size = UDim2.fromOffset(246, 246)
map.BackgroundColor3 = Color3.fromRGB(30, 36, 30)
map.ClipsDescendants = true
map.Parent = logPanel
local closeLog = Instance.new("TextButton")
closeLog.Position = UDim2.fromOffset(306, 260)
closeLog.Size = UDim2.fromOffset(246, 32)
closeLog.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
closeLog.TextColor3 = Color3.new(1, 1, 1)
closeLog.Font = Enum.Font.GothamBold
closeLog.TextSize = 16
closeLog.Text = "Close"
closeLog.Parent = logPanel

gui.Parent = player:WaitForChild("PlayerGui")

local messageToken = 0
local function showMessage(text: string)
	messageToken += 1
	local token = messageToken
	message.Text = text
	message.Visible = true
	task.delay(raidCfg.Ui.MessageSeconds, function()
		if messageToken == token then
			message.Visible = false
		end
	end)
end

local function ask(remote: RemoteFunction, ...: any): (boolean, string?)
	if busy then
		return false, nil
	end
	busy = true
	local ok, accepted, reason = pcall(remote.InvokeServer, remote, ...)
	busy = false
	if not ok then
		showMessage(REASON_TEXT.Failed)
		return false, nil
	end
	if not accepted and reason then
		showMessage(REASON_TEXT[reason] or REASON_TEXT.Failed)
	end
	return accepted, reason
end

-- ── Where am I? (client-side hints only; the server re-checks) ───────────

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Someone else's plot I'm standing at, or nil.
local function raidablePlotNear(root: BasePart): Model?
	for _, plot in CollectionService:GetTagged(Config.Plots.Tag) do
		local owner = plot:GetAttribute("OwnerUserId")
		local hitbox = plot:FindFirstChild("Hitbox")
		if owner and owner ~= player.UserId and hitbox and hitbox:IsA("BasePart")
			and NodeMath.distanceToHitbox(hitbox, root.Position) <= raidCfg.BreachRange
		then
			return plot :: Model
		end
	end
	return nil
end

local function victimCore(): BasePart?
	local current = state
	if not current then
		return nil
	end
	-- The victim's core = a core that isn't ours, within reach.
	local root = myRoot()
	for _, core in CollectionService:GetTagged(Config.Bank.VaultCoreTag) do
		local hitbox = core:FindFirstChild("Hitbox")
		if root and hitbox and hitbox:IsA("BasePart") and core:GetAttribute("OwnerUserId") ~= player.UserId
			and NodeMath.distanceToHitbox(hitbox, root.Position) <= raidCfg.CoreRange
		then
			return hitbox
		end
	end
	return nil
end

local function victimDefenseNear(root: BasePart): Model?
	for _, defense in CollectionService:GetTagged(Config.Defenses.Tag) do
		local hitbox = defense:FindFirstChild("Hitbox")
		if defense:GetAttribute("OwnerUserId") ~= player.UserId and hitbox and hitbox:IsA("BasePart")
			and NodeMath.distanceToHitbox(hitbox, root.Position) <= raidCfg.SabotageRange
		then
			return defense :: Model
		end
	end
	return nil
end

-- ── Per-frame refresh ────────────────────────────────────────────────────

-- The lockpick, client side. pickAngle is in degrees (-90..90, 0 = up)
-- and is frozen while Turn is held (both hands on the lock). The lock's
-- shown angle chases the server's at the same speeds, so it's smooth
-- between updates and springs back the moment Turn is let go.
local pickAngle = 0
local keyTurn = false -- D / W / Space / right trigger held
local buttonTurn = false -- the on-screen TURN button held
local feel: Types.LockpickFeel? = nil
local shownLock = 0
local lockoutUntil = 0 -- os.clock(): fitting a fresh pick
local stageFlashUntil = 0 -- os.clock(): "Pin set!"

local function holdingTurn(): boolean
	return keyTurn or buttonTurn
end

local function lootText(loot: { [string]: number }?): string
	if not loot then
		return ""
	end
	local parts = {}
	local counted = { "Stone", "Ore", "Riftsalt", "Scrap" }
	for _, key in counted do
		if (loot[key] or 0) > 0 then
			table.insert(parts, `{loot[key]} {key}`)
		end
	end
	for key in loot do -- anything else is a stolen armor piece (D112)
		if not table.find(counted, key) then
			table.insert(parts, key)
		end
	end
	return table.concat(parts, ", ")
end

-- "70/140 studs · " while someone's carrying loot (the server's number).
local function chaseText(view: Types.RaidView): string
	if view.Phase ~= "Carrying" or not view.ChaseStuds then
		return ""
	end
	local grip = if view.Grip then `grip {view.Grip}/{raidCfg.GripDamage} · ` else ""
	return `{view.ChaseStuds}/{raidCfg.EscapeRadiusStuds} studs · {grip}`
end

local actionKind = "" -- what actionButton does right now

RunService.RenderStepped:Connect(function(dt: number)
	local root = myRoot()
	local current = state
	local t = workspace:GetServerTimeNow()
	actionKind = ""

	if current then
		local left = math.max(0, math.ceil(current.EndsAt - t))
		if current.Role == "Victim" then
			banner.Text = if current.Phase == "Carrying"
				then `{current.RaiderName} has your loot ({lootText(current.Loot)})! {chaseText(current)}Hit them to break their grip - {left}s`
				else `RAID! {current.RaiderName} is at your base - {left}s`
		elseif current.Role == "Escort" then
			banner.Text = `Escorting {current.RaiderName}: body-block anyone chasing them - {chaseText(current)}{left}s`
		elseif current.Phase == "Carrying" then
			banner.Text = `Escape! {chaseText(current)}{left}s   ({lootText(current.Loot)})`
		elseif current.Phase == "Unlocked" then
			banner.Text = `Lock open: grab the loot - {left}s`
		else
			banner.Text = `Raiding {current.VictimName}: pick the vault lock - {left}s`
		end
		banner.BackgroundColor3 = if current.Role == "Victim" then Color3.fromRGB(150, 30, 30) else Color3.fromRGB(120, 70, 20)
		banner.Visible = true
		local grip = if current.Phase == "Carrying" then current.Grip else nil
		gripBack.Visible = grip ~= nil
		if grip then
			gripFill.Size = UDim2.fromScale(math.clamp(grip / raidCfg.GripDamage, 0, 1), 1)
		end
	else
		banner.Visible = false
		gripBack.Visible = false
	end

	-- Lockpick dial (raider, before the lock opens, near the vault).
	local lockpick = if current and current.Role == "Raider" then current.Lockpick else nil
	local core = if current and current.Role == "Raider" then victimCore() else nil
	if lockpick and core and lockpick.Picking then
		dial.Visible = true
		turnButton.Visible = true
		cancelPick.Visible = true
		local clock = os.clock()
		local f = feel
		local held = holdingTurn()
		local refitting = clock < lockoutUntil
		-- The lock: towards the server's angle while Turn is held, springing
		-- back as soon as it's let go (visual only; the server decides).
		local target = if held and f and not refitting then f.LockAngle else 0
		if target > shownLock then
			shownLock = math.min(target, shownLock + pickCfg.TurnSpeed * dt)
		else
			shownLock = math.max(target, shownLock - pickCfg.ReturnSpeed * dt)
		end
		-- Stalled: the lock shakes, less the closer the pick is (guide §4).
		-- Computed fresh every frame, never stored (pitfall 3).
		local stalled = held and f ~= nil and f.Stalled and not refitting
		local shake = 0
		if stalled and f then
			local amp = pickUi.ShakeNear + (pickUi.ShakeFar - pickUi.ShakeNear) * (1 - f.Closeness)
			shake = amp * math.sin(clock * pickUi.ShakeHz * 2 * math.pi) + amp * 0.4 * math.noise(clock * 30, 0.5)
		end
		face.Rotation = shownLock + shake
		wrench.Rotation = shownLock + shake
		keyway.Rotation = 0 -- sits in the face, so it turns with it
		-- The pick sits in the turning cylinder, so it turns with the lock.
		pickPivot.Rotation = pickAngle + shownLock + shake * pickUi.PickShakeScale
		pickPivot.Visible = not refitting
		-- Worn picks redden a little (the pick's own damage, not the spot).
		local wear = if f then f.Damage else 0
		local pickColor = Color3.fromRGB(235, 235, 235):Lerp(Color3.fromRGB(220, 90, 70), wear)
		pickArm.BackgroundColor3 = pickColor
		pickTip.BackgroundColor3 = pickColor
		-- The grind, louder and higher as the pick wears.
		if stalled then
			grindSound.Volume = 0.25 + 0.4 * wear
			grindSound.PlaybackSpeed = 0.55 + 0.25 * wear
			if not grindSound.IsPlaying then
				grindSound:Play()
			end
		elseif grindSound.IsPlaying then
			grindSound:Stop()
		end
		-- Studio tuning overlay.
		local debug = f and f.Debug
		for angle, tick in overlayTicks do
			local zone = 0
			if debug then
				local d = math.abs(angle - debug.Center)
				zone = if d <= debug.SweetWidth / 2 then 2 elseif d <= debug.SweetWidth / 2 + debug.PartialWidth then 1 else 0
			end
			tick.Visible = zone > 0
			tick.BackgroundColor3 = if zone == 2 then Color3.fromRGB(70, 230, 110) else Color3.fromRGB(230, 200, 60)
		end
		local picks = if f then f.Picks else lockpick.Picks
		local stageNumber = if f then f.Stage else lockpick.Stage
		local stages = if f then f.Stages else lockpick.Stages
		pinsLabel.Text = if refitting
			then (if picks > 0 then "Pick snapped: fitting another..." else "No picks: improvising...")
			elseif clock < stageFlashUntil then "Pin set!"
			else `Pin {stageNumber}/{stages}   ·   Picks {picks}` .. (if picks <= 0 then "  (improvising: slow)" else "")
	else
		dial.Visible = false
		turnButton.Visible = false
		cancelPick.Visible = false
		shownLock = 0
		if grindSound.IsPlaying then
			grindSound:Stop()
		end
	end

	-- The context button.
	if root and not current and not player:GetAttribute(Config.Base.BuildUi.ClientModeAttribute) and raidablePlotNear(root) then
		actionKind = "Breach"
		actionButton.Text = "Breach"
	elseif current and current.Role == "Raider" and current.Phase == "Unlocked" and core then
		actionKind = "Grab"
		actionButton.Text = "GRAB"
	elseif lockpick and core and not lockpick.Picking then
		actionKind = "Pick"
		actionButton.Text = "Pick lock"
	end
	actionButton.Visible = actionKind ~= ""

	local defense = if current and current.CanSabotage and root then victimDefenseNear(root) else nil
	sabotageButton.Visible = defense ~= nil
	if defense then
		sabotageButton.Text = `Sabotage {defense:GetAttribute("Kind")}`
	end
end)

actionButton.Activated:Connect(function()
	if actionKind == "Breach" then
		ask(Remotes.getFunction("Breach"))
	elseif actionKind == "Pick" then
		if ask(Remotes.getFunction("StartLockpick")) then
			showMessage("Both hands on the lock: you can't move until it opens")
		end
	elseif actionKind == "Grab" then
		local ok, reason = ask(Remotes.getFunction("Grab"))
		if ok and reason == "Empty" then
			showMessage("Their Exposed was empty")
		end
	end
end)

-- ── Lockpick input ──────────────────────────────────────────────────────

-- The pick points at the pointer (polar aim, guide §5): straight up = 0,
-- right = +90, left = -90. Ignored while Turn is held.
local function aimAt(position: Vector2)
	if holdingTurn() then
		return
	end
	local centre = dial.AbsolutePosition + dial.AbsoluteSize / 2
	local offset = position - centre
	if offset.Magnitude < 8 then
		return
	end
	pickAngle = math.clamp(math.deg(math.atan2(offset.X, -offset.Y)), -pickCfg.PickLimit, pickCfg.PickLimit)
end

-- Phone (or mouse click): drag on the dial to point the pick.
dial.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		aimAt(Vector2.new(input.Position.X, input.Position.Y))
	end
end)
dial.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
		local held = input.UserInputType == Enum.UserInputType.Touch or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		if held then
			aimAt(Vector2.new(input.Position.X, input.Position.Y))
		end
	end
end)

-- The TURN button: hold it (thumb or mouse).
local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end
turnButton.InputBegan:Connect(function(input)
	if isPress(input) then
		buttonTurn = true
	end
end)
turnButton.InputEnded:Connect(function(input)
	if isPress(input) then
		buttonTurn = false
	end
end)
UserInputService.InputEnded:Connect(function(input) -- let go off the button
	if isPress(input) then
		buttonTurn = false
	end
end)

local function cancel()
	keyTurn = false
	buttonTurn = false
	ask(Remotes.getFunction("CancelLockpick"))
end
cancelPick.Activated:Connect(cancel)

-- Keys + gamepad, bound only while the dial is up. Sinking them keeps
-- W / D / Space from reaching the character (guide pitfall 10) and the
-- right stick from turning the camera. (Escape is Roblox's own and
-- Backspace drops tools, so cancel is the on-screen button or gamepad B.)
local TURN_KEYS = { Enum.KeyCode.D, Enum.KeyCode.W, Enum.KeyCode.Space, Enum.KeyCode.ButtonR2 }
local turnKeysDown: { [Enum.KeyCode]: boolean } = {}
local bound = false
local function bindLockpickKeys()
	ContextActionService:BindActionAtPriority("LockpickTurn", function(_, inputState, input)
		if inputState == Enum.UserInputState.Begin then
			turnKeysDown[input.KeyCode] = true
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			turnKeysDown[input.KeyCode] = nil
		end
		keyTurn = next(turnKeysDown) ~= nil
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(TURN_KEYS))
	ContextActionService:BindActionAtPriority("LockpickAim", function(_, _, input)
		local stick = Vector2.new(input.Position.X, input.Position.Y)
		if stick.Magnitude >= pickUi.AimDeadzone and not holdingTurn() then
			pickAngle = math.clamp(math.deg(math.atan2(stick.X, stick.Y)), -pickCfg.PickLimit, pickCfg.PickLimit)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Thumbstick2)
	ContextActionService:BindActionAtPriority("LockpickCancel", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			task.spawn(cancel)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
end
local function unbindLockpickKeys()
	ContextActionService:UnbindAction("LockpickTurn")
	ContextActionService:UnbindAction("LockpickAim")
	ContextActionService:UnbindAction("LockpickCancel")
	table.clear(turnKeysDown)
	keyTurn = false
end

local function usingGamepadOrTouch(): boolean
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Touch or string.sub(last.Name, 1, 7) == "Gamepad"
end

-- Send (angle, holding Turn) when either changes, at most InputSendSeconds
-- apart; the server does everything else.
local sentAngle: number? = nil
local sentTurn = false
local lastSend = 0
local lastScrapeAngle = 0
local lastScrape = 0
RunService.RenderStepped:Connect(function()
	if not dial.Visible then
		if bound then
			bound = false
			unbindLockpickKeys()
		end
		buttonTurn = false
		sentAngle = nil
		sentTurn = false
		return
	end
	if not bound then
		bound = true
		bindLockpickKeys()
	end
	-- PC: the pick follows the mouse, no clicking needed.
	if UserInputService.MouseEnabled and not usingGamepadOrTouch() then
		aimAt(UserInputService:GetMouseLocation() - GuiService:GetGuiInset())
	end
	local now = os.clock()
	local held = holdingTurn()
	-- A scrape as the pick moves (throttled), a click as Turn goes on.
	if not held and math.abs(pickAngle - lastScrapeAngle) > 1.5 and now - lastScrape >= pickUi.ScrapeSeconds then
		lastScrape = now
		lastScrapeAngle = pickAngle
		playSound(pickUi.Sounds.Scrape, 0.15, 1.4)
	end
	if held and not sentTurn then
		playSound(pickUi.Sounds.TurnStart, 0.4, 0.8)
	end
	local changed = held ~= sentTurn or sentAngle == nil or math.abs(pickAngle - (sentAngle :: number)) > 0.2
	if changed and now - lastSend >= pickCfg.InputSendSeconds then
		lastSend = now
		sentAngle = pickAngle
		sentTurn = held
		Remotes.getEvent("LockpickInput"):FireServer(pickAngle, held)
	end
end)

Remotes.getEvent("LockpickFeel").OnClientEvent:Connect(function(update: Types.LockpickFeel)
	feel = update
	lockoutUntil = os.clock() + update.Lockout
	if update.Event == "broke" then
		playSound(pickUi.Sounds.Snap, 0.8, 1.8)
	elseif update.Event == "solved" then
		stageFlashUntil = os.clock() + pickUi.StageFlashSeconds
		playSound(pickUi.Sounds.Stage, 0.8, 0.6)
	elseif update.Event == "open" then
		playSound(pickUi.Sounds.Open, 0.9, 1)
	end
end)

sabotageButton.Activated:Connect(function()
	local root = myRoot()
	local defense = root and victimDefenseNear(root)
	if defense and ask(Remotes.getFunction("Sabotage"), defense) then
		showMessage("Defense knocked offline")
	end
end)

-- ── Server state + escort offers ─────────────────────────────────────────

Remotes.getEvent("RaidState").OnClientEvent:Connect(function(view: Types.RaidView?)
	state = view
end)

local offerId: string? = nil
local offerToken = 0
Remotes.getEvent("EscortOffer").OnClientEvent:Connect(function(raidId: string, raiderName: string, seconds: number)
	offerToken += 1
	local token = offerToken
	offerId = raidId
	offer.Text = `{raiderName} is raiding: join as escort?`
	offer.Visible = true
	task.delay(seconds, function()
		if offerToken == token then
			offer.Visible = false
			offerId = nil
		end
	end)
end)
offer.Activated:Connect(function()
	local raidId = offerId
	offer.Visible = false
	offerId = nil
	if raidId and ask(Remotes.getFunction("JoinEscort"), raidId) then
		showMessage("You're escorting: stay close and block chasers")
	end
end)

-- ── Raid log + path map (D105) ───────────────────────────────────────────

-- The map shows this many studs across, centred on the victim's plot.
local MAP_STUDS = Config.Plots.SizeStuds * raidCfg.Ui.MapStudsScale

local function dot(x: number, z: number, color: Color3, size: number, text: string?)
	local scale = map.AbsoluteSize.X / MAP_STUDS
	local d = Instance.new("TextLabel")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.fromOffset(map.AbsoluteSize.X / 2 + x * scale, map.AbsoluteSize.Y / 2 + z * scale)
	d.Size = UDim2.fromOffset(size, size)
	d.BackgroundColor3 = color
	d.BorderSizePixel = 0
	d.Text = text or ""
	d.TextColor3 = Color3.new(1, 1, 1)
	d.TextSize = 10
	d.Font = Enum.Font.GothamBold
	d.Parent = map
end

local function drawMap(entry: Types.RaidLogEntry)
	map:ClearAllChildren()
	-- The plot square.
	local scale = map.AbsoluteSize.X / MAP_STUDS
	local plotFrame = Instance.new("Frame")
	plotFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	plotFrame.Position = UDim2.fromScale(0.5, 0.5)
	plotFrame.Size = UDim2.fromOffset(Config.Plots.SizeStuds * scale, Config.Plots.SizeStuds * scale)
	plotFrame.BackgroundColor3 = Color3.fromRGB(70, 90, 60)
	plotFrame.BorderSizePixel = 0
	plotFrame.Parent = map
	for i, point in entry.Path do
		local fade = i / math.max(1, #entry.Path)
		dot(point[1] - raidCfg.LogCoordOffset, point[2] - raidCfg.LogCoordOffset, Color3.fromRGB(255, math.floor(220 - 150 * fade), 60), 4, nil)
	end
	for _, trigger in entry.Triggers do
		local kind = tostring(trigger[3] or "?")
		dot(trigger[1] - raidCfg.LogCoordOffset, trigger[2] - raidCfg.LogCoordOffset, Color3.fromRGB(200, 40, 40), 14, kind:sub(1, 1))
	end
end

local function refreshLog()
	for _, child in logList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local ok, entries = pcall(function()
		return Remotes.getFunction("GetRaidLog"):InvokeServer()
	end)
	if not ok or not entries then
		return
	end
	if #entries == 0 then
		map:ClearAllChildren()
	end
	for i, entry: Types.RaidLogEntry in entries do
		local b = Instance.new("TextButton")
		b.LayoutOrder = i
		b.Size = UDim2.new(1, -8, 0, 54)
		local asRaider = entry.AsRaider == true
		b.BackgroundColor3 = if asRaider
			then (if entry.Outcome == "Stolen" then Color3.fromRGB(120, 95, 30) else Color3.fromRGB(70, 70, 80))
			else (if entry.Outcome == "Stolen" then Color3.fromRGB(110, 40, 40) else Color3.fromRGB(40, 90, 50))
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.Gotham
		b.TextSize = 13
		b.TextWrapped = true
		b.TextXAlignment = Enum.TextXAlignment.Left
		local minutes = math.floor((os.time() - entry.At) / 60)
		local taken = {}
		for key, amount in entry.Taken do
			table.insert(taken, `{amount} {key}`)
		end
		local what = if #taken > 0 then table.concat(taken, ", ") else "nothing"
		b.Text = if asRaider
			then `  You raided {entry.VictimName or "?"}{if entry.Offline then " (offline)" else ""} - {minutes} min ago\n  {if entry.Outcome == "Stolen" then "Got: " .. what else "Failed: " .. (entry.Note or "no loot")}`
			else `  {entry.RaiderName}{if entry.Offline then " (while you were away)" else ""} - {minutes} min ago\n  {if entry.Outcome == "Stolen" then "Took: " .. what else "Loot recovered" .. (if entry.Note then ` ({entry.Note})` else "")}`
		b.Parent = logList
		b.Activated:Connect(function()
			drawMap(entry)
		end)
		if i == 1 then
			task.defer(drawMap, entry)
		end
	end
end

logButton.Activated:Connect(function()
	logPanel.Visible = not logPanel.Visible
	if logPanel.Visible then
		refreshLog()
	end
end)
closeLog.Activated:Connect(function()
	logPanel.Visible = false
end)

local function applyLogVisibility()
	logButton.Visible = player:GetAttribute(raidCfg.Ui.RaidLogVisibleAttribute) == true
end
player:GetAttributeChangedSignal(raidCfg.Ui.RaidLogVisibleAttribute):Connect(applyLogVisibility)
applyLogVisibility()
