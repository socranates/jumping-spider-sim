extends "res://tests/tether_test_case.gd"
## The safety line (T04, spec 9.1, 17, 21.3) in the real physics world: anchoring at takeoff and the cue before
## commit, payout that never touches the arc, a miss caught into HANGING that settles, lowering and reeling at
## the species rate, reeling up under a lip into a hold, letting go only on purpose, a line whose anchor goes
## away, a snagged line and a blocked reel, completed lines that fade, the labelled debug fallback, the line's
## own prompts, and the F3 and F4 views; the real keys and controller buttons that lower, reel and let go; a
## spider that has come to rest staying put and waking when it should; and the whole practice loop (miss on
## purpose, recover, retry). Gate M03 (ten recoverable misses) is test_m03_tether.gd.

const Tether = preload("res://scripts/movement/tether.gd")
const DebugOverlay = preload("res://scripts/presentation/debug_overlay.gd")
const JumpFeedback = preload("res://scripts/presentation/jump_feedback.gd")


func _start(pose: Transform3D, interactive: bool = false) -> Node3D:
	spawn_world(pose, interactive)
	await physics_frames(6)
	await settle(world.spider)
	return world.spider


func after_each() -> void:
	for a: String in ["reel", "lower", "cancel", "move_forward", "move_back"]:
		Input.action_release(a)


## A real key, joypad axis or joypad button event through the input pipeline (not an action injected by name).
func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _axis(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)


func _button(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)


func test_a_leap_anchors_a_line_at_takeoff_and_pays_it_out_without_touching_the_arc() -> void:
	var spider := await _start(floor_pose(-28.0, 13.0, -90.0))
	var events := record_line_events(spider)
	var under: Vector3 = spider.support.contact_point
	var plan: RefCounted = spider.plan_jump(top_target(-19.0, 13.0))
	check(plan.is_valid(), "a 9 WU leap is reachable")
	check(plan.line_needed > 8.5 and plan.line_needed < 10.0, "it needs about 9 WU of line: %f" % plan.line_needed)
	check(spider.begin_prepare() and spider.commit_jump(plan), "committed")
	check_eq(events, ["anchored:floor"] as Array[String], "the line is anchored to the floor at takeoff")
	var t: RefCounted = spider.tether
	check_eq(t.mode, Tether.Mode.PAYOUT, "paying out")
	check_vec_near(t.anchor_point, under, 1e-4, "at the support point under the body (no remote aiming)")
	check_vec_near(world.lab.get_piece("floor").global_transform * t.anchor_local, under, 1e-4, "stored in the floor's local space")
	check_near(t.max_length, 20.0, 1e-6, "the species maximum")
	var paid_max := 0.0
	while spider.is_airborne():
		await physics_frames(1)
		if t.is_active():
			check(t.paid_length <= t.max_length + 1e-6 and t.paid_length >= paid_max - 1e-6, "the paid length only grows and stays within the maximum")
			paid_max = t.paid_length
			check(not t.taut, "a paying-out line never pulls")
	var rec: Dictionary = spider.last_jump
	check_eq(rec["outcome"], "support", "it lands where the plan said")
	check(not rec["line_ran_out"], "the line never ran out")
	var worst := 0.0
	var path: PackedVector3Array = rec["path"]
	for k in mini(path.size(), plan.path.size()):
		worst = maxf(worst, path[k].distance_to(plan.path[k]))
	check(worst < 1e-3, "the flight is the predicted arc, worst deviation %f WU" % worst)
	check(paid_max > 8.5, "about the jump's length was paid out: %f" % paid_max)
	check_eq(events, ["anchored:floor", "completed"] as Array[String], "landing completes the line")
	check_eq(spider.completed_lines.size(), 1, "the line stays behind")
	var pts: PackedVector3Array = spider.completed_lines[0]["points"]
	check_vec_near(pts[0], under, 1e-4, "from its anchor")
	check(pts[pts.size() - 1].distance_to(spider.global_position) < 0.4, "to where the spider landed")
	check(not t.is_active(), "and the spider has no line of its own any more")


