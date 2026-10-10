extends "res://tests/test_case.gd"
## ObservationMemory (spec 7, 21.3): contacts are made, held, lost, faded and forgotten only by observations and time, a mark
## stays exactly where it was last observed, a cue never takes back what an inspection found, and a lost spot can be dropped.

const Observation = preload("res://scripts/perception/observation.gd")
const ObservationMemory = preload("res://scripts/perception/observation_memory.gd")

var mem: ObservationMemory
var events: Array[String] = []


func before_each() -> void:
	mem = ObservationMemory.new()
	mem.configure(60.0, 6.0, 0.15, 1.0)
	events = []
	mem.contact_acquired.connect(func(c: ObservationMemory.Contact) -> void: events.append("acquired:" + c.track_id))
	mem.contact_lost.connect(func(c: ObservationMemory.Contact) -> void: events.append("lost:" + c.track_id))
	mem.contact_reacquired.connect(func(c: ObservationMemory.Contact) -> void: events.append("reacquired:" + c.track_id))
	mem.contact_ended.connect(func(c: ObservationMemory.Contact, why: String) -> void: events.append("ended:%s:%s" % [c.track_id, why]))
	mem.category_changed.connect(func(c: ObservationMemory.Contact, a: StringName, b: StringName) -> void: events.append("category:%s>%s" % [a, b]))


func after_each() -> void:
	mem = null  # the signal lambdas hold the test: let go of the memory so the two do not keep each other alive


func _inspection(tick: int, at: Vector3 = Vector3(4.0, 1.0, -6.0), category: StringName = Observation.POSSIBLE_PREY, track: String = "trk_1", conf: float = 0.7) -> Observation:
	var o := Observation.new()
	o.observer_id = "spider"
	o.track_id = track
	o.target_id = "test_target" if category != Observation.MOVEMENT else ""
	o.modality = Observation.INSPECTION
	o.has_position = true
	o.estimated_position = at
	o.direction = Vector3.FORWARD
	o.confidence = conf
	o.observed_tick = tick
	o.category = category
	o.size_wu = 0.9
	o.apparent_size_deg = 9.0
	return o


func _cue(tick: int, track: String = "trk_1", dir: Vector3 = Vector3.LEFT) -> Observation:
	var o := Observation.new()
	o.observer_id = "spider"
	o.track_id = track
	o.modality = Observation.PERIPHERAL
	o.direction = dir
	o.confidence = 0.2
	o.observed_tick = tick
	return o


func _run_to(tick: int) -> void:
	for t in range(mem.now_tick + 1, tick + 1):
		mem.advance(t)


func test_a_cue_makes_a_contact_with_a_bearing_and_nothing_else() -> void:
	var c := mem.ingest(_cue(10))
	check(c != null and mem.count() == 1, "a contact")
	check(c.is_live() and not c.has_position and not c.has_mark(), "live, with no position and no mark")
	check_eq(c.category, Observation.MOVEMENT, "movement")
	check_eq(c.target_id, "", "nothing resolved")
	check_eq(c.cue_direction, Vector3.LEFT, "the bearing is kept")
	check_eq(events, ["acquired:trk_1"] as Array[String], "announced once")


func test_an_invalid_record_is_refused_and_changes_nothing() -> void:
	var bad := _inspection(5)
	bad.confidence = 3.0
	check(mem.ingest(bad) == null, "refused")
	check(mem.ingest(null) == null, "null is refused")
	check_eq(mem.count(), 0, "no contact")
	check_eq(mem.ingested, 0, "and it was not counted")


func test_a_peripheral_contact_is_held_for_the_cue_hold_and_then_lost() -> void:
	mem.ingest(_cue(0))
	_run_to(60)
	check(mem.get_contact("trk_1").is_live(), "still live at one second")
	_run_to(61)
	check(not mem.get_contact("trk_1").is_live(), "lost just after")
	check_eq(events, ["acquired:trk_1", "lost:trk_1"] as Array[String], "one loss, announced once")
	_run_to(200)
	check_eq(events.size(), 2, "and it is not announced again")


