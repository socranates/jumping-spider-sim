extends "res://tests/prey_test_case.gd"
## T09c (Nathan, 2026-10-11: "they should actively walk around more naturally like a real fly, take off and fly randomly sometimes";
## "the tapping mechanic ... isnt working properly when i catch a fly"; "maybe the space bar can be used for the tapping"; and Chet's
## review 5, P2, remapped prompts).
##   * a perched fly walks about its spot in stop-start bursts, on its surface, never through a wall, within its wander radius; the same seed
##     walks the same way;
##   * a fly that moves of its own accord sometimes loops through the open air before landing, every leg flown at flight speed;
##   * the struggle: the jump button (Space, A) is the grip and neither hops nor aims; the grip does not drain while the spider is still in
##     the air; once subdued the fly is eaten at once and taps that follow do not toggle the meal; the end is said in words;
##   * prompts name the keys the player chose.

const KeyNames = preload("res://scripts/presentation/key_names.gd")


func after_each() -> void:
	for a: String in ["interact", "prepare_jump"]:
		Input.action_release(a)
	super.after_each()


# ------------------------------------------------------------------ walking

func _walk_run(seed_value: int) -> Dictionary:
	await spawn_prey_world(floor_pose(-20.0, 12.0, -90.0))
	director().stimulus_enabled = false   # only its own life
	var f := add_fly("floor_east_open", seed_value)
	var p := perch("floor_east_open")
	var rec := {"far": 0.0, "off": 0, "path": [], "max_step": 0.0}
	var last := [f.global_position]
	await run_ticks(60 * 15, func() -> void:
		rec["far"] = maxf(float(rec["far"]), flat_distance(f.stand, p.position))
		if f.state == Fly.State.PERCHED and not f.surface_under(f.stand):
			rec["off"] = int(rec["off"]) + 1
		if f.state == Fly.State.PERCHED:
			rec["max_step"] = maxf(float(rec["max_step"]), (f.global_position - (last[0] as Vector3)).length())
		last[0] = f.global_position
		(rec["path"] as Array).append(f.global_position))
	rec["walks"] = f.walks_started
	rec["walked"] = f.walked_wu
	rec["radius"] = f.profile.wander_radius_wu
	rec["top_speed"] = f.profile.walk_speed_wu_s.y
	world.queue_free()
	await physics_frames(2)
	return rec


func test_a_fly_walks_about_its_spot_like_a_fly() -> void:
	var a := await _walk_run(11)
	check(int(a["walks"]) >= 3 and float(a["walked"]) > 1.5, "it walks about: %d walks, %.1f WU in 15 s" % [int(a["walks"]), float(a["walked"])])
	check(float(a["far"]) <= float(a["radius"]) + 0.01, "within its wander radius of its perch (%.2f of %.1f WU)" % [float(a["far"]), float(a["radius"])])
	check_eq(int(a["off"]), 0, "never off its surface")
	check(float(a["max_step"]) <= float(a["top_speed"]) / 60.0 * 1.05 + 0.03, "a step at a time, never a jump (%.3f WU in a tick)" % float(a["max_step"]))
	var b := await _walk_run(11)
	var same := (a["path"] as Array).size() == (b["path"] as Array).size()
	for i in mini((a["path"] as Array).size(), (b["path"] as Array).size()):
		same = same and ((a["path"] as Array)[i] as Vector3).distance_to((b["path"] as Array)[i]) < 1.0e-5
	check(same, "the same seed walks the same way")


func test_a_fly_does_not_walk_through_a_wall() -> void:
	await spawn_prey_world(floor_pose(-20.0, 12.0, -90.0))
	director().stimulus_enabled = false
	world.lab.add_fixture_piece("fly_fence", "wall", Vector3(3.0, 0.0, 11.6), Vector3(5.0, 2.0, 11.8))
	await physics_frames(3)
	var f := add_fly("floor_east_open", 5)
	var crossed := [0]
	var side := signf(f.global_position.z - 11.7)
	await run_ticks(60 * 15, func() -> void:
		if f.state == Fly.State.PERCHED and absf(f.global_position.x - 4.0) < 1.0 and signf(f.global_position.z - 11.7) != side:
			crossed[0] = int(crossed[0]) + 1)
	check_eq(int(crossed[0]), 0, "it never walked through the fence beside its perch")


