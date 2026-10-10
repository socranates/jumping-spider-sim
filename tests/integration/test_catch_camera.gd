extends "res://tests/tether_test_case.gd"
## The catch camera check (A-017, chunk 6A). Reviewer 2 asked how long the camera is crowded at the cliff-cap catch
## and grab with ordinary input, and to fix it only if the view hides the recovery choices.
##
## The scenario is M03 F03 in the normal game setup (the interactive world: the real camera rig, jump and line
## controllers, Settings defaults): the spider stands on the wooden cap of the coated cliff facing the practice perch,
## aims at it through the jump controller's aim override (the same path the reticle takes), releases, the perch drops
## and the line catches the spider hanging below the cap's lip, clear of the coated face. NO camera input is given at
## any point: no look, no recenter, no yaw or pitch set. Then the line is reeled in with the controller's reel input,
## either 24 ticks after the catch (a quick player) or once the swing has settled and the spider rests (a patient one),
## until the grab, and the view is measured for 2 s after the grab. Every physics tick, tests/catch_camera_probe.gd
## measures the boom length, whether the spider is seen (in the inner 94 percent of a 16:9 frame and not behind
## geometry, at three of five points on its body, with the body drawn), how much of the screen height the 1 WU body
## covers, whether the lip (where the line bends over the cap's edge) is in frame and not behind geometry, what share
## of the line from the lip to the spider is, and how much of the screen is covered by geometry within 1 WU of the
## camera.
##
## The criterion, stated: a tick is CROWDED when any of these holds.
##   spider hidden   the body is not drawn (the boom is shorter than 0.8 WU) or fewer than three of its five sample
##                   points are in frame and unhidden
##   too close       the 1 WU body is taller than 0.6 of the screen height (the camera is on top of it)
##   geometry        geometry within 1 WU of the camera covers more than a third of the screen
##   lip hidden      (while the line is out) the lip is outside the frame or behind geometry
##   line hidden     (while the line is out) less than half of the line between the lip and the spider is in frame
##                   and unhidden
## That is: crowded means the player cannot see the spider, the lip it hangs from and the line between them, which
## is what the choices (reel up, lower, let go) are made from. Each tick is measured, so the report gives how long the
## view is crowded in game time, in total and in the longest unbroken run, on the line and in the 2 s after the grab.
##
## Measured before the line framing existed (the camera as shipped in chunk 5, `line_framing` off), with the framing as
## chunk 6A shipped it (a turn of up to 180 degrees: `framing_max_turn` lifted to PI, "uncapped") and with the framing
## as it ships now (chunk 6B: Chet's temporary cap of 45 degrees, "capped"), in tests/reports/catch_camera_report.txt,
## which this test writes. This test asserts the result. Without the framing the scenario really is squeezed. Uncapped,
## the framing leaves a short crowded stretch while it turns the view, none after that until the grab, none in the 2 s
## after it. Capped, the cliff-cap catch from the default view (the camera behind the spider) is NOT helped, because the
## smallest turn that clears the cliff is 90 degrees: the test says so, as a measurement, and records how long the view
## is crowded. With a view 45 degrees off the open side ("cliff45": a turn the cap allows) the capped framing works.
## In every framed run the camera never enters geometry or rolls and the player's own yaw and pitch are untouched until
## the grab. The slab-edge catch (M03 F04) is measured too and may not be made worse.

const Probe = preload("res://tests/catch_camera_probe.gd")
const Evidence := preload("res://tests/evidence.gd")
const REPORT_PATH := "res://tests/reports/catch_camera_report.txt"
const AFTER_GRAB_TICKS := 120       # 2 s
const QUICK_REEL_TICKS := 24        # the quick player reels this long after the catch
const TABLE_EVERY := 6

