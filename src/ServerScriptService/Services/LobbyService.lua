--[[
	LobbyService
	Map queues. Standing on a pad queues you for that map (one queue at a time); stepping
	off removes you. When a queue's countdown ends the group is sent to a match:
	  Local mode    -> a match running in this server (built on demand, reused while it has room)
	  Teleport mode -> an open reserved server for that map (via MatchRegistry) or a new one
]]

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)
local MapData = require(ReplicatedStorage.Shared.MapData)
local LobbyBuilder = require(script.Parent.Parent.Builders.LobbyBuilder)
local MatchManager = require(script.Parent.MatchManager)
local MatchRegistry = require(script.Parent.MatchRegistry)
local SpawnManager = require(script.Parent.SpawnManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local LobbyService = {}
LobbyService.Mode = "Local"

local lobby
local queues: { [string]: { Players: { Player }, EndsAt: number? } } = {}
local playerQueue: { [Player]: string } = {}
local teleporting: { [Player]: boolean } = {}

function LobbyService.GetSpawnCFrame(): CFrame
	return lobby and lobby.SpawnCFrame or CFrame.new(0, 5, 0)
end

function LobbyService.GetZone(mapId: string)
	return lobby and lobby.Zones[mapId]
end

local function leaveQueue(player: Player)
	local mapId = playerQueue[player]
	if not mapId then
		return
	end
	playerQueue[player] = nil
	local q = queues[mapId]
	local i = table.find(q.Players, player)
	if i then
		table.remove(q.Players, i)
	end
	if #q.Players == 0 then
		q.EndsAt = nil
	end
	player:SetAttribute("QueuedMap", nil)
end

local function joinQueue(player: Player, mapId: string)
	if playerQueue[player] == mapId then
		return
	end
	leaveQueue(player)
	local q = queues[mapId]
	if #q.Players >= Config.Match.MaxPlayers then
		return
	end
	table.insert(q.Players, player)
	playerQueue[player] = mapId
	if not q.EndsAt then
		q.EndsAt = workspace:GetServerTimeNow() + Config.Lobby.QueueCountdown
	end
	player:SetAttribute("QueuedMap", mapId)
end

local function broadcastLobbyState()
	local state = {}
	for mapId, q in pairs(queues) do
		state[mapId] = {
			Waiting = #q.Players,
			EndsAt = q.EndsAt,
			InMatch = LobbyService.Mode == "Local" and MatchManager.CountForMap(mapId) or nil,
		}
	end
	Net.Event("LobbyState"):FireAllClients(state)
end

local function updateSigns()
	local now = workspace:GetServerTimeNow()
	for mapId, zone in pairs(lobby.Zones) do
		local q = queues[mapId]
		local waiting = #q.Players
		local inMatch = LobbyService.Mode == "Local" and MatchManager.CountForMap(mapId) or 0
		zone.Count.Text = string.format("WAITING: %d / %d%s", waiting, Config.Match.MaxPlayers, inMatch > 0 and ("   |   IN MATCH: " .. inMatch) or "")
		if q.EndsAt and waiting > 0 then
			if waiting < Config.Lobby.MinPlayersToLaunch then
				zone.Status.Text = string.format("Need %d more player(s)", Config.Lobby.MinPlayersToLaunch - waiting)
			else
				zone.Status.Text = string.format("LAUNCHING IN %d", math.max(0, math.ceil(q.EndsAt - now)))
			end
		else
			zone.Status.Text = "Step onto the pad to queue"
		end
	end
end

-- TELEPORT ---------------------------------------------------------------------------

local function teleportGroup(mapId: string, group: { Player })
	local placeId = Config.Matchmaking.MatchPlaceId or game.PlaceId
	for _, p in ipairs(group) do
		teleporting[p] = true
		leaveQueue(p)
		Net.Event("Notify"):FireClient(p, "Finding a " .. MapData.Get(mapId).Name .. " server...", "info")
	end
	local code = MatchRegistry.FindOpen(mapId, #group)
	if not code then
		local ok, result = pcall(function()
			return TeleportService:ReserveServer(placeId)
		end)
		if ok then
			code = result
		else
			warn("[Lobby] ReserveServer failed, falling back to a local match: " .. tostring(result))
		end
	end
	if not code then
		for _, p in ipairs(group) do
			teleporting[p] = nil
		end
		LobbyService.LaunchLocal(mapId, group)
		return
	end
	-- release the data lock first so the match server can load the profile immediately
	local ready = {}
	for _, p in ipairs(group) do
		if p.Parent then
			PlayerDataManager.SaveAndRelease(p)
			table.insert(ready, p)
		end
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({ MapId = mapId, Code = code })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, ready, options)
	end)
	if not ok then
		warn("[Lobby] TeleportAsync failed: " .. tostring(err))
		for _, p in ipairs(ready) do
			teleporting[p] = nil
			PlayerDataManager.Reacquire(p)
			Net.Event("Notify"):FireClient(p, "Teleport failed - starting the match on this server instead.", "error")
		end
		LobbyService.LaunchLocal(mapId, ready)
	end
