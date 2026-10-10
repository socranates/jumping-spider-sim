extends "res://tests/world_test_case.gd"
## T02 in the real lab with real Jolt: concave corners, convex edges, the underside, gaps, the
## coated panel, the thin shelf and the coplanar seam. Each test drives the motor with a world
## intent; the motor carries that intent across edges by itself. Every tick is checked for
## penetration with a sphere 0.005 WU smaller than the collider.

const Layers = preload("res://scripts/core/physics_layers.gd")

const PENETRATION_TOLERANCE := 0.005

var _probe := SphereShape3D.new()


## Sphere overlap against the world at the spider's position.
func _penetrates(spider: Node3D) -> bool:
	_probe.radius = 0.3 - PENETRATION_TOLERANCE
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _probe
	params.transform = Transform3D(Basis.IDENTITY, spider.global_position)
	params.collision_mask = Layers.WORLD
	return not world.get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


## Short name for the support face: surface id plus the normal's dominant axis, e.g. "floor+y".
func _face(spider: Node3D) -> String:
	if not spider.is_supported():
		return "none"
	var n: Vector3 = spider.get_support_normal()
	var axis := "?"
	if n.y > 0.99:
		axis = "+y"
	elif n.y < -0.99:
		axis = "-y"
	elif n.x > 0.99:
		axis = "+x"
	elif n.x < -0.99:
		axis = "-x"
	elif n.z > 0.99:
		axis = "+z"
	elif n.z < -0.99:
		axis = "-z"
	return "%s%s" % [spider.support.surface_id, axis]


## Runs up to max_ticks physics ticks. Records the faces visited (arc ticks skipped), states,
## penetration, the largest step per tick and arc lengths. Stops early when stop_when returns true.
func _run(spider: Node3D, max_ticks: int, stop_when: Callable = Callable()) -> Dictionary:
	var log := {"faces": [] as Array[String], "states": [] as Array[String], "penetrating_ticks": 0, "first_penetration": "", "max_step": 0.0, "arcs": [] as Array[int], "unsupported_ticks": 0, "ticks": 0}
	var arc_ticks := 0
	var last: Vector3 = spider.global_position
	var on_state := func(_old: int, new_state: int) -> void: (log["states"] as Array[String]).append(spider.State.keys()[new_state])
	spider.state_changed.connect(on_state)
	for i in max_ticks:
		await physics_frames(1)
		log["ticks"] = i + 1
		var p: Vector3 = spider.global_position
		log["max_step"] = maxf(log["max_step"], p.distance_to(last))
		last = p
		if _penetrates(spider):
			log["penetrating_ticks"] += 1
			if log["first_penetration"] == "":
				log["first_penetration"] = "tick %d at %s on %s" % [i, str(p), _face(spider)]
		if not spider.is_supported():
			log["unsupported_ticks"] += 1
		if spider.in_transition():
			arc_ticks += 1
			continue
		if arc_ticks > 0:
			(log["arcs"] as Array[int]).append(arc_ticks)
			arc_ticks = 0
		var f := _face(spider)
		var faces: Array[String] = log["faces"]
		if faces.is_empty() or faces[faces.size() - 1] != f:
			faces.append(f)
		if stop_when.is_valid() and stop_when.call():
			break
	spider.state_changed.disconnect(on_state)
	return log


## max_step: walking moves about 0.04 WU per tick and an edge arc about 0.06, so a bigger step is a
## snap. A free fall moves faster and passes its own bound.
func _clean(log: Dictionary, label: String, max_step: float = 0.1) -> void:
	check_eq(log["penetrating_ticks"], 0, "%s: no penetration (first: %s)" % [label, log["first_penetration"]])
	check(log["max_step"] < max_step, "%s: no snapping, largest step %f WU" % [label, log["max_step"]])


