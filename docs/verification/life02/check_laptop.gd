extends SceneTree
## LIFE round 2 graphical checks. Excluded from exports; isolated APPDATA required.
## Default: 8 x 30 s live profile, no screenshots. --visual: separate staged checks.
const HOURS := [8.0, 8.0, 13.0, 13.0, 19.6, 19.6, 23.0, 23.0]
const NAMES := ["morning_orbit", "morning_eye", "midday_orbit", "midday_eye", "dusk_orbit", "dusk_eye", "night_orbit", "night_eye"]
var world: Node3D
var prefs: Node
var started := 0
var last_frame := 0
var phase := -1
var rows: Array[String] = []
var target := Vector3(-10, 0.31, 6)
var finished := false
var visual := false

func _initialize() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	prefs = load("res://scripts/presentation/settings.gd").new()
	prefs.autosave = false
	root.add_child(prefs)
	world = load("res://scenes/main.tscn").instantiate()
	world.settings = prefs
	world.checkpoint_dir = "user://life02_checkpoint"
	world.prey_seed = 4242
	root.add_child(world)
	world.controller.set_physics_process(false)
	world.camera_rig.require_captured_mouse = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for i in 120:
		await process_frame
	if visual:
		await visual_checks()
		return
	started = Time.get_ticks_usec()
	last_frame = started
	rows.append("elapsed_s,phase,frame_ms,process_ms,physics_ms,render_cpu_ms,render_gpu_ms,hour,sun_x,energy")
	print("LIFE02_START ", JSON.stringify({"gpu": RenderingServer.get_video_adapter_name(), "vsync": DisplayServer.window_get_vsync_mode(), "size":root.size}))

func set_phase(n: int) -> void:
	phase = n
	world.habitat_loop.clock.hour = HOURS[n]
	world.habitat_loop.apply_light()
	prefs.set_value("eye_view", n % 2 == 1)
	print("LIFE02_PHASE ", NAMES[n], " ", JSON.stringify({"hour":world.habitat_loop.clock.hour,"sun":world.lab.sun.rotation_degrees}))

func _process(_dt: float) -> bool:
	if started == 0 or finished:
		return false
	var now := Time.get_ticks_usec()
	var elapsed := float(now - started) / 1000000.0
	if elapsed >= 240.0:
		finished = true
		var f := FileAccess.open("user://life02_frames.csv", FileAccess.WRITE)
		f.store_string("\n".join(rows))
		f.close()
		print("LIFE02_END ", JSON.stringify({"seconds":elapsed,"frames":rows.size()-1}))
		quit()
		return false
	var next := mini(7, int(elapsed / 30.0))
	if next != phase:
		set_phase(next)
	var vp := root.get_viewport_rid()
	rows.append("%.6f,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.6f,%.6f,%.6f" % [elapsed,phase,float(now-last_frame)/1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS)*1000,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,
		RenderingServer.viewport_get_measured_render_time_cpu(vp),RenderingServer.viewport_get_measured_render_time_gpu(vp),
		world.habitat_loop.clock.hour,world.lab.sun.rotation_degrees.x,world.needs.energy])
	last_frame = now
	return false

func _physics_process(_dt: float) -> bool:
	if started == 0 or finished:
		return false
	var d: Vector3 = target - world.spider.global_position
	d.y = 0
	if d.length() < 0.4:
		target.x = -22.0 if target.x > -15.0 else -10.0
	world.spider.set_intent(d.normalized(), false)
	return false

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://"+name+".png")
	var body: Node = world.spider.get_node("Body")
	print("LIFE02_SHOT ", name, " ", JSON.stringify({"day":world.habitat_loop.clock.day,"hour":world.habitat_loop.clock.hour,
		"asleep":world.habitat_loop.asleep,"energy":world.needs.energy,"condition":body.shown_condition,"abdomen_scale":body.get_node("Abdomen").scale,
		"sun":world.lab.sun.rotation_degrees,"caption":world.habitat_loop.caption()}))

func visual_checks() -> void:
	world.spider.teleport_to(Transform3D(Basis(Vector3.UP, -PI/2), Vector3(-16.5,0.31,6)))
	for n in 8:
		set_phase(n)
		await create_timer(3.0).timeout
		await shot(NAMES[n])
	prefs.set_value("eye_view", false)
	world.spider.teleport_to(Transform3D(Basis(Vector3.UP, -PI/2), Vector3(-25,0.31,6)))
	world.habitat_loop.clock.hour = 19.0
	await create_timer(1.0).timeout
	var ok: bool = world.habitat_loop.request_rest()
	print("LIFE02_REST_REQUEST ", ok)
	await create_timer(2.0).timeout
	await shot("sleeping")
	await create_timer(8.0).timeout
	await shot("morning_after_sleep")
	print("LIFE02_WAKE ", JSON.stringify({"day":world.habitat_loop.clock.day,"asleep":world.habitat_loop.asleep,
		"checkpoint_ok":world.habitat_loop.checkpoint_result.get("ok",false),"checkpoint_day":world.last_checkpoint.get("life",{}).get("day",-1)}))
	world.habitat_loop.stop_rest()
	world.spider.teleport_to(Transform3D(Basis(Vector3.UP, -PI/2), Vector3(-16.5,0.31,6)))
	world.habitat_loop.clock.hour = 13.0
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = world.spider.global_position + Vector3(-1.2,0.9,1.6)
	cam.look_at(world.spider.global_position + Vector3(0,0.1,0))
	cam.current = true
	# Use the real needs notification and presentation smoothing, not direct body scales.
	world.needs.add_hours(24.0, false)
	await create_timer(4.0).timeout
	await shot("abdomen_hungry")
	world.needs.grant_energy(0.90, "life02_fixture_meal")
	await create_timer(0.5).timeout
	await shot("abdomen_filling")
	await create_timer(4.0).timeout
	await shot("abdomen_fed")
	quit()
