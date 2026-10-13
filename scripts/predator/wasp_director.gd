extends Node
## WaspDirector: the black-and-yellow mud dauber's visits to the sill (LIFE_DESIGN round 4; LIFE-03: the first predator; LIFE-01: "death
## can be real and jarring. not sensationalized"; spec 8.3: search, inspect, approach, strike, disengage; spec 2: no threat spawning
## behind the player and no unexplained death).
##
## When. At most one visit a day, in the warm middle of the day (WINDOW_FROM_H to WINDOW_TO_H), never on the first day, never before the
## spider has finished its first meal (the player is still learning), and never while it rests or moults in the crack. Whether a day
## has a visit, and when, follows from the world's seed and the day alone, so a return to a checkpoint meets the same wasp.
##
## Warned. The wasp is heard before it is near: it comes in over the window frame from outside, buzzing, for ARRIVE_S, and it does not
## search until it is on the sill. Its own shadow crosses the sill. When it lands, the spider feels it through its feet if they share a
## surface. When it has seen the spider it turns toward it and comes to look (INSPECT_S at arm's length) before it strikes.
##
## Search by sight. It moves between authored places on the sill where a spider might be (POINTS): it hovers and looks, and on open
## surfaces it may land and walk, its antennae flicking. It knows nothing it has not seen: where it goes does not depend on where the
## spider is. Each tick that it can see the spider (in range, a clear line, not in the retreat) its notice grows, much faster when the
## spider moves than when it keeps still, and faster near than far. Out of sight, notice fades. Full notice: it has found the spider.
##
## Escapes. The silk-lined crack is safe: nothing in the retreat is ever seen. A jump, a drop on the line, or getting out of sight breaks
## its approach; then it is confused for CONFUSE_S and searches somewhere at least FAR_FROM_LOSS_WU away. Its strike is a short lunge
## at where the spider was: a spider that moves off quickly is missed. After SEARCH_S of searching it gives up and flies away.
##
## Caught. The wasp stings and the spider goes still (SpiderMotor.seize); the wasp carries it up and away over the frame. The world
## presents that (round 4: plainly, then back to the last rest; round 5 builds death and continuing on it). The spider is paralysed by
## the sting, not killed, and the notebook says so (LIFE-03).

signal visit_started(first: bool)
signal noticed()
signal lost(why: String)
signal landed(point: Vector3)
signal caught()
signal carried_off()
signal left(escaped: bool)

const Wasp = preload("res://scripts/predator/wasp.gd")
const WaspBody = preload("res://scripts/predator/wasp_body.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")
const SurfaceProfile = preload("res://scripts/core/surface_profile.gd")

enum Phase { AWAY, ARRIVING, SEARCHING, INSPECTING, STRIKING, CARRYING, LEAVING }
const PHASE_NAMES: Array[String] = ["away", "arriving", "searching", "inspecting", "striking", "carrying", "leaving"]

## When it may come.
const FIRST_DAY := 2
const VISIT_CHANCE := 0.6
const WINDOW_FROM_H := 10.0
const WINDOW_TO_H := 15.5
## A visit (game seconds).
const ARRIVE_S := 8.0
const SEARCH_S := 45.0
const LEAVE_S := 5.0
const CARRY_S := 3.5
## How it flies: between places at CRUISE_Y, in over the frame at OVER from ENTRY outside.
const CRUISE_Y := 9.0
const ENTRY := Vector3(38.0, 19.0, 2.0)
const OVER := Vector3(27.0, 15.0, 2.0)
const FLY_SPEED := 4.0
const RADIUS := 0.55              # WU kept clear of the world on its paths
const HOVER_S := Vector2(1.5, 2.5)
const SCAN_DEG_S := 70.0          # how fast it turns while it hovers and looks
const LAND_CHANCE := 0.5
const LAND_S := 0.6
const WALK_S := 2.0
const WALK_SPEED := 0.7
const STEP_EVERY_S := 0.5
## What it sees.
const SIGHT_WU := 7.0
const NOTICE_STILL := 0.25        # notice per second for a still spider at point-blank range
const NOTICE_MOVING := 1.6        # added per second at walking speed
const NOTICE_DECAY := 0.2
const CONFUSE_S := 4.0
const AFTER_LOSS_NOTICE := 0.35
const LOSE_UNSEEN_S := 0.8
const FAR_FROM_LOSS_WU := 6.0
## Inspecting and striking.
const STANDOFF_WU := 1.2
const INSPECT_SPEED := 2.5
const INSPECT_S := 1.5
const INSPECT_GIVE_UP_S := 6.0   # it cannot get to arm's length (the spider is somewhere it cannot fly): it gives up on it
const STRIKE_S := 0.35
const CATCH_WU := 0.8
const HOLD_BELOW := 0.5

