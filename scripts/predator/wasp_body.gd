extends Node3D
## Cosmetic Sceliphron silhouette; -Z forward. Dimensions and animation are
## authored approximations, not measured wing kinematics. No collision/AI.
enum Mode { FLYING, WALKING, HOLDING }
var _phase := 0.0
var _wings: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _antennae: Array[Node3D] = []
var _torso: Node3D

func _init(phase: float = 0.0) -> void:
	_phase = phase
	_build()

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _ellipsoid(label: String, radii: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	node.mesh = mesh
	node.scale = radii
	node.position = at
	node.material_override = mat
	return node

func _rod(label: String, radius: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = 7
	mesh.rings = 1
	node.mesh = mesh
	node.material_override = mat
	return node

func _span(node: Node3D, a: Vector3, b: Vector3) -> void:
	var axis := b - a
	var frame := Basis(Quaternion(Vector3.UP, axis.normalized()))
	frame.y *= axis.length()
	node.transform = Transform3D(frame, (a + b) * 0.5)

func _build() -> void:
	_torso = Node3D.new()
	_torso.name = "Torso"
	add_child(_torso)
	var black := _material(Color("191919"), 0.36)
	var yellow := _material(Color("d9af26"), 0.48)
	var eye := _material(Color("302b24"), 0.18)
	_torso.add_child(_ellipsoid("Head", Vector3(0.23,0.20,0.17), Vector3(0,0.04,-1.05), black))
	_torso.add_child(_ellipsoid("Thorax", Vector3(0.24,0.24,0.35), Vector3(0,0.02,-0.63), black))
	_torso.add_child(_ellipsoid("Scutellum", Vector3(0.13,0.045,0.085), Vector3(0,0.25,-0.52), yellow))
	_torso.add_child(_ellipsoid("Collar", Vector3(0.20,0.04,0.055), Vector3(0,0.20,-0.85), yellow))
	var waist := _rod("Petiole",0.038,yellow)
	_torso.add_child(waist)
	_span(waist,Vector3(0,0,-0.32),Vector3(0,0.04,0.39))
	# Overlapping tapering segments give a narrow attachment and pointed rear.
	_torso.add_child(_ellipsoid("Gaster",Vector3(0.245,0.22,0.39),Vector3(0,0.025,0.76),black))
	_torso.add_child(_ellipsoid("AbdomenTip",Vector3(0.15,0.15,0.23),Vector3(0,-0.01,1.02),black))
	_torso.add_child(_ellipsoid("AbdomenBase",Vector3(0.12,0.115,0.13),Vector3(0,0.04,0.40),yellow))
	for side in [-1.0,1.0]:
		_torso.add_child(_ellipsoid("CompoundEye",Vector3(0.085,0.15,0.115),Vector3(side*0.185,0.075,-1.075),eye))
		_torso.add_child(_ellipsoid("Mandible",Vector3(0.035,0.07,0.065),Vector3(side*0.055,-0.10,-1.19),yellow))
		var antenna := Node3D.new()
		antenna.name = "Antenna"
		antenna.position = Vector3(side*0.075,0.13,-1.15)
		_torso.add_child(antenna)
		_antennae.append(antenna)
		var scape := _rod("Scape",0.020,yellow)
		antenna.add_child(scape)
		_span(scape,Vector3.ZERO,Vector3(side*0.055,0.10,-0.17))
		var flagellum := _rod("Flagellum",0.013,black)
		antenna.add_child(flagellum)
		_span(flagellum,Vector3(side*0.055,0.10,-0.17),Vector3(side*0.19,0.06,-0.53))
		for k in 2:
			var pivot := Node3D.new()
			pivot.name = "WingPivot"
			pivot.position = Vector3(side*0.14,0.20,-0.68+k*0.17)
			_torso.add_child(pivot)
			_wings.append(pivot)
			_make_wing(pivot,side,1.0 if k==0 else 0.68)
		for k in 3:
			var leg := Node3D.new()
			leg.name = "Leg"
			leg.position = Vector3(side*0.17,-0.12,-0.82+k*0.18)
			_torso.add_child(leg)
			_legs.append(leg)
			leg.add_child(_rod("Femur",0.036,black))
			leg.add_child(_rod("Tibia",0.026,yellow))
			leg.add_child(_rod("Tarsus",0.015,yellow))
	pose(Mode.FLYING,0.0,0.0)

func _make_wing(pivot: Node3D, side: float, size: float) -> void:
	var mat := _material(Color(0.28,0.23,0.17,0.40),0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var points := PackedVector3Array([Vector3.ZERO,Vector3(0.27,0,0.12),Vector3(0.49,0,0.61),Vector3(0.40,0,1.02),Vector3(0.24,0,1.17),Vector3(0.08,0,0.80)])
	for i in points.size():
		points[i] *= size
		points[i].x *= side
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()-1):
		for index in [0,i,i+1]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(points[index])
	var wing := MeshInstance3D.new()
	wing.name = "Membrane"
	wing.mesh = surface.commit()
	wing.material_override = mat
	wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(wing)
	var vein_mat := _material(Color("5b4a31"),0.7)
	for endpoints in [[0,2],[0,4],[2,4]]:
		var vein := _rod("Vein",0.005,vein_mat)
		vein.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(vein)
		_span(vein,points[endpoints[0]],points[endpoints[1]])

## Absolute-time pose: repeated calls never accumulate drift or allocate meshes.
func pose(mode: int, beat: float, search: float) -> void:
	var walking := mode == Mode.WALKING
	for i in _wings.size():
		var side := -1.0 if i<2 else 1.0
		# Bounded authored blur motion, not a claim about wingbeat frequency.
		var flap := 6.0 if walking else 25.0+38.0*sin(TAU*23.0*beat+_phase)
		_wings[i].rotation = Vector3(0,deg_to_rad(side*(12.0 if walking else 58.0)),deg_to_rad(-side*flap))
	for i in _legs.size():
		var side := -1.0 if i<3 else 1.0
		var pair := i%3
		var knee := Vector3(side*(0.35+0.05*pair),-0.25,0.04+0.15*pair)
		var ankle := Vector3(side*(0.52+0.09*pair),-0.58,0.10+0.23*pair)
		var tip := ankle+Vector3(side*0.03,-0.12,0.12)
		if walking:
			# Director places the actor 0.35 WU above its walking surface.
			knee.y = -0.08
			ankle.y = -0.20
			tip.y = -0.23
			var cycle := TAU*3.0*beat+_phase+PI*((pair+i/3)%2)
			var stride := Vector3(0,maxf(0,sin(cycle))*0.13,cos(cycle)*0.18)
			ankle += stride
			tip += stride
		elif mode==Mode.HOLDING and pair<2:
			knee = Vector3(side*0.30,-0.26,-0.05)
			ankle = Vector3(side*0.18,-0.58,-0.07)
			tip = Vector3(side*0.08,-0.60,-0.16)
		else:
			ankle.z += 0.25+0.14*pair
			tip = ankle+Vector3(0,-0.11,0.14)
		_span(_legs[i].get_child(0),Vector3.ZERO,knee)
		_span(_legs[i].get_child(1),knee,ankle)
		_span(_legs[i].get_child(2),ankle,tip)
	for i in _antennae.size():
		var side := -1.0 if i==0 else 1.0
		var flick := clampf(search,0,1)*sin(TAU*(3.0+0.7*i)*beat+_phase)*0.32
		_antennae[i].rotation = Vector3(0.20+flick,side*0.12+flick*0.5,0)
	_torso.position.y = 0.0 if walking else 0.025*sin(TAU*1.3*beat+_phase)
