extends Node3D
## Fly: the first living prey (T07), one archetype of fly-like prey with no claim about any real species (spec 8.3, 19.3). A fly is a
## small state machine with its own senses and a seeded stream of choices:
##   PERCHED  -> ALERT -> TAKEOFF -> FLEE -> SEEK_PERCH -> PERCHED   (it noticed something, left in a hurry, found another place)
##   PERCHED  -> REPOSITION -> PERCHED                               (it moved on by itself)
##   REPOSITION / SEEK_PERCH -> FLEE                                  (credible danger interrupts a flight)
##   any living state -> CAPTURED -> CONSUMED                         (the capture and the feeding belong to PreyDirector and the spider)
## A fly reacts only to its own evidence (FlySenses, A-028). Its mind (FlyMind) picks goals with a small utility selector and logs the
## winning reason of every transition; its flight (FlyFlight) moves it along validated paths with collision sweeps and never
## teleports it. This class holds the state, the rest behaviour (fidgets and grooming, which are also what makes a perched fly findable by
## its small movements), the percept the spider's senses may read, the trace, and the prey's side of a capture.
## Order (spec 20): the director steps every fly once per tick at the start of the tick, in id order, after the spider's sensor and before
## the spider moves; a fly reads the world as the previous tick committed it.

const PreyMath = preload("res://scripts/prey/prey_math.gd")
const FlySenses = preload("res://scripts/prey/fly_senses.gd")
const PerchGraph = preload("res://scripts/prey/perch_graph.gd")
const FlyBody = preload("res://scripts/prey/fly_body.gd")
const Perceivable = preload("res://scripts/perception/perceivable.gd")
const Observation = preload("res://scripts/perception/observation.gd")
const SupportMath = preload("res://scripts/movement/support_math.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")
const RecordMath = preload("res://scripts/persistence/record_math.gd")

enum State { PERCHED, ALERT, TAKEOFF, FLEE, SEEK_PERCH, REPOSITION, CAPTURED, CONSUMED }
const STATE_NAMES: Array[String] = ["PERCHED", "ALERT", "TAKEOFF", "FLEE", "SEEK_PERCH", "REPOSITION", "CAPTURED", "CONSUMED"]

## A state change, with the reason that won it.
signal transitioned(fly: Node3D, from_state: String, to_state: String, reason: String)

const TRACE_MAX := 80
const EVENTS_MAX := 64
const EYE_LIFT := 0.1
const SURFACE_PROBE := 0.3
const SURFACE_TOLERANCE := 0.06

var profile: RefCounted
var id: String = ""
var serial: int = 0
## The gameplay stream (reaction delays, fidget and grooming times, restlessness) and the cosmetic stream (how it looks); the second never
## feeds the first, so changing how a fly is drawn cannot change what it does.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var cosmetic_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var world: Node
var senses: FlySenses
var mind: RefCounted
var flight: RefCounted
var body: Node3D

var state: int = State.PERCHED
var state_since: float = 0.0
var goal: StringName = &"rest"
var goal_since: float = 0.0
var goal_reason: String = ""
var perch: PerchGraph.Perch
## The point on the surface under the feet while perched.
var stand: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.UP
var heading: Vector3 = Vector3.FORWARD
var velocity: Vector3 = Vector3.ZERO
var prev_position: Vector3 = Vector3.ZERO
var fatigue: float = 0.0
## How restless this stay has made it, in [0, 1], and the rate it grows at (varied by the stream for each stay).
var restless_rate: float = 0.0
var perched_since: float = 0.0
var trace: Array[Dictionary] = []
var transitions_total: int = 0
## Fidgets and grooming bouts it started (time, kind, and for a fidget the shift from the perch's centre), for tests and the developer view.
var events: Array[Dictionary] = []
var fidgets_started: int = 0
var grooms_started: int = 0
## Tests: a fly held still does not fidget, groom or decide (it still senses and shows its awareness).
var fixture_hold: bool = false

## The prey's side of a capture.
var captured_by: String = ""
var capture_event_id: String = ""
var nutrition_total: float = 0.0
var nutrition_left: float = 0.0

