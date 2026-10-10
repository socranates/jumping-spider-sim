extends "res://tests/world_test_case.gd"
## Input to motion through the real player controller: named actions in, camera-relative
## walking out. Actions are injected with Input.action_press and parse_input_event.

const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "stalk", "look_left", "look_right", "look_up", "look_down"]


func after_each() -> void:
	for a: String in ACTIONS:
		Input.action_release(a)


func _horizontal_speed(spider: Node) -> float:
	return Vector3(spider.velocity.x, 0.0, spider.velocity.z).length()


func _tap_action(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await physics_frames(2)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await physics_frames(2)


func test_move_actions_are_relative_to_the_camera() -> void:
	spawn_world(floor_spawn(-22.0, 12.0, -90.0), true)  # faces +X; the camera looks along +X too
	var spider = world.spider
	await physics_frames(40)
	var start: Vector3 = spider.global_position
	Input.action_press("move_forward")
	await physics_frames(60)
	Input.action_release("move_forward")
	var moved: Vector3 = spider.global_position - start
	check(moved.x > 1.5 and absf(moved.z) < 0.2, "forward walks along the camera direction (+X), moved %s" % str(moved))
	await physics_frames(30)
	start = spider.global_position
	Input.action_press("move_right")
	await physics_frames(60)
	Input.action_release("move_right")
	moved = spider.global_position - start
	check(moved.z > 1.0 and absf(moved.x) < 0.3, "right strafes to the camera's right (+Z), moved %s" % str(moved))
	await physics_frames(30)
	world.camera_rig.yaw += PI / 2.0  # a quarter turn to the left: the camera now looks along -Z
	start = spider.global_position
	Input.action_press("move_forward")
	await physics_frames(60)
	Input.action_release("move_forward")
	moved = spider.global_position - start
	check(moved.z < -1.0 and absf(moved.x) < 0.3, "after turning the camera left, forward is -Z, moved %s" % str(moved))


func test_stick_magnitude_scales_speed() -> void:
	spawn_world(floor_spawn(-22.0, 12.0, -90.0), true)
	var spider = world.spider
	await physics_frames(40)
	Input.action_press("move_forward", 0.6)
	await physics_frames(60)
	var partial := _horizontal_speed(spider)
	Input.action_release("move_forward")
	check(partial > 0.4 and partial < 2.0, "a partly tilted stick walks slower than full, %f" % partial)


func test_stalk_hold_slows_the_spider() -> void:
	spawn_world(floor_spawn(-22.0, 12.0, -90.0), true)
	var spider = world.spider
	await physics_frames(40)
	Input.action_press("move_forward")
	Input.action_press("stalk")
	await physics_frames(60)
	check_near(_horizontal_speed(spider), 0.8, 0.1, "holding stalk walks at 0.8 WU/s")
	check(spider.is_stalking(), "the motor reports stalking")
	Input.action_release("stalk")
	await physics_frames(60)
	check_near(_horizontal_speed(spider), 2.5, 0.15, "releasing stalk returns to walking speed")


func test_stalk_toggle_mode_latches() -> void:
	spawn_world(floor_spawn(-22.0, 12.0, -90.0), true)
	var spider = world.spider
	settings.stalk_toggle = true
	await physics_frames(40)
	Input.action_press("move_forward")
	await _tap_action("stalk")
	await physics_frames(40)
	check_near(_horizontal_speed(spider), 0.8, 0.1, "one press latches stalking")
	await _tap_action("stalk")
	await physics_frames(40)
	check_near(_horizontal_speed(spider), 2.5, 0.15, "a second press releases it")


func test_look_actions_turn_the_camera() -> void:
	spawn_world(floor_spawn(-22.0, 12.0, -90.0), true)
	var rig = world.camera_rig
	await physics_frames(5)
	var yaw0: float = rig.yaw
	Input.action_press("look_right")
	await runner.get_tree().create_timer(0.3).timeout
	Input.action_release("look_right")
	var turned := angle_difference(yaw0, rig.yaw)
	check(turned < -deg_to_rad(10.0), "look_right turns the camera right, turned %f rad" % turned)
	var elev0: float = rig.elevation
	Input.action_press("look_down")
	await runner.get_tree().create_timer(0.3).timeout
	Input.action_release("look_down")
	check(rig.elevation > elev0 + deg_to_rad(10.0), "look_down raises the camera, delta %f rad" % (rig.elevation - elev0))


func test_debug_overlay_is_off_by_default_and_toggles_with_f3() -> void:
	spawn_world(null, true)
	var overlay: CanvasLayer = world.overlay
	await physics_frames(5)
	check(not overlay.visible, "hidden by default")
	await _tap_action("debug_overlay")
	await process_frames(2)
	check(overlay.visible, "the debug_overlay action shows it")
	var text: String = overlay._label.text
	for needle in ["FPS", "State ATTACHED", "Position", "Velocity", "Supported yes", "Support floor (painted_wood_dry)", "Normal (0.00, 1.00, 0.00)", "Camera boom", "Godot 4.7"]:
		check(needle in text, "overlay shows '%s'" % needle)
	await _tap_action("debug_overlay")
	await process_frames(1)
	check(not overlay.visible, "and hides it again")
