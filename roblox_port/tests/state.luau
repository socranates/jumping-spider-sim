-- Persistent saves (ROBLOX-39): the pure model and the session logic, with every failure a DataStore can show. No engine and no live
-- DataStore: a smoke test of the real modules on the in-memory backend with injected faults and a fake clock. What needs Studio and API
-- access is in tests/studio/StateSpec.luau (see docs/HANDOFF-roblox-state.md).
-- Run with the other suites:  python3 tests/run.py path/to/luau state.luau
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local Species = require("../src/Shared/Data/Species")
local Surfaces = require("../src/Shared/Data/Surfaces")
local Motor = require("../src/Shared/Movement/SpiderMotor")
local PreyDirector = require("../src/Shared/Prey/PreyDirector")
local Sensor = require("../src/Shared/Perception/Sensor")
local ObservationMemory = require("../src/Shared/Perception/ObservationMemory")
local NeedsModel = require("../src/Shared/Life/NeedsModel")
local LifeLoop = require("../src/Shared/Life/LifeLoop")
local Checkpoint = require("../src/Shared/Persistence/Checkpoint")
local Json = require("../src/Shared/Persistence/Json")
local SaveRules = require("../src/Shared/Data/SaveRules")
local SaveStores = require("../src/Shared/Persistence/SaveStores")
local MemoryBackend = require("../src/Shared/Persistence/MemoryBackend")
local SaveClient = require("../src/Client/SaveClient")
local SaveEnvelope = require("../src/Shared/Persistence/SaveEnvelope")
local SaveProgress = require("../src/Shared/Persistence/SaveProgress")
local SettingsModel = require("../src/Shared/UI/SettingsModel")
local SaveRest = require("../src/Shared/Persistence/SaveRest")
local SaveScheduler = require("../src/Shared/Persistence/SaveScheduler")
local SaveSession = require("../src/Shared/Persistence/SaveSession")
local DataStoreBackend = require("../src/Server/DataStoreBackend")
local RestCompression = require("../src/Server/RestCompression")
local SaveService = require("../src/Server/SaveService")
local Appearances = require("../src/Shared/Data/Appearances")
local SpiderChoice = require("../src/Shared/Rig/SpiderChoice")

local passed, failed = 0, 0
local STATE_TRACE = false
local current = ""
local function check(ok: boolean, what: string): boolean
	if ok then passed += 1 else failed += 1; print(`FAIL [{current}] {what}`) end
	return ok
end
local function case(name: string, fn: () -> ())
	current = name
	if STATE_TRACE then print("case: " .. name) end
	local started = os.clock()
	local ok, err = xpcall(fn, debug.traceback)
	if os.clock() - started > 5 then print(`slow [{name}] {math.floor((os.clock() - started) * 10) / 10} s`) end
	if not ok then failed += 1; print(`FAIL [{name}] raised: {tostring(err)}`) end
end
local function canon(v: any): string
	return (Json.canonical(v)) or "?"
end

-- ---------------------------------------------------------------------------------------------- a world like the client's
local DT = Motor.DT
local sill = BoxWorld.folder("StateSill", Layout.PIECES)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { sill }
local cast = Sensor.workspaceCast(params)
local camera = { CFrame = CFrame.new(Vector3.new(0, 30, 40)), FieldOfView = 70, ViewportSize = Vector2.new(1280, 720) }
local HOME = Vector3.new(-25.5, Layout.SPAWN.Y, 6.0)

local function newWorld(seed: number?, mode: string?): any
	local motor = Motor.new({
		world = sill, surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Layout.SPAWN,
		heading = Layout.SPAWN_HEADING, boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX,
	})
	local prey = PreyDirector.engine(sill, Species.fly_like_prototype, seed or 914, 4)
	local memory = ObservationMemory.new()
	local sensor = Sensor.new(memory)
	sensor:configureFrom(Species.phidippus_audax_prototype.perception)
	local needs = NeedsModel.new(true, mode == "free" or mode == "easy")
	prey.feeding.needs = needs
	local w: any = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs }
	w.life = LifeLoop.new(needs, function() return { ok = true, message = "" } end)
	if mode == "free" then w.life.mode, w.life.rules = "free", "gentle" elseif mode == "easy" then w.life.mode, w.life.rules = "main", "gentle" end
	motor:place(HOME, Vector3.yAxis, Vector3.new(1, 0, 0))
	return w
end
local STILL = { wish = Vector3.zero, creep = false, reel = 0, dropHeld = false, releaseHeld = false }
local function tick(w: any, feed: boolean?)
	w.sensor:step(DT, w.motor:observer(), w.prey:percepts(), cast)
	w.prey:before(DT, w.motor.pos, w.motor:observer(), w.sensor, cast, camera)
	w.motor:tick(STILL)
	w.prey:after(DT, w.motor, w.sensor, cast)
	local holding = w.prey.feeding.held ~= nil
	w.life:step(DT, {
		inRetreat = Layout.inRetreat(w.motor.pos), attached = w.motor.mode == "attached" and not w.motor.preparing,
		still = w.motor.vel.Magnitude < 0.15, holding = holding, feeding = holding and w.prey.feeding.feeding,
	}, feed == true, false)
	w.sensor.core.rangeScale = w.life.rangeScale
	w.life:drainEvents()
end
local function realRest(ticks: number?, mode: string?): any
	local w = newWorld(nil, mode)
	for _ = 1, ticks or 120 do tick(w) end
	tick(w, true)
	return assert(Checkpoint.capture(w, 0)), w
end

