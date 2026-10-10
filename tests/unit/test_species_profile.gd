extends "res://tests/test_case.gd"

const SpeciesProfile = preload("res://scripts/core/species_profile.gd")
const PATH := "res://data/species/phidippus_audax_prototype.json"


func before_each() -> void:
	SpeciesProfile.quiet = true


func after_each() -> void:
	SpeciesProfile.quiet = false


func _good_dict() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PATH))


## Loads a mutated copy of the good profile and returns [profile, joined error text].
func _load_mutated(mutate: Callable) -> Array:
	var d := _good_dict()
	mutate.call(d)
	var p := SpeciesProfile.parse_text(JSON.stringify(d), "mutated")
	return [p, "; ".join(SpeciesProfile.last_errors)]


## Spec 21.1 values, except the jump and line tuning raised together in chunk 5 for farther jumps
## (Nathan's request): launch speed 14 -> 20 WU/s, longest flight 0.6 -> 0.9 s, line 8 -> 20 WU.
func test_shipped_profile_loads_with_spec_values() -> void:
	var p := SpeciesProfile.load_file(PATH)
	if not check(p != null, "the shipped species profile must load"):
		return
	check_eq(p.id, "phidippus_audax_prototype", "id")
	check_near(p.body_length_wu, 1.0, 1e-6, "body length")
	check_near(p.walk_speed_wu_s, 2.5, 1e-6, "walk speed")
	check_near(p.stalk_speed_wu_s, 0.8, 1e-6, "stalk speed")
	check_near(p.gravity_wu_s2, 35.0, 1e-6, "gravity")
	check_near(p.flight_time_min_s, 0.35, 1e-6, "flight time min")
	check_near(p.flight_time_max_s, 0.9, 1e-6, "flight time max (chunk 5)")
	check_near(p.max_launch_speed_wu_s, 20.0, 1e-6, "launch speed limit (chunk 5)")
	check_near(p.max_line_length_wu, 20.0, 1e-6, "safety line maximum (chunk 5)")
	check_near(p.reel_speed_wu_s, 1.5, 1e-6, "reel speed")
	check_eq(p.life_cycle_profile_id, "", "null life cycle id becomes empty")
	check_eq(p.evidence_refs.size(), 4, "evidence refs")


func test_missing_file_is_rejected() -> void:
	var p := SpeciesProfile.load_file("res://data/species/does_not_exist.json")
	check(p == null, "a missing file returns null")
	check(not SpeciesProfile.last_errors.is_empty(), "and records why")


func test_missing_field_is_rejected_and_named() -> void:
	var r := _load_mutated(func(d: Dictionary) -> void: d["locomotion"].erase("gravity_wu_s2"))
	check(r[0] == null, "missing gravity must be rejected")
	check("gravity_wu_s2" in r[1], "the error names the field: %s" % r[1])
	r = _load_mutated(func(d: Dictionary) -> void: d.erase("silk"))
	check(r[0] == null, "a missing section must be rejected")
	check("silk.max_line_length_wu" in r[1], "the error names the nested field: %s" % r[1])


func test_wrong_types_are_rejected() -> void:
	var cases := {
		"string for number": func(d: Dictionary) -> void: d["locomotion"]["walk_speed_wu_s"] = "fast",
		"bool for number": func(d: Dictionary) -> void: d["body_length_wu"] = true,
		"number for id": func(d: Dictionary) -> void: d["id"] = 7,
		"object for refs": func(d: Dictionary) -> void: d["evidence_refs"] = {"a": 1},
		"number in refs": func(d: Dictionary) -> void: d["evidence_refs"] = ["B1", 2],
		"number for life cycle id": func(d: Dictionary) -> void: d["life_cycle_profile_id"] = 3,
		"fractional schema version": func(d: Dictionary) -> void: d["schema_version"] = 1.5,
	}
	for label: String in cases:
		var r := _load_mutated(cases[label])
		check(r[0] == null, "wrong type rejected: " + label)


func test_non_finite_numbers_are_rejected() -> void:
	# JSON text cannot carry NaN or infinity, so exercise the number check directly.
	for bad in [NAN, INF, -INF]:
		var errors := PackedStringArray()
		SpeciesProfile._num({"x": bad}, "x", errors, 0.0, 10.0)
		check(errors.size() == 1 and "finite" in errors[0], "non-finite %s rejected: %s" % [str(bad), str(errors)])
	var ok_errors := PackedStringArray()
	check_near(SpeciesProfile._num({"x": 2.5}, "x", ok_errors, 0.0, 10.0), 2.5, 1e-9, "a finite number passes")
	check(ok_errors.is_empty(), "with no error")


func test_out_of_range_and_inconsistent_values_are_rejected() -> void:
	var cases := {
		"negative speed": func(d: Dictionary) -> void: d["locomotion"]["walk_speed_wu_s"] = -1.0,
		"zero gravity": func(d: Dictionary) -> void: d["locomotion"]["gravity_wu_s2"] = 0.0,
		"huge speed": func(d: Dictionary) -> void: d["locomotion"]["walk_speed_wu_s"] = 1.0e9,
		"stalk faster than walk": func(d: Dictionary) -> void: d["locomotion"]["stalk_speed_wu_s"] = 9.0,
		"flight times reversed": func(d: Dictionary) -> void: d["locomotion"]["flight_time_min_s"] = 1.2,
		"unsupported schema": func(d: Dictionary) -> void: d["schema_version"] = 2,
	}
	for label: String in cases:
		var m := _load_mutated(cases[label])
		check(m[0] == null, "rejected: " + label)


