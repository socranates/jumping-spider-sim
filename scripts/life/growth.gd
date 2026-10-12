extends RefCounted
## Growth by moulting (LIFE_DESIGN.md round 3; LIFE-03: three moults from juvenile to adult in one life). A spider grows only by shedding
## its old exoskeleton. Here:
##   * after the spider has eaten enough since its last moult (READY_FOOD of energy granted) it is ready, and says so;
##   * resting in the retreat while ready starts the moult. It cannot be hurried or stopped: the hours pass quickly (MOULT_HOURS), as
##     a night's sleep does, and the old skin is left behind in the crack;
##   * afterwards the spider is a stage older and soft for SOFT_HOURS of game time: paler, and its jumps reach only SOFT_REACH as far;
##   * the fourth stage is the adult. LIFE-03 / MODES-01: one spider reaching adulthood finishes the main life.
## In Phidippus johnsoni, spiders stay in their nests about six days before a moult and two after (Jackson 1979, from an excerpt); real
## spiders also usually stop eating for a while before moulting. The game compresses both and does not stop the spider eating; the
## notebook says so. How long the new cuticle stays soft is a design assumption: no measurement was found (LIFE_DESIGN.md).
## The spider's body is drawn the same size at every stage for now (its physics never changes); the rig's growth is a later round.

const STAGES: Array[String] = ["young juvenile", "juvenile", "subadult", "adult"]
const ADULT := 3
const READY_FOOD := 0.9
const MOULT_HOURS := 12.0
const SOFT_HOURS := 10.0
const SOFT_REACH := 0.7

var stage: int = 0
## Energy eaten since the last moult (or since the start).
var fed_since_moult: float = 0.0
var ready: bool = false
## Game hours of the moult still to pass; 0 when not moulting.
var moulting_hours_left: float = 0.0
## Game hours until the new cuticle has hardened; 0 when hard.
var soft_hours_left: float = 0.0
## Where each old skin was left: positions in the habitat.
var exuviae: Array[Vector3] = []


func is_adult() -> bool:
	return stage >= ADULT


func is_moulting() -> bool:
	return moulting_hours_left > 0.0


func is_soft() -> bool:
	return soft_hours_left > 0.0


func stage_name() -> String:
	return STAGES[clampi(stage, 0, STAGES.size() - 1)]


## How far the jumps reach now, as a share of normal.
func reach_factor() -> float:
	return SOFT_REACH if is_soft() or is_moulting() else 1.0


## How soft the spider is, 1 just after the moult down to 0 when hardened.
func softness() -> float:
	return clampf(soft_hours_left / SOFT_HOURS, 0.0, 1.0) if not is_moulting() else 1.0


## Food eaten (energy actually granted). True when this makes the spider ready to moult.
func eat(energy: float) -> bool:
	if not is_finite(energy) or energy <= 0.0 or is_adult() or is_moulting():
		return false
	fed_since_moult += energy
	if not ready and fed_since_moult >= READY_FOOD:
		ready = true
		return true
	return false


## Starts the moult if the spider is ready. True when it started.
func begin_moult() -> bool:
	if not ready or is_moulting() or is_adult():
		return false
	moulting_hours_left = MOULT_HOURS
	return true


## Lets `hours` of game time pass. Returns "moulted" when the moult ended in them, "hardened" when the new skin set, else "".
func pass_hours(hours: float, at: Vector3) -> String:
	if not is_finite(hours) or hours <= 0.0:
		return ""
	if is_moulting():
		moulting_hours_left = maxf(0.0, moulting_hours_left - hours)
		if moulting_hours_left <= 0.0:
			stage = mini(stage + 1, ADULT)
			ready = false
			fed_since_moult = 0.0
			soft_hours_left = SOFT_HOURS
			exuviae.append(at)
			return "moulted"
		return ""
	if is_soft():
		soft_hours_left = maxf(0.0, soft_hours_left - hours)
		if soft_hours_left <= 0.0:
			return "hardened"
	return ""


func to_dict() -> Dictionary:
	var skins: Array = []
	for p in exuviae:
		skins.append([p.x, p.y, p.z])
	return {"stage": stage, "fed_since_moult": fed_since_moult, "ready": ready, "moulting_hours_left": moulting_hours_left,
		"soft_hours_left": soft_hours_left, "exuviae": skins}


func load_dict(d: Dictionary) -> bool:
	if not problems(d).is_empty():
		return false
	stage = int(d["stage"])
	fed_since_moult = float(d["fed_since_moult"])
	ready = bool(d["ready"])
	moulting_hours_left = float(d["moulting_hours_left"])
	soft_hours_left = float(d["soft_hours_left"])
	exuviae.clear()
	for p: Variant in d["exuviae"]:
		exuviae.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	return true


static func _num(v: Variant) -> bool:
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v))


static func problems(d: Variant) -> PackedStringArray:
	var e := PackedStringArray()
	if typeof(d) != TYPE_DICTIONARY:
		e.append("growth: not a record")
		return e
	var r: Dictionary = d
	var s: Variant = r.get("stage")
	if not _num(s) or float(s) != floorf(float(s)) or int(s) < 0 or int(s) > ADULT:
		e.append("growth: the stage is not 0 to %d" % ADULT)
	for k in ["fed_since_moult", "moulting_hours_left", "soft_hours_left"]:
		if not _num(r.get(k)) or float(r.get(k)) < 0.0:
			e.append("growth: '%s' is not a number from 0" % k)
	if typeof(r.get("ready")) != TYPE_BOOL:
		e.append("growth: 'ready' is not true or false")
	var skins: Variant = r.get("exuviae")
	if typeof(skins) != TYPE_ARRAY or (skins as Array).size() > ADULT:
		e.append("growth: the old skins are not a list of up to %d places" % ADULT)
	else:
		for p: Variant in skins:
			if typeof(p) != TYPE_ARRAY or (p as Array).size() != 3 or not (_num(p[0]) and _num(p[1]) and _num(p[2])):
				e.append("growth: an old skin's place is not three numbers")
				break
	return e
