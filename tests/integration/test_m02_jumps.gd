extends "res://tests/jump_test_case.gd"
## Gate M02 (spec 25): for 100 legal static-surface jumps spanning reach and height combinations, the
## planned and the actual landing centres differ by no more than 0.25 WU in calm conditions, and
## invalid candidates show invalid feedback (and do not launch).
##
## The jumps are set up in one world at the same time, each by its own spider (spiders collide with
## nothing but the world, so they cannot disturb each other). Launch surfaces: the floor, the four ledge
## tops, a gap platform, the south wall and the underside of the overhang. Targets: the floor, ledge and
## platform tops, and the south wall. Reaches 2 to 5 WU (horizontal distance between the launch centre and
## the planned landing centre), rises from -4.7 to +2.1 WU. A fixture-seed jitter moves every start and
## target a little. Chunk 5 (farther jumps): reaches now run from 2 WU to the new maximum (about 11 WU on the level,
## up to 13 WU jumping down from the 10 WU towers), in five reach bands. A candidate counts as legal when the shared solver finds a clear arc for it; the first
## 100 legal candidates are flown (the candidates the solver refuses are listed in the report with their
## reasons). Each is planned through the spider's own planner, committed, and flown by the real motor.
## For each jump: planned landing centre (the plan's seat) against the body centre at first contact, and
## against the settled body after LANDING, both at most TOLERANCE; the flight must also be the predicted path.
## Invalid candidates: for each, the plan is not reachable and names why, the motor refuses to commit
## it, and through the real controller the release cancels with invalid feedback (a patch that is not a
## solid ring, a label in words) and launches nothing. Writes tests/reports/m02_report.txt.

const SpiderScene = preload("res://scenes/actors/spider.tscn")
const Evidence := preload("res://tests/evidence.gd")
const REPORT_PATH := "res://tests/reports/m02_report.txt"
const TOLERANCE := 0.25
const JUMPS := 100
const SEAT := 0.31
const WALL_Z := 17.5
const REACH_EDGES := [3.0, 4.0, 5.5, 8.0]

var _cands: Array[Dictionary] = []


func _jit(amount: float) -> float:
	return rng.randf_range(-amount, amount)


func _on_floor(x: float, z: float, facing: Vector3) -> Transform3D:
	return Transform3D(SupportMath.body_basis(Vector3.UP, facing), Vector3(x + _jit(0.08), SEAT, z + _jit(0.08)))


func _on_top(x: float, z: float, top: float, facing: Vector3) -> Transform3D:
	return Transform3D(SupportMath.body_basis(Vector3.UP, facing), Vector3(x + _jit(0.08), top + SEAT, z + _jit(0.08)))


func _on_wall(x: float, y: float) -> Transform3D:
	return Transform3D(SupportMath.body_basis(Vector3(0.0, 0.0, -1.0), Vector3.UP), Vector3(x + _jit(0.08), y, WALL_Z - SEAT))


func _under(x: float, z: float, facing: Vector3) -> Transform3D:
	return Transform3D(SupportMath.body_basis(Vector3.DOWN, facing), Vector3(x + _jit(0.08), 3.0 - SEAT, z + _jit(0.08)))


func _add(label: String, pose: Transform3D, target: Dictionary) -> void:
	_cands.append({"name": label, "pose": pose, "target": target})


func _top(x: float, z: float) -> Dictionary:
	return top_target(x + _jit(0.12), z + _jit(0.12))


func _under_floor(x: float, z: float) -> Dictionary:
	return ray_target(Vector3(x + _jit(0.12), 2.5, z + _jit(0.12)), Vector3(x, -5.0, z))


func _wall_target(x: float, y: float) -> Dictionary:
	return ray_target(Vector3(x + _jit(0.12), y + _jit(0.12), 10.0), Vector3(x, y, 20.0))


