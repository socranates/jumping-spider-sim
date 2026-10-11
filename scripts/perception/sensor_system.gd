extends Node
## SensorSystem (spec 7, 19.3, 21.3): turns world truth into evidence, and nothing more. Each physics tick it reads the
## observer's eye and gaze (never the camera's), asks every perceivable thing for its percept, and decides what the
## observer's senses could pick up of it:
##   * a thing inside the broad peripheral field that moves and can be seen through at least one of its sample points
##     gives a PERIPHERAL cue: a coarse bearing and nothing else, at most once per cue cooldown for each thing;
##   * a thing inside the narrow inspection cone along the gaze that can be seen, and looks big enough, is INSPECTED:
##     its position is estimated from the points that could be seen, and the longer it is held in the cone without a
##     break the finer the category (movement, possible prey, fly-like prey: A-004), the exposure each step needs
##     growing as the thing looks smaller.
## Line of sight is five rays from the eye to sample points of the thing; a point the world stands in front of does not
## count. Nothing about a thing that cannot be seen reaches the memory: a hidden thing makes no observation, and the
## memory is never refreshed from where it really is.
## The sensor also looks at the spots where lost contacts were last seen. A spot that is inside the cone, close enough
## that the thing would look big enough, entirely in plain view and holds nothing for the time an easy target needs, is
## reported to the memory as empty, which drops the mark.
## The sensor decides no behaviour and writes no words (spec 19.3): its output is Observation records. A thing that has
## never been sensed has no track id and no record anywhere: the ids are given at the first observation, not before.
## Who is who (A-027). Three things are kept apart. The world's id for a thing is how the sensor finds it again each tick (the key of
## _tracks); it is never the spider's idea of who the thing is. A contact (the memory's track id) is the spider's hypothesis that some
## observations are of one visible thing. Familiarity is what earlier exposure to a contact taught, kept per contact (_kept) and faded
## with the memory of it; it names no individual. A thing's evidence stays under one contact while sight of it is unbroken: the contact
## is live and the thing itself was filed under it within the memory's hold time for that kind of evidence (continuous observation, and the
## brief gaps the memory calls justified). Once sight has been lost the world id decides nothing, and nothing the thing did while it was
## out of sight is read: a new inspection is compared with the lost contacts by where each was last observed, how long ago, how big it
## looked, what it can look like and how fast it was seen moving. It is taken for a lost contact only when exactly one of them could
## be it (inside a region that grows with the time at an explicit speed bound, about as big, and not finer in appearance than what was
## learned) and no other thing sighted in the same tick could be it either (chunk 7B: two look-alikes that come into view together are
## two fresh contacts, and the order the world lists them in decides nothing); otherwise it is a fresh contact that starts again at
## "movement" and inherits no exposure, and the old marks fade or are looked at and found empty. A bare cue has no place to compare, so it is always a weak new contact; the inspection that follows
## it makes the comparison, and a cue-only contact that turns out to be a lost one is folded into it.
## Rates (spec 20): the broad scan of everything runs at broad_query_hz; things already tracked, things whose last
## position is remembered as a mark, and things within close_check_range_wu are checked every tick.
## Order (spec 20): the sensor runs at the start of the tick (priority -10), before the motor and the things that move,
## so it reads the world as the previous tick committed it.
##
## Like the camera, the sensor does nothing until physics queries can see the world it was made with (a body added in a
## physics tick is invisible to queries until that tick is over): a ray cast earlier would find an empty world and
## everything would look in plain view.

const SimClock = preload("res://scripts/core/sim_clock.gd")  # one game clock: count in its ticks, never the engine rate
const Observation = preload("res://scripts/perception/observation.gd")
const ObservationMemory = preload("res://scripts/perception/observation_memory.gd")
const PerceptionMath = preload("res://scripts/perception/perception_math.gd")
const Perceivable = preload("res://scripts/perception/perceivable.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")

## Emitted for every peripheral cue made (after the cooldown), for tests and the developer view.
signal cue_emitted(obs: Observation)

const PRIORITY := -10
const SAMPLE_COUNT := 5
## The sample points sit this share of a thing's radius off its centre.
const SAMPLE_SPREAD := 0.8
const MIN_DISTANCE := 0.05
const EPS := 1e-6


