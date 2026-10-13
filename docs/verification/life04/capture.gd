extends SceneTree
## LIFE round 4 stills: the mud dauber coming over the frame, searching, looking at the spider, the spider-eye view of it, the catch, and
## the screen that follows. The spider stands in the open on the floor. Own Settings, autosave off.
## Run: godot --path . --script res://docs/verification/life04/capture.gd
const OUT := "res://docs/verification/life04/"
var world: Node3D


func _initialize() -> void:
	call_deferred("run")


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("CAPTURE ", name)


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


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
	world.prey_count = 0
	world.prey_seed = 4242
	world.spawn_override = Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(3.0, 0.31, 6.5))
	root.add_child(world)
	await ticks(40)
	world.prey.ensure_ready()
	world.habitat_loop.clock.day = 2
	world.habitat_loop.clock.hour = 12.0
	var wd: Node = world.wasp_director
	wd.force_visit("floor_middle")
	await ticks(150)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(8.0, 6.0, 14.0)
	cam.look_at(wd.wasp.global_position)
	cam.current = true
	await shot("1_arriving_over_the_frame")
	cam.current = false
	await ticks(260)
	await shot("2_searching_game_camera")
	cam.global_position = wd.wasp.global_position + Vector3(2.2, 0.8, 2.6)
	cam.look_at(wd.wasp.global_position)
	cam.current = true
	await shot("3_wasp_close")
	cam.current = false
	var s: Node3D = world.spider
	var n := 0
	while wd.phase_name() != "inspecting" and n < 900:
		n += 1
		s.set_intent(Vector3.RIGHT * (1.0 if (n / 30) % 2 == 0 else -1.0), false)
		await physics_frame
	s.set_intent(Vector3.ZERO, false)
	await ticks(30)
	await shot("4_it_has_seen_you")
	world.camera_rig.eye_view = true
	await ticks(20)
	await shot("5_spider_eye_view_of_the_wasp")
	world.camera_rig.eye_view = false
	n = 0
	while wd.phase_name() != "carrying" and n < 600:
		n += 1
		await physics_frame
	await ticks(40)
	await shot("6_carried_off")
	n = 0
	while not world.caught_panel.is_showing() and n < 600:
		n += 1
		await physics_frame
	for i in 220:
		await process_frame
	await shot("7_the_screen_after")
	quit()
