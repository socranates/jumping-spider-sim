extends "res://tests/test_case.gd"
## Camera-relative stick mapping (SurfaceInput) on floors, walls and undersides. "Where the screen
## says" is checked by projecting through a camera placed the way the rig places it (pivot 0.45 WU
## along the normal, boom behind at the given yaw and pitch): right must move the spider right on
## screen; forward must move it up on screen on floors and walls, and away from the camera on the
## underside.

const SurfaceInput = preload("res://scripts/movement/surface_input.gd")
const BoomMath = preload("res://scripts/movement/boom_math.gd")

const STEP := 0.05


## [screen x, screen y (up), depth] of world point p seen from camera transform cam.
func _screen(cam: Transform3D, p: Vector3) -> Vector3:
	var c := cam.affine_inverse() * p
	return Vector3(c.x / -c.z, c.y / -c.z, -c.z)


func _camera(spider: Vector3, n: Vector3, yaw: float, elevation: float, distance: float) -> Transform3D:
	var b := BoomMath.orbit_basis(yaw, elevation)
	return Transform3D(b, spider + n * 0.45 + b.z * distance)


## Moves the spider along the mapped stick and returns the screen-space change.
func _moved(cam: Transform3D, spider: Vector3, stick: Vector2, yaw: float, elevation: float, n: Vector3) -> Vector3:
	var d := SurfaceInput.map_stick(stick, yaw, elevation, n)
	return _screen(cam, spider + d * STEP) - _screen(cam, spider)


func test_floor_mapping_is_the_chunk_2_mapping() -> void:
	for yaw in [0.0, 0.7, -2.5, PI]:
		for elev_deg in [18.0, 45.0, 80.0, -20.0]:
			var e := deg_to_rad(elev_deg)
			var f := SurfaceInput.map_stick(Vector2(0.0, 1.0), yaw, e, Vector3.UP)
			var r := SurfaceInput.map_stick(Vector2(1.0, 0.0), yaw, e, Vector3.UP)
			check_vec_near(f, Vector3(-sin(yaw), 0.0, -cos(yaw)), 1e-5, "floor forward is the camera's flat forward (yaw %f, pitch %f)" % [yaw, elev_deg])
			check_vec_near(r, Vector3(cos(yaw), 0.0, -sin(yaw)), 1e-5, "floor right is the camera's right (yaw %f, pitch %f)" % [yaw, elev_deg])


func test_floor_forward_and_right_go_where_the_screen_says() -> void:
	var spider := Vector3(1.0, 0.31, 2.0)
	for yaw in [0.0, 1.1, -2.0]:
		for elev_deg in [18.0, 50.0]:
			var e := deg_to_rad(elev_deg)
			var cam := _camera(spider, Vector3.UP, yaw, e, 5.0)
			var fwd := _moved(cam, spider, Vector2(0.0, 1.0), yaw, e, Vector3.UP)
			var right := _moved(cam, spider, Vector2(1.0, 0.0), yaw, e, Vector3.UP)
			check(fwd.y > 0.0 and absf(fwd.x) < 1e-4, "forward moves up the screen (yaw %f, pitch %f): %s" % [yaw, elev_deg, str(fwd)])
			check(right.x > 0.0, "right moves right on screen (yaw %f, pitch %f): %s" % [yaw, elev_deg, str(right)])


func test_wall_forward_climbs_and_right_goes_right() -> void:
	var spider := Vector3(0.0, 2.0, 0.0)
	for yaw in [0.0, 0.9, -2.2]:
		var facing := Vector3(sin(yaw), 0.0, cos(yaw))  # wall normal pointing at the camera
		for turn_deg in [0.0, 30.0, -40.0]:
			var n := facing.rotated(Vector3.UP, deg_to_rad(turn_deg))  # the wall seen straight on or obliquely
			for elev_deg in [18.0, 45.0, 70.0]:
				var e := deg_to_rad(elev_deg)
				var cam := _camera(spider, n, yaw, e, 5.0)
				var label := "yaw %f, wall turned %f, pitch %f" % [yaw, turn_deg, elev_deg]
				var f := SurfaceInput.map_stick(Vector2(0.0, 1.0), yaw, e, n)
				# Looking steeply down at a wall seen at an angle, up the screen is mostly along the
				# wall, so forward still climbs but less steeply.
				check(f.y > (0.5 if elev_deg <= 45.0 else 0.2), "forward climbs the wall (%s): %s" % [label, str(f)])
				check(_moved(cam, spider, Vector2(0.0, 1.0), yaw, e, n).y > 0.0, "forward moves up the screen (%s)" % label)
				check(_moved(cam, spider, Vector2(1.0, 0.0), yaw, e, n).x > 0.0, "right moves right on screen (%s)" % label)


