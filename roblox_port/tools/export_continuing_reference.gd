extends SceneTree
## Golden thresholds/drain/progress from the frozen Godot implementation, not reimplemented formulas.
const Ref = preload("res://roblox_port/tools/export_life_reference.gd")
const Loop = preload("res://scripts/habitat/habitat_loop.gd")
const Needs = preload("res://scripts/needs/needs_model.gd")
const Progress = preload("res://scripts/life/progress.gd")
func _init() -> void:
 var rows := []
 for gentle: bool in [false, true]:
  for streak: float in [0.0,23.99,24.0,47.99,48.0,72.0]:
   var w := Ref.FakeWorld.new()
   w.needs.gentle = gentle
   w.needs.starving_streak_h = streak
   var loop := Loop.new()
   loop.world = w
   rows.append({"gentle":gentle,"streak":streak,"weak":loop.too_hungry_to_sleep(),"dead":loop.starved()})
   loop.free()
   w.free()
 var drain := []
 for gentle: bool in [false,true]:
  for hours: float in [2.0,10.0,48.0,400.0]:
   var n := Needs.new()
   n.life_mode=true
   n.gentle=gentle
   n.configure({"energy":0.5})
   n.add_hours(hours,false)
   n.advance(0.25,false)
   n.advance(0.25,false)
   drain.append({"gentle":gentle,"hours":hours,"energy":n.energy,"streak":n.starving_streak_h})
 var progress := Progress.new()
 var first := progress.finish_main_life()
 var second := progress.finish_main_life()
 progress.record_death()
 var data := {"thresholds":rows,"drain":drain,"progress":{"first":first,"second":second,"easy":progress.easy_unlocked(),"deaths":progress.deaths}}
 var f := FileAccess.open("res://roblox_port/tests/continuing_reference.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(data,"  ")+"\n")
 print("CONTINUING_REFERENCE: 12 thresholds, 8 drains, progress")
 quit()
