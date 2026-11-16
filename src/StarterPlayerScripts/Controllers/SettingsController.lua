--[[
	SettingsController
	Settings menu (volumes, mouse / touch sensitivity, crosshair, effects quality).
	Changes apply live; "Save" stores them in the player's profile through the server.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Util = require(ReplicatedStorage.Shared.Util)
local ClientState = require(script.Parent.ClientState)
local UIKit = require(script.Parent.UIKit)

local SettingsController = {}

local T = UIKit.T
local screen, window
local refreshers = {}
local dirty = false

local DEFAULTS = Util.DeepCopy(ClientState.Settings)

local function apply()
	local s = ClientState.Settings
	Sounds.SetVolumes(s.MasterVolume, s.MusicVolume, s.SfxVolume)
	ClientState.SettingsChanged:Fire(s)
end

local function pct(v)
	return math.floor(v * 100 + 0.5) .. "%"
end

local function slider(parent, y, label, key, min, max, step, fmt)
	local row = UIKit.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 40), Parent = parent })
	UIKit.Label({ Text = label, TextSize = 15, Size = UDim2.new(0.38, 0, 1, 0), Parent = row })
	local valueLabel = UIKit.Label({ Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.Accent, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.14, 0, 1, 0), Parent = row })
	local track = UIKit.New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.new(0.4, 0, 0.5, -5),
		Size = UDim2.new(0.44, 0, 0, 10),
		BackgroundColor3 = T.Panel3,
		Corner = 5,
		Parent = row,
	})
	local fill = UIKit.New("Frame", { BackgroundColor3 = T.Accent, Size = UDim2.fromScale(0, 1), Corner = 5, Parent = track })
	local knob = UIKit.New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = T.Text, Corner = 10, Parent = track })
	local function refresh()
		local v = ClientState.Settings[key]
		local a = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		valueLabel.Text = type(fmt) == "function" and fmt(v) or string.format(fmt or "%.2f", v)
	end
	local dragging = false
	local function setFromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local v = min + (max - min) * a
		v = math.floor(v / step + 0.5) * step
		ClientState.Settings[key] = math.clamp(v, min, max)
		dirty = true
		refresh()
		apply()
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	table.insert(refreshers, refresh)
	refresh()
end

local function header(parent, y, text)
	UIKit.Label({ Text = text, TextSize = 13, TextColor3 = T.Sub, Font = UIKit.FontBlack, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 20), Parent = parent })
end

