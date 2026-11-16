--[[
	CombatServer
	Validates every shot and knife attack, applies damage and credits kills.

	Shot validation (client sends: slot, origin, direction, claimed hit part, hit position):
	  1. WeaponServer.TryConsumeShot: alive, armed, right slot, ammo, fire rate, reload, draw time.
	  2. Origin must be near the shooter's head on the server.
	  3. Direction must be a unit vector and point at the claimed hit position.
	  4. Target must be an enemy in the same match, alive and not spawn protected.
	  5. Claimed hit must be close to where the server sees that body part (lag tolerance).
	  6. No map geometry may block the line from origin to the hit position.
	  7. Damage is computed here from WeaponData (never sent by the client).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)
local WeaponData = require(ReplicatedStorage.WeaponModules.WeaponData)
local WeaponServer = require(script.Parent.WeaponServer)
local SpawnManager = require(script.Parent.SpawnManager)
local RateLimiter = require(script.Parent.RateLimiter)

local CombatServer = {}

-- Hooks wired by MatchManager
CombatServer.GetMatchOf = function(_player: Player): any
	return nil
end

local HEAD_PARTS = { Head = true }
local LIMB_PARTS = {
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
}

local MAX_ORIGIN_OFFSET = 9 -- studs between claimed origin and server head (movement + latency)
local MAX_HIT_OFFSET = 7 -- studs between claimed hit and server body-part position
local MAX_ANGLE = math.rad(6)

local lastAttacker: { [Humanoid]: { player: Player, weapon: string, headshot: boolean, time: number } } = {}

local function aliveHumanoid(character: Model?): Humanoid?
	local h = character and character:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		return h
	end
	return nil
end

local function headOf(character: Model): BasePart?
	local head = character:FindFirstChild("Head")
	return head and head:IsA("BasePart") and head or nil
end

local function worldParams(extraIgnore: { Instance })
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { workspace:FindFirstChild("Effects") }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	for _, i in ipairs(extraIgnore) do
		table.insert(ignore, i)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function matchPlayers(match): { Player }
	local list = {}
	for p in pairs(match.Players) do
		table.insert(list, p)
	end
	return list
end

-- Applies damage from attacker to victim. Returns (damageDealt, killed).
function CombatServer.ApplyDamage(attacker: Player, victim: Player, amount: number, weaponId: string, headshot: boolean, fromPos: Vector3)
	local match = CombatServer.GetMatchOf(attacker)
	if not match or match ~= CombatServer.GetMatchOf(victim) or match.State ~= "Live" then
		return 0, false
	end
	if attacker == victim then
		return 0, false
	end
	local aStat, vStat = match.Players[attacker], match.Players[victim]
	if not aStat or not vStat or aStat.Team == vStat.Team then
		return 0, false -- no friendly fire
	end
	if SpawnManager.IsProtected(victim) then
		return 0, false
	end
	local humanoid = aliveHumanoid(victim.Character)
	if not humanoid then
		return 0, false
	end
	amount = math.max(1, math.floor(amount + 0.5))
	local before = humanoid.Health
	lastAttacker[humanoid] = { player = attacker, weapon = weaponId, headshot = headshot, time = os.clock() }
	humanoid:TakeDamage(amount)
	local killed = before > 0 and humanoid.Health <= 0
	Net.Event("Damaged"):FireClient(victim, fromPos, amount)
	if killed then
		match:OnKill(attacker, victim, weaponId, headshot)
		Net.FireList("KillFeed", matchPlayers(match), {
			Killer = attacker.DisplayName,
			KillerTeam = aStat.Team,
			Victim = victim.DisplayName,
			VictimTeam = vStat.Team,
			Weapon = WeaponData.Get(weaponId) and WeaponData.Get(weaponId).Name or weaponId,
			Headshot = headshot,
		})
		Net.Event("Died"):FireClient(victim, {
			Killer = attacker.DisplayName,
			KillerUserId = attacker.UserId,
			Weapon = WeaponData.Get(weaponId) and WeaponData.Get(weaponId).Name or weaponId,
			Headshot = headshot,
		})
	end
	return before - math.max(humanoid.Health, 0), killed
end

local function onFire(player: Player, payload)
	if type(payload) ~= "table" or not RateLimiter.Check(player, "Fire", 25, 30) then
		return
	end
	local slot, origin, dir, hitPart, hitPos = payload.Slot, payload.Origin, payload.Direction, payload.Hit, payload.Position
	if type(slot) ~= "string" or not Util.IsValidVector3(origin) or not Util.IsValidVector3(dir) then
		return
	end
	if math.abs(dir.Magnitude - 1) > 0.02 then
		return
	end
	local match = CombatServer.GetMatchOf(player)
	if not match or match.State ~= "Live" then
		return
	end
	local character = player.Character
	if not aliveHumanoid(character) then
		return
	end
	local head = headOf(character)
	if not head or (head.Position - origin).Magnitude > MAX_ORIGIN_OFFSET then
		return
	end

	local ok, weapon = WeaponServer.TryConsumeShot(player, slot)
	if not ok then
		return
	end

	-- default visual end point: server raycast along the direction
	local params = worldParams({})
	local worldHit = workspace:Raycast(origin, dir * weapon.Range, params)
	local endPos = worldHit and worldHit.Position or (origin + dir * weapon.Range)

	local dealt, killed, headshot = 0, false, false
	if typeof(hitPart) == "Instance" and hitPart:IsA("BasePart") and Util.IsValidVector3(hitPos) then
		local victimChar = Util.GetCharacterFromPart(hitPart)
		local victim = victimChar and Players:GetPlayerFromCharacter(victimChar)
		if victim and victim ~= player and aliveHumanoid(victimChar) then
			local toHit = hitPos - origin
			local dist = toHit.Magnitude
			local angleOk = dist > 0.1 and dir:Angle(toHit.Unit) <= MAX_ANGLE
			local nearPart = (hitPart.Position - hitPos).Magnitude <= (hitPart.Size.Magnitude / 2 + MAX_HIT_OFFSET)
			local inRange = dist <= weapon.Range
			local blocked = false
			if angleOk and nearPart and inRange then
				local los = workspace:Raycast(origin, toHit.Unit * math.max(0, dist - 1.5), params)
				blocked = los ~= nil
			end
			if angleOk and nearPart and inRange and not blocked then
				headshot = HEAD_PARTS[hitPart.Name] == true
				local mult = headshot and weapon.HeadMultiplier or (LIMB_PARTS[hitPart.Name] and weapon.LimbMultiplier or 1)
				local damage = weapon.Damage * mult * (weapon.RangeModifier ^ (dist / 100))
				dealt, killed = CombatServer.ApplyDamage(player, victim, damage, weapon.Id, headshot, origin)
				endPos = hitPos
			end
		end
	end

	if dealt > 0 then
		Net.Event("HitConfirm"):FireClient(player, { Damage = dealt, Headshot = headshot, Killed = killed })
	end

	-- broadcast the shot to the other players of this match for tracers / sound
	local others = {}
	for p in pairs(match.Players) do
		if p ~= player then
			table.insert(others, p)
		end
	end
	Net.FireList("ShotFx", others, player, weapon.Id, origin, endPos, dealt > 0)
end

local function onMelee(player: Player, heavy, look)
	if type(heavy) ~= "boolean" or not Util.IsValidVector3(look) or not RateLimiter.Check(player, "Melee", 6, 6) then
		return
	end
	if look.Magnitude < 0.5 then
		return
	end
	look = look.Unit
	local match = CombatServer.GetMatchOf(player)
	if not match or match.State ~= "Live" then
		return
	end
	local character = player.Character
	if not aliveHumanoid(character) then
		return
	end
	local ok, knife = WeaponServer.TryMelee(player, heavy)
	if not ok then
		return
	end
	local attack = heavy and knife.Stab or knife.Slash
	local head = headOf(character)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not head or not root then
		return
	end
	local origin = head.Position
	local best, bestDist, bestPart = nil, attack.Range + 1.5, nil
	for p in pairs(match.Players) do
		if p ~= player and match.Players[p].Team ~= match.Players[player].Team then
			local vc = p.Character
			local vRoot = vc and vc:FindFirstChild("HumanoidRootPart") :: BasePart?
			if vRoot and aliveHumanoid(vc) then
				local to = vRoot.Position - origin
				local d = to.Magnitude
				if d < bestDist and to.Unit:Dot(look) > 0.35 then
					best, bestDist, bestPart = p, d, vRoot
				end
			end
		end
	end
	if not best or not bestPart then
		return
	end
	local params = worldParams({})
	local los = workspace:Raycast(origin, (bestPart.Position - origin), params)
	if los then
		return
	end
	local damage = attack.Damage
	local victimRoot = bestPart
	local backstab = heavy and victimRoot.CFrame.LookVector:Dot(root.CFrame.LookVector) > 0.5
	if backstab then
		damage = knife.Stab.BackstabDamage
	end
	local dealt, killed = CombatServer.ApplyDamage(player, best, damage, "Knife", false, origin)
	if dealt > 0 then
		Net.Event("HitConfirm"):FireClient(player, { Damage = dealt, Headshot = false, Killed = killed, Melee = true })
	end
end

function CombatServer.GetLastAttacker(humanoid: Humanoid)
	local info = lastAttacker[humanoid]
	lastAttacker[humanoid] = nil
	return info
end

function CombatServer.Init()
	Net.Event("Fire").OnServerEvent:Connect(onFire)
	Net.Event("Melee").OnServerEvent:Connect(onMelee)
	-- clear stale references
	task.spawn(function()
		while true do
			task.wait(30)
			local t = os.clock()
			for h, info in pairs(lastAttacker) do
				if not h.Parent or t - info.time > 30 then
					lastAttacker[h] = nil
				end
			end
		end
	end)
end

return CombatServer
