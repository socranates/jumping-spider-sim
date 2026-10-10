extends "res://tests/jump_test_case.gd"
## The landing patch, the optional detailed arc and the F4 jump view on the real interactive world.

const JumpFeedback = preload("res://scripts/presentation/jump_feedback.gd")
const JumpHudScript = preload("res://scripts/presentation/jump_hud.gd")


func _start(pose: Transform3D) -> Node3D:
	spawn_world(pose, true)
	await physics_frames(6)
	await settle(world.spider)
	return world.spider


func _surface_vertices(mesh: ArrayMesh, surface: int) -> int:
	return (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


func test_the_patch_lies_on_the_aimed_surface_in_the_shape_and_colour_of_its_kind() -> void:
	var spider := await _start(floor_pose(-24.0, -6.5, 0.0))
	var patch: Node3D = world.landing_patch
	var cases := [
		[top_target(-24.0, -3.5), "reachable", "solid"],
		[top_target(-24.0, -11.5), "obstructed", "cross"],
		[top_target(-11.0, -6.5), "unreachable", "dashed"],
		[ray_target(Vector3(-24.0, 1.5, 17.0), Vector3(-24.0, 1.5, 20.0)), "unreachable", "dashed"],
	]
	for c in cases:
		var plan = spider.plan_jump(c[0])
		check_eq(plan.kind_name(), c[1], "the plan is %s (%s)" % [c[1], plan.reason])
		patch.show_plan(plan)
		check_eq(patch.shown_pattern, c[2], "%s is drawn %s" % [c[1], c[2]])
		check(patch.visible, "the patch is visible")
		check_vec_near(patch.global_basis.y.normalized(), plan.target_normal, 1e-5, "its up is the surface normal")
		check_vec_near(patch.global_position, plan.target_point + plan.target_normal * 0.02, 1e-5, "it lies just off the aimed point")
	# A coated panel's face is ineligible, drawn dotted, on a vertical surface.
	spider.teleport_to(floor_pose(13.5, 11.0, 180.0))
	await settle(spider)
	var panel = spider.plan_jump(ray_target(Vector3(13.5, 1.5, 11.0), Vector3(13.5, 1.5, 20.0)))
	patch.show_plan(panel)
	check_eq(patch.shown_pattern, "dotted", "ineligible is dotted")
	check_vec_near(patch.global_basis.y.normalized(), Vector3.BACK * -1.0 if panel.target_normal.z < 0.0 else Vector3.BACK, 1e-5, "standing on a vertical face")
	check(absf(patch.global_basis.y.y) < 1e-5, "the patch stands on the wall, not the floor")
	var coloured: StandardMaterial3D = (patch._ring as MeshInstance3D).get_surface_override_material(1)
	check_eq(coloured.albedo_color, JumpFeedback.color_for("ineligible"), "in the ineligible colour")
	patch.show_plan(null)
	check(not patch.visible and patch.shown_kind == "", "no plan, no patch")
	var none: RefCounted = spider.plan_jump({})
	patch.show_plan(none)
	check(not patch.visible, "no target, no patch")


## Chunk 5: a far ring would be a few pixels, so beyond SCALE_REF_DISTANCE from the camera the patch grows
## with distance and keeps about the same size on screen; nearer it keeps its world size (just larger than
## the body). Measured through the real camera.
func test_the_ring_keeps_its_size_on_screen_at_distance_with_a_minimum_world_size() -> void:
	var spider := await _start(floor_pose(-28.0, 13.0, -90.0))
	await physics_frames(10)
	var patch: Node3D = world.landing_patch
	var LandingPatch: GDScript = patch.get_script()
	check_near(LandingPatch.scale_at_distance(2.0), 1.0, 1e-9, "near: the minimum world size")
	check_near(LandingPatch.scale_at_distance(6.0), 1.0, 1e-9, "at the reference distance: 1")
	check_near(LandingPatch.scale_at_distance(12.0), 2.0, 1e-9, "twice as far: twice as large")
	check_near(LandingPatch.scale_at_distance(100.0), 4.0, 1e-9, "capped")
	var cam: Camera3D = world.get_viewport().get_camera_3d()
	if not check(cam != null, "the world has a camera"):
		return
	var radii: Array[float] = []
	for d in [1.5, 4.0, 8.0, 11.0]:
		var plan = spider.plan_jump(top_target(-28.0 + d, 13.0))
		patch.show_plan(plan)
		var center: Vector3 = plan.target_point
		var side: Vector3 = patch.global_basis.z  # across the view (the camera looks along +X), scaled by the patch scale
		var px := cam.unproject_position(center).distance_to(cam.unproject_position(center + side * patch.RING_OUTER))
		var dist := cam.global_position.distance_to(center)
		check_near(patch.shown_scale, maxf(1.0, dist / patch.SCALE_REF_DISTANCE), 1e-4, "%.1f WU ahead (%.1f WU from the camera): the scale follows the distance" % [d, dist])
		radii.append(px)
	check(radii[2] > 0.0 and radii[3] > 0.0, "the far rings are on screen")
	check(radii[3] >= radii[2] * 0.75 and radii[3] <= radii[2] * 1.33, "8 and 11 WU ahead the ring is about the same size on screen: %.1f and %.1f px" % [radii[2], radii[3]])
	check(radii[3] >= 12.0, "11 WU ahead the ring is still at least 12 px across its radius: %.1f px" % radii[3])


func test_the_shapes_really_differ() -> void:
	await _start(floor_pose(-22.0, 12.0, -90.0))
	var patch: Node3D = world.landing_patch
	var counts := {}
	for pattern in ["solid", "cross", "dashed", "dotted"]:
		var mesh: ArrayMesh = patch._meshes[pattern]
		check_eq(mesh.get_surface_count(), 3, "%s has a backing, the coloured pattern and a faint disc" % pattern)
		counts[pattern] = _surface_vertices(mesh, 1)
	check(counts["cross"] > counts["solid"], "the cross adds bars to the ring")
	check(counts["solid"] > counts["dashed"] and counts["dashed"] > counts["dotted"], "dashes are fewer than a ring, dots fewer than dashes: %s" % str(counts))


func test_the_detailed_arc_is_off_by_default_and_draws_the_predicted_arc_when_on() -> void:
	var spider := await _start(floor_pose(-22.0, 12.0, -90.0))
	var jc: Node = world.jump_controller
	var patch: Node3D = world.landing_patch
	jc.aim_override = top_target(-18.0, 12.0)
	jc.press()
	await physics_frames(12)
	await process_frames(2)
	check_eq(patch.shown_kind, "reachable", "aiming at a reachable point")
	check_eq(patch._arc.rod_count(), 0, "the arc is not drawn by default")
	settings.detailed_arc = true
	await process_frames(2)
	patch.show_plan(null)
	await process_frames(2)
	check(patch._arc.rod_count() >= jc.plan.path.size() - 2, "with the setting on the arc has a rod per tick (%d rods, %d points)" % [patch._arc.rod_count(), jc.plan.path.size()])
	settings.detailed_arc = false
	patch.show_plan(null)
	await process_frames(2)
	check_eq(patch._arc.rod_count(), 0, "and it goes away again")
	jc.cancel()
	await physics_frames(3)
	check_eq(spider.state, spider.State.ATTACHED, "cancelled")


func test_f4_shows_the_predicted_and_the_actual_path_of_the_last_jump() -> void:
	var spider := await _start(floor_pose(-14.5, -8.5, 0.0))
	var jc: Node = world.jump_controller
	var dbg: Node3D = world.jump_debug
	check(not dbg.is_visible_in_tree(), "the jump view is hidden with the support view")
	jc.aim_override = top_target(-14.5, -11.6)
	jc.press()
	await physics_frames(12)
	var plan: RefCounted = jc.plan
	jc.release()
	await physics_frames(3)
	await wait_until(func() -> bool: return not spider.last_jump.is_empty() and str(spider.last_jump["outcome"]) != "", 120)
	await settle(spider)
	world.support_debug.visible = true
	await process_frames(3)
	check(dbg.is_visible_in_tree(), "F4 shows it")
	check(dbg._predicted.rod_count() > 5, "the predicted arc is drawn dashed (%d rods)" % dbg._predicted.rod_count())
	check_eq(dbg._actual.rod_count(), spider.last_jump["path"].size() - 1, "the actual path has a rod per tick")
	check(dbg._planned_marker.visible and dbg._landed_marker.visible, "the planned and the landed centres are marked")
	check_vec_near(dbg._planned_marker.global_position, plan.seat, 1e-4, "the planned marker is on the plan's seat")
	check_vec_near(dbg._landed_marker.global_position, spider.last_jump["contact_center"], 1e-4, "the landed marker is on the first touchdown")
	check(dbg._planned_marker.global_position.distance_to(dbg._landed_marker.global_position) < 0.25, "and they agree")
	world.support_debug.visible = false
	await process_frames(2)
	check(not dbg.is_visible_in_tree(), "F4 hides it again")


func test_the_toast_goes_after_a_few_seconds() -> void:
	await _start(floor_pose(-22.0, 12.0, -90.0))
	var jc: Node = world.jump_controller
	var hud: CanvasLayer = world.jump_hud
	jc.aim_override = top_target(-7.0, 12.0)
	jc.press()
	await physics_frames(12)
	jc.release()
	await physics_frames(3)
	await process_frames(2)
	check(hud.toast_text() != "", "a refused release shows a toast")
	await runner.get_tree().create_timer(JumpHudScript.TOAST_SECONDS + 0.5).timeout
	check_eq(hud.toast_text(), "", "and it goes after %.1f s" % JumpHudScript.TOAST_SECONDS)
