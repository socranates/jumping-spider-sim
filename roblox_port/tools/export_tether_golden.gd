extends SceneTree
## Tool only: export the frozen Godot implementation, never the port under test.
const Tether = preload("res://scripts/movement/tether.gd")
func vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]
func _initialize() -> void:
	var cases := []
	for target in [Vector3.ZERO, Vector3(0,-1,0), Vector3(3,-4,0), Vector3(2,3,-6)]:
		for velocity in [Vector3.ZERO, Vector3(1,-3,2), Vector3(-2,4,1)]:
			var result := Tether.constrain(Vector3.ZERO, 2.0, target, velocity)
			result["position"] = vec(result["position"])
			result["velocity"] = vec(result["velocity"])
			cases.append({"target":vec(target),"velocity":vec(velocity),"length":2.0,"result":result})
	var out := {"source_commit":"c87ce00","source":"scripts/movement/tether.gd","engine":Engine.get_version_info().string,"cases":cases,
		"energy":Tether.energy(Vector3(0,3,0),Vector3(3,4,0),35),
		"work":Tether.reel_work_bound(0.025,35,4,2),"sag":Tether.sag_depth(3,4)}
	var file := FileAccess.open("res://roblox_port/tests/tether_reference.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(out,"\t")+"\n")
	var uid_path := "res://roblox_port/tools/export_tether_golden.gd.uid"
	if not FileAccess.file_exists(uid_path):
		var uid := FileAccess.open(uid_path,FileAccess.WRITE)
		uid.store_string(ResourceUID.id_to_text(ResourceUID.create_id())+"\n")
	print("Exported 12 frozen Godot tether cases")
	quit()
