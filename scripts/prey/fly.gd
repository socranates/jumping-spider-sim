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
var glances_started: int = 0
var walks_started: int = 0
var walked_wu: float = 0.0
## Tests: a fly held still does not fidget, groom or decide (it still senses and shows its awareness).
var fixture_hold: bool = false

## The prey's side of a capture.
var captured_by: String = ""
var capture_event_id: String = ""
var nutrition_total: float = 0.0
var nutrition_left: float = 0.0
## T09c: true while it fights the jaws (drawn: buzzing wings, kicking legs). Set by the feeding controller.
var struggling: bool = false

var _now: float = 0.0
var _next_fidget_t: float = 0.0
var _fidget_t0: float = 0.0
var _fidget_t1: float = 0.0
var _fidget_from: Vector3 = Vector3.ZERO
var _fidget_to: Vector3 = Vector3.ZERO
var _next_groom_t: float = 0.0
var _groom_t1: float = 0.0
## T09b: looking to and fro. The way it settled facing (the glances swing either side of it), the turn under way and when the next is due.
var _home_heading: Vector3 = Vector3.FORWARD
var _glancing: bool = false
var _glance_target: Vector3 = Vector3.FORWARD
var _glance_sign: float = 1.0
var _next_glance_t: float = 0.0
## T09c: walking about its spot. Where the walk is going, how fast, the stop-start bursts, when the next walk is due, and the spot it last
## settled on (the anchor of its little fidgets).
var _walking: bool = false
var _walk_target: Vector3 = Vector3.ZERO
var _walk_speed: float = 0.0
var _burst_left: float = 0.0
var _pause_left: float = 0.0
var _next_walk_t: float = 0.0
var _rest_spot: Vector3 = Vector3.ZERO
const WALK_SAMPLE_WU := 0.15
const WALK_MIN_WU := 0.2
const WALK_FACE_DEG := 20.0
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
	_home_heading = heading
	_glancing = false
	_glance_sign = 1.0 if rng.randf() < 0.5 else -1.0
	_next_glance_t = now + PreyMath.draw(rng, profile.glance_interval_s)
	_walking = false
	_rest_spot = stand
	_next_walk_t = now + PreyMath.draw(rng, profile.walk_interval_s)


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


## True while a perched fly turns to look another way (T09b): the moments a careful hunter waits for or uses.
func glancing() -> bool:
	return state == State.PERCHED and _glancing


## The direction the fly faces now, for the developer view and the tests.
func facing() -> Vector3:
	return heading


func fidgeting(now: float) -> bool:
	return state == State.PERCHED and now < _fidget_t1 and _fidget_t1 > _fidget_t0


# ------------------------------------------------------------------ at rest

func _rest(now: float, dt: float) -> void:
	if state == State.ALERT:
		_fidget_t1 = 0.0
		_groom_t1 = 0.0
		_glancing = false
		if _walking:
			_end_walk(now)
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
	if _glancing:
		if _turn_heading(_glance_target, dt):
			_glancing = false
		return
	if _walking:
		_walk_step(now, dt)
		return
	if now >= _next_groom_t:
		begin_groom(now, PreyMath.draw(rng, profile.groom_duration_s))
		return
	if now >= _next_glance_t:
		_start_glance(now)
		return
	if now >= _next_walk_t:
		_start_walk(now)
		return
	if now >= _next_fidget_t:
		_start_fidget(now)


## T09c: a walk across its surface, the way flies walk: turn, a few quick steps, a stop, a few more. Mostly onward, a little to either side;
## back toward its perch when it has wandered more than about half its wander radius. The way is checked before it sets off: surface under
## every sample (never off an edge) and nothing standing in the way; a blocked walk stops short where the way was still good.
func _start_walk(now: float) -> void:
	_next_walk_t = now + PreyMath.draw(rng, profile.walk_interval_s)
	var dir: Vector3 = heading.rotated(normal, deg_to_rad(rng.randf_range(-100.0, 100.0)))
	var home := perch.position - stand if perch != null else Vector3.ZERO
	home -= normal * home.dot(normal)
	if home.length() > profile.wander_radius_wu * 0.5:
		dir = home.normalized().rotated(normal, deg_to_rad(rng.randf_range(-40.0, 40.0)))
	dir = (dir - normal * dir.dot(normal)).normalized()
	var want: float = PreyMath.draw(rng, profile.walk_distance_wu)
	var speed: float = PreyMath.draw(rng, profile.walk_speed_wu_s)
	var good := 0.0
	var d := WALK_SAMPLE_WU
	while d <= want + 1.0e-6:
		var p := stand + dir * d
		if perch != null and (p - perch.position).length() > profile.wander_radius_wu:
			break
		if not surface_under(p) or not _clear_walk(stand + dir * (d - WALK_SAMPLE_WU), p):
			break
		good = d
		d += WALK_SAMPLE_WU
	if good < WALK_MIN_WU:
		return
	_walk_target = stand + dir * good
	_walk_speed = speed
	_walking = true
	_burst_left = PreyMath.draw(rng, profile.walk_burst_s)
	_pause_left = 0.0
	walks_started += 1
	_log_event({"t": now, "kind": "walk", "distance": good})


