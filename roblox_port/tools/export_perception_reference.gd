extends SceneTree
## Exports perception golden values from the frozen Godot reference (c87ce00) for roblox_port/tests/perception_reference.json.
## Godot's own code runs, nothing is recomputed by the port:
##   * math, observation: PerceptionMath and Observation are called directly.
##   * sensor: the real SensorSystem bookkeeping and the real ObservationMemory are driven tick by tick through the same methods
##     _physics_process calls once it has sensed the world (_cue, _file_sightings, _check_spots, memory.advance, _forget_gone).
##     The world half is the only thing replaced: a scenario scripts what the eye found each tick (sightings, cues), which remembered
##     spots the world hides (_all_visible) and where the gaze points, so the decisions are checked apart from ray geometry (the
##     rays are the next part of the port).
## Run from the repo root:
##   godot --headless --path . -s roblox_port/tools/export_perception_reference.gd -- roblox_port/tests/perception_reference.json
## then, from roblox_port/:  python3 tools/reference_to_luau.py tests/perception_reference.json
const Observation = preload("res://scripts/perception/observation.gd")
const ObservationMemory = preload("res://scripts/perception/observation_memory.gd")
const PerceptionMath = preload("res://scripts/perception/perception_math.gd")
const SensorSystem = preload("res://scripts/perception/sensor_system.gd")
const SpeciesProfile = preload("res://scripts/core/species_profile.gd")

const DELTA := 1.0 / 60.0


## The sensor with the world half replaced: the spots in `blocked` are hidden from the eye (a cover in front of them).
class Rig extends SensorSystem:
	var blocked: Array = []

	func _all_visible(space: PhysicsDirectSpaceState3D, eye: Vector3, center: Vector3, radius: float, up: Vector3) -> bool:
		spot_checks_total += 1
		for b: Vector3 in blocked:
			if b.distance_to(center) < 0.01:
				return false
		return true


func _n(x: Variant) -> float:
	if x is String:
		return INF if x == "inf" else (-INF if x == "-inf" else NAN)
	return float(x)


func _v(a: Array) -> Vector3:
	return Vector3(_n(a[0]), _n(a[1]), _n(a[2]))


