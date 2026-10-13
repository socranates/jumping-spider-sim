extends RefCounted
## T09 / S01-C: the retreat checkpoint (spec 21.4, 22; DECISIONS A-001). A checkpoint is the whole world at one tick boundary, in one plain
## record: the spider standing on its surface, its reserves and the books of what fed them, every fly with its streams and what it was in
## the middle of, who sits on each perch, the replacements still owed, the captures made, the habitat clock and the passing shadow.
## Loading one discards the current world and builds the checkpoint's world again from this record, so an earlier spider is never put into a
## newer world and a prey eaten after the checkpoint is not eaten twice: both the fly and the energy it gave go back together.
##
## When: only at the end of a tick (the habitat loop runs last, after contacts, captures and feeding have resolved), and only from a supported,
## still spider that is not mid-meal or mid-strike. The player makes one by resting in the retreat; tests may make one anywhere that is
## supported (for L01 with a part-eaten fly in the jaws). Airborne, hanging, preparing and feeding states are refused: exact arbitrary-state
## resume (the original S01) is deferred, not claimed.
## Validation happens on the record alone, before any node is built (spec 22.5): types, finite numbers, bounds, unique ids, every reference
## (perches, vents, surfaces, the fly in the jaws, the captures and the energy each one gave), and the schema and content revision.

const RecordMath = preload("res://scripts/persistence/record_math.gd")
const Windowsill = preload("res://scripts/habitat/windowsill.gd")
const NeedsModel = preload("res://scripts/needs/needs_model.gd")
const PreyProfile = preload("res://scripts/prey/prey_profile.gd")
const Fly = preload("res://scripts/prey/fly.gd")
const HabitatLoop = preload("res://scripts/habitat/habitat_loop.gd")
const LifeClock = preload("res://scripts/life/life_clock.gd")
const Growth = preload("res://scripts/life/growth.gd")
const WaspDirector = preload("res://scripts/predator/wasp_director.gd")

## Schema 2 (T09b): flies record their glances (schedule: home_heading, glancing, glance_target, glance_sign, next_glance) and the
## habitat's fallen leaf tip is a habitat change. Schema 3 (T09c): flies record their walks (schedule: walking, walk_target, walk_speed,
## burst_left, pause_left, next_walk, rest_spot). Schema 4 (LIFE_DESIGN.md round 1): the life clock (life: day, hour, sleeping) and
## the needs' life mode (life_mode, starving_hours, hour_accumulator). Schema 5 (round 3): growth (stage, food since the last moult,
## readiness, the moult and the soft skin still to pass, where the old skins lie). Schema 6 (round 4): the wasp (the day of its last
## visit, and this life's visits and escapes; a visit going on is not kept: the spider rests in the crack, where the wasp cannot find
## it, and the world that comes back has the wasp away). Older records are upgraded on load (upgrade()), one schema at a time.
const SCHEMA_VERSION := 6
const GAME_BUILD := "prototype-0.1.0"
const KIND := "retreat_checkpoint"
const PLAYER_ID := "spider"
const SLOT_ID := "checkpoint"
## The windowsill's play bounds (Windowsill.get_play_bounds), for checking a recorded position without building the habitat.
const PLAY_BOUNDS := AABB(Vector3(-33, -5, -16), Vector3(66, 40, 32))
const STILL_SPEED := 0.15
const EPS := 1.0e-6
const PHASES: Array[String] = ["waiting", "warning", "passing", "quiet"]
const FLY_PROFILE_PATH := "res://data/species/fly_like_prototype.json"


