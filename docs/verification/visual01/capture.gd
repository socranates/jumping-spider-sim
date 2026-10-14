extends SceneTree
## VISUAL-01 stills: the spider close up (side, front three-quarter, above), standing and mid-walk, and the game's own camera on the sill.
## Own Settings, autosave off. Run: godot --path . --script res://docs/verification/visual01/capture.gd -- --tag=after
const OUT := "res://docs/verification/visual01/"
var world: Node3D
var tag := "after"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	call_deferred("run")


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + tag + "_" + name + ".png")
	print("CAPTURE ", tag, "_", name)


func close(cam: Camera3D, offset: Vector3) -> void:
	var s: Node3D = world.spider
	var b := s.global_basis
	cam.global_position = s.global_position + b * offset
	cam.look_at(s.global_position + b.y * 0.02, b.y)
	cam.current = true


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
	world.spawn_override = Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-8.0, 0.31, 4.0))
	root.add_child(world)
	for i in 60:
		await physics_frame
	await shot("game_camera")
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.02
	root.add_child(cam)
	close(cam, Vector3(1.9, 0.55, -0.4))
	await shot("side")
	close(cam, Vector3(-1.1, 0.5, -1.5))
	await shot("front_three_quarter")
	close(cam, Vector3(0.6, 2.0, 0.9))
	await shot("above")
	world.spider.set_intent(Vector3.RIGHT, false)
	for i in 21:
		await physics_frame
	close(cam, Vector3(1.9, 0.55, -0.4))
	await shot("walking_side")
	world.spider.set_intent(Vector3.ZERO, false)
	for i in 40:
		await physics_frame
	cam.current = false
	await shot("game_camera_after_walk")
	cam.current = false
	prefs.set_value("eye_view", true)
	for i in 10:
		await physics_frame
	await shot("eye_view")
	prefs.set_value("eye_view", false)
	for i in 10:
		await physics_frame
	var sill := _find_sill(world)
	if sill != null:
		sill.set_daylight(0.3, 18.5)
		await shot("game_camera_evening")
		cam.current = true
		close(cam, Vector3(-1.1, 0.5, -1.5))
		await shot("front_three_quarter_evening")
	quit()


func _find_sill(n: Node) -> Node:
	if n.has_method("set_daylight") and n.has_method("get_play_bounds"):
		return n
	for c in n.get_children():
		var f := _find_sill(c)
		if f != null:
			return f
	return null
