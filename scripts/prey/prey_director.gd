extends Node3D
## PreyDirector: the prey side of the world (spec 8.3, 19.3, 20). It owns the shared fly profile, the perch graph, the flies and their
## seeded streams, the stable order they are stepped in, the clock they share, what the world offers a fly to look at, and the one place
## where a capture is decided. It decides nothing for a fly: each fly senses, chooses and flies for itself (Fly, FlyMind, FlyFlight).
## Order (spec 20): this node runs at priority -5, after the spider's sensor (-10) and before the spider moves (0), so every fly reads the
## world as the previous tick committed it; flies are stepped in id order. Captures are resolved after the spider has moved, by a second
## stage at priority +10, in id order, once.
## Capture (T07, A-028): a strike is a jump, from the moment the spider commits it until it ends (and a few ticks after, for the landing).
## During a strike every living fly is tested against the spider's body: the closest approach of the spider's path and the fly's path
## within this tick (exact for straight moves, PreyMath.sweep_closest) must be within the fly's capture radius plus the spider's body radius
## (times the assist scale when the player has asked for a wider reach), and nothing of the world may stand between them at that moment.
## What the spider has or has not classified is never read: a strike at something it has not even identified catches it just the same, and
## a fly it has identified is not caught unless the strike reaches it. A capture has a stable event id ("capture:<spider>:<prey>"), is
## recorded once, and has an owner; the prey becomes CAPTURED at that moment and the spider holds it. Nothing here grants energy: the only
## door to the reserves is the feeding (FeedingController -> NeedsModel). One prey is held at a time; a strike while the jaws are full
## catches nothing.
## Streams (spec 8.2): one seed gives every fly two streams of its own, a gameplay one and a cosmetic one; nothing the player does draws
## from any of them.

const PreyProfile = preload("res://scripts/prey/prey_profile.gd")
const PreyMath = preload("res://scripts/prey/prey_math.gd")
const PerchGraph = preload("res://scripts/prey/perch_graph.gd")
const Fly = preload("res://scripts/prey/fly.gd")
const FlyMind = preload("res://scripts/prey/fly_mind.gd")
const FlyFlight = preload("res://scripts/prey/fly_flight.gd")
const Population = preload("res://scripts/prey/prey_population.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")
const RecordMath = preload("res://scripts/persistence/record_math.gd")

const PROFILE_PATH := "res://data/species/fly_like_prototype.json"
const PRIORITY := -5
const LATE_PRIORITY := 10
const DEFAULT_SEED := 20261007
const SPIDER_RADIUS_FALLBACK := 0.3
const COST_RING := 1200
## Ticks after a flight ends in which the landing can still catch (the body is still settling onto the surface).
const STRIKE_GRACE_TICKS := 3
const STRIKE_MAX_TICKS := 240
const DEAD_KEPT := 6
const OWNER_ID := "spider"

signal fly_spawned(fly: Node3D)
## A capture was resolved (once per event id). The dictionary: id, tick, t, owner, prey, distance, reach, assisted, t_closest.
signal captured(event: Dictionary)
## T09b: the prey in the jaws tore free before it was subdued; its capture is undone (id, tick, t, prey, reason).
signal escaped(event: Dictionary)

