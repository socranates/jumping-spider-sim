extends "res://tests/prey_test_case.gd"
## LIFE_DESIGN round 5, death and continuing (LIFE-01: "death can be real and jarring. not sensationalized"; LIFE-03: continue as an
## unrelated young juvenile; MODES-01: Standard until the main life is finished, then Easy; free play apart; spec 11: every death
## explained by what the player could have learned, a summary of the life without a score):
##   * starving kills only under Standard rules, and only long after the screen says so: starving, then weak (too hungry to sleep), then,
##     a day later, death;
##   * Gentle rules (Easy, free play) never starve and the wasp only touches the spider and leaves;
##   * the end: a plain line, a short summary (no score), back to the last rest or on as another spider (somewhere new, unrelated, the
##     notebook kept, the old life put away);
##   * finishing the main life opens Easy; the start menu offers it then, and free play from the start, with its own save;
##   * checkpoints keep the mode and rules; the player's progress is kept only when settings are saved.

const Checkpoint = preload("res://scripts/persistence/checkpoint.gd")
const WaspDirector = preload("res://scripts/predator/wasp_director.gd")
const NeedsModel = preload("res://scripts/needs/needs_model.gd")
const HabitatLoop = preload("res://scripts/habitat/habitat_loop.gd")
const CaughtPanel = preload("res://scripts/presentation/caught_panel.gd")
const StartMenu = preload("res://scripts/presentation/start_menu.gd")
const Progress = preload("res://scripts/life/progress.gd")

const HOME := Vector3(-25.0, 0.31, 6.0)
const OPEN_FLOOR := Vector3(2.0, 0.31, 6.0)
const TEMP_PROGRESS := "user://jss_test_progress.cfg"


func after_each() -> void:
	if FileAccess.file_exists(TEMP_PROGRESS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PROGRESS))


func _sill(pose: Transform3D, interactive: bool = false) -> void:
	use_windowsill = true
	await spawn_prey_world(pose, 0, PREY_SEED, interactive)
	await wait_until(func() -> bool: return world.spider.state == world.spider.State.ATTACHED, 60)


## Empties the test worlds' checkpoint folders (kept between tests and runs).
func _clear_test_saves() -> void:
	for d in [TEST_SAVE_DIR, TEST_SAVE_DIR.path_join("free")]:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		for f in dir.get_files():
			dir.remove(f)


## `hours` of waking game time pass for the needs (used up at their next update), then a tick for the habitat loop to look.
func _pass_hours(hours: float) -> void:
	var needs: RefCounted = world.needs
	needs.add_hours(hours, false)
	needs.advance(NeedsModel.UPDATE_PERIOD_S * 0.5, false)
	needs.advance(NeedsModel.UPDATE_PERIOD_S * 0.5, false)
	await physics_frames(1)


func test_starving_is_warned_long_before_it_kills() -> void:
	await _sill(Transform3D(Basis(Vector3.UP, 0.0), HOME))
	var loop: Node = world.habitat_loop
	var ended := [""]
	world.life_ended_signal.connect(func(cause: String, _s: Dictionary) -> void: ended[0] = cause)
	world.needs.configure({"energy": 0.02})
	await _pass_hours(2.0)
	check(world.needs.is_starving(), "the reserve runs out")
	check(loop.caption().contains("Starving"), "and the screen says so: %s" % loop.caption())
	await _pass_hours(HabitatLoop.WEAK_AFTER_H - world.needs.starving_streak_h - 0.5)
	check(not loop.too_hungry_to_sleep() and ended[0] == "", "nearly a day at zero: still alive, still warned")
	await _pass_hours(1.0)
	check(loop.too_hungry_to_sleep(), "then weak")
	check(loop.caption().contains("will not last another day"), "and the screen says it will not last another day: %s" % loop.caption())
	loop.clock.hour = 22.0
	check(loop.request_rest(), "it rests in the crack at night")
	await physics_frames(3)
	check(loop.resting and not loop.asleep, "but it is too hungry to sleep")
	loop.stop_rest()
	await _pass_hours(HabitatLoop.STARVE_AFTER_H - world.needs.starving_streak_h - 0.5)
	check_eq(ended[0], "", "nearly two days at zero and alive")
	world.needs.grant_energy(0.3, "test_fly")
	check_eq(world.needs.starving_streak_h, 0.0, "a meal ends the starving")
	world.needs.configure({"energy": 0.0})
	await _pass_hours(HabitatLoop.STARVE_AFTER_H + 0.5)
	check_eq(ended[0], "starved", "two days at zero kills under Standard rules")
	check(HabitatLoop.STARVE_AFTER_H - HabitatLoop.WEAK_AFTER_H >= 24.0, "a whole day of 'weak' before the end")


