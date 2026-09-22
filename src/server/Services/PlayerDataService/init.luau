--!strict
-- PlayerDataService: the ONLY code that touches player profiles.
--
-- * Profiles live in ProfileStore, which session-locks them: only one server
--   can hold a player's profile at a time, the main defence against item
--   duplication (13-build-guide.md § Part D, Player data).
-- * R5: the server is the only authority. Other services never get the live
--   profile table. They read deep copies with get(), and write through
--   update(), which checks that the caller owns that section
--   (Config.Data.SectionOwners) and validates the result before saving it.
-- * Small fields are bitpacked (D80): use getPacked / setPacked.
-- * Plot archiving (D55) is a stub: see PlotArchive.luau.
-- * Offline raids (13-build-guide.md § Part D, step 7): other servers can
--   read a READ-ONLY view of an offline profile (viewAsync) and send it a
--   message (messageAsync). On login, a load gate waits out any raid in
--   progress and messages are applied BEFORE the profile counts as loaded,
--   so nothing can act on resources a raid already took.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.PlayerDataTypes)
local LevelCurve = require(ReplicatedStorage.Shared.LevelCurve)
local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
local BitPack = require(ServerScriptService.Util.BitPack)
local Clock = require(ServerScriptService.Util.Clock)
local Backoff = require(ServerScriptService.Util.Backoff)
local Migrations = require(script.Migrations)
local PlotArchive = require(script.PlotArchive)
local Template = require(script.Template)

local dataCfg = Config.Data

local LOAD_FAILED_MESSAGE = "Couldn't load your save. Please rejoin in a minute."
local SESSION_ENDED_MESSAGE = "Your save was opened on another server. Please rejoin."
local OUTDATED_MESSAGE = "This server is out of date. Please rejoin to get a new one."

local PlayerDataService = {}

-- ── Bitpack layouts (D80) ─────────────────────────────────────────────────

local packedLayouts: { [string]: BitPack.Layout } = {} -- word -> field -> slot
local packedWordOf: { [string]: string } = {} -- field -> word
-- Config.Data.Packed is a record (Reputation, Progress...); view it as a map to loop over it.
local packedConfig: { [string]: { BitPack.Field } } = dataCfg.Packed :: any
for word, fields in packedConfig do
	packedLayouts[word] = BitPack.layout(fields)
	for _, field in fields do
		assert(packedWordOf[field.Name] == nil, `Packed field {field.Name} is defined twice in Config.Data.Packed`)
		packedWordOf[field.Name] = word
	end
end

-- ── State ─────────────────────────────────────────────────────────────────

local storeName = if RunService:IsStudio() then dataCfg.StudioStoreName else dataCfg.StoreName
local store = ProfileStore.New(storeName, Template)
local profiles: { [Player]: any } = {}
local loadedEvent = Instance.new("BindableEvent")

-- Fires (player) once their profile is loaded and safe to use.
PlayerDataService.Loaded = loadedEvent.Event