func _a(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## JSON has no infinity or NaN: they are written as the strings "inf", "-inf" and "nan".
func _out(x: Variant) -> Variant:
	if x is float:
		if is_inf(x):
			return "inf" if x > 0.0 else "-inf"
		if is_nan(x):
			return "nan"
		return x
	if x is Vector3:
		return _a(x)
	if x is StringName:
		return str(x)
	return x


func _rows(cases: Array, f: Callable) -> Array:
	var rows := []
	for c: Array in cases:
		rows.append({"in": c, "out": _out(f.callv(c))})
	return rows


func _init() -> void:
	var profile: SpeciesProfile.Profile = SpeciesProfile.load_file("res://data/species/phidippus_audax_prototype.json")
	var out := {
		"source": "Godot %s; scripts/perception, data/species and sim_clock last changed at 04697f6; frozen reference c87ce00; repository 61f2d49" % Engine.get_version_info()["string"],
		"parameters": {"species": profile.id, "hz": 60, "delta": DELTA, "eye": [0.0, 0.0, 0.0], "axis": [0.0, 0.0, -1.0], "up": [0.0, 1.0, 0.0], "forward": [0.0, 0.0, -1.0]},
		"tuning": _tuning(profile),
		"math": _math(),
		"observation": _observations(),
		"scenarios": [],
	}
	for sc: Dictionary in _scenarios():
		var r := _run(sc, profile)
		sc["events"] = r["events"]
		sc["expected"] = r["probes"]
		sc["counts"] = r["counts"]
		out["scenarios"].append(sc)
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", true, true))
	f.close()
	print("exported ", out["scenarios"].size(), " scenarios")
	quit()


# ------------------------------------------------------------------------------------------------ tuning

func _tuning(p: SpeciesProfile.Profile) -> Dictionary:
	var s := Rig.new()
	s.memory = ObservationMemory.new()
	s.configure_from(p)
	var t := {
		"inspect_cone_degrees": p.inspect_cone_degrees, "easy_target_inspection_s": p.easy_target_inspection_s,
		"fly_like_inspection_s": p.fly_like_inspection_s, "easy_apparent_size_deg": p.easy_apparent_size_deg,
		"min_apparent_size_deg": p.min_apparent_size_deg, "peripheral_cone_degrees": p.peripheral_cone_degrees,
		"peripheral_sector_degrees": p.peripheral_sector_degrees, "sensor_range_wu": p.sensor_range_wu,
		"motion_min_speed_wu_s": p.motion_min_speed_wu_s, "cue_cooldown_s": p.cue_cooldown_s, "broad_query_hz": p.broad_query_hz,
		"close_check_range_wu": p.close_check_range_wu, "exposure_grace_s": p.exposure_grace_s, "memory_decay_s": p.memory_decay_s,
		"contact_speed_bound_wu_s": p.contact_speed_bound_wu_s, "contact_size_ratio": p.contact_size_ratio,
		# what configure_from makes of the memory (apply_to_memory) and of the sensor
		"memory_hz": s.memory.hz, "memory_decay": s.memory.decay_s, "memory_hold_inspection_s": s.memory.hold_inspection_s,
		"memory_hold_peripheral_s": s.memory.hold_peripheral_s, "hold_ticks_inspection": s.memory.hold_ticks(Observation.INSPECTION),
		"hold_ticks_peripheral": s.memory.hold_ticks(Observation.PERIPHERAL), "reach_wu": s.reach_wu(),
	}
	s.free()
	return t


# ------------------------------------------------------------------------------------------------ math

func _math() -> Dictionary:
	var m := {}
	m["sight_tolerance"] = _rows([[0.01, 1.0], [0.1, 1.0], [0.45, 5.0], [5.0, 5.0], [0.0, 0.0], [-1.0, -1.0], [0.3, 40.0], [0.005, 60.0], [0.02, 0.5], [0.25, 8.0], [0.01, 0.0]],
		func(r: float, l: float) -> float: return PerceptionMath.sight_tolerance(r, l))
	m["plausible_radius"] = _rows([[0.5, 0.5, 0.0, 2.0, 0.0], [0.5, 0.5, 3.0, 2.0, 0.0], [0.5, 0.5, 3.0, 2.0, 5.0], [0.5, 0.5, -4.0, 2.0, 0.0], [0.4, 0.6, 1.5, 2.0, 0.8], [0.0, 0.0, 2.0, 2.0, 0.0], [0.9, 0.5, 0.25, 2.0, 1.9], [-1.0, 0.5, 1.0, 2.0, 0.0]],
		func(a: float, b: float, e: float, s: float, o: float) -> float: return PerceptionMath.plausible_radius(a, b, e, s, o))
	m["sizes_compatible"] = _rows([[0.5, 0.5, 1.5], [0.5, 0.74, 1.5], [0.74, 0.5, 1.5], [0.5, 0.8, 1.5], [0.8, 0.5, 1.5], [0.0, 0.9, 1.5], [0.9, 0.0, 1.5], [1.0, 1.0, 0.2], [0.5, 0.75, 1.5], [0.5, 0.76, 1.5], [0.5, 1.0, 2.0], [0.5, 1.0, 1.9]],
		func(a: float, b: float, r: float) -> bool: return PerceptionMath.sizes_compatible(a, b, r))
	var cats := ["movement", "possible_prey", "fly_like_prey", "nonsense"]
	var cc := []
	for a in cats:
		for b in cats:
			cc.append([a, b])
	m["categories_compatible"] = _rows(cc, func(a: String, b: String) -> bool: return PerceptionMath.categories_compatible(StringName(a), StringName(b)))
	m["rank"] = _rows([["movement"], ["possible_prey"], ["fly_like_prey"], ["nonsense"]], func(a: String) -> int: return Observation.rank(StringName(a)))
	m["angle_between"] = _rows([[[0, 0, -1], [1, 0, 0]], [[0, 0, 0], [1, 0, 0]], [[1, 0, 0], [1, 1, 0]], [[0, 0, -1], [0, 0, -1]], [[0, 0, -1], [0, 0, 1]], [[2, 0, 0], [0, 0.5, 0]], [[0, 0, -1], [0.001, 0, -1]], [[0, 0, -1], [0, 0, 0]], [[0.3, -0.8, 0.52], [-0.2, 0.4, 0.9]]],
		func(a: Array, b: Array) -> float: return PerceptionMath.angle_between(_v(a), _v(b)))
	var cone := []
	for deg in [0.0, 5.0, 14.9, 15.1, 15.5, 30.0, 90.0, 179.0]:
		cone.append([[0.0, 0.0, -1.0], _a(Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(deg))), deg_to_rad(15.0)])
	cone.append([[0.0, 0.0, -1.0], [0.0, 0.0, 0.0], deg_to_rad(15.0)])
	cone.append([[0.0, 0.0, -1.0], [1.0e-7, 0.0, -1.0e-7], deg_to_rad(15.0)])
	cone.append([[0.0, 1.0, 0.0], _a(Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(40.0))), deg_to_rad(45.0)])
	m["in_cone"] = _rows(cone, func(ax: Array, to: Array, h: float) -> bool: return PerceptionMath.in_cone(_v(ax), _v(to), h))
	m["apparent_size_deg"] = _rows([[1.0, 10.0], [0.9, 5.0], [1.0, 20.0], [1.0, 0.0], [1.0, 1.0e-7], [0.5, 8.0], [0.5, 40.0], [0.05, 40.0], [2.0, 0.5], [0.5, -3.0]],
		func(s: float, d: float) -> float: return PerceptionMath.apparent_size_deg(s, d))
	m["required_exposure"] = _rows([[0.4, 5.0, 3.0], [0.4, 3.0, 3.0], [0.4, 1.5, 3.0], [0.4, 0.0, 3.0], [1.0, 0.6, 3.0], [1.0, 1.0, 3.0], [0.4, -1.0, 3.0], [0.4, 2.9999, 3.0], [1.0, 1.4324, 3.0]],
		func(b: float, a: float, e: float) -> float: return PerceptionMath.required_exposure(b, a, e))
	var cl := []
	for e in [0.0, 0.39, 0.4, 0.9, 1.0, 5.0]:
		cl.append([e, 8.0, 0.4, 1.0, 3.0, 0.6])
	for e in [0.5, 0.79, 0.8, 1.9, 1.99, 2.0]:
		cl.append([e, 1.5, 0.4, 1.0, 3.0, 0.6])
	for e in [1.99, 2.0, 4.99, 5.0, 9.0]:
		cl.append([e, 0.6, 0.4, 1.0, 3.0, 0.6])
	cl.append([9.0, 0.5, 0.4, 1.0, 3.0, 0.6])
	cl.append([0.39999999999999997, 3.5, 0.4, 1.0, 3.0, 0.6])
	cl.append([0.3999985, 3.5, 0.4, 1.0, 3.0, 0.6])
	cl.append([0.3999, 3.5, 0.4, 1.0, 3.0, 0.6])
	m["classify"] = _rows(cl, func(e: float, a: float, es: float, fs: float, ed: float, md: float) -> String: return str(PerceptionMath.classify(e, a, es, fs, ed, md)))
	m["inspection_confidence"] = _rows([[0.0, 1.0, 1.0], [0.5, 1.0, 1.0], [1.0, 1.0, 1.0], [1.0, 1.0, 0.2], [0.0, 1.0, 0.2], [5.0, 1.0, 1.0], [0.5, "inf", 1.0], [0.25, 2.0, 0.6], [0.3, 1.0, 1.5], [0.3, 1.0, -1.0], [0.3, 0.0, 1.0]],
		func(e: float, n: Variant, v: float) -> float: return PerceptionMath.inspection_confidence(e, _n(n), v))
	m["peripheral_confidence"] = _rows([[1.0, 40.0], [39.0, 40.0], [1000.0, 40.0], [20.0, 40.0], [0.0, 40.0], [5.0, 0.0], [8.485, 40.0]],
		func(d: float, r: float) -> float: return PerceptionMath.peripheral_confidence(d, r))
	var q := []
	for deg in [0.0, 5.0, 10.0, 11.0, 12.0, 30.0, 47.0, 90.0, -100.0, 140.0, -171.0, 179.0]:
		q.append([_a(Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(deg))), [0.0, 0.0, -1.0], [0.0, 1.0, 0.0], 22.5])
	for deg in [10.0, 28.0, 44.0, -28.0, -50.0, 80.0]:
		q.append([_a((Vector3.FORWARD + Vector3.UP * tan(deg_to_rad(deg))).normalized()), [0.0, 0.0, -1.0], [0.0, 1.0, 0.0], 22.5])
	var yawed := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(40.0))
	q.append([_a((yawed + Vector3.UP * tan(deg_to_rad(25.0))).normalized()), [0.0, 0.0, -1.0], [0.0, 1.0, 0.0], 22.5])
	q.append([_a(Vector3.UP), [0.0, 0.0, -1.0], [0.0, 1.0, 0.0], 22.5])
	q.append([_a(Vector3.DOWN), [0.0, 0.0, -1.0], [0.0, 1.0, 0.0], 22.5])
	q.append([_a(Vector3.UP), [0.0, 1.0, 0.0], [0.0, 1.0, 0.0], 22.5])
	q.append([_a(Vector3(0.3, 0.2, -0.9).normalized()), [0.0, 1.0, 0.0], [0.0, 1.0, 0.0], 22.5])
	q.append([_a(Vector3(0.3, -0.8, 0.5).normalized()), [0.0, -1.0, 0.0], [1.0, 0.0, 0.0], 22.5])
	q.append([_a(Vector3(-0.6, 0.1, 0.2).normalized()), [0.0, 0.0, 1.0], [-1.0, 0.0, 0.0], 45.0])
	q.append([_a(Vector3(0.4, 0.1, -0.9).normalized()), [0.0, 0.0, -1.0], [0.0, 1.0, 0.0], 10.0])
	q.append([_a(Vector3(0.4, 0.1, -0.9).normalized()), [0.0, 0.0, -1.0], [0.0, 1.0, 0.0], 0.1])
	m["quantize_direction"] = _rows(q, func(d: Array, f: Array, u: Array, s: float) -> Vector3: return PerceptionMath.quantize_direction(_v(d), _v(f), _v(u), s))
	m["decayed_confidence"] = _rows([[0.8, 0.0, 6.0], [0.8, 3.0, 6.0], [0.8, 6.0, 6.0], [0.8, 60.0, 6.0], [0.8, 1.0, 0.0], [0.5, 1.5, 6.0], [0.8, -1.0, 6.0], [1.2, 0.0, 6.0], [0.8, 5.9833, 6.0]],
		func(c: float, a: float, d: float) -> float: return PerceptionMath.decayed_confidence(c, a, d))
	m["staleness"] = _rows([[0.0, 6.0], [1.5, 6.0], [7.0, 6.0], [3.0, 0.0], [-1.0, 6.0], [6.0, 6.0]],
		func(a: float, d: float) -> float: return PerceptionMath.staleness(a, d))
	return m


