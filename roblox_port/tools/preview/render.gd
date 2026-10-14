extends SceneTree
# Renders the Roblox SpiderRig part list (exported by the Luau preview driver) so the layout can be inspected off-Roblox.
func mat(c: Color, m: String, r: float, t: float = 0.0) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = Color(c.r, c.g, c.b, 1.0 - t)
	if t > 0.0:
		s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.roughness = 0.55
	if m.ends_with("Glass") or r > 0.2:
		s.roughness = 0.08
		s.metallic_specular = 1.0
	if m.ends_with("Neon"):
		s.emission_enabled = true
		s.emission = c
		s.emission_energy_multiplier = 1.5
	if m.ends_with("Foil"):
		s.metallic = 0.6
		s.roughness = 0.25
	return s

func add_parts(root: Node3D, path: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	for p in data:
		var mi := MeshInstance3D.new()
		var size := Vector3(p["size"][0], p["size"][1], p["size"][2])
		var extra := Basis.IDENTITY
		match p["s"]:
			"sphere":
				var m := SphereMesh.new(); m.radius = 0.5; m.height = 1.0; m.radial_segments = 24; m.rings = 12
				mi.mesh = m
			"ball":
				var m := SphereMesh.new(); m.radius = 0.5; m.height = 1.0; m.radial_segments = 16; m.rings = 8
				mi.mesh = m
				size = Vector3.ONE * size.x
			"cyl":
				var m := CylinderMesh.new(); m.top_radius = 0.5; m.bottom_radius = 0.5; m.height = 1.0; m.radial_segments = 12
				mi.mesh = m
				extra = Basis(Vector3(0, 0, 1), -PI / 2)  # Godot cylinders run along Y; Roblox along X
				size = Vector3(size.y, size.x, size.z)
			_:
				mi.mesh = BoxMesh.new()
		var b := Basis(Vector3(p["x"][0], p["x"][1], p["x"][2]), Vector3(p["y"][0], p["y"][1], p["y"][2]), Vector3(p["z"][0], p["z"][1], p["z"][2]))
		mi.transform = Transform3D(b * extra * Basis.from_scale(size), Vector3(p["p"][0], p["p"][1], p["p"][2]))
		mi.material_override = mat(Color(p["c"][0], p["c"][1], p["c"][2]), p["m"], float(p["r"]), float(p.get("t", 0.0)))
		root.add_child(mi)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var root := Node3D.new()
	get_root().add_child(root)
	add_parts(root, args[0])
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(40, 40)
	floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.86, 0.76, 0.6); fm.roughness = 0.9
	floor.material_override = fm
	root.add_child(floor)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.3
	root.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	# A plain backdrop, but a procedural sky for ambient light and reflections, so glossy parts (the eyes) show a sky in them
	# the way Roblox's Future lighting does.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.62, 0.88)
	sky_mat.sky_horizon_color = Color(0.92, 0.9, 0.84)
	sky_mat.ground_horizon_color = Color(0.86, 0.8, 0.7)
	sky_mat.ground_bottom_color = Color(0.7, 0.62, 0.52)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.sky = sky
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.82, 0.86, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.8
	e.ambient_light_energy = 0.9
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.environment = e
	root.add_child(env)
	var cam := Camera3D.new()
	cam.fov = float(args[2])
	cam.near = 0.01
	root.add_child(cam)
	var eye := Vector3(float(args[3]), float(args[4]), float(args[5]))
	var at := Vector3(float(args[6]), float(args[7]), float(args[8]))
	cam.look_at_from_position(eye, at, Vector3.UP)
	cam.current = true
	for i in 6:
		await process_frame
	get_root().get_texture().get_image().save_png(args[1])
	quit()
