extends SceneTree
## Exports LIFE golden values from the frozen Godot reference for roblox_port/tests/life_reference.json.
## Godot's own code runs; nothing is recomputed by the port:
##   * clock: the real LifeClock (scripts/life/life_clock.gd): its day, advance, sleep, moult, daylight, words and record checks.
##   * needs: the real NeedsModel (scripts/needs/needs_model.gd): the 2 Hz drain, life mode by the hour, gentle rules, grants,
##     rest, the record and its checks.
##   * loop: the real habitat loop (scripts/habitat/habitat_loop.gd) on a stand-in world (a spider that is in or out of the crack
##     and still or moving, no prey unless a scenario holds one, the real NeedsModel advanced first in each tick as the feeding
##     controller does). Recorded every tick: the clock, rest and sleep, energy, the reach of the eyes, notices and checkpoints.
##     No food is eaten in a scenario, so growth never readies a moult, and the reserve never runs out, so the round 5 starvation
##     rules (not part of this port) never act. The loop's shadow event runs as in Godot and is not recorded.
## Run from the repo root:
##   godot --headless --path . -s roblox_port/tools/export_life_reference.gd -- roblox_port/tests/life_reference.json
## then, from roblox_port/:  python3 tools/reference_to_luau.py tests/life_reference.json
const LifeClock = preload("res://scripts/life/life_clock.gd")
const NeedsModel = preload("res://scripts/needs/needs_model.gd")
const HabitatLoop = preload("res://scripts/habitat/habitat_loop.gd")

const DELTA := 1.0 / 60.0


class FakeSupport extends RefCounted:
	func is_valid() -> bool:
		return true


class FakeSpider extends Node3D:
	enum State { ATTACHED, AIRBORNE }
	var state: int = State.ATTACHED
	var support := FakeSupport.new()
	var velocity := Vector3.ZERO
	var intent := Vector3.ZERO

	func get_intent() -> Vector3:
		return intent


class FakeLab extends Node3D:
	const RETREAT_ID := "sill_crevice"
	var inside := true
	var light := -1.0
	var light_hour := -1.0

	func in_retreat(_p: Vector3) -> bool:
		return inside

	func show_disturbance(_progress: float) -> void:
		pass

	func set_daylight(l: float, hour: float) -> void:
		light = l
		light_hour = hour


class FakePrey extends RefCounted:
	var held: Variant = null


class FakeFeeding extends RefCounted:
	var feeding := false


class FakeSensor extends RefCounted:
	var range_scale := 1.0


class FakeWorld extends Node3D:
	var lab: FakeLab
	var spider: FakeSpider
	var prey := FakePrey.new()
	var feeding := FakeFeeding.new()
	var needs := NeedsModel.new()
	var sensor := FakeSensor.new()
	var settings: Variant = null
	var checkpoints := 0

	func save_checkpoint() -> Dictionary:
		checkpoints += 1
		return {"ok": true, "message": "Checkpoint kept."}


func _out(x: Variant) -> Variant:
	if x is float:
		if is_inf(x):
			return "inf" if x > 0.0 else "-inf"
		if is_nan(x):
			return "nan"
	return x


func _clock_state(c: RefCounted) -> Dictionary:
	return {"day": c.day, "hour": c.hour, "sleeping": c.sleeping, "daylight": c.daylight(), "part": c.part_of_day(),
		"sleep_time": c.is_sleep_time(), "until_wake": c.hours_until(LifeClock.WAKE_H)}


