extends "res://tests/prey_test_case.gd"
## Chunk 7B, milestone 7: feeding. The capture grants nothing; the feeding is the one door by which a caught fly becomes energy, a
## little each tick, only while the spider is on a surface, still and holding the prey. Any press of cancel or interact, any step, any jump
## or loss of footing ends it on the same tick, with the reason, and the controls are the player's again. What was eaten was eaten: the
## fly keeps what is left and a second meal continues from it, so nothing is granted twice. A full reserve does not stop the meal.


func test_a_capture_grants_nothing_and_feeding_grants_gradually() -> void:
	var f := await catch_a_fly()
	check_eq(f.state, Fly.State.CAPTURED, "caught")
	var before: float = world.needs.energy
	check_eq(world.needs.grants_made, 0, "the capture granted no energy")
	check_near(f.nutrition_left, 0.35, 1.0e-9, "and the fly has all its nutrition")
	check(world.feeding.request_feed(), "feeding starts")
	await run_ticks(60)
	var gained: float = world.needs.energy - before
	check_near(gained, 0.1, 0.01, "after a second of feeding the reserve has gained a tenth (%.3f)" % gained)
	check_near(f.nutrition_left, 0.25, 0.005, "and the fly has lost the same")
	check(world.feeding.feeding, "still feeding")
	await wait_until(func() -> bool: return not world.feeding.feeding, 60 * 6)
	check_eq(world.feeding.last_end_reason, "finished", "the meal ended because the fly was eaten")
	check_eq(f.state, Fly.State.CONSUMED, "it is CONSUMED")
	check_eq(director().held, null, "the jaws are empty")
	check_near(world.needs.granted_from(f.capture_event_id), 0.35, 1.0e-6, "exactly its nutrition was granted under its event id")
	check_near(world.needs.energy - before, 0.35, 0.01, "and the reserve rose by that (%.3f)" % (world.needs.energy - before))
	check_eq(world.needs.grants_refused, 0, "no grant was refused")


func test_cancel_returns_control_at_once_and_nothing_is_granted_twice() -> void:
	var f := await catch_a_fly()
	var id: String = f.capture_event_id
	world.feeding.request_feed()
	await run_ticks(60)
	world.feeding.request_cancel()
	check(not world.feeding.feeding, "cancelled on the same tick")
	check_eq(world.feeding.last_end_reason, "cancelled", "and it says so")
	var after_first: float = world.needs.granted_from(id)
	var left: float = f.nutrition_left
	check_near(after_first, 0.35 - left, 1.0e-6, "what was granted is what was eaten")
	await run_ticks(60)
	check_near(world.needs.granted_from(id), after_first, 1.0e-9, "nothing more while it is not feeding")
	check_eq(f.state, Fly.State.CAPTURED, "the fly is still held, with what is left")
	check(world.feeding.request_feed(), "a second meal starts")
	await wait_until(func() -> bool: return not world.feeding.feeding, 60 * 6)
	check_near(world.needs.granted_from(id), 0.35, 1.0e-6, "the two meals together granted its nutrition once")
	check_eq(f.state, Fly.State.CONSUMED, "and it is gone")
	check(not world.feeding.request_feed(), "there is nothing more to eat")
	check_eq(world.feeding.last_refusal, "no prey", "and the refusal says why")


func test_moving_or_jumping_or_falling_ends_it_and_the_controls_work() -> void:
	var f := await catch_a_fly()
	world.feeding.request_feed()
	await run_ticks(30)
	world.spider.set_intent(Vector3.RIGHT, false)
	await physics_frames(2)
	check(not world.feeding.feeding, "a step ends it")
	check_eq(world.feeding.last_end_reason, "moved", "because it moved")
	check(world.spider.velocity.length() > 0.5 or world.spider.global_position.x > 4.05, "and the spider is walking: control was never taken")
	world.spider.set_intent(Vector3.ZERO, false)
	await physics_frames(20)
	check(world.feeding.request_feed(), "it can start again when still")
	await physics_frames(5)
	check(world.spider.begin_prepare(), "the jump press works while it feeds")
	await physics_frames(2)
	check(not world.feeding.feeding, "and ends the feeding")
	check_eq(world.feeding.last_end_reason, "jumped", "as a jump")
	world.spider.cancel_prepare()
	await physics_frames(10)
	check_eq(f.state, Fly.State.CAPTURED, "the prey is still held and partly eaten")
	check(f.nutrition_left < 0.35 and f.nutrition_left > 0.0, "(%.3f left)" % f.nutrition_left)


func test_it_cannot_start_when_it_is_not_valid() -> void:
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0))
	check(not world.feeding.request_feed(), "nothing held: refused")
	check_eq(world.feeding.last_refusal, "no prey", "no prey")
	var f := add_fly("floor_east_open", 1, true)
	await strike_at(4.0, 11.0)
	world.spider.set_intent(Vector3.RIGHT, false)
	await physics_frames(3)
	check(not world.feeding.request_feed(), "walking: refused")
	check_eq(world.feeding.last_refusal, "moved", "because it is moving")
	world.spider.set_intent(Vector3.ZERO, false)
	await physics_frames(30)
	world.spider.begin_prepare()
	await physics_frames(1)
	check(not world.feeding.request_feed(), "aiming a jump: refused")
	world.spider.cancel_prepare()
	check_eq(world.needs.grants_made, 0, "none of it granted anything")
	check_eq(f.state, Fly.State.CAPTURED, "the prey is untouched")


func test_a_full_reserve_does_not_trap_the_player() -> void:
	var f := await catch_a_fly()
	world.needs.energy = 0.98
	var id: String = f.capture_event_id
	world.feeding.request_feed()
	await wait_until(func() -> bool: return not world.feeding.feeding, 60 * 6)
	check_eq(world.feeding.last_end_reason, "finished", "the meal still ends by itself")
	check_eq(f.state, Fly.State.CONSUMED, "the fly is eaten")
	check(world.needs.energy <= 1.0 + 1.0e-9, "the reserve never passes full (%.3f)" % world.needs.energy)
	check(world.needs.granted_from(id) < 0.35, "less than its nutrition was granted: the reserve had no room (%.3f)" % world.needs.granted_from(id))
	check_eq(director().held, null, "and the jaws are free")


func test_the_needs_clock_runs_with_the_spider_and_drains_slowly() -> void:
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0))
	var e0: float = world.needs.energy
	await run_ticks(60 * 10)
	var drained: float = e0 - world.needs.energy
	check(drained > 0.0 and drained < 0.02, "ten seconds cost a hair of energy (%.4f)" % drained)
	check_near(world.needs.elapsed_s, 10.0, 0.6, "the model has seen the time pass (%.1f s)" % world.needs.elapsed_s)
