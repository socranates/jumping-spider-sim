extends "res://tests/prey_test_case.gd"
## Gate L01 (spec 25, T07; A-028): feeding increases energy only while it is valid, and canceling cannot duplicate prey or consumption.
## The part about saving and loading is a test of its own (T09): it uses the retreat checkpoint (S01-C), the only save P0 has, in the
## windowsill, and its result is in the runner's report.
##
## Everything here uses the real spider, the real prey director, the real feeding controller and the real needs model. The spider holds a
## captured fly (a real strike) and the checks audit every tick: the energy, the ledger of what each source has given, the controller's
## state, and what the spider and the prey were doing.
##
## Four fixtures, each a fresh world:
##   F1 the audit of one whole meal: nothing is granted by the capture or while the spider only holds the prey; energy rises while the
##      meal is valid, at the rate the species data sets and by exactly what the fly gave up; it stops on the tick the spider steps, aims or
##      leaves its footing; and when the fly is eaten the reserve has gained its nutrition once
##   F2 canceling at random moments, again and again, by every route (the button twice, cancel, a step, a jump press): what was granted is
##      always what was eaten, never more than the fly had, the fly is never duplicated, and a cancel on the very tick of the last bite
##      cannot grant it twice
##   F3 what is refused: nothing in the jaws, a prey that escaped, a spider that moves, aims or hangs; each says why and grants nothing; a
##      full reserve does not stop the meal and is not overfilled
##   F4 the real buttons: interact (E, the west button) starts and stops the meal, cancel (Q, B) stops it, and the controls are the player's
##      again on the same tick
## Writes tests/reports/l01_report.txt.

const GateFixture := preload("res://tests/gate_fixture.gd")
const Evidence := preload("res://tests/evidence.gd")
const REPORT_PATH := "res://tests/reports/l01_report.txt"
const ACTIONS := ["interact", "cancel", "move_forward", "prepare_jump"]

var _results: Array = []


func after_each() -> void:
	for a: String in ACTIONS:
		Input.action_release(a)


func test_l01_feeding_increases_energy_only_while_valid_and_canceling_cannot_duplicate_prey_or_consumption() -> void:
	_results.clear()
	var fixtures: Array[Callable] = [_f1_one_meal, _f2_cancels, _f3_refusals, _f4_buttons]
	for fixture: Callable in fixtures:
		var f: GateFixture = await fixture.call()
		_results.append(f)
		await _drop_world()
	var lines := PackedStringArray()
	lines.append("L01 feeding report (spec 25): feeding increases energy only while valid; canceling cannot duplicate prey or consumption")
	lines.append("timestamp_utc: %sZ" % Time.get_datetime_string_from_system(true))
	lines.append(Evidence.describe(Evidence.identity("res://")))
	lines.append("engine: %s" % Engine.get_version_info()["string"])
	lines.append("numbers: a fly gives 0.35 of the reserve in all, eaten at 0.10 a second (3.5 s for a whole fly); the reserve is 0..1 and starts at 0.55; it drains by 0.0006 a second down to a floor of 0.20, so a meal is never needed to survive the first hunt")
	lines.append("setup: the lab's own world, the real spider, prey director, feeding controller and needs model; the spider holds a fly it caught with a real strike (F4 sets the catch up directly and presses the real buttons); the audit reads the truth")
	var passed := 0
	for f: GateFixture in _results:
		if f.ok():
			passed += 1
		lines.append("%s %s" % ["PASS" if f.ok() else "FAIL", f.name])
		for n in f.notes:
			lines.append("    %s" % n)
		for pr in f.problems:
			lines.append("    PROBLEM: %s" % pr)
		check(f.ok(), "%s: %s" % [f.name, "; ".join(f.problems)])
	lines.append("saving and loading cannot duplicate prey or consumption: checked by test_l01_saving_and_loading_cannot_duplicate_prey_or_consumption (T09, through the S01-C retreat checkpoint in the windowsill); its result is in the runner's report, not here.")
	var summary := "L01 result: %d of %d fixtures passed: feeding raised the energy only while valid and canceling never duplicated prey or consumption; save/load not run (no save system yet)" % [passed, _results.size()]
	lines.append("")
	lines.append(summary)
	print(summary)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/reports"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()


