--[[
	HUDController
	In-match HUD: timer + team counts/score, your team & kills, health, weapon & ammo,
	weapon slots, dynamic crosshair, hit markers, damage direction, kill feed, death screen,
	warmup countdown, spawn protection, shop hint, scoreboard (Tab) and the sniper scope.
	Also owns the top-bar Shop / Settings / Scoreboard buttons (used on phones and PCs).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)
local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local WeaponData = require(ReplicatedStorage.WeaponModules.WeaponData)
local ClientState = require(script.Parent.ClientState)
local UIKit = require(script.Parent.UIKit)
local InputController = require(script.Parent.InputController)
local WeaponController = require(script.Parent.WeaponController)
local CameraController = require(script.Parent.CameraController)
local WeaponShopUI = require(script.Parent.WeaponShopUI)
local SettingsController = require(script.Parent.SettingsController)

local HUDController = {}

local T = UIKit.T
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local hud, topbar, scopeGui
local ui = {}
local deathInfo = nil
local lastCountdown = -1
local lastState = nil
local scoreboardOpen = false

local function teamColor(team)
	return team and Config.Teams[team] and Config.Teams[team].Color or T.Sub
end

-- TOP BAR BUTTONS (outside the scaled HUD so they line up with Roblox's own buttons) ---------
local function buildTopbar()
	topbar = Instance.new("ScreenGui")
	topbar.Name = "TopbarButtons"
	topbar.ResetOnSpawn = false
	topbar.IgnoreGuiInset = true
	topbar.DisplayOrder = 60
	topbar.Parent = UIKit.PlayerGui
	local holder = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(400, 44), Parent = topbar })
	UIKit.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = holder })
	local function place()
		local x, y, h = 104, 4, 44
		local ok, inset = pcall(function()
			return GuiService.TopbarInset
		end)
		if ok and inset and inset.Width > 0 then
			x = inset.Min.X + 8
			h = math.max(32, inset.Height - 8)
			y = inset.Min.Y + (inset.Height - h) / 2
		end
		holder.Position = UDim2.fromOffset(x, y)
		holder.Size = UDim2.fromOffset(400, h)
	end
	place()
	pcall(function()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	end)
	local function topButton(name, text, w, onClick)
		local b = UIKit.Button({
			Name = name,
			Text = text,
			TextSize = 14,
			Size = UDim2.new(0, w, 1, 0),
			BackgroundColor3 = Color3.fromRGB(18, 20, 26),
			BackgroundTransparency = 0.25,
			Corner = UDim.new(1, 0),
			Parent = holder,
		}, onClick)
		return b
	end
	ui.ShopButton = topButton("Shop", "SHOP (B)", 104, function()
		WeaponShopUI.Toggle()
	end)
	ui.ScoreButton = topButton("Score", "SCORE", 80, function()
		HUDController.SetScoreboard(not scoreboardOpen)
	end)
	ui.GearButton = topButton("Settings", "SETTINGS", 96, function()
		SettingsController.Toggle()
	end)
	if ClientState.IsTouch() then
		ui.ShopButton.Text = "SHOP"
	end
end

