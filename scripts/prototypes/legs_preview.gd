extends Node3D
## Standalone visual bench, deliberately not connected to the game's spider.
const Legs = preload("res://scripts/presentation/spider_legs.gd")
const LABELS := ["Walk", "Stalk", "Prepare", "Airborne / hanging", "Idle", "Sideways", "Reduced motion"]
var legs: Node3D
var label: Label
var mode: int = 0
var elapsed: float = 0.0
var automatic: bool = true

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("182b32")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b5d0d6")
	env.ambient_light_energy = 0.7
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(2.0, 1.8, -2.8)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("775646")
	for p in [Vector3(0, 0.02, -0.22), Vector3(0, 0.04, 0.20)]:
		var body := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		body.mesh = sphere
		body.material_override = mat
		body.position = p
		body.scale = Vector3(0.22, 0.18, 0.28)
		add_child(body)
	legs = Legs.new()
	add_child(legs)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4, 4)
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.305
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("61716d")
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(28, 24)
	label.add_theme_font_size_override("font_size", 23)
	canvas.add_child(label)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			automatic = not automatic
		elif event.keycode == KEY_RIGHT:
			mode = (mode + 1) % LABELS.size()
			automatic = false
			legs.reset_pose()

func _physics_process(delta: float) -> void:
	if automatic:
		elapsed += delta
		if elapsed >= 3.0:
			elapsed = 0.0
			mode = (mode + 1) % LABELS.size()
			legs.reset_pose()
	var velocity := Vector3(0, 0, -1.4)
	if mode == 1:
		velocity *= 0.18
	elif mode in [2, 3, 4]:
		velocity = Vector3.ZERO
	elif mode == 5:
		velocity = Vector3(1.0, 0, 0)
	legs.advance_pose(delta, velocity, mode != 3, mode == 2, mode == 6)
	label.text = "LEG STUDY  /  %s\nRight arrow: next pose   Space: auto-cycle %s\nCosmetic prototype; not attached to the game" % [LABELS[mode], "on" if automatic else "off"]
