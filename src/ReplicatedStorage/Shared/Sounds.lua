--[[
	Sounds
	Every sound in the game is built from the 11 audio files that ship inside the Roblox client
	(content/sounds, checked against the client file manifest), so there is never a dead
	asset link. Each sound is one or more layers: a file, cut to a short slice (Start/Len),
	re-pitched and shaped with distortion / EQ / reverb. Layers can be delayed to build
	clicks, racks and jingles. The podium music is a sequenced track (melody, bass, drums)
	played from the same files.

	To use your own licensed audio instead, put ids in Config.Sounds.Overrides
	(e.g. Overrides = { AK_Shot = "rbxassetid://123" }) or Config.Sounds.PodiumMusicId.

	Client-only playback (sounds are cosmetic; the server never needs them).
]]

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Config = require(script.Parent.Config)

local Sounds = {}

local S = "rbxasset://sounds/"
-- The complete list of built-in sounds available to games (tests fail on anything else).
Sounds.BuiltIn = {
	EXPLOSION = S .. "impact_explosion_03.mp3",
	LAND = S .. "action_jump_land.mp3",
	STEP = S .. "action_footsteps_plastic.mp3",
	GETUP = S .. "action_get_up.mp3",
	JUMP = S .. "action_jump.mp3",
	SWIM = S .. "action_swim.mp3",
	WATER = S .. "impact_water.mp3",
	FALL = S .. "action_falling.ogg",
	OOF = S .. "oof.ogg",
	OUCH = S .. "ouch.ogg",
	TICK = S .. "volume_slider.ogg",
}
local F = Sounds.BuiltIn

local function L(id, vol, speed, opts)
	local layer = { Id = id, Volume = vol, Speed = speed }
	if opts then
		for k, v in pairs(opts) do
			layer[k] = v
		end
	end
	return layer
end

-- semitones -> playback speed
local function st(n)
	return 2 ^ (n / 12)
end

--[[ Layer fields: Id, Volume, Speed, Start (seconds into the file), Len (real seconds to keep),
     Delay, Dist (distortion 0..1), Low / High (EQ gain dB), Reverb (bool) ]]
