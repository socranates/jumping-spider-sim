extends "res://tests/prey_test_case.gd"
## LIFE_DESIGN.md round 3, moulting (LIFE-03: three moults from juvenile to adult in one life; MODES-01: reaching adulthood finishes the
## main life):
##   * enough food since the last moult makes the spider ready, and the screen says so;
##   * resting in the crack while ready moults it: the hours pass quickly, a tick's worth at a time, and the rest cannot be ended;
##   * afterwards it is a stage older, its old skin lies in the crack, and it is pale and soft, with shorter jumps, until the skin hardens;
##   * the third moult makes it an adult, and the notebook says the main life is finished;
##   * checkpoints keep all of it, and older checkpoints are brought up to it.

const Checkpoint = preload("res://scripts/persistence/checkpoint.gd")
const Growth = preload("res://scripts/life/growth.gd")
const LifeClock = preload("res://scripts/life/life_clock.gd")
const SimClock = preload("res://scripts/core/sim_clock.gd")
const HOME := Vector3(-25.0, 0.31, 6.0)


func _sill(interactive: bool = false) -> void:
	use_windowsill = true
	await spawn_prey_world(floor_pose(HOME.x, HOME.z, -90), 0, PREY_SEED, interactive)


func _rest() -> void:
	var loop: Node = world.habitat_loop
	loop.set_physics_process(false)
	loop.step(1.0 / 60.0, true, false)
	loop.set_physics_process(true)


## Feeds the spider enough to be ready (through the needs' ledger, as a meal does) and waits a tick for the loop to see it.
func _feed_to_ready() -> void:
	world.habitat_loop.on_food(Growth.READY_FOOD + 0.01)
	await physics_frames(2)


func _moult_through() -> void:
	var loop: Node = world.habitat_loop
	await wait_until(func() -> bool: return not loop.growth.is_moulting(), 60 * 15)


func test_food_from_the_needs_ledger_counts_toward_a_moult() -> void:
	await _sill()
	var loop: Node = world.habitat_loop
	world.needs.configure({"energy": 0.05})
	world.needs.grant_energy(0.5, "ledger_meal")
	await physics_frames(2)
	check_near(loop.growth.fed_since_moult, 0.5, 1.0e-6, "a meal's energy counts toward the next moult")
	check(not loop.growth.ready, "half a moult's worth is not enough")


func test_the_growth_rules() -> void:
	var g := Growth.new()
	check_eq(g.stage_name(), "young juvenile", "a young juvenile at the start")
	check(not g.eat(Growth.READY_FOOD - 0.1), "not ready on a little food")
	check(g.eat(0.2) and g.ready, "ready once it has eaten enough")
	check(not g.eat(0.2), "and says so once")
	check(g.begin_moult() and g.is_moulting(), "the moult begins")
	check_eq(g.reach_factor(), Growth.SOFT_REACH, "jumps are short while moulting")
	check_eq(g.pass_hours(Growth.MOULT_HOURS - 0.5, Vector3.ZERO), "", "not done before its hours")
	check_eq(g.pass_hours(1.0, Vector3(1, 2, 3)), "moulted", "then done")
	check(g.stage == 1 and g.is_soft() and not g.ready and g.fed_since_moult == 0.0, "a stage older, soft, starting again")
	check_eq(g.exuviae, [Vector3(1, 2, 3)] as Array[Vector3], "the old skin is where it moulted")
	check_eq(g.pass_hours(Growth.SOFT_HOURS + 1.0, Vector3.ZERO), "hardened", "the skin hardens")
	check_eq(g.reach_factor(), 1.0, "full jumps again")
	g.stage = Growth.ADULT
	check(not g.eat(5.0) and not g.begin_moult(), "an adult moults no more")
	check(Growth.problems(g.to_dict()).is_empty(), "the record is valid")
	var bad := g.to_dict()
	bad["stage"] = 7
	check(not Growth.problems(bad).is_empty(), "an impossible stage is refused")


