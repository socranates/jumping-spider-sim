extends "res://tests/prey_test_case.gd"
## Chunk 7B, milestone 10, the population: a fly that is lost is replaced after a delay by one that comes in through a wall vent that
## nobody can see, and flies in (PreyPopulation, the P0 rule). The wait is shortened in most of these tests (it is data: 25 to 45 s in the
## profile; one test reads the shipped numbers without waiting them out). The spider stands in the north-west corner (-24, -12), from where
## three of the four vents are out of its sight (the east one is 54 WU away). The camera the population is told about is a stand-in that looks
## where the test says (the real one follows the spider and cannot be pointed at a wall vent from the floor); the engine's own frustum test
## and a ray are the independent checks that nothing came in view or in sight.

const PreyDebug = preload("res://scripts/presentation/prey_debug.gd")
const Perceivable = preload("res://scripts/perception/perceivable.gd")

const SHORT_WAIT := Vector2(0.6, 0.9)


class StubRig extends Node:
	var camera: Camera3D


var rig: StubRig
## What was true at the moment each replacement appeared (the director announces it in the tick it comes in).
var spawned: Array[Dictionary] = []
var _watch: Array[Dictionary] = []


func _world(count: int, seed_value: int, wait: Vector2 = SHORT_WAIT, pose: Variant = null) -> void:
	prey_replenish = true
	await spawn_prey_world(pose if pose != null else floor_pose(-24.0, -12.0, 0.0), count, seed_value)
	director().profile.replenish_delay_s = wait
	rig = StubRig.new()
	rig.camera = Camera3D.new()
	rig.camera.fov = 65.0
	rig.add_child(rig.camera)
	sandbox.add_child(rig)
	director().camera_rig = rig
	spawned.clear()
	_watch.clear()
	director().fly_spawned.connect(_on_spawned)
	_look_down()


func _on_spawned(f: Node3D) -> void:
	var d := director()
	if f.perch == null or not _is_vent(f.perch.id):
		return
	spawned.append({"fly": f.id, "vent": f.perch.id, "at": f.global_position, "state": f.state_name(), "t": d.now, "tick": d.tick,
		"in_frustum": rig.camera.is_position_in_frustum(f.global_position), "spider_could_sense": _spider_could_sense(f.global_position),
		"spider_distance": f.global_position.distance_to(world.spider.global_position), "reason": str(f.goal_reason)})


func _is_vent(perch_id: String) -> bool:
	for v: PerchGraph.Perch in director().population.vents:
		if v.id == perch_id:
			return true
	return false


func _vent(vent_id: String) -> PerchGraph.Perch:
	for v: PerchGraph.Perch in director().population.vents:
		if v.id == vent_id:
			return v
	return null


func _eye() -> Vector3:
	return world.spider.get_eye_position()


func _look_at(point: Vector3) -> void:
	rig.camera.look_at_from_position(_eye(), point, Vector3.UP)


func _look_down() -> void:
	rig.camera.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), _eye())


func _only_vents(ids: Array) -> void:
	var keep: Array[PerchGraph.Perch] = []
	for v: PerchGraph.Perch in director().population.vents:
		if ids.has(v.id):
			keep.append(v)
	director().population.vents = keep


## The question asked again in the test's own words: within the sensor's range, inside the field of the eyes, and any of the five sample
## points of the body (the centre and four around it) with nothing of the world between.
func _spider_could_sense(point: Vector3) -> bool:
	var spider: Node3D = world.spider
	var eye: Vector3 = spider.get_eye_position()
	var to := point - eye
	if to.length() > world.sensor.range_wu:
		return false
	if spider.get_gaze_direction().angle_to(to.normalized()) > deg_to_rad(world.sensor.peripheral_cone_deg) * 0.5:
		return false
	var d := to.normalized()
	var side := d.cross(Vector3.UP).normalized()
	var vert := side.cross(d).normalized()
	var r: float = director().profile.radius_wu * 0.8
	for p: Vector3 in [point, point + side * r, point - side * r, point + vert * r, point - vert * r]:
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, p, 1))
		if hit.is_empty() or eye.distance_to(hit["position"] as Vector3) >= eye.distance_to(p) - 0.06:
			return true
	return false


func _lose(f: Node3D) -> void:
	f.mark_captured("spider", "capture:spider:%s" % f.id)


