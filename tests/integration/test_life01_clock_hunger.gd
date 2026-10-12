extends "res://tests/prey_test_case.gd"
## LIFE_DESIGN.md round 1 (Nathan: "death can be real and jarring. not sensationalized"; LIFE-03: about 10 game days in 2 to 3 hours):
##   * the life clock passes the day with action time only (the same at any frame rate) and never while paused;
##   * a rest in the retreat in the evening sleeps until morning, a tick's worth of hours at a time, and keeps a new checkpoint; moving
##     wakes the spider; a rest by day passes no extra time;
##   * on the windowsill hunger runs by game hours, slower asleep, and can run out (the hours at zero are counted; no death yet);
##   * the light and the reach of the eyes follow the hour; the abdomen shows the spider's condition;
##   * checkpoints keep the day and the hour, and an older checkpoint is brought up to them;
##   * the notebook opens its pages on the first night, the first hunger and the first full abdomen.

const Checkpoint = preload("res://scripts/persistence/checkpoint.gd")
const LifeClock = preload("res://scripts/life/life_clock.gd")
const NeedsModel = preload("res://scripts/needs/needs_model.gd")
const SpiderBody = preload("res://scripts/presentation/spider_body.gd")
const FieldNotebook = preload("res://scripts/learning/field_notebook.gd")
const SimClock = preload("res://scripts/core/sim_clock.gd")
const HOME := Vector3(-25.0, 0.31, 6.0)


func _sill(interactive: bool = false) -> void:
	use_windowsill = true
	await spawn_prey_world(floor_pose(HOME.x, HOME.z, -90), 0, PREY_SEED, interactive)


## One 2 Hz needs update (the model takes at most MAX_STEP_S at a time).
func _period(n: RefCounted) -> void:
	n.advance(NeedsModel.MAX_STEP_S, false)
	n.advance(NeedsModel.UPDATE_PERIOD_S - NeedsModel.MAX_STEP_S, false)


func _rest() -> void:
	var loop: Node = world.habitat_loop
	loop.set_physics_process(false)
	loop.step(1.0 / 60.0, true, false)
	loop.set_physics_process(true)


func test_the_day_passes_with_action_time_and_never_while_paused() -> void:
	var c := LifeClock.new()
	check_eq(c.day, 1, "day 1")
	check_near(c.hour, 9.0, 1.0e-9, "at 9 in the morning")
	var h := c.advance(60.0, false)
	check_near(h, 60.0 * LifeClock.ACTIVE_HOURS_PER_S, 1.0e-9, "a minute of play is %.2f game hours" % h)
	check(c.advance(-1.0, false) == 0.0 and c.advance(NAN, false) == 0.0, "no time from nonsense")
	c.hour = 23.9
	c.advance(0.2 / LifeClock.ACTIVE_HOURS_PER_S, false)
	check(c.day == 2 and c.hour < 0.2, "midnight turns the day (%d, %.2f)" % [c.day, c.hour])
	await _sill()
	var loop: Node = world.habitat_loop
	var start: float = loop.clock.hour
	await physics_frames(120)
	check_near(loop.clock.hour - start, 120.0 * SimClock.DT * LifeClock.ACTIVE_HOURS_PER_S, 1.0e-6, "120 ticks: the same game time at any frame rate")
	var held: float = loop.clock.hour
	sandbox.get_tree().paused = true
	for i in 10:
		await sandbox.get_tree().process_frame
	sandbox.get_tree().paused = false
	check_eq(loop.clock.hour, held, "paused: no time passes")


func test_daylight_and_the_words_for_the_day() -> void:
	var c := LifeClock.new()
	c.hour = 12.0
	check_eq(c.daylight(), 1.0, "noon is full day")
	check_eq(c.part_of_day(), "midday", "midday")
	c.hour = 0.5
	check_eq(c.daylight(), 0.0, "past midnight it is dark")
	check_eq(c.part_of_day(), "night", "night")
	c.hour = 19.75
	check(c.daylight() > 0.05 and c.daylight() < 0.95, "dusk is in between (%.2f)" % c.daylight())
	check_eq(c.part_of_day(), "evening", "evening")
	c.hour = 6.5
	check(c.daylight() > 0.0 and c.daylight() < 0.5, "dawn is coming (%.2f)" % c.daylight())
	check(c.is_sleep_time(), "before 7 a rest is still a night's sleep")
	c.hour = 10.0
	check(not c.is_sleep_time(), "at 10 it is not")


