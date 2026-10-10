extends "res://tests/prey_test_case.gd"
## Gate A01 (spec 25, T07; A-026, A-028): a fly flees on sensed evidence, not on the state of the jump button; its debug trace explains
## each transition; a capture triggers once. The fly in question is the prototype's single archetype, "fly-like prey" (no species claim),
## in the lab's own world, with the real spider, sensor and prey director; the spider is driven by its movement intent or by the real
## controller, and the checks (and only the checks) look at what is true.
##
## Five fixtures, each a fresh world (or two, where a run has to be compared with another):
##   F1 the jump button (held to aim, cancelled), Focus, the camera and interact are all pressed while the spider stands still: the fly's
##      awareness stays at nothing, it makes no transition, and it does exactly what it does when none of them is pressed; then the same
##      world and the same fly, the spider walks at it: it goes on alert, with a reason that names what it saw
##   F2 the spider walks, runs back and forth and leaps close to the fly, behind a wall: the fly does not stir, and does what it does with
##      the spider standing still; the wall comes down and the same leap in plain view startles it
##   F3 a fly that is walked up to notices, takes off after a reaction delay, flees and lands elsewhere: every transition has a reason that
##      says what it saw or chose, the awareness and the evidence it had, and the developer's label shows the state, goal, reason and
##      awareness
##   F4 a strike catches a fly once: one event with a stable id and an owner, the prey is CAPTURED before any energy exists, and further
##      strikes and re-tests catch nothing more
##   F5 nothing but the world's stimulus reaches a fly: its scripts do not name the input, the jump, Focus, the camera, the aim, the
##      feeding or the spider, and the one thing the world offers it is a position and a radius
## Writes tests/reports/a01_report.txt.

const GateFixture := preload("res://tests/gate_fixture.gd")
const Evidence := preload("res://tests/evidence.gd")
const PreyDebug := preload("res://scripts/presentation/prey_debug.gd")
const REPORT_PATH := "res://tests/reports/a01_report.txt"
const ACTIONS := ["prepare_jump", "cancel", "focus", "look_right", "look_up", "interact", "move_forward"]
const FLY_SCRIPTS := ["fly.gd", "fly_senses.gd", "fly_mind.gd", "fly_flight.gd", "fly_body.gd"]
## The only parts of the world a fly may read.
const WORLD_MEMBERS := ["graph", "now", "space", "stimulus", "tick"]
## Names a fly's code may not use: the player's controls and the spider's own business.
const FORBIDDEN := ["Input", "InputMap", "InputEvent", "spider", "jump", "focus", "gaze", "camera", "prepare", "reticle", "aim", "feeding", "needs"]
const FLY_DIR := "res://scripts/prey/"

var _results: Array = []
var _numbers: String = ""


func after_each() -> void:
	for a: String in ACTIONS:
		Input.action_release(a)