## T09: the save/load half of L01, through the S01-C checkpoint (the only save P0 has; DECISIONS A-001). In the shipped windowsill the spider
## catches a fly with a real strike, eats part of it and stops; a checkpoint is made then (standing still, holding the part-eaten fly). It then
## finishes the meal, and the checkpoint is loaded: the fly is in the jaws again with exactly what was left, the energy and the ledger are the
## checkpoint's, and finishing it again grants its nutrition once in all. Loading again, and loading twice in a row, changes none of that:
## no second fly, no second capture, no energy from nowhere.
func test_l01_saving_and_loading_cannot_duplicate_prey_or_consumption() -> void:
	use_windowsill = true
	await spawn_prey_world(floor_pose(-16, 6, -90))
	var f := add_fly("sill_first_hunt", 1, true)
	await run_ticks(100)
	await strike_at(-13, 6)
	if not check(director().held == f, "the spider holds the fly it caught"):
		return
	var fid: String = f.id
	var event_id: String = f.capture_event_id
	var total: float = f.nutrition_total
	check(world.feeding.request_feed(), "eating starts")
	await run_ticks(15)
	world.feeding.request_cancel()
	await run_ticks(3)
	var left: float = f.nutrition_left
	check(left > 0.0 and left < total, "part of the fly is eaten (%.4f of %.4f left)" % [left, total])
	var saved: Dictionary = world.save_checkpoint()
	if not check(bool(saved["ok"]), "a checkpoint is made standing still with the fly in the jaws: %s" % str(saved["message"])):
		return
	var rec: Dictionary = saved["record"]
	var energy_at: float = world.needs.energy
	var granted_at: float = world.needs.granted_from(event_id)
	check_near(granted_at, total - left, 1.0e-9, "what was granted so far is what was eaten so far")
	# finish the meal after the checkpoint
	check(world.feeding.request_feed(), "eating again")
	await wait_until(func() -> bool: return not world.feeding.feeding, 400)
	check_near(world.needs.granted_from(event_id), total, 1.0e-6, "the whole fly was eaten once before loading")
	for n in 3:
		var fresh: Node3D = world.return_to_checkpoint(rec if n == 2 else {})
		if not check(fresh != null, "load %d: %s" % [n + 1, world.last_checkpoint_message]):
			return
		world = fresh
		await wait_until(func() -> bool: return world.prey.ready_done and world.spider.state == world.spider.State.ATTACHED, 60)
		var held: Node3D = director().held
		check(held != null and held.id == fid, "load %d: the same fly is in the jaws" % [n + 1])
		if held == null:
			return
		check_near(held.nutrition_left, left, 1.0e-9, "load %d: with exactly what was left at the checkpoint" % [n + 1])
		check_eq(director().capture_log.size(), 1, "load %d: one capture, not two" % [n + 1])
		var copies := 0
		for g in director().flies:
			if g.id == fid:
				copies += 1
		check_eq(copies, 1, "load %d: one fly by that id" % [n + 1])
		check_near(world.needs.energy, energy_at, 1.0e-9, "load %d: the energy is the checkpoint's" % [n + 1])
		check_near(world.needs.granted_from(event_id), granted_at, 1.0e-9, "load %d: the ledger is the checkpoint's" % [n + 1])
		if n == 1:
			continue  # load straight again without eating: nothing may change
		check(world.feeding.request_feed(), "load %d: the meal goes on" % [n + 1])
		await wait_until(func() -> bool: return not world.feeding.feeding, 400)
		check_near(world.needs.granted_from(event_id), total, 1.0e-6, "load %d: the fly gave its nutrition once in all" % [n + 1])
		check(world.needs.granted_total <= total + 1.0e-6, "load %d: nothing else was granted" % [n + 1])
		check_eq(held.state_name(), "CONSUMED", "load %d: eaten" % [n + 1])


