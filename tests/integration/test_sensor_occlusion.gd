extends "res://tests/sensor_rig_case.gd"
## The sensor's line of sight against small things (A-024, chunk 7A). A ray the world stops short of a sample point has not seen it; the
## only allowance is the one PerceptionMath.sight_tolerance gives (a tenth of the thing's radius and the float error of the cast), so a
## speck wholly behind a thin barrier is never sensed, while a speck part of which is in view still is, an open one is refined as
## before, a thing resting against a surface keeps the points that lie in the surface's skin, and the memory of a place behind the
## barrier is never called empty. Chunk 6B allowed a flat 0.05 WU, which let a barrier 0.03 WU in front of a speck 0.02 WU across hide
## all of it and still count as seen (Chet's review 3).

const PerceptionMath = preload("res://scripts/perception/perception_math.gd")

## Chet's arrangement, in the observer's own frame (the eye at the origin, gaze along -Z).
const BARRIER_AT := Vector3(0.0, 0.0, -0.97)
const BARRIER_SIZE := Vector3(0.2, 0.2, 0.02)
const SPECK_AT := Vector3(0.0, 0.0, -1.0)
const SPECK_RADIUS := 0.01


func _visible_points(id: String) -> int:
	var t: Variant = sensor.get_track(id)
	return -1 if t == null else int(t.last_check.get("visible_points", -1))


func test_a_speck_wholly_behind_a_thin_barrier_is_not_sensed() -> void:
	rig()
	add_wall(BARRIER_AT, BARRIER_SIZE)
	var speck := add_ball("speck", SPECK_AT, SPECK_RADIUS)
	await run(3)
	var hit := first_hit(Vector3.ZERO, SPECK_AT)
	if check(not hit.is_empty(), "the barrier is in the world"):
		check_near((hit["position"] as Vector3).length(), 0.96, 1e-3, "the ray to the speck meets the barrier 0.96 WU out, 0.04 WU short of the speck")
	var gap := SPECK_AT.length() - 0.96
	check(gap > 3.0 * PerceptionMath.sight_tolerance(SPECK_RADIUS, 1.0), "that is %.3f WU short, far more than the allowance of %.4f" % [gap, PerceptionMath.sight_tolerance(SPECK_RADIUS, 1.0)])
	await run(60)
	check_eq(memory.count(), 0, "a full second on: the speck was not sensed (it was, with 5 visible points, before the fix)")
	check_eq(sensor.inspections_made, 0, "not inspected")
	check_eq(sensor.cues_made, 0, "and no cue")
	check_eq(_visible_points("speck"), 0, "none of its five sample points was seen")
	check(speck.position.is_equal_approx(SPECK_AT), "it stood where the arrangement put it")


func test_the_same_speck_with_the_barrier_taken_away_is_sensed_and_refined() -> void:
	rig()
	var wall := add_wall(BARRIER_AT, BARRIER_SIZE, true)
	var speck := add_ball("speck", SPECK_AT, SPECK_RADIUS)
	await run(30)
	check_eq(memory.count(), 0, "hidden while the barrier stands")
	set_wall(wall, false)
	await run(100)
	var c := contact_of_ball(speck)
	if not check(c != null and c.is_inspected_now(), "with the barrier gone it is inspected"):
		return
	check_eq(_visible_points("speck"), 5, "all five sample points are in view")
	check_vec_near(c.position, SPECK_AT, 0.02, "at the place it stands")
	check_eq(c.category, Observation.POSSIBLE_PREY, "after 1.6 s it is refined to possible prey (a speck needs 2.6 times as long as an easy target)")
	await run(110)
	check_eq(c.category, Observation.FLY_LIKE_PREY, "and after 3.4 s to fly-like prey, as before the fix")


func test_a_speck_partly_in_view_is_sensed_from_the_points_that_are() -> void:
	rig()
	# The barrier ends at x = 0.004: the sample on the +x side of the speck (x = 0.008) is in view past its edge, the other four are behind it.
	add_wall(Vector3(-0.098, 0.0, -0.97), Vector3(0.204, 0.2, 0.02))
	var speck := add_ball("speck", SPECK_AT, SPECK_RADIUS)
	await run(40)
	check_eq(_visible_points("speck"), 1, "one of the five sample points is in view")
	var c := contact_of_ball(speck)
	if not check(c != null and c.is_inspected_now(), "so it is inspected, from what can be seen"):
		return
	check(c.position.distance_to(SPECK_AT) <= 0.01, "its place is the visible point's, within the speck: %.4f WU off" % c.position.distance_to(SPECK_AT))
	check(c.confidence < 0.5, "with less confidence than a full view (%.2f)" % c.confidence)


func test_what_is_hidden_does_not_flicker_at_the_edge_of_a_barrier() -> void:
	# Slide a speck's whole body behind the barrier's edge, a hair at a time: the number of visible points never rises as it goes in.
	rig()
	add_wall(Vector3(-0.098, 0.0, -0.97), Vector3(0.204, 0.2, 0.02))
	var speck := add_ball("speck", Vector3(0.05, 0.0, -1.0), SPECK_RADIUS)
	var last := 99
	var rose := 0
	for step in 24:
		speck.position.x = 0.05 - 0.0025 * float(step)
		await run(2)
		var now := _visible_points("speck")
		if now > last:
			rose += 1
		last = now
	check_eq(rose, 0, "going behind the barrier the visible points only fall")
	check_eq(last, 0, "and at the end none of them is seen (x = %.3f)" % speck.position.x)