func test_a01_a_fly_flees_on_sensed_evidence_not_on_the_jump_button_its_trace_explains_each_step_and_a_capture_happens_once() -> void:
	_results.clear()
	var p = load("res://scripts/prey/prey_profile.gd").load_file("res://data/species/fly_like_prototype.json")
	_numbers = "awareness calm %.2f, alert %.2f, flee %.2f; a startle is %.0f deg/s of apparent motion within %.0f WU; reaction delays (s) alert %.2f to %.2f, relaxed %.2f to %.2f, grooming %.2f to %.2f; take-off %.0f WU/s2, flight %.0f WU/s; capture radius %.2f WU plus the spider's 0.30" % [
		p.awareness_calm, p.awareness_alert, p.awareness_flee, p.startle_motion_deg_s, p.startle_range_wu,
		p.delay_startle_alert_s.x, p.delay_startle_alert_s.y, p.delay_startle_relaxed_s.x, p.delay_startle_relaxed_s.y,
		p.delay_startle_grooming_s.x, p.delay_startle_grooming_s.y, p.takeoff_accel_wu_s2, p.flee_speed_wu_s, p.capture_radius_wu]
	var fixtures: Array[Callable] = [_f1_buttons, _f2_occluded, _f3_trace, _f4_capture_once, _f5_nothing_else_is_read]
	for fixture: Callable in fixtures:
		var f: GateFixture = await fixture.call()
		_results.append(f)
		await _drop_world()
	var lines := PackedStringArray()
	lines.append("A01 prey report (spec 25): a fly flees based on sensed evidence, not jump-button state; its debug trace explains each transition; capture triggers once")
	lines.append("timestamp_utc: %sZ" % Time.get_datetime_string_from_system(true))
	lines.append(Evidence.describe(Evidence.identity("res://")))
	lines.append("engine: %s" % Engine.get_version_info()["string"])
	lines.append("prey: the prototype's one archetype, fly-like prey (no species claim), data/species/fly_like_prototype.json; the prey seed is fixed, so a run is repeatable")
	lines.append("setup: the lab's own world, the real spider, sensor and prey director; the spider is driven by its movement intent or the real controller; the checks read the truth, the fly never does")
	lines.append("numbers (from the species data): " + _numbers)
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
	var summary := "A01 result: %d of %d fixtures passed: the fly fled on what it sensed and not on the jump button; its trace explained every step; the capture happened once" % [passed, _results.size()]
	lines.append("")
	lines.append(summary)
	print(summary)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/reports"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()


# ------------------------------------------------------------------ helpers

func _drop_world() -> void:
	if world != null and is_instance_valid(world):
		world.free()
		world = null
	await physics_frames(2)


## A real action event, as the keyboard or a pad would send it, then one counted tick.
func _send(action: String, pressed: bool, really: bool, sample: Callable) -> void:
	if really:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)
	await run_ticks(1, sample)


func _max_of(values: Array) -> float:
	var m := 0.0
	for v in values:
		m = maxf(m, float(v))
	return m


func _max_gap(a: Array, b: Array) -> float:
	var m := 0.0
	for i in mini(a.size(), b.size()):
		m = maxf(m, (a[i] as Vector3).distance_to(b[i] as Vector3))
	return m


# ------------------------------------------------------------------ F1 the buttons

## One run of the button scenario: 269 ticks of a spider that stands still next to a fly 6 WU off, with (press) or without the buttons.
func _button_run(press: bool) -> Dictionary:
	await spawn_prey_world(floor_pose(4.0, 5.0, 180.0), 0, PREY_SEED, true)
	var spider: Node3D = world.spider
	var fly := add_fly("floor_east_open", 7)
	var jc: Node = world.jump_controller
	var start: Vector3 = spider.global_position
	var heading0: Vector3 = spider.get_heading_vector()
	var yaw0: float = world.camera_rig.yaw
	var rec := {"aw": [], "pos": [], "states": {}, "aiming": 0, "turned_deg": 0.0, "refusal": ""}
	var sample := func() -> void:
		(rec["aw"] as Array).append(fly.senses.awareness)
		(rec["pos"] as Array).append(fly.global_position)
		(rec["states"] as Dictionary)[fly.state_name()] = true
		if jc.is_aiming():
			rec["aiming"] = int(rec["aiming"]) + 1
		rec["turned_deg"] = maxf(float(rec["turned_deg"]), rad_to_deg(heading0.angle_to(spider.get_heading_vector())))
	await run_ticks(30, sample)
	await _send("prepare_jump", true, press, sample)
	await run_ticks(90, sample)                 # the jump button is down, and the spider aims
	await _send("cancel", true, press, sample)  # cancelled: the aim ends, nothing flies
	await run_ticks(5, sample)
	await _send("cancel", false, press, sample)
	await _send("prepare_jump", false, press, sample)
	await run_ticks(10, sample)
	if press:
		Input.action_press("look_right")
	await run_ticks(40, sample)                 # the camera swings round
	if press:
		Input.action_release("look_right")
		Input.action_press("focus")
	await run_ticks(60, sample)                 # Focus: the body turns to where the camera looks
	if press:
		Input.action_release("focus")
		Input.action_press("interact")
	await run_ticks(3, sample)                  # interact, with nothing in the jaws
	if press:
		Input.action_release("interact")
		rec["refusal"] = world.feeding.last_refusal
	await run_ticks(30, sample)
	rec["moved"] = spider.global_position.distance_to(start)
	rec["trace_n"] = fly.trace.size()
	rec["jumped"] = not spider.last_jump.is_empty()
	var contrast := {}
	if press:
		world.camera_rig.yaw = yaw0   # the camera looks at the fly again, as at the start
		await physics_frames(2)
		Input.action_press("move_forward")
		for i in 360:
			await physics_frames(1)
			if fly.state != Fly.State.PERCHED:
				contrast["distance"] = flat_distance(spider.global_position, fly.global_position)
				contrast["ticks"] = i
				break
		Input.action_release("move_forward")
		contrast["state"] = fly.state_name()
		contrast["trace"] = fly.trace.duplicate(true)
	rec["contrast"] = contrast
	return rec


