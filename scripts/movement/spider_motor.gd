extends CharacterBody3D
## SpiderMotor (spec 19.3): owns the spider's position, velocity, support and movement state.
## T02: supported locomotion on floors, walls and undersides (spec 6.1, 6.2).
##
## While ATTACHED the motor keeps a support frame (spec 21.3 SupportState: surface id, contact
## point, normal N, validity tick). There is no gravity while attached: the support constraint
## holds the sphere at RADIUS + SKIN from the surface. Each tick:
##   1. steer: the intent is projected onto the tangent plane of N and the velocity accelerates
##      toward it (same rates as chunk 2, so floor walking feels the same);
##   2. move with collision (move_and_slide in floating mode, sliding along obstacles);
##   3. concave corner: a short probe along the intent. An eligible face whose normal differs from
##      N by more than CONCAVE_MIN_DEG becomes the support (floor to wall, wall to ceiling). A face
##      that cannot hold the spider just stops it;
##   4. re-acquire support with a ray along -N and re-seat the body when the correction is small.
##      The re-seat uses move_and_collide, so it never passes through geometry;
##   5. convex edge: when that ray misses, rays from ahead of and under the body, cast back toward
##      it, find the face around the corner. Support transfers only when that face can hold the
##      spider and the swept arc to the new seat is clear; the body then rotates about the edge over
##      ARC_MIN_S to ARC_MAX_S. With no valid face the spider becomes FALLING.
## Gravity is world-down and acts only while FALLING (spec 6.1). A falling spider takes the first
## surface it hits that can hold it and that it approaches (LANDING, then ATTACHED). Support only
## ever moves to a face the body touches or to the far side of an edge it is touching, so it never
## crosses empty space.
##
## Eligibility (data/surfaces, spec 21.2): a surface holds the spider if its profile is attachable
## or its normal is within 45 degrees of world up. Hysteresis: probe normals within
## NORMAL_IGNORE_DEG of N are ignored, a concave transition is not reversed onto the face just left
## for BACKTRACK_COOLDOWN_TICKS, and the body's up vector turns toward N at a capped rate.
## When the support turns sharply the motor rotates its stored intent and heading with it, so an
## intent set once keeps the spider walking over an edge, and transition_serial increments.
## The node's own basis is the body frame for presentation and the camera: y is the smoothed
## normal and -z the heading. The collider is a sphere, so collision does not depend on it.
## The motor takes an explicit intent from the player controller; it never reads input.
##
## Jumping (T03, spec 6.2, 6.3): begin_prepare() holds the spider still on its support (PREPARING;
## the intent is ignored, the body turns toward the aim point at a capped rate, which is cosmetic and
## never blocks a jump). commit_jump(plan) freezes the plan's launch impulse and the motor flies it:
## AIRBORNE integrates with semi-implicit Euler at the physics tick, v += g * dt then a move_and_collide
## of v * dt, which is exactly what the planner predicts (JumpMath). There is no steering and no
## retargeting in the air. A contact is classified: valid support (a face that can hold the spider,
## approached fast enough) gives LANDING then ATTACHED through the same support acquisition as a fall,
## with N taken from the hit, and may be a different surface than the one aimed at; a glancing hit, an
## edge, a surface that cannot hold the spider, or no contact at all gives FALLING with the existing
## landing logic. Outside play_bounds the spider is returned to its last supported position and
## out_of_bounds_reset says so. last_jump keeps the plan, the actual path and both landing centres.
##
## Safety line (T04, spec 9.1, 21.3 TetherState; see tether.gd). At takeoff the motor anchors a line to the
## surface it stands on, at the support contact point under the body, when that surface's profile allows
## silk (silk_anchor_allowed) and the plan's line_needed fits the maximum length. No remote aiming: the
## anchor is always the launch surface. During a normal leap the line pays out with the body (PAYOUT), so it
## never truncates the predicted arc. A landing completes the line: it stays behind, fades and is removed
## (completed_lines, at most MAX_COMPLETED_LINES). A miss (no contact within MISS_GRACE_TICKS of the
## predicted contact) or a contact that is not a landing locks the line at the paid-out length plus a short
## braking extension (LOCKED); the spider falls (FALLING) until the line takes the load, then HANGING. On
## the line, each tick: reel or lower (a reel shortens the rest length at the species reel speed and pulls
## the body in only by a collision-checked sweep; a body that cannot follow gives the line back and the reel
## stops with a cue), then gravity, swing damping and the unilateral constraint (Tether.constrain: it removes
## outward radial velocity only, keeps tangential motion and never pushes), then a swept move with one slide.
## Touching a face that can hold the spider takes hold of it (LANDING, then ATTACHED: the player climbs on
## as normal) and completes the line. When the straight line to the anchor is blocked, ONE bend point is
## placed on the edge it caught on (found by bisecting the body's motion this tick); a line that would need a
## second bend is "snagged" and cannot be reeled in (lowering and letting go still work). No general rope
## wrapping. The dynamics step never ends with more mechanical energy than it began with plus the reel's work
## (any numerical gain is taken off the speed and counted in energy_clamps). The one thing that can raise a
## body that has no speed to give is the physics engine's own collision recovery, which pushes a body pressed
## into something back out of it by a fraction of a millimetre; the trace records that as contact_lift. A hanging
## body that has been still for SETTLE_TICKS is held exactly where it is (resting) until the player works the
## line, the line changes or a surface changes, so a settled spider stays put instead of creeping. If the
## anchor's surface goes away (it leaves the
## physics world, is freed, or surface_availability_changed says so) the line comes loose with a cue. A
## state the line solver cannot resolve (non-finite numbers, or the constraint unmet for FALLBACK_TICKS) is a
## separate, labelled debug fallback, never presented as silk breaking. HANGING and REELING are spec 6.2
## names; release_line() lets go (FALLING). The body hangs head down from its spinnerets (cosmetic pose).

const SimClock = preload("res://scripts/core/sim_clock.gd")  # one game clock: count in its ticks, never the engine rate
const SpeciesProfile = preload("res://scripts/core/species_profile.gd")
const SurfaceProfile = preload("res://scripts/core/surface_profile.gd")
const SupportMath = preload("res://scripts/movement/support_math.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")
const JumpMath = preload("res://scripts/movement/jump_math.gd")
const JumpPlanner = preload("res://scripts/movement/jump_planner.gd")
const JumpPlan = preload("res://scripts/movement/jump_plan.gd")
const Tether = preload("res://scripts/movement/tether.gd")

signal state_changed(old_state: State, new_state: State)
## "concave", "convex" (an edge arc starts) or "slope" (a probe normal turned by SHARP_TURN_DEG or more).
signal support_transition(kind: String)
## A jump plan was committed: the flight starts on the next tick.
signal jump_committed(plan: RefCounted)
## A flight ended. `result` is last_jump: outcome "support" (landed), "glancing", "edge", "ineligible"
## or "timeout" (then the spider is FALLING), with the plan, the path and the landing centres.
signal jump_ended(result: Dictionary)
## The spider left play_bounds and was put back at its last supported position.
signal out_of_bounds_reset(from_position: Vector3, to_position: Vector3)
## Something happened to the safety line. kind: "anchored" (detail: the anchor's surface id), "no_anchor"
## (detail: "no_silk", "too_long" or "no_support"), "locked" (a miss: the paid-out length froze), "caught"
## (the line took the load), "completed" (back on a surface; the line stays behind and fades), "released"
## (let go on purpose), "lost" (the anchor's surface went away; detail: its id), "blocked" (detail: "blocked"
## or "shortest": reeling stopped), "snagged" (the line would need a second bend), "fallback" (detail: why
## the debug fallback put the spider back).
signal line_event(kind: String, detail: String)

## Spec 6.2 names. LANDING is the brief re-attach after a fall or a jump. PREPARING and AIRBORNE are
## the jump (T03); HANGING (on a taut safety line) and REELING (taking line in) are T04. FEEDING and
## RESTING come later. New names go at the end.
enum State { ATTACHED, FALLING, LANDING, PREPARING, AIRBORNE, HANGING, REELING }


## Spec 21.3. surface_id is the persistent id of the surface instance (never a node path);
## local_contact_point is in that surface's local space.
class SupportState extends RefCounted:
	var surface_id: String = ""
	var profile_id: String = ""
	var contact_point: Vector3 = Vector3.ZERO
	var local_contact_point: Vector3 = Vector3.ZERO
	var normal: Vector3 = Vector3.UP
	var valid_tick: int = -1

	func is_valid() -> bool:
		return surface_id != ""


