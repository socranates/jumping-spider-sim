extends "res://tests/perception_test_case.gd"
## The gaze footprint (A-003; T06): off by default, a faint footprint where the cone meets the first surface along the body's
## gaze, stopping at whatever stands in the way, the same whether or not anything is hidden behind it, never moved by the
## camera. It may teach where the spider looks; it must not tell what it has not seen.

const GazeOverlay = preload("res://scripts/presentation/gaze_overlay.gd")


func footprint() -> Dictionary:
	return world.gaze_overlay.footprint


func switch_on() -> void:
	settings.set_value("show_gaze", true)
	await process_frames(3)


# ------------------------------------------------------------------ on and off

func test_it_is_off_by_default_and_draws_only_when_switched_on() -> void:
	check_eq(settings.get_value("show_gaze"), false, "the setting is off by default")
	await spawn_stage(true, 0.0, BEHIND_SCREEN)
	await process_frames(3)
	check(not world.gaze_overlay.is_showing() and footprint().is_empty(), "nothing is drawn")
	await switch_on()
	check(world.gaze_overlay.is_showing() and not footprint().is_empty(), "switched on, a footprint is drawn")
	settings.set_value("show_gaze", false)
	await process_frames(3)
	check(not world.gaze_overlay.is_showing() and footprint().is_empty(), "and switched off, it goes")


# ------------------------------------------------------------------ where it lands

func test_the_footprint_lies_on_the_first_surface_the_gaze_reaches_as_wide_as_the_cone() -> void:
	await spawn_stage(true, 0.0, null)
	await switch_on()
	var f := footprint()
	if not check(not f.is_empty(), "a footprint"):
		return
	# The spider looks level from (-24.5, 2.39, -2.88): the stage screen's face (z = -5.8) is the first thing in the way.
	check_near((f["point"] as Vector3).z, -5.8, 0.02, "on the screen's near face (z %.3f)" % (f["point"] as Vector3).z)
	check_near(float(f["distance"]), eye().distance_to(f["point"]), 1e-6, "its distance is from the eye")
	var want := clampf(float(f["distance"]) * tan(deg_to_rad(world.sensor.cone_deg) * 0.5), GazeOverlay.MIN_RADIUS, GazeOverlay.MAX_RADIUS)
	check_near(float(f["radius"]), want, 1e-6, "as wide as the %d degree cone is there (%.2f WU)" % [int(world.sensor.cone_deg), want])
	check(((f["normal"] as Vector3) - Vector3(0.0, 0.0, 1.0)).length() < 0.01, "lying on the face (normal %s)" % str(f["normal"]))


func test_a_wall_in_the_way_is_where_it_stops_and_what_is_behind_it_changes_nothing() -> void:
	await spawn_stage(true, 0.0, BEHIND_SCREEN)
	await switch_on()
	var with_target := footprint().duplicate()
	check(target_is_hidden(), "the marker is hidden behind the screen")
	target().set_enabled(false)
	await process_frames(3)
	var without := footprint().duplicate()
	check_eq(without, with_target, "with the marker taken away the footprint is exactly the same")
	target().set_enabled(true)
	target().hold_at(Vector3(-24.5, 1.4, -12.0))
	await process_frames(3)
	check_eq(footprint(), with_target, "moved further behind the screen, the same again")
	target().hold_at(Vector3(-24.5, 1.4, -4.0))
	await process_frames(3)
	check_eq(footprint(), with_target, "and moved to a spot in plain view in front of the screen, still the same: it never looks for targets")
	check_near((with_target["point"] as Vector3).z, -5.8, 0.02, "and it is on the screen, not past it")


func test_it_goes_where_the_body_looks_and_only_the_body_moves_it() -> void:
	await spawn_stage(true, 0.0, null)
	await switch_on()
	var before := footprint().duplicate()
	world.camera_rig.look(70.0, 0.0)   # the player orbits the camera well away
	await physics_frames(30)
	await process_frames(3)
	check_eq(footprint(), before, "swinging the camera does not move it")
	var heading0 := heading_deg()
	world.controller.focus_override = true
	world.controller.focus_direction_override = Vector3(1.0, 0.0, -0.4).normalized()   # Focus: turn the body toward the east
	await physics_frames(60)
	await process_frames(3)
	check(absf(heading_deg() - heading0) > 40.0, "Focus turned the body (%.0f degrees)" % (heading_deg() - heading0))
	var after := footprint()
	check(not after.is_empty() and (after["point"] as Vector3).distance_to(before["point"]) > 3.0, "and the footprint went with it (now at %s)" % str(after.get("point")))
	var axis: Vector3 = world.spider.get_gaze_direction()
	var on_ray: Vector3 = ((after["point"] as Vector3) - world.spider.get_eye_position(true)).normalized()
	check(on_ray.angle_to(axis) < deg_to_rad(0.5), "along the body's gaze")


