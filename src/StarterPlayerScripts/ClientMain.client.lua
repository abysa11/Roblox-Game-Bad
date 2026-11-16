--[[
	ClientMain (client bootstrap)
	Initialises every client controller in dependency order and feeds server state into
	ClientState (profile, match state).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local Controllers = script.Parent:WaitForChild("Controllers")
local ClientState = require(Controllers.ClientState)

local order = {
	"SettingsController",
	"LightingController",
	"CameraController",
	"InputController",
	"Toast",
	"EffectsController",
	"WeaponController",
	"WeaponShopUI",
	"HUDController",
	"MobileControls",
	"SkinShopUI",
	"LobbyUI",
	"ResultsUI",
}

-- server state -> ClientState
Net.Event("ProfileUpdate").OnClientEvent:Connect(function(profile)
	if type(profile) == "table" then
		ClientState.SetProfile(profile)
	end
end)
Net.Event("MatchState").OnClientEvent:Connect(function(payload)
	if type(payload) == "table" then
		ClientState.SetMatch(payload)
	end
end)

for _, name in ipairs(order) do
	local module = Controllers:FindFirstChild(name)
	if module then
		local ok, err = pcall(function()
			local controller = require(module)
			if controller.Init then
				controller.Init()
			end
		end)
		if not ok then
			warn("[ClientMain] " .. name .. " failed to start: " .. tostring(err))
		end
	end
end

task.spawn(function()
	local ok, profile = pcall(function()
		return Net.Function("GetProfile"):InvokeServer()
	end)
	if ok and type(profile) == "table" then
		ClientState.SetProfile(profile)
	end
end)

-- route every character sound (footsteps, jumps...) through the SFX volume group
local function hookCharacter(character: Model)
	local group = Sounds.GetGroup("SFX")
	local function apply(d)
		if d:IsA("Sound") then
			d.SoundGroup = group
		end
	end
	for _, d in ipairs(character:GetDescendants()) do
		apply(d)
	end
	character.DescendantAdded:Connect(apply)
end
local function hookPlayer(p: Player)
	if p.Character then
		hookCharacter(p.Character)
	end
	p.CharacterAdded:Connect(hookCharacter)
end
for _, p in ipairs(Players:GetPlayers()) do
	hookPlayer(p)
end
Players.PlayerAdded:Connect(hookPlayer)

-- teammates get name tags, enemies don't (enemy names would make hiding pointless)
local function updateNameTags()
	local myTeam = Players.LocalPlayer:GetAttribute("Team")
	for _, p in ipairs(Players:GetPlayers()) do
		local hum = p ~= Players.LocalPlayer and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			local team = p:GetAttribute("Team")
			if myTeam == nil then
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			elseif team == myTeam then
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
				hum.NameDisplayDistance = 120
			else
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
	end
end
task.spawn(function()
	while true do
		task.wait(1)
		updateNameTags()
	end
end)
