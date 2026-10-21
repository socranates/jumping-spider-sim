-- Studio-only visual/movement driver. Never publish Client/SilkPlayback.
return function(d)
 local Run=game:GetService("RunService")
 assert(Run:IsStudio())
 local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
 local Verge=require(game.ReplicatedStorage.Shared.World.Verge)
 task.spawn(function()
  while not d.session.started do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
  task.wait(2.5);if d.title:holding() then d.title:skip() end;task.wait(2)
  d.life.clock.hour=12
  local origin=Vector3.new(100,Verge.TOP+.31,-550)
  local region=assert(Map.at(origin));local leaf=nil
  for _,p in Verge.pieces(region) do
   if string.sub(p.id,-5)=="_leaf" and (leaf==nil or ((p.lo+p.hi)/2-origin).Magnitude<((leaf.lo+leaf.hi)/2-origin).Magnitude) then leaf=p end
  end
  assert(leaf,"litter source not synced")
  local centre=(leaf.lo+leaf.hi)/2
  local at=Vector3.new(centre.X,Verge.TOP+.31,leaf.lo.Z-2)
  local deadline=os.clock()+15
  repeat d.place(at);Run.RenderStepped:Wait() until d.world:regionReady(region.id) or os.clock()>deadline
  assert(d.world:regionReady(region.id),"review region not ready")
  d.place(at);d.motor:place(at,Vector3.yAxis,Vector3.zAxis);d.cam:snap()
  task.wait(10)
  print("[CHET_LITTER_READY]",leaf.id,d.motor.mode,d.motor.pos,d.world.region.id,d.detail)
  local function sample(label)
   local n,total,worst=0,0,0;local stop=os.clock()+5
   while os.clock()<stop do local dt=Run.RenderStepped:Wait();n+=1;total+=dt;worst=math.max(worst,dt) end
   print("[CHET_LITTER_FRAME]",label,n,1000*total/math.max(n,1),1000*worst)
   if workspace:GetAttribute("LitterProfile")==true then
    d.prof.start();task.wait(3);d.prof.stop()
    print("[CHET_LITTER_PROFILE]",label,d.prof.line())
   end
  end
  sample("approach")
  local mode="approach"
  while true do
   local nextMode=workspace:GetAttribute("LitterReviewStep") or "approach"
   if nextMode~=mode then
    mode=nextMode
    if mode=="walk" then
     d.input:simulate("Forward",true)
     local stop=os.clock()+8
     repeat Run.RenderStepped:Wait() until d.motor.pos.Z>=centre.Z or os.clock()>stop
     d.input:simulate("Forward",false)
     print("[CHET_LITTER_WALK]",d.motor.mode,d.motor.pos,d.motor.pos.Z>=centre.Z,math.abs(d.motor.pos.Y-Verge.TOP-.31)<.05)
     sample("under")
    elseif mode=="top" then
     d.place(Vector3.new(centre.X,leaf.hi.Y+.31,centre.Z));d.cam:snap();task.wait(3)
     print("[CHET_LITTER_TOP]",d.motor.mode,d.motor.pos)
     sample("top")
    end
   end
   task.wait(.25)
  end
 end)
end