## Why a checkpoint cannot be made of `world` now; "" when it can.
static func boundary_problem(world: Node) -> String:
	if world == null or not world.is_inside_tree():
		return "there is no world"
	if not world.use_windowsill or world.habitat_loop == null:
		return "this world has no retreat checkpoint (only the windowsill does)"
	var prey: Node = world.prey
	if prey == null or not prey.ready_done:
		return "the world is still starting"
	var spider: Node = world.spider
	if spider.state != spider.State.ATTACHED or not spider.support.is_valid() or spider.in_transition():
		return "the spider is not standing on a surface"
	if spider.velocity.length() > STILL_SPEED:
		return "the spider is moving"
	if world.feeding.feeding:
		return "the spider is feeding"
	if world.feeding.struggling:
		return "the prey in the jaws is still struggling"
	if prey.strike_active:
		return "a strike is still in progress"
	return ""


## The checkpoint record of `world` as it is now. Call boundary_problem first; this does not check it again.
static func capture(world: Node) -> Dictionary:
	var spider: Node = world.spider
	var prey: Node = world.prey
	var loop: Node = world.habitat_loop
	var in_retreat: bool = world.lab.in_retreat(spider.global_position)
	var prey_record: Dictionary = prey.to_record()
	var rng_states := {"population": prey_record["population"]["rng_state"]}
	for fr: Dictionary in prey_record["flies"]:
		rng_states[str(fr["id"])] = fr["rng_state"]
	return {
		"schema_version": SCHEMA_VERSION, "game_build": GAME_BUILD, "content_revision": Windowsill.CONTENT_REVISION, "kind": KIND,
		"slot_id": SLOT_ID, "created_utc": Time.get_datetime_string_from_system(true) + "Z",
		"snapshot_tick": int(prey.tick), "seed": str(prey.seed_value), "rng_states": rng_states,
		"clocks": {"action_seconds": float(prey.now), "habitat_elapsed": float(loop.elapsed), "needs_elapsed": float(world.needs.elapsed_s)},
		"player_id": PLAYER_ID,
		"player": {"id": PLAYER_ID, "position": RecordMath.v3(spider.global_position), "normal": RecordMath.v3(spider.support.normal),
			"heading": RecordMath.v3(spider.get_heading_vector()), "surface_id": str(spider.support.surface_id),
			"retreat_id": Windowsill.RETREAT_ID if in_retreat else "", "state": "ATTACHED"},
		"needs": world.needs.to_dict(),
		"feeding": {"meals_started": world.feeding.meals_started, "meals_finished": world.feeding.meals_finished,
			"taken_total": world.feeding.taken_total, "granted_total": world.feeding.granted_total},
		"prey": prey_record,
		"habitat": loop.to_dict(),
		"life": loop.clock.to_dict(),
		"growth": loop.growth.to_dict(),
		"wasp": world.wasp_director.to_dict() if world.get("wasp_director") != null else WaspDirector.default_record(),
		"retreats": [{"id": Windowsill.RETREAT_ID, "surface_id": "sill_floor"}],
		"habitat_changes": world.lab.changes_record(),
		"journal": [],
	}


