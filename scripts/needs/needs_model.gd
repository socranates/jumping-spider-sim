extends RefCounted
## NeedsModel (spec 11, 19.3, 21.3 NeedState): the spider's reserves, and the only place they change. P0 simulates ENERGY and REST
## and nothing else (hydration, stress and condition are named placeholders in the record, not simulated). It owns the numbers and
## the rule that they only change through approved calls: time passing (advance) and food (grant_energy). It never reads the world,
## never decides that anything is eaten, and does not know what a fly is: the feeding controller asks it to grant, and says which
## source the energy came from, so a ledger can show that no source ever gave more than it had.
##
## Energy (P0 sandbox rule, spec 11: "the first hunt should not be timed against starvation"). It drains very slowly with the
## passing of action time and stops at ENERGY_FLOOR: nothing happens at the floor, nothing is lost, and nothing stops working. The
## drain is integrated over elapsed action time in steps of UPDATE_PERIOD_S (spec 20: needs update at 1 to 2 Hz), so the same
## total time drains the same energy at 30, 60 or 144 frames a second and a stall cannot drain more than a capped step.
## Life mode (LIFE_DESIGN.md round 1; the windowsill, where the life clock runs): energy no longer drains with action seconds and has
## no floor. It drains with the game hours the life clock reports (add_hours), faster awake than asleep, and it can run out: the hours
## spent at zero are counted (starving_hours). Nothing else follows from them yet; death is a later round. The hours are applied at the
## same 2 Hz update as before, so a checkpoint taken between updates keeps them (hour_accumulator) and loads to the same energy.
## LIFE round 5: the hours at zero since the spider last ate (starving_streak_h) are what can kill it in the main life's Standard rules
## (the habitat loop decides that, after clear warnings). Gentle rules (Easy and free play, MODES-01) are forgiving: the reserve drains at
## GENTLE_DRAIN of the rate and never falls below GENTLE_FLOOR, so a gentle spider is hungry at worst, never starving.
## Rest is a second reserve with no consequence in P0: it wears down while the spider is active and builds back while it keeps
## still. It is here so that the retreat (T08) has something to restore; nothing reads it for a decision yet.

signal energy_changed(old_value: float, new_value: float)

const ENERGY_MAX := 1.0
const ENERGY_START := 0.55
## 0.0006 a second: a full reserve would last about 28 minutes, and the start of 0.55 reaches the floor after about 10.
const ENERGY_DRAIN_PER_S := 0.0006
const ENERGY_FLOOR := 0.20
const REST_MAX := 1.0
const REST_START := 1.0
const REST_DRAIN_PER_S := 0.0012
const REST_RECOVER_PER_S := 0.004
## Spec 20: needs and zones update at 1 to 2 Hz, integrating the action time that actually passed.
const UPDATE_PERIOD_S := 0.5
## One call may account for at most this much time (spec 20, time safety: never integrate an arbitrarily large step after a stall).
const MAX_STEP_S := 0.25
## "Full" for the purposes of a hint on the screen: feeding is never refused for it (see the feeding controller).
const FULL_AT := 0.98
## Life mode: a full reserve lasts about three game days without food (about 12 hours awake and 12 asleep each), and one fly (0.35)
## feeds the spider for about a day. A real Phidippus goes much longer without food (adult female P. johnsoni were kept 25 to 31 days
## unfed); the game compresses time on purpose (LIFE_DESIGN.md).
const LIFE_DRAIN_AWAKE_PER_H := 0.021
const LIFE_DRAIN_ASLEEP_PER_H := 0.007
## Gentle rules (round 5).
const GENTLE_DRAIN := 0.5
const GENTLE_FLOOR := 0.1
const STAGE_ID := "p0_prototype"

var energy: float = ENERGY_START
var rest: float = REST_START
## Total action time accounted for, seconds.
var elapsed_s: float = 0.0
## Everything ever granted, and by which source: no source may give more than it had.
var granted_total: float = 0.0
var granted_by_source: Dictionary = {}
var grants_made: int = 0
var grants_refused: int = 0

var _acc_active: float = 0.0
var _acc_still: float = 0.0
## Life mode (see above).
var life_mode: bool = false
var starving_hours: float = 0.0
## Hours at zero since the last food (reset by any grant).
var starving_streak_h: float = 0.0
## Gentle rules (set by the world from its life's rules; not part of the record).
var gentle: bool = false
var _acc_hours_awake: float = 0.0
var _acc_hours_asleep: float = 0.0