## The most crowded game time the framing may leave on the line, in ticks (0.75 s), and in one unbroken stretch (0.5 s).
const FRAMED_CROWDED_MAX := 45
const FRAMED_RUN_MAX := 30
## From this many ticks (0.83 s) after the catch the framed view has settled: until the grab it may flicker (where the
## reel starts and where the spider takes hold) for at most LATE_MAX ticks in all and LATE_RUN_MAX in a row.
const FRAMED_SETTLED_TICK := 50
const LATE_MAX := 8
const LATE_RUN_MAX := 4

var _report: PackedStringArray = PackedStringArray()
var _results: Dictionary = {}


## One run of a scenario: "cliff" (the camera behind the spider, as the game leaves it), "cliff45" (the player's view 45
## degrees off the open side) or the slab's x, with a camera variant: "before" (no framing, chunk 5), "capped" (the
## shipped framing, at most 45 degrees) or "uncapped" (chunk 6A's, up to 180 degrees). Returns {caught, samples, grab_tick, max_assist (radians), unsafe and
## rolled (ticks), yaw_dev and elevation_dev (the player's own yaw and pitch against their start, the most while on the
## line), view_on_line (the view's yaw on the last tick on the line), view_end and yaw_assist_end (after the 2 s)}.
func _run_variant(scenario: String, variant: String, settle_first: bool) -> Dictionary:
	var on_cliff := scenario.begins_with("cliff")
	spawn_world(cliff_pose() if on_cliff else slab_pose(float(scenario)), true)
	await physics_frames(6)
	var spider: Node3D = world.spider
	await settle(spider)
	var jc: Node = world.jump_controller
	var tc: Node = world.tether_controller
	var rig: Node3D = world.camera_rig
	rig.line_framing = variant != "before"
	if variant == "uncapped":
		rig.framing_max_turn = PI
	if scenario == "cliff45":
		rig.yaw = deg_to_rad(-45.0)
	var yaw0: float = rig.yaw
	var elevation0: float = rig.elevation
	var events := record_line_events(spider)
	var caught := false
	if on_cliff:
		jc.aim_override = top_target(27.3, -7.0)
		jc.press()
		await physics_frames(14)
		await process_frames(2)
		jc.release()
		caught = await wait_until(func() -> bool: return events.has("caught"), 240)
	else:
		caught = await miss_off_the_slab(spider, float(scenario))
	var catch_tick: int = spider.get_physics_tick()
	var samples: Array[Dictionary] = []
	var reeling := false
	var grab_tick := -1
	var lip: Variant = null
	var max_assist := 0.0
	var unsafe := 0
	var rolled := 0
	var yaw_dev := 0.0
	var elevation_dev := 0.0
	var view_on_line := NAN
	var space := world.get_world_3d().direct_space_state
	var probe_shape := SphereShape3D.new()
	probe_shape.radius = 0.05
	var guard := 0
	while guard < 1800:
		guard += 1
		var tick: int = spider.get_physics_tick()
		if not reeling:
			var go: bool = (spider.state == spider.State.HANGING and spider.velocity == Vector3.ZERO) if settle_first else (tick - catch_tick >= (QUICK_REEL_TICKS if on_cliff else 60))
			if go:
				tc.reel_override = 1.0
				reeling = true
		if spider.tether.is_active() and lip == null:
			lip = spider.tether.bend_point if spider.tether.has_bend else spider.tether.anchor_point
		var m := Probe.measure(world, spider, rig, lip)
		m["tick"] = tick - catch_tick
		m["state"] = spider.get_state_name()
		m["why"] = Probe.crowded_reasons(m)
		samples.append(m)
		max_assist = maxf(max_assist, absf(rig.yaw_assist))
		if spider.is_on_line():
			yaw_dev = maxf(yaw_dev, absf(angle_difference(rig.yaw, yaw0)))
			elevation_dev = maxf(elevation_dev, absf(rig.elevation - elevation0))
			view_on_line = rig.view_yaw()
		var cam: Camera3D = rig.camera
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = probe_shape
		query.transform = Transform3D(Basis.IDENTITY, cam.global_position)
		query.collision_mask = 1
		if not space.intersect_shape(query, 1).is_empty():
			unsafe += 1
		if absf(cam.global_transform.basis.x.y) > 1e-5:
			rolled += 1
		if grab_tick < 0 and events.has("completed"):
			grab_tick = tick
			tc.reel_override = 0.0
		if grab_tick >= 0 and tick >= grab_tick + AFTER_GRAB_TICKS:
			break
		await physics_frames(1)
	tc.reel_override = 0.0
	var result := {"caught": caught, "samples": samples, "grab_tick": grab_tick - catch_tick, "max_assist": max_assist, "unsafe": unsafe, "rolled": rolled, "yaw_dev": yaw_dev, "elevation_dev": elevation_dev, "view_on_line": view_on_line, "view_end": rig.view_yaw(), "yaw_assist_end": rig.yaw_assist}
	world.free()
	return result


