extends RefCounted
## Validating loader for the fly archetype's data (spec 8, 21: "unknown required fields or invalid units fail validation with a
## useful error"). Like the species profile it fails loudly: every problem found is reported and the loader returns null. Unlike it,
## it also rejects fields it does not know, so a misspelt tuning value cannot silently keep its default.
##
## Every number the fly's behaviour depends on lives here, as data that the debug view can show: how far it sees and how it weighs
## what it sees (senses), how long it takes to react (reaction, in seconds, drawn from the seeded prey stream), how it flies
## (flight), how it spends its time (behavior) and how it weighs goals (utility). They are designed values for a prototype, not
## measurements of any animal; "fly-like" is a behaviour, not a species (spec 8.1).
##   const PreyProfile = preload("res://scripts/prey/prey_profile.gd")
##   var profile = PreyProfile.load_file(path)

const SUPPORTED_SCHEMA_VERSION := 1
const POSITIVE := 0.000001
const MISSING := &"__missing__"

## Problems found by the most recent load.
static var last_errors: PackedStringArray = PackedStringArray()
## Test switch: when true, errors are recorded in last_errors but not pushed to the engine log.
static var quiet: bool = false

## section -> field -> [kind, lo, hi]; kind "f" is a number in [lo, hi], "p" a pair [low, high] of numbers in [lo, hi] with low <= high,
## "i" a whole number in [lo, hi]. The field name is also the name of the member of Profile that holds it (so it is unique).
const SCHEMA := {
	"body": {
		"radius_wu": ["f", 0.01, 5.0], "length_wu": ["f", 0.05, 10.0], "hover_wu": ["f", 0.01, 2.0],
		"capture_radius_wu": ["f", 0.05, 5.0], "nutrition": ["f", 0.01, 1.0], "capture_assist_scale": ["f", 1.0, 4.0], "feed_rate_per_s": ["f", 0.005, 10.0],
	},
	"senses": {
		"sight_range_wu": ["f", 1.0, 200.0], "full_sensitivity_wu": ["f", 0.1, 100.0],
		"front_half_deg": ["f", 10.0, 180.0], "rear_half_deg": ["f", 10.0, 180.0], "rear_gain": ["f", 0.0, 1.0],
		"motion_threshold_deg_s": ["f", 0.0, 1000.0], "motion_scale_deg_s": ["f", 0.1, 1000.0], "loom_scale_deg_s": ["f", 0.0, 1000.0],
		"appear_motion_deg_s": ["f", 0.0, 1000.0], "appear_range_wu": ["f", 0.0, 200.0], "sample_gap_max_s": ["f", 0.02, 5.0],
		"near_check_range_wu": ["f", 0.0, 200.0], "far_check_hz": ["f", 1.0, 120.0],
		"awareness_alert": ["f", 0.01, 5.0], "awareness_calm": ["f", 0.0, 5.0], "awareness_flee": ["f", 0.01, 5.0], "awareness_max": ["f", 0.01, 10.0],
		"decay_relaxed_per_s": ["f", 0.0, 10.0], "decay_alert_per_s": ["f", 0.0, 10.0],
		"unseen_decay_mult": ["f", 1.0, 50.0], "threat_memory_s": ["f", 0.5, 60.0],
		"vigilance_grooming": ["f", 0.0, 10.0], "vigilance_relaxed": ["f", 0.0, 10.0], "vigilance_alert": ["f", 0.0, 10.0],
		"startle_motion_deg_s": ["f", 1.0, 5000.0], "startle_range_wu": ["f", 0.1, 200.0], "startle_rear_gain": ["f", 0.0, 1.0],
	},
	"reaction": {
		"delay_startle_alert_s": ["p", 0.0, 5.0], "delay_startle_relaxed_s": ["p", 0.0, 5.0],
		"delay_startle_grooming_s": ["p", 0.0, 5.0], "delay_deliberate_s": ["p", 0.0, 5.0],
	},
	"flight": {
		"takeoff_accel_wu_s2": ["f", 1.0, 5000.0], "flee_speed_wu_s": ["f", 0.5, 500.0], "cruise_speed_wu_s": ["f", 0.5, 500.0],
		"landing_speed_wu_s": ["f", 0.1, 100.0], "landing_slow_wu": ["f", 0.1, 20.0], "turn_rate_deg_s": ["f", 10.0, 5000.0],
		"clearance_radius_wu": ["f", 0.01, 2.0], "lift_wu": ["f", 0.1, 10.0], "approach_wu": ["f", 0.1, 10.0],
		"min_hop_wu": ["f", 0.0, 100.0], "max_flight_wu": ["f", 1.0, 500.0], "takeoff_s": ["f", 0.02, 5.0],
		"flee_min_s": ["f", 0.0, 30.0], "safe_distance_wu": ["f", 0.0, 500.0], "perch_avoid_wu": ["f", 0.0, 100.0],
		"path_threat_clearance_wu": ["f", 0.0, 100.0], "cruise_accel_wu_s2": ["f", 1.0, 5000.0], "open_escape_wu": ["f", 0.5, 100.0],
	},
	"behavior": {
		"fidget_interval_s": ["p", 0.1, 600.0], "fidget_duration_s": ["p", 0.05, 10.0], "fidget_distance_wu": ["p", 0.0, 5.0],
		"perch_radius_wu": ["f", 0.0, 5.0], "groom_interval_s": ["p", 0.1, 600.0], "groom_duration_s": ["p", 0.1, 30.0],
		"alert_min_s": ["f", 0.0, 60.0], "min_commit_s": ["f", 0.0, 60.0], "hysteresis": ["f", 0.0, 5.0],
		"decision_hz": ["f", 1.0, 60.0], "restless_per_s": ["f", 0.0, 1.0], "restless_spread": ["f", 0.0, 0.95],
		"fatigue_up_per_s": ["f", 0.0, 5.0], "fatigue_down_per_s": ["f", 0.0, 5.0], "candidates_validated": ["i", 1.0, 32.0],
		"interrupt_threat": ["f", 0.0, 1.0], "block_retry_s": ["f", 0.0, 120.0], "reposition_max_wu": ["f", 0.5, 500.0],
		"glance_interval_s": ["p", 0.1, 60.0], "glance_angle_deg": ["p", 0.0, 180.0],
	},
	"population": {
		"replenish_delay_s": ["p", 0.1, 3600.0], "replenish_retry_s": ["f", 0.05, 60.0], "vent_view_margin_deg": ["f", 0.0, 90.0],
		"vent_min_distance_wu": ["f", 0.0, 500.0], "entry_min_flight_wu": ["f", 0.0, 500.0],
	},
	"utility": {
		"rest_base": ["f", 0.0, 5.0], "rest_fatigue": ["f", 0.0, 5.0], "rest_shelter": ["f", 0.0, 5.0], "rest_food": ["f", 0.0, 5.0],
		"rest_threat": ["f", 0.0, 5.0], "move_restless": ["f", 0.0, 5.0], "move_food": ["f", 0.0, 5.0], "move_shelter": ["f", 0.0, 5.0],
		"move_travel": ["f", 0.0, 5.0], "move_fatigue": ["f", 0.0, 5.0], "move_threat": ["f", 0.0, 5.0], "flee_threat": ["f", 0.0, 5.0],
		"flee_shelter": ["f", 0.0, 5.0], "flee_away": ["f", 0.0, 5.0], "flee_travel": ["f", 0.0, 5.0],
	},
}


