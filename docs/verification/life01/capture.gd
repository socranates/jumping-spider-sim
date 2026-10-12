extends SceneTree
## LIFE round 1 stills: the windowsill at four hours of the day, and the spider thin and well fed. Own Settings, autosave off; nothing of
## the player's is touched. Run: godot --path . --script res://docs/verification/life01/capture.gd
const OUT := "res://docs/verification/life01/"
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
	var loop: Node = world.habitat_loop
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for h in [[8.0, "sill_0800_morning"], [13.0, "sill_1300_midday"], [19.6, "sill_1936_dusk"], [23.0, "sill_2300_night"]]:
		loop.clock.hour = float(h[0])
		loop.apply_light()
		loop._label.text = loop.caption()
		await shot(str(h[1]))
	loop.clock.hour = 13.0
	loop.apply_light()
	var body: Node = world.spider.get_node("Body")
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = world.spider.global_position + Vector3(-1.2, 0.9, 1.6)
	cam.look_at(world.spider.global_position + Vector3(0, 0.1, 0))
	cam.current = true
	for c in [[0.05, "spider_hungry"], [0.95, "spider_well_fed"]]:
		body.condition = float(c[0])
		body.shown_condition = float(c[0])
		body.get_node("Abdomen").scale = body.abdomen_scale(float(c[0]))
		await shot(str(c[1]))
	quit()
