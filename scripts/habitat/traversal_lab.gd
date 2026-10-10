extends Node3D
## Graybox traversal lab: the shared fixture for movement (T02) and jump (T03) work.
## 1 WU = 1 cm. Every piece is one StaticBody3D with one BoxShape3D, a flat colour per
## surface kind, and the metadata "surface_profile_id" (a file in data/surfaces) and "surface_id"
## (the piece name, a persistent id for SupportState). Geometry is built in _ready.
## The floor top is y = 0, spanning x -30..30 and z -17.5..17.5. The spawn is at (-22, 0, 12)
## facing +X.
## T02 fixtures: floor, ramp, walls, the block's convex edges, concave corners, the overhang
## (underside reached up the east wall), the M01 arch (a post with a slab that overhangs it: up the
## post, over two convex edges and around onto the slab's broad underside), the gap (gap_right is
## coated and cannot be climbed), a coplanar seam (seam_a and seam_b), a thin shelf (0.2 WU, thinner
## than the body) and a free-standing coated panel that cannot be climbed.
## Chunk 5 (farther jumps, T04 safety line): two 10 WU towers with a 9 WU gap between them (a long jump
## top to top), a coated cliff that cannot be climbed with a wooden cap that overhangs it by 0.4 WU (miss
## off the cap, hang below its lip clear of the coating, reel back up), and two practice perches in yellow
## that drop away when a jump is committed toward them, so a player can miss on purpose and let the line
## catch them. A dropped perch comes back DROP_RESET_SECONDS later, once nothing is inside it.
## Surface availability: set_piece_enabled() takes a piece out of the physics world (and greys it out), puts
## it back, and announces either through surface_availability_changed, the explicit event that invalidates
## anchors on it (spec 21.2). Tests add their own pieces with add_fixture_piece().

const Layers = preload("res://scripts/core/physics_layers.gd")
const TestTarget = preload("res://scripts/habitat/test_target.gd")

## A surface left the world (available false) or came back. The id is the piece's surface_id.
signal surface_availability_changed(surface_id: String, available: bool)

const DROP_RESET_SECONDS := 4.0
const GHOST_ALPHA := 0.15  # a dropped piece is drawn this opaque. Alpha blending in the material: GeometryInstance3D.transparency does nothing in the Compatibility renderer

const FLOOR_X := 30.0
const FLOOR_Z := 17.5
const SPAWN_POSITION := Vector3(-22.0, 0.0, 12.0)

## Chunk 6B, the perception stage (A-010), in the north-west of the room: a ledge to watch from (climb its south face and
## you stand facing north), a screen 3 WU high between the ledge and the path, and a labelled test marker (not a fly) that
## walks the path to and fro behind the screen. From the ledge it is in plain view at both ends of the path and hidden
## for the middle of it. The ledge and the screen are ordinary lab pieces; the path, the posts, the sign and the marker
## are drawn only (no collision), and nothing in the stage moves any other piece.
const WATCH_LEDGE := "watch_ledge"
const STAGE_SCREEN := "stage_screen"
const STAGE_PATH_A := Vector3(-28.8, 1.4, -7.9)
const STAGE_PATH_B := Vector3(-20.2, 1.4, -7.9)

