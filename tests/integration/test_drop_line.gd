extends "res://tests/prey_test_case.gd"
## Letting down on a line from anywhere (Nathan, 2026-10-12: "can you add an easy way to lower yourself from anywhere"):
##   * from a leaf top the spider walks to the nearest edge, goes over it and lets itself down on a line anchored to the leaf;
##   * letting itself down it slides past the leaf instead of catching on it, and takes hold of the floor below, where the line stays
##     behind as after any line;
##   * from a wall it lets go at once; on the floor, with nothing below, it says so and stays put;
##   * reeling in after a drop takes hold of the leaf again;
##   * the button: F / D-pad down lets it down, held on the line it lowers, cancel or the stick stops a walk to the edge; both can be
##     changed and the screen names them.

const SpiderMotor = preload("res://scripts/movement/spider_motor.gd")
const KeyNames = preload("res://scripts/presentation/key_names.gd")
const JumpFeedback = preload("res://scripts/presentation/jump_feedback.gd")

## On the middle leaf's top (x -4..2, z -4..1, top 4.2), a metre short of its south edge, facing it (+Z).
const LEAF_POSE := Transform3D(Basis(Vector3.UP, deg_to_rad(180.0)), Vector3(-1.0, 4.51, 0.0))
const LEAF_TOP := 4.2


func _sill(pose: Transform3D, interactive: bool = false) -> void:
	use_windowsill = true
	await spawn_prey_world(pose, 0, PREY_SEED, interactive)
	await wait_until(func() -> bool: return world.spider.state == world.spider.State.ATTACHED, 60)


func _events(spider: Node3D) -> Array[String]:
	var out: Array[String] = []
	spider.line_event.connect(func(kind: String, detail: String) -> void: out.append(kind if detail == "" else "%s:%s" % [kind, detail]))
	return out


## Lowers (as holding the button does) until the spider stands on something again, or max_ticks pass.
func _lower_to_ground(spider: Node3D, max_ticks: int = 60 * 12) -> bool:
	if not await wait_until(func() -> bool: return spider.is_on_line(), 60 * 5):
		return false  # it never got onto its line (a walk to the edge that did not arrive)
	return await wait_until(func() -> bool:
		if spider.is_on_line():
			spider.set_reel_intent(-1.0)
		return spider.state == spider.State.ATTACHED and not spider.tether.is_active(), max_ticks)


func test_from_a_leaf_it_walks_to_the_edge_and_lets_itself_down() -> void:
	await _sill(LEAF_POSE)
	var spider: Node3D = world.spider
	check_eq(spider.support.surface_id, "leaf_middle", "standing on the middle leaf")
	var events := _events(spider)
	var plan: Dictionary = spider.plan_drop()
	check(plan["ok"], "a drop is possible from a leaf: %s" % plan["reason"])
	check(plan["walk_dir"].dot(Vector3.BACK) > 0.95, "toward the edge it faces, the nearest: %s" % plan["walk_dir"])
	check_near(float(plan["walk_distance"]), 1.0, 0.11, "a metre off")
	check(float(plan["fall"]) > 3.0, "with the floor far below: %.2f" % float(plan["fall"]))
	check(spider.begin_drop()["ok"] and spider.is_drop_walking(), "it sets off for the edge")
	check(events.has("drop_walk"), "and says so")
	check(await wait_until(func() -> bool: return spider.is_on_line(), 120), "over the edge, it lets go on its line")
	check(events.has("dropped:leaf_middle"), "anchored to the leaf it left: %s" % ", ".join(events))
	check(spider.tether.lowering, "letting itself down, not caught after a miss")
	check(spider.tether.anchor_point.y > LEAF_TOP - 0.45 and spider.tether.anchor_point.z > 0.9, "anchored at the leaf's edge: %s" % spider.tether.anchor_point)
	check(await wait_until(func() -> bool: return spider.state == spider.State.HANGING, 60), "the line takes its weight")
	await physics_frames(60)
	check_eq(spider.get_state_name(), "HANGING", "it hangs, and does not catch on the leaf it brushes")
	check(spider.global_position.y < LEAF_TOP - 0.3, "below the leaf: %s" % spider.global_position)
	var completed_before: int = spider.completed_lines.size()
	check(await _lower_to_ground(spider), "lowering, it reaches the ground")
	check_eq(spider.support.surface_id, "sill_floor", "and takes hold of the floor")
	check_near(spider.global_position.y, 0.31, 0.03, "standing on it")
	check_eq(spider.completed_lines.size(), completed_before + 1, "the line stays behind, as after any line")
	check(not events.has("caught") or events.find("caught") > events.find("dropped:leaf_middle"), "events in order")
	check_eq(spider.energy_clamps, 0, "no energy from the line")
	check_eq(spider.tether_fallbacks, 0, "and no fallback")


func test_reeling_in_after_a_drop_takes_hold_of_the_leaf_again() -> void:
	await _sill(LEAF_POSE)
	var spider: Node3D = world.spider
	spider.begin_drop()
	check(await wait_until(func() -> bool: return spider.state == spider.State.HANGING, 180), "let down and hanging")
	check(await wait_until(func() -> bool:
		if spider.is_on_line():
			spider.set_reel_intent(1.0)
		return spider.state == spider.State.ATTACHED, 60 * 8), "reeling in, it takes hold again")
	check(str(spider.support.surface_id).begins_with("leaf_middle"), "of the leaf: %s" % spider.support.surface_id)
	check(not spider.tether.is_active(), "and the line stays behind")


