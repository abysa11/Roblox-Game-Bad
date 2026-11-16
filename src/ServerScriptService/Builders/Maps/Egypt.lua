--[[
	MAP 4 - ANCIENT EGYPT "Sands of Kemet"
	Point-symmetric layout:
	  * Centre: the Great Temple - pylon gateways, a dim hypostyle hall full of columns,
	    side doors and an accessible roof (high ground), obelisks and seated colossi outside
	  * Each team's left : a bustling market street with awnings, pottery and mud-brick houses
	    with roof terraces reached by outside stairs
	  * Each team's right: temple ruins with broken columns, a fallen obelisk, a sphinx and a
	    sunken courtyard (lower level) entered by ramps
	Decorative bands of carved relief motifs (ankh, eye, bird, water) run along temple walls.
]]

local Builder = require(script.Parent.Parent.Builder)
local MapKit = require(script.Parent.Parent.MapKit)

local Egypt = {}

local SAND = Color3.fromRGB(222, 192, 138)
local STONE = Color3.fromRGB(214, 180, 122)
local STONE_DARK = Color3.fromRGB(176, 142, 92)
local MUD = Color3.fromRGB(176, 136, 96)
local GOLD = Color3.fromRGB(240, 190, 70)
local LAPIS = Color3.fromRGB(30, 70, 150)
local RUST = Color3.fromRGB(170, 60, 40)
local SANDSTONE = Enum.Material.Sandstone

-- carved relief motif, drawn on a wall plane. `cf` = wall-surface frame (look = out of wall)
local function motif(b, cf: CFrame, kind: number, color: Color3)
	local d = 0.25
	local function bar(w, h, x, y, rot)
		b:Part(Vector3.new(w, h, d), cf * CFrame.new(x, y, -d / 2) * CFrame.Angles(0, 0, math.rad(rot or 0)), color, SANDSTONE, { CastShadow = false, CanCollide = false })
	end
	if kind == 1 then -- ankh
		bar(0.35, 2.2, 0, -0.4)
		bar(1.6, 0.35, 0, 0.5)
		bar(0.3, 1.0, -0.38, 1.25, -20)
		bar(0.3, 1.0, 0.38, 1.25, 20)
		bar(0.6, 0.3, 0, 1.7)
	elseif kind == 2 then -- eye
		bar(2.2, 0.3, 0, 0.6, -6)
		bar(1.6, 0.3, 0, -0.1, 4)
		bar(0.5, 0.5, 0, 0.25)
		bar(0.25, 1.1, 0.5, -0.65, 15)
		bar(1.0, 0.25, -0.9, -0.55, -30)
	elseif kind == 3 then -- bird
		bar(1.6, 0.6, 0, 0, 12)
		bar(0.5, 0.5, 0.95, 0.35)
		bar(0.9, 0.25, -1.1, -0.3, 30)
		bar(0.2, 0.8, 0.1, -0.7)
		bar(0.2, 0.8, -0.3, -0.7)
	else -- water zigzag
		for i = -2, 2 do
			bar(0.7, 0.22, i * 0.55, (i % 2 == 0) and 0.15 or -0.15, (i % 2 == 0) and 35 or -35)
		end
	end
end

-- band of motifs along a wall segment from a to c (local points at band height)
local function glyphBand(b, a: Vector3, c: Vector3, outward: Vector3)
	local dir = (c - a)
	local len = dir.Magnitude
	dir = dir.Unit
	local sub = b:Sub("Relief")
	-- painted stripes above/below the band
	local mid = (a + c) / 2
	local frame = CFrame.lookAt(mid, mid + outward)
	sub:Part(Vector3.new(len, 0.4, 0.15), frame * CFrame.new(0, 2.2, -0.05), LAPIS, Enum.Material.SmoothPlastic, { CanCollide = false })
	sub:Part(Vector3.new(len, 0.4, 0.15), frame * CFrame.new(0, -1.8, -0.05), RUST, Enum.Material.SmoothPlastic, { CanCollide = false })
	local count = math.floor(len / 3.2)
	for i = 0, count - 1 do
		local p = a + dir * (1.6 + i * 3.2)
		motif(sub, CFrame.lookAt(p, p + outward), (i % 4) + 1, STONE_DARK)
	end
