extends "res://tests/perception_test_case.gd"
## What the player is shown (spec 7, 17; T06; A-002): a soft marker on the screen's edge for a peripheral cue, a category in
## plain words at the observed place, "lost sight" there when it goes, a faint last-seen mark that goes stale, and nothing for
## what was never sensed. build_view is a pure function of the memory, the camera and the settings, so most checks read the
## picture as data; a few go through the real nodes.

const PerceptionHud = preload("res://scripts/presentation/perception_hud.gd")
const PerceptionText = preload("res://scripts/presentation/perception_text.gd")

const AWAY := Vector3(1.0, 0.0, -0.2)   # a world direction well away from the west spot (toward the east)


func rect() -> Rect2:
	return world.get_viewport().get_visible_rect()


func view() -> Dictionary:
	return world.perception_hud.build_view(world.camera_rig.camera, rect(), world.get_world_3d().direct_space_state)


func texts_of(v: Dictionary, kind: String) -> Array[String]:
	var out: Array[String] = []
	for l: Dictionary in v["labels"]:
		if str(l["kind"]) == kind:
			out.append(str(l["text"]))
	return out


## The classified marker in plain view dead ahead, the spider's body turned away from it with Focus (through the controller,
## as a player would), until it is lost. The marker stands still where it was classified.
func classify_then_look_away() -> void:
	await spawn_stage(true, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(70)
	world.controller.focus_override = true
	world.controller.focus_direction_override = AWAY.normalized()
	await wait_until(func() -> bool: return target_contact() != null and not target_contact().is_live(), 120)


# ------------------------------------------------------------------ the pure parts

func test_the_edge_marker_sits_on_the_side_of_the_bearing_inside_the_screen() -> void:
	var cam := Camera3D.new()
	sandbox.add_child(cam)
	var r := Rect2(0.0, 0.0, 1280.0, 720.0)
	var right: Dictionary = PerceptionHud.edge_marker(cam, r, Vector3.RIGHT)
	check((right["pos"] as Vector2).x > 1200.0 and absf((right["pos"] as Vector2).y - 360.0) < 5.0, "a bearing to the right is at the right edge, mid-height (%s)" % str(right["pos"]))
	var left: Dictionary = PerceptionHud.edge_marker(cam, r, Vector3.LEFT)
	check((left["pos"] as Vector2).x < 80.0, "to the left, the left edge")
	var up: Dictionary = PerceptionHud.edge_marker(cam, r, Vector3.UP)
	check((up["pos"] as Vector2).y < 60.0, "overhead, the top edge")
	var down: Dictionary = PerceptionHud.edge_marker(cam, r, Vector3.DOWN)
	check((down["pos"] as Vector2).y > 660.0, "underfoot, the bottom edge")
	var behind: Dictionary = PerceptionHud.edge_marker(cam, r, Vector3(0.7, 0.0, 0.7))
	check(behind["behind"] == true and (behind["pos"] as Vector2).x > 1000.0, "a bearing behind the camera is still marked, on its own side, and says it is behind")
	var ahead: Dictionary = PerceptionHud.edge_marker(cam, r, Vector3.FORWARD)
	check((ahead["pos"] as Vector2).y < 60.0, "a bearing straight along the view has no side and goes on the top edge")
	for d in [Vector3(1.0, 0.4, -0.3), Vector3(-0.2, -1.0, 0.1), Vector3(0.3, 0.3, 1.0)]:
		var m: Dictionary = PerceptionHud.edge_marker(cam, r, d)
		check(r.grow(-PerceptionHud.EDGE_MARGIN + 0.01).has_point(m["pos"]), "every marker is inside the screen by its margin (%s)" % str(m["pos"]))
		check_near((m["dir"] as Vector2).length(), 1.0, 1e-6, "and carries a unit direction")


func test_an_edge_marker_rises_quickly_fades_slowly_and_is_gone_after_a_moment() -> void:
	check_eq(PerceptionHud.edge_fade(-0.1), 0.0, "nothing before the cue")
	check_eq(PerceptionHud.edge_fade(PerceptionHud.CUE_SHOW_S), 0.0, "nothing once its time is up")
	check_eq(PerceptionHud.edge_fade(5.0), 0.0, "nor long after")
	check(PerceptionHud.edge_fade(0.0) < 0.01, "it starts from nothing (no pop)")
	check(PerceptionHud.edge_fade(PerceptionHud.CUE_RISE_S) > 0.8, "and is strong by the end of its rise")
	var last := PerceptionHud.edge_fade(PerceptionHud.CUE_RISE_S)
	var falling := true
	var t := PerceptionHud.CUE_RISE_S + 0.05
	while t < PerceptionHud.CUE_SHOW_S:
		var f := PerceptionHud.edge_fade(t)
		if f > last + 1e-9:
			falling = false
		last = f
		t += 0.05
	check(falling, "then it only fades")
	check(PerceptionHud.EDGE_ALPHA <= 0.65, "and even at its strongest it is soft (%.2f)" % PerceptionHud.EDGE_ALPHA)


func test_a_ring_is_as_large_as_the_thing_looks_between_a_readable_minimum_and_a_maximum() -> void:
	var cam := Camera3D.new()
	sandbox.add_child(cam)
	cam.global_position = Vector3.ZERO
	var near := PerceptionHud.ring_radius_px(cam, Vector3(0.0, 0.0, -1.0), 0.9)
	var far := PerceptionHud.ring_radius_px(cam, Vector3(0.0, 0.0, -80.0), 0.9)
	check_near(far, PerceptionHud.RING_MIN_PX, 1e-6, "far away it is as small as it ever gets")
	check_near(near, PerceptionHud.RING_MAX_PX, 1e-6, "close by it is as large as it ever gets")
	var mid := PerceptionHud.ring_radius_px(cam, Vector3(0.0, 0.0, -20.0), 0.9)
	check(mid > far and mid < near, "in between it follows how big the thing looks (%.1f px)" % mid)


# ------------------------------------------------------------------ a cue

func test_a_cue_is_a_soft_marker_on_the_edge_toward_it_that_fades_away() -> void:
	await spawn_stage(true, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([EAST_VISIBLE, EAST_VISIBLE + Vector3(2.0, 0.0, 0.0)])))
	var seen := await wait_until(func() -> bool: return world.sensor.cues_made >= 1, 120)
	if not check(seen, "the marker walks in the periphery and a cue is made"):
		return
	await physics_frames(10)   # the marker rises over the first 0.12 s
	var v := view()
	check_eq((v["edges"] as Array).size(), 1, "one edge marker")
	check(v["labels"].is_empty() and v["rings"].is_empty(), "and nothing else: a cue has no place and no name")
	if (v["edges"] as Array).is_empty():
		return
	var e: Dictionary = v["edges"][0]
	var c := rect().get_center()
	check((e["pos"] as Vector2).x > c.x + 200.0 and (e["dir"] as Vector2).x > 0.3, "it is on the right, the side the cue came from (at %s)" % str(e["pos"]))
	check(rect().grow(-PerceptionHud.EDGE_MARGIN + 0.01).has_point(e["pos"]), "inside the screen, by the margin")
	check(float(e["alpha"]) > 0.0 and float(e["alpha"]) <= PerceptionHud.EDGE_ALPHA + 1e-6, "soft (%.2f)" % float(e["alpha"]))
	var cue: RefCounted = target_contact()
	check_near(float(e["alpha"]), PerceptionHud.EDGE_ALPHA * PerceptionHud.edge_fade(mem().cue_age_s(cue)), 1e-6, "its strength is that of a cue of that age")
	check(world.get_viewport().get_camera_3d() == world.camera_rig.camera, "seen through the player's camera")
	# The thing leaves the world: no more cues, and the marker fades out by itself.
	target().set_enabled(false)
	await physics_frames(int(PerceptionHud.CUE_SHOW_S * 60.0) + 12)
	check(view()["edges"].is_empty(), "with no new cue it is gone after %.1f s" % PerceptionHud.CUE_SHOW_S)
	check(texts_of(view(), "category").is_empty() and texts_of(view(), "lost").is_empty(), "and it never had words")


