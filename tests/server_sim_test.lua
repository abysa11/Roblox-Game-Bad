-- Full server simulation: boots Main.server.lua and plays through the whole game loop.
local task = M.task
local V3, CF = M.Vector3, M.CFrame
local workspace = M.workspace

M.runScript(H.Scripts["ServerScriptService/Main.server.lua"])
M.run(1)

local function S(name)
	return H.module("ServerScriptService/Services/" .. name .. ".lua")
end
local Net = H.module("ReplicatedStorage/Shared/Net.lua")
local Config = H.module("ReplicatedStorage/Shared/Config.lua")
local Util = H.module("ReplicatedStorage/Shared/Util.lua")
local PDM, MatchManager, LobbyService, WeaponServer = S("PlayerDataManager"), S("MatchManager"), S("LobbyService"), S("WeaponServer")

-- capture server -> client traffic
local sent = {}
local liveAt, liveEndsAt = nil, nil
M.OnClientFire = function(remote, player, ...)
	sent[remote] = sent[remote] or {}
	table.insert(sent[remote], { player = player, args = table.pack(...) })
	local payload = ...
	if remote == "MatchState" and type(payload) == "table" and payload.State == "Live" and not liveAt then
		liveAt, liveEndsAt = workspace:GetServerTimeNow(), payload.EndsAt
	end
end
local function lastSent(remote, player)
	local list = sent[remote] or {}
	for i = #list, 1, -1 do
		if list[i].player == player or list[i].player == "ALL" then
			return list[i].args
		end
	end
	return nil
end
local function fire(name, player, ...)
	Net.Event(name).OnServerEvent:Fire(player, ...)
end
local function invoke(name, player, ...)
	local fn = Net.Function(name).OnServerInvoke
	local result
	local co = coroutine.create(function(...)
		result = fn(...)
	end)
	M.resume(co, player, ...)
	while coroutine.status(co) ~= "dead" do
		M.run(0.05)
	end
	return result
end
local function place(player, pos, look)
	local char = player.Character
	char:PivotTo(look and CF.lookAt(pos, pos + look) or CF.new(pos))
end
local function hp(player)
	local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return h and h.Health or -1
end

H.section("Join + data load")
local A = M.AddPlayer("Alice", 101)
local B = M.AddPlayer("Bob", 102)
local C = M.AddPlayer("Cara", 103)
local D = M.AddPlayer("Dan", 104)
M.run(2)
for _, p in ipairs({ A, B, C, D }) do
	H.check(p.Name .. " data loaded", PDM.IsLoaded(p))
	H.check(p.Name .. " spawned in lobby", p.Character ~= nil and p:GetAttribute("Context") == "Lobby")
end

H.section("Map queues")
local forest = LobbyService.GetZone("Forest")
local egypt = LobbyService.GetZone("Egypt")
place(A, egypt.CFrame.Position)
M.run(0.5)
H.check("stepping on a pad queues you", A:GetAttribute("QueuedMap") == "Egypt")
place(A, forest.CFrame.Position)
M.run(0.5)
H.check("moving to another pad switches queue (never two queues)", A:GetAttribute("QueuedMap") == "Forest")
place(D, forest.CFrame.Position)
M.run(0.5)
place(D, LobbyService.GetSpawnCFrame().Position)
M.run(0.5)
H.check("stepping off the pad leaves the queue", D:GetAttribute("QueuedMap") == nil)
for _, p in ipairs({ B, C, D }) do
	place(p, forest.CFrame.Position + V3.new(math.random(-5, 5), 0, math.random(-5, 5)))
end
M.run(0.5)
H.check("4 players waiting on the Forest pad", forest.Count.Text:find("WAITING: 4") ~= nil, forest.Count.Text)
M.run(11)
local match = MatchManager.GetMatchOf(A)
H.check("queue launched a Forest match", match ~= nil and match.MapId == "Forest")
H.check("whole group in the same match", match and MatchManager.GetMatchOf(B) == match and MatchManager.GetMatchOf(C) == match and MatchManager.GetMatchOf(D) == match)

