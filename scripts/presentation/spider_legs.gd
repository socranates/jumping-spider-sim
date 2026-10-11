extends Node3D
## Standalone cosmetic gait prototype. +Y is support-up, -Z is forward.
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


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("594034")
	material.roughness = 0.8
	for i in 16:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.026 if i % 2 == 0 else 0.020
		mesh.bottom_radius = 0.035 if i % 2 == 0 else 0.028
		mesh.height = 1.0
		mesh.radial_segments = 6
		mesh.rings = 1
		var segment := MeshInstance3D.new()
		segment.mesh = mesh
		segment.material_override = material
		add_child(segment)
		_segments.append(segment)
	reset_pose()


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
				_place_segment(_segments[index + 1], knee, foot)


## A copy for prototype inspection; callers cannot mutate the internal pose.
func foot_positions() -> Array[Vector3]:
	return _feet.duplicate()


func _place_segment(segment: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var direction := to - from
	var basis := Basis(Quaternion(Vector3.UP, direction.normalized()))
	segment.transform = Transform3D(basis.scaled(Vector3(1.0, direction.length(), 1.0)), (from + to) * 0.5)
