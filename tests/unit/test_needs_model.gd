extends "res://tests/test_case.gd"
## NeedsModel (chunk 7B, spec 11): energy and rest only, drained slowly by elapsed action time with a floor (no starvation pressure on
## the first hunt), changed otherwise only by approved grants, and the same at every frame rate.

const NeedsModel := preload("res://scripts/needs/needs_model.gd")


func _run(m: RefCounted, seconds: float, hz: float, active: bool) -> void:
	var steps := roundi(seconds * hz)
	for i in steps:
		m.advance(1.0 / hz, active)


func test_it_starts_a_little_hungry_and_rested() -> void:
	var m = NeedsModel.new()
	check_near(m.energy, NeedsModel.ENERGY_START, 1e-9, "energy at the start")
	check_near(m.rest, NeedsModel.REST_START, 1e-9, "rest at the start")
	check(m.energy > NeedsModel.ENERGY_FLOOR and m.energy < NeedsModel.ENERGY_MAX, "there is room to eat on the first hunt")
	check(not m.is_full(), "not full at the start")


func test_energy_drains_slowly_and_only_with_time() -> void:
	var m = NeedsModel.new()
	m.advance(0.0, true)
	m.advance(-1.0, true)
	m.advance(NAN, true)
	m.advance(INF, false)
	check_near(m.energy, NeedsModel.ENERGY_START, 1e-12, "no time, no drain; bad time is ignored")
	_run(m, 60.0, 60.0, false)
	check_near(m.energy, NeedsModel.ENERGY_START - 60.0 * NeedsModel.ENERGY_DRAIN_PER_S, NeedsModel.ENERGY_DRAIN_PER_S * NeedsModel.UPDATE_PERIOD_S + 1e-9, "a minute drains a minute's worth")
	check(NeedsModel.ENERGY_DRAIN_PER_S * 60.0 < 0.05, "a minute costs well under a twentieth of the reserve: a slow drain")


func test_the_drain_stops_at_the_floor_and_nothing_goes_negative() -> void:
	var m = NeedsModel.new()
	_run(m, 3600.0, 30.0, true)
	check_near(m.energy, NeedsModel.ENERGY_FLOOR, 1e-12, "an hour of play ends at the floor, not below")
	check(m.energy >= 0.0 and m.rest >= 0.0, "nothing is negative")
	_run(m, 600.0, 30.0, false)
	check_near(m.energy, NeedsModel.ENERGY_FLOOR, 1e-12, "and it stays there")


func test_the_same_time_drains_the_same_at_every_frame_rate() -> void:
	var results: Array[float] = []
	var rests: Array[float] = []
	for hz in [30.0, 60.0, 144.0, 240.0]:
		var m = NeedsModel.new()
		_run(m, 300.0, hz, true)
		results.append(m.energy)
		rests.append(m.rest)
	for i in results.size():
		check_near(results[i], results[0], NeedsModel.ENERGY_DRAIN_PER_S * NeedsModel.UPDATE_PERIOD_S + 1e-9, "energy after 300 s at rate %d agrees with the first" % i)
		check_near(rests[i], rests[0], NeedsModel.REST_DRAIN_PER_S * NeedsModel.UPDATE_PERIOD_S + 1e-9, "rest after 300 s at rate %d agrees with the first" % i)


func test_a_stall_cannot_drain_more_than_a_capped_step() -> void:
	var m = NeedsModel.new()
	m.advance(5000.0, true)
	check(m.elapsed_s <= NeedsModel.MAX_STEP_S + 1e-9, "one huge step counts as at most the cap (%s)" % str(m.elapsed_s))
	check_near(m.energy, NeedsModel.ENERGY_START - NeedsModel.ENERGY_DRAIN_PER_S * NeedsModel.UPDATE_PERIOD_S * floorf(NeedsModel.MAX_STEP_S / NeedsModel.UPDATE_PERIOD_S), 1e-9, "and it drains at most that")


func test_rest_wears_down_while_active_and_builds_while_still() -> void:
	var m = NeedsModel.new()
	_run(m, 100.0, 60.0, true)
	var worn: float = m.rest
	check(worn < NeedsModel.REST_START, "activity wears rest down")
	_run(m, 100.0, 60.0, false)
	check(m.rest > worn, "keeping still builds it back")
	_run(m, 1000.0, 60.0, false)
	check_near(m.rest, NeedsModel.REST_MAX, 1e-12, "and it stops at the top")


