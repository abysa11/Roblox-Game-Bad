--[[
	MatchRegistry
	Cross-server discovery of running matches (Teleport mode only) through MemoryStoreService.
	Match servers publish { MapId, Code, Count, Max, Joinable } every few seconds with a short
	expiry, so crashed servers disappear automatically. Lobby servers read it to place new
	groups into running matches with free slots before reserving a new server.
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local MatchRegistry = {}

local map
local ok, err = pcall(function()
	map = MemoryStoreService:GetSortedMap("FPS_OpenMatches_v1")
end)
if not ok then
	warn("[MatchRegistry] MemoryStore unavailable: " .. tostring(err))
end

function MatchRegistry.Publish(serverId: string, entry)
	if not map then
		return
	end
	pcall(function()
		map:SetAsync(serverId, entry, Config.Matchmaking.RegistryExpiry)
	end)
end

function MatchRegistry.Remove(serverId: string)
	if not map then
		return
	end
	pcall(function()
		map:RemoveAsync(serverId)
	end)
end

-- Returns the reserved-server access code of a joinable match for mapId with room for `need`.
function MatchRegistry.FindOpen(mapId: string, need: number): string?
	if not map then
		return nil
	end
	local found = nil
	pcall(function()
		local items = map:GetRangeAsync(Enum.SortDirection.Ascending, 100)
		local best = -1
		for _, item in ipairs(items) do
			local v = item.value
			if type(v) == "table" and v.MapId == mapId and v.Joinable and type(v.Code) == "string" then
				local count = tonumber(v.Count) or 0
				local max = tonumber(v.Max) or Config.Match.MaxPlayers
				-- prefer the fullest match that still fits the group (keeps matches lively)
				if count + need <= max and count > best then
					best = count
					found = v.Code
				end
			end
		end
	end)
	return found
end

return MatchRegistry
