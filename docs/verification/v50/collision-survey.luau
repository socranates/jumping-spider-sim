-- Temporary Studio-only survey. Install as SilkPlayback, never publish it.
-- Native self-test covers exact supported crossings; this surveys walking/hopping
-- and camera endpoints in every dry region at the normal player camera.
return function(d)
 local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
 local deadline=os.clock()+30
 while not d.session.started and os.clock()<deadline do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
 if d.title:holding() then d.title:stop() end
 assert(d.fresh("free",false));assert(d.session.rules=="gentle")
 d.cam.mouse=false
 game:GetService("UserInputService").MouseBehavior=Enum.MouseBehavior.Default
 game:GetService("UserInputService").MouseIconEnabled=true
 local params=OverlapParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={d.world.root}
 local total,wet,unready,inside=0,0,0,0
 local function endpoint(id,phase)
  local camera=workspace.CurrentCamera
  local list=workspace:GetPartBoundsInBox(CFrame.new(camera.CFrame.Position),Vector3.one*.04,params)
  for _,p in list do if p.CanQuery and p.CanCollide then
   inside+=1;print("[CHET_V50_CAMERA_INTERIOR]",d.detail,id,phase,p.Name,"camera",camera.CFrame.Position,"spider",d.motor.pos)
  end end
 end
 for index,r in Map.regions() do
  d.life.clock.hour=12
  local at=r.spawn.pos+Vector3.yAxis*.31
  if d.Pond.inWater(at) then wet+=1;continue end
  d.place(at)
  local until_=os.clock()+4
  while not d.world:regionReady(r.id) and os.clock()<until_ do d.place(at);task.wait(.1) end
  if not d.world:regionReady(r.id) then unready+=1;print("[CHET_V50_SURVEY_UNREADY]",d.detail,r.id);continue end
  local up=nil
  for _,axis in {Vector3.yAxis,-Vector3.zAxis,Vector3.zAxis,-Vector3.xAxis,Vector3.xAxis,-Vector3.yAxis} do
   local hit=workspace:Raycast(r.spawn.pos+axis*.5,-axis,d.motor.params)
   if hit and (hit.Position-r.spawn.pos).Magnitude<.1 then up=axis;break end
  end
  if not up then unready+=1;print("[CHET_V50_SURVEY_NO_SUPPORT]",d.detail,r.id);continue end
  d.place(r.spawn.pos+up*.31,up)
  d.motor:place(r.spawn.pos+up*.31,up,r.spawn.heading);d.cam:snap()
  task.wait(.2)
  endpoint(r.id,"stand")
  d.input:simulate("Forward",true);task.wait(.65);d.input:simulate("Forward",false)
  endpoint(r.id,"walk")
  d.input:simulate("Jump",true);task.wait(.05);d.input:simulate("Jump",false);task.wait(.75)
  endpoint(r.id,"hop")
  total+=1
  print("[CHET_V50_SURVEY]",d.detail,index,r.id,"mode",d.motor.mode,"at",d.motor.pos,"alive",not d.life.lifeOver,
   "look_parts",d.world.looks:parts(),"look_plan",d.world.looks.planned)
 end
 d.input:clear()
 print("[CHET_V50_SURVEY_END]",d.detail,"dry",total,"water",wet,"unready",unready,"camera_interior_observations",inside)
end
