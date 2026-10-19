--!strict
-- Original procedural recordings from the frozen Godot sound_bank.gd. Presentation only:
-- never feeds perception, AI or simulation time. Roblox's master volume controls every voice. The player's three volumes (ROBLOX-49:
-- MasterVolume, AmbienceVolume for the room and the birds, CreatureVolume for the flies and the wasp) multiply the mix below, which was
-- tuned and accepted at full volume; setVolumes is called each frame and takes effect at once.
-- The ambient music (ROBLOX-76) is the same kind of thing: scenery, a 64 s loop of its own, never read by perception, the AI or the simulation,
-- and it has no part in the world (no position, no slow motion). Its fourth volume is MusicVolume. Its asset (assets/audio/sill_music.wav) is uploaded and its id is in
-- IDS.music, so it plays; were the id ever empty the voice would not even be made. It ducks while the wasp is on the sill and swells during the mating scene.
local Soundscape = {}
Soundscape.__index = Soundscape
local IDS = {
	room = "rbxassetid://135813320748786", buzz = "rbxassetid://90354950534870",
	takeoff = "rbxassetid://135484013341687", birds = "rbxassetid://105858750316891",
	wasp = "rbxassetid://76049518783466",
	music = "rbxassetid://114531800455832", -- assets/audio/sill_music.wav, uploaded 2026-10-18 by socranates (assets/audio/manifest.json); "" would mean no music, no voice
}
Soundscape.IDS = IDS -- (tests/settings.luau gives the music an id to see its voice)
-- The mix as authored (each voice's own loudness before the player's volumes).
local MIX = { room = 0.09, birds = 0.16, buzz = 0.23, takeoff = 0.22, hum = 0.42, humArriving = 0.32, music = 0.18 }
-- While the wasp is on the sill the music is this share of itself, reached (and left) over about DUCK_S seconds.
local DUCK = 0.4
local DUCK_S = 1.0
-- The mating scene (ROBLOX-89) swells the music to this share of itself over SWELL_S seconds (and back after); the wasp's duck still wins: while it is on the
-- sill the swell is not asked for and the music is at its ducked level.
local SWELL = 1.6
local SWELL_S = 1.0
Soundscape.SWELL, Soundscape.SWELL_S = SWELL, SWELL_S -- (the tests read them)
local function voice(parent: Instance, name: string, volume: number, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = IDS[name]
	s.Volume = volume
	s.Looped = looped
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 80
	s.Parent = parent
	return s
end
-- ROBLOX-100: how the music's recording fared, written once to Output for whoever is looking (Studio, the PC's F9 console): the asset's fetch status from
-- ContentProvider when it has one, and, if the music has still not loaded after MUSIC_LOAD_WARN_S seconds of being asked to play, that too. Nothing on screen.
Soundscape.MUSIC_LOAD_WARN_S = 20
local function reportMusicLoad(music: Sound)
	local okService, provider = pcall(function() return game:GetService("ContentProvider") end)
	if not okService or provider == nil or typeof((provider :: any).PreloadAsync) ~= "function" then return end
	task.spawn(function()
		local ok, err = pcall(function()
			(provider :: any):PreloadAsync({ music }, function(id: string, status: Enum.AssetFetchStatus)
				if status ~= Enum.AssetFetchStatus.Success then
					warn(`[Windowsill] music: {id} did not load ({tostring(status)}); check the asset's moderation and that it is granted to this experience`)
				end
			end)
		end)
		if not ok then warn("[Windowsill] music: the load report failed: " .. tostring(err)) end
	end)
end
function Soundscape.new(parent: Instance): any
	local root = Instance.new("Folder")
	root.Name = "WindowsillAudio"
	root.Parent = parent
	local emitter = Instance.new("Part")
	emitter.Name = "WaspAudio"
	emitter.Anchored = true; emitter.CanCollide = false; emitter.CanTouch = false; emitter.CanQuery = false
	emitter.Transparency = 1; emitter.Size = Vector3.new(0.1, 0.1, 0.1); emitter.Parent = root
	local hum = voice(emitter, "wasp", MIX.hum, true)
	hum.RollOffMinDistance = 16; hum.RollOffMaxDistance = 120
	local music: Sound? = if IDS.music ~= "" then voice(root, "music", MIX.music, true) else nil
	if music ~= nil then reportMusicLoad(music) end
	return setmetatable({ root = root, room = voice(root, "room", MIX.room, true),
		music = music, musicVolume = 1, duck = 1, duckTarget = 1, swell = 1, swellWanted = false, musicAsked = 0, musicWarned = false,
		waspEmitter = emitter, waspHum = hum, master = 1, ambience = 1, creatures = 1,
		birds = voice(root, "birds", MIX.birds, false), slots = {}, elapsed = 0, nextBird = 8 }, Soundscape)
end
-- The mating scene is playing (true) or over (false): the music swells to SWELL of itself over SWELL_S seconds, and comes back. Only music, nothing new: the birds and
-- the room go on as they were. While the wasp ducks the music the swell is ignored (the duck wins).
function Soundscape.setSwell(self: any, on: boolean)
	self.swellWanted = on
end
-- The player's volumes, each 0 to 1 (`music`, the fourth, is 1 when left out).
function Soundscape.setVolumes(self: any, master: number, ambience: number, creatures: number, music: number?)
	self.master, self.ambience, self.creatures = math.clamp(master, 0, 1), math.clamp(ambience, 0, 1), math.clamp(creatures, 0, 1)
	self.musicVolume = math.clamp(music or 1, 0, 1)
