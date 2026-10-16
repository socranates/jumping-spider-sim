--!strict
-- LIFE and checkpoints in the engine (ROBLOX-24, ROBLOX-25). The pure CLI suites (tests/life.luau, tests/checkpoint.luau) check
-- the same modules under a shim; here they run in Roblox: real Vector3s and Color3s, the real Lighting service, HttpService's
-- own JSON, and real raycasts on a private copy of the sill.
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local LifeClock = require(Shared.Life.LifeClock)
local NeedsModel = require(Shared.Life.NeedsModel)
local LifeLoop = require(Shared.Life.LifeLoop)
local DayLight = require(Shared.Habitat.DayLight)
local Graphics = require(Shared.Data.Graphics)
local Layout = require(Shared.Habitat.WindowsillLayout)
local Species = require(Shared.Data.Species)
local Surfaces = require(Shared.Data.Surfaces)
local Motor = require(Shared.Movement.SpiderMotor)
local PreyDirector = require(Shared.Prey.PreyDirector)
local Sensor = require(Shared.Perception.Sensor)
local ObservationMemory = require(Shared.Perception.ObservationMemory)
local ObjectRecord = require(Shared.Persistence.ObjectRecord)
local Checkpoint = require(Shared.Persistence.Checkpoint)
local CheckpointStore = require(Shared.Persistence.CheckpointStore)
local Json = require(Shared.Persistence.Json)