const ACCELERATION := 20.0       # WU/s^2 toward the wanted velocity; about 0.12 s to walking speed
const DECELERATION := 28.0       # WU/s^2 when no input
const TURN_RATE_DEG_S := 540.0   # cap on how fast the heading turns toward the intent
const MIN_TURN_INTENT := 0.1
const MAX_FALL_SPEED := 60.0     # WU/s
const SKIN := 0.01               # WU kept between the collider and its support
const SEAT_TOLERANCE := 0.12     # WU: the largest re-seat; a surface farther away has fallen away
const SEAT_STEP_MAX := 0.02      # WU per tick: re-seating glides instead of jumping
const NORMAL_IGNORE_DEG := 2.0   # probe normals closer than this to N do not move the frame
const SAME_SUPPORT_MAX_DEG := 45.0  # a probe normal turned more than this is an edge, not a slope
const SHARP_TURN_DEG := 20.0     # a support change at least this large counts as a transition
const CONCAVE_MIN_DEG := 30.0    # a face ahead turned more than this is a corner to climb
const CONCAVE_PROBE := 0.05      # WU beyond the skin that the corner probe looks ahead
const CONCAVE_PUSH_MIN := 0.25   # how much the intent must point into a face to climb it (about 15 degrees)
const FACE_MATCH_DEG := 8.0      # contact normal versus face normal: more means an edge contact
const CRACK_AHEAD := 0.2         # WU: a gap narrower than this under the body is bridged
const EDGE_AHEAD := 0.35         # WU ahead of the body where the convex probes start
const EDGE_DEPTHS: Array[float] = [0.04, 0.12, 0.25, 0.4]  # WU below the old surface, shallowest first
const EDGE_MIN_DEG := 20.0
const EDGE_REACH := 0.25         # WU: the edge must be this close to the seat distance
const ARC_MIN_S := 0.15
const ARC_MAX_S := 0.6           # the arc time follows the speed (arc length / speed); at stalk speed it is slow
const ARC_SAMPLES := 6
const CLEARANCE := 0.02          # WU: arc checks use a sphere this much smaller than the collider
const VISUAL_TURN_DEG_S := 600.0 # cap on how fast the body's up vector follows N
const LANDING_TICKS := 6
const LAND_APPROACH_MIN := JumpMath.LAND_APPROACH_MIN  # WU/s into a wall or underside needed to catch it, falling or jumping
const ACQUIRE_REACH := 0.3       # WU below the body searched for support after a teleport
const ACQUIRE_TICKS := 3         # ticks a spawned spider waits for the world to become visible to queries
const BACKTRACK_COOLDOWN_TICKS := 8
const PREPARE_TURN_RATE_DEG_S := 360.0  # cosmetic: how fast the body turns toward the aim point while preparing
## T10a: how far either way of the body's gaze the principal eyes' retinas can point the sharp field (see set_scan_direction).
const PRINCIPAL_SCAN_DEG := 30.0
const EYE_FORWARD := 0.18               # WU from the body centre along the facing, and EYE_UP along the body's up: where the
const EYE_UP := 0.08                    # eyes are. Both inside the 0.3 WU collider, so a ray from the eye never starts in the world
const FOCUS_TURN_FALLBACK_DEG_S := 180.0  # used when there is no species profile: see the profile's perception section
const GAZE_PITCH_FALLBACK_DEG := 35.0
const COMMIT_ORIGIN_TOLERANCE := 0.02   # WU: a plan must start where the body is
const AIR_MAX_STEPS := 150              # ticks of flight without any contact before the spider is let fall
const HOP_PROBE_UP := 0.5               # WU: a hop looks for its ground from this far off the surface at its end...
const HOP_PROBE_DOWN := 1.2             # ...to this far below it
const MISS_GRACE_TICKS := 3             # no contact this many ticks after the predicted one: a miss
const LINE_BRAKE_EXTENSION := 0.25      # WU the line runs on after a miss before it holds
const LINE_NEEDED_FACTOR := 1.15        # a jump gets a line only if line_needed * this + margin fits the
const LINE_NEEDED_MARGIN := 0.5         # maximum (a line wrapped over an edge is a little longer)
const LINE_MIN_REST := 0.4              # WU: the shortest the line reels in to (from the anchor or the bend)
const LINE_LIFT := 0.02                 # WU off a surface where line checks start (anchor)
const BEND_OFFSET := 0.03               # WU a bend point sits off the edge it wraps
const BEND_SEARCH_STEPS := 12
const LINE_RAY_MARGIN := 0.02           # WU short of the end that a line check stops
const REEL_BLOCK_FRACTION := 0.25       # a reel step that moves the body less than this share of the shortening is blocked
const HANG_DAMPING := 1.6               # 1/s: swing damping while hanging on a taut line (a small, quickly settling pendulum)
const SETTLE_SPEED := 0.05              # WU/s: a hanging body slower than this for SETTLE_TICKS comes to rest
const SETTLE_TICKS := 20
const REST_MOVE_EPS := 1e-5             # WU: an anchor or pivot that moves more than this wakes a resting body
const ENERGY_EPS := 5e-5               # WU^2/s^2: gains below this are float32 rounding, not numerical drift
const HANG_POSE_SECONDS := 0.25         # cosmetic: time to turn head down on the line, and back
const SPINNERET_LOCAL := Vector3(0.0, 0.02, 0.48)  # where the drawn line leaves the body (abdomen tip, body frame)
const COMPLETED_LINE_SECONDS := 6.0     # a completed line stays this long (it fades out over the last part)
const MAX_COMPLETED_LINES := 6
const FALLBACK_TICKS := 30              # ticks the constraint may stay unmet before the debug fallback
const FALLBACK_OVERSTRETCH := 0.25      # WU beyond the rest length that counts as unmet

## Injected before the node enters the tree. Tuning comes from this profile only.
var profile: SpeciesProfile.Profile
## Surface profiles by id (SurfaceProfile.load_dir), injected before the node enters the tree.
## Without them no surface is attachable: the spider can only stand.
var surfaces: Dictionary = {}
var state: State = State.FALLING
var last_landing_speed: float = 0.0
var support := SupportState.new()
## Increments when the support turns sharply (concave corner, convex edge, steep slope change).
## The player controller watches it to carry the heading across an edge.
var transition_serial: int = 0
## Rays cast in the last physics tick, for the F4 view: {"from", "to", "hit" (Vector3 or null)}.
var debug_rays: Array[Dictionary] = []
## The plan being flown, or the last one flown.
var jump_plan: RefCounted = null
## The last jump: {"plan", "committed_tick", "origin", "planned_center" (the plan's seat),
## "predicted_contact", "path" (actual body centres, one per tick), "outcome", "contact_center",
## "settled_center", "error_contact", "error_settled", "landed_surface", "ticks"}.
var last_jump: Dictionary = {}
## The habitat's allowed region. Outside it the spider is reset to its last supported position.
var play_bounds: AABB = AABB()
var bounds_enabled: bool = false
## The "Jump reach" playtest setting (Settings.jump_reach, 0.5 to 1.5). The planner scales the launch speed
## limit and the longest flight time by its square root; the safety line's maximum length scales with it.
## Set it before the node enters the tree, or call set_reach_factor().
var reach_factor: float = 1.0
## The safety line (spec 21.3 TetherState). mode NONE when there is none.
var tether: Tether = Tether.new()
## Lines left behind after a landing: {"points": PackedVector3Array, "age": float, "life": float,
## "anchor_surface_id": String, "anchor_body": Object}. They fade and are removed; never more than MAX_COMPLETED_LINES.
var completed_lines: Array[Dictionary] = []
## Tests: when true, every tick on a line appends a record to tether_trace (positions, velocities, lengths,
## energies, what the constraint did, overlap with the world). See _trace_tick.
var trace_tether: bool = false
var tether_trace: Array[Dictionary] = []
## Ticks in which the energy limit took speed off (numerical gain), and debug fallbacks so far.
var energy_clamps: int = 0
var tether_fallbacks: int = 0

var _walk_speed: float = 2.5
var _stalk_speed: float = 0.8
var _gravity: float = 35.0
var _radius: float = 0.3
var _intent: Vector3 = Vector3.ZERO
var _stalk: bool = false
var _heading: Vector3 = Vector3.FORWARD
var _visual_up: Vector3 = Vector3.UP
var _tick: int = 0
var _focus_on: bool = false          # Focus is held (spec 7): the body turns toward _focus_dir
var _focus_dir: Vector3 = Vector3.ZERO
var _scan_dir: Vector3 = Vector3.ZERO   # T10a: where the spider-eye view points the principal eyes; ZERO: straight ahead
var _focus_rate: float = deg_to_rad(FOCUS_TURN_FALLBACK_DEG_S)
var _gaze_limit: float = deg_to_rad(GAZE_PITCH_FALLBACK_DEG)
var _gaze_pitch: float = 0.0         # how far the gaze is tilted off the support plane, radians, up positive
var _landing_left: int = 0
var _acquire_ticks_left: int = ACQUIRE_TICKS
var _probe_shape: SphereShape3D
var _support_collider_id: int = 0
var _left_collider_id: int = 0
var _left_normal: Vector3 = Vector3.ZERO
var _left_ticks: int = 0
var _arc_active: bool = false
var _arc_pivot: Vector3 = Vector3.ZERO
var _arc_offset: Vector3 = Vector3.ZERO
var _arc_axis: Vector3 = Vector3.RIGHT
var _arc_turn: float = 0.0
var _arc_from_normal: Vector3 = Vector3.UP
var _arc_from_heading: Vector3 = Vector3.FORWARD
var _arc_from_velocity: Vector3 = Vector3.ZERO
var _arc_elapsed: float = 0.0
var _arc_duration: float = 0.2
var _arc_hit: Dictionary = {}
var _arc_normal: Vector3 = Vector3.UP
var _aim_dir: Vector3 = Vector3.ZERO
var _air_velocity: Vector3 = Vector3.ZERO
var _air_gravity: Vector3 = Vector3(0.0, -35.0, 0.0)
var _air_dt: float = 1.0 / 60.0
var _air_step: int = 0
var _flight_path: PackedVector3Array = PackedVector3Array()
var _safe_transform: Transform3D = Transform3D.IDENTITY
var _planner: RefCounted
var _query: RefCounted
var _support_body: Variant = null  # the support's collider (Node3D), for the anchor
var _anchor_body: Variant = null
var _bend_body: Variant = null
var _reel_speed: float = 1.5
var _line_max_base: float = 20.0
var _line_prev_body: Vector3 = Vector3.ZERO
var _settle_count: int = 0
var _overstretch_ticks: int = 0
var _hang_blend: float = 0.0
var _hang_dir: Vector3 = Vector3.UP
var _lost_surfaces: Dictionary = {}  # surface ids announced unavailable
var _line_grabbed: bool = false      # set when a contact on the line took hold this tick
var _hold_work: float = 0.0          # potential energy the legs added seating the body when it took hold
var _grab_y_before: float = 0.0      # the body's height at the contact, before the legs seated it (trace accounting)
var _contact_lift: float = 0.0       # potential energy the engine's collision recovery gave the body this tick (trace)
var _asleep: bool = false            # a hanging body that has been still is held exactly where it is
var _rest_touching: bool = false     # it rests touching something (else only the line holds it)
var _rest_anchor: Vector3 = Vector3.ZERO
var _rest_pivot: Vector3 = Vector3.ZERO
var _rest_length: float = 0.0


func _ready() -> void:
	collision_layer = Layers.SPIDER
	collision_mask = Layers.WORLD
	motion_mode = MOTION_MODE_FLOATING
	var col := get_node_or_null("Collider") as CollisionShape3D
	if col != null and col.shape is SphereShape3D:
		_radius = (col.shape as SphereShape3D).radius
	_probe_shape = SphereShape3D.new()
	_probe_shape.radius = maxf(_radius - CLEARANCE, 0.01)
	if profile == null:
		push_error("SpiderMotor: no species profile set, using built-in defaults")
	else:
		_walk_speed = profile.walk_speed_wu_s
		_stalk_speed = profile.stalk_speed_wu_s
		_gravity = profile.gravity_wu_s2
		_reel_speed = profile.reel_speed_wu_s
		_line_max_base = profile.max_line_length_wu
		_focus_rate = deg_to_rad(profile.focus_turn_rate_deg_s)
		_gaze_limit = deg_to_rad(profile.gaze_pitch_limit_deg)
	_reset_frame_from_basis()
	_safe_transform = global_transform
	reset_physics_interpolation()