## Chunk 7B, the first living prey: where flies may sit. Each perch is a point on a surface of the lab with the surface's normal, how
## sheltered the place is (0 in the open, 1 in a corner or under a slab) and how much food is there (a sticky blot drawn on the
## surface). `start` marks the places the default population begins on, in this order. PerchGraph checks every one against the
## physics world when the world is ready and refuses any that is blocked, floating or cut off; nothing here is trusted.
const PREY_PERCHES: Array[Dictionary] = [
	{"id": "floor_ahead", "position": Vector3(-13.0, 0.0, 11.5), "normal": Vector3.UP, "shelter": 0.15, "food": 0.0, "kind": "floor", "start": true},
	{"id": "floor_east_open", "position": Vector3(4.0, 0.0, 11.0), "normal": Vector3.UP, "shelter": 0.1, "food": 0.0, "kind": "floor", "start": true},
	{"id": "block_top", "position": Vector3(-3.0, 3.4, 5.0), "normal": Vector3.UP, "shelter": 0.2, "food": 0.8, "kind": "top", "start": true},
	{"id": "ledge_2_top", "position": Vector3(-8.5, 2.0, -12.5), "normal": Vector3.UP, "shelter": 0.35, "food": 0.7, "kind": "top", "start": true},
	{"id": "floor_gap_well", "position": Vector3(13.5, 0.0, -4.0), "normal": Vector3.UP, "shelter": 0.6, "food": 0.0, "kind": "floor", "start": true},
	{"id": "slab_top", "position": Vector3(14.0, 4.6, 7.0), "normal": Vector3.UP, "shelter": 0.25, "food": 0.0, "kind": "top", "start": true},
	{"id": "floor_north_open", "position": Vector3(-2.0, 0.0, -7.0), "normal": Vector3.UP, "shelter": 0.15, "food": 0.6, "kind": "floor"},
	{"id": "floor_nw_pocket", "position": Vector3(-24.0, 0.0, -13.5), "normal": Vector3.UP, "shelter": 0.8, "food": 0.0, "kind": "floor"},
	{"id": "floor_se_corner", "position": Vector3(27.0, 0.0, 14.5), "normal": Vector3.UP, "shelter": 0.5, "food": 0.0, "kind": "floor"},
	{"id": "ledge_4_top", "position": Vector3(3.5, 5.0, -12.5), "normal": Vector3.UP, "shelter": 0.3, "food": 0.0, "kind": "top"},
	{"id": "tower_w_top", "position": Vector3(-16.5, 10.0, -2.5), "normal": Vector3.UP, "shelter": 0.1, "food": 0.0, "kind": "top"},
	{"id": "tower_e_top", "position": Vector3(-4.5, 10.0, -2.5), "normal": Vector3.UP, "shelter": 0.1, "food": 0.0, "kind": "top"},
	{"id": "gap_left_top", "position": Vector3(10.0, 2.0, -4.0), "normal": Vector3.UP, "shelter": 0.3, "food": 0.0, "kind": "top"},
	{"id": "cap_top", "position": Vector3(23.0, 6.4, -7.0), "normal": Vector3.UP, "shelter": 0.2, "food": 0.0, "kind": "top"},
	{"id": "ptfe_top", "position": Vector3(13.5, 4.0, 14.15), "normal": Vector3.UP, "shelter": 0.2, "food": 0.0, "kind": "top"},
	{"id": "arch_under", "position": Vector3(15.0, 4.0, 7.0), "normal": Vector3.DOWN, "shelter": 0.8, "food": 0.0, "kind": "underside"},
	{"id": "overhang_under", "position": Vector3(26.0, 3.0, 5.0), "normal": Vector3.DOWN, "shelter": 0.8, "food": 0.0, "kind": "underside"},
	{"id": "wall_north_high", "position": Vector3(-8.0, 7.0, -17.5), "normal": Vector3.BACK, "shelter": 0.1, "food": 0.0, "kind": "wall"},
	{"id": "wall_east_high", "position": Vector3(30.0, 8.0, 6.0), "normal": Vector3.LEFT, "shelter": 0.1, "food": 0.0, "kind": "wall"},
	{"id": "wall_south_mid", "position": Vector3(0.0, 5.0, 17.5), "normal": Vector3.FORWARD, "shelter": 0.1, "food": 0.0, "kind": "wall"},
	{"id": "wall_west_mid", "position": Vector3(-30.0, 5.0, 4.0), "normal": Vector3.RIGHT, "shelter": 0.1, "food": 0.0, "kind": "wall"},
]
## Where a replacement fly may come in: a dark slit high on a wall. A fly enters only while the slit is out of the camera's view and
## out of the spider's sight (PreyPopulation), and flies out through the room to a perch.
const PREY_VENTS: Array[Dictionary] = [
	{"id": "vent_north", "position": Vector3(-20.0, 9.5, -17.5), "normal": Vector3.BACK},
	{"id": "vent_east", "position": Vector3(30.0, 9.0, -10.0), "normal": Vector3.LEFT},
	{"id": "vent_west", "position": Vector3(-30.0, 9.5, 8.0), "normal": Vector3.RIGHT},
	{"id": "vent_south", "position": Vector3(14.0, 10.0, 17.5), "normal": Vector3.FORWARD},
]

