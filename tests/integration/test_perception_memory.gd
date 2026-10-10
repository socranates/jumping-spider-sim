extends "res://tests/perception_test_case.gd"
## The memory in the world (spec 7, 21.3; A-002; T06): confidence decays after sight is lost; the last-seen mark is fixed at the
## last observed position while the thing moves on behind cover, expires, is dropped when the spot is looked at and found
## empty, and is replaced by the new record when the thing is seen again; a cue never takes back what an inspection found.

## Runs `ticks` physics ticks with the spider following what it has sensed: while the target is being inspected, Focus is held
## toward where it is observed (never toward where it is). Returns nothing; read the memory afterwards.
func follow(ticks: int) -> void:
	for i in ticks:
		var c := target_contact()
		if c != null and c.is_inspected_now():
			focus_on((c.position - eye()).normalized())
		await physics_frames(1)


## A spider on the ledge facing the west end, the marker walking east from there, the spider following it until it is lost.
func lose_it_behind_the_screen() -> void:
	await spawn_stage(false, heading_toward(Vector3(-28.8, 1.4, -7.9)), null)
	var guard := 0
	while guard < 600:
		await follow(1)
		guard += 1
		var c := target_contact()
		if c != null and not c.is_live() and c.has_position:
			return


func test_the_mark_stays_put_while_the_thing_moves_on_behind_cover() -> void:
	await lose_it_behind_the_screen()
	var c := target_contact()
	if not check(c != null and c.has_mark(), "the marker was inspected, then lost behind the screen: it has a mark"):
		return
	check(Observation.rank(c.category) >= Observation.rank(Observation.POSSIBLE_PREY), "after being classified (%s)" % str(c.category))
	check(target_is_hidden(), "and it is hidden now")
	var mark := c.position
	var seen_at := c.position_tick
	var ingested := mem().ingested
	var truth0: Vector3 = target().global_position
	var last_conf := c.confidence
	var last_stale := mem().staleness_of(c)
	var monotonic := true
	var hidden_ticks := 0
	for i in 200:
		await physics_frames(1)
		if target_contact() != c or not target_is_hidden():
			break   # it has come out the other side: the walk behind cover is over
		hidden_ticks += 1
		if c.confidence > last_conf + 1e-9 or mem().staleness_of(c) < last_stale - 1e-9:
			monotonic = false
		last_conf = c.confidence
		last_stale = mem().staleness_of(c)
		if c.position != mark or c.position_tick != seen_at:
			check(false, "the mark moved at tick %d" % i)
			break
		if mem().ingested != ingested:
			check(false, "something was ingested while it was hidden (tick %d)" % i)
			break
	check_eq(c.position, mark, "the mark is exactly where the marker was last observed")
	check_eq(c.position_tick, seen_at, "and was observed at the same tick")
	check_eq(mem().ingested, ingested, "nothing was added to the memory while it was out of sight")
	check(hidden_ticks >= 90, "it stayed hidden for %d ticks of walking" % hidden_ticks)
	check(target().global_position.distance_to(truth0) > 2.0, "the marker walked on %.1f WU" % target().global_position.distance_to(truth0))
	check(target().global_position.distance_to(mark) > 2.0, "and is %.1f WU from the mark" % target().global_position.distance_to(mark))
	check(monotonic, "confidence only fell and staleness only grew")
	check(c.confidence < 0.9 * c.confidence_at_loss, "confidence has fallen (%.2f of %.2f)" % [c.confidence, c.confidence_at_loss])


func test_the_mark_expires_when_the_memory_does_and_not_before() -> void:
	await lose_it_behind_the_screen()
	var c := target_contact()
	if not check(c != null and c.has_mark(), "a mark"):
		return
	var ended: Array[String] = []
	mem().contact_ended.connect(func(_c: ObservationMemory.Contact, why: String) -> void: ended.append(why))
	var lost_tick := c.lost_tick
	target().set_enabled(false)  # keep the marker from walking back into view
	await wait_until(func() -> bool: return world.sensor.tick - lost_tick >= 355, 600)
	check(c.has_mark() and mem().marks().size() == 1, "5.9 s after the loss the mark is still there (confidence %.3f)" % c.confidence)
	check(c.confidence > 0.0 and c.confidence < 0.1 * c.confidence_at_loss + 0.001, "very faint (%.3f of %.2f)" % [c.confidence, c.confidence_at_loss])
	await wait_until(func() -> bool: return world.sensor.tick - lost_tick >= 361, 60)
	check_eq(mem().marks().size(), 0, "6.0 s after the loss it is gone")
	check_eq(mem().count(), 0, "with the contact")
	check_eq(ended, ["expired"] as Array[String], "because it expired")


