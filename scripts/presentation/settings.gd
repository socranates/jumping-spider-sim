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
}
## Inclusive [min, max] for the numeric settings.
const LIMITS := {
	"look_sensitivity": [0.2, 3.0],
	"fov_degrees": [50.0, 90.0],
	"camera_distance": [4.0, 7.0],
	"jump_reach": [0.5, 1.5],
}

## Tests point this at a temporary file; the autoload keeps the default.
var config_path: String = DEFAULT_PATH
var autosave: bool = true
var _values: Dictionary = DEFAULTS.duplicate()

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


## Hook for a future remapping screen: {action: Array of InputEvent}. Empty for now.
func get_binding_overrides() -> Dictionary:
	return {}


func save_settings() -> Error:
	var cfg := ConfigFile.new()
	for key: String in DEFAULTS:
		cfg.set_value(SECTION, key, _values[key])
	var err := cfg.save(config_path)
	if err != OK:
		push_warning("Settings: could not save %s (error %d)" % [config_path, err])
	return err


## Loads from config_path. Returns true when a readable file was found. Anything missing,
## corrupt or invalid keeps its default.
func load_settings() -> bool:
	_values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(config_path) != OK:
		return false
	for key: String in DEFAULTS:
		if cfg.has_section_key(SECTION, key):
			var coerced: Variant = _coerce(key, cfg.get_value(SECTION, key))
			if coerced != null:
				_values[key] = coerced
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