## surface kind -> profile id and flat colour
const KINDS := {
	"floor": {"id": "painted_wood_dry", "color": Color(0.62, 0.50, 0.36)},
	"wall": {"id": "plaster_matte", "color": Color(0.82, 0.80, 0.74)},
	"ledge": {"id": "bare_wood_rough", "color": Color(0.45, 0.31, 0.19)},
	"block": {"id": "brick_rough", "color": Color(0.62, 0.28, 0.22)},
	"ramp": {"id": "varnished_wood_smooth", "color": Color(0.80, 0.56, 0.24)},
	"platform": {"id": "painted_metal_smooth", "color": Color(0.38, 0.45, 0.56)},
	"ceiling": {"id": "painted_ceiling", "color": Color(0.52, 0.68, 0.55)},
	"glass": {"id": "glass_clean", "color": Color(0.55, 0.80, 0.90)},
	"coated": {"id": "ptfe_coated", "color": Color(0.72, 0.62, 0.86)},
	"drop": {"id": "painted_metal_smooth", "color": Color(0.96, 0.84, 0.22)},
}

var _pieces: Dictionary = {}
var _materials: Dictionary = {}
var _spawn: Marker3D
var _drop_timers: Dictionary = {}  # piece name -> seconds until it may come back
## The stage's test marker (null until the lab is built, and for a lab made without it).
var test_target: Node3D
## Tests: false keeps dropped practice perches down.
var drop_resets: bool = true


func _ready() -> void:
	_build_pieces()
	_build_grid()
	_build_light_and_environment()
	_build_stage()
	_build_prey_marks()
	_spawn = Marker3D.new()
	_spawn.name = "SpawnPoint"
	add_child(_spawn)
	_spawn.position = SPAWN_POSITION
	_spawn.rotation_degrees = Vector3(0.0, -90.0, 0.0)


## Spawn point on the floor, facing +X. The spider origin goes a little above it.
func get_spawn_transform() -> Transform3D:
	return _spawn.global_transform


func get_piece(piece_name: String) -> StaticBody3D:
	return _pieces.get(piece_name)


## The region the spider may be in. Outside it (below the floor, beyond the walls) the motor puts it
## back at its last supported position (T03).
func get_play_bounds() -> AABB:
	return AABB(Vector3(-33.0, -5.0, -21.0), Vector3(66.0, 24.0, 42.0))


## Takes a piece out of the physics world (no collision layer, drawn as a ghost) or puts it back, and
## announces the change. Anything anchored to it must let go (spec 21.2).
func set_piece_enabled(piece_name: String, enabled: bool) -> void:
	var body: StaticBody3D = _pieces.get(piece_name)
	if body == null:
		return
	var was := is_piece_enabled(piece_name)
	body.collision_layer = Layers.WORLD if enabled else 0
	body.set_meta("surface_available", enabled)
	var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		mesh.material_override = _material(str(body.get_meta("surface_kind"))) if enabled else _ghost_material(str(body.get_meta("surface_kind")))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if was != enabled:
		surface_availability_changed.emit(str(body.get_meta("surface_id")), enabled)


func is_piece_enabled(piece_name: String) -> bool:
	var body: StaticBody3D = _pieces.get(piece_name)
	return body != null and body.collision_layer != 0


## True for the yellow practice perches that drop away when a jump is aimed at them.
func is_drop_piece(piece_name: String) -> bool:
	var body: StaticBody3D = _pieces.get(piece_name)
	return body != null and str(body.get_meta("surface_kind", "")) == "drop"


