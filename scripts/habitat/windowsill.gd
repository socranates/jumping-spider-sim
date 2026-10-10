extends Node3D
## T08 authored habitat. Coordinates are WU (cm); static boxes carry persistent IDs.
## A wide floor route passes the planter; an upper route crosses an 8 WU gap.
## Nothing disappears when aimed at; the lab remains a separate scene.
signal surface_availability_changed(surface_id: String, available: bool)

const Layers = preload("res://scripts/core/physics_layers.gd")
const RETREAT_ID := "sill_crevice"
const RETREAT_AREA := AABB(Vector3(-27.8, 0.0, 3.0), Vector3(4.5, 1.5, 6.0))
const SPAWN := Vector3(-22.0, 0.0, 6.0)
var pieces: Dictionary = {}
var sun: DirectionalLight3D
var shadow_band: MeshInstance3D

func _ready() -> void:
	box("sill_floor", Vector3(-30, -1, -12.5), Vector3(30, 0, 12.5), "painted_wood_dry", Color("b6a082"))
	box("back_frame", Vector3(-31, 0, -13.5), Vector3(31, 14, -12.5), "bare_wood_rough", Color("ded7c3"))
	box("left_frame", Vector3(-31, 0, -12.5), Vector3(-30, 14, 12.5), "bare_wood_rough", Color("ded7c3"))
	box("right_frame", Vector3(30, 0, -12.5), Vector3(31, 14, 12.5), "bare_wood_rough", Color("ded7c3"))
	box("front_lip", Vector3(-30, 0, 12.0), Vector3(30, 0.7, 12.5), "bare_wood_rough", Color("8b7256"))
	# Broad planter and leaves use forgiving rectangular collision silhouettes.
	box("planter", Vector3(3, 0, -8), Vector3(17, 4, 0), "brick_rough", Color("9f6650"))
	box("planter_rim", Vector3(2.5, 4, -8.5), Vector3(17.5, 4.6, 0.5), "brick_rough", Color("ba8264"))
	visual_box("soil", Vector3(12, 0.01, 6), Vector3(10, 4.61, -4), Color("665644"))
	box("leaf_west", Vector3(-18, 3.8, -4), Vector3(-12, 4.2, 1), "leaf_dry_prototype", Color("607952"))
	box("leaf_middle", Vector3(-4, 3.8, -4), Vector3(2, 4.2, 1), "leaf_dry_prototype", Color("738a59"))
	box("leaf_east", Vector3(18, 5.0, -6), Vector3(25, 5.4, 0), "leaf_dry_prototype", Color("829960"))
	box("stem_west", Vector3(-16.5, 0, -2), Vector3(-15.5, 3.8, -1), "leaf_dry_prototype", Color("536b43"))
	box("stem_middle", Vector3(-2.5, 0, -2), Vector3(-1.5, 3.8, -1), "leaf_dry_prototype", Color("536b43"))
	box("stem_east", Vector3(21, 0, -3.5), Vector3(22, 5, -2.5), "leaf_dry_prototype", Color("536b43"))
	# Physical crevice, open on the east; camera can retract without clipping.
	box("crevice_back", Vector3(-29, 0, 2), Vector3(-28, 3, 10), "bare_wood_rough", Color("655640"))
	box("crevice_roof", Vector3(-29, 2.6, 2), Vector3(-23, 3, 10), "bare_wood_rough", Color("8b775a"))
	box("crevice_north", Vector3(-29, 0, 2), Vector3(-23, 2.6, 2.6), "bare_wood_rough", Color("786448"))
	box("crevice_south", Vector3(-29, 0, 9.4), Vector3(-23, 2.6, 10), "bare_wood_rough", Color("786448"))
	# Silk and wood grain are drawn only: no snagging on decorative details.
	for i in 7:
		visual_box("silk_%d" % i, Vector3(4.6, 0.012, 0.045), Vector3(-25.5, 0.025, 3.3 + i * 0.85), Color("ddd9bf"))
	for z in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		visual_box("grain", Vector3(59, 0.008, 0.035), Vector3(0, 0.008, z), Color("a48d70"))
	# A pale window above the rear wood trim establishes scale without glare.
	visual_box("window_glow", Vector3(55, 10, 0.04), Vector3(0, 8, -12.44), Color("a9c2c1"))
	for x in [-10.0, 10.0]:
		visual_box("mullion", Vector3(0.7, 12, 0.1), Vector3(x, 8, -12.35), Color("e2dbc7"))
	for d in get_prey_vents():
		visual_box(str(d["id"]), Vector3(1.6, 0.24, 0.06), d["position"] + Vector3(0, 0, 0.05), Color("403e33"))
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 0.55
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	sun.rotation_degrees = Vector3(-55, 25, 0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fb6bc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfddce")
	env.ambient_light_energy = 0.40
	var background := WorldEnvironment.new()
	background.environment = env
	add_child(background)
	shadow_band = visual_box("passing_shadow", Vector3(10, 0.012, 24), Vector3(-40, 0.025, 0), Color(0.13, 0.17, 0.2, 0.22))
	shadow_band.visible = false

func get_spawn_transform() -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(-90)), SPAWN)