func _clock() -> Dictionary:
	var out := {}
	# Daylight, words and sleep time over the whole day, every quarter hour and at the edges.
	var grid := []
	var hours: Array[float] = []
	for i in 96:
		hours.append(i * 0.25)
	for h: float in [5.999, 6.0, 6.001, 6.5, 7.0, 7.999, 8.0, 8.001, 9.0, 13.999, 17.999, 18.0, 18.001, 19.0, 19.001, 19.75, 20.0, 20.499, 20.5, 20.501, 23.999]:
		hours.append(h)
	for h: float in hours:
		var c := LifeClock.new()
		c.hour = h
		grid.append({"hour": h, "daylight": c.daylight(), "part": c.part_of_day(), "sleep_time": c.is_sleep_time(),
			"until_wake": c.hours_until(LifeClock.WAKE_H), "until_dusk": c.hours_until(LifeClock.DUSK_H)})
	out["grid"] = grid
	# Sequences of advance and advance_moult from set starts.
	var seqs := []
	var plans: Array = [
		{"day": 1, "hour": 9.0, "ops": [["a", 60.0, false], ["a", -1.0, false], ["a", "nan", false], ["a", "inf", false], ["a", 0.0, true], ["a", 900.0, false]]},
		{"day": 1, "hour": 23.9, "ops": [["a", 0.2 / LifeClock.ACTIVE_HOURS_PER_S, false]]},
		{"day": 4, "hour": 19.0, "ops": [["a", 2.0, true], ["a", 5.0, true], ["a", 1.0, false], ["a", 3.0, true], ["a", 30.0, true], ["a", 1.0, true]]},
		{"day": 2, "hour": 6.95, "ops": [["a", 0.5, true], ["a", 0.5, true]]},
		{"day": 2, "hour": 10.0, "ops": [["a", 2.0, true], ["a", 2.0, false]]},
		{"day": 3, "hour": 22.0, "ops": [["m", 4.0], ["m", 20.0], ["m", -2.0], ["a", 1.0, true]]},
		{"day": 1, "hour": 7.0, "ops": [["a", 0.1, true]]},
	]
	for plan: Dictionary in plans:
		var c := LifeClock.new()
		c.day = int(plan["day"])
		c.hour = float(plan["hour"])
		var steps := []
		for op: Array in plan["ops"]:
			var s: float = float(op[1]) if not (op[1] is String) else (NAN if op[1] == "nan" else INF)
			var h: float
			if op[0] == "m":
				h = c.advance_moult(s)
			else:
				h = c.advance(s, bool(op[2]))
			var st := _clock_state(c)
			st["op"] = op[0]
			st["seconds"] = _out(s)
			st["asleep"] = bool(op[2]) if op.size() > 2 else false
			st["hours"] = h
			steps.append(st)
		seqs.append({"day": plan["day"], "hour": plan["hour"], "steps": steps})
	out["sequences"] = seqs
	# A night of sleep tick by tick: the largest step, and where it stops.
	var night := LifeClock.new()
	night.hour = 19.0
	var largest := 0.0
	var ticks := 0
	var last := night.hour + 24.0 * night.day
	while ticks < 5000:
		night.advance(DELTA, true)
		ticks += 1
		var now := night.hour + 24.0 * night.day
		largest = maxf(largest, now - last)
		last = now
		if not night.sleeping:
			break
	out["night"] = {"ticks": ticks, "largest": largest, "day": night.day, "hour": night.hour, "sleeping": night.sleeping}
	# Record checks.
	var records := []
	for r: Variant in [
		{"day": 1, "hour": 9.0, "sleeping": false}, {"day": 3, "hour": 0.0, "sleeping": true}, {"day": 2.0, "hour": 23.99, "sleeping": false},
		{"day": 0, "hour": 9.0, "sleeping": false}, {"day": 1.5, "hour": 9.0, "sleeping": false}, {"day": 1, "hour": 24.0, "sleeping": false},
		{"day": 1, "hour": -0.1, "sleeping": false}, {"day": 1, "hour": 9.0, "sleeping": 1}, {"day": 1, "hour": 9.0}, {"hour": 9.0, "sleeping": false},
		{"day": 1, "hour": "9", "sleeping": false}, "not a record",
	]:
		var c := LifeClock.new()
		c.day = 5
		c.hour = 12.5
		var ok := c.load_dict(r) if typeof(r) == TYPE_DICTIONARY else false
		records.append({"record": r, "problems": Array(LifeClock.problems(r)), "loaded": ok, "day": c.day, "hour": c.hour, "sleeping": c.sleeping})
	out["records"] = records
	out["constants"] = {"wake": LifeClock.WAKE_H, "dawn": LifeClock.DAWN_H, "dusk": LifeClock.DUSK_H, "night": LifeClock.NIGHT_H,
		"evening": LifeClock.EVENING_H, "start_day": LifeClock.START_DAY, "start_hour": LifeClock.START_H,
		"active_rate": LifeClock.ACTIVE_HOURS_PER_S, "sleep_rate": LifeClock.SLEEP_HOURS_PER_S}
	return out


