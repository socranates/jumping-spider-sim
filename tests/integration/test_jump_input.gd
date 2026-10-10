extends "res://tests/jump_test_case.gd"
## The jump controls on the real interactive world: tap hops, hold aims, release commits, Q cancels, an
## invalid release cancels with feedback and no launch, the toggle option, the aim through the camera's
## centre ray, the landing patch and the HUD. Presses are sent as real action events where the wiring
## is the point, and through the controller's own press/release/cancel everywhere else.

const JumpFeedback = preload("res://scripts/presentation/jump_feedback.gd")

var jc: Node
var patch: Node3D
var hud: CanvasLayer


func after_each() -> void:
	runner.get_tree().paused = false
	Input.action_release("prepare_jump")
	Input.action_release("cancel")


## An interactive world with the spider standing at the pose.
func _start(pose: Transform3D, toggle: bool = false) -> Node3D:
	settings.prepare_toggle = toggle
	spawn_world(pose, true)
	await physics_frames(6)
	await settle(world.spider)
	jc = world.jump_controller
	patch = world.landing_patch
	hud = world.jump_hud
	return world.spider


func _action(name: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = pressed
	Input.parse_input_event(e)
	await process_frames(1)


## Holds long enough for the preparation to start and for the HUD and patch to draw.
func _hold_to_aim() -> void:
	jc.press()
	await physics_frames(12)
	await process_frames(2)


func _flight_over(spider: Node3D, max_frames: int = 120) -> bool:
	return await wait_until(func() -> bool: return not spider.last_jump.is_empty() and str(spider.last_jump["outcome"]) != "", max_frames)


func test_pausing_drops_an_aim_in_progress_so_it_cannot_get_stuck() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var rig = world.camera_rig
	# The runner never pauses; the real game's world does. Make the test world pausable like it.
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	await _hold_to_aim()
	check(jc.is_aiming() and spider.is_preparing() and rig.aiming, "aiming")
	runner.get_tree().paused = true
	await process_frames(2)
	check(not jc.is_aiming() and not spider.is_preparing() and not rig.aiming, "opening the pause panel drops the aim at once")
	runner.get_tree().paused = false
	await physics_frames(3)
	check_eq(spider.state, spider.State.ATTACHED, "after resuming the spider stands as before")
	jc.release()  # the real release happened while paused and was never delivered; a late one does nothing
	await physics_frames(3)
	check(spider.last_jump.is_empty(), "so nothing was launched")
	check_eq(spider.state, spider.State.ATTACHED, "and the spider still stands")
	# And the controls work again afterwards.
	await _hold_to_aim()
	check(jc.is_aiming(), "a fresh hold aims again")
	jc.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)  # alt-tab while holding: the same
	check(not jc.is_aiming() and not spider.is_preparing() and not rig.aiming, "losing the window focus drops the aim too")
	await _hold_to_aim()
	jc.cancel()
	await physics_frames(2)
	check(not jc.is_aiming(), "and Q cancels a fresh aim")


func test_a_tap_of_the_jump_button_is_a_short_hop_forward() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))  # faces +X
	var p0: Vector3 = spider.global_position
	var states := record_states(spider)
	await _action("prepare_jump", true)
	await physics_frames(3)
	check_eq(spider.state, spider.State.ATTACHED, "a short press has not started preparing")
	await _action("prepare_jump", false)
	await physics_frames(3)
	check(spider.is_airborne(), "the release hops")
	check(await _flight_over(spider), "the hop ends")
	await settle(spider)
	var moved: Vector3 = spider.global_position - p0
	check(moved.x > 1.3 and moved.x < 1.7 and absf(moved.z) < 0.05 and absf(moved.y) < 0.02, "it hopped about 1.5 WU along the heading, moved %s" % str(moved))
	check_eq(spider.support.surface_id, "floor", "and landed on the floor")
	check_eq(jc.last_feedback["kind"], "launched", "the controller says it launched")
	check_eq(states, ["PREPARING", "AIRBORNE", "LANDING", "ATTACHED"] as Array[String], "the states run in the spec's order")
	check(float(spider.last_jump["error_settled"]) < 0.05, "the hop lands where its plan said, %f WU" % float(spider.last_jump["error_settled"]))


