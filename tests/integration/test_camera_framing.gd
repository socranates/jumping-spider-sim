extends "res://tests/tether_test_case.gd"
## The camera's line framing (chunk 6A, A-017) as behaviour: it turns the view to the open side when the spider hangs
## on its line and the player's own view has no room, holds that turn, steps aside for any look input, a recenter or
## aiming, never rolls, and the walking controls steer by what is on screen. What it does to the view over the whole
## catch and grab, measured, is in test_catch_camera.gd.
##
## Chunk 6B (Chet's temporary change): the turn is capped at 45 degrees (FRAMING_MAX_TURN_DEG), it is a setting,
## "Frame the line after a catch" (default on), and any look input cancels a turn at once, in progress or held. At the
## cliff cap with the camera behind the spider (the view a catch from the cap starts in) the smallest turn that clears
## the cliff is 90 degrees, so the cap leaves that view as it was in chunk 5; these tests use a player view that is 30
## degrees off (a turn the cap allows) to show the framing, and test_catch_camera.gd measures both.

const LOOK_ACTIONS := ["look_left", "look_right", "look_up", "look_down"]
## A player view 30 degrees from the open side of the cliff: the smallest working turn is +30 degrees, inside the cap.
const FRAMED_YAW := -0.5235987755982988


func after_each() -> void:
	for a: String in LOOK_ACTIONS:
		Input.action_release(a)


## The cliff-cap catch with no camera input: the spider is caught, hangs, and the framing has had `ticks` ticks to act.
## `cap` lifts the framing's cap (radians) for the comparison with chunk 6A.
func _hang(ticks: int, yaw: Variant = null, cap: Variant = null) -> Node3D:
	spawn_world(cliff_pose(), true)
	await physics_frames(6)
	var spider: Node3D = world.spider
	await settle(spider)
	if yaw is float:
		world.camera_rig.yaw = yaw
	if cap is float:
		world.camera_rig.framing_max_turn = cap
	var jc: Node = world.jump_controller
	var events := record_line_events(spider)
	jc.aim_override = top_target(27.3, -7.0)
	jc.press()
	await physics_frames(14)
	await process_frames(2)
	jc.release()
	await wait_until(func() -> bool: return events.has("caught"), 240)
	await physics_frames(ticks)
	return spider


func test_the_view_turns_to_the_open_side_by_the_smallest_turn_and_holds_it() -> void:
	var spider := await _hang(90, FRAMED_YAW)
	var rig: Node3D = world.camera_rig
	check(spider.is_on_line(), "the spider hangs on its line")
	check_near(rig.yaw_assist, deg_to_rad(30.0), 1e-3, "the view has turned 30 degrees, the smallest 15 degree step with room (15 degrees has none: the cliff is in the way)")
	check_near(rig.view_yaw(), rig.yaw + rig.yaw_assist, 1e-12, "the view is the player's yaw plus the turn")
	check_near(rig.yaw, FRAMED_YAW, 1e-6, "the player's own yaw is untouched")
	check(rig.boom_length > 4.5, "the boom is open, %.2f WU" % rig.boom_length)
	var sign0 := signf(rig.yaw_assist)
	var drift := 0.0
	var flips := 0
	var start: float = rig.yaw_assist
	for i in 150:
		await physics_frames(1)
		drift = maxf(drift, absf(rig.yaw_assist - start))
		if signf(rig.yaw_assist) != sign0:
			flips += 1
	check(spider.is_on_line(), "still hanging after 2.5 s more")
	check_eq(flips, 0, "the turn never flips sides")
	check(drift < 1e-6, "and holds still while the spider rests (%f rad of drift)" % drift)
	var cam: Camera3D = rig.camera
	check_near(cam.global_transform.basis.x.y, 0.0, 1e-6, "the camera does not roll")
	var from: Vector3 = rig.global_position
	var out := cam.global_position - from
	check(absf(out.x) < 0.8 and absf(out.z) > 3.5, "the camera sits along the cliff face, clear of it: %s from the pivot" % str(out))


func test_a_look_input_wins_and_nothing_jumps() -> void:
	var spider := await _hang(90, FRAMED_YAW)
	var rig: Node3D = world.camera_rig
	var view0: float = rig.view_yaw()
	check(absf(rig.yaw_assist) > 0.4, "the framing has turned the view (%.0f degrees)" % rad_to_deg(rig.yaw_assist))
	rig.look(10.0, 0.0)
	check_near(angle_difference(view0, rig.view_yaw()), -deg_to_rad(10.0), 1e-4, "the view turns 10 degrees right, from where it was: no jump back to the player's own yaw")
	check_eq(rig.yaw_assist, 0.0, "the framing turn has become the player's own")
	var view1: float = rig.view_yaw()
	await physics_frames(150)
	check(spider.is_on_line(), "still on the line")
	check_near(angle_difference(view1, rig.view_yaw()), 0.0, 1e-6, "the framing does not take the view back while the line is out")
	check_eq(rig.yaw_assist, 0.0, "it stays off")
	# The player's own turns keep working as usual afterwards.
	var yaw1: float = rig.yaw
	rig.look(-20.0, 0.0)
	check_near(angle_difference(yaw1, rig.yaw), deg_to_rad(20.0), 1e-6, "a later look is an ordinary look")
	# Reel up and take hold: the line ends, and the view still stays.
	world.tether_controller.reel_override = 1.0
	var events := record_line_events(spider)
	var done := await wait_until(func() -> bool: return events.has("completed"), 600)
	world.tether_controller.reel_override = 0.0
	check(done, "the spider takes hold again")
	var yaw2: float = rig.yaw
	await physics_frames(90)
	check_near(angle_difference(yaw2, rig.yaw), 0.0, 1e-9, "the player's yaw is the same after the grab")
	check_eq(rig.yaw_assist, 0.0, "and no framing is left")


