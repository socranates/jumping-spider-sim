extends "res://tests/sensor_rig_case.gd"
## Who is who (A-027, chunk 7A). Three things are kept apart: the world's id for a thing (how the sensor finds it each tick), the
## contact (the spider's hypothesis that some observations are of one thing) and familiarity (what exposure to a contact taught).
## A contact is kept through unbroken sight and the brief gaps the memory calls justified. After sight is lost, a thing seen again is
## matched to a lost contact only by where that was last observed, how long ago, how big it looked and what it can look like, and
## only when exactly one lost contact could be it; otherwise it is a fresh contact that inherits nothing. Nothing a thing did while
## it was out of sight is read, and the world's id decides nothing once sight has been lost.
##
## The fixtures use the bare rig: balls of 0.25 WU radius 8 WU out, a narrow screen between, the species numbers as shipped (speed bound
## 2 WU/s, size ratio 1.5). A ball walks at 0.8 WU/s, the pace of the test marker. The tick numbers in the comments count from the moment
## the walk begins.

const WALK := 0.8


## A wall that hides the far line around `x` (the shadow of a wall 4 WU out is twice its own span).
func cover_for(x: float, on: bool = true) -> StaticBody3D:
	return add_wall(Vector3(x * 0.5, 0.0, -4.0), Vector3(1.0, 4.0, 0.1), on)


## A ball standing at x on the far line, watched until it is refined to fly-like prey.
func _classified(id: String, x: float) -> Node3D:
	var b := add_ball(id, Vector3(x, 0.0, FAR_Z))
	await run(90)
	var c := contact_of_ball(b)
	check(c != null and c.is_inspected_now() and c.category == Observation.FLY_LIKE_PREY, "%s is in view and refined to fly-like prey" % id)
	return b


## Two look-alikes cross behind the screen from opposite sides, and are frozen as they come out into view on the far sides (tick 210).
## With `swap_ids` the fixture exchanges their world ids at tick 110, when both are hidden and have been lost. Returns what the memory
## holds then, as a player could be shown it, and where the two stand.
func _both_crossing(swap_ids: bool) -> Dictionary:
	rig()
	add_screen()
	var a := await _classified("a", -1.8)
	var b := await _classified("b", 1.8)
	a.velocity = Vector3(WALK, 0.0, 0.0)
	b.velocity = Vector3(-WALK, 0.0, 0.0)
	await run(110)   # both are behind the screen (hidden from tick 74) and were lost at tick 84
	var swapped := false
	if swap_ids:
		var hidden_a := contact_of_ball(a)
		var hidden_b := contact_of_ball(b)
		if check(hidden_a != null and hidden_b != null and not hidden_a.is_live() and not hidden_b.is_live(), "both are lost behind the screen"):
			var keep: String = a.id
			a.id = b.id
			b.id = keep
			swapped = true
	await run(100)   # they come out on the far sides from tick 196
	a.velocity = Vector3.ZERO
	b.velocity = Vector3.ZERO
	await run(1)
	return {"digest": digest(), "a_x": a.position.x, "b_x": b.position.x, "swapped": swapped}


func test_two_look_alikes_cross_behind_cover_and_come_out_as_new_contacts() -> void:
	var r := await _both_crossing(false)
	check(float(r["a_x"]) >= 0.95 and float(r["b_x"]) <= -0.95, "they have crossed and come out: a at %.2f, b at %.2f" % [float(r["a_x"]), float(r["b_x"])])
	var live: Array = memory.live_contacts()
	var marks: Array = memory.marks()
	check_eq(live.size(), 2, "two live contacts, one for each thing in view")
	check_eq(marks.size(), 2, "and the two places they were last seen are still remembered")
	for c: ObservationMemory.Contact in live:
		check_eq(c.reacquisitions, 0, "%s: nothing was reacquired: each thing could have been either, so neither is taken for either" % c.track_id)
		check(c.first_tick > 150, "%s: it began when it came out (tick %d), not when its namesake was first seen" % [c.track_id, c.first_tick])
		check(Observation.rank(c.category) < Observation.rank(Observation.FLY_LIKE_PREY), "%s: it is %s, not fly-like prey: it has only just come out" % [c.track_id, c.category])
	for m: ObservationMemory.Contact in marks:
		check(not m.is_live() and m.has_mark(), "%s: still a mark, left where it was" % m.track_id)
		check_eq(m.category, Observation.FLY_LIKE_PREY, "%s: what was learned stayed with the place" % m.track_id)
	await run(90)
	for c: ObservationMemory.Contact in memory.live_contacts():
		check_eq(c.category, Observation.FLY_LIKE_PREY, "%s: given time it is refined again, from nothing" % c.track_id)


