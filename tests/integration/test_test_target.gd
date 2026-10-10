extends "res://tests/perception_test_case.gd"
## The test target (A-010): a marker that stands in for prey so that the senses can be shown working. It is plainly labelled,
## it is not a fly, it has no senses and no goals, it walks a path to and fro, goes behind the screen and comes out again, and a
## fixture can take it out of the world, hold it still, put it somewhere else and let it go.

const TestTarget = preload("res://scripts/habitat/test_target.gd")
const Perceivable = preload("res://scripts/perception/perceivable.gd")


func test_the_stage_carries_a_sign_that_says_what_the_marker_is() -> void:
	spawn_world(ledge_pose(), false)
	var sign_label: Label3D = world.lab.get_node("Stage/Sign")
	check_eq(sign_label.text, TestTarget.SIGN_TEXT, "the sign carries the marker's own words")
	check(sign_label.text.find("TEST TARGET") >= 0, "it says TEST TARGET")
	check(sign_label.text.find("not a fly") >= 0, "and that it is not a fly")
	check(sign_label.text.find("watch it from the ledge") >= 0, "and where to watch it from")
	check(target().get_parent().name == "Stage", "the marker stands on the stage")


func test_it_has_no_senses_no_goals_and_does_not_react_to_the_spider() -> void:
	spawn_world(ledge_pose(), false)
	for child in target().get_children():
		check(child is MeshInstance3D, "a part of the marker is only drawn: %s" % child.name)
	world.free()
	var near := await path_of_the_marker(ledge_pose(), 240)
	world.free()
	var far := await path_of_the_marker(Transform3D(Basis(Vector3.UP, 1.0), Vector3(12.0, 0.31, 6.0)), 240)
	check_eq(near.size(), far.size(), "the same number of samples")
	var same := true
	for i in near.size():
		if (near[i] as Vector3).distance_to(far[i]) > 1e-9:
			same = false
	check(same, "it walks exactly the same path with the spider on the ledge or on the far side of the lab")


func path_of_the_marker(pose: Transform3D, ticks: int) -> Array[Vector3]:
	spawn_world(pose, false)
	var out: Array[Vector3] = []
	for i in ticks:
		await physics_frames(1)
		out.append(target().global_position)
	return out


func test_it_walks_its_path_to_and_fro_pauses_at_the_ends_and_passes_behind_the_screen() -> void:
	await spawn_stage(false, 0.0, null)
	var xs: Array[float] = []
	var hidden_run := 0
	var longest_hidden := 0
	var hidden_at_the_start := true
	var still_run := 0
	var longest_still := 0
	var first := true
	for i in 800:
		await physics_frames(1)
		xs.append(target().global_position.x)
		var hidden := target_is_hidden()
		if first:
			hidden_at_the_start = hidden
			first = false
		hidden_run = hidden_run + 1 if hidden else 0
		longest_hidden = maxi(longest_hidden, hidden_run)
		still_run = still_run + 1 if target().velocity.length() < 1e-9 else 0
		longest_still = maxi(longest_still, still_run)
	check(not hidden_at_the_start, "it starts in plain view")
	check(longest_hidden >= 100, "it passes behind the screen: hidden for %d ticks in a row (%.1f s)" % [longest_hidden, longest_hidden / 60.0])
	check(xs[0] < -27.5 and xs[0] > -28.9, "it starts at the west end of the path (%.2f)" % xs[0])
	check_near(xs.max(), -20.2, 0.05, "walks to the east end")
	check(longest_still >= 70, "and stops a moment at an end (%d ticks)" % longest_still)
	check(not target_is_hidden(), "and it is in plain view again")
	var speed := 0.0
	for i in range(1, xs.size()):
		speed = maxf(speed, absf(xs[i] - xs[i - 1]) * 60.0)
	check_near(speed, TestTarget.DEFAULT_SPEED, 0.01, "at a steady walking pace (%.2f WU/s)" % speed)


func test_a_fixture_can_remove_hold_move_and_release_it() -> void:
	await spawn_stage(false, 0.0, null)
	var t := target()
	check(t.is_in_group(Perceivable.GROUP), "it is perceivable")
	var p: Dictionary = t.get_percept()
	check_eq(str(p["id"]), TARGET_ID, "it has its id")
	check_near(float(p["radius"]), t.radius, 1e-9, "and its size")
	check_eq(p["max_category"], Observation.FLY_LIKE_PREY, "and the finest thing it can be taken for")
	# Held where a fixture puts it.
	var spot := Vector3(-27.0, 1.4, -7.9)
	t.hold_at(spot)
	await physics_frames(60)
	check_vec_near(t.global_position, spot, 1e-9, "held, it stays where it was put")
	check_vec_near(t.get_percept()["position"], spot, 1e-9, "and its percept says so")
	check_near(t.get_percept()["velocity"].length(), 0.0, 1e-9, "at rest")
	# Taken out of the world.
	t.set_enabled(false)
	check(t.get_percept().is_empty(), "taken out of the world it has no percept")
	check(not t.visible, "and is not drawn")
	await physics_frames(30)
	check_vec_near(t.global_position, spot, 1e-9, "and does not move")
	t.set_enabled(true)
	check(not t.get_percept().is_empty() and t.visible, "put back, it is there again")
	# Let go, it walks again from where it stands.
	t.release()
	await physics_frames(120)
	check(t.global_position.distance_to(spot) > 1.0, "released, it walks on (%.1f WU)" % t.global_position.distance_to(spot))
	check(t.get_percept()["velocity"].length() > 0.5, "and its percept carries its velocity")
	# A new path puts it at the start of it, walking, even if it was held.
	t.hold_at(spot)
	t.set_path(PackedVector3Array([Vector3(-21.0, 1.4, -7.9), Vector3(-19.0, 1.4, -7.9)]))
	check_vec_near(t.global_position, Vector3(-21.0, 1.4, -7.9), 1e-9, "a new path starts at its first point")
	await physics_frames(90)
	check(t.global_position.x > -21.0 + 0.5, "and it walks it")