func test_an_evening_rest_sleeps_until_morning_and_keeps_a_checkpoint() -> void:
	await _sill()
	var loop: Node = world.habitat_loop
	loop.clock.hour = 19.0
	var made := [0]
	loop.checkpoint_made.connect(func(r: Dictionary) -> void:
		if bool(r.get("ok", false)):
			made[0] = int(made[0]) + 1)
	_rest()
	check(loop.resting, "resting in the crack")
	var biggest := [0.0]
	var last := [loop.clock.hour + 24.0 * loop.clock.day]
	var asleep_seen := [false]
	await wait_until(func() -> bool:
		var now: float = loop.clock.hour + 24.0 * loop.clock.day
		biggest[0] = maxf(float(biggest[0]), now - float(last[0]))
		last[0] = now
		asleep_seen[0] = bool(asleep_seen[0]) or loop.asleep
		return loop.clock.day == 2 and not loop.asleep, 60 * 20)
	check(bool(asleep_seen[0]), "the spider slept")
	check(loop.clock.day == 2 and absf(loop.clock.hour - LifeClock.WAKE_H) < 0.05, "and woke on the morning of day 2 (%.2f)" % loop.clock.hour)
	check(float(biggest[0]) <= LifeClock.SLEEP_HOURS_PER_S * SimClock.DT + 1.0e-6, "the night passed a tick's worth at a time (largest step %.4f h)" % float(biggest[0]))
	check(loop.resting, "still resting in the crack, awake")
	check(int(made[0]) >= 2, "the rest and the morning each kept a checkpoint (%d)" % int(made[0]))
	check(loop.notice.contains("Morning, day 2"), "the screen says it is morning: %s" % loop.notice)
	check_eq(world.last_checkpoint["life"]["day"], 2, "the morning's checkpoint is of day 2")


func test_moving_wakes_the_spider_and_a_day_rest_passes_no_extra_time() -> void:
	await _sill()
	var loop: Node = world.habitat_loop
	loop.clock.hour = 22.0
	_rest()
	await physics_frames(30)
	check(loop.asleep, "asleep")
	var night: float = loop.clock.hour
	loop.stop_rest()
	await physics_frames(2)
	check(not loop.asleep, "moving wakes it")
	check(loop.notice.contains("Awake before morning"), "and says so: %s" % loop.notice)
	var t0: float = loop.clock.hour
	await physics_frames(60)
	check_near(fposmod(loop.clock.hour - t0, 24.0), 60.0 * SimClock.DT * LifeClock.ACTIVE_HOURS_PER_S, 1.0e-6, "awake, the night passes at the daytime rate")
	check(fposmod(loop.clock.hour - night, 24.0) < 3.0, "the night was not skipped")
	loop.clock.hour = 10.0
	_rest()
	var day_start: float = loop.clock.hour
	await physics_frames(60)
	check(loop.resting and not loop.asleep, "a rest at 10 in the morning is not a sleep")
	check_near(loop.clock.hour - day_start, 60.0 * SimClock.DT * LifeClock.ACTIVE_HOURS_PER_S, 1.0e-6, "and passes no extra time")


func test_hunger_runs_by_the_hour_and_can_run_out() -> void:
	var n := NeedsModel.new()
	n.life_mode = true
	n.configure({"energy": 0.6})
	n.add_hours(10.0, false)
	_period(n)
	check_near(n.energy, 0.6 - 10.0 * NeedsModel.LIFE_DRAIN_AWAKE_PER_H, 1.0e-9, "ten waking hours")
	var e: float = n.energy
	n.add_hours(10.0, true)
	_period(n)
	check_near(n.energy, e - 10.0 * NeedsModel.LIFE_DRAIN_ASLEEP_PER_H, 1.0e-9, "ten hours asleep use a third as much")
	check(not n.is_starving(), "not starving yet")
	n.add_hours(100.0, false)
	_period(n)
	check_eq(n.energy, 0.0, "the reserve can run out")
	check(n.is_starving() and n.starving_hours > 50.0, "and the hours without it are counted (%.1f)" % n.starving_hours)
	check(n.grant_energy(0.35, "fly_1") > 0.0 and not n.is_starving(), "a meal ends it")
	var full := NeedsModel.new()
	full.life_mode = true
	full.configure({"energy": 1.0})
	full.add_hours(2.5 * 12.0, false)
	full.add_hours(2.5 * 12.0, true)
	_period(full)
	check(full.energy > 0.1, "a full reserve still has some left after two and a half days without food (%.3f)" % full.energy)
	full.add_hours(12.0, false)
	full.add_hours(12.0, true)
	_period(full)
	check(full.is_starving(), "and is gone by the end of the third and a half")
	var legacy := NeedsModel.new()
	legacy.add_hours(100.0, false)
	_period(legacy)
	check(legacy.energy > NeedsModel.ENERGY_START - 0.01, "outside the windowsill the old slow drain is unchanged")
	await _sill()
	check(world.needs.life_mode, "the windowsill turns life mode on")


