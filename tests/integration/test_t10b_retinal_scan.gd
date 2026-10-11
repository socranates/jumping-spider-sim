extends "res://tests/prey_test_case.gd"


func test_scanning_changes_detail_without_changing_camera_or_sensing() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	settings.set_value("eye_view", true)
	await physics_frames(3)
	var eye: CanvasLayer = world.eye_overlay
	eye.set_process(false)
	eye._process(0.0)
	var ray: Dictionary = world.camera_rig.get_aim_ray()
	var axis: Vector3 = world.spider.get_gaze_direction()
	var left: Vector2 = eye.left_scan_deg
	var right: Vector2 = eye.right_scan_deg
	eye._process(0.4)
	check(eye.left_scan_deg.distance_to(left) > 1.0, "left retina sweeps over detail")
	check(eye.right_scan_deg.distance_to(right) > 1.0, "right retina also sweeps")
	check_near((eye.left_scan_deg - left).x, (eye.right_scan_deg - right).x, 0.0001, "conjugate horizontal sweep")
	check(absf(eye.scan_torsion) > 0.01, "slower retinal torsion accompanies sweep")
	check_eq(world.camera_rig.get_aim_ray(), ray, "scanning does not shake or steer the aiming camera")
	check_eq(world.spider.get_gaze_direction(), axis, "cosmetic scan does not alter gameplay sensing")
	check((eye.get_node("EyeViewTag") as Label).text.contains("UV not simulated"), "the spectral limitation stays visible")


func test_reduced_motion_holds_scan_and_orbit_does_not_advance_it() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	settings.set_value("eye_view", true)
	await physics_frames(3)
	var eye: CanvasLayer = world.eye_overlay
	eye.set_process(false)
	eye._process(0.3)
	var time: float = eye.scan_time
	var left: Vector2 = eye.left_scan_deg
	settings.set_value("reduced_motion", true)
	eye._process(3.0)
	check_eq(eye.scan_time, time, "Reduced motion stops the scan clock immediately")
	check_eq(eye.left_scan_deg, left, "no snap when Reduced motion starts")
	settings.set_value("reduced_motion", false)
	eye._process(0.1)
	check(eye.scan_time > time, "scan resumes from the held phase")
	settings.set_value("eye_view", false)
	time = eye.scan_time
	eye._process(1.0)
	check_eq(eye.scan_time, time, "orbit view does not run scanning")
	check(not (eye.get_node("EyeView") as Control).visible, "orbit view has no retinal filter")


func test_scan_is_frame_rate_independent_and_stays_bounded() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	settings.set_value("eye_view", true)
	await physics_frames(3)
	var eye: CanvasLayer = world.eye_overlay
	eye.set_process(false)
	var reference := Vector2.ZERO
	for fps in [30, 60, 144]:
		eye.scan_time = 0.0
		for i in fps * 2:
			eye._process(1.0 / float(fps))
			check(absf(eye.left_scan_deg.x + 2.5) <= eye.SWEEP_DEG + 0.001, "bounded retinal sweep")
			check(absf(eye.scan_torsion) <= deg_to_rad(eye.TORSION_DEG) + 0.001, "bounded torsion")
		if fps == 30:
			reference = eye.left_scan_deg
		else:
			check(eye.left_scan_deg.distance_to(reference) < 0.001, "same scan after two seconds at %d fps" % fps)


func test_tree_pause_freezes_automatic_scan() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	settings.set_value("eye_view", true)
	await physics_frames(3)
	var eye: CanvasLayer = world.eye_overlay
	world.get_tree().paused = true
	var time: float = eye.scan_time
	for i in 3:
		await world.get_tree().process_frame
	var held: bool = eye.scan_time == time
	world.get_tree().paused = false
	check(held, "paused menus do not keep sweeping the retinas")
