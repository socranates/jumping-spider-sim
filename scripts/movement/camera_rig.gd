extends Node3D
## Third-person orbit camera rig (spec 6.4).
## Horizon-stable: orientation comes from yaw and pitch only, so the camera never rolls.
## The boom is a sphere cast from the pivot toward the wanted camera position, run in
## _physics_process. The camera itself is placed in _process from the target's interpolated
## transform. A hit retracts the boom at once; recovery is rate limited (see BoomMath).
##
## Squeezed boom: with the spider's back to a wall the boom would retract to the pivot and the
## camera would look forward, with the spider out of frame. When the boom at the player's own
## pitch is shorter than COMFORT_BOOM, steeper downward pitches are cast in AUTO_PITCH_STEP_DEG
## steps up to MAX_ELEVATION_DEG. If no downward pitch is comfortable either (a low ceiling or an
## underside above the camera: the pivot hangs below the spider there and the camera at the
## player's pitch runs into the slab), pitches the other way are cast: the camera goes lower and
## looks up, in the same steps down to MIN_AUTO_ELEVATION_DEG. The smallest change that gives a
## comfortable boom, else the longest boom found, becomes an auto-pitch offset on top of
## `elevation` (positive: steeper, negative: flatter or looking up). The offset eases in quickly
## and relaxes when space clears. `elevation` stays the player's own pitch.
##
## Flicks: the orbit direction can change between physics ticks, so _process casts again along
## the direction it is about to use and retracts the boom at once. Only recovery is smoothed.
##
## Surfaces (chunk 3): the pivot sits PIVOT_HEIGHT along the spider's smoothed normal, not world
## up, so on a wall it stands out from the wall and on a ceiling it hangs below the spider, never
## inside the overhang. The camera itself still turns only by yaw and pitch: it never rolls.
## Recenter turns behind the heading on floors and undersides and toward the surface on walls.
##
## Aiming (chunk 4, spec 6.3): the camera's centre ray picks the jump target, and it always passes
## through the pivot, which hangs 0.45 WU above the spider, so with the orbit alone nothing higher than
## that could be aimed at. While aiming, vertical look therefore tilts the camera about its own position
## (`aim_pitch`, a free-look that never rolls) instead of orbiting. Yaw still orbits, and nothing about
## the spider, the pivot or the boom changes, so the view of the landing region stays steady and the
## camera does not swing behind the body at release. `aim_pitch` eases back to zero when aiming ends.
## get_view_elevation(), which the walking controls use, ignores it.
##
## Line framing (chunk 6A, A-017): hanging on the safety line under an overhang, the boom behind the spider is
## inside the cliff at every pitch, so the view shows the rock at 0.3 WU and neither the lip nor the line.
## While the spider is on a locked line and the boom at the player's own yaw is squeezed at the place the
## spider will hang (the line's rest point, so the view does not chase the swing), `yaw_assist` turns the
## view by the smallest turn, in ASSIST_STEP_DEG steps either way, that gives a comfortable boom there. It is
## added to the player's yaw (view_yaw()); `yaw` stays the player's own. It eases in and out, the boom is
## cast along the turned view like any other (so it cannot go through terrain) and the horizon never rolls.
## Any look input, a recenter or aiming takes the turn over: the view stays where it is, the framing is off
## until the line is gone, and the player's own turn applies as usual. When the line ends the view stays
## where the framing put it (it becomes the player's yaw, as if they had turned it there).
## Chunk 6B: the framing never turns the view by more than FRAMING_MAX_TURN_DEG (45), it can be switched off
## by the setting "Frame the line after a catch" (default on), and any look input cancels a turn at once (below).
##
## Placement order (chunk 6B, the Windows failure of 2026-10-07): the camera is never placed from a boom that was not
## cast against a world the physics server could see. A body added during a physics tick (a test's spawn, a scene
## built from a physics callback) has its transform applied only when the engine next flushes transform
## notifications, so a query made in that same tick finds an empty world and "no hit" would mean a full boom,
## outside the wall. The rig therefore does not trust a cast until the world can be seen: at once when it was made
## outside the physics step (a normal start), or after one completed physics tick when it was made inside one
## (`is_world_ready()`). Until then it sits at the pivot, boom 0, and nothing is drawn from a cast. This holds at any
## frame rate: several physics ticks can run between two rendered frames (a slow frame, a low --fixed-fps), and
## _process, the only other place the camera is placed, may not run in between.

