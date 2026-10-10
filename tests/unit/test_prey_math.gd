extends "res://tests/test_case.gd"
## PreyMath (chunk 7B): the swept contact test, what the fly makes of what it sees, the small utility selector, and paths. Pure functions.

const PreyMath := preload("res://scripts/prey/prey_math.gd")
const PreyProfile := preload("res://scripts/prey/prey_profile.gd")
const PROFILE_PATH := "res://data/species/fly_like_prototype.json"


func _weights() -> Dictionary:
	return PreyProfile.load_file(PROFILE_PATH).weights()


# ------------------------------------------------------------------ the swept contact

func test_a_sweep_finds_a_head_on_pass_that_a_per_tick_check_would_miss() -> void:
	# a goes from -5 to +5 and b stays at the origin: at both ends they are 5 apart, in the middle they touch.
	var r := PreyMath.sweep_closest(Vector3(-5, 0, 0), Vector3(5, 0, 0), Vector3.ZERO, Vector3.ZERO)
	check_near(float(r["distance"]), 0.0, 1e-6, "they pass through each other")
	check_near(float(r["t"]), 0.5, 1e-6, "in the middle of the step")


func test_a_sweep_with_both_things_moving_uses_the_relative_motion() -> void:
	# a moves +x, b moves -x on a parallel line 0.5 above: they cross at t = 0.5 and are 0.5 apart there.
	var r := PreyMath.sweep_closest(Vector3(-2, 0, 0), Vector3(2, 0, 0), Vector3(2, 0.5, 0), Vector3(-2, 0.5, 0))
	check_near(float(r["distance"]), 0.5, 1e-6, "the line between them is 0.5 at the closest")
	check_near(float(r["t"]), 0.5, 1e-6, "halfway")


func test_a_sweep_of_things_moving_together_does_not_change_their_distance() -> void:
	var d := PreyMath.sweep_min_distance(Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(1, 1, 0), Vector3(4, 1, 0))
	check_near(d, sqrt(2.0), 1e-6, "a fixed offset stays the offset")


func test_a_sweep_where_the_closest_moment_is_an_end_uses_that_end() -> void:
	var r := PreyMath.sweep_closest(Vector3(1, 0, 0), Vector3(3, 0, 0), Vector3.ZERO, Vector3.ZERO)
	check_near(float(r["distance"]), 1.0, 1e-6, "moving away, the start is the closest")
	check_near(float(r["t"]), 0.0, 1e-6, "at t = 0")
	var r2 := PreyMath.sweep_closest(Vector3(3, 0, 0), Vector3(1, 0, 0), Vector3.ZERO, Vector3.ZERO)
	check_near(float(r2["distance"]), 1.0, 1e-6, "moving in and stopping short, the end is the closest")
	check_near(float(r2["t"]), 1.0, 1e-6, "at t = 1")


func test_a_sweep_of_two_things_that_do_not_move_is_their_distance() -> void:
	check_near(PreyMath.sweep_min_distance(Vector3(1, 2, 3), Vector3(1, 2, 3), Vector3(1, 2, 5), Vector3(1, 2, 5)), 2.0, 1e-9, "still, still")


# ------------------------------------------------------------------ what the fly sees

func test_apparent_angle_and_bearing_rate() -> void:
	check_near(rad_to_deg(PreyMath.apparent_angle(0.3, 3.0)), 2.0 * rad_to_deg(atan(0.1)), 1e-6, "a sphere of radius 0.3 at 3 WU")
	check(PreyMath.apparent_angle(0.3, 1.0) > PreyMath.apparent_angle(0.3, 5.0), "nearer looks larger")
	check_near(PreyMath.bearing_rate_deg_s(Vector3.RIGHT, Vector3(1, 1, 0), 0.5), 90.0, 1e-3, "45 degrees in half a second is 90 a second")
	check_near(PreyMath.bearing_rate_deg_s(Vector3.RIGHT, Vector3.RIGHT, 0.1), 0.0, 1e-9, "no turn, no rate")
	check_near(PreyMath.bearing_rate_deg_s(Vector3.RIGHT, Vector3.UP, 0.0), 0.0, 1e-9, "no time, no rate")
	check_near(PreyMath.bearing_rate_deg_s(Vector3.ZERO, Vector3.UP, 0.1), 0.0, 1e-9, "no direction, no rate")


