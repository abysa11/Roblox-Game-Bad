--[[
	PlayerDataManager
	Persistent progress (points, skins, settings, lifetime stats) in DataStoreService.

	Safety rules:
	  * Data is loaded with UpdateAsync and a session lock, so two servers never write the same
	    profile at once (e.g. while teleporting between lobby and match servers).
	  * If loading fails, the player is NEVER given a default profile that could overwrite their
	    real data. Live servers kick with a friendly message; Studio uses a temporary profile
	    that is flagged as unsaveable.
	  * Saves retry with exponential backoff, run on leave, on an autosave timer and on shutdown.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local PlayerDataManager = {}

local DATA = Config.Data
local JOB_ID = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))

PlayerDataManager.Template = {
	Version = 1,
	Points = 0,
	OwnedSkins = {},
	EquippedSkins = {},
	Stats = { Kills = 0, Deaths = 0, Matches = 0, Wins = 0, Podiums = 0 },
	Settings = {
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
	},
	ProcessedMatches = {},
}

type Profile = {
	Data: any,
	CanSave: boolean,
	Saving: boolean,
	Released: boolean,
	LastSave: number,
}

local profiles: { [Player]: Profile } = {}
local loadedEvent = Instance.new("BindableEvent")
PlayerDataManager.ProfileLoaded = loadedEvent.Event
local changedEvent = Instance.new("BindableEvent")
PlayerDataManager.Changed = changedEvent.Event

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATA.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore unavailable: " .. tostring(result))
	end
end

local function keyFor(player: Player)
	return "u_" .. player.UserId
end

local function lockIsForeign(lock): boolean
	return type(lock) == "table"
		and lock.JobId ~= JOB_ID
		and type(lock.Time) == "number"
		and os.time() - lock.Time < DATA.SessionLockTimeout
end

-- Public snapshot sent to the owning client.
function PlayerDataManager.Snapshot(data)
	return {
		Points = data.Points,
		OwnedSkins = data.OwnedSkins,
		EquippedSkins = data.EquippedSkins,
		Stats = data.Stats,
		Settings = data.Settings,
	}
end

local function replicate(player: Player)
	local profile = profiles[player]
	if not profile or not player.Parent then
		return
	end
	player:SetAttribute("Points", profile.Data.Points)
	Net.Event("ProfileUpdate"):FireClient(player, PlayerDataManager.Snapshot(profile.Data))
	changedEvent:Fire(player, profile.Data)
end
PlayerDataManager.Replicate = replicate

local function loadProfile(player: Player)
	local key = keyFor(player)
	local loaded = nil
	local lastError = nil

	if store then
		-- Studio without API access fails every call: fall back to the temporary profile fast
		local attempts = RunService:IsStudio() and 2 or DATA.LoadAttempts
		for attempt = 1, attempts do
			if not player.Parent then
				return
			end
			local foreign = false
			local stealing = attempt == attempts
			local ok, err = pcall(function()
				store:UpdateAsync(key, function(old)
					if old and lockIsForeign(old.Lock) and not stealing then
						foreign = true
						return nil -- cancel write, wait for the other server to release
					end
					local data = type(old) == "table" and old or Util.DeepCopy(PlayerDataManager.Template)
					Util.Reconcile(data, PlayerDataManager.Template)
					data.Lock = { JobId = JOB_ID, Time = os.time() }
					loaded = Util.DeepCopy(data)
					return data
				end)
			end)
			if ok and loaded then
				break
			end
			loaded = nil
			lastError = ok and (foreign and "session locked by another server" or "no data") or err
			warn(string.format("[PlayerData] load attempt %d for %s failed: %s", attempt, player.Name, tostring(lastError)))
			if attempt < attempts then
				task.wait(RunService:IsStudio() and 0.5 or (foreign and 4 or math.min(2 ^ attempt, 10)))
			end
		end
	end

	if not player.Parent then
		return
	end

	local profile: Profile
	if loaded then
		loaded.Lock = nil
		profile = { Data = loaded, CanSave = true, Saving = false, Released = false, LastSave = os.clock() }
	elseif RunService:IsStudio() then
		warn("[PlayerData] Using a TEMPORARY, unsaved profile for " .. player.Name
			.. " (enable Studio API access in Game Settings > Security to test saving). Reason: "
			.. tostring(lastError or "DataStore unavailable"))
		local data = Util.DeepCopy(PlayerDataManager.Template)
		data.Points = 500 -- generous test balance so the skin shop can be tried in Studio
		profile = { Data = data, CanSave = false, Saving = false, Released = false, LastSave = os.clock() }
	else
		player:Kick("We couldn't load your saved progress (Roblox data services are having trouble). Your data is safe - please rejoin in a minute.")
		return
	end

	profiles[player] = profile
	player:SetAttribute("DataLoaded", true)
	replicate(player)
	loadedEvent:Fire(player, profile.Data)
