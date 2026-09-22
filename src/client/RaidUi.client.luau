--!strict
-- Raid UI (step 7): context buttons, the lockpick bar, the raid timer, the
-- escort offer and the raid log with its path map.
-- 02-core-loop.md § Raiding, § Lockpick skill model, § The Chase, § Raid
-- escort (D101), § Raid log path map (D105).
--
-- Display + intents only. The server picks the target base, times the
-- lockpick itself, and decides every outcome (R5). The lockpick bar here is
-- a picture of the server's bar (same start time + speed), drawn with
-- workspace:GetServerTimeNow() so it lines up.

local CollectionService = game:GetService("CollectionService")
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
	Locked = "That base was raided recently (shielded)",
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
local message = label(UDim2.fromOffset(360, 30), UDim2.new(0.5, 0, 0.62, 0), 16)

-- Lockpick dial (Skyrim-style, Josh's call): turn the pick with A/D or by
-- dragging, hold TURN. The lock only moves near the pin's secret angle.
local dial = Instance.new("Frame")
dial.AnchorPoint = Vector2.new(0.5, 1)
dial.Position = UDim2.new(0.5, 0, 1, -SIZE * 1.6)
dial.Size = UDim2.fromOffset(190, 190)
dial.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
dial.BackgroundTransparency = 0.15
dial.Visible = false
dial.Parent = gui
local dialRound = Instance.new("UICorner")
dialRound.CornerRadius = UDim.new(1, 0)
dialRound.Parent = dial

-- The lock face turns as the pin gives.
local face = Instance.new("Frame")
face.AnchorPoint = Vector2.new(0.5, 0.5)
face.Position = UDim2.fromScale(0.5, 0.5)
face.Size = UDim2.fromOffset(120, 120)
face.BackgroundColor3 = Color3.fromRGB(90, 90, 105)
face.Parent = dial
local faceRound = Instance.new("UICorner")
faceRound.CornerRadius = UDim.new(1, 0)
faceRound.Parent = face
local keyway = Instance.new("Frame") -- the slot, shows the face turning
keyway.AnchorPoint = Vector2.new(0.5, 0.5)
keyway.Position = UDim2.fromScale(0.5, 0.5)
keyway.Size = UDim2.fromOffset(14, 86)
keyway.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
keyway.Parent = face

-- The tension wrench sits in the keyway and turns with the lock.
local wrench = Instance.new("Frame")
wrench.AnchorPoint = Vector2.new(0.5, 0.5)
wrench.Position = UDim2.fromScale(0.5, 0.5)
wrench.Size = UDim2.fromOffset(10, 54)
wrench.BackgroundColor3 = Color3.fromRGB(120, 120, 140)
wrench.ZIndex = 2
wrench.Parent = dial

-- The pick: anchored in the keyhole (dial centre), sweeping left to right
-- like Skyrim's. Its tip is the end that touches the pin.
local pickArm = Instance.new("Frame")
pickArm.AnchorPoint = Vector2.new(0.5, 1)
pickArm.Position = UDim2.fromScale(0.5, 0.5)
pickArm.Size = UDim2.fromOffset(5, 92)
pickArm.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
pickArm.ZIndex = 3
pickArm.Parent = dial
local pickTip = Instance.new("Frame")
pickTip.AnchorPoint = Vector2.new(0.5, 0)
pickTip.Position = UDim2.fromScale(0.5, 0)
pickTip.Size = UDim2.fromOffset(12, 10)
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

local turnButton = button("TURN", Color3.fromRGB(60, 150, 80))
turnButton.AnchorPoint = Vector2.new(0.5, 1)
turnButton.Position = UDim2.new(0.5, 0, 1, -SIZE * 0.5)
turnButton.Size = UDim2.fromOffset(SIZE * 2.4, SIZE * 0.9)

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
	task.delay(2, function()
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

-- Pick angle (0..1 across the dial) and whether TURN is held.
local pickAngle = 0.5
local holdingTurn = false
local ANGLE_KEY_SPEED = 0.6 -- [PH] invented: A/D sweep, dial widths per second
local TURN_SEND_SECONDS = 0.1 -- [PH] invented: how often a held turn is sent

local function lootText(loot: { [string]: number }?): string
	if not loot then
		return ""
	end
	local parts = {}
	for _, key in { "Stone", "Ore", "Riftsalt", "Scrap" } do
		if (loot[key] or 0) > 0 then
			table.insert(parts, `{loot[key]} {key}`)
		end
	end
	return table.concat(parts, ", ")
end

local actionKind = "" -- what actionButton does right now

RunService.RenderStepped:Connect(function()
	local root = myRoot()
	local current = state
	local t = workspace:GetServerTimeNow()
	actionKind = ""

	if current then
		local left = math.max(0, math.ceil(current.EndsAt - t))
		if current.Role == "Victim" then
			banner.Text = if current.Phase == "Carrying"
				then `{current.RaiderName} has your loot ({lootText(current.Loot)})! Hit them before they escape - {left}s`
				else `RAID! {current.RaiderName} is at your base - {left}s`
		elseif current.Role == "Escort" then
			banner.Text = `Escorting {current.RaiderName}: body-block anyone chasing them - {left}s`
		elseif current.Phase == "Carrying" then
			banner.Text = `Escape! Get off their plot and bridge - {left}s   ({lootText(current.Loot)})`
		elseif current.Phase == "Unlocked" then
			banner.Text = `Lock open: grab the loot - {left}s`
		else
			banner.Text = `Raiding {current.VictimName}: pick the vault lock - {left}s`
		end
		banner.BackgroundColor3 = if current.Role == "Victim" then Color3.fromRGB(150, 30, 30) else Color3.fromRGB(120, 70, 20)
		banner.Visible = true
	else
		banner.Visible = false
	end

	-- Lockpick dial (raider, before the lock opens, near the vault).
	local lockpick = if current and current.Role == "Raider" then current.Lockpick else nil
	local core = if current and current.Role == "Raider" then victimCore() else nil
	if lockpick and core then
		dial.Visible = true
		turnButton.Visible = true
		-- Angle 0..1 maps across a half turn; the pick points that way.
		local stuck = holdingTurn and lockpick.Warmth <= 0
		-- The pick pivots in the keyhole; A/D (or a drag) sweeps it, and it
		-- judders when the lock won't give.
		pickArm.Rotation = -90 + pickAngle * 180 + (if stuck then math.random(-2, 2) else 0)
		local warmColor = Color3.fromRGB(200, 200, 200):Lerp(Color3.fromRGB(70, 230, 110), lockpick.Warmth)
		pickArm.BackgroundColor3 = warmColor
		pickTip.BackgroundColor3 = warmColor
		-- The lock (and the wrench in it) turns as the pin gives.
		face.Rotation = lockpick.Progress * 80
		wrench.Rotation = face.Rotation
		keyway.Rotation = 0
		pinsLabel.Text = `Pins {lockpick.PinsDone}/{lockpick.Pins}` .. (if stuck then "   (stuck: move the pick)" else "")
	else
		dial.Visible = false
		turnButton.Visible = false
	end

	-- The context button.
	if root and not current and not player:GetAttribute(Config.Base.BuildUi.ClientModeAttribute) and raidablePlotNear(root) then
		actionKind = "Breach"
		actionButton.Text = "Breach"
	elseif current and current.Role == "Raider" and current.Phase == "Unlocked" and core then
		actionKind = "Grab"
		actionButton.Text = "GRAB"
	elseif current and current.Role == "Raider" and current.Phase == "Breached" and not core then
		actionKind = "" -- walk to the vault: the banner says so
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
	elseif actionKind == "Grab" then
		local ok, reason = ask(Remotes.getFunction("Grab"))
		if ok and reason == "Empty" then
			showMessage("Their Exposed was empty")
		end
	end
end)

-- ── Lockpick input ──────────────────────────────────────────────────────

-- Drag anywhere on the dial (phone or mouse) to point the pick.
local function aimAt(position: Vector2)
	local centre = dial.AbsolutePosition + dial.AbsoluteSize / 2
	local offset = position - centre
	if offset.Magnitude < 8 then
		return
	end
	-- Straight up = 0.5; right = 1, left = 0.
	local degrees = math.deg(math.atan2(offset.X, -offset.Y))
	pickAngle = math.clamp(0.5 + degrees / 180, 0, 1)
end

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

-- Hold TURN (mouse or thumb). PC also turns the pick with A and D.
turnButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		holdingTurn = true
	end
end)
local function stopTurning(input: InputObject)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		holdingTurn = false
	end
end
turnButton.InputEnded:Connect(stopTurning)
UserInputService.InputEnded:Connect(stopTurning)

local turning = false
local lastTurnSent = 0
RunService.RenderStepped:Connect(function(dt)
	if not dial.Visible then
		holdingTurn = false
		return
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		pickAngle = math.clamp(pickAngle - ANGLE_KEY_SPEED * dt, 0, 1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		pickAngle = math.clamp(pickAngle + ANGLE_KEY_SPEED * dt, 0, 1)
	end
	-- While TURN is held, stream the angle; the server does the timing.
	local now = os.clock()
	if holdingTurn and not turning and now - lastTurnSent >= TURN_SEND_SECONDS then
		lastTurnSent = now
		turning = true
		task.spawn(function()
			pcall(function()
				Remotes.getFunction("LockpickTurn"):InvokeServer(pickAngle)
			end)
			turning = false
		end)
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
local MAP_STUDS = Config.Plots.SizeStuds * 1.8

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
		dot(point[1], point[2], Color3.fromRGB(255, math.floor(220 - 150 * fade), 60), 4, nil)
	end
	for _, trigger in entry.Triggers do
		local kind = tostring(trigger[3] or "?")
		dot(trigger[1], trigger[2], Color3.fromRGB(200, 40, 40), 14, kind:sub(1, 1))
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
		b.BackgroundColor3 = if entry.Outcome == "Stolen" then Color3.fromRGB(110, 40, 40) else Color3.fromRGB(40, 90, 50)
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
		b.Text = `  {entry.RaiderName}{if entry.Offline then " (while you were away)" else ""} - {minutes} min ago\n  {if entry.Outcome == "Stolen" then "Took: " .. (if #taken > 0 then table.concat(taken, ", ") else "nothing") else "Loot recovered"}`
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
