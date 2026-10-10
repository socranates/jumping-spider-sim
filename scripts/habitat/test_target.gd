extends Node3D
## TestTarget (A-010): a clearly labelled moving marker for proving perception. It is NOT a fly: it has no senses, no
## goals and no reaction to anything, and the sign beside it in the lab says so. It walks a path to and fro (stopping a
## moment at each end), gives a percept to whoever can sense it, and can be taken out of the world, held still or put
## somewhere else by a fixture. Drawn as a magenta ball on a short rod and a flat base, so nobody takes it for prey.
##
## The ball's centre is the node's origin; its percept is a sphere of RADIUS about it. The rod under it is `stand_height`
## long (the lab sets it to the height of the path, so the base sits on the floor).

const Perceivable = preload("res://scripts/perception/perceivable.gd")
const Observation = preload("res://scripts/perception/observation.gd")

const RADIUS := 0.45
## Slow enough that a person can see the cue, turn the camera, hold Focus and watch it classify before it goes behind the screen.
const DEFAULT_SPEED := 0.8
const DEFAULT_PAUSE_S := 1.2
const ROD_HEIGHT := 0.8
## What the sign beside the stage says: the marker is a prop for proving the senses, nothing more.
const SIGN_TEXT := "TEST TARGET\na moving marker, not a fly\nit stands in for prey, to show how the senses work\nwatch it from the ledge"

var target_id: String = "test_target"
var radius: float = RADIUS
## The finest category an observer can ever refine it to (Observation.MOVEMENT makes a "neutral moving thing").
var max_category: StringName = Observation.FLY_LIKE_PREY
var path: PackedVector3Array = PackedVector3Array()
var speed: float = DEFAULT_SPEED
## Length of the rod under the ball, WU (set before the marker enters the tree).
var stand_height: float = ROD_HEIGHT
var pause_s: float = DEFAULT_PAUSE_S
## Out of the world: no percept, not drawn, not moving.
var enabled: bool = true
## Held where it is: no percept change, no movement (a fixture's hand).
var frozen: bool = false
## WU/s over the last tick.
var velocity: Vector3 = Vector3.ZERO

var _target_index: int = 1
var _direction: int = 1
var _pause_left: float = 0.0
var _last: Vector3 = Vector3.ZERO
var _ball: MeshInstance3D


func _ready() -> void:
	add_to_group(Perceivable.GROUP)
	_build_body()
	_last = global_position


## Replaces the path and puts the marker at its first point, heading for the second (it walks again, even if it was held).
func set_path(points: PackedVector3Array) -> void:
	path = points
	frozen = false
	_direction = 1
	_target_index = 1 if points.size() > 1 else 0
	_pause_left = 0.0
	velocity = Vector3.ZERO
	if not points.is_empty():
		global_position = points[0]
	_last = global_position


## Puts the marker down at `point`, still, until released: for a fixture that wants it exactly there.
func hold_at(point: Vector3) -> void:
	frozen = true
	global_position = point
	_last = point
	velocity = Vector3.ZERO


## Lets a held marker walk again from where it stands, toward the nearest end of the path ahead of it.
func release() -> void:
	frozen = false
	_pause_left = 0.0
	_last = global_position


## Takes the marker out of the world, or puts it back.
func set_enabled(on: bool) -> void:
	enabled = on
	if is_inside_tree():
		visible = on
	velocity = Vector3.ZERO
	_last = global_position


## What a sensor may read (spec 19.3). Nothing while it is out of the world.
func get_percept() -> Dictionary:
	if not enabled:
		return {}
	return Perceivable.make(target_id, global_position, radius, velocity, max_category)


func _physics_process(delta: float) -> void:
	if not enabled or frozen or path.size() < 2:
		velocity = Vector3.ZERO
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		velocity = Vector3.ZERO
		return
	var goal := path[_target_index]
	var to := goal - global_position
	var step := speed * delta
	if to.length() <= step:
		global_position = goal
		var next := _target_index + _direction
		if next < 0 or next >= path.size():
			_direction = -_direction
			next = _target_index + _direction
			_pause_left = pause_s
		_target_index = next
	else:
		global_position += to.normalized() * step
	velocity = (global_position - _last) / delta
	_last = global_position


func _build_body() -> void:
	var magenta := _material(Color(0.86, 0.12, 0.62))
	var dark := _material(Color(0.20, 0.20, 0.24))
	var white := _material(Color(0.96, 0.96, 0.98))
	_ball = MeshInstance3D.new()
	_ball.name = "Ball"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	_ball.mesh = sphere
	_ball.material_override = magenta
	add_child(_ball)
	var band := MeshInstance3D.new()
	band.name = "Band"
	var ring := CylinderMesh.new()
	ring.top_radius = radius * 1.02
	ring.bottom_radius = radius * 1.02
	ring.height = radius * 0.16
	band.mesh = ring
	band.material_override = white
	add_child(band)
	var rod := MeshInstance3D.new()
	rod.name = "Rod"
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.05
	rod_mesh.bottom_radius = 0.05
	rod_mesh.height = stand_height
	rod.mesh = rod_mesh
	rod.material_override = dark
	rod.position = Vector3(0.0, -stand_height * 0.5, 0.0)
	add_child(rod)
	var base := MeshInstance3D.new()
	base.name = "Base"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.32
	base_mesh.bottom_radius = 0.32
	base_mesh.height = 0.06
	base.mesh = base_mesh
	base.material_override = dark
	base.position = Vector3(0.0, -stand_height + 0.03, 0.0)
	add_child(base)
	visible = enabled


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m
