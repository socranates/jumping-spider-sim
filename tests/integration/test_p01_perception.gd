extends "res://tests/perception_test_case.gd"
## Gate P01 (spec 25, T06; A-010, A-022): hidden prey does not update a classified observation, and turning toward a visible
## cue improves classification after the configured inspection period. It is shown with the labelled test target (a prop that
## walks a path, goes behind the screen and comes out; it is not a fly) on the stage in the lab's north-west corner, the spider
## on the ledge, in interactive worlds so that the player's own path is the one used: the camera, the Focus input through the
## player controller, the HUD. What the player does comes only from what the spider has sensed (the memory), never from where
## the marker really is; the checks (and only the checks) look at the truth.
##
## Eight fixtures, each a fresh world:
##   F1 visible motion in the periphery gives a coarse cue: a bearing, no position, no category, one cue per cooldown
##   F2 orbiting the camera toward it, without Focus, grants no inspection and leaves the cone where it was
##   F3 holding Focus toward the cue turns the body at the capped rate, and the classification improves after the configured
##      inspection period and not before
##   F4 a target that goes behind cover does not update the classified observation, and the HUD shows no coordinates of it
##   F5 the last-seen mark stays put, goes stale and expires
##   F6 seen again (after turning toward its cue) the one remembered place it could be is updated: reacquisition by evidence, not by name
##   F7 inspecting a remembered spot and finding it empty drops the mark; a spot the world hides cannot be called empty
##   F8 a target the spider never sensed leaves nothing in the presentation, even where the camera sees it, and the gaze
##      overlay does not change for it
## Writes tests/reports/p01_report.txt.

const Evidence := preload("res://tests/evidence.gd")
const PerceptionHud := preload("res://scripts/presentation/perception_hud.gd")
const GazeOverlay := preload("res://scripts/presentation/gaze_overlay.gd")
const JumpHud := preload("res://scripts/presentation/jump_hud.gd")
const TestTarget := preload("res://scripts/habitat/test_target.gd")
const REPORT_PATH := "res://tests/reports/p01_report.txt"
const AWAY := Vector3(1.0, 0.0, -0.2)

var _results: Array[Fixture] = []
var _numbers: String = ""


class Fixture extends RefCounted:
	var name: String
	var notes: PackedStringArray = PackedStringArray()
	var problems: PackedStringArray = PackedStringArray()

	func _init(p_name: String) -> void:
		name = p_name

	## Records a measurement; with a condition, a problem when it does not hold.
	func need(condition: bool, ok_text: String, problem: String) -> bool:
		if condition:
			notes.append(ok_text)
		else:
			problems.append(problem)
		return condition

	func note(text: String) -> void:
		notes.append(text)

	func ok() -> bool:
		return problems.is_empty()


func test_p01_hidden_prey_does_not_update_a_classified_observation_and_turning_toward_a_visible_cue_improves_classification() -> void:
	_results.clear()
	for fixture: Callable in [_f1_cue, _f2_orbit, _f3_turn, _f4_hidden, _f5_stale, _f6_reacquire, _f7_empty, _f8_never_sensed]:
		var f: Fixture = await fixture.call()
		_results.append(f)
		if world != null and is_instance_valid(world):
			world.free()
			world = null
	var lines := PackedStringArray()
	lines.append("P01 perception report (spec 25): hidden prey does not update a classified observation; turning toward a visible cue improves classification after the configured inspection period")
	lines.append("timestamp_utc: %sZ" % Time.get_datetime_string_from_system(true))
	lines.append(Evidence.describe(Evidence.identity("res://")))
	lines.append("engine: %s" % Engine.get_version_info()["string"])
	lines.append("target: the labelled test target (A-010), a magenta marker on a rod and base that walks a path at %.1f WU/s, goes behind a 3 WU screen and comes out; it is not a fly and has no AI" % TestTarget.DEFAULT_SPEED)
	lines.append("setup: the spider on the 2 WU ledge facing the stage, interactive worlds (camera rig, player controller, perception HUD); what the player does comes only from the memory; checks read the truth")
	lines.append("numbers (from the species profile): " + _numbers)
	var passed := 0
	for f in _results:
		if f.ok():
			passed += 1
		lines.append("%s %s" % ["PASS" if f.ok() else "FAIL", f.name])
		for n in f.notes:
			lines.append("    %s" % n)
		for p in f.problems:
			lines.append("    PROBLEM: %s" % p)
		check(f.ok(), "%s: %s" % [f.name, "; ".join(f.problems)])
	var summary := "P01 result: %d of %d fixtures passed: a hidden target left the classified observation untouched; turning toward a visible cue improved the classification after the configured inspection period" % [passed, _results.size()]
	lines.append("")
	lines.append(summary)
	print(summary)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/reports"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()