func test_swapping_only_the_hidden_world_ids_changes_nothing_the_player_could_see() -> void:
	var plain := await _both_crossing(false)
	var swapped := await _both_crossing(true)
	check(bool(swapped["swapped"]), "the ids were exchanged while both things were out of sight")
	check_near(float(swapped["a_x"]), float(plain["a_x"]), 1e-9, "with the very same evidence in front of the spider")
	check_eq((swapped["digest"] as Array).size(), (plain["digest"] as Array).size(), "the same number of contacts")
	check_eq(swapped["digest"], plain["digest"], "and the very same contacts: where, when, what and how sure, whatever the world called the things")


func test_a_thing_seen_again_where_only_it_could_be_is_the_one_remembered() -> void:
	rig()
	add_screen()
	var a := await _classified("a", -1.8)
	var c := contact_of_ball(a)
	var track := c.track_id
	a.velocity = Vector3(WALK, 0.0, 0.0)
	await run(95)   # behind the screen from tick 74, lost at 84
	check(not c.is_live() and c.has_mark(), "it was lost behind the screen, with a mark")
	var mark := c.position
	var mark_tick := c.position_tick
	await run(110)   # and out on the far side from tick 196, 2 seconds after it was last seen
	check(a.position.x > 0.85, "it is out on the far side (x = %.2f)" % a.position.x)
	check(c.is_live() and c.reacquisitions == 1, "the one remembered place it could be is the contact: reacquired once")
	check_eq(memory.count(), 1, "and there is no other")
	check(c.position.distance_to(mark) > 1.5 and c.position_tick > mark_tick, "its place was updated by what was seen, %.1f WU from the mark" % c.position.distance_to(mark))
	check_eq(c.category, Observation.FLY_LIKE_PREY, "and it is still known for what it was")
	check_eq(contact_of_ball(a).track_id, track, "the same contact")
	check_eq(c.target_id, "a", "the live link to the world is made again, for interaction")


func test_the_name_does_not_make_a_distant_thing_the_remembered_one() -> void:
	rig()
	var cover := cover_for(-1.9, false)
	var a := await _classified("a", -1.9)
	var old := contact_of_ball(a)
	var mark := old.position
	set_wall(cover, true)
	await run(18)   # hidden for 0.3 s; the memory lost it at tick 10
	check(old.has_mark(), "it is lost, with a mark")
	a.position = Vector3(1.9, 0.0, FAR_Z)   # the same thing, with the same name, is 3.8 WU away when it is next in view
	await run(8)
	var now := contact_of_ball(a)
	check(now != null and now != old and now.is_inspected_now(), "it is a new contact: nothing seen to move that fast could have come so far in 0.3 s")
	check_eq(now.reacquisitions, 0, "not a reacquisition")
	check_eq(now.category, Observation.MOVEMENT, "and it starts again at movement")
	check(old.has_mark() and old.position == mark, "the old mark is untouched, still where it was seen")
	check_eq(memory.count(), 2, "two contacts")
	await run(80)
	check_eq(now.category, Observation.FLY_LIKE_PREY, "which is refined, from nothing, in the time it takes")


func test_the_region_a_lost_thing_could_have_reached_grows_with_the_time() -> void:
	# The same far sighting, 3.8 WU from the mark, is a stranger after 0.3 s and the remembered thing after 2.7 s (the speed bound is
	# 2 WU/s): the region depends on the time and the bound, not on where the thing went.
	rig()
	var cover := cover_for(-1.9)
	set_wall(cover, false)
	var a := await _classified("a", -1.9)
	var c := contact_of_ball(a)
	set_wall(cover, true)
	await run(160)   # hidden for 2.7 s, lost at tick 10 and remembered
	check(not c.is_live() and c.has_mark(), "it is lost behind the cover and remembered")
	a.position = Vector3(1.9, 0.0, FAR_Z)   # while it was hidden, wherever it went: this is the first anyone sees of it
	await run(8)
	check(c.is_live() and c.reacquisitions == 1 and memory.count() == 1, "after 2.7 s a thing 3.8 WU away could be the one remembered, and it is the only one that could")


