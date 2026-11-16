--[[
	Minimal Roblox engine mock for headless tests with the `luau` CLI.
	Implements a virtual-time task scheduler, datatypes (Vector3/CFrame/Color3/UDim2...),
	an Instance tree with property checks on BaseParts, signals, services, DataStore and
	remotes. Good enough to execute map builders and simulate whole matches on the server.
]]

local M = {}

---------------------------------------------------------------------------------------
-- scheduler (virtual time)
---------------------------------------------------------------------------------------
local now = 0
local queue = {}
M.Errors = {}

local function push(t, co, args)
	local item = { t = t, co = co, args = args, seq = #queue + math.random() }
	local i = #queue + 1
	while i > 1 and (queue[i - 1].t > t) do
		i -= 1
	end
	table.insert(queue, i, item)
end

local function resume(co, ...)
	if coroutine.status(co) == "dead" then
		return
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		local tb = debug.traceback(co, tostring(err))
		table.insert(M.Errors, tb)
		print("[MOCK ERROR] " .. tb)
	end
end
M.resume = resume

local task = {}
function task.spawn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	push(now, co, table.pack(...))
	return co
end
function task.delay(t, f, ...)
	local co = coroutine.create(f)
	push(now + (t or 0), co, table.pack(...))
	return co
end
function task.wait(t)
	local co = coroutine.running()
	local start = now
	push(now + math.max(t or 0.03, 0.001), co, nil)
	coroutine.yield()
	return now - start
end
function task.cancel() end
M.task = task

function M.run(duration)
	local target = now + duration
	while #queue > 0 and queue[1].t <= target do
		local item = table.remove(queue, 1)
		now = item.t
		if item.args then
			resume(item.co, table.unpack(item.args, 1, item.args.n))
		else
			resume(item.co, now)
		end
	end
	now = target
end
function M.now()
	return now
end

---------------------------------------------------------------------------------------
-- typeof / helpers
---------------------------------------------------------------------------------------
local function typeof(v)
	local mt = getmetatable(v)
	if type(mt) == "table" and mt.__type then
		return mt.__type
	end
	return type(v)
end
M.typeof = typeof

---------------------------------------------------------------------------------------
-- Vector3 / Vector2
---------------------------------------------------------------------------------------
local V3 = {}
V3.__type = "Vector3"
V3.__index = function(v, k)
	if k == "X" then
		return rawget(v, 1)
	elseif k == "Y" then
		return rawget(v, 2)
	elseif k == "Z" then
		return rawget(v, 3)
	elseif k == "Magnitude" then
		return math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	elseif k == "Unit" then
		local m = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
		if m == 0 then
			return setmetatable({ 0 / 0, 0 / 0, 0 / 0 }, V3)
		end
		return setmetatable({ v[1] / m, v[2] / m, v[3] / m }, V3)
	end
	return V3[k]
end
local function v3(x, y, z)
	return setmetatable({ x or 0, y or 0, z or 0 }, V3)
end
V3.__add = function(a, b)
	return v3(a[1] + b[1], a[2] + b[2], a[3] + b[3])
end
V3.__sub = function(a, b)
	return v3(a[1] - b[1], a[2] - b[2], a[3] - b[3])
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b[1], a * b[2], a * b[3])
	elseif type(b) == "number" then
		return v3(a[1] * b, a[2] * b, a[3] * b)
	end
	return v3(a[1] * b[1], a[2] * b[2], a[3] * b[3])
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a[1] / b, a[2] / b, a[3] / b)
	end
	return v3(a[1] / b[1], a[2] / b[2], a[3] / b[3])
end
V3.__unm = function(a)
	return v3(-a[1], -a[2], -a[3])
end
V3.__eq = function(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end
V3.__tostring = function(a)
	return string.format("%.3f, %.3f, %.3f", a[1], a[2], a[3])
end
function V3.Dot(a, b)
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
function V3.Cross(a, b)
	return v3(a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1])
end
function V3.Lerp(a, b, t)
	return a + (b - a) * t
end
function V3.Angle(a, b)
	local d = a:Dot(b) / (a.Magnitude * b.Magnitude)
	return math.acos(math.clamp(d, -1, 1))
end
function V3.FuzzyEq(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-5)
end
local Vector3 = {
	new = v3,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
}
M.Vector3 = Vector3

local V2 = { __type = "Vector2" }
V2.__index = function(v, k)
	if k == "X" then
		return v[1]
	elseif k == "Y" then
		return v[2]
	elseif k == "Magnitude" then
		return math.sqrt(v[1] ^ 2 + v[2] ^ 2)
	end
	return nil
end
V2.__add = function(a, b)
	return setmetatable({ a[1] + b[1], a[2] + b[2] }, V2)
end
V2.__sub = function(a, b)
	return setmetatable({ a[1] - b[1], a[2] - b[2] }, V2)
end
local Vector2 = {
	new = function(x, y)
		return setmetatable({ x or 0, y or 0 }, V2)
	end,
}
Vector2.zero = Vector2.new(0, 0)
M.Vector2 = Vector2