## What the sensor keeps for each thing it can sense, under the world's id for it. It is the channel to a visible thing, not an identity.
class Track extends RefCounted:
	var percept_id: String = ""
	## The contact this thing's evidence is filed under while sight of it is unbroken. "" until the first observation (only a thing that
	## has been sensed has one); it is replaced, not trusted, once sight of the thing has been lost.
	var track_id: String = ""
	## The tick of the last evidence of this thing that was filed under that contact.
	var link_tick: int = -1000000
	## Continuous exposure in the cone, seconds.
	var exposure: float = 0.0
	## Seconds since the last inspected tick.
	var gap_s: float = 1.0e9
	var next_cue_tick: int = 0
	## What the last check of this thing found, for the developer overlay.
	var last_check: Dictionary = {}


var observer: Node3D        # needs get_eye_position(), get_gaze_direction(), get_visual_up(), get_heading_vector()
var memory: ObservationMemory
var observer_id: String = "spider"
var enabled: bool = true

## Parameters: the species profile's perception section (configure_from).
var cone_deg: float = 30.0
var peripheral_cone_deg: float = 300.0
var sector_deg: float = 22.5
var range_wu: float = 40.0
var easy_s: float = 0.4
var fly_s: float = 1.0
var easy_apparent_deg: float = 3.0
var min_apparent_deg: float = 0.6
var motion_min_speed: float = 0.3
var cue_cooldown_s: float = 0.8
var broad_hz: float = 10.0
var close_range_wu: float = 4.0
var grace_s: float = 0.15
var decay_s: float = 6.0
## The association rule (A-027): the assumed top speed of anything unseen, and the size ratio that still counts as one thing.
var contact_speed_bound: float = 2.0
var contact_size_ratio: float = 1.5

## Statistics, for tests and the developer overlay.
var tick: int = 0
var broad_scans: int = 0
var rays_this_tick: int = 0
var max_rays_in_a_tick: int = 0
var rays_total: int = 0
var cues_made: int = 0
var inspections_made: int = 0
var checks_this_tick: int = 0
var checks_total: int = 0
## The cost of the memory-spot checks (looking again at a remembered empty place): checks made and the rays they used, also counted in rays_total.
var spot_checks_total: int = 0
var spot_rays_total: int = 0
## CPU time of the sensor tick in microseconds (ticks that did the work): the total, the largest and a ring of the latest for percentiles.
const COST_RING := 1200
var cpu_us_total: int = 0
var cpu_ticks: int = 0
var cpu_us_max: int = 0
var cpu_ring: PackedInt32Array = PackedInt32Array()
var _cost_base: int = 0
## What the observer's eyes, gaze and up were on the last tick (the developer view draws the cones from them).
var last_eye: Vector3 = Vector3.ZERO
var last_axis: Vector3 = Vector3.FORWARD
var last_up: Vector3 = Vector3.UP

## T13a, the lateral eyes' motion sense, for the spider-eye picture only (a shimmer in its soft surround). Each thing the eyes could see
## moving on its last check, under the world's id for it: {"direction": the sensed direction from the eye, "distance": WU, "apparent":
## degrees across, "tick"}. An entry stays MOTION_HOLD_TICKS after the thing was last seen moving. It is presentation: nothing reads it to
## decide anything, the memory never sees it, and it holds only what the sightline checks found (a hidden thing never appears).
const MOTION_HOLD_TICKS := 15
var motion_seen: Dictionary = {}

var _tracks: Dictionary = {}   # percept id -> Track
var _serial: int = 0
var _next_broad_tick: int = 0
var _spots: Dictionary = {}    # track id -> {exposure, gap}
var _kept: Dictionary = {}     # track id -> continuous exposure the contact had when sight of it last ended: familiarity builds on this
var _born_physics_frames: int = 0
var _born_in_physics: bool = false


func _ready() -> void:
	process_physics_priority = PRIORITY
	_born_physics_frames = Engine.get_physics_frames()
	_born_in_physics = Engine.is_in_physics_frame()