end

local function column(b, x, z, h, d, broken)
	local sub = b:Sub("Column")
	sub:Column(Vector3.new(x, 0, z), 1.2, d + 1.2, STONE_DARK, SANDSTONE)
	local height = broken and h * (0.3 + math.random() * 0.4) or h
	sub:Column(Vector3.new(x, 1.2, z), height - 1.2, d, STONE, SANDSTONE)
	-- painted bands
	sub:Column(Vector3.new(x, height * 0.75, z), 0.6, d + 0.1, LAPIS, Enum.Material.SmoothPlastic)
	if not broken then
		-- papyrus capital
		sub:Column(Vector3.new(x, h, z), 1.2, d + 1.6, GOLD:Lerp(STONE, 0.5), SANDSTONE)
		sub:Box(x - d / 2 - 1, h + 1.2, z - d / 2 - 1, x + d / 2 + 1, h + 2, z + d / 2 + 1, STONE_DARK, SANDSTONE)
	else
		sub:Part(Vector3.new(d, d * 0.9, d), CFrame.new(x + d, d * 0.45, z + 1) * CFrame.Angles(0, 0.6, math.pi / 2), STONE, SANDSTONE)
	end
end

local function obelisk(b, x, z, h, fallen, rotY)
	local sub = b:Sub("Obelisk")
	if fallen then
		local cf = CFrame.new(x, 2, z) * CFrame.Angles(0, math.rad(rotY or 0), 0) * CFrame.Angles(0, 0, math.rad(4))
		sub:Part(Vector3.new(h * 0.7, 3.4, 3.4), cf, STONE, SANDSTONE)
		sub:Part(Vector3.new(h * 0.25, 3.0, 3.0), cf * CFrame.new(h * 0.52, -0.2, 1.2) * CFrame.Angles(0, 0.3, 0.2), STONE, SANDSTONE)
		return
	end
	sub:Box(x - 3, 0, z - 3, x + 3, 2, z + 3, STONE_DARK, SANDSTONE)
	local layers = 6
	for i = 0, layers - 1 do
		local w = 2.6 - i * 0.25
		sub:Box(x - w / 2, 2 + i * h / layers, z - w / 2, x + w / 2, 2 + (i + 1) * h / layers, z + w / 2, STONE, SANDSTONE)
	end
	local tip = 2.6 - layers * 0.25
	sub:Wedge(Vector3.new(tip, 2, tip / 2), CFrame.new(x, 2 + h + 1, z - tip / 4), GOLD, Enum.Material.Foil)
	sub:Wedge(Vector3.new(tip, 2, tip / 2), CFrame.new(x, 2 + h + 1, z + tip / 4) * CFrame.Angles(0, math.pi, 0), GOLD, Enum.Material.Foil)
end

-- original seated colossus statue (stylised, blocky)
local function colossus(b, x, z, facing)
	local sub = b:Sub("Colossus")
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(facing), 0)
	sub:Part(Vector3.new(8, 4, 10), cf * CFrame.new(0, 2, 0), STONE_DARK, SANDSTONE)
	sub:Part(Vector3.new(6, 6, 4), cf * CFrame.new(0, 7, 2.5), STONE_DARK, SANDSTONE) -- throne back
	sub:Part(Vector3.new(5, 5, 3), cf * CFrame.new(0, 6.5, 0.5), STONE, SANDSTONE) -- torso
	sub:Part(Vector3.new(5, 2, 4), cf * CFrame.new(0, 5, -2), STONE, SANDSTONE) -- lap
	sub:Part(Vector3.new(1.6, 4, 1.6), cf * CFrame.new(-1.4, 2, -3.8), STONE, SANDSTONE)
	sub:Part(Vector3.new(1.6, 4, 1.6), cf * CFrame.new(1.4, 2, -3.8), STONE, SANDSTONE)
	sub:Part(Vector3.new(2.6, 3, 2.6), cf * CFrame.new(0, 10.4, 0.5), STONE, SANDSTONE) -- head
	sub:Part(Vector3.new(4, 3.6, 2.4), cf * CFrame.new(0, 10.2, 1.1), LAPIS, Enum.Material.SmoothPlastic) -- headdress
	sub:Part(Vector3.new(0.5, 1.4, 0.5), cf * CFrame.new(0, 8.4, -0.9), GOLD, Enum.Material.Foil) -- beard
	sub:Part(Vector3.new(2.8, 0.5, 2.8), cf * CFrame.new(0, 12.1, 0.5), GOLD, Enum.Material.Foil)
