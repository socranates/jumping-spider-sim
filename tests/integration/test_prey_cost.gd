extends "res://tests/prey_test_case.gd"
## Chunk 7B, milestone 10, the cost of the prey (spec 24, A-029): six flies, a spider walking among them for fifteen seconds (they notice it,
## leave, plan flights, land again; a lost one is replaced), measured tick by tick: the prey tick (the flies' senses, minds and flights, the
## population, the capture stage) and the sensor tick (the spider's eyes on all of it), the candidates and plans the flies considered, and the
## rays and sweeps they asked of the world, the memory-spot checks of the sensor included. The numbers are written to
## tests/reports/t07_cost_report.txt. They are a measurement of this machine, a headless Linux virtual machine: they say nothing about any
## player's hardware (that needs a measurement on it, and nobody has made one). The budget they are held to is the specification's: about
## 2 ms at the 95th percentile for the AI and perception of a tick.

const REPORT_PATH := "res://tests/reports/t07_cost_report.txt"
const BUDGET_US := 2000
const FLIES := 6
const WINDOW_TICKS := 60 * 15
## The spider's route among the perches: it walks (not stalks), so flies notice it, leave and come back.
const ROUTE: Array[Vector3] = [Vector3(-13.0, 0.0, 8.0), Vector3(2.0, 0.0, 8.5), Vector3(10.0, 0.0, 2.0), Vector3(13.0, 0.0, -1.5),
	Vector3(2.0, 0.0, -6.0), Vector3(-6.0, 0.0, 2.0), Vector3(-13.0, 0.0, 8.0)]


