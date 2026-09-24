--!strict
-- CosmeticService: pickaxe skins. The only service that writes the
-- Cosmetics section (Config.Data.SectionOwners).
--
-- Docs: 05-items.md § Pickaxes are not tradeable (D111: skins are the
-- tradeable product), § Cosmetics; 04-world-content.md § The PvE ladder
-- (Captain pickaxe skin, v5.8); 01-pillars.md R1 (never lootable).
-- * Owned skins are counts, so a duplicate is a spare (Josh's call,
--   2026-09-22) that direct trading (step 9) can move.
-- * Nothing ever takes a skin away: raids and death can't touch this (R1).
-- * A skin is a template model in ServerStorage.PickaxeSkins with a Handle
--   part + a Visual folder. CombatService builds the pickaxe from it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local AnomalyLog = require(ServerScriptService.Util.AnomalyLog)
local PlayerDataService = require(script.Parent.PlayerDataService)

local OWNER = "CosmeticService"
local cosmeticCfg = Config.Cosmetics
local skinCfgs: { [string]: { Name: string } } = cosmeticCfg.PickaxeSkins :: any

type CosmeticsData = { PickaxeSkins: { [string]: number }, EquippedPickaxeSkin: string }

local templates: { [string]: Model } = {}
local changedEvent = Instance.new("BindableEvent")
local logAnomaly = AnomalyLog.new("Cosmetic")

local CosmeticService = {}

-- Fires (player) after their skins or equipped skin change.
CosmeticService.Changed = changedEvent.Event

function CosmeticService.get(player: Player): CosmeticsData?
	return PlayerDataService.get(player, "Cosmetics")
end

-- The template for the player's equipped skin, or nil for the plain pickaxe.
-- Also nil if they no longer own it or the template is gone (never errors).
function CosmeticService.equippedTemplate(player: Player): Model?
	local data = CosmeticService.get(player)
	if not data or data.EquippedPickaxeSkin == "" then
		return nil
	end
	local skinId = data.EquippedPickaxeSkin
	if (data.PickaxeSkins[skinId] or 0) <= 0 then
		return nil
	end
	return templates[skinId]
end

-- Gives one skin (Captain drop, FTUE reward in step 14, ...).
function CosmeticService.grantSkin(player: Player, skinId: string, amount: number?): boolean
	assert(skinCfgs[skinId], `CosmeticService.grantSkin: unknown skin "{skinId}"`)
	local copies = amount or 1
	assert(copies > 0 and copies == math.floor(copies), `CosmeticService.grantSkin: bad amount {copies}`)
	local ok = PlayerDataService.update(player, "Cosmetics", OWNER, function(data: CosmeticsData)
		data.PickaxeSkins[skinId] = (data.PickaxeSkins[skinId] or 0) + copies
		return data
	end)
	if ok then
		changedEvent:Fire(player)
	end
	return ok
end

-- Removes `amount` copies of a skin (a direct trade, step 9). All or nothing.
-- Giving away the last copy of the equipped skin unequips it. Raids and
-- death never call this (R1); only TradeService does.
function CosmeticService.takeSkin(player: Player, skinId: string, amount: number): boolean
	assert(skinCfgs[skinId], `CosmeticService.takeSkin: unknown skin "{skinId}"`)
	assert(amount > 0 and amount == math.floor(amount), `CosmeticService.takeSkin: bad amount {amount}`)
	local taken = false
	local ok = PlayerDataService.update(player, "Cosmetics", OWNER, function(data: CosmeticsData)
		local have = data.PickaxeSkins[skinId] or 0
		if have < amount then
			return data
		end
		local skins: { [string]: number? } = data.PickaxeSkins
		skins[skinId] = if have == amount then nil else have - amount
		if have == amount and data.EquippedPickaxeSkin == skinId then
			data.EquippedPickaxeSkin = ""
		end
		taken = true
		return data
	end)
	if ok and taken then
		changedEvent:Fire(player)
		return true
	end
	return false
end

-- Copies of a skin the player owns.
function CosmeticService.count(player: Player, skinId: string): number
	local data = CosmeticService.get(player)
	return if data then data.PickaxeSkins[skinId] or 0 else 0
end

local function equip(player: Player, skinArg: unknown): (boolean, string?)
	if typeof(skinArg) ~= "string" then
		logAnomaly(player, "sent a bad skin id")
		return false, "Invalid"
	end
	local skinId = skinArg :: string
	local data = CosmeticService.get(player)
	if not data then
		return false, "Failed"
	end
	if skinId ~= "" and (data.PickaxeSkins[skinId] or 0) <= 0 then
		return false, "NotFound"
	end
	if skinId ~= "" and not templates[skinId] then
		-- Owned, but its art model didn't load (see the start-up warning).
		return false, "NoArt"
	end
	local ok = PlayerDataService.update(player, "Cosmetics", OWNER, function(current: CosmeticsData)
		current.EquippedPickaxeSkin = skinId
		return current
	end)
	if not ok then
		return false, "Failed"
	end
	changedEvent:Fire(player)
	return true, nil
end

function CosmeticService.start()
	-- No WaitForChild: a missing folder must not stall every service after
	-- this one. It means Rojo hasn't synced src/assets/PickaxeSkins.
	local folder = ServerStorage:FindFirstChild(cosmeticCfg.SkinFolderName)
	if not folder then
		warn(`[Cosmetic] ServerStorage.{cosmeticCfg.SkinFolderName} is missing: restart "rojo serve" so it picks up default.project.json, then reconnect`)
		folder = Instance.new("Folder")
	end
	for skinId in skinCfgs do
		local template = folder:FindFirstChild(skinId)
		-- A missing skin model is an art problem, not a crash: warn and skip.
		if not template or not template:IsA("Model") or not template:FindFirstChild("Handle") or not template:FindFirstChild("Visual") then
			warn(`[Cosmetic] skin "{skinId}" needs a model ServerStorage.{cosmeticCfg.SkinFolderName}.{skinId} with a Handle part and a Visual folder`)
			continue
		end
		templates[skinId] = template
	end
	local loaded = {}
	for skinId in templates do
		table.insert(loaded, skinId)
	end
	print(`[Cosmetic] pickaxe skins loaded: {if #loaded > 0 then table.concat(loaded, ", ") else "NONE"}`)

	local allow = RateLimiter.new("EquipSkin", Config.Combat.GearRequestCooldownSeconds)
	Remotes.getFunction("EquipSkin").OnServerInvoke = function(player: Player, skinArg: unknown): (boolean, string?)
		if not allow(player) then
			return false, "Busy"
		end
		return equip(player, skinArg)
	end
end

return CosmeticService