end

local function sphinx(b, x, z, facing)
	local sub = b:Sub("Sphinx")
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(facing), 0)
	sub:Part(Vector3.new(8, 2, 24), cf * CFrame.new(0, 1, 0), STONE_DARK, SANDSTONE)
	sub:Part(Vector3.new(7, 5, 14), cf * CFrame.new(0, 4.5, 3), STONE, SANDSTONE) -- body
	sub:Part(Vector3.new(2, 2, 8), cf * CFrame.new(-2.4, 3, -7), STONE, SANDSTONE) -- paws
	sub:Part(Vector3.new(2, 2, 8), cf * CFrame.new(2.4, 3, -7), STONE, SANDSTONE)
	sub:Part(Vector3.new(5, 5, 5), cf * CFrame.new(0, 8, -4), STONE, SANDSTONE) -- chest
	sub:Part(Vector3.new(3.2, 3.4, 3.2), cf * CFrame.new(0, 11.6, -4.6), STONE, SANDSTONE) -- head
	sub:Part(Vector3.new(5.6, 4, 2.4), cf * CFrame.new(0, 11.2, -3.6), LAPIS:Lerp(STONE, 0.3), SANDSTONE) -- headdress
end

local function stall(b, x, z, rotY, cloth)
	local sub = b:Sub("Stall")
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(rotY), 0)
	for _, p in ipairs({ { -3, -2 }, { 3, -2 }, { -3, 2 }, { 3, 2 } }) do
		sub:Part(Vector3.new(0.5, 7, 0.5), cf * CFrame.new(p[1], 3.5, p[2]), Color3.fromRGB(120, 86, 54), Enum.Material.Wood)
	end
	sub:Part(Vector3.new(7.4, 0.3, 5.4), cf * CFrame.new(0, 7.2, 0) * CFrame.Angles(math.rad(8), 0, 0), cloth, Enum.Material.Fabric, { CanCollide = false })
	sub:Part(Vector3.new(6.4, 3, 2), cf * CFrame.new(0, 1.5, -1.4), Color3.fromRGB(140, 100, 64), Enum.Material.WoodPlanks)
	for i = -1, 1 do
		sub:Ball(1.2, (cf * CFrame.new(i * 1.8, 3.6, -1.4)).Position, Color3.fromRGB(180, 100, 60), Enum.Material.Slate, { CanCollide = false })
	end
	sub:Column((cf * CFrame.new(2.6, 0, 2.6)).Position, 2.4, 1.6, Color3.fromRGB(170, 96, 60), Enum.Material.Slate)
end

local function palm(b, x, z, rng)
	local sub = b:Sub("Palm")
	local h = 14 + rng:NextNumber() * 4
	local lean = rng:NextNumber(-0.15, 0.15)
	for i = 0, 5 do
		local y = i * h / 6
		sub:Part(Vector3.new(1.3 - i * 0.08, h / 6 + 0.2, 1.3 - i * 0.08), CFrame.new(x + lean * y, y + h / 12, z) * CFrame.Angles(0, 0, -lean), Color3.fromRGB(130, 100, 64), Enum.Material.Wood)
	end
	local top = Vector3.new(x + lean * h, h, z)
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		sub:Part(Vector3.new(1.6, 0.2, 7), CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -3) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(70, 130, 50), Enum.Material.Grass, { CanCollide = false, NoBullets = true })
	end
end