func _spawn(x: float, y: float, z: float, heading_deg: float) -> Node3D:
	spawn_world(Transform3D(Basis(Vector3.UP, deg_to_rad(heading_deg)), Vector3(x, y + 0.31, z)))
	await physics_frames(5)
	return world.spider


func test_floor_to_wall_climbs_at_a_concave_corner() -> void:
	var spider := await _spawn(5.0, 0.0, 15.5, 180.0)  # faces +Z, 2 WU from the south wall
	check_eq(spider.get_state_name(), "ATTACHED", "attached on the floor")
	var serial: int = spider.transition_serial
	spider.set_intent(Vector3.BACK, false)
	var log := await _run(spider, 120)
	_clean(log, "floor to wall")
	check_eq(log["faces"], ["floor+y", "wall_south-z"] as Array[String], "floor, then the south wall")
	check_eq(log["states"], [] as Array[String], "no state change: attached throughout")
	check(spider.transition_serial > serial, "the corner counts as a transition")
	var p: Vector3 = spider.global_position
	check(p.y > 1.2, "climbing the wall, centre at y = %f" % p.y)
	check_near(p.z, 17.5 - 0.31, 0.02, "held at the seat distance from the wall")
	check(spider.get_visual_up().dot(Vector3.BACK * -1.0) > 0.95, "the body's up vector follows the wall normal")


func test_wall_to_top_over_a_convex_edge() -> void:
	var spider := await _spawn(2.0, 0.0, 5.0, 90.0)  # faces -X toward the block's east face at x = 0
	spider.set_intent(Vector3.LEFT, false)
	var log := await _run(spider, 300, func() -> bool: return spider.global_position.x < -1.5 and spider.support.surface_id == "block" and spider.get_support_normal().y > 0.99)
	_clean(log, "block")
	check_eq(log["faces"], ["floor+y", "block+x", "block+y"] as Array[String], "floor, the block's east face, its top")
	check_eq(log["states"], [] as Array[String], "attached throughout")
	var arcs: Array[int] = log["arcs"]
	check_eq(arcs.size(), 1, "one edge arc, at the crest")
	if arcs.size() == 1:
		check(arcs[0] >= 9 and arcs[0] <= 16, "the arc takes 0.15 to 0.25 s (%d ticks)" % arcs[0])
	check_near(spider.global_position.y, 3.4 + 0.31, 0.02, "seated on the block top")


func test_wall_to_underside_and_back() -> void:
	var spider := await _spawn(27.0, 0.0, 5.0, -90.0)  # faces +X toward the east wall, under the overhang
	spider.set_intent(Vector3.RIGHT, false)
	var log := await _run(spider, 240, func() -> bool: return spider.support.surface_id == "overhang" and spider.global_position.x < 28.0)
	_clean(log, "up to the underside")
	check_eq(log["faces"], ["floor+y", "wall_east-x", "overhang-y"] as Array[String], "floor, east wall, the overhang's underside")
	check_near(spider.global_position.y, 3.0 - 0.31, 0.02, "hanging 0.31 WU under the underside")
	check(spider.get_intent().x < -0.9, "the intent was carried round: now heading west, away from the wall")
	spider.set_intent(Vector3.RIGHT, false)  # back the way it came
	var back := await _run(spider, 300, func() -> bool: return spider.support.surface_id == "floor" and spider.global_position.x < 29.0)
	_clean(back, "back down")
	check_eq(back["faces"], ["overhang-y", "wall_east-x", "floor+y"] as Array[String], "underside, wall, floor")
	check_eq((log["states"] as Array).size() + (back["states"] as Array).size(), 0, "attached the whole way")
	check(spider.get_visual_up().y > 0.9, "upright again")


