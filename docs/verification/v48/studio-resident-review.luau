-- Studio-only driver. Never include Client/SilkPlayback in a published build.
return function(d)
 assert(game:GetService("RunService"):IsStudio())
 workspace:SetAttribute("Wasp",true)
 task.spawn(function()
  local deadline=os.clock()+30
  while not d.session.started and os.clock()<deadline do
   if d.menu:isShowing() then d.menu:choose("New") end
   task.wait(.2)
  end
  task.wait(2);if d.title:holding() then d.title:skip() end
  task.wait(2)
  d.input:clear();d.place(Vector3.new(-25.5,.31,6));d.cam:snap()
  d.life.resting=true
  task.wait(12)
  local visible={}
  for _,name in {"SpiderHud","SpiderPrompts","PerceptionHud"} do
   local gui=game.Players.LocalPlayer.PlayerGui:FindFirstChild(name)
   if gui then for _,object in gui:GetDescendants() do
    if object:IsA("TextLabel") and object.Text~="" then
     local shown=true;local at=object
     while at and at~=game.Players.LocalPlayer.PlayerGui do
      if at:IsA("ScreenGui") and not at.Enabled then shown=false end
      if at:IsA("GuiObject") and not at.Visible then shown=false end
      at=at.Parent
     end
     if shown then table.insert(visible,object.Name..":"..object.Text) end
    end
   end end
  end
  print("[CHET_V48_MINIMAL]",d.life.growth.stage,d.life.growth:mealGoal(),#visible,table.concat(visible," | "))
  print("[CHET_V48_RESIDENT]",d.life.rival.state,d.life.rival.region,d.life.rival.position,d.wasp.phase,d.wasp.wasp.position,d.world:creatureLive(d.life.rival.region))
  local n,total,worst=0,0,0;local stop=os.clock()+5
  while os.clock()<stop do local dt=game:GetService("RunService").RenderStepped:Wait();n+=1;total+=dt;worst=math.max(worst,dt) end
  print("[CHET_V48_RESIDENT_FRAME]",n,1000*total/n,1000*worst)
 end)
end
