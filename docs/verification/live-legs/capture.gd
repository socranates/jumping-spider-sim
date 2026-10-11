extends SceneTree

var world: Node3D
var camera: Camera3D
var caption: Label
const OUT := "res://docs/verification/live-legs/"

func _initialize() -> void:
	call_deferred("run")

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func capture(label: String, filename: String) -> void:
	caption.text = label
	var center: Vector3 = world.spider.global_position
	camera.global_position = center + Vector3(1.8, 1.25, -2.1)
	camera.look_at(center + Vector3(0, -0.06, -0.1))
	camera.reset_physics_interpolation()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + filename + ".png")
	print("captured %s state=%s reduced_motion=%s" % [filename, world.spider.get_state_name(), world.settings.get_value("reduced_motion")])

func run() -> void:
	root.size = Vector2i(1000, 700)
	var settings = load("res://scripts/presentation/settings.gd").new()
	settings.autosave = false
	settings.config_path = "user://live_legs_capture_unused.cfg"
	root.add_child(settings)
	settings.set_value("reduced_motion", false)
	world = load("res://scenes/main.tscn").instantiate()
	world.settings = settings
	world.interactive = false
	world.use_windowsill = true
	world.prey_count = 0
	world.spawn_override = Transform3D(Basis.IDENTITY, Vector3(-12, 0.31, 6))
	root.add_child(world)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 45
	var layer := CanvasLayer.new()
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(24, 24)
	caption.add_theme_font_size_override("font_size", 23)
	layer.add_child(caption)
	await ticks(12)
	await capture("LIVE SPIDER / neutral stance", "idle")
	world.spider.set_intent(Vector3.FORWARD, false)
	await ticks(20)
	await capture("LIVE SPIDER / walking + body twitch", "walk")
	world.spider.set_intent(Vector3.FORWARD, true)
	await ticks(25)
	await capture("LIVE SPIDER / slow stalk", "stalk")
	world.spider.set_intent(Vector3.ZERO, false)
	await ticks(30)
	world.spider.begin_prepare()
	await ticks(12)
	await capture("LIVE SPIDER / preparing to jump", "prepare")
	world.spider.cancel_prepare()
	world.settings.set_value("reduced_motion", true)
	world.spider.set_intent(Vector3.FORWARD, false)
	await ticks(12)
	await capture("LIVE SPIDER / Reduced motion while walking", "reduced-motion")
	quit()