func test_the_marker_follows_the_camera_not_the_body() -> void:
	await spawn_stage(true, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([EAST_VISIBLE, EAST_VISIBLE + Vector3(2.0, 0.0, 0.0)])))
	await wait_until(func() -> bool: return world.sensor.cues_made >= 1, 120)
	var before: Dictionary = view()["edges"][0]
	check((before["pos"] as Vector2).x > rect().get_center().x, "to the right of a camera looking the way the body does")
	world.camera_rig.look(100.0, 0.0)
	await physics_frames(3)
	await process_frames(3)
	var after: Dictionary = view()["edges"][0]
	check((after["pos"] as Vector2).x < rect().get_center().x, "after the camera looks away to the right, the same cue is on the left of the view (%s)" % str(after["pos"]))


# ------------------------------------------------------------------ what is inspected

func test_a_thing_being_inspected_has_a_ring_and_words_and_no_edge_marker() -> void:
	await spawn_stage(true, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([WEST_VISIBLE, WEST_VISIBLE + Vector3(1.0, 0.0, 0.0)])))
	await wait_until(func() -> bool: return world.sensor.cues_made >= 1, 120)
	await physics_frames(10)
	check_eq((view()["edges"] as Array).size(), 1, "first only a cue: an edge marker")
	# The body turns to it (Focus through the controller) and the cone has it.
	world.controller.focus_override = true
	world.controller.focus_direction_override = toward(WEST_VISIBLE + Vector3(0.5, 0.0, 0.0))
	await wait_until(func() -> bool: return target_contact().is_inspected_now(), 120)
	await physics_frames(5)
	var v := view()
	check_eq((v["rings"] as Array).size(), 1, "now it is inspected: a ring")
	check(not (v["labels"] as Array).is_empty(), "and words")
	check((v["edges"] as Array).is_empty(), "and the old bearing is no longer marked at the edge: the finer evidence has taken over")