## Changes the numbers for a fixture. Keys: energy, rest. Values outside [0, 1] or not finite are ignored.
func configure(values: Dictionary) -> void:
	if values.has("energy") and _unit(values["energy"]):
		energy = float(values["energy"])
	if values.has("rest") and _unit(values["rest"]):
		rest = float(values["rest"])


## Lets `dt` seconds of action time pass. `active` is whether the spider spent them moving (walking, leaping, hanging) rather
## than keeping still. Non-finite or non-positive time is ignored; a long step counts as at most MAX_STEP_S.
func advance(dt: float, active: bool) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	dt = minf(dt, MAX_STEP_S)
	elapsed_s += dt
	if active:
		_acc_active += dt
	else:
		_acc_still += dt
	var total := _acc_active + _acc_still
	while total >= UPDATE_PERIOD_S - 1e-9:
		_apply(UPDATE_PERIOD_S, _acc_active / total)
		var keep := maxf(0.0, (total - UPDATE_PERIOD_S) / total)  # T09: never a tiny negative remainder (it made the record unloadable)
		_acc_active *= keep
		_acc_still *= keep
		total -= UPDATE_PERIOD_S


## Life mode: `hours` of game time passed, asleep or awake. They are used up at the next 2 Hz update.
func add_hours(hours: float, asleep: bool) -> void:
	if not life_mode or not is_finite(hours) or hours <= 0.0:
		return
	if asleep:
		_acc_hours_asleep += hours
	else:
		_acc_hours_awake += hours


## Whether the reserve has run out (life mode).
func is_starving() -> bool:
	return life_mode and energy <= 0.0


func _apply(period: float, active_share: float) -> void:
	var before := energy
	if life_mode:
		var need := _acc_hours_awake * LIFE_DRAIN_AWAKE_PER_H + _acc_hours_asleep * LIFE_DRAIN_ASLEEP_PER_H
		var hours := _acc_hours_awake + _acc_hours_asleep
		_acc_hours_awake = 0.0
		_acc_hours_asleep = 0.0
		if gentle:
			need *= GENTLE_DRAIN
		if need > 0.0:
			var floor_left := maxf(energy - GENTLE_FLOOR, 0.0) if gentle else energy
			var used := minf(floor_left, need)
			energy -= used
			if need > used and not gentle:
				var starved := hours * (need - used) / need
				starving_hours += starved
				starving_streak_h += starved
	elif energy > ENERGY_FLOOR:
		energy = maxf(ENERGY_FLOOR, energy - ENERGY_DRAIN_PER_S * period)
	rest = clampf(rest + (REST_RECOVER_PER_S * (1.0 - active_share) - REST_DRAIN_PER_S * active_share) * period, 0.0, REST_MAX)
	if energy != before:
		energy_changed.emit(before, energy)


## Adds food energy from `source_id` (a prey id). Returns what was actually added: nothing for an amount that is not a positive finite
## number or a source with no name, and never more than the room left below ENERGY_MAX. The caller is the one that decides that
## the energy is deserved (the feeding controller, only while a held prey is being eaten); this only keeps the books.
func grant_energy(amount: float, source_id: String) -> float:
	if source_id == "" or not is_finite(amount) or amount <= 0.0:
		grants_refused += 1
		return 0.0
	var added := minf(amount, room())
	if added <= 0.0:
		return 0.0
	var before := energy
	energy = minf(ENERGY_MAX, energy + added)
	added = energy - before
	granted_total += added
	granted_by_source[source_id] = float(granted_by_source.get(source_id, 0.0)) + added
	grants_made += 1
	starving_streak_h = 0.0
	energy_changed.emit(before, energy)
	return added


## Energy that could still be added.
func room() -> float:
	return maxf(0.0, ENERGY_MAX - energy)


## A valid retreat interaction restores rest; it never grants food energy.
func restore_rest(amount: float) -> void:
	if is_finite(amount) and amount > 0.0:
		rest = minf(REST_MAX, rest + amount)


func is_full() -> bool:
	return energy >= FULL_AT


## What one source has given so far.
func granted_from(source_id: String) -> float:
	return float(granted_by_source.get(source_id, 0.0))


