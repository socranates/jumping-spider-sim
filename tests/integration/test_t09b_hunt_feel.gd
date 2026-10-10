extends "res://tests/prey_test_case.gd"
## T09b, the feel of the hunt (Nathan, 2026-10-10: "twitchy movements typical of jumping spiders"; "the fly should look to and fro while you
## slowly creep"; "tap the button as the prey struggles ... a bar that depletes when you stop tapping"; hunts "deliberately slow and
## challenging"), and the windowsill's leaf tip that gives way so the silk can catch a miss in the habitat.
##   * a perched fly glances to and fro, alternately each side of the way it settled, from its own seeded stream;
##   * the spider's model twitches (snap turns, stop-and-dart lurches, idle flicks) within set limits, the physics body never sees it, and
##     "Reduced motion" turns it off;
##   * a caught fly struggles: the grip bar drains and each jerk knocks some off; presses fill it; let it run out and the fly tears free,
##     its capture undone and nothing eaten; hold on and it is subdued and can be eaten; holding the button down does nothing on its own;
##     "Struggling prey: automatic" holds on with no presses;
##   * the dry leaf tip past the east leaf gives way when a jump is aimed at it, the line catches the spider, reeling brings it back, the tip
##     returns, and a checkpoint keeps it down.

const Checkpoint = preload("res://scripts/persistence/checkpoint.gd")
const SpiderBody = preload("res://scripts/presentation/spider_body.gd")


func after_each() -> void:
	Input.action_release("interact")
	super.after_each()


# ------------------------------------------------------------------ the fly's glances

func test_a_perched_fly_glances_to_and_fro_from_its_own_stream() -> void:
	var angles := []
	for run in 2:
		await spawn_prey_world(floor_pose(-20.0, 12.0, -90.0))
		director().stimulus_enabled = false   # nothing to be afraid of: only its own rest behaviour
		var f := add_fly("floor_east_open", 7)
		var home: Vector3 = f.heading
		var widest := [0.0]   # a list: a lambda gets a copy of a plain local
		await run_ticks(60 * 12, func() -> void: widest[0] = maxf(float(widest[0]), rad_to_deg(home.angle_to(f.heading))))
		var mine := []
		for e: Dictionary in f.events:
			if str(e["kind"]) == "glance":
				mine.append(snappedf(float(e["angle"]), 0.001))
		angles.append(mine)
		if run == 0:
			check(mine.size() >= 5, "it glanced %d times in 12 s" % mine.size())
			var alternating := true
			for i in range(1, mine.size()):
				alternating = alternating and signf(float(mine[i])) != signf(float(mine[i - 1]))
			check(alternating, "alternately to each side: %s" % str(mine))
			for a: float in mine:
				check(absf(a) >= 45.0 - 1e-3 and absf(a) <= 135.0 + 1e-3, "each glance is 45 to 135 degrees off its settled facing (%.0f)" % a)
			check(float(widest[0]) > 60.0, "so at times it faces well away from where it settled (%.0f degrees)" % float(widest[0]))
		world.queue_free()
		await physics_frames(2)
	check_eq(angles[0], angles[1], "the same seed glances the same way")


# ------------------------------------------------------------------ the spider's twitch

func _walk_figure(turns: int) -> Array:
	var spider: Node3D = world.spider
	var body: Node3D = spider.get_node("Body")
	var worst := {"yaw": 0.0, "offset": 0.0, "moved": 0.0}
	for i in turns * 30:
		var a := deg_to_rad(float(i) * 6.0)
		spider.set_intent(Vector3(sin(a), 0.0, -cos(a)), false)
		await physics_frames(1)
		worst["yaw"] = maxf(float(worst["yaw"]), absf(body.twitch_yaw))
		worst["offset"] = maxf(float(worst["offset"]), body.twitch_offset.length())
		worst["moved"] = maxf(float(worst["moved"]), body.position.length())
	spider.set_intent(Vector3.ZERO, false)
	await physics_frames(2)
	return [worst, spider.global_position, spider.get_heading_vector()]


