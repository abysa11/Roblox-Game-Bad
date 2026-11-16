--[[
	Builder
	Geometry toolkit used by the lobby, the five maps and the podium.
	All coordinates passed to a Builder are LOCAL to its origin CFrame, so a map can be built
	anywhere in the world (several maps can run side by side in one server).
]]

local Builder = {}
Builder.__index = Builder

local DEFAULT_MAT = Enum.Material.SmoothPlastic

function Builder.new(parent: Instance, origin: CFrame)
	local self = setmetatable({}, Builder)
	self.Folder = parent
	self.Origin = origin
	self.Count = 0
	self.Root = self
	return self
end

-- Child builder that puts its parts into a sub-folder (same origin).
function Builder:Sub(name: string, className: string?)
	local f = Instance.new(className or "Folder")
	f.Name = name
	f.Parent = self.Folder
	local b = setmetatable({}, Builder)
	b.Folder = f
	b.Origin = self.Origin
	b.Count = 0
	b.Root = self.Root
	return b
end

function Builder:World(cf: CFrame | Vector3): CFrame
	if typeof(cf) == "Vector3" then
		return self.Origin * CFrame.new(cf)
	end
	return self.Origin * cf
end

function Builder:WorldPos(v: Vector3): Vector3
	return self.Origin:PointToWorldSpace(v)
end

local function applyProps(p: BasePart, props)
	if not props then
		return
	end
	for k, v in pairs(props) do
		if k == "Studs" then
			if v then
				p.TopSurface = Enum.SurfaceType.Studs
				p.BottomSurface = Enum.SurfaceType.Inlet
				p.Material = Enum.Material.Plastic
			end
		elseif k == "NoBullets" then
			if v then
				p.CanQuery = false
			end
		elseif k ~= "Class" then
			(p :: any)[k] = v
		end
	end
end

function Builder:Part(size: Vector3, cf: CFrame | Vector3, color: Color3?, material: Enum.Material?, props: any?): BasePart
	local className = props and props.Class or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = self:World(cf)
	p.Color = color or Color3.fromRGB(160, 160, 160)
	p.Material = material or DEFAULT_MAT
	applyProps(p, props)
	p.Parent = self.Folder
	self.Root.Count += 1
	return p
end

-- Axis-aligned box from two local corners.
function Builder:Box(x0, y0, z0, x1, y1, z1, color, material, props): BasePart
	local minX, maxX = math.min(x0, x1), math.max(x0, x1)
	local minY, maxY = math.min(y0, y1), math.max(y0, y1)
	local minZ, maxZ = math.min(z0, z1), math.max(z0, z1)
	local size = Vector3.new(math.max(maxX - minX, 0.05), math.max(maxY - minY, 0.05), math.max(maxZ - minZ, 0.05))
	return self:Part(size, Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2), color, material, props)
end

function Builder:Wedge(size: Vector3, cf: CFrame | Vector3, color, material, props): BasePart
	local p2 = props and table.clone(props) or {}
	p2.Class = "WedgePart"
	return self:Part(size, cf, color, material, p2)
end

-- Cylinder whose axis runs along local X of `cf`.
function Builder:Cyl(length: number, diameter: number, cf: CFrame | Vector3, color, material, props): BasePart
	local p2 = props and table.clone(props) or {}
	p2.Shape = Enum.PartType.Cylinder
	return self:Part(Vector3.new(length, diameter, diameter), cf, color, material, p2)
end

-- Vertical cylinder standing on `base` (local position of the bottom centre).
function Builder:Column(base: Vector3, height: number, diameter: number, color, material, props): BasePart
	return self:Cyl(height, diameter, CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material, props)
end

function Builder:Ball(diameter: number, pos: Vector3, color, material, props): BasePart
	local p2 = props and table.clone(props) or {}
	p2.Shape = Enum.PartType.Ball
	return self:Part(Vector3.new(diameter, diameter, diameter), pos, color, material, p2)
end

-- Walkable plank from a -> b (points on the walking surface).
function Builder:Ramp(a: Vector3, b: Vector3, width: number, color, material, props, thickness: number?): BasePart
	local t = thickness or 1
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b) * CFrame.new(0, -t / 2, 0)
	return self:Part(Vector3.new(width, t, len), cf, color, material, props)
end

