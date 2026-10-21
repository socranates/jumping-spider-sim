--!strict
-- The retreat checkpoint (S01-C; Godot's scripts/persistence/checkpoint.gd, T09; ROBLOX-25). A checkpoint is the whole world
-- at one tick boundary in one plain record: the spider standing on its surface, its reserves and the books of what fed them,
-- the life clock and the rest, every fly with its random stream and whatever it was in the middle of, who sits on and who
-- has reserved each perch, the replacements still owed, the captures made, the meal in the jaws, and what the spider's senses
-- and memory held. Restoring one puts back all of it together, so an earlier spider is never put into a newer world and a fly
-- eaten after the checkpoint is not eaten twice: the fly and the energy it gave come back together.
--
-- When: only at the end of a tick, from a still spider on a surface that is not mid-meal, mid-struggle or mid-strike
-- (boundaryProblem). The player makes one by resting in the silk-lined crack (LifeLoop) and when a night's sleep reaches the
-- morning. Airborne, hanging, aiming and eating are refused: exact arbitrary-state resume (the original S01) stays deferred.
-- How: the live objects are recorded as one graph (ObjectRecord), so no field can be forgotten; the spider's body is
-- recorded by its pose (Godot's player record) and put back with SpiderMotor.place.
-- Validation happens on the record alone, before anything live changes: the format, schema and windowsill, the spider's
-- pose, every reference in the graph, and then the meaning of the rebuilt world (reserves in range and books that add up,
-- the clock, unique flies, perches held by flies that exist, the meal in the jaws one of them). A record with any problem is
-- refused with its reasons and the live world is left exactly as it was.
-- The wasp keeps a small record beside the graph (Godot's checkpoint schema 6): the day of its last visit and this life's visits and
-- escapes, so a return to a rest meets the same wasp. A visit going on is not kept; restoring ends it. A record without one (the port's
-- first checkpoints were made before the wasp) gets the record of a life it has not yet visited.
-- Differences from Godot: the record is the port's own (its flies are the port's, Chet's ROBLOX flies, not Godot's), so
-- Godot checkpoints are not read and schema numbers start again at 1. Schema 3 adds growth and its food ledger cursor.
-- The passing shadow and notebook are not recorded.
-- ROBLOX-91: nor are the two profiling windows of the live world: the prey director's `cpu` (the last 1200 ticks' microseconds) and the sensor's cost ring. They are
-- clock readings, different on every run, and were about 2400 floats, twice the rest of the record; capture leaves them out and a restore (of an old record too)
-- leaves them empty.
-- ROBLOX-94: where in the world the rest was kept is `world_map` = { seed, revision, region, retreat, diffs } (not `world`: that is the recorded object graph). The world is
-- never saved, only the seed and the revision it was made from and what changed in it (`diffs`, empty until something in the world can change). A record without one (every
-- rest before the world) means the sill of the default world with no changes. A region that is not on the map, or a position outside that region's bounds, is refused like
-- any bad record. A rest made in another revision of the world, or from another seed, is put back at its region's spawn: the position was kept for geometry that may have
-- moved, so it is not trusted (the rest of the record is: the life, the reserves, the clock).
-- ROBLOX-95: the world is at revision world-2 (the sill's back frame opened, the garden added) and a record without `world_map` is read as world-1's, the sill
-- of before: every rest kept before this round is put back at its region's spawn with the notice. A rest in the garden (the gap under the bed's stone) records
-- region bed_a and retreat bed_a_stone and is put back there. SCHEMA_VERSION and CONTENT_REVISION do not change (a new content revision would refuse old records).
-- ROBLOX-112: world-3 (the window in true proportion, the eaves raised, the kitchen): a rest kept under world-2 is put back at its region's spawn the same way, and a
-- rest under the toaster on the kitchen's counter records region kitchen_counter and retreat kitchen_toaster.
-- ROBLOX-96: the prey is per region. The `prey` root is still the sill's director, byte for byte what it was (an old record, sill-only prey, restores unchanged);
-- the regions outside are an optional `garden` root, { [regionId] = { prey = a PreyDirector?, bugs = a Woodlice? } } (Prey/PreyWorld's table), recorded when the
-- world has one and checked like the sill's: every fly in a known state with a meal inside its own profile's, every held perch held by a living fly, the woodlice
-- inside their region. A record without one leaves the live garden as it is (nothing rerolls); one with a region the map lacks is refused.
-- ROBLOX-101: a region's entry may hold `kinds`, the bestiary's directors by kind ({ [kind] = director }), checked as W3's director is; the wall and the outer
-- sill may now be named (they have bestiary prey). The new profiles are kept by name (springtailProfile ... craneFlyDuskProfile) and a hopper in the air is in
-- the state HOP. A W3 record (its bed with gnats, aphids and woodlice alone) restores unchanged; the bestiary's directors it lacks are made afresh from their
-- seeds when their region is next whole (Prey/PreyWorld.kinds), so nothing is rerolled that the record had. SCHEMA_VERSION, CONTENT_REVISION and the
-- world's revision stay as they were (W3's precedent: an optional part an old record lacks needs none of them).
-- ROBLOX-105: a region's entry may hold `ambient`, the ambient bugs' colonies by kind ({ ladybird = Ladybirds, millipede = Millipedes, snail = Snails,
-- harvestman = Harvestmen }), each of the kind the region has and in order (its creatures in known states inside the region's bounds). A record without it (every
-- rest before this round) restores unchanged and the colonies it lacks are made afresh from their seeds when their region is next whole (Prey/PreyWorld.ambient).
-- ROBLOX-106: the life may hold `cold_day` (the morning a night out in the garden left cold, Life/Nature), the rival `camp` (its watch by the crack), the mate its
-- courtship's record and the rival's level (`court_*`, `cut`) and the mating its counters (`courts`, `rejections`, `cut_ins`): all optional, absent in every record
-- before, checked when present.

local Species = require(script.Parent.Parent.Data.Species)
local ObjectRecord = require(script.Parent.ObjectRecord)
local Fly = require(script.Parent.Parent.Prey.Fly)
local FlyFlight = require(script.Parent.Parent.Prey.FlyFlight)
local FlySenses = require(script.Parent.Parent.Prey.FlySenses)
local PreyRandom = require(script.Parent.Parent.Prey.PreyRandom)
local PreyPopulation = require(script.Parent.Parent.Prey.PreyPopulation)
local PerchGraph = require(script.Parent.Parent.Prey.PerchGraph)
local Feeding = require(script.Parent.Parent.Prey.Feeding)
local PreyDirector = require(script.Parent.Parent.Prey.PreyDirector)
local Sensor = require(script.Parent.Parent.Perception.Sensor)
local SensorCore = require(script.Parent.Parent.Perception.SensorCore)
local ObservationMemory = require(script.Parent.Parent.Perception.ObservationMemory)
local Observation = require(script.Parent.Parent.Perception.Observation)
local NeedsModel = require(script.Parent.Parent.Life.NeedsModel)
local LifeLoop = require(script.Parent.Parent.Life.LifeLoop)
local LifeClock = require(script.Parent.Parent.Life.LifeClock)
local Growth = require(script.Parent.Parent.Life.Growth)
local WorldMap = require(script.Parent.Parent.World.WorldMap)
local WaspDirector = require(script.Parent.Parent.Predator.WaspDirector)
local Cat = require(script.Parent.Parent.Predator.Cat)
local Woodlice = require(script.Parent.Parent.Prey.Woodlouse)
local Ladybirds = require(script.Parent.Parent.Prey.Ladybird)
local Millipedes = require(script.Parent.Parent.Prey.Millipede)
local Snails = require(script.Parent.Parent.Prey.Snail)
local Harvestmen = require(script.Parent.Parent.Prey.Harvestman)
local Ants = require(script.Parent.Parent.Prey.Ant) -- (ROBLOX-119: the meadow's ants)
local Garden = require(script.Parent.Parent.World.Garden)

local RivalSpider = require(script.Parent.Parent.Predator.RivalSpider)
local Mate = require(script.Parent.Parent.Predator.Mate)
local Mating = require(script.Parent.Parent.Life.Mating)
local Breakaway = require(script.Parent.Parent.Habitat.Breakaway)
local Nature = require(script.Parent.Parent.Life.Nature)
local Checkpoint = {}

Checkpoint.SCHEMA_VERSION = 3
Checkpoint.KIND = "retreat_checkpoint"
Checkpoint.GAME = "the-windowsill-roblox"
-- Changes whenever the windowsill's pieces or perches change in a way an old checkpoint could not be put back into.
Checkpoint.CONTENT_REVISION = "windowsill-roblox-1"
Checkpoint.STILL_SPEED = 0.15
Checkpoint.ROOTS = { "prey", "sensor", "memory", "needs", "life" }

-- The classes a world record may hold.
Checkpoint.CLASSES = {
	Fly = Fly, FlyFlight = FlyFlight, FlySenses = FlySenses, PreyRandom = PreyRandom, PreyPopulation = PreyPopulation,
	PerchGraph = PerchGraph, Feeding = Feeding, PreyDirector = PreyDirector, Woodlice = Woodlice,
	Ladybirds = Ladybirds, Millipedes = Millipedes, Snails = Snails, Harvestmen = Harvestmen, -- (ROBLOX-105)
	Ants = Ants, -- (ROBLOX-119)
	Sensor = Sensor, SensorCore = SensorCore, ObservationMemory = ObservationMemory, Contact = ObservationMemory.Contact,
	Observation = Observation,
	NeedsModel = NeedsModel, LifeLoop = LifeLoop, LifeClock = LifeClock, Growth = Growth,
}

-- What the world is made of that a record keeps by name instead of copying (see ObjectRecord). The same function names them
-- when a record is made and when it is put back, so a name always means this world's own thing.
export type World = {
	motor: any, prey: any, sensor: any, memory: any, needs: any, life: any,
	breakaway: any?,
	wasp: any?, -- the WaspDirector (nil: no wasp in this world)
	cat: any?, -- (ROBLOX-118) the ranger's cat, Predator/Cat (nil: no cat in this world: the test garden)
	garden: { [string]: any }?, -- ROBLOX-96: the regions' prey and bugs outside the sill (Prey/PreyWorld's table; nil: a world of the sill alone)
	extraRefs: { [string]: any }?, -- anything else the world's state points at that the record should keep by name
}

function Checkpoint.refs(world: World): { [string]: any }
	local refs: { [string]: any } = {}
	local prey = world.prey
	ObjectRecord.constants("flyProfile", prey.p, refs)
	ObjectRecord.constants("fruitFlyProfile", Species.fruit_fly_prototype, refs)
	ObjectRecord.constants("gnatProfile", Species.fungus_gnat_prototype, refs) -- (ROBLOX-96: the bed's prey)
	ObjectRecord.constants("aphidProfile", Species.aphid_prototype, refs)
	-- (ROBLOX-101: the bestiary's prey, by day and from dusk)
	for _, pair in { { "springtailProfile", Species.springtail_prototype }, { "leafhopperProfile", Species.leafhopper_prototype }, { "mothProfile", Species.moth_prototype },
		{ "mothDuskProfile", Species.moth_dusk_prototype }, { "craneFlyProfile", Species.crane_fly_prototype }, { "craneFlyDuskProfile", Species.crane_fly_dusk_prototype },
		{ "hoverflyProfile", Species.hoverfly_prototype } } :: { { any } } do -- (ROBLOX-117: the hut garden's hoverflies)
		local name: string, profile: any = pair[1], pair[2]
		ObjectRecord.constants(name, profile, refs)
	end
	local g = prey.graph
	refs["graph.cast"], refs["graph.sweep"], refs["graph.overlap"] = g.cast, g.sweep, g.overlap
	if prey.probe ~= nil then refs["prey.probe"] = prey.probe end
	if world.life.save ~= nil then refs["life.save"] = world.life.save end
	local m = world.memory
	for _, k in { "contactAcquired", "categoryChanged", "contactLost", "contactReacquired", "contactEnded" } do
		if m[k] ~= nil then refs["memory." .. k] = m[k] end
	end
	local core = world.sensor.core
	if core and core.cueEmitted ~= nil then refs["sensor.cueEmitted"] = core.cueEmitted end
	if world.needs.onEnergyChanged ~= nil then refs["needs.onEnergyChanged"] = world.needs.onEnergyChanged end
	local extra: { [string]: any } = world.extraRefs or {}
	for k, v in extra do refs[k] = v end
	return refs
end

local function liveRoots(world: World): { [string]: any }
	local roots: { [string]: any } = { prey = world.prey, sensor = world.sensor, memory = world.memory, needs = world.needs, life = world.life }
	if world.garden ~= nil then roots.garden = world.garden end
	return roots
end

local function v3(v: Vector3): { number }
	return { v.X, v.Y, v.Z }
end

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function vec(t: any): Vector3?
	if type(t) ~= "table" or #t ~= 3 or not finite(t[1]) or not finite(t[2]) or not finite(t[3]) then return nil end
	return Vector3.new(t[1], t[2], t[3])
end

-- The world record of a checkpoint with the defaults of a record from before there was a world: the default world's seed, the first revision of the world
-- (WorldMap.FIRST_REVISION, ROBLOX-95: such a rest was kept on the sill before its back frame opened, so it is put back at the spawn like any rest from
-- world-1), the sill, the retreat the player block names, no changes. Returns it and what is wrong with a record that has one (an empty list for a good one or
-- an old one).
-- ROBLOX-115: `world`, the world the rest was kept in (World/Worlds), written only outside the test garden: a record without it (every rest before, and every rest
-- kept in the test garden, byte for byte as before) is the test garden's. A rest from another world than the one running is put back where a life begins here.
export type MapRecord = { seed: number, revision: string, region: string, retreat: string, diffs: { any }, world: string }
local function mapRecord(record: any): (MapRecord, { string })
	local problems: { string } = {}
	local p = record.player
	local out: MapRecord = {
		seed = WorldMap.SEED, revision = WorldMap.FIRST_REVISION, region = WorldMap.HOME, diffs = {}, world = "test_garden",
		retreat = if type(p) == "table" and type(p.retreat_id) == "string" then p.retreat_id else "",
	}
	local m = record.world_map
	if m == nil then return out, problems end
	local function bad(t: string) table.insert(problems, t) end
	if type(m) ~= "table" then
		bad("world: the place in the world is not a record")
		return out, problems
	end
	if not finite(m.seed) or m.seed < 0 or m.seed > 4294967295 or m.seed % 1 ~= 0 then bad("world: the world's seed is not a whole number") else out.seed = m.seed end
	if type(m.revision) ~= "string" or #m.revision < 1 or #m.revision > 64 then bad("world: the world's revision is not a name") else out.revision = m.revision end
	if type(m.region) ~= "string" then
		bad("world: the region is not a name")
	else
		out.region = m.region
	end
	if type(m.retreat) ~= "string" then bad("world: the retreat is not a name") else out.retreat = m.retreat end
	if m.world ~= nil then
		if type(m.world) ~= "string" or #m.world < 1 or #m.world > 64 then bad("world: the world is not a name") else out.world = m.world end
	end
	if type(m.diffs) ~= "table" or getmetatable(m.diffs) ~= nil then
		bad("world: the changes to the world are not a list")
	elseif next(m.diffs) ~= nil then
		bad("world: the world has changes this game does not know (nothing in it can change yet)") -- later entries are { kind, region, id, data }, each kind with its own check
	end
	return out, problems
end

-- Whether a rest was kept in another world than this game's (another revision of it, or another seed): its position is not to be trusted.
function Checkpoint.worldMoved(record: any): boolean
	local map = mapRecord(record)
	return map.world ~= WorldMap.world() or map.revision ~= WorldMap.revision() or map.seed ~= WorldMap.SEED
end

-- Whether a rest was kept in another world than the one running (ROBLOX-115): its region and retreat are that world's, not looked for here.
local function otherWorld(record: any): boolean
	return mapRecord(record).world ~= WorldMap.world()
end

local function hasRetreat(region: WorldMap.Region, id: string): boolean
	for _, t in region.retreats do
		if t.id == id then return true end
	end
	return false
end

-- Why a checkpoint cannot be made of the world now; "" when it can.
function Checkpoint.boundaryProblem(world: World): string
	local motor, prey = world.motor, world.prey
	if motor.mode ~= "attached" or motor.preparing then return "the spider is not standing on a surface" end
	if motor.vel.Magnitude > Checkpoint.STILL_SPEED then return "the spider is moving" end
	if world.life.rival and world.life.rival.state=="captured" then
		return if world.life.rival.subdued == false then "the rival in the jaws is still struggling" else "the spider is eating its rival"
	end
	-- ROBLOX-89: the mating scene is playing (the pause together, and a male mate's walk off the sill that ends it): no rest is kept inside it.
	if world.life.mate and world.life.mate.scene == true then return "the two spiders are together" end
	-- ROBLOX-79: the brood is out and the ending is the player's to take; a rest here would keep a family that has already hatched.
	if world.life.mating and world.life.mating.stage == "hatched" then return "the brood is hatching" end
	if prey.feeding.feeding then return "the spider is feeding" end
	if prey.feeding.struggling then return "the prey in the jaws is still struggling" end
	if prey.tick <= prey.strikeEnd then return "a strike is still in progress" end
	return ""
end

-- The checkpoint record of the world as it is now (call boundaryProblem first). Nil and the reason if something in the world
-- could not be recorded (a field this file does not know how to keep; the tests make sure there is none).
function Checkpoint.capture(world: World, createdAt: number?): ({ [string]: any }?, string?)
	local motor = world.motor
	-- (the live windows are put aside for the capture and put straight back)
	local prey, sensor = world.prey, world.sensor
	local cpu, ring = prey.cpu, sensor._ring
	if cpu ~= nil then prey.cpu = {} end
	if ring ~= nil then sensor._ring = {} end
	local gardenCpu: { [any]: any } = {}
	for _, entry in (world.garden or {}) :: { [string]: any } do
		if type(entry) == "table" and entry.prey ~= nil and entry.prey.cpu ~= nil then gardenCpu[entry.prey] = entry.prey.cpu; entry.prey.cpu = {} end
		if type(entry) == "table" and type(entry.kinds) == "table" then
			for _, d in entry.kinds do if type(d) == "table" and d.cpu ~= nil then gardenCpu[d] = d.cpu; d.cpu = {} end end
		end
	end
	local graph, why = ObjectRecord.capture(liveRoots(world), Checkpoint.CLASSES, Checkpoint.refs(world))
	if cpu ~= nil then prey.cpu = cpu end
	if ring ~= nil then sensor._ring = ring end
	for d, window in gardenCpu do d.cpu = window end
	if not graph then return nil, why end
	local region = WorldMap.at(motor.pos) or WorldMap.region(WorldMap.HOME) :: WorldMap.Region
	local retreat = WorldMap.inRetreat(motor.pos) or ""
	return {
		schema_version = Checkpoint.SCHEMA_VERSION, kind = Checkpoint.KIND, game = Checkpoint.GAME,
		content_revision = Checkpoint.CONTENT_REVISION, created_at = createdAt or 0, snapshot_tick = world.prey.tick,
		player = {
			position = v3(motor.pos), normal = v3(motor.up), heading = v3(motor.heading), gaze_pitch = motor.gazePitch,
			retreat_id = retreat, state = "ATTACHED",
		},
		world_map = { seed = WorldMap.SEED, revision = WorldMap.revision(), region = region.id, retreat = retreat, diffs = {},
			world = if WorldMap.world() == "test_garden" then nil else WorldMap.world() },
		world = graph,
		life_rules = { mode = world.life.mode or "main", rules = world.life.rules or "standard" },
		breakaway = if world.breakaway then world.breakaway:record() else nil,
		wasp = if world.wasp ~= nil then world.wasp:toRecord() else nil,
		cat = if world.cat ~= nil then world.cat:toRecord() else nil, -- (ROBLOX-118: optional; a test garden rest has none)
	}, nil
end

-- The checks on the rebuilt (fresh, not live) world: what a good world must be.
local function checkWorld(roots: { [string]: any }, problems: { string })
	local function bad(t: string) table.insert(problems, t) end
	for _, name in Checkpoint.ROOTS do
		if type(roots[name]) ~= "table" then bad(`world: no {name}`) end
	end
	if #problems > 0 then return end
	local prey, needs, life, sensor, memory = roots.prey, roots.needs, roots.life, roots.sensor, roots.memory
	if getmetatable(prey) ~= PreyDirector then bad("world: the prey is not a prey director") end
	if getmetatable(needs) ~= NeedsModel then bad("world: the needs are not a needs model") end
	if getmetatable(life) ~= LifeLoop then bad("world: the life is not a life loop") end
	if getmetatable(sensor) ~= Sensor then bad("world: the sensor is not a sensor") end
	if getmetatable(memory) ~= ObservationMemory then bad("world: the memory is not an observation memory") end
	if #problems > 0 then return end
	-- The reserves and their books (NeedsModel's own record check).
	local scratch = NeedsModel.new()
	local ok, rec = pcall(function() return NeedsModel.toRecord(needs) end)
	if not ok or not scratch:load(rec) then bad("needs: the reserves or their books are not valid") end
	-- One needs model: the one feeding grants to is the one the life loop reports hours to.
	if prey.feeding == nil or prey.feeding.needs ~= needs or life.needs ~= needs then bad("needs: feeding and the life loop do not share the reserves") end
	-- The clock and the rest.
	for _, p in LifeClock.problems(if type(life.clock) == "table" then LifeClock.toRecord(life.clock) else nil) do bad(p) end
	if getmetatable(life.clock) ~= LifeClock then bad("life: the clock is not a life clock") end
	if getmetatable(life.growth) ~= Growth then bad("growth: missing growth state")
 else
  for _,p in Growth.problems(life.growth:toRecord()) do bad(p) end
  if life.growth:isMoulting() and not life.resting then bad("growth: moult outside rest") end
 end
 if not finite(life.grantedSeen) or life.grantedSeen<0 or life.grantedSeen>needs.grantedTotal+1e-6 then bad("growth: invalid food ledger cursor") end
 if not RivalSpider.valid(life.rival) then bad("life: invalid rival state") end
 -- ROBLOX-79: the mate, the mating cycle and the generation. All three are missing in a record from before (a life with no mate, stage none, generation 0).
 if not Mate.valid(life.mate) then bad("life: invalid mate state") end
 for _, text in Mating.problemsWith(life.mating, life.mate) do bad(text) end
 if not Nature.validCold(life.cold_day) then bad("life: invalid cold morning") end -- (ROBLOX-106: optional, set by a night out in the garden)
 if life.generation ~= nil and not (finite(life.generation) and life.generation >= 0 and life.generation <= 1e6 and life.generation % 1 == 0) then bad("life: invalid generation") end
 -- ROBLOX-91: where this generation's grace began (Mating.grace); absent in a record from before (the first generation's: the sill's own day and meals).
 for _, k in { "born", "mealsBase" } do
  local v = life[k]
  if v ~= nil and not (finite(v) and v >= 0 and v <= 1e9 and v % 1 == 0) then bad("life: invalid " .. k) end
 end
 if type(life.resting) ~= "boolean" then bad("life: 'resting' is not true or false") end
	-- The flies: unique ids, a known state, finite places, a meal no bigger than the profile's (ROBLOX-96: each profile's own; the fruit fly's was special-cased
	-- before), perches held only by flies that exist. The same checks for each region's director outside (the `garden` root); `ids` is every fly of the world.
	local every: { [any]: boolean } = {} -- every fly of the world, by identity
	local states = { PERCHED = true, ALERT = true, TAKEOFF = true, FLEE = true, SEEK_PERCH = true, REPOSITION = true, CAPTURED = true, CONSUMED = true, HOP = true }
	local function checkFlies(director: any, label: string): boolean
		if type(director.flies) ~= "table" then
			bad(`{label}: no list of flies`)
			return false
		end
		local ids: { [string]: any } = {}
		for i, f in director.flies do
			if getmetatable(f) ~= Fly or type(f.id) ~= "string" then
				bad(`{label}: fly {i} is not a fly`)
				continue
			end
			if ids[f.id] then bad(`{label}: two flies called {f.id}`) end
			ids[f.id] = f
			every[f] = true
			if not states[f.state] then bad(`{label}: {f.id} is in no known state`) end
			if typeof(f.position) ~= "Vector3" and type(f.position) ~= "table" then bad(`{label}: {f.id} has no position`) end
			if type(f.profile) ~= "table" or type(f.profile.body) ~= "table" or not finite(f.profile.body.nutrition) then bad(`{label}: {f.id} has no profile`)
			elseif not finite(f.nutrition) or f.nutrition < 0 or f.nutrition > f.profile.body.nutrition + 1e-9 then bad(`{label}: {f.id}'s nutrition is out of range`) end
			if f.flight == nil or f.flight.fly ~= f then bad(`{label}: {f.id}'s flight is not its own`) end
		end
		if type(director.graph) == "table" and type(director.graph.perches) == "table" then
			for _, p in director.graph.perches do
				if p.occupant ~= "" and (ids[p.occupant] == nil or not ids[p.occupant]:alive()) then bad(`{label}: perch {p.id} is held by {p.occupant}, which is not a living fly`) end
				if p.reserved ~= "" and ids[p.reserved] == nil then bad(`{label}: perch {p.id} is reserved by {p.reserved}, which is not a fly`) end
			end
		else
			bad(`{label}: no perches`)
		end
		return true
	end
	if not checkFlies(prey, "prey") then return end
	-- ROBLOX-96: the regions outside. Each a region of the map with prey of its own, its director a director sharing the jaws, its woodlice inside the region.
	local garden = roots.garden
	if garden ~= nil then
		if type(garden) ~= "table" or getmetatable(garden) ~= nil then
			bad("garden: not a record of regions")
		else
			for id, entry in garden do
				local region = if type(id) == "string" then WorldMap.region(id) else nil
				local kinds = if region ~= nil then Garden.bestiary(region) else nil
				-- (ROBLOX-116: or with woodlice or ambient bugs alone, as the hut garden's lawn has)
				if region == nil or (Garden.prey(region) == nil and kinds == nil and Garden.bugs(region) == nil and Garden.ambient(region) == nil) then bad(`garden: {tostring(id)} is not a region with prey`); continue end
				if type(entry) ~= "table" or getmetatable(entry) ~= nil then bad(`garden: {id} is not a record`); continue end
				if entry.prey ~= nil then
					if getmetatable(entry.prey) ~= PreyDirector then bad(`garden: {id}'s prey is not a prey director`)
					else
						if entry.prey.feeding ~= prey.feeding then bad(`garden: {id}'s prey does not eat with the sill's jaws`) end
						checkFlies(entry.prey, `garden {id}`)
					end
				end
				if entry.prey ~= nil and Garden.prey(region) == nil then bad(`garden: {id} has no prey of the bed's kind`) end
				-- ROBLOX-101: the bestiary's directors, one per kind the region has
				if entry.kinds ~= nil then
					if type(entry.kinds) ~= "table" or getmetatable(entry.kinds) ~= nil then bad(`garden: {id}'s kinds are not a record`)
					else
						local known: { [string]: boolean } = {}
						for _, k in (kinds or {}) :: { any } do known[k.kind] = true end
						for kind, d in entry.kinds do
							if type(kind) ~= "string" or not known[kind] then bad(`garden: {id} has no prey of the kind {tostring(kind)}`)
							elseif getmetatable(d) ~= PreyDirector then bad(`garden: {id}'s {kind} is not a prey director`)
							else
								if d.feeding ~= prey.feeding then bad(`garden: {id}'s {kind} does not eat with the sill's jaws`) end
								checkFlies(d, `garden {id} {kind}`)
							end
						end
					end
				end
				if entry.bugs ~= nil then
					if getmetatable(entry.bugs) ~= Woodlice then bad(`garden: {id}'s bugs are not woodlice`)
					else for _, text in entry.bugs:problems(region.bounds[1], region.bounds[2]) do bad(`garden: {id}: {text}`) end end
				end
				-- ROBLOX-105: the ambient bugs' colonies, one per kind the region has, each of its kind's class
				if entry.ambient ~= nil then
					if type(entry.ambient) ~= "table" or getmetatable(entry.ambient) ~= nil then bad(`garden: {id}'s ambient bugs are not a record`)
					else
						local known: { [string]: boolean } = {}
						for _, a in (Garden.ambient(region) or {}) :: { any } do known[a.kind] = true end
						local classes = { ladybird = Ladybirds, millipede = Millipedes, snail = Snails, harvestman = Harvestmen, ant = Ants } :: { [string]: any }
						for kind, c in entry.ambient do
							if type(kind) ~= "string" or not known[kind] then bad(`garden: {id} has no ambient bug of the kind {tostring(kind)}`)
							elseif getmetatable(c) ~= classes[kind] then bad(`garden: {id}'s {kind} is not a colony of its kind`)
							else for _, text in c:problems(region.bounds[1], region.bounds[2]) do bad(`garden: {id}: {text}`) end end
						end
					end
				end
			end
		end
	end
	-- The meal in the jaws.
	local held = prey.feeding.held
	if held ~= nil then
		if not every[held] or held.state ~= "CAPTURED" then bad("feeding: the prey in the jaws is not a caught fly of this world") end
	end
	local sum = 0
	for _, g in prey.feeding.ledger do
		if not finite(g) or g < 0 then bad("feeding: a meal's energy is not a number") end
		sum += if finite(g) then g else 0
	end
	if math.abs(sum - prey.feeding.granted) > 1e-6 then bad("feeding: the meals' energy does not add up") end
	if prey.feeding.granted > needs.grantedTotal + 1e-6 then bad("feeding: more energy was eaten than the reserves were given") end
end

-- Every problem with `record` (an empty list for a good one), and the rebuilt world when it is good. Nothing live changes.
function Checkpoint.check(record: any, world: World): ({ string }, ObjectRecord.Decoded?)
	local problems: { string } = {}
	local function bad(t: string) table.insert(problems, t) end
	if type(record) ~= "table" then return { "not a checkpoint" }, nil end
	local sv = record.schema_version
	if not finite(sv) or sv ~= math.floor(sv) or sv < 1 then
		return { "the schema version is not a whole number" }, nil
	end
	if sv > Checkpoint.SCHEMA_VERSION then
		return { `made by a newer version of the game (schema {sv}; this one reads up to {Checkpoint.SCHEMA_VERSION})` }, nil
	end
	if record.kind ~= Checkpoint.KIND then bad("not a retreat checkpoint") end
	if record.game ~= Checkpoint.GAME then bad("not a checkpoint of this game") end
	if record.content_revision ~= Checkpoint.CONTENT_REVISION then bad(`made for another windowsill ({tostring(record.content_revision)})`) end
	if not finite(record.snapshot_tick) or record.snapshot_tick < 0 then bad("the tick is not a number") end
	-- ROBLOX-94: which region the rest was kept in, and whether this is the world it was kept in.
	local map, mapProblemList = mapRecord(record)
	for _, text in mapProblemList do bad(text) end
	local elsewhere = otherWorld(record)
	local region = if elsewhere then nil else WorldMap.region(map.region)
	if #mapProblemList == 0 and region == nil and not elsewhere then bad("the spider is in a region this world does not have") end
	local moved = Checkpoint.worldMoved(record)
	if region ~= nil and #mapProblemList == 0 and map.retreat ~= "" and not hasRetreat(region, map.retreat) then bad("the spider is in an unknown retreat") end
	local p = record.player
	if type(p) ~= "table" then
		bad("no spider")
	else
		local pos, n, h = vec(p.position), vec(p.normal), vec(p.heading)
		if not pos then bad("the spider has no position")
		elseif region ~= nil and not moved and not WorldMap.inBounds(pos, region.id) then
			bad(if region.id == WorldMap.HOME then "the spider is outside the windowsill" else `the spider is outside {region.id}`) -- (a rest from another world is put back at the spawn: its position is not tested)
		end
		if not n or math.abs(n.Magnitude - 1) > 1e-3 then bad("the spider's surface normal is not a unit vector") end
		if not h or math.abs(h.Magnitude - 1) > 1e-3 then bad("the spider's heading is not a unit vector") end
		if not finite(p.gaze_pitch) or math.abs(p.gaze_pitch) > math.pi / 2 then bad("the spider's gaze is not a number") end
		if p.state ~= "ATTACHED" then bad("the spider is not standing on a surface") end
		if p.retreat_id ~= "" and (type(p.retreat_id) ~= "string" or (region ~= nil and not hasRetreat(region, p.retreat_id)) or (region == nil and not elsewhere and WorldMap.retreat(p.retreat_id) == nil)) then bad("the spider is in an unknown retreat") end
		-- The player block's retreat and the world record's are one answer written twice (capture writes both from the same lookup); a record where they differ was not made by a capture.
		if type(record.world_map) == "table" and #mapProblemList == 0 and p.retreat_id ~= map.retreat then bad("the spider's retreat and the world record's retreat disagree") end
	end
	if not Breakaway.valid(record.breakaway) then bad("invalid falling leaf state") end
	local rules = record.life_rules
	if record.schema_version >= 2 and rules == nil then bad("missing life rules") end
	if rules ~= nil and (type(rules) ~= "table" or (rules.mode ~= "main" and rules.mode ~= "free") or (rules.rules ~= "standard" and rules.rules ~= "gentle") or (rules.mode == "free" and rules.rules ~= "gentle")) then bad("invalid life rules") end
	if record.wasp ~= nil then
		for _, text in WaspDirector.problems(record.wasp) do bad(text) end
	end
	if record.cat ~= nil then
		for _, text in Cat.problems(record.cat) do bad(text) end
	end
	if #problems > 0 then return problems, nil end
	local decoded, why = ObjectRecord.decode(record.world, Checkpoint.CLASSES, Checkpoint.refs(world))
	if not decoded then
		for _, w in why do bad("world: " .. w) end
		return problems, nil
	end
	local roots = decoded.roots
 -- Schemas 1/2 had no growth. Migrate only old records; never repair a damaged schema 3 record.
 if sv < 3 and type(roots.life)=="table" and type(roots.needs)=="table" then
  if roots.life.growth == nil then roots.life.growth=Growth.new() end
  if roots.life.grantedSeen == nil then roots.life.grantedSeen=roots.needs.grantedTotal end
 end
	local ok: boolean, err: any = (pcall :: any)(checkWorld, roots, problems)
	if not ok then bad("world: " .. tostring(err)) end
	if #problems > 0 then return problems, nil end
	return problems, decoded
end

-- Puts the world back as the record has it, or changes nothing. Returns true, or false and the problems.
-- The caller then lets go of anything the motor or the screen held (aims, lines, the camera); SpiderMotor.place already
-- ends every line, aim and walk.
function Checkpoint.restore(record: any, world: World): (boolean, { string })
	local problems, decoded = Checkpoint.check(record, world)
	if not decoded then return false, problems end
	local p = record.player
	local pos, n, h = vec(p.position) :: Vector3, vec(p.normal) :: Vector3, vec(p.heading) :: Vector3
	if not ObjectRecord.commit(decoded, liveRoots(world)) then
		return false, { "the live world is missing a part" }
	end
	-- The profiling windows are not in the record (an older one holds them): empty, and the sensor's window begins now.
	world.prey.cpu = {}
	world.sensor._ring = {}
	for _, entry in (world.garden or {}) :: { [string]: any } do
		if type(entry) == "table" and entry.prey ~= nil then entry.prey.cpu = {} end
		if type(entry) == "table" and type(entry.kinds) == "table" then for _, d in entry.kinds do d.cpu = {} end end
	end
	-- ROBLOX-94: a rest from another world than this game's is put back at its region's spawn; its position was kept for geometry that may have moved.
	local moved = Checkpoint.worldMoved(record)
	if moved then
		local home = WorldMap.region(WorldMap.HOME) :: WorldMap.Region
		local at = (if otherWorld(record) then home else WorldMap.region(mapRecord(record).region) or home).spawn
		world.motor:respawn(at.pos, at.heading)
	else
		world.motor:place(pos, n.Unit, h.Unit)
		world.motor.gazePitch = p.gaze_pitch
	end
	if world.breakaway then world.breakaway:apply(record.breakaway) end
	if world.wasp ~= nil then world.wasp:load(record.wasp or WaspDirector.defaultRecord()) end
	if world.cat ~= nil then world.cat:load(record.cat or Cat.defaultRecord()) end -- (ROBLOX-118: a rest without one is a cat that has not met this spider)
	-- Godot's apply_record: the rest that was going on goes on, the spider takes a moment to take hold, and the screen says
	-- this is checkpoint recovery. What was owed or announced at that tick is not done again.
	local life = world.life
	local rules = record.life_rules or {mode="main",rules="standard"}
	life.mode, life.rules, life.lifeOver = rules.mode, rules.rules, false
	world.needs.gentle = rules.rules == "gentle"
	if world.wasp then world.wasp.gentle = world.needs.gentle end
	life.asleep = false
	life.checkpointDue = false
	life.morningText = ""
	life.events = {}
	life.restoreGrace = LifeLoop.RESTORE_GRACE_TICKS
	life:applyLight()
	life:showNotice(if moved then "Returned to your last rest, but the world has changed since you rested, so you stand where a life begins in it. Everything else is as you left it."
		else "Returned to your last rest: the sill as it was when you rested in the crack. This is a return to the rest, not an exact resume.")
	return true, {}
end

return Checkpoint