func test_from_a_wall_it_lets_go_at_once() -> void:
	# On the back frame, 6 high, head up.
	var on_wall := Transform3D(Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN), Vector3(-8.0, 6.0, -12.5 + 0.31))
	await _sill(on_wall)
	var spider: Node3D = world.spider
	check_eq(spider.support.surface_id, "back_frame", "on the back frame")
	var plan: Dictionary = spider.begin_drop()
	check(plan["ok"] and plan["walk_dir"] == Vector3.ZERO, "it lets go where it is: %s" % plan["reason"])
	check(spider.is_on_line() and spider.tether.lowering, "on its line at once")
	check(await _lower_to_ground(spider), "lowers to the floor")
	check_eq(spider.support.surface_id, "sill_floor", "and stands on it")


func test_on_the_floor_there_is_nothing_below() -> void:
	await _sill(floor_pose(-13.0, 6.0, -90))
	var spider: Node3D = world.spider
	var events := _events(spider)
	var before: Vector3 = spider.global_position
	var plan: Dictionary = spider.begin_drop()
	check(not plan["ok"] and plan["reason"] == "no_edge", "nothing below the floor: %s" % plan["reason"])
	check(events.has("drop_refused:no_edge"), "and it says so")
	check_eq(JumpFeedback.line_toast("drop_refused", "no_edge", false), "Nothing below to let yourself down into from here", "in words")
	await physics_frames(10)
	check(spider.state == spider.State.ATTACHED and spider.global_position.distance_to(before) < 0.01 and not spider.is_drop_walking(), "and stays put")


func test_the_button_lets_it_down_holds_to_lower_and_cancel_stops_the_walk() -> void:
	await _sill(LEAF_POSE, true)
	var spider: Node3D = world.spider
	var tc: Node = world.tether_controller
	tc.drop_pressed()
	await physics_frames(3)
	check(spider.is_drop_walking(), "the button sets it off for the edge")
	tc.cancel_down()
	tc.cancel_up()
	await physics_frames(3)
	check(not spider.is_drop_walking() and spider.state == spider.State.ATTACHED, "cancel stops it on the leaf")
	tc.drop_pressed()
	await physics_frames(3)
	world.controller.stick_override = Vector2(1.0, 0.0)
	await physics_frames(3)
	check(not spider.is_drop_walking(), "pushing the stick takes over")
	world.controller.stick_override = Vector2.ZERO
	await physics_frames(10)
	tc.drop_override = true
	tc.drop_pressed()
	check(await wait_until(func() -> bool: return spider.state == spider.State.ATTACHED and spider.support.surface_id == "sill_floor", 60 * 12), "held, it goes all the way down")
	tc.drop_override = null
	world.habitat_loop.resting = true
	check_eq(tc.drop_blocked(), "resting", "not while resting")
	world.habitat_loop.resting = false


func test_the_button_can_be_changed_and_the_screen_names_it() -> void:
	check(settings.REMAPPABLE.has("drop_line") and settings.PAD_REMAPPABLE.has("drop_line"), "the key and the button can be changed")
	check_eq(settings.get_key("drop_line"), KEY_F, "F by default")
	check_eq(str(settings.pad_name("drop_line")), "D-pad down", "D-pad down on a controller")
	check(KeyNames.apply(JumpFeedback.DROPPED, settings).contains("F / D-pad down"), "the hint names them")


func test_from_every_raised_place_it_reaches_the_floor_and_the_lip_refuses() -> void:
	# [name, pose, expected surface first held, true when a drop is possible]
	var cases := [
		["east leaf", Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(21.5, 5.71, -3.0)), "leaf_east", true],
		["middle of the planter", Transform3D(Basis(Vector3.UP, 0.0), Vector3(10.0, 4.91, -4.0)), "planter_rim", true],
		["west leaf", Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(-15.0, 4.51, -1.5)), "leaf_west", true],
		["under the middle leaf", Transform3D(Basis(Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD), Vector3(0.5, 3.49, -3.0)), "leaf_middle", true],
		["the east stem", Transform3D(Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP), Vector3(22.31, 2.5, -3.0)), "stem_east", true],
		["the front lip", Transform3D(Basis(Vector3.UP, 0.0), Vector3(0.0, 1.01, 12.25)), "front_lip", false],
	]
	for c: Array in cases:
		await _sill(c[1])
		var spider: Node3D = world.spider
		check_eq(spider.support.surface_id, c[2], "%s: standing there" % c[0])
		var plan: Dictionary = spider.begin_drop()
		if not bool(c[3]):
			check(not plan["ok"] and plan["reason"] == "no_edge", "%s: only a small step or nothing below, so no drop: %s" % [c[0], plan["reason"]])
		elif check(plan["ok"], "%s: a drop: %s" % [c[0], plan["reason"]]):
			check(await _lower_to_ground(spider), "%s: lowered to the ground" % c[0])
			check_eq(spider.support.surface_id, "sill_floor", "%s: on the floor" % c[0])
			check(spider.energy_clamps == 0 and spider.tether_fallbacks == 0, "%s: a clean line" % c[0])
		world.queue_free()
		await physics_frames(2)