func test_a_speck_wholly_behind_a_barrier_is_hidden_whatever_its_size() -> void:
	# The sphere stands just behind a barrier 0.02 thick, at every size from a speck to a ball 0.4 WU across: none of it is in view.
	for radius in [0.005, 0.01, 0.02, 0.03, 0.05, 0.1, 0.2]:
		rig()
		add_wall(Vector3(0.0, 0.0, -0.97), Vector3(1.0, 1.0, 0.02))
		var ball := add_ball("ball", Vector3(0.0, 0.0, -0.98 - float(radius) - 0.001), float(radius))
		await run(20)
		check_eq(_visible_points("ball"), 0, "radius %s: none of its points is in view" % str(radius))
		check_eq(memory.count(), 0, "radius %s: nothing was sensed" % str(radius))
		check(contact_of_ball(ball) == null, "radius %s: it has no contact" % str(radius))
	clear_rig()


func test_a_thing_resting_in_a_surface_keeps_the_points_in_the_surfaces_skin() -> void:
	# An ordinary thing (the 0.9 WU test marker) resting against a wall: its sample points lie a little inside the wall's face. Up to a
	# tenth of its radius in, they still count as seen, as before; further in, they are behind the wall.
	rig()
	add_wall(Vector3(0.0, 0.0, -2.05), Vector3(6.0, 6.0, 0.1))   # front face at z = -2.0
	var ball := add_ball("marker", Vector3(0.0, 0.0, -2.0), 0.45)
	for inside in [0.0, 0.01, 0.03, 0.04]:
		ball.position.z = -2.0 - inside
		await run(6)
		check_eq(_visible_points("marker"), 5, "%.2f WU inside the face: all five points are seen" % inside)
	for inside in [0.06, 0.08, 0.2]:
		ball.position.z = -2.0 - inside
		await run(6)
		check_eq(_visible_points("marker"), 0, "%.2f WU inside the face: none is seen" % inside)


func test_a_thing_resting_in_a_surface_is_not_lost_and_found_again_by_chance() -> void:
	rig()
	add_wall(Vector3(0.0, 0.0, -2.05), Vector3(6.0, 6.0, 0.1))
	var ball := add_ball("marker", Vector3(0.0, 0.0, -2.03), 0.45)
	var lost := [0]
	memory.contact_lost.connect(func(_c: ObservationMemory.Contact) -> void: lost[0] += 1)
	await run(180)
	var c := contact_of_ball(ball)
	check(c != null and c.is_inspected_now(), "it is inspected the whole time")
	check_eq(lost[0], 0, "and never lost: the same arrangement gives the same answer every tick")
	check_eq(memory.count(), 1, "one contact")
	check_eq(c.category, Observation.FLY_LIKE_PREY, "which has been refined as an open one would be")


func test_a_spot_behind_the_barrier_is_not_called_empty() -> void:
	# A speck is seen and classified, the barrier goes up in front of it, and the speck goes away. Looking at a barrier does not show that
	# the place behind it is empty: the mark stays until the memory lets go of it (6 s), as it would for any hidden place.
	rig()
	var wall := add_wall(BARRIER_AT, BARRIER_SIZE, false)
	var speck := add_ball("speck", SPECK_AT, SPECK_RADIUS)
	await run(200)
	var c := contact_of_ball(speck)
	if not check(c != null and c.category == Observation.FLY_LIKE_PREY, "the speck was refined to fly-like prey in plain view"):
		return
	set_wall(wall, true)
	await run(20)
	check(not c.is_live() and c.has_mark(), "behind the barrier it is lost, with a mark")
	speck.enabled = false
	await run(240)
	check(c.has_mark(), "four seconds on, the place behind the barrier has not been called empty")
	check_eq(ended.size(), 0, "nothing ended the contact")
	await run(180)
	check_eq(ended, ["%s:expired" % c.track_id] as Array[String], "it went when the memory did: expired, not empty")


func test_the_same_spot_in_plain_view_is_called_empty() -> void:
	# The control of the test above: with no barrier, looking at the spot for the time an easy target needs shows that nothing is there.
	rig()
	var speck := add_ball("speck", SPECK_AT, SPECK_RADIUS)
	await run(200)
	var c := contact_of_ball(speck)
	if not check(c != null and c.category == Observation.FLY_LIKE_PREY, "the speck was refined to fly-like prey in plain view"):
		return
	speck.enabled = false
	await run(20)
	check(c.has_mark(), "taken away, it is lost with a mark")
	await run(60)
	check_eq(memory.marks().size(), 0, "after looking at the empty spot, the mark is gone")
	check_eq(ended, ["%s:empty" % c.track_id] as Array[String], "because the spot was empty")