-- ── Helpers ───────────────────────────────────────────────────────────────

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Returns an error message if `value` can't or shouldn't be saved.
-- Enforces ProfileStore's plain-data rules, and that no stored number is
-- negative, NaN or infinite: every quantity in a profile (counts, tiers,
-- times, XP) is >= 0, so a negative one is always a bug or an exploit.
local function validate(value: any, path: string): string?
	local kind = typeof(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return `{path} is not a finite number`
		elseif value < 0 then
			return `{path} is negative ({value})`
		end
		return nil
	elseif kind == "string" or kind == "boolean" then
		return nil
	elseif kind == "table" then
		local numericCount, maxIndex, hasStringKey = 0, 0, false
		for key, child in value do
			if type(key) == "number" then
				if key < 1 or key ~= math.floor(key) then
					return `{path} has a bad array index {key}`
				end
				numericCount += 1
				maxIndex = math.max(maxIndex, key)
			elseif type(key) == "string" then
				hasStringKey = true
			else
				return `{path} has a {typeof(key)} key`
			end
			local problem = validate(child, `{path}.{tostring(key)}`)
			if problem then
				return problem
			end
		end
		if numericCount > 0 and hasStringKey then
			return `{path} mixes array and string keys`
		elseif numericCount ~= maxIndex then
			return `{path} is an array with gaps`
		end
		return nil
	end
	return `{path} holds a {kind}; only numbers, strings, booleans and tables can be saved`
end

local function activeProfile(player: Player): any?
	local profile = profiles[player]
	if profile and profile:IsActive() then
		return profile
	end
	return nil
end

-- Copy the section, let `mutate` change the copy, validate, then swap it in.
-- Either the whole change lands or none of it does.
local function applyUpdateTo(profile: any, player: Player, section: Types.SectionName, mutate: (any) -> any, who: string): boolean

	local ok, result = pcall(mutate, deepCopy(profile.Data[section]))
	if not ok then
		warn(`[PlayerData] {who} update of {section} for {player.Name} threw: {result}`)
		return false
	end
	local problem = validate(result, section)
	if problem then
		warn(`[PlayerData] rejected {who} update for {player.Name} ({player.UserId}): {problem}`)
		return false
	end
	-- `mutate` could have yielded; make sure it's still the same live session.
	if not profile:IsActive() then
		warn(`[PlayerData] {who} update of {section} for {player.Name} dropped: session ended mid-update`)
		return false
	end
	profile.Data[section] = result
	return true
end

local function applyUpdate(player: Player, section: Types.SectionName, mutate: (any) -> any, who: string): boolean
	local profile = activeProfile(player)
	if not profile then
		warn(`[PlayerData] {who} tried to update {section} for {player.Name}, but no profile is loaded`)
		return false
	end
	local ok = applyUpdateTo(profile, player, section, mutate, who)
	if ok and profiles[player] ~= profile then
		return false -- the session changed under us (shouldn't happen: mutate can't yield usefully)
	end
	return ok
end

-- ── Offline access + messages (step 7) ───────────────────────────────────

export type Update = (section: Types.SectionName, owner: string, mutate: (any) -> any) -> boolean
export type MessageHandler = (player: Player, message: { [string]: any }, update: Update) -> boolean

local messageHandlers: { [string]: MessageHandler } = {}
local beforeRelease: ((player: Player) -> ())? = nil

-- Called when a player leaves, while their profile is STILL live (before
-- the session ends). Must not yield. RaidService settles a Chase on a
-- leaving victim here (review H1).
function PlayerDataService.setBeforeRelease(fn: (player: Player) -> ())
	beforeRelease = fn
end
local loadGate: ((userId: number) -> ())? = nil

-- Called on every login before the profile counts as loaded; may yield.
-- RaidService uses it to wait out a raid in progress.
function PlayerDataService.setLoadGate(fn: (userId: number) -> ())
	loadGate = fn
end

-- Handles profile messages whose Kind is `kind`. The handler gets an
-- `update` that works before the profile is loaded (same owner rules as
-- update()). Return true once the message is applied or safely ignored;
-- false leaves it to be retried on the next login.
function PlayerDataService.onMessage(kind: string, handler: MessageHandler)
	messageHandlers[kind] = handler
end

local function dispatchMessage(player: Player, profile: any, message: any, processed: () -> ())
	local kind = type(message) == "table" and message.Kind
	local handler = kind and messageHandlers[kind]
	if not handler then
		warn(`[PlayerData] {player.Name} has a message nobody handles ({tostring(kind)}); left for later`)
		return
	end
	local update: Update = function(section, owner, mutate)
		local expected = dataCfg.SectionOwners[section]
		assert(owner == expected, `{owner} tried to write "{section}", which only {expected} may change`)
		return applyUpdateTo(profile, player, section, mutate, owner)
	end
	local ok, done = pcall(handler, player, message, update)
	if not ok then
		warn(`[PlayerData] message {kind} for {player.Name} failed: {done}`)
	elseif done then
		processed()
	end
end

-- A read-only copy of an OFFLINE player's last saved data, plus whether some
-- server still holds their session (then the save may be stale). Yields.
-- Returns nil if it couldn't be read.
function PlayerDataService.viewAsync(userId: number): (Types.ProfileData?, boolean)
	local ok, profile = Backoff.retry(`profile view {userId}`, function()
		return store:GetAsync(dataCfg.KeyPrefix .. userId)
	end)
	if not ok or profile == nil then
		return nil, false
	end
	local view: any = profile
	local data = deepCopy(view.Data)
	if not Migrations.run(data, dataCfg.SchemaVersion) then
		return nil, false
	end
	return data, view.Session ~= nil
end

-- Sends a message to a player's profile (applied on their next login, or
-- soon if online elsewhere). Yields. True only if it was stored.
function PlayerDataService.messageAsync(userId: number, message: { [string]: any }): boolean
	local ok, sent = Backoff.retry(`profile message {userId}`, function()
		return store:MessageAsync(dataCfg.KeyPrefix .. userId, message)
	end)
	return ok and sent == true
end

-- ── Public API ────────────────────────────────────────────────────────────

function PlayerDataService.isLoaded(player: Player): boolean
	return activeProfile(player) ~= nil
end