## Counts for one run: crowded ticks on the line and after the grab, the longest unbroken crowded run, crowded ticks
## after `settled_tick`, the unbroken crowded runs as "a-b" strings, the smallest boom and the largest near cover.
func _stats(r: Dictionary) -> Dictionary:
	var line_ticks := 0
	var line_crowded := 0
	var after_crowded := 0
	var longest := 0
	var run := 0
	var run_start := 0
	var late := 0
	var late_run := 0
	var late_longest := 0
	var min_boom := 99.0
	var max_cover := 0.0
	var reasons := {}
	var runs: Array[String] = []
	var samples: Array = r["samples"]
	for i in samples.size():
		var m: Dictionary = samples[i]
		var on_line: bool = m["tick"] <= r["grab_tick"]
		if on_line:
			line_ticks += 1
		min_boom = minf(min_boom, m["boom"])
		max_cover = maxf(max_cover, m["near_cover"])
		var why: PackedStringArray = m["why"]
		if not why.is_empty():
			if on_line:
				line_crowded += 1
				if m["tick"] >= FRAMED_SETTLED_TICK:
					late += 1
					late_run += 1
					late_longest = maxi(late_longest, late_run)
				else:
					late_run = 0
			else:
				after_crowded += 1
			if run == 0:
				run_start = m["tick"]
			run += 1
			longest = maxi(longest, run)
			for w in why:
				reasons[w] = int(reasons.get(w, 0)) + 1
		if why.is_empty():
			late_run = 0
		if why.is_empty() or i == samples.size() - 1:
			if run > 0:
				runs.append("%d-%d" % [run_start, run_start + run - 1])
			run = 0
	return {"line_ticks": line_ticks, "line_crowded": line_crowded, "after_crowded": after_crowded, "longest": longest, "late": late, "late_longest": late_longest, "min_boom": min_boom, "max_cover": max_cover, "reasons": reasons, "runs": runs}


func _line_of(label: String, r: Dictionary, s: Dictionary) -> String:
	return "%s: caught=%s grab at tick %d (%.2f s after the catch); on the line %d ticks, crowded %d (%.2f s), longest run %d (%.2f s), crowded after %d ticks (%.2f s) of the 2 s after the grab; crowded runs (ticks from the catch) %s; smallest boom %.2f WU, most near cover %.2f; reasons %s" % [label, str(r["caught"]), r["grab_tick"], r["grab_tick"] / 60.0, s["line_ticks"], s["line_crowded"], s["line_crowded"] / 60.0, s["longest"], s["longest"] / 60.0, s["after_crowded"], s["after_crowded"] / 60.0, ", ".join(PackedStringArray(s["runs"])), s["min_boom"], s["max_cover"], str(s["reasons"])]


func _table(r: Dictionary) -> Array[String]:
	var rows: Array[String] = ["    tick state     boom  view yaw  turn  pitch  body seen lip(in/hidden) line  near  crowded because"]
	var i := 0
	for m: Dictionary in r["samples"]:
		if i % TABLE_EVERY == 0:
			rows.append("    %4d %-9s %4.2f %8.1f %5.1f %6.1f %5s %3d  %s/%s        %4.2f  %4.2f  %s" % [m["tick"], m["state"], m["boom"], m["view_yaw_deg"], m["yaw_assist_deg"], m["auto_pitch_deg"], str(m["body_drawn"]), m["body_seen"], "y" if m["lip_in_frame"] else "n", "y" if m["lip_occluded"] else "n", m["span_visible"], m["near_cover"], ", ".join(m["why"])])
		i += 1
	return rows