func _f1_buttons() -> GateFixture:
	var fx := GateFixture.new("F1 pressing the jump button, Focus, the camera and interact changes nothing for the fly; walking at it does")
	var down := await _button_run(true)
	await _drop_world()
	var up := await _button_run(false)
	var calm: float = 0.1
	fx.need(int(down["aiming"]) >= 60, "the jump button was down and the spider was aiming for %d ticks (the controller took it)" % int(down["aiming"]), "the aim never took hold (%d ticks): the fixture did not press the jump button" % int(down["aiming"]))
	fx.need(float(down["turned_deg"]) > 20.0, "Focus and the camera did take effect: the body turned %.0f degrees" % float(down["turned_deg"]), "Focus did not turn the body (%.1f degrees): the fixture did not press it" % float(down["turned_deg"]))
	fx.need(str(down["refusal"]) == "no prey", "interact was pressed and answered 'no prey'", "interact was answered '%s'" % str(down["refusal"]))
	fx.need(float(down["moved"]) < 0.05 and not bool(down["jumped"]), "and the spider did not move (%.3f WU) and did not leap" % float(down["moved"]), "the spider moved %.3f WU or leapt: the buttons were not a still test" % float(down["moved"]))
	var peak := _max_of(down["aw"])
	fx.need(peak <= 1.0e-6 and int(down["trace_n"]) == 0, "the fly's awareness stayed at %.3f (calm is %.2f) and it made %d transitions" % [peak, calm, int(down["trace_n"])], "the fly reacted to buttons: awareness peaked at %.3f, %d transitions" % [peak, int(down["trace_n"])])
	fx.need((down["states"] as Dictionary).keys() == ["PERCHED"], "it stayed PERCHED throughout", "it was seen in states %s" % str((down["states"] as Dictionary).keys()))
	var gap := _max_gap(down["pos"], up["pos"])
	fx.need((down["pos"] as Array).size() == (up["pos"] as Array).size() and gap < 1.0e-4, "the same world, the same fly and no buttons at all: the fly did the very same thing, to %.6f WU over %d ticks" % [gap, (down["pos"] as Array).size()], "with and without the buttons the fly differs by %.4f WU" % gap)
	fx.need(_max_of(up["aw"]) <= 1.0e-6, "and its awareness stayed at nothing there too", "awareness without buttons peaked at %.3f" % _max_of(up["aw"]))
	var c: Dictionary = down["contrast"]
	fx.need(c.has("distance") and str(c["state"]) != "PERCHED", "then the spider walked at the same fly: it left its rest after %.1f s, with the spider %.1f WU away, and was %s" % [float(c.get("ticks", 0)) / 60.0, float(c.get("distance", 0.0)), str(c.get("state", ""))], "walking at the fly did not move it at all within 6 s")
	if c.has("trace") and not (c["trace"] as Array).is_empty():
		var first: Dictionary = (c["trace"] as Array)[0]
		var why := str(first["reason"])
		fx.need(why.begins_with("noticed") or why.begins_with("startled"), "its first transition was %s -> %s: %s" % [first["from"], first["to"], why.substr(0, 150)], "its first transition does not say what it saw: %s" % why)
		fx.need(why.contains("deg/s") and why.contains("WU"), "and the reason carries the evidence (an angular speed and a distance)", "the reason has no measurement in it: %s" % why)
	return fx


