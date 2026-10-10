extends RefCounted
## FlyMind: what a fly wants and why (spec 8.3, 19.3). A small utility selector over three goals, with explicit weights from the fly's
## profile (data/species/fly_like_prototype.json, "utility"):
##   rest  the base wish to stay, more when tired, on a sheltered perch or one with food on it, less with perceived threat;
##   move  restlessness (time at one place), a perch with more food or shelter than here, less the trip, being tired or threatened;
##   flee  worth exactly as much as there is perceived threat, plus how sheltered the perch is, how far it gets the fly from where it last
##         saw the thing, less the trip.
## Inputs are the fly's own: its awareness (from FlySenses) mapped to a threat in [0, 1], its fatigue and restlessness, and its perches.
## The thing's position is only ever the place the fly last SAW it. Decisions run at decision_hz, staggered by serial, and are held by
## hysteresis (the present goal counts `hysteresis` more) and a minimum commitment (a goal is kept `min_commit_s` unless the danger is
## credible: a startle, or a threat at or above `interrupt_threat`). A credible danger also interrupts a flight.
## Reactions wait out a delay (A-028, tunable data): a startle, the fly's reflex to a lot of motion near it, uses the delay of its
## present vigilance (alert is quickest, grooming slowest); a deliberate flight, the utility's choice, uses its own. The delay is drawn
## from the fly's seeded stream, and the fly keeps doing what it was doing until it is over.
## Posture: awareness at the alert level turns PERCHED into ALERT (it freezes, faces where it last saw the thing, and takes in more);
## after `alert_min_s` with awareness below the calm level and rest winning, ALERT returns to PERCHED.
## Every transition is logged with its winning reason (Fly.trace), and the last decision's scores and inputs are kept for the developer view.

const PreyMath = preload("res://scripts/prey/prey_math.gd")
const FlySenses = preload("res://scripts/prey/fly_senses.gd")
const PerchGraph = preload("res://scripts/prey/perch_graph.gd")
const Fly = preload("res://scripts/prey/fly.gd")
const RecordMath = preload("res://scripts/persistence/record_math.gd")

const GOALS: Array[StringName] = [&"rest", &"move", &"flee"]
const RETRY_S := 0.25
## A sighting this recent counts in full as a reason to be afraid; the threat fades to nothing by `threat_memory_s`.
const RECENT_S := 0.4
## The alert posture needs at least this much of the awareness to be about something that matters now.
const ALERT_RELEVANCE := 0.5
const OPEN_DIRECTIONS := 8

var fly: Node3D
var weights: Dictionary = {}
## A reaction waiting out its delay ({} when none): kind, due, delay, vigilance, reason.
var pending: Dictionary = {}
## The last decision, for the developer view: goal scores, inputs and the winner.
var scores: Dictionary = {}
var inputs: Dictionary = {}
var winner: StringName = &"rest"
var blocked: Dictionary = {}
## Cost counters.
var decisions_total: int = 0
var candidates_total: int = 0
var plans_total: int = 0
var plans_ok: int = 0
var interrupts_total: int = 0

var _next_decision_t: float = 0.0
var _next_retry_t: float = 0.0


func _init(f: Node3D) -> void:
	fly = f
	weights = f.profile.weights()
	var period: float = 1.0 / f.profile.decision_hz
	_next_decision_t = f.world.now + fmod(float(f.serial) * 0.0371, period)


# ------------------------------------------------------------------ the tick

func think(now: float, _dt: float) -> void:
	var f := fly
	var p: RefCounted = f.profile
	var ev: Dictionary = f.senses.evidence
	var fresh: bool = not ev.is_empty() and absf(float(ev.get("t", -1.0e9)) - now) < 1.0e-9
	var airborne_ok: bool = f.state == Fly.State.PERCHED or f.state == Fly.State.ALERT or f.state == Fly.State.SEEK_PERCH or f.state == Fly.State.REPOSITION
	if fresh and bool(ev.get("startle", false)) and pending.is_empty() and airborne_ok:
		_schedule(&"startle", now, ev, "startle: " + _startle_text(ev))
	if f.state == Fly.State.PERCHED and ((f.senses.awareness >= p.awareness_alert and relevance(now) >= ALERT_RELEVANCE) or not pending.is_empty()):
		var why := ("startled, " if not pending.is_empty() else "noticed: awareness %.2f reached the alert level %.2f, " % [f.senses.awareness, p.awareness_alert]) + FlySenses.describe(ev)
		if not pending.is_empty():
			why = "startled: " + _startle_text(ev) + "; " + FlySenses.describe(ev)
		f.transition(Fly.State.ALERT, why)
	if not pending.is_empty() and now >= float(pending["due"]):
		_fire(now)
	if now >= _next_decision_t:
		_next_decision_t = now + 1.0 / p.decision_hz
		_decide(now)