func test_the_look_stick_wins_too() -> void:
	var spider := await _hang(90, FRAMED_YAW)
	var rig: Node3D = world.camera_rig
	var view0: float = rig.view_yaw()
	Input.action_press("look_right")
	await process_frames(6)
	Input.action_release("look_right")
	check(angle_difference(view0, rig.view_yaw()) < -deg_to_rad(0.5), "the stick turns the view right from where it was")
	check_eq(rig.yaw_assist, 0.0, "the framing stepped aside")
	var view1: float = rig.view_yaw()
	await physics_frames(60)
	check_near(angle_difference(view1, rig.view_yaw()), 0.0, 1e-6, "and stays aside")
	check(spider.is_on_line(), "still on the line")


func test_a_recenter_and_aiming_take_the_view_as_well() -> void:
	var spider := await _hang(90, FRAMED_YAW)
	var rig: Node3D = world.camera_rig
	var view0: float = rig.view_yaw()
	check(absf(rig.yaw_assist) > 0.4, "the framing has turned the view first (%.0f degrees)" % rad_to_deg(rig.yaw_assist))
	rig.set_aiming(true)
	check_near(angle_difference(view0, rig.view_yaw()), 0.0, 1e-9, "aiming keeps the view where it is")
	check_eq(rig.yaw_assist, 0.0, "and the turn is the player's")
	rig.set_aiming(false)
	await physics_frames(30)
	check_eq(rig.yaw_assist, 0.0, "nothing frames the view again while the line is out")
	spider = world.spider
	rig.yaw_assist = PI / 2.0
	rig._assist_prev = PI / 2.0
	var view1: float = rig.view_yaw()
	rig.start_recenter()
	check_eq(rig.yaw_assist, 0.0, "a recenter takes the turn over, then turns as usual")
	check_near(angle_difference(view1, rig.view_yaw()), 0.0, 1e-9, "without a jump")
	await physics_frames(60)
	check_eq(rig.yaw_assist, 0.0, "and the framing stays off")


func test_the_turn_never_exceeds_the_cap_and_the_cap_is_what_stops_it() -> void:
	# The default view of the cliff-cap catch needs a quarter turn: more than the cap, so nothing turns and the view is
	# as crowded as in chunk 5 (test_catch_camera.gd gives the numbers). With the cap lifted, as in chunk 6A, it turns.
	var spider := await _hang(90)
	var rig: Node3D = world.camera_rig
	check(spider.is_on_line(), "the spider hangs on its line")
	check_eq(rig.yaw_assist, 0.0, "a 90 degree turn is beyond the 45 degree cap: the view is left to the pitch search")
	check(rig.boom_length < rig.COMFORT_BOOM, "so it is as squeezed as before (%.2f WU against a comfortable %.1f)" % [rig.boom_length, rig.COMFORT_BOOM])
	check_near(rig.framing_max_turn, deg_to_rad(45.0), 1e-12, "the cap is 45 degrees")
	world.free()
	spider = await _hang(90, null, PI)
	rig = world.camera_rig
	check_near(rig.yaw_assist, PI / 2.0, 1e-3, "with the cap lifted the quarter turn is made, as in chunk 6A, so the geometry allowed it and the cap stopped it")
	world.free()
	# A turn of exactly the cap is allowed; one step more is not.
	spider = await _hang(90, -PI / 4.0)
	rig = world.camera_rig
	check_near(rig.yaw_assist, PI / 4.0, 1e-3, "a view 45 degrees off turns by 45 degrees, exactly the cap")
	world.free()
	spider = await _hang(90, deg_to_rad(-60.0))
	rig = world.camera_rig
	check_eq(rig.yaw_assist, 0.0, "a view 60 degrees off would need 60: nothing turns")