---------------------------------------------------------------------------------------
-- CFrame (row-major 3x3 rotation + position)
---------------------------------------------------------------------------------------
local CF = { __type = "CFrame" }
local function cfraw(p, r)
	return setmetatable({ p = p, r = r }, CF)
end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function matmul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end
local function matvec(m, v)
	return v3(m[1] * v[1] + m[2] * v[2] + m[3] * v[3], m[4] * v[1] + m[5] * v[2] + m[6] * v[3], m[7] * v[1] + m[8] * v[2] + m[9] * v[3])
end
local function transpose(m)
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end
CF.__index = function(c, k)
	local r = rawget(c, "r")
	local p = rawget(c, "p")
	if k == "Position" or k == "p" then
		return p
	elseif k == "X" then
		return p[1]
	elseif k == "Y" then
		return p[2]
	elseif k == "Z" then
		return p[3]
	elseif k == "LookVector" then
		return v3(-r[3], -r[6], -r[9])
	elseif k == "RightVector" then
		return v3(r[1], r[4], r[7])
	elseif k == "UpVector" then
		return v3(r[2], r[5], r[8])
	elseif k == "Rotation" then
		return cfraw(v3(), r)
	end
	return CF[k]
end
CF.__mul = function(a, b)
	if typeof(b) == "Vector3" then
		return matvec(a.r, b) + a.p
	end
	return cfraw(matvec(a.r, b.p) + a.p, matmul(a.r, b.r))
end
CF.__add = function(a, b)
	return cfraw(a.p + b, a.r)
end
CF.__sub = function(a, b)
	return cfraw(a.p - b, a.r)
end
CF.__eq = function(a, b)
	if a.p ~= b.p then
		return false
	end
	for i = 1, 9 do
		if a.r[i] ~= b.r[i] then
			return false
		end
	end
	return true
end
CF.__tostring = function(c)
	return "CFrame(" .. tostring(c.p) .. ")"
end
function CF.Inverse(c)
	local rt = transpose(c.r)
	return cfraw(-matvec(rt, c.p), rt)
end
function CF.PointToWorldSpace(c, v)
	return c * v
end
function CF.PointToObjectSpace(c, v)
	return c:Inverse() * v
end
function CF.VectorToWorldSpace(c, v)
	return matvec(c.r, v)
end
function CF.VectorToObjectSpace(c, v)
	return matvec(transpose(c.r), v)
end
function CF.ToObjectSpace(a, b)
	return a:Inverse() * b
end
function CF.Lerp(a, b, t)
	return cfraw(a.p:Lerp(b.p, t), t < 0.5 and a.r or b.r)
end
function CF.ToEulerAnglesYXZ(c)
	local m = c.r
	local x = math.asin(math.clamp(-m[6], -1, 1))
	local y = math.atan2(m[3], m[9])
	local z = math.atan2(m[4], m[5])
	return x, y, z
end
function CF.GetComponents(c)
	local r = c.r
	return c.p[1], c.p[2], c.p[3], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
end
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
local CFrame = {}
function CFrame.new(a, b, c, ...)
	if a == nil then
		return cfraw(v3(), IDENT)
	end
	if typeof(a) == "Vector3" then
		if b and typeof(b) == "Vector3" then
			return CFrame.lookAt(a, b)
		end
		return cfraw(a, IDENT)
	end
	local rest = { ... }
	if #rest == 9 then
		return cfraw(v3(a, b, c), rest)
	end
	return cfraw(v3(a, b, c), IDENT)
