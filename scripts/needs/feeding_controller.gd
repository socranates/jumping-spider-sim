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

signal feeding_started(event_id: String)
## reason: "finished", "cancelled", "moved", "jumped", "lost footing", "no prey", ...; summary: nutrition taken and energy granted this meal.
signal feeding_ended(reason: String, summary: Dictionary)

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


func _ready() -> void:
	process_physics_priority = PRIORITY


func _physics_process(delta: float) -> void:
	var press := false
	var cancel := false
	if interactive:
		press = Input.is_action_just_pressed("interact")
		cancel = Input.is_action_just_pressed("cancel")
	step(delta, press, cancel)


## One tick, with the presses it saw. Tests drive this directly or through request_feed and request_cancel.
func step(delta: float, press: bool, cancel: bool) -> void:
	if needs != null:
		needs.advance(delta, spider_active())
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
	if feeding:
		return {"title": "Eating", "hint": "keep still    E or Q to stop", "left": held.nutrition_left / maxf(held.nutrition_total, 1.0e-6)}
	var why := invalid_reason()
	if why == "":
		return {"title": "Holding prey", "hint": "E to eat", "left": held.nutrition_left / maxf(held.nutrition_total, 1.0e-6)}
	return {"title": "Holding prey", "hint": "stand still on a surface, then E to eat", "left": held.nutrition_left / maxf(held.nutrition_total, 1.0e-6)}


## Developer line for the F3 overlay.
func describe() -> String:
	var held: Node3D = prey.held if prey != null else null
	var meal := "idle"
	if feeding:
		meal = "eating %s" % meal_event_id
	var holding := "none" if held == null else "%s (%.3f of %.3f left)" % [held.id, held.nutrition_left, held.nutrition_total]
	return "Feeding: %s | holding %s | meals %d started, %d finished | taken %.3f, granted %.3f | last end: %s" % [
		meal, holding, meals_started, meals_finished, taken_total, granted_total, last_end_reason if last_end_reason != "" else "-"]
