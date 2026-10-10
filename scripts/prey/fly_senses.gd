extends RefCounted
## FlySenses: what a fly makes of the one thing it can be afraid of (A-028). Everything here is the fly's own evidence:
##   * the thing's visible angular motion from the fly's viewpoint, the change in its bearing and the swelling of its apparent size
##     between two sightings the fly itself made (never the thing's velocity, never what it is doing);
##   * how far it is, where in the fly's field of view it lies, and how much of it a ray from the fly's eye can reach;
##   * the fly's own state of alertness, which scales how much it takes in.
## It never reads a button, the Focus or aim state, a landing target or a plan, and it asks the world nothing but rays. A thing
## behind cover gives no evidence at all, however it moves: the fly keeps no position of it, only the place where it last saw it,
## and its awareness drains. A thing that comes out from cover counts as a sudden appearance if it is near.
## The fly's awareness is a number in [0, awareness_max]: it builds while there is motion above the threshold to take in and drains
## otherwise. The thresholds that turn it into behaviour belong to the fly's mind (FlyMind); this class only keeps the number.
## Rate: nothing is looked at beyond the sight range; within the near-check range of where it was last seen the fly looks every tick,
## otherwise at far_check_hz. The scheduling reads only the fly's own last sighting, never the thing's real distance.

const PreyMath = preload("res://scripts/prey/prey_math.gd")
const PerceptionMath = preload("res://scripts/perception/perception_math.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")
const RecordMath = preload("res://scripts/persistence/record_math.gd")

const SAMPLES := 3
const SAMPLE_SPREAD := 0.8
const MIN_DISTANCE := 0.05
const MAX_STEP_S := 0.25
const EPS := 1.0e-9

var profile: RefCounted
var awareness: float = 0.0
## The last evidence (a Dictionary, see update), for the mind and for the trace.
var evidence: Dictionary = {}
## Where the fly last saw the thing (its own memory), and when.
var has_last_seen: bool = false
var last_seen_position: Vector3 = Vector3.ZERO
var last_seen_time: float = -1.0e9
## Cost counters.
var checks_total: int = 0
var rays_total: int = 0
var checks_skipped: int = 0

var _started: bool = false
var _has_last: bool = false
var _last_point: Vector3 = Vector3.ZERO
var _last_time: float = -1.0e9
var _last_mask: int = 0
var _last_check_time: float = -1.0e9
var _next_check_time: float = 0.0
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


func _init(p: RefCounted = null) -> void:
	profile = p
	_ray.collision_mask = Layers.WORLD


func reset() -> void:
	awareness = 0.0
	evidence = {}
	has_last_seen = false
	_started = false
	_has_last = false
	_last_check_time = -1.0e9
	_next_check_time = 0.0


## True when a look is due at `now`.
func should_check(now: float) -> bool:
	return now + EPS >= _next_check_time