-- Visual steps plus an invisible collision ramp for smooth movement.
function Builder:Stairs(a: Vector3, b: Vector3, width: number, color, material, props)
	local rise = b.Y - a.Y
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local run = flat.Magnitude
	local dir = flat.Unit
	local steps = math.max(2, math.floor(math.abs(rise) / 1.2 + 0.5))
	local stepRun = run / steps
	local stepRise = rise / steps
	local folder = self:Sub("Stairs")
	for i = 0, steps - 1 do
		local top = a.Y + stepRise * (i + 1)
		local h = math.max(0.4, top - math.min(a.Y, b.Y) + 0.2)
		local centerFlat = Vector3.new(a.X, 0, a.Z) + dir * (stepRun * (i + 0.5))
		local center = Vector3.new(centerFlat.X, top - h / 2, centerFlat.Z)
		local cf = CFrame.lookAt(center, center + dir)
		local sp = props and table.clone(props) or {}
		sp.CanCollide = false
		folder:Part(Vector3.new(width, h, stepRun + 0.05), cf, color, material, sp)
	end
	local ramp = folder:Ramp(a + Vector3.new(0, 0.1, 0), b + Vector3.new(0, 0.1, 0), width, color, material, { Transparency = 1, CanQuery = false }, 0.6)
	ramp.Name = "StairRamp"
	return folder
end

-- Climbable ladder (TrussPart). base = local bottom centre.
function Builder:Ladder(base: Vector3, height: number, color)
	local h = math.max(2, math.floor(height / 2 + 0.5) * 2)
	return self:Part(Vector3.new(2, h, 2), base + Vector3.new(0, h / 2, 0), color or Color3.fromRGB(90, 70, 50), Enum.Material.Metal, { Class = "TrussPart" })
end

--[[ Wall along a -> b (base points). openings = { {c=centerDist, w=width, b=bottom, t=top}, ... } ]]
function Builder:Wall(a: Vector3, b: Vector3, height: number, thickness: number, color, material, openings, props)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = flat.Magnitude
	if length < 0.05 then
		return
	end
	local dir = flat.Unit
	local function seg(s, e, y0, y1)
		if e - s < 0.05 or y1 - y0 < 0.05 then
			return
		end
		local center = a + dir * ((s + e) / 2) + Vector3.new(0, (y0 + y1) / 2, 0)
		local cf = CFrame.lookAt(center, center + dir)
		self:Part(Vector3.new(thickness, y1 - y0, e - s), cf, color, material, props)
	end
	local ops = {}
	for _, o in ipairs(openings or {}) do
		table.insert(ops, o)
	end
	table.sort(ops, function(x, y)
		return x.c < y.c
	end)
	local cursor = 0
	for _, o in ipairs(ops) do
		local left = math.clamp(o.c - o.w / 2, 0, length)
		local right = math.clamp(o.c + o.w / 2, 0, length)
		if left > cursor then
			seg(cursor, left, 0, height)
		end
		local lo = math.max(left, cursor)
		if (o.b or 0) > 0 then
			seg(lo, right, 0, o.b)
		end
		if (o.t or height) < height then
			seg(lo, right, o.t, height)
		end
		cursor = math.max(cursor, right)
	end
	seg(cursor, length, 0, height)
end

-- Horizontal slab (top at yTop) with up to several rectangular holes {x0,z0,x1,z1}.
function Builder:Slab(x0, z0, x1, z1, yTop, thickness, color, material, holes, props)
	local rects = { { math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1) } }
	for _, h in ipairs(holes or {}) do
		local hx0, hz0, hx1, hz1 = math.min(h[1], h[3]), math.min(h[2], h[4]), math.max(h[1], h[3]), math.max(h[2], h[4])
		local nextRects = {}
		for _, r in ipairs(rects) do
			local rx0, rz0, rx1, rz1 = r[1], r[2], r[3], r[4]
			if hx1 <= rx0 or hx0 >= rx1 or hz1 <= rz0 or hz0 >= rz1 then
				table.insert(nextRects, r)
			else
				local cx0, cx1 = math.max(rx0, hx0), math.min(rx1, hx1)
				if hz0 > rz0 then
					table.insert(nextRects, { rx0, rz0, rx1, hz0 })
				end
				if hz1 < rz1 then
					table.insert(nextRects, { rx0, hz1, rx1, rz1 })
				end
				local mz0, mz1 = math.max(rz0, hz0), math.min(rz1, hz1)
				if cx0 > rx0 then
					table.insert(nextRects, { rx0, mz0, cx0, mz1 })
				end
				if cx1 < rx1 then
					table.insert(nextRects, { cx1, mz0, rx1, mz1 })
				end
			end
		end
		rects = nextRects
	end
	for _, r in ipairs(rects) do
		self:Box(r[1], yTop - thickness, r[2], r[3], yTop, r[4], color, material, props)
	end
end

