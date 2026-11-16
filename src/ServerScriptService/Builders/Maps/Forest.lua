--[[
	MAP 1 - FOREST "Whispering Pines"
	Lanes (Red z=-125 -> Blue z=+125):
	  West  : a high wooded ridge (long sight lines broken by trees and boulders), rope bridge
	  Mid   : clearings, two abandoned cabins (two floors + attic), the main covered bridge
	  East  : a low ravine with a stream - close-quarters flank route, plank bridge above
	A river crosses the whole map at z = 0; it can be waded or crossed on three bridges.
	Watchtowers give elevated spots on both halves.
]]

local MapKit = require(script.Parent.Parent.MapKit)

local Forest = {}

local GRASS = Enum.Material.Grass
local WOOD = Color3.fromRGB(110, 78, 48)
local WOOD_DARK = Color3.fromRGB(74, 52, 34)
local ROCK = Color3.fromRGB(112, 114, 108)

local function gy(b, x, z)
	return b:GroundY(x, z, nil, true)
end

local function pine(b, x, z, rng, scale)
	local y = gy(b, x, z)
	local s = scale or (0.8 + rng:NextNumber() * 0.6)
	local h = 14 * s
	local t = b:Sub("Pine")
	t:Column(Vector3.new(x, y - 1, z), h * 0.55 + 1, 1.6 * s, Color3.fromRGB(92, 62, 40), Enum.Material.Wood)
	local tiers = 4
	for i = 0, tiers - 1 do
		local d = (9 - i * 2) * s
		local ty = y + h * 0.3 + i * 2.6 * s
		local green = Color3.fromRGB(34 + i * 6, 84 + i * 10 + rng:NextInteger(-8, 8), 46 + i * 4)
		t:Cyl(2.6 * s, d, CFrame.new(x, ty, z) * CFrame.Angles(0, rng:NextNumber() * 6, math.pi / 2), green, Enum.Material.Grass, { CanCollide = false, CastShadow = true })
	end
end

local function broadleaf(b, x, z, rng)
	local y = gy(b, x, z)
	local s = 0.9 + rng:NextNumber() * 0.5
	local t = b:Sub("Oak")
	t:Column(Vector3.new(x, y - 1, z), 9 * s, 2 * s, Color3.fromRGB(84, 60, 42), Enum.Material.Wood)
	for i = 1, 4 do
		local off = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(0, 3), rng:NextNumber(-3, 3)) * s
		t:Ball((7 + rng:NextNumber() * 3) * s, Vector3.new(x, y + 9 * s, z) + off, Color3.fromRGB(60, 120 + rng:NextInteger(-15, 15), 50), Enum.Material.Grass, { CanCollide = false })
	end
end

local function bush(b, x, z, rng)
	local y = gy(b, x, z)
	for _ = 1, 3 do
		b:Ball(3 + rng:NextNumber() * 2.5, Vector3.new(x + rng:NextNumber(-1.5, 1.5), y + 1, z + rng:NextNumber(-1.5, 1.5)),
			Color3.fromRGB(50, 110 + rng:NextInteger(-12, 12), 46), Enum.Material.Grass, { CanCollide = false, NoBullets = true, CastShadow = false })
	end
end

local function rock(b, x, z, rng, size)
	local y = gy(b, x, z)
	local s = size or (3 + rng:NextNumber() * 4)
	b:Part(Vector3.new(s * 1.3, s, s), CFrame.new(x, y + s * 0.3, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber() * 6, rng:NextNumber(-0.3, 0.3)), ROCK:Lerp(Color3.fromRGB(90, 96, 86), rng:NextNumber()), Enum.Material.Slate)
end

local function log(b, x, z, rot, len)
	local y = gy(b, x, z)
	b:Cyl(len or 12, 2.4, CFrame.new(x, y + 1, z) * CFrame.Angles(0, math.rad(rot), 0), Color3.fromRGB(96, 70, 46), Enum.Material.Wood)
end

