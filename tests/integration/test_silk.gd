extends "res://tests/tether_test_case.gd"
## The safety line as the player sees it (A-017, chunk 6A), in the real lab with the real silk drawing, HUD and camera
## rig: the load-bearing line is a dark core in a light rim and never thinner than the pixel minimum, a taut or reeling
## line is heavier, old silk is thin, pale and translucent and fades, the world still hides the line (no X-ray), and the
## HUD says so when the line's anchor is out of sight behind the lip. How it looks is in tests/reports/shots (t06a_*).

const Silk = preload("res://scripts/presentation/silk_lines.gd")
const SilkShader = preload("res://scripts/presentation/silk.gdshader")
const JumpFeedback = preload("res://scripts/presentation/jump_feedback.gd")
const JumpHud = preload("res://scripts/presentation/jump_hud.gd")
const BoomMath = preload("res://scripts/movement/boom_math.gd")


func _start(pose: Transform3D) -> Node3D:
	spawn_world(pose, true)
	await physics_frames(6)
	await settle(world.spider)
	return world.spider


func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## The anchor as the HUD checks it: lifted a little off its surface.
func _anchor_probe(spider: Node3D) -> Vector3:
	return spider.tether.anchor_point + spider.tether.anchor_normal * JumpHud.ANCHOR_LIFT


## A view from the east (the side the spider hangs on, away from the cap): the camera's back direction points along +X.
func _look_from_the_east(rig: Node3D, elevation_deg: float) -> void:
	rig.yaw = PI * 0.5 if BoomMath.back_direction(PI * 0.5, 0.0).x > 0.0 else -PI * 0.5
	rig.elevation = deg_to_rad(elevation_deg)


func test_the_load_bearing_line_is_dark_with_a_light_rim_and_old_silk_is_pale_thin_and_fainter() -> void:
	var spider := await _start(cliff_pose())
	var silk: Node3D = world.silk_lines
	var tc: Node = world.tether_controller
	silk.screen_height_override = 1080.0   # widths in pixels at 1080p; the test window may be tiny
	var events := record_line_events(spider)
	check(await miss_off_the_cliff(spider), "caught and hanging")
	await process_frames(3)
	var h: float = silk.screen_height_px()
	check(silk.active_visible, "the active line is drawn")
	var active: ShaderMaterial = silk.active_material()
	var core: Color = active.get_shader_parameter("core_color")
	var rim: Color = active.get_shader_parameter("rim_color")
	check(_luma(core) < 0.12, "the core is dark (%.2f)" % _luma(core))
	check(_luma(rim) > 0.85, "the rim is light (%.2f)" % _luma(rim))
	check((_luma(rim) + 0.05) / (_luma(core) + 0.05) > 7.0, "so the two contrast by more than 7 to 1, and one of them stands out on a pale wall and on a dark one")
	check_near(float(active.get_shader_parameter("opacity")), 1.0, 1e-6, "the load-bearing line is fully opaque")
	check(silk.completed_alphas.is_empty(), "there is no old silk yet")
	tc.reel_override = 1.0
	check(await wait_until(func() -> bool: return events.has("completed"), 900), "reeled in and holding on again")
	tc.reel_override = 0.0
	await process_frames(3)
	check(not silk.active_visible, "the active line is no longer drawn")
	check_eq(silk.completed_alphas.size(), 1, "it is left behind as old silk")
	var old: ShaderMaterial = silk.old_material(0)
	var old_core: Color = old.get_shader_parameter("core_color")
	var old_rim: Color = old.get_shader_parameter("rim_color")
	check_eq(old_core, old_rim, "old silk is one colour: no dark core, no rim")
	check(_luma(old_core) > 0.8, "pale (%.2f)" % _luma(old_core))
	var old_opacity: float = old.get_shader_parameter("opacity")
	check(old_opacity > 0.3 and old_opacity < 0.9, "and translucent (%.2f)" % old_opacity)
	check(Silk.scaled_px(Silk.OLD_PX, h) < silk.active_core_px, "and thinner than the load-bearing line's core")


