extends "res://tests/test_case.gd"

const InputSetupScript = preload("res://scripts/core/input_setup.gd")


func _kinds(action: String) -> Dictionary:
	var kb_or_mouse := 0
	var joypad := 0
	for e in InputMap.action_get_events(action):
		if e is InputEventKey or e is InputEventMouseButton:
			kb_or_mouse += 1
		elif e is InputEventJoypadButton or e is InputEventJoypadMotion:
			joypad += 1
	return {"kb": kb_or_mouse, "pad": joypad}


func test_every_section_17_action_has_keyboard_or_mouse_and_joypad_events() -> void:
	check_eq(InputSetupScript.GAME_ACTIONS.size(), 17, "the action list matches spec 17")
	for action: String in InputSetupScript.GAME_ACTIONS:
		if not check(InputMap.has_action(action), "action exists: " + action):
			continue
		var k := _kinds(action)
		check(k["kb"] >= 1, "keyboard or mouse event: " + action)
		check(k["pad"] >= 1, "joypad event: " + action)


func test_debug_overlay_action_is_bound_to_f3() -> void:
	if not check(InputMap.has_action("debug_overlay"), "debug_overlay exists"):
		return
	var found := false
	for e in InputMap.action_get_events("debug_overlay"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_F3:
			found = true
	check(found, "F3 is bound to debug_overlay")


func test_default_bindings_match_the_action_map() -> void:
	var expected := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"prepare_jump": KEY_SPACE, "stalk": KEY_SHIFT, "interact": KEY_E, "cancel": KEY_Q,
		"recenter": KEY_R, "pause": KEY_ESCAPE,
	}
	for action: String in expected:
		var found := false
		for e in InputMap.action_get_events(action):
			if e is InputEventKey and (e as InputEventKey).physical_keycode == expected[action]:
				found = true
		check(found, "default key for " + action)
	var middle := false
	for e in InputMap.action_get_events("recenter"):
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE:
			middle = true
	check(middle, "recenter also on the middle mouse button")


func test_saved_overrides_replace_defaults_and_can_be_reset() -> void:
	var setup: Node = InputSetupScript.new()
	var custom := InputEventKey.new()
	custom.physical_keycode = KEY_X
	setup.register_actions({"cancel": [custom]})
	var events := InputMap.action_get_events("cancel")
	check_eq(events.size(), 1, "override leaves exactly the override event")
	check(events.size() == 1 and (events[0] as InputEventKey).physical_keycode == KEY_X, "the override is the one bound")
	check(InputMap.has_action("pause"), "other actions are untouched")
	setup.register_actions()
	var k := _kinds("cancel")
	check(k["kb"] >= 1 and k["pad"] >= 1, "defaults come back after a reset")
	setup.free()