local function bridge(b, x, width, length, height, covered, ramps)
	local sub = b:Sub("Bridge")
	local z0, z1 = -length / 2, length / 2
	sub:Box(x - width / 2, height - 0.8, z0, x + width / 2, height, z1, WOOD, Enum.Material.WoodPlanks)
	for _, sx in ipairs({ -1, 1 }) do
		local rx = x + sx * (width / 2 - 0.3)
		sub:Box(rx - 0.3, height, z0, rx + 0.3, height + 3.2, z0 + 0.6, WOOD_DARK, Enum.Material.Wood)
		sub:Box(rx - 0.3, height, z1 - 0.6, rx + 0.3, height + 3.2, z1, WOOD_DARK, Enum.Material.Wood)
		sub:Box(rx - 0.2, height + 2.6, z0, rx + 0.2, height + 3, z1, WOOD_DARK, Enum.Material.Wood)
		for z = z0 + 4, z1 - 4, 4 do
			sub:Box(rx - 0.2, height, z - 0.2, rx + 0.2, height + 2.6, z + 0.2, WOOD_DARK, Enum.Material.Wood)
		end
		-- support posts into the river bed
		for _, z in ipairs({ z0 + 2, z1 - 2 }) do
			sub:Box(rx - 0.6, -6, z - 0.6, rx + 0.6, height - 0.8, z + 0.6, WOOD_DARK, Enum.Material.Wood)
		end
	end
	if covered then
		local roofY = height + 9
		for _, sx in ipairs({ -1, 1 }) do
			for z = z0 + 1, z1 - 1, (length - 2) / 2 do
				sub:Box(x + sx * width / 2 - 0.4, height, z - 0.4, x + sx * width / 2 + 0.4, roofY, z + 0.4, WOOD_DARK, Enum.Material.Wood)
			end
		end
		sub:Part(Vector3.new(width / 2 + 1.5, 0.6, length + 2), CFrame.new(x - width / 4, roofY + 1.5, 0) * CFrame.Angles(0, 0, math.rad(25)), Color3.fromRGB(80, 60, 44), Enum.Material.WoodPlanks)
		sub:Part(Vector3.new(width / 2 + 1.5, 0.6, length + 2), CFrame.new(x + width / 4, roofY + 1.5, 0) * CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(80, 60, 44), Enum.Material.WoodPlanks)
	end
	if not ramps then
		return
	end
	-- approach ramps from the banks
	sub:Ramp(Vector3.new(x, 0.2, z0 - 8), Vector3.new(x, height, z0), width, WOOD, Enum.Material.WoodPlanks)
	sub:Ramp(Vector3.new(x, height, z1), Vector3.new(x, 0.2, z1 + 8), width, WOOD, Enum.Material.WoodPlanks)
end

local function cabin(b, cx, cz, flip)
	local w, d = 26, 20
	local x0, z0, x1, z1 = cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2
	local y = gy(b, cx, cz)
	local sub, roofY = b:Building({
		name = "Cabin",
		x0 = x0, z0 = z0, x1 = x1, z1 = z1, y = y + 0.5,
		floors = 2, floorH = 11, wall = 1,
		color = Color3.fromRGB(118, 84, 54), mat = Enum.Material.WoodPlanks,
		floorColor = Color3.fromRGB(96, 70, 46), floorMat = Enum.Material.WoodPlanks,
		trimColor = WOOD_DARK,
		doors = {
			{ side = flip and "S" or "N", at = 0.5, w = 6, h = 8 },
			{ side = "E", at = 0.3, w = 5, h = 8 },
			{ side = "W", at = 0.7, w = 5, h = 8 },
		},
		windows = { spacing = 8, w = 4, h = 3, b = 4, groundFloor = true },
		roof = true, parapet = 2.5,
		stairSide = flip and "E" or "W",
	})
	-- foundation so the cabin sits on slopes
	b:Box(x0 - 0.5, y - 4, z0 - 0.5, x1 + 0.5, y + 0.5, z1 + 0.5, Color3.fromRGB(90, 90, 86), Enum.Material.Cobblestone)
	-- broken roof boards and a chimney
	b:Box(x1 - 5, roofY, z0 + 3, x1 - 2, roofY + 6, z0 + 6, Color3.fromRGB(100, 96, 92), Enum.Material.Brick)
	b:Part(Vector3.new(10, 0.5, 3), CFrame.new(cx - 3, roofY + 0.8, cz) * CFrame.Angles(0, 0.4, 0.15), WOOD_DARK, Enum.Material.WoodPlanks)
	-- interior cover
	MapKit.Crate(b, Vector3.new(cx + 4, y + 0.7, cz + 2), 3.5)
	MapKit.Crate(b, Vector3.new(cx - 2, y + 11.7, cz - 3), 3.5)
	b:Box(cx + 6, y + 0.7, cz - 6, cx + 10, y + 3.7, cz - 4, WOOD_DARK, Enum.Material.Wood) -- table
	return sub
