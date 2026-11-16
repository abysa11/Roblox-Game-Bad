--[[
	MAP 2 - MODERN CITY "Downtown District"
	Point-symmetric layout (every feature on Red's half is mirrored on Blue's half):
	  * Central avenue (wide, broken up by cars, a bus stop and a fountain plaza)
	  * Two narrow cross streets and back alleys for flanking
	  * Enterable office (3 floors + roof), corner shops with glass fronts, a 4-storey tower
	    (best high ground, but exposed from rooftops), a two-level parking garage
	  * Open parking lots with cars for mid-range fights
]]

local MapKit = require(script.Parent.Parent.MapKit)

local ModernCity = {}

local ASPHALT = Color3.fromRGB(46, 47, 52)
local SIDEWALK = Color3.fromRGB(150, 150, 146)
local LINE = Color3.fromRGB(235, 225, 190)
local GLASS = Color3.fromRGB(110, 150, 180)

local CAR_COLORS = {
	Color3.fromRGB(190, 40, 40), Color3.fromRGB(30, 60, 140), Color3.fromRGB(230, 230, 232),
	Color3.fromRGB(30, 30, 34), Color3.fromRGB(200, 170, 40), Color3.fromRGB(70, 120, 90),
}

local function car(b, x, z, rotY, color)
	local sub = b:Sub("Car")
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(rotY), 0)
	sub:Part(Vector3.new(5.6, 2.2, 11), cf * CFrame.new(0, 1.9, 0), color, Enum.Material.SmoothPlastic, { Reflectance = 0.1 })
	sub:Part(Vector3.new(5.2, 2, 6), cf * CFrame.new(0, 4, 0.6), GLASS, Enum.Material.Glass, { Transparency = 0.25 })
	sub:Part(Vector3.new(5.3, 0.3, 5.6), cf * CFrame.new(0, 5.05, 0.6), color, Enum.Material.SmoothPlastic)
	for _, wx in ipairs({ -2.6, 2.6 }) do
		for _, wz in ipairs({ -3.6, 3.6 }) do
			sub:Cyl(1, 2.4, cf * CFrame.new(wx, 1.2, wz), Color3.fromRGB(20, 20, 22), Enum.Material.SmoothPlastic)
		end
	end
	sub:Part(Vector3.new(1.2, 0.5, 0.2), cf * CFrame.new(-1.8, 2.3, -5.55), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
	sub:Part(Vector3.new(1.2, 0.5, 0.2), cf * CFrame.new(1.8, 2.3, -5.55), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
	sub:Part(Vector3.new(1.2, 0.5, 0.2), cf * CFrame.new(-1.8, 2.3, 5.55), Color3.fromRGB(200, 20, 20), Enum.Material.Neon)
	sub:Part(Vector3.new(1.2, 0.5, 0.2), cf * CFrame.new(1.8, 2.3, 5.55), Color3.fromRGB(200, 20, 20), Enum.Material.Neon)
end

local function lamp(b, x, z, rotY)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(rotY), 0)
	b:Part(Vector3.new(0.6, 14, 0.6), cf * CFrame.new(0, 7.5, 0), Color3.fromRGB(50, 52, 58), Enum.Material.Metal)
	b:Part(Vector3.new(0.5, 0.5, 4), cf * CFrame.new(0, 14.3, -1.8), Color3.fromRGB(50, 52, 58), Enum.Material.Metal)
	local head = b:Part(Vector3.new(1.4, 0.4, 1.8), cf * CFrame.new(0, 14, -3.6), Color3.fromRGB(255, 240, 210), Enum.Material.Neon, { CastShadow = false })
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Bottom
	l.Angle = 100
	l.Range = 26
	l.Brightness = 1.4
	l.Color = Color3.fromRGB(255, 220, 170)
	l.Parent = head
end

local function planterTree(b, x, z)
	b:Box(x - 2, 0, z - 2, x + 2, 1.6, z + 2, Color3.fromRGB(110, 110, 112), Enum.Material.Concrete)
	b:Box(x - 1.7, 1.6, z - 1.7, x + 1.7, 1.8, z + 1.7, Color3.fromRGB(70, 50, 34), Enum.Material.Ground)
	b:Column(Vector3.new(x, 1.6, z), 6, 0.7, Color3.fromRGB(80, 60, 44), Enum.Material.Wood)
	b:Ball(6, Vector3.new(x, 8.6, z), Color3.fromRGB(60, 120, 60), Enum.Material.Grass, { CanCollide = false })
end

local function bench(b, x, z, rotY)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(rotY), 0)
	b:Part(Vector3.new(5, 0.4, 1.6), cf * CFrame.new(0, 1.6, 0), Color3.fromRGB(120, 86, 56), Enum.Material.Wood)
	b:Part(Vector3.new(5, 1.4, 0.3), cf * CFrame.new(0, 2.5, 0.75), Color3.fromRGB(120, 86, 56), Enum.Material.Wood)
	b:Part(Vector3.new(0.3, 1.6, 1.4), cf * CFrame.new(-2.2, 0.8, 0), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	b:Part(Vector3.new(0.3, 1.6, 1.4), cf * CFrame.new(2.2, 0.8, 0), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
end

local function billboard(b, x, y, z, rotY, text, color)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotY), 0)
	local p = b:Part(Vector3.new(16, 7, 0.6), cf, Color3.fromRGB(20, 20, 26), Enum.Material.SmoothPlastic)
	b:Part(Vector3.new(16.4, 0.3, 0.8), cf * CFrame.new(0, -3.6, 0), color, Enum.Material.Neon)
	local lbl = require(script.Parent.Parent.Builder).Label(p, Enum.NormalId.Front, text, color, { PixelsPerStud = 10 })
	lbl.Font = Enum.Font.GothamBlack
