extends "res://tests/tether_test_case.gd"
## Gate M03 (spec 25): the tether catches recoverable misses in ten fixtures, and reeling reaches a valid
## surface or reports blockage, without clipping, endless oscillation or unexplained energy gain. The energy part of
## the gate is "no unexplained energy gain within the documented allowances" (A-019): the allowances are listed below
## and in the report, and an unqualified conservation claim is not made.
##
## The ten fixtures run at the same time in one world, each with its own spider (spiders collide only with the
## world), its own practice perch and its own coroutine. A miss is made the way a player can make one: a jump is
## planned and committed to a perch that then drops away (or, for the glancing fixture, a coated plate moves into
## the path after launch). After the line catches, the fixture's recovery runs: wait for the swing to settle (no
## input), then reel in until the spider takes hold of a surface or reeling reports a stop; or lower until it
## reaches the floor; or, where an obstacle snags the line, check that reeling is refused, lower, and let go.
## Every tick on a line is traced by the motor and checked: the body never overlaps the world; 0 <= paid <= rest
## <= max; the path never exceeds the rest length; the constraint only ever removes outward radial speed (it never
## pushes inward or outward and leaves tangential motion alone); and the mechanical energy (per unit mass, 0.5 v^2
## + g y) never rises above the start of the tick plus the reel's work (itself bounded by shortening x
## (g + v^2 / L)), the seat step when the legs take hold of a surface, and what the physics engine's collision
## recovery lifted the body by when it was pressed into something (at most CONTACT_LIFT_MAX = 0.002 WU a tick, which is
## 0.02 mm at 1 WU = 1 cm = 10 mm; the report gives the measured maximum in WU and in mm). A hanging spider that has come to rest is held there; the swing must settle (or end in a
## hold) within 10 s. The line itself may pass through geometry only on ticks flagged as snagged (no general rope
## wrapping), which are counted. Writes tests/reports/m03_report.txt.

const SpiderScene = preload("res://scenes/actors/spider.tscn")
const Evidence := preload("res://tests/evidence.gd")
const REPORT_PATH := "res://tests/reports/m03_report.txt"
const G := 35.0
const SEAT := 0.31

var _results: Array[Dictionary] = []


func _wall_pose(point: Vector3, normal: Vector3) -> Transform3D:
	return Transform3D(SupportMath.body_basis(normal, Vector3.UP), point + normal * SEAT)


func _fixtures() -> Array[Dictionary]:
	var top_face := func(x: float, y: float, z: float, heading: Vector3) -> Transform3D:
		return Transform3D(SupportMath.body_basis(Vector3.UP, heading), Vector3(x, y + SEAT, z))
	return [
		{"name": "F01 miss off a ledge edge: the practice bridge between the towers drops", "pose": top_face.call(-15.6, 10.0, -2.0, Vector3.RIGHT),
			"target_xz": Vector2(-10.5, -2.0), "perch": [], "after": "reel"},
		{"name": "F02 long-jump miss: 8.5 WU off tower_e", "pose": top_face.call(-3.4, 10.0, -2.5, Vector3.RIGHT),
			"target_xz": Vector2(5.1, -2.5), "perch": [Vector3(4.6, 9.6, -3.0), Vector3(5.6, 10.0, -2.0)], "after": "reel"},
		{"name": "F03 miss off the cliff cap: hang below its lip clear of the coating, reel up", "pose": top_face.call(24.6, 6.4, -7.0, Vector3.RIGHT),
			"target_xz": Vector2(27.3, -7.0), "perch": [], "after": "reel"},
		{"name": "F04 miss off the slab's edge: hang below it, reel up into its underside", "pose": top_face.call(17.0, 4.6, 5.0, Vector3.FORWARD),
			"target_xz": Vector2(17.0, 2.5), "perch": [Vector3(16.5, 4.2, 2.0), Vector3(17.5, 4.6, 3.0)], "after": "reel"},
		{"name": "F05 overshoot the cliff cap from the east wall: caught over its far lip, reel up", "pose": _wall_pose(Vector3(30.0, 8.0, -5.6), Vector3.LEFT),
			"target_xz": Vector2(19.7, -5.6), "perch": [Vector3(19.2, 6.2, -6.1), Vector3(20.2, 6.6, -5.1)], "after": "reel"},
		{"name": "F06 glancing contact: a coated plate moves into the path", "pose": top_face.call(-17.4, 10.0, -2.5, Vector3.LEFT),
			"target_xz": Vector2(-22.4, -2.5), "perch": [Vector3(-22.9, 9.6, -3.0), Vector3(-21.9, 10.0, -2.0)], "after": "reel", "plate": true},
		{"name": "F07 falling past a wall: jump away from the north wall", "pose": _wall_pose(Vector3(15.0, 7.0, -17.5), Vector3.BACK),
			"target_xz": Vector2(15.0, -13.0), "perch": [Vector3(14.5, 5.6, -13.5), Vector3(15.5, 6.0, -12.5)], "after": "reel"},
		{"name": "F08 a line snagged by an obstacle: reeling reports it, lower, let go", "pose": top_face.call(12.0, 4.6, 5.0, Vector3.FORWARD),
			"target_xz": Vector2(12.0, 2.5), "perch": [Vector3(11.5, 4.2, 2.0), Vector3(12.5, 4.6, 3.0)], "after": "snag"},
		{"name": "F09 a line anchored on clean glass: jump away from the pane", "pose": _wall_pose(Vector3(-9.0, 3.4, 15.5), Vector3.FORWARD),
			"target_xz": Vector2(-9.0, 13.0), "perch": [Vector3(-9.5, 2.6, 12.5), Vector3(-8.5, 3.0, 13.5)], "after": "reel"},
		{"name": "F10 miss off the slab's edge, then lower to the floor", "pose": top_face.call(14.5, 4.6, 5.0, Vector3.FORWARD),
			"target_xz": Vector2(14.5, 2.5), "perch": [Vector3(14.0, 4.2, 2.0), Vector3(15.0, 4.6, 3.0)], "after": "lower"},
	]


