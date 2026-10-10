extends "res://tests/jump_test_case.gd"
## The planner against the real physics world: classifications on the lab's own surfaces, the whole
## body swept along the path, and an independent check of the swept path with the engine's body test.

const JumpMath = preload("res://scripts/movement/jump_math.gd")


func _start(x: float, z: float, heading_deg: float = 0.0) -> Node3D:
	spawn_world(floor_pose(x, z, heading_deg))
	await physics_frames(6)
	await settle(world.spider)
	return world.spider


func test_level_floor_jumps_of_two_to_eleven_body_lengths_are_reachable() -> void:
	var spider := await _start(-22.0, 12.0, -90.0)
	for d in [2.0, 3.0, 4.0, 5.0, 7.0, 9.0, 11.0]:
		var plan = spider.plan_jump(top_target(-22.0 + d, 12.0))
		check_eq(plan.kind_name(), "reachable", "%.0f WU along the floor (%s)" % [d, plan.reason])
		check_vec_near(plan.seat, Vector3(-22.0 + d, 0.31, 12.0), 1e-4, "the seat is %.0f WU away" % d)
		check(plan.speed <= 20.0 + 1e-6 and plan.duration <= 0.9 + 1e-6, "%.0f WU: within 20 WU/s and 0.9 s (%f, %f)" % [d, plan.speed, plan.duration])
	var far = spider.plan_jump(top_target(-22.0 + 13.0, 12.0))
	check_eq(far.kind_name(), "unreachable", "13 WU is out of reach")
	check_eq(far.reason, "too_far", "too far")
	check(far.min_speed > 20.0, "the speed it would need is above the limit, %f" % far.min_speed)


func test_the_jump_reach_setting_scales_speed_and_flight_time_by_its_square_root() -> void:
	var spider := await _start(-22.0, 12.0, -90.0)
	var nine := top_target(-22.0 + 9.0, 12.0)
	var fourteen := top_target(-22.0 + 14.0, 12.0)
	check_eq(spider.plan_jump(nine).kind_name(), "reachable", "9 WU at 100%")
	check_eq(spider.plan_jump(fourteen).kind_name(), "unreachable", "14 WU at 100%")
	spider.set_reach_factor(0.5)
	var planner: RefCounted = spider.get_jump_planner()
	check_near(planner.max_speed, 20.0 * sqrt(0.5), 1e-6, "50%: speed limit times sqrt(0.5)")
	check_near(planner.t_max, 0.9 * sqrt(0.5), 1e-6, "50%: longest flight times sqrt(0.5)")
	check_near(planner.gravity.y, -35.0, 1e-9, "gravity unchanged")
	check_eq(spider.plan_jump(nine).kind_name(), "unreachable", "9 WU is out of reach at 50%")
	check_eq(spider.plan_jump(top_target(-22.0 + 5.0, 12.0)).kind_name(), "reachable", "5 WU still reachable at 50%")
	spider.set_reach_factor(1.5)
	check_near(planner.max_speed, 20.0 * sqrt(1.5), 1e-6, "150%: speed limit times sqrt(1.5)")
	check_eq(spider.plan_jump(fourteen).kind_name(), "reachable", "14 WU reachable at 150%")
	spider.set_reach_factor(1.0)
	check_near(planner.max_speed, 20.0, 1e-6, "back to 100%")


func test_floor_to_ledge_tops_are_reachable_and_the_highest_ledge_is_not() -> void:
	var spider := await _start(-14.5, -8.5, 0.0)
	var one = spider.plan_jump(top_target(-14.5, -11.6))
	check_eq(one.kind_name(), "reachable", "ledge_1, 1 WU up (%s)" % one.reason)
	check_eq(one.target_surface_id, "ledge_1", "the target surface is ledge_1")
	check_eq(one.target_profile_id, "bare_wood_rough", "with its profile")
	check_vec_near(one.target_normal, Vector3.UP, 1e-5, "facing up")
	spider.teleport_to(floor_pose(-8.5, -9.4, 0.0))
	await settle(spider)
	var two = spider.plan_jump(top_target(-8.5, -11.7))
	check_eq(two.kind_name(), "reachable", "ledge_2, 2 WU up, close to its face (%s)" % two.reason)
	check(two.speed <= 14.0, "within the launch limit, %f" % two.speed)
	spider.teleport_to(floor_pose(2.0, -8.5, 0.0))
	await settle(spider)
	var five = spider.plan_jump(top_target(3.5, -12.0))
	check_eq(five.kind_name(), "unreachable", "ledge_4, 5 WU up, is beyond the launch limit")
	check_eq(five.reason, "too_far", "too far")


