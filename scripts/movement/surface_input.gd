extends RefCounted
## Camera-relative stick mapping on any surface (spec 6.4). Pure functions, no scene access.
##
## right_t is the camera's right vector on the tangent plane of the support normal. forward_t
## comes from the camera's horizontal forward vector on the plane for floors and undersides, and
## from the camera's up vector on the plane for walls, blended between 30 and 60 degrees of tilt;
## right_t is then made perpendicular to it. On the underside forward therefore stays "away from
## the camera", because it comes from the camera's forward vector and not from a cross product
## with the normal, which would point it back at the camera.
## No mapping can be continuous for every normal (a sphere has no smooth nowhere-zero tangent
## field). Here the turn sits on surfaces tilted about 45 degrees toward or away from the camera;
## the player controller carries the heading across edges, so holding a direction never flips.

const FLOOR_BLEND_START := 0.5      # |n.y| (cos 60 degrees): below this, forward comes from the camera's up vector
const FLOOR_BLEND_END := 0.8660254  # |n.y| (cos 30 degrees): above this, from the camera's forward vector


## The camera rig's orientation for a yaw and an elevation (camera above the pivot when positive).
static func camera_basis(yaw: float, elevation: float) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -elevation)


## {"right": Vector3, "forward": Vector3}: unit, perpendicular, on the plane with normal n.
static func tangent_axes(yaw: float, elevation: float, n: Vector3) -> Dictionary:
	var normal := n.normalized() if n.is_finite() and n.length_squared() > 1e-10 else Vector3.UP
	var cam := camera_basis(yaw, elevation)
	var cam_right := cam.x
	var cam_up := cam.y
	var flat_forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var pf := _dir_on(flat_forward, normal)
	var pu := _dir_on(cam_up, normal)
	var w := smoothstep(FLOOR_BLEND_START, FLOOR_BLEND_END, absf(normal.y))
	var forward := pf * w + pu * (1.0 - w)
	if forward.length_squared() < 1e-6:
		# The two references cancel (a surface tilted about 45 degrees toward the camera): use the
		# direction perpendicular to the camera's right vector instead.
		var pr := _dir_on(cam_right, normal)
		if pr == Vector3.ZERO:
			pr = _dir_on(Vector3.RIGHT, normal)
		forward = normal.cross(pr)
	forward = _dir_on(forward, normal)
	var right := forward.cross(normal).normalized()
	if right.dot(cam_right) < 0.0:
		right = -right
	return {"right": right, "forward": forward}


## World intent for a stick vector (x right, y forward, length up to 1) on a surface with normal n.
## The result lies on the tangent plane and keeps the stick's length.
static func map_stick(stick: Vector2, yaw: float, elevation: float, n: Vector3) -> Vector3:
	if not stick.is_finite() or stick.length_squared() < 1e-12:
		return Vector3.ZERO
	var s := stick.limit_length(1.0)
	var axes := tangent_axes(yaw, elevation, n)
	var right: Vector3 = axes["right"]
	var forward: Vector3 = axes["forward"]
	return right * s.x + forward * s.y


static func _dir_on(v: Vector3, n: Vector3) -> Vector3:
	var t := v - n * v.dot(n)
	var length := t.length()
	return t / length if length > 1e-6 else Vector3.ZERO