func _spawn_spider(pose: Transform3D) -> Node3D:
	var spider: Node3D = SpiderScene.instantiate()
	spider.profile = world.spider.profile
	spider.surfaces = world.surfaces
	spider.play_bounds = world.lab.get_play_bounds()
	spider.bounds_enabled = true
	spider.transform = pose
	world.add_child(spider)
	spider.jump_committed.connect(world.lab.on_jump_committed)
	world.lab.surface_availability_changed.connect(spider.on_surface_availability_changed)
	return spider


func test_m03_the_line_catches_ten_recoverable_misses_and_recovery_reaches_a_surface_or_reports_blockage() -> void:
	spawn_world(floor_pose(-22.0, 12.0, -90.0))
	world.lab.drop_resets = false
	var fixtures := _fixtures()
	for i in fixtures.size():
		var f: Dictionary = fixtures[i]
		if not (f["perch"] as Array).is_empty():
			world.lab.add_fixture_piece("m03_perch_%02d" % (i + 1), "drop", f["perch"][0], f["perch"][1])
	await physics_frames(3)
	_results.clear()
	for i in fixtures.size():
		_results.append({"name": fixtures[i]["name"], "done": false})
		_run_fixture(i, fixtures[i])
	var all_done := await wait_until(func() -> bool:
		for r in _results:
			if not r["done"]:
				return false
		return true, 60 * 40)
	check(all_done, "every fixture finished within 40 s")
	var lines := PackedStringArray()
	lines.append("M03 tether report (spec 25): ten recoverable misses caught by the safety line, recovery by reeling, lowering or letting go")
	lines.append("timestamp_utc: %sZ" % Time.get_datetime_string_from_system(true))
	lines.append(Evidence.describe(Evidence.identity("res://")))
	lines.append("engine: %s" % Engine.get_version_info()["string"])
	lines.append("fixture_seed: %d" % fixture_seed)
	lines.append("checked every tick on a line: no overlap with the world (sphere 0.005 WU under the collider); 0 <= paid <= rest <= max;")
	lines.append("  path <= rest + 0.01 WU; the constraint only removes outward radial speed (no push, tangential speed kept);")
	lines.append("  energy (0.5 v^2 + g y per unit mass) <= start of tick + reel work + the seat step when the legs take hold + the engine's")
	lines.append("  collision recovery (at most 0.002 WU = 0.02 mm of lift a tick, 1 WU = 1 cm = 10 mm; measured per fixture below) + 2e-4;")
	lines.append("  reel work <= shortening x (g + v^2 / L); the line clear of geometry except on ticks flagged as snagged")
	lines.append("energy gate (A-019): no unexplained energy gain within the documented allowances (reel work, the seat step, the engine's collision recovery, 2e-4)")
	var passed := 0
	for r in _results:
		var ok: bool = r.get("ok", false)
		if ok:
			passed += 1
		lines.append("%s %s" % ["PASS" if ok else "FAIL", r["name"]])
		lines.append("    %s" % str(r.get("detail", "did not finish")))
		for p in (r.get("problems", PackedStringArray()) as PackedStringArray).slice(0, 5):
			lines.append("    problem: %s" % p)
		check(ok, "%s: %s %s" % [r["name"], str(r.get("detail", "")), "; ".join((r.get("problems", PackedStringArray()) as PackedStringArray).slice(0, 3))])
	var summary := "M03 result: %d of %d fixtures caught and recovered or reported blockage, with no overlap, no push and no unexplained energy gain within the documented allowances" % [passed, _results.size()]
	lines.append("")
	lines.append(summary)
	print(summary)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/reports"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()