func test_a_lost_fly_is_replaced_after_a_delay_by_one_that_flies_in() -> void:
	await _world(2, 31)
	var d := director()
	check_eq(d.flies.size(), 2, "two flies to begin with")
	check(d.population.enabled and d.population.target == 2, "the population is on and wants two")
	check_eq(d.population.vents.size(), 4, "four authored vents")
	check_eq(int(d.vent_validation["valid"]), 4, "and the world accepted all four (%s)" % str(d.vent_validation["refused"]))
	_lose(d.flies[0])
	await physics_frames(2)
	check_eq(d.population.pending.size(), 1, "one replacement is waited for")
	check_eq(d.population.free_count(), 1, "a fly in the jaws is not part of the room")
	var rec: Dictionary = d.population.pending[0]
	check(float(rec["delay"]) >= SHORT_WAIT.x and float(rec["delay"]) <= SHORT_WAIT.y, "after a delay drawn from the profile's range (%.2f s)" % float(rec["delay"]))
	check_near(float(rec["due"]), float(rec["lost"]) + float(rec["delay"]), 1.0e-9, "due = when the loss was noticed + the delay")
	await run_ticks(maxi(1, int((float(rec["delay"]) - 0.15) * 60.0)))
	check_eq(d.population.entries_total, 0, "nothing comes in before it is due")
	check(await wait_until(func() -> bool: return d.population.entries_total == 1, 60 * 6), "then one comes in")
	var h: Dictionary = d.population.history[0]
	check(float(h["waited_s"]) >= -0.02 and float(h["waited_s"]) <= 1.6, "within a couple of asks of being due (%.2f s late)" % float(h["waited_s"]))
	check_eq(spawned.size(), 1, "its arrival was announced once")
	var s: Dictionary = spawned[0]
	check_eq(str(s["vent"]), str(h["vent"]), "the announcement and the history agree on the vent")
	check_vec_near(s["at"], _vent(str(h["vent"])).rest_point(d.profile.hover_wu), 1.0e-3, "it appeared on the vent, nowhere else")
	check_eq(str(s["state"]), "REPOSITION", "and was flying from the first tick")
	check(not bool(s["in_frustum"]), "not in the picture (the engine's frustum test)")
	check(not bool(s["spider_could_sense"]), "and not where the spider could have sensed it")
	check(float(s["spider_distance"]) >= d.profile.vent_min_distance_wu, "and not close (%.1f WU)" % float(s["spider_distance"]))
	var f: Node3D = d.fly_by_id(str(h["fly"]))
	check(f != null and f.is_alive(), "the new fly lives")
	check_eq(d.population.free_count(), 2, "so the room has its two again")
	var first: Dictionary = f.trace[0]
	check(str(first["reason"]).contains("replacement") and str(first["reason"]).contains(str(h["vent"])), "its first line says why it is there: %s" % str(first["reason"]).substr(0, 110))
	check(await wait_until(func() -> bool: return f.state == Fly.State.PERCHED and f.flight.landings_total >= 1, 60 * 20), "it lands")
	check_eq(f.perch.id, str(h["target"]), "on the perch the population planned for it")
	check(f.flight.max_step <= f.profile.cruise_speed_wu_s / 60.0 * 1.05 + 1.0e-6, "never moving more than its speed in a tick (%.3f WU): it flew in" % f.flight.max_step)
	check(float(h["flight_wu"]) >= d.profile.entry_min_flight_wu, "a real flight (%.1f WU)" % float(h["flight_wu"]))
	await run_ticks(90)
	check_eq(d.population.entries_total, 1, "and no second one comes: the room is full")


func test_the_same_seed_brings_the_same_replacement_and_another_seed_another() -> void:
	var runs: Array[Dictionary] = []
	for seed_value in [31, 31, 32]:
		await _world(2, seed_value)
		var d := director()
		_lose(d.flies[0])
		await wait_until(func() -> bool: return d.population.entries_total == 1, 60 * 8)
		var h: Dictionary = d.population.history[0].duplicate()
		runs.append(h)
		rig.queue_free()
		world.queue_free()
		await physics_frames(2)
	check_eq(runs.size(), 3, "three runs")
	if runs.size() == 3:
		check(is_equal_approx(float(runs[0]["due"]), float(runs[1]["due"])) and runs[0]["vent"] == runs[1]["vent"] and runs[0]["target"] == runs[1]["target"] and is_equal_approx(float(runs[0]["t"]), float(runs[1]["t"])),
			"the same seed: the same delay, vent, perch and moment")
		check(not is_equal_approx(float(runs[0]["due"]), float(runs[2]["due"])) or runs[0]["vent"] != runs[2]["vent"] or runs[0]["target"] != runs[2]["target"],
			"another seed: something differs")


