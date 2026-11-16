--[[
	MapData
	Display information and client lighting presets for the five maps.
	Geometry lives in ServerScriptService/Builders/Maps/<Id>.
]]

local MapData = {}

MapData.Order = { "Forest", "ModernCity", "BrickCity", "Egypt", "Maya" }

MapData.Maps = {
	Forest = {
		Id = "Forest",
		Name = "Whispering Pines",
		Subtitle = "FOREST",
		Description = "Dense pine forest split by a river. Three bridges, a ridge for long shots and a ravine for flanks.",
		Color = Color3.fromRGB(86, 170, 92),
		Lighting = {
			ClockTime = 15.2,
			Brightness = 2.4,
			Ambient = Color3.fromRGB(70, 82, 70),
			OutdoorAmbient = Color3.fromRGB(110, 128, 110),
			FogColor = Color3.fromRGB(170, 190, 175),
			FogEnd = 900,
			AtmosphereDensity = 0.36,
			AtmosphereColor = Color3.fromRGB(200, 220, 205),
			AtmosphereDecay = Color3.fromRGB(110, 140, 110),
			Tint = Color3.fromRGB(245, 255, 240),
		},
	},
	ModernCity = {
		Id = "ModernCity",
		Name = "Downtown District",
		Subtitle = "MODERN CITY",
		Description = "Glass offices, a parking lot and narrow alleys. Fight through lobbies, shops and rooftops.",
		Color = Color3.fromRGB(80, 160, 230),
		Lighting = {
			ClockTime = 17.4,
			Brightness = 2.2,
			Ambient = Color3.fromRGB(80, 80, 92),
			OutdoorAmbient = Color3.fromRGB(120, 118, 130),
			FogColor = Color3.fromRGB(200, 180, 170),
			FogEnd = 1200,
			AtmosphereDensity = 0.3,
			AtmosphereColor = Color3.fromRGB(230, 200, 180),
			AtmosphereDecay = Color3.fromRGB(120, 110, 140),
			Tint = Color3.fromRGB(255, 245, 235),
		},
	},
	BrickCity = {
		Id = "BrickCity",
		Name = "Toybox Town",
		Subtitle = "BRICK CITY",
		Description = "A giant toy town made of plastic bricks. Climb stacked towers, hide behind oversized blocks.",
		Color = Color3.fromRGB(255, 196, 30),
		Lighting = {
			ClockTime = 13,
			Brightness = 3,
			Ambient = Color3.fromRGB(120, 120, 130),
			OutdoorAmbient = Color3.fromRGB(160, 160, 170),
			FogColor = Color3.fromRGB(190, 225, 255),
			FogEnd = 1500,
			AtmosphereDensity = 0.2,
			AtmosphereColor = Color3.fromRGB(200, 230, 255),
			AtmosphereDecay = Color3.fromRGB(150, 190, 255),
			Tint = Color3.fromRGB(255, 255, 255),
			Saturation = 0.25,
		},
	},
	Egypt = {
		Id = "Egypt",
		Name = "Sands of Kemet",
		Subtitle = "ANCIENT EGYPT",
		Description = "Sandstone temples, obelisks and a busy market. Hold the great temple hall or flank through the ruins.",
		Color = Color3.fromRGB(226, 182, 96),
		Lighting = {
			ClockTime = 11.5,
			Brightness = 3.2,
			Ambient = Color3.fromRGB(110, 92, 70),
			OutdoorAmbient = Color3.fromRGB(150, 128, 100),
			FogColor = Color3.fromRGB(235, 205, 160),
			FogEnd = 1100,
			AtmosphereDensity = 0.42,
			AtmosphereColor = Color3.fromRGB(240, 210, 160),
			AtmosphereDecay = Color3.fromRGB(200, 150, 90),
			Tint = Color3.fromRGB(255, 240, 215),
		},
	},
	Maya = {
		Id = "Maya",
		Name = "Temple of the Jaguar",
		Subtitle = "MAYA JUNGLE CITY",
		Description = "Stepped pyramids rising out of the jungle. Ball court in the middle, cenote tunnels below.",
		Color = Color3.fromRGB(40, 180, 140),
		Lighting = {
			ClockTime = 7.6,
			Brightness = 2,
			Ambient = Color3.fromRGB(60, 80, 70),
			OutdoorAmbient = Color3.fromRGB(100, 125, 110),
			FogColor = Color3.fromRGB(150, 175, 150),
			FogEnd = 700,
			AtmosphereDensity = 0.45,
			AtmosphereColor = Color3.fromRGB(170, 200, 170),
			AtmosphereDecay = Color3.fromRGB(80, 120, 90),
			Tint = Color3.fromRGB(235, 255, 235),
		},
	},
}

MapData.LobbyLighting = {
	ClockTime = 17.4, -- golden hour: bright enough to read the whole hub, still moody
	Brightness = 2.6,
	Ambient = Color3.fromRGB(120, 118, 132),
	OutdoorAmbient = Color3.fromRGB(150, 146, 162),
	FogColor = Color3.fromRGB(170, 150, 170),
	FogEnd = 1600,
	AtmosphereDensity = 0.28,
	AtmosphereColor = Color3.fromRGB(225, 195, 190),
	AtmosphereDecay = Color3.fromRGB(140, 110, 140),
	Tint = Color3.fromRGB(255, 248, 240),
}

function MapData.Get(id)
	return MapData.Maps[id]
end

function MapData.IsValid(id)
	return type(id) == "string" and MapData.Maps[id] ~= nil
end

return MapData
