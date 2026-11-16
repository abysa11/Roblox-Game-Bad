--[[
	UIKit
	Shared look & feel: a minimal dark competitive-FPS theme, element constructors,
	responsive scaling and the mouse-unlock helper for menus in first person.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local ClientState = require(script.Parent.ClientState)

local UIKit = {}

UIKit.T = {
	Bg = Color3.fromRGB(12, 13, 17),
	Panel = Color3.fromRGB(20, 22, 28),
	Panel2 = Color3.fromRGB(30, 33, 41),
	Panel3 = Color3.fromRGB(42, 46, 57),
	Stroke = Color3.fromRGB(58, 63, 76),
	Text = Color3.fromRGB(240, 242, 246),
	Sub = Color3.fromRGB(150, 156, 170),
	Accent = Color3.fromRGB(255, 140, 40),
	Good = Color3.fromRGB(70, 210, 120),
	Bad = Color3.fromRGB(235, 70, 70),
	Gold = Color3.fromRGB(255, 196, 46),
	Silver = Color3.fromRGB(200, 208, 220),
	Bronze = Color3.fromRGB(205, 127, 50),
	Red = Color3.fromRGB(232, 72, 77),
	Blue = Color3.fromRGB(62, 142, 247),
}

UIKit.Font = Enum.Font.GothamBold
UIKit.FontBlack = Enum.Font.GothamBlack
UIKit.FontRegular = Enum.Font.GothamMedium

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
UIKit.PlayerGui = playerGui

-- Generic constructor: UIKit.New("Frame", { Size = ..., Corner = 8, Stroke = {...}, Padding = 6 }, { children })
function UIKit.New(className: string, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for k, v in pairs(props or {}) do
		if k == "Corner" then
			local c = Instance.new("UICorner")
			c.CornerRadius = typeof(v) == "UDim" and v or UDim.new(0, v)
			c.Parent = inst
		elseif k == "Stroke" then
			local s = Instance.new("UIStroke")
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			s.Color = v.Color or UIKit.T.Stroke
			s.Thickness = v.Thickness or 1
			s.Transparency = v.Transparency or 0
			s.Parent = inst
		elseif k == "Padding" then
			local p = Instance.new("UIPadding")
			local u = typeof(v) == "UDim" and v or UDim.new(0, v)
			p.PaddingLeft, p.PaddingRight, p.PaddingTop, p.PaddingBottom = u, u, u, u
			p.Parent = inst
		elseif k == "Gradient" then
			local g = Instance.new("UIGradient")
			g.Color = v.Color or ColorSequence.new(Color3.new(1, 1, 1))
			g.Rotation = v.Rotation or 90
			if v.Transparency then
				g.Transparency = v.Transparency
			end
			g.Parent = inst
		elseif k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIKit.Screen(name: string, displayOrder: number?, ignoreInset: boolean?): ScreenGui
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = ignoreInset == true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or 0
	gui.Parent = playerGui
	UIKit.AutoScale(gui)
	return gui
end

-- Scales a whole ScreenGui relative to a 1280x720 reference, with a floor for phones.
function UIKit.AutoScale(gui: ScreenGui)
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local camera = workspace.CurrentCamera
	local function update()
		local vp = camera.ViewportSize
		local s = math.min(vp.X / 1280, vp.Y / 720)
		if ClientState.IsTouch() then
			s = math.clamp(s * 1.25, 0.62, 1.2)
		else
			s = math.clamp(s, 0.7, 1.4)
		end
		scale.Scale = s
	end
	update()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	return scale
end

function UIKit.Label(props)
	local p = {
		BackgroundTransparency = 1,
		Font = UIKit.Font,
		TextColor3 = UIKit.T.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return UIKit.New("TextLabel", p)
end

function UIKit.Tween(obj: Instance, t: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Button with hover / press feedback and click sound. `onClick` runs on Activated.
function UIKit.Button(props, onClick)
	local base = props.BackgroundColor3 or UIKit.T.Panel3
	local p = {
		AutoButtonColor = false,
		BackgroundColor3 = base,
		Font = UIKit.Font,
		TextColor3 = UIKit.T.Text,
		TextSize = 16,
		Corner = 8,
		Text = "",
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	local btn = UIKit.New("TextButton", p)
	local hover = base:Lerp(Color3.new(1, 1, 1), 0.12)
	btn.MouseEnter:Connect(function()
		if btn.Active then
			UIKit.Tween(btn, 0.12, { BackgroundColor3 = btn:GetAttribute("Base") and (btn:GetAttribute("Base") :: Color3):Lerp(Color3.new(1, 1, 1), 0.12) or hover })
		end
	end)
	btn.MouseLeave:Connect(function()
		UIKit.Tween(btn, 0.12, { BackgroundColor3 = btn:GetAttribute("Base") or base })
	end)
	btn.Activated:Connect(function()
		if not btn.Active then
			return
		end
		Sounds.Play("UIClick")
		if onClick then
			onClick(btn)
		end
	end)
	return btn
end

-- Change a button's resting colour (keeps hover logic consistent).
function UIKit.SetButtonColor(btn: GuiButton, color: Color3)
	btn:SetAttribute("Base", color)
	btn.BackgroundColor3 = color
end

-- Dark full-screen dimmer + centred window; returns (screen, window, closeButton)
function UIKit.Window(name: string, title: string, size: UDim2, order: number?)
	local screen = UIKit.Screen(name, order or 20, true)
	screen.Enabled = false
	local dim = UIKit.New("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		Modal = true, -- frees the mouse while in first person
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Parent = screen,
	})
	local window = UIKit.New("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = UIKit.T.Panel,
		Corner = 12,
		Stroke = { Color = UIKit.T.Stroke, Thickness = 1 },
		Parent = screen,
	})
	UIKit.New("Frame", {
		Name = "AccentBar",
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = UIKit.T.Accent,
		BorderSizePixel = 0,
		Parent = window,
	})
	UIKit.Label({
		Name = "Title",
		Text = title,
		Font = UIKit.FontBlack,
		TextSize = 24,
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -80, 0, 30),
		Parent = window,
	})
	local close = UIKit.Button({
		Name = "Close",
		Text = "X",
		TextSize = 18,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = UIKit.T.Panel3,
		Parent = window,
	})
	dim.Activated:Connect(function() end)
	return screen, window, close
end

-- Horizontal stat bar
function UIKit.StatBar(parent: Instance, label: string, value: number, y: number, width: number?)
	local row = UIKit.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 22), Parent = parent })
	UIKit.Label({ Text = label:upper(), TextSize = 12, TextColor3 = UIKit.T.Sub, Size = UDim2.new(0.4, 0, 1, 0), Parent = row })
	local track = UIKit.New("Frame", {
		Position = UDim2.new(0.4, 0, 0.5, -4),
		Size = UDim2.new(width or 0.6, 0, 0, 8),
		BackgroundColor3 = UIKit.T.Panel3,
		Corner = 4,
		Parent = row,
	})
	local fill = UIKit.New("Frame", {
		Size = UDim2.fromScale(math.clamp(value / 100, 0, 1), 1),
		BackgroundColor3 = UIKit.T.Accent,
		Corner = 4,
		Parent = track,
	})
	return row, fill
