extends SceneTree
## Exports WASP golden values from the frozen Godot reference for roblox_port/tests/wasp_reference.json.
## Godot's own WaspDirector (scripts/predator/wasp_director.gd, with its real Wasp actor and WaspBody) runs on a stand-in world:
##   * physics: a floor (top at y = 0), and, in two scenarios, a low wall; the director's real sphere casts and rays query them.
##   * the stand-in spider is a Node3D with a velocity and a state (attached, airborne, falling) that a scripted "program" moves, tick by
##     tick, exactly as the Luau replay will; the program's segments end on a tick count, on the director's phase, or on the visit's end.
##   * the stand-in life loop gives the day, hour, rest and moult; the stand-in lab gives the retreat (the crack's box).
## What is recorded: the constants and the 15 places, `blocked()` for a grid of inputs, the record checks, then per scenario the events
## the director logged, the phase and search step at every change, a sample of the whole state every 12 ticks, and the random draws.
## The draws: Godot's RandomNumberGenerator cannot be reproduced in Luau, so each draw the director made is read back from the state it
## left (the hover time, the land chance as under or over a half, the walk direction as an angle, the pick as an index into the nearer half
## of the places) and the Luau replay is fed exactly those, in the order the director asked for them.
## Run from the repo root:
##   godot --headless --path . -s roblox_port/tools/export_wasp_reference.gd -- roblox_port/tests/wasp_reference.json
## then, from roblox_port/:  python3 tools/reference_to_luau.py tests/wasp_reference.json
const WaspDirector = preload("res://scripts/predator/wasp_director.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")

## Not 1/60: Godot keeps its vectors in single precision, and every duration here (8 s, 0.6 s, 5 s) is a whole number of 1/60 s ticks, so a
## path would end on one tick in Godot and the next in Luau by rounding alone. This step puts every duration well between two ticks.
const DT := 0.0173
const WALK := 2.5
const SAMPLE_EVERY := 12
## The crack the stand-in lab calls the retreat (Windowsill.RETREAT_AREA, in world space: the sill sits at the origin).
const RETREAT := AABB(Vector3(-27.8, 0.0, 3.0), Vector3(4.5, 1.5, 6.0))


class FakeLoopClock extends RefCounted:
	var day := 2
	var hour := 12.0


class FakeGrowth extends RefCounted:
	var moulting := false

	func is_moulting() -> bool:
		return moulting


class FakeLoop extends Node:
	var clock := FakeLoopClock.new()
	var resting := false
	var growth := FakeGrowth.new()


class FakeFeeding extends RefCounted:
	var meals_finished := 1


class FakeLab extends RefCounted:
	func in_retreat(p: Vector3) -> bool:
		return RETREAT.has_point(p)


class FakeVibration extends Node:
	var shakes: Array[Dictionary] = []

	func shake(at: Vector3, kind: String, _who: Node) -> Dictionary:
		shakes.append({"kind": kind, "at": [at.x, at.y, at.z]})
		return {}


class FakeSpider extends Node3D:
	enum State { ATTACHED, AIRBORNE, FALLING }
	var state: int = State.ATTACHED
	var velocity := Vector3.ZERO
	var seized := false
	var _walk_speed := 2.5

	func is_airborne() -> bool:
		return state == State.AIRBORNE

	func seize() -> void:
		seized = true
		state = State.FALLING


class FakeWorld extends Node3D:
	var habitat_loop := FakeLoop.new()
	var feeding := FakeFeeding.new()
	var lab := FakeLab.new()
	var vibration := FakeVibration.new()
	var spider: FakeSpider


func _v(x: Vector3) -> Array:
	return [x.x, x.y, x.z]


func _out(x: Variant) -> Variant:
	if x is float:
		if is_inf(x):
			return "inf" if x > 0.0 else "-inf"
		if is_nan(x):
			return "nan"
	return x


