extends CanvasLayer
## Pause panel, built in code. Esc or the controller menu button (action "pause") toggles it.
## Pausing sets get_tree().paused and shows the mouse; resuming hides it again.
## Changes are written through to Settings, which saves on every change.

const KeyNames = preload("res://scripts/presentation/key_names.gd")
const InputSetupScript = preload("res://scripts/core/input_setup.gd")

var settings: Node  # Settings autoload, or a test instance
## T09: the world, for "Return to checkpoint" (null in a menu built on its own).
var world: Node
var _checkpoint_button: Button
var _checkpoint_label: Label
## T09 (U01): keyboard remapping. The action waiting for a key ("" when none), its buttons and the line that says what happened.
## T09d: the same list remaps controller buttons; _listening_pad says the action waits for a button rather than a key.
var _listening: String = ""
var _listening_pad: bool = false
var _key_buttons: Dictionary = {}  # action -> Button
var _pad_buttons: Dictionary = {}  # action -> Button (disabled for the actions on a stick)
var _keys_grid: GridContainer
## T09d: assisted-play presets.
var _preset_buttons: Dictionary = {}  # preset id -> Button
var _preset_note: Label
var _keys_box: Control
var _keys_toggle: Button
var _keys_status: Label
var _scroll: ScrollContainer
var _switches: GridContainer
var _dragging: Dictionary = {}  # setting key -> true while the mouse drags that slider
var _content: VBoxContainer

var _dim: ColorRect
var _panel: PanelContainer
var _resume_button: Button
var _sliders: Dictionary = {}  # setting key -> HSlider
var _checks: Dictionary = {}   # setting key -> CheckBox
var _value_labels: Dictionary = {}  # setting key -> Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	if settings == null:
		settings = get_node("/root/Settings")
	_build()
	visible = false


func _input(event: InputEvent) -> void:
	if _listening != "" and visible:
		_listen(event)
		return
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused:
		_refresh()
		_refresh_checkpoint()
		_refresh_keys()
		_fit_to_screen()
		_resume_button.grab_focus()
	else:
		_listening = ""
		_listening_pad = false


func _refresh() -> void:
	for key: String in _sliders:
		var slider: HSlider = _sliders[key]
		slider.set_value_no_signal(settings.get_value(key))
		_update_value_label(key, slider.value)
	for key: String in _checks:
		var check: CheckBox = _checks[key]
		var on: bool = settings.get_value(key)
		check.set_pressed_no_signal(on)
		check.set_meta("label", KeyNames.apply(String(check.get_meta("default_label", check.get_meta("label"))), settings))
		check.text = _check_text(String(check.get_meta("label")), on)
	_refresh_presets()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.5)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	var theme := Theme.new()
	theme.default_font_size = 20
	_panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.24, 0.29, 0.97)
	style.border_color = Color(0.62, 0.68, 0.78)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_panel.add_child(margin)
	# T09: the panel scrolls when it is taller than the window (larger text, the key list).
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_scroll.add_child(box)
	_content = box
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	_build_presets(box)
	_add_slider(box, "look_sensitivity", "Look sensitivity", 0.05, "%.2f")
	_add_slider(box, "fov_degrees", "Field of view", 1.0, "%d deg")
	_add_slider(box, "camera_distance", "Camera distance", 0.1, "%.1f WU")
	_add_slider(box, "jump_reach", "Jump reach (playtest)", 0.05, "pct")
	_add_slider(box, "ui_scale", "Text and panel size", 0.05, "pct")
	# The switches go in two columns so the panel stays inside a 720 px window (chunk 6B added three, chunk 7A one).
	var switches := GridContainer.new()
	switches.name = "Switches"
	switches.columns = 2
	_switches = switches
	switches.add_theme_constant_override("h_separation", 28)
	switches.add_theme_constant_override("v_separation", 2)
	box.add_child(switches)
	_add_check(switches, "invert_x", "Invert look X")
	_add_check(switches, "invert_y", "Invert look Y")
	_add_check(switches, "stalk_toggle", "Stalk toggles (instead of hold)")
	_add_check(switches, "prepare_toggle", "Jump aim toggles (press, press)")
	_add_check(switches, "focus_toggle", "Focus toggles (press to start and stop)")
	_add_check(switches, "detailed_arc", "Show the jump arc while aiming")
	_add_check(switches, "release_hold", "Hold Q / B to let go of the line")
	_add_check(switches, "frame_line_after_catch", "Frame the line after a catch")
	_add_check(switches, "show_last_seen", "Show the last-seen mark")
	_add_check(switches, "show_gaze", "Show where the spider looks")
	_add_check(switches, "capture_assist", "Strike assist: a wider reach for the bite")
	_add_check(switches, "struggle_auto", "Struggling prey: hold on automatically")
	_add_check(switches, "reduced_motion", "Reduced motion (a calmer spider body)")
	_add_check(switches, "eye_view", "Spider-eye view (first person, V / Y)")
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_resume_button = Button.new()
	_resume_button.text = "Resume"
	_resume_button.custom_minimum_size = Vector2(140.0, 0.0)
	_resume_button.pressed.connect(set_paused.bind(false))
	buttons.add_child(_resume_button)
	_checkpoint_button = Button.new()
	_checkpoint_button.name = "ReturnToCheckpoint"
	_checkpoint_button.text = "Return to checkpoint"
	_checkpoint_button.pressed.connect(_on_return_to_checkpoint)
	buttons.add_child(_checkpoint_button)
	_keys_toggle = Button.new()
	_keys_toggle.name = "KeysToggle"
	_keys_toggle.text = "Keys and buttons..."
	_keys_toggle.pressed.connect(func() -> void:
		_keys_box.visible = not _keys_box.visible
		_keys_toggle.text = "Hide keys" if _keys_box.visible else "Keys and buttons..."
		_fit_to_screen()
		if _keys_box.visible:
			_scroll.call_deferred("ensure_control_visible", _keys_box))
	buttons.add_child(_keys_toggle)
	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(140.0, 0.0)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(quit_button)
	_checkpoint_label = Label.new()
	_checkpoint_label.name = "CheckpointStatus"
	_checkpoint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_checkpoint_label.custom_minimum_size = Vector2(560.0, 0.0)
	_checkpoint_label.add_theme_font_size_override("font_size", 16)
	box.add_child(_checkpoint_label)
	_build_keys(box)
	_refresh()
	_refresh_checkpoint()