end

-- shop with a glass front facing `side`
local function shop(b, x0, z0, x1, z1, side, color, name, signColor)
	local sub = b:Building({
		name = "Shop",
		x0 = x0, z0 = z0, x1 = x1, z1 = z1, y = 0.5,
		floors = 1, floorH = 11, wall = 1,
		color = color, mat = Enum.Material.Brick,
		floorColor = Color3.fromRGB(190, 186, 176), floorMat = Enum.Material.Marble,
		doors = { { side = side, at = 0.5, w = 7, h = 8 }, { side = side == "N" and "S" or "N", at = 0.25, w = 5, h = 8 } },
		windows = { spacing = 8, w = 5, h = 4.5, b = 2.5, groundFloor = true },
		glass = true, roof = false, stairs = false,
	})
	-- shop sign
	local cx = (x0 + x1) / 2
	local zFace = side == "N" and z0 - 0.4 or z1 + 0.4
	local sign = sub:Box(cx - 7, 9, zFace - 0.3, cx + 7, 11, zFace + 0.3, Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic)
	local Builder = require(script.Parent.Parent.Builder)
	Builder.Label(sign, side == "N" and Enum.NormalId.Front or Enum.NormalId.Back, name, signColor, { PixelsPerStud = 12 })
	-- counters and shelves as cover
	sub:Box(cx - 6, 0.7, (z0 + z1) / 2 - 1, cx + 2, 4, (z0 + z1) / 2 + 1, Color3.fromRGB(80, 70, 60), Enum.Material.Wood)
	sub:Box(x1 - 4, 0.7, z0 + 3, x1 - 2, 7, z1 - 3, Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	return sub
end

local function garage(b, s)
	-- two-level open parking deck with a ramp, mirrored by s
	local sub = b:Sub("Garage")
	local function X(x)
		return x * s
	end
	local function Z(z)
		return z * s
	end
	local x0, x1, z0, z1 = X(62), X(104), Z(-98), Z(-58)
	local minX, maxX = math.min(x0, x1), math.max(x0, x1)
	local minZ, maxZ = math.min(z0, z1), math.max(z0, z1)
	local deckY = 11
	local concrete = Color3.fromRGB(140, 140, 138)
	-- deck with a hole for the ramp
	local rx0, rx1 = X(66), X(74)
	local rz0, rz1 = Z(-96), Z(-74)
	sub:Slab(minX, minZ, maxX, maxZ, deckY, 1.2, concrete, Enum.Material.Concrete, { { rx0, rz0, rx1, rz1 } })
	-- pillars
	for x = 78, 100, 11 do
		for _, z in ipairs({ -94, -78, -62 }) do
			sub:Box(X(x) - 0.8, 0, Z(z) - 0.8, X(x) + 0.8, deckY - 1.2, Z(z) + 0.8, concrete, Enum.Material.Concrete)
		end
	end
	-- ramp up to the deck
	local rx = (rx0 + rx1) / 2
	sub:Ramp(Vector3.new(rx, 0.2, rz1), Vector3.new(rx, deckY, rz0), 8, concrete, Enum.Material.Concrete)
	-- deck parapets with gaps
	sub:Box(minX, deckY, minZ, maxX, deckY + 3, minZ + 0.6, concrete, Enum.Material.Concrete)
	sub:Box(minX, deckY, maxZ - 0.6, minX + (maxX - minX) * 0.4, deckY + 3, maxZ, concrete, Enum.Material.Concrete)
	sub:Box(minX + (maxX - minX) * 0.6, deckY, maxZ - 0.6, maxX, deckY + 3, maxZ, concrete, Enum.Material.Concrete)
	local farX = s > 0 and maxX or minX
	sub:Box(farX - 0.3, deckY, minZ, farX + 0.3, deckY + 3, maxZ, concrete, Enum.Material.Concrete)
	-- ladder on the inner side as a second way up
	sub:Ladder(Vector3.new((s > 0 and minX or maxX) - 1.2 * s, 0, Z(-66)), deckY + 1, concrete)
	-- cars on both levels
	car(sub, X(84), Z(-88), 0, CAR_COLORS[1])
	car(sub, X(96), Z(-86), 6, CAR_COLORS[3])
	car(sub, X(92), Z(-66), 180, CAR_COLORS[4])
	car(sub, X(78), Z(-66), 180, CAR_COLORS[2])
	-- deck cars sit on the slab
	local deck = sub:Sub("DeckCars")
	for _, d in ipairs({ { 86, -90, 0 }, { 97, -84, 10 }, { 84, -64, 180 } }) do
		car(deck, X(d[1]), Z(d[2]), d[3], CAR_COLORS[(d[1] % 6) + 1])
	end
	for _, d in ipairs(deck.Folder:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + Vector3.new(0, deckY, 0)
		end
	end
	for x = 80, 100, 10 do
		for _, z in ipairs({ -95, -61 }) do
			sub:Box(X(x) - 0.15, 0.02, Z(z) - 3, X(x) + 0.15, 0.06, Z(z) + 3, LINE, Enum.Material.SmoothPlastic, { CastShadow = false })
		end
	end
end

function ModernCity.Build(b)
	local B = MapKit.BOUNDS
	local Builder = require(script.Parent.Parent.Builder)

	-- ground: asphalt everywhere, sidewalks around blocks
	b:Box(B.x0 - 30, -2, B.z0 - 30, B.x1 + 30, 0, B.z1 + 30, ASPHALT, Enum.Material.Asphalt)
	local blocks = {
		{ -112, -100, -24, -56 }, { 24, -100, 112, -56 },
		{ -112, -36, -24, 36 }, { 24, -36, 112, 36 },
		{ -112, 56, -24, 100 }, { 24, 56, 112, 100 },
	}
	for _, bl in ipairs(blocks) do
		b:Box(bl[1], 0, bl[2], bl[3], 0.5, bl[4], SIDEWALK, Enum.Material.Concrete)
		b:Box(bl[1] - 0.3, 0, bl[2] - 0.3, bl[3] + 0.3, 0.55, bl[2] + 0.3, Color3.fromRGB(120, 120, 118), Enum.Material.Concrete)
	end
	-- road markings: avenue centre line, crosswalks
	for z = -110, 110, 10 do
		if math.abs(z) > 14 then
			b:Box(-0.25, 0, z - 2.5, 0.25, 0.04, z + 2.5, LINE, Enum.Material.SmoothPlastic, { CastShadow = false })
		end
	end
	for _, z in ipairs({ -52, 52 }) do
		for x = -20, 20, 3 do
			b:Box(x - 0.8, 0, z - 3, x + 0.8, 0.04, z + 3, Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, { CastShadow = false })
		end
	end

	-- central fountain plaza (blocks the full-length avenue sight line)
	local plaza = b:Sub("Plaza")
	plaza:Column(Vector3.new(0, 0, 0), 0.6, 30, Color3.fromRGB(180, 178, 170), Enum.Material.Marble)
	plaza:Column(Vector3.new(0, 0.6, 0), 2.4, 18, Color3.fromRGB(200, 198, 190), Enum.Material.Marble)
	plaza:Column(Vector3.new(0, 0.8, 0), 2.4, 16.4, Color3.fromRGB(80, 140, 190), Enum.Material.Glass, { Transparency = 0.3, CanCollide = false, NoBullets = true })
	plaza:Column(Vector3.new(0, 3, 0), 7, 3, Color3.fromRGB(190, 188, 180), Enum.Material.Marble)
	plaza:Box(-2.5, 10, -2.5, 2.5, 12, 2.5, Color3.fromRGB(200, 170, 70), Enum.Material.Foil)
	plaza:Box(-1.2, 12, -1.2, 1.2, 17, 1.2, Color3.fromRGB(200, 170, 70), Enum.Material.Foil)
	for _, p in ipairs({ { -12, -10 }, { 12, 10 }, { 12, -10 }, { -12, 10 } }) do
		planterTree(plaza, p[1], p[2])
	end

	-- avenue cover
	for _, s in ipairs({ -1, 1 }) do
		car(b, -7 * s, -70 * s, 8 * s, CAR_COLORS[1 + (s > 0 and 0 or 3)])
		car(b, 8 * s, -30 * s, -5, CAR_COLORS[2 + (s > 0 and 0 or 3)])
		car(b, -6 * s, -96 * s, 90, CAR_COLORS[3])
		-- bus stop shelter
		local bx, bz = 19 * s, -78 * s
		b:Box(bx - 1, 0.5, bz - 7, bx + 1, 8, bz - 6.6, Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
		b:Box(bx - 1, 0.5, bz + 6.6, bx + 1, 8, bz + 7, Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
		b:Box(bx - 1.6, 8, bz - 7.4, bx + 1.6, 8.5, bz + 7.4, Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
		b:Box(bx + 0.8 * s - 0.15, 0.5, bz - 6.6, bx + 0.8 * s + 0.15, 7.5, bz + 6.6, GLASS, Enum.Material.Glass, { Transparency = 0.5 })
		bench(b, bx, bz, s > 0 and -90 or 90)
		-- jersey barriers
		for _, x in ipairs({ -10, 10 }) do
			b:Box(x * s - 4, 0, -112 * s - 0.8, x * s + 4, 3, -112 * s + 0.8, Color3.fromRGB(190, 190, 186), Enum.Material.Concrete)
		end
		-- lamps along the avenue
		for z = -100, -20, 26 do
			lamp(b, -21 * s, z * s, s > 0 and -90 or 90)
			lamp(b, 21 * s, (z + 13) * s, s > 0 and 90 or -90)
		end
		-- cross-street cover
		car(b, -60 * s, -46 * s, 90, CAR_COLORS[5])
		car(b, 70 * s, -44 * s, 92, CAR_COLORS[6])
		MapKit.Barrel(b, Vector3.new(-40 * s, 0, -42 * s), Color3.fromRGB(220, 110, 30))
		MapKit.Barrel(b, Vector3.new(-37 * s, 0, -43 * s), Color3.fromRGB(220, 110, 30))
		for i = 0, 3 do
			b:Part(Vector3.new(0.9, 1.6, 0.9), Vector3.new((30 + i * 3) * s, 0.8, -50 * s), Color3.fromRGB(255, 120, 20), Enum.Material.SmoothPlastic)
		end
	end

	-- buildings (point-symmetric pairs)
	local office = Color3.fromRGB(176, 182, 190)
	for _, s in ipairs({ -1, 1 }) do
		local function X(x)
			return x * s
		end
		local function Z(z)
			return z * s
		end
		local function rect(ax, az, bx, bz)
			return math.min(X(ax), X(bx)), math.min(Z(az), Z(bz)), math.max(X(ax), X(bx)), math.max(Z(az), Z(bz))
		end
		local nearSide = s > 0 and "S" or "N" -- the side facing the map centre
		local innerSide = s > 0 and "E" or "W" -- the side facing the avenue

		-- office (3 floors + roof) on the Red-near-left / Blue-near-right block
		local x0, z0, x1, z1 = rect(-104, -98, -64, -62)
		local _, roofY = b:Building({
			name = "Office", x0 = x0, z0 = z0, x1 = x1, z1 = z1, y = 0.5,
			floors = 3, floorH = 11, wall = 1,
			color = office, mat = Enum.Material.Concrete,
			floorColor = Color3.fromRGB(150, 150, 156), floorMat = Enum.Material.SmoothPlastic,
			trimColor = Color3.fromRGB(70, 74, 84),
			doors = { { side = nearSide, at = 0.5, w = 7, h = 8 }, { side = innerSide, at = 0.5, w = 6, h = 8 } },
			windows = { spacing = 8, w = 4.5, h = 4, b = 3.5 },
			glass = true, roof = true, stairSide = s < 0 and "W" or "E",
		})
		billboard(b, X(-84), roofY + 6, Z(-80), s < 0 and 0 or 180, "NOVA BANK", Color3.fromRGB(80, 200, 255))
		b:Box(X(-84) - 0.5, roofY, Z(-80) - 0.5, X(-84) + 0.5, roofY + 2.6, Z(-80) + 0.5, Color3.fromRGB(40, 40, 44), Enum.Material.Metal)

		-- corner shops
		local sx0, sz0, sx1, sz1 = rect(-58, -96, -28, -66)
		shop(b, sx0, sz0, sx1, sz1, nearSide, Color3.fromRGB(150, 70, 60), s < 0 and "QUICKMART" or "CAFE 24", Color3.fromRGB(255, 200, 80))

		-- the tower (4 floors) on the middle-left/right block
		local tx0, tz0, tx1, tz1 = rect(-82, -22, -42, 22)
		b:Building({
			name = "Tower", x0 = tx0, z0 = tz0, x1 = tx1, z1 = tz1, y = 0.5,
			floors = 4, floorH = 11, wall = 1,
			color = Color3.fromRGB(70, 82, 100), mat = Enum.Material.Glass,
			floorColor = Color3.fromRGB(120, 124, 132), floorMat = Enum.Material.SmoothPlastic,
			trimColor = Color3.fromRGB(40, 44, 54),
			doors = {
				{ side = innerSide, at = 0.5, w = 8, h = 9 },
				{ side = innerSide == "E" and "W" or "E", at = 0.5, w = 6, h = 8 },
				{ side = "N", at = 0.7, w = 5, h = 8 },
				{ side = "S", at = 0.3, w = 5, h = 8 },
			},
			windows = { spacing = 7, w = 4, h = 4, b = 3.5 },
			glass = true, roof = true,
		})
		-- alley behind the tower with dumpsters
		for _, z in ipairs({ -26, 6 }) do
			b:Box(X(-104) - 3, 0.5, Z(z) - 2, X(-104) + 3, 5, Z(z) + 2, Color3.fromRGB(40, 90, 60), Enum.Material.Metal)
		end
		b:Box(X(-96) - 0.5, 0.5, Z(-30), X(-96) + 0.5, 9, Z(-12), Color3.fromRGB(120, 60, 50), Enum.Material.Brick)

		-- shopping arcade (2 floors) on the middle-right/left block
		local ax0, az0, ax1, az1 = rect(42, -26, 100, 26)
		b:Building({
			name = "Arcade", x0 = ax0, z0 = az0, x1 = ax1, z1 = az1, y = 0.5,
			floors = 2, floorH = 12, wall = 1,
			color = Color3.fromRGB(205, 196, 180), mat = Enum.Material.Limestone,
			floorColor = Color3.fromRGB(200, 196, 188), floorMat = Enum.Material.Marble,
			trimColor = Color3.fromRGB(150, 120, 80),
			doors = {
				{ side = innerSide == "E" and "W" or "E", at = 0.5, w = 10, h = 10 },
				{ side = "N", at = 0.5, w = 8, h = 9 },
				{ side = "S", at = 0.5, w = 8, h = 9 },
			},
			windows = { spacing = 9, w = 5, h = 4, b = 3 },
			glass = true, roof = true, stairSide = s < 0 and "E" or "W",
		})
		-- arcade interior: kiosks splitting the hall
		for _, z in ipairs({ -12, 12 }) do
			b:Box(X(64) - 3, 0.7, Z(z) - 2, X(64) + 3, 4.5, Z(z) + 2, Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
			b:Box(X(80) - 2, 0.7, Z(z) - 4, X(80) + 2, 6, Z(z) + 4, Color3.fromRGB(210, 210, 214), Enum.Material.Metal)
		end
		billboard(b, X(71), 32, Z(0), s < 0 and 90 or -90, "PIXEL PLAZA", Color3.fromRGB(255, 90, 180))
		b:Box(X(71) - 0.5, 25.5, Z(0) - 0.5, X(71) + 0.5, 28.6, Z(0) + 0.5, Color3.fromRGB(40, 40, 44), Enum.Material.Metal)

		-- parking garage (opposite corner of the same half)
		garage(b, -s)
		-- small kiosk + newsstand near the garage
		shop(b, math.min(X(-58), X(-30)), math.min(Z(62), Z(92)), math.max(X(-58), X(-30)), math.max(Z(62), Z(92)), s > 0 and "N" or "S", Color3.fromRGB(70, 90, 140), s < 0 and "BYTE SHOP" or "BURGER LAB", Color3.fromRGB(120, 230, 255))
		-- parked cars in the lot between garage and centre
		for i, x in ipairs({ 40, 56, 72, 88 }) do
			car(b, X(x), Z(46), 90 + (i % 2) * 180, CAR_COLORS[(i % #CAR_COLORS) + 1])
		end
	end

	-- spawns
	local redSpawns, redZone = MapKit.SpawnBase(b, "Red", { floorColor = Color3.fromRGB(150, 150, 146), wallColor = Color3.fromRGB(110, 112, 118) })
	local blueSpawns, blueZone = MapKit.SpawnBase(b, "Blue", { floorColor = Color3.fromRGB(150, 150, 146), wallColor = Color3.fromRGB(110, 112, 118) })

	-- skyline backdrop outside the play area
	local rng = Random.new(42)
	local skyline = b:Sub("Skyline")
	for i = 1, 26 do
		local side = i % 2 == 0 and 1 or -1
		local x = side * rng:NextNumber(135, 175)
		local z = rng:NextNumber(-160, 160)
		local h = rng:NextNumber(40, 120)
		local w = rng:NextNumber(16, 30)
		skyline:Box(x - w / 2, 0, z - w / 2, x + w / 2, h, z + w / 2, Color3.fromRGB(60 + rng:NextInteger(0, 40), 66 + rng:NextInteger(0, 40), 80 + rng:NextInteger(0, 40)), Enum.Material.Glass, { CanQuery = false })
	end
	for i = 1, 16 do
		local side = i % 2 == 0 and 1 or -1
		local z = side * rng:NextNumber(150, 175)
		local x = rng:NextNumber(-120, 120)
		local h = rng:NextNumber(30, 90)
		skyline:Box(x - 10, 0, z - 10, x + 10, h, z + 10, Color3.fromRGB(80, 86, 96), Enum.Material.Concrete, { CanQuery = false })
	end
	local _ = Builder

	b:Boundary(B.x0, B.z0, B.x1, B.z1, -2, 120)
	return {
		Spawns = { Red = redSpawns, Blue = blueSpawns },
		SpawnZones = { Red = redZone, Blue = blueZone },
		Podium = MapKit.PODIUM,
		KillY = -30,
	}
end

function ModernCity.BuildPreview(b)
	b:Box(-3, 0, -3, 3, 0.3, 3, Color3.fromRGB(46, 47, 52), Enum.Material.Asphalt)
	local rng = Random.new(3)
	for _, p in ipairs({ { -2, -2 }, { 2, -2 }, { -2, 0 }, { 2, 0 }, { -2, 2 }, { 2, 2 } }) do
		local h = rng:NextNumber(0.8, 3)
		b:Box(p[1] - 0.8, 0.3, p[2] - 0.7, p[1] + 0.8, 0.3 + h, p[2] + 0.7, Color3.fromRGB(80 + rng:NextInteger(0, 60), 100, 130), Enum.Material.Glass)
	end
	b:Box(-0.1, 0.3, -3, 0.1, 0.32, 3, Color3.fromRGB(230, 220, 180), Enum.Material.Neon)
	b:Column(Vector3.new(0, 0.3, 0), 0.3, 1, Color3.fromRGB(200, 198, 190), Enum.Material.Marble)
end

return ModernCity