## The NeedState record (spec 21.3): the reserves in [0, 1], the update accumulator and the stage. Only the enabled needs are
## simulated; the others are null, named so that the record has the shape the save will need.
func to_dict() -> Dictionary:
	return {
		"energy": energy, "rest": rest, "hydration": null, "stress": null, "condition": null,
		"enabled": ["energy", "rest"], "update_accumulator": [_acc_active, _acc_still], "stage_id": STAGE_ID,
		"elapsed_s": elapsed_s, "granted_total": granted_total, "granted_by_source": granted_by_source.duplicate(),
		"life_mode": life_mode, "starving_hours": starving_hours, "hour_accumulator": [_acc_hours_awake, _acc_hours_asleep],
		"starving_streak_h": starving_streak_h,
	}


## Restores a record made by to_dict. False, and nothing changed, for anything that is not one: a missing or non-finite number, a
## reserve outside [0, 1], an accumulator that is not two non-negative numbers, a grant ledger that does not add up.
func load_dict(d: Dictionary) -> bool:
	for key: String in ["energy", "rest", "elapsed_s", "granted_total"]:
		if not d.has(key) or not (typeof(d[key]) == TYPE_FLOAT or typeof(d[key]) == TYPE_INT) or not is_finite(float(d[key])):
			return false
	if not _unit(d["energy"]) or not _unit(d["rest"]) or float(d["elapsed_s"]) < 0.0 or float(d["granted_total"]) < 0.0:
		return false
	var acc: Variant = d.get("update_accumulator")
	if typeof(acc) != TYPE_ARRAY or (acc as Array).size() != 2:
		return false
	for v: Variant in acc:
		if (typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT) or not is_finite(float(v)) or float(v) < 0.0:
			return false
	var by_source: Variant = d.get("granted_by_source")
	if typeof(by_source) != TYPE_DICTIONARY:
		return false
	var sum := 0.0
	for k: Variant in (by_source as Dictionary):
		var v: Variant = (by_source as Dictionary)[k]
		if typeof(k) != TYPE_STRING or (typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT) or not is_finite(float(v)) or float(v) < 0.0:
			return false
		sum += float(v)
	if absf(sum - float(d["granted_total"])) > 1e-6:
		return false
	# Life mode (optional in older records: none of them had it).
	var lm: Variant = d.get("life_mode", false)
	var sh: Variant = d.get("starving_hours", 0.0)
	var ha: Variant = d.get("hour_accumulator", [0.0, 0.0])
	var streak: Variant = d.get("starving_streak_h", 0.0)
	if (typeof(streak) != TYPE_FLOAT and typeof(streak) != TYPE_INT) or not is_finite(float(streak)) or float(streak) < 0.0:
		return false
	if typeof(lm) != TYPE_BOOL or (typeof(sh) != TYPE_FLOAT and typeof(sh) != TYPE_INT) or not is_finite(float(sh)) or float(sh) < 0.0:
		return false
	if typeof(ha) != TYPE_ARRAY or (ha as Array).size() != 2:
		return false
	for v: Variant in ha:
		if (typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT) or not is_finite(float(v)) or float(v) < 0.0:
			return false
	life_mode = bool(lm)
	starving_hours = float(sh)
	starving_streak_h = float(streak)
	_acc_hours_awake = float((ha as Array)[0])
	_acc_hours_asleep = float((ha as Array)[1])
	energy = float(d["energy"])
	rest = float(d["rest"])
	elapsed_s = float(d["elapsed_s"])
	granted_total = float(d["granted_total"])
	granted_by_source = (by_source as Dictionary).duplicate()
	_acc_active = float((acc as Array)[0])
	_acc_still = float((acc as Array)[1])
	return true


## Developer text for the F3 overlay.
func describe() -> String:
	if life_mode:
		return "Energy %.3f (life mode: %.3f a waking hour, %.3f asleep; %.1f h starving), rest %.3f; granted %.3f from %d source(s)" % [energy, LIFE_DRAIN_AWAKE_PER_H, LIFE_DRAIN_ASLEEP_PER_H, starving_hours, rest, granted_total, granted_by_source.size()]
	return "Energy %.3f (drain %.4f/s to a floor of %.2f), rest %.3f; granted %.3f from %d source(s)" % [energy, ENERGY_DRAIN_PER_S, ENERGY_FLOOR, rest, granted_total, granted_by_source.size()]


static func _unit(v: Variant) -> bool:
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v)) and float(v) >= 0.0 and float(v) <= 1.0