func test_the_twitch_is_looks_only_bounded_and_can_be_turned_off() -> void:
	await spawn_prey_world(floor_pose(-10.0, 0.0, 0.0))
	var lively: Array = await _walk_figure(4)
	var worst: Dictionary = lively[0]
	check(float(worst["yaw"]) > deg_to_rad(3.0), "the model turns in snaps, lagging the body for a moment (%.1f degrees at most)" % rad_to_deg(float(worst["yaw"])))
	check(float(worst["yaw"]) <= deg_to_rad(SpiderBody.SNAP_DEG + SpiderBody.JOLT_DEG + 1.0), "never more than the snap limit (%.1f)" % rad_to_deg(float(worst["yaw"])))
	check(float(worst["offset"]) > 0.02, "and walks in lurches (%.3f WU)" % float(worst["offset"]))
	check(float(worst["offset"]) <= SpiderBody.TWITCH_MAX_WU + 1e-6, "within %.2f WU of the body" % SpiderBody.TWITCH_MAX_WU)
	world.queue_free()
	await physics_frames(2)
	settings.set_value("reduced_motion", true)
	await spawn_prey_world(floor_pose(-10.0, 0.0, 0.0))
	var calm: Array = await _walk_figure(4)
	check_eq(float(calm[0]["moved"]), 0.0, "Reduced motion: the model keeps still on the body")
	check_vec_near(calm[1], lively[1], 1e-5, "the physics body walked exactly the same path either way")
	check_vec_near(calm[2], lively[2], 1e-5, "and ended facing the same way")


# ------------------------------------------------------------------ the struggle

func _caught() -> Node3D:
	prey_struggle = true
	var f := await catch_a_fly()
	world.feeding.interactive = true
	return f


func _tap() -> void:
	Input.action_press("interact")
	await physics_frames(1)
	Input.action_release("interact")


func test_tapping_keeps_the_grip_until_the_fly_is_subdued() -> void:
	var f := await _caught()
	var fc: Node = world.feeding
	if not check(director().held == f and fc.struggling, "the caught fly struggles"):
		return
	check(not fc.request_feed() and fc.last_refusal == "struggling", "it cannot be eaten while it struggles")
	check_eq(str(fc.prompt()["title"]), "IT STRUGGLES!", "the screen says so, with the grip bar")
	var lowest := 1.0
	for i in 400:
		if not fc.struggling:
			break
		if i % 24 == 0:
			await _tap()   # two and a half presses a second
		else:
			await physics_frames(1)
		if fc.struggling:
			lowest = minf(lowest, fc.grip)
	check(not fc.struggling and director().held == f, "held on: the fly is subdued and still in the jaws")
	check(lowest > 0.0, "the grip never ran out (lowest %.2f)" % lowest)
	check(fc.struggle_log.has("subdued"), "the log says subdued")
	check(fc.request_feed(), "now it can be eaten")


func test_stop_tapping_and_the_grip_runs_out_and_the_fly_tears_free() -> void:
	var f := await _caught()
	var fc: Node = world.feeding
	var event_id: String = f.capture_event_id
	var seen_grip := [1.0]
	await wait_until(func() -> bool:
		seen_grip[0] = minf(float(seen_grip[0]), fc.grip)
		return not fc.struggling, 300)
	check(director().held == null, "with no presses the grip ran out: the jaws are empty")
	check(f.is_alive() and f.is_flying(), "the fly is free and flying (%s)" % f.state_name())
	check_eq(director().capture_log.size(), 0, "its capture is undone")
	check(not director()._event_ids.has(event_id), "so it can be caught again")
	check_eq(director().escape_log.size(), 1, "and the escape is logged")
	check_near(world.needs.granted_total, 0.0, 1e-12, "nothing was eaten of it")
	check_near(f.nutrition_left, f.nutrition_total, 1e-12, "it keeps all its nutrition")
	await run_ticks(60 * 5)
	check(f.is_alive(), "five seconds on it is still alive (%s)" % f.state_name())


