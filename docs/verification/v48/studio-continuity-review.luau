-- Studio-only: observe a real floor flea while backing across a region seam.
-- No animal, clock freeze, camera magnification or invulnerability is added.
return function(d)
 local Run=game:GetService("RunService");assert(Run:IsStudio())
 task.spawn(function()
  while not d.session.started do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
  task.wait(2.5);if d.title:holding() then d.title:skip() end;task.wait(2)
  d.life.clock.hour=12
  local at=Vector3.new(140,-69.69,238)
  d.place(at);d.motor:place(at,Vector3.yAxis,-Vector3.xAxis);d.cam:snap()
  task.wait(15)
  local living=assert(d.world.living);local chosen=nil
  for _,flea in living.fleas do if flea.shown and flea.site.region=="hut_floor_i" then chosen=flea;break end end
  assert(chosen,"no local floor flea")
  local id=chosen.site.id;local anchor=chosen.site.anchor;local region=d.world.region.id
  print("[CHET_CONTINUITY_START]",d.detail,d.motor.pos,region,id,anchor,#living.fleaSites,living.count)
  local function sample(label,seconds)
   local n,total,worst,kept,inView=0,0,0,0,0
   local stop=os.clock()+seconds;d.prof.start()
   while os.clock()<stop do
    local dt=Run.RenderStepped:Wait();n+=1;total+=dt;worst=math.max(worst,dt)
    if chosen.shown and chosen.site and chosen.site.id==id then
     kept+=1
     local p,onScreen=workspace.CurrentCamera:WorldToViewportPoint(chosen.parts[1].Position)
     if onScreen and p.Z>0 then inView+=1 end
    end
   end
   d.prof.stop()
   print("[CHET_CONTINUITY_FRAME]",label,n,total/n*1000,worst*1000,kept,inView,living.count,d.motor.mode,d.motor.pos,d.world.region.id,d.life.lifeOver)
   print("[CHET_CONTINUITY_PROFILE]",label,d.prof.line())
  end
  d.input:simulate("Back",true);sample("backing",3.3);d.input:simulate("Back",false)
  sample("arrived",5)
  local kept=chosen.shown and chosen.site and chosen.site.id==id
  local gap=if kept then (chosen.site.anchor-anchor).Magnitude else -1
  print("[CHET_CONTINUITY_END]",kept,gap,region,d.world.region.id,id,chosen.site and chosen.site.id)
  assert(d.world.region.id~=region and kept and gap<.0001,"door crossing did not retain its nearby flea site")
 end)
end