## Takes the perception section of a species profile (spec 21.1) and sets the memory's timing to match.
func configure_from(profile: RefCounted) -> void:
	cone_deg = profile.inspect_cone_degrees
	peripheral_cone_deg = profile.peripheral_cone_degrees
	sector_deg = profile.peripheral_sector_degrees
	range_wu = profile.sensor_range_wu
	easy_s = profile.easy_target_inspection_s
	fly_s = profile.fly_like_inspection_s
	easy_apparent_deg = profile.easy_apparent_size_deg
	min_apparent_deg = profile.min_apparent_size_deg
	motion_min_speed = profile.motion_min_speed_wu_s
	cue_cooldown_s = profile.cue_cooldown_s
	broad_hz = profile.broad_query_hz
	close_range_wu = profile.close_check_range_wu
	grace_s = profile.exposure_grace_s
	decay_s = profile.memory_decay_s
	contact_speed_bound = profile.contact_speed_bound_wu_s
	contact_size_ratio = profile.contact_size_ratio
	if memory != null:
		apply_to_memory()


## The memory's timing follows the sensor's: a cue repeats every cooldown, so a peripheral contact is held a little
## longer than that; an inspection comes every tick, so it is held for the exposure grace.
func apply_to_memory() -> void:
	memory.configure(float(SimClock.HZ), decay_s, grace_s, cue_cooldown_s + 0.2)


## True once queries can see the bodies that were in the scene when the sensor entered it (see the header).
func is_world_ready() -> bool:
	return not _born_in_physics or Engine.get_physics_frames() > _born_physics_frames


func get_track(percept_id: String) -> Track:
	return _tracks.get(percept_id)


## The track a percept id is filed under, "" if it was never sensed. Tests and the developer overlay only.
func track_id_for(percept_id: String) -> String:
	var t: Track = _tracks.get(percept_id)
	return "" if t == null else t.track_id


func tracks() -> Array:
	return _tracks.values()


## Capture is bodily evidence. Called in the capture tick, before percept cleanup.
## Never search lost marks by world ID, and never invent a visual classification.
func on_capture(event: Dictionary) -> void:
	if str(event.get("owner", "")) != observer_id:
		return
	var t: Track = _tracks.get(str(event.get("prey", "")))
	if t != null and _is_linked(t):
		memory.resolve_capture(t.track_id)
		_kept.erase(t.track_id)
		_spots.erase(t.track_id)
		_tracks.erase(t.percept_id)
	elif event.get("contact_position") is Vector3 and event.has("contact_radius"):
		# A jump can lose the visual cone before contact. The jaws now supply a
		# position and size, not a secret world identity or visual classification.
		var matches: Array[String] = []
		var size := float(event["contact_radius"]) * 2.0
		for c: ObservationMemory.Contact in memory.marks():
			var age := float(tick - c.position_tick) / float(SimClock.HZ)
			var radius := PerceptionMath.plausible_radius(c.size_wu, size, age, contact_speed_bound, c.speed_wu_s)
			if c.position.distance_to(event["contact_position"]) <= radius and PerceptionMath.sizes_compatible(c.size_wu, size, contact_size_ratio):
				matches.append(c.track_id)
		if matches.size() == 1:
			memory.resolve_capture(matches[0])
			_kept.erase(matches[0])
			_spots.erase(matches[0])


## Whether the eye could sense a thing of `radius` at `center` right now: in range, inside the field of the peripheral eyes and at least one
## of its sample points in plain view, which is exactly what a sensed thing has to pass. Changes no state of the senses; the rays are counted.
## The prey population asks it before a replacement is let in (it must come in where the spider could not sense it).
func could_sense(center: Vector3, radius: float) -> bool:
	if observer == null or not is_instance_valid(observer):
		return true
	var eye: Vector3 = observer.get_eye_position()
	var to := center - eye
	var dist := to.length()
	if dist > range_wu:
		return false
	if dist < MIN_DISTANCE:
		return true
	if (observer.get_gaze_direction() as Vector3).angle_to(to / dist) > deg_to_rad(peripheral_cone_deg) * 0.5:
		return false
	return not _visible_points(observer.get_world_3d().direct_space_state, eye, center, maxf(radius, 0.01), observer.get_visual_up()).is_empty()


## Developer view: what the last check of each thing found (distance, off-axis angle, how many points were seen, whether
## it was in the cone), with the exposure so far. Truth-derived numbers, for developers only: nothing in the player's
## presentation reads this.
func describe_tracks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Track in _tracks.values():
		var row: Dictionary = t.last_check.duplicate()
		row["percept_id"] = t.percept_id
		row["track_id"] = t.track_id
		row["exposure_s"] = t.exposure if t.gap_s <= grace_s + EPS else 0.0
		out.append(row)
	return out


