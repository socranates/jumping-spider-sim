extends Node3D
## Cosmetic spider, built from primitive meshes. About 1 WU long, head toward -Z.
## The leg rig inherits the twitch/recoil and uses movement in the model's local frame.
## Neutral tips sit 0.3 WU below the origin, at the sphere collider's support plane.

const SpiderLegs = preload("res://scripts/presentation/surface_legs.gd")
const SimClock = preload("res://scripts/core/sim_clock.gd")

const BODY_COLOR := Color(0.14, 0.11, 0.10)
const LEG_COLOR := Color(0.19, 0.15, 0.13)
const EYE_COLOR := Color(0.01, 0.01, 0.01)
const SPOT_COLOR := Color(0.92, 0.9, 0.84)
const FANG_COLOR := Color(0.16, 0.58, 0.47)

var gait_enabled: bool = true
var legs: Node3D
# Visual timeline only: the motor commits immediately and flies its original plan.
const ATTACH_S := 0.067
const PUSH_S := 0.067
const RECOVER_S := 0.10
const LAND_S := 0.24
var launch_time := -1.0
var landing_time := -1.0
var landing_depth := 0.0
var push_amount := 0.0
var attachment_amount := 0.0
var _launch_frame := Transform3D.IDENTITY
var _launch_dip := 0.0
var _eye_view := false
var _spinnerets: Node3D
var _abdomen: Node3D
## LIFE_DESIGN.md round 1: body condition you can see. The abdomen is plumper when the spider is well fed and thinner when it is hungry;
## abdomen size against the rest of the body is how a spider's condition is usually judged (Jakob, Marshall & Uetz 1996). Display only:
## the motor, the jumps and the collider never read it. `condition` is the energy reserve (0 to 1); the drawn size follows it slowly.
var condition: float = 0.55
var shown_condition: float = 0.55
const CONDITION_FOLLOW_PER_S := 0.5
var _prepare_time := 0.0


## Catch recoil (A-018, cosmetic): when the line catches the spider, the model is thrown a little way along the line, away
## from the anchor, and settles back in a damped bounce of about a third of a second. It moves only this node, a child of the
## physics body on the presentation side: the body, its collider, the line's length and the camera are never touched, and
## nothing shakes. It runs in the physics tick so the engine's interpolation smooths it. The silk's end follows the model.
const RECOIL_AMPLITUDE := 0.09     # WU, at most
const RECOIL_FREQUENCY := 4.0      # Hz
const RECOIL_DAMPING := 8.0        # 1/s
const RECOIL_STOP := 0.002         # WU: below this it is over and the node is put back exactly

var recoil_enabled: bool = true
## Where the recoil has put the model, in the physics body's space (zero when it is not recoiling).
var recoil_offset: Vector3 = Vector3.ZERO

## T09b, the twitchy jumping-spider body (cosmetic, A-018): the model turns in quick snaps instead of a smooth swivel, walks in little
## stop-and-dart lurches, crouches while aiming, makes small idle flicks when still, and jolts when held prey struggles. Only this child
## node moves, by at most TWITCH_MAX_WU and SNAP_DEG: the physics body, its heading, the senses (the spider's and every fly's), the camera
## and the line never see it. "Reduced motion" in the pause panel turns it off (and the catch recoil).
const SNAP_DEG := 14.0             # the model lags a turn by up to this, then snaps round
const SNAP_RATE := 28.0            # 1/s: how fast a snap closes the gap
const SETTLE_S := 0.12             # a turn that has stopped is snapped home after this
const STRIDE_WU := 0.32            # walking distance per lurch
const LURCH_WU := 0.07             # how far the model holds back then darts ahead, walking
const STALK_LURCH_WU := 0.035      # ... and stalking
const DART_SHARE := 0.3            # the share of each stride spent darting
const CROUCH_WU := 0.035
const IDLE_INTERVAL_S := Vector2(0.7, 2.4)
const IDLE_FLICK_DEG := Vector2(4.0, 9.0)
const JOLT_DEG := 10.0
const TWITCH_MAX_WU := 0.1
var twitch_enabled: bool = true
## What the twitch adds to the model's place and to its yaw about the body's up (radians).
var twitch_offset: Vector3 = Vector3.ZERO
var twitch_yaw: float = 0.0
var _last_heading: Vector3 = Vector3.ZERO
var _yaw_lag: float = 0.0
var _snapping: bool = false
var _still_turn_s: float = 0.0
var _stride: float = 0.0
var _lurch: float = 0.0
var _crouch: float = 0.0
var _idle_s: float = 0.0
var _next_idle_s: float = 1.0
var _flick: float = 0.0
var _flick_target: float = 0.0
var _flick_hold: float = 0.0
var _bob: float = 0.0
var _jolt: float = 0.0
var _jolt_t: float = 0.0
## Cosmetic stream (never gameplay): the idle flicks.
var _twitch_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _mats: Dictionary = {}
var _recoil_dir: Vector3 = Vector3.ZERO
var _recoil_amp: float = 0.0
var _recoil_t: float = 0.0
var _recoiling: bool = false