func test_the_turn_is_a_setting_and_switching_it_off_leaves_the_view_where_it_is() -> void:
	check_eq(settings.frame_line_after_catch, true, "'Frame the line after a catch' is on by default")
	settings.frame_line_after_catch = false
	var spider := await _hang(90, FRAMED_YAW)
	var rig: Node3D = world.camera_rig
	check(spider.is_on_line(), "the spider hangs on its line")
	check_eq(rig.yaw_assist, 0.0, "with the setting off the view is not turned")
	check(not rig.framing_enabled(), "the rig says so")
	check_near(rig.view_yaw(), FRAMED_YAW, 1e-9, "the view is the player's own")
	world.free()
	settings.frame_line_after_catch = true
	spider = await _hang(90, FRAMED_YAW)
	rig = world.camera_rig
	check(absf(rig.yaw_assist) > 0.4, "with it on the view is turned (%.0f degrees)" % rad_to_deg(rig.yaw_assist))
	var view_on: float = rig.view_yaw()
	settings.frame_line_after_catch = false
	check_near(angle_difference(view_on, rig.view_yaw()), 0.0, 1e-4, "switching it off with a turn held does not swing the view back")
	check_eq(rig.yaw_assist, 0.0, "the held turn has become the player's own yaw")
	await physics_frames(60)
	check_near(angle_difference(view_on, rig.view_yaw()), 0.0, 1e-4, "and nothing moves afterwards")
	check(spider.is_on_line(), "the spider is still on its line")


func test_any_look_input_cancels_a_turn_in_progress_at_once() -> void:
	spawn_world(cliff_pose(), true)
	await physics_frames(6)
	var spider: Node3D = world.spider
	await settle(spider)
	var rig: Node3D = world.camera_rig
	rig.yaw = FRAMED_YAW
	var jc: Node = world.jump_controller
	var events := record_line_events(spider)
	jc.aim_override = top_target(27.3, -7.0)
	jc.press()
	await physics_frames(14)
	await process_frames(2)
	jc.release()
	await wait_until(func() -> bool: return events.has("locked"), 240)
	await physics_frames(3)
	var mid: float = rig.yaw_assist
	check(mid > 0.0 and mid < deg_to_rad(30.0) - 0.02, "three ticks after the line locks the turn is under way (%.1f of 30 degrees)" % rad_to_deg(mid))
	# What is on screen is the player's yaw plus the turn interpolated between the last two ticks, which is what a
	# look takes over, so the picture does not jump (view_yaw() is the value at the last tick).
	var view0: float = rig.yaw + lerpf(rig._assist_prev, rig.yaw_assist, clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0))
	rig.look(1.0, 0.0)  # the smallest look: one degree to the right
	check_eq(rig.yaw_assist, 0.0, "a look cancels the turn at once")
	check_near(angle_difference(view0, rig.view_yaw()), -deg_to_rad(1.0), 1e-4, "the view stays where it was, and turns by what was asked")
	var view1: float = rig.view_yaw()
	await physics_frames(120)
	check(spider.is_on_line(), "the spider is still on its line")
	check_near(angle_difference(view1, rig.view_yaw()), 0.0, 1e-6, "the turn never comes back")
	check_eq(rig.yaw_assist, 0.0, "and the framing stays off while the line is out")


func test_no_framing_where_the_view_is_already_good() -> void:
	# The player is already looking along the cliff face (yaw 0): the camera sits south of the spider, in the open.
	var spider := await _hang(120, 0.0)
	var rig: Node3D = world.camera_rig
	check(spider.is_on_line(), "the spider hangs on its line")
	check_eq(rig.yaw_assist, 0.0, "the player's own view has room, so the framing does nothing")
	check_near(rig.yaw, 0.0, 1e-12, "and the yaw is the player's")
	check(rig.boom_length > 4.5, "the boom is open, %.2f WU" % rig.boom_length)


func test_no_framing_without_a_line() -> void:
	spawn_world(floor_spawn(-22.0, 16.5, 180.0), true)  # facing the south wall: a squeezed view, but no line
	await physics_frames(40)
	var rig: Node3D = world.camera_rig
	var worst := 0.0
	for i in 60:
		await physics_frames(1)
		worst = maxf(worst, absf(rig.yaw_assist))
	check_eq(worst, 0.0, "a squeezed view without the safety line is left to the pitch search, as before")
	check_near(rig.camera.global_transform.basis.x.y, 0.0, 1e-6, "no roll")


func test_the_walking_controls_steer_by_the_view() -> void:
	spawn_world(floor_spawn(-22.0, 12.0, -90.0), true)  # faces +X; the camera looks along +X too
	await physics_frames(40)
	var rig: Node3D = world.camera_rig
	var controller: Node = world.controller
	controller.stick_override = Vector2(0.0, -1.0)  # forward
	controller._physics_process(0.0)
	check(world.spider.get_intent().x > 0.9, "forward follows the camera, +X: %s" % str(world.spider.get_intent()))
	rig.yaw_assist = PI / 2.0  # the view a quarter turn to the left, as the framing would leave it
	controller._physics_process(0.0)
	var intent: Vector3 = world.spider.get_intent()
	check(intent.z < -0.9 and absf(intent.x) < 0.1, "forward follows the turned view, -Z: %s" % str(intent))
	controller.stick_override = null
