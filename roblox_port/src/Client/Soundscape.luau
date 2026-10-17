--!strict
-- Original procedural recordings from the frozen Godot sound_bank.gd. Presentation only:
-- never feeds perception, AI or simulation time. Roblox's master volume controls every voice.
local Soundscape = {}
Soundscape.__index = Soundscape
local IDS = {
	room = "rbxassetid://135813320748786", buzz = "rbxassetid://90354950534870",
	takeoff = "rbxassetid://135484013341687", birds = "rbxassetid://105858750316891",
	wasp = "rbxassetid://76049518783466",
}
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
function Soundscape.new(parent: Instance): any
	local root = Instance.new("Folder")
	root.Name = "WindowsillAudio"
	root.Parent = parent
	local emitter = Instance.new("Part")
	emitter.Name = "WaspAudio"
	emitter.Anchored = true; emitter.CanCollide = false; emitter.CanTouch = false; emitter.CanQuery = false
	emitter.Transparency = 1; emitter.Size = Vector3.new(0.1, 0.1, 0.1); emitter.Parent = root
	local hum = voice(emitter, "wasp", 0.42, true)
	hum.RollOffMinDistance = 16; hum.RollOffMaxDistance = 120
	return setmetatable({ root = root, room = voice(root, "room", 0.09, true),
		waspEmitter = emitter, waspHum = hum,
		birds = voice(root, "birds", 0.16, false), slots = {}, elapsed = 0, nextBird = 8 }, Soundscape)
end
local function playing(s: Sound, wanted: boolean)
	if wanted then
		if not s.Playing then s:Resume(); if not s.Playing then s:Play() end end
	elseif s.Playing then s:Pause() end
end
function Soundscape.update(self: any, dt: number, prey: any, daylight: number, paused: boolean, speed: number, muted: boolean)
	local audible = not paused and not muted
	playing(self.room, audible)
	self.room.PlaybackSpeed = speed
	self.birds.PlaybackSpeed = speed
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
			slot = { part = p, buzz = voice(p, "buzz", 0.23, true), takeoff = voice(p, "takeoff", 0.22, false), flying = false }
			self.slots[i] = slot
		end
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
	local active = director.phase ~= "away" and director.wasp.mode ~= "walking"
	local hum: Sound = self.waspHum
	self.waspEmitter.Position = director.wasp.position
	hum.Parent = if arriving then self.root else self.waspEmitter
	hum.Volume = if arriving then 0.32 else 0.42
	hum.PlaybackSpeed = speed
	if not active then hum:Stop()
	else playing(hum, not paused and not muted) end
end
function Soundscape.destroy(self: any)
	self.root:Destroy()
	table.clear(self.slots)
end
return Soundscape