## A record of an older schema brought up to this one (a copy; the original, and any file it came from, are left as they were). A record
## that is not an older schema this build knows comes back unchanged, for validate() to judge.
static func upgrade(record: Variant) -> Variant:
	if typeof(record) != TYPE_DICTIONARY or not RecordMath.is_whole((record as Dictionary).get("schema_version")):
		return record
	var r: Dictionary = (record as Dictionary).duplicate(true)
	if int(r["schema_version"]) == 1:
		# 1 -> 2: a fly that was perched settled facing the way it faces now and has not yet glanced; its first glance is a second away.
		var prey: Variant = r.get("prey")
		var now := float((prey as Dictionary).get("now", 0.0)) if typeof(prey) == TYPE_DICTIONARY else 0.0
		if typeof(prey) == TYPE_DICTIONARY and typeof((prey as Dictionary).get("flies")) == TYPE_ARRAY:
			for fv: Variant in prey["flies"]:
				if typeof(fv) == TYPE_DICTIONARY and typeof((fv as Dictionary).get("schedule")) == TYPE_DICTIONARY:
					var sch: Dictionary = fv["schedule"]
					var h: Variant = (fv as Dictionary).get("heading", [0.0, 0.0, -1.0])
					sch["home_heading"] = h
					sch["glancing"] = false
					sch["glance_target"] = h
					sch["glance_sign"] = 1.0
					sch["next_glance"] = now + 1.0
		if typeof(r.get("habitat_changes")) != TYPE_ARRAY:
			r["habitat_changes"] = []
		r["schema_version"] = 2
		r["upgraded_from"] = 1
	if int(r["schema_version"]) == 2:
		# 2 -> 3: no fly is mid-walk; each settled where it stands and walks again in a moment.
		var prey3: Variant = r.get("prey")
		var now3 := float((prey3 as Dictionary).get("now", 0.0)) if typeof(prey3) == TYPE_DICTIONARY else 0.0
		if typeof(prey3) == TYPE_DICTIONARY and typeof((prey3 as Dictionary).get("flies")) == TYPE_ARRAY:
			for fv: Variant in prey3["flies"]:
				if typeof(fv) == TYPE_DICTIONARY and typeof((fv as Dictionary).get("schedule")) == TYPE_DICTIONARY:
					var sch3: Dictionary = fv["schedule"]
					var st: Variant = (fv as Dictionary).get("stand", [0.0, 0.0, 0.0])
					sch3["walking"] = false
					sch3["walk_target"] = st
					sch3["walk_speed"] = 0.0
					sch3["burst_left"] = 0.0
					sch3["pause_left"] = 0.0
					sch3["next_walk"] = now3 + 1.5
					sch3["rest_spot"] = st
		r["schema_version"] = 3
		if not r.has("upgraded_from"):
			r["upgraded_from"] = 2
	if int(r["schema_version"]) == 3:
		# 3 -> 4: the morning of the first day, the reserve not yet counted by the hour (the world turns life mode on as it loads).
		r["life"] = {"day": LifeClock.START_DAY, "hour": LifeClock.START_H, "sleeping": false}
		var needs4: Variant = r.get("needs")
		if typeof(needs4) == TYPE_DICTIONARY:
			needs4["life_mode"] = false
			needs4["starving_hours"] = 0.0
			needs4["hour_accumulator"] = [0.0, 0.0]
		r["schema_version"] = 4
		if not r.has("upgraded_from"):
			r["upgraded_from"] = 3
	if int(r["schema_version"]) == 4:
		# 4 -> 5: a young juvenile that has not yet eaten toward its next moult.
		r["growth"] = Growth.new().to_dict()
		r["schema_version"] = 5
		if not r.has("upgraded_from"):
			r["upgraded_from"] = 4
	if int(r["schema_version"]) == 5:
		# 5 -> 6: the wasp has not yet come in this life.
		r["wasp"] = WaspDirector.default_record()
		r["schema_version"] = 6
		if not r.has("upgraded_from"):
			r["upgraded_from"] = 5
	return r


