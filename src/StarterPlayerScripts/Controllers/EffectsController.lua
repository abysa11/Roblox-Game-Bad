--[[
	EffectsController
	Purely visual/audio bullet effects: tracers, muzzle flashes, impact sparks and marks,
	and other players' gunshots (from the server's ShotFx broadcast).
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local WeaponData = require(ReplicatedStorage.WeaponModules.WeaponData)
local ClientState = require(script.Parent.ClientState)

local EffectsController = {}

local folder = Instance.new("Folder")
folder.Name = "LocalEffects"
folder.Parent = workspace.CurrentCamera
EffectsController.Folder = folder

local function lowFx()
	return ClientState.Settings.Effects == "Low"
end

function EffectsController.Tracer(from: Vector3, to: Vector3, color: Color3?)
	local dist = (to - from).Magnitude
	if dist < 1 then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color or Color3.fromRGB(255, 225, 150)
	p.Size = Vector3.new(0.07, 0.07, math.min(dist, 30))
	-- a short streak that travels along the path
	local dir = (to - from).Unit
	local start = CFrame.lookAt(from + dir * (p.Size.Z / 2), to)
	p.CFrame = start
	p.Parent = folder
	local travel = math.max(0, dist - p.Size.Z)
	local t = math.clamp(dist / 900, 0.03, 0.15)
	TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = start + dir * travel, Transparency = 0.6 }):Play()
	Debris:AddItem(p, t + 0.02)
end

function EffectsController.MuzzleFlash(attachmentOrPos: any, suppressed: boolean?)
	local pos = typeof(attachmentOrPos) == "Instance" and attachmentOrPos.WorldPosition or attachmentOrPos
	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 200, 110)
	flash.Size = Vector3.one * (suppressed and 0.18 or 0.45)
	flash.Transparency = suppressed and 0.5 or 0.1
	flash.CFrame = CFrame.new(pos)
	flash.Parent = folder
	if not suppressed and not lowFx() then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 180, 90)
		light.Range = 10
		light.Brightness = 3
		light.Parent = flash
	end
	Debris:AddItem(flash, 0.045)
end

function EffectsController.Impact(pos: Vector3, normal: Vector3?, hitCharacter: boolean)
	local n = normal or Vector3.yAxis
	Sounds.Play(hitCharacter and "FleshImpact" or "BulletImpact", pos, { Volume = 0.7 })
	if hitCharacter then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.one * 0.2
		p.CFrame = CFrame.new(pos)
		p.Parent = folder
		if not lowFx() then
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new(Color3.fromRGB(170, 20, 20))
			e.Size = NumberSequence.new(0.25, 0)
			e.Lifetime = NumberRange.new(0.2, 0.4)
			e.Speed = NumberRange.new(4, 9)
			e.SpreadAngle = Vector2.new(40, 40)
			e.Acceleration = Vector3.new(0, -30, 0)
			e.Rate = 0
			e.Parent = p
			e:Emit(8)
		end
		Debris:AddItem(p, 0.6)
		return
	end
	-- bullet mark
	local mark = Instance.new("Part")
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.CastShadow = false
	mark.Shape = Enum.PartType.Cylinder
	mark.Size = Vector3.new(0.03, 0.28, 0.28)
	mark.Color = Color3.fromRGB(25, 25, 25)
	mark.Material = Enum.Material.SmoothPlastic
	mark.CFrame = CFrame.lookAt(pos, pos + n) * CFrame.Angles(0, math.pi / 2, 0)
	mark.Parent = folder
	Debris:AddItem(mark, 8)
	if not lowFx() then
		local att = Instance.new("Attachment")
		att.WorldPosition = pos
		att.Parent = workspace.Terrain
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 160))
		e.Size = NumberSequence.new(0.18, 0)
		e.Lifetime = NumberRange.new(0.1, 0.25)
		e.Speed = NumberRange.new(6, 14)
		e.SpreadAngle = Vector2.new(35, 35)
		e.EmissionDirection = Enum.NormalId.Top
		e.Rate = 0
		e.LightEmission = 1
		e.Parent = att
		att.WorldCFrame = CFrame.lookAt(pos, pos + n) * CFrame.Angles(-math.pi / 2, 0, 0)
		e:Emit(5)
		Debris:AddItem(att, 0.5)
	end
end

local function onShotFx(shooter: Player, weaponId: string, origin: Vector3, endPos: Vector3, hit: boolean)
	if typeof(origin) ~= "Vector3" or typeof(endPos) ~= "Vector3" then
		return
	end
	local w = WeaponData.Get(weaponId)
	if not w then
		return
	end
	local from = origin
	local character = shooter and shooter.Character
	local model = character and character:FindFirstChild("EquippedWeapon")
	local muzzle = model and model:FindFirstChild("Muzzle", true)
	if muzzle and muzzle:IsA("Attachment") then
		from = muzzle.WorldPosition
		EffectsController.MuzzleFlash(muzzle, w.Suppressed)
	end
	EffectsController.Tracer(from, endPos)
	EffectsController.Impact(endPos, (from - endPos).Unit, hit)
	Sounds.Play(w.Sound, from, { Volume = w.Suppressed and 0.6 or 1.2 })
end

function EffectsController.Init()
	Net.Event("ShotFx").OnClientEvent:Connect(onShotFx)
end

return EffectsController
