--[[
	SpawnManager
	Owns character spawning for the whole server (CharacterAutoLoads is off).
	Main wires ResolveSpawn so a character appears either in the lobby or at the correct team
	base of the player's match. Also handles spawn protection, team vests and ragdoll deaths.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local SpawnManager = {}

-- Set by Main. Returns (CFrame, context) where context is "Lobby" | "Match".
SpawnManager.ResolveSpawn = function(_player: Player): (CFrame?, string)
	return CFrame.new(0, 10, 0), "Lobby"
end

local spawnHooks = {}
local deathHooks = {}

function SpawnManager.OnSpawned(fn)
	table.insert(spawnHooks, fn)
end

function SpawnManager.OnDied(fn)
	table.insert(deathHooks, fn)
end

local respawnTokens: { [Player]: number } = {}

local pendingSpawn: { [Player]: { CFrame: CFrame?, Context: string } } = {}

function SpawnManager.Spawn(player: Player)
	respawnTokens[player] = (respawnTokens[player] or 0) + 1
	local token = respawnTokens[player]
	if not player.Parent then
		return
	end
	local spawnCf, spawnContext = SpawnManager.ResolveSpawn(player)
	pendingSpawn[player] = { CFrame = spawnCf, Context = spawnContext }
	task.spawn(function()
		-- With StreamingEnabled the floor must reach the client before the character does,
		-- otherwise it can fall through (or hang in empty space) for a moment.
		if spawnCf then
			pcall(function()
				player:RequestStreamAroundAsync(spawnCf.Position, 3)
			end)
		end
		if respawnTokens[player] ~= token or not player.Parent then
			return
		end
		local ok, err = pcall(function()
			player:LoadCharacter()
		end)
		if not ok then
			warn("[Spawn] LoadCharacter failed for " .. player.Name .. ": " .. tostring(err))
		end
	end)
end

-- Respawn after a delay unless something else spawns/moves the player first.
function SpawnManager.ScheduleRespawn(player: Player, delay: number)
	respawnTokens[player] = (respawnTokens[player] or 0) + 1
	local token = respawnTokens[player]
	task.delay(delay, function()
		if respawnTokens[player] == token and player.Parent then
			SpawnManager.Spawn(player)
		end
	end)
end

function SpawnManager.CancelRespawn(player: Player)
	respawnTokens[player] = (respawnTokens[player] or 0) + 1
end

function SpawnManager.IsProtected(player: Player): boolean
	local untilT = player:GetAttribute("ProtectedUntil")
	return type(untilT) == "number" and workspace:GetServerTimeNow() < untilT
end

function SpawnManager.EndProtection(player: Player)
	if player:GetAttribute("ProtectedUntil") then
		player:SetAttribute("ProtectedUntil", nil)
		local char = player.Character
		local ff = char and char:FindFirstChild("SpawnShield")
		if ff then
			ff:Destroy()
		end
	end
end

function SpawnManager.GiveProtection(player: Player, seconds: number)
	local char = player.Character
	if not char then
		return
	end
	local ff = Instance.new("ForceField")
	ff.Name = "SpawnShield"
	ff.Visible = true
	ff.Parent = char
	local untilT = workspace:GetServerTimeNow() + seconds
	player:SetAttribute("ProtectedUntil", untilT)
	task.delay(seconds, function()
		if player:GetAttribute("ProtectedUntil") == untilT then
			SpawnManager.EndProtection(player)
		end
	end)
end

local function addTeamVest(character: Model, color: Color3)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local function piece(size, offset)
		local p = Instance.new("Part")
		p.Name = "TeamVest"
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = torso.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = torso
		w.Part1 = p
		w.Parent = p
		p.Parent = character
	end
	local s = torso.Size
	piece(Vector3.new(s.X + 0.12, s.Y * 0.45, s.Z + 0.12), CFrame.new(0, s.Y * 0.05, 0))
	local arm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm")
	if arm and arm:IsA("BasePart") then
		local p = Instance.new("Part")
		p.Name = "TeamBand"
		p.Size = Vector3.new(arm.Size.X + 0.1, 0.35, arm.Size.Z + 0.1)
		p.Color = color
		p.Material = Enum.Material.Neon
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = arm.CFrame * CFrame.new(0, arm.Size.Y * 0.2, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0 = arm
		w.Part1 = p
		w.Parent = p
		p.Parent = character
	end
end

function SpawnManager.Ragdoll(character: Model, impulse: Vector3?)
	for _, m in ipairs(character:GetDescendants()) do
		if m:IsA("Motor6D") and m.Name ~= "Root" and m.Name ~= "RootJoint" and m.Part0 and m.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = "RagA0"
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagA1"
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.UpperAngle = 55
			bs.TwistLimitsEnabled = true
			bs.TwistLowerAngle = -40
			bs.TwistUpperAngle = 40
			bs.Parent = m.Part0
			m.Enabled = false
		end
	end
	for _, p in ipairs(character:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and not p:GetAttribute("Role") then
			p.CanCollide = true
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.CanCollide = false
		if impulse then
			root:ApplyImpulse(impulse * root.AssemblyMass)
		end
	end
end

local RunService = game:GetService("RunService")

-- CharacterAdded fires before the engine has parented the character and placed it on its
-- default spawn. Moving it any earlier gets overridden (that left players hanging in the air),
-- so wait until it is in the world and one frame has passed.
local function waitUntilPlaced(character: Model)
	local deadline = os.clock() + 5
	while not character:IsDescendantOf(workspace) and os.clock() < deadline do
		character.AncestryChanged:Wait()
	end
	RunService.Heartbeat:Wait()
end

local function placeCharacter(character: Model, cf: CFrame)
	local target = cf + Vector3.new(0, 3, 0)
	character:PivotTo(target)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart
	if not humanoid or not root then
		return
	end
	local pending = pendingSpawn[player]
	pendingSpawn[player] = nil
	local cf, context
	if pending then
		cf, context = pending.CFrame, pending.Context
	else
		cf, context = SpawnManager.ResolveSpawn(player)
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid.WalkSpeed = Config.Player.BaseWalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Player.JumpPower
	player:SetAttribute("BaseWalkSpeed", Config.Player.BaseWalkSpeed)
	player:SetAttribute("Context", context)
	if cf then
		placeCharacter(character, cf) -- early placement (helps streaming) ...
		waitUntilPlaced(character)
		if player.Character ~= character then
			return
		end
		placeCharacter(character, cf) -- ... and the one that sticks
	end

	if context == "Match" then
		local team = player:GetAttribute("Team")
		local info = team and Config.Teams[team]
		if info then
			addTeamVest(character, info.Color)
		end
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		SpawnManager.GiveProtection(player, Config.Match.SpawnProtection)
	else
		player:SetAttribute("ProtectedUntil", nil)
	end

	humanoid.Died:Connect(function()
		SpawnManager.Ragdoll(character, nil)
		for _, fn in ipairs(deathHooks) do
			task.spawn(fn, player, character, humanoid)
		end
	end)

	for _, fn in ipairs(spawnHooks) do
		task.spawn(fn, player, character, context)
	end
	Net.Event("Spawned"):FireClient(player, context)
end

function SpawnManager.Init()
	Players.CharacterAutoLoads = false
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		respawnTokens[player] = nil
		pendingSpawn[player] = nil
	end)
end

return SpawnManager