## Everything wrong with `record`; empty when it can be loaded. Nothing is built and nothing is changed.
static func validate(record: Variant) -> PackedStringArray:
	var e := PackedStringArray()
	if typeof(record) != TYPE_DICTIONARY:
		e.append("the checkpoint is not a record")
		return e
	var r: Dictionary = record
	if not RecordMath.is_whole(r.get("schema_version")):
		e.append("the checkpoint has no schema version")
		return e
	var version := int(r["schema_version"])
	if version > SCHEMA_VERSION:
		e.append("the checkpoint was made by a newer version of the game (schema %d; this build reads schema %d). It was left untouched." % [version, SCHEMA_VERSION])
		return e
	if version < 1 or version != SCHEMA_VERSION:
		e.append("unsupported checkpoint schema %d (this build reads schema %d)" % [version, SCHEMA_VERSION])
		return e
	if str(r.get("kind", "")) != KIND:
		e.append("not a retreat checkpoint (kind '%s')" % str(r.get("kind", "")))
	if str(r.get("content_revision", "")) != Windowsill.CONTENT_REVISION:
		e.append("the checkpoint belongs to habitat content '%s', not '%s'" % [str(r.get("content_revision", "")), Windowsill.CONTENT_REVISION])
	if str(r.get("player_id", "")) != PLAYER_ID:
		e.append("the checkpoint names no player")
	for key: String in ["player", "needs", "feeding", "prey", "habitat", "clocks", "life", "growth", "wasp"]:
		if typeof(r.get(key)) != TYPE_DICTIONARY:
			e.append("missing section '%s'" % key)
	if not e.is_empty():
		return e
	_check_player(r["player"], e)
	_check_feeding(r["feeding"], e)
	if not NeedsModel.new().load_dict(r["needs"]):
		e.append("needs: the reserves or their ledger are not a valid record")
	_check_habitat(r["habitat"], e)
	e.append_array(LifeClock.problems(r["life"]))
	e.append_array(Growth.problems(r["growth"]))
	e.append_array(WaspDirector.problems(r["wasp"]))
	_check_prey(r["prey"], r["needs"], e)
	_check_changes(r.get("habitat_changes"), e)
	if e.is_empty():
		var prey: Dictionary = r["prey"]
		if int(r.get("snapshot_tick", -1)) != int(prey["tick"]):
			e.append("the snapshot tick does not match the prey clock")
		if not RecordMath.is_num((r["clocks"] as Dictionary).get("action_seconds")) or absf(float(r["clocks"]["action_seconds"]) - float(prey["now"])) > EPS:
			e.append("the action clock does not match the prey clock")
	return e


static func _num(d: Dictionary, key: String, e: PackedStringArray, where: String, lo: float = -INF, hi: float = INF) -> bool:
	var v: Variant = d.get(key)
	if not RecordMath.is_num(v) or float(v) < lo or float(v) > hi:
		e.append("%s: '%s' is missing, not a finite number or out of range" % [where, key])
		return false
	return true


static func _whole(d: Dictionary, key: String, e: PackedStringArray, where: String, lo: int = 0) -> bool:
	var v: Variant = d.get(key)
	if not RecordMath.is_whole(v) or int(v) < lo:
		e.append("%s: '%s' is not a whole number of at least %d" % [where, key, lo])
		return false
	return true


static func _str(d: Dictionary, key: String, e: PackedStringArray, where: String) -> bool:
	if typeof(d.get(key)) != TYPE_STRING:
		e.append("%s: '%s' is not text" % [where, key])
		return false
	return true


static func _vec(d: Dictionary, key: String, e: PackedStringArray, where: String, unit: bool = false) -> bool:
	var ok := RecordMath.is_unit_v3(d.get(key)) if unit else RecordMath.is_v3(d.get(key))
	if not ok:
		e.append("%s: '%s' is not a %svector" % [where, key, "unit " if unit else ""])
	return ok


static func _bool(d: Dictionary, key: String, e: PackedStringArray, where: String) -> bool:
	if typeof(d.get(key)) != TYPE_BOOL:
		e.append("%s: '%s' is not true or false" % [where, key])
		return false
	return true


static func _check_player(p: Dictionary, e: PackedStringArray) -> void:
	var w := "player"
	if str(p.get("id", "")) != PLAYER_ID:
		e.append("player: unknown id")
	if str(p.get("state", "")) != "ATTACHED":
		e.append("player: a checkpoint holds only a spider standing on a surface")
	if _vec(p, "position", e, w) and not PLAY_BOUNDS.has_point(RecordMath.to_v3(p["position"])):
		e.append("player: the position is outside the habitat")
	var n_ok := _vec(p, "normal", e, w, true)
	var h_ok := _vec(p, "heading", e, w, true)
	if n_ok and h_ok and absf(RecordMath.to_v3(p["normal"]).dot(RecordMath.to_v3(p["heading"]))) > 0.05:
		e.append("player: the heading does not lie along the surface")
	if not (Windowsill.SURFACE_IDS as Array).has(str(p.get("surface_id", ""))):
		e.append("player: the surface '%s' is not part of the habitat" % str(p.get("surface_id", "")))
	if _str(p, "retreat_id", e, w) and str(p["retreat_id"]) not in ["", Windowsill.RETREAT_ID]:
		e.append("player: unknown retreat '%s'" % str(p["retreat_id"]))