# ------------------------------------------------------------------ F2 behind a wall

## A spider that walks, turns back and leaps 4.5 WU from a fly, behind a wall (move) or stands in the same place (no move). The fly sits at
## (4, 0, 11); the wall is a 0.3 WU plank, 8 WU high, across the whole way between.
func _hidden_run(move: bool, with_control: bool) -> Dictionary:
	await spawn_prey_world(floor_pose(0.0, 6.5, -90.0), 0, PREY_SEED)
	world.lab.add_fixture_piece("hide_wall", "wall", Vector3(-8.0, 0.0, 8.0), Vector3(16.0, 8.0, 8.3))
	await physics_frames(3)
	var spider: Node3D = world.spider
	var fly := add_fly("floor_east_open", 9)
	var rec := {"aw": [], "pos": [], "seen": 0, "checks0": 0}
	var sample := func() -> void:
		(rec["aw"] as Array).append(fly.senses.awareness)
		(rec["pos"] as Array).append(fly.global_position)
		if not fly.senses.evidence.is_empty() and bool(fly.senses.evidence.get("seen", false)) and director().now - float(fly.senses.evidence.get("t", -1.0e9)) < 0.3:
			rec["seen"] = int(rec["seen"]) + 1
	await run_ticks(30, sample)
	rec["checks0"] = fly.senses.checks_total
	if move:
		await walk_toward(Vector3(5.0, 0.31, 6.5), WALK, 0.2, 200, sample)    # east at walking pace, a few WU from the fly, out of its sight
		await walk_toward(Vector3(1.5, 0.31, 6.5), WALK, 0.2, 200, sample)    # and back
		await strike_at(7.0, 6.5)                                              # a real leap along the wall
	else:
		await run_ticks(260, sample)
	await run_ticks(20, sample)
	rec["state"] = fly.state_name()
	rec["trace_n"] = fly.trace.size()
	rec["has_last_seen"] = fly.senses.has_last_seen
	rec["checks"] = fly.senses.checks_total - int(rec["checks0"])
	rec["rays"] = fly.senses.rays_total
	rec["captures"] = director().capture_log.size()
	rec["spider_x"] = spider.global_position.x
	rec["leapt"] = not spider.last_jump.is_empty()
	if with_control:
		world.lab.set_piece_enabled("hide_wall", false)
		await physics_frames(2)
		var before: int = fly.trace.size()
		await strike_at(1.5, 6.5)
		await wait_until(func() -> bool: return fly.trace.size() > before, 90)
		rec["control_trace"] = fly.trace.slice(before)
		rec["control_state"] = fly.state_name()
	return rec