func test_a_surface_that_cannot_hold_silk_is_shown_before_commit_and_the_jump_is_the_same() -> void:
	var spider := await _start(Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(16.5, 2.31, -4.0)), true)
	check_eq(spider.support.profile_id, "ptfe_coated", "standing on the coated platform's top")
	var jc: Node = world.jump_controller
	var hud: CanvasLayer = world.jump_hud
	var cue: Node3D = world.anchor_cue
	var events := record_line_events(spider)
	jc.aim_override = top_target(11.0, -4.0)
	jc.press()
	await physics_frames(14)
	await process_frames(2)
	check(jc.is_aiming() and jc.plan.is_valid(), "aiming at gap_left, reachable")
	check_eq(hud.anchor_text(), JumpFeedback.ANCHOR_TEXT["no_silk"], "before commit the HUD says there will be no line")
	check_eq(cue.shown, "refused", "and the anchor cue is the refused one")
	check_eq(cue.shown_reason, "no_silk", "because the coating will not hold silk")
	var plan: RefCounted = jc.plan
	jc.release()
	await physics_frames(2)
	check(spider.is_airborne(), "the jump goes anyway")
	check_eq(events, ["no_anchor:no_silk"] as Array[String], "without a line")
	check(not spider.tether.is_active(), "no line")
	await wait_until(func() -> bool: return str(spider.last_jump.get("outcome", "")) != "", 90)
	var path: PackedVector3Array = spider.last_jump["path"]
	var worst := 0.0
	for k in mini(path.size(), plan.path.size()):
		worst = maxf(worst, path[k].distance_to(plan.path[k]))
	check(worst < 1e-3, "no line, no change to the arc (A-008): worst deviation %f WU" % worst)
	check_eq(spider.last_jump["outcome"], "support", "it lands as planned")
	# And the other way: gap_left's metal top holds silk.
	await settle(spider)
	jc.aim_override = top_target(17.0, -4.0)
	jc.press()
	await physics_frames(14)
	await process_frames(2)
	check_eq(hud.anchor_text(), JumpFeedback.ANCHOR_TEXT["ok"], "on gap_left the HUD says the line will be anchored")
	check_eq(cue.shown, "ok", "and the cue is the anchored one")
	check("Q / B: cancel the jump" in hud.hint_text(), "Q is labelled as cancelling the jump while aiming: %s" % hud.hint_text())
	jc.cancel()
	await physics_frames(3)


func test_a_jump_that_needs_more_line_than_the_maximum_gets_none() -> void:
	var spider := await _start(floor_pose(-28.0, 13.0, -90.0))
	spider._line_max_base = 4.0
	var events := record_line_events(spider)
	var plan: RefCounted = spider.plan_jump(top_target(-22.0, 13.0))
	check_eq(spider.get_anchor_preview(plan)["reason"], "too_long", "6 WU of jump on 4 WU of line: refused before commit")
	check_eq(spider.get_anchor_preview(spider.plan_jump(top_target(-26.0, 13.0)))["reason"], "ok", "2 WU fits")
	check(spider.begin_prepare() and spider.commit_jump(plan), "committed")
	check_eq(events, ["no_anchor:too_long"] as Array[String], "no line rather than one that would cut the arc short")
	spider.set_reach_factor(1.5)
	check_near(spider.get_line_max_length(), 6.0, 1e-6, "the reach setting scales the maximum line with the reach")


func test_a_miss_is_caught_hangs_below_the_lip_and_settles_without_endless_oscillation() -> void:
	var spider := await _start(cliff_pose())
	var events := record_line_events(spider)
	var states := record_states(spider)
	spider.trace_tether = true
	check(await miss_off_the_cliff(spider), "the line catches the miss")
	check(not world.lab.is_piece_enabled("drop_perch"), "the practice perch dropped away")
	check_eq(states.slice(0, 4), ["PREPARING", "AIRBORNE", "FALLING", "HANGING"] as Array[String], "states")
	check_eq(spider.last_jump["outcome"], "missed", "a miss: nothing where the plan landed")
	check_eq(events.slice(0, 3), ["anchored:cliff_cap", "locked", "caught"] as Array[String], "anchored, locked by the miss, caught")
	var t: RefCounted = spider.tether
	check(t.has_bend and t.bend_surface_id == "cliff_cap", "the line goes over the cap's lip: one bend point")
	check(t.bend_point.x > 25.4 and t.bend_point.y > 6.4, "just outside the edge: %s" % str(t.bend_point))
	check(await wait_settled(spider, 540), "it comes to rest within 9 s")
	var rest_at: Vector3 = spider.global_position
	check(spider.is_resting(), "and is held at rest")
	check("held at rest" in "\n".join(DebugOverlay.describe_line(spider)), "F3 says so")
	check(rest_at.x > 25.3, "hanging clear of the coated face: %s" % str(rest_at))
	check(rest_at.y > 2.0, "well above the floor: %s" % str(rest_at))
	var off: Vector3 = rest_at - t.pivot()
	check(Vector2(off.x, off.z).length() < 0.05, "at rest straight below its bend point (within 0.05 WU), not stopped mid-swing: %f WU off" % Vector2(off.x, off.z).length())
	await physics_frames(240)
	check(spider.global_position.distance_to(rest_at) < 1e-6 and spider.velocity == Vector3.ZERO and spider.is_resting(), "and stays at rest for four more seconds (no endless oscillation, no creep): moved %f WU" % spider.global_position.distance_to(rest_at))
	var problems := PackedStringArray()
	for r: Dictionary in spider.tether_trace:
		problems.append_array(tick_problems(r, 35.0))
	check(problems.is_empty(), "every tick: no overlap, lengths bounded, the line never pushes, no unexplained energy gain: %s" % "; ".join(problems.slice(0, 3)))
	check_eq(spider.tether_fallbacks, 0, "no debug fallback")


