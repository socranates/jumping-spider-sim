extends "res://tests/prey_test_case.gd"
## T10a, the spider-eye view (Nathan, 2026-10-11: "a first person spider eye mode so its more immersive"; "scientific realism in terms
## of vision and movement"):
##   * it switches on and off (setting, V / Y, the pause menu), survives a restart, and the orbit camera comes back behind the spider;
##   * the camera is at the principal eyes, the head is hidden and the legs are not, and the aim ray is the eyes' line of sight;
##   * walking goes where the eyes look; over an edge onto a wall the view is carried with the body and never turns suddenly;
##   * the principal eyes' retinas point the inspection without turning the body, within their reach; beyond it, standing still, the
##     body turns to face the gaze; the head tilts toward where the eyes look;
##   * the picture: sharp window, fading out of reach, words that say it is an impression and name the player's keys, all on screen.

const KeyNames = preload("res://scripts/presentation/key_names.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const TEMP_PATH := "user://jss_test_t10a_settings.cfg"


func after_each() -> void:
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
	super.after_each()


func _rig() -> Node3D:
	return world.camera_rig


func _turn_gaze(deg_right: float, deg_down: float = 0.0) -> void:
	_rig().look(deg_right / float(settings.look_sensitivity), deg_down / float(settings.look_sensitivity))


func _head_meshes_visible() -> int:
	var n := 0
	for c in world.spider.get_node("Body").get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).visible:
			n += 1
	return n


# ------------------------------------------------------------------ on and off

func test_the_eye_view_switches_on_and_off_and_survives_a_restart() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0))
	await physics_frames(3)
	var rig := _rig()
	var meshes := _head_meshes_visible()
	check(not rig.eye_view and rig.boom_length > 1.0, "the orbit camera by default (boom %.2f WU)" % rig.boom_length)
	settings.set_value("eye_view", true)
	await physics_frames(2)
	check(rig.eye_view, "the setting turns the eye view on")
	check_near(float(rig.camera.fov), rig.EYE_FOV_DEG, 1.0e-6, "with its own wide field of view")
	var eye: Vector3 = world.spider.get_eye_position(true)
	var cam: Vector3 = rig.camera.global_position
	var heading: Vector3 = world.spider.get_heading_vector()
	check(cam.distance_to(eye) < 0.45 and (cam - world.spider.global_position).dot(heading) > 0.4, "the camera is at the front eyes (%.2f WU from the sensing eye)" % cam.distance_to(eye))
	check(rig.gaze.angle_to(heading) < deg_to_rad(1.0), "looking where the spider looks")
	check_eq(_head_meshes_visible(), 0, "the head, abdomen, eyes and fangs are hidden")
	check((world.spider.get_node("Body/Legs") as Node3D).is_visible_in_tree(), "the legs are not")
	var ray: Dictionary = rig.get_aim_ray()
	check((ray["origin"] as Vector3).distance_to(cam) < 1.0e-4 and (ray["direction"] as Vector3).angle_to(rig.gaze) < 1.0e-3, "the aim is the eyes' line of sight")
	settings.set_value("eye_view", false)
	await physics_frames(3)
	check(not rig.eye_view and rig.boom_length > 1.0, "off again: the orbit camera is back (boom %.2f WU)" % rig.boom_length)
	check_eq(_head_meshes_visible(), meshes, "and the whole spider is drawn")
	check_near(float(rig.camera.fov), float(settings.fov_degrees), 1.0e-6, "at the player's field of view")
	# the key, and a restart
	var v := InputEventKey.new()
	v.physical_keycode = KEY_V
	v.pressed = true
	rig._unhandled_input(v)
	check(bool(settings.get_value("eye_view")) and rig.eye_view, "V switches it on")
	var saved: Node = SettingsScript.new()
	saved.config_path = TEMP_PATH
	saved.set_value("eye_view", true)
	var again: Node = SettingsScript.new()
	again.config_path = TEMP_PATH
	check(again.load_settings() and bool(again.get_value("eye_view")), "the choice survives a restart")
	saved.free()
	again.free()


func test_a_world_started_with_the_setting_on_starts_in_the_eye_view() -> void:
	settings.set_value("eye_view", true)
	await spawn_prey_world(floor_pose(0.0, 6.0, 90.0))
	await physics_frames(3)
	check(_rig().eye_view, "the eye view from the first frame")
	check(_rig().gaze.angle_to(world.spider.get_heading_vector()) < deg_to_rad(1.0), "looking along the spider's heading")


# ------------------------------------------------------------------ walking and edges

