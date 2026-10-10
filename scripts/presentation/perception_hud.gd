extends CanvasLayer
## Perception presentation (spec 7, 17; T06, A-002): what the spider has sensed, as the player sees it. It reads the
## ObservationMemory and the camera and nothing else: it never asks the world where anything is, so nothing the spider has not
## sensed can appear in it (spec 6.4: camera-visible actors outside the spider's sensed information get no overlay).
##   * Peripheral cue: a soft glow with a small chevron on the edge of the screen, in the direction of the cue as the camera
##     sees it. The cue is coarse (a sector of 22.5 degrees and a band of elevation), and the marker says no more. It pulses at
##     each cue and fades over about a second. A thing that is being inspected has finer evidence (a place, a ring, words), so
##     its old bearing is no longer marked.
##   * Inspection: while a thing is being inspected, a thin ring at where it is observed, with its category in words under
##     the refinement it has reached: "movement", "possible prey", "fly-like prey". No numbers.
##   * Loss: the label turns to "lost sight" at the same place for a couple of seconds. The place does not move: it is where the
##     thing was last observed.
##   * The last-seen mark (A-002, setting "Show the last-seen mark", on by default): a faint dashed ring there, fixed to that
##     world position, that grows fainter and more broken with age and is gone when the memory is (or when the spot has been
##     inspected and found empty). It is memory, never tracking: it never moves, and it is fainter still where the world
##     hides the place from the camera (the usual case: the thing went behind cover), so that it reads as "it was here",
##     not as a view through the cover. Nothing is ever drawn at where a hidden thing really is.
##   * While Focus is held, four small ticks mark the centre of the screen, where the body will turn to face. When the player has
##     chosen to toggle Focus (A-026) a line of words at the top of the screen says it is on and how to stop it.
## A pure function of the memory, the camera and the settings builds the picture (build_view), so tests can check it without
## looking at pixels; _process only draws what it returns.

const Observation = preload("res://scripts/perception/observation.gd")
const PerceptionText = preload("res://scripts/presentation/perception_text.gd")
const JumpHud = preload("res://scripts/presentation/jump_hud.gd")

## Edge marker: shown for this long after a cue, strongest at EDGE_ALPHA, EDGE_MARGIN pixels in from the edge.
const CUE_SHOW_S := 1.4
const CUE_RISE_S := 0.12
const EDGE_ALPHA := 0.6
const EDGE_MARGIN := 34.0
## The "lost sight" words last this long (the mark outlives them).
const LOST_WORDS_S := 2.5
## The mark: how strong and how unbroken it is when fresh and when stale, and how many dashes it has.
const MARK_ALPHA_FRESH := 0.6
const MARK_ALPHA_STALE := 0.12
const MARK_DASH_FRESH := 1.0
const MARK_DASH_STALE := 0.3
const MARK_DASHES := 14
const RING_MIN_PX := 10.0
const RING_MAX_PX := 36.0
const LIVE_RING_ALPHA := 0.85
const LABEL_FONT_SIZE := 18
const LABEL_GAP_PX := 8.0
## A mark counts as covered when the world stops the camera's view of it more than this short of the target's own radius,
## and is then drawn at MARK_COVERED_FACTOR of its strength.
const MARK_HIDDEN_SLACK := 0.06
const MARK_COVERED_FACTOR := 0.6

var memory: RefCounted     # ObservationMemory
var settings: Node         # Settings autoload, or a test instance
var motor: Node3D          # SpiderMotor, for the focus ticks; optional
var controller: Node       # PlayerController, for the toggled-Focus note; optional

var _canvas: Control
var _labels: Array[Label] = []
var _focus_label: Label
var _view: Dictionary = {"edges": [], "labels": [], "rings": []}


func _ready() -> void:
	layer = 4
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)
	_focus_label = Label.new()
	_focus_label.name = "FocusNote"
	_focus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus_label.anchor_left = 0.5
	_focus_label.anchor_right = 0.5
	_focus_label.offset_left = -360.0
	_focus_label.offset_right = 360.0
	_focus_label.offset_top = 22.0
	_focus_label.offset_bottom = 54.0
	_focus_label.add_theme_font_size_override("font_size", 20)
	_focus_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_focus_label.add_theme_constant_override("outline_size", 6)
	_focus_label.visible = false
	add_child(_focus_label)
	if settings == null:
		settings = get_node_or_null("/root/Settings")


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var space: PhysicsDirectSpaceState3D = null
	if motor != null and is_instance_valid(motor):
		space = motor.get_world_3d().direct_space_state
	_view = build_view(cam, get_viewport().get_visible_rect(), space)
	_apply_labels()
	var note := focus_note()
	_focus_label.text = note
	_focus_label.visible = note != ""
	_canvas.queue_redraw()


