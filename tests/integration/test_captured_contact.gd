extends "res://tests/prey_test_case.gd"

func test_observed_capture_resolves_mark_without_duplicate_food() -> void:
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0))
	var f := add_fly("floor_east_open", 1, true)
	await run_ticks(150)
	var track: String = world.sensor.track_id_for(f.id)
	check(world.memory.get_contact(track) != null, "known before capture")
	await strike_at(4, 11)
	check_eq(f.state, Fly.State.CAPTURED, "captured physically")
	check(world.memory.get_contact(track) == null, "no ghost lost contact")
	check_near(world.needs.granted_total, 0.0, 0.00001, "capture grants no food")
	world.sensor.on_capture({"owner": "spider", "prey": f.id})
	check_eq(director().capture_log.size(), 1, "duplicate notification has no gameplay effect")

func test_capture_does_not_erase_an_old_lost_hypothesis_or_invent_one() -> void:
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0))
	var f := add_fly("floor_east_open", 1, true)
	await run_ticks(100)
	var old: String = world.sensor.track_id_for(f.id)
	world.sensor.enabled = false
	world.memory.advance(world.sensor.tick + 20)
	check(world.memory.get_contact(old).state == ObservationMemory.Contact.LOST, "old hypothesis lost")
	world.sensor.on_capture({"owner": "spider", "prey": f.id})
	check(world.memory.get_contact(old) != null, "world ID did not erase a lost hypothesis")
	var count: int = world.memory.count()
	world.sensor.on_capture({"owner": "spider", "prey": "unseen_fly"})
	check_eq(world.memory.count(), count, "unseen capture invented no visual contact")

func test_bodily_capture_keeps_two_ambiguous_lost_marks() -> void:
	await spawn_prey_world(floor_pose(4, 7.5, 180))
	var f := add_fly("floor_east_open", 1, true)
	await run_ticks(100)
	var old: String = world.sensor.track_id_for(f.id)
	var c: ObservationMemory.Contact = world.memory.get_contact(old)
	var other := Observation.new()
	other.observer_id = "spider"
	other.track_id = "other_hypothesis"
	other.modality = Observation.INSPECTION
	other.has_position = true
	other.estimated_position = c.position + Vector3.RIGHT * 0.1
	other.size_wu = c.size_wu
	other.confidence = 1.0
	other.observed_tick = world.sensor.tick
	world.memory.ingest(other)
	world.sensor.enabled = false
	world.memory.advance(world.sensor.tick + 20)
	world.sensor.on_capture({"owner": "spider", "prey": f.id, "contact_position": f.global_position, "contact_radius": f.profile.radius_wu})
	check(world.memory.get_contact(old) != null, "old world-linked hypothesis not privileged")
	check(world.memory.get_contact("other_hypothesis") != null, "competing mark also retained")