# ------------------------------------------------------------------ the player's hand and eye

## Focus held toward a world direction, or released (null), through the player controller.
func steer(dir: Variant) -> void:
	if dir is Vector3:
		world.controller.focus_override = true
		world.controller.focus_direction_override = dir
	else:
		world.controller.focus_override = false
		world.controller.focus_direction_override = null


## What a player does with what the spider has sensed: while the thing is being inspected, keep turned toward where it is
## observed; when only a cue is recent, turn toward the cue's bearing; otherwise let go. Never toward where it really is.
func follow_what_is_sensed() -> void:
	var c := target_contact()
	if c == null:
		steer(null)
	elif c.is_inspected_now():
		steer((c.position - eye()).normalized())
	elif c.cue_count > 0 and mem().cue_age_s(c) < 1.0 and c.cue_direction.length_squared() > 0.5:
		steer(c.cue_direction)
	else:
		steer(null)


func hud_view() -> Dictionary:
	return world.perception_hud.build_view(world.camera_rig.camera, world.get_viewport().get_visible_rect(), world.get_world_3d().direct_space_state)


## A second viewpoint, high on the west side of the stage, from which the camera sees the marker and its remembered place in the
## open (over the screen) whatever the spider can see: the picture the HUD would draw for it. The player's camera is behind the
## spider and cannot see behind the screen either.
func side_camera() -> Camera3D:
	var cam := Camera3D.new()
	sandbox.add_child(cam)
	cam.look_at_from_position(Vector3(-29.8, 9.0, -3.5), Vector3(-25.0, 1.4, -7.9))
	return cam


func side_view(cam: Camera3D) -> Dictionary:
	return world.perception_hud.build_view(cam, world.get_viewport().get_visible_rect(), world.get_world_3d().direct_space_state)


## The spider on the ledge facing the west end, the marker walking east from there, the spider following it with Focus until the
## marker has been classified and then lost behind the screen. Returns the contact, or null.
func story_until_lost(f: Fixture) -> ObservationMemory.Contact:
	await spawn_stage(true, heading_toward(Vector3(-28.8, 1.4, -7.9)), null)
	for i in 600:
		follow_what_is_sensed()
		await physics_frames(1)
		var c := target_contact()
		if c != null and not c.is_live() and c.has_position:
			steer(null)
			return c
	f.problems.append("the marker was never classified and lost behind the screen")
	return null


# ------------------------------------------------------------------ the fixtures