## world_dir is limited to length 1, so a partly tilted stick walks slower. Each tick it is
## projected onto the support's tangent plane. Held until the next call; the motor rotates it with
## the support when the support turns sharply.
func set_intent(world_dir: Vector3, stalk: bool) -> void:
	_intent = world_dir.limit_length(1.0) if world_dir.is_finite() else Vector3.ZERO
	_stalk = stalk


func get_intent() -> Vector3:
	return _intent


func is_stalking() -> bool:
	return _stalk


func get_state_name() -> String:
	return State.keys()[state]


## Physics ticks since the motor entered the tree; SupportState.valid_tick uses the same count.
func get_physics_tick() -> int:
	return _tick


## True while the spider is held by a surface (ATTACHED, LANDING or PREPARING).
func is_supported() -> bool:
	return (state == State.ATTACHED or state == State.LANDING or state == State.PREPARING) and support.is_valid()


func is_preparing() -> bool:
	return state == State.PREPARING


func is_airborne() -> bool:
	return state == State.AIRBORNE


## True while the safety line holds the spider after a miss (FALLING on a locked line, HANGING, REELING).
func is_on_line() -> bool:
	return tether.is_locked() and (state == State.FALLING or state == State.HANGING or state == State.REELING)


## HANGING or REELING.
func is_hanging() -> bool:
	return state == State.HANGING or state == State.REELING


## True while a hanging body that has come to rest is held still (see the class comment).
func is_resting() -> bool:
	return _asleep


## The longest line this spider pays out: the species maximum times the reach factor.
func get_line_max_length() -> float:
	return _line_max_base * reach_factor


## Where the body comes to rest on a locked line: straight below the pivot, the effective length away (a pendulum
## at rest). The camera frames the recovery from here, so its view does not chase the swing (A-017).
func get_line_rest_point() -> Vector3:
	if not tether.is_locked():
		return global_position
	return tether.pivot() + Vector3.DOWN * tether.effective_length()


## The point the line leaves its support at: the bend point, or the anchor when there is no bend (lifted a hair off
## its surface so that a ray to it is not stopped by that surface). The camera frames the recovery from it (A-017).
func get_line_lip() -> Vector3:
	return tether.bend_point if tether.has_bend else tether.anchor_point + tether.anchor_normal * 0.04


## Where the drawn line leaves the body (the spinnerets), interpolated for drawing.
func line_end_point(interpolated: bool = true) -> Vector3:
	var xf := get_global_transform_interpolated() if interpolated else global_transform
	return xf * SPINNERET_LOCAL


## What a jump from here would do with the line, for the anchor cue before commit:
## {"ok", "reason" ("ok", "no_support", "no_silk": the surface will not hold silk, "too_long": the jump
## needs more line than the maximum), "point" (the anchor point, the support contact under the body),
## "normal", "surface_id"}. A missing line never changes the jump itself (A-008).
func get_anchor_preview(plan: RefCounted = null) -> Dictionary:
	var out := {"ok": false, "reason": "no_support", "point": global_position, "normal": support.normal, "surface_id": ""}
	if not support.is_valid() or not is_instance_valid(_support_body):
		return out
	out["point"] = support.contact_point
	out["surface_id"] = support.surface_id
	var prof: SurfaceProfile.Profile = surfaces.get(support.profile_id)
	if prof == null or not prof.silk_anchor_allowed:
		out["reason"] = "no_silk"
		return out
	if plan != null and plan.is_valid() and plan.line_needed * LINE_NEEDED_FACTOR + LINE_NEEDED_MARGIN > get_line_max_length():
		out["reason"] = "too_long"
		return out
	out["ok"] = true
	out["reason"] = "ok"
	return out


## Reel intent from the player while on the line: +1 reel in, -1 lower, 0 neither. Letting go of reel
## clears a "blocked" stop, so the next reel tries again.
func set_reel_intent(x: float) -> void:
	var v := clampf(x, -1.0, 1.0) if is_finite(x) else 0.0
	if v <= 0.0 and tether.block_reason == "blocked":
		tether.block_reason = ""
	tether.reel_intent = v


## Lets go of the line on purpose: the spider falls freely. False when it is not on a line.
func release_line() -> bool:
	if not is_on_line():
		return false
	_drop_line("released", "")
	if state != State.FALLING:
		_set_state(State.FALLING)
	return true


## The world says a surface left (available false) or came back (spec 21.2). A line anchored to a surface
## that left comes loose on the next tick; completed lines anchored there are removed.
func on_surface_availability_changed(surface_id: String, available: bool) -> void:
	if _asleep and _rest_touching and not available:
		_wake()  # what it rests against may be the surface that went; a body held by the line alone does not care
	if available:
		_lost_surfaces.erase(surface_id)
	else:
		_lost_surfaces[surface_id] = true


## Tests and debugging: runs the line solver's fallback as if it had failed.
func debug_force_tether_fallback(reason: String) -> void:
	_tether_fallback(reason)


## True while the body rotates about a convex edge.
func in_transition() -> bool:
	return _arc_active


## T12a: the solid piece under the spider's feet (null when it has no support), for the vibration sense.
func get_support_body() -> Object:
	return _support_body if is_supported() and is_instance_valid(_support_body) else null


## Normal of the support frame (hysteresis applied); the last one while falling.
func get_support_normal() -> Vector3:
	return support.normal


## The smoothed normal: the body's up vector. The camera pivot follows it.
func get_visual_up() -> Vector3:
	return _visual_up


## Unit heading on the support plane.
func get_heading_vector() -> Vector3:
	return _heading


## Heading in radians about world up, from the heading's horizontal part (as in chunk 2).
func get_heading() -> float:
	return atan2(-_heading.x, -_heading.z)


## Focus (spec 7, 17): deliberate orientation and inspection. While it is on, the body turns toward `world_dir` (the
## direction the player's camera aims, from the controller) at the species' focus rate, and the gaze tilts toward it,
## up to the species' gaze limit. The camera alone never changes where the spider looks: only Focus and moving do.
func set_focus(on: bool, world_dir: Vector3 = Vector3.ZERO) -> void:
	_focus_on = on and world_dir.is_finite() and world_dir.length_squared() > 1e-8
	_focus_dir = world_dir.normalized() if _focus_on else Vector3.ZERO


func is_focusing() -> bool:
	return _focus_on


## The direction Focus is turning toward, ZERO when it is off.
func get_focus_direction() -> Vector3:
	return _focus_dir


## The axis of the inspection cone. The body's own gaze (the facing tilted by the gaze pitch), unless the spider-eye view has pointed
## the principal eyes' retinas elsewhere (set_scan_direction): then that direction, held within PRINCIPAL_SCAN_DEG of the body's gaze.
func get_gaze_direction() -> Vector3:
	var axis := get_body_gaze_direction()
	if _scan_dir == Vector3.ZERO:
		return axis
	var angle := axis.angle_to(_scan_dir)
	var reach := deg_to_rad(PRINCIPAL_SCAN_DEG)
	if angle <= reach:
		return _scan_dir
	var turn_axis := axis.cross(_scan_dir)
	if turn_axis.length_squared() < 1e-10:
		return axis
	return axis.rotated(turn_axis.normalized(), reach).normalized()


## The facing tilted by the gaze pitch about the body's right: where the eyes point with the retinas centred.
func get_body_gaze_direction() -> Vector3:
	var b := SupportMath.body_basis(_visual_up, _heading)
	return ((-b.z) * cos(_gaze_pitch) + b.y * sin(_gaze_pitch)).normalized()


## T10a, the spider-eye view: where the player points the principal eyes (a world direction; ZERO: straight ahead). Salticid principal
## eyes are fixed lenses in front of movable retinas, which six muscles swing through about 50 degrees (Land 1969), so the sharp
## field can be pointed without turning the body, over a field of about 60 by 60 degrees (Tarsitano and Jackson 1992). Beyond that
## the body has to turn. Nothing else changes: facing, walking and jumping are as before.
func set_scan_direction(world_dir: Vector3) -> void:
	_scan_dir = world_dir.normalized() if world_dir.is_finite() and world_dir.length_squared() > 1e-8 else Vector3.ZERO


func get_scan_direction() -> Vector3:
	return _scan_dir


func get_gaze_pitch() -> float:
	return _gaze_pitch


## Where the eyes are, for the sensor and the gaze overlay. `interpolated` places them on the body as it is drawn.
## The radius of the body's collider, WU: what a fly sees of the spider and what a strike must come within (T07).
func get_body_radius() -> float:
	return _radius


func get_eye_position(interpolated: bool = false) -> Vector3:
	var b := SupportMath.body_basis(_visual_up, _heading)
	var origin := get_global_transform_interpolated().origin if interpolated and is_inside_tree() else global_position
	return origin + (-b.z) * EYE_FORWARD + b.y * EYE_UP


## Camera yaw for a recenter: behind the heading on floors and undersides, facing the surface on
## walls, blended by tilt. Returns `fallback` when neither is defined.
func get_recenter_yaw(fallback: float) -> float:
	var n := _visual_up
	var w := n.y * n.y
	var v := Vector3(_heading.x, 0.0, _heading.z) * w + Vector3(-n.x, 0.0, -n.z) * (1.0 - w)
	if v.length() < 1e-3:
		return fallback
	return atan2(-v.x, -v.z)


## Moves the spider without interpolating the move. The next tick looks for support along the
## new basis's -Y (so a teleport onto a wall works) and otherwise falls.
func teleport_to(xform: Transform3D) -> void:
	global_transform = xform
	velocity = Vector3.ZERO
	_intent = Vector3.ZERO
	_arc_active = false
	_aim_dir = Vector3.ZERO
	tether.clear()
	_asleep = false
	_anchor_body = null
	_bend_body = null
	_hang_blend = 0.0
	_gaze_pitch = 0.0
	if not last_jump.is_empty():
		last_jump["pending_settle"] = false
		if state == State.AIRBORNE and last_jump.get("outcome", "") == "":
			last_jump["outcome"] = "interrupted"
	_reset_frame_from_basis()
	_clear_support()
	_set_state(State.FALLING)
	_acquire_ticks_left = ACQUIRE_TICKS
	reset_physics_interpolation()


## True when a preparation or a hop may start: standing on a surface and not rounding an edge.
func can_prepare() -> bool:
	return state == State.ATTACHED and support.is_valid() and not _arc_active


## ATTACHED to PREPARING. The spider holds still on its support; the intent is ignored until the
## preparation ends. False when it cannot start.
func begin_prepare() -> bool:
	if not can_prepare():
		return false
	velocity = Vector3.ZERO
	_aim_dir = Vector3.ZERO
	_set_state(State.PREPARING)
	return true