-- ---------------------------------------------------------------------------------------------- sizes, measured
local restSizes: { number } = {}
case("measured sizes: a real rest, early and after a long life, against the cap and Roblox's limit", function()
	local early = realRest(120)
	local n1 = #canon(early)
	local w = newWorld()
	local sizes: { number } = {}
	for t = 1, 12000 do
		tick(w, t % 600 == 0)
		if t % 4000 == 0 then
			if Checkpoint.boundaryProblem(w) == "" then
				local rec = Checkpoint.capture(w, os.time())
				if rec then table.insert(sizes, #canon(rec)) end
			end
		end
	end
	local biggest = n1
	for _, s in sizes do biggest = math.max(biggest, s) end
	table.insert(restSizes, n1)
	table.insert(restSizes, biggest)
	print(`state: a rest is {n1} characters early and {biggest} at most after {#sizes} samples of a long life (cap {SaveRules.MAX_REST_CHARS}, Roblox {SaveRules.MAX_VALUE_CHARS})`)
	check(n1 > 5000, `a real size ({n1})`)
	check(biggest * 4 <= SaveRules.MAX_REST_CHARS, `at least four times headroom under the cap ({biggest} of {SaveRules.MAX_REST_CHARS})`)
	check(RestCompression.MAX_STORED_CHARS < SaveRules.MAX_VALUE_CHARS, "compressed envelope including backup fits one stored value")
	check(2 * SaveRules.MAX_REST_CHARS + 4096 < RestCompression.MAX_EXPANDED_BYTES, "two capped rests fit the bounded expanded envelope")
end)


-- ---------------------------------------------------------------------------------------------- store names and error classes
case("the store: Studio and the test place use the test store, a live server the production one; the attribute cannot name production for a test", function()
	check(SaveStores.name(true, false, nil) == "WindowsillTest_v1", "Studio -> test")
	check(SaveStores.name(false, true, nil) == "WindowsillTest_v1", "test place -> test")
	check(SaveStores.name(false, false, nil) == "Windowsill_v1", "live -> production")
	check(SaveStores.name(true, false, "Windowsill_v1") == "WindowsillTest_v1", "Studio asked for production: refused")
	check(SaveStores.name(false, true, "Windowsill_v1") == "WindowsillTest_v1", "test place asked for production: refused")
	check(SaveStores.name(true, false, "WindowsillTest_chet") == "WindowsillTest_chet", "a test-looking name is allowed in Studio")
	check(SaveStores.name(false, false, "WindowsillTest_chet") == "Windowsill_v1", "a live server ignores the attribute")
	check(SaveStores.name(true, false, 42) == "WindowsillTest_v1" and SaveStores.name(true, false, string.rep("WindowsillTest", 9)) == "WindowsillTest_v1", "junk is ignored")
	check(SaveRules.STORE_PRODUCTION ~= SaveRules.STORE_TEST, "the two names differ")
end)

case("error classes: throttles, configuration, values that can never be stored, everything else transient", function()
	local table1 = {
		{ "301: GetAsync request was throttled", "throttle" }, { "304: UpdateAsync over limit", "throttle" }, { "Request queue is full: too many requests", "throttle" },
		{ "104: Cannot store Dictionary in data store. Data stores can only accept valid UTF-8 characters.", "value" },
		{ "105: ValueTooLarge: the value exceeds 4 MB", "value" },
		{ "403: Studio access to APIs is not allowed", "config" }, { "StudioAccessToApisNotAllowed", "config" }, { "You must publish this place to the web to access DataStore", "config" },
		{ "502: API Services rejected request with error", "transient" }, { "504: timed out", "transient" }, { "something nobody expected", "transient" }, { "", "transient" },
	}
	for _, row in table1 do check(SaveStores.classify(row[1]) == row[2], `"{row[1]}" is {row[2]} (got {SaveStores.classify(row[1])})`) end
	check(SaveStores.classify(nil) == "transient", "nil is transient")
	check(SaveStores.classify("102: KeyNameLimit") == "value" and SaveStores.classify("101: KeyNameEmpty") == "value", "a bad key can never be stored")
end)

-- ---------------------------------------------------------------------------------------------- the rest check
case("a real rest passes the server's check, in each mode, and the stand-in world names everything a real world does", function()
	local rec, w = realRest(120, "main")
	local problems = SaveRest.check("main", rec)
	check(#problems == 0, "main rest: " .. table.concat(problems, "; "))
	check(#SaveRest.check("free", rec) > 0, "a main rest is not a free rest")
	local freeRec = realRest(120, "free")
	check(#SaveRest.check("free", freeRec) == 0, "free rest: " .. table.concat(SaveRest.check("free", freeRec), "; "))
	check(#SaveRest.check("main", freeRec) > 0, "a free rest is not a main rest")
	local real = Checkpoint.refs(w)
	local stub = Checkpoint.refs(SaveRest.stubWorld())
	local missing = 0
	for name in real do if stub[name] == nil then missing += 1; print("  the stand-in lacks " .. name) end end
	check(missing == 0, "every name a real world offers, the stand-in offers")
	-- (the stand-in may offer more than one world does: needs.onEnergyChanged is only there when something sets it)
	-- after a long life, and in Easy
	local easy = newWorld(nil, "free")
	for _ = 1, 1500 do tick(easy) end
	tick(easy, true)
	local rec2 = assert(Checkpoint.capture(easy, 0))
	check(#SaveRest.check("free", rec2) == 0, "a later free rest: " .. table.concat(SaveRest.check("free", rec2), "; "))
end)

case("the rest check refuses what is not a whole, sensible rest, and never raises", function()
	local rec = realRest(120, "main")
	local function mutated(fn: (any) -> ()): any
		local c = Json.copy(rec)
		fn(c)
		return c
	end
	local function refused(label: string, mode: any, v: any)
		local ok, problems = pcall(SaveRest.check, mode, v)
		check(ok and #problems > 0, `{label} is refused ({if ok then problems[1] or "ACCEPTED" else tostring(problems)})`)
	end
	refused("nil", "main", nil)
	refused("a string", "main", "rest")
	refused("a number", "main", 42)
	refused("an empty table", "main", {})
	refused("an unknown mode", "weekly", rec)
	refused("a nil mode", nil, rec)
	refused("a newer checkpoint schema", "main", mutated(function(c) c.schema_version = 99 end))
	refused("another windowsill", "main", mutated(function(c) c.content_revision = "windowsill-roblox-0" end))
	refused("a missing world", "main", mutated(function(c) c.world = nil end))
	refused("a spider outside the sill", "main", mutated(function(c) c.player.position = { 9999, 0, 0 } end))
	-- The record of the world the rest was made in (ROBLOX-94): a rest of a place this world does not have, or of changes this game does not know, is refused; one from before the record, or from another
	-- revision of the world, is not (it is put back at the region's spawn when it is used).
	refused("a region the world does not have", "main", mutated(function(c) c.world_map.region = "moon" end))
	refused("a retreat of another region", "main", mutated(function(c) c.world_map.retreat = "garden_hollow" end))
	refused("a seed that is not a number", "main", mutated(function(c) c.world_map.seed = 0 / 0 end))
	refused("changes to the world this game does not know", "main", mutated(function(c) c.world_map.diffs = { { id = "stone_1", moved = { 1, 2, 3 } } } end))
	refused("a world record that is not a table", "main", mutated(function(c) c.world_map = "sill" end))
	check(#SaveRest.check("main", mutated(function(c) c.world_map = nil end)) == 0, "a rest from before the world record is accepted, as the sill's (of world-1: put back at the spawn when used, ROBLOX-95)")
	-- ROBLOX-95: the regions outside the window. A rest under the bed's stone is a rest like the crack's; one that says the bed but lies outside it, or names the
	-- sill's crack, is not.
	local function inBed(c: any)
		c.player.position = { 11, -89.69, -50 }
		c.world_map.region, c.world_map.retreat, c.player.retreat_id = "bed_a", "bed_a_stone", "bed_a_stone"
	end
	check(#SaveRest.check("main", mutated(inBed)) == 0, "a rest under the bed's stone is accepted: " .. table.concat(SaveRest.check("main", mutated(inBed)), "; "))
	refused("a bed rest outside the bed", "main", mutated(function(c) inBed(c); c.player.position = { 11, -89.69, -200 } end))
	refused("a bed rest in the sill's crack", "main", mutated(function(c) inBed(c); c.world_map.retreat = "sill_crevice"; c.player.retreat_id = "sill_crevice" end))
	refused("a rest in the bed's stone that says the sill", "main", mutated(function(c) inBed(c); c.world_map.region = "sill" end))
	check(#SaveRest.check("main", mutated(function(c) c.world_map.revision = "world-0"; c.world_map.seed = 7 end)) == 0, "a rest from another revision or seed of the world is accepted: it is put back at the spawn when used")
	-- ROBLOX-96: the garden root. An empty one (a world whose bed has not been made yet) is accepted; one naming a region without prey, or a region that is not a record, is refused.
	local function withGarden(c: any, entries: { any })
		table.insert(c.world.objects, { e = entries })
		c.world.roots.garden = { ["$o"] = #c.world.objects }
	end
	check(#SaveRest.check("main", mutated(function(c) withGarden(c, {}) end)) == 0, "a rest with an empty garden root is accepted")
	refused("a garden naming a region the map does not have", "main", mutated(function(c)
		table.insert(c.world.objects, { e = {} })
		withGarden(c, { { "moon", { ["$o"] = #c.world.objects } } })
	end))
	refused("a garden naming the sill, which has no generated prey", "main", mutated(function(c)
		table.insert(c.world.objects, { e = {} })
		withGarden(c, { { "sill", { ["$o"] = #c.world.objects } } })
	end))
	refused("a garden whose region is not a record", "main", mutated(function(c) withGarden(c, { { "bed_a", 7 } }) end))
	refused("a garden whose bed's prey is not a prey director", "main", mutated(function(c)
		table.insert(c.world.objects, { e = {} })
		local plain = #c.world.objects
		table.insert(c.world.objects, { e = { { "prey", { ["$o"] = plain } } } })
		withGarden(c, { { "bed_a", { ["$o"] = #c.world.objects } } })
	end))
	refused("a non-unit normal", "main", mutated(function(c) c.player.normal = { 0, 5, 0 } end))
	refused("NaN in the pose", "main", mutated(function(c) c.player.position = { 0 / 0, 1, 1 } end))
	refused("an infinity", "main", mutated(function(c) c.player.gaze_pitch = math.huge end))
	refused("a function inside", "main", mutated(function(c) c.player.extra = function() end end))
	refused("a metatable inside", "main", mutated(function(c) c.player = setmetatable(c.player, {}) end))
	refused("a vector inside", "main", mutated(function(c) c.player.position = Vector3.new(1, 1, 1) end))
	refused("an unknown class", "main", mutated(function(c) c.world.objects[1].c = "Evil" end))
	refused("a dangling reference", "main", mutated(function(c) c.world.objects[2].e[1][2] = { ["$o"] = 99999 } end))
	refused("an unnamed reference", "main", mutated(function(c) c.world.objects[2].e[1][2] = { ["$r"] = "os.execute" } end))
	refused("a cut-off graph", "main", mutated(function(c) for i = 40, #c.world.objects do c.world.objects[i] = nil end end))
	refused("rules that are not the mode's", "main", mutated(function(c) c.life_rules = { mode = "free", rules = "gentle" } end))
	refused("a free rest on standard rules", "free", mutated(function(c) c.life_rules = { mode = "free", rules = "standard" } end))
	local deep: any = {}
	local at = deep
	for _ = 1, 40 do at.next = {}; at = at.next end
	refused("nesting 40 deep", "main", mutated(function(c) c.player.extra = deep end))
	local wide: any = {}
	for i = 1, SaveRules.MAX_REST_NODES + 5 do wide[i] = i end
	refused("more values than the cap", "main", mutated(function(c) c.player.extra = wide end))
	refused("more characters than the cap", "main", mutated(function(c) c.player.extra = string.rep("x", SaveRules.MAX_REST_CHARS + 1) end))
	local cyc: any = {}
	cyc.me = cyc
	refused("a cycle", "main", mutated(function(c) c.player.extra = cyc end))
	local twice: any = { 1 }
	refused("a table met twice", "main", mutated(function(c) c.player.a = twice; c.player.b = twice end))
	refused("a key that is a table", "main", mutated(function(c) c.player[{}] = 1 end))
	check(SaveRest.bounded(rec, SaveRules.MAX_REST_NODES, SaveRules.MAX_DEPTH) == nil, "a real rest is within the bounds")
end)

-- ---------------------------------------------------------------------------------------------- the envelope
local TESTSPEC: SaveEnvelope.Spec = {
	kind = "thing", current = 3,
	migrations = {
		[1] = function(p: any): any return { value = p.v, label = "migrated" } end,
		[2] = function(p: any): any p.extra = true; return p end,
	},
	validate = function(p: any): ({ string }, any?)
		if type(p) ~= "table" or type(p.value) ~= "number" then return { "no value" }, nil end
		return {}, p
	end,
}
local function stored(spec: SaveEnvelope.Spec, schema: number, payload: any, t: number): any
	local c: any = { schema = schema, updatedAt = t, payload = payload }
	c.checksum = Json.checksum(canon({ kind = spec.kind, schema = schema, updatedAt = t, payload = payload }))
	return { format = SaveRules.FORMAT, kind = spec.kind, schema = c.schema, updatedAt = c.updatedAt, payload = c.payload, checksum = c.checksum }
end

case("envelope: a save opens as it was made; missing, corrupt and invalid are told apart", function()
	local env = SaveEnvelope.make(TESTSPEC, { value = 7, label = "x", extra = true }, 100, nil)
	local o = SaveEnvelope.open(TESTSPEC, env)
	check(o.status == "ok" and o.payload.value == 7 and o.updatedAt == 100 and o.backup == nil, "ok")
	check(SaveEnvelope.open(TESTSPEC, nil).status == "missing", "nil is missing")
	for label, v in { ["a string"] = "x", ["a number"] = 3, ["an empty table"] = {}, ["another game"] = { format = "other", kind = "thing" } } do
		check(SaveEnvelope.open(TESTSPEC, v).status == "corrupt", `{label} is corrupt`)
	end
	local wrongKind = SaveEnvelope.make({ kind = "other", current = 3, migrations = {}, validate = TESTSPEC.validate }, { value = 1 }, 1, nil)
	check(SaveEnvelope.open(TESTSPEC, wrongKind).status == "corrupt", "another kind is corrupt")
	local tampered = Json.copy(env)
	tampered.payload.value = 8
	check(SaveEnvelope.open(TESTSPEC, tampered).status == "corrupt", "a changed payload fails its checksum")
	local cut = Json.copy(env)
	cut.checksum = nil
	check(SaveEnvelope.open(TESTSPEC, cut).status == "corrupt", "a missing checksum is corrupt")
	local stamped = Json.copy(env)
	stamped.updatedAt = 101
	check(SaveEnvelope.open(TESTSPEC, stamped).status == "corrupt", "a changed time fails its checksum")
	local badSchema = Json.copy(env)
	badSchema.schema = 1.5
	check(SaveEnvelope.open(TESTSPEC, badSchema).status == "corrupt", "a schema that is not whole is corrupt")
	badSchema.schema = 0
	check(SaveEnvelope.open(TESTSPEC, badSchema).status == "corrupt", "schema 0 is corrupt")
	local invalid = stored(TESTSPEC, 3, { value = "seven" }, 5)
	local oi = SaveEnvelope.open(TESTSPEC, invalid)
	check(oi.status == "invalid" and oi.payload == nil, "good checksum, bad content: invalid")
	check(SaveEnvelope.open(TESTSPEC, SaveEnvelope.withLock(env, { session = "a", beat = 5 })).status == "ok", "the lock is outside the checksum")
end)

case("envelope: older schemas migrate forward in memory, step by step; a gap or a failing step is invalid, never guessed", function()
	local v1 = stored(TESTSPEC, 1, { v = 4 }, 10)
	local o = SaveEnvelope.open(TESTSPEC, v1)
	check(o.status == "migrated" and o.migratedFrom == 1 and o.payload.value == 4 and o.payload.label == "migrated" and o.payload.extra == true, "1 -> 2 -> 3")
	local v2 = stored(TESTSPEC, 2, { value = 5, label = "two" }, 10)
	local o2 = SaveEnvelope.open(TESTSPEC, v2)
	check(o2.status == "migrated" and o2.payload.extra == true and o2.payload.label == "two", "2 -> 3")
	check(canon(v1.payload) == canon({ v = 4 }), "opening did not touch the stored value")
	local gap: SaveEnvelope.Spec = { kind = "thing", current = 3, migrations = { [2] = TESTSPEC.migrations[2] }, validate = TESTSPEC.validate }
	check(SaveEnvelope.open(gap, v1).status == "invalid", "no migration from 1: invalid")
	local boom: SaveEnvelope.Spec = { kind = "thing", current = 3, migrations = { [1] = function(_p: any): any error("no") end, [2] = TESTSPEC.migrations[2] }, validate = TESTSPEC.validate }
	check(SaveEnvelope.open(boom, v1).status == "invalid", "a migration that raises: invalid")
	local nothing: SaveEnvelope.Spec = { kind = "thing", current = 3, migrations = { [1] = function(_p: any): any return nil end, [2] = TESTSPEC.migrations[2] }, validate = TESTSPEC.validate }
	check(SaveEnvelope.open(nothing, v1).status == "invalid", "a migration that returns nothing: invalid")
	local bad1 = stored(TESTSPEC, 1, { v = "x" }, 10)
	check(SaveEnvelope.open(TESTSPEC, bad1).status == "invalid", "a migrated payload is validated")
	local raises: SaveEnvelope.Spec = { kind = "thing", current = 3, migrations = TESTSPEC.migrations, validate = function(_p: any): ({ string }, any?) error("validator bug") end }
	check(SaveEnvelope.open(raises, stored(TESTSPEC, 3, { value = 1 }, 1)).status == "invalid", "a validator that raises: invalid, not a crash")
	local before = canon(v1)
	SaveEnvelope.open(TESTSPEC, v1)
	check(canon(v1) == before and SaveEnvelope.open(TESTSPEC, v1).status == "migrated", "a migration that edits its argument in place does not damage the stored value")
	local tamperedOld = Json.copy(v1)
	tamperedOld.payload.v = 5
	check(SaveEnvelope.open(TESTSPEC, tamperedOld).status == "corrupt", "an old save is checked before it is migrated")
end)

case("envelope: a newer schema is told apart and never read past its header", function()
	local fromFuture = { format = SaveRules.FORMAT, kind = "thing", schema = 4, updatedAt = 50, payload = { anything = true }, checksum = "not computed the way this build does" }
	local o = SaveEnvelope.open(TESTSPEC, fromFuture)
	check(o.status == "newer" and o.payload == nil and o.schema == 4, "newer")
	check(string.find(o.reasons[1] or "", "newer", 1, true) ~= nil, "the reason says so")
end)

case("envelope: the backup is the previous good version, one level, and survives a lock-only change", function()
	local a = SaveEnvelope.make(TESTSPEC, { value = 1 }, 10, nil)
	local b = SaveEnvelope.make(TESTSPEC, { value = 2 }, 20, a)
	local ob = SaveEnvelope.open(TESTSPEC, b)
	check(ob.status == "ok" and ob.backup ~= nil and ob.backup.status == "ok" and ob.backup.payload.value == 1 and ob.backup.updatedAt == 10, "backup is the version before")
	local c = SaveEnvelope.make(TESTSPEC, { value = 3 }, 30, b)
	local oc = SaveEnvelope.open(TESTSPEC, c)
	check(oc.backup ~= nil and oc.backup.payload.value == 2 and (c :: any).backup.backup == nil, "one level only")
	local locked = SaveEnvelope.withLock(c, { session = "s", beat = 99 })
	check(SaveEnvelope.open(TESTSPEC, locked).backup ~= nil and locked.checksum == c.checksum and locked.payload == c.payload, "a lock change leaves payload, checksum and backup alone")
	check(SaveEnvelope.withLock(locked, nil).lock == nil, "the lock can be released")
	-- a corrupt prior is not kept as the backup; its own good backup stays
	local damaged = Json.copy(c)
	damaged.payload.value = 99
	local d = SaveEnvelope.make(TESTSPEC, { value = 4 }, 40, damaged)
	local od = SaveEnvelope.open(TESTSPEC, d)
	check(od.backup ~= nil and od.backup.payload.value == 2, "a damaged prior is not made the backup; its good backup is kept")
	local e = SaveEnvelope.make(TESTSPEC, { value = 5 }, 50, "junk")
	check(SaveEnvelope.open(TESTSPEC, e).backup == nil, "junk as prior: no backup")
	-- a corrupt current with a good backup reports the backup
	local rotten = Json.copy(c)
	rotten.checksum = "0000000000000000"
	local orr = SaveEnvelope.open(TESTSPEC, rotten)
	check(orr.status == "corrupt" and orr.backup ~= nil and orr.backup.status == "ok" and orr.backup.payload.value == 2, "corrupt current, good backup offered")
end)

case("envelope: lock rules", function()
	local H = SaveRules.LOCK_STALE
	check(not SaveEnvelope.heldByOther(nil, "me", 1000, H), "no lock")
	check(not SaveEnvelope.heldByOther({ session = "me", beat = 1000 }, "me", 1000, H), "my own lock")
	check(SaveEnvelope.heldByOther({ session = "you", beat = 990 }, "me", 1000, H), "a fresh lock of another")
	check(SaveEnvelope.heldByOther({ session = "you", beat = 1000 - H }, "me", 1000, H), "exactly at the limit: still held")
	check(not SaveEnvelope.heldByOther({ session = "you", beat = 1000 - H - 1 }, "me", 1000, H), "a stale lock of another")
	check(not SaveEnvelope.heldByOther({ session = "you" }, "me", 1000, H), "a lock with no beat protects nothing")
	check(not SaveEnvelope.heldByOther({ session = 5, beat = 1000 }, "me", 1000, H), "a lock with no session name")
	check(not SaveEnvelope.heldByOther("junk", "me", 1000, H), "junk")
end)

-- ---------------------------------------------------------------------------------------------- progress
local function prog(ids: { string }, extra: { [string]: any }?): any
	local x: any = extra or {}
	return SaveProgress.snapshot({ opened = ids, eye_seconds = x.eye or 0 }, x.finished == true, x.appearance, x.settings or {})
end

case("progress: a good record is kept, anything out of range or of the wrong type is refused, nothing raises", function()
	local good = prog({ "bold_jumper", "dragline" }, { eye = 12.5, finished = true, appearance = "maratus_volans_male", settings = { LargeText = true, ShowLastSeen = false } })
	local problems, clean = SaveProgress.sanitize(good)
	check(#problems == 0 and clean ~= nil and canon(clean) == canon(good), "a snapshot is sanitary")
	local function refused(label: string, mutate: (any) -> ())
		local c = Json.copy(good)
		mutate(c)
		local ok, p, cl = pcall(SaveProgress.sanitize, c)
		check(ok and #(p :: any) > 0 and cl == nil, `{label} is refused`)
	end
	refused("pages that are not a list", function(c) c.notebook.opened = "all" end)
	refused("a page id with a slash", function(c) c.notebook.opened = { "../../x" } end)
	refused("a page id that is a number", function(c) c.notebook.opened = { 5 } end)
	refused("an empty page id", function(c) c.notebook.opened = { "" } end)
	refused("a very long page id", function(c) c.notebook.opened = { string.rep("a", 49) } end)
	refused("negative eye seconds", function(c) c.notebook.eye_seconds = -1 end)
	refused("NaN eye seconds", function(c) c.notebook.eye_seconds = 0 / 0 end)
	refused("infinite eye seconds", function(c) c.notebook.eye_seconds = math.huge end)
	refused("huge eye seconds", function(c) c.notebook.eye_seconds = 1e12 end)
	refused("a string for finished_main", function(c) c.finished_main = "yes" end)
	refused("a table for the appearance", function(c) c.appearance = {} end)
	refused("a preference that is not a boolean", function(c) c.settings.LargeText = "yes" end)
	refused("preferences as a list of numbers", function(c) c.settings = 5 end)
	refused("no notebook", function(c) c.notebook = nil end)
	refused("a sparse page list", function(c) c.notebook.opened = { [1] = "a", [3] = "b" } end)
	for _, v in { 1, "x", true, {}, false } do
		local ok, p = pcall(SaveProgress.sanitize, v)
		check(ok and #p > 0, `junk {tostring(v)} refused`)
	end
	local many: { string } = {}
	for i = 1, SaveRules.MAX_PAGES + 1 do many[i] = "page" .. i end
	local c = Json.copy(good)
	c.notebook.opened = many
	check(#(SaveProgress.sanitize(c)) > 0, "more pages than the cap is refused")
	c.notebook.opened = { "a", "a", "b" }
	local _, cl = SaveProgress.sanitize(c)
	check(cl ~= nil and #cl.notebook.opened == 2, "a repeated page id is dropped quietly")
	c = Json.copy(good)
	c.settings.SomethingNew = true
	_, cl = SaveProgress.sanitize(c)
	check(cl ~= nil and cl.settings.SomethingNew == nil and cl.settings.LargeText == true, "a preference this build does not know is dropped, the rest kept")
	c = Json.copy(good)
	c.notebook.opened = { "bold_jumper", "a_page_from_a_newer_build" }
	_, cl = SaveProgress.sanitize(c)
	check(cl ~= nil and #cl.notebook.opened == 2, "an unknown but well-formed page id is kept")
end)

case("progress: every spider the game draws is a good appearance, the ant-mimicking spider included (ROBLOX-64)", function()
	for id in Appearances.profiles do
		local playable = table.find(SpiderChoice.ORDER, id) ~= nil -- the rival's look is drawn for the other spider and is never put on (ROBLOX-67)
		local good = prog({ "bold_jumper" }, { appearance = id })
		local problems, clean = SaveProgress.sanitize(good)
		check(#problems == 0 and clean ~= nil and clean.appearance == id, `the appearance {id} is accepted and kept`)
		check(#id <= SaveRules.MAX_ID_CHARS and string.match(id, "^[%w_]+$") ~= nil, `{id} is a short plain name`)
		check(SpiderChoice.start(clean and clean.appearance, nil) == (if playable then id else "first_spider"), `{id} is {if playable then "a spider the client puts on" else "the rival's look and never put on"}`)
	end
	local ant = "myrmarachne_formicaria_female"
	check(Appearances.profiles[ant] ~= nil and table.find(SpiderChoice.ORDER, ant) ~= nil, "the ant-mimicking spider is drawn and in the crack's cycle")
	check(SaveProgress.merge(prog({}, { appearance = "first_spider" }), prog({}, { appearance = ant }), 10, 20).appearance == ant, "the newer choice of the ant-mimicking spider wins a merge")
	check(SaveProgress.merge(prog({}, { appearance = ant }), prog({}, { appearance = "maratus_volans_male" }), 30, 20).appearance == ant, "and an older one does not undo it")
	-- A spider this build does not draw (from a newer build) is kept in the record, and the client falls back to the first spider.
	local future = prog({ "bold_jumper" }, { appearance = "a_spider_from_a_newer_build" })
	local _, kept = SaveProgress.sanitize(future)
	check(kept ~= nil and kept.appearance == "a_spider_from_a_newer_build" and SpiderChoice.start(kept.appearance, nil) == "first_spider", "an unknown spider id is kept, and not put on")
	local bad = Json.copy(prog({ "bold_jumper" }, { appearance = ant }))
	bad.appearance = ant .. "/../x"
	local p1, c1 = SaveProgress.sanitize(bad)
	check(#p1 > 0 and c1 == nil, "an appearance that is not a plain name is refused")
end)

case("progress: merging never loses a page, an adult or the longest eye time; the newer choice wins", function()
	local a = prog({ "p1", "p2" }, { eye = 100, finished = false, appearance = "first_spider", settings = { LargeText = true } })
	local b = prog({ "p2", "p3" }, { eye = 50, finished = true, appearance = "maratus_volans_male", settings = { SoundMuted = true } })
	local m = SaveProgress.merge(a, b, 10, 20)
	check(canon(m.notebook.opened) == canon({ "p1", "p2", "p3" }), "pages: a union, the stored order first")
	check(m.notebook.eye_seconds == 100 and m.finished_main == true, "eye time the longest, a finished life stays")
	check(m.appearance == "maratus_volans_male" and m.settings.LargeText == true and m.settings.SoundMuted == true, "the newer appearance; preferences key by key")
	local m2 = SaveProgress.merge(a, b, 30, 20)
	check(m2.appearance == "first_spider", "the older incoming does not override the appearance")
	local m3 = SaveProgress.merge(a, prog({}, { settings = { LargeText = false } }), 10, 20)
	check(m3.settings.LargeText == false and m3.appearance == "first_spider", "a newer preference overrides; an absent appearance keeps the stored one")
	local d = SaveProgress.default()
	check(canon(SaveProgress.merge(a, d, 10, 0)) == canon(a), "merging a default changes nothing")
	check(canon(SaveProgress.merge(d, a, 0, 10)) == canon(a), "merging into a default gives the record")
	check(SaveProgress.same(m, SaveProgress.merge(m, m, 1, 1)), "idempotent")
	-- monotonic over many random merges
	local seed = 7
	local function rnd(n: number): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed % n + 1
	end
	local acc = SaveProgress.default()
	local seenIds: { [string]: boolean } = {}
	local prevEye = 0
	local ok = true
	for i = 1, 300 do
		local ids: { string } = {}
		for _ = 1, rnd(4) do
			local id = "page" .. rnd(30)
			table.insert(ids, id)
		end
		local inc = prog(ids, { eye = rnd(500), finished = rnd(10) == 1 })
		acc = SaveProgress.merge(acc, inc, i, i)
		for _, id in ids do seenIds[id] = true end
		for id in seenIds do if not table.find(acc.notebook.opened, id) then ok = false end end
		if acc.notebook.eye_seconds < prevEye then ok = false end
		prevEye = acc.notebook.eye_seconds
	end
	check(ok, "300 random merges: every page ever found is still there, eye time never fell")
	local capped = prog({}, {})
	local many: { string } = {}
	for i = 1, SaveRules.MAX_PAGES do many[i] = "q" .. i end
	capped.notebook.opened = many
	local over = SaveProgress.merge(capped, prog({ "extra" }), 1, 1)
	check(#over.notebook.opened == SaveRules.MAX_PAGES and over.notebook.opened[1] == "q1", "the page cap holds, the stored pages first")
end)

-- ---------------------------------------------------------------------------------------------- the scheduler
case("scheduler: progress is debounced to one write in 30 s, a rest to one in 10 s; changes in between join the next write", function()
	local s = SaveScheduler.new()
	s:track("progress", SaveRules.PROGRESS_DEBOUNCE)
	s:track("rest", SaveRules.REST_MIN_INTERVAL)
	s:markDirty("progress", 100)
	check(s:due("progress", 100), "the first change after a quiet time is due at once")
	local v = s:begin("progress", 100)
	s:succeeded("progress", 100, v)
	check(not s:isDirty("progress") and not s:anyDirty(), "clean")
	s:markDirty("progress", 105)
	s:markDirty("progress", 110)
	s:markDirty("progress", 125)
	check(not s:due("progress", 129), "not due inside 30 s")
	check(s:due("progress", 130), "due at 30 s")
	local v2 = s:begin("progress", 130)
	s:markDirty("progress", 131) -- changed while the write is in flight
	s:succeeded("progress", 132, v2)
	check(s:isDirty("progress") and not s:due("progress", 140) and s:due("progress", 162), "a change in flight keeps it dirty, due 30 s after")
	s:markDirty("rest", 200)
	check(s:due("rest", 200), "a rest is due at once")
	local vr = s:begin("rest", 200)
	s:succeeded("rest", 200, vr)
	s:markDirty("rest", 201)
	check(not s:due("rest", 209) and s:due("rest", 210), "the next rest waits 10 s")
end)

case("scheduler: a failure keeps it dirty and backs off 2, 4, 8 ... to a cap; a throttle waits longer; a success resets", function()
	local s = SaveScheduler.new()
	s:track("progress", 30)
	s:markDirty("progress", 0)
	local waits: { number } = {}
	local t = 0
	for _ = 1, 8 do
		s:begin("progress", t)
		table.insert(waits, s:failed("progress", t, "transient"))
		check(s:isDirty("progress") and not s:due("progress", t), "still dirty, not due at once")
		t += waits[#waits]
		check(s:due("progress", t - 0.01) == false, "not due a moment early") -- budget aside
		s.started = {}
	end
	check(canon(waits) == canon({ 2, 4, 8, 16, 32, 60, 60, 60 }), "waits: " .. canon(waits))
	check(SaveScheduler.backoff(1, "throttle") == 4 and SaveScheduler.backoff(2, "throttle") == 8 and SaveScheduler.backoff(9, "throttle") == 60, "a throttle doubles")
	check(SaveScheduler.backoff(1, "config") == SaveRules.BACKOFF_CAP, "a configuration error waits the cap")
	local v = s:begin("progress", t)
	s:succeeded("progress", t, v)
	check(not s:isDirty("progress") and s:failures("progress") == 0, "success resets")
	s:markDirty("progress", t + 1)
	check(SaveScheduler.backoff(s:failures("progress") + 1, "transient") == 2, "and the next failure starts again at 2")
end)

case("scheduler: the request budget and the heartbeat", function()
	local s = SaveScheduler.new()
	s:track("a", 0)
	for i = 1, SaveRules.REQUESTS_PER_MINUTE do
		check(s:budgetOk(1000 + i), `request {i} fits`)
		s:begin(nil, 1000 + i)
	end
	check(not s:budgetOk(1000 + SaveRules.REQUESTS_PER_MINUTE), "the eleventh does not")
	s:markDirty("a", 1000)
	check(not s:due("a", 1015), "a dirty item waits for the budget too")
	check(s:budgetOk(1000 + 61), "a minute later it fits again")
	local h = SaveScheduler.new()
	check(h:heartbeatDue(0), "the first heartbeat is due")
	h:beat(0)
	check(not h:heartbeatDue(29) and h:heartbeatDue(30), "then every 30 s")
end)

-- ---------------------------------------------------------------------------------------------- sessions on the in-memory backend
local function newEnv(): any
	local e: any = { t = 100000, backend = MemoryBackend.new(), logs = {} :: { string }, calls = {} :: { any }, changes = {} :: { string } }
	e.now = function(): number return e.t end
	e.sleep = function(s: number) e.t += s end
	local update, read = e.backend.update, e.backend.read
	e.backend.update = function(self: any, key: string, fn: any): (boolean, any, string?)
		local ok, v, err = update(self, key, fn)
		table.insert(e.calls, { t = e.t, op = "update", key = key, ok = ok })
		return ok, v, err
	end
	e.backend.read = function(self: any, key: string): (boolean, any, string?)
		local ok, v, err = read(self, key)
		table.insert(e.calls, { t = e.t, op = "read", key = key, ok = ok })
		return ok, v, err
	end
	return e
end
local function newSession(e: any, uid: number, id: string, extra: { [string]: any }?): any
	local cfg: any = {
		backend = e.backend, userId = uid, sessionId = id, now = e.now, sleep = e.sleep,
		log = function(s: string) table.insert(e.logs, s) end,
		onChange = function(st: string, reason: string?) table.insert(e.changes, `{id}:{st}:{reason or ""}`) end,
	}
	if extra then for k, v in extra do cfg[k] = v end end
	return SaveSession.new(cfg)
end
local function run(e: any, s: any, seconds: number)
	for _ = 1, seconds do
		e.t += 1
		s:step()
	end
end
local function runBoth(e: any, a: any, b: any, seconds: number)
	for _ = 1, seconds do
		e.t += 1
		a:step()
		b:step()
	end
end
local function storedOf(e: any, key: string, spec: any): any
	return SaveEnvelope.open(spec or SaveProgress.SPEC, e.backend.data[key])
end
local function snapshotAll(e: any): string
	return canon(e.backend.data)
end
local function writes(e: any, from: number?): number
	local n = 0
	for i = (from or 0) + 1, #e.calls do
		-- every update is a request that may have written; the backend's own counter is the truth
	end
	return e.backend.writes
end

case("a new player: the record is made with a lock, progress is saved after the debounce, and a rejoin finds it", function()
	local e = newEnv()
	local a = newSession(e, 1, "A")
	check(a:load() == "active", "active")
	local o = storedOf(e, "P_1", nil)
	check(o.status == "ok" and o.lock ~= nil and o.lock.session == "A" and #o.payload.notebook.opened == 0, "a default record with A's lock")
	check(select(1, a:status()) == "saved", "saved")
	check(a:setProgress(prog({ "bold_jumper", "dragline" }, { eye = 30, appearance = "maratus_volans_male", settings = { LargeText = true } })), "progress accepted")
	check(select(1, a:status()) == "saving", "saving")
	run(e, a, 2)
	o = storedOf(e, "P_1", nil)
	check(#o.payload.notebook.opened == 2 and o.payload.appearance == "maratus_volans_male" and o.payload.settings.LargeText == true, "written at once (nothing written lately)")
	check(select(1, a:status()) == "saved", "saved again")
	local w0 = e.backend.writes
	a:setProgress(prog({ "bold_jumper", "dragline", "eight_eyes" }, { eye = 31 }))
	run(e, a, 5)
	a:setProgress(prog({ "bold_jumper", "dragline", "eight_eyes", "venom" }, { eye = 33 }))
	run(e, a, 5)
	check(e.backend.writes == w0, "two more events inside the debounce: no write yet")
	check(select(1, a:status()) == "saving", "still saving")
	run(e, a, 25)
	check(e.backend.writes == w0 + 1, `one coalesced write after the debounce ({e.backend.writes - w0})`)
	o = storedOf(e, "P_1", nil)
	check(#o.payload.notebook.opened == 4 and o.payload.notebook.eye_seconds == 33 and o.backup ~= nil and o.backup.status == "ok", "both events are in it, with the earlier version as the backup")
	a:flush()
	o = storedOf(e, "P_1", nil)
	check(o.lock == nil and o.status == "ok", "leaving releases the lock")
	local b = newSession(e, 1, "B")
	check(b:load() == "active", "the rejoin takes the lock at once")
	check(canon(b.progress.notebook.opened) == canon({ "bold_jumper", "dragline", "eight_eyes", "venom" }) and b.progress.appearance == "maratus_volans_male", "and has the notebook and the choice")
	check(#b.progress.settings == 0 and b.progress.settings.LargeText == true, "and the preferences")
end)

case("rests: saved per mode as separate values, handed back on a rejoin, the earlier one kept as the backup", function()
	local e = newEnv()
	local a = newSession(e, 2, "A")
	a:load()
	local rest1 = realRest(120, "main")
	local rest2 = realRest(240, "main")
	local free1 = realRest(150, "free")
	check(a:setRest("main", rest1) and a:setRest("free", free1), "accepted")
	check(not a:setRest("free", rest1), "a main rest is refused as a free one")
	check(not a:setRest("weekly", rest1), "an unknown mode is refused")
	check(select(2, a:status()) == "rest_refused", "the refused free rest is reported")
	check(a:setRest("free", free1), "a valid rest in the rejected slot clears its failure")
	run(e, a, 25)
	check(storedOf(e, "R_2_main", SaveRest.SPECS.main).status == "ok" and storedOf(e, "R_2_free", SaveRest.SPECS.free).status == "ok", "both are stored, apart")
	check(e.backend.data["P_2"].payload.notebook ~= nil and e.backend.data["R_2_main"].payload.player ~= nil, "progress and rest are different values")
	a:setRest("main", rest2)
	run(e, a, 15)
	local om = storedOf(e, "R_2_main", SaveRest.SPECS.main)
	check(canon(om.payload) == canon(rest2) and om.backup ~= nil and canon(om.backup.payload) == canon(rest1), "the newer rest, the earlier as its backup")
	check(select(1, a:status()) == "saved", "saved")
	a:flush()
	local b = newSession(e, 2, "B")
	b:load()
	check(canon(b.rests.main) == canon(rest2) and canon(b.rests.free) == canon(free1), "a rejoin gets both rests back")
	local snap = b:snapshot()
	check(snap.status == "saved" and snap.rests.main ~= nil, "and the snapshot for the client has them")
end)

case("a failed load never overwrites good data: every kind of failure, for ten minutes and a leave, leaves every stored byte as it was", function()
	local kinds: { { string | (any) -> () } } = {
		{ "the store is down (reads and updates)", function(e: any) e.backend:fail({ op = "any", times = 100000, message = "503: the service is unavailable" }) end },
		{ "throttled", function(e: any) e.backend:fail({ op = "any", times = 100000, message = "304: UpdateAsync over limit" }) end },
		{ "studio access off", function(e: any) e.backend:fail({ op = "any", times = 100000, message = "403: Studio access to APIs is not allowed" }) end },
		{ "a checksum that does not match", function(e: any) e.backend.data["P_3"].payload.notebook.eye_seconds = 1234 end },
		{ "cut short (no checksum, no payload)", function(e: any) e.backend.data["P_3"] = { format = SaveRules.FORMAT, kind = "progress", schema = 1, updatedAt = 5 } end },
		{ "not a table at all", function(e: any) e.backend.data["P_3"] = "{\"notebook\": {\"opened\": [\"bold_jum" end },
		{ "from a newer game", function(e: any) e.backend.data["P_3"] = { format = SaveRules.FORMAT, kind = "progress", schema = 9, updatedAt = 5, payload = { future = true }, checksum = "x" } end },
		{ "a good checksum on nonsense", function(e: any)
			local bad = { notebook = "yes" }
			e.backend.data["P_3"] = { format = SaveRules.FORMAT, kind = "progress", schema = 1, updatedAt = 5, payload = bad, checksum = Json.checksum(canon({ kind = "progress", schema = 1, updatedAt = 5, payload = bad })) }
		end },
		{ "locked by a live session", function(e: any) e.backend.data["P_3"] = SaveEnvelope.withLock(e.backend.data["P_3"], { session = "OTHER", beat = e.t + 5000 }) end },
	}
	for _, kind in kinds do
		local label, inject = kind[1] :: string, kind[2] :: (any) -> ()
		local e = newEnv()
		-- a good life first: a notebook, a choice, both rests
		local first = newSession(e, 3, "FIRST")
		first:load()
		first:setProgress(prog({ "bold_jumper", "venom", "retreat" }, { eye = 90, finished = true, appearance = "maratus_volans_male" }))
		first:setRest("main", realRest(120, "main"))
		run(e, first, 40)
		first:flush()
		local good = storedOf(e, "P_3", nil)
		check(good.status == "ok" and #good.payload.notebook.opened == 3, `[{label}] the good record is there to begin with`)
		inject(e)
		local before = snapshotAll(e)
		local w0 = e.backend.writes
		local s = newSession(e, 3, "SECOND")
		local state = s:load()
		check(state == "session" or state == "loading", `[{label}] the load did not succeed (state {state})`)
		s:setProgress(prog({ "eight_eyes", "drinking" }, { eye = 5, appearance = "first_spider", settings = { LargeText = true } }))
		s:setRest("main", realRest(130, "main"))
		s:setRest("free", realRest(130, "free"))
		run(e, s, 600)
		s:flush()
		check(e.backend.writes == w0, `[{label}] nothing was written ({e.backend.writes - w0} writes)`)
		check(snapshotAll(e) == before, `[{label}] every stored value is byte for byte as it was`)
		check(select(1, s:status()) == "session", `[{label}] the session says it is session-only`)
		check(#s.progress.notebook.opened >= 2, `[{label}] the player's own progress is still in memory`)
	end
end)

case("a transient outage at load is retried: progress kept in memory meanwhile is merged with the stored record, nothing lost either way", function()
	local e = newEnv()
	local first = newSession(e, 4, "FIRST")
	first:load()
	first:setProgress(prog({ "bold_jumper", "venom" }, { eye = 10, finished = true, appearance = "maratus_volans_male", settings = { LargeText = true } }))
	run(e, first, 3)
	first:flush()
	e.backend:fail({ op = "any", times = 4, message = "503: the service is unavailable" })
	local loaded: { any } = {}
	local s = newSession(e, 4, "SECOND", { onLoaded = function(snap: any) table.insert(loaded, snap) end })
	check(s:load() == "session" and s.reason == "load_failed", "the first try fails")
	s:setProgress(prog({ "eight_eyes" }, { eye = 3, settings = { SoundMuted = true } }))
	local seen = false
	for _ = 1, 120 do
		e.t += 1
		s:step()
		if s.state == "active" then seen = true break end
	end
	check(seen, `it tried again and held the record (after {#e.calls} requests)`)
	check(#loaded == 1 and canon(loaded[1].progress.notebook.opened) == canon({ "bold_jumper", "venom", "eight_eyes" }), "and told the client what is stored, merged with this visit")
	run(e, s, 40)
	local o = storedOf(e, "P_4", nil)
	check(canon(o.payload.notebook.opened) == canon({ "bold_jumper", "venom", "eight_eyes" }) and o.payload.finished_main == true and o.payload.appearance == "maratus_volans_male", "the merged record is stored: the old pages, the new one, the old choice")
	check(o.payload.settings.LargeText == true and o.payload.settings.SoundMuted == true, "preferences from both")
	check(o.backup ~= nil and o.backup.payload.notebook.eye_seconds == 10, "and the version before is its backup")
	check(select(1, s:status()) == "saved", "saved")
end)

case("a corrupt record is left alone; its good backup is shown meanwhile, and the player is told saving is off", function()
	local e = newEnv()
	local a = newSession(e, 5, "A")
	a:load()
	a:setProgress(prog({ "p1", "p2" }, { eye = 5 }))
	run(e, a, 2)
	a:setProgress(prog({ "p1", "p2", "p3" }, { eye = 8 }))
	run(e, a, 40)
	a:flush()
	local d = e.backend.data["P_5"]
	check(d.backup ~= nil, "there is a backup")
	d.payload.notebook.eye_seconds = 99999 -- damage the current one
	local before = snapshotAll(e)
	local b = newSession(e, 5, "B")
	check(b:load() == "session" and b.reason == "corrupt", "session-only: corrupt")
	check(canon(b.progress.notebook.opened) == canon({ "p1", "p2" }), "the backup's notebook is what the player sees meanwhile")
	run(e, b, 300)
	b:flush()
	check(snapshotAll(e) == before, "nothing was written over the corrupt record")
	check(select(2, b:status()) == "corrupt", "the reason is told to the client")
end)

case("a record from a newer game is never read past its header or written", function()
	local e = newEnv()
	local future = { format = SaveRules.FORMAT, kind = "progress", schema = SaveProgress.SCHEMA + 1, updatedAt = 12, payload = { notebook = { opened = { "from_the_future" } }, shiny = true }, checksum = "later", lock = { session = "Z", beat = 1 } }
	e.backend.data["P_6"] = future
	e.backend.data["R_6_main"] = { format = SaveRules.FORMAT, kind = "rest_main", schema = 7, updatedAt = 12, payload = { new = "world" }, checksum = "later" }
	local before = snapshotAll(e)
	local s = newSession(e, 6, "S")
	check(s:load() == "session" and s.reason == "newer", "session-only: newer")
	s:setProgress(prog({ "bold_jumper" }))
	s:setRest("main", realRest(120, "main"))
	run(e, s, 400)
	s:flush()
	check(snapshotAll(e) == before and e.backend.writes == 0, "untouched, including its lock")
	check(s.reason == "newer" and not s.canRetry, "and it does not keep retrying")
	-- A newer rest protects only its own slot; unreadable progress above still stops all writes.
	local e2 = newEnv()
	e2.backend.data["R_7_free"] = { format = SaveRules.FORMAT, kind = "rest_free", schema = 7, updatedAt = 12, payload = { new = "world" }, checksum = "later" }
	local s2 = newSession(e2, 7, "S")
	s2:load()
	check(s2.state == "active" and s2.restProtected.free == "newer", "a newer rest alone protects its own slot")
	local keep = canon(e2.backend.data["R_7_free"])
	s2:setRest("free", realRest(120, "free"))
	run(e2, s2, 100)
	s2:flush()
	check(canon(e2.backend.data["R_7_free"]) == keep, "and the newer rest is not written over")
end)

case("an older schema migrates forward when saved, and the old version is kept as the backup", function()
	local e = newEnv()
	-- (a later schema than this build's, to show the pattern for the next change)
	local spec3: SaveEnvelope.Spec = {
		kind = "progress", current = 3,
		migrations = { [2] = function(p: any): any p.settings = p.settings or {}; p.settings.LargeText = true; return p end },
		validate = SaveProgress.SPEC.validate,
	}
	local old = SaveProgress.snapshot({ opened = { "p1" }, eye_seconds = 4 }, false, nil, {})
	e.backend.data["P_8"] = stored(SaveProgress.SPEC, 2, old, 50)
	local s = newSession(e, 8, "S", { progressSpec = spec3 })
	check(s:load() == "active", "an older record loads")
	check(s.progress.settings.LargeText == true and #s.progress.notebook.opened == 1, "migrated in memory")
	check(e.backend.data["P_8"].schema == 2, "and the stored value is still schema 2 (loading writes only the lock)")
	s:setProgress(prog({ "p1", "p2" }))
	run(e, s, 3)
	local o = SaveEnvelope.open(spec3, e.backend.data["P_8"])
	check(o.status == "ok" and e.backend.data["P_8"].schema == 3 and #o.payload.notebook.opened == 2, "saved at schema 3")
	check(o.backup ~= nil and o.backup.migratedFrom == 2 and #o.backup.payload.notebook.opened == 1, "the schema-2 version is its backup")
	-- this build (schema 2 only) now sees schema 3 as newer: it must not touch it
	local s1 = newSession(e, 8, "OLDBUILD")
	s:flush()
	local before = snapshotAll(e)
	check(s1:load() == "session" and s1.reason == "newer", "the older build refuses the record the newer one wrote")
	run(e, s1, 100)
	s1:flush()
	check(snapshotAll(e) == before, "and leaves it as it is")
end)

case("settings (ROBLOX-49): a schema-1 record's seven toggles become settings, older records load with defaults for the new ones", function()
	local e = newEnv()
	-- the record a v19 build wrote: schema 1, `prefs` of booleans
	local v1 = { notebook = { opened = { "eight_eyes", "venom" }, eye_seconds = 33 }, finished_main = true, appearance = "maratus_volans_male",
		prefs = { LargeText = true, ShowLastSeen = false, SoundMuted = true, FocusToggle = false, SomethingGone = true } }
	e.backend.data["P_21"] = stored(SaveProgress.SPEC, 1, v1, 40)
	local o = SaveEnvelope.open(SaveProgress.SPEC, e.backend.data["P_21"])
	check(o.status == "migrated" and o.migratedFrom == 1, "it opens as migrated from 1")
	local pl = o.payload
	check(pl.prefs == nil and pl.settings.LargeText == true and pl.settings.ShowLastSeen == false and pl.settings.SoundMuted == true and pl.settings.FocusToggle == false, "the toggles are now settings")
	check(pl.settings.SomethingGone == nil and pl.settings.MasterVolume == nil and pl.settings.Captions == nil, "an unknown toggle is left behind; new settings are simply not there")
	check(#pl.notebook.opened == 2 and pl.notebook.eye_seconds == 33 and pl.finished_main == true and pl.appearance == "maratus_volans_male", "nothing else changed")
	check(pl.settings_version == 1, "settings version 1")
	local s = newSession(e, 21, "S")
	check(s:load() == "active", "the session loads it")
	check(s.progress.settings.LargeText == true, "in memory")
	local m = SettingsModel.get(function(id: string): any return s.progress.settings[id] end, "MasterVolume")
	check(m == 1.0, "a setting the old record never had reads as its default")
	check(e.backend.data["P_21"].schema == 1, "loading changes nothing stored but the lock")
	s:setProgress(prog({ "eight_eyes", "venom", "drinking" }, { eye = 40, finished = true, settings = { MasterVolume = 0.4, Captions = "large" } }))
	run(e, s, 3)
	local w = SaveEnvelope.open(SaveProgress.SPEC, e.backend.data["P_21"])
	check(w.status == "ok" and e.backend.data["P_21"].schema == 2, "the next write is schema 2")
	check(w.payload.settings.LargeText == true and w.payload.settings.MasterVolume == 0.4 and w.payload.settings.Captions == "large", "old and new settings together")
	check(w.backup ~= nil and w.backup.migratedFrom == 1 and w.backup.payload.settings.LargeText == true, "the schema-1 record is its backup")
	-- a damaged old record is not guessed at
	local e2 = newEnv()
	local rec = stored(SaveProgress.SPEC, 1, v1, 40)
	rec.payload.prefs.LargeText = false -- after the checksum was taken
	e2.backend.data["P_22"] = rec
	local s2 = newSession(e2, 22, "S")
	check(s2:load() == "session" and s2.reason == "corrupt", "a record whose checksum no longer matches is corrupt, migrated or not")
end)

case("settings (ROBLOX-49): progress sanitising checks type, range and id", function()
	local good = prog({ "bold_jumper" }, { eye = 1, settings = { LargeText = true } })
	local function with(change: (any) -> ()): ({ string }, any)
		local c = Json.copy(good)
		change(c)
		return SaveProgress.sanitize(c)
	end
	local pr, cl = with(function(c) c.settings = { MasterVolume = 0.35, Captions = "off", FieldOfView = 70, InvertY = true } end)
	check(#pr == 0 and cl.settings.MasterVolume == 0.35 and cl.settings.Captions == "off" and cl.settings.FieldOfView == 70 and cl.settings.InvertY == true, "numbers, choices and toggles are kept")
	pr, cl = with(function(c) c.settings = { MasterVolume = 7, LookSensitivityMouse = -2, CameraDistance = 100 } end)
	check(#pr == 0 and cl.settings.MasterVolume == 1 and cl.settings.LookSensitivityMouse == 0.2 and cl.settings.CameraDistance == 7, "out-of-range numbers are clamped to the range")
	pr = with(function(c) c.settings = { MasterVolume = "loud" } end)
	check(#pr > 0, "a number setting that is a string is refused")
	pr = with(function(c) c.settings = { MasterVolume = 0 / 0 } end)
	check(#pr > 0, "NaN is refused")
	pr = with(function(c) c.settings = { FieldOfView = math.huge } end)
	check(#pr > 0, "infinity is refused")
	pr = with(function(c) c.settings = { InvertY = 1 } end)
	check(#pr > 0, "a toggle that is a number is refused")
	pr = with(function(c) c.settings = { Captions = 7 } end)
	check(#pr > 0, "a choice that is a number is refused")
	pr, cl = with(function(c) c.settings = { Captions = "tiny", Mystery = 5, [3] = true } end)
	check(#pr > 0, "a key that is not a name is refused")
	pr, cl = with(function(c) c.settings = { Captions = "tiny", Mystery = 5, Another = {} } end)
	check(#pr == 0 and cl.settings.Captions == nil and cl.settings.Mystery == nil and cl.settings.Another == nil, "an unknown id and an unknown option are dropped quietly")
	pr = with(function(c) c.settings = "all" end)
	check(#pr > 0, "settings that are not a table are refused")
	pr = with(function(c) c.settings_version = "one" end)
	check(#pr > 0, "a settings version that is not a number is refused")
	pr = with(function(c) c.settings_version = 0 end)
	check(#pr > 0, "settings version 0 is refused")
	pr, cl = with(function(c) c.settings = nil end)
	check(#pr == 0 and next(cl.settings) == nil and cl.settings_version == SettingsModel.VERSION, "no settings at all is fine")
	pr, cl = with(function(c) c.prefs = { LargeText = true }; c.settings = nil end)
	check(#pr == 0 and next(cl.settings) == nil, "the old `prefs` field of a stale client is ignored, not trusted")
	local big: { [string]: any } = {}
	for i = 1, 400 do big["Setting" .. i] = i end
	pr, cl = with(function(c) c.settings = big end)
	check(#pr == 0 and next(cl.settings) == nil, "hundreds of unknown ids are all dropped")
	-- whatever a client sends, what is kept is clean
	local seed49 = 49
	local rnd = { NextInteger = function(_self: any, lo: number, hi: number): number
		seed49 = (seed49 * 1103515245 + 12345) % 2147483648
		return lo + seed49 % (hi - lo + 1)
	end }
	local junk: { any } = { true, false, 0, 1, -1, 0.5, 1e9, -1e9, "off", "large", "", {}, math.huge, -math.huge, 0 / 0 }
	for _ = 1, 300 do
		local c = Json.copy(good)
		c.settings = {}
		for _ = 1, 6 do
			local ids = SettingsModel.ids()
			c.settings[ids[rnd:NextInteger(1, #ids)]] = junk[rnd:NextInteger(1, #junk)]
		end
		local p2, k = SaveProgress.sanitize(c)
		if #p2 == 0 then
			for id, v in k.settings do
				if SettingsModel.clean(id, v) ~= v then check(false, `kept an unclean {id}`) end
			end
		end
	end
	check(true, "300 random settings objects: nothing unclean is ever kept")
	-- merging, comparing and sending
	local a = prog({}, { settings = { MasterVolume = 0.2, InvertY = true } })
	local b = prog({}, { settings = { MasterVolume = 0.9, Captions = "off" } })
	local m = SaveProgress.merge(a, b, 10, 20)
	check(m.settings.MasterVolume == 0.9 and m.settings.InvertY == true and m.settings.Captions == "off", "settings merge key by key, the newer first")
	m = SaveProgress.merge(a, b, 30, 20)
	check(m.settings.MasterVolume == 0.2 and m.settings.Captions == "off" and m.settings.InvertY == true, "and the older incoming does not override a newer stored one")
	check(SaveProgress.same(a, Json.copy(a)) and not SaveProgress.same(a, b), "same() sees settings")
	local snap = SaveProgress.snapshot({ opened = {}, eye_seconds = 0 }, false, nil, { MasterVolume = 0.5, InvertY = "yes", Mystery = true, Captions = "large", FieldOfView = 400 })
	check(snap.settings.MasterVolume == 0.5 and snap.settings.InvertY == nil and snap.settings.Mystery == nil and snap.settings.Captions == "large" and snap.settings.FieldOfView == 90, "the snapshot sends only clean settings")
	check(#(SaveProgress.sanitize(snap)) == 0, "and the snapshot passes its own check")
	local text = canon(SaveProgress.snapshot({ opened = {}, eye_seconds = 0 }, false, nil, SettingsModel.defaults()))
	check(#text < 1500 and #text < SaveRules.MAX_PROGRESS_CHARS / 8, `a full set of settings is small ({#text} characters)`)
end)

case("oversized and malformed things from the client never reach the store", function()
	local e = newEnv()
	local s = newSession(e, 9, "S")
	s:load()
	local rest = realRest(120, "main")
	local fat = Json.copy(rest)
	fat.player.extra = string.rep("x", SaveRules.MAX_REST_CHARS)
	check(not s:setRest("main", fat), "an oversized rest is refused")
	local rejectedStatus, rejectedReason = s:status()
	check(rejectedStatus == "saving" and rejectedReason == "rest_refused", "a rejected rest is never labelled Saved")
	s:notify()
	check(select(2, s:status()) == "rest_refused", "the failure survives a normal status refresh")
	check(s:setRest("main", rest), "a later valid rest is accepted")
	check(select(2, s:status()) == nil, "a valid replacement clears the rejection")
	-- Keep the original malformed-input test's store empty.
	s.restPending.main = nil
	s.sched:abandon("rest_main")
	local many: { string } = {}
	for i = 1, SaveRules.MAX_PAGES + 5 do many[i] = "p" .. i end
	local huge = prog({}, {})
	huge.notebook.opened = many
	check(not s:setProgress(huge), "too many pages are refused")
	check(not s:setProgress("progress") and not s:setProgress(nil) and not s:setProgress({ notebook = {} }), "junk progress is refused")
	check(not s:setRest("main", "x") and not s:setRest("main", nil) and not s:setRest(nil :: any, rest), "junk rests are refused")
	local keepProgress = canon(e.backend.data["P_9"].payload)
	run(e, s, 100)
	check(canon(e.backend.data["P_9"].payload) == keepProgress and e.backend.data["R_9_main"] == nil, "nothing was written but the lock's beat")
	check(s.counters.rejected >= 5, `the refusals are counted ({s.counters.rejected})`)
	-- a value the store itself refuses (too large) is dropped, not retried for ever
	local e2 = newEnv()
	local s2 = newSession(e2, 10, "S")
	s2:load()
	s2:setRest("main", realRest(120, "main"))
	e2.backend:fail({ op = "update", key = "R_10_main", times = 1, message = "105: ValueTooLarge" })
	run(e2, s2, 60)
	check(not s2.sched:isDirty("rest_main") and s2.restPending.main == nil, "a value that can never be stored is abandoned, not retried")
	check(select(1, s2:status()) == "session" and s2.reason == "write_failed", "play carries on but the rejected save is never called Saved")
end)

case("throttling and outages while saving: the change stays dirty, retries back off 4, 8, 16 s, and it lands when the store returns", function()
	local e = newEnv()
	local s = newSession(e, 11, "S")
	s:load()
	local mark = #e.calls
	e.backend:fail({ op = "update", key = "P_11", times = 3, message = "304: UpdateAsync over limit" })
	s:setProgress(prog({ "bold_jumper" }))
	local t0 = e.t
	for _ = 1, 80 do
		e.t += 1
		s:step()
	end
	local attempts: { number } = {}
	for i = mark + 1, #e.calls do
		local c = e.calls[i]
		if c.key == "P_11" and c.op == "update" then table.insert(attempts, c.t - t0) end
	end
	check(canon({ attempts[1], attempts[2], attempts[3], attempts[4] }) == canon({ 1, 5, 13, 29 }), "attempts at 1, then +4, +8, +16 s: " .. canon(attempts))
	check(storedOf(e, "P_11", nil).payload.notebook.opened[1] == "bold_jumper", "and the fourth landed")
	check(select(1, s:status()) == "saved", "saved")
	-- a long outage: status says so after three failures, and nothing is lost
	e.backend:fail({ op = "any", times = 100000, message = "502: API Services rejected request" })
	s:setProgress(prog({ "bold_jumper", "dragline" }))
	run(e, s, 200)
	local st, why = s:status()
	check(st == "saving" and why == "write_failed", `trouble is told ({st}/{why})`)
	e.backend:clearFaults()
	run(e, s, 80)
	check(select(1, s:status()) == "saved" and #storedOf(e, "P_11", nil).payload.notebook.opened == 2, "and it all lands when the store is back")
	-- the budget: however long it fails, requests stay within the minute's allowance
	local worst = 0
	for i = 1, #e.calls do
		local n = 0
		for j = i, #e.calls do
			if e.calls[j].t - e.calls[i].t < 60 then n += 1 end
		end
		worst = math.max(worst, n)
	end
	check(worst <= SaveRules.REQUESTS_PER_MINUTE + 1, `at most {SaveRules.REQUESTS_PER_MINUTE} requests in any minute (worst {worst})`)
end)

case("an interrupted write (it happened, but the answer was lost) is retried without harm, and the backup stays the version before", function()
	local e = newEnv()
	local s = newSession(e, 12, "S")
	s:load()
	s:setProgress(prog({ "p1" }))
	run(e, s, 3)
	s:setProgress(prog({ "p1", "p2" }, { eye = 4 }))
	e.backend:fail({ op = "update", key = "P_12", times = 1, message = "504: timed out", afterWrite = true })
	run(e, s, 90)
	local o = storedOf(e, "P_12", nil)
	check(canon(o.payload.notebook.opened) == canon({ "p1", "p2" }) and o.status == "ok", "stored once, correctly")
	check(o.backup ~= nil and canon(o.backup.payload.notebook.opened) == canon({ "p1" }), "the backup is still the version before, not a copy of the new one")
	check(select(1, s:status()) == "saved", "saved")
	-- the same for a rest
	local e2 = newEnv()
	local r = newSession(e2, 13, "S")
	r:load()
	local rest1, rest2 = realRest(120, "main"), realRest(300, "main")
	r:setRest("main", rest1)
	run(e2, r, 3)
	r:setRest("main", rest2)
	e2.backend:fail({ op = "update", key = "R_13_main", times = 2, message = "504: timed out", afterWrite = true })
	run(e2, r, 120)
	local or2 = storedOf(e2, "R_13_main", SaveRest.SPECS.main)
	check(canon(or2.payload) == canon(rest2) and or2.backup ~= nil and canon(or2.backup.payload) == canon(rest1), "the rest: the new one, with the earlier as backup")
	check(select(1, r:status()) == "saved", "rest saved")
end)

case("competing sessions: a live lock holds, a stale one is taken over, and the older session goes read-only with nothing lost", function()
	local e = newEnv()
	local a = newSession(e, 14, "A")
	a:load()
	a:setProgress(prog({ "a1" }, { eye = 3 }))
	run(e, a, 3)
	local b = newSession(e, 14, "B")
	check(b:load() == "session" and b.reason == "other_session", "B finds A's live lock: session-only, read-only")
	check(canon(b.progress.notebook.opened) == canon({ "a1" }), "B sees A's notebook meanwhile")
	b:setProgress(prog({ "b1" }, { eye = 9 }))
	for _ = 1, 100 do -- A keeps its heartbeat, B keeps asking: B never takes over
		e.t += 1
		a:step()
		b:step()
	end
	check(b.state == "session" and a.state == "active", "A, alive and heartbeating, keeps the lock for 100 s")
	local lock = e.backend.data["P_14"].lock
	check(lock.session == "A" and e.t - lock.beat <= SaveRules.HEARTBEAT + 1, "and its beat is fresh")
	check(storedOf(e, "P_14", nil).payload.notebook.opened[2] == nil, "B wrote nothing")
	-- A hangs (no more steps): after LOCK_STALE B takes over and merges what it kept
	local hangStart = e.t
	local took = -1
	for _ = 1, 300 do
		e.t += 1
		b:step()
		if b.state == "active" then took = e.t - hangStart break end
	end
	check(took > SaveRules.LOCK_STALE - SaveRules.HEARTBEAT - 1 and took <= SaveRules.LOCK_STALE + SaveRules.RETRY_LOAD + SaveRules.HEARTBEAT, `B took over after the lock went stale ({took} s)`)
	run(e, b, 40)
	local o = storedOf(e, "P_14", nil)
	check(canon(o.payload.notebook.opened) == canon({ "a1", "b1" }) and o.payload.notebook.eye_seconds == 9 and o.lock.session == "B", "B's record holds A's page and its own")
	-- A wakes up: its next write finds the lock is B's, A goes read-only, and what A had is not lost to B either way
	a:setProgress(prog({ "a1", "a2" }, { eye = 12 }))
	for _ = 1, 40 do
		e.t += 1
		a:step()
		b:step()
	end
	check(a.state == "session" and a.reason == "other_session", "A is told: read-only")
	check(select(2, a:status()) == "other_session", "with the same plain reason")
	o = storedOf(e, "P_14", nil)
	check(table.find(o.payload.notebook.opened, "a2") == nil and o.lock.session == "B", "A wrote nothing over B")
	-- B leaves; A gets the lock at its next try and its page joins the union
	b:flush()
	local got = false
	for _ = 1, 60 do
		e.t += 1
		a:step()
		if a.state == "active" then got = true break end
	end
	check(got, "once B has left, A can hold it again")
	run(e, a, 40)
	o = storedOf(e, "P_14", nil)
	check(canon(o.payload.notebook.opened) == canon({ "a1", "b1", "a2" }) and o.payload.notebook.eye_seconds == 12, "everyone's pages are in it: a union")
end)

case("rests across sessions: a rest another session wrote after this one read is not overwritten", function()
	local e = newEnv()
	local a = newSession(e, 15, "A")
	a:load()
	local rA1 = realRest(120, "main")
	a:setRest("main", rA1)
	run(e, a, 15)
	-- A hangs; B takes over and writes a newer rest
	e.t += SaveRules.LOCK_STALE + 5
	local b = newSession(e, 15, "B")
	check(b:load() == "active", "B takes over the stale lock")
	local rB = realRest(500, "main")
	b:setRest("main", rB)
	run(e, b, 15)
	check(canon(storedOf(e, "R_15_main", SaveRest.SPECS.main).payload) == canon(rB), "B's rest is stored")
	-- A wakes with a new rest of its own; its write is refused because the stored one is newer than the one A last saw
	a:setRest("main", realRest(200, "main"))
	local st = e.t
	for _ = 1, 40 do
		e.t += 1
		a:step()
		b:step()
	end
	check(canon(storedOf(e, "R_15_main", SaveRest.SPECS.main).payload) == canon(rB), "B's rest is still the stored one")
	check(a.state == "session", "A is read-only")
end)

case("leaving: whatever is waiting is written with retries inside the deadline, the lock is released; a session-only visit writes nothing", function()
	local e = newEnv()
	local s = newSession(e, 16, "S")
	s:load()
	s:setProgress(prog({ "p1", "p2" }))
	s:setRest("main", realRest(120, "main"))
	e.backend:fail({ op = "update", times = 2, message = "503: the service is unavailable" })
	local t0 = e.t
	s:flush()
	check(storedOf(e, "P_16", nil).payload.notebook.opened[2] == "p2" and storedOf(e, "R_16_main", SaveRest.SPECS.main).status == "ok", "both were written after two failures")
	check(storedOf(e, "P_16", nil).lock == nil, "and the lock is released")
	check(e.t - t0 <= SaveRules.FLUSH_DEADLINE, `inside the deadline ({e.t - t0} s)`)
	-- a store that is down for the whole deadline: it gives up in time, keeps nothing half-written
	local e2 = newEnv()
	local s2 = newSession(e2, 17, "S")
	s2:load()
	s2:setProgress(prog({ "p1" }))
	e2.backend:fail({ op = "update", times = 1000, message = "503: the service is unavailable" })
	local t1 = e2.t
	s2:flush()
	check(e2.t - t1 <= SaveRules.FLUSH_DEADLINE, `a dead store: gives up inside the deadline ({e2.t - t1} s)`)
	check(e2.backend.data["P_17"] ~= nil and storedOf(e2, "P_17", nil).status == "ok", "what was stored before is intact")
	-- the lock then goes stale and the next visit takes it
	e2.backend:clearFaults()
	e2.t += SaveRules.LOCK_STALE + 1
	local next = newSession(e2, 17, "NEXT")
	check(next:load() == "active", "the next visit finds a stale lock and takes it")
	-- session-only leaves nothing
	local e3 = newEnv()
	e3.backend.data["P_18"] = { format = SaveRules.FORMAT, kind = "progress", schema = 1, updatedAt = 1 }
	local keep = snapshotAll(e3)
	local s3 = newSession(e3, 18, "S")
	s3:load()
	s3:setProgress(prog({ "x" }))
	s3:flush()
	check(snapshotAll(e3) == keep and e3.backend.writes == 0, "a session-only visit writes nothing on leaving")
	-- after closing, nothing more is accepted or written
	check(not s3:setProgress(prog({ "y" })) and not s:setProgress(prog({ "z" })), "a closed session accepts nothing")
	local w = e.backend.writes
	s:step()
	check(e.backend.writes == w, "and does not step")
end)

case("the lock is refreshed on the heartbeat without touching the payload, the checksum or the backup", function()
	local e = newEnv()
	local s = newSession(e, 19, "S")
	s:load()
	s:setProgress(prog({ "p1" }))
	run(e, s, 3)
	s:setProgress(prog({ "p1", "p2" }))
	run(e, s, 35)
	local before = e.backend.data["P_19"]
	local sum, upd, payload, backup = before.checksum, before.updatedAt, canon(before.payload), canon(before.backup)
	local beat0 = before.lock.beat
	run(e, s, 100)
	local after = e.backend.data["P_19"]
	check(after.lock.beat > beat0, "the beat moved")
	check(after.checksum == sum and after.updatedAt == upd and canon(after.payload) == payload and canon(after.backup) == backup, "nothing else did")
	check(SaveEnvelope.open(SaveProgress.SPEC, after).status == "ok", "and it still opens")
end)

case("a restart of a rest read: a failed read of a rest is retried and handed to the client when it arrives", function()
	local e = newEnv()
	local first = newSession(e, 20, "FIRST")
	first:load()
	local rest = realRest(120, "main")
	first:setRest("main", rest)
	run(e, first, 20)
	first:flush()
	e.backend:fail({ op = "read", key = "R_20_*", times = 2, message = "503: the service is unavailable" })
	local got: { any } = {}
	local s = newSession(e, 20, "SECOND", { onRest = function(mode: string, rec: any) table.insert(got, { mode, rec }) end })
	check(s:load() == "active" and s.rests.main == nil, "progress loads; the rests could not be read yet")
	run(e, s, 60)
	check(#got == 1 and got[1][1] == "main" and canon(got[1][2]) == canon(rest), "the rest arrived later and was handed over")
end)

case("random operations, faults and two sessions: stored progress only ever grows, every stored value is a good save, and nothing raises", function()
	local seed = 12345
	local function rnd(n: number): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed % n + 1
	end
	local rests = { realRest(120, "main"), realRest(200, "main") }
	local freeRests = { realRest(120, "free") }
	local faults = { "503: the service is unavailable", "304: UpdateAsync over limit", "504: timed out", "302: over limit" }
	local bad = 0
	for run_ = 1, 8 do
		local e = newEnv()
		local sessions = { newSession(e, 30, "S1"), newSession(e, 30, "S2") }
		local maxPages = 0
		local seen: { [string]: boolean } = {}
		for _, s in sessions do s:load() end
		for step_ = 1, 300 do
			e.t += rnd(6)
			local s = sessions[rnd(2)]
			local roll = rnd(100)
			if roll <= 20 then
				local id = "page" .. rnd(40)
				seen[id] = true
				local ids: { string } = {}
				for _, x in s.progress.notebook.opened do table.insert(ids, x) end
				table.insert(ids, id)
				s:setProgress(prog(ids, { eye = rnd(100), settings = { LargeText = rnd(2) == 1 } }))
			elseif roll <= 28 then
				s:setRest("main", rests[rnd(#rests)])
			elseif roll <= 32 then
				s:setRest("free", freeRests[1])
			elseif roll <= 38 then
				e.backend:fail({ op = if rnd(2) == 1 then "update" else "any", times = rnd(3), message = faults[rnd(#faults)], afterWrite = rnd(4) == 1 })
			elseif roll <= 41 then
				e.t += rnd(150) -- a hang
			elseif roll <= 43 then
				s:flush()
				local id = s.id
				sessions[if id == "S1" then 1 else 2] = newSession(e, 30, id .. "x")
				sessions[if id == "S1" then 1 else 2]:load()
			end
			for _, x in sessions do x:step() end
			-- invariants, every step
			local d = e.backend.data["P_30"]
			if d ~= nil then
				local o = SaveEnvelope.open(SaveProgress.SPEC, d)
				if o.status ~= "ok" then bad += 1; print("  not ok: " .. o.status .. " " .. tostring(o.reasons[1])) end
				if o.payload then
					if #o.payload.notebook.opened < maxPages then bad += 1; print("  the stored pages shrank") end
					maxPages = math.max(maxPages, #o.payload.notebook.opened)
				end
			end
			for _, k in { "R_30_main", "R_30_free" } do
				local rv = e.backend.data[k]
				if rv ~= nil and step_ % 25 == 0 then
					local ro = SaveEnvelope.open(SaveRest.SPECS[if k == "R_30_main" then "main" else "free"], rv)
					if ro.status ~= "ok" then bad += 1; print("  a rest is not ok: " .. ro.status) end
				end
			end
		end
		for _, s in sessions do s:flush() end
		local o = SaveEnvelope.open(SaveProgress.SPEC, e.backend.data["P_30"])
		for id in seen do
			-- a page found in a session that never held the lock may legitimately be missing; but a page that was ever STORED must stay
		end
		if o.status ~= "ok" then bad += 1 end
	end
	check(bad == 0, `{bad} invariant breaks in 8 runs of 300 steps`)
end)

-- ---------------------------------------------------------------------------------------------- the server service, with scripted clients
local function newServer(e: any, opts: { [string]: any }?): any
	local srv: any = { sent = {} :: { [any]: { any } }, queue = {} :: { () -> () }, deferSpawn = false, logs = e.logs }
	local o: any = opts or {}
	srv.service = SaveService.new({
		backend = o.backend or e.backend, now = e.now, sleep = e.sleep, jobId = o.jobId or "JOB",
		spawn = function(fn: any, ...: any)
			if srv.deferSpawn then
				local args = { ... }
				table.insert(srv.queue, function() fn(table.unpack(args)) end)
			else
				fn(...)
			end
		end,
		send = function(player: any, msg: any)
			srv.sent[player] = srv.sent[player] or {}
			table.insert(srv.sent[player], Json.copy(msg))
		end,
		log = function(text: string) table.insert(e.logs, text) end,
	})
	function srv.drain()
		while #srv.queue > 0 do
			local f = table.remove(srv.queue, 1)
			f()
		end
	end
	function srv.last(player: any, kind: string): any
		local list = srv.sent[player] or {}
		for i = #list, 1, -1 do if list[i].kind == kind then return list[i] end end
		return nil
	end
	function srv.count(player: any, kind: string): number
		local n = 0
		for _, m in srv.sent[player] or {} do if m.kind == kind then n += 1 end end
		return n
	end
	return srv
end
local function tickServer(e: any, srv: any, seconds: number)
	for _ = 1, seconds do
		e.t += 1
		srv.service:step()
	end
end
local function player(uid: number): any
	return { UserId = uid, Name = "P" .. uid }
end

case("service: a joining player is loaded, answers hello with their state, and nothing is sent before they speak", function()
	local e = newEnv()
	local first = newSession(e, 40, "OLD")
	first:load()
	first:setProgress(prog({ "bold_jumper", "venom" }, { eye = 9, finished = true, appearance = "maratus_volans_male", settings = { LargeText = true } }))
	local rest = realRest(120, "main")
	first:setRest("main", rest)
	run(e, first, 20)
	first:flush()
	local srv = newServer(e)
	local p = player(40)
	srv.service:addPlayer(p)
	check(srv.sent[p] == nil, "no hello yet: nothing sent")
	srv.service:onMessage(p, { kind = "hello", v = 1 })
	local m = srv.last(p, "loaded")
	check(m ~= nil and m.status == "saved" and m.reason == nil, "loaded, saved")
	check(m ~= nil and canon(m.progress.notebook.opened) == canon({ "bold_jumper", "venom" }) and m.progress.finished_main == true and m.progress.appearance == "maratus_volans_male", "with the notebook, the adult and the choice")
	check(m ~= nil and canon(m.rests.main) == canon(rest) and m.rests.free == nil, "and the main rest, no free one")
	check(srv.service:statusOf(p) == "saved", "statusOf")
	srv.service:onMessage(p, { kind = "hello", v = 1 })
	check(srv.count(p, "loaded") == 2, "a repeated hello is answered again (within its small allowance)")
end)

case("service: hello before the load finishes is answered when it does; a store that is down answers session-only, and the late load follows", function()
	local e = newEnv()
	local seed = newSession(e, 41, "OLD")
	seed:load()
	seed:setProgress(prog({ "p1" }, { eye = 3 }))
	run(e, seed, 3)
	seed:flush()
	local srv = newServer(e)
	srv.deferSpawn = true
	local p = player(41)
	srv.service:addPlayer(p)
	srv.service:onMessage(p, { kind = "hello", v = 1 })
	check(srv.sent[p] == nil, "the load has not run: nothing yet")
	e.backend:fail({ op = "any", times = 3, message = "503: the service is unavailable" })
	srv.drain()
	local m = srv.last(p, "loaded")
	check(m ~= nil and m.status == "session" and m.reason == "load_failed", "answered once the load failed: session-only, load_failed")
	srv.deferSpawn = false
	srv.service:onMessage(p, { kind = "progress", progress = prog({ "p1", "p2" }, { eye = 4 }) })
	tickServer(e, srv, 80)
	local late = srv.last(p, "loaded")
	check(srv.count(p, "loaded") >= 2 and late.status ~= "session", "the retry succeeded and the client was sent the state again")
	check(canon(late.progress.notebook.opened) == canon({ "p1", "p2" }), "merged with what this visit found")
	tickServer(e, srv, 40)
	check(canon(storedOf(e, "P_41", nil).payload.notebook.opened) == canon({ "p1", "p2" }), "and it is stored")
end)

case("service: progress and rest messages are stored (debounced), status changes are sent, leaving flushes and releases", function()
	local e = newEnv()
	local srv = newServer(e)
	local p = player(42)
	srv.service:addPlayer(p)
	srv.service:onMessage(p, { kind = "hello", v = 1 })
	srv.service:onMessage(p, { kind = "progress", progress = prog({ "bold_jumper" }, { appearance = "maratus_volans_male" }) })
	local rest = realRest(120, "main")
	srv.service:onMessage(p, { kind = "rest", mode = "main", record = rest })
	check(srv.service:statusOf(p) == "saving", "saving")
	tickServer(e, srv, 25)
	check(srv.service:statusOf(p) == "saved", "saved")
	check(storedOf(e, "P_42", nil).payload.appearance == "maratus_volans_male" and canon(storedOf(e, "R_42_main", SaveRest.SPECS.main).payload) == canon(rest), "both stored")
	check(srv.count(p, "status") >= 2 and srv.last(p, "status").status == "saved", "the client was told: saving, then saved")
	srv.service:onMessage(p, { kind = "progress", progress = prog({ "bold_jumper", "dragline" }) })
	srv.service:removePlayer(p)
	local o = storedOf(e, "P_42", nil)
	check(#o.payload.notebook.opened == 2 and o.lock == nil, "leaving wrote the last event and released the lock")
	srv.service:onMessage(p, { kind = "progress", progress = prog({ "x" }) })
	check(#storedOf(e, "P_42", nil).payload.notebook.opened == 2, "messages after leaving are ignored")
	-- a new server picks it up at once
	local srv2 = newServer(e, { jobId = "JOB2" })
	local p2 = player(42)
	srv2.service:addPlayer(p2)
	srv2.service:onMessage(p2, { kind = "hello", v = 1 })
	check(srv2.last(p2, "loaded").status == "saved" and #srv2.last(p2, "loaded").progress.notebook.opened == 2, "the next server has it, no waiting for the lock")
end)

case("service: nothing a client sends can raise, be stored unchecked, or exceed its allowance", function()
	local e = newEnv()
	local srv = newServer(e)
	local p = player(43)
	srv.service:addPlayer(p)
	srv.service:onMessage(p, { kind = "hello", v = 1 })
	local before = canon(e.backend.data["P_43"].payload)
	local cyc: any = {}
	cyc.me = cyc
	local rest = realRest(120, "main")
	local forgedRest = Json.copy(rest)
	forgedRest.player.position = { 5000, 0, 0 }
	local junk: { any } = {
		"hello", 42, true, nil, {}, { kind = 5 }, { kind = "teleport" }, { kind = "progress" }, { kind = "progress", progress = "all of it" },
		{ kind = "progress", progress = cyc }, { kind = "progress", progress = { notebook = { opened = { "../../etc" }, eye_seconds = 1 }, finished_main = false } },
		{ kind = "progress", progress = { notebook = { opened = {}, eye_seconds = math.huge }, finished_main = false } },
		{ kind = "progress", progress = { notebook = { opened = {}, eye_seconds = 0 }, finished_main = "yes" } },
		{ kind = "progress", progress = { notebook = { opened = string.rep("x", 5000), eye_seconds = 0 }, finished_main = false } },
		{ kind = "rest" }, { kind = "rest", mode = "main" }, { kind = "rest", mode = 5, record = rest }, { kind = "rest", mode = "daily", record = rest },
		{ kind = "rest", mode = "free", record = rest }, { kind = "rest", mode = "main", record = forgedRest }, { kind = "rest", mode = "main", record = cyc },
		{ kind = "rest", mode = "main", record = function() end }, { kind = "rest", mode = "main", record = { player = {} } },
	}
	local raised = 0
	for i = 1, 24 do
		e.t += 5 -- inside the allowance
		local ok = pcall(srv.service.onMessage, srv.service, p, junk[i])
		if not ok then raised += 1 end
	end
	check(raised == 0, "no message raised")
	tickServer(e, srv, 60)
	check(canon(e.backend.data["P_43"].payload) == before, "no progress changed")
	check(e.backend.data["R_43_main"] == nil and e.backend.data["R_43_free"] == nil, "no rest was stored")
	check(srv.service.stats.dropped >= 18, `the refusals are counted ({srv.service.stats.dropped})`)
	-- the allowance: a flood is cut to the burst
	local srv2 = newServer(e)
	local p2 = player(44)
	srv2.service:addPlayer(p2)
	srv2.service:onMessage(p2, { kind = "hello", v = 1 })
	for i = 1, 200 do srv2.service:onMessage(p2, { kind = "progress", progress = prog({ "page" .. i }) }) end
	check(srv2.service.stats.limited >= 200 - SaveRules.PROGRESS_BURST - 1, `a flood of 200 is cut ({srv2.service.stats.limited} limited)`)
	local entry = srv2.service.entries[p2]
	check(#entry.session.progress.notebook.opened <= SaveRules.PROGRESS_BURST + 1, "only the burst got through")
	for i = 1, 10 do srv2.service:onMessage(p2, { kind = "rest", mode = "main", record = rest }) end
	check(srv2.service.stats.limited >= 200 - SaveRules.PROGRESS_BURST - 1 + 10 - SaveRules.REST_BURST - 1, "and a flood of rests")
	-- before addPlayer and after removePlayer
	local stranger = player(45)
	srv2.service:onMessage(stranger, { kind = "progress", progress = prog({ "x" }) })
	check(e.backend.data["P_45"] == nil, "a player with no session cannot store anything")
end)

case("service: the player leaves while the load is still in flight: the thread that loads lets go of the lock", function()
	local e = newEnv()
	local srv = newServer(e)
	srv.deferSpawn = true
	local p = player(46)
	srv.service:addPlayer(p)
	srv.service:removePlayer(p)
	srv.drain()
	local d = e.backend.data["P_46"]
	check(d == nil or d.lock == nil, "no lock left behind")
	local again = newSession(e, 46, "AGAIN")
	check(again:load() == "active", "and a rejoin is not kept waiting")
end)

case("service: shutdown writes everyone's waiting changes at once, inside the deadline, even through a few failures", function()
	local e = newEnv()
	local srv = newServer(e)
	local ps = { player(50), player(51), player(52) }
	for _, p in ps do
		srv.service:addPlayer(p)
		srv.service:onMessage(p, { kind = "hello", v = 1 })
		srv.service:onMessage(p, { kind = "progress", progress = prog({ "mine" .. p.UserId }, { eye = p.UserId }) })
	end
	srv.service:onMessage(ps[1], { kind = "rest", mode = "main", record = realRest(120, "main") })
	e.backend:fail({ op = "update", times = 3, message = "504: timed out" })
	local t0 = e.t
	srv.service:shutdown()
	for _, p in ps do
		local o = storedOf(e, "P_" .. p.UserId, nil)
		check(o.status == "ok" and o.payload.notebook.opened[1] == "mine" .. p.UserId and o.lock == nil, `{p.UserId}: written and released`)
	end
	check(storedOf(e, "R_50_main", SaveRest.SPECS.main).status == "ok", "and the rest")
	check(e.t - t0 <= SaveRules.FLUSH_DEADLINE, `inside the deadline ({e.t - t0} s)`)
end)

case("service: the real DataStore backend, against a fake DataStore, behaves as the in-memory one: update, cancel, errors, and a whole visit", function()
	local ds: any = { data = {} :: { [string]: any }, err = nil :: string?, calls = 0 }
	function ds.GetAsync(self: any, key: string): any
		self.calls += 1
		if self.err then error(self.err) end
		return Json.copy(self.data[key])
	end
	function ds.UpdateAsync(self: any, key: string, fn: (any) -> any): (any, any)
		self.calls += 1
		if self.err then error(self.err) end
		local new = fn(Json.copy(self.data[key]))
		if new == nil then return nil, nil end
		self.data[key] = Json.copy(new)
		return Json.copy(new), {}
	end
	local b = DataStoreBackend.new(ds)
	local ok, v = b:read("k")
	check(ok and v == nil, "a missing key reads as nil")
	local ok2, v2 = b:update("k", function(old: any): any return { n = (old and old.n or 0) + 1 } end)
	check(ok2 and v2.n == 1 and ds.data.k.n == 1, "update writes")
	local ok3, v3 = b:update("k", function(_old: any): any return nil end)
	check(ok3 and v3 == nil and ds.data.k.n == 1, "returning nil cancels")
	ds.err = "304: UpdateAsync over limit"
	local ok4, _, err4 = b:update("k", function(_old: any): any return { n = 9 } end)
	check(not ok4 and string.find(err4 :: string, "304", 1, true) ~= nil and ds.data.k.n == 1, "an error is reported, not raised, and nothing changed")
	local ok5, _, err5 = b:read("k")
	check(not ok5 and err5 ~= nil, "a read error too")
	ds.err = nil
	local e = newEnv()
	e.backend = b
	local s = SaveSession.new({ backend = b, userId = 60, sessionId = "S", now = e.now, sleep = e.sleep })
	check(s:load() == "active", "a session loads through it")
	s:setProgress(prog({ "p1" }))
	s:setRest("main", realRest(120, "main"))
	for _ = 1, 30 do e.t += 1; s:step() end
	s:flush()
	check(SaveEnvelope.open(SaveProgress.SPEC, ds.data["P_60"]).payload.notebook.opened[1] == "p1" and ds.data["P_60"].lock == nil, "progress stored through the DataStore interface, lock released")
	check(SaveEnvelope.open(SaveRest.SPECS.main, ds.data["R_60_main"]).status == "ok", "and the rest")
end)

case("the Studio fixture still matches the checkpoint format (regenerate tests/studio/StateFixture.luau if this fails)", function()
	local Fixture = require("./studio/StateFixture")
	for _, key in { "main", "free" } do
		local text = Fixture[key]
		check(string.find(text, `"schema_version":{Checkpoint.SCHEMA_VERSION},`, 1, true) ~= nil, `{key}: the checkpoint schema is {Checkpoint.SCHEMA_VERSION}`)
		check(string.find(text, `"content_revision":"{Checkpoint.CONTENT_REVISION}"`, 1, true) ~= nil, `{key}: the content revision is {Checkpoint.CONTENT_REVISION}`)
		check(string.find(text, '"life_rules":{"mode":"' .. key .. '"', 1, true) ~= nil, `{key}: the rules are {key}'s`)
	end
end)

case("service: the key a player is filed under can be chosen (the test place files each run apart)", function()
	local e = newEnv()
	local srv = newServer(e)
	srv.service.cfg.keyOf = function(p: any): string return "tRUN_" .. p.UserId end
	local p = player(70)
	srv.service:addPlayer(p)
	srv.service:onMessage(p, { kind = "hello", v = 1 })
	srv.service:onMessage(p, { kind = "progress", progress = prog({ "x" }) })
	tickServer(e, srv, 5)
	check(e.backend.data["P_tRUN_70"] ~= nil and e.backend.data["P_70"] == nil, "filed under the chosen name")
	srv.service:removePlayer(p)
end)


case("a page earned while UpdateAsync yields survives its reply", function()
	local e = newEnv()
	local a = newSession(e, 81, "A")
	a:load()
	a:setProgress(prog({ "first" }))
	local update = e.backend.update
	local once = false
	e.backend.update = function(self: any, key: string, transform: any): (boolean, any, string?)
		local ok, value, err = update(self, key, transform)
		if key == "P_81" and not once then
			once = true
			e.t += 1
			a:setProgress(prog({ "first", "during_write" }))
		end
		return ok, value, err
	end
	run(e, a, 40)
	check(table.find(a.progress.notebook.opened, "during_write") ~= nil, "in-memory progress retains the new page")
	check(table.find(storedOf(e, "P_81", nil).payload.notebook.opened, "during_write") ~= nil, "the next write stores it")
end)

case("leaving holds the lock until both rest writes have finished", function()
	local e = newEnv()
	local a = newSession(e, 82, "A")
	a:load()
	a:setRest("main", realRest(120, "main"))
	local update = e.backend.update
	local observed = false
	e.backend.update = function(self: any, key: string, transform: any): (boolean, any, string?)
		if key == "R_82_main" then
			observed = true
			local b = newSession(e, 82, "B")
			check(b:load() == "session" and b.reason == "other_session", "rejoining cannot read an unfinished departing visit")
		end
		return update(self, key, transform)
	end
	a:flush()
	check(observed and storedOf(e, "P_82", nil).lock == nil, "lock is released after the rest completes")
end)

case("a failed rest load never permits a leave-time overwrite", function()
	local e = newEnv()
	local original = SaveEnvelope.make(SaveRest.SPECS.main, realRest(400, "main"), e.t, nil, { session = "OLD" })
	e.backend:poke("R_83_main", original)
	e.backend:fail({ op = "read", key = "R_83_main", times = 100, message = "503: down" })
	local a = newSession(e, 83, "A")
	a:load()
	a:setRest("main", realRest(120, "main"))
	a:flush()
	check(canon(e.backend.data.R_83_main) == canon(original), "unread stored rest remains byte-for-byte intact")
end)

case("damaged rests stay intact, including damage discovered on a retry or write", function()
	for _, when in { "load", "retry", "write" } do
		local e = newEnv()
		local a = newSession(e, 84, "A")
		local damaged = SaveEnvelope.make(SaveRest.SPECS.main, realRest(120, "main"), e.t, nil, { session = "OLD" })
		damaged.checksum = "damaged"
		if when ~= "write" then e.backend:poke("R_84_main", damaged) end
		if when == "retry" then e.backend:fail({ op = "read", key = "R_84_main", times = 1, message = "503: down" }) end
		a:load()
		if when == "write" then e.backend:poke("R_84_main", damaged) end
		a:setRest("main", realRest(200, "main"))
		run(e, a, 20)
		a:flush()
		check(canon(e.backend.data.R_84_main) == canon(damaged), when .. ": damaged record preserved")
		check(a.restProtected.main == "corrupt" and select(2,a:status()) == "rest_protected", when .. ": partial saving is explained")
	end
end)

case("failed rest reads do not starve a live session's heartbeat", function()
	local e = newEnv()
	local a = newSession(e, 85, "A")
	e.backend:fail({ op = "read", key = "R_85_main", times = 1000, message = "503: down" })
	a:load()
	run(e, a, SaveRules.LOCK_STALE + 40)
	local b = newSession(e, 85, "B")
	check(b:load() == "session" and b.reason == "other_session", "repeated read failures retain the live lock")
end)

case("flush deadline never overlaps an existing write", function()
	local e = newEnv()
	local a = newSession(e, 86, "A")
	a:load()
	a:setProgress(prog({ "pending" }))
	a.busy = true
	local before = e.backend.writes
	a:flush(e.t + 1)
	check(e.backend.writes == before, "no concurrent second write is started after the wait expires")
end)

case("a permanent write rejection never reports Saved", function()
	for _, key in { "P_87", "R_87_main" } do
		local e = newEnv()
		local a = newSession(e, 87, "A")
		a:load()
		a:setProgress(prog({ "unsaved" }))
		a:setRest("main", realRest(120, "main"))
		e.backend:fail({ op = "update", key = key, times = 1, message = "105: value too large" })
		run(e, a, 5)
		local st, why = a:status()
		check(st == "session" and why == "write_failed", key .. ": explicitly session-only")
	end
end)

case("shutdown waits for a PlayerRemoving flush already in flight", function()
	local e = newEnv()
	local srv = newServer(e)
	local p = player(88)
	srv.service:addPlayer(p)
	local entry = srv.service.entries[p]
	local flushed = false
	entry.session.flush = function()
		coroutine.yield()
		flushed = true
	end
	local leaving = coroutine.create(function() srv.service:removePlayer(p) end)
	check(coroutine.resume(leaving) and not flushed, "departing flush is suspended after removal")
	local waited = false
	srv.service.cfg.sleep = function(seconds: number)
		waited = true
		e.t += seconds
		assert(coroutine.resume(leaving))
	end
	srv.service:shutdown()
	check(waited and flushed and srv.service.departing == 0, "shutdown awaits and completes the departing write")
end)

case("future settings versions never get silently downgraded", function()
	local e = newEnv()
	local future = SaveProgress.default()
	future.settings_version = SettingsModel.VERSION + 1
	future.settings.FutureChoice = "keep_me"
	local raw = SaveEnvelope.make(SaveProgress.SPEC, future, e.t, nil, nil)
	e.backend:poke("P_89", raw)
	local before = canon(raw)
	local a = newSession(e, 89, "A")
	check(a:load() == "session", "unsupported settings make this visit read-only")
	a:setProgress(prog({ "new_page" }))
	run(e, a, 40)
	a:flush()
	check(canon(e.backend.data.P_89) == before, "future settings and their version remain byte-for-byte intact")
end)

-- ---------------------------------------------------------------------------------------------- the audit, part one (ROBLOX-91)
case("the Easy slot: the main life on the gentle rules has its own rest, so beginning Easy cannot wipe the standard rest", function()
	check(SaveRules.slotOf("main", "standard") == "main" and SaveRules.slotOf("main", "gentle") == "easy" and SaveRules.slotOf("free", "gentle") == "free", "the slot of each life: standard main keeps its key")
	check(table.concat(SaveRules.MODES, ",") == "main,free,easy", "the slots, the old two first")
	local std = realRest(120, "main")
	local easy = realRest(120, "easy")
	local free = realRest(120, "free")
	check(easy.life_rules.mode == "main" and easy.life_rules.rules == "gentle", "(an Easy rest is a main life on the gentle rules)")
	check(#SaveRest.check("easy", easy) == 0, "an Easy rest passes as the easy slot's: " .. table.concat(SaveRest.check("easy", easy), "; "))
	check(#SaveRest.check("easy", std) > 0 and #SaveRest.check("easy", free) > 0, "a standard rest and a free one are not the easy slot's")
	check(#SaveRest.check("free", easy) > 0, "an Easy rest is not a free one")
	check(#SaveRest.check("main", std) == 0 and #SaveRest.check("free", free) == 0, "the standard slot and the free one are as they were")
	check(#SaveRest.check("main", easy) == 0, "(an Easy rest saved before the slot existed was filed as main: it is still accepted there)")
	check(SaveRest.SPECS.easy ~= nil and SaveRest.SPECS.easy.kind == "rest_easy" and #SaveRest.check("weekly", easy) > 0, "its own envelope kind; other names are refused")
	-- stored apart, under the keys
	local e = newEnv()
	local a = newSession(e, 91, "A")
	a:load()
	check(a:setRest("main", std) and a:setRest("easy", easy) and a:setRest("free", free), "all three are accepted")
	check(not a:setRest("easy", std) and not a:setRest("free", easy), "and the wrong slot refuses")
	check(select(2, a:status()) == "rest_refused", "wrong-slot rests are reported, not silently dropped")
	check(a:setRest("easy", easy) and a:setRest("free", free), "each refused slot recovers after a valid replacement")
	run(e, a, 40)
	check(storedOf(e, "R_91_main", SaveRest.SPECS.main).status == "ok" and storedOf(e, "R_91_easy", SaveRest.SPECS.easy).status == "ok" and storedOf(e, "R_91_free", SaveRest.SPECS.free).status == "ok", "three values, apart")
	check(canon(storedOf(e, "R_91_main", SaveRest.SPECS.main).payload) == canon(std), "the standard rest is as it was sent")
	-- an Easy rest sent later does not touch the standard one
	local easy2 = realRest(240, "easy")
	a:setRest("easy", easy2)
	run(e, a, 25)
	check(canon(storedOf(e, "R_91_main", SaveRest.SPECS.main).payload) == canon(std), "a later Easy rest leaves the standard rest alone")
	check(canon(storedOf(e, "R_91_easy", SaveRest.SPECS.easy).payload) == canon(easy2), "and replaces the Easy one")
	check(select(1, a:status()) == "saved", "saved")
	a:flush()
	local b = newSession(e, 91, "B")
	b:load()
	check(canon(b.rests.main) == canon(std) and canon(b.rests.easy) == canon(easy2) and canon(b.rests.free) == canon(free), "a rejoin gets all three back")
	local snap = b:snapshot()
	check(snap.rests.main ~= nil and snap.rests.easy ~= nil and snap.rests.free ~= nil, "and the snapshot for the client has them")
	-- an old player (two rests, no Easy): the missing slot reads as nothing, and everything else is as it was
	local e2 = newEnv()
	local old = newSession(e2, 92, "OLD")
	old:load()
	old:setRest("main", std)
	run(e2, old, 25)
	old:flush()
	local back = newSession(e2, 92, "NEW")
	check(back:load() == "active" and canon(back.rests.main) == canon(std) and back.rests.easy == nil and back.rests.free == nil, "a save with no Easy slot loads, and the standard rest is where it was")
	check(select(1, back:status()) == "saved", "(and is saved)")
end)

case("shutdown with a player still loading: the departing count never goes negative, and the load's flush is awaited", function()
	-- shutdown marks every entry as leaving; the entry whose load had not finished was uncounted by its loading thread without ever having been counted
	local e = newEnv()
	local srv = newServer(e)
	srv.deferSpawn = true
	local p = player(93)
	srv.service:addPlayer(p)
	local entry = srv.service.entries[p]
	check(entry ~= nil and not entry.loaded, "the load has not run yet")
	local lowest = 0
	srv.service.cfg.sleep = function(seconds: number)
		e.t += seconds
		srv.drain()
		lowest = math.min(lowest, srv.service.departing)
	end
	srv.service:shutdown()
	lowest = math.min(lowest, srv.service.departing)
	check(entry.loaded and entry.session.closed == true, "the load finished and its session was flushed and closed")
	check(srv.service.departing == 0 and lowest >= 0, `the count ends at 0 and was never below it (lowest {lowest})`)
	-- a player who leaves while loading, then the shutdown: counted once, uncounted once
	local e2 = newEnv()
	local srv2 = newServer(e2)
	srv2.deferSpawn = true
	local q = player(94)
	srv2.service:addPlayer(q)
	local entry2 = srv2.service.entries[q]
	srv2.service:removePlayer(q)
	check(srv2.service.departing == 1 and srv2.service.entries[q] == nil, "leaving while loading counts one departure")
	srv2.service.cfg.sleep = function(seconds: number) e2.t += seconds; srv2.drain() end
	srv2.service:shutdown()
	check(srv2.service.departing == 0 and entry2.session.closed == true, "and the shutdown awaits it: one in, one out")
	-- two players loading, one leaves: still balanced
	local e3 = newEnv()
	local srv3 = newServer(e3)
	srv3.deferSpawn = true
	local r1, r2 = player(95), player(96)
	srv3.service:addPlayer(r1)
	srv3.service:addPlayer(r2)
	srv3.service:removePlayer(r1)
	srv3.service.cfg.sleep = function(seconds: number) e3.t += seconds; srv3.drain() end
	srv3.service:shutdown()
	check(srv3.service.departing == 0, "a mix of a leaver and a shutdown: balanced")
	-- a loaded player: unchanged (the count stays zero)
	local e4 = newEnv()
	local srv4 = newServer(e4)
	local t = player(97)
	srv4.service:addPlayer(t)
	srv4.service:shutdown()
	check(srv4.service.departing == 0, "a loaded player: unchanged")
end)

case("audit: rejected rests reach the client and cannot erase the earlier stored rest", function()
	local e = newEnv()
	local srv = newServer(e)
	local p = player(701)
	srv.service:addPlayer(p)
	srv.service:onMessage(p, { kind = "hello", v = 1 })
	local rest = realRest(120, "main")
	srv.service:onMessage(p, { kind = "rest", mode = "main", record = rest })
	tickServer(e, srv, 15)
	local earlier = canon(e.backend.data["R_701_main"])
	check(earlier ~= "null", "the first rest reached the backend")
	local fat = Json.copy(rest)
	fat.player.extra = string.rep("x", SaveRules.MAX_REST_CHARS)
	srv.service:onMessage(p, { kind = "rest", mode = "main", record = fat })
	local status = srv.last(p, "status")
	check(status ~= nil and status.status == "saving" and status.reason == "rest_refused", "rejection is sent through the real service callback")
	tickServer(e, srv, 40)
	check(canon(e.backend.data["R_701_main"]) == earlier, "earlier online rest remains byte-identical")
	check(srv.service:statusOf(p) == "saving", "heartbeat does not turn a rejected rest into Saved")
	srv.service:onMessage(p, { kind = "rest", mode = "main", record = rest })
	tickServer(e, srv, 15)
	check(srv.service:statusOf(p) == "saved", "a later accepted rest can recover online saving")
end)


case("retirement records preserve old checkpoints and reject old readers",function()
 local rec=realRest(120,"main")
 local spec=SaveRest.SPECS.main
 local marker={save_retired=true,save_life="session:main:1"}
 local tombstone=SaveEnvelope.make(spec,marker,100,SaveEnvelope.make(spec,rec,90,nil))
 check(SaveEnvelope.open(spec,tombstone).status=="ok","retirement is a valid schema-2 value")
 local old={kind=spec.kind,current=1,migrations={},validate=spec.validate}
 check(SaveEnvelope.open(old,tombstone).status=="newer","old reader refuses retirement before parsing it")
 check(canon(SaveEnvelope.open(spec,tombstone.backup and {format=tombstone.format,kind=tombstone.kind,schema=tombstone.backup.schema,updatedAt=tombstone.backup.updatedAt,payload=tombstone.backup.payload,checksum=tombstone.backup.checksum}).payload)==canon(rec),"previous life retained as recoverable backup")
 local bad=SaveEnvelope.make(spec,{save_retired=true,save_life="a",extra=true},100,nil)
 check(SaveEnvelope.open(spec,bad).status=="invalid","unknown retirement fields refused")
 local legacy=SaveEnvelope.make(old,rec,90,nil)
 check(SaveEnvelope.open(spec,legacy).status=="migrated" and canon(SaveEnvelope.open(spec,legacy).payload)==canon(rec),"schema-1 checkpoint migrates without changing state")
end)
case("New Life retires durably before acknowledgement, binds later rests, and survives quit",function()
 local e=newEnv();local acknowledgements={}
 local a=newSession(e,901,"A",{onLife=function(mode,serial,token)
  table.insert(acknowledgements,{mode,serial,token})
  check(e.backend.data["R_901_main"].payload.save_life==token,"ack follows actual durable write")
 end})
 a:load();local old=realRest(120,"main");a:setRest("main",old);run(e,a,15)
 local oldBytes=canon(e.backend.data["R_901_main"].payload)
 check(a:beginLife("main",1),"New Life intent accepted")
 check(#acknowledgements==0 and a:snapshot().rests.main==nil,"not acknowledged before write; old rest not offered")
 check(not a:setRest("main",old) and not a:setRestForLife("main",old,"wrong"),"prior life cannot enqueue another rest")
 a:flush()
 check(#acknowledgements==1,"retirement acknowledged once committed")
 local value=e.backend.data["R_901_main"]
 check(value.payload.save_retired==true and canon(value.backup.payload)==oldBytes,"marker kept instead of deleting the prior rest")
 e.t+=40;local b=newSession(e,901,"B");b:load()
 check(b:snapshot().rests.main==nil,"quitting before the first new rest cannot revive old life")
 local token=b:snapshot().lives.main
 check(token==acknowledgements[1][3],"life identity persists across sessions")
 check(not b:setRestForLife("main",old,"A:old") and not b:setRest("main",old),"late old records rejected after rejoin")
 check(b:setRestForLife("main",old,token),"same-life resumed record can be kept")
 b:flush()
 check(e.backend.data["R_901_main"].payload.save_life==token and not e.backend.data["R_901_main"].payload.save_retired,"new rest replaces retirement marker with same identity")
end)
case("New Life retry after a lost write response is idempotent",function()
 local e=newEnv();local ack={};local a=newSession(e,902,"A",{onLife=function(_,serial) table.insert(ack,serial) end})
 a:load();a:setRest("main",realRest(120,"main"));run(e,a,15)
 local update=e.backend.update;local lose=true
 e.backend.update=function(self,key,fn)
  local ok,value,err=update(self,key,fn)
  if key=="R_902_main" and lose then lose=false;return false,nil,"lost response" end
  return ok,value,err
 end
 a:beginLife("main",1);run(e,a,1)
 check(#ack==0 and a.lifeRequests.main.done==false,"ambiguous response never acknowledges retirement")
 local backup=canon(e.backend.data["R_902_main"].backup)
 run(e,a,20)
 check(#ack==1 and a.lifeRequests.main.done,"retry confirms durable marker")
 check(canon(e.backend.data["R_902_main"].backup)==backup,"retry never replaces old-life backup with a duplicate marker")
 check(a:beginLife("main",1) and #ack==2,"duplicate request resends acknowledgement")
 check(not a:beginLife("main",0) and not a:beginLife("main",0/0) and not a:beginLife("unknown",2),"invalid intents refused")
end)
case("a newer New Life choice supersedes an in-flight older acknowledgement",function()
 local e=newEnv();local ack={};local a=newSession(e,903,"A",{onLife=function(_,serial) table.insert(ack,serial) end})
 a:load();a:setRest("main",realRest(120,"main"));run(e,a,15)
 local update=e.backend.update;local replace=true
 e.backend.update=function(self,key,fn)
  local ok,value,err=update(self,key,fn)
  if key=="R_903_main" and replace then replace=false;a:beginLife("main",2) end
  return ok,value,err
 end
 a:beginLife("main",1);run(e,a,1)
 check(#ack==0 and a.lifeRequests.main.serial==2,"late response does not acknowledge superseded life")
 check(a:snapshot().rests.main==nil,"no transient prior rest exposed")
 run(e,a,20)
 check(#ack==1 and ack[1]==2,"only latest intent acknowledged")
 check(not a:beginLife("main",1),"reordered old intent refused")
end)
case("retirement obeys foreign locks and preserves damaged records",function()
 local e=newEnv();local a=newSession(e,904,"A");a:load();a:setRest("main",realRest(120,"main"));run(e,a,15)
 local b=newSession(e,904,"B");b:load();b:beginLife("main",1);local before=canon(e.backend.data["R_904_main"])
 run(e,b,20);check(canon(e.backend.data["R_904_main"])==before and not b.lifeRequests.main.done,"foreign lease cannot retire another session's life")
 e.backend.data["R_904_main"].checksum="broken";before=canon(e.backend.data["R_904_main"])
 a:beginLife("main",1);run(e,a,20)
 check(canon(e.backend.data["R_904_main"])==before and a.state=="active" and a.restProtected.main=="corrupt" and not a.lifeRequests.main.done,"damaged record never replaced by a retirement marker")
end)

case("rest messages cannot forge retirement and foreign epochs cannot race equal timestamps",function()
 local e=newEnv();local a=newSession(e,905,"A");a:load();local rec=realRest(120,"main")
 local forged=Json.copy(rec);forged.save_retired=true;forged.save_life="A:forged"
 check(not a:setRest("main",forged),"checkpoint-shaped client payload cannot create retirement marker")
 a:beginLife("main",1);run(e,a,15)
 local token=a.lifeTokens.main;local old=e.backend.data["R_905_main"]
 local foreign=SaveEnvelope.make(SaveRest.SPECS.main,{save_retired=true,save_life="B:main:1"},old.updatedAt,old,{session="B"})
 e.backend.data["R_905_main"]=foreign;local before=canon(foreign)
 check(a:setRestForLife("main",rec,token),"old session can queue before discovering new owner")
 run(e,a,20)
 check(canon(e.backend.data["R_905_main"])==before and a.reason=="other_session","foreign life identity prevents overwrite even with equal timestamps")
end)

case("retiring one slot preserves the other two byte for byte",function()
 local e=newEnv();local a=newSession(e,906,"A");a:load()
 for _,mode in {"main","free","easy"} do check(a:setRest(mode,realRest(120,mode)),"seed "..mode) end
 run(e,a,20)
 local free,easy=canon(e.backend.data["R_906_free"]),canon(e.backend.data["R_906_easy"])
 a:beginLife("main",1);run(e,a,20)
 check(canon(e.backend.data["R_906_free"])==free and canon(e.backend.data["R_906_easy"])==easy,"other slots untouched")
 check(a:snapshot().rests.main==nil and a:snapshot().rests.free~=nil and a:snapshot().rests.easy~=nil,"only retired Continue is hidden")
end)
case("real SaveClient and SaveService carry durable intent and same-life rest end to end",function()
 local e=newEnv();local srv=newServer(e);local p=player(907);srv.service:addPlayer(p)
 local deliver
 local remotes={server={FireServer=function(_,msg) srv.service:onMessage(p,msg) end},client={OnClientEvent={Connect=function(_,fn) deliver=fn end}}}
 local send=srv.service.cfg.send
 srv.service.cfg.send=function(who,msg) send(who,msg);if who==p and deliver then deliver(msg) end end
 local client=SaveClient.new({rules=SaveRules,now=e.now,findRemotes=function() return remotes end,
  onLoaded=function() end,onRest=function() end,onStatus=function() end,build=SaveProgress.default})
 client:update();check(client:connected(),"real hello/load exchange completed")
 local rec=realRest(120,"main")
 client:beginLife("main");client:sendRest("main",rec);client:update()
 check(srv.last(p,"life")==nil and e.backend.data["R_907_main"]==nil,"no early acknowledgement or premature rest")
 tickServer(e,srv,2)
 local ack=srv.last(p,"life");check(ack and client.lifeRequests.main.done and e.backend.data["R_907_main"].payload.save_retired,"actual stored marker acknowledges client intent")
 client:update();tickServer(e,srv,15)
 check(e.backend.data["R_907_main"].payload.save_life==ack.token and not e.backend.data["R_907_main"].payload.save_retired,"queued rest crosses real service boundary only in new life")
 local before=canon(e.backend.data["R_907_main"])
 srv.service:onMessage(p,{kind="rest",mode="main",record=rec,life="wrong"});tickServer(e,srv,15)
 check(canon(e.backend.data["R_907_main"])==before,"late foreign-life message never changes stored rest")
 srv.service:removePlayer(p);e.t+=40
 local rejoined=newSession(e,907,"rejoin");check(rejoined:load()=="active" and rejoined.lifeTokens.main==ack.token,"life identity survives full service leave/rejoin")
end)

case("identity metadata is included in the admitted checkpoint size",function()
 local e=newEnv();local a=newSession(e,908,"A");a:load();a:beginLife("main",1);run(e,a,2)
 local rec=realRest(120,"main");local cap=SaveRules.MAX_REST_CHARS
 local before=canon(e.backend.data["R_908_main"])
 SaveRules.MAX_REST_CHARS=#canon(rec)
 local ok,why=pcall(function()
  check(#SaveRest.check("main",rec)==0,"raw checkpoint fits exact cap")
  check(not a:setRestForLife("main",rec,a.lifeTokens.main),"stamped checkpoint over cap is refused before queueing")
  local hostile=setmetatable({},{__iter=function() error("must not iterate") end,__index=function() error("must not index") end})
  check(not a:setRestForLife("main",hostile,a.lifeTokens.main),"malformed root cannot execute metatable code during stamping")
 end)
 SaveRules.MAX_REST_CHARS=cap
 check(ok,"size-boundary regression did not raise: "..tostring(why))
 run(e,a,20)
 check(canon(e.backend.data["R_908_main"])==before,"valid earlier retirement remains intact")
end)

case("a native-swallowed encoder failure cannot acknowledge retirement or report Saved", function()
 local e=newEnv();local blocked=true;local acknowledgements=0
 local stored=SaveEnvelope.make(SaveRest.SPECS.main,realRest(120,"main"),e.t-10,nil,nil)
 local ds:any={data={R_native_main=Json.copy(stored)},errors=0}
 function ds:GetAsync(key) return Json.copy(self.data[key]) end
 function ds:UpdateAsync(key,fn)
  local ok,candidate=pcall(fn,Json.copy(self.data[key]))
  if not ok then self.errors+=1;return nil end -- observed native API boundary
  if candidate~=nil then self.data[key]=Json.copy(candidate);return Json.copy(candidate) end
  return nil
 end
 local codec:any={}
 function codec:decode(value) return value end
 function codec:encode(value) if blocked then error("injected encoder refusal",0) end;return value end
 local backend=DataStoreBackend.new(ds,codec)
 local session=SaveSession.new({backend=backend,userId="native",sessionId="native_test",now=e.now,sleep=e.sleep,
  onLife=function() acknowledgements+=1 end})
 check(session:load()=="active","session loads its earlier checkpoint")
 local before=canon(ds.data.R_native_main)
 check(session:beginLife("main",1),"retirement request is accepted")
 session:step()
 check(acknowledgements==0 and not session.lifeRequests.main.done,"failed encoding is not acknowledged")
 check(session.restPending.main~=nil and session.sched.items.rest_main.dirty,"failed retirement remains queued")
 check(session:status()~="saved","failed retirement cannot report Saved")
 check(canon(ds.data.R_native_main)==before,"earlier checkpoint and backup remain untouched")
 check(ds.errors==0,"encoder error did not escape into native callback")
 blocked=false
 for _=1,80 do e.t+=1;session:step();if acknowledgements>0 then break end end
 check(acknowledgements==1 and session.lifeRequests.main.done,"a successful retry acknowledges exactly once")
 local opened=SaveEnvelope.open(SaveRest.SPECS.main,ds.data.R_native_main)
 check(opened.status=="ok" and SaveRest.isRetired(opened.payload) and opened.backup~=nil,"retry stores marker with recoverable prior checkpoint")
end)

case("unreadable rests protect only their own slot, retain backup, and survive a rejoin unchanged", function()
 local records={main=realRest(120,"main"),easy=realRest(120,"easy"),free=realRest(120,"free")}
 for _,mode in SaveRules.MODES do
  for _,damage in {"corrupt","invalid","newer"} do
   local e=newEnv();local key="R_901_"..mode
   local backup=SaveEnvelope.make(SaveRest.SPECS[mode],records[mode],20,nil,{session="OLD"})
   local broken=SaveEnvelope.make(SaveRest.SPECS[mode],records[mode],21,backup,{session="OLD"})
   if damage=="corrupt" then broken.checksum="damaged"
   elseif damage=="newer" then broken.schema=99
   else broken=SaveEnvelope.make(SaveRest.SPECS[mode],{invalid=true},21,backup,{session="OLD"}) end
   e.backend:poke(key,broken);local original=canon(broken)
   local a=newSession(e,901,"A");check(a:load()=="active" and a.lockHeld,"progress ownership retained: "..mode..damage)
   check(a.restProtected[mode]==(if damage=="newer" then "newer" else "corrupt"),"only known unreadable value is protected")
   if damage~="newer" then check(a.rests[mode]~=nil and canon(a.rests[mode])==canon(records[mode]),"readable backup offered in memory without repair") end
   local snap=a:snapshot();snap.protected[mode]="tampered"
   check(a.restProtected[mode]~="tampered","metadata is copied")
   check(not a:setRest(mode,records[mode]) and not a:beginLife(mode,1),"neither rest nor retirement can replace protected value")
   a:setProgress(prog({"p1"}))
   for _,healthy in SaveRules.MODES do if healthy~=mode then check(a:setRest(healthy,records[healthy]),"healthy rest accepted") end end
   run(e,a,160)
   check(a.state=="active" and a.lockHeld,"heartbeats remain live")
   check(select(1,a:status())=="saving" and select(2,a:status())=="rest_protected","no false Saved or global off status")
   check(#storedOf(e,"P_901",nil).payload.notebook.opened==1,"notebook persisted")
   for _,healthy in SaveRules.MODES do if healthy~=mode then check(storedOf(e,"R_901_"..healthy,SaveRest.SPECS[healthy]).status=="ok","healthy slot persisted") end end
   a:flush();check(canon(e.backend.data[key])==original,"damaged envelope and backup byte-equivalent on exit")
   local rejoin=newSession(e,901,"B");rejoin:load()
   check(rejoin.state=="active" and rejoin.restProtected[mode]~=nil and #rejoin.progress.notebook.opened==1,"rejoin preserves notebook and protection")
   check(canon(e.backend.data[key])==original,"rejoin leaves protected storage unchanged")
  end
 end
end)

case("a pending New Life encountering damaged storage gets no acknowledgement while other progress saves",function()
 for _,damage in {"corrupt","newer"} do
  local e=newEnv();local acks=0
  local a=newSession(e,902,"A",{onLife=function() acks+=1 end});a:load()
  check(a:beginLife("main",1),"intent queued before write discovers damage")
  local broken=SaveEnvelope.make(SaveRest.SPECS.main,realRest(120,"main"),20,nil,{session="OLD"})
  if damage=="corrupt" then broken.checksum="damaged" else broken.schema=99 end
  e.backend:poke("R_902_main",broken);local before=canon(broken)
  a:setProgress(prog({"p1"}));run(e,a,30)
  check(a.restProtected.main==damage and acks==0 and not a.lifeRequests.main.done,"no false durable-life acknowledgement")
  check(a.restPending.main==nil and not a.sched.items.rest_main.dirty,"unwritable work is abandoned")
  check(a.lifeRequests.main.serial==1 and not a:beginLife("main",2),"serial retained and subsequent intent refused")
  check(#storedOf(e,"P_902",nil).payload.notebook.opened==1 and a.state=="active","independent progress still written")
  a:flush();check(canon(e.backend.data.R_902_main)==before,"retirement never touches unreadable data")
 end
end)

case("temporary rest read failures retry; protection remains sticky only after actual unreadable data",function()
 local e=newEnv();e.backend:fail({op="read",key="R_903_main",times=1,message="503: down"})
 local a=newSession(e,903,"A");a:load()
 check(a.restProtected.main==nil and not a.restLoaded.main,"API failure is not corruption")
 run(e,a,30);check(a.restLoaded.main and a.restProtected.main==nil,"normal retry recovers")
 local broken={invalid=true};e.backend:poke("R_903_main",broken)
 a:setRest("main",realRest(120,"main"));run(e,a,20)
 check(a.restProtected.main=="corrupt","actual unreadable rest protected")
 e.backend:poke("R_903_main",nil);a:load()
 check(a.restProtected.main=="corrupt" and not a:beginLife("main",1),"reacquisition does not remove visit protection")
 a:flush();local b=newSession(e,903,"B");b:load()
 check(b.restProtected.main==nil and b:beginLife("main",1),"fresh visit reevaluates repaired storage")
end)

case("service transports protected slots and refuses a stale intent without acknowledging it",function()
 local e=newEnv();e.backend:poke("R_904_main",{invalid=true})
 local srv=newServer(e);local p=player(904);srv.service:addPlayer(p)
 srv.service:onMessage(p,{kind="hello",v=SaveRules.PROTOCOL})
 local loaded=srv.last(p,"loaded")
 check(loaded and loaded.protected.main=="corrupt","initial load carries protection")
 srv.service:onMessage(p,{kind="begin_life",mode="main",serial=1})
 local status=srv.last(p,"status")
 check(status and status.protected.main=="corrupt","refused intent resends protection")
 tickServer(e,srv,20)
 check(srv.count(p,"life")==0 and canon(e.backend.data.R_904_main)==canon({invalid=true}),"no ack or replacement")
end)

-- An intent chosen before reading a slot cannot retire a subsequently discovered life.
case("unseen New Life intent survives no foreign save after delayed ownership",function()
 for _,changed in {false,true} do
  local e=newEnv();local uid=if changed then 982 else 981
  local a=newSession(e,uid,"owner");a:load();a:setRest("main",realRest(120,"main"));run(e,a,15)
  local ack=0;local b=newSession(e,uid,"visitor",{onLife=function() ack+=1 end})
  check(b:load()=="session" and not b.restLoaded.main,"visitor has not read the leased slot")
  check(b:beginLife("main",1),"local intent accepted while waiting")
  if changed then
   a:beginLife("main",1);run(e,a,15)
   check(a:setRestForLife("main",realRest(240,"main"),a.lifeTokens.main),"owner starts and saves another life")
  end
  a:flush(e.t+20)
  local before=canon(e.backend.data["R_"..uid.."_main"])
  run(e,b,40)
  check(canon(e.backend.data["R_"..uid.."_main"])==before,"late ownership never retires the unseen stored life")
  check(ack==0 and not b.lifeRequests.main.done,"no durable acknowledgement for refused unseen retirement")
  check(b.state=="session" and b.reason=="other_session" and not b.canRetry,"conflict stays read-only for this visit")
  run(e,b,SaveRules.LOCK_STALE+30)
  check(canon(e.backend.data["R_"..uid.."_main"])==before and ack==0,"later retries never erase the protected life")
 end
end)
case("preload New Life on a genuinely empty slot remains usable",function()
 local e=newEnv();local ack=0;local a=newSession(e,983,"fresh",{onLife=function() ack+=1 end})
 check(a:beginLife("main",1),"fresh intent can precede initial load")
 check(a:load()=="active","missing slot acquires normally")
 run(e,a,15)
 check(ack==1 and a.lifeRequests.main.done,"empty-slot retirement is durably acknowledged")
 check(e.backend.data.R_983_main.payload.save_life==a.lifeTokens.main,"acknowledged identity matches storage")
end)

case("observed New Life cannot retire a different life after lease recovery",function()
 for i,mode in {"main","free","easy"} do
  local e=newEnv();local uid=990+i;local b=newSession(e,uid,"visitor")
  b:load();b:beginLife(mode,1);run(e,b,15)
  check(b:setRestForLife(mode,realRest(120,mode),b.lifeTokens[mode]),mode..": visitor stores an observed life")
  run(e,b,15);local old=b.lifeTokens[mode]
  e.t+=SaveRules.LOCK_STALE+1
  local a=newSession(e,uid,"owner");check(a:load()=="active",mode..": owner takes expired lease")
  a:beginLife(mode,1);run(e,a,15)
  check(a:setRestForLife(mode,realRest(240,mode),a.lifeTokens[mode]) and a.lifeTokens[mode]~=old,mode..": owner saves a different life")
  run(e,a,15);b:beginLife(mode,2);run(e,b,1)
  check(b.state=="session",mode..": visitor discovers lost lease")
  a:flush(e.t+20);local key="R_"..uid.."_"..mode;local before=canon(e.backend.data[key])
  run(e,b,45)
  check(canon(e.backend.data[key])==before,mode..": newer checkpoint and backup remain byte-equivalent")
  check(not b.lifeRequests[mode].done and b.state=="session" and not b.canRetry,mode..": stale intent never acknowledged")
 end
end)
case("nil legacy life tokens still require the observed rest revision",function()
 local e=newEnv();local b=newSession(e,995,"visitor");b:load();b:setRest("main",realRest(120,"main"));run(e,b,15)
 check(b.lifeTokens.main==nil,"legacy rest has no identity token")
 e.t+=SaveRules.LOCK_STALE+1
 local a=newSession(e,995,"owner");a:load();a:setRest("main",realRest(240,"main"));run(e,a,15)
 b:beginLife("main",1);run(e,b,1);a:flush(e.t+20)
 local before=canon(e.backend.data.R_995_main);run(e,b,45)
 check(canon(e.backend.data.R_995_main)==before and not b.lifeRequests.main.done,"revision change protects a legacy rest without a token")
end)
case("unchanged previously observed rest permits explicit retirement after lease recovery",function()
 local e=newEnv();local b=newSession(e,996,"visitor");b:load();b:setRest("main",realRest(120,"main"));run(e,b,15)
 e.t+=SaveRules.LOCK_STALE+1
 local a=newSession(e,996,"owner");a:load()
 b:beginLife("main",1);run(e,b,1);a:flush(e.t+20);run(e,b,45)
 check(b.lifeRequests.main.done and b.state=="active","unchanged observation remains valid")
 check(e.backend.data.R_996_main.payload.save_retired and e.backend.data.R_996_main.payload.save_life==b.lifeTokens.main,"retirement matches durable acknowledgement")
end)
case("preload own retirement survives ambiguous response and reacquisition",function()
 local e=newEnv();local ack=0;local b=newSession(e,997,"visitor",{onLife=function() ack+=1 end})
 b:beginLife("main",1);b:load()
 e.backend:fail({op="update",key="R_997_main",times=1,afterWrite=true,message="lost response"})
 run(e,b,1)
 check(ack==0 and not b.lifeRequests.main.done and e.backend.data.R_997_main.payload.save_retired,"retirement stored but acknowledgement lost")
 local before=canon(e.backend.data.R_997_main)
 e.t+=SaveRules.LOCK_STALE+1
 local a=newSession(e,997,"owner");a:load();a:flush(e.t+20)
 check(b:load()=="active","own ambiguous marker is not a foreign conflict")
 run(e,b,15)
 check(ack==1 and b.lifeRequests.main.done and canon(e.backend.data.R_997_main)==before,"retry acknowledges without duplicating backup or changing marker")
end)

case("equal timestamps and life tokens do not make changed rest contents identical",function()
 local e=newEnv();local b=newSession(e,998,"visitor");b:load();b:setRest("main",realRest(120,"main"));run(e,b,15)
 local observed=e.backend.data.R_998_main
 e.t+=SaveRules.LOCK_STALE+1
 local a=newSession(e,998,"owner");a:load()
 -- A valid foreign envelope can have the same revision time and nil legacy token.
 -- Its intact checksum still distinguishes the changed payload.
 local changed=SaveEnvelope.make(SaveRest.SPECS.main,realRest(240,"main"),observed.updatedAt,observed,{session="owner"})
 check(changed.checksum~=observed.checksum,"fixture differs in contents despite equal timestamp/token")
 e.backend:poke("R_998_main",changed)
 b:beginLife("main",1);run(e,b,1);a:flush(e.t+20)
 local before=canon(e.backend.data.R_998_main);run(e,b,45)
 check(canon(e.backend.data.R_998_main)==before and not b.lifeRequests.main.done,"changed checksum blocks stale consent")
end)
case("write-time revision protects an equal-time foreign update after the slot was read",function()
 local e=newEnv();local a=newSession(e,999,"visitor");a:load();a:setRest("main",realRest(120,"main"));run(e,a,15)
 local observed=e.backend.data.R_999_main
 a:beginLife("main",1)
 local changed=SaveEnvelope.make(SaveRest.SPECS.main,realRest(240,"main"),observed.updatedAt,observed,{session="owner"})
 e.backend:poke("R_999_main",changed);local before=canon(changed)
 run(e,a,20)
 check(canon(e.backend.data.R_999_main)==before and not a.lifeRequests.main.done,"atomic callback refuses the changed observed revision")
end)

-- Appended to the default state suite; uses its real-rest and backend fixtures.
local function releaseQueued(s)
 local item=s.sched.items.release;return item~=nil and item.dirty
end
case("rejected unseen retirement releases its acquired lease without changing any saved life",function()
 for i,mode in SaveRules.MODES do
  local e=newEnv();local uid=1200+i;local owner=newSession(e,uid,"owner")
  owner:load();assert(owner:setRest(mode,realRest(120,mode)));run(e,owner,15)
  local visitor=newSession(e,uid,"visitor")
  check(visitor:load()=="session" and not visitor.restLoaded[mode],mode..": live owner prevents initial slot read")
  assert(visitor:beginLife(mode,1));owner:flush(e.t+20)
  check(visitor:load()=="session" and not visitor.canRetry,mode..": unseen retirement is still refused after acquisition")
  local pkey="P_"..uid;local rkey="R_"..uid.."_"..mode
  local progress=Json.copy(e.backend.data[pkey]);local rest=canon(e.backend.data[rkey])
  check(progress.lock.session==visitor.id,mode..": regression actually acquired the abandoned lease")
  visitor:step()
  check(canon(e.backend.data[pkey])==canon(SaveEnvelope.withLock(progress,nil)),mode..": only owned lock metadata was released")
  check(canon(e.backend.data[rkey])==rest and not visitor.lifeRequests[mode].done,mode..": checkpoint, backup and refused acknowledgement untouched")
  local nextVisit=newSession(e,uid,"next-visit")
  check(nextVisit:load()=="active",mode..": next visit loads immediately without waiting120 seconds")
  check(canon(nextVisit.rests[mode])==canon(owner.rests[mode]),mode..": next visit receives the preserved life")
 end
end)

local function cleanupFixture(uid)
 local e=newEnv();local s=newSession(e,uid,"cleanup");assert(s:load()=="active")
 local raw=e.backend.data[s.pkey]
 raw=Json.copy(SaveEnvelope.make(SaveProgress.SPEC,raw.payload,e.t,raw,{lock=raw.lock}))
 assert(Json.canonical(raw),"fixture must be a storable tree, not shared payload references")
 raw.extra_metadata={preserve="unchanged"};e.backend:poke(s.pkey,raw)
 -- Queue local candidates that cleanup must never merge or acknowledge.
 s:setProgress(prog({"unsaved-local-page"}));assert(s:beginLife("main",1))
 return e,s,raw
end

case("session-only cleanup preserves progress, backup and unknown envelope metadata",function()
 local e,s,raw=cleanupFixture(1210)
 s:demote("other_session",false);local writes=e.backend.writes
 check(s:step(),"one queued cleanup request executes")
 check(canon(e.backend.data[s.pkey])==canon(SaveEnvelope.withLock(raw,nil)),"no local progress merge or backup rewrite")
 check(e.backend.data[s.rkey.main]==nil and not s.lifeRequests.main.done,"unsent rest/retirement never written or acknowledged")
 check(e.backend.writes==writes+1,"only the lock removal writes")
 local requests=e.backend.requests;s:step();s:step()
 check(e.backend.requests==requests,"completed cleanup has no recurring requests")
end)

case("lease cleanup refuses another owner even when its beat is stale",function()
 for i,beat in {100000,1} do
  local e,s,raw=cleanupFixture(1210+i);s:demote("other_session",false)
  local foreign=SaveEnvelope.withLock(raw,{session="other-owner",beat=beat});e.backend:poke(s.pkey,foreign)
  local writes=e.backend.writes;s:step()
  check(canon(e.backend.data[s.pkey])==canon(foreign),"foreign ownership metadata stays intact")
  check(e.backend.writes==writes,"foreign lock cleanup is a cancelled transform")
 end
end)

case("retried cleanup callback rechecks the latest owner",function()
 local e,s,raw=cleanupFixture(1213);s:demote("other_session",false)
 local update=e.backend.update;local calls=0
 local foreign=SaveEnvelope.withLock(raw,{session="replacement",beat=e.t})
 e.backend.update=function(self,key,transform)
  local discarded=transform(Json.copy(raw));calls+=1
  assert(discarded and discarded.lock==nil,"first speculative callback would release ours")
  self:poke(key,foreign)
  return update(self,key,function(latest) calls+=1;return transform(latest) end)
 end
 s:step()
 check(calls==2,"fixture reruns callback after a concurrent owner change")
 check(canon(e.backend.data[s.pkey])==canon(foreign),"final callback never releases a replacement owner")
end)

case("cleanup retries transient failure with backoff and resolves a lost success response",function()
 for i,afterWrite in {false,true} do
  local e,s,raw=cleanupFixture(1213+i);s:demote("other_session",true)
  e.backend:fail({op="update",key=s.pkey,times=1,afterWrite=afterWrite,message="lost cleanup response"})
  s:step();local requests=e.backend.requests;local writes=e.backend.writes
  check(releaseQueued(s),"uncertain cleanup remains queued")
  e.t+=1;s:step()
  check(e.backend.requests==requests,"neither cleanup retry nor reacquisition bypasses backoff")
  e.t+=1;s:step()
  check(not releaseQueued(s) and e.backend.data[s.pkey].lock==nil,"retry converges on released ownership")
  check(canon(e.backend.data[s.pkey])==canon(SaveEnvelope.withLock(raw,nil)),"ambiguous responses cannot rewrite progress/backup")
  check(e.backend.writes==writes+(if afterWrite then 0 else 1),"lost committed success does not duplicate a write")
 end
end)

case("metadata cleanup follows request budget and cannot renew a lease while waiting",function()
 local e,s=cleanupFixture(1216);s:demote("other_session",true)
 s.sched.started=table.create(SaveRules.REQUESTS_PER_MINUTE,e.t)
 local requests=e.backend.requests;e.t+=SaveRules.RETRY_LOAD;s:step()
 check(e.backend.requests==requests,"exhausted budget prevents cleanup and reacquisition")
 e.t+=61;s:step()
 check(e.backend.requests==requests+1 and e.backend.data[s.pkey].lock==nil,"one budgeted request releases rather than reacquires")
 check(s.state=="session","release is not a false recovery notification")
end)

case("unknown or damaged progress is never rewritten just to remove its lock",function()
 for i,kind in {"newer","corrupt","missing"} do
  local e,s,raw=cleanupFixture(1216+i);s:demote("other_session",false)
  if kind=="newer" then raw.schema=SaveProgress.SPEC.current+1
  elseif kind=="corrupt" then raw.checksum="damaged"
  else raw=nil end
  e.backend:poke(s.pkey,raw);local before=canon(raw);local writes=e.backend.writes;s:step()
  check(canon(e.backend.data[s.pkey])==before,kind..": unreadable or missing raw value retained")
  check(e.backend.writes==writes,kind..": cleanup never manufactures a default record")
 end
end)

case("successful explicit reload cancels stale cleanup and keeps the renewed active lease",function()
 local e,s=cleanupFixture(1220);s:demote("other_session",true)
 -- No queued retirement on this fixture: exercise successful deliberate reload.
 s.lifeRequests={};s.restPending={};s.restPendingTime={};s.sched:abandon("rest_main")
 check(s:load()=="active","same session can deliberately recover ownership")
 local requests=e.backend.requests;s:step()
 check(not releaseQueued(s) and e.backend.data[s.pkey].lock.session==s.id,"active ownership is not released by old cleanup")
 check(e.backend.requests<=requests+1,"only ordinary progress scheduling may run after reload")
end)

case("departure cleanup preserves dirty candidates and respects its deadline",function()
 for i,fail in {false,true} do
  local e,s,raw=cleanupFixture(1220+i);s:demote("other_session",false)
  if fail then e.backend:fail({op="update",key=s.pkey,times=10,message="offline"}) end
  local requests=e.backend.requests;local deadline=e.t+.5;s:flush(deadline)
  check(s.closed and e.t<=deadline,"departure completes without overrunning its sleep deadline")
  check(e.backend.requests==requests+1,"bounded departure made one cleanup attempt in this half-second window")
  check(canon(e.backend.data[s.pkey])==canon(if fail then raw else SaveEnvelope.withLock(raw,nil)),"departure changes no saved candidate")
  check(e.backend.data[s.rkey.main]==nil and not s.lifeRequests.main.done,"departure never flushes a refused life")
 end
end)


case("negotiated previews reveal a leased rest without loading it for writes",function()
 for i,mode in SaveRules.MODES do
  local e=newEnv();local uid=1300+i;local owner=newSession(e,uid,"owner")
  owner:load();owner:beginLife(mode,1);run(e,owner,15)
  assert(owner:setRestForLife(mode,realRest(120,mode),owner.lifeTokens[mode]));run(e,owner,15)
  local visitor=newSession(e,uid,"visitor");assert(visitor:load()=="session")
  local requests=e.backend.requests;visitor:step();visitor:step()
  check(e.backend.requests==requests,mode..": legacy transport performs no preview requests")
  local beforeP=canon(e.backend.data[visitor.pkey]);local beforeR=canon(e.backend.data[visitor.rkey[mode]]);local writes=e.backend.writes
  visitor:enableOffers()
  for _=1,3 do local n=e.backend.requests;visitor:step();check(e.backend.requests==n+1,mode..": one preview request per step") end
  local offer=visitor:offer(mode)
  check(offer~=nil and #SaveRest.check(mode,offer.record)==0,mode..": leased snapshot is a valid playable rest")
  check(not visitor.restLoaded[mode] and visitor.rests[mode]==nil and visitor.lifeTokens[mode]==nil and visitor.restBase[mode]==nil and visitor.restRevision[mode]==nil,mode..": preview grants no owned write base or credential")
  check(canon(e.backend.data[visitor.pkey])==beforeP and canon(e.backend.data[visitor.rkey[mode]])==beforeR and e.backend.writes==writes,mode..": preview preserves every stored byte and owner lock")
  local oldLife=offer.record.save_life;offer.record.save_life="mutated-view"
  check(visitor:offer(mode).record.save_life==oldLife,mode..": caller cannot edit private preview")
  requests=e.backend.requests;visitor:enableOffers();visitor:step();visitor:step()
  check(e.backend.requests==requests,mode..": repeated negotiation never rescans all three slots")
 end
end)
case("preview failures back off without manufacturing an empty owned slot",function()
 local e=newEnv();local owner=newSession(e,1310,"owner");owner:load()
 local s=newSession(e,1310,"visitor");s:load();s:enableOffers()
 e.backend:fail({op="read",key=s.rkey.main,times=1,message="502 offline"})
 s:step();local requests=e.backend.requests
 check(s.previewPending.main and s:offer("main")==nil and not s.restLoaded.main,"failed read remains pending, not missing/owned")
 s:step();s:step();local afterOtherSlots=e.backend.requests;s:step()
 check(afterOtherSlots==requests+2 and e.backend.requests==afterOtherSlots,"other slots progress once, failed slot waits")
 e.t+=2;s:step()
 check(s.previewPending.main==nil and not s.restLoaded.main,"successful missing preview is still not an owned empty slot")
end)
case("preview request budget and closed read completion",function()
 local e=newEnv();local owner=newSession(e,1311,"owner");owner:load()
 local s=newSession(e,1311,"visitor");s:load();s:enableOffers()
 s.sched.started=table.create(SaveRules.REQUESTS_PER_MINUTE,e.t)
 local requests=e.backend.requests;s:step()
 check(e.backend.requests==requests,"exhausted request budget blocks previews")
 s.sched.started={};local read=e.backend.read
 e.backend.read=function(self,key) s.closed=true;return read(self,key) end
 local notifications=0;s.cfg.onOffer=function() notifications+=1 end;s:step()
 check(s:offer("main")==nil and notifications==0,"read finishing after departure cannot publish or callback")
end)
case("read-only backup remains protected and unknown future rest stays untouched",function()
 local e=newEnv();local owner=newSession(e,1312,"owner");owner:load()
 owner:setRest("main",realRest(120,"main"));run(e,owner,15)
 owner:setRest("main",realRest(240,"main"));run(e,owner,15)
 local raw=Json.copy(e.backend.data[owner.rkey.main]);raw.checksum="damaged"
 e.backend:poke(owner.rkey.main,raw)
 local s=newSession(e,1312,"visitor");s:load();s:enableOffers();local before=canon(raw);local writes=e.backend.writes;s:step()
 local offer=s:offer("main")
 check(offer and offer.protected and #SaveRest.check("main",offer.record)==0,"readable backup is explicitly protected")
 check(canon(e.backend.data[s.rkey.main])==before and e.backend.writes==writes,"preview never repairs or replaces damaged primary")
 raw=Json.copy(raw);raw.schema=SaveRest.SPECS.main.current+1;e.backend:poke(s.rkey.main,raw)
 local future=newSession(e,1312,"future-viewer");future:load();future:enableOffers();future:step()
 check(future:offer("main")==nil and canon(e.backend.data[s.rkey.main])==canon(raw),"future schema never falls back to a writable/ordinary preview")
end)

-- Appended to default state.luau; real checkpoints and scripted store failures.
local function authorityFixture(uid,mode,foreign,legacy)
 local e=newEnv();local owner=newSession(e,uid,"original-owner");assert(owner:load()=="active")
 if mode=="easy" then owner:setProgress(prog({},{finished=true})) end
 if not legacy then owner:beginLife(mode,1);run(e,owner,15) end
 assert(owner:setRestForLife(mode,realRest(120,mode),owner.lifeTokens[mode]));run(e,owner,15)
 if not foreign then owner:flush(e.t+20) end
 local decisions={};local s=newSession(e,uid,"bound-visitor",{onDecision=function(value) table.insert(decisions,value) end})
 s:load();s:enableOffers();run(e,s,3)
 assert(s:offer(mode),"fixture requires an actual observed rest")
 return e,s,owner,decisions
end
local function grantContinue(e,s,mode,serial)
 local offer=assert(s:offer(mode));assert(s:requestLife("continue",mode,serial,offer.id));run(e,s,2)
 local r=assert(s.intents.requests[mode]);assert(r.state=="writable","fixture did not grant continuation")
 return r
end

case("bound Continue requires a separate acknowledged credential in all slots",function()
 for i,mode in SaveRules.MODES do
  local e,s,_,decisions=authorityFixture(1400+i,mode,false,false);local offer=s:offer(mode)
  local before=canon(e.backend.data[s.rkey[mode]])
  check(not s:setRestForLife(mode,realRest(240,mode),offer.record.save_life) and not s:beginLife(mode,1),mode..": persisted identity cannot use legacy write/retirement paths")
  check(s:requestLife("continue",mode,1,offer.id),mode..": exact displayed choice is accepted")
  check(decisions[#decisions].state=="readonly" and decisions[#decisions].credential==nil,mode..": choice alone grants no write credential")
  check(not s:setRestForIntent(mode,realRest(240,mode),offer.record.save_life,1,nil),mode..": nil acknowledgement never authorizes")
  check(canon(e.backend.data[s.rkey[mode]])==before,mode..": pre-validation messages do not write")
  run(e,s,2);local r=s.intents.requests[mode]
  check(r.state=="writable" and type(r.credential)=="string" and r.credential~=r.life,mode..": validation issues a separate credential")
  check(not s:setRestForIntent(mode,realRest(240,mode),r.life,1,"stale"),mode..": wrong credential refused")
  check(s:setRestForIntent(mode,realRest(240,mode),r.life,1,r.credential),mode..": exact credential queues a valid rest")
  run(e,s,15)
  check(e.backend.data[s.rkey[mode]].checksum==r.expected.checksum and canon(e.backend.data[s.rkey[mode]])~=before,mode..": stored revision follows the acknowledged world")
 end
end)

case("read-only Continue promotes only an unchanged foreign rest after recovery",function()
 for i,changed in {false,true} do
  local e,s,owner=authorityFixture(1410+i,"main",true,false);local offer=s:offer("main")
  assert(s:requestLife("continue","main",1,offer.id));local r=s.intents.requests.main
  check(r.state=="readonly" and not s:setRestForIntent("main",realRest(240,"main"),offer.record.save_life,1,"guess"),"leased play has no permission")
  if changed then owner:beginLife("main",2);run(e,owner,15);owner:setRestForLife("main",realRest(240,"main"),owner.lifeTokens.main);run(e,owner,15) end
  owner:flush(e.t+20);local before=canon(e.backend.data[s.rkey.main]);run(e,s,70)
  if changed then
   check(r.state=="changed" and r.credential==nil and not s.canRetry,"changed recovery needs a fresh explicit choice")
   check(canon(e.backend.data[s.rkey.main])==before,"foreign rest and backup never rebased or overwritten")
   check(e.backend.data[s.pkey].lock==nil,"refused recovery releases only its acquired lease")
  else check(r.state=="writable" and r.life==offer.record.save_life,"unchanged recovery is acknowledged") end
 end
end)

case("New Life is writable only after durable retirement and recovers without a second retirement",function()
 local e,s=authorityFixture(1420,"main",false,false);local offer=s:offer("main");local original=e.backend.data[s.rkey.main]
 assert(s:requestLife("new","main",1,offer.id));local r=s.intents.requests.main
 run(e,s,1)
 check(r.state=="readonly" and r.credential==nil and r.retireReady,"validated intent still waits for its durable marker")
 run(e,s,1);local marker=e.backend.data[s.rkey.main]
 check(r.state=="writable" and marker.payload.save_retired and marker.backup.checksum==original.checksum,"marker and previous rest precede acknowledgement")
 local credential=r.credential;local writes=e.backend.writes;s:requestLife("new","main",1,offer.id)
 check(r.credential==credential and e.backend.writes==writes,"duplicate intent neither mints permission nor rewrites backup")
 assert(s:setRestForIntent("main",realRest(240,"main"),r.life,1,credential));run(e,s,15)
 local before=canon(e.backend.data[s.rkey.main]);s:demote("other_session",true)
 check(not s:setRestForIntent("main",realRest(240,"main"),r.life,1,credential),"ownership loss revokes the old credential immediately")
 s:load();run(e,s,70)
 check(r.state=="writable" and r.credential~=credential,"established New Life receives a fresh continuation credential")
 check(canon(e.backend.data[s.rkey.main])==before and not e.backend.data[s.rkey.main].payload.save_retired,"recovery never retires the already played life again")
end)

case("empty-only New cannot retire an unseen record, but a missing slot and observed marker work",function()
 local e,s=authorityFixture(1421,"main",false,false);local before=canon(e.backend.data[s.rkey.main])
 assert(s:requestLife("new","main",1,nil));run(e,s,2)
 check(s.intents.requests.main.state=="changed" and canon(e.backend.data[s.rkey.main])==before,"no offer means physically missing only")
 e=newEnv();s=newSession(e,1422,"empty");s:load();s:enableOffers();run(e,s,3)
 assert(s:requestLife("new","main",1,nil));run(e,s,2)
 check(s.intents.requests.main.state=="writable" and e.backend.data[s.rkey.main].payload.save_retired,"genuinely missing slot can acknowledge New")
 local markerOffer=s:offer("main");assert(markerOffer and markerOffer.record.save_retired)
 check(s:requestLife("continue","main",2,markerOffer.id) and s.intents.requests.main.state=="changed","retirement marker is not a playable Continue")
 assert(s:requestLife("new","main",3,markerOffer.id));run(e,s,70)
 check(s.intents.requests.main.state=="writable" and s.lifeRequests.main.serial==3,"explicit New can bind an observed nonplayable marker")
end)

case("delayed validation cannot grant an intent superseded during its read",function()
 local e,s,_,decisions=authorityFixture(1430,"main",false,false);local offer=s:offer("main")
 assert(s:requestLife("continue","main",1,offer.id));local read=e.backend.read;local injected=false
 e.backend.read=function(self,key)
  if key==s.rkey.main and not injected then injected=true;assert(s:requestLife("new","main",2,offer.id)) end
  return read(self,key)
 end
 run(e,s,1);e.backend.read=read
 local stale=false;for _,d in decisions do if d.serial==1 and d.state=="writable" then stale=true end end
 check(injected and not stale,"old read completion emits no stale writable decision")
 run(e,s,70)
 check(s.intents.requests.main.serial==2 and s.intents.requests.main.state=="writable","only newer New intent can finish")
end)

case("atomic callback retries recheck the current selected intent",function()
 local e,s=authorityFixture(1431,"main",false,false);local r=grantContinue(e,s,"main",1)
 assert(s:setRestForIntent("main",realRest(240,"main"),r.life,1,r.credential))
 local before=canon(e.backend.data[s.rkey.main]);local update=e.backend.update;local injected=false
 e.backend.update=function(self,key,transform)
  if key==s.rkey.main and not injected then
   injected=true;assert(transform(Json.copy(self.data[key]))~=nil)
   assert(s:requestLife("new","main",2,s:offer("main").id))
  end
  return update(self,key,transform)
 end
 run(e,s,1);e.backend.update=update
 check(injected and canon(e.backend.data[s.rkey.main])==before,"discarded speculative callback cannot commit old rest after a newer choice")
 check(s.intents.requests.main.serial==2 and s.intents.requests.main.state=="readonly","old callback cannot acknowledge newer intent")
end)

case("commit before revocation preserves the authored revision without resurrecting permission",function()
 local e,s=authorityFixture(1432,"main",false,false);local r=grantContinue(e,s,"main",1);local credential=r.credential
 assert(s:setRestForIntent("main",realRest(240,"main"),r.life,1,credential))
 local update=e.backend.update;local revoked=false
 e.backend.update=function(self,key,transform)
  local ok,value,err=update(self,key,transform)
  if key==s.rkey.main and not revoked then revoked=true;s:demote("other_session",true) end
  return ok,value,err
 end
 run(e,s,1);e.backend.update=update
 check(revoked and r.state=="readonly" and r.credential==nil,"late successful response never restores permission after loss")
 local before=canon(e.backend.data[s.rkey.main]);s:load();run(e,s,70)
 check(r.state=="writable" and r.credential~=credential and canon(e.backend.data[s.rkey.main])==before,"fresh revalidation can recover our confirmed authored checkpoint")
end)

case("lost write response can advance to a newer queued checkpoint without rebasing foreign data",function()
 local e,s=authorityFixture(1433,"main",false,false);local r=grantContinue(e,s,"main",1)
 assert(s:setRestForIntent("main",realRest(240,"main"),r.life,1,r.credential))
 e.backend:fail({op="update",key=s.rkey.main,times=1,afterWrite=true,message="lost response"})
 run(e,s,1);local newer=realRest(360,"main")
 assert(s:setRestForIntent("main",newer,r.life,1,r.credential));run(e,s,5)
 local expected=Json.copy(newer);expected.save_life=r.life
 check(r.state=="writable" and canon(e.backend.data[s.rkey.main].payload)==canon(expected),"only our known authored ambiguous revision permits advancing a newer queued rest")
 check(r.expected.checksum==e.backend.data[s.rkey.main].checksum and r.ambiguous==nil,"successful retry settles exact revision")
end)

case("missing and equal-time foreign records cannot pass an acknowledged write callback",function()
 for i,missing in {false,true} do
  local e,s=authorityFixture(1440+i,"main",false,false);local r=grantContinue(e,s,"main",1)
  assert(s:setRestForIntent("main",realRest(240,"main"),r.life,1,r.credential))
  local old=e.backend.data[s.rkey.main];local replacement=nil
  if not missing then
   local payload=realRest(360,"main");payload.save_life=r.life
   replacement=SaveEnvelope.make(SaveRest.SPECS.main,payload,old.updatedAt,old,{session="foreign"})
  end
  e.backend:poke(s.rkey.main,replacement);local before=canon(replacement);run(e,s,1)
  check(r.state=="changed" and r.credential==nil,"changed revision revokes current authority")
  check(canon(e.backend.data[s.rkey.main])==before,"callback cannot recreate a deleted rest or replace an equal-time foreign revision")
 end
end)

case("protected backups and legacy nil identity never bypass the new credential gate",function()
 local e,s=authorityFixture(1450,"main",false,false);local old=e.backend.data[s.rkey.main]
 local raw=SaveEnvelope.make(SaveRest.SPECS.main,realRest(240,"main"),e.t,old,{session="foreign"});raw.checksum="damaged"
 e.backend:poke(s.rkey.main,raw);s.previewPending.main=true;s:step()
 local offer=s:offer("main");assert(offer and offer.protected);local before=canon(raw)
 assert(s:requestLife("continue","main",1,offer.id));run(e,s,15)
 check(s.intents.requests.main.state=="readonly" and canon(e.backend.data[s.rkey.main])==before,"readable backup stays temporary and preserves damaged primary")
 e,s=authorityFixture(1451,"main",false,true);local r=grantContinue(e,s,"main",1)
 check(r.life==nil and not s:setRestForIntent("main",realRest(240,"main"),nil,1,nil),"legacy nil life identity alone remains powerless")
 check(s:setRestForIntent("main",realRest(240,"main"),nil,1,r.credential),"legacy life can continue with an independent acknowledgement")
end)

case("validation is budgeted, backs off and respects Easy unlock",function()
 local e,s=authorityFixture(1452,"main",false,false);local offer=s:offer("main")
 check(not s:requestLife("new","easy",1,nil),"locked Easy cannot request a new authority")
 assert(s:requestLife("continue","main",1,offer.id));local r=s.intents.requests.main
 s.sched.started=table.create(SaveRules.REQUESTS_PER_MINUTE,e.t);local requests=e.backend.requests;s:step()
 check(e.backend.requests==requests and r.state=="readonly","budget exhaustion cannot grant or start a validation read")
 s.sched.started={};e.backend:fail({op="read",key=s.rkey.main,times=1,message="offline"});s:step()
 requests=e.backend.requests;s:step()
 check(e.backend.requests==requests and r.needsCheck and r.credential==nil,"failed validation backs off without permission")
 run(e,s,3);check(r.state=="writable","later successful read can acknowledge the same explicit observation")
end)

case("departure validates New before durable acknowledgement",function()
 local e,s=authorityFixture(1453,"main",false,false);local offer=s:offer("main")
 assert(s:requestLife("new","main",1,offer.id));s:flush(e.t+20)
 check(s.closed and e.backend.data[s.rkey.main].payload.save_retired and s.lifeRequests.main.done,"departure stores only a validated explicit retirement")
end)

local function serviceOffer(srv,p,mode)
 local list=srv.sent[p] or {}
 for i=#list,1,-1 do if list[i].kind=="offer" and list[i].mode==mode then return list[i].offer end end
 return nil
end
case("offer protocol transports observations separately and requires current intent credentials",function()
 local e=newEnv();local owner=newSession(e,1500,"owner");owner:load();owner:setRest("main",realRest(120,"main"));run(e,owner,15);owner:flush()
 local srv=newServer(e);local p=player(1500);srv.service:addPlayer(p);srv.service:onMessage(p,{kind="hello",v=SaveRules.OFFER_PROTOCOL})
 local loaded=srv.last(p,"loaded")
 check(loaded.v==SaveRules.OFFER_PROTOCOL and loaded.rests==nil and loaded.lives==nil,"negotiation never treats preview/life identities as ordinary loaded write credentials")
 check(loaded.sequence==1 and type(loaded.epoch)=="string","initial reply establishes sequence and owner epoch")
 tickServer(e,srv,3);local offer=assert(serviceOffer(srv,p,"main"));local before=canon(e.backend.data.R_1500_main)
 check(#SaveRest.check("main",offer.record)==0 and srv.count(p,"rest")==0,"valid rest travels only as an explicit offer")
 srv.service:onMessage(p,{kind="rest",mode="main",record=realRest(240,"main"),life=offer.record.save_life})
 srv.service:onMessage(p,{kind="begin_life",mode="main",serial=1});tickServer(e,srv,1)
 check(canon(e.backend.data.R_1500_main)==before and srv.count(p,"life")==0,"legacy upload/retirement cannot bypass negotiated authority")
 e.t+=5;srv.service:onMessage(p,{kind="life_intent",intent="continue",mode="main",serial=1,offerId=offer.id})
 check(srv.last(p,"decision").decision.state=="readonly","selected view is initially read-only")
 tickServer(e,srv,2);local d=srv.last(p,"decision").decision
 check(d.state=="writable" and d.serial==1 and type(d.credential)=="string","server replies with validated separate credential")
 srv.service:onMessage(p,{kind="rest",mode="main",record=realRest(240,"main"),life=d.life,serial=d.serial,credential=d.credential,restSerial=1});tickServer(e,srv,15)
 check(canon(e.backend.data.R_1500_main)~=before,"acknowledged rest is stored through the new route")
 local last=0;local ordered=true
 for _,m in srv.sent[p] do if m.epoch~=loaded.epoch or m.sequence<=last then ordered=false end;last=m.sequence end
 check(ordered,"all new-protocol status/offer/decision/loaded replies share a monotonic epoch sequence")
 local n=srv.count(p,"loaded");local dropped=srv.service.stats.dropped
 srv.service:onMessage(p,{kind="hello",v=SaveRules.PROTOCOL})
 check(srv.count(p,"loaded")==n and srv.service.stats.dropped==dropped+1,"compatible negotiation cannot be downgraded to regain legacy writes")
 local stable=canon(e.backend.data.R_1500_main)
 srv.service:onMessage(p,{kind="rest",mode="main",record=realRest(360,"main"),life=d.life});tickServer(e,srv,1)
 check(canon(e.backend.data.R_1500_main)==stable,"downgrade attempt does not restore the old rest API")
end)
case("older negotiated peers keep their original save route",function()
 local e=newEnv();local srv=newServer(e);local p=player(1501);srv.service:addPlayer(p)
 srv.service:onMessage(p,{kind="hello",v=1});local loaded=srv.last(p,"loaded")
 check(loaded.v==SaveRules.PROTOCOL and type(loaded.rests)=="table" and type(loaded.lives)=="table" and loaded.sequence==nil,"legacy reply shape remains unchanged")
 srv.service:onMessage(p,{kind="hello",v=SaveRules.OFFER_PROTOCOL})
 check(not srv.service.entries[p].session.offersEnabled,"later hello cannot silently upgrade a playing legacy session")
 srv.service:onMessage(p,{kind="rest",mode="main",record=realRest(120,"main")});tickServer(e,srv,15)
 check(e.backend.data.R_1501_main~=nil and srv.count(p,"offer")==0,"older peer still saves without preview copies or messages")
end)
case("pre-negotiation and unsupported peers cannot queue candidates or retain an owned lease",function()
 local e=newEnv();local srv=newServer(e);local p=player(1502);srv.service:addPlayer(p)
 srv.service:onMessage(p,{kind="progress",progress=prog({"unnegotiated"})})
 srv.service:onMessage(p,{kind="rest",mode="main",record=realRest(120,"main")})
 srv.service:onMessage(p,{kind="begin_life",mode="main",serial=1})
 tickServer(e,srv,2)
 check(e.backend.data.R_1502_main==nil and #e.backend.data.P_1502.payload.notebook.opened==0 and srv.sent[p]==nil,"before hello no rest/progress/retirement candidate is admitted")
 srv.service:onMessage(p,{kind="hello",v=999});tickServer(e,srv,2)
 check(e.backend.data.P_1502.lock==nil and not srv.service.entries[p].session.canRetry,"unsupported peer releases only its lease and stops renewing/retrying it")
 srv.service:onMessage(p,{kind="hello",v=SaveRules.OFFER_PROTOCOL});tickServer(e,srv,70)
 check(srv.service.entries[p].session.state=="active" and srv.last(p,"loaded").v==SaveRules.OFFER_PROTOCOL,"later supported negotiation can recover without a stale lock wait")
end)
case("a new-protocol intent arriving before the stored rest is read cannot retire an unseen life",function()
 local e=newEnv();local owner=newSession(e,1503,"owner");owner:load();owner:setRest("main",realRest(120,"main"));run(e,owner,15);owner:flush()
 local before=canon(e.backend.data.R_1503_main);local srv=newServer(e);srv.deferSpawn=true;local p=player(1503);srv.service:addPlayer(p)
 srv.service:onMessage(p,{kind="hello",v=SaveRules.OFFER_PROTOCOL})
 srv.service:onMessage(p,{kind="life_intent",intent="new",mode="main",serial=1})
 srv.deferSpawn=false;srv.drain();tickServer(e,srv,70)
 check(canon(e.backend.data.R_1503_main)==before,"deferred load preserves unseen primary and backup")
 local writable=false
 for _,m in srv.sent[p] or {} do if m.kind=="decision" and m.decision.state=="writable" then writable=true end end
 check(not writable and srv.last(p,"decision").decision.state=="changed","empty-only early intent never receives a write acknowledgement for discovered life")
end)
case("preview refresh requests are rate limited and issue no synchronous backend calls",function()
 local e=newEnv();local srv=newServer(e);local p=player(1504);srv.service:addPlayer(p);srv.service:onMessage(p,{kind="hello",v=SaveRules.OFFER_PROTOCOL});tickServer(e,srv,3)
 local requests=e.backend.requests;local limited=srv.service.stats.limited
 for _=1,40 do srv.service:onMessage(p,{kind="refresh_offer",mode="main"}) end
 check(e.backend.requests==requests and srv.service.stats.limited>=limited+38,"refresh burst is bounded and never reads from a RemoteEvent callback")
 tickServer(e,srv,1)
 check(e.backend.requests<=requests+1,"periodic refresh consumes at most one budgeted backend request")
end)

case("checkpoint receipts follow durable storage and duplicate retry preserves backup",function()
 local e,s=authorityFixture(1600,"main",false,false);local r=grantContinue(e,s,"main",1)
 local receipts={};s.cfg.onStored=function(mode,serial,credential,ticket) table.insert(receipts,{mode=mode,serial=serial,credential=credential,ticket=ticket}) end
 local candidate=realRest(240,"main");assert(s:setRestForIntent("main",candidate,r.life,1,r.credential,1))
 check(#receipts==0,"queueing never claims the checkpoint is stored")
 e.backend:fail({op="update",key=s.rkey.main,times=1,message="offline"});run(e,s,1)
 check(#receipts==0 and r.storedSerial==0,"failed storage produces no receipt")
 assert(s:setRestForIntent("main",candidate,r.life,1,r.credential,1));check(#receipts==0,"duplicate queued ticket is not an acknowledgement")
 run(e,s,3)
 check(#receipts==1 and receipts[1].ticket==1 and receipts[1].serial==1 and receipts[1].credential==r.credential,"only durable completion emits the exact granted ticket")
 local before=canon(e.backend.data[s.rkey.main]);local requests=e.backend.requests
 assert(s:setRestForIntent("main",realRest(360,"main"),r.life,1,r.credential,1))
 check(#receipts==2 and e.backend.requests==requests and canon(e.backend.data[s.rkey.main])==before,"replayed immutable ticket repeats receipt without accepting different contents or rewriting backup")
end)
case("newer queued checkpoint wins over delayed older tickets",function()
 local e,s=authorityFixture(1601,"main",false,false);local r=grantContinue(e,s,"main",1)
 local receipts={};s.cfg.onStored=function(_,_,_,ticket) table.insert(receipts,ticket) end
 local first,newer=realRest(240,"main"),realRest(360,"main")
 assert(s:setRestForIntent("main",first,r.life,1,r.credential,1));assert(s:setRestForIntent("main",newer,r.life,1,r.credential,2))
 check(not s:setRestForIntent("main",first,r.life,1,r.credential,1) and #receipts==0,"late older uncommitted ticket cannot replace a newer pending candidate")
 run(e,s,1);local expected=Json.copy(newer);expected.save_life=r.life
 check(#receipts==1 and receipts[1]==2 and canon(e.backend.data[s.rkey.main].payload)==canon(expected),"coalesced storage acknowledges only its actual latest ticket")
 local before=canon(e.backend.data[s.rkey.main]);assert(s:setRestForIntent("main",first,r.life,1,r.credential,1))
 check(receipts[#receipts]==2 and canon(e.backend.data[s.rkey.main])==before,"older retry can learn latest stored ticket without rolling back the world")
end)
case("ambiguous storage response never emits a premature receipt for a newer queued world",function()
 local e,s=authorityFixture(1602,"main",false,false);local r=grantContinue(e,s,"main",1)
 local receipts={};s.cfg.onStored=function(_,_,_,ticket) table.insert(receipts,ticket) end
 assert(s:setRestForIntent("main",realRest(240,"main"),r.life,1,r.credential,1))
 e.backend:fail({op="update",key=s.rkey.main,times=1,afterWrite=true,message="lost response"});run(e,s,1)
 check(#receipts==0,"unconfirmed commit is not acknowledged")
 assert(s:setRestForIntent("main",realRest(360,"main"),r.life,1,r.credential,2));run(e,s,3)
 check(#receipts==1 and receipts[1]==2 and r.storedSerial==2,"retry advances only a known authored ambiguous revision and acknowledges the newer checkpoint")
end)
case("new grant rejects old receipt credentials and idempotently confirms the same checkpoint",function()
 local e,s=authorityFixture(1603,"main",false,false);local r=grantContinue(e,s,"main",1);local candidate=realRest(240,"main")
 local receipts={};s.cfg.onStored=function(_,_,credential,ticket) table.insert(receipts,{credential=credential,ticket=ticket}) end
 assert(s:setRestForIntent("main",candidate,r.life,1,r.credential,1));run(e,s,1);local oldCredential=r.credential
 s:demote("other_session",true);s:load();run(e,s,70)
 local count=#receipts;local before=canon(e.backend.data[s.rkey.main])
 check(not s:setRestForIntent("main",candidate,r.life,1,oldCredential,1) and #receipts==count,"old grant cannot solicit a new-current receipt")
 assert(s:setRestForIntent("main",candidate,r.life,1,r.credential,1));run(e,s,1)
 check(#receipts==count+1 and receipts[#receipts].credential==r.credential and receipts[#receipts].ticket==1,"fresh grant confirms the immutable candidate using its current credential")
 check(canon(e.backend.data[s.rkey.main])==before,"idempotent confirmation preserves timestamp, checksum and backup")
end)
case("receipt callback failure can be recovered without another storage write",function()
 local e,s=authorityFixture(1604,"main",false,false);local r=grantContinue(e,s,"main",1);local candidate=realRest(240,"main")
 s.cfg.onStored=function() error("synthetic dropped reply") end
 assert(s:setRestForIntent("main",candidate,r.life,1,r.credential,1));run(e,s,1)
 local before=canon(e.backend.data[s.rkey.main]);local requests=e.backend.requests;local receipt=0
 s.cfg.onStored=function(_,_,_,ticket) receipt=ticket end
 assert(s:setRestForIntent("main",candidate,r.life,1,r.credential,1))
 check(receipt==1 and e.backend.requests==requests and canon(e.backend.data[s.rkey.main])==before,"lost outbound receipt is retransmitted from confirmed state")
end)
case("throttled wire upload can retry its ticket and receive actual storage confirmation",function()
 local e=newEnv();local owner=newSession(e,1605,"owner");owner:load();owner:setRest("main",realRest(120,"main"));run(e,owner,15);owner:flush()
 local srv=newServer(e);local p=player(1605);srv.service:addPlayer(p);srv.service:onMessage(p,{kind="hello",v=SaveRules.OFFER_PROTOCOL});tickServer(e,srv,3)
 local offer=assert(serviceOffer(srv,p,"main"));srv.service:onMessage(p,{kind="life_intent",intent="continue",mode="main",serial=1,offerId=offer.id});tickServer(e,srv,2)
 local d=srv.last(p,"decision").decision;assert(d.state=="writable")
 local msg={kind="rest",mode="main",record=realRest(240,"main"),life=d.life,serial=1,credential=d.credential,restSerial=1}
 local bucket=srv.service.entries[p].restBucket;bucket.tokens=0;bucket.last=e.t
 srv.service:onMessage(p,msg)
 check(srv.last(p,"stored")==nil,"throttled admission cannot pretend the packet was stored")
 e.t+=5;srv.service:onMessage(p,msg);tickServer(e,srv,1);local stored=srv.last(p,"stored")
 check(stored and stored.restSerial==1 and stored.serial==1 and stored.credential==d.credential and type(stored.sequence)=="number","retry receives a sequence-stamped exact storage receipt")
end)

case("permanent checkpoint refusal identifies only its own immutable ticket",function()
 local e=newEnv();local owner=newSession(e,1610,"owner");owner:load();owner:setRest("main",realRest(120,"main"));run(e,owner,15);owner:flush()
 local srv=newServer(e);local p=player(1610);srv.service:addPlayer(p);srv.service:onMessage(p,{kind="hello",v=SaveRules.OFFER_PROTOCOL});tickServer(e,srv,3)
 local offer=assert(serviceOffer(srv,p,"main"));srv.service:onMessage(p,{kind="life_intent",intent="continue",mode="main",serial=1,offerId=offer.id});tickServer(e,srv,2)
 local d=srv.last(p,"decision").decision;assert(d.state=="writable");local before=canon(e.backend.data.R_1610_main)
 srv.service:onMessage(p,{kind="rest",mode="main",record={broken=true},life=d.life,serial=1,credential=d.credential,restSerial=1})
 local refused=srv.last(p,"refused")
 check(refused and refused.serial==1 and refused.restSerial==1 and refused.credential==d.credential and refused.reason=="invalid_checkpoint","permanent failure is scoped to the exact offending ticket and grant")
 check(canon(e.backend.data.R_1610_main)==before and srv.last(p,"stored")==nil,"refusal never changes the stored record or invents storage success")
 srv.service:onMessage(p,{kind="rest",mode="main",record=realRest(240,"main"),life=d.life,serial=1,credential=d.credential,restSerial=2});tickServer(e,srv,1)
 check(srv.last(p,"stored").restSerial==2,"a later valid candidate can succeed independently of an older refusal")
end)


case("repeated validation failures never claim Saved and can recover unchanged authority",function()
 local e,s=authorityFixture(1611,"main",false,false);local offer=s:offer("main");local before=canon(e.backend.data[s.rkey.main])
 assert(s:requestLife("continue","main",1,offer.id));local r=s.intents.requests.main
 e.backend:fail({op="read",key=s.rkey.main,times=3,message="offline"});run(e,s,10)
 local status,reason=s:status()
 check(r.state=="readonly" and r.credential==nil and status=="saving" and reason=="write_failed","unresolved repeated validation is not falsely Saved")
 check(canon(e.backend.data[s.rkey.main])==before,"failed validation changes no stored rest")
 run(e,s,70) -- initial reads/failures also consumed the one-minute request budget
 check(r.state=="writable" and select(1,s:status())=="saved","unchanged successful recovery clears the failure state")
end)

case("actual client and service preserve temporary play then confirm a retried durable checkpoint",function()
 local SaveClient=require("../src/Client/SaveClient")
 for i,mode in SaveRules.MODES do
  local e=newEnv();local uid=1700+i;local owner=newSession(e,uid,"owner")
  owner:load();local progress=prog({});progress.finished_main=true;owner:setProgress(progress)
  assert(owner:setRest(mode,realRest(120,mode)));run(e,owner,15)
  local original=canon(e.backend.data[owner.rkey[mode]])
  local srv=newServer(e);local p=player(uid);srv.service:addPlayer(p)
  local receiver;local cursor=0;local restores=0;local lostReceipt=false;local loadedCount=0
  local remotes={client={OnClientEvent={Connect=function(_,fn) receiver=fn end}},server={FireServer=function(_,msg) srv.service:onMessage(p,msg) end}}
  local client=SaveClient.new({rules=SaveRules,now=e.now,findRemotes=function() return remotes end,
   continuation={copy=Json.copy,validate=function(m,r,allowRetired)
    if allowRetired and SaveRest.isRetired(r) then return SaveRest.bounded(r,10,3)==nil and SaveRest.validLife(r.save_life) end
    return #SaveRest.check(m,r)==0
   end,onRestore=function(m,r) assert(m==mode and #SaveRest.check(m,r)==0);restores+=1 end},
   onLoaded=function() loadedCount+=1 end,onRest=function() error("bound route used legacy callback") end,onStatus=function() end,build=function() return prog({}) end})
  local function pump()
   local list=srv.sent[p] or {}
   while cursor<#list do
    cursor+=1;local msg=list[cursor]
    if msg.kind=="stored" and not lostReceipt then lostReceipt=true else receiver(msg) end
   end
  end
  local function step(n)
   for _=1,n do e.t+=1;client:update();srv.service:step();pump() end
  end
  client:update();pump();step(5)
  check(loadedCount==1 and client:status()=="session",mode..": live owner yields temporary connection")
  local offered=assert(client:offer(mode));check(client:continueLife(mode,offered.id) and restores==1,mode..": explicit actual checkpoint restoration")
  local localRest=realRest(240,mode);check(client:sendRest(mode,localRest),mode..": real candidate held while readonly")
  step(5)
  check(canon(e.backend.data[owner.rkey[mode]])==original and restores==1,mode..": temporary play cannot overwrite owner or rewind")
  owner:flush();step(100)
  local stored=SaveEnvelope.open(SaveRest.SPECS[mode],e.backend.data[owner.rkey[mode]] or {})
  local expected=Json.copy(localRest);expected.save_life=client.bound.requests[mode].life
  check(stored.status=="ok" and type(stored.payload.snapshot_tick)=="number" and canon(stored.payload)==canon(expected),mode..": unchanged ownership recovery stores the entire held world exactly")
  check(lostReceipt and client:status()=="saved",mode..": retry recovers a deliberately dropped durable receipt")
  check(restores==1,mode..": load/recovery/ack replies never restore twice")
  check(srv.count(p,"life")==0 and srv.count(p,"rest")==0,mode..": negotiated route exposes no legacy credentials/rests")
 end
end)

case("client world-aware rest validation keeps the full acceptance boundary without a second decode",function()
 for _,mode in SaveRules.MODES do
  local record,world=realRest(120,mode);local original=canon(record)
  check(#SaveRest.check(mode,record)==0 and #SaveRest.check(mode,record,world)==0,mode..": complete real checkpoint validates against either proper world")
  for _,damage in {"schema","graph","life","position"} do
   local bad=Json.copy(record)
   if damage=="schema" then bad.schema_version=1e9
   elseif damage=="graph" then bad.world.objects[1]=nil
   elseif damage=="life" then bad.life_rules.mode="unknown"
   else bad.player.position={0/0,0,0} end
   check(#SaveRest.check(mode,bad)>0 and #SaveRest.check(mode,bad,world)>0,mode..": both validators reject "..damage)
  end
  check(canon(record)==original,mode..": validation never mutates input")
 end
end)

case("fresh rest observations use uncached adapter reads before granting write authority",function()
local Backend=DataStoreBackend
-- Real SaveSession + real DataStoreBackend; simulated four-second DataStore cache.
-- The payloads were captured by the real checkpoint code in the CLI fixture.
for index,mode in {"main","free","easy"} do
 for _,scenario in {"same","changed","missing","corrupt","newer","unavailable"} do
  local now=100;local storage=MemoryBackend.new();local uid=9200+index
  local ds={cache={},expires={},fresh=0,ordinary=0,fail=false}
  function ds:GetAsync(key,options)
   if options and options.UseCache==false then self.fresh+=1 else
    self.ordinary+=1
    if self.expires[key] and now<self.expires[key] then return Json.copy(self.cache[key]) end
   end
   if self.fail then error("503: unavailable") end
   local ok,value,why=storage:read(key);assert(ok,why)
   self.cache[key]=Json.copy(value);self.expires[key]=now+4
   return value
  end
  function ds:UpdateAsync(key,fn)
   local ok,value,why=storage:update(key,fn);assert(ok,why)
   self.cache[key]=Json.copy(value);self.expires[key]=now+4
   return value
  end
  local backend=Backend.new(ds)
  local record=realRest(1,mode);record.save_life="adapter-"..mode
  local initial=SaveEnvelope.make(SaveRest.SPECS[mode],record,90,nil)
  local key="R_"..uid.."_"..mode
  storage:poke(key,initial)
  local progress=SaveProgress.default();progress.finished_main=true
  storage:poke("P_"..uid,SaveEnvelope.make(SaveProgress.SPEC,progress,90,nil))
  local s=SaveSession.new({backend=backend,userId=uid,sessionId="adapter-probe",now=function() return now end})
  check(s:load()=="active","adapter load failed")
  s:enableOffers();for _=1,3 do now+=.1;s:step() end
  local offer=assert(s:offer(mode));local original=Json.canonical(initial)
  local replacement=Json.copy(initial)
  if scenario=="changed" then
   local other=realRest(2,mode);other.save_life=record.save_life
   replacement=SaveEnvelope.make(SaveRest.SPECS[mode],other,90,nil)
  elseif scenario=="missing" then replacement=nil
  elseif scenario=="corrupt" then replacement.checksum="bad"
  elseif scenario=="newer" then replacement.schema=initial.schema+1
  elseif scenario=="unavailable" then ds.fail=true end
  storage:poke(key,replacement)
  local stored=Json.canonical(replacement);local writes=storage.writes
  check(s:requestLife("continue",mode,1,offer.id),"adapter choice refused")
  now+=.1;s:step();local r=s.intents.requests[mode]
  if scenario=="same" then
   check(r.state=="writable" and type(r.credential)=="string","unchanged source not writable")
  elseif scenario=="unavailable" then
   check(r.credential==nil and r.needsCheck and r.nextAt>now,"failed uncached request granted authority")
   ds.fail=false;now=r.nextAt+.001;s:step()
   check(r.state=="writable" and type(r.credential)=="string","uncached retry failed")
  else check(r.state=="changed" and r.credential==nil,"foreign source accepted: "..scenario) end
  check(ds.ordinary==0 and ds.fresh>0,"adapter silently used cached GetAsync")
  check(Json.canonical(storage.data[key])==stored and storage.writes==writes,"session validation wrote source")
  check(Json.canonical(initial)==original,"original observation mutated")
  print("SESSION_ADAPTER_CASE "..mode.." "..scenario)
 end
end
end)

case("periodic recovery delivers only freshly loaded slots within request bounds",function()
local passedBudget=0
local failedBudget=0
local function verifyBudget(ok,why)
 check(ok,why)
 if not ok then failedBudget+=1;error(why,2) end
 passedBudget+=1
end
for _,kind in {"rest_retry","lease_retry"} do
 local now=100;local b=MemoryBackend.new();local loaded=0;local delivered={}
 for _,mode in SaveRules.MODES do
  local record=realRest(1,mode);record.save_life="budget-"..mode
  b:poke("R_9300_"..mode,SaveEnvelope.make(SaveRest.SPECS[mode],record,90,nil))
 end
 if kind=="rest_retry" then b:fail({op="read",key="R_*",times=3})
 else b:fail({op="update",key="P_*",times=1}) end
 local s
 s=SaveSession.new({backend=b,userId=9300,sessionId="budget-candidate",now=function() return now end,
  onLoaded=function(snapshot)
   for _,mode in SaveRules.MODES do
    verifyBudget(s.restLoaded[mode] or snapshot.rests[mode]==nil,"loaded callback exposed an unvalidated slot")
   end
   loaded+=1
  end,onRest=function(mode,record)
   verifyBudget(record.save_life=="budget-"..mode,"wrong source delivered")
   delivered[mode]=(delivered[mode] or 0)+1
  end})
 s:load()
 verifyBudget(if kind=="rest_retry" then s.state=="active" and not s:restsLoaded() else s.state=="session" and s.canRetry,"invalid recovery fixture")
 now=if kind=="rest_retry" then s.restRetryAt+.001 else s.retryAt+.001
 while #s.sched.started<SaveRules.REQUESTS_PER_MINUTE-1 do s.sched:begin(nil,now) end
 local before=b.requests;verifyBudget(s:step(),"recovery did not run")
 verifyBudget(b.requests-before==1 and #s.sched.started==SaveRules.REQUESTS_PER_MINUTE,"periodic recovery exceeded remaining request budget")
 verifyBudget(loaded==(if kind=="lease_retry" then 1 else 0),"merged progress notification was delayed")
 now+=.1;before=b.requests;s:step()
 verifyBudget(b.requests==before,"exhausted budget admitted another request")
 now+=61
 for _=1,8 do
  before=b.requests;s:step()
  verifyBudget(b.requests-before<=1,"periodic step exceeded one request")
  verifyBudget(#s.sched.started<=SaveRules.REQUESTS_PER_MINUTE,"periodic minute budget exceeded")
  now+=.1
 end
 verifyBudget(s.state=="active" and s:restsLoaded(),"recovery did not finish")
 verifyBudget(loaded==(if kind=="lease_retry" then 1 else 0),"load notification missing or repeated")
 for _,mode in SaveRules.MODES do verifyBudget(delivered[mode]==1,"slot callback missing or duplicated") end
 print("SESSION_BUDGET_CANDIDATE "..kind.." bounded_and_complete")
end
-- A persistently unreadable first slot cannot starve other slots.
do
 local now=100;local b=MemoryBackend.new()
 b:fail({op="read",key="R_*",times=3})
 local s=SaveSession.new({backend=b,userId=9301,sessionId="budget-fairness",now=function() return now end})
 s:load();b:fail({op="read",key="R_9301_main",times=20})
 for _=1,3 do
  now=math.max(now+.1,s.restRetryAt+.001);local before=b.requests;s:step()
  verifyBudget(b.requests-before==1,"fairness retry made multiple requests")
 end
 verifyBudget(not s.restLoaded.main and s.restLoaded.free and s.restLoaded.easy,"failed slot starved other modes")
end
-- Reacquisition preserves the retained observations internally, sends merged
-- progress promptly, and delivers each newly verified replacement exactly once.
do
 local now=100;local b=MemoryBackend.new();local delivered={};local snapshots={};local fresh={}
 for _,mode in SaveRules.MODES do
  local record=realRest(1,mode);record.save_life="retained-"..mode
  b:poke("R_9302_"..mode,SaveEnvelope.make(SaveRest.SPECS[mode],record,90,nil))
  local other=realRest(2,mode);other.save_life=record.save_life
  fresh[mode]=SaveEnvelope.make(SaveRest.SPECS[mode],other,90,nil)
 end
 local s=SaveSession.new({backend=b,userId=9302,sessionId="budget-retained",now=function() return now end,
  onLoaded=function(snapshot) table.insert(snapshots,snapshot) end,
  onRest=function(mode,record)
   verifyBudget(Json.canonical(record)==Json.canonical(fresh[mode].payload),"old retained rest delivered as fresh")
   delivered[mode]=(delivered[mode] or 0)+1
  end})
 s:load();local retained=s.rests;local original=Json.canonical(retained)
 s:demote("load_failed",true);s:step() -- release the old lease before recovery
 for _,mode in SaveRules.MODES do b:poke(s.rkey[mode],fresh[mode]) end
 now=s.retryAt+.001;local before=b.requests;s:step()
 verifyBudget(b.requests-before==1 and #snapshots==1,"lease retry delayed progress or batched requests")
 verifyBudget(next(snapshots[1].rests)==nil,"lease retry exposed retained rests as freshly verified")
 verifyBudget(s.rests==retained and Json.canonical(retained)==original,"lease retry discarded retained observations")
 for _=1,3 do before=b.requests;now+=.1;s:step();verifyBudget(b.requests-before==1,"rest reload batched requests") end
 verifyBudget(s:restsLoaded() and not s.restReloading,"partial reload never completed")
 for _,mode in SaveRules.MODES do
  verifyBudget(delivered[mode]==1,"fresh replacement not delivered exactly once")
  verifyBudget(Json.canonical(s:snapshot().rests[mode])==Json.canonical(fresh[mode].payload),"snapshot retained old source after verification")
 end
 verifyBudget(#snapshots==1,"progress reload notification duplicated")
end
verifyBudget(failedBudget==0,"callback failures were caught internally: "..failedBudget)
end)

case("suspended recovery is fenced after close demotion and superseding load",function()
local checksYield=0
local function verifyYield(ok,why) check(ok,why);assert(ok,why);checksYield+=1 end
for _,operation in {"read","lock"} do
 for _,action in {"close","demote","supersede"} do
  local now=100;local b=MemoryBackend.new();local callbacks=0
  local record=realRest(1,"main");record.save_life="yield-life"
  b:poke("R_9400_main",SaveEnvelope.make(SaveRest.SPECS.main,record,90,nil))
  if operation=="read" then b:fail({op="read",key="R_*",times=3})
  else b:fail({op="update",key="P_*",times=1}) end
  local s=SaveSession.new({backend=b,userId=9400,sessionId="budget-yield",now=function() return now end,
   onRest=function() callbacks+=1 end,onLoaded=function() callbacks+=1 end})
  s:load();now=if operation=="read" then s.restRetryAt+.001 else s.retryAt+.001
  local key=if operation=="read" then "read" else "update"
  local original=b[key];local suspended=false
  b[key]=function(self,...)
   if not suspended then suspended=true;coroutine.yield("request-pending") end
   return original(self,...)
  end
  local worker=coroutine.create(function() return s:step() end)
  local ok,signal=coroutine.resume(worker)
  verifyYield(ok and signal=="request-pending" and s.busy,"fixture did not suspend an actual recovery request")
  local requests=b.requests;verifyYield(not s:step() and b.requests==requests,"reentrant step started a parallel request")
  local progress=Json.canonical(s.progress)
  if action=="close" then s:flush(now+.001);verifyYield(s.closed,"departure failed to close pending session")
  elseif action=="demote" then s:demote("offline",false)
  else verifyYield(s:load()=="active","superseding load failed") end
  local retained=Json.canonical({rests=s.rests,loaded=s.restLoaded,progress=s.progress})
  ok,signal=coroutine.resume(worker)
  verifyYield(ok and coroutine.status(worker)=="dead","pending recovery failed to settle")
  verifyYield(callbacks==0,"cancelled or superseded recovery emitted a late callback: "..operation.."/"..action)
  if action=="supersede" then
   verifyYield(s.state=="active" and s:restsLoaded(),"stale operation damaged newer load")
  else
   verifyYield(Json.canonical(s.progress)==progress,"cancelled recovery adopted progress")
   verifyYield(if action=="close" then s.closed else s.state=="session" and not s.lockHeld,"cancelled recovery regained authority")
  end
  verifyYield(Json.canonical({rests=s.rests,loaded=s.restLoaded,progress=s.progress})==retained,"cancelled recovery changed retained state")
  print("SESSION_BUDGET_YIELD "..operation.." "..action.." fenced")
 end
end
end)

case("optional service owner is the only work and intake route",function()
 local now=100;local b=MemoryBackend.new();local sent={};local calls={};local owned;local emitOwner
 local service=SaveService.new({backend=b,now=function() return now end,sleep=function(dt) now+=dt end,spawn=function(f,...) f(...) end,
  send=function(_player,msg) table.insert(sent,msg) end,jobId="owner-hook",
  ownerFactory=function(cfg,emit)
   local session=SaveSession.new(cfg);local result={session=session};emitOwner=emit
   for _,name in {"load","step","flush","setProgress","beginLife","requestLife","refreshOffer","setRestForIntent","setRestForLife","enableOffers","demote"} do
    result[name]=function(_self,...) calls[name]=(calls[name] or 0)+1;return session[name](session,...) end
   end
   result.applyRecovery=function(_self,msg) calls.applyRecovery=(calls.applyRecovery or 0)+1;return msg.id=="exact" end
   check(session.counters.requests==0,"owner constructor performed storage work");owned=result;return result
  end})
 local player={UserId=9950,Name="owner-test"};service:addPlayer(player)
 check(calls.load==1 and service.entries[player].session==owned.session,"service bypassed owned load or session")
 emitOwner({kind="recovery_entry",offer={id="pre-hello"}});check(#sent==0,"owned sender spoke before negotiation")
 service:onMessage(player,{kind="recovery_applied",id="exact"});check(calls.applyRecovery==nil,"receipt reached owner before hello")
 service:onMessage(player,{kind="hello",v=SaveRules.OFFER_PROTOCOL});check(calls.enableOffers==1,"hello bypassed owner negotiation")
 local n=#sent;emitOwner({kind="recovery_entry",offer={id="exact"}})
 check(#sent==n+1 and sent[#sent].epoch==owned.session.id and type(sent[#sent].sequence)=="number","owned sender bypassed transport stamps")
 emitOwner({kind="decision",decision={state="writable"}});check(#sent==n+1,"owned sender accepted an unsupported packet kind")
 service.entries[player].lifeBucket.tokens=0
 service:onMessage(player,{kind="recovery_applied",id="exact"});check(calls.applyRecovery==1,"intent retries starved matching recovery receipt")
 check(service.entries[player].lifeBucket.tokens==0,"recovery receipt consumed intent capacity")
 now+=5
 service:onMessage(player,{kind="progress",progress=SaveProgress.default()});check(calls.setProgress==1,"progress bypassed owner")
 now+=5;service:onMessage(player,{kind="life_intent",intent="new",mode="main",serial=1});check(calls.requestLife==1,"intent bypassed owner")
 for _=1,12 do now+=1;service:step() end
 check(calls.step~=nil and owned.session.intents.requests.main.state=="writable","owned worker did not perform real intent grant")
 local r=owned.session.intents.requests.main
 now+=5;service:onMessage(player,{kind="rest",mode="main",record={},serial=r.serial,credential=r.credential,life=r.life,restSerial=1})
 check(calls.setRestForIntent==1,"checkpoint bypassed owner intake")
 now+=5;service:onMessage(player,{kind="refresh_offer",mode="free"});check(calls.refreshOffer==1,"refresh bypassed owner")
 local stable=owned.session;local requests=b.requests;owned.session={id="foreign"};service:step()
 check(b.requests==requests,"silent owner session replacement performed storage work");owned.session=stable
 service:removePlayer(player);check(calls.flush==1 and stable.closed,"departure bypassed owned closed flush")
 local after=#sent;emitOwner({kind="recovery_entry",offer={id="late"}});check(#sent==after,"departed owner sent a late entry offer")
 local other={UserId=9951,Name="owner-shutdown"};service:addPlayer(other);service:shutdown()
 check(calls.flush==2 and owned.session.closed,"shutdown bypassed owned flush")
end)

print(`STATE passed={passed} failed={failed}`)
if failed > 0 then error("state checks failed") end