func _add_slider(parent: Control, key: String, label_text: String, step: float, format: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(210.0, 0.0)
	row.add_child(label)
	var limits: Array = settings.LIMITS[key]
	var slider := HSlider.new()
	slider.min_value = limits[0]
	slider.max_value = limits[1]
	slider.step = step
	slider.custom_minimum_size = Vector2(260.0, 28.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(value_label)
	slider.set_meta("format", format)
	slider.value_changed.connect(func(v: float) -> void:
		_update_value_label(key, v)
		# T09: the text size is applied when a mouse drag ends (the panel would otherwise resize under the pointer mid-drag).
		if not (key == "ui_scale" and _dragging.get(key, false)):
			settings.set_value(key, v))
	slider.drag_started.connect(func() -> void: _dragging[key] = true)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		_dragging[key] = false
		settings.set_value(key, slider.value)
		_fit_to_screen())
	_sliders[key] = slider
	_value_labels[key] = value_label
	parent.add_child(row)


func _add_check(parent: Control, key: String, label_text: String) -> void:
	var check := CheckBox.new()
	check.set_meta("label", label_text)
	check.set_meta("default_label", label_text)
	check.text = _check_text(label_text, false)
	check.toggled.connect(func(on: bool) -> void:
		settings.set_value(key, on)
		check.text = _check_text(String(check.get_meta("label")), on)
		_refresh_presets())
	_checks[key] = check
	parent.add_child(check)


## The state is also written out, so it does not depend on the check mark alone.
func _check_text(label_text: String, on: bool) -> String:
	return "%s: %s" % [label_text, "on" if on else "off"]


func _update_value_label(key: String, value: float) -> void:
	var slider: HSlider = _sliders[key]
	var format := String(slider.get_meta("format"))
	if format == "pct":
		(_value_labels[key] as Label).text = "%d%%" % roundi(value * 100.0)
	else:
		(_value_labels[key] as Label).text = format % value


## T09 (S01-C): the checkpoint action says what it does, and is off with the reason when there is nothing to return to. It is recovery of
## the whole world as it was at the last rest, never "save current position".
func _refresh_checkpoint() -> void:
	if _checkpoint_button == null:
		return
	if world == null or not world.has_method("available_checkpoint") or not world.use_windowsill:
		_checkpoint_button.disabled = true
		_checkpoint_label.text = "Checkpoints: only the windowsill has a retreat to rest in."
		return
	var found: Dictionary = world.available_checkpoint()
	_checkpoint_button.disabled = not bool(found["ok"])
	if bool(found["ok"]):
		var note := "" if str(found.get("source", "")) != "backup" else "  (" + str(found["message"]) + ")"
		_checkpoint_label.text = "Return to checkpoint: the whole sill as it was at your last rest in the crack; anything since is undone.%s" % note
	else:
		_checkpoint_label.text = str(found["message"])


func _on_return_to_checkpoint() -> void:
	if world == null:
		return
	set_paused(false)
	world.call_deferred("return_to_checkpoint")


# ------------------------------------------------------------------ assisted play (T09d)

func _build_presets(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "Presets"
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = "Assisted play"
	label.custom_minimum_size = Vector2(150.0, 0.0)
	row.add_child(label)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	row.add_child(flow)
	for p: Dictionary in settings.PRESETS:
		var id := str(p["id"])
		var b := Button.new()
		b.name = "Preset_" + id
		b.text = str(p["name"])
		b.toggle_mode = true
		b.pressed.connect(func() -> void:
			settings.apply_preset(id)
			_refresh())
		flow.add_child(b)
		_preset_buttons[id] = b
	_preset_note = Label.new()
	_preset_note.name = "PresetNote"
	_preset_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preset_note.custom_minimum_size = Vector2(560.0, 0.0)
	_preset_note.add_theme_font_size_override("font_size", 16)
	parent.add_child(_preset_note)


## The preset the switches match is shown pressed and described in words; "Custom" when the switches match none.
func _refresh_presets() -> void:
	if _preset_note == null:
		return
	var now: String = settings.current_preset()
	for id: String in _preset_buttons:
		(_preset_buttons[id] as Button).set_pressed_no_signal(id == now)
	if now == "custom":
		_preset_note.text = "Now: Custom (your own choice of the switches below). A preset sets them all at once."
	else:
		var p: Dictionary = settings.preset(now)
		_preset_note.text = KeyNames.apply("Now: %s. %s" % [str(p["name"]), str(p["note"])], settings)


# ------------------------------------------------------------------ keys (T09, U01)

func _build_keys(parent: Control) -> void:
	var keys := VBoxContainer.new()
	keys.name = "Keys"
	keys.visible = false
	_keys_box = keys
	parent.add_child(keys)
	var note := Label.new()
	note.text = "Each action shows its keyboard key, then its controller button. Choose one, then press the key or the button (or trigger) you want for it. Esc or Menu stops without changing anything. One that is in use is swapped. Walking and looking stay on the sticks."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(560.0, 0.0)
	note.add_theme_font_size_override("font_size", 16)
	keys.add_child(note)
	var grid := GridContainer.new()
	grid.name = "KeysGrid"
	grid.columns = 6
	_keys_grid = grid
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	keys.add_child(grid)
	for action: String in settings.REMAPPABLE:
		var label := Label.new()
		label.text = String(settings.ACTION_NAMES[action])
		label.custom_minimum_size = Vector2(190.0, 0.0)
		grid.add_child(label)
		var button := Button.new()
		button.name = "Key_" + action
		button.custom_minimum_size = Vector2(96.0, 0.0)
		button.pressed.connect(_start_listening.bind(action))
		grid.add_child(button)
		_key_buttons[action] = button
		var pad := Button.new()
		pad.name = "Pad_" + action
		pad.custom_minimum_size = Vector2(150.0, 0.0)
		if settings.PAD_REMAPPABLE.has(action):
			pad.pressed.connect(_start_listening.bind(action, true))
		else:
			pad.disabled = true
			pad.text = _stick_of(action)
		grid.add_child(pad)
		_pad_buttons[action] = pad
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	keys.add_child(row)
	var reset := Button.new()
	reset.name = "ResetKeys"
	reset.text = "Reset keys and buttons"
	reset.pressed.connect(func() -> void:
		_listening = ""
		_listening_pad = false
		settings.reset_keys()
		_refresh()
		_keys_status.text = "Keys and buttons are back to their defaults."
		_refresh_keys())
	row.add_child(reset)
	_keys_status = Label.new()
	_keys_status.name = "KeysStatus"
	_keys_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_status.custom_minimum_size = Vector2(420.0, 0.0)
	_keys_status.add_theme_font_size_override("font_size", 16)
	row.add_child(_keys_status)
	_refresh_keys()


func _refresh_keys() -> void:
	for action: String in _key_buttons:
		var code: int = settings.get_key(action)
		var b: Button = _key_buttons[action]
		b.text = "press a key" if action == _listening and not _listening_pad else (OS.get_keycode_string(code as Key) if code > 0 else _mouse_of(action))
	for action: String in _pad_buttons:
		if settings.PAD_REMAPPABLE.has(action):
			var p: Button = _pad_buttons[action]
			p.text = "press a button" if action == _listening and _listening_pad else str(settings.pad_name(action))


## The mouse button of an action with no key (Focus), for its key column.
func _mouse_of(action: String) -> String:
	for e in InputSetupScript.defaults_of(action):
		if e is InputEventMouseButton:
			return "right mouse" if (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT else "mouse"
	return "none"


## The stick an action stays on (T09d), for its controller column.
func _stick_of(action: String) -> String:
	for e in InputSetupScript.defaults_of(action):
		if e is InputEventJoypadMotion:
			var axis := (e as InputEventJoypadMotion).axis
			return "left stick" if axis == JOY_AXIS_LEFT_X or axis == JOY_AXIS_LEFT_Y else "right stick"
	return "none"


func _start_listening(action: String, pad: bool = false) -> void:
	_listening = action
	_listening_pad = pad
	if pad:
		_keys_status.text = "Press a controller button or trigger for %s (Esc or Menu to stop)." % String(settings.ACTION_NAMES[action])
	else:
		_keys_status.text = "Press a key for %s (Esc to stop)." % String(settings.ACTION_NAMES[action])
	_refresh_keys()


func _stop_listening(message: String) -> void:
	_keys_status.text = message
	var action := _listening
	var was_pad := _listening_pad
	_listening = ""
	_listening_pad = false
	_refresh_keys()
	var buttons: Dictionary = _pad_buttons if was_pad else _key_buttons
	if buttons.has(action):
		(buttons[action] as Button).grab_focus()
	get_viewport().set_input_as_handled()


## While an action waits for its key: a key press assigns it (Esc stops); anything else is ignored. The event goes no further.
## T09d: while it waits for a controller button, a button press or a trigger pull assigns it (Menu or Esc stops).
func _listen(event: InputEvent) -> void:
	if _listening_pad:
		_listen_pad(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code := int((event as InputEventKey).physical_keycode)
		if code == KEY_ESCAPE:
			_stop_listening("Nothing was changed.")
		else:
			var result: Dictionary = settings.set_key(_listening, code)
			_refresh()  # labels that name keys follow the change
			_stop_listening(str(result["message"]))
	elif event is InputEventJoypadButton and event.pressed:
		_keys_status.text = "Press a keyboard key, or Esc. Controller buttons have their own column."
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		pass  # clicking another row is handled by that button


func _listen_pad(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if int((event as InputEventKey).physical_keycode) == KEY_ESCAPE:
			_stop_listening("Nothing was changed.")
		else:
			_keys_status.text = "Press a controller button or trigger, or Esc. Keys have their own column."
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return  # clicking another row is handled by that button
	var pad := InputSetupScript.pad_of_event(event)
	get_viewport().set_input_as_handled()  # a stick nudge does not move the menu's focus while it waits
	if pad == InputSetupScript.NO_PAD:
		return
	if pad == JOY_BUTTON_START:
		_stop_listening("Nothing was changed.")
		return
	var result: Dictionary = settings.set_pad(_listening, pad)
	_refresh()  # labels that name buttons follow the change
	_stop_listening(str(result["message"]))


## The panel never grows past the window: it scrolls instead.
func _fit_to_screen() -> void:
	if _scroll == null or not is_inside_tree():
		return
	if _switches != null:
		_switches.columns = 2 if get_viewport().get_visible_rect().size.x >= 1000.0 else 1
	if _keys_grid != null:
		_keys_grid.columns = 6 if get_viewport().get_visible_rect().size.x >= 1000.0 else 3
	var want := _content.get_combined_minimum_size().y
	var room := get_viewport().get_visible_rect().size.y - 56.0
	_scroll.custom_minimum_size = Vector2(_content.get_combined_minimum_size().x, clampf(want, 120.0, maxf(room, 120.0)))
