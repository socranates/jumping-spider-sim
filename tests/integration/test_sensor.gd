extends "res://tests/perception_test_case.gd"
## The SensorSystem on the stage (spec 7, 19.3, 20; T06): peripheral cues are coarse and rate limited, the forward cone refines a
## category with continuous exposure, the world hides what it stands in front of, the camera never turns the cone, Focus does
## (at a capped rate), and nothing is made for a thing that was never sensed.


func test_a_moving_thing_in_the_periphery_gives_a_coarse_cue_and_nothing_else() -> void:
	await spawn_stage(false, 0.0, WEST_VISIBLE)
	check(mem().count() == 0, "a standing marker, in plain view, outside the cone: no motion, no cue")
	target().release()
	await physics_frames(40)
	var c := target_contact()
	if not check(c != null, "the moving marker was noticed"):
		return
	check_eq(c.modality, Observation.PERIPHERAL, "by the peripheral channel")
	check_eq(c.category, Observation.MOVEMENT, "as movement and nothing finer")
	check(not c.has_position and not c.has_mark(), "with no position to point at")
	check_eq(c.target_id, "", "and no target resolved")
	check(c.confidence >= 0.1 and c.confidence <= 0.3, "a weak cue (%.2f)" % c.confidence)
	var truth := toward(target().global_position)
	var err := rad_to_deg(c.cue_direction.angle_to(truth))
	check(err > 0.5 and err < 30.0, "the bearing is a sector and a band, not the truth: it is %.1f degrees off" % err)
	check_eq(world.sensor.inspections_made, 0, "nothing was inspected")
	check(off_axis_deg(target().global_position) > 15.0, "because it is outside the 30 degree cone (%.0f degrees off)" % off_axis_deg(target().global_position))


func test_cues_come_at_most_once_per_cooldown() -> void:
	var ticks: Array[int] = []
	await spawn_stage(false, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([Vector3(-29.5, 1.4, -7.9), Vector3(-27.6, 1.4, -7.9)])))
	world.sensor.cue_emitted.connect(func(o: Observation) -> void: ticks.append(o.observed_tick))
	await physics_frames(60 * 4)
	check(ticks.size() >= 4 and ticks.size() <= 5, "about one cue every 0.8 s over 4 s of constant motion: %d" % ticks.size())
	for i in range(1, ticks.size()):
		check(ticks[i] - ticks[i - 1] >= 48, "cues %d and %d are %d ticks apart (cooldown 48)" % [i - 1, i, ticks[i] - ticks[i - 1]])


func test_broad_queries_run_at_ten_hertz_and_close_things_are_checked_every_tick() -> void:
	await spawn_stage(false, 0.0, BEHIND_SCREEN)
	var sensor: Node = world.sensor
	var scans0: int = sensor.broad_scans
	var checks0: int = sensor.checks_total
	await physics_frames(120)
	var scans: int = sensor.broad_scans - scans0
	var checks: int = sensor.checks_total - checks0
	check(scans >= 19 and scans <= 21, "10 broad scans a second: %d in 2 s" % scans)
	check(checks >= 19 and checks <= 21, "a far marker that is not being tracked is looked at on those scans only: %d checks" % checks)
	target().hold_at(eye() + Vector3(0.0, -0.5, -3.0))
	var c1: int = sensor.checks_total
	await physics_frames(120)
	check(sensor.checks_total - c1 >= 118, "a marker within 4 WU is checked every tick: %d in 120" % (sensor.checks_total - c1))
	check(sensor.max_rays_in_a_tick <= 20, "the rays in one tick stay few (%d)" % sensor.max_rays_in_a_tick)