func test_the_gaze_that_meets_nothing_within_reach_draws_nothing() -> void:
	await spawn_stage(true, 0.0, null)
	world.controller.focus_override = true
	world.controller.focus_direction_override = Vector3.UP   # straight up: the lab has no ceiling
	await physics_frames(90)
	await switch_on()
	var up: float = world.spider.get_gaze_pitch()
	check(up > deg_to_rad(30.0), "the gaze is tilted up (%.0f degrees)" % rad_to_deg(up))
	check(footprint().is_empty() and not world.gaze_overlay.is_showing(), "and meets nothing within reach: nothing is drawn")


# ------------------------------------------------------------------ the pure parts

func test_the_footprint_maths() -> void:
	await spawn_stage(false, 0.0, null)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var eye0 := Vector3(-24.5, 5.0, 5.0)   # above the open floor
	var down := GazeOverlay.compute_footprint(space, eye0, Vector3(0.0, -1.0, 0.0), 30.0, 40.0)
	check_near(float(down["distance"]), 5.0, 0.02, "straight down, the floor is 5 WU away")
	check_near(float(down["radius"]), 5.0 * tan(deg_to_rad(15.0)), 0.02, "the cone is %.2f WU wide there" % (5.0 * tan(deg_to_rad(15.0))))
	var close := GazeOverlay.compute_footprint(space, Vector3(-24.5, 0.5, 5.0), Vector3(0.0, -1.0, 0.0), 30.0, 40.0)
	check_near(float(close["radius"]), GazeOverlay.MIN_RADIUS, 1e-9, "a very small footprint is kept readable")
	var far := GazeOverlay.compute_footprint(space, Vector3(-24.5, 40.0, 5.0), Vector3(0.0, -1.0, 0.0), 30.0, 80.0)
	check_near(float(far["radius"]), GazeOverlay.MAX_RADIUS, 1e-9, "a huge one is capped")
	check(GazeOverlay.compute_footprint(space, eye0, Vector3.UP, 30.0, 40.0).is_empty(), "looking at the sky: no footprint")
	check(GazeOverlay.compute_footprint(space, Vector3(-24.5, 50.0, 5.0), Vector3(0.0, -1.0, 0.0), 30.0, 40.0).is_empty(), "nor when the surface is past reach")
	check(GazeOverlay.compute_footprint(null, eye0, Vector3.DOWN, 30.0, 40.0).is_empty(), "nor without a world")
	# The frame: a circle on the surface, longer along a shallow gaze, never more than three times.
	var n := Vector3.UP
	var b := GazeOverlay.footprint_basis(Vector3(0.0, -1.0, 0.0), n, 2.0)
	check_near(b.x.length(), 2.0, 1e-6, "looking straight at it, a true circle")
	check_near(b.z.length(), 2.0, 1e-6, "(both axes)")
	check_near(b.y.dot(n), 1.0, 1e-9, "and it lies on the surface")
	var shallow := GazeOverlay.footprint_basis(Vector3(1.0, -0.2, 0.0).normalized(), n, 2.0)
	check_near(shallow.x.length(), 2.0 * 3.0, 1e-6, "at a shallow angle it is stretched along the gaze, to three times at most")
	check_near(shallow.z.length(), 2.0, 1e-6, "and not across it")
	var annulus: ArrayMesh = GazeOverlay.make_annulus(0.9, 1.0, 24)
	var box := annulus.get_aabb()
	check(absf(box.size.x - 2.0) < 0.01 and absf(box.size.z - 2.0) < 0.01 and box.size.y < 1e-3, "a flat ring a unit across (%s)" % str(box.size))


func test_it_has_no_way_to_ask_what_has_been_sensed_or_where_anything_is() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/presentation/gaze_overlay.gd")
	var code := ""
	for line in src.split("\n"):
		if not line.strip_edges().begins_with("##") and not line.strip_edges().begins_with("#"):
			code += line + "\n"
	for word in ["memory", "contacts", "get_percept", "Perceivable", "perceivable", "get_nodes_in_group", "track_id", "observation"]:
		check(code.find(word) < 0, "its code never mentions \"%s\"" % word)
