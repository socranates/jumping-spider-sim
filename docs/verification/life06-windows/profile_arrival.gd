extends SceneTree
var world: Node3D
var profile := false
var large := false
var recording := false
var rows: Array[String] = ["phase,frame_ms,gpu_ms"]
var last := 0
var audio_record: AudioEffectRecord

func _initialize() -> void:
 profile = "--profile" in OS.get_cmdline_user_args()
 large = "--large" in OS.get_cmdline_user_args()
 call_deferred("run")

func _process(_dt: float) -> bool:
 var now := Time.get_ticks_usec()
 if recording and profile:
  rows.append("%s,%.4f,%.4f" % [world.wasp_director.phase_name(),float(now-last)/1000.0,RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())])
 last = now
 return false

func ticks(n: int) -> void:
 for i in n:
  await physics_frame

func shot(label: String) -> void:
 if profile:
  return
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("user://"+label+("_large" if large else "")+".png")
 print("SHOT ",label)

func run() -> void:
 root.size = Vector2i(1920,1080)
 var prefs = load("res://scripts/presentation/settings.gd").new()
 prefs.config_path = "user://wasp_fixture.cfg"
 root.add_child(prefs)
 prefs.autosave = false
 prefs.set_value("ui_scale",1.5 if large else 1.0)
 world = load("res://scenes/main.tscn").instantiate()
 world.settings = prefs
 world.interactive = true
 world.use_windowsill = true
 world.wasp_enabled = false
 world.prey_count = 0
 world.prey_seed = 4242
 world.checkpoint_dir = "user://wasp_fixture"
 world.spawn_override = Transform3D(Basis(Vector3.UP,PI/2),Vector3(3,0.31,6.5))
 root.add_child(world)
 world.controller.set_physics_process(false)
 world.camera_rig.require_captured_mouse = false
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 await ticks(45)
 world.prey.ensure_ready()
 world.habitat_loop.clock.day = 2
 world.habitat_loop.clock.hour = 12
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 if "--warm" in OS.get_cmdline_user_args():
  var viewport := SubViewport.new()
  viewport.size = Vector2i(96,96)
  viewport.own_world_3d = true
  viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
  root.add_child(viewport)
  var body = load("res://scripts/predator/wasp_body.gd").new()
  viewport.add_child(body)
  var eye := Camera3D.new()
  viewport.add_child(eye)
  eye.position = Vector3(3,2,3)
  eye.look_at(Vector3.ZERO)
  eye.current = true
  var light := DirectionalLight3D.new()
  light.shadow_enabled = true
  light.rotation_degrees = Vector3(-50,30,0)
  viewport.add_child(light)
  await RenderingServer.frame_post_draw
  await RenderingServer.frame_post_draw
  viewport.queue_free()
  await ticks(30)
  print("WARMED offscreen")
 var wd: Node = world.wasp_director
 var cam := Camera3D.new()
 cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
 root.add_child(cam)
 # Model studies use the same runtime body, frozen in each public pose.
 if not profile:
  world.camera_rig.set_process(false)
  wd.wasp.visible = true
  wd.wasp.set_physics_process(false)
  wd.wasp.place(Vector3(0,2,6))
  cam.position = Vector3(3.5,3.6,9)
  cam.look_at(wd.wasp.position)
  cam.current = true
  for mode in 3:
   wd.wasp.body.pose(mode,0.37,0.7)
   await shot("model_"+str(mode))
  wd.wasp.set_physics_process(true)
  cam.current = false
  world.camera_rig.camera.current = true
  world.camera_rig.set_process(true)
 if not profile:
  audio_record = AudioEffectRecord.new()
  AudioServer.add_bus_effect(0,audio_record)
  audio_record.set_recording_active(true)
 wd.force_visit("floor_middle")
 recording = true
 await ticks(480)
 if not profile:
  audio_record.set_recording_active(false)
  audio_record.get_recording().save_to_wav("user://arrival.wav")
 print("ARRIVAL_END ",wd.visit_s," ",wd.phase_name()," HUM ",world.soundscape.wasp_humming())
 await shot("arrival_end")
 var n := 0
 while wd.phase_name()!="inspecting" and n<900:
  n += 1
  world.spider.set_intent(Vector3.RIGHT*(1.0 if (n/30)%2==0 else -1.0),false)
  await physics_frame
 world.spider.set_intent(Vector3.ZERO,false)
 if wd.phase_name()!="inspecting":
  print("CHECK_FAILED no inspection")
  quit(1)
  return
 await ticks(30)
 await shot("inspection")
 world.camera_rig.eye_view = true
 await ticks(20)
 await shot("eye_inspection")
 world.camera_rig.eye_view = false
 n = 0
 while wd.phase_name()!="carrying" and n<600:
  n += 1
  await physics_frame
 if wd.phase_name()!="carrying":
  print("CHECK_FAILED no carry")
  quit(1)
  return
 if not profile:
  cam.position = wd.wasp.position+Vector3(2.5,1.0,3.5)
  cam.look_at(wd.wasp.position+Vector3.DOWN*0.3)
  cam.current = true
 await shot("carrying")
 n = 0
 while not world.caught_panel.is_showing() and n<600:
  n += 1
  await physics_frame
 recording = false
 print("VISIT_EVENTS ",JSON.stringify(wd.events))
 if not world.caught_panel.is_showing():
  print("CHECK_FAILED no catch screen")
  quit(1)
  return
 for i in 240:
  await process_frame
 await shot("caught")
 print("PANEL ",world.caught_panel._box.get_global_rect()," VIEW ",root.get_visible_rect())
 if profile:
  var file := FileAccess.open("user://visit_frames.csv",FileAccess.WRITE)
  file.store_string("\n".join(rows))
  file.close()
 if not profile:
  var opened: Array = world.notebook.opened.duplicate()
  world = world.caught_panel.go_on_as_another()
  await ticks(30)
  print("AFTER_CATCH ",world.new_spider," AT ",world.spider.position," NOTICE ",world.habitat_loop.notice," NOTEBOOK ",world.notebook.opened," BEFORE ",opened)
  await shot("another_after_catch")
 print("CHECK_COMPLETE")
 quit()