func test_gap_is_crossed_only_along_surfaces() -> void:
	var spider := await _spawn(10.5, 2.0, -4.0, -90.0)  # on gap_left, facing +X toward the gap
	spider.set_intent(Vector3.RIGHT, false)
	var log := await _run(spider, 360)
	_clean(log, "gap")
	check_eq(log["faces"], ["gap_left+y", "gap_left+x", "floor+y"] as Array[String], "down gap_left's side face to the floor, never across")
	check_eq(log["states"], [] as Array[String], "never falls: gap_left's side face holds the spider")
	var p: Vector3 = spider.global_position
	check_near(p.x, 15.0 - 0.31, 0.03, "stopped at gap_right's coated face, which cannot be climbed")
	check_near(p.y, 0.31, 0.02, "still on the floor")


func test_gap_with_nothing_reachable_falls() -> void:
	var spider := await _spawn(16.0, 2.0, -4.0, 90.0)  # on gap_right (coated), facing -X toward the gap
	spider.set_intent(Vector3.LEFT, false)
	var log := await _run(spider, 240, func() -> bool: return spider.get_state_name() == "ATTACHED" and spider.support.surface_id == "floor")
	spider.set_intent(Vector3.ZERO, false)
	_clean(log, "fall", 0.25)
	check_eq(log["states"], ["FALLING", "LANDING", "ATTACHED"] as Array[String], "falls, lands, re-attaches")
	check_eq(log["faces"], ["gap_right+y", "none", "floor+y"] as Array[String], "no support while falling; lands on the floor, not on gap_left")
	check(spider.global_position.x > 12.3, "landed in the gap, short of gap_left (x = %f)" % spider.global_position.x)


func test_coated_panel_cannot_be_climbed() -> void:
	var spider := await _spawn(13.5, 0.0, 12.0, 180.0)  # faces +Z toward the panel's face at z = 14
	var serial: int = spider.transition_serial
	spider.set_intent(Vector3.BACK, false)
	var log := await _run(spider, 150)
	_clean(log, "panel")
	check_eq(log["faces"], ["floor+y"] as Array[String], "stays on the floor")
	check_eq(spider.transition_serial, serial, "no transition onto the panel")
	check_near(spider.global_position.z, 14.0 - 0.3, 0.02, "stopped against the panel")
	check_near(spider.global_position.y, 0.31, 0.01, "not lifted onto it")


func test_thin_shelf_is_wrapped_never_crossed() -> void:
	var spider := await _spawn(-28.0, 1.7, -13.0, -90.0)  # on the 0.2 WU shelf, facing +X toward its free end
	spider.set_intent(Vector3.RIGHT, false)
	var crossed := [0]
	var shelf: AABB = world.lab.get_piece_aabb("thin_shelf")
	var watch := func() -> bool:
		var p: Vector3 = spider.global_position
		if p.x < shelf.end.x and p.z > shelf.position.z and p.z < shelf.end.z and p.y > shelf.position.y - 0.25 and p.y < shelf.end.y + 0.25:
			crossed[0] += 1  # centre within the slab's band: it went through
		return spider.support.surface_id == "wall_west"
	var log := await _run(spider, 360, watch)
	_clean(log, "thin shelf")
	check_eq(crossed[0], 0, "the centre never passes through the shelf")
	check_eq(log["faces"], ["thin_shelf+y", "thin_shelf+x", "thin_shelf-y", "wall_west+x"] as Array[String], "top, the 0.2 WU end, the underside, the wall")
	check_eq(log["states"], [] as Array[String], "attached throughout")
	check_eq((log["arcs"] as Array).size(), 2, "two edge arcs around the thin end")


