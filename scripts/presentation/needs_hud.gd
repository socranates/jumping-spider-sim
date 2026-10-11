extends CanvasLayer
## The needs on the screen (T07, spec 12, 16): a small, quiet energy bar at the bottom left (it never flashes or nags: there is no
## starvation pressure in this prototype), and, while the spider holds a prey, what it can do about it, in words (nothing depends on colour):
## "Holding prey / E to eat", "Eating / keep still, E or Q to stop" with the share of the prey left. It reads the NeedsModel and the
## FeedingController only; it grants nothing and decides nothing.

const BAR_SIZE := Vector2(150.0, 7.0)

var needs: RefCounted        # NeedsModel
var feeding: Node            # FeedingController

var _box: VBoxContainer
var _bar_back: ColorRect
var _bar_fill: ColorRect
var _energy_label: Label
var _prompt_box: VBoxContainer
var _prompt_title: Label
var _prompt_hint: Label
var _prompt_bar: ColorRect
var _prompt_back: ColorRect
const PROMPT_BAR_W := 160.0


func _ready() -> void:
	layer = 4
	_box = VBoxContainer.new()
	_box.name = "Energy"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anchor_left = 0.0
	_box.anchor_right = 0.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = 24.0
	_box.offset_top = -50.0
	_box.offset_right = 24.0 + BAR_SIZE.x + 70.0
	_box.offset_bottom = -20.0
	add_child(_box)
	_energy_label = _label(13)
	_box.add_child(_energy_label)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(0.0, 0.0, 0.0, 0.35)
	_bar_back.custom_minimum_size = BAR_SIZE
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.95, 0.80, 0.35, 0.85)
	_bar_fill.size = BAR_SIZE
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.add_child(_bar_fill)
	_prompt_box = VBoxContainer.new()
	_prompt_box.name = "PreyPrompts"
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.anchor_left = 0.5
	_prompt_box.anchor_right = 0.5
	_prompt_box.anchor_top = 1.0
	_prompt_box.anchor_bottom = 1.0
	_prompt_box.offset_left = -300.0
	_prompt_box.offset_right = 300.0
	_prompt_box.offset_top = -140.0
	_prompt_box.offset_bottom = -60.0
	_prompt_box.visible = false
	add_child(_prompt_box)
	_prompt_title = _label(22)
	_prompt_hint = _label(16)
	_prompt_box.add_child(_prompt_title)
	_prompt_box.add_child(_prompt_hint)
	# T09b: the bar sits in a dark back, so a gauge that runs down (the grip while prey struggles) reads as one.
	_prompt_back = ColorRect.new()
	_prompt_back.name = "PromptGauge"
	_prompt_back.color = Color(0.0, 0.0, 0.0, 0.4)
	_prompt_back.custom_minimum_size = Vector2(PROMPT_BAR_W, 7.0)
	_prompt_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.add_child(_prompt_back)
	_prompt_bar = ColorRect.new()
	_prompt_bar.color = Color(0.95, 0.80, 0.35, 0.85)
	_prompt_bar.size = Vector2(0.0, 7.0)
	_prompt_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_back.add_child(_prompt_bar)


func _process(_delta: float) -> void:
	refresh()


## Brings the text and the bars up to date (also called by tests).
func refresh() -> void:
	if needs != null:
		var e: float = needs.energy
		_energy_label.text = "Energy %d%%" % roundi(e * 100.0)
		_bar_fill.size = Vector2(BAR_SIZE.x * clampf(e / needs.ENERGY_MAX, 0.0, 1.0), BAR_SIZE.y)
	var d: Dictionary = feeding.prompt() if feeding != null else {}
	if d.is_empty() and feeding != null and float(feeding.get("note_left") if feeding.get("note_left") != null else 0.0) > 0.0:
		d = {"title": str(feeding.note), "hint": "", "left": 0.0, "no_bar": true}   # T09c: how a struggle ended
	_prompt_box.visible = not d.is_empty()
	if not d.is_empty():
		_prompt_title.text = str(d["title"])
		_prompt_hint.text = str(d["hint"])
		_prompt_back.visible = not bool(d.get("no_bar", false))
		_prompt_bar.size = Vector2(PROMPT_BAR_W * clampf(float(d["left"]), 0.0, 1.0), 7.0)
		var urgent := bool(d.get("urgent", false))
		_prompt_bar.color = Color(1.0, 0.45, 0.25, 0.95) if urgent else Color(0.95, 0.80, 0.35, 0.85)
		_prompt_back.custom_minimum_size = Vector2(PROMPT_BAR_W, 12.0 if d.has("urgent") else 7.0)
		_prompt_bar.size.y = _prompt_back.custom_minimum_size.y


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER if size > 14 else HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
