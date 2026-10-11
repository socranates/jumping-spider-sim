extends "res://tests/test_case.gd"
const Legs = preload("res://scripts/presentation/spider_legs.gd")

func test_rendered_rods_join_at_knees_and_end_at_the_reported_feet() -> void:
	var legs := Legs.new()
	sandbox.add_child(legs)
	for mode in 5:
		legs.advance_pose(0.07, Vector3.ZERO if mode == 4 else Vector3(1, 0, -2), mode != 2, mode == 1, mode == 3)
		var feet := legs.foot_positions()
		for i in 8:
			var upper: MeshInstance3D = legs.get_child(i * 2)
			var lower: MeshInstance3D = legs.get_child(i * 2 + 1)
			var hip := Vector3((-1.0 if i < 4 else 1.0) * 0.16, 0.02, Legs.HIP_Z[i % 4])
			check_vec_near(upper.transform * Vector3(0, -0.5, 0), hip, 1e-6, "upper rod starts at the hip")
			check_vec_near(upper.transform * Vector3(0, 0.5, 0), lower.transform * Vector3(0, -0.5, 0), 1e-6, "rods meet at the knee")
			check_vec_near(lower.transform * Vector3(0, 0.5, 0), feet[i], 1e-6, "lower rod ends at the foot")
	legs.free()

func test_cosmetic_pose_is_bounded_and_does_not_move_its_parent() -> void:
	var parent := Node3D.new()
	var legs := Legs.new()
	parent.add_child(legs)
	parent.transform = Transform3D(Basis(Vector3.FORWARD, 1.0), Vector3(4, 5, 6))
	sandbox.add_child(parent)
	var before := parent.transform
	for i in 240:
		legs.advance_pose(1.0 / 60.0, Vector3(0, 0, -3))
		var feet := legs.foot_positions()
		check_eq(feet.size(), 8, "eight feet")
		for foot in feet:
			check(foot.is_finite() and foot.length() < 1.5, "bounded finite foot")
	check(parent.transform == before, "no parent transform changes, including rotated support frame")
	check_eq(legs.get_child_count(), 16, "fixed sixteen segments, no per-frame node growth")
	for segment in legs.get_children():
		check(segment.transform.is_finite(), "rendered segment transform is finite")
	parent.free()

func test_reduced_motion_and_idle_restore_neutral_pose() -> void:
	var legs := Legs.new()
	legs.reset_pose()
	var neutral := legs.foot_positions()
	legs.advance_pose(0.1, Vector3(0, 0, -3))
	check(legs.foot_positions() != neutral, "walking moves feet")
	legs.advance_pose(0.1, Vector3(0, 0, -3), true, false, true)
	check(legs.foot_positions() == neutral, "reduced motion restores neutral pose")
	legs.advance_pose(0.1, Vector3.ZERO, false)
	check(legs.foot_positions() != neutral, "airborne folds legs")
	legs.advance_pose(0.1, Vector3.ZERO)
	check(legs.foot_positions() == neutral, "idle is stable")
	legs.advance_pose(NAN, Vector3.ZERO)
	legs.advance_pose(0.1, Vector3(INF, 0, 0))
	check(legs.foot_positions() == neutral, "invalid samples cannot poison geometry")
	legs.free()

func test_gait_phase_uses_distance_not_render_frame_count() -> void:
	var slow := Legs.new()
	var fast := Legs.new()
	for i in 30:
		slow.advance_pose(1.0 / 30.0, Vector3(0, 0, -0.37))
	for i in 144:
		fast.advance_pose(1.0 / 144.0, Vector3(0, 0, -0.37))
	for i in 8:
		check(slow.foot_positions()[i].distance_to(fast.foot_positions()[i]) < 0.00001, "matching pose at 30/144 samples")
	slow.free()
	fast.free()
