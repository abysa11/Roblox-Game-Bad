--[[
	TeamManager
	Red/Blue assignment and balancing for a match. Teams are stored per match (not with the
	global Teams service) so several matches can run in one server without mixing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local TeamManager = {}

function TeamManager.Count(match)
	local red, blue = 0, 0
	for _, stat in pairs(match.Players) do
		if stat.Team == "Red" then
			red += 1
		elseif stat.Team == "Blue" then
			blue += 1
		end
	end
	return red, blue
end

-- Smaller team, random on ties.
function TeamManager.PickTeam(match): string
	local red, blue = TeamManager.Count(match)
	if red < blue then
		return "Red"
	elseif blue < red then
		return "Blue"
	end
	return math.random() < 0.5 and "Red" or "Blue"
end

function TeamManager.SetTeam(player: Player, stat, team: string)
	stat.Team = team
	player:SetAttribute("Team", team)
	local info = Config.Teams[team]
	if info then
		player:SetAttribute("TeamColor", info.Color)
	end
end

-- Fresh, shuffled, alternating split for a new round.
function TeamManager.Rebalance(match)
	local list = {}
	for player in pairs(match.Players) do
		table.insert(list, player)
	end
	Util.Shuffle(list)
	local first = math.random() < 0.5 and "Red" or "Blue"
	local second = first == "Red" and "Blue" or "Red"
	for i, player in ipairs(list) do
		TeamManager.SetTeam(player, match.Players[player], (i % 2 == 1) and first or second)
	end
end

-- If teams are uneven by more than the allowed amount, returns the team that should lose a player.
function TeamManager.OverfullTeam(match): string?
	local red, blue = TeamManager.Count(match)
	if red - blue > Config.Match.MaxTeamImbalance then
		return "Red"
	elseif blue - red > Config.Match.MaxTeamImbalance then
		return "Blue"
	end
	return nil
end

function TeamManager.Other(team: string): string
	return team == "Red" and "Blue" or "Red"
end

return TeamManager
