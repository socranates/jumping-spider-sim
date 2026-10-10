extends RefCounted
## PerchGraph: where a fly may sit and how it gets from one place to another (spec 8.3, 19.3). Perches are authored points on
## surfaces of the lab (a position, the surface normal, how sheltered the place is, how much food is there). Nothing is trusted until the
## physics world has been asked:
##   * a perch needs a surface under it (a ray along the normal finds one within a hand's width of the authored point, turned the way
##     the author said); the point is snapped to what was found;
##   * the fly's clearance sphere must fit at the resting point without touching the world, and a straight lift of `lift_wu` off the
##     surface must be clear;
##   * after that, every perch must be linked to at least one other by a flight that can really be flown. A perch that fails is kept,
##     with the reason it was refused, and is never chosen; the developer view lists them.
## A flight is a short polyline: lift off the surface, cross, approach the new perch along its normal, settle. Each leg is swept with the
## clearance sphere (cast_motion). When the straight crossing is blocked the planner tries to go over: the middle of the crossing raised
## by a few set heights, never above the ceiling. A flight that cannot be planned is refused with a reason (blocked, too far, passes the
## threat); the fly then asks for another perch. Nothing here moves a fly: the planner only says what could be flown.

const PreyMath = preload("res://scripts/prey/prey_math.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")

## Flights stay under this height (the lab's walls are 12 WU high).
const CEILING_Y := 11.0
const APEX_HEIGHTS: Array[float] = [2.5, 5.0, 8.0, 11.0]
## Heights for the up-and-over routes when no raised crossing is clear.
const OVER_HEIGHTS: Array[float] = [6.0, 9.0, 11.0]
const SNAP_TOLERANCE := 0.06
const NORMAL_TOLERANCE_DEG := 12.0
const LINK_TRIES := 5
const SAFE := 0.9999


class Perch extends RefCounted:
	var id: String = ""
	var position: Vector3 = Vector3.ZERO
	var normal: Vector3 = Vector3.UP
	var surface_id: String = ""
	var kind: String = ""
	var shelter: float = 0.3
	var food: float = 0.0
	## Part of the default population's places.
	var start: bool = false
	## Added by a test fixture: never picked by the default population.
	var fixture: bool = false
	var valid: bool = false
	var refusal: String = "not validated"
	## False while its surface is out of the world.
	var available: bool = true
	var occupant: String = ""
	var reserved_by: String = ""

	func rest_point(hover: float) -> Vector3:
		return position + normal * hover

	func is_free_for(fly_id: String) -> bool:
		return valid and available and (occupant == "" or occupant == fly_id) and (reserved_by == "" or reserved_by == fly_id)


class Flight extends RefCounted:
	var ok: bool = false
	var reason: String = ""
	var points: PackedVector3Array = PackedVector3Array()
	var length: float = 0.0
	var target_id: String = ""
	## The height of the raised crossing if the straight one was blocked, -1 when it was straight.
	var apex: float = -1.0


var perches: Dictionary = {}
var order: Array[String] = []
## Counters for the cost report.
var sweeps_total: int = 0
var plans_total: int = 0
var plans_failed: int = 0
var rays_total: int = 0

var _sphere: SphereShape3D = SphereShape3D.new()
var _query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


func _init() -> void:
	_query.shape = _sphere
	_query.collision_mask = Layers.WORLD
	_ray.collision_mask = Layers.WORLD


## Adds a perch from authored data: id, position, normal, shelter, food, kind, start.
func add_perch(d: Dictionary) -> Perch:
	var perch := make_perch(d)
	if not perches.has(perch.id):
		order.append(perch.id)
	perches[perch.id] = perch
	return perch


## A perch from authored data that is not part of the graph (a vent a replacement comes in through: checked like any perch, never chosen
## as a place to sit).
func make_perch(d: Dictionary) -> Perch:
	var perch := Perch.new()
	perch.id = str(d["id"])
	perch.position = d["position"]
	perch.normal = (d.get("normal", Vector3.UP) as Vector3).normalized()
	perch.shelter = clampf(float(d.get("shelter", 0.3)), 0.0, 1.0)
	perch.food = clampf(float(d.get("food", 0.0)), 0.0, 1.0)
	perch.kind = str(d.get("kind", ""))
	perch.start = bool(d.get("start", false))
	perch.fixture = bool(d.get("fixture", false))
	return perch


func get_perch(id: String) -> Perch:
	return perches.get(id)


