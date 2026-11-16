--[[
	WeaponModels
	Builds original, procedural weapon models out of parts (no imported/copyrighted meshes).
	The same builder is used for first-person viewmodels, third-person models and the 3D
	previews in the weapon/skin shops, so a skin looks identical everywhere.

	Model space: origin = right-hand grip, -Z = barrel direction, +Y = up.
	Parts carry a "Role" attribute:
	  Body / Accent -> recoloured by skins
	  Metal / Grip  -> fixed dark materials
	  Glow          -> neon strip, only visible on skins with NeonAccent
	Attachments on Handle: Muzzle, LeftHand. Part "Mag" is joined with a Weld so it can be
	animated during reloads.
]]

local SkinData = require(script.Parent.Parent.Shared.SkinData)

local WeaponModels = {}

local METAL = Color3.fromRGB(42, 44, 48)
local GRIP = Color3.fromRGB(26, 26, 28)

local DEFAULTS = {
	USP = { Body = Color3.fromRGB(52, 54, 58), Accent = Color3.fromRGB(28, 28, 30), Material = Enum.Material.SmoothPlastic },
	Glock = { Body = Color3.fromRGB(40, 42, 46), Accent = Color3.fromRGB(64, 66, 70), Material = Enum.Material.SmoothPlastic },
	Deagle = { Body = Color3.fromRGB(168, 170, 176), Accent = Color3.fromRGB(40, 40, 44), Material = Enum.Material.Metal },
	AK47 = { Body = Color3.fromRGB(122, 74, 38), Accent = Color3.fromRGB(32, 32, 34), Material = Enum.Material.Wood },
	M4A1S = { Body = Color3.fromRGB(38, 40, 44), Accent = Color3.fromRGB(72, 74, 80), Material = Enum.Material.SmoothPlastic },
	SCAR = { Body = Color3.fromRGB(176, 150, 104), Accent = Color3.fromRGB(40, 40, 42), Material = Enum.Material.SmoothPlastic },
	AWP = { Body = Color3.fromRGB(70, 96, 64), Accent = Color3.fromRGB(30, 30, 32), Material = Enum.Material.SmoothPlastic },
	Knife = { Body = Color3.fromRGB(196, 200, 206), Accent = Color3.fromRGB(58, 58, 64), Material = Enum.Material.Metal },
}

local rad = math.rad
local function rot(x, y, z)
	return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0))
end
local ALONG_Z = rot(0, 90, 0) -- cylinders are built along X; this turns them to Z

-- Geometry tables: { role, shape, size, cframe, name? }
local B, C, W = "Block", "Cylinder", "Wedge"