func test_looking_at_the_empty_spot_drops_the_mark_and_not_looking_does_not() -> void:
	# The marker stands in plain view, dead ahead, long enough to be classified, and is then taken away.
	await spawn_stage(false, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(40)
	var c := target_contact()
	check(c != null and Observation.rank(c.category) >= Observation.rank(Observation.POSSIBLE_PREY), "classified first")
	var ended: Array[String] = []
	mem().contact_ended.connect(func(_c: ObservationMemory.Contact, why: String) -> void: ended.append(why))
	target().set_enabled(false)
	await physics_frames(14)
	check(c.has_mark(), "taken away: lost, with a mark at the spot")
	await physics_frames(10)
	check(c.has_mark(), "a moment later the empty spot has not yet been looked at for long enough")
	await physics_frames(40)
	check_eq(mem().marks().size(), 0, "after looking at the empty spot for 0.4 s the mark is gone")
	check_eq(ended, ["empty"] as Array[String], "dropped because it was empty, not because it expired")
	world.free()
	# The same, looking away (the spot is in plain view of the body's side, but not in its cone).
	await spawn_stage(false, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(40)
	var d := target_contact()
	check(d != null and d.is_inspected_now(), "classified again")
	target().set_enabled(false)
	focus_on(Vector3(1.0, 0.0, -0.3).normalized())   # turn the body away, to the right
	await physics_frames(150)
	check(d.has_mark(), "the body looked away: 2.5 s later the mark is still there (nobody has checked)")
	check(mem().count() == 1 and d.position.distance_to(WEST_VISIBLE) < 0.5, "at the spot where it stood")


func test_a_spot_the_world_hides_cannot_be_called_empty() -> void:
	await spawn_stage(false, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(40)
	var c := target_contact()
	check(c != null and c.is_inspected_now(), "classified")
	# A wall goes up between the ledge and the marker: it is lost, and its spot is now out of sight.
	world.lab.add_fixture_piece("test_wall", "wall", Vector3(-30.0, 0.0, -5.0), Vector3(-23.0, 4.0, -4.8))
	await physics_frames(90)
	check(not c.is_live(), "lost behind the new wall")
	check(c.has_mark(), "with a mark")
	check(target_is_hidden(), "the marker is hidden")
	target().set_enabled(false)
	await physics_frames(120)
	check(c.has_mark(), "two seconds of looking at a wall do not show that the place behind it is empty: the mark stays")
	check_eq(c.position.distance_to(WEST_VISIBLE) < 0.6, true, "where it was last seen")


func test_seeing_it_again_updates_the_same_record() -> void:
	await spawn_stage(false, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(40)
	var c := target_contact()
	var track: String = world.sensor.track_id_for(TARGET_ID)
	check(c != null and Observation.rank(c.category) >= Observation.rank(Observation.POSSIBLE_PREY), "classified")
	var first_position := c.position
	world.lab.add_fixture_piece("test_wall", "wall", Vector3(-30.0, 0.0, -5.0), Vector3(-23.0, 4.0, -4.8))
	await physics_frames(60)
	check(not c.is_live() and c.has_mark(), "lost behind a wall")
	check_eq(c.reacquisitions, 0, "not seen again yet")
	# Changed assumption (chunk 7A, A-027): the same record used to follow from the marker's world id. It now follows from the evidence: the
	# marker is renamed while it is out of sight, and it is still the one remembered place it could be (a step away, a second later).
	target().target_id = "test_target_renamed"
	world.lab.set_piece_enabled("test_wall", false)   # the wall goes away and the marker has moved on a little
	target().hold_at(Vector3(-27.0, 1.4, -6.9))   # a step nearer, still in the cone
	await physics_frames(30)
	check(target_contact() == c and world.sensor.track_id_for(target().target_id) == track, "it is the same record, the same track, whatever the world calls the marker")
	check(c.is_live() and not c.has_mark(), "live again, the mark gone")
	check_eq(c.reacquisitions, 1, "seen again once")
	check(c.position.distance_to(target().global_position) < 0.5, "at where it is now (%.2f WU off)" % c.position.distance_to(target().global_position))
	check(c.position.distance_to(first_position) > 1.0, "not where it was")
	check(Observation.rank(c.category) >= Observation.rank(Observation.POSSIBLE_PREY), "and it is still recognised: a thing seen a moment ago is not a stranger (%s)" % str(c.category))


func test_a_thing_forgotten_has_to_be_classified_again() -> void:
	await spawn_stage(false, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(70)
	var c := target_contact()
	check(c != null and c.category == Observation.FLY_LIKE_PREY, "fly-like prey after more than a second")
	target().set_enabled(false)
	await physics_frames(14 + 360 + 5)
	check_eq(mem().count(), 0, "forgotten after the decay time")
	target().set_enabled(true)
	await physics_frames(5)
	var d := target_contact()
	check(d != null and d.is_inspected_now(), "seen again")
	check_eq(d.category, Observation.MOVEMENT, "as movement: what was known has gone")
	check_eq(d.reacquisitions, 0, "a new contact, not a reacquisition")
	await physics_frames(30)
	check(Observation.rank(d.category) >= Observation.rank(Observation.POSSIBLE_PREY), "and refined again with 0.4 s")


func test_a_cue_does_not_take_back_what_was_found_or_bring_back_a_lost_contact() -> void:
	await spawn_stage(false, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(70)
	var c := target_contact()
	check(c != null and c.category == Observation.FLY_LIKE_PREY, "fly-like prey")
	focus_on(Vector3(1.0, 0.0, -0.2).normalized())   # the body turns away: the marker is outside the cone, still in plain view
	await wait_until(func() -> bool: return not c.is_live(), 120)
	check(c.has_mark(), "it left the cone and was lost, with a mark")
	var pos := c.position
	var cues_at_loss := c.cue_count
	check(pos.distance_to(WEST_VISIBLE) < 0.5, "where it stood")
	target().pause_s = 0.0
	target().set_path(PackedVector3Array([Vector3(-29.5, 1.4, -7.9), Vector3(-27.6, 1.4, -7.9)]))   # now it walks, to and fro
	await physics_frames(150)
	check(not target_is_hidden(), "it is in plain view of the body's side, not in its cone (%.0f degrees off the axis)" % off_axis_deg(target().global_position))
	check(c.has_mark() and c.position == pos, "its mark is still where it was seen")
	check_eq(c.category, Observation.FLY_LIKE_PREY, "and it is still remembered as fly-like prey")
	# Changed assumption (chunk 7A, A-027): its cues used to be added to this record through the world id of the marker. A bearing cannot
	# say which remembered place the movement comes from, so now they make a contact of their own and the lost record is left alone.
	check_eq(c.cue_count, cues_at_loss, "none of what it does in the periphery is added to the lost record")
	var cued := target_contact()
	check(cued != null and cued != c and not cued.has_position and cued.category == Observation.MOVEMENT, "it is a contact of its own, known only from bearings")
	check(cued != null and cued.cue_count >= 2, "although it keeps moving in the periphery: %d cues" % (cued.cue_count if cued != null else 0))
	check_eq(c.reacquisitions, 0, "a cue is not a reacquisition")
	check(cued != null and mem().cue_age_s(cued) < 1.0, "the latest cue is recent")


## Two look-alike markers (A-027): the second labelled test target, added by the fixture, stands a step from the first. A wall goes up and
## hides both, they are lost; the wall comes down and both are in view again. The spider cannot tell them apart by anything it has
## seen, so neither is taken for either, and what the world calls them while they are hidden changes nothing it knows.
func _two_markers(swap_ids: bool) -> Dictionary:
	await spawn_stage(false, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	var other: Node3D = add_second_target("test_target_b", Vector3(-27.0, 1.4, -7.9))
	await physics_frames(90)
	var first := target_contact()
	var second := contact_of(other)
	var report := {"classified": first != null and second != null and first != second and first.category == Observation.FLY_LIKE_PREY and second.category == Observation.FLY_LIKE_PREY}
	world.lab.add_fixture_piece("test_wall", "wall", Vector3(-30.0, 0.0, -5.0), Vector3(-23.0, 4.0, -4.8))
	await physics_frames(60)
	report["lost"] = first != null and second != null and first.has_mark() and second.has_mark() and target_is_hidden() and target_is_hidden(other)
	if swap_ids:
		var keep: String = target().target_id
		target().target_id = other.target_id
		other.target_id = keep
	world.lab.set_piece_enabled("test_wall", false)
	await physics_frames(40)
	report["digest"] = contacts_digest()
	report["live"] = mem().live_contacts().size()
	report["marks"] = mem().marks().size()
	report["reacquired"] = 0
	for c: ObservationMemory.Contact in mem().contacts():
		report["reacquired"] = int(report["reacquired"]) + c.reacquisitions
	world.free()
	await physics_frames(2)
	return report


func test_two_look_alike_markers_are_not_told_apart_by_their_names() -> void:
	var plain := await _two_markers(false)
	check(bool(plain["classified"]), "both markers were classified, each as its own contact")
	check(bool(plain["lost"]), "the wall hid both and both were lost, with a mark each")
	check(int(plain["live"]) == 2 and int(plain["marks"]) == 2, "back in view there are two new contacts and the two old places (%d live, %d marks)" % [int(plain["live"]), int(plain["marks"])])
	check_eq(int(plain["reacquired"]), 0, "nothing was reacquired: each marker could have been either of the two remembered places")
	var swapped := await _two_markers(true)
	check(bool(swapped["lost"]), "the second run: the same, with both hidden when their world ids were exchanged")
	check_eq(swapped["digest"], plain["digest"], "and what the spider knows is exactly the same, whatever the world called them")
