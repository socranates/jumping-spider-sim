extends "res://tests/test_case.gd"
## The safety line's pure parts (spec 9.1, 21.3, 27: "tether never pushes when slack; values remain finite"):
## the unilateral constraint step, the TetherState record and its bounds, and the helpers the motor and the
## drawing use. The line in the real physics world is tests/integration/test_tether.gd and gate M03.

const Tether = preload("res://scripts/movement/tether.gd")

const G := 35.0
const DT := 1.0 / 60.0
## Machine epsilon of a 32-bit float (2^-23). Vector3 components are 32-bit, so a dot product of two vectors
## of length |v| carries a few epsilons of |v| in rounding.
const F32_EPS := 1.1920929e-7


func test_a_slack_line_changes_nothing() -> void:
	var pivot := Vector3(0.0, 5.0, 0.0)
	for i in 200:
		var target := pivot + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).limit_length(1.99)
		var v := Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0))
		var c := Tether.constrain(pivot, 2.0, target, v)
		check(not c["acted"], "inside the length the line takes no load")
		check_vec_near(c["position"], target, 0.0, "position unchanged")
		check_vec_near(c["velocity"], v, 0.0, "velocity unchanged")


func test_a_taut_line_only_removes_the_excess_and_outward_speed_and_never_pushes() -> void:
	var pivot := Vector3(1.0, 6.0, -2.0)
	var length := 3.0
	for i in 500:
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if dir.length() < 0.1:
			continue
		dir = dir.normalized()
		var target := pivot + dir * rng.randf_range(length + 1e-3, length + 1.0)
		var v := Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
		var c := Tether.constrain(pivot, length, target, v)
		var r := dir
		var p: Vector3 = c["position"]
		var out: Vector3 = c["velocity"]
		check(c["acted"], "beyond the length the line takes load")
		check_near(p.distance_to(pivot), length, 1e-5, "put back on the length, no closer")
		check_vec_near((p - pivot).normalized(), r, 1e-5, "along the same radial line: only the excess is taken off")
		var u := v.dot(r)
		var u_after := out.dot(r)
		# The radial direction here is the one the target was built from; the constraint re-derives its own from
		# target - pivot in 32-bit floats, so the two differ by about an epsilon and a speed of 10 WU/s shows
		# a residual of a few 1e-7. The tolerance is 8 epsilons of the speed (a fixed 1e-6 is below float32's
		# resolution at |v| = 14). test_the_constraint_residuals_are_float32_rounding_not_a_push shows the
		# residual has no sign and no bias.
		var tol := 8.0 * F32_EPS * maxf(v.length(), 1.0)
		check(u_after <= maxf(u, 0.0) + tol, "no outward speed is added")
		check(u_after >= minf(u, 0.0) - tol, "no inward speed is added: the line never pushes")
		check(u_after <= tol, "no outward speed is left")
		check_vec_near(out - r * u_after, v - r * u, 1e-5, "tangential motion is kept exactly")
		check(out.length() <= v.length() + tol, "the line never adds speed")
		check(float(c["tangential_change"]) < 1e-5, "and reports no tangential change")


func test_the_constraint_residuals_are_float32_rounding_not_a_push() -> void:
	# Over many random taut steps the speed left along the line after the constraint removed the outward part
	# (it is zero in exact arithmetic) must be within a few float32 epsilons of |v|, must have no preferred sign
	# and must average out: rounding. A real push would show as a bias or as something that grows with |v|.
	var pivot := Vector3(1.0, 6.0, -2.0)
	var length := 3.0
	var worst := 0.0
	var sum := 0.0
	var negative := 0
	var positive := 0
	var count := 0
	for i in 20000:
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if dir.length() < 0.1:
			continue
		dir = dir.normalized()
		var v := Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
		if v.dot(dir) <= 0.0:
			continue  # moving inward: the line does nothing, nothing to measure
		var c := Tether.constrain(pivot, length, pivot + dir * rng.randf_range(length + 1e-3, length + 1.0), v)
		var residual: float = (c["velocity"] as Vector3).dot(dir) / v.length()
		worst = maxf(worst, absf(residual))
		sum += residual
		if residual < 0.0:
			negative += 1
		elif residual > 0.0:
			positive += 1
		count += 1
	check(count > 5000, "enough outward trials: %d" % count)
	check(worst <= 4.0 * F32_EPS, "the largest leftover is %s of the speed, %s epsilons" % [String.num(worst, 10), String.num(worst / F32_EPS, 2)])
	check(absf(sum / float(count)) <= 0.05 * F32_EPS, "no bias: the mean leftover is %s of the speed" % String.num(sum / float(count), 12))
	check(negative > count * 3 / 10 and positive > count * 3 / 10, "no preferred sign: %d negative, %d positive of %d" % [negative, positive, count])


