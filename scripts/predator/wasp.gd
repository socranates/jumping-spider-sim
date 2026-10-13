extends Node3D
## Wasp: the mud dauber on the sill (LIFE_DESIGN round 4). The WaspDirector decides everything it does and moves it; this node is where
## it is, which way it faces, how it is posed, and what the spider can sense of it. Like a fly it has no physics body: it never pushes
## anything, and the director keeps its paths clear of the world. The spider sees it as movement (the "perceivable" group) and never as
## prey: its percept is capped at MOVEMENT, so no aim, capture or inspection ever treats it as something to catch.

const SimClock = preload("res://scripts/core/sim_clock.gd")
const Perceivable = preload("res://scripts/perception/perceivable.gd")
const Observation = preload("res://scripts/perception/observation.gd")
const WaspBody = preload("res://scripts/predator/wasp_body.gd")

## Where its eyes are, ahead of its centre along the facing (WU).
const EYE_AHEAD := 1.0
## The size the spider's senses give it (WU).
const SENSED_RADIUS := 0.9

var id := "wasp"
## Where it faces (world, unit).
var heading := Vector3.FORWARD
## How it moves (WU/s), from its own motion each tick.
var velocity := Vector3.ZERO
## The surface it stands on when it stands (VibrationSense reads it to find what it shakes), else up.
var normal := Vector3.UP
var mode: int = WaspBody.Mode.FLYING
## How busily the antennae flick (0 to 1).
var search := 0.0
var body: Node3D
var _beat := 0.0
var _prev := Vector3.ZERO


func _ready() -> void:
	add_to_group(Perceivable.GROUP)
	body = WaspBody.new(0.37)
	body.name = "Body"
	add_child(body)
	visible = false
	_prev = global_position


## Places it and faces it along `dir` (flattened), and works out its velocity from where it was.
func move_to(p: Vector3, dir: Vector3, dt: float) -> void:
	global_position = p
	velocity = (p - _prev) / dt if dt > 0.0 else Vector3.ZERO
	_prev = p
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 1e-4:
		heading = flat.normalized()
		global_basis = Basis.looking_at(heading, Vector3.UP)


## Puts it somewhere without a velocity (its first appearance).
func place(p: Vector3) -> void:
	global_position = p
	_prev = p
	velocity = Vector3.ZERO


func eye_position() -> Vector3:
	return global_position + heading * EYE_AHEAD


func get_percept() -> Dictionary:
	if not visible:
		return {}
	return Perceivable.make(id, global_position, SENSED_RADIUS, velocity, Observation.MOVEMENT)


func _physics_process(_delta: float) -> void:
	if not visible:
		return
	_beat += SimClock.DT
	body.pose(mode, _beat, search)
