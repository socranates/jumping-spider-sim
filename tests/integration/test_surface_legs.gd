extends "res://tests/jump_test_case.gd"
const SimClock = preload("res://scripts/core/sim_clock.gd")


func after_each() -> void:
	SimClock.set_speed(1.0)
	super.after_each()


func _start() -> Node3D:
	spawn_world(floor_pose(-22.0, 12.0, -90.0))
	await physics_frames(8)
	return world.spider.get_node("Body")


func test_stance_is_fixed_in_world_space_despite_travel_and_twitch() -> void:
	var body := await _start()
	world.spider.set_intent(Vector3.RIGHT, true)
	var checked := 0
	for tick in 50:
		var before: Array = body.legs.world_foot_positions()
		var planted: Array[bool] = []
		for i in 8:
			planted.append(body.legs.is_planted(i))
		await physics_frames(1)
		for i in 8:
			if planted[i] and body.legs.is_planted(i):
				check_vec_near(body.legs.world_foot_positions()[i], before[i], 1e-5, "stance does not slide")
				checked += 1
	check(checked > 100, "many real stance samples")
	check(body.legs.steps_started > 0, "travel also triggers swing")


func test_turning_on_the_spot_takes_steps() -> void:
	var body := await _start()
	var start: Vector3 = world.spider.global_position
	world.spider.begin_prepare()
	world.spider.set_aim_target(start + Vector3.LEFT * 5.0)
	await physics_frames(35)
	check(body.legs.steps_started > 0, "rotation alone triggers foot replacement")
	check_vec_near(world.spider.global_position, start, 1e-5, "feet did not move motor")


func test_tap_jump_displays_attachment_before_rear_push_and_absorbs_landing() -> void:
	var body := await _start()
	var spider: Node3D = world.spider
	var plan: RefCounted = spider.plan_hop(1.5)
	check(plan.is_valid() and spider.commit_jump(plan), "immediate scripted hop")
	var attached := false
	var pushed := false
	var crouched := false
	var launch: Vector3 = body.global_position
	for tick in 65:
		await physics_frames(1)
		if body.attachment_amount > 0.1 and not pushed:
			attached = true
		if body.push_amount > 0.1:
			check(attached, "touchdown is shown before extension")
			pushed = true
		if body.landing_depth > 0.02:
			crouched = true
		if tick == 1:
			check_vec_near(body.global_position, launch, 0.02, "visual touchdown stays at launch")
			check(spider.global_position.distance_to(launch) > 0.02, "physics already flies, no input delay")
	check(attached and pushed and crouched, "all three phases happened")
	check_near(body.landing_depth, 0.0, 1e-5, "landing returns to neutral height")
	check_eq(str(spider.last_jump.outcome), "support", "hop still lands")


func test_quarter_speed_keeps_the_same_gait_per_simulation_tick() -> void:
	var traces: Array = []
	for speed in [1.0, 0.25]:
		SimClock.set_speed(speed)
		var body := await _start()
		world.spider.set_intent(Vector3.RIGHT, true)
		var trace: Array = []
		for tick in 40:
			await physics_frames(1)
			trace.append(body.legs.world_foot_positions())
		traces.append(trace)
		world.queue_free()
		await physics_frames(2)
	for tick in 40:
		for i in 8:
			check_vec_near(traces[0][tick][i], traces[1][tick][i], 1e-5, "quarter speed retains foot trajectory")


func test_surface_contacts_on_wall_and_underside_are_on_real_geometry() -> void:
	spawn_world(floor_pose(27.0, 5.0, -90.0))
	await physics_frames(8)
	var body: Node3D = world.spider.get_node("Body")
	world.spider.set_intent(Vector3.RIGHT, false)
	var faces: Dictionary = {}
	for tick in 240:
		await physics_frames(1)
		if world.spider.in_transition():
			continue
		for i in 8:
			if body.legs.is_planted(i):
				var foot: Vector3 = body.legs.world_foot_positions()[i]
				var up: Vector3 = body.legs.contacts[i].up
				var hit := ray_target(foot + up * 0.03, foot - up * 0.03)
				check(not hit.is_empty(), "contact sits on a real surface")
				faces[world.spider.support.surface_id] = true
	for face in ["floor", "wall_east", "overhang"]:
		check(faces.has(face), "contact samples on " + face)


func test_eye_view_uses_a_stable_distal_leg_mask_and_reduced_motion_clears_launch() -> void:
	var body := await _start()
	body.set_eye_view(true)
	world.spider.set_intent(Vector3.RIGHT, true)
	await physics_frames(10)
	for i in 16:
		check_eq(body.legs.get_child(i).visible, i == 1 or i == 9, "no proximal rod crosses the camera")
	world.spider.set_intent(Vector3.ZERO, false)
	check(world.spider.commit_jump(world.spider.plan_hop(1.5)), "hop")
	await physics_frames(2)
	settings.set_value("reduced_motion", true)
	await physics_frames(2)
	check(body.launch_time < 0.0 and body.landing_depth == 0.0, "Reduced motion clears transient animation")
	check(body.position == Vector3.ZERO and body.rotation == Vector3.ZERO, "calm model")


func test_leaf_edge_retracts_feet_onto_the_leaf_and_sill_contacts_hold() -> void:
	use_windowsill = true
	spawn_world(Transform3D(Basis.IDENTITY, Vector3(-12.2, 4.51, -0.5)))
	await physics_frames(10)
	var legs: Node3D = world.spider.get_node("Body").legs
	var count := 0
	for i in 8:
		if legs.is_planted(i):
			var p: Vector3 = legs.world_foot_positions()[i]
			check(p.x <= -12.0 + 1e-4, "no foot planted in empty space beyond leaf")
			check_near(p.y, 4.2, 1e-4, "on the actual leaf top")
			count += 1
	check(count >= 6, "narrow edge finds multiple footholds: %d; %s" % [count, str(world.spider.global_position)])
	world.spider.teleport_to(floor_pose(-22.0, 6.0))
	await physics_frames(12)
	for i in 8:
		check(legs.is_planted(i), "sill supports foot after teleport reset")
		check_near(legs.world_foot_positions()[i].y, 0.0, 1e-4, "sill surface")


func test_push_straightens_rear_knees_with_feet_still_planted() -> void:
	var body := await _start()
	var legs: Node3D = body.legs
	var feet: Array = legs.world_foot_positions()
	legs.advance_surface(world.spider, SimClock.DT, 0.0)
	var angles: Array[float] = []
	for i in 8:
		var a: Node3D = legs.get_child(i * 2)
		var b: Node3D = legs.get_child(i * 2 + 1)
		angles.append(a.global_basis.y.normalized().angle_to(b.global_basis.y.normalized()))
	legs.advance_surface(world.spider, SimClock.DT, 1.0)
	for i in 8:
		var a: Node3D = legs.get_child(i * 2)
		var b: Node3D = legs.get_child(i * 2 + 1)
		var angle := a.global_basis.y.normalized().angle_to(b.global_basis.y.normalized())
		if i % 4 >= 2:
			check(angle < angles[i] - 0.2, "pairs III/IV visibly straighten")
		check_vec_near(legs.world_foot_positions()[i], feet[i], 1e-5, "push retains foothold")
