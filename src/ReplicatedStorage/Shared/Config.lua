--[[
	Config
	Central, designer-facing configuration. Every tunable number in the game lives here
	(match length, rewards, player limits, data store settings, sound ids...).
]]

local Config = {}

Config.GameName = "FRONTLINE: Five Fronts"

-- MATCH ------------------------------------------------------------------------------
Config.Match = {
	Duration = 600, -- seconds (exactly 10 minutes)
	PreRoundCountdown = 6, -- freeze-free warmup before the clock starts
	RespawnDelay = 3,
	SpawnProtection = 3, -- seconds of invulnerability after spawning (ends early if you shoot)
	ResultsDuration = 14, -- podium cinematic length
	PostMatchChoiceDuration = 20, -- time to pick "Return to Lobby" / "Play Again"
	MaxPlayers = 16,
	MaxTeamImbalance = 1, -- auto-balance kicks in when a team is ahead by more than this
}

-- LOBBY / MATCHMAKING ----------------------------------------------------------------
Config.Lobby = {
	QueueCountdown = 10, -- seconds after the first player steps on a pad
	MinPlayersToLaunch = 1, -- set to 2+ for live servers if you do not want solo matches
}

Config.Matchmaking = {
	-- "Auto": Studio / unpublished place => matches run inside the same server ("Local").
	--         Published place => each match gets its own reserved server ("Teleport").
	-- "Local" / "Teleport" force a mode.
	Mode = "Auto",
	-- Leave nil to use the current place for both lobby and matches (single-place universe).
	LobbyPlaceId = nil,
	MatchPlaceId = nil,
	LocalMapSpacing = 2500, -- studs between maps when several run in one server
	RegistryHeartbeat = 10, -- match servers publish their player count this often
	RegistryExpiry = 45,
}

-- REWARDS ----------------------------------------------------------------------------
Config.Rewards = {
	Placement = { 100, 60, 30 }, -- 1st, 2nd, 3rd
	Other = 0,
}

-- PLAYER -----------------------------------------------------------------------------
Config.Player = {
	MaxHealth = 100,
	BaseWalkSpeed = 16,
	JumpPower = 44,
}

-- TEAMS ------------------------------------------------------------------------------
Config.Teams = {
	Red = { Name = "Red Team", Short = "RED", Color = Color3.fromRGB(232, 72, 77) },
	Blue = { Name = "Blue Team", Short = "BLUE", Color = Color3.fromRGB(62, 142, 247) },
}

-- DATA -------------------------------------------------------------------------------
Config.Data = {
	StoreName = "FPS_PlayerData_v1",
	AutosaveInterval = 90,
	SessionLockTimeout = 240, -- a lock older than this is considered abandoned
	LoadAttempts = 6,
	SaveAttempts = 5,
	ProcessedMatchHistory = 60, -- remembered match ids (reward de-duplication)
}

-- SOUNDS -----------------------------------------------------------------------------
-- All sounds are built from audio files bundled with the Roblox client, so the game never
-- ships a dead asset link (see Shared/Sounds.lua). Paste your own uploaded/licensed audio ids
-- into Overrides to replace any of them, e.g. Overrides = { AK_Shot = "rbxassetid://123456" }.
Config.Sounds = {
	Overrides = {},
	PodiumMusicId = nil, -- e.g. "rbxassetid://..." ; falls back to the sequenced podium track
}

return Config