-- MAIN HUD ---------------------------------------------------------------------------
local function buildHud()
	hud = UIKit.Screen("HUD", 5)
	local touch = ClientState.IsTouch()

	-- top centre: timer + teams
	local top = UIKit.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(460, 64), Parent = hud })
	local function teamBox(team, x, anchor)
		local f = UIKit.New("Frame", {
			AnchorPoint = Vector2.new(anchor, 0),
			Position = UDim2.new(x, 0, 0, 0),
			Size = UDim2.fromOffset(150, 52),
			BackgroundColor3 = T.Panel,
			BackgroundTransparency = 0.15,
			Corner = 8,
			Parent = top,
		})
		UIKit.New("Frame", { BackgroundColor3 = teamColor(team), Size = UDim2.new(1, 0, 0, 3), BorderSizePixel = 0, Parent = f })
		local score = UIKit.Label({ Text = "0", Font = UIKit.FontBlack, TextSize = 26, TextColor3 = teamColor(team), TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 28), Parent = f })
		local count = UIKit.Label({ Text = "", TextSize = 12, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 16), Parent = f })
		return score, count
	end
	ui.RedScore, ui.RedCount = teamBox("Red", 0, 0)
	ui.BlueScore, ui.BlueCount = teamBox("Blue", 1, 1)
	local timerBox = UIKit.New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(140, 60), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.1, Corner = 8, Stroke = { Color = T.Stroke }, Parent = top })
	ui.Timer = UIKit.Label({ Text = "10:00", Font = UIKit.FontBlack, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 34), Parent = timerBox })
	ui.Phase = UIKit.Label({ Text = "", TextSize = 11, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 16), Parent = timerBox })

	-- player panel (bottom-left on PC, top-left on touch so the thumbstick stays free)
	local pp = UIKit.New("Frame", {
		AnchorPoint = touch and Vector2.new(0, 0) or Vector2.new(0, 1),
		Position = touch and UDim2.new(0, 16, 0, 64) or UDim2.new(0, 20, 1, -20),
		Size = UDim2.fromOffset(300, 92),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.15,
		Corner = 10,
		Parent = hud,
	})
	ui.TeamPill = UIKit.Label({ Text = "RED TEAM", TextSize = 12, Font = UIKit.FontBlack, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = T.Red, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(100, 22), Corner = 6, Parent = pp })
	ui.Kills = UIKit.Label({ Text = "KILLS 0", TextSize = 16, Font = UIKit.FontBlack, Position = UDim2.fromOffset(124, 10), Size = UDim2.fromOffset(90, 22), Parent = pp })
	ui.Deaths = UIKit.Label({ Text = "DEATHS 0", TextSize = 13, TextColor3 = T.Sub, Position = UDim2.fromOffset(214, 10), Size = UDim2.fromOffset(80, 22), Parent = pp })
	ui.HealthText = UIKit.Label({ Text = "100", Font = UIKit.FontBlack, TextSize = 34, Position = UDim2.fromOffset(12, 38), Size = UDim2.fromOffset(70, 40), Parent = pp })
	local hpTrack = UIKit.New("Frame", { Position = UDim2.fromOffset(84, 54), Size = UDim2.fromOffset(200, 12), BackgroundColor3 = T.Panel3, Corner = 6, Parent = pp })
	ui.HealthFill = UIKit.New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Good, Corner = 6, Parent = hpTrack })
	UIKit.Label({ Text = "HEALTH", TextSize = 10, TextColor3 = T.Sub, Position = UDim2.fromOffset(84, 70), Size = UDim2.fromOffset(100, 12), Parent = pp })

	-- weapon panel (bottom-right on PC, bottom-centre on touch)
	local wp = UIKit.New("Frame", {
		AnchorPoint = touch and Vector2.new(0.5, 1) or Vector2.new(1, 1),
		Position = touch and UDim2.new(0.5, 0, 1, -12) or UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(touch and 280 or 320, touch and 70 or 140),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.15,
		Corner = 10,
		Parent = hud,
	})
	ui.WeaponName = UIKit.Label({ Text = "", TextSize = 14, TextColor3 = T.Sub, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 18), Parent = wp })
	ui.Ammo = UIKit.Label({ Text = "", Font = UIKit.FontBlack, TextSize = touch and 28 or 40, Position = UDim2.fromOffset(14, 26), Size = UDim2.new(0.6, 0, 0, touch and 34 or 44), Parent = wp })
	ui.Reserve = UIKit.Label({ Text = "", TextSize = 16, TextColor3 = T.Sub, Position = UDim2.new(0.6, 0, 0, touch and 34 or 40), Size = UDim2.new(0.4, -14, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, Parent = wp })
	ui.Mode = UIKit.Label({ Text = "", TextSize = 11, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0.5, -14, 0, 16), Parent = wp })
	ui.Slots = {}
	if not touch then
		for i, slot in ipairs({ "Primary", "Secondary", "Melee" }) do
			local s = UIKit.Label({
				Text = "",
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundTransparency = 0,
				BackgroundColor3 = T.Panel2,
				Position = UDim2.new((i - 1) / 3, i == 1 and 14 or 4, 1, -44),
				Size = UDim2.new(1 / 3, -18, 0, 32),
				Corner = 6,
				Parent = wp,
			})
			ui.Slots[slot] = s
		end
	end

	-- crosshair
	local ch = UIKit.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2, 2), Parent = hud })
	ui.Crosshair = ch
	ui.CrossLines = {}
	for i = 1, 4 do
		ui.CrossLines[i] = UIKit.New("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = ch }, {
			UIKit.New("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.5 }),
		})
	end
	ui.CrossDot = UIKit.New("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 3), Parent = ch })
	-- hit marker
	ui.HitMarker = UIKit.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 34), Visible = false, Parent = hud })
	for i, a in ipairs({ 45, 135, 225, 315 }) do
		local r = math.rad(a)
		UIKit.New("Frame", {
			Name = "L" .. i,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(r) * 11, 0.5, math.sin(r) * 11),
			Size = UDim2.fromOffset(10, 2),
			Rotation = a,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = ui.HitMarker,
		})
	end
	-- reload bar
	ui.ReloadBar = UIKit.New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 34), Size = UDim2.fromOffset(120, 6), BackgroundColor3 = T.Panel3, Corner = 3, Visible = false, Parent = hud })
	ui.ReloadFill = UIKit.New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, Corner = 3, Parent = ui.ReloadBar })
	UIKit.Label({ Text = "RELOADING", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 14), Parent = ui.ReloadBar })

	-- damage direction indicators
	ui.DamageRoot = UIKit.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(260, 260), Parent = hud })

	-- kill feed (top-right, below Roblox's own buttons)
	ui.KillFeed = UIKit.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 60), Size = UDim2.fromOffset(380, 200), Parent = hud })
	UIKit.New("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = ui.KillFeed })

	-- centre messages
	ui.BigText = UIKit.Label({ Text = "", Font = UIKit.FontBlack, TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(800, 60), Parent = hud })
	ui.SubText = UIKit.Label({ Text = "", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.32, 44), Size = UDim2.fromOffset(800, 26), Parent = hud })
	ui.Protection = UIKit.Label({ Text = "SPAWN PROTECTION", TextSize = 14, Font = UIKit.FontBlack, TextColor3 = Color3.fromRGB(140, 220, 255), TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 60), Size = UDim2.fromOffset(300, 20), Visible = false, Parent = hud })
	ui.ShopHint = UIKit.Label({
		Text = touch and "In spawn: tap SHOP to change weapons" or "In spawn: press B to open the weapon shop",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.3,
		BackgroundColor3 = T.Panel,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, touch and -96 or -30),
		Size = UDim2.fromOffset(380, 30),
		Corner = 8,
		Visible = false,
		Parent = hud,
	})

	-- death screen
	ui.Death = UIKit.New("Frame", { BackgroundColor3 = Color3.fromRGB(60, 0, 0), BackgroundTransparency = 0.65, Size = UDim2.fromScale(1, 1), Visible = false, Parent = hud })
	ui.DeathTitle = UIKit.Label({ Text = "ELIMINATED", Font = UIKit.FontBlack, TextSize = 52, TextColor3 = T.Bad, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(700, 60), Parent = ui.Death })
	ui.DeathBy = UIKit.Label({ Text = "", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.38, 50), Size = UDim2.fromOffset(700, 28), Parent = ui.Death })
	ui.DeathTimer = UIKit.Label({ Text = "", TextSize = 16, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.38, 84), Size = UDim2.fromOffset(700, 22), Parent = ui.Death })

	-- scoreboard
	local sb = UIKit.New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 460), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.05, Corner = 12, Visible = false, Parent = hud })
	ui.Scoreboard = sb
	ui.ScoreTitle = UIKit.Label({ Text = "SCOREBOARD", Font = UIKit.FontBlack, TextSize = 20, Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 26), Parent = sb })
	ui.ScoreCols = {}
	for i, team in ipairs({ "Red", "Blue" }) do
		local col = UIKit.New("Frame", { BackgroundColor3 = T.Panel2, Position = UDim2.new((i - 1) * 0.5, i == 1 and 16 or 8, 0, 50), Size = UDim2.new(0.5, -24, 1, -66), Corner = 8, Parent = sb })
		UIKit.New("Frame", { BackgroundColor3 = teamColor(team), Size = UDim2.new(1, 0, 0, 3), BorderSizePixel = 0, Parent = col })
		UIKit.Label({ Text = Config.Teams[team].Name:upper(), TextSize = 14, Font = UIKit.FontBlack, TextColor3 = teamColor(team), Position = UDim2.fromOffset(12, 8), Size = UDim2.new(0.6, 0, 0, 20), Parent = col })
		UIKit.Label({ Text = "K      D", TextSize = 12, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.6, 0, 0, 10), Size = UDim2.new(0.4, -14, 0, 18), Parent = col })
		local rows = UIKit.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34), Parent = col })
		UIKit.New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rows })
		ui.ScoreCols[team] = rows
	end

	-- sniper scope (circle cut-out made with a huge UIStroke)
	scopeGui = UIKit.Screen("Scope", 4, true)
	scopeGui.Enabled = false
	local ring = UIKit.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.9), Corner = UDim.new(0.5, 0), Parent = scopeGui })
	UIKit.New("UIAspectRatioConstraint", { AspectRatio = 1, Parent = ring })
	-- the stroke fills the corners between the circle and its square; big frames cover the rest
	UIKit.New("UIStroke", { Thickness = 400, Color = Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ring })
	for _, f in ipairs({
		{ Vector2.new(1, 0.5), UDim2.new(0, 1, 0.5, 0), UDim2.fromOffset(4000, 8000) },
		{ Vector2.new(0, 0.5), UDim2.new(1, -1, 0.5, 0), UDim2.fromOffset(4000, 8000) },
		{ Vector2.new(0.5, 1), UDim2.new(0.5, 0, 0, 1), UDim2.new(1, 0, 0, 4000) },
		{ Vector2.new(0.5, 0), UDim2.new(0.5, 0, 1, -1), UDim2.new(1, 0, 0, 4000) },
	}) do
		UIKit.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = f[1], Position = f[2], Size = f[3], Parent = ring })
	end
	UIKit.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2), Parent = ring })
	UIKit.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 2, 1, 0), Parent = ring })
	UIKit.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(255, 60, 60), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4), Corner = 2, Parent = ring })