end
function CFrame.Angles(x, y, z)
	return cfraw(v3(), matmul(matmul(rx(x or 0), ry(y or 0)), rz(z or 0)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(x, y, z)
	return cfraw(v3(), matmul(matmul(ry(y or 0), rx(x or 0)), rz(z or 0)))
end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - at)
	if look.Magnitude < 1e-9 then
		return cfraw(at, IDENT)
	end
	look = look.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(v3(0, 0, 1))
		if right.Magnitude < 1e-6 then
			right = v3(1, 0, 0)
		end
	end
	right = right.Unit
	local u = right:Cross(look)
	return cfraw(at, { right[1], u[1], -look[1], right[2], u[2], -look[2], right[3], u[3], -look[3] })
end
CFrame.identity = CFrame.new()
M.CFrame = CFrame

---------------------------------------------------------------------------------------
-- Color3, UDim, UDim2, misc datatypes
---------------------------------------------------------------------------------------
local C3 = { __type = "Color3" }
C3.__index = function(c, k)
	if k == "R" then
		return c[1]
	elseif k == "G" then
		return c[2]
	elseif k == "B" then
		return c[3]
	end
	return C3[k]
end
C3.__eq = function(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end
local function c3(r, g, b)
	return setmetatable({ r or 0, g or 0, b or 0 }, C3)
end
function C3.Lerp(a, b, t)
	return c3(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t)
end
local Color3 = {
	new = c3,
	fromRGB = function(r, g, b)
		return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	end,
	fromHSV = function()
		return c3(1, 1, 1)
	end,
}
M.Color3 = Color3

local UD = { __type = "UDim" }
UD.__index = function(u, k)
	if k == "Scale" then
		return u[1]
	elseif k == "Offset" then
		return u[2]
	end
end
local UDim = {
	new = function(s, o)
		return setmetatable({ s or 0, o or 0 }, UD)
	end,
}
local UD2 = { __type = "UDim2" }
UD2.__index = function(u, k)
	if k == "X" then
		return u[1]
	elseif k == "Y" then
		return u[2]
	end
end
local function ud2(xs, xo, ys, yo)
	return setmetatable({ UDim.new(xs, xo), UDim.new(ys, yo) }, UD2)
end
UD2.__add = function(a, b)
	return ud2(a[1][1] + b[1][1], a[1][2] + b[1][2], a[2][1] + b[2][1], a[2][2] + b[2][2])
end
UD2.__sub = function(a, b)
	return ud2(a[1][1] - b[1][1], a[1][2] - b[1][2], a[2][1] - b[2][1], a[2][2] - b[2][2])
end
local UDim2 = {
	new = ud2,
	fromScale = function(x, y)
		return ud2(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		return ud2(0, x, 0, y)
	end,
}
M.UDim, M.UDim2 = UDim, UDim2

local function simpleType(name)
	local mt = { __type = name }
	mt.__index = mt
	return {
		new = function(...)
			return setmetatable({ args = { ... } }, mt)
		end,
	}
end
M.NumberRange = simpleType("NumberRange")
M.NumberSequence = simpleType("NumberSequence")
M.NumberSequenceKeypoint = simpleType("NumberSequenceKeypoint")
M.ColorSequence = simpleType("ColorSequence")
M.ColorSequenceKeypoint = simpleType("ColorSequenceKeypoint")
M.TweenInfo = simpleType("TweenInfo")
M.Rect = simpleType("Rect")
M.Font = simpleType("Font")

local R3 = { __type = "Region3" }
R3.__index = R3
function R3.ExpandToGrid(r)
	return r
end
M.Region3 = {
	new = function(a, b)
		return setmetatable({ Min = a, Max = b }, R3)
	end,
}

local RP = { __type = "RaycastParams" }
RP.__index = RP
M.RaycastParams = {
	new = function()
		return setmetatable({ FilterDescendantsInstances = {}, FilterType = nil, IgnoreWater = false }, RP)
	end,
}

local RandomMT = { __type = "Random" }
RandomMT.__index = RandomMT
function RandomMT.NextNumber(r, a, b)
	r.s = (r.s * 1103515245 + 12345) % 2147483648
	local f = r.s / 2147483648
	if a then
		return a + (b - a) * f
	end
	return f
end
function RandomMT.NextInteger(r, a, b)
	return math.floor(r:NextNumber(a, b + 1 - 1e-9))
end
M.Random = {
	new = function(seed)
		return setmetatable({ s = seed or 1234 }, RandomMT)
	end,
}

---------------------------------------------------------------------------------------
-- Enum
---------------------------------------------------------------------------------------
local enumCache = {}
local EnumItemMT = { __type = "EnumItem" }
EnumItemMT.__index = EnumItemMT
EnumItemMT.__tostring = function(e)
	return "Enum." .. e.EnumType .. "." .. e.Name
end
local Enum = setmetatable({}, {
	__index = function(_, typeName)
		enumCache[typeName] = enumCache[typeName] or setmetatable({}, {
			__index = function(t, itemName)
				local item = setmetatable({ Name = itemName, EnumType = typeName, Value = 0 }, EnumItemMT)
				rawset(t, itemName, item)
				return item
			end,
		})
		return enumCache[typeName]
	end,
})
M.Enum = Enum

---------------------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------------------
local SignalMT = { __type = "RBXScriptSignal" }
SignalMT.__index = SignalMT
local function newSignal()
	return setmetatable({ handlers = {}, waiting = {} }, SignalMT)
end
function SignalMT.Connect(s, fn)
	local h = { fn = fn, connected = true }
	table.insert(s.handlers, h)
	return {
		Connected = true,
		Disconnect = function()
			h.connected = false
		end,
	}
end
SignalMT.Once = SignalMT.Connect
function SignalMT.Fire(s, ...)
	for _, h in ipairs(table.clone(s.handlers)) do
		if h.connected then
			task.spawn(h.fn, ...)
		end
	end
	local w = s.waiting
	s.waiting = {}
	for _, co in ipairs(w) do
		task.spawn(co, ...)
	end
end
function SignalMT.Wait(s)
	table.insert(s.waiting, coroutine.running())
	return coroutine.yield()
end
M.newSignal = newSignal

---------------------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------------------
local PARENT = {
	Part = "FormFactorPart", SpawnLocation = "Part", WedgePart = "FormFactorPart", CornerWedgePart = "BasePart", TrussPart = "BasePart",
	FormFactorPart = "BasePart", MeshPart = "BasePart", BasePart = "PVInstance", Model = "PVInstance",
	WorldModel = "Model", Workspace = "WorldModel", PVInstance = "Instance", Terrain = "BasePart",
	Script = "BaseScript", LocalScript = "Script", BaseScript = "LuaSourceContainer", ModuleScript = "LuaSourceContainer",
	LuaSourceContainer = "Instance",
	Frame = "GuiObject", TextLabel = "GuiObject", ImageLabel = "GuiObject", ScrollingFrame = "GuiObject",
	ViewportFrame = "GuiObject", TextButton = "GuiButton", ImageButton = "GuiButton", GuiButton = "GuiObject",
	GuiObject = "GuiBase2d", ScreenGui = "LayerCollector", SurfaceGui = "LayerCollector", BillboardGui = "LayerCollector",
	LayerCollector = "GuiBase2d", GuiBase2d = "Instance",
	Weld = "JointInstance", Motor6D = "JointInstance", JointInstance = "Instance",
	PointLight = "Light", SpotLight = "Light", Light = "Instance",
	Humanoid = "Instance", Player = "Instance",
}
local function isA(className, target)
	local c = className
	while c do
		if c == target then
			return true
		end
		c = PARENT[c]
	end
	return target == "Instance"
end

local PART_PROPS = {
	Name = true, Parent = true, Size = true, CFrame = true, Position = true, Anchored = true, CanCollide = true,
	CanQuery = true, CanTouch = true, CastShadow = true, Massless = true, Color = true, Material = true,
	Transparency = true, Reflectance = true, TopSurface = true, BottomSurface = true, Shape = true, Locked = true,
	AssemblyLinearVelocity = true, AssemblyMass = true, LocalTransparencyModifier = true, Archivable = true,
	BrickColor = true, Orientation = true, CollisionGroup = true,
	Neutral = true, Duration = true, AllowTeamChangeOnTouch = true, Enabled = true, TeamColor = true,
}

local InstMT = { __type = "Instance" }
local Instance = {}
local INSTANCE_COUNT = 0
M.InstanceCount = function()
	return INSTANCE_COUNT
end

local methods = {}

local function getProp(inst, k)
	local props = rawget(inst, "_p")
	if k == "Parent" then
		return rawget(inst, "_parent")
	end
	if k == "Position" and props.CFrame then
		return props.CFrame.Position
	end
	if k == "WorldPosition" and inst.ClassName == "Attachment" then
		local parent = rawget(inst, "_parent")
		local pcf = parent and rawget(parent, "_p").CFrame or CFrame.new()
		return pcf * (props.CFrame or CFrame.new()).Position
	end
	if k == "WorldCFrame" and inst.ClassName == "Attachment" then
		local parent = rawget(inst, "_parent")
		local pcf = parent and rawget(parent, "_p").CFrame or CFrame.new()
		return pcf * (props.CFrame or CFrame.new())
	end
	local v = props[k]
	if v ~= nil then
		return v
	end
	if methods[k] then
		return methods[k]
	end
	-- child lookup like Roblox (inst.ChildName)
	for _, c in ipairs(rawget(inst, "_children")) do
		if rawget(c, "_p").Name == k then
			return c
		end
	end
	local ev = rawget(inst, "_events")
	if string.match(k, "^%u") and (k:sub(-5) == "Added" or k:sub(-7) == "Removed" or k:sub(-8) == "Removing" or k:sub(-7) == "Changed"
		or k == "Died" or k == "Triggered" or k == "Activated" or k:sub(1, 5) == "Mouse" or k:sub(1, 5) == "Input"
		or k == "Event" or k == "OnServerEvent" or k == "OnClientEvent" or k == "Heartbeat" or k == "RenderStepped" or k == "Stepped"
		or k == "TeleportInitFailed" or k == "CharacterAppearanceLoaded" or k == "Destroying") then
		ev[k] = ev[k] or newSignal()
		return ev[k]
	end
	return nil
end

InstMT.__index = getProp
InstMT.__newindex = function(inst, k, v)
	local props = rawget(inst, "_p")
	local cls = props.ClassName
	if isA(cls, "BasePart") and cls ~= "Terrain" and not PART_PROPS[k] then
		error("Unknown BasePart property '" .. tostring(k) .. "' on " .. cls, 2)
	end
	if k == "Parent" then
		local old = rawget(inst, "_parent")
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, inst)
			if i then
				table.remove(list, i)
			end
		end
		rawset(inst, "_parent", v)
		local myEv = rawget(inst, "_events")
		if myEv.AncestryChanged then
			myEv.AncestryChanged:Fire(inst, v)
		end
		if v then
			table.insert(rawget(v, "_children"), inst)
			local ev = rawget(v, "_events")
			if ev.ChildAdded then
				ev.ChildAdded:Fire(inst)
			end
			local a = v
			while a do
				local e = rawget(a, "_events")
				if e.DescendantAdded then
					e.DescendantAdded:Fire(inst)
				end
				a = rawget(a, "_parent")
			end
		end
		return
	end
	if k == "Position" and isA(cls, "BasePart") then
		local cf = props.CFrame or CFrame.new()
		props.CFrame = cfraw(v, cf.r)
		return
	end
	if k == "WorldPosition" and cls == "Attachment" then
		local parent = rawget(inst, "_parent")
		local pcf = parent and rawget(parent, "_p").CFrame or CFrame.new()
		props.CFrame = CFrame.new(pcf:PointToObjectSpace(v))
		return
	end
	if k == "WorldCFrame" and cls == "Attachment" then
		local parent = rawget(inst, "_parent")
		local pcf = parent and rawget(parent, "_p").CFrame or CFrame.new()
		props.CFrame = pcf:Inverse() * v
		return
	end
	if k == "Position" and cls == "Attachment" then
		props.CFrame = CFrame.new(v)
		return
	end
	props[k] = v
	local sigs = rawget(inst, "_propSignals")
	if sigs[k] then
		sigs[k]:Fire()
	end
end
InstMT.__tostring = function(inst)
	return rawget(inst, "_p").Name
end

local DEFAULTS = {
	BasePart = function(p)
		p.Size = v3(4, 1.2, 2)
		p.CFrame = CFrame.new()
		p.Anchored = false
		p.CanCollide = true
		p.CanQuery = true
		p.Transparency = 0
		p.AssemblyLinearVelocity = v3()
		p.AssemblyMass = 1
		p.Color = c3(0.6, 0.6, 0.6)
	end,
	Attachment = function(p)
		p.CFrame = CFrame.new()
	end,
	Humanoid = function(p)
		p.Health = 100
		p.MaxHealth = 100
		p.WalkSpeed = 16
		p.JumpPower = 50
		p.HipHeight = 2
		p.RigType = Enum.HumanoidRigType.R15
		p.FloorMaterial = Enum.Material.Plastic
	end,
	Motor6D = function(p)
		p.C0 = CFrame.new()
		p.C1 = CFrame.new()
		p.Enabled = true
	end,
	Weld = function(p)
		p.C0 = CFrame.new()
		p.C1 = CFrame.new()
	end,
	GuiObject = function(p)
		p.Visible = true
		p.AbsolutePosition = Vector2.new(0, 0)
		p.AbsoluteSize = Vector2.new(100, 100)
		p.Active = true
	end,
	LayerCollector = function(p)
		p.Enabled = true
	end,
	Model = function(p) end,
}

function Instance.new(className, parent)
	INSTANCE_COUNT += 1
	local inst = setmetatable({ _p = { ClassName = className, Name = className }, _children = {}, _events = {}, _propSignals = {}, _attrs = {} }, InstMT)
	for base, fn in pairs(DEFAULTS) do
		if isA(className, base) then
			fn(rawget(inst, "_p"))
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
M.Instance = Instance

function methods.IsA(inst, name)
	return isA(inst.ClassName, name)
end
function methods.GetChildren(inst)
	return table.clone(rawget(inst, "_children"))
end
function methods.GetDescendants(inst)
	local out = {}
	local function walk(i)
		for _, c in ipairs(rawget(i, "_children")) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(inst)
	return out
end
function methods.FindFirstChild(inst, name, recursive)
	for _, c in ipairs(rawget(inst, "_children")) do
		if rawget(c, "_p").Name == name then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(rawget(inst, "_children")) do
			local f = methods.FindFirstChild(c, name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function methods.WaitForChild(inst, name)
	return methods.FindFirstChild(inst, name)
end
function methods.FindFirstChildOfClass(inst, cls)
	for _, c in ipairs(rawget(inst, "_children")) do
		if c.ClassName == cls then
			return c
		end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(inst, cls)
	for _, c in ipairs(rawget(inst, "_children")) do
		if isA(c.ClassName, cls) then
			return c
		end
	end
	return nil
end
function methods.FindFirstAncestor(inst, name)
	local a = rawget(inst, "_parent")
	while a do
		if a.Name == name then
			return a
		end
		a = rawget(a, "_parent")
	end
	return nil
end
function methods.FindFirstAncestorOfClass(inst, cls)
	local a = rawget(inst, "_parent")
	while a do
		if a.ClassName == cls then
			return a
		end
		a = rawget(a, "_parent")
	end
	return nil
end
function methods.FindFirstAncestorWhichIsA(inst, cls)
	local a = rawget(inst, "_parent")
	while a do
		if isA(a.ClassName, cls) then
			return a
		end
		a = rawget(a, "_parent")
	end
	return nil
end
function methods.IsDescendantOf(inst, other)
	local a = rawget(inst, "_parent")
	while a do
		if a == other then
			return true
		end
		a = rawget(a, "_parent")
	end
	return false
end
function methods.Destroy(inst)
	inst.Parent = nil
	local ev = rawget(inst, "_events")
	if ev.Destroying then
		ev.Destroying:Fire()
	end
end
methods.Remove = methods.Destroy
function methods.ClearAllChildren(inst)
	for _, c in ipairs(methods.GetChildren(inst)) do
		c:Destroy()
	end
end
function methods.Clone(inst)
	local copy = Instance.new(inst.ClassName)
	for k, v in pairs(rawget(inst, "_p")) do
		rawget(copy, "_p")[k] = v
	end
	for _, c in ipairs(rawget(inst, "_children")) do
		local cc = methods.Clone(c)
		cc.Parent = copy
	end
	return copy
end
function methods.SetAttribute(inst, k, v)
	rawget(inst, "_attrs")[k] = v
	local ev = rawget(inst, "_events")
	if ev["Attr_" .. k] then
		ev["Attr_" .. k]:Fire()
	end
end
function methods.GetAttribute(inst, k)
	return rawget(inst, "_attrs")[k]
end
function methods.GetAttributes(inst)
	return table.clone(rawget(inst, "_attrs"))
end
function methods.GetAttributeChangedSignal(inst, k)
	local ev = rawget(inst, "_events")
	ev["Attr_" .. k] = ev["Attr_" .. k] or newSignal()
	return ev["Attr_" .. k]
end
function methods.GetPropertyChangedSignal(inst, k)
	local sigs = rawget(inst, "_propSignals")
	sigs[k] = sigs[k] or newSignal()
	return sigs[k]
end
local function pivotOf(model)
	local pp = model.PrimaryPart
	if pp then
		return pp.CFrame
	end
	for _, d in ipairs(methods.GetDescendants(model)) do
		if isA(d.ClassName, "BasePart") then
			return d.CFrame
		end
	end
	return CFrame.new()
end
function methods.GetPivot(inst)
	if isA(inst.ClassName, "BasePart") then
		return inst.CFrame
	end
	return pivotOf(inst)
end
function methods.PivotTo(inst, cf)
	if isA(inst.ClassName, "BasePart") then
		inst.CFrame = cf
		return
	end
	local delta = cf * pivotOf(inst):Inverse()
	for _, d in ipairs(methods.GetDescendants(inst)) do
		if isA(d.ClassName, "BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end
function methods.ApplyImpulse() end
function methods.SetNetworkOwner() end
function methods.TakeDamage(h, amount)
	if h.Health <= 0 then
		return
	end
	if h.Parent and h.Parent:FindFirstChildOfClass("ForceField") then
		return
	end
	h.Health = math.max(0, h.Health - amount)
	if h.Health <= 0 then
		h.Died:Fire()
	end
end
function methods.ChangeState() end
function methods.SetTeleportData(inst, data)
	inst.TeleportData = data
end
function methods.Fire(inst, ...)
	-- BindableEvent:Fire
	getProp(inst, "Event"):Fire(...)
end
function methods.GetAppliedDescription()
	return Instance.new("HumanoidDescription")
end
function methods.LoadAnimation()
	return { Play = function() end, Stop = function() end, Looped = false }
end
function methods.Emit() end
function methods.Play() end
function methods.Stop() end
-- terrain
function methods.FillBlock(t)
	t._fills = (rawget(t, "_fills") or 0) + 1
end
methods.FillBall = methods.FillBlock
methods.FillCylinder = methods.FillBlock
methods.ReplaceMaterial = methods.FillBlock
-- remotes
function methods.FireClient(r, player, ...)
	M.RemoteLog = M.RemoteLog or {}
	table.insert(M.RemoteLog, { remote = r.Name, player = player, args = table.pack(...) })
	if M.OnClientFire then
		M.OnClientFire(r.Name, player, ...)
	end
end
function methods.FireAllClients(r, ...)
	methods.FireClient(r, "ALL", ...)
end
M.methods = methods

---------------------------------------------------------------------------------------
-- game, services
---------------------------------------------------------------------------------------
local game = Instance.new("DataModel")
game.Name = "Game"
game.PlaceId = 0
game.JobId = ""
game.PrivateServerId = ""
game.PrivateServerOwnerId = 0
local services = {}
local function svc(name, setup)
	local s = Instance.new(name)
	s.Name = name
	s.Parent = game
	if setup then
		setup(s)
	end
	services[name] = s
	return s
end
function methods.GetService(_, name)
	if not services[name] then
		svc(name)
	end
	return services[name]
end
function methods.BindToClose(_, fn)
	M.CloseHandlers = M.CloseHandlers or {}
	table.insert(M.CloseHandlers, fn)
end
M.game = game

local workspace = svc("Workspace")
workspace.Name = "Workspace"
local terrain = Instance.new("Terrain")
terrain.Name = "Terrain"
terrain.Parent = workspace
function methods.Raycast(ws, origin, dir, params)
	if M.RaycastHook then
		return M.RaycastHook(origin, dir, params)
	end
	-- flat ground plane at y = 0 (only hit if the ray actually reaches it)
	if dir.Y < 0 and origin.Y + dir.Y <= 0 then
		local t = origin.Y / -dir.Y
		return { Position = origin + dir * t, Instance = terrain, Normal = v3(0, 1, 0), Material = Enum.Material.Grass }
	end
	return nil
end
function methods.GetServerTimeNow()
	return 1700000000 + now
end
function methods.Shoot() end
M.workspace = workspace
workspace.CurrentCamera = Instance.new("Camera")

svc("ReplicatedStorage")
svc("UserInputService", function(s)
	local p = rawget(s, "_p")
	p.TouchEnabled = false
	p.MouseEnabled = true
	p.KeyboardEnabled = true
	p.MouseDeltaSensitivity = 1
	p.MouseIconEnabled = true
	p.GetMouseDelta = function()
		return Vector2.new(0, 0)
	end
	p.GetLastInputType = function()
		return Enum.UserInputType.MouseMovement
	end
end)
svc("ServerScriptService")
svc("Lighting")
svc("SoundService")
svc("StarterGui")
svc("StarterPlayer")
svc("Debris", function(s)
	rawget(s, "_p").AddItem = function(_, item, t)
		task.delay(t or 10, function()
			item:Destroy()
		end)
	end
end)
svc("TweenService", function(s)
	rawget(s, "_p").Create = function(_, obj, _info, props)
		return {
			Play = function()
				for k, v in pairs(props) do
					obj[k] = v
				end
			end,
			Cancel = function() end,
		}
	end
end)
svc("HttpService", function(s)
	local n = 0
	rawget(s, "_p").GenerateGUID = function()
		n += 1
		return string.format("GUID-%06d", n)
	end
end)
svc("RunService", function(s)
	local p = rawget(s, "_p")
	p.IsServer = function()
		return M.IsServer ~= false
	end
	p.IsClient = function()
		return M.IsServer == false
	end
	p.IsStudio = function()
		return M.IsStudio ~= false
	end
	M.RenderSteps = {}
	p.BindToRenderStep = function(_, name, _priority, fn)
		M.RenderSteps[name] = fn
	end
	p.UnbindFromRenderStep = function(_, name)
		M.RenderSteps[name] = nil
	end
end)

-- DataStore (persists across simulated sessions while the process lives)
M.DataStoreData = {}
M.DataStoreFail = false
svc("DataStoreService", function(s)
	rawget(s, "_p").GetDataStore = function(_, name)
		local store = {}
		M.DataStoreData[name] = M.DataStoreData[name] or {}
		local data = M.DataStoreData[name]
		function store.UpdateAsync(_, key, fn)
			task.wait(0.05)
			if M.DataStoreFail then
				error("502: simulated DataStore outage")
			end
			local old = data[key]
			local copy = old and M.deepcopy(old) or nil
			local new = fn(copy)
			if new ~= nil then
				data[key] = M.deepcopy(new)
			end
			return new
		end
		function store.GetAsync(_, key)
			return data[key] and M.deepcopy(data[key])
		end
		function store.SetAsync(_, key, v)
			data[key] = M.deepcopy(v)
		end
		return store
	end
end)
svc("MemoryStoreService", function(s)
	rawget(s, "_p").GetSortedMap = function()
		local items = {}
		return {
			SetAsync = function(_, k, v)
				items[k] = v
			end,
			RemoveAsync = function(_, k)
				items[k] = nil
			end,
			GetRangeAsync = function()
				local out = {}
				for k, v in pairs(items) do
					table.insert(out, { key = k, value = v })
				end
				return out
			end,
		}
	end
end)
svc("TeleportService", function(s)
	local p = rawget(s, "_p")
	p.ReserveServer = function()
		return "ACCESS-CODE"
	end
	p.TeleportAsync = function(_, placeId, players)
		M.Teleports = M.Teleports or {}
		table.insert(M.Teleports, { placeId = placeId, players = players })
	end
end)

function M.deepcopy(t)
	if type(t) ~= "table" then
		return t
	end
	if getmetatable(t) then
		return t
	end
	local o = {}
	for k, v in pairs(t) do
		o[k] = M.deepcopy(v)
	end
	return o
end

---------------------------------------------------------------------------------------
-- Players + characters
---------------------------------------------------------------------------------------
local Players = svc("Players")
local playerList = {}
M.PlayerList = playerList

local function buildRig(name)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = v3(2, 2, 1)
	root.Parent = model
	model.PrimaryPart = root
	local function limb(n, size, offset)
		local p = Instance.new("Part")
		p.Name = n
		p.Size = size
		p.CFrame = CFrame.new(offset)
		p.Parent = model
		return p
	end
	local lower = limb("LowerTorso", v3(2, 0.4, 1), v3(0, -0.2, 0))
	local upper = limb("UpperTorso", v3(2, 1.6, 1), v3(0, 0.8, 0))
	local head = limb("Head", v3(1.2, 1.2, 1.2), v3(0, 2.2, 0))
	local rua = limb("RightUpperArm", v3(1, 1.2, 1), v3(1.5, 0.9, 0))
	limb("RightHand", v3(0.6, 0.4, 0.6), v3(1.5, -0.3, 0))
	local lua = limb("LeftUpperArm", v3(1, 1.2, 1), v3(-1.5, 0.9, 0))
	limb("LeftHand", v3(0.6, 0.4, 0.6), v3(-1.5, -0.3, 0))
	limb("LeftUpperLeg", v3(1, 1.6, 1), v3(-0.5, -1.2, 0))
	limb("RightUpperLeg", v3(1, 1.6, 1), v3(0.5, -1.2, 0))
	local function motor(n, p0, p1, parentPart)
		local m = Instance.new("Motor6D")
		m.Name = n
		m.Part0 = p0
		m.Part1 = p1
		m.Parent = parentPart
	end
	motor("Root", root, lower, lower)
	motor("Waist", lower, upper, upper)
	motor("Neck", upper, head, head)
	motor("RightShoulder", upper, rua, rua)
	motor("LeftShoulder", upper, lua, lua)
	local hum = Instance.new("Humanoid")
	hum.Parent = model
	Instance.new("Animator").Parent = hum
	return model
end
M.buildRig = buildRig

rawget(Players, "_p").GetPlayers = function()
	return table.clone(playerList)
end
rawget(Players, "_p").GetPlayerFromCharacter = function(_, char)
	for _, p in ipairs(playerList) do
		if p.Character == char then
			return p
		end
	end
	return nil
end
rawget(Players, "_p").GetPlayerByUserId = function(_, id)
	for _, p in ipairs(playerList) do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
rawget(Players, "_p").CreateHumanoidModelFromUserId = function()
	error("HTTP 403 (mock)")
end
rawget(Players, "_p").CreateHumanoidModelFromDescription = function()
	return buildRig("Avatar")
end
rawget(Players, "_p").GetUserThumbnailAsync = function()
	return "rbxthumb://mock"
end

function M.AddPlayer(name, userId, joinData)
	local p = Instance.new("Player")
	p.Name = name
	p.DisplayName = name
	p.UserId = userId
	local pp = rawget(p, "_p")
	pp.LoadCharacter = function(self)
		if self.Character then
			self.Character:Destroy()
		end
		local rig = buildRig(name)
		self.Character = rig
		-- Like the real engine: CharacterAdded fires first, THEN Roblox parents the character
		-- and puts it on a SpawnLocation (or high above the origin when there is none),
		-- overriding any position set synchronously inside CharacterAdded.
		self.CharacterAdded:Fire(rig)
		task.defer(function()
			local spawnAt = CFrame.new(0, 100, 0)
			for _, d in ipairs(methods.GetDescendants(workspace)) do
				if d.ClassName == "SpawnLocation" and d.Enabled ~= false then
					spawnAt = CFrame.new(d.Position + v3(0, d.Size.Y / 2 + 3, 0))
					break
				end
			end
			rig.Parent = workspace
			methods.PivotTo(rig, spawnAt)
		end)
	end
	pp.Kick = function(self, msg)
		M.Kicked = M.Kicked or {}
		table.insert(M.Kicked, { player = self, msg = msg })
		M.RemovePlayer(self)
	end
	pp.GetJoinData = function()
		return joinData or {}
	end
	pp.SetAttribute = methods.SetAttribute
	table.insert(playerList, p)
	p.Parent = Players
	Players.PlayerAdded:Fire(p)
	return p
end

function M.RemovePlayer(p)
	local i = table.find(playerList, p)
	if i then
		table.remove(playerList, i)
	end
	Players.PlayerRemoving:Fire(p)
	p.Parent = nil
	if p.Character then
		p.Character:Destroy()
	end
end

---------------------------------------------------------------------------------------
-- module loading
---------------------------------------------------------------------------------------
local cache = {}
local env
function M.mapSource(inst, path)
	rawset(inst, "_path", path)
end
local function mockRequire(inst)
	if cache[inst] ~= nil then
		return cache[inst]
	end
	local path = rawget(inst, "_path")
	assert(path, "require of non-module " .. tostring(inst))
	local src = M.readFile(path)
	local fn, err = loadstring(src, "@" .. path)
	assert(fn, err)
	local e = setmetatable({ script = inst }, { __index = env })
	setfenv(fn, e)
	local result = fn()
	cache[inst] = result
	return result
end
M.require = mockRequire

function M.runScript(inst)
	local path = rawget(inst, "_path")
	local fn, err = loadstring(M.readFile(path), "@" .. path)
	assert(fn, err)
	setfenv(fn, setmetatable({ script = inst }, { __index = env }))
	task.spawn(fn)
end

env = {
	game = game,
	workspace = workspace,
	Instance = Instance,
	Vector3 = Vector3,
	Vector2 = Vector2,
	CFrame = CFrame,
	Color3 = Color3,
	UDim = UDim,
	UDim2 = UDim2,
	Enum = Enum,
	task = task,
	Random = M.Random,
	RaycastParams = M.RaycastParams,
	Region3 = M.Region3,
	TweenInfo = M.TweenInfo,
	NumberRange = M.NumberRange,
	NumberSequence = M.NumberSequence,
	NumberSequenceKeypoint = M.NumberSequenceKeypoint,
	ColorSequence = M.ColorSequence,
	ColorSequenceKeypoint = M.ColorSequenceKeypoint,
	Rect = M.Rect,
	typeof = typeof,
	warn = function(...)
		if M.Verbose then
			print("[warn]", ...)
		end
		M.Warnings = (M.Warnings or 0) + 1
	end,
	print = function(...)
		if M.Verbose then
			print(...)
		end
	end,
	require = mockRequire,
	os = setmetatable({ clock = function()
		return now
	end, time = function()
		return 1700000000 + math.floor(now)
	end }, { __index = os }),
	tick = function()
		return now
	end,
	math = math,
	table = table,
	string = string,
	pairs = pairs,
	ipairs = ipairs,
	next = next,
	type = type,
	tostring = tostring,
	tonumber = tonumber,
	pcall = pcall,
	xpcall = xpcall,
	error = error,
	assert = assert,
	select = select,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	rawget = rawget,
	rawset = rawset,
	rawequal = rawequal,
	unpack = table.unpack,
	coroutine = coroutine,
	debug = debug,
	utf8 = utf8,
}
M.env = env

-- engine frame tick (60 Hz) so Heartbeat:Wait() resolves like in a running game
task.spawn(function()
	local rs = services.RunService
	while true do
		task.wait(1 / 60)
		rs.Heartbeat:Fire(1 / 60)
	end
end)

return M