end

-- Save the profile. `release` drops the session lock (leaving / teleporting).
function PlayerDataManager.Save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or not profile.CanSave or not store then
		return false
	end
	while profile.Saving do
		task.wait(0.1)
	end
	profile.Saving = true
	local snapshot = Util.DeepCopy(profile.Data)
	local success = false
	for attempt = 1, DATA.SaveAttempts do
		local blocked = false
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(old)
				if old and lockIsForeign(old.Lock) then
					blocked = true
					return nil -- another server owns this profile now; never overwrite it
				end
				local data = Util.DeepCopy(snapshot)
				data.Lock = (not release) and { JobId = JOB_ID, Time = os.time() } or nil
				return data
			end)
		end)
		if ok then
			success = not blocked
			if blocked then
				warn("[PlayerData] save for " .. player.Name .. " skipped: profile is locked by another server")
				profile.CanSave = false
			end
			break
		end
		warn(string.format("[PlayerData] save attempt %d for %s failed: %s", attempt, player.Name, tostring(err)))
		task.wait(math.min(2 ^ attempt, 8))
	end
	profile.Saving = false
	profile.LastSave = os.clock()
	if release and success then
		profile.Released = true
	end
	return success
end

-- Called before teleporting so the destination server can lock the profile immediately.
function PlayerDataManager.SaveAndRelease(player: Player): boolean
	return PlayerDataManager.Save(player, true)
end

-- After a failed teleport the player stays here: take the lock back.
function PlayerDataManager.Reacquire(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Released = false
		task.spawn(PlayerDataManager.Save, player, false)
	end
end

function PlayerDataManager.Get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

function PlayerDataManager.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function PlayerDataManager.WaitForData(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while player.Parent and not profiles[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	return PlayerDataManager.Get(player)
end

-- Mutate through this so the client is always told about changes.
function PlayerDataManager.Update(player: Player, mutator: (any) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutator(profile.Data)
	replicate(player)
	return true
end

-- Grant match rewards exactly once per (player, matchId). Returns points granted or nil.
function PlayerDataManager.ApplyMatchResult(player: Player, matchId: string, points: number, kills: number, deaths: number, place: number?)
	local profile = profiles[player]
	if not profile or type(matchId) ~= "string" then
		return nil
	end
	local data = profile.Data
	if table.find(data.ProcessedMatches, matchId) then
		return nil
	end
	table.insert(data.ProcessedMatches, matchId)
	while #data.ProcessedMatches > DATA.ProcessedMatchHistory do
		table.remove(data.ProcessedMatches, 1)
	end
	data.Points += math.max(0, math.floor(points))
	data.Stats.Kills += kills
	data.Stats.Deaths += deaths
	data.Stats.Matches += 1
	if place and place <= 3 then
		data.Stats.Podiums += 1
	end
	if place == 1 then
		data.Stats.Wins += 1
	end
	replicate(player)
	task.spawn(PlayerDataManager.Save, player, false)
	return points
end

function PlayerDataManager.CanSave(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.CanSave
end

function PlayerDataManager.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(loadProfile, p)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			if not profile.Released then
				PlayerDataManager.Save(player, true)
			end
			profiles[player] = nil
		end
	end)

	Net.Function("GetProfile").OnServerInvoke = function(player)
		local data = PlayerDataManager.WaitForData(player, 20)
		return data and PlayerDataManager.Snapshot(data) or nil
	end

	-- autosave
	task.spawn(function()
		while true do
			task.wait(DATA.AutosaveInterval)
			for player, profile in pairs(profiles) do
				if profile.CanSave and not profile.Released and player.Parent then
					task.spawn(PlayerDataManager.Save, player, false)
					task.wait(0.5)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in pairs(profiles) do
			if profile.CanSave and not profile.Released then
				pending += 1
				task.spawn(function()
					PlayerDataManager.Save(player, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerDataManager
