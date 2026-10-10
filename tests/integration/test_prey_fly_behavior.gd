extends "res://tests/prey_test_case.gd"
## Chunk 7B, milestones 4 and 5: the fly's mind and its flight. A fly that is walked up to notices, stays on alert, takes off after a reaction
## delay, flees to a perch far from where it last saw the thing and lands; every step is a logged transition with a reason, no step is a jump.
## A fly that is only watched settles again. A restless fly moves on by itself, to a better place, and a danger it sees interrupts the flight.
## A flight that is blocked is re-planned and the fly still never jumps. A perch the world refuses is never used. A perch that leaves the
## world under a fly sends it off.

const PreyMath = preload("res://scripts/prey/prey_math.gd")


func _names(f: Node3D) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in f.trace:
		out.append(str(e["to"]))
	return out


func _walk_in_and_wait(f: Node3D, start_x: float = -5.0) -> void:
	f.face(Vector3.LEFT)
	await walk_toward(f.global_position, WALK, 1.0, 900)
	await wait_until(func() -> bool: return f.state == Fly.State.PERCHED and f.flight.landings_total >= 1, 60 * 8)


func test_a_fly_that_is_walked_up_to_notices_it_leaves_and_every_step_has_a_reason() -> void:
	await spawn_prey_world(floor_pose(-5.0, 11.0, -90.0))
	var f := add_fly("floor_east_open", 3)
	var origin := perch("floor_east_open")
	await _walk_in_and_wait(f)
	var names := _names(f)
	check_eq(names.slice(0, 6), ["ALERT", "TAKEOFF", "FLEE", "SEEK_PERCH", "PERCHED"] as Array[String], "it notices, takes off, flees, eases in and lands (got %s)" % str(names))
	for e: Dictionary in f.trace:
		check(str(e["reason"]).length() > 20, "every transition says why: %s -> %s: %s" % [e["from"], e["to"], e["reason"]])
	var first: Dictionary = f.trace[0]
	check(str(first["reason"]).begins_with("noticed"), "it noticed first: %s" % first["reason"])
	var took_off: Dictionary = f.trace[1]
	check(str(took_off["reason"]).contains("reaction delay"), "the take-off waited out a reaction delay: %s" % took_off["reason"])
	check(float(took_off["t"]) - float(first["t"]) >= 0.2, "the alert posture lasted long enough to be seen (%.2f s)" % (float(took_off["t"]) - float(first["t"])))
	check(f.perch != origin, "it landed somewhere else (%s)" % f.perch.id)
	check(f.perch.position.distance_to(world.spider.global_position) >= f.profile.perch_avoid_wu, "and not near the spider (%.1f WU)" % f.perch.position.distance_to(world.spider.global_position))
	check_eq(origin.occupant, "", "the perch it left is free")
	check_eq(f.perch.occupant, f.id, "the one it landed on knows it")
	check(f.flight.max_step <= f.profile.flee_speed_wu_s / 60.0 * 1.02, "it never moved more than its top speed allows in a tick (%.3f WU)" % f.flight.max_step)
	check_eq(f.flight.replans, 0, "and needed no re-plan")


func test_a_fly_that_is_only_watched_settles_again() -> void:
	await spawn_prey_world(floor_pose(-5.0, 11.0, -90.0))
	var f := add_fly("floor_east_open", 3)
	f.face(Vector3.LEFT)
	await walk_toward(f.global_position, WALK, 1.0, 900, Callable(), func() -> bool: return f.state == Fly.State.ALERT)
	check_eq(f.state, Fly.State.ALERT, "it went on alert")
	world.spider.set_intent(Vector3.ZERO, false)
	await wait_until(func() -> bool: return f.state == Fly.State.PERCHED, 60 * 8)
	check_eq(f.state, Fly.State.PERCHED, "and settled again with the spider standing still")
	check_eq(f.perch.id, "floor_east_open", "without having gone anywhere")
	var last: Dictionary = f.trace[f.trace.size() - 1]
	check(str(last["reason"]).begins_with("relaxed"), "it says it relaxed: %s" % last["reason"])


