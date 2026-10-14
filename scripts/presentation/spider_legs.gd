extends Node3D
## Cosmetic gait used by the live spider and the standalone preview. +Y is support-up, -Z is forward.
## The caller supplies velocity in this node's local support frame. No motor,
## input, settings, RNG, collision, rays or save state are read or changed here.
## Call advance_pose once per physics tick, after updating the body's frame.
## This is an alternating four-leg approximation, not biological foot IK.

const HIP_Z := [-0.36, -0.24, -0.12, 0.0]
const KNEE_Z := [-0.62, -0.38, -0.06, 0.30]
const TIP_Z := [-0.82, -0.52, 0.12, 0.62]
const STRIDE := 0.48
const STEP_HEIGHT := 0.12
const MAX_SPEED := 8.0
const STANCE_SHARE := 0.65

var _phase: float = 0.0
var _feet: Array[Vector3] = []
var _segments: Array[MeshInstance3D] = []
## Supply before adding to the tree to match the caller's body material.
var material: StandardMaterial3D
## VISUAL-01 (drawn only): set before adding to the tree to give each leg a third, thin distal segment (metatarsus and tarsus)
## and small pale joint bulbs, the bold jumper's banded knees. They live under `detail_parent`, not here, so this node keeps
## its sixteen rods. With detail the second rod ends at the ankle; the feet are exactly where they were.
var detail_parent: Node3D
var joint_material: StandardMaterial3D
var _tarsi: Array[MeshInstance3D] = []
var _joints: Array[MeshInstance3D] = []   # two per leg: knee, ankle
## Stout front legs, slimmer back legs (salticid silhouette): [femur top, femur base, tibia top, tibia base] per pair.
const LEG_RADII := [[0.034, 0.044, 0.028, 0.036], [0.028, 0.037, 0.023, 0.030],
	[0.024, 0.033, 0.019, 0.026], [0.025, 0.034, 0.020, 0.027]]
const ANKLE_SHARE := 0.62      # along knee -> foot
const ANKLE_LIFT := 0.045      # WU above that line, along support-up


func _ready() -> void:
	if material == null:
		material = StandardMaterial3D.new()
		material.albedo_color = Color("594034")
		material.roughness = 0.8
	for i in 16:
		var r: Array = LEG_RADII[(i / 2) % 4]
		var mesh := CylinderMesh.new()
		mesh.top_radius = r[0] if i % 2 == 0 else r[2]
		mesh.bottom_radius = r[1] if i % 2 == 0 else r[3]
		mesh.height = 1.0
		mesh.radial_segments = 8 if detail_parent != null else 6
		mesh.rings = 1
		var segment := MeshInstance3D.new()
		segment.mesh = mesh
		segment.material_override = material
		add_child(segment)
		_segments.append(segment)
	if detail_parent != null:
		_build_detail()
	reset_pose()


func _build_detail() -> void:
	if joint_material == null:
		joint_material = material
	for i in 8:
		var r: Array = LEG_RADII[i % 4]
		var mesh := CylinderMesh.new()
		mesh.top_radius = r[2] * 0.42
		mesh.bottom_radius = r[2] * 0.85
		mesh.height = 1.0
		mesh.radial_segments = 6
		mesh.rings = 1
		var tarsus := MeshInstance3D.new()
		tarsus.name = "Tarsus%d" % i
		tarsus.mesh = mesh
		tarsus.material_override = material
		detail_parent.add_child(tarsus)
		_tarsi.append(tarsus)
		for j in 2:
			var bulb := SphereMesh.new()
			bulb.radius = (r[1] if j == 0 else r[3]) * 0.9
			bulb.height = bulb.radius * 2.0
			bulb.radial_segments = 8
			bulb.rings = 4
			var joint := MeshInstance3D.new()
			joint.name = ("Knee%d" if j == 0 else "Ankle%d") % i
			joint.mesh = bulb
			joint.material_override = joint_material
			joint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			detail_parent.add_child(joint)
			_joints.append(joint)


func has_detail() -> bool:
	return not _tarsi.is_empty()


## Where the drawn tibia ends and the thin tarsus begins: a little above the knee-to-foot line.
static func ankle_point(knee: Vector3, foot: Vector3, up: Vector3) -> Vector3:
	return knee.lerp(foot, ANKLE_SHARE) + up * ANKLE_LIFT


