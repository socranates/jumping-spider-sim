extends Node3D
## The landing patch (spec 6.3): a small disc-sized ring lying on the aimed surface, aligned to its
## normal. Its kind is told by SHAPE and colour (JumpFeedback): a solid ring is reachable, a ring with a
## cross is obstructed, a dashed ring is out of reach, a dotted ring cannot hold the spider. No
## uncertainty band: in P0 the patch only promises what the solver found. With Settings.detailed_arc the
## predicted arc is drawn too. The patch shows what the controller's get_patch_plan() returns.

const JumpFeedback = preload("res://scripts/presentation/jump_feedback.gd")
const JumpArc = preload("res://scripts/presentation/jump_arc.gd")

const RING_OUTER := 0.45       # WU: a little larger than the body's 0.3 radius
const RING_INNER := 0.34
const BACK_OUTER := 0.49       # the dark backing ring that keeps the colour readable on any surface
const BACK_INNER := 0.30
const FILL_ALPHA := 0.22       # the disc inside the ring, so the patch still reads when the surface is seen at a low angle
const LIFT := 0.02             # WU off the surface, against z-fighting
## Each surface of the patch sits a hair above the one before it, so the dark backing, the faint disc
## and the coloured ring never share a plane (they used to z-fight, leaving only slivers of colour).
const BACK_LIFT := 0.0
const FILL_LIFT := 0.006
const RING_LIFT := 0.012
const SEGMENTS := 64
## Readable at distance (chunk 5): beyond SCALE_REF_DISTANCE from the camera the whole patch grows with the
## distance, so its size on screen stays about what it is at that distance; nearer, it keeps its world size,
## a little larger than the body. Capped at SCALE_MAX. The patch's centre is still the exact landing point.
const SCALE_REF_DISTANCE := 6.0
const SCALE_MAX := 4.0

var controller: Node     # JumpController; null in tests that call show_plan() themselves
var settings: Node       # Settings autoload, or a test instance
## What is shown: the kind name and the pattern, "" when hidden. For tests.
var shown_kind: String = ""
var shown_pattern: String = ""
var shown_plan: RefCounted = null
var shown_scale: float = 1.0

var _ring: MeshInstance3D
var _meshes: Dictionary = {}     # pattern -> ArrayMesh
var _materials: Dictionary = {}  # kind name -> StandardMaterial3D
var _fill_materials: Dictionary = {}  # kind name -> the translucent disc
var _back_material: StandardMaterial3D
var _arc: Node3D


func _ready() -> void:
	top_level = true
	visible = false
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if settings == null and controller != null:
		settings = controller.settings
	_back_material = _make_material(Color(0.02, 0.02, 0.03, 0.9))
	_back_material.render_priority = 6
	for kind: String in JumpFeedback.PATTERNS:
		var m := _make_material(JumpFeedback.color_for(kind))
		m.render_priority = 7
		_materials[kind] = m
		var f := _make_material(Color(m.albedo_color.r, m.albedo_color.g, m.albedo_color.b, FILL_ALPHA))
		f.render_priority = 5
		_fill_materials[kind] = f
	for pattern: String in ["solid", "cross", "dashed", "dotted"]:
		_meshes[pattern] = _build_mesh(pattern)
	_ring = MeshInstance3D.new()
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_arc = JumpArc.new(Color.WHITE, 0.03)
	add_child(_arc)


func _process(_delta: float) -> void:
	if controller != null:
		show_plan(controller.get_patch_plan())


## Shows the plan's target, or hides the patch for null.
func show_plan(p: RefCounted) -> void:
	if p == null or p.kind_name() == "none":
		shown_kind = ""
		shown_pattern = ""
		shown_plan = null
		visible = false
		_arc.clear()
		return
	var kind: String = p.kind_name()
	shown_kind = kind
	shown_pattern = JumpFeedback.pattern_for(kind)
	shown_plan = p
	var mesh: ArrayMesh = _meshes[shown_pattern]
	_ring.mesh = mesh
	_ring.set_surface_override_material(0, _back_material)
	_ring.set_surface_override_material(1, _materials[kind])
	_ring.set_surface_override_material(2, _fill_materials[kind])
	var up: Vector3 = p.target_normal
	var x := up.cross(Vector3.BACK if absf(up.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT).normalized()
	var s := scale_for(p.target_point)
	shown_scale = s
	global_transform = Transform3D(Basis(x * s, up * s, x.cross(up) * s), p.target_point + up * LIFT)
	visible = true
	var detailed: bool = settings != null and settings.detailed_arc
	if detailed and p.path.size() > 1:
		_arc.set_color(JumpFeedback.color_for(kind))
		_arc.set_path(p.path)
	else:
		_arc.clear()


## The patch's scale for a target point: 1 up to SCALE_REF_DISTANCE from the current camera, then in
## proportion to the distance, at most SCALE_MAX. 1 when there is no camera.
func scale_for(point: Vector3) -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or not point.is_finite():
		return 1.0
	return scale_at_distance(cam.global_position.distance_to(point))


static func scale_at_distance(d: float) -> float:
	if not is_finite(d):
		return 1.0
	return clampf(d / SCALE_REF_DISTANCE, 1.0, SCALE_MAX)


## Three surfaces: 0 the dark backing, 1 the coloured pattern, 2 the faint disc inside the ring.
func _build_mesh(pattern: String) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_add_surface(mesh, _pattern_quads(pattern, BACK_OUTER, BACK_INNER, true), BACK_LIFT)
	_add_surface(mesh, _pattern_quads(pattern, RING_OUTER, RING_INNER, false), RING_LIFT)
	var disc: Array = []
	for i in SEGMENTS:
		var a0 := TAU * float(i) / SEGMENTS
		var a1 := TAU * float(i + 1) / SEGMENTS
		disc.append([Vector3.ZERO, _pt(BACK_INNER, a0), _pt(BACK_INNER, a0), _pt(BACK_INNER, a1)])
	_add_surface(mesh, disc, FILL_LIFT)
	return mesh


## Quads [a, b, c, d] in the XZ plane (corner order around the quad) for the pattern.
func _pattern_quads(pattern: String, outer: float, inner: float, backing: bool) -> Array:
	var quads: Array = []
	var period := 1
	var on := 1
	if pattern == "dashed":
		period = 8
		on = 5
	elif pattern == "dotted":
		period = 4
		on = 1
	for i in SEGMENTS:
		if period > 1 and i % period >= on:
			continue
		var a0 := TAU * float(i) / SEGMENTS
		var a1 := TAU * float(i + 1) / SEGMENTS
		quads.append([_pt(inner, a0), _pt(outer, a0), _pt(outer, a1), _pt(inner, a1)])
	if pattern == "cross":
		var half := inner - 0.02
		var w := (outer - inner) * (0.5 if not backing else 0.62)
		for angle in [PI * 0.25, PI * 0.75]:
			var d := Vector3(cos(angle), 0.0, sin(angle))
			var s := Vector3(-d.z, 0.0, d.x) * w
			quads.append([-d * half - s, d * half - s, d * half + s, -d * half + s])
	return quads


func _pt(r: float, a: float) -> Vector3:
	return Vector3(cos(a) * r, 0.0, sin(a) * r)


func _add_surface(mesh: ArrayMesh, quads: Array, lift: float) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for q: Array in quads:
		var base := verts.size()
		for v: Vector3 in q:
			verts.append(v + Vector3(0.0, lift, 0.0))
			normals.append(Vector3.UP)
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _make_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
