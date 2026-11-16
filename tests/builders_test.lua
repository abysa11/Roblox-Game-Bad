-- Executes every geometry builder (lobby, 5 maps, podium) and every weapon model + skin.
local task = M.task
local Vector3, CFrame = M.Vector3, M.CFrame

H.section("Weapon models and skins")
local WeaponData = H.module("ReplicatedStorage/WeaponModules/WeaponData.lua")
local WeaponModels = H.module("ReplicatedStorage/WeaponModules/WeaponModels.lua")
local SkinData = H.module("ReplicatedStorage/Shared/SkinData.lua")
for id, w in pairs(WeaponData.Weapons) do
	local ok, model = pcall(WeaponModels.Build, id, nil)
	H.check("build " .. id, ok and model and model.PrimaryPart ~= nil, model)
	if ok then
		local muzzle = model.PrimaryPart:FindFirstChild("Muzzle")
		H.check(id .. " has muzzle + left hand", muzzle ~= nil and model.PrimaryPart:FindFirstChild("LeftHand") ~= nil)
		if w.MagSize then
			H.check(id .. " has animatable magazine", model:FindFirstChild("Mag") ~= nil and model.Mag:FindFirstChild("MagWeld") ~= nil)
		end
	end
	for _, skin in ipairs(SkinData.ForWeapon(id)) do
		local ok2, err = pcall(WeaponModels.Build, id, skin.Id)
		if not ok2 then
			H.check("skin " .. skin.Id, false, err)
		end
	end
	H.check(id .. " has skins", #SkinData.ForWeapon(id) >= 3)
end

H.section("Maps")
local MapData = H.module("ReplicatedStorage/Shared/MapData.lua")
local MapLoader = H.module("ServerScriptService/Builders/MapLoader.lua")
local Util = H.module("ReplicatedStorage/Shared/Util.lua")
for i, mapId in ipairs(MapData.Order) do
	H.async(function()
		local origin = CFrame.new(i * 2500, 0, 0)
		local ok, world = pcall(MapLoader.Load, mapId, origin)
		H.check(mapId .. " builds", ok, world)
		if not ok then
			return
		end
		local parts = 0
		for _, d in ipairs(world.Model:GetDescendants()) do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		print(string.format("     %s: %d parts", mapId, parts))
		H.check(mapId .. " is detailed (>800 parts)", parts > 800, parts)
		H.check(mapId .. " stays under part budget (<9000)", parts < 9000, parts)
		for _, team in ipairs({ "Red", "Blue" }) do
			local spawns = world.Spawns[team]
			local zone = world.SpawnZones[team]
			H.check(mapId .. " " .. team .. " has 10 spawns", #spawns == 10, #spawns)
			local inside = true
			for _, cf in ipairs(spawns) do
				if not Util.InBox(cf.Position + Vector3.new(0, 3, 0), zone.CFrame, zone.Size + Vector3.new(2, 6, 2)) then
					inside = false
				end
				local localPos = origin:PointToObjectSpace(cf.Position)
				if math.abs(localPos.X) > 120 or math.abs(localPos.Z) > 140 then
					inside = false
				end
			end
			H.check(mapId .. " " .. team .. " spawns inside shop zone and bounds", inside)
			-- spawns face the enemy side
			local look = spawns[1].LookVector
			H.check(mapId .. " " .. team .. " spawns face the map centre", (team == "Red" and look.Z > 0.9) or (team == "Blue" and look.Z < -0.9), tostring(look))
		end
		local red = origin:PointToObjectSpace(world.Spawns.Red[1].Position)
		local blue = origin:PointToObjectSpace(world.Spawns.Blue[1].Position)
		H.check(mapId .. " bases are far apart", (red - blue).Magnitude > 200)
		H.check(mapId .. " has podium", world.Podium ~= nil and world.Podium.Model.Parent ~= nil)
		-- podium show with 3 entries (avatars fall back to description rigs in the mock)
		world.Podium:Show({
			{ Place = 1, UserId = 1, DisplayName = "A", Kills = 9 },
			{ Place = 2, UserId = 2, DisplayName = "B", Kills = 5 },
			{ Place = 3, UserId = 3, DisplayName = "C", Kills = 2 },
		})
		task.wait(1)
		H.check(mapId .. " podium shows 3 avatars", #world.Podium.Avatars == 3, #world.Podium.Avatars)
		world.Podium:Clear()
		world.Destroy()
		task.wait(1.1)
		H.check(mapId .. " destroys cleanly", world.Model.Parent == nil)
	end)
end

H.section("Lobby")
H.async(function()
	local LobbyBuilder = H.module("ServerScriptService/Builders/LobbyBuilder.lua")
	local ok, lobby = pcall(LobbyBuilder.Build, M.workspace)
	H.check("lobby builds", ok, lobby)
	if ok then
		local n = 0
		for id, zone in pairs(lobby.Zones) do
			n += 1
			H.check("zone " .. id .. " has live sign", zone.Count ~= nil and zone.Status ~= nil)
			H.check("zone " .. id .. " does not contain the spawn", not Util.InBox(lobby.SpawnCFrame.Position, zone.CFrame, zone.Size))
		end
		H.check("5 map zones", n == 5, n)
		-- zones must not overlap each other
		local list = {}
		for _, z in pairs(lobby.Zones) do
			table.insert(list, z)
		end
		local overlap = false
		for a = 1, #list do
			for b = a + 1, #list do
				if (list[a].CFrame.Position - list[b].CFrame.Position).Magnitude < 32 then
					overlap = true
				end
			end
		end
		H.check("map zones are separate", not overlap)
		H.check("skin shop prompt exists", lobby.SkinShopPrompt ~= nil)
	end
end)

H.finish()
