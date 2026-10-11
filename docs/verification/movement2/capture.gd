extends SceneTree
const SimClock = preload("res://scripts/core/sim_clock.gd")
var world: Node3D
var camera: Camera3D
var caption: Label
var body: Node3D

func _initialize() -> void:
	call_deferred("run")

func ticks(n: int) -> void:
	for i in n:
		await physics_frame

func shot(label: String, eye: bool = false) -> void:
	world.process_mode = Node.PROCESS_MODE_DISABLED
	caption.text = label + " / 25% speed / Windows Compatibility"
	if not eye:
		camera.current = true
		camera.global_position = body.global_position + Vector3(1.6, 0.9, 1.8)
		camera.look_at(body.global_position + Vector3(0, -0.06, 0))
		camera.reset_physics_interpolation()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/verification/movement2/" + label + ".png")
	print("CAPTURE ", label)
	world.process_mode = Node.PROCESS_MODE_INHERIT

func run() -> void:
	root.size = Vector2i(1000, 700)
	var prefs = load("res://scripts/presentation/settings.gd").new()
	prefs.autosave = false
	root.add_child(prefs)
	world = load("res://scenes/main.tscn").instantiate()
	world.settings = prefs
	world.interactive = true
	world.use_windowsill = true
	world.prey_count = 0
	world.spawn_override = Transform3D(Basis.IDENTITY, Vector3(-12.5, 4.51, -0.5))
	root.add_child(world)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.fov = 46
	camera.near = 0.02
	var layer := CanvasLayer.new()
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(18, 120)
	layer.add_child(caption)
	await ticks(12)
	body = world.spider.get_node("Body")
	world.camera_rig.require_captured_mouse = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SimClock.set_speed(0.25)
	world.spider.set_intent(Vector3.FORWARD, true)
	await ticks(12)
	await shot("leaf-stance")
	world.spider.set_intent(Vector3.ZERO, false)
	world.spider.begin_prepare()
	await ticks(10)
	await shot("spinneret-touchdown")
	world.spider.commit_jump(world.spider.plan_hop(1.5))
	await ticks(7)
	await shot("rear-push")
	for i in 90:
		await ticks(1)
		if body.landing_depth > 0.045:
			await shot("landing-absorption")
			break
	await ticks(20)
	prefs.set_value("eye_view", true)
	world.camera_rig.camera.current = true
	world.camera_rig._look_eye(deg_to_rad(35.0), deg_to_rad(45.0))
	world.spider.set_intent(Vector3.FORWARD, true)
	await ticks(8)
	world.camera_rig.gaze = (body.legs.world_foot_positions()[0] - world.camera_rig.camera.global_position).normalized()
	world.camera_rig._place_eye(1.0)
	await shot("spider-eye-stance", true)
	prefs.set_value("eye_view", false)
	prefs.set_value("reduced_motion", true)
	await ticks(3)
	await shot("reduced-motion")
	SimClock.set_speed(1.0)
	quit()