func test_a_wall_is_a_valid_target_and_the_arrival_goes_into_it() -> void:
	var spider := await _start(0.0, 14.0, 180.0)
	var target := ray_target(Vector3(0.0, 1.5, 10.0), Vector3(0.0, 1.5, 20.0))
	check_vec_near(target["normal"], Vector3.BACK * -1.0, 1e-5, "the south wall faces -Z")
	var plan = spider.plan_jump(target)
	check_eq(plan.kind_name(), "reachable", "floor to wall (%s)" % plan.reason)
	check(plan.approach_speed >= JumpMath.LAND_APPROACH_MIN, "arrives into the wall at %f WU/s" % plan.approach_speed)
	check_eq(plan.target_surface_id, "wall_south", "the wall's id")


func test_a_surface_that_cannot_hold_the_spider_is_ineligible() -> void:
	var spider := await _start(13.5, 11.0, 180.0)
	var plan = spider.plan_jump(ray_target(Vector3(13.5, 1.5, 11.0), Vector3(13.5, 1.5, 20.0)))
	check_eq(plan.target_surface_id, "ptfe_panel", "aimed at the coated panel")
	check_eq(plan.kind_name(), "ineligible", "its vertical face cannot hold the spider")
	check_eq(plan.reason, "ineligible_surface", "reason")


func test_a_tall_wall_between_the_spider_and_the_target_obstructs_every_arc() -> void:
	var spider := await _start(-24.0, -6.5, 0.0)
	var target := top_target(-24.0, -11.5)  # the floor behind corner_a, a 5 WU wall 0.6 thick
	check_vec_near(target["point"], Vector3(-24.0, 0.0, -11.5), 1e-4, "the aimed point is on the floor behind the wall")
	var plan = spider.plan_jump(target)
	check_eq(plan.kind_name(), "obstructed", "the wall is in the way (%s)" % plan.reason)
	check_eq(plan.reason, "path_blocked", "the path is blocked")
	check(plan.blocked_step >= 1, "and the tick is known, %d" % plan.blocked_step)
	check(absf(plan.blocked_at.z - -9.0) < 1.2, "near the wall, at %s" % str(plan.blocked_at))
	check(not plan.is_valid(), "not committable")
	check(not spider.commit_jump(plan), "and the motor refuses it")


func test_no_room_for_the_body_at_the_foot_of_a_wall_even_when_the_point_is_visible() -> void:
	var spider := await _start(0.0, 14.2, 180.0)
	var target := top_target(0.0, 17.4)  # 0.1 WU from the south wall: the 0.6 WU body cannot sit there
	var ray := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(spider.global_position + Vector3.UP * 0.5, target["point"] + Vector3.UP * 0.05, 1))
	check(ray.is_empty(), "a point ray from the spider to the target is clear")
	var plan = spider.plan_jump(target)
	check_eq(plan.kind_name(), "obstructed", "but the whole body does not fit")
	check_eq(plan.reason, "no_room", "no room at the landing")


func test_no_surface_under_the_aim_is_no_target() -> void:
	var spider := await _start(-22.0, 12.0, -90.0)
	check_eq(spider.plan_jump({}).kind_name(), "none", "no aim, no target")
	check_eq(spider.plan_jump(ray_target(Vector3(0.0, 50.0, 0.0), Vector3(0.0, 60.0, 0.0))).kind_name(), "none", "a ray into the sky finds nothing")


func test_planning_is_repeatable_and_moves_nothing() -> void:
	var spider := await _start(-22.0, 12.0, -90.0)
	var p0: Vector3 = spider.global_position
	var target := top_target(-18.0, 12.0)
	var a = spider.plan_jump(target)
	await physics_frames(5)
	var b = spider.plan_jump(target)
	check_eq(a.velocity, b.velocity, "the same target gives the same launch velocity")
	check_eq(a.steps, b.steps, "and the same duration")
	check_vec_near(spider.global_position, p0, 1e-6, "the spider did not move")
	check_eq(spider.state, spider.State.ATTACHED, "and is still attached")
	check(spider.last_jump.is_empty(), "no jump was recorded")


func test_the_planned_path_is_clear_for_the_real_body() -> void:
	# An independent check: the engine's own body test, with the real collider and the engine's margin,
	# along every segment of a reachable plan's path.
	var spider := await _start(-14.5, -8.5, 0.0)
	var plan = spider.plan_jump(top_target(-14.5, -11.6))
	check(plan.is_valid(), "the plan to the ledge is reachable")
	var params := PhysicsTestMotionParameters3D.new()
	var result := PhysicsTestMotionResult3D.new()
	var blocked := 0
	for k in range(1, plan.path.size()):
		params.from = Transform3D(Basis.IDENTITY, plan.path[k - 1])
		params.motion = plan.path[k] - plan.path[k - 1]
		if PhysicsServer3D.body_test_motion(spider.get_rid(), params, result):
			blocked += 1
	check_eq(blocked, 0, "the engine finds no collision along any of the %d segments" % (plan.path.size() - 1))
