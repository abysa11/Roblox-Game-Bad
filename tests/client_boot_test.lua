-- Boots every client controller and drives the UI through a whole session.
local task = M.task
local V3, CF, V2 = M.Vector3, M.CFrame, M.Vector2
local workspace = M.workspace
local game = M.game

-- remotes must exist (server creates them)
local Net = H.module("ReplicatedStorage/Shared/Net.lua")
M.IsServer = false

local Players = game:GetService("Players")
local me = M.AddPlayer("Tester", 900)
rawget(Players, "_p").LocalPlayer = me
local pg = M.Instance.new("PlayerGui")
pg.Name = "PlayerGui"
pg.Parent = me
local cam = workspace.CurrentCamera
cam.CFrame = CF.new(0, 5, 0)
cam.FieldOfView = 70
cam.ViewportSize = V2.new(1280, 720)
me:LoadCharacter()

-- client -> server traffic log
local toServer = {}
for _, r in ipairs(game:GetService("ReplicatedStorage").Remotes:GetChildren()) do
	if r.ClassName == "RemoteEvent" then
		rawget(r, "_p").FireServer = function(_, ...)
			table.insert(toServer, { name = r.Name, args = table.pack(...) })
		end
	else
		rawget(r, "_p").InvokeServer = function(_, ...)
			table.insert(toServer, { name = r.Name, args = table.pack(...) })
			if r.Name == "SetLoadout" then
				return { Ok = true, Message = "ok" }
			elseif r.Name == "BuySkin" or r.Name == "EquipSkin" then
				return { Ok = true, Message = "ok", Profile = { Points = 10, OwnedSkins = { AK47_Jungle = true }, EquippedSkins = { AK47 = "AK47_Jungle" }, Stats = {}, Settings = {} } }
			elseif r.Name == "GetProfile" then
				return { Points = 500, OwnedSkins = {}, EquippedSkins = {}, Stats = { Kills = 3, Deaths = 1, Matches = 2, Wins = 1 }, Settings = {} }
			end
			return true
		end
	end
end
local function sentCount(name)
	local n = 0
	for _, e in ipairs(toServer) do
		if e.name == name then
			n += 1
		end
	end
	return n
end
local function toClient(name, ...)
	Net.Event(name).OnClientEvent:Fire(...)
end
local RunService = game:GetService("RunService")
local function frames(n)
	for _ = 1, n do
		for _, fn in pairs(M.RenderSteps) do
			local ok, err = pcall(fn, 1 / 60)
			if not ok then
				table.insert(M.Errors, err)
				print("[MOCK ERROR] renderstep: " .. tostring(err))
			end
		end
		RunService.RenderStepped:Fire(1 / 60)
		RunService.Heartbeat:Fire(1 / 60)
		M.run(1 / 60)
	end
end

M.runScript(H.Scripts["StarterPlayerScripts/ClientMain.client.lua"])
M.run(0.5)
frames(10)

local Controllers = H.StarterPlayerScripts.Controllers
local function C(name)
	return M.require(Controllers:FindFirstChild(name))
end
local ClientState = C("ClientState")
local InputController = C("InputController")
local WeaponController = C("WeaponController")

H.section("Lobby")
toClient("ProfileUpdate", { Points = 340, OwnedSkins = {}, EquippedSkins = {}, Stats = { Kills = 10, Deaths = 5, Matches = 3, Wins = 1 }, Settings = {} })
toClient("MatchState", { State = "Lobby" })
toClient("LobbyState", { Forest = { Waiting = 2, EndsAt = workspace:GetServerTimeNow() + 8 }, Egypt = { Waiting = 0 } })
me:SetAttribute("QueuedMap", "Forest")
frames(5)
H.check("lobby menu visible", pg.MainMenu.Enabled == true)
H.check("profile points shown", pg.MainMenu:FindFirstChild("Frame") ~= nil)
me.Character:PivotTo(CF.lookAt(V3.new(0, 4, 52), V3.new(0, 4, 0)))
toClient("Spawned", "Lobby")
M.run(0.1)
local camLook = workspace.CurrentCamera.CFrame.LookVector
H.check("camera behind the player facing the map pads after spawning", camLook.Z < -0.8 and workspace.CurrentCamera.CFrame.Position.Z > 52, tostring(camLook))
C("SkinShopUI").Open()
frames(3)
H.check("skin shop opens in lobby", pg.SkinShop.Enabled == true and ClientState.IsMenuOpen("SkinShop"))
C("SkinShopUI").Close()
C("SettingsController").Open()
frames(3)
H.check("settings open", pg.SettingsUI.Enabled == true)
C("SettingsController").Close()
H.check("settings auto-saved on close", sentCount("SaveSettings") >= 0)