func _needs_state(n: RefCounted) -> Dictionary:
	var d: Dictionary = n.to_dict()
	return {"energy": n.energy, "rest": n.rest, "elapsed": n.elapsed_s, "granted_total": n.granted_total, "grants_made": n.grants_made,
		"grants_refused": n.grants_refused, "starving_hours": n.starving_hours, "streak": n.starving_streak_h, "starving": n.is_starving(),
		"full": n.is_full(), "room": n.room(), "acc": d["update_accumulator"], "hour_acc": d["hour_accumulator"]}


func _needs() -> Dictionary:
	var out := {}
	var seqs := []
	# op: ["adv", dt, active] | ["hrs", hours, asleep] | ["grant", amount, source] | ["rest", amount] | ["cfg", energy, rest]
	var plans: Array = [
		{"life": false, "gentle": false, "ops": [["adv", 0.25, false], ["adv", 0.25, false], ["adv", 0.5, true], ["adv", 0.1, true], ["adv", 0.1, false], ["adv", 0.3, true],
			["adv", -1.0, true], ["adv", "nan", true], ["adv", 10.0, false], ["hrs", 50.0, false], ["adv", 0.25, false], ["adv", 0.25, false]]},
		{"life": false, "gentle": false, "ops": [["cfg", 0.2005, 0.5], ["adv", 0.25, true], ["adv", 0.25, true], ["adv", 0.25, true], ["adv", 0.25, true]]},
		{"life": true, "gentle": false, "ops": [["cfg", 0.6, 1.0], ["hrs", 10.0, false], ["adv", 0.25, false], ["adv", 0.25, false], ["hrs", 10.0, true],
			["adv", 0.25, false], ["adv", 0.25, false], ["hrs", 100.0, false], ["adv", 0.25, false], ["adv", 0.25, false], ["grant", 0.35, "fly_1"],
			["hrs", 3.0, false], ["hrs", 2.0, true], ["adv", 0.2, true], ["adv", 0.2, true], ["adv", 0.2, true]]},
		{"life": true, "gentle": true, "ops": [["cfg", 0.3, 0.2], ["hrs", 100.0, false], ["adv", 0.25, false], ["adv", 0.25, false], ["hrs", 5.0, true],
			["adv", 0.25, false], ["adv", 0.25, false]]},
		{"life": true, "gentle": false, "ops": [["cfg", 0.1, 1.0], ["grant", 0.8, "a"], ["grant", 0.5, "b"], ["grant", 0.0, "c"], ["grant", -1.0, "c"],
			["grant", "nan", "c"], ["grant", 0.2, ""], ["cfg", 0.9, 0.0], ["grant", 0.05, "a"], ["rest", 0.3], ["rest", -0.3], ["rest", "inf"], ["rest", 2.0]]},
		{"life": false, "gentle": false, "ops": [["cfg", 2.0, -1.0], ["cfg", "nan", 0.4], ["cfg", 0.7, 0.4]]},
	]
	for plan: Dictionary in plans:
		var n := NeedsModel.new()
		n.life_mode = bool(plan["life"])
		n.gentle = bool(plan["gentle"])
		var steps := []
		for op: Array in plan["ops"]:
			var x: Variant = op[1]
			var v: float = float(x) if not (x is String) else (NAN if x == "nan" else INF)
			var ret: Variant = null
			match op[0]:
				"adv":
					n.advance(v, bool(op[2]))
				"hrs":
					n.add_hours(v, bool(op[2]))
				"grant":
					ret = n.grant_energy(v, str(op[2]))
				"rest":
					n.restore_rest(v)
				"cfg":
					var y: Variant = op[2]
					n.configure({"energy": v, "rest": float(y) if not (y is String) else NAN})
			var st := _needs_state(n)
			st["op"] = op[0]
			st["value"] = _out(v)
			st["flag"] = op[2] if op.size() > 2 else false
			st["returned"] = ret if ret != null else 0.0
			steps.append(st)
		seqs.append({"life": plan["life"], "gentle": plan["gentle"], "steps": steps})
	out["sequences"] = seqs
	# Many ticks at 60 Hz: the same time drains the same energy and rest in the same updates.
	var n2 := NeedsModel.new()
	var trace := []
	for i in 600:
		n2.advance(DELTA, (i / 45) % 2 == 0)
		if i % 30 == 29:
			trace.append(_needs_state(n2))
	out["ticks"] = trace
	# Record checks: a good record, then broken copies of it.
	var good_model := NeedsModel.new()
	good_model.life_mode = true
	good_model.configure({"energy": 0.4, "rest": 0.7})
	good_model.grant_energy(0.1, "fly_a")
	good_model.grant_energy(0.05, "fly_b")
	good_model.advance(0.2, true)
	good_model.add_hours(1.5, false)
	good_model.add_hours(0.5, true)
	var good: Dictionary = good_model.to_dict()
	var cases := []
	var variants := {
		"good": {},
		"energy_high": {"energy": 1.5}, "energy_text": {"energy": "0.4"}, "rest_negative": {"rest": -0.1}, "elapsed_negative": {"elapsed_s": -1.0},
		"acc_short": {"update_accumulator": [0.1]}, "acc_negative": {"update_accumulator": [0.1, -0.2]}, "ledger_off": {"granted_total": 0.3},
		"ledger_bad_value": {"granted_by_source": {"fly_a": -0.1, "fly_b": 0.25}}, "life_text": {"life_mode": "yes"},
		"hours_short": {"hour_accumulator": [1.0]}, "streak_negative": {"starving_streak_h": -2.0}, "starving_negative": {"starving_hours": -1.0},
	}
	for name: String in variants:
		var r: Dictionary = good.duplicate(true)
		# Nulls do not survive the trip to Luau: the placeholder needs are left out of the golden record.
		for k in ["hydration", "stress", "condition"]:
			r.erase(k)
		var change: Dictionary = variants[name]
		for k: String in change:
			r[k] = change[k]
		var m := NeedsModel.new()
		var ok: bool = m.load_dict(r)
		cases.append({"name": name, "record": r, "loaded": ok, "after": _needs_state(m), "life": m.life_mode})
	# An older record with no life fields loads (they were added later).
	var older: Dictionary = good.duplicate(true)
	for k in ["hydration", "stress", "condition", "life_mode", "starving_hours", "hour_accumulator", "starving_streak_h"]:
		older.erase(k)
	var m2 := NeedsModel.new()
	cases.append({"name": "older", "record": older, "loaded": m2.load_dict(older), "after": _needs_state(m2), "life": m2.life_mode})
	out["records"] = cases
	out["constants"] = {"max": NeedsModel.ENERGY_MAX, "start": NeedsModel.ENERGY_START, "drain": NeedsModel.ENERGY_DRAIN_PER_S,
		"floor": NeedsModel.ENERGY_FLOOR, "rest_start": NeedsModel.REST_START, "rest_drain": NeedsModel.REST_DRAIN_PER_S,
		"rest_recover": NeedsModel.REST_RECOVER_PER_S, "period": NeedsModel.UPDATE_PERIOD_S, "max_step": NeedsModel.MAX_STEP_S,
		"full_at": NeedsModel.FULL_AT, "awake_per_h": NeedsModel.LIFE_DRAIN_AWAKE_PER_H, "asleep_per_h": NeedsModel.LIFE_DRAIN_ASLEEP_PER_H,
		"gentle_drain": NeedsModel.GENTLE_DRAIN, "gentle_floor": NeedsModel.GENTLE_FLOOR}
	return out


