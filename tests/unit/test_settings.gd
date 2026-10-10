extends "res://tests/test_case.gd"

const SettingsScript = preload("res://scripts/presentation/settings.gd")
const TEMP_PATH := "user://jss_test_settings.cfg"

var _made: Array[Node] = []


func before_each() -> void:
	_remove_temp()


func after_each() -> void:
	for n in _made:
		n.free()
	_made.clear()
	_remove_temp()


func _remove_temp() -> void:
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func _settings(path: String = TEMP_PATH, autosave: bool = true) -> Node:
	var s: Node = SettingsScript.new()
	s.config_path = path
	s.autosave = autosave
	_made.append(s)
	return s


func _write_text(text: String) -> void:
	var f := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_defaults() -> void:
	var s := _settings()
	check_near(s.look_sensitivity, 1.0, 1e-6, "look sensitivity default")
	check_near(s.fov_degrees, 65.0, 1e-6, "vertical FOV default")
	check_near(s.camera_distance, 5.0, 1e-6, "camera distance default")
	check_eq(s.invert_x, false, "invert x default")
	check_eq(s.invert_y, false, "invert y default")
	check_eq(s.stalk_toggle, false, "stalk toggle default")
	check_eq(s.prepare_toggle, false, "hold-to-aim is the default; toggle aim is an accessibility option")
	check_eq(s.focus_toggle, false, "hold-to-focus is the default; toggled Focus is an accessibility option (A-026)")
	check_eq(s.detailed_arc, false, "the detailed jump arc is off by default")
	check_near(s.jump_reach, 1.0, 1e-6, "jump reach is the species profile's by default (100%)")
	check_eq(s.release_hold, true, "letting go of the line needs a hold by default")
	check_eq(s.frame_line_after_catch, true, "the camera frames the line after a catch by default (chunk 6B)")
	check_eq(s.show_last_seen, true, "the last-seen mark is shown by default (A-002)")
	check_eq(s.show_gaze, false, "the gaze footprint is off by default (A-003)")


func test_round_trip_through_a_temp_file() -> void:
	var a := _settings()
	a.look_sensitivity = 1.75
	a.invert_x = true
	a.invert_y = true
	a.fov_degrees = 80.0
	a.camera_distance = 6.5
	a.stalk_toggle = true
	a.prepare_toggle = true
	a.focus_toggle = true
	a.detailed_arc = true
	check(FileAccess.file_exists(TEMP_PATH), "a change writes the file")
	var b := _settings()
	check(b.load_settings(), "the saved file loads")
	check_near(b.look_sensitivity, 1.75, 1e-6, "look sensitivity round trip")
	check_eq(b.invert_x, true, "invert x round trip")
	check_eq(b.invert_y, true, "invert y round trip")
	check_near(b.fov_degrees, 80.0, 1e-6, "fov round trip")
	check_near(b.camera_distance, 6.5, 1e-6, "distance round trip")
	check_eq(b.stalk_toggle, true, "stalk toggle round trip")
	check_eq(b.prepare_toggle, true, "prepare toggle round trip")
	check_eq(b.focus_toggle, true, "focus toggle round trip")
	check_eq(b.detailed_arc, true, "detailed arc round trip")


func test_every_change_is_saved() -> void:
	var a := _settings()
	a.fov_degrees = 70.0
	var first := ConfigFile.new()
	first.load(TEMP_PATH)
	check_near(float(first.get_value(SettingsScript.SECTION, "fov_degrees", 0.0)), 70.0, 1e-6, "first change on disk")
	a.fov_degrees = 72.0
	var second := ConfigFile.new()
	second.load(TEMP_PATH)
	check_near(float(second.get_value(SettingsScript.SECTION, "fov_degrees", 0.0)), 72.0, 1e-6, "second change on disk")


func test_missing_file_falls_back_to_defaults() -> void:
	var s := _settings()
	check(not s.load_settings(), "no file means load_settings returns false")
	check_near(s.fov_degrees, 65.0, 1e-6, "fov default after missing file")
	check_near(s.camera_distance, 5.0, 1e-6, "distance default after missing file")


func test_corrupt_file_falls_back_to_defaults() -> void:
	allow_errors(4)  # the ConfigFile parser reports the corrupt file itself
	_write_text("this is { not [ a config file\n=== ???")
	var s := _settings(TEMP_PATH, false)
	s.fov_degrees = 80.0  # prove loading replaces a changed value
	check(not s.load_settings(), "a corrupt file means load_settings returns false")
	check_near(s.fov_degrees, 65.0, 1e-6, "fov falls back to the default")
	check_eq(s.invert_x, false, "invert x falls back to the default")


func test_invalid_saved_values_fall_back_or_clamp() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SettingsScript.SECTION, "fov_degrees", "wide")
	cfg.set_value(SettingsScript.SECTION, "camera_distance", 99.0)
	cfg.set_value(SettingsScript.SECTION, "look_sensitivity", NAN)
	cfg.set_value(SettingsScript.SECTION, "invert_x", 5)
	cfg.set_value(SettingsScript.SECTION, "invert_y", true)
	cfg.save(TEMP_PATH)
	var s := _settings()
	check(s.load_settings(), "the file loads")
	check_near(s.fov_degrees, 65.0, 1e-6, "wrong type falls back to the default")
	check_near(s.camera_distance, 7.0, 1e-6, "out-of-range value is clamped")
	check_near(s.look_sensitivity, 1.0, 1e-6, "non-finite value falls back to the default")
	check_eq(s.invert_x, false, "wrong type for a bool falls back to the default")
	check_eq(s.invert_y, true, "a valid value is kept")


func test_setters_clamp_notify_and_reject_bad_types() -> void:
	allow_errors(1)  # set_value reports the rejected value
	var s := _settings(TEMP_PATH, false)
	var seen: Array[String] = []
	s.setting_changed.connect(func(key: String) -> void: seen.append(key))
	s.fov_degrees = 500.0
	check_near(s.fov_degrees, 90.0, 1e-6, "fov clamps to its maximum")
	s.camera_distance = 1.0
	check_near(s.camera_distance, 4.0, 1e-6, "distance clamps to its minimum")
	check(not s.set_value("fov_degrees", "wide"), "a string is rejected")
	check_near(s.fov_degrees, 90.0, 1e-6, "a rejected value changes nothing")
	check_eq(seen, ["fov_degrees", "camera_distance"] as Array[String], "one signal per accepted change")
	check(not FileAccess.file_exists(TEMP_PATH), "autosave off writes nothing")
	s.jump_reach = 3.0
	check_near(s.jump_reach, 1.5, 1e-6, "jump reach clamps to 150%")
	s.jump_reach = 0.1
	check_near(s.jump_reach, 0.5, 1e-6, "and to 50%")