# ------------------------------------------------------------------ decisions

func _decide(now: float) -> void:
	var f := fly
	var p: RefCounted = f.profile
	var aw: float = f.senses.awareness
	var threat: float = PreyMath.threat_input(aw, p.awareness_calm, p.awareness_flee) * relevance(now)
	if f.is_flying():
		_decide_in_flight(now, threat)
		return
	decisions_total += 1
	var here: PerchGraph.Perch = f.perch
	var restless: float = f.restlessness(now)
	var fatigue: float = f.fatigue
	var threat_pos: Variant = f.senses.last_seen_position if f.senses.has_last_seen else null
	var origin: Vector3 = f.global_position
	scores = {&"rest": PreyMath.score_rest(weights, fatigue, here.shelter, here.food, threat)}
	var best_move: Dictionary = {}
	var best_flee: Dictionary = {}
	if f.state == Fly.State.PERCHED:
		best_move = _best_prescored(&"move", now, here, threat, threat_pos, restless, fatigue, origin)
		if not best_move.is_empty():
			scores[&"move"] = best_move["score"]
	if threat > 0.02:
		best_flee = _best_prescored(&"flee", now, here, threat, threat_pos, restless, fatigue, origin)
		if not best_flee.is_empty():
			scores[&"flee"] = best_flee["score"]
	var credible: bool = threat >= p.interrupt_threat
	var chosen: StringName = PreyMath.pick_goal(scores, f.goal, p.hysteresis, GOALS)
	var held := false
	if chosen != f.goal and not credible and now - f.goal_since < p.min_commit_s:
		chosen = f.goal
		held = true
	winner = chosen
	inputs = {"threat": threat, "awareness": aw, "restless": restless, "fatigue": fatigue, "credible": credible, "held_by_commitment": held,
		"shelter_here": here.shelter, "food_here": here.food}
	match chosen:
		&"flee":
			f.set_goal(&"flee", "utility: flee wins (%s; threat %.2f)" % [_scores_text(), threat])
			if pending.is_empty():
				_schedule(&"deliberate", now, f.senses.evidence, "utility: flee wins (%s; threat %.2f)" % [_scores_text(), threat])
		&"move":
			if f.state == Fly.State.PERCHED and pending.is_empty():
				_begin_reposition(now, "utility: move wins (%s; restless %.2f)" % [_scores_text(), restless])
		_:
			if f.goal != &"rest" and pending.is_empty():
				f.set_goal(&"rest", "utility: rest wins (%s)" % _scores_text())
			if f.state == Fly.State.ALERT and pending.is_empty() and (aw < p.awareness_calm or relevance(now) < 0.25) and now - f.state_since >= p.alert_min_s:
				f.transition(Fly.State.PERCHED, "relaxed: awareness %.2f (calm level %.2f, relevance %.2f) after %.1f s on alert; rest wins (%s)" % [aw, p.awareness_calm, relevance(now), now - f.state_since, _scores_text()])


## How much of the fly's awareness is about something that matters now, in [0, 1]: the thing must have been seen lately, and the place it was
## last seen must not be far from the fly (full within half the safe distance, nothing past one and a half times it). Only the fly's own
## memory goes in: when and where it last saw the thing, and where it is itself.
func relevance(now: float) -> float:
	var s: FlySenses = fly.senses
	if not s.has_last_seen:
		return 0.0
	var p: RefCounted = fly.profile
	var age: float = now - s.last_seen_time
	var recency := clampf(1.0 - (age - RECENT_S) / maxf(float(p.threat_memory_s) - RECENT_S, 0.1), 0.0, 1.0)
	var proximity := clampf((float(p.safe_distance_wu) * 1.5 - fly.global_position.distance_to(s.last_seen_position)) / float(p.safe_distance_wu), 0.0, 1.0)
	return recency * proximity


## While flying only danger matters: a credible threat interrupts the flight.
func _decide_in_flight(now: float, threat: float) -> void:
	var f := fly
	var p: RefCounted = f.profile
	if f.state == Fly.State.SEEK_PERCH and f.flight.target == null and now >= _next_retry_t:
		_next_retry_t = now + RETRY_S
		_retarget(now, "looking for a perch")
	if (f.state == Fly.State.REPOSITION or f.state == Fly.State.SEEK_PERCH) and pending.is_empty() and threat >= p.interrupt_threat and _fresh_danger(now):
		interrupts_total += 1
		_schedule(&"deliberate", now, f.senses.evidence, "danger in flight: threat %.2f is at the interrupt level %.2f and the thing is moving in view %.1f WU away" % [threat, p.interrupt_threat, float(f.senses.evidence.get("distance", 0.0))])


