extends Node
## T12a, the spider's other senses (ROADMAP step 3; spec 7: "add substrate vibration only across connected materials/silk with attenuation.
## Do not implement vibration as an unrestricted radius that travels through air gaps"; spec 16: "the same event can drive a low sound, a
## visual cue, and optional haptics").
##
## Spiders feel substrate vibration through slit sensilla in their legs, most sensitively at tens to hundreds of hertz (studies of
## Cupiennius; salticids have the same kind of organs). Here a fly's landing, take-off and footsteps shake the surface it stands on. The
## shake reaches the spider only if that surface and the one under the spider's feet are joined through touching solid pieces (the boxes
## the habitat is built of), and it fades with distance (FADE_WU) and at every joint between pieces (JOINT_LOSS). Nothing crosses an air
## gap, and a spider in the air or on its line feels nothing through its feet. What it feels is a direction, not a place: the event
## carries a bearing on the spider's surface and a strength, which the HUD draws as a ripple, the soundscape plays as a low thrum and a
## controller can rumble (the "haptics" setting). Felt events are presentation: no fly, sense or memory decision depends on them yet.

signal felt(event: Dictionary)

const Layers = preload("res://scripts/core/physics_layers.gd")

const STRENGTH := {"landing": 1.0, "take-off": 0.8, "footsteps": 0.45}
const FADE_WU := 4.0          # the shake falls to 1/e over this distance
const JOINT_LOSS := 0.5       # and to this share at each joint between pieces
const THRESHOLD := 0.08       # weaker than this is not felt
const STEP_EVERY_S := 0.3     # a walking fly's footsteps, as separate events
const CONTACT_WU := 0.05      # two boxes this close count as touching

var spider: Node3D    # SpiderMotor
var prey: Node3D      # PreyDirector
var lab: Node3D       # the habitat (windowsill or lab): its boxes are the pieces
var settings: Node
## The last felt events, newest last (tests and the developer overlay read it).
var felt_log: Array[Dictionary] = []
## Every event, felt or not, with why (tests read it).
var all_log: Array[Dictionary] = []

var _last_state: Dictionary = {}   # fly id -> state
var _step_left: Dictionary = {}    # fly id -> seconds to the next footstep
var _boxes: Array[Dictionary] = [] # {"body": StaticBody3D, "aabb": AABB}
var _box_count := -1


func _physics_process(delta: float) -> void:
	if prey == null or spider == null or not is_instance_valid(prey):
		return
	for f: Node3D in prey.flies:
		if not is_instance_valid(f):
			continue
		var id := str(f.id)
		var now: int = f.state
		var before: int = int(_last_state.get(id, now))
		_last_state[id] = now
		var was_flying: bool = before >= f.State.TAKEOFF and before <= f.State.REPOSITION
		if not was_flying and f.is_flying() and before != f.State.CAPTURED:
			shake(f.global_position, "take-off", f)
		elif was_flying and now == f.State.PERCHED:
			shake(f.stand, "landing", f)
		if now == f.State.PERCHED and f.has_method("walking_now") and f.walking_now():
			var left: float = float(_step_left.get(id, 0.0)) - delta
			if left <= 0.0:
				left = STEP_EVERY_S
				shake(f.stand, "footsteps", f)
			_step_left[id] = left
		else:
			_step_left[id] = 0.0


## A shake of `kind` at `point` (on a surface). Returns the event; it is felt (and emitted) only if it reaches the spider's feet.
func shake(point: Vector3, kind: String, source: Node3D = null) -> Dictionary:
	var ev := {"kind": kind, "felt": false, "why": "", "strength": 0.0, "joints": -1, "bearing": 0.0, "word": ""}
	var under_spider: Object = spider.get_support_body() if spider.has_method("get_support_body") else null
	if under_spider == null or not spider.is_supported():
		ev["why"] = "the spider's feet are off the surface"
		return _log(ev)
	var normal: Vector3 = source.normal if source != null and "normal" in source else Vector3.UP
	var under_source: Object = body_under(point, normal)
	if under_source == null:
		ev["why"] = "nothing solid under the source"
		return _log(ev)
	var joints := joints_between(under_source, under_spider)
	ev["joints"] = joints
	if joints < 0:
		ev["why"] = "not joined to the spider's surface (an air gap)"
		return _log(ev)
	var dist: float = point.distance_to(spider.global_position)
	var strength: float = float(STRENGTH.get(kind, 0.5)) * exp(-dist / FADE_WU) * pow(JOINT_LOSS, joints)
	ev["strength"] = strength
	if strength < THRESHOLD:
		ev["why"] = "too faint (%.2f at %.1f WU, %d joints)" % [strength, dist, joints]
		return _log(ev)
	ev["felt"] = true
	ev["bearing"] = bearing_of(point)
	ev["word"] = direction_word(spider, point)
	ev["direction"] = (point - spider.global_position).normalized()
	felt_log.append(ev)
	if felt_log.size() > 50:
		felt_log.pop_front()
	_rumble(strength)
	felt.emit(ev)
	return _log(ev)