end

-- Rotating 3D preview of any model inside a ViewportFrame. Returns (viewport, setModel)
function UIKit.Preview(parent: Instance, props)
	local vp = UIKit.New("ViewportFrame", {
		BackgroundColor3 = UIKit.T.Bg,
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.5, -1),
		Corner = 10,
		Parent = parent,
	})
	for k, v in pairs(props or {}) do
		(vp :: any)[k] = v
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local current: Model? = nil
	local angle = 0
	local distance = 8
	local conn
	local function setModel(model: Model?, length: number?)
		if current then
			current:Destroy()
		end
		current = model
		if model then
			model:PivotTo(CFrame.new())
			model.Parent = world
			distance = (length or 3) * 2.4 + 1
		end
	end
	conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
		if not vp.Parent then
			conn:Disconnect()
			return
		end
		if not vp.Visible or not current then
			return
		end
		local gui = vp:FindFirstAncestorOfClass("ScreenGui")
		if gui and not gui.Enabled then
			return
		end
		angle += dt * 0.6
		local center = Vector3.new(0, 0.2, -1.2)
		local pos = center + Vector3.new(math.sin(angle) * distance, distance * 0.25, math.cos(angle) * distance)
		cam.CFrame = CFrame.lookAt(pos, center)
	end)
	return vp, setModel
end

return UIKit