--[[
	Enterable multi-storey building.
	spec = {
		x0, z0, x1, z1, y, floors, floorH, wall, color, mat, floorColor, floorMat, trimColor,
		doors = { {side="N"|"S"|"E"|"W", at=0..1, w=6, h=8} },
		windows = { spacing=10, w=4, h=3.5, b=4, groundFloor=true },
		roof = true (accessible roof with parapet), glass = true,
		stairSide = "W" | "E"
	}
	N = -Z side, S = +Z side, W = -X side, E = +X side.
]]
function Builder:Building(spec)
	local b = self:Sub(spec.name or "Building", "Model")
	local x0, z0, x1, z1 = spec.x0, spec.z0, spec.x1, spec.z1
	local y = spec.y or 0
	local floors = spec.floors or 1
	local fh = spec.floorH or 12
	local wt = spec.wall or 1
	local color, mat = spec.color, spec.mat or Enum.Material.Concrete
	local floorColor = spec.floorColor or Color3.fromRGB(120, 120, 125)
	local floorMat = spec.floorMat or Enum.Material.SmoothPlastic
	local rampW = 5
	local run = math.min(fh * 1.7, (z1 - z0) - 6)
	local stairE = spec.stairSide == "E"
	local function lane(k)
		local i = k % 2
		if stairE then
			local right = x1 - wt - i * rampW
			return right - rampW, right
		end
		local left = x0 + wt + i * rampW
		return left, left + rampW
	end
	local rampZ0 = z0 + wt + 1.5
	local rampZ1 = rampZ0 + run
	local totalFloors = floors + ((spec.roof ~= false) and 1 or 0)
	local hasStairs = totalFloors > 1 and spec.stairs ~= false

	-- ground floor slab
	b:Box(x0, y - 1, z0, x1, y + 0.2, z1, floorColor, floorMat)

	for f = 0, floors - 1 do
		local fy = y + f * fh
		local doorsHere = (f == 0) and spec.doors or {}
		local wins = spec.windows
		local function openingsFor(side, length)
			local ops = {}
			for _, d in ipairs(doorsHere) do
				if d.side == side then
					table.insert(ops, { c = d.at * length, w = d.w or 6, b = 0, t = d.h or 8 })
				end
			end
			if wins and (f > 0 or wins.groundFloor) then
				local spacing = wins.spacing or 10
				local n = math.floor((length - 4) / spacing)
				for i = 1, n do
					local c = (length - (n - 1) * spacing) / 2 + (i - 1) * spacing
					local blocked = false
					for _, o in ipairs(ops) do
						if math.abs(o.c - c) < (o.w / 2 + (wins.w or 4) / 2 + 1) then
							blocked = true
						end
					end
					if not blocked then
						table.insert(ops, { c = c, w = wins.w or 4, b = wins.b or 4, t = (wins.b or 4) + (wins.h or 3.5) })
					end
				end
			end
			return ops
		end
		local h = fh
		local nOps = openingsFor("N", x1 - x0)
		local sOps = openingsFor("S", x1 - x0)
		local wOps = openingsFor("W", z1 - z0)
		local eOps = openingsFor("E", z1 - z0)
		b:Wall(Vector3.new(x0, fy, z0 + wt / 2), Vector3.new(x1, fy, z0 + wt / 2), h, wt, color, mat, nOps)
		b:Wall(Vector3.new(x0, fy, z1 - wt / 2), Vector3.new(x1, fy, z1 - wt / 2), h, wt, color, mat, sOps)
		b:Wall(Vector3.new(x0 + wt / 2, fy, z0 + wt), Vector3.new(x0 + wt / 2, fy, z1 - wt), h, wt, color, mat, wOps)
		b:Wall(Vector3.new(x1 - wt / 2, fy, z0 + wt), Vector3.new(x1 - wt / 2, fy, z1 - wt), h, wt, color, mat, eOps)

		if spec.glass and wins and (f > 0 or wins.groundFloor) then
			local glassCol = Color3.fromRGB(150, 200, 230)
			local function glassFor(ops, side)
				for _, o in ipairs(ops) do
					if o.b > 0 then
						local gy0, gy1 = fy + o.b, fy + o.t
						if side == "N" or side == "S" then
							local zz = side == "N" and z0 + wt / 2 or z1 - wt / 2
							b:Box(x0 + o.c - o.w / 2, gy0, zz - 0.1, x0 + o.c + o.w / 2, gy1, zz + 0.1, glassCol, Enum.Material.Glass, { Transparency = 0.6, CanQuery = false, CastShadow = false })
						else
							local xx = side == "W" and x0 + wt / 2 or x1 - wt / 2
							b:Box(xx - 0.1, gy0, z0 + wt + o.c - o.w / 2, xx + 0.1, gy1, z0 + wt + o.c + o.w / 2, glassCol, Enum.Material.Glass, { Transparency = 0.6, CanQuery = false, CastShadow = false })
						end
					end
				end
			end
			glassFor(nOps, "N")
			glassFor(sOps, "S")
			glassFor(wOps, "W")
			glassFor(eOps, "E")
		end

		-- ramp from this floor up to the next one
		if hasStairs and f < totalFloors - 1 then
			local lx0, lx1 = lane(f)
			local cx = (lx0 + lx1) / 2
			b:Ramp(Vector3.new(cx, fy + 0.2, rampZ0), Vector3.new(cx, fy + fh + 0.2, rampZ1), rampW, spec.trimColor or floorColor, floorMat)
		end

		-- slab above this floor
		local ceilY = fy + fh + 0.2
		local holes = {}
		if hasStairs and f < totalFloors - 1 then
			local lx0, lx1 = lane(f)
			table.insert(holes, { lx0, rampZ0 - 0.5, lx1, rampZ1 })
		end
		if f < floors - 1 or spec.roof ~= false then
			b:Slab(x0, z0, x1, z1, ceilY, 1.2, floorColor, floorMat, holes)
		else
			b:Box(x0, ceilY - 1.2, z0, x1, ceilY, z1, floorColor, floorMat)
		end
		-- guard rail along the stair hole on the upper floor
		if #holes > 0 then
			local hole = holes[1]
			local railX = stairE and hole[1] or hole[3]
			b:Box(railX - 0.2, ceilY, hole[2], railX + 0.2, ceilY + 3, hole[4], spec.trimColor or color, Enum.Material.Metal)
		end
	end

	local roofY = y + floors * fh + 0.2
	if spec.roof ~= false then
		local ph = spec.parapet or 3
		local tc = spec.trimColor or color
		b:Box(x0, roofY, z0, x1, roofY + ph, z0 + 0.8, tc, mat)
		b:Box(x0, roofY, z1 - 0.8, x1, roofY + ph, z1, tc, mat)
		b:Box(x0, roofY, z0, x0 + 0.8, roofY + ph, z1, tc, mat)
		b:Box(x1 - 0.8, roofY, z0, x1, roofY + ph, z1, tc, mat)
	end
	return b, roofY
