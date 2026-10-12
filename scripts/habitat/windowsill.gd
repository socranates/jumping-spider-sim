extends Node3D
## T08 authored habitat. Coordinates are WU (cm); static boxes carry persistent IDs.
## A wide floor route passes the planter; an upper route crosses an 8 WU gap.
## Nothing disappears when aimed at; the lab remains a separate scene.
signal surface_availability_changed(surface_id: String, available: bool)

const Layers = preload("res://scripts/core/physics_layers.gd")
const RETREAT_ID := "sill_crevice"
const RETREAT_AREA := AABB(Vector3(-27.8, 0.0, 3.0), Vector3(4.5, 1.5, 6.0))
const SPAWN := Vector3(-22.0, 0.0, 6.0)
## T09: stable content IDs. A checkpoint names perches, vents and surfaces by these, and is checked against them before any world is built.
const CONTENT_REVISION := "windowsill-v1"
const PERCH_POINTS := {
	"sill_first_hunt": Vector3(-13, 0, 6), "rim_hunt": Vector3(10, 4.6, -3),
	"leaf_hunt": Vector3(-1, 4.2, -1), "east_hunt": Vector3(23, 0, 7),
	"west_leaf": Vector3(-15, 4.2, -1), "east_leaf": Vector3(22, 5.4, -2),
	"under_leaf": Vector3(-12.8, 0, -2), "front_path": Vector3(1, 0, 8),
	"east_corner": Vector3(27, 0, -7), "back_path": Vector3(-9, 0, -9),
	"rim_west": Vector3(5, 4.6, -5), "rim_east": Vector3(15, 4.6, -5),
}
const VENT_POINTS := {"frame_crack_west": Vector3(-23, 8, -12.5), "frame_crack_east": Vector3(23, 8, -12.5)}
const SURFACE_IDS: Array[String] = ["sill_floor", "back_frame", "left_frame", "right_frame", "front_lip", "planter", "planter_rim",
	"leaf_west", "leaf_middle", "leaf_east", "stem_west", "stem_middle", "stem_east", "crevice_back", "crevice_roof", "crevice_north", "crevice_south",
	"leaf_tip"]
## T09b: the one authored place to learn the silk on the sill (spec 17: "a safe recovery opportunity"). A pale, dry leaf tip past the east
## leaf looks like a landing but gives way when a jump is aimed at it, like the lab's practice perches: the line from the east leaf catches
## the spider below. It falls away (drawn only), and comes back DROP_RESET_S later once nothing is where it would be.
const DROP_PIECES: Array[String] = ["leaf_tip"]
const DROP_RESET_S := 8.0
const DROP_FALL_S := 0.7
var _drop_timers: Dictionary = {}
var _falling: Dictionary = {}  # piece -> seconds since it gave way (the mesh's fall, drawn only)
var pieces: Dictionary = {}
var sun: DirectionalLight3D
var shadow_band: MeshInstance3D
## LIFE_DESIGN.md round 1: the light of the hour (set_daylight), 0 night to 1 day, and what makes it: the sun, the room's ambient light,
## the sky behind the glass and the window's glow. Night is dim and blue, never black, so the sill can still be found.
var daylight: float = 1.0
var _env: Environment
var _window_glow: MeshInstance3D
var _disturbance: float = -1.0
const SUN_DAY := 0.55
const AMBIENT_DAY := 0.40
const AMBIENT_NIGHT := 0.10
const SKY_DAY := Color("9fb6bc")
const SKY_NIGHT := Color("1d2633")
const GLOW_DAY := Color("a9c2c1")
const GLOW_NIGHT := Color("2c3747")

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
	box("leaf_tip", Vector3(25.6, 5.15, -4.2), Vector3(28.4, 5.35, -1.8), "leaf_dry_prototype", Color("cdb27a"))
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
	_window_glow = visual_box("window_glow", Vector3(55, 10, 0.04), Vector3(0, 8, -12.44), GLOW_DAY)
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
	_env = env
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
	var points := PERCH_POINTS
	for id: String in points:
		out.append({"id": id, "position": to_global(points[id]), "normal": Vector3.UP,
			"shelter": 0.5 if id == "under_leaf" else 0.2, "food": 0.5 if "rim" in id else 0.1,
			"kind": "habitat", "start": out.size() < 4})
	return out

func get_prey_vents() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in VENT_POINTS:
		out.append({"id": id, "position": to_global(VENT_POINTS[id]), "normal": Vector3.BACK})
	return out

# ------------------------------------------------------------------ the leaf tip that gives way (T09b)