## Danger worth interrupting a flight for needs new evidence: the thing seen a moment ago, moving, and within the distance the fly wants to keep.
## A fright that is only remembered (the awareness drains slowly) does not stop a fly landing.
func _fresh_danger(now: float) -> bool:
	var ev: Dictionary = fly.senses.evidence
	return not ev.is_empty() and bool(ev.get("seen", false)) and now - float(ev.get("t", -1.0e9)) <= 0.3 and float(ev.get("gain_per_s", 0.0)) > 0.0 and float(ev.get("distance", 1.0e9)) <= float(fly.profile.safe_distance_wu)


## The best candidate for a goal by its score alone (no sweeps): {} when there is none. Candidates the planner refused lately are skipped.
func _best_prescored(kind: StringName, now: float, here: PerchGraph.Perch, threat: float, threat_pos: Variant, restless: float, fatigue: float, origin: Vector3) -> Dictionary:
	var list := _candidates(kind, threat_pos, origin)
	var best: Dictionary = {}
	for c: PerchGraph.Perch in list:
		if float(blocked.get(c.id, -1.0)) > now:
			continue
		candidates_total += 1
		var s := _score(kind, c, here, threat, threat_pos, restless, fatigue, origin)
		if best.is_empty() or s > float(best["score"]) + 1.0e-9:
			best = {"perch": c, "score": s}
	return best


func _candidates(kind: StringName, threat_pos: Variant, origin: Vector3) -> Array[PerchGraph.Perch]:
	var p: RefCounted = fly.profile
	var lo: float = p.min_hop_wu
	var hi: float = p.reposition_max_wu
	if kind == &"flee":
		lo = maxf(p.min_hop_wu, p.flee_speed_wu_s * p.flee_min_s * 0.5)
		hi = p.max_flight_wu
	return fly.world.graph.candidates(fly.id, origin, threat_pos, p, lo, hi)


func _score(kind: StringName, c: PerchGraph.Perch, here: PerchGraph.Perch, threat: float, threat_pos: Variant, restless: float, fatigue: float, origin: Vector3) -> float:
	var p: RefCounted = fly.profile
	var travel := clampf(origin.distance_to(c.position) / p.max_flight_wu, 0.0, 1.0)
	if kind == &"move":
		return PreyMath.score_move(weights, restless, clampf(c.food - here.food, 0.0, 1.0), clampf(c.shelter - here.shelter, 0.0, 1.0), travel, fatigue, threat)
	var away := 0.5
	if threat_pos is Vector3:
		away = clampf((threat_pos as Vector3).distance_to(c.position) / p.safe_distance_wu, 0.0, 1.0)
	return PreyMath.score_flee(weights, threat, c.shelter, away, travel)


func _scores_text() -> String:
	var parts := PackedStringArray()
	for g in GOALS:
		if scores.has(g):
			parts.append("%s %.2f" % [str(g), float(scores[g])])
	return ", ".join(parts)


# ------------------------------------------------------------------ reactions

func _schedule(kind: StringName, now: float, ev: Dictionary, reason: String) -> void:
	var f := fly
	var p: RefCounted = f.profile
	var vigilance := "alert" if f.state == Fly.State.ALERT else ("grooming" if f.grooming(now) else "relaxed")
	var range: Vector2 = p.delay_deliberate_s
	if kind == &"startle":
		range = p.delay_startle_alert_s if vigilance == "alert" else (p.delay_startle_grooming_s if vigilance == "grooming" else p.delay_startle_relaxed_s)
	var delay: float = PreyMath.draw(f.rng, range)
	pending = {"kind": kind, "due": now + delay, "delay": delay, "vigilance": vigilance, "reason": reason, "scheduled": now}
	f.set_goal(&"flee", reason)


func _fire(now: float) -> void:
	var rec := pending
	pending = {}
	_begin_flee(now, "%s; reaction delay %.2f s (%s)" % [str(rec["reason"]), float(rec["delay"]), str(rec["vigilance"])])