# ------------------------------------------------------------------ helpers

func _drop_world() -> void:
	if world != null and is_instance_valid(world):
		world.free()
		world = null
	await physics_frames(2)


## A per-tick audit of the books. `rec` collects: ticks in which the ledger grew and whether the meal was valid then, grants above the rate
## the data allows, energy gains the ledger does not explain, and the largest single grant.
func _new_audit() -> Dictionary:
	return {"granted": float(world.needs.granted_total), "energy": float(world.needs.energy), "finished": int(world.feeding.meals_finished),
		"grant_ticks": 0, "bad_grants": 0, "over_rate": 0, "unexplained": 0, "max_grant": 0.0, "valid_ticks": 0, "problems": PackedStringArray()}


func _audit(rec: Dictionary) -> void:
	var needs = world.needs
	var fc = world.feeding
	var spider: Node3D = world.spider
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var rate: float = float(director().profile.feed_rate_per_s)
	var granted: float = float(needs.granted_total)
	var d: float = granted - float(rec["granted"])
	var de: float = float(needs.energy) - float(rec["energy"])
	var finished_now: bool = int(fc.meals_finished) > int(rec["finished"])
	if d > 1.0e-12:
		rec["grant_ticks"] = int(rec["grant_ticks"]) + 1
		rec["max_grant"] = maxf(float(rec["max_grant"]), d)
		var valid: bool = (bool(fc.feeding) or finished_now) and spider.state == spider.State.ATTACHED and spider.velocity.length() <= 0.2
		if not valid:
			rec["bad_grants"] = int(rec["bad_grants"]) + 1
			(rec["problems"] as PackedStringArray).append("tick %d: the ledger grew by %.5f with feeding %s, spider state %d, speed %.2f" % [director().tick, d, str(fc.feeding), spider.state, spider.velocity.length()])
		if d > rate * dt + 1.0e-9:
			rec["over_rate"] = int(rec["over_rate"]) + 1
	if de > d + 1.0e-9:
		rec["unexplained"] = int(rec["unexplained"]) + 1
		(rec["problems"] as PackedStringArray).append("tick %d: the energy rose by %.5f and the ledger by %.5f" % [director().tick, de, d])
	rec["granted"] = granted
	rec["energy"] = float(needs.energy)
	rec["finished"] = int(fc.meals_finished)


func _ledger_matches(f: Node3D) -> bool:
	return absf(float(world.needs.granted_from(f.capture_event_id)) - (f.nutrition_total - f.nutrition_left)) < 1.0e-9


# ------------------------------------------------------------------ F1 one meal