H.section("Teams + spawning")
M.run(1)
local red, blue = 0, 0
for _, p in ipairs({ A, B, C, D }) do
	local t = p:GetAttribute("Team")
	if t == "Red" then
		red += 1
	elseif t == "Blue" then
		blue += 1
	end
end
H.check("teams balanced 2v2", red == 2 and blue == 2, red .. "v" .. blue)
H.check("warmup phase", match.State == "Warmup", match.State)
for _, p in ipairs({ A, B, C, D }) do
	local zone = match.World.SpawnZones[p:GetAttribute("Team")]
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	H.check(p.Name .. " spawned in own team base", root and Util.InBox(root.Position, zone.CFrame, zone.Size + V3.new(2, 6, 2)))
	H.check(p.Name .. " got default USP-S + knife", WeaponServer.GetState(p).Loadout.Secondary == "USP" and WeaponServer.GetState(p).Loadout.Melee == "Knife" and WeaponServer.GetState(p).Loadout.Primary == nil)
end
M.run(Config.Match.PreRoundCountdown)
H.check("match goes live after warmup", match.State == "Live", match.State)
H.check("match timer is exactly 10 minutes", liveAt and math.abs((liveEndsAt - liveAt) - 600) < 0.01, liveAt and (liveEndsAt - liveAt))

-- pick teams
local mate, enemy, enemy2
for _, p in ipairs({ B, C, D }) do
	if p:GetAttribute("Team") == A:GetAttribute("Team") then
		mate = p
	elseif not enemy then
		enemy = p
	else
		enemy2 = p
	end
end

H.section("Weapon shop rules (server validated)")
local r = invoke("SetLoadout", A, { Primary = "AK47", Secondary = "Glock" })
H.check("AK-47 + Glock accepted in spawn", r and r.Ok, r and r.Message)
H.check("loadout applied", WeaponServer.GetState(A).Loadout.Primary == "AK47" and WeaponServer.GetState(A).Equipped == "Primary")
r = invoke("SetLoadout", A, { Primary = "AK47", Secondary = "AWP" })
H.check("sniper as pistol rejected", r and not r.Ok)
r = invoke("SetLoadout", A, { Primary = "Glock", Secondary = "USP" })
H.check("pistol as primary rejected", r and not r.Ok)
r = invoke("SetLoadout", A, { Primary = "Knife" })
H.check("knife cannot be bought", r and not r.Ok)
place(enemy, match.World.Origin.Position + V3.new(0, 3, 0))
r = invoke("SetLoadout", enemy, { Primary = "AWP" })
H.check("shop refused outside spawn", r and not r.Ok, r and r.Message)
r = invoke("SetLoadout", A, { Primary = "AK47", Secondary = "Glock" })

H.section("Shooting")
local origin = match.World.Origin.Position
place(A, origin + V3.new(0, 3, 20), V3.new(0, 0, -1))
place(enemy, origin + V3.new(0, 3, 0))
place(mate, origin + V3.new(6, 3, 10))
M.run(1.2) -- AK draw time
local function shoot(shooter, target, partName, opts)
	opts = opts or {}
	local head = shooter.Character.Head
	local part = target and target.Character:FindFirstChild(partName or "Head")
	local to = part and part.Position or (head.Position + V3.new(0, 0, -50))
	local dir = (to - head.Position).Unit
	fire("Fire", shooter, {
		Slot = opts.Slot or "Primary",
		Origin = opts.Origin or head.Position,
		Direction = dir,
		Hit = part,
		Position = opts.Position or to,
	})
