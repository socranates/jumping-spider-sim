-- Studio-only normal-camera detail inspection. Never publish SilkPlayback.
return function(d)
 local Run=game:GetService("RunService")
 local Environment=require(game.ReplicatedStorage.Shared.World.Environment)
 assert(Run:IsStudio())
 task.spawn(function()
  while not d.session.started do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
  task.wait(2.5);if d.title:holding() then d.title:skip() end;task.wait(2)
  d.life.clock.hour=12
  d.place(Vector3.new(140,-69.69,226));task.wait(10)
  local living=assert(d.world.living);local chosen=nil
  for _,flea in living.fleas do if flea.shown then chosen=flea;break end end
  if not chosen then
   -- Low detail keeps the first two authored floor workers. Inspect their
   -- seeded floor locations instead of adding an extra animal for this test.
   local region=d.world.region;local lo,hi=region.bounds[1],region.bounds[2]
   for index=1,#living.fleas do
    d.place(Vector3.new(lo.X+(hi.X-lo.X)*(.12+index*.14)+1.2,-69.69,lo.Z+(hi.Z-lo.Z)*Environment.hash(region.seed,index,73)+2))
    task.wait(2)
    for _,flea in living.fleas do if flea.shown then chosen=flea;break end end
    if chosen then break end
   end
  end
  assert(chosen,"no flea in the ordinary floor review location")
  local point=chosen.parts[1].Position
  local at=Vector3.new(point.X+1.2,-69.69,point.Z+2)
  d.place(at);d.motor:place(at,Vector3.yAxis,Vector3.new(-1.2,0,-2).Unit);d.cam:snap()
  task.wait(5)
  print("[CHET_FLEA_READY]",d.detail,d.motor.pos,d.world.region.id,chosen.index,chosen.parts[1].Position,chosen.parts[3].Size,living.count)
  local frames,total,worst,visible,restSamples,footGap=0,0,0,0,0,0
  local lastReport=0;local stop=os.clock()+20
  d.prof.start()
  while os.clock()<stop do
   local dt=Run.RenderStepped:Wait();frames+=1;total+=dt;worst=math.max(worst,dt)
   local body=chosen.parts[1]
   local projection,onScreen=workspace.CurrentCamera:WorldToViewportPoint(body.Position)
   if chosen.shown and onScreen and projection.Z>0 then visible+=1 end
   local _,hop=Environment.flea(living.state.totalHours*75,chosen.index)
   if chosen.shown and not hop then
    for _,name in {"LeftHindTibia","RightHindTibia"} do
     local leg=assert(chosen.folder:FindFirstChild(name))
     local a=leg.CFrame:PointToWorldSpace(Vector3.new(-leg.Size.X*.5,0,0))
     local b=leg.CFrame:PointToWorldSpace(Vector3.new(leg.Size.X*.5,0,0))
     footGap=math.max(footGap,math.abs(math.min(a.Y,b.Y)+70));restSamples+=1
    end
   end
   if os.clock()-lastReport>2 then
    print("[CHET_FLEA_POSE]",chosen.shown,body.Position,hop,projection,onScreen)
    lastReport=os.clock()
   end
  end
  d.prof.stop()
  print("[CHET_FLEA_FRAME]",frames,total/frames*1000,worst*1000,visible,restSamples,footGap,d.life.lifeOver,d.motor.mode)
  print("[CHET_FLEA_PROFILE]",d.prof.line())
  print("[CHET_FLEA_COMPLETE]")
 end)
end
