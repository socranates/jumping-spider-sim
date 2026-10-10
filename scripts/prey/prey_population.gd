extends RefCounted
## PreyPopulation: how many flies the world keeps and how a lost one is replaced (T07, spec 8.3). This is the documented P0
## replenishment rule; every number in it is data in the fly profile's "population" section.
##
## The rule
##   1. The world keeps `target` free flies. A fly stops counting the moment it is captured (it is in the jaws, no longer part of the room).
##   2. Each fly short of the target is replaced after a delay: one replacement is scheduled `replenish_delay_s` (25 to 45 s) after the loss
##      is noticed, a draw of this class's own seeded stream. Nothing the player does feeds the draw except by causing the loss.
##   3. A replacement comes in through one of the lab's authored vents (dark slits high in the walls) and only through one that is, right
##      now and at the ask before this one,
##        * valid: checked against the physics world like any perch (a surface under it, room to lift off, a flight to somewhere);
##        * out of the picture: its centre and both ends of the slit are outside the real camera's field of view, widened by
##          `vent_view_margin_deg` on every side (the camera's own field of view and aspect, never narrower than 16:9);
##        * out of the spider's sight: farther than its range, or outside the field its eyes cover, or with the world between;
##        * at least `vent_min_distance_wu` from the spider, free, and not used by an entry in the last few seconds.
##      "Two asks in a row" is half a second: a flick of the camera cannot catch a fly coming in.
##   4. When no vent qualifies it waits and asks again every `replenish_retry_s`. It never comes in view.
##   5. The fly appears on the vent and flies at once to a perch picked by the same wishes a fly has for moving (food, shelter, the trip) and
##      planned with sweeps (a flight of at least `entry_min_flight_wu`, keeping clear of the spider). It is never put anywhere else. From the
##      first tick it is an ordinary fly with streams and senses of its own.
## Whoever asks "was it in view?" afterwards has the history: for every entry the vent, the checks that let it through, and how long it waited.

const PreyMath = preload("res://scripts/prey/prey_math.gd")
const PerchGraph = preload("res://scripts/prey/perch_graph.gd")

## A vent rests this long after a fly came in through it.
const VENT_REST_S := 6.0
## Candidate perches planned with sweeps from one vent.
const ENTRY_TRIES := 4
const SLIT_HALF_WIDTH := 0.8
const MIN_ASPECT := 16.0 / 9.0
const HISTORY_MAX := 64
const DEFERRALS_MAX := 64
## The wish for an entry perch is jittered by up to this much so entries do not always end in the same place.
const JITTER := 0.25

## The PreyDirector.
var director: Node3D
var enabled: bool = false
var target: int = 0
## How long a vent rests after a fly came in through it (seconds).
var vent_rest_s: float = VENT_REST_S
## The vents, checked like perches but never chosen as a place to sit.
var vents: Array[PerchGraph.Perch] = []
## The replacements to come, earliest first: when the loss was noticed, the delay drawn, and when each is due.
var pending: Array[Dictionary] = []
## Every entry made: t, fly, vent, target, due, waited_s, flight_wu, spider_distance, the checks.
var history: Array[Dictionary] = []
## The asks that found no vent: t, and what stopped each vent.
var deferrals: Array[Dictionary] = []
var last_blockers: Dictionary = {}
var losses_noticed: int = 0
var asks_total: int = 0
var deferred_total: int = 0
var entries_total: int = 0
var plans_total: int = 0
var plans_failed: int = 0
var view_checks_total: int = 0
var sensor_checks_total: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _vent_free_at: Dictionary = {}
var _ok_before: Dictionary = {}
var _last_ask_t: float = -1.0e9
var _next_ask: float = 0.0
var _weights: Dictionary = {}


func _init(owner_director: Node3D, stream_seed: int) -> void:
	director = owner_director
	rng.seed = stream_seed


## Takes the authored vents (id, position, normal) as unregistered perches. Call once; validate() asks the physics world.
func set_vents(list: Array) -> void:
	vents.clear()
	for d: Dictionary in list:
		vents.append(director.graph.make_perch(d))


## Checks every vent against the physics world: a surface under it, the body's room at rest and to lift, and a flight to somewhere. A vent
## that fails is kept with the reason and never used. Returns {"valid": n, "refused": {id: reason}}.
func validate(space: PhysicsDirectSpaceState3D) -> Dictionary:
	var profile: RefCounted = director.profile
	var graph: PerchGraph = director.graph
	_weights = profile.weights()
	var refused := {}
	var valid := 0
	for v in vents:
		var why := graph.validate_perch(space, v, profile)
		if why == "" and not graph.has_link(space, v, profile):
			v.valid = false
			v.refusal = "unreachable"
			why = "unreachable"
		if why == "":
			valid += 1
		else:
			refused[v.id] = why
	return {"valid": valid, "refused": refused}