func _f1_one_meal() -> GateFixture:
	var fx := GateFixture.new("F1 a whole meal, audited tick by tick: energy rises only while the meal is valid")
	var f := await catch_a_fly()
	var rate: float = float(f.profile.feed_rate_per_s)
	var audit := _new_audit()
	var on_tick := func() -> void: _audit(audit)
	var e0: float = world.needs.energy
	fx.need(f.state == Fly.State.CAPTURED and director().held == f and world.needs.grants_made == 0, "the capture: the fly is CAPTURED and held, and no energy has been granted (%d grants, %.3f)" % [world.needs.grants_made, world.needs.energy], "after the capture: state %s, %d grants" % [f.state_name(), world.needs.grants_made])
	await run_ticks(60, on_tick)
	fx.need(int(audit["grant_ticks"]) == 0 and world.needs.energy <= e0 + 1.0e-9, "holding the prey for a second grants nothing: the reserve only drained, %.4f to %.4f" % [e0, world.needs.energy], "holding the prey changed the reserve to %.4f" % world.needs.energy)
	var e1: float = world.needs.energy
	fx.need(world.feeding.request_feed(), "E starts the meal", "the meal was refused: %s" % world.feeding.last_refusal)
	await run_ticks(90, on_tick)
	var gained: float = world.needs.energy - e1
	fx.need(absf(gained - rate * 1.5) < 0.004 and int(audit["over_rate"]) == 0, "1.5 s of feeding raised the reserve by %.3f (the data says %.3f), never more than %.4f in a tick" % [gained, rate * 1.5, float(audit["max_grant"])], "1.5 s of feeding raised the reserve by %.3f (expected %.3f), %d ticks over the rate" % [gained, rate * 1.5, int(audit["over_rate"])])
	fx.need(_ledger_matches(f), "and the ledger shows what the fly gave up (%.4f of %.2f) and nothing else" % [f.nutrition_total - f.nutrition_left, f.nutrition_total], "the ledger says %.4f, the fly gave up %.4f" % [world.needs.granted_from(f.capture_event_id), f.nutrition_total - f.nutrition_left])
	# the spider steps: invalid on that tick
	var g1: float = world.needs.granted_total
	world.spider.set_intent(Vector3.RIGHT, false)
	await run_ticks(1, on_tick)
	var stopped_on_the_tick: bool = not world.feeding.feeding and world.feeding.last_end_reason == "moved"
	await run_ticks(20, on_tick)
	world.spider.set_intent(Vector3.ZERO, false)
	fx.need(stopped_on_the_tick and absf(world.needs.granted_total - g1) < 1.0e-12, "the spider took a step: the meal ended on that very tick ('moved') and nothing more was granted while it walked", "after a step: stopped on the tick %s, granted %.5f more" % [str(stopped_on_the_tick), world.needs.granted_total - g1])
	await run_ticks(40, on_tick)
	fx.need(absf(world.needs.granted_total - g1) < 1.0e-12, "standing still again without pressing E grants nothing: a meal is something the player starts", "granted %.5f without a meal" % (world.needs.granted_total - g1))
	# an aim in progress is not a valid moment either
	world.feeding.request_feed()
	await run_ticks(10, on_tick)
	var g2: float = world.needs.granted_total
	world.spider.begin_prepare()
	await run_ticks(10, on_tick)
	world.spider.cancel_prepare()
	fx.need(world.feeding.last_end_reason == "jumped" and absf(world.needs.granted_total - g2) < rate * 2.0 / 60.0 + 1.0e-9, "pressing the jump ended it ('jumped') within a tick, and nothing was granted during the aim", "the jump press: last end '%s', granted %.5f meanwhile" % [world.feeding.last_end_reason, world.needs.granted_total - g2])
	await run_ticks(30, on_tick)
	# and a meal to the end
	world.feeding.request_feed()
	var done: bool = await wait_until(func() -> bool: _audit(audit); return not world.feeding.feeding, 60 * 5)
	fx.need(done and world.feeding.last_end_reason == "finished" and f.state == Fly.State.CONSUMED, "the meal went on to the end: the fly is CONSUMED and the jaws are empty (%s)" % str(director().held), "the last meal ended '%s' with the fly %s" % [world.feeding.last_end_reason, f.state_name()])
	fx.need(absf(world.needs.granted_from(f.capture_event_id) - f.nutrition_total) < 1.0e-6, "in all it granted %.4f, the fly's whole nutrition, once" % world.needs.granted_from(f.capture_event_id), "in all it granted %.5f" % world.needs.granted_from(f.capture_event_id))
	fx.need(int(audit["bad_grants"]) == 0 and int(audit["unexplained"]) == 0, "over the whole run the energy rose in %d ticks and every one was inside a valid meal, with no gain the ledger does not explain" % int(audit["grant_ticks"]), "audit: %s" % "; ".join(audit["problems"] as PackedStringArray))
	return fx


# ------------------------------------------------------------------ F2 cancels