## Where it looks for spiders: where it hovers to look, and, on open surfaces, where it may land. Every hover point is open straight up
## to CRUISE_Y (tests check them all).
const POINTS: Array[Dictionary] = [
	{"id": "floor_middle", "hover": Vector3(0.0, 1.6, 6.0), "land": Vector3(0.0, 0.35, 6.0)},
	{"id": "floor_east", "hover": Vector3(14.0, 1.6, 7.0), "land": Vector3(14.0, 0.35, 7.0)},
	{"id": "floor_west", "hover": Vector3(-13.0, 1.6, 7.0), "land": Vector3(-13.0, 0.35, 7.0)},
	{"id": "floor_back", "hover": Vector3(-7.0, 1.6, -9.0), "land": Vector3(-7.0, 0.35, -9.0)},
	{"id": "leaf_west", "hover": Vector3(-15.0, 5.7, -1.5), "land": Vector3(-15.0, 4.55, -1.5)},
	{"id": "leaf_middle", "hover": Vector3(-1.0, 5.7, -1.5), "land": Vector3(-1.0, 4.55, -1.5)},
	{"id": "leaf_east", "hover": Vector3(21.5, 6.9, -3.0), "land": Vector3(21.5, 5.75, -3.0)},
	{"id": "planter", "hover": Vector3(10.0, 6.1, -4.0), "land": Vector3(10.0, 4.95, -4.0)},
	{"id": "back_wall_west", "hover": Vector3(-12.0, 5.0, -11.2)},
	{"id": "back_wall_east", "hover": Vector3(12.0, 7.0, -11.2)},
	{"id": "right_wall", "hover": Vector3(28.6, 4.0, 5.0)},
	{"id": "under_leaf_middle", "hover": Vector3(-1.0, 2.4, 2.3)},
	{"id": "under_leaf_west", "hover": Vector3(-15.0, 2.4, 2.3)},
	{"id": "planter_front", "hover": Vector3(10.0, 2.0, 1.5)},
	{"id": "crack_mouth", "hover": Vector3(-20.8, 1.6, 6.0)},
]

var world: Node3D
## False: it never comes by itself (test worlds; force_visit still brings it).
var enabled := true
var seed_value := 0
var wasp: Node3D
var phase: int = Phase.AWAY
## Seconds into this visit, and into this phase.
var visit_s := 0.0
var phase_s := 0.0
var search_left := 0.0
var notice := 0.0
var confused_s := 0.0
var noticed_this_visit := false
## Kept in checkpoints: the day of the last visit, and how many visits and escapes this life has had.
var last_visit_day := 0
var visits := 0
var escapes := 0
## This visit's events, each {"kind", "t"} (seconds into the visit), for tests and the developer views.
var events: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _path := PackedVector3Array()
var _path_i := 0
var _speed := FLY_SPEED
var _point := -1
var _recent: Array[int] = []
var _sub := ""          # searching: "fly", "hover", "land", "walk", "takeoff"
var _sub_s := 0.0
var _walk_dir := Vector3.ZERO
var _step_s := 0.0
var _open_pos := Vector3.ZERO
var _last_seen := Vector3.ZERO
var _unseen_s := 0.0
var _hold_s := 0.0
var _loss_pos := Vector3.INF
var _strike_from := Vector3.ZERO
var _strike_to := Vector3.ZERO
var _shape := SphereShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()
var _dt := 1.0 / 60.0


func _ready() -> void:
	process_physics_priority = 8  # after the spider has moved (0), before feeding (11) and the habitat loop (12)
	wasp = Wasp.new()
	wasp.name = "Wasp"
	add_child(wasp)
	_shape.radius = RADIUS
	_query.shape = _shape
	_query.collision_mask = Layers.WORLD