# ------------------------------------------------------------------------------------------------ observation

func _base_observation(kind: String) -> Observation:
	var o := Observation.new()
	o.observer_id = "spider"
	if kind == "inspection":
		o.track_id = "trk_1"
		o.modality = Observation.INSPECTION
		o.has_position = true
		o.estimated_position = Vector3(1.0, 2.0, 3.0)
		o.direction = Vector3.FORWARD
		o.confidence = 0.6
		o.observed_tick = 120
		o.category = Observation.POSSIBLE_PREY
	else:
		o.track_id = "trk_2"
		o.modality = Observation.PERIPHERAL
		o.direction = Vector3.LEFT
		o.confidence = 0.2
		o.observed_tick = 30
	return o


func _apply(o: Observation, fields: Dictionary) -> void:
	for k: String in fields:
		var v: Variant = fields[k]
		if v is Array:
			v = _v(v)
		elif v is String and (k == "modality" or k == "category"):
			v = StringName(v)
		elif v is String and k != "observer_id" and k != "track_id" and k != "target_id":
			v = _n(v)
		o.set(k, v)


func _observations() -> Array:
	var cases := [
		{"label": "a good inspection", "kind": "inspection", "set": {}},
		{"label": "a good peripheral cue", "kind": "cue", "set": {}},
		{"label": "no observer", "kind": "inspection", "set": {"observer_id": ""}},
		{"label": "no track", "kind": "inspection", "set": {"track_id": ""}},
		{"label": "unknown modality", "kind": "inspection", "set": {"modality": "telepathy"}},
		{"label": "unknown category", "kind": "inspection", "set": {"category": "housefly"}},
		{"label": "confidence above 1", "kind": "inspection", "set": {"confidence": 1.2}},
		{"label": "negative confidence", "kind": "inspection", "set": {"confidence": -0.1}},
		{"label": "nan confidence", "kind": "inspection", "set": {"confidence": "nan"}},
		{"label": "infinite confidence", "kind": "inspection", "set": {"confidence": "inf"}},
		{"label": "confidence exactly 1 and 0 are fine", "kind": "inspection", "set": {"confidence": 1.0}},
		{"label": "negative tick", "kind": "inspection", "set": {"observed_tick": -1}},
		{"label": "direction not a unit vector", "kind": "inspection", "set": {"direction": [2.0, 0.0, 0.0]}},
		{"label": "no direction at all", "kind": "inspection", "set": {"direction": [0.0, 0.0, 0.0]}},
		{"label": "direction within the unit tolerance", "kind": "inspection", "set": {"direction": [1.0005, 0.0, 0.0]}},
		{"label": "direction just outside the unit tolerance", "kind": "inspection", "set": {"direction": [1.002, 0.0, 0.0]}},
		{"label": "infinite position", "kind": "inspection", "set": {"estimated_position": ["inf", 0.0, 0.0]}},
		{"label": "nan position", "kind": "inspection", "set": {"estimated_position": [0.0, "nan", 0.0]}},
		{"label": "an inspection without a position", "kind": "inspection", "set": {"has_position": false}},
		{"label": "a negative speed", "kind": "inspection", "set": {"speed_wu_s": -0.5}},
		{"label": "an infinite speed", "kind": "inspection", "set": {"speed_wu_s": "inf"}},
		{"label": "a nan speed", "kind": "inspection", "set": {"speed_wu_s": "nan"}},
		{"label": "a cue with a position", "kind": "cue", "set": {"has_position": true}},
		{"label": "a cue with a category beyond movement", "kind": "cue", "set": {"category": "possible_prey"}},
		{"label": "a cue that resolved a target", "kind": "cue", "set": {"target_id": "test_target"}},
		{"label": "a cue with a label and a target", "kind": "cue", "set": {"category": "fly_like_prey", "target_id": "x"}},
		{"label": "an inspection that names a target is fine", "kind": "inspection", "set": {"target_id": "test_target", "category": "fly_like_prey"}},
		{"label": "several problems at once", "kind": "inspection", "set": {"observer_id": "", "track_id": "", "confidence": 2.0, "observed_tick": -5}},
	]
	var rows := []
	for c: Dictionary in cases:
		var o := _base_observation(c["kind"])
		_apply(o, c["set"])
		var d := o.to_dict()
		rows.append({"label": c["label"], "kind": c["kind"], "set": c["set"], "valid": o.is_valid(), "problems": Array(o.problems()),
			"dict_has_position": d["estimated_position"] != null})
	return rows