func test_a_hold_aims_and_the_release_commits() -> void:
	var spider := await _start(floor_pose(-14.5, -8.5, 0.0))
	jc.aim_override = top_target(-14.5, -11.6)
	jc.press()
	await physics_frames(5)
	check_eq(spider.state, spider.State.ATTACHED, "before the hold time the spider is not preparing")
	await physics_frames(7)
	check_eq(spider.state, spider.State.PREPARING, "after the hold time it is")
	check(jc.is_aiming() and jc.plan.is_valid(), "aiming with a reachable plan")
	await process_frames(2)
	check_eq(patch.shown_kind, "reachable", "the patch shows reachable")
	check_eq(patch.shown_pattern, "solid", "as a solid ring")
	check_vec_near(patch.global_position, jc.plan.target_point + Vector3.UP * 0.02, 1e-4, "on the aimed point, just above the surface")
	check(hud.reticle_visible(), "the reticle is up")
	check_eq(hud.title_text(), "Reachable", "and the label says so in words")
	var plan: RefCounted = jc.plan
	jc.release()
	await physics_frames(2)
	check(spider.is_airborne(), "the release commits")
	check(jc.get_patch_plan() == plan, "the patch keeps showing the committed plan in the air")
	check(await _flight_over(spider), "the flight ends")
	await settle(spider)
	check_eq(spider.support.surface_id, "ledge_1", "on the ledge")
	check(float(spider.last_jump["error_settled"]) < 0.25, "within a quarter of a WU of the plan, %f" % float(spider.last_jump["error_settled"]))
	check_eq(jc.last_feedback["kind"], "launched", "feedback: launched")
	await process_frames(2)
	check_eq(patch.shown_kind, "", "the patch is gone after the landing")
	check(not hud.reticle_visible(), "and so is the reticle")


func test_q_cancels_a_press_and_a_preparation_with_no_penalty() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var p0: Vector3 = spider.global_position
	var states := record_states(spider)
	jc.press()
	await physics_frames(3)
	jc.cancel()
	await physics_frames(3)
	jc.release()
	await physics_frames(10)
	check(states.is_empty(), "cancelling a press before the hold time starts nothing, and its release does not hop")
	check_vec_near(spider.global_position, p0, 1e-6, "the spider stayed")
	jc.aim_override = top_target(-18.0, 12.0)
	await _hold_to_aim()
	check_eq(spider.state, spider.State.PREPARING, "preparing")
	await _action("cancel", true)
	await physics_frames(3)
	check_eq(spider.state, spider.State.ATTACHED, "Q returns to attached")
	check_vec_near(spider.global_position, p0, 1e-6, "in the same place")
	check(spider.last_jump.is_empty(), "no jump was recorded")
	check_eq(jc.last_feedback["kind"], "cancelled", "feedback: cancelled")
	check(not world.camera_rig.aiming, "the camera left aiming")
	jc.release()
	await physics_frames(5)
	check_eq(spider.state, spider.State.ATTACHED, "the release that follows does nothing")
	check_eq(states, ["PREPARING", "ATTACHED"] as Array[String], "one preparation, cancelled")


func test_releasing_on_an_unreachable_target_cancels_with_feedback_and_launches_nothing() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var p0: Vector3 = spider.global_position
	jc.aim_override = top_target(-7.0, 12.0)  # 15 WU away
	await _hold_to_aim()
	check_eq(jc.plan.kind_name(), "unreachable", "the plan says unreachable")
	check_eq(patch.shown_kind, "unreachable", "the patch shows it")
	check_eq(patch.shown_pattern, "dashed", "as a dashed ring")
	check(hud.title_text().begins_with("Out of reach"), "the label says so: %s" % hud.title_text())
	check("release to cancel" in hud.hint_text(), "and what a release will do")
	jc.release()
	await physics_frames(4)
	await process_frames(2)
	check_eq(spider.state, spider.State.ATTACHED, "the release cancelled the preparation")
	check(spider.last_jump.is_empty(), "nothing was launched")
	check_vec_near(spider.global_position, p0, 1e-6, "the spider did not move")
	check_eq(jc.last_feedback["kind"], "refused", "feedback: refused")
	check_eq(jc.last_feedback["plan"].reason, "too_far", "because it is too far")
	check("Jump cancelled" in hud.toast_text(), "the HUD says so: %s" % hud.toast_text())
	check_eq(patch.shown_kind, "unreachable", "the refused target stays on the patch for a moment")
	await physics_frames(jc.FLASH_TICKS + 5)
	await process_frames(2)
	check_eq(patch.shown_kind, "", "and then goes")