func _f1_cue() -> Fixture:
	var f := Fixture.new("F1 visible motion in the periphery gives a coarse cue and nothing finer")
	await spawn_stage(true, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([EAST_VISIBLE, EAST_VISIBLE + Vector3(2.0, 0.0, 0.0)])))
	var cues: Array[Dictionary] = []
	world.sensor.cue_emitted.connect(func(o: Observation) -> void:
		cues.append({"tick": o.observed_tick, "dir": o.direction, "valid": o.is_valid(), "position": o.has_position, "category": o.category, "truth_dir": toward(target().global_position)}))
	await physics_frames(240)
	var c := target_contact()
	if not f.need(c != null, "the marker walks in view, off to the right of the cone", "no contact from a marker walking in view in the periphery"):
		return f
	f.need(cues.size() >= 3 and cues.size() <= 6, "%d cues in 4 s" % cues.size(), "%d cues in 4 s (the cooldown allows 3 to 6)" % cues.size())
	var spacing := 999.0
	var worst := 0.0
	var all_valid := true
	var any_position := false
	var any_category := false
	for i in cues.size():
		worst = maxf(worst, rad_to_deg((cues[i]["dir"] as Vector3).angle_to(cues[i]["truth_dir"])))
		all_valid = all_valid and bool(cues[i]["valid"])
		any_position = any_position or bool(cues[i]["position"])
		any_category = any_category or cues[i]["category"] != Observation.MOVEMENT
		if i > 0:
			spacing = minf(spacing, float(int(cues[i]["tick"]) - int(cues[i - 1]["tick"])) / 60.0)
	var cooldown: float = world.spider.profile.cue_cooldown_s
	f.need(spacing >= cooldown - 1e-6, "cues are %.2f s apart at the least (configured cooldown %.2f s)" % [spacing, cooldown], "two cues %.2f s apart (configured cooldown %.2f s)" % [spacing, cooldown])
	f.need(all_valid, "every cue is a valid observation record (spec 21.3)", "an invalid cue record")
	f.need(not any_position and not any_category, "no cue carries a position or a category beyond movement", "a cue carried a position or a finer category")
	f.need(worst <= 20.0, "the bearing is within %.1f degrees of the truth (a 22.5 degree sector, a 30 degree band)" % worst, "a cue bearing was %.1f degrees off" % worst)
	f.need(not c.has_position and c.category == Observation.MOVEMENT and c.modality == Observation.PERIPHERAL, "the record knows only 'movement', coming from that side: no position, no refinement", "the record claims more than a cue gave: position %s, category %s" % [c.has_position, c.category])
	f.need(world.sensor.inspections_made == 0, "no inspection was made: the cone never touched it", "%d inspections without the cone on it" % world.sensor.inspections_made)
	var v := hud_view()
	f.need((v["rings"] as Array).is_empty() and (v["labels"] as Array).is_empty(), "the screen shows an edge marker only (no ring, no words, no place)", "the HUD drew a place or words for a bare cue")
	return f


func _f2_orbit() -> Fixture:
	var f := Fixture.new("F2 orbiting the camera toward the cue, without Focus, grants no inspection")
	await spawn_stage(true, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([EAST_VISIBLE, EAST_VISIBLE + Vector3(2.0, 0.0, 0.0)])))
	await wait_until(func() -> bool: return world.sensor.cues_made >= 1, 120)
	var c := target_contact()
	if not f.need(c != null, "a cue arrived", "no cue arrived"):
		return f
	var heading0 := heading_deg()
	var axis0: Vector3 = world.sensor.last_axis
	var bearing := rad_to_deg(atan2(-c.cue_direction.x, -c.cue_direction.z))
	world.camera_rig.look(rad_to_deg(world.camera_rig.yaw) - bearing, 0.0)
	await physics_frames(300)
	var camera_yaw := rad_to_deg(world.camera_rig.yaw)
	f.need(absf(camera_yaw - bearing) < 1.0, "the player swung the camera %.0f degrees to look straight at the cue's bearing" % absf(camera_yaw), "the camera did not turn (%.1f vs %.1f)" % [camera_yaw, bearing])
	f.need(absf(heading_deg() - heading0) < 1e-6, "for 5 s the body's heading did not change (%.6f degrees)" % absf(heading_deg() - heading0), "the camera orbit turned the body by %.2f degrees" % absf(heading_deg() - heading0))
	f.need(world.sensor.last_axis.angle_to(axis0) < deg_to_rad(0.001), "and the sensor's cone axis did not move", "the cone axis moved with the camera")
	f.need(world.sensor.inspections_made == 0 and not c.has_position and c.category == Observation.MOVEMENT, "the thing is still only 'movement': no inspection, no position, no refinement, though the camera looked straight at it", "orbiting the camera granted an inspection (%d inspections, category %s)" % [world.sensor.inspections_made, c.category])
	return f


