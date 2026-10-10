extends "res://tests/world_test_case.gd"


func test_lab_pieces_are_boxes_with_surface_metadata() -> void:
	spawn_world()
	var lab: Node3D = world.lab
	var names: Array = lab.get_piece_names()
	check(names.size() >= 15, "the lab has its pieces (%d)" % names.size())
	for piece_name: String in names:
		var body: StaticBody3D = lab.get_piece(piece_name)
		check(body.has_meta("surface_profile_id") and str(body.get_meta("surface_profile_id")) != "", "surface_profile_id on " + piece_name)
		var shapes := body.get_children().filter(func(c: Node) -> bool: return c is CollisionShape3D)
		check_eq(shapes.size(), 1, "one collision shape on " + piece_name)
		check(shapes.size() == 1 and (shapes[0] as CollisionShape3D).shape is BoxShape3D, "box shape on " + piece_name)


func test_each_surface_kind_has_its_own_flat_colour() -> void:
	spawn_world()
	var seen: Dictionary = {}
	var lab: Node3D = world.lab
	for piece_name: String in lab.get_piece_names():
		var body: StaticBody3D = lab.get_piece(piece_name)
		var mesh := body.get_node("Mesh") as MeshInstance3D
		var color: Color = (mesh.material_override as StandardMaterial3D).albedo_color
		var kind := str(body.get_meta("surface_kind"))
		if seen.has(kind):
			check_eq(seen[kind], color, "same colour within kind " + kind)
		seen[kind] = color
	var colors: Array = seen.values()
	for i in colors.size():
		for j in range(i + 1, colors.size()):
			check(colors[i] != colors[j], "surface kinds %d and %d have different colours" % [i, j])


func test_floor_is_at_least_60_by_35() -> void:
	spawn_world()
	var floor_body: StaticBody3D = world.lab.get_piece("floor")
	var size := ((floor_body.get_node("Shape") as CollisionShape3D).shape as BoxShape3D).size
	check(size.x >= 60.0 and size.z >= 35.0, "floor size %s" % str(size))
	check_near(world.lab.get_piece_top("floor").y, 0.0, 1e-6, "floor top is y = 0")


func test_spawn_point_is_clear_of_walls() -> void:
	spawn_world()
	await physics_frames(2)
	var spawn: Vector3 = world.lab.get_spawn_transform().origin + Vector3.UP * 3.5
	check(point_is_clear(spawn, 3.0), "a 3 WU sphere around the spawn touches nothing")


func test_a_dropped_piece_is_drawn_see_through_in_every_renderer() -> void:
	# GeometryInstance3D.transparency does nothing in the Compatibility renderer, so the ghost is an alpha material:
	# the dropped practice perch must not stay solid on screen between the camera and the spider (A-017).
	spawn_world()
	var lab: Node3D = world.lab
	var mesh := lab.get_piece("drop_perch").get_node("Mesh") as MeshInstance3D
	var solid := mesh.material_override as StandardMaterial3D
	check_eq(solid.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "a perch in the world is opaque")
	lab.set_piece_enabled("drop_perch", false)
	var ghost := mesh.material_override as StandardMaterial3D
	check_eq(ghost.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "a dropped perch is alpha blended")
	check(ghost.albedo_color.a < 0.3, "and mostly see-through (alpha %f)" % ghost.albedo_color.a)
	check_near(ghost.albedo_color.r, solid.albedo_color.r, 1e-6, "in the same colour")
	check_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "casting no shadow")
	lab.set_piece_enabled("drop_perch", true)
	check(mesh.material_override == solid, "back in the world it is the solid material again")
	check_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "and casts a shadow")