## Connected to a spider's jump_committed: a practice perch the jump is aimed at drops away now.
func on_jump_committed(plan: RefCounted) -> void:
	if plan == null:
		return
	var target: String = plan.target_surface_id
	if is_drop_piece(target) and is_piece_enabled(target):
		set_piece_enabled(target, false)
		if drop_resets:
			_drop_timers[target] = DROP_RESET_SECONDS


func _physics_process(delta: float) -> void:
	for piece_name: String in _drop_timers.keys():
		_drop_timers[piece_name] = float(_drop_timers[piece_name]) - delta
		if float(_drop_timers[piece_name]) <= 0.0:
			if _piece_is_empty(piece_name):
				_drop_timers.erase(piece_name)
				set_piece_enabled(piece_name, true)
			else:
				_drop_timers[piece_name] = 0.5  # something is where it would come back: try again shortly


## True when no spider body overlaps the piece's box.
func _piece_is_empty(piece_name: String) -> bool:
	var body: StaticBody3D = _pieces[piece_name]
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = (body.get_node("Shape") as CollisionShape3D).shape
	params.transform = body.global_transform
	params.collision_mask = Layers.SPIDER
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


## Adds a box piece for a test fixture, with the same metadata as the lab's own pieces. Like any new body
## it is visible to physics queries after the next physics tick.
func add_fixture_piece(piece_name: String, kind: String, lo: Vector3, hi: Vector3) -> StaticBody3D:
	return _block(piece_name, kind, lo, hi)


## Centre of a piece's world-axis-aligned top face (the pieces used for standing are not rotated).
func get_piece_top(piece_name: String) -> Vector3:
	var body: StaticBody3D = _pieces[piece_name]
	var box := (body.get_node("Shape") as CollisionShape3D).shape as BoxShape3D
	return body.global_position + Vector3.UP * (box.size.y * 0.5)


func get_piece_names() -> Array:
	return _pieces.keys()


## World-space bounds of a piece (exact for the unrotated boxes).
func get_piece_aabb(piece_name: String) -> AABB:
	var body: StaticBody3D = _pieces[piece_name]
	var box := (body.get_node("Shape") as CollisionShape3D).shape as BoxShape3D
	return body.global_transform * AABB(-box.size * 0.5, box.size)