func _f3_turn() -> Fixture:
	var f := Fixture.new("F3 holding Focus toward the visible cue improves classification after the configured inspection period")
	await spawn_stage(true, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([EAST_VISIBLE, EAST_VISIBLE + Vector3(2.0, 0.0, 0.0)])))
	await wait_until(func() -> bool: return world.sensor.cues_made >= 1, 120)
	var c := target_contact()
	if not f.need(c != null, "a cue arrived; the thing is 'movement' only", "no cue arrived"):
		return f
	var before := Observation.rank(c.category)
	var prof: RefCounted = world.spider.profile
	_numbers = "inspection cone %.0f deg; continuous exposure %.2f s for possible prey and %.2f s for fly-like prey; cue cooldown %.1f s; broad scan %.0f Hz, close checks every tick within %.0f WU; memory %.0f s; Focus turns at most %.0f deg/s" % [prof.inspect_cone_degrees, prof.easy_target_inspection_s, prof.fly_like_inspection_s, prof.cue_cooldown_s, prof.broad_query_hz, prof.close_check_range_wu, prof.memory_decay_s, prof.focus_turn_rate_deg_s]
	var seen: Array[Dictionary] = []
	world.memory.category_changed.connect(func(_c: ObservationMemory.Contact, _old: StringName, new_category: StringName) -> void: seen.append({"tick": world.sensor.tick, "category": new_category}))
	# The player turns the camera to the cue's bearing and holds Focus: the body follows the camera's aim at the capped rate.
	var bearing := rad_to_deg(atan2(-c.cue_direction.x, -c.cue_direction.z))
	world.camera_rig.look(rad_to_deg(world.camera_rig.yaw) - bearing, 0.0)
	await physics_frames(5)
	var heading0 := heading_deg()
	var first_inspect := -1
	var worst_step := 0.0
	var last_heading := heading0
	world.controller.focus_override = true
	var focus_tick: int = world.sensor.tick
	for i in 240:
		await physics_frames(1)
		worst_step = maxf(worst_step, absf(heading_deg() - last_heading))
		last_heading = heading_deg()
		if first_inspect < 0 and c.is_inspected_now():
			first_inspect = world.sensor.tick
	f.need(first_inspect > 0, "the cone reached it %.2f s after Focus was pressed" % (float(first_inspect - focus_tick) / 60.0), "the cone never reached the marker after Focus was held toward the cue")
	f.need(absf(heading_deg() - heading0) > 20.0, "the body turned %.0f degrees toward the cue" % absf(heading_deg() - heading0), "the body did not turn")
	var cap_per_tick: float = float(world.spider.profile.focus_turn_rate_deg_s) / 60.0
	f.need(worst_step <= cap_per_tick + 1e-3, "at no more than %.2f degrees a tick (cap %.0f degrees/s = %.2f a tick)" % [worst_step, world.spider.profile.focus_turn_rate_deg_s, cap_per_tick], "a tick turned %.2f degrees (cap %.2f)" % [worst_step, cap_per_tick])
	if first_inspect < 0:
		return f
	var possible := -1
	var fly := -1
	for s in seen:
		if s["category"] == Observation.POSSIBLE_PREY and possible < 0:
			possible = int(s["tick"])
		if s["category"] == Observation.FLY_LIKE_PREY and fly < 0:
			fly = int(s["tick"])
	# The first inspection tick is the first tick of exposure, so the exposure when a category changes counts it too.
	var easy: float = world.spider.profile.easy_target_inspection_s
	var fly_period: float = world.spider.profile.fly_like_inspection_s
	var d_possible := float(possible - first_inspect + 1) / 60.0
	var d_fly := float(fly - first_inspect + 1) / 60.0
	f.need(possible > 0 and d_possible >= easy - 1e-6 and d_possible <= easy + 0.25, "possible prey after %.2f s of continuous inspection (configured %.2f s), not before" % [d_possible, easy], "possible prey came after %.2f s of inspection (configured %.2f s)" % [d_possible, easy])
	f.need(fly > 0 and d_fly >= fly_period - 1e-6 and d_fly <= fly_period + 0.3, "fly-like prey after %.2f s (configured %.2f s), not before" % [d_fly, fly_period], "fly-like prey came after %.2f s of inspection (configured %.2f s)" % [d_fly, fly_period])
	f.need(Observation.rank(c.category) > before, "classification improved: %s -> %s" % [Observation.CATEGORIES[before], c.category], "classification did not improve")
	f.need(c.has_position and c.position.distance_to(target().global_position) < 0.6, "and the record has a position within %.2f WU of the marker" % c.position.distance_to(target().global_position), "the inspected position is off")
	var words := hud_view()["labels"] as Array
	f.need(not words.is_empty() and str(words[0]["text"]) == "fly-like prey", "the screen says so, in words: \"%s\"" % (str(words[0]["text"]) if not words.is_empty() else ""), "the HUD does not show the category")
	return f


