extends SceneTree
## T13a stills: the spider-eye view on the windowsill with a fly moving in the soft surround (the motion shimmer), the same view in grey,
## and the level horizon on a wall. Run: godot --path . --script res://docs/verification/t13a/capture.gd (a window is needed).
## Uses its own Settings with autosave off, so the player's settings are untouched.
const OUT := "res://docs/verification/t13a/"
var world: Node3D
var prefs: Node


func _initialize() -> void:
	call_deferred("run")


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("CAPTURE ", name)


func make_world(spawn: Transform3D) -> void:
	if world != null:
		world.queue_free()
		await process_frame
	world = load("res://scenes/main.tscn").instantiate()
	world.settings = prefs
	world.interactive = true
	world.use_windowsill = true
	world.prey_count = 0
	world.prey_seed = 4242
	world.spawn_override = spawn
	root.add_child(world)
	await ticks(30)


func run() -> void:
	root.size = Vector2i(1280, 720)
	prefs = load("res://scripts/presentation/settings.gd").new()
	prefs.autosave = false
	root.add_child(prefs)
	prefs.set_value("eye_view", true)
	# The fly to the spider's left, out of the sharp fields; the spider faces +X along the sill.
	await make_world(Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0 + 32.0)), Vector3(-17.5, 0.31, 6.0)))
	world.prey.ensure_ready()
	var f = world.prey.spawn_fly("sill_first_hunt", 1)
	world.prey.stimulus_enabled = false
	await ticks(20)
	f.mind._begin_flee(f._now, "capture still")
	var flying_at := -1
	for i in 120:
		await physics_frame
		if f.is_flying() and flying_at < 0:
			flying_at = i
		if flying_at >= 0 and i - flying_at >= 10 and not world.eye_overlay.movers.is_empty():
			break
	print("flying ", f.is_flying(), " movers ", world.eye_overlay.movers)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.eye_overlay.flicker = 1.0
	world.eye_overlay.refresh()
	await shot("eye_motion_shimmer")
	prefs.set_value("eye_colour_free", true)
	world.eye_overlay.refresh()
	await shot("eye_grey")
	prefs.set_value("eye_colour_free", false)
	world.process_mode = Node.PROCESS_MODE_INHERIT
	# The level horizon: the spider walks onto the planter's side, then looks along it, with and without the switch.
	await make_world(Transform3D(Basis.IDENTITY, Vector3(10.0, 0.31, 3.5)))
	world.controller.stick_override = Vector2(0.0, -1.0)
	for i in 600:
		await physics_frame
		if world.spider.get_support_normal().dot(Vector3.UP) < 0.3 and world.spider.global_position.y > 1.6:
			break
	world.controller.stick_override = null
	await ticks(40)
	var rig = world.camera_rig
	var n: Vector3 = world.spider.get_support_normal()
	print("on wall normal ", n)
	rig.gaze = (n.cross(Vector3.UP).normalized() * 0.94 - n * 0.34).normalized()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	rig._place_eye(1.0)
	await shot("eye_wall_rolls_with_body")
	prefs.set_value("eye_level_horizon", true)
	rig._place_eye(1.0)
	await shot("eye_wall_level_horizon")
	quit()
