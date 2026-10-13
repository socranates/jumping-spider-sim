extends "res://tests/test_case.gd"
## Base for integration tests: builds the real main scene (lab, spider, camera rig) without
## input, pause menu or overlay, using an isolated Settings instance so the player's saved
## settings never change a test.

const MainScene = preload("res://scenes/main.tscn")
const SettingsScript = preload("res://scripts/presentation/settings.gd")
const TEST_SAVE_DIR := "user://jss_test_saves"

var settings: Node
var world: Node3D
## Flies the next world keeps (chunk 7B). The main scene ships with some; every test world starts with none unless the test asks.
var prey_count: int = 0
var prey_seed: int = 0
## Whether the next world replaces a lost fly (off unless the test asks).
var prey_replenish: bool = false
## T09b: whether a caught fly struggles in the next world (off unless the test asks).
var prey_struggle: bool = false
## Existing fixtures intentionally keep the lab; habitat tests opt in.
var use_windowsill: bool = false
## LIFE round 4: whether the mud dauber comes by itself in the next world (off unless the test asks; force_visit brings it anyway).
var wasp_enabled: bool = false
## LIFE round 5: the next world's mode and rules, and whether the start menu opens over it.
var world_mode: String = "main"
var world_rules: String = "standard"
var show_start_menu: bool = false


func before_each() -> void:
	prey_count = 0
	prey_seed = 0
	prey_replenish = false
	prey_struggle = false
	use_windowsill = false
	wasp_enabled = false
	world_mode = "main"
	world_rules = "standard"
	show_start_menu = false
	settings = SettingsScript.new()
	settings.autosave = false
	settings.config_path = "user://jss_test_never_written.cfg"
	sandbox.add_child(settings)


## Adds the world. spawn is an optional Transform3D for the spider origin. Interactive worlds
## also get the player controller, pause menu and debug overlay.
func spawn_world(spawn: Variant = null, interactive: bool = false) -> Node3D:
	world = MainScene.instantiate()
	world.use_windowsill = use_windowsill
	world.interactive = interactive
	world.settings = settings
	world.spawn_override = spawn
	world.prey_count = prey_count
	world.prey_seed = prey_seed
	world.prey_replenish = prey_replenish
	world.prey_struggle = prey_struggle
	world.wasp_enabled = wasp_enabled
	world.mode = world_mode
	world.rules = world_rules
	world.show_start_menu = show_start_menu
	# T09: an interactive test world keeps checkpoints in a test folder, never the player's saves (a non-interactive one keeps them in memory).
	world.checkpoint_dir = TEST_SAVE_DIR if interactive else ""
	sandbox.add_child(world)
	return world


## Spider origin transform: standing on the floor at (x, z) with the given heading in degrees
## (0 faces -Z, -90 faces +X, 180 faces +Z).
func floor_spawn(x: float, z: float, heading_deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(heading_deg)), Vector3(x, 0.31, z))


## Geometric truth, independent of the physics server (which cannot see bodies added this
## frame): true when a sphere at the point overlaps none of the lab's boxes. Slightly
## conservative at box corners.
func point_is_clear(point: Vector3, radius: float = 0.05) -> bool:
	var lab: Node3D = world.lab
	for piece_name: String in lab.get_piece_names():
		var body: StaticBody3D = lab.get_piece(piece_name)
		var box := (body.get_node("Shape") as CollisionShape3D).shape as BoxShape3D
		var local := body.global_transform.affine_inverse() * point
		var half := box.size * 0.5 + Vector3.ONE * radius
		if absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z:
			return false
	return true


## The same question asked of the physics server; only valid once a physics tick has run.
func point_is_clear_in_physics(point: Vector3, radius: float = 0.05) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, point)
	params.collision_mask = 1
	return world.get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func in_lab_bounds(point: Vector3) -> bool:
	return absf(point.x) < 30.0 and absf(point.z) < 17.5 and point.y > 0.0 and point.y < 12.0
