extends "res://tests/prey_test_case.gd"
## T09, the parts of U01 (spec 25) that a test can show: remapped keys drive the real actions and survive a restart; the text size setting
## survives a restart and scales the panels; every action of the loop and the field notes can be reached from a controller; the pause
## menu's key list changes a key, swaps a key in use, refuses the pause key and is reset; the windowsill's words follow remapped keys.
## The formal U01 (completing the loop with a controller only, with remapped keys, toggle preparation and sound muted) is a human
## playtest and is not claimed here.

const InputSetupScript = preload("res://scripts/core/input_setup.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const TEMP_PATH := "user://jss_test_u01_settings.cfg"

var _made: Array[Node] = []


func after_each() -> void:
	var setup: Node = InputSetupScript.new()
	setup.register_actions()  # the default bindings for every later test
	setup.free()
	for n in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
	super.after_each()


func _fresh_settings() -> Node:
	var s: Node = SettingsScript.new()
	s.config_path = TEMP_PATH
	s.autosave = true
	s.load_settings()
	_made.append(s)
	return s


func _has_key(action: String, code: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == code:
			return true
	return false


func _has_pad(action: String) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			return true
	return false


func test_a_remapped_key_drives_the_action_and_survives_a_restart() -> void:
	var s := _fresh_settings()
	var r: Dictionary = s.set_key("interact", KEY_F)
	check(bool(r["ok"]), "interact takes F: %s" % r["message"])
	var setup: Node = InputSetupScript.new()
	setup.register_actions(s.get_binding_overrides())
	setup.free()
	check(_has_key("interact", KEY_F) and not _has_key("interact", KEY_E), "interact answers F, not E")
	check(_has_pad("interact"), "the controller button still works")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F
	ev.pressed = true
	check(ev.is_action_pressed("interact"), "a press of F is the interact action")
	# a restart: a new Settings reads the file
	var again := _fresh_settings()
	check_eq(again.get_key("interact"), KEY_F, "the key survives a restart")
	check_eq(again.get_key("cancel"), KEY_Q, "the others keep their defaults")


func test_walk_forward_carries_reel_with_it_and_a_used_key_is_swapped() -> void:
	var s := _fresh_settings()
	s.set_key("move_forward", KEY_I)
	var setup: Node = InputSetupScript.new()
	setup.register_actions(s.get_binding_overrides())
	check(_has_key("move_forward", KEY_I) and _has_key("reel", KEY_I), "reeling in follows walking forward (spec 17: W with a context override)")
	var r: Dictionary = s.set_key("interact", KEY_Q)
	check_eq(str(r["swapped"]), "cancel", "Q was cancel's: the two are swapped")
	check_eq(s.get_key("cancel"), KEY_E, "cancel now has interact's old key")
	check(str(r["message"]).contains("Cancel / let go now uses E"), "and the menu says so: %s" % r["message"])
	check(not bool(s.set_key("interact", KEY_ESCAPE)["ok"]), "Esc stays the way out of every menu")
	check(not bool(s.set_key("pause", KEY_P)["ok"]), "pause itself is not remapped")
	s.reset_keys()
	setup.register_actions(s.get_binding_overrides())
	setup.free()
	check(_has_key("interact", KEY_E) and _has_key("cancel", KEY_Q) and _has_key("move_forward", KEY_W) and _has_key("reel", KEY_W), "reset brings every default back")
	check_eq(_fresh_settings().get_key("interact"), KEY_E, "and the reset is saved")


func test_text_size_survives_a_restart_and_is_bounded() -> void:
	var s := _fresh_settings()
	check_eq(float(s.get_value("ui_scale")), 1.0, "normal size by default")
	s.set_value("ui_scale", 1.3)
	check_near(float(_fresh_settings().get_value("ui_scale")), 1.3, 1.0e-6, "the size survives a restart")
	s.set_value("ui_scale", 9.0)
	check_near(float(s.get_value("ui_scale")), 1.5, 1.0e-6, "and stays within its limits")


func test_every_action_of_the_loop_and_the_field_notes_have_a_controller_input() -> void:
	var setup: Node = InputSetupScript.new()
	setup.register_actions()
	setup.free()
	for action: String in InputSetupScript.GAME_ACTIONS + ["help"]:
		check(_has_pad(action), "%s can be done from a controller" % action)
	use_windowsill = true
	await spawn_prey_world(floor_pose(-25, 6, -90))
	var loop: Node = world.habitat_loop
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_BACK
	back.pressed = true
	loop._unhandled_input(back)
	check(loop.help_shown(), "the controller's View / Back button opens the field notes")
	check(loop.caption().contains("Return to checkpoint"), "the notes say how to get back to a checkpoint")
	loop._unhandled_input(back)
	check(not loop.help_shown(), "and closes them")


func test_the_windowsill_names_the_keys_the_player_chose() -> void:
	settings.set_key("interact", KEY_F)
	use_windowsill = true
	await spawn_prey_world(floor_pose(-25, 6, -90))
	check(world.habitat_loop.caption().contains("F / X to rest"), "the rest prompt names F: %s" % world.habitat_loop.caption())
	settings.reset_keys()


func test_the_pause_menu_remaps_a_key_and_fits_larger_text() -> void:
	var s := _fresh_settings()
	var menu := PauseMenu.new()
	menu.settings = s
	sandbox.add_child(menu)
	menu.set_paused(true)
	var toggle := menu.find_child("KeysToggle", true, false) as Button
	var key_button := menu.find_child("Key_stalk", true, false) as Button
	if not check(toggle != null and key_button != null, "the key list is in the menu"):
		menu.set_paused(false)
		return
	toggle.pressed.emit()
	check((menu.find_child("Keys", true, false) as Control).visible, "it opens")
	check_eq(key_button.text, "Shift", "stalk shows its key")
	key_button.pressed.emit()
	check_eq(key_button.text, "press a key", "the button waits for a key")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	menu._input(esc)
	check(runner.get_tree().paused, "Esc while choosing a key stops choosing, and does not close the menu")
	check_eq(s.get_key("stalk"), KEY_SHIFT, "nothing changed")
	key_button.pressed.emit()
	var c := InputEventKey.new()
	c.physical_keycode = KEY_C
	c.pressed = true
	menu._input(c)
	check_eq(s.get_key("stalk"), KEY_C, "stalk is now C")
	check_eq(key_button.text, "C", "and the button says so")
	(menu.find_child("ResetKeys", true, false) as Button).pressed.emit()
	check_eq(s.get_key("stalk"), KEY_SHIFT, "reset")
	# the panel never grows past the window
	s.set_value("ui_scale", 1.5)
	menu._fit_to_screen()
	var scroll := menu._scroll as ScrollContainer
	check(scroll.custom_minimum_size.y <= menu.get_viewport().get_visible_rect().size.y, "the panel fits the window and scrolls")
	menu.set_paused(false)