func _box(world: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	world.add_child(body)


func _make_world(wall: bool) -> FakeWorld:
	var world := FakeWorld.new()
	var spider := FakeSpider.new()
	spider._walk_speed = WALK
	world.spider = spider
	world.add_child(spider)
	_box(world, Vector3(0.0, -1.0, 0.0), Vector3(120.0, 2.0, 60.0))   # the floor: top at y = 0
	if wall:
		_box(world, Vector3(3.2, 1.25, 0.0), Vector3(0.4, 2.5, 40.0))   # a low wall across the floor, x 3.0 to 3.4, up to 2.5
	root.add_child(world)
	return world


## One scenario. `program`: segments {"pos"?, "state"?, "axis"? (pace along it), "flip"? (ticks per direction), "speed"? (times walk),
## "until": {"ticks": n} | {"phase": name} | {"away": true}}. The last segment ends the run, or `max_ticks` does.
func _scenario(name: String, point: String, wall: bool, program: Array, max_ticks: int) -> Dictionary:
	var world := _make_world(wall)
	await physics_frame
	await physics_frame
	var wd: Node = WaspDirector.new()
	wd.world = world
	wd.seed_value = 1234
	wd.enabled = false
	world.add_child(wd)
	wd.set_physics_process(false)
	var spider := world.spider
	var out_events := []
	var phases := []
	var samples := []
	var draws := []
	var held_log := []
	spider.global_position = Vector3(2.0, 0.31, 6.0)
	wd.force_visit(point)
	var seg_i := 0
	var seg_tick := 0
	var tick := 0
	var last_phase := -1
	var last_sub := ""
	var prev_point: int = wd._point
	var prev_phase: int = wd.phase
	var prev_sub: String = wd._sub
	while tick < max_ticks:
		# The spider's program, as the Luau replay runs it: the segment ends first if its condition holds, then the spider moves.
		while seg_i < program.size():
			var seg: Dictionary = program[seg_i]
			var u: Dictionary = seg["until"]
			var done := false
			if u.has("ticks"):
				done = seg_tick >= int(u["ticks"])
			elif u.has("phase"):
				done = wd.phase_name() == str(u["phase"])
			elif u.has("away"):
				done = not wd.is_visiting()
			if not done:
				break
			seg_i += 1
			seg_tick = 0
		if seg_i >= program.size():
			break
		var seg: Dictionary = program[seg_i]
		if seg_tick == 0:
			if seg.has("pos"):
				var p: Array = seg["pos"]
				spider.global_position = Vector3(p[0], p[1], p[2])
			spider.state = FakeSpider.State.ATTACHED
			if seg.has("state"):
				spider.state = {"attached": FakeSpider.State.ATTACHED, "airborne": FakeSpider.State.AIRBORNE, "falling": FakeSpider.State.FALLING}[seg["state"]]
		if not spider.seized:
			var vel := Vector3.ZERO
			if seg.has("axis"):
				var a: Array = seg["axis"]
				var flip := int(seg.get("flip", 30))
				var sign := 1.0 if (seg_tick / flip) % 2 == 0 else -1.0
				vel = Vector3(a[0], a[1], a[2]) * sign * WALK * float(seg.get("speed", 1.0))
			spider.velocity = vel
			spider.global_position += vel * DT
		seg_tick += 1
		wd.step(DT)
		tick += 1
		var t := tick * DT
		# The draws this tick made, read back from the state they left.
		if wd._point != prev_point or (prev_phase == WaspDirector.Phase.ARRIVING and wd.phase == WaspDirector.Phase.SEARCHING) or wd._sub != prev_sub:
			if (prev_phase == WaspDirector.Phase.INSPECTING or prev_phase == WaspDirector.Phase.STRIKING) and wd.phase == WaspDirector.Phase.SEARCHING:
				draws.append({"kind": "pick", "value": _near_rank(wd), "at": t})   # _lose: the place it searches next
			elif prev_phase == WaspDirector.Phase.ARRIVING and wd.phase == WaspDirector.Phase.SEARCHING:
				draws.append({"kind": "hover", "value": wd._sub_s, "at": t})
			elif prev_sub == "fly" and wd._sub == "hover":
				draws.append({"kind": "hover", "value": wd._sub_s, "at": t})
			elif prev_sub == "land" and wd._sub == "walk":
				var d: Vector3 = wd._walk_dir
				draws.append({"kind": "angle", "value": fposmod(atan2(-d.x, -d.z), TAU), "at": t})
			elif prev_sub == "hover" and wd._sub != "hover":
				if WaspDirector.POINTS[prev_point].has("land"):
					draws.append({"kind": "chance", "value": 0.0 if wd._sub == "land" else 0.99, "at": t})
				if wd._sub == "fly":
					draws.append({"kind": "pick", "value": _near_rank(wd), "at": t})
			elif prev_sub == "takeoff" and wd._sub == "fly":
				draws.append({"kind": "pick", "value": _near_rank(wd), "at": t})
		prev_point = wd._point
		prev_phase = wd.phase
		prev_sub = wd._sub
		if wd.phase != last_phase or (wd.phase == WaspDirector.Phase.SEARCHING and wd._sub != last_sub):
			phases.append({"tick": tick, "phase": wd.phase_name(), "sub": wd._sub if wd.phase == WaspDirector.Phase.SEARCHING else ""})
			last_phase = wd.phase
			last_sub = wd._sub
		if tick % SAMPLE_EVERY == 0:
			samples.append({"tick": tick, "phase": wd.phase_name(), "sub": wd._sub, "pos": _v(wd.wasp.global_position), "heading": _v(wd.wasp.heading),
				"mode": wd.wasp.mode, "search": wd.wasp.search, "visible": wd.wasp.visible, "notice": wd.notice, "confused": wd.confused_s,
				"search_left": wd.search_left, "point": WaspDirector.POINTS[wd._point]["id"], "sees": wd.can_see_spider() if wd.phase != WaspDirector.Phase.AWAY else false,
				"spider": _v(spider.global_position), "seized": spider.seized, "velocity": _v(wd.wasp.velocity)})
		if wd.phase == WaspDirector.Phase.AWAY and wd.visit_s > 0.0:
			break
	for e: Dictionary in wd.events:
		out_events.append({"kind": e["kind"], "t": e["t"]})
	var res := {"name": name, "point": point, "wall": wall, "program": program, "max_ticks": max_ticks, "ticks": tick, "events": out_events,
		"phases": phases, "samples": samples, "draws": draws, "shakes": world.vibration.shakes, "visits": wd.visits, "escapes": wd.escapes,
		"last_visit_day": wd.last_visit_day, "noticed": wd.noticed_this_visit, "seized": spider.seized, "record": wd.to_dict(), "visit_s": wd.visit_s}
	world.queue_free()
	await physics_frame
	return res


## The index, in the nearer half of the places the director may choose from, of the place it chose (the director's own filter and sort,
## read from the state it left: `_recent` already holds the place it came from).
func _near_rank(wd: Node) -> int:
	var here: Vector3 = wd.wasp.global_position
	var choices: Array[int] = []
	for i in WaspDirector.POINTS.size():
		if wd._recent.has(i):
			continue
		var hover: Vector3 = WaspDirector.POINTS[i]["hover"]
		if wd._loss_pos.is_finite() and hover.distance_to(wd._loss_pos) < WaspDirector.FAR_FROM_LOSS_WU:
			continue
		choices.append(i)
	if choices.is_empty():
		choices.append((wd._recent[wd._recent.size() - 1] + 1) % WaspDirector.POINTS.size())
	choices.sort_custom(func(a: int, b: int) -> bool:
		return here.distance_to(WaspDirector.POINTS[a]["hover"]) < here.distance_to(WaspDirector.POINTS[b]["hover"]))
	var near := choices.slice(0, maxi(1, (choices.size() + 1) / 2))
	return near.find(wd._point)


func _constants() -> Dictionary:
	var pts := []
	for p: Dictionary in WaspDirector.POINTS:
		var row := {"id": p["id"], "hover": _v(p["hover"])}
		if p.has("land"):
			row["land"] = _v(p["land"])
		pts.append(row)
	return {"first_day": WaspDirector.FIRST_DAY, "visit_chance": WaspDirector.VISIT_CHANCE, "window_from": WaspDirector.WINDOW_FROM_H,
		"window_to": WaspDirector.WINDOW_TO_H, "arrive_s": WaspDirector.ARRIVE_S, "search_s": WaspDirector.SEARCH_S, "leave_s": WaspDirector.LEAVE_S,
		"carry_s": WaspDirector.CARRY_S, "cruise_y": WaspDirector.CRUISE_Y, "entry": _v(WaspDirector.ENTRY), "over": _v(WaspDirector.OVER),
		"fly_speed": WaspDirector.FLY_SPEED, "radius": WaspDirector.RADIUS, "hover_s": [WaspDirector.HOVER_S.x, WaspDirector.HOVER_S.y],
		"scan_deg_s": WaspDirector.SCAN_DEG_S, "land_chance": WaspDirector.LAND_CHANCE, "land_s": WaspDirector.LAND_S, "walk_s": WaspDirector.WALK_S,
		"walk_speed": WaspDirector.WALK_SPEED, "step_every_s": WaspDirector.STEP_EVERY_S, "sight_wu": WaspDirector.SIGHT_WU,
		"notice_still": WaspDirector.NOTICE_STILL, "notice_moving": WaspDirector.NOTICE_MOVING, "notice_decay": WaspDirector.NOTICE_DECAY,
		"confuse_s": WaspDirector.CONFUSE_S, "after_loss_notice": WaspDirector.AFTER_LOSS_NOTICE, "lose_unseen_s": WaspDirector.LOSE_UNSEEN_S,
		"far_from_loss_wu": WaspDirector.FAR_FROM_LOSS_WU, "standoff_wu": WaspDirector.STANDOFF_WU, "inspect_speed": WaspDirector.INSPECT_SPEED,
		"inspect_s": WaspDirector.INSPECT_S, "inspect_give_up_s": WaspDirector.INSPECT_GIVE_UP_S, "strike_s": WaspDirector.STRIKE_S,
		"catch_wu": WaspDirector.CATCH_WU, "hold_below": WaspDirector.HOLD_BELOW, "eye_ahead": 1.0, "sensed_radius": 0.9, "points": pts}


func _blocked_grid() -> Array:
	var world := _make_world(false)
	var wd: Node = WaspDirector.new()
	wd.world = world
	world.add_child(wd)
	wd.set_physics_process(false)
	var rows := []
	for day in [1, 2, 5]:
		for meals in [0, 1, 3]:
			for resting in [false, true]:
				for moulting in [false, true]:
					world.habitat_loop.clock.day = day
					world.feeding.meals_finished = meals
					world.habitat_loop.resting = resting
					world.habitat_loop.growth.moulting = moulting
					rows.append({"day": day, "meals": meals, "resting": resting, "moulting": moulting, "blocked": wd.blocked()})
	world.queue_free()
	return rows


func _records() -> Array:
	var rows := []
	for r: Variant in [
		{"last_visit_day": 0, "visits": 0, "escapes": 0}, {"last_visit_day": 4, "visits": 3, "escapes": 2}, {"last_visit_day": -1, "visits": 0, "escapes": 0},
		{"last_visit_day": 2, "visits": 1, "escapes": 2}, {"last_visit_day": 2, "visits": 1.5, "escapes": 0}, {"last_visit_day": 2, "visits": 1},
		{"last_visit_day": "2", "visits": 1, "escapes": 0}, "not a record", {"last_visit_day": 3.0, "visits": 3.0, "escapes": 3.0},
	]:
		rows.append({"record": r, "problems": Array(WaspDirector.problems(r))})
	return rows


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var pace_x := {"axis": [1.0, 0.0, 0.0], "flip": 30}
	var scenarios := []
	var open := [2.0, 0.31, 6.0]
	var crack := [-25.0, 0.31, 6.0]
	# 1. Nobody out in the open: the crack. The whole visit: arrive, search (hover, land, walk, take off), give up, leave.
	scenarios.append(await _scenario("empty_crack_whole_visit", "crack_mouth", false, [{"pos": crack, "until": {"away": true}}], 60 * 90))
	# 2. A moving spider in the open is found, looked at, caught and carried off.
	var seg_pace := {"pos": open, "axis": [1.0, 0.0, 0.0], "flip": 30, "until": {"phase": "inspecting"}}
	scenarios.append(await _scenario("moving_found_looked_at_caught", "floor_middle", false,
		[seg_pace, {"until": {"away": true}}], 60 * 60))
	# 3. A still spider in the open.
	scenarios.append(await _scenario("still_in_the_open", "floor_middle", false, [{"pos": open, "until": {"away": true}}], 60 * 90))
	# 4. A jump breaks the approach.
	scenarios.append(await _scenario("jump_breaks_the_approach", "floor_middle", false,
		[seg_pace, {"until": {"ticks": 4}}, {"state": "airborne", "until": {"ticks": 12}}, {"state": "attached", "until": {"away": true}}], 60 * 90))
	# 5. A drop on the line breaks it.
	scenarios.append(await _scenario("drop_breaks_the_approach", "floor_middle", false,
		[seg_pace, {"until": {"ticks": 4}}, {"state": "falling", "until": {"ticks": 40}}, {"state": "attached", "until": {"away": true}}], 60 * 90))
	# 6. The spider hides behind a wall while it is being looked at: out of sight.
	scenarios.append(await _scenario("out_of_sight_behind_a_wall", "floor_middle", true,
		[seg_pace, {"until": {"ticks": 4}}, {"pos": [5.0, 0.31, 6.0], "until": {"ticks": 80}}, {"pos": [2.0, 0.31, 6.0], "until": {"away": true}}], 60 * 90))
	# 7. It is somewhere else by the time the lunge lands: missed.
	scenarios.append(await _scenario("gone_by_the_end_of_the_lunge_is_missed", "floor_middle", false,
		[seg_pace, {"until": {"phase": "striking"}}, {"pos": [2.0, 0.31, 9.5], "until": {"ticks": 30}}, {"until": {"away": true}}], 60 * 90))
	# 8. Into the crack while being looked at: it loses sight of it (the retreat).
	scenarios.append(await _scenario("hides_in_the_crack_while_looked_at", "floor_west", false,
		[{"pos": [-13.0, 0.31, 6.0], "axis": [1.0, 0.0, 0.0], "flip": 30, "until": {"phase": "inspecting"}},
			{"until": {"ticks": 4}}, {"pos": crack, "until": {"ticks": 30}}, {"until": {"away": true}}], 60 * 90))
	var out := {"constants": _constants(), "blocked": _blocked_grid(), "records": _records(), "scenarios": scenarios, "dt": DT, "walk": WALK,
		"retreat": [RETREAT.position.x, RETREAT.position.y, RETREAT.position.z, RETREAT.end.x, RETREAT.end.y, RETREAT.end.z]}
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "", true, true))
	f.close()
	print("wrote ", OS.get_cmdline_user_args()[0])
	for s: Dictionary in scenarios:
		var kinds := []
		for e: Dictionary in s["events"]:
			kinds.append("%s@%.2f" % [e["kind"], e["t"]])
		print(s["name"], ": ", s["ticks"], " ticks; ", ", ".join(kinds))
	quit()