func phase_name() -> String:
	return PHASE_NAMES[phase]


func is_visiting() -> bool:
	return phase != Phase.AWAY


## Whether day `day` has a visit, and at what hour: -1 when it has none. From the seed and the day alone.
func planned_hour(day: int) -> float:
	if day < FIRST_DAY:
		return -1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash([seed_value, "wasp", day]) & 0x7fffffff)
	if rng.randf() >= VISIT_CHANCE:
		return -1.0
	return rng.randf_range(WINDOW_FROM_H, WINDOW_TO_H - 1.0)


## Why a visit could not begin now ("" when it could), apart from the hour.
func blocked() -> String:
	var loop: Node = world.get("habitat_loop")
	if loop == null:
		return "no habitat"
	if int(loop.clock.day) < FIRST_DAY:
		return "the first day"
	if int(world.feeding.meals_finished) < 1:
		return "no meal yet"
	if loop.resting or loop.growth.is_moulting():
		return "resting"
	return ""


func _physics_process(delta: float) -> void:
	if world == null:
		return
	step(delta)


func step(delta: float) -> void:
	_dt = delta
	if phase == Phase.AWAY:
		if enabled:
			_maybe_begin()
		return
	visit_s += delta
	phase_s += delta
	match phase:
		Phase.ARRIVING:
			if _advance(delta):
				_open_pos = wasp.global_position
				_set_phase(Phase.SEARCHING)
				_log("searching")
				_sub = "hover"
				_sub_s = _rng.randf_range(HOVER_S.x, HOVER_S.y)
		Phase.SEARCHING:
			search_left -= delta
			_search(delta)
			_look(delta)
			if notice >= 1.0:
				_begin_inspecting()
			elif search_left <= 0.0 and (_sub == "hover" or _sub == "fly"):
				_begin_leaving()
		Phase.INSPECTING:
			_inspect(delta)
		Phase.STRIKING:
			_strike(delta)
		Phase.CARRYING:
			var done := _advance(delta)
			_hold_spider()
			if done:
				_set_phase(Phase.AWAY)
				carried_off.emit()
		Phase.LEAVING:
			if _advance(delta):
				wasp.visible = false
				_set_phase(Phase.AWAY)
				if noticed_this_visit:
					escapes += 1
				_log("left")
				left.emit(noticed_this_visit)


func _maybe_begin() -> void:
	var loop: Node = world.get("habitat_loop")
	if loop == null:
		return
	var day: int = int(loop.clock.day)
	if day == last_visit_day:
		return
	var hour := planned_hour(day)
	if hour < 0.0 or float(loop.clock.hour) < hour or float(loop.clock.hour) >= WINDOW_TO_H:
		return
	if blocked() != "":
		return
	begin_visit(day)


## Brings the wasp now (tests and the developer views). `at`: the id of the place it searches first ("" lets the visit choose). False
## when it is already here.
func force_visit(at: String = "") -> bool:
	if phase != Phase.AWAY:
		return false
	var loop: Node = world.get("habitat_loop")
	begin_visit(int(loop.clock.day) if loop != null else 0, point_index(at))
	return true


## The index of the search place with this id, -1 when there is none.
static func point_index(id: String) -> int:
	for i in POINTS.size():
		if str(POINTS[i]["id"]) == id:
			return i
	return -1


func begin_visit(day: int, first: int = -1) -> void:
	last_visit_day = day
	visits += 1
	_rng.seed = int(hash([seed_value, "wasp-visit", day, visits]) & 0x7fffffff)
	events.clear()
	visit_s = 0.0
	notice = 0.0
	confused_s = 0.0
	noticed_this_visit = false
	search_left = SEARCH_S
	_recent.clear()
	_loss_pos = Vector3.INF
	_point = first if first >= 0 else _rng.randi_range(0, POINTS.size() - 1)
	var to: Vector3 = POINTS[_point]["hover"]
	_path = PackedVector3Array([ENTRY, OVER, Vector3(to.x, CRUISE_Y, to.z), to])
	_path_i = 1
	_speed = _length(_path) / ARRIVE_S
	wasp.place(ENTRY)
	wasp.mode = WaspBody.Mode.FLYING
	wasp.search = 0.0
	wasp.visible = true
	_set_phase(Phase.ARRIVING)
	_log("warning")
	visit_started.emit(visits == 1)