## Connected to the spider's jump_committed: a jump aimed at the dry leaf tip makes it give way now.
func on_jump_committed(plan: RefCounted) -> void:
	if plan == null:
		return
	var target: String = plan.target_surface_id
	if DROP_PIECES.has(target) and is_piece_enabled(target):
		drop_piece(target, DROP_RESET_S)


func drop_piece(piece_name: String, returns_in: float) -> void:
	set_piece_enabled(piece_name, false)
	_drop_timers[piece_name] = returns_in
	_falling[piece_name] = 0.0


func is_piece_enabled(piece_name: String) -> bool:
	var body: StaticBody3D = pieces.get(piece_name)
	return body != null and body.collision_layer != 0


func set_piece_enabled(piece_name: String, enabled: bool) -> void:
	var body: StaticBody3D = pieces.get(piece_name)
	if body == null:
		return
	var was := is_piece_enabled(piece_name)
	body.collision_layer = Layers.WORLD if enabled else 0
	var mesh := body.get_node_or_null(piece_name + "_mesh") as Node3D
	if mesh != null:
		mesh.position = Vector3.ZERO
		mesh.rotation = Vector3.ZERO
		mesh.visible = true
	if enabled:
		_falling.erase(piece_name)
	if was != enabled:
		surface_availability_changed.emit(piece_name, enabled)


func _physics_process(delta: float) -> void:
	for piece_name: String in _falling.keys():
		var t: float = float(_falling[piece_name]) + delta
		_falling[piece_name] = t
		var mesh := pieces[piece_name].get_node_or_null(piece_name + "_mesh") as Node3D
		if mesh != null:
			var u := clampf(t / DROP_FALL_S, 0.0, 1.0)
			mesh.position = Vector3(0.4 * u, -5.0 * u * u, 0.0)
			mesh.rotation = Vector3(0.0, 0.0, -1.2 * u)
			mesh.visible = u < 1.0
	for piece_name: String in _drop_timers.keys():
		_drop_timers[piece_name] = float(_drop_timers[piece_name]) - delta
		if float(_drop_timers[piece_name]) <= 0.0:
			if _piece_is_empty(piece_name):
				_drop_timers.erase(piece_name)
				set_piece_enabled(piece_name, true)
			else:
				_drop_timers[piece_name] = 0.5


func _piece_is_empty(piece_name: String) -> bool:
	var body: StaticBody3D = pieces[piece_name]
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = (body.get_node("Shape") as CollisionShape3D).shape
	params.transform = body.global_transform
	params.collision_mask = Layers.SPIDER
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


## The checkpoint's habitat changes: the pieces that are down and when each comes back.
func changes_record() -> Array:
	var out: Array = []
	for piece_name: String in DROP_PIECES:
		if not is_piece_enabled(piece_name):
			out.append({"surface_id": piece_name, "available": false, "returns_in": float(_drop_timers.get(piece_name, DROP_RESET_S))})
	return out


func apply_changes(changes: Array) -> void:
	for c: Dictionary in changes:
		drop_piece(str(c["surface_id"]), float(c["returns_in"]))
		_falling[str(c["surface_id"])] = DROP_FALL_S


func show_disturbance(progress: float) -> void:
	shadow_band.visible = progress >= 0.0 and progress <= 1.0
	_disturbance = progress if shadow_band.visible else -1.0
	if shadow_band.visible:
		shadow_band.position.x = lerpf(-36, 36, progress)
	_apply_light()


## The light of the hour: `light` 0 (night) to 1 (day) from the life clock, and the sun lower in the sky early and late.
func set_daylight(light: float, hour: float) -> void:
	daylight = clampf(light, 0.0, 1.0)
	var height := clampf(sin(PI * (hour - 6.0) / 14.0), 0.0, 1.0)
	sun.rotation_degrees = Vector3(-lerpf(18.0, 55.0, height), 25.0, 0.0)
	_apply_light()


func _apply_light() -> void:
	var shade := 0.18 * sin(_disturbance * PI) if _disturbance >= 0.0 else 0.0
	sun.light_energy = maxf(0.0, (SUN_DAY - shade) * daylight)
	sun.light_color = Color(1.0, 0.82, 0.66).lerp(Color.WHITE, smoothstep(0.0, 0.6, daylight))
	if _env != null:
		_env.ambient_light_energy = lerpf(AMBIENT_NIGHT, AMBIENT_DAY, daylight)
		_env.ambient_light_color = Color("8fa3c4").lerp(Color("dfddce"), daylight)
		_env.background_color = SKY_NIGHT.lerp(SKY_DAY, daylight)
	if _window_glow != null:
		(_window_glow.material_override as StandardMaterial3D).albedo_color = GLOW_NIGHT.lerp(GLOW_DAY, daylight)

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
