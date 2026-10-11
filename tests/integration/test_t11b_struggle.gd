extends "res://tests/prey_test_case.gd"
## T11b (Nathan's playtest, 2026-10-11: "the tapping when catching a fly should be a bit harder and just stop when it is full"):
##   * a full grip bar subdues the fly on that tick, with no timer to wait out;
##   * a slow rhythm (two presses a second) no longer holds a fly: it tears free;
##   * a steady four a second wins in the end, because the fly's struggles weaken as the venom works;
##   * holding on automatically fills the bar by itself and ends the struggle in a moment.


func _caught() -> Node3D:
	prey_struggle = true
	var f := await catch_a_fly()
	world.feeding.interactive = true
	return f


func _tap() -> void:
	Input.action_press("interact")
	await physics_frames(1)
	Input.action_release("interact")


## Taps every `gap` ticks until the struggle ends (or `max_ticks`). Returns [ticks it lasted, the grip on the tick before it ended].
func _rhythm(gap: int, max_ticks: int = 60 * 14) -> Array:
	var fc: Node = world.feeding
	var last_grip := [fc.grip]
	var i := 0
	while fc.struggling and i < max_ticks:
		last_grip[0] = fc.grip
		if i % gap == 0:
			await _tap()
		else:
			await physics_frames(1)
		i += 1
	return [i, float(last_grip[0])]


func test_a_full_bar_subdues_the_fly_at_once() -> void:
	var f := await _caught()
	var fc: Node = world.feeding
	if not check(fc.struggling, "the caught fly struggles"):
		return
	check_near(fc.grip, fc.GRIP_START, 0.05, "the bar starts under half full")
	var done: Array = await _rhythm(8)   # seven and a half presses a second
	check(not fc.struggling and director().held == f, "a fast rhythm wins: the fly is subdued in the jaws")
	check(float(done[1]) > 1.0 - fc.GRIP_TAP - 0.02, "it ended the moment the bar was full (it stood at %.2f before the last press)" % float(done[1]))
	check(int(done[0]) < 60 * 4, "in a few seconds (%.1f s)" % (float(done[0]) / 60.0))
	var why := ""
	for line: String in fc.struggle_log:
		if line.begins_with("subdued: "):
			why = line
	check(why.begins_with("subdued: the grip is full"), "and the log says why: %s" % why)
	check_eq(fc.note, "Subdued.", "the screen says so")


func test_a_slow_rhythm_no_longer_holds_a_fly() -> void:
	var f := await _caught()
	var fc: Node = world.feeding
	await _rhythm(30)   # two presses a second: enough before T11b
	check(not fc.struggling and director().held == null, "two presses a second: it tore free")
	check(f.is_alive(), "and flew off")


func test_a_steady_rhythm_wins_as_the_venom_weakens_the_fly() -> void:
	var f := await _caught()
	var fc: Node = world.feeding
	var start_strength: float = fc.venom_strength()
	var done: Array = await _rhythm(15)   # four presses a second
	check(not fc.struggling and director().held == f, "four presses a second wins in the end (%.1f s)" % (float(done[0]) / 60.0))
	check(fc.venom_strength() < start_strength - 0.2, "the fly had weakened (%.2f of its first strength)" % fc.venom_strength())
	check(float(done[0]) / 60.0 <= fc.STRUGGLE_MAX_S + 0.5, "within the venom's time")


func test_holding_on_automatically_fills_the_bar_by_itself() -> void:
	settings.set_value("struggle_auto", true)
	var f := await _caught()
	var fc: Node = world.feeding
	var ticks := [0]
	await wait_until(func() -> bool:
		ticks[0] = int(ticks[0]) + 1
		return not fc.struggling, 300)
	check(director().held == f, "held on with no presses")
	check(int(ticks[0]) < 60 * 3, "and the bar filled in a moment (%.1f s)" % (float(ticks[0]) / 60.0))
	check(fc.struggle_jerks >= 1, "while the fly still kicked")