func _write_report() -> void:
	var lines := PackedStringArray()
	lines.append("Catch camera report (A-017, chunk 6A, re-measured in chunk 6B at Chet's cap of 45 degrees): the cliff-cap catch and grab, and the slab-edge catch, with no camera input")
	lines.append("timestamp_utc: %sZ" % Time.get_datetime_string_from_system(true))
	lines.append(Evidence.describe(Evidence.identity("res://")))
	lines.append("engine: %s" % Engine.get_version_info()["string"])
	lines.append("A tick is crowded when the spider is hidden (body not drawn, or under three of five body points in the inner 94 percent of a 16:9 frame and unhidden), the 1 WU body is over 0.6 of the screen height, geometry within 1 WU covers over a third of the screen, or, while the line is out, the lip is out of frame or hidden or under half of the line from the lip to the spider is in frame and unhidden.")
	lines.append("Rows: every %d ticks from the catch (60 ticks = 1 s). 'before' is the camera of chunk 5 (line framing off), 'capped' the shipped camera of chunk 6B (the framing turns the view by at most 45 degrees), 'uncapped' the framing of chunk 6A (up to 180 degrees; 90 at the cliff). 'cliff' is the view the game leaves after a leap from the cap (the camera behind the spider); 'cliff45' is a view 45 degrees off the open side. The player's yaw and pitch are never touched in any run." % TABLE_EVERY)
	lines.append("")
	lines.append_array(_report)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/reports"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()


func _measure(scenario: String, variant: String, settle_first: bool) -> Dictionary:
	var r: Dictionary = await _run_variant(scenario, variant, settle_first)
	var s := _stats(r)
	var where := "slab edge x=%s" % scenario if scenario[0].is_valid_int() else "cliff cap (%s view)" % ("default" if scenario == "cliff" else "45 degrees off")
	var label := "%s, %s, %s" % [where, variant, "reel after settling" if settle_first else "quick reel"]
	_report.append(_line_of(label, r, s))
	_report.append_array(_table(r))
	_report.append("")
	_write_report()
	return {"r": r, "s": s}


## What a camera that frames the view must satisfy in every run, capped or not: caught and grabbed, never in geometry,
## never rolls, the player's own yaw and pitch untouched, and the view stays where the framing left it at the end.
func _check_safe_and_the_players_own(name: String, m: Dictionary) -> void:
	var r: Dictionary = m["r"]
	check(r["caught"] and r["grab_tick"] > 0, "%s: the spider is caught and takes hold again" % name)
	check(r["unsafe"] == 0, "%s: the camera is never inside geometry (%d ticks)" % [name, r["unsafe"]])
	check(r["rolled"] == 0, "%s: the camera never rolls (%d ticks)" % [name, r["rolled"]])
	check_near(r["yaw_dev"], 0.0, 1e-9, "%s: the player's own yaw is untouched while the line is out" % name)
	check_near(r["elevation_dev"], 0.0, 1e-9, "%s: so is the player's own pitch" % name)
	check_near(absf(angle_difference(r["view_end"], r["view_on_line"])), 0.0, deg_to_rad(1.0), "%s: when the line ends the view stays where the framing put it" % name)
	check_eq(r["yaw_assist_end"], 0.0, "%s: and the turn has become the player's own yaw" % name)


