-- Diagnostic only. Install as Client/SilkPlayback in Studio; never publish it.
return function(d)
 local Run=game:GetService("RunService")
 assert(Run:IsStudio())
 local Route=require(game.ReplicatedStorage.Shared.Predator.RivalRoute)
 task.spawn(function()
  local n,total,worst,navWorst=0,0,0,0
  local settledN,settledTotal,settledWorst,distance=0,0,0,0
  local previous=nil;local started=os.clock()
  local regions={};local stop=started+70;local nextReport=started+10
  local connection=Run.RenderStepped:Connect(function(dt)
   n+=1;total+=dt;worst=math.max(worst,dt)
   navWorst=math.max(navWorst,Route.preparationStats().lastSeconds)
   if os.clock()-started>10 then settledN+=1;settledTotal+=dt;settledWorst=math.max(settledWorst,dt) end
   local r=d.life.rival;if r then
    regions[r.region or "unknown"]=true
    if previous then distance+=(r.position-previous).Magnitude end;previous=r.position
   end
  end)
  while not d.session.started do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
  task.wait(2.5);if d.title:holding() then d.title:skip() end
  d.prof.start()
  while os.clock()<stop do
   if os.clock()>=nextReport then
    local s=Route.preparationStats();local r=d.life.rival
    print("[CHET_ROUTE_PROGRESS]",s.pending,s.completed,s.failed,s.active,r and r.region,r and r.state,r and r.position)
    nextReport+=10
   end
   task.wait(.25)
  end
  connection:Disconnect();d.prof.stop()
  local visited={};for id in regions do table.insert(visited,id) end;table.sort(visited)
  local s=Route.preparationStats()
  print("[CHET_ROUTE_FRAME]",n,total/n*1000,worst*1000,navWorst*1000)
  print("[CHET_ROUTE_SETTLED]",settledN,settledTotal/math.max(1,settledN)*1000,settledWorst*1000,distance)
  print("[CHET_ROUTE_READY]",s.pending,s.completed,s.failed,s.largestSlice*1000,table.concat(visited,","))
  print("[CHET_ROUTE_PROFILE]",d.prof.line())
 end)
end
