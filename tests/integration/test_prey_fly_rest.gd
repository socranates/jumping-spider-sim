extends "res://tests/prey_test_case.gd"
## Chunk 7B, milestone 3: a fly at rest and its senses. The authored perches are checked against the physics world; a fly sits a leg's
## length above its perch and is a percept the spider's senses can read like any other; its fidgets and grooming are timed by a seeded
## stream of its own (the same seed gives the same fly, another seed another); what it takes in is only what its own eyes could see of
## the spider's body (a wall hides the spider's motion completely; a slow stalk gives it little while it looks the other way and enough to
## notice while it looks straight at it (T09b); a walk plenty), and what it has taken in drains when there is nothing more to see.


func test_the_authored_perches_are_checked_against_the_world() -> void:
	await spawn_prey_world(floor_pose(-22.0, 12.0, -90.0), 0)
	check(director().ensure_ready(), "the director can check the graph once the world can be queried")
	var summary: Dictionary = director().graph.summary()
	var authored: Array[Dictionary] = world.lab.get_prey_perches()
	check_eq(int(summary["valid"]), authored.size(), "every authored perch is valid (refused: %s)" % str(summary["refused"]))
	for d: Dictionary in authored:
		var p := perch(str(d["id"]))
		check(p != null and p.position.distance_to(d["position"] as Vector3) <= 0.07, "%s was snapped to the surface it is on" % str(d["id"]))
	var starts := 0
	for p: PerchGraph.Perch in director().graph.all():
		starts += 1 if p.start else 0
	check(starts >= 4, "at least four perches begin a population")


func test_a_fly_rests_a_leg_above_its_perch_and_the_spider_can_sense_it() -> void:
	await spawn_prey_world(floor_pose(4.0, 5.0, 180.0))
	var f := add_fly("floor_east_open", 1, true)
	var p := perch("floor_east_open")
	check(f != null, "the fly was made")
	check_vec_near(f.global_position, p.position + Vector3.UP * f.profile.hover_wu, 1.0e-4, "it hovers a leg's length above the surface")
	check(f.is_in_group("perceivable"), "it joins the group the spider's sensor reads")
	var pc: Dictionary = f.get_percept()
	check_eq(str(pc["id"]), "fly_1", "its world id")
	check_near(float(pc["radius"]), f.profile.radius_wu, 1.0e-9, "its apparent size is its body")
	check_eq(pc["max_category"], Observation.FLY_LIKE_PREY, "it can be refined to fly-like prey")
	check_eq(p.occupant, "fly_1", "its perch knows it is there")
	await run_ticks(150)
	var track: String = world.sensor.track_id_for("fly_1")
	check(track != "", "the spider has a contact for it")
	var contact: ObservationMemory.Contact = world.memory.get_contact(track)
	check(contact != null and contact.category == Observation.FLY_LIKE_PREY, "looking at it for a second makes it fly-like prey")


## The intervals between fidgets and grooming bouts are scaled by 0.4 here (and the run is 12 s, not 30 s), to keep the suite's real time down;
## the mechanism is the same.
func _quicken(f: Node3D) -> void:
	f.profile.fidget_interval_s = Vector2(1.0, 2.8)
	f.profile.groom_interval_s = Vector2(2.4, 6.0)
	f.begin_stay(director().now)


func test_fidgets_and_grooming_show_that_it_is_alive() -> void:
	await spawn_prey_world(floor_pose(4.0, 5.0, -90.0))
	var f := add_fly("floor_east_open", 7)
	_quicken(f)
	var p := perch("floor_east_open")
	var farthest := [0.0]
	await run_ticks(60 * 12, func() -> void: farthest[0] = maxf(farthest[0], flat_distance(f.global_position, p.position)))
	check(f.fidgets_started >= 3, "it shuffles now and then (%d fidgets in 12 s)" % f.fidgets_started)
	check(f.grooms_started >= 1, "it grooms now and then (%d bouts in 12 s)" % f.grooms_started)
	check(float(farthest[0]) <= f.profile.perch_radius_wu + 0.02, "and stays within its patch of the perch (%.2f WU)" % float(farthest[0]))
	check(world.sensor.cues_made >= 1, "the small shuffles are what the spider's side vision picks up (%d cues)" % world.sensor.cues_made)
	check_eq(f.state, Fly.State.PERCHED, "nothing here disturbs it")


