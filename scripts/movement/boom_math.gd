extends RefCounted
## Pure helpers for the camera rig (spec 6.4). No scene access, so they can be unit tested.

const SETTLE := 2e-4  # radians, about 0.01 degree: an eased offset closer than this lands on its target
const TIE := 1e-3     # WU: boom lengths closer than this count as equal


## Next boom length. `allowed` is the longest collision-free length found this tick, `desired`
## the length the player chose. A hit retracts at once; recovery is limited to
## recover_speed * dt per call and never passes `allowed` or `desired`. Non-finite input
## returns 0.0, the position closest to the pivot.
static func next_length(current: float, allowed: float, desired: float, recover_speed: float, dt: float) -> float:
	if not (is_finite(current) and is_finite(allowed) and is_finite(desired) and is_finite(recover_speed) and is_finite(dt)):
		return 0.0
	var target := maxf(0.0, minf(allowed, desired))
	if target <= current:
		return target
	return minf(current + maxf(recover_speed, 0.0) * maxf(dt, 0.0), target)


## Converts the safe fraction returned by a shape cast into a length along the boom.
static func allowed_length(safe_fraction: float, boom_distance: float) -> float:
	return clampf(safe_fraction, 0.0, 1.0) * maxf(boom_distance, 0.0)


## Camera orientation for a yaw about world up and an elevation angle (camera above the pivot
## when positive). Built from yaw and pitch only, so the horizon never rolls.
static func orbit_basis(yaw: float, elevation: float) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -elevation)


## Unit vector from the pivot to the camera.
static func back_direction(yaw: float, elevation: float) -> Vector3:
	return orbit_basis(yaw, elevation) * Vector3.BACK


## Next auto-pitch offset in radians. It moves away from zero toward `target` with time constant
## `in_seconds` (quick) and back toward zero with `out_seconds` (slower), whichever sign the offset
## has. Exponential, so it never overshoots, and it lands exactly on the target once within 0.01
## degree. Non-finite input returns 0.0.
static func ease_offset(current: float, target: float, dt: float, in_seconds: float, out_seconds: float) -> float:
	if not (is_finite(current) and is_finite(target) and is_finite(dt) and is_finite(in_seconds) and is_finite(out_seconds)):
		return 0.0
	var seconds := maxf(in_seconds if absf(target) >= absf(current) else out_seconds, 1e-4)
	var next := current + (target - current) * (1.0 - exp(-maxf(dt, 0.0) / seconds))
	return target if absf(target - next) < SETTLE else next


## Chooses a pitch offset for a squeezed boom. `offsets` are in the order they are tried and start at
## 0.0 (the player's own pitch); lengths[i] is the collision-free boom length at offsets[i]. Returns
## the first offset whose boom reaches `comfort`. If none does, returns the offset with the longest
## boom (the earlier one on a near tie), so the result is never worse than the player's own pitch.
## Empty or mismatched arrays and non-finite numbers return 0.0.
static func pick_pitch_offset(offsets: PackedFloat64Array, lengths: PackedFloat64Array, comfort: float) -> float:
	if offsets.is_empty() or offsets.size() != lengths.size() or not is_finite(comfort):
		return 0.0
	for i in offsets.size():
		if not (is_finite(offsets[i]) and is_finite(lengths[i])):
			return 0.0
	var best := 0
	for i in offsets.size():
		if lengths[i] >= comfort:
			return offsets[i]
		if lengths[i] > lengths[best] + TIE:
			best = i
	return offsets[best]


## Critically damped approach of `current` to `target`: a spring that arrives without overshoot and starts and
## ends gently (the usual "smooth damp"). `smooth_time` is about the time it takes to arrive. Returns [value,
## velocity]; pass the velocity back in on the next call. Lands exactly on the target once within SETTLE and
## nearly still. Non-finite input returns [0.0, 0.0].
static func smooth_damp(current: float, target: float, velocity: float, smooth_time: float, dt: float) -> PackedFloat64Array:
	if not (is_finite(current) and is_finite(target) and is_finite(velocity) and is_finite(smooth_time) and is_finite(dt)):
		return PackedFloat64Array([0.0, 0.0])
	var omega := 2.0 / maxf(smooth_time, 1e-4)
	var x := omega * maxf(dt, 0.0)
	var damp := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - target
	var temp := (velocity + omega * change) * dt
	var next_velocity := (velocity - omega * temp) * damp
	var next := target + (change + temp) * damp
	if (target - current > 0.0) == (next > target):
		return PackedFloat64Array([target, 0.0])
	if absf(target - next) < SETTLE and absf(next_velocity) < 1e-3:
		return PackedFloat64Array([target, 0.0])
	return PackedFloat64Array([next, next_velocity])
