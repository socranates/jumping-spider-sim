extends "res://tests/test_case.gd"
## The safety line's drawing, the parts that need no scene (A-017, chunk 6A): widths in pixels, the strip a polyline
## becomes, and where the curve hangs. The line in a real world is tests/integration/test_silk.gd; how it looks is in
## tests/reports/shots (t06a_*).

const Silk = preload("res://scripts/presentation/silk_lines.gd")
const Tether = preload("res://scripts/movement/tether.gd")

const FOV := 75.0
const HEIGHT := 1080.0


## A line held by an anchor at `anchor` with `paid` of silk out, locked after a miss (no bend).
func _locked_line(anchor: Vector3, paid: float) -> Tether:
	var t := Tether.new()
	t.mode = Tether.Mode.LOCKED
	t.anchor_point = anchor
	t.paid_length = paid
	t.rest_length = paid
	t.max_length = 20.0
	return t


## Width of the strip at vertex pair i in screen pixels, for a camera at the origin looking along -Z and a point `depth` away.
func _strip_px(strip: Dictionary, i: int, depth: float) -> float:
	var v: PackedVector3Array = strip["vertices"]
	return v[2 * i].distance_to(v[2 * i + 1]) / Silk.pixel_size(depth, FOV, HEIGHT)


func test_widths_are_given_at_1080p_and_follow_the_screen_height() -> void:
	check_near(Silk.scaled_px(2.0, 1080.0), 2.0, 1e-6, "as given at 1080p")
	check_near(Silk.scaled_px(2.0, 2160.0), 4.0, 1e-6, "twice as many pixels on a screen twice as tall")
	check_near(Silk.scaled_px(2.0, 100.0), Silk.MIN_PX, 1e-6, "never below the minimum, however small the picture")
	check_eq(Silk.scaled_px(0.0, 1080.0), 0.0, "no rim stays no rim")
	check(Silk.scaled_px(Silk.ACTIVE_CORE_PX, 1080.0) >= 2.0, "the active line's core is at least 2 px at 1080p")
	check(Silk.scaled_px(Silk.LOADED_CORE_PX, 1080.0) > Silk.scaled_px(Silk.ACTIVE_CORE_PX, 1080.0), "a taut or reeling line is a little heavier")
	check(Silk.OLD_PX < Silk.ACTIVE_CORE_PX, "old silk is thinner than the line that takes the weight")


func test_a_pixel_has_a_world_size_that_follows_depth_and_the_picture_height() -> void:
	var expected := 2.0 * 10.0 * tan(deg_to_rad(FOV) * 0.5) / HEIGHT
	check_near(Silk.pixel_size(10.0, FOV, HEIGHT), expected, 1e-9, "2 * depth * tan(fov / 2) / height")
	check_near(Silk.pixel_size(20.0, FOV, HEIGHT), 2.0 * Silk.pixel_size(10.0, FOV, HEIGHT), 1e-9, "twice as far, twice as big")
	check_near(Silk.pixel_size(10.0, FOV, 2.0 * HEIGHT), 0.5 * Silk.pixel_size(10.0, FOV, HEIGHT), 1e-9, "twice as many pixels, half the size")
	check_near(Silk.pixel_size(10.0, FOV, HEIGHT) * HEIGHT * 0.5, 10.0 * tan(deg_to_rad(FOV) * 0.5), 1e-6, "the whole picture is what the camera sees")
	check(Silk.pixel_size(0.0, FOV, HEIGHT) > 0.0 and Silk.pixel_size(-3.0, FOV, HEIGHT) > 0.0, "a point at or behind the camera still gets a finite, positive size")


func test_the_strip_is_the_same_width_on_screen_at_any_distance_beyond_a_few_wu() -> void:
	var want := 2.0 + 2.0 * (Silk.RIM_PX + Silk.AA_PX)
	for d: float in [8.0, 12.0, 20.0, 40.0, 80.0]:
		var pts := PackedVector3Array([Vector3(0.0, 0.0, -d), Vector3(0.0, 1.0, -d)])
		var strip := Silk.ribbon(pts, Vector3.ZERO, Vector3.FORWARD, FOV, HEIGHT, 2.0, Silk.RIM_PX)
		check_near(_strip_px(strip, 0, d), want, 1e-3, "%.0f WU away the strip is %.2f px wide (2 px core, the rim and the smoothing margin each side)" % [d, want])
		check_near(_strip_px(strip, 1, d), want, 1e-3, "and its other end too")
		var core: PackedFloat32Array = strip["core"]
		var edge: PackedFloat32Array = strip["edge"]
		check_near(core[0], 1.0 / (1.0 + Silk.RIM_PX + Silk.AA_PX), 1e-6, "the core is its share of the half width")
		check_near(edge[0], (1.0 + Silk.RIM_PX) / (1.0 + Silk.RIM_PX + Silk.AA_PX), 1e-6, "and the rim ends at its share")


