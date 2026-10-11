extends Node
## FeedingController (T07, spec 12, 19.3, L01): feeding is a brief action the player can stop at any moment, and the one door by which
## food becomes energy. The spider holds a captured fly (PreyDirector.held); pressing interact (E, the west button) starts feeding if it
## is valid, and pressing it again, or cancel (Q, B), stops it. While feeding, each tick the fly gives up a little of its nutrition
## (feed_rate_per_s of the profile) and the same amount, no more, goes to the NeedsModel as a grant under the fly's capture event id, which
## the model clamps to what the reserve can still take; a fly's nutrition is taken once, so cancelling and starting again continues
## where it stopped and nothing is ever granted twice. A full reserve does not stop the meal (the fly is finished all the same, and the
## grant is clamped), so there is no state a player can get stuck in.
## Valid means all of: the spider holds a prey that is CAPTURED and has nutrition left, the spider is ATTACHED on a surface, and it is
## still (no move intent, hardly any speed). The moment any of it stops being true the feeding ends and says why; the controls are never
## taken from the player, so control returns on the same tick: the movement, the jump press or the line works as it does without feeding.
## Order (spec 20): this node runs last in the tick (priority +11), after the spider has moved and captures have been resolved. It also
## drives the needs clock: the model gets the elapsed time once a tick, active when the spider is moving or off its surface.

const NeedsModel = preload("res://scripts/needs/needs_model.gd")
const PreyMath = preload("res://scripts/prey/prey_math.gd")

signal feeding_started(event_id: String)
## reason: "finished", "cancelled", "moved", "jumped", "lost footing", "no prey", ...; summary: nutrition taken and energy granted this meal.
signal feeding_ended(reason: String, summary: Dictionary)
## T09b, the struggle: "start", "tap" (a press added grip), "jerk" (the fly jerked and the grip lost some), "subdued", "escaped".
signal struggle_changed(phase: String)

const PRIORITY := 11
const MOVE_CANCEL_INTENT := 0.25
const STILL_SPEED := 0.15
const ACTIVE_SPEED := 0.2

var motor: Node3D       # SpiderMotor
var prey: Node3D        # PreyDirector
var needs: NeedsModel
## True in a played world: interact and cancel are read from the real input. Tests call request_feed and request_cancel.
var interactive: bool = false

var feeding: bool = false
var meal_event_id: String = ""
var last_end_reason: String = ""
var last_refusal: String = ""
var meals_started: int = 0
var meals_finished: int = 0
var taken_this_meal: float = 0.0
var granted_this_meal: float = 0.0
var taken_total: float = 0.0
var granted_total: float = 0.0
var refusals: Dictionary = {}

## T09b, the struggle (Nathan: "you should have to tap the button as the prey struggles"; "a bar that depletes when you stop tapping"). A
## caught fly is not yet subdued: for STRUGGLE_S (a draw of its own stream) it fights the jaws. The grip bar drains on its own and each jerk
## of the fly knocks a piece off; every press of interact adds to it. If the grip runs out the fly tears free; if it lasts until the fly is
## subdued, the fly is the spider's and can be eaten. About two presses a second are enough, and holding the button does nothing on its own,
## so "Struggling prey: automatic" in the pause panel (spec 17: no required rapid tapping) keeps the grip full with no presses.
## Played worlds struggle; test worlds only when a test asks.
const GRIP_START := 0.6
const GRIP_TAP := 0.25
const GRIP_DRAIN_PER_S := 0.3
const GRIP_JERK := 0.1
const STRUGGLE_S := Vector2(2.5, 3.5)
const JERK_GAP_S := Vector2(0.35, 0.75)
var struggle_enabled: bool = false
var struggle_auto: bool = false
## For the words on the screen: Settings (or null), to name the interact key the player chose.
var settings: Node
var struggling: bool = false
var grip: float = 0.0
var struggle_left: float = 0.0
var struggle_taps: int = 0
var struggle_jerks: int = 0
var struggle_log: Array[String] = []
var struggles_won: int = 0
var struggles_lost: int = 0
var _until_jerk: float = 0.0
## T09c (Nathan: "the tapping mechanic ... isnt working properly"): the grip starts to drain only once the spider has landed (a catch is
## usually made in the air), taps for a moment after the fly is subdued are swallowed instead of toggling the meal, and the meal then starts
## by itself when the spider can eat. A short line says how it ended ("Subdued." / "It tore free!").
const LANDING_WAIT_MAX_S := 1.0
const SWALLOW_S := 1.0
var note: String = ""
var note_left: float = 0.0
var _landing_wait: float = 0.0
var _swallow_left: float = 0.0
## The jump button (Space, the south button) pressed this tick: during a struggle it is the grip, like interact.
var _jump_pressed: bool = false