func test_obstructed_and_ineligible_targets_show_their_own_shapes_and_do_not_launch() -> void:
	var spider := await _start(floor_pose(-24.0, -6.5, 0.0))
	jc.aim_override = top_target(-24.0, -11.5)  # the floor behind the 5 WU wall
	await _hold_to_aim()
	check_eq(jc.plan.kind_name(), "obstructed", "behind the wall is obstructed")
	check_eq(patch.shown_pattern, "cross", "a ring with a cross")
	check(hud.title_text().begins_with("Blocked"), "labelled blocked: %s" % hud.title_text())
	jc.release()
	await physics_frames(4)
	check(spider.last_jump.is_empty() and spider.state == spider.State.ATTACHED, "no launch")
	check_eq(jc.last_feedback["kind"], "refused", "refused")
	spider.teleport_to(floor_pose(13.5, 11.0, 180.0))
	await settle(spider)
	await physics_frames(jc.FLASH_TICKS + 2)
	jc.aim_override = ray_target(Vector3(13.5, 1.5, 11.0), Vector3(13.5, 1.5, 20.0))  # the coated panel's face
	await _hold_to_aim()
	check_eq(jc.plan.kind_name(), "ineligible", "the coated panel cannot hold the spider")
	check_eq(patch.shown_pattern, "dotted", "a dotted ring")
	check(hud.title_text().begins_with("Can't land there"), "labelled: %s" % hud.title_text())
	jc.release()
	await physics_frames(4)
	check(spider.last_jump.is_empty(), "no launch")


func test_every_kind_has_its_own_shape_and_its_own_colour() -> void:
	var patterns := {}
	var colors := {}
	for kind in ["reachable", "obstructed", "unreachable", "ineligible"]:
		patterns[JumpFeedback.pattern_for(kind)] = kind
		colors[JumpFeedback.color_for(kind)] = kind
	check_eq(patterns.size(), 4, "four kinds, four shapes")
	check_eq(colors.size(), 4, "four kinds, four colours")
	for kind in ["reachable", "obstructed", "unreachable", "ineligible"]:
		check(JumpFeedback.TITLES.has(kind), "%s has a text label" % kind)


func test_toggle_mode_press_to_aim_press_to_jump_and_q_to_cancel() -> void:
	var spider := await _start(floor_pose(-14.5, -8.5, 0.0), true)
	jc.aim_override = top_target(-14.5, -11.6)
	jc.press()
	await physics_frames(2)
	check_eq(spider.state, spider.State.PREPARING, "the first press starts preparing at once")
	jc.release()
	await physics_frames(20)
	check_eq(spider.state, spider.State.PREPARING, "releasing does nothing, and a quick press is not a hop")
	check(jc.plan.is_valid(), "the plan is reachable")
	jc.press()
	await physics_frames(2)
	check(spider.is_airborne(), "the second press commits")
	check(await _flight_over(spider), "the flight ends")
	await settle(spider)
	check_eq(spider.support.surface_id, "ledge_1", "on the ledge")
	# An invalid target: the second press says why and keeps preparing.
	spider.teleport_to(floor_pose(-22.0, 12.0, -90.0))
	await settle(spider)
	jc.aim_override = top_target(-7.0, 12.0)
	jc.press()
	await physics_frames(3)
	check_eq(spider.state, spider.State.PREPARING, "preparing again")
	jc.press()
	await physics_frames(3)
	check_eq(spider.state, spider.State.PREPARING, "a press on an invalid target stays preparing")
	check_eq(jc.last_feedback["kind"], "invalid_press", "and says why")
	check(spider.last_jump["outcome"] == "support", "no new jump was started (the last one is the ledge jump)")
	jc.aim_override = top_target(-19.0, 12.0)
	await physics_frames(3)
	check(jc.plan.is_valid(), "aimed somewhere reachable again")
	jc.cancel()
	await physics_frames(3)
	check_eq(spider.state, spider.State.ATTACHED, "Q cancels in toggle mode too")


