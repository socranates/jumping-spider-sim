extends "res://tests/test_case.gd"
## The fly archetype's data (chunk 7B): the shipped file loads, every field is required and checked, unknown fields are rejected, and the
## relations that make the numbers coherent are enforced. The loader fails loudly with a useful error and returns null.

const PreyProfile := preload("res://scripts/prey/prey_profile.gd")
const PATH := "res://data/species/fly_like_prototype.json"


func before_each() -> void:
	PreyProfile.quiet = true


func after_each() -> void:
	PreyProfile.quiet = false


func _shipped() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PATH))


func test_the_shipped_profile_loads_with_the_designed_numbers() -> void:
	var p = PreyProfile.load_file(PATH)
	check(p != null, "the file loads (%s)" % "; ".join(PreyProfile.last_errors))
	if p == null:
		return
	check_eq(p.id, "fly_like_prototype", "id")
	check(p.biological_status.contains("no_species_claim"), "it makes no species claim")
	check_near(p.capture_radius_wu, 0.4, 1e-9, "capture radius")
	check_near(p.nutrition, 0.35, 1e-9, "a fly is worth about a third of the reserve")
	check(p.hover_wu > p.clearance_radius_wu, "a perched body is clear of its perch")
	check(p.awareness_calm < p.awareness_alert and p.awareness_alert < p.awareness_flee, "calm < alert < flee")
	check(p.delay_startle_alert_s.y < p.delay_startle_relaxed_s.y and p.delay_startle_relaxed_s.y < p.delay_startle_grooming_s.y + 1e-9, "an alert fly reacts faster than a relaxed one, and a grooming one slowest")
	check(p.cruise_speed_wu_s <= p.flee_speed_wu_s, "it flees faster than it cruises")
	check_eq(p.weights().size(), 15, "fifteen utility weights")
	check_eq(p.describe_all().size(), 7, "seven tunable sections")
	check(p.replenish_delay_s.x > 0.0 and p.replenish_delay_s.x < p.replenish_delay_s.y, "a replacement comes after a delay drawn from a range")
	check(p.vent_view_margin_deg > 0.0 and p.vent_min_distance_wu > 0.0 and p.entry_min_flight_wu > 0.0, "the vent rules have a view margin, a distance and a flight")
	check_eq(p.candidates_validated, 4, "a whole number field is an int")


func test_a_missing_file_is_rejected() -> void:
	check(PreyProfile.load_file("res://data/species/nope.json") == null, "no such file")
	check(PreyProfile.last_errors.size() == 1, "one error")


func test_every_field_is_required_and_named_when_missing() -> void:
	for section: String in PreyProfile.SCHEMA:
		for field: String in PreyProfile.SCHEMA[section]:
			var d := _shipped()
			(d[section] as Dictionary).erase(field)
			check(PreyProfile.parse_text(JSON.stringify(d)) == null, "%s.%s is required" % [section, field])
			check("; ".join(PreyProfile.last_errors).contains("%s.%s" % [section, field]), "and the error names %s.%s" % [section, field])
	var d2 := _shipped()
	d2.erase("senses")
	check(PreyProfile.parse_text(JSON.stringify(d2)) == null, "a missing section is rejected")
	check("; ".join(PreyProfile.last_errors).contains("senses"), "and named")
	for key in ["id", "biological_status", "schema_version"]:
		var d3 := _shipped()
		d3.erase(key)
		check(PreyProfile.parse_text(JSON.stringify(d3)) == null, "%s is required" % key)


func test_unknown_fields_are_rejected() -> void:
	var d := _shipped()
	d["senses"]["sight_range_wu_typo"] = 3.0
	check(PreyProfile.parse_text(JSON.stringify(d)) == null, "a misspelt tuning value does not quietly keep a default")
	check("; ".join(PreyProfile.last_errors).contains("sight_range_wu_typo"), "and it is named")
	var d2 := _shipped()
	d2["extra_section"] = {}
	check(PreyProfile.parse_text(JSON.stringify(d2)) == null, "an unknown section is rejected")


func test_wrong_types_and_out_of_range_values_are_rejected() -> void:
	var d := _shipped()
	d["body"]["radius_wu"] = "big"
	check(PreyProfile.parse_text(JSON.stringify(d)) == null, "a string for a number")
	var d2 := _shipped()
	d2["body"]["nutrition"] = 4.0
	check(PreyProfile.parse_text(JSON.stringify(d2)) == null, "a nutrition above the whole reserve")
	var d3 := _shipped()
	d3["reaction"]["delay_deliberate_s"] = [0.3, 0.1]
	check(PreyProfile.parse_text(JSON.stringify(d3)) == null, "a pair out of order")
	var d4 := _shipped()
	d4["reaction"]["delay_deliberate_s"] = [0.1]
	check(PreyProfile.parse_text(JSON.stringify(d4)) == null, "a pair of one")
	var d5 := _shipped()
	d5["behavior"]["candidates_validated"] = 2.5
	check(PreyProfile.parse_text(JSON.stringify(d5)) == null, "a whole number field with a fraction")
	var d6 := _shipped()
	d6["schema_version"] = 2
	check(PreyProfile.parse_text(JSON.stringify(d6)) == null, "an unsupported schema version")
	check(PreyProfile.parse_text("{ not json") == null, "malformed JSON")
	check(PreyProfile.parse_text("[1, 2]") == null, "not an object")


func test_the_relations_between_values_are_enforced() -> void:
	var d := _shipped()
	d["senses"]["awareness_alert"] = 0.05
	check(PreyProfile.parse_text(JSON.stringify(d)) == null, "alert below calm")
	var d2 := _shipped()
	d2["flight"]["cruise_speed_wu_s"] = 40.0
	check(PreyProfile.parse_text(JSON.stringify(d2)) == null, "cruising faster than fleeing")
	var d3 := _shipped()
	d3["flight"]["clearance_radius_wu"] = 0.5
	check(PreyProfile.parse_text(JSON.stringify(d3)) == null, "a body that would sit inside its own perch")
	var d4 := _shipped()
	d4["senses"]["vigilance_grooming"] = 3.0
	check(PreyProfile.parse_text(JSON.stringify(d4)) == null, "more vigilant while grooming than while alert")
	var d5 := _shipped()
	d5["senses"]["startle_range_wu"] = 50.0
	check(PreyProfile.parse_text(JSON.stringify(d5)) == null, "startled by something it cannot see")
