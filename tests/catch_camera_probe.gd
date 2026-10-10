extends RefCounted
## Measures what the camera shows while the spider is on its safety line (A-017, chunk 6A). One call to
## measure() takes one sample of the view and reads only the camera rig and the world: no camera input is
## involved. crowded_reasons() applies the criterion stated in tests/integration/test_catch_camera.gd.

const Layers = preload("res://scripts/core/physics_layers.gd")

## The inner part of the screen that counts as in frame: this fraction in from each edge is margin.
const FRAME_MARGIN := 0.03
## Rays across the screen for the "nearest geometry" measure (columns by rows).
const GRID_X := 16
const GRID_Y := 9
## Geometry closer to the camera than this is "near"; the share of the screen it covers is near_cover.
const NEAR_DISTANCE := 1.0
const MID_DISTANCE := 2.5
const LINE_SAMPLES := 24
## A ray to a point that hits something this much short of it means the point is hidden.
const OCCLUSION_TOLERANCE := 0.05
## Sample points on the body, in the body's own frame (it is about 1 WU long, 0.6 across): centre, head, tail, back, belly.
const BODY_POINTS: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0, 0, -0.4), Vector3(0, 0, 0.4), Vector3(0, 0.25, 0), Vector3(0, -0.25, 0)]
const BODY_POINTS_NEEDED := 3

## The "crowded" criterion (stated in the test header): any of these makes a tick crowded.
const CLOSE_FRACTION := 0.6      # the 1 WU body is more than this share of the screen height: the camera is on top of it
const SPAN_MIN := 0.5            # less than this share of the line between the lip and the spider is in frame and unhidden
const COVER_MAX := 1.0 / 3.0     # geometry within NEAR_DISTANCE covers more than this share of the screen


## One sample of the view. Keys: boom (physics state), cam_distance (what is drawn), auto_pitch_deg, view_yaw_deg,
## yaw_assist_deg, body_drawn, body_seen (sample points in frame and unhidden), spider_visible, spider_frac (the
## 1 WU body length as a share of the screen height), line_active, lip, lip_in_frame, lip_occluded, line_visible
## (share of the whole drawn line), span_visible (share of the stretch from the lip to the spider), near_cover,
## mid_cover, floor_visible. The lip is the line's bend point (its anchor when there is no bend); once the line is
## gone, `remembered_lip` stands in for it.
static func measure(world: Node3D, spider: Node3D, rig: Node3D, remembered_lip: Variant = null) -> Dictionary:
	var cam: Camera3D = rig.camera
	var space := world.get_world_3d().direct_space_state
	var size := cam.get_viewport().get_visible_rect().size
	if size.x < 1.0 or size.y < 1.0:
		size = Vector2(1280.0, 720.0)
	var out := {}
	out["boom"] = rig.boom_length
	out["cam_distance"] = cam.position.z
	out["auto_pitch_deg"] = rad_to_deg(rig.auto_pitch)
	out["view_yaw_deg"] = rad_to_deg(rig.view_yaw())
	out["yaw_assist_deg"] = rad_to_deg(rig.yaw_assist)
	var body := spider.get_node_or_null("Body") as Node3D
	var drawn := body != null and body.visible
	out["body_drawn"] = drawn
	var xform: Transform3D = spider.get_global_transform_interpolated()
	var seen := 0
	for p in BODY_POINTS:
		var w := xform * p
		if _in_frame(cam, size, w) and not _occluded(space, cam, w):
			seen += 1
	out["body_seen"] = seen
	out["spider_visible"] = drawn and seen >= BODY_POINTS_NEEDED
	var centre := xform.origin
	var d := maxf(cam.global_position.distance_to(centre), 0.05)
	out["spider_frac"] = 1.0 / (2.0 * d * tan(deg_to_rad(cam.fov) * 0.5))
	var t: RefCounted = spider.tether
	out["line_active"] = t.is_active()
	var lip: Variant = remembered_lip
	if t.is_active():
		lip = t.bend_point if t.has_bend else t.anchor_point + t.anchor_normal * 0.04
		var corners: PackedVector3Array = t.points(spider.line_end_point())
		out["line_visible"] = _visible_fraction(space, cam, size, corners, 0)
		out["span_visible"] = _visible_fraction(space, cam, size, corners, corners.size() - 2)
	else:
		out["line_visible"] = 0.0
		out["span_visible"] = 0.0
	if lip is Vector3:
		out["lip"] = lip
		out["lip_in_frame"] = _in_frame(cam, size, lip)
		out["lip_occluded"] = _occluded(space, cam, lip)
	else:
		out["lip"] = Vector3.ZERO
		out["lip_in_frame"] = false
		out["lip_occluded"] = false
	var near := 0
	var mid := 0
	for ix in GRID_X:
		for iy in GRID_Y:
			var p := Vector2((float(ix) + 0.5) / float(GRID_X) * size.x, (float(iy) + 0.5) / float(GRID_Y) * size.y)
			var dir := cam.project_ray_normal(p)
			var from := cam.global_position
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * MID_DISTANCE, Layers.WORLD))
			if not hit.is_empty():
				mid += 1
				if from.distance_to(hit["position"]) < NEAR_DISTANCE:
					near += 1
	out["near_cover"] = float(near) / float(GRID_X * GRID_Y)
	out["mid_cover"] = float(mid) / float(GRID_X * GRID_Y)
	# The floor under the spider: what lowering would reach, or a let-go would fall to.
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(centre, centre + Vector3.DOWN * 40.0, Layers.WORLD))
	out["floor_visible"] = not down.is_empty() and _in_frame(cam, size, down["position"] + Vector3.UP * 0.05) and not _occluded(space, cam, down["position"] + Vector3.UP * 0.05)
	return out