func test_malformed_json_is_rejected() -> void:
	for text in ["", "{", "[1, 2]", "not json", '{"schema_version": 1,']:
		check(SpeciesProfile.parse_text(text, "bad") == null, "malformed input rejected: '%s'" % text)


## Chunk 6B: the perception section of spec 21.1 grew the parameters the sensor and Focus use (gameplay numbers, not
## anatomical measurements). The spec's own two are unchanged: a 30 degree inspection cone and 0.4 s for an easy target.
func test_the_perception_section_loads_and_keeps_the_spec_numbers() -> void:
	var p := SpeciesProfile.load_file(PATH)
	if not check(p != null, "the shipped species profile must load"):
		return
	check_near(p.inspect_cone_degrees, 30.0, 1e-9, "inspection cone (spec 7)")
	check_near(p.easy_target_inspection_s, 0.4, 1e-9, "0.4 s to classify easy prey (spec 7)")
	check_near(p.cue_cooldown_s, 0.8, 1e-9, "0.8 s cue cooldown (spec 7)")
	check_near(p.broad_query_hz, 10.0, 1e-9, "broad sensory queries at 10 Hz (spec 20)")
	check(p.fly_like_inspection_s >= p.easy_target_inspection_s, "fly-like needs at least as long as possible prey (A-004)")
	check(p.peripheral_cone_degrees > p.inspect_cone_degrees, "the peripheral field is broader than the cone")
	check(p.min_apparent_size_deg <= p.easy_apparent_size_deg, "nothing is easier below the minimum size")
	check(p.memory_decay_s >= 3.0, "memory fades over several seconds (spec 7): %.1f" % p.memory_decay_s)
	check(p.focus_turn_rate_deg_s > 0.0 and p.focus_turn_rate_deg_s <= 360.0, "Focus turns at a capped rate (%.0f deg/s)" % p.focus_turn_rate_deg_s)
	check(p.gaze_pitch_limit_deg > 0.0 and p.gaze_pitch_limit_deg < 90.0, "the gaze tilts only so far (%.0f deg)" % p.gaze_pitch_limit_deg)
	# Chunk 7A (A-027): the association rule's numbers are data, not code.
	check_near(p.contact_speed_bound_wu_s, 2.0, 1e-9, "the speed any unseen thing is assumed able to move at (WU/s): about 2.5 times the test marker's pace")
	check_near(p.contact_size_ratio, 1.5, 1e-9, "how much bigger or smaller a thing may look and still be a remembered one")


func test_every_perception_field_is_required_and_checked() -> void:
	var fields := ["inspect_cone_degrees", "easy_target_inspection_s", "fly_like_inspection_s", "easy_apparent_size_deg", "min_apparent_size_deg",
		"peripheral_cone_degrees", "peripheral_sector_degrees", "sensor_range_wu", "motion_min_speed_wu_s", "cue_cooldown_s", "broad_query_hz",
		"close_check_range_wu", "exposure_grace_s", "memory_decay_s", "focus_turn_rate_deg_s", "gaze_pitch_limit_deg",
		"contact_speed_bound_wu_s", "contact_size_ratio"]
	for f: String in fields:
		var missing := _load_mutated(func(d: Dictionary) -> void: d["perception"].erase(f))
		check(missing[0] == null and ("perception." + f) in str(missing[1]), "missing %s is rejected and named" % f)
		var wrong := _load_mutated(func(d: Dictionary) -> void: d["perception"][f] = "wide")
		check(wrong[0] == null, "a string for %s is rejected" % f)
		var negative := _load_mutated(func(d: Dictionary) -> void: d["perception"][f] = -1.0)
		check(negative[0] == null, "a negative %s is rejected" % f)


func test_inconsistent_perception_values_are_rejected() -> void:
	var cases := {
		"fly-like faster than possible prey": func(d: Dictionary) -> void: d["perception"]["fly_like_inspection_s"] = 0.1,
		"minimum size above the easy size": func(d: Dictionary) -> void: d["perception"]["min_apparent_size_deg"] = 5.0,
		"peripheral field narrower than the cone": func(d: Dictionary) -> void: d["perception"]["peripheral_cone_degrees"] = 20.0,
		"a cone wider than a half turn": func(d: Dictionary) -> void: d["perception"]["inspect_cone_degrees"] = 200.0,
		"a gaze that tilts to straight up": func(d: Dictionary) -> void: d["perception"]["gaze_pitch_limit_deg"] = 90.0,
		"Focus that does not turn": func(d: Dictionary) -> void: d["perception"]["focus_turn_rate_deg_s"] = 0.0,
		"queries slower than once a second": func(d: Dictionary) -> void: d["perception"]["broad_query_hz"] = 0.5,
		"a size ratio under one": func(d: Dictionary) -> void: d["perception"]["contact_size_ratio"] = 0.9,
		"no speed bound": func(d: Dictionary) -> void: d["perception"]["contact_speed_bound_wu_s"] = 0.0,
	}
	for label: String in cases:
		var m := _load_mutated(cases[label])
		check(m[0] == null, "rejected: " + label)
