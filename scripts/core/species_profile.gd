extends RefCounted
## Validating loader for species profile JSON (spec 21.1).
## Fails loudly: every problem found is reported with push_error and the loader returns null.
## Use through a preload constant:
##   const SpeciesProfile = preload("res://scripts/core/species_profile.gd")
##   var profile: SpeciesProfile.Profile = SpeciesProfile.load_file(path)

const SUPPORTED_SCHEMA_VERSION := 1
const POSITIVE := 0.000001
const MISSING := &"__missing__"

## Problems found by the most recent load, for tests and callers that want the text.
static var last_errors: PackedStringArray = PackedStringArray()
## Test switch: when true, errors are recorded in last_errors but not pushed to the engine log.
static var quiet: bool = false


class Profile extends RefCounted:
	var schema_version: int = 0
	var id: String = ""
	var biological_status: String = ""
	var body_length_wu: float = 0.0
	var walk_speed_wu_s: float = 0.0
	var stalk_speed_wu_s: float = 0.0
	var gravity_wu_s2: float = 0.0
	var max_launch_speed_wu_s: float = 0.0
	var flight_time_min_s: float = 0.0
	var flight_time_max_s: float = 0.0
	## Perception (spec 7; gameplay parameters, not anatomical measurements). The inspection cone is the FULL opening
	## angle, so 30 means 15 degrees either side of where the spider faces.
	var inspect_cone_degrees: float = 0.0
	var easy_target_inspection_s: float = 0.0
	## Continuous exposure that refines "possible prey" to "fly-like prey" (A-004), for a target that looks easy.
	var fly_like_inspection_s: float = 0.0
	## A target at least this many degrees across is "easy"; smaller ones need proportionally longer, and one below the
	## minimum cannot be inspected at all.
	var easy_apparent_size_deg: float = 0.0
	var min_apparent_size_deg: float = 0.0
	## Full opening angle of the broad peripheral field about where the spider faces, and the coarseness of the bearing a
	## peripheral cue gives (it is rounded to a sector of this many degrees).
	var peripheral_cone_degrees: float = 0.0
	var peripheral_sector_degrees: float = 0.0
	var sensor_range_wu: float = 0.0
	## Something counts as moving for a peripheral cue above this speed.
	var motion_min_speed_wu_s: float = 0.0
	var cue_cooldown_s: float = 0.0
	## How often the broad scan runs; things within close_check_range_wu, and things already being tracked, are checked
	## every tick.
	var broad_query_hz: float = 0.0
	var close_check_range_wu: float = 0.0
	## Exposure survives a break in sight this short (a flicker of cover) and no longer.
	var exposure_grace_s: float = 0.0
	## Seconds a lost contact's confidence takes to fall to nothing, and the mark with it.
	var memory_decay_s: float = 0.0
	## How fast Focus turns the body toward the camera's aim (deg/s), and how far it may tilt the gaze off the surface.
	var focus_turn_rate_deg_s: float = 0.0
	var gaze_pitch_limit_deg: float = 0.0
	## Contact association (A-027), the rule that decides whether something seen again is a remembered contact. The speed bound is
	## the most the spider assumes anything it has seen can move while it is out of sight: the plausible region of a lost contact
	## grows by this much each second (or by the speed it was last seen moving at, if that was greater). The size ratio is how
	## much larger or smaller than the remembered thing the new thing may look and still be it.
	var contact_speed_bound_wu_s: float = 0.0
	var contact_size_ratio: float = 0.0
	var max_line_length_wu: float = 0.0
	var reel_speed_wu_s: float = 0.0
	var life_cycle_profile_id: String = ""  # empty when the JSON value is null
	var evidence_refs: PackedStringArray = PackedStringArray()


static func load_file(path: String) -> Profile:
	last_errors = PackedStringArray()
	if not FileAccess.file_exists(path):
		return _fail(path, PackedStringArray(["file not found"]))
	return parse_text(FileAccess.get_file_as_string(path), path)


