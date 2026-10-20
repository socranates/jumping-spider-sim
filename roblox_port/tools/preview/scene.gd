extends SceneTree
# Draws the part list that tools/preview/scene.py dumped from the Luau scene driver (the sill, its decor, the spider and the flies)
# in Godot 4 for a quick look at layout and colour: a sun from behind the window, warm ambient light, a filmic tonemap, soft
# shadows, a sky-colour background, and rough stand-ins for Roblox's materials. It is NOT Roblox rendering: Roblox's PBR textures,
# Future lighting, haze, bloom and depth of field look different, and only Studio is the judge of that.
# User args: parts.json config.json out_prefix   (config: { views: [...], sun: {...}, format: "png" | "jpg" })

# Material name -> roughness (1 is matte). Roblox's own materials carry textures that this does not try to imitate.
const ROUGH := {
	"Plastic": 0.55, "SmoothPlastic": 0.30, "Neon": 0.5, "Wood": 0.8, "WoodPlanks": 0.74, "Plaster": 0.93, "Concrete": 0.96,
	"Brick": 0.92, "Glass": 0.03, "Ground": 1.0, "Grass": 0.96, "LeafyGrass": 0.92, "Fabric": 1.0, "Cardboard": 0.96,
	"Sand": 1.0, "Slate": 0.85, "Pebble": 0.9, "Rock": 0.9, "Mud": 1.0, "Limestone": 0.9, "Marble": 0.3, "Metal": 0.36,
}
var cache := {}
var box_mesh := BoxMesh.new()
var sphere_mesh := SphereMesh.new()
var cyl_mesh := CylinderMesh.new()

func srgb_to_linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)

func make_material(m: String, c: Array, r: float, t: float) -> StandardMaterial3D:
	var key := "%s|%.3f,%.3f,%.3f|%.3f|%.3f" % [m, c[0], c[1], c[2], r, t]
	if cache.has(key):
		return cache[key]
	var s := StandardMaterial3D.new()
	s.albedo_color = Color(c[0], c[1], c[2], 1.0 - t)  # Roblox colours are sRGB, as Godot's albedo is
	if t > 0.001:
		s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rough: float = ROUGH.get(m, 0.6)
	s.roughness = clampf(rough - r * 3.0, 0.03, 1.0)
	s.metallic_specular = 0.5 + minf(r * 3.0, 0.5)
	if m == "Metal":
		s.metallic = 0.45  # no reflections to pick up here, so keep it from going black
	if m == "Glass":
		s.metallic_specular = 1.0
	if m == "Neon":
		s.emission_enabled = true
		s.emission = Color(c[0], c[1], c[2])
		s.emission_energy_multiplier = 1.6
	cache[key] = s
	return s

