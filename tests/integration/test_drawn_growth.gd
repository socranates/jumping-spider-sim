extends "res://tests/prey_test_case.gd"
const Body = preload("res://scripts/presentation/spider_body.gd")

func _sill() -> void:
	use_windowsill = true
	await spawn_prey_world(floor_pose(-25, 6, -90), 0, PREY_SEED, false)
	await physics_frames(10)

func test_stages_grow_visuals_without_changing_motor_or_collider() -> void:
	await _sill()
	var b: Node3D = world.spider.get_node("Body")
	var collider: CollisionShape3D = world.spider.get_node("Collider")
	var original := collider.transform
	var radius: float = collider.shape.radius
	var motor_pose: Transform3D = world.spider.transform
	for stage in 4:
		world.habitat_loop.growth.stage = stage
		world.habitat_loop._apply_growth()
		await physics_frames(12)
		check_near(b.scale.x, Body.STAGE_SCALES[stage], 1e-6, "stage size")
		check_vec_near(world.spider.scale, Vector3.ONE, 1e-6, "motor not scaled")
		check_eq(collider.transform, original, "collider transform unchanged")
		check_eq(collider.shape.radius, radius, "radius unchanged")
		check_vec_near(world.spider.position, motor_pose.origin, 0.001, "growth does not move motor")
		for i in 8:
			if b.legs.is_planted(i):
				check_near(b.legs.world_foot_positions()[i].y, 0.0, 1e-4, "feet on support plane")
		check_near(b.legs.get_child(0).global_basis.x.length(), Body.STAGE_SCALES[stage], 1e-5, "world-space rods grow in thickness")

func test_every_stage_keeps_stance_fixed_and_takes_walking_steps() -> void:
	await _sill()
	var b: Node3D = world.spider.get_node("Body")
	for stage in 4:
		b.set_growth_stage(stage)
		var steps: int = b.legs.steps_started
		world.spider.set_intent(Vector3.RIGHT, true)
		var samples := 0
		for tick in 65:
			var feet: Array = b.legs.world_foot_positions()
			var planted: Array[bool] = []
			for i in 8:
				planted.append(b.legs.is_planted(i))
			await physics_frames(1)
			for i in 8:
				if planted[i] and b.legs.is_planted(i):
					check_vec_near(b.legs.world_foot_positions()[i], feet[i], 1e-5, "planted foot stays still")
					samples += 1
		check(samples > 100, "stance samples at each size")
		check(b.legs.steps_started > steps, "steps at each size")

func test_checkpoint_restores_size_softness_and_condition_together() -> void:
	await _sill()
	world.habitat_loop.growth.stage = 2
	world.habitat_loop.growth.soft_hours_left = 5.0
	world.habitat_loop._apply_growth()
	world.needs.configure({"energy":0.2})
	world.habitat_loop.request_rest()
	await physics_frames(2)
	var rec: Dictionary = world.last_checkpoint.duplicate(true)
	var fresh: Node3D = world.return_to_checkpoint(rec)
	if not check(fresh != null, "checkpoint restores"):
		return
	world = fresh
	await physics_frames(15)
	var b: Node3D = world.spider.get_node("Body")
	check_eq(b.growth_stage, 2, "subadult restored")
	check_near(b.scale.x, Body.STAGE_SCALES[2], 1e-6, "visual scale restored")
	check(b.softness > 0.45 and b.softness < 0.55, "softness preserved alongside size")
	check_near(b.shown_condition, world.needs.energy, 0.01, "reserve preserved alongside size")
	check_vec_near(b.get_node("Abdomen").scale, Body.abdomen_scale(b.shown_condition), 1e-5, "condition remains local, not double-scaled")

func test_adult_reduced_motion_keeps_neutral_feet_at_support_height() -> void:
	await _sill()
	var b: Node3D = world.spider.get_node("Body")
	b.set_growth_stage(3)
	settings.set_value("reduced_motion", true)
	await physics_frames(3)
	check_vec_near(b.position, Vector3(0,0.15,0), 1e-5, "only growth lift remains")
	check_vec_near(b.rotation, Vector3.ZERO, 1e-5, "no twitch rotation")
	for foot in b.legs.foot_positions():
		check_near(b.legs.to_global(foot).y, 0.01, 1e-4, "neutral toes at original support clearance")

func test_adult_contacts_follow_floor_wall_and_underside_geometry() -> void:
	use_windowsill = false
	spawn_world(floor_pose(27.0, 5.0, -90.0))
	await physics_frames(8)
	var b: Node3D = world.spider.get_node("Body")
	b.set_growth_stage(3)
	world.spider.set_intent(Vector3.RIGHT, false)
	var faces: Dictionary = {}
	for tick in 240:
		await physics_frames(1)
		if world.spider.in_transition():
			continue
		for i in 8:
			if b.legs.is_planted(i):
				var foot: Vector3 = b.legs.world_foot_positions()[i]
				var up: Vector3 = b.legs.contacts[i].up
				check(not ray_target(foot + up*0.03, foot - up*0.03).is_empty(), "adult foot on geometry")
				faces[world.spider.support.surface_id] = true
	for face in ["floor", "wall_east", "overhang"]:
		check(faces.has(face), "adult contacts on "+face)

func test_adult_turning_steps_and_eye_mask_remain_stable() -> void:
	await _sill()
	var b: Node3D = world.spider.get_node("Body")
	b.set_growth_stage(3)
	b.set_eye_view(true)
	await physics_frames(20)
	var steps: int = b.legs.steps_started
	var at: Vector3 = world.spider.global_position
	world.spider.begin_prepare()
	world.spider.set_aim_target(at + Vector3.LEFT*5)
	await physics_frames(40)
	check(b.legs.steps_started > steps, "adult steps on turning")
	check_vec_near(world.spider.global_position, at, 1e-5, "no motor translation")
	for i in 16:
		check_eq(b.legs.get_child(i).visible, i==1 or i==9, "stable eye mask at adult size")
