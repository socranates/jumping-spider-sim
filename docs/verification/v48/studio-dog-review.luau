-- Studio diagnostic only. Never publish the SilkPlayback instance.
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
  local living=assert(d.world.living);local dog=living.dog
  local count,total,worst,shown,slide,gap=0,0,0,0,0,0
  local before={};local stop=os.clock()+30
  d.prof.start()
  while os.clock()<stop do
   local dt=Run.RenderStepped:Wait();count+=1;total+=dt;worst=math.max(worst,dt)
   if dog.shown then
    shown+=1
    for i,f in dog.gait.feet do
     local old=before[i]
     if old and old.reset==dog.gait.resets and not old.swing and not f.swing then slide=math.max(slide,(old.at-f.anchor).Magnitude) end
     gap=math.max(gap,(f.ankle-f.anchor-Vector3.yAxis*3.5).Magnitude)
     before[i]={at=f.anchor,swing=f.swing~=nil,reset=dog.gait.resets}
    end
   else before={} end
  end
  d.prof.stop()
  print("[CHET_DOG_NATIVE]",d.detail,count,total/count*1000,worst*1000,shown,slide,gap,dog.gait.resets)
  print("[CHET_DOG_PROFILE]",d.prof.line())
  workspace:SetAttribute("DogReviewComplete",true)
  -- The optional close-up is a diagnostic camera, not the normal game view.
  local clear=false
  Run:BindToRenderStep("DogReviewCamera",Enum.RenderPriority.Camera.Value+5,function()
   if workspace:GetAttribute("DogReviewShot")==true and dog.shown then
    if not clear then
     for _,effect in game:GetService("Lighting"):GetDescendants() do if effect:IsA("DepthOfFieldEffect") then effect.Enabled=false end end
     clear=true
    end
    local centre=dog.parts[1].Position
    workspace.CurrentCamera.CFrame=CFrame.lookAt(centre+Vector3.new(-90,15,90),centre-Vector3.new(0,8,0))
   end
  end)
 end)
end