## PREPARING to ATTACHED: no penalty, no change of position or support. (The body may have turned
## toward the aim point; that is cosmetic and is kept.) False when not preparing.
func cancel_prepare() -> bool:
	if state != State.PREPARING:
		return false
	_aim_dir = Vector3.ZERO
	_set_state(State.ATTACHED)
	return true


## The world point the body turns toward while preparing (cosmetic; it never blocks a jump).
func set_aim_target(point: Vector3) -> void:
	var d := point - global_position
	_aim_dir = d.normalized() if point.is_finite() and d.length() > 1e-3 else Vector3.ZERO


func clear_aim_target() -> void:
	_aim_dir = Vector3.ZERO


## Commits a reachable plan: the launch impulse is frozen and the flight starts on the next tick. The
## plan must start where the body is and use the engine's tick. Returns false, and changes nothing, for
## a plan that is not reachable, a body that is not standing on a support, or a stale plan.
func commit_jump(plan: RefCounted) -> bool:
	if plan == null or not plan.is_valid():
		return false
	if state != State.PREPARING and state != State.ATTACHED:
		return false
	if not support.is_valid() or _arc_active:
		return false
	if global_position.distance_to(plan.origin) > COMMIT_ORIGIN_TOLERANCE:
		return false
	if absf(plan.dt - 1.0 / float(SimClock.HZ)) > 1e-9:
		return false
	if plan.velocity.dot(support.normal) <= 0.0 or not plan.velocity.is_finite():
		return false
	var anchor := get_anchor_preview(plan)
	var anchor_body: Variant = _support_body
	var launch_normal := support.normal
	jump_plan = plan
	_air_velocity = plan.velocity
	_air_gravity = plan.gravity
	_air_dt = plan.dt
	_air_step = 0
	_aim_dir = Vector3.ZERO
	_flight_path = PackedVector3Array([global_position])
	velocity = plan.velocity
	_arc_active = false
	last_jump = {
		"plan": plan, "committed_tick": _tick, "origin": global_position, "planned_center": plan.seat,
		"predicted_contact": plan.contact_center, "path": _flight_path, "outcome": "", "pending_settle": false,
		"contact_center": Vector3.ZERO, "settled_center": Vector3.ZERO, "error_contact": -1.0, "error_settled": -1.0,
		"landed_surface": "", "ticks": 0, "anchored": bool(anchor["ok"]), "anchor_reason": anchor["reason"], "line_ran_out": false,
	}
	_clear_support()
	_set_state(State.AIRBORNE)
	if anchor["ok"]:
		_anchor_line(anchor_body, anchor["point"], launch_normal)
	else:
		tether.clear()
		line_event.emit("no_anchor", str(anchor["reason"]))
	jump_committed.emit(plan)
	return true


## The shared jump planner (spec 19.3), tuned from this motor's own species profile, collider and
## physics tick, so a plan and the flight that follows it cannot disagree about gravity, size or time.
## Call it after the node is in the tree.
func get_jump_planner() -> RefCounted:
	if _planner == null:
		_planner = JumpPlanner.new()
		if profile != null:
			_planner.configure(profile, _radius + SKIN, surfaces, 1.0 / float(SimClock.HZ), reach_factor)
	return _planner


## Changes the jump reach factor (see reach_factor). A jump already in the air keeps its plan.
func set_reach_factor(k: float) -> void:
	reach_factor = clampf(k, 0.5, 1.5) if is_finite(k) else 1.0
	if _planner != null and profile != null:
		_planner.configure(profile, _radius + SKIN, surfaces, 1.0 / float(SimClock.HZ), reach_factor)


## Plans a jump from the current body position and support to `target` ({"point", "normal",
## "collider"}, or {} for no surface), against the live physics world with this body excluded.
func plan_jump(target: Dictionary) -> RefCounted:
	if _query == null:
		var exclude: Array[RID] = [get_rid()]
		_query = JumpPlanner.PhysicsQuery.new(get_world_3d().direct_space_state, _radius + JumpPlanner.SWEEP_MARGIN, exclude, Layers.WORLD)
	_query.space = get_world_3d().direct_space_state
	return get_jump_planner().plan(_query, global_position, support.normal, target)


## A short hop along the surface: a jump to the ground `distance` WU ahead of the body, planned and
## validated exactly like an aimed jump (same solver, same sweeps). A refusal comes back as a plan that
## is not reachable: reason "hop_blocked" (a wall or step in the way) or "no_ground" (nothing to land
## on ahead). Hops only work where gravity brings the spider back to its surface, so on a wall or an
## underside the solver itself says there is no launch.
func plan_hop(distance: float) -> RefCounted:
	var n := support.normal
	var h := SupportMath.tangent_dir(_heading, n)
	if h == Vector3.ZERO:
		h = SupportMath.any_perpendicular(n)
	var from := global_position
	var ahead := _ray(from, from + h * (distance + _radius + SKIN))
	if not ahead.is_empty():
		return _refusal(JumpPlan.Kind.OBSTRUCTED, "hop_blocked", ahead["position"], ahead["normal"], n)
	var end := from + h * distance
	var ground := _ray(end + n * HOP_PROBE_UP, end - n * HOP_PROBE_DOWN)
	if ground.is_empty():
		return _refusal(JumpPlan.Kind.UNREACHABLE, "no_ground", end - n * (_radius + SKIN), n, n)
	return plan_jump({"point": ground["position"], "normal": ground["normal"], "collider": ground.get("collider")})


func _refusal(kind: JumpPlan.Kind, reason: String, point: Vector3, normal: Vector3, launch_normal: Vector3) -> RefCounted:
	var p := JumpPlan.new()
	p.kind = kind
	p.reason = reason
	p.origin = global_position
	p.launch_normal = launch_normal
	p.target_point = point
	p.target_normal = normal
	p.seat = point + normal * (_radius + SKIN)
	p.dt = 1.0 / float(SimClock.HZ)
	p.gravity = Vector3(0.0, -_gravity, 0.0)
	return p


func _physics_process(delta: float) -> void:
	_tick += 1
	debug_rays.clear()
	if _left_ticks > 0:
		_left_ticks -= 1
	if bounds_enabled and not play_bounds.has_point(global_position):
		_reset_out_of_bounds()
		return
	if _acquire_ticks_left > 0:
		# Bodies added this frame are invisible to queries until the first physics step, so a
		# spawn looks for its support for a few ticks, holding still, before it may fall.
		_acquire_ticks_left -= 1
		if _acquire_below():
			_acquire_ticks_left = 0
		elif _acquire_ticks_left > 0:
			return
	if state == State.FALLING:
		if tether.is_locked():
			_tick_tethered(delta)
		else:
			_tick_falling(delta)
	elif state == State.AIRBORNE:
		_tick_airborne()
	elif state == State.HANGING or state == State.REELING:
		if tether.is_locked():
			_tick_tethered(delta)
		else:
			_set_state(State.FALLING)
			_tick_falling(delta)
	elif state == State.PREPARING:
		_tick_preparing(delta)
	else:
		if _arc_active:
			_tick_arc(delta)
		else:
			_tick_supported(delta)
		if state == State.LANDING:
			_landing_left -= 1
			if _landing_left <= 0:
				_set_state(State.ATTACHED)
				_note_settled()
		if state == State.ATTACHED and tether.is_locked():
			# Took hold of a surface from the line and is attached: the line stays behind. Until now it was
			# kept, so a hold that failed during LANDING would still be caught by it.
			_complete_line(support.contact_point)
	_age_completed_lines(delta)
	_remember_safe_spot()
	_update_body_frame(delta)
	_update_gaze(delta)


func _speed() -> float:
	return _stalk_speed if _stalk else _walk_speed


func _tick_supported(delta: float) -> void:
	var n := support.normal
	var dir := SupportMath.tangent_dir(_intent, n)
	var amount := minf(_intent.length(), 1.0)
	var steering := state == State.ATTACHED and dir != Vector3.ZERO and amount > 0.0
	var wanted := dir * amount * _speed() if steering else Vector3.ZERO
	var rate := ACCELERATION if steering else DECELERATION
	velocity = SupportMath.tangent(velocity, n).move_toward(wanted, rate * delta)
	var pre_velocity := velocity
	var start := global_position
	if velocity.length_squared() > 0.0:
		move_and_slide()
		velocity = SupportMath.tangent(velocity, n)
	if steering and amount >= MIN_TURN_INTENT and _try_concave(dir, pre_velocity):
		_turn_heading(delta)
		return
	var m := SupportMath.tangent_dir(global_position - start, n)
	if m == Vector3.ZERO:
		m = SupportMath.tangent_dir(pre_velocity, n)
	if m == Vector3.ZERO:
		m = dir
	if m == Vector3.ZERO:
		m = SupportMath.tangent_dir(_heading, n)
	if _reacquire(n, m):
		_turn_heading(delta)
		return
	if m != Vector3.ZERO and _try_convex(n, m):
		return
	_start_falling()


## Ray along -n from the body centre. True when the same surface, or a surface turned by less than
## SAME_SUPPORT_MAX_DEG that can hold the spider, is within reach; the frame and seat are updated.
func _reacquire(n: Vector3, m: Vector3) -> bool:
	var from := global_position
	var reach := _radius + SKIN + SEAT_TOLERANCE
	var hit := _ray(from, from - n * reach)
	if hit.is_empty():
		# A crack narrower than CRACK_AHEAD: the same plane continues just ahead. Keep the frame.
		var ahead := from + m * CRACK_AHEAD
		var hit2 := _ray(ahead, ahead - n * reach)
		if hit2.is_empty():
			return false
		var n2: Vector3 = hit2["normal"]
		if n2.angle_to(n) > deg_to_rad(NORMAL_IGNORE_DEG):
			return false
		support.valid_tick = _tick
		return true
	var hn: Vector3 = hit["normal"]
	if hn.angle_to(n) > deg_to_rad(SAME_SUPPORT_MAX_DEG):
		return false
	if not _eligible(hit, hn):
		return false
	var new_n := SupportMath.filter_normal(n, hn, NORMAL_IGNORE_DEG)
	if new_n != n:
		var sharp := new_n.angle_to(n) >= deg_to_rad(SHARP_TURN_DEG)
		_rotate_frame(SupportMath.rotation_between(n, new_n), "slope" if sharp else "")
	_take_support(hit, new_n)
	_seat(new_n, hit["position"])
	return true