# ------------------------------------------------------------------ the tick

## Once per tick, before the flies are stepped.
func step(now: float) -> void:
	if not enabled or target <= 0:
		return
	_notice_losses(now)
	if pending.is_empty() or now < float(pending[0]["due"]) or now < _next_ask:
		return
	ask(now)


func free_count() -> int:
	var n := 0
	for f in director.flies:
		if f.is_alive():
			n += 1
	return n


func _notice_losses(now: float) -> void:
	var profile: RefCounted = director.profile
	var missing := target - free_count() - pending.size()
	while missing > 0:
		var delay := PreyMath.draw(rng, profile.replenish_delay_s)
		pending.append({"lost": now, "delay": delay, "due": now + delay})
		losses_noticed += 1
		missing -= 1
		if pending.size() > 1:
			pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["due"]) < float(b["due"]))


## One ask: the vents that qualify now and did at the last ask; one of them is chosen by a draw and a fly comes in. No vent, no entry:
## the ask is counted as a deferral with what stopped each vent.
func ask(now: float) -> Node3D:
	var profile: RefCounted = director.profile
	asks_total += 1
	if now - _last_ask_t > profile.replenish_retry_s * 1.6:
		_ok_before = {}   # the last ask is too old to count as "the ask before"
	_last_ask_t = now
	_next_ask = now + profile.replenish_retry_s
	var blockers := {}
	var ok_now := {}
	var settled: Array[PerchGraph.Perch] = []
	for v in vents:
		var why := blocker(v, now)
		blockers[v.id] = why if why != "" else "ok"
		if why == "":
			ok_now[v.id] = true
			if _ok_before.has(v.id):
				settled.append(v)
	_ok_before = ok_now
	last_blockers = blockers
	if settled.is_empty():
		deferred_total += 1
		deferrals.append({"t": now, "blockers": blockers})
		if deferrals.size() > DEFERRALS_MAX:
			deferrals.pop_front()
		return null
	# the order the vents are tried in is a draw of this stream
	var order: Array[PerchGraph.Perch] = []
	var pool := settled.duplicate()
	while not pool.is_empty():
		order.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	for v in order:
		var choice := plan_entry(v)
		if choice.is_empty():
			continue
		return _enter(v, choice, now, blockers)
	return null


## Why a vent cannot be used now: "" when it can, else the first thing that stops it.
func blocker(v: PerchGraph.Perch, now: float) -> String:
	var profile: RefCounted = director.profile
	if not v.valid or not v.available:
		return "refused"
	if v.occupant != "" or v.reserved_by != "":
		return "occupied"
	if now < float(_vent_free_at.get(v.id, -1.0e9)):
		return "resting"
	var at: Vector3 = v.rest_point(profile.hover_wu)
	var spider: Node3D = director.spider
	if spider == null or not is_instance_valid(spider):
		return "no_spider"
	if at.distance_to(spider.global_position) < profile.vent_min_distance_wu:
		return "too_near"
	if in_camera_view(v):
		return "in_camera_view"
	if spider_sees(at):
		return "seen_by_spider"
	return ""


## True when the vent (its centre or either end of the slit) is inside the camera's field of view, widened by the margin. With no camera
## it cannot be shown to be out of the picture, so it counts as in it.
func in_camera_view(v: PerchGraph.Perch) -> bool:
	var profile: RefCounted = director.profile
	var rig: Node = director.camera_rig
	if rig == null:
		return true
	var cam: Camera3D = rig.camera
	if cam == null or not cam.is_inside_tree():
		return true
	view_checks_total += 1
	var aspect := MIN_ASPECT
	var vp := cam.get_viewport()
	if vp != null:
		var size := vp.get_visible_rect().size
		if size.y > 1.0:
			aspect = maxf(size.x / size.y, MIN_ASPECT)
	var fov_v: float = cam.fov
	if cam.keep_aspect == Camera3D.KEEP_WIDTH:
		fov_v = rad_to_deg(2.0 * atan(tan(deg_to_rad(cam.fov) * 0.5) / aspect))
	var centre: Vector3 = v.rest_point(profile.hover_wu)
	var side: Vector3 = v.normal.cross(Vector3.UP)
	if side.length_squared() < 1.0e-6:
		side = Vector3.RIGHT
	side = side.normalized() * SLIT_HALF_WIDTH
	var xf: Transform3D = cam.global_transform
	var margin: float = profile.vent_view_margin_deg
	for p in [centre, centre + side, centre - side]:
		if PreyMath.in_view(xf, fov_v, aspect, p as Vector3, margin):
			return true
	return false