func test_the_cone_refines_a_category_with_continuous_exposure() -> void:
	await spawn_stage(false, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	check(absf(angle_difference(deg_to_rad(heading_deg()), deg_to_rad(heading_toward(WEST_VISIBLE)))) < deg_to_rad(1.0), "the body faces the marker (the marker is %.0f degrees below the gaze, inside the half cone)" % off_axis_deg(WEST_VISIBLE))
	var seen: Array = []
	var first := -1
	for i in 75:
		await physics_frames(1)
		var c := target_contact()
		if c != null and c.modality == Observation.INSPECTION:
			if first < 0:
				first = c.first_tick
			seen.append([float(world.sensor.tick - first + 1) / 60.0, c.category])
	check(first >= 0, "it was inspected")
	var possible_at := -1.0
	var fly_at := -1.0
	for row: Array in seen:
		if possible_at < 0.0 and row[1] != Observation.MOVEMENT:
			possible_at = row[0]
		if fly_at < 0.0 and row[1] == Observation.FLY_LIKE_PREY:
			fly_at = row[0]
	check(possible_at >= 0.39 and possible_at <= 0.45, "possible prey after 0.4 s of continuous exposure (at %.2f s)" % possible_at)
	check(fly_at >= 0.99 and fly_at <= 1.06, "fly-like prey after 1.0 s (at %.2f s)" % fly_at)
	var c := target_contact()
	check_eq(c.target_id, TARGET_ID, "the target is resolved once it is possible prey")
	check(c.confidence > 0.9, "and the confidence is high (%.2f)" % c.confidence)
	check(c.has_position and c.position.distance_to(target().global_position) < 0.5, "at about where it is (%.2f WU off)" % c.position.distance_to(target().global_position))


func test_a_marker_that_never_looks_like_prey_is_never_refined() -> void:
	await spawn_stage(false, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	target().max_category = Observation.MOVEMENT
	await physics_frames(90)
	var c := target_contact()
	check(c != null and c.is_inspected_now(), "inspected for 1.5 s")
	check_eq(c.category, Observation.MOVEMENT, "and still only movement")
	check_eq(c.target_id, "", "with no target resolved")


func test_a_marker_that_looks_too_small_is_not_inspected() -> void:
	# 6.2 WU away: a radius of 0.03 looks 0.55 degrees across (under the 0.6 minimum), 0.05 looks 0.92.
	await spawn_stage(false, heading_toward(WEST_VISIBLE), WEST_VISIBLE, func(t: Node3D) -> void: t.radius = 0.03)
	await physics_frames(90)
	check(world.sensor.get_track(TARGET_ID).last_check.get("apparent_deg", 9.0) < 0.6, "it looks under 0.6 degrees across (%.2f)" % world.sensor.get_track(TARGET_ID).last_check.get("apparent_deg", 9.0))
	check_eq(world.sensor.inspections_made, 0, "so it is not inspected, however long it is in the cone")
	world.free()
	await spawn_stage(false, heading_toward(WEST_VISIBLE), WEST_VISIBLE, func(t: Node3D) -> void: t.radius = 0.05)
	await wait_until(func() -> bool: return target_contact() != null, 30)
	var c := target_contact()
	check(c != null and c.is_inspected_now(), "at 0.92 degrees it can be inspected")
	await wait_until(func() -> bool: return world.sensor.tick - c.first_tick >= 60, 120)
	check(world.sensor.get_track(TARGET_ID).last_check.get("apparent_deg", 0.0) >= 0.6, "it looks 0.92 degrees across")
	check_eq(c.category, Observation.MOVEMENT, "a thing that small needs 3.3 times as long to refine (1.3 s): after 1.0 s it is still movement")
	await wait_until(func() -> bool: return world.sensor.tick - c.first_tick >= 80, 120)
	check_eq(c.category, Observation.POSSIBLE_PREY, "after 1.3 s it is possible prey")


func test_the_world_hides_what_it_stands_in_front_of() -> void:
	await spawn_stage(false, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([Vector3(-25.2, 1.4, -7.9), Vector3(-23.8, 1.4, -7.9)])))
	check(target_is_hidden(), "the screen hides the marker from the ledge")
	await physics_frames(90)
	check(target_is_hidden(), "still hidden while it walks about behind the screen")
	check_eq(world.sensor.cues_made, 0, "it moves behind cover: no cue")
	check_eq(world.sensor.inspections_made, 0, "and it is dead ahead, in the cone: no inspection either")
	check_eq(mem().count(), 0, "the memory holds nothing")
	check_eq(world.sensor.track_id_for(TARGET_ID), "", "and the sensor never gave it a track")
	check_eq(world.sensor.get_track(TARGET_ID).last_check.get("visible_points", -1), 0, "no sample point could be seen")


func test_turning_the_camera_never_turns_the_cone() -> void:
	await spawn_stage(true, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([Vector3(-29.5, 1.4, -7.9), Vector3(-27.6, 1.4, -7.9)])))
	var rig: Node3D = world.camera_rig
	var spider: Node3D = world.spider
	var gaze0: Vector3 = spider.get_gaze_direction()
	var heading0: Vector3 = spider.get_heading_vector()
	var worst := 0.0
	for i in 180:
		rig.yaw = float(i) * deg_to_rad(2.0)   # a full turn of the camera round the spider, and a half turn more
		rig.elevation = deg_to_rad(10.0 + 20.0 * sin(float(i) * 0.1))
		await physics_frames(1)
		worst = maxf(worst, spider.get_gaze_direction().angle_to(gaze0))
		worst = maxf(worst, spider.get_heading_vector().angle_to(heading0))
		check_vec_near(world.sensor.last_axis, spider.get_gaze_direction(), 1e-9, "the sensor's axis is the body's gaze (tick %d)" % i)
	check_near(worst, 0.0, 1e-9, "the gaze and heading never moved while the camera went round (%.6f rad)" % worst)
	check(not spider.is_focusing(), "Focus was never on")
	var c := target_contact()
	check(c != null and c.modality == Observation.PERIPHERAL, "the marker, 35 degrees off, was only ever a cue, however the camera looked at it")
	check_eq(world.sensor.inspections_made, 0, "never inspected, not once")
	check(world.sensor.cues_made >= 4, "though it was noticed again and again (%d cues)" % world.sensor.cues_made)


