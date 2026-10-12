extends Node
const SimClock = preload("res://scripts/core/sim_clock.gd")  # one game clock: count in its ticks, never the engine rate
## Safety-line input (spec 9.1, 17): reel in, lower and let go while the spider is on its line.
##
## While the motor is on its line (is_on_line(): falling on a locked line, HANGING or REELING), the `reel`
## action (W, left stick up) reels in and `lower` (S, left stick down) lets line out, at the species reel
## speed times how far the stick is pushed. They share keys with walking, which does nothing on the line:
## this is spec 17's context override. `cancel` (Q, east button) lets go of the line. It is the same button
## that cancels an aim; the HUD labels it differently in each state.
## An accidental second press must not drop the spider (spec 17). A press counts only when it begins while
## the spider is on the line and at least GRACE_SECONDS after the line took hold, so a press made to cancel
## an aim, or one still held from before the miss, never lets go. With Settings.release_hold (on by default)
## the button must then be held for RELEASE_HOLD_SECONDS, so a tap, or two, does nothing; with it off a
## counted press lets go at once. release_progress (0 to 1) is shown by the HUD. Button events are applied at
## the next physics tick, so timing is counted in ticks.
##
## Letting down on a line (Nathan, 2026-10-12: "an easy way to lower yourself from anywhere"): `drop_line` (F, D-pad down) asks the
## motor to let the spider down from where it stands (SpiderMotor.begin_drop), unless it is feeding or resting. Held while on the
## line, it lowers, like `lower`. Cancel stops a walk to the edge.

signal let_go()

const GRACE_SECONDS := 0.4
const RELEASE_HOLD_SECONDS := 0.6

var motor: Node3D       # SpiderMotor
var settings: Node      # Settings autoload, or a test instance
var feeding: Node       # FeedingController, optional: no letting down while it feeds
var habitat_loop: Node  # HabitatLoop, optional: no letting down while resting (or moulting) in the retreat
## Tests and scripted runs: a number here replaces the reel and lower actions (+1 reel in, -1 lower).
## null reads the real input.
var reel_override: Variant = null
## Tests and scripted runs: true or false here replaces holding the drop_line action. null reads the real input.
var drop_override: Variant = null
## 0 to 1 while a counted press is being held to let go (hold mode).
var release_progress: float = 0.0

var _events: Array[String] = []
var _on_line_ticks: int = 0
var _button_down: bool = false
var _press_counts: bool = false
var _held_ticks: int = 0


func _ready() -> void:
	if settings == null:
		settings = get_node("/root/Settings")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		cancel_down()
	elif event.is_action_released("cancel"):
		cancel_up()
	elif event.is_action_pressed("drop_line"):
		drop_pressed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# A button released while paused is never delivered: forget the press rather than act on it later.
		_events.clear()
		_button_down = false
		_press_counts = false
		_held_ticks = 0
		release_progress = 0.0


## The cancel button went down or came up. Applied at the next physics tick.
func cancel_down() -> void:
	_events.append("down")


func cancel_up() -> void:
	_events.append("up")


## The drop_line button was pressed. Applied at the next physics tick.
func drop_pressed() -> void:
	_events.append("drop")


## Why the spider may not let itself down now: "" when it may.
func drop_blocked() -> String:
	if feeding != null and feeding.get("feeding") == true:
		return "feeding"
	if habitat_loop != null and habitat_loop.get("resting") == true:
		return "resting"
	return ""


## True while a press is being held toward letting go.
func is_releasing() -> bool:
	return _press_counts and _button_down and release_progress > 0.0


func _physics_process(_delta: float) -> void:
	if motor == null:
		return
	var on_line: bool = motor.is_on_line()
	_on_line_ticks = _on_line_ticks + 1 if on_line else 0
	var ticks_per_second := float(SimClock.HZ)
	var hold: bool = settings == null or settings.release_hold
	while not _events.is_empty():
		var ev: String = _events.pop_front()
		if ev == "drop":
			if drop_blocked() == "" and motor.has_method("begin_drop"):
				motor.begin_drop()
			continue
		if ev == "down" and motor.has_method("cancel_drop") and motor.cancel_drop():
			continue  # the press stopped a walk to the edge; it is nothing else's
		if ev == "down":
			_button_down = true
			_held_ticks = 0
			_press_counts = on_line and float(_on_line_ticks) >= GRACE_SECONDS * ticks_per_second
			if _press_counts and not hold:
				_let_go()
		else:
			_button_down = false
			_press_counts = false
			_held_ticks = 0
	if not on_line:
		_press_counts = false
		release_progress = 0.0
		return
	motor.set_reel_intent(_reel_amount())
	if hold and _press_counts and _button_down:
		_held_ticks += 1
		release_progress = clampf(float(_held_ticks) / (RELEASE_HOLD_SECONDS * ticks_per_second), 0.0, 1.0)
		if release_progress >= 1.0:
			_let_go()
	else:
		release_progress = 0.0


func _let_go() -> void:
	_press_counts = false
	_held_ticks = 0
	release_progress = 0.0
	if motor.release_line():
		let_go.emit()


func _reel_amount() -> float:
	if reel_override is float or reel_override is int:
		return clampf(float(reel_override), -1.0, 1.0)
	var drop_held: float = (1.0 if drop_override else 0.0) if drop_override is bool else Input.get_action_strength("drop_line")
	return Input.get_action_strength("reel") - maxf(Input.get_action_strength("lower"), drop_held)
