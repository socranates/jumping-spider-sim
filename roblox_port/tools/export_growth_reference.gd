extends SceneTree
## Runs frozen growth.gd, including a mid-moult restore and invalid input; no port formulas generate the expectations.
const Growth = preload("res://scripts/life/growth.gd")
func _init() -> void:
 var g := Growth.new()
 var rows := []
 var actions := [{"kind":"eat","n":-1.0},{"kind":"eat","n":0.89},{"kind":"begin","n":0.0},{"kind":"eat","n":0.011}]
 for stage in range(3):
  if stage > 0:
   actions.append({"kind":"eat","n":0.9})
  actions.append_array([{"kind":"begin","n":0.0},{"kind":"eat","n":10.0},{"kind":"hours","n":3.0},{"kind":"restore","n":0.0},{"kind":"hours","n":9.1},{"kind":"hours","n":4.0},{"kind":"hours","n":6.0}])
 actions.append_array([{"kind":"eat","n":10.0},{"kind":"begin","n":0.0},{"kind":"hours","n":50.0}])
 for a: Dictionary in actions:
  var result: Variant = null
  match a.kind:
   "eat": result=g.eat(a.n)
   "begin": result=g.begin_moult()
   "hours": result=g.pass_hours(a.n,Vector3(-25.5,0.31,6.0))
   "restore":
    var record:=g.to_dict()
    g=Growth.new()
    g.load_dict(record)
  rows.append({"action":a,"result":result,"record":g.to_dict(),"reach":g.reach_factor(),"softness":g.softness(),"name":g.stage_name()})
 var f:=FileAccess.open("res://roblox_port/tests/growth_reference.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(rows,"  ")+"\n")
 print("GROWTH_REFERENCE: ",rows.size()," transitions")
 quit()