func test_close_up_the_core_keeps_some_body_and_the_strip_is_never_thinner_than_asked() -> void:
	var want := 2.0 + 2.0 * (Silk.RIM_PX + Silk.AA_PX)
	for d: float in [0.3, 0.6, 1.0, 2.0, 4.0, 8.0]:
		var pts := PackedVector3Array([Vector3(0.0, 0.0, -d), Vector3(0.0, 1.0, -d)])
		var strip := Silk.ribbon(pts, Vector3.ZERO, Vector3.FORWARD, FOV, HEIGHT, 2.0, Silk.RIM_PX)
		var v: PackedVector3Array = strip["vertices"]
		var core: PackedFloat32Array = strip["core"]
		check(_strip_px(strip, 0, d) >= want - 1e-3, "%.1f WU away: at least %.2f px (%.2f)" % [d, want, _strip_px(strip, 0, d)])
		check(v[0].distance_to(v[1]) * core[0] >= Silk.CORE_WORLD - 1e-6, "%.1f WU away: the core is at least %.3f WU across" % [d, Silk.CORE_WORLD])


func test_the_strip_faces_the_camera() -> void:
	var cam := Vector3(3.0, 2.0, 5.0)
	var forward := (Vector3(0.0, 1.0, 0.0) - cam).normalized()
	var pts := PackedVector3Array([Vector3(-4.0, 0.0, -6.0), Vector3(-2.0, 1.5, -5.0), Vector3(0.5, 2.0, -7.0), Vector3(2.0, 0.0, -9.0)])
	var strip := Silk.ribbon(pts, cam, forward, FOV, HEIGHT, 2.0, 1.0)
	var v: PackedVector3Array = strip["vertices"]
	for i in pts.size():
		var across := v[2 * i + 1] - v[2 * i]
		var tangent := pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
		check_near(absf(across.normalized().dot(tangent.normalized())), 0.0, 1e-5, "point %d: across the line" % i)
		check_near(absf(across.normalized().dot((cam - pts[i]).normalized())), 0.0, 1e-5, "point %d: and across the view of it" % i)
		check_vec_near((v[2 * i] + v[2 * i + 1]) * 0.5, pts[i], 1e-5, "point %d: centred on the point" % i)


func test_a_line_pointing_at_the_camera_or_with_no_length_still_makes_a_finite_strip() -> void:
	var cases: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3(0.0, 0.0, -10.0), Vector3(0.0, 0.0, -5.0)]),
		PackedVector3Array([Vector3(1.0, 1.0, -8.0), Vector3(1.0, 1.0, -8.0), Vector3(1.0, 1.0, -8.0)]),
		PackedVector3Array([Vector3(0.0, 0.0, -0.001), Vector3(0.0, 1.0, -0.001)]),
	]
	for i in cases.size():
		var pts: PackedVector3Array = cases[i]
		var strip := Silk.ribbon(pts, Vector3.ZERO, Vector3.FORWARD, FOV, HEIGHT, 2.0, 1.0)
		var v: PackedVector3Array = strip["vertices"]
		check_eq(v.size(), pts.size() * 2, "case %d: two vertices a point" % i)
		var finite := true
		for p: Vector3 in v:
			finite = finite and p.is_finite()
		check(finite, "case %d: all finite" % i)
		check(v[0].distance_to(v[1]) > 0.0, "case %d: and it has a width" % i)


func test_a_taut_line_is_drawn_straight_wherever_the_spinnerets_are_on_the_body() -> void:
	# The line is measured to the body's centre. The spinnerets are a little off it, and for a taut line that must not
	# read as slack (before this, a taut line hanging under a lip was drawn sagging into the cliff).
	var anchor := Vector3(0.0, 10.0, 0.0)
	var body := Vector3(0.0, 6.0, 0.0)
	var t := _locked_line(anchor, 4.0)
	for offset: Vector3 in [Vector3(0.0, 0.3, 0.0), Vector3(0.0, -0.3, 0.0), Vector3(0.3, 0.1, 0.2), Vector3(-0.2, 0.25, 0.1)]:
		var end := body + offset
		var pts := Silk.curve_points(t, end, body)
		check_vec_near(pts[0], anchor, 1e-6, "from the anchor")
		check_vec_near(pts[pts.size() - 1], end, 1e-6, "to the spinnerets")
		var worst := 0.0
		for p: Vector3 in pts:
			worst = maxf(worst, Geometry3D.get_closest_point_to_segment(p, anchor, end).distance_to(p))
		check(worst < 1e-5, "straight with the spinnerets %s off the centre: the worst point is %f off the line" % [str(offset), worst])