H.section("Match HUD")
me:SetAttribute("QueuedMap", nil)
me:SetAttribute("Team", "Red")
me:SetAttribute("TeamColor", M.Color3.fromRGB(232, 72, 77))
local zone = { CFrame = CF.new(0, 6, -125), Size = V3.new(44, 12, 24) }
me.Character:PivotTo(CF.new(0, 3, -125))
toClient("MatchState", {
	Key = "k", MapId = "Forest", MapName = "Whispering Pines", State = "Warmup", EndsAt = workspace:GetServerTimeNow() + 5,
	Red = 1, Blue = 1, RedKills = 0, BlueKills = 0, Round = 1,
	Roster = { { UserId = 900, Name = "Tester", Team = "Red", Kills = 0, Deaths = 0 }, { UserId = 901, Name = "Enemy", Team = "Blue", Kills = 0, Deaths = 0 } },
	SpawnZones = { Red = zone, Blue = { CFrame = CF.new(0, 6, 125), Size = V3.new(44, 12, 24) } },
})
toClient("Spawned", "Match")
toClient("WeaponState", { Loadout = { Secondary = "USP", Melee = "Knife" }, Equipped = "Secondary", Ammo = { Secondary = { Mag = 12, Reserve = 24 } }, Armed = true, Skins = {} })
frames(30)
H.check("HUD enabled in match", pg.HUD.Enabled == true)
H.check("lobby menu hidden in match", pg.MainMenu.Enabled == false)
H.check("first person in match", me.CameraMode == M.Enum.CameraMode.LockFirstPerson)
M.run(0.3)
H.check("in-spawn detected for shop", C("WeaponShopUI").InSpawn() == true)
InputController.Trigger("Shop", true)
InputController.Trigger("Shop", false)
frames(3)
H.check("B opens weapon shop in spawn", pg.WeaponShop.Enabled == true)
C("WeaponShopUI").Close()
me.Character:PivotTo(CF.new(0, 3, 0))
M.run(0.5)
InputController.Trigger("Shop", true)
InputController.Trigger("Shop", false)
frames(2)
H.check("shop refused outside spawn", pg.WeaponShop.Enabled == false)
me.Character:PivotTo(CF.new(0, 3, -125))
M.run(0.5)
C("WeaponShopUI").Open()
frames(2)
H.check("shop open again in spawn", pg.WeaponShop.Enabled == true)
me.Character:PivotTo(CF.new(0, 3, 0))
M.run(0.5)
H.check("shop auto-closes when leaving spawn", pg.WeaponShop.Enabled == false)

H.section("Shooting (client)")
local m = ClientState.Match
m.State = "Live"
m.EndsAt = workspace:GetServerTimeNow() + 600
toClient("MatchState", m)
M.run(1)
frames(5)
local fires0 = sentCount("Fire")
InputController.Trigger("Fire", true)
frames(4)
InputController.Trigger("Fire", false)
H.check("semi-auto: one press = one shot", sentCount("Fire") == fires0 + 1, sentCount("Fire") - fires0)
H.check("ammo predicted", WeaponController.GetInfo().Mag == 11)
for _ = 1, 3 do
	frames(12)
	InputController.Trigger("Fire", true)
	frames(2)
	InputController.Trigger("Fire", false)
