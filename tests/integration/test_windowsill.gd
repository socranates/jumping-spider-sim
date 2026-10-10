extends "res://tests/prey_test_case.gd"
## T08 uses the shipped world, existing motor, sensors and prey. Lab tests stay unchanged.

func habitat(pose: Variant = null, count: int = 0) -> void:
	use_windowsill = true
	await spawn_prey_world(pose, count, 4242)

func test_habitat_perches_and_entries_validate_with_four_flies() -> void:
	await habitat(null, 4)
	check_eq(director().living().size(), 4, "all four authored start perches spawn")
	for id: String in director().graph.order:
		var p = director().graph.get_perch(id)
		check(p.valid, "%s valid: %s" % [id, p.refusal])
	check_eq(int(director().vent_validation.get("valid", 0)), 2, "both frame cracks validate")
	check(not world.lab.has_method("on_jump_committed"), "habitat has no disappearing practice perches")
	check_eq(world.spider.support.surface_id, "sill_floor", "spawn rests on sill")

func test_front_route_returns_to_physical_retreat_without_teleport() -> void:
	await habitat()
	for goal in [Vector3(-13, 0, 6), Vector3(10, 0, 6), Vector3(23, 0, 6), Vector3(-25, 0, 6)]:
		await walk_toward(goal, false, 0.15, 1500)
		check(flat_distance(world.spider.global_position, goal) < 0.2, "walk reached %s" % goal)
		check_eq(world.spider.get_state_name(), "ATTACHED", "route stays supported")
	await run_ticks(20)
	check(world.habitat_loop.can_rest(), "walked home into the crevice")

func test_upper_route_jumps_across_the_gap_and_back() -> void:
	var pose := Transform3D(Basis(Vector3.UP, deg_to_rad(-90)), Vector3(-12.5, 4.51, -0.5))
	await habitat(pose)
	for point in [Vector3(-3.5, 4.2, -0.5), Vector3(5, 4.6, -0.5), Vector3(14, 4.6, -0.5), Vector3(21, 5.4, -0.5), Vector3(14, 4.6, -0.5), Vector3(5, 4.6, -0.5), Vector3(-3.5, 4.2, -0.5), Vector3(-12.5, 4.2, -0.5)]:
		var target := ray_target(point + Vector3.UP * 2, point - Vector3.UP)
		var plan = world.spider.plan_jump(target)
		if not check(plan.is_valid(), "upper route plan valid: %s" % plan.reason):
			return
		check(world.spider.begin_prepare(), "prepare")
		await physics_frames(2)
		check(world.spider.commit_jump(plan), "launch")
		await physics_frames(100)
		check_eq(world.spider.get_state_name(), "ATTACHED", "landed")
		check(world.spider.global_position.distance_to(point + Vector3.UP * 0.3) < 0.25, "correct leaf landing")

func test_upper_route_can_be_entered_from_floor_and_camera_clears_the_crevice() -> void:
	await habitat(floor_pose(-21, 0, -90))
	var point := Vector3(-17, 4.2, 0)
	var plan = world.spider.plan_jump(ray_target(point + Vector3.UP * 2, point - Vector3.UP))
	if check(plan.is_valid(), "floor-to-leaf route is accessible: %s" % plan.reason):
		world.spider.begin_prepare()
		await physics_frames(2)
		world.spider.commit_jump(plan)
		await physics_frames(100)
		check_eq(world.spider.support.surface_id, "leaf_west", "reached upper route")
	await put_spider(-25, 6, -90)
	world.camera_rig.snap_to_target()
	await process_frames(4)
	check(point_is_clear_in_physics(world.camera_rig.camera.global_position, 0.05), "camera is outside the crevice collision")

func test_rest_restores_only_rest_and_movement_cancels_it() -> void:
	await habitat(floor_pose(-25, 6, -90))
	world.needs.configure({"rest": 0.2, "energy": 0.5})
	var loop: Node = world.habitat_loop
	check(loop.request_rest(), "rest is available inside")
	await run_ticks(60)
	check(world.needs.rest > 0.29, "retreat restores rest")
	check(world.needs.energy <= 0.5, "rest grants no food")
	world.spider.set_intent(Vector3.RIGHT, false)
	await run_ticks(2)
	check(not loop.resting, "movement immediately cancels rest")
	check(world.spider.velocity.length() > 0.0, "controls were never disabled")
	loop.step(0.0, false, true)
	check(not loop.resting, "cancel is safe when idle")

