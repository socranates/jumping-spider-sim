extends RefCounted
## PreyMath: the fly's numbers as pure functions (spec 8.2, 19.3: pass inputs explicitly, helpers do not reach into the scene).
## Four families, none of which touches the world:
##   * the swept contact test the capture uses (two things that each move in a straight line during one tick);
##   * what the fly makes of what it saw: the angular motion of the thing in its eyes, how that is weighed by distance, by where
##     in its field of view the thing is and by how alert it already is, and how that builds and drains its awareness;
##   * the small utility selector (rest, move, flee) over inputs normalised to [0, 1] with explicit weights, hysteresis;
##   * paths and speeds: the length of a polyline of waypoints, where a distance along it is, and how fast to fly there.

const EPS := 1.0e-6


# ------------------------------------------------------------------ the swept contact

## The closest two points come during one tick, a moving from a0 to a1 and b from b0 to b1 at constant velocity each. {"t": the
## moment in [0, 1] of the closest approach (the earliest if it is a tie), "distance": how close}. The relative position is
## linear in t, so this is exact: nothing is lost between ticks, however fast either thing goes.
static func sweep_closest(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> Dictionary:
	var d0 := a0 - b0
	var dv := (a1 - b1) - d0
	var l2 := dv.length_squared()
	var t := 0.0
	if l2 > EPS * EPS:
		t = clampf(-d0.dot(dv) / l2, 0.0, 1.0)
	return {"t": t, "distance": (d0 + dv * t).length()}


static func sweep_min_distance(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> float:
	return float(sweep_closest(a0, a1, b0, b1)["distance"])


# ------------------------------------------------------------------ what the fly makes of what it saw

## How large a sphere of `radius` looks from `distance`, the full angle across it, radians.
static func apparent_angle(radius: float, distance: float) -> float:
	return 2.0 * atan(maxf(radius, 0.0) / maxf(distance, EPS))


## How fast the thing's bearing turned between two sightings, degrees a second (0 for a gap of no time).
static func bearing_rate_deg_s(prev_dir: Vector3, dir: Vector3, dt: float) -> float:
	if dt <= EPS or prev_dir.length_squared() < EPS or dir.length_squared() < EPS:
		return 0.0
	return rad_to_deg(prev_dir.normalized().angle_to(dir.normalized())) / dt


## How fast the thing is swelling in its eyes (looming), as degrees a second: its relative rate of growth in apparent size,
## per second, times `scale`. Nothing for a thing that is shrinking.
static func loom_rate_deg_s(prev_angle: float, angle: float, dt: float, scale: float) -> float:
	if dt <= EPS or angle <= EPS:
		return 0.0
	return scale * maxf(0.0, ((angle - prev_angle) / dt) / angle)


## 1 within `full` of the fly, falling in a straight line to 0 at `zero` and beyond.
static func distance_weight(distance: float, full: float, zero: float) -> float:
	if zero <= full:
		return 1.0 if distance <= full else 0.0
	return clampf((zero - distance) / (zero - full), 0.0, 1.0)


## 1 for a thing within `front_half` degrees of where the fly faces, `rear_gain` for one more than `rear_half` degrees off it,
## a smooth blend between.
static func facing_weight(angle_deg: float, front_half: float, rear_half: float, rear_gain: float) -> float:
	if angle_deg <= front_half:
		return 1.0
	if angle_deg >= rear_half or rear_half <= front_half:
		return rear_gain
	return lerpf(1.0, rear_gain, smoothstep(front_half, rear_half, angle_deg))


## Awareness gained each second by motion in the eyes: nothing at or below the threshold, then in proportion to how far above, scaled by
## the weights of distance, of where in the field of view it is, of how much of the thing could be seen and of how alert the fly is.
static func awareness_gain_per_s(motion: float, threshold: float, scale: float, w_distance: float, w_facing: float, visible_fraction: float, vigilance: float) -> float:
	if motion <= threshold or scale <= EPS:
		return 0.0
	return (motion - threshold) / scale * w_distance * w_facing * clampf(visible_fraction, 0.0, 1.0) * maxf(vigilance, 0.0)


## Awareness after `dt` seconds. It rises while there is something to gain from and falls, at `decay` a second, when there is not. It
## stays in [0, a_max]. `dt` is the time since the previous sighting, so a gap in looking is neither free evidence nor free forgetting.
static func integrate_awareness(a: float, gain: float, dt: float, decay: float, a_max: float) -> float:
	if dt <= 0.0:
		return clampf(a, 0.0, a_max)
	if gain > 0.0:
		return clampf(a + gain * dt, 0.0, a_max)
	return clampf(a - decay * dt, 0.0, a_max)


## Credible immediate danger: so much motion, so near, that the fly does not wait to be sure.
static func is_startle(motion: float, distance: float, startle_motion: float, startle_range: float) -> bool:
	return motion >= startle_motion and distance <= startle_range


## A number from the seeded stream within [pair.x, pair.y].
static func draw(rng: RandomNumberGenerator, pair: Vector2) -> float:
	return pair.x + (pair.y - pair.x) * rng.randf()


# ------------------------------------------------------------------ the small utility selector

## The perceived threat as a number in [0, 1]: nothing at or below the calm awareness, everything at the flee awareness.
static func threat_input(awareness: float, calm: float, flee: float) -> float:
	if flee <= calm:
		return 1.0 if awareness >= flee else 0.0
	return clampf((awareness - calm) / (flee - calm), 0.0, 1.0)


## Staying where it is: a base wish to rest, more with fatigue, a sheltered perch and a perch with food on it, less with threat.
static func score_rest(w: Dictionary, fatigue: float, shelter: float, food: float, threat: float) -> float:
	return float(w["rest_base"]) + float(w["rest_fatigue"]) * fatigue + float(w["rest_shelter"]) * shelter + float(w["rest_food"]) * food - float(w["rest_threat"]) * threat


## Moving to another perch: restlessness (time at one place), more food or shelter there than here, less for the trip, for being
## tired and for any threat. `food_gain` and `shelter_gain` are the perch's advantage over the present one, in [0, 1].
static func score_move(w: Dictionary, restless: float, food_gain: float, shelter_gain: float, travel: float, fatigue: float, threat: float) -> float:
	return float(w["move_restless"]) * restless + float(w["move_food"]) * food_gain + float(w["move_shelter"]) * shelter_gain - float(w["move_travel"]) * travel - float(w["move_fatigue"]) * fatigue - float(w["move_threat"]) * threat


## Fleeing to a perch: worth exactly as much as there is threat. Its shelter, how far it gets the fly from the thing, and the cost of the trip
## only matter once there is something to flee from.
static func score_flee(w: Dictionary, threat: float, shelter: float, away: float, travel: float) -> float:
	return threat * (float(w["flee_threat"]) + float(w["flee_shelter"]) * shelter + float(w["flee_away"]) * away - float(w["flee_travel"]) * travel)


## The goal with the highest score, the present goal counting `hysteresis` more than it scores, so a close call keeps what it is doing.
## Ties go to the earlier name in `order`. `scores` maps goal -> score; goals missing from it are not considered.
static func pick_goal(scores: Dictionary, current: StringName, hysteresis: float, order: Array[StringName]) -> StringName:
	var best: StringName = current
	var best_value := -INF
	for g: StringName in order:
		if not scores.has(g):
			continue
		var v := float(scores[g]) + (hysteresis if g == current else 0.0)
		if v > best_value + 1.0e-9:
			best_value = v
			best = g
	return best


# ------------------------------------------------------------------ paths and speeds

static func path_length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## The point `s` along the polyline (clamped to its ends).
static func point_at(points: PackedVector3Array, s: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	if s <= 0.0 or points.size() == 1:
		return points[0]
	var left := s
	for i in range(1, points.size()):
		var seg := points[i - 1].distance_to(points[i])
		if left <= seg:
			return points[i - 1] if seg < EPS else points[i - 1].lerp(points[i], left / seg)
		left -= seg
	return points[points.size() - 1]


## The direction of the segment the distance `s` falls in (the last one past the end); zero for a path with no length.
static func direction_at(points: PackedVector3Array, s: float) -> Vector3:
	var left := maxf(s, 0.0)
	var last := Vector3.ZERO
	for i in range(1, points.size()):
		var seg_vec := points[i] - points[i - 1]
		var seg := seg_vec.length()
		if seg < EPS:
			continue
		last = seg_vec / seg
		if left <= seg:
			return last
		left -= seg
	return last


## The least distance from the polyline to a point.
static func distance_to_path(points: PackedVector3Array, p: Vector3) -> float:
	if points.is_empty():
		return INF
	if points.size() == 1:
		return points[0].distance_to(p)
	var best := INF
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var ab := b - a
		var l2 := ab.length_squared()
		var t := 0.0 if l2 < EPS * EPS else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		best = minf(best, (a + ab * t).distance_to(p))
	return best


## How fast to be going when `remaining` WU of path are left: `top` until the last `slow_zone`, then easing down to `landing` speed.
static func target_speed(remaining: float, top: float, landing: float, slow_zone: float) -> float:
	if slow_zone <= EPS or remaining >= slow_zone:
		return top
	return lerpf(landing, top, clampf(remaining / slow_zone, 0.0, 1.0))


## One tick of speed: it climbs toward the target at `accel`, and drops to a lower target at once (a fly can stop faster than it starts).
static func step_speed(speed: float, target: float, accel: float, dt: float) -> float:
	if speed >= target:
		return target
	return minf(speed + accel * dt, target)


# ------------------------------------------------------------------ what a camera can see

## Whether a world point is inside a camera's view widened by `margin_deg` on every side: the point in the camera's own frame must lie
## in front of it, within the half angles (vertical `fov_v_deg` / 2, horizontal from the aspect ratio) plus the margin. Occlusion is not
## considered: a point behind a wall inside the view still counts as in view (the safe side for "never in view").
static func in_view(cam: Transform3D, fov_v_deg: float, aspect: float, point: Vector3, margin_deg: float) -> bool:
	var local := cam.affine_inverse() * point
	if local.z >= -EPS:
		return false   # behind the camera (the camera looks along its -Z)
	var half_v := deg_to_rad(fov_v_deg) * 0.5
	var half_h := atan(tan(half_v) * maxf(aspect, 0.1))
	var margin := deg_to_rad(margin_deg)
	var ax := atan2(absf(local.x), -local.z)
	var ay := atan2(absf(local.y), -local.z)
	return ax <= half_h + margin and ay <= half_v + margin
