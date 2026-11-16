--[[
	MatchManager
	A Match owns one built map, its players (stats + team), and the round loop:

	  Starting -> Warmup (short countdown, shop open) -> Live (exactly Config.Match.Duration)
	           -> Results (podium cinematic) -> PostMatch (Return to Lobby / Play Again)
	           -> next round with everyone who stayed (stats reset, teams rebalanced)

	In "Local" mode several matches can run in one server, each map at its own offset.
	In "Teleport" mode a reserved server runs exactly one match.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)
local MapData = require(ReplicatedStorage.Shared.MapData)
local MapLoader = require(script.Parent.Parent.Builders.MapLoader)
local TeamManager = require(script.Parent.TeamManager)
local SpawnManager = require(script.Parent.SpawnManager)
local WeaponServer = require(script.Parent.WeaponServer)
local RewardManager = require(script.Parent.RewardManager)
local RateLimiter = require(script.Parent.RateLimiter)

local MatchManager = {}

-- Wired by Main: sends a player back to the lobby (respawn in lobby or teleport).
MatchManager.ReturnToLobby = function(_player: Player) end
MatchManager.OnMatchClosed = function(_match) end

local matches: { [string]: any } = {}
local playerMatch: { [Player]: any } = {}
local usedSlots: { [number]: boolean } = {}
local joinCounter = 0

local function serverNow()
	return workspace:GetServerTimeNow()
end

local Match = {}
Match.__index = Match

function MatchManager.Create(mapId: string, origin: CFrame, slot: number?)
	local self = setmetatable({}, Match)
	self.Key = HttpService:GenerateGUID(false)
	self.MapId = mapId
	self.Players = {}
	self.State = "Starting"
	self.EndsAt = 0
	self.Round = 0
	self.Id = ""
	self.Choices = {}
	self.Closed = false
	self.Slot = slot
	self.World = MapLoader.Load(mapId, origin)
	matches[self.Key] = self
	task.spawn(function()
		self:Loop()
	end)
	return self
end

-- Local mode: reuse a match of this map with free room, or build a new one at a free offset.
function MatchManager.FindOrCreateLocal(mapId: string, groupSize: number)
	for _, m in pairs(matches) do
		if m.MapId == mapId and m:HasRoom(groupSize) then
			return m
		end
	end
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	local origin = CFrame.new(slot * Config.Matchmaking.LocalMapSpacing, 0, 0)
	return MatchManager.Create(mapId, origin, slot)
end

function MatchManager.GetMatchOf(player: Player)
	return playerMatch[player]
end

function MatchManager.GetMatches()
	return matches
end

function MatchManager.CountForMap(mapId: string): number
	local n = 0
	for _, m in pairs(matches) do
		if m.MapId == mapId then
			n += m:Count()
		end
	end
	return n
end

-- MATCH ------------------------------------------------------------------------------

function Match:Count(): number
	local n = 0
	for _ in pairs(self.Players) do
		n += 1
	end
	return n
end

function Match:PlayerList(): { Player }
	local list = {}
	for p in pairs(self.Players) do
		table.insert(list, p)
	end
	return list
end

function Match:HasRoom(n: number): boolean
	return not self.Closed and self:Count() + n <= Config.Match.MaxPlayers
end

function Match:Broadcast(eventName: string, ...)
	Net.FireList(eventName, self:PlayerList(), ...)
end

function Match:Notify(text: string, kind: string?)
	self:Broadcast("Notify", text, kind or "info")
end

function Match:StatePayload()
	local red, blue = TeamManager.Count(self)
	local redKills, blueKills = 0, 0
	local roster = {}
	for p, stat in pairs(self.Players) do
		if stat.Team == "Red" then
			redKills += stat.Kills
		else
			blueKills += stat.Kills
		end
		table.insert(roster, { UserId = p.UserId, Name = p.DisplayName, Team = stat.Team, Kills = stat.Kills, Deaths = stat.Deaths })
	end
	local map = MapData.Get(self.MapId)
	return {
		Key = self.Key,
		MapId = self.MapId,
		MapName = map and map.Name or self.MapId,
		State = self.State,
		EndsAt = self.EndsAt,
		Round = self.Round,
		Red = red,
		Blue = blue,
		RedKills = redKills,
		BlueKills = blueKills,
		Roster = roster,
		SpawnZones = self.World.SpawnZones,
	}
end

function Match:SendState(only: Player?)
	local payload = self:StatePayload()
	if only then
		Net.Event("MatchState"):FireClient(only, payload)
	else
		self:Broadcast("MatchState", payload)
	end
end

function Match:AddPlayer(player: Player)
	if playerMatch[player] == self or self.Closed then
		return
	end
	if playerMatch[player] then
		playerMatch[player]:RemovePlayer(player)
	end
	joinCounter += 1
	local stat = { Team = nil, Kills = 0, Deaths = 0, JoinOrder = joinCounter }
	self.Players[player] = stat
	playerMatch[player] = self
	TeamManager.SetTeam(player, stat, TeamManager.PickTeam(self))
	player:SetAttribute("MatchKey", self.Key)
	player:SetAttribute("MapId", self.MapId)
	player:SetAttribute("Kills", 0)
	player:SetAttribute("Deaths", 0)
	WeaponServer.ResetLoadout(player)
	WeaponServer.Disarm(player)
	self:SendState()

	if self.State == "Warmup" or self.State == "Live" then
		SpawnManager.Spawn(player)
		Net.Event("Notify"):FireClient(player, "You joined " .. Config.Teams[stat.Team].Name, stat.Team)
	else
		SpawnManager.CancelRespawn(player)
		if player.Character then
			player.Character:Destroy()
			player.Character = nil
		end
		if self.LastResults then
			Net.Event("Results"):FireClient(player, self.LastResults)
		end
		if self.State == "PostMatch" then
			Net.Event("PostMatchPrompt"):FireClient(player, { EndsAt = self.EndsAt })
		end
	end
end

function Match:RemovePlayer(player: Player)
	if not self.Players[player] then
		return
	end
	self.Players[player] = nil
	self.Choices[player] = nil
	if playerMatch[player] == self then
		playerMatch[player] = nil
	end
	for _, attr in ipairs({ "MatchKey", "MapId", "Team", "TeamColor", "Kills", "Deaths", "ProtectedUntil" }) do
		player:SetAttribute(attr, nil)
	end
	if player.Parent then
		WeaponServer.Disarm(player)
	end
	self:SendState()
end

function Match:GetSpawnCFrame(player: Player): CFrame
	local stat = self.Players[player]
	local team = stat and stat.Team or "Red"
	local spawns = self.World.Spawns[team]
	local enemies = {}
	for p, s in pairs(self.Players) do
		local root = s.Team ~= team and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			table.insert(enemies, root.Position)
		end
	end
	local best, bestScore = spawns[math.random(1, #spawns)], -1
	if #enemies > 0 then
		for _, cf in ipairs(spawns) do
			local nearest = math.huge
			for _, e in ipairs(enemies) do
				nearest = math.min(nearest, (cf.Position - e).Magnitude)
			end
			local score = nearest + math.random() * 8
			if score > bestScore then
				best, bestScore = cf, score
			end
		end
	end
	return best
end

function Match:IsInSpawnZone(player: Player): boolean
	local stat = self.Players[player]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local zone = stat and self.World.SpawnZones[stat.Team]
	if not root or not zone then
		return false
	end
	return Util.InBox(root.Position, zone.CFrame, zone.Size + Vector3.new(2, 6, 2))
end

function Match:OnKill(killer: Player, _victim: Player, _weaponId: string, _headshot: boolean)
	local stat = self.Players[killer]
	if stat and self.State == "Live" then
		stat.Kills += 1
		killer:SetAttribute("Kills", stat.Kills)
		self:SendState()
	end
end

function Match:OnDeath(player: Player)
	local stat = self.Players[player]
	if not stat then
		return
	end
	WeaponServer.OnDeath(player)
	if self.State ~= "Live" and self.State ~= "Warmup" then
		return
	end
	if self.State == "Live" then
		stat.Deaths += 1
		player:SetAttribute("Deaths", stat.Deaths)
	end
	-- auto-balance: move this player if their team is too big
	local over = TeamManager.OverfullTeam(self)
	if over and over == stat.Team then
		TeamManager.SetTeam(player, stat, TeamManager.Other(stat.Team))
		Net.Event("Notify"):FireClient(player, "Teams auto-balanced: you are now on " .. Config.Teams[stat.Team].Name, stat.Team)
	end
	self:SendState()
	SpawnManager.ScheduleRespawn(player, Config.Match.RespawnDelay)
end

function Match:OnChoice(player: Player, choice: string)
	if not self.Players[player] or (self.State ~= "PostMatch" and self.State ~= "Results") then
		return
	end
	if choice == "Lobby" then
		self:RemovePlayer(player)
		MatchManager.ReturnToLobby(player)
	elseif choice == "Continue" then
		self.Choices[player] = "Continue"
		Net.Event("Notify"):FireClient(player, "You'll stay for the next match.", "info")
	end
end

function Match:WaitUntil(t: number, stopIf: (() -> boolean)?)
	while serverNow() < t and not self.Closed do
		if stopIf and stopIf() then
			return
		end
		task.wait(0.25)
	end
end

function Match:CheckOutOfBounds()
	for p in pairs(self.Players) do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and root.Position.Y < self.World.KillY then
			hum.Health = 0
		end
	end
end

function Match:PlayRound()
	self.Round += 1
	self.Id = HttpService:GenerateGUID(false)
	self.Choices = {}
	self.LastResults = nil
	for p, stat in pairs(self.Players) do
		stat.Kills = 0
		stat.Deaths = 0
		p:SetAttribute("Kills", 0)
		p:SetAttribute("Deaths", 0)
		WeaponServer.ResetLoadout(p)
	end
	TeamManager.Rebalance(self)

	self.State = "Warmup"
	self.EndsAt = serverNow() + Config.Match.PreRoundCountdown
	self:SendState()
	for p in pairs(self.Players) do
		SpawnManager.Spawn(p)
	end
	self:WaitUntil(self.EndsAt, function()
		return self:Count() == 0
	end)
	if self.Closed or self:Count() == 0 then
		return
	end

	self.State = "Live"
	self.EndsAt = serverNow() + Config.Match.Duration
	self:SendState()
	self:Notify("Match started! Most kills in 10 minutes wins.", "start")
	while serverNow() < self.EndsAt and not self.Closed do
		task.wait(0.5)
		if self:Count() == 0 then
			return
		end
		self:CheckOutOfBounds()
	end
	if self.Closed then
		return
	end
	self:FinishRound()
end

function Match:FinishRound()
	self.State = "Results"
	self.EndsAt = serverNow() + Config.Match.ResultsDuration
	for p in pairs(self.Players) do
		SpawnManager.CancelRespawn(p)
		WeaponServer.Disarm(p)
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		end
	end

	local ranking = RewardManager.Rank(self)
	RewardManager.Grant(self.Id, ranking)

	local podium, rankings = {}, {}
	for _, e in ipairs(ranking) do
		local row = {
			Place = e.Place,
			UserId = e.UserId,
			Name = e.Name,
			DisplayName = e.DisplayName,
			Team = e.Team,
			Kills = e.Kills,
			Deaths = e.Deaths,
			Points = e.Points,
		}
		table.insert(rankings, row)
		if e.Place <= 3 then
			table.insert(podium, row)
		end
	end
	self.World.Podium:Show(podium)

	self.LastResults = {
		MatchId = self.Id,
		MapId = self.MapId,
		PodiumCFrame = self.World.PodiumCFrame,
		Duration = Config.Match.ResultsDuration,
		Podium = podium,
		Rankings = rankings,
	}
	self:SendState()
	self:Broadcast("Results", self.LastResults)
	self:WaitUntil(self.EndsAt)
	if self.Closed then
		return
	end

	self.State = "PostMatch"
	self.EndsAt = serverNow() + Config.Match.PostMatchChoiceDuration
	self:SendState()
	self:Broadcast("PostMatchPrompt", { EndsAt = self.EndsAt })
	self:WaitUntil(self.EndsAt, function()
		if self:Count() == 0 then
			return true
		end
		for p in pairs(self.Players) do
			if self.Choices[p] ~= "Continue" then
				return false
			end
		end
		return true
	end)
	self.World.Podium:Clear()
end

function Match:Loop()
	task.wait(0.5)
	while not self.Closed do
		if self:Count() == 0 then
			local waited = 0
			while self:Count() == 0 and waited < 45 and not self.Closed do
				task.wait(1)
				waited += 1
			end
			if self:Count() == 0 then
				self:Close()
				return
			end
		end
		local ok, err = pcall(function()
			self:PlayRound()
		end)
		if not ok then
			warn("[Match] round error: " .. tostring(err))
			task.wait(2)
		end
	end
end

function Match:Close()
	if self.Closed then
		return
	end
	self.Closed = true
	self.State = "Closed"
	for _, p in ipairs(self:PlayerList()) do
		self:RemovePlayer(p)
		MatchManager.ReturnToLobby(p)
	end
	matches[self.Key] = nil
	if self.Slot then
		usedSlots[self.Slot] = nil
	end
	MatchManager.OnMatchClosed(self)
	task.delay(1, function()
		self.World.Destroy()
	end)
end

-- INIT -------------------------------------------------------------------------------

function MatchManager.Init()
	Net.Event("PostMatchChoice").OnServerEvent:Connect(function(player, choice)
		if type(choice) ~= "string" or not RateLimiter.Check(player, "PostChoice", 2, 3) then
			return
		end
		local m = playerMatch[player]
		if m then
			m:OnChoice(player, choice)
		end
	end)

	WeaponServer.CanChangeLoadout = function(player)
		local m = playerMatch[player]
		if not m then
			return false, "You are not in a match."
		end
		if m.State ~= "Warmup" and m.State ~= "Live" then
			return false, "The match is over."
		end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return false, "You are dead."
		end
		if not m:IsInSpawnZone(player) then
			return false, "Return to your spawn to change weapons."
		end
		return true
	end

	Players.PlayerRemoving:Connect(function(player)
		local m = playerMatch[player]
		if m then
			m:RemovePlayer(player)
		end
	end)
end

return MatchManager
