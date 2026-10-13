extends Node
## T08: cancelable rest and one harmless, telegraphed shadow encounter.
## No forces, camera commands, starvation, teleport or time skip. Tree pause freezes it.
## LIFE_DESIGN.md round 1: the life clock (time of day, the spider's age in days) runs here. Resting in the retreat in the evening or at
## night sleeps until morning, the hours passing quickly in bounded steps; moving, or anything that ends the rest, wakes the spider. The
## morning keeps a new checkpoint. The light follows the hour, and the spider's eyes see less far in the dark.
## T09 (S01-C): starting a rest in the retreat makes the retreat checkpoint, at the end of that tick (this node runs last), through the
## world's save_checkpoint. One checkpoint per rest; the caption says whether it was kept. Rest itself still grants only rest.
signal rest_changed(active: bool)
signal checkpoint_made(result: Dictionary)
const KeyNames = preload("res://scripts/presentation/key_names.gd")
const LifeClock = preload("res://scripts/life/life_clock.gd")
const Growth = preload("res://scripts/life/growth.gd")
## The sensor's reach at night, as a share of its daytime reach (jumping spiders hunt by sight, in daylight).
const NIGHT_SIGHT := 0.3
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
## The life clock, and whether the spider is asleep now (a night's rest in the retreat).
var clock := LifeClock.new()
var asleep := false
signal woke(day: int)
var _morning_text := ""
## LIFE_DESIGN round 3: growth by moulting. The food the spider has eaten is read from the needs' ledger each tick.
var growth := Growth.new()
signal moult_ready()
signal moulted(stage: int)
var _granted_seen: float = -1.0
var _skins: Array[Node3D] = []

func _ready() -> void:
	process_physics_priority = 12
	apply_light()
	_place_skins()
	_apply_growth()
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
	if resting and not growth.is_moulting() and (cancel_pressed or interact_pressed or (_restore_grace == 0 and not can_rest())):
		stop_rest()
	elif interact_pressed and world.prey.held == null and not world.feeding.feeding:
		request_rest()
	if resting:
		rest_seconds += delta
		world.needs.restore_rest(delta * 0.10)
	_step_life(delta)
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


## The life clock's tick: a rest that begins in the evening or at night is a night's sleep until morning.
func _step_life(delta: float) -> void:
	_step_growth_food()
	if resting and growth.ready and not growth.is_moulting() and growth.begin_moult():
		show_notice("The moult begins. The old skin splits and the spider slowly pulls free; it cannot be hurried.")
		_apply_growth()
	var was_asleep := asleep
	var moulting := growth.is_moulting()
	asleep = resting and not moulting and (clock.sleeping or clock.is_sleep_time())
	var hours := clock.advance_moult(delta) if moulting else clock.advance(delta, asleep)
	var what := growth.pass_hours(hours, world.spider.global_position)
	if what == "moulted":
		_on_moulted()
	elif what == "hardened":
		show_notice("The new skin has hardened. Full-length jumps again.")
		_apply_growth()
	elif growth.is_soft():
		_apply_growth(false)
	if asleep and not clock.sleeping:
		# The morning came during this tick: awake, still resting in the crack. The new day keeps a checkpoint.
		asleep = false
		checkpoint_due = true
		_morning_text = "Morning, day %d. Rested through the night in the crack." % clock.day
		show_notice(_morning_text)
		woke.emit(clock.day)
	elif was_asleep and not asleep:
		show_notice("Awake before morning: it is still %s." % clock.part_of_day())
	world.needs.add_hours(hours, asleep or moulting)
	apply_light()


## The food eaten since the last tick, from the needs' ledger (energy actually granted).
func _step_growth_food() -> void:
	var g: float = world.needs.granted_total
	if _granted_seen < 0.0:
		_granted_seen = g
	if g > _granted_seen:
		on_food(g - _granted_seen)
	_granted_seen = g


## Food the spider has eaten counts toward its next moult (tests may call this directly).
func on_food(energy: float) -> void:
	if growth.eat(energy):
		show_notice("Your spider is ready to moult. Rest in the silk-lined crack.")
		moult_ready.emit()


func _on_moulted() -> void:
	checkpoint_due = true
	_place_skins()
	_apply_growth()
	if growth.is_adult():
		_morning_text = "Moulted for the last time: your spider is an adult."
	else:
		_morning_text = "Moulted: now a %s (stage %d of %d). The new skin is soft for a while." % [growth.stage_name(), growth.stage + 1, Growth.STAGES.size()]
	show_notice(_morning_text)
	moulted.emit(growth.stage)


## The spider's reach and colour for its growth now (the world applies the reach with the player's own jump-reach setting).
func _apply_growth(reach: bool = true) -> void:
	if reach and world.has_method("apply_reach"):
		world.apply_reach()
	var body: Node = world.spider.get_node_or_null("Body") if world.spider != null else null
	if body != null and body.has_method("set_softness"):
		body.set_softness(growth.softness())
		if body.has_method("set_growth_stage"):
			body.set_growth_stage(growth.stage)


## The old skins left in the habitat, drawn as pale empty husks where each moult happened.
func _place_skins() -> void:
	for s in _skins:
		if is_instance_valid(s):
			s.queue_free()
	_skins.clear()
	for p in growth.exuviae:
		var m := MeshInstance3D.new()
		m.name = "OldSkin%d" % _skins.size()
		var mesh := SphereMesh.new()
		mesh.radius = 0.24
		mesh.height = 0.30
		m.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.86, 0.80, 0.66, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.9
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.scale = Vector3(1.0, 0.6, 1.4)
		world.lab.add_child(m)
		m.global_position = p + Vector3(0.0, -0.18, 0.0)
		_skins.append(m)


