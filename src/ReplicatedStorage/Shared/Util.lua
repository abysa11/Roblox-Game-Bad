--[[
	Util
	Small helpers shared by client and server.
]]

local Util = {}

function Util.FormatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Util.DeepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = Util.DeepCopy(v)
	end
	return out
end

-- Fills in any keys of `template` missing from `data` (recursively). Never removes keys.
function Util.Reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = Util.DeepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			Util.Reconcile(data[k], v)
		end
	end
	return data
end

function Util.IsFiniteNumber(n): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Util.IsValidVector3(v): boolean
	return typeof(v) == "Vector3"
		and Util.IsFiniteNumber(v.X)
		and Util.IsFiniteNumber(v.Y)
		and Util.IsFiniteNumber(v.Z)
end

-- Position inside an oriented box?
function Util.InBox(pos: Vector3, cf: CFrame, size: Vector3): boolean
	local p = cf:PointToObjectSpace(pos)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

function Util.GetCharacterFromPart(part: Instance?)
	if not part then
		return nil
	end
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function Util.Shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Random direction inside a cone of `angleDeg` around `dir`.
function Util.SpreadDirection(dir: Vector3, angleDeg: number, rng: Random?): Vector3
	if angleDeg <= 0 then
		return dir.Unit
	end
	local r = rng or Random.new()
	local cf = CFrame.lookAt(Vector3.zero, dir)
	-- uniform within the cone disk (sqrt for even distribution)
	local radius = math.tan(math.rad(angleDeg)) * math.sqrt(r:NextNumber())
	local theta = r:NextNumber() * math.pi * 2
	local offset = cf.RightVector * math.cos(theta) * radius + cf.UpVector * math.sin(theta) * radius
	return (dir.Unit + offset).Unit
end

function Util.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

return Util