## The fixture: explicit launch/target families, each a list of reaches, from 2 WU up to the new maximum
## (chunk 5: about 11 WU on the level, more when jumping down). The first 100 the solver accepts are flown,
## so the long families come first and the extra level floor jumps last. The reaches the speed limit makes
## impossible are left in a few families on purpose: the solver refuses them and the report lists why.
func _build_candidates() -> void:
	_cands.clear()
	for r in [2.0, 3.5, 5.0, 6.5, 8.0, 9.5, 11.0]:
		_add("floor to floor +x %.1f" % r, _on_floor(-28.0, 13.0, Vector3.RIGHT), _top(-28.0 + r, 13.0))
	for r in [2.5, 4.5, 6.0, 7.5, 9.0, 10.5]:
		_add("floor to floor -z %.1f" % r, _on_floor(2.5, 14.0, Vector3.FORWARD), _top(2.5, 14.0 - r))
	for r in [9.9, 10.4, 10.9]:
		_add("tower_w to tower_e %.1f" % r, _on_top(-15.6, -2.5, 10.0, Vector3.RIGHT), _top(-15.6 + r, -2.5))
		_add("tower_e to tower_w %.1f" % r, _on_top(-5.4, -2.5, 10.0, Vector3.LEFT), _top(-5.4 - r, -2.5))
	for r in [5.0, 8.0, 11.0, 13.0]:
		_add("tower_w to floor %.1f" % r, _on_top(-16.5, -1.6, 10.0, Vector3.BACK), _top(-16.5, -1.6 + r))
	for r in [4.0, 6.0]:
		_add("tower_e to floor %.1f" % r, _on_top(-4.5, -3.6, 10.0, Vector3.FORWARD), _top(-4.5, -3.6 - r))
	for r in [9.0, 10.5]:
		_add("gap_left to floor beyond gap_right %.1f" % r, _on_top(11.5, -3.0, 2.0, Vector3.RIGHT), _top(11.5 + r, -3.0))
	for ledge in [["ledge_1", -14.5, 1.0], ["ledge_2", -8.5, 2.0], ["ledge_3", -2.5, 3.5], ["ledge_4", 3.5, 5.0]]:
		for r in [2.5, 4.0, 5.5, 7.0]:
			_add("%s to floor %.1f" % [ledge[0], r], _on_top(float(ledge[1]), -11.5, float(ledge[2]), Vector3.BACK), _top(float(ledge[1]), -11.5 + r))
	for pair in [["ledge_1 to ledge_2", -13.5, 1.0, 1.0, [4.0, 5.0]], ["ledge_2 to ledge_1", -9.5, 2.0, -1.0, [4.0, 5.0]],
			["ledge_3 to ledge_2", -3.5, 3.5, -1.0, [4.0, 5.0]], ["ledge_4 to ledge_3", 2.5, 5.0, -1.0, [4.0, 5.0]],
			["ledge_2 to ledge_3", -7.5, 2.0, 1.0, [3.6, 4.0]], ["ledge_4 to ledge_2", 3.5, 5.0, -1.0, [12.0]], ["ledge_3 to ledge_1", -2.5, 3.5, -1.0, [12.0]]]:
		for r in pair[4]:
			var x0: float = float(pair[1])
			var x1: float = x0 + float(r) * float(pair[3])
			_add("%s %.1f" % [pair[0], r], _on_top(x0, -12.5, float(pair[2]), Vector3.RIGHT * float(pair[3])), _top(x1, -12.5))
	for r in [2.0, 3.0, 4.5]:
		_add("floor to ledge_1 from south %.1f" % r, _on_floor(-14.5, -12.0 + r, Vector3.FORWARD), _top(-14.5, -12.0))
	for r in [2.5, 4.0]:
		_add("floor to ledge_1 from west %.1f" % r, _on_floor(-14.5 - r, -12.5, Vector3.RIGHT), _top(-14.5, -12.5))
	for r in [2.0, 3.0]:
		_add("floor to ledge_2 from south %.1f" % r, _on_floor(-8.5, -12.0 + r, Vector3.FORWARD), _top(-8.5, -12.0))
	_add("floor to ledge_2 from west 2.5", _on_floor(-11.0, -12.5, Vector3.RIGHT), _top(-8.5, -12.5))
	for r in [2.0, 3.0]:
		_add("floor to gap_left from south %.1f" % r, _on_floor(10.0, -3.0 + r, Vector3.FORWARD), _top(10.0, -3.0))
	_add("floor to gap_left from west 2.5", _on_floor(6.5, -4.0, Vector3.RIGHT), _top(9.0, -4.0))
	for r in [4.0, 5.0]:
		_add("gap_left to gap_right %.1f" % r, _on_top(11.5, -4.0, 2.0, Vector3.RIGHT), _top(11.5 + r, -4.0))
		_add("gap_right to gap_left %.1f" % r, _on_top(15.5, -4.0, 2.0, Vector3.LEFT), _top(15.5 - r, -4.0))
	for r in [3.0, 5.0]:
		_add("gap_left to floor %.1f" % r, _on_top(10.0, -2.5, 2.0, Vector3.BACK), _top(10.0, -2.5 + r))
	for d in [2.0, 3.0, 4.0, 5.0, 6.5]:
		for h in [0.8, 2.4]:
			_add("floor to south wall %.1f at %.1f" % [d, h], _on_floor(0.0, WALL_Z - SEAT - d, Vector3.BACK), _wall_target(0.0, h))
	for d in [2.0, 3.0, 4.0, 5.0, 7.0]:
		for h in [1.5, 3.5]:
			_add("south wall at %.1f to floor %.1f" % [h, d], _on_wall(0.0, h), _top(0.0, WALL_Z - SEAT - d))
	for d in [2.0, 2.5, 3.0, 4.0]:
		_add("underside to floor west %.1f" % d, _under(23.0, 5.0, Vector3.LEFT), _under_floor(23.0 - d, 5.0))
		_add("underside to floor south %.1f" % d, _under(26.0, 8.5, Vector3.BACK), _under_floor(26.0, 8.5 + d))
	# Level floor jumps in other directions come last, so they are the ones left out when there are more than 100.
	for r in [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]:
		_add("floor to floor diagonal %.1f" % r, _on_floor(-28.0, 6.0, Vector3(1.0, 0.0, 1.0)), _top(-28.0 + r * 0.7071, 6.0 + r * 0.7071))
		_add("floor to floor -x %.1f" % r, _on_floor(4.0, 12.5, Vector3.LEFT), _top(4.0 - r, 12.5))