func _f4_hidden() -> Fixture:
	var f := Fixture.new("F4 a hidden target does not update the classified observation, and no coordinates of it reach the HUD")
	var c := await story_until_lost(f)
	if c == null:
		return f
	f.need(c.category == Observation.FLY_LIKE_PREY and c.has_mark(), "classified as fly-like prey, then lost behind the screen: it has a mark", "not classified and marked when lost (%s)" % c.category)
	var snap := {"pos": c.position, "tick": c.position_tick, "obs_tick": c.observed_tick, "cat": c.category, "mod": c.modality, "conf0": c.confidence_at_loss}
	var ingested := mem().ingested
	var truth0: Vector3 = target().global_position
	var hidden_ticks := 0
	var changed := ""
	var leak := false
	var drawn := 0
	var cam: Camera3D = world.camera_rig.camera
	var side := side_camera()
	var seen_by_side := 0
	var rect := world.get_viewport().get_visible_rect()
	for i in 300:
		await physics_frames(1)
		if not target_is_hidden():
			break
		hidden_ticks += 1
		if c.position != snap["pos"] or c.position_tick != snap["tick"] or c.observed_tick != snap["obs_tick"] or c.category != snap["cat"] or c.modality != snap["mod"]:
			changed = "tick %d" % i
		if mem().ingested != ingested:
			changed = "an observation was ingested at tick %d" % i
		if i % 10 == 0:
			for viewer: Camera3D in [cam, side]:
				var v := hud_view() if viewer == cam else side_view(viewer)
				var truth_px := viewer.unproject_position(target().global_position)
				if viewer == side and rect.has_point(truth_px) and not viewer.is_position_behind(target().global_position) and not JumpHud.point_hidden(viewer, world.get_world_3d().direct_space_state, target().global_position, rect, 0.5):
					seen_by_side += 1
				for ring: Dictionary in v["rings"]:
					drawn += 1
					if (ring["pos"] as Vector2).distance_to(viewer.unproject_position(snap["pos"])) > 1.0:
						leak = true
					if (ring["pos"] as Vector2).distance_to(truth_px) < 8.0 and target().global_position.distance_to(snap["pos"]) > 1.5:
						leak = true
				for l: Dictionary in v["labels"]:
					if (l["pos"] as Vector2).distance_to(truth_px) < 30.0 and target().global_position.distance_to(snap["pos"]) > 1.5:
						leak = true
				if not (v["edges"] as Array).is_empty():
					leak = true   # nothing peripheral can be coming from behind the screen
	f.need(hidden_ticks >= 100, "the marker stayed hidden for %d ticks (%.1f s) while it walked on %.1f WU" % [hidden_ticks, hidden_ticks / 60.0, target().global_position.distance_to(truth0)], "it was hidden for only %d ticks" % hidden_ticks)
	f.need(changed == "", "through all of it the record did not change: position, tick observed, category and modality as at the loss, and no observation was ingested", "the record changed while the target was hidden (%s)" % changed)
	f.need(c.confidence < snap["conf0"], "only its confidence fell, %.2f to %.2f" % [snap["conf0"], c.confidence], "confidence did not fall")
	f.need(target().global_position.distance_to(snap["pos"]) > 2.0, "the marker is %.1f WU from where the memory has it" % target().global_position.distance_to(snap["pos"]), "the marker did not move away from the mark")
	f.need(seen_by_side > 0 and drawn > 0, "from a second viewpoint, on the west side of the stage, the camera sees the marker in the open (%d of the samples) and the HUD drew the remembered place %d times" % [seen_by_side, drawn], "the second viewpoint did not see both the marker and the mark (%d, %d)" % [seen_by_side, drawn])
	f.need(not leak, "every ring was at the projection of the last observed place and none at the marker, no label near the marker, no edge marker: no coordinates of the hidden target reached the HUD", "the HUD drew something that follows the hidden target")
	return f


