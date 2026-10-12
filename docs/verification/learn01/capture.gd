extends SceneTree
## LEARN-01 stills: the note when a page opens, and the notebook open at a page. Uses its own Settings with autosave off, so neither the
## player's settings nor their notebook are touched. Run: godot --path . --script res://docs/verification/learn01/capture.gd
const OUT := "res://docs/verification/learn01/"
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
	world.spawn_override = Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-16.5, 0.31, 6.0))
	root.add_child(world)
	for i in 40:
		await physics_frame
	world.notebook.notice("jump")
	await shot("notebook_new_page_note")
	world.notebook.notice("eye_view")
	world.notebook.notice("felt")
	world.notebook_panel.open("dragline")
	await shot("notebook_open")
	quit()
