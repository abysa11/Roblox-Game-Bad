--[[
	PodiumBuilder
	Builds the results stage (gold / silver / bronze) for a match and puts the top-3 players'
	avatars on it with emotes, a crown and confetti for the winner.

	Stage space: avatars face -Z, the results camera looks at the stage from -Z.
	2nd place is on the viewer's left (+X), 3rd on the viewer's right (-X).
]]

local Players = game:GetService("Players")

local Builder = require(script.Parent.Builder)

local PodiumBuilder = {}
PodiumBuilder.__index = PodiumBuilder

local GOLD = Color3.fromRGB(255, 196, 46)
local SILVER = Color3.fromRGB(200, 208, 220)
local BRONZE = Color3.fromRGB(205, 127, 50)

PodiumBuilder.Slots = {
	{ Place = 1, X = 0, Height = 7, Color = GOLD },
	{ Place = 2, X = 11, Height = 4.8, Color = SILVER },
	{ Place = 3, X = -11, Height = 3.2, Color = BRONZE },
}

-- R15 / R6 emotes from Roblox's default Animate script.
local EMOTES = {
	R15 = { "rbxassetid://507770677", "rbxassetid://507770239", "rbxassetid://507771019" }, -- cheer, wave, dance
	R6 = { "rbxassetid://129423030", "rbxassetid://128777973", "rbxassetid://182435998" },
}

function PodiumBuilder.new(parent: Instance, cf: CFrame)
	local self = setmetatable({}, PodiumBuilder)
	local model = Instance.new("Model")
	model.Name = "Podium"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	self.Model = model
	self.CFrame = cf
	self.Avatars = {}
	self.Effects = {}

	local b = Builder.new(model, cf)
	-- stage
	b:Box(-34, -2, -18, 34, 0, 16, Color3.fromRGB(22, 24, 30), Enum.Material.SmoothPlastic)
	b:Box(-34, 0, -18, 34, 0.15, -17.4, Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
	-- backdrop
	local back = b:Box(-34, 0, 14, 34, 30, 16, Color3.fromRGB(16, 18, 24), Enum.Material.SmoothPlastic)
	-- Front (-Z) is the face toward the results camera
	local title = Builder.Label(back, Enum.NormalId.Front, "MATCH RESULTS", Color3.fromRGB(255, 255, 255), { PixelsPerStud = 8 })
	title.Size = UDim2.fromScale(1, 0.18)
	title.Position = UDim2.fromScale(0, 0.06)
	for i = -3, 3 do
		b:Box(i * 10 - 0.3, 0, 13.6, i * 10 + 0.3, 30, 14, Color3.fromRGB(255, 140, 40), Enum.Material.Neon, { CastShadow = false })
	end

	-- blocks
	for _, slot in ipairs(PodiumBuilder.Slots) do
		local block = b:Box(slot.X - 5, 0, -5, slot.X + 5, slot.Height, 5, slot.Color, Enum.Material.Foil, { Reflectance = 0.2 })
		block.Name = "Place" .. slot.Place
		local front = b:Box(slot.X - 5.05, 0, -5.05, slot.X + 5.05, slot.Height, -5, slot.Color, Enum.Material.Neon, { Transparency = 0.85, CastShadow = false })
		Builder.Label(front, Enum.NormalId.Front, tostring(slot.Place), Color3.fromRGB(20, 20, 24), { PixelsPerStud = 10 })
		local trim = b:Box(slot.X - 5.2, slot.Height - 0.2, -5.2, slot.X + 5.2, slot.Height + 0.1, 5.2, Color3.fromRGB(255, 255, 255), Enum.Material.Neon, { CastShadow = false })
		trim.Transparency = 0.4
	end

	-- lights
	b:Light(Vector3.new(0, 22, -12), GOLD, 40, 3, true)
	b:Light(Vector3.new(14, 18, -12), Color3.fromRGB(180, 200, 255), 30, 1.5)
	b:Light(Vector3.new(-14, 18, -12), Color3.fromRGB(255, 180, 120), 30, 1.5)

	-- confetti emitters (enabled during the show)
	for _, x in ipairs({ -20, 0, 20 }) do
		local p = b:Part(Vector3.new(1, 1, 1), Vector3.new(x, 26, -2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.Rate = 60
		e.Lifetime = NumberRange.new(3, 5)
		e.Speed = NumberRange.new(4, 10)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0, -6, 0)
		e.Drag = 1
		e.RotSpeed = NumberRange.new(-200, 200)
		e.Rotation = NumberRange.new(0, 360)
		e.Size = NumberSequence.new(0.35)
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 255, 120)),
		})
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Parent = p
		table.insert(self.Effects, e)
	end
	return self
end

local function stripModel(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ForceField") or d.Name == "EquippedWeapon" then
			d:Destroy()
		elseif d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and (d.Name == "RagA0" or d.Name == "RagA1")) then
			d:Destroy()
		elseif d:IsA("Motor6D") then
			d.Enabled = true
		end
	end
end