## Forget everything about what is being tracked (the memory is cleared separately).
func reset() -> void:
	_tracks.clear()
	motion_seen.clear()
	_spots.clear()
	_kept.clear()
	_next_broad_tick = 0


func _physics_process(delta: float) -> void:
	rays_this_tick = 0
	checks_this_tick = 0
	if not enabled or memory == null or observer == null or not is_instance_valid(observer):
		return
	if not is_world_ready():
		return
	var t0 := Time.get_ticks_usec()
	tick += 1
	var eye: Vector3 = observer.get_eye_position()
	var axis: Vector3 = observer.get_gaze_direction()
	var up: Vector3 = observer.get_visual_up()
	var forward: Vector3 = observer.get_heading_vector()
	last_eye = eye
	last_axis = axis
	last_up = up
	var space: PhysicsDirectSpaceState3D = observer.get_world_3d().direct_space_state
	var broad_due := tick >= _next_broad_tick
	if broad_due:
		_next_broad_tick = tick + maxi(1, roundi(float(SimClock.HZ) / maxf(broad_hz, 0.1)))
		broad_scans += 1
	for t: Track in _tracks.values():
		t.gap_s += delta
	var inspected: Array[Dictionary] = []
	var sightings: Array[Dictionary] = []
	var present: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(Perceivable.GROUP):
		if not node.has_method("get_percept"):
			continue
		var p: Dictionary = node.get_percept()
		if p.is_empty():
			continue
		present[str(p["id"])] = true
		var t := _track_of(str(p["id"]))
		var c: ObservationMemory.Contact = memory.get_contact(t.track_id) if t.track_id != "" else null
		var watching := c != null and (c.state == ObservationMemory.Contact.LIVE or c.has_mark())
		if broad_due or watching or eye.distance_to(p["position"] as Vector3) <= close_range_wu:
			checks_this_tick += 1
			checks_total += 1
			_sense(t, p, eye, axis, up, forward, space, delta, inspected, sightings)
	_file_sightings(sightings, delta)
	_check_spots(eye, axis, up, space, delta, inspected)
	memory.advance(tick)
	_forget_gone(present)
	for id: String in motion_seen.keys():
		if not present.has(id) or tick - int(motion_seen[id]["tick"]) > MOTION_HOLD_TICKS:
			motion_seen.erase(id)
	max_rays_in_a_tick = maxi(max_rays_in_a_tick, rays_this_tick)
	_record_cost(Time.get_ticks_usec() - t0)


func _record_cost(us: int) -> void:
	if cpu_ring.is_empty():
		cpu_ring.resize(COST_RING)
	cpu_us_total += us
	cpu_us_max = maxi(cpu_us_max, us)
	cpu_ring[cpu_ticks % COST_RING] = us
	cpu_ticks += 1


## Percentile of the latest measured sensor ticks (since the window began), in microseconds.
func cost_percentile(q: float) -> int:
	var n := mini(cost_ticks(), COST_RING)
	if n <= 0:
		return 0
	var xs := PackedInt32Array()
	for i in n:
		xs.append(cpu_ring[(cpu_ticks - 1 - i) % COST_RING])
	xs.sort()
	return xs[clampi(int(ceil(q * float(n))) - 1, 0, n - 1)]


## Ticks measured since the window began (the start of the run, or the last reset_cost()).
func cost_ticks() -> int:
	return cpu_ticks - _cost_base


## Begins a new measuring window (the totals, the largest and the percentiles start again).
func reset_cost() -> void:
	cpu_us_total = 0
	cpu_us_max = 0
	_cost_base = cpu_ticks


func _track_of(percept_id: String) -> Track:
	var t: Track = _tracks.get(percept_id)
	if t == null:
		t = Track.new()
		t.percept_id = percept_id
		_tracks[percept_id] = t
	return t


## Lifecycle (A-029): a thing that is no longer there to be sensed (its node left the world, or it gives no percept) loses its entry; the
## contacts it made are not touched, they fade and expire on their own clocks. Exposure kept for a contact that is gone goes too.
func _forget_gone(present: Dictionary) -> void:
	for pid: String in _tracks.keys():
		if not present.has(pid):
			_tracks.erase(pid)
	for id: String in _kept.keys():
		if memory.get_contact(id) == null:
			_kept.erase(id)