const BoomMath = preload("res://scripts/movement/boom_math.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")

const PIVOT_HEIGHT := 0.45          # WU from the spider origin along its smoothed normal
const BOOM_RADIUS := 0.15           # WU, radius of the cast sphere
const DEFAULT_ELEVATION_DEG := 18.0
const MIN_ELEVATION_DEG := -20.0
const MAX_ELEVATION_DEG := 80.0
const MOUSE_DEG_PER_PIXEL := 0.1    # at look_sensitivity 1.0
const STICK_DEG_PER_SECOND := 150.0 # at look_sensitivity 1.0
const RECOVER_SPEED := 6.0          # WU/s the boom may lengthen after a retract
const RECENTER_SECONDS := 0.25
const BODY_HIDE_LENGTH := 0.8       # WU: hide the spider body when the boom is shorter than this
const NEAR_PLANE := 0.02
const FAR_PLANE := 300.0
const COMFORT_BOOM := 2.5           # WU: a shorter boom at the player's pitch starts the pitch search
const AUTO_PITCH_STEP_DEG := 10.0   # search step, from the player's pitch up to MAX_ELEVATION_DEG
const MIN_AUTO_ELEVATION_DEG := -45.0  # the lowest the camera may go when it looks up for room
const AUTO_PITCH_IN_SECONDS := 0.08   # ease-in time constant of the offset: quick
const AUTO_PITCH_OUT_SECONDS := 0.35  # ease-out time constant: slower
const DIRECTION_EPSILON := 1e-6     # radians: a smaller change in orbit direction is not recast
const SNAP_SETTLE_TICKS := 2        # physics ticks after a snap in which the auto-pitch jumps instead of easing
const AIM_PITCH_MIN_DEG := -20.0    # free-look while aiming, relative to the orbit view; positive looks up
const AIM_PITCH_MAX_DEG := 50.0
const AIM_VIEW_LIMIT_DEG := 85.0    # the whole view (orbit and free-look) stays this far from straight up or down
const AIM_RETURN_SECONDS := 0.25    # time constant of the return to the orbit view after aiming
const ASSIST_STEP_DEG := 15.0       # line framing: the turns tried, smallest first, either way
const FRAMING_MAX_TURN_DEG := 45.0  # line framing: the largest turn it may add (chunk 6B, Chet's temporary cap; was a half turn)
const SIGHT_TOLERANCE := 0.06       # WU: a ray that stops this short of its end still saw it (the lip sits a hair off its edge)
const ASSIST_SMOOTH_SECONDS := 0.12 # about how long the framing turn takes: a critically damped spring, gentle at both ends

var target: Node3D                  # the spider
var settings: Node                  # Settings autoload, or a test instance
var camera: Camera3D
var yaw: float = 0.0                # radians about world up; the camera looks along (-sin, 0, -cos)
var elevation: float = deg_to_rad(DEFAULT_ELEVATION_DEG)  # the player's own pitch, radians; positive puts the camera above the pivot
var boom_length: float = 0.0        # WU, as of the last cast: a physics tick, or _process after a flick
## Pitch the rig adds to `elevation` while the boom is squeezed: radians, positive steeper (a wall
## behind the spider), negative flatter (a low ceiling or an underside above), as of the last physics
## tick. Only the rig sets it; look() moves `elevation`, the player's own pitch.
var auto_pitch: float = 0.0
## Free-look about the camera while aiming, radians, positive looks up. See the header. The controller
## sets `aiming`; look() then moves this instead of `elevation`.
var aim_pitch: float = 0.0
var aiming: bool = false
## The turn the line framing adds to `yaw`, radians, as of the last physics tick (see the header). Only the
## rig sets it; zero unless the spider hangs on its line in a squeezed view and the player has not looked.
var yaw_assist: float = 0.0
## False turns the line framing off. The game never does (the player's setting "Frame the line after a catch" is
## separate and is read as well); tests measure the view with and without it.
var line_framing: bool = true
## The largest turn the line framing may add, radians (FRAMING_MAX_TURN_DEG). A test lifts it to measure the
## uncapped framing of chunk 6A.
var framing_max_turn: float = deg_to_rad(FRAMING_MAX_TURN_DEG)
## Mouse look only applies while the mouse is captured. Tests turn this off: a headless run
## has no mouse to capture.
var require_captured_mouse: bool = true

