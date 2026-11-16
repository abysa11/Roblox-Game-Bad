--[[
	MAP 5 - MAYA JUNGLE CITY "Temple of the Jaguar"
	Mossy grey stepped architecture in a dense jungle (deliberately nothing like the smooth
	sandstone of the Egypt map):
	  * Centre : the Great Pyramid - six jumpable tiers, steep stairways facing both teams,
	             a shrine with a red roof comb on top and a dark tunnel through its base
	  * East   : the ball court - two long sloped platforms with stone rings, an open alley
	  * West   : the cenote - a flooded sinkhole with ramps to a stone island and a cave
	             tunnel that comes up in a trench at the pyramid's west tunnel mouth
	  * Each half: a three-tier side temple and overgrown ruins with carved stelae
]]

local MapKit = require(script.Parent.Parent.MapKit)

local Maya = {}

local STONE = Color3.fromRGB(128, 132, 118)
local STONE_LIGHT = Color3.fromRGB(156, 158, 142)
local STONE_DARK = Color3.fromRGB(96, 100, 90)
local MOSS = Color3.fromRGB(70, 110, 58)
local TEMPLE_RED = Color3.fromRGB(150, 52, 40)
local JADE = Color3.fromRGB(40, 150, 110)
local SLATE = Enum.Material.Slate
local COBBLE = Enum.Material.Cobblestone

local TIER_H = 4.5

local function gy(b, x, z)
	return b:GroundY(x, z, nil, true)
end

-- square carved glyph tile (stylised, original) on a wall frame
local function glyphTile(b, cf: CFrame, rng)
	b:Part(Vector3.new(1.8, 1.8, 0.2), cf * CFrame.new(0, 0, -0.1), STONE_DARK, SLATE, { CanCollide = false, CastShadow = false })
	for _ = 1, 3 do
		local w, h = rng:NextNumber(0.3, 1.2), rng:NextNumber(0.25, 0.9)
		b:Part(Vector3.new(w, h, 0.12), cf * CFrame.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5), -0.25), STONE_LIGHT, SLATE, { CanCollide = false, CastShadow = false })
	end
end

local function stela(b, x, z, rotY, rng)
	local y = gy(b, x, z)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotY), 0)
	b:Part(Vector3.new(4, 1, 2.4), cf * CFrame.new(0, 0.3, 0), STONE_DARK, COBBLE)
	b:Part(Vector3.new(3, 9, 1.4), cf * CFrame.new(0, 5, 0), STONE, SLATE)
	for row = 0, 2 do
		glyphTile(b, cf * CFrame.new(0, 3 + row * 2.2, -0.7), rng)
	end
	b:Part(Vector3.new(3.2, 0.6, 1.6), cf * CFrame.new(0, 9.7, 0), MOSS, Enum.Material.Grass, { CanCollide = false })
end

local function jungleTree(b, x, z, rng)
	local y = gy(b, x, z)
	local t = b:Sub("JungleTree")
	local h = 16 + rng:NextNumber() * 10
	t:Column(Vector3.new(x, y - 1, z), h, 2 + rng:NextNumber(), Color3.fromRGB(96, 80, 60), Enum.Material.Wood)
	-- buttress roots
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + rng:NextNumber()
		t:Part(Vector3.new(0.8, 3, 4), CFrame.new(x + math.cos(a) * 1.6, y + 1, z + math.sin(a) * 1.6) * CFrame.Angles(0, -a, 0), Color3.fromRGB(90, 74, 56), Enum.Material.Wood)
	end
	for _ = 1, 4 do
		local off = Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-1.5, 1.5), rng:NextNumber(-5, 5))
		local s = 8 + rng:NextNumber() * 5
		t:Ball(s * 0.75, Vector3.new(x, y + h, z) + off, Color3.fromRGB(40 + rng:NextInteger(0, 20), 100 + rng:NextInteger(0, 30), 46), Enum.Material.Grass, { CanCollide = false })
	end
	-- hanging vines
	for _ = 1, 3 do
		local vx, vz = x + rng:NextNumber(-4, 4), z + rng:NextNumber(-4, 4)
		local len = rng:NextNumber(5, 10)
		t:Part(Vector3.new(0.25, len, 0.25), Vector3.new(vx, y + h - len / 2 - 1, vz), Color3.fromRGB(60, 110, 50), Enum.Material.Grass, { CanCollide = false, NoBullets = true, CastShadow = false })
	end
