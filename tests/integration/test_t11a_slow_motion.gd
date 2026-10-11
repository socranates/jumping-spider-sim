extends "res://tests/prey_test_case.gd"
## T11a, one game clock and slow motion (ROADMAP step 2; DECISIONS T9e-01, CLOCK-01; Nathan: "the slomo thing sounds cool"), and an
## easy switch between first and third person (Nathan: "add a button that can easily swtch between first and 3rd person"):
##   * every tick is 1/60 s of game time at any speed; slow motion only runs fewer of them each real second;
##   * a stalk, a fly's life and a strike play out the same at half speed, tick for tick, only slower;
##   * the setting and its key switch the speed of a played world, the screen says so, and a world never leaves the clock slowed;
##   * looking about is not slowed;
##   * V switches the view, a line on screen names it, and the pause menu has a button for it.

const SimClock = preload("res://scripts/core/sim_clock.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")


func after_each() -> void:
	SimClock.set_speed(1.0)
	for a: String in ["look_right"]:
		Input.action_release(a)
	super.after_each()


func _key(code: int, pressed: bool) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code as Key
	k.pressed = pressed
	return k


# ------------------------------------------------------------------ the clock

func test_every_tick_is_the_same_length_at_every_speed() -> void:
	check_eq(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")), SimClock.HZ, "the project runs the clock's rate")
	for speed: float in [1.0, 0.75, 0.5, 0.25]:
		SimClock.set_speed(speed)
		await physics_frames(2)
		check_near(SimClock.speed(), speed, 1.0e-9, "speed %.2f" % speed)
		check_eq(Engine.physics_ticks_per_second, roundi(60.0 * speed), "%d ticks a real second" % roundi(60.0 * speed))
		check_near(sandbox.get_physics_process_delta_time(), SimClock.DT, 1.0e-12, "and each tick is still 1/60 s of game time")
	SimClock.set_speed(0.1)
	check_near(SimClock.speed(), 0.25, 1.0e-9, "never slower than a quarter")
	SimClock.set_speed(1.0)
	check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0, "and back to normal")


func _hunt(speed: float) -> Dictionary:
	SimClock.set_speed(speed)
	await spawn_prey_world(floor_pose(4.0, 6.5, 180.0))
	var f := add_fly("floor_east_open", 7)
	var track: Array[Vector3] = []
	var flies: Array[Vector3] = []
	var frames0 := Engine.get_process_frames()
	var ticks0 := Engine.get_physics_frames()
	await walk_toward(Vector3(4.0, 0.3, 9.5), STALK, 0.4, 240, func() -> void:
		track.append(world.spider.global_position)
		flies.append(f.global_position))
	await strike_at(4.0, 11.0)
	track.append(world.spider.global_position)
	var out := {"track": track, "flies": flies, "outcome": str(world.spider.last_jump.get("outcome", "")),
		"held": director().held == f, "fly_trace": f.trace.size(),
		"frames": Engine.get_process_frames() - frames0, "ticks": Engine.get_physics_frames() - ticks0}
	world.queue_free()
	await physics_frames(2)
	return out


func test_a_hunt_plays_out_the_same_in_slow_motion_only_slower() -> void:
	var full := await _hunt(1.0)
	var half := await _hunt(0.5)
	var a: Array = full["track"]
	var b: Array = half["track"]
	check_eq(b.size(), a.size(), "the same number of ticks to stalk and strike")
	var worst := 0.0
	for i in mini(a.size(), b.size()):
		worst = maxf(worst, (a[i] as Vector3).distance_to(b[i]))
	var fa: Array = full["flies"]
	var fb: Array = half["flies"]
	for i in mini(fa.size(), fb.size()):
		worst = maxf(worst, (fa[i] as Vector3).distance_to(fb[i]))
	check(worst < 1.0e-5, "the spider and the fly are where they were, tick for tick (at most %s WU apart)" % str(worst))
	check_eq(str(half["outcome"]), str(full["outcome"]), "the strike ends the same way (%s)" % str(full["outcome"]))
	check_eq(bool(half["held"]), bool(full["held"]), "and catches, or misses, the same")
	check_eq(int(half["fly_trace"]), int(full["fly_trace"]), "the fly decided the same things")
	var ratio := float(half["frames"]) / maxf(float(full["frames"]), 1.0)
	check(ratio > 1.8 and ratio < 2.2, "at half speed it took about twice as long to watch (%.2f times the frames)" % ratio)


# ------------------------------------------------------------------ the setting, the key, the screen