## One scenario of the habitat loop: `script` lists phases {ticks, inside, moving, airborne, held, feeding, interact_at, cancel_at}.
func _loop(name: String, day: int, hour: float, energy: float, phases: Array) -> Dictionary:
	var world := FakeWorld.new()
	world.lab = FakeLab.new()
	world.spider = FakeSpider.new()
	world.add_child(world.lab)
	world.add_child(world.spider)
	world.needs.life_mode = true
	world.needs.configure({"energy": energy})
	root.add_child(world)
	var loop: Node = HabitatLoop.new()
	loop.world = world
	loop.clock.day = day
	loop.clock.hour = hour
	world.add_child(loop)  # _ready: the light of the starting hour
	loop.set_physics_process(false)
	var ticks := []
	var t := 0
	for phase: Dictionary in phases:
		world.lab.inside = bool(phase.get("inside", true))
		var moving := bool(phase.get("moving", false))
		world.spider.velocity = Vector3(0.5, 0.0, 0.0) if moving else Vector3.ZERO
		world.spider.intent = Vector3(1.0, 0.0, 0.0) if moving else Vector3.ZERO
		world.spider.state = FakeSpider.State.AIRBORNE if bool(phase.get("airborne", false)) else FakeSpider.State.ATTACHED
		world.prey.held = "fly" if bool(phase.get("held", false)) else null
		world.feeding.feeding = bool(phase.get("feeding", false))
		for i in int(phase["ticks"]):
			var interact := int(phase.get("interact_at", -1)) == i
			var cancel := int(phase.get("cancel_at", -1)) == i
			var active: bool = world.spider.state != FakeSpider.State.ATTACHED or moving
			world.needs.advance(DELTA, active)
			var before_notice: String = loop.notice
			loop.step(DELTA, interact, cancel)
			ticks.append({"t": t, "interact": interact, "cancel": cancel, "inside": world.lab.inside, "moving": moving,
				"airborne": world.spider.state != FakeSpider.State.ATTACHED, "held": world.prey.held != null, "feeding": world.feeding.feeding,
				"day": loop.clock.day, "hour": loop.clock.hour, "sleeping": loop.clock.sleeping, "asleep": loop.asleep, "resting": loop.resting,
				"rest_seconds": loop.rest_seconds, "energy": world.needs.energy, "rest": world.needs.rest, "range": world.sensor.range_scale,
				"light": world.lab.light, "light_hour": world.lab.light_hour, "checkpoints": world.checkpoints,
				"notice": loop.notice if loop.notice != before_notice or i == 0 else "", "notice_seconds": loop.notice_seconds,
				"can_rest": loop.can_rest()})
			t += 1
	var result := {"name": name, "day": day, "hour": hour, "energy": energy, "ticks": ticks}
	world.queue_free()
	return result