var _boom: float = 0.0
var _boom_prev: float = 0.0
var _pivot: float = 0.0             # pivot height above the target, lowered under low ceilings
var _pivot_prev: float = 0.0
var _pivot_dir: Vector3 = Vector3.UP       # the target's smoothed normal at the last physics tick
var _pivot_dir_prev: Vector3 = Vector3.UP
var _cast_dir: Vector3 = Vector3.UP        # pivot direction of the last boom cast
var _auto_pitch_prev: float = 0.0
var _auto_pitch_target: float = 0.0
var _cast_yaw: float = 0.0          # orbit direction the boom was last cast along
var _cast_elevation: float = 0.0    # effective pitch of that cast
var _settle_ticks: int = 0          # see SNAP_SETTLE_TICKS
var _assist_prev: float = 0.0
var _assist_target: float = 0.0
var _assist_velocity: float = 0.0   # rad/s, of the spring that eases yaw_assist
var _assist_off: bool = false       # the player has turned the view since the line caught: no framing until it ends
var _shape: SphereShape3D
var _recenter_t: float = -1.0       # negative when idle
var _recenter_yaw0: float = 0.0
var _recenter_elev0: float = 0.0
var _world_ready: bool = false      # true once physics queries can see the world (see is_world_ready()); casts are not trusted before
var _born_physics_frames: int = 0   # Engine.get_physics_frames() when the rig entered the tree
var _born_in_physics: bool = false  # the rig entered the tree inside a physics tick


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if settings == null:
		settings = get_node("/root/Settings")
	_shape = SphereShape3D.new()
	_shape.radius = BOOM_RADIUS
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = NEAR_PLANE
	camera.far = FAR_PLANE
	add_child(camera)
	camera.current = true
	settings.setting_changed.connect(_on_setting_changed)
	_apply_fov()
	_born_physics_frames = Engine.get_physics_frames()
	_born_in_physics = Engine.is_in_physics_frame()
	if target != null:
		snap_to_target()


func desired_distance() -> float:
	return settings.camera_distance


## True once the rig trusts physics casts: the world it was made with can be seen by queries. See "Placement order" in
## the header. Before it, the camera sits at the pivot and the boom is 0.
func is_world_ready() -> bool:
	return _world_ready


## Whether queries can see the bodies that were in the scene when the rig entered it. A rig made outside the physics
## step (the first frame of the game, a spawn from _process or a process_frame callback) is queried only after the
## engine's own flush of transform notifications, which comes before any physics tick, so its first tick is good. A rig
## made inside a physics tick has to wait for that tick to finish.
func _world_queryable() -> bool:
	return not _born_in_physics or Engine.get_physics_frames() > _born_physics_frames


## Starts or ends aiming. Ending it lets aim_pitch ease back to zero.
func set_aiming(on: bool) -> void:
	aiming = on
	if on:
		_take_over_assist()
		_recenter_t = -1.0


## The ray the aim uses: from the camera along its view direction, which is the screen-centre ray.
func get_aim_ray() -> Dictionary:
	var xform := camera.global_transform
	return {"origin": xform.origin, "direction": (-xform.basis.z).normalized()}


## Effective pitch of the view (the player's pitch plus the auto-pitch), radians.
func get_view_elevation() -> float:
	return _effective_elevation(auto_pitch)


## The yaw the camera uses: the player's own plus the line framing's turn. The walking controls steer by it,
## so the stick always means what is on screen.
func view_yaw() -> float:
	return yaw + yaw_assist