func _f5_stale() -> Fixture:
	var f := Fixture.new("F5 the last-seen mark stays put, goes stale and expires")
	var c := await story_until_lost(f)
	if c == null:
		return f
	var ended: Array[String] = []
	mem().contact_ended.connect(func(_c: ObservationMemory.Contact, why: String) -> void: ended.append(why))
	target().set_enabled(false)   # it is gone for good: no new evidence from here on
	var mark := c.position
	var conf0 := c.confidence_at_loss
	var lost_tick := c.lost_tick
	var fresh := mem().staleness_of(c)
	var decay_ticks := int(roundf(float(world.spider.profile.memory_decay_s) * 60.0))
	await wait_until(func() -> bool: return world.sensor.tick - lost_tick >= decay_ticks / 2, 400)
	f.need(c.has_mark() and c.position == mark, "half the memory time (%.1f s) after the loss the mark is exactly where it was (%s)" % [decay_ticks / 120.0, str(mark)], "the mark moved or went")
	f.need(mem().staleness_of(c) > 0.45 and mem().staleness_of(c) < 0.55 and mem().staleness_of(c) > fresh, "stale: %.2f of the way to forgotten" % mem().staleness_of(c), "staleness at 3 s was %.2f" % mem().staleness_of(c))
	f.need(absf(c.confidence - 0.5 * conf0) < 0.03 * conf0 + 0.001, "confidence has fallen from %.2f to %.2f, a straight line to nothing at %.1f s" % [conf0, c.confidence, decay_ticks / 60.0], "confidence at half time was %.2f (from %.2f)" % [c.confidence, conf0])
	var side := side_camera()
	var v := side_view(side)
	if f.need(not (v["rings"] as Array).is_empty(), "seen from the west side of the stage the mark is a ring", "no mark ring from the west side"):
		var ring: Dictionary = v["rings"][0]
		f.need(float(ring["alpha"]) < PerceptionHud.MARK_ALPHA_FRESH * 0.8 and float(ring["dash"]) < 0.8, "fainter and more broken (strength %.2f of %.2f when fresh, dash %.2f of 1)" % [float(ring["alpha"]), PerceptionHud.MARK_ALPHA_FRESH, float(ring["dash"])], "the ring did not fade (%.2f, dash %.2f)" % [float(ring["alpha"]), float(ring["dash"])])
		f.need((ring["pos"] as Vector2).distance_to(side.unproject_position(mark)) < 1.0, "at the place it was last seen, fixed in the world", "the ring is not at the last observed place")
	await wait_until(func() -> bool: return world.sensor.tick - lost_tick >= decay_ticks - 1, 400)
	f.need(mem().marks().size() == 1, "one tick before the memory time (%.2f s) it is still just there" % ((decay_ticks - 1) / 60.0), "the mark expired early")
	await wait_until(func() -> bool: return world.sensor.tick - lost_tick >= decay_ticks + 1, 60)
	f.need(mem().marks().is_empty() and mem().count() == 0 and ended == ["expired"], "at %.1f s it expired and the contact with it (reason %s)" % [decay_ticks / 60.0, str(ended)], "the mark did not expire when the memory did (%s)" % str(ended))
	var after := hud_view()
	f.need((after["rings"] as Array).is_empty() and (after["labels"] as Array).is_empty() and (after["edges"] as Array).is_empty(), "and nothing of it is left on the screen", "something is still drawn after the memory let go")
	return f


