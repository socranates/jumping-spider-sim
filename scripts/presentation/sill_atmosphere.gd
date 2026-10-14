extends Node3D
## VISUAL-01 (drawn only): dust motes drifting in the window light, fading with the daylight. No collision, no physics, no
## rays, no RNG shared with gameplay; the senses never see them. Coordinates are WU (1 WU = 1 cm): a mote is 0.3 to 0.7 mm across.

const AMOUNT := 70
const AREA := AABB(Vector3(-28.0, 0.6, -12.0), Vector3(56.0, 11.0, 22.0))
const MOTE_ALPHA_DAY := 0.35
const MOTE_ALPHA_NIGHT := 0.06

var motes: CPUParticles3D
var _mat: StandardMaterial3D


func _ready() -> void:
	motes = CPUParticles3D.new()
	motes.name = "DustMotes"
	motes.amount = AMOUNT
	motes.lifetime = 16.0
	motes.preprocess = 16.0
	motes.randomness = 1.0
	motes.local_coords = false
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = AREA.size * 0.5
	motes.position = AREA.get_center()
	motes.direction = Vector3(0.3, 0.15, 0.1)
	motes.spread = 180.0
	motes.gravity = Vector3(0.0, -0.02, 0.0)
	motes.initial_velocity_min = 0.05
	motes.initial_velocity_max = 0.25
	motes.damping_min = 0.02
	motes.damping_max = 0.06
	motes.scale_amount_min = 0.6
	motes.scale_amount_max = 1.4
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.15, 1.0))
	fade.add_point(Vector2(0.85, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	motes.scale_amount_curve = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = g
	_mat.albedo_texture = dot
	quad.material = _mat
	motes.mesh = quad
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)
	set_daylight(1.0)


## 0 night to 1 day: motes catch the sun by day and nearly vanish at night.
func set_daylight(light: float) -> void:
	if _mat == null:
		return
	var d := clampf(light, 0.0, 1.0)
	_mat.albedo_color = Color(1.0, 0.93, 0.8, lerpf(MOTE_ALPHA_NIGHT, MOTE_ALPHA_DAY, d))