## Puts the camera behind the target at once, with the boom already clear of geometry and, when a
## wall is behind the spider, already pitched to see it (a snap does not ease the auto-pitch,
## nor do the next SNAP_SETTLE_TICKS physics ticks).
## Call after spawning or teleporting the target.
## Bodies added during a physics tick are invisible to physics queries until that tick is over (see "Placement order"
## in the header), so until is_world_ready() the camera sits at the spider's own centre (never inside the world) and
## the first tick that can see the world snaps again with a real query.
func snap_to_target() -> void:
	yaw = _target_heading()
	elevation = deg_to_rad(DEFAULT_ELEVATION_DEG)
	_recenter_t = -1.0
	yaw_assist = 0.0
	_assist_prev = 0.0
	_assist_target = 0.0
	_assist_velocity = 0.0
	_assist_off = false
	_settle_ticks = SNAP_SETTLE_TICKS
	var origin := target.global_position
	_pivot_dir = _target_up()
	_pivot_dir_prev = _pivot_dir
	if _world_ready:
		_pivot = _query_pivot(origin, _pivot_dir)
		var from := origin + _pivot_dir * _pivot
		_auto_pitch_target = _wanted_auto_pitch(from, yaw)
		auto_pitch = _auto_pitch_target
		_boom = minf(_boom_at(from, yaw, _effective_elevation(auto_pitch)), desired_distance())
	else:
		_pivot = 0.0
		_boom = 0.0
		_auto_pitch_target = 0.0
		auto_pitch = 0.0
	_pivot_prev = _pivot
	_boom_prev = _boom
	_auto_pitch_prev = auto_pitch
	boom_length = _boom
	var elev := _effective_elevation(auto_pitch)
	_cast_yaw = yaw
	_cast_elevation = elev
	_cast_dir = _pivot_dir
	_place(origin, _pivot, elev, _boom, _pivot_dir)


func start_recenter() -> void:
	if target == null or aiming:
		return
	_take_over_assist()
	if _on_line():
		_assist_off = true
	_recenter_t = 0.0
	_recenter_yaw0 = yaw
	_recenter_elev0 = elevation


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if require_captured_mouse and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		var rel: Vector2 = (event as InputEventMouseMotion).screen_relative
		look(rel.x * MOUSE_DEG_PER_PIXEL, rel.y * MOUSE_DEG_PER_PIXEL)
	elif event.is_action_pressed("recenter"):
		start_recenter()


## Turns the view by degrees: dx > 0 looks right, dy > 0 looks down. Applies sensitivity and
## the invert settings, then clamps pitch. This moves the player's own pitch; the auto-pitch
## offset is added on top of it.
func look(dx_deg: float, dy_deg: float) -> void:
	var s: float = settings.look_sensitivity
	var ix := -1.0 if settings.invert_x else 1.0
	var iy := -1.0 if settings.invert_y else 1.0
	if dx_deg != 0.0 or dy_deg != 0.0:
		_take_over_assist()
		if _on_line():
			_assist_off = true
	yaw -= deg_to_rad(dx_deg * s * ix)
	if aiming:
		aim_pitch = _clamp_aim_pitch(aim_pitch - deg_to_rad(dy_deg * s * iy))
	else:
		elevation = clampf(elevation + deg_to_rad(dy_deg * s * iy), deg_to_rad(MIN_ELEVATION_DEG), deg_to_rad(MAX_ELEVATION_DEG))
	if _recenter_t >= 0.0 and absf(dx_deg) + absf(dy_deg) > 1.5:
		_recenter_t = -1.0


func _physics_process(delta: float) -> void:
	if target == null:
		return
	if not _world_ready:
		if not _world_queryable():
			return  # made inside this tick: the world is not visible to queries yet, so nothing is cast and nothing moves
		_world_ready = true
		snap_to_target()
		return
	_pivot_prev = _pivot
	_boom_prev = _boom
	_auto_pitch_prev = auto_pitch
	_pivot_dir_prev = _pivot_dir
	_pivot_dir = _target_up()
	var origin := target.global_position
	_pivot = BoomMath.next_length(_pivot, _query_pivot(origin, _pivot_dir), PIVOT_HEIGHT, RECOVER_SPEED, delta)
	var from := origin + _pivot_dir * _pivot
	_assist_prev = yaw_assist
	_update_assist(delta)
	var vyaw := view_yaw()
	_auto_pitch_target = _wanted_auto_pitch(from, vyaw)
	if _settle_ticks > 0:
		# Just after a snap the first query may have run before the world was visible, so the
		# next ticks correct it without easing.
		_settle_ticks -= 1
		auto_pitch = _auto_pitch_target
	else:
		auto_pitch = BoomMath.ease_offset(auto_pitch, _auto_pitch_target, delta, AUTO_PITCH_IN_SECONDS, AUTO_PITCH_OUT_SECONDS)
	var elev := _effective_elevation(auto_pitch)
	_boom = BoomMath.next_length(_boom, _boom_at(from, vyaw, elev), desired_distance(), RECOVER_SPEED, delta)
	boom_length = _boom
	_cast_yaw = vyaw
	_cast_elevation = elev
	_cast_dir = _pivot_dir