func _f6_reacquire() -> Fixture:
	var f := Fixture.new("F6 seen again after turning toward its cue: the one remembered place it could be is updated (reacquisition by evidence, not by name)")
	var c := await story_until_lost(f)
	if c == null:
		return f
	var track := c.track_id
	# Changed assumption (chunk 7A, A-027): the record used to be found again through the marker's world id. Now sight of it has been lost,
	# the id decides nothing: while the marker is out of sight the fixture gives it another name, and the spider has to find the record
	# again by where it was last observed, how long ago, how big it looks and what it can look like.
	target().target_id = "test_target_renamed"
	var cues0 := c.cue_count
	var lost_tick := c.lost_tick
	var snap_pos := c.position
	var came_out := -1
	var reacquired := -1
	for i in 600:
		follow_what_is_sensed()
		await physics_frames(1)
		if came_out < 0 and not target_is_hidden():
			came_out = world.sensor.tick
		if c.is_live() and c.reacquisitions >= 1:
			reacquired = world.sensor.tick
			break
	steer(null)
	if not f.need(reacquired > 0, "the marker came out on the far side and was inspected again", "the marker was never reacquired"):
		return f
	f.need(came_out > 0 and came_out < reacquired, "it came out %.2f s after the loss; the cone had it again %.2f s later" % [float(came_out - lost_tick) / 60.0, float(reacquired - came_out) / 60.0], "bad timing: out at %d, reacquired at %d" % [came_out, reacquired])
	f.need(c.cue_count > cues0, "first came a cue (%d new) from its new side, which did not bring the record back by itself" % (c.cue_count - cues0), "no cue came before the reacquisition")
	f.need(target_contact() == c and c.track_id == track and world.sensor.track_id_for(target().target_id) == track and mem().count() == 1, "it is the same record and the same track (%s), not a new one, although the world now calls the marker by another name" % track, "a new record was made")
	f.need(c.reacquisitions == 1 and c.is_live() and not c.has_mark(), "reacquired once, live, the mark gone", "reacquisitions %d, live %s, mark %s" % [c.reacquisitions, c.is_live(), c.has_mark()])
	f.need(c.position.distance_to(target().global_position) < 0.6 and c.position.distance_to(snap_pos) > 2.0, "its position is updated to where it is now (%.2f WU from the marker, %.1f WU from the old mark)" % [c.position.distance_to(target().global_position), c.position.distance_to(snap_pos)], "the position was not updated (%.2f WU from the marker)" % c.position.distance_to(target().global_position))
	f.need(c.position_tick > lost_tick and Observation.rank(c.category) >= Observation.rank(Observation.POSSIBLE_PREY), "observed again after the loss, and still known as %s (something seen a moment ago is not a stranger)" % c.category, "the reacquired record is %s" % c.category)
	return f


