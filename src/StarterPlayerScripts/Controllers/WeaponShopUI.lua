--[[
	WeaponShopUI
	Buy menu (B on keyboard, shop button on touch). Only opens inside your team's spawn while
	the match is in Warmup/Live, and closes itself when you leave the spawn, die or the match
	ends. Rules: one pistol + (one rifle OR one sniper). The knife is always carried.
	The server re-validates everything in SetLoadout.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local WeaponData = require(ReplicatedStorage.WeaponModules.WeaponData)
local WeaponModels = require(ReplicatedStorage.WeaponModules.WeaponModels)
local ClientState = require(script.Parent.ClientState)
local UIKit = require(script.Parent.UIKit)
local Toast = require(script.Parent.Toast)
local InputController = require(script.Parent.InputController)
local WeaponController = require(script.Parent.WeaponController)

local WeaponShopUI = {}
WeaponShopUI.SpawnStateChanged = require(ReplicatedStorage.Shared.Signal).new()

local T = UIKit.T
local player = Players.LocalPlayer

local screen, window
local pending = { Primary = nil, Secondary = "USP" }
local category = "Pistol"
local selectedId = "USP"
local ui = {}
local inSpawn = false

function WeaponShopUI.InSpawn(): boolean
	return inSpawn
end

local function computeInSpawn(): boolean
	local m = ClientState.Match
	if not ClientState.InMatch or not m or (m.State ~= "Live" and m.State ~= "Warmup") then
		return false
	end
	local team = ClientState.Team()
	local zone = team and m.SpawnZones and m.SpawnZones[team]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not zone or not root or not hum or hum.Health <= 0 then
		return false
	end
	return Util.InBox(root.Position, zone.CFrame, zone.Size + Vector3.new(2, 6, 2))
end

local function isPendingSelected(id)
	return pending.Primary == id or pending.Secondary == id
end

local function refreshLoadoutBar()
	local p = pending.Primary and WeaponData.Get(pending.Primary)
	local s = WeaponData.Get(pending.Secondary or "USP")
	ui.PrimaryText.Text = "PRIMARY:  " .. (p and p.Name or "NONE")
	ui.SecondaryText.Text = "PISTOL:  " .. s.Name
	ui.KnifeText.Text = "MELEE:  KNIFE (always)"
	ui.ClearPrimary.Visible = pending.Primary ~= nil
end

local function refreshDetail()
	local w = WeaponData.Get(selectedId)
	if not w then
		return
	end
	ui.Name.Text = w.Name
	ui.Category.Text = w.Category:upper() .. (w.FireMode and ("  /  " .. w.FireMode:upper()) or "")
	ui.Desc.Text = w.Description
	local skins = ClientState.Profile and ClientState.Profile.EquippedSkins or {}
	ui.SetPreview(WeaponModels.BuildStatic(w.Id, skins[w.Id]), WeaponModels.GetLength(w.Id))
	for _, c in ipairs(ui.StatRows) do
		c:Destroy()
	end
	ui.StatRows = {}
	for i, stat in ipairs(WeaponData.DisplayStats(w)) do
		local row = UIKit.StatBar(ui.Stats, stat[1], stat[2], (i - 1) * 24, 0.6)
		table.insert(ui.StatRows, row)
	end
	if w.MagSize then
		ui.Specs.Text = string.format("DMG %d  |  %d RPM  |  MAG %d / %d  |  RELOAD %.1fs  |  SPEED %d%%", w.Damage, w.RPM, w.MagSize, w.Reserve, w.ReloadTime, math.floor(w.MoveSpeed * 100 + 0.5))
	else
		ui.Specs.Text = ""
	end
	local selected = isPendingSelected(w.Id)
	ui.Select.Text = selected and "SELECTED" or "SELECT"
	UIKit.SetButtonColor(ui.Select, selected and T.Good or T.Accent)
	ui.Select.TextColor3 = Color3.new(0, 0, 0)
end

local function refreshList()
	for _, c in ipairs(ui.Cards) do
		c:Destroy()
	end
	ui.Cards = {}
	for _, cat in ipairs(WeaponData.Categories) do
		UIKit.SetButtonColor(ui.Tabs[cat.Id], cat.Id == category and T.Accent or T.Panel3)
		ui.Tabs[cat.Id].TextColor3 = cat.Id == category and Color3.new(0, 0, 0) or T.Text
		if cat.Id == category then
			for i, id in ipairs(cat.Weapons) do
				local w = WeaponData.Get(id)
				local card = UIKit.Button({
					Name = id,
					Position = UDim2.fromOffset(0, (i - 1) * 66),
					Size = UDim2.new(1, 0, 0, 58),
					BackgroundColor3 = id == selectedId and T.Panel3 or T.Panel2,
					Parent = ui.List,
				}, function()
					selectedId = id
					refreshList()
					refreshDetail()
				end)
				UIKit.Label({ Text = w.Name, TextSize = 18, Font = UIKit.FontBlack, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -110, 0, 22), Parent = card })
				UIKit.Label({ Text = string.format("%d DMG  ·  %d RPM  ·  %d RND", w.Damage, w.RPM, w.MagSize), TextSize = 12, TextColor3 = T.Sub, Font = UIKit.FontRegular, Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -110, 0, 16), Parent = card })
				if isPendingSelected(id) then
					UIKit.Label({
						Text = "SELECTED",
						TextSize = 11,
						TextColor3 = Color3.new(0, 0, 0),
						TextXAlignment = Enum.TextXAlignment.Center,
						BackgroundTransparency = 0,
						BackgroundColor3 = T.Good,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(84, 22),
						Corner = 6,
						Parent = card,
					})
				end
				if id == selectedId then
					UIKit.New("Frame", { BackgroundColor3 = T.Accent, Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(4, 8), BorderSizePixel = 0, Parent = card })
				end
				table.insert(ui.Cards, card)
			end
		end
	end
