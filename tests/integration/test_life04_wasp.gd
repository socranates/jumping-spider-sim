extends "res://tests/prey_test_case.gd"
## LIFE_DESIGN round 4, the mud dauber wasp (LIFE-03: the first predator; LIFE-01: death can be real, not sensationalized; spec 2: no
## threat behind the player and no unexplained death; spec 8.3: search, inspect, approach, strike, disengage):
##   * it comes at most once a day, by day, never on the first day or before the first meal, never while the spider rests, and the
##     same world meets the same wasp;
##   * every visit is heard ARRIVE_S before the wasp can look for anything, and every catch comes after a visible look (INSPECT_S);
##   * it finds a moving spider in the open, a still one only slowly, and nothing in the crack; a jump or a drop breaks its approach;
##   * it is movement to the spider's senses, never prey; its landing shakes the surface; its paths are clear of the sill;
##   * caught: the spider goes still and is carried off, the screen says so plainly and offers the way back; checkpoints keep the
##     wasp's record, and older ones are brought up.

const WaspDirector = preload("res://scripts/predator/wasp_director.gd")
const Checkpoint = preload("res://scripts/persistence/checkpoint.gd")
const CaughtPanel = preload("res://scripts/presentation/caught_panel.gd")
const VibrationSense = preload("res://scripts/perception/vibration_sense.gd")

const HOME := Vector3(-25.0, 0.31, 6.0)
const OPEN_FLOOR := Vector3(2.0, 0.31, 6.0)   # in the open, near the "floor_middle" place
## On the back wall, 4.5 up, near the "back_wall_west" place.
const ON_WALL := Transform3D(Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN), Vector3(-11.0, 4.5, -12.5 + 0.31))


func _sill(pose: Transform3D, interactive: bool = false) -> void:
	use_windowsill = true
	await spawn_prey_world(pose, 0, PREY_SEED, interactive)
	await wait_until(func() -> bool: return world.spider.state == world.spider.State.ATTACHED, 60)


func _wd() -> Node:
	return world.wasp_director


## When the first event of this kind (or starting with it) happened in the visit, -1 if it has not.
func _t(kind: String) -> float:
	for e: Dictionary in _wd().events:
		if str(e["kind"]).begins_with(kind):
			return float(e["t"])
	return -1.0


func _kinds() -> String:
	var out: Array[String] = []
	for e: Dictionary in _wd().events:
		out.append("%s@%.1f" % [e["kind"], e["t"]])
	return ", ".join(out)


## Keeps the spider pacing to and fro along `axis` until `until` is true (or max_ticks pass); then it stops.
func _pace(axis: Vector3, until: Callable, max_ticks: int) -> bool:
	var n := [0]
	var ok := await wait_until(func() -> bool:
		n[0] += 1
		var s: Node3D = world.spider
		if s.state == s.State.ATTACHED:
			s.set_intent(axis * (1.0 if (n[0] / 30) % 2 == 0 else -1.0), false)
		return until.call(), max_ticks)
	world.spider.set_intent(Vector3.ZERO, false)
	return ok


func test_when_it_comes() -> void:
	await _sill(floor_pose(-13.0, 6.0, -90))
	var wd := _wd()
	var loop: Node = world.habitat_loop
	check_eq(wd.planned_hour(1), -1.0, "never on the first day")
	var days_with := 0
	for day in range(2, 42):
		var h: float = wd.planned_hour(day)
		if h >= 0.0:
			days_with += 1
			check(h >= WaspDirector.WINDOW_FROM_H and h < WaspDirector.WINDOW_TO_H, "day %d: by day (%.1f h)" % [day, h])
		check_eq(wd.planned_hour(day), h, "the same world, the same wasp (day %d)" % day)
	check(days_with >= 14 and days_with <= 34, "on some days, not all: %d of 40" % days_with)
	check_eq(wd.blocked(), "the first day", "the first day is for learning")
	var day := 2
	while wd.planned_hour(day) < 0.0:
		day += 1
	loop.clock.day = day
	loop.clock.hour = wd.planned_hour(day) + 0.05
	check_eq(wd.blocked(), "no meal yet", "not before the first meal")
	world.feeding.meals_finished = 1
	loop.resting = true
	check_eq(wd.blocked(), "resting", "not while resting")
	loop.resting = false
	check_eq(wd.blocked(), "", "otherwise nothing stands in its way")
	wd.enabled = true
	await physics_frames(2)
	check(wd.is_visiting(), "then, on its day and hour, it comes: %s" % wd.phase_name())
	check_eq(int(wd.last_visit_day), day, "and that is the day's visit")
	wd.phase = WaspDirector.Phase.AWAY
	wd.wasp.visible = false
	await physics_frames(3)
	check(not wd.is_visiting(), "once a day")


