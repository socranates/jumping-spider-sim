extends Node3D
## Cosmetic placeholder spider, built from primitive meshes. About 1 WU long with the head
## toward -Z. Static pose: leg tips sit 0.3 WU below the origin, which is the centre of the
## 0.3 WU sphere collider, so the spider appears to stand on the surface it touches.

const BODY_COLOR := Color(0.14, 0.11, 0.10)
const LEG_COLOR := Color(0.19, 0.15, 0.13)
const EYE_COLOR := Color(0.01, 0.01, 0.01)
const SPOT_COLOR := Color(0.92, 0.9, 0.84)
const FANG_COLOR := Color(0.16, 0.58, 0.47)

# Legs, front pair to back pair (left side; the right side mirrors x).
const HIP_Z := [-0.36, -0.24, -0.12, 0.0]
const KNEE_Z := [-0.62, -0.38, -0.06, 0.30]
const TIP_Z := [-0.82, -0.52, 0.12, 0.62]

## Catch recoil (A-018, cosmetic): when the line catches the spider, the model is thrown a little way along the line, away
## from the anchor, and settles back in a damped bounce of about a third of a second. It moves only this node, a child of the
## physics body on the presentation side: the body, its collider, the line's length and the camera are never touched, and
## nothing shakes. It runs in the physics tick so the engine's interpolation smooths it. The silk's end follows the model.
const RECOIL_AMPLITUDE := 0.09     # WU, at most
const RECOIL_FREQUENCY := 4.0      # Hz
const RECOIL_DAMPING := 8.0        # 1/s
const RECOIL_STOP := 0.002         # WU: below this it is over and the node is put back exactly

var recoil_enabled: bool = true
## Where the recoil has put the model, in the physics body's space (zero when it is not recoiling).
var recoil_offset: Vector3 = Vector3.ZERO

var _mats: Dictionary = {}
var _recoil_dir: Vector3 = Vector3.ZERO
var _recoil_amp: float = 0.0
var _recoil_t: float = 0.0
var _recoiling: bool = false


func _ready() -> void:
	_build()
	var motor := get_parent()
	if motor != null and motor.has_signal("line_event"):
		motor.line_event.connect(_on_line_event)


## Throws the model along `direction` (in the physics body's space) and lets it settle. `strength` is 0 to 1 of the
## largest recoil.
func start_recoil(direction: Vector3, strength: float = 1.0) -> void:
	if not recoil_enabled or direction.length() < 1e-4:
		return
	_recoil_dir = direction.normalized()
	_recoil_amp = RECOIL_AMPLITUDE * clampf(strength, 0.0, 1.0)
	_recoil_t = 0.0
	_recoiling = _recoil_amp > RECOIL_STOP


func is_recoiling() -> bool:
	return _recoiling


func _physics_process(delta: float) -> void:
	if not _recoiling:
		return
	_recoil_t += delta
	var envelope := exp(-RECOIL_DAMPING * _recoil_t)
	recoil_offset = _recoil_dir * _recoil_amp * envelope * sin(TAU * RECOIL_FREQUENCY * _recoil_t)
	if _recoil_amp * envelope < RECOIL_STOP:
		_recoiling = false
		recoil_offset = Vector3.ZERO
	position = recoil_offset


func _on_line_event(kind: String, _detail: String) -> void:
	if kind != "caught":
		return
	var motor := get_parent() as Node3D
	if motor == null:
		return
	var away: Vector3 = motor.global_position - motor.tether.pivot()
	start_recoil(motor.global_transform.basis.inverse() * away)


func _build() -> void:
	_ellipsoid(Vector3(0.0, 0.02, -0.22), Vector3(0.22, 0.17, 0.26), "body")  # cephalothorax
	_ellipsoid(Vector3(0.0, 0.04, 0.20), Vector3(0.21, 0.19, 0.30), "body")   # abdomen
	_ellipsoid(Vector3(0.0, 0.225, 0.12), Vector3(0.05, 0.012, 0.05), "spot")
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * 0.07, 0.205, 0.30), Vector3(0.05, 0.012, 0.05), "spot")
		_ellipsoid(Vector3(side * 0.075, 0.09, -0.45), Vector3(0.075, 0.075, 0.075), "eye")   # principal
		_ellipsoid(Vector3(side * 0.17, 0.10, -0.34), Vector3(0.045, 0.045, 0.045), "eye")    # anterior lateral
		_ellipsoid(Vector3(side * 0.12, 0.15, -0.16), Vector3(0.05, 0.05, 0.05), "eye")       # posterior lateral
		_ellipsoid(Vector3(side * 0.06, 0.185, -0.20), Vector3(0.022, 0.022, 0.022), "eye")   # posterior median
		_ellipsoid(Vector3(side * 0.05, -0.05, -0.46), Vector3(0.045, 0.045, 0.045), "fang")
		for i in 4:
			var hip := Vector3(side * 0.16, 0.02, HIP_Z[i])
			var knee := Vector3(side * 0.50, 0.26, KNEE_Z[i])
			var tip := Vector3(side * 0.78, -0.30, TIP_Z[i])
			_segment(hip, knee, 0.035)
			_segment(knee, tip, 0.028)


func _material(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.roughness = 0.6
	match kind:
		"body":
			m.albedo_color = BODY_COLOR
		"leg":
			m.albedo_color = LEG_COLOR
		"eye":
			m.albedo_color = EYE_COLOR
			m.roughness = 0.05
			m.metallic = 0.4
			m.emission_enabled = true
			m.emission = Color(0.05, 0.12, 0.16)
		"spot":
			m.albedo_color = SPOT_COLOR
		"fang":
			m.albedo_color = FANG_COLOR
			m.metallic = 0.3
			m.roughness = 0.3
	_mats[kind] = m
	return m


func _ellipsoid(center: Vector3, radii: Vector3, kind: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(kind)
	mi.position = center
	mi.scale = radii
	add_child(mi)


func _segment(from: Vector3, to: Vector3, radius: float) -> void:
	var dir := to - from
	var length := dir.length()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius * 0.75
	mesh.height = length
	mesh.radial_segments = 6
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material("leg")
	var unit := dir / length
	var axis := Vector3.UP.cross(unit)
	var basis := Basis.IDENTITY
	if axis.length() > 0.0001:
		basis = Basis(axis.normalized(), Vector3.UP.angle_to(unit))
	mi.transform = Transform3D(basis, (from + to) * 0.5)
	add_child(mi)
