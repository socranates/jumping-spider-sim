-- Studio diagnostic only; remove SilkPlayback before release.
return function(d)
 assert(game:GetService("RunService"):IsStudio())
 task.spawn(function()
  while not d.session.started do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
  task.wait(2.5);if d.title:holding() then d.title:skip() end;task.wait(2)
  d.life.clock.hour=12
  local at=Vector3.new(148,-69.69,226)
  d.place(at);d.motor:place(at,Vector3.yAxis,-Vector3.xAxis);d.cam:snap()
  task.wait(10)
  print("[CHET_INTERIOR_READY]",d.detail,d.motor.pos,d.world.region.id,d.world.living.count)
  for _,r in d.world.living.fleas do print("[CHET_INTERIOR_FLEA]",r.index,r.shown,r.parts[1].Position) end
  workspace:SetAttribute("InteriorReviewReady",true)
  task.wait(20)
  at=Vector3.new(145,-69.69,234)
  d.place(at);d.motor:place(at,Vector3.yAxis,Vector3.new(-1,0,-.6).Unit);d.cam:snap()
  print("[CHET_INTERIOR_SIDE]",d.motor.pos)
  task.wait(25)
  local dust=d.world.living.static:FindFirstChild("DustBunny")
  if dust then
   at=Vector3.new(dust.Position.X+3.5,-69.69,dust.Position.Z+2)
   d.place(at);d.motor:place(at,Vector3.yAxis,Vector3.new(-3.5,0,-2).Unit);d.cam:snap()
   print("[CHET_INTERIOR_DUST]",d.motor.pos,dust.Position)
  end
  task.wait(25)
  for _,flea in d.world.living.fleas do
   if not flea.shown then continue end
   local point=flea.parts[1].Position
   at=Vector3.new(point.X+1.2,-69.69,point.Z+2)
   d.place(at);d.motor:place(at,Vector3.yAxis,Vector3.new(-1.2,0,-2).Unit);d.cam:snap()
   print("[CHET_INTERIOR_FLEA_VIEW]",flea.index,d.motor.pos,point)
   break
  end
 end)
end
