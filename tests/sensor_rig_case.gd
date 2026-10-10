extends "res://tests/test_case.gd"
## A bare rig for the tests of the sensor that need exact geometry (A-024, A-027; chunk 7A): an observer with its eye at the origin
## looking along -Z, walls that can be raised and lowered, balls that stand for things (props for proving the senses, with ids the
## test is free to swap), and the real SensorSystem and ObservationMemory with the shipped species numbers. It is not the lab and
## nothing in it is a fly.
##
## The standard cover of the association fixtures: a narrow screen 4 WU in front of the eye. A ball 0.25 WU in radius, 8 WU out, is
## in plain view and in the inspection cone from about |x| = 1.2 to 2.1, partly hidden from about 0.8 to 1.2 and wholly hidden
## inside that.

const ObservationMemory = preload("res://scripts/perception/observation_memory.gd")
const Observation = preload("res://scripts/perception/observation.gd")
const SensorSystem = preload("res://scripts/perception/sensor_system.gd")
const SpeciesProfile = preload("res://scripts/core/species_profile.gd")

const PROFILE_PATH := "res://data/species/phidippus_audax_prototype.json"
const HZ := 60.0
const SCREEN_AT := Vector3(0.0, 0.0, -4.0)
const SCREEN_SIZE := Vector3(1.0, 4.0, 0.1)
const FAR_Z := -8.0
const BALL_RADIUS := 0.25


## The observer the sensor reads: its eye is its origin and it looks along its -Z.
class Eye extends Node3D:
	func get_eye_position() -> Vector3:
		return global_position

	func get_gaze_direction() -> Vector3:
		return -global_transform.basis.z

	func get_visual_up() -> Vector3:
		return Vector3.UP

	func get_heading_vector() -> Vector3:
		return -global_transform.basis.z


## A thing the sensor can sense: a ball of `radius` at its position, moving at `velocity` (the rig moves it, one tick at a time).
class Ball extends Node3D:
	var id: String = "ball"
	var radius: float = 0.25
	var velocity: Vector3 = Vector3.ZERO
	var max_category: StringName = &"fly_like_prey"
	var enabled: bool = true

	func _ready() -> void:
		add_to_group(&"perceivable")

	func get_percept() -> Dictionary:
		if not enabled:
			return {}
		return {"id": id, "position": global_position, "radius": radius, "velocity": velocity, "max_category": max_category}


var eye_node: Node3D
var memory: ObservationMemory
var sensor: Node
var ended: Array[String] = []   # "track:reason", as the memory announced them
var balls: Array[Node3D] = []


func after_each() -> void:
	memory = null   # the memory holds a callable of this test: let go of it so the two do not keep each other alive
	sensor = null
	eye_node = null
	balls.clear()


## Builds the rig: the eye, the sensor and the memory (and clears any earlier rig first). Walls are added separately.
func rig() -> void:
	clear_rig()
	ended.clear()
	eye_node = Eye.new()
	sandbox.add_child(eye_node)
	memory = ObservationMemory.new()
	memory.contact_ended.connect(func(c: ObservationMemory.Contact, why: String) -> void: ended.append("%s:%s" % [c.track_id, why]))
	sensor = SensorSystem.new()
	sensor.observer = eye_node
	sensor.memory = memory
	sensor.configure_from(SpeciesProfile.load_file(PROFILE_PATH))
	sandbox.add_child(sensor)


func clear_rig() -> void:
	for n in sandbox.get_children():
		if n is Eye or n is Ball or n is StaticBody3D or n == sensor:
			n.free()
	balls.clear()
	sensor = null
	memory = null


## A wall of `size` centred at `centre`, in the layer the sensor looks through (WORLD). `on` false leaves it out of the world for now.
func add_wall(centre: Vector3, size: Vector3, on: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 if on else 0
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = centre
	sandbox.add_child(body)
	return body


func set_wall(body: StaticBody3D, on: bool) -> void:
	body.collision_layer = 1 if on else 0


func add_screen(on: bool = true) -> StaticBody3D:
	return add_wall(SCREEN_AT, SCREEN_SIZE, on)


func add_ball(id: String, at: Vector3, radius: float = BALL_RADIUS) -> Node3D:
	var b := Ball.new()
	b.id = id
	b.radius = radius
	b.position = at
	sandbox.add_child(b)
	balls.append(b)
	return b


## Runs `count` physics ticks, moving each ball by its velocity before the sensor reads it. Standing still is a velocity of zero.
func run(count: int) -> void:
	for i in count:
		for b: Node3D in balls:
			if is_instance_valid(b) and b.enabled:
				b.position += b.velocity / HZ
		await physics_frames(1)


## The first thing of the world between two points, {} when there is nothing.
func first_hit(from: Vector3, to: Vector3) -> Dictionary:
	return eye_node.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


## The contact the sensor last filed a ball under, null when it has none.
func contact_of_ball(ball: Node3D) -> ObservationMemory.Contact:
	var id: String = sensor.track_id_for(ball.id)
	return null if id == "" else memory.get_contact(id)


## What a player could be shown of the memory: each contact's category, state, place and bearing, without any id of the world.
func digest() -> Array:
	var out: Array = []
	for c: ObservationMemory.Contact in memory.contacts():
		var d: Dictionary = c.to_dict()
		d.erase("target_id")
		d["reacquisitions"] = c.reacquisitions
		d["cue_count"] = c.cue_count
		d["cue_direction"] = c.cue_direction
		d["size_wu"] = c.size_wu
		d["speed_wu_s"] = c.speed_wu_s
		out.append(d)
	return out