end

-- UPDATERS -----------------------------------------------------------------------------

local function refreshScoreboard()
	local m = ClientState.Match
	if not m or not m.Roster then
		return
	end
	for team, rows in pairs(ui.ScoreCols) do
		for _, c in ipairs(rows:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local list = {}
		for _, r in ipairs(m.Roster) do
			if r.Team == team then
				table.insert(list, r)
			end
		end
		table.sort(list, function(a, b)
			if a.Kills ~= b.Kills then
				return a.Kills > b.Kills
			end
			return a.Deaths < b.Deaths
		end)
		for i, r in ipairs(list) do
			local row = UIKit.New("Frame", { LayoutOrder = i, BackgroundColor3 = r.UserId == player.UserId and T.Panel3 or T.Panel2, BackgroundTransparency = 0, Size = UDim2.new(1, 0, 0, 28), Parent = rows })
			UIKit.Label({ Text = r.Name, TextSize = 14, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.6, -12, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
			UIKit.Label({ Text = string.format("%d     %d", r.Kills, r.Deaths), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, -14, 1, 0), Parent = row })
		end
	end
	ui.ScoreTitle.Text = string.format("SCOREBOARD  -  %s", (m.MapName or ""):upper())
end

function HUDController.SetScoreboard(open: boolean)
	scoreboardOpen = open
	if ui.Scoreboard then
		ui.Scoreboard.Visible = open and ClientState.InMatch
		if open then
			refreshScoreboard()
		end
	end
end

local function refreshMatch()
	local m = ClientState.Match
	if not m or not ClientState.InMatch then
		return
	end
	ui.RedScore.Text = tostring(m.RedKills or 0)
	ui.BlueScore.Text = tostring(m.BlueKills or 0)
	ui.RedCount.Text = string.format("RED  ·  %d PLAYERS", m.Red or 0)
	ui.BlueCount.Text = string.format("BLUE  ·  %d PLAYERS", m.Blue or 0)
	local team = ClientState.Team()
	ui.TeamPill.Text = team and Config.Teams[team].Name:upper() or "NO TEAM"
	ui.TeamPill.BackgroundColor3 = teamColor(team)
	if m.State ~= lastState then
		if m.State == "Live" and lastState == "Warmup" then
			Sounds.Play("MatchStart")
			ui.BigText.Text = "FIGHT!"
			ui.SubText.Text = "Most kills in 10 minutes wins"
			task.delay(2, function()
				if ClientState.Match and ClientState.Match.State == "Live" then
					ui.BigText.Text = ""
					ui.SubText.Text = ""
				end
			end)
		end
		lastState = m.State
	end
	if scoreboardOpen then
		refreshScoreboard()
	end
end

local function refreshWeapon()
	local info = WeaponController.GetInfo()
	local w = info.Weapon
	if not info.Armed or not w then
		ui.WeaponName.Text = ""
		ui.Ammo.Text = ""
		ui.Reserve.Text = ""
		ui.Mode.Text = ""
	else
		ui.WeaponName.Text = w.Name:upper()
		if w.MagSize then
			ui.Ammo.Text = tostring(info.Mag or 0)
			ui.Ammo.TextColor3 = (info.Mag or 0) <= math.ceil(w.MagSize * 0.2) and T.Bad or T.Text
			ui.Reserve.Text = "/ " .. tostring(info.Reserve or 0)
		else
			ui.Ammo.Text = "∞"
			ui.Ammo.TextColor3 = T.Text
			ui.Reserve.Text = "MELEE"
		end
		if w.AltFire == "Burst" then
			ui.Mode.Text = info.Burst and "BURST (RMB)" or "SEMI (RMB: BURST)"
		elseif w.ScopeLevels then
			ui.Mode.Text = "RMB: SCOPE"
		elseif w.FireMode == "Melee" then
			ui.Mode.Text = "LMB SLASH · RMB STAB"
		else
			ui.Mode.Text = w.FireMode:upper()
		end
	end
	for i, slot in ipairs({ "Primary", "Secondary", "Melee" }) do
		local label = ui.Slots[slot]
		if label then
			local id = info.Loadout and info.Loadout[slot]
			local wd = id and WeaponData.Get(id)
			label.Text = string.format("%d  %s", i, wd and wd.Name or "-")
			label.BackgroundColor3 = (info.Slot == slot) and T.Accent or T.Panel2
			label.TextColor3 = (info.Slot == slot) and Color3.new(0, 0, 0) or (wd and T.Text or T.Sub)
		end
	end
end

local function addKillFeed(entry)
	local row = UIKit.New("Frame", { BackgroundColor3 = T.Panel, BackgroundTransparency = 0.2, Size = UDim2.fromOffset(380, 28), Corner = 6, Parent = ui.KillFeed })
	local involved = entry.Killer == player.DisplayName or entry.Victim == player.DisplayName
	if involved then
		UIKit.New("UIStroke", { Color = T.Accent, Thickness = 1, Parent = row })
	end
	UIKit.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), Parent = row })
	UIKit.New("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = row })
	local function part(text, color, order, size)
		local l = UIKit.Label({ Text = text, TextSize = size or 14, TextColor3 = color, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), LayoutOrder = order, Parent = row })
		return l
	end
	part(entry.Killer, teamColor(entry.KillerTeam), 1)
	part("[" .. tostring(entry.Weapon) .. "]", T.Sub, 2, 12)
	if entry.Headshot then
		part("HS", T.Gold, 3, 12)
	end
	part(entry.Victim, teamColor(entry.VictimTeam), 4)
	task.delay(6, function()
		row:Destroy()
	end)
	local children = {}
	for _, c in ipairs(ui.KillFeed:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(children, c)
		end
	end
	if #children > 6 then
		children[1]:Destroy()
	end
end

local function showHitMarker(info)
	local color = info.Killed and T.Bad or (info.Headshot and T.Gold or Color3.new(1, 1, 1))
	for _, l in ipairs(ui.HitMarker:GetChildren()) do
		l.BackgroundColor3 = color
	end
	ui.HitMarker.Visible = true
	ui.HitMarker.Size = UDim2.fromOffset(44, 44)
	UIKit.Tween(ui.HitMarker, 0.15, { Size = UDim2.fromOffset(30, 30) })
	local token = os.clock()
	ui.HitMarker:SetAttribute("Token", token)
	task.delay(info.Killed and 0.4 or 0.2, function()
		if ui.HitMarker:GetAttribute("Token") == token then
			ui.HitMarker.Visible = false
		end
	end)
	if info.Killed then
		Sounds.Play("KillConfirm")
	elseif info.Melee then
		Sounds.Play("KnifeHit")
	else
		Sounds.Play(info.Headshot and "HeadshotMarker" or "HitMarker")
	end
end

local function showDamage(fromPos: Vector3, amount: number)
	Sounds.Play("Hurt", nil, { Volume = 0.6 })
	if typeof(fromPos) ~= "Vector3" then
		return
	end
	local camCF = camera.CFrame
	local look = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
	local to = Vector3.new(fromPos.X - camCF.Position.X, 0, fromPos.Z - camCF.Position.Z)
	if look.Magnitude < 0.01 or to.Magnitude < 0.01 then
		return
	end
	look, to = look.Unit, to.Unit
	local angle = math.deg(math.atan2(look:Cross(to).Y, look:Dot(to)))
	local r = math.rad(-angle - 90)
	local ind = UIKit.New("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.cos(r) * 110, 0.5, math.sin(r) * 110),
		Size = UDim2.fromOffset(60, 8),
		Rotation = math.deg(r) + 90,
		BackgroundColor3 = T.Bad,
		BackgroundTransparency = math.clamp(0.6 - amount / 100, 0, 0.6),
		Corner = 4,
		Parent = ui.DamageRoot,
	})
	UIKit.Tween(ind, 1, { BackgroundTransparency = 1 })
	task.delay(1, function()
		ind:Destroy()
	end)