func test_an_inspection_is_held_for_the_grace_only() -> void:
	mem.ingest(_inspection(0))
	_run_to(9)
	check(mem.get_contact("trk_1").is_live(), "live through the grace (9 ticks)")
	_run_to(10)
	check(not mem.get_contact("trk_1").is_live(), "lost on the 10th tick without evidence")


func test_a_lost_inspected_contact_leaves_a_mark_that_never_moves() -> void:
	var at := Vector3(4.0, 1.0, -6.0)
	mem.ingest(_inspection(0, at))
	_run_to(10)
	var c := mem.get_contact("trk_1")
	check(c.has_mark(), "a mark")
	check_eq(mem.marks().size(), 1, "listed")
	for t in range(11, 300):
		mem.advance(t)
		var m := mem.get_contact("trk_1")
		if m == null:
			break
		if m.position != at:
			check(false, "the mark moved at tick %d" % t)
			return
	check(true, "the mark never moved over its whole life")
	check_eq(c.position, at, "it is exactly where it was last observed")


func test_confidence_falls_in_a_straight_line_and_the_contact_expires() -> void:
	mem.ingest(_inspection(0, Vector3.ZERO, Observation.POSSIBLE_PREY, "trk_1", 0.8))
	_run_to(10)
	var c := mem.get_contact("trk_1")
	check_near(c.confidence, 0.8, 1e-9, "at the loss it has what it had")
	_run_to(10 + 180)
	check_near(c.confidence, 0.4, 1e-6, "half way through the decay, half")
	check_near(mem.staleness_of(c), 0.5, 1e-6, "and half stale")
	_run_to(10 + 359)
	check(mem.get_contact("trk_1") != null, "still remembered a tick before the end")
	_run_to(10 + 360)
	check(mem.get_contact("trk_1") == null, "forgotten after the decay time")
	check_eq(events.back(), "ended:trk_1:expired", "announced as expired")
	check_eq(mem.marks().size(), 0, "and no mark is left")


func test_a_cue_never_takes_back_what_an_inspection_found() -> void:
	var at := Vector3(4.0, 1.0, -6.0)
	mem.ingest(_inspection(0, at, Observation.FLY_LIKE_PREY, "trk_1", 0.9))
	var c := mem.ingest(_cue(3, "trk_1", Vector3.RIGHT))
	check_eq(c.category, Observation.FLY_LIKE_PREY, "the category stays")
	check_near(c.confidence, 0.9, 1e-9, "so does the confidence")
	check_eq(c.position, at, "and the position")
	check_eq(c.modality, Observation.INSPECTION, "and the modality of the record")
	check_eq(c.cue_direction, Vector3.RIGHT, "the bearing is kept apart")
	check_eq(c.cue_count, 1, "counted")
	_run_to(30)
	check(not c.is_live() and c.has_mark(), "and the contact is lost on its own clock (the cue did not hold it)")
	var d := mem.ingest(_cue(40, "trk_1", Vector3.LEFT))
	check(not d.is_live(), "a cue does not bring a lost contact back")
	check_eq(d.cue_direction, Vector3.LEFT, "though its bearing is noted")
	check(d.has_mark() and d.position == at, "the mark is still where it was")
	check(not events.has("reacquired:trk_1"), "no reacquisition from a cue")


func test_only_an_inspection_reacquires_and_it_updates_the_record() -> void:
	mem.ingest(_inspection(0, Vector3(4.0, 1.0, -6.0), Observation.POSSIBLE_PREY, "trk_1", 0.6))
	_run_to(100)
	var c := mem.get_contact("trk_1")
	check(not c.is_live(), "lost")
	var now := Vector3(9.0, 1.0, -6.0)
	mem.ingest(_inspection(101, now, Observation.FLY_LIKE_PREY, "trk_1", 0.8))
	check(c.is_live() and not c.has_mark(), "live again, no mark")
	check_eq(c.position, now, "at the new position")
	check_eq(c.position_tick, 101, "observed at the new tick")
	check_eq(c.category, Observation.FLY_LIKE_PREY, "with the new category")
	check_near(c.confidence, 0.8, 1e-9, "and the new confidence")
	check_eq(c.reacquisitions, 1, "counted once")
	check_eq(events.filter(func(e: String) -> bool: return e.begins_with("reacquired")).size(), 1, "announced once")
	check(events.has("category:possible_prey>fly_like_prey"), "and the category change announced")