func test_walking_goes_where_the_eyes_look() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	settings.set_value("eye_view", true)
	await physics_frames(3)
	var rig := _rig()
	var n := Vector3.UP
	var ahead: Vector3 = rig.map_stick(Vector2(0.0, 1.0), n)
	check(ahead.angle_to(rig.gaze) < deg_to_rad(1.0), "forward is the gaze")
	_turn_gaze(90.0, 20.0)
	var forward: Vector3 = rig.map_stick(Vector2(0.0, 1.0), n)
	var g: Vector3 = rig.gaze
	var flat: Vector3 = (g - n * g.dot(n)).normalized()
	check(forward.angle_to(flat) < deg_to_rad(1.0) and absf(forward.dot(n)) < 1.0e-4, "looking right and down, forward is the gaze laid on the floor")
	check(rig.map_stick(Vector2(1.0, 0.0), n).angle_to(flat.cross(n)) < deg_to_rad(1.0), "and right is the view's right")
	var start: Vector3 = world.spider.global_position
	world.controller.stick_override = Vector2(0.0, -1.0)   # Input.get_vector convention: y negative is forward
	await physics_frames(60)
	world.controller.stick_override = null
	var moved: Vector3 = world.spider.global_position - start
	moved.y = 0.0
	check(moved.length() > 0.5 and moved.normalized().angle_to(flat) < deg_to_rad(12.0), "the spider walked where it looked (%.1f WU, %.0f degrees off)" % [moved.length(), rad_to_deg(moved.normalized().angle_to(flat))])


func test_over_an_edge_the_view_is_carried_with_the_body_and_never_turns_suddenly() -> void:
	await spawn_prey_world(floor_pose(0.0, 14.0, 180.0), 0, PREY_SEED, true)   # facing +Z, the south wall ahead
	settings.set_value("eye_view", true)
	await physics_frames(3)
	var rig := _rig()
	var worst := [0.0, 0.0]   # largest turn of the camera's up in one frame (degrees), largest gaze elevation off the surface
	var last_up := [rig.camera.global_transform.basis.y]
	world.controller.stick_override = Vector2(0.0, -1.0)
	for i in 300:
		await physics_frames(1)
		var up: Vector3 = rig.camera.global_transform.basis.y
		worst[0] = maxf(float(worst[0]), rad_to_deg(up.angle_to(last_up[0] as Vector3)))
		last_up[0] = up
	world.controller.stick_override = null
	await physics_frames(30)
	var body_up: Vector3 = world.spider.get_visual_up()
	worst[1] = rad_to_deg(absf(asin(clampf(rig.gaze.dot(body_up), -1.0, 1.0))))
	var on_wall: bool = world.spider.get_support_normal().dot(Vector3.UP) < 0.3
	check(on_wall, "the spider climbed onto the wall (normal %s)" % str(world.spider.get_support_normal()))
	check(rig.gaze.dot(Vector3.UP) > 0.8, "and the view went up the wall with it (gaze %s)" % str(rig.gaze))
	check(float(worst[1]) < 5.0, "the gaze ends along the wall, as the eyes do (%.1f degrees off it)" % float(worst[1]))
	check(float(worst[0]) <= rig.EYE_ROLL_DEG_S / 60.0 + 0.1, "the view never turned suddenly (at most %.1f degrees in a frame)" % float(worst[0]))


# ------------------------------------------------------------------ the principal eyes

func test_the_retinas_point_the_inspection_without_turning_within_their_reach() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	settings.set_value("eye_view", true)
	await physics_frames(3)
	var rig := _rig()
	var spider: Node3D = world.spider
	var heading0: Vector3 = spider.get_heading_vector()
	_turn_gaze(20.0)
	await physics_frames(30)
	check(spider.get_heading_vector().angle_to(heading0) < deg_to_rad(0.5), "20 degrees aside: the body did not turn")
	check(not world.controller.is_eye_turning(), "nor began to")
	check((spider.get_gaze_direction() as Vector3).angle_to(rig.gaze) < deg_to_rad(1.0), "the inspection points where the eyes look")
	check(world.sensor.last_axis.angle_to(rig.gaze) < deg_to_rad(1.0), "and the senses used it")
	check_near(rig.principal_offset_deg(), 20.0, 1.0, "the gaze is 20 degrees off the body's own")
	# out of reach
	_turn_gaze(50.0)
	await physics_frames(2)
	check(world.controller.is_eye_turning(), "70 degrees aside, standing still: the body turns to face it")
	var away: float = rad_to_deg((spider.get_gaze_direction() as Vector3).angle_to(spider.get_body_gaze_direction()))
	check(away <= spider.PRINCIPAL_SCAN_DEG + 0.5, "meanwhile the retinas point no further than they can (%.1f degrees)" % away)
	await wait_until(func() -> bool: return not world.controller.is_eye_turning(), 120)
	var g: Vector3 = rig.gaze
	var flat: Vector3 = (g - Vector3.UP * g.dot(Vector3.UP)).normalized()
	check(spider.get_heading_vector().angle_to(flat) < deg_to_rad(world.controller.EYE_SETTLE_DEG + 0.5), "it turned to face the gaze, then stopped")
	check(rig.gaze.angle_to(flat) < deg_to_rad(0.5), "the view did not move while the body turned under it")