## A face ahead along `dir` that the body touches or nearly touches. Climbs it when it can hold
## the spider and is turned enough; otherwise leaves the stop to the slide.
func _try_concave(dir: Vector3, pre_velocity: Vector3) -> bool:
	var n := support.normal
	var col := KinematicCollision3D.new()
	if not test_move(global_transform, dir * (SKIN + CONCAVE_PROBE), col):
		return false
	var cn := col.get_normal()
	if cn.dot(dir) > -CONCAVE_PUSH_MIN or cn.angle_to(n) < deg_to_rad(CONCAVE_MIN_DEG):
		return false
	var cp := col.get_position()
	var to := cp + (cp - global_position).normalized() * 0.05
	var hit := _ray(global_position, to)
	if hit.is_empty():
		return false
	var fn: Vector3 = hit["normal"]
	if fn.angle_to(cn) > deg_to_rad(FACE_MATCH_DEG):
		return false  # an edge, not a face
	if not _eligible(hit, fn):
		return false  # cannot hold the spider: it stops at the face
	if _left_ticks > 0 and int(hit["collider_id"]) == _left_collider_id and fn.angle_to(_left_normal) < deg_to_rad(FACE_MATCH_DEG):
		return false  # hysteresis: not straight back onto the face just left
	_left_collider_id = _support_collider_id
	_left_normal = n
	_left_ticks = BACKTRACK_COOLDOWN_TICKS
	var q := SupportMath.rotation_between(n, fn)
	velocity = SupportMath.tangent(q * pre_velocity, fn)
	_rotate_frame(q, "concave")
	_take_support(hit, fn)
	_seat(fn, hit["position"])
	return true


## Finds the face around a convex edge and starts the arc onto it. The search runs first along the
## outward direction across the edge (from the body's contact with it), then along the motion, so
## an edge crossed almost sideways is found too. False when there is no face, it cannot hold the
## spider, or the arc is blocked: the caller then falls.
func _try_convex(n: Vector3, m: Vector3) -> bool:
	var dirs: Array[Vector3] = []
	var out := _edge_outward(n)
	if out != Vector3.ZERO:
		dirs.append(out)
	if out == Vector3.ZERO or out.angle_to(m) > deg_to_rad(5.0):
		dirs.append(m)
	for d in dirs:
		var result := _convex_along(n, d)
		if result != 0:
			return result > 0
	return false


## Direction on the support plane from the edge the body touches out toward the body centre, or
## ZERO when the body touches nothing nearby or sits straight over its contact.
func _edge_outward(n: Vector3) -> Vector3:
	var shape := SphereShape3D.new()
	shape.radius = _radius + SKIN + 0.03
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, global_position)
	params.collision_mask = Layers.WORLD
	var info := get_world_3d().direct_space_state.get_rest_info(params)
	if info.is_empty():
		return Vector3.ZERO
	var point: Vector3 = info["point"]
	return SupportMath.tangent_dir(global_position - point, n, 1e-3)


## One search direction d: 1 when an arc started, -1 when the face around the corner was found
## but cannot hold the spider or the arc is blocked, 0 when nothing usable was found.
func _convex_along(n: Vector3, d: Vector3) -> int:
	var p := global_position
	var seat := _radius + SKIN
	for depth: float in EDGE_DEPTHS:
		var start := p - n * (seat + depth) + d * EDGE_AHEAD
		var hit := _ray(start, start - d * (EDGE_AHEAD + seat + 0.3))
		if hit.is_empty():
			continue
		var n2: Vector3 = hit["normal"]
		if n2.dot(d) < 0.2:
			continue  # not facing out of the corner
		var turn := n.angle_to(n2)
		if turn < deg_to_rad(EDGE_MIN_DEG):
			continue
		if not _eligible(hit, n2):
			return -1
		var line := SupportMath.edge_line(support.contact_point, n, hit["position"], n2)
		if line.is_empty():
			continue
		var pivot := SupportMath.closest_on_line(p, line[0], line[1])
		if pivot.distance_to(p) > seat + EDGE_REACH:
			continue  # some other surface, not the edge the body is on
		var axis := n.cross(n2).normalized()
		var offset := p - pivot
		for k in range(1, ARC_SAMPLES + 1):
			if _overlaps(pivot + offset.rotated(axis, turn * float(k) / float(ARC_SAMPLES))):
				return -1
		_begin_arc(pivot, offset, axis, turn, hit, n2)
		return 1
	return 0


func _begin_arc(pivot: Vector3, offset: Vector3, axis: Vector3, turn: float, hit: Dictionary, n2: Vector3) -> void:
	_arc_active = true
	_arc_pivot = pivot
	_arc_offset = offset
	_arc_axis = axis
	_arc_turn = turn
	_arc_from_normal = support.normal
	_arc_from_heading = _heading
	_arc_from_velocity = velocity
	_arc_hit = hit
	_arc_normal = n2
	_arc_elapsed = 0.0
	support.contact_point = pivot  # the body is held by the edge until the arc ends
	support.valid_tick = _tick
	var speed := maxf(velocity.length(), _stalk_speed)
	_arc_duration = clampf(offset.length() * turn / speed, ARC_MIN_S, ARC_MAX_S)
	transition_serial += 1
	support_transition.emit("convex")


func _tick_arc(delta: float) -> void:
	_arc_elapsed += delta
	var s := clampf(_arc_elapsed / _arc_duration, 0.0, 1.0)
	var angle := _arc_turn * s
	var before := global_position
	if move_and_collide(_arc_pivot + _arc_offset.rotated(_arc_axis, angle) - before) != null:
		# The path was clear when the arc began; something is in the way now. Let go.
		_arc_active = false
		_start_falling()
		return
	velocity = (global_position - before) / delta
	support.normal = _arc_from_normal.rotated(_arc_axis, angle).normalized()
	support.contact_point = _arc_pivot
	support.valid_tick = _tick
	_heading = _arc_from_heading.rotated(_arc_axis, angle).normalized()
	if s < 1.0:
		return
	_arc_active = false
	var q := Basis(_arc_axis, _arc_turn)
	_intent = q * _intent
	velocity = SupportMath.tangent(q * _arc_from_velocity, _arc_normal)
	_take_support(_arc_hit, _arc_normal)
	_seat(_arc_normal, _arc_hit["position"])


func _tick_falling(delta: float) -> void:
	velocity.y = maxf(velocity.y - _gravity * delta, -MAX_FALL_SPEED)
	var pre := velocity
	move_and_slide()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var cn := c.get_normal()
		var approach := -pre.dot(cn)
		if approach <= 0.0:
			continue
		var cp := c.get_position()
		var hit := _ray(global_position, cp + (cp - global_position).normalized() * 0.05)
		if hit.is_empty():
			continue
		var fn: Vector3 = hit["normal"]
		if fn.angle_to(cn) > deg_to_rad(FACE_MATCH_DEG) or not _eligible(hit, fn):
			continue
		var standing := fn.dot(Vector3.UP) >= cos(deg_to_rad(SurfaceProfile.STAND_MAX_DEG))
		if not standing and approach < LAND_APPROACH_MIN:
			continue
		_land(hit, fn, approach)
		return


## PREPARING: hold still, keep the support confirmed, turn toward the aim point (cosmetic).
func _tick_preparing(delta: float) -> void:
	velocity = Vector3.ZERO
	var n := support.normal
	var hit := _ray(global_position, global_position - n * (_radius + SKIN + SEAT_TOLERANCE))
	if hit.is_empty() or not _eligible(hit, hit["normal"]):
		_aim_dir = Vector3.ZERO
		_start_falling()
		return
	support.valid_tick = _tick
	_heading = SupportMath.tangent_dir(_heading, n)
	if _heading == Vector3.ZERO:
		_heading = SupportMath.any_perpendicular(n)
	var target := SupportMath.tangent_dir(_aim_dir, n)
	if target == Vector3.ZERO:
		return
	var max_step := deg_to_rad(PREPARE_TURN_RATE_DEG_S) * delta
	var angle := SupportMath.signed_angle(_heading, target, n)
	_heading = _heading.rotated(n, clampf(angle, -max_step, max_step)).normalized()


## AIRBORNE: the committed flight, exactly as JumpMath predicts it. No steering, no retargeting.
func _tick_airborne() -> void:
	_air_step += 1
	_air_velocity += _air_gravity * _air_dt
	var col: KinematicCollision3D = move_and_collide(_air_velocity * _air_dt)
	velocity = _air_velocity
	var flat := Vector3(_air_velocity.x, 0.0, _air_velocity.z)
	if flat.length() > 0.5:
		_heading = flat.normalized()  # cosmetic: the body points where it is going
	_flight_path.append(global_position)
	last_jump["path"] = _flight_path
	last_jump["ticks"] = _air_step
	_tick_payout()
	if col != null:
		_resolve_air_contact(col)
	elif jump_plan != null and jump_plan.contact_step > 0 and _air_step >= jump_plan.contact_step + MISS_GRACE_TICKS:
		_end_flight("missed", {}, Vector3.UP, 0.0)  # nothing where the plan landed: a miss
	elif _air_step >= AIR_MAX_STEPS:
		_end_flight("timeout", {}, Vector3.UP, 0.0)


## Classifies the first contact of a flight: valid support, a glancing hit, an edge or a surface that
## cannot hold the spider. Only valid support lands; everything else lets the spider fall with its
## velocity, and the existing falling logic catches it on whatever it can land on.
func _resolve_air_contact(col: KinematicCollision3D) -> void:
	var cn := col.get_normal()
	var cp := col.get_position()
	var approach := -_air_velocity.dot(cn)
	var hit := _ray(global_position, cp + (cp - global_position).normalized() * 0.05)
	var outcome := "edge"
	var fn := cn
	if not hit.is_empty():
		fn = hit["normal"]
		if fn.angle_to(cn) > deg_to_rad(FACE_MATCH_DEG):
			outcome = "edge"  # a rim or a corner, not a face
		elif not _eligible(hit, fn):
			outcome = "ineligible"
		else:
			var need := JumpMath.min_approach(fn)
			approach = -_air_velocity.dot(fn)
			outcome = "support" if approach >= need else "glancing"
	_end_flight(outcome, hit, fn, approach)


func _end_flight(outcome: String, hit: Dictionary, n: Vector3, approach: float) -> void:
	velocity = _air_velocity
	last_jump["outcome"] = outcome
	last_jump["contact_center"] = global_position
	last_jump["error_contact"] = global_position.distance_to(jump_plan.seat)
	if outcome == "support":
		if tether.is_active():
			_complete_line(hit["position"])
		_land(hit, n, approach)
		# The feet plant: a committed jump lands where its patch said instead of skidding on past it.
		velocity = Vector3.ZERO
		last_jump["landed_surface"] = support.surface_id
		last_jump["pending_settle"] = true
	else:
		_start_falling()
		if tether.mode == Tether.Mode.PAYOUT:
			_lock_line(LINE_BRAKE_EXTENSION)
	jump_ended.emit(last_jump)


