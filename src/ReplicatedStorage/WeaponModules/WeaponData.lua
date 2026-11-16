--[[
	WeaponData
	Authoritative weapon stats. The server reads the same table to validate fire rate,
	ammo, reload time and damage, so changing a number here changes both sides.

	Units: distances in studs, angles in degrees, times in seconds.
	Damage falloff: damage * RangeModifier ^ (distance / 100)
]]

local WeaponData = {}

WeaponData.Weapons = {
	-- PISTOLS --------------------------------------------------------------------------
	USP = {
		Id = "USP",
		Name = "USP-S",
		Category = "Pistol",
		Slot = "Secondary",
		Description = "Suppressed sidearm. Quiet, precise first shot and forgiving recoil. Rewards patient tapping.",
		FireMode = "Semi",
		RPM = 352,
		Damage = 35,
		HeadMultiplier = 4,
		LimbMultiplier = 0.75,
		RangeModifier = 0.91,
		Range = 700,
		MagSize = 12,
		Reserve = 24,
		ReloadTime = 2.2,
		EquipTime = 0.55,
		Spread = { Base = 0.25, Move = 1.6, Air = 5, PerShot = 1.1, Max = 4.5, Recovery = 9 },
		Recoil = { Vertical = 1.1, Horizontal = 0.25, Recovery = 9, Pattern = "Tap" },
		MoveSpeed = 1.0,
		Suppressed = true,
		Sound = "USP_Shot",
		ViewOffset = CFrame.new(0.75, -0.75, -1.55),
	},
	Glock = {
		Id = "Glock",
		Name = "Glock-18",
		Category = "Pistol",
		Slot = "Secondary",
		Description = "Large magazine and fast trigger. Right-click toggles 3-round burst for close fights.",
		FireMode = "Semi",
		AltFire = "Burst",
		BurstCount = 3,
		BurstRPM = 1200,
		RPM = 400,
		Damage = 28,
		HeadMultiplier = 4,
		LimbMultiplier = 0.75,
		RangeModifier = 0.84,
		Range = 600,
		MagSize = 20,
		Reserve = 120,
		ReloadTime = 2.25,
		EquipTime = 0.5,
		Spread = { Base = 0.4, Move = 1.8, Air = 5, PerShot = 0.9, Max = 5, Recovery = 10 },
		BurstSpread = 1.8,
		Recoil = { Vertical = 0.8, Horizontal = 0.35, Recovery = 11, Pattern = "Tap" },
		MoveSpeed = 1.0,
		Sound = "Glock_Shot",
		ViewOffset = CFrame.new(0.75, -0.72, -1.5),
	},
	Deagle = {
		Id = "Deagle",
		Name = "Desert Eagle",
		Category = "Pistol",
		Slot = "Secondary",
		Description = "Hand cannon. One headshot ends a fight, but heavy kick punishes spamming.",
		FireMode = "Semi",
		RPM = 267,
		Damage = 63,
		HeadMultiplier = 3.2,
		LimbMultiplier = 0.75,
		RangeModifier = 0.85,
		Range = 800,
		MagSize = 7,
		Reserve = 35,
		ReloadTime = 2.2,
		EquipTime = 0.75,
		Spread = { Base = 0.3, Move = 3.2, Air = 7, PerShot = 3.2, Max = 7, Recovery = 6 },
		Recoil = { Vertical = 4.2, Horizontal = 0.9, Recovery = 7, Pattern = "Tap" },
		MoveSpeed = 0.97,
		Sound = "Deagle_Shot",
		ViewOffset = CFrame.new(0.78, -0.78, -1.6),
	},

	-- RIFLES ---------------------------------------------------------------------------
	AK47 = {
		Id = "AK47",
		Name = "AK-47",
		Category = "Rifle",
		Slot = "Primary",
		Description = "Hard-hitting automatic rifle. A headshot kills instantly; its spray climbs fast and kicks left-right.",
		FireMode = "Auto",
		RPM = 600,
		Damage = 36,
		HeadMultiplier = 4,
		LimbMultiplier = 0.75,
		RangeModifier = 0.98,
		Range = 1200,
		MagSize = 30,
		Reserve = 90,
		ReloadTime = 2.45,
		EquipTime = 1.0,
		Spread = { Base = 0.2, Move = 3.5, Air = 8, PerShot = 0.45, Max = 4.5, Recovery = 7 },
		Recoil = { Vertical = 1.15, Horizontal = 0.55, Recovery = 6, Pattern = "Climb", SwayStart = 8, SwayAmp = 1.0 },
		MoveSpeed = 0.86,
		Sound = "AK_Shot",
		ViewOffset = CFrame.new(0.7, -0.8, -1.35),
	},
	M4A1S = {
		Id = "M4A1S",
		Name = "M4A1-S",
		Category = "Rifle",
		Slot = "Primary",
		Description = "Suppressed precision rifle. Smaller magazine, but the most controllable spray in the arsenal.",
		FireMode = "Auto",
		RPM = 600,
		Damage = 33,
		HeadMultiplier = 4,
		LimbMultiplier = 0.75,
		RangeModifier = 0.97,
		Range = 1200,
		MagSize = 20,
		Reserve = 80,
		ReloadTime = 3.0,
		EquipTime = 1.0,
		Spread = { Base = 0.15, Move = 3.0, Air = 8, PerShot = 0.32, Max = 3.5, Recovery = 8 },
		Recoil = { Vertical = 0.8, Horizontal = 0.3, Recovery = 7, Pattern = "Climb", SwayStart = 10, SwayAmp = 0.6 },
		MoveSpeed = 0.9,
		Suppressed = true,
		Sound = "M4_Shot",
		ViewOffset = CFrame.new(0.68, -0.78, -1.3),
	},
	SCAR = {
		Id = "SCAR",
		Name = "SCAR",
		Category = "Rifle",
		Slot = "Primary",
		Description = "Battle rifle with the highest rate of fire. Shreds up close, drifts upward in long sprays.",
		FireMode = "Auto",
		RPM = 690,
		Damage = 30,
		HeadMultiplier = 4,
		LimbMultiplier = 0.75,
		RangeModifier = 0.96,
		Range = 1100,
		MagSize = 25,
		Reserve = 100,
		ReloadTime = 2.7,
		EquipTime = 0.95,
		Spread = { Base = 0.22, Move = 3.2, Air = 8, PerShot = 0.4, Max = 4.0, Recovery = 7.5 },
		Recoil = { Vertical = 0.95, Horizontal = 0.45, Recovery = 6.5, Pattern = "Climb", SwayStart = 6, SwayAmp = 0.8 },
		MoveSpeed = 0.88,
		Sound = "SCAR_Shot",
		ViewOffset = CFrame.new(0.7, -0.8, -1.35),
	},

	-- SNIPER ---------------------------------------------------------------------------
	AWP = {
		Id = "AWP",
		Name = "AWP",
		Category = "Sniper",
		Slot = "Primary",
		Description = "Bolt-action rifle. One body shot kills when scoped and still, but it is slow, heavy and wild without the scope.",
		FireMode = "Bolt",
		RPM = 41,
		Damage = 115,
		HeadMultiplier = 1.5,
		LimbMultiplier = 0.75,
		RangeModifier = 0.99,
		Range = 2000,
		MagSize = 5,
		Reserve = 20,
		ReloadTime = 3.6,
		EquipTime = 1.15,
		Spread = { Base = 8, Move = 12, Air = 18, PerShot = 0, Max = 18, Recovery = 20 },
		ScopedSpread = 0.04,
		ScopedMoveSpread = 4.5, -- moving while scoped is still inaccurate
		ScopeLevels = { 40, 14 }, -- field of view per zoom level
		ScopeTime = 0.28, -- time after zooming before the shot is accurate
		ScopedMoveSpeed = 0.55,
		Recoil = { Vertical = 6, Horizontal = 0.6, Recovery = 4, Pattern = "Tap" },
		MoveSpeed = 0.78,
		Sound = "AWP_Shot",
		ViewOffset = CFrame.new(0.72, -0.82, -1.25),
	},

	-- KNIFE ----------------------------------------------------------------------------
	Knife = {
		Id = "Knife",
		Name = "Knife",
		Category = "Melee",
		Slot = "Melee",
		Description = "Always with you. Left-click slashes, right-click stabs. A stab in the back is lethal.",
		FireMode = "Melee",
		Slash = { Damage = 40, Cooldown = 0.45, Range = 7.5 },
		Stab = { Damage = 65, BackstabDamage = 180, Cooldown = 1.05, Range = 6.5 },
		EquipTime = 0.4,
		MoveSpeed = 1.08,
		ViewOffset = CFrame.new(0.9, -0.85, -1.4),
	},
}