func test_the_setting_and_its_key_slow_a_played_world_and_the_screen_says_so() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	await physics_frames(2)
	check_near(SimClock.speed(), 1.0, 1.0e-9, "normal speed to begin with")
	settings.set_value("slow_motion", true)
	check_near(SimClock.speed(), 0.5, 1.0e-9, "slow motion: half speed by default")
	settings.set_value("slow_speed", 0.25)
	check_near(SimClock.speed(), 0.25, 1.0e-9, "the chosen speed applies at once")
	var hud: CanvasLayer = world.slow_motion_hud
	hud.refresh()
	var label := hud.get_node("SlowMotion") as Label
	check(label.visible and label.text.contains("SLOW MOTION 25%") and label.text.contains("T / right trigger: normal speed"), "the screen says so: %s" % label.text)
	Input.parse_input_event(_key(KEY_T, true))
	Input.parse_input_event(_key(KEY_T, false))
	await physics_frames(2)
	check(not bool(settings.get_value("slow_motion")) and is_equal_approx(SimClock.speed(), 1.0), "T switches it off (speed %.2f)" % SimClock.speed())
	hud.refresh()
	check(not label.visible, "and the line goes")
	settings.set_value("slow_motion", true)
	world.queue_free()
	await physics_frames(2)
	check_near(SimClock.speed(), 1.0, 1.0e-9, "a world that ends puts the clock back")
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0))   # a test world, not played
	await physics_frames(2)
	check_near(SimClock.speed(), 1.0, 1.0e-9, "a world that is not played never slows the clock")
	settings.set_value("slow_motion", false)


func test_looking_about_is_not_slowed() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	await physics_frames(2)
	var rig: Node3D = world.camera_rig
	var turned := []
	for slow: bool in [false, true]:
		settings.set_value("slow_speed", 0.25)
		settings.set_value("slow_motion", slow)
		Input.action_press("look_right", 1.0)
		for i in 5:   # settle: the first frames depend on where in a frame the press and the switch landed
			await runner.get_tree().process_frame
		var yaw0: float = rig.yaw
		for i in 20:
			await runner.get_tree().process_frame
		turned.append(absf(angle_difference(yaw0, rig.yaw)))
		Input.action_release("look_right")
	settings.set_value("slow_motion", false)
	check(float(turned[0]) > 0.2, "the stick turns the view (%.2f rad in 20 frames)" % float(turned[0]))
	check_near(float(turned[1]), float(turned[0]), float(turned[0]) * 0.03, "and turns it just as fast in slow motion")


func test_the_view_switch_is_easy_to_find_and_works_from_the_keyboard() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	await physics_frames(2)
	var overlay: CanvasLayer = world.eye_overlay
	overlay._process(0.016)
	var hint := overlay.get_node("ViewHint") as Label
	check(hint.visible and hint.text == "V / Y: first person (spider-eye view)", "in third person a line names the switch: %s" % hint.text)
	var screen: Vector2 = overlay.get_viewport().get_visible_rect().size
	check(hint.position.x >= 0.0 and hint.position.x + hint.size.x <= screen.x + 0.5, "on the screen")
	Input.parse_input_event(_key(KEY_V, true))
	Input.parse_input_event(_key(KEY_V, false))
	await physics_frames(2)
	check(world.camera_rig.eye_view, "a real press of V gives first person")
	overlay._process(0.016)
	check(not hint.visible, "the line gives way to the eye view's own")
	check((overlay.get_node("EyeViewTag") as Label).text.contains("V / Y: third person"), "which names the way back")
	Input.parse_input_event(_key(KEY_V, true))
	Input.parse_input_event(_key(KEY_V, false))
	await physics_frames(2)
	check(not world.camera_rig.eye_view, "and V again gives third person")
	# the pause menu's button
	var menu: CanvasLayer = world.pause_menu
	menu.set_paused(true)
	var button := menu.find_child("ViewSwitch", true, false) as Button
	if check(button != null, "the pause menu has a view button"):
		check_eq(button.text, "First person (V / Y)", "it says what it does")
		button.pressed.emit()
		check(world.camera_rig.eye_view, "and does it")
		check_eq(button.text, "Third person (V / Y)", "then offers the way back")
		button.pressed.emit()
		check(not world.camera_rig.eye_view, "which works")
	menu.set_paused(false)
	var slow_check: CheckBox = menu._checks.get("slow_motion")
	check(slow_check != null and slow_check.text.begins_with("Slow motion (T / right trigger)"), "the pause menu has the slow-motion switch")
	check(menu._sliders.has("slow_speed"), "and its speed")
