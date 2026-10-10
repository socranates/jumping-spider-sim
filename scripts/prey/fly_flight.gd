extends RefCounted
## FlyFlight: how a fly gets from one place to another (spec 8.3, 20). It flies a path the planner (PerchGraph.plan) has already swept
## and still sweeps every step: before a fly moves, the clearance sphere is cast from where it is to where it would be, and a fly whose way
## has been blocked does not move at all. It then re-plans from where it is (up to three times), and if that fails asks its mind for another
## perch (FlyMind.on_flight_blocked); with nowhere to go it hovers and looks again. A fly is never put somewhere it did not fly to: the
## only placement is the landing, at the end of its path, within a hand's width of where its last step left it.
## Speeds: a flight climbs toward its top speed at an acceleration (the take-off and the flee burst are quick, a reposition gentle) and
## eases down to the landing speed over the last `landing_slow_wu`. The body turns toward the direction of travel at the turn rate,
## and its up follows the surface it will land on near the end.
## States it drives: TAKEOFF -> FLEE (after takeoff_s) -> SEEK_PERCH (close to the perch) -> PERCHED (landed); REPOSITION -> PERCHED.

const PreyMath = preload("res://scripts/prey/prey_math.gd")
const PerchGraph = preload("res://scripts/prey/perch_graph.gd")
const Fly = preload("res://scripts/prey/fly.gd")
const RecordMath = preload("res://scripts/persistence/record_math.gd")

const MAX_REPLANS := 3
const LAND_TOLERANCE := 0.06
const UP_TURN_DEG_S := 540.0

var fly: Node3D
var path: PackedVector3Array = PackedVector3Array()
var length: float = 0.0
var s: float = 0.0
var speed: float = 0.0
## "flee", "move" or "" when not flying; "open" targets nothing.
var mode: StringName = &""
var target: PerchGraph.Perch
var started_at: float = 0.0
var replans: int = 0
var blocked_ticks: int = 0
var replans_total: int = 0
var retargets_total: int = 0
var flights_total: int = 0
var landings_total: int = 0
var sweeps_total: int = 0
## The largest distance moved in a tick (tests: a fly never jumps).
var max_step: float = 0.0
var last_flight_s: float = 0.0


func _init(f: Node3D) -> void:
	fly = f


## Starts a flight along a planned path to a perch (or into the open air when `perch` is null). `from_air`: the fly is already flying and keeps its speed.
func begin(plan: PerchGraph.Flight, perch: PerchGraph.Perch, new_mode: StringName, now: float, from_air: bool) -> void:
	release_target()
	path = plan.points
	length = plan.length
	s = 0.0
	speed = fly.velocity.length() if from_air else 0.0
	mode = new_mode
	target = perch
	started_at = now
	replans = 0
	blocked_ticks = 0
	flights_total += 1
	if target != null:
		target.reserved_by = fly.id
	if not from_air and fly.perch != null and fly.perch.occupant == fly.id:
		fly.perch.occupant = ""


## Lets go of the perch it was flying to.
func release_target() -> void:
	if target != null and target.reserved_by == fly.id:
		target.reserved_by = ""
	target = null


## Nowhere to go for now: stands still in the air.
func hover(_now: float) -> void:
	path = PackedVector3Array()
	length = 0.0
	s = 0.0
	speed = 0.0
	release_target()


func step(now: float, dt: float) -> void:
	var f := fly
	var p: RefCounted = f.profile
	var here: Vector3 = f.global_position
	if length <= 1.0e-6 or path.size() < 2:
		# hovering (or a path that never left the ground): the speed bleeds away and the mind looks for a place
		speed = PreyMath.step_speed(speed, 0.0, p.takeoff_accel_wu_s2, dt)
		if path.size() == 1 and f.state != Fly.State.SEEK_PERCH:
			f.transition(Fly.State.SEEK_PERCH, "nowhere clear to go, hovering")
		return
	var top: float = p.flee_speed_wu_s if (f.state == Fly.State.TAKEOFF or f.state == Fly.State.FLEE) else p.cruise_speed_wu_s
	var accel: float = p.takeoff_accel_wu_s2 if (f.state == Fly.State.TAKEOFF or f.state == Fly.State.FLEE) else p.cruise_accel_wu_s2
	var remaining := length - s
	var wanted: float = top
	if target != null:
		wanted = PreyMath.target_speed(remaining, top, p.landing_speed_wu_s, p.landing_slow_wu)
	speed = PreyMath.step_speed(speed, wanted, accel, dt)
	var s_next := minf(length, s + speed * dt)
	var next := PreyMath.point_at(path, s_next)
	sweeps_total += 1
	var graph = f.world.graph
	if graph.sweep(f.world.space(), here, next, p.clearance_radius_wu) < graph.SAFE:
		_blocked(now)
		return
	f.global_position = next
	s = s_next
	max_step = maxf(max_step, here.distance_to(next))
	_turn(here, next, dt)
	_advance_state(now)
	if s >= length - 1.0e-4:
		_arrive(now)