func test_the_speed_bound_is_the_species_number_and_not_a_guess_in_the_code() -> void:
	# The same two sightings with the bound turned down to a crawl: the thing 3.8 WU away after 2.7 s cannot be the remembered one.
	rig()
	var cover := cover_for(-1.9)
	set_wall(cover, false)
	var a := await _classified("a", -1.9)
	var c := contact_of_ball(a)
	check_near(sensor.contact_speed_bound, 2.0, 1e-9, "the bound is the species profile's")
	sensor.contact_speed_bound = 0.2
	set_wall(cover, true)
	await run(160)
	a.position = Vector3(1.9, 0.0, FAR_Z)
	await run(8)
	var now := contact_of_ball(a)
	check(now != null and now != c and c.reacquisitions == 0, "with a bound of 0.2 WU/s it is a new contact")
	check(c.has_mark() and memory.count() == 2, "and the place it came from is still remembered")


func test_a_thing_that_cannot_look_like_what_was_learned_is_not_the_remembered_one() -> void:
	rig()
	var cover := cover_for(-1.0, false)
	var a := await _classified("a", -1.0)
	var old := contact_of_ball(a)
	set_wall(cover, true)
	await run(20)
	check(old.has_mark(), "lost, with a mark")
	a.max_category = Observation.MOVEMENT   # the same place and size, but something that never looks like prey
	set_wall(cover, false)
	await run(20)
	var now := contact_of_ball(a)
	check(now != null and now != old, "a new contact: what was learned about the old one cannot be true of a thing that is only ever movement")
	check_eq(now.reacquisitions, 0, "not a reacquisition")
	check(old.has_mark(), "and the old mark stays")


func test_a_thing_of_another_size_is_not_the_remembered_one() -> void:
	rig()
	var cover := cover_for(-1.0, false)
	var a := await _classified("a", -1.0)
	var old := contact_of_ball(a)
	set_wall(cover, true)
	await run(20)
	check(old.has_mark(), "lost, with a mark")
	a.radius = 0.5   # twice as big
	set_wall(cover, false)
	await run(20)
	var now := contact_of_ball(a)
	check(now != null and now != old, "a new contact: twice the size is not the same thing")
	check(old.has_mark() and old.reacquisitions == 0, "and the old mark stays")


func test_a_brief_gap_keeps_the_contact_and_a_long_one_does_not() -> void:
	rig()
	var cover := cover_for(-1.0, false)
	var a := await _classified("a", -1.0)
	var c := contact_of_ball(a)
	var track := c.track_id
	var lost := [0]
	memory.contact_lost.connect(func(_c: ObservationMemory.Contact) -> void: lost[0] += 1)
	set_wall(cover, true)
	await run(6)   # hidden for 0.1 s, inside the 0.15 s the memory holds an inspection for
	set_wall(cover, false)
	await run(10)
	check(contact_of_ball(a) == c and c.track_id == track and c.is_live(), "after a gap of 6 ticks it is the same contact, still live")
	check_eq(lost[0], 0, "which was never lost")
	check_eq(c.reacquisitions, 0, "and not reacquired")
	check_eq(c.category, Observation.FLY_LIKE_PREY, "it is still known for what it was")
	set_wall(cover, true)
	await run(14)   # 0.23 s: past the hold
	set_wall(cover, false)
	await run(10)
	check_eq(lost[0], 1, "a longer gap loses it")
	check(c.is_live() and c.reacquisitions == 1 and memory.count() == 1, "and it is found again by the evidence (the one place it could be): reacquired once")


func test_a_loss_of_sight_never_updates_the_remembered_place() -> void:
	rig()
	add_screen()
	var a := await _classified("a", -1.8)
	var c := contact_of_ball(a)
	a.velocity = Vector3(WALK, 0.0, 0.0)
	await run(95)
	check(not c.is_live() and c.has_mark(), "behind the screen it is lost")
	var place := c.position
	var tick := c.position_tick
	var speed := c.speed_wu_s
	var cat := c.category
	await run(30)
	a.id = "someone_else"   # and the world gives it another name while it is hidden
	await run(30)
	check(a.position.x > -0.8 and a.position.x < 0.8, "it is still behind the screen (x = %.2f), going on" % a.position.x)
	check(c.position == place and c.position_tick == tick and c.speed_wu_s == speed, "the remembered place is exactly where it was seen, with the tick and the speed it was seen at")
	check_eq(c.category, cat, "and the category is what it was")
	check_eq(c.target_id, "", "the contact holds no link to the world: there is nothing for the world to update")
	check_eq(c.reacquisitions, 0, "and it has not been reacquired")


