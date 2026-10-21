-- Studio-only normal-camera walk through close ground cover.
return function(d)
 local Run=game:GetService("RunService")
 assert(Run:IsStudio())
 task.spawn(function()
  while not d.session.started do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
  task.wait(2.5);if d.title:holding() then d.title:skip() end;task.wait(2)
  d.life.clock.hour=12
  local at=Vector3.new(-310,-84.29,-155)
  d.place(at);d.motor:place(at,Vector3.yAxis,Vector3.zAxis);d.cam:snap()
  task.wait(10)
  local living=assert(d.world.living)
  print("[CHET_GROUND_READY]",d.detail,d.motor.pos,d.world.region.id,#living.grass,living.count)
  for _,fly in d.world.prey:flies() do
   local point,onScreen=workspace.CurrentCamera:WorldToViewportPoint(fly.position)
   print("[CHET_GROUND_POP]",fly.id,fly.state,fly.position,(fly.position-d.motor.pos).Magnitude,point,onScreen)
  end
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={d.world.root}
  local function sample(label,seconds)
   local n,total,worst,seen,closest=0,0,0,{},math.huge
   local stop=os.clock()+seconds
   d.prof.start()
   while os.clock()<stop do
    local dt=Run.RenderStepped:Wait();n+=1;total+=dt;worst=math.max(worst,dt)
    local camera=workspace.CurrentCamera
    for _,fly in d.world.prey:flies() do
     local distance=(fly.position-d.motor.pos).Magnitude
     if fly.state~="DEAD" and distance<25 then
      closest=math.min(closest,distance)
      local point,onScreen=camera:WorldToViewportPoint(fly.position)
      if onScreen and point.Z>0 then
       local hit=workspace:Raycast(camera.CFrame.Position,fly.position-camera.CFrame.Position,params)
       if hit==nil or (hit.Position-fly.position).Magnitude<.2 then seen[fly.id]=true end
      end
     end
    end
   end
   d.prof.stop()
   local ids={};for id in seen do table.insert(ids,id) end;table.sort(ids)
   print("[CHET_GROUND_FRAME]",label,d.detail,n,total/n*1000,worst*1000,d.motor.mode,d.motor.pos,#living.grass,living.count)
   print("[CHET_GROUND_PREY]",label,closest,table.concat(ids,","))
   print("[CHET_GROUND_PROFILE]",label,d.prof.line())
  end
  sample("standing",5)
  d.input:simulate("Forward",true);sample("walking",10);d.input:simulate("Forward",false)
  sample("arrived",5)
  workspace:SetAttribute("GroundReviewComplete",true)
 end)
end
