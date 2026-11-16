--[[
	RewardManager
	Ranks a finished match and pays placement points exactly once.
	Ranking: kills (desc) -> deaths (asc) -> join order (asc, stable).
	De-duplication happens twice: per match id here, and per (player, match id) in the
	persistent profile, so leaving/rejoining or replaying remotes can never pay twice.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local RewardManager = {}

local paidMatches: { [string]: boolean } = {}

function RewardManager.Rank(match)
	local list = {}
	for player, stat in pairs(match.Players) do
		if player.Parent then
			table.insert(list, {
				Player = player,
				UserId = player.UserId,
				Name = player.Name,
				DisplayName = player.DisplayName,
				Team = stat.Team,
				Kills = stat.Kills,
				Deaths = stat.Deaths,
				JoinOrder = stat.JoinOrder,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.Kills ~= b.Kills then
			return a.Kills > b.Kills
		end
		if a.Deaths ~= b.Deaths then
			return a.Deaths < b.Deaths
		end
		return a.JoinOrder < b.JoinOrder
	end)
	for i, e in ipairs(list) do
		e.Place = i
	end
	return list
end

function RewardManager.PointsFor(place: number): number
	return Config.Rewards.Placement[place] or Config.Rewards.Other
end

-- Mutates ranking entries with .Points (what was actually granted).
function RewardManager.Grant(matchId: string, ranking)
	if paidMatches[matchId] then
		for _, e in ipairs(ranking) do
			e.Points = 0
		end
		return
	end
	paidMatches[matchId] = true
	for _, e in ipairs(ranking) do
		local points = RewardManager.PointsFor(e.Place)
		local granted = PlayerDataManager.ApplyMatchResult(e.Player, matchId, points, e.Kills, e.Deaths, e.Place)
		e.Points = granted or 0
	end
end

return RewardManager
