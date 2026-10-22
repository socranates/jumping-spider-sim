-- Temporary Studio-only profile driver. Never publish as Client/SilkPlayback.
-- Use the same viewport/camera/detail and no concurrent CLI jobs before/after.
return function(d)
 local RS=game:GetService("RunService")
 local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
 local deadline=os.clock()+30
 while not d.session.started and os.clock()<deadline do
  if d.menu:isShowing() then d.menu:choose("New") end
  task.wait(.2)
 end
 if d.title:holding() then d.title:skip() end
 task.wait(2)
 assert(d.fresh("free",false),"profile needs a real fresh Free play session")
 assert(d.session.mode=="free" and d.session.rules=="gentle")
 d.cam.mouse=false
 game:GetService("UserInputService").MouseBehavior=Enum.MouseBehavior.Default
 game:GetService("UserInputService").MouseIconEnabled=true
 workspace:SetAttribute("Cat",true)
 d.cat.enabled=true
 for _,id in {"sill","garden_b2","meadow_a3","deck_n2","hut_doorway"} do
  d.life.clock.hour=12
  local r=assert(Map.region(id),id)
  d.place(r.spawn.pos+Vector3.new(0,.31,0))
  task.wait(7)
  local frames={};local seconds=0
  d.prof.start()
  while seconds<5 do local dt=RS.RenderStepped:Wait();seconds+=dt;table.insert(frames,dt) end
  d.prof.stop();table.sort(frames)
  print("[CHET_V50_PROFILE]","before",d.detail,id,#frames,seconds,
   "mean_ms",seconds/#frames*1000,"p95_ms",frames[math.ceil(#frames*.95)]*1000,
   "worst_ms",frames[#frames]*1000,"mode",d.motor.mode,"alive",not d.life.lifeOver)
  print("[CHET_V50_PROFILE_LUA]","before",d.detail,id,d.prof.line())
  local camera=workspace.CurrentCamera
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={d.world.root}
  local ray=workspace:Raycast(camera.CFrame.Position,d.motor.pos-camera.CFrame.Position,params)
  print("[CHET_V50_CAMERA]","before",d.detail,id,"spider",d.motor.pos,"camera",camera.CFrame.Position,
   "first_block",if ray then ray.Instance:GetFullName() else "none","hit",if ray then ray.Position else Vector3.zero)
  task.wait(3)
 end
 print("[CHET_V50_PROFILE_END]","before",d.detail)
end
