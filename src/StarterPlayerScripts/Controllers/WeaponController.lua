--[[
	WeaponController
	Client side of every weapon: first-person viewmodel with procedural animations (draw,
	idle sway, walk bob, fire kick, reload with magazine swap, bolt cycling, knife slash/stab),
	spread & recoil simulation, fire modes (semi, auto, burst, bolt), AWP scope and inputs.

	The client only predicts. Every shot / reload / swap is sent to the server, which owns
	ammo and damage and corrects us through WeaponState / AmmoUpdate.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Util = require(ReplicatedStorage.Shared.Util)
local Config = require(ReplicatedStorage.Shared.Config)
local WeaponData = require(ReplicatedStorage.WeaponModules.WeaponData)
local WeaponModels = require(ReplicatedStorage.WeaponModules.WeaponModels)
local ClientState = require(script.Parent.ClientState)
local InputController = require(script.Parent.InputController)
local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)

local WeaponController = {}
WeaponController.Changed = Signal.new() -- HUD refresh
WeaponController.Fired = Signal.new()
WeaponController.ScopeChanged = Signal.new()

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rng = Random.new()

local SLOT_BY_INDEX = { "Primary", "Secondary", "Melee" }

local state = { Loadout = {}, Equipped = nil, Ammo = {}, Armed = false, Skins = {} }
local current: string? = nil -- locally equipped slot
local lastSlot: string? = nil

-- timing / animation state
local equipStart, equipDur = 0, 0.5
local reloading, reloadStart, reloadEnd, reloadToken = false, 0, 0, 0
local lastShot = 0
local semiReady = true
local burstQueue = 0
local burstMode = false
local bloom = 0
local sprayCount = 0
local scopeLevel, scopeStart, rescopeLevel = 0, 0, 0
local meleeKind, meleeStart = nil, 0
local boltStart = -10
local kick = 0
local pendingPitch, pendingYaw = 0, 0
local accumPitch, accumYaw = 0, 0
local swayX, swayY = 0, 0
local bobT = 0
local alive = false

-- viewmodel
local vmFolder = Instance.new("Folder")
vmFolder.Name = "Viewmodel"
vmFolder.Parent = camera
local vm = { Model = nil :: Model?, Id = nil, Skin = nil, MagWeld = nil :: Weld?, MagBase = CFrame.new(), Arms = {} }

local function weapon()
	local id = current and state.Loadout[current]
	return id and WeaponData.Get(id), id
end

local function now()
	return os.clock()
end

local function emitChanged()
	WeaponController.Changed:Fire()
end

-- VIEWMODEL --------------------------------------------------------------------------

local function makeArmPart(color: Color3, size: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = vmFolder
	return p
end

local function destroyViewmodel()
	if vm.Model then
		vm.Model:Destroy()
	end
	for _, p in ipairs(vm.Arms) do
		p:Destroy()
	end
	vm.Model, vm.Id, vm.Skin, vm.MagWeld = nil, nil, nil, nil
	vm.Arms = {}
end

local function buildViewmodel()
	local _, id = weapon()
	local skin = id and state.Skins[id] or nil
	if vm.Model and vm.Id == id and vm.Skin == skin then
		return
	end
	destroyViewmodel()
	if not id then
		return
	end
	local model = WeaponModels.Build(id, skin)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CastShadow = false
		end
	end
	model.PrimaryPart.Anchored = true
	model.Parent = vmFolder
	vm.Model, vm.Id, vm.Skin = model, id, skin
	local mag = model:FindFirstChild("Mag")
	vm.MagWeld = mag and mag:FindFirstChild("MagWeld") or nil
	vm.MagBase = vm.MagWeld and vm.MagWeld.C0 or CFrame.new()

	local teamColor = player:GetAttribute("TeamColor") or Color3.fromRGB(80, 80, 90)
	local skinColor = Color3.fromRGB(234, 184, 146)
	local char = player.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	if hand and hand:IsA("BasePart") then
		skinColor = hand.Color
	end
	vm.Arms = {
		makeArmPart(teamColor, Vector3.new(0.42, 0.42, 1)), -- right sleeve
		makeArmPart(skinColor, Vector3.new(0.34, 0.34, 0.5)), -- right hand
		makeArmPart(teamColor, Vector3.new(0.42, 0.42, 1)), -- left sleeve
		makeArmPart(skinColor, Vector3.new(0.34, 0.34, 0.5)), -- left hand
	}
end

local function placeArm(sleeve: BasePart, handPart: BasePart, shoulder: Vector3, hand: Vector3)
	local d = hand - shoulder
	local len = math.max(0.2, d.Magnitude - 0.25)
	sleeve.Size = Vector3.new(0.42, 0.42, len)
	sleeve.CFrame = CFrame.lookAt(shoulder, hand) * CFrame.new(0, 0, -len / 2)
	handPart.CFrame = CFrame.lookAt(hand, hand + d.Unit) * CFrame.new(0, 0, 0)
end

local function setViewmodelVisible(visible: boolean)
	vmFolder.Parent = visible and camera or nil
end

-- SCOPE --------------------------------------------------------------------------------

local function setScope(level: number)
	local w = weapon()
	if not w or not w.ScopeLevels then
		level = 0
	end
	if level == scopeLevel then
		return
	end
	scopeLevel = level
	scopeStart = now()
	if level > 0 then
		CameraController.SetFov(w.ScopeLevels[level])
		Sounds.Play("ScopeIn")
	else
		CameraController.SetFov(nil)
	end
	Net.Event("ScopeState"):FireServer(level > 0)
	WeaponController.ScopeChanged:Fire(level)
end

function WeaponController.GetScopeLevel()
	return scopeLevel
end

-- SPREAD / RECOIL ----------------------------------------------------------------------

local function movementInfo()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return 0, false
	end
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	return speed, hum.FloorMaterial == Enum.Material.Air
end

function WeaponController.GetSpread(): number
	local w = weapon()
	if not w or not w.Spread then
		return 0
	end
	local sp = w.Spread
	local speed, air = movementInfo()
	local moveFactor = math.clamp((speed - 2) / Config.Player.BaseWalkSpeed, 0, 1.2)
	local base = sp.Base
	local move = sp.Move * moveFactor
	if w.ScopedSpread and scopeLevel > 0 then
		local settle = math.clamp((now() - scopeStart) / w.ScopeTime, 0, 1)
		base = Util.Lerp(sp.Base * 0.5, w.ScopedSpread, settle)
		move = w.ScopedMoveSpread * moveFactor
	end
	if burstMode and w.BurstSpread then
		base += w.BurstSpread
	end
	return math.min(base + move + (air and sp.Air or 0) + bloom, sp.Max + (air and sp.Air or 0))
end

local function addRecoil(w)
	local r = w.Recoil
	sprayCount += 1
	local v = r.Vertical * (0.9 + rng:NextNumber() * 0.2)
	local h
	if r.Pattern == "Climb" then
		if sprayCount <= (r.SwayStart or 8) then
			h = rng:NextNumber(-1, 1) * r.Horizontal * 0.35
			v *= 1 + sprayCount * 0.04
		else
			h = math.sin(sprayCount * 0.55) * (r.SwayAmp or 0.8) + rng:NextNumber(-1, 1) * r.Horizontal * 0.4
			v *= 0.45
		end
	else
		h = rng:NextNumber(-1, 1) * r.Horizontal
	end
	pendingPitch += v
	pendingYaw += h
	kick = math.min(kick + (w.Category == "Sniper" and 2.2 or (w.Category == "Pistol" and 1.2 or 0.8)), 3)
end

-- SHOOTING -----------------------------------------------------------------------------

local function raycastParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { camera }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local fx = workspace:FindFirstChild("Effects")
	if fx then
		table.insert(ignore, fx)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function canAct()
	return state.Armed and alive and current ~= nil and ClientState.IsLive() and not ClientState.IsMenuOpen()
		and not CameraController.IsCinematic()
end

function WeaponController.Reload()
	local w, id = weapon()
	if not w or not w.MagSize or reloading or not state.Armed then
		return
	end
	local ammo = state.Ammo[current]
	if not ammo or ammo.Mag >= w.MagSize or ammo.Reserve <= 0 then
		return
	end
	rescopeLevel = 0
	setScope(0)
	reloading = true
	reloadStart = now()
	reloadEnd = reloadStart + w.ReloadTime
	reloadToken += 1
	local token = reloadToken
	local slot = current
	Net.Event("Reload"):FireServer(slot)
	Sounds.Play("MagOut", nil, { Volume = 0.8 })
	task.delay(w.ReloadTime * 0.62, function()
		if reloadToken == token and reloading then
			Sounds.Play("MagIn", nil, { Volume = 0.9 })
		end
	end)
	if w.Category == "Sniper" or w.Id == "Deagle" then
		task.delay(w.ReloadTime * 0.88, function()
			if reloadToken == token and reloading then
				Sounds.Play("BoltRack")
			end
		end)
	end
	-- predicted completion; the server's AmmoUpdate is authoritative and usually arrives first
	task.delay(w.ReloadTime + 0.5, function()
		if reloadToken == token and reloading and current == slot and state.Loadout[slot] == id then
			local take = math.min(w.MagSize - ammo.Mag, ammo.Reserve)
			ammo.Mag += take
			ammo.Reserve -= take
			reloading = false
			emitChanged()
		end
	end)
	emitChanged()
end

local function fireGun(w)
	local ammo = state.Ammo[current]
	if not ammo then
		return
	end
	if ammo.Mag <= 0 then
		Sounds.Play("DryFire")
		semiReady = false
		WeaponController.Reload()
		return
	end
	ammo.Mag -= 1
	lastShot = now()

	local spread = WeaponController.GetSpread()
	local camCF = camera.CFrame
	local origin = camCF.Position
	local dir = Util.SpreadDirection(camCF.LookVector, spread, rng)
	local result = workspace:Raycast(origin, dir * w.Range, raycastParams())
	local hitPos = result and result.Position or origin + dir * w.Range
	local hitPart = result and result.Instance
	local hitChar = hitPart and Util.GetCharacterFromPart(hitPart)
	local isPlayerHit = hitChar ~= nil and Players:GetPlayerFromCharacter(hitChar) ~= nil

	Net.Event("Fire"):FireServer({
		Slot = current,
		Origin = origin,
		Direction = dir,
		Hit = isPlayerHit and hitPart or nil,
		Position = hitPos,
	})

	-- local feedback
	local muzzle = vm.Model and vm.Model.PrimaryPart and vm.Model.PrimaryPart:FindFirstChild("Muzzle")
	local muzzlePos = muzzle and muzzle.WorldPosition or origin
	if scopeLevel == 0 then
		EffectsController.MuzzleFlash(muzzlePos, w.Suppressed)
	end
	EffectsController.Tracer(scopeLevel > 0 and (origin + camCF.UpVector * -0.3) or muzzlePos, hitPos)
	if result then
		EffectsController.Impact(hitPos, result.Normal, isPlayerHit)
	end
	Sounds.Play(w.Sound, nil, { Volume = w.Suppressed and 0.7 or 1 })
	addRecoil(w)
	bloom = math.min(bloom + w.Spread.PerShot, w.Spread.Max)
	WeaponController.Fired:Fire()

	if w.FireMode == "Bolt" then
		boltStart = now()
		rescopeLevel = scopeLevel
		setScope(0)
		local interval = 60 / w.RPM
		task.delay(0.35, function()
			Sounds.Play("BoltRack")
		end)
		task.delay(interval * 0.9, function()
			if rescopeLevel > 0 and current and state.Loadout[current] == w.Id and not reloading and alive then
				setScope(rescopeLevel)
			end
			rescopeLevel = 0
		end)
	end
	if ammo.Mag <= 0 and ammo.Reserve > 0 then
		task.delay(0.25, WeaponController.Reload)
	end
	emitChanged()
end

local function melee(heavy: boolean)
	local w = WeaponData.Get("Knife")
	local cd = heavy and w.Stab.Cooldown or w.Slash.Cooldown
	if now() - lastShot < cd then
		return
	end
	lastShot = now()
	meleeKind = heavy and "Stab" or "Slash"
	meleeStart = now()
	Sounds.Play(heavy and "KnifeStab" or "KnifeSlash")
	Net.Event("Melee"):FireServer(heavy, camera.CFrame.LookVector)
end

local function tryFire()
	local w = weapon()
	if not w or not canAct() then
		return
	end
	local t = now()
	if t < equipStart + equipDur then
		return
	end
	if w.FireMode == "Melee" then
		melee(false)
		return
	end
	if reloading then
		return
	end
	local interval = 60 / w.RPM
	if burstMode and w.AltFire == "Burst" then
		if burstQueue > 0 then
			if t - lastShot >= 60 / w.BurstRPM then
				burstQueue -= 1
				fireGun(w)
			end
			return
		end
		if semiReady and t - lastShot >= interval * 1.6 then
			semiReady = false
			burstQueue = w.BurstCount - 1
			fireGun(w)
		end
		return
	end
	if t - lastShot < interval then
		return
	end
	if w.FireMode == "Auto" then
		fireGun(w)
	elseif semiReady then
		semiReady = false
		fireGun(w)
	end
end

-- EQUIP ------------------------------------------------------------------------------

local function equipLocal(slot: string, tellServer: boolean)
	if not state.Loadout[slot] then
		return
	end
	if current ~= slot then
		lastSlot = current
	end
	current = slot
	reloading = false
	reloadToken += 1
	burstQueue = 0
	burstMode = false
	rescopeLevel = 0
	setScope(0)
	local w = WeaponData.Get(state.Loadout[slot])
	equipStart = now()
	equipDur = w and w.EquipTime or 0.5
	bloom = 0
	buildViewmodel()
	Sounds.Play(slot == "Melee" and "EquipKnife" or "EquipGun")
	if tellServer then
		Net.Event("EquipSlot"):FireServer(slot)
	end
	emitChanged()
end

function WeaponController.Equip(slot: string)
	if not state.Armed or not alive or slot == current or not state.Loadout[slot] then
		return
	end
	equipLocal(slot, true)
end

local function cycle(dir: number)
	local available = {}
	for _, s in ipairs(SLOT_BY_INDEX) do
		if state.Loadout[s] then
			table.insert(available, s)
		end
	end
	if #available == 0 then
		return
	end
	local i = table.find(available, current) or 1
	WeaponController.Equip(available[((i - 1 + dir) % #available) + 1])
end

function WeaponController.Cycle(dir: number)
	cycle(dir)
end

function WeaponController.Alt(began: boolean)
	local w = weapon()
	if not w or not began or not canAct() then
		return
	end
	if w.FireMode == "Melee" then
		melee(true)
	elseif w.ScopeLevels then
		if reloading or now() < equipStart + equipDur then
			return
		end
		rescopeLevel = 0
		setScope((scopeLevel + 1) % (#w.ScopeLevels + 1))
	elseif w.AltFire == "Burst" then
		burstMode = not burstMode
		burstQueue = 0
		Net.Event("ScopeState"):FireServer(burstMode)
		emitChanged()
	end
end

function WeaponController.IsBurst()
	return burstMode
end

-- PUBLIC STATE for HUD ------------------------------------------------------------------

function WeaponController.GetInfo()
	local w, id = weapon()
	local ammo = current and state.Ammo[current]
	return {
		Armed = state.Armed and alive,
		Slot = current,
		WeaponId = id,
		Weapon = w,
		Mag = ammo and ammo.Mag,
		Reserve = ammo and ammo.Reserve,
		Reloading = reloading,
		ReloadProgress = reloading and math.clamp((now() - reloadStart) / math.max(0.01, reloadEnd - reloadStart), 0, 1) or 0,
		Loadout = state.Loadout,
		Burst = burstMode,
	}
end

-- RENDER -----------------------------------------------------------------------------

local function easeOut(t)
	return 1 - (1 - t) ^ 3
end

local function renderStep(dt: number)
	-- camera recoil (applied after the default camera so it sticks)
	if pendingPitch ~= 0 or pendingYaw ~= 0 then
		local f = math.min(1, dt * 22)
		local dp, dy = pendingPitch * f, pendingYaw * f
		pendingPitch -= dp
		pendingYaw -= dy
		accumPitch += dp
		accumYaw += dy
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(dp), math.rad(-dy), 0)
	end
	local w = weapon()
	local t = now()
	if w and w.Recoil and t - lastShot > 0.14 then
		sprayCount = 0
		if accumPitch > 0.01 then
			local back = math.min(accumPitch, w.Recoil.Recovery * 3 * dt)
			accumPitch -= back
			camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(-back), 0, 0)
		end
		accumYaw *= (1 - math.min(1, dt * 4))
	end
	if w and w.Spread then
		bloom = math.max(0, bloom - w.Spread.Recovery * dt)
	end
	kick = kick * (1 - math.min(1, dt * 14))

	-- viewmodel
	local show = vm.Model ~= nil and state.Armed and alive and ClientState.InMatch and scopeLevel == 0 and not CameraController.IsCinematic()
	setViewmodelVisible(show)
	if not show or not w then
		return
	end
	local md = UserInputService:GetMouseDelta()
	swayX += ((-md.X * 0.0025) - swayX) * math.min(1, dt * 10)
	swayY += ((md.Y * 0.0025) - swayY) * math.min(1, dt * 10)
	local speed, air = movementInfo()
	bobT += dt * (speed > 1 and not air and speed * 0.55 or 0)
	local bobAmt = math.clamp(speed / 16, 0, 1) * (air and 0.2 or 1)
	local bob = CFrame.new(math.sin(bobT) * 0.035 * bobAmt, -math.abs(math.cos(bobT)) * 0.045 * bobAmt, 0)
	local idle = CFrame.new(0, math.sin(t * 1.6) * 0.012, 0)
	local sway = CFrame.Angles(swayY, swayX, swayX * 0.6)

	local e = easeOut(math.clamp((t - equipStart) / equipDur, 0, 1))
	local equipCF = CFrame.new(0, -1.1 * (1 - e), 0.25 * (1 - e)) * CFrame.Angles(math.rad(-55 * (1 - e)), math.rad(10 * (1 - e)), 0)

	local reloadCF = CFrame.new()
	local magDrop = 0
	if reloading then
		local p = math.clamp((t - reloadStart) / math.max(0.01, reloadEnd - reloadStart), 0, 1)
		local dip = math.sin(p * math.pi)
		reloadCF = CFrame.new(-0.08 * dip, -0.3 * dip, 0.05 * dip) * CFrame.Angles(math.rad(12 * dip), math.rad(-8 * dip), math.rad(28 * dip))
		if p > 0.12 and p < 0.75 then
			local q = (p - 0.12) / 0.63
			magDrop = math.sin(q * math.pi) * 1.4
		end
	end
	if vm.MagWeld then
		vm.MagWeld.C0 = vm.MagBase * CFrame.new(0, -magDrop, magDrop * 0.15)
	end

	local boltCF = CFrame.new()
	if t - boltStart < 0.9 then
		local p = (t - boltStart) / 0.9
		local s = math.sin(p * math.pi)
		boltCF = CFrame.new(0.05 * s, -0.08 * s, 0) * CFrame.Angles(0, 0, math.rad(-18 * s))
	end

	local meleeCF = CFrame.new()
	if meleeKind then
		local dur = meleeKind == "Stab" and 0.5 or 0.32
		local p = (t - meleeStart) / dur
		if p >= 1 then
			meleeKind = nil
		else
			local s = math.sin(p * math.pi)
			if meleeKind == "Slash" then
				meleeCF = CFrame.new(-0.5 * s, 0.15 * s, -0.4 * s) * CFrame.Angles(math.rad(-15 * s), math.rad(80 - 160 * easeOut(p)) * s, math.rad(-50 * s))
			else
				meleeCF = CFrame.new(-0.25 * s, 0.1 * s, -1.1 * s) * CFrame.Angles(math.rad(-25 * s), math.rad(10 * s), 0)
			end
		end
	end

	local kickCF = CFrame.new(0, kick * 0.03, kick * 0.12) * CFrame.Angles(math.rad(kick * 2.2), 0, 0)
	local base = camera.CFrame * (w.ViewOffset or CFrame.new(0.7, -0.8, -1.4))
	local final = base * sway * bob * idle * equipCF * reloadCF * boltCF * meleeCF * kickCF
	local handle = vm.Model.PrimaryPart
	handle.CFrame = final

	-- arms: shoulders are fixed in camera space, hands follow the weapon
	local camCF = camera.CFrame
	local rShoulder = camCF:PointToWorldSpace(Vector3.new(0.95, -1.5, 0.4))
	local lShoulder = camCF:PointToWorldSpace(Vector3.new(-0.95, -1.5, 0.4))
	local rHand = final.Position
	local leftAtt = handle:FindFirstChild("LeftHand") :: Attachment?
	local lHand = leftAtt and leftAtt.WorldPosition or rHand
	if reloading and vm.Model:FindFirstChild("Mag") then
		local magPart = vm.Model:FindFirstChild("Mag") :: BasePart
		local p = math.clamp((t - reloadStart) / math.max(0.01, reloadEnd - reloadStart), 0, 1)
		if p > 0.1 and p < 0.85 then
			lHand = lHand:Lerp(magPart.Position, math.sin((p - 0.1) / 0.75 * math.pi))
		end
	end
	if w.Category == "Melee" then
		lHand = camCF:PointToWorldSpace(Vector3.new(-0.9, -1.2, -0.6))
	end
	placeArm(vm.Arms[1], vm.Arms[2], rShoulder, rHand)
	placeArm(vm.Arms[3], vm.Arms[4], lShoulder, lHand)
end

local function heartbeat()
	if InputController.IsHeld("Fire") or burstQueue > 0 then
		tryFire()
	end
end

-- SERVER SYNC --------------------------------------------------------------------------

local function onWeaponState(payload)
	if type(payload) ~= "table" then
		return
	end
	local wasArmed = state.Armed
	state.Loadout = payload.Loadout or {}
	state.Armed = payload.Armed == true
	state.Skins = payload.Skins or {}
	state.Ammo = {}
	for slot, a in pairs(payload.Ammo or {}) do
		state.Ammo[slot] = { Mag = a.Mag, Reserve = a.Reserve }
	end
	if not state.Armed then
		current = nil
		reloading = false
		setScope(0)
		destroyViewmodel()
	elseif payload.Equipped and (payload.Equipped ~= current or not wasArmed) then
		equipLocal(payload.Equipped, false)
	else
		buildViewmodel()
	end
	emitChanged()
end

-- Server answer to a reload request (completed or rejected): authoritative ammo.
local function onAmmo(slot, mag, reserve)
	local a = state.Ammo[slot]
	if not a or type(mag) ~= "number" or type(reserve) ~= "number" then
		return
	end
	a.Mag, a.Reserve = mag, reserve
	if slot == current then
		reloading = false
	end
	emitChanged()
end

function WeaponController.Init()
	Net.Event("WeaponState").OnClientEvent:Connect(onWeaponState)
	Net.Event("AmmoUpdate").OnClientEvent:Connect(onAmmo)

	InputController.Action:Connect(function(name, began)
		if name == "Fire" then
			if not began then
				semiReady = true
			end
		elseif name == "Alt" then
			WeaponController.Alt(began)
		elseif not began then
			return
		elseif name == "Reload" then
			WeaponController.Reload()
		elseif name == "Slot1" or name == "Slot2" or name == "Slot3" then
			WeaponController.Equip(SLOT_BY_INDEX[tonumber(name:sub(5))])
		elseif name == "NextWeapon" then
			cycle(1)
		elseif name == "PrevWeapon" then
			cycle(-1)
		elseif name == "LastWeapon" then
			if lastSlot and state.Loadout[lastSlot] then
				WeaponController.Equip(lastSlot)
			end
		end
	end)

	local function onCharacter(char: Model)
		alive = true
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid
		if hum then
			hum.Died:Connect(function()
				alive = false
				reloading = false
				setScope(0)
				destroyViewmodel()
				emitChanged()
			end)
		end
		emitChanged()
	end
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	player:GetAttributeChangedSignal("TeamColor"):Connect(function()
		vm.Id = nil
		buildViewmodel()
	end)

	RunService:BindToRenderStep("FPSWeapon", Enum.RenderPriority.Camera.Value + 1, renderStep)
	RunService.Heartbeat:Connect(heartbeat)
end

return WeaponController