## The picture of the memory seen through `cam`, as data: edge markers {track_id, pos, dir, alpha}, labels {track_id, text, pos,
## alpha, kind: "category" or "lost"} and rings {track_id, pos, radius, alpha, dash, kind: "live" or "mark", stale, covered}. `space`
## is the physics space the covered-mark test casts in (null skips the test).
func build_view(cam: Camera3D, rect: Rect2, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var edges: Array[Dictionary] = []
	var labels: Array[Dictionary] = []
	var rings: Array[Dictionary] = []
	var out := {"edges": edges, "labels": labels, "rings": rings}
	if cam == null or memory == null:
		return out
	var show_mark: bool = settings == null or bool(settings.get_value("show_last_seen"))
	for c: RefCounted in memory.contacts():
		if c.cue_count > 0 and c.cue_direction.length_squared() > 0.5 and not c.is_inspected_now():
			var cue_age: float = memory.cue_age_s(c)
			if cue_age >= 0.0 and cue_age < CUE_SHOW_S:
				var e := edge_marker(cam, rect, c.cue_direction)
				e["track_id"] = c.track_id
				e["alpha"] = EDGE_ALPHA * edge_fade(cue_age)
				edges.append(e)
		if not c.has_position:
			continue
		var at: Vector3 = c.position
		if cam.is_position_behind(at):
			continue
		var screen := cam.unproject_position(at)
		if not rect.grow(40.0).has_point(screen):
			continue
		var radius := ring_radius_px(cam, at, c.size_wu)
		if c.is_inspected_now():
			rings.append({"track_id": c.track_id, "pos": screen, "radius": radius, "alpha": LIVE_RING_ALPHA, "dash": 1.0, "kind": "live", "stale": 0.0, "covered": false})
			labels.append({"track_id": c.track_id, "text": PerceptionText.category(c.category), "pos": screen + Vector2(0.0, -(radius + LABEL_GAP_PX)), "alpha": 1.0, "kind": "category"})
		elif c.has_mark():
			var covered: bool = space != null and JumpHud.point_hidden(cam, space, at, rect, maxf(c.size_wu, 0.2) * 0.5 + MARK_HIDDEN_SLACK)
			var stale: float = memory.staleness_of(c)
			if show_mark:
				var strength := lerpf(MARK_ALPHA_FRESH, MARK_ALPHA_STALE, stale) * (MARK_COVERED_FACTOR if covered else 1.0)
				rings.append({"track_id": c.track_id, "pos": screen, "radius": radius, "alpha": strength, "dash": lerpf(MARK_DASH_FRESH, MARK_DASH_STALE, stale), "kind": "mark", "stale": stale, "covered": covered})
			var age: float = memory.age_s(c)
			if age < LOST_WORDS_S:
				labels.append({"track_id": c.track_id, "text": PerceptionText.LOST, "pos": screen + Vector2(0.0, -(radius + LABEL_GAP_PX)), "alpha": clampf(1.0 - age / LOST_WORDS_S, 0.0, 1.0), "kind": "lost"})
	return out


## The strength of an edge marker `age` seconds after its cue: a quick rise, then a fade (1 at its strongest).
static func edge_fade(age: float) -> float:
	if age < 0.0 or age >= CUE_SHOW_S:
		return 0.0
	var rise := smoothstep(0.0, CUE_RISE_S, age)
	var fall := pow(clampf(1.0 - age / CUE_SHOW_S, 0.0, 1.0), 1.5)
	return rise * fall


## Where on the screen's edge a cue in world direction `dir` is marked: the screen-space direction of that bearing as the
## camera sees it, taken out to the rectangle `margin` pixels inside the screen. {pos, dir (unit, screen space), behind}.
## A bearing straight along the view axis has no side to it, so it is put on the top edge.
static func edge_marker(cam: Camera3D, rect: Rect2, dir: Vector3, margin: float = EDGE_MARGIN) -> Dictionary:
	var local := cam.global_transform.basis.inverse() * dir.normalized()
	var v := Vector2(local.x, -local.y)
	if v.length() < 0.03:
		v = Vector2(0.0, -1.0)
	v = v.normalized()
	var half := rect.size * 0.5 - Vector2(margin, margin)
	var t := minf(half.x / maxf(absf(v.x), 1e-6), half.y / maxf(absf(v.y), 1e-6))
	return {"pos": rect.get_center() + v * t, "dir": v, "behind": local.z > 0.0}


## The radius, in pixels, of the ring drawn round a thing `size_wu` across at `at`: as it looks, kept between a readable
## minimum and a maximum.
static func ring_radius_px(cam: Camera3D, at: Vector3, size_wu: float) -> float:
	var right := cam.global_transform.basis.x
	var a := cam.unproject_position(at)
	var b := cam.unproject_position(at + right * maxf(size_wu, 0.2) * 0.5)
	return clampf(a.distance_to(b), RING_MIN_PX, RING_MAX_PX)


## The words that tell a player who toggles Focus that it is on and how to end it (A-026); empty in hold mode and while it is off.
func focus_note() -> String:
	if controller == null or not is_instance_valid(controller) or not controller.has_method("is_focus_latched") or not controller.is_focus_latched():
		return ""
	var stop: String = PerceptionText.FOCUS_STOP_OR_CANCEL if controller.cancel_stops_focus() else PerceptionText.FOCUS_STOP
	return "%s    %s" % [PerceptionText.FOCUS_ON, stop]


## The texts of the labels on show (tests).
func label_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for l in _labels:
		if l.visible:
			out.append(l.text)
	return out


func view() -> Dictionary:
	return _view


func _apply_labels() -> void:
	var wanted: Array = _view["labels"]
	while _labels.size() < wanted.size():
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
		l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		l.add_theme_constant_override("outline_size", 5)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(l)
		_labels.append(l)
	for i in _labels.size():
		var l := _labels[i]
		if i >= wanted.size():
			l.visible = false
			continue
		var d: Dictionary = wanted[i]
		l.text = str(d["text"])
		l.reset_size()
		l.position = (d["pos"] as Vector2) - Vector2(l.size.x * 0.5, l.size.y)
		var tint := Color(1.0, 1.0, 1.0) if str(d["kind"]) == "category" else Color(0.86, 0.9, 1.0)
		l.add_theme_color_override("font_color", Color(tint, float(d["alpha"])))
		l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9 * float(d["alpha"])))
		l.visible = true


