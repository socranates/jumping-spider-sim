extends SceneTree
# Golden values are computed by frozen Godot code; seeded input stream is exported, not reimplemented.
const M=preload("res://scripts/prey/prey_math.gd")
func v(p: Vector3) -> Array: return [p.x,p.y,p.z]
func _init() -> void:
 if not FileAccess.file_exists("res://roblox_port/tools/export_prey_reference.gd.uid"):
  var uid=FileAccess.open("res://roblox_port/tools/export_prey_reference.gd.uid",FileAccess.WRITE)
  uid.store_string(ResourceUID.id_to_text(ResourceUID.create_id())+"\n")
  uid.close()
 var rng=RandomNumberGenerator.new()
 rng.seed=72819
 var rows=[]
 for i in 128:
  var a=Vector3(rng.randf_range(-8,8),rng.randf_range(0,6),rng.randf_range(-8,8))
  var b=Vector3(rng.randf_range(-8,8),rng.randf_range(0,6),rng.randf_range(-8,8))
  var c=Vector3(rng.randf_range(-8,8),rng.randf_range(0,6),rng.randf_range(-8,8))
  var d=Vector3(rng.randf_range(-8,8),rng.randf_range(0,6),rng.randf_range(-8,8))
  var dt=rng.randf_range(.01,.25)
  var dist=rng.randf_range(.05,18)
  var motion=rng.randf_range(0,90)
  var off=rng.randf_range(0,180)
  var aw=rng.randf_range(0,1.5)
  var gain=M.awareness_gain_per_s(motion,10,6,M.distance_weight(dist,3,14),M.facing_weight(off,90,150,.12),2.0/3,1.5)
  var points=PackedVector3Array([a,b,c,d])
  var s=rng.randf_range(0,50)
  rows.append({"a":v(a),"b":v(b),"c":v(c),"d":v(d),"dt":dt,"dist":dist,"motion":motion,"off":off,"aw":aw,"s":s,
   "sweep":M.sweep_closest(a,b,c,d),"angle":M.apparent_angle(.3,dist),"bearing":M.bearing_rate_deg_s(a,b,dt),
   "gain":gain,"aw_next":M.integrate_awareness(aw,gain,dt,.35,1.5),"threat":M.threat_input(aw,.1,1),
   "length":M.path_length(points),"point":v(M.point_at(points,s)),"path_distance":M.distance_to_path(points,Vector3.ZERO),
   "target":M.target_speed(dist,15,2,1.2),"speed":M.step_speed(s,15,80,dt)})
 var f=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
 f.store_string(JSON.stringify({"source":"frozen scripts/prey/prey_math.gd", "seed":72819,"rows":rows},"  ",true,true))
 f.close()
 print("PREY golden rows: ",rows.size())
 quit()
