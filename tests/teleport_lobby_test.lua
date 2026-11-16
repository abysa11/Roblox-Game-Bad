-- Published-game lobby server: queues must reserve a server and teleport the group.
local task = M.task
local V3 = M.Vector3
local workspace = M.workspace
M.IsStudio = false
M.game.PlaceId = 777
M.game.JobId = "lobby-job"
M.runScript(H.Scripts["ServerScriptService/Main.server.lua"])
M.run(1)
H.section("Teleport-mode lobby")
H.check("server role is Lobby", workspace:GetAttribute("ServerRole") == "Lobby")
H.check("mode is Teleport", workspace:GetAttribute("MatchmakingMode") == "Teleport")
local LobbyService = H.module("ServerScriptService/Services/LobbyService.lua")
local Config = H.module("ReplicatedStorage/Shared/Config.lua")
local A = M.AddPlayer("Alice", 201)
local B = M.AddPlayer("Bob", 202)
M.run(2)
local zone = LobbyService.GetZone("Maya")
A.Character:PivotTo(M.CFrame.new(zone.CFrame.Position))
B.Character:PivotTo(M.CFrame.new(zone.CFrame.Position + V3.new(3, 0, 0)))
M.run(12)
local tp = M.Teleports and M.Teleports[1]
H.check("group teleported together", tp ~= nil and #tp.players == 2)
H.check("teleport to the match place", tp and tp.placeId == 777)
local saved = M.DataStoreData[Config.Data.StoreName]["u_201"]
H.check("profile saved and lock released before teleport", saved and saved.Lock == nil)
H.finish()