func _log(ev: Dictionary) -> Dictionary:
	all_log.append(ev)
	if all_log.size() > 200:
		all_log.pop_front()
	return ev


## The solid piece under a point on a surface (a short ray along -normal), or null.
func body_under(point: Vector3, normal: Vector3) -> Object:
	var space := spider.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(point + normal * 0.15, point - normal * 0.35)
	q.collision_mask = Layers.WORLD
	var hit := space.intersect_ray(q)
	return hit.get("collider") if not hit.is_empty() else null


## How many joints a shake crosses from piece `a` to piece `b` (0: the same piece), or -1 when they are not joined.
func joints_between(a: Object, b: Object) -> int:
	if a == b:
		return 0
	_refresh_boxes()
	var ia := _index_of(a)
	var ib := _index_of(b)
	if ia < 0 or ib < 0:
		return -1
	var seen := {ia: 0}
	var queue: Array[int] = [ia]
	while not queue.is_empty():
		var i: int = queue.pop_front()
		if i == ib:
			return int(seen[i])
		var ai: AABB = _boxes[i]["aabb"]
		for j in _boxes.size():
			if seen.has(j) or not _enabled(j):
				continue
			if ai.grow(CONTACT_WU).intersects(_boxes[j]["aabb"]):
				seen[j] = int(seen[i]) + 1
				queue.append(j)
	return -1


func _enabled(i: int) -> bool:
	var body: StaticBody3D = _boxes[i]["body"]
	return is_instance_valid(body) and body.collision_layer != 0


func _index_of(o: Object) -> int:
	for i in _boxes.size():
		if _boxes[i]["body"] == o:
			return i
	return -1


## The habitat's solid boxes and their world bounds, rebuilt when pieces are added (a test's fixture, a leaf that returns).
func _refresh_boxes() -> void:
	var found: Array[StaticBody3D] = []
	if lab != null and is_instance_valid(lab):
		for n in lab.find_children("*", "StaticBody3D", true, false):
			found.append(n as StaticBody3D)
	if found.size() == _box_count:
		return
	_box_count = found.size()
	_boxes.clear()
	for body in found:
		for c in body.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
				var size: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size
				var xf := (c as CollisionShape3D).global_transform
				var aabb := xf * AABB(-size * 0.5, size)
				_boxes.append({"body": body, "aabb": aabb})


## The direction to `point` on the spider's surface, radians from its heading, positive to its left.
func bearing_of(point: Vector3) -> float:
	var n: Vector3 = spider.get_support_normal()
	var to := point - spider.global_position
	to -= n * to.dot(n)
	if to.length_squared() < 1.0e-6:
		return 0.0
	return (spider.get_heading_vector() as Vector3).signed_angle_to(to.normalized(), n)


## Words for a direction from the spider: "ahead", "ahead-left", "left", "behind-left", "behind" and so on, with "above" or "below"
## first when the point is well off the spider's surface plane.
static func direction_word(observer: Node3D, point: Vector3) -> String:
	var n: Vector3 = observer.get_visual_up() if observer.has_method("get_visual_up") else Vector3.UP
	var heading: Vector3 = observer.get_heading_vector() if observer.has_method("get_heading_vector") else -observer.global_transform.basis.z
	var to := point - observer.global_position
	var up := to.dot(n)
	var flat := to - n * up
	var word := ""
	if flat.length_squared() > 1.0e-6:
		var a := rad_to_deg(heading.signed_angle_to(flat.normalized(), n))
		var names := ["ahead", "ahead-left", "left", "behind-left", "behind", "behind-right", "right", "ahead-right"]
		word = names[posmod(roundi(a / 45.0), 8)]
	var rise := rad_to_deg(atan2(up, maxf(flat.length(), 1.0e-6)))
	if rise > 35.0:
		word = "above" if word == "" else "above, " + word
	elif rise < -35.0:
		word = "below" if word == "" else "below, " + word
	return word if word != "" else "here"


func _rumble(strength: float) -> void:
	if settings == null or not bool(settings.get_value("haptics")):
		return
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, clampf(strength * 0.7, 0.0, 1.0), clampf(strength * 0.35, 0.0, 1.0), 0.12)