## Picks where to flee to and goes. From a perch it takes off; from the air it turns into a flight away.
func _begin_flee(now: float, reason: String) -> void:
	var f := fly
	var from_air: bool = f.is_flying()
	var threat_pos: Variant = f.senses.last_seen_position if f.senses.has_last_seen else null
	var origin: Vector3 = f.global_position
	var start_normal: Vector3 = Vector3.ZERO if from_air else f.normal
	var choice := _pick_target(&"flee", now, threat_pos, origin, start_normal, 1.0)
	var text := ""
	if choice.is_empty():
		choice = _any_flyable(now, origin, start_normal, threat_pos)
	if choice.is_empty():
		choice = {"flight": _open_air_plan(origin, threat_pos), "perch": null}
		text = "no perch can be flown to: breaking away into the open air"
	else:
		var c: PerchGraph.Perch = choice["perch"]
		text = "to %s (%.1f WU, shelter %.2f)" % [c.id, origin.distance_to(c.position), c.shelter]
	f.flight.begin(choice["flight"], choice["perch"], &"flee", now, from_air)
	f.set_goal(&"flee", reason)
	f.transition(Fly.State.FLEE if from_air else Fly.State.TAKEOFF, "%s -> %s" % [reason, text])


func _begin_reposition(now: float, reason: String) -> void:
	var f := fly
	var origin: Vector3 = f.global_position
	var choice := _pick_target(&"move", now, null, origin, f.normal, 0.0)
	if choice.is_empty():
		return
	var c: PerchGraph.Perch = choice["perch"]
	f.flight.begin(choice["flight"], c, &"move", now, false)
	f.set_goal(&"move", reason)
	f.transition(Fly.State.REPOSITION, "%s -> %s (%.1f WU, food %.2f, shelter %.2f)" % [reason, c.id, origin.distance_to(c.position), c.food, c.shelter])


## A replacement fly sets off from the vent it came in through to the perch the population chose, by a flight the planner has swept
## (PreyPopulation). From then on it is an ordinary fly.
func begin_entry(now: float, target: PerchGraph.Perch, plan: PerchGraph.Flight, reason: String) -> void:
	var f := fly
	f.flight.begin(plan, target, &"move", now, false)
	f.set_goal(&"move", reason)
	f.transition(Fly.State.REPOSITION, "%s -> %s (%.1f WU, shelter %.2f)" % [reason, target.id, f.global_position.distance_to(target.position), target.shelter])


