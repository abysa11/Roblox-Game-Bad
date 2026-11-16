--[[
	ResultsUI
	End-of-match presentation:
	  fade out -> cinematic camera flies to the podium -> 3rd, 2nd, 1st revealed one by one
	  (cards with avatar, name, kills, place, points) -> push-in on the winner -> full ranking ->
	  post-match menu with working RETURN TO LOBBY / PLAY AGAIN buttons.
	Podium music plays throughout. Everyone in the match sees the same results.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local ClientState = require(script.Parent.ClientState)
local UIKit = require(script.Parent.UIKit)
local CameraController = require(script.Parent.CameraController)

local ResultsUI = {}

local T = UIKit.T
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local screen, fade, cardsRow, rankPanel, rankList, menu, menuTimer, menuStatus, youText, title
local lobbyBtn, againBtn
local active = false
local showToken = 0
local music: any = nil -- Sound or sequenced-music handle (both have :Destroy())
local camConn: RBXScriptConnection? = nil
local postEndsAt = 0

local PLACE_COLORS = { T.Gold, T.Silver, T.Bronze }
local PLACE_NAMES = { "1ST", "2ND", "3RD" }

local function build()
	screen = UIKit.Screen("ResultsUI", 25, true)
	screen.Enabled = false
	fade = UIKit.New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = screen })

	title = UIKit.Label({ Text = "MATCH OVER", Font = UIKit.FontBlack, TextSize = 44, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(800, 50), Parent = screen })
	youText = UIKit.Label({ Text = "", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(800, 24), Parent = screen })

	cardsRow = UIKit.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(760, 190), Parent = screen })

	rankPanel = UIKit.New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.45, 0), Size = UDim2.fromOffset(330, 380), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.08, Corner = 10, Visible = false, Parent = screen })
	UIKit.Label({ Text = "FULL RESULTS", Font = UIKit.FontBlack, TextSize = 16, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 20), Parent = rankPanel })
	UIKit.Label({ Text = "#   PLAYER                         K    D    PTS", TextSize = 11, TextColor3 = T.Sub, Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 0, 14), Parent = rankPanel })
	rankList = UIKit.New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1, -16, 1, -60), ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = rankPanel })
	UIKit.New("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rankList })

	menu = UIKit.New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 220), BackgroundColor3 = T.Panel, Corner = 12, Stroke = { Color = T.Stroke }, Visible = false, ZIndex = 10, Parent = screen })
	UIKit.New("Frame", { BackgroundColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 3), BorderSizePixel = 0, ZIndex = 10, Parent = menu })
	UIKit.Label({ Text = "WHAT NEXT?", Font = UIKit.FontBlack, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 30), ZIndex = 10, Parent = menu })
	menuTimer = UIKit.Label({ Text = "", TextSize = 14, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 18), ZIndex = 10, Parent = menu })
	-- Modal so the mouse is free in first person
	lobbyBtn = UIKit.Button({ Text = "RETURN TO LOBBY", TextSize = 16, Modal = true, Position = UDim2.fromOffset(24, 90), Size = UDim2.new(0.5, -36, 0, 64), ZIndex = 10, Parent = menu }, function()
		Net.Event("PostMatchChoice"):FireServer("Lobby")
		menuStatus.Text = "Returning to the lobby..."
		lobbyBtn.Active = false
		againBtn.Active = false
	end)
	againBtn = UIKit.Button({ Text = "PLAY AGAIN", TextSize = 16, BackgroundColor3 = T.Accent, TextColor3 = Color3.new(0, 0, 0), Position = UDim2.new(0.5, 12, 0, 90), Size = UDim2.new(0.5, -36, 0, 64), ZIndex = 10, Parent = menu }, function()
		Net.Event("PostMatchChoice"):FireServer("Continue")
		menuStatus.Text = "You'll stay on this map. Waiting for the next match..."
		UIKit.SetButtonColor(againBtn, T.Good)
	end)
	menuStatus = UIKit.Label({ Text = "", TextSize = 13, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -44), Size = UDim2.new(1, 0, 0, 30), TextWrapped = true, ZIndex = 10, Parent = menu })
end

