extends "res://tests/test_case.gd"

const BoomMath = preload("res://scripts/movement/boom_math.gd")
const DT := 1.0 / 60.0


func test_hit_retracts_immediately() -> void:
	check_near(BoomMath.next_length(5.0, 1.2, 5.0, 6.0, DT), 1.2, 1e-9, "retract to the hit in one step")
	check_near(BoomMath.next_length(5.0, 0.0, 5.0, 6.0, DT), 0.0, 1e-9, "retract all the way")
	check_near(BoomMath.next_length(5.0, 3.0, 4.0, 6.0, DT), 3.0, 1e-9, "retract to the nearer of hit and wish")


func test_recovery_is_bounded_per_step() -> void:
	check_near(BoomMath.next_length(1.2, 5.0, 5.0, 6.0, DT), 1.2 + 6.0 * DT, 1e-9, "one step recovers speed * dt")
	check_near(BoomMath.next_length(4.99, 5.0, 5.0, 6.0, DT), 5.0, 1e-9, "recovery stops at the wish")
	check_near(BoomMath.next_length(1.0, 1.05, 5.0, 6.0, DT), 1.05, 1e-9, "recovery stops at the hit")
	check_near(BoomMath.next_length(2.0, 5.0, 5.0, 6.0, 0.0), 2.0, 1e-9, "zero dt changes nothing")
	check_near(BoomMath.next_length(2.0, 5.0, 5.0, 0.0, DT), 2.0, 1e-9, "zero speed changes nothing")


func test_recovery_converges_without_overshoot() -> void:
	var length := 0.0
	var previous := 0.0
	var steps := 0
	while length < 5.0 and steps < 200:
		length = BoomMath.next_length(length, 5.0, 5.0, 6.0, DT)
		check(length >= previous and length <= 5.0, "monotonic and bounded at step %d" % steps)
		previous = length
		steps += 1
	check_near(length, 5.0, 1e-9, "reaches the wish")
	check(steps >= 49 and steps <= 52, "takes about 5 / (6 * dt) steps, took %d" % steps)


func test_invariants_hold_for_random_inputs() -> void:
	for i in 500:
		var current := rng.randf_range(0.0, 8.0)
		var allowed := rng.randf_range(-1.0, 9.0)
		var desired := rng.randf_range(0.0, 8.0)
		var speed := rng.randf_range(0.0, 12.0)
		var dt := rng.randf_range(0.0, 0.05)
		var next := BoomMath.next_length(current, allowed, desired, speed, dt)
		var target := maxf(0.0, minf(allowed, desired))
		var ok: bool
		if target <= current:
			ok = absf(next - target) < 1e-9
		else:
			ok = next >= current - 1e-9 and next <= target + 1e-9 and next <= current + speed * dt + 1e-9
		if not check(ok, "case %d: current %f allowed %f desired %f speed %f dt %f -> %f" % [i, current, allowed, desired, speed, dt, next]):
			return


func test_non_finite_input_returns_the_pivot() -> void:
	check_near(BoomMath.next_length(NAN, 5.0, 5.0, 6.0, DT), 0.0, 0.0, "nan current")
	check_near(BoomMath.next_length(1.0, INF, 5.0, 6.0, DT), 0.0, 0.0, "infinite allowed")
	check_near(BoomMath.next_length(1.0, 5.0, NAN, 6.0, DT), 0.0, 0.0, "nan desired")


func test_allowed_length_from_cast_fraction() -> void:
	check_near(BoomMath.allowed_length(0.5, 5.0), 2.5, 1e-9, "half the boom")
	check_near(BoomMath.allowed_length(1.0, 5.0), 5.0, 1e-9, "no hit")
	check_near(BoomMath.allowed_length(-0.2, 5.0), 0.0, 1e-9, "fraction clamps low")
	check_near(BoomMath.allowed_length(1.7, 5.0), 5.0, 1e-9, "fraction clamps high")


func test_orbit_basis_never_rolls() -> void:
	for i in 500:
		var yaw := rng.randf_range(-TAU, TAU)
		var elevation := rng.randf_range(deg_to_rad(-20.0), deg_to_rad(80.0))
		var b := BoomMath.orbit_basis(yaw, elevation)
		if not check(absf(b.x.y) < 1e-6 and b.y.y > 0.0, "horizon level at yaw %f elevation %f" % [yaw, elevation]):
			return
		var back := BoomMath.back_direction(yaw, elevation)
		check_near(back.length(), 1.0, 1e-5, "unit boom direction")
		check_near(back.y, sin(elevation), 1e-5, "boom height follows elevation")
		check_near((b * Vector3.FORWARD).dot(back), -1.0, 1e-5, "the camera looks back along the boom")