# ------------------------------------------------------------------------------------------------ sensor scenarios

func _ball(id: String, at: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "at": at, "radius": 0.25, "velocity": [0.8, 0.0, 0.0]}
	d.merge(extra, true)
	return d


func _sc(name: String, note: String, steps: Array, probes: Array) -> Dictionary:
	return {"name": name, "note": note, "steps": steps, "probes": probes}


func _scenarios() -> Array:
	var HERE := [0.0, 0.0, -8.0]            # straight ahead, 8 WU out: a ball of radius 0.25 looks 3.6 degrees across, an easy target
	var out := []
	out.append(_sc("timing_easy_target",
		"An easy target in the cone: movement, possible prey at 0.40 s (tick 24), fly-like at 1.00 s (tick 60). Sight ends at tick 90, the contact is lost on the 10th tick without evidence (100), its confidence falls in a straight line to nothing over 6 s and it is forgotten at tick 460. The world hides the spot meanwhile, so the mark is kept to the end.",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 380, "hidden": ["a"], "blocked": [HERE]}],
		[1, 2, 23, 24, 25, 59, 60, 61, 90, 99, 100, 101, 280, 459, 460, 461]))
	out.append(_sc("timing_small_target",
		"A target that looks half the easy size (1.4 degrees) needs twice as long: possible prey at about 0.84 s (tick 51), fly-like at about 2.09 s (tick 126).",
		[{"n": 140, "sight": [_ball("a", [0.0, 0.0, -20.0])]}],
		[50, 51, 52, 125, 126, 127, 140]))
	out.append(_sc("categories_are_capped_by_what_a_thing_can_look_like",
		"Two things watched together: one that can look like possible prey at best, one that is only ever movement. Neither is ever refined further; movement carries no world link.",
		[{"n": 90, "sight": [_ball("a", [-2.0, 0.0, -8.0], {"max_category": "possible_prey"}), _ball("b", [2.0, 0.0, -8.0], {"max_category": "movement"})]}],
		[23, 24, 60, 90]))
	out.append(_sc("a_short_break_does_not_reset_the_exposure",
		"Sight breaks for 5 ticks (0.083 s, under the 0.15 s grace) after 30: the exposure goes on, so fly-like comes after 60 ticks of sight, at tick 65.",
		[{"n": 30, "sight": [_ball("a", HERE)]}, {"n": 5, "hidden": ["a"]}, {"n": 40, "sight": [_ball("a", HERE)]}],
		[24, 30, 35, 36, 64, 65, 66, 75]))
	out.append(_sc("the_longest_break_that_keeps_the_contact",
		"Sight breaks for 8 ticks (0.133 s): the first sighting after it is 9 ticks after the last, still inside the memory's hold, so it is the same contact with the exposure it had (fly-like after 60 ticks of sight, at tick 68).",
		[{"n": 30, "sight": [_ball("a", HERE)]}, {"n": 8, "hidden": ["a"]}, {"n": 40, "sight": [_ball("a", HERE)]}],
		[24, 30, 38, 39, 67, 68, 69]))
	out.append(_sc("a_break_one_tick_longer_starts_a_new_contact",
		"Sight breaks for 9 ticks: the first sighting after it is 10 ticks after the last, past the hold, so unbroken sight is over: it is a fresh contact that starts again (possible prey at tick 63, 24 ticks on), and the old one is lost in the same tick.",
		[{"n": 30, "sight": [_ball("a", HERE)]}, {"n": 9, "hidden": ["a"]}, {"n": 40, "sight": [_ball("a", HERE)]}],
		[39, 40, 41, 62, 63, 64, 69]))
	out.append(_sc("a_lost_contact_found_again_keeps_what_the_memory_of_it_has_left",
		"Sight is lost after 30 ticks (the contact is lost at tick 40) and comes back at tick 51 in the same place: the same contact, and the exposure it had, faded as the memory of it has (familiarity), carries over.",
		[{"n": 30, "sight": [_ball("a", HERE)]}, {"n": 20, "hidden": ["a"], "blocked": [HERE]}, {"n": 60, "sight": [_ball("a", HERE)]}],
		[40, 41, 50, 51, 52, 80, 81, 82, 90, 110]))
	out.append(_sc("an_empty_spot_in_plain_view_drops_the_mark",
		"The thing is gone and the spot is in the cone, entirely in plain view and empty: after 0.40 s (24 ticks) of looking the mark is dropped (ended empty). Looking starts the tick after the loss (100).",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 60, "hidden": ["a"]}],
		[100, 101, 102, 123, 124, 125, 150]))
	out.append(_sc("a_spot_the_world_hides_cannot_be_called_empty",
		"The same, but a cover stands in front of the spot: it is never seen empty, so the mark stays, at the same place, for the 60 ticks watched.",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 60, "hidden": ["a"], "blocked": [HERE]}],
		[100, 101, 124, 125, 150]))
	out.append(_sc("a_spot_out_of_the_cone_is_not_inspected",
		"The same, but the gaze has turned away (the spot is 90 degrees off): nothing is inspected, so the mark stays.",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 60, "hidden": ["a"], "axis": [1.0, 0.0, 0.0]}],
		[100, 101, 124, 125, 150]))
	out.append(_sc("looking_at_the_spot_interrupted_briefly_goes_on",
		"The spot is looked at for 15 ticks, covered for 5 (under the grace), then looked at again: the 24 ticks are made up (mark dropped at tick 129).",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 25, "hidden": ["a"]}, {"n": 5, "hidden": ["a"], "blocked": [HERE]}, {"n": 30, "hidden": ["a"]}],
		[115, 116, 120, 121, 128, 129, 130]))
	out.append(_sc("looking_at_the_spot_interrupted_for_longer_starts_again",
		"Covered for 12 ticks (over the grace): the looking starts again, and the mark is dropped 24 ticks after the cover goes (tick 151).",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 25, "hidden": ["a"]}, {"n": 12, "hidden": ["a"], "blocked": [HERE]}, {"n": 40, "hidden": ["a"]}],
		[127, 128, 150, 151, 152]))
	out.append(_sc("seen_again_where_only_it_could_be_is_the_remembered_contact",
		"A thing with another world id (z) is sighted 1.4 WU from the mark after about a second (the region is 0.5 + 2 WU/s x 1.0 s = 2.5 WU): the one lost contact it fits, so it rejoins it: same contact, record updated, no new one.",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 60, "hidden": ["a"], "blocked": [HERE]}, {"n": 40, "sight": [_ball("z", [0.8, 0.0, -9.2])]}],
		[150, 151, 152, 170, 190]))
	out.append(_sc("seen_outside_the_region_is_a_fresh_contact",
		"The same world id (a) is sighted 16 WU from the mark: outside the region, so a fresh contact that starts at movement and carries no exposure. The old mark stays until the spot is seen empty.",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 60, "hidden": ["a"], "blocked": [HERE]}, {"n": 60, "sight": [_ball("a", [0.5, 0.0, -24.0])]}],
		[150, 151, 152, 173, 174, 175, 210]))
	out.append(_sc("a_similar_size_is_the_remembered_contact",
		"Back at the spot after 0.5 s but looking 1.48 times as big (size ratio at most 1.5): still the same contact.",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 30, "hidden": ["a"], "blocked": [HERE]}, {"n": 30, "sight": [_ball("a", HERE, {"radius": 0.37})]}],
		[120, 121, 122, 150]))
	out.append(_sc("a_different_size_is_a_fresh_contact",
		"The same but 1.6 times as big: too different, a fresh contact.",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 30, "hidden": ["a"], "blocked": [HERE]}, {"n": 30, "sight": [_ball("a", HERE, {"radius": 0.4})]}],
		[120, 121, 122, 150]))
	out.append(_sc("a_thing_that_can_only_look_like_movement_is_a_fresh_contact",
		"Back at the spot but a thing whose appearance can be refined no further than movement: what was learned (fly-like prey) cannot be finer than it can ever look, so a fresh contact.",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 30, "hidden": ["a"], "blocked": [HERE]}, {"n": 30, "sight": [_ball("a", HERE, {"max_category": "movement"})]}],
		[120, 121, 122, 150]))
	out.append(_sc("a_fast_walker_has_a_wider_region",
		"The thing was seen moving at 5 WU/s: 7 WU away after 1.5 s is inside the region (0.5 + 5 x 1.5 = 8.0 WU), so it is the same contact.",
		[{"n": 90, "sight": [_ball("a", HERE, {"velocity": [5.0, 0.0, 0.0]})]}, {"n": 90, "hidden": ["a"], "blocked": [HERE]}, {"n": 30, "sight": [_ball("z", [0.0, 0.0, -15.0])]}],
		[180, 181, 182, 210]))
	out.append(_sc("a_slow_walker_has_the_speed_bound_only",
		"The same but the thing was seen moving at 0.8 WU/s: the bound (2 WU/s) applies, the region is 3.5 WU, and 7 WU away is a fresh contact.",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 90, "hidden": ["a"], "blocked": [HERE]}, {"n": 30, "sight": [_ball("z", [0.0, 0.0, -15.0])]}],
		[180, 181, 182, 210]))
	var left := [-1.8, 0.0, -8.0]
	var right := [1.8, 0.0, -8.0]
	out.append(_sc("two_lost_contacts_one_newcomer_early_takes_the_one_it_fits",
		"Two look-alikes were lost, 3.6 WU apart; after 1.0 s a newcomer 0.3 WU from the left mark is inside the left region only (2.5 WU): it rejoins the left one.",
		[{"n": 90, "sight": [_ball("a", left), _ball("b", right)]}, {"n": 60, "hidden": ["a", "b"], "blocked": [left, right]}, {"n": 40, "sight": [_ball("z", [-1.5, 0.0, -8.0])]}],
		[150, 151, 152, 170, 190]))
	out.append(_sc("two_lost_contacts_one_newcomer_late_fits_both_so_is_a_stranger",
		"The same newcomer after 3.2 s: the region has grown to 6.9 WU and both lost contacts could be it, so it is a fresh contact and takes neither.",
		[{"n": 90, "sight": [_ball("a", left), _ball("b", right)]}, {"n": 190, "hidden": ["a", "b"], "blocked": [left, right]}, {"n": 40, "sight": [_ball("z", [-1.5, 0.0, -8.0])]}],
		[280, 281, 282, 300, 320]))
	for rev in [false, true]:
		var both := [_ball("z1", right), _ball("z2", left)]
		if rev:
			both.reverse()
		out.append(_sc("look_alikes_cross_and_come_out_as_strangers" + ("_listed_the_other_way_round" if rev else ""),
			"Two look-alikes cross behind cover and come out on each other's sides after 1.7 s: each could be either lost contact, so both are fresh contacts, whichever the sensor handles first. The order the world lists them in decides nothing.",
			[{"n": 90, "sight": [_ball("a", left), _ball("b", right)]}, {"n": 100, "hidden": ["a", "b"], "blocked": [left, right]}, {"n": 40, "sight": both}],
			[190, 191, 192, 215, 230]))
	out.append(_sc("a_thing_that_fits_one_place_alone_still_takes_it_while_a_stranger_is_in_view",
		"One lost contact. A newcomer 0.3 WU from the mark and a stranger far away are sighted in the same tick: the first is the only candidate and rejoins; the stranger is fresh.",
		[{"n": 90, "sight": [_ball("a", left)]}, {"n": 60, "hidden": ["a"], "blocked": [left]}, {"n": 40, "sight": [_ball("z1", [-1.5, 0.0, -8.0]), _ball("z2", [3.0, 0.0, -30.0])]}],
		[150, 151, 152, 190]))
	for rev in [false, true]:
		var pair := [_ball("z1", [-0.5, 0.0, -8.0]), _ball("z2", [0.5, 0.0, -8.0])]
		if rev:
			pair.reverse()
		out.append(_sc("a_place_two_newcomers_could_each_be_is_taken_by_neither" + ("_listed_the_other_way_round" if rev else ""),
			"One lost contact and two newcomers that each fit it, sighted in the same tick: it is taken by neither, both are fresh contacts, in whatever order they are listed.",
			[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 60, "hidden": ["a"], "blocked": [HERE]}, {"n": 40, "sight": pair}],
			[150, 151, 152, 190]))
	out.append(_sc("a_cue_never_joins_a_lost_contact_but_the_inspection_after_it_does",
		"After the loss a cue arrives (tick 131): a bare bearing, so a new weak contact. The inspection that follows (tick 136) is compared with the lost contacts, matches the one, and the cue-only contact is folded into it (ended merged).",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 40, "hidden": ["a"], "blocked": [HERE]}, {"n": 1, "cue": [{"id": "a", "at": [1.8, 0.0, -8.0]}], "blocked": [HERE]}, {"n": 4, "hidden": ["a"], "blocked": [HERE]}, {"n": 30, "sight": [_ball("a", [1.5, 0.0, -8.0])]}],
		[130, 131, 132, 135, 136, 137, 160]))
	out.append(_sc("cues_come_once_per_cooldown_and_a_cue_only_contact_has_no_mark",
		"A thing moving at the edge of the field gives a cue at most every 0.8 s (ticks 1, 49, 97); the contact made of bearings is held for 1.0 s after the last, is lost at tick 158 with no position and no mark, fades and is forgotten at tick 518.",
		[{"n": 100, "cue": [{"id": "a", "at": [6.0, 0.0, -6.0]}]}, {"n": 430, "hidden": ["a"]}],
		[1, 2, 48, 49, 50, 97, 98, 100, 157, 158, 159, 300, 517, 518, 519]))
	out.append(_sc("a_thing_gone_from_the_world_is_forgotten_by_the_sensor_and_its_mark_expires_on_its_own",
		"The thing leaves the world at tick 91: the sensor drops its track at once; the contact fades and expires on its own clock (tick 460).",
		[{"n": 90, "sight": [_ball("a", HERE)]}, {"n": 380, "blocked": [HERE]}],
		[90, 91, 100, 101, 459, 460, 461]))
	return out


