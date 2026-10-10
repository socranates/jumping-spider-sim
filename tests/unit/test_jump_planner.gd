extends "res://tests/test_case.gd"
## The planner's logic against a fake world (boxes and a floor), so every classification can be
## provoked exactly: reachable, obstructed (blocked path, no room), unreachable, ineligible, no target.
## The real physics world is covered by tests/integration/test_jump_planning.gd.

const JumpPlanner = preload("res://scripts/movement/jump_planner.gd")
const JumpPlan = preload("res://scripts/movement/jump_plan.gd")
const JumpMath = preload("res://scripts/movement/jump_math.gd")
const SpeciesProfile = preload("res://scripts/core/species_profile.gd")
const SurfaceProfile = preload("res://scripts/core/surface_profile.gd")

const G := Vector3(0.0, -35.0, 0.0)
const DT := 1.0 / 60.0
const SEAT := 0.31
const SWEPT := 0.303  # the sphere the planner sweeps: radius 0.3 plus the margin


## Boxes the body centre may not enter (already inflated by the swept radius). Counts its calls.
class FakeWorld extends RefCounted:
	var boxes: Array[AABB] = []
	var sweeps: int = 0
	var fit_checks: int = 0

	func add_floor() -> void:
		boxes.append(AABB(Vector3(-60.0, -10.0, -60.0), Vector3(120.0, 10.303, 120.0)))

	func sweep(from: Vector3, to: Vector3) -> Dictionary:
		sweeps += 1
		for b in boxes:
			var hit: Variant = b.intersects_segment(from, to)
			if hit != null:
				return {"position": hit as Vector3}
		return {}

	func fits(center: Vector3) -> bool:
		fit_checks += 1
		for b in boxes:
			if b.has_point(center):
				return false
		return true


var _profile: SpeciesProfile.Profile
var _surfaces: Dictionary


func before_each() -> void:
	_profile = SpeciesProfile.load_file("res://data/species/phidippus_audax_prototype.json")
	_surfaces = SurfaceProfile.load_dir()


func _planner() -> JumpPlanner:
	var p := JumpPlanner.new()
	p.configure(_profile, SEAT, _surfaces, DT)
	return p


func _collider(profile_id: String) -> Node:
	var n := Node.new()
	n.set_meta("surface_profile_id", profile_id)
	n.set_meta("surface_id", "fake_" + profile_id)
	sandbox.add_child(n)
	return n


func _floor_target(x: float, profile_id: String = "painted_wood_dry") -> Dictionary:
	return {"point": Vector3(x, 0.0, 0.0), "normal": Vector3.UP, "collider": _collider(profile_id)}


func _wall(x_center: float, height: float) -> AABB:
	# A wall across the flight (x), 0.2 thick, from below the floor to `height`, inflated by the swept radius.
	return AABB(Vector3(x_center - 0.1 - SWEPT, -10.0, -20.0), Vector3(0.2 + 2.0 * SWEPT, 10.0 + height + SWEPT, 40.0))


func test_a_clear_target_is_reachable_and_the_plan_is_complete() -> void:
	var world := FakeWorld.new()
	world.add_floor()
	var plan := _planner().plan(world, Vector3(0.0, SEAT, 0.0), Vector3.UP, _floor_target(4.0))
	check_eq(plan.kind, JumpPlan.Kind.REACHABLE, "4 WU on a clear floor is reachable")
	check_eq(plan.reason, "ok", "reason ok")
	check(plan.is_valid(), "is_valid")
	check_eq(plan.kind_name(), "reachable", "kind name")
	check_vec_near(plan.seat, Vector3(4.0, SEAT, 0.0), 1e-5, "the seat is the target point plus N times the seat distance")
	check(plan.steps >= 21 and plan.steps <= 36, "duration in range, %d ticks" % plan.steps)
	check_near(plan.duration, float(plan.steps) * DT, 1e-9, "duration is steps * dt")
	check(plan.speed <= 20.0 and plan.speed > 0.0, "speed within the limit, %f" % plan.speed)
	check(plan.velocity.dot(Vector3.UP) > 0.0, "the launch leaves the surface")
	check_eq(plan.path.size(), plan.steps + 1, "the path holds every tick position")
	check_vec_near(plan.path[0], Vector3(0.0, SEAT, 0.0), 1e-6, "the path starts at the origin")
	check_vec_near(plan.path[plan.steps], plan.seat, 1e-3, "and ends on the seat")
	check(plan.contact_center.distance_to(plan.seat) <= JumpPlanner.MAX_DRIFT, "the predicted contact is near the seat")
	check_vec_near(plan.gravity, G, 1e-9, "gravity comes from the profile")
	check_near(plan.dt, DT, 1e-12, "the plan records its tick")
	var lowest: Dictionary = (JumpMath.solve(Vector3(0.0, SEAT, 0.0), plan.seat, Vector3.UP, Vector3.UP, G, DT, 0.35, 0.9, 20.0)["valid"] as Array)[0]
	check_near(plan.speed, float(lowest["speed"]), 1e-4, "with nothing in the way, the lowest launch speed is taken")