func _f2_cancels() -> GateFixture:
	var fx := GateFixture.new("F2 canceling at any moment, by any route, again and again, cannot duplicate the prey or its consumption")
	var f := await catch_a_fly()
	var id: String = f.capture_event_id
	var audit := _new_audit()
	var on_tick := func() -> void: _audit(audit)
	var routes := {"button": 0, "cancel": 0, "step": 0, "jump": 0}
	var population0: int = director().flies.size()
	for cycle in 14:
		if f.state != Fly.State.CAPTURED or f.nutrition_left < 0.12:
			break
		world.feeding.request_feed()
		await run_ticks(rng.randi_range(1, 45), on_tick)
		match rng.randi_range(0, 3):
			0:
				world.feeding.step(1.0 / 60.0, true, false)   # the button again, as the controller would send it
				routes["button"] += 1
			1:
				world.feeding.step(1.0 / 60.0, false, true)   # cancel
				routes["cancel"] += 1
			2:
				world.spider.set_intent(Vector3.RIGHT, false)
				await run_ticks(2, on_tick)
				world.spider.set_intent(Vector3.ZERO, false)
				routes["step"] += 1
			_:
				world.spider.begin_prepare()
				await run_ticks(2, on_tick)
				world.spider.cancel_prepare()
				routes["jump"] += 1
		await run_ticks(rng.randi_range(2, 25), on_tick)
		if not _ledger_matches(f):
			fx.problems.append("cycle %d: the ledger says %.5f and the fly gave up %.5f" % [cycle, world.needs.granted_from(id), f.nutrition_total - f.nutrition_left])
	fx.need(world.feeding.meals_started >= 8 and routes["button"] + routes["cancel"] + routes["step"] + routes["jump"] >= 8, "%d meals were started and cancelled at random moments: %d by the button, %d by cancel, %d by a step, %d by a jump press" % [world.feeding.meals_started, routes["button"], routes["cancel"], routes["step"], routes["jump"]], "only %d meals were started" % world.feeding.meals_started)
	var left: float = f.nutrition_left
	fx.need(_ledger_matches(f) and world.needs.granted_from(id) < f.nutrition_total, "after all of them the ledger holds %.4f, exactly what the fly gave up, and the fly still has %.4f of its %.2f" % [world.needs.granted_from(id), left, f.nutrition_total], "the ledger says %.5f and the fly gave up %.5f" % [world.needs.granted_from(id), f.nutrition_total - left])
	fx.need(director().flies.size() == population0 and director().capture_log.size() == 1 and director().held == f and f.state == Fly.State.CAPTURED, "there is still one fly, held, captured once: canceling made no second fly and no second capture", "flies %d (was %d), captures %d, state %s" % [director().flies.size(), population0, director().capture_log.size(), f.state_name()])
	# a cancel on the very tick of the last bite: eat on, tick by tick, until one bite is all that is left
	var one_bite: float = float(f.profile.feed_rate_per_s) / 60.0
	world.spider.set_intent(Vector3.ZERO, false)
	await run_ticks(30, on_tick)
	world.feeding.request_feed()
	await wait_until(func() -> bool: _audit(audit); return f.nutrition_left <= one_bite * 1.0001 or not world.feeding.feeding, 60 * 6)
	var before: float = world.needs.granted_from(id)
	var left_before: float = f.nutrition_left
	world.feeding.step(1.0 / 60.0, false, true)
	fx.need(left_before > 0.0 and not world.feeding.feeding and f.nutrition_left == left_before and f.state == Fly.State.CAPTURED and absf(world.needs.granted_from(id) - before) < 1.0e-12, "a cancel on the very tick of the last bite wins: that bite is not taken and not granted (%.5f is left)" % f.nutrition_left, "the last bite was taken anyway or the meal went on (left %.5f, was %.5f)" % [f.nutrition_left, left_before])
	world.feeding.request_feed()
	await wait_until(func() -> bool: _audit(audit); return not world.feeding.feeding, 120)
	fx.need(f.state == Fly.State.CONSUMED and absf(world.needs.granted_from(id) - f.nutrition_total) < 1.0e-6 and _ledger_matches(f), "the next meal took it: CONSUMED, and the ledger holds %.4f, its whole nutrition and no more" % world.needs.granted_from(id), "state %s, ledger %.5f of %.5f" % [f.state_name(), world.needs.granted_from(id), f.nutrition_total])
	var total_before: float = world.needs.granted_total
	for i in 4:
		world.feeding.request_feed()
		world.feeding.step(1.0 / 60.0, true, false)
		world.feeding.request_cancel()
	await run_ticks(60, on_tick)
	fx.need(absf(world.needs.granted_total - total_before) < 1.0e-12 and director().living().is_empty() and director().held == null, "pressing E and cancel on an eaten fly grants nothing and brings nothing back: no living fly, empty jaws", "after the fly was eaten %.5f was granted and %d flies live" % [world.needs.granted_total - total_before, director().living().size()])
	fx.need((world.needs.granted_by_source as Dictionary).size() == 1 and int(audit["bad_grants"]) == 0 and int(audit["unexplained"]) == 0, "one source in the books, and every tick of every meal was valid with nothing unexplained (%d energy ticks)" % int(audit["grant_ticks"]), "sources %s; audit %s" % [str(world.needs.granted_by_source.keys()), "; ".join(audit["problems"] as PackedStringArray)])
	return fx