func _f7_empty() -> Fixture:
	var f := Fixture.new("F7 inspecting the remembered spot and finding it empty drops the mark; looking away, or a spot the world hides, does not")
	# (a) in plain view and in the cone: the marker is taken away.
	await spawn_stage(true, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(70)
	var c := target_contact()
	if not f.need(c != null and c.category == Observation.FLY_LIKE_PREY, "(a) classified as fly-like prey at the west spot", "(a) not classified first"):
		return f
	var ended: Array[String] = []
	mem().contact_ended.connect(func(_c: ObservationMemory.Contact, why: String) -> void: ended.append(why))
	target().set_enabled(false)
	await wait_until(func() -> bool: return c.has_mark(), 30)
	var marked_at: int = world.sensor.tick
	await wait_until(func() -> bool: return mem().marks().is_empty(), 120)
	var looked := float(world.sensor.tick - marked_at) / 60.0
	f.need(ended == ["empty"] and mem().count() == 0, "(a) taken away, lost, and %.2f s of looking at the empty spot dropped the mark (reason empty, not expiry)" % looked, "(a) the empty spot did not drop the mark (%s)" % str(ended))
	var check_s: float = world.spider.profile.easy_target_inspection_s
	f.need(looked >= check_s - 1e-6 and looked <= check_s + 0.3, "(a) and not sooner than the %.2f s the check needs" % check_s, "(a) dropped after %.2f s (the check needs %.2f s)" % [looked, check_s])
	world.free()
	# (b) the body looks away first: nobody checks the spot.
	await spawn_stage(true, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(70)
	var d := target_contact()
	steer(AWAY.normalized())
	await wait_until(func() -> bool: return not d.is_live(), 120)
	target().set_enabled(false)
	await physics_frames(150)
	f.need(d.has_mark() and mem().count() == 1, "(b) with the body turned away the marker was taken away unseen: 2.5 s later the mark is still there (nobody has looked)", "(b) the mark went without anyone looking")
	world.free()
	# (c) the world hides the spot: a wall goes up; the marker is taken away behind it.
	await spawn_stage(true, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(70)
	var e := target_contact()
	world.lab.add_fixture_piece("test_wall", "wall", Vector3(-30.0, 0.0, -5.0), Vector3(-23.0, 4.0, -4.8))
	await wait_until(func() -> bool: return not e.is_live(), 120)
	target().set_enabled(false)
	await physics_frames(150)
	f.need(e.has_mark() and e.position.distance_to(WEST_VISIBLE) < 0.6, "(c) behind a wall 2.5 s of looking at the wall did not call the place behind it empty: the mark stays", "(c) the hidden spot was called empty")
	return f


func _f8_never_sensed() -> Fixture:
	var f := Fixture.new("F8 a target the spider never sensed leaves nothing in the presentation, even where the camera sees it")
	# (a) behind the spider, in the 60 degree wedge the field leaves out, with the camera turned to look right at it.
	await spawn_stage(true, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([BEHIND_SPIDER, BEHIND_SPIDER + Vector3(2.0, 0.0, 0.0)])))
	world.camera_rig.look(180.0, 0.0)
	await physics_frames(180)
	await process_frames(2)
	var cam: Camera3D = world.camera_rig.camera
	var at: Vector3 = target().global_position
	f.need(not cam.is_position_behind(at) and world.get_viewport().get_visible_rect().has_point(cam.unproject_position(at)) and target().velocity.length() > 0.5, "(a) the marker walks behind the spider, and the camera, turned round, has it on the screen", "(a) the marker was not on the camera's screen")
	var v := hud_view()
	f.need(mem().count() == 0 and world.sensor.cues_made == 0 and world.sensor.inspections_made == 0 and world.sensor.track_id_for(TARGET_ID) == "", "(a) the spider has sensed nothing: no cue, no inspection, not even a track id", "(a) the sensor made evidence out of the blind wedge")
	f.need((v["edges"] as Array).is_empty() and (v["labels"] as Array).is_empty() and (v["rings"] as Array).is_empty() and world.perception_hud.label_texts().is_empty(), "(a) so no edge marker, ring, label or mark is drawn for it (spec 6.4)", "(a) the presentation drew something for a target never sensed")
	world.free()
	# (b) behind the screen from the start, in plain view of nothing: and the gaze overlay says nothing of it either.
	await spawn_stage(true, 0.0, BEHIND_SCREEN)
	settings.set_value("show_gaze", true)
	await physics_frames(120)
	await process_frames(3)
	var with_target: Dictionary = world.gaze_overlay.footprint.duplicate()
	f.need(target_is_hidden() and mem().count() == 0 and world.sensor.track_id_for(TARGET_ID) == "", "(b) the marker stands dead ahead behind the screen: hidden, and never sensed", "(b) the marker behind the screen was sensed")
	target().set_enabled(false)
	await process_frames(3)
	f.need(not with_target.is_empty() and world.gaze_overlay.footprint == with_target and (with_target["point"] as Vector3).z > -6.0, "(b) the gaze overlay lies on the screen's face (%s) and is exactly the same with the marker taken away: it reveals nothing hidden" % str((with_target["point"] as Vector3).snappedf(0.01)), "(b) the gaze footprint depends on the hidden marker")
	var after := hud_view()
	f.need((after["edges"] as Array).is_empty() and (after["labels"] as Array).is_empty() and (after["rings"] as Array).is_empty(), "(b) and the HUD is empty", "(b) the HUD drew something for the hidden marker")
	return f