func _ready() -> void:
	_twitch_rng.seed = 91573
	_build()
	var motor := get_parent()
	if motor != null and motor.has_signal("line_event"):
		motor.line_event.connect(_on_line_event)
		motor.jump_committed.connect(_on_jump_committed)
		motor.state_changed.connect(_on_motor_state)
		motor.out_of_bounds_reset.connect(func(_a: Vector3, _b: Vector3) -> void: _clear_jump_pose())


## Throws the model along `direction` (in the physics body's space) and lets it settle. `strength` is 0 to 1 of the
## largest recoil.
func start_recoil(direction: Vector3, strength: float = 1.0) -> void:
	if not recoil_enabled or direction.length() < 1e-4:
		return
	_recoil_dir = direction.normalized()
	_recoil_amp = RECOIL_AMPLITUDE * clampf(strength, 0.0, 1.0)
	_recoil_t = 0.0
	_recoiling = _recoil_amp > RECOIL_STOP


func is_recoiling() -> bool:
	return _recoiling


func _physics_process(_delta: float) -> void:
	var delta := SimClock.DT
	if not recoil_enabled:
		_recoiling = false
		recoil_offset = Vector3.ZERO
	if _recoiling:
		_recoil_t += delta
		var envelope := exp(-RECOIL_DAMPING * _recoil_t)
		recoil_offset = _recoil_dir * _recoil_amp * envelope * sin(TAU * RECOIL_FREQUENCY * _recoil_t)
		if _recoil_amp * envelope < RECOIL_STOP:
			_recoiling = false
			recoil_offset = Vector3.ZERO
	_twitch(delta)
	position = recoil_offset + twitch_offset
	rotation = Vector3(0.0, twitch_yaw, 0.0)
	_jump_pose(delta)
	_update_legs(delta)
	shown_condition = move_toward(shown_condition, condition, CONDITION_FOLLOW_PER_S * delta)
	_abdomen.scale = abdomen_scale(shown_condition)


func _update_legs(delta: float) -> void:
	var motor := get_parent()
	if legs == null or motor == null or not motor.has_method("is_supported"):
		return
	var lead_in := launch_time >= 0.0 and launch_time < ATTACH_S + PUSH_S
	if gait_enabled and (motor.is_supported() or lead_in) and not _eye_view:
		legs.advance_surface(motor, delta, push_amount)
	elif gait_enabled and motor.is_supported():
		legs.advance_surface(motor, delta, push_amount)
	else:
		legs.advance_free(delta, not gait_enabled)


func _clear_jump_pose() -> void:
	launch_time = -1.0
	landing_time = -1.0
	landing_depth = 0.0
	push_amount = 0.0
	attachment_amount = 0.0
	_prepare_time = 0.0
	if legs != null:
		legs.clear_contacts()


func _on_motor_state(old: int, state: int) -> void:
	var motor := get_parent()
	if state == motor.State.LANDING:
		landing_time = 0.0
		launch_time = -1.0
	elif state == motor.State.FALLING and old != motor.State.AIRBORNE:
		_clear_jump_pose()


func _on_jump_committed(_plan: RefCounted) -> void:
	if not gait_enabled:
		return
	_launch_frame = global_transform
	_launch_dip = maxf(0.0, 0.035 + position.y)
	launch_time = 0.0
	landing_time = -1.0
	attachment_amount = 0.0
	# Do not wait for a render frame: tap/release and scripted jumps use this too.