class Profile extends RefCounted:
	var schema_version: int = 0
	var id: String = ""
	var biological_status: String = ""
	# body
	## The size of the sphere it presents to a sensor (its apparent size), WU.
	var radius_wu: float = 0.0
	var length_wu: float = 0.0
	## How far its body centre sits off the surface it perches on.
	var hover_wu: float = 0.0
	## The capture volume's radius about its body centre (the spider's own radius is added to it by the sweep).
	var capture_radius_wu: float = 0.0
	## The energy a whole fly restores, as a share of the spider's full reserve.
	var nutrition: float = 0.0
	var capture_assist_scale: float = 0.0
	var feed_rate_per_s: float = 0.0
	# senses (what the fly can know about the spider, and from it: visible angular motion, distance, line of sight)
	var sight_range_wu: float = 0.0
	var full_sensitivity_wu: float = 0.0
	var front_half_deg: float = 0.0
	var rear_half_deg: float = 0.0
	var rear_gain: float = 0.0
	var motion_threshold_deg_s: float = 0.0
	var motion_scale_deg_s: float = 0.0
	var loom_scale_deg_s: float = 0.0
	var appear_motion_deg_s: float = 0.0
	var appear_range_wu: float = 0.0
	var sample_gap_max_s: float = 0.0
	var near_check_range_wu: float = 0.0
	var far_check_hz: float = 0.0
	var awareness_alert: float = 0.0
	var awareness_calm: float = 0.0
	var awareness_flee: float = 0.0
	var awareness_max: float = 0.0
	var decay_relaxed_per_s: float = 0.0
	var decay_alert_per_s: float = 0.0
	var unseen_decay_mult: float = 0.0
	var threat_memory_s: float = 0.0
	var vigilance_grooming: float = 0.0
	var vigilance_relaxed: float = 0.0
	var vigilance_alert: float = 0.0
	var startle_motion_deg_s: float = 0.0
	var startle_range_wu: float = 0.0
	## T09b: how much a sudden big motion behind the fly still counts toward a startle (its rear view is poor for a slow creep, but a looming
	## leap is caught over a wide field). Ordinary awareness behind it uses rear_gain.
	var startle_rear_gain: float = 0.0
	# reaction delays, seconds, each a Vector2(low, high)
	var delay_startle_alert_s: Vector2 = Vector2.ZERO
	var delay_startle_relaxed_s: Vector2 = Vector2.ZERO
	var delay_startle_grooming_s: Vector2 = Vector2.ZERO
	var delay_deliberate_s: Vector2 = Vector2.ZERO
	# flight
	var takeoff_accel_wu_s2: float = 0.0
	var flee_speed_wu_s: float = 0.0
	var cruise_speed_wu_s: float = 0.0
	var landing_speed_wu_s: float = 0.0
	var landing_slow_wu: float = 0.0
	var turn_rate_deg_s: float = 0.0
	var clearance_radius_wu: float = 0.0
	var lift_wu: float = 0.0
	var approach_wu: float = 0.0
	var min_hop_wu: float = 0.0
	var max_flight_wu: float = 0.0
	var takeoff_s: float = 0.0
	var flee_min_s: float = 0.0
	var safe_distance_wu: float = 0.0
	var perch_avoid_wu: float = 0.0
	var path_threat_clearance_wu: float = 0.0
	var cruise_accel_wu_s2: float = 0.0
	var open_escape_wu: float = 0.0
	# behavior
	var fidget_interval_s: Vector2 = Vector2.ZERO
	var fidget_duration_s: Vector2 = Vector2.ZERO
	var fidget_distance_wu: Vector2 = Vector2.ZERO
	var perch_radius_wu: float = 0.0
	var groom_interval_s: Vector2 = Vector2.ZERO
	var groom_duration_s: Vector2 = Vector2.ZERO
	var alert_min_s: float = 0.0
	var min_commit_s: float = 0.0
	var hysteresis: float = 0.0
	var decision_hz: float = 0.0
	var restless_per_s: float = 0.0
	var restless_spread: float = 0.0
	var fatigue_up_per_s: float = 0.0
	var fatigue_down_per_s: float = 0.0
	var candidates_validated: int = 0
	var interrupt_threat: float = 0.0
	var block_retry_s: float = 0.0
	var reposition_max_wu: float = 0.0
	## T09b: a perched fly looks to and fro: a quick turn every glance_interval_s, alternately each side of the way it settled facing.
	var glance_interval_s: Vector2 = Vector2.ZERO
	var glance_angle_deg: Vector2 = Vector2.ZERO
	# population (the P0 replenishment rule, PreyPopulation)
	## How long after a fly leaves the living population its replacement falls due, seconds, drawn for each from the population's stream.
	var replenish_delay_s: Vector2 = Vector2.ZERO
	## How often a due replacement tries again while no vent is out of view and out of the spider's sight.
	var replenish_retry_s: float = 0.0
	## A vent must be this far outside the camera's view, degrees, on every side.
	var vent_view_margin_deg: float = 0.0
	## A vent must be at least this far from the spider.
	var vent_min_distance_wu: float = 0.0
	## A replacement flies at least this far from its vent to its first perch.
	var entry_min_flight_wu: float = 0.0
	# utility weights
	var rest_base: float = 0.0
	var rest_fatigue: float = 0.0
	var rest_shelter: float = 0.0
	var rest_food: float = 0.0
	var rest_threat: float = 0.0
	var move_restless: float = 0.0
	var move_food: float = 0.0
	var move_shelter: float = 0.0
	var move_travel: float = 0.0
	var move_fatigue: float = 0.0
	var move_threat: float = 0.0
	var flee_threat: float = 0.0
	var flee_shelter: float = 0.0
	var flee_away: float = 0.0
	var flee_travel: float = 0.0

	## The utility weights as the dictionary the selector's pure functions take.
	func weights() -> Dictionary:
		var out := {}
		for field: String in SCHEMA["utility"]:
			out[field] = get(field)
		return out

	## Every tunable value by section, for the debug view and the report.
	func describe_all() -> Dictionary:
		var out := {}
		for section: String in SCHEMA:
			var s := {}
			for field: String in SCHEMA[section]:
				s[field] = get(field)
			out[section] = s
		return out


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
	for key: Variant in d:
		if not (str(key) in ["schema_version", "id", "biological_status"] or SCHEMA.has(str(key))):
			errors.append("unknown field '%s'" % str(key))
	p.schema_version = int(_num(d, ["schema_version"], errors, float(SUPPORTED_SCHEMA_VERSION), float(SUPPORTED_SCHEMA_VERSION), true))
	p.id = _str(d, "id", errors)
	p.biological_status = _str(d, "biological_status", errors)
	for section: String in SCHEMA:
		var sec: Variant = d.get(section)
		if typeof(sec) != TYPE_DICTIONARY:
			errors.append("missing section '%s'" % section)
			continue
		for key: Variant in (sec as Dictionary):
			if not (SCHEMA[section] as Dictionary).has(str(key)):
				errors.append("unknown field '%s.%s'" % [section, str(key)])
		for field: String in SCHEMA[section]:
			var spec: Array = SCHEMA[section][field]
			var path := [section, field]
			match str(spec[0]):
				"f":
					p.set(field, _num(d, path, errors, float(spec[1]), float(spec[2])))
				"i":
					p.set(field, int(_num(d, path, errors, float(spec[1]), float(spec[2]), true)))
				"p":
					p.set(field, _pair(d, path, errors, float(spec[1]), float(spec[2])))
	if errors.is_empty():
		_relations(p, errors)
	if not errors.is_empty():
		return _fail(source, errors)
	return p


