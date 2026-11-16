--[[
	LobbyBuilder
	Main hub: spawn plaza, five themed map-select pads (each with a live sign and a small
	diorama preview of its map) and the skin shop kiosk.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapData = require(ReplicatedStorage.Shared.MapData)
local Builder = require(script.Parent.Builder)
local MapLoader = require(script.Parent.MapLoader)
local WeaponModels = require(ReplicatedStorage.WeaponModules.WeaponModels)

local LobbyBuilder = {}

local DARK = Color3.fromRGB(70, 74, 86) -- floor
local DARKER = Color3.fromRGB(22, 24, 30) -- signs, trims
local WALL = Color3.fromRGB(52, 56, 68)
local GRID = Color3.fromRGB(104, 110, 128)
local ACCENT = Color3.fromRGB(255, 140, 40)

local PAD = 22
local RADIUS = 74
local CENTER = Vector3.new(0, 0, 34)

local function decorate(b, mapId: string, color: Color3)
	-- themed props around each pad (pad-local space: pad centre at origin, front = +Z toward plaza)
	if mapId == "Forest" then
		for _, p in ipairs({ { -13, -13 }, { 13, -13 }, { -13, 8 }, { 13, 8 } }) do
			b:Cyl(4, 1.2, CFrame.new(p[1], 2, p[2]) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(95, 66, 40), Enum.Material.Wood)
			for i = 0, 2 do
				b:Part(Vector3.new(5 - i * 1.4, 2.6, 5 - i * 1.4), Vector3.new(p[1], 4.6 + i * 2, p[2]), Color3.fromRGB(46, 110 + i * 15, 52), Enum.Material.Grass)
			end
		end
		b:Cyl(8, 1.4, CFrame.new(0, 0.9, -12) * CFrame.Angles(0, math.rad(20), 0), Color3.fromRGB(110, 76, 46), Enum.Material.Wood)
	elseif mapId == "ModernCity" then
		for _, p in ipairs({ { -13, -13 }, { 13, -13 }, { -13, 8 }, { 13, 8 } }) do
			b:Column(Vector3.new(p[1], 0, p[2]), 9, 0.5, Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
			b:Part(Vector3.new(1.6, 0.4, 1.6), Vector3.new(p[1], 9.2, p[2]), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
		end
		b:Box(-9, 0, -16, -5, 12, -12, Color3.fromRGB(70, 90, 120), Enum.Material.Glass, { Transparency = 0.2 })
		b:Box(5, 0, -16, 9, 8, -12, Color3.fromRGB(90, 96, 104), Enum.Material.Concrete)
	elseif mapId == "BrickCity" then
		local colors = { Color3.fromRGB(230, 40, 40), Color3.fromRGB(255, 205, 0), Color3.fromRGB(30, 110, 230), Color3.fromRGB(40, 170, 70) }
		for i, p in ipairs({ { -13, -13 }, { 13, -13 }, { -13, 8 }, { 13, 8 } }) do
			for k = 0, 2 do
				b:Part(Vector3.new(4, 1.6, 2), Vector3.new(p[1], 0.8 + k * 1.6, p[2] + (k % 2) * 0.6), colors[(i + k) % 4 + 1], Enum.Material.Plastic, { Studs = true })
			end
		end
	elseif mapId == "Egypt" then
		for _, x in ipairs({ -13, 13 }) do
			b:Box(x - 1.2, 0, -14.2, x + 1.2, 10, -11.8, Color3.fromRGB(214, 180, 120), Enum.Material.Sandstone)
			b:Part(Vector3.new(2.4, 1.6, 2.4), Vector3.new(x, 10.8, -13), Color3.fromRGB(255, 205, 80), Enum.Material.Foil)
		end
		b:Box(-13, 0, 6, 13, 0.4, 12, Color3.fromRGB(230, 200, 140), Enum.Material.Sand)
	elseif mapId == "Maya" then
		for i = 0, 3 do
			local s = 8 - i * 1.8
			b:Box(-s, i * 1.4, -16 - s / 2, s, (i + 1) * 1.4, -16 + s / 2, Color3.fromRGB(120, 128, 112), Enum.Material.Slate)
		end
		for _, p in ipairs({ { -13, 6 }, { 13, 6 } }) do
			b:Ball(4.5, Vector3.new(p[1], 2, p[2]), Color3.fromRGB(40, 120, 60), Enum.Material.Grass)
		end
	end
	return color
end

function LobbyBuilder.Build(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Lobby"
	model.Parent = parent
	local b = Builder.new(model, CFrame.new())

	-- floor + grid
	b:Box(-130, -2, -110, 130, 0, 150, DARK, Enum.Material.Concrete)
	for x = -120, 120, 24 do
		b:Box(x - 0.15, 0, -110, x + 0.15, 0.05, 150, GRID, Enum.Material.SmoothPlastic, { CastShadow = false })
	end
	for z = -100, 150, 24 do
		b:Box(-130, 0, z - 0.15, 130, 0.05, z + 0.15, GRID, Enum.Material.SmoothPlastic, { CastShadow = false })
	end
	-- outer walls
	for _, w in ipairs({ { -130, -110, 130, -106 }, { -130, 146, 130, 150 }, { -130, -110, -126, 150 }, { 126, -110, 130, 150 } }) do
		b:Box(w[1], 0, w[2], w[3], 18, w[4], WALL, Enum.Material.Concrete)
		b:Box(w[1], 17.6, w[2], w[3], 18.2, w[4], ACCENT, Enum.Material.Neon, { CastShadow = false })
	end
	b:Boundary(-126, -106, 126, 146, 0, 80)

	-- spawn plaza
	local spawnPos = CENTER + Vector3.new(0, 0, 18)
	b:Column(spawnPos - Vector3.new(0, 0, 0), 0.6, 30, Color3.fromRGB(36, 38, 48), Enum.Material.SmoothPlastic)
	b:Column(spawnPos, 0.7, 26, ACCENT, Enum.Material.Neon)
	b:Column(spawnPos, 0.8, 24, Color3.fromRGB(36, 38, 48), Enum.Material.SmoothPlastic)
	b:Light(spawnPos + Vector3.new(0, 14, 0), Color3.fromRGB(255, 200, 150), 40, 1.5, true)
	-- Safety net: Roblox's own default placement also lands on the spawn pad.
	-- Invisible and non-solid (the pad underneath is the floor); no default force field.
	local spawnLocation = b:Part(Vector3.new(8, 0.4, 8), spawnPos + Vector3.new(0, 0.5, 0), ACCENT, Enum.Material.SmoothPlastic, {
		Class = "SpawnLocation",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	spawnLocation.Name = "LobbySpawn"
	local sl = spawnLocation :: SpawnLocation
	sl.Neutral = true
	sl.Duration = 0
	for _, d in ipairs(sl:GetChildren()) do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end

	-- title sign
	local title = b:Box(-40, 22, -100, 40, 36, -99, DARKER, Enum.Material.SmoothPlastic)
	Builder.Label(title, Enum.NormalId.Back, Config.GameName, Color3.new(1, 1, 1), { PixelsPerStud = 6 })
	b:Box(-40, 21.6, -99.2, 40, 22, -98.8, ACCENT, Enum.Material.Neon)
	b:Box(-1, 0, -100, 1, 22, -99, DARKER, Enum.Material.Metal)

	-- map pads
	local zones = {}
	local n = #MapData.Order
	for i, mapId in ipairs(MapData.Order) do
		local map = MapData.Get(mapId)
		local angle = math.rad(-64 + (i - 1) * (128 / (n - 1)))
		local pos = CENTER + Vector3.new(math.sin(angle) * RADIUS, 0, -math.cos(angle) * RADIUS)
		-- pad faces the plaza centre: local +Z points toward CENTER
		local padCF = CFrame.lookAt(pos, Vector3.new(CENTER.X, 0, CENTER.Z)) * CFrame.Angles(0, math.pi, 0)
		local pb = Builder.new(model, padCF)
		local sub = pb:Sub("Pad_" .. mapId)

		sub:Box(-PAD / 2 - 1.5, 0, -PAD / 2 - 1.5, PAD / 2 + 1.5, 0.5, PAD / 2 + 1.5, DARKER, Enum.Material.SmoothPlastic)
		local surface = sub:Box(-PAD / 2, 0.5, -PAD / 2, PAD / 2, 0.8, PAD / 2, map.Color:Lerp(Color3.new(0, 0, 0), 0.55), Enum.Material.SmoothPlastic)
		surface.Name = "PadSurface"
		for _, e in ipairs({ { -PAD / 2, -PAD / 2, PAD / 2, -PAD / 2 + 0.6 }, { -PAD / 2, PAD / 2 - 0.6, PAD / 2, PAD / 2 }, { -PAD / 2, -PAD / 2, -PAD / 2 + 0.6, PAD / 2 }, { PAD / 2 - 0.6, -PAD / 2, PAD / 2, PAD / 2 } }) do
			sub:Box(e[1], 0.8, e[2], e[3], 0.95, e[4], map.Color, Enum.Material.Neon, { CastShadow = false })
		end
		local floorText = sub:Box(-8, 0.8, -3, 8, 0.82, 3, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
		local ft = Builder.Label(floorText, Enum.NormalId.Top, "STEP IN TO QUEUE", map.Color, { PixelsPerStud = 12 })
		ft.Rotation = 180

		-- sign board behind the pad
		local sign = sub:Box(-12, 6, -PAD / 2 - 6.5, 12, 19, -PAD / 2 - 5.5, DARKER, Enum.Material.SmoothPlastic)
		sub:Box(-12, 5.6, -PAD / 2 - 6.4, 12, 6, -PAD / 2 - 5.4, map.Color, Enum.Material.Neon, { CastShadow = false })
		sub:Box(-11, 0, -PAD / 2 - 6.3, -10, 6, -PAD / 2 - 5.7, Color3.fromRGB(50, 52, 60), Enum.Material.Metal)
		sub:Box(10, 0, -PAD / 2 - 6.3, 11, 6, -PAD / 2 - 5.7, Color3.fromRGB(50, 52, 60), Enum.Material.Metal)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "SignGui"
		gui.Face = Enum.NormalId.Back -- +Z, toward the plaza
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = 0
		gui.Brightness = 1.4
		gui.Parent = sign
		local function line(name, y, h, text, font, color)
			local l = Instance.new("TextLabel")
			l.Name = name
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0.05, y)
			l.Size = UDim2.fromScale(0.9, h)
			l.Font = font
			l.TextScaled = true
			l.TextColor3 = color
			l.Text = text
			l.Parent = gui
			return l
		end
		line("Subtitle", 0.05, 0.1, map.Subtitle, Enum.Font.GothamBold, map.Color)
		line("Title", 0.16, 0.2, map.Name, Enum.Font.GothamBlack, Color3.new(1, 1, 1))
		local desc = line("Desc", 0.4, 0.2, map.Description, Enum.Font.Gotham, Color3.fromRGB(190, 195, 205))
		desc.TextWrapped = true
		local count = line("Count", 0.64, 0.14, "WAITING: 0 / " .. Config.Match.MaxPlayers, Enum.Font.GothamBold, Color3.new(1, 1, 1))
		local status = line("Status", 0.8, 0.13, "Step onto the pad to queue", Enum.Font.GothamMedium, map.Color)

		-- diorama preview on a pedestal (left of the sign, so it is visible from the plaza)
		sub:Box(-PAD / 2 - 9, 0, -6, -PAD / 2 - 2, 3, 1, Color3.fromRGB(36, 38, 48), Enum.Material.SmoothPlastic)
		sub:Box(-PAD / 2 - 9.1, 2.9, -6.1, -PAD / 2 - 1.9, 3.1, 1.1, map.Color, Enum.Material.Neon, { CastShadow = false })
		local previewCF = padCF * CFrame.new(-PAD / 2 - 5.5, 3.1, -2.5)
		local ok, err = pcall(MapLoader.BuildPreview, mapId, model, previewCF)
		if not ok then
			warn("[Lobby] preview for " .. mapId .. " failed: " .. tostring(err))
		end

		decorate(sub, mapId, map.Color)
		sub:Light(Vector3.new(0, 10, 0), map.Color, 26, 1.2)

		zones[mapId] = {
			CFrame = padCF * CFrame.new(0, 5, 0),
			Size = Vector3.new(PAD, 10, PAD),
			Count = count,
			Status = status,
			Surface = surface,
		}
	end

	-- skin shop kiosk (behind spawn)
	local kioskCF = CFrame.new(0, 0, 118)
	local kb = Builder.new(model, kioskCF):Sub("SkinShop")
	kb:Box(-16, 0, -6, 16, 1, 8, DARKER, Enum.Material.SmoothPlastic)
	kb:Box(-16, 1, 6, 16, 16, 8, Color3.fromRGB(30, 32, 42), Enum.Material.SmoothPlastic)
	kb:Box(-16, 15, -6, 16, 16, 8, Color3.fromRGB(30, 32, 42), Enum.Material.SmoothPlastic)
	kb:Box(-16, 1, -6, -15, 15, 8, Color3.fromRGB(30, 32, 42), Enum.Material.SmoothPlastic)
	kb:Box(15, 1, -6, 16, 15, 8, Color3.fromRGB(30, 32, 42), Enum.Material.SmoothPlastic)
	kb:Box(-16, 14.6, -6.4, 16, 15, -6, Color3.fromRGB(136, 71, 255), Enum.Material.Neon)
	local header = kb:Box(-10, 16, -1, 10, 21, 0, DARKER, Enum.Material.SmoothPlastic)
	Builder.Label(header, Enum.NormalId.Front, "SKIN SHOP", Color3.fromRGB(200, 170, 255), { PixelsPerStud = 10 })
	local counter = kb:Box(-6, 1, -2, 6, 4.5, 0, Color3.fromRGB(50, 40, 80), Enum.Material.SmoothPlastic)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SkinShopPrompt"
	prompt.ActionText = "Open Skin Shop"
	prompt.ObjectText = "Weapon Skins"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	-- weapon showcase on the back wall
	local showcase = { "AK47", "AWP", "M4A1S", "Deagle", "Knife" }
	for i, id in ipairs(showcase) do
		local w = WeaponModels.BuildStatic(id, nil)
		local x = -12 + (i - 1) * 6
		w:PivotTo(kioskCF * CFrame.new(x, 9, 5.6) * CFrame.Angles(0, math.rad(90), math.rad(-60)))
		w.Parent = kb.Folder
	end
	kb:Light(Vector3.new(0, 12, 0), Color3.fromRGB(170, 120, 255), 30, 1.6)

	-- ambient lighting columns
	for _, p in ipairs({ { -90, -60 }, { 90, -60 }, { -100, 60 }, { 100, 60 }, { -60, 120 }, { 60, 120 } }) do
		b:Column(Vector3.new(p[1], 0, p[2]), 14, 2, Color3.fromRGB(36, 38, 48), Enum.Material.SmoothPlastic)
		b:Part(Vector3.new(2.4, 1, 2.4), Vector3.new(p[1], 14.5, p[2]), ACCENT, Enum.Material.Neon)
		b:Light(Vector3.new(p[1], 15, p[2]), Color3.fromRGB(255, 180, 120), 30, 1)
	end

	return {
		Model = model,
		SpawnCFrame = CFrame.lookAt(spawnPos + Vector3.new(0, 1, 0), CENTER + Vector3.new(0, 1, -40)),
		Zones = zones,
		SkinShopPrompt = prompt,
	}
end

return LobbyBuilder
