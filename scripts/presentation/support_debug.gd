extends Node3D
## Developer view of the motor's support (F4, action debug_support; off by default): the support
## normal as a yellow arrow from the contact point, the contact point as a magenta dot (during an
## edge arc it sits on the edge), and the probe rays of the last physics tick as thin rods, green
## up to a hit and red where they found nothing. Drawn over the scene, so it shows through walls.

const SupportMath = preload("res://scripts/movement/support_math.gd")

const NORMAL_LENGTH := 1.0
const HIT_COLOR := Color(0.2, 1.0, 0.3)
const MISS_COLOR := Color(1.0, 0.25, 0.2)
const RAY_POOL := 16         # most rays the motor casts in one tick, with room to spare
const RAY_RADIUS := 0.012    # WU: drawn as thin rods so they read at any resolution

var motor: Node3D  # SpiderMotor

var _rays: Array[MeshInstance3D] = []
var _hit_mat: StandardMaterial3D
var _miss_mat: StandardMaterial3D
var _arrow: Node3D
var _dot: MeshInstance3D


func _ready() -> void:
	visible = false
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_hit_mat = _material(HIT_COLOR)
	_miss_mat = _material(MISS_COLOR)
	var rod := CylinderMesh.new()
	rod.top_radius = RAY_RADIUS
	rod.bottom_radius = RAY_RADIUS
	rod.height = 1.0
	rod.radial_segments = 6
	rod.rings = 1
	var rays := Node3D.new()
	rays.name = "ProbeRays"
	add_child(rays)
	for i in RAY_POOL:
		var mi := _part(rod, _hit_mat, Vector3.ZERO)
		mi.visible = false
		rays.add_child(mi)
		_rays.append(mi)
	_arrow = Node3D.new()
	_arrow.name = "NormalArrow"
	add_child(_arrow)
	var yellow := _material(Color(1.0, 0.85, 0.1))
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.025
	shaft.bottom_radius = 0.025
	shaft.height = NORMAL_LENGTH
	_arrow.add_child(_part(shaft, yellow, Vector3(0.0, NORMAL_LENGTH * 0.5, 0.0)))
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.08
	tip.height = 0.2
	_arrow.add_child(_part(tip, yellow, Vector3(0.0, NORMAL_LENGTH + 0.1, 0.0)))
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	_dot = _part(sphere, _material(Color(1.0, 0.2, 0.9)), Vector3.ZERO)
	_dot.name = "ContactPoint"
	add_child(_dot)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_support"):
		visible = not visible
		# T09c: draw at once, not on the next frame (Chet's native Windows run caught the view shown but not yet drawn; spec 19 developer
		# views should never show a stale picture).
		if visible and motor != null:
			refresh()


func _process(_delta: float) -> void:
	if visible and motor != null:
		refresh()


## Rebuilds the drawing from the motor's current support and probe rays.
func refresh() -> void:
	var rays: Array = motor.debug_rays
	for i in RAY_POOL:
		var mi := _rays[i]
		mi.visible = false
		if i >= rays.size():
			continue
		var r: Dictionary = rays[i]
		var from: Vector3 = r["from"]
		var end: Vector3 = r["to"]
		mi.material_override = _miss_mat
		if r["hit"] is Vector3:
			end = r["hit"]
			mi.material_override = _hit_mat
		var length := from.distance_to(end)
		if length < 1e-4:
			continue
		var b := SupportMath.body_basis((end - from) / length, Vector3.ONE)
		mi.global_transform = Transform3D(Basis(b.x, b.y * length, b.z), (from + end) * 0.5)
		mi.visible = true
	var supported: bool = motor.is_supported()
	_arrow.visible = supported
	_dot.visible = supported
	if supported:
		var n: Vector3 = motor.support.normal
		var p: Vector3 = motor.support.contact_point
		_arrow.global_transform = Transform3D(SupportMath.body_basis(n, motor.get_heading_vector()), p)
		_dot.global_position = p


func _part(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	return mi


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.no_depth_test = true
	m.render_priority = 10
	return m
