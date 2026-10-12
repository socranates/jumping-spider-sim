extends SceneTree
## Letting down on a line (Nathan, 2026-10-12): stills from the middle leaf, with the game's own camera. The spider sets off for the
## edge, hangs below the leaf, lowers, and stands on the floor with the line behind it. A trace of each tick goes to trace.txt.
## Own Settings, autosave off. Run: godot --path . --script res://docs/verification/drop/capture.gd
const OUT := "res://docs/verification/drop/"
var world: Node3D
var trace := PackedStringArray()


func _initialize() -> void:
	call_deferred("run")


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("CAPTURE ", name)


func tick(n: int, label: String) -> void:
	var s: Node3D = world.spider
	for i in n:
		await physics_frame
		trace.append("%s %s pos=(%.2f, %.2f, %.2f) surface=%s line=%s rest=%.2f" % [label, s.get_state_name(), s.global_position.x,
			s.global_position.y, s.global_position.z, s.support.surface_id, s.tether.mode_name(), s.tether.rest_length])


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
	world.spawn_override = Transform3D(Basis(Vector3.UP, deg_to_rad(180.0)), Vector3(-1.0, 4.51, 0.0))
	root.add_child(world)
	for i in 40:
		await physics_frame
	world.prey.ensure_ready()
	world.spider.line_event.connect(func(kind: String, detail: String) -> void: trace.append("EVENT %s %s" % [kind, detail]))
	await tick(5, "start")
	world.tether_controller.drop_pressed()
	await tick(12, "walk")
	await shot("1_to_the_edge")
	await tick(60, "over")
	await shot("2_hanging_below_the_leaf")
	world.tether_controller.drop_override = true
	await tick(80, "lower")
	await shot("3_lowering")
	for i in 600:
		await tick(1, "lower")
		if world.spider.state == world.spider.State.ATTACHED:
			break
	world.tether_controller.drop_override = null
	await tick(20, "down")
	await shot("4_on_the_floor_line_behind")
	var f := FileAccess.open(OUT + "trace.txt", FileAccess.WRITE)
	f.store_string("\n".join(trace) + "\n")
	quit()