func test_a_restless_fly_moves_on_by_itself_to_a_better_place() -> void:
	await spawn_prey_world(floor_pose(-22.0, 12.0, -90.0))
	var f := add_fly("floor_east_open", 11)
	f.perched_since = -200.0   # it has sat here a very long time
	await wait_until(func() -> bool: return f.flight.landings_total >= 1, 60 * 12)
	check_eq(f.flight.landings_total, 1, "it moved")
	var names := _names(f)
	check_eq(names.slice(0, 2), ["REPOSITION", "PERCHED"] as Array[String], "REPOSITION then PERCHED (got %s)" % str(names))
	check(str(f.trace[0]["reason"]).contains("utility: move wins"), "its reason was the utility: %s" % f.trace[0]["reason"])
	check(f.perch.id != "floor_east_open" and (f.perch.food > 0.0 or f.perch.shelter > 0.1), "to a place with more going for it (%s, food %.1f, shelter %.1f)" % [f.perch.id, f.perch.food, f.perch.shelter])
	await physics_frames(60)
	check_eq(f.state, Fly.State.PERCHED, "and it stays there for a while (min commitment %.1f s)" % f.profile.min_commit_s)
	check(f.flight.max_step <= f.profile.cruise_speed_wu_s / 60.0 * 1.05, "a gentle flight, no jumps (%.3f WU a tick)" % f.flight.max_step)


func test_a_danger_it_sees_in_flight_interrupts_the_flight() -> void:
	await spawn_prey_world(floor_pose(-22.0, 12.0, -90.0))
	var f := add_fly("floor_east_open", 11)
	f.perched_since = -200.0
	await wait_until(func() -> bool: return f.state == Fly.State.REPOSITION and f.flight.s > 0.5, 60 * 12)
	check_eq(f.state, Fly.State.REPOSITION, "it set off")
	# the spider appears 4 WU along the way (on the floor, out of the fly's sight until now) and walks at it
	var ahead: Vector3 = PreyMath.point_at(f.flight.path, f.flight.s + 4.0)
	world.spider.teleport_to(Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(ahead.x, 0.31, ahead.z)))
	await settle(world.spider)
	await walk_toward(f.global_position, WALK, 0.5, 90, Callable(), func() -> bool: return f.state != Fly.State.REPOSITION)
	await wait_until(func() -> bool: return f.state != Fly.State.REPOSITION, 60)
	check(f.state != Fly.State.REPOSITION, "it did not carry on (%s)" % f.state_name())
	var seen := false
	for e: Dictionary in f.trace:
		if str(e["from"]) == "REPOSITION" and str(e["to"]) == "FLEE":
			seen = true
			check(str(e["reason"]).contains("danger in flight") or str(e["reason"]).contains("startle"), "the reason says so: %s" % e["reason"])
	check(seen, "REPOSITION -> FLEE is in the trace (got %s)" % str(_names(f)))


func test_a_blocked_flight_is_replanned_and_the_fly_never_jumps() -> void:
	await spawn_prey_world(floor_pose(-22.0, 12.0, -90.0))
	var f := add_fly("floor_east_open", 11)
	f.perched_since = -200.0
	await wait_until(func() -> bool: return f.state == Fly.State.REPOSITION and f.flight.s > 0.8, 60 * 12)
	check_eq(f.state, Fly.State.REPOSITION, "it is under way")
	var target_id: String = f.flight.target.id
	# a wall appears across the path, in front of the fly
	var ahead: Vector3 = PreyMath.point_at(f.flight.path, f.flight.s + 2.0)
	world.lab.add_fixture_piece("late_wall", "wall", Vector3(ahead.x - 0.3, 0.0, ahead.z - 3.0), Vector3(ahead.x + 0.3, 9.0, ahead.z + 3.0))
	await wait_until(func() -> bool: return f.state == Fly.State.PERCHED, 60 * 12)
	check_eq(f.state, Fly.State.PERCHED, "it still got somewhere")
	check_eq(f.flight.replans_total, 1, "it re-planned over the wall and carried on to the same perch")
	check_eq(f.flight.retargets_total, 0, "without having to give the perch up")
	check(f.flight.max_step <= f.profile.cruise_speed_wu_s / 60.0 * 1.05 + 1.0e-6, "and never moved more than its speed allows in a tick (%.3f WU)" % f.flight.max_step)
	check(not director().graph.overlaps(world.get_world_3d().direct_space_state, f.global_position, f.profile.clearance_radius_wu), "it is not inside anything")
	check_eq(f.perch.id, target_id, "and landed where it was going")


