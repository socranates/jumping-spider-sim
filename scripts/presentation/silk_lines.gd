extends Node3D
## The safety line drawn as a camera-facing ribbon (spec 9.1, A-017): one strip per line, rebuilt every frame, no
## physics (the line's behaviour is the motor's). The active line runs from its anchor, over its bend point if it
## has one, to the spinnerets, and sags only when it is slack. It is the load-bearing line, so it is drawn to be
## read: a dark core inside a thin light rim (silk.gdshader), which stands out on a pale wall and on a dark one, and
## never thinner on screen than ACTIVE_CORE_PX at 1080p (the width is worked out per point from its distance, so
## it holds in pixels, and a taut or reeling line is a little heavier). It is depth tested like any object: the
## world hides it where it is in the way. Completed lines are old silk: thin, pale and translucent, left where
## they were and faded out over their last FADE_SECONDS; the motor removes them when their time is up and keeps
## no more than MAX_COMPLETED_LINES.

const Tether = preload("res://scripts/movement/tether.gd")
const SilkShader = preload("res://scripts/presentation/silk.gdshader")

## Widths on screen, in pixels at 1080p (scaled with the window's height, never below MIN_PX).
const ACTIVE_CORE_PX := 2.0
const LOADED_CORE_PX := 2.5     # taut or reeling: the line that is taking the weight
const RIM_PX := 1.25            # the light edge, each side of the core
const OLD_PX := 1.5             # an old line: one thin pale stroke
const MIN_PX := 1.0
## The core is never thinner than this in the world (WU, a diameter), so close up the line has some body. Beyond about
## 4 WU from the camera the pixel minimum above is what sets the width.
const CORE_WORLD := 0.012
## The strip is this many pixels wider each side than the rim, so that the one-pixel smoothing of its edges is centred
## on the edge it describes and a thin rim keeps its width and its brightness.
const AA_PX := 0.6
const ACTIVE_CORE_COLOR := Color(0.06, 0.07, 0.10)
const ACTIVE_RIM_COLOR := Color(0.97, 0.96, 0.92)
const OLD_COLOR := Color(0.93, 0.95, 0.98)
const ALPHA := 0.9               # an active or newest line; an old line's alpha is this times its fade
const OLD_OPACITY := 0.8         # how solid a fully drawn old line is (the active line is 1.0)
const SEGMENTS_PER_SPAN := 12    # points per straight span; a sagging span is a parabola
const FADE_SECONDS := 2.0
const POOL := 6                  # completed lines drawn at most (the motor keeps no more)

var motor: Node3D   # SpiderMotor
## For tests: the active line's drawn points, and how many completed lines are drawn and their alphas.
var shown_points: PackedVector3Array = PackedVector3Array()
var completed_alphas: Array[float] = []
## For tests: the active ribbon's last widths on screen, in pixels at the window's height: the core, and the whole strip.
var active_core_px: float = 0.0
var active_total_px: float = 0.0
## For tests: whether the active ribbon is drawn.
var active_visible: bool = false
## For tests: when above zero, the picture height in pixels to work from instead of the window's (a test window can be tiny).
var screen_height_override: float = 0.0

var _active: MeshInstance3D
var _pool: Array[MeshInstance3D] = []


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_priority = 100   # after the camera rig, so a ribbon faces this frame's camera
	_active = _make_line()
	for i in POOL:
		_pool.append(_make_line())


func _process(_delta: float) -> void:
	if motor != null:
		refresh()


## Rebuilds the drawing from the motor's line and completed lines.
func refresh() -> void:
	var t: RefCounted = motor.tether
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var px_h := screen_height_px()
	if t.is_active():
		var body: Vector3 = motor.get_global_transform_interpolated().origin
		shown_points = curve_points(t, motor.line_end_point() + _recoil_shift(), body)
	else:
		shown_points = PackedVector3Array()
	var loaded: bool = t.is_active() and (bool(t.taut) or motor.state == motor.State.REELING)
	var core_px := scaled_px(LOADED_CORE_PX if loaded else ACTIVE_CORE_PX, px_h)
	var rim_px := scaled_px(RIM_PX, px_h)
	_draw(_active, cam, shown_points, core_px, rim_px, ACTIVE_CORE_COLOR, ACTIVE_RIM_COLOR, 1.0 if t.is_active() else 0.0)
	active_core_px = core_px
	active_total_px = core_px + 2.0 * rim_px
	active_visible = _active.visible
	completed_alphas.clear()
	var lines: Array = motor.completed_lines
	var old_px := scaled_px(OLD_PX, px_h)
	for i in _pool.size():
		if i < lines.size():
			var line: Dictionary = lines[i]
			var alpha := ALPHA * clampf((float(line["life"]) - float(line["age"])) / FADE_SECONDS, 0.0, 1.0)
			completed_alphas.append(alpha)
			_draw(_pool[i], cam, line["points"], old_px, 0.0, OLD_COLOR, OLD_COLOR, alpha * OLD_OPACITY / ALPHA)
		else:
			_draw(_pool[i], cam, PackedVector3Array(), old_px, 0.0, OLD_COLOR, OLD_COLOR, 0.0)


## How far the catch recoil has moved the model from the body, in the world: the line's end goes with it.
func _recoil_shift() -> Vector3:
	var model := motor.get_node_or_null("Body")
	if model != null and model.get("launch_time") != null and model.launch_time >= 0.0:
		# Presentation lead-in only: the solver keeps its original anchor/length.
		return model.visual_spinneret_point() - motor.line_end_point()
	if model == null or not model.has_method("is_recoiling") or not model.is_recoiling():
		return Vector3.ZERO
	return motor.get_global_transform_interpolated().basis * model.recoil_offset