end

local function build()
	local close
	screen, window, close = UIKit.Window("WeaponShop", "WEAPON SHOP", UDim2.fromOffset(980, 620), 30)
	ui.Cards, ui.StatRows, ui.Tabs = {}, {}, {}

	UIKit.Label({
		Text = "Pick one pistol and one rifle OR sniper. Your knife is always equipped.",
		TextSize = 13,
		TextColor3 = T.Sub,
		Font = UIKit.FontRegular,
		Position = UDim2.fromOffset(20, 44),
		Size = UDim2.new(1, -40, 0, 18),
		Parent = window,
	})

	-- tabs
	for i, cat in ipairs(WeaponData.Categories) do
		ui.Tabs[cat.Id] = UIKit.Button({
			Text = cat.Label,
			TextSize = 14,
			Position = UDim2.fromOffset(20 + (i - 1) * 118, 72),
			Size = UDim2.fromOffset(110, 36),
			Parent = window,
		}, function()
			category = cat.Id
			selectedId = cat.Weapons[1]
			refreshList()
			refreshDetail()
		end)
	end

	ui.List = UIKit.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 120), Size = UDim2.fromOffset(340, 380), Parent = window })

	-- detail panel
	local detail = UIKit.New("Frame", { BackgroundColor3 = T.Panel2, Position = UDim2.fromOffset(380, 72), Size = UDim2.new(1, -400, 0, 428), Corner = 10, Parent = window })
	local vp, setModel = UIKit.Preview(detail, { Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 170) })
	ui.Preview = vp
	ui.SetPreview = setModel
	ui.Name = UIKit.Label({ Text = "", Font = UIKit.FontBlack, TextSize = 26, Position = UDim2.fromOffset(16, 190), Size = UDim2.new(0.6, 0, 0, 30), Parent = detail })
	ui.Category = UIKit.Label({ Text = "", TextSize = 12, TextColor3 = T.Accent, Position = UDim2.fromOffset(16, 220), Size = UDim2.new(0.6, 0, 0, 16), Parent = detail })
	ui.Desc = UIKit.Label({ Text = "", TextSize = 13, TextWrapped = true, Font = UIKit.FontRegular, TextColor3 = T.Sub, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(16, 240), Size = UDim2.new(0.5, -20, 0, 90), Parent = detail })
	ui.Stats = UIKit.New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 236), Size = UDim2.new(0.5, -16, 0, 150), Parent = detail })
	ui.Specs = UIKit.Label({ Text = "", TextSize = 12, TextColor3 = T.Text, Font = UIKit.FontRegular, Position = UDim2.new(0, 16, 1, -36), Size = UDim2.new(1, -200, 0, 24), Parent = detail })
	ui.Select = UIKit.Button({
		Text = "SELECT",
		BackgroundColor3 = T.Accent,
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 16,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -12),
		Size = UDim2.fromOffset(160, 40),
		Parent = detail,
	}, function()
		local w = WeaponData.Get(selectedId)
		if w.Category == "Pistol" then
			pending.Secondary = w.Id
		elseif pending.Primary == w.Id then
			pending.Primary = nil -- toggle off
		else
			pending.Primary = w.Id -- replaces any rifle OR sniper (only one primary)
		end
		refreshList()
		refreshDetail()
		refreshLoadoutBar()
	end)

	-- loadout bar
	local bar = UIKit.New("Frame", { BackgroundColor3 = T.Bg, Position = UDim2.new(0, 20, 1, -100), Size = UDim2.new(1, -40, 0, 80), Corner = 10, Stroke = { Color = T.Stroke }, Parent = window })
	UIKit.Label({ Text = "CURRENT LOADOUT", TextSize = 11, TextColor3 = T.Sub, Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(200, 14), Parent = bar })
	ui.PrimaryText = UIKit.Label({ Text = "", TextSize = 15, Position = UDim2.fromOffset(16, 28), Size = UDim2.fromOffset(250, 20), Parent = bar })
	ui.SecondaryText = UIKit.Label({ Text = "", TextSize = 15, Position = UDim2.fromOffset(16, 50), Size = UDim2.fromOffset(250, 20), Parent = bar })
	ui.KnifeText = UIKit.Label({ Text = "", TextSize = 13, TextColor3 = T.Sub, Position = UDim2.fromOffset(280, 50), Size = UDim2.fromOffset(220, 20), Parent = bar })
	ui.ClearPrimary = UIKit.Button({ Text = "CLEAR PRIMARY", TextSize = 12, Position = UDim2.fromOffset(280, 22), Size = UDim2.fromOffset(130, 26), Parent = bar }, function()
		pending.Primary = nil
		refreshList()
		refreshDetail()
		refreshLoadoutBar()
	end)
	ui.Status = UIKit.Label({ Text = "", TextSize = 13, TextColor3 = T.Sub, Position = UDim2.new(1, -470, 0, 10), Size = UDim2.fromOffset(240, 60), TextWrapped = true, Parent = bar })
	ui.Confirm = UIKit.Button({
		Text = "CONFIRM LOADOUT",
		BackgroundColor3 = T.Good,
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 16,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(210, 50),
		Parent = bar,
	}, function()
		ui.Status.Text = "Confirming..."
		local ok, res = pcall(function()
			return Net.Function("SetLoadout"):InvokeServer({ Primary = pending.Primary, Secondary = pending.Secondary })
		end)
		if ok and type(res) == "table" and res.Ok then
			Sounds.Play("UIBuy")
			Toast.Show(res.Message or "Loadout confirmed.", "success")
			WeaponShopUI.Close()
		else
			local msg = (ok and type(res) == "table" and res.Message) or "Could not confirm loadout."
			ui.Status.Text = msg
			Toast.Show(msg, "error")
		end
	end)
	close.Activated:Connect(function()
		WeaponShopUI.Close()
	end)