func _run(sc: Dictionary, profile: SpeciesProfile.Profile) -> Dictionary:
	var s := Rig.new()
	s.memory = ObservationMemory.new()
	s.configure_from(profile)
	var events: Array = []
	s.memory.contact_acquired.connect(func(c: ObservationMemory.Contact) -> void: events.append("%d acquired:%s" % [s.tick, c.track_id]))
	s.memory.contact_lost.connect(func(c: ObservationMemory.Contact) -> void: events.append("%d lost:%s" % [s.tick, c.track_id]))
	s.memory.contact_reacquired.connect(func(c: ObservationMemory.Contact) -> void: events.append("%d reacquired:%s" % [s.tick, c.track_id]))
	s.memory.contact_ended.connect(func(c: ObservationMemory.Contact, why: String) -> void: events.append("%d ended:%s:%s" % [s.tick, c.track_id, why]))
	s.memory.category_changed.connect(func(c: ObservationMemory.Contact, a: StringName, b: StringName) -> void: events.append("%d category:%s:%s>%s" % [s.tick, c.track_id, a, b]))
	var probes: Array = sc["probes"]
	var snaps := []
	var tick := 0
	for step: Dictionary in sc["steps"]:
		var axis := _v(step["axis"]) if step.has("axis") else Vector3(0.0, 0.0, -1.0)
		s.blocked = []
		for b: Array in step.get("blocked", []):
			s.blocked.append(_v(b))
		for i in int(step["n"]):
			tick += 1
			_drive(s, step, axis)
			if probes.has(tick):
				snaps.append(_snapshot(s, tick, events.size()))
	var counts := {"inspections_made": s.inspections_made, "cues_made": s.cues_made}
	s.free()
	return {"probes": snaps, "events": events, "counts": counts}


