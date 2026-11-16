--[[
	WeaponServer
	Authoritative weapon state per player: loadout, equipped slot, ammo, reloads, fire-rate
	budget and the third-person weapon model. CombatServer asks this module whether a shot
	is legal (TryConsumeShot) before any damage is applied.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local WeaponData = require(ReplicatedStorage.WeaponModules.WeaponData)
local WeaponModels = require(ReplicatedStorage.WeaponModules.WeaponModels)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local RateLimiter = require(script.Parent.RateLimiter)
local SpawnManager = require(script.Parent.SpawnManager)

local WeaponServer = {}

-- Hooks wired by MatchManager
WeaponServer.CanChangeLoadout = function(_player: Player): (boolean, string?)
	return false, "Not in a match."
end
WeaponServer.IsCombatAllowed = function(_player: Player): boolean
	return false
end

type SlotAmmo = { Mag: number, Reserve: number }
type State = {
	Loadout: { Primary: string?, Secondary: string, Melee: string },
	Ammo: { [string]: SlotAmmo },
	Equipped: string?,
	EquippedAt: number,
	LastFire: number,
	ShotTimes: { number },
	ReloadToken: number,
	ReloadingUntil: number,
	Burst: boolean,
	Armed: boolean,
	Model: Model?,
}

local states: { [Player]: State } = {}

local function now()
	return os.clock()
end

local function defaultLoadout()
	return { Primary = nil, Secondary = "USP", Melee = "Knife" }
end

local function getState(player: Player): State
	local s = states[player]
	if not s then
		s = {
			Loadout = defaultLoadout(),
			Ammo = {},
			Equipped = nil,
			EquippedAt = 0,
			LastFire = 0,
			ShotTimes = {},
			ReloadToken = 0,
			ReloadingUntil = 0,
			Burst = false,
			Armed = false,
			Model = nil,
		}
		states[player] = s
	end
	return s
end
WeaponServer.GetState = getState

local function skinFor(player: Player, weaponId: string): string?
	local data = PlayerDataManager.Get(player)
	return data and data.EquippedSkins[weaponId] or nil
end

local function sendState(player: Player)
	local s = getState(player)
	local skins = {}
	for _, id in pairs(s.Loadout) do
		skins[id] = skinFor(player, id)
	end
	Net.Event("WeaponState"):FireClient(player, {
		Loadout = s.Loadout,
		Equipped = s.Equipped,
		Ammo = s.Ammo,
		Armed = s.Armed,
		Skins = skins,
		Burst = s.Burst,
	})
end
WeaponServer.SendState = sendState

local function refill(s: State)
	s.Ammo = {}
	for slot, id in pairs(s.Loadout) do
		local w = WeaponData.Get(id)
		if w and w.MagSize then
			s.Ammo[slot] = { Mag = w.MagSize, Reserve = w.Reserve }
		end
	end
end

-- Arm pose ------------------------------------------------------------------------------
local function findMotor(character: Model, names: { string }): Motor6D?
	for _, n in ipairs(names) do
		local m = character:FindFirstChild(n, true)
		if m and m:IsA("Motor6D") then
			return m
		end
	end
	return nil
end

local function setPose(character: Model, weaponId: string?)
	local isR15 = character:FindFirstChild("UpperTorso") ~= nil
	local right = findMotor(character, isR15 and { "RightShoulder" } or { "Right Shoulder" })
	local left = findMotor(character, isR15 and { "LeftShoulder" } or { "Left Shoulder" })
	for _, m in ipairs({ right, left }) do
		if m and m:GetAttribute("BaseC0") == nil then
			m:SetAttribute("BaseC0", m.C0)
		end
	end
	local w = weaponId and WeaponData.Get(weaponId)
	local twoHanded = w and (w.Category == "Rifle" or w.Category == "Sniper" or w.Category == "Pistol")
	local function pose(m: Motor6D?, angle: number, yaw: number)
		if not m then
			return
		end
		local base = m:GetAttribute("BaseC0") :: CFrame
		if angle == 0 then
			m.C0 = base
		elseif isR15 then
			m.C0 = base * CFrame.Angles(math.rad(angle), math.rad(yaw), 0)
		else
			m.C0 = base * CFrame.Angles(0, 0, math.rad(angle * (m == right and 1 or -1)))
		end
	end
	if not w then
		pose(right, 0, 0)
		pose(left, 0, 0)
	elseif w.Category == "Melee" then
		pose(right, 35, 0)
		pose(left, 0, 0)
	else
		pose(right, 88, 0)
		pose(left, twoHanded and 80 or 0, twoHanded and -35 or 0)
	end
end

local function attachModel(player: Player, s: State)
	if s.Model then
		s.Model:Destroy()
		s.Model = nil
	end
	local character = player.Character
	local id = s.Equipped and s.Loadout[s.Equipped]
	if not character or not id then
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local model = WeaponModels.Build(id, skinFor(player, id))
	model.Name = "EquippedWeapon"
	local handle = model.PrimaryPart :: BasePart
	local offset = (hand.Name == "RightHand" and CFrame.new(0, -0.15, 0) or CFrame.new(0, -0.95, 0)) * CFrame.Angles(math.rad(-90), 0, 0)
	model:PivotTo(hand.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = offset
	weld.Parent = handle
	model.Parent = character
	s.Model = model
	setPose(character, id)
end

local function applySpeed(player: Player, s: State)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local id = s.Equipped and s.Loadout[s.Equipped]
	local w = id and WeaponData.Get(id)
	local speed = Config.Player.BaseWalkSpeed * (w and w.MoveSpeed or 1)
	humanoid.WalkSpeed = speed
	player:SetAttribute("BaseWalkSpeed", speed)
end

local function equip(player: Player, slot: string)
	local s = getState(player)
	if not s.Armed or not s.Loadout[slot] then
		return false
	end
	if s.Equipped == slot then
		return true
	end
	s.Equipped = slot
	s.EquippedAt = now()
	s.ReloadToken += 1
	s.ReloadingUntil = 0
	s.Burst = false
	attachModel(player, s)
	applySpeed(player, s)
	player:SetAttribute("EquippedWeapon", s.Loadout[slot])
	return true
end

-- Public API -----------------------------------------------------------------------------

function WeaponServer.Arm(player: Player)
	local s = getState(player)
	s.Armed = true
	refill(s)
	s.Equipped = nil
	equip(player, s.Loadout.Primary and "Primary" or "Secondary")
	sendState(player)
end

function WeaponServer.Disarm(player: Player)
	local s = getState(player)
	s.Armed = false
	s.Equipped = nil
	s.ReloadToken += 1
	if s.Model then
		s.Model:Destroy()
		s.Model = nil
	end
	player:SetAttribute("EquippedWeapon", nil)
	if player.Character then
		setPose(player.Character, nil)
	end
	sendState(player)
end

function WeaponServer.ResetLoadout(player: Player)
	local s = getState(player)
	s.Loadout = defaultLoadout()
end

-- Drop the third-person model on death (falls with the ragdoll, then cleans up).
function WeaponServer.OnDeath(player: Player)
	local s = getState(player)
	s.Armed = false
	s.ReloadToken += 1
	local model = s.Model
	s.Model = nil
	if model and model.PrimaryPart then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Weld") and d.Name ~= "MagWeld" then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.CanCollide = true
				d.Massless = false
			end
		end
		model.Parent = workspace
		game:GetService("Debris"):AddItem(model, 6)
	end
	sendState(player)
end

-- Called by CombatServer for every shot request. Returns (ok, weaponData, reason).
function WeaponServer.TryConsumeShot(player: Player, slot: string)
	local s = states[player]
	if not s or not s.Armed then
		return false, nil, "unarmed"
	end
	if s.Equipped ~= slot or (slot ~= "Primary" and slot ~= "Secondary") then
		return false, nil, "slot"
	end
	local w = WeaponData.Get(s.Loadout[slot])
	if not w or not w.MagSize then
		return false, nil, "weapon"
	end
	local t = now()
	if t < s.EquippedAt + w.EquipTime * 0.75 then
		return false, w, "drawing"
	end
	if t < s.ReloadingUntil - 0.15 then
		return false, w, "reloading"
	end
	local ammo = s.Ammo[slot]
	if not ammo or ammo.Mag <= 0 then
		return false, w, "empty"
	end
	local burst = s.Burst and w.AltFire == "Burst"
	local interval = burst and (60 / w.BurstRPM) or (60 / w.RPM)
	if t - s.LastFire < interval * 0.7 then
		return false, w, "rate"
	end
	-- sliding one-second window guards against sustained speed hacks
	local window = s.ShotTimes
	while window[1] and t - window[1] > 1 do
		table.remove(window, 1)
	end
	local maxPerSecond = burst and (w.BurstCount * 3 + 1) or (math.ceil(w.RPM / 60 * 1.15) + 1)
	if #window >= maxPerSecond then
		return false, w, "rate"
	end
	table.insert(window, t)
	s.LastFire = t
	ammo.Mag -= 1
	SpawnManager.EndProtection(player)
	return true, w, nil
end

function WeaponServer.TryMelee(player: Player, heavy: boolean)
	local s = states[player]
	if not s or not s.Armed or s.Equipped ~= "Melee" then
		return false, nil
	end
	local w = WeaponData.Get("Knife")
	local t = now()
	if t < s.EquippedAt + w.EquipTime * 0.75 then
		return false, w
	end
	local cd = heavy and w.Stab.Cooldown or w.Slash.Cooldown
	if t - s.LastFire < cd * 0.8 then
		return false, w
	end
	s.LastFire = t
	SpawnManager.EndProtection(player)
	return true, w
end

function WeaponServer.GetEquippedId(player: Player): string?
	local s = states[player]
	return s and s.Equipped and s.Loadout[s.Equipped] or nil
end

function WeaponServer.GetModel(player: Player): Model?
	local s = states[player]
	return s and s.Model
end

-- Remotes --------------------------------------------------------------------------------

local function onEquip(player: Player, slot)
	if type(slot) ~= "string" or not RateLimiter.Check(player, "Equip", 10, 12) then
		return
	end
	if slot ~= "Primary" and slot ~= "Secondary" and slot ~= "Melee" then
		return
	end
	if equip(player, slot) then
		sendState(player)
	end
end

local function onReload(player: Player, slot)
	if type(slot) ~= "string" or not RateLimiter.Check(player, "Reload", 4, 6) then
		return
	end
	local s = states[player]
	if not s or not s.Armed or s.Equipped ~= slot then
		return
	end
	local w = WeaponData.Get(s.Loadout[slot])
	local ammo = s.Ammo[slot]
	if not w or not ammo or not w.MagSize then
		return
	end
	if ammo.Mag >= w.MagSize or ammo.Reserve <= 0 or now() < s.ReloadingUntil then
		Net.Event("AmmoUpdate"):FireClient(player, slot, ammo.Mag, ammo.Reserve, false)
		return
	end
	s.ReloadToken += 1
	local token = s.ReloadToken
	s.ReloadingUntil = now() + w.ReloadTime
	task.delay(w.ReloadTime, function()
		if s.ReloadToken ~= token or not s.Armed or s.Equipped ~= slot then
			return
		end
		local need = w.MagSize - ammo.Mag
		local take = math.min(need, ammo.Reserve)
		ammo.Mag += take
		ammo.Reserve -= take
		s.ReloadingUntil = 0
		Net.Event("AmmoUpdate"):FireClient(player, slot, ammo.Mag, ammo.Reserve, true)
	end)
end

local function onScope(player: Player, scoped)
	if type(scoped) ~= "boolean" or not RateLimiter.Check(player, "Scope", 10, 10) then
		return
	end
	local s = states[player]
	if not s or not s.Armed then
		return
	end
	local id = s.Equipped and s.Loadout[s.Equipped]
	local w = id and WeaponData.Get(id)
	if not w then
		return
	end
	if w.AltFire == "Burst" then
		s.Burst = scoped
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and w.ScopedMoveSpeed then
		humanoid.WalkSpeed = Config.Player.BaseWalkSpeed * (scoped and w.ScopedMoveSpeed or w.MoveSpeed)
	end
end

local function onSetLoadout(player: Player, request)
	if type(request) ~= "table" or not RateLimiter.Check(player, "Loadout", 2, 4) then
		return { Ok = false, Message = "Invalid request." }
	end
	local ok, reason = WeaponServer.CanChangeLoadout(player)
	if not ok then
		return { Ok = false, Message = reason or "You can only change weapons in your spawn." }
	end
	local pistol, primary = request.Secondary, request.Primary
	if pistol == nil then
		pistol = "USP"
	end
	if type(pistol) ~= "string" or not WeaponData.IsPistol(pistol) then
		return { Ok = false, Message = "Pick one pistol." }
	end
	if primary ~= nil and (type(primary) ~= "string" or not WeaponData.IsPrimary(primary)) then
		return { Ok = false, Message = "Pick one rifle OR one sniper." }
	end
	local s = getState(player)
	s.Loadout = { Primary = primary, Secondary = pistol, Melee = "Knife" }
	if s.Armed then
		refill(s)
		s.Equipped = nil
		equip(player, primary and "Primary" or "Secondary")
	end
	sendState(player)
	return { Ok = true, Message = "Loadout confirmed.", Loadout = s.Loadout }
end

function WeaponServer.Init()
	Net.Event("EquipSlot").OnServerEvent:Connect(onEquip)
	Net.Event("Reload").OnServerEvent:Connect(onReload)
	Net.Event("ScopeState").OnServerEvent:Connect(onScope)
	Net.Function("SetLoadout").OnServerInvoke = onSetLoadout
	Players.PlayerRemoving:Connect(function(player)
		local s = states[player]
		if s and s.Model then
			s.Model:Destroy()
		end
		states[player] = nil
	end)
end

return WeaponServer