func _spawn_spider(pose: Transform3D) -> Node3D:
	var spider: Node3D = SpiderScene.instantiate()
	spider.profile = world.spider.profile
	spider.surfaces = world.surfaces
	spider.play_bounds = world.lab.get_play_bounds()
	spider.bounds_enabled = true
	spider.transform = pose
	world.add_child(spider)
	return spider


func _band(value: float, edges: Array) -> int:
	var k := 0
	for e: float in edges:
		if value >= e:
			k += 1
	return k


func test_m02_planned_and_actual_landing_centres_agree_and_invalid_candidates_say_so() -> void:
	spawn_world(floor_pose(-22.0, 12.0, -90.0), true)
	await physics_frames(3)  # the lab's bodies are visible to ray casts after the first physics tick
	_build_candidates()
	var spiders: Array[Node3D] = []
	for c in _cands:
		spiders.append(_spawn_spider(c["pose"]))
	await physics_frames(10)
	var chosen: Array[Dictionary] = []
	var refused: Array[Dictionary] = []
	for i in _cands.size():
		var spider := spiders[i]
		var c: Dictionary = _cands[i]
		if not (spider.state == spider.State.ATTACHED and spider.support.is_valid()):
			check(false, "candidate '%s' did not start attached (%s)" % [c["name"], spider.get_state_name()])
			continue
		check(point_is_clear_in_physics(spider.global_position, 0.299), "candidate '%s' starts clear of geometry" % c["name"])
		var plan: RefCounted = spider.plan_jump(c["target"])
		if plan.is_valid() and chosen.size() < JUMPS:
			chosen.append({"i": i, "name": c["name"], "spider": spider, "plan": plan, "from": spider.support.surface_id})
		elif not plan.is_valid():
			refused.append({"name": c["name"], "kind": plan.kind_name(), "reason": plan.reason})
	check(chosen.size() == JUMPS, "the fixture offers %d legal jumps (%d candidates, %d refused by the solver)" % [chosen.size(), _cands.size(), refused.size()])
	for j in chosen:
		var spider: Node3D = j["spider"]
		check(spider.begin_prepare(), "%s: preparing starts" % j["name"])
		check(spider.commit_jump(j["plan"]), "%s: the plan is committed" % j["name"])
	var done := await wait_until(func() -> bool:
		for j in chosen:
			var rec: Dictionary = (j["spider"] as Node3D).last_jump
			if rec.is_empty() or str(rec["outcome"]) == "":
				return false
		return true, 150)
	check(done, "every flight ends")
	await wait_until(func() -> bool:
		for j in chosen:
			var s: Node3D = j["spider"]
			if not (s.state == s.State.ATTACHED and s.support.is_valid()):
				return false
		return true, 60)
	var contact_errors := PackedFloat64Array()
	var settled_errors := PackedFloat64Array()
	var path_worst := 0.0
	var lines := PackedStringArray()
	lines.append("M02 jump report (spec 25): planned landing centre against the actual landing centre, calm static scenes")
	lines.append("timestamp_utc: %sZ" % Time.get_datetime_string_from_system(true))
	lines.append(Evidence.describe(Evidence.identity("res://")))
	lines.append("engine: %s" % Engine.get_version_info()["string"])
	lines.append("fixture_seed: %d" % fixture_seed)
	lines.append("tolerance: %.2f WU between the planned landing centre (the plan's seat) and the body centre, at first contact and after LANDING" % TOLERANCE)
	var reach_bins := [0, 0, 0, 0, 0]
	var reach_max := 0.0
	var rise_bins := [0, 0, 0]
	var ok_count := 0
	for k in chosen.size():
		var j: Dictionary = chosen[k]
		var spider: Node3D = j["spider"]
		var plan: RefCounted = j["plan"]
		var rec: Dictionary = spider.last_jump
		var reach := Vector2(plan.seat.x - plan.origin.x, plan.seat.z - plan.origin.z).length()
		var rise: float = plan.seat.y - plan.origin.y
		reach_max = maxf(reach_max, reach)
		var e_contact := float(rec["error_contact"])
		var e_settled := float(rec["error_settled"])
		var actual: PackedVector3Array = rec["path"]
		var worst := 0.0
		for s in range(0, mini(actual.size(), plan.path.size())):
			worst = maxf(worst, actual[s].distance_to(plan.path[s]))
		path_worst = maxf(path_worst, worst)
		contact_errors.append(e_contact)
		settled_errors.append(e_settled)
		reach_bins[_band(reach, REACH_EDGES)] += 1
		rise_bins[_band(rise, [-0.5, 0.5])] += 1
		var ok: bool = str(rec["outcome"]) == "support" and e_contact <= TOLERANCE and e_settled <= TOLERANCE and str(rec["landed_surface"]) == plan.target_surface_id
		if ok:
			ok_count += 1
		var line := "jump %03d %s: %s, from %s to %s, reach %.2f WU, rise %+.2f WU, speed %.2f WU/s, %.3f s, planned centre (%.2f, %.2f, %.2f), contact error %.4f WU, settled error %.4f WU, path deviation %.5f WU, landed on %s" % [
			k + 1, "PASS" if ok else "FAIL", j["name"], j["from"], plan.target_surface_id, reach, rise, plan.speed, plan.duration,
			plan.seat.x, plan.seat.y, plan.seat.z, e_contact, e_settled, worst, rec["landed_surface"]]
		lines.append(line)
		check_eq(rec["outcome"], "support", "%s: lands on support" % j["name"])
		check_eq(rec["landed_surface"], plan.target_surface_id, "%s: on the surface it was aimed at" % j["name"])
		check(e_contact <= TOLERANCE, "%s: contact within %.2f WU of the plan, %f" % [j["name"], TOLERANCE, e_contact])
		check(e_settled <= TOLERANCE, "%s: settled within %.2f WU of the plan, %f" % [j["name"], TOLERANCE, e_settled])
	var max_contact := 0.0
	var max_settled := 0.0
	var sum_contact := 0.0
	var sum_settled := 0.0
	for k in chosen.size():
		max_contact = maxf(max_contact, contact_errors[k])
		max_settled = maxf(max_settled, settled_errors[k])
		sum_contact += contact_errors[k]
		sum_settled += settled_errors[k]
	var n := maxi(chosen.size(), 1)
	lines.append("")
	lines.append("coverage: reach 2 to 3 WU: %d, 3 to 4 WU: %d, 4 to 5.5 WU: %d, 5.5 to 8 WU: %d, 8 WU and more: %d (longest %.2f WU); rise below -0.5 WU: %d, level (within 0.5 WU): %d, above +0.5 WU: %d" % [reach_bins[0], reach_bins[1], reach_bins[2], reach_bins[3], reach_bins[4], reach_max, rise_bins[0], rise_bins[1], rise_bins[2]])
	lines.append("candidates the solver refused (not flown): %d" % refused.size())
	for r in refused:
		lines.append("  %s: %s (%s)" % [r["name"], r["kind"], r["reason"]])
	check(reach_bins[0] >= 10 and reach_bins[1] >= 10 and reach_bins[2] >= 10 and reach_bins[3] >= 10 and reach_bins[4] >= 10, "every reach band has at least 10 jumps: %s" % str(reach_bins))
	check(reach_max >= 10.5, "the longest jump flown reaches the new maximum, %.2f WU" % reach_max)
	check(rise_bins[0] >= 15 and rise_bins[1] >= 10 and rise_bins[2] >= 15, "every height band is covered: %s" % str(rise_bins))
	check(path_worst < 1e-3, "every flight followed its predicted path, worst deviation %f WU" % path_worst)
	var summary := "M02 result: %d of %d jumps within %.2f WU; contact error max %.4f WU mean %.4f WU; settled error max %.4f WU mean %.4f WU; worst path deviation %.5f WU" % [
		ok_count, chosen.size(), TOLERANCE, max_contact, sum_contact / n, max_settled, sum_settled / n, path_worst]
	lines.append("")
	lines.append("flown: %d" % chosen.size())
	lines.append(summary)
	print(summary)
	# Invalid candidates: not reachable, named, refused by the motor, and cancelled with feedback by the controller.
	var invalid := await _invalid_candidates(lines)
	check_eq(ok_count, JUMPS, "M02: all %d jumps within tolerance" % JUMPS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/reports"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	print("M02 invalid candidates: %d of %d showed invalid feedback and did not launch" % [invalid[0], invalid[1]])


## [shown_invalid, total]
func _invalid_candidates(lines: PackedStringArray) -> Array[int]:
	var cases: Array[Dictionary] = [
		{"name": "15 WU across the floor", "pose": _on_floor(-28.0, 13.0, Vector3.RIGHT), "target": top_target(-13.0, 13.0), "kind": "unreachable", "reason": "too_far"},
		{"name": "ledge_4 top (5 WU up) from 6 WU away", "pose": _on_floor(3.5, -6.0, Vector3.FORWARD), "target": top_target(3.5, -12.0), "kind": "unreachable", "reason": "too_far"},
		{"name": "the top of tower_e (10 WU up) from the floor", "pose": _on_floor(-4.5, 1.0, Vector3.FORWARD), "target": top_target(-4.5, -2.5), "kind": "unreachable", "reason": "too_far"},
		{"name": "the floor behind the 5 WU wall", "pose": _on_floor(-24.0, -6.5, Vector3.FORWARD), "target": top_target(-24.0, -11.5), "kind": "obstructed", "reason": "path_blocked"},
		{"name": "the foot of the south wall, no room for the body", "pose": _on_floor(0.0, 14.2, Vector3.BACK), "target": top_target(0.0, 17.4), "kind": "obstructed", "reason": "no_room"},
		{"name": "the coated panel's face", "pose": _on_floor(13.5, 11.0, Vector3.BACK), "target": ray_target(Vector3(13.5, 1.5, 11.0), Vector3(13.5, 1.5, 20.0)), "kind": "ineligible", "reason": "ineligible_surface"},
		{"name": "the sky", "pose": _on_floor(-22.0, 12.0, Vector3.RIGHT), "target": {}, "kind": "none", "reason": "no_target"},
		{"name": "along the same wall", "pose": _on_wall(0.0, 1.5), "target": ray_target(Vector3(0.0, 3.5, 10.0), Vector3(0.0, 3.5, 20.0)), "kind": "unreachable", "reason": "no_launch"},
	]
	var jc: Node = world.jump_controller
	var patch: Node3D = world.landing_patch
	var hud: CanvasLayer = world.jump_hud
	var spider: Node3D = world.spider
	var shown := 0
	lines.append("")
	lines.append("invalid candidates (flown through the real controller: hold, then release):")
	for c in cases:
		spider.teleport_to(c["pose"])
		await settle(spider)
		await physics_frames(jc.FLASH_TICKS + 2)
		jc.last_feedback = {}
		spider.last_jump = {}
		jc.aim_override = c["target"]
		var before: Vector3 = spider.global_position
		jc.press()
		await physics_frames(12)
		await process_frames(2)
		var plan: RefCounted = jc.plan
		var kind_ok: bool = plan != null and plan.kind_name() == c["kind"] and plan.reason == c["reason"]
		check(kind_ok, "%s: planned as %s/%s, got %s/%s" % [c["name"], c["kind"], c["reason"], plan.kind_name() if plan != null else "null", plan.reason if plan != null else "null"])
		var cannot_commit: bool = plan != null and not spider.commit_jump(plan)
		check(cannot_commit, "%s: the motor refuses to commit it" % c["name"])
		var pattern_ok: bool = (c["kind"] == "none" and patch.shown_kind == "") or (patch.shown_kind == c["kind"] and patch.shown_pattern != "solid")
		check(pattern_ok, "%s: the patch is not a solid ring (shown %s, %s)" % [c["name"], patch.shown_kind, patch.shown_pattern])
		var words: String = hud.title_text()
		check(words != "" and not words.begins_with("Reachable"), "%s: the label says so in words: %s" % [c["name"], words])
		jc.release()
		await physics_frames(4)
		var not_launched: bool = spider.last_jump.is_empty() and spider.state == spider.State.ATTACHED and spider.global_position.distance_to(before) < 1e-4
		check(not_launched, "%s: nothing launched" % c["name"])
		var feedback_ok: bool = str(jc.last_feedback.get("kind", "")) == "refused"
		check(feedback_ok, "%s: the controller reports the refusal" % c["name"])
		if kind_ok and cannot_commit and pattern_ok and words != "" and not_launched and feedback_ok:
			shown += 1
		lines.append("  %s: %s (%s), shown as %s, label '%s', launched nothing: %s" % [c["name"], c["kind"], c["reason"], patch.shown_pattern if patch.shown_kind != "" else "no patch", words, str(not_launched)])
	lines.append("result: %d of %d invalid candidates showed invalid feedback and did not launch" % [shown, cases.size()])
	var out: Array[int] = [shown, cases.size()]
	return out