## LANDING to ATTACHED after a jump: the settled landing centre.
func _note_settled() -> void:
	if not last_jump.get("pending_settle", false):
		return
	last_jump["pending_settle"] = false
	last_jump["settled_center"] = global_position
	last_jump["error_settled"] = global_position.distance_to(last_jump["planned_center"])


## Outside play_bounds: back to the last supported position, and say so.
func _reset_out_of_bounds() -> void:
	var from := global_position
	var back := _safe_transform
	teleport_to(back)
	out_of_bounds_reset.emit(from, back.origin)


func _remember_safe_spot() -> void:
	if state == State.ATTACHED and support.is_valid() and not _arc_active and _acquire_ticks_left == 0:
		_safe_transform = Transform3D(SupportMath.body_basis(support.normal, _heading), global_position)


func _land(hit: Dictionary, n: Vector3, approach: float) -> void:
	last_landing_speed = approach
	velocity = SupportMath.tangent(velocity, n)
	_heading = SupportMath.tangent_dir(_heading, n)
	if _heading == Vector3.ZERO:
		_heading = SupportMath.any_perpendicular(n)
	_take_support(hit, n)
	_seat(n, hit["position"])
	_landing_left = LANDING_TICKS
	_set_state(State.LANDING)


## After a teleport or spawn: support straight below along the body's -Y, without a landing.
func _acquire_below() -> bool:
	var down := -global_basis.y.normalized()
	var from := global_position
	var hit := _ray(from, from + down * (_radius + SKIN + ACQUIRE_REACH))
	if hit.is_empty():
		return false
	var n: Vector3 = hit["normal"]
	if not _eligible(hit, n):
		return false
	_take_support(hit, n)
	_seat(n, hit["position"])
	_visual_up = n
	_heading = SupportMath.tangent_dir(_heading, n)
	if _heading == Vector3.ZERO:
		_heading = SupportMath.any_perpendicular(n)
	_set_state(State.ATTACHED)
	return true


func _start_falling() -> void:
	_arc_active = false
	_clear_support()
	_set_state(State.FALLING)


func _clear_support() -> void:
	support.surface_id = ""
	support.profile_id = ""
	support.valid_tick = _tick
	_support_collider_id = 0
	_support_body = null


func _rotate_frame(q: Basis, kind: String) -> void:
	_intent = q * _intent
	_heading = (q * _heading).normalized()
	if kind != "":
		transition_serial += 1
		support_transition.emit(kind)


func _take_support(hit: Dictionary, n: Vector3) -> void:
	var collider: Object = hit.get("collider")
	var point: Vector3 = hit["position"]
	_support_body = collider
	support.surface_id = _surface_id(collider)
	support.profile_id = _profile_id(collider)
	support.contact_point = point
	support.local_contact_point = (collider as Node3D).global_transform.affine_inverse() * point if collider is Node3D else point
	support.normal = n
	support.valid_tick = _tick
	_support_collider_id = int(hit.get("collider_id", 0))


## Moves the body along n toward RADIUS + SKIN from the plane through surface_point, by at most
## SEAT_STEP_MAX per tick. Small corrections only, and collision-checked.
func _seat(n: Vector3, surface_point: Vector3) -> void:
	var correction := (global_position - surface_point).dot(n) - (_radius + SKIN)
	if absf(correction) < 1e-4 or absf(correction) > SEAT_TOLERANCE:
		return
	move_and_collide(-n * clampf(correction, -SEAT_STEP_MAX, SEAT_STEP_MAX))


func _turn_heading(delta: float) -> void:
	var n := support.normal
	_heading = SupportMath.tangent_dir(_heading, n)
	if _heading == Vector3.ZERO:
		_heading = SupportMath.any_perpendicular(n)
	if state != State.ATTACHED:
		return
	if _focus_on:
		# Focus decides where the body faces while it is held, at its own capped rate; the intent still decides where it walks.
		var look := SupportMath.tangent_dir(_focus_dir, n)
		if look != Vector3.ZERO:
			var step := _focus_rate * delta
			_heading = _heading.rotated(n, clampf(SupportMath.signed_angle(_heading, look, n), -step, step)).normalized()
		return
	if _intent.length() < MIN_TURN_INTENT:
		return
	var target := SupportMath.tangent_dir(_intent, n)
	if target == Vector3.ZERO:
		return
	var max_step := deg_to_rad(TURN_RATE_DEG_S) * delta
	var angle := SupportMath.signed_angle(_heading, target, n)
	_heading = _heading.rotated(n, clampf(angle, -max_step, max_step)).normalized()


## The gaze tilts toward the focus direction (within the gaze limit) while Focus is held on a support, and settles back to the
## support plane, at half that rate, when it is not. T10a: in the spider-eye view it tilts, at that half rate, toward the scan direction.
func _update_gaze(delta: float) -> void:
	var wanted := 0.0
	var rate := _focus_rate * 0.5
	if _focus_on and is_supported():
		wanted = clampf(asin(clampf(_focus_dir.dot(support.normal), -1.0, 1.0)), -_gaze_limit, _gaze_limit)
		rate = _focus_rate
	elif _scan_dir != Vector3.ZERO and is_supported():
		# T10a: in the spider-eye view the cephalothorax tilts toward where the principal eyes are pointed, within the same limit.
		wanted = clampf(asin(clampf(_scan_dir.dot(support.normal), -1.0, 1.0)), -_gaze_limit, _gaze_limit)
	_gaze_pitch = move_toward(_gaze_pitch, wanted, rate * delta)


func _update_body_frame(delta: float) -> void:
	var free := state == State.FALLING or state == State.AIRBORNE or state == State.HANGING or state == State.REELING
	var target_up := Vector3.UP if free else support.normal
	_visual_up = SupportMath.rotate_toward(_visual_up, target_up, deg_to_rad(VISUAL_TURN_DEG_S) * delta)
	var base := SupportMath.body_basis(_visual_up, _heading)
	# Cosmetic: on a taut line the body hangs head down from its spinnerets, back toward its old heading.
	# The camera follows _visual_up (world up here), not this pose.
	var hang := tether.is_locked() and tether.taut and is_hanging()
	_hang_blend = move_toward(_hang_blend, 1.0 if hang else 0.0, delta / HANG_POSE_SECONDS)
	if _hang_blend <= 0.0:
		global_basis = base
		return
	if tether.is_active():
		var to_pivot := tether.pivot() - global_position
		if to_pivot.length() > 1e-3:
			_hang_dir = to_pivot.normalized()
	var back := SupportMath.tangent_dir(_heading, _hang_dir)
	if back == Vector3.ZERO:
		back = SupportMath.any_perpendicular(_hang_dir)
	var hanging := SupportMath.body_basis(back, -_hang_dir)
	global_basis = Basis(base.get_rotation_quaternion().slerp(hanging.get_rotation_quaternion(), _hang_blend))


func _reset_frame_from_basis() -> void:
	var b := global_basis.orthonormalized()
	_visual_up = b.y
	_heading = SupportMath.tangent_dir(-b.z, b.y)
	if _heading == Vector3.ZERO:
		_heading = SupportMath.any_perpendicular(b.y)
	support.normal = b.y


# --- Safety line (T04) -------------------------------------------------------------------------------

func _anchor_line(body: Variant, point: Vector3, normal: Vector3) -> void:
	tether.clear()
	if not is_instance_valid(body) or not (body is Node3D):
		line_event.emit("no_anchor", "no_support")
		return
	var node := body as Node3D
	var inv := node.global_transform.affine_inverse()
	tether.mode = Tether.Mode.PAYOUT
	tether.anchor_surface_id = _surface_id(node)
	tether.anchor_profile_id = _profile_id(node)
	tether.anchor_local = inv * point
	tether.anchor_normal_local = (inv.basis * normal).normalized()
	tether.anchor_point = point
	tether.anchor_normal = normal
	tether.max_length = get_line_max_length()
	tether.rest_length = tether.max_length
	tether.paid_length = minf(point.distance_to(global_position), tether.max_length)
	tether.anchored_tick = _tick
	_asleep = false
	_anchor_body = node
	_bend_body = null
	_line_prev_body = global_position
	_lost_surfaces.erase(tether.anchor_surface_id)
	line_event.emit("anchored", tether.anchor_surface_id)


## During a leap: the line pays out with the body (it never pulls), wraps an edge if it meets one, and
## comes loose if its anchor goes away.
func _tick_payout() -> void:
	if tether.mode != Tether.Mode.PAYOUT:
		return
	if not _refresh_line_anchor():
		_drop_line("lost", tether.anchor_surface_id)
		return
	_update_line_geometry(_line_prev_body)
	_line_prev_body = global_position
	tether.paid_length = maxf(tether.paid_length, tether.path_length(global_position))
	tether.taut = false
	if tether.paid_length > tether.max_length:
		# The line ran out in mid-leap. A plan never needs this (the anchor is refused when line_needed does
		# not fit, with room for a bend); it is recorded so tests can show it never happens.
		tether.paid_length = tether.max_length
		last_jump["line_ran_out"] = true
		_lock_line(0.0)
	if trace_tether:
		_trace_payout()


## A miss: the paid-out length freezes, plus a short braking extension, and the line becomes the constraint.
func _lock_line(extension: float) -> void:
	tether.mode = Tether.Mode.LOCKED
	tether.paid_length = minf(maxf(tether.paid_length, tether.path_length(global_position)), tether.max_length)
	tether.rest_length = minf(tether.paid_length + maxf(extension, 0.0), tether.max_length)
	tether.caught_tick = -1
	tether.block_reason = ""
	tether.taut = false
	_asleep = false
	_settle_count = 0
	_overstretch_ticks = 0
	line_event.emit("locked", "")