end

-- Invisible boundary walls around a rectangle (players stay in, bullets pass out).
-- Walls only, no ceiling: nobody can jump this high, and a ceiling is something to get stuck on.
function Builder:Boundary(x0, z0, x1, z1, y0, height)
	local t = 4
	local props = { Transparency = 1, CanQuery = false, CastShadow = false }
	local f = self:Sub("Boundary")
	f:Box(x0 - t, y0, z0 - t, x1 + t, y0 + height, z0, nil, nil, props)
	f:Box(x0 - t, y0, z1, x1 + t, y0 + height, z1 + t, nil, nil, props)
	f:Box(x0 - t, y0, z0, x0, y0 + height, z1, nil, nil, props)
	f:Box(x1, y0, z0, x1 + t, y0 + height, z1, nil, nil, props)
end

function Builder:Light(pos: Vector3, color: Color3, range: number, brightness: number?, shadows: boolean?)
	local p = self:Part(Vector3.new(0.4, 0.4, 0.4), pos, color, Enum.Material.Neon, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	p.Name = "LightSource"
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1
	l.Shadows = shadows == true
	l:SetAttribute("WantsShadows", shadows == true)
	l.Parent = p
	return p
end

-- Text on one face of a part.
function Builder.Label(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3?, opts)
	opts = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.PixelsPerStud or 20
	gui.LightInfluence = opts.LightInfluence or 0
	gui.Brightness = opts.Brightness or 1.5
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = opts.Font or Enum.Font.GothamBlack
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = opts.Stroke and 0.3 or 1
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
	return label
end

-- TERRAIN ------------------------------------------------------------------------------
function Builder:TerrainBox(x0, y0, z0, x1, y1, z1, material: Enum.Material)
	local center = self:WorldPos(Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	workspace.Terrain:FillBlock(CFrame.new(center), size, material)
end

function Builder:TerrainBall(pos: Vector3, radius: number, material: Enum.Material)
	workspace.Terrain:FillBall(self:WorldPos(pos), radius, material)
end

function Builder:ClearTerrain(x0, y0, z0, x1, y1, z1)
	self:TerrainBox(x0, y0, z0, x1, y1, z1, Enum.Material.Air)
end

-- Local Y of the ground (terrain or map parts) at local x,z.
function Builder:GroundY(x: number, z: number, fromY: number?, terrainOnly: boolean?): number
	local top = self:WorldPos(Vector3.new(x, fromY or 200, z))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = terrainOnly and { workspace.Terrain } or { workspace.Terrain, self.Root.Folder }
	params.IgnoreWater = true
	local hit = workspace:Raycast(top, Vector3.new(0, -((fromY or 200) + 300), 0), params)
	if hit then
		return self.Origin:PointToObjectSpace(hit.Position).Y
	end
	return 0
end

return Builder