local GEOMETRY = {
	USP = {
		muzzle = Vector3.new(0, 0.38, -1.62),
		leftHand = CFrame.new(-0.12, -0.12, 0.05) * rot(0, 0, -20),
		parts = {
			{ "Body", B, Vector3.new(0.24, 0.26, 1.0), CFrame.new(0, 0.38, -0.3) },
			{ "Accent", B, Vector3.new(0.22, 0.15, 0.92), CFrame.new(0, 0.2, -0.28) },
			{ "Grip", B, Vector3.new(0.22, 0.62, 0.32), CFrame.new(0, -0.1, 0.06) * rot(16, 0, 0) },
			{ "Metal", B, Vector3.new(0.06, 0.1, 0.3), CFrame.new(0, 0.06, -0.2) },
			{ "Metal", C, Vector3.new(0.75, 0.21, 0.21), CFrame.new(0, 0.38, -1.22) * ALONG_Z },
			{ "Metal", B, Vector3.new(0.08, 0.06, 0.08), CFrame.new(0, 0.54, 0.12) },
			{ "Metal", B, Vector3.new(0.05, 0.06, 0.05), CFrame.new(0, 0.54, -0.74) },
			{ "Glow", B, Vector3.new(0.245, 0.04, 0.7), CFrame.new(0, 0.33, -0.3) },
			{ "Metal", B, Vector3.new(0.17, 0.52, 0.25), CFrame.new(0, -0.12, 0.07) * rot(16, 0, 0), "Mag" },
		},
	},
	Glock = {
		muzzle = Vector3.new(0, 0.38, -0.86),
		leftHand = CFrame.new(-0.12, -0.12, 0.05) * rot(0, 0, -20),
		parts = {
			{ "Body", B, Vector3.new(0.25, 0.27, 0.98), CFrame.new(0, 0.38, -0.3) },
			{ "Accent", B, Vector3.new(0.23, 0.16, 0.88), CFrame.new(0, 0.19, -0.27) },
			{ "Accent", B, Vector3.new(0.23, 0.64, 0.34), CFrame.new(0, -0.1, 0.06) * rot(13, 0, 0) },
			{ "Metal", B, Vector3.new(0.06, 0.1, 0.3), CFrame.new(0, 0.05, -0.2) },
			{ "Metal", C, Vector3.new(0.08, 0.1, 0.1), CFrame.new(0, 0.38, -0.82) * ALONG_Z },
			{ "Metal", B, Vector3.new(0.1, 0.06, 0.06), CFrame.new(0, 0.54, 0.12) },
			{ "Glow", B, Vector3.new(0.255, 0.035, 0.6), CFrame.new(0, 0.44, -0.3) },
			{ "Metal", B, Vector3.new(0.18, 0.58, 0.26), CFrame.new(0, -0.14, 0.07) * rot(13, 0, 0), "Mag" },
		},
	},
	Deagle = {
		muzzle = Vector3.new(0, 0.44, -1.12),
		leftHand = CFrame.new(-0.14, -0.14, 0.06) * rot(0, 0, -20),
		parts = {
			{ "Body", B, Vector3.new(0.3, 0.34, 1.25), CFrame.new(0, 0.42, -0.42) },
			{ "Body", W, Vector3.new(0.3, 0.12, 1.0), CFrame.new(0, 0.65, -0.55) * rot(0, 180, 0) },
			{ "Accent", B, Vector3.new(0.27, 0.16, 1.0), CFrame.new(0, 0.2, -0.32) },
			{ "Grip", B, Vector3.new(0.27, 0.72, 0.38), CFrame.new(0, -0.14, 0.08) * rot(14, 0, 0) },
			{ "Metal", B, Vector3.new(0.07, 0.12, 0.32), CFrame.new(0, 0.05, -0.22) },
			{ "Metal", B, Vector3.new(0.12, 0.08, 0.1), CFrame.new(0, 0.62, 0.16) },
			{ "Metal", B, Vector3.new(0.06, 0.08, 0.06), CFrame.new(0, 0.74, -0.98) },
			{ "Glow", B, Vector3.new(0.305, 0.04, 1.0), CFrame.new(0, 0.33, -0.45) },
			{ "Metal", B, Vector3.new(0.2, 0.64, 0.28), CFrame.new(0, -0.18, 0.09) * rot(14, 0, 0), "Mag" },
		},
	},
	AK47 = {
		muzzle = Vector3.new(0, 0.32, -3.05),
		leftHand = CFrame.new(-0.02, 0.06, -1.45) * rot(0, 0, -80),
		parts = {
			{ "Metal", B, Vector3.new(0.26, 0.34, 1.35), CFrame.new(0, 0.26, -0.5) },
			{ "Accent", B, Vector3.new(0.22, 0.1, 1.1), CFrame.new(0, 0.46, -0.45) },
			{ "Body", B, Vector3.new(0.3, 0.28, 0.82), CFrame.new(0, 0.22, -1.55) },
			{ "Body", B, Vector3.new(0.18, 0.13, 0.72), CFrame.new(0, 0.44, -1.5) },
			{ "Metal", C, Vector3.new(1.15, 0.11, 0.11), CFrame.new(0, 0.3, -2.45) * ALONG_Z },
			{ "Metal", C, Vector3.new(0.22, 0.16, 0.16), CFrame.new(0, 0.3, -2.98) * ALONG_Z },
			{ "Metal", B, Vector3.new(0.06, 0.22, 0.06), CFrame.new(0, 0.44, -2.6) },
			{ "Metal", B, Vector3.new(0.08, 0.1, 0.18), CFrame.new(0, 0.5, -0.05) },
			{ "Body", B, Vector3.new(0.24, 0.34, 1.05), CFrame.new(0, 0.1, 0.72) * rot(-6, 0, 0) },
			{ "Body", B, Vector3.new(0.25, 0.48, 0.16), CFrame.new(0, 0.02, 1.22) * rot(-6, 0, 0) },
			{ "Grip", B, Vector3.new(0.2, 0.55, 0.28), CFrame.new(0, -0.1, 0.02) * rot(18, 0, 0) },
			{ "Metal", B, Vector3.new(0.05, 0.1, 0.3), CFrame.new(0, 0.04, -0.3) },
			{ "Glow", B, Vector3.new(0.305, 0.04, 0.7), CFrame.new(0, 0.3, -1.55) },
			{ "Accent", B, Vector3.new(0.2, 0.52, 0.32), CFrame.new(0, -0.14, -0.78) * rot(-10, 0, 0), "Mag" },
			{ "Accent", B, Vector3.new(0.19, 0.42, 0.3), CFrame.new(0, -0.5, -0.62) * rot(-28, 0, 0), "MagPart" },
		},
	},
	M4A1S = {
		muzzle = Vector3.new(0, 0.32, -3.25),
		leftHand = CFrame.new(-0.02, 0.06, -1.4) * rot(0, 0, -80),
		parts = {
			{ "Body", B, Vector3.new(0.26, 0.36, 1.25), CFrame.new(0, 0.27, -0.45) },
			{ "Metal", B, Vector3.new(0.14, 0.08, 1.3), CFrame.new(0, 0.49, -0.6) },
			{ "Metal", B, Vector3.new(0.16, 0.18, 0.12), CFrame.new(0, 0.6, 0.0) },
			{ "Body", B, Vector3.new(0.3, 0.3, 0.95), CFrame.new(0, 0.27, -1.5) },
			{ "Metal", C, Vector3.new(0.35, 0.1, 0.1), CFrame.new(0, 0.3, -2.1) * ALONG_Z },
			{ "Metal", C, Vector3.new(1.0, 0.21, 0.21), CFrame.new(0, 0.3, -2.75) * ALONG_Z },
			{ "Metal", C, Vector3.new(0.7, 0.12, 0.12), CFrame.new(0, 0.28, 0.55) * ALONG_Z },
			{ "Accent", B, Vector3.new(0.22, 0.34, 0.6), CFrame.new(0, 0.16, 0.95) },
			{ "Accent", B, Vector3.new(0.22, 0.14, 0.4), CFrame.new(0, 0.38, 0.85) },
			{ "Grip", B, Vector3.new(0.2, 0.55, 0.28), CFrame.new(0, -0.1, 0.02) * rot(18, 0, 0) },
			{ "Metal", B, Vector3.new(0.05, 0.1, 0.3), CFrame.new(0, 0.05, -0.3) },
			{ "Glow", B, Vector3.new(0.305, 0.04, 0.85), CFrame.new(0, 0.2, -1.5) },
			{ "Accent", B, Vector3.new(0.19, 0.58, 0.3), CFrame.new(0, -0.2, -0.72) * rot(-4, 0, 0), "Mag" },
		},
	},
	SCAR = {
		muzzle = Vector3.new(0, 0.32, -2.55),
		leftHand = CFrame.new(-0.02, 0.06, -1.3) * rot(0, 0, -80),
		parts = {
			{ "Body", B, Vector3.new(0.3, 0.42, 1.65), CFrame.new(0, 0.28, -0.72) },
			{ "Body", B, Vector3.new(0.28, 0.2, 0.6), CFrame.new(0, 0.12, -1.25) },
			{ "Metal", B, Vector3.new(0.14, 0.07, 1.7), CFrame.new(0, 0.53, -0.72) },
			{ "Metal", B, Vector3.new(0.16, 0.18, 0.34), CFrame.new(0, 0.66, -0.4) },
			{ "Glow", B, Vector3.new(0.1, 0.1, 0.02), CFrame.new(0, 0.68, -0.58) },
			{ "Metal", C, Vector3.new(0.85, 0.12, 0.12), CFrame.new(0, 0.3, -1.95) * ALONG_Z },
			{ "Metal", B, Vector3.new(0.16, 0.16, 0.22), CFrame.new(0, 0.3, -2.42) },
			{ "Accent", B, Vector3.new(0.2, 0.4, 0.22), CFrame.new(0, 0.2, 0.25) },
			{ "Accent", B, Vector3.new(0.2, 0.12, 0.85), CFrame.new(0, 0.36, 0.62) },
			{ "Accent", B, Vector3.new(0.2, 0.42, 0.18), CFrame.new(0, 0.18, 1.02) },
			{ "Grip", B, Vector3.new(0.2, 0.55, 0.28), CFrame.new(0, -0.1, 0.02) * rot(18, 0, 0) },
			{ "Metal", B, Vector3.new(0.05, 0.1, 0.3), CFrame.new(0, 0.04, -0.3) },
			{ "Accent", B, Vector3.new(0.2, 0.55, 0.32), CFrame.new(0, -0.18, -0.68) * rot(-6, 0, 0), "Mag" },
		},
	},
	AWP = {
		muzzle = Vector3.new(0, 0.3, -3.45),
		leftHand = CFrame.new(-0.02, 0.04, -1.25) * rot(0, 0, -80),
		parts = {
			{ "Body", B, Vector3.new(0.3, 0.36, 1.6), CFrame.new(0, 0.24, -0.6) },
			{ "Body", B, Vector3.new(0.3, 0.28, 0.9), CFrame.new(0, 0.2, -1.6) },
			{ "Body", B, Vector3.new(0.3, 0.52, 1.25), CFrame.new(0, 0.1, 0.8) },
			{ "Accent", B, Vector3.new(0.31, 0.16, 0.3), CFrame.new(0, -0.05, 1.25) },
			{ "Metal", C, Vector3.new(2.0, 0.14, 0.14), CFrame.new(0, 0.3, -2.3) * ALONG_Z },
			{ "Metal", B, Vector3.new(0.2, 0.2, 0.26), CFrame.new(0, 0.3, -3.3) },
			{ "Metal", C, Vector3.new(1.25, 0.27, 0.27), CFrame.new(0, 0.65, -0.5) * ALONG_Z },
			{ "Metal", C, Vector3.new(0.18, 0.36, 0.36), CFrame.new(0, 0.65, -1.15) * ALONG_Z },
			{ "Metal", C, Vector3.new(0.14, 0.32, 0.32), CFrame.new(0, 0.65, 0.12) * ALONG_Z },
			{ "Accent", C, Vector3.new(0.02, 0.3, 0.3), CFrame.new(0, 0.65, -1.25) * ALONG_Z },
			{ "Metal", B, Vector3.new(0.1, 0.24, 0.1), CFrame.new(0, 0.46, -0.85) },
			{ "Metal", B, Vector3.new(0.1, 0.24, 0.1), CFrame.new(0, 0.46, -0.15) },
			{ "Metal", B, Vector3.new(0.3, 0.06, 0.06), CFrame.new(0.2, 0.32, -0.05) },
			{ "Metal", B, Vector3.new(0.1, 0.1, 0.1), CFrame.new(0.36, 0.32, -0.05) },
			{ "Grip", B, Vector3.new(0.2, 0.5, 0.28), CFrame.new(0, -0.08, 0.02) * rot(18, 0, 0) },
			{ "Glow", B, Vector3.new(0.31, 0.04, 1.4), CFrame.new(0, 0.12, -0.6) },
			{ "Metal", B, Vector3.new(0.2, 0.3, 0.42), CFrame.new(0, -0.06, -0.62), "Mag" },
		},
	},
	Knife = {
		muzzle = Vector3.new(0, 0.05, -1.25),
		leftHand = CFrame.new(-0.6, -0.3, 0.4),
		parts = {
			{ "Grip", B, Vector3.new(0.16, 0.2, 0.62), CFrame.new(0, 0, 0.02) },
			{ "Accent", B, Vector3.new(0.18, 0.22, 0.08), CFrame.new(0, 0, 0.32) },
			{ "Metal", B, Vector3.new(0.34, 0.09, 0.07), CFrame.new(0, 0, -0.31) },
			{ "Body", B, Vector3.new(0.05, 0.22, 0.78), CFrame.new(0, 0.03, -0.73) },
			{ "Body", W, Vector3.new(0.05, 0.22, 0.32), CFrame.new(0, 0.03, -1.27) * rot(0, 180, 0) },
			{ "Glow", B, Vector3.new(0.055, 0.03, 0.78), CFrame.new(0, 0.13, -0.73) },
		},
	},
}

