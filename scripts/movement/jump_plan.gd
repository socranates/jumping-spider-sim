extends RefCounted
## The result of planning one jump to one target point (spec 6.3, 19.3 JumpPlanner): what the
## player is told about the target and, when it is reachable, the exact launch impulse and the
## predicted flight. A plan is data: the motor flies a reachable plan as it is, and no plan is
## ever changed after the jump is committed.

enum Kind {
	REACHABLE,    # a clear arc within the speed and time limits: the jump can be committed
	OBSTRUCTED,   # a launch exists, but every arc is blocked on the way or there is no room at the landing
	UNREACHABLE,  # outside the speed or time range, or the arc cannot leave or arrive properly
	INELIGIBLE,   # the surface cannot hold the spider (D-010)
	NO_TARGET,    # the aim point found no surface
}
const KIND_NAMES: Array[String] = ["reachable", "obstructed", "unreachable", "ineligible", "none"]

var kind: Kind = Kind.NO_TARGET
## Short machine-readable cause: "ok", "no_target", "ineligible_surface", "too_far", "no_launch",
## "no_arrival", "no_durations", "no_room", "path_blocked", "graze", "hop_blocked", "no_ground".
var reason: String = "no_target"
var origin: Vector3 = Vector3.ZERO          # body centre at launch
var launch_normal: Vector3 = Vector3.UP     # normal of the surface left
var target_point: Vector3 = Vector3.ZERO    # the aimed surface point
var target_normal: Vector3 = Vector3.UP
var target_surface_id: String = ""
var target_profile_id: String = ""
## The landing seat: where the body centre rests on the target surface. The plan lands here.
var seat: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO        # launch velocity (reachable plans)
var speed: float = 0.0
var steps: int = 0                          # ticks from launch to the seat
var duration: float = 0.0                   # steps * dt
var dt: float = 1.0 / 60.0
var gravity: Vector3 = Vector3(0.0, -35.0, 0.0)
var arrival_velocity: Vector3 = Vector3.ZERO
var approach_speed: float = 0.0             # speed into the target surface on arrival
## Body-centre positions p_0 .. p_steps. For an obstructed plan: the lowest-speed arc, cut at the
## blocking point.
var path: PackedVector3Array = PackedVector3Array()
var blocked_step: int = -1
var blocked_at: Vector3 = Vector3.ZERO
## Predicted body centre at first contact after the seat (reachable plans).
var contact_center: Vector3 = Vector3.ZERO
## The tick of that predicted first contact, counted from launch (reachable plans; -1 otherwise). A flight
## that has touched nothing a couple of ticks after it is a miss (spec 9.1: the safety line then locks).
var contact_step: int = -1
## Where a safety line would be anchored: the launch surface point under the body (origin - launch_normal
## * seat distance), and the most line the predicted flight pays out from there (the largest distance from
## that point to the body centre along the path, the contact included). Reachable plans only.
var anchor_point: Vector3 = Vector3.ZERO
var line_needed: float = 0.0
## The least launch speed any allowed duration needs (INF when none): for messages.
var min_speed: float = INF


func is_valid() -> bool:
	return kind == Kind.REACHABLE


func kind_name() -> String:
	return KIND_NAMES[kind]