Sounds.Defs = {
	-- GUNSHOTS: the explosion sample cut short and pitched up gives a punchy report;
	-- every weapon gets its own pitch, length, saturation and tone.
	USP_Shot = { -- suppressed: dull "thup"
		L(F.EXPLOSION, 0.4, 3.3, { Len = 0.16, Low = 5, High = -20 }),
		L(F.LAND, 0.35, 2.6, { Len = 0.12, High = -8 }),
		L(F.STEP, 0.18, 2.4, { Len = 0.05, Delay = 0.03 }),
	},
	Glock_Shot = { -- light, snappy pistol
		L(F.EXPLOSION, 0.6, 2.75, { Len = 0.2, Dist = 0.45, High = 3 }),
		L(F.STEP, 0.25, 2.2, { Len = 0.05 }),
	},
	Deagle_Shot = { -- heavy hand cannon with a tail
		L(F.EXPLOSION, 1, 1.5, { Len = 0.55, Dist = 0.7, Low = 6, Reverb = true }),
		L(F.LAND, 0.6, 1.2, { Len = 0.25 }),
	},
	AK_Shot = { -- loud, gritty rifle
		L(F.EXPLOSION, 0.9, 1.95, { Len = 0.3, Dist = 0.65, Low = 4 }),
		L(F.STEP, 0.2, 1.8, { Len = 0.05 }),
	},
	M4_Shot = { -- suppressed rifle: muffled but deeper than the USP
		L(F.EXPLOSION, 0.5, 2.45, { Len = 0.2, Low = 4, High = -15 }),
		L(F.LAND, 0.32, 2, { Len = 0.12 }),
	},
	SCAR_Shot = { -- sharper, brighter rifle
		L(F.EXPLOSION, 0.8, 2.25, { Len = 0.25, Dist = 0.55, High = 4 }),
		L(F.STEP, 0.22, 2.4, { Len = 0.04 }),
	},
	AWP_Shot = { -- huge sniper boom with echo
		L(F.EXPLOSION, 1, 1.12, { Len = 1.3, Dist = 0.8, Low = 8, Reverb = true }),
		L(F.LAND, 0.7, 0.8, { Len = 0.4 }),
	},

	-- WEAPON HANDLING
	DryFire = { L(F.STEP, 0.5, 2.6, { Len = 0.06 }) },
	MagOut = { L(F.STEP, 0.6, 1.4, { Len = 0.12 }), L(F.GETUP, 0.25, 1.8, { Len = 0.2, Delay = 0.05 }) },
	MagIn = { L(F.LAND, 0.6, 2.4, { Len = 0.15 }), L(F.STEP, 0.45, 2, { Len = 0.07, Delay = 0.06 }) },
	BoltRack = { L(F.STEP, 0.7, 1.1, { Len = 0.1 }), L(F.STEP, 0.6, 1.6, { Len = 0.08, Delay = 0.14 }) },
	EquipGun = { L(F.GETUP, 0.45, 1.6, { Len = 0.3 }), L(F.STEP, 0.3, 2, { Len = 0.06, Delay = 0.2 }) },
	EquipKnife = { L(F.JUMP, 0.4, 2.2, { Len = 0.25, High = 4 }), L(F.STEP, 0.3, 3, { Len = 0.05, Delay = 0.12 }) },
	KnifeSlash = { L(F.JUMP, 0.6, 1.7, { Len = 0.3, High = 5 }), L(F.SWIM, 0.25, 2.5, { Len = 0.25 }) },
	KnifeStab = { L(F.JUMP, 0.7, 1.2, { Len = 0.35 }), L(F.LAND, 0.35, 1.8, { Len = 0.15, Delay = 0.12 }) },
	KnifeHit = { L(F.LAND, 0.7, 1.6, { Len = 0.2, Dist = 0.3 }) },
	ScopeIn = { L(F.STEP, 0.35, 3, { Len = 0.05 }), L(F.TICK, 0.2, 0.7) },

	-- FEEDBACK
	HitMarker = { L(F.TICK, 0.5, 1.8) },
	HeadshotMarker = { L(F.TICK, 0.6, 2.4), L(F.TICK, 0.4, 3, { Delay = 0.05 }) },
	KillConfirm = {
		L(F.TICK, 0.6, st(0) * 1.5),
		L(F.TICK, 0.6, st(4) * 1.5, { Delay = 0.07 }),
		L(F.TICK, 0.5, st(7) * 1.5, { Delay = 0.14 }),
		L(F.LAND, 0.4, 0.9, { Len = 0.2 }),
	},
	Hurt = { L(F.OUCH, 0.45, 1) },
	Death = { L(F.OOF, 0.6, 1) },
	Respawn = { L(F.GETUP, 0.6, 1), L(F.TICK, 0.3, 1.2, { Delay = 0.1 }), L(F.TICK, 0.3, 1.8, { Delay = 0.2 }) },
	BulletImpact = { L(F.STEP, 0.3, 3, { Len = 0.06 }), L(F.LAND, 0.2, 3, { Len = 0.08 }) },
	FleshImpact = { L(F.LAND, 0.35, 2.2, { Len = 0.1, High = -6 }), L(F.WATER, 0.12, 3, { Len = 0.08 }) },

	-- MATCH FLOW
	CountdownTick = { L(F.TICK, 0.6, 1) },
	MatchStart = {
		L(F.TICK, 0.6, st(0)),
		L(F.TICK, 0.6, st(4), { Delay = 0.1 }),
		L(F.TICK, 0.6, st(7), { Delay = 0.2 }),
		L(F.TICK, 0.7, st(12), { Delay = 0.3 }),
		L(F.EXPLOSION, 0.3, 1.2, { Len = 0.8, Low = 6, Delay = 0.3 }),
	},
	MatchEnd = {
		L(F.TICK, 0.6, st(12)),
		L(F.TICK, 0.6, st(7), { Delay = 0.15 }),
		L(F.TICK, 0.6, st(4), { Delay = 0.3 }),
		L(F.TICK, 0.7, st(0), { Delay = 0.45 }),
		L(F.LAND, 0.5, 0.7, { Delay = 0.45 }),
	},
	PodiumReveal = { L(F.TICK, 0.6, 0.75), L(F.LAND, 0.5, 0.8, { Len = 0.3 }) },

	-- UI
	UIClick = { L(F.TICK, 0.4, 1.4) },
	UIHover = { L(F.TICK, 0.1, 2.2) },
	UIBuy = { L(F.TICK, 0.5, st(0) * 1.5), L(F.TICK, 0.5, st(7) * 1.5, { Delay = 0.08 }) },
	UIError = { L(F.TICK, 0.5, 0.6), L(F.TICK, 0.5, 0.5, { Delay = 0.1 }) },
	QueueJoin = { L(F.TICK, 0.4, st(0) * 1.2), L(F.TICK, 0.4, st(5) * 1.2, { Delay = 0.08 }) },
}