func _build_pieces() -> void:
	# Floor and perimeter.
	_block("floor", "floor", Vector3(-FLOOR_X, -1.0, -FLOOR_Z), Vector3(FLOOR_X, 0.0, FLOOR_Z))
	_block("wall_north", "wall", Vector3(-31.0, 0.0, -18.5), Vector3(31.0, 12.0, -FLOOR_Z))
	_block("wall_south", "wall", Vector3(-31.0, 0.0, FLOOR_Z), Vector3(31.0, 12.0, 18.5))
	_block("wall_west", "wall", Vector3(-31.0, 0.0, -FLOOR_Z), Vector3(-FLOOR_X, 12.0, FLOOR_Z))
	_block("wall_east", "wall", Vector3(FLOOR_X, 0.0, -FLOOR_Z), Vector3(31.0, 12.0, FLOOR_Z))
	# Ledges at several heights, 3 WU apart: stepping stones and gap jumps.
	_block("ledge_1", "ledge", Vector3(-16.0, 0.0, -14.0), Vector3(-13.0, 1.0, -11.0))
	_block("ledge_2", "ledge", Vector3(-10.0, 0.0, -14.0), Vector3(-7.0, 2.0, -11.0))
	_block("ledge_3", "ledge", Vector3(-4.0, 0.0, -14.0), Vector3(-1.0, 3.5, -11.0))
	_block("ledge_4", "ledge", Vector3(2.0, 0.0, -14.0), Vector3(5.0, 5.0, -11.0))
	# Block with convex edges, reached by a ramp (rise 3.4 over 7.2 WU, about 25 degrees).
	_block("block", "block", Vector3(-6.0, 0.0, 2.0), Vector3(0.0, 3.4, 8.0))
	_ramp("ramp", "ramp", -13.2, -6.0, 3.4, 3.0, 7.0, 0.5)
	# A gap: two platforms 3 WU apart.
	_block("gap_left", "platform", Vector3(8.0, 0.0, -6.0), Vector3(12.0, 2.0, -2.0))
	_block("gap_right", "coated", Vector3(15.0, 0.0, -6.0), Vector3(19.0, 2.0, -2.0))
	# Broad overhang with an underside 3 WU above the floor, joined to the east wall.
	_block("overhang", "ceiling", Vector3(21.0, 3.0, 0.0), Vector3(FLOOR_X, 3.6, 10.0))
	# Concave corner: two free-standing walls meeting at a right angle.
	_block("corner_a", "wall", Vector3(-28.0, 0.0, -9.6), Vector3(-20.0, 5.0, -9.0))
	_block("corner_b", "wall", Vector3(-20.6, 0.0, -15.0), Vector3(-20.0, 5.0, -9.0))
	# A glass pane. Jumping spiders climb clean glass, so it is attachable.
	_block("glass_pane", "glass", Vector3(-12.0, 0.0, 15.5), Vector3(-6.0, 4.0, 15.8))
	# M01 arch: a 4 WU post carrying a 0.6 WU slab that overhangs it by 8 WU to the east. The post's
	# west face and the slab's west end are flush. Route: up the post, over the top, round the far
	# end onto the 8 by 6 WU underside, down the post's east face, back to the floor.
	_block("arch_post", "wall", Vector3(9.0, 0.0, 4.0), Vector3(11.0, 4.0, 10.0))
	_block("arch_slab", "ceiling", Vector3(9.0, 4.0, 4.0), Vector3(19.0, 4.6, 10.0))
	# Coplanar seam: two 1 WU platforms touching at x = 25, tops level.
	_block("seam_a", "platform", Vector3(21.0, 0.0, -15.0), Vector3(25.0, 1.0, -11.0))
	_block("seam_b", "ledge", Vector3(25.0, 0.0, -15.0), Vector3(29.0, 1.0, -11.0))
	# Thin shelf, 0.2 WU thick (the body is 0.6 WU across), on the west wall.
	_block("thin_shelf", "ledge", Vector3(-30.0, 1.5, -15.0), Vector3(-26.0, 1.7, -11.0))
	# Free-standing panel with a coating the spider cannot grip (PTFE, as used to stop arthropods
	# climbing). Its top can be stood on; its sides cannot be climbed.
	_block("ptfe_panel", "coated", Vector3(11.0, 0.0, 14.0), Vector3(16.0, 4.0, 14.3))
	# Chunk 5. Long jumps: two 10 WU towers, 9 WU apart edge to edge (10 to 11 WU top to top), climbable.
	# Between their tops floats a practice perch that drops away when a jump is aimed at it.
	_block("tower_w", "wall", Vector3(-18.0, 0.0, -4.0), Vector3(-15.0, 10.0, -1.0))
	_block("tower_e", "wall", Vector3(-6.0, 0.0, -4.0), Vector3(-3.0, 10.0, -1.0))
	_block("drop_bridge", "drop", Vector3(-11.5, 9.6, -3.75), Vector3(-9.5, 10.0, -1.25))
	# A coated cliff the spider cannot climb, with a wooden cap that overhangs it by 0.4 WU on every side.
	# Reach the cap from the east wall (climb it to about 8 WU and leap west). East of the cap, a second
	# practice perch: miss it, hang below the cap's lip clear of the coating, and reel back up.
	_block("cliff", "coated", Vector3(21.0, 0.0, -9.0), Vector3(25.0, 6.0, -5.0))
	_block("cliff_cap", "ledge", Vector3(20.6, 6.0, -9.4), Vector3(25.4, 6.4, -4.6))
	_block("drop_perch", "drop", Vector3(26.6, 5.6, -7.75), Vector3(28.0, 6.0, -6.25))
	# Chunk 6B, the perception stage: a 2 WU ledge to watch from and a 3 WU screen 2.5 WU in front of it.
	_block(WATCH_LEDGE, "ledge", Vector3(-26.5, 0.0, -4.2), Vector3(-22.5, 2.0, -1.2))
	_block(STAGE_SCREEN, "wall", Vector3(-25.6, 0.0, -6.3), Vector3(-23.4, 3.0, -5.8))


