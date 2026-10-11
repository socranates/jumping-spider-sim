extends CanvasLayer
## T10a, the spider-eye view's picture (Nathan, 2026-10-11: "scientific realism in terms of vision"). It is an impression, and the screen
## says so: nobody can show what a spider experiences. It shows, from salticid research, where seeing is sharp and in what colours:
##
##   * Principal eyes (the two big front eyes): long telephoto eyes with high acuity in a narrow field, about 10 degrees across at an
##     instant (Land 1969). Their retinas move behind fixed lenses, which is the gaze here (see CameraRig, SpiderMotor.set_scan_direction).
##     Drawn as a sharp window SHARP_DEG across at the centre of the view, where the gaze is, a little wider than one eye's instant field
##     (both eyes, and the scanning they do). Receptors for green and ultraviolet; none for red has been found in Phidippus (De Voe
##     1975 on P. regius). So the window is two-colour: green against "UV". A screen has no UV, so blue stands in for it, and reds go dark.
##   * Secondary eyes (the six others): together nearly all round, lower acuity, chiefly motion detectors, dominated by green-sensitive
##     pigment. Drawn as the rest of the view: coarse, soft and one-colour (green light). What moves there is found by the senses, and the
##     perception HUD's cue marks it, as before.
##   * When the gaze is further than the principal eyes can point (SpiderMotor.PRINCIPAL_SCAN_DEG from the body's gaze) the window fades:
##     everything is secondary-eye view until the body turns (the controller turns it when the spider stands still).
##
## The layer sits under every HUD (layer -1: after the 3D, before any panel), so words and markers stay crisp.

const KeyNames = preload("res://scripts/presentation/key_names.gd")

const SHARP_DEG := Vector2(16.0, 24.0)   # the sharp window, full width and height in degrees
const SOFT_DEG := Vector2(10.0, 14.0)    # its soft edge, added on each side
const FADE_DEG := 10.0                   # past the principal eyes' reach, the window fades over this many degrees
const FADE_RATE := 6.0                   # 1/s, how fast the window follows (it takes a few frames, never a pop)
const NOTICE_S := 7.0
const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float principal = 1.0;            // 0..1: the principal eyes reach the gaze
uniform vec2 window = vec2(0.06, 0.12);   // half size of the sharp field, in screen UV
uniform vec2 soft = vec2(0.04, 0.07);     // width of its soft edge, in screen UV
uniform float blur_px = 7.0;              // radius of the secondary eyes' blur, in pixels
uniform float grain_px = 3.0;             // their coarser sampling, in pixels

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	// An oval window (the retinas' field is taller than wide), fading out over its soft edge.
	float r = length((uv - vec2(0.5)) / window);
	float sharp = principal * (1.0 - smoothstep(1.0, 1.0 + soft.y / window.y, r));
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
	vec3 tint = vec3(0.93, 1.0, 0.95);
	float green_side = dot(coarse, vec3(0.12, 0.76, 0.12));
	vec3 side = vec3(green_side) * tint;
	// Principal eyes: the same green-weighted brightness, sharp, plus one colour contrast, "UV" against green (blue stands in for
	// UV; there is no red receptor, so red adds almost nothing). Neutral where the two agree; violet where "UV" is strong, yellow-green
	// where green is.
	vec3 clear = texture(screen_tex, uv).rgb;
	float g = dot(clear, vec3(0.15, 0.75, 0.10));
	float u = clear.b;
	vec3 centre = clamp(vec3(g) * tint + (u - g) * vec3(0.30, -0.12, 0.50), 0.0, 1.0);
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
	return camera_rig != null and is_instance_valid(camera_rig) and bool(camera_rig.get("eye_view"))


func _process(delta: float) -> void:
	var on := is_on()
	if on != _was_on:
		_was_on = on
		_set_visible(on)
		if on:
			notice_left = NOTICE_S
			principal = target_principal()
	if not on:
		return
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
	var half_h := tan(fov * 0.5)
	var aspect := size.x / maxf(size.y, 1.0)
	var to_uv := func(deg: Vector2) -> Vector2:
		return Vector2(tan(deg_to_rad(deg.x * 0.5)) / (half_h * aspect), tan(deg_to_rad(deg.y * 0.5)) / half_h) * 0.5
	_material.set_shader_parameter("window", to_uv.call(SHARP_DEG))
	_material.set_shader_parameter("soft", to_uv.call(SHARP_DEG + SOFT_DEG * 2.0) - to_uv.call(SHARP_DEG))
	_material.set_shader_parameter("principal", principal)
	_tag.text = KeyNames.apply("SPIDER-EYE VIEW (an impression)    V / Y: switch back", settings)
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
	_notice.text = "Sharp only where the two big front eyes point, and they see green and ultraviolet but no red. The rest is the six other eyes: wide, coarse and quick to catch movement. Look further than the front eyes reach and the spider turns to face it."


func _set_visible(on: bool) -> void:
	_rect.visible = on
	_tag.visible = on
	_notice.visible = on and notice_left > 0.0
