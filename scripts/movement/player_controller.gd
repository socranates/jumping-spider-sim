extends Node
## Turns player input into a camera-relative world intent for the motor (spec 19.3, 6.4).
## Samples input each physics tick; the stalk toggle press is consumed once at the next tick.
##
## On any surface the stick maps through SurfaceInput: right is the camera's right on the surface;
## forward is away from the camera on floors and undersides and up on walls.
## Carry: when the support turns sharply (the motor's transition_serial changes) while the stick is
## held, the controller keeps the motor's own intent, which the motor rotates with the support,
## instead of the fresh camera mapping. The carry ends when the stick is released or turned by more
## than CARRY_STICK_DEG, or when the fresh mapping agrees with the carried direction again (within
## CARRY_AGREE_DEG, outside an edge arc). Holding one direction therefore never oscillates at an edge.
##
## Focus (spec 7, 17; A-026). Hold mode, the default: Focus is on while the focus action is held. Toggle mode (Settings.focus_toggle,
## for players who cannot hold a button): a press starts it and the next press stops it, and so does the cancel action when cancel has
## nothing else to do (an aim in progress and the safety line come first, and a press that one of them claims is theirs alone). A
## toggled Focus ends by itself when the spider leaves its surface (a committed jump, a fall, the line), and a press while it is off its
## surface is ignored, so it can neither touch a jump in flight nor stand in the way of a recovery. The HUD shows it while it is on.

const SurfaceInput = preload("res://scripts/movement/surface_input.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")

const CARRY_STICK_DEG := 30.0
const CARRY_AGREE_DEG := 25.0
## How far the camera's aim ray looks for the point Focus turns the body toward (WU).
const FOCUS_RANGE := 60.0
## T10a, spider-eye view: standing still, the body turns to face the gaze once the gaze is further than the principal eyes can point
## (the motor's PRINCIPAL_SCAN_DEG, measured on the surface), and stops when it is within EYE_SETTLE_DEG. Real salticids turn to face
## what the secondary eyes catch, then inspect it with the principal eyes. Walking turns the body as before.
const EYE_SETTLE_DEG := 4.0

var motor: Node3D        # SpiderMotor
var camera_rig: Node3D   # supplies the camera yaw and pitch
var settings: Node       # Settings autoload, or a test instance
var jump_controller: Node  # JumpController, optional: tells whether a press or an aim has the cancel button
var feeding_controller: Node  # FeedingController, optional (T07): while it feeds, cancel is its alone
## Scripted routes and tests: a Vector2 here replaces the move actions, in the same convention as
## Input.get_vector (x right, y back). null reads the real input.
var stick_override: Variant = null
## Scripted routes and tests: true or false here replaces the focus action, null reads the real input.
var focus_override: Variant = null
## Scripted routes and tests: a world direction Focus turns toward instead of the camera's aim (null: the camera's aim).
var focus_direction_override: Variant = null

var _stalk_latched: bool = false
var _toggle_pending: bool = false
var _focus_latched: bool = false
var _focus_was_down: bool = false
var _focus_cancel_pending: bool = false
var _carrying: bool = false
var _carry_stick: Vector2 = Vector2.ZERO
var _last_serial: int = 0
var _eye_turning: bool = false


func _ready() -> void:
	if settings == null:
		settings = get_node("/root/Settings")
	if motor != null:
		_last_serial = motor.transition_serial


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("stalk"):
		_toggle_pending = true
	elif event.is_action_pressed("cancel") and _focus_latched and not _cancel_has_other_work():
		_focus_cancel_pending = true


func _physics_process(_delta: float) -> void:
	if motor == null:
		return
	var raw: Vector2 = stick_override if stick_override is Vector2 else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var stick := Vector2(raw.x, -raw.y)  # x right, y forward
	var fresh: Vector3
	if camera_rig != null and camera_rig.has_method("map_stick"):
		fresh = camera_rig.map_stick(stick, motor.get_support_normal())
	else:
		var yaw: float = camera_rig.view_yaw() if camera_rig != null else 0.0
		var pitch: float = camera_rig.get_view_elevation() if camera_rig != null and camera_rig.has_method("get_view_elevation") else 0.0
		fresh = SurfaceInput.map_stick(stick, yaw, pitch, motor.get_support_normal())
	motor.set_intent(_carry(stick, fresh), _read_stalk())
	var focusing := _read_focus()
	var dir := focus_direction() if focusing else Vector3.ZERO
	if _eye_view():
		var gaze: Vector3 = camera_rig.gaze
		if motor.has_method("set_scan_direction"):
			motor.set_scan_direction(gaze)
		if not focusing and _eye_turn(stick, gaze):
			focusing = true
			dir = gaze
	else:
		_eye_turning = false
		if motor.has_method("set_scan_direction"):
			motor.set_scan_direction(Vector3.ZERO)
	motor.set_focus(focusing, dir)


func _eye_view() -> bool:
	return camera_rig != null and bool(camera_rig.get("eye_view"))


