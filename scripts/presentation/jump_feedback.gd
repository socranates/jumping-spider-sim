extends RefCounted
## What the player is told about a jump target (spec 6.3, 16): one place for the style of each plan
## kind and the words. Every kind has a shape AND a colour (never colour alone) and a text label:
##   reachable    solid ring              green    "Reachable"
##   obstructed   ring with a cross       amber    "Blocked"
##   unreachable  dashed ring             red      "Out of reach"
##   ineligible   dotted ring             violet   "Can't land there"
## There is no uncertainty band in P0: static jumps are deterministic, and the patch only ever promises
## what the solver found (A-005, A-008).

const PATTERNS := {"reachable": "solid", "obstructed": "cross", "unreachable": "dashed", "ineligible": "dotted"}
const COLORS := {
	"reachable": Color(0.25, 0.92, 0.38),
	"obstructed": Color(1.0, 0.72, 0.1),
	"unreachable": Color(1.0, 0.32, 0.28),
	"ineligible": Color(0.72, 0.45, 1.0),
	"none": Color(0.8, 0.8, 0.8),
}
const TITLES := {
	"reachable": "Reachable",
	"obstructed": "Blocked",
	"unreachable": "Out of reach",
	"ineligible": "Can't land there",
	"none": "No surface in view",
}
## Why, in a few words, by plan.reason.
const REASONS := {
	"ok": "",
	"no_target": "no surface in view",
	"ineligible_surface": "the spider cannot hold on there",
	"too_far": "too far or too high",
	"no_launch": "no way to leave this surface toward there",
	"no_arrival": "it can't land from that angle",
	"no_durations": "out of range",
	"no_room": "no room to land",
	"path_blocked": "something is in the way",
	"graze": "it would only graze the surface",
	"hop_blocked": "something is in the way",
	"no_ground": "nothing to land on ahead",
}


static func pattern_for(kind_name: String) -> String:
	return str(PATTERNS.get(kind_name, ""))


static func color_for(kind_name: String) -> Color:
	return COLORS.get(kind_name, COLORS["none"])


static func reason_text(plan: RefCounted) -> String:
	return str(REASONS.get(plan.reason, plan.reason))


## The two lines shown at the reticle while aiming: {"title", "hint"}. `toggle` is the accessibility mode.
static func describe(plan: RefCounted, toggle: bool) -> Dictionary:
	if plan == null:
		return {"title": TITLES["none"], "hint": "release to cancel" if not toggle else "Q cancels"}
	var kind: String = plan.kind_name()
	var go := "press jump again to leap" if toggle else "release to leap"
	var stop := "Q cancels" if toggle else "release to cancel"
	var hint := go if plan.is_valid() else stop
	var title: String = TITLES.get(kind, kind)
	if not plan.is_valid() and kind != "none":
		var why := reason_text(plan)
		if why != "":
			title = "%s: %s" % [title, why]
	return {"title": title, "hint": hint}


## The safety line, before commit (spec 9.1: lack of a usable attachment must be clear before committing), by
## SpiderMotor.get_anchor_preview()["reason"]. A missing line never changes the jump itself (A-008).
const ANCHOR_TEXT := {
	"ok": "Safety line: anchored here",
	"no_silk": "No safety line: this surface won't hold silk",
	"too_long": "No safety line: this jump needs more line than you have",
	"no_support": "",
}
const ANCHOR_OK_COLOR := Color(0.92, 0.94, 0.98)
const ANCHOR_REFUSED_COLOR := Color(1.0, 0.72, 0.1)
## On the line (spec 17: reel, lower and let go are context prompts, distinct from cancelling an aim).
const LINE_TITLE := "On your line"
const LINE_TITLE_REELING := "On your line: reeling in"
const LINE_HINT_HOLD := "W / stick up: reel in    S / stick down: lower    hold Q / B: let go"
const LINE_HINT_PRESS := "W / stick up: reel in    S / stick down: lower    Q / B: let go"
const AIM_CANCEL_HINT := "Q / B: cancel the jump"
## When the line's anchor is out of sight behind the world from this camera (A-017). A line that bends over an edge is
## held beyond that edge, so the note says so.
const ANCHOR_HIDDEN_BEND := "Anchored out of sight, behind the edge your line passes over"
const ANCHOR_HIDDEN := "Anchored out of sight"
## Why reeling stopped (Tether.block_reason, and snagged), shown under the line prompt while it lasts.
const LINE_BLOCKED := {
	"blocked": "Can't reel in: something is in the way. Lower, or let go",
	"shortest": "Reeled in as far as it goes",
	"snagged": "The line is caught on a second edge and can't be reeled in. Lower, or let go",
}


static func anchor_text(reason: String) -> String:
	return str(ANCHOR_TEXT.get(reason, ""))


static func anchor_hidden_text(has_bend: bool) -> String:
	return ANCHOR_HIDDEN_BEND if has_bend else ANCHOR_HIDDEN


## The toast for a SpiderMotor.line_event, "" when it needs none. `after_miss` says whether the line had been
## locked by a miss, so an ordinary landing (which also completes a line) says nothing.
static func line_toast(kind: String, detail: String, after_miss: bool) -> String:
	match kind:
		"caught":
			return "Caught by your line"
		"completed":
			return "Holding on again. The line stays behind for a moment" if after_miss else ""
		"released":
			return "You let go of the line"
		"lost":
			return "Your line came loose: its anchor is gone"
		"blocked":
			return str(LINE_BLOCKED.get(detail, ""))
		"snagged":
			return str(LINE_BLOCKED["snagged"])
		"fallback":
			return "Line solver fallback (debug, not silk breaking): back at the last safe spot"
	return ""


## The toast for a feedback record kind (see JumpController): "" for kinds that need none.
static func toast(kind: String, plan: RefCounted) -> String:
	var why := reason_text(plan) if plan != null else ""
	match kind:
		"refused":
			return "Jump cancelled: %s" % (why if why != "" else "nothing to land on")
		"invalid_press":
			return "Can't jump there: %s. Q cancels." % (why if why != "" else "nothing to land on")
		"hop_refused":
			return "No hop: %s" % (why if why != "" else "nowhere to land")
		"cancelled":
			return "Jump cancelled"
		"out_of_bounds":
			return "Out of bounds: back to the last safe spot"
	return ""
