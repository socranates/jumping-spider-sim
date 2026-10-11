extends "res://tests/prey_test_case.gd"
## T09d, the rest of T09's accessibility list that a test can show (spec 17: "Inputs are remappable actions"; "Adjustable aim/capture
## assistance"; "assisted play presets"; "no shame labels"):
##   * a controller button or trigger can be given to an action; it drives the real action, survives a restart, swaps with an action that
##     already uses it, never takes Menu (pause) or Guide, and leaves the sticks alone; a damaged file keeps the defaults;
##   * the pause menu's key list has a controller column that listens for a button or a trigger pull;
##   * every prompt names the controller buttons the player chose;
##   * a preset sets its switches at once, says what it does in words, survives a restart, and shows "Custom" once a switch is changed;
##     it changes the running game.
## U01 itself (a person completing the loop with a controller only) is still a human playtest and is not claimed here.

const InputSetupScript = preload("res://scripts/core/input_setup.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const KeyNames = preload("res://scripts/presentation/key_names.gd")
const TEMP_PATH := "user://jss_test_t09d_settings.cfg"

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


func _register(s: Node) -> void:
	var setup: Node = InputSetupScript.new()
	setup.register_actions(s.get_binding_overrides())
	setup.free()


func _has_button(action: String, button: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and int((e as InputEventJoypadButton).button_index) == button:
			return true
	return false


func _has_axis(action: String, axis: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion and int((e as InputEventJoypadMotion).axis) == axis:
			return true
	return false


func _has_key(action: String, code: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == code:
			return true
	return false


func _button(index: int) -> InputEventJoypadButton:
	var b := InputEventJoypadButton.new()
	b.button_index = index as JoyButton
	b.pressed = true
	return b


func _axis(axis: int, value: float) -> InputEventJoypadMotion:
	var m := InputEventJoypadMotion.new()
	m.axis = axis as JoyAxis
	m.axis_value = value
	return m


func _key(code: int) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code as Key
	k.pressed = true
	return k


# ------------------------------------------------------------------ remapping the controller

func test_a_remapped_controller_button_drives_the_action_and_survives_a_restart() -> void:
	var s := _fresh_settings()
	check_eq(s.get_pad("prepare_jump"), JOY_BUTTON_A, "aiming starts on A")
	var r: Dictionary = s.set_pad("prepare_jump", JOY_BUTTON_Y)
	check(bool(r["ok"]) and str(r["message"]) == "Aim and jump: Y", "aiming takes Y: %s" % r["message"])
	_register(s)
	check(_has_button("prepare_jump", JOY_BUTTON_Y) and not _has_button("prepare_jump", JOY_BUTTON_A), "aiming answers Y, not A")
	check(_has_key("prepare_jump", KEY_SPACE), "the keyboard key stays")
	check(_button(JOY_BUTTON_Y).is_action_pressed("prepare_jump"), "a press of Y is the aim-and-jump action")
	check(_has_axis("move_forward", JOY_AXIS_LEFT_Y) and _has_axis("look_left", JOY_AXIS_RIGHT_X), "the sticks are untouched")
	var again := _fresh_settings()
	check_eq(again.get_pad("prepare_jump"), JOY_BUTTON_Y, "the button survives a restart")
	check_eq(again.get_pad("cancel"), JOY_BUTTON_B, "the others keep their defaults")


func test_a_button_in_use_is_swapped_and_menu_guide_and_sticks_are_kept() -> void:
	var s := _fresh_settings()
	var r: Dictionary = s.set_pad("interact", JOY_BUTTON_B)
	check_eq(str(r["swapped"]), "cancel", "B was cancel's: the two are swapped")
	check_eq(s.get_pad("cancel"), JOY_BUTTON_X, "cancel now has interact's old X")
	check(str(r["message"]).contains("Cancel / let go now uses X"), "and the menu says so: %s" % r["message"])
	check(not bool(s.set_pad("interact", JOY_BUTTON_START)["ok"]), "Menu stays the way out of every menu")
	check(not bool(s.set_pad("interact", JOY_BUTTON_GUIDE)["ok"]), "Guide stays the system's")
	check(not bool(s.set_pad("move_forward", JOY_BUTTON_Y)["ok"]), "walking stays on its stick")
	check(not bool(s.set_pad("interact", 99)["ok"]), "an unknown number is refused")
	# a trigger can be given too, and the trigger an action leaves is removed from it
	var t: Dictionary = s.set_pad("stalk", InputSetupScript.PAD_TRIGGER + JOY_AXIS_TRIGGER_LEFT)
	check(bool(t["ok"]) and str(t["swapped"]) == "focus", "stalk takes the left trigger from Focus: %s" % t["message"])
	_register(s)
	check(_has_axis("stalk", JOY_AXIS_TRIGGER_LEFT) and not _has_button("stalk", JOY_BUTTON_LEFT_SHOULDER), "stalk answers the left trigger")
	check(_has_button("focus", JOY_BUTTON_LEFT_SHOULDER) and not _has_axis("focus", JOY_AXIS_TRIGGER_LEFT), "Focus answers the left shoulder")
	var right_mouse := false
	for e in InputMap.action_get_events("focus"):
		right_mouse = right_mouse or (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT)
	check(right_mouse, "and still the right mouse button")
	check(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0).is_action_pressed("stalk"), "a pull of the left trigger is the stalk action")
	s.reset_keys()
	_register(s)
	check(_has_button("interact", JOY_BUTTON_X) and _has_button("cancel", JOY_BUTTON_B) and _has_axis("focus", JOY_AXIS_TRIGGER_LEFT)
		and _has_button("stalk", JOY_BUTTON_LEFT_SHOULDER), "reset brings every default button back")
	check_eq(_fresh_settings().get_pad("interact"), JOY_BUTTON_X, "and the reset is saved")


func test_a_damaged_bindings_file_keeps_the_default_buttons() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("pad_bindings", "prepare_jump", JOY_BUTTON_START)   # reserved
	cfg.set_value("pad_bindings", "interact", "X")                   # not a number
	cfg.set_value("pad_bindings", "move_forward", JOY_BUTTON_Y)       # a stick action
	cfg.set_value("pad_bindings", "cancel", 999)                     # no such button
	cfg.set_value("pad_bindings", "stalk", JOY_BUTTON_RIGHT_SHOULDER) # fine
	cfg.save(TEMP_PATH)
	var s := _fresh_settings()
	check_eq(s.get_pad("prepare_jump"), JOY_BUTTON_A, "a reserved button is ignored")
	check_eq(s.get_pad("interact"), JOY_BUTTON_X, "a value that is not a number is ignored")
	check_eq(s.get_pad("move_forward"), InputSetupScript.NO_PAD, "a stick action gets no button")
	check_eq(s.get_pad("cancel"), JOY_BUTTON_B, "an unknown button is ignored")
	check_eq(s.get_pad("stalk"), JOY_BUTTON_RIGHT_SHOULDER, "the good line is kept")


# ------------------------------------------------------------------ the pause menu's controller column

func test_the_pause_menu_remaps_a_controller_button_or_trigger() -> void:
	var s := _fresh_settings()
	var menu := PauseMenu.new()
	menu.settings = s
	sandbox.add_child(menu)
	menu.set_paused(true)
	var toggle := menu.find_child("KeysToggle", true, false) as Button
	var pad := menu.find_child("Pad_interact", true, false) as Button
	var stick := menu.find_child("Pad_move_forward", true, false) as Button
	if not check(toggle != null and pad != null and stick != null, "the controller column is in the menu"):
		menu.set_paused(false)
		return
	check_eq(toggle.text, "Keys and buttons...", "the list says it holds buttons too")
	toggle.pressed.emit()
	check_eq(pad.text, "X", "eat / rest shows its button")
	check(stick.disabled and stick.text == "left stick", "walking shows its stick and cannot be changed")
	check_eq((menu.find_child("Key_focus", true, false) as Button).text, "right mouse", "Focus, with no key, shows its mouse button")
	pad.pressed.emit()
	check_eq(pad.text, "press a button", "the button waits for a controller input")
	menu._input(_key(KEY_C))
	check_eq(s.get_pad("interact"), JOY_BUTTON_X, "a keyboard key does not answer it")
	check_eq(pad.text, "press a button", "and it keeps waiting")
	menu._input(_axis(JOY_AXIS_LEFT_X, 0.9))
	check_eq(pad.text, "press a button", "a stick nudge is ignored")
	menu._input(_button(JOY_BUTTON_START))
	check(runner.get_tree().paused, "Menu while choosing stops choosing, and does not close the menu")
	check_eq(s.get_pad("interact"), JOY_BUTTON_X, "nothing changed")
	pad.pressed.emit()
	menu._input(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.3))
	check_eq(pad.text, "press a button", "a light touch on a trigger is not a choice")
	menu._input(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	check_eq(s.get_pad("interact"), InputSetupScript.PAD_TRIGGER + JOY_AXIS_TRIGGER_RIGHT, "eat / rest is now the right trigger")
	check_eq(pad.text, "right trigger", "and the button says so")
	pad.pressed.emit()
	menu._input(_button(JOY_BUTTON_B))
	check_eq(s.get_pad("interact"), JOY_BUTTON_B, "a button in use is swapped")
	check_eq((menu.find_child("Pad_cancel", true, false) as Button).text, "right trigger", "cancel took eat / rest's trigger")
	var status := menu.find_child("KeysStatus", true, false) as Label
	check(status.text.contains("now uses right trigger"), "the menu says what was swapped: %s" % status.text)
	var hold := menu._checks["release_hold"] as CheckBox
	check(hold.text.begins_with("Hold Q / right trigger to let go"), "labels that name the button follow: %s" % hold.text)
	(menu.find_child("ResetKeys", true, false) as Button).pressed.emit()
	check(s.get_pad("interact") == JOY_BUTTON_X and s.get_pad("cancel") == JOY_BUTTON_B, "reset brings the buttons back")
	check(hold.text.begins_with("Hold Q / B"), "and the labels")
	menu.set_paused(false)


# ------------------------------------------------------------------ the words on the screen

func test_every_prompt_names_the_controller_buttons_the_player_chose() -> void:
	settings.set_pad("cancel", JOY_BUTTON_Y)
	check_eq(KeyNames.apply("Q / B: cancel the jump", settings), "Q / Y: cancel the jump", "the aim hint")
	settings.set_key("cancel", KEY_E)          # swaps with interact: E for cancel, Q for interact
	settings.set_pad("cancel", JOY_BUTTON_X)   # swaps with interact: X for cancel, Y for interact
	check_eq(KeyNames.apply("E / X to eat    Q / B to stop", settings), "Q / Y to eat    E / X to stop",
		"swapped actions are each named once, never renamed twice")
	settings.reset_keys()
	settings.set_pad("interact", JOY_BUTTON_Y)
	settings.set_pad("prepare_jump", JOY_BUTTON_RIGHT_SHOULDER)
	use_windowsill = true
	await spawn_prey_world(floor_pose(-25, 6, -90))
	world.habitat_loop.toggle_help()
	var notes: String = world.habitat_loop.caption()
	check(notes.contains("Hold Space / right shoulder to aim") and notes.contains("E / Y: eat or rest"), "the field notes: %s" % notes)
	world.habitat_loop.toggle_help()
	world.queue_free()
	await physics_frames(2)
	use_windowsill = false
	var f := await catch_a_fly()
	var fc: Node = world.feeding
	fc.settings = settings
	check(str(fc.prompt()["hint"]).contains("E / Y to eat"), "holding prey: %s" % fc.prompt()["hint"])
	check(f != null, "a fly was caught")
	settings.reset_keys()


# ------------------------------------------------------------------ assisted-play presets

func test_a_preset_sets_its_switches_and_survives_a_restart() -> void:
	var s := _fresh_settings()
	check_eq(s.current_preset(), "standard", "the defaults are the Standard preset")
	for p: Dictionary in s.PRESETS:
		var keys: Array = (p["values"] as Dictionary).keys()
		keys.sort()
		var want: Array = s.PRESET_KEYS.duplicate()
		want.sort()
		check_eq(keys, want, "%s sets every assist switch" % p["name"])
		check(str(p["note"]).length() > 40, "%s says what it does" % p["name"])
		for bad: String in ["easy", "hard", "baby", "cheat", "normal"]:
			check(not str(p["name"]).to_lower().contains(bad), "%s has no shame label" % p["name"])
	s.set_value("ui_scale", 1.3)
	s.set_value("reduced_motion", true)
	check(s.apply_preset("most_help"), "Most help")
	for key: String in (s.preset("most_help")["values"] as Dictionary):
		check_eq(s.get_value(key), (s.preset("most_help")["values"] as Dictionary)[key], "most help sets %s" % key)
	check_near(float(s.get_value("ui_scale")), 1.3, 1.0e-6, "the text size is left alone")
	check(bool(s.get_value("reduced_motion")), "and Reduced motion")
	check_eq(s.current_preset(), "most_help", "the switches are said to be Most help")
	check_eq(_fresh_settings().current_preset(), "most_help", "and survive a restart")
	s.set_value("show_gaze", false)
	check_eq(s.current_preset(), "custom", "one switch changed: Custom")
	allow_errors(1)   # the refusal is reported
	check(not s.apply_preset("nonsense"), "an unknown preset is refused")
	check(s.apply_preset("standard") and s.current_preset() == "standard", "Standard brings the designed hunt back")


func test_the_pause_menu_offers_the_presets_in_words() -> void:
	var s := _fresh_settings()
	var menu := PauseMenu.new()
	menu.settings = s
	sandbox.add_child(menu)
	menu.set_paused(true)
	var guided := menu.find_child("Preset_guided", true, false) as Button
	var standard := menu.find_child("Preset_standard", true, false) as Button
	var note := menu.find_child("PresetNote", true, false) as Label
	if not check(guided != null and standard != null and note != null, "the presets are in the menu"):
		menu.set_paused(false)
		return
	check(standard.button_pressed and not guided.button_pressed, "Standard is shown as the current one")
	check(note.text.begins_with("Now: Standard."), "and said in words: %s" % note.text)
	guided.pressed.emit()
	check_eq(s.current_preset(), "guided", "Guided hunting is applied")
	check(guided.button_pressed and not standard.button_pressed, "and shown")
	check(note.text.begins_with("Now: Guided hunting. A wider reach for the bite"), "and described: %s" % note.text)
	var assist := menu._checks["capture_assist"] as CheckBox
	check(assist.button_pressed and assist.text.ends_with(": on"), "the switch below follows: %s" % assist.text)
	assist.button_pressed = false   # the player changes one switch
	check_eq(s.current_preset(), "custom", "one switch changed")
	check(not guided.button_pressed and note.text.begins_with("Now: Custom"), "the menu says Custom: %s" % note.text)
	s.set_key("cancel", KEY_Z)
	(menu.find_child("Preset_no_holding", true, false) as Button).pressed.emit()
	check(note.text.contains("one press of Z / B lets go of the line"), "the words name the player's keys: %s" % note.text)
	menu.set_paused(false)


func test_a_preset_changes_the_running_game() -> void:
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0))
	check(not bool(world.prey.assist) and not bool(world.feeding.struggle_auto), "the designed hunt to begin with")
	settings.apply_preset("most_help")
	check(bool(world.prey.assist), "a wider reach for the bite, at once")
	check(bool(world.feeding.struggle_auto), "a struggling fly is held for you")
	check(bool(settings.prepare_toggle) and bool(settings.stalk_toggle), "aim and stalk by single presses")
	settings.apply_preset("standard")
	check(not bool(world.prey.assist) and not bool(world.feeding.struggle_auto), "and back")
