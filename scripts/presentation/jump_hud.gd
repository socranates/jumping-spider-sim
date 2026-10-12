extends CanvasLayer
## Jump HUD (spec 6.3, 16): a reticle at the screen centre while aiming (the camera's centre ray is the
## aim), a two-line label under it that says in words what the patch shows (so nothing depends on colour
## alone), and a short toast when a jump or hop is refused, cancelled, or the spider was put back inside
## the habitat. Hidden when not aiming.
## Safety line (T04, spec 9.1, 17): while aiming, a third line says whether this jump will have a line
## (and why not, before commit), with the prompt that Q cancels the jump. While the spider is on its line, a
## panel at the bottom gives the line's own prompts (reel in, lower, let go: distinct from cancelling an
## aim), why reeling stopped if it did, and the hold-to-let-go progress. Line events get toasts.

const KeyNames = preload("res://scripts/presentation/key_names.gd")
const JumpFeedback = preload("res://scripts/presentation/jump_feedback.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")

const TOAST_SECONDS := 2.5
const RETICLE_RADIUS := 11.0
## The hidden-anchor note (A-017): the line panel says so when the line's anchor is out of sight behind the world. It comes
## and goes after NOTE_DELAY seconds, so a swinging camera does not make it flicker. The anchor is checked ANCHOR_LIFT off its
## surface, and a hit within ANCHOR_SIGHT_TOLERANCE of it is the anchor's own surface, not something in the way.
const NOTE_DELAY := 0.3
const ANCHOR_LIFT := 0.04
const ANCHOR_SIGHT_TOLERANCE := 0.06

var controller: Node   # JumpController
var settings: Node     # Settings autoload, or a test instance
var motor: Node3D      # SpiderMotor, for the line; optional
var tether_controller: Node  # TetherController, for the let-go progress; optional

var _reticle: Control
var _title: Label
var _hint: Label
var _anchor: Label
var _toast: Label
var _toast_left: float = 0.0
var _line_box: VBoxContainer
var _line_title: Label
var _line_hint: Label
var _line_note: Label
var _line_cue: Label
var _after_miss: bool = false
var _dropped: bool = false  # the spider let itself down on the line it is on (no "caught" toast)
var _hidden_for: float = 0.0
var _clear_for: float = 0.0
var _note_on: bool = false


