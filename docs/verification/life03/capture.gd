extends SceneTree
## LIFE round 3 stills: ready to moult, moulting in the crack, and the pale, soft spider beside its old skin. Own Settings, autosave off.
## Run: godot --path . --script res://docs/verification/life03/capture.gd
const OUT := "res://docs/verification/life03/"
var world: Node3D


func _initialize() -> void:
	call_deferred("run")


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("CAPTURE ", name)


func run() -> void:
	root.size = Vector2i(1280, 720)
	var prefs = load("res://scripts/presentation/settings.gd").new()
	prefs.autosave = false
	root.add_child(prefs)
	world = load("res://scenes/main.tscn").instantiate()
	world.settings = prefs
	world.interactive = true
	world.use_windowsill = true
	world.prey_count = 0
	world.prey_seed = 4242
	world.spawn_override = Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-25.0, 0.31, 6.0))
	root.add_child(world)
	for i in 40:
		await physics_frame
	world.prey.ensure_ready()
	for i in 5:
		await physics_frame
	var loop: Node = world.habitat_loop
	loop.on_food(1.0)
	for i in 3:
		await physics_frame
	await shot("ready_to_moult")
	loop.set_physics_process(false)
	loop.step(1.0 / 60.0, true, false)
	loop.set_physics_process(true)
	for i in 120:
		await physics_frame
	await shot("moulting")
	for i in 900:
		await physics_frame
		if not loop.growth.is_moulting():
			break
	for i in 20:
		await physics_frame
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = world.spider.global_position + Vector3(1.4, 0.9, 1.2)
	cam.look_at(world.spider.global_position + Vector3(-0.2, -0.05, 0))
	cam.current = true
	await shot("soft_after_moult_with_old_skin")
	quit()
