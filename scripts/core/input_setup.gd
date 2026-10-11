extends Node
## Registers the named input actions of spec 17 in code (autoload "InputSetup").
## Every action gets keyboard/mouse and controller defaults. Saved settings can later
## override bindings: pass {action_name: Array of InputEvent} to register_actions().

const STICK_DEADZONE := 0.25
const LOOK_DEADZONE := 0.15
const BUTTON_DEADZONE := 0.5

## Look has arrow keys as a keyboard alternative; mouse look comes from InputEventMouseMotion.
## "axes" entries are [JoyAxis, direction]. "dead" is the action deadzone.
const BINDINGS := {
	"move_forward": {"keys": [KEY_W], "axes": [[JOY_AXIS_LEFT_Y, -1.0]], "dead": STICK_DEADZONE},
	"move_back": {"keys": [KEY_S], "axes": [[JOY_AXIS_LEFT_Y, 1.0]], "dead": STICK_DEADZONE},
	"move_left": {"keys": [KEY_A], "axes": [[JOY_AXIS_LEFT_X, -1.0]], "dead": STICK_DEADZONE},
	"move_right": {"keys": [KEY_D], "axes": [[JOY_AXIS_LEFT_X, 1.0]], "dead": STICK_DEADZONE},
	"look_left": {"keys": [KEY_LEFT], "axes": [[JOY_AXIS_RIGHT_X, -1.0]], "dead": LOOK_DEADZONE},
	"look_right": {"keys": [KEY_RIGHT], "axes": [[JOY_AXIS_RIGHT_X, 1.0]], "dead": LOOK_DEADZONE},
	"look_up": {"keys": [KEY_UP], "axes": [[JOY_AXIS_RIGHT_Y, -1.0]], "dead": LOOK_DEADZONE},
	"look_down": {"keys": [KEY_DOWN], "axes": [[JOY_AXIS_RIGHT_Y, 1.0]], "dead": LOOK_DEADZONE},
	"prepare_jump": {"keys": [KEY_SPACE], "buttons": [JOY_BUTTON_A], "dead": BUTTON_DEADZONE},
	"focus": {"mouse": [MOUSE_BUTTON_RIGHT], "axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]], "dead": BUTTON_DEADZONE},
	"stalk": {"keys": [KEY_SHIFT], "buttons": [JOY_BUTTON_LEFT_SHOULDER], "dead": BUTTON_DEADZONE},
	"interact": {"keys": [KEY_E], "buttons": [JOY_BUTTON_X], "dead": BUTTON_DEADZONE},
	"reel": {"keys": [KEY_W], "axes": [[JOY_AXIS_LEFT_Y, -1.0]], "dead": STICK_DEADZONE},
	"lower": {"keys": [KEY_S], "axes": [[JOY_AXIS_LEFT_Y, 1.0]], "dead": STICK_DEADZONE},
	"cancel": {"keys": [KEY_Q], "buttons": [JOY_BUTTON_B], "dead": BUTTON_DEADZONE},
	"recenter": {"keys": [KEY_R], "mouse": [MOUSE_BUTTON_MIDDLE], "buttons": [JOY_BUTTON_RIGHT_STICK], "dead": BUTTON_DEADZONE},
	"pause": {"keys": [KEY_ESCAPE], "buttons": [JOY_BUTTON_START], "dead": BUTTON_DEADZONE},
	# T09 (U01): the habitat's field notes, from the keyboard or the controller's View / Back button.
	"help": {"keys": [KEY_H], "buttons": [JOY_BUTTON_BACK], "dead": BUTTON_DEADZONE},
	"debug_overlay": {"keys": [KEY_F3], "dead": BUTTON_DEADZONE},
	"debug_support": {"keys": [KEY_F4], "dead": BUTTON_DEADZONE},
}

## T09d (U01): a controller input an action can be given, as one number: a button is its JoyButton, a trigger is PAD_TRIGGER plus its
## JoyAxis. NO_PAD: none. The sticks are not given this way (walking and looking stay on them).
const PAD_TRIGGER := 100
const NO_PAD := -1
## The names the screen uses for them (the layout of spec 17's controller column: A, B, X, Y, View, Menu).
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_BACK: "View", JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "left stick click", JOY_BUTTON_RIGHT_STICK: "right stick click",
	JOY_BUTTON_LEFT_SHOULDER: "left shoulder", JOY_BUTTON_RIGHT_SHOULDER: "right shoulder", JOY_BUTTON_DPAD_UP: "D-pad up",
	JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right", JOY_BUTTON_MISC1: "Share",
	JOY_BUTTON_PADDLE1: "paddle 1", JOY_BUTTON_PADDLE2: "paddle 2", JOY_BUTTON_PADDLE3: "paddle 3", JOY_BUTTON_PADDLE4: "paddle 4",
	JOY_BUTTON_TOUCHPAD: "touchpad", PAD_TRIGGER + JOY_AXIS_TRIGGER_LEFT: "left trigger", PAD_TRIGGER + JOY_AXIS_TRIGGER_RIGHT: "right trigger",
}