local function makePart(shape, size)
	local p
	if shape == W then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
		if shape == C then
			p.Shape = Enum.PartType.Cylinder
		end
	end
	p.Size = size
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

function WeaponModels.GetDefaults(weaponId)
	return DEFAULTS[weaponId]
end

-- Applies a skin (or the default finish when skinId is nil/unknown) to an existing model.
function WeaponModels.ApplySkin(model: Model, weaponId: string, skinId: string?)
	local skin = skinId and SkinData.Get(skinId)
	if skin and skin.Weapon ~= weaponId then
		skin = nil
	end
	local def = DEFAULTS[weaponId]
	local bodyColor = skin and skin.Body or def.Body
	local accentColor = skin and skin.Accent or def.Accent
	local bodyMat = skin and skin.Material or def.Material
	local neon = skin and skin.NeonAccent
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local role = p:GetAttribute("Role")
			if role == "Body" then
				p.Color = bodyColor
				p.Material = bodyMat
				p.Reflectance = (bodyMat == Enum.Material.Foil or bodyMat == Enum.Material.Glass) and 0.15 or 0
			elseif role == "Accent" then
				p.Color = accentColor
				p.Material = bodyMat == Enum.Material.Wood and Enum.Material.SmoothPlastic or bodyMat
			elseif role == "Glow" then
				p.Color = accentColor
				p.Material = Enum.Material.Neon
				p.Transparency = neon and 0 or 1
			end
		end
	end
	model:SetAttribute("SkinId", skin and skin.Id or "")