func get_play_bounds() -> AABB:
	return AABB(Vector3(-33, -5, -16), Vector3(66, 40, 32))

func get_piece_names() -> Array:
	return pieces.keys()

func get_piece(id: String) -> StaticBody3D:
	return pieces.get(id)

func in_retreat(world_position: Vector3) -> bool:
	return RETREAT_AREA.has_point(to_local(world_position))

func get_prey_perches() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var points := {
		"sill_first_hunt": Vector3(-13, 0, 6), "rim_hunt": Vector3(10, 4.6, -3),
		"leaf_hunt": Vector3(-1, 4.2, -1), "east_hunt": Vector3(23, 0, 7),
		"west_leaf": Vector3(-15, 4.2, -1), "east_leaf": Vector3(22, 5.4, -2),
		"under_leaf": Vector3(-12.8, 0, -2), "front_path": Vector3(1, 0, 8),
		"east_corner": Vector3(27, 0, -7), "back_path": Vector3(-9, 0, -9),
		"rim_west": Vector3(5, 4.6, -5), "rim_east": Vector3(15, 4.6, -5),
	}
	for id: String in points:
		out.append({"id": id, "position": to_global(points[id]), "normal": Vector3.UP,
			"shelter": 0.5 if id == "under_leaf" else 0.2, "food": 0.5 if "rim" in id else 0.1,
			"kind": "habitat", "start": out.size() < 4})
	return out

func get_prey_vents() -> Array[Dictionary]:
	return [
		{"id": "frame_crack_west", "position": to_global(Vector3(-23, 8, -12.5)), "normal": Vector3.BACK},
		{"id": "frame_crack_east", "position": to_global(Vector3(23, 8, -12.5)), "normal": Vector3.BACK},
	]

func show_disturbance(progress: float) -> void:
	shadow_band.visible = progress >= 0.0 and progress <= 1.0
	if shadow_band.visible:
		shadow_band.position.x = lerpf(-36, 36, progress)
		sun.light_energy = 0.55 - 0.18 * sin(progress * PI)
	else:
		sun.light_energy = 0.55

func box(id: String, lo: Vector3, hi: Vector3, profile: String, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = id
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.set_meta("surface_profile_id", profile)
	body.set_meta("surface_id", id)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var bounds := BoxShape3D.new()
	bounds.size = hi - lo
	shape.shape = bounds
	body.add_child(shape)
	add_child(body)
	body.position = (lo + hi) * 0.5
	var mesh := visual_box(id + "_mesh", hi - lo, Vector3.ZERO, color)
	mesh.reparent(body, false)
	pieces[id] = body

func visual_box(id: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = material
	add_child(mesh)
	mesh.position = at
	return mesh