func test_a_taut_or_reeling_line_is_heavier_and_none_is_thinner_than_two_pixels_at_1080p() -> void:
	var spider := await _start(cliff_pose())
	var silk: Node3D = world.silk_lines
	var tc: Node = world.tether_controller
	silk.screen_height_override = 1080.0
	var plan: RefCounted = spider.plan_jump(top_target(27.3, -7.0))
	check(spider.begin_prepare() and spider.commit_jump(plan), "leaping toward the practice perch")
	await physics_frames(8)
	check(spider.tether.is_active() and not spider.tether.taut, "the line pays out behind the leap, slack")
	silk.refresh()
	var h: float = silk.screen_height_px()
	check_near(silk.active_core_px, Silk.scaled_px(Silk.ACTIVE_CORE_PX, h), 1e-6, "an ordinary line has the ordinary core")
	check(silk.active_core_px >= 2.0 - 1e-6, "which is at least 2 px at 1080p (%.2f)" % silk.active_core_px)
	check(await wait_until(func() -> bool: return spider.state == spider.State.HANGING, 200), "caught")
	check(await wait_settled(spider), "and at rest")
	silk.refresh()
	check(spider.tether.taut, "the line is taut")
	check_near(silk.active_core_px, Silk.scaled_px(Silk.LOADED_CORE_PX, h), 1e-6, "a taut line takes the heavier core")
	check(silk.active_core_px > Silk.scaled_px(Silk.ACTIVE_CORE_PX, h), "heavier than the ordinary one")
	tc.reel_override = 1.0
	await physics_frames(10)
	silk.refresh()
	check_eq(spider.state, spider.State.REELING, "reeling")
	check_near(silk.active_core_px, Silk.scaled_px(Silk.LOADED_CORE_PX, h), 1e-6, "a reeling line takes it too")
	check_near(silk.active_total_px, silk.active_core_px + 2.0 * Silk.scaled_px(Silk.RIM_PX, h), 1e-6, "and the whole strip is the core and a rim each side")
	tc.reel_override = 0.0


func test_the_line_is_depth_tested_like_any_object_so_the_world_hides_it() -> void:
	var code := SilkShader.code
	check(not ("depth_test_disabled" in code), "the shader never switches the depth test off: the world hides the line where it is in the way")
	check("depth_draw_never" in code, "and it does not write depth, so it never hides the world")
	check("unshaded" in code and "blend_mix" in code, "it is flat colour with alpha, the same everywhere")
	var spider := await _start(cliff_pose())
	var silk: Node3D = world.silk_lines
	check(await miss_off_the_cliff(spider), "hanging")
	var shaded := 0
	var strips := 0
	for child in silk.get_children():
		if child is MeshInstance3D:
			strips += 1
			if (child.material_override as ShaderMaterial).shader == SilkShader:
				shaded += 1
	check(strips == shaded and strips == 1 + Silk.POOL, "the active line and every pooled old line use that shader (%d of %d)" % [shaded, strips])