# ------------------------------------------------------------------ searching

func _search(delta: float) -> void:
	match _sub:
		"fly":
			wasp.search = 0.3
			if _advance(delta):
				_open_pos = wasp.global_position
				_sub = "hover"
				_sub_s = _rng.randf_range(HOVER_S.x, HOVER_S.y)
		"hover":
			wasp.mode = WaspBody.Mode.FLYING
			wasp.search = 0.8
			wasp.move_to(wasp.global_position, wasp.heading.rotated(Vector3.UP, deg_to_rad(SCAN_DEG_S) * delta), delta)
			_sub_s -= delta
			if _sub_s <= 0.0:
				var p: Dictionary = POINTS[_point]
				if p.has("land") and _rng.randf() < LAND_CHANCE and search_left > LAND_S + WALK_S:
					_sub = "land"
					_path = PackedVector3Array([wasp.global_position, p["land"]])
					_path_i = 1
					_speed = wasp.global_position.distance_to(p["land"]) / LAND_S
				else:
					_next_point()
		"land":
			if _advance(delta):
				wasp.mode = WaspBody.Mode.WALKING
				wasp.normal = Vector3.UP
				_open_pos = wasp.global_position
				_shake("heavy landing")
				_log("landed")
				landed.emit(wasp.global_position)
				_sub = "walk"
				_sub_s = WALK_S
				_step_s = STEP_EVERY_S
				_walk_dir = Vector3.FORWARD.rotated(Vector3.UP, _rng.randf_range(0.0, TAU))
		"walk":
			wasp.search = 1.0
			_walk(delta)
			_sub_s -= delta
			if _sub_s <= 0.0:
				_sub = "takeoff"
				var up := wasp.global_position + Vector3.UP * 1.2
				_path = PackedVector3Array([wasp.global_position, up])
				_path_i = 1
				_speed = FLY_SPEED * 0.5
				wasp.mode = WaspBody.Mode.FLYING
		"takeoff":
			if _advance(delta):
				_open_pos = wasp.global_position
				_next_point()


## A few steps along the surface it stands on, turning back where it would step off.
func _walk(delta: float) -> void:
	var p := wasp.global_position
	var next := p + _walk_dir * WALK_SPEED * delta
	var ground := _ray(next + Vector3.UP * 0.3, next + Vector3.DOWN * 0.8)
	if ground.is_empty() or not _clear(p, next):
		_walk_dir = -_walk_dir
		next = p
	wasp.move_to(next, _walk_dir, delta)
	_step_s -= delta
	if _step_s <= 0.0:
		_step_s = STEP_EVERY_S
		_shake("heavy footsteps")


func _next_point() -> void:
	_recent.append(_point)
	while _recent.size() > 3:
		_recent.pop_front()
	var here := wasp.global_position
	var choices: Array[int] = []
	for i in POINTS.size():
		if _recent.has(i):
			continue
		var hover: Vector3 = POINTS[i]["hover"]
		if _loss_pos.is_finite() and hover.distance_to(_loss_pos) < FAR_FROM_LOSS_WU:
			continue
		choices.append(i)
	if choices.is_empty():
		choices.append((_point + 1) % POINTS.size())
	# A local search: the nearer half of the places it has not just looked at.
	choices.sort_custom(func(a: int, b: int) -> bool:
		return here.distance_to(POINTS[a]["hover"]) < here.distance_to(POINTS[b]["hover"]))
	var near := choices.slice(0, maxi(1, (choices.size() + 1) / 2))
	_point = near[_rng.randi_range(0, near.size() - 1)]
	_fly_to(POINTS[_point]["hover"], FLY_SPEED)
	_sub = "fly"


# ------------------------------------------------------------------ seeing the spider

## Whether it can see the spider now: in range, nothing in the way, and not in the retreat.
func can_see_spider() -> bool:
	var s: Node3D = world.spider
	if s == null or not is_instance_valid(s) or s.get("seized") == true or not wasp.visible:
		return false
	if world.lab.in_retreat(s.global_position):
		return false
	var eye: Vector3 = wasp.eye_position()
	if eye.distance_to(s.global_position) > SIGHT_WU:
		return false
	return _ray(eye, s.global_position).is_empty()