func test_loom_is_the_relative_swelling_and_only_for_things_that_grow() -> void:
	var a0 := PreyMath.apparent_angle(0.3, 4.0)
	var a1 := PreyMath.apparent_angle(0.3, 3.75)
	var rate := PreyMath.loom_rate_deg_s(a0, a1, 0.1, 40.0)
	check(rate > 0.0, "approaching swells")
	# 2.5 WU/s head on at 4 WU: relative growth about v / d = 0.62 a second, times the scale 40
	check_near(rate, 40.0 * (2.5 / 4.0), 3.0, "about the speed over the distance times the scale")
	check_near(PreyMath.loom_rate_deg_s(a1, a0, 0.1, 40.0), 0.0, 1e-9, "receding does not loom")
	check_near(PreyMath.loom_rate_deg_s(a0, a1, 0.0, 40.0), 0.0, 1e-9, "no time, no rate")


func test_distance_and_facing_weights() -> void:
	check_near(PreyMath.distance_weight(2.0, 3.0, 14.0), 1.0, 1e-9, "full within the near distance")
	check_near(PreyMath.distance_weight(14.0, 3.0, 14.0), 0.0, 1e-9, "nothing at the far distance")
	check_near(PreyMath.distance_weight(20.0, 3.0, 14.0), 0.0, 1e-9, "nothing beyond it")
	check_near(PreyMath.distance_weight(8.5, 3.0, 14.0), 0.5, 1e-9, "half way is half")
	check_near(PreyMath.facing_weight(40.0, 90.0, 150.0, 0.35), 1.0, 1e-9, "in front, full")
	check_near(PreyMath.facing_weight(170.0, 90.0, 150.0, 0.35), 0.35, 1e-9, "behind, the rear gain")
	var mid := PreyMath.facing_weight(120.0, 90.0, 150.0, 0.35)
	check(mid > 0.35 and mid < 1.0, "to the side, between")
	check_near(mid, lerpf(1.0, 0.35, 0.5), 1e-9, "half way across the blend")


func test_awareness_needs_motion_above_the_threshold_and_is_scaled_by_the_weights() -> void:
	check_near(PreyMath.awareness_gain_per_s(10.0, 10.0, 12.0, 1.0, 1.0, 1.0, 1.0), 0.0, 1e-12, "at the threshold, nothing")
	check_near(PreyMath.awareness_gain_per_s(5.0, 10.0, 12.0, 1.0, 1.0, 1.0, 1.0), 0.0, 1e-12, "below it, nothing")
	check_near(PreyMath.awareness_gain_per_s(34.0, 10.0, 12.0, 1.0, 1.0, 1.0, 1.0), 2.0, 1e-9, "24 deg/s over the threshold at a scale of 12 is 2 a second")
	check_near(PreyMath.awareness_gain_per_s(34.0, 10.0, 12.0, 0.5, 1.0, 1.0, 1.0), 1.0, 1e-9, "half the distance weight, half the gain")
	check_near(PreyMath.awareness_gain_per_s(34.0, 10.0, 12.0, 1.0, 0.35, 1.0, 1.0), 0.7, 1e-9, "from behind, 0.35")
	check_near(PreyMath.awareness_gain_per_s(34.0, 10.0, 12.0, 1.0, 1.0, 0.5, 1.0), 1.0, 1e-9, "half of it hidden, half the gain")
	check_near(PreyMath.awareness_gain_per_s(34.0, 10.0, 12.0, 1.0, 1.0, 1.0, 1.5), 3.0, 1e-9, "more alert, more gain")
	check_near(PreyMath.awareness_gain_per_s(34.0, 10.0, 12.0, 1.0, 1.0, 0.0, 1.0), 0.0, 1e-12, "nothing visible, nothing gained")


