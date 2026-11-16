--[[
	SkinShopServer
	Server side of the cosmetic skin shop and player settings.
	All prices, ownership and balances are checked here; the client only sends ids.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local SkinData = require(ReplicatedStorage.Shared.SkinData)
local WeaponData = require(ReplicatedStorage.WeaponModules.WeaponData)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local RateLimiter = require(script.Parent.RateLimiter)

local SkinShopServer = {}

-- Set by Main: returns true while the player is in the lobby (shop is a lobby feature).
SkinShopServer.IsInLobby = function(_player)
	return true
end

local busy: { [Player]: boolean } = {}

local function result(ok, message, player)
	local data = PlayerDataManager.Get(player)
	return { Ok = ok, Message = message, Profile = data and PlayerDataManager.Snapshot(data) }
end

local function buySkin(player: Player, skinId)
	if type(skinId) ~= "string" or #skinId > 64 then
		return result(false, "Invalid item.", player)
	end
	if not RateLimiter.Check(player, "BuySkin", 2, 4) then
		return result(false, "Slow down.", player)
	end
	if busy[player] then
		return result(false, "Purchase already in progress.", player)
	end
	local skin = SkinData.Get(skinId)
	if not skin then
		return result(false, "That skin does not exist.", player)
	end
	if not SkinShopServer.IsInLobby(player) then
		return result(false, "The skin shop is only available in the lobby.", player)
	end
	local data = PlayerDataManager.Get(player)
	if not data then
		return result(false, "Your data is still loading.", player)
	end
	if data.OwnedSkins[skinId] then
		return result(false, "You already own this skin.", player)
	end
	if data.Points < skin.Price then
		return result(false, string.format("Not enough points (%d / %d).", data.Points, skin.Price), player)
	end

	busy[player] = true
	-- Deduct and grant in one synchronous step (no yields in between => no double spend).
	PlayerDataManager.Update(player, function(d)
		d.Points -= skin.Price
		d.OwnedSkins[skinId] = true
		d.EquippedSkins[skin.Weapon] = skinId
	end)
	busy[player] = nil
	task.spawn(PlayerDataManager.Save, player, false)
	return result(true, "Purchased " .. skin.Name .. "!", player)
end

local function equipSkin(player: Player, weaponId, skinId)
	if type(weaponId) ~= "string" or not WeaponData.Get(weaponId) then
		return result(false, "Invalid weapon.", player)
	end
	if skinId ~= nil and type(skinId) ~= "string" then
		return result(false, "Invalid skin.", player)
	end
	if not RateLimiter.Check(player, "EquipSkin", 4, 8) then
		return result(false, "Slow down.", player)
	end
	local data = PlayerDataManager.Get(player)
	if not data then
		return result(false, "Your data is still loading.", player)
	end
	if skinId then
		local skin = SkinData.Get(skinId)
		if not skin or skin.Weapon ~= weaponId then
			return result(false, "That skin does not fit this weapon.", player)
		end
		if not data.OwnedSkins[skinId] then
			return result(false, "You do not own this skin.", player)
		end
	end
	PlayerDataManager.Update(player, function(d)
		d.EquippedSkins[weaponId] = skinId
	end)
	return result(true, skinId and "Skin equipped." or "Default finish equipped.", player)
end

local CROSSHAIR_COLORS = { Green = true, White = true, Cyan = true, Yellow = true, Red = true, Pink = true }
local EFFECTS = { Low = true, Medium = true, High = true }
local NUMERIC = {
	MasterVolume = { 0, 1 },
	MusicVolume = { 0, 1 },
	SfxVolume = { 0, 1 },
	MouseSensitivity = { 0.1, 4 },
	TouchSensitivity = { 0.1, 4 },
	CrosshairSize = { 2, 24 },
	CrosshairGap = { 0, 16 },
	CrosshairThickness = { 1, 6 },
}

local function saveSettings(player: Player, settings)
	if type(settings) ~= "table" then
		return false
	end
	if not RateLimiter.Check(player, "SaveSettings", 1, 3) then
		return false
	end
	local clean = {}
	for key, range in pairs(NUMERIC) do
		local v = settings[key]
		if type(v) == "number" and v == v then
			clean[key] = math.clamp(v, range[1], range[2])
		end
	end
	if CROSSHAIR_COLORS[settings.CrosshairColor] then
		clean.CrosshairColor = settings.CrosshairColor
	end
	if EFFECTS[settings.Effects] then
		clean.Effects = settings.Effects
	end
	if type(settings.CrosshairDot) == "boolean" then
		clean.CrosshairDot = settings.CrosshairDot
	end
	return PlayerDataManager.Update(player, function(d)
		for k, v in pairs(clean) do
			d.Settings[k] = v
		end
	end)
end

function SkinShopServer.Init()
	Net.Function("BuySkin").OnServerInvoke = buySkin
	Net.Function("EquipSkin").OnServerInvoke = equipSkin
	Net.Function("SaveSettings").OnServerInvoke = saveSettings
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		busy[p] = nil
	end)
end

return SkinShopServer
