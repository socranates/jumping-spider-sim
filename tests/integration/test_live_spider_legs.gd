extends "res://tests/jump_test_case.gd"
## Exercise the shipped Body/Legs wiring through actual motor states and settings.


func _start(pose: Transform3D) -> Node3D:
	spawn_world(pose)
	await physics_frames(6)
	await settle(world.spider)
	return world.spider


func _check_rig(body: Node3D) -> void:
	check_eq(body.legs.get_child_count(), 16, "exactly sixteen animated segments")
	for child in body.get_children():
		check(not (child is MeshInstance3D and child.mesh is CylinderMesh), "old static legs were removed")
	for segment in body.legs.get_children():
		check(segment.transform.is_finite(), "finite segment transform")
		check(segment.material_override.albedo_color == body.LEG_COLOR, "keeps the live spider's leg colour")
	for foot in body.legs.foot_positions():
		check(foot.is_finite() and foot.length() < 1.5, "bounded foot in the model frame")


func test_live_walk_stalk_and_stop_drive_the_single_leg_rig() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var body: Node3D = spider.get_node("Body")
	var neutral: Array = body.legs.foot_positions()
	for stalk in [false, true]:
		spider.set_intent(Vector3.RIGHT, stalk)
		await physics_frames(30)
		var first: Array = body.legs.foot_positions()
		await physics_frames(4)
		check(body.legs.foot_positions() != first, "feet cycle while walking/stalking along world +X")
		check(body.legs.foot_positions() != neutral, "moving pose differs from idle")
		check(body.twitch_offset.length() > 0.0, "body lurch is retained")
		_check_rig(body)
	spider.set_intent(Vector3.ZERO, false)
	await physics_frames(40)
	check(body.legs.foot_positions() == neutral, "stopping settles the feet")
	await physics_frames(150)
	check(body.legs.foot_positions() == neutral, "idle twitch does not walk the feet")
	_check_rig(body)


func test_legs_follow_wall_and_underside_without_changing_the_route() -> void:
	var traces: Array = []
	for enabled in [true, false]:
		var spider := await _start(floor_pose(27.0, 5.0, -90.0))
		var body: Node3D = spider.get_node("Body")
		body.gait_enabled = enabled
		var trace: Array[Vector3] = []
		var moving_faces: Dictionary = {}
		var previous: Array = body.legs.foot_positions()
		spider.set_intent(Vector3.RIGHT, false)
		for i in 240:
			await physics_frames(1)
			trace.append(spider.global_position)
			var feet: Array = body.legs.foot_positions()
			if enabled and feet != previous and not spider.in_transition():
				moving_faces[spider.support.surface_id] = true
			previous = feet
			check(body.legs.global_basis.is_equal_approx(body.global_basis), "legs inherit the body's changing surface frame")
		_check_rig(body)
		if enabled:
			for face in ["floor", "wall_east", "overhang"]:
				check(moving_faces.has(face), "feet move on " + face)
		traces.append(trace)
		world.queue_free()
		await physics_frames(2)
	for i in traces[0].size():
		check_vec_near(traces[0][i], traces[1][i], 1e-6, "gait leaves the motor route unchanged")


func test_prepare_flight_and_landing_switch_leg_poses() -> void:
	var spider := await _start(floor_pose(-14.5, -8.5, 0.0))
	var body: Node3D = spider.get_node("Body")
	var neutral: Array = body.legs.foot_positions()
	var plan = spider.plan_jump(top_target(-14.5, -11.6))
	if not check(plan.is_valid() and spider.begin_prepare(), "prepare a real ledge jump"):
		return
	await physics_frames(12)
	var prepared: Array = body.legs.foot_positions()
	check(prepared != neutral, "preparing spreads the feet")
	check(body.twitch_offset.y < 0.0, "the existing body crouch remains")
	check(spider.commit_jump(plan), "launch")
	await physics_frames(3)
	check_eq(spider.get_state_name(), "AIRBORNE", "sample during flight")
	var flying: Array = body.legs.foot_positions()
	check(flying != prepared and flying != neutral, "airborne pose replaces the crouch")
	for foot in flying:
		check(absf(foot.x) < 0.6, "legs fold toward the body in flight")
	await settle(spider)
	await physics_frames(3)
	check(body.legs.foot_positions() == neutral, "landing restores the resting stance")
	_check_rig(body)


func test_reduced_motion_toggle_stops_gait_twitch_and_active_recoil() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var body: Node3D = spider.get_node("Body")
	var neutral: Array = body.legs.foot_positions()
	spider.set_intent(Vector3.RIGHT, false)
	body.start_recoil(Vector3.BACK)
	await physics_frames(3)
	check(body.is_recoiling() and body.legs.foot_positions() != neutral, "recoil and gait are active before toggling")
	settings.set_value("reduced_motion", true)
	await physics_frames(3)
	check(body.legs.foot_positions() == neutral, "setting restores neutral legs while still moving")
	check(body.position == Vector3.ZERO and body.rotation == Vector3.ZERO, "twitch and active recoil stop")
	check(not body.is_recoiling(), "no hidden recoil remains")
	check(spider.velocity.length() > 1.0, "movement continues")
	await physics_frames(15)
	check(body.legs.foot_positions() == neutral, "calm pose stays fixed")
	settings.set_value("reduced_motion", false)
	await physics_frames(4)
	check(body.legs.foot_positions() != neutral, "turning Reduced motion off resumes gait")


func test_checkpoint_rebuild_has_one_rig_and_honours_reduced_motion() -> void:
	use_windowsill = true
	settings.set_value("reduced_motion", true)
	var spider := await _start(floor_pose(-25.0, 6.0, -90.0))
	await wait_until(func() -> bool: return world.prey.is_world_ready(), 40)
	world.prey.ensure_ready()
	var neutral: Array = spider.get_node("Body").legs.foot_positions()
	var saved: Dictionary = world.save_checkpoint()
	if not check(bool(saved["ok"]), "save the supported habitat: " + str(saved["message"])):
		return
	var fresh: Node3D = world.return_to_checkpoint()
	if not check(fresh != null, "rebuild from checkpoint"):
		return
	world = fresh
	await physics_frames(6)
	var body: Node3D = world.spider.get_node("Body")
	_check_rig(body)
	check(not body.gait_enabled, "restored world uses the current Reduced motion setting")
	world.spider.set_intent(Vector3.RIGHT, false)
	await physics_frames(20)
	check(body.legs.foot_positions() == neutral, "restored rig remains calm during movement")
