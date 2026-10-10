extends "res://tests/world_test_case.gd"
## Camera rig in the real lab: boom collision, first-frame placement, look, recenter, settings,
## the pitch search against walls and fast orbit flicks.

const CameraRig = preload("res://scripts/movement/camera_rig.gd")
const Layers = preload("res://scripts/core/physics_layers.gd")
const SupportMath = preload("res://scripts/movement/support_math.gd")


## The first-frame check uses scene geometry only: bodies added this frame are not yet visible
## to the physics server, so a physics query would pass for the wrong reason.
func _assert_camera_clear(label: String, also_in_physics: bool = true) -> void:
	var p: Vector3 = world.camera_rig.camera.global_position
	check(point_is_clear(p, 0.1), "%s: camera is outside geometry at %s" % [label, str(p)])
	check(in_lab_bounds(p), "%s: camera is inside the lab at %s" % [label, str(p)])
	if also_in_physics:
		check(point_is_clear_in_physics(p, 0.1), "%s: physics agrees at %s" % [label, str(p)])


func _assert_level(label: String) -> void:
	var b: Basis = world.camera_rig.camera.global_transform.basis
	check(absf(b.x.y) < 1e-4 and b.y.y > 0.0, "%s: the horizon stays level (right.y %f, up.y %f)" % [label, b.x.y, b.y.y])


## First thing a ray from `from` to `to` meets on the layers in `mask`; empty when nothing.
func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, mask)
	return world.get_world_3d().direct_space_state.intersect_ray(params)


func test_camera_starts_clear_with_the_spider_backed_against_a_wall() -> void:
	spawn_world(floor_spawn(0.0, 17.15, 0.0))  # faces -Z; the camera sits behind it, at the south wall
	var rig = world.camera_rig
	_assert_camera_clear("first frame", false)
	await physics_frames(3)
	_assert_camera_clear("after the first ticks")
	check(rig.boom_length < CameraRig.COMFORT_BOOM, "the wall still limits the boom, %f" % rig.boom_length)
	await physics_frames(30)
	await process_frames(2)
	_assert_camera_clear("after 30 more ticks")
	check((world.spider.get_node("Body") as Node3D).visible, "the camera pitched up for room, so the spider body is drawn")


func test_camera_starts_clear_with_the_spider_facing_a_wall() -> void:
	spawn_world(floor_spawn(0.0, 17.15, 180.0))  # faces +Z, toward the south wall
	_assert_camera_clear("first frame", false)
	await physics_frames(5)
	_assert_camera_clear("after the first ticks")
	check_near(world.camera_rig.boom_length, 5.0, 0.01, "the open side gives the full boom")
	check((world.spider.get_node("Body") as Node3D).visible, "the spider body is visible")


func test_camera_starts_clear_in_a_corner() -> void:
	spawn_world(floor_spawn(29.65, 17.15, 45.0))  # faces the open room; the camera is in the SE corner
	_assert_camera_clear("first frame", false)
	await physics_frames(5)
	_assert_camera_clear("after the first ticks")
	check(world.camera_rig.boom_length < CameraRig.COMFORT_BOOM, "the corner still limits the boom, %f" % world.camera_rig.boom_length)


func test_camera_is_clear_on_the_first_frame_at_every_wall_and_heading() -> void:
	var spots := [Vector2(0.0, 17.15), Vector2(0.0, -17.15), Vector2(-29.65, 0.0), Vector2(29.65, 0.0)]
	var tested := 0
	for spot: Vector2 in spots:
		for heading in range(0, 360, 45):
			spawn_world(floor_spawn(spot.x, spot.y, float(heading)))
			_assert_camera_clear("spot %s heading %d, first frame" % [str(spot), heading], false)
			await physics_frames(3)
			_assert_camera_clear("spot %s heading %d, after ticks" % [str(spot), heading])
			world.free()
			tested += 1
	check_eq(tested, 32, "all wall and heading combinations were tried")


