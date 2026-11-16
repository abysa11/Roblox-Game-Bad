--[[
	Test harness: mounts the bundled sources into the mock DataModel and provides checks.
	(BUNDLE and M are defined by run_tests.py before this chunk.)
]]

local task = M.task
local H = {}
H.passed, H.failed = 0, 0

function H.check(name, cond, detail)
	if cond then
		H.passed += 1
		print("  ok   " .. name)
	else
		H.failed += 1
		print("  FAILED " .. name .. (detail and ("  -> " .. tostring(detail)) or ""))
	end
end

function H.section(name)
	print("\n-- " .. name)
end

function H.finish()
	print(string.format("\n%d passed, %d failed, %d runtime errors", H.passed, H.failed, #M.Errors))
	if #M.Errors > 0 then
		print("FAILED: runtime errors were raised")
	end
end

local game = M.game
local StarterPlayer = game:GetService("StarterPlayer")
local sps = M.Instance.new("StarterPlayerScripts")
sps.Name = "StarterPlayerScripts"
sps.Parent = StarterPlayer
H.StarterPlayerScripts = sps

local roots = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayerScripts = sps,
}

H.Scripts = {}
for path in pairs(BUNDLE) do
	local parts = string.split(path, "/")
	local node = roots[parts[1]]
	for i = 2, #parts - 1 do
		local child = node:FindFirstChild(parts[i])
		if not child then
			child = M.Instance.new("Folder")
			child.Name = parts[i]
			child.Parent = node
		end
		node = child
	end
	local file = parts[#parts]
	local cls, name
	if file:sub(-11) == ".server.lua" then
		cls, name = "Script", file:sub(1, -12)
	elseif file:sub(-11) == ".client.lua" then
		cls, name = "LocalScript", file:sub(1, -12)
	else
		cls, name = "ModuleScript", file:sub(1, -5)
	end
	local inst = M.Instance.new(cls)
	inst.Name = name
	inst.Parent = node
	M.mapSource(inst, path)
	H.Scripts[path] = inst
end

function H.module(path)
	return M.require(H.Scripts[path])
end

-- Runs fn inside a coroutine so it may call task.wait; advances virtual time until done.
function H.async(fn)
	local done = false
	task.spawn(function()
		fn()
		done = true
	end)
	local guard = 0
	while not done and guard < 200000 do
		M.run(0.05)
		guard += 1
	end
	if not done then
		H.check("async block completed", false, "timed out")
	end
end

return H