func _draw_canvas() -> void:
	for e: Dictionary in _view["edges"]:
		_draw_edge(e)
	for r: Dictionary in _view["rings"]:
		_draw_ring(r)
	if motor != null and is_instance_valid(motor) and motor.has_method("is_focusing") and motor.is_focusing():
		_draw_focus_ticks()


func _draw_edge(e: Dictionary) -> void:
	var pos: Vector2 = e["pos"]
	var dir: Vector2 = e["dir"]
	var alpha: float = e["alpha"]
	if alpha <= 0.002:
		return
	var tint := Color(0.82, 0.93, 1.0)
	# A dark halo first, so that the marker reads on a pale wall, then a light one, so that it reads on a dark one.
	for i in 4:
		var halo := lerpf(64.0, 26.0, float(i) / 3.0)
		_canvas.draw_circle(pos, halo, Color(0.0, 0.05, 0.12, alpha * (0.05 + 0.05 * float(i))))
	for i in 6:
		var radius := lerpf(54.0, 14.0, float(i) / 5.0)
		_canvas.draw_circle(pos, radius, Color(tint, alpha * (0.05 + 0.07 * float(i))))
	var side := Vector2(-dir.y, dir.x)
	var tip := pos + dir * 15.0
	var shadow := PackedVector2Array([tip + dir * 3.5, pos - dir * 7.5 + side * 13.0, pos - dir * 7.5 - side * 13.0])
	_canvas.draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, minf(alpha * 1.3, 0.8)))
	var chevron := PackedVector2Array([tip, pos - dir * 4.0 + side * 9.5, pos - dir * 4.0 - side * 9.5])
	_canvas.draw_colored_polygon(chevron, Color(1.0, 1.0, 1.0, minf(alpha * 1.6, 0.97)))


func _draw_ring(r: Dictionary) -> void:
	var pos: Vector2 = r["pos"]
	var radius: float = r["radius"]
	var alpha: float = r["alpha"]
	var tint := Color(1.0, 1.0, 1.0) if str(r["kind"]) == "live" else Color(0.86, 0.9, 1.0)
	var dash: float = r["dash"]
	if dash >= 0.999:
		_canvas.draw_arc(pos, radius, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, alpha * 0.5), 3.6, true)
		_canvas.draw_arc(pos, radius, 0.0, TAU, 48, Color(tint, alpha), 1.6, true)
		return
	var slot := TAU / float(MARK_DASHES)
	for i in MARK_DASHES:
		var a0 := float(i) * slot
		var a1 := a0 + slot * dash
		_canvas.draw_arc(pos, radius, a0, a1, 6, Color(0.0, 0.0, 0.0, alpha * 0.5), 3.6, true)
		_canvas.draw_arc(pos, radius, a0, a1, 6, Color(tint, alpha), 1.6, true)


func _draw_focus_ticks() -> void:
	var c := _canvas.size * 0.5
	var col := Color(1.0, 1.0, 1.0, 0.8)
	var shadow := Color(0.0, 0.0, 0.0, 0.6)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_canvas.draw_line(c + d * 7.0, c + d * 14.0, shadow, 4.0, true)
		_canvas.draw_line(c + d * 7.0, c + d * 14.0, col, 1.6, true)