func _ready() -> void:
	process_physics_priority = PRIORITY


func _physics_process(delta: float) -> void:
	var press := false
	var cancel := false
	if interactive:
		press = Input.is_action_just_pressed("interact")
		cancel = Input.is_action_just_pressed("cancel")
		_jump_pressed = Input.is_action_just_pressed("prepare_jump")
	step(delta, press, cancel)


## One tick, with the presses it saw. Tests drive this directly or through request_feed and request_cancel.
func step(delta: float, press: bool, cancel: bool) -> void:
	if needs != null:
		needs.advance(delta, spider_active())
	if note_left > 0.0:
		note_left = maxf(0.0, note_left - delta)
	if struggling:
		_step_struggle(delta, press or _jump_pressed)
		return  # the press was the grip; nothing is eaten until the prey is subdued
	if _swallow_left > 0.0:
		_swallow_left -= delta
		press = false  # the last taps of a struggle do not start and stop the meal
		if not feeding and invalid_reason() == "":
			begin()   # the subdued prey is eaten at once, as a spider does
	if feeding and cancel:
		stop("cancelled")
	elif press:
		if feeding:
			stop("cancelled")
		else:
			begin()
	if feeding:
		var why := invalid_reason()
		if why != "":
			stop(why)
		else:
			_transfer(delta)


## The reason feeding cannot go on now, "" when it can.
func invalid_reason() -> String:
	if struggling:
		return "struggling"
	var held: Node3D = prey.held if prey != null else null
	if held == null or not is_instance_valid(held) or held.state != held.State.CAPTURED:
		return "no prey"
	if held.nutrition_left <= 0.0:
		return "nothing left"
	if motor == null:
		return "no spider"
	if motor.state == motor.State.PREPARING or motor.state == motor.State.AIRBORNE:
		return "jumped"
	if motor.state != motor.State.ATTACHED or not motor.support.is_valid():
		return "lost footing"
	if motor.get_intent().length() > MOVE_CANCEL_INTENT or motor.velocity.length() > STILL_SPEED:
		return "moved"
	return ""


## Starts a meal if it is valid. False, with the reason in last_refusal, when not.
func begin() -> bool:
	var why := invalid_reason()
	if why != "":
		last_refusal = why
		refusals[why] = int(refusals.get(why, 0)) + 1
		return false
	feeding = true
	meal_event_id = prey.held.capture_event_id
	taken_this_meal = 0.0
	granted_this_meal = 0.0
	meals_started += 1
	feeding_started.emit(meal_event_id)
	return true


func stop(reason: String) -> void:
	if not feeding:
		return
	feeding = false
	last_end_reason = reason
	if reason == "finished":
		meals_finished += 1
	feeding_ended.emit(reason, {"event_id": meal_event_id, "taken": taken_this_meal, "granted": granted_this_meal})


func request_feed() -> bool:
	return begin()


func request_cancel() -> void:
	stop("cancelled")


## True when the spider is doing something: moving, or not held by a surface. The needs clock counts its time as activity.
func spider_active() -> bool:
	if motor == null:
		return false
	return motor.state != motor.State.ATTACHED or motor.velocity.length() > ACTIVE_SPEED or motor.get_intent().length() > MOVE_CANCEL_INTENT


## The fly gives up some nutrition and the reserve takes exactly that much, as far as it has room.
func _transfer(delta: float) -> void:
	var held: Node3D = prey.held
	var want: float = float(held.profile.feed_rate_per_s) * delta
	var taken: float = held.consume(want)
	if taken <= 0.0:
		return
	var granted: float = needs.grant_energy(taken, meal_event_id)
	taken_this_meal += taken
	granted_this_meal += granted
	taken_total += taken
	granted_total += granted
	if held.state == held.State.CONSUMED:
		stop("finished")
		prey.release_held()