func test_boom_retracts_at_once_and_recovers_gradually() -> void:
	spawn_world(floor_spawn(0.0, 17.15, 0.0))
	var rig = world.camera_rig
	await physics_frames(5)
	check(rig.boom_length < CameraRig.COMFORT_BOOM, "limited by the wall, %f" % rig.boom_length)
	rig.yaw += PI  # swing the camera to the open side
	var previous: float = rig.boom_length
	var max_step := 0.0
	var monotonic := true
	for i in 120:
		await physics_frames(1)
		var now: float = rig.boom_length
		if now < previous - 1e-6:
			monotonic = false
		max_step = maxf(max_step, now - previous)
		previous = now
	check(monotonic, "the boom never shrinks while the way is clear")
	check(max_step <= 6.0 / 60.0 + 1e-4, "recovery is rate limited, largest step %f" % max_step)
	check(max_step > 0.01, "and it does recover")
	check_near(rig.boom_length, 5.0, 0.01, "full length after 2 s")
	rig.yaw -= PI  # back toward the wall
	await physics_frames(3)
	check(rig.boom_length < 1.0, "a new hit retracts at once, %f" % rig.boom_length)


func test_camera_under_the_overhang_stays_below_the_underside() -> void:
	spawn_world(floor_spawn(25.0, 5.0, 0.0))
	var rig = world.camera_rig
	await physics_frames(20)
	rig.elevation = deg_to_rad(70.0)  # steeply above: the slab underside is in the way
	await physics_frames(40)
	var p: Vector3 = rig.camera.global_position
	check(p.y < 3.0, "camera stays under the 3 WU underside, y = %f" % p.y)
	check(rig.boom_length < 4.0, "the boom shortened, %f" % rig.boom_length)
	_assert_camera_clear("under the overhang")


func test_horizon_stays_level_while_orbiting() -> void:
	spawn_world()
	var rig = world.camera_rig
	await physics_frames(5)
	for i in 40:
		rig.look(rng.randf_range(-40.0, 40.0), rng.randf_range(-30.0, 30.0))
		await process_frames(1)
		var b: Basis = rig.camera.global_transform.basis
		if not check(absf(b.x.y) < 1e-4 and b.y.y > 0.0, "camera right stays horizontal and up stays up (step %d)" % i):
			return


func test_look_applies_sensitivity_invert_and_pitch_clamp() -> void:
	spawn_world()
	var rig = world.camera_rig
	var yaw0: float = rig.yaw
	rig.look(10.0, 0.0)
	check_near(angle_difference(yaw0, rig.yaw), -deg_to_rad(10.0), 1e-5, "moving right turns the yaw clockwise")
	settings.look_sensitivity = 2.0
	yaw0 = rig.yaw
	rig.look(10.0, 0.0)
	check_near(angle_difference(yaw0, rig.yaw), -deg_to_rad(20.0), 1e-5, "sensitivity 2 doubles the turn")
	settings.invert_x = true
	yaw0 = rig.yaw
	rig.look(10.0, 0.0)
	check_near(angle_difference(yaw0, rig.yaw), deg_to_rad(20.0), 1e-5, "invert X flips the turn")
	settings.look_sensitivity = 1.0
	rig.elevation = deg_to_rad(20.0)
	rig.look(0.0, 10.0)
	check_near(rig.elevation, deg_to_rad(30.0), 1e-5, "moving down raises the camera")
	settings.invert_y = true
	rig.look(0.0, 10.0)
	check_near(rig.elevation, deg_to_rad(20.0), 1e-5, "invert Y flips it")
	settings.invert_y = false
	rig.look(0.0, 5000.0)
	check_near(rig.elevation, deg_to_rad(80.0), 1e-5, "pitch clamps at the top")
	rig.look(0.0, -5000.0)
	check_near(rig.elevation, deg_to_rad(-20.0), 1e-5, "pitch clamps at the bottom")


func test_recenter_turns_behind_the_spider_over_about_a_quarter_second() -> void:
	spawn_world(floor_spawn(-22.0, 12.0, -90.0))  # faces +X
	var rig = world.camera_rig
	await physics_frames(5)
	var behind: float = world.spider.get_heading()
	rig.yaw = behind + 2.0
	rig.elevation = deg_to_rad(60.0)
	rig.start_recenter()
	await process_frames(1)
	check(absf(angle_difference(rig.yaw, behind)) > 1.0, "the turn is smooth, not a snap")
	await runner.get_tree().create_timer(0.1).timeout
	var mid := absf(angle_difference(rig.yaw, behind))
	check(mid > 0.05 and mid < 1.9, "partway after 0.1 s, %f rad left" % mid)
	await runner.get_tree().create_timer(0.35).timeout
	check_near(angle_difference(rig.yaw, behind), 0.0, 0.01, "behind the spider after 0.45 s")
	check_near(rig.elevation, deg_to_rad(18.0), 0.01, "default elevation restored")


