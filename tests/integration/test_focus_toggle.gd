extends "res://tests/tether_test_case.gd"
## The Focus toggle (A-026, chunk 7A) on the real interactive world. Hold mode, the default, is unchanged: Focus is on while the button is
## held. With Settings.focus_toggle a press starts it and the next press stops it; the cancel button stops it too, but only when cancel has
## nothing else to do (an aim in progress, or the safety line); it is clearly indicated on the HUD; it ends by itself when the spider
## leaves its surface (a committed jump, a fall, the line); and a press while off the surface is ignored, so it can neither touch a jump
## in flight nor get in the way of a recovery. Presses are sent as real action events, so the wiring is part of what is tested.

const PerceptionText = preload("res://scripts/presentation/perception_text.gd")

var jc: Node


func after_each() -> void:
	runner.get_tree().paused = false
	for a in ["focus", "cancel", "prepare_jump"]:
		Input.action_release(a)
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_TRIGGER_LEFT
	e.axis_value = 0.0
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _start(pose: Transform3D, toggle: bool) -> Node3D:
	settings.focus_toggle = toggle
	spawn_world(pose, true)
	await physics_frames(6)
	await settle(world.spider)
	jc = world.jump_controller
	return world.spider


## Sends the action as a real event and has the engine deliver it now: left to itself it is delivered at the start of the next rendered
## frame, which at a low frame rate (two physics ticks to a frame) is after the next tick has already read the input.
func _action(name: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await physics_frames(2)


## A press and a release of the action, as a finger does.
func _tap(name: String) -> void:
	await _action(name, true)
	await _action(name, false)
	await physics_frames(1)


## One reading of the left trigger, an analog axis that reports a value every time it moves.
func _trigger(value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_TRIGGER_LEFT
	e.axis_value = value
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await physics_frames(2)


func _heading_deg() -> float:
	return rad_to_deg(world.spider.get_heading())


func test_hold_mode_is_unchanged_and_the_toggle_is_off_by_default() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0), false)
	check_eq(settings.focus_toggle, false, "toggling Focus is an option, not the default")
	check(not spider.is_focusing(), "Focus is off to begin with")
	await _action("focus", true)
	check(spider.is_focusing(), "it is on while the button is held")
	await physics_frames(30)
	check(spider.is_focusing(), "for as long as it is held")
	await _action("focus", false)
	check(not spider.is_focusing(), "and off when it is let go")
	await _tap("focus")
	check(not spider.is_focusing(), "a tap leaves nothing on")
	check_eq(world.controller.is_focus_latched(), false, "there is no latch in hold mode")
	check_eq(world.perception_hud.focus_note(), "", "and nothing to say about it: the button is the state")
	await _action("cancel", true)
	await _action("cancel", false)
	await _action("focus", true)
	await _action("cancel", true)
	check(spider.is_focusing(), "cancel does not touch a held Focus")


func test_a_toggled_focus_starts_with_a_press_and_stops_with_the_next() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0), true)
	await _tap("focus")
	check(spider.is_focusing(), "one press starts it, and it stays on after the button is let go")
	await physics_frames(60)
	check(spider.is_focusing() and world.controller.is_focus_latched(), "a second later it is still on")
	await _tap("focus")
	check(not spider.is_focusing() and not world.controller.is_focus_latched(), "the next press stops it")
	await _tap("focus")
	check(spider.is_focusing(), "and a third starts it again")


func test_a_toggled_focus_turns_the_body_as_a_held_one_does() -> void:
	var turned := {}
	for toggle in [false, true]:
		var spider := await _start(floor_pose(-22.0, 12.0, -90.0), toggle)
		check(absf(angle_difference(deg_to_rad(_heading_deg()), deg_to_rad(-90.0))) < deg_to_rad(1.0), "(toggle %s) the body faces east to begin with" % str(toggle))
		world.controller.focus_direction_override = Vector3(0.0, 0.0, -1.0)   # toward the north wall: 90 degrees to the left
		if toggle:
			await _tap("focus")
		else:
			await _action("focus", true)
		await physics_frames(70)
		turned[toggle] = _heading_deg()
		check(spider.is_focusing(), "(toggle %s) Focus is on" % str(toggle))
		await _action("focus", false)
		world.free()
		await physics_frames(2)
	for toggle in [false, true]:
		check(absf(angle_difference(deg_to_rad(float(turned[toggle])), 0.0)) < deg_to_rad(3.0), "(toggle %s) the body turned to face the north wall: %.1f degrees" % [str(toggle), float(turned[toggle])])


