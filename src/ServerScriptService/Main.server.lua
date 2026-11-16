--[[
	Main (server bootstrap)
	Decides what this server is and wires the services together.

	Roles:
	  Lobby server  - builds the hub, runs map queues, hosts Local matches (Studio / small games)
	  Match server  - a reserved server created by a lobby (Teleport mode): runs one match
]]

local Players = game:GetService("Players")
-- Before anything else: never let Roblox drop a default character into the empty world
-- while the lobby is still being built (we spawn characters ourselves).
Players.CharacterAutoLoads = false
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net) -- creates the remotes
local MapData = require(ReplicatedStorage.Shared.MapData)

local Services = script.Parent.Services
local PlayerDataManager = require(Services.PlayerDataManager)
local SpawnManager = require(Services.SpawnManager)
local WeaponServer = require(Services.WeaponServer)
local CombatServer = require(Services.CombatServer)
local MatchManager = require(Services.MatchManager)
local SkinShopServer = require(Services.SkinShopServer)
local LobbyService = require(Services.LobbyService)
local MatchRegistry = require(Services.MatchRegistry)

-- MODE / ROLE ------------------------------------------------------------------------
local mode = Config.Matchmaking.Mode
if mode == "Auto" then
	mode = (RunService:IsStudio() or game.PlaceId == 0) and "Local" or "Teleport"
end
local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local isMatchPlace = Config.Matchmaking.MatchPlaceId ~= nil and game.PlaceId == Config.Matchmaking.MatchPlaceId
local role = (mode == "Teleport" and (isReserved or isMatchPlace)) and "Match" or "Lobby"
workspace:SetAttribute("ServerRole", role)
workspace:SetAttribute("MatchmakingMode", mode)
print(string.format("[Main] mode=%s role=%s", mode, role))

-- global lighting baseline (each client applies map-specific lighting locally;
-- Lighting.Technology is set in the place file because scripts cannot change it)
Lighting.GlobalShadows = true
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6

do
	local effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = workspace
end

-- INIT ---------------------------------------------------------------------------------
PlayerDataManager.Init()
SpawnManager.Init()
WeaponServer.Init()
CombatServer.Init()
MatchManager.Init()
SkinShopServer.Init()

CombatServer.GetMatchOf = MatchManager.GetMatchOf
SkinShopServer.IsInLobby = function(player)
	return role == "Lobby" and MatchManager.GetMatchOf(player) == nil
end

SpawnManager.ResolveSpawn = function(player)
	local m = MatchManager.GetMatchOf(player)
	if m and (m.State == "Warmup" or m.State == "Live") then
		return m:GetSpawnCFrame(player), "Match"
	end
	if role == "Lobby" then
		return LobbyService.GetSpawnCFrame(), "Lobby"
	end
	return CFrame.new(0, 80, 0), "Lobby"
end

SpawnManager.OnSpawned(function(player, _character, context)
	if context == "Match" then
		WeaponServer.Arm(player)
	else
		WeaponServer.Disarm(player)
	end
end)

SpawnManager.OnDied(function(player)
	local m = MatchManager.GetMatchOf(player)
	if m then
		m:OnDeath(player)
	elseif role == "Lobby" then
		SpawnManager.ScheduleRespawn(player, 2)
	end
end)

-- lobby kill plane (local-mode lobby has walls, but guard against glitches)
task.spawn(function()
	while true do
		task.wait(1)
		for _, p in ipairs(Players:GetPlayers()) do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and not MatchManager.GetMatchOf(p) and root.Position.Y < -80 then
				hum.Health = 0
			end
		end
	end
end)

if role == "Lobby" then
	LobbyService.Init(mode)
	MatchManager.ReturnToLobby = LobbyService.SendToLobby

	local function onJoin(player)
		-- spawn immediately; queues and the skin shop wait for the profile on their own
		Net.Event("MatchState"):FireClient(player, { State = "Lobby" })
		SpawnManager.Spawn(player)
	end
	Players.PlayerAdded:Connect(function(p)
		task.spawn(onJoin, p)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onJoin, p)
	end
else
	-- MATCH SERVER ---------------------------------------------------------------------
	local match = nil
	local accessCode = nil
	local lobbyPlace = Config.Matchmaking.LobbyPlaceId or game.PlaceId

	local function ensureMatch(mapId)
		if not match or match.Closed then
			match = MatchManager.Create(mapId, CFrame.new())
		end
		return match
	end

	local function sendToLobby(player: Player)
		if not player.Parent then
			return
		end
		Net.Event("Notify"):FireClient(player, "Returning to the lobby...", "info")
		PlayerDataManager.SaveAndRelease(player)
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(lobbyPlace, { player })
		end)
		if not ok then
			warn("[Main] return-to-lobby teleport failed: " .. tostring(err))
			PlayerDataManager.Reacquire(player)
			Net.Event("Notify"):FireClient(player, "Could not reach the lobby, keeping you in this match.", "error")
			if match and not match.Closed then
				match:AddPlayer(player)
			end
		end
	end
	MatchManager.ReturnToLobby = sendToLobby

	TeleportService.TeleportInitFailed:Connect(function(player)
		PlayerDataManager.Reacquire(player)
		if match and not match.Closed and player.Parent then
			match:AddPlayer(player)
		end
	end)

	local function onJoin(player: Player)
		local data = PlayerDataManager.WaitForData(player, 45)
		if not data or not player.Parent then
			return
		end
		local joinData = player:GetJoinData()
		local td = joinData and joinData.TeleportData
		local mapId = (type(td) == "table" and MapData.IsValid(td.MapId)) and td.MapId or (match and match.MapId) or MapData.Order[1]
		if type(td) == "table" and type(td.Code) == "string" then
			accessCode = accessCode or td.Code
		end
		local m = ensureMatch(mapId)
		if not m:HasRoom(1) then
			Net.Event("Notify"):FireClient(player, "That match just filled up - sending you back to the lobby.", "error")
			sendToLobby(player)
			return
		end
		m:AddPlayer(player)
	end
	Players.PlayerAdded:Connect(function(p)
		task.spawn(onJoin, p)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onJoin, p)
	end

	MatchManager.OnMatchClosed = function()
		MatchRegistry.Remove(game.PrivateServerId)
	end

	-- publish this server so lobbies can fill free slots
	task.spawn(function()
		while true do
			if match and not match.Closed and accessCode then
				MatchRegistry.Publish(game.PrivateServerId, {
					MapId = match.MapId,
					Code = accessCode,
					Count = match:Count(),
					Max = Config.Match.MaxPlayers,
					Joinable = match:HasRoom(1),
				})
			end
			task.wait(Config.Matchmaking.RegistryHeartbeat)
		end
	end)

	game:BindToClose(function()
		MatchRegistry.Remove(game.PrivateServerId)
	end)
end
