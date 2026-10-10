extends RefCounted
## Pure jump math (spec 6.3, 27). No scene access, so it can be unit tested.
##
## The motor flies a committed jump with semi-implicit Euler at the physics tick: every tick
##   v = v + g * dt, then p = p + v * dt.
## After n ticks from the launch velocity v0 at p0 that gives, exactly,
##   p_n = p0 + n * dt * v0 + g * dt^2 * n * (n + 1) / 2
## so the launch velocity that puts the body centre on the landing seat at tick n is solved in this
## discrete form, not with the continuous 0.5 * g * T^2 formula (their gravity terms differ by a
## factor of (n + 1) / n, 3 to 5 percent at n = 21 to 36). The flight time is T = n * dt, and the
## allowed durations are the whole tick counts inside the species profile's range.

const SurfaceProfile = preload("res://scripts/core/surface_profile.gd")

## A launch must carry the body away from the surface it leaves by at least this much (WU/s).
const MIN_LAUNCH_NORMAL_SPEED := 0.05
## Speed (WU/s) into a surface that a body needs to land on it. A surface within STAND_MAX_DEG of
## level takes anything that arrives; any other (a wall, an underside) needs LAND_APPROACH_MIN or
## more. The motor uses the same numbers for a falling spider.
const STAND_APPROACH_MIN := 0.05
const LAND_APPROACH_MIN := 0.3


## Tick counts n whose duration n * dt lies inside [t_min, t_max], as Vector2i(n_min, n_max).
## n_max is below n_min when no whole tick count fits.
static func step_range(t_min: float, t_max: float, dt: float) -> Vector2i:
	if not (is_finite(t_min) and is_finite(t_max) and is_finite(dt)) or dt <= 0.0:
		return Vector2i(1, 0)
	var n_min := int(ceil(t_min / dt - 1e-6))
	var n_max := int(floor(t_max / dt + 1e-6))
	return Vector2i(maxi(n_min, 1), n_max)


## Body-centre position after n ticks (closed form of the tick loop).
static func position_after(p0: Vector3, v0: Vector3, g: Vector3, dt: float, n: int) -> Vector3:
	return p0 + v0 * (float(n) * dt) + g * (dt * dt * float(n) * float(n + 1) * 0.5)


## Velocity after n ticks.
static func velocity_after(v0: Vector3, g: Vector3, dt: float, n: int) -> Vector3:
	return v0 + g * (dt * float(n))


## The launch velocity that puts the body centre on `seat` after n ticks.
static func launch_velocity(p0: Vector3, seat: Vector3, g: Vector3, dt: float, n: int) -> Vector3:
	return (seat - p0 - g * (dt * dt * float(n) * float(n + 1) * 0.5)) / (float(n) * dt)


## Body-centre positions p_0 .. p_steps by repeated ticks, in the order the motor does them.
static func path(p0: Vector3, v0: Vector3, g: Vector3, dt: float, steps: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(steps + 1)
	out[0] = p0
	var v := v0
	var p := p0
	for k in range(1, steps + 1):
		v += g * dt
		p += v * dt
		out[k] = p
	return out


## True when a surface with this normal is within STAND_MAX_DEG of level.
static func is_standing(normal: Vector3) -> bool:
	if not normal.is_finite() or normal.length_squared() < 1e-10:
		return false
	return normal.normalized().dot(Vector3.UP) >= cos(deg_to_rad(SurfaceProfile.STAND_MAX_DEG)) - 1e-6


## Least speed into a surface with this normal that counts as arriving on it.
static func min_approach(target_normal: Vector3) -> float:
	return STAND_APPROACH_MIN if is_standing(target_normal) else LAND_APPROACH_MIN


## Every launch solution for a landing seat, one per allowed whole-tick duration, filtered by the
## launch speed limit, by leaving the launch surface (v0 . launch_normal) and by arriving at the
## target surface fast enough (see min_approach). Returns
##   {"valid": Array[Dictionary] sorted by launch speed, lowest first,
##    "reason": "ok" or why none is left: "no_durations", "too_far" (every duration needs more than
##      max_speed), "no_launch" (none leaves the surface) or "no_arrival" (none arrives into the target),
##    "min_speed": the least speed any allowed duration needs, ignoring the other limits (INF if none)}.
## Each valid entry is {"steps", "duration", "velocity", "speed", "arrival_velocity", "approach"}.
static func solve(p0: Vector3, seat: Vector3, launch_normal: Vector3, target_normal: Vector3, g: Vector3, dt: float, t_min: float, t_max: float, max_speed: float) -> Dictionary:
	var valid: Array[Dictionary] = []
	var counts := step_range(t_min, t_max, dt)
	var min_speed := INF
	var any_speed_ok := false
	var any_launch_ok := false
	var need := min_approach(target_normal)
	for n in range(counts.x, counts.y + 1):
		var v0 := launch_velocity(p0, seat, g, dt, n)
		if not v0.is_finite():
			continue
		var speed := v0.length()
		min_speed = minf(min_speed, speed)
		if speed > max_speed:
			continue
		any_speed_ok = true
		if v0.dot(launch_normal) < MIN_LAUNCH_NORMAL_SPEED:
			continue
		any_launch_ok = true
		var arrival := velocity_after(v0, g, dt, n)
		var approach := -arrival.dot(target_normal)
		if approach < need:
			continue
		valid.append({"steps": n, "duration": float(n) * dt, "velocity": v0, "speed": speed, "arrival_velocity": arrival, "approach": approach})
	valid.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["speed"]) - float(b["speed"])) > 1e-9:
			return float(a["speed"]) < float(b["speed"])
		return int(a["steps"]) < int(b["steps"]))
	var reason := "ok"
	if valid.is_empty():
		if counts.y < counts.x:
			reason = "no_durations"
		elif not any_speed_ok:
			reason = "too_far"
		elif not any_launch_ok:
			reason = "no_launch"
		else:
			reason = "no_arrival"
	return {"valid": valid, "reason": reason, "min_speed": min_speed}