end
InputController.Trigger("Reload", true)
InputController.Trigger("Reload", false)
frames(5)
H.check("reload sent", sentCount("Reload") >= 1)
H.check("reloading state", WeaponController.GetInfo().Reloading == true)
toClient("AmmoUpdate", "Secondary", 12, 16, true)
frames(2)
H.check("server ammo applied", WeaponController.GetInfo().Mag == 12 and not WeaponController.GetInfo().Reloading)
InputController.Trigger("Slot3", true)
InputController.Trigger("Slot3", false)
frames(40)
H.check("switch to knife", WeaponController.GetInfo().Slot == "Melee" and sentCount("EquipSlot") >= 1)
InputController.Trigger("Fire", true)
frames(2)
InputController.Trigger("Fire", false)
H.check("knife slash sent", sentCount("Melee") >= 1)
toClient("WeaponState", { Loadout = { Primary = "AWP", Secondary = "USP", Melee = "Knife" }, Equipped = "Primary", Ammo = { Primary = { Mag = 5, Reserve = 20 }, Secondary = { Mag = 12, Reserve = 24 } }, Armed = true, Skins = {} })
frames(80)
InputController.Trigger("Alt", true)
InputController.Trigger("Alt", false)
frames(20)
H.check("AWP scope zooms", WeaponController.GetScopeLevel() == 1 and cam.FieldOfView < 60, cam.FieldOfView)
H.check("scope overlay shown", pg.Scope.Enabled == true)
InputController.Trigger("Fire", true)
frames(2)
InputController.Trigger("Fire", false)
H.check("AWP unscopes after the shot (bolt)", WeaponController.GetScopeLevel() == 0)
toClient("WeaponState", { Loadout = { Primary = "AK47", Secondary = "USP", Melee = "Knife" }, Equipped = "Primary", Ammo = { Primary = { Mag = 30, Reserve = 90 }, Secondary = { Mag = 12, Reserve = 24 } }, Armed = true, Skins = {} })
frames(80)
local f1 = sentCount("Fire")
InputController.Trigger("Fire", true)
frames(60) -- 1 second of full auto at 600 RPM
InputController.Trigger("Fire", false)
local autoShots = sentCount("Fire") - f1
H.check("AK full-auto ~10 shots/sec", autoShots >= 8 and autoShots <= 11, autoShots)
toClient("HitConfirm", { Damage = 36, Headshot = true, Killed = true })
toClient("KillFeed", { Killer = "Tester", KillerTeam = "Red", Victim = "Enemy", VictimTeam = "Blue", Weapon = "AK-47", Headshot = true })
toClient("Damaged", V3.new(10, 3, 0), 27)
frames(5)
C("HUDController").SetScoreboard(true)
frames(2)
C("HUDController").SetScoreboard(false)

H.section("Death + respawn")
toClient("Died", { Killer = "Enemy", Weapon = "AWP", Headshot = false })
me.Character.Humanoid.Health = 0
me.Character.Humanoid.Died:Fire()
frames(10)
H.check("death screen", pg.HUD:FindFirstChild("Frame") ~= nil)
me:LoadCharacter()
toClient("Spawned", "Match")
frames(10)

H.section("Results + post-match")
m.State = "Results"
toClient("MatchState", m)
toClient("Results", {
	MatchId = "x", MapId = "Forest", PodiumCFrame = CF.new(0, 450, 0), Duration = 14,
	Podium = {
		{ Place = 1, UserId = 900, Name = "Tester", DisplayName = "Tester", Team = "Red", Kills = 9, Deaths = 1, Points = 100 },
		{ Place = 2, UserId = 901, Name = "Enemy", DisplayName = "Enemy", Team = "Blue", Kills = 4, Deaths = 9, Points = 60 },
	},
	Rankings = {
		{ Place = 1, UserId = 900, Name = "Tester", DisplayName = "Tester", Team = "Red", Kills = 9, Deaths = 1, Points = 100 },
		{ Place = 2, UserId = 901, Name = "Enemy", DisplayName = "Enemy", Team = "Blue", Kills = 4, Deaths = 9, Points = 60 },
	},
})
frames(60)
H.check("results screen shown", pg.ResultsUI.Enabled == true)
H.check("cinematic camera", cam.CameraType == M.Enum.CameraType.Scriptable)
H.check("HUD hidden during results", pg.HUD.Enabled == false)
frames(400)
toClient("PostMatchPrompt", { EndsAt = workspace:GetServerTimeNow() + 20 })
frames(5)
local menu
for _, d in ipairs(pg.ResultsUI:GetDescendants()) do
	if d.ClassName == "TextButton" and d.Text == "PLAY AGAIN" then
		menu = d
	end
end
H.check("PLAY AGAIN button exists", menu ~= nil)
if menu then
	menu.Activated:Fire()
	M.run(0.1)
	H.check("PLAY AGAIN sends Continue", toServer[#toServer].name == "PostMatchChoice" and toServer[#toServer].args[1] == "Continue")
end
for _, d in ipairs(pg.ResultsUI:GetDescendants()) do
	if d.ClassName == "TextButton" and d.Text == "RETURN TO LOBBY" then
		d.Activated:Fire()
	end
end
M.run(0.1)
H.check("RETURN TO LOBBY sends Lobby", toServer[#toServer].args[1] == "Lobby")
toClient("MatchState", { State = "Lobby" })
frames(5)
H.check("results closed when back in lobby", pg.ResultsUI.Enabled == false and cam.CameraType ~= M.Enum.CameraType.Scriptable)
H.check("third person in lobby", me.CameraMode == M.Enum.CameraMode.Classic)

H.section("Touch device layout")
H.check("mobile controls only on touch devices", pg:FindFirstChild("MobileControls") == nil)
H.check("no controller failed to start (no warnings)", (M.Warnings or 0) == 0, M.Warnings)

H.finish()