func _process(delta: float) -> void:
	if target == null:
		return
	var v := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if v != Vector2.ZERO:
		look(v.x * STICK_DEG_PER_SECOND * delta, v.y * STICK_DEG_PER_SECOND * delta)
	_update_recenter(delta)
	if not aiming and aim_pitch != 0.0:
		aim_pitch = BoomMath.ease_offset(aim_pitch, 0.0, delta, AIM_RETURN_SECONDS, AIM_RETURN_SECONDS)
	# Interpolate recovery between physics ticks; a retract is taken at once (min).
	var frac := Engine.get_physics_interpolation_fraction()
	var origin := target.get_global_transform_interpolated().origin
	var pivot := minf(lerpf(_pivot_prev, _pivot, frac), _pivot)
	var length := minf(lerpf(_boom_prev, _boom, frac), _boom)
	var elev := _effective_elevation(lerpf(_auto_pitch_prev, auto_pitch, frac))
	var dir := _pivot_dir_prev.slerp(_pivot_dir, frac).normalized()
	var vyaw := yaw + lerpf(_assist_prev, yaw_assist, frac)
	# The orbit direction can change between physics ticks (a flick, a recenter, the auto-pitch
	# ease), and the boom was cast along the old one. Cast again along the direction about to be
	# used and retract at once. Physics runs on the main thread, so the direct space state is
	# safe to query here. The retract is kept in the physics state, so the boom does not spring
	# back next frame; only its recovery is smoothed (next_length, per tick).
	if _world_ready and (absf(angle_difference(vyaw, _cast_yaw)) > DIRECTION_EPSILON or absf(elev - _cast_elevation) > DIRECTION_EPSILON or dir.angle_to(_cast_dir) > DIRECTION_EPSILON):
		_cast_yaw = vyaw
		_cast_elevation = elev
		_cast_dir = dir
		var limit := _boom_at(origin + dir * pivot, vyaw, elev)
		if limit < length:
			length = limit
			_boom = minf(_boom, limit)
			_boom_prev = minf(_boom_prev, limit)
			boom_length = _boom
	_place(origin, pivot, elev, length, dir, vyaw)


func _update_recenter(delta: float) -> void:
	if _recenter_t < 0.0:
		return
	_recenter_t += delta
	var k := clampf(_recenter_t / RECENTER_SECONDS, 0.0, 1.0)
	var s := k * k * (3.0 - 2.0 * k)
	yaw = lerp_angle(_recenter_yaw0, _target_heading(), s)
	elevation = lerpf(_recenter_elev0, deg_to_rad(DEFAULT_ELEVATION_DEG), s)
	if k >= 1.0:
		_recenter_t = -1.0


func _place(origin: Vector3, pivot_height: float, elev: float, length: float, pivot_dir: Vector3 = Vector3.UP, yaw_angle: float = NAN) -> void:
	var facing := view_yaw() if is_nan(yaw_angle) else yaw_angle
	global_transform = Transform3D(BoomMath.orbit_basis(facing, elev), origin + pivot_dir * pivot_height)
	camera.transform = Transform3D(Basis(Vector3.RIGHT, _clamp_aim_pitch(aim_pitch, elev)), Vector3(0.0, 0.0, length))
	var body := target.get_node_or_null("Body") as Node3D
	if body != null:
		body.visible = length >= BODY_HIDE_LENGTH


func _target_heading() -> float:
	if target.has_method("get_recenter_yaw"):
		return target.get_recenter_yaw(yaw)
	var f := -target.get_global_transform_interpolated().basis.z
	return atan2(-f.x, -f.z)


