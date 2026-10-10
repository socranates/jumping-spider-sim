extends "res://tests/test_case.gd"
## Pure jump math: the discrete launch solution, the duration range, the speed and launch limits.

const JumpMath = preload("res://scripts/movement/jump_math.gd")

const G := Vector3(0.0, -35.0, 0.0)
const DT := 1.0 / 60.0


func _level_solve(distance: float, rise: float = 0.0) -> Dictionary:
	var p0 := Vector3(0.0, 0.31, 0.0)
	var seat := Vector3(distance, 0.31 + rise, 0.0)
	return JumpMath.solve(p0, seat, Vector3.UP, Vector3.UP, G, DT, 0.35, 0.6, 14.0)


func test_step_range_is_the_whole_ticks_inside_the_profile_range() -> void:
	var r := JumpMath.step_range(0.35, 0.6, DT)
	check_eq(r, Vector2i(21, 36), "0.35 to 0.6 s at 60 Hz is 21 to 36 ticks")
	check_eq(JumpMath.step_range(0.35, 0.6, 1.0 / 120.0), Vector2i(42, 72), "at 120 Hz twice as many ticks")
	check(JumpMath.step_range(0.351, 0.359, DT).y < JumpMath.step_range(0.351, 0.359, DT).x, "a range holding no whole tick is empty")
	check(JumpMath.step_range(NAN, 0.6, DT).y < JumpMath.step_range(NAN, 0.6, DT).x, "non-finite input gives an empty range")
	check(JumpMath.step_range(0.35, 0.6, 0.0).y < 1, "a zero step gives an empty range")


func test_the_launch_velocity_reaches_the_seat_exactly_in_the_tick_loop() -> void:
	var worst := 0.0
	var worst_closed := 0.0
	for i in 300:
		var p0 := Vector3(rng.randf_range(-20.0, 20.0), rng.randf_range(0.0, 8.0), rng.randf_range(-15.0, 15.0))
		var seat := p0 + Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(-4.0, 3.0), rng.randf_range(-5.0, 5.0))
		var n := rng.randi_range(21, 36)
		var v0 := JumpMath.launch_velocity(p0, seat, G, DT, n)
		var pts := JumpMath.path(p0, v0, G, DT, n)
		worst = maxf(worst, pts[n].distance_to(seat))
		worst_closed = maxf(worst_closed, JumpMath.position_after(p0, v0, G, DT, n).distance_to(seat))
		check_eq(pts.size(), n + 1, "the path has n + 1 points")
	check(worst < 1e-3, "the iterated path ends on the seat, worst error %f" % worst)
	check(worst_closed < 1e-3, "the closed form ends on the seat, worst error %f" % worst_closed)


func test_the_continuous_formula_would_miss_by_a_visible_amount() -> void:
	# The spec's formula v = (target - p0 - 0.5 g T^2) / T is the continuous one. Flown tick by tick
	# with semi-implicit Euler it lands g * dt^2 * n / 2 off: 0.146 WU at n = 30. The discrete solution
	# does not.
	var p0 := Vector3(0.0, 0.31, 0.0)
	var seat := Vector3(4.0, 0.31, 0.0)
	var n := 30
	var t := float(n) * DT
	var v_cont := (seat - p0 - 0.5 * G * t * t) / t
	var miss := JumpMath.path(p0, v_cont, G, DT, n)[n].distance_to(seat)
	check_near(miss, 35.0 * DT * DT * float(n) / 2.0, 1e-3, "the continuous formula misses by g dt^2 n / 2")
	check(miss > 0.1, "which is more than a tenth of a body length")
	var v_disc := JumpMath.launch_velocity(p0, seat, G, DT, n)
	check(JumpMath.path(p0, v_disc, G, DT, n)[n].distance_to(seat) < 1e-4, "the discrete solution hits it")


func test_solutions_are_ordered_lowest_launch_speed_first_and_respect_the_limit() -> void:
	var s := _level_solve(4.0)
	var valid: Array[Dictionary] = s["valid"]
	check_eq(s["reason"], "ok", "4 WU on the level is reachable")
	check(valid.size() > 3, "several durations work, %d" % valid.size())
	var sorted_ok := true
	for i in range(1, valid.size()):
		if float(valid[i]["speed"]) < float(valid[i - 1]["speed"]):
			sorted_ok = false
	check(sorted_ok, "lowest launch speed first")
	for c in valid:
		check(float(c["speed"]) <= 14.0 + 1e-6, "within the 14 WU/s limit")
		var n: int = c["steps"]
		check(n >= 21 and n <= 36, "within the 0.35 to 0.6 s range")
		check_near(float(c["duration"]), float(n) * DT, 1e-9, "duration is n * dt")
		check_near((c["velocity"] as Vector3).length(), float(c["speed"]), 1e-4, "speed is the velocity's length")
	var lowest: Dictionary = valid[0]
	check_near(float(s["min_speed"]), float(lowest["speed"]), 1e-4, "the lowest valid speed is the least any duration needs here")
	check_near(float(lowest["speed"]), 11.3, 1.0, "about 11 WU/s for 4 WU on the level")


func test_reach_is_about_two_to_five_body_lengths_on_the_level() -> void:
	for d in [2.0, 3.0, 4.0, 5.0]:
		check_eq(_level_solve(d)["reason"], "ok", "%.0f WU on the level is reachable" % d)
	check_eq(_level_solve(5.6)["reason"], "too_far", "5.6 WU is beyond the 14 WU/s limit")
	check_eq(_level_solve(9.0)["reason"], "too_far", "9 WU is far beyond it")
	check_eq(_level_solve(1.0)["reason"], "ok", "a short hop works too")


