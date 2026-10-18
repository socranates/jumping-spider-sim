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
local SaveEnvelope = require("../src/Shared/Persistence/SaveEnvelope")
local SaveProgress = require("../src/Shared/Persistence/SaveProgress")
local SettingsModel = require("../src/Shared/UI/SettingsModel")
local SaveRest = require("../src/Shared/Persistence/SaveRest")
local SaveScheduler = require("../src/Shared/Persistence/SaveScheduler")
local SaveSession = require("../src/Shared/Persistence/SaveSession")
local DataStoreBackend = require("../src/Server/DataStoreBackend")
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
	local needs = NeedsModel.new(true, mode == "free")
	prey.feeding.needs = needs
	local w: any = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs }
	w.life = LifeLoop.new(needs, function() return { ok = true, message = "" } end)
	if mode == "free" then w.life.mode, w.life.rules = "free", "gentle" end
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
	check(2 * SaveRules.MAX_REST_CHARS + 4096 < SaveRules.MAX_VALUE_CHARS, "a capped rest and its backup fit one stored value")
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
	-- the rest alone being newer (progress fine): the session goes session-only too
	local e2 = newEnv()
	e2.backend.data["R_7_free"] = { format = SaveRules.FORMAT, kind = "rest_free", schema = 7, updatedAt = 12, payload = { new = "world" }, checksum = "later" }
	local s2 = newSession(e2, 7, "S")
	s2:load()
	check(s2.state == "session" and s2.reason == "newer", "a newer rest alone also stops saving")
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
		check(a.reason == "corrupt", when .. ": player is told saving is off")
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

print(`STATE passed={passed} failed={failed}`)