## Free-look limits: its own range, and the whole view kept short of straight up or down.
func _clamp_aim_pitch(value: float, elev: float = NAN) -> float:
	var e := get_view_elevation() if is_nan(elev) else elev
	var limit := deg_to_rad(AIM_VIEW_LIMIT_DEG)
	var low := maxf(deg_to_rad(AIM_PITCH_MIN_DEG), e - limit)
	var high := minf(deg_to_rad(AIM_PITCH_MAX_DEG), e + limit)
	return clampf(value, low, maxf(low, high))


## The target's smoothed surface normal (world up for targets without one).
func _target_up() -> Vector3:
	if target.has_method("get_visual_up"):
		var n: Vector3 = target.get_visual_up()
		if n.is_finite() and n.length_squared() > 1e-6:
			return n.normalized()
	return Vector3.UP


## The player's pitch plus an auto-pitch offset, held between the lowest automatic pitch and the
## pitch clamp (or the player's own pitch, if that was set past either).
func _effective_elevation(offset: float) -> float:
	var low := minf(elevation, deg_to_rad(MIN_AUTO_ELEVATION_DEG))
	var high := maxf(elevation, deg_to_rad(MAX_ELEVATION_DEG))
	return clampf(elevation + offset, low, high)


## Distance of the pivot from the spider along `dir`: PIVOT_HEIGHT, or less where geometry is closer.
func _query_pivot(origin: Vector3, dir: Vector3 = Vector3.UP) -> float:
	var fraction := _cast_fraction(origin, dir * PIVOT_HEIGHT)
	return BoomMath.allowed_length(fraction, PIVOT_HEIGHT)


## Longest collision-free boom length from the pivot `from` along the orbit direction for the
## given yaw and pitch, up to the wanted distance.
func _boom_at(from: Vector3, yaw_angle: float, pitch: float) -> float:
	var distance := desired_distance()
	var motion := BoomMath.back_direction(yaw_angle, pitch) * distance
	return BoomMath.allowed_length(_cast_fraction(from, motion), distance)


## The auto-pitch offset the boom wants from the pivot `from`: 0.0 while the player's own pitch
## leaves a comfortable boom. Otherwise steeper downward pitches are cast in steps up to the
## pitch clamp, then, only if none of those is comfortable, flatter and upward-looking pitches down
## to the lowest automatic pitch. The smallest change that reaches the comfortable length wins
## (downward candidates come first), or the longest boom found (see BoomMath.pick_pitch_offset).
## It is measured from the player's pitch, never from the eased one, so the answer does not
## feed back on itself.
func _wanted_auto_pitch(from: Vector3, yaw_angle: float) -> float:
	return _pitch_search(from, yaw_angle)[0]


## [offset, boom length at that offset] for the pitch search described above, at the given yaw from `from`.
func _pitch_search(from: Vector3, yaw_angle: float) -> PackedFloat64Array:
	var comfort := minf(COMFORT_BOOM, desired_distance())
	var offsets := PackedFloat64Array([0.0])
	var lengths := PackedFloat64Array([_boom_at(from, yaw_angle, elevation)])
	var step := deg_to_rad(AUTO_PITCH_STEP_DEG)
	var room_down := maxf(deg_to_rad(MAX_ELEVATION_DEG) - elevation, 0.0)  # steeper: the camera rises
	var room_up := maxf(elevation - deg_to_rad(MIN_AUTO_ELEVATION_DEG), 0.0)  # flatter, then looking up
	var offset := 0.0
	while lengths[lengths.size() - 1] < comfort and offset < room_down - 1e-6:
		offset = minf(offset + step, room_down)
		offsets.append(offset)
		lengths.append(_boom_at(from, yaw_angle, elevation + offset))
	offset = 0.0
	while lengths[lengths.size() - 1] < comfort and offset < room_up - 1e-6:
		offset = minf(offset + step, room_up)
		offsets.append(-offset)
		lengths.append(_boom_at(from, yaw_angle, elevation - offset))
	var picked := BoomMath.pick_pitch_offset(offsets, lengths, comfort)
	var index := maxi(offsets.find(picked), 0)
	return PackedFloat64Array([picked, lengths[index]])


## True while the spider hangs on its safety line (a target without a line is never on one).
func _on_line() -> bool:
	return target != null and target.has_method("is_on_line") and target.is_on_line()