func test_a_camera_that_looks_away_does_not_take_the_cone_off_what_is_ahead() -> void:
	await spawn_stage(true, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	world.camera_rig.yaw = deg_to_rad(180.0)   # the camera looks south, away from the marker, which is dead ahead of the spider
	await physics_frames(60)
	var c := target_contact()
	check(c != null and c.is_inspected_now(), "the marker ahead of the body is inspected whatever the camera looks at")
	check(Observation.rank(c.category) >= Observation.rank(Observation.POSSIBLE_PREY), "and refined past movement (%s)" % str(c.category))


func test_focus_turns_the_body_toward_the_camera_aim_at_a_capped_rate() -> void:
	await spawn_stage(true, 0.0, WEST_VISIBLE)
	var rig: Node3D = world.camera_rig
	var spider: Node3D = world.spider
	var ctl: Node = world.controller
	rig.yaw = deg_to_rad(90.0)   # the camera looks west: a quarter turn from where the body faces
	await physics_frames(3)
	var start := heading_deg()
	check_near(start, 0.0, 0.5, "the body still faces north (%.1f)" % start)
	ctl.focus_override = true
	var prev := start
	var worst_step := 0.0
	var ticks_to_turn := -1
	for i in 90:
		await physics_frames(1)
		var h := heading_deg()
		worst_step = maxf(worst_step, absf(angle_difference(deg_to_rad(prev), deg_to_rad(h))))
		prev = h
		if ticks_to_turn < 0 and absf(angle_difference(deg_to_rad(h), deg_to_rad(90.0))) < deg_to_rad(2.0):
			ticks_to_turn = i + 1
	check(spider.is_focusing(), "Focus is on")
	check_near(rad_to_deg(worst_step), 3.0, 0.2, "the body turns at most 180 degrees a second: %.2f degrees a tick" % rad_to_deg(worst_step))
	check(ticks_to_turn >= 28 and ticks_to_turn <= 34, "a quarter turn takes about half a second (%d ticks)" % ticks_to_turn)
	check_near(angle_difference(deg_to_rad(heading_deg()), deg_to_rad(90.0)), 0.0, deg_to_rad(2.0), "and it ends facing where the camera looks (%.1f)" % heading_deg())
	ctl.focus_override = false
	var h1 := heading_deg()
	rig.yaw = deg_to_rad(-60.0)
	await physics_frames(30)
	check_near(heading_deg(), h1, 1e-6, "letting go of Focus leaves the body where it is, whatever the camera does")
	check(not spider.is_focusing(), "Focus is off")


func test_focus_tilts_the_gaze_toward_what_the_camera_aims_at_within_its_limit() -> void:
	await spawn_stage(true, 0.0, WEST_VISIBLE)
	var spider: Node3D = world.spider
	check_near(spider.get_gaze_pitch(), 0.0, 1e-9, "the gaze starts level")
	world.controller.focus_direction_override = (Vector3(0.0, -1.0, -1.0)).normalized()
	world.controller.focus_override = true
	await physics_frames(60)
	check_near(rad_to_deg(spider.get_gaze_pitch()), -35.0, 0.01, "looking steeply down it stops at the limit (%.1f)" % rad_to_deg(spider.get_gaze_pitch()))
	check(spider.get_gaze_direction().y < -0.5, "and the cone's axis points down")
	world.controller.focus_override = false
	await physics_frames(90)
	check_near(spider.get_gaze_pitch(), 0.0, 1e-6, "released, the gaze comes back level")


func test_a_thing_that_is_never_sensed_leaves_no_trace_anywhere() -> void:
	await spawn_stage(true, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([BEHIND_SPIDER, BEHIND_SPIDER + Vector3(2.0, 0.0, 0.0)])))
	await physics_frames(180)
	check(target().velocity.length() > 0.5, "the marker is moving, behind the spider")
	check_eq(mem().count(), 0, "no contact")
	check_eq(world.sensor.cues_made + world.sensor.inspections_made, 0, "no evidence was made")
	check_eq(world.sensor.track_id_for(TARGET_ID), "", "no track id was ever given")
	var view: Dictionary = world.perception_hud.build_view(world.camera_rig.camera, world.get_viewport().get_visible_rect(), world.get_world_3d().direct_space_state)
	check(view["edges"].is_empty() and view["labels"].is_empty() and view["rings"].is_empty(), "and nothing is drawn for it")


func test_the_sensor_takes_its_numbers_from_the_species_profile() -> void:
	await spawn_stage(false, 0.0, BEHIND_SCREEN)
	var p: RefCounted = world.spider.profile
	var s: Node = world.sensor
	check_near(s.cone_deg, p.inspect_cone_degrees, 1e-9, "cone")
	check_near(s.easy_s, p.easy_target_inspection_s, 1e-9, "easy exposure")
	check_near(s.cue_cooldown_s, p.cue_cooldown_s, 1e-9, "cue cooldown")
	check_near(s.broad_hz, p.broad_query_hz, 1e-9, "broad rate")
	check_near(s.range_wu, p.sensor_range_wu, 1e-9, "range")
	check_near(world.memory.decay_s, p.memory_decay_s, 1e-9, "memory decay")
	check_near(world.memory.hold_inspection_s, p.exposure_grace_s, 1e-9, "inspection hold")
	check_near(world.memory.hold_peripheral_s, p.cue_cooldown_s + 0.2, 1e-9, "cue hold")
