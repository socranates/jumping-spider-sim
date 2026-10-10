extends "res://tests/test_case.gd"
## Pure support geometry: the normal hysteresis filter, edge lines, rotations and the body frame.

const SupportMath = preload("res://scripts/movement/support_math.gd")


func test_hysteresis_keeps_the_normal_across_a_seam() -> void:
	var n := Vector3.UP
	var a := Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(0.6))
	var b := Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(-0.6))
	var changes := 0
	for i in 200:
		var next := SupportMath.filter_normal(n, a if i % 2 == 0 else b, 2.0)
		if next != n:
			changes += 1
		n = next
	check_eq(changes, 0, "alternating seam normals 1.2 degrees apart never move the frame")
	check_eq(n, Vector3.UP, "the frame stays exactly up")
	var slope := Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(25.0))
	check(SupportMath.filter_normal(Vector3.UP, slope, 2.0).is_equal_approx(slope), "a real slope change is taken")
	check_eq(SupportMath.filter_normal(Vector3.UP, Vector3(NAN, 1.0, 0.0), 2.0), Vector3.UP, "a non-finite probe normal is ignored")
	check_eq(SupportMath.filter_normal(Vector3.UP, Vector3.ZERO, 2.0), Vector3.UP, "a zero probe normal is ignored")


func test_edge_line_of_two_faces() -> void:
	# Top face y = 4.6 and east face x = 19 meet on the line x = 19, y = 4.6.
	var line := SupportMath.edge_line(Vector3(15.0, 4.6, 7.0), Vector3.UP, Vector3(19.0, 4.3, 5.0), Vector3.RIGHT)
	check_eq(line.size(), 2, "the planes meet")
	if line.size() == 2:
		var p: Vector3 = line[0]
		var d: Vector3 = line[1]
		check_near(p.x, 19.0, 1e-5, "on the east face")
		check_near(p.y, 4.6, 1e-5, "on the top face")
		check(absf(d.dot(Vector3.BACK)) > 0.9999, "along Z")
		check_vec_near(SupportMath.closest_on_line(Vector3(19.2, 4.9, 6.5), p, d), Vector3(19.0, 4.6, 6.5), 1e-5, "closest point on the edge")
	check(SupportMath.edge_line(Vector3.ZERO, Vector3.UP, Vector3.ONE, Vector3.UP).is_empty(), "parallel planes have no edge")


func test_rotations_and_body_frame() -> void:
	var q := SupportMath.rotation_between(Vector3.UP, Vector3.LEFT)
	check_vec_near(q * Vector3.UP, Vector3.LEFT, 1e-6, "rotation_between maps a onto b")
	check_vec_near(q * Vector3.RIGHT, Vector3.UP, 1e-6, "and carries a heading into the corner: walking +X into a west-facing wall becomes climbing")
	var flip := SupportMath.rotation_between(Vector3.UP, Vector3.DOWN)
	check_vec_near(flip * Vector3.UP, Vector3.DOWN, 1e-6, "opposite vectors still rotate")
	var step := SupportMath.rotate_toward(Vector3.UP, Vector3.RIGHT, deg_to_rad(10.0))
	check_near(rad_to_deg(Vector3.UP.angle_to(step)), 10.0, 1e-3, "rotate_toward is capped")
	check_vec_near(SupportMath.rotate_toward(Vector3.UP, Vector3.RIGHT, PI), Vector3.RIGHT, 1e-6, "and arrives")
	var b := SupportMath.body_basis(Vector3.DOWN, Vector3(1.0, 0.3, 0.0))
	check(b.is_conformal() and absf(b.determinant() - 1.0) < 1e-5, "the body frame is a rotation")
	check_vec_near(b.y, Vector3.DOWN, 1e-6, "up is the normal (upside down on a ceiling)")
	check_vec_near(-b.z, Vector3.RIGHT, 1e-6, "forward is the heading made tangent")
	check_near(SupportMath.signed_angle(Vector3.FORWARD, Vector3.LEFT, Vector3.UP), PI / 2.0, 1e-6, "signed angle about the normal")
