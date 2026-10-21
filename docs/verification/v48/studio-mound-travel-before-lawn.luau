-- Studio-only ordinary-control crossing, including the previous hidden-body endpoint.
return function(d)
 local Run=game:GetService("RunService");assert(Run:IsStudio())
 task.spawn(function()
  while not d.session.started do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
  task.wait(2.5);if d.title:holding() then d.title:skip() end;task.wait(2)
  assert(d.fresh("free",false));d.life.clock.hour=12
  local at=Vector3.new(-182,-84.29,-190)
  d.place(at);d.motor:place(at,Vector3.yAxis,-Vector3.zAxis);d.cam:snap();task.wait(12)
  local function sample(label,seconds,action)
   local frames,hidden,outside,blocked=0,0,0,0
   local hiddenRun,maxHidden,total,worst=0,0,0,0
   if action then d.input:simulate(action,true) end
   local untilTime=os.clock()+seconds
   while os.clock()<untilTime do
    local dt=Run.RenderStepped:Wait();frames+=1;total+=dt;worst=math.max(worst,dt)
    local camera=workspace.CurrentCamera
    local point,onScreen=camera:WorldToViewportPoint(d.motor.pos)
    if not onScreen or point.Z<=0 then outside+=1 end
    if d.rig()._bodyHidden then hidden+=1;hiddenRun+=dt;maxHidden=math.max(maxHidden,hiddenRun) else hiddenRun=0 end
    local hit=workspace:Raycast(camera.CFrame.Position,d.motor.pos-camera.CFrame.Position,d.motor.params)
    if hit and (hit.Position-d.motor.pos).Magnitude>.4 then blocked+=1 end
   end
   if action then d.input:simulate(action,false) end
   print("[CHET_MOUND_TRAVEL]",d.detail,label,frames,hidden,outside,blocked,maxHidden,total/frames*1000,worst*1000,
    d.motor.mode,d.motor.pos,d.motor.up,(workspace.CurrentCamera.CFrame.Position-d.motor.pos).Magnitude)
   assert(d.motor.mode=="attached" and not d.life.lifeOver,"mound crossing lost support")
  end
  sample("approach",5.4,"Forward")
  sample("old-endpoint",3,nil)
  sample("across",6.6,"Forward")
  sample("back",12,"Back")
  sample("returned",3,nil)
  print("[CHET_MOUND_TRAVEL_DONE]",d.detail)
 end)
end
