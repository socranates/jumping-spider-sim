extends CanvasLayer
## The end of a life (LIFE rounds 4 and 5; LIFE-01: "death can be real and jarring. not sensationalized but my kids are allowed to
## encounter reality"; LIFE-03; spec 11: "a life summary emphasizes places, escapes, rests, and changes, not kills or rank. Let the player
## skip it"). Plain and brief: the world goes quiet and dim for a moment, one plain line says what happened, then a short summary of the
## life and the way on: back to the last rest (the checkpoint), or on as another spider, a young juvenile unrelated to the last; and the
## notebook. No gore, no score, nothing lingered on. The summary is part of the screen, so choosing at once skips it.
## It pauses the game while it is up, hides the HUD under it (large text stays clear), and takes the keys and buttons first, so the
## pause menu does not open over it.

const QUIET_S := 1.5   # dim and quiet before the line
const LINE_S := 1.5    # the line alone before the summary and the choices
## What happened, by cause, and a second plain line.
const LINES := {
	"wasp": ["A mud dauber wasp stung the spider and carried it away.", "Its sting does not kill: it paralyses. The notebook says what happens next."],
	"starved": ["The spider starved.", "Its reserve ran out, and it went too long without food to recover."],
}
const LINE := "A mud dauber wasp stung the spider and carried it away."
const BACK := "Back to your last rest"
const ANOTHER := "Continue as another spider"
const NOTEBOOK := "Read the notebook"
## The notebook page each cause opens on.
const PAGES := {"wasp": "what_the_wasp_does", "starved": "going_without_food"}

var world: Node3D
var settings: Node
var shown_seconds := 0.0
var cause := ""
var summary: Dictionary = {}
var _dim: ColorRect
var _box: VBoxContainer
var _line: Label
var _sub: Label
var _summary: Label
var _buttons: VBoxContainer
var _back: Button
var _another: Button
var _notebook: Button
var _hidden_hud: Array[CanvasLayer] = []


func _ready() -> void:
	layer = 20  # under the notebook (21), which opens over it
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func is_showing() -> bool:
	return visible


## The wasp carried the spider off (round 4's entry; the world's end_life calls show_end).
func show_caught() -> void:
	show_end("wasp", world.life_summary("wasp") if world != null and world.has_method("life_summary") else {})


## The life has ended by `cause`: the quiet, the line, then the summary and the choices.
func show_end(p_cause: String, p_summary: Dictionary) -> void:
	cause = p_cause
	summary = p_summary
	# Large text can overlap in the live HUD. The end has its own message;
	# keep that quiet screen clear, while leaving the notebook above it usable.
	for node in world.find_children("*", "CanvasLayer", true, false) if world != null else []:
		if node != self and node.layer < layer and node.visible:
			_hidden_hud.append(node)
			node.visible = false
	var lines: Array = LINES.get(cause, ["The spider's life has ended.", ""])
	_line.text = str(lines[0])
	_sub.text = str(lines[1])
	_sub.visible = _sub.text != ""
	_summary.text = summary_text(summary)
	visible = true
	shown_seconds = 0.0
	_dim.color.a = 0.0
	_box.visible = false
	_summary.visible = false
	_buttons.visible = false
	var has_rest: bool = world != null and bool(world.available_checkpoint()["ok"])
	_back.visible = has_rest
	_back.set_meta("has_rest", has_rest)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## The life in a few plain lines: how long it lived, how far it grew, its meals, the wasp. Never a score.
static func summary_text(s: Dictionary) -> String:
	if s.is_empty():
		return ""
	var hours := float(s.get("hours", 0.0))
	var lived := "less than a day"
	if hours >= 24.0:
		var days := floori(hours / 24.0)
		lived = "%d day%s" % [days, "" if days == 1 else "s"]
	var stage := int(s.get("stage", 0))
	var grew := "%s, %d moult%s" % [str(s.get("stage_name", "")), stage, "" if stage == 1 else "s"]
	var meals := int(s.get("meals", 0))
	var out: Array[String] = ["It lived %s." % lived, "It grew to a %s." % grew,
		"It ate %d meal%s." % [meals, "" if meals == 1 else "s"]]
	var visits := int(s.get("wasp_visits", 0))
	if visits > 0:
		var escapes := int(s.get("wasp_escapes", 0))
		out.append("The wasp came %d time%s; it got away from it %d time%s." % [visits, "" if visits == 1 else "s", escapes, "" if escapes == 1 else "s"])
	return "\n".join(out)


