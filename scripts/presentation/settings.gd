extends Node
## Persistent player settings (autoload "Settings"). Saved to user://settings.cfg on every
## change and loaded at start. A missing or corrupt file, or an invalid value, falls back to
## the defaults. Numeric values are clamped to their limits.

signal setting_changed(key: String)

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULTS := {
	"look_sensitivity": 1.0,   # multiplier on the base mouse and stick look speeds
	"invert_x": false,
	"invert_y": false,
	"fov_degrees": 65.0,       # vertical field of view
	"camera_distance": 5.0,    # WU from the pivot to the camera
	"stalk_toggle": false,     # false: hold Shift to stalk; true: press to toggle
	"prepare_toggle": false,   # false: hold Space to aim and release to jump; true: press to aim, press again to jump
	"focus_toggle": false,     # chunk 7A (A-026): false: hold Focus (right mouse, left trigger); true: press to start it and press again (or cancel) to stop
	"detailed_arc": false,     # draw the predicted jump arc while aiming (the landing patch is always shown)
	"jump_reach": 1.0,         # playtest: jump reach as a fraction of the species profile's (launch speed and longest flight time scale by its square root)
	"release_hold": true,      # true: hold cancel (Q, east button) to let go of the safety line; false: a fresh press lets go
	"frame_line_after_catch": true,  # chunk 6B: the camera may turn the view up to 45 degrees to show the line while the spider hangs on it (A-017)
	"show_last_seen": true,    # chunk 6B (A-002): a faint mark at the last place a target was sensed, going stale with time
	"show_gaze": false,        # chunk 6B (A-003): an optional footprint of where the spider is looking; reveals nothing hidden
	"capture_assist": false,   # chunk 7B: off by default; on, a strike catches a fly within a wider reach (the profile's capture_assist_scale)
	"ui_scale": 1.0,           # T09 (U01): size of all text and on-screen panels (the window's 2D content scale); the 3D view is unchanged
	"struggle_auto": false,    # T09b: struggling prey is held with no presses (spec 17: no required rapid tapping)
	"reduced_motion": false,   # T09b: the spider's model keeps still (no twitchy turns, lurches, flicks, jolts or catch recoil); looks only
	"eye_view": false,         # T10a: see through the spider's eyes (first person) instead of the orbit camera; V or Y switches it
}
## Inclusive [min, max] for the numeric settings.
const LIMITS := {
	"look_sensitivity": [0.2, 3.0],
	"fov_degrees": [50.0, 90.0],
	"camera_distance": [4.0, 7.0],
	"jump_reach": [0.5, 1.5],
	"ui_scale": [1.0, 1.5],
}
## T09 (U01): keyboard keys the player may change, in the order the pause menu lists them, with their names there. The mouse buttons
## stay as they are. Reel and lower follow walk forward and walk back (spec 17: W/S with a context override).
const REMAPPABLE: Array[String] = ["move_forward", "move_back", "move_left", "move_right", "prepare_jump", "focus", "stalk", "interact",
	"cancel", "recenter", "help", "eye_view", "look_left", "look_right", "look_up", "look_down"]
const ACTION_NAMES := {
	"move_forward": "Walk forward / reel in", "move_back": "Walk back / lower", "move_left": "Walk left", "move_right": "Walk right",
	"prepare_jump": "Aim and jump", "focus": "Focus", "stalk": "Stalk", "interact": "Eat / rest", "cancel": "Cancel / let go",
	"recenter": "Recenter view", "help": "Field notes", "eye_view": "Spider-eye view", "look_left": "Look left", "look_right": "Look right", "look_up": "Look up",
	"look_down": "Look down",
}
const LINKED := {"move_forward": "reel", "move_back": "lower"}
## Keys that cannot be given to an action: pause (the way out of every menu) and the developer views.
const RESERVED_KEYS: Array[int] = [KEY_ESCAPE, KEY_F3, KEY_F4]
const BINDINGS_SECTION := "bindings"
## T09d (U01): the controller buttons and triggers the player may change (the sticks stay: walking and looking). Menu (pause, the way out
## of every menu) and Guide (the system's) are kept.
const PAD_REMAPPABLE: Array[String] = ["prepare_jump", "focus", "stalk", "interact", "cancel", "recenter", "help", "eye_view"]
const RESERVED_PADS: Array[int] = [JOY_BUTTON_START, JOY_BUTTON_GUIDE]
const PAD_SECTION := "pad_bindings"
## T09d (spec 17: "assisted play presets"; "adjustable aim/capture assistance"; "no shame labels"): each preset sets these switches at
## once and says plainly what it does. The player can still change any switch afterwards; the menu then says "Custom". Presets leave the
## camera, the text size, Reduced motion and the playtest jump reach alone.
const PRESET_KEYS: Array[String] = ["capture_assist", "detailed_arc", "show_gaze", "struggle_auto", "prepare_toggle", "stalk_toggle",
	"focus_toggle", "release_hold"]
