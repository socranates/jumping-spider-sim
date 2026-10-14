extends SceneTree
## Exports camera/stick golden values from the frozen Godot reference for roblox_port/tests/camera_reference.json.
## Run from the repo root: godot --headless -s roblox_port/tools/export_camera_reference.gd -- out.json
const SurfaceInput = preload("res://scripts/movement/surface_input.gd")
const BoomMath = preload("res://scripts/movement/boom_math.gd")
const CameraRig = preload("res://scripts/movement/camera_rig.gd")

func v(x: Vector3) -> Array: return [x.x, x.y, x.z]

func _init() -> void:
	var out := {"source": "Godot %s, c87ce00 frozen reference" % Engine.get_version_info()["string"]}
	var normals := [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD,
		Vector3(1, 1, 0).normalized(), Vector3(0, 1, 1).normalized(), Vector3(0.3, -0.8, 0.52).normalized(), Vector3(0, 0.70710678, -0.70710678)]
	var views := [[0.0, 0.31], [1.1, 0.31], [-2.4, 0.9], [3.0, -0.3], [0.6, 1.3], [-0.9, 0.0]]
	var sticks := [Vector2(0, 1), Vector2(1, 0), Vector2(-0.6, 0.8), Vector2(0.3, -0.2), Vector2(2.0, 2.0)]
	var axes := []
	for n in normals:
		for view in views:
			var a: Dictionary = SurfaceInput.tangent_axes(view[0], view[1], n)
			var s := []
			for st in sticks:
				s.append(v(SurfaceInput.map_stick(st, view[0], view[1], n)))
			axes.append({"n": v(n), "yaw": view[0], "elev": view[1], "right": v(a["right"]), "forward": v(a["forward"]), "mapped": s})
	out["axes"] = axes
	out["sticks"] = sticks.map(func(st): return [st.x, st.y])
	var backs := []
	for view in views:
		var b := BoomMath.orbit_basis(view[0], view[1])
		backs.append({"yaw": view[0], "elev": view[1], "back": v(BoomMath.back_direction(view[0], view[1])), "x": v(b.x), "y": v(b.y)})
	out["backs"] = backs
	var lengths := []
	for c in [[0.0, 5.0, 5.0, 6.0, 1.0/60.0], [4.0, 1.2, 5.0, 6.0, 1.0/60.0], [1.0, 9.0, 5.0, 6.0, 1.0/60.0], [4.95, 9.0, 5.0, 6.0, 1.0/60.0], [2.0, -1.0, 5.0, 6.0, 0.1]]:
		lengths.append({"in": c, "out": BoomMath.next_length(c[0], c[1], c[2], c[3], c[4])})
	out["next_length"] = lengths
	var eases := []
	for c in [[0.0, 0.5, 1.0/60.0, 0.08, 0.35], [0.5, 0.0, 1.0/60.0, 0.08, 0.35], [0.3, 0.30001, 0.1, 0.08, 0.35], [-0.2, 0.4, 0.05, 0.25, 0.25]]:
		eases.append({"in": c, "out": BoomMath.ease_offset(c[0], c[1], c[2], c[3], c[4])})
	out["ease"] = eases
	var picks := []
	for c in [[[0.0, 0.17, 0.35], [1.0, 2.6, 4.0]], [[0.0, 0.17, 0.35], [1.0, 1.4, 1.2]], [[0.0, -0.17], [3.0, 1.0]]]:
		picks.append({"offsets": c[0], "lengths": c[1], "out": BoomMath.pick_pitch_offset(PackedFloat64Array(c[0]), PackedFloat64Array(c[1]), 2.5)})
	out["pick"] = picks
	var rig = CameraRig.new()
	rig.settings = null
	var clamps := []
	for c in [[0.0, 0.31], [1.2, 0.31], [-0.6, 0.31], [0.7, -0.2], [0.9, 1.3], [-0.5, -1.2]]:
		clamps.append({"in": c, "out": rig._clamp_aim_pitch(c[0], c[1])})
	out["aim_clamp"] = clamps
	var eff := []
	for c in [[0.31, 0.0], [0.31, 0.6], [0.31, 2.0], [0.31, -1.5], [1.5, 0.3], [-0.5, -0.5]]:
		rig.elevation = c[0]
		eff.append({"in": c, "out": rig._effective_elevation(c[1])})
	out["effective"] = eff
	var gazes := []
	for c in [[Vector3(0, 0, -1), Vector3.UP], [Vector3(0, 1, -0.05).normalized(), Vector3.UP], [Vector3(0.2, -0.99, 0.1).normalized(), Vector3.UP], [Vector3(1, 0.4, 0).normalized(), Vector3.RIGHT], [Vector3(0, -0.3, -1).normalized(), Vector3.DOWN]]:
		gazes.append({"g": v(c[0]), "up": v(c[1]), "out": v(rig._clamp_gaze(c[0], c[1]))})
	out["gaze_clamp"] = gazes
	var looks := []
	for c in [[Vector3(0, 0, -1), Vector3.UP, 0.3, 0.0], [Vector3(0, 0, -1), Vector3.UP, 0.0, 0.4], [Vector3(0.6, 0, -0.8), Vector3.UP, -0.5, -0.2], [Vector3(0, 0.2, -1).normalized(), Vector3.RIGHT, 0.4, 0.3], [Vector3(0, 0, -1), Vector3.UP, 0.0, -1.5]]:
		rig.gaze = c[0]
		rig._gaze_up = c[1]
		rig._look_eye(c[2], c[3])
		looks.append({"g": v(c[0]), "up": v(c[1]), "yaw": c[2], "pitch": c[3], "out": v(rig.gaze)})
	out["look_eye"] = looks
	rig.free()
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", true, true))
	f.close()
	print("exported")
	quit()
