extends "res://tests/world_test_case.gd"
## Helpers for the jump tests: surface points to aim at, planning through the spider's own planner,
## settling a spider after a teleport, and recording states.

const SupportMath = preload("res://scripts/movement/support_math.gd")
const JumpPlan = preload("res://scripts/movement/jump_plan.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")


## First surface a ray meets, as a planner target: {"point", "normal", "collider"}; {} when none.
func ray_target(from: Vector3, to: Vector3) -> Dictionary:
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD))
	if hit.is_empty():
		return {}
	return {"point": hit["position"], "normal": hit["normal"], "collider": hit["collider"]}


## The top surface under (x, z), found from above.
func top_target(x: float, z: float) -> Dictionary:
	return ray_target(Vector3(x, 30.0, z), Vector3(x, -5.0, z))


## Waits until the spider is ATTACHED with support (after a spawn, a teleport or a landing).
func settle(spider: Node3D, max_ticks: int = 90) -> bool:
	return await wait_until(func() -> bool: return spider.state == spider.State.ATTACHED and spider.support.is_valid(), max_ticks)


## Records every state change of a spider as a list of names, in order.
func record_states(spider: Node3D) -> Array[String]:
	var states: Array[String] = []
	spider.state_changed.connect(func(_old: int, new_state: int) -> void: states.append(spider.State.keys()[new_state]))
	return states


## A spider standing on the floor at (x, z), heading in degrees (0 faces -Z, -90 faces +X).
func floor_pose(x: float, z: float, heading_deg: float = 0.0) -> Transform3D:
	return floor_spawn(x, z, heading_deg)