func _turn(here: Vector3, next: Vector3, dt: float) -> void:
	var f := fly
	var p: RefCounted = f.profile
	var delta := next - here
	var flat := Vector3(delta.x, 0.0, delta.z)
	if flat.length() > 0.004:
		var angle: float = f.heading.signed_angle_to(flat.normalized(), Vector3.UP)
		var limit := deg_to_rad(p.turn_rate_deg_s) * dt
		f.heading = f.heading.rotated(Vector3.UP, clampf(angle, -limit, limit)).normalized()
	var up_target := Vector3.UP
	if target != null and length - s <= p.approach_wu + p.landing_slow_wu:
		up_target = target.normal
	var rate := deg_to_rad(UP_TURN_DEG_S) * dt
	var angle_up: float = f.normal.angle_to(up_target)
	if angle_up > 1.0e-4:
		var axis: Vector3 = f.normal.cross(up_target)
		f.normal = f.normal.rotated(axis.normalized(), minf(angle_up, rate)) if axis.length_squared() > 1.0e-10 else up_target
	f._apply_basis()


func _advance_state(now: float) -> void:
	var f := fly
	var p: RefCounted = f.profile
	if f.state == Fly.State.TAKEOFF and now - f.state_since >= p.takeoff_s:
		f.transition(Fly.State.FLEE, "airborne after %.2f s, %.1f WU/s" % [now - f.state_since, speed])
	elif f.state == Fly.State.FLEE and target != null and length - s <= p.approach_wu + p.landing_slow_wu:
		f.transition(Fly.State.SEEK_PERCH, "%.1f WU from %s, easing in" % [length - s, target.id])


func _arrive(now: float) -> void:
	var f := fly
	if target == null:
		# the open-air escape is over: look for a perch
		hover(now)
		if f.state != Fly.State.SEEK_PERCH:
			f.transition(Fly.State.SEEK_PERCH, "the open-air escape ended, looking for a perch")
		return
	var rest: Vector3 = target.rest_point(f.profile.hover_wu)
	if f.global_position.distance_to(rest) > LAND_TOLERANCE:
		_blocked(now)
		return
	var perch := target
	var h: Vector3 = f.heading
	release_target()
	var kind := mode
	last_flight_s = now - started_at
	landings_total += 1
	mode = &""
	path = PackedVector3Array()
	length = 0.0
	s = 0.0
	speed = 0.0
	f.place_on(perch, now)
	f.face(h)
	f.goal_since = now
	f.set_goal(&"rest", "landed on %s" % perch.id)
	f.transition(Fly.State.PERCHED, "landed on %s after a %s flight of %.1f s (%d re-plans)" % [perch.id, str(kind), last_flight_s, replans])


func _blocked(now: float) -> void:
	var f := fly
	blocked_ticks += 1
	if target != null and replans < MAX_REPLANS:
		replans += 1
		replans_total += 1
		var threat_pos: Variant = f.senses.last_seen_position if (f.senses.has_last_seen and mode == &"flee") else null
		var plan: PerchGraph.Flight = f.world.graph.plan(f.world.space(), f.global_position, Vector3.ZERO, target, f.profile, threat_pos)
		if plan.ok:
			path = plan.points
			length = plan.length
			s = 0.0
			return
	retargets_total += 1
	f.mind.on_flight_blocked(now)


## T09: the flight in progress (its swept path, how far along, the perch it has reserved) as a plain record; empty when not flying.
func to_record() -> Dictionary:
	return {"path": RecordMath.path_to_array(path), "length": length, "s": s, "speed": speed, "mode": str(mode),
		"target": target.id if target != null else "", "started_at": started_at, "replans": replans, "blocked_ticks": blocked_ticks}


func apply_record(r: Dictionary, find_perch: Callable) -> void:
	path = RecordMath.array_to_path(r["path"])
	length = float(r["length"])
	s = float(r["s"])
	speed = float(r["speed"])
	mode = StringName(str(r["mode"]))
	target = find_perch.call(str(r["target"])) if str(r["target"]) != "" else null
	started_at = float(r["started_at"])
	replans = int(r["replans"])
	blocked_ticks = int(r["blocked_ticks"])