end

local function palm(b, x, z, rng)
	local y = gy(b, x, z)
	local h = 12 + rng:NextNumber() * 6
	local t = b:Sub("Palm")
	t:Column(Vector3.new(x, y - 1, z), h, 1.2, Color3.fromRGB(120, 100, 70), Enum.Material.Wood)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		t:Part(Vector3.new(1.8, 0.2, 8), CFrame.new(x, y + h, z) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -3.6) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(50, 130, 60), Enum.Material.Grass, { CanCollide = false, NoBullets = true })
	end
end

local function fern(b, x, z, rng)
	local y = gy(b, x, z)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber()
		b:Part(Vector3.new(1.2, 0.2, 4), CFrame.new(x, y + 0.8, z) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.6) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(60, 140 + rng:NextInteger(-20, 20), 60), Enum.Material.Grass, { CanCollide = false, NoBullets = true, CastShadow = false })
	end
	b:Ball(3 + rng:NextNumber() * 2, Vector3.new(x, y + 0.8, z), Color3.fromRGB(46, 110, 50), Enum.Material.Grass, { CanCollide = false, NoBullets = true, CastShadow = false })
end

local function greatPyramid(b)
	local sub = b:Sub("GreatPyramid")
	local tunnelTop = 7
	for i = 0, 5 do
		local half = 28 - i * 4
		local y0, y1 = i * TIER_H, (i + 1) * TIER_H
		local color = (i % 2 == 0) and STONE or STONE_LIGHT
		if y0 < tunnelTop then
			sub:Box(-half, y0, -half, half, y1, -3, color, COBBLE)
			sub:Box(-half, y0, 3, half, y1, half, color, COBBLE)
			if y1 > tunnelTop then
				sub:Box(-half, tunnelTop, -3, half, y1, 3, color, COBBLE)
			end
		else
			sub:Box(-half, y0, -half, half, y1, half, color, COBBLE)
		end
		-- moss lip on each tier
		sub:Box(-half - 0.1, y1 - 0.4, -half - 0.1, half + 0.1, y1, half + 0.1, MOSS, Enum.Material.Grass, { CastShadow = false })
		-- carved panel band on the east/west faces
		if i == 2 then
			for z = -half + 4, half - 4, 6 do
				if math.abs(z) > 6 then
					sub:Part(Vector3.new(0.3, 2.6, 4), Vector3.new(half + 0.1, y0 + 2.2, z), STONE_DARK, SLATE, { CanCollide = false })
					sub:Part(Vector3.new(0.3, 2.6, 4), Vector3.new(-half - 0.1, y0 + 2.2, z), STONE_DARK, SLATE, { CanCollide = false })
				end
			end
		end
	end
	local topY = 6 * TIER_H
	-- tunnel lighting
	for _, x in ipairs({ -18, 0, 18 }) do
		sub:Light(Vector3.new(x, 5.5, 0), Color3.fromRGB(255, 160, 80), 14, 1.2)
	end
	-- stairways facing both teams
	for _, s in ipairs({ -1, 1 }) do
		sub:Stairs(Vector3.new(0, 0.2, 42 * s), Vector3.new(0, topY + 0.1, 8 * s), 10, STONE_LIGHT, COBBLE)
		-- balustrades
		for _, x in ipairs({ -5.8, 5.8 }) do
			sub:Ramp(Vector3.new(x, 1.6, 42 * s), Vector3.new(x, topY + 1.6, 8 * s), 1.6, STONE_DARK, COBBLE, { CanCollide = false })
		end
		sub:Part(Vector3.new(3, 3, 4), Vector3.new(-6.5, 1.5, 43 * s), JADE, SLATE) -- serpent heads at the foot
		sub:Part(Vector3.new(3, 3, 4), Vector3.new(6.5, 1.5, 43 * s), JADE, SLATE)
	end
	-- shrine on top
	local x0, x1, z0, z1 = -7, 7, -6, 6
	local h = 8
	sub:Wall(Vector3.new(x0, topY, z0 + 0.6), Vector3.new(x1, topY, z0 + 0.6), h, 1.2, TEMPLE_RED, SLATE, { { c = 7, w = 4, b = 0, t = 6.5 } })
	sub:Wall(Vector3.new(x0, topY, z1 - 0.6), Vector3.new(x1, topY, z1 - 0.6), h, 1.2, TEMPLE_RED, SLATE, { { c = 7, w = 4, b = 0, t = 6.5 } })
	sub:Wall(Vector3.new(x0 + 0.6, topY, z0 + 1.2), Vector3.new(x0 + 0.6, topY, z1 - 1.2), h, 1.2, TEMPLE_RED, SLATE, { { c = 4.8, w = 2.5, b = 2.5, t = 5 } })
	sub:Wall(Vector3.new(x1 - 0.6, topY, z0 + 1.2), Vector3.new(x1 - 0.6, topY, z1 - 1.2), h, 1.2, TEMPLE_RED, SLATE, { { c = 4.8, w = 2.5, b = 2.5, t = 5 } })
	sub:Box(x0 - 1, topY + h, z0 - 1, x1 + 1, topY + h + 1.2, z1 + 1, STONE_DARK, SLATE)
	-- roof comb (lattice)
	for x = -6, 6, 3 do
		sub:Box(x - 0.6, topY + h + 1.2, -0.6, x + 0.6, topY + h + 8, 0.6, TEMPLE_RED, SLATE)
	end
	sub:Box(-6.6, topY + h + 4, -0.5, 6.6, topY + h + 5, 0.5, TEMPLE_RED, SLATE)
	sub:Box(-6.6, topY + h + 7.6, -0.5, 6.6, topY + h + 8.6, 0.5, JADE, SLATE)
	local brazier = sub:Part(Vector3.new(1.4, 1.2, 1.4), Vector3.new(0, topY + 0.6, 0), STONE_DARK, SLATE)
	local f = Instance.new("Fire")
	f.Size = 3
	f.Parent = brazier
	sub:Light(Vector3.new(0, topY + 3, 0), Color3.fromRGB(255, 150, 70), 18, 1.4)