func test_the_cancel_button_stops_a_toggled_focus_when_it_has_nothing_else_to_do() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0), true)
	await _tap("focus")
	check(spider.is_focusing() and world.controller.cancel_stops_focus(), "Focus is on and cancel would stop it")
	await _tap("cancel")
	check(not spider.is_focusing() and not world.controller.is_focus_latched(), "Q / B stops it")
	await _tap("cancel")
	check(not spider.is_focusing(), "and cancel with Focus off does nothing")


func test_cancel_belongs_to_an_aim_or_a_press_first() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0), true)
	await _tap("focus")
	jc.aim_override = top_target(-18.0, 12.0)
	jc.press()
	await physics_frames(3)
	check(jc.is_busy() and not spider.is_preparing(), "a jump press is in progress, not yet an aim")
	check(not world.controller.cancel_stops_focus(), "cancel is the press's")
	await _tap("cancel")
	check(spider.is_focusing() and world.controller.is_focus_latched(), "cancelling the press leaves Focus on")
	jc.release()
	await physics_frames(10)
	jc.press()
	await physics_frames(14)
	check_eq(spider.state, spider.State.PREPARING, "now it is an aim")
	check(spider.is_focusing(), "Focus is on while aiming")
	check(not world.controller.cancel_stops_focus(), "cancel is the aim's")
	check(not "Q" in world.perception_hud.focus_note(), "and the words on the screen do not offer it")
	await _tap("cancel")
	check_eq(spider.state, spider.State.ATTACHED, "cancel ended the aim")
	check(spider.is_focusing() and world.controller.is_focus_latched(), "and left Focus alone")
	jc.release()
	await physics_frames(4)
	check(world.controller.cancel_stops_focus() and "Q" in world.perception_hud.focus_note(), "with the aim gone, cancel is Focus's again and the words say so")
	await _tap("cancel")
	check(not spider.is_focusing(), "a second cancel stops Focus")


func test_a_committed_jump_ends_a_toggled_focus_and_a_press_in_flight_does_nothing() -> void:
	var spider := await _start(floor_pose(-14.5, -8.5, 0.0), true)
	await _tap("focus")
	check(spider.is_focusing(), "Focus is on")
	jc.aim_override = top_target(-14.5, -11.6)
	jc.press()
	await physics_frames(12)
	check(spider.is_preparing() and jc.plan.is_valid(), "aiming at a reachable ledge")
	var plan: RefCounted = jc.plan
	jc.release()
	await physics_frames(3)
	check(spider.is_airborne(), "the jump is committed and in the air")
	check(not spider.is_focusing() and not world.controller.is_focus_latched(), "Focus ended with it: it is not Focus's to steer")
	await _tap("focus")
	check(not spider.is_focusing(), "a press in flight is ignored, not kept for the landing")
	check(await wait_until(func() -> bool: return not spider.last_jump.is_empty() and str(spider.last_jump["outcome"]) != "", 150), "the flight ends")
	await settle(spider)
	check_eq(jc.last_feedback["kind"], "launched", "it was the jump that was committed")
	check(float(spider.last_jump["error_settled"]) < 0.25, "and it landed where its plan said: %.3f WU off" % float(spider.last_jump["error_settled"]))
	check(not spider.is_focusing(), "nothing turned Focus back on after the landing")
	check(plan.is_valid(), "(the plan was a valid one)")


func test_a_toggled_focus_cannot_get_in_the_way_of_a_recovery_on_the_line() -> void:
	var spider := await _start(cliff_pose(), true)
	await _tap("focus")
	check(spider.is_focusing(), "Focus is on, standing on the cliff")
	var events := record_line_events(spider)
	check(await miss_off_the_cliff(spider), "a miss: the line has caught the spider")
	await physics_frames(2)
	check(not spider.is_focusing() and not world.controller.is_focus_latched(), "the line took over: Focus is off")
	await _tap("focus")
	check(not spider.is_focusing() and not world.controller.is_focus_latched(), "a press on the line does not start it")
	var tc: Node = world.tether_controller
	tc.reel_override = 1.0
	await physics_frames(20)
	await _tap("focus")
	check(not spider.is_focusing(), "nor a press in the middle of the reel")
	check(await wait_until(func() -> bool: return events.has("completed"), 900), "the reel carries on and holds on again")
	tc.reel_override = 0.0
	await physics_frames(6)
	check(await wait_until(func() -> bool: return spider.state == spider.State.ATTACHED, 120), "the spider is back on the cliff")
	check(not spider.is_focusing(), "and Focus was never on during the recovery or after it")
	await _tap("focus")
	check(spider.is_focusing(), "on a surface again, a press works")


