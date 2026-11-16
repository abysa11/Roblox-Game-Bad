--[[
	LobbyUI
	Main-menu overlay shown in the hub: player profile (avatar, name, points, lifetime stats),
	live map queue list, queue status banner, Skin Shop and Settings buttons.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local MapData = require(ReplicatedStorage.Shared.MapData)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local ClientState = require(script.Parent.ClientState)
local UIKit = require(script.Parent.UIKit)
local CameraController = require(script.Parent.CameraController)
local SkinShopUI = require(script.Parent.SkinShopUI)
local SettingsController = require(script.Parent.SettingsController)

local LobbyUI = {}

local T = UIKit.T
local player = Players.LocalPlayer
local screen
local ui = {}
local lastQueued = nil

local function build()
	screen = UIKit.Screen("MainMenu", 3)
	local touch = ClientState.IsTouch()

	-- profile card
	local card = UIKit.New("Frame", { Position = UDim2.fromOffset(16, 60), Size = UDim2.fromOffset(320, 112), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.1, Corner = 12, Parent = screen })
	UIKit.New("Frame", { BackgroundColor3 = T.Accent, Size = UDim2.new(0, 3, 1, -20), Position = UDim2.fromOffset(0, 10), BorderSizePixel = 0, Parent = card })
	local avatar = UIKit.New("ImageLabel", { BackgroundColor3 = T.Panel3, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(84, 84), Corner = 10, Parent = card })
	task.spawn(function()
		if player.UserId > 0 then
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok then
				avatar.Image = url
			end
		end
	end)
	UIKit.Label({ Text = player.DisplayName, Font = UIKit.FontBlack, TextSize = 20, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(110, 14), Size = UDim2.fromOffset(200, 24), Parent = card })
	UIKit.Label({ Text = "@" .. player.Name, TextSize = 12, Font = UIKit.FontRegular, TextColor3 = T.Sub, Position = UDim2.fromOffset(110, 38), Size = UDim2.fromOffset(200, 16), Parent = card })
	ui.Points = UIKit.Label({ Text = "0 POINTS", Font = UIKit.FontBlack, TextSize = 18, TextColor3 = T.Gold, Position = UDim2.fromOffset(110, 58), Size = UDim2.fromOffset(200, 22), Parent = card })
	ui.Stats = UIKit.Label({ Text = "", TextSize = 12, TextColor3 = T.Sub, Position = UDim2.fromOffset(110, 82), Size = UDim2.fromOffset(200, 16), Parent = card })

	-- map queue list
	-- bottom-right, above the buttons: the top-right corner belongs to Roblox's player list
	local maps = UIKit.New("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -84),
		Size = UDim2.fromOffset(300, 46 + #MapData.Order * 46),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.1,
		Corner = 12,
		Visible = not touch,
		Parent = screen,
	})
	UIKit.Label({ Text = "SELECT A MAP", Font = UIKit.FontBlack, TextSize = 14, Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(200, 18), Parent = maps })
	UIKit.Label({ Text = "Walk onto a pad", TextSize = 11, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -150, 0, 12), Size = UDim2.fromOffset(136, 14), Parent = maps })
	ui.MapRows = {}
	for i, id in ipairs(MapData.Order) do
		local m = MapData.Get(id)
		local row = UIKit.New("Frame", { BackgroundColor3 = T.Panel2, Position = UDim2.fromOffset(10, 38 + (i - 1) * 46), Size = UDim2.new(1, -20, 0, 40), Corner = 8, Parent = maps })
		UIKit.New("Frame", { BackgroundColor3 = m.Color, Size = UDim2.new(0, 4, 1, -12), Position = UDim2.fromOffset(6, 6), Corner = 2, Parent = row })
		UIKit.Label({ Text = m.Name, TextSize = 14, Position = UDim2.fromOffset(18, 3), Size = UDim2.new(1, -110, 0, 18), Parent = row })
		UIKit.Label({ Text = m.Subtitle, TextSize = 10, TextColor3 = m.Color, Position = UDim2.fromOffset(18, 21), Size = UDim2.new(1, -110, 0, 14), Parent = row })
		local count = UIKit.Label({ Text = "0 waiting", TextSize = 12, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -100, 0, 0), Size = UDim2.fromOffset(90, 40), Parent = row })
		ui.MapRows[id] = { Row = row, Count = count }
	end

	-- queue banner
	ui.Queue = UIKit.New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, touch and -150 or -24), Size = UDim2.fromOffset(520, 70), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.05, Corner = 12, Visible = false, Parent = screen })
	ui.QueueStroke = UIKit.New("UIStroke", { Color = T.Accent, Thickness = 2, Parent = ui.Queue })
	ui.QueueTitle = UIKit.Label({ Text = "", Font = UIKit.FontBlack, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 26), Parent = ui.Queue })
	ui.QueueSub = UIKit.Label({ Text = "", TextSize = 13, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 20), Parent = ui.Queue })

	ui.Hint = UIKit.Label({ Text = "Walk onto one of the five map pads to queue for a match.", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, touch and -150 or -30), Size = UDim2.fromOffset(600, 22), Parent = screen })

	-- buttons
	local buttons = UIKit.New("Frame", {
		AnchorPoint = touch and Vector2.new(1, 0) or Vector2.new(1, 1),
		Position = touch and UDim2.new(1, -16, 0, 60) or UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(touch and 150 or 360, touch and 112 or 54),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	UIKit.New("UIListLayout", { FillDirection = touch and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), Parent = buttons })
	UIKit.Button({ Text = "SKIN SHOP", TextSize = 16, BackgroundColor3 = Color3.fromRGB(110, 60, 220), Size = UDim2.fromOffset(touch and 150 or 170, touch and 52 or 54), Parent = buttons }, function()
		SkinShopUI.Open()
	end)
	UIKit.Button({ Text = "SETTINGS", TextSize = 16, Size = UDim2.fromOffset(touch and 150 or 170, touch and 52 or 54), Parent = buttons }, function()
		SettingsController.Open()
	end)
end

local function refreshProfile()
	local p = ClientState.Profile
	if not p or not ui.Points then
		return
	end
	ui.Points.Text = string.format("%d POINTS", p.Points or 0)
	local s = p.Stats or {}
	local kd = (s.Deaths or 0) > 0 and (s.Kills or 0) / s.Deaths or (s.Kills or 0)
	ui.Stats.Text = string.format("K/D %.2f  ·  %d matches  ·  %d wins", kd, s.Matches or 0, s.Wins or 0)
end

local function refreshQueue()
	local queued = player:GetAttribute("QueuedMap")
	local lobby = ClientState.Lobby or {}
	for id, row in pairs(ui.MapRows) do
		local q = lobby[id] or {}
		local text = string.format("%d waiting", q.Waiting or 0)
		if (q.InMatch or 0) > 0 then
			text = text .. string.format("\n%d in match", q.InMatch)
		end
		row.Count.Text = text
		row.Row.BackgroundColor3 = (queued == id) and T.Panel3 or T.Panel2
	end
	if queued then
		local map = MapData.Get(queued)
		local q = lobby[queued] or {}
		ui.Queue.Visible = true
		ui.Hint.Visible = false
		ui.QueueStroke.Color = map and map.Color or T.Accent
		local left = q.EndsAt and math.max(0, math.ceil(q.EndsAt - workspace:GetServerTimeNow())) or nil
		local waiting = q.Waiting or 1
		ui.QueueTitle.Text = string.format("QUEUED: %s", map and map.Name:upper() or queued)
		if waiting < Config.Lobby.MinPlayersToLaunch then
			ui.QueueSub.Text = string.format("%d / %d players  ·  waiting for more players  ·  step off the pad to leave", waiting, Config.Match.MaxPlayers)
		else
			ui.QueueSub.Text = string.format("%d / %d players  ·  launching in %s  ·  step off the pad to leave", waiting, Config.Match.MaxPlayers, left and (left .. "s") or "...")
		end
	else
		ui.Queue.Visible = false
		ui.Hint.Visible = true
	end
	if queued ~= lastQueued then
		if queued then
			Sounds.Play("QueueJoin")
		end
		lastQueued = queued
	end
end

function LobbyUI.Init()
	build()
	ClientState.ProfileChanged:Connect(refreshProfile)
	Net.Event("LobbyState").OnClientEvent:Connect(function(state)
		if type(state) == "table" then
			ClientState.Lobby = state
			ClientState.LobbyChanged:Fire(state)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local show = not ClientState.InMatch and not CameraController.IsCinematic()
			and workspace:GetAttribute("ServerRole") ~= "Match"
		screen.Enabled = show
		if show then
			refreshQueue()
		end
	end)
	refreshProfile()
end

return LobbyUI
