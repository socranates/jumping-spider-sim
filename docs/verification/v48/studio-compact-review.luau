-- Studio-only observation driver. Never publish Client/SilkPlayback.
return function(d)
 assert(game:GetService("RunService"):IsStudio())
 local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
 local Pond=require(game.ReplicatedStorage.Shared.World.Pond)
 _G.CompactReview=d -- client-only Studio diagnostic, absent from the project tree
 assert(Map.revision()=="preserve-3","compact source required")
 local sites={
  garden={Vector3.new(40,-84.29,-88),Vector3.zAxis},
  shoulder={Vector3.new(100,-84.29,-550),Vector3.xAxis},
  pond={Vector3.new(510,Pond.DECK+.31,(Pond.BOARDS[2][1]+Pond.BOARDS[2][2])/2),Vector3.xAxis},
  can={Vector3.new(115,-69.69,226),Vector3.xAxis},
 }
 task.spawn(function()
  while not d.session.started do
   if d.menu:isShowing() then d.menu:choose("New") end
   task.wait(.2)
  end
  task.wait(2.5);if d.title:holding() then d.title:skip() end
  task.wait(2)
  d.life.clock.hour=12
  local current=nil
  while true do
   local wanted=workspace:GetAttribute("CompactReviewSite") or "garden"
   if sites[wanted] and wanted~=current then
    current=wanted
    d.input:clear();d.life.resting=false
    local site=sites[wanted]
    local region=assert(Map.at(site[1]))
    local deadline=os.clock()+15
    repeat
     d.place(site[1])
     game:GetService("RunService").RenderStepped:Wait()
    until d.world:regionReady(region.id) or os.clock()>deadline
    assert(d.world:regionReady(region.id),"region not ready: "..region.id)
    d.place(site[1]);d.motor:place(site[1],Vector3.yAxis,site[2]);d.cam:snap()
    task.wait(8)
    local nearby=0
    for _,f in d.world.prey:flies() do if (f.position-d.motor.pos).Magnitude<30 then nearby+=1 end end
    print("[CHET_COMPACT_SITE]",wanted,d.world.region.id,d.motor.mode,d.motor.pos,nearby,#Map.regions())
    local n,total,worst=0,0,0
    local stop=os.clock()+5
    while os.clock()<stop do
     local dt=game:GetService("RunService").RenderStepped:Wait()
     n+=1;total+=dt;worst=math.max(worst,dt)
    end
    print("[CHET_COMPACT_FRAME]",wanted,n,1000*total/math.max(n,1),1000*worst)
   end
   task.wait(.25)
  end
 end)
end