const PRESETS: Array[Dictionary] = [
	{"id": "standard", "name": "Standard",
		"note": "The hunt as designed: hold to aim, stalk and focus; keep tapping to hold a struggling fly; hold Q / B to let go of the line.",
		"values": {"capture_assist": false, "detailed_arc": false, "show_gaze": false, "struggle_auto": false, "prepare_toggle": false,
			"stalk_toggle": false, "focus_toggle": false, "release_hold": true}},
	{"id": "guided", "name": "Guided hunting",
		"note": "A wider reach for the bite, the jump arc and where the spider looks are shown, and a struggling fly is held for you.",
		"values": {"capture_assist": true, "detailed_arc": true, "show_gaze": true, "struggle_auto": true, "prepare_toggle": false,
			"stalk_toggle": false, "focus_toggle": false, "release_hold": true}},
	{"id": "no_holding", "name": "No held buttons",
		"note": "Aim, stalk and focus each start with one press and stop with another, a struggling fly is held for you, and one press of Q / B lets go of the line.",
		"values": {"capture_assist": false, "detailed_arc": false, "show_gaze": false, "struggle_auto": true, "prepare_toggle": true,
			"stalk_toggle": true, "focus_toggle": true, "release_hold": false}},
	{"id": "most_help", "name": "Most help",
		"note": "Everything in Guided hunting, and aim, stalk and focus by single presses. Letting go of the line is still a hold of Q / B, so it does not happen by accident.",
		"values": {"capture_assist": true, "detailed_arc": true, "show_gaze": true, "struggle_auto": true, "prepare_toggle": true,
			"stalk_toggle": true, "focus_toggle": true, "release_hold": true}},
]
const InputSetupScript = preload("res://scripts/core/input_setup.gd")

## Tests point this at a temporary file; the autoload keeps the default.
var config_path: String = DEFAULT_PATH
var autosave: bool = true
var _values: Dictionary = DEFAULTS.duplicate()
## Remapped keyboard keys: action -> physical keycode. Only actions the player changed are here.
var _keys: Dictionary = {}
## T09d: remapped controller inputs: action -> InputSetup pad number. Only actions the player changed are here.
var _pads: Dictionary = {}

var look_sensitivity: float:
	get: return _values["look_sensitivity"]
	set(v): set_value("look_sensitivity", v)
var invert_x: bool:
	get: return _values["invert_x"]
	set(v): set_value("invert_x", v)
var invert_y: bool:
	get: return _values["invert_y"]
	set(v): set_value("invert_y", v)
var fov_degrees: float:
	get: return _values["fov_degrees"]
	set(v): set_value("fov_degrees", v)
var camera_distance: float:
	get: return _values["camera_distance"]
	set(v): set_value("camera_distance", v)
var stalk_toggle: bool:
	get: return _values["stalk_toggle"]
	set(v): set_value("stalk_toggle", v)
var prepare_toggle: bool:
	get: return _values["prepare_toggle"]
	set(v): set_value("prepare_toggle", v)
var focus_toggle: bool:
	get: return _values["focus_toggle"]
	set(v): set_value("focus_toggle", v)
var detailed_arc: bool:
	get: return _values["detailed_arc"]
	set(v): set_value("detailed_arc", v)

var jump_reach: float:
	get: return _values["jump_reach"]
	set(v): set_value("jump_reach", v)

var release_hold: bool:
	get: return _values["release_hold"]
	set(v): set_value("release_hold", v)

var frame_line_after_catch: bool:
	get: return _values["frame_line_after_catch"]
	set(v): set_value("frame_line_after_catch", v)

var show_last_seen: bool:
	get: return _values["show_last_seen"]
	set(v): set_value("show_last_seen", v)

var show_gaze: bool:
	get: return _values["show_gaze"]
	set(v): set_value("show_gaze", v)

