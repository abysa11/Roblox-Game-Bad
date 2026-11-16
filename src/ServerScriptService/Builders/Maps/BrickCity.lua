--[[
	MAP 3 - BRICK CITY "Toybox Town"
	A giant toy world built from plastic building bricks (all original shapes, no logos).
	Point-symmetric layout:
	  * Centre: a brick castle with a raised courtyard, corner towers and a tight tunnel underneath
	  * West : "Tower Park" - stacked brick towers of different heights linked by plates
	  * East : "Toy Street" - bright toy houses with slope-brick roofs, toy cars, a toy train
	  * Oversized 2x4 bricks everywhere as cover, block trees and lollipop trees
]]

local MapKit = require(script.Parent.Parent.MapKit)

local BrickCity = {}

local RED = Color3.fromRGB(218, 36, 36)
local YELLOW = Color3.fromRGB(255, 205, 0)
local BLUE = Color3.fromRGB(20, 100, 220)
local GREEN = Color3.fromRGB(40, 165, 70)
local WHITE = Color3.fromRGB(245, 245, 245)
local ORANGE = Color3.fromRGB(255, 130, 20)
local LIME = Color3.fromRGB(150, 210, 40)
local PURPLE = Color3.fromRGB(140, 70, 200)
local BLACK = Color3.fromRGB(30, 30, 34)
local PALETTE = { RED, YELLOW, BLUE, GREEN, WHITE, ORANGE, LIME, PURPLE }

local PLASTIC = Enum.Material.Plastic
local STUD = 4 -- size of one oversized stud cell

-- Brick with big 3D studs on top. Axis-aligned, base at y.
local function brick(b, x0, y, z0, x1, z1, h, color, bigStuds)
	local p = b:Box(x0, y, z0, x1, y + h, z1, color, PLASTIC, { Studs = true })
	if bigStuds ~= false then
		local nx = math.max(1, math.floor(math.abs(x1 - x0) / STUD + 0.5))
		local nz = math.max(1, math.floor(math.abs(z1 - z0) / STUD + 0.5))
		if nx * nz <= 24 then
			local sx = (x1 - x0) / nx
			local sz = (z1 - z0) / nz
			for i = 0, nx - 1 do
				for k = 0, nz - 1 do
					b:Column(Vector3.new(x0 + sx * (i + 0.5), y + h, z0 + sz * (k + 0.5)), 1, 2.6, color, PLASTIC, { CastShadow = false })
				end
			end
		end
	end
	return p
end

-- 2x4 cover brick
local function coverBrick(b, x, z, rotated, color, y)
	if rotated then
		return brick(b, x - 4, y or 0, z - 8, x + 4, z + 8, 5, color)
	end
	return brick(b, x - 8, y or 0, z - 4, x + 8, z + 4, 5, color)
end

local function blockTree(b, x, z, rng)
	local t = b:Sub("BlockTree")
	brick(t, x - 1.5, 0, z - 1.5, x + 1.5, z + 1.5, 7, Color3.fromRGB(120, 70, 30), false)
	local g = rng:NextNumber() < 0.5 and GREEN or LIME
	brick(t, x - 6, 7, z - 6, x + 6, z + 6, 3, g, false)
	brick(t, x - 4, 10, z - 4, x + 4, z + 4, 3, g, false)
	brick(t, x - 2, 13, z - 2, x + 2, z + 2, 3, g, true)
end