## The spider (anything with a global_position; its radius comes from get_body_radius() when it has one) and the lab (perches, vents).
var spider: Node3D
var lab: Node3D
var profile: PreyProfile.Profile
var graph: PerchGraph = PerchGraph.new()
var flies: Array[Node3D] = []
var seed_value: int = DEFAULT_SEED
## How many flies the world keeps (spawn at start, replaced after a loss).
var target_population: int = 0
## Tests: false hides the spider from every fly (nothing to look at).
var stimulus_enabled: bool = true
## The player asked for a wider reach (Settings.capture_assist; off unless the player turns it on).
var assist: bool = false
## The picture the player sees and the spider's senses (set by the world): the population only lets a replacement in where it cannot be seen.
var camera_rig: Node
var sensor: Node
## True in a played world: a fly that is lost is replaced (PreyPopulation). Off in the test worlds unless a test asks.
var replenish: bool = false
var population: Population
## T09: a checkpoint's prey record (to_record) to restore instead of starting the default population; applied once the world can be queried.
var restore_record: Dictionary = {}
## What the prey side was the moment the restore finished (to_record), for checks that nothing was lost or added.
var restored_record: Dictionary = {}
## What the vents were found to be when the world was checked (PreyPopulation.validate).
var vent_validation: Dictionary = {}
## The perch graph has been checked against the physics world.
var ready_done: bool = false
var tick: int = 0
var now: float = 0.0
var serial_counter: int = 0
var validation: Dictionary = {}
## The strike (a jump in flight) and the prey the spider holds.
var strike_active: bool = false
var strike_started_tick: int = -1
var held: Node3D = null
var capture_log: Array[Dictionary] = []
## T09b: captures that did not hold (the prey struggled free), and how hard the prey in the jaws is jerking now (0 to 1, drawn only).
var escape_log: Array[Dictionary] = []
var held_jerk: float = 0.0
var refused_log: Array[Dictionary] = []
## Cost of the prey tick (microseconds), for the cost report: totals, the largest, and a ring of the latest for percentiles.
var cpu_us_total: int = 0
var cpu_ticks: int = 0
var cpu_us_max: int = 0
var cpu_ring: PackedInt32Array = PackedInt32Array()
var combined_cpu_ring: PackedInt32Array = PackedInt32Array()
var flies_stepped_total: int = 0
var capture_tests_total: int = 0
## The counters of flies that have left the list (so the cost report covers the whole run).
var banked: Dictionary = {"decisions": 0, "candidates": 0, "plans": 0, "fly_checks": 0, "fly_rays": 0, "flight_sweeps": 0, "flies": 0}

var _cost_base: int = 0
var _born_physics_frames: int = 0
var _born_in_physics: bool = false
var _spider_prev: Vector3 = Vector3.ZERO
var _strike_end_tick: int = -1
var _event_ids: Dictionary = {}
var _late: Node
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


## The second stage of the tick, after the spider has moved.
class LateStage extends Node:
	var director: Node

	func _ready() -> void:
		process_physics_priority = 10

	func _physics_process(_delta: float) -> void:
		director.late_step()


func _ready() -> void:
	process_physics_priority = PRIORITY
	_born_physics_frames = Engine.get_physics_frames()
	_born_in_physics = Engine.is_in_physics_frame()
	_ray.collision_mask = Layers.WORLD
	if profile == null:
		profile = PreyProfile.load_file(PROFILE_PATH)
	if profile == null:
		push_error("The fly profile could not be loaded: %s" % "\n".join(PreyProfile.last_errors))
		set_physics_process(false)
		return
	if lab != null and lab.has_method("get_prey_perches"):
		for d: Dictionary in lab.get_prey_perches():
			graph.add_perch(d)
		if lab.has_signal("surface_availability_changed"):
			lab.surface_availability_changed.connect(on_surface_availability_changed)
	population = Population.new(self, int(hash([seed_value, "population"]) & 0x7fffffff))
	if lab != null and lab.has_method("get_prey_vents"):
		population.set_vents(lab.get_prey_vents())
	if spider != null:
		_spider_prev = spider.global_position
		if spider.has_signal("jump_committed"):
			spider.jump_committed.connect(_on_jump_committed)
			spider.jump_ended.connect(_on_jump_ended)
	cpu_ring.resize(COST_RING)
	combined_cpu_ring.resize(COST_RING)
	_late = LateStage.new()
	_late.name = "LateStage"
	_late.director = self
	add_child(_late)


## True once queries can see the bodies that were in the scene when the director entered it (see SensorSystem).
func is_world_ready() -> bool:
	return not _born_in_physics or Engine.get_physics_frames() > _born_physics_frames


func space() -> PhysicsDirectSpaceState3D:
	return get_world_3d().direct_space_state


## What the world offers a fly to look at: the spider's body. Only the fly's own senses (rays, field of view, motion between its
## sightings) decide what of it counts; an empty Dictionary means nothing to look at.
func stimulus() -> Dictionary:
	if not stimulus_enabled or spider == null or not is_instance_valid(spider):
		return {}
	return {"position": spider.global_position, "radius": spider_radius()}


func spider_radius() -> float:
	if spider != null and spider.has_method("get_body_radius"):
		return float(spider.get_body_radius())
	return SPIDER_RADIUS_FALLBACK


