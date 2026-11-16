-- Guards against dead audio links and missing sound names.
local task = M.task
M.IsServer = false
local Sounds = H.module("ReplicatedStorage/Shared/Sounds.lua")
local WeaponData = H.module("ReplicatedStorage/WeaponModules/WeaponData.lua")
local Config = H.module("ReplicatedStorage/Shared/Config.lua")

-- files listed under content/sounds in the Roblox client manifest
local VERIFIED = {}
for _, f in ipairs({ "action_falling.ogg", "action_footsteps_plastic.mp3", "action_get_up.mp3", "action_jump.mp3",
	"action_jump_land.mp3", "action_swim.mp3", "impact_explosion_03.mp3", "impact_water.mp3", "oof.ogg",
	"ouch.ogg", "volume_slider.ogg" }) do
	VERIFIED["rbxasset://sounds/" .. f] = true
end

H.section("Every sound layer uses a bundled client file")
for _, id in pairs(Sounds.BuiltIn) do
	H.check("built-in " .. id, VERIFIED[id] == true)
end
local bad = {}
for name, layers in pairs(Sounds.Defs) do
	for _, layer in ipairs(layers) do
		if not VERIFIED[layer.Id] then
			table.insert(bad, name .. ": " .. tostring(layer.Id))
		end
		if layer.Speed <= 0 or layer.Speed > 20 then
			table.insert(bad, name .. ": speed " .. layer.Speed)
		end
	end
end
H.check("no unverified sound ids in definitions", #bad == 0, table.concat(bad, ", "))

H.section("No hard-coded sound paths elsewhere")
local stray = {}
for path, src in pairs(BUNDLE) do
	if path ~= "ReplicatedStorage/Shared/Sounds.lua" and src:find("rbxasset://sounds/", 1, true) then
		table.insert(stray, path)
	end
	local noBlocks = src:gsub("%-%-%[(=*)%[.-%]%1%]", "")
	for line in noBlocks:gmatch("[^\n]+") do
		local code = line:gsub("%-%-.*$", "") -- ignore comments (examples in docs)
		for id in code:gmatch("rbxassetid://(%d+)") do
			if not path:find("PodiumBuilder") then
				table.insert(stray, path .. " uses rbxassetid://" .. id)
			end
		end
	end
end
H.check("only Sounds.lua references audio files", #stray == 0, table.concat(stray, ", "))

H.section("Every sound the game plays exists")
local missing = {}
for path, src in pairs(BUNDLE) do
	for expr in src:gmatch("Sounds%.Play%(([^,%)]+)") do
		-- sound names are the leading literal or the results of `and "X"` / `or "X"`
		local names = {}
		local lead = expr:match('^%s*"([%w_]+)"')
		if lead then
			table.insert(names, lead)
		end
		for name in expr:gmatch('and%s+"([%w_]+)"') do
			table.insert(names, name)
		end
		for name in expr:gmatch('or%s+"([%w_]+)"') do
			table.insert(names, name)
		end
		for _, name in ipairs(names) do
			if not Sounds.Defs[name] then
				table.insert(missing, path .. ": " .. name)
			end
		end
	end
end
for id, w in pairs(WeaponData.Weapons) do
	if w.Sound and not Sounds.Defs[w.Sound] then
		table.insert(missing, id .. " weapon sound " .. w.Sound)
	end
end
H.check("all referenced sound names are defined", #missing == 0, table.concat(missing, ", "))
H.check("every gun has its own shot sound", (function()
	local seen = {}
	for _, w in pairs(WeaponData.Weapons) do
		if w.Sound then
			if seen[w.Sound] then
				return false
			end
			seen[w.Sound] = true
		end
	end
	return true
end)())

H.section("Playback")
local SoundService = M.game:GetService("SoundService")
local function countSounds()
	local n = 0
	for _, d in ipairs(SoundService:GetDescendants()) do
		if d.ClassName == "Sound" then
			n += 1
		end
	end
	return n
end
Sounds.Play("AK_Shot")
H.check("gunshot creates its layers", countSounds() == #Sounds.Defs.AK_Shot)
M.run(0.5)
H.check("short slices are cut (no lingering sounds)", countSounds() == 0, countSounds())
Sounds.Play("KillConfirm")
M.run(0.05)
H.check("delayed layers wait their turn", countSounds() < #Sounds.Defs.KillConfirm)
M.run(5)
local music = Sounds.PlayMusic("Podium")
local created = 0
local conn = SoundService.DescendantAdded:Connect(function(d)
	if d.ClassName == "Sound" then
		created += 1
	end
end)
M.run(8)
H.check("podium music plays notes, bass and drums", created > 40, created)
music:Destroy()
M.run(1)
local after = created
M.run(4)
H.check("music stops when destroyed", created == after)
conn.Disconnect()
Config.Sounds.Overrides.AK_Shot = "rbxassetid://1"
Sounds.Play("AK_Shot")
H.check("overrides replace a definition", countSounds() == 1)
Config.Sounds.Overrides.AK_Shot = nil
H.finish()
