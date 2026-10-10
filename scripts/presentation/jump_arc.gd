extends Node3D
## A path drawn in the world as short rods between successive points, one MultiMesh draw call. Used for
## the optional detailed arc while aiming and for the predicted and actual paths in the F4 view. Dashed
## paths leave out every other pair of segments. Rods rather than lines, so they read at any resolution.

const SupportMath = preload("res://scripts/movement/support_math.gd")

var _instance: MultiMeshInstance3D
var _multimesh: MultiMesh
var _material: StandardMaterial3D
var _radius: float = 0.02
var _points: PackedVector3Array = PackedVector3Array()
var _dashed: bool = false


func _init(color: Color = Color.WHITE, radius: float = 0.02, depth_test: bool = true) -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_radius = radius
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = color
	_material.no_depth_test = not depth_test
	_material.render_priority = 8
	var rod := CylinderMesh.new()
	rod.top_radius = radius
	rod.bottom_radius = radius
	rod.height = 1.0
	rod.radial_segments = 6
	rod.rings = 1
	rod.material = _material
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = rod
	_multimesh.instance_count = 0
	_instance = MultiMeshInstance3D.new()
	_instance.multimesh = _multimesh
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_instance)


func set_color(color: Color) -> void:
	_material.albedo_color = color


## Draws the path (world points). An empty or one-point path draws nothing.
func set_path(points: PackedVector3Array, dashed: bool = false) -> void:
	if points == _points and dashed == _dashed:
		return
	_points = points
	_dashed = dashed
	var segments: Array[Transform3D] = []
	for i in range(1, points.size()):
		if dashed and (((i - 1) >> 1) & 1) == 1:
			continue
		var a := points[i - 1]
		var b := points[i]
		var length := a.distance_to(b)
		if length < 1e-4:
			continue
		var basis := SupportMath.body_basis((b - a) / length, Vector3.ONE)
		segments.append(Transform3D(Basis(basis.x, basis.y * length, basis.z), (a + b) * 0.5))
	_multimesh.instance_count = segments.size()
	for i in segments.size():
		_multimesh.set_instance_transform(i, segments[i])


func clear() -> void:
	set_path(PackedVector3Array())


## Number of rods currently drawn (tests).
func rod_count() -> int:
	return _multimesh.instance_count
