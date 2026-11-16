--[[
	MapLoader
	Builds a map at a world origin, converts its local spawn data to world space and attaches
	a results podium. Map modules return local-space info:
	  { Spawns = {Red={CFrame}, Blue={CFrame}}, SpawnZones = {Red={CFrame,Size}, Blue=...},
	    Podium = CFrame, KillY = number, Bounds = {x0,y0,z0,x1,y1,z1} }
]]

local Builder = require(script.Parent.Builder)
local PodiumBuilder = require(script.Parent.PodiumBuilder)

local MapLoader = {}

local MODULES = {
	Forest = script.Parent.Maps.Forest,
	ModernCity = script.Parent.Maps.ModernCity,
	BrickCity = script.Parent.Maps.BrickCity,
	Egypt = script.Parent.Maps.Egypt,
	Maya = script.Parent.Maps.Maya,
}

local function mapsFolder()
	local f = workspace:FindFirstChild("Maps")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Maps"
		f.Parent = workspace
	end
	return f
end

function MapLoader.GetModule(mapId: string)
	local m = MODULES[mapId]
	return m and require(m)
end

function MapLoader.Load(mapId: string, origin: CFrame)
	local module = MapLoader.GetModule(mapId)
	assert(module, "Unknown map " .. tostring(mapId))
	local model = Instance.new("Model")
	model.Name = mapId
	model:SetAttribute("MapId", mapId)
	model.Parent = mapsFolder()
	local b = Builder.new(model, origin)
	local t0 = os.clock()
	local info = module.Build(b)
	print(string.format("[MapLoader] built %s with %d parts in %.2fs", mapId, b.Count, os.clock() - t0))

	local world = { Spawns = { Red = {}, Blue = {} }, SpawnZones = {}, Model = model, MapId = mapId, Origin = origin }
	for team, list in pairs(info.Spawns) do
		for _, cf in ipairs(list) do
			table.insert(world.Spawns[team], origin * cf)
		end
	end
	for team, zone in pairs(info.SpawnZones) do
		world.SpawnZones[team] = { CFrame = origin * zone.CFrame, Size = zone.Size }
	end
	world.KillY = origin.Position.Y + (info.KillY or -60)
	world.Podium = PodiumBuilder.new(model, origin * info.Podium)
	world.PodiumCFrame = origin * info.Podium

	function world.Destroy()
		world.Podium:Destroy()
		model:Destroy()
		local bd = info.Bounds
		if bd then
			b:ClearTerrain(bd[1], bd[2], bd[3], bd[4], bd[5], bd[6])
		end
	end
	return world
end

function MapLoader.BuildPreview(mapId: string, parent: Instance, cf: CFrame)
	local module = MapLoader.GetModule(mapId)
	if module and module.BuildPreview then
		local model = Instance.new("Model")
		model.Name = mapId .. "Preview"
		model.Parent = parent
		module.BuildPreview(Builder.new(model, cf))
		return model
	end
	return nil
end

return MapLoader