func test_nothing_comes_in_while_the_only_open_vent_is_in_view_and_it_waits_for_a_quiet_half_second() -> void:
	await _world(2, 33)
	var d := director()
	_only_vents(["vent_east"])
	var vent: PerchGraph.Perch = d.population.vents[0]
	var at: Vector3 = vent.rest_point(d.profile.hover_wu)
	_look_at(at)
	check(rig.camera.is_position_in_frustum(at), "the camera looks straight at the vent (the engine's frustum agrees)")
	check_eq(d.population.blocker(vent, d.now), "in_camera_view", "so the vent cannot be used")
	_lose(d.flies[0])
	await run_ticks(60 * 3)
	check_eq(d.population.entries_total, 0, "three seconds in view, past the due time: nothing came in")
	check(d.population.asks_total >= 4 and d.population.deferred_total == d.population.asks_total, "it asked about every half second and was told to wait each time (%d asks)" % d.population.asks_total)
	check_eq(str(d.population.last_blockers["vent_east"]), "in_camera_view", "and the reason is on record")
	_look_down()
	var t_turn: float = d.now
	check(await wait_until(func() -> bool: return d.population.entries_total == 1, 60 * 3), "it comes in once the camera has turned away")
	var dt: float = float(d.population.history[0]["t"]) - t_turn
	check(dt >= d.profile.replenish_retry_s - 0.02, "but not at the first look that finds the vent clear (%.2f s after the turn)" % dt)
	check(dt <= 2.0 * d.profile.replenish_retry_s + 0.1, "only at the second (%.2f s)" % dt)
	check_eq(spawned.size(), 1, "announced once")
	check(not bool(spawned[0]["in_frustum"]), "out of the picture when it appeared")


func test_the_margin_keeps_a_vent_just_outside_the_picture_from_being_used() -> void:
	await _world(2, 34)
	var d := director()
	var vent: PerchGraph.Perch = _vent("vent_east")
	var at: Vector3 = vent.rest_point(d.profile.hover_wu)
	# turn the camera until the vent sits about 6 degrees outside the vertical edge of the picture, inside the 12 degree margin
	var half_v := 65.0 * 0.5
	_look_at(at)
	var to_vent: Vector3 = (at - _eye()).normalized()
	var pitched: Vector3 = to_vent.rotated(to_vent.cross(Vector3.UP).normalized(), deg_to_rad(half_v + 6.0)).normalized()
	rig.camera.look_at_from_position(_eye(), _eye() + pitched * 10.0, Vector3.UP)
	check(not rig.camera.is_position_in_frustum(at), "the vent is just outside the engine's frustum")
	check(d.population.in_camera_view(vent), "but inside the margin the rule keeps around it")
	check_eq(d.population.blocker(vent, d.now), "in_camera_view", "so it is still not used")
	var beyond: Vector3 = to_vent.rotated(to_vent.cross(Vector3.UP).normalized(), deg_to_rad(half_v + 30.0)).normalized()
	rig.camera.look_at_from_position(_eye(), _eye() + beyond * 10.0, Vector3.UP)
	check(not d.population.in_camera_view(vent), "well outside, it may be used")