## One physics tick of the sensor, as _physics_process makes it, with the sensing step replaced by the scenario's sightings and cues.
func _drive(s: Rig, step: Dictionary, axis: Vector3) -> void:
	var eye := Vector3.ZERO
	var up := Vector3.UP
	var forward := Vector3(0.0, 0.0, -1.0)
	s.tick += 1
	for t: SensorSystem.Track in s._tracks.values():
		t.gap_s += DELTA
	var present := {}
	var inspected: Array[Dictionary] = []
	var sightings: Array[Dictionary] = []
	for id: String in step.get("hidden", []):
		present[id] = true
		s._track_of(id)
	for cue: Dictionary in step.get("cue", []):
		var pid: String = cue["id"]
		present[pid] = true
		var t: SensorSystem.Track = s._track_of(pid)
		var at := _v(cue["at"])
		if s.tick >= t.next_cue_tick:
			s._cue(t, (at - eye).normalized(), forward, up, eye.distance_to(at))
	for sp: Dictionary in step.get("sight", []):
		var pid: String = sp["id"]
		present[pid] = true
		var t: SensorSystem.Track = s._track_of(pid)
		var p := {"id": pid, "position": _v(sp["at"]), "radius": float(sp["radius"]), "velocity": _v(sp["velocity"])}
		if sp.has("max_category"):
			p["max_category"] = StringName(sp["max_category"])
		var radius := maxf(float(p["radius"]), 0.01)
		var center: Vector3 = p["position"]
		var estimate: Vector3 = _v(sp["estimate"]) if sp.has("estimate") else center
		var apparent := PerceptionMath.apparent_size_deg(2.0 * radius, eye.distance_to(center))
		sightings.append({"t": t, "p": p, "estimate": estimate, "est_dir": (estimate - eye).normalized(), "apparent": apparent, "visible_fraction": float(sp.get("visible", 1.0))})
		inspected.append({"position": estimate, "radius": radius})
	s._file_sightings(sightings, DELTA)
	s._check_spots(eye, axis, up, null, DELTA, inspected)
	s.memory.advance(s.tick)
	s._forget_gone(present)


