extends Node
## T08: cancelable rest and one harmless, telegraphed shadow encounter.
## No forces, camera commands, starvation, teleport or time skip. Tree pause freezes it.
signal rest_changed(active: bool)
const EVENT_ID := "room_shadow_01"
const EVENT_DELAY := 60.0
const WARNING_S := 5.0
const SHADOW_S := 12.0
var world: Node3D
var interactive := false
var resting := false
var rest_seconds := 0.0
var elapsed := 0.0
var event_phase := "waiting"
var phase_seconds := 0.0
var event_completed := false
var _label: Label
var _show_help := false

func _ready() -> void:
	process_physics_priority = 12
	if interactive:
		var canvas := CanvasLayer.new()
		add_child(canvas)
		_label = Label.new()
		_label.position = Vector2(22, 18)
		_label.add_theme_font_size_override("font_size", 18)
		_label.add_theme_color_override("font_color", Color("fff4d9"))
		_label.add_theme_color_override("font_outline_color", Color("242b28"))
		_label.add_theme_constant_override("outline_size", 5)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(_label)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		_show_help = not _show_help

func can_rest() -> bool:
	return world.lab.in_retreat(world.spider.global_position) and world.prey.held == null \
		and not world.feeding.feeding and world.spider.state == world.spider.State.ATTACHED \
		and world.spider.support.is_valid() and world.spider.get_intent().length() < 0.01 \
		and world.spider.velocity.length() < 0.15

func request_rest() -> bool:
	if not can_rest():
		return false
	resting = true
	rest_changed.emit(true)
	return true

func stop_rest() -> void:
	if resting:
		resting = false
		rest_changed.emit(false)

func _physics_process(delta: float) -> void:
	step(delta, interactive and Input.is_action_just_pressed("interact"), interactive and Input.is_action_just_pressed("cancel"))
	if _label != null:
		_label.text = caption()

func step(delta: float, interact_pressed: bool = false, cancel_pressed: bool = false) -> void:
	elapsed += delta
	if resting and (cancel_pressed or interact_pressed or not can_rest()):
		stop_rest()
	elif interact_pressed and world.prey.held == null and not world.feeding.feeding:
		request_rest()
	if resting:
		rest_seconds += delta
		world.needs.restore_rest(delta * 0.10)
	# Start only outside a meal and rest; after starting it is one uninterrupted event.
	if event_phase == "waiting":
		if elapsed >= EVENT_DELAY and not resting and not world.feeding.feeding:
			event_phase = "warning"
			phase_seconds = 0.0
	elif event_phase == "warning":
		phase_seconds += delta
		if phase_seconds >= WARNING_S:
			event_phase = "passing"
			phase_seconds = 0.0
	elif event_phase == "passing":
		phase_seconds += delta
		if phase_seconds >= SHADOW_S:
			event_phase = "quiet"
			event_completed = true
			phase_seconds = 0.0
	world.lab.show_disturbance(phase_seconds / SHADOW_S if event_phase == "passing" else -1.0)

func caption() -> String:
	var text := "THE WINDOWSILL    ·    H: field notes"
	if _show_help:
		return text + "\nFocus: right mouse / left trigger    Stalk: Shift / left shoulder\nHold Space / A to aim; release to jump. Green means reachable ground.\nA fly may leave before you arrive. E / X: eat or rest    Q / B: cancel\nYour silk can catch a miss. W / left stick up reels you back.\nHome is the silk-lined crack at the west end. Both routes lead back."
	if resting:
		return text + "\nResting in the silk-lined crack. Move, E or Q to leave."
	if can_rest():
		return text + "\nThe silk-lined crack    ·    E to rest"
	if event_phase == "warning":
		return text + "\nLight shifts at the window. A shadow is approaching."
	if event_phase == "passing":
		return text + "\nA shadow passes across the sill."
	if elapsed < 18.0:
		return text + "\nA small world, and time to look. Focus on movement; Shift to creep closer."
	if world.prey.held != null:
		return text  # Feeding owns its prompt.
	if world.jump_controller != null and world.spider.state == world.spider.State.PREPARING:
		return text + "\nReachable ground does not guarantee a catch. Watch the fly."
	if elapsed < 40.0:
		return text + "\nAlong the sill or across the leaves: choose your way to the planter."
	return text

func to_dict() -> Dictionary:
	return {"retreat_id": world.lab.RETREAT_ID, "resting": resting, "rest_seconds": rest_seconds,
		"event_id": EVENT_ID, "elapsed": elapsed, "phase": event_phase, "phase_seconds": phase_seconds,
		"event_completed": event_completed}
