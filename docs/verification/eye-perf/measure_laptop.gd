extends SceneTree
## Supplementary Windows screen: frozen 720p view, VSync disabled, 240 frames
## per row, three off/on pairs, 120 warmup frames. No screenshot/readback.
## Full live five-minute comparisons use profile_play.gd --no-screenshots.
const FRAMES := 240
var world: Node3D


func _initialize() -> void:
	call_deferred("run")


func timed(frames: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in frames:
		var t0 := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		out.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	return out


func stats(name: String, ms: PackedFloat64Array) -> void:
	var s := Array(ms)
	s.sort()
	var mean := 0.0
	for v in s:
		mean += float(v)
	mean /= float(s.size())
	print("%s mean %.2f ms  median %.2f ms  p90 %.2f ms" % [name, mean, float(s[s.size() / 2]), float(s[int(s.size() * 0.9)])])


func run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var prefs = load("res://scripts/presentation/settings.gd").new()
	prefs.autosave = false
	root.add_child(prefs)
	prefs.set_value("eye_view", true)
	world = load("res://scenes/main.tscn").instantiate()
	world.settings = prefs
	world.interactive = true
	world.use_windowsill = true
	world.prey_count = 0
	world.prey_seed = 4242
	world.spawn_override = Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(-16.5, 0.31, 6.0))
	root.add_child(world)
	for i in 60:
		await physics_frame
	world.process_mode = Node.PROCESS_MODE_DISABLED   # the same picture every frame
	var rect: Control = world.eye_overlay.get_node("EyeView")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shader-file="):
			rect.material.shader.code = FileAccess.get_file_as_string(arg.trim_prefix("--shader-file="))
	await timed(120)
	for round in 3:
		rect.visible = false
		stats("eye picture off ", await timed(FRAMES))
		rect.visible = true
		stats("eye picture on  ", await timed(FRAMES))
	quit()