## The authored perches for flies (data; PerchGraph validates them against the physics world).
func get_prey_perches() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in PREY_PERCHES:
		out.append(d.duplicate(true))
	return out


func get_prey_vents() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in PREY_VENTS:
		out.append(d.duplicate(true))
	return out


## The food blots and the vent slits: drawn only (no collision), flat on the surface they are on.
func _build_prey_marks() -> void:
	var marks := Node3D.new()
	marks.name = "PreyMarks"
	add_child(marks)
	var blot_material := StandardMaterial3D.new()
	blot_material.albedo_color = Color(0.46, 0.22, 0.08)
	blot_material.roughness = 0.35
	var slit_material := StandardMaterial3D.new()
	slit_material.albedo_color = Color(0.05, 0.05, 0.06)
	slit_material.roughness = 1.0
	for d: Dictionary in PREY_PERCHES:
		if float(d.get("food", 0.0)) <= 0.0:
			continue
		var disc := MeshInstance3D.new()
		disc.name = "Blot_" + str(d["id"])
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.55
		mesh.bottom_radius = 0.55
		mesh.height = 0.02
		mesh.radial_segments = 20
		mesh.rings = 1
		disc.mesh = mesh
		disc.material_override = blot_material
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marks.add_child(disc)
		var n: Vector3 = d["normal"]
		disc.transform = Transform3D(Basis(Quaternion(Vector3.UP, n)), (d["position"] as Vector3) + n * 0.011)
	for d: Dictionary in PREY_VENTS:
		var slit := MeshInstance3D.new()
		slit.name = "Vent_" + str(d["id"])
		var box := BoxMesh.new()
		box.size = Vector3(1.6, 0.02, 0.28)
		slit.mesh = box
		slit.material_override = slit_material
		slit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marks.add_child(slit)
		var vn: Vector3 = d["normal"]
		slit.transform = Transform3D(Basis(Quaternion(Vector3.UP, vn)), (d["position"] as Vector3) + vn * 0.011)


## Where the spider stands to watch the stage: the middle of the ledge's top, facing north.
func get_stage_view_spot() -> Vector3:
	return get_piece_top(WATCH_LEDGE)


## The stage's test marker, or null.
func get_test_target() -> Node3D:
	return test_target


## The marker, its path, the end posts and the sign. All of it is drawn only: no collision.
func _build_stage() -> void:
	var stage := Node3D.new()
	stage.name = "Stage"
	add_child(stage)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.20, 0.20, 0.24)
	dark.roughness = 1.0
	var line := MeshInstance3D.new()
	line.name = "PathLine"
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(STAGE_PATH_B.x - STAGE_PATH_A.x, 0.01, 0.12)
	line.mesh = line_mesh
	line.material_override = dark
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(line)
	line.position = Vector3((STAGE_PATH_A.x + STAGE_PATH_B.x) * 0.5, 0.012, STAGE_PATH_A.z)
	# An end post stands just beyond each end of the path, so the marker never has a post through it.
	for end_point: Vector3 in [STAGE_PATH_A + Vector3(-0.9, 0.0, 0.0), STAGE_PATH_B + Vector3(0.9, 0.0, 0.0)]:
		var post := MeshInstance3D.new()
		post.name = "EndPost"
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.1
		post_mesh.bottom_radius = 0.1
		post_mesh.height = STAGE_PATH_A.y + 0.6
		post.mesh = post_mesh
		post.material_override = dark
		stage.add_child(post)
		post.position = Vector3(end_point.x, (STAGE_PATH_A.y + 0.6) * 0.5, end_point.z)
	# The sign hangs on the face of the north wall behind the path, above the screen, facing the ledge: it is in the way of
	# nobody (the camera behind the spider looks over the screen at it) and it labels the marker whenever the stage is in view.
	var sign_label := Label3D.new()
	sign_label.name = "Sign"
	sign_label.text = TestTarget.SIGN_TEXT
	sign_label.font_size = 48
	sign_label.pixel_size = 0.0052
	sign_label.outline_size = 12
	sign_label.modulate = Color(1.0, 1.0, 1.0)
	sign_label.outline_modulate = Color(0.08, 0.08, 0.1)
	sign_label.shaded = false
	sign_label.double_sided = false
	stage.add_child(sign_label)
	sign_label.position = Vector3(-24.0, 4.1, -8.96)
	test_target = TestTarget.new()
	test_target.name = "TestTarget"
	test_target.path = PackedVector3Array([STAGE_PATH_A, STAGE_PATH_B])
	test_target.stand_height = STAGE_PATH_A.y
	stage.add_child(test_target)
	test_target.position = STAGE_PATH_A


