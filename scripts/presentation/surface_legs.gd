extends "res://scripts/presentation/spider_legs.gd"
## Display-only contacts. Queries never feed back into the motor or jump solver.
## Stance points live in the touched collider's frame; swing endpoints are fixed
## for each step. A missing foothold tucks the foot, never invents a platform.
const Layers = preload("res://scripts/core/physics_layers.gd")
const STEP_ERROR := 0.24
const SWING_SECONDS := 0.10
var contacts: Array[Dictionary] = []
var _world_feet: Array[Vector3] = []
var _previous_feet: Array[Vector3] = []
var _group: int = 0
var _surface_mode := false
var _push := 0.0
var steps_started := 0
var eye_view := false


func _ready() -> void:
	super._ready()
	for i in 8:
		contacts.append({"body": null, "local": Vector3.ZERO, "swing": -1.0,
			"from": Vector3.ZERO, "to": Vector3.ZERO, "up": Vector3.UP})
		_world_feet.append(Vector3.ZERO)
		_previous_feet.append(Vector3.ZERO)


func clear_contacts() -> void:
	for c in contacts:
		c.body = null
		c.swing = -1.0
	_surface_mode = false
	for segment in _segments:
		segment.top_level = false
		segment.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT


func is_planted(i: int) -> bool:
	return _surface_mode and is_instance_valid(contacts[i].body) and contacts[i].swing < 0.0


func world_foot_positions() -> Array[Vector3]:
	return _world_feet.duplicate()


func _rest(i: int) -> Vector3:
	return Vector3(-0.78 if i < 4 else 0.78, -0.30, TIP_Z[i % 4])


func _target(motor: Node3D, i: int) -> Dictionary:
	var up := global_basis.y.normalized()
	var rest := _rest(i)
	# Retract towards the body at a narrow edge; do not raycast to an imaginary
	# extension of the support plane. The same construction works upside down.
	for reach in [1.0, 0.65, 0.35, 0.12]:
		var point := to_global(Vector3(rest.x * reach, 0.0, rest.z * reach))
		var query := PhysicsRayQueryParameters3D.create(point + up * 0.35 * global_basis.get_scale().x,
			point - up * 0.65 * global_basis.get_scale().x, Layers.WORLD, [motor.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and (hit.normal as Vector3).dot(up) > 0.35:
			return hit
	return {}


func _seat(i: int, hit: Dictionary) -> void:
	var c := contacts[i]
	c.body = hit.get("collider")
	if is_instance_valid(c.body):
		c.local = (c.body as Node3D).to_local(hit.position)
		c.to = hit.position
		c.up = hit.normal


func advance_surface(motor: Node3D, dt: float, push: float = 0.0) -> void:
	var first := not _surface_mode
	_surface_mode = true
	_push = push
	_previous_feet = _world_feet.duplicate()
	var swinging := false
	for c in contacts:
		swinging = swinging or c.swing >= 0.0
	if not swinging and not first:
		var size := global_basis.get_scale().x
		var worst := STEP_ERROR * size
		for i in 8:
			var error := to_global(_rest(i)).distance_to(_world_feet[i])
			if error > worst:
				worst = error
				_group = (i % 4 + i / 4) % 2
	var size := global_basis.get_scale().x
	var started := false
	for i in 8:
		var c := contacts[i]
		var rest_world := to_global(_rest(i))
		if first or not is_instance_valid(c.body):
			_seat(i, _target(motor, i))
			c.swing = -1.0
			_world_feet[i] = c.to if is_instance_valid(c.body) else rest_world + global_basis.y * 0.16
		if is_instance_valid(c.body):
			var anchor: Vector3 = (c.body as Node3D).to_global(c.local)
			if c.swing >= 0.0:
				c.swing = minf(1.0, c.swing + dt / SWING_SECONDS)
				_world_feet[i] = (c.from as Vector3).lerp(anchor, smoothstep(0.0, 1.0, c.swing)) + (c.up as Vector3) * sin(PI * c.swing) * STEP_HEIGHT * size
				if c.swing >= 1.0:
					c.swing = -1.0
					_world_feet[i] = anchor
			else:
				_world_feet[i] = anchor
				var error := rest_world.distance_to(anchor)
				var group := (i % 4 + i / 4) % 2
				if push <= 0.0 and error > STEP_ERROR * size and (not swinging and group == _group or error > 0.60 * size):
					var hit := _target(motor, i)
					if not hit.is_empty() and anchor.distance_to(hit.position) > 0.12 * size:
						c.from = anchor
						_seat(i, hit)
						c.swing = 0.0
						steps_started += 1
						started = true
				# A teleport or a vanished/rotated support must not leave metres of leg.
				if to_local(_world_feet[i]).length() > 1.4:
					c.body = null
					_world_feet[i] = rest_world
		if first:
			_previous_feet[i] = _world_feet[i]
	if started:
		_group = 1 - _group
	_feet.clear()
	for point in _world_feet:
		_feet.append(to_local(point))
	_draw_contacts(global_transform, 1.0)


func _process(_delta: float) -> void:
	if _surface_mode:
		_draw_contacts(get_global_transform_interpolated(), Engine.get_physics_interpolation_fraction())


func _draw_contacts(xf: Transform3D, fraction: float) -> void:
	for i in 8:
		var side := -1.0 if i < 4 else 1.0
		var pair := i % 4
		var hip := xf * Vector3(side * 0.16, 0.02, HIP_Z[pair])
		var foot := _previous_feet[i].lerp(_world_feet[i], fraction)
		# Keep the foot fixed as the hip advances. The raised knee folds/extends;
		# pairs III/IV straighten during push-off. This is not a force model.
		var bend := 0.30 * (1.0 - 0.85 * _push if pair >= 2 else 1.0)
		var knee := hip.lerp(foot, 0.48) + xf.basis.y * bend
		for j in 2:
			var segment := _segments[i * 2 + j]
			segment.top_level = true
			segment.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			_place_segment(segment, hip if j == 0 else knee, knee if j == 0 else foot)
			# These rods are top-level world transforms, so inherited scale does
			# not resize their thickness (free legs inherit it normally).
			var rod_basis := segment.basis
			rod_basis.x *= xf.basis.get_scale().x
			rod_basis.z *= xf.basis.get_scale().z
			segment.basis = rod_basis
			# Only distal front legs enter the eye view. Proximal rods can cross
			# the eye during snap turns; this stable mask avoids near-plane popping.
			segment.visible = not eye_view or (pair == 0 and j == 1)


## Static drawn-in posture; does not read or alter the motor.
func pose_seized() -> void:
	clear_contacts()
	_feet.clear()
	for i in 8:
		var side := -1.0 if i < 4 else 1.0
		var pair := i % 4
		var hip := Vector3(side * 0.16, 0.02, HIP_Z[pair])
		var knee := Vector3(side * 0.34, -0.17, KNEE_Z[pair] * 0.65)
		var foot := Vector3(side * 0.10, -0.26, HIP_Z[pair])
		_feet.append(foot)
		_place_segment(_segments[i * 2], hip, knee)
		_place_segment(_segments[i * 2 + 1], knee, foot)
		_segments[i * 2].visible = not eye_view
		_segments[i * 2 + 1].visible = not eye_view


func advance_free(dt: float, reduced: bool) -> void:
	clear_contacts()
	advance_pose(dt, Vector3.ZERO, false, false, reduced)
	for i in _segments.size():
		_segments[i].visible = not eye_view or (i % 8 == 1)