func test_the_lowest_speed_arc_goes_first_and_higher_arcs_follow_when_it_is_blocked() -> void:
	var world := FakeWorld.new()
	world.add_floor()
	world.boxes.append(_wall(2.0, 1.35))  # a low wall midway: it stops flat arcs, not high ones
	var origin := Vector3(0.0, SEAT, 0.0)
	var target := _floor_target(4.0)
	var plan := _planner().plan(world, origin, Vector3.UP, target)
	check(plan.is_valid(), "a higher arc clears the low wall")
	var valid: Array[Dictionary] = JumpMath.solve(origin, plan.seat, Vector3.UP, Vector3.UP, G, DT, 0.35, 0.9, 20.0)["valid"]
	check_near(plan.speed, plan.velocity.length(), 1e-4, "speed is the velocity's length")
	var blocked_before := 0
	for c in valid:
		var pts := JumpMath.path(origin, c["velocity"], G, DT, int(c["steps"]))
		var hit := false
		for k in range(1, pts.size()):
			if not world.sweep(pts[k - 1], pts[k]).is_empty():
				hit = true
				break
		if float(c["speed"]) < plan.speed - 1e-6:
			check(hit, "every lower-speed arc (%d ticks) was blocked" % int(c["steps"]))
			blocked_before += 1
	check(blocked_before >= 1, "at least the lowest-speed arc was tried first and blocked")
	var lowest_steps := int(valid[0]["steps"])
	check(plan.steps != lowest_steps, "the chosen arc is not the lowest-speed one (%d against %d ticks)" % [plan.steps, lowest_steps])
	check(plan.speed > float(valid[0]["speed"]), "and it needs more speed")


func test_every_arc_blocked_is_obstructed_and_shows_where() -> void:
	var world := FakeWorld.new()
	world.add_floor()
	world.boxes.append(_wall(2.0, 12.0))  # a wall nothing can clear
	var origin := Vector3(0.0, SEAT, 0.0)
	var plan := _planner().plan(world, origin, Vector3.UP, _floor_target(4.0))
	check_eq(plan.kind, JumpPlan.Kind.OBSTRUCTED, "obstructed")
	check_eq(plan.reason, "path_blocked", "the path is blocked")
	check(not plan.is_valid(), "not valid")
	check(plan.blocked_step >= 1 and plan.blocked_step <= plan.steps, "the blocking tick is on the path, %d" % plan.blocked_step)
	check(absf(plan.blocked_at.x - 1.9) < 0.5, "the block is at the wall, %s" % str(plan.blocked_at))
	check_vec_near(plan.path[plan.path.size() - 1], plan.blocked_at, 1e-6, "the shown arc ends where it is blocked")
	var lowest: Dictionary = (JumpMath.solve(origin, plan.seat, Vector3.UP, Vector3.UP, G, DT, 0.35, 0.9, 20.0)["valid"] as Array)[0]
	check_near(plan.speed, float(lowest["speed"]), 1e-4, "the arc shown is the lowest-speed one")
	check_eq(plan.seat, Vector3(4.0, SEAT, 0.0), "the target is still shown")


func test_no_room_at_the_landing_is_obstructed_even_when_a_point_ray_is_clear() -> void:
	var world := FakeWorld.new()
	world.add_floor()
	world.boxes.append(AABB(Vector3(3.8, 0.0, -1.0), Vector3(0.6, 3.0, 2.0)))  # something at the seat
	var plan := _planner().plan(world, Vector3(0.0, SEAT, 0.0), Vector3.UP, _floor_target(4.0))
	check_eq(plan.kind, JumpPlan.Kind.OBSTRUCTED, "obstructed")
	check_eq(plan.reason, "no_room", "no room for the body at the landing")
	check_eq(world.sweeps, 0, "decided before any sweep")
	check_vec_near(plan.blocked_at, plan.seat, 1e-6, "the block is the seat")


func test_unreachable_is_not_obstructed_and_costs_no_sweeps() -> void:
	var world := FakeWorld.new()
	world.add_floor()
	world.boxes.append(_wall(2.0, 12.0))
	var plan := _planner().plan(world, Vector3(0.0, SEAT, 0.0), Vector3.UP, _floor_target(14.0))
	check_eq(plan.kind, JumpPlan.Kind.UNREACHABLE, "14 WU is out of reach")
	check_eq(plan.reason, "too_far", "too far")
	check(plan.min_speed > 20.0, "and the speed it would need is known, %f" % plan.min_speed)
	check_eq(world.sweeps, 0, "no sweeps for an unreachable target")
	check_eq(world.fit_checks, 0, "and no fit check")
	check(not plan.is_valid(), "not valid")