func test_perch_validation_refuses_blocked_perches() -> void:
	await spawn_prey_world(floor_pose(-22.0, 12.0, -90.0))
	check(director().ensure_ready(), "ready")
	var graph: PerchGraph = director().graph
	var profile: PreyProfile.Profile = director().profile
	var space := world.get_world_3d().direct_space_state
	world.lab.add_fixture_piece("low_slab", "ledge", Vector3(14.0, 0.2, -14.0), Vector3(16.0, 0.5, -12.0))
	world.lab.add_fixture_piece("low_ceiling", "ledge", Vector3(17.0, 0.6, -14.0), Vector3(19.0, 0.8, -12.0))
	await physics_frames(3)
	space = world.get_world_3d().direct_space_state
	var cases := {
		"under_slab": {"position": Vector3(15.0, 0.0, -13.0), "normal": Vector3.UP, "want": "blocked_at_rest"},
		"under_ceiling": {"position": Vector3(18.0, 0.0, -13.0), "normal": Vector3.UP, "want": "no_room_to_lift"},
		"in_the_air": {"position": Vector3(0.0, 1.5, 14.0), "normal": Vector3.UP, "want": "no_surface"},
	}
	for key: String in cases:
		var c: Dictionary = cases[key]
		var p := graph.add_perch({"id": key, "position": c["position"], "normal": c["normal"], "fixture": true})
		var why := graph.validate_perch(space, p, profile)
		check_eq(why, str(c["want"]), "%s is refused for the right reason" % key)
		check(not p.valid, "%s is not valid" % key)
		check(not p.is_free_for("fly_x"), "and cannot be chosen")
	# a slope claimed to be flat
	var hit := ray_target(Vector3(-9.6, 5.0, 5.0), Vector3(-9.6, -1.0, 5.0))
	var slope := graph.add_perch({"id": "ramp_claimed_flat", "position": hit["point"], "normal": Vector3.UP, "fixture": true})
	check_eq(graph.validate_perch(space, slope, profile), "wrong_normal", "a ramp claimed to be flat is refused")
	# a perch with nothing it can be reached from
	var tiny: float = profile.max_flight_wu
	profile.max_flight_wu = 3.0
	var after := graph.validate_all(space, profile)
	check((after["refused"] as Dictionary).size() >= graph.order.size() - 3, "with flights limited to 3 WU almost every perch is cut off (%d refused)" % (after["refused"] as Dictionary).size())
	check_eq(str((after["refused"] as Dictionary).get("floor_ahead", "")), "unreachable", "and the reason is that")
	profile.max_flight_wu = tiny


func test_a_perch_that_leaves_the_world_sends_its_fly_off() -> void:
	await spawn_prey_world(floor_pose(-22.0, 12.0, -90.0))
	check(director().ensure_ready(), "ready")
	world.lab.add_fixture_piece("drop_test", "drop", Vector3(0.0, 0.0, -9.0), Vector3(2.0, 1.0, -7.0))
	await physics_frames(3)
	var p: PerchGraph.Perch = director().graph.add_perch({"id": "drop_test_top", "position": Vector3(1.0, 1.0, -8.0), "normal": Vector3.UP, "fixture": true, "shelter": 0.2})
	check_eq(director().graph.validate_perch(world.get_world_3d().direct_space_state, p, director().profile), "", "the perch on it is fine")
	var f := add_fly("drop_test_top", 5)
	check_eq(f.perch.id, "drop_test_top", "the fly is on it")
	world.lab.set_piece_enabled("drop_test", false)
	await physics_frames(2)
	check_eq(f.state, Fly.State.TAKEOFF, "it took off at once")
	check(str(f.trace[0]["reason"]).contains("its perch left the world"), "and said why: %s" % f.trace[0]["reason"])
	await wait_until(func() -> bool: return f.state == Fly.State.PERCHED, 60 * 10)
	check_eq(f.state, Fly.State.PERCHED, "it found another place")
	check(f.perch.id != "drop_test_top" and f.perch.valid and f.perch.available, "a valid one (%s)" % f.perch.id)