func test_lowering_and_reeling_change_the_rest_length_at_the_species_rate() -> void:
	var spider := await _start(cliff_pose(), true)
	var tc: Node = world.tether_controller
	check(await miss_off_the_cliff(spider), "hanging")
	check(await wait_settled(spider, 540), "at rest")
	var t: RefCounted = spider.tether
	var rest0: float = t.rest_length
	var y0: float = spider.global_position.y
	tc.reel_override = -1.0
	await physics_frames(30)
	check_near(t.rest_length - rest0, 0.75, 0.03, "lowering for 0.5 s lets out 0.75 WU (1.5 WU/s)")
	tc.reel_override = -0.5
	await physics_frames(30)
	check_near(t.rest_length - rest0, 1.125, 0.04, "half a stick lowers at half the rate")
	tc.reel_override = 0.0
	await physics_frames(60)
	check(y0 - spider.global_position.y > 1.0, "the spider went down with the line: %f WU" % (y0 - spider.global_position.y))
	var rest1: float = t.rest_length
	tc.reel_override = 1.0
	await physics_frames(2)
	check_eq(spider.state, spider.State.REELING, "reeling in is REELING")
	await physics_frames(28)
	check_near(rest1 - t.rest_length, 0.75, 0.04, "reeling for 0.5 s takes in 0.75 WU")
	tc.reel_override = 0.0
	await physics_frames(2)
	check_eq(spider.state, spider.State.HANGING, "and back to HANGING when it stops")
	check(t.rest_length <= t.max_length and t.paid_length <= t.rest_length + 1e-4, "lengths stay bounded")


func test_reeling_up_under_the_lip_takes_hold_and_the_spider_climbs_on() -> void:
	var spider := await _start(cliff_pose(), true)
	var tc: Node = world.tether_controller
	var events := record_line_events(spider)
	spider.trace_tether = true
	check(await miss_off_the_cliff(spider), "hanging below the lip")
	tc.reel_override = 1.0
	var held := await wait_until(func() -> bool: return spider.state == spider.State.ATTACHED, 480)
	tc.reel_override = 0.0
	check(held, "reeling in brings it to the cap, which it takes hold of (%s)" % spider.get_state_name())
	check_eq(spider.support.surface_id, "cliff_cap", "the wooden cap, not the coating")
	check(events.has("completed"), "the line is completed")
	check_eq(spider.completed_lines.size(), 1, "and stays behind")
	var problems := PackedStringArray()
	for r: Dictionary in spider.tether_trace:
		problems.append_array(tick_problems(r, 35.0))
	check(problems.is_empty(), "every tick while reeling: no overlap, the line never pushes, no energy gain beyond the reel's work and the documented allowances: %s" % "; ".join(problems.slice(0, 3)))
	# The player climbs on as normal: holding forward walks round the lip onto the cap's top.
	world.controller.stick_override = Vector2(0.0, -1.0)
	var on_top := await wait_until(func() -> bool: return spider.support.surface_id == "cliff_cap" and spider.support.normal.y > 0.99 and spider.state == spider.State.ATTACHED, 240)
	world.controller.stick_override = null
	check(on_top, "holding forward climbs onto the top of the cap (normal %s)" % str(spider.support.normal))


func test_letting_go_needs_a_hold_and_an_accidental_double_press_does_nothing() -> void:
	var spider := await _start(cliff_pose(), true)
	var tc: Node = world.tether_controller
	var hud: CanvasLayer = world.jump_hud
	var events := record_line_events(spider)
	settings.release_hold = true
	# A press made before the miss (as if to cancel) and still held never lets go.
	tc.cancel_down()
	check(await miss_off_the_cliff(spider), "hanging")
	await physics_frames(40)
	check(spider.is_on_line(), "a press held from before the miss does nothing")
	tc.cancel_up()
	await physics_frames(2)
	# Two quick taps: an accidental double press.
	for i in 2:
		tc.cancel_down()
		await physics_frames(4)
		tc.cancel_up()
		await physics_frames(4)
	check(spider.is_on_line(), "two quick taps do not drop the spider")
	check(not events.has("released"), "no release")
	# A real hold lets go.
	tc.cancel_down()
	await physics_frames(20)
	await process_frames(2)
	check(tc.release_progress > 0.2 and tc.release_progress < 1.0, "holding shows progress: %f" % tc.release_progress)
	check("Letting go" in hud.line_cue_text(), "and the HUD says so: %s" % hud.line_cue_text())
	await physics_frames(25)
	check(events.has("released"), "held for %.1f s: it lets go" % tc.RELEASE_HOLD_SECONDS)
	check(not spider.tether.is_active(), "no line")
	tc.cancel_up()
	var down := await wait_until(func() -> bool: return spider.state == spider.State.ATTACHED, 180)
	check(down and spider.support.surface_id == "floor", "and falls to the floor (%s, %s)" % [spider.get_state_name(), spider.support.surface_id])