func test_it_is_heard_before_it_can_look() -> void:
	await _sill(floor_pose(OPEN_FLOOR.x, OPEN_FLOOR.z, -90))
	var wd := _wd()
	check(wd.force_visit("floor_middle"), "a visit")
	check_eq(_t("warning"), 0.0, "the warning is the visit's first moment")
	check(wd.wasp.global_position.distance_to(world.spider.global_position) > WaspDirector.SIGHT_WU * 3.0, "it starts far outside, over the frame")
	var seen_early := [false]
	await _pace(Vector3.RIGHT, func() -> bool:
		if wd.phase == WaspDirector.Phase.ARRIVING and wd.notice > 0.0:
			seen_early[0] = true
		return wd.phase != WaspDirector.Phase.ARRIVING, 60 * 20)
	check(not seen_early[0], "it looks for nothing while it arrives")
	check(_t("searching") >= WaspDirector.ARRIVE_S - 0.05, "and searches only after %.0f s: %s" % [WaspDirector.ARRIVE_S, _kinds()])
	check(wd.wasp.global_position.distance_to(WaspDirector.POINTS[WaspDirector.point_index("floor_middle")]["hover"]) < 0.05, "at the first place it looks")


func test_a_moving_spider_in_the_open_is_found_looked_at_and_caught() -> void:
	await _sill(floor_pose(OPEN_FLOOR.x, OPEN_FLOOR.z, -90))
	var wd := _wd()
	var got := [false, false]
	wd.caught.connect(func() -> void: got[0] = true)
	wd.carried_off.connect(func() -> void: got[1] = true)
	wd.force_visit("floor_middle")
	check(await _pace(Vector3.RIGHT, func() -> bool: return wd.phase == WaspDirector.Phase.INSPECTING, 60 * 20), "moving in the open, it is found: %s" % _kinds())
	check(_t("noticed") - _t("searching") < 2.5, "and quickly (%.1f s)" % (_t("noticed") - _t("searching")))
	check(await wait_until(func() -> bool: return got[0], 60 * 6), "keeping still now, close by, it is caught: %s" % _kinds())
	check(_t("caught") - _t("noticed") >= WaspDirector.INSPECT_S + WaspDirector.STRIKE_S - 0.02, "only after the wasp came and looked (%.2f s)" % (_t("caught") - _t("noticed")))
	check(_t("caught") - _t("warning") >= WaspDirector.ARRIVE_S + WaspDirector.INSPECT_S, "and long after it was first heard")
	var s: Node3D = world.spider
	check(s.seized and not s.is_physics_processing(), "the spider goes still")
	check(not s.can_prepare() and not s.begin_drop()["ok"], "and can do nothing more")
	check(await wait_until(func() -> bool: return got[1], 60 * 6), "the wasp carries it away")
	check(s.global_position.distance_to(wd.wasp.global_position + Vector3.DOWN * WaspDirector.HOLD_BELOW) < 0.05, "held under the wasp")
	check(s.global_position.y > 10.0, "up and away over the frame: %s" % s.global_position)


