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
local WorldMap = require("../src/Shared/World/WorldMap")

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
	check(w.life.checkpoints == 1 and w.life.notice == "Last rest kept.", `kept: {w.life.notice}`)
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
	check(not none.ok and none.message == "no last rest to return to", "nothing to return to")
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
-- ---------------------------------------------------------------- ROBLOX-96: the prey per region (the garden root)
local Garden = require("../src/Shared/World/Garden")
local WorldMap2 = require("../src/Shared/World/WorldMap")
local WorldBuild = require("../src/Shared/World/WorldBuild")
local Woodlouse = require("../src/Shared/Prey/Woodlouse")
local Region = require("../src/Shared/World/Region")
local SaveRest = require("../src/Shared/Persistence/SaveRest")
-- A world with a garden: the sill and the bed as the server builds them, the sill's director at home and the bed's director and woodlice in `garden`, sharing the jaws
-- and the casts, with the spider at home on the sill.
local function gardenWorld(): any
	local folder = WorldBuild.world(workspace, WorldMap2.SEED) -- (under the workspace: the shim's casts see only what is)
	local motor = Motor.new({
		world = folder, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Layout.SPAWN,
		heading = Layout.SPAWN_HEADING, boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX,
	})
	local casts = PreyDirector.casts(folder)
	local prey = PreyDirector.engine(folder, Species.fly_like_prototype, 914, 4, true, nil, casts)
	local bed = WorldMap2.region("bed_a") :: any
	local spec = Garden.prey(bed)
	local bedPrey = PreyDirector.engine(folder, Species.fungus_gnat_prototype, spec.seed, spec.target, false, spec, casts)
	bedPrey.feeding = prey.feeding
	local soil: any, boxes = nil, {}
	for _, piece in Region.pieces(bed) do
		if piece.id == "bed_a_soil" then soil = { min = piece.lo, max = piece.hi } elseif piece.lo.Y <= -89.99 then table.insert(boxes, { min = piece.lo, max = piece.hi }) end
	end
	local bugs = Woodlouse.new(Garden.bugs(bed), soil, boxes)
	local memory = ObservationMemory.new()
	local sensor = Sensor.new(memory)
	sensor:configureFrom(Species.phidippus_audax_prototype.perception)
	local needs = NeedsModel.new(true, false)
	prey.feeding.needs = needs
	local w: any = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs, garden = { bed_a = { prey = bedPrey, bugs = bugs } } }
	w.life = LifeLoop.new(needs, nil)
	motor:place(HOME, Vector3.yAxis, Vector3.new(1, 0, 0))
	return w, bedPrey, bugs
end
-- Ticks the garden's director and woodlice as PreyWorld would with the spider in the bed, the sill's waiting.
local function gardenTick(w: any, bedPrey: any, bugs: any, at: Vector3)
	local obs = { eye = at, gaze = Vector3.new(0, 0, -1), up = Vector3.yAxis, heading = Vector3.new(0, 0, -1) }
	bedPrey:before(DT, at, obs, w.sensor, cast, camera)
	bugs:step(DT, at)
	w.prey:after(DT, w.motor, w.sensor, cast)
	bedPrey:afterShared(w.motor, w.sensor, cast)