func test_holding_the_button_down_is_not_a_grip() -> void:
	await _caught()
	var fc: Node = world.feeding
	Input.action_press("interact")
	await wait_until(func() -> bool: return not fc.struggling, 300)
	Input.action_release("interact")
	check(director().held == null, "a held button counts once: the fly still tore free")


func test_automatic_struggle_holds_on_with_no_presses() -> void:
	settings.set_value("struggle_auto", true)
	var f := await _caught()
	var fc: Node = world.feeding
	check(fc.struggle_auto, "the setting reached the jaws")
	await wait_until(func() -> bool: return not fc.struggling, 300)
	check(director().held == f, "held on with no presses at all")
	check(fc.prompt().get("hint", "") != "", "the screen had said it holds on by itself")


# ------------------------------------------------------------------ the leaf tip that gives way

func _on_east_leaf() -> void:
	use_windowsill = true
	await spawn_prey_world(Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(23.6, 5.71, -3.0)))


func _jump_at_tip() -> bool:
	var spider: Node3D = world.spider
	var plan = spider.plan_jump(ray_target(Vector3(27.0, 7.0, -3.0), Vector3(27.0, 4.0, -3.0)))
	if not check(plan.is_valid() and plan.target_surface_id == "leaf_tip", "the leaf tip looks like a landing: %s" % plan.reason):
		return false
	spider.begin_prepare()
	await physics_frames(2)
	return check(spider.commit_jump(plan), "the jump is launched")


func test_the_dry_leaf_tip_gives_way_and_the_silk_catches_the_spider() -> void:
	await _on_east_leaf()
	check(world.lab.is_piece_enabled("leaf_tip"), "the tip is there")
	if not await _jump_at_tip():
		return
	check(not world.lab.is_piece_enabled("leaf_tip"), "it gives way as the jump is made")
	await wait_until(func() -> bool: return world.spider.is_hanging(), 240)
	check(world.spider.is_on_line(), "the line from the east leaf caught the spider (%s)" % world.spider.get_state_name())
	check(world.spider.global_position.y > 1.0, "it hangs above the sill, not on it (y %.2f)" % world.spider.global_position.y)
	world.spider.set_reel_intent(1.0)
	await wait_until(func() -> bool: return world.spider.state == world.spider.State.ATTACHED, 60 * 20)
	world.spider.set_reel_intent(0.0)
	check_eq(world.spider.get_state_name(), "ATTACHED", "reeling in takes it back to a surface")
	check(world.spider.global_position.y > 3.0, "up by the leaves again (y %.2f)" % world.spider.global_position.y)
	await wait_until(func() -> bool: return world.lab.is_piece_enabled("leaf_tip"), 60 * 12)
	check(world.lab.is_piece_enabled("leaf_tip"), "the tip comes back")


func test_a_checkpoint_keeps_the_fallen_tip_down() -> void:
	await _on_east_leaf()
	if not await _jump_at_tip():
		return
	world.lab.set_physics_process(false)   # hold the tip's return timer for the checkpoint
	await wait_until(func() -> bool: return world.spider.is_hanging(), 240)
	world.spider.teleport_to(floor_pose(-25.0, 6.0, -90.0))
	await settle(world.spider)
	await wait_until(func() -> bool: return not director().strike_active, 300)  # a strike cut short by a teleport times out
	var r: Dictionary = world.save_checkpoint()
	if not check(bool(r["ok"]), "a checkpoint with the tip down: %s" % r["message"]):
		return
	var changes: Array = r["record"]["habitat_changes"]
	check(changes.size() == 1 and str(changes[0]["surface_id"]) == "leaf_tip", "it records the fallen tip: %s" % str(changes))
	var fresh: Node3D = world.return_to_checkpoint()
	world = fresh
	await physics_frames(3)
	check(not world.lab.is_piece_enabled("leaf_tip"), "after loading, the tip is still down")
	await wait_until(func() -> bool: return world.lab.is_piece_enabled("leaf_tip"), 60 * 12)
	check(world.lab.is_piece_enabled("leaf_tip"), "and comes back on its own time")