func test_the_live_link_to_the_world_ends_with_the_sight() -> void:
	rig()
	var a := await _classified("a", -1.0)
	var c := contact_of_ball(a)
	check_eq(c.target_id, "a", "while it is in view and refined, the contact is linked to the world's id for it, for interaction")
	a.enabled = false
	await run(20)
	check(not c.is_live(), "lost")
	check_eq(c.target_id, "", "the link is gone with the sight")


func test_a_mark_is_dropped_when_its_place_is_seen_empty_and_a_hidden_one_is_not() -> void:
	rig()
	var a := await _classified("a", -1.8)   # in plain view
	var c := contact_of_ball(a)
	a.enabled = false
	await run(120)
	check_eq(memory.marks().size(), 0, "the place in plain view was seen empty for long enough: dropped")
	check_eq(ended, ["%s:empty" % c.track_id] as Array[String], "because it was empty")
	# The same, behind a cover: nothing can be said about a place that is hidden.
	var cover := cover_for(-1.8, false)
	var b := add_ball("b", Vector3(-1.8, 0.0, FAR_Z))
	await run(90)
	var d := contact_of_ball(b)
	check(d != null and d.category == Observation.FLY_LIKE_PREY, "another is refined in plain view")
	set_wall(cover, true)
	await run(20)
	check(not d.is_live() and d.has_mark(), "behind the cover it is lost, with a mark")
	b.enabled = false
	await run(150)
	check(d.has_mark(), "two and a half seconds of looking at the cover: the place behind it is not called empty")


func test_a_thing_gone_from_the_world_is_forgotten_by_the_sensor_but_its_mark_expires_on_its_own() -> void:
	rig()
	var cover := cover_for(-1.8, false)
	var a := await _classified("a", -1.8)
	var c := contact_of_ball(a)
	check(sensor.get_track("a") != null, "the sensor keeps a track of the thing while it is there")
	set_wall(cover, true)
	await run(20)
	check(not c.is_live() and c.has_mark(), "it is hidden and lost, with a mark")
	balls.erase(a)
	a.free()
	await run(2)
	check(sensor.get_track("a") == null and sensor.tracks().is_empty(), "the thing left the world: the sensor's track of it is gone (A-029)")
	check(c.has_mark() and memory.count() == 1, "the mark is not touched by that")
	await run(300)
	check(c.has_mark(), "it is still there after five seconds: it fades on the memory's clock, not the world's")
	await run(80)
	check_eq(ended, ["%s:expired" % c.track_id] as Array[String], "and expires when the memory lets go of it, after 6 s")
	var again := add_ball("a", Vector3(-1.8, 0.0, FAR_Z))   # a new thing that happens to have the old name
	set_wall(cover, false)
	await run(10)
	var fresh := contact_of_ball(again)
	check(fresh != null and fresh.first_tick > c.lost_tick and fresh.category == Observation.MOVEMENT, "is a stranger: nothing of the old track is left to be carried over")


func test_a_thing_seen_only_in_the_periphery_never_joins_a_lost_contact() -> void:
	# A thing moving in the periphery is only a bearing. It never takes back a lost contact, whatever its name was.
	rig()
	var cover := cover_for(-1.8, false)
	var a := await _classified("a", -1.8)
	var old := contact_of_ball(a)
	set_wall(cover, true)
	await run(20)
	check(not old.is_live() and old.has_mark(), "hidden and lost, with a mark")
	var cues := old.cue_count
	a.position = Vector3(5.0, 0.0, -2.0)   # far outside the cone, in the periphery, and walking
	a.velocity = Vector3(0.0, 0.0, 1.0)
	await run(70)
	var cued := contact_of_ball(a)
	check(cued != null and cued != old, "its movement made a contact of its own")
	check(not cued.has_position and cued.cue_count >= 1, "known from a bearing only")
	check_eq(old.cue_count, cues, "the lost contact received none of the cues")
	check(old.has_mark() and old.reacquisitions == 0, "and was not reacquired")


# ------------------------------------------------------------------ several sightings in one tick (chunk 7B, two flies)

## What a player could be shown of the contacts, sorted by place, without the sensor's serial ids: the order the world lists things in
## shows nowhere in it.
func _by_place() -> Array:
	var out: Array = []
	for c: ObservationMemory.Contact in memory.contacts():
		out.append({"x": snappedf(c.position.x, 0.001), "state": c.state, "category": c.category, "reacq": c.reacquisitions, "first": c.first_tick})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["x"]) < float(b["x"]))
	return out


