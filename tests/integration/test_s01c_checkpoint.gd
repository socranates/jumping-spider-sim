extends "res://tests/prey_test_case.gd"
## Gate S01-C (DECISIONS A-001, chet-review-1 Q3): creating a retreat checkpoint and loading it restores a consistent supported/resting
## world. Repeated loading does not duplicate prey, energy or scheduled consequences. Loading while airborne, preparing or feeding discards
## the current world and restores the complete checkpoint. The original S01 (exact resume from any state) stays deferred and is not claimed.
## Everything uses the shipped windowsill, the real spider, prey director, feeding and needs; checkpoints are kept in memory here (no file),
## the file store has its own tests (test_s02_checkpoint_store.gd).

const Checkpoint = preload("res://scripts/persistence/checkpoint.gd")
const CheckpointStore = preload("res://scripts/persistence/checkpoint_store.gd")

const HOME := Vector3(-25.0, 0.31, 6.0)


func habitat(pose: Variant = null, count: int = 0, seed_value: int = 4242) -> void:
	use_windowsill = true
	await spawn_prey_world(pose, count, seed_value)


## Rests in the crack the way the player does (the interact press on the habitat loop's tick) and returns the checkpoint it made.
func rest_and_checkpoint() -> Dictionary:
	var loop: Node = world.habitat_loop
	loop.set_physics_process(false)
	loop.step(1.0 / 60.0, true, false)
	loop.set_physics_process(true)
	check(loop.resting, "resting in the crack")
	check(bool(loop.checkpoint_result.get("ok", false)), "the rest made a checkpoint: %s" % str(loop.checkpoint_result.get("message", "")))
	return world.last_checkpoint


## Replaces the world by the checkpoint's and waits until the prey and the spider have been rebuilt. Returns the new world.
func load_checkpoint(record: Dictionary = {}) -> Node3D:
	var fresh: Node3D = world.return_to_checkpoint(record)
	if not check(fresh != null, "the checkpoint loads: %s" % world.last_checkpoint_message):
		return null
	world = fresh
	await wait_until(func() -> bool: return world.prey.ready_done and world.spider.state == world.spider.State.ATTACHED, 60)
	return world


func same(a: Variant, b: Variant) -> bool:
	return CheckpointStore.canonical({"v": a}) == CheckpointStore.canonical({"v": b})


