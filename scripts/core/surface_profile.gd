extends RefCounted
## Validating loader for surface profiles (spec 21.2) and the rule for which surfaces can hold the
## spider. Fails loudly like the species profile loader: every problem found is reported with
## push_error and nothing loads.
##   const SurfaceProfile = preload("res://scripts/core/surface_profile.gd")
##   var registry: Dictionary = SurfaceProfile.load_dir()   # id -> Profile, empty on any error
##   SurfaceProfile.supports(registry.get(id), normal)

const SUPPORTED_SCHEMA_VERSION := 1
const DEFAULT_DIR := "res://data/surfaces"
## A surface whose normal is within this angle of world up holds the spider without adhesion.
const STAND_MAX_DEG := 45.0
const FIELDS := ["schema_version", "id", "attachable", "silk_anchor_allowed", "adhesion_multiplier", "vibration_group", "wetness_response_profile"]

## Problems found by the most recent load, for tests and callers that want the text.
static var last_errors: PackedStringArray = PackedStringArray()
## Test switch: when true, errors are recorded in last_errors but not pushed to the engine log.
static var quiet: bool = false


class Profile extends RefCounted:
	var schema_version: int = 0
	var id: String = ""
	var attachable: bool = false
	var silk_anchor_allowed: bool = false
	var adhesion_multiplier: float = 0.0
	var vibration_group: String = ""
	var wetness_response_profile: String = ""


## The eligibility rule: a surface can hold the spider if its profile is attachable, or if its
## normal is within STAND_MAX_DEG of world up (standing needs no adhesion). A missing profile
## counts as not attachable.
static func supports(profile: Profile, normal: Vector3) -> bool:
	if profile != null and profile.attachable:
		return true
	if not normal.is_finite() or normal.length_squared() < 1e-10:
		return false
	return normal.normalized().dot(Vector3.UP) >= cos(deg_to_rad(STAND_MAX_DEG)) - 1e-6


static func load_file(path: String) -> Profile:
	last_errors = PackedStringArray()
	if not FileAccess.file_exists(path):
		return _fail(path, PackedStringArray(["file not found"]))
	var p := parse_text(FileAccess.get_file_as_string(path), path)
	if p != null and p.id != path.get_file().get_basename():
		return _fail(path, PackedStringArray(["id '%s' does not match the file name" % p.id]))
	return p


## Loads every .json file in the folder. Returns {id: Profile}, or an empty dictionary when any
## file is invalid, two files share an id, or the folder holds no profiles.
static func load_dir(dir_path: String = DEFAULT_DIR) -> Dictionary:
	var errors := PackedStringArray()
	var out: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		errors.append("%s: folder not found" % dir_path)
	else:
		var files := Array(dir.get_files())
		files.sort()
		for f: String in files:
			if f.get_extension() != "json":
				continue
			var p := load_file(dir_path + "/" + f)
			if p == null:
				for e in last_errors:
					errors.append("%s: %s" % [f, e])
			elif out.has(p.id):
				errors.append("%s: duplicate id '%s'" % [f, p.id])
			else:
				out[p.id] = p
		if out.is_empty() and errors.is_empty():
			errors.append("%s: no surface profiles" % dir_path)
	last_errors = errors
	if not errors.is_empty():
		if not quiet:
			push_error("Surface profiles rejected: %s" % "; ".join(errors))
		return {}
	return out


static func parse_text(text: String, source: String = "<text>") -> Profile:
	last_errors = PackedStringArray()
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail(source, PackedStringArray(["invalid JSON, line %d: %s" % [json.get_error_line(), json.get_error_message()]]))
	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail(source, PackedStringArray(["top level must be a JSON object"]))
	var d: Dictionary = json.data
	var errors := PackedStringArray()
	for key: Variant in d.keys():
		if not FIELDS.has(str(key)):
			errors.append("unknown field '%s'" % str(key))
	var p := Profile.new()
	p.schema_version = int(_num(d, "schema_version", errors, SUPPORTED_SCHEMA_VERSION, SUPPORTED_SCHEMA_VERSION, true))
	p.id = _id(d, "id", errors)
	p.attachable = _bool(d, "attachable", errors)
	p.silk_anchor_allowed = _bool(d, "silk_anchor_allowed", errors)
	p.adhesion_multiplier = _num(d, "adhesion_multiplier", errors, 0.0, 10.0)
	p.vibration_group = _id(d, "vibration_group", errors)
	p.wetness_response_profile = _id(d, "wetness_response_profile", errors)
	if not errors.is_empty():
		return _fail(source, errors)
	return p


static func _fail(source: String, errors: PackedStringArray) -> Profile:
	last_errors = errors
	if not quiet:
		push_error("Surface profile %s rejected: %s" % [source, "; ".join(errors)])
	return null


static func _num(d: Dictionary, key: String, errors: PackedStringArray, lo: float, hi: float, whole: bool = false) -> float:
	if not d.has(key):
		errors.append("missing field '%s'" % key)
		return 0.0
	var v: Variant = d[key]
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		errors.append("field '%s' must be a number" % key)
		return 0.0
	var f: float = v
	if not is_finite(f):
		errors.append("field '%s' must be finite" % key)
		return 0.0
	if f < lo or f > hi:
		errors.append("field '%s' = %s is outside the allowed range" % [key, str(f)])
		return 0.0
	if whole and f != floorf(f):
		errors.append("field '%s' must be a whole number" % key)
		return 0.0
	return f


static func _bool(d: Dictionary, key: String, errors: PackedStringArray) -> bool:
	if not d.has(key):
		errors.append("missing field '%s'" % key)
		return false
	if typeof(d[key]) != TYPE_BOOL:
		errors.append("field '%s' must be true or false" % key)
		return false
	return d[key]


## A non-empty identifier: lower case letters, digits and underscores.
static func _id(d: Dictionary, key: String, errors: PackedStringArray) -> String:
	if not d.has(key):
		errors.append("missing field '%s'" % key)
		return ""
	var v: Variant = d[key]
	if typeof(v) != TYPE_STRING or (v as String).is_empty():
		errors.append("field '%s' must be a non-empty string" % key)
		return ""
	var s: String = v
	var re := RegEx.create_from_string("^[a-z0-9_]+$")
	if re.search(s) == null:
		errors.append("field '%s' = '%s' may only use a-z, 0-9 and _" % [key, s])
		return ""
	return s