func test_over_many_entries_not_one_comes_in_view_or_in_sight() -> void:
	await _world(3, 35, Vector2(0.4, 0.6))
	var d := director()
	d.population.vent_rest_s = 1.0   # a vent rests a second here (6 s in play), so that a dozen entries fit in twelve seconds
	var sweep: Array = [0.0]
	for f: Node3D in d.flies.duplicate():
		_lose(f)
	await run_ticks(60 * 12, func() -> void:
		sweep[0] = float(sweep[0]) + deg_to_rad(70.0) / 60.0
		rig.camera.global_transform = Transform3D(Basis(Vector3.UP, float(sweep[0])) * Basis(Vector3.RIGHT, deg_to_rad(25.0)), _eye())
		# every entry is watched for its first ticks, then taken (so the room keeps losing flies and the replacements keep coming)
		for s in spawned:
			if not s.has("watched") and d.tick - int(s["tick"]) == 1:
				s["watched"] = true
				_watch.append({"fly": str(s["fly"]), "until": d.tick + 6, "seen": false})
		for w in _watch:
			if d.tick <= int(w["until"]) and world.sensor.track_id_for(str(w["fly"])) != "":
				w["seen"] = true
			if d.tick == int(w["until"]) + 1:
				var fly: Node3D = d.fly_by_id(str(w["fly"]))
				if fly != null and fly.is_alive():
					_lose(fly)
	)
	check(spawned.size() >= 6, "a good number of replacements came in (%d)" % spawned.size())
	check(d.population.deferred_total >= 1, "and some asks were turned away (%d of %d)" % [d.population.deferred_total, d.population.asks_total])
	var in_view := 0
	var sensed := 0
	var near := 0
	for s in spawned:
		in_view += 1 if bool(s["in_frustum"]) else 0
		sensed += 1 if bool(s["spider_could_sense"]) else 0
		near += 1 if float(s["spider_distance"]) < d.profile.vent_min_distance_wu else 0
	check_eq(in_view, 0, "none appeared in the camera's picture (engine frustum test at the moment it came in)")
	check_eq(sensed, 0, "none appeared where the spider could sense it (range, field of the eyes, a ray)")
	check_eq(near, 0, "none appeared within %.0f WU of the spider" % d.profile.vent_min_distance_wu)
	var noticed := 0
	for w in _watch:
		noticed += 1 if bool(w["seen"]) else 0
	check_eq(noticed, 0, "and the spider's own memory had no contact for any of them in their first ticks")
	var used := {}
	for h in d.population.history:
		used[str(h["vent"])] = true
	check(used.size() >= 2, "more than one vent was used (%s)" % ", ".join(PackedStringArray(used.keys())))


func test_a_vent_the_world_refuses_is_never_used() -> void:
	await _world(2, 36)
	var d := director()
	world.lab.add_fixture_piece("vent_plug", "ledge", Vector3(-21.0, 8.5, -17.45), Vector3(-19.0, 10.5, -15.5))
	await physics_frames(3)
	var res: Dictionary = d.population.validate(world.get_world_3d().direct_space_state)
	check_eq(int(res["valid"]), 3, "three of the four are left")
	check_eq(str((res["refused"] as Dictionary).get("vent_north", "")), "blocked_at_rest", "the plugged one is refused for the right reason")
	var authored: Array[Dictionary] = world.lab.get_prey_vents()
	d.population.set_vents([{"id": "vent_air", "position": Vector3(0.0, 6.0, 0.0), "normal": Vector3.BACK}, authored[0]])
	res = d.population.validate(world.get_world_3d().direct_space_state)
	check_eq(int(res["valid"]), 0, "a vent in mid-air and the plugged one: none is usable")
	check_eq(str((res["refused"] as Dictionary).get("vent_air", "")), "no_surface", "the one in the air has no wall behind it")
	_lose(d.flies[0])
	await run_ticks(60 * 3)
	check_eq(d.population.entries_total, 0, "three seconds past the due time and nothing comes in")
	check(d.population.deferred_total >= 3, "it kept asking (%d asks)" % d.population.asks_total)
	var all_refused := true
	for k: String in d.population.last_blockers:
		all_refused = all_refused and str(d.population.last_blockers[k]) == "refused"
	check(all_refused, "and every vent was refused: %s" % str(d.population.last_blockers))
	d.population.set_vents(authored)
	res = d.population.validate(world.get_world_3d().direct_space_state)
	check_eq(int(res["valid"]), 3, "with the authored vents back, the three good ones work")
	check(await wait_until(func() -> bool: return d.population.entries_total == 1, 60 * 6), "and a fly comes in")
	check(str(d.population.history[0]["vent"]) != "vent_north", "not through the plugged one")