local function greatTemple(b)
	local sub = b:Sub("GreatTemple")
	local H = 16
	local x0, x1, z0, z1 = -30, 30, -24, 24
	-- hall floor
	sub:Box(x0, 0, z0, x1, 0.6, z1, STONE_DARK, SANDSTONE)
	-- walls with side doors (E/W) and wide gate openings (N/S)
	sub:Wall(Vector3.new(x0, 0.6, z0 + 1), Vector3.new(x1, 0.6, z0 + 1), H, 2, STONE, SANDSTONE, { { c = 30, w = 10, b = 0, t = 11 } })
	sub:Wall(Vector3.new(x0, 0.6, z1 - 1), Vector3.new(x1, 0.6, z1 - 1), H, 2, STONE, SANDSTONE, { { c = 30, w = 10, b = 0, t = 11 } })
	sub:Wall(Vector3.new(x0 + 1, 0.6, z0 + 2), Vector3.new(x0 + 1, 0.6, z1 - 2), H, 2, STONE, SANDSTONE, { { c = 22, w = 6, b = 0, t = 8 }, { c = 8, w = 3, b = 7, t = 10 }, { c = 36, w = 3, b = 7, t = 10 } })
	sub:Wall(Vector3.new(x1 - 1, 0.6, z0 + 2), Vector3.new(x1 - 1, 0.6, z1 - 2), H, 2, STONE, SANDSTONE, { { c = 22, w = 6, b = 0, t = 8 }, { c = 8, w = 3, b = 7, t = 10 }, { c = 36, w = 3, b = 7, t = 10 } })
	-- roof with skylight slots (thin beams of light into the hall)
	local roofY = H + 0.6
	sub:Slab(x0, z0, x1, z1, roofY + 1.2, 1.2, STONE_DARK, SANDSTONE, { { -2, -14, 2, -6 }, { -2, 6, 2, 14 } })
	sub:Box(x0, roofY + 1.2, z0, x1, roofY + 3.4, z0 + 1, STONE, SANDSTONE)
	sub:Box(x0, roofY + 1.2, z1 - 1, x1, roofY + 3.4, z1, STONE, SANDSTONE)
	-- side parapets have a gap where the outside stairs arrive
	sub:Box(x0, roofY + 1.2, z0, x0 + 1, roofY + 3.4, 1, STONE, SANDSTONE)
	sub:Box(x0, roofY + 1.2, 7, x0 + 1, roofY + 3.4, z1, STONE, SANDSTONE)
	sub:Box(x1 - 1, roofY + 1.2, z0, x1, roofY + 3.4, -7, STONE, SANDSTONE)
	sub:Box(x1 - 1, roofY + 1.2, -1, x1, roofY + 3.4, z1, STONE, SANDSTONE)
	-- hypostyle columns inside
	for _, x in ipairs({ -20, -10, 10, 20 }) do
		for _, z in ipairs({ -12, 0, 12 }) do
			column(sub, x, z, H - 2, 3.4, false)
		end
	end
	-- central altar (cover)
	sub:Box(-4, 0.6, -3, 4, 4, 3, STONE_DARK, SANDSTONE)
	sub:Box(-4.4, 4, -3.4, 4.4, 4.6, 3.4, GOLD, Enum.Material.Foil)
	-- torches inside
	for _, p in ipairs({ { -27, -18 }, { 27, 18 }, { -27, 18 }, { 27, -18 } }) do
		local t = sub:Part(Vector3.new(0.6, 0.6, 0.6), Vector3.new(p[1], 7, p[2]), Color3.fromRGB(255, 160, 60), Enum.Material.Neon, { CanCollide = false })
		local f = Instance.new("Fire")
		f.Size = 2
		f.Heat = 4
		f.Parent = t
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 160, 80)
		l.Range = 20
		l.Brightness = 1.6
		l.Parent = t
	end
	-- pylon gateways at both ends (tall battered towers flanking the gate) + roof access
	for _, s in ipairs({ -1, 1 }) do
		local zf = s * 24
		for _, sx in ipairs({ -1, 1 }) do
			local px0, px1 = sx * 5, sx * 22
			local pz0, pz1 = zf - 2 * s, zf + 4 * s
			sub:Box(px0, 0, pz0, px1, H + 8, pz1, STONE, SANDSTONE)
			sub:Box(px0, H + 8, pz0, px1, H + 9.5, pz1, STONE_DARK, SANDSTONE)
			glyphBand(sub, Vector3.new(px0, H - 2, pz1 + 0.05 * s), Vector3.new(px1, H - 2, pz1 + 0.05 * s), Vector3.new(0, 0, s))
		end
		-- lintel over the gate
		sub:Box(-5, 11, zf - 2 * s, 5, 14, zf + 4 * s, STONE_DARK, SANDSTONE)
		sub:Box(-5, 13, zf + 4 * s, 5, 13.6, zf + 4.3 * s, GOLD, Enum.Material.Foil)
		-- outside stairs up the long wall to the roof (high above the side door)
		sub:Stairs(Vector3.new(33 * s, 0.2, 20 * s), Vector3.new(33 * s, roofY + 1.3, -4 * s), 5, STONE_DARK, SANDSTONE)
		-- obelisks and colossi in front of each gate
		obelisk(b, -12, zf + 14 * s, 26, false)
		obelisk(b, 12, zf + 14 * s, 26, false)
		colossus(b, -9, zf + 7 * s, s > 0 and 180 or 0)
		colossus(b, 9, zf + 7 * s, s > 0 and 180 or 0)
	end
	-- relief bands along the long walls (outside)
	glyphBand(sub, Vector3.new(-30, 9, -24.05), Vector3.new(30, 9, -24.05), Vector3.new(0, 0, -1))
	glyphBand(sub, Vector3.new(-30.05, 9, -20), Vector3.new(-30.05, 9, 20), Vector3.new(-1, 0, 0))
	glyphBand(sub, Vector3.new(30.05, 9, -20), Vector3.new(30.05, 9, 20), Vector3.new(1, 0, 0))