end

local function watchtower(b, cx, cz)
	local y = gy(b, cx, cz)
	local sub = b:Sub("Watchtower")
	local h = 16
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			sub:Box(cx + sx * 4 - 0.5, y - 2, cz + sz * 4 - 0.5, cx + sx * 4 + 0.5, y + h + 4, cz + sz * 4 + 0.5, WOOD_DARK, Enum.Material.Wood)
		end
	end
	sub:Box(cx - 5, y + h - 0.8, cz - 5, cx + 5, y + h, cz + 5, WOOD, Enum.Material.WoodPlanks)
	for _, side in ipairs({ { -5, -5, 5, -4.6 }, { -5, 4.6, 5, 5 }, { 4.6, -5, 5, 5 } }) do
		sub:Box(cx + side[1], y + h, cz + side[2], cx + side[3], y + h + 3, cz + side[4], WOOD, Enum.Material.WoodPlanks)
	end
	sub:Part(Vector3.new(12, 0.6, 12), CFrame.new(cx, y + h + 6, cz), Color3.fromRGB(84, 62, 42), Enum.Material.WoodPlanks)
	sub:Ladder(Vector3.new(cx - 6, y, cz), h, WOOD_DARK)
end

function Forest.Build(b)
	local rng = Random.new(1201)
	local terrain = workspace.Terrain
	local B = MapKit.BOUNDS

	-- ground
	b:TerrainBox(-170, -14, -190, 170, 0, 190, GRASS)
	-- west ridge (high ground), split by the river gorge
	for z = -78, 78, 12 do
		if math.abs(z) > 14 then
			b:TerrainBall(Vector3.new(-90 + rng:NextNumber(-4, 4), -6, z), 20 + rng:NextNumber(0, 3), GRASS)
			b:TerrainBall(Vector3.new(-104, -4, z), 16, Enum.Material.Rock)
		end
	end
	-- soft hills elsewhere for varied terrain
	for _, h in ipairs({ { 40, -70, 14 }, { -40, 70, 14 }, { 30, 95, 10 }, { -30, -95, 10 }, { -50, 0, 10 } }) do
		b:TerrainBall(Vector3.new(h[1], -h[3] + 5, h[2]), h[3], GRASS)
	end
	-- east ravine (low route)
	for z = -70, 70, 8 do
		b:TerrainBall(Vector3.new(84 + math.sin(z / 20) * 4, 3, z), 12, Enum.Material.Air)
	end
	b:TerrainBox(74, -12, -66, 94, -9, 66, Enum.Material.Mud)
	-- river across the map
	b:TerrainBox(-170, -6, -9, 170, 2, 9, Enum.Material.Air)
	b:TerrainBox(-170, -10, -9, 170, -6, 9, Enum.Material.Mud)
	b:TerrainBox(-170, -6, -8, 170, -2.4, 8, Enum.Material.Water)
	-- gorge through the ridge so the river and the rope bridge cut it cleanly
	b:TerrainBox(-118, 2, -12, -64, 50, 12, Enum.Material.Air)
	-- gentle river banks
	for x = -160, 160, 10 do
		b:TerrainBall(Vector3.new(x, -5, -10), 4, Enum.Material.Mud)
		b:TerrainBall(Vector3.new(x, -5, 10), 4, Enum.Material.Mud)
	end
	-- dirt paths
	local function path(x0, z0, x1, z1)
		local a = b:WorldPos(Vector3.new(math.min(x0, x1), -6, math.min(z0, z1)))
		local c = b:WorldPos(Vector3.new(math.max(x0, x1), 30, math.max(z0, z1)))
		terrain:ReplaceMaterial(Region3.new(a, c):ExpandToGrid(4), 4, GRASS, Enum.Material.Ground)
	end
	path(-6, -112, 6, -12)
	path(-6, 12, 6, 112)
	path(-96, -60, -84, 60)
	path(40, -110, 48, -12)
	path(-48, 12, -40, 110)

	-- spawns
	local redSpawns, redZone = MapKit.SpawnBase(b, "Red", { floorColor = Color3.fromRGB(96, 78, 58), floorMat = Enum.Material.WoodPlanks, wallColor = Color3.fromRGB(100, 72, 46), wallMat = Enum.Material.WoodPlanks })
	local blueSpawns, blueZone = MapKit.SpawnBase(b, "Blue", { floorColor = Color3.fromRGB(96, 78, 58), floorMat = Enum.Material.WoodPlanks, wallColor = Color3.fromRGB(100, 72, 46), wallMat = Enum.Material.WoodPlanks })

	-- bridges
	bridge(b, -90, 8, 28, 13, false, false) -- high bridge across the ridge gorge
	bridge(b, 0, 14, 24, 2.5, true, true) -- covered main bridge
	bridge(b, 46, 9, 22, 2, false, true)

	-- cabins and towers (point-symmetric for fairness)
	cabin(b, -30, -42, false)
	cabin(b, 30, 42, true)
	watchtower(b, 58, -78)
	watchtower(b, -58, 78)

	-- abandoned camp sites in the clearings
	local props = b:Sub("Props")
	for _, s in ipairs({ -1, 1 }) do
		MapKit.CrateStack(props, Vector3.new(14 * s, gy(b, 14 * s, 28 * s), 28 * s))
		MapKit.Barrel(props, Vector3.new(-12 * s, gy(b, -12 * s, 22 * s), 22 * s), Color3.fromRGB(90, 70, 50))
		MapKit.Sandbags(props, Vector3.new(0, gy(b, 0, 24 * s), 24 * s), 10, 0, Color3.fromRGB(130, 116, 90))
		log(props, 22 * s, -62 * s, 70, 14)
		log(props, -16 * s, -78 * s, 15, 12)
		log(props, 70 * s, 20 * s, 85, 10)
		-- campfire ring
		local cx, cz = 24 * s, 86 * s
		local gy = gy(b, cx, cz)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			props:Part(Vector3.new(1.2, 0.8, 1.2), Vector3.new(cx + math.cos(a) * 2.2, gy + 0.3, cz + math.sin(a) * 2.2), ROCK, Enum.Material.Slate)
		end
		local fire = props:Part(Vector3.new(1, 0.6, 1), Vector3.new(cx, gy + 0.3, cz), Color3.fromRGB(80, 40, 20), Enum.Material.Wood, { CanCollide = false })
		local f = Instance.new("Fire")
		f.Size = 4
		f.Heat = 6
		f.Parent = fire
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 150, 70)
		l.Range = 18
		l.Brightness = 2
		l.Parent = fire
	end

	-- boulders on the ridge for cover
	for z = -70, 70, 14 do
		if math.abs(z) > 16 then
			rock(props, -82 + rng:NextNumber(-3, 3), z + rng:NextNumber(-4, 4), rng, 5 + rng:NextNumber() * 3)
		end
	end
	-- ravine rocks
	for z = -60, 60, 16 do
		rock(props, 84 + rng:NextNumber(-5, 5), z, rng, 4)
	end

	-- trees: scatter avoiding lanes, bases, river and structures
	local function blocked(x, z)
		if math.abs(z) < 14 then
			return true -- river
		end
		if math.abs(z) > 108 and math.abs(x) < 30 then
			return true -- bases
		end
		if math.abs(x) < 8 then
			return true -- main path
		end
		if (math.abs(x + 30) < 18 and math.abs(z + 42) < 15) or (math.abs(x - 30) < 18 and math.abs(z - 42) < 15) then
			return true -- cabins
		end
		if (math.abs(x - 58) < 9 and math.abs(z + 78) < 9) or (math.abs(x + 58) < 9 and math.abs(z - 78) < 9) then
			return true
		end
		if math.abs(x - 84) < 9 and math.abs(z) < 66 then
			return true -- ravine floor
		end
		return false
	end
	local trees = b:Sub("Trees")
	local placed = 0
	local tries = 0
	while placed < 135 and tries < 1200 do
		tries += 1
		local x = rng:NextNumber(B.x0 + 4, B.x1 - 4)
		local z = rng:NextNumber(B.z0 + 4, B.z1 - 4)
		if not blocked(x, z) then
			if rng:NextNumber() < 0.75 then
				pine(trees, x, z, rng)
			else
				broadleaf(trees, x, z, rng)
			end
			placed += 1
			if rng:NextNumber() < 0.45 then
				bush(trees, x + rng:NextNumber(-5, 5), z + rng:NextNumber(-5, 5), rng)
			end
		end
	end
	-- dense backdrop outside the play area
	for i = 1, 70 do
		local side = i % 4
		local x, z
		if side == 0 then
			x, z = rng:NextNumber(-160, 160), rng:NextNumber(146, 175)
		elseif side == 1 then
			x, z = rng:NextNumber(-160, 160), rng:NextNumber(-175, -146)
		elseif side == 2 then
			x, z = rng:NextNumber(126, 160), rng:NextNumber(-170, 170)
		else
			x, z = rng:NextNumber(-160, -126), rng:NextNumber(-170, 170)
		end
		pine(trees, x, z, rng, 1.3 + rng:NextNumber() * 0.5)
	end

	b:Boundary(B.x0, B.z0, B.x1, B.z1, -20, 120)

	return {
		Spawns = { Red = redSpawns, Blue = blueSpawns },
		SpawnZones = { Red = redZone, Blue = blueZone },
		Podium = MapKit.PODIUM,
		KillY = -30,
		Bounds = { -172, -16, -192, 172, 40, 192 },
	}
