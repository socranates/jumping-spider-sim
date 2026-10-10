extends RefCounted
## Pure helpers for the perception layer (spec 7). Nothing here touches the scene: angles, apparent size, the
## exposure a classification needs, the evidence's confidence, the coarse direction a peripheral cue is given, how a
## remembered contact fades.

const Observation = preload("res://scripts/perception/observation.gd")

const EPS := 1e-6
## A peripheral cue is given a direction in sectors of the observer's own bearing, and in coarse bands of elevation.
const PITCH_BAND_DEG := 30.0
## Visibility of a sample point (A-024). A ray the world stops short of its sample point has not seen it: the world is in front of it.
## The only allowance is for a sample that lies in the skin of the surface the thing rests on or against (a thing touching a wall has
## sample points in the wall's face) and for the float error of a long cast: SIGHT_SHARE of the thing's own radius plus
## SIGHT_FLOAT_PER_WU for each WU of ray, and never more than SIGHT_CEILING. Chunk 6B allowed a flat 0.05 WU to every thing of every
## size, which let a barrier 0.03 WU in front of a speck 0.02 WU across hide all of it and still count as seen.
const SIGHT_SHARE := 0.1
const SIGHT_FLOAT_PER_WU := 1.0e-5
const SIGHT_CEILING := 0.05


## How far short of its sample point a ray may be stopped by the world and still count as having seen it (A-024). The sample points
## sit up to 0.8 of the radius off the centre, so for a thing of radius r the allowance is a tenth of r: a speck's whole body is
## never inside it, and a large thing resting on a wall still has the points that lie in the wall's face counted.
static func sight_tolerance(radius: float, ray_length: float) -> float:
	return minf(SIGHT_CEILING, SIGHT_SHARE * maxf(radius, 0.0) + SIGHT_FLOAT_PER_WU * maxf(ray_length, 0.0))


## The furthest a lost contact's thing can be from where it was last observed when something is seen `elapsed_s` later (A-027).
## Three parts, each an observation or an explicit assumption and none of them the truth about where the thing went: the sizes of
## the two sightings (a position is only good to about the size of what it was taken from), and the distance the thing could have
## covered in the time at the conservative speed bound, or at the speed it was last seen moving at if that was greater.
static func plausible_radius(old_size_wu: float, new_size_wu: float, elapsed_s: float, speed_bound: float, observed_speed: float) -> float:
	return 0.5 * (maxf(old_size_wu, 0.0) + maxf(new_size_wu, 0.0)) + maxf(speed_bound, observed_speed) * maxf(elapsed_s, 0.0)


## Whether two size estimates can belong to one thing: neither is more than `ratio` times the other. A size that is not known
## (zero) is compatible with anything.
static func sizes_compatible(a: float, b: float, ratio: float) -> bool:
	if a <= EPS or b <= EPS:
		return true
	return maxf(a, b) <= minf(a, b) * maxf(ratio, 1.0) + EPS


## Whether a lost contact refined to `old_category` can be a thing whose appearance can be refined no further than `cap`: what
## was learned about the one cannot be finer than the other can ever look.
static func categories_compatible(old_category: StringName, cap: StringName) -> bool:
	return Observation.rank(old_category) <= Observation.rank(cap)


## Angle between two directions, radians; 0 when either has no length.
static func angle_between(a: Vector3, b: Vector3) -> float:
	if a.length_squared() < EPS * EPS or b.length_squared() < EPS * EPS:
		return 0.0
	return a.normalized().angle_to(b.normalized())


## True when `to` lies within `half_angle` (radians) of `axis`.
static func in_cone(axis: Vector3, to: Vector3, half_angle: float) -> bool:
	return to.length_squared() > EPS * EPS and angle_between(axis, to) <= half_angle + 1e-9