end

local function ballCourt(b)
	local sub = b:Sub("BallCourt")
	local H = 8
	sub:Box(66, 0, -30, 90, 0.4, 30, STONE_LIGHT, COBBLE) -- alley floor
	for _, side in ipairs({ { 54, 66, 1 }, { 90, 102, -1 } }) do
		local x0, x1, dir = side[1], side[2], side[3]
		sub:Box(x0, 0, -30, x1, H, 30, STONE, COBBLE)
		sub:Box(x0 - 0.1, H - 0.4, -30.1, x1 + 0.1, H, 30.1, MOSS, Enum.Material.Grass, { CastShadow = false })
		-- sloped inner face (walkable)
		local innerX = dir > 0 and x1 or x0
		sub:Ramp(Vector3.new(innerX + 6 * dir, 0.4, 0) + Vector3.new(0, 0, 0), Vector3.new(innerX, 4, 0), 58, STONE_LIGHT, COBBLE, nil, 1)
		-- vertical upper wall with the stone ring
		sub:Box(innerX - 0.4 * dir, 4, -30, innerX + 0.01 * dir, H, 30, STONE_LIGHT, COBBLE)
		local ring = sub:Cyl(1.2, 5, CFrame.new(innerX + 0.5 * dir, 6.2, 0), STONE_DARK, SLATE)
		ring.Name = "CourtRing"
		sub:Cyl(1.4, 2.4, CFrame.new(innerX + 0.5 * dir, 6.2, 0), Color3.fromRGB(20, 22, 18), SLATE, { CanCollide = false })
		-- low parapet on top with gaps
		local px = dir > 0 and x0 or x1
		sub:Box(px - 0.6, H, -30, px + 0.6, H + 2.5, -8, STONE_DARK, COBBLE)
		sub:Box(px - 0.6, H, 8, px + 0.6, H + 2.5, 30, STONE_DARK, COBBLE)
		-- stairs up at both ends
		local sx = (x0 + x1) / 2
		sub:Stairs(Vector3.new(sx, 0.2, -40), Vector3.new(sx, H + 0.1, -30), 6, STONE_DARK, COBBLE)
		sub:Stairs(Vector3.new(sx, 0.2, 40), Vector3.new(sx, H + 0.1, 30), 6, STONE_DARK, COBBLE)
		-- small shrine block on top for cover
		sub:Box(sx - 3, H, -3, sx + 3, H + 4, 3, TEMPLE_RED, SLATE)
	end
	for _, z in ipairs({ -18, 0, 18 }) do
		sub:Column(Vector3.new(78, 0.4, z), 0.3, 3, JADE, SLATE)
	end
end

