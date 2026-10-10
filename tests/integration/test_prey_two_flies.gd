extends "res://tests/prey_test_case.gd"
## Chunk 7B, milestone 9, two flies at once (A-027, A-028). Two look-alike flies cannot be told apart by anything the spider has seen of
## them: when both are lost behind cover and both come out again at places either could have reached, each is a stranger and neither is
## taken for either, whatever the world calls them; a lone fly that comes back to where only it could be is the one remembered, whatever
## the world calls it now; and the flies do not tell each other anything: what one fly takes in and does is the same whether or not another
## fly is there, and a fly that cannot see the spider is not moved by a fly that can.
## The spider stands 10 WU south of two flies 4.2 WU apart, both inside its 30 degree focus cone; a wall 4 WU high across the line of sight
## hides both, and the fixtures move them (or rename them) only while they are hidden.

const SPIDER_AT := Vector3(4.0, 0.0, 12.0)
const A_AT := Vector3(1.9, 0.0, 2.0)
const B_AT := Vector3(6.1, 0.0, 2.0)
const COVER := "two_flies_cover"


func _scene(with_b: bool = true) -> Array:
	await spawn_prey_world(floor_pose(SPIDER_AT.x, SPIDER_AT.z, 0.0), 0, 51)
	director().ensure_ready()
	var graph: PerchGraph = director().graph
	var space := world.get_world_3d().direct_space_state
	var pa := graph.add_perch({"id": "two_a", "position": A_AT, "normal": Vector3.UP, "fixture": true, "shelter": 0.1})
	var pb := graph.add_perch({"id": "two_b", "position": B_AT, "normal": Vector3.UP, "fixture": true, "shelter": 0.1})
	check_eq(graph.validate_perch(space, pa, director().profile), "", "perch A is valid")
	check_eq(graph.validate_perch(space, pb, director().profile), "", "perch B is valid")
	world.lab.add_fixture_piece(COVER, "wall", Vector3(0.5, 0.0, 6.9), Vector3(7.5, 4.0, 7.2))
	world.lab.set_piece_enabled(COVER, false)
	await physics_frames(3)
	var a := add_fly("two_a", 61, true)
	var b: Node3D = add_fly("two_b", 62, true) if with_b else null
	await run_ticks(100)
	return [a, b, pa, pb]


func _contact_of(f: Node3D) -> ObservationMemory.Contact:
	var id: String = world.sensor.track_id_for(f.id)
	return null if id == "" else world.memory.get_contact(id)


## What a player could be shown of the memory, without any id of the world.
func _digest() -> Array:
	var out: Array = []
	for c: ObservationMemory.Contact in world.memory.contacts():
		var d: Dictionary = c.to_dict()
		d.erase("target_id")
		d["reacquisitions"] = c.reacquisitions
		d["size_wu"] = c.size_wu
		out.append(d)
	return out


func _rename(f: Node3D, new_id: String) -> void:
	f.id = new_id
	f.name = new_id


## Both flies are seen and known, hidden behind the wall for `hidden_s`, exchanged between their two perches (and, with `swap_ids`, between
## their names) while hidden, and shown again for 40 ticks.
func _swap_run(swap_ids: bool, hidden_s: float) -> Dictionary:
	var s := await _scene()
	var a: Node3D = s[0]
	var b: Node3D = s[1]
	var pa: PerchGraph.Perch = s[2]
	var pb: PerchGraph.Perch = s[3]
	var ca := _contact_of(a)
	var cb := _contact_of(b)
	var known := ca != null and cb != null and ca.is_inspected_now() and cb.is_inspected_now() and ca.category == Observation.FLY_LIKE_PREY and cb.category == Observation.FLY_LIKE_PREY
	check(known, "both flies are in view and known as fly-like prey before the wall comes up")
	world.lab.set_piece_enabled(COVER, true)
	await run_ticks(int(hidden_s * 60.0 * 0.5))
	var lost := ca != null and cb != null and not ca.is_live() and not cb.is_live() and ca.has_mark() and cb.has_mark()
	check(lost, "behind the wall both are lost, each leaving a mark where it was last seen")
	var now: float = director().now
	pa.occupant = ""
	pb.occupant = ""
	a.place_on(pb, now)
	b.place_on(pa, now)
	if swap_ids:
		var keep: String = a.id
		_rename(a, b.id)
		_rename(b, keep)
	await run_ticks(int(hidden_s * 60.0 * 0.5))
	world.lab.set_piece_enabled(COVER, false)
	await run_ticks(40)
	return {"digest": _digest(), "live": world.memory.live_contacts().size(), "marks": world.memory.marks().size(), "ids": [a.id, b.id]}


func test_two_look_alikes_exchanged_while_hidden_come_out_as_strangers_whatever_they_are_called() -> void:
	var plain := await _swap_run(false, 3.0)
	await _free_scene()
	var swapped := await _swap_run(true, 3.0)
	await _free_scene()
	check_eq(int(plain["live"]), 2, "two live contacts, one for each fly in view")
	check_eq(int(plain["marks"]), 2, "and the two places they were last seen are still remembered")
	for c: Dictionary in plain["digest"]:
		if str(c["state"]) == str(ObservationMemory.Contact.LIVE):
			check_eq(int(c["reacquisitions"]), 0, "%s: nothing was reacquired: each fly could have been either, so neither is taken for either" % str(c["track_id"]))
	check_eq((swapped["ids"] as Array)[0], (plain["ids"] as Array)[1], "the world's names were exchanged in the second run")
	check_eq(swapped["digest"], plain["digest"], "and the memory is exactly the same: where, when, what and how sure, whatever the world called the flies")