func test_the_aim_is_the_cameras_centre_ray_and_vertical_look_tilts_the_camera_only() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))  # open floor ahead
	var rig = world.camera_rig
	await process_frames(3)
	var elevation0: float = rig.elevation
	var yaw0: float = rig.yaw
	jc.press()
	await physics_frames(12)
	await process_frames(2)
	check(jc.is_aiming(), "aiming through the real camera")
	var cam: Camera3D = rig.camera
	var from: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_basis.z
	var space := world.get_world_3d().direct_space_state
	var expected := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 60.0, 1, [spider.get_rid()]))
	check(not expected.is_empty(), "the centre ray meets a surface")
	check_vec_near(jc.plan.target_point, expected["position"], 1e-3, "the target is exactly what the reticle is on")
	var far0: float = (jc.plan.target_point - spider.global_position).length()
	rig.look(0.0, -4.0)  # the mouse moves up: look up
	check(rig.aim_pitch > deg_to_rad(3.0), "looking up while aiming raises the aim, %f" % rig.aim_pitch)
	check_near(rig.elevation, elevation0, 1e-9, "the orbit pitch did not change")
	check_near(rig.get_view_elevation(), elevation0 + rig.auto_pitch, 1e-9, "and the walking view pitch ignores it")
	await process_frames(2)
	await physics_frames(3)
	check((jc.plan.target_point - spider.global_position).length() > far0 + 0.5, "the target moved farther away")
	check_near(rig.yaw, yaw0, 1e-9, "the camera did not turn")
	var right: Vector3 = cam.global_basis.x
	check(absf(right.y) < 1e-6 and cam.global_basis.y.y > 0.0, "and it never rolls")
	jc.cancel()
	await physics_frames(3)
	check_eq(spider.state, spider.State.ATTACHED, "cancelled")
	await physics_frames(90)  # the ease runs in _process with a 0.25 s time constant: 1.5 s leaves almost nothing
	await process_frames(2)
	check(absf(rig.aim_pitch) < deg_to_rad(0.2), "the tilt eases back to the orbit view after aiming, %f" % rig.aim_pitch)


func test_a_ledge_top_higher_than_the_pivot_is_aimed_at_by_tilting_the_camera() -> void:
	var spider := await _start(floor_pose(-14.5, -8.5, 0.0))
	var rig = world.camera_rig
	await process_frames(3)
	var yaw0: float = rig.yaw
	jc.press()
	await physics_frames(12)
	await process_frames(2)
	check(jc.is_aiming(), "aiming through the real camera")
	var found := false
	var angle := 0.0
	while angle <= 50.0 and not found:
		rig.aim_pitch = deg_to_rad(angle)
		await process_frames(1)
		await physics_frames(2)
		found = jc.plan.target_surface_id == "ledge_1" and jc.plan.target_normal.is_equal_approx(Vector3.UP)
		angle += 1.0
	check(found, "a ledge top higher than the pivot can be aimed at by tilting the camera")
	check(jc.plan.is_valid(), "and it is reachable (%s)" % jc.plan.reason)
	var plan: RefCounted = jc.plan
	jc.release()
	await physics_frames(2)
	check(spider.is_airborne(), "released: airborne")
	check(await _flight_over(spider), "the flight ends")
	await settle(spider)
	check_eq(spider.support.surface_id, "ledge_1", "on the ledge it was aimed at")
	check(spider.global_position.distance_to(plan.seat) < 0.25, "at the planned landing centre")
	await physics_frames(90)
	await process_frames(2)
	check(absf(rig.aim_pitch) < deg_to_rad(0.2), "the camera tilt eases back after the jump, %f" % rig.aim_pitch)
	check_near(rig.yaw, yaw0, 1e-9, "the camera never swung round")


