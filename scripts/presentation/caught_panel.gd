extends CanvasLayer
## What follows when the mud dauber has caught the spider (LIFE round 4; LIFE-01: "death can be real and jarring. not sensationalized but
## my kids are allowed to encounter reality"). Plain and brief: the world goes quiet and dim for a moment, one plain line says what
## happened, and then the way on. No gore, no score, nothing lingered on. Round 4 offers the way back to the last rest (or a new start
## when there is none) and the notebook; round 5 builds the life's summary and continuing as another spider on this.
## It pauses the game while it is up and takes the keys and buttons first, so the pause menu does not open over it.


const QUIET_S := 1.5   # dim and quiet before the line
const LINE_S := 1.5    # the line alone before the choices
const LINE := "A mud dauber wasp stung the spider and carried it away."
const SUB := "Its sting does not kill: it paralyses. The notebook says what happens next."
const BACK := "Back to your last rest"
const AGAIN := "Start a new life"
const NOTEBOOK := "Read the notebook"

var world: Node3D
var settings: Node
var shown_seconds := 0.0
var _dim: ColorRect
var _box: VBoxContainer
var _line: Label
var _sub: Label
var _buttons: HBoxContainer
var _back: Button
var _notebook: Button
var _hidden_hud: Array[CanvasLayer] = []


func _ready() -> void:
	layer = 20  # under the notebook (21), which opens over it
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func is_showing() -> bool:
	return visible


## The wasp has carried the spider off: the quiet, the line, then the choices.
func show_caught() -> void:
	# Large text can overlap in the live HUD. The catch has its own message;
	# keep that quiet screen clear, while leaving the notebook above it usable.
	for node in world.find_children("*", "CanvasLayer", true, false) if world != null else []:
		if node != self and node.layer < layer and node.visible:
			_hidden_hud.append(node)
			node.visible = false
	visible = true
	shown_seconds = 0.0
	_dim.color.a = 0.0
	_box.visible = false
	_buttons.visible = false
	var has_rest: bool = world != null and bool(world.available_checkpoint()["ok"])
	_back.text = BACK if has_rest else AGAIN
	_back.set_meta("has_rest", has_rest)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if not visible:
		return
	shown_seconds += delta
	_dim.color.a = clampf(shown_seconds / QUIET_S, 0.0, 1.0) * 0.82
	if shown_seconds >= QUIET_S and not _box.visible:
		_box.visible = true
	if shown_seconds >= QUIET_S + LINE_S and not _buttons.visible:
		_buttons.visible = true
		_back.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var notebook_open: bool = world != null and world.get("notebook_panel") != null and world.notebook_panel.is_open()
	if notebook_open:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()  # the pause menu stays shut: the choice is here
	elif _buttons.visible and (event.is_action_pressed("interact") or event.is_action_pressed("prepare_jump")) and not event.is_echo():
		get_viewport().set_input_as_handled()
		go_on()


## Takes the first choice: back to the last rest, or a new life when there is none. Returns the new world.
func go_on() -> Node3D:
	if world == null:
		return null
	for hud in _hidden_hud:
		if is_instance_valid(hud):
			hud.visible = true
	_hidden_hud.clear()
	visible = false
	if bool(_back.get_meta("has_rest", false)):
		var back: Node3D = world.return_to_checkpoint()
		if back != null:
			return back
	return world.start_new_life()


func _open_notebook() -> void:
	if world != null and world.get("notebook_panel") != null:
		world.notebook_panel.open("wasp_caught", _notebook)


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
	_box.offset_left = -420.0
	_box.offset_right = 420.0
	_box.offset_top = -90.0
	_box.offset_bottom = 120.0
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 14)
	add_child(_box)
	_line = _label(LINE, 28, Color(0.95, 0.93, 0.88))
	_box.add_child(_line)
	_sub = _label(SUB, 18, Color(0.8, 0.79, 0.74))
	_box.add_child(_sub)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	_box.add_child(_buttons)
	_back = Button.new()
	_back.name = "Back"
	_back.text = BACK
	_back.add_theme_font_size_override("font_size", 20)
	_back.pressed.connect(func() -> void: go_on())
	_buttons.add_child(_back)
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
