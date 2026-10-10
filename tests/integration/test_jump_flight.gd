extends "res://tests/jump_test_case.gd"
## Prepare, cancel, commit and the committed flight on the real motor and physics: the flight is the
## prediction, there is no steering, landing is classified, and a miss is recoverable.

const SpiderMotor = preload("res://scripts/movement/spider_motor.gd")


func _start(pose: Transform3D) -> Node3D:
	spawn_world(pose)
	await physics_frames(6)
	await settle(world.spider)
	return world.spider


## Prepares and commits a plan, then waits for the flight to end. True when it ended in time.
func _fly(spider: Node3D, plan: Object) -> bool:
	check(spider.begin_prepare(), "preparing starts")
	await physics_frames(2)
	check(spider.commit_jump(plan), "the plan is committed")
	return await wait_until(func() -> bool: return not spider.last_jump.is_empty() and str(spider.last_jump["outcome"]) != "", 120)


func test_floor_to_ledge_the_flight_is_the_prediction() -> void:
	var spider := await _start(floor_pose(-14.5, -8.5, 0.0))
	var states := record_states(spider)
	var plan = spider.plan_jump(top_target(-14.5, -11.6))
	check(plan.is_valid(), "the plan is reachable (%s)" % plan.reason)
	var landed := await _fly(spider, plan)
	check(landed, "the flight ends")
	var jump: Dictionary = spider.last_jump
	check_eq(jump["outcome"], "support", "it lands on support")
	check_eq(jump["landed_surface"], "ledge_1", "on the ledge it was aimed at")
	await settle(spider)
	check_eq(states, ["PREPARING", "AIRBORNE", "LANDING", "ATTACHED"] as Array[String], "the states run in the spec's order")
	check_vec_near(spider.get_support_normal(), Vector3.UP, 1e-5, "on its top face")
	var path: PackedVector3Array = jump["path"]
	check_eq(path.size(), plan.steps + 2, "the contact comes on the tick after the seat (%d points)" % path.size())
	var worst := 0.0
	for k in range(0, plan.steps + 1):
		worst = maxf(worst, path[k].distance_to(plan.path[k]))
	check(worst < 1e-3, "every tick of the flight is on the predicted path, worst %f WU" % worst)
	check(float(jump["error_contact"]) < 0.05, "the contact is at the planned landing centre, %f WU" % float(jump["error_contact"]))
	check(float(jump["error_settled"]) < 0.1, "and so is the settled body, %f WU" % float(jump["error_settled"]))
	check_vec_near(jump["planned_center"], plan.seat, 1e-6, "the record keeps the planned centre")
	check_near(spider.global_position.y, 1.0 + 0.31, 0.02, "seated on the ledge top")


func test_floor_to_wall_attaches_with_the_wall_normal() -> void:
	var spider := await _start(floor_pose(0.0, 14.0, 180.0))
	var plan = spider.plan_jump(ray_target(Vector3(0.0, 1.5, 10.0), Vector3(0.0, 1.5, 20.0)))
	check(plan.is_valid(), "the wall is reachable (%s)" % plan.reason)
	check(await _fly(spider, plan), "the flight ends")
	check_eq(spider.last_jump["outcome"], "support", "it lands")
	await settle(spider)
	check_eq(spider.support.surface_id, "wall_south", "attached to the wall")
	check_vec_near(spider.get_support_normal(), Vector3(0.0, 0.0, -1.0), 1e-5, "with the wall's normal")
	await physics_frames(30)
	check_eq(spider.state, spider.State.ATTACHED, "and it stays there")
	check_vec_near(spider.get_visual_up(), Vector3(0.0, 0.0, -1.0), 0.05, "the body turned to lie on the wall")
	check(float(spider.last_jump["error_settled"]) < 0.15, "near the planned centre, %f WU" % float(spider.last_jump["error_settled"]))


func test_ledge_to_floor() -> void:
	var spider := await _start(Transform3D(Basis(Vector3.UP, PI), Vector3(-8.5, 2.31, -12.5)))
	check_eq(spider.support.surface_id, "ledge_2", "starts on ledge_2")
	var plan = spider.plan_jump(top_target(-8.5, -8.5))
	check(plan.is_valid(), "the floor is reachable (%s)" % plan.reason)
	check(await _fly(spider, plan), "the flight ends")
	await settle(spider)
	check_eq(spider.support.surface_id, "floor", "lands on the floor")
	check(float(spider.last_jump["error_settled"]) < 0.1, "at the planned centre, %f WU" % float(spider.last_jump["error_settled"]))