static func _check_feeding(f: Dictionary, e: PackedStringArray) -> void:
	var w := "feeding"
	_whole(f, "meals_started", e, w)
	_whole(f, "meals_finished", e, w)
	_num(f, "taken_total", e, w, 0.0)
	_num(f, "granted_total", e, w, 0.0)
	if e.is_empty() and float(f["granted_total"]) > float(f["taken_total"]) + EPS:
		e.append("feeding: more energy granted than prey eaten")


static func _check_habitat(h: Dictionary, e: PackedStringArray) -> void:
	var w := "habitat"
	if str(h.get("retreat_id", "")) != Windowsill.RETREAT_ID:
		e.append("habitat: unknown retreat")
	if str(h.get("event_id", "")) != HabitatLoop.EVENT_ID:
		e.append("habitat: unknown event")
	_bool(h, "resting", e, w)
	_num(h, "rest_seconds", e, w, 0.0)
	_num(h, "elapsed", e, w, 0.0)
	_num(h, "phase_seconds", e, w, 0.0)
	var completed_ok := _bool(h, "event_completed", e, w)
	var phase := str(h.get("phase", ""))
	if not PHASES.has(phase):
		e.append("habitat: unknown event phase '%s'" % phase)
	elif completed_ok and (phase == "quiet") != bool(h["event_completed"]):
		e.append("habitat: the event phase and its completion disagree")


