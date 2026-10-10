extends "res://tests/test_case.gd"
## Surface profiles (spec 21.2): the shipped files, validation, and the eligibility rule.

const SurfaceProfile = preload("res://scripts/core/surface_profile.gd")
const DIR := "res://data/surfaces"
const TMP := "user://jss_surface_profile_test"


func before_each() -> void:
	SurfaceProfile.quiet = true


func after_each() -> void:
	SurfaceProfile.quiet = false
	var d := DirAccess.open(TMP)
	if d != null:
		for f in d.get_files():
			d.remove(f)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _good() -> Dictionary:
	return {"schema_version": 1, "id": "test_surface", "attachable": true, "silk_anchor_allowed": true, "adhesion_multiplier": 1.0, "vibration_group": "test_group", "wetness_response_profile": "test_wet"}


func _errors_for(mutate: Callable) -> String:
	var d := _good()
	mutate.call(d)
	var p := SurfaceProfile.parse_text(JSON.stringify(d), "mutated")
	check(p == null, "the mutated profile is rejected")
	return "; ".join(SurfaceProfile.last_errors)


func test_shipped_profiles_load() -> void:
	var reg := SurfaceProfile.load_dir(DIR)
	check(reg.size() >= 9, "all lab surfaces load (%d)" % reg.size())
	for id in ["painted_wood_dry", "plaster_matte", "bare_wood_rough", "brick_rough", "varnished_wood_smooth", "painted_metal_smooth", "painted_ceiling", "glass_clean", "ptfe_coated"]:
		check(reg.has(id), "profile %s exists" % id)
	if reg.has("ptfe_coated"):
		check(not reg["ptfe_coated"].attachable, "the coated surface cannot be gripped")
	if reg.has("glass_clean"):
		check(reg["glass_clean"].attachable, "jumping spiders climb clean glass")
	if reg.has("plaster_matte"):
		check(reg["plaster_matte"].attachable, "plaster can be climbed")


func test_eligibility_rule() -> void:
	var grip := SurfaceProfile.parse_text(JSON.stringify(_good()))
	var d := _good()
	d["attachable"] = false
	var slick := SurfaceProfile.parse_text(JSON.stringify(d))
	for n in [Vector3.UP, Vector3.LEFT, Vector3.DOWN, Vector3(0.0, -0.7, 0.7).normalized()]:
		check(SurfaceProfile.supports(grip, n), "an attachable surface holds at %s" % str(n))
	check(SurfaceProfile.supports(slick, Vector3.UP), "a slick floor can be stood on")
	check(SurfaceProfile.supports(slick, Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(44.0))), "a slick 44 degree slope can be stood on")
	check(not SurfaceProfile.supports(slick, Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(46.0))), "a slick 46 degree slope cannot")
	check(not SurfaceProfile.supports(slick, Vector3.LEFT), "a slick wall cannot")
	check(not SurfaceProfile.supports(slick, Vector3.DOWN), "a slick underside cannot")
	check(SurfaceProfile.supports(null, Vector3.UP), "an unknown surface can still be stood on")
	check(not SurfaceProfile.supports(null, Vector3.BACK), "but not climbed")
	check(not SurfaceProfile.supports(slick, Vector3(NAN, 1.0, 0.0)), "a non-finite normal holds nothing")


func test_validation_names_the_problem() -> void:
	check("missing field 'attachable'" in _errors_for(func(d: Dictionary) -> void: d.erase("attachable")), "missing field")
	check("'attachable' must be true or false" in _errors_for(func(d: Dictionary) -> void: d["attachable"] = 1), "wrong type")
	check("'adhesion_multiplier'" in _errors_for(func(d: Dictionary) -> void: d["adhesion_multiplier"] = -0.5), "out of range")
	check("'adhesion_multiplier' must be a number" in _errors_for(func(d: Dictionary) -> void: d["adhesion_multiplier"] = "high"), "not a number")
	check("unknown field 'attachible'" in _errors_for(func(d: Dictionary) -> void: d["attachible"] = true), "a misspelt field is caught")
	check("'id'" in _errors_for(func(d: Dictionary) -> void: d["id"] = "Bad Id"), "ids are lower case with underscores")
	check("'schema_version'" in _errors_for(func(d: Dictionary) -> void: d["schema_version"] = 2), "unsupported schema version")
	check("'vibration_group' must be a non-empty string" in _errors_for(func(d: Dictionary) -> void: d["vibration_group"] = ""), "empty string")
	check(SurfaceProfile.parse_text("{ not json") == null and "invalid JSON" in "; ".join(SurfaceProfile.last_errors), "malformed JSON")
	check(SurfaceProfile.parse_text("[1, 2]") == null and "JSON object" in "; ".join(SurfaceProfile.last_errors), "top level must be an object")


func test_folder_loading_is_all_or_nothing() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	var a := _good()
	a["id"] = "one"
	_write("one.json", JSON.stringify(a))
	check_eq(SurfaceProfile.load_dir(TMP).size(), 1, "a valid folder loads")
	var b := _good()
	b["id"] = "two_wrong"
	_write("two.json", JSON.stringify(b))
	check(SurfaceProfile.load_dir(TMP).is_empty(), "an id that does not match its file name rejects the folder")
	check("does not match the file name" in "; ".join(SurfaceProfile.last_errors), "and says why")
	_write("two.json", JSON.stringify(a))
	check(SurfaceProfile.load_dir(TMP).is_empty(), "a duplicate id rejects the folder")
	check(SurfaceProfile.load_dir("user://jss_no_such_folder").is_empty(), "a missing folder loads nothing")


func _write(file_name: String, text: String) -> void:
	var f := FileAccess.open(TMP + "/" + file_name, FileAccess.WRITE)
	f.store_string(text)
	f.close()
