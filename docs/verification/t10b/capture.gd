extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var prefs = load("res://scripts/presentation/settings.gd").new()
	prefs.autosave = false
	root.add_child(prefs)
	prefs.set_value("eye_view", true)
	var world = load("res://scenes/main.tscn").instantiate()
	world.settings = prefs
	world.interactive = true
	world.use_windowsill = true
	world.prey_count = 3
	world.spawn_override = Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-25, 0.31, 6))
	root.add_child(world)
	for i in 20:
		await physics_frame
	world.camera_rig.require_captured_mouse = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for phase in [0.0, 0.4, 2.0]:
		world.eye_overlay.scan_time = phase
		world.eye_overlay.notice_left = 5.0
		world.eye_overlay.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		var filename := "res://docs/verification/t10b/scan-%s.png" % str(phase).replace(".", "-")
		root.get_texture().get_image().save_png(filename)
		print("Captured ", filename)
	quit()