static func parse_text(text: String, source: String = "<text>") -> Profile:
	last_errors = PackedStringArray()
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail(source, PackedStringArray(["invalid JSON, line %d: %s" % [json.get_error_line(), json.get_error_message()]]))
	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail(source, PackedStringArray(["top level must be a JSON object"]))
	var d: Dictionary = json.data
	var errors := PackedStringArray()
	var p := Profile.new()
	p.schema_version = int(_num(d, "schema_version", errors, float(SUPPORTED_SCHEMA_VERSION), float(SUPPORTED_SCHEMA_VERSION), true))
	p.id = _str(d, "id", errors)
	p.biological_status = _str(d, "biological_status", errors)
	p.body_length_wu = _num(d, "body_length_wu", errors, POSITIVE, 1000.0)
	p.walk_speed_wu_s = _num(d, "locomotion.walk_speed_wu_s", errors, POSITIVE, 1000.0)
	p.stalk_speed_wu_s = _num(d, "locomotion.stalk_speed_wu_s", errors, POSITIVE, 1000.0)
	p.gravity_wu_s2 = _num(d, "locomotion.gravity_wu_s2", errors, POSITIVE, 100000.0)
	p.max_launch_speed_wu_s = _num(d, "locomotion.max_launch_speed_wu_s", errors, POSITIVE, 1000.0)
	p.flight_time_min_s = _num(d, "locomotion.flight_time_min_s", errors, POSITIVE, 60.0)
	p.flight_time_max_s = _num(d, "locomotion.flight_time_max_s", errors, POSITIVE, 60.0)
	p.inspect_cone_degrees = _num(d, "perception.inspect_cone_degrees", errors, POSITIVE, 180.0)
	p.easy_target_inspection_s = _num(d, "perception.easy_target_inspection_s", errors, POSITIVE, 60.0)
	p.fly_like_inspection_s = _num(d, "perception.fly_like_inspection_s", errors, POSITIVE, 60.0)
	p.easy_apparent_size_deg = _num(d, "perception.easy_apparent_size_deg", errors, POSITIVE, 90.0)
	p.min_apparent_size_deg = _num(d, "perception.min_apparent_size_deg", errors, POSITIVE, 90.0)
	p.peripheral_cone_degrees = _num(d, "perception.peripheral_cone_degrees", errors, POSITIVE, 360.0)
	p.peripheral_sector_degrees = _num(d, "perception.peripheral_sector_degrees", errors, 1.0, 180.0)
	p.sensor_range_wu = _num(d, "perception.sensor_range_wu", errors, POSITIVE, 1000.0)
	p.motion_min_speed_wu_s = _num(d, "perception.motion_min_speed_wu_s", errors, POSITIVE, 1000.0)
	p.cue_cooldown_s = _num(d, "perception.cue_cooldown_s", errors, POSITIVE, 60.0)
	p.broad_query_hz = _num(d, "perception.broad_query_hz", errors, 1.0, 120.0)
	p.close_check_range_wu = _num(d, "perception.close_check_range_wu", errors, 0.0, 1000.0)
	p.exposure_grace_s = _num(d, "perception.exposure_grace_s", errors, 0.0, 5.0)
	p.memory_decay_s = _num(d, "perception.memory_decay_s", errors, POSITIVE, 600.0)
	p.focus_turn_rate_deg_s = _num(d, "perception.focus_turn_rate_deg_s", errors, 1.0, 3600.0)
	p.gaze_pitch_limit_deg = _num(d, "perception.gaze_pitch_limit_deg", errors, 0.0, 85.0)
	p.contact_speed_bound_wu_s = _num(d, "perception.contact_speed_bound_wu_s", errors, POSITIVE, 1000.0)
	p.contact_size_ratio = _num(d, "perception.contact_size_ratio", errors, 1.0, 10.0)
	p.max_line_length_wu = _num(d, "silk.max_line_length_wu", errors, POSITIVE, 1000.0)
	p.reel_speed_wu_s = _num(d, "silk.reel_speed_wu_s", errors, POSITIVE, 1000.0)
	p.life_cycle_profile_id = _str_or_null(d, "life_cycle_profile_id", errors)
	p.evidence_refs = _str_array(d, "evidence_refs", errors)
	if errors.is_empty():
		if p.stalk_speed_wu_s > p.walk_speed_wu_s:
			errors.append("locomotion.stalk_speed_wu_s must not exceed walk_speed_wu_s")
		if p.flight_time_max_s < p.flight_time_min_s:
			errors.append("locomotion.flight_time_max_s must not be below flight_time_min_s")
		if p.fly_like_inspection_s < p.easy_target_inspection_s:
			errors.append("perception.fly_like_inspection_s must not be below easy_target_inspection_s")
		if p.min_apparent_size_deg > p.easy_apparent_size_deg:
			errors.append("perception.min_apparent_size_deg must not exceed easy_apparent_size_deg")
		if p.peripheral_cone_degrees < p.inspect_cone_degrees:
			errors.append("perception.peripheral_cone_degrees must not be below inspect_cone_degrees")
	if not errors.is_empty():
		return _fail(source, errors)
	return p


static func _fail(source: String, errors: PackedStringArray) -> Profile:
	last_errors = errors
	if not quiet:
		push_error("Species profile %s rejected: %s" % [source, "; ".join(errors)])
	return null


static func _find(d: Dictionary, path: String) -> Variant:
	var cur: Variant = d
	for part in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not (cur as Dictionary).has(part):
			return MISSING
		cur = (cur as Dictionary)[part]
	return cur


static func _num(d: Dictionary, path: String, errors: PackedStringArray, lo: float, hi: float, whole: bool = false) -> float:
	var v: Variant = _find(d, path)
	if typeof(v) == TYPE_STRING_NAME:
		errors.append("missing field '%s'" % path)
		return 0.0
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		errors.append("field '%s' must be a number" % path)
		return 0.0
	var f: float = v
	if not is_finite(f):
		errors.append("field '%s' must be finite" % path)
		return 0.0
	if f < lo or f > hi:
		errors.append("field '%s' = %s is outside the allowed range" % [path, str(f)])
		return 0.0
	if whole and f != floorf(f):
		errors.append("field '%s' must be a whole number" % path)
		return 0.0
	return f


static func _str(d: Dictionary, path: String, errors: PackedStringArray) -> String:
	var v: Variant = _find(d, path)
	if typeof(v) == TYPE_STRING_NAME:
		errors.append("missing field '%s'" % path)
		return ""
	if typeof(v) != TYPE_STRING or (v as String).is_empty():
		errors.append("field '%s' must be a non-empty string" % path)
		return ""
	return v


static func _str_or_null(d: Dictionary, path: String, errors: PackedStringArray) -> String:
	var v: Variant = _find(d, path)
	if typeof(v) == TYPE_STRING_NAME:
		errors.append("missing field '%s'" % path)
		return ""
	if v == null:
		return ""
	if typeof(v) != TYPE_STRING:
		errors.append("field '%s' must be a string or null" % path)
		return ""
	return v


static func _str_array(d: Dictionary, path: String, errors: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var v: Variant = _find(d, path)
	if typeof(v) == TYPE_STRING_NAME:
		errors.append("missing field '%s'" % path)
		return out
	if typeof(v) != TYPE_ARRAY:
		errors.append("field '%s' must be an array of strings" % path)
		return out
	for item: Variant in v:
		if typeof(item) != TYPE_STRING:
			errors.append("field '%s' must contain only strings" % path)
			return PackedStringArray()
		out.append(item)
	return out