func test_without_the_hold_option_a_fresh_press_lets_go_but_not_one_inside_the_grace() -> void:
	var spider := await _start(cliff_pose(), true)
	var tc: Node = world.tether_controller
	settings.release_hold = false
	check(await miss_off_the_cliff(spider), "hanging")
	tc.cancel_down()
	await physics_frames(2)
	tc.cancel_up()
	await physics_frames(2)
	check(spider.is_on_line(), "a press right after the line took hold (inside %.1f s) does nothing" % tc.GRACE_SECONDS)
	await physics_frames(30)
	tc.cancel_down()
	await physics_frames(2)
	check(not spider.tether.is_active() and spider.state == spider.State.FALLING, "a fresh press after that lets go at once")
	tc.cancel_up()


func test_the_line_comes_loose_safely_when_its_anchor_goes_away() -> void:
	var spider := await _start(slab_pose(14.0), true)
	var hud: CanvasLayer = world.jump_hud
	var events := record_line_events(spider)
	check(await miss_off_the_slab(spider, 14.0), "hanging below the slab's edge")
	check_eq(spider.tether.anchor_surface_id, "arch_slab", "anchored to the slab")
	world.lab.set_piece_enabled("arch_slab", false)
	await physics_frames(2)
	await process_frames(2)
	check(events.has("lost:arch_slab"), "the line comes loose with its anchor's surface: %s" % str(events))
	check(not spider.tether.is_active(), "no line")
	check_eq(spider.state, spider.State.FALLING, "the spider falls, nothing else")
	check("came loose" in hud.toast_text(), "the HUD says why: %s" % hud.toast_text())
	var down := await wait_until(func() -> bool: return spider.state == spider.State.ATTACHED, 180)
	check(down and spider.support.surface_id == "floor", "and lands on the floor")
	check_eq(spider.tether_fallbacks, 0, "no debug fallback")


func test_a_line_across_an_obstacle_snags_and_reeling_reports_it_and_never_pulls_through() -> void:
	var spider := await _start(slab_pose(12.0), true)
	var tc: Node = world.tether_controller
	var hud: CanvasLayer = world.jump_hud
	spider.trace_tether = true
	check(await miss_off_the_slab(spider, 12.0), "hanging below the slab's edge")
	check(await wait_settled(spider, 600), "at rest")
	var p: Vector3 = spider.global_position
	# Something moves into the line between the spider and the edge: a coated plate.
	world.lab.add_fixture_piece("plate", "coated", Vector3(p.x - 0.6, p.y + 0.9, p.z - 0.6), Vector3(p.x + 0.6, p.y + 1.0, p.z + 0.6))
	await physics_frames(3)
	check(spider.tether.snagged, "the line is snagged: it would need a second bend")
	var rest0: float = spider.tether.rest_length
	tc.reel_override = 1.0
	await physics_frames(30)
	await process_frames(2)
	check_near(spider.tether.rest_length, rest0, 1e-4, "reeling does not shorten a snagged line")
	check(spider.global_position.y < p.y + 0.05, "nothing pulls the spider into the plate")
	check("second edge" in hud.line_cue_text(), "the HUD says why: %s" % hud.line_cue_text())
	tc.reel_override = -1.0
	await physics_frames(30)
	check(spider.tether.rest_length > rest0 + 0.6, "lowering still works")
	tc.reel_override = 0.0
	world.lab.set_piece_enabled("plate", false)
	await physics_frames(3)
	check(not spider.tether.snagged, "the plate gone, the line is clear again")
	var problems := PackedStringArray()
	for r: Dictionary in spider.tether_trace:
		if not bool(r.get("snagged", false)):
			problems.append_array(tick_problems(r, 35.0))
	check(problems.is_empty(), "no overlap, no push, no unexplained energy gain: %s" % "; ".join(problems.slice(0, 3)))


