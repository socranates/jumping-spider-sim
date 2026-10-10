extends "res://tests/perception_test_case.gd"
## The developer's view of the senses (F3 "Senses" lines, F4 cones and markers; spec 17, A-007): it may show what the player
## may not, and says so. Here: its numbers match the sensor's and the memory's, its cones follow the body and not the camera,
## and the one thing it takes from the world (the red truth marker) is the one thing the memory does not follow.

const PerceptionDebug = preload("res://scripts/presentation/perception_debug.gd")


func lines() -> PackedStringArray:
	return PerceptionDebug.describe(world.sensor, world.memory)


func joined() -> String:
	return "\n".join(lines())


func test_the_senses_lines_report_the_counters_and_what_the_memory_holds() -> void:
	await spawn_stage(false, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(70)
	var l := lines()
	check(l.size() >= 3, "a summary, a check and a contact: %d lines" % l.size())
	check(l[0].begins_with("Senses: tick "), "the first line is the sensor's counters")
	check(l[0].find("inspections %d" % world.sensor.inspections_made) >= 0 and l[0].find("broad scans %d" % world.sensor.broad_scans) >= 0, "and they are the sensor's own")
	var text := joined()
	check(text.find("check (developer, from the world) test_target") >= 0, "the check line says it comes from the world, and that it is for developers")
	check(text.find("in cone yes") >= 0 and text.find("sees 5 of 5 points") >= 0, "and what the sensor made of it: in the cone, all five points in view")
	var c := target_contact()
	check(text.find(c.track_id) >= 0 and text.find("fly_like_prey") >= 0 and text.find("confidence") >= 0, "the contact line carries its track, category and confidence")
	check(text.find("lost") < 0, "nothing is lost yet")
	world.lab.add_fixture_piece("test_wall", "wall", Vector3(-30.0, 0.0, -5.0), Vector3(-23.0, 4.0, -4.8))
	await physics_frames(90)
	text = joined()
	check(text.find("lost") >= 0 and text.find(", mark") >= 0, "once it is lost behind a wall: lost, and holding a mark")
	check(text.find("sees 0 of 5 points") >= 0, "and the check says the wall hides all five points")


func test_it_prints_nothing_for_a_memory_that_is_empty_but_the_summary() -> void:
	await spawn_stage(false, 0.0, BEHIND_SPIDER)
	await physics_frames(30)
	check_eq(mem().count(), 0, "nothing is known")
	var l := lines()
	check(l.size() >= 1 and l[0].begins_with("Senses:"), "the summary is there")
	var contacts := 0
	for line in l:
		if line.find("trk_") >= 0 or line.find("live") >= 0 or line.find("lost") >= 0:
			contacts += 1
	check_eq(contacts, 0, "and no contact lines")
	check_eq(PerceptionDebug.describe(null, null).size(), 0, "and nothing at all without a sensor")


func test_the_developer_view_shows_the_cone_with_the_body_and_the_truth_where_the_memory_is_not() -> void:
	await spawn_stage(true, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	var dbg: Node3D = world.perception_debug
	check(not dbg.is_visible_in_tree(), "it is hidden until the support view is switched on")
	world.support_debug.visible = true
	await physics_frames(70)
	dbg.refresh()
	var truth: Array = dbg._truth_markers.filter(func(m: MeshInstance3D) -> bool: return m.visible)
	var held: Array = dbg._memory_markers.filter(func(m: MeshInstance3D) -> bool: return m.visible)
	check_eq(truth.size(), 1, "one red truth marker, for the one thing in the world")
	check_eq(held.size(), 1, "one marker for the one thing the memory holds")
	check_vec_near(truth[0].global_position, target().global_position, 1e-6, "the red one is where the thing is")
	check_vec_near(held[0].global_position, target_contact().position, 1e-6, "the green one is where the memory has it")
	check(((held[0] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color == PerceptionDebug.LIVE_COLOR, "green while it is being inspected")
	# Behind a wall the thing walks on; the memory stays where it was.
	world.lab.add_fixture_piece("test_wall", "wall", Vector3(-30.0, 0.0, -5.0), Vector3(-23.0, 4.0, -4.8))
	await physics_frames(60)
	target().release()
	await physics_frames(60)
	dbg.refresh()
	truth = dbg._truth_markers.filter(func(m: MeshInstance3D) -> bool: return m.visible)
	held = dbg._memory_markers.filter(func(m: MeshInstance3D) -> bool: return m.visible)
	check(held.size() == 1 and truth.size() == 1, "still one of each")
	check(((held[0] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color == PerceptionDebug.LOST_COLOR, "the memory's marker has turned amber: lost")
	check(truth[0].global_position.distance_to(held[0].global_position) > 0.8, "and the truth has walked away from it (%.1f WU)" % truth[0].global_position.distance_to(held[0].global_position))
	check_vec_near(held[0].global_position, target_contact().position, 1e-6, "while the memory stayed")
	# The cone is the sensor's: along the body's gaze, from its eye, and the camera never changes it.
	var axis: Vector3 = world.sensor.last_axis
	check(axis.angle_to(world.spider.get_gaze_direction()) < deg_to_rad(1.0), "the cone's axis is the body's gaze")
	world.camera_rig.look(60.0, 0.0)
	await physics_frames(20)
	check(world.sensor.last_axis.angle_to(axis) < deg_to_rad(0.01), "which the camera does not move")
	check_near(world.sensor.cone_deg, 30.0, 1e-9, "its width is the profile's")