func test_gentle_rules_never_starve_and_the_wasp_only_touches() -> void:
	world_rules = "gentle"
	await _sill(floor_pose(OPEN_FLOOR.x, OPEN_FLOOR.z, -90))
	check(world.needs.gentle, "gentle hunger")
	world.needs.configure({"energy": 0.5})
	await _pass_hours(10.0)
	check_near(world.needs.energy, 0.5 - 10.0 * NeedsModel.LIFE_DRAIN_AWAKE_PER_H * NeedsModel.GENTLE_DRAIN, 1.0e-4, "drains at half the rate")
	var ended := [""]
	world.life_ended_signal.connect(func(cause: String, _s: Dictionary) -> void: ended[0] = cause)
	await _pass_hours(400.0)
	check_near(world.needs.energy, NeedsModel.GENTLE_FLOOR, 1.0e-6, "and stops at the floor")
	check(not world.needs.is_starving() and world.needs.starving_streak_h == 0.0 and ended[0] == "", "never starving, never dying")
	world.end_life("starved")
	check(not world.life_ended, "nothing ends a gentle life")
	var wd: Node = world.wasp_director
	wd.force_visit("floor_middle")
	var n := [0]
	await wait_until(func() -> bool:
		n[0] += 1
		if wd.phase <= WaspDirector.Phase.SEARCHING:
			world.spider.set_intent(Vector3.RIGHT * (1.0 if (n[0] / 30) % 2 == 0 else -1.0), false)
		else:
			world.spider.set_intent(Vector3.ZERO, false)
		return wd.phase == WaspDirector.Phase.LEAVING or wd.phase == WaspDirector.Phase.CARRYING, 60 * 30)
	check(wd.spared_this_visit and wd.phase == WaspDirector.Phase.LEAVING, "the wasp looked, touched and gave up")
	check(not world.spider.seized, "the spider is free")
	check(world.habitat_loop.caption().contains("gave up"), "and the screen says so: %s" % world.habitat_loop.caption())