func test_the_camera_stays_put_while_the_body_turns_toward_the_aim() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))  # faces +X
	var rig = world.camera_rig
	await process_frames(3)
	var yaw0: float = rig.yaw
	var boom0: float = rig.boom_length
	jc.aim_override = top_target(-22.0, 8.0)  # 4 WU to the left of the heading
	await _hold_to_aim()
	await physics_frames(30)
	var heading: Vector3 = spider.get_heading_vector()
	check(heading.z < -0.9, "the body turned toward the aim, heading %s" % str(heading))
	check_near(rig.yaw, yaw0, 1e-9, "the camera did not follow the turn")
	check_near(rig.boom_length, boom0, 0.01, "nor did the boom change")
	check_eq(spider.state, spider.State.PREPARING, "the turn does not stop the preparation")
	check(jc.plan.is_valid(), "and the plan stays reachable (%s)" % jc.plan.reason)


func test_hops_are_refused_with_a_reason_and_never_launch() -> void:
	var spider := await _start(floor_pose(0.0, 16.0, 180.0))  # facing the south wall, 1.5 WU away
	jc.press()
	await physics_frames(3)
	jc.release()
	await physics_frames(3)
	check(spider.last_jump.is_empty() and spider.state == spider.State.ATTACHED, "no hop into a wall")
	check_eq(jc.last_feedback["kind"], "hop_refused", "refused")
	check_eq(jc.last_feedback["plan"].reason, "hop_blocked", "something is in the way")
	check("No hop" in hud.toast_text() or true, "toast checked below")
	await process_frames(2)
	check("No hop" in hud.toast_text(), "the HUD says so: %s" % hud.toast_text())
	# Off the front of a ledge there is nothing to land on.
	spider.teleport_to(Transform3D(Basis(Vector3.UP, 0.0), Vector3(-14.5, 1.31, -13.0)))
	await settle(spider)
	jc.press()
	await physics_frames(3)
	jc.release()
	await physics_frames(3)
	check(spider.last_jump.is_empty(), "no hop off a ledge")
	check_eq(jc.last_feedback["plan"].reason, "no_ground", "nothing to land on ahead")
	# On a wall a hop cannot come back to the wall: the solver says there is no launch.
	var wall_basis := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, -1.0, 0.0))
	spider.teleport_to(Transform3D(wall_basis, Vector3(0.0, 1.5, 17.19)))
	await settle(spider)
	check_vec_near(spider.get_support_normal(), Vector3(0.0, 0.0, -1.0), 1e-4, "on the south wall")
	await physics_frames(jc.FLASH_TICKS + 2)
	jc.press()
	await physics_frames(3)
	jc.release()
	await physics_frames(3)
	check(spider.last_jump.is_empty() and spider.state == spider.State.ATTACHED, "no hop along a wall")
	check_eq(jc.last_feedback["plan"].reason, "no_launch", "gravity would not bring it back")


func test_leaving_the_habitat_says_so_and_ends_the_aim() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var home: Vector3 = spider.global_position
	jc.aim_override = top_target(-18.0, 12.0)
	await _hold_to_aim()
	spider.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, -50.0, 0.0)))
	await physics_frames(3)
	check_eq(jc.last_feedback["kind"], "out_of_bounds", "the controller reports it")
	check(not jc.is_aiming() and not world.camera_rig.aiming, "the aim ended")
	await process_frames(2)
	check("Out of bounds" in hud.toast_text(), "the HUD labels it: %s" % hud.toast_text())
	await settle(spider)
	check(spider.global_position.distance_to(home) < 0.5, "and the spider is back at its last supported position")


func test_the_real_jump_and_cancel_actions_are_wired() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	jc.aim_override = top_target(-18.0, 12.0)
	await _action("prepare_jump", true)
	await physics_frames(14)
	check_eq(spider.state, spider.State.PREPARING, "the prepare_jump action starts a preparation")
	await _action("cancel", true)
	await _action("cancel", false)
	await physics_frames(3)
	check_eq(spider.state, spider.State.ATTACHED, "the cancel action cancels it")
	await _action("prepare_jump", false)
	await physics_frames(3)
	check_eq(spider.state, spider.State.ATTACHED, "and the late release does nothing")
	await _action("prepare_jump", true)
	await physics_frames(14)
	await _action("prepare_jump", false)
	await physics_frames(3)
	check(spider.is_airborne(), "hold and release through the real action launches")
	await _flight_over(spider)
