extends CanvasLayer
## Developer overlay, off by default; F3 (action debug_overlay) toggles it. Shows the motor state,
## the support surface id and profile, and the support normal (F4 draws them in the scene). Chunk 5: the
## safety line (spec 21.3 TetherState): mode, anchor surface and point, paid, rest and maximum length, taut,
## the bend point, the reel intent and why reeling stopped, if it did.

const PerceptionDebug = preload("res://scripts/presentation/perception_debug.gd")
const PreyDebug = preload("res://scripts/presentation/prey_debug.gd")

var motor: Node3D        # SpiderMotor
var camera_rig: Node3D   # CameraRig
var sensor: Node         # SensorSystem; optional (chunk 6B)
var memory: RefCounted   # ObservationMemory; optional
var prey: Node3D         # PreyDirector; optional (chunk 7B)
var needs: RefCounted    # NeedsModel; optional
var feeding: Node        # FeedingController; optional

var _label: Label


func _ready() -> void:
	layer = 10
	visible = false
	_label = Label.new()
	_label.position = Vector2(10.0, 8.0)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible


func _process(_delta: float) -> void:
	if visible:
		_label.text = _describe()


func _describe() -> String:
	var lines := PackedStringArray()
	lines.append("FPS %d" % Engine.get_frames_per_second())
	if motor != null:
		var p := motor.global_position
		var v: Vector3 = motor.velocity
		lines.append("State %s%s" % [motor.get_state_name(), "  (edge arc)" if motor.in_transition() else ""])
		lines.append("Position (%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])
		lines.append("Velocity (%.2f, %.2f, %.2f)  speed %.2f" % [v.x, v.y, v.z, v.length()])
		lines.append("Supported %s" % ("yes" if motor.is_supported() else "no"))
		var s: RefCounted = motor.support
		var sid: String = s.surface_id
		lines.append("Support %s (%s)" % [sid if sid != "" else "none", s.profile_id])
		var n: Vector3 = motor.get_support_normal()
		lines.append("Normal (%.2f, %.2f, %.2f)" % [n.x, n.y, n.z])
		lines.append_array(describe_line(motor))
	if camera_rig != null:
		lines.append("Camera boom %.2f WU" % camera_rig.boom_length)
	if sensor != null and memory != null:
		if motor != null and motor.has_method("is_focusing"):
			lines.append("Focus %s, gaze pitch %.0f deg" % ["on" if motor.is_focusing() else "off", rad_to_deg(motor.get_gaze_pitch())])
		lines.append_array(PerceptionDebug.describe(sensor, memory))
	if prey != null or needs != null:
		lines.append_array(PreyDebug.describe(prey, needs, feeding))
	lines.append("Godot %s, %s, %s" % [
		Engine.get_version_info()["string"],
		RenderingServer.get_current_rendering_method(),
		str(ProjectSettings.get_setting("physics/3d/physics_engine")),
	])
	return "\n".join(lines)


## The safety line's lines of the overlay (also used by tests).
static func describe_line(m: Node3D) -> PackedStringArray:
	var out := PackedStringArray()
	if m == null or not ("tether" in m):
		return out
	var t: RefCounted = m.tether
	if not t.is_active():
		out.append("Line: none (%d completed, fading)" % (m.completed_lines as Array).size())
		return out
	var a: Vector3 = t.anchor_point
	out.append("Line %s, anchor %s at (%.2f, %.2f, %.2f)" % [t.mode_name(), t.anchor_surface_id, a.x, a.y, a.z])
	var held := ", held at rest" if (m.has_method("is_resting") and m.is_resting()) else ""
	out.append("  paid %.2f WU, rest %.2f WU, max %.2f WU, taut %s%s" % [t.paid_length, t.rest_length, t.max_length, "yes" if t.taut else "no", held])
	var bend := "none"
	if t.has_bend:
		bend = "(%.2f, %.2f, %.2f) on %s" % [t.bend_point.x, t.bend_point.y, t.bend_point.z, t.bend_surface_id]
	var stop: String = t.block_reason if t.block_reason != "" else ("snagged" if t.snagged else "-")
	out.append("  bend %s, reel %+.1f, stopped: %s" % [bend, t.reel_intent, stop])
	return out