## What the framing must achieve where it works: a short crowded stretch while it turns, none after the first 0.83 s, none after the grab.
func _check_framed_view_is_clear(name: String, m: Dictionary) -> void:
	var s: Dictionary = m["s"]
	check(s["line_crowded"] <= FRAMED_CROWDED_MAX, "%s: crowded for at most %d ticks on the line (%d)" % [name, FRAMED_CROWDED_MAX, s["line_crowded"]])
	check(s["longest"] <= FRAMED_RUN_MAX, "%s: no crowded stretch longer than %d ticks (%d)" % [name, FRAMED_RUN_MAX, s["longest"]])
	check(s["late"] <= LATE_MAX and s["late_longest"] <= LATE_RUN_MAX, "%s: from %d ticks after the catch to the grab at most %d crowded ticks, none in a run over %d (%d ticks, longest %d) - runs %s" % [name, FRAMED_SETTLED_TICK, LATE_MAX, LATE_RUN_MAX, s["late"], s["late_longest"], str(s["runs"])])
	check(s["after_crowded"] == 0, "%s: not crowded in the 2 s after the grab (%d ticks)" % [name, s["after_crowded"]])
	check(s["min_boom"] > 1.0, "%s: the boom never collapses (smallest %.2f WU)" % [name, s["min_boom"]])


func test_the_cliff_cap_catch_and_grab_with_no_camera_input() -> void:
	var before_quick: Dictionary = await _measure("cliff", "before", false)
	var before_settled: Dictionary = await _measure("cliff", "before", true)
	var capped_quick: Dictionary = await _measure("cliff", "capped", false)
	var capped_settled: Dictionary = await _measure("cliff", "capped", true)
	var uncapped_quick: Dictionary = await _measure("cliff", "uncapped", false)
	var uncapped_settled: Dictionary = await _measure("cliff", "uncapped", true)
	for pair in [["before, quick reel", before_quick], ["before, reel after settling", before_settled]]:
		var r: Dictionary = pair[1]["r"]
		var s: Dictionary = pair[1]["s"]
		check(r["caught"] and r["grab_tick"] > 0, "%s: the spider is caught and takes hold again" % pair[0])
		check(s["min_boom"] < 1.0, "%s: the scenario really is squeezed without the framing (smallest boom %.2f WU)" % [pair[0], s["min_boom"]])
		check(s["line_crowded"] >= int(0.8 * s["line_ticks"]), "%s: the default view is crowded for nearly all of the time on the line (%d of %d ticks)" % [pair[0], s["line_crowded"], s["line_ticks"]])
	# Chunk 6A's framing, up to a half turn: the mechanism is intact and still does what 6A measured.
	for pair in [["uncapped, quick reel", uncapped_quick], ["uncapped, reel after settling", uncapped_settled]]:
		var r: Dictionary = pair[1]["r"]
		_check_safe_and_the_players_own(pair[0], pair[1])
		check(r["max_assist"] > deg_to_rad(45.0), "%s: the framing turned the view (by up to %.0f degrees)" % [pair[0], rad_to_deg(r["max_assist"])])
		_check_framed_view_is_clear(pair[0], pair[1])
	# The shipped framing, capped at 45 degrees: the smallest turn that clears the cliff is 90, so from the default view
	# nothing turns and the view is what chunk 5 had. That is the cost of the cap, asserted as a measurement.
	for pair in [["capped, quick reel", capped_quick], ["capped, reel after settling", capped_settled]]:
		var r: Dictionary = pair[1]["r"]
		var s: Dictionary = pair[1]["s"]
		_check_safe_and_the_players_own(pair[0], pair[1])
		check(r["max_assist"] <= deg_to_rad(45.0) + 1e-6, "%s: the turn never exceeds the cap (%.1f degrees)" % [pair[0], rad_to_deg(r["max_assist"])])
		check(s["line_crowded"] >= int(0.8 * s["line_ticks"]), "%s: from the default view the cap leaves the cliff-cap catch as crowded as chunk 5's camera (%d of %d ticks)" % [pair[0], s["line_crowded"], s["line_ticks"]])
	_report.append("VERDICT cliff cap, default view: the view of the recovery is crowded for %.2f s of %.2f s on the line with a quick reel and %.2f s of %.2f s with a reel after settling in the camera of chunk 5. With the framing capped at 45 degrees (what ships now) it is %.2f s and %.2f s (the smallest turn that clears the cliff is 90 degrees, so nothing turns), and %.2f s and %.2f s in the 2 s after the grab. With chunk 6A's uncapped framing it was %.2f s and %.2f s, none after the first %.2f s, and %.2f s and %.2f s in the 2 s after the grab." % [
		before_quick["s"]["line_crowded"] / 60.0, before_quick["s"]["line_ticks"] / 60.0, before_settled["s"]["line_crowded"] / 60.0, before_settled["s"]["line_ticks"] / 60.0,
		capped_quick["s"]["line_crowded"] / 60.0, capped_settled["s"]["line_crowded"] / 60.0, capped_quick["s"]["after_crowded"] / 60.0, capped_settled["s"]["after_crowded"] / 60.0,
		uncapped_quick["s"]["line_crowded"] / 60.0, uncapped_settled["s"]["line_crowded"] / 60.0, FRAMED_SETTLED_TICK / 60.0, uncapped_quick["s"]["after_crowded"] / 60.0, uncapped_settled["s"]["after_crowded"] / 60.0])
	_write_report()


