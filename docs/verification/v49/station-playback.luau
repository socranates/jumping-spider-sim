-- Temporary Studio-only driver. Insert as Client/SilkPlayback, never publish it.
return function(d)
 local RS=game:GetService("RunService")
 local function wait(s) local t=os.clock()+s;while os.clock()<t do RS.RenderStepped:Wait() end end
 local deadline=os.clock()+30
 while not d.session.started and os.clock()<deadline do
  if d.menu:isShowing() then d.menu:choose("New") end
  task.wait(.2)
 end
 if d.title:holding() then d.title:skip() end
 wait(2)
 d.fresh("free",true)
 d.life.clock.hour=12
 workspace:SetAttribute("Wasp",false);workspace:SetAttribute("Cat",false)
 local command=Instance.new("BindableEvent");command.Name="ChetStationView";command.Parent=game.Players.LocalPlayer.PlayerScripts
 local view="gear"
 command.Event:Connect(function(which) view=which;d.life.clock.hour=12 end)
 local at,offset=Vector3.new(102,10,48),Vector3.new(31,21,39)
 RS:BindToRenderStep("ChetStationCamera",Enum.RenderPriority.Camera.Value+20,function()
  if view=="window" then at=Vector3.new(460,1,134);offset=Vector3.new(-25,13,24)
  elseif view=="boots" then at=Vector3.new(-111,-51,65);offset=Vector3.new(57,21,60)
  elseif view=="cat" then at=d.cat.pos+Vector3.new(0,12,0);offset=Vector3.new(68,28,-65)
  elseif view=="gear" then at=Vector3.new(102,10,48);offset=Vector3.new(31,21,39)
  else return end
  local cam=workspace.CurrentCamera;cam.CFrame=CFrame.lookAt(at+offset,at);cam.Focus=CFrame.new(at);cam.FieldOfView=48
  local dof=game.Lighting:FindFirstChild("MacroDOF");if dof then dof.FocusDistance=offset.Magnitude;dof.InFocusRadius=40 end
 end)
 d.place(Vector3.new(95,4.31,62))
 wait(3)
 assert(d.hud.reticle.Visible and d.hud.reticle.Size.X.Offset==2,"tiny aim dot missing")
 assert(d.hud.food.Size.X.Offset==150 and d.hud.track.Size.Y.Offset==6,"reserve dimensions")
 assert(d.hud.foodText.Text=="" and not d.hud.foodText.Visible,"reserve labels returned")
 print("[CHET_V49_HUD]",d.hud.reticle.Size,d.hud.food.Size,d.hud.foodText.Visible)
 print("[CHET_V49_VIEW_READY]",d.detail,"gear; use ChetStationView:Fire(window/boots/cat/player)")
 wait(15)
 -- The real client supplies speeds and raycast visibility, not fabricated prey.
 view="cat";d.life.clock.hour=.8;d.place(Vector3.new(290,-69.69,145));d.Cat.load(d.cat,d.Cat.defaultRecord())
 workspace:SetAttribute("Cat",true)
 d.input:simulate("Creep",true,"station-review");d.input:simulate("Forward",true,"station-review")
 wait(3);d.input:clear()
 assert(d.cat.advance==0 and d.cat.wakeS<.1,"creeping woke the cat")
 print("[CHET_V49_CREEP]",d.cat.pose,d.cat.advance,d.cat.wakeS)
 d.input:simulate("Forward",true,"station-review")
 wait(3);d.input:clear()
 assert(d.cat.advance>0,"actual walking did not wake the cat")
 print("[CHET_V49_WAKE]",d.cat.pose,d.cat.pos,d.cat.advance,d.cat.notices)
 wait(4)
 workspace:SetAttribute("Cat",false)
 view="window";d.life.clock.hour=12;d.place(Vector3.new(450,.31,134));wait(3)
 print("[CHET_V49_WINDOW_READY]",d.motor.pos,d.motor.mode)
 -- Native casts against the exact same collision as the player.
 local Shared=game.ReplicatedStorage.Shared
 local Motor=require(Shared.Movement.SpiderMotor)
 local Map=require(Shared.World.WorldMap)
 local Species=require(Shared.Data.Species)
 local Surfaces=require(Shared.Data.Surfaces)
 local lo,hi=Map.bounds()
 local probe=Motor.new({world=d.world.root,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,
  spawn=Vector3.new(450,.31,134),heading=Vector3.xAxis,boundsMin=lo,boundsMax=hi})
 local input=Motor.idleInput();input.wish=Vector3.xAxis
 local detached=0
 probe:place(Vector3.new(450,.31,134),Vector3.yAxis,Vector3.xAxis)
 for _=1,60*24 do probe:tick(input);if probe.mode~="attached" then detached+=1 end end
 assert(probe.pos.X>470 and detached==0,"native cracked-window passage")
 probe:place(Vector3.new(473.81,-10,134),Vector3.xAxis,-Vector3.yAxis);input.wish=-Vector3.yAxis
 for _=1,60*32 do probe:tick(input);if probe.mode~="attached" then detached+=1 end end
 assert(probe.pos.Y< -80 and detached==0,"native log descent")
 probe:place(Vector3.new(477,-84.29,134),Vector3.yAxis,Vector3.xAxis);input.wish=Vector3.xAxis
 for _=1,60*24 do probe:tick(input);if probe.mode~="attached" then detached+=1 end end
 assert(probe.pos.X>530 and detached==0,"native ground to stone path")
 print("[CHET_V49_NATIVE_ROUTES]",detached,probe.pos)
 print("[CHET_V49_REVIEW_END]",d.detail,game.PlaceId,game.GameId)
end