func _ready() -> void:
	layer = 5
	if settings == null and controller != null:
		settings = controller.settings
	if motor == null and controller != null:
		motor = controller.motor
	_reticle = Control.new()
	_reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.draw.connect(_draw_reticle)
	_reticle.visible = false
	add_child(_reticle)
	var box := VBoxContainer.new()
	_anchor_box(box, 0.5, 0.5, -330.0, RETICLE_RADIUS + 14.0, 330.0, RETICLE_RADIUS + 100.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	box.name = "AimLabels"
	add_child(box)
	_title = _label(22)
	_hint = _label(16)
	_anchor = _label(16)
	box.add_child(_title)
	box.add_child(_hint)
	box.add_child(_anchor)
	_toast = _label(20)
	_anchor_box(_toast, 0.5, 0.0, -360.0, 70.0, 360.0, 110.0)
	_toast.visible = false
	add_child(_toast)
	_line_box = VBoxContainer.new()
	_line_box.name = "LinePrompts"
	_anchor_box(_line_box, 0.5, 1.0, -380.0, -144.0, 380.0, -24.0)
	_line_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_box.visible = false
	add_child(_line_box)
	_line_title = _label(22)
	_line_hint = _label(16)
	_line_note = _label(16)
	_line_note.add_theme_color_override("font_color", JumpFeedback.ANCHOR_OK_COLOR)
	_line_note.visible = false
	_line_cue = _label(16)
	_line_cue.add_theme_color_override("font_color", JumpFeedback.ANCHOR_REFUSED_COLOR)
	_line_box.add_child(_line_title)
	_line_box.add_child(_line_hint)
	_line_box.add_child(_line_note)
	_line_box.add_child(_line_cue)
	if controller != null:
		controller.feedback.connect(_on_feedback)
	if motor != null and motor.has_signal("line_event"):
		motor.line_event.connect(_on_line_event)


func _process(delta: float) -> void:
	var aiming: bool = controller != null and controller.is_aiming()
	_reticle.visible = aiming
	_title.get_parent().visible = aiming
	var toggle: bool = settings != null and settings.prepare_toggle
	if aiming:
		var plan: RefCounted = controller.plan
		var d := JumpFeedback.describe(plan, toggle)
		_title.text = d["title"]
		_hint.text = KeyNames.apply(d["hint"] if toggle else "%s    %s" % [d["hint"], JumpFeedback.AIM_CANCEL_HINT], settings)
		var color := JumpFeedback.color_for(plan.kind_name() if plan != null else "none")
		_title.add_theme_color_override("font_color", color)
		_update_anchor_label(plan)
		_reticle.queue_redraw()
	_update_line_panel(delta)
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.visible = false


## For tests and the HUD's own redraw.
func reticle_visible() -> bool:
	return _reticle.visible


func title_text() -> String:
	return _title.text


func hint_text() -> String:
	return _hint.text


func anchor_text() -> String:
	return _anchor.text if _anchor.visible else ""


func toast_text() -> String:
	return _toast.text if _toast.visible else ""


func line_panel_visible() -> bool:
	return _line_box.visible


func line_title_text() -> String:
	return _line_title.text


func line_hint_text() -> String:
	return _line_hint.text


func line_cue_text() -> String:
	return _line_cue.text if _line_cue.visible else ""


## The hidden-anchor note, "" while it is not showing.
func line_note_text() -> String:
	return _line_note.text if _line_note.visible else ""


func _update_anchor_label(plan: RefCounted) -> void:
	if motor == null or not motor.has_method("get_anchor_preview"):
		_anchor.visible = false
		return
	var preview: Dictionary = motor.get_anchor_preview(plan)
	var text := JumpFeedback.anchor_text(str(preview["reason"]))
	_anchor.visible = text != ""
	_anchor.text = text
	_anchor.add_theme_color_override("font_color", JumpFeedback.ANCHOR_OK_COLOR if preview["ok"] else JumpFeedback.ANCHOR_REFUSED_COLOR)


func _update_line_panel(delta: float) -> void:
	var on_line: bool = motor != null and motor.has_method("is_on_line") and motor.is_on_line()
	_line_box.visible = on_line
	if not on_line:
		_hidden_for = 0.0
		_clear_for = 0.0
		_note_on = false
		_line_note.visible = false
		return
	_update_anchor_note(delta)
	var reeling: bool = motor.state == motor.State.REELING
	_line_title.text = JumpFeedback.LINE_TITLE_REELING if reeling else JumpFeedback.LINE_TITLE
	var hold: bool = settings == null or settings.release_hold
	_line_hint.text = KeyNames.apply(JumpFeedback.LINE_HINT_HOLD if hold else JumpFeedback.LINE_HINT_PRESS, settings)
	var cue := ""
	var progress: float = tether_controller.release_progress if tether_controller != null else 0.0
	if progress > 0.0:
		cue = "Letting go... %d%%" % roundi(progress * 100.0)
	elif motor.tether.snagged:
		cue = str(JumpFeedback.LINE_BLOCKED["snagged"])
	elif motor.tether.block_reason != "":
		cue = str(JumpFeedback.LINE_BLOCKED.get(motor.tether.block_reason, ""))
	_line_cue.text = cue
	_line_cue.visible = cue != ""


## While on the line, says when its anchor is out of sight behind the world from this camera (the line goes over an edge to
## where it is held; the lip hides it). It is a note, not an X-ray: the line itself stays hidden where the world hides it.
func _update_anchor_note(delta: float) -> void:
	var hidden := false
	var cam := get_viewport().get_camera_3d()
	if cam != null and motor != null:
		var t: RefCounted = motor.tether
		hidden = point_hidden(cam, motor.get_world_3d().direct_space_state, t.anchor_point + t.anchor_normal * ANCHOR_LIFT, get_viewport().get_visible_rect())
		_line_note.text = JumpFeedback.anchor_hidden_text(bool(t.has_bend))
	if hidden:
		_hidden_for += delta
		_clear_for = 0.0
	else:
		_clear_for += delta
		_hidden_for = 0.0
	if _hidden_for >= NOTE_DELAY:
		_note_on = true
	elif _clear_for >= NOTE_DELAY:
		_note_on = false
	_line_note.visible = _note_on


## True when a point that is on the screen cannot be seen because the world is in the way: the ray from the camera to it is
## stopped more than `tolerance` before it. A point off the screen or behind the camera is not "hidden", it is not in view.
static func point_hidden(cam: Camera3D, space: PhysicsDirectSpaceState3D, p: Vector3, screen: Rect2, tolerance: float = ANCHOR_SIGHT_TOLERANCE) -> bool:
	if cam == null or space == null or cam.is_position_behind(p) or not screen.has_point(cam.unproject_position(p)):
		return false
	var from := cam.global_position
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, p, Layers.WORLD))
	return not hit.is_empty() and from.distance_to(hit["position"]) < from.distance_to(p) - tolerance


func _on_feedback(kind: String, plan: RefCounted) -> void:
	var text := JumpFeedback.toast(kind, plan)
	if text == "":
		return
	_show_toast(text, JumpFeedback.color_for(plan.kind_name() if plan != null else "obstructed"))


func _on_line_event(kind: String, detail: String) -> void:
	if kind == "locked":
		_after_miss = true
	elif kind == "dropped":
		_dropped = true
	var text := JumpFeedback.line_toast(kind, detail, _after_miss, _dropped)
	if kind == "completed" or kind == "released" or kind == "lost" or kind == "fallback" or kind == "anchored":
		_after_miss = false
		_dropped = false
	if text != "":
		var warn: bool = kind in ["blocked", "snagged", "lost", "fallback", "drop_refused"]
		_show_toast(KeyNames.apply(text, settings), JumpFeedback.ANCHOR_REFUSED_COLOR if warn else JumpFeedback.ANCHOR_OK_COLOR)


func _show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.visible = true
	_toast_left = TOAST_SECONDS


func _draw_reticle() -> void:
	var center := _reticle.size * 0.5
	var color := Color(1.0, 1.0, 1.0, 0.95)
	var shadow := Color(0.0, 0.0, 0.0, 0.75)
	_reticle.draw_arc(center, RETICLE_RADIUS, 0.0, TAU, 40, shadow, 5.0, true)
	_reticle.draw_arc(center, RETICLE_RADIUS, 0.0, TAU, 40, color, 2.0, true)
	_reticle.draw_circle(center, 2.5, shadow)
	_reticle.draw_circle(center, 1.5, color)


## Pins a control to a fixed rectangle relative to a point of the screen (anchor fractions, pixel offsets).
func _anchor_box(c: Control, ax: float, ay: float, left: float, top: float, right: float, bottom: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom


func _label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l
