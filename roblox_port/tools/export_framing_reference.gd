extends SceneTree
## Exports the camera's line framing (A-017, chunk 6B) from the frozen Godot reference (c87ce00) for
## roblox_port/tests/framing_reference.json: BoomMath.smooth_damp, the turn search (camera_rig._wanted_yaw_assist) and
## tick-by-tick sequences of camera_rig._update_assist with a look, a recenter, aiming, the setting and the line ending
## taking the turn over. Godot's own code runs. Only _good_view (world queries) is replaced by a table of good turns, so
## the decisions are checked apart from geometry; the port checks geometry in Studio (tests/studio/CameraSpec.luau).
## Run from the repo root: godot --headless --path . -s roblox_port/tools/export_framing_reference.gd -- out.json
const BoomMath = preload("res://scripts/movement/boom_math.gd")

class StubSettings extends Node:
	var look_sensitivity := 1.0
	var invert_x := false
	var invert_y := false
	var camera_distance := 5.0
	var frame_line := true
	func get_value(key: String) -> Variant:
		if key == "frame_line_after_catch":
			return frame_line
		return false

class StubTarget extends Node3D:
	var on_line := true
	func is_on_line() -> bool:
		return on_line
	func get_line_rest_point() -> Vector3:
		return Vector3(0.0, -3.0, 0.0)
	func get_line_lip() -> Vector3:
		return Vector3.ZERO
	func get_visual_up() -> Vector3:
		return Vector3.UP

class TableRig extends "res://scripts/movement/camera_rig.gd":
	var good_yaws: Array = []  # absolute yaws (radians) that frame the recovery
	func _good_view(_from: Vector3, yaw_angle: float, _spot: Vector3, _lip: Vector3) -> bool:
		for g in good_yaws:
			if absf(angle_difference(yaw_angle, float(g))) < 1e-6:
				return true
		return false

const DT := 1.0 / 60.0


func _rig(yaw0: float, good_turns: Array) -> Node:
	var rig = TableRig.new()
	rig.settings = StubSettings.new()
	rig.target = StubTarget.new()
	rig.yaw = yaw0
	rig.good_yaws = good_turns.map(func(t): return yaw0 + float(t))
	return rig


func _free(rig: Node) -> void:
	rig.target.free()
	rig.settings.free()
	rig.free()


## One physics tick of the framing, as camera_rig._physics_process runs it.
func _tick(rig: Node) -> void:
	rig._assist_prev = rig.yaw_assist
	rig._update_assist(DT)


func _state(rig: Node) -> Array:
	return [rig.yaw, rig.yaw_assist, rig._assist_target, 1.0 if rig._assist_off else 0.0]


func _initialize() -> void:
	var out := {"source_commit": "c87ce00", "source": "scripts/movement/camera_rig.gd, boom_math.gd", "engine": Engine.get_version_info()["string"], "dt": DT}
	var damps := []
	for c in [[0.0, 0.5236, 0.0, 0.12, DT], [0.2, 0.5236, 1.5, 0.12, DT], [0.5, 0.5236, 0.3, 0.12, DT], [0.5236, 0.5236, 0.0, 0.12, DT],
			[-0.3, 0.0, -2.0, 0.12, DT], [0.0, 0.7854, 0.0, 0.12, 0.1], [0.4, 0.0, 0.0, 0.12, DT], [0.52359, 0.5236, 0.0001, 0.12, DT]]:
		var r: PackedFloat64Array = BoomMath.smooth_damp(c[0], c[1], c[2], c[3], c[4])
		damps.append({"in": c, "out": [r[0], r[1]]})
	out["smooth_damp"] = damps
	# The turn search: good turns relative to the player's yaw, the turn already held, the cap.
	var d30 := deg_to_rad(30.0)
	var decisions := []
	for c in [[[d30], 0.0, 45.0], [[deg_to_rad(90.0)], 0.0, 45.0], [[deg_to_rad(90.0)], 0.0, 180.0], [[deg_to_rad(45.0)], 0.0, 45.0],
			[[deg_to_rad(60.0)], 0.0, 45.0], [[deg_to_rad(-15.0), d30], 0.0, 45.0], [[deg_to_rad(15.0), deg_to_rad(-15.0)], 0.0, 45.0],
			[[deg_to_rad(15.0), d30], d30, 45.0], [[0.0, d30], 0.0, 45.0], [[], 0.0, 45.0], [[deg_to_rad(-45.0)], 0.0, 45.0],
			[[deg_to_rad(15.0)], d30, 45.0]]:
		var rig = _rig(0.3, c[0])
		rig._assist_target = float(c[1])
		rig.framing_max_turn = deg_to_rad(float(c[2]))
		decisions.append({"good": c[0], "held": c[1], "cap_deg": c[2], "out": rig._wanted_yaw_assist()})
		_free(rig)
	out["decisions"] = decisions
	var seqs := {}
	# Caught with a view 30 degrees off: the turn eases in and holds; a one-degree look takes it over at once and the
	# framing stays off; the line ends and nothing moves.
	var rig = _rig(-0.5235987755982988, [d30])
	var rows := []
	for i in 40:
		_tick(rig)
		rows.append(_state(rig))
	rig._assist_prev = rig.yaw_assist
	rig.look(1.0, 0.0)
	rows.append(_state(rig))
	for i in 20:
		_tick(rig)
		rows.append(_state(rig))
	rig.target.on_line = false
	_tick(rig)
	rows.append(_state(rig))
	seqs["look_takes_over"] = rows
	_free(rig)
	# A turn in progress, then aiming takes it over; after aiming the view is already good, so nothing turns again.
	rig = _rig(0.1, [d30])
	rows = []
	for i in 3:
		_tick(rig)
		rows.append(_state(rig))
	rig._assist_prev = rig.yaw_assist
	rig.set_aiming(true)
	rows.append(_state(rig))
	for i in 5:
		_tick(rig)
		rows.append(_state(rig))
	rig.set_aiming(false)
	for i in 10:
		_tick(rig)
		rows.append(_state(rig))
	seqs["aim_takes_over"] = rows
	_free(rig)
	# A recenter takes a held turn over (and the recenter then turns as usual; only the hand-over is recorded).
	rig = _rig(0.0, [d30])
	rows = []
	for i in 30:
		_tick(rig)
		rows.append(_state(rig))
	rig._assist_prev = rig.yaw_assist
	rig.start_recenter()
	rows.append(_state(rig))
	seqs["recenter_takes_over"] = rows
	_free(rig)
	# The line ends with a turn held: the turn becomes the player's yaw.
	rig = _rig(0.7, [deg_to_rad(-45.0)])
	rows = []
	for i in 30:
		_tick(rig)
		rows.append(_state(rig))
	rig.target.on_line = false
	_tick(rig)
	rows.append(_state(rig))
	_tick(rig)
	rows.append(_state(rig))
	seqs["line_end_keeps_view"] = rows
	_free(rig)
	# "Frame the line after a catch" off from the start: nothing turns.
	rig = _rig(0.0, [d30])
	rig.settings.frame_line = false
	rows = []
	for i in 10:
		_tick(rig)
		rows.append(_state(rig))
	seqs["setting_off"] = rows
	_free(rig)
	out["sequences"] = seqs
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", true, true))
	f.close()
	print("exported framing reference")
	quit()
