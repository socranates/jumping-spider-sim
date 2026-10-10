extends "res://tests/jump_test_case.gd"
## Helpers for the perception tests (chunk 6B): the stage in the lab's north-west corner (A-010), a spider standing on its
## ledge, and the labelled test marker that walks behind the screen. Everything the tests do to the marker goes through its
## fixture calls (hold_at, release, set_enabled); what the spider knows comes only from the memory.

const Observation = preload("res://scripts/perception/observation.gd")
const ObservationMemory = preload("res://scripts/perception/observation_memory.gd")
const PerceptionMath = preload("res://scripts/perception/perception_math.gd")

const TARGET_ID := "test_target"
## Stage places, all on the path's line (z = -7.9, y = 1.4). The spider on the ledge's middle looks at them from
## (-24.5, 2.39, -2.88): WEST_VISIBLE is in plain view 35 degrees left of north, EAST_VISIBLE the same to the right, and
## BEHIND_SCREEN is hidden by the screen (it is dead ahead, 3 WU of wall in the way).
const WEST_VISIBLE := Vector3(-28.0, 1.4, -7.9)
const EAST_VISIBLE := Vector3(-21.0, 1.4, -7.9)
const BEHIND_SCREEN := Vector3(-24.5, 1.4, -7.9)
## A place the spider cannot sense at all while it faces north: behind it, in the 60 degree wedge the field leaves out.
const BEHIND_SPIDER := Vector3(-24.5, 1.4, 6.0)


## Where the spider stands on the ledge, heading in degrees (0 faces north, toward the stage; positive turns left).
func ledge_pose(heading_deg: float = 0.0, x: float = -24.5, z: float = -2.7) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(heading_deg)), Vector3(x, 2.31, z))


## The heading, in degrees, that makes a spider on the ledge face `p`.
func heading_toward(p: Vector3, from: Vector3 = Vector3(-24.5, 2.39, -2.88)) -> float:
	var d := p - from
	return rad_to_deg(atan2(-d.x, -d.z))


## The stage world: the spider settled on the ledge, the sensor able to see the world, the marker held where `hold_target_at`
## says (null: left to walk its path from the start of it). The marker is placed, and `setup` called with it, before the
## first physics tick, so the sensor never sees it anywhere else.
func spawn_stage(interactive: bool = false, heading_deg: float = 0.0, hold_target_at: Variant = null, setup: Callable = Callable()) -> void:
	spawn_world(ledge_pose(heading_deg), interactive)
	if setup.is_valid():
		setup.call(target())
	if hold_target_at is Vector3:
		target().hold_at(hold_target_at)
	await settle(world.spider)
	await wait_until(func() -> bool: return world.sensor.is_world_ready() and world.sensor.tick > 2, 30)


func target() -> Node3D:
	return world.lab.get_test_target()


func mem() -> ObservationMemory:
	return world.memory


## The target's contact in the memory, null while it has never been sensed. It is found under the world id the target has now: a fixture
## may rename the marker while it is hidden (A-027), and who the spider takes it for does not follow the name.
func target_contact() -> ObservationMemory.Contact:
	return contact_of(target())


## The contact the sensor last filed a labelled test target under, null while it has never been sensed.
func contact_of(thing: Node3D) -> ObservationMemory.Contact:
	var id: String = world.sensor.track_id_for(thing.target_id)
	return null if id == "" else world.memory.get_contact(id)


## A second labelled test target for fixtures that need two look-alikes (A-027): the same magenta marker on a rod, named in the scene
## "TestTargetB", with its own world id. Like the first it is a prop for proving the senses, not prey, and only a test makes it. It
## stands at `at` and walks `path` (if one is given) from there.
func add_second_target(id: String = "test_target_b", at: Vector3 = Vector3.ZERO, path: PackedVector3Array = PackedVector3Array()) -> Node3D:
	var marker_script: GDScript = load("res://scripts/habitat/test_target.gd")
	var t: Node3D = marker_script.new()
	t.name = "TestTargetB"
	t.target_id = id
	t.stand_height = target().stand_height
	target().get_parent().add_child(t)
	if path.size() > 1:
		t.path = path
		t.set_path(path)
	else:
		t.hold_at(at)
	return t


## What a player could be shown of the memory (A-027): every contact's category, state, place and bearing, without any id of the world.
func contacts_digest() -> Array:
	var out: Array = []
	for c: ObservationMemory.Contact in world.memory.contacts():
		var d: Dictionary = c.to_dict()
		d.erase("target_id")
		d["reacquisitions"] = c.reacquisitions
		d["cue_count"] = c.cue_count
		d["cue_direction"] = c.cue_direction
		d["size_wu"] = c.size_wu
		d["speed_wu_s"] = c.speed_wu_s
		out.append(d)
	return out


func eye() -> Vector3:
	return world.spider.get_eye_position()


## Unit direction from the spider's eyes to a point.
func toward(p: Vector3) -> Vector3:
	return (p - eye()).normalized()


## The angle, degrees, between the gaze and the direction to a point.
func off_axis_deg(p: Vector3) -> float:
	return rad_to_deg(world.spider.get_gaze_direction().angle_to(toward(p)))


## True when the world stands between the spider's eye and every one of the target's sample points (it is hidden). The allowance is the
## sensor's own (PerceptionMath.sight_tolerance, A-024), so this agrees with what the sensor can see.
func target_is_hidden(thing: Node3D = null) -> bool:
	var t: Node3D = thing if thing != null else target()
	var space := world.get_world_3d().direct_space_state
	var c: Vector3 = t.global_position
	var r: float = t.radius * 0.8
	var d := (c - eye()).normalized()
	var side := d.cross(Vector3.UP).normalized()
	var pts: Array[Vector3] = [c, c + side * r, c - side * r, c + Vector3.UP * r, c - Vector3.UP * r]
	for p in pts:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye(), p, 1))
		var length := eye().distance_to(p)
		if hit.is_empty() or eye().distance_to(hit["position"] as Vector3) >= length - PerceptionMath.sight_tolerance(t.radius, length):
			return false
	return true


## Turns the body toward a world direction with Focus, as the motor sees it (the same call the player controller makes).
func focus_on(dir: Vector3) -> void:
	world.spider.set_focus(true, dir)


func focus_off() -> void:
	world.spider.set_focus(false)


## The heading as an angle about up, degrees (0 faces north, positive turns left).
func heading_deg() -> float:
	return rad_to_deg(world.spider.get_heading())
