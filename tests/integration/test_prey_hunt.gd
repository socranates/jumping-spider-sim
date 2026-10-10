extends "res://tests/prey_test_case.gd"
## Chunk 7B, milestone 9, the hunt: what a player can learn about a living fly by trying. A slow stalk reaches striking range of a perched fly
## without startling it and the strike catches it; a walk startles it from far off; a jump from far off is seen coming and the fly is gone
## when it lands; from close by it is caught; a fly that is grooming is the moment to strike; and a strike that misses (here: off a cliff
## whose far perch gives way) lets the fly escape while the spider hangs on its line. Every trial is a fixed seed, so the numbers are
## repeatable; they are the same numbers the tuning notes give (a still spider, a strike aimed at the fly's perch).
## Nothing here is told to the fly: it reacts to what its own eyes took in of the spider's body.

const FLY_PERCH := "floor_east_open"
const FLY_X := 4.0
const FLY_Z := 11.0
## A stalk of 0.8 WU/s is let to stop this far from the fly (flat distance): from here a fly is still unalarmed; closer in it is alerted (1.8 WU)
## and then gone (1.5 WU), so the range to strike from is about 2 to 3 WU.
const STRIKING_RANGE := 2.2


## A world with the spider `dist` WU from the fly on its perch, facing it, and the fly's first moments over.
func _hunt_world(dist: float, seed_value: int) -> Node3D:
	await spawn_prey_world(floor_pose(FLY_X, FLY_Z - dist, 180.0), 0, seed_value)
	director().ensure_ready()
	var f := add_fly(FLY_PERCH, seed_value)
	await physics_frames(50 + (seed_value * 37) % 90)
	return f


## Jumps at the floor point and waits until the flight is over (and a few ticks more). Returns whether the fly was caught.
func _strike(f: Node3D, x: float, z: float) -> bool:
	var spider: Node3D = world.spider
	var plan = spider.plan_jump(top_target(x, z))
	if not plan.is_valid():
		return false
	spider.begin_prepare()
	await physics_frames(2)
	spider.commit_jump(plan)
	await wait_until(func() -> bool: return not spider.last_jump.is_empty() and str(spider.last_jump["outcome"]) != "", 120)
	await physics_frames(5)
	return f.state == Fly.State.CAPTURED


func _free_world() -> void:
	world.queue_free()
	await physics_frames(2)


func test_a_slow_stalk_reaches_striking_range_unnoticed_and_a_strike_from_there_catches_the_fly() -> void:
	var caught := 0
	for seed_value in [3, 4]:
		var f: Node3D = await _hunt_world(7.0, seed_value)
		check_eq(f.state, Fly.State.PERCHED, "seed %d: the fly sits on its perch" % seed_value)
		var peak := [0.0]
		var note := func() -> void: peak[0] = maxf(float(peak[0]), f.senses.awareness)
		var used := await walk_toward(Vector3(FLY_X, 0.0, FLY_Z), STALK, STRIKING_RANGE, 60 * 14, note)
		check(flat_distance(world.spider.global_position, f.global_position) <= STRIKING_RANGE + 0.1, "seed %d: the spider is in striking range after %.1f s (%.1f WU from the fly)" % [seed_value, used / 60.0, flat_distance(world.spider.global_position, f.global_position)])
		check_eq(f.state, Fly.State.PERCHED, "seed %d: and the fly has not so much as been alerted" % seed_value)
		check_eq(f.flight.flights_total, 0, "seed %d: it never took off" % seed_value)
		check(float(peak[0]) < f.profile.awareness_flee * 0.5, "seed %d: its awareness stayed low (%.2f of the %.2f that sends it off)" % [seed_value, float(peak[0]), f.profile.awareness_flee])
		if await _strike(f, FLY_X, FLY_Z):
			caught += 1
		await _free_world()
	check(caught >= 1, "a strike from there catches it (%d of 2; the tuning notes have 5 of 8 seeds from 2.2 WU, 1 of 8 from 1.8 WU, where the fly is already alerted)" % caught)


func test_a_walk_up_to_the_same_fly_alerts_it_early_and_it_leaves_before_the_spider_is_near() -> void:
	var f: Node3D = await _hunt_world(8.0, 1)
	var seen_at := [-1.0, -1.0]   # the distance when it was first alert, and when it first took off
	var note := func() -> void:
		var d := flat_distance(world.spider.global_position, f.global_position)
		if float(seen_at[0]) < 0.0 and f.state >= Fly.State.ALERT:
			seen_at[0] = d
		if float(seen_at[1]) < 0.0 and f.state >= Fly.State.TAKEOFF:
			seen_at[1] = d
	var gone := func() -> bool: return f.state >= Fly.State.TAKEOFF
	await walk_toward(Vector3(FLY_X, 0.0, FLY_Z), WALK, 1.0, 60 * 8, note, gone)
	check(f.state >= Fly.State.TAKEOFF and f.state <= Fly.State.REPOSITION, "the fly took off (%s)" % f.state_name())
	check(float(seen_at[0]) > 3.5, "it was alert while the spider was still %.1f WU away" % float(seen_at[0]))
	check(float(seen_at[1]) > 2.2, "and gone with the spider still %.1f WU away: it never gets into the range a stalk reaches" % float(seen_at[1]))
	var reasons := PackedStringArray()
	for e: Dictionary in f.trace:
		reasons.append(str(e["reason"]))
	var joined := " | ".join(reasons)
	check(joined.contains("noticed") and joined.contains("reaction delay"), "and its own trace says why: it noticed the spider, and left after a reaction delay (%s)" % joined.substr(0, 120))
	await _free_world()