var _now: float = 0.0
var _next_fidget_t: float = 0.0
var _fidget_t0: float = 0.0
var _fidget_t1: float = 0.0
var _fidget_from: Vector3 = Vector3.ZERO
var _fidget_to: Vector3 = Vector3.ZERO
var _next_groom_t: float = 0.0
var _groom_t1: float = 0.0
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


## Wires a new fly. `director` is the PreyDirector (the fly asks it for the world: stimulus(), space(), graph, tick); the seed fixes both streams.
func setup(p: RefCounted, director: Node, fly_id: String, fly_serial: int, stream_seed: int) -> void:
	profile = p
	world = director
	id = fly_id
	serial = fly_serial
	name = fly_id
	rng.seed = stream_seed
	cosmetic_rng.seed = stream_seed ^ 0x5bd1e995
	senses = FlySenses.new(p)
	nutrition_total = p.nutrition
	nutrition_left = p.nutrition
	_ray.collision_mask = Layers.WORLD
	body = FlyBody.new(cosmetic_rng.randf() * TAU)
	body.name = "Body"
	add_child(body)


func _ready() -> void:
	add_to_group(Perceivable.GROUP)


func state_name() -> String:
	return STATE_NAMES[state]


func is_alive() -> bool:
	return state < State.CAPTURED


func is_flying() -> bool:
	return state >= State.TAKEOFF and state <= State.REPOSITION


func eye_position() -> Vector3:
	return global_position + normal * EYE_LIFT


## Sits the fly on a perch (a new stay: the schedule of fidgets and grooming starts again).
func place_on(p: PerchGraph.Perch, now: float) -> void:
	if perch != null and perch != p and perch.occupant == id:
		perch.occupant = ""
	perch = p
	p.occupant = id
	if p.reserved_by == id:
		p.reserved_by = ""
	stand = p.position
	normal = p.normal
	var tangent := _random_tangent()
	heading = tangent
	global_position = stand + normal * profile.hover_wu
	prev_position = global_position
	velocity = Vector3.ZERO
	_apply_basis()
	reset_physics_interpolation()
	begin_stay(now)


## The start of a stay on a perch: the clocks of fidgets, grooming and restlessness.
func begin_stay(now: float) -> void:
	perched_since = now
	var spread: float = profile.restless_spread
	restless_rate = profile.restless_per_s * (1.0 + spread * (rng.randf() * 2.0 - 1.0))
	_fidget_t1 = 0.0
	_groom_t1 = 0.0
	_next_fidget_t = now + PreyMath.draw(rng, profile.fidget_interval_s)
	_next_groom_t = now + PreyMath.draw(rng, profile.groom_interval_s)


func restlessness(now: float) -> float:
	return clampf((now - perched_since) * restless_rate, 0.0, 1.0)


# ------------------------------------------------------------------ the tick

## One tick. The director calls it once for every living fly, in id order.
func step(dt: float, now: float) -> void:
	_now = now
	prev_position = global_position
	if state >= State.CAPTURED:
		velocity = Vector3.ZERO
		return
	_look(now, dt)
	if mind != null and not fixture_hold:
		mind.think(now, dt)
	if state == State.PERCHED or state == State.ALERT:
		_rest(now, dt)
		fatigue = maxf(0.0, fatigue - profile.fatigue_down_per_s * dt)
	elif flight != null:
		flight.step(now, dt)
		fatigue = minf(1.0, fatigue + profile.fatigue_up_per_s * dt)
	velocity = (global_position - prev_position) / maxf(dt, 1.0e-6)
	_pose(now)


## Looks at what there is to see (the one stimulus the world offers) and lets the awareness build or drain.
func _look(now: float, dt: float) -> void:
	var stim: Dictionary = world.stimulus()
	if stim.is_empty():
		senses.idle(dt, decay_rate())
		return
	if not senses.should_check(now):
		return
	var facing := heading
	if is_flying() and velocity.length_squared() > 0.01:
		facing = velocity.normalized()
	senses.update(world.space(), eye_position(), facing, Vector3.UP if is_flying() else normal, stim["position"], float(stim["radius"]), now, vigilance(), decay_rate())