## One look. `eye` is the fly's eye, `facing` the way it faces and `up` its body's up; `stim_pos` and `stim_radius` are the thing's centre and
## body radius as the world offers it to anything that might see it (the line-of-sight rays decide how much of it counts). `vigilance` scales
## what is taken in; `decay` is the awareness drained each second when there is nothing to take in. Returns the evidence:
##   seen, reason (when not seen), distance, off_deg, w_dist, w_face, visible_fraction, bearing_deg_s, loom_deg_s, motion_deg_s, appeared,
##   gain_per_s, startle, awareness (after), dt, t
func update(space: PhysicsDirectSpaceState3D, eye: Vector3, facing: Vector3, up: Vector3, stim_pos: Vector3, stim_radius: float, now: float, vigilance: float, decay: float) -> Dictionary:
	var p: RefCounted = profile
	var dt := clampf(now - _last_check_time, 0.0, MAX_STEP_S) if _started else 0.0
	_last_check_time = now
	checks_total += 1
	var to := stim_pos - eye
	var dist := to.length()
	var ev := {"t": now, "dt": dt, "seen": false, "distance": dist, "reason": "", "startle": false, "appeared": false,
		"bearing_deg_s": 0.0, "loom_deg_s": 0.0, "motion_deg_s": 0.0, "gain_per_s": 0.0, "visible_fraction": 0.0, "off_deg": 0.0, "w_dist": 0.0, "w_face": 0.0}
	if dist > p.sight_range_wu or dist < MIN_DISTANCE:
		ev["reason"] = "out of range" if dist > p.sight_range_wu else "too close to see"
		return _finish(ev, now, dt, 0.0, decay, false)
	var dir := to / dist
	var off_deg := rad_to_deg(facing.angle_to(dir)) if facing.length_squared() > 1.0e-9 else 0.0
	var w_face: float = PreyMath.facing_weight(off_deg, p.front_half_deg, p.rear_half_deg, p.rear_gain)
	var w_dist: float = PreyMath.distance_weight(dist, p.full_sensitivity_wu, p.sight_range_wu)
	ev["off_deg"] = off_deg
	ev["w_face"] = w_face
	ev["w_dist"] = w_dist
	var side := dir.cross(up)
	if side.length_squared() < 1.0e-6:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var r := stim_radius * SAMPLE_SPREAD
	var points: Array[Vector3] = [stim_pos, stim_pos + side * r, stim_pos - side * r]
	var seen_points: Array[Vector3] = []
	var mask := 0
	for i in points.size():
		if _clear(space, eye, points[i], stim_radius):
			seen_points.append(points[i])
			mask |= 1 << i
	if seen_points.is_empty():
		ev["reason"] = "no line of sight"
		return _finish(ev, now, dt, 0.0, decay, false)
	var vf := float(seen_points.size()) / float(SAMPLES)
	var centre := Vector3.ZERO
	for s: Vector3 in seen_points:
		centre += s
	centre /= float(seen_points.size())
	var offset := centre - eye
	var vdist := offset.length()
	var vdir := offset / maxf(vdist, MIN_DISTANCE)
	var vangle: float = PreyMath.apparent_angle(stim_radius, vdist)
	ev["visible_fraction"] = vf
	ev["distance"] = vdist
	var bearing := 0.0
	var loom := 0.0
	var appeared := false
	if not _started:
		pass  # the first look only learns where the thing is: nothing has changed that the fly saw
	elif _has_last and now - _last_time <= p.sample_gap_max_s + EPS:
		if mask == _last_mask:
			# Both sightings are judged from where the eye is now, so only the thing's own movement counts: a fly that flies past a
			# still thing does not see it move (the fly's own motion is subtracted, as an insect's eye does with optic flow).
			var gap := maxf(now - _last_time, EPS)
			var then := _last_point - eye
			bearing = PreyMath.bearing_rate_deg_s(then, offset, gap)
			loom = PreyMath.loom_rate_deg_s(PreyMath.apparent_angle(stim_radius, then.length()), vangle, gap, p.loom_scale_deg_s)
		# a different set of visible points moves the apparent centre by a body's width: that is not motion
	else:
		appeared = vdist <= p.appear_range_wu
		if appeared:
			bearing = p.appear_motion_deg_s
	var motion := maxf(bearing, loom)
	var gain: float = PreyMath.awareness_gain_per_s(motion, p.motion_threshold_deg_s, p.motion_scale_deg_s, w_dist, w_face, vf, vigilance)
	ev["bearing_deg_s"] = bearing
	ev["loom_deg_s"] = loom
	ev["motion_deg_s"] = motion
	ev["appeared"] = appeared
	ev["gain_per_s"] = gain
	ev["startle"] = PreyMath.is_startle(motion * w_face * vf, vdist, p.startle_motion_deg_s, p.startle_range_wu)
	ev["seen"] = true
	_has_last = true
	_last_point = centre
	_last_time = now
	_last_mask = mask
	has_last_seen = true
	last_seen_position = centre
	last_seen_time = now
	return _finish(ev, now, dt, gain, decay, true)