WeaponData.Categories = {
	{ Id = "Pistol", Label = "PISTOLS", Weapons = { "USP", "Glock", "Deagle" } },
	{ Id = "Rifle", Label = "RIFLES", Weapons = { "AK47", "M4A1S", "SCAR" } },
	{ Id = "Sniper", Label = "SNIPERS", Weapons = { "AWP" } },
}

WeaponData.SkinnableOrder = { "USP", "Glock", "Deagle", "AK47", "M4A1S", "SCAR", "AWP", "Knife" }

WeaponData.SlotOrder = { "Primary", "Secondary", "Melee" }

function WeaponData.Get(id)
	return WeaponData.Weapons[id]
end

function WeaponData.FireInterval(weapon)
	return 60 / weapon.RPM
end

function WeaponData.IsPistol(id)
	local w = WeaponData.Weapons[id]
	return w ~= nil and w.Category == "Pistol"
end

function WeaponData.IsPrimary(id)
	local w = WeaponData.Weapons[id]
	return w ~= nil and (w.Category == "Rifle" or w.Category == "Sniper")
end

-- 0..100 values for the shop stat bars (derived, so they never drift from the real stats)
function WeaponData.DisplayStats(weapon)
	if weapon.Category == "Melee" then
		return {
			{ "Damage", 70 },
			{ "Speed", 95 },
			{ "Range", 10 },
			{ "Mobility", 100 },
		}
	end
	local dps = weapon.Damage * weapon.RPM / 60
	local accuracy = weapon.ScopedSpread and 98 or math.clamp(100 - weapon.Spread.Base * 120 - weapon.Spread.PerShot * 8, 5, 100)
	local control = math.clamp(100 - weapon.Recoil.Vertical * 14 - weapon.Recoil.Horizontal * 20, 5, 100)
	return {
		{ "Damage", math.clamp(weapon.Damage / 115 * 100, 5, 100) },
		{ "Fire Rate", math.clamp(weapon.RPM / 700 * 100, 5, 100) },
		{ "DPS", math.clamp(dps / 400 * 100, 5, 100) },
		{ "Accuracy", accuracy },
		{ "Recoil Control", control },
		{ "Mobility", math.clamp((weapon.MoveSpeed - 0.7) / 0.35 * 100, 5, 100) },
	}
end

return WeaponData