func test_a_reel_the_body_cannot_follow_stops_with_a_cue_and_gives_the_line_back() -> void:
	var spider := await _start(slab_pose(16.0), true)
	var tc: Node = world.tether_controller
	spider.trace_tether = true
	check(await miss_off_the_slab(spider, 16.0), "hanging below the slab's edge")
	check(await wait_settled(spider, 600), "at rest")
	var p: Vector3 = spider.global_position
	# A coated ceiling with a 0.3 WU square hole in it, on the line, 0.6 WU above the spider's back. The line passes
	# through the hole untouched; the 0.6 WU body cannot follow it through. (An earlier fixture, a plate over half the
	# body's footprint, only blocked the body when the swing happened to have come to rest on the right side of it:
	# a sphere pushed up against the edge of a plate slides out from under it, which is right. The hole cannot be
	# slid out of.)
	var pivot: Vector3 = spider.tether.pivot()
	var y_ceiling := p.y + 0.65
	var hole: Vector3 = p.lerp(pivot, (y_ceiling - p.y) / (pivot.y - p.y))
	var lo_y := y_ceiling - 0.05
	var hi_y := y_ceiling + 0.05
	var half := 0.15
	var reach := 0.9
	world.lab.add_fixture_piece("hole_w", "coated", Vector3(hole.x - half - reach, lo_y, hole.z - reach), Vector3(hole.x - half, hi_y, hole.z + reach))
	world.lab.add_fixture_piece("hole_e", "coated", Vector3(hole.x + half, lo_y, hole.z - reach), Vector3(hole.x + half + reach, hi_y, hole.z + reach))
	world.lab.add_fixture_piece("hole_n", "coated", Vector3(hole.x - half, lo_y, hole.z - reach), Vector3(hole.x + half, hi_y, hole.z - half))
	world.lab.add_fixture_piece("hole_s", "coated", Vector3(hole.x - half, lo_y, hole.z + half), Vector3(hole.x + half, hi_y, hole.z + reach))
	await physics_frames(3)
	check(not spider.tether.snagged, "the ceiling is round the line, not across it: the line passes the hole")
	var events := record_line_events(spider)
	tc.reel_override = 1.0
	var blocked := await wait_until(func() -> bool: return spider.tether.block_reason == "blocked", 120)
	check(blocked, "reeling stops: the body cannot follow the line in")
	check(events.has("blocked:blocked"), "and says so")
	await physics_frames(10)
	var tr: Array = spider.tether_trace
	var last: Dictionary = tr[tr.size() - 1]
	check(float(last["path"]) <= float(last["rest"]) + 1e-3 and float(last["rest"]) - float(last["path"]) < 0.05, "the line gave back what it could not take in: no stored tension")
	tc.reel_override = 0.0
	await physics_frames(2)
	check_eq(spider.tether.block_reason, "", "letting go of reel clears the stop, so the next reel tries again")
	var problems := PackedStringArray()
	for r: Dictionary in tr:
		problems.append_array(tick_problems(r, 35.0))
	check(problems.is_empty(), "never pulled through the plate, no unexplained energy gain: %s" % "; ".join(problems.slice(0, 3)))


func test_completed_lines_fade_and_no_more_than_six_are_kept() -> void:
	var spider := await _start(floor_pose(-28.0, 9.0, -90.0), true)
	var silk: Node3D = world.silk_lines
	for i in 8:
		var plan: RefCounted = spider.plan_jump(top_target(spider.global_position.x + 2.0, 9.0))
		check(spider.begin_prepare() and spider.commit_jump(plan), "leap %d" % i)
		await wait_until(func() -> bool: return spider.state == spider.State.ATTACHED, 90)
		await physics_frames(2)
	check_eq(spider.completed_lines.size(), spider.MAX_COMPLETED_LINES, "no more than %d lines are kept" % spider.MAX_COMPLETED_LINES)
	await process_frames(2)
	check_eq(silk.completed_alphas.size(), spider.MAX_COMPLETED_LINES, "all drawn")
	check(silk.completed_alphas[spider.MAX_COMPLETED_LINES - 1] > 0.85, "the newest is fully drawn")
	var newest: Dictionary = spider.completed_lines[spider.completed_lines.size() - 1]
	var left: float = float(newest["life"]) - float(newest["age"])
	await physics_frames(int((left - 1.0) * 60.0))
	await process_frames(2)
	var alpha: float = silk.completed_alphas[silk.completed_alphas.size() - 1] if not silk.completed_alphas.is_empty() else 0.0
	check(alpha > 0.2 and alpha < 0.6, "a second before it goes it is fading: alpha %f" % alpha)
	await physics_frames(75)
	await process_frames(2)
	check_eq(spider.completed_lines.size(), 0, "then every line is removed")
	check(silk.completed_alphas.is_empty(), "and nothing is drawn")


func test_the_debug_fallback_is_labelled_and_is_not_silk_breaking() -> void:
	var spider := await _start(cliff_pose(), true)
	var hud: CanvasLayer = world.jump_hud
	var events := record_line_events(spider)
	var safe: Vector3 = spider.global_position
	check(await miss_off_the_cliff(spider), "hanging")
	spider.debug_force_tether_fallback("forced by the test")
	await physics_frames(2)
	await process_frames(2)
	check(events.has("fallback:forced by the test"), "a fallback event with its reason")
	check(not events.has("released") and not events.has("lost"), "not reported as letting go or losing the anchor")
	check("debug" in hud.toast_text() and "not silk breaking" in hud.toast_text(), "the HUD labels it as a debug fallback: %s" % hud.toast_text())
	check_eq(spider.tether_fallbacks, 1, "counted")
	check(not spider.tether.is_active(), "the line is dropped")
	var back := await settle(spider)
	check(back and spider.global_position.distance_to(safe) < 0.05, "and the spider is back at its last supported position")


