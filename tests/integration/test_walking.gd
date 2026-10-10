extends "res://tests/world_test_case.gd"
## Real physics: the spider walks in the traversal lab. Tolerances are loose on purpose;
## the point is "stays on the floor, goes where told, stops when told".


func _settle() -> void:
	await physics_frames(40)


func test_forward_intent_walks_forward_on_the_floor() -> void:
	spawn_world()
	var spider = world.spider
	await _settle()
	check_eq(spider.get_state_name(), "ATTACHED", "spider is attached after settling")
	var start: Vector3 = spider.global_position
	check_near(start.y, 0.3, 0.03, "rests on the floor (centre 0.3 WU up)")
	spider.set_intent(Vector3.RIGHT, false)  # the spawn faces +X
	var min_y := start.y
	var max_y := start.y
	var off_floor := 0
	for i in 120:
		await physics_frames(1)
		min_y = minf(min_y, spider.global_position.y)
		max_y = maxf(max_y, spider.global_position.y)
		if not spider.is_supported() or spider.get_support_normal() != Vector3.UP or spider.support.surface_id != "floor":
			off_floor += 1
	var moved: Vector3 = spider.global_position - start
	check(moved.x > 4.0 and moved.x < 5.5, "about 2 s at 2.5 WU/s moves 4 to 5.5 WU forward, moved %f" % moved.x)
	check(absf(moved.z) < 0.05, "no sideways drift, z moved %f" % moved.z)
	check(max_y - min_y < 0.03, "no sinking or hopping, height range %f" % (max_y - min_y))
	check_eq(off_floor, 0, "never leaves the floor")
	check_near(Vector3(spider.velocity.x, 0.0, spider.velocity.z).length(), 2.5, 0.15, "reaches walking speed")


func test_stalk_is_slower_than_walk() -> void:
	spawn_world()
	var spider = world.spider
	await _settle()
	spider.set_intent(Vector3.RIGHT, true)
	await physics_frames(60)
	check_near(Vector3(spider.velocity.x, 0.0, spider.velocity.z).length(), 0.8, 0.08, "stalk speed 0.8 WU/s")


func test_zero_intent_does_not_drift() -> void:
	spawn_world()
	var spider = world.spider
	await _settle()
	var start: Vector3 = spider.global_position
	await physics_frames(120)
	check(spider.global_position.distance_to(start) < 0.001, "no drift in 2 s, moved %f" % spider.global_position.distance_to(start))
	check_eq(spider.get_state_name(), "ATTACHED", "still attached")


func test_walking_stops_when_intent_stops() -> void:
	spawn_world()
	var spider = world.spider
	await _settle()
	spider.set_intent(Vector3.RIGHT, false)
	await physics_frames(60)
	spider.set_intent(Vector3.ZERO, false)
	await physics_frames(30)
	check(Vector3(spider.velocity.x, 0.0, spider.velocity.z).length() < 0.01, "stopped within 0.5 s")
	var rest: Vector3 = spider.global_position
	await physics_frames(30)
	check(spider.global_position.distance_to(rest) < 0.001, "and stays stopped")


func test_acceleration_is_quick_but_not_instant() -> void:
	spawn_world()
	var spider = world.spider
	await _settle()
	spider.set_intent(Vector3.RIGHT, false)
	await physics_frames(2)
	var early := Vector3(spider.velocity.x, 0.0, spider.velocity.z).length()
	check(early > 0.0 and early < 2.5, "after 2 ticks the speed is partial, %f" % early)
	await physics_frames(30)
	check_near(Vector3(spider.velocity.x, 0.0, spider.velocity.z).length(), 2.5, 0.1, "full speed within 0.5 s")


func test_body_turns_toward_movement_at_a_capped_rate() -> void:
	spawn_world()
	var spider = world.spider
	await _settle()
	var h0: float = spider.get_heading()
	spider.set_intent(Vector3.LEFT, false)  # opposite the facing: a 180 degree turn
	var worst := 0.0
	var last: float = h0
	var turned_at := -1
	for i in 60:
		await physics_frames(1)
		var h: float = spider.get_heading()
		worst = maxf(worst, absf(angle_difference(last, h)))
		last = h
		if turned_at < 0 and absf(angle_difference(h0, h)) > deg_to_rad(175.0):
			turned_at = i
	check(worst <= deg_to_rad(540.0) / 60.0 + 0.01, "turn per tick is capped, worst %f rad" % worst)
	check(worst > deg_to_rad(2.0), "and the turn is not frozen")
	check(turned_at > 8 and turned_at < 40, "a half turn takes a fraction of a second, frame %d" % turned_at)


