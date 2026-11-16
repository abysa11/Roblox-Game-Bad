--[[
	Net
	Single place that declares every RemoteEvent / RemoteFunction.
	The server creates them in ReplicatedStorage.Remotes; clients wait for them.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local EVENTS = {
	-- server -> client
	"MatchState", -- match phase, timer, team counts
	"Notify", -- toast messages
	"WeaponState", -- loadout + equipped slot + ammo
	"AmmoUpdate", -- authoritative ammo for one slot
	"ShotFx", -- other players' shots (tracers, sounds)
	"HitConfirm", -- hit marker for the shooter
	"Damaged", -- damage direction for the victim
	"KillFeed",
	"Died", -- death screen info
	"Spawned",
	"Results", -- podium + rankings
	"PostMatchPrompt",
	"ProfileUpdate",
	"OpenSkinShop",
	"LobbyState",
	-- client -> server
	"EquipSlot",
	"Fire",
	"Reload",
	"Melee",
	"PostMatchChoice",
	"ScopeState",
}

local FUNCTIONS = {
	"GetProfile",
	"SetLoadout",
	"BuySkin",
	"EquipSkin",
	"SaveSettings",
}

local folder: Folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local cache = {}

function Net.Event(name: string): RemoteEvent
	local r = cache[name]
	if not r then
		r = folder:WaitForChild(name, 30)
		assert(r and r:IsA("RemoteEvent"), "Unknown RemoteEvent " .. name)
		cache[name] = r
	end
	return r
end

function Net.Function(name: string): RemoteFunction
	local r = cache[name]
	if not r then
		r = folder:WaitForChild(name, 30)
		assert(r and r:IsA("RemoteFunction"), "Unknown RemoteFunction " .. name)
		cache[name] = r
	end
	return r
end

-- Fire an event to a list of players (used for per-match broadcasts).
function Net.FireList(name: string, players: { Player }, ...)
	local r = Net.Event(name)
	for _, p in ipairs(players) do
		if p.Parent then
			r:FireClient(p, ...)
		end
	end
end

return Net