func test_walking_never_fights_the_turn_and_the_head_tilts_toward_the_gaze() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	settings.set_value("eye_view", true)
	await physics_frames(3)
	var spider: Node3D = world.spider
	_turn_gaze(80.0)
	world.controller.stick_override = Vector2(-1.0, 0.0)   # sidestep left while looking far right
	await physics_frames(10)
	check(not world.controller.is_eye_turning(), "while walking the body is not turned to the gaze")
	world.controller.stick_override = null
	_turn_gaze(-80.0, 45.0)   # back ahead, and down at the floor
	await physics_frames(60)
	var pitch := rad_to_deg(float(spider.get_gaze_pitch()))
	check(pitch < -20.0, "the head tilted down toward where the eyes look (%.0f degrees)" % pitch)
	check(_rig().principal_offset_deg() <= spider.PRINCIPAL_SCAN_DEG, "so the floor ahead is within the principal eyes' reach (%.0f degrees)" % _rig().principal_offset_deg())
	settings.set_value("eye_view", false)
	await physics_frames(2)
	check(spider.get_scan_direction() == Vector3.ZERO, "off: the retinas are centred again")


# ------------------------------------------------------------------ the picture and the words

func test_the_picture_is_sharp_where_the_eyes_reach_and_says_it_is_an_impression() -> void:
	await spawn_prey_world(floor_pose(0.0, 6.0, 0.0), 0, PREY_SEED, true)
	var overlay: CanvasLayer = world.eye_overlay
	await physics_frames(2)
	check(not (overlay.get_node("EyeView") as Control).visible, "nothing is drawn in the orbit view")
	settings.set_key("eye_view", KEY_G)
	settings.set_value("eye_view", true)
	await physics_frames(3)
	overlay._process(0.016)
	check((overlay.get_node("EyeView") as Control).visible, "the eye picture is drawn in the eye view")
	check(overlay.layer < 4, "under every HUD, so words and markers stay sharp")
	var tag := overlay.get_node("EyeViewTag") as Label
	check(tag.text.contains("an impression") and tag.text.contains("G / Y: switch back"), "the view says it is an impression and names the key: %s" % tag.text)
	var notice := overlay.get_node("EyeViewNotice") as Label
	check(notice.visible and notice.text.contains("no red"), "and briefly what it shows")
	var screen: Vector2 = overlay.get_viewport().get_visible_rect().size
	for l: Label in [tag, notice]:
		check(l.position.x >= 0.0 and l.position.x + l.size.x <= screen.x + 0.5, "%s stays on the screen" % l.name)
	check_near(overlay.target_principal(), 1.0, 1.0e-6, "looking ahead, the sharp window is drawn")
	_turn_gaze(60.0)
	await physics_frames(1)   # the body starts to turn at 3 degrees a tick: still far out of reach
	check(overlay.target_principal() < 0.01, "out of the principal eyes' reach it fades out")
	overlay.principal = 0.0
	overlay.refresh()
	check(tag.text.contains("stand still and the spider turns to look"), "and the words say why: %s" % tag.text)
	settings.reset_keys()


func test_the_pause_menu_and_the_field_notes_offer_the_eye_view() -> void:
	var menu := PauseMenu.new()
	menu.settings = settings
	sandbox.add_child(menu)
	var check_box: CheckBox = menu._checks.get("eye_view")
	check(check_box != null and check_box.text.begins_with("Spider-eye view (first person, V / Y)"), "a pause-menu switch")
	check_box.button_pressed = true
	check(bool(settings.get_value("eye_view")), "which sets it")
	menu.free()
	settings.set_value("eye_view", false)
	use_windowsill = true
	await spawn_prey_world(floor_pose(-25, 6, -90))
	world.habitat_loop.toggle_help()
	check(world.habitat_loop.caption().contains("V / Y: spider-eye view"), "the field notes name it")
