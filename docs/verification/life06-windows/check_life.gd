extends SceneTree
var world: Node3D
var prefs: Node
var large := false
func _initialize() -> void:
 large = "--large" in OS.get_cmdline_user_args()
 call_deferred("run")
func frames(n: int) -> void:
 for i in n:
  await process_frame
func shot(label: String) -> void:
 await frames(3)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("user://"+label+("_large" if large else "")+".png")
 print("SHOT ",label)
func run() -> void:
 root.size = Vector2i(1920,1080)
 prefs = load("res://scripts/presentation/settings.gd").new()
 prefs.config_path = "user://life06.cfg"
 root.add_child(prefs)
 prefs.autosave = false
 prefs.set_value("ui_scale",1.5 if large else 1.0)
 world = load("res://scenes/main.tscn").instantiate()
 world.settings = prefs
 world.interactive = true
 world.wasp_enabled = false
 world.prey_count = 0
 world.prey_seed = 4242
 world.checkpoint_dir = "user://life06"
 world.show_start_menu = true
 root.add_child(world)
 await frames(40)
 print("CONTROLLERS ",Input.get_connected_joypads())
 print("MENU_RECT ",world.start_menu._panel.get_global_rect()," VIEW ",root.get_visible_rect())
 await shot("start")
 if "--menu-only" in OS.get_cmdline_user_args():
  return
 world.start_menu.new_life(false)
 world.controller.set_physics_process(false)
 world.camera_rig.require_captured_mouse = false
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 await frames(30)
 world.prey.ensure_ready()
 world.needs.configure({"energy":0.01})
 for hours in [2.0,25.0,30.0]:
  world.needs.add_hours(hours,false)
  world.needs.advance(0.25,false)
  world.needs.advance(0.25,false)
  await frames(5)
  print("HUNGER ",hours," ",world.habitat_loop.caption())
  if not world.life_ended:
   await shot("hunger_"+str(int(hours)))
 await create_timer(3.3).timeout
 await shot("starved")
 print("END_RECT ",world.caught_panel._box.get_global_rect())
 world = world.caught_panel.go_on_as_another()
 await frames(40)
 print("ANOTHER ",world.new_spider," ",world.spider.position," ",world.habitat_loop.caption()," NOTEBOOK ",world.notebook.opened)
 await shot("another")
 world.prey.ensure_ready()
 world.controller.set_physics_process(false)
 # Stage the third moult in the retreat; real habitat ticks finish it.
 world.spider.teleport_to(Transform3D(Basis(),Vector3(-25,0.31,6)))
 await frames(40)
 world.habitat_loop.growth.stage = 2
 world.habitat_loop.growth.eat(1.0)
 print("REST ",world.habitat_loop.request_rest())
 for i in 1500:
  if world.habitat_loop.growth.stage == 3:
   break
  await physics_frame
 print("ADULT ",world.habitat_loop.growth.stage," EASY ",world.progress.easy_unlocked())
 await shot("adult")
 print("CHECKPOINT ",world.available_checkpoint()["ok"]," ",world.last_checkpoint_message)
 world.habitat_loop.stop_rest()
 world.start_menu = load("res://scripts/presentation/start_menu.gd").new()
 world.start_menu.world = world
 world.start_menu.settings = prefs
 world.add_child(world.start_menu)
 world.start_menu.open()
 await frames(10)
 await shot("all_options")
 print("ALL_MENU_RECT ",world.start_menu._panel.get_global_rect())
 world.start_menu._close()
 world.end_life("wasp")
 await create_timer(3.3).timeout
 await shot("wasp_three_choices")
 world = world.caught_panel.go_on()
 await frames(40)
 print("RESTORED ",world.restored," ALIVE ",not world.life_ended)
 await shot("last_rest")
 world = world.start_free_play()
 await frames(40)
 world.controller.set_physics_process(false)
 world.spider.teleport_to(Transform3D(Basis(Vector3.UP,PI/2),Vector3(3,0.31,6.5)))
 await frames(40)
 world.prey.ensure_ready()
 world.wasp_director.force_visit("floor_middle")
 for i in 2400:
  if world.wasp_director.spared_this_visit:
   break
  if world.wasp_director.phase_name() in ["arriving","searching"]:
   world.spider.set_intent(Vector3.RIGHT*(1.0 if (i/30)%2==0 else -1.0),false)
  else:
   world.spider.set_intent(Vector3.ZERO,false)
  await physics_frame
 print("FREE_TOUCH ",world.wasp_director.spared_this_visit," SEIZED ",world.spider.seized," ENDED ",world.life_ended," MODE ",world.mode)
 await shot("free_touch")
 print("CHECK_COMPLETE")
 quit()
