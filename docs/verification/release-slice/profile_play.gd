extends SceneTree
## Real-time rendered five-minute route; no fixed-fps/headless mode. External
## Run with the editor binary. Release templates ignore this --script entry.
## This developer fixture is excluded from shipping exports.
const SimClock = preload("res://scripts/core/sim_clock.gd")
var world: Node3D
var prefs: Node
var rows: Array[String] = []
var started := 0
var last_frame := 0
var phase := -1
var target := Vector3(-10, 0.31, 6)
var capture: AudioEffectCapture
var audio_peak := 0.0
var hunt_attempts := 0
var hunt_captures := 0
var last_hop := 0.0
var label: Label
var finished := false

func _initialize() -> void:
	if "--licenses-only" in OS.get_cmdline_user_args():
		var notices := FileAccess.open("user://GODOT-LICENSES.txt", FileAccess.WRITE)
		notices.store_string(Engine.get_license_text() + "\n\nThird-party notices:\n" + JSON.stringify(Engine.get_copyright_info(), "  ") + "\n\n" + JSON.stringify(Engine.get_license_info(), "  "))
		notices.close()
		quit()
		return
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	prefs = load("res://scripts/presentation/settings.gd").new()
	prefs.autosave = false
	root.add_child(prefs)
	world = load("res://scenes/main.tscn").instantiate()
	world.settings = prefs
	world.checkpoint_dir = "user://profile_only_checkpoint"
	world.prey_seed = 4242
	root.add_child(world)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shader-file="):
			world.eye_overlay.get_node("EyeView").material.shader.code = FileAccess.get_file_as_string(arg.trim_prefix("--shader-file="))
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(20, 150)
	layer.add_child(label)
	world.controller.set_physics_process(false)
	world.camera_rig.require_captured_mouse = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(0, capture)
	for i in 120:
		await process_frame
	started = Time.get_ticks_usec()
	last_frame = started
	rows.append("elapsed_s,phase,frame_ms,process_ms,physics_ms,render_cpu_ms,render_gpu_ms,draw_calls,objects,static_bytes,flies,state")
	print("PROFILE_START ", JSON.stringify({"size": root.size, "texture": root.get_texture().get_size(), "gpu": RenderingServer.get_video_adapter_name(), "os": OS.get_name(), "vsync": DisplayServer.window_get_vsync_mode(), "seed": 4242}))

func _process(_delta: float) -> bool:
	if started == 0 or finished:
		return false
	var now := Time.get_ticks_usec()
	var elapsed := float(now - started) / 1000000.0
	var next := mini(4, int(elapsed / 60.0))
	if next != phase:
		phase = next
		prefs.set_value("eye_view", phase == 1 or phase == 2)
		SimClock.set_speed(0.25 if phase == 2 or phase == 3 else 1.0)
		print("PROFILE_PHASE ", phase, " at ", elapsed)
		if phase == 4:
			world.spider.teleport_to(Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(-15.5, 0.31, 6)))
			# A reproducible hunt encounter; normal fly senses/flight remain enabled.
			world.prey.spawn_fly("sill_first_hunt", 4243)
		if "--no-screenshots" not in OS.get_cmdline_user_args():
			capture_phase.call_deferred(phase)
	label.text = "REAL-TIME PROFILE / %s / %ds of 300s" % [["orbit route", "eye route", "eye 25%", "orbit 25%", "hunt attempts"][phase], int(elapsed)]
	var vp := root.get_viewport_rid()
	rows.append("%.6f,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%d,%d,%d,%s" % [elapsed, phase,
		float(now - last_frame) / 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000,
		RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC), world.prey.living().size(), world.spider.get_state_name()])
	last_frame = now
	var samples := capture.get_buffer(capture.get_frames_available())
	for sample in samples:
		audio_peak = maxf(audio_peak, maxf(absf(sample.x), absf(sample.y)))
	if elapsed >= 300.0:
		finished = true
		var file := FileAccess.open("user://profile_frames.csv", FileAccess.WRITE)
		file.store_string("\n".join(rows))
		file.close()
		print("PROFILE_END ", JSON.stringify({"seconds": elapsed, "frames": rows.size()-1, "audio_peak": audio_peak, "hunt_attempts": hunt_attempts, "captures_seen": hunt_captures, "struggles_won": world.feeding.struggles_won, "path": ProjectSettings.globalize_path("user://profile_frames.csv")}))
		SimClock.set_speed(1.0)
		quit()
	return false

func _physics_process(_delta: float) -> bool:
	if started == 0 or finished:
		return false
	var spider: Node3D = world.spider
	if phase < 4:
		var d := target - spider.global_position
		d.y = 0.0
		if d.length() < 0.4:
			target.x = -22.0 if target.x > -15.0 else -10.0
		spider.set_intent(d.normalized(), false)
	else:
		var held: Node3D = world.prey.held
		if held != null:
			hunt_captures = 1
			spider.set_intent(Vector3.ZERO, false)
			if world.feeding.struggling and Engine.get_physics_frames() % 8 == 0:
				world.feeding.step(0.0, true, false)
		elif spider.can_prepare():
			var nearest: Node3D = null
			var dist := INF
			for fly in world.prey.living():
				var d := spider.global_position.distance_to(fly.global_position)
				if d < dist and absf(fly.global_position.y - 0.2) < 0.5:
					nearest = fly
					dist = d
			if nearest != null:
				var direction := nearest.global_position - spider.global_position
				direction.y = 0.0
				spider.set_intent(direction.normalized() if dist > 3.0 else Vector3.ZERO, true)
				var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
				if dist <= 3.0 and elapsed - last_hop > 3.0:
					var point: Vector3 = nearest.global_position
					var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP, 1))
					if not hit.is_empty():
						var plan: RefCounted = spider.plan_jump({"point": hit.position, "normal": hit.normal, "collider": hit.collider})
						if plan.is_valid() and spider.commit_jump(plan):
							hunt_attempts += 1
							last_hop = elapsed
	return false

func capture_phase(which: int) -> void:
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://phase-%d.png" % which)
	print("PROFILE_STATE ", JSON.stringify({"phase": which, "spider": world.spider.global_position, "flies": world.prey.living().map(func(f): return str(f.global_position))}))
