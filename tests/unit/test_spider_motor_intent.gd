extends "res://tests/test_case.gd"

const SpiderScene = preload("res://scenes/actors/spider.tscn")


func test_intent_keeps_its_direction_and_is_limited() -> void:
	# Chunk 3 (T02) changed this: the intent is no longer flattened to the horizontal, because the
	# motor projects it onto whatever surface supports the spider.
	var spider := SpiderScene.instantiate()
	spider.set_intent(Vector3(3.0, 7.0, 4.0), false)
	var i: Vector3 = spider.get_intent()
	check_near(i.length(), 1.0, 1e-6, "length limited to 1")
	check(i.normalized().is_equal_approx(Vector3(3.0, 7.0, 4.0).normalized()), "direction kept, vertical part included")
	spider.set_intent(Vector3(0.3, 0.0, 0.0), true)
	check_near(spider.get_intent().length(), 0.3, 1e-6, "a partial stick keeps its magnitude")
	check(spider.is_stalking(), "stalk flag stored")
	spider.set_intent(Vector3(NAN, 0.0, 1.0), false)
	check_eq(spider.get_intent(), Vector3.ZERO, "a non-finite intent becomes zero")
	spider.free()


func test_states_are_the_t04_subset_of_spec_6_2() -> void:
	# T03 added PREPARING and AIRBORNE at the end, T04 HANGING and REELING; FEEDING and RESTING come later.
	var spider := SpiderScene.instantiate()
	check_eq(spider.State.keys(), ["ATTACHED", "FALLING", "LANDING", "PREPARING", "AIRBORNE", "HANGING", "REELING"], "state names follow spec 6.2 (T04 adds HANGING and REELING)")
	spider.free()


func test_collider_is_a_sphere_of_radius_0_3() -> void:
	var spider := SpiderScene.instantiate()
	var shape := (spider.get_node("Collider") as CollisionShape3D).shape
	check(shape is SphereShape3D, "sphere collider")
	check_near((shape as SphereShape3D).radius, 0.3, 1e-6, "radius")
	spider.free()