end

function Forest.BuildPreview(b)
	b:Box(-3, 0, -3, 3, 0.4, 3, Color3.fromRGB(70, 130, 60), Enum.Material.Grass)
	b:Box(-3, 0.4, -0.35, 3, 0.45, 0.35, Color3.fromRGB(70, 140, 200), Enum.Material.Glass, { Transparency = 0.2 })
	b:Box(-0.6, 0.45, -0.6, 0.6, 0.6, 0.6, Color3.fromRGB(110, 78, 48), Enum.Material.WoodPlanks)
	local rng = Random.new(7)
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-2.7, 2.7), rng:NextNumber(-2.7, 2.7)
		if math.abs(z) > 0.7 then
			b:Box(x - 0.06, 0.4, z - 0.06, x + 0.06, 0.9, z + 0.06, Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
			b:Cyl(0.5, 0.7, CFrame.new(x, 1.1, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 100, 50), Enum.Material.Grass)
			b:Cyl(0.4, 0.45, CFrame.new(x, 1.45, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(50, 120, 56), Enum.Material.Grass)
		end
	end
	b:Box(-2.6, 0.4, -2.4, -1.6, 0.9, -1.6, Color3.fromRGB(118, 84, 54), Enum.Material.WoodPlanks)
	b:Box(1.6, 0.4, 1.6, 2.6, 0.9, 2.4, Color3.fromRGB(118, 84, 54), Enum.Material.WoodPlanks)
end

return Forest
