-- Reserved match server: builds the requested map, runs the match, returns players by teleport.
local task = M.task
local workspace = M.workspace
M.IsStudio = false
M.game.PlaceId = 777
M.game.JobId = "match-job"
M.game.PrivateServerId = "ps-1"
M.game.PrivateServerOwnerId = 0
M.runScript(H.Scripts["ServerScriptService/Main.server.lua"])
M.run(1)
H.section("Reserved match server")
H.check("server role is Match", workspace:GetAttribute("ServerRole") == "Match")
local MatchManager = H.module("ServerScriptService/Services/MatchManager.lua")
local Config = H.module("ReplicatedStorage/Shared/Config.lua")
local A = M.AddPlayer("Alice", 301, { TeleportData = { MapId = "Egypt", Code = "CODE-1" } })
local B = M.AddPlayer("Bob", 302, { TeleportData = { MapId = "Egypt", Code = "CODE-1" } })
M.run(3)
local match = MatchManager.GetMatchOf(A)
H.check("match created for the requested map", match ~= nil and match.MapId == "Egypt")
H.check("both players in it", MatchManager.GetMatchOf(B) == match)
H.check("no lobby built on match servers", workspace:FindFirstChild("Lobby") == nil)
M.run(Config.Match.PreRoundCountdown + 1)
H.check("match live", match.State == "Live")
M.run(Config.Match.Duration + Config.Match.ResultsDuration + 1)
H.check("post-match on match server", match.State == "PostMatch", match.State)
local Net = H.module("ReplicatedStorage/Shared/Net.lua")
Net.Event("PostMatchChoice").OnServerEvent:Fire(A, "Lobby")
M.run(1)
local tp = M.Teleports and M.Teleports[1]
H.check("RETURN TO LOBBY teleports back to the lobby place", tp ~= nil and tp.players[1] == A and tp.placeId == 777)
H.check("rewards saved before leaving", M.DataStoreData[Config.Data.StoreName]["u_301"].Stats.Matches == 1)
H.finish()
