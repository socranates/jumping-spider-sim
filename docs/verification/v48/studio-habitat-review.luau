-- Temporary Studio review module; installed as Client/SilkPlayback and removed before release.
local Review={}
function Review.run(d)
 assert(game:GetService("RunService"):IsStudio())
 Review.ctx=d
 local event=Instance.new("BindableEvent");event.Name="ChetHabitatReview";event.Parent=game.Players.LocalPlayer.PlayerScripts
 event.Event:Connect(function(name) task.spawn(Review.go,name) end)
 task.spawn(function()
  local untilTime=os.clock()+25
  while not d.session.started and os.clock()<untilTime do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
  task.wait(3);if d.title:holding() then d.title:skip() end;task.wait(2)
  Review.go("garden")
 end)
end
function Review.go(name)
 local d=Review.ctx;local map=d.world.map
 local sites={verge=Vector3.new(100,-84.29,-550),garden=Vector3.new(47,-84.29,-78),ant=Vector3.new(-175,-84.29,-205),floor=Vector3.new(138,-69.69,230),dog=Vector3.new(-205,-84.29,-120)}
 local pos=sites[name] or sites.garden
 d.input:clear();d.life.clock.hour=12
 d.input:simulate("Help",true,"review");game:GetService("RunService").RenderStepped:Wait();d.input:simulate("Help",false,"review")
 d.place(pos);d.motor.heading=Vector3.new(0,0,-1);d.cam:snap()
 task.wait(8)
 local flies=0;local entries=0
 for _,entry in d.world.garden do
  if entry.kinds then for _,director in entry.kinds do entries+=1;flies+=#director.flies end end
 end
 local region=d.world.region
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={d.world.root}
 local support=workspace:Raycast(d.motor.pos,Vector3.new(0,-2,0),params)
 print("[CHET_V48_SITE]",name,region.id,d.world:regionReady(region.id),d.motor.pos,d.motor.mode,entries,flies,support and support.Instance:GetFullName(),d.world.living.count)
 local n,total,worst=0,0,0;local stop=os.clock()+4
 while os.clock()<stop do local dt=game:GetService("RunService").RenderStepped:Wait();n+=1;total+=dt;worst=math.max(worst,dt) end
 print("[CHET_V48_FRAME]",name,n,1000*total/n,1000*worst)
end
return Review.run
