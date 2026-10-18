-- Checkpoint checks (S01-C, S02; ROBLOX-25): the retreat checkpoint of a whole world, the DataStore-shaped store, and their
-- refusals. A world like the client's (the real SpiderMotor on the windowsill's boxes, the real flies of PreyDirector.engine,
-- Sensor, ObservationMemory, NeedsModel, Feeding, LifeLoop) runs on the box world of tests/shim.luau in the client's tick
-- order. The central check: run, keep a checkpoint, run on and note every state; return to the checkpoint and run the same
-- ticks again; the second run must repeat the first exactly. Then what must be refused, and that a refusal changes nothing.
-- Not engine evidence (no Studio, no real DataStore): a smoke test of the real modules.
-- Run with the other suites:  python3 tests/run.py path/to/luau checkpoint.luau
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local Species = require("../src/Shared/Data/Species")
local Surfaces = require("../src/Shared/Data/Surfaces")
local Motor = require("../src/Shared/Movement/SpiderMotor")
local PreyDirector = require("../src/Shared/Prey/PreyDirector")
local Sensor = require("../src/Shared/Perception/Sensor")
local ObservationMemory = require("../src/Shared/Perception/ObservationMemory")
local NeedsModel = require("../src/Shared/Life/NeedsModel")
local LifeLoop = require("../src/Shared/Life/LifeLoop")
local ObjectRecord = require("../src/Shared/Persistence/ObjectRecord")
local Checkpoint = require("../src/Shared/Persistence/Checkpoint")
local CheckpointStore = require("../src/Shared/Persistence/CheckpointStore")
local Json = require("../src/Shared/Persistence/Json")
local WaspDirector = require("../src/Shared/Predator/WaspDirector")

local passed, failed = 0, 0
local current = ""
local function check(ok: boolean, what: string): boolean
	if ok then passed += 1 else failed += 1; print(`FAIL [{current}] {what}`) end
	return ok
end
local function case(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	if not ok then failed += 1; print(`FAIL [{name}] raised: {tostring(err)}`) end
end

local DT = Motor.DT
local sill = BoxWorld.folder("CheckpointSill", Layout.PIECES)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { sill }
local cast = Sensor.workspaceCast(params)
local camera = { CFrame = CFrame.new(Vector3.new(0, 30, 40)), FieldOfView = 70, ViewportSize = Vector2.new(1280, 720) }
local HOME = Vector3.new(-25.5, Layout.SPAWN.Y, 6.0)

-- A world built the way the client builds it.
local function newWorld(seed: number?): any
	local motor = Motor.new({
		world = sill, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Layout.SPAWN,
		heading = Layout.SPAWN_HEADING, boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX,
	})
	local prey = PreyDirector.engine(sill, Species.fly_like_prototype, seed or 914, 4)
	local memory = ObservationMemory.new()
	local sensor = Sensor.new(memory)
	sensor:configureFrom(Species.phidippus_audax_prototype.perception)
	local needs = NeedsModel.new(true, false)
	prey.feeding.needs = needs
	local w: any = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs }
	w.dataStore = CheckpointStore.MemoryDataStore.new()
	w.store = CheckpointStore.new(w.dataStore, function(r) return (Checkpoint.check(r, w)) end)
	w.life = LifeLoop.new(needs, function()
		local why = Checkpoint.boundaryProblem(w)
		if why ~= "" then return { ok = false, message = why } end
		local record, err = Checkpoint.capture(w, 0)
		if not record then return { ok = false, message = err :: string } end
		local r = w.store:save(record)
		return { ok = r.ok, message = if r.ok then r.message else r.message .. ": " .. table.concat(r.errors, "; ") }
	end)
	motor:place(HOME, Vector3.yAxis, Vector3.new(1, 0, 0))
	return w
end