## How large a thing of `size_wu` across looks from `distance`, degrees of angle.
static func apparent_size_deg(size_wu: float, distance: float) -> float:
	if distance <= EPS:
		return 180.0
	return rad_to_deg(2.0 * atan(size_wu * 0.5 / distance))


## Continuous exposure a refinement needs: `base_s` for an easy target (one that looks at least `easy_deg` across), and
## proportionally longer the smaller it looks. Infinite for something with no apparent size.
static func required_exposure(base_s: float, apparent_deg: float, easy_deg: float) -> float:
	if apparent_deg <= EPS:
		return INF
	return base_s * maxf(1.0, easy_deg / apparent_deg)


## The category continuous exposure supports. Nothing smaller than `min_deg` is refined at all.
static func classify(exposure_s: float, apparent_deg: float, easy_s: float, fly_s: float, easy_deg: float, min_deg: float) -> StringName:
	if apparent_deg < min_deg:
		return Observation.MOVEMENT
	if exposure_s + EPS >= required_exposure(fly_s, apparent_deg, easy_deg):
		return Observation.FLY_LIKE_PREY
	if exposure_s + EPS >= required_exposure(easy_s, apparent_deg, easy_deg):
		return Observation.POSSIBLE_PREY
	return Observation.MOVEMENT


## Confidence of an inspection: it rises with exposure (to the fly-like refinement) and falls with how much of the
## thing is hidden. From 0.4 x 0.68 = 0.27 (one of five sample points seen, no exposure yet) to 1.
static func inspection_confidence(exposure_s: float, fly_needed_s: float, visible_fraction: float) -> float:
	var progress := clampf(exposure_s / maxf(fly_needed_s, EPS), 0.0, 1.0) if is_finite(fly_needed_s) else 0.0
	return clampf((0.4 + 0.6 * progress) * (0.6 + 0.4 * clampf(visible_fraction, 0.0, 1.0)), 0.0, 1.0)


## Confidence of a peripheral cue: low, and a little higher the nearer it is. In [0.1, 0.3].
static func peripheral_confidence(distance: float, range_wu: float) -> float:
	return clampf(0.1 + 0.2 * (1.0 - distance / maxf(range_wu, EPS)), 0.1, 0.3)


## The direction of a peripheral cue, coarse: its bearing about `up` from `forward` rounded to a sector, its elevation to
## a band of PITCH_BAND_DEG. Returns a unit vector. This is all a peripheral observation says about where.
static func quantize_direction(dir: Vector3, forward: Vector3, up: Vector3, sector_deg: float) -> Vector3:
	var d := dir.normalized()
	var u := up.normalized()
	var f := forward - u * forward.dot(u)
	if f.length_squared() < EPS:
		f = d - u * d.dot(u)
	if f.length_squared() < EPS:
		return d  # straight up or down: there is no bearing to round
	f = f.normalized()
	var right := f.cross(u).normalized()
	var yaw := atan2(d.dot(right), d.dot(f))
	var pitch := asin(clampf(d.dot(u), -1.0, 1.0))
	var sector := deg_to_rad(maxf(sector_deg, 0.5))
	var band := deg_to_rad(PITCH_BAND_DEG)
	var yq := roundf(yaw / sector) * sector
	var pq := roundf(pitch / band) * band
	return (f * cos(pq) * cos(yq) + right * cos(pq) * sin(yq) + u * sin(pq)).normalized()


## Confidence of a contact that is no longer sensed: it falls straight to nothing over `decay_s`, from the confidence it
## had when it was lost.
static func decayed_confidence(confidence_at_loss: float, age_s: float, decay_s: float) -> float:
	if decay_s <= EPS:
		return 0.0
	return clampf(confidence_at_loss * (1.0 - age_s / decay_s), 0.0, 1.0)


## 0 when a contact has only just been lost, 1 when its memory is gone.
static func staleness(age_s: float, decay_s: float) -> float:
	if decay_s <= EPS:
		return 1.0
	return clampf(age_s / decay_s, 0.0, 1.0)