func test_the_end_is_plain_and_another_spider_goes_on() -> void:
	_clear_test_saves()
	await _sill(floor_pose(OPEN_FLOOR.x, OPEN_FLOOR.z, -90), true)
	var nb: Node = world.notebook
	world.feeding.meals_finished = 2
	world.habitat_loop.clock.day = 3
	world.habitat_loop.growth.stage = 1
	world.needs.configure({"energy": 0.01})
	await _pass_hours(1.0)
	check(nb.is_open("going_without_food"), "the notebook explains starving")
	world.end_life("starved")
	var panel: CanvasLayer = world.caught_panel
	check(panel.is_showing() and sandbox.get_tree().paused, "the end: the game waits")
	await wait_until(func() -> bool: return panel.shown_seconds >= CaughtPanel.QUIET_S + CaughtPanel.LINE_S + 0.1, 60 * 6)
	check_eq(str(panel._line.text), "The spider starved.", "one plain line")
	var text: String = (panel.find_child("Summary", true, false) as Label).text
	check(text.contains("It lived 2 days") and text.contains("juvenile, 1 moult") and text.contains("2 meals"), "a short summary: %s" % text)
	for word in ["score", "points", "kills", "rank"]:
		check(not text.to_lower().contains(word), "no %s" % word)
	check(not panel.find_child("Back", true, false).is_visible_in_tree(), "no rest to go back to")
	check(panel.find_child("Another", true, false).is_visible_in_tree(), "on as another spider")
	world.end_life("wasp")
	check_eq(world.progress.deaths, 1, "one death, counted once")
	var progress: RefCounted = world.progress
	var opened: Array = nb.opened.duplicate()
	var fresh: Node3D = panel.go_on_as_another()
	if not check(fresh != null, "a new world"):
		return
	world = fresh
	await wait_until(func() -> bool: return world.is_node_ready() and world.spider.state == world.spider.State.ATTACHED, 120)
	check(world.new_spider and not world.restored and world.progress == progress, "another spider, the same player")
	check_eq(progress.lives.size(), 1, "the life that ended is kept in the player's progress")
	check_eq(str(progress.lives[0]["cause"]), "starved", "with how it ended")
	var spot: Vector3 = world.NEW_SPIDER_SPOTS[1]
	check(Vector2(world.spider.global_position.x, world.spider.global_position.z).distance_to(Vector2(spot.x, spot.z)) < 0.5, "somewhere new on the sill")
	check(not world.lab.in_retreat(world.spider.global_position), "not in the crack")
	check(world.habitat_loop.notice.contains("not related"), "said plainly to be unrelated: %s" % world.habitat_loop.notice)
	check(world.habitat_loop.growth.stage == 0 and world.habitat_loop.clock.day == 1, "a young juvenile on its first day")
	for id: String in opened:
		check(world.notebook.is_open(id), "the notebook goes on (%s)" % id)
	check(world.memory.contacts().is_empty() if world.memory.has_method("contacts") else true, "and the old spider's memory does not")


func test_back_to_the_last_rest_after_a_death_and_continuing_puts_the_old_life_away() -> void:
	_clear_test_saves()
	await _sill(Transform3D(Basis(Vector3.UP, 0.0), HOME), true)
	check(world.habitat_loop.request_rest(), "rests")
	await physics_frames(3)
	world.habitat_loop.stop_rest()
	world.end_life("wasp")
	var panel: CanvasLayer = world.caught_panel
	await wait_until(func() -> bool: return panel.shown_seconds >= CaughtPanel.QUIET_S + CaughtPanel.LINE_S + 0.1, 60 * 6)
	check(panel.find_child("Back", true, false).is_visible_in_tree(), "back to the last rest is offered")
	var back: Node3D = panel.go_on()
	if not check(back != null, "it loads"):
		return
	world = back
	await wait_until(func() -> bool: return world.is_node_ready() and world.spider.state == world.spider.State.ATTACHED, 120)
	check(world.restored and not world.life_ended, "the spider at its last rest, alive")
	world.end_life("wasp")
	var fresh: Node3D = world.continue_as_another()
	world = fresh
	await wait_until(func() -> bool: return world.is_node_ready(), 60)
	check(not bool(world.available_checkpoint()["ok"]), "going on as another spider puts the old life's rest away")


func test_finishing_the_main_life_opens_easy_and_nothing_else_does() -> void:
	await _sill(Transform3D(Basis(Vector3.UP, 0.0), HOME))
	var progress: RefCounted = world.progress
	check(not progress.easy_unlocked(), "Easy is closed at first")
	world.rules = "gentle"
	world.habitat_loop.moulted.emit(3)
	check(not progress.finished_main_life, "a life on Easy does not finish the main life")
	world.rules = "standard"
	world.mode = "free"
	world.habitat_loop.moulted.emit(3)
	check(not progress.finished_main_life, "nor does free play")
	world.mode = "main"
	world.habitat_loop.moulted.emit(2)
	check(not progress.finished_main_life, "nor a subadult")
	world.habitat_loop.moulted.emit(3)
	check(progress.finished_main_life and progress.easy_unlocked(), "an adult of the main life on Standard does")
	check(world.habitat_loop.notice.contains("Easy"), "and the screen says Easy is open: %s" % world.habitat_loop.notice)