## Places leg i's detail. `world` puts it in world space with the body's scale `s` (surface contacts); otherwise local.
func _place_detail(i: int, knee: Vector3, ankle: Vector3, foot: Vector3, world: bool, s: float, shown: bool) -> void:
	if _tarsi.is_empty():
		return
	var parts: Array[MeshInstance3D] = [_tarsi[i], _joints[i * 2], _joints[i * 2 + 1]]
	for part in parts:
		part.top_level = world
		part.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF if world else Node.PHYSICS_INTERPOLATION_MODE_INHERIT
		part.visible = shown
	_place_segment(_tarsi[i], ankle, foot)
	var k := Basis.IDENTITY
	if world:
		var b := _tarsi[i].basis
		b.x *= s
		b.z *= s
		_tarsi[i].basis = b
		k = Basis.IDENTITY.scaled(Vector3.ONE * s)
	_joints[i * 2].transform = Transform3D(k, knee)
	_joints[i * 2 + 1].transform = Transform3D(k, ankle)


func reset_pose() -> void:
	_phase = 0.0
	advance_pose(0.0, Vector3.ZERO)


## grounded=false folds legs for flight/hanging; preparing lowers the stance.
## reduced_motion=true uses the neutral pose without cycling or body movement.
## Invalid samples are ignored, and large frame gaps are bounded to avoid snaps.
func advance_pose(delta: float, local_velocity: Vector3, grounded: bool = true,
		preparing: bool = false, reduced_motion: bool = false) -> void:
	if not is_finite(delta) or delta < 0.0 or not local_velocity.is_finite():
		return
	var planar := Vector3(local_velocity.x, 0.0, local_velocity.z).limit_length(MAX_SPEED)
	var moving := grounded and not preparing and not reduced_motion and planar.length() > 0.03
	if moving:
		_phase = fposmod(_phase + planar.length() * minf(delta, 0.1) / STRIDE, 1.0)
	else:
		_phase = 0.0
	_feet.clear()
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		for pair in 4:
			var hip := Vector3(side * 0.16, 0.02, HIP_Z[pair])
			var knee := Vector3(side * 0.50, 0.26, KNEE_Z[pair])
			var foot := Vector3(side * 0.78, -0.30, TIP_Z[pair])
			if not reduced_motion:
				if not grounded:
					foot = Vector3(side * 0.47, -0.12, TIP_Z[pair] * 0.72)
					knee.x *= 0.8
				elif preparing:
					foot.x *= 1.1
					foot.y = -0.265
				elif moving:
					var phase := fposmod(_phase + 0.5 * ((pair + side_index) % 2), 1.0)
					var travel: float
					if phase < STANCE_SHARE:
						travel = lerpf(0.5, -0.5, phase / STANCE_SHARE)
					else:
						var swing := (phase - STANCE_SHARE) / (1.0 - STANCE_SHARE)
						travel = lerpf(-0.5, 0.5, smoothstep(0.0, 1.0, swing))
						foot.y += sin(swing * PI) * STEP_HEIGHT
					foot += planar.normalized() * travel * STRIDE * STANCE_SHARE
					knee += (foot - Vector3(side * 0.78, -0.30, TIP_Z[pair])) * 0.35
			_feet.append(foot)
			var index := (side_index * 4 + pair) * 2
			if _segments.size() == 16:
				_place_segment(_segments[index], hip, knee)
				if has_detail():
					var ankle := ankle_point(knee, foot, Vector3.UP)
					_place_segment(_segments[index + 1], knee, ankle)
					_place_detail(side_index * 4 + pair, knee, ankle, foot, false, 1.0, _detail_shown(pair))
				else:
					_place_segment(_segments[index + 1], knee, foot)


## Overridden by the live rig (eye view shows only the front legs' far ends).
func _detail_shown(_pair: int) -> bool:
	return true


## A copy for prototype inspection; callers cannot mutate the internal pose.
func foot_positions() -> Array[Vector3]:
	return _feet.duplicate()


func _place_segment(segment: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var direction := to - from
	var basis := Basis(Quaternion(Vector3.UP, direction.normalized()))
	# Scale the cylinder's LOCAL length axis. World-axis scaling skews a tilted rod
	# and leaves its ends sticking through (or falling short of) the knee.
	basis.y *= direction.length()
	segment.transform = Transform3D(basis, (from + to) * 0.5)