static func _check_prey(p: Dictionary, needs: Dictionary, e: PackedStringArray) -> void:
	var w := "prey"
	var start := e.size()
	if not RecordMath.is_int_string(p.get("seed")):
		e.append("prey: the seed is not a whole number written as text")
	_whole(p, "tick", e, w)
	_num(p, "now", e, w, 0.0)
	_whole(p, "serial_counter", e, w)
	_whole(p, "target_population", e, w)
	_bool(p, "replenish", e, w)
	_str(p, "held", e, w)
	for key: String in ["captures", "flies", "perches"]:
		if typeof(p.get(key)) != TYPE_ARRAY:
			e.append("prey: '%s' is not a list" % key)
	if typeof(p.get("population")) != TYPE_DICTIONARY:
		e.append("prey: no population record")
	if e.size() > start:
		return
	var known_perches := {}
	for id: String in Windowsill.PERCH_POINTS:
		known_perches[id] = "perch"
	for id: String in Windowsill.VENT_POINTS:
		known_perches[id] = "vent"
	# captures
	var capture_ids := {}
	for c: Variant in p["captures"]:
		if typeof(c) != TYPE_DICTIONARY or typeof((c as Dictionary).get("id")) != TYPE_STRING or typeof((c as Dictionary).get("prey")) != TYPE_STRING:
			e.append("prey: a capture record is malformed")
			continue
		var cid := str(c["id"])
		if capture_ids.has(cid):
			e.append("prey: capture %s is recorded twice" % cid)
		capture_ids[cid] = str(c["prey"])
		if cid != "capture:%s:%s" % [PLAYER_ID, str(c["prey"])] or str((c as Dictionary).get("owner", "")) != PLAYER_ID:
			e.append("prey: capture %s has the wrong owner or id" % cid)
	# flies
	var flies := {}
	var serials := {}
	var serial_counter := int(p["serial_counter"])
	var captured_count := 0
	for fv: Variant in p["flies"]:
		if typeof(fv) != TYPE_DICTIONARY:
			e.append("prey: a fly record is not a record")
			continue
		var f: Dictionary = fv
		var fid := str(f.get("id", ""))
		var fw := "fly %s" % fid
		if fid == "" or flies.has(fid):
			e.append("prey: a fly has no id or a repeated id '%s'" % fid)
			continue
		flies[fid] = f
		if _whole(f, "serial", e, fw, 1):
			if int(f["serial"]) > serial_counter or serials.has(int(f["serial"])):
				e.append("%s: its serial is repeated or beyond the id counter" % fw)
			serials[int(f["serial"])] = true
		for key: String in ["rng_seed", "rng_state", "cosmetic_rng_state"]:
			if not RecordMath.is_int_string(f.get(key)):
				e.append("%s: '%s' is not a whole number written as text" % [fw, key])
		var state_name := str(f.get("state", ""))
		var st := Fly.STATE_NAMES.find(state_name)
		if st < 0 or st == Fly.State.CONSUMED:
			e.append("%s: state '%s' cannot be restored" % [fw, state_name])
		for key: String in ["state_since", "goal_since", "fatigue", "restless_rate", "perched_since"]:
			_num(f, key, e, fw)
		_num(f, "fatigue", e, fw, 0.0, 1.0)
		for key: String in ["goal", "goal_reason", "perch", "captured_by", "capture_event_id"]:
			_str(f, key, e, fw)
		for key: String in ["stand", "position", "velocity"]:
			_vec(f, key, e, fw)
		_vec(f, "normal", e, fw, true)
		_vec(f, "heading", e, fw, true)
		if str(f.get("perch", "")) != "" and not known_perches.has(str(f["perch"])):
			e.append("%s: unknown perch '%s'" % [fw, str(f["perch"])])
		var tot_ok := _num(f, "nutrition_total", e, fw, 0.0)
		var left_ok := _num(f, "nutrition_left", e, fw, 0.0)
		if tot_ok and left_ok and float(f["nutrition_left"]) > float(f["nutrition_total"]) + EPS:
			e.append("%s: more nutrition left than it ever had" % fw)
		_check_schedule(f.get("schedule"), e, fw)
		_check_senses(f.get("senses"), e, fw)
		_check_mind(f.get("mind"), e, fw)
		_check_flight(f.get("flight"), known_perches, e, fw)
		if st == Fly.State.CAPTURED:
			captured_count += 1
			if fid != str(p["held"]) or str(f.get("captured_by", "")) != PLAYER_ID or str(f.get("capture_event_id", "")) != "capture:%s:%s" % [PLAYER_ID, fid] \
					or not capture_ids.has(str(f.get("capture_event_id", ""))):
				e.append("%s: a captured fly must be the one in the jaws, with its capture recorded" % fw)
		elif str(f.get("captured_by", "x")) != "" or str(f.get("capture_event_id", "x")) != "" or capture_ids.values().has(fid):
			e.append("%s: a free fly carries a capture" % fw)
		elif tot_ok and left_ok and absf(float(f["nutrition_left"]) - float(f["nutrition_total"])) > EPS:
			e.append("%s: a free fly has been eaten" % fw)
	if captured_count > 1:
		e.append("prey: more than one fly is in the jaws")
	var held := str(p["held"])
	if held != "" and (not flies.has(held) or str((flies[held] as Dictionary).get("state", "")) != "CAPTURED"):
		e.append("prey: the fly in the jaws ('%s') is not a captured fly of this checkpoint" % held)
	# perches: every authored perch and vent once, occupancy consistent with the flies
	var seen := {}
	for pv: Variant in p["perches"]:
		if typeof(pv) != TYPE_DICTIONARY:
			e.append("prey: a perch record is not a record")
			continue
		var pr: Dictionary = pv
		var pid := str(pr.get("id", ""))
		if not known_perches.has(pid) or seen.has(pid):
			e.append("prey: unknown or repeated perch '%s'" % pid)
			continue
		seen[pid] = true
		if not (_str(pr, "occupant", e, "perch " + pid) and _str(pr, "reserved_by", e, "perch " + pid) and _bool(pr, "available", e, "perch " + pid)):
			continue
		var occ := str(pr["occupant"])
		if occ != "":
			var of: Dictionary = flies.get(occ, {})
			if of.is_empty() or str(of.get("perch", "")) != pid or str(of.get("state", "")) not in ["PERCHED", "ALERT"]:
				e.append("perch %s: its occupant '%s' is not a fly resting there" % [pid, occ])
		var res := str(pr["reserved_by"])
		if res != "":
			var rf: Dictionary = flies.get(res, {})
			if rf.is_empty() or typeof(rf.get("flight")) != TYPE_DICTIONARY or str((rf["flight"] as Dictionary).get("target", "")) != pid:
				e.append("perch %s: it is reserved by '%s', which is not flying to it" % [pid, res])
	if seen.size() != known_perches.size():
		e.append("prey: %d of %d perches and vents are recorded" % [seen.size(), known_perches.size()])
	_check_population(p["population"], e)
	# the books: no capture may have given more energy than its fly had, and the fly in the jaws no more than was eaten of it
	if e.size() > start:
		return
	var nutrition := _fly_nutrition()
	var by_source: Dictionary = needs.get("granted_by_source", {})
	for src: Variant in by_source:
		if not capture_ids.has(str(src)):
			e.append("needs: energy granted by '%s', which is not a recorded capture" % str(src))
			continue
		var given := float(by_source[src])
		var prey_id := str(capture_ids[str(src)])
		var limit := nutrition
		if flies.has(prey_id):
			var hf: Dictionary = flies[prey_id]
			limit = float(hf["nutrition_total"]) - float(hf["nutrition_left"])
		if given > limit + EPS:
			e.append("needs: capture %s gave %.5f, more than the %.5f eaten of its fly" % [str(src), given, limit])