func add_part(root: Node3D, p: Dictionary, uv_view: bool) -> void:
	var size := Vector3(p["size"][0], p["size"][1], p["size"][2])
	var mi := MeshInstance3D.new()
	var extra := Basis.IDENTITY
	var t: float = p["t"]
	var uv = p.get("uv")
	if uv != null:
		if not uv_view:
			return
		t = 1.0 - float(uv)  # the eye-view helper fades the layer in: Transparency = 1 - UVOpacity
	if p.has("mesh"):
		var ms := Vector3(p["ms"][0], p["ms"][1], p["ms"][2])
		match p["mesh"]:
			"Sphere":
				mi.mesh = sphere_mesh
			"Cylinder":
				mi.mesh = cyl_mesh
			_:
				mi.mesh = box_mesh
		size = size * ms
	else:
		match p["k"]:
			"Ball":
				mi.mesh = sphere_mesh
				size = Vector3.ONE * size.x
			"Cylinder":
				mi.mesh = cyl_mesh
				extra = Basis(Vector3(0, 0, 1), -PI / 2.0)  # Godot cylinders run along Y, Roblox's along X
				size = Vector3(size.y, size.x, size.z)
			_:
				mi.mesh = box_mesh
	var b := Basis(Vector3(p["x"][0], p["x"][1], p["x"][2]), Vector3(p["y"][0], p["y"][1], p["y"][2]), Vector3(p["z"][0], p["z"][1], p["z"][2]))
	mi.transform = Transform3D(b * extra * Basis.from_scale(size), Vector3(p["p"][0], p["p"][1], p["p"][2]))
	mi.material_override = make_material(p["m"], p["c"], float(p["r"]), t)
	if not p["cs"] or t > 0.35:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var parts = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var prefix: String = args[2]
	box_mesh.size = Vector3.ONE
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	sphere_mesh.radial_segments = 24
	sphere_mesh.rings = 12
	cyl_mesh.top_radius = 0.5
	cyl_mesh.bottom_radius = 0.5
	cyl_mesh.height = 1.0
	cyl_mesh.radial_segments = 28
	cyl_mesh.rings = 1
	get_root().msaa_3d = Viewport.MSAA_4X
	RenderingServer.directional_shadow_atlas_set_size(8192, true)

	var root := Node3D.new()
	get_root().add_child(root)
	# One node per group so a view can show the world, one spider and the flies.
	var groups := {}
	for p in parts:
		var g: String = p["g"]
		if not groups.has(g):
			var n := Node3D.new()
			n.name = g
			root.add_child(n)
			groups[g] = n
	var uv_nodes := Node3D.new()  # the UV layer, shown only in views that ask for it
	root.add_child(uv_nodes)
	for p in parts:
		var target: Node3D = uv_nodes if p.get("uv") != null else groups[p["g"]]
		add_part(target, p, true)

	var sun_cfg: Dictionary = cfg["sun"]
	var el := deg_to_rad(float(sun_cfg["el"]))
	var az := deg_to_rad(float(sun_cfg["az"]))
	var to_sun := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3.ZERO)
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.light_energy = float(sun_cfg.get("energy", 1.3))
	sun.shadow_enabled = true
	sun.shadow_bias = float(sun_cfg.get("bias", 0.06))
	sun.shadow_normal_bias = float(sun_cfg.get("nbias", 0.4))
	sun.shadow_blur = float(sun_cfg.get("blur", 0.6))
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if int(sun_cfg.get("splits", 4)) == 4 else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_split_1 = float(sun_cfg.get("s1", 0.08))
	sun.directional_shadow_split_2 = float(sun_cfg.get("s2", 0.25))
	sun.directional_shadow_split_3 = float(sun_cfg.get("s3", 0.55))
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 1.0
	root.add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.38, 0.58, 0.86)
	sky_mat.sky_horizon_color = Color(0.80, 0.88, 0.95)
	sky_mat.ground_horizon_color = Color(0.80, 0.86, 0.90)
	sky_mat.ground_bottom_color = Color(0.62, 0.70, 0.58)
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.sky = sky
	e.background_mode = Environment.BG_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR  # warm room light, not the blue of the sky
	e.ambient_light_color = Color(1.0, 0.90, 0.78)
	e.ambient_light_energy = float(sun_cfg.get("ambient", 0.45))
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_hdr_threshold = 1.1
	e.glow_bloom = 0.04
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.10
	e.fog_enabled = true  # Roblox's Atmosphere haze, roughly: far hills fade toward the sky
	e.fog_light_color = Color(0.78, 0.85, 0.92)
	e.fog_density = float(sun_cfg.get("fog", 0.0009))  # (ROBLOX-115: a knob, --set fog=..., and a view's own "fog" for a plan)
	env.environment = e
	root.add_child(env)

	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var fmt: String = cfg.get("format", "png")
	for v in cfg["views"]:
		for g in groups:
			groups[g].visible = (g == "world") or (g in v["groups"])
		uv_nodes.visible = bool(v.get("uv", false))
		cam.fov = float(v["fov"])
		cam.near = float(v["near"])
		cam.far = float(v["far"])
		sun.directional_shadow_max_distance = float(v.get("shadow", 140.0))
		e.fog_density = float(v.get("fog", sun_cfg.get("fog", 0.0009)))
		var eye := Vector3(v["eye"][0], v["eye"][1], v["eye"][2])
		var at := Vector3(v["at"][0], v["at"][1], v["at"][2])
		cam.look_at_from_position(eye, at, Vector3.UP)
		for i in 5:
			await process_frame
		var img := get_root().get_texture().get_image()
		var path: String = prefix + str(v["name"]) + "." + fmt
		if fmt == "jpg":
			img.save_jpg(path, 0.92)
		else:
			img.save_png(path)
		print("wrote ", path)
	quit()
