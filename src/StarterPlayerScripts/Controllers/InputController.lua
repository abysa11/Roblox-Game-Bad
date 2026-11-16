--[[
	InputController
	Turns keyboard / mouse / gamepad / touch-button input into named actions so gameplay code
	never cares which device is used.

	Actions (fired with began = true/false):
	  Fire, Alt (scope / burst toggle / knife stab), Reload, Slot1, Slot2, Slot3,
	  NextWeapon, PrevWeapon, LastWeapon, Shop, Scoreboard, Settings
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)
local ClientState = require(script.Parent.ClientState)

local InputController = {}
InputController.Action = Signal.new()

local KEYS = {
	[Enum.KeyCode.R] = "Reload",
	[Enum.KeyCode.One] = "Slot1",
	[Enum.KeyCode.Two] = "Slot2",
	[Enum.KeyCode.Three] = "Slot3",
	[Enum.KeyCode.Q] = "LastWeapon",
	[Enum.KeyCode.B] = "Shop",
	[Enum.KeyCode.Tab] = "Scoreboard",
	[Enum.KeyCode.P] = "Settings",
	-- gamepad
	[Enum.KeyCode.ButtonR2] = "Fire",
	[Enum.KeyCode.ButtonL2] = "Alt",
	[Enum.KeyCode.ButtonX] = "Reload",
	[Enum.KeyCode.ButtonY] = "NextWeapon",
	[Enum.KeyCode.DPadUp] = "Slot3",
	[Enum.KeyCode.ButtonSelect] = "Scoreboard",
	[Enum.KeyCode.DPadDown] = "Shop",
}

-- Actions that should work even when a menu is open
local MENU_SAFE = { Shop = true, Settings = true, Scoreboard = true }

local held = {}

function InputController.Trigger(name: string, began: boolean)
	if began then
		if held[name] then
			return
		end
		held[name] = true
	else
		if not held[name] then
			return
		end
		held[name] = nil
	end
	if began and ClientState.IsMenuOpen() and not MENU_SAFE[name] then
		held[name] = nil
		return
	end
	InputController.Action:Fire(name, began)
end

function InputController.IsHeld(name: string): boolean
	return held[name] == true
end

function InputController.ReleaseAll()
	for name in pairs(held) do
		InputController.Trigger(name, false)
	end
end

function InputController.Init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not processed then
				InputController.Trigger("Fire", true)
			end
			return
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			if not processed then
				InputController.Trigger("Alt", true)
			end
			return
		end
		local action = KEYS[input.KeyCode]
		if action and (not processed or action == "Scoreboard") then
			InputController.Trigger(action, true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			InputController.Trigger("Fire", false)
			return
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			InputController.Trigger("Alt", false)
			return
		end
		local action = KEYS[input.KeyCode]
		if action then
			InputController.Trigger(action, false)
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processed and ClientState.InMatch then
			local name = input.Position.Z > 0 and "PrevWeapon" or "NextWeapon"
			InputController.Action:Fire(name, true)
		end
	end)
	ClientState.MenuChanged:Connect(function(_, open)
		if open then
			-- stop firing etc. when a menu pops up
			for name in pairs(held) do
				if not MENU_SAFE[name] then
					InputController.Trigger(name, false)
				end
			end
		end
	end)
end

return InputController
