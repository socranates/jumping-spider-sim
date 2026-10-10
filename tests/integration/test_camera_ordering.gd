extends "res://tests/world_test_case.gd"
## Placement order of the camera rig (chunk 6B). Nathan's Windows run of 2026-10-07T06:14:45Z failed
## test_camera.gd::test_camera_is_clear_on_the_first_frame_at_every_wall_and_heading at (0, 17.15) heading 315 and
## (0, -17.15) heading 135, with the camera 3.4 WU outside the wall (z 20.51): a full 5 WU boom. Chet's run ten minutes
## later passed, and so does every headless run at 60 frames a second.
##
## The cause was an ordering race, reproduced on Linux with --fixed-fps 15 (four physics ticks per rendered frame) and
## with --max-fps 15, with exactly the same camera positions. A body added during a physics tick has its transform
## applied only at the engine's next flush of transform notifications, so a query made in that same tick finds an empty
## world. The rig used to trust its first cast, in that tick, as "nothing in the way": it placed the camera at the full
## boom, and only a later _process could take it back. With a slow frame, several physics ticks run between two rendered
## frames, nothing re-places the camera, and a reader sees the stale placement.
##
## These tests pin the order rather than the timing: at every frame boundary (the start of each physics tick and of each
## rendered frame) after a spawn, the camera is clear of geometry and inside the lab, whatever the frame rate. Until the
## rig can see the world (is_world_ready()) the camera sits at the pivot with a boom of 0 and nothing is drawn from a
## cast. They fail on the camera of chunk 6A at any frame rate, because the spawn here is made the way the test runner
## makes one, inside a physics tick.

const CameraRig = preload("res://scripts/movement/camera_rig.gd")

## x, z, heading in degrees. The first two are the Windows failure; the third looks into the north wall with its back to
## the stale boom's other side; the fourth and fifth are a wall behind and a corner; the sixth puts the stale camera
## inside a ledge (the failure of --fixed-fps 10 and 15 at (0, -17.15) heading 45).
const SPOTS := [
	Vector3(0.0, 17.15, 315.0),
	Vector3(0.0, -17.15, 135.0),
	Vector3(0.0, -17.15, 180.0),
	Vector3(0.0, 17.15, 0.0),
	Vector3(29.65, 17.15, 45.0),
	Vector3(0.0, -17.15, 45.0),
]


func _spot_pose(spot: Vector3) -> Transform3D:
	return floor_spawn(spot.x, spot.y, spot.z)


## The camera is outside every piece of the lab and inside its walls; before the rig can see the world it also sits at
## the spider's own centre, boom 0.
func _boundary(label: String) -> void:
	var rig = world.camera_rig
	var p: Vector3 = rig.camera.global_position
	check(point_is_clear(p, 0.1), "%s: the camera is outside geometry at %s" % [label, str(p)])
	check(in_lab_bounds(p), "%s: the camera is inside the lab at %s" % [label, str(p)])
	if not rig.is_world_ready():
		check(p.distance_to(world.spider.global_position) < 0.02, "%s: before the rig can see the world the camera sits at the spider's centre, not at %s" % [label, str(p)])
		check_near(rig.boom_length, 0.0, 1e-9, "%s: and the boom is 0" % label)


func test_a_spawn_inside_a_physics_tick_never_shows_a_camera_from_an_uncast_boom() -> void:
	for spot: Vector3 in SPOTS:
		await physics_frames(1)  # resumed from the physics_frame signal: inside a tick, where every test spawns
		var label := "spot (%.2f, %.2f) heading %d" % [spot.x, spot.y, int(spot.z)]
		check(Engine.is_in_physics_frame(), "%s: the spawn is made inside a physics tick" % label)
		spawn_world(_spot_pose(spot))
		var rig = world.camera_rig
		check(not rig.is_world_ready(), "%s: a rig made inside a tick cannot see its world yet" % label)
		_boundary(label + ", after the spawn")
		var ready_at := -1
		for step in 12:
			if step % 3 == 2:
				await process_frames(1)
			else:
				await physics_frames(1)
			_boundary("%s, boundary %d" % [label, step])
			if ready_at < 0 and rig.is_world_ready():
				ready_at = step
		check(ready_at >= 0 and ready_at <= 2, "%s: the rig can see its world within two boundaries (at %d)" % [label, ready_at])
		check(rig.boom_length > 0.2 and rig.boom_length <= rig.desired_distance(), "%s: and then casts a real boom (%.2f WU)" % [label, rig.boom_length])
		world.free()