end
local mag0 = WeaponServer.GetState(A).Ammo.Primary.Mag
shoot(A, mate, "UpperTorso")
H.check("no friendly fire", hp(mate) == 100, hp(mate))
M.run(0.15)
shoot(A, enemy, "UpperTorso", { Origin = A.Character.Head.Position + V3.new(0, 30, 0) })
H.check("spoofed origin rejected", hp(enemy) == 100, hp(enemy))
M.run(0.15)
shoot(A, enemy, "UpperTorso", { Position = enemy.Character.UpperTorso.Position + V3.new(0, 0, 40) })
H.check("hit far from the body part rejected", hp(enemy) == 100, hp(enemy))
M.run(0.15)
M.RaycastHook = function(o, d)
	return { Position = o + d * 0.5, Instance = workspace.Terrain, Normal = V3.new(0, 0, 1) }
end
shoot(A, enemy, "UpperTorso")
M.RaycastHook = nil
H.check("shot through a wall rejected", hp(enemy) == 100, hp(enemy))
M.run(0.15)
local before = WeaponServer.GetState(A).Ammo.Primary.Mag
for _ = 1, 25 do
	shoot(A, enemy, "LeftUpperLeg")
end
local after = WeaponServer.GetState(A).Ammo.Primary.Mag
H.check("rapid-fire exploit: 25 shots in one frame consume 1 bullet", before - after == 1, before - after)
H.check("one AK leg shot = 27 damage", hp(enemy) == 73, hp(enemy))
H.check("hit marker sent to shooter", lastSent("HitConfirm", A) ~= nil)
H.check("victim told damage direction", lastSent("Damaged", enemy) ~= nil)
M.run(0.15)
shoot(A, enemy, "Head")
H.check("AK headshot kills", hp(enemy) <= 0, hp(enemy))
H.check("kill credited (+1)", A:GetAttribute("Kills") == 1, A:GetAttribute("Kills"))
H.check("death counted", enemy:GetAttribute("Deaths") == 1)
local feed = lastSent("KillFeed", A)
H.check("kill feed broadcast", feed and feed[1].Headshot == true and feed[1].Killer == "Alice")
-- consumed: friendly-fire shot, far-hit shot, wall shot, 1 of 25 rapid shots, headshot (spoofed origin is dropped before ammo)
H.check("ammo tracked by server", WeaponServer.GetState(A).Ammo.Primary.Mag == mag0 - 5, WeaponServer.GetState(A).Ammo.Primary.Mag)
M.run(0.15)
shoot(A, enemy, "Head")
H.check("dead players can't be killed twice", A:GetAttribute("Kills") == 1)
local deadChar = enemy.Character
M.run(Config.Match.RespawnDelay + 0.3)
H.check("respawn after delay", enemy.Character ~= deadChar and hp(enemy) == 100)
H.check("respawned in own base", Util.InBox(enemy.Character.HumanoidRootPart.Position, match.World.SpawnZones[enemy:GetAttribute("Team")].CFrame, match.World.SpawnZones[enemy:GetAttribute("Team")].Size + V3.new(2, 6, 2)))
H.check("kill counter kept after death", A:GetAttribute("Kills") == 1)
place(enemy, origin + V3.new(0, 3, 0))
shoot(A, enemy, "Head")
H.check("spawn protection blocks damage", hp(enemy) == 100, hp(enemy))
M.run(Config.Match.SpawnProtection)

H.section("Reload")
local st = WeaponServer.GetState(A)
st.Ammo.Primary.Mag = 0
local reserve0 = st.Ammo.Primary.Reserve
M.run(0.2)
shoot(A, enemy, "UpperTorso")
H.check("empty magazine can't fire", hp(enemy) == 100)
fire("Reload", A, "Primary")
M.run(1)
shoot(A, enemy, "UpperTorso")
H.check("can't fire while reloading", hp(enemy) == 100)
M.run(1.6)
H.check("reload refills from reserve", st.Ammo.Primary.Mag == 30 and st.Ammo.Primary.Reserve == reserve0 - 30, st.Ammo.Primary.Mag .. "/" .. st.Ammo.Primary.Reserve)
H.check("client told ammo after reload", lastSent("AmmoUpdate", A) ~= nil)