func _f2_occluded() -> GateFixture:
	var fx := GateFixture.new("F2 occluded spider motion does not startle the fly; the same motion in plain view does")
	var moving := await _hidden_run(true, true)
	await _drop_world()
	var still := await _hidden_run(false, false)
	fx.need(bool(moving["leapt"]) and float(moving["spider_x"]) > 5.0, "behind the wall the spider walked east and back at 2.5 WU/s and then leapt along it (to x = %.1f), 4.5 WU from the fly" % float(moving["spider_x"]), "the fixture did not move the spider as planned (leapt %s, x = %.1f)" % [str(moving["leapt"]), float(moving["spider_x"])])
	fx.need(int(moving["seen"]) == 0 and int(moving["checks"]) > 30, "the fly looked %d times and saw it in none of them (%d rays)" % [int(moving["checks"]), int(moving["rays"])], "the fly saw the spider %d times through the wall (checks %d)" % [int(moving["seen"]), int(moving["checks"])])
	var peak := _max_of(moving["aw"])
	fx.need(peak <= 1.0e-6 and int(moving["trace_n"]) == 0 and str(moving["state"]) == "PERCHED", "its awareness stayed at %.3f, it made %d transitions and is %s" % [peak, int(moving["trace_n"]), str(moving["state"])], "the fly stirred: awareness peaked at %.3f, %d transitions, state %s" % [peak, int(moving["trace_n"]), str(moving["state"])])
	fx.need(not bool(moving["has_last_seen"]), "and it holds no memory of where the spider is: it has never seen it", "the fly remembers a place it should not know")
	fx.need(int(moving["captures"]) == 0, "nothing was caught by the leap", "the leap behind the wall caught %d" % int(moving["captures"]))
	var gap := _max_gap(moving["pos"], still["pos"])
	var n := mini((moving["pos"] as Array).size(), (still["pos"] as Array).size())
	fx.need(gap < 1.0e-4 and n > 250, "the spider standing still in the same place: the fly did the very same thing, to %.6f WU over %d ticks (all it does is its own fidgeting and grooming)" % [gap, n], "what the hidden spider did changed the fly by %.4f WU" % gap)
	var ct: Array = moving.get("control_trace", [])
	fx.need(not ct.is_empty(), "the wall came down and the same leap in plain view moved the fly: %s" % (str((ct[0] as Dictionary)["reason"]).substr(0, 140) if not ct.is_empty() else ""), "with the wall down the leap did not move the fly")
	if not ct.is_empty():
		var why := str((ct[0] as Dictionary)["reason"])
		fx.need(why.contains("deg/s") and (why.begins_with("noticed") or why.begins_with("startled")), "and its reason is the evidence: an angular speed over the limit at a distance", "the reason is not evidence: %s" % why)
	return fx


# ------------------------------------------------------------------ F3 the trace

