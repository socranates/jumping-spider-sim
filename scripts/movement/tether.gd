extends RefCounted
## TetherState (spec 21.3) and the pure math of the P0 safety line (spec 9.1). No scene access, so the
## constraint can be unit tested; SpiderMotor owns the line in the world (anchoring, sweeps, bends).
##
## One line at a time, from an anchor on a surface to the body centre (the drawn line ends at the
## spinnerets), optionally over ONE bend point on an obstructing edge. No general rope wrapping.
##   PAYOUT  a normal leap: the line pays out freely with the body (paid_length follows it), so it never
##           truncates the predicted arc; rest_length is the maximum.
##   LOCKED  after a miss: the paid-out length is frozen (plus a short braking extension). The line is ONE
##           unilateral constraint: path length (anchor, bend, body) <= rest_length. It limits extension
##           and never pushes. Reeling shortens rest_length at a capped rate, lowering lengthens it up to
##           max_length.
## Lengths are nonnegative and bounded: 0 <= paid_length <= rest_length <= max_length (is_consistent()).
## Units: WU, seconds; ticks are physics ticks.

enum Mode { NONE, PAYOUT, LOCKED }
const MODE_NAMES: Array[String] = ["none", "payout", "locked"]

## A line within this of its rest length counts as taut.
const TAUT_EPS := 0.003

var mode: Mode = Mode.NONE
## The anchor: persistent surface id and the attachment point (and the surface normal there) in that
## surface's local space. anchor_point / anchor_normal are the world values, refreshed every tick from the
## surface's transform (so a moved surface carries its anchor).
var anchor_surface_id: String = ""
var anchor_profile_id: String = ""
var anchor_local: Vector3 = Vector3.ZERO
var anchor_normal_local: Vector3 = Vector3.UP
var anchor_point: Vector3 = Vector3.ZERO
var anchor_normal: Vector3 = Vector3.UP
## Line out of the spinnerets, measured along the line. A slack line is longer than the path and sags.
var paid_length: float = 0.0
## The most the line may stretch to now (the constraint length).
var rest_length: float = 0.0
var max_length: float = 0.0
var taut: bool = false
## The optional bend point on an obstructing edge (world, and local to that surface).
var has_bend: bool = false
var bend_point: Vector3 = Vector3.ZERO
var bend_surface_id: String = ""
var bend_local: Vector3 = Vector3.ZERO
## +1 reel in, -1 lower, 0 neither (from the player, set each tick).
var reel_intent: float = 0.0
## Why reeling has stopped: "" (it has not), "blocked" (the body cannot get any closer to the pivot; cleared
## when the player lets go of reel, so the next reel tries again) or "shortest" (reeled in as far as it goes;
## cleared by lowering). Lowering and letting go always work.
var block_reason: String = ""
## The line would need a second bend (something lies between the bend and the body, or something moved into
## the line): no general rope wrapping, so it cannot be reeled in until it clears. Recomputed every tick.
var snagged: bool = false
var anchored_tick: int = -1
## First tick the line took the load after a miss (-1 until then).
var caught_tick: int = -1
## The spider let itself down on this line on purpose (SpiderMotor.begin_drop), rather than being caught by it after a miss.
var lowering: bool = false


func is_active() -> bool:
	return mode != Mode.NONE


func is_locked() -> bool:
	return mode == Mode.LOCKED


func mode_name() -> String:
	return MODE_NAMES[mode]


## The point the body swings about: the bend point if there is one, else the anchor.
func pivot() -> Vector3:
	return bend_point if has_bend else anchor_point


## Line between the anchor and the pivot (0 without a bend).
func anchor_to_pivot() -> float:
	return anchor_point.distance_to(bend_point) if has_bend else 0.0


## How far the body centre may be from the pivot.
func effective_length() -> float:
	return maxf(rest_length - anchor_to_pivot(), 0.0)


## Length of the line's path (anchor, bend, body centre).
func path_length(body: Vector3) -> float:
	return anchor_to_pivot() + pivot().distance_to(body)