static func _check_changes(v: Variant, e: PackedStringArray) -> void:
	if typeof(v) != TYPE_ARRAY:
		e.append("habitat_changes is not a list")
		return
	var seen := {}
	for c: Variant in v:
		if typeof(c) != TYPE_DICTIONARY or not Windowsill.DROP_PIECES.has(str((c as Dictionary).get("surface_id", ""))) \
				or seen.has(str((c as Dictionary).get("surface_id", ""))) or (c as Dictionary).get("available") != false:
			e.append("habitat_changes: an unknown, repeated or malformed change")
			continue
		seen[str(c["surface_id"])] = true
		_num(c, "returns_in", e, "habitat_changes", 0.0, 600.0)


static func _check_schedule(v: Variant, e: PackedStringArray, fw: String) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		e.append("%s: no schedule" % fw)
		return
	var d: Dictionary = v
	for key: String in ["next_fidget", "fidget_t0", "fidget_t1", "next_groom", "groom_t1", "next_glance", "next_walk", "burst_left", "pause_left"]:
		_num(d, key, e, fw + " schedule")
	_num(d, "glance_sign", e, fw + " schedule", -1.0, 1.0)
	_num(d, "walk_speed", e, fw + " schedule", 0.0, 50.0)
	_bool(d, "glancing", e, fw + " schedule")
	_bool(d, "walking", e, fw + " schedule")
	for key: String in ["fidget_from", "fidget_to", "home_heading", "glance_target", "walk_target", "rest_spot"]:
		_vec(d, key, e, fw + " schedule")


static func _check_senses(v: Variant, e: PackedStringArray, fw: String) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		e.append("%s: no senses record" % fw)
		return
	var d: Dictionary = v
	var w := fw + " senses"
	_num(d, "awareness", e, w, 0.0)
	for key: String in ["last_seen_time", "last_time", "last_check_time", "next_check_time"]:
		_num(d, key, e, w)
	_whole(d, "last_mask", e, w)
	for key: String in ["has_last_seen", "started", "has_last"]:
		_bool(d, key, e, w)
	_vec(d, "last_seen_position", e, w)
	_vec(d, "last_point", e, w)
	if typeof(d.get("evidence")) != TYPE_DICTIONARY:
		e.append("%s: evidence is not a record" % w)