func test_the_hud_says_when_the_anchor_is_out_of_sight_and_stops_when_it_is_back_in_view() -> void:
	var spider := await _start(cliff_pose())
	var hud: CanvasLayer = world.jump_hud
	var rig: Node3D = world.camera_rig
	var space := world.get_world_3d().direct_space_state
	rig.line_framing = false   # the player's own view, set below
	check(await miss_off_the_cliff(spider), "caught and hanging below the cap's lip")
	_look_from_the_east(rig, 3.0)
	await physics_frames(45)
	await process_frames(2)
	var cam: Camera3D = rig.camera
	var screen := hud.get_viewport().get_visible_rect()
	check(cam.global_position.x > spider.global_position.x + 2.0, "the camera is east of the spider, beyond the lip (x %.2f)" % cam.global_position.x)
	check(JumpHud.point_hidden(cam, space, _anchor_probe(spider), screen), "from there the cap's edge hides the anchor")
	check_eq(hud.line_note_text(), JumpFeedback.ANCHOR_HIDDEN_BEND, "so the panel says it is anchored out of sight behind the edge the line passes over")
	check(hud.line_panel_visible(), "in the line's own panel")
	# Looking down from above the lip: the anchor is in view. The note stays for a moment (no flicker), then goes.
	_look_from_the_east(rig, 60.0)
	await physics_frames(6)
	check_eq(hud.line_note_text(), JumpFeedback.ANCHOR_HIDDEN_BEND, "a few ticks after the view changes the note is still there")
	await physics_frames(60)
	await process_frames(2)
	check(not JumpHud.point_hidden(cam, space, _anchor_probe(spider), screen), "from above the lip the anchor is in view (camera y %.2f, anchor y %.2f)" % [cam.global_position.y, spider.tether.anchor_point.y])
	check_eq(hud.line_note_text(), "", "and the note is gone")
	# And back: it takes a moment to come, too.
	_look_from_the_east(rig, 3.0)
	await physics_frames(5)
	check_eq(hud.line_note_text(), "", "not at once")
	await physics_frames(60)
	await process_frames(2)
	check_eq(hud.line_note_text(), JumpFeedback.ANCHOR_HIDDEN_BEND, "but it comes back when the anchor stays hidden")
	# Off the line there is no note.
	var tc: Node = world.tether_controller
	tc.reel_override = 1.0
	var events := record_line_events(spider)
	check(await wait_until(func() -> bool: return events.has("completed"), 900), "reeled in")
	tc.reel_override = 0.0
	await physics_frames(3)
	await process_frames(2)
	check_eq(hud.line_note_text(), "", "back on the cap there is no line and no note")
	check(not hud.line_panel_visible(), "and no panel")


func test_with_the_real_camera_and_no_camera_input_the_note_matches_what_the_camera_sees() -> void:
	var spider := await _start(cliff_pose())
	var hud: CanvasLayer = world.jump_hud
	var rig: Node3D = world.camera_rig
	var space := world.get_world_3d().direct_space_state
	check(await miss_off_the_cliff(spider), "caught and hanging")
	await wait_settled(spider)
	await physics_frames(90)
	await process_frames(2)
	var cam: Camera3D = rig.camera
	var screen := hud.get_viewport().get_visible_rect()
	var hidden := JumpHud.point_hidden(cam, space, _anchor_probe(spider), screen)
	check_eq(hud.line_note_text() != "", hidden, "the note is showing exactly when the anchor is hidden from the camera the player has (hidden: %s)" % str(hidden))
	check(hud.line_note_text() == "" or hud.line_note_text() == JumpFeedback.ANCHOR_HIDDEN_BEND, "and it is the note for a line over an edge")


func test_point_hidden_means_the_world_is_in_the_way_not_that_the_point_is_off_screen() -> void:
	var spider := await _start(cliff_pose())
	var space := world.get_world_3d().direct_space_state
	check(await miss_off_the_cliff(spider), "hanging")
	var screen := Rect2(0.0, 0.0, 1280.0, 720.0)
	var anchor := _anchor_probe(spider)
	var cam := Camera3D.new()
	sandbox.add_child(cam)
	cam.fov = 75.0
	# East of the cliff at the height of the spider, looking at the lip: the cap's edge is between the camera and the anchor.
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(30.0, 4.5, -7.0)).looking_at(anchor, Vector3.UP)
	check(JumpHud.point_hidden(cam, space, anchor, screen), "the cap hides its own top from below")
	# High above the cap, looking down at it: nothing in the way.
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(27.0, 14.0, -7.0)).looking_at(anchor, Vector3.UP)
	check(not JumpHud.point_hidden(cam, space, anchor, screen), "from above the same point is in plain view")
	# Looking the other way, the point is behind the camera: not hidden, just not in view.
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(30.0, 4.5, -7.0)).looking_at(Vector3(40.0, 4.5, -7.0), Vector3.UP)
	check(not JumpHud.point_hidden(cam, space, anchor, screen), "a point behind the camera is not reported as hidden")
	# Off to the side of the picture while the world would be in the way if it were looked at: not hidden either.
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(30.0, 4.5, -7.0)).looking_at(Vector3(30.0, 4.5, 20.0), Vector3.UP)
	check(not JumpHud.point_hidden(cam, space, anchor, screen), "a point outside the picture is not reported as hidden")
	check(not JumpHud.point_hidden(null, space, anchor, screen), "no camera: not hidden")
	cam.queue_free()