local function cenote(b)
	local cx, cz = -78, 0
	local terrain = workspace.Terrain
	local center = b:WorldPos(Vector3.new(cx, -6, cz))
	terrain:FillCylinder(CFrame.new(center), 22, 16, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(b:WorldPos(Vector3.new(cx, -16, cz))), 6, 15.5, Enum.Material.Water)
	-- cave tunnel east toward the pyramid and an open trench at its mouth
	b:TerrainBox(-63, -10, -4, -46, -3, 4, Enum.Material.Air)
	b:TerrainBox(-48, -10, -4.5, -27, 12, 4.5, Enum.Material.Air)
	local sub = b:Sub("Cenote")
	-- island and walkway
	sub:Box(cx - 5, -14, cz - 5, cx + 5, -10, cz + 5, STONE, COBBLE)
	sub:Box(cx + 4, -11, -3, -60, -10, 3, STONE_DARK, COBBLE)
	-- ramps down from the rim (north and south)
	sub:Ramp(Vector3.new(cx, 0.4, cz - 17), Vector3.new(cx, -10, cz - 5), 6, STONE_DARK, COBBLE)
	sub:Ramp(Vector3.new(cx, 0.4, cz + 17), Vector3.new(cx, -10, cz + 5), 6, STONE_DARK, COBBLE)
	-- tunnel floor, frame and lights
	sub:Box(-64, -11, -4, -46, -10, 4, STONE_DARK, COBBLE)
	sub:Ramp(Vector3.new(-46, -10, 0), Vector3.new(-28, 0.4, 0), 8, STONE_DARK, COBBLE)
	for _, x in ipairs({ -62, -48 }) do
		sub:Box(x - 1, -10, -4.5, x + 1, -3, -3.5, STONE_LIGHT, COBBLE)
		sub:Box(x - 1, -10, 3.5, x + 1, -3, 4.5, STONE_LIGHT, COBBLE)
		sub:Box(x - 1, -3.6, -4.5, x + 1, -2.6, 4.5, STONE_LIGHT, COBBLE)
	end
	sub:Light(Vector3.new(-55, -5, 0), Color3.fromRGB(120, 220, 180), 16, 1)
	sub:Light(Vector3.new(cx, -8, cz), Color3.fromRGB(120, 220, 180), 20, 1)
	-- trench walls lined with stone
	sub:Box(-48, -10, -5.5, -27, 0.5, -4.5, STONE, COBBLE)
	sub:Box(-48, -10, 4.5, -27, 0.5, 5.5, STONE, COBBLE)
	-- rim stones
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		if math.abs(math.sin(a)) < 0.9 then
			sub:Part(Vector3.new(3, 2, 4), CFrame.new(cx + math.cos(a) * 17.5, 0.8, cz + math.sin(a) * 17.5) * CFrame.Angles(0, -a, 0), STONE_DARK, COBBLE)
		end
	end
end

local function sideTemple(b, cx, cz, facing)
	local sub = b:Sub("SideTemple")
	local y = gy(b, cx, cz)
	local f = facing -- +1 => stairs face +Z
	for i = 0, 2 do
		local half = 12 - i * 3
		sub:Box(cx - half, y - 2 + i * TIER_H, cz - half, cx + half, y + (i + 1) * TIER_H, cz + half, (i % 2 == 0) and STONE or STONE_LIGHT, COBBLE)
		sub:Box(cx - half - 0.1, y + (i + 1) * TIER_H - 0.4, cz - half - 0.1, cx + half + 0.1, y + (i + 1) * TIER_H, cz + half + 0.1, MOSS, Enum.Material.Grass, { CastShadow = false })
	end
	local top = y + 3 * TIER_H
	sub:Stairs(Vector3.new(cx, y + 0.2, cz + 20 * f), Vector3.new(cx, top + 0.1, cz + 6 * f), 6, STONE_LIGHT, COBBLE)
	-- small shrine; the wall facing the stairs has a doorway
	local nearZ0, nearZ1 = cz + 2.8, cz + 4
	local farZ0, farZ1 = cz - 4, cz - 2.8
	if f < 0 then
		nearZ0, nearZ1, farZ0, farZ1 = cz - 4, cz - 2.8, cz + 2.8, cz + 4
	end
	sub:Box(cx - 5, top, farZ0, cx + 5, top + 6, farZ1, TEMPLE_RED, SLATE)
	sub:Box(cx - 5, top, cz - 2.8, cx - 3.8, top + 6, cz + 2.8, TEMPLE_RED, SLATE)
	sub:Box(cx + 3.8, top, cz - 2.8, cx + 5, top + 6, cz + 2.8, TEMPLE_RED, SLATE)
	sub:Box(cx - 5, top, nearZ0, cx - 1.6, top + 6, nearZ1, TEMPLE_RED, SLATE)
	sub:Box(cx + 1.6, top, nearZ0, cx + 5, top + 6, nearZ1, TEMPLE_RED, SLATE)
	sub:Box(cx - 1.6, top + 4.6, nearZ0, cx + 1.6, top + 6, nearZ1, TEMPLE_RED, SLATE)
	sub:Box(cx - 5.6, top + 6, cz - 4.6, cx + 5.6, top + 7, cz + 4.6, STONE_DARK, SLATE)
	for x = -4, 4, 2 do
		sub:Box(cx + x - 0.4, top + 7, cz - 0.4, cx + x + 0.4, top + 11, cz + 0.4, TEMPLE_RED, SLATE)
	end