## The reasons a sample is crowded (empty when it is not). While the line is out the recovery choices need the
## spider, the lip it hangs from and the line between them; after the grab only the spider and a clear view.
static func crowded_reasons(m: Dictionary) -> PackedStringArray:
	var why := PackedStringArray()
	if not m["spider_visible"]:
		why.append("spider hidden")
	if m["spider_frac"] > CLOSE_FRACTION:
		why.append("too close")
	if m["near_cover"] > COVER_MAX:
		why.append("geometry")
	if m["line_active"]:
		if not m["lip_in_frame"] or m["lip_occluded"]:
			why.append("lip hidden")
		if m["span_visible"] < SPAN_MIN:
			why.append("line hidden")
	return why


static func _in_frame(cam: Camera3D, size: Vector2, p: Vector3) -> bool:
	if cam.is_position_behind(p):
		return false
	var s := cam.unproject_position(p)
	return s.x >= size.x * FRAME_MARGIN and s.x <= size.x * (1.0 - FRAME_MARGIN) and s.y >= size.y * FRAME_MARGIN and s.y <= size.y * (1.0 - FRAME_MARGIN)


static func _occluded(space: PhysicsDirectSpaceState3D, cam: Camera3D, p: Vector3) -> bool:
	var from := cam.global_position
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, p, Layers.WORLD))
	return not hit.is_empty() and from.distance_to(hit["position"]) < from.distance_to(p) - OCCLUSION_TOLERANCE


## The share of evenly spaced points along the polyline's spans from `first_span` on that are in frame and not hidden.
static func _visible_fraction(space: PhysicsDirectSpaceState3D, cam: Camera3D, size: Vector2, corners: PackedVector3Array, first_span: int) -> float:
	var total := 0.0
	for i in range(first_span, corners.size() - 1):
		total += corners[i].distance_to(corners[i + 1])
	if total < 1e-4:
		return 0.0
	var seen := 0
	for k in LINE_SAMPLES:
		var want := (float(k) + 0.5) / float(LINE_SAMPLES) * total
		var walked := 0.0
		var p := corners[corners.size() - 1]
		for i in range(first_span, corners.size() - 1):
			var span := corners[i].distance_to(corners[i + 1])
			if walked + span >= want or i == corners.size() - 2:
				p = corners[i].lerp(corners[i + 1], clampf((want - walked) / maxf(span, 1e-6), 0.0, 1.0))
				break
			walked += span
		if _in_frame(cam, size, p) and not _occluded(space, cam, p):
			seen += 1
	return float(seen) / float(LINE_SAMPLES)