func test_a_slack_line_hangs_in_a_parabola_in_its_last_span() -> void:
	var anchor := Vector3(0.0, 10.0, 0.0)
	var body := Vector3(3.0, 10.0, 0.0)
	var t := _locked_line(anchor, 3.5)
	var pts := Silk.curve_points(t, body, body)
	var sag := Tether.sag_depth(3.0, 3.5)
	check(sag > 0.3, "there is a sag worth drawing: %f" % sag)
	check_eq(pts.size(), 1 + Silk.SEGMENTS_PER_SPAN, "the anchor and one run of points")
	var mid := pts[pts.size() / 2]
	check_near(mid.x, 1.5, 1e-5, "its lowest point is half way along")
	check_near(mid.y, 10.0 - sag, 1e-5, "sag_depth below the chord")
	var above := 0
	for p: Vector3 in pts:
		if p.y > 10.0 + 1e-6:
			above += 1
	check_eq(above, 0, "nothing of it rises above the chord: slack hangs")
	check_vec_near(pts[pts.size() - 1], body, 1e-6, "and it ends on the body")


func test_over_a_bend_only_the_last_span_sags_and_a_taut_line_is_straight_everywhere() -> void:
	var anchor := Vector3(0.0, 10.0, 0.0)
	var bend := Vector3(3.0, 10.0, 0.0)
	var body := Vector3(6.0, 9.0, 0.0)
	var path := anchor.distance_to(bend) + bend.distance_to(body)
	var taut := _locked_line(anchor, path)
	taut.has_bend = true
	taut.bend_point = bend
	var pts := Silk.curve_points(taut, body, body)
	check_eq(pts.size(), 1 + 2 * Silk.SEGMENTS_PER_SPAN, "two spans")
	check_vec_near(pts[Silk.SEGMENTS_PER_SPAN], bend, 1e-6, "the corner is the bend")
	var worst := 0.0
	for i in pts.size():
		var a := anchor if i <= Silk.SEGMENTS_PER_SPAN else bend
		var b := bend if i <= Silk.SEGMENTS_PER_SPAN else body
		worst = maxf(worst, Geometry3D.get_closest_point_to_segment(pts[i], a, b).distance_to(pts[i]))
	check(worst < 1e-5, "taut over the bend: both spans straight (%f)" % worst)
	var slack := _locked_line(anchor, path + 0.6)
	slack.has_bend = true
	slack.bend_point = bend
	var sagging := Silk.curve_points(slack, body, body)
	var first_span_worst := 0.0
	for i in range(0, Silk.SEGMENTS_PER_SPAN + 1):
		first_span_worst = maxf(first_span_worst, Geometry3D.get_closest_point_to_segment(sagging[i], anchor, bend).distance_to(sagging[i]))
	check(first_span_worst < 1e-5, "with slack the span from the anchor to the bend is still straight")
	var last_span_worst := 0.0
	for i in range(Silk.SEGMENTS_PER_SPAN, sagging.size()):
		last_span_worst = maxf(last_span_worst, Geometry3D.get_closest_point_to_segment(sagging[i], bend, body).distance_to(sagging[i]))
	check(last_span_worst > 0.1, "and the span from the bend to the body carries the slack (%f off the chord)" % last_span_worst)


func test_a_line_that_is_not_locked_is_drawn_straight() -> void:
	var t := Tether.new()
	t.mode = Tether.Mode.PAYOUT
	t.anchor_point = Vector3(0.0, 1.0, 0.0)
	t.paid_length = 12.0
	t.rest_length = 20.0
	t.max_length = 20.0
	var end := Vector3(4.0, 1.5, 0.0)
	var pts := Silk.curve_points(t, end, end)
	var worst := 0.0
	for p: Vector3 in pts:
		worst = maxf(worst, Geometry3D.get_closest_point_to_segment(p, t.anchor_point, end).distance_to(p))
	check(worst < 1e-5, "a line paying out follows the body: no sag (%f)" % worst)
