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
local Layout = require(script.Parent.Parent.Habitat.WindowsillLayout)
local WaspDirector = require(script.Parent.Parent.Predator.WaspDirector)

local RivalSpider = require(script.Parent.Parent.Predator.RivalSpider)
local Breakaway = require(script.Parent.Parent.Habitat.Breakaway)
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
	PerchGraph = PerchGraph, Feeding = Feeding, PreyDirector = PreyDirector,
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
	extraRefs: { [string]: any }?, -- anything else the world's state points at that the record should keep by name
}

function Checkpoint.refs(world: World): { [string]: any }
	local refs: { [string]: any } = {}
	local prey = world.prey
	ObjectRecord.constants("flyProfile", prey.p, refs)
	ObjectRecord.constants("fruitFlyProfile", Species.fruit_fly_prototype, refs)
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
	return { prey = world.prey, sensor = world.sensor, memory = world.memory, needs = world.needs, life = world.life }
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

-- Why a checkpoint cannot be made of the world now; "" when it can.
function Checkpoint.boundaryProblem(world: World): string
	local motor, prey = world.motor, world.prey
	if motor.mode ~= "attached" or motor.preparing then return "the spider is not standing on a surface" end
	if motor.vel.Magnitude > Checkpoint.STILL_SPEED then return "the spider is moving" end
	if world.life.rival and world.life.rival.state=="captured" then
		return if world.life.rival.subdued == false then "the rival in the jaws is still struggling" else "the spider is eating its rival"
	end
	if prey.feeding.feeding then return "the spider is feeding" end
	if prey.feeding.struggling then return "the prey in the jaws is still struggling" end
	if prey.tick <= prey.strikeEnd then return "a strike is still in progress" end
	return ""
end

-- The checkpoint record of the world as it is now (call boundaryProblem first). Nil and the reason if something in the world
-- could not be recorded (a field this file does not know how to keep; the tests make sure there is none).
function Checkpoint.capture(world: World, createdAt: number?): ({ [string]: any }?, string?)
	local motor = world.motor
	local graph, why = ObjectRecord.capture(liveRoots(world), Checkpoint.CLASSES, Checkpoint.refs(world))
	if not graph then return nil, why end
	return {
		schema_version = Checkpoint.SCHEMA_VERSION, kind = Checkpoint.KIND, game = Checkpoint.GAME,
		content_revision = Checkpoint.CONTENT_REVISION, created_at = createdAt or 0, snapshot_tick = world.prey.tick,
		player = {
			position = v3(motor.pos), normal = v3(motor.up), heading = v3(motor.heading), gaze_pitch = motor.gazePitch,
			retreat_id = if Layout.inRetreat(motor.pos) then "sill_crevice" else "", state = "ATTACHED",
		},
		world = graph,
		life_rules = { mode = world.life.mode or "main", rules = world.life.rules or "standard" },
		breakaway = if world.breakaway then world.breakaway:record() else nil,
		wasp = if world.wasp ~= nil then world.wasp:toRecord() else nil,
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
 if type(life.resting) ~= "boolean" then bad("life: 'resting' is not true or false") end
	-- The flies: unique ids, a known state, finite places, perches held only by flies that exist.
	if type(prey.flies) ~= "table" then
		bad("prey: no list of flies")
		return
	end
	local ids: { [string]: any } = {}
	local states = { PERCHED = true, ALERT = true, TAKEOFF = true, FLEE = true, SEEK_PERCH = true, REPOSITION = true, CAPTURED = true, CONSUMED = true }
	for i, f in prey.flies do
		if getmetatable(f) ~= Fly or type(f.id) ~= "string" then
			bad(`prey: fly {i} is not a fly`)
			continue
		end
		if ids[f.id] then bad(`prey: two flies called {f.id}`) end
		ids[f.id] = f
		if not states[f.state] then bad(`prey: {f.id} is in no known state`) end
		if typeof(f.position) ~= "Vector3" and type(f.position) ~= "table" then bad(`prey: {f.id} has no position`) end
		if not finite(f.nutrition) or f.nutrition < 0 or f.nutrition > (if f.profile==Species.fruit_fly_prototype then .18 else f.profile.body.nutrition) + 1e-9 then bad(`prey: {f.id}'s nutrition is out of range`) end
		if f.flight == nil or f.flight.fly ~= f then bad(`prey: {f.id}'s flight is not its own`) end
	end
	if type(prey.graph) == "table" and type(prey.graph.perches) == "table" then
		for _, p in prey.graph.perches do
			if p.occupant ~= "" and (ids[p.occupant] == nil or not ids[p.occupant]:alive()) then bad(`prey: perch {p.id} is held by {p.occupant}, which is not a living fly`) end
			if p.reserved ~= "" and ids[p.reserved] == nil then bad(`prey: perch {p.id} is reserved by {p.reserved}, which is not a fly`) end
		end
	else
		bad("prey: no perches")
	end
	-- The meal in the jaws.
	local held = prey.feeding.held
	if held ~= nil then
		if ids[held.id] ~= held or held.state ~= "CAPTURED" then bad("feeding: the prey in the jaws is not a caught fly of this world") end
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
	local p = record.player
	if type(p) ~= "table" then
		bad("no spider")
	else
		local pos, n, h = vec(p.position), vec(p.normal), vec(p.heading)
		if not pos then bad("the spider has no position")
		elseif pos.X < Layout.PLAY_BOUNDS_MIN.X or pos.Y < Layout.PLAY_BOUNDS_MIN.Y or pos.Z < Layout.PLAY_BOUNDS_MIN.Z
			or pos.X > Layout.PLAY_BOUNDS_MAX.X or pos.Y > Layout.PLAY_BOUNDS_MAX.Y or pos.Z > Layout.PLAY_BOUNDS_MAX.Z then
			bad("the spider is outside the windowsill")
		end
		if not n or math.abs(n.Magnitude - 1) > 1e-3 then bad("the spider's surface normal is not a unit vector") end
		if not h or math.abs(h.Magnitude - 1) > 1e-3 then bad("the spider's heading is not a unit vector") end
		if not finite(p.gaze_pitch) or math.abs(p.gaze_pitch) > math.pi / 2 then bad("the spider's gaze is not a number") end
		if p.state ~= "ATTACHED" then bad("the spider is not standing on a surface") end
		if p.retreat_id ~= "" and p.retreat_id ~= "sill_crevice" then bad("the spider is in an unknown retreat") end
	end
	if not Breakaway.valid(record.breakaway) then bad("invalid falling leaf state") end
	local rules = record.life_rules
	if record.schema_version >= 2 and rules == nil then bad("missing life rules") end
	if rules ~= nil and (type(rules) ~= "table" or (rules.mode ~= "main" and rules.mode ~= "free") or (rules.rules ~= "standard" and rules.rules ~= "gentle") or (rules.mode == "free" and rules.rules ~= "gentle")) then bad("invalid life rules") end
	if record.wasp ~= nil then
		for _, text in WaspDirector.problems(record.wasp) do bad(text) end
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
	world.motor:place(pos, n.Unit, h.Unit)
	world.motor.gazePitch = p.gaze_pitch
	if world.breakaway then world.breakaway:apply(record.breakaway) end
	if world.wasp ~= nil then world.wasp:load(record.wasp or WaspDirector.defaultRecord()) end
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
	life:showNotice("Returned to the checkpoint: the sill as it was when you rested in the crack. This is checkpoint recovery, not an exact resume.")
	return true, {}
end

return Checkpoint
