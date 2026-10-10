extends "res://tests/world_test_case.gd"
## The convex edge arc tick by tick: from the post's west face over its top edge onto the slab.
## Support must be confirmed on every tick (the edge holds the body during the arc), the body must
## keep its distance from the edge, the normal must turn steadily one way, and the arc must take
## 0.15 to 0.25 s at walking speed. The arc time follows the speed: stalking rounds the same edge
## slowly (about 0.5 to 0.6 s), as the body would walk it.

const SupportMath = preload("res://scripts/movement/support_math.gd")


func test_edge_arc_keeps_support_every_tick() -> void:
	spawn_world(Transform3D(SupportMath.body_basis(Vector3.LEFT, Vector3.UP), Vector3(8.69, 4.3, 7.0)))
	var spider = world.spider
	await physics_frames(5)
	check_eq(spider.support.surface_id, "arch_slab", "starts on the slab's west end, the post's flush face")
	check(spider.get_support_normal().is_equal_approx(Vector3.LEFT), "facing west")
	spider.set_intent(Vector3.UP, false)
	var stale := 0
	var arc_ticks := 0
	var radius_error := 0.0
	var backwards := 0
	var last_n: Vector3 = spider.get_support_normal()
	var edge := Vector3(9.0, 4.6, 0.0)
	for i in 60:
		await physics_frames(1)
		if spider.support.valid_tick != spider.get_physics_tick() or not spider.is_supported():
			stale += 1
		var n: Vector3 = spider.get_support_normal()
		if spider.in_transition():
			arc_ticks += 1
			var p: Vector3 = spider.global_position
			radius_error = maxf(radius_error, absf(Vector2(p.x - edge.x, p.y - edge.y).length() - 0.31))
			if n.y < last_n.y - 1e-6:
				backwards += 1
		last_n = n
	check_eq(stale, 0, "support is confirmed on every tick, including the arc")
	check(arc_ticks >= 9 and arc_ticks <= 15, "the arc takes 0.15 to 0.25 s (%d ticks)" % arc_ticks)
	check(radius_error < 0.05, "the body rounds the edge at about the seat distance (worst error %f)" % radius_error)
	check_eq(backwards, 0, "the normal turns one way only")
	check(spider.get_support_normal().is_equal_approx(Vector3.UP), "ends on the slab top")
	check_near(spider.global_position.y, 4.6 + 0.31, 0.02, "seated on the top")


func test_the_arc_time_follows_the_speed_so_stalking_rounds_an_edge_slowly() -> void:
	spawn_world(Transform3D(SupportMath.body_basis(Vector3.LEFT, Vector3.UP), Vector3(8.69, 4.3, 7.0)))
	var spider = world.spider
	await physics_frames(5)
	spider.set_intent(Vector3.UP, true)  # stalk
	var stale := 0
	var arc_ticks := 0
	var longest_gap := 0.0
	var last: Vector3 = spider.global_position
	for i in 140:
		await physics_frames(1)
		if spider.support.valid_tick != spider.get_physics_tick() or not spider.is_supported():
			stale += 1
		if spider.in_transition():
			arc_ticks += 1
			longest_gap = maxf(longest_gap, spider.global_position.distance_to(last))
		last = spider.global_position
	check_eq(stale, 0, "support is confirmed on every tick of the slow arc too")
	check(arc_ticks >= 28 and arc_ticks <= 38, "a stalking spider takes about 0.5 to 0.6 s round the edge (%d ticks)" % arc_ticks)
	check(longest_gap < 0.05, "the body never lurches during the slow arc, largest step %f WU" % longest_gap)
	check(spider.get_support_normal().is_equal_approx(Vector3.UP), "ends on the slab top")