func test_fov_and_distance_settings_apply() -> void:
	spawn_world()
	var rig = world.camera_rig
	check_near(rig.camera.fov, 65.0, 1e-6, "default vertical FOV")
	check_near(rig.camera.near, 0.02, 1e-6, "near plane")
	check_near(rig.camera.far, 300.0, 1e-6, "far plane")
	settings.fov_degrees = 80.0
	check_near(rig.camera.fov, 80.0, 1e-6, "FOV follows the setting")
	await physics_frames(10)
	check_near(rig.boom_length, 5.0, 0.01, "default distance 5 WU")
	settings.camera_distance = 7.0
	await physics_frames(60)
	check_near(rig.boom_length, 7.0, 0.01, "distance 7 WU after recovery")
	settings.camera_distance = 4.0
	await physics_frames(3)
	check_near(rig.boom_length, 4.0, 0.01, "a shorter distance takes effect at once")


func test_camera_follows_the_walking_spider() -> void:
	spawn_world()
	var spider = world.spider
	await physics_frames(40)
	spider.set_intent(Vector3.RIGHT, false)
	await physics_frames(90)
	await process_frames(2)
	var offset: Vector3 = world.camera_rig.camera.global_position - spider.global_position
	check(offset.length() > 3.5 and offset.length() < 6.5, "the camera trails at about the boom distance, %f" % offset.length())
	check(offset.y > 0.5, "and stays above the spider")
	check(offset.x < -3.0, "behind it along -X, offset %s" % str(offset))


func test_mouse_motion_events_turn_the_camera() -> void:
	spawn_world()
	var rig = world.camera_rig
	rig.require_captured_mouse = false  # a headless run cannot capture the mouse
	var yaw0: float = rig.yaw
	var elev0: float = rig.elevation
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(50.0, 20.0)
	move.screen_relative = Vector2(50.0, 20.0)
	rig._unhandled_input(move)
	check_near(angle_difference(yaw0, rig.yaw), -deg_to_rad(5.0), 1e-5, "50 px right turns 5 degrees right at sensitivity 1")
	check_near(rig.elevation - elev0, deg_to_rad(2.0), 1e-5, "20 px down tilts 2 degrees")
	rig.require_captured_mouse = true
	var before: float = rig.yaw
	rig._unhandled_input(move)
	check_eq(rig.yaw, before, "uncaptured mouse motion is ignored")


func test_recenter_action_starts_a_recenter() -> void:
	spawn_world(floor_spawn(-22.0, 12.0, -90.0))
	var rig = world.camera_rig
	await physics_frames(5)
	rig.yaw += 1.5
	var press := InputEventAction.new()
	press.action = "recenter"
	press.pressed = true
	rig._unhandled_input(press)
	await runner.get_tree().create_timer(0.4).timeout
	check_near(angle_difference(rig.yaw, world.spider.get_heading()), 0.0, 0.01, "the recenter action turns the camera behind the spider")