local function makeCard(entry, slotIndex)
	-- slotIndex: 1 = left (2nd), 2 = centre (1st), 3 = right (3rd)
	local big = entry.Place == 1
	local w, h = big and 260 or 220, big and 190 or 160
	local x = ({ 0.17, 0.5, 0.83 })[slotIndex]
	local color = PLACE_COLORS[entry.Place] or T.Text
	local card = UIKit.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(x, 0, 1, 40),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.05,
		Corner = 12,
		Stroke = { Color = color, Thickness = big and 3 or 2 },
		Parent = cardsRow,
	})
	if big then
		UIKit.New("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(70, 56, 20), Color3.fromRGB(20, 22, 28)), Rotation = 90, Parent = card })
	end
	UIKit.Label({ Text = PLACE_NAMES[entry.Place] or "", Font = UIKit.FontBlack, TextSize = big and 30 or 24, TextColor3 = color, Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(90, 34), Parent = card })
	local img = UIKit.New("ImageLabel", { BackgroundColor3 = T.Panel3, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(big and 84 or 70, big and 84 or 70), Corner = UDim.new(1, 0), Image = "", Parent = card })
	UIKit.New("UIStroke", { Color = color, Thickness = 2, Parent = img })
	if entry.UserId and entry.UserId > 0 then
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(entry.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok and img.Parent then
				img.Image = url
			end
		end)
	end
	UIKit.Label({ Text = entry.DisplayName, Font = UIKit.FontBlack, TextSize = big and 22 or 18, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.new(0, 14, 1, big and -92 or -82), Size = UDim2.new(1, -28, 0, 26), Parent = card })
	UIKit.Label({ Text = "@" .. entry.Name, TextSize = 12, TextColor3 = T.Sub, Font = UIKit.FontRegular, Position = UDim2.new(0, 14, 1, big and -66 or -58), Size = UDim2.new(1, -28, 0, 16), Parent = card })
	UIKit.Label({ Text = string.format("%d KILLS  ·  %d DEATHS", entry.Kills, entry.Deaths), TextSize = 14, Position = UDim2.new(0, 14, 1, big and -46 or -40), Size = UDim2.new(1, -28, 0, 18), Parent = card })
	UIKit.Label({ Text = string.format("+%d POINTS", entry.Points or 0), Font = UIKit.FontBlack, TextSize = 15, TextColor3 = T.Good, Position = UDim2.new(0, 14, 1, -24), Size = UDim2.new(1, -28, 0, 18), Parent = card })
	card.Visible = false
	return card
end

local function fillRanking(rankings)
	for _, c in ipairs(rankList:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, r in ipairs(rankings) do
		local mine = r.UserId == player.UserId
		local row = UIKit.New("Frame", { LayoutOrder = i, BackgroundColor3 = mine and T.Panel3 or T.Panel2, Size = UDim2.new(1, -6, 0, 26), Corner = 4, Parent = rankList })
		local teamColor = Config.Teams[r.Team] and Config.Teams[r.Team].Color or T.Text
		UIKit.Label({ Text = tostring(r.Place), TextSize = 13, TextColor3 = PLACE_COLORS[r.Place] or T.Sub, Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(24, 26), Parent = row })
		UIKit.Label({ Text = r.DisplayName, TextSize = 13, TextColor3 = teamColor, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -150, 1, 0), Parent = row })
		UIKit.Label({ Text = string.format("%d    %d    %d", r.Kills, r.Deaths, r.Points or 0), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -118, 0, 0), Size = UDim2.fromOffset(110, 26), Parent = row })
	end
end

local function stopCamera()
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
end

local function runCamera(podium: CFrame, duration: number)
	stopCamera()
	local t0 = os.clock()
	local focusLow = podium * CFrame.new(0, 6, 0)
	local winner = podium * CFrame.new(0, 10, 0)
	camConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local cf
		if t < 4.5 then
			-- sweeping crane shot from the left, rising over the stage
			local e = math.clamp(t / 4.5, 0, 1)
			e = e * e * (3 - 2 * e)
			local angle = math.rad(-55 + 55 * e)
			local radius = 46 - 10 * e
			local pos = podium * CFrame.new(math.sin(angle) * radius, 16 - 6 * e, -math.cos(angle) * radius)
			cf = CFrame.lookAt(pos.Position, focusLow.Position)
		elseif t < duration * 0.62 then
			-- slow dolly along the podium
			local e = math.clamp((t - 4.5) / (duration * 0.62 - 4.5), 0, 1)
			local pos = podium * CFrame.new(-8 + 16 * e, 9, -32)
			cf = CFrame.lookAt(pos.Position, focusLow.Position)
		else
			-- push-in on the winner
			local e = math.clamp((t - duration * 0.62) / (duration * 0.38), 0, 1)
			e = 1 - (1 - e) ^ 3
			local pos = podium * CFrame.new(math.sin(t * 0.3) * 2, 12 - 1 * e, -30 + 12 * e)
			cf = CFrame.lookAt(pos.Position, winner.Position)
		end
		camera.CFrame = cf
		camera.FieldOfView = 60
	end)