func test_a_spawn_made_outside_the_physics_step_can_be_cast_from_the_first_tick() -> void:
	# A normal start (and any spawn from _process or a process_frame callback) enters the tree outside the physics step:
	# the engine flushes transforms before any tick, so the first tick may cast. Nothing is lost against chunk 6A.
	for spot: Vector3 in SPOTS:
		await process_frames(1)
		var label := "spot (%.2f, %.2f) heading %d" % [spot.x, spot.y, int(spot.z)]
		check(not Engine.is_in_physics_frame(), "%s: the spawn is made outside the physics step" % label)
		spawn_world(_spot_pose(spot))
		var rig = world.camera_rig
		_boundary(label + ", after the spawn")
		await physics_frames(1)
		_boundary(label + ", at the first tick")
		await process_frames(1)
		_boundary(label + ", after the first tick")
		check(rig.is_world_ready(), "%s: the first tick could see the world" % label)
		check(rig.boom_length > 0.2, "%s: and cast a real boom (%.2f WU)" % [label, rig.boom_length])
		world.free()


func test_a_snap_before_the_rig_can_see_the_world_keeps_the_camera_at_the_pivot() -> void:
	# main.respawn() snaps the camera in the same tick. Until the world is visible a snap must not trust a cast.
	await physics_frames(1)
	spawn_world(_spot_pose(SPOTS[0]))
	var rig = world.camera_rig
	rig.snap_to_target()
	_boundary("a snap in the tick of the spawn")
	check(not rig.is_world_ready(), "a snap does not make the world visible")
	rig.set_physics_process(false)  # rendered frames with no tick in between (a headless run draws a frame after every tick)
	await process_frames(2)
	_boundary("two rendered frames later")
	check_near(rig.boom_length, 0.0, 1e-9, "the boom is still 0")
	rig.set_physics_process(true)
	await physics_frames(3)
	check(rig.is_world_ready(), "after a tick the rig can see the world")
	rig.snap_to_target()
	_boundary("a snap once the world is visible")
	check(rig.boom_length > 0.2 and rig.boom_length < CameraRig.COMFORT_BOOM, "and it casts the wall-limited boom (%.2f WU)" % rig.boom_length)


func test_several_physics_ticks_between_two_rendered_frames_leave_no_stale_placement() -> void:
	# The Windows pattern: a slow frame runs several ticks and _process does not run in between. Switching _process off
	# is exactly that, at any frame rate: the camera node is then placed by the physics ticks alone.
	for spot: Vector3 in [SPOTS[0], SPOTS[1], SPOTS[5]]:
		await physics_frames(1)
		var label := "spot (%.2f, %.2f) heading %d" % [spot.x, spot.y, int(spot.z)]
		spawn_world(_spot_pose(spot))
		var rig = world.camera_rig
		rig.set_process(false)
		for step in 8:
			_boundary("%s, tick %d without a rendered frame" % [label, step])
			await physics_frames(1)
		_boundary("%s, after eight ticks without a rendered frame" % label)
		rig.set_process(true)
		await process_frames(2)
		_boundary("%s, once rendering resumes" % label)
		world.free()


func test_rendered_frames_before_the_first_tick_draw_nothing_from_a_cast() -> void:
	# The other order: several rendered frames before the first physics tick (a long first frame). The rig has cast
	# nothing yet, so the camera stays at the pivot until a tick has run.
	for spot: Vector3 in [SPOTS[0], SPOTS[4]]:
		await process_frames(1)
		var label := "spot (%.2f, %.2f) heading %d" % [spot.x, spot.y, int(spot.z)]
		spawn_world(_spot_pose(spot))
		var rig = world.camera_rig
		rig.set_physics_process(false)
		for step in 5:
			await process_frames(1)
			_boundary("%s, rendered frame %d before the first tick" % [label, step])
		check(not rig.is_world_ready(), "%s: no tick, no cast" % label)
		rig.set_physics_process(true)
		await physics_frames(3)
		_boundary("%s, after the ticks" % label)
		check(rig.is_world_ready() and rig.boom_length > 0.2, "%s: the ticks cast a real boom (%.2f WU)" % [label, rig.boom_length])
		world.free()