## The fly looked and took in what there was (or found nothing): the awareness builds or drains, three times faster when it cannot see the
## thing at all (it is no longer in front of it). No sighting carries over a loss of sight.
func _finish(ev: Dictionary, now: float, dt: float, gain: float, decay: float, seen: bool) -> Dictionary:
	if not seen:
		_has_last = false
	_started = true
	var drain: float = decay if seen else decay * float(profile.unseen_decay_mult)
	awareness = PreyMath.integrate_awareness(awareness, gain, dt, drain, profile.awareness_max)
	ev["awareness"] = awareness
	ev["seen"] = seen
	evidence = ev
	var near: bool = seen and float(ev["distance"]) <= profile.near_check_range_wu
	_next_check_time = now if near else now + 1.0 / maxf(profile.far_check_hz, 0.1)
	return ev


## Drains the awareness while no look was made (the fly has nothing to look at, or is not looking).
func idle(dt: float, decay: float) -> void:
	awareness = PreyMath.integrate_awareness(awareness, 0.0, dt, decay * float(profile.unseen_decay_mult), profile.awareness_max)


## True when the world stops a ray from the eye short of the sample point (the same allowance the spider's sensor gives, A-024).
func _clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, radius: float) -> bool:
	rays_total += 1
	_ray.from = from
	_ray.to = to
	var hit := space.intersect_ray(_ray)
	if hit.is_empty():
		return true
	var length := from.distance_to(to)
	return from.distance_to(hit["position"] as Vector3) >= length - PerceptionMath.sight_tolerance(radius, length)


## A line for the trace: what the fly took in.
static func describe(ev: Dictionary) -> String:
	if ev.is_empty():
		return "nothing looked at yet"
	if not bool(ev.get("seen", false)):
		return "sees nothing (%s), awareness %.2f" % [str(ev.get("reason", "")), float(ev.get("awareness", 0.0))]
	return "sees it %.1f WU away, %.0f deg off its facing, %.0f%% of it; bearing %.0f, loom %.0f deg/s%s%s; awareness %.2f" % [
		float(ev["distance"]), float(ev["off_deg"]), float(ev["visible_fraction"]) * 100.0, float(ev["bearing_deg_s"]), float(ev["loom_deg_s"]),
		", appeared" if bool(ev["appeared"]) else "", ", startling" if bool(ev["startle"]) else "", float(ev["awareness"])]


## T09: the fly's own memory and look schedule as a plain record. The evidence keeps only its plain values (it is read for the trace and
## for whether a sighting is from this very tick); cost counters start again.
func to_record() -> Dictionary:
	return {"awareness": awareness, "evidence": RecordMath.plain(evidence), "has_last_seen": has_last_seen,
		"last_seen_position": RecordMath.v3(last_seen_position), "last_seen_time": last_seen_time, "started": _started, "has_last": _has_last,
		"last_point": RecordMath.v3(_last_point), "last_time": _last_time, "last_mask": _last_mask, "last_check_time": _last_check_time,
		"next_check_time": _next_check_time}


func apply_record(r: Dictionary) -> void:
	awareness = float(r["awareness"])
	evidence = (r["evidence"] as Dictionary).duplicate()
	has_last_seen = bool(r["has_last_seen"])
	last_seen_position = RecordMath.to_v3(r["last_seen_position"])
	last_seen_time = float(r["last_seen_time"])
	_started = bool(r["started"])
	_has_last = bool(r["has_last"])
	_last_point = RecordMath.to_v3(r["last_point"])
	_last_time = float(r["last_time"])
	_last_mask = int(r["last_mask"])
	_last_check_time = float(r["last_check_time"])
	_next_check_time = float(r["next_check_time"])