## The light of the hour on the sill, and how far the spider's eyes reach in it.
func apply_light() -> void:
	var light := clock.daylight()
	if world.lab.has_method("set_daylight"):
		world.lab.set_daylight(light, clock.hour)
	if world.get("sensor") != null:
		world.sensor.range_scale = lerpf(NIGHT_SIGHT, 1.0, light)


## The retreat checkpoint, now (the end of a tick). The world refuses it unless the spider stands still on a surface, not feeding.
func make_checkpoint() -> Dictionary:
	checkpoint_result = world.save_checkpoint()
	show_notice(str(checkpoint_result["message"]) if bool(checkpoint_result["ok"]) else "Resting, but the checkpoint was not kept: %s" % str(checkpoint_result["message"]))
	if _morning_text != "":
		show_notice(_morning_text + "\n" + notice)
		_morning_text = ""
	checkpoint_made.emit(checkpoint_result)
	return checkpoint_result


func show_notice(text: String) -> void:
	notice = text
	notice_seconds = NOTICE_S

func caption() -> String:
	var text := "THE WINDOWSILL    ·    Day %d, %s    ·    %s    ·    %s: field notes" % [clock.day, clock.part_of_day(), growth.stage_name(), _both("help", "H", "View")]
	if notice_seconds > 0.0 and not _show_help:
		text += "\n" + notice
	if _show_help:
		return text + "\nFocus: %s    Stalk: %s\nHold %s to aim; release to jump. Green means reachable ground.\nA fly may leave before you arrive. %s: eat or rest    %s: cancel\nYour silk can catch a miss. %s / left stick up reels you back.\n%s: let yourself down on your line from anywhere; hold it to keep lowering.\n%s: spider-eye view (first person)    %s: slow motion    %s: notebook\nHome is the silk-lined crack at the west end. Both routes lead back.\nThe pale leaf tip past the east leaf won't hold you. Your silk will.\nResting in the crack keeps a checkpoint.\nSounds: the room as you would hear it, the flies, and a low thrum for what the spider feels through its feet. Captions show them all.\nEsc / Menu: Return to checkpoint, keys, text size, sound." % [
			_both("focus", "right mouse", "left trigger"), _both("stalk", "Shift", "left shoulder"), _both("prepare_jump", "Space", "A"),
			_both("interact", "E", "X"), _both("cancel", "Q", "B"), _key_name("move_forward", "W"), _both("drop_line", "F", "D-pad down"),
			_both("eye_view", "V", "Y"),
			_both("slow_motion", "T", "right trigger"), _both("notebook", "N", "D-pad up")]
	if growth.is_moulting():
		return text + "\nMoulting in the silk-lined crack. The old skin splits and the spider slowly pulls free; it cannot be hurried."
	if asleep:
		return text + "\nAsleep in the silk-lined crack. The night passes. Move, %s or %s to wake." % [_both("interact", "E", "X"), _both("cancel", "Q", "B")]
	if resting:
		return text + "\nResting in the silk-lined crack. Move, %s or %s to leave." % [_both("interact", "E", "X"), _both("cancel", "Q", "B")]
	var wasp_line := _wasp_line()
	if wasp_line != "":
		return text + "\n" + wasp_line
	if growth.ready and not resting:
		return text + ("\nReady to moult    ·    %s to rest and moult" % _both("interact", "E", "X") if can_rest() else "\nYour spider is ready to moult. Rest in the silk-lined crack at the west end.")
	if can_rest():
		if clock.is_sleep_time():
			return text + "\nThe silk-lined crack    ·    %s to sleep until morning" % _both("interact", "E", "X")
		return text + "\nThe silk-lined crack    ·    %s to rest" % _both("interact", "E", "X")
	if clock.part_of_day() == "night":
		return text + "\nIt is dark, and your eyes reach only a little way. Home is the silk-lined crack at the west end."
	if clock.part_of_day() == "evening":
		return text + "\nEvening. Jumping spiders go into their silk retreat before dark."
	if growth.is_soft():
		return text + "\nThe new skin is still soft: shorter jumps for a while."
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

## LIFE round 4: what the top line says while the wasp visits ("" when it is away). The first visit says what wasps do and how to get away.
func _wasp_line() -> String:
	var w: Node = world.get("wasp_director")
	if w == null or not w.is_visiting():
		return ""
	match w.phase_name():
		"arriving":
			if int(w.visits) <= 1:
				return "A deep hum outside: a wasp is coming, and wasps hunt spiders. Hide in the crack, keep still, or let yourself down on your line (%s)." % _both("drop_line", "F", "D-pad down")
			return "A deep hum outside: a wasp is coming. Hide in the crack, keep still, or drop on your line."
		"searching":
			if float(w.confused_s) > 0.0:
				return "The wasp has lost you. Get out of sight."
			return "A wasp is searching the sill. Keep still, keep out of sight, or get home to the crack."
		"inspecting", "striking":
			return "The wasp has seen you! Get away: jump, drop on your line, or reach the crack."
		"carrying":
			return "Stung, the spider cannot move. The wasp carries it away."
		"leaving":
			return "The wasp is leaving."
	return ""

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


## "Key / button" an action answers to now (T09d: the controller button follows its remapping too).
func _both(action: String, key_fallback: String, pad_fallback: String) -> String:
	return KeyNames.both(world.settings if world != null else null, action, key_fallback, pad_fallback)


## The keyboard key an action answers to now (remapping, T09), for the words on the screen.
func _key_name(action: String, fallback: String) -> String:
	var settings: Node = world.settings if world != null else null
	if settings == null or not settings.has_method("get_key"):
		return fallback
	var code: int = settings.get_key(action)
	return OS.get_keycode_string(code as Key) if code > 0 else fallback