func _run_fixture(i: int, f: Dictionary) -> void:
	var r: Dictionary = _results[i]
	var spider := _spawn_spider(f["pose"])
	var events: Array[String] = []
	spider.line_event.connect(func(kind: String, detail: String) -> void: events.append(kind if detail == "" else "%s:%s" % [kind, detail]))
	if not await settle(spider, 60):
		_finish(r, spider, events, false, "did not start attached (%s)" % spider.get_state_name())
		return
	var target_xz: Vector2 = f["target_xz"]
	var target := top_target(target_xz.x, target_xz.y) if (f["perch"] as Array).is_empty() else ray_target(Vector3(target_xz.x, (f["perch"][1] as Vector3).y + 1.0, target_xz.y), Vector3(target_xz.x, -5.0, target_xz.y))
	var plan: RefCounted = spider.plan_jump(target)
	if not plan.is_valid():
		_finish(r, spider, events, false, "the planned jump was not reachable (%s, %s)" % [plan.kind_name(), plan.reason])
		return
	spider.trace_tether = true
	spider.begin_prepare()
	if not spider.commit_jump(plan):
		_finish(r, spider, events, false, "commit refused")
		return
	var reach := Vector2(plan.seat.x - plan.origin.x, plan.seat.z - plan.origin.z).length()
	var notes := PackedStringArray(["jump %.1f WU to %s" % [reach, plan.target_surface_id]])
	if f.get("plate", false):
		var mid: Vector3 = plan.path[plan.path.size() * 3 / 5]
		var d: Vector3 = (plan.path[plan.path.size() * 3 / 5 + 1] - mid).normalized()
		var side := Vector3(-d.z, 0.0, d.x).normalized()
		var c := mid + d * 0.45
		var a := c - side * 1.0 - Vector3(0.05, 1.0, 0.05)
		var b := c + side * 1.0 + Vector3(0.05, 1.0, 0.05)
		world.lab.add_fixture_piece("m03_plate_%02d" % (i + 1), "coated", a.min(b), a.max(b))
	# 1. The miss and the catch.
	await wait_until(func() -> bool: return events.has("caught") or spider.state == spider.State.ATTACHED, 240)
	if not events.has("caught"):
		_finish(r, spider, events, false, "the line did not catch (state %s, outcome %s)" % [spider.get_state_name(), str(spider.last_jump.get("outcome"))])
		return
	notes.append("outcome %s, caught %.2f s after launch with %.2f WU of line%s" % [str(spider.last_jump.get("outcome")), float(spider.tether.caught_tick - spider.tether.anchored_tick) / 60.0, spider.tether.rest_length, ", over a bend on " + spider.tether.bend_surface_id if spider.tether.has_bend else ""])
	# 2. The swing settles with no input, unless the spider takes hold of something first.
	var t0: int = spider.get_physics_tick()
	var settled := await wait_until(func() -> bool: return spider.state == spider.State.ATTACHED or (spider.state == spider.State.HANGING and spider.velocity == Vector3.ZERO), 600)
	if not settled:
		_finish(r, spider, events, false, "still swinging after 10 s (%s)" % spider.get_state_name())
		return
	if spider.state == spider.State.ATTACHED:
		notes.append("the swing carried it onto %s, which it took hold of, %.2f s after the catch" % [spider.support.surface_id, float(spider.get_physics_tick() - t0) / 60.0])
		_finish(r, spider, events, true, "; ".join(notes))
		return
	notes.append("came to rest %.2f s after the catch, %.2f WU above the floor" % [float(spider.get_physics_tick() - t0) / 60.0, spider.global_position.y - SEAT])
	# 3. Recovery.
	var after: String = f["after"]
	if after == "reel":
		var t1: int = spider.get_physics_tick()
		var done := await _hold_reel(spider, 1.0, 720)
		if spider.state == spider.State.ATTACHED:
			notes.append("reeled in for %.2f s and took hold of %s" % [float(spider.get_physics_tick() - t1) / 60.0, spider.support.surface_id])
			_finish(r, spider, events, true, "; ".join(notes))
		elif done:
			notes.append("reeling stopped and said why: %s" % (spider.tether.block_reason if spider.tether.block_reason != "" else "snagged"))
			_finish(r, spider, events, true, "; ".join(notes))
		else:
			_finish(r, spider, events, false, "; ".join(notes) + "; reeling neither reached a surface nor reported a stop")
	elif after == "lower":
		var t1: int = spider.get_physics_tick()
		await _hold_reel(spider, -1.0, 600)
		var ok: bool = spider.state == spider.State.ATTACHED and spider.support.surface_id == "floor"
		notes.append("lowered for %.2f s and %s" % [float(spider.get_physics_tick() - t1) / 60.0, "took hold of the floor" if ok else "did not reach the floor (%s)" % spider.get_state_name()])
		_finish(r, spider, events, ok, "; ".join(notes))
	else:
		var p: Vector3 = spider.global_position
		world.lab.add_fixture_piece("m03_snag_%02d" % (i + 1), "coated", Vector3(p.x - 0.6, p.y + 0.9, p.z - 0.6), Vector3(p.x + 0.6, p.y + 1.0, p.z + 0.6))
		await physics_frames(3)
		var snagged: bool = spider.tether.snagged
		var rest0: float = spider.tether.rest_length
		for k in 30:
			spider.set_reel_intent(1.0)
			await physics_frames(1)
		var refused: bool = absf(spider.tether.rest_length - rest0) < 1e-4
		for k in 30:
			spider.set_reel_intent(-1.0)
			await physics_frames(1)
		spider.set_reel_intent(0.0)
		var lowered: bool = spider.tether.rest_length > rest0 + 0.6
		var let_go: bool = spider.release_line()
		var landed := await wait_until(func() -> bool: return spider.state == spider.State.ATTACHED, 240)
		var ok: bool = snagged and refused and lowered and let_go and landed and spider.support.surface_id == "floor"
		notes.append("a coated plate across the line: snagged %s, reeling refused %s, lowered %s, let go %s, landed on %s" % [str(snagged), str(refused), str(lowered), str(let_go), spider.support.surface_id])
		_finish(r, spider, events, ok, "; ".join(notes))