end

local function ruins(b, cx, cz, rng)
	local sub = b:Sub("Ruins")
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = 12 + rng:NextNumber(-2, 4)
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		local y = gy(b, x, z)
		local h = rng:NextNumber(3, 8)
		local len = rng:NextNumber(6, 12)
		local cf = CFrame.new(x, y + h / 2 - 0.5, z) * CFrame.Angles(0, -a + math.pi / 2, 0)
		sub:Part(Vector3.new(len, h, 2), cf, STONE, COBBLE)
		sub:Part(Vector3.new(len + 0.2, 0.6, 2.2), cf * CFrame.new(0, h / 2, 0), MOSS, Enum.Material.Grass, { CanCollide = false })
	end
	for _ = 1, 4 do
		local x, z = cx + rng:NextNumber(-9, 9), cz + rng:NextNumber(-9, 9)
		sub:Part(Vector3.new(3, 2, 3), CFrame.new(x, gy(b, x, z) + 0.8, z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber() * 6, 0), STONE_DARK, COBBLE)
	end
	stela(sub, cx, cz, rng:NextNumber() * 360, rng)
	local altarY = gy(b, cx + 5, cz + 5)
	sub:Column(Vector3.new(cx + 5, altarY - 0.5, cz + 5), 3, 5, STONE_LIGHT, SLATE)
end