func first_difference(a: Variant, b: Variant, path: String = "") -> String:
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		for k: Variant in a:
			if not (b as Dictionary).has(k):
				return "%s.%s missing" % [path, str(k)]
			var d := first_difference(a[k], b[k], "%s.%s" % [path, str(k)])
			if d != "":
				return d
		return "" if (a as Dictionary).size() == (b as Dictionary).size() else path + " has extra keys"
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if (a as Array).size() != (b as Array).size():
			return "%s size %d vs %d" % [path, (a as Array).size(), (b as Array).size()]
		for i in (a as Array).size():
			var d := first_difference(a[i], b[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	return "" if same(a, b) else "%s: %s vs %s" % [path, str(a), str(b)]


func test_resting_makes_a_checkpoint_that_restores_the_whole_sill() -> void:
	await habitat(floor_pose(HOME.x, HOME.z, -90), 4)
	await run_ticks(240)  # the flies settle in, fidget and groom; the habitat clock runs
	world.needs.configure({"rest": 0.4})
	var rec := await rest_and_checkpoint()
	if not check(not rec.is_empty(), "a checkpoint record exists"):
		return
	check(Checkpoint.validate(rec).is_empty(), "the record passes validation: %s" % "; ".join(Checkpoint.validate(rec)))
	check_eq(str(rec["player"]["retreat_id"]), "sill_crevice", "it is a retreat checkpoint")
	check_eq((rec["prey"]["flies"] as Array).size(), 4, "four living flies recorded")
	var energy := float(rec["needs"]["energy"])
	var prey_now := float(rec["prey"]["now"])
	# The world moves on: the spider walks out, time passes, the flies do what they do.
	await walk_toward(Vector3(-10, 0, 6), false, 0.3, 600)
	await run_ticks(120)
	check(world.prey.now > prey_now + 5.0, "time moved on after the checkpoint")
	await load_checkpoint()
	if world == null:
		return
	check(world.restored, "the world was built from the checkpoint")
	check_vec_near(world.spider.global_position, Checkpoint.RecordMath.to_v3(rec["player"]["position"]), 0.02, "the spider is back where it rested")
	check_eq(world.spider.support.surface_id, str(rec["player"]["surface_id"]), "on the same surface")
	check(world.habitat_loop.resting, "and still resting in the crack")
	var restored: Dictionary = world.prey.restored_record
	var diff := first_difference(rec["prey"], restored)
	check(diff == "", "every fly, perch, capture and the replacement schedule came back exactly (%s)" % diff)
	check_eq(world.prey.living().size(), 4, "four flies, no more")
	check_near(float(world.needs.energy), energy, 1.0e-9, "energy is the checkpoint's")
	check(world.habitat_loop.notice.begins_with("Returned to the checkpoint"), "the screen says this is checkpoint recovery")
	await run_ticks(60)
	check(world.habitat_loop.resting, "the restored rest goes on once the spider has taken hold")
	check(world.needs.rest > float(rec["needs"]["rest"]), "and restores rest")


func test_loading_twice_gives_the_same_world_and_duplicates_nothing() -> void:
	await habitat(floor_pose(HOME.x, HOME.z, -90), 4)
	await run_ticks(180)
	var rec := await rest_and_checkpoint()
	await load_checkpoint()
	if world == null:
		return
	var first: Dictionary = world.prey.restored_record
	var flies_first: int = world.prey.flies.size()
	await run_ticks(90)
	await load_checkpoint()
	if world == null:
		return
	var second: Dictionary = world.prey.restored_record
	check(first_difference(first, second) == "", "the second load is the same world as the first: %s" % first_difference(first, second))
	check_eq(world.prey.flies.size(), flies_first, "no fly was added by loading again")
	check_eq(world.prey.serial_counter, int(rec["prey"]["serial_counter"]), "the id counter is the checkpoint's: no id is reused or skipped")
	check_near(world.needs.granted_total, float(rec["needs"]["granted_total"]), 1.0e-12, "no energy appeared from loading")
	check_eq(world.prey.population.pending.size(), (rec["prey"]["population"]["pending"] as Array).size(), "replacements owed are the checkpoint's, not doubled")


func test_two_restored_worlds_go_on_the_same_way() -> void:
	await habitat(floor_pose(HOME.x, HOME.z, -90), 4)
	await run_ticks(150)
	var rec := await rest_and_checkpoint()
	await load_checkpoint()
	if world == null:
		return
	await run_ticks(240)
	var a: Array = []
	for f in world.prey.flies:
		a.append([f.id, f.state_name(), f.perch.id if f.perch != null else "", f.global_position])
	await load_checkpoint(rec)
	if world == null:
		return
	await run_ticks(240)
	var b: Array = []
	for f in world.prey.flies:
		b.append([f.id, f.state_name(), f.perch.id if f.perch != null else "", f.global_position])
	check_eq(a.size(), b.size(), "the same flies after 4 s")
	for i in mini(a.size(), b.size()):
		check_eq(a[i][0], b[i][0], "fly order")
		check_eq(a[i][1], b[i][1], "%s is doing the same thing" % str(a[i][0]))
		check_eq(a[i][2], b[i][2], "%s is on the same perch" % str(a[i][0]))
		check((a[i][3] as Vector3).distance_to(b[i][3]) < 0.01, "%s is in the same place (%s vs %s)" % [str(a[i][0]), a[i][3], b[i][3]])


func test_loading_while_airborne_or_preparing_discards_the_current_world() -> void:
	await habitat(floor_pose(HOME.x, HOME.z, -90), 2)
	await run_ticks(60)
	var rec := await rest_and_checkpoint()
	await put_spider(-16, 6, -90)
	var plan = world.spider.plan_jump(top_target(-12.0, 6.0))
	if not check(plan.is_valid(), "a jump to make: %s" % plan.reason):
		return
	world.spider.begin_prepare()
	await physics_frames(2)
	world.spider.commit_jump(plan)
	await physics_frames(8)
	check_eq(world.spider.get_state_name(), "AIRBORNE", "in the air")
	var old: Node3D = world
	check(Checkpoint.boundary_problem(world) != "", "no checkpoint can be made in the air: %s" % Checkpoint.boundary_problem(world))
	await load_checkpoint()
	if world == null:
		return
	check(not is_instance_valid(old) or not old.is_inside_tree(), "the world in the air is gone")
	check_eq(world.spider.get_state_name(), "ATTACHED", "the checkpoint's spider stands in the crack")
	check(not world.spider.is_on_line(), "no line came along")
	check(world.habitat_loop.resting, "resting, as at the checkpoint")
	# preparing
	world.spider.set_intent(Vector3.ZERO, false)
	await run_ticks(5)
	check(world.spider.begin_prepare(), "aiming from the crack")
	await physics_frames(2)
	check(Checkpoint.boundary_problem(world) != "", "no checkpoint while aiming")
	await load_checkpoint(rec)
	if world != null:
		check_eq(world.spider.get_state_name(), "ATTACHED", "aiming is discarded with the world")


func test_loading_while_feeding_undoes_the_meal_since_the_checkpoint() -> void:
	await habitat(floor_pose(-16, 6, -90))
	var f := add_fly("sill_first_hunt", 1, true)
	await run_ticks(100)
	var rec_before := {}
	await put_spider(HOME.x, HOME.z, -90)
	rec_before = await rest_and_checkpoint()
	await put_spider(-16, 6, -90)
	await strike_at(-13, 6)
	if not check_eq(director().held, f, "caught after the checkpoint"):
		return
	check(world.feeding.request_feed(), "eating")
	await run_ticks(20)
	check(world.feeding.feeding, "mid-meal")
	check(Checkpoint.boundary_problem(world) != "", "no checkpoint mid-meal")
	var fid: String = f.id
	await load_checkpoint()
	if world == null:
		return
	check(director().held == null, "the fly caught after the checkpoint is not in the jaws")
	check(director().fly_by_id(fid) != null and director().fly_by_id(fid).is_alive(), "it is free on its perch again")
	check_eq(director().capture_log.size(), 0, "and its capture is undone with it")
	check_near(world.needs.granted_total, float(rec_before["needs"]["granted_total"]), 1.0e-12, "the energy of the undone meal is gone too")


func test_no_checkpoint_outside_the_windowsill_or_off_a_surface() -> void:
	await spawn_prey_world(floor_pose(0, 0, 0))
	check(Checkpoint.boundary_problem(world).contains("windowsill"), "the lab has no retreat checkpoint")
	var r: Dictionary = world.save_checkpoint()
	check(not bool(r["ok"]), "refused with a reason: %s" % str(r["message"]))
	check(world.return_to_checkpoint() == null, "nothing to return to")
	check(world.last_checkpoint_message.begins_with("No checkpoint yet"), "says so: %s" % world.last_checkpoint_message)


func test_a_refused_record_never_replaces_the_world() -> void:
	await habitat(floor_pose(HOME.x, HOME.z, -90), 1)
	var rec := await rest_and_checkpoint()
	var bad := rec.duplicate(true)
	bad["prey"]["flies"][0]["perch"] = "nowhere"
	var old: Node3D = world
	check(world.return_to_checkpoint(bad) == null, "a record naming a missing perch is refused")
	check(is_instance_valid(old) and old.is_inside_tree(), "the current world was left as it was")
	check(world.last_checkpoint_message.contains("unknown perch"), "with a useful reason: %s" % world.last_checkpoint_message)