func remove_perch(id: String) -> void:
	perches.erase(id)
	order.erase(id)


func all() -> Array[Perch]:
	var out: Array[Perch] = []
	for id in order:
		out.append(perches[id])
	return out


## Marks every perch on a surface that left the world (or came back). Returns the perches whose availability changed.
func set_surface_available(surface_id: String, available: bool) -> Array[Perch]:
	var changed: Array[Perch] = []
	for id in order:
		var perch: Perch = perches[id]
		if perch.surface_id == surface_id and perch.available != available:
			perch.available = available
			changed.append(perch)
	return changed


# ------------------------------------------------------------------ the world questions

## Fraction of the way from `from` to `to` that a sphere of `radius` can go before the world stops it (1 when it can all the way).
func sweep(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, radius: float) -> float:
	sweeps_total += 1
	var motion := to - from
	if motion.length_squared() < 1.0e-10:
		return 1.0
	_sphere.radius = radius
	_query.transform = Transform3D(Basis.IDENTITY, from)
	_query.motion = motion
	var result := space.cast_motion(_query)
	return 1.0 if result.is_empty() else float(result[0])


func sweep_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, radius: float) -> bool:
	return sweep(space, from, to, radius) >= SAFE


## True when a sphere of `radius` at `point` touches the world.
func overlaps(space: PhysicsDirectSpaceState3D, point: Vector3, radius: float) -> bool:
	_sphere.radius = radius
	_query.transform = Transform3D(Basis.IDENTITY, point)
	_query.motion = Vector3.ZERO
	return not space.intersect_shape(_query, 1).is_empty()


# ------------------------------------------------------------------ validation

## Asks the world about one perch. Returns "" when it is a place a fly can sit and leave, else why not (it is also stored on the perch).
func validate_perch(space: PhysicsDirectSpaceState3D, perch: Perch, p: RefCounted) -> String:
	perch.valid = false
	var n := perch.normal
	rays_total += 1
	_ray.from = perch.position + n * 0.5
	_ray.to = perch.position - n * 0.5
	var hit := space.intersect_ray(_ray)
	if hit.is_empty():
		return _refuse(perch, "no_surface")
	var snapped := hit["position"] as Vector3
	if absf((snapped - perch.position).dot(n)) > SNAP_TOLERANCE:
		return _refuse(perch, "no_surface")
	if rad_to_deg(n.angle_to(hit["normal"] as Vector3)) > NORMAL_TOLERANCE_DEG:
		return _refuse(perch, "wrong_normal")
	perch.position = snapped
	var collider := hit["collider"] as Object
	if collider != null and collider.has_meta("surface_id"):
		perch.surface_id = str(collider.get_meta("surface_id"))
	var rest: Vector3 = perch.rest_point(p.hover_wu)
	if overlaps(space, rest, p.clearance_radius_wu):
		return _refuse(perch, "blocked_at_rest")
	if not sweep_clear(space, rest, perch.position + n * (p.hover_wu + p.lift_wu), p.clearance_radius_wu):
		return _refuse(perch, "no_room_to_lift")
	perch.valid = true
	perch.refusal = ""
	return ""


func _refuse(perch: Perch, why: String) -> String:
	perch.valid = false
	perch.refusal = why
	return why


## Validates every perch, then keeps only those that are linked to another by a flight that can be flown. Returns {"valid": n, "refused": {id: reason}}.
func validate_all(space: PhysicsDirectSpaceState3D, p: RefCounted) -> Dictionary:
	for id in order:
		validate_perch(space, perches[id], p)
	for id in order:
		var perch: Perch = perches[id]
		if perch.valid and not has_link(space, perch, p):
			_refuse(perch, "unreachable")
	return summary()


func summary() -> Dictionary:
	var valid := 0
	var refused := {}
	for id in order:
		var perch: Perch = perches[id]
		if perch.valid:
			valid += 1
		else:
			refused[id] = perch.refusal
	return {"valid": valid, "refused": refused}


## True when some other valid perch can be reached from this one (the nearest few are tried).
func has_link(space: PhysicsDirectSpaceState3D, perch: Perch, p: RefCounted) -> bool:
	var others: Array[Perch] = []
	for id in order:
		var o: Perch = perches[id]
		if o != perch and o.valid and not o.fixture:
			others.append(o)
	others.sort_custom(func(a: Perch, b: Perch) -> bool:
		var da := perch.position.distance_squared_to(a.position)
		var db := perch.position.distance_squared_to(b.position)
		return da < db or (da == db and a.id < b.id))
	var tries := 0
	for o in others:
		if perch.position.distance_to(o.position) > p.max_flight_wu:
			continue
		tries += 1
		if tries > LINK_TRIES:
			break
		if plan(space, perch.rest_point(p.hover_wu), perch.normal, o, p).ok:
			return true
	return false