func test_a_jump_from_far_off_is_seen_coming_and_one_from_close_by_is_not() -> void:
	var far_caught := 0
	var near_caught := 0
	var far_fled := 0
	for seed_value in [1, 2, 3]:
		var f := await _hunt_world(5.5, seed_value)
		if await _strike(f, FLY_X, FLY_Z):
			far_caught += 1
		else:
			var wrote := false
			for e: Dictionary in f.trace:
				wrote = wrote or str(e["reason"]).contains("startle") or str(e["reason"]).contains("noticed")
			far_fled += 1 if (wrote and (f.state >= Fly.State.TAKEOFF or f.perch.id != FLY_PERCH)) else 0
		await _free_world()
		f = await _hunt_world(2.0, seed_value)
		if await _strike(f, FLY_X, FLY_Z):
			near_caught += 1
		await _free_world()
	check_eq(far_caught, 0, "from 5.5 WU no strike of three catches a calm fly: it saw the leap coming")
	check_eq(far_fled, 3, "and each of the three was gone (or going) by the time the spider landed, its own trace saying it noticed")
	check(near_caught >= 2, "from 2 WU at least two of three catch it (%d of 3)" % near_caught)


func test_a_grooming_fly_is_the_moment_to_strike() -> void:
	var caught := 0
	for seed_value in [1, 2, 3]:
		var f := await _hunt_world(4.0, seed_value)
		f.begin_groom(director().now, 3.0)
		await physics_frames(20)
		check(f.grooming(director().now), "the fly is grooming (a bout of 3 s)")
		if await _strike(f, FLY_X, FLY_Z):
			caught += 1
		await _free_world()
	check(caught >= 2, "a strike from 4 WU at a grooming fly catches it in at least two of three (%d of 3); the same strike at a fly that is not grooming catches about one in three" % caught)


## A cliff of coated wall with a cap, a perch beyond it that gives way when a leap is aimed at it, and a fly on the floor below.
func test_a_missed_strike_lets_the_fly_escape_while_the_spider_hangs_on_its_line() -> void:
	await spawn_prey_world(floor_pose(4.0, 5.0, 180.0), 0, 21)
	director().ensure_ready()
	world.lab.add_fixture_piece("hunt_cliff", "coated", Vector3(11.0, 0.0, -17.0), Vector3(15.0, 6.0, -13.0))
	world.lab.add_fixture_piece("hunt_cap", "ledge", Vector3(10.6, 6.0, -17.4), Vector3(15.4, 6.4, -12.6))
	world.lab.add_fixture_piece("hunt_perch", "drop", Vector3(16.6, 5.6, -15.75), Vector3(18.0, 6.0, -14.25))
	await physics_frames(3)
	var perch_on_floor: PerchGraph.Perch = director().graph.add_perch({"id": "hunt_floor", "position": Vector3(20.0, 0.0, -15.0), "normal": Vector3.UP, "fixture": true, "shelter": 0.1})
	check_eq(director().graph.validate_perch(world.get_world_3d().direct_space_state, perch_on_floor, director().profile), "", "the fly's floor perch is valid")
	var f := add_fly("hunt_floor", 21)
	var spider: Node3D = world.spider
	spider.teleport_to(Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(14.6, 6.71, -15.0)))
	await settle(spider)
	await physics_frames(90)
	check_eq(f.state, Fly.State.PERCHED, "the fly is perched below, unaware")
	var plan = spider.plan_jump(top_target(17.3, -15.0))
	check(plan.is_valid(), "the leap at the far perch is a plan the spider can fly (%s)" % plan.reason)
	spider.begin_prepare()
	await physics_frames(2)
	check(spider.commit_jump(plan), "the leap is committed")
	var st := [0, 0]   # ticks the spider hung on its line, and of those the ticks the fly was in the air getting away
	var watch := func() -> void:
		if spider.state == spider.State.HANGING:
			st[0] += 1
			if f.state >= Fly.State.TAKEOFF and f.state <= Fly.State.SEEK_PERCH:
				st[1] += 1
	await run_ticks(60 * 6, watch)
	var hanging_ticks: int = st[0]
	var fly_away_while_hanging: int = st[1]
	check(hanging_ticks > 60, "the spider ends up hanging on its line (%d ticks)" % hanging_ticks)
	check(fly_away_while_hanging > 20, "and the fly was in the air, getting away, for %d of those ticks" % fly_away_while_hanging)
	check_eq(director().capture_log.size(), 0, "nothing was caught")
	check_eq(f.state, Fly.State.PERCHED, "the fly is perched again")
	check(f.perch.id != "hunt_floor" and f.global_position.distance_to(Vector3(20.0, 0.2, -15.0)) > 6.0, "on another perch, %.1f WU from where it was (%s)" % [f.global_position.distance_to(Vector3(20.0, 0.2, -15.0)), f.perch.id])
	var told := PackedStringArray()
	for e: Dictionary in f.trace:
		told.append("%s>%s" % [str(e["from"]), str(e["to"])])
	check(" ".join(told).contains("PERCHED>ALERT") and " ".join(told).contains("TAKEOFF>FLEE"), "and its trace tells the story: %s" % " ".join(told))