## One tick on a locked line (FALLING slack, HANGING, REELING). See the class comment for the order.
func _tick_tethered(delta: float) -> void:
	var t := tether
	if not _refresh_line_anchor():
		_drop_line("lost", t.anchor_surface_id)
		if state != State.FALLING:
			_set_state(State.FALLING)
		_tick_falling(delta)
		return
	if _asleep:
		if _rest_disturbed():
			_wake()
		else:
			_tick_resting()
			return
	var p0 := global_position
	var v0 := velocity
	var e0 := Tether.energy(p0, v0, _gravity)
	var len0 := t.effective_length()
	_contact_lift = 0.0
	# 1. Reel in or lower. Only the rest length changes; a reel pulls the body in by a collision-checked
	# sweep toward the pivot and never through anything.
	var shortening := 0.0
	var reel_work := 0.0
	if t.reel_intent > 0.0 and t.block_reason == "" and not t.snagged:
		var shortest := t.anchor_to_pivot() + LINE_MIN_REST
		shortening = minf(_reel_speed * t.reel_intent * delta, maxf(t.rest_length - shortest, 0.0))
		if shortening <= 1e-6:
			shortening = 0.0
			_set_block("shortest")
		else:
			t.rest_length -= shortening
			var excess := t.path_length(p0) - t.rest_length
			if excess > 1e-6:
				_line_grabbed = false
				_line_move((t.pivot() - p0).normalized() * excess)
				if _line_grabbed:
					# The body reached a surface it can hold partway through the pull. The reel's work is the rise
					# up to the contact; the legs' seating after it is hold_work, a support matter, not the line's.
					reel_work = _gravity * (_grab_y_before - p0.y)
					_trace_end_tick(p0, v0, e0, e0 + reel_work, shortening, reel_work, len0, {})
					return
				reel_work = _gravity * (global_position.y - p0.y)
				# What the body could not take in (something in the way) the line gives back: no stored tension,
				# and the constraint below never finishes a pull the sweep refused.
				var path_now := t.path_length(global_position)
				if path_now > t.rest_length:
					t.rest_length = minf(path_now, t.max_length)
				if (global_position - p0).length() < excess * REEL_BLOCK_FRACTION:
					_set_block("blocked")  # the body cannot follow the line in: say so, never pull through
	elif t.reel_intent < 0.0:
		var before := t.rest_length
		t.rest_length = minf(t.rest_length + _reel_speed * -t.reel_intent * delta, t.max_length)
		if t.rest_length > before and t.block_reason == "shortest":
			t.block_reason = ""
	var p1 := global_position
	var e1 := Tether.energy(p1, velocity, _gravity)
	# 2. Gravity, swing damping, the line constraint on where the body would go, and a swept move.
	velocity.y = maxf(velocity.y - _gravity * delta, -MAX_FALL_SPEED)
	var pivot := t.pivot()
	var length := t.effective_length()
	if t.taut and is_hanging():
		var r := (p1 - pivot).normalized()
		var vt := velocity - r * velocity.dot(r)
		velocity -= vt * (1.0 - exp(-HANG_DAMPING * delta))
	var c := Tether.constrain(pivot, length, p1 + velocity * delta, velocity)
	velocity = c["velocity"]
	_line_grabbed = false
	var want: Vector3 = c["position"] - p1
	_line_move(want)
	if _line_grabbed:
		_trace_end_tick(p0, v0, e0, e1, shortening, reel_work, len0, c)
		return
	# 3. A slide may have carried the body past the rest length: back toward the pivot, swept, no speed added.
	var over := t.path_length(global_position) - t.rest_length
	var fix := Vector3.ZERO
	if over > 1e-4:
		fix = (t.pivot() - global_position).normalized() * over
		_line_move(fix)
		if _line_grabbed:
			_trace_end_tick(p0, v0, e0, e1, shortening, reel_work, len0, c)
			return
	# What the sweeps gave the body beyond what the line step asked of them: the engine's collision recovery
	# pushing a body that is pressed into something back out of it. It is the world's doing, not the line's,
	# and it is bounded (a fraction of a millimetre per sweep); the trace carries it so the energy check can
	# tell it from a gain made by the line.
	_contact_lift = _gravity * maxf(global_position.y - p1.y - want.y - fix.y, 0.0)
	# 4. Line geometry: one bend point at most; a line that would need two is snagged.
	var was_snagged := t.snagged
	_update_line_geometry(_line_prev_body)
	_line_prev_body = global_position
	if t.snagged and not was_snagged:
		line_event.emit("snagged", "")
	# 5. No energy from numerical error: the dynamics step may not end with more than it began with.
	var clamped := false
	var e2 := Tether.energy(global_position, velocity, _gravity)
	if e2 > e1 + ENERGY_EPS:
		var ke := 0.5 * velocity.length_squared()
		var allowed := maxf(e1 - _gravity * global_position.y, 0.0)
		velocity *= sqrt(clampf(allowed / ke, 0.0, 1.0)) if ke > 1e-12 else 0.0
		energy_clamps += 1
		clamped = true
	# 6. Lengths, taut, states, settling.
	var path := t.path_length(global_position)
	t.paid_length = minf(maxf(t.paid_length, path), t.rest_length)
	t.taut = path >= t.rest_length - Tether.TAUT_EPS
	if t.taut and t.caught_tick < 0:
		t.caught_tick = _tick
		line_event.emit("caught", "")
	if state == State.FALLING and t.taut:
		_set_state(State.HANGING)
	if is_hanging():
		_set_state(State.REELING if shortening > 0.0 and t.block_reason == "" else State.HANGING)
	if state == State.HANGING and t.taut and velocity.length() < SETTLE_SPEED and not _reel_can_act():
		_settle_count += 1
		if _settle_count >= SETTLE_TICKS:
			velocity = Vector3.ZERO
			_fall_asleep()
	else:
		_settle_count = 0
	_overstretch_ticks = _overstretch_ticks + 1 if path > t.rest_length + FALLBACK_OVERSTRETCH else 0
	_trace_end_tick(p0, v0, e0, e1, shortening, reel_work, len0, c, clamped)
	if not (global_position.is_finite() and velocity.is_finite() and t.is_consistent(0.01)):
		_tether_fallback("non-finite or inconsistent line state")
	elif _overstretch_ticks > FALLBACK_TICKS:
		_tether_fallback("the line constraint could not be met")


## True when working the line would change something: reeling in (not blocked, not snagged) or lowering (not at the maximum).
func _reel_can_act() -> bool:
	var t := tether
	return (t.reel_intent > 0.0 and t.block_reason == "" and not t.snagged) or (t.reel_intent < 0.0 and t.rest_length < t.max_length)


## A hanging body that has been still for SETTLE_TICKS is held exactly where it is. Without this the velocity
## would be zeroed every tick but gravity's sideways pull would still creep it, slowly, toward the bottom of
## its swing (a second or two of drift at a fraction of a millimetre a tick). The body is within about a
## centimetre of where the swing would end, or held by something it is pressed against.
func _fall_asleep() -> void:
	_asleep = true
	_rest_touching = _overlaps_world(global_position, _radius + 0.02)
	_rest_anchor = tether.anchor_point
	_rest_pivot = tether.pivot()
	_rest_length = tether.rest_length


## Back to the dynamics, which must show the body is still for SETTLE_TICKS again before it rests.
func _wake() -> void:
	_asleep = false
	_settle_count = 0


## A resting body wakes when the player works the line, when its anchor or pivot moved, when the line's length
## changed, or when it is no longer a plain taut hang. A surface going away wakes a body that rests touching
## something (see on_surface_availability_changed).
func _rest_disturbed() -> bool:
	var t := tether
	return state != State.HANGING or not t.taut or _reel_can_act() \
		or t.anchor_point.distance_to(_rest_anchor) > REST_MOVE_EPS or t.pivot().distance_to(_rest_pivot) > REST_MOVE_EPS \
		or absf(t.rest_length - _rest_length) > 1e-6


## One tick of a resting body: nothing moves, but the line still follows its geometry, so an obstacle that
## appears across it snags it, and a bend that forms or goes wakes the body.
func _tick_resting() -> void:
	var t := tether
	velocity = Vector3.ZERO
	var had_bend := t.has_bend
	var was_snagged := t.snagged
	_update_line_geometry(_line_prev_body)
	_line_prev_body = global_position
	if t.snagged and not was_snagged:
		line_event.emit("snagged", "")
	if t.has_bend != had_bend or t.snagged != was_snagged:
		_wake()
	_contact_lift = 0.0
	var e := Tether.energy(global_position, Vector3.ZERO, _gravity)
	_trace_end_tick(global_position, Vector3.ZERO, e, e, 0.0, 0.0, t.effective_length(), {})


## Moves the body on the line with collision: a sweep, then one slide along what it touched. Touching a face
## that can hold the spider ends the line there (the spider takes hold).
func _line_move(motion: Vector3) -> void:
	if motion.length_squared() < 1e-14:
		return
	var col := move_and_collide(motion)
	if col == null or _grab_from_line(col):
		return
	var n := col.get_normal()
	var vn := velocity.dot(n)
	if vn < 0.0:
		velocity -= n * vn
	var rest := col.get_remainder()
	rest -= n * rest.dot(n)
	if rest.length_squared() < 1e-14:
		return
	var col2 := move_and_collide(rest)
	if col2 == null or _grab_from_line(col2):
		return
	var n2 := col2.get_normal()
	var vn2 := velocity.dot(n2)
	if vn2 < 0.0:
		velocity -= n2 * vn2


## A contact while on the line: the spider takes hold of a face that can hold it (D-010), at any approach,
## through the same acquisition as a landing (LANDING, then ATTACHED, where T02's support and edge rules take
## over). At an edge the face is looked for around the contact point, so bumping into a lip it can grip (the
## underside of an overhang, the end of a cap) is a hold too. The line is kept until the spider is ATTACHED,
## so a hold that does not work out (no support after all) is still caught by it.
func _grab_from_line(col: KinematicCollision3D) -> bool:
	var hit := _find_grab_face(col)
	if hit.is_empty():
		return false
	var fn: Vector3 = hit["normal"]
	var approach := maxf(-velocity.dot(fn), 0.0)
	var y_before := global_position.y
	_land(hit, fn, approach)
	velocity = Vector3.ZERO  # the feet take hold
	_grab_y_before = y_before
	_hold_work = _gravity * (global_position.y - y_before)  # the seat step (at most SEAT_STEP_MAX), for the trace
	_line_grabbed = true
	# The legs hold the body now, not the line. The record stays consistent while the line waits for ATTACHED
	# (it still catches the body if the hold falls through): never more paid out than the rest length.
	tether.paid_length = minf(tether.paid_length, tether.rest_length)
	tether.taut = false
	return true