## How much of what it sees a fly takes in: less while it grooms, more once it is alert.
func vigilance() -> float:
	if state == State.ALERT:
		return profile.vigilance_alert
	if grooming(_now):
		return profile.vigilance_grooming
	return profile.vigilance_relaxed


func decay_rate() -> float:
	return profile.decay_alert_per_s if state == State.ALERT else profile.decay_relaxed_per_s


func grooming(now: float) -> bool:
	return state == State.PERCHED and now < _groom_t1


func fidgeting(now: float) -> bool:
	return state == State.PERCHED and now < _fidget_t1 and _fidget_t1 > _fidget_t0


# ------------------------------------------------------------------ at rest

func _rest(now: float, dt: float) -> void:
	if state == State.ALERT:
		_fidget_t1 = 0.0
		_groom_t1 = 0.0
		if senses.has_last_seen:
			_turn_toward(senses.last_seen_position, dt)
		return
	if fixture_hold:
		return
	if now < _groom_t1:
		return
	if now < _fidget_t1:
		var u := clampf((now - _fidget_t0) / maxf(_fidget_t1 - _fidget_t0, 1.0e-6), 0.0, 1.0)
		stand = _fidget_from.lerp(_fidget_to, smoothstep(0.0, 1.0, u))
		global_position = stand + normal * profile.hover_wu
		return
	if now >= _next_groom_t:
		begin_groom(now, PreyMath.draw(rng, profile.groom_duration_s))
		return
	if now >= _next_fidget_t:
		_start_fidget(now)


## A grooming bout of `duration` seconds from now (the fly's own schedule starts one; a test may start one at a chosen moment).
func begin_groom(now: float, duration: float) -> void:
	_groom_t1 = now + duration
	_next_groom_t = _groom_t1 + PreyMath.draw(rng, profile.groom_interval_s)
	grooms_started += 1
	_log_event({"t": now, "kind": "groom", "duration": duration})


func _start_fidget(now: float) -> void:
	var dir := _random_tangent()
	var dist: float = PreyMath.draw(rng, profile.fidget_distance_wu)
	var dur: float = PreyMath.draw(rng, profile.fidget_duration_s)
	_next_fidget_t = now + dur + PreyMath.draw(rng, profile.fidget_interval_s)
	var away := stand + dir * dist - perch.position
	away -= normal * away.dot(normal)
	if away.length() > profile.perch_radius_wu:
		var home := perch.position - stand
		home -= normal * home.dot(normal)
		if home.length_squared() > 1.0e-6:
			dir = home.normalized()
	var target := stand + dir * dist
	if not surface_under(target):
		return
	_fidget_from = stand
	_fidget_to = target
	_fidget_t0 = now
	_fidget_t1 = now + dur
	heading = heading.slerp(dir, 0.7).normalized() if heading.dot(dir) > -0.99 else dir
	_apply_basis()
	fidgets_started += 1
	_log_event({"t": now, "kind": "fidget", "shift": target - perch.position, "duration": dur})


func _log_event(e: Dictionary) -> void:
	events.append(e)
	if events.size() > EVENTS_MAX:
		events.pop_front()


## True when a surface lies under `point` (along the normal), so a fidget never takes a fly off an edge.
func surface_under(point: Vector3) -> bool:
	_ray.from = point + normal * SURFACE_PROBE
	_ray.to = point - normal * SURFACE_PROBE
	var hit: Dictionary = world.space().intersect_ray(_ray)
	return not hit.is_empty() and absf(((hit["position"] as Vector3) - point).dot(normal)) <= SURFACE_TOLERANCE


func _turn_toward(point: Vector3, dt: float) -> void:
	var to := point - global_position
	to -= normal * to.dot(normal)
	if to.length_squared() < 1.0e-6:
		return
	var angle := heading.signed_angle_to(to.normalized(), normal)
	var limit := deg_to_rad(profile.turn_rate_deg_s) * dt
	heading = heading.rotated(normal, clampf(angle, -limit, limit)).normalized()
	_apply_basis()