H.section("Every weapon fires")
local WeaponData = H.module("ReplicatedStorage/WeaponModules/WeaponData.lua")
for _, combo in ipairs({ { "USP", nil }, { "Deagle", "M4A1S" }, { "Glock", "SCAR" }, { "USP", "AWP" }, { "USP", "AK47" } }) do
	place(A, match.World.Spawns[A:GetAttribute("Team")][1].Position + V3.new(0, 3, 0))
	local res = invoke("SetLoadout", A, { Secondary = combo[1], Primary = combo[2] })
	H.check("loadout " .. combo[1] .. " + " .. tostring(combo[2]), res and res.Ok, res and res.Message)
	M.run(1.3)
	for _, slot in ipairs({ "Primary", "Secondary" }) do
		local id = WeaponServer.GetState(A).Loadout[slot]
		if id then
			fire("EquipSlot", A, slot)
			M.run(1.3)
			local m0 = WeaponServer.GetState(A).Ammo[slot].Mag
			shoot(A, nil, nil, { Slot = slot })
			H.check(id .. " fires (server consumed ammo)", WeaponServer.GetState(A).Ammo[slot].Mag == m0 - 1)
			fire("Reload", A, slot)
			M.run(4)
			H.check(id .. " reloads", WeaponServer.GetState(A).Ammo[slot].Mag == WeaponData.Get(id).MagSize)
		end
	end
end
H.check("primary is a rifle OR sniper, never both", WeaponServer.GetState(A).Loadout.Primary == "AK47")

H.section("Burst fire + fire-rate cap")
place(A, match.World.Spawns[A:GetAttribute("Team")][1].Position + V3.new(0, 3, 0))
invoke("SetLoadout", A, { Secondary = "Glock" })
M.run(0.6)
fire("ScopeState", A, true) -- Glock burst toggle
local g0 = WeaponServer.GetState(A).Ammo.Secondary.Mag
for _ = 1, 3 do
	shoot(A, nil, nil, { Slot = "Secondary" })
	M.run(0.05)
end
H.check("Glock burst: 3 rounds in 0.15s accepted", g0 - WeaponServer.GetState(A).Ammo.Secondary.Mag == 3, g0 - WeaponServer.GetState(A).Ammo.Secondary.Mag)
fire("ScopeState", A, false)
M.run(1)
local g1 = WeaponServer.GetState(A).Ammo.Secondary.Mag
for _ = 1, 10 do
	shoot(A, nil, nil, { Slot = "Secondary" })
	M.run(0.02)
end
H.check("semi-auto speed hack capped", g1 - WeaponServer.GetState(A).Ammo.Secondary.Mag <= 2, g1 - WeaponServer.GetState(A).Ammo.Secondary.Mag)

H.section("Knife")
fire("EquipSlot", A, "Melee")
M.run(0.6)
place(A, origin + V3.new(30, 3, 0), V3.new(-1, 0, 0))
place(enemy, origin + V3.new(25, 3, 0), V3.new(0, 0, 1))
local k0 = hp(enemy)
fire("Melee", A, false, V3.new(-1, 0, 0))
H.check("knife slash hits for 40", k0 - hp(enemy) == 40, k0 - hp(enemy))
fire("Melee", A, false, V3.new(-1, 0, 0))
H.check("knife cooldown enforced", k0 - hp(enemy) == 40)
M.run(0.6)
fire("Melee", A, false, V3.new(1, 0, 0))
H.check("knife misses when facing away", k0 - hp(enemy) == 40)
place(enemy, origin + V3.new(60, 3, 0))
M.run(1.2)
fire("Melee", A, true, V3.new(-1, 0, 0))
H.check("knife out of range does nothing", k0 - hp(enemy) == 40)
H.check("knife can't be removed from the loadout", WeaponServer.GetState(A).Loadout.Melee == "Knife")