func living() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for f in flies:
		if f.is_alive():
			out.append(f)
	return out


func fly_by_id(fly_id: String) -> Node3D:
	for f in flies:
		if f.id == fly_id:
			return f
	return null


# ------------------------------------------------------------------ the tick

func _physics_process(delta: float) -> void:
	if not is_world_ready():
		return
	if not ready_done and (target_population > 0 or not restore_record.is_empty()):
		ensure_ready()
	var t0 := Time.get_ticks_usec()
	tick += 1
	now += delta
	if spider != null:
		_spider_prev = spider.global_position
	if population != null:
		population.step(now)
	for f in flies:
		if f.is_alive():
			f.step(delta, now)
			flies_stepped_total += 1
	_record_cost(Time.get_ticks_usec() - t0)


## After the spider has moved: the strike, the capture, the prey in the jaws.
func late_step() -> void:
	if not is_world_ready() or cpu_ticks == 0:
		return
	var t0 := Time.get_ticks_usec()
	if strike_active and tick > _strike_end_tick and _strike_end_tick >= 0:
		strike_active = false
		_strike_end_tick = -1
	elif strike_active and tick - strike_started_tick > STRIKE_MAX_TICKS:
		strike_active = false
	if strike_active:
		resolve_captures()
	_carry_held()
	_retire_dead()
	var late_us := Time.get_ticks_usec() - t0
	var slot := (cpu_ticks - 1) % COST_RING
	cpu_ring[slot] += late_us
	cpu_us_total += late_us
	cpu_us_max = maxi(cpu_us_max, cpu_ring[slot])
	# Sensor (-10) and prey (-5 / +10) costs from this same committed tick.
	var sensor_us := 0
	if sensor != null and sensor.cpu_ticks > 0:
		sensor_us = int(sensor.cpu_ring[(sensor.cpu_ticks - 1) % sensor.COST_RING])
	combined_cpu_ring[slot] = cpu_ring[slot] + sensor_us


func ensure_ready() -> bool:
	if ready_done:
		return true
	if not is_world_ready() or not is_inside_tree():
		return false
	_become_ready()
	return true


## Checks the perch graph against the physics world (once) and starts the default population. False while the world cannot be queried yet.
## Worlds that keep no flies never pay for it.
func _become_ready() -> void:
	ready_done = true
	validation = graph.validate_all(space(), profile)
	population.rng.seed = int(hash([seed_value, "population"]) & 0x7fffffff)
	population.target = target_population
	population.enabled = replenish and target_population > 0
	vent_validation = population.validate(space())
	if not restore_record.is_empty():
		_apply_restore(restore_record)
		return
	var placed := 0
	for id in graph.order:
		if placed >= target_population:
			break
		var perch: PerchGraph.Perch = graph.perches[id]
		if perch.start and perch.valid and perch.is_free_for(""):
			spawn_fly(id)
			placed += 1


func _record_cost(us: int) -> void:
	cpu_us_total += us
	cpu_us_max = maxi(cpu_us_max, us)
	cpu_ring[cpu_ticks % COST_RING] = us
	cpu_ticks += 1


## Percentile of the latest measured ticks (since the window began), in microseconds.
func cost_percentile(q: float) -> int:
	var n := mini(cost_ticks(), COST_RING)
	if n <= 0:
		return 0
	var xs := PackedInt32Array()
	for i in n:
		xs.append(cpu_ring[(cpu_ticks - 1 - i) % COST_RING])
	xs.sort()
	return xs[clampi(int(ceil(q * float(n))) - 1, 0, n - 1)]


## Ticks measured since the window began (the start of the run, or the last reset_cost()).
func cost_ticks() -> int:
	return cpu_ticks - _cost_base


func combined_cost_percentile(q: float) -> int:
	var xs := PackedInt32Array()
	for i in mini(cost_ticks(), COST_RING):
		xs.append(combined_cpu_ring[(cpu_ticks - 1 - i) % COST_RING])
	if xs.is_empty():
		return 0
	xs.sort()
	return xs[clampi(int(ceil(q * xs.size())) - 1, 0, xs.size() - 1)]