func test_awareness_integrates_by_the_time_that_passed_and_stays_in_range() -> void:
	check_near(PreyMath.integrate_awareness(0.2, 1.0, 0.1, 0.35, 1.5), 0.3, 1e-9, "gain over a tenth of a second")
	check_near(PreyMath.integrate_awareness(0.2, 0.0, 0.1, 0.35, 1.5), 0.165, 1e-9, "decay when there is no gain")
	check_near(PreyMath.integrate_awareness(0.02, 0.0, 1.0, 0.35, 1.5), 0.0, 1e-12, "never below nothing")
	check_near(PreyMath.integrate_awareness(1.4, 5.0, 1.0, 0.35, 1.5), 1.5, 1e-12, "never above the maximum")
	check_near(PreyMath.integrate_awareness(0.4, 5.0, 0.0, 0.35, 1.5), 0.4, 1e-12, "no time, no change")
	# the same total time, sampled once or ten times, gives the same
	var once := PreyMath.integrate_awareness(0.0, 0.8, 1.0, 0.35, 1.5)
	var a := 0.0
	for i in 10:
		a = PreyMath.integrate_awareness(a, 0.8, 0.1, 0.35, 1.5)
	check_near(a, once, 1e-9, "one second as one step or ten")


func test_startle_needs_both_a_lot_of_motion_and_nearness() -> void:
	check(PreyMath.is_startle(80.0, 5.0, 70.0, 7.0), "fast and near")
	check(not PreyMath.is_startle(60.0, 5.0, 70.0, 7.0), "not fast enough")
	check(not PreyMath.is_startle(80.0, 9.0, 70.0, 7.0), "not near enough")
	check(PreyMath.is_startle(70.0, 7.0, 70.0, 7.0), "the limits count")


func test_a_draw_stays_in_its_pair_and_follows_the_seed() -> void:
	var r1 := RandomNumberGenerator.new()
	r1.seed = 42
	var r2 := RandomNumberGenerator.new()
	r2.seed = 42
	var lo := INF
	var hi := -INF
	for i in 200:
		var a := PreyMath.draw(r1, Vector2(0.1, 0.2))
		var b := PreyMath.draw(r2, Vector2(0.1, 0.2))
		check_near(a, b, 1e-12, "the same seed gives the same draw")
		lo = minf(lo, a)
		hi = maxf(hi, a)
	check(lo >= 0.1 and hi <= 0.2, "inside the pair")
	check(hi - lo > 0.05, "and it does vary")


# ------------------------------------------------------------------ the utility selector

func test_threat_runs_from_calm_to_flee() -> void:
	check_near(PreyMath.threat_input(0.05, 0.1, 1.0), 0.0, 1e-12, "below calm, none")
	check_near(PreyMath.threat_input(0.1, 0.1, 1.0), 0.0, 1e-12, "at calm, none")
	check_near(PreyMath.threat_input(0.55, 0.1, 1.0), 0.5, 1e-9, "half way")
	check_near(PreyMath.threat_input(1.4, 0.1, 1.0), 1.0, 1e-12, "past the flee awareness, all of it")


func test_flee_is_worth_nothing_without_a_threat() -> void:
	var w := _weights()
	check_near(PreyMath.score_flee(w, 0.0, 1.0, 1.0, 0.0), 0.0, 1e-12, "no threat, no flight, however good the perch")
	check(PreyMath.score_flee(w, 0.8, 0.5, 0.5, 0.3) > PreyMath.score_flee(w, 0.4, 0.5, 0.5, 0.3), "more threat, more worth")
	check(PreyMath.score_flee(w, 0.8, 0.9, 0.5, 0.3) > PreyMath.score_flee(w, 0.8, 0.1, 0.5, 0.3), "a more sheltered perch is better")
	check(PreyMath.score_flee(w, 0.8, 0.5, 0.9, 0.3) > PreyMath.score_flee(w, 0.8, 0.5, 0.1, 0.3), "farther from the thing is better")
	check(PreyMath.score_flee(w, 0.8, 0.5, 0.5, 0.1) > PreyMath.score_flee(w, 0.8, 0.5, 0.5, 0.9), "a shorter trip is better")