H.section("Joining a running match")
local E = M.AddPlayer("Eve", 105)
M.run(2)
place(E, forest.CFrame.Position)
M.run(11)
H.check("late joiner placed into the running Forest match", MatchManager.GetMatchOf(E) == match)
local red2, blue2 = 0, 0
for p, stat in pairs(match.Players) do
	if stat.Team == "Red" then
		red2 += 1
	else
		blue2 += 1
	end
end
H.check("teams stay within 1 player", math.abs(red2 - blue2) <= 1, red2 .. "v" .. blue2)
H.check("late joiner spawned", E.Character ~= nil and E:GetAttribute("Context") == "Match")

H.section("Match end, podium and rewards")
-- give Bob/Cara a kill each so the ranking is interesting
match:OnKill(mate, enemy, "USP", false)
M.run(math.max(0, match.EndsAt - workspace:GetServerTimeNow()) + 1)
H.check("match ends when the timer hits zero", match.State == "Results", match.State)
local results = lastSent("Results", A)
H.check("results broadcast", results ~= nil)
if results then
	local payload = results[1]
	H.check("podium has top 3", #payload.Podium == 3, #payload.Podium)
	H.check("1st place = most kills (Alice)", payload.Podium[1].UserId == 101, payload.Podium[1].DisplayName)
	H.check("2nd place = teammate with 1 kill", payload.Podium[2].UserId == mate.UserId)
	H.check("rankings list every player", #payload.Rankings == 5, #payload.Rankings)
	H.check("1st gets 100, 2nd 60, 3rd 30", payload.Podium[1].Points == 100 and payload.Podium[2].Points == 60 and payload.Podium[3].Points == 30)
	H.check("4th+ get 0", payload.Rankings[4].Points == 0)
	-- tie-break: among 0-kill players fewer deaths ranks higher
	local third = payload.Podium[3]
	H.check("tie broken by fewer deaths", third.Deaths <= payload.Rankings[4].Deaths, third.Deaths .. " vs " .. payload.Rankings[4].Deaths)
end
H.check("profile points saved for winner", PDM.Get(A).Points == 100, PDM.Get(A).Points)
H.check("players frozen during results", WeaponServer.GetState(A).Armed == false)
local mid = match.Id
H.check("reward can't be claimed twice", PDM.ApplyMatchResult(A, mid, 100, 0, 0, 1) == nil and PDM.Get(A).Points == 100)
shoot(A, mate, "Head")
H.check("no combat after the match", hp(mate) > 0)
M.run(1)
H.check("podium avatars spawned", #match.World.Podium.Avatars == 3, #match.World.Podium.Avatars)

H.section("Post-match choices")
M.run(Config.Match.ResultsDuration)
H.check("post-match menu phase", match.State == "PostMatch", match.State)
H.check("post-match prompt sent", lastSent("PostMatchPrompt", A) ~= nil)
fire("PostMatchChoice", A, "Lobby")
M.run(0.5)
H.check("RETURN TO LOBBY works", MatchManager.GetMatchOf(A) == nil and A:GetAttribute("Context") == "Lobby")
H.check("points kept after returning", PDM.Get(A).Points == 100)
fire("PostMatchChoice", mate, "Continue")
M.run(Config.Match.PostMatchChoiceDuration + 1)
H.check("PLAY AGAIN: new round on the same map", match.State == "Warmup" and MatchManager.GetMatchOf(mate) == match, match.State)
H.check("new match id", match.Id ~= mid)
H.check("stats reset for the new match", mate:GetAttribute("Kills") == 0)
H.check("undecided players stay", MatchManager.GetMatchOf(B) == match or MatchManager.GetMatchOf(C) == match)
H.check("loadout reset to default for new match", WeaponServer.GetState(mate).Loadout.Secondary == "USP" and WeaponServer.GetState(mate).Loadout.Primary == nil)

H.section("Skin shop")
r = invoke("BuySkin", A, "USP_Desert")
H.check("buy skin with enough points", r.Ok and PDM.Get(A).Points == 60, r.Message)
r = invoke("BuySkin", A, "USP_Desert")
H.check("can't buy the same skin twice", not r.Ok and PDM.Get(A).Points == 60)
r = invoke("BuySkin", A, "AK47_Gold")
H.check("insufficient points rejected", not r.Ok and PDM.Get(A).Points == 60)
r = invoke("BuySkin", A, "NotARealSkin")
H.check("unknown skin rejected", not r.Ok)
r = invoke("BuySkin", A, { "exploit" })
H.check("bad argument type rejected", not r.Ok)
r = invoke("EquipSkin", A, "USP", "USP_Desert")
H.check("equip owned skin", r.Ok and PDM.Get(A).EquippedSkins.USP == "USP_Desert")
r = invoke("EquipSkin", A, "AK47", "USP_Desert")
H.check("skin can't go on another weapon", not r.Ok)
r = invoke("EquipSkin", A, "AK47", "AK47_Neon")
H.check("unowned skin can't be equipped", not r.Ok)
r = invoke("EquipSkin", A, "USP", nil)
H.check("unequip back to default", r.Ok and PDM.Get(A).EquippedSkins.USP == nil)
invoke("EquipSkin", A, "USP", "USP_Desert")
r = invoke("BuySkin", mate, "USP_Desert")
H.check("skin shop locked during a match", not r.Ok)

H.section("Settings")
H.check("valid settings saved", invoke("SaveSettings", A, { MouseSensitivity = 2.5, CrosshairColor = "Cyan", Effects = "Low" }) == true)
H.check("settings clamped", PDM.Get(A).Settings.MouseSensitivity == 2.5 and PDM.Get(A).Settings.CrosshairColor == "Cyan")
M.run(1.1)
invoke("SaveSettings", A, { MouseSensitivity = 999, CrosshairColor = "Rainbow" })
H.check("out-of-range values clamped / ignored", PDM.Get(A).Settings.MouseSensitivity == 4 and PDM.Get(A).Settings.CrosshairColor == "Cyan")

H.section("Persistence across sessions")
M.RemovePlayer(A)
M.run(2)
local saved = M.DataStoreData[Config.Data.StoreName]["u_101"]
H.check("saved on leave", saved and saved.Points == 60 and saved.OwnedSkins.USP_Desert == true)
H.check("session lock released on leave", saved and saved.Lock == nil)
local A2 = M.AddPlayer("Alice", 101)
M.run(2)
H.check("points restored next session", PDM.Get(A2) and PDM.Get(A2).Points == 60)
H.check("skins restored next session", PDM.Get(A2) and PDM.Get(A2).OwnedSkins.USP_Desert and PDM.Get(A2).EquippedSkins.USP == "USP_Desert")
H.check("settings restored", PDM.Get(A2) and PDM.Get(A2).Settings.Effects == "Low")

H.section("DataStore outage never overwrites data")
M.RemovePlayer(A2)
M.run(2)
local snapshot = M.deepcopy(M.DataStoreData[Config.Data.StoreName]["u_101"])
M.IsStudio = false
M.DataStoreFail = true
local A3 = M.AddPlayer("Alice", 101)
M.run(80)
H.check("player kicked with a message when data can't load", M.Kicked and #M.Kicked > 0 and M.Kicked[#M.Kicked].player == A3)
M.DataStoreFail = false
M.run(2)
local now = M.DataStoreData[Config.Data.StoreName]["u_101"]
H.check("stored data untouched by the failure", now.Points == snapshot.Points and now.OwnedSkins.USP_Desert == true)
M.IsStudio = true

H.section("Everyone leaves -> match closes")
for _, p in ipairs({ B, C, D, E }) do
	if p.Parent then
		M.RemovePlayer(p)
	end
end
M.run(60)
H.check("empty match closed and map removed", match.Closed and match.World.Model.Parent == nil)

H.finish()