local function lollipopTree(b, x, z, rng)
	b:Column(Vector3.new(x, 0, z), 9, 1.2, Color3.fromRGB(120, 70, 30), PLASTIC)
	b:Ball(8, Vector3.new(x, 12, z), PALETTE[rng:NextInteger(1, #PALETTE)], Enum.Material.SmoothPlastic, { CanCollide = false })
end

local function toyCar(b, x, z, rotY, color)
	local t = b:Sub("ToyCar")
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(rotY), 0)
	t:Part(Vector3.new(7, 2.4, 13), cf * CFrame.new(0, 2.6, 0), color, PLASTIC, { Studs = true })
	t:Part(Vector3.new(6, 3, 6), cf * CFrame.new(0, 5.3, 1), WHITE, PLASTIC, { Studs = true })
	t:Part(Vector3.new(5.6, 2, 0.4), cf * CFrame.new(0, 5.4, -2.1), Color3.fromRGB(120, 200, 255), Enum.Material.Glass, { Transparency = 0.3 })
	for _, wx in ipairs({ -3.8, 3.8 }) do
		for _, wz in ipairs({ -4.2, 4.2 }) do
			t:Cyl(1.6, 3.6, cf * CFrame.new(wx, 1.8, wz), BLACK, PLASTIC)
			t:Cyl(1.7, 1.6, cf * CFrame.new(wx, 1.8, wz), Color3.fromRGB(200, 200, 205), PLASTIC)
		end
	end
	t:Part(Vector3.new(1.4, 1, 0.3), cf * CFrame.new(-2.2, 3, -6.6), YELLOW, Enum.Material.Neon)
	t:Part(Vector3.new(1.4, 1, 0.3), cf * CFrame.new(2.2, 3, -6.6), YELLOW, Enum.Material.Neon)
end

local function toyHouse(b, x0, z0, x1, z1, wallColor, roofColor, doorSide)
	local sub, roofY = b:Building({
		name = "ToyHouse", x0 = x0, z0 = z0, x1 = x1, z1 = z1, y = 0.4,
		floors = 2, floorH = 10, wall = 2,
		color = wallColor, mat = PLASTIC,
		floorColor = Color3.fromRGB(200, 200, 200), floorMat = PLASTIC,
		trimColor = WHITE,
		doors = { { side = doorSide, at = 0.5, w = 6, h = 8 }, { side = doorSide == "N" and "S" or "N", at = 0.3, w = 5, h = 8 } },
		windows = { spacing = 8, w = 4, h = 4, b = 3, groundFloor = true },
		roof = true, parapet = 2.5,
	})
	-- chunky slope-brick roof edge (wedges) on the long sides
	local w = x1 - x0
	sub:Wedge(Vector3.new(w + 1, 3, 3), CFrame.new((x0 + x1) / 2, roofY + 1.5, z0 - 1), roofColor, PLASTIC)
	sub:Wedge(Vector3.new(w + 1, 3, 3), CFrame.new((x0 + x1) / 2, roofY + 1.5, z1 + 1) * CFrame.Angles(0, math.pi, 0), roofColor, PLASTIC)
	-- window frames in contrasting colour
	for _, p in ipairs(sub.Folder:GetDescendants()) do
		if p:IsA("BasePart") then
			p.TopSurface = Enum.SurfaceType.Studs
		end
	end
	return sub
end

local function brickTower(b, x, z, size, height, color)
	local sub = b:Sub("BrickTower")
	local layers = math.floor(height / 5)
	for i = 0, layers - 1 do
		local c = (i % 2 == 0) and color or color:Lerp(WHITE, 0.25)
		brick(sub, x - size / 2, i * 5, z - size / 2, x + size / 2, z + size / 2, 5, c, i == layers - 1)
	end
	-- ladder on one face
	sub:Ladder(Vector3.new(x, 0, z + size / 2 + 1), layers * 5, YELLOW)
	return layers * 5
end

local function plate(b, a: Vector3, c: Vector3, width, color)
	-- flat plate bridge between two tower tops
	return b:Ramp(a + Vector3.new(0, 1.6, 0), c + Vector3.new(0, 1.6, 0), width, color, PLASTIC, { Studs = true }, 1.2)
end

local function castle(b)
	local sub = b:Sub("Castle")
	local gray = Color3.fromRGB(160, 165, 172)
	local dark = Color3.fromRGB(110, 114, 122)
	-- raised courtyard platform (height 6); a tight N-S tunnel runs underneath at x in [-6, 6]
	local h = 6
	sub:Box(-26, 0, -20, -8, h, 20, gray, PLASTIC, { Studs = true })
	sub:Box(8, 0, -20, 26, h, 20, gray, PLASTIC, { Studs = true })
	sub:Box(-8, h - 1.2, -20, 8, h, 20, dark, PLASTIC, { Studs = true })
	sub:Box(-8, 0, -20, -6, h - 1.2, 20, dark, PLASTIC)
	sub:Box(6, 0, -20, 8, h - 1.2, 20, dark, PLASTIC)
	for _, z in ipairs({ -10, 10 }) do
		b:Light(Vector3.new(0, h - 2, z), Color3.fromRGB(255, 220, 120), 14, 1)
	end
	-- stairs up to the courtyard from both teams' sides
	for _, s in ipairs({ -1, 1 }) do
		sub:Stairs(Vector3.new(-17, 0.2, 30 * s), Vector3.new(-17, h + 0.1, 20 * s), 6, RED, PLASTIC)
		sub:Stairs(Vector3.new(17, 0.2, 30 * s), Vector3.new(17, h + 0.1, 20 * s), 6, BLUE, PLASTIC)
	end
	-- crenellated walls on the courtyard
	for _, s in ipairs({ -1, 1 }) do
		for _, x in ipairs({ -24, -6, 6, 24 }) do
			do
				brick(sub, x - 2, h, 19.5 * s - 0.5, x + 2, 19.5 * s + 0.5, 4, gray, false)
			end
		end
	end
	-- four round corner towers
	for _, p in ipairs({ { -26, -20 }, { 26, -20 }, { -26, 20 }, { 26, 20 } }) do
		for i = 0, 4 do
			sub:Column(Vector3.new(p[1], i * 5, p[2]), 5, 10, (i % 2 == 0) and gray or dark, PLASTIC)
		end
		sub:Column(Vector3.new(p[1], 25, p[2]), 1, 11, YELLOW, PLASTIC)
		sub:Wedge(Vector3.new(2, 4, 4), CFrame.new(p[1], 28, p[2]), RED, PLASTIC)
	end
	-- courtyard cover
	coverBrick(sub, 0, 0, false, YELLOW, h)
	coverBrick(sub, -14, 10, true, BLUE, h)
	coverBrick(sub, 14, -10, true, RED, h)
	-- flag
	sub:Column(Vector3.new(0, h + 5, 0), 12, 0.8, WHITE, PLASTIC)
	sub:Box(0.4, h + 13, -0.2, 6, h + 17, 0.2, ORANGE, PLASTIC)
end

function BrickCity.Build(b)
	local B = MapKit.BOUNDS
	local rng = Random.new(2024)

	-- baseplates
	b:Box(B.x0 - 40, -2, B.z0 - 40, B.x1 + 40, 0, B.z1 + 40, GREEN, PLASTIC, { Studs = true })
	-- grey road plates
	b:Box(-12, 0, B.z0, 12, 0.4, B.z1, Color3.fromRGB(110, 114, 120), PLASTIC, { Studs = true })
	b:Box(B.x0, 0, -52, B.x1, 0.4, -40, Color3.fromRGB(110, 114, 120), PLASTIC, { Studs = true })
	b:Box(B.x0, 0, 40, B.x1, 0.4, 52, Color3.fromRGB(110, 114, 120), PLASTIC, { Studs = true })
	for z = -130, 130, 12 do
		if math.abs(z) > 24 then
			b:Box(-0.6, 0.4, z - 3, 0.6, 0.5, z + 3, YELLOW, PLASTIC)
		end
	end

	castle(b)

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

		-- TOWER PARK (west for s=1, east for s=-1)
		local towers = {
			{ -96, -84, 10, 20, RED },
			{ -76, -70, 8, 15, YELLOW },
			{ -100, -58, 8, 10, BLUE },
			{ -86, -26, 10, 25, GREEN },
			{ -64, -24, 8, 10, ORANGE },
			{ -102, -6, 8, 15, PURPLE },
		}
		local tops = {}
		for i, t in ipairs(towers) do
			local top = brickTower(b, X(t[1]), Z(t[2]), t[3], t[4], t[5])
			tops[i] = Vector3.new(X(t[1]), top, Z(t[2]))
		end
		plate(b, tops[1] + Vector3.new(0, 0, 0), tops[2], 4, WHITE)
		plate(b, tops[2], tops[4], 4, WHITE)
		plate(b, tops[3], tops[6], 4, LIME)
		plate(b, tops[4], tops[5], 4, WHITE)
		for _, c in ipairs({ { -84, -100, false }, { -110, -74, true }, { -60, -88, true }, { -72, -12, false }, { -104, -30, true }, { -54, -62, false } }) do
			coverBrick(b, X(c[1]), Z(c[2]), c[3], PALETTE[rng:NextInteger(1, #PALETTE)])
		end

		-- TOY STREET (east for s=1, west for s=-1)
		local hx0, hz0, hx1, hz1 = rect(28, -100, 54, -76)
		toyHouse(b, hx0, hz0, hx1, hz1, s > 0 and BLUE or RED, YELLOW, s > 0 and "S" or "N")
		hx0, hz0, hx1, hz1 = rect(70, -100, 104, -70)
		toyHouse(b, hx0, hz0, hx1, hz1, YELLOW, RED, s > 0 and "S" or "N")
		hx0, hz0, hx1, hz1 = rect(30, -30, 60, -8)
		toyHouse(b, hx0, hz0, hx1, hz1, WHITE, BLUE, s > 0 and "N" or "S")
		hx0, hz0, hx1, hz1 = rect(76, -32, 106, -6)
		toyHouse(b, hx0, hz0, hx1, hz1, LIME, PURPLE, "W")
		toyCar(b, X(40), Z(-58), 90, RED)
		toyCar(b, X(84), Z(-46), 92, YELLOW)
		toyCar(b, X(20), Z(-20), 0, BLUE)
		-- toy train on a track along the cross street
		local tz = Z(-46)
		b:Box(X(-110), 0.4, tz - 2.5, X(-40), 0.7, tz + 2.5, Color3.fromRGB(80, 80, 86), PLASTIC)
		for i, color in ipairs({ RED, BLUE, YELLOW }) do
			local cx = X(-100 + (i - 1) * 16)
			b:Box(cx - 6.5, 0.7, tz - 3.5, cx + 6.5, 6, tz + 3.5, color, PLASTIC, { Studs = true })
			if i == 1 then
				b:Box(cx - 3, 6, tz - 3, cx + 3, 9.5, tz + 3, BLACK, PLASTIC, { Studs = true })
				b:Column(Vector3.new(cx + 4 * s, 6, tz), 3, 2, BLACK, PLASTIC)
			end
			for _, wx in ipairs({ -4, 4 }) do
				b:Cyl(1, 2.6, CFrame.new(cx + wx, 1.5, tz - 3.8), BLACK, PLASTIC)
				b:Cyl(1, 2.6, CFrame.new(cx + wx, 1.5, tz + 3.8), BLACK, PLASTIC)
			end
		end

		-- trees and scattered cover near the bases
		for _, p in ipairs({ { -40, -100 }, { 40, -96 }, { -60, -60 }, { 30, -66 }, { 62, -110 }, { -30, -70 } }) do
			if rng:NextNumber() < 0.5 then
				blockTree(b, X(p[1]), Z(p[2]), rng)
			else
				lollipopTree(b, X(p[1]), Z(p[2]), rng)
			end
		end
		coverBrick(b, X(-24), Z(-84), true, ORANGE)
		coverBrick(b, X(24), Z(-90), true, PURPLE)
		coverBrick(b, X(0), Z(-62), false, WHITE)
		coverBrick(b, X(-40), Z(-34), false, RED)
		coverBrick(b, X(38), Z(-38), true, GREEN)
		-- stacked brick staircase to a lookout plate over the avenue
		for i = 0, 3 do
			brick(b, X(-20) - 4, i * 3, Z(-30 - i * 6) - 3, X(-20) + 4, Z(-30 - i * 6) + 3, 3, PALETTE[(i % #PALETTE) + 1], i == 3)
		end
	end

	-- spawns
	local redSpawns, redZone = MapKit.SpawnBase(b, "Red", { floorColor = WHITE, floorMat = PLASTIC, wallColor = Color3.fromRGB(240, 70, 70), wallMat = PLASTIC })
	local blueSpawns, blueZone = MapKit.SpawnBase(b, "Blue", { floorColor = WHITE, floorMat = PLASTIC, wallColor = Color3.fromRGB(70, 130, 240), wallMat = PLASTIC })

	-- giant toy backdrop: letter blocks and crayons outside the play area
	local deco = b:Sub("Backdrop")
	local letters = { "A", "B", "C", "D", "E", "F", "G", "H" }
	for i = 1, 16 do
		local side = i % 2 == 0 and 1 or -1
		local x = side * rng:NextNumber(135, 165)
		local z = rng:NextNumber(-150, 150)
		local size = rng:NextNumber(18, 30)
		local cube = deco:Part(Vector3.new(size, size, size), CFrame.new(x, size / 2, z) * CFrame.Angles(0, rng:NextNumber() * 6, 0), PALETTE[rng:NextInteger(1, #PALETTE)], Enum.Material.SmoothPlastic, { CanQuery = false })
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
			require(script.Parent.Parent.Builder).Label(cube, face, letters[rng:NextInteger(1, #letters)], WHITE, { PixelsPerStud = 2, Stroke = true })
		end
	end
	for i = 1, 8 do
		local side = i % 2 == 0 and 1 or -1
		local z = side * rng:NextNumber(150, 170)
		local x = rng:NextNumber(-110, 110)
		local c = PALETTE[rng:NextInteger(1, #PALETTE)]
		deco:Cyl(60, 8, CFrame.new(x, 4, z) * CFrame.Angles(0, rng:NextNumber() * 3, 0), c, Enum.Material.SmoothPlastic, { CanQuery = false })
	end

	b:Boundary(B.x0, B.z0, B.x1, B.z1, -2, 120)
	return {
		Spawns = { Red = redSpawns, Blue = blueSpawns },
		SpawnZones = { Red = redZone, Blue = blueZone },
		Podium = MapKit.PODIUM,
		KillY = -30,
	}
end

function BrickCity.BuildPreview(b)
	b:Box(-3, 0, -3, 3, 0.3, 3, GREEN, PLASTIC, { Studs = true })
	local cols = { RED, YELLOW, BLUE, WHITE, ORANGE, PURPLE }
	local i = 0
	for x = -2.4, 2.4, 1.6 do
		for z = -2.4, 2.4, 1.6 do
			i += 1
			if (i % 3) ~= 0 then
				local h = 0.4 + (i % 4) * 0.5
				b:Box(x - 0.6, 0.3, z - 0.6, x + 0.6, 0.3 + h, z + 0.6, cols[(i % #cols) + 1], PLASTIC, { Studs = true })
			end
		end
	end
	b:Box(-1, 0.3, -1, 1, 1.3, 1, Color3.fromRGB(160, 165, 172), PLASTIC, { Studs = true })
end

return BrickCity