end

local function updateCrosshair()
	local s = ClientState.Settings
	local color = ClientState.CrosshairColors[s.CrosshairColor] or Color3.new(1, 1, 1)
	local info = WeaponController.GetInfo()
	local w = info.Weapon
	local spread = WeaponController.GetSpread()
	local pxPerDeg = (camera.ViewportSize.Y / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * math.rad(1)
	local gap = s.CrosshairGap + math.min(spread * pxPerDeg * 0.9, 90)
	local len, thick = s.CrosshairSize, s.CrosshairThickness
	local sniperHip = w and w.Category == "Sniper"
	local show = info.Armed and not CameraController.IsCinematic() and WeaponController.GetScopeLevel() == 0
	ui.Crosshair.Visible = show
	local lines = ui.CrossLines
	local positions = {
		{ UDim2.fromOffset(0, -(gap + len / 2)), UDim2.fromOffset(thick, len) },
		{ UDim2.fromOffset(0, gap + len / 2), UDim2.fromOffset(thick, len) },
		{ UDim2.fromOffset(-(gap + len / 2), 0), UDim2.fromOffset(len, thick) },
		{ UDim2.fromOffset(gap + len / 2, 0), UDim2.fromOffset(len, thick) },
	}
	for i, l in ipairs(lines) do
		l.Position = UDim2.fromScale(0.5, 0.5) + positions[i][1]
		l.Size = positions[i][2]
		l.BackgroundColor3 = color
		l.Visible = not sniperHip
	end
	ui.CrossDot.Visible = s.CrosshairDot or sniperHip
	ui.CrossDot.BackgroundColor3 = color
	ui.CrossDot.Size = UDim2.fromOffset(thick + 1, thick + 1)
	scopeGui.Enabled = info.Armed and WeaponController.GetScopeLevel() > 0 and not CameraController.IsCinematic()
end

local function frame()
	local inMatch = ClientState.InMatch and not CameraController.IsCinematic()
	hud.Enabled = inMatch
	ui.ShopButton.Visible = ClientState.InMatch
	ui.ScoreButton.Visible = ClientState.InMatch
	ui.GearButton.Visible = ClientState.InMatch
	if not inMatch then
		scopeGui.Enabled = false
		return
	end
	local m = ClientState.Match
	local remaining = m and (m.EndsAt or 0) - workspace:GetServerTimeNow() or 0
	if m and m.State == "Warmup" then
		ui.Timer.Text = Util.FormatTime(Config.Match.Duration)
		ui.Phase.Text = "WARMUP"
		local n = math.max(0, math.ceil(remaining))
		ui.BigText.Text = "MATCH STARTS IN " .. n
		ui.SubText.Text = "Change your loadout in the spawn now"
		if n ~= lastCountdown and n > 0 then
			lastCountdown = n
			Sounds.Play("CountdownTick")
		end
	elseif m and m.State == "Live" then
		ui.Timer.Text = Util.FormatTime(remaining)
		ui.Timer.TextColor3 = remaining <= 30 and T.Bad or T.Text
		ui.Phase.Text = "TEAM DEATHMATCH"
		lastCountdown = -1
	else
		ui.Timer.Text = "0:00"
		ui.Phase.Text = m and m.State and m.State:upper() or ""
	end

	-- health
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hp = hum and math.max(0, math.ceil(hum.Health)) or 0
	local maxHp = hum and hum.MaxHealth or 100
	ui.HealthText.Text = tostring(hp)
	ui.HealthFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	ui.HealthFill.BackgroundColor3 = hp > 60 and T.Good or (hp > 25 and T.Gold or T.Bad)
	ui.HealthText.TextColor3 = hp > 25 and T.Text or T.Bad
	ui.Kills.Text = "KILLS " .. tostring(player:GetAttribute("Kills") or 0)
	ui.Deaths.Text = "DEATHS " .. tostring(player:GetAttribute("Deaths") or 0)

	-- protection, shop hint, reload
	local prot = player:GetAttribute("ProtectedUntil")
	ui.Protection.Visible = type(prot) == "number" and workspace:GetServerTimeNow() < prot
	ui.ShopHint.Visible = WeaponShopUI.InSpawn() and not ClientState.IsMenuOpen("WeaponShop")
	local info = WeaponController.GetInfo()
	ui.ReloadBar.Visible = info.Reloading
	ui.ReloadFill.Size = UDim2.fromScale(info.ReloadProgress, 1)
	ui.ShopButton.BackgroundColor3 = WeaponShopUI.InSpawn() and T.Accent or Color3.fromRGB(18, 20, 26)
	ui.ShopButton.TextColor3 = WeaponShopUI.InSpawn() and Color3.new(0, 0, 0) or T.Sub

	-- death screen
	local dead = not hum or hum.Health <= 0
	ui.Death.Visible = dead and deathInfo ~= nil
	if ui.Death.Visible then
		local left = math.max(0, math.ceil(deathInfo.RespawnAt - os.clock()))
		ui.DeathTimer.Text = (m and m.State == "Live") and ("Respawning in " .. left) or ""
	end

	updateCrosshair()
end

function HUDController.Init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	buildTopbar()
	buildHud()
	hud.Enabled = false

	ClientState.MatchChanged:Connect(refreshMatch)
	WeaponController.Changed:Connect(refreshWeapon)
	player:GetAttributeChangedSignal("Team"):Connect(refreshMatch)

	Net.Event("HitConfirm").OnClientEvent:Connect(function(info)
		if type(info) == "table" then
			showHitMarker(info)
		end
	end)
	Net.Event("Damaged").OnClientEvent:Connect(showDamage)
	Net.Event("KillFeed").OnClientEvent:Connect(function(entry)
		if type(entry) == "table" then
			addKillFeed(entry)
		end
	end)
	Net.Event("Died").OnClientEvent:Connect(function(info)
		deathInfo = { RespawnAt = os.clock() + Config.Match.RespawnDelay }
		ui.DeathBy.Text = string.format("Killed by %s with %s%s", info.Killer or "?", info.Weapon or "?", info.Headshot and "  (HEADSHOT)" or "")
		Sounds.Play("Death")
	end)
	Net.Event("Spawned").OnClientEvent:Connect(function(context)
		if context == "Match" then
			Sounds.Play("Respawn")
		end
		deathInfo = nil
	end)
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid
		if hum then
			hum.Died:Connect(function()
				if not deathInfo then
					deathInfo = { RespawnAt = os.clock() + Config.Match.RespawnDelay }
					ui.DeathBy.Text = "You died"
				end
			end)
		end
	end)

	InputController.Action:Connect(function(name, began)
		if name == "Scoreboard" and ClientState.InMatch and not ClientState.IsTouch() then
			HUDController.SetScoreboard(began)
		elseif name == "Settings" and began then
			SettingsController.Toggle()
		end
	end)

	RunService.RenderStepped:Connect(frame)
	refreshWeapon()
end

return HUDController
