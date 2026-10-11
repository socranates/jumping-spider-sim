extends "res://tests/prey_test_case.gd"
## T13a, comfort in the spider-eye view (ROADMAP step 5):
##   * "eye_level_horizon": on a wall the view keeps the world's up instead of rolling with the body; looking straight up the wall, where
##     the world's up says nothing about roll, it holds steady; the mouse and stick then turn the picture the way it looks on screen;
##     aiming and walking still follow the gaze;
##   * "eye_colour_free": the same green-weighted brightness, shown grey, and the label says so;
##   * both are in the pause menu and off by default.

const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")


func after_each() -> void:
	settings.set_value("eye_level_horizon", false)
	settings.set_value("eye_colour_free", false)
	super.after_each()


func _climb_the_south_wall() -> bool:
	await spawn_prey_world(floor_pose(0.0, 14.0, 180.0), 0, PREY_SEED, true)   # facing +Z, the south wall ahead (as test_t10a)
	settings.set_value("eye_view", true)
	await physics_frames(3)
	world.controller.stick_override = Vector2(0.0, -1.0)
	await physics_frames(300)
	world.controller.stick_override = null
	await physics_frames(30)
	return world.spider.get_support_normal().dot(Vector3.UP) < 0.3


func _along_the_wall_sideways() -> Vector3:
	var n: Vector3 = world.spider.get_support_normal()
	return n.cross(Vector3.UP).normalized()


func test_off_by_default_and_in_the_pause_menu() -> void:
	check(not bool(settings.DEFAULTS["eye_level_horizon"]) and not bool(settings.DEFAULTS["eye_colour_free"]), "both off by default")
	var menu := PauseMenu.new()
	menu.settings = settings
	sandbox.add_child(menu)
	var level: CheckBox = menu._checks.get("eye_level_horizon")
	var grey: CheckBox = menu._checks.get("eye_colour_free")
	check(level != null and level.text.contains("level horizon"), "a pause-menu switch for the level horizon")
	check(grey != null and grey.text.contains("grey"), "and one for the grey picture")
	level.button_pressed = true
	grey.button_pressed = true
	check(bool(settings.get_value("eye_level_horizon")) and bool(settings.get_value("eye_colour_free")), "which set them")
	menu.free()


func test_on_a_wall_the_level_horizon_keeps_the_world_up() -> void:
	if not check(await _climb_the_south_wall(), "the spider climbed onto the wall"):
		return
	var rig: Node3D = world.camera_rig
	var side := _along_the_wall_sideways()
	rig.gaze = side
	rig._place_eye(1.0)
	var body_up: Vector3 = rig._gaze_up
	check(rig.camera.global_transform.basis.y.angle_to(body_up) < deg_to_rad(5.0), "normally, looking along the wall, the view rolls with the body")
	settings.set_value("eye_level_horizon", true)
	rig._place_eye(1.0)
	var cam_up: Vector3 = rig.camera.global_transform.basis.y
	check(cam_up.angle_to(Vector3.UP) < deg_to_rad(3.0), "with a level horizon it keeps the world's up (%.1f degrees off)" % rad_to_deg(cam_up.angle_to(Vector3.UP)))
	check((-rig.camera.global_transform.basis.z).angle_to(side) < deg_to_rad(1.0), "and still looks where the eyes look")
	var ray: Dictionary = rig.get_aim_ray()
	check((ray["direction"] as Vector3).angle_to(rig.gaze) < deg_to_rad(1.0), "the aim follows the gaze as before")
	# Turning with the mouse or stick now moves the picture the way it looks on screen: sideways about the world's up.
	var before: Vector3 = rig.gaze
	rig._look_eye(deg_to_rad(10.0), 0.0)
	check_near(rig.gaze.dot(Vector3.UP), before.dot(Vector3.UP), 0.02, "a sideways turn stays level")
	check(rig.gaze.angle_to(before) > deg_to_rad(8.0), "and turns (%.1f degrees)" % rad_to_deg(rig.gaze.angle_to(before)))


func test_looking_straight_up_the_wall_the_level_view_holds_steady() -> void:
	settings.set_value("eye_level_horizon", true)
	await spawn_prey_world(floor_pose(0.0, 14.0, 180.0), 0, PREY_SEED, true)
	settings.set_value("eye_view", true)
	await physics_frames(3)
	var rig: Node3D = world.camera_rig
	var worst := [0.0]
	var last := [rig.camera.global_transform.basis.y]
	world.controller.stick_override = Vector2(0.0, -1.0)
	for i in 300:
		await physics_frames(1)
		var up: Vector3 = rig.camera.global_transform.basis.y
		worst[0] = maxf(float(worst[0]), rad_to_deg(up.angle_to(last[0] as Vector3)))
		last[0] = up
	world.controller.stick_override = null
	check(world.spider.get_support_normal().dot(Vector3.UP) < 0.3, "the spider climbed onto the wall")
	check(rig.gaze.dot(Vector3.UP) > 0.8, "and looks up it")
	check(float(worst[0]) < 12.0, "the level view never flipped on the way (largest change %.1f degrees in a tick)" % float(worst[0]))


func test_the_grey_picture_keeps_the_brightness_and_says_so() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	settings.set_value("eye_view", true)
	await physics_frames(3)
	var eye: CanvasLayer = world.eye_overlay
	var tag: Label = eye.get_node("EyeViewTag")
	var mat: ShaderMaterial = (eye.get_node("EyeView") as ColorRect).material
	eye._process(0.0)
	check(not bool(mat.get_shader_parameter("colour_free")), "green-tinted by default")
	settings.set_value("eye_colour_free", true)
	eye._process(0.0)
	check(bool(mat.get_shader_parameter("colour_free")), "the grey picture is on")
	check(tag.text.contains("shown grey") and tag.text.contains("UV not simulated"), "the label says it is grey and still that UV is not simulated")