func test_a_contact_that_was_only_ever_a_cue_comes_back_on_a_cue() -> void:
	mem.ingest(_cue(0))
	_run_to(100)
	check(not mem.get_contact("trk_1").is_live(), "lost")
	var c := mem.ingest(_cue(101))
	check(c.is_live() and c.reacquisitions == 1, "a repeated cue is a reacquisition for a contact that never had a position")


func test_familiarity_is_one_while_live_then_fades_then_is_nothing() -> void:
	check_near(mem.familiarity("trk_1"), 0.0, 1e-9, "nothing is familiar that was never sensed")
	mem.ingest(_inspection(0))
	check_near(mem.familiarity("trk_1"), 1.0, 1e-9, "live is fully familiar")
	_run_to(10 + 180)
	check_near(mem.familiarity("trk_1"), 0.5, 1e-6, "half way through the decay, half")
	_run_to(10 + 360)
	check_near(mem.familiarity("trk_1"), 0.0, 1e-9, "and after it, nothing")


func test_inspecting_the_empty_spot_drops_the_mark_and_only_a_lost_contact_has_one() -> void:
	mem.ingest(_inspection(0))
	check(not mem.invalidate("trk_1"), "a live contact's spot is not empty: nothing happens")
	check_eq(mem.count(), 1, "it stays")
	_run_to(10)
	check(mem.invalidate("trk_1", "empty"), "a lost one's can be dropped")
	check_eq(mem.count(), 0, "gone")
	check_eq(mem.marks().size(), 0, "with no mark")
	check_eq(events.back(), "ended:trk_1:empty", "announced as empty")
	check(not mem.invalidate("trk_1"), "and not twice")
	check(not mem.invalidate("trk_9"), "nor one that never existed")


func test_time_alone_never_changes_a_position_or_a_category() -> void:
	var at := Vector3(-3.0, 0.5, 2.0)
	mem.ingest(_inspection(0, at, Observation.FLY_LIKE_PREY))
	var before := mem.get_contact("trk_1").to_dict()
	_run_to(10)
	var after := mem.get_contact("trk_1").to_dict()
	for key in ["position", "category", "position_tick", "observed_tick", "modality"]:
		check_eq(after[key], before[key], "'%s' is the same after the loss" % key)
	check_eq(before["target_id"], "test_target", "while it was seen, the thing had a world link")
	check_eq(after["target_id"], "", "and the link ends with the sight (A-027): a lost contact holds no world id to be updated by")
	check(after["state"] != before["state"], "only the state and the live link changed")


func test_several_contacts_are_kept_apart() -> void:
	mem.ingest(_inspection(0, Vector3(1.0, 0.0, 0.0), Observation.POSSIBLE_PREY, "trk_1"))
	mem.ingest(_inspection(5, Vector3(2.0, 0.0, 0.0), Observation.MOVEMENT, "trk_2"))
	check_eq(mem.count(), 2, "two contacts")
	check_eq(mem.contacts()[0].track_id, "trk_1", "the older first")
	_run_to(30)
	check_eq(mem.lost_contacts().size(), 2, "both lost")
	mem.ingest(_inspection(31, Vector3(2.5, 0.0, 0.0), Observation.POSSIBLE_PREY, "trk_2"))
	check_eq(mem.live_contacts().size(), 1, "one live")
	check_eq(mem.marks().size(), 1, "one mark")
	check_eq(mem.marks()[0].track_id, "trk_1", "the first one's")


