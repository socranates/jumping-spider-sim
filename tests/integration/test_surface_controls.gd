extends "res://tests/world_test_case.gd"
## Input to motion on walls and undersides through the real player controller and camera rig:
## named actions in, camera-relative movement out. Also the heading carry at an edge, the camera
## pivot under a ceiling, and recenter on a wall.

const SupportMath = preload("res://scripts/movement/support_math.gd")
const ACTIONS := ["move_forward", "move_back", "move_left", "move_right"]


func after_each() -> void:
	for a: String in ACTIONS:
		Input.action_release(a)


func _hold(action: String, ticks: int) -> Vector3:
	var spider: Node3D = world.spider
	var start := spider.global_position
	Input.action_press(action)
	await physics_frames(ticks)
	Input.action_release(action)
	await physics_frames(20)
	return spider.global_position - start


func _level(label: String) -> void:
	var b: Basis = world.camera_rig.camera.global_transform.basis
	check(absf(b.x.y) < 1e-4 and b.y.y > 0.0, "%s: the camera does not roll" % label)


func test_on_a_wall_forward_climbs_and_right_goes_to_the_cameras_right() -> void:
	# On the south wall (normal -Z), facing up. The camera recenters to face the wall (looking +Z).
	spawn_world(Transform3D(SupportMath.body_basis(Vector3.FORWARD, Vector3.UP), Vector3(0.0, 2.0, 17.5 - 0.31)), true)
	await physics_frames(10)
	var spider: Node3D = world.spider
	check_eq(spider.support.surface_id, "wall_south", "starts on the wall")
	check_near(angle_difference(world.camera_rig.yaw, PI), 0.0, 0.01, "the camera faces the wall")
	var up := await _hold("move_forward", 40)
	check(up.y > 1.0 and absf(up.x) < 0.1, "forward climbs, moved %s" % str(up))
	var right := await _hold("move_right", 40)
	check(right.x < -1.0 and absf(right.y) < 0.15, "right moves to the camera's right (-X when looking +Z), moved %s" % str(right))
	var down := await _hold("move_back", 30)
	check(down.y < -0.8, "back climbs down, moved %s" % str(down))
	check_eq(spider.support.surface_id, "wall_south", "still on the wall")
	_level("on the wall")


func test_on_the_underside_forward_moves_away_from_the_camera() -> void:
	# Under the overhang (underside y = 3), heading west. The camera recenters behind, to the east.
	spawn_world(Transform3D(SupportMath.body_basis(Vector3.DOWN, Vector3.LEFT), Vector3(26.0, 3.0 - 0.31, 5.0)), true)
	await physics_frames(10)
	var spider: Node3D = world.spider
	var rig: Node3D = world.camera_rig
	check_eq(spider.support.surface_id, "overhang", "starts on the underside")
	check_near(angle_difference(rig.yaw, PI / 2.0), 0.0, 0.01, "the camera is behind the spider, looking west")
	var cam_before: Vector3 = rig.camera.global_position
	var gap_before := Vector2(spider.global_position.x - cam_before.x, spider.global_position.z - cam_before.z).length()
	var moved := await _hold("move_forward", 40)
	check(moved.x < -1.0 and absf(moved.z) < 0.1 and absf(moved.y) < 0.01, "forward moves west along the underside, moved %s" % str(moved))
	var cam: Vector3 = rig.camera.global_position
	var gap_after := Vector2(spider.global_position.x - cam.x, spider.global_position.z - cam.z).length()
	check(gap_after >= gap_before - 0.05, "away from the camera, not toward it (%f to %f)" % [gap_before, gap_after])
	var right := await _hold("move_right", 30)
	check(right.z < -0.6, "right moves to the camera's right (-Z when looking west), moved %s" % str(right))
	check(rig.global_position.y < spider.global_position.y - 0.3, "the camera pivot hangs below the spider")
	check(cam.y < 3.0, "the camera stays below the underside, y = %f" % cam.y)
	check(point_is_clear_in_physics(cam, 0.1), "and outside the overhang")
	_level("under the overhang")


func test_holding_forward_over_an_edge_never_oscillates() -> void:
	# On the block top facing +X, camera behind. Holding forward walks off the east edge, down the
	# east face (where forward would mean "up" for a fresh mapping) and out across the floor.
	spawn_world(Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-2.0, 3.4 + 0.31, 5.0)), true)
	await physics_frames(10)
	var spider: Node3D = world.spider
	var faces: Array[String] = []
	var carried := 0
	Input.action_press("move_forward")
	for i in 240:
		await physics_frames(1)
		if world.controller.is_carrying():
			carried += 1
		if spider.in_transition():
			continue
		var n: Vector3 = spider.get_support_normal()
		var f: String = "%s%s" % [spider.support.surface_id, "+y" if n.y > 0.99 else ("+x" if n.x > 0.99 else "?")]
		if faces.is_empty() or faces[faces.size() - 1] != f:
			faces.append(f)
		if f == "floor+y" and spider.global_position.x > 1.5:
			break
	Input.action_release("move_forward")
	check_eq(faces, ["block+y", "block+x", "floor+y"] as Array[String], "top, east face, floor: each once, no back and forth")
	check(carried > 10, "the heading was carried down the east face (%d ticks)" % carried)
	check(not world.controller.is_carrying() or spider.global_position.x > 1.5, "carry ends once the camera mapping agrees again")
	check(spider.global_position.x > 1.5, "out on the floor, x = %f" % spider.global_position.x)


func test_recenter_on_a_wall_turns_the_camera_to_face_it() -> void:
	spawn_world(Transform3D(SupportMath.body_basis(Vector3.FORWARD, Vector3.UP), Vector3(0.0, 2.0, 17.5 - 0.31)), true)
	await physics_frames(10)
	var rig: Node3D = world.camera_rig
	rig.yaw += 1.5
	rig.start_recenter()
	await runner.get_tree().create_timer(0.45).timeout
	check_near(angle_difference(rig.yaw, PI), 0.0, 0.01, "the camera faces the wall the spider is on")
	_level("after recenter")