func _f3_trace() -> GateFixture:
	var fx := GateFixture.new("F3 a fly that is walked up to flees, and its trace and the developer's label explain every step")
	await spawn_prey_world(floor_pose(-5.0, 11.0, -90.0), 0, PREY_SEED)
	var fly := add_fly("floor_east_open", 3)
	fly.face(Vector3.LEFT)
	var labels := {}
	var sample := func() -> void:
		if not labels.has(fly.state_name()):
			labels[fly.state_name()] = PreyDebug.label_text(fly)
	await walk_toward(fly.global_position, WALK, 1.0, 900, sample)
	await wait_until(func() -> bool: return fly.state == Fly.State.PERCHED and fly.flight.landings_total >= 1, 60 * 8)
	var names: Array[String] = []
	for e: Dictionary in fly.trace:
		names.append(str(e["to"]))
	fx.need(" ".join(PackedStringArray(names.slice(0, 5))) == "ALERT TAKEOFF FLEE SEEK_PERCH PERCHED", "it walked at the fly and the fly went %s" % " -> ".join(PackedStringArray(names.slice(0, 5))), "the transitions were %s" % str(names))
	var all_explained := true
	for e: Dictionary in fly.trace:
		var why := str(e["reason"])
		var line := "t %.2f s  %s -> %s: %s" % [float(e["t"]), e["from"], e["to"], why.substr(0, 130)]
		fx.note(line)
		if why.length() < 20 or str(e["evidence"]) == "" or not e.has("awareness") or not e.has("goal") or int(e["tick"]) <= 0:
			all_explained = false
	fx.need(all_explained, "every transition carries a reason, the tick, the goal, the awareness and the evidence the fly had", "a transition is missing its reason, tick, goal, awareness or evidence")
	if fly.trace.size() >= 2:
		var noticed: Dictionary = fly.trace[0]
		var took_off: Dictionary = fly.trace[1]
		fx.need(str(noticed["reason"]).begins_with("noticed") and str(noticed["reason"]).contains("bearing"), "the first says what it saw (bearing, looming, distance, how much of the spider)", "the first reason: %s" % noticed["reason"])
		fx.need(str(took_off["reason"]).contains("reaction delay"), "the take-off waited out a reaction delay, which the reason states", "the take-off reason does not state the delay: %s" % took_off["reason"])
		fx.need(float(took_off["t"]) - float(noticed["t"]) >= 0.2, "and the alert posture lasted %.2f s: long enough to be seen" % (float(took_off["t"]) - float(noticed["t"])), "the alert lasted only %.2f s" % (float(took_off["t"]) - float(noticed["t"])))
	var last: Dictionary = fly.trace[fly.trace.size() - 1] if not fly.trace.is_empty() else {}
	fx.need(not last.is_empty() and str(last["reason"]).begins_with("landed on"), "and the last says where it landed", "the last reason: %s" % str(last.get("reason", "")))
	fx.need(fly.flight.max_step <= fly.profile.flee_speed_wu_s / 60.0 * 1.02 and fly.flight.replans == 0, "the flight never moved more than its top speed allows in a tick (%.3f WU): no jump, no teleport" % fly.flight.max_step, "the flight moved %.3f WU in a tick" % fly.flight.max_step)
	var label_ok := true
	for state_name: String in ["ALERT", "FLEE"]:
		if not labels.has(state_name):
			label_ok = false
			fx.problems.append("the developer's label was never read in %s" % state_name)
			continue
		var text: String = labels[state_name]
		if not (text.contains(fly.id) and text.contains(state_name) and text.contains("goal") and text.contains("aw ") and text.contains("perch")):
			label_ok = false
			fx.problems.append("the label in %s lacks the id, state, goal, awareness or perch: %s" % [state_name, text.replace("\n", " | ")])
	if label_ok:
		fx.note("F4 shows, for each fly, its id, state, goal, awareness, perch and the reason of its last transition, e.g. while fleeing: " + str(labels["FLEE"]).replace("\n", " | ").substr(0, 230))
	var lines := PreyDebug.describe(world.prey, world.needs, world.feeding)
	fx.need(lines.size() >= 3 and " ".join(lines).contains(fly.id), "F3 lists the fly with its state and awareness, and the energy and feeding lines", "the F3 lines do not list the fly: %s" % " | ".join(lines))
	return fx


# ------------------------------------------------------------------ F4 capture once

func _f4_capture_once() -> GateFixture:
	var fx := GateFixture.new("F4 a capture is resolved once, with a stable id and an owner, before any energy exists")
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0), 0, PREY_SEED)
	var fly := add_fly("floor_east_open", 1, true)
	var seen: Array[Dictionary] = []
	var at_capture := {}
	director().captured.connect(func(e: Dictionary) -> void:
		seen.append(e)
		at_capture["state"] = fly.state_name()
		at_capture["grants"] = world.needs.grants_made
		at_capture["energy"] = world.needs.energy)
	var energy0: float = world.needs.energy
	await strike_at(4.0, 11.0)
	await run_ticks(60)
	fx.need(seen.size() == 1 and director().capture_log.size() == 1, "one strike, one capture event: %s (owner %s, %.2f WU from the fly with a reach of %.2f)" % [str(seen[0]["id"]) if not seen.is_empty() else "-", str(seen[0]["owner"]) if not seen.is_empty() else "-", float(seen[0]["distance"]) if not seen.is_empty() else 0.0, float(seen[0]["reach"]) if not seen.is_empty() else 0.0], "the capture log holds %d events (%d announced)" % [director().capture_log.size(), seen.size()])
	fx.need(not seen.is_empty() and str(seen[0]["id"]) == "capture:spider:%s" % fly.id, "its id is stable: it names who took what", "the event id is %s" % (str(seen[0]["id"]) if not seen.is_empty() else "-"))
	fx.need(str(at_capture.get("state", "")) == "CAPTURED" and int(at_capture.get("grants", -1)) == 0 and absf(float(at_capture.get("energy", 0.0)) - energy0) < 1.0e-9, "at the moment of the capture the prey was CAPTURED and the spider's energy was untouched (%d grants, %.3f)" % [int(at_capture.get("grants", -1)), float(at_capture.get("energy", 0.0))], "at the capture: state %s, grants %s, energy %s" % [str(at_capture.get("state", "")), str(at_capture.get("grants", "")), str(at_capture.get("energy", ""))])
	fx.need(fly.captured_by == "spider" and director().held == fly, "the spider owns it and holds it", "owner '%s', held %s" % [fly.captured_by, str(director().held)])
	fx.need(world.needs.grants_made == 0, "sixty ticks later the capture alone has still granted nothing: only feeding does", "the capture granted energy (%d grants)" % world.needs.grants_made)
	# the same strike again, and the world asked again and again
	await strike_at(4.0, 8.0)
	director().strike_active = true
	for i in 12:
		director().resolve_captures()
	director().strike_active = false
	fx.need(director().capture_log.size() == 1 and director().refused_log.is_empty(), "a second strike through the same place and twelve more tests of the world caught nothing more: still one event, none refused", "afterwards %d captures and %d refusals" % [director().capture_log.size(), director().refused_log.size()])
	return fx