end

function WeaponModels.Build(weaponId: string, skinId: string?): Model
	local geo = GEOMETRY[weaponId]
	assert(geo, "No geometry for weapon " .. tostring(weaponId))

	local model = Instance.new("Model")
	model.Name = weaponId

	local handle = makePart(B, Vector3.new(0.2, 0.2, 0.2))
	handle.Name = "Handle"
	handle.Transparency = 1
	handle.CFrame = CFrame.new()
	handle.Parent = model
	model.PrimaryPart = handle

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = geo.muzzle
	muzzle.Parent = handle

	local left = Instance.new("Attachment")
	left.Name = "LeftHand"
	left.CFrame = geo.leftHand
	left.Parent = handle

	local mag
	for _, d in ipairs(geo.parts) do
		local role, shape, size, cf, name = d[1], d[2], d[3], d[4], d[5]
		local p = makePart(shape, size)
		p.Name = name or role
		p:SetAttribute("Role", role)
		if role == "Metal" then
			p.Color = METAL
			p.Material = Enum.Material.Metal
		elseif role == "Grip" then
			p.Color = GRIP
			p.Material = Enum.Material.SmoothPlastic
		end
		p.CFrame = cf
		p.Parent = model
		if name == "Mag" then
			mag = p
			local w = Instance.new("Weld")
			w.Name = "MagWeld"
			w.Part0 = handle
			w.Part1 = p
			w.C0 = cf
			w.Parent = p
		elseif name == "MagPart" and mag then
			local w = Instance.new("WeldConstraint")
			w.Part0 = mag
			w.Part1 = p
			w.Parent = p
		else
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end
	end

	WeaponModels.ApplySkin(model, weaponId, skinId)
	return model
end

-- Re-anchors a built model for static display (ViewportFrames / lobby displays).
function WeaponModels.BuildStatic(weaponId: string, skinId: string?): Model
	local model = WeaponModels.Build(weaponId, skinId)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	return model
end

-- Approximate length of the weapon, used to frame preview cameras.
function WeaponModels.GetLength(weaponId: string): number
	local geo = GEOMETRY[weaponId]
	if not geo then
		return 2
	end
	return math.abs(geo.muzzle.Z) + 1.4
end

return WeaponModels