-- A deep copy of one section (changing it changes nothing), or nil if the
-- player's profile isn't loaded.
function PlayerDataService.get(player: Player, section: Types.SectionName): any
	local profile = activeProfile(player)
	return if profile then deepCopy(profile.Data[section]) else nil
end

-- The only way to write a section. `owner` must be the service named in
-- Config.Data.SectionOwners. `mutate` receives a copy of the section and must
-- RETURN the new value (this also works for plain numbers like Credits).
-- Returns true if the change was saved into the profile.
function PlayerDataService.update(
	player: Player,
	section: Types.SectionName,
	owner: string,
	mutate: (current: any) -> any
): boolean
	local expected = dataCfg.SectionOwners[section]
	if expected == nil then
		error(`unknown profile section "{section}"`, 2)
	elseif owner ~= expected then
		error(`{owner} tried to write "{section}", which only {expected} may change`, 2)
	end
	return applyUpdate(player, section, mutate, owner)
end

-- Bitpacked fields (D80). `field` is a Name from Config.Data.Packed.
function PlayerDataService.getPacked(player: Player, field: string): number?
	local word = packedWordOf[field]
	assert(word, `unknown packed field "{field}"`)
	local profile = activeProfile(player)
	if not profile then
		return nil
	end
	return BitPack.get(profile.Data.Packed[word], packedLayouts[word][field])
end

local function writePacked(player: Player, field: string, value: number, who: string): boolean
	local word = packedWordOf[field]
	local slot = packedLayouts[word][field]
	local profile = activeProfile(player)
	if not profile then
		warn(`[PlayerData] {who} tried to set {field} for {player.Name}, but no profile is loaded`)
		return false
	end
	local newWord, clamped = BitPack.set(profile.Data.Packed[word], slot, value)
	if clamped then
		-- Anomaly log: either a real value outgrew its bit width (widen it with
		-- a migration) or something computed a bad value.
		warn(`[PlayerData] {field} for {player.Name} clamped: {value} is outside 0..{slot.Max}`)
	end
	profile.Data.Packed[word] = newWord
	return true
end

function PlayerDataService.setPacked(player: Player, field: string, owner: string, value: number): boolean
	local word = packedWordOf[field]
	if word == nil then
		error(`unknown packed field "{field}"`, 2)
	end
	local expected = packedLayouts[word][field].Owner
	if owner ~= expected then
		error(`{owner} tried to write packed field "{field}", which only {expected} may change`, 2)
	end
	return writePacked(player, field, value, owner)
end

-- ── Studio-only debug access ──────────────────────────────────────────────

-- Lets DebugService change any section in Studio (it owns none of them).
function PlayerDataService.debugUpdate(player: Player, section: Types.SectionName, mutate: (any) -> any): boolean
	assert(RunService:IsStudio(), "debugUpdate is Studio-only")
	return applyUpdate(player, section, mutate, "Studio debug")
end

local function describe(value: any, indent: string, lines: { string }, label: string)
	if type(value) ~= "table" then
		table.insert(lines, `{indent}{label} = {tostring(value)}`)
		return
	end
	local keys = {}
	for key in value do
		table.insert(keys, key)
	end
	if #keys == 0 then
		table.insert(lines, `{indent}{label} = {"{}"}`)
		return
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	table.insert(lines, `{indent}{label}:`)
	for _, key in keys do
		describe(value[key], indent .. "  ", lines, tostring(key))
	end
end

-- Lets DebugService set any bitpacked field in Studio.
function PlayerDataService.debugSetPacked(player: Player, field: string, value: number): boolean
	assert(RunService:IsStudio(), "debugSetPacked is Studio-only")
	assert(packedWordOf[field], `unknown packed field "{field}"`)
	return writePacked(player, field, value, "Studio debug")
end

-- A readable dump of a player's profile, with bitpacked fields decoded.
function PlayerDataService.debugDescribe(player: Player): string
	assert(RunService:IsStudio(), "debugDescribe is Studio-only")
	local profile = activeProfile(player)
	if not profile then
		return `[PlayerData] {player.Name}: no profile loaded`
	end
	local now = Clock.now()
	local lines = {
		`[PlayerData] profile of {player.Name} ({player.UserId}), key {profile.Key}`,
		`  session #{profile.SessionLoadCount}, clock offset {Clock.getOffset()} s`,
		`  plot stale for archiving (D55): {PlotArchive.isStale(profile.Data.Meta.LastActiveAt, now)}`,
	}
	describe(profile.Data, "  ", lines, "Data")
	table.insert(lines, "  Packed fields (decoded):")
	local decoded: { [string]: number } = {}
	for field, word in packedWordOf do
		decoded[field] = BitPack.get(profile.Data.Packed[word], packedLayouts[word][field])
		table.insert(lines, `    {field} = {decoded[field]}`)
	end
	local miner, trader, raider = decoded.MinerXP or 0, decoded.TraderXP or 0, decoded.RaiderXP or 0
	table.insert(
		lines,
		`  Levels (derived, D82): Miner {LevelCurve.trackLevel(miner)}, Trader {LevelCurve.trackLevel(trader)}, Raider {LevelCurve.trackLevel(raider)} -> Level {LevelCurve.playerLevel(miner, trader, raider)}`
	)
	return table.concat(lines, "\n")