end

function LobbyService.LaunchLocal(mapId: string, group: { Player })
	local valid = {}
	for _, p in ipairs(group) do
		leaveQueue(p)
		if p.Parent and not MatchManager.GetMatchOf(p) then
			table.insert(valid, p)
		end
	end
	if #valid == 0 then
		return
	end
	local match = MatchManager.FindOrCreateLocal(mapId, #valid)
	for _, p in ipairs(valid) do
		match:AddPlayer(p)
	end
end

local function launch(mapId: string)
	local q = queues[mapId]
	local group = {}
	for i = 1, math.min(#q.Players, Config.Match.MaxPlayers) do
		table.insert(group, q.Players[i])
	end
	q.EndsAt = nil
	if LobbyService.Mode == "Teleport" then
		task.spawn(teleportGroup, mapId, group)
	else
		LobbyService.LaunchLocal(mapId, group)
	end
end

-- Return a player from a local match to the lobby (keeps all persistent progress).
function LobbyService.SendToLobby(player: Player)
	if not player.Parent then
		return
	end
	leaveQueue(player)
	Net.Event("MatchState"):FireClient(player, { State = "Lobby" })
	SpawnManager.Spawn(player)
	-- step off the pad area so returning players are not instantly re-queued
	player:SetAttribute("QueueCooldownUntil", workspace:GetServerTimeNow() + 3)
end

local function tick()
	local now = workspace:GetServerTimeNow()
	for _, player in ipairs(Players:GetPlayers()) do
		local inZone = nil
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local cooldown = player:GetAttribute("QueueCooldownUntil")
		local eligible = root and hum and hum.Health > 0
			and not teleporting[player]
			and not MatchManager.GetMatchOf(player)
			and PlayerDataManager.IsLoaded(player)
			and not (type(cooldown) == "number" and now < cooldown)
		if eligible then
			for mapId, zone in pairs(lobby.Zones) do
				if Util.InBox(root.Position, zone.CFrame, zone.Size) then
					inZone = mapId
					break
				end
			end
		end
		if inZone then
			if playerQueue[player] ~= inZone then
				joinQueue(player, inZone)
			end
		elseif playerQueue[player] then
			leaveQueue(player)
		end
	end

	for mapId, q in pairs(queues) do
		local n = #q.Players
		if n > 0 and q.EndsAt then
			if n >= Config.Match.MaxPlayers or (now >= q.EndsAt and n >= Config.Lobby.MinPlayersToLaunch) then
				launch(mapId)
			elseif now >= q.EndsAt then
				q.EndsAt = now + Config.Lobby.QueueCountdown -- not enough players yet, keep waiting
			end
		end
	end
end

function LobbyService.Init(mode: string)
	LobbyService.Mode = mode
	for _, mapId in ipairs(MapData.Order) do
		queues[mapId] = { Players = {}, EndsAt = nil }
	end
	lobby = LobbyBuilder.Build(workspace)

	lobby.SkinShopPrompt.Triggered:Connect(function(player)
		if not MatchManager.GetMatchOf(player) then
			Net.Event("OpenSkinShop"):FireClient(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
		teleporting[player] = nil
	end)

	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		if teleporting[player] then
			teleporting[player] = nil
			PlayerDataManager.Reacquire(player)
			Net.Event("Notify"):FireClient(player, "Teleport failed (" .. tostring(message or result) .. "). Please try again.", "error")
		end
	end)

	task.spawn(function()
		local t = 0
		while true do
			task.wait(0.2)
			local ok, err = pcall(tick)
			if not ok then
				warn("[Lobby] tick error: " .. tostring(err))
			end
			t += 1
			if t % 2 == 0 then
				updateSigns()
			end
			if t % 5 == 0 then
				broadcastLobbyState()
			end
		end
	end)
end

return LobbyService