# ------------------------------------------------------------------ planning

## A flight from `start` (a fly's centre) to a perch. `start_normal` is the surface it leaves (a fly already in the air passes ZERO and
## goes straight on). `threat`, when given, is a point the flight must keep `path_threat_clearance_wu` away from. Every leg is swept.
func plan(space: PhysicsDirectSpaceState3D, start: Vector3, start_normal: Vector3, to: Perch, p: RefCounted, threat: Variant = null) -> Flight:
	plans_total += 1
	var f := Flight.new()
	f.target_id = to.id
	var r: float = p.clearance_radius_wu
	var lifted: Vector3 = start + start_normal * float(p.lift_wu) if start_normal.length_squared() > 0.5 else start
	var approach: Vector3 = to.position + to.normal * float(p.hover_wu + p.approach_wu)
	var rest: Vector3 = to.rest_point(p.hover_wu)
	if start.distance_to(rest) > p.max_flight_wu:
		return _fail(f, "too_far")
	if lifted != start and not sweep_clear(space, start, lifted, r):
		return _fail(f, "blocked_lift")
	if not sweep_clear(space, approach, rest, r):
		return _fail(f, "blocked_landing")
	var routes: Array[PackedVector3Array] = []
	routes.append(PackedVector3Array([lifted, approach]))
	var mid: Vector3 = (lifted + approach) * 0.5
	for h in APEX_HEIGHTS:
		var apex := Vector3(mid.x, minf(mid.y + h, CEILING_Y), mid.z)
		if apex.y > mid.y + 0.5:
			routes.append(PackedVector3Array([lifted, apex, approach]))
	# up and over: straight up from the start to a height, across at that height, down to the approach point
	for h in OVER_HEIGHTS:
		var top_y := minf(maxf(h, maxf(lifted.y, approach.y) + 0.5), CEILING_Y)
		if top_y > maxf(lifted.y, approach.y) + 0.3:
			routes.append(PackedVector3Array([lifted, Vector3(lifted.x, top_y, lifted.z), Vector3(approach.x, top_y, approach.z), approach]))
	var best_reason := "blocked"
	for k in routes.size():
		var legs: PackedVector3Array = routes[k]
		var clear := true
		for i in range(1, legs.size()):
			if not sweep_clear(space, legs[i - 1], legs[i], r):
				clear = false
				break
		if not clear:
			continue
		var pts := PackedVector3Array()
		if lifted != start:
			pts.append(start)
		pts.append_array(legs)
		pts.append(rest)
		if threat is Vector3 and PreyMath.distance_to_path(pts, threat as Vector3) < float(p.path_threat_clearance_wu):
			best_reason = "passes_threat"
			continue
		f.ok = true
		f.points = pts
		f.length = PreyMath.path_length(pts)
		f.apex = -1.0 if k == 0 else maxf(legs[1].y, legs[legs.size() - 2].y)
		if f.length > p.max_flight_wu * 1.6:
			return _fail(f, "too_far")
		return f
	return _fail(f, best_reason)


func _fail(f: Flight, why: String) -> Flight:
	f.ok = false
	f.reason = why
	plans_failed += 1
	return f


## Valid perches a fly could consider: free for it, between `min_dist` and `max_dist` of `from`, and not within the avoid distance of
## `threat`. Nearest first (ties by id), so the order never depends on the dictionary.
func candidates(fly_id: String, from: Vector3, threat: Variant, p: RefCounted, min_dist: float, max_dist: float, include_fixtures: bool = false) -> Array[Perch]:
	var out: Array[Perch] = []
	for id in order:
		var c: Perch = perches[id]
		if not c.is_free_for(fly_id) or (c.fixture and not include_fixtures):
			continue
		var d := from.distance_to(c.position)
		if d < min_dist or d > max_dist:
			continue
		if threat is Vector3 and (threat as Vector3).distance_to(c.position) < float(p.perch_avoid_wu):
			continue
		out.append(c)
	out.sort_custom(func(a: Perch, b: Perch) -> bool:
		var da := from.distance_squared_to(a.position)
		var db := from.distance_squared_to(b.position)
		return da < db or (da == db and a.id < b.id))
	return out