end

function WeaponShopUI.Open()
	if not inSpawn then
		Toast.Show("You can only open the weapon shop inside your team's spawn.", "error")
		return
	end
	if not screen then
		build()
	end
	local info = WeaponController.GetInfo()
	pending.Primary = info.Loadout and info.Loadout.Primary or nil
	pending.Secondary = info.Loadout and info.Loadout.Secondary or "USP"
	ui.Status.Text = ""
	refreshList()
	refreshDetail()
	refreshLoadoutBar()
	screen.Enabled = true
	ClientState.SetMenu("WeaponShop", true)
end

function WeaponShopUI.Close()
	if screen and screen.Enabled then
		screen.Enabled = false
	end
	ClientState.SetMenu("WeaponShop", false)
end

function WeaponShopUI.Toggle()
	if screen and screen.Enabled then
		WeaponShopUI.Close()
	else
		WeaponShopUI.Open()
	end
end

function WeaponShopUI.Init()
	InputController.Action:Connect(function(name, began)
		if name == "Shop" and began and ClientState.InMatch then
			WeaponShopUI.Toggle()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local now = computeInSpawn()
			if now ~= inSpawn then
				inSpawn = now
				WeaponShopUI.SpawnStateChanged:Fire(inSpawn)
			end
			if not inSpawn and screen and screen.Enabled then
				WeaponShopUI.Close()
				Toast.Show("Weapon shop closed - you left your spawn.", "info")
			end
		end
	end)
	ClientState.MatchChanged:Connect(function(m)
		if screen and screen.Enabled and (not ClientState.InMatch or not m or (m.State ~= "Live" and m.State ~= "Warmup")) then
			WeaponShopUI.Close()
		end
	end)
end

return WeaponShopUI