end
local function playing(s: Sound, wanted: boolean)
	if wanted then
		-- A recording that has not loaded yet is asked to play once and plays when it has loaded: Play and Resume set Playing at once, so the next frame
		-- asks nothing more. ROBLOX-100: the audit's gate on IsLoaded (ROBLOX-92) is gone; the engine is known to leave IsLoaded false for audio that
		-- loads and plays (devforum 2654049), and the gate then kept the music from ever being asked to play, which is the silence Nathan heard.
		if not s.Playing then s:Resume(); if not s.Playing then s:Play() end end
	elseif s.Playing then s:Pause() end
end
function Soundscape.update(self: any, dt: number, prey: any, daylight: number, paused: boolean, speed: number, muted: boolean)
	local audible = not paused and not muted
	local room, creature = self.master * self.ambience, self.master * self.creatures
	self.room.Volume = MIX.room * room
	self.birds.Volume = MIX.birds * room
	playing(self.room, audible)
	self.room.PlaybackSpeed = speed
	self.birds.PlaybackSpeed = speed
	-- The music: its own volume times the master, ducked toward DUCK while the wasp is here (updateWasp sets the target); it pauses with the
	-- menu and the mute like the rest, and does not follow slow motion.
	self.duck += math.clamp(self.duckTarget - self.duck, -(1 - DUCK) / DUCK_S * dt, (1 - DUCK) / DUCK_S * dt)
	local swellTarget = if self.swellWanted and self.duckTarget >= 1 then SWELL else 1
	self.swell += math.clamp(swellTarget - self.swell, -(SWELL - 1) / SWELL_S * dt, (SWELL - 1) / SWELL_S * dt)
	local music: Sound? = self.music
	if music then
		music.Volume = MIX.music * self.master * self.musicVolume * self.duck * self.swell
		playing(music, audible)
		-- (ROBLOX-100: a music that has been asked to play for MUSIC_LOAD_WARN_S seconds and still says it has not loaded is reported once, in Output only.)
		if audible and not self.musicWarned then
			self.musicAsked += dt
			if self.musicAsked >= Soundscape.MUSIC_LOAD_WARN_S and (music.IsLoaded :: any) == false then
				self.musicWarned = true
				warn(`[Windowsill] music: {music.SoundId} has not loaded after {Soundscape.MUSIC_LOAD_WARN_S} s (IsLoaded false); it plays when it loads, if it loads`)
			end
		end
	end
	if not audible or daylight < 0.3 then self.birds:Stop() end
	if audible then
		self.elapsed += math.min(dt, 0.25) * speed
		if self.elapsed >= self.nextBird then
			self.nextBird = self.elapsed + 17
			if daylight >= 0.3 then self.birds:Play() end
		end
	end
	-- A bounded pool, indexed by the current population rather than holding checkpoint fly references.
	for i, fly in prey.flies do
		if i > 8 then break end
		local slot = self.slots[i]
		if not slot then
			local p = Instance.new("Part")
			p.Name = "FlyAudio"
			p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
			p.Transparency = 1; p.Size = Vector3.new(0.1, 0.1, 0.1); p.Parent = self.root
			slot = { part = p, buzz = voice(p, "buzz", MIX.buzz, true), takeoff = voice(p, "takeoff", MIX.takeoff, false), flying = false }
			self.slots[i] = slot
		end
		slot.buzz.Volume, slot.takeoff.Volume = MIX.buzz * creature, MIX.takeoff * creature
		slot.part.Position = fly.position
		local flying = fly:airborne() or (prey.feeding.held == fly and prey.feeding.struggling)
		slot.buzz.PlaybackSpeed = speed; slot.takeoff.PlaybackSpeed = speed
		playing(slot.buzz, audible and flying)
		if not audible then slot.takeoff:Stop()
		elseif flying and not slot.flying then slot.takeoff:Play() end
		slot.flying = flying
	end
	for i, slot in self.slots do
		if i > #prey.flies then slot.part:Destroy(); self.slots[i] = nil end
	end
end
-- The warning starts immediately with the director's arrival phase. Its initial global mix
-- cannot disappear when the third-person camera is far away; the caption supplies direction.
-- Once it reaches the sill, the same voice follows the wasp in 3D. No second warning timer.
function Soundscape.updateWasp(self: any, director: any, paused: boolean, speed: number, muted: boolean)
	local arriving = director.phase == "arriving"
	self.duckTarget = if director.phase ~= "away" then DUCK else 1
	local active = director.phase ~= "away" and director.wasp.mode ~= "walking"
	local hum: Sound = self.waspHum
	self.waspEmitter.Position = director.wasp.position
	local home: Instance = if arriving then self.root else self.waspEmitter
	if hum.Parent ~= home then hum.Parent = home end -- (only on a change: re-parenting a playing sound each frame can restart it, ROBLOX-92)
	hum.Volume = (if arriving then MIX.humArriving else MIX.hum) * self.master * self.creatures
	hum.PlaybackSpeed = speed
	if not active then hum:Stop()
	else playing(hum, not paused and not muted) end
end
function Soundscape.destroy(self: any)
	self.root:Destroy()
	table.clear(self.slots)
end
return Soundscape