## Nothing solid between two points on the surface at the fly's body height.
func _clear_walk(a: Vector3, b: Vector3) -> bool:
	_ray.from = a + normal * profile.hover_wu
	_ray.to = b + normal * profile.hover_wu
	return world.space().intersect_ray(_ray).is_empty()


func _walk_step(now: float, dt: float) -> void:
	var to := _walk_target - stand
	to -= normal * to.dot(normal)
	var left := to.length()
	if left <= 1.0e-3:
		_end_walk(now)
		return
	var dir := to / left
	if rad_to_deg(heading.angle_to(dir)) > WALK_FACE_DEG:
		_turn_heading(dir, dt)  # face the way first, quickly
		return
	if _pause_left > 0.0:
		_pause_left -= dt
		if _pause_left <= 0.0:
			_burst_left = PreyMath.draw(rng, profile.walk_burst_s)
		return
	var step := minf(_walk_speed * dt, left)
	stand += dir * step
	walked_wu += step
	heading = heading.slerp(dir, 0.3).normalized()
	global_position = stand + normal * profile.hover_wu
	_apply_basis()
	_burst_left -= dt
	if _burst_left <= 0.0:
		_pause_left = PreyMath.draw(rng, profile.walk_pause_s)


func _end_walk(now: float) -> void:
	_walking = false
	_rest_spot = stand
	_home_heading = heading
	_next_walk_t = maxf(_next_walk_t, now + PreyMath.draw(rng, profile.walk_interval_s) * 0.5)


## True while it walks (and is not in one of its little stops): drawn with stepping legs.
func walking_now() -> bool:
	return state == State.PERCHED and _walking and _pause_left <= 0.0


## A quick look to one side of the way it settled, then (next time) to the other: the fly's view swings to and fro, so what it can take in
## of a creeping spider rises and falls (FlySenses weighs motion by where in the field of view it is).
func _start_glance(now: float) -> void:
	var angle: float = PreyMath.draw(rng, profile.glance_angle_deg) * _glance_sign
	_glance_sign = -_glance_sign
	var home := _home_heading - normal * _home_heading.dot(normal)
	if home.length_squared() < 1.0e-6:
		home = heading
	_glance_target = home.normalized().rotated(normal, deg_to_rad(angle)).normalized()
	_glancing = true
	_next_glance_t = now + PreyMath.draw(rng, profile.glance_interval_s)
	glances_started += 1
	_log_event({"t": now, "kind": "glance", "angle": angle})


## Turns the heading toward a direction on the surface at the fly's turn rate; true once it is there.
func _turn_heading(target: Vector3, dt: float) -> bool:
	var to := target - normal * target.dot(normal)
	if to.length_squared() < 1.0e-6:
		return true
	var angle := heading.signed_angle_to(to.normalized(), normal)
	var limit := deg_to_rad(profile.turn_rate_deg_s) * dt
	heading = heading.rotated(normal, clampf(angle, -limit, limit)).normalized()
	_apply_basis()
	return absf(angle) <= limit + 1.0e-4


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
	var away := stand + dir * dist - _rest_spot
	away -= normal * away.dot(normal)
	if away.length() > profile.perch_radius_wu:
		var home := _rest_spot - stand
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
			mode = FlyBody.Mode.STRUGGLING if struggling else FlyBody.Mode.HELD
		_:
			if now < _groom_t1:
				mode = FlyBody.Mode.GROOMING
				groom = 1.0
			elif walking_now():
				mode = FlyBody.Mode.WALKING
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


## T09b: it tore free of the jaws before it was subdued. It knows exactly where the spider is (it was in its jaws), is as frightened as it
## can be, and flees at once from where it is (FlyMind picks where to, as for any flight from danger).
func escape_capture(now: float, reason: String) -> void:
	if state != State.CAPTURED:
		return
	_now = now
	captured_by = ""
	capture_event_id = ""
	senses.awareness = profile.awareness_max
	senses.has_last_seen = true
	senses.last_seen_position = global_position
	senses.last_seen_time = now
	prev_position = global_position
	velocity = Vector3.ZERO
	if mind != null:
		mind.escape(now, "escaped: " + reason)


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
			"fidget_to": RecordMath.v3(_fidget_to), "next_groom": _next_groom_t, "groom_t1": _groom_t1,
			"home_heading": RecordMath.v3(_home_heading), "glancing": _glancing, "glance_target": RecordMath.v3(_glance_target),
			"glance_sign": _glance_sign, "next_glance": _next_glance_t,
			"walking": _walking, "walk_target": RecordMath.v3(_walk_target), "walk_speed": _walk_speed, "burst_left": _burst_left,
			"pause_left": _pause_left, "next_walk": _next_walk_t, "rest_spot": RecordMath.v3(_rest_spot)},
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
	_home_heading = RecordMath.to_v3(sch["home_heading"])
	_glancing = bool(sch["glancing"])
	_glance_target = RecordMath.to_v3(sch["glance_target"])
	_glance_sign = float(sch["glance_sign"])
	_next_glance_t = float(sch["next_glance"])
	_walking = bool(sch["walking"])
	_walk_target = RecordMath.to_v3(sch["walk_target"])
	_walk_speed = float(sch["walk_speed"])
	_burst_left = float(sch["burst_left"])
	_pause_left = float(sch["pause_left"])
	_next_walk_t = float(sch["next_walk"])
	_rest_spot = RecordMath.to_v3(sch["rest_spot"])
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