## One catch off the cliff cap, tick by tick until a second after the catch: the physics body's path, the model's offset from
## it and (while it recoils) how far the drawn line's end is from the spinnerets.
func _catch_run(recoil: bool) -> Dictionary:
	var spider := await _start(cliff_pose())
	var model: Node3D = spider.get_node("Body")
	model.recoil_enabled = recoil
	var silk: Node3D = world.silk_lines
	var events := record_line_events(spider)
	var plan: RefCounted = spider.plan_jump(top_target(27.3, -7.0))
	check(spider.begin_prepare() and spider.commit_jump(plan), "leaping toward the practice perch (recoil %s)" % str(recoil))
	var trace: Array[Vector3] = []
	var peak := 0.0
	var caught_tick := -1
	var follow_checks := 0
	var follow_worst := 0.0
	var i := 0
	while i < 400 and (caught_tick < 0 or i < caught_tick + 60):
		await physics_frames(1)
		trace.append(spider.global_position)
		if caught_tick < 0 and events.has("caught"):
			caught_tick = i
		# The separate launch lead-in is not catch recoil. Measure after it ends.
		if model.launch_time < 0.0:
			peak = maxf(peak, model.position.length())
		if model.is_recoiling() and spider.tether.is_active():
			silk.refresh()
			var end: Vector3 = silk.shown_points[silk.shown_points.size() - 1]
			follow_worst = maxf(follow_worst, absf(end.distance_to(spider.line_end_point()) - model.recoil_offset.length()))
			follow_checks += 1
		i += 1
	return {"trace": trace, "peak": peak, "caught_tick": caught_tick, "rest": model.position, "recoiling": model.is_recoiling(), "follow_checks": follow_checks, "follow_worst": follow_worst}


func test_the_catch_recoil_moves_only_the_model_and_the_silk_follows_it() -> void:
	var with: Dictionary = await _catch_run(true)
	world.free()
	var without: Dictionary = await _catch_run(false)
	check(with["caught_tick"] >= 0 and without["caught_tick"] >= 0, "the line caught the spider both times")
	check_eq(with["caught_tick"], without["caught_tick"], "at the same tick")
	var peak: float = with["peak"]
	check(peak > 0.03 and peak <= 0.09 + 1e-6, "with the recoil the model is thrown a little way, no further than %.2f WU (%.3f)" % [0.09, peak])
	check_eq(with["rest"], Vector3.ZERO, "and it ends exactly where it was")
	check(not with["recoiling"], "and the recoil is over")
	check_eq(float(without["peak"]), 0.0, "with it off the model never moves")
	var a: Array[Vector3] = with["trace"]
	var b: Array[Vector3] = without["trace"]
	check_eq(a.size(), b.size(), "the same number of ticks")
	var worst := 0.0
	for k in mini(a.size(), b.size()):
		worst = maxf(worst, a[k].distance_to(b[k]))
	check(worst < 1e-6, "the physics body takes exactly the same path with and without it (worst difference %f WU)" % worst)
	check(int(with["follow_checks"]) >= 5, "the drawn line was checked for %d ticks of the recoil" % int(with["follow_checks"]))
	check(float(with["follow_worst"]) < 1e-4, "its end goes with the model: within %f WU" % float(with["follow_worst"]))
