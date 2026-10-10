extends "res://tests/test_case.gd"
## What the player is told: a shape, a colour and words for each kind of plan, and a reason for each refusal.

const JumpFeedback = preload("res://scripts/presentation/jump_feedback.gd")
const JumpPlan = preload("res://scripts/movement/jump_plan.gd")

const KINDS: Array[String] = ["reachable", "obstructed", "unreachable", "ineligible"]
const REASONS: Array[String] = ["ok", "no_target", "ineligible_surface", "too_far", "no_launch", "no_arrival", "no_durations", "no_room", "path_blocked", "graze", "hop_blocked", "no_ground"]


func _plan(kind: JumpPlan.Kind, reason: String) -> JumpPlan:
	var p := JumpPlan.new()
	p.kind = kind
	p.reason = reason
	return p


func test_each_kind_has_its_own_shape_colour_and_words() -> void:
	var shapes := {}
	var colors := {}
	var titles := {}
	for kind in KINDS:
		shapes[JumpFeedback.pattern_for(kind)] = true
		colors[JumpFeedback.color_for(kind).to_html()] = true
		titles[JumpFeedback.TITLES[kind]] = true
	check_eq(shapes.size(), 4, "four shapes")
	check_eq(colors.size(), 4, "four colours")
	check_eq(titles.size(), 4, "four labels")
	check_eq(JumpFeedback.pattern_for("reachable"), "solid", "reachable is a solid ring")
	check_eq(JumpFeedback.pattern_for("obstructed"), "cross", "obstructed is a ring with a cross")
	check_eq(JumpFeedback.pattern_for("unreachable"), "dashed", "unreachable is dashed")
	check_eq(JumpFeedback.pattern_for("ineligible"), "dotted", "ineligible is dotted")
	check_eq(JumpFeedback.pattern_for("none"), "", "no target has no patch")


func test_every_reason_the_solver_can_give_has_words() -> void:
	for reason in REASONS:
		check(reason == "ok" or JumpFeedback.REASONS.get(reason, "") != "", "reason '%s' has words" % reason)


func test_the_aim_label_says_what_a_release_does() -> void:
	var good := JumpFeedback.describe(_plan(JumpPlan.Kind.REACHABLE, "ok"), false)
	check_eq(good["title"], "Reachable", "title")
	check_eq(good["hint"], "release to leap", "hold mode hint")
	check_eq(JumpFeedback.describe(_plan(JumpPlan.Kind.REACHABLE, "ok"), true)["hint"], "press jump again to leap", "toggle mode hint")
	var bad := JumpFeedback.describe(_plan(JumpPlan.Kind.UNREACHABLE, "too_far"), false)
	check_eq(bad["title"], "Out of reach: too far or too high", "an unreachable target says why")
	check_eq(bad["hint"], "release to cancel", "and that a release cancels")
	check_eq(JumpFeedback.describe(_plan(JumpPlan.Kind.OBSTRUCTED, "path_blocked"), true)["hint"], "Q cancels", "toggle mode: Q cancels")
	check_eq(JumpFeedback.describe(_plan(JumpPlan.Kind.INELIGIBLE, "ineligible_surface"), false)["title"], "Can't land there: the spider cannot hold on there", "ineligible")
	check_eq(JumpFeedback.describe(null, false)["title"], "No surface in view", "nothing under the reticle")
	check_eq(JumpFeedback.describe(_plan(JumpPlan.Kind.NO_TARGET, "no_target"), false)["title"], "No surface in view", "no target")


func test_toasts_for_each_outcome() -> void:
	var far := _plan(JumpPlan.Kind.UNREACHABLE, "too_far")
	check_eq(JumpFeedback.toast("refused", far), "Jump cancelled: too far or too high", "a refused release")
	check_eq(JumpFeedback.toast("invalid_press", far), "Can't jump there: too far or too high. Q cancels.", "toggle mode refusal")
	check_eq(JumpFeedback.toast("hop_refused", _plan(JumpPlan.Kind.OBSTRUCTED, "hop_blocked")), "No hop: something is in the way", "a blocked hop")
	check_eq(JumpFeedback.toast("cancelled", null), "Jump cancelled", "a cancel")
	check_eq(JumpFeedback.toast("out_of_bounds", null), "Out of bounds: back to the last safe spot", "out of bounds")
	check_eq(JumpFeedback.toast("launched", far), "", "a launch needs no toast")
	check_eq(JumpFeedback.toast("nothing", null), "", "unknown kinds are silent")


func test_the_hidden_anchor_note_names_the_edge_only_when_the_line_bends_over_one() -> void:
	var over_an_edge := JumpFeedback.anchor_hidden_text(true)
	var plain := JumpFeedback.anchor_hidden_text(false)
	check("out of sight" in over_an_edge and "edge" in over_an_edge, "a bent line is anchored out of sight behind the edge it passes over: %s" % over_an_edge)
	check(plain == "Anchored out of sight" and not ("edge" in plain), "a straight one is just out of sight: %s" % plain)
	check(over_an_edge.length() < 70 and plain.length() < 70, "both fit on one line of the panel")