end

local function close()
	if not active then
		return
	end
	active = false
	showToken += 1
	stopCamera()
	if music then
		music:Destroy()
		music = nil
	end
	screen.Enabled = false
	menu.Visible = false
	ClientState.SetMenu("Results", false)
	camera.FieldOfView = CameraController.BaseFov
	CameraController.SetCinematic(false)
end

local function show(payload)
	if type(payload) ~= "table" or typeof(payload.PodiumCFrame) ~= "CFrame" then
		return
	end
	showToken += 1
	local token = showToken
	active = true
	screen.Enabled = true
	menu.Visible = false
	rankPanel.Visible = false
	for _, c in ipairs(cardsRow:GetChildren()) do
		c:Destroy()
	end
	title.Text = "MATCH OVER"
	title.TextTransparency = 1
	youText.Text = ""
	lobbyBtn.Active = true
	againBtn.Active = true
	UIKit.SetButtonColor(againBtn, T.Accent)
	menuStatus.Text = ""

	-- your own result line
	for _, r in ipairs(payload.Rankings or {}) do
		if r.UserId == player.UserId then
			youText.Text = string.format("You placed #%d  ·  %d kills  ·  +%d points", r.Place, r.Kills, r.Points or 0)
		end
	end
	fillRanking(payload.Rankings or {})

	Sounds.Play("MatchEnd")
	fade.BackgroundTransparency = 1
	UIKit.Tween(fade, 0.6, { BackgroundTransparency = 0 })
	task.delay(0.65, function()
		if token ~= showToken then
			return
		end
		CameraController.SetCinematic(true)
		ClientState.SetMenu("Results", true)
		runCamera(payload.PodiumCFrame, payload.Duration or Config.Match.ResultsDuration)
		UIKit.Tween(fade, 0.8, { BackgroundTransparency = 1 })
		UIKit.Tween(title, 0.8, { TextTransparency = 0 })
		if music then
			music:Destroy()
		end
		music = Sounds.PlayMusic("Podium")
	end)

	-- cards revealed 3rd -> 2nd -> 1st
	local bySlot = {}
	for _, e in ipairs(payload.Podium or {}) do
		local slotIndex = e.Place == 1 and 2 or (e.Place == 2 and 1 or 3)
		bySlot[e.Place] = makeCard(e, slotIndex)
	end
	for i, place in ipairs({ 3, 2, 1 }) do
		task.delay(1.6 + i * 1.3, function()
			local card = bySlot[place]
			if token ~= showToken or not card then
				return
			end
			card.Visible = true
			local target = card.Position - UDim2.fromOffset(0, 40)
			UIKit.Tween(card, 0.5, { Position = target }, Enum.EasingStyle.Back)
			Sounds.Play("PodiumReveal", nil, { Pitch = place == 1 and 1.4 or 1 })
			if place == 1 then
				title.Text = (payload.Podium[1] and payload.Podium[1].DisplayName or "") .. " WINS!"
				title.TextColor3 = T.Gold
				Sounds.Play("KillConfirm", nil, { Pitch = 1.2 })
			end
		end)
	end
	task.delay(6.5, function()
		if token == showToken then
			rankPanel.Visible = true
		end
	end)
	if #(payload.Podium or {}) == 0 then
		title.Text = "MATCH OVER - NO PLAYERS"
	end
end

local function showMenu(info)
	if not active or type(info) ~= "table" then
		return
	end
	postEndsAt = info.EndsAt or (workspace:GetServerTimeNow() + Config.Match.PostMatchChoiceDuration)
	menu.Visible = true
	menu.Position = UDim2.fromScale(0.5, 0.42)
end

function ResultsUI.Init()
	build()
	Net.Event("Results").OnClientEvent:Connect(show)
	Net.Event("PostMatchPrompt").OnClientEvent:Connect(showMenu)
	ClientState.MatchChanged:Connect(function(m)
		if active and (not ClientState.InMatch or (m and (m.State == "Warmup" or m.State == "Live"))) then
			close()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if active and menu.Visible then
			local left = math.max(0, math.ceil(postEndsAt - workspace:GetServerTimeNow()))
			menuTimer.Text = string.format("Next match on this map starts in %ds  ·  undecided players stay", left)
		end
	end)
	player.CharacterAdded:Connect(function()
		-- returning to the lobby spawns a new character: make sure the cinematic is over
		if active and not ClientState.InMatch then
			close()
		end
	end)
end

return ResultsUI