## What the screen says about the prey in the jaws: {} when there is none.
func prompt() -> Dictionary:
	var held: Node3D = prey.held if prey != null else null
	if held == null or not is_instance_valid(held) or held.state != held.State.CAPTURED:
		return {}
	if struggling:
		var hint := "holding on (automatic)" if struggle_auto else "tap %s / A (or %s / X) to keep your grip" % [_key("prepare_jump", "Space"), _key("interact", "E")]
		return {"title": "IT STRUGGLES!", "hint": hint, "left": grip, "urgent": grip < 0.3}
	var eat := "%s / X" % _key("interact", "E")
	var stop := "%s / B" % _key("cancel", "Q")
	if feeding:
		return {"title": "Eating", "hint": "keep still    %s or %s to stop" % [eat, stop], "left": held.nutrition_left / maxf(held.nutrition_total, 1.0e-6)}
	var why := invalid_reason()
	if why == "":
		return {"title": "Holding prey", "hint": "%s to eat" % eat, "left": held.nutrition_left / maxf(held.nutrition_total, 1.0e-6)}
	return {"title": "Holding prey", "hint": "stand still on a surface, then %s to eat" % eat, "left": held.nutrition_left / maxf(held.nutrition_total, 1.0e-6)}


# ------------------------------------------------------------------ the struggle (T09b)

## Called when the spider catches something (PreyDirector.captured).
func on_captured(_event: Dictionary) -> void:
	if not struggle_enabled or prey == null or prey.held == null:
		return
	var f: Node3D = prey.held
	struggling = true
	grip = 1.0 if struggle_auto else GRIP_START
	struggle_left = PreyMath.draw(f.rng, STRUGGLE_S)
	struggle_taps = 0
	struggle_jerks = 0
	_until_jerk = PreyMath.draw(f.rng, JERK_GAP_S) * 0.5
	_landing_wait = 0.0
	f.struggling = true
	struggle_log.append("start %s (%.2f s)" % [f.id, struggle_left])
	struggle_changed.emit("start")


func _step_struggle(delta: float, press: bool) -> void:
	var f: Node3D = prey.held if prey != null else null
	if f == null or not is_instance_valid(f) or f.state != f.State.CAPTURED:
		_end_struggle()
		return
	if press:
		struggle_taps += 1
		grip = minf(1.0, grip + GRIP_TAP)
		struggle_changed.emit("tap")
	# Caught in mid-air: the fight starts in earnest once the spider is down (or after a second at most).
	if motor != null and motor.state != motor.State.ATTACHED and _landing_wait < LANDING_WAIT_MAX_S:
		_landing_wait += delta
		return
	grip -= GRIP_DRAIN_PER_S * delta
	_until_jerk -= delta
	if _until_jerk <= 0.0:
		_until_jerk = PreyMath.draw(f.rng, JERK_GAP_S)
		struggle_jerks += 1
		grip -= GRIP_JERK
		prey.held_jerk = 1.0
		struggle_changed.emit("jerk")
	if struggle_auto:
		grip = 1.0
	struggle_left -= delta
	if grip <= 0.0:
		grip = 0.0
		struggles_lost += 1
		_end_struggle()
		prey.escape_held("it tore free of the jaws (%d taps, %d jerks)" % [struggle_taps, struggle_jerks])
		struggle_log.append("escaped")
		_say("It tore free!")
		struggle_changed.emit("escaped")
	elif struggle_left <= 0.0:
		struggles_won += 1
		_end_struggle()
		struggle_log.append("subdued")
		_swallow_left = SWALLOW_S
		_say("Subdued.")
		struggle_changed.emit("subdued")


## True while the jump button belongs to the grip (a struggle, and the moment after it), so the jump controller leaves it alone.
func jump_button_is_grip() -> bool:
	return struggling or _swallow_left > 0.0


func _end_struggle() -> void:
	struggling = false
	var f: Node3D = prey.held if prey != null else null
	if f != null and is_instance_valid(f):
		f.struggling = false
	if prey != null:
		for g in prey.flies:
			g.struggling = false


func _say(text: String) -> void:
	note = text
	note_left = 2.0


func _key(action: String, fallback: String) -> String:
	if settings == null or not settings.has_method("get_key"):
		return fallback
	var code: int = settings.get_key(action)
	return OS.get_keycode_string(code as Key) if code > 0 else fallback


## Developer line for the F3 overlay.
func describe() -> String:
	var held: Node3D = prey.held if prey != null else null
	var meal := "idle"
	if feeding:
		meal = "eating %s" % meal_event_id
	var holding := "none" if held == null else "%s (%.3f of %.3f left)" % [held.id, held.nutrition_left, held.nutrition_total]
	return "Feeding: %s | holding %s | meals %d started, %d finished | taken %.3f, granted %.3f | last end: %s" % [
		meal, holding, meals_started, meals_finished, taken_total, granted_total, last_end_reason if last_end_reason != "" else "-"]