## Begins a new measuring window (the totals, the largest and the percentiles start again).
func reset_cost() -> void:
	cpu_us_total = 0
	cpu_us_max = 0
	_cost_base = cpu_ticks


# ------------------------------------------------------------------ flies

## A new fly on a perch (the first free valid start perch when none is named). Returns null when there is no place for it.
func spawn_fly(perch_id: String = "", fly_seed: int = -1) -> Node3D:
	if not ensure_ready():
		return null
	var perch: PerchGraph.Perch = graph.get_perch(perch_id) if perch_id != "" else _first_free_start()
	if perch == null:
		return null
	var f := _make_fly(perch, fly_seed)
	fly_spawned.emit(f)
	return f


## A replacement fly: it appears on a vent and sets off at once along the flight the population planned (never placed anywhere else).
func spawn_entry(vent: PerchGraph.Perch, target: PerchGraph.Perch, plan: PerchGraph.Flight, reason: String) -> Node3D:
	var f := _make_fly(vent, -1)
	f.mind.begin_entry(now, target, plan, reason)
	fly_spawned.emit(f)
	return f


func _make_fly(perch: PerchGraph.Perch, fly_seed: int) -> Node3D:
	serial_counter += 1
	var fly_id := "fly_%d" % serial_counter
	var f: Node3D = Fly.new()
	var stream := fly_seed if fly_seed >= 0 else int(hash([seed_value, serial_counter]) & 0x7fffffff)
	f.setup(profile, self, fly_id, serial_counter, stream)
	f.mind = FlyMind.new(f)
	f.flight = FlyFlight.new(f)
	add_child(f)
	f.place_on(perch, now)
	f.goal_since = now
	flies.append(f)
	return f


func _first_free_start() -> PerchGraph.Perch:
	for id in graph.order:
		var p: PerchGraph.Perch = graph.perches[id]
		if p.start and p.valid and p.is_free_for(""):
			return p
	return null


## A surface left the world or came back: perches on it follow, and a fly sitting on one that left has lost its place (FlyMind).
func on_surface_availability_changed(surface_id: String, available: bool) -> void:
	var changed := graph.set_surface_available(surface_id, available)
	for p in changed:
		for f in flies:
			if f.is_alive() and f.perch == p and not available and f.mind != null:
				f.mind.on_perch_lost()


## Eaten flies leave the list after a while (the last few are kept for the developer view and the tests).
func _retire_dead() -> void:
	var dead := 0
	for f in flies:
		if not f.is_alive() and f != held:
			dead += 1
	if dead <= DEAD_KEPT:
		return
	for f in flies:
		if not f.is_alive() and f != held:
			_bank(f)
			flies.erase(f)
			f.queue_free()
			break


## Keeps the counters of a fly that leaves the list.
func _bank(f: Node3D) -> void:
	var c := _fly_counters(f)
	for k: String in c:
		banked[k] = int(banked[k]) + int(c[k])
	banked["flies"] = int(banked["flies"]) + 1


func _fly_counters(f: Node3D) -> Dictionary:
	return {"decisions": int(f.mind.decisions_total), "candidates": int(f.mind.candidates_total), "plans": int(f.mind.plans_total),
		"fly_checks": int(f.senses.checks_total), "fly_rays": int(f.senses.rays_total), "flight_sweeps": int(f.flight.sweeps_total)}


## What the prey side cost, for the cost report (T07, spec 24): the prey tick in microseconds (the flies' senses, minds and flights, the
## population and the capture stage) and what it asked of the world: candidates considered, plans swept, rays and sweeps. Totals cover
## every fly that ever lived in this run; the percentiles the latest `COST_RING` ticks.
func cost_summary() -> Dictionary:
	var out := banked.duplicate()
	for f in flies:
		var c := _fly_counters(f)
		for k: String in c:
			out[k] = int(out[k]) + int(c[k])
	out["flies"] = int(out["flies"]) + flies.size()
	out["living"] = living().size()
	out["ticks"] = cost_ticks()
	out["cpu_avg_us"] = cpu_us_total / maxi(cost_ticks(), 1)
	out["cpu_p50_us"] = cost_percentile(0.5)
	out["cpu_p95_us"] = cost_percentile(0.95)
	out["cpu_p99_us"] = cost_percentile(0.99)
	out["cpu_max_us"] = cpu_us_max
	out["graph_plans"] = graph.plans_total
	out["graph_plans_failed"] = graph.plans_failed
	out["graph_sweeps"] = graph.sweeps_total
	out["graph_rays"] = graph.rays_total
	out["capture_tests"] = capture_tests_total
	out["population_asks"] = population.asks_total
	out["population_deferred"] = population.deferred_total
	out["population_entries"] = population.entries_total
	out["population_view_checks"] = population.view_checks_total
	out["population_sensor_checks"] = population.sensor_checks_total
	return out