## Chunk 3 (T02) changed this case: the ledge is attachable, so walking off its edge wraps onto its
## side face and down to the floor instead of falling. The fall now happens at the coated platform.
func test_walking_off_a_ledge_wraps_down_its_side_face() -> void:
	spawn_world()
	var spider = world.spider
	await _settle()
	var top: Vector3 = world.lab.get_piece_top("ledge_2")  # top at y = 2, x -10..-7
	spider.teleport_to(Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-9.0, top.y + 0.31, top.z)))
	world.camera_rig.snap_to_target()
	await physics_frames(30)
	check_eq(spider.get_state_name(), "ATTACHED", "attached on the ledge")
	check_near(spider.global_position.y, top.y + 0.3, 0.05, "standing on the ledge top")
	var states: Array[String] = []
	spider.state_changed.connect(func(_old: int, new_state: int) -> void: states.append(spider.State.keys()[new_state]))
	var faces: Array[String] = []
	var on_floor := 0
	spider.set_intent(Vector3.RIGHT, false)
	for i in 240:
		await physics_frames(1)
		if spider.in_transition():
			continue  # mid-arc normals belong to no face
		var n: Vector3 = spider.get_support_normal()
		var face := "top" if n.y > 0.99 and spider.global_position.y > 1.0 else ("side" if n.x > 0.99 else ("floor" if n.y > 0.99 else "other"))
		if faces.is_empty() or faces[faces.size() - 1] != face:
			faces.append(face)
		on_floor = on_floor + 1 if face == "floor" else 0
		if on_floor >= 20:
			break
	spider.set_intent(Vector3.ZERO, false)
	check_eq(states, [] as Array[String], "never falls: the side face holds the spider")
	check_eq(faces, ["top", "side", "floor"] as Array[String], "ledge top, then its east face, then the floor")
	check_near(spider.global_position.y, 0.31, 0.03, "ends on the floor")
	check(spider.global_position.x > -7.0, "walking on east, away from the ledge, x = %f" % spider.global_position.x)


func test_walking_off_the_coated_platform_falls_then_lands() -> void:
	spawn_world()
	var spider = world.spider
	await _settle()
	var top: Vector3 = world.lab.get_piece_top("gap_right")  # coated, top at y = 2, x 15..19
	spider.teleport_to(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(16.5, top.y + 0.31, top.z)))  # faces -X
	world.camera_rig.snap_to_target()
	await physics_frames(30)
	check_eq(spider.get_state_name(), "ATTACHED", "standing on the coated platform: level surfaces need no grip")
	check_near(spider.global_position.y, top.y + 0.3, 0.05, "standing on its top")
	var states: Array[String] = []
	spider.state_changed.connect(func(_old: int, new_state: int) -> void: states.append(spider.State.keys()[new_state]))
	spider.set_intent(Vector3.LEFT, false)
	var fell := await wait_until(func() -> bool: return states.has("FALLING"), 240)
	check(fell, "walking off the edge enters FALLING: the coated side face cannot hold the spider")
	spider.set_intent(Vector3.ZERO, false)
	var landed := await wait_until(func() -> bool: return states.size() >= 3 and spider.get_state_name() == "ATTACHED", 240)
	check(landed, "then lands and is ATTACHED again")
	check_eq(states, ["FALLING", "LANDING", "ATTACHED"] as Array[String], "state sequence")
	check_near(spider.global_position.y, 0.3, 0.05, "lands on the floor, not through it")
	check_eq(spider.support.surface_id, "floor", "on the floor between the platforms")
	check(spider.last_landing_speed > 8.0 and spider.last_landing_speed < 14.0, "landing speed matches a 2 WU fall under 35 WU/s^2, got %f" % spider.last_landing_speed)


func test_walks_up_the_ramp_onto_the_block_without_falling() -> void:
	spawn_world(floor_spawn(-15.0, 5.0, -90.0))  # faces +X, toward the ramp foot at x = -13.2
	var spider = world.spider
	await physics_frames(40)
	var states: Array[String] = []
	spider.state_changed.connect(func(_old: int, new_state: int) -> void: states.append(spider.State.keys()[new_state]))
	spider.set_intent(Vector3.RIGHT, false)
	var max_y := 0.0
	for i in 330:
		await physics_frames(1)
		max_y = maxf(max_y, spider.global_position.y)
	var p: Vector3 = spider.global_position
	check(p.x > -5.5, "reached the block top, x = %f" % p.x)
	check_near(p.y, 3.4 + 0.3, 0.08, "standing on the block top (3.4 WU up)")
	check_eq(spider.get_state_name(), "ATTACHED", "attached on top")
	check(not states.has("FALLING"), "never fell during the climb: %s" % str(states))
	check(max_y < 3.4 + 0.3 + 0.12, "no hop at the crest, highest centre %f" % max_y)