func test_the_words_get_finer_in_order_and_never_carry_a_number() -> void:
	await spawn_stage(true, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	var seen: Array[String] = []
	var numbers := false
	var placed := true
	for i in 100:
		await physics_frames(1)
		var v := view()
		for l: Dictionary in v["labels"]:
			var text := str(l["text"])
			if seen.is_empty() or seen[seen.size() - 1] != text:
				seen.append(text)
			if PerceptionText.has_number(text):
				numbers = true
			if not rect().has_point(l["pos"]):
				placed = false
	check_eq(seen, ["movement", "possible prey", "fly-like prey"] as Array[String], "the words refine, in that order, once each")
	check(not numbers, "none of them has a digit or a percent sign")
	check(placed, "and each sits inside the screen")
	var v := view()
	check_eq((v["rings"] as Array).size(), 1, "one ring")
	check_eq(str(v["rings"][0]["kind"]), "live", "a live one")
	check((v["labels"][0]["pos"] as Vector2).y < (v["rings"][0]["pos"] as Vector2).y, "the words are above the ring")
	var c := target_contact()
	var proj: Vector2 = world.camera_rig.camera.unproject_position(c.position)
	check((v["rings"][0]["pos"] as Vector2).distance_to(proj) < 0.5, "the ring is at where the thing is observed, as the camera sees it")
	await process_frames(2)
	check_eq(world.perception_hud.label_texts(), PackedStringArray(["fly-like prey"]), "the label node shows the same words")


func test_a_word_stays_with_the_spot_it_was_observed_at_when_the_camera_moves() -> void:
	await spawn_stage(true, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(70)
	var c := target_contact()
	var a: Dictionary = view()["labels"][0]
	world.camera_rig.look(25.0, 0.0)
	await process_frames(3)
	var b: Array = view()["labels"]
	check(b.is_empty() or (b[0]["pos"] as Vector2).distance_to(a["pos"]) > 20.0, "the label went with the world: the camera turned and it is not where it was on the screen")
	var proj: Vector2 = world.camera_rig.camera.unproject_position(c.position)
	if not b.is_empty():
		check((b[0]["pos"] as Vector2).distance_to(proj) < 80.0, "it is still at the place it was observed")


# ------------------------------------------------------------------ what is lost

func test_losing_sight_says_so_where_it_was_and_the_mark_fades_and_breaks_up() -> void:
	await spawn_stage(true, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(70)
	var live: Dictionary = view()["rings"][0]
	var live_words := texts_of(view(), "category")
	check_eq(live_words, ["fly-like prey"] as Array[String], "classified")
	world.controller.focus_override = true
	world.controller.focus_direction_override = AWAY.normalized()
	var lost := await wait_until(func() -> bool: return not target_contact().is_live(), 120)
	check(lost, "the body turns away and the thing is lost")
	var c := target_contact()
	var v := view()
	check_eq(texts_of(v, "lost"), ["lost sight"] as Array[String], "it says so, in words")
	check(texts_of(v, "category").is_empty(), "and no longer names it")
	check_eq((v["rings"] as Array).size(), 1, "one ring: the mark")
	var mark: Dictionary = v["rings"][0]
	check_eq(str(mark["kind"]), "mark", "which is a mark")
	check((mark["pos"] as Vector2).distance_to(live["pos"]) < 1.5, "at the same place on the screen as the ring was (%.2f px apart)" % (mark["pos"] as Vector2).distance_to(live["pos"]))
	check(float(mark["alpha"]) < float(live["alpha"]) and float(mark["alpha"]) > 0.4, "fainter than a live ring (%.2f)" % float(mark["alpha"]))
	check(float(mark["dash"]) > 0.9, "and still unbroken")
	var first_alpha := float(mark["alpha"])
	var first_dash := float(mark["dash"])
	var last_alpha := first_alpha
	var last_dash := first_dash
	var steady := true
	var words_alpha := float(v["labels"][0]["alpha"])
	var words_fall := true
	var spot := (mark["pos"] as Vector2)
	var drifted := 0.0
	var ticks := 0
	while ticks < 330 and not mem().marks().is_empty():
		await physics_frames(10)
		ticks += 10
		var w := view()
		var rings: Array = w["rings"]
		if rings.is_empty():
			break
		var ring: Dictionary = rings[0]
		if float(ring["alpha"]) > last_alpha + 1e-6 or float(ring["dash"]) > last_dash + 1e-6:
			steady = false
		last_alpha = float(ring["alpha"])
		last_dash = float(ring["dash"])
		drifted = maxf(drifted, (ring["pos"] as Vector2).distance_to(spot))
		var lost_words: Array[String] = texts_of(w, "lost")
		if not lost_words.is_empty():
			var a := float((w["labels"] as Array)[0]["alpha"])
			if a > words_alpha + 1e-6:
				words_fall = false
			words_alpha = a
		if ticks == 150:
			check(texts_of(w, "lost").is_empty(), "after 2.5 s the words are gone")
			check(not (w["rings"] as Array).is_empty(), "and the mark is still there")
	check(steady, "the mark only grows fainter and more broken")
	check(words_fall, "and the words only fade")
	check(drifted < 1.5, "it never moved on the screen while the camera stood still (%.2f px)" % drifted)
	check(last_alpha < 0.5 * first_alpha, "by the end it is much fainter (%.2f from %.2f)" % [last_alpha, first_alpha])
	check(last_dash < 0.6 * first_dash, "and much more broken (%.2f from %.2f)" % [last_dash, first_dash])
	await physics_frames(60)
	check((view()["rings"] as Array).is_empty() and (view()["labels"] as Array).is_empty(), "after six seconds there is nothing at all")
	check_eq(mem().count(), 0, "the memory let go of it")
	check(c.state == &"lost", "the record ended lost, not live")


func test_the_mark_can_be_switched_off_and_the_words_stay() -> void:
	await classify_then_look_away()
	check(target_contact().has_mark(), "a mark is held")
	check_eq((view()["rings"] as Array).size(), 1, "by default it is drawn")
	settings.set_value("show_last_seen", false)
	var v := view()
	check((v["rings"] as Array).is_empty(), "with the setting off no ring is drawn")
	check_eq(texts_of(v, "lost"), ["lost sight"] as Array[String], "though it still says it lost sight")
	check(target_contact().has_mark(), "the memory is not touched by a display setting")
	settings.set_value("show_last_seen", true)
	check_eq((view()["rings"] as Array).size(), 1, "and back on it is drawn again")


func test_a_mark_over_cover_is_drawn_fainter_and_never_at_where_the_thing_really_is() -> void:
	await spawn_stage(true, heading_toward(WEST_VISIBLE), WEST_VISIBLE)
	await physics_frames(70)
	var c := target_contact()
	var seen_ring: Dictionary = view()["rings"][0]
	check(not bool(seen_ring["covered"]), "while it is in plain view the ring is not covered")
	world.lab.add_fixture_piece("test_wall", "wall", Vector3(-30.0, 0.0, -5.0), Vector3(-23.0, 4.0, -4.8))
	await physics_frames(60)
	check(not c.is_live() and c.has_mark(), "the wall hides it from the spider: lost, with a mark")
	await process_frames(2)
	var v := view()
	check_eq((v["rings"] as Array).size(), 1, "the mark is still drawn, where it was last seen: it is memory")
	var ring: Dictionary = v["rings"][0]
	check(bool(ring["covered"]), "and it is flagged as covered by the world")
	check_near(float(ring["alpha"]), lerpf(PerceptionHud.MARK_ALPHA_FRESH, PerceptionHud.MARK_ALPHA_STALE, float(ring["stale"])) * PerceptionHud.MARK_COVERED_FACTOR, 1e-6, "fainter than the same mark in the open (%.2f)" % float(ring["alpha"]))
	check((ring["pos"] as Vector2).distance_to(world.camera_rig.camera.unproject_position(c.position)) < 0.5, "at the projection of the last observed position")
	check_eq(texts_of(v, "lost"), ["lost sight"] as Array[String], "and the words say the sight is lost")
	# The marker is moved right across the stage, behind the wall; the mark does not follow it.
	target().hold_at(Vector3(-22.0, 1.4, -7.9))
	await physics_frames(10)
	await process_frames(2)
	var after: Dictionary = view()["rings"][0]
	check((after["pos"] as Vector2).distance_to(ring["pos"]) < 0.5, "when the marker is moved elsewhere behind the wall the ring stays put")
	check((after["pos"] as Vector2).distance_to(world.camera_rig.camera.unproject_position(target().global_position)) > 30.0, "and is far from where the marker really is on the screen")
	world.lab.set_piece_enabled("test_wall", false)
	target().set_enabled(false)
	await physics_frames(3)
	check(not bool((view()["rings"] as Array)[0]["covered"]), "with the wall gone the place is in plain view again, and the ring is no longer covered")


# ------------------------------------------------------------------ what was never sensed

func test_a_thing_the_camera_sees_but_the_spider_never_sensed_gets_nothing() -> void:
	await spawn_stage(true, 0.0, null, func(t: Node3D) -> void:
		t.pause_s = 0.0
		t.set_path(PackedVector3Array([BEHIND_SPIDER, BEHIND_SPIDER + Vector3(2.0, 0.0, 0.0)])))
	world.camera_rig.look(180.0, 0.0)   # the player turns the camera right round to look back past the spider
	await physics_frames(120)
	await process_frames(2)
	var cam: Camera3D = world.camera_rig.camera
	var at: Vector3 = target().global_position
	check(not cam.is_position_behind(at) and rect().has_point(cam.unproject_position(at)), "the marker is in the camera's view, on the screen")
	check_eq(mem().count(), 0, "yet the spider has sensed nothing")
	var v := view()
	check(v["edges"].is_empty() and v["labels"].is_empty() and v["rings"].is_empty(), "so nothing is drawn for it (6.4: no overlay on what the camera sees alone)")
	check(world.perception_hud.label_texts().is_empty(), "and no label")