func test_the_cliff_cap_catch_from_a_view_45_degrees_off_is_framed_within_the_cap() -> void:
	var before: Dictionary = await _measure("cliff45", "before", false)
	var capped: Dictionary = await _measure("cliff45", "capped", false)
	check(before["s"]["line_crowded"] >= int(0.8 * before["s"]["line_ticks"]), "before: this view is crowded for nearly all of the time on the line too (%d of %d ticks)" % [before["s"]["line_crowded"], before["s"]["line_ticks"]])
	_check_safe_and_the_players_own("capped, view 45 degrees off", capped)
	check_near(capped["r"]["max_assist"], deg_to_rad(45.0), deg_to_rad(1.0), "the framing turns the view by the cap, 45 degrees (%.1f)" % rad_to_deg(capped["r"]["max_assist"]))
	_check_framed_view_is_clear("capped, view 45 degrees off", capped)
	_report.append("VERDICT cliff cap, a view 45 degrees off the open side: crowded %.2f s of %.2f s on the line before, %.2f s with the framing capped at 45 degrees (its turn is exactly the cap), and %.2f s in the 2 s after the grab." % [before["s"]["line_crowded"] / 60.0, before["s"]["line_ticks"] / 60.0, capped["s"]["line_crowded"] / 60.0, capped["s"]["after_crowded"] / 60.0])
	_write_report()


func test_the_slab_edge_catch_is_not_made_worse() -> void:
	var before: Dictionary = await _measure("14.0", "before", false)
	var framed: Dictionary = await _measure("14.0", "capped", false)
	check(before["r"]["caught"] and framed["r"]["caught"], "both runs catch the spider")
	check(before["s"]["line_crowded"] > 60, "the slab-edge catch is crowded in the camera of chunk 5 (%d ticks)" % before["s"]["line_crowded"])
	check(framed["s"]["line_crowded"] <= before["s"]["line_crowded"], "the framing does not make it worse (%d against %d ticks)" % [framed["s"]["line_crowded"], before["s"]["line_crowded"]])
	check(framed["s"]["after_crowded"] <= before["s"]["after_crowded"], "nor the 2 s after the grab (%d against %d ticks)" % [framed["s"]["after_crowded"], before["s"]["after_crowded"]])
	check(framed["r"]["unsafe"] == 0 and framed["r"]["rolled"] == 0, "the camera is never inside geometry and never rolls")
	check(framed["r"]["max_assist"] <= deg_to_rad(45.0) + 1e-6, "and the turn never exceeds the cap (%.1f degrees)" % rad_to_deg(framed["r"]["max_assist"]))
	_report.append("VERDICT slab edge (M03 F04): crowded %.2f s of %.2f s on the line before, %.2f s framed at the cap (the swing under the slab and the grab on its underside, which the framing does not address, remain)." % [before["s"]["line_crowded"] / 60.0, before["s"]["line_ticks"] / 60.0, framed["s"]["line_crowded"] / 60.0])
	_write_report()
