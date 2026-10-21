-- Studio-only normal-camera habitat inspection. Never ship SilkPlayback.
return function(d)
 assert(game:GetService("RunService"):IsStudio())
 task.spawn(function()
  while not d.session.started do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
  task.wait(2.5);if d.title:holding() then d.title:skip() end;task.wait(2)
  d.life.clock.hour=12
  local at=Vector3.new(-182,-84.29,-190)
  d.place(at);d.motor:place(at,Vector3.yAxis,-Vector3.zAxis);d.cam:snap()
  task.wait(10)
  local living=assert(d.world.living)
  print("[CHET_COLONY_READY]",d.detail,d.motor.pos,d.world.region.id,living.state.rain,living.state.wetness)
  for _,ant in living.ants do print("[CHET_COLONY_ANT]",ant.index,ant.shown,ant.parts[1].Position,ant.pose and ant.pose.mode,ant.pose and ant.pose.carrying) end
  task.spawn(function()
   for _=1,9 do
    task.wait(5)
    local modes={inside=0,outbound=0,forage=0,["return"]=0};local loads=0
    for _,ant in living.ants do
     if ant.pose then modes[ant.pose.mode]+=1;if ant.shown and ant.pose.carrying then loads+=1 end end
    end
    print("[CHET_COLONY_TRAFFIC]",modes.inside,modes.outbound,modes.forage,modes["return"],loads)
   end
  end)
  for _,grub in living.grubs do print("[CHET_COLONY_GRUB]",grub.index,grub.shown,grub.parts[1].Position) end
  task.wait(15)
  d.input:simulate("Forward",true);task.wait(if d.detail=="low" then 5.4 else 3);d.input:simulate("Forward",false)
  print("[CHET_COLONY_APPROACH]",d.motor.mode,d.motor.pos,d.world.region.id)
  if d.detail=="low" then return end
  task.wait(25)
  at=Vector3.new(-310,-84.29,-155)
  d.place(at);d.motor:place(at,Vector3.yAxis,Vector3.zAxis);d.cam:snap()
  task.wait(10)
  local before={}
  local stop=os.clock()+70
  while os.clock()<stop do
   for _,grub in living.grubs do
    if grub.shown~=before[grub.index] then
     print("[CHET_COLONY_EMERGENCE]",grub.index,grub.shown,d.life.clock.day,d.life.clock.hour,living.state.wetness,grub.parts[1].Position)
     before[grub.index]=grub.shown
    end
   end
   task.wait(.05)
  end
  print("[CHET_COLONY_COMPLETE]")
 end)
end