func _snapshot(s: Rig, tick: int, events_so_far: int) -> Dictionary:
	var cs: Array = s.memory.contacts()
	cs.sort_custom(func(a: ObservationMemory.Contact, b: ObservationMemory.Contact) -> bool:
		return a.first_tick < b.first_tick or (a.first_tick == b.first_tick and a.track_id < b.track_id))
	var contacts := []
	for c: ObservationMemory.Contact in cs:
		contacts.append({
			"id": c.track_id, "state": str(c.state), "modality": str(c.modality), "category": str(c.category),
			"confidence": c.confidence, "target_id": c.target_id,
			"position": _a(c.position) if c.has_position else null,
			"position_tick": c.position_tick, "observed_tick": c.observed_tick, "first_tick": c.first_tick, "lost_tick": c.lost_tick,
			"reacquisitions": c.reacquisitions, "cue_count": c.cue_count,
			"cue_direction": _a(c.cue_direction) if c.cue_count > 0 else null, "cue_tick": c.cue_tick if c.cue_count > 0 else null,
			"size_wu": c.size_wu, "speed_wu_s": c.speed_wu_s, "mark_valid": c.mark_valid, "has_mark": c.has_mark(),
			"familiarity": s.memory.familiarity(c.track_id), "age_s": s.memory.age_s(c), "staleness": s.memory.staleness_of(c),
		})
	var tracks := {}
	for pid: String in s._tracks.keys():
		var t: SensorSystem.Track = s._tracks[pid]
		tracks[pid] = {"track_id": t.track_id, "exposure": t.exposure, "link_tick": t.link_tick, "next_cue_tick": t.next_cue_tick}
	var spots := {}
	for id: String in s._spots.keys():
		spots[id] = s._spots[id]["exposure"]
	return {"tick": tick, "events_so_far": events_so_far, "contacts": contacts, "tracks": tracks, "spots": spots, "kept": s._kept.duplicate(),
		"marks": s.memory.marks().map(func(c: ObservationMemory.Contact) -> String: return c.track_id)}