func test_a_ready_spider_moults_in_the_crack() -> void:
	await _sill()
	var loop: Node = world.habitat_loop
	var reach_before: float = world.spider.reach_factor
	await _feed_to_ready()
	check(loop.growth.ready, "enough food makes it ready")
	check(loop.notice.contains("ready to moult"), "and the screen says so: %s" % loop.notice)
	check(loop.caption().contains("moult"), "the caption offers the moult: %s" % loop.caption())
	_rest()
	await physics_frames(2)
	check(loop.growth.is_moulting(), "resting in the crack begins the moult")
	check(loop.caption().contains("Moulting"), "and says so")
	loop.set_physics_process(false)
	loop.step(SimClock.DT, false, true)   # a cancel press
	loop.step(SimClock.DT, true, false)   # an interact press
	loop.set_physics_process(true)
	check(loop.resting and loop.growth.is_moulting(), "a moult cannot be stopped")
	var biggest := [0.0]
	var last := [loop.clock.day * 24.0 + loop.clock.hour]
	await wait_until(func() -> bool:
		var now: float = loop.clock.day * 24.0 + loop.clock.hour
		biggest[0] = maxf(float(biggest[0]), now - float(last[0]))
		last[0] = now
		return not loop.growth.is_moulting(), 60 * 15)
	check(float(biggest[0]) <= LifeClock.SLEEP_HOURS_PER_S * SimClock.DT + 1.0e-6, "the moult's hours passed a tick's worth at a time (%.4f)" % float(biggest[0]))
	check_eq(loop.growth.stage, 1, "a stage older")
	check(loop.notice.contains("Moulted"), "the screen says so: %s" % loop.notice)
	var skins: Array = world.lab.find_children("OldSkin*", "", true, false)
	check_eq(skins.size(), 1, "the old skin lies in the crack")
	check(world.lab.in_retreat((skins[0] as Node3D).global_position + Vector3(0, 0.18, 0)), "inside the retreat")
	check_near(world.spider.reach_factor, reach_before * Growth.SOFT_REACH, 1.0e-6, "soft: the jumps reach %.0f %% as far" % (Growth.SOFT_REACH * 100.0))
	var body: Node = world.spider.get_node("Body")
	check(body.softness > 0.9, "and the spider is pale")
	check_eq(int(world.last_checkpoint["growth"]["stage"]), 1, "the moult kept a checkpoint of the new stage")
	loop.growth.soft_hours_left = 0.001
	await physics_frames(3)
	check(not loop.growth.is_soft(), "the skin hardens")
	check_near(world.spider.reach_factor, reach_before, 1.0e-6, "full jumps again")
	check(body.softness < 0.01, "and the colour comes back")


func test_three_moults_make_an_adult_and_finish_the_main_life() -> void:
	await _sill(true)
	var loop: Node = world.habitat_loop
	var nb: Node = world.notebook
	for i in 3:
		if loop.resting:
			loop.stop_rest()
		await physics_frames(2)
		await _feed_to_ready()
		if i == 0:
			check(nb.is_open("outgrowing_a_skin"), "the first readiness opens its notebook page")
		_rest()
		await physics_frames(2)
		await _moult_through()
		loop.growth.soft_hours_left = 0.0
		await physics_frames(3)
		if i == 0:
			check(nb.is_open("new_skin"), "the first moult opens its page")
	check(loop.growth.is_adult(), "after three moults the spider is an adult")
	check_eq(loop.growth.exuviae.size(), 3, "three old skins")
	check(loop.caption().contains("adult"), "the top line says so")
	check(nb.is_open("grown_up"), "the notebook says the main life is finished")
	loop.on_food(2.0)
	await physics_frames(2)
	check(not loop.growth.ready, "an adult does not get ready to moult again")


func test_checkpoints_keep_growth_and_older_ones_are_brought_up() -> void:
	await _sill()
	var loop: Node = world.habitat_loop
	loop.growth.stage = 2
	loop.growth.fed_since_moult = 0.4
	loop.growth.soft_hours_left = 3.0
	loop.growth.exuviae = [HOME, HOME + Vector3(0.5, 0, 0)] as Array[Vector3]
	_rest()
	var rec: Dictionary = world.last_checkpoint
	check_eq(int(rec["schema_version"]), 5, "schema 5")
	check(Checkpoint.validate(rec).is_empty(), "valid: %s" % "; ".join(Checkpoint.validate(rec)))
	var fresh: Node3D = world.return_to_checkpoint(rec)
	if not check(fresh != null, "it loads"):
		return
	world = fresh
	await wait_until(func() -> bool: return world.prey.ready_done and world.spider.state == world.spider.State.ATTACHED, 60)
	var g: RefCounted = world.habitat_loop.growth
	check(g.stage == 2 and absf(g.fed_since_moult - 0.4) < 1.0e-9 and g.is_soft(), "the stage, the food and the soft skin are back")
	check_eq(world.lab.find_children("OldSkin*", "", true, false).size(), 2, "and both old skins")
	check_near(world.spider.reach_factor, float(settings.get_value("jump_reach")) * Growth.SOFT_REACH, 1.0e-6, "still soft after loading")
	var old: Dictionary = rec.duplicate(true)
	old["schema_version"] = 4
	old.erase("growth")
	var up: Variant = Checkpoint.upgrade(old)
	check(Checkpoint.validate(up).is_empty(), "a schema 4 checkpoint is brought up to 5: %s" % "; ".join(Checkpoint.validate(up)))
	check_eq(int(up["growth"]["stage"]), 0, "as a young juvenile")