function Maya.Build(b)
	local B = MapKit.BOUNDS
	local rng = Random.new(5150)
	local terrain = workspace.Terrain

	-- jungle floor
	b:TerrainBox(-170, -24, -190, 170, 0, 190, Enum.Material.LeafyGrass)
	-- rolling jungle mounds away from the main structures
	for _, h in ipairs({ { -100, -40, 9 }, { 100, 50, 9 }, { -30, -90, 8 }, { 30, 90, 8 }, { 110, -100, 10 }, { -110, 100, 10 } }) do
		b:TerrainBall(Vector3.new(h[1], -h[3] + 4, h[2]), h[3], Enum.Material.Grass)
	end
	-- mud paths
	local function path(x0, z0, x1, z1)
		local a = b:WorldPos(Vector3.new(math.min(x0, x1), -6, math.min(z0, z1)))
		local c = b:WorldPos(Vector3.new(math.max(x0, x1), 20, math.max(z0, z1)))
		terrain:ReplaceMaterial(Region3.new(a, c):ExpandToGrid(4), 4, Enum.Material.LeafyGrass, Enum.Material.Mud)
	end
	path(-6, -112, 6, -44)
	path(-6, 44, 6, 112)
	path(70, -100, 82, 100)
	path(-82, -100, -70, 100)

	-- stone plaza around the pyramid (with a gap for the cenote trench)
	b:Slab(-40, -48, 40, 48, 0.4, 0.8, STONE_DARK, COBBLE, { { -48, -5.5, -27, 5.5 } })

	cenote(b)
	greatPyramid(b)
	ballCourt(b)

	for _, s in ipairs({ -1, 1 }) do
		sideTemple(b, -62 * s, -80 * s, s)
		ruins(b, 62 * s, -78 * s, rng)
		-- stelae along the approach and scattered cover
		stela(b, -14 * s, -60 * s, s > 0 and 0 or 180, rng)
		stela(b, 14 * s, -60 * s, s > 0 and 0 or 180, rng)
		for _, p in ipairs({ { -30, -70 }, { 36, -56 }, { 20, -96 }, { -44, -40 }, { 100, -64 } }) do
			local x, z = p[1] * s, p[2] * s
			b:Part(Vector3.new(6, 4, 3), CFrame.new(x, gy(b, x, z) + 1.5, z) * CFrame.Angles(0, rng:NextNumber() * 6, 0), STONE, COBBLE)
		end
	end

	-- spawns
	local redSpawns, redZone = MapKit.SpawnBase(b, "Red", { floorColor = STONE_DARK, floorMat = COBBLE, wallColor = STONE, wallMat = COBBLE })
	local blueSpawns, blueZone = MapKit.SpawnBase(b, "Blue", { floorColor = STONE_DARK, floorMat = COBBLE, wallColor = STONE, wallMat = COBBLE })

	-- jungle vegetation
	local function blocked(x, z)
		if math.abs(x) < 46 and math.abs(z) < 52 then
			return true -- pyramid + plaza + stairs
		end
		if x > 50 and x < 106 and math.abs(z) < 44 then
			return true -- ball court
		end
		if (x + 78) ^ 2 + z ^ 2 < 22 ^ 2 then
			return true -- cenote
		end
		if math.abs(z) > 108 and math.abs(x) < 30 then
			return true -- bases
		end
		if math.abs(x) < 8 then
			return true
		end
		for _, c in ipairs({ { -62, -80 }, { 62, 80 } }) do
			if math.abs(x - c[1]) < 16 and math.abs(z - c[2]) < 26 then
				return true
			end
		end
		for _, c in ipairs({ { 62, -78 }, { -62, 78 } }) do
			if math.abs(x - c[1]) < 16 and math.abs(z - c[2]) < 16 then
				return true
			end
		end
		return false
	end
	local veg = b:Sub("Jungle")
	local placed, tries = 0, 0
	while placed < 120 and tries < 1500 do
		tries += 1
		local x = rng:NextNumber(B.x0 + 4, B.x1 - 4)
		local z = rng:NextNumber(B.z0 + 4, B.z1 - 4)
		if not blocked(x, z) then
			local r = rng:NextNumber()
			if r < 0.55 then
				jungleTree(veg, x, z, rng)
			elseif r < 0.8 then
				palm(veg, x, z, rng)
			else
				fern(veg, x, z, rng)
			end
			if rng:NextNumber() < 0.6 then
				fern(veg, x + rng:NextNumber(-5, 5), z + rng:NextNumber(-5, 5), rng)
			end
			placed += 1
		end
	end
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
		jungleTree(veg, x, z, rng)
	end

	b:Boundary(B.x0, B.z0, B.x1, B.z1, -20, 120)
	return {
		Spawns = { Red = redSpawns, Blue = blueSpawns },
		SpawnZones = { Red = redZone, Blue = blueZone },
		Podium = MapKit.PODIUM,
		KillY = -28,
		Bounds = { -172, -26, -192, 172, 40, 192 },
	}
end

function Maya.BuildPreview(b)
	b:Box(-3, 0, -3, 3, 0.3, 3, Color3.fromRGB(60, 120, 60), Enum.Material.Grass)
	for i = 0, 4 do
		local w = 3.4 - i * 0.6
		b:Box(-w / 2, 0.3 + i * 0.4, -w / 2, w / 2, 0.7 + i * 0.4, w / 2, (i % 2 == 0) and STONE or STONE_LIGHT, COBBLE)
	end
	b:Box(-0.4, 2.3, -0.3, 0.4, 2.8, 0.3, TEMPLE_RED, SLATE)
	b:Box(-0.25, 0.5, 1.7, 0.25, 2.2, 2.2, STONE_LIGHT, COBBLE)
	local rng = Random.new(9)
	for _ = 1, 8 do
		local x, z = rng:NextNumber(-2.7, 2.7), rng:NextNumber(-2.7, 2.7)
		if math.abs(x) > 1.9 or math.abs(z) > 1.9 then
			b:Ball(0.9, Vector3.new(x, 1.1, z), Color3.fromRGB(40, 120, 50), Enum.Material.Grass)
			b:Box(x - 0.05, 0.3, z - 0.05, x + 0.05, 0.8, z + 0.05, Color3.fromRGB(90, 70, 50), Enum.Material.Wood)
		end
	end
end

return Maya