func test_yaw_convention() -> void:
	check_vec_near(BoomMath.orbit_basis(0.0, 0.0) * Vector3.FORWARD, Vector3(0.0, 0.0, -1.0), 1e-6, "yaw 0 looks along -Z")
	check_vec_near(BoomMath.orbit_basis(PI / 2.0, 0.0) * Vector3.FORWARD, Vector3(-1.0, 0.0, 0.0), 1e-6, "positive yaw turns left")
	check_vec_near(BoomMath.back_direction(0.0, deg_to_rad(18.0)), Vector3(0.0, sin(deg_to_rad(18.0)), cos(deg_to_rad(18.0))), 1e-6, "camera sits behind and above")


func test_pitch_offset_takes_the_smallest_comfortable_change() -> void:
	var offsets := PackedFloat64Array([0.0, 0.2, 0.4, 0.6])
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([0.4, 1.9, 2.6, 3.0]), 2.5), 0.4, 1e-12, "the first offset that reaches the minimum")
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([2.6, 3.0, 3.0, 3.0]), 2.5), 0.0, 1e-12, "no change when the player's pitch is comfortable")
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([0.4, 1.0, 1.9, 1.2]), 2.5), 0.4, 1e-12, "otherwise the longest boom found")
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([2.0, 1.5, 1.2, 0.9]), 2.5), 0.0, 1e-12, "a steeper pitch that shortens the boom is never taken")
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([1.0, 1.0004, 1.0, 1.0]), 2.5), 0.0, 1e-12, "a near tie keeps the smaller change")
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([0.0, 0.0, 0.0, 0.0]), 2.5), 0.0, 1e-12, "no room anywhere: no change")


func test_pitch_offset_works_down_the_list_in_the_order_tried_including_negative_offsets() -> void:
	# Steeper pitches first, then flatter and upward-looking ones (negative offsets).
	var offsets := PackedFloat64Array([0.0, 0.2, 0.4, -0.2, -0.4])
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([1.0, 0.8, 0.6, 2.7, 3.0]), 2.5), -0.2, 1e-12, "the first negative offset that is comfortable, the smallest change")
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([1.0, 2.6, 0.6, 2.7, 3.0]), 2.5), 0.2, 1e-12, "a comfortable downward pitch comes before any upward one")
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([1.0, 0.8, 0.6, 1.4, 2.2]), 2.5), -0.4, 1e-12, "none comfortable: the longest boom, even when it is an upward pitch")
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([1.0, 0.8, 0.6, 0.9, 0.7]), 2.5), 0.0, 1e-12, "none better than the player's pitch: no change")


func test_pitch_offset_rejects_bad_input() -> void:
	var offsets := PackedFloat64Array([0.0, 0.2])
	check_near(BoomMath.pick_pitch_offset(PackedFloat64Array(), PackedFloat64Array(), 2.5), 0.0, 1e-12, "empty")
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([1.0]), 2.5), 0.0, 1e-12, "mismatched sizes")
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([1.0, NAN]), 2.5), 0.0, 1e-12, "NaN length")
	check_near(BoomMath.pick_pitch_offset(offsets, PackedFloat64Array([1.0, 3.0]), NAN), 0.0, 1e-12, "NaN comfort")


func test_pitch_ease_treats_negative_offsets_like_positive_ones() -> void:
	var into := BoomMath.ease_offset(0.0, -1.0, DT, 0.08, 0.35)
	var out := 1.0 + BoomMath.ease_offset(-1.0, 0.0, DT, 0.08, 0.35)
	check_near(-into, 1.0 - exp(-DT / 0.08), 1e-12, "moving away from zero uses the in time constant")
	check_near(out, 1.0 - exp(-DT / 0.35), 1e-12, "moving back toward zero uses the out time constant")
	var value := 0.0
	var steps := 0
	while value != -1.0 and steps < 300:
		value = BoomMath.ease_offset(value, -1.0, DT, 0.08, 0.35)
		check(value <= 0.0 and value >= -1.0, "bounded at step %d" % steps)
		steps += 1
	check(value == -1.0 and steps < 100, "a negative target is reached exactly, took %d steps" % steps)
	check_near(BoomMath.ease_offset(-0.5, 0.5, DT, 0.08, 0.35), -0.5 + 1.0 * (1.0 - exp(-DT / 0.08)), 1e-12, "a flip of sign of equal size counts as moving in")


