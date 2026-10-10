extends CanvasLayer
## Pause panel, built in code. Esc or the controller menu button (action "pause") toggles it.
## Pausing sets get_tree().paused and shows the mouse; resuming hides it again.
## Changes are written through to Settings, which saves on every change.

var settings: Node  # Settings autoload, or a test instance
## T09: the world, for "Return to checkpoint" (null in a menu built on its own).
var world: Node
var _checkpoint_button: Button
var _checkpoint_label: Label

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
		_resume_button.grab_focus()


func _refresh() -> void:
	for key: String in _sliders:
		var slider: HSlider = _sliders[key]
		slider.set_value_no_signal(settings.get_value(key))
		_update_value_label(key, slider.value)
	for key: String in _checks:
		var check: CheckBox = _checks[key]
		var on: bool = settings.get_value(key)
		check.set_pressed_no_signal(on)
		check.text = _check_text(String(check.get_meta("label")), on)


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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	_add_slider(box, "look_sensitivity", "Look sensitivity", 0.05, "%.2f")
	_add_slider(box, "fov_degrees", "Field of view", 1.0, "%d deg")
	_add_slider(box, "camera_distance", "Camera distance", 0.1, "%.1f WU")
	_add_slider(box, "jump_reach", "Jump reach (playtest)", 0.05, "pct")
	# The switches go in two columns so the panel stays inside a 720 px window (chunk 6B added three, chunk 7A one).
	var switches := GridContainer.new()
	switches.name = "Switches"
	switches.columns = 2
	switches.add_theme_constant_override("h_separation", 28)
	switches.add_theme_constant_override("v_separation", 8)
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
		settings.set_value(key, v)
		_update_value_label(key, v))
	_sliders[key] = slider
	_value_labels[key] = value_label
	parent.add_child(row)


func _add_check(parent: Control, key: String, label_text: String) -> void:
	var check := CheckBox.new()
	check.set_meta("label", label_text)
	check.text = _check_text(label_text, false)
	check.toggled.connect(func(on: bool) -> void:
		settings.set_value(key, on)
		check.text = _check_text(label_text, on))
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
		_checkpoint_label.text = "Return to checkpoint: the whole sill goes back to how it was when you last rested in the crack; anything since is undone.%s" % note
	else:
		_checkpoint_label.text = str(found["message"])


func _on_return_to_checkpoint() -> void:
	if world == null:
		return
	set_paused(false)
	world.call_deferred("return_to_checkpoint")
