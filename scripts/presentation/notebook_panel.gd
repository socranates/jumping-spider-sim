extends CanvasLayer
## The naturalist's notebook on screen (LEARN-01). N (controller: D-pad up), or "Notebook" in the Esc menu, opens it; the game waits while
## it is open. On the left, the pages found so far, newest first-found at the top of its own order; on the right, the page: a few true
## sentences, "In this game" where the game simplifies, and the sources. When a page opens during play a short note says so at the bottom
## left for a few seconds (the setting "notebook_notes" turns the note off; the pages still open). No counts of pages left to find (spec 4).
## Built in code; readable with the keyboard, the mouse or a controller.

const KeyNames = preload("res://scripts/presentation/key_names.gd")

const NOTE_S := 6.0
## Half the width of the prompts centred at the bottom of the screen (JumpHud's line panel, NeedsHud's prey prompts): the note stays left of them.
const NOTE_CLEAR := 380.0
const KEY_HINT := "N / D-pad up"

var notebook: Node     # FieldNotebook
var settings: Node
## The id shown on the right ("" when none).
var shown: String = ""
## Whether the notebook was opened over the Esc menu (closing it then goes back to the menu).
var opened_from_menu: bool = false
var note_left: float = 0.0

var _dim: ColorRect
var _panel: PanelContainer
var _list: VBoxContainer
var _title: Label
var _body: Label
var _game: Label
var _sources: Label
var _empty: Label
var _close: Button
var _note: Label
var _buttons: Dictionary = {}   # page id -> Button
var _menu_return: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 21
	_build()
	_set_open(false)
	if notebook != null:
		notebook.page_opened.connect(_on_page_opened)


func is_open() -> bool:
	return _panel.visible


## Opens the notebook at a page (the newest found when "" is given). From the Esc menu, `return_to` gets the focus back on closing.
func open(at: String = "", return_to: Control = null) -> void:
	opened_from_menu = get_tree().paused
	_menu_return = return_to
	if not opened_from_menu:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rebuild_list()
	var id := at
	if id == "" and notebook != null and not notebook.opened.is_empty():
		id = notebook.opened[notebook.opened.size() - 1]
	show_page(id)
	_set_open(true)
	if _buttons.has(shown):
		(_buttons[shown] as Button).grab_focus()
	else:
		_close.grab_focus()


func close() -> void:
	_set_open(false)
	if opened_from_menu:
		if _menu_return != null and is_instance_valid(_menu_return) and _menu_return.is_visible_in_tree():
			_menu_return.grab_focus()
	else:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func show_page(id: String) -> void:
	shown = id
	var p: Dictionary = notebook.page(id) if notebook != null and id != "" else {}
	_empty.visible = p.is_empty()
	_title.visible = not p.is_empty()
	_body.visible = not p.is_empty()
	_sources.visible = not p.is_empty()
	_game.visible = not p.is_empty() and str(p.get("game", "")) != ""
	if p.is_empty():
		return
	_title.text = str(p["title"])
	_body.text = str(p["text"])
	_game.text = "In this game: " + KeyNames.apply(str(p.get("game", "")), settings)
	var lines: Array[String] = []
	for s: Variant in p.get("sources", []):
		lines.append(str(s))
	_sources.text = ("Source: " if lines.size() == 1 else "Sources:\n") + "\n".join(lines)
	for pid: String in _buttons:
		(_buttons[pid] as Button).button_pressed = pid == id


func _input(event: InputEvent) -> void:
	if is_open():
		# Closing: the notebook key (from the keyboard; the D-pad moves through the pages), Esc / Menu, or B.
		var key_close := event.is_action_pressed("notebook") and event is InputEventKey
		if key_close or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
			close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("notebook") and not get_tree().paused:
		open()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if note_left > 0.0:
		note_left = maxf(note_left - delta, 0.0)
		_note.modulate.a = clampf(note_left / 0.8, 0.0, 1.0)
		_note.visible = note_left > 0.0 and not is_open()
		_place_note()


func _on_page_opened(id: String) -> void:
	if is_open():
		_rebuild_list()
	if settings != null and not bool(settings.get_value("notebook_notes")):
		return
	var p: Dictionary = notebook.page(id)
	_note.text = KeyNames.apply("New in your notebook: %s\n(%s to read)" % [str(p.get("title", "")), KEY_HINT], settings)
	note_left = NOTE_S
	_note.visible = not is_open()
	_place_note()


## Bottom left, above the energy bar, and wrapped to stay left of the prompts centred at the bottom (the line's controls, eating
## and resting), which are NOTE_CLEAR either side of the centre.
func _place_note() -> void:
	var size := _note.get_viewport_rect().size
	_note.size = Vector2(maxf(size.x * 0.5 - NOTE_CLEAR - 40.0, 160.0), 0.0)
	var want := _note.get_minimum_size()
	_note.size = Vector2(_note.size.x, want.y)
	_note.position = Vector2(24.0, size.y - 64.0 - want.y)


func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_buttons.clear()
	if notebook == null:
		return
	for id: String in notebook.opened:
		var b := Button.new()
		b.name = "Page_" + id
		b.text = str(notebook.page(id).get("title", id))
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(show_page.bind(id))
		b.focus_entered.connect(show_page.bind(id))
		_list.add_child(b)
		_buttons[id] = b


func _set_open(on: bool) -> void:
	_dim.visible = on
	_panel.visible = on
	if on:
		_note.visible = false


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_panel = PanelContainer.new()
	_panel.name = "Notebook"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 60.0
	_panel.offset_right = -60.0
	_panel.offset_top = 40.0
	_panel.offset_bottom = -40.0
	var theme := Theme.new()
	theme.default_font_size = 20
	_panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.90, 0.82, 0.98)   # paper
	style.border_color = Color(0.45, 0.38, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_panel.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	var heading := Label.new()
	heading.text = "Naturalist's notebook"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color(0.20, 0.16, 0.10))
	outer.add_child(heading)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 22)
	outer.add_child(row)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(300.0, 0.0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.name = "Pages"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list)
	var page_scroll := ScrollContainer.new()
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(page_scroll)
	var page_box := VBoxContainer.new()
	page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_box.add_theme_constant_override("separation", 14)
	page_scroll.add_child(page_box)
	_title = _paper_label(26, Color(0.20, 0.16, 0.10))
	_title.name = "Title"
	page_box.add_child(_title)
	_body = _paper_label(20, Color(0.15, 0.13, 0.10))
	_body.name = "Text"
	page_box.add_child(_body)
	_game = _paper_label(18, Color(0.18, 0.32, 0.22))
	_game.name = "InThisGame"
	page_box.add_child(_game)
	_sources = _paper_label(15, Color(0.35, 0.30, 0.24))
	_sources.name = "Sources"
	page_box.add_child(_sources)
	_empty = _paper_label(20, Color(0.30, 0.26, 0.20))
	_empty.text = "Pages appear here as you play."
	page_box.add_child(_empty)
	_close = Button.new()
	_close.name = "Close"
	_close.text = "Close"
	_close.custom_minimum_size = Vector2(140.0, 0.0)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close.pressed.connect(close)
	outer.add_child(_close)
	_note = Label.new()
	_note.name = "NotebookNote"
	_note.add_theme_font_size_override("font_size", 18)
	_note.add_theme_color_override("font_color", Color(0.96, 0.93, 0.82))
	_note.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_note.add_theme_constant_override("outline_size", 6)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	add_child(_note)


func _paper_label(size: int, colour: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
