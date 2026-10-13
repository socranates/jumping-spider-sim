extends CanvasLayer
## The start menu (LIFE round 5; MODES-01). It opens over a fresh world of the main life when the game starts, and from the pause menu.
##   * Continue this life: back to the main life's last rest (shown when there is one).
##   * Begin a new life: the main life on Standard (hunger and the wasp can kill). When a life is going on, a second press confirms it,
##     because the spider's story so far is put away.
##   * Begin a new life on Easy: shown once a spider of the main life has reached adulthood (nothing kills, hunger forgives). Until then
##     a line says how it opens.
##   * Free play: easy and relaxed, with its own save; it never counts toward finishing.
##   * The notebook, and Quit.
## It pauses the game while it is up. The control helps (presets, toggles, slow motion, text size) are in the pause menu in every mode.

const TITLE := "THE WINDOWSILL"
const SUBTITLE := "The life of a bold jumping spider"
const CONTINUE := "Continue this life"
const NEW_LIFE := "Begin a new life"
const NEW_LIFE_EASY := "Begin a new life on Easy"
const CONFIRM := "Begin a new life? Your spider's story so far ends (press again)"
const FREE := "Free play"
const NOTEBOOK := "Notebook"
const QUIT := "Quit"
const EASY_LOCKED := "Easy opens once one of your spiders has lived its whole life to adulthood."
const FREE_NOTE := "Free play: nothing on the sill can kill your spider, and it has its own save."

var world: Node3D
var settings: Node
var _panel: PanelContainer
var _continue: Button
var _new: Button
var _easy: Button
var _free: Button
var _notebook: Button
var _locked: Label
var _confirming := false


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	call_deferred("open")


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_confirming = false
	_new.text = NEW_LIFE
	var has_life: bool = world != null and bool(world.available_checkpoint()["ok"])
	_continue.visible = has_life
	var easy: bool = world != null and world.progress != null and world.progress.easy_unlocked()
	_easy.visible = easy
	_locked.visible = not easy
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_continue if has_life else _new).grab_focus()


func _close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Continue the main life from its last rest. Returns the new world (null when there is none).
func continue_life() -> Node3D:
	visible = false
	var back: Node3D = world.return_to_checkpoint()
	if back == null:
		open()
	return back


## A new main life in this world, on Standard or (when earned) on Easy. A life going on asks for a second press first. True when it began.
func new_life(easy: bool = false) -> bool:
	var has_life: bool = bool(world.available_checkpoint()["ok"])
	if has_life and not _confirming:
		_confirming = true
		_new.text = CONFIRM
		return false
	world.begin_new_life(easy)
	_close()
	return true


## Free play: its own world and save. Returns the new world.
func free_play() -> Node3D:
	visible = false
	return world.start_free_play()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var notebook_open: bool = world != null and world.get("notebook_panel") != null and world.notebook_panel.is_open()
	if notebook_open:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()  # the pause menu stays shut while choosing how to play


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.04, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.07, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(460.0, 0.0)
	_panel.add_child(box)
	box.add_child(_label(TITLE, 34, Color(0.96, 0.93, 0.84)))
	box.add_child(_label(SUBTITLE, 18, Color(0.78, 0.8, 0.72)))
	_continue = _button("Continue", CONTINUE, func() -> void: continue_life())
	box.add_child(_continue)
	_new = _button("NewLife", NEW_LIFE, func() -> void: new_life(false))
	box.add_child(_new)
	_easy = _button("NewLifeEasy", NEW_LIFE_EASY, func() -> void: new_life(true))
	box.add_child(_easy)
	_locked = _label(EASY_LOCKED, 15, Color(0.72, 0.74, 0.68))
	box.add_child(_locked)
	_free = _button("FreePlay", FREE, func() -> void: free_play())
	box.add_child(_free)
	box.add_child(_label(FREE_NOTE, 15, Color(0.72, 0.74, 0.68)))
	_notebook = _button("Notebook", NOTEBOOK, func() -> void:
		if world != null and world.get("notebook_panel") != null:
			world.notebook_panel.open("", _notebook))
	box.add_child(_notebook)
	var quit := _button("Quit", QUIT, func() -> void: get_tree().quit())
	quit.visible = not OS.has_feature("web")  # a page cannot close itself; the browser tab is the way out
	box.add_child(quit)


func _button(node_name: String, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(on_press)
	return b


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