## One remembered place, two look-alikes that come into view at once and either of which could be the thing: `first` is the one the
## world lists first.
func _two_could_be_it(first: String) -> Array:
	rig()
	var cover := cover_for(-1.8, false)
	var a := await _classified("a", -1.8)
	var old := contact_of_ball(a)
	set_wall(cover, true)
	await run(20)
	check(not old.is_live() and old.has_mark(), "the thing is lost behind the cover, with a mark")
	a.enabled = false
	var where := {"p": -1.4, "q": -2.0}
	var order := ["p", "q"] if first == "p" else ["q", "p"]
	for id: String in order:
		add_ball(id, Vector3(float(where[id]), 0.0, FAR_Z))
	set_wall(cover, false)
	await run(8)
	var p := contact_of_ball(balls[balls.size() - 1 if first == "q" else balls.size() - 2])
	var q := contact_of_ball(balls[balls.size() - 2 if first == "q" else balls.size() - 1])
	check(p != null and q != null and p != q, "each look-alike is a contact")
	check(p != old and q != old, "and neither is the remembered one: either could have been it, so neither is taken for it")
	check_eq(p.reacquisitions + q.reacquisitions + old.reacquisitions, 0, "nothing was reacquired")
	check(old.has_mark(), "the remembered place stays, left where it was seen")
	return _by_place()


func test_two_look_alikes_that_come_into_view_together_are_strangers_whatever_order_they_are_listed_in() -> void:
	var pq := await _two_could_be_it("p")
	var qp := await _two_could_be_it("q")
	check_eq(pq.size(), 3, "three contacts: the old place and the two newcomers")
	check_eq(qp, pq, "the very same contacts whichever of them the sensor handles first")


func test_a_thing_that_fits_one_place_alone_still_takes_it_while_a_stranger_is_in_view() -> void:
	rig()
	var cover := cover_for(-1.8, false)
	var a := await _classified("a", -1.8)
	var old := contact_of_ball(a)
	set_wall(cover, true)
	await run(20)
	a.enabled = false
	var near := add_ball("p", Vector3(-1.5, 0.0, FAR_Z))
	var far := add_ball("q", Vector3(1.9, 0.0, FAR_Z))   # 3.7 WU from the mark: farther than anything unseen for 0.3 s could have come
	set_wall(cover, false)
	await run(8)
	check(old.is_live() and old.reacquisitions == 1, "the one that could only be the remembered thing is it")
	check_eq(contact_of_ball(near), old, "filed under the old contact")
	var stranger := contact_of_ball(far)
	check(stranger != null and stranger != old and stranger.reacquisitions == 0, "the other, nowhere near, is a new contact")


## Two remembered places; one newcomer that fits only the first and one that fits both.
func _asymmetric(first: String) -> Array:
	rig()
	var cover_a := cover_for(-1.8, false)
	var cover_b := cover_for(1.8, false)
	var a := await _classified("a", -1.8)
	var b := await _classified("b", 1.8)
	set_wall(cover_a, true)
	set_wall(cover_b, true)
	await run(44)   # about 0.75 s since either was last observed: the region each could have reached is about 2 WU wide
	check(memory.marks().size() == 2, "both are lost, with marks")
	a.enabled = false
	b.enabled = false
	var where := {"p": -1.6, "q": 0.0}
	var order := ["p", "q"] if first == "p" else ["q", "p"]
	for id: String in order:
		add_ball(id, Vector3(float(where[id]), 0.0, FAR_Z))
	set_wall(cover_a, false)
	set_wall(cover_b, false)
	await run(6)
	var live: Array = memory.live_contacts()
	check_eq(live.size(), 2, "two newcomers are in view")
	for c: ObservationMemory.Contact in live:
		check_eq(c.reacquisitions, 0, "nothing was reacquired: the one near the first place could be it, but so could the one between the two, and a place cannot be both")
	check_eq(memory.marks().size(), 2, "and both remembered places are still there")
	return _by_place()


func test_a_place_two_newcomers_could_each_be_is_taken_by_neither_in_whatever_order() -> void:
	var pq := await _asymmetric("p")
	var qp := await _asymmetric("q")
	check_eq(qp, pq, "the same contacts whichever is handled first")