func _jump_pose(dt: float) -> void:
	push_amount = 0.0
	attachment_amount = 0.0
	landing_depth = 0.0
	if not gait_enabled:
		_clear_jump_pose()
		_abdomen.rotation.x = 0.0
		return
	var motor := get_parent()
	if motor.state == motor.State.PREPARING:
		_prepare_time += dt
		attachment_amount = smoothstep(0.0, ATTACH_S, _prepare_time)
	else:
		_prepare_time = 0.0
	if launch_time >= 0.0:
		launch_time += dt
		if launch_time < ATTACH_S:
			attachment_amount = smoothstep(0.0, ATTACH_S, launch_time)
		elif launch_time < ATTACH_S + PUSH_S:
			push_amount = smoothstep(0.0, PUSH_S, launch_time - ATTACH_S)
			attachment_amount = 1.0 - push_amount
		var catch_up := smoothstep(ATTACH_S, ATTACH_S + PUSH_S + RECOVER_S, launch_time)
		# Only the visible third-person model waits at the launch point. First
		# person keeps its existing camera/motor relation, with a local rear push.
		if not _eye_view:
			global_transform = _launch_frame.interpolate_with(global_transform, catch_up)
			global_position -= _launch_frame.basis.y * _launch_dip * attachment_amount
		if launch_time >= ATTACH_S + PUSH_S + RECOVER_S:
			launch_time = -1.0
	if landing_time >= 0.0:
		landing_time += dt
		landing_depth = 0.065 * sin(PI * clampf(landing_time / LAND_S, 0.0, 1.0))
		position.y -= landing_depth
		if landing_time >= LAND_S:
			landing_time = -1.0
	_abdomen.rotation.x = 0.55 * attachment_amount


func set_condition(energy: float) -> void:
	if is_finite(energy):
		condition = clampf(energy, 0.0, 1.0)


## The abdomen's size for a condition: wider and deeper as it fills, a little longer too. About its present size at the start (0.55).
static func abdomen_scale(c: float) -> Vector3:
	var w := 0.84 + 0.30 * c
	return Vector3(w, w, 0.93 + 0.12 * c)


## A jolt of the whole model (held prey struggling).
func jolt(strength: float = 1.0) -> void:
	if twitch_enabled:
		_jolt = clampf(strength, 0.0, 1.0)
		_jolt_t = 0.0


func _twitch(delta: float) -> void:
	var motor := get_parent()
	var standing: bool = motor != null and motor.has_method("get_heading_vector") and twitch_enabled and delta > 0.0 \
		and (motor.state == motor.State.ATTACHED or motor.state == motor.State.PREPARING) and not motor.in_transition()
	if not standing:
		_last_heading = Vector3.ZERO
		_yaw_lag = 0.0
		_snapping = false
		_lurch = 0.0
		_crouch = 0.0
		_flick = 0.0
		_bob = 0.0
		_jolt = 0.0
		twitch_offset = Vector3.ZERO
		twitch_yaw = 0.0
		return
	var up: Vector3 = motor.get_visual_up()
	var h: Vector3 = motor.get_heading_vector()
	h = (h - up * h.dot(up)).normalized()
	# Turns: the model keeps its old facing until the gap passes SNAP_DEG (or the turn stops), then snaps round.
	if _last_heading != Vector3.ZERO:
		var d := _last_heading.signed_angle_to(h, up)
		if absf(d) > 0.8:
			_yaw_lag = 0.0
		else:
			_yaw_lag -= d
		_still_turn_s = _still_turn_s + delta if absf(d) < 1.0e-4 else 0.0
	_last_heading = h
	if absf(_yaw_lag) > deg_to_rad(SNAP_DEG) or (_still_turn_s >= SETTLE_S and absf(_yaw_lag) > 1.0e-3):
		_snapping = true
	if _snapping:
		_yaw_lag *= exp(-SNAP_RATE * delta)
		if absf(_yaw_lag) < deg_to_rad(0.5):
			_yaw_lag = 0.0
			_snapping = false
	# Walking: hold back, then dart ahead, once a stride.
	var speed: float = motor.velocity.length()
	if speed > 0.05 and motor.state == motor.State.ATTACHED:
		_stride += speed * delta / STRIDE_WU
		var phase := fposmod(_stride, 1.0)
		var amp := STALK_LURCH_WU if motor.is_stalking() else LURCH_WU
		var hold := 1.0 - DART_SHARE
		_lurch = lerpf(amp, -amp, phase / hold) if phase < hold else lerpf(-amp, amp, (phase - hold) / DART_SHARE)
		_idle_s = 0.0
		_flick_target = 0.0
	else:
		_lurch = move_toward(_lurch, 0.0, 0.8 * delta)
		_idle_s += delta
	# Still: now and then a small flick of the body or a bob.
	if _idle_s >= _next_idle_s:
		_idle_s = 0.0
		_next_idle_s = _twitch_rng.randf_range(IDLE_INTERVAL_S.x, IDLE_INTERVAL_S.y)
		if _twitch_rng.randf() < 0.65:
			_flick_target = deg_to_rad(_twitch_rng.randf_range(IDLE_FLICK_DEG.x, IDLE_FLICK_DEG.y)) * (1.0 if _twitch_rng.randf() < 0.5 else -1.0)
			_flick_hold = 0.18
		else:
			_bob = -0.025
	_flick = move_toward(_flick, _flick_target, deg_to_rad(240.0) * delta)
	if _flick_target != 0.0 and absf(_flick - _flick_target) < 1.0e-4:
		_flick_hold -= delta
		if _flick_hold <= 0.0:
			_flick_target = 0.0
	_bob = move_toward(_bob, 0.0, 0.25 * delta)
	_crouch = move_toward(_crouch, -CROUCH_WU if motor.state == motor.State.PREPARING else 0.0, 0.4 * delta)
	var jolt_yaw := 0.0
	if _jolt > 0.0:
		_jolt_t += delta
		jolt_yaw = deg_to_rad(JOLT_DEG) * _jolt * sin(_jolt_t * 55.0)
		_jolt = maxf(0.0, _jolt - 4.0 * delta)
	twitch_offset = Vector3(0.0, _bob + _crouch, -_lurch).limit_length(TWITCH_MAX_WU)
	twitch_yaw = _yaw_lag + _flick + jolt_yaw


