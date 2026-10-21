-- Studio-only reproduction of the upper-region support protocol.
return function(d)
 local Run=game:GetService("RunService");assert(Run:IsStudio())
 local axes={Vector3.yAxis,-Vector3.zAxis,Vector3.zAxis,Vector3.xAxis,-Vector3.xAxis,-Vector3.yAxis}
 task.spawn(function()
  while not d.session.started do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
  task.wait(2.5);if d.title:holding() then d.title:skip() end;task.wait(2)
  assert(d.fresh("main",false))
  for _,name in {"cat","crab","bird","frog"} do if d[name] then d[name].enabled=false end end
  for _,id in {"hut_up_g","hut_up_h","hut_up_i","room_up_a"} do
   local r=assert(d.world.map.region(id));local at=r.spawn.pos
   local deadline=os.clock()+30
   while not d.world:regionReady(id) and os.clock()<deadline do d.place(at+Vector3.yAxis*.31);Run.RenderStepped:Wait() end
   assert(d.world:regionReady(id),"region not ready: "..id)
   local normal=nil
   for _,n in axes do
    local hit=workspace:Raycast(at+n*.5,-n,d.motor.params)
    if hit and (hit.Position-at).Magnitude<.1 then
     print("[CHET_UPPER_AXIS]",id,n,hit.Normal,hit.Position,hit.Instance:GetFullName())
     if normal==nil then normal=n end
    end
   end
   assert(normal,"no support: "..id)
   d.place(at+normal*.31,normal);d.motor:place(at+normal*.31,normal,r.spawn.heading);d.cam:snap()
   task.wait(1.2)
   local owned=d.world.map.at(d.motor.pos)
   print("[CHET_UPPER_RESULT]",id,at,normal,d.motor.pos,d.motor.up,d.motor.mode,d.world.region.id,
    owned and owned.id,d.caughtPanel:isShowing(),d.session.ended,d.life.lifeOver,d.wasp.phase)
  end
  print("[CHET_UPPER_DONE]")
 end)
end
