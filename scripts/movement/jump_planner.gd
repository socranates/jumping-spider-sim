extends RefCounted
## JumpPlanner (spec 6.3, 19.3): turns a target surface point into a JumpPlan. It owns candidate
## trajectories and validity, and nothing else: it never moves a body.
##
## For a target point P with normal N the body centre must reach the landing seat P + N * seat_distance.
## JumpMath solves the launch velocity for every allowed whole-tick duration in the same discrete
## form the motor flies (semi-implicit Euler at the physics tick). Candidates are tried lowest launch
## speed first; each is checked by sweeping a sphere (the body's radius plus a small margin) between
## the successive tick positions, and the landing seat must be free of geometry. The first clear
## candidate wins. If every candidate is blocked the target is OBSTRUCTED; if none exists within the
## speed limit, the time range, leaving the launch surface and arriving into the target it is
## UNREACHABLE; a surface that cannot hold the spider (D-010) is INELIGIBLE. A candidate must also
## land where it says: the predicted first contact after the seat may not drift more than MAX_DRIFT
## from the seat, which rejects arcs that would only graze the surface. There is no aim error and no
## displayed uncertainty in P0: static jumps are deterministic (A-005, A-008).
##
## The world comes in through a query object with two methods, so the logic can be tested without a
## physics server:
##   sweep(from: Vector3, to: Vector3) -> Dictionary   {} when clear, else {"position": body centre at first contact}
##   fits(center: Vector3) -> bool                      true when the body fits at the centre
## PhysicsQuery is the real one.

const JumpMath = preload("res://scripts/movement/jump_math.gd")
const JumpPlan = preload("res://scripts/movement/jump_plan.gd")
const SurfaceProfile = preload("res://scripts/core/surface_profile.gd")
const SpeciesProfile = preload("res://scripts/core/species_profile.gd")

const SWEEP_MARGIN := 0.003       # WU added to the body radius in sweeps: a clear plan is slightly conservative
const MAX_DRIFT := 0.15           # WU: the predicted contact centre may differ this much from the seat
const CONTACT_EXTRA_STEPS := 8    # ticks beyond the seat searched for the first contact

var gravity: Vector3 = Vector3(0.0, -35.0, 0.0)
var dt: float = 1.0 / 60.0
var t_min: float = 0.35
var t_max: float = 0.6
var max_speed: float = 14.0
var seat_distance: float = 0.31   # body centre to surface at rest: radius + skin
var surfaces: Dictionary = {}     # SurfaceProfile registry, id -> Profile
var reach_factor: float = 1.0     # the "Jump reach" playtest setting (see configure)


## Tuning comes from the species profile only (spec 21.1). `p_reach_factor` is the "Jump reach" playtest
## setting (0.5 to 1.5, 1.0 = the profile as written). Ballistic range on level ground is speed squared over
## gravity, and the flight that reaches it lasts in proportion to the speed, so a reach factor k scales the
## launch speed limit and the longest flight time both by sqrt(k) and leaves gravity alone: the arcs keep
## their shape and the solver never shows an arc the spider could not fly (spec 6.3: tune together).
func configure(profile: SpeciesProfile.Profile, p_seat_distance: float, p_surfaces: Dictionary, p_dt: float, p_reach_factor: float = 1.0) -> void:
	reach_factor = clampf(p_reach_factor, 0.1, 10.0) if is_finite(p_reach_factor) else 1.0
	var root_k := sqrt(reach_factor)
	gravity = Vector3(0.0, -profile.gravity_wu_s2, 0.0)
	max_speed = profile.max_launch_speed_wu_s * root_k
	t_min = profile.flight_time_min_s
	t_max = maxf(profile.flight_time_max_s * root_k, t_min)
	seat_distance = p_seat_distance
	surfaces = p_surfaces
	dt = p_dt


## Plans a jump from the body centre `origin`, standing on a surface with normal `launch_normal`,
## to `target` = {"point": Vector3, "normal": Vector3, "collider": Object (optional)}, an empty
## dictionary meaning the aim found no surface.
func plan(query: RefCounted, origin: Vector3, launch_normal: Vector3, target: Dictionary) -> JumpPlan:
	var p := JumpPlan.new()
	p.origin = origin
	p.launch_normal = launch_normal.normalized() if launch_normal.is_finite() and launch_normal.length_squared() > 1e-10 else Vector3.UP
	p.dt = dt
	p.gravity = gravity
	if target.is_empty() or not (target.get("point") is Vector3) or not (target.get("normal") is Vector3):
		return p
	var point: Vector3 = target["point"]
	var normal: Vector3 = target["normal"]
	if not point.is_finite() or not normal.is_finite() or normal.length_squared() < 1e-10:
		return p
	normal = normal.normalized()
	p.target_point = point
	p.target_normal = normal
	var collider: Object = target.get("collider")
	p.target_surface_id = _surface_id(collider)
	p.target_profile_id = _profile_id(collider)
	p.seat = point + normal * seat_distance
	if not SurfaceProfile.supports(surfaces.get(p.target_profile_id), normal):
		p.kind = JumpPlan.Kind.INELIGIBLE
		p.reason = "ineligible_surface"
		return p
	var solved := JumpMath.solve(origin, p.seat, p.launch_normal, normal, gravity, dt, t_min, t_max, max_speed)
	p.min_speed = float(solved["min_speed"])
	var valid: Array[Dictionary] = solved["valid"]
	if valid.is_empty():
		p.kind = JumpPlan.Kind.UNREACHABLE
		p.reason = str(solved["reason"])
		return p
	if not query.fits(p.seat):
		_fill_candidate(p, valid[0], JumpMath.path(origin, valid[0]["velocity"], gravity, dt, int(valid[0]["steps"])))
		p.kind = JumpPlan.Kind.OBSTRUCTED
		p.reason = "no_room"
		p.blocked_step = p.steps
		p.blocked_at = p.seat
		return p
	var first_blocked: Dictionary = {}
	var any_blocked := false
	for c in valid:
		var result := _try_candidate(query, origin, p.seat, c)
		if result["ok"]:
			_fill_candidate(p, c, result["path"])
			p.kind = JumpPlan.Kind.REACHABLE
			p.reason = "ok"
			p.contact_center = result["contact"]
			p.contact_step = int(result["contact_step"])
			p.anchor_point = origin - p.launch_normal * seat_distance
			p.line_needed = line_needed(p)
			return p
		if first_blocked.is_empty():
			first_blocked = result
			first_blocked["candidate"] = c
		if result["reason"] == "path_blocked":
			any_blocked = true
	# Nothing clear. Show the lowest-speed arc that was tried, cut where it was blocked.
	var shown: Dictionary = first_blocked["candidate"]
	_fill_candidate(p, shown, first_blocked["path"])
	p.blocked_step = int(first_blocked["blocked_step"])
	p.blocked_at = first_blocked["blocked_at"]
	if any_blocked:
		p.kind = JumpPlan.Kind.OBSTRUCTED
		p.reason = "path_blocked"
	else:
		p.kind = JumpPlan.Kind.UNREACHABLE
		p.reason = "graze"
	return p