func test_the_line_has_its_own_prompts_distinct_from_cancelling_an_aim() -> void:
	var spider := await _start(cliff_pose(), true)
	var jc: Node = world.jump_controller
	var hud: CanvasLayer = world.jump_hud
	jc.aim_override = top_target(27.3, -7.0)
	jc.press()
	await physics_frames(14)
	await process_frames(2)
	check("cancel the jump" in hud.hint_text(), "aiming: Q cancels the jump (%s)" % hud.hint_text())
	check(not hud.line_panel_visible(), "no line prompts while aiming")
	jc.release()
	check(await wait_until(func() -> bool: return spider.state == spider.State.HANGING, 150), "missed and hanging")
	await process_frames(2)
	check(hud.line_panel_visible(), "on the line: the line's prompts")
	var text: String = hud.line_hint_text()
	check("reel in" in text and "lower" in text and "let go" in text, "reel in, lower, let go: %s" % text)
	check("hold Q" in text, "letting go needs a hold by default")
	check(not ("cancel" in text), "and nothing about cancelling")
	check(not hud.reticle_visible(), "no aim reticle")
	check("Caught" in hud.toast_text(), "the catch is announced: %s" % hud.toast_text())


func test_f3_and_f4_show_the_line_and_its_constraint() -> void:
	var spider := await _start(cliff_pose(), true)
	check(await miss_off_the_cliff(spider), "hanging")
	await physics_frames(30)
	var lines := DebugOverlay.describe_line(spider)
	var text := "\n".join(lines)
	check("anchor cliff_cap" in text and "paid" in text and "rest" in text and "taut yes" in text and "bend (" in text, "F3 shows anchor, paid and rest length, taut and the bend:\n%s" % text)
	var view: Node3D = world.tether_debug
	view.refresh()
	check(view.showing_line and view.showing_bend, "F4 draws the line and its bend point")
	check_near(view.limit_radius, spider.tether.effective_length(), 1e-6, "and the circle the body may not leave")
	var silk: Node3D = world.silk_lines
	silk.refresh()
	check(silk.shown_points.size() >= 3, "the line itself is drawn, anchor to spinnerets")
	check(silk.shown_points[0].distance_to(spider.tether.anchor_point) < 1e-4, "from the anchor")


func test_a_glancing_contact_locks_the_line_and_it_catches() -> void:
	var spider := await _start(cliff_pose(-8.5))
	var events := record_line_events(spider)
	var plan: RefCounted = spider.plan_jump(top_target(27.3, -7.0))
	check(plan.is_valid(), "aimed at the practice perch")
	world.lab.drop_resets = false
	check(spider.begin_prepare() and spider.commit_jump(plan), "committed")
	# A coated plate swings into the path after the launch: the first contact cannot hold the spider.
	var mid: Vector3 = plan.path[plan.path.size() / 2]
	world.lab.add_fixture_piece("late_plate", "coated", mid + Vector3(0.35, -1.0, -1.0), mid + Vector3(0.45, 1.0, 1.0))
	var hung := await wait_until(func() -> bool: return spider.state == spider.State.HANGING, 150)
	check(str(spider.last_jump["outcome"]) in ["ineligible", "edge", "glancing"], "the flight ended on the plate: %s" % str(spider.last_jump["outcome"]))
	check(events.has("locked"), "which locked the line")
	check(hung, "and the line caught the fall (%s)" % spider.get_state_name())


func test_a_resting_spider_wakes_when_lowered_and_ignores_a_surface_that_goes_away_elsewhere() -> void:
	var spider := await _start(cliff_pose(), true)
	var tc: Node = world.tether_controller
	check(await miss_off_the_cliff(spider), "hanging")
	check(await wait_settled(spider, 540) and spider.is_resting(), "at rest, held")
	var rest0: float = spider.tether.rest_length
	tc.reel_override = -1.0
	await physics_frames(3)
	check(not spider.is_resting(), "lowering wakes it")
	await physics_frames(27)
	tc.reel_override = 0.0
	check_near(spider.tether.rest_length - rest0, 0.75, 0.06, "and it lets line out at the species rate")
	check(await wait_settled(spider, 600) and spider.is_resting(), "then comes to rest again, held at its new length")
	# A surface far from a spider that hangs free, held by its line alone, is none of its business.
	world.lab.set_piece_enabled("ledge_3", false)
	await physics_frames(3)
	check(spider.is_resting(), "a surface going away somewhere else does not wake a spider the line alone holds")
	check_eq(spider.tether_fallbacks, 0, "no debug fallback")