func test_a_lone_fly_that_comes_back_where_only_it_could_be_is_the_one_remembered_under_any_name() -> void:
	var s := await _scene(false)   # only fly A is in the picture
	var a: Node3D = s[0]
	var ca := _contact_of(a)
	check(ca != null and ca.is_inspected_now(), "fly A is in view and known")
	var track := ca.track_id if ca != null else ""
	world.lab.set_piece_enabled(COVER, true)
	await run_ticks(150)
	check(ca != null and not ca.is_live() and ca.has_mark(), "hidden behind the wall it is lost, with a mark")
	_rename(a, "fly_77")
	world.lab.set_piece_enabled(COVER, false)
	await run_ticks(40)
	var now_c := _contact_of(a)
	check(now_c != null and now_c.track_id == track, "the one remembered place it could be is its contact: the same track, under a name the player was never told")
	check(now_c != null and now_c.is_live() and now_c.reacquisitions == 1, "reacquired once")
	check(now_c != null and now_c.target_id == "fly_77", "and the live link to the world is made again under the name it has now")


func test_what_a_fly_takes_in_does_not_depend_on_another_fly_being_there() -> void:
	var with_a := await _witness_run(true)
	var without_a := await _witness_run(false)
	check(int(with_a["cut"]) > 20, "the witness is alerted by the spider on its own account (it takes off after %d ticks)" % int(with_a["cut"]))
	check(float(with_a["peak"]) > 0.3, "and its awareness climbs well (%.2f)" % float(with_a["peak"]))
	check_eq(int(with_a["a_flights"]), 1, "while the other fly flees right beside it")
	check_eq(with_a["cut"], without_a["cut"], "it takes off at the very same tick whether the other fly is there or not")
	check_eq((with_a["series"] as Array).slice(0, int(with_a["cut"])), (without_a["series"] as Array).slice(0, int(without_a["cut"])), "and every tick of its awareness and state up to then is the same")


## The spider walks up to fly A; fly B sits 5 WU to the side of the path and watches. In the other run fly A is absent (it still takes a serial
## number, so B's decisions are staggered the same way: the stagger is by serial and not a message).
func _witness_run(with_a: bool) -> Dictionary:
	await spawn_prey_world(floor_pose(4.0, 2.0, 180.0), 0, 5)
	director().ensure_ready()
	var graph: PerchGraph = director().graph
	var space := world.get_world_3d().direct_space_state
	var pa := graph.add_perch({"id": "wit_a", "position": Vector3(4.0, 0.0, 11.0), "normal": Vector3.UP, "fixture": true})
	var pb := graph.add_perch({"id": "wit_b", "position": Vector3(8.0, 0.0, 9.0), "normal": Vector3.UP, "fixture": true})
	check_eq(graph.validate_perch(space, pa, director().profile), "", "A's perch is valid")
	check_eq(graph.validate_perch(space, pb, director().profile), "", "B's perch is valid")
	var a: Node3D = null
	if with_a:
		a = add_fly("wit_a", 11)
	else:
		director().serial_counter += 1
	var b := add_fly("wit_b", 12)
	var series := []
	var peak := [0.0]
	var note := func() -> void:
		series.append("%.5f %s" % [b.senses.awareness, b.state_name()])
		peak[0] = maxf(float(peak[0]), b.senses.awareness)
	await walk_toward(Vector3(4.0, 0.0, 11.0), WALK, 1.0, 60 * 5, note)
	await run_ticks(30, note)
	var cut := series.size()
	for i in series.size():
		if str(series[i]).contains("TAKEOFF"):
			cut = i
			break
	var out := {"series": series, "cut": cut, "peak": float(peak[0]), "a_flights": a.flight.flights_total if a != null else -1}
	await _free_scene()
	return out


func test_a_fly_that_cannot_see_the_spider_is_not_moved_by_one_that_can() -> void:
	await spawn_prey_world(floor_pose(4.0, 2.0, 180.0), 0, 5)
	director().ensure_ready()
	var graph: PerchGraph = director().graph
	var space := world.get_world_3d().direct_space_state
	var pa := graph.add_perch({"id": "seen_a", "position": Vector3(4.0, 0.0, 11.0), "normal": Vector3.UP, "fixture": true})
	var pb := graph.add_perch({"id": "hidden_b", "position": Vector3(7.0, 0.0, 9.5), "normal": Vector3.UP, "fixture": true})
	world.lab.add_fixture_piece("hide_b", "wall", Vector3(5.5, 0.0, 3.0), Vector3(5.8, 4.0, 13.0))
	await physics_frames(3)
	check_eq(graph.validate_perch(space, pa, director().profile), "", "A's perch is valid")
	check_eq(graph.validate_perch(space, pb, director().profile), "", "B's perch is valid")
	var a := add_fly("seen_a", 11)
	var b := add_fly("hidden_b", 12)
	var worst := [0.0]
	var note := func() -> void: worst[0] = maxf(float(worst[0]), b.senses.awareness)
	await walk_toward(Vector3(4.0, 0.0, 11.0), WALK, 1.0, 60 * 5, note)
	await run_ticks(120, note)
	check(a.flight.flights_total >= 1, "fly A saw the spider coming and left (%d flights)" % a.flight.flights_total)
	check_near(float(worst[0]), 0.0, 1.0e-12, "fly B, behind its wall, took in nothing at all")
	check_eq(b.trace.size(), 0, "and has not changed state once")
	check_eq(b.flight.flights_total, 0, "it never left its perch, though the fly beside it did")
	await _free_scene()


func _free_scene() -> void:
	world.queue_free()
	await physics_frames(2)
