extends CanvasLayer
## T11a, slow motion (Nathan, 2026-10-11: "the slomo thing sounds cool"). T or the controller's right trigger switches the setting
## "slow_motion"; the world (main.gd, through SimClock) runs at "slow_speed" while it is on. Everything slows evenly, flies and the
## spider alike, tick for tick; looking about does not. While it is on, a line at the top of the screen says so, with the key to end it.

const KeyNames = preload("res://scripts/presentation/key_names.gd")

var settings: Node
var _label: Label


func _ready() -> void:
	layer = 5
	_label = Label.new()
	_label.name = "SlowMotion"
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_label.add_theme_constant_override("outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("slow_motion") and settings != null:
		settings.set_value("slow_motion", not bool(settings.get_value("slow_motion")))
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	if _label == null:
		return
	var on := settings != null and bool(settings.get_value("slow_motion"))
	_label.visible = on
	if not on:
		return
	var pct := roundi(float(settings.get_value("slow_speed")) * 100.0)
	_label.text = KeyNames.apply("SLOW MOTION %d%%    T / right trigger: normal speed" % pct, settings)
	var size := _label.get_viewport_rect().size
	var want := _label.get_minimum_size()
	_label.size = want
	_label.position = Vector2((size.x - want.x) * 0.5, 12.0)