func test_a_spider_resting_against_something_wakes_when_a_surface_goes_away() -> void:
	var spider := await _start(slab_pose(16.0), true)
	# A wall 0.01 WU off the hanging spider's side, in place before the miss, so it comes to rest touching it.
	world.lab.add_fixture_piece("side_wall", "wall", Vector3(16.31, 1.8, 3.0), Vector3(17.1, 3.2, 5.0))
	await physics_frames(2)
	check(await miss_off_the_slab(spider, 16.0), "hanging below the slab's edge")
	check(await wait_settled(spider, 600) and spider.is_resting(), "at rest, held")
	check(absf(spider.global_position.x - 16.0) < 0.02, "beside the wall, not pushed away by it: x %f" % spider.global_position.x)
	world.lab.set_piece_enabled("side_wall", false)
	await physics_frames(2)
	check(not spider.is_resting() and spider.state == spider.State.HANGING, "the wall going away wakes it: it never rests against something that has gone")
	check(await wait_settled(spider, 600) and spider.is_resting(), "and it settles again, held")
	world.lab.set_piece_enabled("side_wall", true)
	await physics_frames(3)
	check(spider.is_resting(), "a surface coming back does not wake it")
	check_eq(spider.tether_fallbacks, 0, "no debug fallback")


func test_the_keyboard_lowers_reels_and_lets_go_through_the_real_actions() -> void:
	var spider := await _start(cliff_pose(), true)
	var events := record_line_events(spider)
	settings.release_hold = true
	check(await miss_off_the_cliff(spider), "hanging")
	await physics_frames(40)
	var t: RefCounted = spider.tether
	var rest0: float = t.rest_length
	# A key goes through the input pipeline, which applies it a tick or two late (the line input is read one tick
	# before the motor uses it, and a key between two physics ticks of one frame waits for the next frame), so the
	# rate is measured over a second: 1.5 WU, give or take four ticks of 0.025 WU.
	_key(KEY_S, true)
	await physics_frames(2)
	check(Input.is_action_pressed("lower"), "the S key is the lower action")
	await physics_frames(58)
	_key(KEY_S, false)
	await physics_frames(4)
	check_near(t.rest_length - rest0, 1.5, 0.1, "holding S for a second lets out 1.5 WU (1.5 WU/s)")
	var rest1: float = t.rest_length
	_key(KEY_W, true)
	await physics_frames(2)
	check(Input.is_action_pressed("reel"), "the W key is the reel action")
	await physics_frames(58)
	_key(KEY_W, false)
	await physics_frames(4)
	check_near(rest1 - t.rest_length, 1.5, 0.1, "holding W for a second takes in 1.5 WU")
	check(spider.is_on_line(), "still on the line, not yet at the lip")
	# Q: a quick double press does nothing, a hold lets go.
	for i in 2:
		_key(KEY_Q, true)
		await physics_frames(5)
		_key(KEY_Q, false)
		await physics_frames(5)
	check(spider.is_on_line() and not events.has("released"), "two quick presses of Q do not drop the spider")
	_key(KEY_Q, true)
	await physics_frames(55)
	check(events.has("released") and not spider.tether.is_active(), "holding Q for %.1f s lets go" % world.tether_controller.RELEASE_HOLD_SECONDS)
	_key(KEY_Q, false)


func test_the_controller_lowers_reels_and_lets_go_through_the_real_actions() -> void:
	var spider := await _start(cliff_pose(), true)
	var events := record_line_events(spider)
	settings.release_hold = true
	check(await miss_off_the_cliff(spider), "hanging")
	await physics_frames(40)
	var t: RefCounted = spider.tether
	var rest0: float = t.rest_length
	_axis(JOY_AXIS_LEFT_Y, 1.0)
	await physics_frames(2)
	check(Input.is_action_pressed("lower"), "the left stick pushed down is the lower action")
	await physics_frames(58)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await physics_frames(4)
	check_near(t.rest_length - rest0, 1.5, 0.1, "holding the stick down for a second lets out 1.5 WU (1.5 WU/s)")
	var rest1: float = t.rest_length
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await physics_frames(2)
	check(Input.is_action_pressed("reel"), "the left stick pushed up is the reel action")
	await physics_frames(58)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await physics_frames(4)
	check_near(rest1 - t.rest_length, 1.5, 0.1, "holding it up for a second takes in 1.5 WU")
	check(spider.is_on_line(), "still on the line, not yet at the lip")
	_button(JOY_BUTTON_B, true)
	await physics_frames(5)
	_button(JOY_BUTTON_B, false)
	await physics_frames(5)
	check(spider.is_on_line() and not events.has("released"), "a tap of the east button does not drop the spider")
	_button(JOY_BUTTON_B, true)
	await physics_frames(55)
	check(events.has("released") and not spider.tether.is_active(), "holding the east button lets go")
	_button(JOY_BUTTON_B, false)