func test_underside_forward_moves_away_from_the_camera() -> void:
	var spider := Vector3(0.0, 2.69, 0.0)
	var n := Vector3.DOWN
	for yaw in [0.0, 1.3, -2.8]:
		for elev_deg in [18.0, -15.0]:
			var e := deg_to_rad(elev_deg)
			var cam := _camera(spider, n, yaw, e, 1.8)
			var label := "yaw %f, pitch %f" % [yaw, elev_deg]
			var fwd := _moved(cam, spider, Vector2(0.0, 1.0), yaw, e, n)
			check(fwd.z > STEP * 0.9, "forward moves away from the camera (%s): depth change %f" % [label, fwd.z])
			check_vec_near(SurfaceInput.map_stick(Vector2(0.0, 1.0), yaw, e, n), Vector3(-sin(yaw), 0.0, -cos(yaw)), 1e-5, "forward is the camera's flat forward, not flipped (%s)" % label)
			check(_moved(cam, spider, Vector2(1.0, 0.0), yaw, e, n).x > 0.0, "right moves right on screen (%s)" % label)


func test_mapping_is_unit_perpendicular_and_keeps_the_stick_length() -> void:
	var normals := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.BACK, Vector3(0.3, 0.8, -0.2).normalized(), Vector3(-0.5, -0.7, 0.4).normalized(), Vector3(0.0, -0.7071, 0.7071)]
	for n: Vector3 in normals:
		for yaw in [0.0, 2.0, -1.0]:
			var axes := SurfaceInput.tangent_axes(yaw, deg_to_rad(18.0), n)
			var r: Vector3 = axes["right"]
			var f: Vector3 = axes["forward"]
			check(r.is_normalized() and f.is_normalized(), "unit axes for %s" % str(n))
			check(absf(r.dot(f)) < 1e-4 and absf(r.dot(n)) < 1e-4 and absf(f.dot(n)) < 1e-4, "perpendicular and on the plane for %s" % str(n))
			var v := SurfaceInput.map_stick(Vector2(0.6, -0.3), yaw, deg_to_rad(18.0), n)
			check_near(v.length(), Vector2(0.6, -0.3).length(), 1e-5, "keeps the stick length for %s" % str(n))
	check_eq(SurfaceInput.map_stick(Vector2.ZERO, 0.0, 0.3, Vector3.UP), Vector3.ZERO, "no stick, no intent")
	check_eq(SurfaceInput.map_stick(Vector2(NAN, 1.0), 0.0, 0.3, Vector3.UP), Vector3.ZERO, "a non-finite stick gives no intent")
	check_near(SurfaceInput.map_stick(Vector2(3.0, 4.0), 0.0, 0.3, Vector3.UP).length(), 1.0, 1e-6, "an over-long stick is limited to 1")


func test_mapping_turns_smoothly_as_a_floor_tilts_into_a_wall() -> void:
	# From floor to a wall facing the camera, forward turns from flat-forward to up through the
	# blend band without jumps.
	var worst := 0.0
	var last := SurfaceInput.map_stick(Vector2(0.0, 1.0), 0.0, deg_to_rad(18.0), Vector3.UP)
	for i in range(1, 91):
		var n := Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(float(i)))  # tilts toward the camera at +Z
		var f := SurfaceInput.map_stick(Vector2(0.0, 1.0), 0.0, deg_to_rad(18.0), n)
		worst = maxf(worst, rad_to_deg(f.angle_to(last)))
		last = f
	check(worst < 4.0, "forward turns at most 4 degrees per degree of tilt, worst %f" % worst)