## One physics tick of the line framing: its wanted turn, and the eased turn.
func _update_assist(delta: float) -> void:
	var on_line := _on_line()
	if not on_line:
		# The line is gone (the grab, a let-go, a lost anchor): the view stays where the framing put it, as if the
		# player had turned it there. Swinging back would sweep through the same squeezed turns again.
		_assist_off = false
		_take_over_assist(false)
		return
	var wanted := 0.0
	if on_line and framing_enabled() and not _assist_off and not aiming:
		wanted = _wanted_yaw_assist()
	_assist_target = wanted
	var next := BoomMath.smooth_damp(yaw_assist, wanted, _assist_velocity, ASSIST_SMOOTH_SECONDS, delta)
	yaw_assist = next[0]
	_assist_velocity = next[1]


## True while the line framing may act: the rig's own switch and the player's setting "Frame the line after a catch".
func framing_enabled() -> bool:
	return line_framing and bool(settings.get_value("frame_line_after_catch"))


## The turn that gives a good view of the recovery where the spider will hang: 0 while the player's own yaw
## already has one, else the smallest turn that does within framing_max_turn (the turn already held first, so the view
## does not flip as the rest point moves), else 0 (nowhere does: the view is left to the pitch search).
func _wanted_yaw_assist() -> float:
	var rest: Vector3 = target.get_line_rest_point() if target.has_method("get_line_rest_point") else target.global_position
	var lip: Vector3 = target.get_line_lip() if target.has_method("get_line_lip") else rest
	var from := rest + _pivot_dir * _pivot
	if _assist_target != 0.0 and _good_view(from, yaw + _assist_target, rest, lip):
		return _assist_target
	if _good_view(from, yaw, rest, lip):
		return 0.0
	var step := deg_to_rad(ASSIST_STEP_DEG)
	var k := 1
	while float(k) * step <= framing_max_turn + 1e-6:
		for side in [1.0, -1.0]:
			var turn: float = float(k) * step * side
			if _good_view(from, yaw + turn, rest, lip):
				return turn
		k += 1
	return 0.0


## A good view of the recovery: from the pivot `from`, at this yaw and the pitch the pitch search would pick, the
## boom is comfortable and the camera has a clear line of sight to the spider (`spot`) and to the lip.
func _good_view(from: Vector3, yaw_angle: float, spot: Vector3, lip: Vector3) -> bool:
	var found := _pitch_search(from, yaw_angle)
	if found[1] < minf(COMFORT_BOOM, desired_distance()):
		return false
	var cam_pos := from + BoomMath.back_direction(yaw_angle, _effective_elevation(found[0])) * found[1]
	return _sees(cam_pos, spot) and _sees(cam_pos, lip)


## True when nothing in the world stands between the two points.
func _sees(a: Vector3, b: Vector3) -> bool:
	var params := PhysicsRayQueryParameters3D.create(a, b, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	return hit.is_empty() or a.distance_to(hit["position"]) >= a.distance_to(b) - SIGHT_TOLERANCE


## The player is taking the view (a look, a recenter, aiming): the turn the framing had added becomes the
## player's own yaw, so nothing moves on screen.
func _take_over_assist(interpolated: bool = true) -> void:
	if yaw_assist == 0.0 and _assist_prev == 0.0 and _assist_target == 0.0:
		return
	yaw += lerpf(_assist_prev, yaw_assist, clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)) if interpolated else yaw_assist
	yaw_assist = 0.0
	_assist_prev = 0.0
	_assist_target = 0.0
	_assist_velocity = 0.0


func _cast_fraction(from: Vector3, motion: Vector3) -> float:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _shape
	params.transform = Transform3D(Basis.IDENTITY, from)
	params.motion = motion
	params.collision_mask = Layers.WORLD
	var excluded: Array[RID] = []
	if target is CollisionObject3D:
		excluded.append((target as CollisionObject3D).get_rid())
	params.exclude = excluded
	var result := get_world_3d().direct_space_state.cast_motion(params)
	return result[0] if result.size() > 0 else 1.0


func _on_setting_changed(key: String) -> void:
	if key == "fov_degrees":
		_apply_fov()
	elif key == "frame_line_after_catch" and not framing_enabled():
		_take_over_assist()  # switched off while a turn is held: the view stays where it is, it does not swing back


func _apply_fov() -> void:
	camera.fov = settings.fov_degrees