func test_a_pendulum_stepped_with_it_settles_with_damping_and_stays_on_its_length() -> void:
	# The motor's loop without collisions: gravity, swing damping, the constraint, and the energy limit.
	var pivot := Vector3(0.0, 10.0, 0.0)
	var length := 3.0
	var p := pivot + Vector3(length, 0.0, 0.0)  # level with the pivot: the biggest swing
	var v := Vector3.ZERO
	var e_start := Tether.energy(p, v, G)
	var e_prev := e_start
	var worst_gain := 0.0
	for i in 600:
		var e0 := Tether.energy(p, v, G)
		v.y -= G * DT
		var r := (p - pivot).normalized()
		var vt := v - r * v.dot(r)
		v -= vt * (1.0 - exp(-1.6 * DT))
		var c := Tether.constrain(pivot, length, p + v * DT, v)
		p = c["position"]
		v = c["velocity"]
		var e1 := Tether.energy(p, v, G)
		if e1 > e0:
			var ke := 0.5 * v.length_squared()
			var allowed := maxf(e0 - G * p.y, 0.0)
			v *= sqrt(clampf(allowed / ke, 0.0, 1.0)) if ke > 1e-12 else 0.0
		worst_gain = maxf(worst_gain, Tether.energy(p, v, G) - e_prev)
		e_prev = Tether.energy(p, v, G)
		check(absf(p.distance_to(pivot) - length) < 1e-4 or p.distance_to(pivot) < length, "never beyond the length")
	# A step may gain no more than one float32 step of the body's height: at y = 8..10 the 32-bit position moves in
	# steps of 2^-20 = 9.5e-7 WU, which is 3.3e-5 of energy (g times that), so the position alone cannot be
	# resolved finer than that. (A bound of 1e-6 was below the resolution of the quantity it checks; the check
	# never ran before, because its message used a format GDScript lacks.)
	var one_step := G * 8.0 * F32_EPS
	check(worst_gain <= one_step, "no step gains energy beyond one float32 step of height (%s), worst %s" % [String.num(one_step, 9), String.num(worst_gain, 9)])
	check(v.length() < 0.05, "after 10 s the swing has died away: %f WU/s" % v.length())
	check(p.distance_to(pivot + Vector3.DOWN * length) < 0.05, "hanging straight down: %s" % str(p))
	check(e_prev < e_start, "energy went down overall")


func test_the_state_record_has_the_spec_fields_and_bounded_lengths() -> void:
	var t := Tether.new()
	check(not t.is_active(), "a new line is none")
	check(t.is_consistent(), "none is consistent")
	t.mode = Tether.Mode.LOCKED
	t.anchor_surface_id = "tower_w"
	t.anchor_local = Vector3(1.0, 5.0, 0.0)
	t.anchor_point = Vector3(0.0, 10.0, 0.0)
	t.max_length = 20.0
	t.rest_length = 5.0
	t.paid_length = 4.0
	check(t.is_consistent(), "0 <= paid <= rest <= max")
	var d := t.to_dict()
	for key in ["anchor_surface_id", "anchor_local", "paid_length", "max_length", "taut", "bend", "reel_intent", "rest_length", "mode"]:
		check(d.has(key), "spec 21.3 TetherState field %s" % key)
	t.paid_length = 6.0
	check(not t.is_consistent(), "paid beyond rest is caught")
	t.paid_length = 4.0
	t.rest_length = 25.0
	check(not t.is_consistent(), "rest beyond max is caught")
	t.rest_length = -1.0
	check(not t.is_consistent(), "a negative length is caught")
	t.rest_length = NAN
	check(not t.is_consistent(), "a non-finite length is caught")
	t.clear()
	check(not t.is_active() and t.anchor_surface_id == "" and not t.has_bend, "clear empties it")


func test_a_bend_point_splits_the_path_and_shortens_the_free_length() -> void:
	var t := Tether.new()
	t.mode = Tether.Mode.LOCKED
	t.anchor_point = Vector3(0.0, 6.0, 0.0)
	t.max_length = 20.0
	t.rest_length = 4.0
	var body := Vector3(1.0, 3.0, 0.0)
	check_near(t.path_length(body), t.anchor_point.distance_to(body), 1e-6, "straight without a bend")
	check_vec_near(t.pivot(), t.anchor_point, 0.0, "the pivot is the anchor")
	check_near(t.effective_length(), 4.0, 1e-6, "the whole rest length is free")
	t.has_bend = true
	t.bend_point = Vector3(1.0, 6.0, 0.0)
	check_vec_near(t.pivot(), t.bend_point, 0.0, "with a bend the pivot is the bend point")
	check_near(t.path_length(body), 1.0 + 3.0, 1e-6, "anchor to bend plus bend to body")
	check_near(t.effective_length(), 3.0, 1e-6, "the free length is what is left after the bend")
	check_eq(t.points(body).size(), 3, "anchor, bend, end")


func test_drawing_and_accounting_helpers() -> void:
	check_near(Tether.sag_depth(4.0, 4.0), 0.0, 1e-9, "a taut line does not sag")
	check(Tether.sag_depth(4.0, 4.5) > 0.5, "a slack line sags: %f" % Tether.sag_depth(4.0, 4.5))
	check(Tether.sag_depth(4.0, 40.0) <= 3.0, "sag is capped")
	check_near(Tether.reel_work_bound(0.1, G, 0.0, 2.0), 0.1 * G, 1e-9, "hanging still: shortening times gravity")
	check(Tether.reel_work_bound(0.1, G, 4.0, 2.0) > 0.1 * G, "a swing adds its centripetal load")
	check_near(Tether.reel_work_bound(-1.0, G, 4.0, 2.0), 0.0, 1e-9, "lowering does no reel work")
	check_near(Tether.energy(Vector3(0.0, 2.0, 0.0), Vector3(3.0, 0.0, 4.0), G), 12.5 + 70.0, 1e-9, "energy per unit mass")