func test_the_light_and_the_reach_of_the_eyes_follow_the_hour() -> void:
	await _sill()
	var loop: Node = world.habitat_loop
	loop.clock.hour = 12.0
	loop.apply_light()
	var noon_sun: float = world.lab.sun.light_energy
	check_near(world.sensor.range_scale, 1.0, 1.0e-9, "at noon the eyes reach their full range")
	loop.clock.hour = 23.0
	loop.apply_light()
	check_eq(world.lab.sun.light_energy, 0.0, "at night there is no sun")
	check(world.lab._env.ambient_light_energy < 0.15, "a dim room light remains")
	check_near(world.sensor.range_scale, loop.NIGHT_SIGHT, 1.0e-9, "and the eyes reach a third as far")
	check_near(world.sensor.reach_wu(), world.sensor.range_wu * loop.NIGHT_SIGHT, 1.0e-6, "the sensor uses the shorter reach")
	check(noon_sun > 0.5, "the noon sun is the day's (%.2f)" % noon_sun)
	loop.clock.hour = 19.75
	loop.apply_light()
	check(world.lab.sun.light_energy > 0.0 and world.lab.sun.light_energy < noon_sun, "dusk is dimmer than noon")


func test_the_abdomen_shows_the_spider_condition() -> void:
	check(SpiderBody.abdomen_scale(1.0).x > SpiderBody.abdomen_scale(0.0).x + 0.25, "a full spider's abdomen is plainly bigger than a starving one's")
	check_near(SpiderBody.abdomen_scale(0.55).x, 1.0, 0.02, "about today's size at the start")
	await _sill()
	var body: Node = world.spider.get_node("Body")
	world.needs.configure({"energy": 0.1})
	world.needs.grant_energy(0.8, "test_source")
	check_near(body.condition, world.needs.energy, 1.0e-9, "the body hears of the meal")
	var before: float = body.shown_condition
	await physics_frames(30)
	check(body.shown_condition > before, "and fills out over the next moments")
	var ab: Node3D = body.get_node("Abdomen")
	check_near(ab.scale.x, SpiderBody.abdomen_scale(body.shown_condition).x, 1.0e-6, "drawn at that size")


func test_checkpoints_keep_the_day_and_older_ones_are_brought_up() -> void:
	await _sill()
	var loop: Node = world.habitat_loop
	loop.clock.day = 3
	loop.clock.hour = 15.25
	_rest()
	var rec: Dictionary = world.last_checkpoint
	if not check(not rec.is_empty(), "a checkpoint was kept"):
		return
	check_eq(int(rec["schema_version"]), 4, "schema 4")
	check(Checkpoint.validate(rec).is_empty(), "valid: %s" % "; ".join(Checkpoint.validate(rec)))
	var fresh: Node3D = world.return_to_checkpoint(rec)
	if not check(fresh != null, "it loads"):
		return
	world = fresh
	await wait_until(func() -> bool: return world.prey.ready_done and world.spider.state == world.spider.State.ATTACHED, 60)
	check_eq(world.habitat_loop.clock.day, 3, "day 3 again")
	check(absf(world.habitat_loop.clock.hour - 15.25) < 0.05, "at a quarter past three (%.3f)" % world.habitat_loop.clock.hour)
	check(world.needs.life_mode, "with hunger by the hour")
	var old: Dictionary = rec.duplicate(true)
	old["schema_version"] = 3
	old.erase("life")
	for k in ["life_mode", "starving_hours", "hour_accumulator"]:
		(old["needs"] as Dictionary).erase(k)
	var up: Variant = Checkpoint.upgrade(old)
	check(Checkpoint.validate(up).is_empty(), "a schema 3 checkpoint is brought up to 4: %s" % "; ".join(Checkpoint.validate(up)))
	check_eq(int(up["life"]["day"]), 1, "starting on day 1")
	var bad: Dictionary = rec.duplicate(true)
	bad["life"]["hour"] = 30.0
	check(not Checkpoint.validate(bad).is_empty(), "an impossible hour is refused")


func test_the_notebook_opens_the_life_pages() -> void:
	await _sill(true)
	var nb: Node = world.notebook
	world.needs.configure({"energy": 0.3})
	world.needs.add_hours(10.0, false)
	await physics_frames(40)
	check(nb.is_open("hungry_at_home"), "running low opens the hunger page")
	world.needs.grant_energy(0.9, "test_source")
	check(nb.is_open("full_abdomen"), "a full abdomen opens its page")
	world.habitat_loop.woke.emit(2)
	check(nb.is_open("home_before_dark"), "the first morning opens the night page")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FieldNotebook.PAGES_PATH))
	check_eq(nb.pages.size(), (raw["pages"] as Array).size(), "every page is complete and sourced")
