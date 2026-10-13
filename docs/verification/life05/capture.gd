extends SceneTree
## LIFE round 5 stills: the start menu, starving warnings, the end of a life with its summary, and another spider going on.
## Own Settings and progress, autosave off. Run: godot --path . --script res://docs/verification/life05/capture.gd
const OUT := "res://docs/verification/life05/"
var world: Node3D


func _initialize() -> void:
	call_deferred("run")


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("CAPTURE ", name)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func pass_hours(h: float) -> void:
	world.needs.add_hours(h, false)
	world.needs.advance(0.25, false)
	world.needs.advance(0.25, false)
	await frames(3)


func run() -> void:
	root.size = Vector2i(1280, 720)
	var prefs = load("res://scripts/presentation/settings.gd").new()
	prefs.autosave = false
	root.add_child(prefs)
	world = load("res://scenes/main.tscn").instantiate()
	world.settings = prefs
	world.interactive = true
	world.use_windowsill = true
	world.wasp_enabled = false
	world.prey_count = 2
	world.prey_seed = 4242
	world.checkpoint_dir = "user://jss_capture_saves"
	world.show_start_menu = true
	root.add_child(world)
	await frames(40)
	await shot("1_start_menu")
	world.start_menu.new_life(false)
	await frames(30)
	world.needs.configure({"energy": 0.01})
	await pass_hours(2.0)
	await shot("2_starving")
	await pass_hours(25.0)
	await shot("3_weak_from_hunger")
	world.feeding.meals_finished = 3
	world.habitat_loop.clock.day = 4
	world.habitat_loop.growth.stage = 1
	await pass_hours(30.0)
	for i in 220:
		await process_frame
	await shot("4_the_end_and_its_summary")
	world = world.caught_panel.go_on_as_another()
	await frames(60)
	print("CAPTION ", world.habitat_loop.caption().replace("\n", " | "))
	await shot("5_another_spider")
	quit()
