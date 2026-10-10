extends RefCounted
## Pure geometry helpers for supported locomotion (spec 6.1, 6.2). No scene access, so they can
## be unit tested. Normals and directions are unit vectors in world space.


## The part of v that lies in the plane with unit normal n.
static func tangent(v: Vector3, n: Vector3) -> Vector3:
	return v - n * v.dot(n)


## Unit direction of v on the plane with normal n, or ZERO when v is (nearly) along n.
static func tangent_dir(v: Vector3, n: Vector3, eps: float = 1e-5) -> Vector3:
	var t := tangent(v, n)
	var length := t.length()
	return t / length if length > eps else Vector3.ZERO


## Hysteresis for the support normal. A candidate within ignore_deg of the current normal is
## ignored and the current normal kept, so tiny differences between adjacent faces or coplanar
## seams never move the support frame. Larger changes are taken as they are. A non-finite or zero
## candidate keeps the current normal.
static func filter_normal(current: Vector3, candidate: Vector3, ignore_deg: float) -> Vector3:
	if not candidate.is_finite() or candidate.length_squared() < 1e-10:
		return current
	var c := candidate.normalized()
	if not current.is_finite() or current.length_squared() < 1e-10:
		return c
	if current.normalized().angle_to(c) <= deg_to_rad(ignore_deg):
		return current
	return c


## Any unit vector perpendicular to v.
static func any_perpendicular(v: Vector3) -> Vector3:
	var other := Vector3.RIGHT if absf(v.normalized().x) < 0.9 else Vector3.BACK
	return v.cross(other).normalized()


## Turns unit vector `from` toward unit vector `to` by at most max_angle radians (shortest arc).
static func rotate_toward(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	var angle := from.angle_to(to)
	if angle <= max_angle or angle < 1e-6:
		return to
	var axis := from.cross(to)
	if axis.length_squared() < 1e-12:
		axis = any_perpendicular(from)
	return from.rotated(axis.normalized(), max_angle).normalized()


## The smallest rotation that takes unit vector a onto unit vector b. Opposite vectors turn about
## any perpendicular axis.
static func rotation_between(a: Vector3, b: Vector3) -> Basis:
	var angle := a.angle_to(b)
	if angle < 1e-6:
		return Basis.IDENTITY
	var axis := a.cross(b)
	if axis.length_squared() < 1e-12:
		axis = any_perpendicular(a)
	return Basis(axis.normalized(), angle)


## Signed angle from a to b about the axis n (all unit vectors, a and b perpendicular to n).
static func signed_angle(a: Vector3, b: Vector3, n: Vector3) -> float:
	return atan2(n.dot(a.cross(b)), a.dot(b))


## The line where plane 1 (point p1, normal n1) meets plane 2 (point p2, normal n2), as
## [point_on_line, unit_direction]. Empty when the planes are (nearly) parallel.
static func edge_line(p1: Vector3, n1: Vector3, p2: Vector3, n2: Vector3) -> Array:
	var d := n1.cross(n2)
	var dd := d.length_squared()
	if dd < 1e-6:
		return []
	var c := n1.dot(n2)
	var h1 := n1.dot(p1)
	var h2 := n2.dot(p2)
	var point := (n1 * (h1 - h2 * c) + n2 * (h2 - h1 * c)) / dd
	return [point, d / sqrt(dd)]


## The point of a line (point, unit direction) closest to `point`.
static func closest_on_line(point: Vector3, line_point: Vector3, line_dir: Vector3) -> Vector3:
	return line_point + line_dir * (point - line_point).dot(line_dir)


## Body frame for an up vector and a heading: y is up, -z is the heading made perpendicular to up.
## A heading along up falls back to any perpendicular direction.
static func body_basis(up: Vector3, heading: Vector3) -> Basis:
	var u := up.normalized()
	var f := tangent_dir(heading, u)
	if f == Vector3.ZERO:
		f = any_perpendicular(u)
	var z := -f
	return Basis(u.cross(z), u, z).orthonormalized()
