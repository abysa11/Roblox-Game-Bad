--[[
	CameraController
	First-person in matches, third person in the lobby, death cam, FOV (sniper zoom),
	mouse sensitivity and cursor visibility. ResultsUI takes the camera over with SetCinematic.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.ClientState)

local CameraController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local BASE_FOV = 78
local targetFov = BASE_FOV
local cinematic = false
local dead = false

CameraController.BaseFov = BASE_FOV

function CameraController.SetFov(fov: number?)
	targetFov = fov or BASE_FOV
end

function CameraController.GetZoomScale(): number
	return camera.FieldOfView / BASE_FOV
end

function CameraController.SetCinematic(on: boolean)
	cinematic = on
	if on then
		camera.CameraType = Enum.CameraType.Scriptable
	else
		camera.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			camera.CameraSubject = hum
		end
	end
	CameraController.Refresh()
end

function CameraController.IsCinematic(): boolean
	return cinematic
end

function CameraController.Refresh()
	if cinematic then
		player.CameraMode = Enum.CameraMode.Classic
		return
	end
	if ClientState.InMatch and not dead then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
	elseif ClientState.InMatch and dead then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = 14
		player.CameraMinZoomDistance = 10
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = 22
		player.CameraMinZoomDistance = 6
	end
end

local function onCharacter(character: Model)
	dead = false
	targetFov = BASE_FOV
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid
	if hum then
		camera.CameraSubject = hum
		hum.Died:Connect(function()
			dead = true
			targetFov = BASE_FOV
			CameraController.Refresh()
		end)
	end
	CameraController.Refresh()
end

-- Put the camera behind the character, looking where it faces (spawns face the map pads in
-- the lobby and the enemy side in matches). Called once the server has placed the character.
function CameraController.FaceForward()
	if cinematic then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	flat = flat.Unit
	local target = root.Position + Vector3.new(0, 2, 0)
	camera.CFrame = CFrame.lookAt(target - flat * 14 + Vector3.new(0, 4, 0), target + flat * 10)
end

function CameraController.Init()
	Net.Event("Spawned").OnClientEvent:Connect(function()
		CameraController.Refresh()
		CameraController.FaceForward()
	end)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	ClientState.MatchChanged:Connect(function()
		CameraController.Refresh()
	end)

	RunService.RenderStepped:Connect(function(dt)
		-- smooth FOV changes (scope in/out)
		if not cinematic then
			camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 18)
		end
		-- mouse sensitivity scaled by zoom so scoped aiming feels consistent
		local sens = ClientState.Settings.MouseSensitivity or 1
		UserInputService.MouseDeltaSensitivity = sens * math.clamp(camera.FieldOfView / BASE_FOV, 0.15, 1)
		-- custom crosshair replaces the cursor in first person
		local hideCursor = ClientState.InMatch and not dead and not cinematic and not ClientState.IsMenuOpen()
		UserInputService.MouseIconEnabled = not hideCursor
	end)
end

return CameraController
