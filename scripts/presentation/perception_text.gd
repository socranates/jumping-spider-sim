extends RefCounted
## The words of the perception presentation (spec 17: "movement", "possible prey", "lost sight", never percentages). The
## words live here and nowhere in the sensor or the memory (spec 19.3: the SensorSystem owns evidence, not labels).

const Observation = preload("res://scripts/perception/observation.gd")

const LOST := "lost sight"
## The categories refine movement, then possible prey, then fly-like prey (A-004). No species is ever named.
const CATEGORY := {
	Observation.MOVEMENT: "movement",
	Observation.POSSIBLE_PREY: "possible prey",
	Observation.FLY_LIKE_PREY: "fly-like prey",
}
## The note that shows a toggled Focus is on and how to end it (A-026); in hold mode there is nothing to show, the button is the state.
const FOCUS_ON := "FOCUS ON"
const FOCUS_STOP := "press Focus again to stop"
const FOCUS_STOP_OR_CANCEL := "press Focus again, or Q / B, to stop"
## What the setting switches are called in the pause panel, and what the developer overlay calls the senses.
const SETTING_LAST_SEEN := "Show the last-seen mark"
const SETTING_GAZE := "Show where the spider looks"


## The words for a category ("movement" for anything unknown, the safest thing to say).
static func category(c: StringName) -> String:
	return str(CATEGORY.get(c, CATEGORY[Observation.MOVEMENT]))


## The words a contact's label carries: its category while it is being inspected, "lost sight" once it is lost.
static func label_for(c: RefCounted) -> String:
	if c == null:
		return ""
	if c.state == &"lost":
		return LOST
	return category(c.category)


## True when a string has a digit or a percent sign in it. The player-facing words never do; tests use this.
static func has_number(text: String) -> bool:
	for ch in text:
		if ch == "%" or (ch >= "0" and ch <= "9"):
			return true
	return false