func test_a_still_spider_is_found_slowly_and_the_crack_never() -> void:
	await _sill(floor_pose(OPEN_FLOOR.x, OPEN_FLOOR.z, -90))
	var wd := _wd()
	wd.force_visit("floor_middle")
	await wait_until(func() -> bool: return wd.phase == WaspDirector.Phase.SEARCHING, 60 * 12)
	var s: Node3D = world.spider
	check(wd.can_see_spider(), "it can see the spider in the open")
	var still: float = wd.notice_rate()
	s.velocity = Vector3.RIGHT * float(s.get("_walk_speed"))
	var moving: float = wd.notice_rate()
	s.velocity = Vector3.ZERO
	check(moving > still * 5.0, "moving is noticed far faster than keeping still (%.2f against %.2f per s)" % [moving, still])
	check(still * WaspDirector.HOVER_S.y < 1.0, "a still spider outlasts one look from close by")
	world.queue_free()
	await physics_frames(2)
	await _sill(Transform3D(Basis(Vector3.UP, 0.0), HOME))
	wd = _wd()
	check(world.lab.in_retreat(world.spider.global_position), "at home in the crack")
	var ever := [false]
	var left := [false, true]
	wd.left.connect(func(escaped: bool) -> void:
		left[0] = true
		left[1] = escaped)
	wd.force_visit("crack_mouth")
	await _pace(Vector3.BACK, func() -> bool:
		if wd.notice > 0.0 or wd.can_see_spider():
			ever[0] = true
		return left[0], 60 * 80)
	check(left[0], "it gives up and leaves: %s" % _kinds())
	check(not ever[0], "never once seeing the spider moving about in the crack")
	check(not left[1], "and it was never close")
	check(_t("left") >= WaspDirector.ARRIVE_S + WaspDirector.SEARCH_S - 0.1, "after its whole search: %s" % _kinds())


func test_a_drop_or_a_jump_breaks_its_approach() -> void:
	await _sill(ON_WALL)
	var wd := _wd()
	var s: Node3D = world.spider
	check_eq(s.support.surface_id, "back_frame", "on the back wall")
	wd.force_visit("back_wall_west")
	check(await _pace(Vector3.UP, func() -> bool: return wd.phase == WaspDirector.Phase.INSPECTING, 60 * 20), "seen on the wall: %s" % _kinds())
	check(s.begin_drop()["ok"], "it lets itself down on its line")
	await physics_frames(3)
	check(_t("lost:dropped") > 0.0, "and the wasp loses it: %s" % _kinds())
	check(wd.confused_s > 0.0 and wd.phase == WaspDirector.Phase.SEARCHING, "and is confused for a while")
	await physics_frames(60 * 3)
	check(_t("caught") < 0.0, "no catch")
	world.queue_free()
	await physics_frames(2)
	await _sill(floor_pose(OPEN_FLOOR.x, OPEN_FLOOR.z, -90))
	wd = _wd()
	s = world.spider
	wd.force_visit("floor_middle")
	check(await _pace(Vector3.RIGHT, func() -> bool: return wd.phase == WaspDirector.Phase.INSPECTING, 60 * 20), "seen on the floor")
	await physics_frames(2)
	var hop: RefCounted = s.plan_hop(2.0)
	check(hop.is_valid() and s.begin_prepare() and s.commit_jump(hop), "it jumps away")
	await physics_frames(3)
	check(_t("lost:jumped") > 0.0, "and the wasp loses it: %s" % _kinds())