## The face to take hold of at a contact: rays from the body centre to the contact point, and to points 0.05 WU
## to either side of it, each carried 0.1 WU past. The first face that can hold the spider and faces the body
## wins, preferring the face whose normal is closest to the contact normal. {} when there is none.
func _find_grab_face(col: KinematicCollision3D) -> Dictionary:
	var cn := col.get_normal()
	var cp := col.get_position()
	var center := global_position
	var dir := cp - center
	if dir.length() < 1e-5:
		dir = -cn
	dir = dir.normalized()
	var e1 := SupportMath.any_perpendicular(dir)
	var e2 := dir.cross(e1).normalized()
	var best: Dictionary = {}
	var best_angle := INF
	for offset: Vector3 in [Vector3.ZERO, e1 * 0.05, -e1 * 0.05, e2 * 0.05, -e2 * 0.05]:
		var aim := cp + offset
		var hit := _query_ray(center, aim + (aim - center).normalized() * 0.1)
		if hit.is_empty():
			continue
		var fn: Vector3 = hit["normal"]
		if fn.dot(center - (hit["position"] as Vector3)) <= 0.0 or not _eligible(hit, fn):
			continue
		var angle := fn.angle_to(cn)
		if angle < best_angle:
			best_angle = angle
			best = hit
		if offset == Vector3.ZERO and angle <= deg_to_rad(FACE_MATCH_DEG):
			break
	return best


## Back on a surface: the line stays behind from its anchor (over its bend) to `end`, fades, and goes.
func _complete_line(end: Vector3) -> void:
	if not tether.is_active():
		return
	completed_lines.append({"points": tether.points(end), "age": 0.0, "life": COMPLETED_LINE_SECONDS,
		"anchor_surface_id": tether.anchor_surface_id, "anchor_body": _anchor_body})
	while completed_lines.size() > MAX_COMPLETED_LINES:
		completed_lines.pop_front()
	tether.clear()
	_asleep = false
	_anchor_body = null
	_bend_body = null
	line_event.emit("completed", "")


func _drop_line(kind: String, detail: String) -> void:
	tether.clear()
	_asleep = false
	_anchor_body = null
	_bend_body = null
	line_event.emit(kind, detail)


func _age_completed_lines(delta: float) -> void:
	for i in range(completed_lines.size() - 1, -1, -1):
		var line: Dictionary = completed_lines[i]
		line["age"] = float(line["age"]) + delta
		if float(line["age"]) >= float(line["life"]) or not _surface_available(line.get("anchor_body"), str(line["anchor_surface_id"])):
			completed_lines.remove_at(i)


func _set_block(reason: String) -> void:
	if tether.block_reason != reason:
		tether.block_reason = reason
		line_event.emit("blocked", reason)


## Refreshes the anchor (and bend) from their surfaces' transforms. False when the anchor's surface is gone.
func _refresh_line_anchor() -> bool:
	if not _surface_available(_anchor_body, tether.anchor_surface_id):
		return false
	var xf: Transform3D = (_anchor_body as Node3D).global_transform
	tether.anchor_point = xf * tether.anchor_local
	tether.anchor_normal = (xf.basis * tether.anchor_normal_local).normalized()
	if tether.has_bend:
		if _surface_available(_bend_body, tether.bend_surface_id):
			tether.bend_point = (_bend_body as Node3D).global_transform * tether.bend_local
		else:
			tether.has_bend = false
			_bend_body = null
	return true


## A surface is available while its node exists in the tree, is in the physics world (WORLD layer), has not
## been marked unavailable, and has not been announced gone.
func _surface_available(body: Variant, surface_id: String) -> bool:
	if body == null or not is_instance_valid(body) or not (body is Node3D):
		return false
	var node := body as Node3D
	if not node.is_inside_tree() or _lost_surfaces.has(surface_id):
		return false
	if node is CollisionObject3D and ((node as CollisionObject3D).collision_layer & Layers.WORLD) == 0:
		return false
	return bool(node.get_meta("surface_available", true))


## Keeps the line's path free of geometry with at most one bend point. With a bend: the bend goes when the
## straight line is clear again (the line is then no longer than before), and the line is snagged while the
## bend-to-body part is blocked. Without one: a blocked straight line gets a bend at the edge it caught on,
## found by bisecting the body's motion since `prev_body` (the last clear line). When no single bend clears
## it (something moved into the line), the line is snagged.
func _update_line_geometry(prev_body: Vector3) -> void:
	var t := tether
	var a := t.anchor_point + t.anchor_normal * LINE_LIFT
	var body := global_position
	if t.has_bend:
		if _line_clear(a, body):
			t.has_bend = false
			_bend_body = null
			t.snagged = false
			return
		t.snagged = not _line_clear(t.bend_point, body)
		return
	if _line_clear(a, body):
		t.snagged = false
		return
	var bend := _find_bend(a, prev_body, body)
	if bend.is_empty():
		t.snagged = true
		return
	t.has_bend = true
	t.bend_point = bend["point"]
	_bend_body = bend["body"]
	t.bend_surface_id = _surface_id(_bend_body)
	t.bend_local = (_bend_body as Node3D).global_transform.affine_inverse() * t.bend_point if _bend_body is Node3D else t.bend_point
	if t.is_locked():
		# Wrapping does not shorten the line: at the moment it touched, the path over the edge was the
		# straight path. The bend's small offset off the edge is given to the rest length.
		t.rest_length = minf(maxf(t.rest_length, t.path_length(body)), t.max_length)
	t.snagged = not _line_clear(t.bend_point, body)


func _find_bend(a: Vector3, p_prev: Vector3, p_now: Vector3) -> Dictionary:
	if not _line_clear(a, p_prev):
		return {}
	var lo := 0.0
	var hi := 1.0
	for i in BEND_SEARCH_STEPS:
		var mid := (lo + hi) * 0.5
		if _line_clear(a, p_prev.lerp(p_now, mid)):
			lo = mid
		else:
			hi = mid
	var hit := _query_ray(a, p_prev.lerp(p_now, hi))
	if hit.is_empty():
		return {}
	var h: Vector3 = hit["position"]
	var n: Vector3 = hit["normal"]
	var toward := p_now - h
	toward -= n * toward.dot(n)
	var side := toward.normalized() if toward.length() > 1e-6 else Vector3.ZERO
	for k: float in [1.0, 2.0, 4.0]:
		var point := h + (n + side) * (BEND_OFFSET * k)
		if _line_clear(a, point) and not _overlaps_point(point):
			return {"point": point, "body": hit.get("collider")}
	return {}


## True when a ray from `from` to just short of `to` meets no world geometry.
func _line_clear(from: Vector3, to: Vector3) -> bool:
	var d := to - from
	var length := d.length()
	if length <= LINE_RAY_MARGIN:
		return true
	return _query_ray(from, from + d * ((length - LINE_RAY_MARGIN) / length)).is_empty()


## A ray query that is not drawn in the F4 view.
func _query_ray(from: Vector3, to: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD))


func _overlaps_point(point: Vector3) -> bool:
	var params := PhysicsPointQueryParameters3D.new()
	params.position = point
	params.collision_mask = Layers.WORLD
	return not get_world_3d().direct_space_state.intersect_point(params, 1).is_empty()


## Debug fallback, kept apart from anything the player reads as silk: the line solver met a state it cannot
## resolve. The line is dropped and the spider put back at its last supported position, with a label.
func _tether_fallback(reason: String) -> void:
	tether_fallbacks += 1
	push_warning("SpiderMotor: line solver fallback (debug): %s" % reason)
	_drop_line("fallback", reason)
	teleport_to(_safe_transform)


func _trace_payout() -> void:
	tether_trace.append({"tick": _tick, "state": get_state_name(), "mode": tether.mode_name(), "p": global_position,
		"paid": tether.paid_length, "rest": tether.rest_length, "max": tether.max_length, "path": tether.path_length(global_position),
		"has_bend": tether.has_bend, "snagged": tether.snagged, "overlap": _overlaps_world(global_position, _radius - 0.005)})


## One record per tick on a locked line (tests set trace_tether). c is the constraint's result ({} if it
## did not run). e0: energy at the start of the tick; e1: after the reel pull (velocity unchanged, so
## e1 - e0 is the reel's work); e: at the end.
func _trace_end_tick(p0: Vector3, v0: Vector3, e0: float, e1: float, shortening: float, reel_work: float, len0: float, c: Dictionary, clamped: bool = false) -> void:
	if not trace_tether:
		return
	var active := tether.is_active()
	var path := tether.path_length(global_position) if active else 0.0
	var clear := true
	if active:
		var a := tether.anchor_point + tether.anchor_normal * LINE_LIFT
		clear = _line_clear(a, tether.pivot()) and _line_clear(tether.pivot(), global_position) if tether.has_bend else _line_clear(a, global_position)
	tether_trace.append({"tick": _tick, "state": get_state_name(), "mode": tether.mode_name() if active else "completed",
		"p0": p0, "p": global_position, "v0": v0, "v": velocity, "e0": e0, "e1": e1, "e": Tether.energy(global_position, velocity, _gravity),
		"shortening": shortening, "reel_work": reel_work, "reel_bound": Tether.reel_work_bound(shortening, _gravity, v0.length(), len0),
		"rest": tether.rest_length if active else 0.0, "paid": tether.paid_length if active else 0.0, "max": tether.max_length if active else 0.0,
		"path": path, "taut": tether.taut, "acted": bool(c.get("acted", false)), "radial_before": float(c.get("radial_before", 0.0)),
		"radial_after": float(c.get("radial_after", 0.0)), "tangential_change": float(c.get("tangential_change", 0.0)),
		"distance_after": float(c.get("distance_after", 0.0)), "length": float(c.get("distance_after", 0.0)) if bool(c.get("acted", false)) else -1.0,
		"overlap": _overlaps_world(global_position, _radius - 0.005), "line_clear": clear, "snagged": tether.snagged if active else false,
		"has_bend": tether.has_bend if active else false, "clamped": clamped, "block": tether.block_reason if active else "",
		"hold_work": _hold_work if _line_grabbed else 0.0, "contact_lift": _contact_lift, "resting": _asleep})


func _overlaps_world(center: Vector3, radius: float) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = Layers.WORLD
	return not get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func _eligible(hit: Dictionary, n: Vector3) -> bool:
	return SurfaceProfile.supports(surfaces.get(_profile_id(hit.get("collider"))), n)


func _surface_id(collider: Object) -> String:
	if collider == null:
		return ""
	if collider.has_meta("surface_id"):
		return str(collider.get_meta("surface_id"))
	return str(collider.get("name"))


func _profile_id(collider: Object) -> String:
	if collider == null or not collider.has_meta("surface_profile_id"):
		return ""
	return str(collider.get_meta("surface_profile_id"))


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	debug_rays.append({"from": from, "to": to, "hit": hit.get("position")})
	return hit


func _overlaps(center: Vector3) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _probe_shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = Layers.WORLD
	return not get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var old := state
	state = new_state
	state_changed.emit(old, new_state)