## Axis-aligned box from two corners.
func _block(piece_name: String, kind: String, lo: Vector3, hi: Vector3) -> StaticBody3D:
	return _add_piece(piece_name, kind, hi - lo, Transform3D(Basis.IDENTITY, (lo + hi) * 0.5))


## Ramp whose top surface rises from (x0, y = 0) to (x1, y = rise), spanning z0..z1.
func _ramp(piece_name: String, kind: String, x0: float, x1: float, rise: float, z0: float, z1: float, thickness: float) -> void:
	var run := x1 - x0
	var angle := atan2(rise, run)
	var normal := Vector3(-sin(angle), cos(angle), 0.0)
	var top_mid := Vector3((x0 + x1) * 0.5, rise * 0.5, (z0 + z1) * 0.5)
	var center := top_mid - normal * (thickness * 0.5)
	var basis := Basis(Vector3.BACK, angle)
	_add_piece(piece_name, kind, Vector3(Vector2(run, rise).length(), thickness, z1 - z0), Transform3D(basis, center))


func _add_piece(piece_name: String, kind: String, size: Vector3, xform: Transform3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = piece_name
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.set_meta("surface_profile_id", KINDS[kind]["id"])
	body.set_meta("surface_id", piece_name)
	body.set_meta("surface_kind", kind)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = _material(kind)
	body.add_child(mesh)
	add_child(body)
	body.transform = xform
	_pieces[piece_name] = body
	return body


## The same colour, mostly see-through, for a piece that has left the physics world.
func _ghost_material(kind: String) -> StandardMaterial3D:
	var key := "ghost_" + kind
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		var c: Color = KINDS[kind]["color"]
		m.albedo_color = Color(c.r, c.g, c.b, GHOST_ALPHA)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 1.0
		_materials[key] = m
	return _materials[key]


func _material(kind: String) -> StandardMaterial3D:
	if not _materials.has(kind):
		var m := StandardMaterial3D.new()
		m.albedo_color = KINDS[kind]["color"]
		m.roughness = 1.0
		_materials[kind] = m
	return _materials[kind]


## Thin visual grid lines every 5 WU on the floor so motion and heading are readable.
func _build_grid() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.50, 0.39, 0.27)
	m.roughness = 1.0
	var grid := Node3D.new()
	grid.name = "Grid"
	add_child(grid)
	for gx in range(-25, 30, 5):
		_grid_line(grid, m, Vector3(0.08, 0.01, FLOOR_Z * 2.0), Vector3(gx, 0.005, 0.0))
	for gz in range(-15, 20, 5):
		_grid_line(grid, m, Vector3(FLOOR_X * 2.0, 0.01, 0.08), Vector3(0.0, 0.005, gz))


func _grid_line(parent: Node3D, mat: Material, size: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos


func _build_light_and_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.light_energy = 0.7
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.66, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.80)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