func test_what_the_spider_senses_of_it_and_where_it_flies() -> void:
	await _sill(floor_pose(OPEN_FLOOR.x, OPEN_FLOOR.z, -90))
	var wd := _wd()
	check(wd.wasp.get_percept().is_empty(), "away, there is nothing to sense")
	wd.force_visit("floor_middle")
	await physics_frames(2)
	var p: Dictionary = wd.wasp.get_percept()
	check_eq(p["max_category"], Observation.MOVEMENT, "to the spider it is movement, never prey")
	for point: Dictionary in WaspDirector.POINTS:
		var hover: Vector3 = point["hover"]
		check(wd._clear(hover + Vector3.UP * 0.01, hover), "%s: room to hover" % point["id"])
		check(wd._clear(hover, Vector3(hover.x, WaspDirector.CRUISE_Y, hover.z)), "%s: open straight up" % point["id"])
		check(wd._clear(WaspDirector.OVER, Vector3(hover.x, WaspDirector.CRUISE_Y, hover.z)), "%s: reached from over the frame" % point["id"])
		if point.has("land"):
			var land: Vector3 = point["land"]
			check(wd._clear(hover, land + Vector3.UP * 0.25), "%s: a clear way down to land" % point["id"])
			check(not wd._ray(land, land + Vector3.DOWN * 0.5).is_empty(), "%s: ground under the landing" % point["id"])
	check(wd._clear(WaspDirector.ENTRY, WaspDirector.OVER), "in over the frame without touching it")
	# The landing shakes the surface: felt close by, heavier than a fly's.
	var v: Node = world.vibration
	var at := OPEN_FLOOR + Vector3(2.0, -0.31, 0.0)
	var heavy: Dictionary = v.shake(at, "heavy landing")
	var fly: Dictionary = v.shake(at, "landing")
	check(heavy["felt"] and float(heavy["strength"]) > float(fly["strength"]), "the spider feels it land, more than a fly")


func test_the_spider_feels_it_land() -> void:
	await _sill(floor_pose(OPEN_FLOOR.x, OPEN_FLOOR.z, -90))
	var wd := _wd()
	var lands := [0]
	wd.landed.connect(func(_p: Vector3) -> void: lands[0] += 1)
	wd.force_visit("floor_middle")
	await wait_until(func() -> bool: return lands[0] > 0 or not wd.is_visiting(), 60 * 70)
	if not check(lands[0] > 0, "on this visit it lands somewhere: %s" % _kinds()):
		return
	var shakes := (world.vibration.all_log as Array).filter(func(e: Dictionary) -> bool: return str(e["kind"]) == "heavy landing")
	check(not shakes.is_empty(), "and its landing shakes the surface")


## Empties the test worlds' checkpoint folder (it is kept between tests and runs), so this world has no rest to go back to.
func _clear_test_saves() -> void:
	var dir := DirAccess.open(TEST_SAVE_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)


func test_caught_the_screen_says_so_plainly_and_offers_the_way_back() -> void:
	_clear_test_saves()
	await _sill(floor_pose(OPEN_FLOOR.x, OPEN_FLOOR.z, -90), true)
	var wd := _wd()
	var nb: Node = world.notebook
	wd.force_visit("floor_middle")
	await physics_frames(2)
	check(nb.is_open("mud_dauber"), "the first visit opens its notebook page")
	check(world.habitat_loop.caption().contains("wasps hunt spiders"), "the first visit says what wasps do: %s" % world.habitat_loop.caption())
	check(world.habitat_loop.caption().contains("F / D-pad down"), "and names the way down")
	check(world.soundscape.wasp_humming(), "it is heard")
	check(await _pace(Vector3.RIGHT, func() -> bool: return wd.phase == WaspDirector.Phase.INSPECTING, 60 * 20), "found")
	check(world.habitat_loop.caption().contains("has seen you"), "the screen says so: %s" % world.habitat_loop.caption())
	var panel: CanvasLayer = world.caught_panel
	check(await wait_until(func() -> bool: return panel.is_showing(), 60 * 12), "caught and carried off, the screen shows it")
	check(nb.is_open("what_the_wasp_does"), "the notebook tells what the wasp does")
	check(get_tree_paused(), "and the game waits")
	check(not world.needs_hud.visible, "live HUD does not clutter the catch screen")
	await wait_until(func() -> bool: return panel.shown_seconds >= CaughtPanel.QUIET_S + CaughtPanel.LINE_S + 0.1, 60 * 6)
	check(panel.find_child("Another", true, false).is_visible_in_tree(), "then the way on")
	check(not panel.find_child("Back", true, false).is_visible_in_tree(), "no rest yet: on as another spider")
	var fresh: Node3D = panel.go_on()
	if not check(fresh != null, "a new world"):
		return
	world = fresh
	await wait_until(func() -> bool: return world.is_node_ready() and world.spider.state == world.spider.State.ATTACHED, 120)
	check(not world.restored and not world.spider.seized and world.new_spider, "another spider at the start of its life")
	check(not sandbox.get_tree().paused, "and the game goes on")