func test_spider_stays_in_frame_with_its_back_to_a_wall() -> void:
	# x, z, heading in degrees. The spider faces away from the wall, so the camera boom points at it.
	var spots := [[0.0, 17.15, 0.0], [0.0, -17.15, 180.0], [-29.65, 0.0, -90.0], [29.65, 0.0, 90.0], [29.65, 17.15, 45.0]]
	for s in spots:
		spawn_world(floor_spawn(s[0], s[1], s[2]))
		var rig = world.camera_rig
		await physics_frames(40)
		await process_frames(2)
		var label := "spot %s" % str(s)
		var cam: Camera3D = rig.camera
		var centre: Vector3 = world.spider.global_position
		check(cam.is_position_in_frustum(centre), "%s: the spider's body centre is in frame, camera at %s" % [label, str(cam.global_position)])
		check((world.spider.get_node("Body") as Node3D).visible, "%s: the body is drawn, the camera is not inside it" % label)
		check(_ray(cam.global_position, centre, Layers.WORLD).is_empty(), "%s: no geometry between the camera and the spider" % label)
		var hit := _ray(cam.global_position, centre, Layers.WORLD | Layers.SPIDER)
		check(not hit.is_empty() and hit["collider"] == world.spider, "%s: the first thing the camera ray meets is the spider, got %s" % [label, str(hit.get("collider"))])
		check_near(rig.elevation, deg_to_rad(18.0), 1e-6, "%s: the player's own pitch is untouched" % label)
		check(rig.auto_pitch > deg_to_rad(10.0) and rig.elevation + rig.auto_pitch <= deg_to_rad(CameraRig.MAX_ELEVATION_DEG) + 1e-6, "%s: the camera pitched down for room, within the pitch clamp (offset %f degrees)" % [label, rad_to_deg(rig.auto_pitch)])
		_assert_camera_clear(label)
		_assert_level(label)
		world.free()


func test_fast_yaw_sweeps_near_walls_never_put_the_camera_in_geometry() -> void:
	# x, z, heading. 4.2 WU off the south wall (a stale 5 WU boom would end inside the wall block),
	# 2 WU off it (the pitch search runs mid-sweep), and near the SE corner.
	var spots := [[0.0, 13.3, 0.0], [0.0, 15.5, 0.0], [27.0, 14.5, 45.0]]
	for s in spots:
		spawn_world(floor_spawn(s[0], s[1], s[2]))
		var rig = world.camera_rig
		await physics_frames(10)
		for direction in [1.0, -1.0]:
			for i in 120:
				rig.look(direction * 24.0, 0.0)  # 24 degrees in one rendered frame
				await process_frames(1)  # resumes before the next _process: the camera is as the last frame drew it
				var label := "spot %s direction %d frame %d" % [str(s), int(direction), i]
				var before := failures.size()
				_assert_camera_clear(label)
				_assert_level(label)
				if failures.size() > before:
					break
		world.free()


func test_auto_pitch_eases_in_against_a_wall_and_out_when_space_clears() -> void:
	spawn_world(floor_spawn(0.0, 17.15, 0.0))
	var rig = world.camera_rig
	await physics_frames(40)
	var base: float = rig.elevation
	var squeezed: float = rig.auto_pitch
	check_near(base, deg_to_rad(18.0), 1e-6, "the player's own pitch is untouched")
	check(squeezed > deg_to_rad(40.0), "the camera pitched well down against the wall, offset %f degrees" % rad_to_deg(squeezed))
	rig.look(0.0, 5.0)
	check_near(rig.elevation, base + deg_to_rad(5.0), 1e-5, "look input still moves the player's own pitch")
	rig.look(0.0, -5.0)
	# Space clears: the camera swings to the open side and the offset relaxes, gradually.
	rig.yaw += PI
	var previous := squeezed
	var largest_step := 0.0
	var monotonic := true
	for i in 150:
		await physics_frames(1)
		monotonic = monotonic and rig.auto_pitch <= previous + 1e-9
		largest_step = maxf(largest_step, previous - rig.auto_pitch)
		previous = rig.auto_pitch
	check(monotonic, "the offset only relaxes while the way is clear")
	check(largest_step < deg_to_rad(5.0), "it eases out instead of snapping, largest step %f degrees" % rad_to_deg(largest_step))
	check(rig.auto_pitch < deg_to_rad(1.0), "back to the player's own pitch after 2.5 s, offset %f degrees" % rad_to_deg(rig.auto_pitch))
	check_near(rig.boom_length, 5.0, 0.01, "and the full boom is back")
	# The wall comes back: the offset eases in quickly.
	rig.yaw -= PI
	await physics_frames(20)
	check(rig.auto_pitch > 0.9 * squeezed, "eased back in within a third of a second, %f of %f degrees" % [rad_to_deg(rig.auto_pitch), rad_to_deg(squeezed)])
	await process_frames(2)
	_assert_level("after easing in and out")