func test_rest_wins_when_calm_and_loses_when_threatened() -> void:
	var w := _weights()
	var order: Array[StringName] = [&"rest", &"move", &"flee"]
	var calm := {"rest": PreyMath.score_rest(w, 0.0, 0.4, 0.3, 0.0), "move": PreyMath.score_move(w, 0.1, 0.2, 0.2, 0.4, 0.0, 0.0), "flee": PreyMath.score_flee(w, 0.0, 0.4, 0.5, 0.3)}
	check_eq(PreyMath.pick_goal(calm, &"rest", w["rest_base"] * 0.0, order), &"rest", "a calm fly that has only just landed rests")
	var scared := {"rest": PreyMath.score_rest(w, 0.0, 0.4, 0.3, 0.9), "move": PreyMath.score_move(w, 0.1, 0.2, 0.2, 0.4, 0.0, 0.9), "flee": PreyMath.score_flee(w, 0.9, 0.4, 0.5, 0.3)}
	check_eq(PreyMath.pick_goal(scared, &"rest", 0.15, order), &"flee", "a threatened one flees, hysteresis and all")
	var restless := {"rest": PreyMath.score_rest(w, 0.0, 0.4, 0.3, 0.0), "move": PreyMath.score_move(w, 1.0, 0.8, 0.6, 0.3, 0.0, 0.0), "flee": 0.0}
	check_eq(PreyMath.pick_goal(restless, &"rest", 0.15, order), &"move", "a restless one with a clearly better place in mind moves")
	var no_better := {"rest": PreyMath.score_rest(w, 0.0, 0.4, 0.3, 0.0), "move": PreyMath.score_move(w, 1.0, 0.0, 0.0, 0.3, 0.0, 0.0), "flee": 0.0}
	check_eq(PreyMath.pick_goal(no_better, &"rest", 0.15, order), &"rest", "restless but with nowhere better to go, it stays")
	var tired := {"rest": PreyMath.score_rest(w, 1.0, 0.4, 0.3, 0.0), "move": PreyMath.score_move(w, 1.0, 0.3, 0.3, 0.3, 1.0, 0.0), "flee": 0.0}
	check_eq(PreyMath.pick_goal(tired, &"rest", 0.15, order), &"rest", "a tired one rests however restless")


func test_hysteresis_keeps_the_present_goal_in_a_close_call() -> void:
	var order: Array[StringName] = [&"rest", &"move", &"flee"]
	var close := {"rest": 0.50, "move": 0.58, "flee": 0.0}
	check_eq(PreyMath.pick_goal(close, &"rest", 0.15, order), &"rest", "8 hundredths ahead is not enough to leave")
	check_eq(PreyMath.pick_goal(close, &"move", 0.15, order), &"move", "and the other way round")
	var clear := {"rest": 0.50, "move": 0.70, "flee": 0.0}
	check_eq(PreyMath.pick_goal(clear, &"rest", 0.15, order), &"move", "20 hundredths ahead is")
	var tie := {"rest": 0.5, "move": 0.5}
	check_eq(PreyMath.pick_goal(tie, &"flee", 0.0, order), &"rest", "a tie goes to the earlier goal")
	check_eq(PreyMath.pick_goal({}, &"rest", 0.15, order), &"rest", "nothing to choose from keeps the present goal")


# ------------------------------------------------------------------ paths and speeds

func test_path_length_point_and_direction() -> void:
	var pts := PackedVector3Array([Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(3, 4, 0)])
	check_near(PreyMath.path_length(pts), 7.0, 1e-9, "3 then 4")
	check_vec_near(PreyMath.point_at(pts, 0.0), Vector3(0, 0, 0), 1e-9, "the start")
	check_vec_near(PreyMath.point_at(pts, 1.5), Vector3(1.5, 0, 0), 1e-9, "on the first leg")
	check_vec_near(PreyMath.point_at(pts, 5.0), Vector3(3, 2, 0), 1e-9, "on the second")
	check_vec_near(PreyMath.point_at(pts, 99.0), Vector3(3, 4, 0), 1e-9, "past the end, the end")
	check_vec_near(PreyMath.point_at(pts, -1.0), Vector3(0, 0, 0), 1e-9, "before the start, the start")
	check_vec_near(PreyMath.direction_at(pts, 1.0), Vector3.RIGHT, 1e-9, "along the first leg")
	check_vec_near(PreyMath.direction_at(pts, 4.0), Vector3.UP, 1e-9, "along the second")
	check_vec_near(PreyMath.direction_at(pts, 50.0), Vector3.UP, 1e-9, "past the end, the last")
	check_near(PreyMath.path_length(PackedVector3Array()), 0.0, 1e-12, "an empty path has no length")


