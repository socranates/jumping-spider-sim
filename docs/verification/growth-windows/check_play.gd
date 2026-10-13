extends SceneTree
## Staged native growth/silk check. --profile disables all screenshot readback.
var world: Node3D
var prefs: Node
var profile := false
var phase := "setup"
var rows: Array[String] = ["phase,frame_ms,gpu_ms,hour,stage"]
var last := 0
var recording := false

func _initialize() -> void:
	profile = "--profile" in OS.get_cmdline_user_args()
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func spawn(pose: Transform3D) -> void:
	if is_instance_valid(world):
		world.queue_free()
		await frames(2)
	world = load("res://scenes/main.tscn").instantiate()
	world.settings = prefs
	world.checkpoint_dir = "user://growth_check"
	world.prey_count = 0
	world.prey_seed = 4242
	world.spawn_override = pose
	root.add_child(world)
	world.controller.set_physics_process(false)
	world.camera_rig.require_captured_mouse = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(40)
	world.prey.ensure_ready()
	await frames(5)

func shot(name: String) -> void:
	print("STATE ",name," ",JSON.stringify({"position":world.spider.global_position,"state":world.spider.get_state_name(),
		"surface":world.spider.support.surface_id,"stage":world.habitat_loop.growth.stage,"scale":world.spider.get_node("Body").scale,
		"caption":world.habitat_loop.caption(),"skins":world.habitat_loop.growth.exuviae.size()}))
	if profile:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://"+name+".png")

func _process(_dt: float) -> bool:
	var now := Time.get_ticks_usec()
	if recording and profile:
		rows.append("%s,%.4f,%.4f,%.4f,%d" % [phase,float(now-last)/1000.0,
			RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),world.habitat_loop.clock.hour,world.habitat_loop.growth.stage])
	last = now
	return false

func run() -> void:
	root.size = Vector2i(1280,720)
	prefs = load("res://scripts/presentation/settings.gd").new()
	prefs.autosave = false
	root.add_child(prefs)
	prefs.set_value("struggle_auto",true)
	await spawn(Transform3D(Basis(Vector3.UP,-PI/2),Vector3(-25,0.31,6)))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await frames(120)
	await shot("stage0")
	for stage in 3:
		phase = "feeding_%d" % stage
		world.habitat_loop.stop_rest()
		# Stage a fly within capture reach; use the actual capture log, struggle
		# assist and feeding controller. Reset reserve to make room for each meal.
		for meal in 3:
			world.needs.configure({"energy":0.1})
			var fly: Node3D = world.prey.spawn_fly("sill_first_hunt",4243+stage*3+meal)
			fly.fixture_hold=true
			fly.global_position=world.spider.global_position+world.spider.get_heading_vector()*0.3
			fly.prev_position=fly.global_position
			world.prey.resolve_captures()
			if world.prey.held==null:
				push_error("Staged capture failed")
				quit(1)
				return
			for tick in 900:
				await physics_frame
				if world.prey.held==null:
					break
			print("MEAL ",stage,"/",meal," consumed=",fly.state==fly.State.CONSUMED," granted=",world.needs.granted_from(fly.capture_event_id))
		if not world.habitat_loop.growth.ready:
			push_error("Meals did not make the spider ready")
			quit(1)
			return
		await shot("ready%d" % stage)
		print("REST_ACCEPTED ",world.habitat_loop.request_rest())
		phase = "moult_%d" % stage
		prefs.set_value("eye_view",stage==1)
		recording = true
		await frames(120)
		await shot("moulting%d" % stage)
		for tick in 900:
			await physics_frame
			if not world.habitat_loop.growth.is_moulting():
				break
		recording = false
		prefs.set_value("eye_view",false)
		await frames(30)
		await shot("stage%d_soft" % (stage+1))
		print("CHECKPOINT_STAGE ",world.last_checkpoint.get("growth",{}).get("stage",-1))
	# Matched framing/condition for the four artistic stage sizes.
	world.habitat_loop.stop_rest()
	world.habitat_loop.clock.hour=13.0
	world.spider.teleport_to(Transform3D(Basis(Vector3.UP,-PI/2),Vector3(-16.5,0.31,6)))
	world.needs.configure({"energy":0.55})
	var body: Node3D = world.spider.get_node("Body")
	body.set_condition(0.55)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = world.spider.global_position+Vector3(-2.3,1.6,2.8)
	cam.look_at(world.spider.global_position)
	cam.current = true
	for stage in 4:
		world.habitat_loop.growth.stage=stage
		world.habitat_loop.growth.soft_hours_left=0.0
		world.habitat_loop._apply_growth()
		await frames(90)
		await shot("size%d" % stage)
	cam.queue_free()
	await frames(2)
	var poses := [Transform3D(Basis(Vector3.UP,PI),Vector3(-1,4.51,0)),
		Transform3D(Basis(Vector3.RIGHT,Vector3.BACK,Vector3.DOWN),Vector3(-8,6,-12.19)),
		Transform3D(Basis(Vector3.UP,PI),Vector3(10,4.91,0))]
	var names := ["leaf","wall","planter"]
	for origin in 3:
		for returning in [false,true]:
			await spawn(poses[origin])
			world.habitat_loop.growth.stage=3
			world.habitat_loop._apply_growth()
			var label: String = names[origin]+("_return" if returning else "_floor")
			print("DROP_PLAN ",label," ",world.spider.begin_drop())
			var hung := false
			for tick in 240:
				await physics_frame
				if world.spider.state==world.spider.State.HANGING:
					hung=true
					break
			await shot(label+"_hanging")
			if hung:
				for tick in 900:
					if world.spider.is_on_line():
						world.spider.set_reel_intent(1.0 if returning else -1.0)
					await physics_frame
					if world.spider.state==world.spider.State.ATTACHED:
						break
			world.spider.set_reel_intent(0.0)
			await shot(label+"_end")
	if profile:
		var f:=FileAccess.open("user://moult_frames.csv",FileAccess.WRITE)
		f.store_string("\n".join(rows))
		f.close()
	print("CHECK_COMPLETE")
	quit()