end
local function gardenText(w: any): string
	local saved = { w.prey.cpu, w.prey.beforeCost, w.sensor._ring, w.garden.bed_a.prey.cpu, w.garden.bed_a.prey.beforeCost }
	w.prey.cpu, w.prey.beforeCost, w.sensor._ring, w.garden.bed_a.prey.cpu, w.garden.bed_a.prey.beforeCost = {}, 0, {}, {}, 0
	local rec = assert(ObjectRecord.capture({ prey = w.prey, sensor = w.sensor, memory = w.memory, needs = w.needs, life = w.life, garden = w.garden }, Checkpoint.CLASSES, Checkpoint.refs(w)))
	w.prey.cpu, w.prey.beforeCost, w.sensor._ring, w.garden.bed_a.prey.cpu, w.garden.bed_a.prey.beforeCost = saved[1], saved[2], saved[3], saved[4], saved[5]
	local text = assert(Json.canonical(rec))
	-- (what a return to a rest itself writes: the notice and its seconds, the grace; not the world's state)
	for _, key in { "notice", "noticeSeconds", "restoreGrace" } do text = string.gsub(text, '%["' .. key .. '",[^%]]*%]', "") end
	return text
end
case("the bed's prey and woodlice are kept with the rest and put back where they were; the sill's record is as it was", function()
	local w, bedPrey, bugs = gardenWorld()
	check(#bedPrey.flies == 6 and #bugs.lice == 4 and bedPrey.feeding == w.prey.feeding, "a garden world: six prey in the bed, four woodlice, one jaws")
	for _ = 1, 600 do gardenTick(w, bedPrey, bugs, Vector3.new(-20, -89.69, -30)) end
	-- the woodlice went under cover as the spider stood in the bed? one near it did, maybe; either way the state is what is kept
	check(Checkpoint.boundaryProblem(w) == "", "a rest can be kept")
	local record = assert(Checkpoint.capture(w, 0))
	check(record.world.roots.garden ~= nil and record.world.roots.prey ~= nil, "the record has the garden root beside the prey")
	check(#SaveRest.check("main", record) == 0, "the server's rest check accepts it: " .. table.concat(SaveRest.check("main", record), "; "))
	local before = gardenText(w)
	local kept = {}
	for i, f in bedPrey.flies do kept[i] = { id = f.id, pos = f.position, state = f.state } end
	local lice = {}
	for i, l in bugs.lice do lice[i] = { pos = l.position, state = l.state } end
	-- the world runs on, then the rest is returned to
	for _ = 1, 600 do gardenTick(w, bedPrey, bugs, Vector3.new(-5, -89.69, -40)) end
	check(gardenText(w) ~= before, "the garden moved on")
	local ok, problems = Checkpoint.restore(record, w)
	check(ok, "restored: " .. table.concat(problems, "; "))
	local d2 = w.garden.bed_a.prey
	check(d2 ~= nil and d2 ~= bedPrey and getmetatable(d2) == PreyDirector and #d2.flies == #kept, "the bed's director is rebuilt from the record")
	for i, f in d2.flies do
		local k = kept[i]
		check(k ~= nil and k.id == f.id and (k.pos - f.position).Magnitude < 1e-9 and k.state == f.state, `{f.id} is back where it was`)
	end
	check(d2.feeding == w.prey.feeding and d2.graph.cast == w.prey.graph.cast and d2.probe == w.prey.probe, "sharing the jaws and the casts by name")
	local b2 = w.garden.bed_a.bugs
	check(b2 ~= nil and getmetatable(b2) == Woodlouse and #b2.lice == #lice, "the woodlice are rebuilt")
	for i, l in b2.lice do check((lice[i].pos - l.position).Magnitude < 1e-9 and lice[i].state == l.state, `louse {i} is where it was`) end
	do
		local after = gardenText(w)
		if after ~= before then
			local i = 1
			while i <= #before and string.byte(before, i) == string.byte(after, i) do i += 1 end
			print("garden restore, first difference:\n  " .. string.sub(before, math.max(1, i - 200), i + 100) .. "\n  " .. string.sub(after, math.max(1, i - 200), i + 100))
		end
		check(after == before, "the whole world, garden included, is the record's again")
	end
	check(#w.garden.bed_a.prey.cpu == 0, "the bed director's cpu window is empty after a restore")
	-- and it runs on from there exactly as it did the first time
	local w2, bp2, bg2 = gardenWorld()
	check(Checkpoint.restore(record, w2), "the same record into a fresh world")
	for _ = 1, 300 do gardenTick(w, w.garden.bed_a.prey, w.garden.bed_a.bugs, Vector3.new(-5, -89.69, -40)); gardenTick(w2, w2.garden.bed_a.prey, w2.garden.bed_a.bugs, Vector3.new(-5, -89.69, -40)) end
	check(gardenText(w) == gardenText(w2), "two worlds restored from it run on identically")
end)
case("an old record (sill-only prey, no garden) restores unchanged and leaves the live garden as it is; a garden that is not in order is refused", function()
	local w, bedPrey, bugs = gardenWorld()
	for _ = 1, 120 do gardenTick(w, bedPrey, bugs, Vector3.new(-20, -89.69, -30)) end
	local record = assert(Checkpoint.capture(w, 0))
	local old = Json.copy(record)
	old.world.roots.garden = nil
	old.world_map = nil -- (a rest from before the world: put back at the spawn)
	local liveGarden = w.garden
	local liveDirector = w.garden.bed_a.prey
	local ok, problems = Checkpoint.restore(old, w)
	check(ok, "an old record restores: " .. table.concat(problems, "; "))
	check(w.garden == liveGarden and w.garden.bed_a.prey == liveDirector and #liveDirector.flies == 6, "the live garden is untouched: nothing rerolled")
	check(#SaveRest.check("main", old) == 0, "and the server accepts it")
	-- a garden world's record into a world without a garden: the live world is missing a part
	local plain = newWorld()
	local ok2, problems2 = Checkpoint.restore(record, plain)
	check(not ok2 and problems2[1] == "the live world is missing a part", "a garden record needs a garden: " .. table.concat(problems2, "; "))
	-- refusals, each on a copy, the live world untouched
	local function refusedGarden(label: string, edit: (any) -> (), part: string)
		local r = Json.copy(record)
		edit(r)
		local ok3, problems3 = Checkpoint.restore(r, w)
		local text = table.concat(problems3, "; ")
		check(not ok3 and string.find(text, part, 1, true) ~= nil, `{label} is refused ({if ok3 then "ACCEPTED" else text})`)
		local server = SaveRest.check("main", r)
		check(#server > 0, `and the server refuses it too ({table.concat(server, "; ")})`)
	end
	local function objectOf(r: any, ref: any): any return r.world.objects[ref["$o"]] end
	local function entry(o: any, key: string): any
		for _, e in o.e do if e[1] == key then return e end end
		return nil
	end
	refusedGarden("a region the map does not have", function(r)
		local g = objectOf(r, r.world.roots.garden)
		entry(g, "bed_a")[1] = "moon"
	end, "is not a region with prey")
	refusedGarden("a bed fly with more meal than a gnat", function(r)
		local g = objectOf(r, r.world.roots.garden)
		local bedEntry = objectOf(r, entry(g, "bed_a")[2])
		local director = objectOf(r, entry(bedEntry, "prey")[2])
		local flies = objectOf(r, entry(director, "flies")[2])
		local f = objectOf(r, flies.e[1][2])
		entry(f, "nutrition")[2] = 0.5
	end, "nutrition is out of range")
	refusedGarden("a bed director with jaws of its own", function(r)
		local g = objectOf(r, r.world.roots.garden)
		local bedEntry = objectOf(r, entry(g, "bed_a")[2])
		local director = objectOf(r, entry(bedEntry, "prey")[2])
		local feeding = objectOf(r, entry(director, "feeding")[2])
		local copy = { c = feeding.c, e = {} }
		for _, e in feeding.e do table.insert(copy.e, { e[1], e[2] }) end
		table.insert(r.world.objects, copy)
		entry(director, "feeding")[2] = { ["$o"] = #r.world.objects }
	end, "does not eat with the sill's jaws")
	refusedGarden("a woodlouse outside the bed", function(r)
		local g = objectOf(r, r.world.roots.garden)
		local bedEntry = objectOf(r, entry(g, "bed_a")[2])
		local colony = objectOf(r, entry(bedEntry, "bugs")[2])
		local lice = objectOf(r, entry(colony, "lice")[2])
		local l = objectOf(r, lice.e[1][2])
		entry(l, "position")[2] = { ["$v"] = { 0, 0, 0 } }
	end, "outside its region")
	check(w.garden.bed_a.prey == liveDirector and #liveDirector.flies == 6, "the live garden is still untouched after the refusals")
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
case("the daily rival: the day it was eaten round-trips, a new one still comes the next morning, a bad day is refused (ROBLOX-67)",function()
 local Rival=require("../src/Shared/Predator/RivalSpider")
 local w=newWorld();w.life.rival=Rival.new();w.life.rival.state="consumed";w.life.rival.food=0;w.life.rival.day=4
 local rec=assert(Checkpoint.capture(w,0))
 w.life.rival=nil
 check(Checkpoint.restore(rec,w) and w.life.rival.state=="consumed" and w.life.rival.day==4,"the day it was eaten is kept")
 local s={position=Vector3.new(-25,.31,6),previous=Vector3.new(-25,.31,6),heading=Vector3.xAxis,day=4,hour=20,meals=3,
  resting=false,safe=false,wasp=false,gentle=false,grounded=true,moving=false,airborne=false,onLine=false,holding=false,striking=false}
 Rival.step(w.life.rival,1/60,s,function() return false end)
 check(w.life.rival.state=="consumed","the same evening nothing new comes")
 s.day=5;s.hour=7
 Rival.step(w.life.rival,1/60,s,function() return false end)
 check(w.life.rival.state=="patrol" and w.life.rival.day==nil and w.life.rival.food==Rival.FOOD,"the next morning a fresh rival is on the sill")
 check(Checkpoint.restore(rec,w) and w.life.rival.state=="consumed","a return to the rest brings back the state of that rest")
 for _,bad in {-1,0/0,math.huge,"4",true} do
  w.life.rival.day=bad
  local badRec=assert(Checkpoint.capture(w,0))
  check(not Checkpoint.restore(badRec,w),`a rival eaten on day {tostring(bad)} is refused`)
 end
 -- A record from before the daily rival has no day at all: it restores, and a new rival comes the morning after it is first seen.
 local old=newWorld();old.life.rival=Rival.new();old.life.rival.state="consumed";old.life.rival.food=0
 local oldRec=assert(Checkpoint.capture(old,0))
 check(oldRec.world~=nil and Checkpoint.restore(oldRec,old) and old.life.rival.day==nil,"an older record of an eaten rival still restores")
end)
case("the roaming rival (ROBLOX-69): a checkpoint taken mid-climb brings it back on the same wall, a rest elsewhere in its walk is not kept, bad places are refused", function()
 local Rival=require("../src/Shared/Predator/RivalSpider")
 local Drive=require("../src/Shared/Predator/RivalDrive")
 local Route=require("../src/Shared/Predator/RivalRoute")
 local w=newWorld()
 local m=Motor.new({world=sill,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,spawn=Vector3.new(25,.31,8),heading=Vector3.new(-1,0,0),
  boundsMin=Layout.PLAY_BOUNDS_MIN,boundsMax=Layout.PLAY_BOUNDS_MAX,probeParent=sill})
 local d=Drive.new(m,function() return true end)
 local r=Rival.new();r.state="patrol";w.life.rival=r
 m:place(Vector3.new(25,.31,8),Vector3.yAxis,Vector3.new(-1,0,0));r.position,r.previous,r.origin,r.heading=m.pos,m.pos,m.pos,m.heading;d.prevState="patrol"
 -- Its next place is a stem (the leg picks it).
 local want
 for leg=0,300 do
  r.leg=leg
  local pick=d:_pickWaypoint(r)
  if pick and string.sub(Route.faces()[pick.face].piece,1,5)=="stem_" and pick.pos.X>0 then want=leg break end
 end
 check(want~=nil,"a patrol place on a stem is found")
 r.leg=want or 0
 local snap={position=Vector3.new(-25,.31,6),previous=Vector3.new(-25,.31,6),up=Vector3.yAxis,grounded=true,heading=Vector3.xAxis,day=3,hour=12,meals=2,
  resting=false,safe=false,wasp=false,gentle=false,moving=false,airborne=false,onLine=false,holding=false,striking=false,drive=d}
 local function run(ticks:number)
  for _=1,ticks do Rival.step(r,DT,snap,function() return true end);d:update(r,DT,snap) end
 end
 local climbing=false
 for _=1,60*150 do
  run(1)
  if r.up.Y<.5 then climbing=true break end
 end
 check(climbing,"it is on a wall or a stem")
 run(40)
 local rec=assert(Checkpoint.capture(w,0))
 local at,up,leg,heading=r.position,r.up,r.leg,r.heading
 run(60*20)
 local later=r.position
 check((later-at).Magnitude>1,"it walked on after the checkpoint")
 check(Checkpoint.restore(rec,w),"the checkpoint restores")
 check(w.life.rival.state=="patrol" and (w.life.rival.position-at).Magnitude<1e-9 and (w.life.rival.up-up).Magnitude<1e-9 and w.life.rival.leg==leg,"the rival is back where it was, on the same face, on the same leg")
 -- The legs follow the state, then carry on to the same place.
 r=w.life.rival
 snap.drive=d
 local before=d.stats.resets
 run(1)
 check(d.stats.resets>before and (m.pos-at).Magnitude<.2 and (m.up-up).Magnitude<1e-6,"its motor stands where the record says")
 run(60*120)
 check(r.leg>leg and Rival.valid(r),"it carries on to the place it was going to, and the next leg begins")
 -- A fresh drive on the same record (a new session) does the same.
 check(Checkpoint.restore(rec,w),"restored again")
 r=w.life.rival
 local m2=Motor.new({world=sill,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,spawn=Vector3.new(25,.31,8),heading=Vector3.new(-1,0,0),
  boundsMin=Layout.PLAY_BOUNDS_MIN,boundsMax=Layout.PLAY_BOUNDS_MAX,probeParent=sill})
 local d2=Drive.new(m2,function() return true end)
 d2.prevState="patrol"
 snap.drive=d2
 for _=1,10 do Rival.step(r,DT,snap,function() return true end);d2:update(r,DT,snap) end
 check((m2.pos-at).Magnitude<.2 and (m2.up-up).Magnitude<1e-6,"a new session's legs stand there too")
 -- Refusals: in the crack, outside the sill, a bad face, a bad leg.
 local good=assert(Checkpoint.capture(w,0))
 for name,mut in {
  crack=function(x) x.position=Vector3.new(-26,.31,6) end,
  outside=function(x) x.position=Vector3.new(200,.31,6) end,
  up=function(x) x.up=Vector3.new(0,0,0) end,
  leg=function(x) x.leg=-3 end,
  legfrac=function(x) x.leg=1.5 end,
 } do
  local x=w.life.rival
  local keep={x.position,x.up,x.leg}
  mut(x)
  local bad=assert(Checkpoint.capture(w,0))
  check(not Checkpoint.restore(bad,w),`a rival {name} is refused`)
  x.position,x.up,x.leg=keep[1],keep[2],keep[3]
 end
 check(Checkpoint.restore(good,w),"and the good record still restores")
 -- A record from before the roaming rival (no up, no leg) restores and means the floor.
 local old=newWorld();old.life.rival=Rival.new();old.life.rival.state="patrol";old.life.rival.up=nil;old.life.rival.leg=nil
 local oldRec=assert(Checkpoint.capture(old,0))
 check(Checkpoint.restore(oldRec,old) and old.life.rival.state=="patrol","an older record of a patrolling rival restores")
end)
case("the wasp takes the rival (ROBLOX-70): a rest taken while it hangs under the wasp, one after it is gone, why it is gone, and the next morning", function()
 local Rival=require("../src/Shared/Predator/RivalSpider")
 local w=newWorld();local r=Rival.new();r.state="patrol";r.position=Vector3.new(12,.31,3);w.life.rival=r
 check(Rival.seize(r),"the wasp seizes the rival")
 r.position=Vector3.new(27,16,2)
 local held=assert(Checkpoint.capture(w,0))
 -- A rest taken then restores (the wasp's visit is not kept, so the rival is carried off at once).
 w.life.rival=nil
 check(Checkpoint.restore(held,w) and w.life.rival.state=="taken","a record taken under the wasp restores")
 local s={position=Vector3.new(-25,.31,6),previous=Vector3.new(-25,.31,6),heading=Vector3.xAxis,day=3,hour=13,meals=2,
  resting=true,safe=true,wasp=false,gentle=false,grounded=true,moving=false,airborne=false,onLine=false,holding=false,striking=false,taken=false}
 local ev=Rival.step(w.life.rival,DT,s,function() return false end)
 check(ev=="taken" and w.life.rival.state=="consumed" and w.life.rival.day==3 and w.life.rival.fate=="taken by the wasp","with no wasp holding it, it is gone for today, and why")
 local gone=assert(Checkpoint.capture(w,0))
 w.life.rival=nil
 check(Checkpoint.restore(gone,w) and w.life.rival.state=="consumed" and w.life.rival.fate=="taken by the wasp" and w.life.rival.day==3,"that record restores with its reason and its day")
 s.day,s.hour,s.resting,s.safe=4,7.5,false,false
 Rival.step(w.life.rival,DT,s,function() return false end)
 check(w.life.rival.state=="patrol" and w.life.rival.fate==nil and w.life.rival.food==Rival.FOOD,"the next morning a new rival")
 check(Checkpoint.restore(gone,w) and w.life.rival.state=="consumed","a return to that rest brings back the day's state: no second rival today")
 for _,bad in {3,true,"elf"} do
  w.life.rival.fate=bad
  local rec=assert(Checkpoint.capture(w,0))
  check(not Checkpoint.restore(rec,w),`a rival whose fate is {tostring(bad)} is refused`)
 end
end)
case("the rival's contest (ROBLOX-73): its count is kept, a return to a rest gives the same outcome for the same strike (no rerolling), a bad count or flag is refused",function()
 local Rival=require("../src/Shared/Predator/RivalSpider")
 local w=newWorld();local r=Rival.new();r.state="stalk";r.position=Vector3.new(24,.31,8);r.previous=r.position;r.contests=4;w.life.rival=r
 local rec=assert(Checkpoint.capture(w,0))
 local function strike(day,gentle)
  return {position=r.position+Vector3.xAxis*.2,previous=r.position+Vector3.xAxis*.2,heading=Vector3.xAxis,day=day,hour=12,meals=3,seed=914,
   resting=false,safe=false,wasp=false,gentle=gentle==true,grounded=true,moving=false,airborne=false,onLine=false,holding=false,striking=true}
 end
 -- find a day on which the fifth contest is not a catch, so there is a rival left to compare
 local day=1
 while Rival.contest(914,day,4)=="captured" do day+=1 end
 local first,cost1=Rival.step(w.life.rival,1/60,strike(day),function() return false end)
 check((first=="sprang" or first=="counter") and w.life.rival.contests==5 and w.life.rival.state=="recover","the strike is a contest, and the rival recovers")
 local after=assert(Checkpoint.capture(w,0))
 check(Checkpoint.restore(after,w) and w.life.rival.contests==5 and w.life.rival.state=="recover","a rest taken after it keeps the count")
 for _=1,4 do
  check(Checkpoint.restore(rec,w) and w.life.rival.contests==4 and w.life.rival.state=="stalk","a return to the earlier rest brings back its count")
  r=w.life.rival
  local again,cost2=Rival.step(w.life.rival,1/60,strike(day),function() return false end)
  check(again==first and cost2==cost1 and w.life.rival.contests==5,"and the same strike on the same day gives the same outcome again")
 end
 -- the gentle modes: the same outcome, nothing lost
 Checkpoint.restore(rec,w);r=w.life.rival
 local g,gcost=Rival.step(w.life.rival,1/60,strike(day,true),function() return false end)
 check(g==Rival.contest(914,day,4,true) and (g~="counter" or gcost==0),"gentle: the gentle odds (ROBLOX-91), the same stream, and a counter-bite costs nothing")
 -- bad records
 for name,set in {["a negative count"]=function(x) x.contests=-1 end,["a fractional count"]=function(x) x.contests=2.5 end,["a count that is not a number"]=function(x) x.contests="3" end,
   ["a count that is not finite"]=function(x) x.contests=0/0 end,["a spared that is not a boolean"]=function(x) x.spared=1 end} do
  Checkpoint.restore(rec,w)
  set(w.life.rival)
  local bad=assert(Checkpoint.capture(w,0))
  check(not Checkpoint.restore(bad,w),`a rival with {name} is refused`)
 end
 -- a record from before the contest has neither, and restores as one that has had none
 local old=newWorld();old.life.rival=Rival.new();old.life.rival.state="stalk";old.life.rival.position=Vector3.new(24,.31,8);old.life.rival.contests=nil;old.life.rival.spared=nil
 local oldRec=assert(Checkpoint.capture(old,0))
 check(Checkpoint.restore(oldRec,old) and old.life.rival.state=="stalk" and (old.life.rival.contests or 0)==0,"an older record restores")
end)
case("the struggle with a caught rival (ROBLOX-77) is never recorded: no rest is taken while it is held, a return lands at the rest as always, and a held record is valid",function()
 local Rival=require("../src/Shared/Predator/RivalSpider")
 local Grip=require("../src/Shared/Predator/RivalGrip")
 local w=newWorld();local r=Rival.new();r.state="patrol";r.position=Vector3.new(24,.31,8);r.previous=r.position;w.life.rival=r
 local rest=assert(Checkpoint.capture(w,0))
 -- caught: held and fighting
 r.state,r.subdued="captured",false
 check(Checkpoint.boundaryProblem(w)=="the rival in the jaws is still struggling","no rest while the rival fights the grip: "..Checkpoint.boundaryProblem(w))
 r.subdued=true
 check(Checkpoint.boundaryProblem(w)=="the spider is eating its rival","and none while it is eaten (as before): "..Checkpoint.boundaryProblem(w))
 r.subdued=nil
 check(Checkpoint.boundaryProblem(w)=="the spider is eating its rival","(a held rival from an older record is eaten)")
 -- a return to the earlier rest: the rival is as it was at the rest, with no struggle left and a grip that has nothing to hold
 r=w.life.rival;r.state,r.subdued="captured",false
 local grip=Grip.new();local s={grounded=true,day=2,seed=914}
 check(Grip.step(grip,r,1/60,s)=="begin" and Grip.active(grip),"(the fight is on)")
 check(Checkpoint.restore(rest,w) and w.life.rival.state=="patrol" and w.life.rival.subdued==nil and Rival.valid(w.life.rival),"a return lands at the rest: the rival patrols, nothing struggles")
 check(Grip.step(grip,w.life.rival,1/60,s)=="" and not Grip.active(grip),"and the old grip lets go of it")
 -- a record that does hold a fighting rival (made by hand) is valid and restores; whoever finds it begins a fresh grip
 local held=w.life.rival;held.state,held.subdued="captured",false
 local rec=assert(Checkpoint.capture(w,0))
 check(Checkpoint.restore(rec,w) and w.life.rival.state=="captured" and w.life.rival.subdued==false,"a held, fighting rival restores as it was")
 check(Grip.step(Grip.new(),w.life.rival,1/60,s)=="begin","and a fresh grip begins on it")
 held=w.life.rival;held.subdued=1
 local bad=assert(Checkpoint.capture(w,0))
 check(not Checkpoint.restore(bad,w),"a subdued that is not true or false is refused")
end)
-- ---------------------------------------------------------------------------------------------- the profiling windows (ROBLOX-91)
case("a capture holds neither the prey director's cpu window nor the sensor's cost ring, and the live ones are untouched", function()
	local w = newWorld()
	for _ = 1, 150 do tick(w) end
	check(#w.prey.cpu > 100 and #w.sensor._ring > 50, `(the live windows are full: {#w.prey.cpu} and {#w.sensor._ring})`)
	local cpuBefore, ringBefore = #w.prey.cpu, #w.sensor._ring
	local fp = fingerprint(w)
	local record = assert(Checkpoint.capture(w, 0))
	check(fingerprint(w) == fp, "capturing changes nothing in the world (the fingerprint is the same)")
	check(#w.prey.cpu == cpuBefore and #w.sensor._ring == ringBefore, "and the live windows are still there")
	-- no object of the record holds a long list of timing floats: no `cpu` entry of the prey director, no `_ring` of the sensor
	local function entriesNamed(key: string): number
		local n = 0
		for _, o in record.world.objects do
			for _, e in o.e do if e[1] == key then n += 1 end end
		end
		return n
	end
	local preyObj = record.world.objects[record.world.roots.prey["$o"]]
	local sensorObj = record.world.objects[record.world.roots.sensor["$o"]]
	local function listOf(obj: any, key: string): any
		for _, e in obj.e do if e[1] == key then return e[2] end end
		return nil
	end
	local cpuRef, ringRef = listOf(preyObj, "cpu"), listOf(sensorObj, "_ring")
	check(cpuRef ~= nil and #record.world.objects[cpuRef["$o"]].e == 0, "the prey's cpu is an empty list in the record")
	check(ringRef ~= nil and #record.world.objects[ringRef["$o"]].e == 0, "and the sensor's ring")
	local text = assert(Json.canonical(record))
	local old = assert(ObjectRecord.capture({ prey = w.prey, sensor = w.sensor, memory = w.memory, needs = w.needs, life = w.life }, Checkpoint.CLASSES, Checkpoint.refs(w)))
	local oldText = assert(Json.canonical(old))
	check(#oldText - #text > 4000, `the record is smaller by the floats ({#oldText} against {#text} characters)`)
	check(entriesNamed("cpu") == 1 and entriesNamed("_ring") == 1, "(each key is there, once, and empty)")
	-- two captures of the same world are the same record, which the timing floats made impossible
	local again = assert(Checkpoint.capture(w, 0))
	check(assert(Json.canonical(again)) == text, "two captures of one world are identical")
	-- restoring leaves the windows empty and the sensor's cost reading well formed
	local restored = Checkpoint.restore(record, w)
	check(restored and #w.prey.cpu == 0 and #w.sensor._ring == 0, "a restore leaves both empty")
	check(w.sensor:costPercentile(0.5) == 0, "and the sensor's cost reading has nothing to say (no reading from nothing)")
	for _ = 1, 10 do tick(w) end
	check(#w.prey.cpu == 10 and w.sensor:costTicks() > 0 and w.sensor:costPercentile(0.5) >= 0, "they fill again as the world runs")
	-- an older record that holds the windows restores too, and the windows come back empty
	local oldRecord = Json.copy(record)
	oldRecord.world = old
	check(#(Checkpoint.check(oldRecord, w)) == 0, "a record made before (with the windows in it) is good")
	check(Checkpoint.restore(oldRecord, w) and #w.prey.cpu == 0 and #w.sensor._ring == 0, "and restores with them empty")
	check(w.sensor:costPercentile(0.9) == 0, "without a reading")
end)

-- ---------------------------------------------------------------------------------------------- where in the world (ROBLOX-94)
case("a rest records where in the world it was kept, and a record from before means the sill (ROBLOX-94)", function()
	local w = newWorld()
	for _ = 1, 120 do tick(w) end
	rest(w)
	local record = w.store:loadBest().record
	local map = record.world_map
	check(map ~= nil and map.seed == 914 and map.revision == WorldMap.REVISION and map.region == "sill" and map.retreat == "sill_crevice" and type(map.diffs) == "table" and #map.diffs == 0,
		"a rest at home records the seed, the revision, the sill, the crevice and no changes")
	check(record.player.retreat_id == "sill_crevice", "and the player block still names the crevice")
	check(record.world ~= nil and record.world.roots ~= nil, "(the recorded world is still the object graph)")
	check(not Checkpoint.worldMoved(record), "this is the world it was kept in")
	-- Away from the crack the retreat is empty and the region is the same.
	w.motor:place(Vector3.new(8, 0.31, 4), Vector3.yAxis, Vector3.new(1, 0, 0))
	local away = assert(Checkpoint.capture(w, 0))
	check(away.world_map.region == "sill" and away.world_map.retreat == "" and away.player.retreat_id == "" and #(Checkpoint.check(away, w)) == 0, "away from the crack: still the sill, no retreat, a good record")
	-- It is storable as it is, the empty list of changes included, and a copy of what a store hands back is as good.
	local text = assert(Json.canonical(record))
	check(string.find(text, '"world_map":{"diffs":[],"region":"sill","retreat":"sill_crevice","revision":"' .. WorldMap.REVISION .. '","seed":914}', 1, true) ~= nil, "(its stored text: " .. string.sub(text, (string.find(text, '"world_map"', 1, true) or 1), (string.find(text, '"world_map"', 1, true) or 1) + 110) .. ")")
	check(#(Checkpoint.check(Json.copy(record), w)) == 0, "and a copy of it is a good record")
	-- A record from before there was a world has no such block, and means the sill of the default world with no changes, kept under the first revision of the world
	-- (ROBLOX-95: world-1, before the back frame opened): a good record, from a world that has moved since, so it is put back at the sill's spawn with the notice.
	local old = Json.copy(record)
	old.world_map = nil
	check(#(Checkpoint.check(old, w)) == 0 and Checkpoint.worldMoved(old) and WorldMap.FIRST_REVISION == "world-1" and WorldMap.REVISION ~= WorldMap.FIRST_REVISION,
		"a record without one is good, and from the world as it was before the sash was raised")
	local fp = fingerprint(w)
	check(Checkpoint.restore(old, w), "and restores")
	local spawn = Layout.SPAWN + Vector3.new(0, 0.31, 0)
	check((w.motor.pos - spawn).Magnitude < 1e-6 and not Layout.inRetreat(w.motor.pos) and fingerprint(w) ~= fp, "at the sill's spawn, not where it was kept (the geometry has moved since)")
	check(string.find(w.life.notice, "the world has changed since you rested", 1, true) ~= nil, "with the notice that says so")
	local oldAway = Json.copy(away)
	oldAway.world_map = nil
	check(Checkpoint.restore(oldAway, w) and (w.motor.pos - spawn).Magnitude < 1e-6, "an old record away from the crack is put back at the spawn too")
	-- An old record's place is not tested (it is not used), so one outside the sill is no longer refused for it; a retreat that is not on the map still is.
	local far = Json.copy(old)
	far.player.position = { 900, 1, 1 }
	check(#(Checkpoint.check(far, w)) == 0 and Checkpoint.restore(far, w) and (w.motor.pos - spawn).Magnitude < 1e-6, "an old record's place is not trusted: one from outside the sill comes back at the spawn")
	local ghost = Json.copy(old)
	ghost.player.retreat_id = "stone"
	check(string.find(table.concat(Checkpoint.check(ghost, w), "; "), "unknown retreat", 1, true) ~= nil, "and an old record in a retreat that is not on the map is refused")
	-- The current revision's record from the sill is as trusted as ever: it comes back where it was kept.
	check(Checkpoint.restore(record, w) and (w.motor.pos - HOME).Magnitude < 1e-6 and Layout.inRetreat(w.motor.pos), "a rest kept under world-2 comes back in the crack")
end)

case("a rest under the bed's stone (ROBLOX-95): it records the bed and its stone, is checked against the bed, and comes back there", function()
	local w = newWorld()
	for _ = 1, 60 do tick(w) end
	local under = Vector3.new(11, -89.69, -50)
	w.motor:place(under, Vector3.yAxis, Vector3.new(0, 0, 1))
	local record = assert(Checkpoint.capture(w, 0))
	check(record.world_map.region == "bed_a" and record.world_map.retreat == "bed_a_stone" and record.player.retreat_id == "bed_a_stone" and record.world_map.revision == "world-2",
		"a rest under the stone records bed_a, bed_a_stone and world-2")
	check(#(Checkpoint.check(record, w)) == 0 and #(Checkpoint.check(Json.copy(record), w)) == 0, "a good record, and a stored copy of it")
	w.motor:place(Layout.SPAWN + Vector3.new(0, 0.31, 0), Vector3.yAxis, Vector3.xAxis)
	check(Checkpoint.restore(record, w) and (w.motor.pos - under).Magnitude < 1e-6 and WorldMap.inRetreat(w.motor.pos) == "bed_a_stone", "and it comes back under the stone")
	check(string.find(w.life.notice, "the world has changed", 1, true) == nil, "with the usual notice")
	-- the bed's own checks: its bounds, its retreats
	local function problemsOf(change: (any) -> ()): string
		local r = Json.copy(record)
		change(r)
		return table.concat(Checkpoint.check(r, w), "; ")
	end
	check(string.find(problemsOf(function(r) r.player.position = { 11, -89.69, -100 } end), "outside bed_a", 1, true) ~= nil, "a spot outside the bed's bounds is refused, by the bed's name")
	check(string.find(problemsOf(function(r) r.player.position = { -22, 0.31, 6 } end), "outside bed_a", 1, true) ~= nil, "and so is the sill's spawn, for a record that says the bed")
	check(string.find(problemsOf(function(r) r.world_map.retreat = "sill_crevice"; r.player.retreat_id = "sill_crevice" end), "unknown retreat", 1, true) ~= nil, "the crack is not a retreat of the bed")
	check(problemsOf(function(r) r.world_map.region = "house_wall"; r.world_map.retreat = ""; r.player.retreat_id = ""; r.player.position = { 0, -40, -24.31 }; r.player.normal = { 0, 0, -1 } end) == "",
		"a record on the wall's face is a good record (no retreat there)")
	-- a rest in the bed from another revision is put back at the bed's own spawn
	local moved = Json.copy(record)
	moved.world_map.revision = "world-1"
	local bed = WorldMap.region("bed_a") :: WorldMap.Region
	check(Checkpoint.restore(moved, w) and (w.motor.pos - (bed.spawn.pos + Vector3.new(0, 0.31, 0))).Magnitude < 1e-6 and string.find(w.life.notice, "the world has changed", 1, true) ~= nil,
		"a bed rest from another revision comes back at the bed's spawn, with the notice")
end)

case("a region that is not on the map, a spot outside its bounds and a bad world record are refused and change nothing (ROBLOX-94)", function()
	local w = newWorld()
	for _ = 1, 40 do tick(w) end
	local good = assert(Checkpoint.capture(w, 0))
	for _ = 1, 30 do tick(w) end
	local function refused(change: (any) -> (), what: string, expect: string)
		local r = Json.copy(good)
		change(r)
		local before = fingerprint(w)
		local ok, problems = Checkpoint.restore(r, w)
		check(not ok and #problems > 0, `{what}: refused`)
		check(string.find(table.concat(problems, "; "), expect, 1, true) ~= nil, `{what}: says '{expect}' ({table.concat(problems, "; ")})`)
		check(fingerprint(w) == before, `{what}: nothing changed`)
	end
	refused(function(r) r.world_map.region = "garden" end, "a region that is not on the map", "region this world does not have")
	refused(function(r) r.world_map.region = "" end, "an empty region", "region this world does not have")
	refused(function(r) r.world_map.region = 7 end, "a region that is not a name", "region is not a name")
	refused(function(r) r.world_map.region = "garden"; r.world_map.revision = "world-0" end, "a region that is not on the map, from another revision too", "region this world does not have")
	refused(function(r) r.player.position = { 40, 1, 1 } end, "a spot outside the sill's bounds", "outside the windowsill")
	refused(function(r) r.player.position = { -22, 40, 1 } end, "a spot above them", "outside the windowsill")
	refused(function(r) r.world_map.retreat = "stone" end, "a retreat that is not in the region", "unknown retreat")
	refused(function(r) r.world_map.retreat = 4 end, "a retreat that is not a name", "retreat is not a name")
	refused(function(r) r.player.retreat_id = "stone" end, "a player in a retreat that is not on the map", "unknown retreat")
	-- The two retreats of a record are one answer written twice: a record that says both is not one a capture made.
	check(good.player.retreat_id == "sill_crevice" and good.world_map.retreat == "sill_crevice", "(the good record rests in the crack, in both places)")
	refused(function(r) r.world_map.retreat = "" end, "a world record outside the crack while the spider is in it", "retreat disagree")
	refused(function(r) r.player.retreat_id = "" end, "a spider outside the crack while the world record is in it", "retreat disagree")
	for _, seed in { "914", -1, 1.5, 0 / 0, 2 ^ 40, true } do
		refused(function(r) r.world_map.seed = seed end, `a seed of {tostring(seed)}`, "seed")
	end
	for _, rev in { 5, "", string.rep("x", 65), true } do
		refused(function(r) r.world_map.revision = rev end, `a revision of {tostring(rev)}`, "revision")
	end
	for _, diffs in { { 1 }, { kind = "stone" }, { { kind = "stone", region = "sill", id = "a", data = {} } }, "none", 3 } do
		refused(function(r) r.world_map.diffs = diffs end, `changes of {tostring(diffs)}`, "changes")
	end
	refused(function(r) r.world_map = 5 end, "a world record that is not a record", "place in the world")
	refused(function(r) r.world_map = "sill" end, "a world record that is a name", "place in the world")
	check(Checkpoint.restore(good, w), "the good record still restores")
end)

case("a rest from another revision of the world, or another seed, is put back at its region's spawn (ROBLOX-94)", function()
	local w = newWorld()
	for _ = 1, 40 do tick(w) end
	w.motor:place(Vector3.new(8, 0.31, 4), Vector3.yAxis, Vector3.new(0, 0, -1))
	w.needs:configure({ energy = 0.5 })
	rest(w)
	local record = assert(Checkpoint.capture(w, 0))
	local energy, flies = w.needs.energy, #w.prey.flies
	check(not Checkpoint.worldMoved(record), "(this world's own rest)")
	local spawn = (WorldMap.region("sill") :: WorldMap.Region).spawn
	local want = spawn.pos + Vector3.new(0, Motor.HEIGHT, 0)
	-- The same record from another revision.
	for _, change in { function(r: any) r.world_map.revision = "world-0" end, function(r: any) r.world_map.seed = 915 end } do
		local moved = Json.copy(record)
		change(moved)
		check(Checkpoint.worldMoved(moved), "a different revision (or seed) is another world")
		check(#(Checkpoint.check(moved, w)) == 0, "and a good record: the check does not ask where the spider was kept")
		for _ = 1, 90 do tick(w) end -- the world moves on; the restore must bring back the record's life, but not its spot
		w.needs:configure({ energy = 0.9 })
		local ok, problems = Checkpoint.restore(moved, w)
		check(ok, "restored: " .. table.concat(problems, "; "))
		check((w.motor.pos - want).Magnitude < 1e-9 and w.motor.mode == "attached" and (w.motor.up - Vector3.yAxis).Magnitude < 1e-9, `the spider is at the sill's spawn ({w.motor.pos}), not where it rested`)
		check((w.motor.heading - spawn.heading).Magnitude < 1e-9, "facing the spawn's way")
		check(math.abs(w.needs.energy - energy) < 1e-9 and #w.prey.flies == flies, "while the life itself is the record's: the reserves and the flies")
		check(string.find(w.life.notice, "world has changed", 1, true) ~= nil, `and the notice says so ({w.life.notice})`)
		for _ = 1, 3 do tick(w) end
		check(not w.life.resting, "the rest does not go on outside the crack")
		-- An unmoved record puts the spider back where it rested, as ever.
		check(Checkpoint.restore(record, w) and (w.motor.pos - Vector3.new(8, 0.31, 4)).Magnitude < 1e-6, "while this world's own rest returns to its spot")
	end
	-- The position of such a rest is not trusted, so it is not tested: a spot far outside the sill is no reason to lose the life.
	local far = Json.copy(record)
	far.world_map.revision = "world-0"
	far.player.position = { 900, 1, 1 }
	check(#(Checkpoint.check(far, w)) == 0 and Checkpoint.restore(far, w) and (w.motor.pos - want).Magnitude < 1e-9, "a spot outside the old bounds is put right, not refused")
	local near = Json.copy(far)
	near.world_map.revision = WorldMap.REVISION
	check(#(Checkpoint.check(near, w)) > 0, "(from this world, the same record is refused)")
	-- But a spot that is not a spot at all, or a region that is not on the map, still is.
	local nan = Json.copy(far)
	nan.player.position = { 0, 0 / 0, 0 }
	check(#(Checkpoint.check(nan, w)) > 0, "a position that is not numbers is refused whatever the revision")
	local lost = Json.copy(far)
	lost.world_map.region = "garden"
	check(#(Checkpoint.check(lost, w)) > 0, "and so is a region that is not on the map")
	-- What it relies on: the motor stands the spider on the support point of any region's spawn, facing the heading given, and on its own config's when none is.
	w.motor:respawn(Vector3.new(-10, 0, 5), Vector3.new(0, 0, -1))
	check((w.motor.pos - Vector3.new(-10, Motor.HEIGHT, 5)).Magnitude < 1e-9 and (w.motor.heading - Vector3.new(0, 0, -1)).Magnitude < 1e-9 and w.motor.mode == "attached",
		"Motor.respawn stands the spider on the support point it is given, facing the heading it is given")
	w.motor:respawn()
	check((w.motor.pos - want).Magnitude < 1e-9 and (w.motor.heading - spawn.heading).Magnitude < 1e-9, "and on the config's own when it is given none")
end)

-- ROBLOX-92: the reasons a rest is refused are engineering words (they are in the tests above); the player is told them in the game's own (LifeText.restRefusal, MateText).
-- Every reason boundaryProblem can give has words, none is the fallback, and no player-facing word says "checkpoint" or names the machinery.
check(true, "(the reasons)")
do
	local LifeText = require("../src/Shared/UI/LifeText")
	local reasons = { "the spider is not standing on a surface", "the spider is moving", "the rival in the jaws is still struggling", "the spider is eating its rival", "the two spiders are together",
		"the brood is hatching", "the spider is feeding", "the prey in the jaws is still struggling", "a strike is still in progress" }
	for _, why in reasons do
		local text = LifeText.restRefusal(why)
		check(text ~= LifeText.REST_FALLBACK and text ~= why and not string.find(string.lower(text), "checkpoint", 1, true) and string.find(text, "Not ", 1, true) == 1, `{why}: "{text}"`)
	end
	check(LifeText.restRefusal("the two spiders are together") == "Not now — the two of you are together" and LifeText.restRefusal("the rival in the jaws is still struggling") == "Not while a fight is on"
		and LifeText.restRefusal("the brood is hatching") == "Not while the brood is hatching", "the three the reviewer named")
	check(LifeText.restRefusal("anything new") == LifeText.REST_FALLBACK, "a reason nobody wrote words for says the plain fallback")
end

print(`CHECKPOINT passed={passed} failed={failed}`)
if failed > 0 then error("CHECKPOINT failed") end