## The relations between values that make the set coherent.
static func _relations(p: Profile, errors: PackedStringArray) -> void:
	if not (p.awareness_calm < p.awareness_alert and p.awareness_alert < p.awareness_flee and p.awareness_flee <= p.awareness_max):
		errors.append("senses: awareness_calm < awareness_alert < awareness_flee <= awareness_max must hold")
	if p.rear_half_deg < p.front_half_deg:
		errors.append("senses.rear_half_deg must not be below front_half_deg")
	if p.startle_range_wu > p.sight_range_wu:
		errors.append("senses.startle_range_wu must not exceed sight_range_wu")
	if p.near_check_range_wu > p.sight_range_wu:
		errors.append("senses.near_check_range_wu must not exceed sight_range_wu")
	if p.full_sensitivity_wu >= p.sight_range_wu:
		errors.append("senses.full_sensitivity_wu must be below sight_range_wu")
	if p.cruise_speed_wu_s > p.flee_speed_wu_s:
		errors.append("flight.cruise_speed_wu_s must not exceed flee_speed_wu_s")
	if p.landing_speed_wu_s > p.cruise_speed_wu_s:
		errors.append("flight.landing_speed_wu_s must not exceed cruise_speed_wu_s")
	if p.clearance_radius_wu >= p.hover_wu:
		errors.append("flight.clearance_radius_wu must be below body.hover_wu, or a perched fly would be inside its own perch")
	if p.min_hop_wu >= p.max_flight_wu:
		errors.append("flight.min_hop_wu must be below max_flight_wu")
	if p.vigilance_grooming > p.vigilance_relaxed or p.vigilance_relaxed > p.vigilance_alert:
		errors.append("senses: vigilance must not fall as the fly gets more alert (grooming <= relaxed <= alert)")