end

-- ── Session lifecycle ─────────────────────────────────────────────────────

local function onPlayerAdded(player: Player)
	local key = dataCfg.KeyPrefix .. player.UserId
	-- Cancel stops ProfileStore retrying if the player leaves while we wait
	-- for another server's session lock to clear. (Its type omits Cancel.)
	local params: any = {
		Cancel = function()
			return player.Parent ~= Players
		end,
	}
	local profile: any = store:StartSessionAsync(key, params)
	if profile == nil then
		if player.Parent == Players then
			warn(`[PlayerData] couldn't start a session for {player.Name} ({key})`)
			player:Kick(LOAD_FAILED_MESSAGE)
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR association

	-- Migrate a copy; only swap it in if every step succeeded.
	local migrated = deepCopy(profile.Data)
	local ok, reason = Migrations.run(migrated, dataCfg.SchemaVersion)
	if not ok then
		warn(`[PlayerData] {player.Name}'s profile can't be loaded: {reason}`)
		profile:EndSession()
		if player.Parent == Players then
			player:Kick(OUTDATED_MESSAGE)
		end
		return
	end
	profile.Data = migrated
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick(SESSION_ENDED_MESSAGE)
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession() -- they left while we were loading
		return
	end

	local data = profile.Data
	local now = Clock.now()
	local isNew = data.Meta.FirstLoginAt == 0
	if isNew then
		data.Meta.FirstLoginAt = now -- also starts the 48-hour new-account shield (R6)
	end
	if PlotArchive.isStale(data.Meta.LastActiveAt, now) then
		print(`[PlayerData] {player.Name} was away past the archive age (D55); archiving is a stub, nothing to restore`)
	end
	PlotArchive.restoreIfArchived(data)
	data.Meta.LastActiveAt = now

	profile.OnSave:Connect(function()
		if profile:IsActive() then
			profile.Data.Meta.LastActiveAt = Clock.now()
		end
	end)

	-- Offline raids (13 § Part D, step 4): wait out a raid in progress, then
	-- apply pending messages (thefts) BEFORE anything can act on this profile.
	if loadGate then
		loadGate(player.UserId)
	end
	if player.Parent ~= Players or not profile:IsActive() then
		if profile:IsActive() then
			profile:EndSession()
		end
		return
	end
	profile:MessageHandler(function(message, processed)
		dispatchMessage(player, profile, message, processed)
	end)

	profiles[player] = profile
	print(`[PlayerData] loaded {player.Name} ({if isNew then "new player" else "returning"}, session #{profile.SessionLoadCount})`)
	loadedEvent:Fire(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	local hook = beforeRelease
	if profile and hook and profile:IsActive() then
		local ok, err = pcall(function(): any
			hook(player)
			return nil
		end)
		if not ok then
			warn(`[PlayerData] before-release hook failed for {player.Name}: {err}`)
		end
	end
	if profile then
		if profile:IsActive() then
			profile.Data.Meta.LastActiveAt = Clock.now()
		end
		profile:EndSession() -- saves and releases the session lock
	end
end

function PlayerDataService.start()
	assert(RunService:IsServer(), "PlayerDataService.start() may only run on the server")
	print(`[PlayerData] using DataStore "{storeName}"`)
	if RunService:IsStudio() then
		BitPack.selfTest()
		-- Check the curve up to the highest level a track's XP bit width allows.
		local xpSlot = packedLayouts[packedWordOf.MinerXP].MinerXP
		LevelCurve.selfTest(LevelCurve.trackLevel(xpSlot.Max))
	end

	ProfileStore.OnError:Connect(function(message, storeName, profileKey)
		warn(`[PlayerData] ProfileStore error ({storeName} / {profileKey}): {message}`)
	end)
	ProfileStore.OnCriticalToggle:Connect(function(isCritical)
		warn(`[PlayerData] ProfileStore critical state: {isCritical}`)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player) -- anyone who joined before we started
	end
	-- ProfileStore saves every profile itself when the server shuts down.
end

return PlayerDataService