## How fast notice grows now (per second) if it can see the spider.
func notice_rate() -> float:
	var s: Node3D = world.spider
	var d: float = wasp.eye_position().distance_to(s.global_position)
	var walk: float = maxf(float(s.get("_walk_speed")), 0.1)
	var motion := clampf(s.velocity.length() / walk, 0.0, 1.5)
	if s.is_airborne():
		motion = 1.5
	return (NOTICE_STILL + NOTICE_MOVING * motion) * maxf(1.0 - d / SIGHT_WU, 0.0)


func _look(delta: float) -> void:
	if confused_s > 0.0:
		confused_s -= delta
		return
	if can_see_spider():
		notice += notice_rate() * delta
		_last_seen = world.spider.global_position
	else:
		notice = maxf(notice - NOTICE_DECAY * delta, 0.0)


func _begin_inspecting() -> void:
	notice = 1.0
	noticed_this_visit = true
	_unseen_s = 0.0
	_hold_s = 0.0
	if wasp.mode == WaspBody.Mode.WALKING:
		wasp.mode = WaspBody.Mode.FLYING
	_set_phase(Phase.INSPECTING)
	_log("noticed")
	noticed.emit()


## Comes to look: to arm's length from where it last saw the spider, then holds there, antennae busy, for INSPECT_S, then strikes. A
## jump, a drop, the retreat, or the spider out of sight for LOSE_UNSEEN_S, and it has lost it.
func _inspect(delta: float) -> void:
	var s: Node3D = world.spider
	wasp.mode = WaspBody.Mode.FLYING
	wasp.search = 1.0
	if world.lab.in_retreat(s.global_position):
		_lose("hid")
		return
	if s.state == s.State.AIRBORNE:
		_lose("jumped")
		return
	if s.state == s.State.FALLING:
		_lose("dropped")
		return
	if can_see_spider():
		_unseen_s = 0.0
		_last_seen = s.global_position
	else:
		_unseen_s += delta
		if _unseen_s > LOSE_UNSEEN_S:
			_lose("out of sight")
			return
	if phase_s > INSPECT_GIVE_UP_S:
		_lose("out of reach")
		return
	var away := wasp.global_position - _last_seen
	if away.length() < 1e-3:
		away = Vector3.UP
	var standoff := _last_seen + away.normalized() * STANDOFF_WU
	var to := standoff - wasp.global_position
	var step := INSPECT_SPEED * delta
	var face := _last_seen - wasp.global_position
	if to.length() > 0.05:
		var next := wasp.global_position + to.limit_length(step)
		if _clear(wasp.global_position, next):
			wasp.move_to(next, face, delta)
		else:
			wasp.move_to(wasp.global_position, face, delta)
		_hold_s = maxf(_hold_s - delta, 0.0)
	else:
		wasp.move_to(wasp.global_position, face, delta)
		_hold_s += delta
		if _hold_s >= INSPECT_S:
			_strike_from = wasp.global_position
			_strike_to = s.global_position
			_set_phase(Phase.STRIKING)
			_log("strike")


func _strike(delta: float) -> void:
	var k := clampf(phase_s / STRIKE_S, 0.0, 1.0)
	wasp.move_to(_strike_from.lerp(_strike_to, k), _strike_to - _strike_from, delta)
	if k < 1.0:
		return
	var s: Node3D = world.spider
	if wasp.global_position.distance_to(s.global_position) <= CATCH_WU and not world.lab.in_retreat(s.global_position) \
			and s.state != s.State.AIRBORNE:
		_catch()
	else:
		_lose("missed")


func _catch() -> void:
	var s: Node3D = world.spider
	if s.has_method("seize"):
		s.seize()
	wasp.mode = WaspBody.Mode.HOLDING
	wasp.search = 0.0
	var p := wasp.global_position
	_path = PackedVector3Array([p, p + Vector3.UP * 2.5, OVER])
	_path_i = 1
	_speed = _length(_path) / CARRY_S
	_set_phase(Phase.CARRYING)
	_log("caught")
	_hold_spider()
	caught.emit()