func test_turning_the_option_off_while_focus_is_toggled_on_gives_hold_mode_back() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0), true)
	await _tap("focus")
	check(spider.is_focusing(), "toggled on")
	settings.focus_toggle = false
	await physics_frames(3)
	check(not spider.is_focusing() and not world.controller.is_focus_latched(), "with the option off it is off: nothing is held")
	await _action("focus", true)
	check(spider.is_focusing(), "and holding works again")
	await _action("focus", false)


func test_an_analog_trigger_that_reports_many_values_is_one_press() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0), true)
	await _trigger(0.3)
	check(not spider.is_focusing(), "a light touch under the dead zone is no press")
	await _trigger(0.6)
	await _trigger(0.8)
	await _trigger(1.0)
	await _trigger(0.9)
	check(spider.is_focusing() and world.controller.is_focus_latched(), "squeezed through four readings it is on once, not toggled on and off")
	await _trigger(0.0)
	check(spider.is_focusing(), "and letting go of the trigger leaves it on")
	await _trigger(0.7)
	await _trigger(1.0)
	await _trigger(0.0)
	check(not spider.is_focusing(), "the next squeeze stops it")


func test_a_toggled_focus_is_clearly_indicated_on_the_screen() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0), true)
	var hud: CanvasLayer = world.perception_hud
	await process_frames(2)
	check_eq(hud.focus_note(), "", "nothing is said while Focus is off")
	check(not hud.get_node("FocusNote").visible, "and no label is up")
	await _tap("focus")
	await process_frames(2)
	var note: String = hud.focus_note()
	check("FOCUS ON" in note, "the words say it is on: '%s'" % note)
	check("Focus again" in note and "Q / B" in note, "how to stop it: press it again, or Q / B")
	var label: Label = hud.get_node("FocusNote")
	check(label.visible and label.text == note, "the label on the screen carries the same words")
	check(not PerceptionText.has_number(note), "and no numbers")
	check(spider.is_focusing(), "(Focus is on)")
	await _tap("focus")
	await process_frames(2)
	check_eq(hud.focus_note(), "", "off again: the words go")
	check(not label.visible, "and the label with them")


func test_a_button_already_down_when_play_resumes_is_not_a_press() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0), true)
	world.process_mode = Node.PROCESS_MODE_PAUSABLE   # the runner never pauses; the real game's world does
	await _tap("focus")
	check(spider.is_focusing(), "toggled on")
	runner.get_tree().paused = true
	await physics_frames(3)
	Input.action_press("focus")   # goes down while the pause panel is open and is still down when play resumes
	await physics_frames(5)
	runner.get_tree().paused = false
	await physics_frames(4)
	check(spider.is_focusing() and world.controller.is_focus_latched(), "the button that was already down when play resumed did not switch Focus off")
	Input.action_release("focus")
	await physics_frames(2)
	check(spider.is_focusing(), "and letting go of it does not either")
	await _tap("focus")
	check(not spider.is_focusing(), "a fresh press does")


func test_a_tap_that_is_over_before_the_next_tick_still_counts() -> void:
	# A press and its release delivered together (a hitch in the frame rate, or a very quick finger): the input has been let go again
	# by the time the controller next looks, and the press has to be remembered, not lost.
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0), true)
	for i in 2:
		var down := InputEventAction.new()
		down.action = "focus"
		down.pressed = true
		var up := InputEventAction.new()
		up.action = "focus"
		up.pressed = false
		Input.parse_input_event(down)
		Input.parse_input_event(up)
		Input.flush_buffered_events()
		check(not Input.is_action_pressed("focus"), "(the button is up again before any tick has looked)")
		await physics_frames(3)
		check_eq(spider.is_focusing(), i == 0, "tap %d: it is %s" % [i + 1, "on" if i == 0 else "off again"])