## True when the spider's eyes could sense a fly at `point`: asked of the sensor itself, so it is the very test a sensed thing passes (within
## its range, inside the field the eyes cover, at least one of the five sample points of the body in plain view). With no sensor it cannot
## be shown that nothing is sensed, so it counts as sensed.
func spider_sees(point: Vector3) -> bool:
	var sensor: Node = director.sensor
	if sensor == null:
		return true
	sensor_checks_total += 1
	return bool(sensor.could_sense(point, float(director.profile.radius_wu)))


# ------------------------------------------------------------------ the entry

## Where a fly coming in through `v` goes and how: {"perch", "flight", "score"}, {} when no flight could be planned. The candidates are the
## free perches at least `entry_min_flight_wu` away, ranked by the wishes a fly has for moving (food, shelter, the trip) and a draw; the
## best few are planned with sweeps, keeping 1.5 WU clear of the spider.
func plan_entry(v: PerchGraph.Perch) -> Dictionary:
	var profile: RefCounted = director.profile
	var graph: PerchGraph = director.graph
	var spider: Node3D = director.spider
	var from: Vector3 = v.rest_point(profile.hover_wu)
	var threat: Vector3 = spider.global_position
	var found: Array[PerchGraph.Perch] = graph.candidates("", from, threat, profile, profile.entry_min_flight_wu, profile.max_flight_wu)
	var ranked: Array[Dictionary] = []
	for c in found:
		var travel := clampf(from.distance_to(c.position) / profile.max_flight_wu, 0.0, 1.0)
		var score := PreyMath.score_move(_weights, 0.0, c.food, c.shelter, travel, 0.0, 0.0) + JITTER * rng.randf()
		ranked.append({"perch": c, "score": score})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"]) or (float(a["score"]) == float(b["score"]) and (a["perch"] as PerchGraph.Perch).id < (b["perch"] as PerchGraph.Perch).id))
	var tried := 0
	for r in ranked:
		if tried >= ENTRY_TRIES:
			break
		tried += 1
		plans_total += 1
		var plan: PerchGraph.Flight = graph.plan(director.space(), from, v.normal, r["perch"] as PerchGraph.Perch, profile, threat)
		if plan.ok:
			return {"perch": r["perch"], "flight": plan, "score": r["score"]}
		plans_failed += 1
	return {}


func _enter(v: PerchGraph.Perch, choice: Dictionary, now: float, blockers: Dictionary) -> Node3D:
	var rec: Dictionary = pending.pop_front()
	var due := float(rec["due"])
	var perch: PerchGraph.Perch = choice["perch"]
	var plan: PerchGraph.Flight = choice["flight"]
	var spider: Node3D = director.spider
	var reason := "replacement: lost at %.0f s, due %.0f s, in through %s at %.0f s (%d of %d vents out of view)" % [float(rec["lost"]), due, v.id, now, _count_ok(blockers), vents.size()]
	var f: Node3D = director.spawn_entry(v, perch, plan, reason)
	_vent_free_at[v.id] = now + vent_rest_s
	entries_total += 1
	var at: Vector3 = v.rest_point(director.profile.hover_wu)
	history.append({"t": now, "fly": f.id if f != null else "", "vent": v.id, "target": perch.id, "due": due, "waited_s": now - due,
		"flight_wu": plan.length, "spider_distance": at.distance_to(spider.global_position), "checks": blockers.duplicate()})
	if history.size() > HISTORY_MAX:
		history.pop_front()
	return f


func _count_ok(blockers: Dictionary) -> int:
	var n := 0
	for k: String in blockers:
		if str(blockers[k]) == "ok":
			n += 1
	return n


## One line for the developer views.
func describe(now: float) -> String:
	if not enabled:
		return "replenishment off"
	var s := "%d of %d free" % [free_count(), target]
	if not pending.is_empty():
		var due := float(pending[0]["due"])
		s += ", next in %.0f s" % maxf(0.0, due - now)
		if now >= due:
			var parts := PackedStringArray()
			for k: String in last_blockers:
				parts.append("%s %s" % [k.trim_prefix("vent_"), str(last_blockers[k])])
			s += " (waiting: %s)" % ", ".join(parts)
	if not history.is_empty():
		var h: Dictionary = history[history.size() - 1]
		s += "; last %s via %s at %.0f s" % [str(h["fly"]), str(h["vent"]), float(h["t"])]
	return s