func test_six_flies_stay_inside_the_budget_and_the_numbers_are_written_down() -> void:
	prey_replenish = true
	await spawn_prey_world(floor_pose(-22.0, 12.0, -90.0), FLIES, 71)
	var d := director()
	var sensor: Node = world.sensor
	check_eq(d.living().size(), FLIES, "six flies begin")
	d.profile.replenish_delay_s = Vector2(2.0, 3.0)   # shortened, so that a replacement falls inside the window
	await physics_frames(60)
	d.reset_cost()
	sensor.reset_cost()
	var before := {
		"cost": d.cost_summary(), "sensor_rays": sensor.rays_total, "spot_rays": sensor.spot_rays_total, "spot_checks": sensor.spot_checks_total,
		"sensor_checks": sensor.checks_total, "ticks": d.tick,
	}
	var shared := [0]   # perch clashes seen
	var flights := [0]
	var leg := [0]
	var max_step := [0.0]
	var on_tick := func() -> void:
		var seen := {}
		for f: Node3D in d.flies:
			if not f.is_alive():
				continue
			max_step[0] = maxf(float(max_step[0]), float(f.flight.max_step))
			var key := ""
			if f.state == Fly.State.PERCHED:
				key = f.perch.id
			elif f.flight.target != null:
				key = f.flight.target.id
			if key != "":
				if seen.has(key):
					shared[0] += 1
				seen[key] = true
	var used := 0
	var lost := false
	var strikes := 0
	while used < WINDOW_TICKS - 360 and int(leg[0]) < ROUTE.size() * 2:
		var goal: Vector3 = ROUTE[int(leg[0]) % ROUTE.size()]
		used += await walk_toward(goal, WALK, 0.8, mini(WINDOW_TICKS - 360 - used, 60 * 8), on_tick)
		leg[0] += 1
		if not lost and int(leg[0]) == 2:
			# a fly is lost mid-window: its replacement is due while the spider is still walking about
			lost = true
			var victim: Node3D = d.living()[0]
			victim.mark_captured("spider", "capture:spider:%s" % victim.id)
	# a strike at the nearest perched fly on the floor, so that the capture stage and the flies' reaction to a leap are in the window too
	var target: Node3D = null
	for f: Node3D in d.living():
		if f.state == Fly.State.PERCHED and f.perch.kind == "floor" and (target == null or f.global_position.distance_to(world.spider.global_position) < target.global_position.distance_to(world.spider.global_position)):
			target = f
	if target != null:
		var plan = world.spider.plan_jump(top_target(target.perch.position.x, target.perch.position.z))
		if plan.is_valid() and world.spider.begin_prepare():
			await physics_frames(2)
			if world.spider.commit_jump(plan):
				strikes += 1
				used += 2
				await run_ticks(120, on_tick)
				used += 120
	if used < WINDOW_TICKS:
		await run_ticks(WINDOW_TICKS - used, on_tick)
	var cost: Dictionary = d.cost_summary()
	var prev: Dictionary = before["cost"]
	var ticks_measured: int = d.cost_ticks()
	var prey_p95: int = d.cost_percentile(0.95)
	var sensor_p95: int = sensor.cost_percentile(0.95)
	var lines := PackedStringArray()
	lines.append("T07 cost with %d flies (chunk 7B, milestone 10)" % FLIES)
	lines.append("Measured on %s, display %s, Godot %s, %d physics ticks/s. Timing arguments: %s. Not a graphical frame-pacing gate." % [OS.get_name(), DisplayServer.get_name(), Engine.get_version_info()["string"], Engine.physics_ticks_per_second, str(OS.get_cmdline_args())])
	var timing := OS.get_environment("JSS_TIMING_MODE")
	lines.append("Timing mode supplied by launcher: %s" % (timing if timing != "" else "unspecified; see invocation log (engine flags can be stripped from OS arguments)"))
	lines.append("Window: %d ticks (%.1f s). The spider walked a route among the perches; flies noticed it, left, landed again; %d were replaced through the vents (the wait shortened to 2-3 s for the measurement); %d strike attempted, %d capture." % [ticks_measured, float(ticks_measured) / 60.0, int(cost["population_entries"]) - int(prev["population_entries"]), strikes, d.capture_log.size()])
	lines.append("")
	lines.append("CPU per tick, microseconds (spec 24: about %d at the 95th percentile for the AI and perception)" % BUDGET_US)
	lines.append("  prey tick   (flies' senses, minds, flights, population, capture stage): avg %d, p50 %d, p95 %d, p99 %d, max %d" % [int(cost["cpu_avg_us"]), int(cost["cpu_p50_us"]), prey_p95, int(cost["cpu_p99_us"]), int(cost["cpu_max_us"])])
	lines.append("  sensor tick (the spider's eyes on everything): avg %d, p50 %d, p95 %d, p99 %d, max %d" % [sensor.cpu_us_total / maxi(sensor.cost_ticks(), 1), sensor.cost_percentile(0.5), sensor_p95, sensor.cost_percentile(0.99), sensor.cpu_us_max])
	lines.append("  the two together: paired per-tick p95 %d against %d" % [d.combined_cost_percentile(0.95), BUDGET_US])
	lines.append("")
	lines.append("What the flies considered and asked of the world, over the window")
	var n := float(maxi(ticks_measured, 1))
	var dec := int(cost["decisions"]) - int(prev["decisions"])
	var cand := int(cost["candidates"]) - int(prev["candidates"])
	var plans := int(cost["plans"]) - int(prev["plans"])
	var fly_rays := int(cost["fly_rays"]) - int(prev["fly_rays"])
	var fly_checks := int(cost["fly_checks"]) - int(prev["fly_checks"])
	var f_sweeps := int(cost["flight_sweeps"]) - int(prev["flight_sweeps"])
	var g_sweeps := int(cost["graph_sweeps"]) - int(prev["graph_sweeps"])
	var g_plans := int(cost["graph_plans"]) - int(prev["graph_plans"])
	lines.append("  decisions %d (%.2f a tick); candidate perches considered %d (%.2f a tick); flights planned with sweeps %d (%d in the graph)" % [dec, dec / n, cand, cand / n, plans, g_plans])
	lines.append("  fly sight: %d checks, %d rays (%.2f rays a tick); flight sweeps %d (%.2f a tick); planner sweeps %d" % [fly_checks, fly_rays, fly_rays / n, f_sweeps, f_sweeps / n, g_sweeps])
	lines.append("  sensor: %d checks, %d rays (%.2f a tick), largest tick %d rays; memory-spot checks %d with %d rays (counted in the sensor's rays)" % [
		sensor.checks_total - int(before["sensor_checks"]), sensor.rays_total - int(before["sensor_rays"]), float(sensor.rays_total - int(before["sensor_rays"])) / n,
		sensor.max_rays_in_a_tick, sensor.spot_checks_total - int(before["spot_checks"]), sensor.spot_rays_total - int(before["spot_rays"])])
	lines.append("  population: %d asks, %d deferred, %d entries, %d view checks, %d sensor checks" % [int(cost["population_asks"]) - int(prev["population_asks"]), int(cost["population_deferred"]) - int(prev["population_deferred"]),
		int(cost["population_entries"]) - int(prev["population_entries"]), int(cost["population_view_checks"]) - int(prev["population_view_checks"]), int(cost["population_sensor_checks"]) - int(prev["population_sensor_checks"])])
	lines.append("  perch clashes between flies: %d; the largest step of any fly in a tick: %.3f WU" % [int(shared[0]), float(max_step[0])])
	lines.append("")
	var combined_p95: int = d.combined_cost_percentile(0.95)
	var verdict := "inside the budget" if combined_p95 <= BUDGET_US else "OVER the budget"
	lines.append("Verdict on this machine: %s (%d of %d microseconds at p95, paired ticks together)." % [verdict, combined_p95, BUDGET_US])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/reports"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if check(file != null, "the report file can be written"):
		file.store_string("\n".join(lines) + "\n")
		file.close()
	check(ticks_measured >= WINDOW_TICKS - 5, "the whole window was measured (%d ticks)" % ticks_measured)
	check(d.living().size() >= FLIES - 1, "six flies throughout (one may be in the jaws or on its way in): %d living" % d.living().size())
	check(combined_p95 <= BUDGET_US, "paired prey + sensor p95 stays inside 2 ms (%d us)" % combined_p95)
	check_eq(int(shared[0]), 0, "no two flies ever shared a perch or a destination")
	check(float(max_step[0]) <= d.profile.flee_speed_wu_s / 60.0 * 1.05 + 1.0e-6, "no fly ever moved more than its speed allows in a tick (%.3f WU)" % float(max_step[0]))
	check(dec > 0 and cand > 0 and fly_rays > 0, "the flies were busy: decisions, candidates and rays were counted")
	check(int(cost["population_entries"]) - int(prev["population_entries"]) >= 1, "a replacement came in during the window, so the population's checks are in the numbers")
	check(sensor.max_rays_in_a_tick <= 80, "the sensor never needed more than 80 rays in a tick (%d)" % sensor.max_rays_in_a_tick)