# ------------------------------------------------------------------ the strike and the capture

func _on_jump_committed(_plan: RefCounted) -> void:
	strike_active = true
	strike_started_tick = tick
	_strike_end_tick = -1


func _on_jump_ended(_result: Dictionary) -> void:
	_strike_end_tick = tick + STRIKE_GRACE_TICKS


## The reach of a strike: the fly's capture radius plus the spider's body radius, wider when the player has asked for it.
func strike_reach() -> float:
	var reach: float = profile.capture_radius_wu + spider_radius()
	if assist:
		reach *= profile.capture_assist_scale
	return reach


## Tests every living fly, in id order, against the spider's path during this tick. Called once a tick, after the spider has moved, while
## a strike lasts.
func resolve_captures() -> void:
	var s0 := _spider_prev
	var s1 := spider.global_position
	var reach := strike_reach()
	for f in flies:
		if not f.is_alive():
			continue
		capture_tests_total += 1
		var c: Dictionary = PreyMath.sweep_closest(s0, s1, f.prev_position, f.global_position)
		if float(c["distance"]) > reach:
			continue
		var t := float(c["t"])
		var at_spider := s0.lerp(s1, t)
		var at_fly: Vector3 = f.prev_position.lerp(f.global_position, t)
		_ray.from = at_spider
		_ray.to = at_fly
		if not space().intersect_ray(_ray).is_empty():
			continue  # the world is between them: nothing is caught through a wall
		var event_id := "capture:%s:%s" % [OWNER_ID, f.id]
		if _event_ids.has(event_id):
			continue
		var event := {"id": event_id, "tick": tick, "t": now, "owner": OWNER_ID, "prey": f.id, "distance": float(c["distance"]),
			"reach": reach, "assisted": assist, "t_closest": t,
			"contact_position": at_fly, "contact_radius": float(f.profile.radius_wu)}
		if held != null:
			event["refused"] = "the jaws are full"
			refused_log.append(event)
			continue
		_event_ids[event_id] = true
		capture_log.append(event)
		f.mark_captured(OWNER_ID, event_id)
		held = f
		captured.emit(event)


## The prey in the jaws follows the spider's mouth (drawn only: it has no say in anything).
func _carry_held() -> void:
	if held == null or not is_instance_valid(held):
		held = null
		return
	if held.state == Fly.State.CONSUMED:
		held = null
		return
	if spider.has_method("get_eye_position") and spider.has_method("get_heading_vector") and spider.has_method("get_visual_up"):
		var up: Vector3 = spider.get_visual_up()
		var forward: Vector3 = spider.get_heading_vector()
		held.global_position = spider.get_eye_position() + forward * 0.2 - up * 0.13
		if held_jerk > 0.0:
			# T09b: a struggling fly jerks in the jaws (drawn only).
			var side: Vector3 = forward.cross(up)
			held.global_position += (side * sin(now * 61.0) * 0.06 + up * cos(now * 47.0) * 0.04) * held_jerk
			held_jerk = maxf(0.0, held_jerk - 0.05)
		held.normal = up
		held.heading = forward
		held.velocity = Vector3.ZERO
		held._apply_basis()
	held.prev_position = held.global_position
	held._pose(now)


## Lets go of the held prey (it was eaten, or dropped). The fly itself keeps whatever state it has.
func release_held() -> void:
	held = null