func test_distance_to_a_path() -> void:
	var pts := PackedVector3Array([Vector3(0, 0, 0), Vector3(10, 0, 0)])
	check_near(PreyMath.distance_to_path(pts, Vector3(5, 2, 0)), 2.0, 1e-9, "beside the middle")
	check_near(PreyMath.distance_to_path(pts, Vector3(-3, 4, 0)), 5.0, 1e-9, "beyond the start: the distance to the start")
	check_near(PreyMath.distance_to_path(pts, Vector3(10, 0, 0)), 0.0, 1e-9, "on it")
	check_near(PreyMath.distance_to_path(PackedVector3Array([Vector3(1, 1, 1)]), Vector3(1, 1, 3)), 2.0, 1e-9, "a single point")


func test_speed_eases_down_into_a_landing_and_climbs_at_the_acceleration() -> void:
	check_near(PreyMath.target_speed(5.0, 7.0, 2.0, 1.2), 7.0, 1e-9, "far from the end, the top speed")
	check_near(PreyMath.target_speed(0.0, 7.0, 2.0, 1.2), 2.0, 1e-9, "at the end, the landing speed")
	check_near(PreyMath.target_speed(0.6, 7.0, 2.0, 1.2), 4.5, 1e-9, "half way down the zone")
	check_near(PreyMath.step_speed(0.0, 15.0, 80.0, 0.1), 8.0, 1e-9, "a tenth of a second at 80 a second squared")
	check_near(PreyMath.step_speed(14.0, 15.0, 80.0, 0.1), 15.0, 1e-9, "it does not pass the target")
	check_near(PreyMath.step_speed(15.0, 2.0, 80.0, 0.1), 2.0, 1e-9, "it can slow at once")


func test_in_view_is_the_camera_cone_with_a_margin() -> void:
	var cam := Transform3D(Basis.IDENTITY, Vector3(0, 5, 0))   # looks along -Z
	check(PreyMath.in_view(cam, 60.0, 1.0, Vector3(0, 5, -10), 0.0), "straight ahead is in view")
	check(not PreyMath.in_view(cam, 60.0, 1.0, Vector3(0, 5, 10), 0.0), "straight behind is not")
	check(not PreyMath.in_view(cam, 60.0, 1.0, Vector3(0, 5, 0), 0.0), "the camera's own place is not in front of it")
	# half angle 30 degrees: 10 ahead and 5.0 across is 26.6 degrees (in), 6.5 across is 33 degrees (out)
	check(PreyMath.in_view(cam, 60.0, 1.0, Vector3(5.0, 5, -10), 0.0), "inside the half angle")
	check(not PreyMath.in_view(cam, 60.0, 1.0, Vector3(6.5, 5, -10), 0.0), "outside the half angle")
	check(PreyMath.in_view(cam, 60.0, 1.0, Vector3(6.5, 5, -10), 5.0), "the margin brings it back in")
	check(not PreyMath.in_view(cam, 60.0, 1.0, Vector3(0, 11.5, -10), 0.0), "above the vertical half angle")
	check(PreyMath.in_view(cam, 60.0, 1.0, Vector3(0, 11.5, -10), 5.0), "the margin works on the vertical angle too")
	# a wide picture sees further across than up: aspect 2 -> horizontal half angle atan(2 * tan 30) = 49.1 degrees
	check(PreyMath.in_view(cam, 60.0, 2.0, Vector3(10.0, 5, -10), 0.0), "a wide picture reaches 45 degrees across")
	check(not PreyMath.in_view(cam, 60.0, 2.0, Vector3(0, 11.5, -10), 0.0), "but not further up")
	# a turned camera: looking along +X
	var turned := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 5, 0))
	check(PreyMath.in_view(turned, 60.0, 1.0, Vector3(10, 5, 0), 0.0), "a camera turned to +X sees +X")
	check(not PreyMath.in_view(turned, 60.0, 1.0, Vector3(0, 5, -10), 0.0), "and no longer sees -Z")
