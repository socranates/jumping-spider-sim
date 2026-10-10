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
	"debug_overlay": {"keys": [KEY_F3], "dead": BUTTON_DEADZONE},
	"debug_support": {"keys": [KEY_F4], "dead": BUTTON_DEADZONE},
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
