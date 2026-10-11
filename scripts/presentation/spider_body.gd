extends Node3D
## Cosmetic spider, built from primitive meshes. About 1 WU long, head toward -Z.
## The leg rig inherits the twitch/recoil and uses movement in the model's local frame.
## Neutral tips sit 0.3 WU below the origin, at the sphere collider's support plane.

const SpiderLegs = preload("res://scripts/presentation/spider_legs.gd")

const BODY_COLOR := Color(0.14, 0.11, 0.10)
const LEG_COLOR := Color(0.19, 0.15, 0.13)
const EYE_COLOR := Color(0.01, 0.01, 0.01)
const SPOT_COLOR := Color(0.92, 0.9, 0.84)
const FANG_COLOR := Color(0.16, 0.58, 0.47)

var gait_enabled: bool = true
var legs: Node3D

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


func _physics_process(delta: float) -> void:
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
	_update_legs(delta)


func _update_legs(delta: float) -> void:
	var motor := get_parent()
	if legs == null or motor == null or not motor.has_method("is_supported"):
		return
	var grounded: bool = motor.is_supported()
	var travel: Vector3 = motor.velocity
	if grounded:
		var normal: Vector3 = motor.get_support_normal()
		travel -= normal * travel.dot(normal)
	# Convert world travel after the motor's frame and this child's twitch have updated.
	# No extra phase from cosmetic lurches, idle flicks or catch recoil.
	var local_velocity: Vector3 = global_basis.inverse() * travel
	legs.advance_pose(delta, local_velocity, grounded,
		motor.state == motor.State.PREPARING, not gait_enabled)


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
	_ellipsoid(Vector3(0.0, 0.04, 0.20), Vector3(0.21, 0.19, 0.30), "body")   # abdomen
	_ellipsoid(Vector3(0.0, 0.225, 0.12), Vector3(0.05, 0.012, 0.05), "spot")
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * 0.07, 0.205, 0.30), Vector3(0.05, 0.012, 0.05), "spot")
		_ellipsoid(Vector3(side * 0.075, 0.09, -0.45), Vector3(0.075, 0.075, 0.075), "eye")   # principal
		_ellipsoid(Vector3(side * 0.17, 0.10, -0.34), Vector3(0.045, 0.045, 0.045), "eye")    # anterior lateral
		_ellipsoid(Vector3(side * 0.12, 0.15, -0.16), Vector3(0.05, 0.05, 0.05), "eye")       # posterior lateral
		_ellipsoid(Vector3(side * 0.06, 0.185, -0.20), Vector3(0.022, 0.022, 0.022), "eye")   # posterior median
		_ellipsoid(Vector3(side * 0.05, -0.05, -0.46), Vector3(0.045, 0.045, 0.045), "fang")
	legs = SpiderLegs.new()
	legs.name = "Legs"
	legs.material = _material("leg")
	add_child(legs)


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


func _ellipsoid(center: Vector3, radii: Vector3, kind: String) -> void:
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