func test_spider_body_is_hidden_only_while_the_camera_is_closer_than_the_hide_length() -> void:
	spawn_world()
	var rig = world.camera_rig
	var body := world.spider.get_node("Body") as Node3D
	await physics_frames(5)
	rig._place(world.spider.global_position, 0.45, rig.elevation, CameraRig.BODY_HIDE_LENGTH - 0.01)
	check(not body.visible, "hidden just inside the hide length")
	rig._place(world.spider.global_position, 0.45, rig.elevation, CameraRig.BODY_HIDE_LENGTH + 0.01)
	check(body.visible, "drawn just outside it")


## An underside above the camera: the pivot hangs below the spider, and the camera at the player's
## own pitch would sit in the slab. The rig now looks for room by going lower and looking up.
func test_on_an_underside_the_camera_goes_lower_and_still_reaches_the_comfortable_boom() -> void:
	var spots := [
		["overhang, heading west", Vector3(26.0, 3.0 - 0.31, 5.0), Vector3.LEFT, 3.0],
		["overhang, heading south", Vector3(25.0, 3.0 - 0.31, 3.0), Vector3.BACK, 3.0],
		["arch slab, heading east", Vector3(14.0, 4.0 - 0.31, 7.0), Vector3.RIGHT, 4.0],
	]
	for s in spots:
		spawn_world(Transform3D(SupportMath.body_basis(Vector3.DOWN, s[2]), s[1]))
		var rig = world.camera_rig
		await physics_frames(40)
		await process_frames(2)
		var label: String = s[0]
		var cam: Camera3D = rig.camera
		check_near(rig.elevation, deg_to_rad(18.0), 1e-6, "%s: the player's own pitch is untouched, at the default" % label)
		check(rig.auto_pitch < -deg_to_rad(5.0), "%s: the camera went lower, offset %f degrees" % [label, rad_to_deg(rig.auto_pitch)])
		check(rig.get_view_elevation() >= deg_to_rad(CameraRig.MIN_AUTO_ELEVATION_DEG) - 1e-6, "%s: not below the lowest automatic pitch" % label)
		check(rig.boom_length >= CameraRig.COMFORT_BOOM - 0.01, "%s: the boom reaches the comfortable length, %f" % [label, rig.boom_length])
		var centre: Vector3 = world.spider.global_position
		check(cam.is_position_in_frustum(centre), "%s: the spider is in frame" % label)
		check((world.spider.get_node("Body") as Node3D).visible, "%s: the body is drawn" % label)
		check(_ray(cam.global_position, centre, Layers.WORLD).is_empty(), "%s: no geometry between the camera and the spider" % label)
		check(cam.global_position.y < float(s[3]), "%s: the camera is under the underside, y = %f" % [label, cam.global_position.y])
		_assert_camera_clear(label)
		_assert_level(label)
		world.free()


func test_the_upward_search_only_runs_when_no_downward_pitch_is_comfortable() -> void:
	# Against a wall the old downward search succeeds, so the offset stays positive (a steeper view).
	spawn_world(floor_spawn(0.0, 17.15, 0.0))
	await physics_frames(40)
	check(world.camera_rig.auto_pitch > deg_to_rad(10.0), "a wall behind still pitches the camera steeper, %f degrees" % rad_to_deg(world.camera_rig.auto_pitch))
	world.free()
	# In the open there is no offset at all.
	spawn_world(floor_spawn(-22.0, 12.0, -90.0))
	await physics_frames(40)
	check_near(world.camera_rig.auto_pitch, 0.0, 1e-9, "in the open the pitch is the player's own")


func test_the_underside_offset_eases_in_and_out_without_snapping() -> void:
	spawn_world(Transform3D(SupportMath.body_basis(Vector3.DOWN, Vector3.LEFT), Vector3(26.0, 3.0 - 0.31, 5.0)))
	var rig = world.camera_rig
	await physics_frames(30)
	var lowered: float = rig.auto_pitch
	check(lowered < -deg_to_rad(5.0), "lowered under the overhang, %f degrees" % rad_to_deg(lowered))
	# Teleport out to the open floor: the offset relaxes to zero in steps, never snapping.
	world.spider.teleport_to(floor_spawn(-22.0, 12.0, -90.0))
	var previous: float = lowered
	var largest := 0.0
	for i in 200:
		await physics_frames(1)
		largest = maxf(largest, rig.auto_pitch - previous)
		previous = rig.auto_pitch
	check(largest < deg_to_rad(5.0), "it relaxes gradually, largest step %f degrees" % rad_to_deg(largest))
	check(absf(rig.auto_pitch) < deg_to_rad(1.0), "and is back at the player's pitch, %f degrees" % rad_to_deg(rig.auto_pitch))