## A direction along the surface, from the gameplay stream.
func _random_tangent() -> Vector3:
	var ref := Vector3.FORWARD if absf(normal.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var t := normal.cross(ref).normalized()
	return t.rotated(normal, rng.randf() * TAU).normalized()


## Turns the fly to face a world direction (projected on the surface it stands on): for a fixture that wants it looking a particular way.
func face(world_dir: Vector3) -> void:
	var flat := world_dir - normal * world_dir.dot(normal)
	if flat.length_squared() > 1.0e-8:
		heading = flat.normalized()
		_apply_basis()


func _apply_basis() -> void:
	var b := SupportMath.body_basis(normal, heading)
	global_transform = Transform3D(b, global_position)


# ------------------------------------------------------------------ states and the trace

## Changes state and records why (every transition has a winning reason; the trace holds the last TRACE_MAX of them).
func transition(to: int, reason: String) -> void:
	if to == state:
		return
	var from := state
	var entry := {"tick": int(world.tick), "t": _now, "from": STATE_NAMES[from], "to": STATE_NAMES[to], "reason": reason, "goal": str(goal),
		"awareness": senses.awareness, "perch": perch.id if perch != null else "", "evidence": FlySenses.describe(senses.evidence)}
	trace.append(entry)
	if trace.size() > TRACE_MAX:
		trace.pop_front()
	transitions_total += 1
	state = to
	state_since = _now
	transitioned.emit(self, STATE_NAMES[from], STATE_NAMES[to], reason)


func set_goal(g: StringName, reason: String) -> void:
	if g != goal:
		goal = g
		goal_since = _now
	goal_reason = reason


## The last reason a transition was made, "" before the first.
func last_reason() -> String:
	return "" if trace.is_empty() else str(trace[trace.size() - 1]["reason"])


# ------------------------------------------------------------------ what the spider's senses may read

## The percept (spec 19.3): the world's truth about this fly, read only by the spider's SensorSystem. A captured or eaten fly is not there.
func get_percept() -> Dictionary:
	if state >= State.CAPTURED:
		return {}
	return Perceivable.make(id, global_position, profile.radius_wu, velocity, Observation.FLY_LIKE_PREY)


# ------------------------------------------------------------------ cosmetics

func _pose(now: float) -> void:
	var mode: int = FlyBody.Mode.PERCHED
	var groom := 0.0
	match state:
		State.ALERT:
			mode = FlyBody.Mode.ALERT
		State.TAKEOFF, State.FLEE, State.SEEK_PERCH, State.REPOSITION:
			mode = FlyBody.Mode.FLYING
		State.CAPTURED:
			mode = FlyBody.Mode.HELD
		_:
			if now < _groom_t1:
				mode = FlyBody.Mode.GROOMING
				groom = 1.0
	body.pose(mode, 1.0, groom, now)


# ------------------------------------------------------------------ the prey's side of a capture

## The spider took this fly. Everything it was doing stops; it keeps the nutrition it has left.
func mark_captured(owner_id: String, event_id: String) -> void:
	if state >= State.CAPTURED:
		return
	if perch != null and perch.occupant == id:
		perch.occupant = ""
	if perch != null and perch.reserved_by == id:
		perch.reserved_by = ""
	if flight != null:
		flight.release_target()
	captured_by = owner_id
	capture_event_id = event_id
	goal_reason = "captured"
	transition(State.CAPTURED, "taken by %s (event %s)" % [owner_id, event_id])
	velocity = Vector3.ZERO


## The spider ate some of it. Returns how much of its nutrition was taken (never more than is left); at nothing left it is CONSUMED.
func consume(amount: float) -> float:
	if state != State.CAPTURED or amount <= 0.0 or not is_finite(amount):
		return 0.0
	var taken := minf(amount, nutrition_left)
	nutrition_left -= taken
	if nutrition_left <= 1.0e-9:
		nutrition_left = 0.0
		transition(State.CONSUMED, "eaten (event %s)" % capture_event_id)
		visible = false
	return taken


## For the developer views: one line of the fly's state.
func describe_line() -> String:
	return "%s %s goal %s awareness %.2f perch %s | %s" % [id, STATE_NAMES[state], str(goal), senses.awareness, perch.id if perch != null else "-", goal_reason]


# ------------------------------------------------------------------ persistence (T09, spec 21.3 PreyState)

## The fly as a plain record: its state, place, clocks, both streams, and what its senses, mind and flight are in the middle of. The trace,
## the event log and the cost counters are developer history and start again after a restore.
func to_record() -> Dictionary:
	return {
		"id": id, "serial": serial, "rng_seed": str(rng.seed), "rng_state": str(rng.state), "cosmetic_rng_state": str(cosmetic_rng.state),
		"state": STATE_NAMES[state], "state_since": state_since, "goal": str(goal), "goal_since": goal_since, "goal_reason": goal_reason,
		"perch": perch.id if perch != null else "", "stand": RecordMath.v3(stand), "normal": RecordMath.v3(normal),
		"heading": RecordMath.v3(heading), "position": RecordMath.v3(global_position), "velocity": RecordMath.v3(velocity),
		"fatigue": fatigue, "restless_rate": restless_rate, "perched_since": perched_since,
		"schedule": {"next_fidget": _next_fidget_t, "fidget_t0": _fidget_t0, "fidget_t1": _fidget_t1, "fidget_from": RecordMath.v3(_fidget_from),
			"fidget_to": RecordMath.v3(_fidget_to), "next_groom": _next_groom_t, "groom_t1": _groom_t1},
		"senses": senses.to_record(), "mind": mind.to_record(), "flight": flight.to_record(),
		"captured_by": captured_by, "capture_event_id": capture_event_id, "nutrition_total": nutrition_total, "nutrition_left": nutrition_left,
	}


## Restores a record made by to_record onto a fly that setup() has wired (with the record's seed) and that is in the tree. `find_perch`
## turns a perch id into the director's perch (or a vent), null when it has none. The record must already have been validated.
func apply_record(r: Dictionary, find_perch: Callable) -> void:
	rng.state = String(r["rng_state"]).to_int()
	cosmetic_rng.state = String(r["cosmetic_rng_state"]).to_int()
	state = STATE_NAMES.find(str(r["state"]))
	state_since = float(r["state_since"])
	goal = StringName(str(r["goal"]))
	goal_since = float(r["goal_since"])
	goal_reason = str(r["goal_reason"])
	perch = find_perch.call(str(r["perch"])) if str(r["perch"]) != "" else null
	stand = RecordMath.to_v3(r["stand"])
	normal = RecordMath.to_v3(r["normal"])
	heading = RecordMath.to_v3(r["heading"])
	velocity = RecordMath.to_v3(r["velocity"])
	fatigue = float(r["fatigue"])
	restless_rate = float(r["restless_rate"])
	perched_since = float(r["perched_since"])
	var sch: Dictionary = r["schedule"]
	_next_fidget_t = float(sch["next_fidget"])
	_fidget_t0 = float(sch["fidget_t0"])
	_fidget_t1 = float(sch["fidget_t1"])
	_fidget_from = RecordMath.to_v3(sch["fidget_from"])
	_fidget_to = RecordMath.to_v3(sch["fidget_to"])
	_next_groom_t = float(sch["next_groom"])
	_groom_t1 = float(sch["groom_t1"])
	senses.apply_record(r["senses"])
	mind.apply_record(r["mind"])
	flight.apply_record(r["flight"], find_perch)
	captured_by = str(r["captured_by"])
	capture_event_id = str(r["capture_event_id"])
	nutrition_total = float(r["nutrition_total"])
	nutrition_left = float(r["nutrition_left"])
	global_position = RecordMath.to_v3(r["position"])
	prev_position = global_position
	_apply_basis()
	reset_physics_interpolation()
	visible = state != State.CONSUMED
	_now = float(world.now)
	_pose(_now)