func test_prepare_then_cancel_leaves_the_spider_unchanged() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var p0: Vector3 = spider.global_position
	var n0: Vector3 = spider.get_support_normal()
	var surface0: String = spider.support.surface_id
	var states := record_states(spider)
	check(spider.begin_prepare(), "preparing starts")
	spider.set_aim_target(p0 + Vector3(0.0, 0.0, -3.0))  # look away: the body may turn, which is cosmetic
	await physics_frames(20)
	check_eq(spider.state, spider.State.PREPARING, "preparing holds")
	check(spider.is_supported(), "the spider is still supported while preparing")
	check_vec_near(spider.global_position, p0, 1e-6, "and does not move")
	check_near(spider.velocity.length(), 0.0, 1e-6, "no velocity")
	check(spider.cancel_prepare(), "cancel works")
	await physics_frames(5)
	check_eq(spider.state, spider.State.ATTACHED, "back to attached")
	check_vec_near(spider.global_position, p0, 1e-6, "same place")
	check_vec_near(spider.get_support_normal(), n0, 1e-6, "same support normal")
	check_eq(spider.support.surface_id, surface0, "same support surface")
	check(spider.last_jump.is_empty(), "no jump happened")
	check_eq(states, ["PREPARING", "ATTACHED"] as Array[String], "two state changes")
	check(not spider.cancel_prepare(), "cancelling when not preparing does nothing")


func test_preparing_ignores_the_walking_intent_and_turns_toward_the_aim_at_a_capped_rate() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))  # faces +X
	var p0: Vector3 = spider.global_position
	check(spider.begin_prepare(), "preparing starts")
	spider.set_intent(Vector3.RIGHT, false)
	spider.set_aim_target(p0 + Vector3(0.0, 0.0, -5.0))  # 90 degrees to the left of the heading
	var before: Vector3 = spider.get_heading_vector()
	await physics_frames(3)
	var turned := rad_to_deg(before.angle_to(spider.get_heading_vector()))
	check(turned > 10.0 and turned < 25.0, "after 3 ticks the body has turned only a capped amount, %f degrees" % turned)
	await physics_frames(30)
	check(spider.get_heading_vector().is_equal_approx(Vector3(0.0, 0.0, -1.0)), "and then faces the aim, %s" % str(spider.get_heading_vector()))
	check_vec_near(spider.global_position, p0, 1e-6, "the intent never moved the body")


func test_a_plan_that_is_not_reachable_is_refused_and_changes_nothing() -> void:
	var spider := await _start(floor_pose(-24.0, -6.5, 0.0))
	var p0: Vector3 = spider.global_position
	var obstructed = spider.plan_jump(top_target(-24.0, -11.5))
	var far = spider.plan_jump(top_target(-24.0, 12.0))
	var none = spider.plan_jump({})
	for pair in [["obstructed", obstructed], ["unreachable", far], ["no target", none]]:
		check(not spider.commit_jump(pair[1]), "a %s plan is refused" % pair[0])
	check(spider.begin_prepare(), "preparing starts")
	check(not spider.commit_jump(obstructed), "also while preparing")
	await physics_frames(20)
	check_eq(spider.state, spider.State.PREPARING, "the spider is still preparing")
	check_vec_near(spider.global_position, p0, 1e-6, "and has not moved")
	check(spider.last_jump.is_empty(), "no jump was recorded")
	check(not spider.commit_jump(null), "null is refused")
	# A stale plan: made for another place.
	spider.cancel_prepare()
	var good = spider.plan_jump(top_target(-24.0, -3.0))
	check(good.is_valid(), "a short hop is reachable")
	spider.teleport_to(floor_pose(-23.0, -6.5, 0.0))
	await settle(spider)
	check(not spider.commit_jump(good), "a plan made for another position is refused")


func test_nothing_steers_the_body_in_the_air() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var plan = spider.plan_jump(top_target(-18.0, 12.0))
	check(plan.is_valid(), "reachable")
	check(spider.begin_prepare(), "preparing")
	check(spider.commit_jump(plan), "committed")
	var seen_airborne := false
	for i in plan.steps + 3:
		await physics_frames(1)
		if spider.state == spider.State.AIRBORNE:
			seen_airborne = true
			spider.set_intent(Vector3(0.0, 0.0, -1.0), false)  # the stick is held sideways the whole flight
			spider.set_aim_target(Vector3(0.0, 0.0, -50.0))
	check(seen_airborne, "it was airborne")
	check_eq(spider.last_jump["outcome"], "support", "landed")
	var path: PackedVector3Array = spider.last_jump["path"]
	var worst := 0.0
	for k in range(0, plan.steps + 1):
		worst = maxf(worst, path[k].distance_to(plan.path[k]))
	check(worst < 1e-3, "the path is the planned one whatever the input, worst %f" % worst)


func test_the_committed_impulse_is_frozen() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var plan = spider.plan_jump(top_target(-18.0, 12.0))
	var v0: Vector3 = plan.velocity
	check(spider.begin_prepare(), "preparing")
	check(spider.commit_jump(plan), "committed")
	check(not spider.commit_jump(plan), "a second commit during the flight is refused")
	plan.velocity = Vector3(100.0, 100.0, 100.0)  # tampering with the plan object after the commit
	await wait_until(func() -> bool: return str(spider.last_jump["outcome"]) != "", 90)
	check_eq(spider.last_jump["outcome"], "support", "landed")
	check(float(spider.last_jump["error_contact"]) < 0.05, "where the committed impulse said, %f WU" % float(spider.last_jump["error_contact"]))
	check(v0.length() < 14.0, "(the original impulse was within the limit)")


