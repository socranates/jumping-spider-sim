extends Node3D
## The anchor cue while aiming (spec 9.1: a small anchor cue; lack of a usable attachment must be clear before
## committing). It shows where this jump's safety line would be anchored, on the surface the spider stands on,
## under its body: a white dot with a short stub of line up to the spinnerets when the line can be anchored;
## an amber cross and no stub when it cannot (a surface that will not hold silk, such as the PTFE coating, or a
## jump that needs more line than the maximum). The dot and the cross are drawn over the body so the cue is not
## hidden under it. The HUD says the same in words. A missing line never changes the jump (A-008).

const SupportMath = preload("res://scripts/movement/support_math.gd")

const OK_COLOR := Color(0.96, 0.97, 1.0)
const REFUSED_COLOR := Color(1.0, 0.72, 0.1)
const DOT_RADIUS := 0.05
const CROSS_HALF := 0.16
const CROSS_RADIUS := 0.018
const STUB_RADIUS := 0.012

var controller: Node   # JumpController: the cue shows while it is aiming
var motor: Node3D      # SpiderMotor
## For tests: "" (hidden), "ok" or "refused", and the reason from the motor's anchor preview.
var shown: String = ""
var shown_reason: String = ""

var _dot: MeshInstance3D
var _cross: Node3D
var _stub: MeshInstance3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var sphere := SphereMesh.new()
	sphere.radius = DOT_RADIUS
	sphere.height = DOT_RADIUS * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	_dot = _part(sphere, _material(OK_COLOR, false))
	add_child(_dot)
	_cross = Node3D.new()
	add_child(_cross)
	var bar := CylinderMesh.new()
	bar.top_radius = CROSS_RADIUS
	bar.bottom_radius = CROSS_RADIUS
	bar.height = CROSS_HALF * 2.0
	bar.radial_segments = 6
	bar.rings = 1
	var cross_mat := _material(REFUSED_COLOR, false)
	for angle in [PI * 0.25, -PI * 0.25]:
		var mi := _part(bar, cross_mat)
		mi.transform = Transform3D(Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
		_cross.add_child(mi)
	var rod := CylinderMesh.new()
	rod.top_radius = STUB_RADIUS
	rod.bottom_radius = STUB_RADIUS
	rod.height = 1.0
	rod.radial_segments = 5
	rod.rings = 1
	_stub = _part(rod, _material(OK_COLOR, true))
	add_child(_stub)
	_hide()


func _process(_delta: float) -> void:
	if controller == null or motor == null or not controller.is_aiming():
		_hide()
		return
	show_preview(motor.get_anchor_preview(controller.plan))


## Shows the cue for an anchor preview (SpiderMotor.get_anchor_preview).
func show_preview(preview: Dictionary) -> void:
	var reason := str(preview.get("reason", "no_support"))
	if reason == "no_support":
		_hide()
		return
	var point: Vector3 = preview["point"]
	var normal: Vector3 = preview["normal"]
	var basis := SupportMath.body_basis(normal, motor.get_heading_vector() if motor != null else Vector3.FORWARD)
	global_transform = Transform3D(basis, point + normal * 0.015)
	var ok: bool = preview["ok"]
	shown = "ok" if ok else "refused"
	shown_reason = reason
	_dot.visible = ok
	_cross.visible = not ok
	_stub.visible = false
	if ok and motor != null:
		var a := point + normal * 0.015
		var b: Vector3 = motor.line_end_point()
		var length := a.distance_to(b)
		if length > 1e-3:
			var rb := SupportMath.body_basis((b - a) / length, Vector3.ONE)
			_stub.global_transform = Transform3D(Basis(rb.x, rb.y * length, rb.z), (a + b) * 0.5)
			_stub.visible = true


func _hide() -> void:
	shown = ""
	shown_reason = ""
	if _dot != null:
		_dot.visible = false
		_cross.visible = false
		_stub.visible = false


func _part(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _material(color: Color, depth_test: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.no_depth_test = not depth_test
	m.render_priority = 9
	return m
