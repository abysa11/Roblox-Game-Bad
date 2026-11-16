--[[
	ClientState
	Single source of truth on the client for profile, settings, match state and which menus
	are open. Controllers listen to its signals instead of talking to each other directly.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)

local ClientState = {}

ClientState.Player = Players.LocalPlayer
ClientState.Profile = nil
ClientState.Settings = {
	MasterVolume = 0.8,
	MusicVolume = 0.6,
	SfxVolume = 0.9,
	MouseSensitivity = 1,
	TouchSensitivity = 1,
	CrosshairColor = "Green",
	CrosshairSize = 8,
	CrosshairGap = 4,
	CrosshairThickness = 2,
	CrosshairDot = false,
	Effects = "High",
}
ClientState.Match = nil -- last MatchState payload (nil / State="Lobby" while in the lobby)
ClientState.Lobby = nil -- last LobbyState payload
ClientState.InMatch = false
ClientState.Alive = false
ClientState.Menus = {}

ClientState.ProfileChanged = Signal.new()
ClientState.SettingsChanged = Signal.new()
ClientState.MatchChanged = Signal.new()
ClientState.MenuChanged = Signal.new()
ClientState.LobbyChanged = Signal.new()

ClientState.CrosshairColors = {
	Green = Color3.fromRGB(80, 255, 120),
	White = Color3.fromRGB(255, 255, 255),
	Cyan = Color3.fromRGB(60, 230, 255),
	Yellow = Color3.fromRGB(255, 230, 60),
	Red = Color3.fromRGB(255, 70, 70),
	Pink = Color3.fromRGB(255, 110, 220),
}
ClientState.CrosshairOrder = { "Green", "White", "Cyan", "Yellow", "Red", "Pink" }

function ClientState.SetProfile(profile)
	ClientState.Profile = profile
	if profile and profile.Settings then
		for k, v in pairs(profile.Settings) do
			ClientState.Settings[k] = v
		end
		ClientState.SettingsChanged:Fire(ClientState.Settings)
	end
	ClientState.ProfileChanged:Fire(profile)
end

function ClientState.SetMatch(payload)
	ClientState.Match = payload
	ClientState.InMatch = payload ~= nil and payload.State ~= "Lobby" and payload.State ~= "Closed"
	ClientState.MatchChanged:Fire(payload)
end

function ClientState.SetMenu(name: string, open: boolean)
	if (ClientState.Menus[name] == true) == open then
		return
	end
	ClientState.Menus[name] = open or nil
	ClientState.MenuChanged:Fire(name, open)
end

function ClientState.IsMenuOpen(name: string?): boolean
	if name then
		return ClientState.Menus[name] == true
	end
	return next(ClientState.Menus) ~= nil
end

function ClientState.Team(): string?
	return ClientState.Player:GetAttribute("Team")
end

function ClientState.IsLive(): boolean
	return ClientState.InMatch and ClientState.Match ~= nil and ClientState.Match.State == "Live"
end

function ClientState.IsTouch(): boolean
	local UIS = game:GetService("UserInputService")
	return UIS.TouchEnabled and not UIS.MouseEnabled
end

return ClientState