func test_a_late_obstacle_is_a_miss_that_still_lands_on_another_eligible_surface() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var plan = spider.plan_jump(top_target(-17.5, 12.0))
	check(plan.is_valid(), "a 4.5 WU jump along the floor")
	check(spider.begin_prepare(), "preparing")
	check(spider.commit_jump(plan), "committed")
	await physics_frames(4)
	# Something appears across the path (a wall of an eligible material), 1.3 WU before the seat.
	var wall := StaticBody3D.new()
	wall.name = "late_wall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.set_meta("surface_profile_id", "plaster_matte")
	wall.set_meta("surface_id", "late_wall")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 8.0, 8.0)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	wall.global_position = Vector3(-19.0, 4.0, 12.0)
	await wait_until(func() -> bool: return str(spider.last_jump["outcome"]) != "", 90)
	check_eq(spider.last_jump["outcome"], "support", "the flight still ends on support")
	await settle(spider)
	check_eq(spider.support.surface_id, "late_wall", "on the wall that was in the way, not on the target")
	check_vec_near(spider.get_support_normal(), Vector3.LEFT, 1e-5, "with its normal")
	check(float(spider.last_jump["error_contact"]) > 0.25, "a real miss, %f WU from the planned centre" % float(spider.last_jump["error_contact"]))


func test_an_obstruction_that_cannot_hold_the_spider_leaves_it_falling_to_the_floor() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var plan = spider.plan_jump(top_target(-17.5, 12.0))
	check(spider.begin_prepare(), "preparing")
	check(spider.commit_jump(plan), "committed")
	await physics_frames(4)
	var wall := StaticBody3D.new()
	wall.name = "late_coated_wall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.set_meta("surface_profile_id", "ptfe_coated")
	wall.set_meta("surface_id", "late_coated_wall")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 8.0, 8.0)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	wall.global_position = Vector3(-19.0, 4.0, 12.0)
	var states := record_states(spider)
	await wait_until(func() -> bool: return str(spider.last_jump["outcome"]) != "", 90)
	check_eq(spider.last_jump["outcome"], "ineligible", "the coated face cannot hold it")
	check(states.has("FALLING"), "so it falls")
	await settle(spider, 150)
	check_eq(spider.support.surface_id, "floor", "and lands on the floor with the existing landing logic")
	check(spider.get_support_normal().is_equal_approx(Vector3.UP), "on its top")


func test_leaving_the_play_bounds_returns_the_spider_to_its_last_supported_position() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	await physics_frames(10)
	var safe: Vector3 = spider.global_position
	var resets: Array[Vector3] = []
	spider.out_of_bounds_reset.connect(func(from_position: Vector3, to_position: Vector3) -> void:
		resets.append(from_position)
		resets.append(to_position))
	spider.global_position = Vector3(-22.0, -30.0, 12.0)  # fell out through the floor
	await physics_frames(3)
	check_eq(resets.size(), 2, "the reset was announced once")
	if resets.size() == 2:
		check_vec_near(resets[0], Vector3(-22.0, -30.0, 12.0), 1e-4, "from where it was")
		check_vec_near(resets[1], safe, 0.02, "to the last supported position")
	await settle(spider)
	check_vec_near(spider.global_position, safe, 0.05, "and it stands there again")
	check_eq(spider.support.surface_id, "floor", "on the floor")
	spider.global_position = Vector3(50.0, 0.31, 0.0)  # outside the lab
	await physics_frames(3)
	await settle(spider)
	check_vec_near(spider.global_position, safe, 0.05, "outside the walls is out of bounds too")


func test_jump_signals_fire_once_each() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var committed: Array[int] = []
	var ended: Array[String] = []
	spider.jump_committed.connect(func(_plan: RefCounted) -> void: committed.append(1))
	spider.jump_ended.connect(func(result: Dictionary) -> void: ended.append(str(result["outcome"])))
	var plan = spider.plan_jump(top_target(-18.0, 12.0))
	await _fly(spider, plan)
	await settle(spider)
	check_eq(committed.size(), 1, "jump_committed fired once")
	check_eq(ended, ["support"] as Array[String], "jump_ended fired once with the outcome")


func test_preparing_needs_a_standing_spider() -> void:
	spawn_world(Transform3D(Basis.IDENTITY, Vector3(-22.0, 6.0, 12.0)))  # in the air
	var spider: Node3D = world.spider
	await physics_frames(2)
	check(not spider.can_prepare(), "not while the spawn waits for support")
	check(not spider.begin_prepare(), "so preparing is refused")
	await wait_until(func() -> bool: return spider.state == spider.State.LANDING, 120)
	check(not spider.begin_prepare(), "and not while landing")
	await settle(spider)
	check(spider.begin_prepare(), "but once attached it works")