func _hold_spider() -> void:
	var s: Node3D = world.spider
	if s != null and is_instance_valid(s) and s.get("seized") == true:
		s.global_position = wasp.global_position + Vector3.DOWN * HOLD_BELOW


func _lose(why: String) -> void:
	_loss_pos = _last_seen
	notice = AFTER_LOSS_NOTICE
	confused_s = CONFUSE_S
	_set_phase(Phase.SEARCHING)
	_log("lost:" + why)
	lost.emit(why)
	_next_point()


func _begin_leaving() -> void:
	var p := wasp.global_position
	var path := _route(p, OVER)
	path.append(ENTRY)
	_path = path
	_path_i = 1
	_speed = _length(_path) / LEAVE_S
	wasp.mode = WaspBody.Mode.FLYING
	wasp.search = 0.0
	_set_phase(Phase.LEAVING)
	_log("leaving")


# ------------------------------------------------------------------ paths and the world

func _fly_to(to: Vector3, speed: float) -> void:
	_path = _route(wasp.global_position, to)
	_path_i = 1
	_speed = speed


## Up to cruising height (from somewhere open above it), across, and down to `to`.
func _route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var path := PackedVector3Array([from])
	var start := from
	if from.y < CRUISE_Y and not _clear(from, Vector3(from.x, CRUISE_Y, from.z)):
		path.append(_open_pos)
		start = _open_pos
	if start.y < CRUISE_Y:
		path.append(Vector3(start.x, CRUISE_Y, start.z))
	if to.y < CRUISE_Y:
		path.append(Vector3(to.x, CRUISE_Y, to.z))
	path.append(to)
	return path


## Moves along the path at the current speed; true at its end.
func _advance(delta: float) -> bool:
	var p: Vector3 = wasp.global_position
	var left := _speed * delta
	while _path_i < _path.size() and left > 0.0:
		var target := _path[_path_i]
		var d := p.distance_to(target)
		if d <= left:
			p = target
			left -= d
			_path_i += 1
		else:
			p += (target - p) / d * left
			left = 0.0
	var dir := p - wasp.global_position
	wasp.move_to(p, dir if dir.length() > 1e-5 else wasp.heading, _dt)
	return _path_i >= _path.size()


func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return maxf(total, 1e-3)


## True when a sphere of RADIUS moves from `a` to `b` without touching the world.
func _clear(a: Vector3, b: Vector3) -> bool:
	if a.distance_to(b) < 1e-5:
		return true
	_query.transform = Transform3D(Basis.IDENTITY, a)
	_query.motion = b - a
	var r: PackedFloat32Array = world.get_world_3d().direct_space_state.cast_motion(_query)
	return r.size() > 0 and r[0] >= 0.9999


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD))


func _shake(kind: String) -> void:
	var v: Node = world.get("vibration")
	if v != null and v.has_method("shake"):
		v.shake(wasp.global_position + Vector3.DOWN * 0.35, kind, wasp)


func _set_phase(p: int) -> void:
	phase = p
	phase_s = 0.0


func _log(kind: String) -> void:
	events.append({"kind": kind, "t": visit_s})


# ------------------------------------------------------------------ checkpoints

func to_dict() -> Dictionary:
	return {"last_visit_day": last_visit_day, "visits": visits, "escapes": escapes}


## The record of a life the wasp has not yet visited.
static func default_record() -> Dictionary:
	return {"last_visit_day": 0, "visits": 0, "escapes": 0}


func load_dict(d: Dictionary) -> void:
	last_visit_day = int(d.get("last_visit_day", 0))
	visits = int(d.get("visits", 0))
	escapes = int(d.get("escapes", 0))


static func problems(d: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if not d is Dictionary:
		out.append("wasp: not a record")
		return out
	for key in ["last_visit_day", "visits", "escapes"]:
		var v: Variant = (d as Dictionary).get(key)
		if not (v is int or v is float) or float(v) < 0.0 or float(v) != floorf(float(v)):
			out.append("wasp: %s must be a whole number, not negative" % key)
	if out.is_empty() and int(d["escapes"]) > int(d["visits"]):
		out.append("wasp: more escapes than visits")
	return out