## A new contact for a thing, with an opaque id; the thing is filed under it from now on.
func _new_contact_for(t: Track) -> String:
	_serial += 1
	t.track_id = "trk_%d" % _serial
	return t.track_id


## True while this thing's evidence is a continuation of the contact it was last filed under (A-027): that contact is live and the thing
## itself was filed under it within the memory's hold time for that kind of evidence. Sight that was lost for longer is not unbroken,
## whatever the world's id says, and neither is sight of a thing whose contact someone else kept alive.
func _is_linked(t: Track) -> bool:
	if t.track_id == "":
		return false
	var c: ObservationMemory.Contact = memory.get_contact(t.track_id)
	return c != null and c.state == ObservationMemory.Contact.LIVE and tick - t.link_tick <= memory.hold_ticks(c.modality)


## The contact a cue is filed under: the one the thing is unbrokenly filed under, else a new one (a bearing cannot say which
## remembered place this is).
func _cue_contact(t: Track) -> String:
	return t.track_id if _is_linked(t) else _new_contact_for(t)


## The sightings of this tick that are first looks after a loss of sight (or at a thing known only from cues) are compared with the lost
## contacts together, not one after the other (A-027): a lost contact is taken by a sighting only when it is that sighting's one candidate
## and no other sighting of the tick could be it either. Two look-alikes that come into view at once, both inside the region one lost
## contact could have reached, are two fresh contacts, whichever of them the sensor happens to handle first; and the order the world lists
## its things in, like the world's ids, decides nothing. Then each sighting is filed.
func _file_sightings(sightings: Array[Dictionary], delta: float) -> void:
	if sightings.is_empty():
		return
	var claims: Dictionary = {}   # lost contact id -> how many sightings of this tick could be it
	for s: Dictionary in sightings:
		s["match"] = ""
		s["candidates"] = []
		if _placed_and_unbroken(s["t"]):
			continue
		var found := _lost_candidates(s["estimate"], 2.0 * float(s["p"]["radius"]), s["p"].get("max_category", Observation.FLY_LIKE_PREY))
		s["candidates"] = found
		for id: String in found:
			claims[id] = int(claims.get(id, 0)) + 1
	for s: Dictionary in sightings:
		var found: Array = s["candidates"]
		if found.size() == 1 and int(claims[found[0]]) == 1:
			s["match"] = str(found[0])
	for s: Dictionary in sightings:
		_inspect(s["t"], s["p"], s["estimate"], s["est_dir"], s["apparent"], s["visible_fraction"], delta, str(s["match"]))


## True while the thing's evidence is a continuation of a contact that already has a place: nothing to compare.
func _placed_and_unbroken(t: Track) -> bool:
	return _is_linked(t) and memory.get_contact(t.track_id).has_position


## The contact an inspection is filed under (A-027). Unbroken sight of a thing already being inspected: the same contact. Otherwise this
## is the first inspection after a loss of sight, or of a thing known only from cues: if the comparison made with the other sightings of
## the tick (_file_sightings) found exactly one lost contact it could be, it is that one (a contact known only from cues is folded into
## it); if it found none, or more than one, it is the contact the cues made or a new one, with nothing carried over.
func _inspection_contact(t: Track, matched: String) -> String:
	var linked := _is_linked(t)
	if linked and memory.get_contact(t.track_id).has_position:
		return t.track_id
	if matched != "":
		if linked:
			memory.merge(t.track_id, matched)
		t.track_id = matched
		return matched
	return t.track_id if linked else _new_contact_for(t)


## The lost contacts a new sighting could be (their track ids; empty when none). A contact could be it when the sighting is inside the
## region its thing could have reached since it was last observed (a function of the time and the speed bound, never of where the thing
## went), looks about as big, and is not finer in appearance than what was learned. Only a focused sighting is ever asked: a bearing cue
## says nothing about which remembered place this is.
func _lost_candidates(estimate: Vector3, size_wu: float, cap: StringName) -> Array[String]:
	var hz := float(SimClock.HZ)
	var found: Array[String] = []
	for m: ObservationMemory.Contact in memory.marks():
		var elapsed := float(tick - m.position_tick) / hz
		var reach := PerceptionMath.plausible_radius(m.size_wu, size_wu, elapsed, contact_speed_bound, m.speed_wu_s)
		if estimate.distance_to(m.position) > reach:
			continue
		if not PerceptionMath.sizes_compatible(m.size_wu, size_wu, contact_size_ratio):
			continue
		if not PerceptionMath.categories_compatible(m.category, cap):
			continue
		found.append(m.track_id)
	return found


