extends "res://tests/perception_test_case.gd"
## Helpers for the prey tests (chunk 7B): a world with the prey director ready, flies put on named perches, and a spider that is walked
## or stalked across the floor by its movement intent (the same intent the player's stick gives it). The fly never sees any of this:
## what it reacts to is its own evidence of the spider's body (A-028); the tests read the fly's state, awareness and trace.

const Fly = preload("res://scripts/prey/fly.gd")
const PerchGraph = preload("res://scripts/prey/perch_graph.gd")
const FlySenses = preload("res://scripts/prey/fly_senses.gd")
const PreyProfile = preload("res://scripts/prey/prey_profile.gd")

const PREY_SEED := 4242
const WALK := false
const STALK := true


## A world with the spider at `pose`, settled, the senses and the director able to see the world, and `population` flies (0 for none) on the
## default start perches. The prey seed is fixed, so a test run is repeatable.
func spawn_prey_world(pose: Variant = null, population: int = 0, seed_value: int = PREY_SEED, interactive: bool = false) -> void:
	prey_count = population
	prey_seed = seed_value
	spawn_world(pose, interactive)
	await settle(world.spider)
	await wait_until(func() -> bool: return world.prey.is_world_ready() and world.sensor.is_world_ready() and world.prey.tick > 1, 40)
	world.prey.ensure_ready()


func director() -> Node3D:
	return world.prey


## A fly on a named perch. `hold` keeps it from fidgeting, grooming and deciding (it still senses).
func add_fly(perch_id: String, fly_seed: int = -1, hold: bool = false) -> Node3D:
	var f: Node3D = world.prey.spawn_fly(perch_id, fly_seed)
	if f != null:
		f.fixture_hold = hold
	return f


func perch(perch_id: String) -> PerchGraph.Perch:
	return world.prey.graph.get_perch(perch_id)


## The spider's body centre on the floor at (x, z) facing `heading_deg` (see floor_spawn), teleported there and settled.
func put_spider(x: float, z: float, heading_deg: float) -> void:
	world.spider.teleport_to(floor_spawn(x, z, heading_deg))
	await settle(world.spider)


## Walks (or stalks) the spider along the floor toward `goal` until it is within `stop_within` of it (flat distance) or `max_ticks` pass.
## `on_tick` is called after every tick. Returns the ticks used. The spider is left standing.
func walk_toward(goal: Vector3, stalk: bool, stop_within: float, max_ticks: int, on_tick: Callable = Callable(), stop_when: Callable = Callable()) -> int:
	var spider: Node3D = world.spider
	var used := 0
	for i in max_ticks:
		var flat := goal - spider.global_position
		flat.y = 0.0
		if flat.length() <= stop_within or (stop_when.is_valid() and stop_when.call()):
			break
		spider.set_intent(flat.normalized(), stalk)
		await physics_frames(1)
		used += 1
		if on_tick.is_valid():
			on_tick.call()
	spider.set_intent(Vector3.ZERO, false)
	return used


## Runs `count` ticks, calling `on_tick` after each.
func run_ticks(count: int, on_tick: Callable = Callable()) -> void:
	for i in count:
		await physics_frames(1)
		if on_tick.is_valid():
			on_tick.call()


func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Prepares and commits a jump from where the spider stands to the floor point (x, z) and waits for the flight to end (and a few ticks more).
## False when the spider has no plan for it.
func strike_at(x: float, z: float) -> bool:
	var spider: Node3D = world.spider
	var plan = spider.plan_jump(top_target(x, z))
	if not check(plan.is_valid(), "the strike at (%.1f, %.1f) is a plan the spider can fly (%s)" % [x, z, plan.reason]):
		return false
	check(spider.begin_prepare(), "preparing starts")
	await physics_frames(2)
	check(spider.commit_jump(plan), "the plan is committed")
	await wait_until(func() -> bool: return not spider.last_jump.is_empty() and str(spider.last_jump["outcome"]) != "", 120)
	await physics_frames(6)
	return true


## A world with the spider standing 3.5 WU south-west of nothing in particular, and one held fly that it has caught by a strike. Returns the fly.
func catch_a_fly() -> Node3D:
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0))
	var f := add_fly("floor_east_open", 1, true)
	await strike_at(4.0, 11.0)
	return f