func test_a_fly_sometimes_loops_through_the_air_before_landing() -> void:
	var loops := 0
	var flights := 0
	var worst := 0.0
	for seed_value in [2, 3, 4, 5, 6, 7]:
		await spawn_prey_world(floor_pose(-20.0, 12.0, -90.0))
		director().stimulus_enabled = false
		var f := add_fly("floor_east_open", seed_value)
		f.restless_rate = 1.0   # restless at once: it wants to move on
		await run_ticks(60 * 6)
		for e: Dictionary in f.trace:
			if str(e["to"]) == "REPOSITION":
				flights += 1
				if str(e["reason"]).contains("looping through the open air"):
					loops += 1
		worst = maxf(worst, f.flight.max_step)
		world.queue_free()
		await physics_frames(2)
	check(flights >= 4, "restless flies took off on their own (%d flights)" % flights)
	check(loops >= 1 and loops < flights, "some of the flights looped through the open air, not all (%d of %d)" % [loops, flights])
	check(worst <= 15.0 / 60.0 * 1.02, "every flight leg flown at flight speed, no jump (%.3f WU in a tick)" % worst)


# ------------------------------------------------------------------ the struggle, played

func _caught_playing() -> Node3D:
	prey_struggle = true
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0), 0, PREY_SEED, true)   # interactive: the real buttons
	var f := add_fly("floor_east_open", 1, true)
	await strike_at(4.0, 11.0)
	return f


func _press(action: String) -> void:
	Input.action_press(action)
	await physics_frames(1)
	Input.action_release(action)


func test_space_is_the_grip_while_the_fly_struggles_and_never_hops() -> void:
	var f := await _caught_playing()
	var fc: Node = world.feeding
	if not check(director().held == f and fc.struggling, "caught and struggling"):
		return
	var landed: Vector3 = world.spider.global_position
	for i in 400:
		if not fc.struggling:
			break
		if i % 9 == 0:   # T11b: a fast rhythm fills the bar
			await _press("prepare_jump")
		else:
			await physics_frames(1)
	check(fc.struggle_log.has("subdued"), "Space alone held the grip until it was subdued (%s)" % str(fc.struggle_log))
	check(fc.struggle_taps >= 4, "each Space press counted (%d)" % fc.struggle_taps)
	check(world.spider.global_position.distance_to(landed) < 0.2 and world.spider.state == world.spider.State.ATTACHED, "and the spider never hopped or aimed")
	check(world.jump_controller.phase == 0, "the jump controller stayed idle")
	await physics_frames(3)
	check(fc.feeding, "once subdued, it eats at once")
	await _press("prepare_jump")   # a last tap of the rhythm
	await _press("interact")
	await physics_frames(2)
	check(fc.feeding, "taps that follow the struggle do not start and stop the meal")


func test_the_grip_waits_for_the_landing_and_the_end_is_said() -> void:
	prey_struggle = true
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0), 0, PREY_SEED, true)
	var f := add_fly("floor_east_open", 1, true)
	var spider: Node3D = world.spider
	var plan = spider.plan_jump(top_target(4.0, 11.0))
	spider.begin_prepare()
	await physics_frames(2)
	spider.commit_jump(plan)
	var grip_in_air := [1.0, false]
	await wait_until(func() -> bool:
		if world.feeding.struggling and spider.state != spider.State.ATTACHED:
			grip_in_air[0] = minf(float(grip_in_air[0]), world.feeding.grip)
			grip_in_air[1] = true
		return spider.state == spider.State.ATTACHED and world.feeding.struggling, 120)
	if bool(grip_in_air[1]):
		check(float(grip_in_air[0]) >= world.feeding.GRIP_START - 1.0e-6, "caught in the air, the grip did not drain before the landing (%.2f)" % float(grip_in_air[0]))
	await wait_until(func() -> bool: return not world.feeding.struggling, 300)
	check(director().held == null and f.is_alive(), "no presses: it tore free")
	check_eq(world.feeding.note, "It tore free!", "and the screen says so")
	world.needs_hud.refresh()
	check_eq(str(world.needs_hud._prompt_title.text), "It tore free!", "on the prey line")


# ------------------------------------------------------------------ prompts follow the keys (Chet review 5, P2)

func test_every_prompt_names_the_keys_the_player_chose() -> void:
	settings.set_key("interact", KEY_F)
	settings.set_key("cancel", KEY_Z)
	settings.set_key("move_forward", KEY_I)
	var f := await catch_a_fly()
	var fc: Node = world.feeding
	fc.settings = settings
	check(str(fc.prompt()["hint"]).contains("F / X to eat"), "holding prey: %s" % fc.prompt()["hint"])
	check(fc.request_feed(), "eating")
	check(str(fc.prompt()["hint"]).contains("F / X or Z / B to stop"), "eating: %s" % fc.prompt()["hint"])
	check_eq(KeyNames.apply("W / stick up: reel in    S / stick down: lower    hold Q / B: let go", settings),
		"I / stick up: reel in    S / stick down: lower    hold Z / B: let go", "the line hint")
	check_eq(KeyNames.apply("Q / B: cancel the jump", settings), "Z / B: cancel the jump", "the aim hint")
	settings.reset_keys()
	check_eq(KeyNames.apply("Q / B: cancel the jump", settings), "Q / B: cancel the jump", "defaults come back unchanged")