## The most safety line a plan pays out: the largest distance from its anchor point to the body centre
## along the predicted path, the predicted contact included. A line that wraps over an edge needs a little
## more; the motor allows for that before it anchors (spec 9.1: payout never truncates the arc).
static func line_needed(p: JumpPlan) -> float:
	var most := p.anchor_point.distance_to(p.contact_center)
	for q in p.path:
		most = maxf(most, p.anchor_point.distance_to(q))
	return most


func _fill_candidate(p: JumpPlan, c: Dictionary, path: PackedVector3Array) -> void:
	p.velocity = c["velocity"]
	p.speed = float(c["speed"])
	p.steps = int(c["steps"])
	p.duration = float(c["duration"])
	p.arrival_velocity = c["arrival_velocity"]
	p.approach_speed = float(c["approach"])
	p.path = path


## Sweeps one candidate along its discretised path and then past the seat to its first contact.
## Returns {"ok", "reason", "path", "blocked_step", "blocked_at", "contact", "contact_step"}.
func _try_candidate(query: RefCounted, origin: Vector3, seat: Vector3, c: Dictionary) -> Dictionary:
	var steps: int = c["steps"]
	var v0: Vector3 = c["velocity"]
	var pts := JumpMath.path(origin, v0, gravity, dt, steps)
	for k in range(1, steps + 1):
		var hit: Dictionary = query.sweep(pts[k - 1], pts[k])
		if not hit.is_empty():
			var cut := pts.slice(0, k)
			var at: Vector3 = hit["position"]
			cut.append(at)
			return {"ok": false, "reason": "path_blocked", "path": cut, "blocked_step": k, "blocked_at": at, "contact": Vector3.ZERO, "contact_step": -1}
	var v := JumpMath.velocity_after(v0, gravity, dt, steps)
	var p := pts[steps]
	for i in CONTACT_EXTRA_STEPS:
		v += gravity * dt
		var next := p + v * dt
		var hit: Dictionary = query.sweep(p, next)
		if not hit.is_empty():
			var contact: Vector3 = hit["position"]
			if contact.distance_to(seat) <= MAX_DRIFT:
				return {"ok": true, "reason": "ok", "path": pts, "blocked_step": -1, "blocked_at": Vector3.ZERO, "contact": contact, "contact_step": steps + i + 1}
			return {"ok": false, "reason": "graze", "path": pts, "blocked_step": steps, "blocked_at": contact, "contact": contact, "contact_step": -1}
		p = next
	return {"ok": false, "reason": "graze", "path": pts, "blocked_step": steps, "blocked_at": seat, "contact": Vector3.ZERO, "contact_step": -1}


static func _surface_id(collider: Object) -> String:
	if collider == null:
		return ""
	if collider.has_meta("surface_id"):
		return str(collider.get_meta("surface_id"))
	return str(collider.get("name"))


static func _profile_id(collider: Object) -> String:
	if collider == null or not collider.has_meta("surface_profile_id"):
		return ""
	return str(collider.get_meta("surface_profile_id"))


## The real world query: sphere sweeps and overlap tests on a physics space, the spider excluded.
class PhysicsQuery extends RefCounted:
	var space: PhysicsDirectSpaceState3D
	var _params := PhysicsShapeQueryParameters3D.new()

	func _init(p_space: PhysicsDirectSpaceState3D, radius: float, exclude: Array[RID], mask: int) -> void:
		space = p_space
		var shape := SphereShape3D.new()
		shape.radius = radius
		_params.shape = shape
		_params.collision_mask = mask
		_params.exclude = exclude

	func sweep(from: Vector3, to: Vector3) -> Dictionary:
		_params.transform = Transform3D(Basis.IDENTITY, from)
		_params.motion = to - from
		var r: PackedFloat32Array = space.cast_motion(_params)
		if r.size() < 2 or r[0] >= 1.0:
			return {}
		return {"fraction": r[0], "position": from + (to - from) * r[0]}

	func fits(center: Vector3) -> bool:
		_params.transform = Transform3D(Basis.IDENTITY, center)
		_params.motion = Vector3.ZERO
		return space.intersect_shape(_params, 1).is_empty()