func _sense(t: Track, p: Dictionary, eye: Vector3, axis: Vector3, up: Vector3, forward: Vector3, space: PhysicsDirectSpaceState3D, delta: float, inspected: Array[Dictionary], sightings: Array[Dictionary]) -> void:
	var center: Vector3 = p["position"]
	var radius := maxf(float(p["radius"]), 0.01)
	var to := center - eye
	var dist := to.length()
	t.last_check = {"in_range": dist <= range_wu, "distance": dist}
	if dist > range_wu or dist < MIN_DISTANCE:
		return
	var dir := to / dist
	var off_axis := axis.angle_to(dir)
	t.last_check["off_axis_deg"] = rad_to_deg(off_axis)
	if off_axis > deg_to_rad(peripheral_cone_deg) * 0.5:
		return
	var seen := _visible_points(space, eye, center, radius, up)
	t.last_check["visible_points"] = seen.size()
	if seen.is_empty():
		return
	var estimate := Vector3.ZERO
	for s: Vector3 in seen:
		estimate += s
	estimate /= float(seen.size())
	var est_dir := (estimate - eye).normalized()
	var apparent := PerceptionMath.apparent_size_deg(2.0 * radius, dist)
	var in_cone := off_axis <= deg_to_rad(cone_deg) * 0.5
	t.last_check["in_cone"] = in_cone
	t.last_check["apparent_deg"] = apparent
	var visible_fraction := float(seen.size()) / float(SAMPLE_COUNT)
	if (p["velocity"] as Vector3).length() >= motion_min_speed:
		motion_seen[str(p["id"])] = {"direction": est_dir, "distance": dist, "apparent": apparent, "tick": tick}
	if in_cone and apparent >= min_apparent_deg:
		sightings.append({"t": t, "p": p, "estimate": estimate, "est_dir": est_dir, "apparent": apparent, "visible_fraction": visible_fraction})
		inspected.append({"position": estimate, "radius": radius})
	elif (p["velocity"] as Vector3).length() >= motion_min_speed and tick >= t.next_cue_tick:
		_cue(t, est_dir, forward, up, dist)


func _inspect(t: Track, p: Dictionary, estimate: Vector3, est_dir: Vector3, apparent: float, visible_fraction: float, delta: float, matched: String) -> void:
	var cap: StringName = p.get("max_category", Observation.FLY_LIKE_PREY)
	var id := _inspection_contact(t, matched)
	if t.gap_s > grace_s + EPS:
		# A new stretch of exposure. What an earlier one taught the contact it belongs to still counts, as much as the memory of
		# it does: a new contact has been taught nothing.
		t.exposure = float(_kept.get(id, 0.0)) * memory.familiarity(id)
	t.exposure += delta
	_kept[id] = t.exposure
	t.gap_s = 0.0
	var category := PerceptionMath.classify(t.exposure, apparent, easy_s, fly_s, easy_apparent_deg, min_apparent_deg)
	if Observation.rank(category) > Observation.rank(cap):
		category = cap
	var obs := Observation.new()
	obs.observer_id = observer_id
	obs.track_id = id
	obs.target_id = str(p["id"]) if Observation.rank(category) >= Observation.rank(Observation.POSSIBLE_PREY) else ""
	obs.modality = Observation.INSPECTION
	obs.has_position = true
	obs.estimated_position = estimate
	obs.direction = est_dir
	obs.confidence = PerceptionMath.inspection_confidence(t.exposure, PerceptionMath.required_exposure(fly_s, apparent, easy_apparent_deg), visible_fraction)
	obs.observed_tick = tick
	obs.category = category
	obs.size_wu = 2.0 * float(p["radius"])
	obs.apparent_size_deg = apparent
	obs.speed_wu_s = (p["velocity"] as Vector3).length()
	if memory.ingest(obs) != null:
		inspections_made += 1
		t.link_tick = tick