# ------------------------------------------------------------------ F5 what a fly can read

## The text of a script without its comments and its strings.
func _code_of(text: String) -> String:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var kept := ""
		var quote := ""
		for i in line.length():
			var ch := line[i]
			if quote != "":
				if ch == quote and (i == 0 or line[i - 1] != "\\"):
					quote = ""
				continue
			if ch == "\"" or ch == "'":
				quote = ch
				continue
			if ch == "#":
				break
			kept += ch
		out.append(kept)
	return "\n".join(out)


func _f5_nothing_else_is_read() -> GateFixture:
	var fx := GateFixture.new("F5 nothing of the player's reaches the fly: its code names no control, no aim and no spider, and the world offers it one stimulus")
	var words := RegEx.new()
	words.compile("\\b(%s)\\w*" % "|".join(PackedStringArray(FORBIDDEN)))
	var members := RegEx.new()
	members.compile("\\bworld\\.([a-z_]+)")
	var lines_total := 0
	var used := {}
	for script_name: String in FLY_SCRIPTS:
		var file := FileAccess.open(FLY_DIR + script_name, FileAccess.READ)
		if file == null:
			fx.problems.append("%s could not be read" % script_name)
			continue
		var code := _code_of(file.get_as_text())
		lines_total += code.count("\n") + 1
		for m in words.search_all(code):
			var hit := m.get_string()
			# 'inputs' and 'threat_input' are the utility's own numbers: a word that merely starts with a name is not the name
			if hit.to_lower().begins_with("input") and hit != "Input" and hit != "InputMap" and not hit.begins_with("InputEvent"):
				continue
			fx.problems.append("%s names '%s'" % [script_name, hit])
		for m in members.search_all(code):
			used[m.get_string(1)] = true
	fx.need(fx.problems.is_empty(), "the %d lines of the fly's scripts (%s) name no input, jump, Focus, camera, aim, feeding, needs or spider" % [lines_total, ", ".join(PackedStringArray(FLY_SCRIPTS))], "a fly script names something it must not")
	var extra: Array[String] = []
	for k in used.keys():
		if not WORLD_MEMBERS.has(str(k)):
			extra.append(str(k))
	fx.need(extra.is_empty(), "the only parts of the world a fly reads are %s" % ", ".join(PackedStringArray(used.keys().map(func(k: Variant) -> String: return str(k)))), "a fly reads other parts of the world: %s" % str(extra))
	await spawn_prey_world(floor_pose(4.0, 5.0, 180.0), 0, PREY_SEED)
	var stim: Dictionary = director().stimulus()
	var keys := stim.keys()
	keys.sort()
	fx.need(keys == ["position", "radius"], "the world's stimulus is a position and a radius (%s) and the fly's own rays decide what of it can be seen" % str(keys), "the stimulus offers %s" % str(keys))
	return fx