func test_coplanar_seam_does_not_jitter() -> void:
	var spider := await _spawn(23.0, 1.0, -13.0, -90.0)  # on seam_a, facing +X toward seam_b
	var serial: int = spider.transition_serial
	spider.set_intent(Vector3.RIGHT, false)
	var ids: Array[String] = []
	var y_lo := INF
	var y_hi := -INF
	var tilted := 0
	for i in 110:
		await physics_frames(1)
		if spider.get_support_normal() != Vector3.UP or spider.get_visual_up() != Vector3.UP:
			tilted += 1
		y_lo = minf(y_lo, spider.global_position.y)
		y_hi = maxf(y_hi, spider.global_position.y)
		var id: String = spider.support.surface_id
		if ids.is_empty() or ids[ids.size() - 1] != id:
			ids.append(id)
	check(spider.global_position.x > 26.0, "crossed the seam at x = 25 (x = %f)" % spider.global_position.x)
	check_eq(ids, ["seam_a", "seam_b"] as Array[String], "support moves to the next piece once and never back")
	check_eq(tilted, 0, "the normal never moves")
	check(y_hi - y_lo < 0.001, "no bump at the seam, height range %f" % (y_hi - y_lo))
	check_eq(spider.transition_serial, serial, "a seam is not a transition")
	check_eq(spider.get_state_name(), "ATTACHED", "attached")


func test_support_view_toggles_with_f4_and_draws_the_normal() -> void:
	spawn_world(null, true)
	await physics_frames(5)
	var view: Node3D = world.support_debug
	check(not view.visible, "hidden by default")
	var press := InputEventAction.new()
	press.action = "debug_support"
	press.pressed = true
	Input.parse_input_event(press)
	await physics_frames(2)
	var release := InputEventAction.new()
	release.action = "debug_support"
	release.pressed = false
	Input.parse_input_event(release)
	await process_frames(2)
	check(view.visible, "F4 shows it")
	var arrow := view.get_node("NormalArrow") as Node3D
	var spider: Node3D = world.spider
	check(arrow.visible, "the normal arrow is drawn while supported")
	check(arrow.global_transform.basis.y.normalized().is_equal_approx(spider.get_support_normal()), "the arrow points along the support normal")
	check_vec_near(arrow.global_position, spider.support.contact_point, 1e-4, "from the contact point")
	check(not spider.debug_rays.is_empty(), "the motor reports its probe rays")
	var shown := view.get_node("ProbeRays").get_children().filter(func(c: Node) -> bool: return (c as Node3D).visible)
	check_eq(shown.size(), spider.debug_rays.size(), "one rod per probe ray of the last tick")


func test_walking_off_an_edge_at_a_shallow_angle_still_wraps() -> void:
	# On ledge_2's top (x -10..-7), heading 10 degrees off its east edge: the body crosses the edge
	# almost sideways. It must still find the side face, not fall.
	var heading := Vector3(sin(deg_to_rad(10.0)), 0.0, cos(deg_to_rad(10.0)))
	var spider := await _spawn(-7.35, 2.0, -13.6, rad_to_deg(atan2(-heading.x, -heading.z)))
	spider.set_intent(heading, false)
	var log := await _run(spider, 200, func() -> bool: return spider.support.surface_id == "floor")
	_clean(log, "shallow edge")
	check_eq(log["states"], [] as Array[String], "never falls")
	check_eq((log["faces"] as Array).slice(0, 2), ["ledge_2+y", "ledge_2+x"], "wraps onto the east face")


func test_inside_corner_of_two_walls_does_not_oscillate() -> void:
	# Diagonally into the inside corner of corner_a (north face z = -9.6) and corner_b (west face
	# x = -20.6). The spider climbs one wall, then the other takes it, then it climbs away.
	var dir := Vector3(1.0, 0.0, 1.0).normalized()
	var spider := await _spawn(-22.5, 0.0, -11.5, rad_to_deg(atan2(-dir.x, -dir.z)))
	var serial: int = spider.transition_serial
	spider.set_intent(dir, false)
	var log := await _run(spider, 180)
	_clean(log, "inside corner")
	check_eq(log["states"], [] as Array[String], "never falls")
	check(spider.transition_serial - serial <= 3, "a few transitions, no back and forth (%d)" % (spider.transition_serial - serial))
	check(spider.global_position.y > 1.5, "climbing, y = %f" % spider.global_position.y)
	var faces: Array[String] = log["faces"]
	check(faces.size() <= 3, "floor and at most two walls, each once: %s" % str(faces))
