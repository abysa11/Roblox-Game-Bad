--[[
	MobileControls
	Dedicated touch layout for matches (not a shrunk PC UI):
	  * Roblox's dynamic thumbstick (left) for movement + its jump button
	  * Aim pad: drag anywhere on the right side to look, using your Touch Aim Sensitivity
	  * FIRE (right, drag on it to keep aiming while shooting) + a second FIRE on the left
	  * AIM / ALT (scope, burst toggle, knife stab), RELOAD, SWITCH weapon, KNIFE
	  * SHOP / SCORE / SETTINGS live in the top bar (HUDController)
]]

local UserInputService = game:GetService("UserInputService")

local ClientState = require(script.Parent.ClientState)
local UIKit = require(script.Parent.UIKit)
local InputController = require(script.Parent.InputController)
local WeaponController = require(script.Parent.WeaponController)
local CameraController = require(script.Parent.CameraController)

local MobileControls = {}

local T = UIKit.T
local camera = workspace.CurrentCamera
local controls, aimGui
local buttons = {}
local tracked: { [InputObject]: boolean } = {}

local function rotateCamera(delta: Vector3)
	local k = 0.22 * (ClientState.Settings.TouchSensitivity or 1) * CameraController.GetZoomScale()
	local cf = camera.CFrame
	local pitch, yaw = cf:ToEulerAnglesYXZ()
	pitch = math.clamp(pitch - math.rad(delta.Y * k), math.rad(-80), math.rad(80))
	yaw -= math.rad(delta.X * k)
	camera.CFrame = CFrame.new(cf.Position) * CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
end

local function holdButton(props, action: string?, onPress: (() -> ())?, aims: boolean?)
	local p = {
		Text = props.Text,
		Font = UIKit.FontBlack,
		TextSize = props.TextSize or 14,
		TextColor3 = T.Text,
		AutoButtonColor = false,
		BackgroundColor3 = props.Color or Color3.fromRGB(20, 22, 28),
		BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position,
		Size = props.Size,
		Corner = UDim.new(1, 0),
		Stroke = { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.6 },
		Parent = controls,
	}
	local btn = UIKit.New("TextButton", p)
	btn.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		btn.BackgroundTransparency = 0.1
		if aims then
			tracked[input] = true
		end
		if action then
			InputController.Trigger(action, true)
		end
		if onPress then
			onPress()
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		btn.BackgroundTransparency = 0.35
		tracked[input] = nil
		if action then
			InputController.Trigger(action, false)
		end
	end)
	return btn
end

local function build()
	-- aim pad sits *below* Roblox's TouchGui so the jump button keeps priority
	aimGui = UIKit.Screen("MobileAimPad", -5, true)
	local pad = UIKit.New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 60),
		Size = UDim2.new(0.55, 0, 1, -60),
		Parent = aimGui,
	})
	pad.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			tracked[input] = true
		end
	end)
	pad.InputEnded:Connect(function(input)
		tracked[input] = nil
	end)

	controls = UIKit.Screen("MobileControls", 6, true)
	-- the controls are laid out in scale so they stay thumb-reachable on every screen size
	buttons.Fire = holdButton({ Text = "FIRE", TextSize = 18, Color = Color3.fromRGB(150, 30, 30), Position = UDim2.new(0.86, 0, 0.56, 0), Size = UDim2.fromOffset(104, 104) }, "Fire", nil, true)
	buttons.Fire2 = holdButton({ Text = "FIRE", TextSize = 13, Color = Color3.fromRGB(150, 30, 30), Position = UDim2.new(0.1, 0, 0.42, 0), Size = UDim2.fromOffset(68, 68) }, "Fire", nil, true)
	buttons.Alt = holdButton({ Text = "AIM", Position = UDim2.new(0.75, 0, 0.42, 0), Size = UDim2.fromOffset(72, 72) }, "Alt", nil, true)
	buttons.Reload = holdButton({ Text = "R", TextSize = 18, Position = UDim2.new(0.94, 0, 0.36, 0), Size = UDim2.fromOffset(60, 60) }, "Reload")
	buttons.Switch = holdButton({ Text = "SWAP", TextSize = 12, Position = UDim2.new(0.94, 0, 0.2, 0), Size = UDim2.fromOffset(60, 60) }, nil, function()
		WeaponController.Cycle(1)
	end)
	buttons.Knife = holdButton({ Text = "KNIFE", TextSize = 12, Position = UDim2.new(0.84, 0, 0.24, 0), Size = UDim2.fromOffset(60, 60) }, nil, function()
		local info = WeaponController.GetInfo()
		if info.Slot == "Melee" then
			WeaponController.Equip(info.Loadout.Primary and "Primary" or "Secondary")
		else
			WeaponController.Equip("Melee")
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if tracked[input] and input.UserInputType == Enum.UserInputType.Touch then
			rotateCamera(input.Delta)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		tracked[input] = nil
	end)
end

local function refresh()
	local show = ClientState.InMatch and not CameraController.IsCinematic() and not ClientState.IsMenuOpen()
	controls.Enabled = show
	aimGui.Enabled = show
	if not show then
		tracked = {}
		InputController.ReleaseAll()
	end
	local info = WeaponController.GetInfo()
	local w = info.Weapon
	if w then
		buttons.Alt.Text = w.ScopeLevels and "SCOPE" or (w.AltFire == "Burst" and (info.Burst and "SEMI" or "BURST") or (w.Category == "Melee" and "STAB" or "-"))
		buttons.Fire.Text = w.Category == "Melee" and "SLASH" or "FIRE"
		buttons.Knife.Text = info.Slot == "Melee" and "GUN" or "KNIFE"
	end
	buttons.Reload.Visible = w ~= nil and w.MagSize ~= nil
end

function MobileControls.Init()
	if not UserInputService.TouchEnabled then
		return
	end
	build()
	refresh()
	ClientState.MatchChanged:Connect(refresh)
	ClientState.MenuChanged:Connect(refresh)
	WeaponController.Changed:Connect(refresh)
	game:GetService("RunService").Heartbeat:Connect(function()
		local cinematic = CameraController.IsCinematic()
		if controls.Enabled == cinematic and ClientState.InMatch then
			refresh()
		end
	end)
end

return MobileControls
