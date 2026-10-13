extends Node3D
## WaspBody: the drawn mud dauber (LIFE_DESIGN round 4; cosmetic only, a placeholder for Chet's model). Nothing here is read by the
## simulation. The black-and-yellow mud dauber, Sceliphron caementarium: about 2.5 WU long (the game's scale is 1 WU = 1 cm), a black
## head and thorax, a long thin yellow waist (the petiole), a black abdomen, yellow legs and smoky wings. Drawn from primitives. In the
## wasp's own frame -Z is where it faces and +Y is its up.
##   * flying and hovering: the wings blur, the long hind legs hang down behind;
##   * walking: the wings lie flat over the back and the legs step;
##   * holding: flying, with the front legs drawn in under the body (it carries the spider there);
##   * the antennae flick while it searches and inspects (`search` in [0, 1]).

const BLACK := Color(0.07, 0.06, 0.06)
const YELLOW := Color(0.93, 0.76, 0.16)
const WING := Color(0.22, 0.2, 0.18, 0.45)

enum Mode { FLYING, WALKING, HOLDING }

var _wings: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _antennae: Array[Node3D] = []
var _torso: Node3D
var _phase: float = 0.0


func _init(phase: float = 0.0) -> void:
	_phase = phase
	_build()


func _build() -> void:
	_torso = Node3D.new()
	_torso.name = "Torso"
	add_child(_torso)
	var black := _material(BLACK, 0.35)
	var yellow := _material(YELLOW, 0.45)
	_torso.add_child(_ellipsoid("Head", Vector3(0.2, 0.18, 0.16), Vector3(0.0, 0.05, -1.02), black))
	for sx in [-1.0, 1.0]:
		_torso.add_child(_ellipsoid("Eye", Vector3(0.07, 0.12, 0.1), Vector3(0.15 * sx, 0.07, -1.0), _material(Color(0.15, 0.13, 0.1), 0.2)))
	_torso.add_child(_ellipsoid("Thorax", Vector3(0.24, 0.24, 0.36), Vector3(0.0, 0.05, -0.6), black))
	_torso.add_child(_ellipsoid("ThoraxSpot", Vector3(0.12, 0.05, 0.08), Vector3(0.0, 0.27, -0.55), yellow))
	var waist := _rod("Petiole", 0.045, 0.6, yellow)
	waist.position = Vector3(0.0, 0.0, 0.0)
	waist.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	_torso.add_child(waist)
	_torso.add_child(_ellipsoid("Abdomen", Vector3(0.26, 0.24, 0.42), Vector3(0.0, -0.02, 0.68), black))
	_torso.add_child(_ellipsoid("AbdomenBand", Vector3(0.2, 0.19, 0.1), Vector3(0.0, 0.0, 0.32), yellow))
	var head := Vector3(0.0, 0.12, -1.12)
	for sx in [-1.0, 1.0]:
		var a := Node3D.new()
		a.name = "Antenna"
		a.position = head + Vector3(0.05 * sx, 0.0, 0.0)
		var rod := _rod("AntennaRod", 0.015, 0.7, black)
		rod.position = Vector3(0.0, 0.0, -0.35)
		rod.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
		a.add_child(rod)
		a.rotation = Vector3(deg_to_rad(25.0), deg_to_rad(18.0 * sx), 0.0)
		_torso.add_child(a)
		_antennae.append(a)
	var wing_material := _material(WING, 0.2)
	wing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for sx in [-1.0, 1.0]:
		for k in 2:
			var pivot := Node3D.new()
			pivot.name = "WingPivot"
			pivot.position = Vector3(0.14 * sx, 0.22, -0.62 + 0.14 * float(k))
			var wing := MeshInstance3D.new()
			var quad := BoxMesh.new()
			quad.size = Vector3(0.3 if k == 0 else 0.22, 0.01, 1.05 if k == 0 else 0.75)
			wing.mesh = quad
			wing.material_override = wing_material
			wing.position = Vector3(0.12 * sx, 0.0, 0.48 if k == 0 else 0.36)
			wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(wing)
			_torso.add_child(pivot)
			_wings.append(pivot)
	var leg_material := _material(YELLOW, 0.6)
	for side in [-1.0, 1.0]:
		for k in 3:
			var leg := Node3D.new()
			leg.name = "Leg"
			leg.position = Vector3(0.16 * side, -0.12, -0.75 + 0.15 * float(k))
			var rod := _rod("LegRod", 0.025, 0.7 + 0.25 * float(k), leg_material)
			rod.position = Vector3(0.0, -(0.35 + 0.125 * float(k)), 0.0)
			leg.add_child(rod)
			_torso.add_child(leg)
			_legs.append(leg)


## Sets the pose. `beat` is the wings' (and the steps') phase in seconds; `search` in [0, 1] how busily the antennae flick.
func pose(mode: int, beat: float, search: float) -> void:
	var walking := mode == Mode.WALKING
	for i in _wings.size():
		var sx := -1.0 if i < 2 else 1.0
		var angle := 8.0 if walking else 40.0 + 55.0 * sin(TAU * 26.0 * beat + _phase + float(i))
		var sweep := 32.0 if walking else 0.0
		_wings[i].rotation = Vector3(0.0, deg_to_rad(sweep * sx), deg_to_rad(-angle * sx))
	for i in _legs.size():
		var side := -1.0 if i < 3 else 1.0
		var k := i % 3
		var spread := -40.0 * side
		var swing := 0.0
		var hang := 0.0
		if walking:
			var tripod := 1.0 if ((k + (0 if side < 0.0 else 1)) % 2 == 0) else -1.0
			swing = 24.0 * tripod * sin(TAU * 4.0 * beat + _phase)
		elif mode == Mode.HOLDING and k < 2:
			hang = -50.0
			spread = -15.0 * side
		else:
			hang = 35.0 + 15.0 * float(k)   # in flight the long legs trail down and back
			spread = -18.0 * side
		_legs[i].rotation = Vector3(deg_to_rad(hang + swing), 0.0, deg_to_rad(spread))
	for i in _antennae.size():
		var sx := -1.0 if i == 0 else 1.0
		var flick := search * 22.0 * sin(TAU * (3.0 + 0.7 * float(i)) * beat + _phase)
		_antennae[i].rotation = Vector3(deg_to_rad(25.0 + flick), deg_to_rad(18.0 * sx + flick * 0.5), 0.0)
	_torso.position = Vector3(0.0, 0.03 * sin(TAU * 1.3 * beat + _phase), 0.0) if not walking else Vector3.ZERO


func _rod(part_name: String, radius: float, length: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 0.7
	cyl.height = length
	cyl.radial_segments = 6
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = material
	return mi


func _ellipsoid(part_name: String, radii: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 14
	sphere.rings = 7
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