func test_the_same_seed_gives_the_same_fly_and_another_seed_another() -> void:
	await spawn_prey_world(floor_pose(4.0, 5.0, -90.0))
	var a := add_fly("floor_east_open", 99)
	var b := add_fly("floor_ahead", 99)
	var c := add_fly("floor_north_open", 100)
	for f: Node3D in [a, b, c]:
		_quicken(f)   # the profile is shared, so this is one change; begin_stay draws each fly's first times again from its own stream
	await run_ticks(60 * 12)
	check(a.events.size() >= 5, "enough happened to compare (%d events)" % a.events.size())
	check_eq(a.events.size(), b.events.size(), "the same seed does the same number of things")
	var same := true
	for i in mini(a.events.size(), b.events.size()):
		var ea: Dictionary = a.events[i]
		var eb: Dictionary = b.events[i]
		same = same and ea["kind"] == eb["kind"] and absf(float(ea["t"]) - float(eb["t"])) < 1.0e-9
		if ea["kind"] == "fidget":
			same = same and (ea["shift"] as Vector3).distance_to(eb["shift"] as Vector3) < 1.0e-5
	check(same, "at the same moments and the same way")
	var differs: bool = c.events.size() != a.events.size()
	for i in mini(a.events.size(), c.events.size()):
		differs = differs or absf(float(a.events[i]["t"]) - float(c.events[i]["t"])) > 1.0e-6
	check(differs, "another seed does it differently")


func test_a_wall_hides_the_spiders_motion_from_the_fly_completely() -> void:
	await spawn_prey_world(floor_pose(0.0, 3.0, -90.0))
	var f := add_fly("floor_east_open", 5, true)
	var peak := [0.0]
	var sees := [0]
	var watch := func() -> void:
		peak[0] = maxf(peak[0], f.senses.awareness)
		sees[0] += 1 if bool(f.senses.evidence.get("seen", false)) else 0
	await walk_toward(Vector3(8.0, 0.0, 3.0), WALK, 0.3, 300, watch)
	check(float(peak[0]) >= 0.4 and int(sees[0]) > 100, "in plain view the same walk is noticed (awareness %.2f, seen on %d looks)" % [float(peak[0]), int(sees[0])])
	world.lab.add_fixture_piece("cover", "wall", Vector3(-1.0, 0.0, 7.0), Vector3(9.0, 8.0, 7.3))
	await physics_frames(4)
	f.senses.awareness = 0.0
	peak[0] = 0.0
	sees[0] = 0
	await walk_toward(Vector3(0.0, 0.0, 3.0), WALK, 0.3, 300, watch)
	check_near(float(peak[0]), 0.0, 1.0e-9, "behind a wall it takes in nothing")
	check_eq(int(sees[0]), 0, "it never once sees the spider")
	check_eq(str(f.senses.evidence.get("reason", "")), "no line of sight", "and knows why")


## T09b (Nathan: hunts "deliberately slow and challenging"; the fly "looks to and fro"): where the fly is looking decides how much of a
## stalk it takes in. A steady stalk straight at a fly that is looking at the spider is noticed before 3 WU; the same stalk while it looks
## the other way stays under the alert level; a walk is too much either way.
func test_what_a_fly_takes_in_of_a_stalk_depends_on_where_it_is_looking() -> void:
	var peaks := {}
	for c: Array in [["stalk, looking at it", STALK, Vector3.LEFT], ["stalk, looking away", STALK, Vector3.RIGHT], ["walk, looking at it", WALK, Vector3.LEFT]]:
		await spawn_prey_world(floor_pose(-2.0, 11.0, -90.0))
		var f := add_fly("floor_east_open", 3, true)
		f.face(c[2])
		var peak := [0.0]
		var steps := await walk_toward(f.global_position, c[1], 3.0, 900, func() -> void: peak[0] = maxf(peak[0], f.senses.awareness))
		peaks[c[0]] = float(peak[0])
		check(flat_distance(world.spider.global_position, f.global_position) <= 3.2, "the spider got to 3 WU of it (%s, %d ticks)" % [c[0], steps])
		world.queue_free()
		await physics_frames(2)
	check(float(peaks["stalk, looking at it"]) >= 0.3, "a steady stalk head on, in plain view, is noticed (%.2f; alert at 0.30)" % float(peaks["stalk, looking at it"]))
	check(float(peaks["stalk, looking away"]) < 0.3, "the same stalk while it looks the other way stays under the alert level (%.2f)" % float(peaks["stalk, looking away"]))
	check(float(peaks["walk, looking at it"]) >= 1.0, "walking up to it is plain to see (%.2f)" % float(peaks["walk, looking at it"]))


func test_what_it_has_taken_in_drains_when_the_spider_keeps_still() -> void:
	await spawn_prey_world(floor_pose(-5.0, 11.0, -90.0))
	var f := add_fly("floor_east_open", 3, true)
	f.face(Vector3.LEFT)
	await walk_toward(f.global_position, WALK, 3.0, 900)
	var high: float = f.senses.awareness
	check(high >= 1.0, "it took in a lot (%.2f)" % high)
	await run_ticks(60 * 6)
	check(f.senses.awareness < 0.1, "six seconds of a still spider and it has settled (%.2f)" % f.senses.awareness)