func test_leaving_the_surface_is_required() -> void:
	var world := FakeWorld.new()
	var wall_pt := Vector3(0.0, 4.0, 0.0)
	var plan := _planner().plan(world, Vector3(0.31, 2.0, 0.0), Vector3.RIGHT, {"point": wall_pt, "normal": Vector3.RIGHT, "collider": _collider("plaster_matte")})
	check_eq(plan.kind, JumpPlan.Kind.UNREACHABLE, "a jump along the same wall")
	check_eq(plan.reason, "no_launch", "cannot leave and come back")


func test_a_surface_that_cannot_hold_the_spider_is_ineligible() -> void:
	var world := FakeWorld.new()
	world.add_floor()
	var side := _planner().plan(world, Vector3(0.0, SEAT, 0.0), Vector3.UP, {"point": Vector3(2.0, 1.0, 0.0), "normal": Vector3.LEFT, "collider": _collider("ptfe_coated")})
	check_eq(side.kind, JumpPlan.Kind.INELIGIBLE, "the side of a coated panel")
	check_eq(side.reason, "ineligible_surface", "reason")
	check_eq(world.sweeps, 0, "decided before any sweep")
	var top := _planner().plan(world, Vector3(0.0, SEAT, 0.0), Vector3.UP, _floor_target(3.0, "ptfe_coated"))
	check_eq(top.kind, JumpPlan.Kind.REACHABLE, "the top of a coated surface can be stood on")
	var unknown := _planner().plan(world, Vector3(0.0, SEAT, 0.0), Vector3.UP, {"point": Vector3(2.0, 1.0, 0.0), "normal": Vector3.LEFT, "collider": _collider("no_such_profile")})
	check_eq(unknown.kind, JumpPlan.Kind.INELIGIBLE, "a surface with an unknown profile only holds by standing")


func test_no_target_is_reported_for_missing_or_broken_aim_data() -> void:
	var world := FakeWorld.new()
	var planner := _planner()
	check_eq(planner.plan(world, Vector3.ZERO, Vector3.UP, {}).kind, JumpPlan.Kind.NO_TARGET, "an empty aim")
	check_eq(planner.plan(world, Vector3.ZERO, Vector3.UP, {"point": Vector3(NAN, 0.0, 0.0), "normal": Vector3.UP}).kind, JumpPlan.Kind.NO_TARGET, "a non-finite point")
	check_eq(planner.plan(world, Vector3.ZERO, Vector3.UP, {"point": Vector3.ONE, "normal": Vector3.ZERO}).kind, JumpPlan.Kind.NO_TARGET, "a zero normal")
	check_eq(planner.plan(world, Vector3.ZERO, Vector3.UP, {"point": "here", "normal": Vector3.UP}).kind, JumpPlan.Kind.NO_TARGET, "a point of the wrong type")
	check_eq(world.sweeps, 0, "nothing was swept")


func test_an_arc_that_would_only_graze_is_not_offered() -> void:
	# No surface under the seat: the body would pass through the shown point and carry on, so the
	# plan does not land where it says.
	var world := FakeWorld.new()
	var plan := _planner().plan(world, Vector3(0.0, SEAT, 0.0), Vector3.UP, _floor_target(4.0))
	check_eq(plan.kind, JumpPlan.Kind.UNREACHABLE, "no contact after the seat")
	check_eq(plan.reason, "graze", "a graze")
	check(not plan.is_valid(), "not valid")


func test_tuning_comes_from_the_species_profile() -> void:
	var world := FakeWorld.new()
	world.add_floor()
	var origin := Vector3(0.0, SEAT, 0.0)
	var base := _planner().plan(world, origin, Vector3.UP, _floor_target(4.0))
	check(base.is_valid(), "reachable with the shipped tuning")
	_profile.max_launch_speed_wu_s = 8.0
	var weak := _planner().plan(world, origin, Vector3.UP, _floor_target(4.0))
	check_eq(weak.reason, "too_far", "with a lower speed limit the same target is out of reach")
	_profile.max_launch_speed_wu_s = 20.0
	_profile.gravity_wu_s2 = 20.0
	var light := _planner().plan(world, origin, Vector3.UP, _floor_target(4.0))
	check_vec_near(light.gravity, Vector3(0.0, -20.0, 0.0), 1e-9, "the plan carries the profile's gravity")
	check(absf(light.velocity.y - base.velocity.y) > 1.0, "and solves with it")
	_profile.gravity_wu_s2 = 35.0
	_profile.flight_time_min_s = 0.5
	_profile.flight_time_max_s = 0.5
	var fixed := _planner().plan(world, origin, Vector3.UP, _floor_target(4.0))
	check_eq(fixed.steps, 30, "a profile with one flight time of 0.5 s gives 30 ticks")