## Reels (amount > 0) or lowers (< 0) until the spider takes hold of a surface, or (reeling) a stop is reported.
func _hold_reel(spider: Node3D, amount: float, max_ticks: int) -> bool:
	for k in max_ticks:
		if spider.state == spider.State.ATTACHED:
			return true
		if spider.state == spider.State.LANDING:
			spider.set_reel_intent(0.0)
		else:
			spider.set_reel_intent(amount)
		if amount > 0.0 and (spider.tether.block_reason != "" or spider.tether.snagged):
			spider.set_reel_intent(0.0)
			return true
		await physics_frames(1)
	spider.set_reel_intent(0.0)
	return spider.state == spider.State.ATTACHED


func _finish(r: Dictionary, spider: Node3D, events: Array[String], ok: bool, detail: String) -> void:
	var problems := PackedStringArray()
	var unclear := 0
	var snag_ticks := 0
	var ticks := 0
	var resting := 0
	var lift_ticks := 0
	var worst_lift := 0.0
	for t: Dictionary in spider.tether_trace:
		ticks += 1
		problems.append_array(tick_problems(t, G))
		if bool(t.get("resting", false)):
			resting += 1
		if float(t.get("contact_lift", 0.0)) > 0.0:
			lift_ticks += 1
			worst_lift = maxf(worst_lift, float(t["contact_lift"]) / G)
		if bool(t.get("snagged", false)):
			snag_ticks += 1
		elif t.has("line_clear") and not bool(t["line_clear"]) and str(t["mode"]) == "locked":
			unclear += 1
	if unclear > 0:
		problems.append("%d ticks with the line through geometry and no snag flagged" % unclear)
	if spider.tether_fallbacks > 0:
		problems.append("%d debug fallbacks" % spider.tether_fallbacks)
	if spider.last_jump.get("line_ran_out", false):
		problems.append("the line ran out during the leap")
	r["ok"] = ok and problems.is_empty()
	r["problems"] = problems
	r["detail"] = "%s. %d ticks traced, %d held at rest, %d with the line snagged (flagged), %d energy-limit ticks, engine contact recovery on %d ticks (at most %.6f WU = %.5f mm); events: %s" % [detail, ticks, resting, snag_ticks, spider.energy_clamps, lift_ticks, worst_lift, worst_lift * WU_TO_MM, ", ".join(events)]
	r["done"] = true