return function(check: (string, () -> ()) -> ())
	check("LIFE: the clock, the needs and the loop run in the engine as in the CLI", function()
		local c = LifeClock.new()
		assert(c.day == 1 and c.hour == 9 and c:daylight() == 1, "starts at 9 on day 1, in full day")
		c.hour = 19
		local ticks = 0
		repeat c:advance(1 / 60, true); ticks += 1 until not c.sleeping or ticks > 5000
		assert(c.day == 2 and math.abs(c.hour - 7) < 1e-9 and ticks == 515, `a night of sleep: {ticks} ticks to day {c.day}, {c.hour}`)
		local n = NeedsModel.new(true)
		n:addHours(10, false)
		n:advance(0.25, false); n:advance(0.25, false)
		assert(math.abs(n.energy - (0.55 - 0.21)) < 1e-9, `hunger by the hour ({n.energy})`)
		local l = LifeLoop.new(NeedsModel.new(true))
		l.clock.hour = 23
		l:applyLight()
		assert(l.rangeScale == LifeLoop.NIGHT_SIGHT, "the eyes reach less far at night")
	end)

	check("LIFE: the day's light is the accepted look; night is set on the real Lighting and taken back", function()
		local before = {
			ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
			ColorShift_Top = Lighting.ColorShift_Top, ExposureCompensation = Lighting.ExposureCompensation,
		}
		local day = DayLight.targets(1, before.ClockTime)
		assert(math.abs(day.brightness - Graphics.lighting.brightness) < 1e-9 and day.clock == before.ClockTime, "full day is the daytime values")
		local decor = workspace:FindFirstChild("Decor")
		DayLight.apply(Lighting, DayLight.targets(0, before.ClockTime), decor)
		assert(math.abs(Lighting.ClockTime - Graphics.dayNight.nightClock) < 1e-3, `night clock {Lighting.ClockTime}`)
		assert(Lighting:GetSunDirection().Y < 0, "the sun is below the horizon at night")
		assert(Lighting.Brightness < 1 and Lighting.ExposureCompensation < 0, "dim")
		local shafts = decor and decor:FindFirstChild("Shafts")
		if shafts then
			for _, b in shafts:GetDescendants() do
				if b:IsA("Beam") then assert(not b.Enabled, "a light shaft still shows at night") end
			end
		end
		DayLight.apply(Lighting, day, decor)
		assert(math.abs(Lighting.ClockTime - before.ClockTime) < 1e-3 and math.abs(Lighting.Brightness - before.Brightness) < 1e-6, "day again")
		assert(Lighting.Ambient == before.Ambient and Lighting.OutdoorAmbient == before.OutdoorAmbient, "the room's light as it was")
		print("PORT_LIFE_LIGHT " .. HttpService:JSONEncode({ day_clock = before.ClockTime, night_clock = Graphics.dayNight.nightClock, sun_pick = Lighting:GetAttribute("SunPick") }))
	end)

	-- A private sill, as PreySpec builds it: the same pieces, casts that see only this copy.
	local world = Instance.new("Folder")
	world.Name = "LifeTestWorld"
	world.Parent = workspace
	for _, b in Layout.PIECES do
		local part = Instance.new("Part")
		part.Name = b.id
		part.Anchored = true
		part.Size = b.hi - b.lo
		part.CFrame = CFrame.new((b.hi + b.lo) * 0.5)
		part.Transparency = 1
		part.CanCollide = false
		part.Parent = world
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world }
	local cast = Sensor.workspaceCast(params)
	local camera = { CFrame = CFrame.new(Vector3.new(0, 30, 40)), FieldOfView = 70, ViewportSize = Vector2.new(1280, 720) } -- a stand-in view (the server has no player camera)
	local function newWorld(): any
		local motor = Motor.new({
			world = world, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Layout.SPAWN,
			heading = Layout.SPAWN_HEADING, boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX,
		})
		local prey = PreyDirector.engine(world, Species.fly_like_prototype, 914, 4)
		local memory = ObservationMemory.new()
		local sensor = Sensor.new(memory)
		sensor:configureFrom(Species.phidippus_audax_prototype.perception)
		local needs = NeedsModel.new(true)
		prey.feeding.needs = needs
		local w: any = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs, life = LifeLoop.new(needs) }
		motor:place(Vector3.new(-25.5, Layout.SPAWN.Y, 6), Vector3.yAxis, Vector3.xAxis)
		return w
	end
	local STILL = { wish = Vector3.zero, creep = false, reel = 0, dropHeld = false, releaseHeld = false }
	local function tick(w: any, feed: boolean?)
		w.sensor:step(Motor.DT, w.motor:observer(), w.prey:percepts(), cast)
		w.prey:before(Motor.DT, w.motor.pos, w.motor:observer(), w.sensor, cast, camera)
		w.motor:tick(STILL)
		w.prey:after(Motor.DT, w.motor, w.sensor, cast)
		local holding = w.prey.feeding.held ~= nil
		w.life:step(Motor.DT, { inRetreat = Layout.inRetreat(w.motor.pos), attached = w.motor.mode == "attached", still = w.motor.vel.Magnitude < 0.15,
			holding = holding, feeding = holding and w.prey.feeding.feeding }, feed == true, false)
		w.sensor.core.rangeScale = w.life.rangeScale
		w.life:drainEvents()
	end
	local function fingerprint(w: any): string
		local saved = { w.prey.cpu, w.prey.beforeCost, w.sensor._ring, w.sensor.cpuUsTotal, w.sensor.cpuUsMax }
		w.prey.cpu, w.prey.beforeCost, w.sensor._ring, w.sensor.cpuUsTotal, w.sensor.cpuUsMax = {}, 0, {}, 0, 0
		local rec = assert(ObjectRecord.capture({ prey = w.prey, sensor = w.sensor, memory = w.memory, needs = w.needs, life = w.life }, Checkpoint.CLASSES, Checkpoint.refs(w)))
		w.prey.cpu, w.prey.beforeCost, w.sensor._ring, w.sensor.cpuUsTotal, w.sensor.cpuUsMax = saved[1], saved[2], saved[3], saved[4], saved[5]
		local text = assert(Json.canonical(rec))
		text = string.gsub(text, '%["notice","[^"]*"%]', "")
		text = string.gsub(text, '%["noticeSeconds",[^%]]*%]', "")
		text = string.gsub(text, '%["restoreGrace",[^%]]*%]', "")
		local m = w.motor
		return text .. string.format("|%.12f %.12f %.12f|%s", m.pos.X, m.pos.Y, m.pos.Z, m.mode)
	end

	check("S01-C: a retreat checkpoint goes through HttpService's JSON and back, and the world repeats exactly", function()
		local w = newWorld()
		for _ = 1, 60 do tick(w) end
		tick(w, true)
		assert(w.life.resting, "resting in the crack")
		assert(Checkpoint.boundaryProblem(w) == "", "a boundary: " .. Checkpoint.boundaryProblem(w))
		local record = assert(Checkpoint.capture(w, os.time()))
		local text = HttpService:JSONEncode(record)
		assert(#text < CheckpointStore.MemoryDataStore.MAX_CHARS, `under the DataStore limit ({#text})`)
		local back = HttpService:JSONDecode(text)
		assert(#(Checkpoint.check(back, w)) == 0, "the record survives Roblox's own JSON: " .. table.concat(Checkpoint.check(back, w), "; "))
		local first = {}
		for t = 1, 300 do
			tick(w)
			if t % 30 == 0 then table.insert(first, fingerprint(w)) end
		end
		local ok, problems = Checkpoint.restore(back, w)
		assert(ok, "restored: " .. table.concat(problems, "; "))
		local diffs = 0
		for t = 1, 300 do
			tick(w)
			if t % 30 == 0 and fingerprint(w) ~= first[t // 30] then diffs += 1 end
		end
		assert(diffs == 0, `the second run differs from the first in {diffs} of {#first} samples`)
		print("PORT_CHECKPOINT " .. HttpService:JSONEncode({ characters = #text, tables = #record.world.objects }))
	end)

	check("S02: the store keeps the last good checkpoint and refuses a bad one without touching the world", function()
		local w = newWorld()
		for _ = 1, 30 do tick(w) end
		local store = CheckpointStore.new(CheckpointStore.MemoryDataStore.new(), function(r) return (Checkpoint.check(r, w)) end)
		assert(store:save(assert(Checkpoint.capture(w, 1))).ok, "first save")
		for _ = 1, 30 do tick(w) end
		assert(store:save(assert(Checkpoint.capture(w, 2))).ok, "second save")
		store.store.data.checkpoint.checkpoint.snapshot_tick += 1
		local best = store:loadBest()
		assert(best.ok and best.source == "backup" and best.record.created_at == 1, "falls back to the backup")
		local bad = Json.copy(best.record)
		bad.content_revision = "elsewhere"
		local before = fingerprint(w)
		assert(not Checkpoint.restore(bad, w) and fingerprint(w) == before, "a bad record changes nothing")
	end)

	world:Destroy()
end
