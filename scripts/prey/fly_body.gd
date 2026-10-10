extends Node3D
## FlyBody: the drawn fly (spec 15, cosmetic only). Nothing here is read by the simulation: the fly's state decides the pose, never the
## other way round, and the little randomness it uses (the flutter's phase) comes from the fly's own cosmetic stream so that how a
## fly looks can never change what it does. Drawn from primitives, about 0.7 WU long, dark with red eyes and pale wings, so it reads
## against every surface in the lab. In the fly's own frame: -Z is where it faces, +Y its up.
##   * perched: wings folded over the back, six short legs on the surface;
##   * alert: raised on its legs, head up, wings lifted, still;
##   * grooming: the front legs rub together;
##   * flying: the wings beat, the legs tuck in;
##   * held: limp, wings closed (the spider carries it).

const BODY_COLOR := Color(0.13, 0.11, 0.10)
const HEAD_COLOR := Color(0.18, 0.15, 0.13)
const EYE_COLOR := Color(0.85, 0.14, 0.08)
const WING_COLOR := Color(0.88, 0.93, 1.0, 0.5)
const LEG_COLOR := Color(0.09, 0.08, 0.08)

enum Mode { PERCHED, ALERT, GROOMING, FLYING, HELD }

var _wing_pivots: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _front_legs: Array[Node3D] = []
var _head: Node3D
var _torso: Node3D
var _phase: float = 0.0
var _mode: int = Mode.PERCHED


func _init(phase: float = 0.0) -> void:
	_phase = phase
	_build()


func _build() -> void:
	_torso = Node3D.new()
	_torso.name = "Torso"
	add_child(_torso)
	var body := _material(BODY_COLOR, 0.55)
	_torso.add_child(_ellipsoid("Abdomen", Vector3(0.16, 0.13, 0.26), Vector3(0.0, 0.0, 0.17), body))
	_torso.add_child(_ellipsoid("Thorax", Vector3(0.17, 0.14, 0.20), Vector3(0.0, 0.01, -0.07), body))
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, 0.0, -0.29)
	_torso.add_child(_head)
	_head.add_child(_ellipsoid("HeadShape", Vector3(0.10, 0.09, 0.09), Vector3.ZERO, _material(HEAD_COLOR, 0.6)))
	for sx in [-1.0, 1.0]:
		_head.add_child(_ellipsoid("Eye", Vector3(0.055, 0.055, 0.055), Vector3(0.07 * sx, 0.02, -0.04), _material(EYE_COLOR, 0.3)))
	var wing_material := _material(WING_COLOR, 0.2)
	wing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for sx in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "WingPivot"
		pivot.position = Vector3(0.09 * sx, 0.10, -0.05)
		_torso.add_child(pivot)
		var wing := MeshInstance3D.new()
		var quad := BoxMesh.new()
		quad.size = Vector3(0.20, 0.008, 0.46)
		wing.mesh = quad
		wing.material_override = wing_material
		wing.position = Vector3(0.10 * sx, 0.0, 0.21)
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(wing)
		_wing_pivots.append(pivot)
	var leg_material := _material(LEG_COLOR, 0.8)
	for side in [-1.0, 1.0]:
		for k in 3:
			var leg := Node3D.new()
			leg.name = "Leg"
			leg.position = Vector3(0.10 * side, -0.05, -0.18 + 0.15 * float(k))
			var rod := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.012
			cyl.bottom_radius = 0.008
			cyl.height = 0.2
			cyl.radial_segments = 5
			cyl.rings = 1
			rod.mesh = cyl
			rod.material_override = leg_material
			rod.position = Vector3(0.0, -0.1, 0.0)
			rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			leg.add_child(rod)
			leg.rotation = Vector3(0.0, 0.0, deg_to_rad(-34.0 * side))
			_torso.add_child(leg)
			_legs.append(leg)
			if k == 0:
				_front_legs.append(leg)


## Sets the pose. `alert` in [0, 1] raises it, `groom` in [0, 1] is the grooming rub, `beat` the wings' phase in seconds (flying only).
func pose(mode: int, alert: float, groom: float, beat: float) -> void:
	_mode = mode
	var flying := mode == Mode.FLYING
	var held := mode == Mode.HELD
	for leg in _legs:
		leg.visible = not flying and not held
	var up := alert if mode == Mode.ALERT else 0.0
	_torso.rotation = Vector3(deg_to_rad(-12.0 * up), 0.0, 0.0)
	_torso.position = Vector3(0.0, 0.03 * up, 0.0)
	_head.rotation = Vector3(deg_to_rad(-16.0 * up + 10.0 * groom), 0.0, 0.0)
	var fold := 8.0
	if mode == Mode.ALERT:
		fold = 8.0 + 30.0 * up
	for i in _wing_pivots.size():
		var sx := -1.0 if i == 0 else 1.0
		var angle := fold
		if flying:
			angle = 38.0 + 52.0 * sin(TAU * 24.0 * beat + _phase)
		elif held:
			angle = 0.0
		_wing_pivots[i].rotation = Vector3(0.0, 0.0, deg_to_rad(-angle * sx))
	for i in _front_legs.size():
		var side := -1.0 if i == 0 else 1.0
		var rub := 0.0
		if mode == Mode.GROOMING:
			rub = 28.0 * groom * sin(TAU * 7.0 * beat + _phase + float(i))
		_front_legs[i].rotation = Vector3(deg_to_rad(-35.0 * groom + rub), 0.0, deg_to_rad(-34.0 * side + 20.0 * groom * side))


func _ellipsoid(part_name: String, radii: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mi.mesh = sphere
	mi.scale = radii
	mi.position = at
	mi.material_override = material
	return mi


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m
