-- Boots every client controller and drives the UI through a whole session.
local task = M.task
local V3, CF, V2 = M.Vector3, M.CFrame, M.Vector2
local workspace = M.workspace
local game = M.game

-- remotes must exist (server creates them)
local Net = H.module("ReplicatedStorage/Shared/Net.lua")
M.IsServer = false
local UIS = game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.MouseEnabled = false
UIS.KeyboardEnabled = false

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

H.section("Mobile controls")
me:SetAttribute("Team", "Blue")
toClient("MatchState", { Key = "k", MapId = "Maya", MapName = "Temple", State = "Live", EndsAt = workspace:GetServerTimeNow() + 600, Red = 1, Blue = 1, RedKills = 0, BlueKills = 0, Roster = {}, SpawnZones = { Red = { CFrame = CF.new(0, 6, -125), Size = V3.new(44, 12, 24) }, Blue = { CFrame = CF.new(0, 6, 125), Size = V3.new(44, 12, 24) } } })
toClient("Spawned", "Match")
toClient("WeaponState", { Loadout = { Primary = "M4A1S", Secondary = "USP", Melee = "Knife" }, Equipped = "Primary", Ammo = { Primary = { Mag = 20, Reserve = 80 }, Secondary = { Mag = 12, Reserve = 24 } }, Armed = true, Skins = {} })
frames(80)
local mc = pg:FindFirstChild("MobileControls")
H.check("touch layout built", mc ~= nil and pg:FindFirstChild("MobileAimPad") ~= nil)
H.check("touch layout visible in match", mc and mc.Enabled == true)
local function btn(text)
	for _, d in ipairs(mc:GetDescendants()) do
		if d.ClassName == "TextButton" and d.Text == text then
			return d
		end
	end
end
local touch = { UserInputType = M.Enum.UserInputType.Touch, Delta = V3.new(20, 0, 0), Position = V3.new(0, 0, 0) }
local fireBtn = btn("FIRE")
H.check("FIRE button", fireBtn ~= nil)
local f0 = sentCount("Fire")
fireBtn.InputBegan:Fire(touch)
M.run(0.01)
local yaw0 = select(2, cam.CFrame:ToEulerAnglesYXZ())
UIS.InputChanged:Fire(touch, false)
M.run(0.01)
local yaw1 = select(2, cam.CFrame:ToEulerAnglesYXZ())
frames(30)
fireBtn.InputEnded:Fire(touch)
M.run(0.01)
H.check("holding FIRE fires (auto)", sentCount("Fire") - f0 >= 3, sentCount("Fire") - f0)
H.check("dragging on FIRE also aims", math.abs(yaw1 - yaw0) > 0.01)
local reload = btn("R")
reload.InputBegan:Fire(touch)
reload.InputEnded:Fire(touch)
M.run(0.1)
H.check("RELOAD button", sentCount("Reload") >= 1)
frames(200)
local knife = btn("KNIFE")
knife.InputBegan:Fire(touch)
knife.InputEnded:Fire(touch)
frames(40)
H.check("KNIFE button equips knife", WeaponController.GetInfo().Slot == "Melee")
local swap = btn("SWAP")
swap.InputBegan:Fire(touch)
swap.InputEnded:Fire(touch)
frames(5)
H.check("SWAP cycles weapons", WeaponController.GetInfo().Slot ~= "Melee")
local tb = pg:FindFirstChild("TopbarButtons")
local shopBtn
for _, d in ipairs(tb:GetDescendants()) do
	if d.ClassName == "TextButton" and d.Text == "SHOP" then
		shopBtn = d
	end
end
H.check("SHOP button in the top bar on touch", shopBtn ~= nil and shopBtn.Visible)
me.Character:PivotTo(CF.new(0, 3, 125))
M.run(0.5)
shopBtn.Activated:Fire()
frames(2)
H.check("SHOP button opens weapon shop in spawn", pg.WeaponShop.Enabled == true)
frames(2)
H.check("mobile controls hidden while a menu is open", mc.Enabled == false)
H.check("no controller failed to start (no warnings)", (M.Warnings or 0) == 0, M.Warnings)
H.finish()