func _on_line_event(kind: String, _detail: String) -> void:
	if kind != "caught":
		return
	var motor := get_parent() as Node3D
	if motor == null:
		return
	var away: Vector3 = motor.global_position - motor.tether.pivot()
	start_recoil(motor.global_transform.basis.inverse() * away)


func _build() -> void:
	_ellipsoid(Vector3(0.0, 0.02, -0.22), Vector3(0.22, 0.17, 0.26), "body")  # cephalothorax
	_abdomen = Node3D.new()
	_abdomen.name = "Abdomen"
	add_child(_abdomen)
	_ellipsoid(Vector3(0.0, 0.04, 0.20), Vector3(0.21, 0.19, 0.30), "body").reparent(_abdomen)   # abdomen
	_ellipsoid(Vector3(0.0, 0.225, 0.12), Vector3(0.05, 0.012, 0.05), "spot").reparent(_abdomen)
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * 0.07, 0.205, 0.30), Vector3(0.05, 0.012, 0.05), "spot").reparent(_abdomen)
		_ellipsoid(Vector3(side * 0.075, 0.09, -0.45), Vector3(0.075, 0.075, 0.075), "eye")   # principal
		_ellipsoid(Vector3(side * 0.17, 0.10, -0.34), Vector3(0.045, 0.045, 0.045), "eye")    # anterior lateral
		_ellipsoid(Vector3(side * 0.12, 0.15, -0.16), Vector3(0.05, 0.05, 0.05), "eye")       # posterior lateral
		_ellipsoid(Vector3(side * 0.06, 0.185, -0.20), Vector3(0.022, 0.022, 0.022), "eye")   # posterior median
		_ellipsoid(Vector3(side * 0.05, -0.05, -0.46), Vector3(0.045, 0.045, 0.045), "fang")
	legs = SpiderLegs.new()
	legs.name = "Legs"
	legs.material = _material("leg")
	add_child(legs)
	_spinnerets = Node3D.new()
	_spinnerets.name = "Spinnerets"
	_abdomen.add_child(_spinnerets)
	for side in [-1.0, 1.0]:
		var spinneret := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.028
		mesh.height = 0.08
		spinneret.mesh = mesh
		spinneret.material_override = _material("leg")
		spinneret.position = Vector3(side * 0.028, 0.02, 0.48)
		_spinnerets.add_child(spinneret)


## T10a, spider-eye view: the camera sits at the principal eyes, so the head, abdomen, eyes and fangs are hidden (they would fill or
## cut the view); the legs stay, as a jumping spider's front legs and palps are in front of its eyes.
func set_eye_view(on: bool) -> void:
	_eye_view = on
	legs.eye_view = on
	_abdomen.visible = not on
	for child in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = not on


func _material(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.roughness = 0.6
	match kind:
		"body":
			m.albedo_color = BODY_COLOR
		"leg":
			m.albedo_color = LEG_COLOR
		"eye":
			m.albedo_color = EYE_COLOR
			m.roughness = 0.05
			m.metallic = 0.4
			m.emission_enabled = true
			m.emission = Color(0.05, 0.12, 0.16)
		"spot":
			m.albedo_color = SPOT_COLOR
		"fang":
			m.albedo_color = FANG_COLOR
			m.metallic = 0.3
			m.roughness = 0.3
	_mats[kind] = m
	return m


func _ellipsoid(center: Vector3, radii: Vector3, kind: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(kind)
	mi.position = center
	mi.scale = radii
	add_child(mi)
	return mi


func visual_spinneret_point() -> Vector3:
	return _spinnerets.get_global_transform_interpolated() * Vector3(0.0, 0.02, 0.48)