## The line's world points: anchor, bend (if any), end.
func points(end: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array([anchor_point])
	if has_bend:
		out.append(bend_point)
	out.append(end)
	return out


func clear() -> void:
	mode = Mode.NONE
	anchor_surface_id = ""
	anchor_profile_id = ""
	paid_length = 0.0
	rest_length = 0.0
	taut = false
	has_bend = false
	bend_surface_id = ""
	reel_intent = 0.0
	block_reason = ""
	snagged = false
	caught_tick = -1
	lowering = false


## Spec 21.3: lengths nonnegative and bounded, everything finite.
func is_consistent(tolerance: float = 1e-4) -> bool:
	if not (is_finite(paid_length) and is_finite(rest_length) and is_finite(max_length)):
		return false
	if not (anchor_point.is_finite() and bend_point.is_finite()):
		return false
	if mode == Mode.NONE:
		return true
	return paid_length >= -tolerance and rest_length >= -tolerance and max_length > 0.0 \
		and paid_length <= rest_length + tolerance and rest_length <= max_length + tolerance


## The record for the debug overlay and, later, saves (spec 21.3 TetherState).
func to_dict() -> Dictionary:
	return {
		"mode": mode_name(), "anchor_surface_id": anchor_surface_id, "anchor_local": anchor_local,
		"paid_length": paid_length, "rest_length": rest_length, "max_length": max_length, "taut": taut,
		"bend": bend_point if has_bend else null, "bend_surface_id": bend_surface_id if has_bend else "",
		"reel_intent": reel_intent, "block_reason": block_reason, "snagged": snagged, "lowering": lowering,
	}


## The unilateral line constraint for one step. `target` is where the body would go this tick without the
## line, `velocity` its velocity after gravity. When target is within `length` of `pivot` the line is slack
## and nothing changes. Otherwise the body is put back on the sphere of that radius along the same radial
## line (the correction only ever pulls toward the pivot, and only the excess), and the outward radial part
## of the velocity is removed (inelastic: no bounce, so the line never pushes and never adds speed). The
## tangential velocity is kept as it is. Returns
##   {"position", "velocity", "acted" (the line took load), "radial_before", "radial_after" (velocity along
##    the outward radial direction), "tangential_change" (size of the change in tangential velocity),
##    "distance_before" (target to pivot), "distance_after"}.
static func constrain(pivot: Vector3, length: float, target: Vector3, velocity: Vector3) -> Dictionary:
	var d := target - pivot
	var dist := d.length()
	var out := {"position": target, "velocity": velocity, "acted": false, "radial_before": 0.0, "radial_after": 0.0,
		"tangential_change": 0.0, "distance_before": dist, "distance_after": dist}
	if dist < 1e-9:
		return out
	var r := d / dist
	var u := velocity.dot(r)
	out["radial_before"] = u
	out["radial_after"] = u
	if dist <= length:
		return out
	var v := velocity
	if u > 0.0:
		v = velocity - r * u
	out["position"] = pivot + r * maxf(length, 0.0)
	out["velocity"] = v
	out["acted"] = true
	out["radial_after"] = v.dot(r)
	out["tangential_change"] = ((v - r * v.dot(r)) - (velocity - r * u)).length()
	out["distance_after"] = maxf(length, 0.0)
	return out


## Mechanical energy per unit mass: kinetic plus potential (gravity along -y).
static func energy(position: Vector3, velocity: Vector3, gravity: float) -> float:
	return 0.5 * velocity.length_squared() + gravity * position.y


## The most work a reel can do shortening the line by `shortening` against a load of gravity plus the
## centripetal load of a swing (per unit mass): shortening * (g + v^2 / L). Used to check that reeling adds
## no energy beyond what it physically could.
static func reel_work_bound(shortening: float, gravity: float, speed: float, length: float) -> float:
	return maxf(shortening, 0.0) * (gravity + speed * speed / maxf(length, 0.05))


## A line's sag for drawing: the depth of a parabola of span `span` and length `line_length`.
static func sag_depth(span: float, line_length: float) -> float:
	var extra := line_length - span
	if extra <= 1e-4 or span < 1e-4:
		return 0.0
	return minf(sqrt(3.0 * span * extra / 8.0), 3.0)