## T09b: the prey in the jaws tore free before it was subdued. Its capture is undone (removed from the log, so the same fly can be caught
## again under the same event id; nothing was eaten of it, since a struggling prey cannot be fed on), the fly flees on its own evidence,
## and a replacement owed for it is no longer owed. Returns false when nothing is held.
func escape_held(reason: String) -> bool:
	if held == null or not is_instance_valid(held) or held.state != Fly.State.CAPTURED:
		return false
	var f: Node3D = held
	var event_id: String = f.capture_event_id
	held = null
	held_jerk = 0.0
	for i in range(capture_log.size() - 1, -1, -1):
		if str(capture_log[i]["id"]) == event_id:
			capture_log.remove_at(i)
			break
	_event_ids.erase(event_id)
	f.escape_capture(now, reason)
	population.forget_owed(1)
	var event := {"id": event_id, "tick": tick, "t": now, "prey": f.id, "reason": reason}
	escape_log.append(event)
	escaped.emit(event)
	return true


# ------------------------------------------------------------------ persistence (T09, spec 21.3 PreyState, S01-C)

## The prey side of the world as one plain record: the clock, the id counter, every living fly and the one in the jaws (a consumed fly is
## gone and is not recorded), who sits on or has reserved each perch and vent, the captures made (so an event can never be granted twice),
## and the replacement schedule with its stream. Call only between ticks, once the director is ready.
func to_record() -> Dictionary:
	var fly_records: Array = []
	for f in flies:
		if f.is_alive() or (f == held and f.state == Fly.State.CAPTURED):
			fly_records.append(f.to_record())
	var perch_records: Array = []
	for id in graph.order:
		perch_records.append(_perch_record(graph.perches[id]))
	for v in population.vents:
		perch_records.append(_perch_record(v))
	var captures: Array = []
	for e: Dictionary in capture_log:
		captures.append({"id": str(e["id"]), "tick": int(e["tick"]), "t": float(e["t"]), "owner": str(e["owner"]), "prey": str(e["prey"])})
	return {"seed": str(seed_value), "tick": tick, "now": now, "serial_counter": serial_counter, "target_population": target_population,
		"replenish": replenish, "held": held.id if held != null and is_instance_valid(held) else "", "captures": captures,
		"flies": fly_records, "perches": perch_records, "population": population.to_record()}


func _perch_record(p: PerchGraph.Perch) -> Dictionary:
	return {"id": p.id, "occupant": p.occupant, "reserved_by": p.reserved_by, "available": p.available}


## A perch of the graph or a vent, by id; null for neither.
func find_perch(perch_id: String) -> PerchGraph.Perch:
	var p: PerchGraph.Perch = graph.get_perch(perch_id)
	if p == null and population != null:
		p = population.vent_by_id(perch_id)
	return p


## Rebuilds the prey side from a validated record. The flies are made again by their own ids, serials and seeds, then given back their
## state; nothing is drawn from any stream on the way, so they go on exactly as their streams stood at the checkpoint.
func _apply_restore(r: Dictionary) -> void:
	tick = int(r["tick"])
	now = float(r["now"])
	serial_counter = int(r["serial_counter"])
	for pr: Dictionary in r["perches"]:
		var p := find_perch(str(pr["id"]))
		if p == null:
			push_error("checkpoint names a perch the habitat lacks: %s" % str(pr["id"]))
			continue
		p.occupant = str(pr["occupant"])
		p.reserved_by = str(pr["reserved_by"])
		p.available = bool(pr["available"])
	population.apply_record(r["population"])
	for fr: Dictionary in r["flies"]:
		var f: Node3D = Fly.new()
		f.setup(profile, self, str(fr["id"]), int(fr["serial"]), String(fr["rng_seed"]).to_int())
		f.mind = FlyMind.new(f)
		f.flight = FlyFlight.new(f)
		add_child(f)
		f.apply_record(fr, find_perch)
		flies.append(f)
	capture_log.clear()
	_event_ids.clear()
	for e: Dictionary in r["captures"]:
		capture_log.append({"id": str(e["id"]), "tick": int(e["tick"]), "t": float(e["t"]), "owner": str(e["owner"]), "prey": str(e["prey"]), "restored": true})
		_event_ids[str(e["id"])] = true
	held = fly_by_id(str(r["held"])) if str(r["held"]) != "" else null
	strike_active = false
	_strike_end_tick = -1
	if spider != null:
		_spider_prev = spider.global_position
	restored_record = to_record()
