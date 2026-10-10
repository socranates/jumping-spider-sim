extends "res://tests/test_case.gd"
## The Observation record (spec 21.3): observer, target only when resolved, estimated position, modality, confidence in
## [0, 1], observed tick, category. Invalid records are described, and the memory refuses them.

const Observation = preload("res://scripts/perception/observation.gd")


func _inspection() -> Observation:
	var o := Observation.new()
	o.observer_id = "spider"
	o.track_id = "trk_1"
	o.modality = Observation.INSPECTION
	o.has_position = true
	o.estimated_position = Vector3(1.0, 2.0, 3.0)
	o.direction = Vector3.FORWARD
	o.confidence = 0.6
	o.observed_tick = 120
	o.category = Observation.POSSIBLE_PREY
	return o


func _cue() -> Observation:
	var o := Observation.new()
	o.observer_id = "spider"
	o.track_id = "trk_2"
	o.modality = Observation.PERIPHERAL
	o.direction = Vector3.LEFT
	o.confidence = 0.2
	o.observed_tick = 30
	return o


func test_good_records_have_no_problems() -> void:
	check(_inspection().is_valid(), "an inspection: %s" % str(_inspection().problems()))
	check(_cue().is_valid(), "a peripheral cue: %s" % str(_cue().problems()))


func test_each_rule_of_the_record_is_checked() -> void:
	var cases := {
		"no observer": func(o: Observation) -> void: o.observer_id = "",
		"no track": func(o: Observation) -> void: o.track_id = "",
		"unknown modality": func(o: Observation) -> void: o.modality = &"telepathy",
		"unknown category": func(o: Observation) -> void: o.category = &"housefly",
		"confidence above 1": func(o: Observation) -> void: o.confidence = 1.2,
		"negative confidence": func(o: Observation) -> void: o.confidence = -0.1,
		"nan confidence": func(o: Observation) -> void: o.confidence = NAN,
		"negative tick": func(o: Observation) -> void: o.observed_tick = -1,
		"direction not a unit vector": func(o: Observation) -> void: o.direction = Vector3(2.0, 0.0, 0.0),
		"infinite position": func(o: Observation) -> void: o.estimated_position = Vector3(INF, 0.0, 0.0),
		"an inspection without a position": func(o: Observation) -> void: o.has_position = false,
		"a negative speed": func(o: Observation) -> void: o.speed_wu_s = -0.5,
		"an infinite speed": func(o: Observation) -> void: o.speed_wu_s = INF,
	}
	for label: String in cases:
		var o := _inspection()
		cases[label].call(o)
		check(not o.is_valid(), "refused: " + label)
		check(not o.problems().is_empty(), "and described: " + label)


func test_a_peripheral_observation_carries_no_position_label_or_target() -> void:
	var o := _cue()
	o.has_position = true
	check(not o.is_valid(), "a cue with a position is refused")
	o = _cue()
	o.category = Observation.POSSIBLE_PREY
	check(not o.is_valid(), "a cue with a category beyond movement is refused")
	o = _cue()
	o.target_id = "test_target"
	check(not o.is_valid(), "a cue that resolved a target is refused")
	check_eq(_cue().to_dict()["estimated_position"], null, "and a cue's record has no position to read")
	check_eq(_inspection().to_dict()["estimated_position"], Vector3(1.0, 2.0, 3.0), "an inspection's has one")


func test_the_record_keeps_the_fields_of_the_spec() -> void:
	var d := _inspection().to_dict()
	for key in ["observer_id", "target_id", "estimated_position", "modality", "confidence", "observed_tick", "category"]:
		check(d.has(key), "spec 21.3 field: " + key)
	check_eq(d["observed_tick"], 120, "the tick is an integer action tick")
	check_eq(typeof(d["observed_tick"]), TYPE_INT, "of integer type")