var capture_assist: bool:
	get: return _values["capture_assist"]
	set(v): set_value("capture_assist", v)


func _ready() -> void:
	load_settings()


## Validates, stores, announces and (when autosave is on) saves one setting.
## Returns false for an unknown key or a value of the wrong type.
func set_value(key: String, value: Variant) -> bool:
	if not DEFAULTS.has(key):
		push_error("Settings: unknown key '%s'" % key)
		return false
	var coerced: Variant = _coerce(key, value)
	if coerced == null:
		push_error("Settings: invalid value for '%s'" % key)
		return false
	if typeof(_values[key]) == typeof(coerced) and _values[key] == coerced:
		return true
	_values[key] = coerced
	setting_changed.emit(key)
	if autosave:
		save_settings()
	return true


func get_value(key: String) -> Variant:
	return _values.get(key)


func reset_to_defaults() -> void:
	for key: String in DEFAULTS:
		set_value(key, DEFAULTS[key])


## {action: Array of InputEvent} for every remapped action (and the action that follows it), for InputSetup.register_actions.
func get_binding_overrides() -> Dictionary:
	var out := {}
	var changed: Array[String] = []
	for action: String in _keys.keys() + _pads.keys():
		if not changed.has(action):
			changed.append(action)
	for action: String in changed:
		out[action] = InputSetupScript.events_for(action, get_key(action), int(_pads.get(action, InputSetupScript.NO_PAD)))
		if LINKED.has(action):
			out[LINKED[action]] = InputSetupScript.events_for(LINKED[action], get_key(action))
	return out


## The keyboard key an action answers to now (its remapped key, else its default; 0 for none).
func get_key(action: String) -> int:
	return int(_keys.get(action, InputSetupScript.default_key(action)))


## Gives `action` the key `keycode`. A key another action already uses is swapped: that action gets this one's old key, so no two actions
## share a key by accident and nothing is left without one. Returns {"ok", "message", "swapped"} (swapped: the other action, or "").
func set_key(action: String, keycode: int) -> Dictionary:
	if not REMAPPABLE.has(action):
		return {"ok": false, "message": "%s cannot be changed" % action, "swapped": ""}
	if keycode <= 0 or RESERVED_KEYS.has(keycode):
		return {"ok": false, "message": "%s is kept for the pause menu and the developer views" % OS.get_keycode_string(keycode as Key), "swapped": ""}
	var old := get_key(action)
	if old == keycode:
		return {"ok": true, "message": "%s: %s" % [ACTION_NAMES[action], OS.get_keycode_string(keycode as Key)], "swapped": ""}
	var swapped := ""
	for other: String in REMAPPABLE:
		if other != action and get_key(other) == keycode:
			swapped = other
			_store_key(other, old)
	_store_key(action, keycode)
	setting_changed.emit("bindings")
	if autosave:
		save_settings()
	var message := "%s: %s" % [ACTION_NAMES[action], OS.get_keycode_string(keycode as Key)]
	if swapped != "":
		message += " (%s now uses %s)" % [ACTION_NAMES[swapped], OS.get_keycode_string(old as Key) if old > 0 else "no key"]
	return {"ok": true, "message": message, "swapped": swapped}


func _store_key(action: String, keycode: int) -> void:
	if keycode == InputSetupScript.default_key(action):
		_keys.erase(action)
	else:
		_keys[action] = keycode


## T09d: the controller button or trigger an action answers to now (InputSetup's pad number; NO_PAD for none).
func get_pad(action: String) -> int:
	return int(_pads.get(action, InputSetupScript.default_pad(action)))


func pad_name(action: String) -> String:
	return InputSetupScript.pad_name(get_pad(action))


## T09d: gives `action` the controller button or trigger `pad`, swapping with an action that already uses it, as set_key does.
func set_pad(action: String, pad: int) -> Dictionary:
	if not PAD_REMAPPABLE.has(action):
		return {"ok": false, "message": "%s stays on its stick" % String(ACTION_NAMES.get(action, action)), "swapped": ""}
	if not InputSetupScript.is_pad(pad) or RESERVED_PADS.has(pad):
		return {"ok": false, "message": "%s is kept for the pause menu and the system" % InputSetupScript.pad_name(pad), "swapped": ""}
	var old := get_pad(action)
	var message := "%s: %s" % [ACTION_NAMES[action], InputSetupScript.pad_name(pad)]
	if old == pad:
		return {"ok": true, "message": message, "swapped": ""}
	var swapped := ""
	for other: String in PAD_REMAPPABLE:
		if other != action and get_pad(other) == pad:
			swapped = other
			_store_pad(other, old)
	_store_pad(action, pad)
	setting_changed.emit("bindings")
	if autosave:
		save_settings()
	if swapped != "":
		message += " (%s now uses %s)" % [ACTION_NAMES[swapped], InputSetupScript.pad_name(old)]
	return {"ok": true, "message": message, "swapped": swapped}