func test_height_limits_the_reach() -> void:
	check_eq(_level_solve(2.0, 2.0)["reason"], "ok", "2 WU up at 2 WU out is reachable")
	check_eq(_level_solve(3.0, 3.5)["reason"], "too_far", "3.5 WU up needs more than 14 WU/s")
	var down := _level_solve(4.0, -4.0)
	check_eq(down["reason"], "ok", "4 WU out and 4 WU down is reachable")
	check(float((down["valid"] as Array)[0]["speed"]) < float((_level_solve(4.0)["valid"] as Array)[0]["speed"]), "going down needs less speed than going level")


func test_every_launch_leaves_the_surface() -> void:
	var p0 := Vector3(0.0, 0.31, 0.0)
	for d in [1.0, 2.5, 4.0]:
		var s := JumpMath.solve(p0, Vector3(d, 0.31, 0.0), Vector3.UP, Vector3.UP, G, DT, 0.35, 0.6, 14.0)
		for c in s["valid"]:
			check((c["velocity"] as Vector3).dot(Vector3.UP) > JumpMath.MIN_LAUNCH_NORMAL_SPEED, "v0 . N > 0 for %.1f WU" % d)
	# A wall: the seat on the same wall plane is the same distance from it, so no launch can leave it
	# and come back. Gravity has no component along the wall's normal.
	var wall_p0 := Vector3(0.31, 2.0, 0.0)
	var wall := JumpMath.solve(wall_p0, Vector3(0.31, 4.0, 0.0), Vector3.RIGHT, Vector3.RIGHT, G, DT, 0.35, 0.6, 14.0)
	check_eq(wall["reason"], "no_launch", "a jump along the same wall cannot leave it")
	check((wall["valid"] as Array).is_empty(), "so nothing is offered")
	# From an underside, a launch must go down, away from it.
	var under := JumpMath.solve(Vector3(0.0, 3.69, 0.0), Vector3(2.0, 0.31, 0.0), Vector3.DOWN, Vector3.UP, G, DT, 0.35, 0.6, 14.0)
	check_eq(under["reason"], "ok", "from the underside down to the floor works")
	for c in under["valid"]:
		check((c["velocity"] as Vector3).dot(Vector3.DOWN) > 0.0, "the launch from the underside points away from it")


func test_arrival_must_go_into_the_target_surface() -> void:
	# Up onto an underside 2.38 WU above the seat height: the body must still be rising when it gets
	# there, which only the shorter durations allow.
	var p0 := Vector3(0.0, 0.31, 0.0)
	var s := JumpMath.solve(p0, Vector3(1.0, 2.69, 0.0), Vector3.UP, Vector3.DOWN, G, DT, 0.35, 0.6, 14.0)
	var valid: Array[Dictionary] = s["valid"]
	check(not valid.is_empty(), "the underside can be reached")
	var longest := 0
	for c in valid:
		check(float(c["approach"]) >= JumpMath.LAND_APPROACH_MIN - 1e-6, "arrives into the underside at 0.3 WU/s or more")
		check((c["arrival_velocity"] as Vector3).y > 0.0, "still rising on arrival")
		longest = maxi(longest, int(c["steps"]))
	check(longest < 36, "the longest durations arrive falling and are left out (longest kept %d)" % longest)
	# A floor target takes any arrival that points down.
	var floor_s := JumpMath.solve(p0, Vector3(3.0, 0.31, 0.0), Vector3.UP, Vector3.UP, G, DT, 0.35, 0.6, 14.0)
	for c in floor_s["valid"]:
		check(float(c["approach"]) >= JumpMath.STAND_APPROACH_MIN, "a floor needs only a small approach")


func test_unreachable_inputs_are_rejected_with_a_reason() -> void:
	var p0 := Vector3.ZERO
	var none := JumpMath.solve(p0, Vector3(3.0, 0.0, 0.0), Vector3.UP, Vector3.UP, G, DT, 0.351, 0.359, 14.0)
	check_eq(none["reason"], "no_durations", "an empty duration range")
	var far := JumpMath.solve(p0, Vector3(20.0, 0.0, 0.0), Vector3.UP, Vector3.UP, G, DT, 0.35, 0.6, 14.0)
	check_eq(far["reason"], "too_far", "20 WU away")
	check(float(far["min_speed"]) > 14.0, "and the least speed it would need is reported, %f" % float(far["min_speed"]))
	var nan := JumpMath.solve(p0, Vector3(NAN, 0.0, 0.0), Vector3.UP, Vector3.UP, G, DT, 0.35, 0.6, 14.0)
	check((nan["valid"] as Array).is_empty(), "a non-finite seat gives nothing")


func test_standing_surfaces_follow_the_45_degree_rule() -> void:
	check(JumpMath.is_standing(Vector3.UP), "the floor stands")
	check(JumpMath.is_standing(Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(44.0))), "44 degrees stands")
	check(not JumpMath.is_standing(Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(46.0))), "46 degrees does not")
	check(not JumpMath.is_standing(Vector3.RIGHT), "a wall does not")
	check(not JumpMath.is_standing(Vector3.ZERO), "a zero normal does not")
	check_near(JumpMath.min_approach(Vector3.UP), JumpMath.STAND_APPROACH_MIN, 1e-9, "floors need the small approach")
	check_near(JumpMath.min_approach(Vector3.RIGHT), JumpMath.LAND_APPROACH_MIN, 1e-9, "walls need the larger one")
