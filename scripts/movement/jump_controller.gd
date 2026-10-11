extends Node
## Jump input (spec 6.3, 17, 19.3): tap, hold to aim, release to commit, cancel, and the toggle option.
##
## Hold mode (the default). A tap of `prepare_jump` (Space, south button) is a short hop forward along
## the surface. Holding it for HOLD_SECONDS starts PREPARING: the spider holds still, the camera's centre
## ray picks a surface point (no target magnet: what the reticle is on is the target), the landing patch
## shows what the solver says about it, and releasing the button commits when the plan is reachable.
## Releasing on a target that is not reachable cancels, says why, and launches nothing. `cancel` (Q,
## east button) leaves a preparation with no penalty.
## Toggle mode (Settings.prepare_toggle, for players who cannot hold a button): the first press starts
## PREPARING, the next press commits when the plan is reachable and otherwise stays in PREPARING with
## the invalid feedback until the player aims somewhere else or cancels. There is no tap hop then.
##
## The controller never moves the body and never invents a plan: it asks the motor for one
## (plan_jump, plan_hop) and commits exactly the plan the patch was showing, so the player never leaves
## for somewhere the patch did not show. Input events are queued and applied at the start of the next
## physics tick, so timing is counted in ticks and does not depend on the render rate.
## last_feedback records the latest outcome for the HUD and for tests: {"kind", "plan", "tick"} with
## kind one of "launched", "cancelled", "refused" (a release on an invalid target), "invalid_press"
## (toggle mode), "hop_refused" and "out_of_bounds".

const Layers = preload("res://scripts/core/physics_layers.gd")
const JumpPlan = preload("res://scripts/movement/jump_plan.gd")

signal feedback(kind: String, plan: RefCounted)

const HOLD_SECONDS := 0.15   # a press shorter than this is a hop
const HOP_DISTANCE := 1.5    # WU along the heading
const AIM_RANGE := 60.0      # WU: how far the aim ray looks
const FLASH_TICKS := 60      # a refused target stays on the patch this long

enum Phase { IDLE, PRESSED, AIMING }

var motor: Node3D        # SpiderMotor
var camera_rig: Node3D   # CameraRig; its centre ray aims. Null in tests that give aim_override.
var settings: Node       # Settings autoload, or a test instance
## Tests and scripted aims: a {"point", "normal", "collider"} (or {} for no surface) used instead of
## the camera's centre ray. null reads the camera.
var aim_override: Variant = null
var phase: Phase = Phase.IDLE
## The plan for the current aim while aiming (any kind, NO_TARGET when the ray found nothing).
var plan: RefCounted = null
var last_feedback: Dictionary = {}

var _events: Array[String] = []
var _held_ticks: int = 0
var _flash_plan: RefCounted = null
var _flash_left: int = 0
var _aim_key: Array = []


func _ready() -> void:
	if settings == null:
		settings = get_node("/root/Settings")
	if motor != null:
		motor.out_of_bounds_reset.connect(_on_out_of_bounds)


## T09c (Nathan: "the space bar can be used for the tapping instead when you have a fly"): while held prey struggles, and for a moment
## after it is subdued, the jump button is the grip (FeedingController reads it); it neither hops nor aims.
var feeding: Node


func _unhandled_input(event: InputEvent) -> void:
	if feeding != null and feeding.has_method("jump_button_is_grip") and feeding.jump_button_is_grip() \
			and (event.is_action("prepare_jump")):
		return
	if event.is_action_pressed("prepare_jump"):
		press()
	elif event.is_action_released("prepare_jump"):
		release()
	elif event.is_action_pressed("cancel"):
		cancel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_drop_input()


## The pause panel opened, or the window lost the focus. A button released while the tree is paused is
## never delivered to a paused node, so a press or an aim in progress would stay stuck until the next
## press and release (and that release would then leap). Drop it instead, with no penalty and no message.
func _drop_input() -> void:
	_events.clear()
	if phase == Phase.AIMING and motor != null:
		motor.cancel_prepare()
		_end_aim()
	phase = Phase.IDLE


## The jump button went down, came up, or the cancel button went down. Applied at the next physics tick.
func press() -> void:
	_events.append("press")


func release() -> void:
	_events.append("release")


func cancel() -> void:
	_events.append("cancel")


func is_aiming() -> bool:
	return phase == Phase.AIMING


## True while a jump press or an aim is in progress: the cancel button belongs to it then (A-026).
func is_busy() -> bool:
	return phase != Phase.IDLE


