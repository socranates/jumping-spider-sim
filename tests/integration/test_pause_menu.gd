extends "res://tests/test_case.gd"
## The pause panel is built in code. The mouse mode is not asserted: a headless run has no
## mouse to capture, so that part is only checked by hand.

const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const SettingsScript = preload("res://scripts/presentation/settings.gd")
const TEMP_PATH := "user://jss_test_pause_settings.cfg"

var _settings: Node


func before_each() -> void:
	_settings = SettingsScript.new()
	_settings.config_path = TEMP_PATH
	_settings.autosave = true


func after_each() -> void:
	runner.get_tree().paused = false
	_settings.free()
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func _menu() -> CanvasLayer:
	var menu := PauseMenu.new()
	menu.settings = _settings
	sandbox.add_child(menu)
	return menu


func test_pause_toggles_the_tree_and_shows_the_panel() -> void:
	var menu := _menu()
	var tree := runner.get_tree()
	check(not tree.paused and not menu.visible, "starts unpaused with the panel hidden")
	check_eq(menu.process_mode, Node.PROCESS_MODE_ALWAYS, "the panel keeps running while paused")
	menu.set_paused(true)
	check(tree.paused and menu.visible, "paused with the panel shown")
	menu.set_paused(false)
	check(not tree.paused and not menu.visible, "resumed with the panel hidden")


func test_the_pause_action_toggles_pause() -> void:
	var menu := _menu()
	var tree := runner.get_tree()
	var press := InputEventAction.new()
	press.action = "pause"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frames(2)
	check(tree.paused and menu.visible, "the pause action pauses")
	Input.parse_input_event(press)
	await process_frames(2)
	check(not tree.paused and not menu.visible, "the pause action resumes")


func test_panel_controls_write_through_to_saved_settings() -> void:
	var menu := _menu()
	menu.set_paused(true)
	menu._sliders["fov_degrees"].value = 80.0
	menu._sliders["camera_distance"].value = 6.0
	menu._sliders["look_sensitivity"].value = 1.5
	menu._checks["invert_x"].button_pressed = true
	menu._checks["invert_y"].button_pressed = true
	menu._checks["stalk_toggle"].button_pressed = true
	menu._checks["prepare_toggle"].button_pressed = true
	menu._checks["focus_toggle"].button_pressed = true
	menu._checks["detailed_arc"].button_pressed = true
	menu._sliders["jump_reach"].value = 1.5
	menu._checks["release_hold"].button_pressed = false
	menu._checks["frame_line_after_catch"].button_pressed = false
	menu._checks["show_last_seen"].button_pressed = false
	menu._checks["show_gaze"].button_pressed = true
	check_near(_settings.fov_degrees, 80.0, 1e-6, "fov slider")
	check_near(_settings.camera_distance, 6.0, 0.051, "distance slider")
	check_near(_settings.look_sensitivity, 1.5, 0.051, "sensitivity slider")
	check(_settings.invert_x and _settings.invert_y and _settings.stalk_toggle, "check boxes")
	check(_settings.prepare_toggle and _settings.detailed_arc, "the jump options")
	check_eq(_settings.focus_toggle, true, "the Focus toggle switch (A-026)")
	check_eq(menu._checks["focus_toggle"].text, "Focus toggles (press to start and stop): on", "labelled in words, with its state")
	check_near(_settings.jump_reach, 1.5, 1e-6, "jump reach slider")
	check_eq((menu._value_labels["jump_reach"] as Label).text, "150%", "jump reach is shown in percent")
	check_eq(_settings.release_hold, false, "the hold-to-let-go option")
	check_eq(_settings.frame_line_after_catch, false, "the line framing switch (chunk 6B)")
	check_eq(_settings.show_last_seen, false, "the last-seen mark switch")
	check_eq(_settings.show_gaze, true, "the gaze footprint switch")
	check_eq(menu._checks["frame_line_after_catch"].text, "Frame the line after a catch: off", "the switch is labelled in words, with its state")
	var saved := ConfigFile.new()
	check_eq(saved.load(TEMP_PATH), OK, "the change was saved to disk")
	check_near(float(saved.get_value(SettingsScript.SECTION, "fov_degrees", 0.0)), 80.0, 1e-6, "saved fov")
	check_eq(saved.get_value(SettingsScript.SECTION, "stalk_toggle", false), true, "saved stalk toggle")
	check_eq(saved.get_value(SettingsScript.SECTION, "focus_toggle", false), true, "saved Focus toggle")
	check_near(float(saved.get_value(SettingsScript.SECTION, "jump_reach", 0.0)), 1.5, 1e-6, "saved jump reach")
	_settings.fov_degrees = 70.0
	menu.set_paused(false)
	menu.set_paused(true)
	check_near(menu._sliders["fov_degrees"].value, 70.0, 1e-6, "the panel shows the current settings when reopened")