func test_a_player_can_miss_on_purpose_recover_and_try_again() -> void:
	# Spec 26 T04's definition of done, through the real jump and line controllers: aim at the practice perch and
	# let it drop away, hang, reel back up, climb onto the cap, wait for the perch to come back and do it again.
	var spider := await _start(cliff_pose(), true)
	var jc: Node = world.jump_controller
	var tc: Node = world.tether_controller
	var events := record_line_events(spider)
	for attempt in 2:
		await settle(spider)
		jc.aim_override = top_target(27.3, -7.0)
		jc.press()
		await physics_frames(14)
		await process_frames(2)
		check(jc.is_aiming() and jc.plan.is_valid() and jc.plan.target_surface_id == "drop_perch", "attempt %d: aiming at the practice perch" % (attempt + 1))
		jc.release()
		check(await wait_until(func() -> bool: return spider.state == spider.State.HANGING, 150), "attempt %d: the perch dropped away and the line caught the miss" % (attempt + 1))
		tc.reel_override = 1.0
		var back := await wait_until(func() -> bool: return spider.state == spider.State.ATTACHED, 600)
		tc.reel_override = 0.0
		check(back and spider.support.surface_id == "cliff_cap", "attempt %d: reeling in brought it back to the cap (%s on %s)" % [attempt + 1, spider.get_state_name(), spider.support.surface_id])
		world.controller.stick_override = Vector2(0.0, -1.0)
		var on_top := await wait_until(func() -> bool: return spider.support.normal.y > 0.99 and spider.state == spider.State.ATTACHED, 300)
		world.controller.stick_override = null
		check(on_top, "attempt %d: and it climbed on top again" % (attempt + 1))
		check(await wait_until(func() -> bool: return world.lab.is_piece_enabled("drop_perch"), 600), "attempt %d: the practice perch comes back" % (attempt + 1))
	check_eq(events.filter(func(e: String) -> bool: return e == "caught").size(), 2, "caught twice")
	check_eq(events.filter(func(e: String) -> bool: return e == "completed").size(), 2, "recovered twice")
	check(not events.has("released") and not events.has("lost"), "never let go or lost")
	check_eq(spider.tether_fallbacks, 0, "no debug fallback")


func test_a_plate_over_part_of_the_body_lets_it_slide_out_and_its_energy_is_still_accounted_for() -> void:
	# What the blocked-reel test's plate used to be. It covers only the far 0.15 to 0.75 WU of the body's footprint,
	# so a sphere pulled up against its edge is pushed out from under it: it slides past and takes hold of the slab
	# (or, if the swing rested elsewhere, is stopped by it). Either is right. What this test holds fixed: nothing
	# overlaps, no length leaves its bounds, the line gains no unexplained energy, and the one source of lift that is
	# not the reel's, the physics engine's collision recovery along the plate's edge, stays within 0.002 WU a tick
	# (0.02 mm at 1 WU = 1 cm = 10 mm; it was 0.000125 WU, 0.00125 mm, a tick when this was measured), in no tick adds
	# more energy than that, and is fully accounted for.
	var spider := await _start(slab_pose(16.0), true)
	var tc: Node = world.tether_controller
	spider.trace_tether = true
	check(await miss_off_the_slab(spider, 16.0), "hanging below the slab's edge")
	check(await wait_settled(spider, 600), "at rest")
	var p: Vector3 = spider.global_position
	var c := p + Vector3(0.0, 0.45, 0.45)
	world.lab.add_fixture_piece("lid", "coated", c - Vector3(0.6, 0.05, 0.3), c + Vector3(0.6, 0.05, 0.3))
	await physics_frames(3)
	tc.reel_override = 1.0
	var done := await wait_until(func() -> bool: return spider.tether.block_reason == "blocked" or spider.state == spider.State.ATTACHED, 300)
	tc.reel_override = 0.0
	await physics_frames(10)
	check(done, "the reel ends in a stop or a hold (%s)" % spider.get_state_name())
	var problems := PackedStringArray()
	var lift_ticks := 0
	var worst_lift := 0.0
	for r: Dictionary in spider.tether_trace:
		problems.append_array(tick_problems(r, 35.0))
		if float(r.get("contact_lift", 0.0)) > 0.0:
			lift_ticks += 1
			worst_lift = maxf(worst_lift, float(r["contact_lift"]) / 35.0)
	check(problems.is_empty(), "no overlap, no push, no energy beyond the reel's work and the engine's contact recovery (%d ticks with some, at most %f WU = %f mm): %s" % [lift_ticks, worst_lift, worst_lift * WU_TO_MM, "; ".join(problems.slice(0, 3))])
	check_eq(spider.tether_fallbacks, 0, "no debug fallback")