local function build()
	screen, window = nil, nil
	local close
	screen, window, close = UIKit.Window("SettingsUI", "SETTINGS", UDim2.fromOffset(640, 600), 40)

	local scroll = UIKit.New("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 1, -130),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 640),
		Parent = window,
	})
	local y = 0
	header(scroll, y, "AUDIO")
	y += 24
	slider(scroll, y, "Master Volume", "MasterVolume", 0, 1, 0.05, pct)
	y += 42
	slider(scroll, y, "Music Volume", "MusicVolume", 0, 1, 0.05, pct)
	y += 42
	slider(scroll, y, "Effects Volume", "SfxVolume", 0, 1, 0.05, pct)
	y += 52
	header(scroll, y, "CONTROLS")
	y += 24
	slider(scroll, y, "Mouse Sensitivity", "MouseSensitivity", 0.1, 4, 0.05)
	y += 42
	slider(scroll, y, "Touch Aim Sensitivity", "TouchSensitivity", 0.1, 4, 0.05)
	y += 52
	header(scroll, y, "CROSSHAIR")
	y += 24
	slider(scroll, y, "Size", "CrosshairSize", 2, 24, 1, "%d")
	y += 42
	slider(scroll, y, "Gap", "CrosshairGap", 0, 16, 1, "%d")
	y += 42
	slider(scroll, y, "Thickness", "CrosshairThickness", 1, 6, 1, "%d")
	y += 44

	-- colour + dot
	local colorRow = UIKit.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 40), Parent = scroll })
	UIKit.Label({ Text = "Color", TextSize = 15, Size = UDim2.new(0.38, 0, 1, 0), Parent = colorRow })
	local colorBtn
	colorBtn = UIKit.Button({ Position = UDim2.new(0.4, 0, 0, 4), Size = UDim2.new(0.25, 0, 0, 32), TextSize = 14, Parent = colorRow }, function()
		local order = ClientState.CrosshairOrder
		local i = table.find(order, ClientState.Settings.CrosshairColor) or 1
		ClientState.Settings.CrosshairColor = order[(i % #order) + 1]
		dirty = true
		apply()
		for _, r in ipairs(refreshers) do
			r()
		end
	end)
	local dotBtn
	dotBtn = UIKit.Button({ Position = UDim2.new(0.68, 0, 0, 4), Size = UDim2.new(0.32, 0, 0, 32), TextSize = 14, Parent = colorRow }, function()
		ClientState.Settings.CrosshairDot = not ClientState.Settings.CrosshairDot
		dirty = true
		apply()
		for _, r in ipairs(refreshers) do
			r()
		end
	end)
	table.insert(refreshers, function()
		local c = ClientState.Settings.CrosshairColor
		colorBtn.Text = c:upper()
		colorBtn.TextColor3 = ClientState.CrosshairColors[c] or T.Text
		dotBtn.Text = ClientState.Settings.CrosshairDot and "CENTER DOT: ON" or "CENTER DOT: OFF"
	end)
	y += 52

	header(scroll, y, "GRAPHICS")
	y += 24
	local fxRow = UIKit.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 40), Parent = scroll })
	UIKit.Label({ Text = "Effects Quality", TextSize = 15, Size = UDim2.new(0.38, 0, 1, 0), Parent = fxRow })
	local fxButtons = {}
	for i, level in ipairs({ "Low", "Medium", "High" }) do
		fxButtons[level] = UIKit.Button({
			Text = level:upper(),
			TextSize = 13,
			Position = UDim2.new(0.4 + (i - 1) * 0.2, 0, 0, 4),
			Size = UDim2.new(0.19, 0, 0, 32),
			Parent = fxRow,
		}, function()
			ClientState.Settings.Effects = level
			dirty = true
			apply()
			for _, r in ipairs(refreshers) do
				r()
			end
		end)
	end
	table.insert(refreshers, function()
		for level, btn in pairs(fxButtons) do
			UIKit.SetButtonColor(btn, ClientState.Settings.Effects == level and T.Accent or T.Panel3)
		end
	end)
	y += 44
	UIKit.Label({
		Text = "Low disables shadows, fire/particles and post-processing for weaker phones and PCs. Your Roblox graphics quality slider still applies on top.",
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = T.Sub,
		Font = UIKit.FontRegular,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 34),
		Parent = scroll,
	})
	scroll.CanvasSize = UDim2.fromOffset(0, y + 50)

	-- footer
	local status = UIKit.Label({ Text = "", TextSize = 13, TextColor3 = T.Sub, Position = UDim2.new(0, 20, 1, -52), Size = UDim2.new(0.4, 0, 0, 36), Parent = window })
	UIKit.Button({ Text = "RESET", Position = UDim2.new(1, -330, 1, -56), Size = UDim2.fromOffset(100, 40), Parent = window }, function()
		for k, v in pairs(DEFAULTS) do
			ClientState.Settings[k] = v
		end
		dirty = true
		apply()
		for _, r in ipairs(refreshers) do
			r()
		end
	end)
	UIKit.Button({ Text = "SAVE & CLOSE", BackgroundColor3 = T.Accent, TextColor3 = Color3.new(0, 0, 0), Position = UDim2.new(1, -220, 1, -56), Size = UDim2.fromOffset(200, 40), Parent = window }, function()
		status.Text = "Saving..."
		local ok, saved = pcall(function()
			return Net.Function("SaveSettings"):InvokeServer(ClientState.Settings)
		end)
		status.Text = (ok and saved) and "Saved" or "Could not save (will retry next time)"
		dirty = not (ok and saved)
		SettingsController.Close()
	end)
	close.Activated:Connect(function()
		SettingsController.Close()
	end)
	for _, r in ipairs(refreshers) do
		r()
	end
end

function SettingsController.Open()
	if not screen then
		build()
	end
	for _, r in ipairs(refreshers) do
		r()
	end
	screen.Enabled = true
	ClientState.SetMenu("Settings", true)
end

function SettingsController.Close()
	if screen then
		screen.Enabled = false
	end
	ClientState.SetMenu("Settings", false)
	if dirty then
		dirty = false
		task.spawn(function()
			pcall(function()
				Net.Function("SaveSettings"):InvokeServer(ClientState.Settings)
			end)
		end)
	end
end

function SettingsController.Toggle()
	if screen and screen.Enabled then
		SettingsController.Close()
	else
		SettingsController.Open()
	end
end

function SettingsController.Init()
	ClientState.SettingsChanged:Connect(function()
		local s = ClientState.Settings
		Sounds.SetVolumes(s.MasterVolume, s.MusicVolume, s.SfxVolume)
	end)
	apply()
end

return SettingsController