static func _fail(source: String, errors: PackedStringArray) -> Profile:
	last_errors = errors
	if not quiet:
		push_error("Prey profile %s rejected: %s" % [source, "; ".join(errors)])
	return null


static func _find(d: Dictionary, path: Array) -> Variant:
	var cur: Variant = d
	for part: Variant in path:
		if typeof(cur) != TYPE_DICTIONARY or not (cur as Dictionary).has(part):
			return MISSING
		cur = (cur as Dictionary)[part]
	return cur


static func _name(path: Array) -> String:
	return ".".join(PackedStringArray(path))


static func _num(d: Dictionary, path: Array, errors: PackedStringArray, lo: float, hi: float, whole: bool = false) -> float:
	var v: Variant = _find(d, path)
	if typeof(v) == TYPE_STRING_NAME:
		errors.append("missing field '%s'" % _name(path))
		return 0.0
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		errors.append("field '%s' must be a number" % _name(path))
		return 0.0
	var f: float = v
	if not is_finite(f):
		errors.append("field '%s' must be finite" % _name(path))
		return 0.0
	if f < lo or f > hi:
		errors.append("field '%s' = %s is outside the allowed range" % [_name(path), str(f)])
		return 0.0
	if whole and f != floorf(f):
		errors.append("field '%s' must be a whole number" % _name(path))
		return 0.0
	return f