func test_three_and_four_flies_each_have_a_perch_of_their_own() -> void:
	for n in [3, 4]:
		await spawn_prey_world(floor_pose(0.0, 0.0, 0.0), n, 40 + n)
		var d := director()
		check_eq(d.flies.size(), n, "%d flies begin" % n)
		var clash := [0]
		var unique := {}
		await run_ticks(150, func() -> void:
			var perches := {}
			var targets := {}
			for f: Node3D in d.flies:
				var key := ""
				if f.state == Fly.State.PERCHED:
					key = f.perch.id
					if perches.has(key):
						clash[0] += 1
					perches[key] = true
				elif f.flight != null and f.flight.target != null:
					key = f.flight.target.id
					if targets.has(key) or perches.has(key):
						clash[0] += 1
					targets[key] = true
			for a in d.flies.size():
				for b in range(a + 1, d.flies.size()):
					if (d.flies[a] as Node3D).global_position.distance_to((d.flies[b] as Node3D).global_position) < 0.5:
						clash[0] += 1
		)
		check_eq(int(clash[0]), 0, "%d flies: no two ever shared a perch, a destination or a place" % n)
		for f: Node3D in d.flies:
			unique[f.id] = true
		check_eq(unique.size(), n, "%d flies have %d ids" % [n, n])
		check_eq(d.population.entries_total, 0, "and nothing was added: the room was full")
		world.queue_free()
		await physics_frames(2)


func test_replenishment_is_off_unless_the_world_asks_for_it() -> void:
	await spawn_prey_world(floor_pose(0.0, 0.0, 0.0), 2, 37)
	var d := director()
	check(not d.population.enabled, "a test world does not replace flies by default")
	_lose(d.flies[0])
	await run_ticks(60 * 2)
	check(d.population.pending.is_empty() and d.population.entries_total == 0, "and a loss is just a loss")
	world.queue_free()
	await physics_frames(2)
	prey_replenish = true
	await spawn_prey_world(floor_pose(0.0, 0.0, 0.0), 0, 38)
	check(not director().population.enabled, "a world that wants no flies has nothing to replace")
	check(world.prey_replenish, "the played world's switch is on (Main.prey_replenish)")


func test_the_shipped_numbers_and_the_developer_line() -> void:
	prey_replenish = true
	await spawn_prey_world(floor_pose(0.0, 0.0, 0.0), 1, 39)
	var d := director()
	var p: PreyProfile.Profile = d.profile
	check_eq(p.replenish_delay_s, Vector2(25.0, 45.0), "the shipped wait is 25 to 45 seconds")
	check_near(p.vent_view_margin_deg, 12.0, 1.0e-9, "the margin around the picture is 12 degrees")
	check_near(p.vent_min_distance_wu, 10.0, 1.0e-9, "no vent within 10 WU of the spider is used")
	_lose(d.flies[0])
	await physics_frames(3)
	var rec: Dictionary = d.population.pending[0]
	check(float(rec["delay"]) >= 25.0 and float(rec["delay"]) <= 45.0, "a loss is made good %.1f s later" % float(rec["delay"]))
	var lines := PreyDebug.describe(d, world.needs, world.feeding)
	var joined := "\n".join(lines)
	check(joined.contains("population: 0 of 1 free, next in"), "the F3 overlay says so: %s" % joined.substr(maxi(0, joined.find("population:")), 60))


func test_the_labelled_test_marker_stays_separate_from_the_flies() -> void:
	await spawn_prey_world(floor_pose(0.0, 0.0, 0.0), 4, 43)
	var d := director()
	await physics_frames(10)
	var marker: Node3D = world.lab.get_test_target()
	check(marker != null and not d.flies.has(marker) and not (marker is Fly), "the marker is not a fly and the director does not hold it")
	var fly_ids := 0
	var others := PackedStringArray()
	for node: Node in runner.get_tree().get_nodes_in_group(Perceivable.GROUP):
		var pc: Dictionary = node.get_percept()
		if pc.is_empty():
			continue
		if node is Fly:
			fly_ids += 1
		else:
			others.append(str(pc["id"]))
	check_eq(fly_ids, 4, "four flies are things the spider can sense")
	check_eq(",".join(others), "test_target", "and the one other thing is the labelled marker, under its own id")
	check_eq(d.living().size(), 4, "the director counts only the flies")
	# a fly taken out of the room changes nothing about the marker
	var before: Dictionary = marker.get_percept()
	d.flies[0].mark_captured("spider", "capture:spider:%s" % d.flies[0].id)
	await physics_frames(2)
	check_eq(marker.get_percept()["id"], before["id"], "the marker is the same thing as before")
	check_eq(d.living().size(), 3, "and three flies live")
