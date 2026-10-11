extends CanvasLayer
## Research-informed retinal scanning, not a literal spider's subjective view.
## Fixed lenses; two narrow fields scan and twist within a stable view.
## See docs/VISION_RESEARCH.md for evidence, species limits and UV limitations.
## Never moves the camera, aim, inspection axis or gameplay RNG. HUD stays crisp.

const KeyNames = preload("res://scripts/presentation/key_names.gd")

const SHARP_DEG := Vector2(5.0, 20.0) # each stylized field, full degrees
const SWEEP_PERIOD_S := 1.6
const TORSION_PERIOD_S := 8.0
const SWEEP_DEG := 4.0
const TORSION_DEG := 25.0
const FADE_DEG := 10.0                   # past the principal eyes' reach, the window fades over this many degrees
const FADE_RATE := 6.0                   # 1/s, how fast the window follows (it takes a few frames, never a pop)
const NOTICE_S := 7.0
const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float principal = 1.0;            // 0..1: the principal eyes reach the gaze
uniform vec2 retinal_half_deg = vec2(2.5, 10.0);
uniform vec2 left_deg = vec2(-2.5, 0.0);
uniform vec2 right_deg = vec2(2.5, 0.0);
uniform float torsion = 0.0;
uniform float tan_half_fov = 0.8391;
uniform float aspect = 1.7778;
uniform float blur_px = 7.0;              // radius of the secondary eyes' blur, in pixels
uniform float grain_px = 3.0;             // their coarser sampling, in pixels