func _cue(t: Track, est_dir: Vector3, forward: Vector3, up: Vector3, dist: float) -> void:
	t.next_cue_tick = tick + roundi(cue_cooldown_s * float(SimClock.HZ))
	var obs := Observation.new()
	obs.observer_id = observer_id
	obs.track_id = _cue_contact(t)
	obs.modality = Observation.PERIPHERAL
	obs.has_position = false
	obs.direction = PerceptionMath.quantize_direction(est_dir, forward, up, sector_deg)
	obs.confidence = PerceptionMath.peripheral_confidence(dist, range_wu)
	obs.observed_tick = tick
	obs.category = Observation.MOVEMENT
	if memory.ingest(obs) != null:
		cues_made += 1
		t.link_tick = tick
		cue_emitted.emit(obs)


## The sample points of a sphere of `radius` at `center` that the eye can see: the centre and four points a little off
## it, across the line of sight and along it. An empty array means none could be seen.
func _visible_points(space: PhysicsDirectSpaceState3D, eye: Vector3, center: Vector3, radius: float, up: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for s in _sample_points(eye, center, radius, up):
		if _clear(space, eye, s, radius):
			out.append(s)
	return out


func _sample_points(eye: Vector3, center: Vector3, radius: float, up: Vector3) -> Array[Vector3]:
	var d := (center - eye).normalized()
	var side := d.cross(up)
	if side.length_squared() < 1e-6:
		side = d.cross(Vector3.RIGHT)
	side = side.normalized()
	var vert := side.cross(d).normalized()
	var r := radius * SAMPLE_SPREAD
	var out: Array[Vector3] = [center, center + side * r, center - side * r, center + vert * r, center - vert * r]
	return out


## True when the eye can see the sample point `to` of a thing of `radius`: the world stops the ray no further than a small allowance short
## of it (PerceptionMath.sight_tolerance, A-024). A world hit before the point is occlusion; it is not forgiven because the point is near.
func _clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, radius: float) -> bool:
	rays_this_tick += 1
	rays_total += 1
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD))
	if hit.is_empty():
		return true
	var length := from.distance_to(to)
	return from.distance_to(hit["position"] as Vector3) >= length - PerceptionMath.sight_tolerance(radius, length)


func _all_visible(space: PhysicsDirectSpaceState3D, eye: Vector3, center: Vector3, radius: float, up: Vector3) -> bool:
	spot_checks_total += 1
	var before := rays_total
	var all := true
	for s in _sample_points(eye, center, radius, up):
		if not _clear(space, eye, s, radius):
			all = false
			break
	spot_rays_total += rays_total - before
	return all


## The remembered spots of lost contacts: inspecting one that is in plain view and empty drops its mark.
func _check_spots(eye: Vector3, axis: Vector3, up: Vector3, space: PhysicsDirectSpaceState3D, delta: float, inspected: Array[Dictionary]) -> void:
	var half := deg_to_rad(cone_deg) * 0.5
	var marks := memory.marks()
	for id: String in _spots.keys():
		var still := false
		for m: ObservationMemory.Contact in marks:
			if m.track_id == id:
				still = true
		if not still:
			_spots.erase(id)
	for m: ObservationMemory.Contact in marks:
		var st: Dictionary = _spots.get(m.track_id, {"exposure": 0.0, "gap": 1.0e9})
		st["gap"] = float(st["gap"]) + delta
		var to := m.position - eye
		var dist := to.length()
		var size := maxf(m.size_wu, 0.2)
		var apparent := PerceptionMath.apparent_size_deg(size, dist)
		var plain := false
		if dist >= MIN_DISTANCE and dist <= range_wu and axis.angle_to(to / dist) <= half and apparent >= min_apparent_deg:
			plain = _all_visible(space, eye, m.position, size * 0.5, up)
			if plain:
				for q: Dictionary in inspected:
					if (q["position"] as Vector3).distance_to(m.position) < size + float(q["radius"]):
						plain = false  # something is there: not an empty spot
		if plain:
			if float(st["gap"]) > grace_s + EPS:
				st["exposure"] = 0.0
			st["exposure"] = float(st["exposure"]) + delta
			st["gap"] = 0.0
			if float(st["exposure"]) + EPS >= PerceptionMath.required_exposure(easy_s, apparent, easy_apparent_deg):
				memory.invalidate(m.track_id, "empty")
				_spots.erase(m.track_id)
				continue
		_spots[m.track_id] = st