func test_caught_after_resting_goes_back_to_the_rest() -> void:
	await _sill(Transform3D(Basis(Vector3.UP, 0.0), HOME), true)
	var loop: Node = world.habitat_loop
	check(loop.request_rest(), "rests in the crack")
	await physics_frames(3)
	check(not world.last_checkpoint.is_empty(), "and keeps a checkpoint")
	loop.stop_rest()
	world.spider.teleport_to(floor_pose(OPEN_FLOOR.x, OPEN_FLOOR.z, -90))
	await wait_until(func() -> bool: return world.spider.state == world.spider.State.ATTACHED, 60)
	var wd := _wd()
	wd.force_visit("floor_middle")
	await _pace(Vector3.RIGHT, func() -> bool: return wd.phase == WaspDirector.Phase.INSPECTING, 60 * 20)
	var panel: CanvasLayer = world.caught_panel
	check(await wait_until(func() -> bool: return panel.is_showing(), 60 * 12), "caught")
	await wait_until(func() -> bool: return panel.shown_seconds >= CaughtPanel.QUIET_S + CaughtPanel.LINE_S + 0.1, 60 * 6)
	check_eq((panel.find_child("Back", true, false) as Button).text, CaughtPanel.BACK, "back to the last rest")
	var back: Node3D = panel.go_on()
	if not check(back != null, "it loads"):
		return
	world = back
	await wait_until(func() -> bool: return world.is_node_ready() and world.spider.state == world.spider.State.ATTACHED, 120)
	check(world.restored and world.lab.in_retreat(world.spider.global_position), "at the last rest, in the crack")
	check(not _wd().is_visiting(), "with the wasp away")


func test_checkpoints_keep_the_wasp_and_older_ones_are_brought_up() -> void:
	await _sill(Transform3D(Basis(Vector3.UP, 0.0), HOME))
	var wd := _wd()
	wd.last_visit_day = 4
	wd.visits = 3
	wd.escapes = 2
	world.habitat_loop.request_rest()
	await physics_frames(3)
	var rec: Dictionary = world.last_checkpoint
	check_eq(int(rec["schema_version"]), Checkpoint.SCHEMA_VERSION, "the current schema")
	check(Checkpoint.validate(rec).is_empty(), "valid: %s" % "; ".join(Checkpoint.validate(rec)))
	check_eq(rec["wasp"], {"last_visit_day": 4, "visits": 3, "escapes": 2}, "the wasp's record is kept")
	var fresh: Node3D = world.return_to_checkpoint(rec)
	if not check(fresh != null, "it loads"):
		return
	world = fresh
	await wait_until(func() -> bool: return world.is_node_ready() and world.wasp_director != null, 60)
	check(world.wasp_director.last_visit_day == 4 and world.wasp_director.visits == 3 and world.wasp_director.escapes == 2, "and comes back")
	var old: Dictionary = rec.duplicate(true)
	old["schema_version"] = 5
	old.erase("wasp")
	var up: Variant = Checkpoint.upgrade(old)
	check(Checkpoint.validate(up).is_empty(), "a schema 5 checkpoint is brought up: %s" % "; ".join(Checkpoint.validate(up)))
	check_eq(up["wasp"], WaspDirector.default_record(), "with no visits yet")
	for bad: Dictionary in [{"last_visit_day": -1, "visits": 0, "escapes": 0}, {"last_visit_day": 2, "visits": 1, "escapes": 2},
			{"last_visit_day": 2, "visits": 1.5, "escapes": 0}]:
		check(not WaspDirector.problems(bad).is_empty(), "refused: %s" % str(bad))


func get_tree_paused() -> bool:
	return sandbox.get_tree().paused