// Soft bent strips suggest boomerang-shaped retinas in one fused view.
float retina(vec2 angle, vec2 centre, float bend) {
    vec2 p = angle - centre;
    float c = cos(torsion);
    float s = sin(torsion);
    p = vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
    p.x -= bend * abs(p.y) * 0.18;
    return 1.0 - smoothstep(0.85, 1.7, length(p / retinal_half_deg));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
    vec2 angle = degrees(atan((uv - vec2(0.5)) * 2.0 * tan_half_fov * vec2(aspect, 1.0)));
    float sharp = principal * max(retina(angle, left_deg, -1.0), retina(angle, right_deg, 1.0));
	// Secondary eyes: coarse cells, then a soft disc around each.
	vec2 cell = px * grain_px;
	vec2 base = (floor(uv / cell) + 0.5) * cell;
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 2.39996;
		float r = sqrt((float(i) + 0.5) / 12.0) * blur_px;
		acc += texture(screen_tex, base + vec2(cos(a), sin(a)) * r * px).rgb;
	}
	vec3 coarse = acc / 12.0;
    // RGB has no UV data: blue is NOT ultraviolet. Illustrative green-weighted
    // brightness, not calibrated spectral sensitivity. Red is dim, not absent.
    vec3 weights = vec3(0.08, 0.84, 0.08);
    float green_side = dot(coarse, weights);
    vec3 side = vec3(green_side) * vec3(0.94, 1.0, 0.94);
    float green_centre = dot(texture(screen_tex, uv).rgb, weights);
    vec3 centre = green_centre * vec3(0.88, 1.0, 0.76);
	COLOR = vec4(mix(side, centre, sharp), 1.0);
}
"""

var camera_rig: Node3D
var motor: Node3D
var settings: Node
## 0..1: how much of the sharp window is drawn now (eased toward the reach of the principal eyes).
var principal: float = 1.0
var notice_left: float = 0.0
var _rect: ColorRect
var _material: ShaderMaterial
var _tag: Label
var _notice: Label
var _was_on: bool = false
var _orbit_hint: Label
var scan_time: float = 0.0
var left_scan_deg := Vector2(-2.5, 0.0)
var right_scan_deg := Vector2(2.5, 0.0)
var scan_torsion: float = 0.0


func _ready() -> void:
	layer = -1
	_rect = ColorRect.new()
	_rect.name = "EyeView"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect.material = _material
	add_child(_rect)
	_tag = _label(16)
	_tag.name = "EyeViewTag"
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notice = _label(18)
	_notice.name = "EyeViewNotice"
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Nathan, 2026-10-11: "a button that can easily switch between first and 3rd person". In the orbit view a small line names it.
	_orbit_hint = _label(16)
	_orbit_hint.name = "ViewHint"
	_orbit_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_set_visible(false)


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.92, 0.96, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func is_on() -> bool:
	return camera_rig != null and is_instance_valid(camera_rig) and camera_rig.get("eye_view") == true


func _process(delta: float) -> void:
	var on := is_on()
	if on != _was_on:
		_was_on = on
		_set_visible(on)
		if on:
			notice_left = NOTICE_S
			principal = target_principal()
			scan_time = 0.0
	if not on:
		_place_orbit_hint()
		return
	# Local elapsed time pauses with the tree. Reduced motion holds current pose.
	if settings == null or not bool(settings.get_value("reduced_motion")):
		scan_time = fposmod(scan_time + maxf(delta, 0.0), TORSION_PERIOD_S)
	principal = move_toward(principal, target_principal(), FADE_RATE * delta)
	notice_left = maxf(notice_left - delta, 0.0)
	refresh()


## 1 while the gaze is within the principal eyes' reach, fading to 0 FADE_DEG past it.
func target_principal() -> float:
	if not is_on():
		return 1.0
	var reach: float = float(motor.PRINCIPAL_SCAN_DEG) if motor != null and is_instance_valid(motor) and "PRINCIPAL_SCAN_DEG" in motor else 30.0
	var off: float = camera_rig.principal_offset_deg()
	return 1.0 - clampf((off - reach) / FADE_DEG, 0.0, 1.0)


## Updates the shader's window to the view's field and the window's size in degrees, and the words.
func refresh() -> void:
	var size := _rect.get_viewport_rect().size
	var fov := deg_to_rad(float(camera_rig.camera.fov)) if camera_rig != null and camera_rig.get("camera") != null else deg_to_rad(80.0)
	var pose := scan_pose(scan_time)
	left_scan_deg = pose["left"]
	right_scan_deg = pose["right"]
	scan_torsion = pose["torsion"]
	_material.set_shader_parameter("retinal_half_deg", SHARP_DEG * 0.5)
	_material.set_shader_parameter("left_deg", left_scan_deg)
	_material.set_shader_parameter("right_deg", right_scan_deg)
	_material.set_shader_parameter("torsion", scan_torsion)
	_material.set_shader_parameter("tan_half_fov", tan(fov * 0.5))
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_material.set_shader_parameter("principal", principal)
	_tag.text = KeyNames.apply("SPIDER-EYE VIEW (an impression)    V / Y: third person", settings)
	_tag.text += "\nGreen-sensitive approximation | UV not simulated"
	if principal < 0.5:
		_tag.text += "\nOut of the principal eyes' reach: stand still and the spider turns to look."
	_notice.visible = notice_left > 0.0
	# Placed by hand from the window's size, so neither runs off the screen at any width or text size.
	var tag_size := _tag.get_minimum_size()
	_tag.size = tag_size
	_tag.position = Vector2(size.x - tag_size.x - 18.0, 14.0)
	var width := minf(760.0, size.x - 36.0)
	_notice.custom_minimum_size = Vector2(width, 0.0)
	_notice.size = Vector2(width, 0.0)
	_notice.position = Vector2((size.x - width) * 0.5, size.y * 0.70)
	_notice.text = "Two narrow retinas sweep and twist behind fixed front lenses. The softer surround suggests the secondary eyes. Related Phidippus have green and UV receptors, with no dedicated red receptor shown. This green-weighted picture cannot recover UV from ordinary colours. Reduced motion holds the scan still."


## Conjugate horizontal sweep plus slower torsion. Periods within Land's reported
## ranges; geometry and continuous cycle are a presentation approximation.
static func scan_pose(seconds: float) -> Dictionary:
	var sweep := SWEEP_DEG * sin(TAU * seconds / SWEEP_PERIOD_S)
	return {"left": Vector2(sweep - 2.5, 0.0),
		"right": Vector2(sweep + 2.5, 0.0),
		"torsion": deg_to_rad(TORSION_DEG) * sin(TAU * seconds / TORSION_PERIOD_S)}


## The orbit view's line: which key gives the spider-eye view.
func _place_orbit_hint() -> void:
	_orbit_hint.text = KeyNames.apply("V / Y: first person (spider-eye view)", settings)
	var size := _orbit_hint.get_viewport_rect().size
	var want := _orbit_hint.get_minimum_size()
	_orbit_hint.size = want
	_orbit_hint.position = Vector2(size.x - want.x - 18.0, 14.0)


func _set_visible(on: bool) -> void:
	_rect.visible = on
	_tag.visible = on
	_orbit_hint.visible = not on
	_notice.visible = on and notice_left > 0.0