func test_aiming_tilts_the_camera_about_itself_and_leaves_the_orbit_and_the_walking_view_alone() -> void:
	spawn_world(floor_spawn(-22.0, 12.0, -90.0))
	var rig = world.camera_rig
	await physics_frames(10)
	await process_frames(2)
	var elevation0: float = rig.elevation
	var view0: float = rig.get_view_elevation()
	var boom0: float = rig.boom_length
	var pos0: Vector3 = rig.camera.global_position
	var yaw0: float = rig.yaw
	rig.set_aiming(true)
	rig.look(5.0, -10.0)  # right and up
	await process_frames(2)
	check_near(rig.elevation, elevation0, 1e-9, "the orbit pitch stays")
	check_near(rig.get_view_elevation(), view0, 1e-9, "and so does the pitch the walking controls use")
	check_near(rig.aim_pitch, deg_to_rad(10.0), 1e-6, "the vertical look went into the aim pitch")
	check(angle_difference(yaw0, rig.yaw) < -deg_to_rad(4.0), "the horizontal look still orbits")
	check_near(rig.boom_length, boom0, 0.01, "the boom is unchanged")
	var pivot: Vector3 = rig.global_position
	check(rig.camera.global_position.distance_to(pivot) > 4.5, "the camera still sits on the boom")
	var ray: Dictionary = rig.get_aim_ray()
	check_vec_near(ray["origin"], rig.camera.global_position, 1e-6, "the aim ray starts at the camera")
	check_vec_near(ray["direction"], -rig.camera.global_basis.z, 1e-6, "and runs along the view, through the screen centre")
	rig.look(0.0, 100.0)
	check_near(rig.aim_pitch, deg_to_rad(CameraRig.AIM_PITCH_MIN_DEG), 1e-6, "the aim pitch stops at its downward limit")
	rig.look(0.0, -1000.0)
	check_near(rig.aim_pitch, deg_to_rad(CameraRig.AIM_PITCH_MAX_DEG), 1e-6, "and at its upward limit")
	await process_frames(2)
	_assert_level("at the upward limit")
	settings.invert_y = true
	rig.aim_pitch = 0.0
	rig.look(0.0, 10.0)
	check_near(rig.aim_pitch, deg_to_rad(10.0), 1e-6, "invert Y applies to the aim too")
	settings.invert_y = false
	rig.start_recenter()
	var yaw1: float = rig.yaw
	await process_frames(20)
	check_near(rig.yaw, yaw1, 1e-9, "recenter is ignored while aiming, so the view cannot swing behind the body")
	rig.set_aiming(false)
	# The ease runs in _process with the real frame time, so wait in game time (physics ticks), not in
	# frames: a headless run draws hundreds of frames a second and 120 of them are well under a second.
	await wait_until(func() -> bool: return absf(rig.aim_pitch) < deg_to_rad(0.1), 300)
	check(absf(rig.aim_pitch) < deg_to_rad(0.1), "after aiming the tilt eases back to zero, %f degrees" % rad_to_deg(rig.aim_pitch))
	check_vec_near(rig.camera.global_position, rig.global_position + (rig.camera.global_position - rig.global_position).normalized() * boom0, 0.6, "and the camera is back on its boom")


func test_the_whole_view_stays_short_of_straight_down_while_aiming() -> void:
	spawn_world(floor_spawn(-22.0, 12.0, -90.0))
	var rig = world.camera_rig
	await physics_frames(10)
	rig.elevation = deg_to_rad(80.0)  # steeply above, looking nearly straight down
	await physics_frames(5)
	rig.set_aiming(true)
	rig.look(0.0, 1000.0)  # look further down
	await process_frames(2)
	var forward: Vector3 = -rig.camera.global_basis.z
	check(forward.y > -sin(deg_to_rad(85.0)) - 1e-4, "the view is never past 85 degrees down, y = %f" % forward.y)
	_assert_level("looking down")
