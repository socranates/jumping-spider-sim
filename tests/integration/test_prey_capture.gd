extends "res://tests/prey_test_case.gd"
## Chunk 7B, milestone 6: spatial capture. A strike is a jump; during it every living fly is tested against the spider's path in the
## tick (the closest approach of two straight moves, exact), once, in id order. A capture has a stable event id and an owner, turns the
## prey CAPTURED at that moment and gives the spider something to hold; it grants nothing else. What the spider has classified never
## matters: a strike at a fly it has not identified catches it, a strike that does not reach a fly it knows well does not. Nothing is
## caught through a wall. Only one prey is held at a time.


func test_a_strike_that_reaches_a_fly_catches_it_once() -> void:
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0))
	var f := add_fly("floor_east_open", 1, true)
	var p := perch("floor_east_open")
	var events: Array[Dictionary] = []
	director().captured.connect(func(e: Dictionary) -> void: events.append(e))
	await strike_at(4.0, 11.0)
	check_eq(director().capture_log.size(), 1, "exactly one capture is on record")
	check_eq(events.size(), 1, "and it was announced once")
	check_eq(str(events[0]["id"]), "capture:spider:fly_1", "its event id is stable and says who took what")
	check_eq(str(events[0]["owner"]), "spider", "the spider owns it")
	check_eq(f.state, Fly.State.CAPTURED, "the prey is CAPTURED")
	check_eq(f.captured_by, "spider", "it knows whose it is")
	check_eq(f.capture_event_id, "capture:spider:fly_1", "and under which event")
	check_eq(director().held, f, "the spider holds it")
	check_eq(p.occupant, "", "its perch is free")
	check(f.get_percept().is_empty(), "a captured fly gives no percept")
	check_eq(world.sensor.track_id_for("fly_1"), "", "the sensor has dropped its channel to it (A-029)")
	check(float(events[0]["distance"]) <= director().strike_reach(), "it was within reach (%.2f of %.2f WU)" % [float(events[0]["distance"]), director().strike_reach()])
	await run_ticks(90)
	check_eq(director().capture_log.size(), 1, "nothing is captured twice")
	check_eq(director().refused_log.size(), 0, "and nothing was refused")
	check_eq(f.state, Fly.State.CAPTURED, "it stays captured")
	check(f.global_position.distance_to(world.spider.get_eye_position()) < 0.6, "carried at the mouth (%.2f WU)" % f.global_position.distance_to(world.spider.get_eye_position()))


func test_classification_never_gates_astrike_at() -> void:
	# the spider has not looked at the fly at all (it faces away): the strike catches it
	await spawn_prey_world(floor_pose(4.0, 7.5, 0.0))
	var f := add_fly("floor_east_open", 1, true)
	await physics_frames(10)
	check_eq(world.sensor.track_id_for("fly_1"), "", "it has not sensed the fly (it faces away)")
	await strike_at(4.0, 11.0)
	check_eq(f.state, Fly.State.CAPTURED, "an unidentified fly is caught all the same")
	# the spider knows another fly well, and strikes just short of it: nothing is caught
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0))
	var g := add_fly("floor_east_open", 1, true)
	await run_ticks(150)
	var track: String = world.sensor.track_id_for("fly_1")
	var contact: ObservationMemory.Contact = world.memory.get_contact(track)
	check(contact != null and contact.category == Observation.FLY_LIKE_PREY, "this one the spider has identified as fly-like prey")
	await strike_at(4.0, 9.7)
	check_eq(g.state, Fly.State.PERCHED, "but a strike that stops 1.3 WU short does not catch it")
	check_eq(director().capture_log.size(), 0, "no capture on record")


func test_the_reach_is_the_bodies_together_and_assist_widens_it() -> void:
	for assisted: bool in [false, true]:
		await spawn_prey_world(floor_pose(4.0, 7.5, 180.0))
		director().assist = assisted
		var f := add_fly("floor_east_open", 1, true)
		check_near(director().strike_reach(), (0.4 + 0.3) * (1.6 if assisted else 1.0), 1.0e-6, "the reach: capture radius plus body radius%s" % (" times the assist scale" if assisted else ""))
		await strike_at(4.0 + 0.9, 11.0)   # lands 0.9 WU to the side of the fly
		check_eq(f.state == Fly.State.CAPTURED, assisted, "a strike 0.9 WU wide %s (assist %s)" % ["catches it" if assisted else "misses", str(assisted)])
		world.queue_free()
		await physics_frames(2)


func test_nothing_is_caught_through_a_wall() -> void:
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0))
	var f := add_fly("floor_east_open", 1, true)
	# a thin wall between the spider's path and the fly: a strike that ends 0.65 WU from the fly, on the other side of it
	world.lab.add_fixture_piece("thin_wall", "wall", Vector3(3.3, 0.0, 9.0), Vector3(4.7, 3.0, 9.1))
	await physics_frames(3)
	director().strike_active = true
	director().strike_started_tick = director().tick
	world.spider.teleport_to(floor_spawn(4.0, 8.6, 180.0))
	await physics_frames(3)
	check(f.global_position.distance_to(world.spider.global_position) < 2.6, "it is close")
	director().strike_active = false
	check_eq(f.state, Fly.State.PERCHED, "a wall between them: nothing is caught")
	# the same path with no wall between catches it
	world.lab.set_piece_enabled("thin_wall", false)
	await physics_frames(3)
	director().strike_active = true
	director().strike_started_tick = director().tick
	world.spider.teleport_to(floor_spawn(4.0, 10.5, 180.0))
	await physics_frames(2)
	check_eq(f.state, Fly.State.CAPTURED, "and with the way clear it is caught")


func test_only_one_prey_is_held_and_the_second_is_refused() -> void:
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0))
	var a := add_fly("floor_east_open", 1, true)
	# a second fly sits on a perch added next to the first
	var q: PerchGraph.Perch = director().graph.add_perch({"id": "twin", "position": Vector3(4.5, 0.0, 11.0), "normal": Vector3.UP, "fixture": true})
	check_eq(director().graph.validate_perch(world.get_world_3d().direct_space_state, q, director().profile), "", "the second perch is fine")
	var b := add_fly("twin", 2, true)
	await strike_at(4.25, 11.0)
	check_eq(a.state, Fly.State.CAPTURED, "the lower id is resolved first and caught")
	check_eq(b.state, Fly.State.PERCHED, "the other is not: the jaws are full")
	check_eq(director().capture_log.size(), 1, "one capture")
	check_eq(director().refused_log.size() >= 1, true, "and the refusal is on record")
	check_eq(str(director().refused_log[0]["prey"]), "fly_2", "for the second fly")