local function createAvatar(entry): Model?
	local model
	if entry.UserId and entry.UserId > 0 then
		local ok, result = pcall(function()
			return Players:CreateHumanoidModelFromUserId(entry.UserId)
		end)
		if ok then
			model = result
		end
	end
	if not model then
		local player = Players:GetPlayerByUserId(entry.UserId)
		local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local desc
		if humanoid then
			pcall(function()
				desc = humanoid:GetAppliedDescription()
			end)
		end
		local ok, result = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc or Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		end)
		if ok then
			model = result
		end
	end
	if model then
		stripModel(model)
	end
	return model
end

-- entries: { {Place, UserId, DisplayName, Kills}, ... } (up to 3)
function PodiumBuilder:Show(entries)
	self:Clear()
	for _, entry in ipairs(entries) do
		local slot = PodiumBuilder.Slots[entry.Place]
		if slot then
			task.spawn(function()
				local avatar = createAvatar(entry)
				if not avatar or not self.Model.Parent then
					return
				end
				avatar.Name = "Avatar" .. entry.Place
				local humanoid = avatar:FindFirstChildOfClass("Humanoid")
				local root = avatar:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not humanoid or not root then
					avatar:Destroy()
					return
				end
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
				root.Anchored = true
				local standY = slot.Height + humanoid.HipHeight + root.Size.Y / 2
				-- face the camera (-Z in stage space)
				local cf = self.CFrame * CFrame.new(slot.X, standY, 0) * CFrame.Angles(0, 0, 0)
				avatar:PivotTo(cf)
				avatar.Parent = self.Model
				table.insert(self.Avatars, avatar)

				-- name tag
				local head = avatar:FindFirstChild("Head")
				if head then
					local bb = Instance.new("BillboardGui")
					bb.Size = UDim2.fromOffset(220, 64)
					bb.StudsOffset = Vector3.new(0, 3.2, 0)
					bb.AlwaysOnTop = true
					bb.LightInfluence = 0
					bb.Parent = head
					local name = Instance.new("TextLabel")
					name.BackgroundTransparency = 1
					name.Size = UDim2.new(1, 0, 0.55, 0)
					name.Font = Enum.Font.GothamBlack
					name.TextScaled = true
					name.TextColor3 = slot.Color
					name.TextStrokeTransparency = 0.4
					name.Text = entry.DisplayName
					name.Parent = bb
					local kills = Instance.new("TextLabel")
					kills.BackgroundTransparency = 1
					kills.Position = UDim2.fromScale(0, 0.55)
					kills.Size = UDim2.new(1, 0, 0.45, 0)
					kills.Font = Enum.Font.GothamBold
					kills.TextScaled = true
					kills.TextColor3 = Color3.new(1, 1, 1)
					kills.TextStrokeTransparency = 0.5
					kills.Text = string.format("#%d  -  %d KILLS", entry.Place, entry.Kills)
					kills.Parent = bb
				end

				-- winner extras
				if entry.Place == 1 then
					local hl = Instance.new("Highlight")
					hl.FillTransparency = 0.85
					hl.FillColor = slot.Color
					hl.OutlineColor = slot.Color
					hl.DepthMode = Enum.HighlightDepthMode.Occluded
					hl.Parent = avatar
					if head and head:IsA("BasePart") then
						local crown = Instance.new("Part")
						crown.Name = "Crown"
						crown.Shape = Enum.PartType.Cylinder
						crown.Size = Vector3.new(0.6, 1.5, 1.5)
						crown.Color = slot.Color
						crown.Material = Enum.Material.Neon
						crown.CanCollide = false
						crown.CanQuery = false
						crown.Massless = true
						crown.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.45, 0) * CFrame.Angles(0, 0, math.pi / 2)
						local w = Instance.new("WeldConstraint")
						w.Part0 = head
						w.Part1 = crown
						w.Parent = crown
						crown.Parent = avatar
						local sparkle = Instance.new("Sparkles")
						sparkle.SparkleColor = slot.Color
						sparkle.Parent = crown
					end
				end

				-- emote (falls back to a celebratory hop if the animation can't load)
				local rig = humanoid.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6"
				local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
				local played = false
				pcall(function()
					local anim = Instance.new("Animation")
					anim.AnimationId = EMOTES[rig][entry.Place]
					local track = animator:LoadAnimation(anim)
					track.Looped = true
					track:Play(0.3)
					played = true
				end)
				task.spawn(function()
					local t0 = os.clock()
					while avatar.Parent do
						local t = os.clock() - t0
						local hop = played and 0 or math.max(0, math.sin(t * 5)) * 0.8
						local turn = entry.Place == 1 and math.sin(t * 1.2) * 0.35 or math.sin(t * 0.8 + entry.Place) * 0.12
						root.CFrame = cf * CFrame.new(0, hop, 0) * CFrame.Angles(0, turn, 0)
						task.wait(1 / 20)
					end
				end)
			end)
		end
	end
	for _, e in ipairs(self.Effects) do
		e.Enabled = true
	end
	task.delay(6, function()
		for _, e in ipairs(self.Effects) do
			e.Enabled = false
		end
	end)
end

function PodiumBuilder:Clear()
	for _, a in ipairs(self.Avatars) do
		a:Destroy()
	end
	self.Avatars = {}
	for _, e in ipairs(self.Effects) do
		e.Enabled = false
	end
end

function PodiumBuilder:Destroy()
	self:Clear()
	self.Model:Destroy()
end

return PodiumBuilder
