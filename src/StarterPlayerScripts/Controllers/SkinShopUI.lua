--[[
	SkinShopUI
	Lobby cosmetic shop: browse skins per weapon, live 3D preview, prices and balance,
	purchase confirmation, equip / unequip. The server validates ownership and balance and
	guards against double spending; this UI also blocks repeat clicks while a request runs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local SkinData = require(ReplicatedStorage.Shared.SkinData)
local WeaponData = require(ReplicatedStorage.WeaponModules.WeaponData)
local WeaponModels = require(ReplicatedStorage.WeaponModules.WeaponModels)
local ClientState = require(script.Parent.ClientState)
local UIKit = require(script.Parent.UIKit)
local Toast = require(script.Parent.Toast)

local SkinShopUI = {}

local T = UIKit.T
local screen, window
local ui = {}
local weaponId = "AK47"
local selectedSkin: string? = nil -- nil = default finish
local busy = false

local function profile()
	return ClientState.Profile or { Points = 0, OwnedSkins = {}, EquippedSkins = {} }
end

local function owns(id: string?)
	return id == nil or profile().OwnedSkins[id] == true
end

local function equippedFor(wid: string)
	return profile().EquippedSkins[wid]
end

local function refreshActions()
	local p = profile()
	ui.Points.Text = string.format("%d POINTS", p.Points or 0)
	local skin = selectedSkin and SkinData.Get(selectedSkin)
	local wd = WeaponData.Get(weaponId)
	ui.SkinName.Text = skin and skin.Name or "Factory Finish"
	ui.WeaponLabel.Text = wd.Name:upper()
	ui.Rarity.Text = skin and skin.Rarity:upper() or "DEFAULT"
	ui.Rarity.TextColor3 = skin and SkinData.Rarities[skin.Rarity].Color or T.Sub
	ui.Price.Text = skin and (owns(selectedSkin) and "OWNED" or string.format("%d POINTS", skin.Price)) or "FREE"

	local isEquipped = equippedFor(weaponId) == selectedSkin
	if not owns(selectedSkin) then
		local canAfford = (p.Points or 0) >= skin.Price
		ui.Buy.Visible = true
		ui.Equip.Visible = false
		ui.Buy.Text = canAfford and string.format("BUY  ·  %d", skin.Price) or string.format("NEED %d MORE", skin.Price - (p.Points or 0))
		ui.Buy.Active = canAfford and not busy
		UIKit.SetButtonColor(ui.Buy, canAfford and T.Good or T.Panel3)
		ui.Buy.TextColor3 = canAfford and Color3.new(0, 0, 0) or T.Sub
	else
		ui.Buy.Visible = false
		ui.Equip.Visible = true
		if isEquipped then
			ui.Equip.Text = selectedSkin and "UNEQUIP" or "EQUIPPED"
			ui.Equip.Active = selectedSkin ~= nil and not busy
			UIKit.SetButtonColor(ui.Equip, T.Panel3)
		else
			ui.Equip.Text = "EQUIP"
			ui.Equip.Active = not busy
			UIKit.SetButtonColor(ui.Equip, T.Accent)
		end
	end
end

local function refreshPreview()
	ui.SetPreview(WeaponModels.BuildStatic(weaponId, selectedSkin), WeaponModels.GetLength(weaponId))
end

local function refreshSkins()
	for _, c in ipairs(ui.SkinCards) do
		c:Destroy()
	end
	ui.SkinCards = {}
	local list = { false }
	for _, s in ipairs(SkinData.ForWeapon(weaponId)) do
		table.insert(list, s)
	end
	for i, s in ipairs(list) do
		local id = s and s.Id or nil
		local col, row = (i - 1) % 2, (i - 1) // 2
		local rarityColor = s and SkinData.Rarities[s.Rarity].Color or T.Sub
		local card = UIKit.Button({
			BackgroundColor3 = (id == selectedSkin) and T.Panel3 or T.Panel2,
			Position = UDim2.new(col * 0.5, col == 0 and 0 or 6, 0, row * 80),
			Size = UDim2.new(0.5, -6, 0, 72),
			Parent = ui.SkinGrid,
		}, function()
			selectedSkin = id
			refreshSkins()
			refreshPreview()
			refreshActions()
		end)
		UIKit.New("Frame", { BackgroundColor3 = rarityColor, Size = UDim2.new(1, 0, 0, 3), BorderSizePixel = 0, Parent = card })
		-- colour swatch
		local defaults = WeaponModels.GetDefaults(weaponId)
		UIKit.New("Frame", { BackgroundColor3 = s and s.Body or defaults.Body, Position = UDim2.fromOffset(10, 14), Size = UDim2.fromOffset(22, 22), Corner = 4, Parent = card })
		UIKit.New("Frame", { BackgroundColor3 = s and s.Accent or defaults.Accent, Position = UDim2.fromOffset(10, 40), Size = UDim2.fromOffset(22, 22), Corner = 4, Parent = card })
		UIKit.Label({ Text = s and s.Name or "Factory Finish", TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(42, 12), Size = UDim2.new(1, -50, 0, 18), Parent = card })
		UIKit.Label({ Text = s and s.Rarity:upper() or "DEFAULT", TextSize = 11, TextColor3 = rarityColor, Position = UDim2.fromOffset(42, 32), Size = UDim2.new(1, -50, 0, 14), Parent = card })
		local status
		if equippedFor(weaponId) == id then
			status = "EQUIPPED"
		elseif owns(id) then
			status = "OWNED"
		else
			status = string.format("%d PTS", s.Price)
		end
		UIKit.Label({ Text = status, TextSize = 12, TextColor3 = status == "EQUIPPED" and T.Good or (status == "OWNED" and T.Text or T.Gold), Position = UDim2.fromOffset(42, 48), Size = UDim2.new(1, -50, 0, 16), Parent = card })
		table.insert(ui.SkinCards, card)
	end
	ui.SkinGrid.CanvasSize = UDim2.fromOffset(0, math.ceil(#list / 2) * 80)
end

local function refreshWeapons()
	for wid, btn in pairs(ui.WeaponButtons) do
		UIKit.SetButtonColor(btn, wid == weaponId and T.Accent or T.Panel2)
		btn.TextColor3 = wid == weaponId and Color3.new(0, 0, 0) or T.Text
	end
end

local function refreshAll()
	refreshWeapons()
	refreshSkins()
	refreshPreview()
	refreshActions()
end

local function handleResult(ok, res)
	busy = false
	if ok and type(res) == "table" then
		if res.Profile then
			ClientState.SetProfile(res.Profile)
		end
		Toast.Show(res.Message or "", res.Ok and "success" or "error")
		if res.Ok then
			Sounds.Play("UIBuy")
		end
	else
		Toast.Show("Shop request failed, try again.", "error")
	end
	refreshAll()
end

local function confirmPurchase(skin)
	ui.ConfirmText.Text = string.format("Buy %s for %s?\n\n%d POINTS", skin.Name, WeaponData.Get(skin.Weapon).Name, skin.Price)
	ui.Confirm.Visible = true
	ui.ConfirmSkin = skin.Id
end

local function build()
	local close
	screen, window, close = UIKit.Window("SkinShop", "SKIN SHOP", UDim2.fromOffset(1000, 620), 30)
	ui.SkinCards, ui.WeaponButtons = {}, {}
	ui.Points = UIKit.Label({ Text = "", Font = UIKit.FontBlack, TextSize = 20, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -64, 0, 16), Size = UDim2.fromOffset(260, 28), Parent = window })
	UIKit.Label({ Text = "Cosmetic only - skins never change weapon stats.", TextSize = 13, TextColor3 = T.Sub, Font = UIKit.FontRegular, Position = UDim2.fromOffset(20, 44), Size = UDim2.fromOffset(500, 18), Parent = window })

	-- weapon list
	local list = UIKit.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 74), Size = UDim2.fromOffset(170, 520), Parent = window })
	for i, wid in ipairs(WeaponData.SkinnableOrder) do
		ui.WeaponButtons[wid] = UIKit.Button({ Text = WeaponData.Get(wid).Name, TextSize = 14, Position = UDim2.fromOffset(0, (i - 1) * 50), Size = UDim2.new(1, 0, 0, 44), Parent = list }, function()
			weaponId = wid
			selectedSkin = equippedFor(wid)
			refreshAll()
		end)
	end

	-- preview
	local center = UIKit.New("Frame", { BackgroundColor3 = T.Panel2, Position = UDim2.fromOffset(206, 74), Size = UDim2.fromOffset(400, 520), Corner = 10, Parent = window })
	local _, setModel = UIKit.Preview(center, { Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 300) })
	ui.SetPreview = setModel
	ui.WeaponLabel = UIKit.Label({ Text = "", TextSize = 13, TextColor3 = T.Sub, Position = UDim2.fromOffset(18, 322), Size = UDim2.new(1, -36, 0, 16), Parent = center })
	ui.SkinName = UIKit.Label({ Text = "", Font = UIKit.FontBlack, TextSize = 26, Position = UDim2.fromOffset(18, 340), Size = UDim2.new(1, -36, 0, 32), Parent = center })
	ui.Rarity = UIKit.Label({ Text = "", TextSize = 13, Position = UDim2.fromOffset(18, 374), Size = UDim2.new(1, -36, 0, 18), Parent = center })
	ui.Price = UIKit.Label({ Text = "", TextSize = 18, TextColor3 = T.Gold, Font = UIKit.FontBlack, Position = UDim2.fromOffset(18, 398), Size = UDim2.new(1, -36, 0, 24), Parent = center })
	ui.Buy = UIKit.Button({ Text = "BUY", TextSize = 18, Position = UDim2.new(0, 18, 1, -70), Size = UDim2.new(1, -36, 0, 52), Parent = center }, function()
		if busy or not selectedSkin then
			return
		end
		local skin = SkinData.Get(selectedSkin)
		if skin and (profile().Points or 0) >= skin.Price then
			confirmPurchase(skin)
		end
	end)
	ui.Equip = UIKit.Button({ Text = "EQUIP", TextSize = 18, Position = UDim2.new(0, 18, 1, -70), Size = UDim2.new(1, -36, 0, 52), Parent = center }, function()
		if busy then
			return
		end
		busy = true
		refreshActions()
		local target = selectedSkin
		if equippedFor(weaponId) == selectedSkin then
			target = nil -- unequip -> default finish
		end
		local ok, res = pcall(function()
			return Net.Function("EquipSkin"):InvokeServer(weaponId, target)
		end)
		if target == nil then
			selectedSkin = nil
		end
		handleResult(ok, res)
	end)

	-- skins grid
	UIKit.Label({ Text = "SKINS", TextSize = 13, TextColor3 = T.Sub, Font = UIKit.FontBlack, Position = UDim2.fromOffset(622, 74), Size = UDim2.fromOffset(200, 16), Parent = window })
	ui.SkinGrid = UIKit.New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, Position = UDim2.fromOffset(622, 96), Size = UDim2.fromOffset(358, 498), Parent = window })

	-- confirmation dialog
	ui.Confirm = UIKit.New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 20, Parent = window })
	local box = UIKit.New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 220), BackgroundColor3 = T.Panel, Corner = 12, Stroke = { Color = T.Gold }, ZIndex = 21, Parent = ui.Confirm })
	ui.ConfirmText = UIKit.Label({ Text = "", TextSize = 18, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(20, 20), Size = UDim2.new(1, -40, 0, 110), ZIndex = 22, Parent = box })
	UIKit.Button({ Text = "CANCEL", TextSize = 16, Position = UDim2.new(0, 20, 1, -70), Size = UDim2.new(0.5, -30, 0, 50), ZIndex = 22, Parent = box }, function()
		ui.Confirm.Visible = false
	end)
	ui.ConfirmBuy = UIKit.Button({ Text = "CONFIRM PURCHASE", TextSize = 15, BackgroundColor3 = T.Good, TextColor3 = Color3.new(0, 0, 0), Position = UDim2.new(0.5, 10, 1, -70), Size = UDim2.new(0.5, -30, 0, 50), ZIndex = 22, Parent = box }, function()
		if busy or not ui.ConfirmSkin then
			return
		end
		busy = true
		ui.Confirm.Visible = false
		refreshActions()
		local id = ui.ConfirmSkin
		ui.ConfirmSkin = nil
		local ok, res = pcall(function()
			return Net.Function("BuySkin"):InvokeServer(id)
		end)
		handleResult(ok, res)
	end)

	close.Activated:Connect(function()
		SkinShopUI.Close()
	end)
end

function SkinShopUI.Open()
	if ClientState.InMatch then
		Toast.Show("The skin shop is in the main lobby.", "error")
		return
	end
	if not screen then
		build()
	end
	selectedSkin = equippedFor(weaponId)
	ui.Confirm.Visible = false
	refreshAll()
	screen.Enabled = true
	ClientState.SetMenu("SkinShop", true)
end

function SkinShopUI.Close()
	if screen then
		screen.Enabled = false
	end
	ClientState.SetMenu("SkinShop", false)
end

function SkinShopUI.Init()
	Net.Event("OpenSkinShop").OnClientEvent:Connect(SkinShopUI.Open)
	ClientState.ProfileChanged:Connect(function()
		if screen and screen.Enabled and not busy then
			refreshActions()
		end
	end)
	ClientState.MatchChanged:Connect(function()
		if ClientState.InMatch then
			SkinShopUI.Close()
		end
	end)
end

return SkinShopUI
