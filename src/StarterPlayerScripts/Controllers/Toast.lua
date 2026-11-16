--[[
	Toast
	Short stacked notifications at the top of the screen (server Notify events + local messages).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local UIKit = require(script.Parent.UIKit)

local Toast = {}

local T = UIKit.T
local screen, list

local COLORS = {
	info = T.Accent,
	error = T.Bad,
	success = T.Good,
	start = T.Gold,
	Red = Config.Teams.Red.Color,
	Blue = Config.Teams.Blue.Color,
}

function Toast.Show(text: string, kind: string?)
	if not screen then
		return
	end
	local color = COLORS[kind or "info"] or T.Accent
	local item = UIKit.New("Frame", {
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.08,
		Size = UDim2.fromOffset(440, 40),
		Corner = 8,
		Stroke = { Color = color, Thickness = 1, Transparency = 0.3 },
		Parent = list,
	})
	UIKit.New("Frame", { BackgroundColor3 = color, Size = UDim2.new(0, 4, 1, -12), Position = UDim2.fromOffset(8, 6), Corner = 2, Parent = item })
	UIKit.Label({
		Text = text,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -30, 1, 0),
		Parent = item,
	})
	if kind == "error" then
		Sounds.Play("UIError")
	end
	task.delay(3.6, function()
		if item.Parent then
			UIKit.Tween(item, 0.3, { BackgroundTransparency = 1 })
			for _, d in ipairs(item:GetDescendants()) do
				if d:IsA("TextLabel") then
					UIKit.Tween(d, 0.3, { TextTransparency = 1 })
				elseif d:IsA("Frame") then
					UIKit.Tween(d, 0.3, { BackgroundTransparency = 1 })
				elseif d:IsA("UIStroke") then
					UIKit.Tween(d, 0.3, { Transparency = 1 })
				end
			end
			task.wait(0.32)
			item:Destroy()
		end
	end)
end

function Toast.Init()
	screen = UIKit.Screen("Toasts", 50)
	list = UIKit.New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(440, 300),
		Parent = screen,
	})
	UIKit.New("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	Net.Event("Notify").OnClientEvent:Connect(function(text, kind)
		if type(text) == "string" then
			Toast.Show(text, kind)
		end
	end)
end

return Toast