--[[ Music: step sequencer (eighth notes). Melody / bass are re-pitched TICK notes, kick is the
     landing thump and the hi-hat a tiny slice of the footstep. ]]
Sounds.Music = {
	Podium = {
		BPM = 116,
		Steps = 32, -- 4 bars of 8 eighth notes, looped
		Melody = { -- { step, semitone }
			{ 0, 0 }, { 2, 4 }, { 3, 7 }, { 4, 12 }, { 6, 7 },
			{ 8, 9 }, { 10, 7 }, { 11, 4 }, { 12, 5 }, { 13, 4 }, { 14, 2 },
			{ 16, 4 }, { 18, 7 }, { 19, 12 }, { 20, 16 }, { 22, 14 }, { 23, 12 },
			{ 24, 11 }, { 25, 7 }, { 26, 14 }, { 28, 12 },
		},
		Bass = { { 0, 0 }, { 4, 0 }, { 8, 5 }, { 12, 5 }, { 16, 9 }, { 20, 9 }, { 24, 7 }, { 28, 7 } },
		MelodyBase = 1.3,
		BassBase = 0.33,
		Kick = { 0, 4, 8, 12, 16, 20, 24, 28 },
		Hat = { 2, 6, 10, 14, 18, 22, 26, 30 },
	},
}

local groups = {}

local function getGroup(name)
	if groups[name] then
		return groups[name]
	end
	local master = SoundService:FindFirstChild("Master")
	if not master then
		master = Instance.new("SoundGroup")
		master.Name = "Master"
		master.Parent = SoundService
	end
	if name == "Master" then
		groups.Master = master
		return master
	end
	local g = master:FindFirstChild(name)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = master
	end
	groups[name] = g
	return g
end
Sounds.GetGroup = getGroup

local function buildLayer(layer, parent: Instance, volumeScale: number, pitch: number, group: string)
	local s = Instance.new("Sound")
	s.SoundId = layer.Id
	s.Volume = (layer.Volume or 0.5) * volumeScale
	s.PlaybackSpeed = (layer.Speed or 1) * pitch
	s.TimePosition = layer.Start or 0
	s.SoundGroup = getGroup(group)
	s.RollOffMaxDistance = 420
	s.RollOffMinDistance = 12
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	if layer.Dist then
		local d = Instance.new("DistortionSoundEffect")
		d.Level = layer.Dist
		d.Parent = s
	end
	if layer.Low or layer.High then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = layer.Low or 0
		eq.MidGain = 0
		eq.HighGain = layer.High or 0
		eq.Parent = s
	end
	if layer.Reverb then
		local r = Instance.new("ReverbSoundEffect")
		r.DecayTime = 1.4
		r.WetLevel = -6
		r.Parent = s
	end
	s.Parent = parent
	return s
end