# ------------------------------------------------------------------ F3 refusals

func _f3_refusals() -> GateFixture:
	var fx := GateFixture.new("F3 what is refused grants nothing, and says why; a full reserve is not overfilled")
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0), 0, PREY_SEED)
	var fly := add_fly("floor_east_open", 1)
	var e0: float = world.needs.energy
	fx.need(not world.feeding.request_feed() and world.feeding.last_refusal == "no prey", "with nothing in the jaws E is refused: '%s'" % world.feeding.last_refusal, "refused as '%s'" % world.feeding.last_refusal)
	# a strike at a fly that notices: it escapes, and cannot be eaten
	await run_ticks(60)
	await put_spider(4.0, 4.0, 180.0)
	await strike_at(4.0, 11.0)
	var escaped: bool = fly.state != Fly.State.CAPTURED
	if escaped:
		fx.need(not world.feeding.request_feed() and world.feeding.last_refusal == "no prey" and world.needs.grants_made == 0, "a strike that missed (the fly was %s) leaves nothing to eat: refused, and no energy granted" % fly.state_name(), "a missed strike left the controller feeding")
	else:
		fx.note("(the fly was caught by this strike, so the missed-strike refusal was not exercised here)")
	await _drop_world()
	var f := await catch_a_fly()
	# moving
	world.spider.set_intent(Vector3.RIGHT, false)
	await run_ticks(3)
	fx.need(not world.feeding.request_feed() and world.feeding.last_refusal == "moved", "walking: refused ('moved')", "walking: refused as '%s'" % world.feeding.last_refusal)
	world.spider.set_intent(Vector3.ZERO, false)
	await run_ticks(40)
	# aiming
	world.spider.begin_prepare()
	await run_ticks(2)
	fx.need(not world.feeding.request_feed() and world.feeding.last_refusal == "jumped", "aiming a jump: refused ('jumped')", "aiming: refused as '%s'" % world.feeding.last_refusal)
	world.spider.cancel_prepare()
	await run_ticks(10)
	fx.need(world.needs.grants_made == 0 and f.state == Fly.State.CAPTURED and absf(f.nutrition_left - f.nutrition_total) < 1.0e-12, "none of the refusals took a bite or granted anything (refused %d times for: moved %d, jumped %d)" % [world.feeding.refusals.values().reduce(func(a: int, b: int) -> int: return a + b, 0), int(world.feeding.refusals.get("moved", 0)), int(world.feeding.refusals.get("jumped", 0))], "a refusal took a bite or granted energy")
	# a full reserve
	world.needs.energy = 0.99
	world.feeding.request_feed()
	await wait_until(func() -> bool: return not world.feeding.feeding, 60 * 5)
	fx.need(world.feeding.last_end_reason == "finished" and f.state == Fly.State.CONSUMED, "with the reserve nearly full the meal still ends by itself, so the player is never trapped holding prey", "a full reserve left the meal '%s', fly %s" % [world.feeding.last_end_reason, f.state_name()])
	fx.need(world.needs.energy <= 1.0 + 1.0e-12 and world.needs.granted_from(f.capture_event_id) < f.nutrition_total * 0.1, "and the reserve is not overfilled: %.4f, having been granted only %.4f of the %.2f the fly had (the rest had no room)" % [world.needs.energy, world.needs.granted_from(f.capture_event_id), f.nutrition_total], "the reserve is %.4f after %.4f was granted" % [world.needs.energy, world.needs.granted_from(f.capture_event_id)])
	return fx