func test_grants_fill_the_reserve_and_never_past_it() -> void:
	var m = NeedsModel.new()
	var got: float = m.grant_energy(0.2, "fly_1")
	check_near(got, 0.2, 1e-9, "a grant adds what it says")
	check_near(m.energy, NeedsModel.ENERGY_START + 0.2, 1e-9, "energy went up by it")
	var got2: float = m.grant_energy(5.0, "fly_2")
	check_near(m.energy, NeedsModel.ENERGY_MAX, 1e-12, "a huge grant stops at the top")
	check_near(got2, NeedsModel.ENERGY_MAX - (NeedsModel.ENERGY_START + 0.2), 1e-9, "and says how much of it was taken")
	check_near(m.grant_energy(0.1, "fly_3"), 0.0, 1e-12, "nothing is added to a full reserve")
	check(m.is_full(), "a full reserve says so")
	check_near(m.granted_total, m.granted_from("fly_1") + m.granted_from("fly_2"), 1e-9, "the ledger adds up")
	check_near(m.granted_from("fly_3"), 0.0, 1e-12, "a source that gave nothing is not in it")


func test_a_grant_that_is_not_one_changes_nothing() -> void:
	var m = NeedsModel.new()
	var before: float = m.energy
	for bad in [0.0, -0.1, NAN, INF, -INF]:
		check_near(m.grant_energy(bad, "fly_1"), 0.0, 1e-12, "a grant of %s adds nothing" % str(bad))
	check_near(m.grant_energy(0.1, ""), 0.0, 1e-12, "a grant from nowhere adds nothing")
	check_near(m.energy, before, 1e-12, "energy is untouched")
	check_eq(m.granted_by_source.size(), 0, "nothing in the ledger")
	check(m.grants_refused >= 5, "refusals are counted")


func test_energy_changed_is_announced_once_per_change() -> void:
	var m = NeedsModel.new()
	var seen: Array[float] = []
	m.energy_changed.connect(func(old_value: float, new_value: float) -> void: seen.append(new_value - old_value))
	m.grant_energy(0.1, "fly_1")
	m.grant_energy(0.0, "fly_1")
	_run(m, 2.0, 60.0, true)
	check_eq(seen.size(), 1 + 4, "one for the grant and four 0.5 s drains in two seconds")
	check_near(seen[0], 0.1, 1e-9, "the grant's change")
	check(seen[1] < 0.0, "a drain is a fall")


func test_the_record_round_trips_and_rejects_nonsense() -> void:
	var m = NeedsModel.new()
	m.grant_energy(0.12, "fly_1")
	_run(m, 7.3, 60.0, true)
	var d: Dictionary = m.to_dict()
	check_eq(d["enabled"], ["energy", "rest"], "only energy and rest are simulated in P0")
	check(d["hydration"] == null and d["stress"] == null and d["condition"] == null, "the other needs are named and null")
	var n = NeedsModel.new()
	check(n.load_dict(d), "a record loads")
	check_near(n.energy, m.energy, 1e-12, "energy comes back")
	check_near(n.rest, m.rest, 1e-12, "rest comes back")
	check_near(n.granted_from("fly_1"), 0.12, 1e-9, "the ledger comes back")
	var before: Dictionary = n.to_dict()
	var bad1: Dictionary = d.duplicate(true)
	bad1["energy"] = 1.5
	var bad2: Dictionary = d.duplicate(true)
	bad2["rest"] = NAN
	var bad3: Dictionary = d.duplicate(true)
	bad3["granted_total"] = 9.0
	var bad4: Dictionary = d.duplicate(true)
	bad4.erase("update_accumulator")
	var bad5: Dictionary = d.duplicate(true)
	bad5["update_accumulator"] = [1.0]
	for bad: Dictionary in [bad1, bad2, bad3, bad4, bad5]:
		check(not n.load_dict(bad), "a bad record is refused")
	check_eq(n.to_dict(), before, "and a refused record changes nothing")


func test_configure_ignores_values_outside_the_unit_range() -> void:
	var m = NeedsModel.new()
	m.configure({"energy": 0.3, "rest": 0.4})
	check_near(m.energy, 0.3, 1e-12, "energy set")
	check_near(m.rest, 0.4, 1e-12, "rest set")
	m.configure({"energy": 2.0, "rest": -1.0})
	check_near(m.energy, 0.3, 1e-12, "out of range ignored (energy)")
	check_near(m.rest, 0.4, 1e-12, "out of range ignored (rest)")
