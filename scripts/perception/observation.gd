extends RefCounted
## Observation (spec 21.3): one piece of sensed evidence, as the SensorSystem makes it and the memory keeps it.
## Observer, target (only when resolved), estimated position, modality, confidence in [0, 1], the tick it was
## observed at (an integer action tick), and a category. It is never refreshed from hidden truth: an observation is
## only ever made from what the observer could see at `observed_tick`, and a later one is a new record.
##
## Two modalities (spec 7):
##   PERIPHERAL  broad coverage, a coarse direction only, no position and no category beyond "movement". The target is
##               not resolved: the observer knows something moved that way, not what, and not how far.
##   INSPECTION  the forward cone: a position (to within the target's own size), a category that refines with
##               continuous exposure (movement, possible prey, fly-like prey: A-004), and the target once it is resolved.
## Words for the categories belong to the presentation (scripts/presentation/perception_text.gd), never here.

const PERIPHERAL := &"peripheral_motion"
const INSPECTION := &"forward_inspection"

const MOVEMENT := &"movement"
const POSSIBLE_PREY := &"possible_prey"
const FLY_LIKE_PREY := &"fly_like_prey"
## Refinement order: each is a finer guess than the one before it. No species is ever named (A-004).
const CATEGORIES: Array[StringName] = [MOVEMENT, POSSIBLE_PREY, FLY_LIKE_PREY]

var observer_id: String = ""
## The target's persistent id once the observer has resolved it (inspected it long enough), else "".
var target_id: String = ""
## Opaque id the sensor gives one thing it keeps sensing, so the memory can follow it. It is not the target's id.
var track_id: String = ""
## The estimate; meaningful only when has_position. A peripheral observation has none: only `direction`.
var estimated_position: Vector3 = Vector3.ZERO
var has_position: bool = false
## Unit direction from the observer to the thing, as sensed: exact enough to aim at for an inspection, quantised to a
## sector for a peripheral cue.
var direction: Vector3 = Vector3.FORWARD
var modality: StringName = PERIPHERAL
var confidence: float = 0.0
var observed_tick: int = 0
var category: StringName = MOVEMENT
## Estimated size of the thing, WU (an inspection only). The memory uses it to judge whether a place could hide it.
var size_wu: float = 0.0
## How large it looked, degrees of angle across.
var apparent_size_deg: float = 0.0
## How fast it was seen moving, WU/s (an inspection only). A lost contact's plausible region grows at least this fast (A-027).
var speed_wu_s: float = 0.0


static func rank(c: StringName) -> int:
	return CATEGORIES.find(c)


## Problems with the record, empty when it is fine: the invariants of spec 21.3 (no NaN or infinity, confidence in
## [0, 1], a known modality and category, a position only for an inspection).
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if observer_id == "":
		out.append("no observer")
	if track_id == "":
		out.append("no track")
	if not (modality == PERIPHERAL or modality == INSPECTION):
		out.append("unknown modality '%s'" % str(modality))
	if not CATEGORIES.has(category):
		out.append("unknown category '%s'" % str(category))
	if not is_finite(confidence) or confidence < 0.0 or confidence > 1.0:
		out.append("confidence %s is not in [0, 1]" % str(confidence))
	if observed_tick < 0:
		out.append("negative tick")
	if not direction.is_finite() or absf(direction.length() - 1.0) > 1e-3:
		out.append("direction is not a unit vector")
	if has_position and not estimated_position.is_finite():
		out.append("estimated position is not finite")
	if modality == PERIPHERAL and has_position:
		out.append("a peripheral observation carries no position")
	if modality == PERIPHERAL and (category != MOVEMENT or target_id != ""):
		out.append("a peripheral observation has no category beyond movement and no resolved target")
	if modality == INSPECTION and not has_position:
		out.append("an inspection carries a position")
	if not is_finite(speed_wu_s) or speed_wu_s < 0.0:
		out.append("speed is not a finite, non-negative number")
	return out


func is_valid() -> bool:
	return problems().is_empty()


func to_dict() -> Dictionary:
	return {
		"observer_id": observer_id, "target_id": target_id, "track_id": track_id,
		"estimated_position": estimated_position if has_position else null, "direction": direction,
		"modality": modality, "confidence": confidence, "observed_tick": observed_tick, "category": category,
	}
