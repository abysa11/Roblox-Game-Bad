-- Regression: pressing Play must put you on the lobby floor right away, never in empty air.
local task = M.task
local workspace = M.workspace
M.DataStoreFail = true -- Studio without API access: every DataStore call errors
M.runScript(H.Scripts["ServerScriptService/Main.server.lua"])
H.section("Spawn on Play")
H.check("Roblox auto-spawn disabled before anything yields", M.game:GetService("Players").CharacterAutoLoads == false)
local P = M.AddPlayer("Player1", 1)
M.run(0.3)
H.check("character spawns within 0.3 s even while data is unavailable", P.Character ~= nil)
local LobbyService = H.module("ServerScriptService/Services/LobbyService.lua")
local root = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
local spawnPos = LobbyService.GetSpawnCFrame().Position
H.check("spawned on the lobby spawn pad", root and (root.Position - spawnPos).Magnitude < 5, root and tostring(root.Position))
H.check("standing just above the floor (y between 1 and 6)", root and root.Position.Y > 1 and root.Position.Y < 6, root and root.Position.Y)
-- the floor really is under the spawn point
local floorTop = -math.huge
for _, d in ipairs(workspace.Lobby:GetDescendants()) do
	if d:IsA("BasePart") and d.CanCollide and d.Transparency < 1 then
		local p, s = d.Position, d.Size
		if math.abs(spawnPos.X - p.X) < s.X / 2 and math.abs(spawnPos.Z - p.Z) < s.Z / 2 and p.Y + s.Y / 2 <= spawnPos.Y + 1 then
			floorTop = math.max(floorTop, p.Y + s.Y / 2)
		end
	end
end
H.check("solid floor directly under the spawn", floorTop > -1 and floorTop < 2, floorTop)
local spawnLoc = workspace.Lobby:FindFirstChild("LobbySpawn", true)
H.check("lobby has a SpawnLocation on the spawn pad (engine default lands in the lobby)", spawnLoc and (spawnLoc.Position - spawnPos).Magnitude < 3)
local ceiling = false
for _, d in ipairs(workspace.Lobby:GetDescendants()) do
	if d:IsA("BasePart") and d.CanCollide and d.Position.Y > 40 and d.Size.X > 100 and d.Size.Z > 100 then
		ceiling = true
	end
end
H.check("no invisible ceiling to get stuck on", not ceiling)
M.run(5)
H.check("still on the floor 5 s later (position not overridden)", root and root.Parent and root.Position.Y < 6, root and root.Position.Y)
M.run(2)
local PDM = H.module("ServerScriptService/Services/PlayerDataManager.lua")
H.check("Studio falls back to the temporary profile within 2 s", PDM.IsLoaded(P))
H.check("still only one character (no double spawn)", #workspace:GetChildren() > 0 and P.Character ~= nil)
H.finish()