func _store_pad(action: String, pad: int) -> void:
	if pad == InputSetupScript.default_pad(action):
		_pads.erase(action)
	else:
		_pads[action] = pad


## Every key and controller input back to its default (T09d: the controller's too).
func reset_keys() -> void:
	if _keys.is_empty() and _pads.is_empty():
		return
	_keys.clear()
	_pads.clear()
	setting_changed.emit("bindings")
	if autosave:
		save_settings()


func save_settings() -> Error:
	var cfg := ConfigFile.new()
	for key: String in DEFAULTS:
		cfg.set_value(SECTION, key, _values[key])
	for action: String in _keys:
		cfg.set_value(BINDINGS_SECTION, action, int(_keys[action]))
	for action: String in _pads:
		cfg.set_value(PAD_SECTION, action, int(_pads[action]))
	var err := cfg.save(config_path)
	if err != OK:
		push_warning("Settings: could not save %s (error %d)" % [config_path, err])
	return err


## Loads from config_path. Returns true when a readable file was found. Anything missing,
## corrupt or invalid keeps its default.
func load_settings() -> bool:
	_values = DEFAULTS.duplicate()
	_keys = {}
	_pads = {}
	var cfg := ConfigFile.new()
	if cfg.load(config_path) != OK:
		return false
	if cfg.has_section(BINDINGS_SECTION):
		for action: String in cfg.get_section_keys(BINDINGS_SECTION):
			var code: Variant = cfg.get_value(BINDINGS_SECTION, action)
			if REMAPPABLE.has(action) and typeof(code) == TYPE_INT and int(code) > 0 and not RESERVED_KEYS.has(int(code)):
				_store_key(action, int(code))
	if cfg.has_section(PAD_SECTION):
		for action: String in cfg.get_section_keys(PAD_SECTION):
			var pad: Variant = cfg.get_value(PAD_SECTION, action)
			if PAD_REMAPPABLE.has(action) and typeof(pad) == TYPE_INT and InputSetupScript.is_pad(int(pad)) and not RESERVED_PADS.has(int(pad)):
				_store_pad(action, int(pad))
	for key: String in DEFAULTS:
		if cfg.has_section_key(SECTION, key):
			var coerced: Variant = _coerce(key, cfg.get_value(SECTION, key))
			if coerced != null:
				_values[key] = coerced
	return true


# ------------------------------------------------------------------ assisted-play presets (T09d)

## The preset the switches match now ("custom" when they match none).
func current_preset() -> String:
	for p: Dictionary in PRESETS:
		var same := true
		for key: String in (p["values"] as Dictionary):
			same = same and _values[key] == (p["values"] as Dictionary)[key]
		if same:
			return str(p["id"])
	return "custom"


func preset(id: String) -> Dictionary:
	for p: Dictionary in PRESETS:
		if str(p["id"]) == id:
			return p
	return {}


## Sets every switch of the preset (each announced as usual) and saves once. Returns false for an unknown preset.
func apply_preset(id: String) -> bool:
	var p := preset(id)
	if p.is_empty():
		push_error("Settings: unknown preset '%s'" % id)
		return false
	var was := autosave
	autosave = false
	for key: String in (p["values"] as Dictionary):
		set_value(key, (p["values"] as Dictionary)[key])
	autosave = was
	if autosave:
		save_settings()
	return true


## Returns the value in canonical type and range, or null when it is unusable.
func _coerce(key: String, value: Variant) -> Variant:
	var default_value: Variant = DEFAULTS[key]
	if typeof(default_value) == TYPE_BOOL:
		return value if typeof(value) == TYPE_BOOL else null
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return null
	var f: float = value
	if not is_finite(f):
		return null
	var limits: Array = LIMITS[key]
	return clampf(f, float(limits[0]), float(limits[1]))