func test_pitch_ease_is_quick_in_slow_out_and_never_overshoots() -> void:
	var up := BoomMath.ease_offset(0.0, 1.0, DT, 0.08, 0.35)
	var down := 1.0 - BoomMath.ease_offset(1.0, 0.0, DT, 0.08, 0.35)
	check_near(up, 1.0 - exp(-DT / 0.08), 1e-12, "growing uses the in time constant")
	check_near(down, 1.0 - exp(-DT / 0.35), 1e-12, "relaxing uses the out time constant")
	check(up > 3.0 * down, "in is much quicker than out")
	var value := 0.0
	var previous := 0.0
	var steps := 0
	while value != 1.0 and steps < 300:
		value = BoomMath.ease_offset(value, 1.0, DT, 0.08, 0.35)
		check(value >= previous and value <= 1.0, "monotonic and bounded at step %d" % steps)
		previous = value
		steps += 1
	check(value == 1.0 and steps < 100, "lands exactly on the target, took %d steps" % steps)
	check_near(BoomMath.ease_offset(0.3, 1.0, 0.0, 0.08, 0.35), 0.3, 1e-12, "zero dt changes nothing")
	check_near(BoomMath.ease_offset(NAN, 1.0, DT, 0.08, 0.35), 0.0, 1e-12, "non-finite input returns 0")


func test_smooth_damp_arrives_without_overshoot_and_starts_gently() -> void:
	var value := 0.0
	var velocity := 0.0
	var previous := 0.0
	var first_step := 0.0
	var peak := 0.0
	var steps := 0
	while value != 1.0 and steps < 300:
		var next := BoomMath.smooth_damp(value, 1.0, velocity, 0.12, DT)
		value = next[0]
		velocity = next[1]
		if steps == 0:
			first_step = value
		peak = maxf(peak, velocity)
		check(value >= previous - 1e-12 and value <= 1.0, "monotonic and never past the target at step %d" % steps)
		previous = value
		steps += 1
	check(value == 1.0 and steps < 60, "lands exactly on the target within a second, took %d steps" % steps)
	check(first_step < 0.05, "a gentle start: the first tick moves %f of the way (an exponential ease at the same pace would move 0.13)" % first_step)
	check(peak > 4.0 and peak < 8.0, "the peak speed is about e^-1 * 2 / smooth_time = %f per second, got %f" % [2.0 / 0.12 * exp(-1.0), peak])


func test_smooth_damp_works_in_both_directions_and_from_a_moving_start() -> void:
	var value := 0.0
	var velocity := 0.0
	for i in 200:
		var next := BoomMath.smooth_damp(value, -2.0, velocity, 0.12, DT)
		value = next[0]
		velocity = next[1]
		check(value >= -2.0 - 1e-12, "a negative target is not overshot at step %d" % i)
	check(value == -2.0 and velocity == 0.0, "lands on a negative target and stops")
	# Retargeting while moving carries the velocity: no jump in value, and it still arrives.
	value = 0.0
	velocity = 0.0
	for i in 8:
		var next := BoomMath.smooth_damp(value, 1.0, velocity, 0.12, DT)
		value = next[0]
		velocity = next[1]
	var before := value
	var after := BoomMath.smooth_damp(value, 0.0, velocity, 0.12, DT)
	check(absf(after[0] - before) < 0.1 and after[1] != 0.0 and absf(after[1] - velocity) < 5.0, "a new target changes the acceleration: the position and the velocity carry on from where they were")
	var steps := 0
	value = after[0]
	velocity = after[1]
	while value != 0.0 and steps < 300:
		var next := BoomMath.smooth_damp(value, 0.0, velocity, 0.12, DT)
		value = next[0]
		velocity = next[1]
		steps += 1
	check(value == 0.0 and steps < 100, "arrives at the new target, took %d steps" % steps)
	check_near(BoomMath.smooth_damp(0.3, 1.0, 0.0, 0.12, 0.0)[0], 0.3, 1e-12, "zero dt changes nothing")
	check_eq(BoomMath.smooth_damp(NAN, 1.0, 0.0, 0.12, DT), PackedFloat64Array([0.0, 0.0]), "non-finite input returns [0, 0]")
	check_eq(BoomMath.smooth_damp(0.0, 1.0, 0.0, 0.0, DT).size(), 2, "a zero smooth time is tolerated")
