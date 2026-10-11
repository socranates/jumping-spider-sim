extends "res://tests/perception_test_case.gd"
## T13a, the motion-sensitive surround (ROADMAP step 5; Nathan: "scientific realism in terms of vision"). The anterior lateral eyes are
## motion detectors (Zurek et al. 2010; Jakob et al. 2018), so in the spider-eye view a thing they could see moving shimmers in the soft
## surround before the principal eyes can tell what it is:
##   * the sensor records only what its sightline checks found moving: a standing thing and a hidden moving thing are not there;
##   * the record is presentation only (only the eye view reads it);
##   * in the eye view the shimmer sits where the thing is drawn, fades when the thing stops, and is weak or absent inside the sharp
##     retinal fields; the orbit view has none;
##   * it pulses (3 Hz, under the flash guideline) and holds steady under Reduced motion.

const WEST_PATH := [Vector3(-29.5, 1.4, -7.9), Vector3(-27.6, 1.4, -7.9)]


func _moving_west(t: Node3D) -> void:
	t.pause_s = 0.0
	t.set_path(PackedVector3Array(WEST_PATH))


func _eye() -> CanvasLayer:
	return world.eye_overlay


func test_the_lateral_eyes_register_motion_not_stillness() -> void:
	await spawn_stage(false, 0.0, WEST_VISIBLE)
	await physics_frames(20)
	check(world.sensor.motion_seen.is_empty(), "a standing marker in plain view: nothing moves")
	target().pause_s = 0.0
	target().release()
	await physics_frames(20)
	var e: Dictionary = world.sensor.motion_seen.get(TARGET_ID, {})
	if not check(not e.is_empty(), "the moving marker is registered as motion"):
		return
	var truth := toward(target().global_position)
	check(rad_to_deg((e["direction"] as Vector3).angle_to(truth)) < 6.0, "where it was seen (%.1f degrees off)" % rad_to_deg((e["direction"] as Vector3).angle_to(truth)))
	check_near(float(e["distance"]), eye().distance_to(target().global_position), 0.6, "at about its distance")
	target().hold_at(target().global_position)
	await physics_frames(world.sensor.MOTION_HOLD_TICKS + 15)
	check(not world.sensor.motion_seen.has(TARGET_ID), "once it stands still the motion fades from the record")


func test_a_hidden_moving_thing_is_not_registered() -> void:
	await spawn_stage(false, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([BEHIND_SCREEN + Vector3(-0.3, 0.0, 0.0), BEHIND_SCREEN + Vector3(0.3, 0.0, 0.0)])))
	var hidden_throughout := [true]
	for i in 60:
		await physics_frames(1)
		hidden_throughout[0] = bool(hidden_throughout[0]) and target_is_hidden()
	check(bool(hidden_throughout[0]), "the marker stayed behind the screen")
	check(not world.sensor.motion_seen.has(TARGET_ID), "moving out of sight: no motion registered")


func test_in_the_eye_view_a_moving_thing_shimmers_in_the_surround() -> void:
	await spawn_stage(true, heading_toward(WEST_VISIBLE) - 28.0, null, _moving_west)
	settings.set_value("eye_view", true)
	await physics_frames(30)
	var eye := _eye()
	var cam: Camera3D = world.camera_rig.camera
	var p: Vector3 = target().global_position
	if not check(not cam.is_position_behind(p), "the marker is in front of the eye view"):
		return
	await wait_until(func() -> bool: return not eye.movers.is_empty(), 60)
	if not check(not eye.movers.is_empty(), "a moving thing in the surround shimmers"):
		return
	var m: Dictionary = eye.movers[0]
	var size := cam.get_viewport().get_visible_rect().size
	var tan_half := tan(deg_to_rad(cam.fov) * 0.5)
	var drawn: Vector2 = eye.screen_angle_deg(cam.unproject_position(target().global_position) / size, tan_half, size.x / size.y)
	check((m["angle"] as Vector2).distance_to(drawn) < 4.0, "where it is drawn (%s, drawn at %s)" % [str(m["angle"]), str(drawn)])
	check(float(m["strength"]) > 0.5, "clearly, outside the sharp fields (%.2f)" % float(m["strength"]))
	check(absf((m["angle"] as Vector2).x) > 12.0, "and it is out in the surround (%.1f degrees across)" % (m["angle"] as Vector2).x)
	check(float(m["radius"]) >= eye.MOVER_MIN_DEG, "at least %.1f degrees across" % eye.MOVER_MIN_DEG)
	target().hold_at(target().global_position)
	await physics_frames(world.sensor.MOTION_HOLD_TICKS + 15)
	check(eye.movers.is_empty(), "it fades once the thing stands still")
	settings.set_value("eye_view", false)
	await physics_frames(2)
	check(eye.movers.is_empty() and not (eye.get_node("EyeView") as Control).visible, "the orbit view has no shimmer")


func test_the_sharp_retinal_fields_see_form_not_shimmer() -> void:
	await spawn_stage(true, 0.0, null, _moving_west)
	settings.set_value("eye_view", true)
	await physics_frames(10)
	var eye := _eye()
	eye.set_process(false)
	eye._process(0.0)
	check(eye.sharpness_at(eye.left_scan_deg) > 0.95, "the left retina's field is sharp")
	check(eye.sharpness_at(eye.right_scan_deg) > 0.95, "and the right one's")
	check(eye.sharpness_at(Vector2(30.0, 0.0)) < 0.01 and eye.sharpness_at(Vector2(-30.0, 10.0)) < 0.01, "the surround is soft")
	for i in 40:
		await physics_frames(1)
		eye._process(1.0 / 60.0)
		for m: Dictionary in eye.movers:
			check(float(m["strength"]) <= 1.0 - eye.sharpness_at(m["angle"]) + 0.001, "no shimmer stronger than the softness where it is")


func test_reduced_motion_holds_the_shimmer_steady() -> void:
	await spawn_stage(true, 0.0, null, _moving_west)
	settings.set_value("eye_view", true)
	await physics_frames(5)
	var eye := _eye()
	eye.set_process(false)
	var seen := {}
	for i in 12:
		eye._process(1.0 / 30.0)
		seen[snappedf(eye.flicker, 0.01)] = true
	check(seen.size() > 4, "the shimmer pulses (%d levels over 0.4 s)" % seen.size())
	check(eye.FLICKER_HZ <= 3.0, "at no more than three pulses a second")
	settings.set_value("reduced_motion", true)
	seen.clear()
	for i in 12:
		eye._process(1.0 / 30.0)
		seen[snappedf(eye.flicker, 0.01)] = true
	check_eq(seen.size(), 1, "Reduced motion: it holds steady")
	settings.set_value("reduced_motion", false)