## The best flyable candidate: pre-scored, then the top few planned with sweeps until one can be flown. {} when none can.
func _pick_target(kind: StringName, now: float, threat_pos: Variant, origin: Vector3, start_normal: Vector3, threat: float) -> Dictionary:
	var f := fly
	var p: RefCounted = f.profile
	var here: PerchGraph.Perch = f.perch
	var ranked: Array[Dictionary] = []
	for c: PerchGraph.Perch in _candidates(kind, threat_pos, origin):
		if float(blocked.get(c.id, -1.0)) > now:
			continue
		candidates_total += 1
		ranked.append({"perch": c, "score": _score(kind, c, here, threat, threat_pos, f.restlessness(now), f.fatigue, origin)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"]) or (float(a["score"]) == float(b["score"]) and (a["perch"] as PerchGraph.Perch).id < (b["perch"] as PerchGraph.Perch).id))
	var tried := 0
	for r in ranked:
		if tried >= p.candidates_validated:
			break
		tried += 1
		var c: PerchGraph.Perch = r["perch"]
		plans_total += 1
		var plan: PerchGraph.Flight = f.world.graph.plan(f.world.space(), origin, start_normal, c, p, threat_pos)
		if plan.ok:
			plans_ok += 1
			return {"perch": c, "flight": plan, "score": r["score"]}
		blocked[c.id] = now + p.block_retry_s
	return {}


## Last resort before the open air: any perch at all that a flight can reach, ignoring the preference for being far from the thing.
func _any_flyable(now: float, origin: Vector3, start_normal: Vector3, threat_pos: Variant) -> Dictionary:
	var f := fly
	var p: RefCounted = f.profile
	var tried := 0
	for c: PerchGraph.Perch in f.world.graph.candidates(f.id, origin, null, p, p.min_hop_wu * 0.5, p.max_flight_wu):
		if tried >= p.candidates_validated:
			break
		tried += 1
		plans_total += 1
		var plan: PerchGraph.Flight = f.world.graph.plan(f.world.space(), origin, start_normal, c, p, threat_pos)
		if plan.ok:
			plans_ok += 1
			return {"perch": c, "flight": plan}
	return {}


## A short flight into the open air, away from where the thing was last seen (or the way the fly faces), up a little. The longest clear
## one of eight directions; a path of one point when nothing is clear, and the fly hovers.
func _open_air_plan(origin: Vector3, threat_pos: Variant) -> PerchGraph.Flight:
	var f := fly
	var p: RefCounted = f.profile
	var base := Vector3(f.heading.x, 0.0, f.heading.z)
	if threat_pos is Vector3:
		base = origin - (threat_pos as Vector3)
		base.y = 0.0
	base = base.normalized() if base.length_squared() > 1.0e-6 else Vector3.FORWARD
	var best_end := origin
	var best_frac := -1.0
	for i in OPEN_DIRECTIONS:
		var dir := base.rotated(Vector3.UP, TAU * float(i) / float(OPEN_DIRECTIONS))
		var goal: Vector3 = origin + dir * float(p.open_escape_wu) + Vector3.UP * 2.0
		goal.y = minf(goal.y, f.world.graph.CEILING_Y)
		var frac: float = f.world.graph.sweep(f.world.space(), origin, goal, p.clearance_radius_wu)
		if frac > best_frac + 1.0e-6:
			best_frac = frac
			best_end = origin.lerp(goal, frac * 0.95)
		if frac >= 0.999:
			break
	var plan := PerchGraph.Flight.new()
	plan.ok = true
	plan.reason = "open air"
	plan.points = PackedVector3Array([origin, best_end]) if best_frac > 0.05 else PackedVector3Array([origin])
	plan.length = PreyMath.path_length(plan.points)
	return plan


## Called by the flight when the way is blocked and could not be re-planned: another perch, or hover and look again.
func on_flight_blocked(now: float) -> void:
	var f := fly
	if f.flight.target != null:
		blocked[f.flight.target.id] = now + f.profile.block_retry_s
	_retarget(now, "its way was blocked")


## From the air, choose a perch now (the goal the fly has decides how): returns after beginning a flight or after setting the fly to hover.
func _retarget(now: float, why: String) -> void:
	var f := fly
	var threat_pos: Variant = f.senses.last_seen_position if f.senses.has_last_seen else null
	var origin: Vector3 = f.global_position
	var kind: StringName = &"flee" if f.goal == &"flee" else &"move"
	var choice := _pick_target(kind, now, threat_pos if kind == &"flee" else null, origin, Vector3.ZERO, 1.0 if kind == &"flee" else 0.0)
	if choice.is_empty():
		choice = _any_flyable(now, origin, Vector3.ZERO, threat_pos)
	if choice.is_empty():
		f.flight.hover(now)
		if f.state != Fly.State.SEEK_PERCH:
			f.transition(Fly.State.SEEK_PERCH, "%s: no perch can be flown to, hovering and looking again" % why)
		return
	var c: PerchGraph.Perch = choice["perch"]
	f.flight.begin(choice["flight"], c, f.flight.mode if f.flight.mode != &"" else kind, now, true)
	if f.state != Fly.State.SEEK_PERCH and f.state != Fly.State.FLEE:
		f.transition(Fly.State.SEEK_PERCH, "%s: new target %s" % [why, c.id])


## The fly's perch left the world under it: it flies at once (no delay: the floor is gone).
func on_perch_lost() -> void:
	var f := fly
	if f.state > Fly.State.REPOSITION or f.is_flying():
		return
	pending = {}
	_begin_flee(f.world.now, "its perch left the world")


# ------------------------------------------------------------------ words

static func _startle_text(ev: Dictionary) -> String:
	return "motion %.0f deg/s (bearing %.0f, loom %.0f) at %.1f WU, %.0f deg off its facing, is over the limit" % [
		float(ev.get("motion_deg_s", 0.0)), float(ev.get("bearing_deg_s", 0.0)), float(ev.get("loom_deg_s", 0.0)), float(ev.get("distance", 0.0)), float(ev.get("off_deg", 0.0))]


## One line for the developer view.
func describe() -> String:
	var line := "winner %s | %s" % [str(winner), _scores_text()]
	if not pending.is_empty():
		line += " | reacting in %.2f s (%s)" % [maxf(0.0, float(pending["due"]) - fly.world.now), str(pending["kind"])]
	return line


## T09: a reaction waiting out its delay, the perches refused lately and the decision clock, as a plain record. The last scores are for the
## developer view and are made again at the next decision.
func to_record() -> Dictionary:
	var p := RecordMath.plain(pending)
	return {"pending": p, "blocked": blocked.duplicate(), "next_decision": _next_decision_t, "next_retry": _next_retry_t, "winner": str(winner)}


func apply_record(r: Dictionary) -> void:
	pending = (r["pending"] as Dictionary).duplicate()
	if pending.has("kind"):
		pending["kind"] = StringName(str(pending["kind"]))
	blocked = {}
	for k: Variant in (r["blocked"] as Dictionary):
		blocked[str(k)] = float((r["blocked"] as Dictionary)[k])
	_next_decision_t = float(r["next_decision"])
	_next_retry_t = float(r["next_retry"])
	winner = StringName(str(r["winner"]))