local STILL = { wish = Vector3.zero, creep = false, reel = 0, dropHeld = false, releaseHeld = false }
-- One fixed tick in the client's order. `input` is the motor's intent; `feed` a press of E.
local function tick(w: any, input: any?, feed: boolean?)
	local i = input or STILL
	w.sensor:step(DT, w.motor:observer(), w.prey:percepts(), cast)
	w.prey:before(DT, w.motor.pos, w.motor:observer(), w.sensor, cast, camera)
	w.motor:tick(i)
	w.prey:after(DT, w.motor, w.sensor, cast)
	local holding = w.prey.feeding.held ~= nil
	w.life:step(DT, {
		inRetreat = Layout.inRetreat(w.motor.pos), attached = w.motor.mode == "attached" and not w.motor.preparing,
		still = i.wish.Magnitude < 0.01 and w.motor.vel.Magnitude < 0.15, holding = holding, feeding = holding and w.prey.feeding.feeding,
	}, feed == true, false)
	w.sensor.core.rangeScale = w.life.rangeScale
	w.life:drainEvents() -- as the client does each tick
end

-- Everything about the world, as text: the recorded graph without the timing instruments (CPU microseconds differ run to
-- run), and the spider's pose.
local function fingerprint(w: any): string
	local saved = { w.prey.cpu, w.prey.beforeCost, w.sensor._ring, w.sensor.cpuUsTotal, w.sensor.cpuUsMax }
	w.prey.cpu, w.prey.beforeCost, w.sensor._ring, w.sensor.cpuUsTotal, w.sensor.cpuUsMax = {}, 0, {}, 0, 0
	local rec = assert(ObjectRecord.capture({ prey = w.prey, sensor = w.sensor, memory = w.memory, needs = w.needs, life = w.life }, Checkpoint.CLASSES, Checkpoint.refs(w)))
	w.prey.cpu, w.prey.beforeCost, w.sensor._ring, w.sensor.cpuUsTotal, w.sensor.cpuUsMax = saved[1], saved[2], saved[3], saved[4], saved[5]
	local m = w.motor
	return assert(Json.canonical(rec)) .. string.format("|%.12f %.12f %.12f|%.12f %.12f %.12f|%s", m.pos.X, m.pos.Y, m.pos.Z, m.heading.X, m.heading.Y, m.heading.Z, m.mode)
end

local function rest(w: any)
	tick(w, nil, true)
end

-- --------------------------------------------------------------------------------------------------------------------------
case("a rest in the crack keeps a checkpoint the store accepts", function()
	local w = newWorld()
	for _ = 1, 120 do tick(w) end
	check(Layout.inRetreat(w.motor.pos) and w.motor.mode == "attached", `the spider is at home ({w.motor.pos})`)
	rest(w)
	check(w.life.resting, "resting")
	check(w.life.checkpoints == 1 and w.life.notice == "Checkpoint kept.", `kept: {w.life.notice}`)
	local best = w.store:loadBest()
	check(best.ok and best.source == "current", "the store hands it back: " .. best.message)
	local size = w.dataStore.sizes.checkpoint or 0
	check(size > 1000 and size < CheckpointStore.MemoryDataStore.MAX_CHARS, `a storable size ({size} characters)`)
	print(`checkpoint: {size} characters, {#best.record.world.objects} tables`)
end)