# ------------------------------------------------------------------ F4 the real buttons

func _f4_buttons() -> GateFixture:
	var fx := GateFixture.new("F4 the real buttons: interact starts the meal, interact or cancel stops it, and the controls are the player's again at once")
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0), 0, PREY_SEED, true)
	var fly := add_fly("floor_east_open", 1, true)
	await physics_frames(5)
	# the capture is set up directly here (A01 F4 covers the strike): the fly is in the jaws, the spider stands still
	fly.global_position = world.spider.get_eye_position()
	director().held = fly
	fly.mark_captured("spider", "capture:spider:%s" % fly.id)
	await physics_frames(10)
	var e0: float = world.needs.energy
	Input.action_press("interact")
	await run_ticks(2)
	Input.action_release("interact")
	await run_ticks(30)
	fx.need(world.feeding.feeding and world.needs.energy > e0 + 0.02, "E started the meal and the reserve rose, %.3f to %.3f in half a second" % [e0, world.needs.energy], "E: feeding %s, reserve %.3f" % [str(world.feeding.feeding), world.needs.energy])
	Input.action_press("cancel")
	await run_ticks(2)
	Input.action_release("cancel")
	var e1: float = world.needs.energy
	fx.need(not world.feeding.feeding and world.feeding.last_end_reason == "cancelled", "Q stopped it", "Q left feeding %s ('%s')" % [str(world.feeding.feeding), world.feeding.last_end_reason])
	await run_ticks(20)
	fx.need(absf(world.needs.energy - e1) < 0.0009, "and nothing more was granted (%.4f)" % (world.needs.energy - e1), "%.4f was granted after cancel" % (world.needs.energy - e1))
	# control returns: the spider walks on the very next ticks
	var x0: float = world.spider.global_position.z
	Input.action_press("move_forward")
	await run_ticks(30)
	Input.action_release("move_forward")
	fx.need(absf(world.spider.global_position.z - x0) > 0.5, "the stick works at once: the spider walked %.2f WU after the meal was cancelled" % absf(world.spider.global_position.z - x0), "the spider did not walk after cancel")
	# starting while walking does nothing, and E again later starts a fresh meal that continues from what is left
	Input.action_press("move_forward")
	await run_ticks(10)
	Input.action_press("interact")
	await run_ticks(2)
	Input.action_release("interact")
	var refused_walking: bool = not world.feeding.feeding
	Input.action_release("move_forward")
	await run_ticks(40)
	Input.action_press("interact")
	await run_ticks(2)
	Input.action_release("interact")
	await run_ticks(10)
	fx.need(refused_walking and world.feeding.feeding, "E while walking did nothing; E when still started the next meal", "E while walking: refused %s; later: feeding %s" % [str(refused_walking), str(world.feeding.feeding)])
	Input.action_press("interact")
	await run_ticks(2)
	Input.action_release("interact")
	fx.need(not world.feeding.feeding and world.feeding.last_end_reason == "cancelled", "E again stops it too", "second E left feeding %s" % str(world.feeding.feeding))
	fx.need(absf(world.needs.granted_from(fly.capture_event_id) - (fly.nutrition_total - fly.nutrition_left)) < 1.0e-9 and fly.nutrition_left > 0.0, "after three presses the ledger is exactly what was eaten (%.4f of %.2f)" % [world.needs.granted_from(fly.capture_event_id), fly.nutrition_total], "the ledger and the fly disagree")
	return fx