func _process(delta: float) -> void:
	if not visible:
		return
	shown_seconds += delta
	_dim.color.a = clampf(shown_seconds / QUIET_S, 0.0, 1.0) * 0.82
	if shown_seconds >= QUIET_S and not _box.visible:
		_box.visible = true
	if shown_seconds >= QUIET_S + LINE_S and not _buttons.visible:
		_summary.visible = _summary.text != ""
		_buttons.visible = true
		(_back if _back.visible else _another).grab_focus()
	var width := minf(880.0, get_viewport().get_visible_rect().size.x - 48.0)
	_box.offset_left = -width * 0.5
	_box.offset_right = width * 0.5
	var height := maxf(340.0, _box.get_combined_minimum_size().y)
	_box.offset_top = -height * 0.5
	_box.offset_bottom = height * 0.5


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var notebook_open: bool = world != null and world.get("notebook_panel") != null and world.notebook_panel.is_open()
	if notebook_open:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()  # the pause menu stays shut: the choice is here
	elif _buttons.visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("prepare_jump")) and not event.is_echo():
		get_viewport().set_input_as_handled()
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and _buttons.is_ancestor_of(focused):
			focused.pressed.emit()
		else:
			go_on()


## Takes the first choice: back to the last rest, or on as another spider when there is none. Returns the new world.
func go_on() -> Node3D:
	if world == null:
		return null
	if bool(_back.get_meta("has_rest", false)):
		_close()
		var back: Node3D = world.return_to_checkpoint()
		if back != null:
			return back
	return go_on_as_another()


## On as another spider (LIFE-03). Returns the new world.
func go_on_as_another() -> Node3D:
	if world == null:
		return null
	_close()
	return world.continue_as_another()


func _close() -> void:
	for hud in _hidden_hud:
		if is_instance_valid(hud):
			hud.visible = true
	_hidden_hud.clear()
	visible = false


func _open_notebook() -> void:
	if world != null and world.get("notebook_panel") != null:
		world.notebook_panel.open(str(PAGES.get(cause, "")), _notebook)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.02, 0.03, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER)
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 0.5
	_box.anchor_bottom = 0.5
	_box.offset_left = -440.0
	_box.offset_right = 440.0
	_box.offset_top = -170.0
	_box.offset_bottom = 170.0
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 14)
	add_child(_box)
	_line = _label(LINE, 28, Color(0.95, 0.93, 0.88))
	_box.add_child(_line)
	_sub = _label("", 18, Color(0.8, 0.79, 0.74))
	_box.add_child(_sub)
	_summary = _label("", 18, Color(0.88, 0.86, 0.8))
	_summary.name = "Summary"
	_box.add_child(_summary)
	_buttons = VBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	_box.add_child(_buttons)
	_back = Button.new()
	_back.name = "Back"
	_back.text = BACK
	_back.add_theme_font_size_override("font_size", 20)
	_back.pressed.connect(func() -> void: go_on())
	_buttons.add_child(_back)
	_another = Button.new()
	_another.name = "Another"
	_another.text = ANOTHER
	_another.add_theme_font_size_override("font_size", 20)
	_another.pressed.connect(func() -> void: go_on_as_another())
	_buttons.add_child(_another)
	_notebook = Button.new()
	_notebook.name = "Notebook"
	_notebook.text = NOTEBOOK
	_notebook.add_theme_font_size_override("font_size", 20)
	_notebook.pressed.connect(_open_notebook)
	_buttons.add_child(_notebook)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	return l
