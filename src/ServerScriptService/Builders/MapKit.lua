--[[
	MapKit
	Pieces shared by all five maps: team spawn bases (spawn points + shop zone), crates,
	barrels and sandbag cover. Map layouts use the same convention:
	  playable area x in [-120, 120], z in [-140, 140]
	  Red base at z = -125 facing +Z, Blue base at z = +125 facing -Z
	  podium floats high above the map at (0, 450, 0)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local MapKit = {}

MapKit.PODIUM = CFrame.new(0, 450, 0)
MapKit.BOUNDS = { x0 = -122, z0 = -142, x1 = 122, z1 = 142 }

--[[
	Team base. opts = { floorColor, floorMat, wallColor, wallMat, y }
	Returns spawn CFrames (local) and the spawn zone used for the weapon shop.
]]
function MapKit.SpawnBase(b, team: string, opts)
	opts = opts or {}
	local sign = team == "Red" and -1 or 1
	local zc = 125 * sign
	local y = opts.y or 0
	local teamColor = Config.Teams[team].Color
	local sub = b:Sub(team .. "Base")
	local floorColor = opts.floorColor or Color3.fromRGB(70, 70, 76)
	local floorMat = opts.floorMat or Enum.Material.Concrete
	local wallColor = opts.wallColor or Color3.fromRGB(90, 90, 96)
	local wallMat = opts.wallMat or Enum.Material.Concrete

	-- floor pad
	sub:Box(-22, y - 1, zc - 12, 22, y + 0.3, zc + 12, floorColor, floorMat)
	-- team stripe & spawn marker
	sub:Box(-22, y + 0.3, zc - 0.4 - 11.6 * sign, 22, y + 0.4, zc + 0.4 - 11.6 * sign, teamColor, Enum.Material.Neon, { CastShadow = false })
	for _, x in ipairs({ -12, 0, 12 }) do
		sub:Box(x - 3, y + 0.3, zc - 3, x + 3, y + 0.35, zc + 3, teamColor:Lerp(Color3.new(0, 0, 0), 0.4), Enum.Material.SmoothPlastic, { CastShadow = false })
	end
	-- back wall and side walls (protect the spawn from long sight lines)
	local backZ = zc + 12 * sign
	sub:Box(-24, y, backZ, 24, y + 14, backZ + 2 * sign, wallColor, wallMat)
	sub:Box(-24, y, zc - 12, -22, y + 9, zc + 12, wallColor, wallMat)
	sub:Box(22, y, zc - 12, 24, y + 9, zc + 12, wallColor, wallMat)
	-- front cover blocks with three exits (left, middle, right)
	local frontZ = zc - 12 * sign
	sub:Box(-16, y, frontZ - 1, -6, y + 4.5, frontZ + 1, wallColor, wallMat)
	sub:Box(6, y, frontZ - 1, 16, y + 4.5, frontZ + 1, wallColor, wallMat)
	-- team banner
	local banner = sub:Box(-8, y + 7, backZ - 0.2 * sign, 8, y + 13, backZ, teamColor, Enum.Material.SmoothPlastic)
	banner.Name = "TeamBanner"
	sub:Light(Vector3.new(0, y + 10, zc), teamColor, 30, 1)

	local spawns = {}
	local facing = Vector3.new(0, 0, -sign)
	for _, x in ipairs({ -14, -7, 0, 7, 14 }) do
		for _, dz in ipairs({ -4, 4 }) do
			local pos = Vector3.new(x, y + 0.5, zc + dz)
			table.insert(spawns, CFrame.lookAt(pos, pos + facing))
		end
	end
	local zone = { CFrame = CFrame.new(0, y + 6, zc), Size = Vector3.new(44, 12, 24) }
	return spawns, zone
end

function MapKit.Crate(b, pos: Vector3, size: number?, color: Color3?, rotY: number?)
	local s = size or 4
	local c = color or Color3.fromRGB(150, 110, 62)
	local cf = CFrame.new(pos + Vector3.new(0, s / 2, 0)) * CFrame.Angles(0, math.rad(rotY or 0), 0)
	b:Part(Vector3.new(s, s, s), cf, c, Enum.Material.WoodPlanks)
	-- frame edges
	local e = 0.25
	local dark = c:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			b:Part(Vector3.new(e * 2, s + 0.05, e * 2), cf * CFrame.new(sx * (s / 2 - e + 0.02), 0, sz * (s / 2 - e + 0.02)), dark, Enum.Material.Wood, { CastShadow = false })
		end
	end
end

function MapKit.CrateStack(b, pos: Vector3, color: Color3?)
	MapKit.Crate(b, pos, 4, color, 0)
	MapKit.Crate(b, pos + Vector3.new(4.2, 0, 0.5), 4, color, 8)
	MapKit.Crate(b, pos + Vector3.new(2, 4, 0.2), 4, color, -6)
end

function MapKit.Barrel(b, pos: Vector3, color: Color3?)
	b:Column(pos, 3.6, 2.6, color or Color3.fromRGB(60, 90, 140), Enum.Material.Metal)
	b:Column(pos + Vector3.new(0, 3.55, 0), 0.1, 2.7, Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
end

function MapKit.Sandbags(b, a: Vector3, bLen: number, rotY: number, color: Color3?)
	local c = color or Color3.fromRGB(170, 150, 110)
	local cf = CFrame.new(a) * CFrame.Angles(0, math.rad(rotY), 0)
	local n = math.floor(bLen / 2.2)
	for row = 0, 2 do
		for i = 0, n - 1 - (row % 2) do
			local x = -bLen / 2 + 1.1 + i * 2.2 + (row % 2) * 1.1
			b:Part(Vector3.new(2.2, 1.1, 1.6), cf * CFrame.new(x, 0.55 + row * 1.05, 0), c, Enum.Material.Fabric)
		end
	end
end

return MapKit
