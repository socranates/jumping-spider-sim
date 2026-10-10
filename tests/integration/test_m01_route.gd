extends "res://tests/world_test_case.gd"
## Gate M01 (spec 25): a route across floor, wall, convex edge and broad underside, completed 20
## times without lost support, collision penetration or forced camera roll.
##
## Route: the M01 arch in the lab. Start on the floor west of the post, facing it, and hold the
## stick forward the whole way: up the post's west face (concave corner, then the coplanar seam
## where the post meets the slab's end), over the top edge (convex), along the slab, over the far
## edge and down the 0.6 WU end face (convex), round its bottom edge onto the 8 by 6 WU underside
## (convex), back along the underside to the post (concave), down the post's east face (concave)
## and out across the floor.
## The 20 runs share one world and run at the same time, each with its own spider, camera rig and
## player controller, from a start offset drawn from the fixture seed. Spiders collide with neither
## each other nor the camera booms (they are on the spider layer), so runs cannot affect each other.
## Each controller holds forward through stick_override and maps it through its own camera, so the
## run exercises input mapping, the heading carry, the motor and the camera together.
## Checked every tick of every run: supported (ATTACHED, support confirmed this tick), no
## penetration (sphere overlap 0.005 WU smaller than the collider), no camera roll (camera right
## vector horizontal, up vector above the horizon). A run passes when it also completes the route
## in order. Writes tests/reports/m01_report.txt with one line per run.

const SpiderScene = preload("res://scenes/actors/spider.tscn")
const CameraRig = preload("res://scripts/movement/camera_rig.gd")
const PlayerController = preload("res://scripts/movement/player_controller.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")

const RUNS := 20
const MAX_TICKS := 1500  # 25 s; the route takes about 17 s
const Evidence := preload("res://tests/evidence.gd")
const REPORT_PATH := "res://tests/reports/m01_report.txt"
const ROUTE: Array[String] = ["floor+y", "arch_post-x", "arch_slab-x", "arch_slab+y", "arch_slab+x", "arch_slab-y", "arch_post+x", "floor+y"]
const PENETRATION_TOLERANCE := 0.005
const FORWARD := Vector2(0.0, -1.0)  # Input.get_vector convention: y back

var _probe := SphereShape3D.new()


func _face(spider: Node3D) -> String:
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
	return "%s%s" % [spider.support.surface_id, axis]


