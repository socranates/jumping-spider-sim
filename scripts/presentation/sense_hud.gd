extends CanvasLayer
## T12a, what the senses tell the player without sound (spec 16: "Caption important environmental cues with direction when useful. Silence
## should not remove information necessary for survival"; U01: the loop playable muted).
##   * Captions: a short line for each cue ("[felt: footsteps, ahead-left]", "[buzzing, behind]", "[a shadow sweeps over the sill]"),
##     bottom centre, a few at a time, each fading after CAPTION_S. The "captions" setting turns them off; they ignore the volume.
##   * Ripples: a felt vibration draws a few short arcs on a ring round the middle of the screen, on the side it came from as seen from the
##     camera, fading as they spread. A ripple gives a direction only, never a place (spec 7: sensed evidence, not coordinates).

const CAPTION_S := 3.0
const MAX_CAPTIONS := 3
const RIPPLE_S := 0.8
const RING_PX := 150.0

var settings: Node
var camera_rig: Node3D
var spider: Node3D
## {text, left} newest last.
var captions: Array[Dictionary] = []
## {angle (radians on screen, 0 up, clockwise), strength, age}.
var ripples: Array[Dictionary] = []
var _label: Label
var _canvas: Control


func _ready() -> void:
	layer = 6
	_canvas = Control.new()
	_canvas.name = "Ripples"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_ripples)
	add_child(_canvas)
	_label = Label.new()
	_label.name = "Captions"
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func show_caption(text: String) -> void:
	if settings != null and not bool(settings.get_value("captions")):
		return
	for c: Dictionary in captions:
		if str(c["text"]) == text:
			c["left"] = CAPTION_S   # the same cue again: keep it up instead of repeating it
			_refresh()
			return
	captions.append({"text": text, "left": CAPTION_S})
	while captions.size() > MAX_CAPTIONS:
		captions.pop_front()
	_refresh()


## A felt vibration (VibrationSense.felt).
func on_felt(ev: Dictionary) -> void:
	var dir: Vector3 = ev.get("direction", Vector3.ZERO)
	ripples.append({"angle": screen_angle(dir), "strength": float(ev.get("strength", 0.5)), "age": 0.0})
	if ripples.size() > 8:
		ripples.pop_front()


## Where a world direction from the spider lies round the screen's middle, as the camera sees it: 0 is up (ahead), positive clockwise.
func screen_angle(dir: Vector3) -> float:
	if camera_rig == null or not is_instance_valid(camera_rig) or camera_rig.get("camera") == null:
		return 0.0
	var cam: Camera3D = camera_rig.camera
	var local := cam.global_transform.basis.inverse() * dir
	if Vector2(local.x, local.z).length_squared() < 1.0e-8:
		return 0.0
	return atan2(local.x, -local.z)


func _process(delta: float) -> void:
	var changed := false
	for c: Dictionary in captions:
		c["left"] = float(c["left"]) - delta
	var before := captions.size()
	captions = captions.filter(func(c: Dictionary) -> bool: return float(c["left"]) > 0.0)
	changed = captions.size() != before
	for r: Dictionary in ripples:
		r["age"] = float(r["age"]) + delta
	ripples = ripples.filter(func(r: Dictionary) -> bool: return float(r["age"]) < RIPPLE_S)
	if changed or not captions.is_empty():
		_refresh()
	_canvas.queue_redraw()


func _refresh() -> void:
	var lines: Array[String] = []
	for c: Dictionary in captions:
		lines.append(str(c["text"]))
	_label.text = "\n".join(lines)
	_label.visible = not lines.is_empty()
	var size := _label.get_viewport_rect().size
	var want := _label.get_minimum_size()
	_label.size = want
	_label.position = Vector2((size.x - want.x) * 0.5, size.y * 0.78 - want.y)


func _draw_ripples() -> void:
	var size := _canvas.get_viewport_rect().size
	var centre := size * 0.5
	for r: Dictionary in ripples:
		var k: float = float(r["age"]) / RIPPLE_S
		var a: float = float(r["angle"])
		var alpha: float = (1.0 - k) * clampf(0.35 + float(r["strength"]), 0.0, 1.0)
		for i in 3:
			var radius := RING_PX + 22.0 * float(i) + 40.0 * k
			var from := a - 0.22 - 0.03 * float(i)
			var to := a + 0.22 + 0.03 * float(i)
			# Screen angles run clockwise from up; draw_arc runs from +x, clockwise on screen (y down).
			_canvas.draw_arc(centre, radius, from - PI * 0.5, to - PI * 0.5, 16, Color(0.0, 0.0, 0.0, alpha * 0.5), 6.0, true)
			_canvas.draw_arc(centre, radius, from - PI * 0.5, to - PI * 0.5, 16, Color(0.85, 0.95, 1.0, alpha), 2.5, true)
