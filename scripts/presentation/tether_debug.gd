extends Node3D
## F4 view of the safety line (child of the support view, so F4 shows it with the support and the jump arcs):
## the line's path from the anchor (white marker) over the bend point (magenta marker) to the body centre, cyan
## while slack and red while taut; and the constraint: the circle the body may not leave, centred on the pivot
## (the bend point, or the anchor) with the free length (rest length minus the anchor-to-bend part) as radius,
## drawn dashed in the vertical plane through the pivot and the body. Drawn over the scene.

const JumpArc = preload("res://scripts/presentation/jump_arc.gd")

const SLACK := Color(0.2, 0.9, 1.0)
const TAUT := Color(1.0, 0.25, 0.2)
const LIMIT := Color(1.0, 0.85, 0.2)
const CIRCLE_POINTS := 64

var motor: Node3D   # SpiderMotor
## For tests: what is drawn.
var showing_line: bool = false
var showing_bend: bool = false
var limit_radius: float = 0.0

var _path: Node3D
var _limit: Node3D
var _anchor_marker: MeshInstance3D
var _bend_marker: MeshInstance3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_path = JumpArc.new(SLACK, 0.02, false)
	_limit = JumpArc.new(LIMIT, 0.012, false)
	add_child(_path)
	add_child(_limit)
	_anchor_marker = _marker(Color.WHITE, 0.07)
	_bend_marker = _marker(Color(1.0, 0.2, 0.9), 0.07)
	add_child(_anchor_marker)
	add_child(_bend_marker)


func _process(_delta: float) -> void:
	if is_visible_in_tree() and motor != null:
		refresh()


func refresh() -> void:
	var t: RefCounted = motor.tether
	showing_line = t.is_active()
	showing_bend = showing_line and t.has_bend
	_anchor_marker.visible = showing_line
	_bend_marker.visible = showing_bend
	if not showing_line:
		_path.clear()
		_limit.clear()
		limit_radius = 0.0
		return
	var body: Vector3 = motor.global_position
	_path.set_color(TAUT if t.taut else SLACK)
	_path.set_path(t.points(body))
	_anchor_marker.global_position = t.anchor_point
	if showing_bend:
		_bend_marker.global_position = t.bend_point
	if not t.is_locked():
		_limit.clear()  # paying out: the line limits nothing
		limit_radius = 0.0
		return
	var pivot: Vector3 = t.pivot()
	limit_radius = t.effective_length()
	var out := body - pivot
	out.y = 0.0
	var side := out.normalized() if out.length() > 1e-3 else Vector3.RIGHT
	var circle := PackedVector3Array()
	for i in CIRCLE_POINTS + 1:
		var a := TAU * float(i) / float(CIRCLE_POINTS)
		circle.append(pivot + (side * sin(a) + Vector3.DOWN * cos(a)) * limit_radius)
	_limit.set_path(circle, true)


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