static func _pair(d: Dictionary, path: Array, errors: PackedStringArray, lo: float, hi: float) -> Vector2:
	var v: Variant = _find(d, path)
	if typeof(v) == TYPE_STRING_NAME:
		errors.append("missing field '%s'" % _name(path))
		return Vector2.ZERO
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != 2:
		errors.append("field '%s' must be a pair [low, high]" % _name(path))
		return Vector2.ZERO
	var out := Vector2.ZERO
	for i in 2:
		var x: Variant = (v as Array)[i]
		if (typeof(x) != TYPE_FLOAT and typeof(x) != TYPE_INT) or not is_finite(float(x)):
			errors.append("field '%s' must hold two finite numbers" % _name(path))
			return Vector2.ZERO
		if float(x) < lo or float(x) > hi:
			errors.append("field '%s' = %s is outside the allowed range" % [_name(path), str(x)])
			return Vector2.ZERO
		out[i] = float(x)
	if out.x > out.y:
		errors.append("field '%s' must be ordered [low, high]" % _name(path))
		return Vector2.ZERO
	return out


static func _str(d: Dictionary, key: String, errors: PackedStringArray) -> String:
	var v: Variant = d.get(key, MISSING)
	if typeof(v) == TYPE_STRING_NAME:
		errors.append("missing field '%s'" % key)
		return ""
	if typeof(v) != TYPE_STRING or (v as String).is_empty():
		errors.append("field '%s' must be a non-empty string" % key)
		return ""
	return v
