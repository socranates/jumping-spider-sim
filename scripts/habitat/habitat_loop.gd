extends Node
## T08: cancelable rest and one harmless, telegraphed shadow encounter.
## No forces, camera commands, starvation, teleport or time skip. Tree pause freezes it.
## T09 (S01-C): starting a rest in the retreat makes the retreat checkpoint, at the end of that tick (this node runs last), through the
## world's save_checkpoint. One checkpoint per rest; the caption says whether it was kept. Rest itself still grants only rest.
signal rest_changed(active: bool)
signal checkpoint_made(result: Dictionary)
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
## T09: a checkpoint is owed for the rest that began this tick; the last checkpoint result and how long its line stays on the screen.
var checkpoint_due := false
var checkpoint_result: Dictionary = {}
var notice := ""
var notice_seconds := 0.0
const NOTICE_S := 6.0
## After a restore the spider takes a tick or two to take hold of its surface again; the restored rest is not ended meanwhile.
const RESTORE_GRACE_TICKS := 30
var _restore_grace := 0
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

## T09 (U01): the field notes answer the "help" action (H, or the controller's View / Back button), so they work without a keyboard.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help") and not event.is_echo():
		toggle_help()


func toggle_help() -> void:
	_show_help = not _show_help


func help_shown() -> bool:
	return _show_help

func can_rest() -> bool:
	return world.lab.in_retreat(world.spider.global_position) and world.prey.held == null \
		and not world.feeding.feeding and world.spider.state == world.spider.State.ATTACHED \
		and world.spider.support.is_valid() and world.spider.get_intent().length() < 0.01 \
		and world.spider.velocity.length() < 0.15

func request_rest() -> bool:
	if not can_rest():
		return false
	resting = true
	checkpoint_due = true
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
	if _restore_grace > 0:
		_restore_grace = 0 if world.spider.state == world.spider.State.ATTACHED else _restore_grace - 1
	if resting and (cancel_pressed or interact_pressed or (_restore_grace == 0 and not can_rest())):
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
	if notice_seconds > 0.0:
		notice_seconds = maxf(0.0, notice_seconds - delta)
	if checkpoint_due:
		checkpoint_due = false
		if resting:
			make_checkpoint()


## The retreat checkpoint, now (the end of a tick). The world refuses it unless the spider stands still on a surface, not feeding.
func make_checkpoint() -> Dictionary:
	checkpoint_result = world.save_checkpoint()
	show_notice(str(checkpoint_result["message"]) if bool(checkpoint_result["ok"]) else "Resting, but the checkpoint was not kept: %s" % str(checkpoint_result["message"]))
	checkpoint_made.emit(checkpoint_result)
	return checkpoint_result


func show_notice(text: String) -> void:
	notice = text
	notice_seconds = NOTICE_S

func caption() -> String:
	var text := "THE WINDOWSILL    ·    %s / View: field notes" % _key_name("help", "H")
	if notice_seconds > 0.0 and not _show_help:
		text += "\n" + notice
	if _show_help:
		return text + "\nFocus: right mouse / left trigger    Stalk: %s / left shoulder\nHold %s / A to aim; release to jump. Green means reachable ground.\nA fly may leave before you arrive. %s / X: eat or rest    %s / B: cancel\nYour silk can catch a miss. %s / left stick up reels you back.\nHome is the silk-lined crack at the west end. Both routes lead back.\nThe pale leaf tip past the east leaf won't hold you. Your silk will.\nResting in the crack keeps a checkpoint.\nEsc / Menu: Return to checkpoint, keys, text size." % [
			_key_name("stalk", "Shift"), _key_name("prepare_jump", "Space"), _key_name("interact", "E"), _key_name("cancel", "Q"), _key_name("move_forward", "W")]
	if resting:
		return text + "\nResting in the silk-lined crack. Move, %s or %s to leave." % [_key_name("interact", "E"), _key_name("cancel", "Q")]
	if can_rest():
		return text + "\nThe silk-lined crack    ·    %s / X to rest" % _key_name("interact", "E")
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


## T09: restores a record made by to_dict (already validated as part of a checkpoint). The rest that was going on goes on; no new
## checkpoint is owed for it.
func apply_record(r: Dictionary) -> void:
	resting = bool(r["resting"])
	rest_seconds = float(r["rest_seconds"])
	elapsed = float(r["elapsed"])
	event_phase = str(r["phase"])
	phase_seconds = float(r["phase_seconds"])
	event_completed = bool(r["event_completed"])
	checkpoint_due = false
	_restore_grace = RESTORE_GRACE_TICKS
	show_notice("Returned to the checkpoint: the sill as it was when you rested in the crack. This is checkpoint recovery, not an exact resume.")


## The keyboard key an action answers to now (remapping, T09), for the words on the screen.
func _key_name(action: String, fallback: String) -> String:
	var settings: Node = world.settings if world != null else null
	if settings == null or not settings.has_method("get_key"):
		return fallback
	var code: int = settings.get_key(action)
	return OS.get_keycode_string(code as Key) if code > 0 else fallback