func test_a_contact_that_expired_comes_back_as_a_new_one() -> void:
	mem.ingest(_inspection(0))
	_run_to(10 + 360)
	check_eq(mem.count(), 0, "forgotten")
	var c := mem.ingest(_inspection(400, Vector3(1.0, 0.0, 1.0), Observation.MOVEMENT))
	check_eq(c.reacquisitions, 0, "a track that was forgotten is a new acquisition")
	check_eq(events.filter(func(e: String) -> bool: return e.begins_with("acquired")).size(), 2, "announced as acquired again")


# ---------------------------------------------------------------- A-027 (chunk 7A): association helpers

func test_the_hold_times_are_the_ones_the_memory_loses_contacts_by() -> void:
	check_eq(mem.hold_ticks(Observation.INSPECTION), 9, "an inspection is held for the exposure grace, 0.15 s")
	check_eq(mem.hold_ticks(Observation.PERIPHERAL), 60, "a cue for the cue hold, 1.0 s")
	mem.ingest(_inspection(0))
	_run_to(mem.hold_ticks(Observation.INSPECTION))
	check(mem.get_contact("trk_1").is_live(), "live at the last tick the hold allows")
	_run_to(mem.hold_ticks(Observation.INSPECTION) + 1)
	check(not mem.get_contact("trk_1").is_live(), "lost the tick after")


func test_the_speed_a_thing_was_seen_moving_at_is_kept_with_the_place() -> void:
	var o := _inspection(0)
	o.speed_wu_s = 0.8
	mem.ingest(o)
	_run_to(20)
	check_near(mem.get_contact("trk_1").speed_wu_s, 0.8, 1e-9, "a mark remembers how fast the thing was going when it was last seen")
	var later := _inspection(25)
	later.speed_wu_s = 0.0
	mem.ingest(later)
	check_near(mem.get_contact("trk_1").speed_wu_s, 0.0, 1e-9, "and a new sighting replaces it")


func test_a_contact_known_only_from_cues_can_be_folded_into_a_lost_one() -> void:
	mem.ingest(_inspection(0, Vector3(2.0, 1.0, -6.0), Observation.FLY_LIKE_PREY, "trk_1"))
	_run_to(20)
	mem.ingest(_cue(30, "trk_2", Vector3.RIGHT))
	mem.ingest(_cue(40, "trk_2", Vector3.LEFT))
	check_eq(mem.count(), 2, "the lost one and the one made of bearings")
	check(mem.merge("trk_2", "trk_1"), "the bearings turned out to belong to the lost contact")
	check_eq(mem.count(), 1, "one contact")
	var c := mem.get_contact("trk_1")
	check(c.has_mark() and c.position == Vector3(2.0, 1.0, -6.0), "the mark did not move: a bearing says nothing of where")
	check_eq(c.cue_count, 2, "it has both cues")
	check_eq(c.cue_direction, Vector3.LEFT, "and the latest bearing")
	check_eq(events.back(), "ended:trk_2:merged", "the folded contact is announced as merged")
	mem.ingest(_inspection(50, Vector3(2.5, 1.0, -6.0), Observation.POSSIBLE_PREY, "trk_1"))
	check(c.is_live() and c.reacquisitions == 1, "and the inspection that follows reacquires it once")


func test_only_a_contact_without_a_place_is_folded_and_never_into_itself() -> void:
	mem.ingest(_inspection(0, Vector3(1.0, 0.0, 0.0), Observation.POSSIBLE_PREY, "trk_1"))
	mem.ingest(_inspection(0, Vector3(5.0, 0.0, 0.0), Observation.POSSIBLE_PREY, "trk_2"))
	check(not mem.merge("trk_2", "trk_1"), "an inspected contact has a place of its own and is never folded into another")
	check(not mem.merge("trk_1", "trk_1"), "nor into itself")
	check(not mem.merge("trk_9", "trk_1") and not mem.merge("trk_1", "trk_9"), "nor does anything fold into or out of a contact that is not there")
	check_eq(mem.count(), 2, "nothing changed")