func _penetrates(spider: Node3D) -> bool:
	_probe.radius = 0.3 - PENETRATION_TOLERANCE
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _probe
	params.transform = Transform3D(Basis.IDENTITY, spider.global_position)
	params.collision_mask = Layers.WORLD
	return not world.get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func _camera_clear(rig: Node3D) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.1
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, rig.camera.global_position)
	params.collision_mask = Layers.WORLD
	return world.get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func test_m01_route_twenty_runs() -> void:
	var starts: Array[Transform3D] = []
	for i in RUNS:
		var x := 5.5 + rng.randf_range(-0.3, 0.3)
		var z := 7.0 + rng.randf_range(-1.2, 1.2)
		var heading := -90.0 + rng.randf_range(-2.0, 2.0)  # facing +X, toward the post
		starts.append(Transform3D(Basis(Vector3.UP, deg_to_rad(heading)), Vector3(x, 0.31, z)))
	spawn_world(starts[0])
	var runs: Array[Dictionary] = []
	for i in RUNS:
		var spider: Node3D = world.spider
		var rig: Node3D = world.camera_rig
		if i > 0:
			spider = SpiderScene.instantiate()
			spider.profile = world.spider.profile
			spider.surfaces = world.surfaces
			spider.transform = starts[i]
			world.add_child(spider)
			rig = CameraRig.new()
			rig.target = spider
			rig.settings = settings
			world.add_child(rig)
		var controller := PlayerController.new()
		controller.motor = spider
		controller.camera_rig = rig
		controller.settings = settings
		controller.stick_override = Vector2.ZERO
		world.add_child(controller)
		runs.append({"spider": spider, "rig": rig, "controller": controller, "faces": [] as Array[String], "done_tick": -1, "lost": 0, "penetrating": 0, "rolled": 0, "camera_clip": 0, "first_problem": "", "arcs": 0, "ticks": 0})
	await physics_frames(10)
	for r in runs:
		(r["controller"] as Node).stick_override = FORWARD
	var active := RUNS
	var tick := 0
	while active > 0 and tick < MAX_TICKS:
		await physics_frames(1)
		tick += 1
		for i in RUNS:
			var r: Dictionary = runs[i]
			if r["done_tick"] >= 0:
				continue
			var spider: Node3D = r["spider"]
			var rig: Node3D = r["rig"]
			r["ticks"] = tick
			var supported: bool = spider.get_state_name() == "ATTACHED" and spider.support.is_valid() and spider.support.valid_tick == spider.get_physics_tick()
			if not supported:
				r["lost"] += 1
				if r["first_problem"] == "":
					r["first_problem"] = "support lost at tick %d, %s at %s" % [tick, spider.get_state_name(), str(spider.global_position)]
			if _penetrates(spider):
				r["penetrating"] += 1
				if r["first_problem"] == "":
					r["first_problem"] = "penetration at tick %d at %s" % [tick, str(spider.global_position)]
			var b: Basis = rig.camera.global_transform.basis
			if absf(b.x.y) > 1e-4 or b.y.y <= 0.0:
				r["rolled"] += 1
				if r["first_problem"] == "":
					r["first_problem"] = "camera roll at tick %d" % tick
			if not _camera_clear(rig):
				r["camera_clip"] += 1
			if spider.in_transition():
				continue
			var faces: Array[String] = r["faces"]
			var f := _face(spider)
			if faces.is_empty() or faces[faces.size() - 1] != f:
				faces.append(f)
				if f.ends_with("-y") or f.begins_with("arch"):
					pass
			if faces == ROUTE and spider.global_position.x > 12.0:
				r["done_tick"] = tick
				(r["controller"] as Node).stick_override = Vector2.ZERO
				active -= 1
	var lines := PackedStringArray()
	lines.append("M01 route report (spec 25): floor, post west face, slab top, slab end, slab underside, post east face, floor")
	lines.append("timestamp_utc: %sZ" % Time.get_datetime_string_from_system(true))
	lines.append(Evidence.describe(Evidence.identity("res://")))
	lines.append("engine: %s" % Engine.get_version_info()["string"])
	lines.append("fixture_seed: %d" % fixture_seed)
	var passed := 0
	for i in RUNS:
		var r: Dictionary = runs[i]
		var s: Transform3D = starts[i]
		var ok: bool = r["done_tick"] >= 0 and r["lost"] == 0 and r["penetrating"] == 0 and r["rolled"] == 0
		if ok:
			passed += 1
		var line := "run %02d %s start (%.2f, %.2f) heading %.1f deg: %s, lost-support ticks %d, penetrating ticks %d, camera roll ticks %d, camera within 0.1 WU of geometry %d ticks%s" % [
			i + 1, "PASS" if ok else "FAIL", s.origin.x, s.origin.z, rad_to_deg(s.basis.get_euler().y),
			("route complete in %.2f s" % (float(r["done_tick"]) / 60.0)) if r["done_tick"] >= 0 else ("route not complete after %.1f s, faces %s" % [float(r["ticks"]) / 60.0, str(r["faces"])]),
			r["lost"], r["penetrating"], r["rolled"], r["camera_clip"],
			"" if r["first_problem"] == "" else ", first problem: " + str(r["first_problem"])]
		lines.append(line)
		print("M01 " + line)
		check(r["done_tick"] >= 0, "run %d completes the route (faces %s)" % [i + 1, str(r["faces"])])
		check_eq(r["lost"], 0, "run %d: never loses support (%s)" % [i + 1, r["first_problem"]])
		check_eq(r["penetrating"], 0, "run %d: never penetrates (%s)" % [i + 1, r["first_problem"]])
		check_eq(r["rolled"], 0, "run %d: the camera never rolls" % (i + 1))
	lines.append("result: %d of %d runs passed" % [passed, RUNS])
	print("M01 result: %d of %d runs passed" % [passed, RUNS])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/reports"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	check_eq(passed, RUNS, "M01: all runs pass")