local function playLayer(layer, parent: Instance, volumeScale: number, pitch: number, group: string)
	local function go()
		if not parent.Parent and parent ~= SoundService then
			return
		end
		local s = buildLayer(layer, parent, volumeScale, pitch, group)
		s:Play()
		if layer.Len then
			-- fade the slice out quickly instead of a hard cut (avoids clicks)
			task.delay(layer.Len, function()
				if s.Parent then
					s.Volume *= 0.35
					task.delay(0.03, function()
						s:Destroy()
					end)
				end
			end)
		end
		Debris:AddItem(s, 4)
	end
	if layer.Delay and layer.Delay > 0 then
		task.delay(layer.Delay, go)
	else
		go()
	end
end

-- Play a named sound. `where` may be nil (2D UI/first person), a BasePart/Attachment, or a Vector3.
function Sounds.Play(name: string, where: any?, opts: { Volume: number?, Pitch: number? }?)
	local override = Config.Sounds.Overrides[name]
	local layers = override and { L(override, 0.8, 1) } or Sounds.Defs[name]
	if not layers then
		warn("[Sounds] unknown sound " .. tostring(name))
		return
	end
	local parent: Instance = SoundService
	if typeof(where) == "Vector3" then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = where
		holder.Parent = workspace.Terrain
		Debris:AddItem(holder, 3)
		parent = holder
	elseif typeof(where) == "Instance" then
		parent = where
	end
	local pitch = (opts and opts.Pitch or 1) * (0.96 + math.random() * 0.08)
	local vol = opts and opts.Volume or 1
	for _, layer in ipairs(layers) do
		playLayer(layer, parent, vol, pitch, "SFX")
	end
end

-- Music handle: call :Destroy() to stop.
function Sounds.PlayMusic(name: string)
	if name == "Podium" and Config.Sounds.PodiumMusicId then
		local s = Instance.new("Sound")
		s.Name = "Music_" .. name
		s.SoundId = Config.Sounds.PodiumMusicId
		s.Volume = 0.6
		s.Looped = true
		s.SoundGroup = getGroup("Music")
		s.Parent = SoundService
		s:Play()
		return s
	end
	local song = Sounds.Music[name]
	if not song then
		return nil
	end
	local handle = { Playing = true }
	function handle:Destroy()
		self.Playing = false
	end
	handle.Stop = handle.Destroy
	local melodyAt, bassAt, kickAt, hatAt = {}, {}, {}, {}
	for _, n in ipairs(song.Melody) do
		melodyAt[n[1]] = n[2]
	end
	for _, n in ipairs(song.Bass) do
		bassAt[n[1]] = n[2]
	end
	for _, s in ipairs(song.Kick) do
		kickAt[s] = true
	end
	for _, s in ipairs(song.Hat) do
		hatAt[s] = true
	end
	local stepTime = 60 / song.BPM / 2
	task.spawn(function()
		local step = 0
		local nextAt = os.clock()
		while handle.Playing do
			local i = step % song.Steps
			if melodyAt[i] then
				playLayer(L(F.TICK, 0.45, song.MelodyBase * st(melodyAt[i])), SoundService, 1, 1, "Music")
			end
			if bassAt[i] then
				playLayer(L(F.TICK, 0.6, song.BassBase * st(bassAt[i]), { Low = 6, High = -10 }), SoundService, 1, 1, "Music")
			end
			if kickAt[i] then
				playLayer(L(F.LAND, 0.55, 0.75, { Len = 0.18, Low = 8 }), SoundService, 1, 1, "Music")
			end
			if hatAt[i] then
				playLayer(L(F.STEP, 0.15, 3.2, { Len = 0.035, High = 6 }), SoundService, 1, 1, "Music")
			end
			step += 1
			nextAt += stepTime
			task.wait(math.max(0, nextAt - os.clock()))
		end
	end)
	return handle
end

function Sounds.SetVolumes(master: number, music: number, sfx: number)
	getGroup("Master").Volume = master
	getGroup("Music").Volume = music
	getGroup("SFX").Volume = sfx
end

return Sounds