case("returning to the checkpoint repeats the world exactly", function()
	local w = newWorld()
	for _ = 1, 90 do tick(w) end
	w.needs:configure({ energy = 0.4 })
	rest(w)
	for _ = 1, 60 do tick(w) end -- still resting; the flies go on
	-- The checkpoint is kept now, at a tick boundary, from the rest going on.
	local record = assert(Checkpoint.capture(w, 0))
	check(#(Checkpoint.check(record, w)) == 0, "a good record")
	local first: { string } = {}
	local walk = { wish = Vector3.new(1, 0, 0), creep = false, reel = 0, dropHeld = false, releaseHeld = false }
	for t = 1, 600 do
		tick(w, if t > 200 and t <= 260 then walk else nil)
		if t % 20 == 0 then table.insert(first, fingerprint(w)) end
	end
	local before = fingerprint(w)
	local ok, problems = Checkpoint.restore(record, w)
	check(ok, "restored: " .. table.concat(problems, "; "))
	check(fingerprint(w) ~= before, "the world went back")
	-- The restore's own notice and grace are not part of the comparison: tick once, then the world is the checkpoint's.
	local diffs = 0
	local k = 0
	for t = 1, 600 do
		tick(w, if t > 200 and t <= 260 then walk else nil)
		if t % 20 == 0 then
			k += 1
			local a, b = first[k], fingerprint(w)
			-- The life loop's notice differs (the restore says so), and so does its timer and the restore's grace: compare without them.
			local function plain(x: string): string
				x = string.gsub(x, '%["notice","[^"]*"%]', "")
				x = string.gsub(x, '%["noticeSeconds",[^%]]*%]', "")
				x = string.gsub(x, '%["restoreGrace",[^%]]*%]', "")
				return x
			end
			a, b = plain(a), plain(b)
			if a ~= b then
				diffs += 1
				if diffs == 1 then
					local i = 1
					while i <= #a and string.byte(a, i) == string.byte(b, i) do i += 1 end
					print("first difference at sample " .. k .. ":\n  " .. string.sub(a, math.max(1, i - 160), i + 80) .. "\n  " .. string.sub(b, math.max(1, i - 160), i + 80))
				end
			end
		end
	end
	check(diffs == 0, `the second run repeats the first ({diffs} of {k} samples differ)`)
end)

case("a fly eaten after the checkpoint comes back with the energy it gave", function()
	local w = newWorld()
	for _ = 1, 30 do tick(w) end
	rest(w)
	local record = assert(Checkpoint.capture(w, 0))
	local energy, flies = w.needs.energy, #w.prey.flies
	-- A meal after the checkpoint: the first fly is caught and eaten (the feeding controller's own path).
	local f = w.prey.flies[1]
	f.flight:release()
	if f.perch and f.perch.occupant == f.id then f.perch.occupant = "" end
	f.state = "CAPTURED"; f.captureSerial += 1; f.captureKey = f.id .. ":" .. f.captureSerial
	w.prey.feeding:capture(f)
	w.prey.feeding.struggling, w.prey.feeding.feeding, w.prey.feeding.swallow = false, true, 0
	for _ = 1, 600 do tick(w) end
	check(w.needs.energy > energy + 0.1 and w.needs.grantedTotal > 0, `the meal fed the spider ({w.needs.energy})`)
	local ok = Checkpoint.restore(record, w)
	check(ok, "restored")
	check(w.needs.energy == energy and w.needs.grantedTotal == 0 and #w.prey.flies == flies, "the energy and the fly went back together")
	check(w.prey.flies[1].state ~= "CAPTURED" and w.prey.feeding.held == nil, "the fly is free again")
	check(w.prey.feeding.needs == w.needs and w.life.needs == w.needs, "one needs model, still shared")
end)

case("a part-eaten meal in the jaws is kept with it", function()
	local w = newWorld()
	for _ = 1, 30 do tick(w) end
	local f = w.prey.flies[2]
	f.flight:release()
	if f.perch and f.perch.occupant == f.id then f.perch.occupant = "" end
	f.state = "CAPTURED"; f.captureSerial += 1; f.captureKey = f.id .. ":" .. f.captureSerial
	w.prey.feeding:capture(f)
	w.prey.feeding.struggling, w.prey.feeding.feeding, w.prey.feeding.swallow = false, true, 0
	for _ = 1, 60 do tick(w) end
	w.prey.feeding:cancel()
	tick(w)
	check(Checkpoint.boundaryProblem(w) == "", "a paused meal is a boundary: " .. Checkpoint.boundaryProblem(w))
	local record = assert(Checkpoint.capture(w, 0))
	local left = f.nutrition
	w.prey.feeding:press()
	for _ = 1, 60 do tick(w) end
	check(f.nutrition < left, "eating went on")
	check(Checkpoint.restore(record, w), "restored")
	local held = w.prey.feeding.held
	check(held ~= nil and held.id == f.id and held.nutrition == left and held ~= f, "the same fly, part eaten, back in the jaws (a rebuilt table)")
	check(w.prey.flies[2] == held, "the jaws hold the world's own fly")
end)

case("no checkpoint at a moment that is not a boundary", function()
	local w = newWorld()
	for _ = 1, 10 do tick(w) end
	w.prey.feeding.feeding = true
	check(Checkpoint.boundaryProblem(w) == "the spider is feeding", "feeding")
	w.prey.feeding.feeding = false
	w.prey.feeding.struggling = true
	check(Checkpoint.boundaryProblem(w) == "the prey in the jaws is still struggling", "struggling")
	w.prey.feeding.struggling = false
	w.prey.strikeEnd = w.prey.tick + 5
	check(Checkpoint.boundaryProblem(w) == "a strike is still in progress", "a strike")
	w.prey.strikeEnd = -1
	w.motor.vel = Vector3.new(1, 0, 0)
	check(Checkpoint.boundaryProblem(w) == "the spider is moving", "moving")
	w.motor.vel = Vector3.zero
	w.motor.mode = "air"
	check(Checkpoint.boundaryProblem(w) == "the spider is not standing on a surface", "in the air")
	w.motor.mode = "attached"
	check(Checkpoint.boundaryProblem(w) == "", "still on a surface")
	-- Through the rest: in the air the loop cannot rest, and so keeps no checkpoint.
	w.life:step(DT, { inRetreat = true, attached = false, still = true, holding = false, feeding = false }, true, false)
	check(not w.life.resting and w.life.checkpoints == 0, "no rest, no checkpoint, in the air")
end)

case("a bad record is refused and changes nothing", function()
	local w = newWorld()
	for _ = 1, 40 do tick(w) end
	local good = assert(Checkpoint.capture(w, 0))
	for _ = 1, 30 do tick(w) end
	local function refused(change: (any) -> (), what: string, expect: string?)
		local r = Json.copy(good)
		change(r)
		local before = fingerprint(w)
		local ok, problems = Checkpoint.restore(r, w)
		check(not ok and #problems > 0, `{what}: refused`)
		if expect then check(string.find(table.concat(problems, "; "), expect, 1, true) ~= nil, `{what}: says '{expect}' ({table.concat(problems, "; ")})`) end
		check(fingerprint(w) == before, `{what}: nothing changed`)
	end
	refused(function(r) r.schema_version = Checkpoint.SCHEMA_VERSION + 1 end, "a newer schema", "newer version")
	refused(function(r) r.schema_version = 1.5 end, "a broken schema", "whole number")
	refused(function(r) r.kind = "x" end, "another kind", "not a retreat checkpoint")
	refused(function(r) r.content_revision = "old-sill" end, "another windowsill", "another windowsill")
	refused(function(r) r.player.position = { 0, 0 / 0, 0 } end, "a NaN position", "no position")
	refused(function(r) r.player.position = { 900, 1, 1 } end, "a spider off the sill", "outside the windowsill")
	refused(function(r) r.player.state = "AIRBORNE" end, "an airborne spider", "not standing")
	refused(function(r) r.player.heading = { 3, 0, 0 } end, "a heading that is not a direction", "heading")
	refused(function(r) r.world.objects[1].c = "Wasp" end, "an unknown class", "does not know")
	refused(function(r) r.world.roots.prey = { ["$o"] = 999999 } end, "a dangling reference", "points at no object")
	refused(function(r) r.world.roots.prey = { ["$r"] = "nothing" } end, "an unknown name", "does not have")
	refused(function(r) r.world = nil end, "no world", "world")
	-- Meaning: the reserves out of range, a duplicated fly, a perch held by nobody.
	local function edit(r: any, class: string, key: string, value: any)
		for _, o in r.world.objects do
			if o.c == class then
				for _, e in o.e do if e[1] == key then e[2] = value end end
				return
			end
		end
	end
	refused(function(r) edit(r, "NeedsModel", "energy", 1.5) end, "energy above full", "reserves")
	refused(function(r) edit(r, "NeedsModel", "grantedTotal", 3) end, "books that do not add up", "reserves")
	refused(function(r) edit(r, "LifeClock", "hour", 30) end, "an impossible hour", "hour")
	refused(function(r)
		local n = 0
		for _, o in r.world.objects do
			if o.c == "Fly" then
				n += 1
				if n == 2 then for _, e in o.e do if e[1] == "id" then e[2] = "fly_1" end end end
			end
		end
	end, "two flies with one name", "two flies")
	refused(function(r) edit(r, "Fly", "state", "DANCING") end, "a fly in no known state", "no known state")
	refused(function(r) edit(r, "Fly", "nutrition", 5) end, "a fly fuller than a fly", "nutrition")
	refused(function(r)
		for _, o in r.world.objects do
			for _, e in o.e do if e[1] == "occupant" and e[2] ~= "" then e[2] = "fly_77" end end
		end
	end, "a perch held by a fly that does not exist", "not a living fly")
	refused(function(r) edit(r, "Feeding", "granted", 0.4) end, "a meal ledger that does not add up", "add up")
	check(Checkpoint.restore(good, w), "the good record still restores")
end)

case("the store keeps the last good checkpoint whatever happens to a write", function()
	local w = newWorld()
	for _ = 1, 30 do tick(w) end
	local store, ds = w.store, w.dataStore
	local a = assert(Checkpoint.capture(w, 1))
	check(store:save(a).ok, "the first save")
	for _ = 1, 30 do tick(w) end
	local b = assert(Checkpoint.capture(w, 2))
	check(store:save(b).ok, "the second save")
	check(ds.data["checkpoint.bak"].checkpoint.created_at == 1 and ds.data.checkpoint.checkpoint.created_at == 2, "the first is the backup now")
	check(ds.data["checkpoint.tmp"] == nil, "no temporary entry left")
	-- A failed write: the current and the backup are untouched.
	ds.failNext = 1
	local c = assert(Checkpoint.capture(w, 3))
	local r = store:save(c)
	check(not r.ok and string.find(r.message, "could not be written", 1, true) ~= nil, "a failed write is reported: " .. r.message)
	check(ds.data.checkpoint.checkpoint.created_at == 2 and ds.data["checkpoint.bak"].checkpoint.created_at == 1, "nothing was lost")
	-- A current entry cut short: loading falls back to the backup, and says why.
	ds.data.checkpoint.checkpoint.snapshot_tick += 1
	local best = store:loadBest()
	check(best.ok and best.source == "backup" and best.record.created_at == 1, "the backup is used")
	check(string.find(table.concat(best.errors, "; "), "checksum", 1, true) ~= nil, "and the reason is given: " .. table.concat(best.errors, "; "))
	-- Saving over a damaged current sets it aside instead of letting it push out the good backup.
	local d = assert(Checkpoint.capture(w, 4))
	check(store:save(d).ok, "a save over a damaged current")
	check(ds.data["checkpoint.aside.1"] ~= nil and ds.data["checkpoint.bak"].checkpoint.created_at == 1, "the damaged one set aside, the good backup kept")
	check(store:loadBest().record.created_at == 4, "the new one is current")
	-- A record made by a newer version is reported and left as it is.
	local newer = Json.copy(d)
	newer.schema_version = 9
	local entry = CheckpointStore.entry(newer)
	ds.data.checkpoint = entry
	local n = store:loadBest()
	check(not n.ok and string.find(n.message, "newer version", 1, true) ~= nil, "a newer checkpoint is reported: " .. n.message)
	check(ds.data.checkpoint.checkpoint.schema_version == 9, "and left as it is")
	-- Invalid records are never written.
	local bad = Json.copy(d)
	bad.kind = "nonsense"
	local writes = ds.writes
	check(not store:save(bad).ok and ds.writes == writes, "an invalid record is not written")
	-- An empty store.
	local empty = CheckpointStore.new(CheckpointStore.MemoryDataStore.new(), function(r) return (Checkpoint.check(r, w)) end)
	local none = empty:loadBest()
	check(not none.ok and none.message == "no checkpoint to return to", "nothing to return to")
end)

case("the DataStore stand-in has a DataStore's rules", function()
	local ds = CheckpointStore.MemoryDataStore.new()
	local v = { a = 1, list = { 1, 2, 3 }, s = "x" }
	ds:SetAsync("k", v)
	local got = ds:GetAsync("k")
	check(got ~= v and got.list ~= v.list and got.list[3] == 3, "values are copied in and out")
	v.a = 2
	check(ds:GetAsync("k").a == 1, "changing the original changes nothing stored")
	for what, value in {
		nan = { x = 0 / 0 }, inf = { x = math.huge }, mixed = { 1, 2, k = 3 }, sparse = { [1] = 1, [3] = 3 },
		fn = { f = function() end }, vector = { v = Vector3.new(1, 2, 3) }, boolkey = { [true] = 1 },
	} do
		check(not pcall(function() ds:SetAsync("bad", value) end), `{what} is refused`)
	end
	local shared = { 1 }
	check(not pcall(function() ds:SetAsync("bad", { a = shared, b = shared }) end), "a table met twice is refused")
	check(ds:GetAsync("bad") == nil, "nothing refused was stored")
	check(Json.canonical({ b = 1, a = { 0.1, true, "q\"" } }) == '{"a":[0.10000000000000001,true,"q\\""],"b":1}', "canonical text")
	check(Json.checksum("abc") ~= Json.checksum("abd") and #Json.checksum("") == 16, "the checksum tells texts apart")
end)

case("the wasp's record is kept, brought back, and a visit going on ends (ROBLOX-26)", function()
	local w = newWorld()
	local none = { ray = function() return false end, clear = function() return true end, inRetreat = function() return false end }
	w.wasp = WaspDirector.new({ seed = 5, world = none, enabled = false })
	w.wasp.lastVisitDay, w.wasp.visits, w.wasp.escapes = 4, 3, 2
	for _ = 1, 60 do tick(w) end
	local record = assert(Checkpoint.capture(w, 0))
	check(record.wasp ~= nil and record.wasp.last_visit_day == 4 and record.wasp.visits == 3 and record.wasp.escapes == 2, "the record holds the wasp's record")
	check(#(Checkpoint.check(record, w)) == 0, "a good record")
	check(Json.canonical(record) ~= nil, "storable with it")
	-- A visit goes on, the record moves, then the checkpoint comes back.
	w.wasp:force(5, "floor_middle")
	w.wasp.visits, w.wasp.escapes, w.wasp.lastVisitDay = 9, 7, 8
	check(w.wasp:isVisiting(), "a visit is going on")
	local ok, problems = Checkpoint.restore(record, w)
	check(ok, "restored: " .. table.concat(problems, "; "))
	check(w.wasp.lastVisitDay == 4 and w.wasp.visits == 3 and w.wasp.escapes == 2, "the wasp's record came back")
	check(not w.wasp:isVisiting() and not w.wasp.wasp.visible and not w.wasp.holding, "and the visit going on is over")
	-- An older record, made before the wasp, brings the record of a life not yet visited.
	local older = assert(Checkpoint.capture(w, 0))
	older.wasp = nil
	check(#(Checkpoint.check(older, w)) == 0, "a record without the wasp is good")
	w.wasp.visits = 5
	check((Checkpoint.restore(older, w)), "and restores")
	check(w.wasp.visits == 0 and w.wasp.escapes == 0 and w.wasp.lastVisitDay == 0, "to no visits yet")
	-- A broken wasp record is refused, and the live world is left alone.
	local bad = assert(Checkpoint.capture(w, 0))
	bad.wasp = { last_visit_day = 2, visits = 1, escapes = 2 }
	w.wasp.visits = 6
	local problems2 = Checkpoint.check(bad, w)
	check(#problems2 > 0 and string.find(problems2[1], "wasp", 1, true) ~= nil, "refused: " .. tostring(problems2[1]))
	local restored = Checkpoint.restore(bad, w)
	check(not restored and w.wasp.visits == 6, "and nothing changed")
	-- The motor taken by the wasp is put right by a return to the checkpoint.
	w.motor:seize()
	check(w.motor.seized and w.motor.mode == "air", "seized")
	local before = w.motor.pos
	w.motor:tick(STILL)
	check(w.motor.pos == before, "a seized motor does not move itself")
	w.motor:hold(Vector3.new(1, 5, 2))
	check(w.motor.pos == Vector3.new(1, 5, 2), "the wasp moves the body")
	check((Checkpoint.restore(record, w)) and not w.motor.seized and w.motor.mode == "attached", "a return puts the spider back on its feet")
end)

case("ObjectRecord keeps cycles and sharing, and refuses what it does not know", function()
	local Klass = {}
	Klass.__index = Klass
	local a = setmetatable({ name = "a" }, Klass)
	local b = { back = a, list = { a, a }, v = Vector3.new(1, 2, 3), inf = math.huge }
	a.b = b
	local rec = assert(ObjectRecord.capture({ root = a }, { K = Klass }, {}))
	local live = setmetatable({}, Klass)
	local dec = assert(ObjectRecord.decode(rec, { K = Klass }, {}))
	check(ObjectRecord.commit(dec, { root = live }), "committed")
	check(live.name == "a" and live.b.back == live and live.b.list[1] == live and live.b.list[2] == live, "the cycle points at the live root")
	check(live.b.v == Vector3.new(1, 2, 3) and live.b.inf == math.huge, "vectors and infinities")
	check(getmetatable(live) == Klass, "the class")
	local _, why = ObjectRecord.capture({ root = { f = function() end } }, {}, {})
	check(why ~= nil and string.find(why :: string, "root.f", 1, true) ~= nil, "an unnamed function is refused, with where it is: " .. tostring(why))
	local Other = {}
	local _, why2 = ObjectRecord.capture({ root = { x = setmetatable({}, Other) } }, {}, {})
	check(why2 ~= nil, "an unknown class is refused")
	local fn = function() end
	local rec2 = assert(ObjectRecord.capture({ root = { f = fn } }, {}, { cb = fn }))
	local dec2 = assert(ObjectRecord.decode(rec2, {}, { cb = fn }))
	check(dec2.roots.root.f == fn, "a named function comes back as itself")
	check(Json.canonical(rec) ~= nil, "a record is storable as it is")
end)

case("mode rules survive recovery and schema 1 defaults to Standard",function()
 local w=newWorld();tick(w)
 w.life.mode,w.life.rules,w.needs.gentle="free","gentle",true
 local r=assert(Checkpoint.capture(w,0))
 w.life.mode,w.life.rules,w.needs.gentle="main","standard",false
 check(Checkpoint.restore(r,w),"free record restored")
 check(w.life.mode=="free" and w.life.rules=="gentle" and w.needs.gentle,"free rules restored")
 local old=assert(Checkpoint.capture(w,0));old.schema_version=1;old.life_rules=nil
 check(Checkpoint.restore(old,w),"old schema restored")
 check(w.life.mode=="main" and not w.needs.gentle,"old defaults Standard")
 r.life_rules.rules="standard"
 local before=fingerprint(w)
 check(not Checkpoint.restore(r,w),"free Standard combination refused")
 check(fingerprint(w)==before,"invalid rules leave world untouched")
end)
case("growth schema 3 restores a moult, migrates old saves and rejects damage atomically",function()
 local w=newWorld()
 for _=1,10 do tick(w) end
 w.life.growth:eat(.9);rest(w)
 check(w.life.growth:isMoulting(),"moult starts")
 local record=assert(Checkpoint.capture(w,0))
 local left=w.life.growth.moultingHoursLeft
 w.life.growth:passHours(20,HOME)
 check(Checkpoint.restore(record,w),"mid-moult restored")
 check(w.life.growth.stage==0 and math.abs(w.life.growth.moultingHoursLeft-left)<1e-8,"progress rewound together")
 w.life.growth:passHours(left,HOME)
 local adult=assert(Checkpoint.capture(w,0))
 check(#(Checkpoint.check(adult,w))==0,"grown state and skin accepted")
 local damaged=Json.copy(adult)
 for _,o in damaged.world.objects do
  if o.c=="Growth" then for _,e in o.e do if e[1]=="stage" then e[2]=8 end end end
 end
 local before=fingerprint(w)
 check(not Checkpoint.restore(damaged,w) and fingerprint(w)==before,"invalid stage leaves world untouched")
 -- Simulate records authored before growth: no Growth object and no ledger cursor.
 for _,schema in {1,2} do
  local old=newWorld();old.life.growth=nil;old.life.grantedSeen=nil
  local legacy=assert(Checkpoint.capture(old,0));legacy.schema_version=schema
  check(Checkpoint.restore(legacy,w),"schema "..schema.." migrated")
  check(w.life.growth.stage==0 and w.life.grantedSeen==w.needs.grantedTotal,"legacy food not counted again")
  legacy.schema_version=3
  check(not Checkpoint.restore(legacy,w),"missing growth in schema 3 refused")
 end
end)

case("mixed prey keeps the fruit profile across a rest",function()
 local w=newWorld()
 w.prey.mixed=true
 local perch=w.prey.flies[3].perch
 w.prey.serial=5
 local f=w.prey:spawn(perch)
 check(f.profile==Species.fruit_fly_prototype and f.nutrition==.175,"third spawn is the smaller meal")
 -- Use the existing fly's slot, preserving the graph's one-occupant rule.
 local old=w.prey.flies[3];old.perch=nil
 table.remove(w.prey.flies,3)
 local record=assert(Checkpoint.capture(w,0))
 check(Checkpoint.restore(record,w),"mixed checkpoint restores")
 local found=false
 for _,prey in w.prey.flies do if prey.id==f.id then found=prey.profile==Species.fruit_fly_prototype and prey.nutrition==.175 end end
 check(found,"restored fruit fly keeps its identity and food")
end)
case("fallen tip timer survives rest and invalid data is atomic",function()
 local Breakaway=require("../src/Shared/Habitat/Breakaway")
 local w=newWorld();w.breakaway=Breakaway.new(sill)
 w.breakaway:apply({left=4})
 local record=assert(Checkpoint.capture(w,0))
 w.breakaway:apply(nil)
 check(Checkpoint.restore(record,w) and w.breakaway.left==4,"fallen leaf restored")
 record.breakaway.left=-1
 check(not Checkpoint.restore(record,w) and w.breakaway.left==4,"bad timer refused without mutation")
 record.breakaway=nil
 check(Checkpoint.restore(record,w) and w.breakaway.left==0,"older checkpoint has intact tip")
end)
case("rival state is kept and malformed rival is refused",function()
 local Rival=require("../src/Shared/Predator/RivalSpider")
 local w=newWorld();w.life.rival=Rival.new();w.life.rival.state="consumed";w.life.rival.food=0
 local rec=assert(Checkpoint.capture(w,0))
 w.life.rival=nil
 check(Checkpoint.restore(rec,w) and w.life.rival.state=="consumed","eaten rival cannot respawn on rest")
 w.life.rival.food=-1
 local bad=assert(Checkpoint.capture(w,0))
 check(not Checkpoint.restore(bad,w),"invalid rival food refused")
end)
print(`CHECKPOINT passed={passed} failed={failed}`)
if failed > 0 then error("CHECKPOINT failed") end