func test_feed_takes_priority_over_rest_and_keeps_its_remaining_nutrition() -> void:
	await habitat(floor_pose(-25, 6, -90))
	var f := add_fly("sill_first_hunt", 1, true)
	f.mark_captured("spider", "capture:spider:%s" % f.id)
	director().held = f
	var loop: Node = world.habitat_loop
	check(not loop.request_rest(), "held prey reserves interaction for feeding")
	check(world.feeding.request_feed(), "can eat at home")
	await run_ticks(30)
	world.feeding.request_cancel()
	var remaining: float = f.nutrition_left
	await run_ticks(30)
	check_near(f.nutrition_left, remaining, 0.00001, "cancellation preserves remaining meal")
	check(not loop.resting, "cancelling feeding did not start rest")

func test_pause_freezes_rest_needs_flies_and_disturbance() -> void:
	await habitat(floor_pose(-25, 6, -90), 4)
	world.needs.configure({"rest": 0.2})
	world.habitat_loop.request_rest()
	world.habitat_loop.event_phase = "passing"
	await run_ticks(3)
	runner.get_tree().paused = true
	var record: Dictionary = world.habitat_loop.to_dict()
	var needs: Dictionary = world.needs.to_dict()
	var prey_tick: int = director().tick
	await process_frames(12)
	check_eq(world.habitat_loop.to_dict(), record, "habitat clock and rest frozen")
	check_eq(world.needs.to_dict(), needs, "needs frozen")
	check_eq(director().tick, prey_tick, "prey frozen")
	runner.get_tree().paused = false
	await run_ticks(2)
	check(director().tick > prey_tick, "resumes normally")

func test_disturbance_warns_passes_once_and_never_moves_collision() -> void:
	await habitat()
	var loop: Node = world.habitat_loop
	loop.set_physics_process(false)
	var before: Transform3D = world.lab.get_piece("leaf_west").global_transform
	loop.elapsed = 60.0
	loop.step(0.0)
	check_eq(loop.event_phase, "warning", "warns first")
	check(not world.lab.shadow_band.visible, "shadow has not arrived during warning")
	loop.step(4.9)
	check_eq(loop.event_phase, "warning", "usable warning interval")
	loop.step(0.2)
	check_eq(loop.event_phase, "passing", "then shadow")
	loop.step(6.0)
	check(world.lab.shadow_band.visible, "visible local change")
	check(world.lab.sun.light_energy < 0.8, "gentle light shift")
	check_eq(world.lab.get_piece("leaf_west").global_transform, before, "no changed collision")
	loop.step(6.1)
	check(loop.event_completed, "finished")
	loop.step(120.0)
	check_eq(loop.event_phase, "quiet", "never repeats")
	check(not world.lab.shadow_band.visible, "shadow cleared")

func test_retreat_refuses_rest_outside_and_cancels_on_jump_preparation() -> void:
	await habitat()
	check(not world.habitat_loop.request_rest(), "outside the crack is not home")
	await put_spider(-25, 6, -90)
	check(world.habitat_loop.request_rest(), "inside is home")
	check(world.spider.begin_prepare(), "jump preparation remains available")
	await run_ticks(2)
	check(not world.habitat_loop.resting, "preparation cancels rest")

func test_habitat_capture_and_interrupted_meal_keep_the_same_ownership() -> void:
	await habitat(floor_pose(-16, 6, -90))
	var f := add_fly("sill_first_hunt", 1, true)
	await run_ticks(100)
	await strike_at(-13, 6)
	check_eq(director().held, f, "capture at the authored hunting spot")
	check(world.feeding.request_feed(), "feeding begins after landing")
	await run_ticks(30)
	world.feeding.request_cancel()
	var left: float = f.nutrition_left
	check(left > 0.0 and left < f.nutrition_total, "partial meal remains")
	check(world.feeding.request_feed(), "resume same meal")
	await run_ticks(240)
	check_eq(director().capture_log.size(), 1, "one owner and one capture")
	check_near(world.needs.granted_total, f.nutrition_total, 0.00001, "one fly's food, exactly once")
