--[[
	LightingController
	Applies per-map lighting locally (several maps can share one server in Local mode) and
	the player's Effects Quality setting (shadows, post-processing, fire and particles).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapData = require(ReplicatedStorage.Shared.MapData)
local ClientState = require(script.Parent.ClientState)

local LightingController = {}

local atmosphere, cc, bloom, rays, sky
local currentPreset = MapData.LobbyLighting

local function ensureEffects()
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	cc = Lighting:FindFirstChild("FPS_CC") or Instance.new("ColorCorrectionEffect")
	cc.Name = "FPS_CC"
	cc.Parent = Lighting
	bloom = Lighting:FindFirstChild("FPS_Bloom") or Instance.new("BloomEffect")
	bloom.Name = "FPS_Bloom"
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	rays = Lighting:FindFirstChild("FPS_Rays") or Instance.new("SunRaysEffect")
	rays.Name = "FPS_Rays"
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
	sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.Parent = Lighting
end

local function applyQuality()
	local q = ClientState.Settings.Effects
	Lighting.GlobalShadows = q ~= "Low"
	bloom.Enabled = q ~= "Low"
	rays.Enabled = q == "High"
	atmosphere.Density = (currentPreset.AtmosphereDensity or 0.3) * (q == "Low" and 0.5 or 1)
	local maps = workspace:FindFirstChild("Maps")
	local function setEffect(d)
		if d:IsA("Fire") or d:IsA("Sparkles") then
			d.Enabled = q ~= "Low"
		elseif d:IsA("ParticleEmitter") and not d:FindFirstAncestor("Podium") then
			d.Enabled = q ~= "Low"
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Shadows = q == "High" and d:GetAttribute("WantsShadows") == true
		end
	end
	if maps then
		for _, d in ipairs(maps:GetDescendants()) do
			setEffect(d)
		end
	end
	return setEffect
end

local function applyPreset(preset)
	currentPreset = preset
	Lighting.ClockTime = preset.ClockTime
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	Lighting.FogColor = preset.FogColor
	Lighting.FogEnd = preset.FogEnd
	Lighting.FogStart = 0
	atmosphere.Color = preset.AtmosphereColor
	atmosphere.Decay = preset.AtmosphereDecay
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	cc.TintColor = preset.Tint
	cc.Saturation = preset.Saturation or 0.08
	cc.Contrast = 0.06
	applyQuality()
end

function LightingController.Init()
	ensureEffects()
	applyPreset(MapData.LobbyLighting)
	ClientState.MatchChanged:Connect(function(payload)
		if ClientState.InMatch and payload and payload.MapId then
			local map = MapData.Get(payload.MapId)
			if map and currentPreset ~= map.Lighting then
				applyPreset(map.Lighting)
			end
		elseif currentPreset ~= MapData.LobbyLighting then
			applyPreset(MapData.LobbyLighting)
		end
	end)
	ClientState.SettingsChanged:Connect(function()
		applyQuality()
	end)
	-- streamed-in map content picks up the current quality too
	task.spawn(function()
		local maps = workspace:WaitForChild("Maps", 60)
		if maps then
			maps.DescendantAdded:Connect(function(d)
				if d:IsA("Fire") or d:IsA("ParticleEmitter") or d:IsA("Sparkles") or d:IsA("PointLight") or d:IsA("SpotLight") then
					task.defer(function()
						if d.Parent then
							local q = ClientState.Settings.Effects
							if d:IsA("Fire") or d:IsA("Sparkles") then
								d.Enabled = q ~= "Low"
							elseif d:IsA("ParticleEmitter") and not d:FindFirstAncestor("Podium") then
								d.Enabled = q ~= "Low"
							end
						end
					end)
				end
			end)
		end
	end)
end

return LightingController