func _loops() -> Array:
	var night_ticks := int(ceil(12.0 / LifeClock.SLEEP_HOURS_PER_S / DELTA)) + 40
	return [
		_loop("evening_rest_sleeps_until_morning", 1, 19.0, 0.55, [{"ticks": night_ticks, "interact_at": 0}]),
		_loop("moving_wakes_before_morning", 1, 22.0, 0.55, [{"ticks": 30, "interact_at": 0}, {"ticks": 60, "moving": true}]),
		_loop("cancel_wakes_before_morning", 2, 2.0, 0.55, [{"ticks": 20, "interact_at": 0}, {"ticks": 20, "cancel_at": 0}, {"ticks": 10}]),
		_loop("second_press_ends_the_rest", 2, 1.0, 0.55, [{"ticks": 15, "interact_at": 0}, {"ticks": 15, "interact_at": 0}]),
		_loop("day_rest_passes_no_extra_time", 1, 10.0, 0.55, [{"ticks": 60, "interact_at": 0}, {"ticks": 10, "moving": true}]),
		_loop("a_day_rest_runs_into_the_evening", 1, 17.995, 0.55, [{"ticks": 60, "interact_at": 0}]),
		_loop("no_rest_outside_the_crack", 1, 21.0, 0.55, [{"ticks": 10, "inside": false, "interact_at": 0}]),
		_loop("no_rest_while_holding_prey", 1, 21.0, 0.55, [{"ticks": 10, "held": true, "interact_at": 0}]),
		_loop("no_rest_in_the_air", 1, 21.0, 0.55, [{"ticks": 10, "airborne": true, "interact_at": 0}]),
		_loop("no_rest_while_moving", 1, 21.0, 0.55, [{"ticks": 10, "moving": true, "interact_at": 0}]),
		_loop("leaving_the_crack_ends_the_rest", 1, 12.0, 0.55, [{"ticks": 10, "interact_at": 0}, {"ticks": 10, "inside": false}]),
		_loop("awake_through_dusk", 1, 18.9, 0.55, [{"ticks": 160, "moving": true}]),
		_loop("dawn_before_waking", 3, 5.9, 0.55, [{"ticks": 10, "interact_at": 0}]),
		_loop("hungry_spider_at_night", 2, 23.0, 0.02, [{"ticks": 240, "interact_at": 0}]),
	]


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var out := {"clock": _clock(), "needs": _needs(), "loops": _loops(), "night_sight": HabitatLoop.NIGHT_SIGHT, "dt": DELTA}
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "", true, true))
	f.close()
	print("wrote ", OS.get_cmdline_user_args()[0])
	quit()