## True while the spider-eye view turns the body toward the gaze (see EYE_SETTLE_DEG). Only standing on a surface with the stick idle.
func _eye_turn(stick: Vector2, gaze: Vector3) -> bool:
	if stick.length() > 0.05 or not _on_surface():
		_eye_turning = false
		return false
	var n: Vector3 = motor.get_support_normal()
	var look := gaze - n * gaze.dot(n)
	if look.length_squared() < 1e-6:
		_eye_turning = false
		return false
	var heading: Vector3 = motor.get_heading_vector()
	var off := rad_to_deg(absf(heading.signed_angle_to(look.normalized(), n)))
	if not _eye_turning and off > float(motor.PRINCIPAL_SCAN_DEG):
		_eye_turning = true
	elif _eye_turning and off < EYE_SETTLE_DEG:
		_eye_turning = false
	return _eye_turning


## True while the body is turning on its own to face the spider-eye view's gaze.
func is_eye_turning() -> bool:
	return _eye_turning


## True while a toggled Focus is on (never in hold mode: there the button is the state).
func is_focus_latched() -> bool:
	return _focus_latched


## True when the cancel button would stop a toggled Focus now, that is when nothing else wants it.
func cancel_stops_focus() -> bool:
	return _focus_latched and not _cancel_has_other_work()


## Whether Focus is on this tick: held in hold mode; in toggle mode switched by a press or by a cancel nothing else claimed. A press is
## the input's own record of one since the last tick (Input.is_action_just_pressed): a tap that was over before this tick is still one,
## an analog trigger that reports many values while it is squeezed is one, and a button that went down while the game was paused is
## none. A scripted route (focus_override) gets the rising edge of what it sets.
func _read_focus() -> bool:
	var scripted := focus_override is bool
	var down: bool = bool(focus_override) if scripted else Input.is_action_pressed("focus")
	var pressed: bool = (down and not _focus_was_down) if scripted else Input.is_action_just_pressed("focus")
	_focus_was_down = down
	var cancelled := _focus_cancel_pending
	_focus_cancel_pending = false
	if not settings.focus_toggle:
		_focus_latched = false
		return down
	if not _on_surface():
		_focus_latched = false
		return false
	if pressed:
		_focus_latched = not _focus_latched
	elif cancelled:
		_focus_latched = false
	return _focus_latched


## Standing, landing or preparing: the states in which the body can be turned by Focus. A committed jump, a fall and the safety line
## are not.
func _on_surface() -> bool:
	var s: int = motor.state
	return s == motor.State.ATTACHED or s == motor.State.LANDING or s == motor.State.PREPARING


## True when a jump press or aim is in progress, the spider is in flight, it is on its line or it is feeding: cancel is theirs then.
func _cancel_has_other_work() -> bool:
	if motor == null:
		return false
	if motor.is_preparing() or motor.is_airborne() or motor.is_on_line():
		return true
	if feeding_controller != null and feeding_controller.feeding:
		return true
	return jump_controller != null and jump_controller.has_method("is_busy") and jump_controller.is_busy()


## The direction Focus turns the body toward: from the eyes to the point the camera's centre ray meets in the world
## (the same aim the jump uses), or along that ray when it meets nothing. The camera by itself never changes the facing:
## this is read only while Focus is held.
func focus_direction() -> Vector3:
	if focus_direction_override is Vector3:
		return focus_direction_override
	if camera_rig == null or motor == null or not camera_rig.has_method("get_aim_ray"):
		return Vector3.ZERO
	var ray: Dictionary = camera_rig.get_aim_ray()
	var origin: Vector3 = ray["origin"]
	var dir: Vector3 = ray["direction"]
	var hit: Dictionary = motor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + dir * FOCUS_RANGE, Layers.WORLD))
	if hit.is_empty():
		return dir
	var to: Vector3 = (hit["position"] as Vector3) - motor.get_eye_position()
	return to.normalized() if to.length() > 0.2 else dir


## True while the heading carried across the last edge is in use.
func is_carrying() -> bool:
	return _carrying


func _carry(stick: Vector2, fresh: Vector3) -> Vector3:
	var serial: int = motor.transition_serial
	var turned := serial != _last_serial
	_last_serial = serial
	if stick.length_squared() < 1e-8:
		_carrying = false
		return Vector3.ZERO
	if turned and not _carrying:
		_carrying = true
		_carry_stick = stick.normalized()
	if not _carrying:
		return fresh
	if absf(stick.normalized().angle_to(_carry_stick)) > deg_to_rad(CARRY_STICK_DEG):
		_carrying = false
		return fresh
	var carried: Vector3 = motor.get_intent()
	if carried.length_squared() < 1e-8:
		_carrying = false
		return fresh
	var dir := carried.normalized()
	if not motor.in_transition() and fresh.length_squared() > 1e-8 and fresh.normalized().angle_to(dir) < deg_to_rad(CARRY_AGREE_DEG):
		_carrying = false
		return fresh
	return dir * minf(stick.length(), 1.0)


func _read_stalk() -> bool:
	if settings.stalk_toggle:
		if _toggle_pending:
			_stalk_latched = not _stalk_latched
		_toggle_pending = false
		return _stalk_latched
	_toggle_pending = false
	_stalk_latched = false
	return Input.is_action_pressed("stalk")