## Actions from spec 17 (everything except the developer overlay and support view).
const GAME_ACTIONS: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right",
	"look_left", "look_right", "look_up", "look_down",
	"prepare_jump", "focus", "stalk", "interact", "reel", "lower", "cancel", "recenter", "pause",
]


func _ready() -> void:
	var overrides: Dictionary = {}
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("get_binding_overrides"):
		overrides = settings.get_binding_overrides()
		# T09: a key changed in the pause menu takes effect at once.
		settings.setting_changed.connect(func(key: String) -> void:
			if key == "bindings":
				register_actions(settings.get_binding_overrides()))
	register_actions(overrides)


## Creates or resets every action. Overrides replace the default events of an action.
func register_actions(overrides: Dictionary = {}) -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, float(BINDINGS[action]["dead"]))
		var events: Array = overrides.get(action, default_events(action))
		for event: Variant in events:
			InputMap.action_add_event(action, event as InputEvent)


func default_events(action: String) -> Array[InputEvent]:
	return defaults_of(action)


static func defaults_of(action: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	var b: Dictionary = BINDINGS.get(action, {})
	for code: int in b.get("keys", []):
		var k := InputEventKey.new()
		k.physical_keycode = code as Key
		k.device = -1
		out.append(k)
	for button: int in b.get("mouse", []):
		var m := InputEventMouseButton.new()
		m.button_index = button as MouseButton
		m.device = -1
		out.append(m)
	for button: int in b.get("buttons", []):
		var jb := InputEventJoypadButton.new()
		jb.button_index = button as JoyButton
		jb.device = -1
		out.append(jb)
	for pair: Array in b.get("axes", []):
		var ja := InputEventJoypadMotion.new()
		ja.axis = int(pair[0]) as JoyAxis
		ja.axis_value = float(pair[1])
		ja.device = -1
		out.append(ja)
	return out


## T09 (remapping): the default events of `action` with its keyboard key replaced by `keycode` (0: no key) and, T09d, its controller button
## or trigger replaced by `pad` (NO_PAD: the default stays). The mouse buttons and the sticks stay. Used by Settings to turn the player's
## choices into the action's full list.
static func events_for(action: String, keycode: int, pad: int = NO_PAD) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if keycode > 0:
		var k := InputEventKey.new()
		k.physical_keycode = keycode as Key
		k.device = -1
		out.append(k)
	for e in defaults_of(action):
		if e is InputEventKey:
			continue
		if pad != NO_PAD and (e is InputEventJoypadButton or (e is InputEventJoypadMotion and _is_trigger((e as InputEventJoypadMotion).axis))):
			continue
		out.append(e)
	if pad != NO_PAD:
		out.append(pad_event(pad))
	return out


## T09d: the default controller button or trigger of an action (NO_PAD when it has none, as for the sticks).
static func default_pad(action: String) -> int:
	var b: Dictionary = BINDINGS.get(action, {})
	var buttons: Array = b.get("buttons", [])
	if not buttons.is_empty():
		return int(buttons[0])
	for pair: Array in b.get("axes", []):
		if _is_trigger(int(pair[0])):
			return PAD_TRIGGER + int(pair[0])
	return NO_PAD


## T09d: a button or a trigger from its number (see PAD_TRIGGER).
static func pad_event(pad: int) -> InputEvent:
	if pad >= PAD_TRIGGER:
		var ja := InputEventJoypadMotion.new()
		ja.axis = (pad - PAD_TRIGGER) as JoyAxis
		ja.axis_value = 1.0
		ja.device = -1
		return ja
	var jb := InputEventJoypadButton.new()
	jb.button_index = pad as JoyButton
	jb.device = -1
	return jb


## T09d: the number of a pressed button or a pulled trigger (NO_PAD for anything else: a stick, a release, a light touch on a trigger).
static func pad_of_event(event: InputEvent) -> int:
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		return int((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion and _is_trigger((event as InputEventJoypadMotion).axis) and (event as InputEventJoypadMotion).axis_value >= 0.6:
		return PAD_TRIGGER + int((event as InputEventJoypadMotion).axis)
	return NO_PAD


static func pad_name(pad: int) -> String:
	return str(PAD_NAMES.get(pad, "button %d" % pad)) if pad != NO_PAD else "none"


static func is_pad(pad: int) -> bool:
	return PAD_NAMES.has(pad)


static func _is_trigger(axis: int) -> bool:
	return axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT


## The default keyboard key of an action, 0 when it has none.
static func default_key(action: String) -> int:
	var keys: Array = (BINDINGS.get(action, {}) as Dictionary).get("keys", [])
	return int(keys[0]) if not keys.is_empty() else 0