## For tests: the shader parameters of the active line, and of the i-th completed line.
func active_material() -> ShaderMaterial:
	return _active.material_override as ShaderMaterial


func old_material(i: int) -> ShaderMaterial:
	return _pool[i].material_override as ShaderMaterial


## The drawn points of a line: straight spans between anchor, bend and end, with the slack (paid length beyond the
## path to the body's centre, where the line is measured) hung as a parabola in the last span. `body` is the body's
## centre; a line that is not slack is straight, wherever the spinnerets are on the body.
static func curve_points(t: RefCounted, end: Vector3, body: Vector3) -> PackedVector3Array:
	var corners: PackedVector3Array = t.points(end)
	var out := PackedVector3Array([corners[0]])
	var slack := maxf(float(t.paid_length) - float(t.path_length(body)), 0.0) if t.is_locked() else 0.0
	for i in range(1, corners.size()):
		var a := corners[i - 1]
		var b := corners[i]
		var span := a.distance_to(b)
		var sag := Tether.sag_depth(span, span + slack) if i == corners.size() - 1 else 0.0
		var dir := (b - a) / span if span > 1e-5 else Vector3.ZERO
		var down := Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
		down = down.normalized() if down.length() > 1e-3 else Vector3.ZERO
		for k in range(1, SEGMENTS_PER_SPAN + 1):
			var s := float(k) / float(SEGMENTS_PER_SPAN)
			out.append(a.lerp(b, s) + down * (4.0 * sag * s * (1.0 - s)))
	return out


## The height of the picture in real pixels: the window's, or the viewport's inside a sub-viewport.
func screen_height_px() -> float:
	if screen_height_override > 0.0:
		return screen_height_override
	var viewport := get_viewport()
	if viewport == null:
		return 1080.0
	var window := get_window()
	if window != null and viewport == window and window.size.y > 0:
		return float(window.size.y)
	return maxf(float(viewport.get_visible_rect().size.y), 1.0)


## A width given in pixels at 1080p, as pixels at this height.
static func scaled_px(px_at_1080: float, px_height: float) -> float:
	return maxf(px_at_1080 * px_height / 1080.0, MIN_PX) if px_at_1080 > 0.0 else 0.0


## World length of one pixel at this depth along the view direction: 2 * depth * tan(fov / 2) / height in pixels.
static func pixel_size(depth: float, fov_deg: float, px_height: float) -> float:
	return 2.0 * maxf(depth, 0.01) * tan(deg_to_rad(fov_deg) * 0.5) / maxf(px_height, 1.0)


## The strip for a polyline seen from `cam_pos` looking along `cam_forward`: for each point two vertices, left and right
## of the line, perpendicular to it and to the view, half a strip apart. The core is core_px pixels wide (at least CORE_WORLD in
## the world), the rim rim_px each side, then AA_PX of margin for the edge smoothing, so the strip is never thinner on
## screen than asked. Returns {vertices, uv (x: -1 left to 1 right), core (the core's share of the half width, per
## vertex), edge (the share where the rim ends)}.
static func ribbon(points: PackedVector3Array, cam_pos: Vector3, cam_forward: Vector3, fov_deg: float, px_height: float, core_px: float, rim_px: float) -> Dictionary:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var core := PackedFloat32Array()
	var edge := PackedFloat32Array()
	var n := points.size()
	for i in n:
		var p := points[i]
		var before := points[maxi(i - 1, 0)]
		var after := points[mini(i + 1, n - 1)]
		var tangent := after - before
		var to_cam := cam_pos - p
		var side := tangent.cross(to_cam)
		if side.length_squared() < 1e-12:
			side = cam_forward.cross(Vector3.UP)
		if side.length_squared() < 1e-12:
			side = Vector3.RIGHT
		side = side.normalized()
		var px := pixel_size((p - cam_pos).dot(cam_forward), fov_deg, px_height)
		var core_half := maxf(core_px * 0.5 * px, CORE_WORLD * 0.5)
		var rim_half := core_half + rim_px * px
		var half := rim_half + AA_PX * px
		vertices.append(p - side * half)
		vertices.append(p + side * half)
		uv.append(Vector2(-1.0, 0.0))
		uv.append(Vector2(1.0, 0.0))
		core.append(core_half / half)
		core.append(core_half / half)
		edge.append(rim_half / half)
		edge.append(rim_half / half)
	return {"vertices": vertices, "uv": uv, "core": core, "edge": edge}


func _make_line() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0   # the strip is rebuilt every frame; never cull it by a stale box
	var m := ShaderMaterial.new()
	m.shader = SilkShader
	mi.material_override = m
	mi.visible = false
	add_child(mi)
	return mi


func _draw(mi: MeshInstance3D, cam: Camera3D, points: PackedVector3Array, core_px: float, rim_px: float, core_color: Color, rim_color: Color, opacity: float) -> void:
	var mesh := mi.mesh as ImmediateMesh
	mesh.clear_surfaces()
	if opacity <= 0.0 or points.size() < 2 or cam == null:
		mi.visible = false
		return
	var strip := ribbon(points, cam.global_position, -cam.global_transform.basis.z, cam.fov, screen_height_px(), core_px, rim_px)
	var vertices: PackedVector3Array = strip["vertices"]
	var uv: PackedVector2Array = strip["uv"]
	var core: PackedFloat32Array = strip["core"]
	var edge: PackedFloat32Array = strip["edge"]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in vertices.size():
		mesh.surface_set_uv(uv[i])
		mesh.surface_set_uv2(Vector2(core[i], edge[i]))
		mesh.surface_add_vertex(vertices[i])
	mesh.surface_end()
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("core_color", core_color)
	m.set_shader_parameter("rim_color", rim_color)
	m.set_shader_parameter("opacity", opacity)
	mi.visible = true