end

local function mudHouse(b, x0, z0, x1, z1, doorSide, stairsAt)
	local sub, roofY = b:Building({
		name = "MudHouse", x0 = x0, z0 = z0, x1 = x1, z1 = z1, y = 0,
		floors = 1, floorH = 10, wall = 1.4,
		color = MUD, mat = Enum.Material.Sandstone,
		floorColor = Color3.fromRGB(160, 124, 86), floorMat = Enum.Material.Ground,
		doors = { { side = doorSide, at = 0.5, w = 5, h = 7.5 } },
		windows = { spacing = 7, w = 2.5, h = 2, b = 5, groundFloor = true },
		roof = true, parapet = 1, stairs = false,
	})
	-- outside stairs to the roof terrace
	if stairsAt then
		sub:Stairs(stairsAt[1], Vector3.new(stairsAt[2].X, roofY + 0.1, stairsAt[2].Z), 3.5, STONE_DARK, SANDSTONE)
	end
	-- awning pole decoration
	sub:Box(x0 + 1, roofY, z0 + 1, x0 + 1.4, roofY + 5, z0 + 1.4, Color3.fromRGB(120, 86, 54), Enum.Material.Wood)
	return sub
end

function Egypt.Build(b)
	local B = MapKit.BOUNDS
	local rng = Random.new(3301)

	-- ground with two sunken courtyards cut out (point-symmetric)
	local sunken = { { 62, -72, 98, -40 }, { -98, 40, -62, 72 } }
	b:Slab(B.x0 - 50, B.z0 - 50, B.x1 + 50, B.z1 + 50, 0, 3, SAND, Enum.Material.Sand, sunken)

	greatTemple(b)

	for _, s in ipairs({ -1, 1 }) do
		local function X(x)
			return x * s
		end
		local function Z(z)
			return z * s
		end
		local function P(x, y, z)
			return Vector3.new(X(x), y, Z(z))
		end
		local function rect(ax, az, bx, bz)
			return math.min(X(ax), X(bx)), math.min(Z(az), Z(bz)), math.max(X(ax), X(bx)), math.max(Z(az), Z(bz))
		end

		-- MARKET STREET (left of the team for s = 1, i.e. west of Red)
		local houses = {
			{ -110, -100, -86, -80, s > 0 and "E" or "W", { P(-108, 0.2, -101.8), P(-90, 0, -101.8) } },
			{ -110, -66, -88, -46, s > 0 and "E" or "W", nil },
			{ -110, -34, -90, -12, s > 0 and "E" or "W", { P(-108, 0.2, -35.8), P(-92, 0, -35.8) } },
			{ -64, -98, -44, -80, s > 0 and "W" or "E", nil },
			{ -62, -62, -42, -40, s > 0 and "W" or "E", { P(-60, 0.2, -63.8), P(-44, 0, -63.8) } },
		}
		for _, h in ipairs(houses) do
			local x0, z0, x1, z1 = rect(h[1], h[2], h[3], h[4])
			mudHouse(b, x0, z0, x1, z1, h[5], h[6])
		end
		local cloths = { Color3.fromRGB(200, 60, 50), Color3.fromRGB(40, 90, 170), Color3.fromRGB(230, 200, 90), Color3.fromRGB(60, 140, 90) }
		for i, z in ipairs({ -92, -74, -56, -38, -20 }) do
			stall(b, X(-74), Z(z), (s > 0 and 90 or -90) + rng:NextNumber(-8, 8), cloths[(i % #cloths) + 1])
		end
		MapKit.CrateStack(b, P(-80, 0, -66), Color3.fromRGB(170, 130, 80))
		MapKit.Crate(b, P(-68, 0, -30), 4, Color3.fromRGB(170, 130, 80), 20)
		-- water jars
		for i = 0, 3 do
			b:Column(P(-84 + i * 2.4, 0, -6), 3, 1.8, Color3.fromRGB(180, 100, 60), Enum.Material.Slate)
		end

		-- RUINS (right of the team for s = 1)
		local rx0, rz0, rx1, rz1 = rect(62, -72, 98, -40)
		-- sunken courtyard: floor at -6, retaining walls, ramps down from two sides
		b:Box(rx0, -9, rz0, rx1, -6, rz1, STONE_DARK, SANDSTONE)
		b:Ramp(P(80, 0.1, -72), P(80, -6, -61), 8, STONE_DARK, SANDSTONE)
		b:Ramp(P(80, 0.1, -40), P(80, -6, -51), 8, STONE_DARK, SANDSTONE)
		-- retaining walls (with gaps where the ramps arrive)
		local wallY = -6
		b:Wall(P(62, wallY, -72), P(76, wallY, -72), 6, 1, STONE, SANDSTONE)
		b:Wall(P(84, wallY, -72), P(98, wallY, -72), 6, 1, STONE, SANDSTONE)
		b:Wall(P(62, wallY, -40), P(76, wallY, -40), 6, 1, STONE, SANDSTONE)
		b:Wall(P(84, wallY, -40), P(98, wallY, -40), 6, 1, STONE, SANDSTONE)
		b:Wall(P(62, wallY, -72), P(62, wallY, -40), 6, 1, STONE, SANDSTONE)
		b:Wall(P(98, wallY, -72), P(98, wallY, -40), 6, 1, STONE, SANDSTONE)
		-- pool and columns in the courtyard
		local poolFrame = b:Box(X(74) - 0.01, -6, Z(-60), X(86), -5.6, Z(-52), Color3.fromRGB(60, 150, 200), Enum.Material.Glass, { Transparency = 0.3, CanCollide = false, NoBullets = true })
		poolFrame.Name = "Pool"
		for _, p in ipairs({ { 66, -68 }, { 94, -68 }, { 66, -44 }, { 94, -44 } }) do
			b:Column(P(p[1], -6, p[2]), 5, 2.4, STONE, SANDSTONE)
		end
		for _, p in ipairs({ { 70, -56 }, { 90, -56 } }) do
			b:Box(X(p[1]) - 2, -6, Z(p[2]) - 2, X(p[1]) + 2, -2.5, Z(p[2]) + 2, STONE_DARK, SANDSTONE)
		end
		-- broken colonnade, fallen obelisk and sphinx above ground
		for i, z in ipairs({ -100, -90, -80 }) do
			column(b, X(60), Z(z), 14, 3, i ~= 2)
			column(b, X(100), Z(z), 14, 3, i == 2)
		end
		obelisk(b, X(78), Z(-14), 30, true, s > 0 and 20 or 200)
		sphinx(b, X(46), Z(-100), s > 0 and 0 or 180)
		-- ruin wall fragments for cover
		b:Box(X(44) - 1, 0, Z(-66) - 6, X(44) + 1, 6, Z(-66) + 6, STONE, SANDSTONE)
		b:Box(X(108) - 6, 0, Z(-24) - 1, X(108) + 6, 4.5, Z(-24) + 1, STONE, SANDSTONE)
		b:Box(X(56) - 5, 0, Z(-30) - 1, X(56) + 5, 7, Z(-30) + 1, STONE, SANDSTONE)
		b:Part(Vector3.new(6, 3, 3), CFrame.new(X(64), 1.4, Z(-20)) * CFrame.Angles(0.1, 0.5, 0.2), STONE_DARK, SANDSTONE)
		-- palms by the courtyard and the market
		for _, p in ipairs({ { 104, -78 }, { 56, -86 }, { -100, -40 }, { -60, -74 }, { 40, -44 } }) do
			palm(b, X(p[1]), Z(p[2]), rng)
		end
		-- low walls near the centre lanes
		b:Box(X(-30) - 6, 0, Z(-46) - 1, X(-30) + 6, 4, Z(-46) + 1, STONE_DARK, SANDSTONE)
		b:Box(X(30) - 1, 0, Z(-48) - 5, X(30) + 1, 4, Z(-48) + 5, STONE_DARK, SANDSTONE)
	end

	-- spawns
	local redSpawns, redZone = MapKit.SpawnBase(b, "Red", { floorColor = STONE_DARK, floorMat = SANDSTONE, wallColor = STONE, wallMat = SANDSTONE })
	local blueSpawns, blueZone = MapKit.SpawnBase(b, "Blue", { floorColor = STONE_DARK, floorMat = SANDSTONE, wallColor = STONE, wallMat = SANDSTONE })

	-- backdrop: pyramids and dunes outside the play area
	local bd = b:Sub("Backdrop")
	local function pyramid(x, z, size)
		local layers = 24
		for i = 0, layers - 1 do
			local w = size * (1 - i / layers)
			bd:Box(x - w / 2, i * size / layers * 0.6, z - w / 2, x + w / 2, (i + 1) * size / layers * 0.6, z + w / 2, SAND:Lerp(STONE, 0.5), SANDSTONE, { CanQuery = false, CastShadow = i < 4 })
		end
		bd:Box(x - size / layers, size * 0.6, z - size / layers, x + size / layers, size * 0.6 + 2, z + size / layers, GOLD, Enum.Material.Foil, { CanQuery = false })
	end
	pyramid(-190, -60, 120)
	pyramid(200, 80, 150)
	pyramid(60, 230, 90)
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local r = 210 + rng:NextNumber(0, 40)
		bd:Part(Vector3.new(80, 14, 40), CFrame.new(math.cos(a) * r, -2, math.sin(a) * r) * CFrame.Angles(0, -a, math.rad(rng:NextNumber(-6, 6))), SAND, Enum.Material.Sand, { CanQuery = false })
	end

	b:Boundary(B.x0, B.z0, B.x1, B.z1, -10, 120)
	return {
		Spawns = { Red = redSpawns, Blue = blueSpawns },
		SpawnZones = { Red = redZone, Blue = blueZone },
		Podium = MapKit.PODIUM,
		KillY = -40,
	}
end

function Egypt.BuildPreview(b)
	b:Box(-3, 0, -3, 3, 0.3, 3, SAND, Enum.Material.Sand)
	for i = 0, 5 do
		local w = 3 - i * 0.5
		b:Box(-w / 2 - 1, 0.3 + i * 0.35, -w / 2 - 1, w / 2 - 1, 0.65 + i * 0.35, w / 2 - 1, STONE, SANDSTONE)
	end
	b:Box(1, 0.3, 0.5, 2.6, 1.3, 2.6, STONE_DARK, SANDSTONE)
	b:Box(1.6, 0.3, -2.4, 1.9, 2.6, -2.1, STONE, SANDSTONE)
	b:Box(1.65, 2.6, -2.35, 1.85, 2.8, -2.15, GOLD, Enum.Material.Foil)
	local _ = Builder
end

return Egypt