func test_the_start_menu_offers_lives_easy_when_earned_and_free_play() -> void:
	_clear_test_saves()
	show_start_menu = true
	await _sill(Transform3D(Basis(Vector3.UP, 0.0), HOME), true)
	await physics_frames(2)
	var menu: CanvasLayer = world.start_menu
	if not check(menu != null and menu.is_open(), "the start menu is open"):
		return
	check(sandbox.get_tree().paused, "and the game waits")
	check(not menu.find_child("Continue", true, false).visible, "no life to continue yet")
	check(not menu.find_child("NewLifeEasy", true, false).visible, "Easy is not offered before it is earned")
	check(menu.new_life(false) and not menu.is_open() and world.rules == "standard", "a new life on Standard")
	check(not sandbox.get_tree().paused, "and play begins")
	await wait_until(func() -> bool: return world.spider.state == world.spider.State.ATTACHED and world.spider.velocity.length() < 0.1, 120)
	check(world.habitat_loop.request_rest(), "rests (a life worth continuing)")
	await physics_frames(3)
	world.habitat_loop.stop_rest()
	world.progress.finished_main_life = true
	menu.open()
	check(menu.find_child("Continue", true, false).visible, "now there is a life to continue")
	check(menu.find_child("NewLifeEasy", true, false).visible, "and Easy, earned")
	check(not menu.new_life(true), "a new life over one that is going on asks first")
	check(menu.new_life(true) and world.rules == "gentle" and world.needs.gentle, "pressed again: a new life on Easy")
	check(not bool(world.available_checkpoint()["ok"]), "the old life was put away")
	check(world.habitat_loop.caption().begins_with("THE WINDOWSILL (EASY)"), "the top line says Easy")
	menu.open()
	var fresh: Node3D = menu.free_play()
	world = fresh
	await wait_until(func() -> bool: return world.is_node_ready() and world.spider.state == world.spider.State.ATTACHED, 120)
	check(world.mode == "free" and world.rules == "gentle", "free play is gentle")
	check(world.store_dir().ends_with("/free"), "with its own save: %s" % world.store_dir())
	check(world.habitat_loop.caption().begins_with("FREE PLAY"), "and says so")


func test_checkpoints_keep_the_mode_and_rules() -> void:
	_clear_test_saves()
	world_mode = "free"
	world_rules = "gentle"
	await _sill(Transform3D(Basis(Vector3.UP, 0.0), HOME))
	world.habitat_loop.request_rest()
	await physics_frames(3)
	var rec: Dictionary = world.last_checkpoint
	check_eq(int(rec["schema_version"]), Checkpoint.SCHEMA_VERSION, "the current schema")
	check_eq(rec["life_rules"], {"mode": "free", "rules": "gentle"}, "the mode and rules are kept")
	check(Checkpoint.validate(rec).is_empty(), "valid: %s" % "; ".join(Checkpoint.validate(rec)))
	var fresh: Node3D = world.return_to_checkpoint(rec)
	world = fresh
	await wait_until(func() -> bool: return world.is_node_ready(), 60)
	check(world.mode == "free" and world.rules == "gentle" and world.needs.gentle, "and come back")
	var old: Dictionary = rec.duplicate(true)
	old["schema_version"] = 6
	old.erase("life_rules")
	var up: Variant = Checkpoint.upgrade(old)
	check(Checkpoint.validate(up).is_empty() and up["life_rules"] == {"mode": "main", "rules": "standard"}, "an older checkpoint is the main life on Standard")
	var bad: Dictionary = rec.duplicate(true)
	bad["life_rules"] = {"mode": "free", "rules": "standard"}
	check(not Checkpoint.validate(bad).is_empty(), "free play on Standard is refused")


func test_the_players_progress_is_kept_only_when_saved() -> void:
	var p := Progress.new()
	p.path = ""
	p.finish_main_life()
	check(not FileAccess.file_exists(TEMP_PROGRESS), "in memory only: nothing written")
	var q := Progress.new()
	q.path = TEMP_PROGRESS
	q.record_death()
	q.record_life({"cause": "wasp", "hours": 30.0})
	check(q.finish_main_life(), "finished, the first time")
	check(not q.finish_main_life(), "and only once")
	var r := Progress.new()
	r.path = TEMP_PROGRESS
	r.load_saved()
	check(r.finished_main_life and r.deaths == 1 and r.lives.size() == 1, "kept and read back")