## The plan the landing patch shows now, or null: the aim while aiming, the plan being flown while
## airborne, or a refused target for a moment after it was refused.
func get_patch_plan() -> RefCounted:
	if phase == Phase.AIMING:
		return plan if plan != null and plan.kind != JumpPlan.Kind.NO_TARGET else null
	if motor != null and motor.is_airborne() and motor.jump_plan != null:
		return motor.jump_plan
	if _flash_left > 0:
		return _flash_plan
	return null


func _physics_process(_delta: float) -> void:
	if motor == null:
		return
	while not _events.is_empty():
		match _events.pop_front():
			"press":
				_on_press()
			"release":
				_on_release()
			"cancel":
				_on_cancel()
	if _flash_left > 0:
		_flash_left -= 1
		if _flash_left == 0:
			_flash_plan = null
	if phase == Phase.PRESSED:
		if not motor.can_prepare():
			phase = Phase.IDLE
		else:
			_held_ticks += 1
			if _held_ticks >= _hold_ticks():
				_begin_aim()
	if phase == Phase.AIMING:
		if motor.is_preparing():
			_update_aim()
		else:
			_end_aim()  # the spider lost its support, or was put somewhere else


func _hold_ticks() -> int:
	return maxi(1, ceili(HOLD_SECONDS * float(Engine.physics_ticks_per_second) - 1e-6))


func _on_press() -> void:
	if settings.prepare_toggle:
		if phase == Phase.AIMING:
			_confirm()
		elif phase == Phase.IDLE and motor.can_prepare():
			_begin_aim()
	elif phase == Phase.IDLE and motor.can_prepare():
		phase = Phase.PRESSED
		_held_ticks = 0


func _on_release() -> void:
	if settings.prepare_toggle:
		return
	if phase == Phase.PRESSED:
		phase = Phase.IDLE
		_hop()
	elif phase == Phase.AIMING:
		_confirm()


func _on_cancel() -> void:
	if phase == Phase.PRESSED:
		phase = Phase.IDLE
		_record("cancelled", null)
	elif phase == Phase.AIMING:
		motor.cancel_prepare()
		_end_aim()
		_record("cancelled", null)


func _begin_aim() -> void:
	if not motor.begin_prepare():
		phase = Phase.IDLE
		return
	phase = Phase.AIMING
	plan = null
	_aim_key = []
	if camera_rig != null:
		camera_rig.set_aiming(true)
	_update_aim()


func _end_aim() -> void:
	phase = Phase.IDLE
	motor.clear_aim_target()
	if camera_rig != null:
		camera_rig.set_aiming(false)


## Commit the plan the patch is showing; on a plan that is not reachable, cancel in hold mode and stay
## aiming in toggle mode, with the reason either way.
func _confirm() -> void:
	var shown := plan
	if shown != null and shown.is_valid() and motor.commit_jump(shown):
		_end_aim()
		_record("launched", shown)
		return
	_flash(shown)
	if settings.prepare_toggle:
		_record("invalid_press", shown)
	else:
		motor.cancel_prepare()
		_end_aim()
		_record("refused", shown)


func _hop() -> void:
	var hop: RefCounted = motor.plan_hop(HOP_DISTANCE)
	if hop.is_valid() and motor.begin_prepare():
		if motor.commit_jump(hop):
			_record("launched", hop)
			return
		motor.cancel_prepare()
	_flash(hop)
	_record("hop_refused", hop)


func _update_aim() -> void:
	var target := _aim_target()
	if target.is_empty():
		motor.clear_aim_target()
	else:
		motor.set_aim_target(target["point"])
	var key: Array = [target.get("point"), target.get("normal"), target.get("collider"), motor.global_position, motor.get_support_normal()]
	if plan == null or key != _aim_key:
		_aim_key = key
		plan = motor.plan_jump(target)


func _aim_target() -> Dictionary:
	if aim_override is Dictionary:
		return aim_override
	if camera_rig == null:
		return {}
	var ray: Dictionary = camera_rig.get_aim_ray()
	var from: Vector3 = ray["origin"]
	var to: Vector3 = from + (ray["direction"] as Vector3) * AIM_RANGE
	var exclude: Array[RID] = [motor.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD, exclude)
	var hit := motor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	return {"point": hit["position"], "normal": hit["normal"], "collider": hit["collider"]}


func _flash(refused: RefCounted) -> void:
	if refused != null and refused.kind != JumpPlan.Kind.NO_TARGET:
		_flash_plan = refused
		_flash_left = FLASH_TICKS


func _on_out_of_bounds(_from: Vector3, _to: Vector3) -> void:
	phase = Phase.IDLE
	_events.clear()
	if camera_rig != null:
		camera_rig.set_aiming(false)
	_record("out_of_bounds", null)


func _record(kind: String, shown: RefCounted) -> void:
	last_feedback = {"kind": kind, "plan": shown, "tick": motor.get_physics_tick()}
	feedback.emit(kind, shown)