static func _check_mind(v: Variant, e: PackedStringArray, fw: String) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		e.append("%s: no mind record" % fw)
		return
	var d: Dictionary = v
	var w := fw + " mind"
	_num(d, "next_decision", e, w)
	_num(d, "next_retry", e, w)
	if str(d.get("winner", "")) not in ["rest", "move", "flee"]:
		e.append("%s: unknown goal" % w)
	if typeof(d.get("blocked")) != TYPE_DICTIONARY:
		e.append("%s: blocked is not a record" % w)
	else:
		for k: Variant in d["blocked"]:
			if not RecordMath.is_num((d["blocked"] as Dictionary)[k]):
				e.append("%s: a blocked time is not a number" % w)
	if typeof(d.get("pending")) != TYPE_DICTIONARY:
		e.append("%s: pending is not a record" % w)
	elif not (d["pending"] as Dictionary).is_empty():
		var pd: Dictionary = d["pending"]
		if str(pd.get("kind", "")) not in ["startle", "deliberate"] or not RecordMath.is_num(pd.get("due")) or not RecordMath.is_num(pd.get("delay")):
			e.append("%s: the pending reaction is malformed" % w)


static func _check_flight(v: Variant, known: Dictionary, e: PackedStringArray, fw: String) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		e.append("%s: no flight record" % fw)
		return
	var d: Dictionary = v
	var w := fw + " flight"
	for key: String in ["length", "s", "speed"]:
		_num(d, key, e, w, 0.0)
	_num(d, "started_at", e, w)
	_whole(d, "replans", e, w)
	_whole(d, "blocked_ticks", e, w)
	_str(d, "mode", e, w)
	if typeof(d.get("path")) != TYPE_ARRAY:
		e.append("%s: the path is not a list" % w)
	else:
		for pt: Variant in d["path"]:
			if not RecordMath.is_v3(pt):
				e.append("%s: a path point is not a vector" % w)
				break
	if str(d.get("target", "")) != "" and not known.has(str(d["target"])):
		e.append("%s: unknown target '%s'" % [w, str(d["target"])])


static func _check_population(v: Variant, e: PackedStringArray) -> void:
	var d: Dictionary = v
	var w := "population"
	_bool(d, "enabled", e, w)
	_whole(d, "target", e, w)
	if not RecordMath.is_int_string(d.get("rng_state")):
		e.append("population: the stream state is not a whole number written as text")
	for key: String in ["last_ask_t", "next_ask"]:
		_num(d, key, e, w)
	for key: String in ["losses_noticed", "asks_total", "deferred_total", "entries_total"]:
		_whole(d, key, e, w)
	if typeof(d.get("pending")) != TYPE_ARRAY:
		e.append("population: pending is not a list")
	else:
		for rv: Variant in d["pending"]:
			if typeof(rv) != TYPE_DICTIONARY or not RecordMath.is_num((rv as Dictionary).get("lost")) or not RecordMath.is_num((rv as Dictionary).get("delay")) \
					or not RecordMath.is_num((rv as Dictionary).get("due")):
				e.append("population: a pending replacement is malformed")
	if typeof(d.get("vent_free_at")) != TYPE_DICTIONARY:
		e.append("population: vent_free_at is not a record")
	else:
		for k: Variant in d["vent_free_at"]:
			if not Windowsill.VENT_POINTS.has(str(k)) or not RecordMath.is_num((d["vent_free_at"] as Dictionary)[k]):
				e.append("population: unknown vent '%s'" % str(k))
	if typeof(d.get("ok_before")) != TYPE_ARRAY:
		e.append("population: ok_before is not a list")
	else:
		for k: Variant in d["ok_before"]:
			if not Windowsill.VENT_POINTS.has(str(k)):
				e.append("population: unknown vent '%s'" % str(k))


## The nutrition of one fly of the shipped profile (a capture can never have given more).
static func _fly_nutrition() -> float:
	var was := PreyProfile.quiet
	PreyProfile.quiet = true
	var prof = PreyProfile.load_file(FLY_PROFILE_PATH)
	PreyProfile.quiet = was
	return float(prof.nutrition) if prof != null else 1.0
