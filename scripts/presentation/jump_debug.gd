extends Node3D
## F4 view of the jump (child of the support view, so F4 shows both): the predicted arc of the plan in
## front of the spider (the aim while aiming, otherwise the last jump's plan) as a cyan dashed path with a
## cyan marker at the planned landing centre, and the actual path of the last jump as an orange solid
## path with an orange marker where the body first touched down. When the two agree the orange path lies
## on the cyan one. Drawn over the scene, so it shows through walls.

const JumpArc = preload("res://scripts/presentation/jump_arc.gd")

const PREDICTED := Color(0.2, 0.9, 1.0)
const ACTUAL := Color(1.0, 0.55, 0.1)

var motor: Node3D        # SpiderMotor
var controller: Node     # JumpController; optional

var _predicted: Node3D
var _actual: Node3D
var _planned_marker: MeshInstance3D
var _landed_marker: MeshInstance3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_predicted = JumpArc.new(PREDICTED, 0.025, false)
	_actual = JumpArc.new(ACTUAL, 0.02, false)
	add_child(_predicted)
	add_child(_actual)
	_planned_marker = _marker(PREDICTED, 0.09)
	_landed_marker = _marker(ACTUAL, 0.065)
	add_child(_planned_marker)
	add_child(_landed_marker)


func _process(_delta: float) -> void:
	if is_visible_in_tree() and motor != null:
		refresh()


## Rebuilds the drawing from the aim plan or the last jump.
func refresh() -> void:
	var plan: RefCounted = null
	if controller != null and controller.is_aiming():
		plan = controller.plan
	var jump: Dictionary = motor.last_jump
	if plan == null and not jump.is_empty():
		plan = jump.get("plan")
	if plan != null and plan.path.size() > 1:
		_predicted.set_path(plan.path, true)
		_planned_marker.global_position = plan.seat if plan.is_valid() else plan.blocked_at
		_planned_marker.visible = true
	else:
		_predicted.clear()
		_planned_marker.visible = false
	var showing_last: bool = not (controller != null and controller.is_aiming())
	if showing_last and not jump.is_empty() and (jump["path"] as PackedVector3Array).size() > 1:
		_actual.set_path((jump["path"] as PackedVector3Array).duplicate())
		var landed: Vector3 = jump["contact_center"]
		_landed_marker.visible = str(jump["outcome"]) != ""
		_landed_marker.global_position = landed
	else:
		_actual.clear()
		_landed_marker.visible = false


func _marker(color: Color, radius: float) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.no_depth_test = true
	m.render_priority = 9
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi
