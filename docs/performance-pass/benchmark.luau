-- Diagnostic module only: injected as SilkPlayback into isolated local profiling places. Never publish.
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local WS=game:GetService("Workspace")
local Shared=game.ReplicatedStorage.Shared
local Environment=require(Shared.World.Environment)
local Map=require(Shared.World.WorldMap)
local Meadow=require(Shared.World.Meadow)
local Stats=game:GetService("Stats")
local UIS=game:GetService("UserInputService")
local HEIGHT=.31
local function xyz(v) return {v.X,v.Y,v.Z} end
local function ask(fn) local ok,v=pcall(fn);return if ok then v else nil end
local function adler(text)
 local a,b=1,0
 for i=1,#text do a=(a+string.byte(text,i))%65521;b=(b+a)%65521 end
 return b*65536+a
end
local function emit(runId,kind,value)
 local text=Http:JSONEncode(value);local n=math.ceil(#text/250)
 print("[CHET_PERF_BEGIN]",runId,kind,#text,n,adler(text))
 for i=1,n do print("[CHET_PERF_DATA]",runId,kind,i,Http:JSONEncode(string.sub(text,(i-1)*250+1,i*250))) end
 print("[CHET_PERF_END]",runId,kind)
end
local function waitFor(fn,seconds)
 local limit=os.clock()+seconds
 repeat Run.Heartbeat:Wait();if fn() then return true end until os.clock()>limit
 return false
end
local function wait(seconds)
 local limit=os.clock()+seconds
 repeat Run.Heartbeat:Wait() until os.clock()>=limit
end
local function summary(values)
 local copy=table.clone(values);table.sort(copy);local n=#copy;assert(n>0,"no rendered frames")
 local sum=0;for _,v in copy do sum+=v end
 return {frames=n,mean_ms=sum/n,median_ms=copy[math.ceil(n*.5)],p95_ms=copy[math.ceil(n*.95)],max_ms=copy[n],over_33ms=(function() local k=0;for _,v in copy do if v>33.333 then k+=1 end end;return k end)()}
end
local function weatherTime()
 for day=1,28 do for hour=10,15,.5 do
  local a,b=Environment.sample(day,hour,914),Environment.sample(day,hour+.5,914)
  if a.rain>.7 and b.rain>.7 then return day,hour end
 end end
 error("no stable seeded rain fixture")
end
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and WS:GetAttribute("Benchmark")==true,"local benchmark only")
 assert(WS:GetAttribute("SelfTest")~=true and WS:GetAttribute("TestTarget")==false,"other diagnostics must be off")
 assert(Map.world()=="preserve","wrong world")
 for _,key in {"Wasp","Cat","Bird","Frog"} do assert(WS:GetAttribute(key)==true,"predator disabled: "..key) end
 local runId=tostring(DateTime.now().UnixTimestampMillis)
 local role=assert(WS:GetAttribute("BenchmarkRole"));local revision=assert(WS:GetAttribute("BenchmarkSource"))
 local warm=WS:GetAttribute("BenchmarkWarmSeconds") or 15
 local seconds=WS:GetAttribute("BenchmarkSampleSeconds") or 20
 local trace=WS:GetAttribute("BenchmarkTraceSeconds") or 0
 -- Studio restores its panes after the client starts. Do not time that editor layout transition.
 assert(waitFor(function() return d.fresh("free",false,nil) end,30),"initial world not ready")
 local uiBegan=os.clock();local changedAt=uiBegan;local lastViewport=WS.CurrentCamera.ViewportSize
 assert(waitFor(function()
  local current=WS.CurrentCamera.ViewportSize
  if current~=lastViewport then lastViewport=current;changedAt=os.clock() end
  return current.X>=320 and current.Y>=180 and os.clock()-uiBegan>=10 and os.clock()-changedAt>=3
 end,45),"editor viewport did not settle")
 local viewport=WS.CurrentCamera.ViewportSize
 local focusLosses=0
 local focusConnection=UIS.WindowFocusReleased:Connect(function() focusLosses+=1 end)
 local rainDay,rainHour=weatherTime()
 local scenes={
  {id="sill_dawn",region="sill",day=1,hour=6.2},
  {id="hut_lamp_night",region="hut_desk",day=1,hour=22},
  {id="garden_rain",region="garden_b2",day=rainDay,hour=rainHour},
  {id="meadow_wind",region="meadow_b2",day=1,hour=13},
  {id="pond",region="pond_a2",day=1,hour=12},
  {id="can_doorway",region="hut_doorway",day=1,hour=12},
  {id="lamppost_night",region="lamp_1",day=1,hour=22},
 }
 local function snapshot()
  local actors={};local active={}
  for _,id in d.world.prey.active do table.insert(active,id) end
  for _,f in d.world.prey:flies() do
   local kind=if f.profile and f.profile.body then f.profile.body.prey_kind or f.profile.id else "unknown"
   actors[kind]=(actors[kind] or 0)+1
  end
  local look=d.world.looks
  return {day=d.life.clock.day,hour=d.life.clock.hour,pos=xyz(d.motor.pos),mode=d.motor.mode,
   region=d.world.region.id,camera={WS.CurrentCamera.CFrame:GetComponents()},fov=WS.CurrentCamera.FieldOfView,
   viewport=xyz(Vector3.new(WS.CurrentCamera.ViewportSize.X,WS.CurrentCamera.ViewportSize.Y,0)),
   lua_mb=gcinfo()/1024,engine_mb=ask(function() return Stats:GetTotalMemoryUsageMb() end),
   instances=ask(function() return Stats.InstanceCount end),physics_fps=ask(function() return WS:GetRealPhysicsFPS() end),
   look_parts=if look then look:parts() else nil,look_builds=if look then look.builds else nil,
   predators={wasp={enabled=d.wasp.enabled,state=d.wasp.state},cat={enabled=d.cat.enabled,state=d.cat.state},bird={enabled=d.bird.enabled,state=d.bird.state},frog={enabled=d.frog.enabled,state=d.frog.state},rival={state=d.life.rival and d.life.rival.state}},
   active=active,actors=actors,environment=Environment.sample(d.life.clock.day,d.life.clock.hour,914)}
 end
 local function compactSnapshot()
  local a=snapshot();a.environment={rain=a.environment.rain,cloud=a.environment.cloud,wind=xyz(a.environment.wind),name=a.environment.name}
  return a
 end
 local function setAt(regionId,at,heading)
  local region=assert(Map.region(regionId),regionId)
  local pos=at or region.spawn.pos+Vector3.yAxis*HEIGHT
  local dir=heading or region.spawn.heading or Vector3.zAxis
  d.place(pos,Vector3.yAxis);d.motor:place(pos,Vector3.yAxis,dir);d.camera:snap()
  assert(waitFor(function()
   if d.world:regionReady(regionId) then return true end
   d.place(pos,Vector3.yAxis);d.motor:place(pos,Vector3.yAxis,dir);d.camera:snap();return false
  end,30),"geometry did not arrive: "..regionId)
  local actual=assert(Map.at(pos),"fixture outside map")
  assert(waitFor(function() return d.world:regionReady(actual.id) end,30),"anchor geometry not whole")
  if at~=nil then assert(actual.id==regionId,"walk fixture must begin in its from region") end
  return pos
 end
 local function freshScene(scene)
  local focusBefore=focusLosses
  assert(waitFor(function() return d.fresh("free",false,nil) end,30),"cannot start fixture life")
  d.camera.mouse=false;d.title.seen=true
  d.life.clock.day,d.life.clock.hour=scene.day,scene.hour;d.life:applyLight()
  local anchor
  if scene.id=="pond" then
   local site=assert(d.Pond.FROG_SITES[d.frog.seat],"no frog seat")
   local seat=assert(d.Pond.frogSeat(site,Map.regions()),"frog seat has no surface")
   anchor=setAt(site.region,seat-site.facing*4+Vector3.yAxis*HEIGHT,site.facing)
  else anchor=setAt(scene.region) end
  local actual=assert(Map.at(anchor)).id
  wait(warm)
  assert(d.motor.mode=="attached" and d.world.region.id==actual,"fixture moved before sampling: "..scene.id)
  assert(focusLosses==focusBefore,"window lost focus during warmup")
 end
 local function sample(sceneId,action)
  local values={};local before=compactSnapshot();local started=os.clock();local focusBefore=focusLosses
  d.prof.start()
  local conn=Run.RenderStepped:Connect(function(dt) table.insert(values,dt*1000) end)
  local ok,err=pcall(action)
  conn:Disconnect();d.prof.stop()
  local after=compactSnapshot();local rows,n,mean,worst=d.prof.rows()
  local sameViewport=WS.CurrentCamera.ViewportSize==viewport
  local result={role=role,source=revision,tier=d.detail,scene=sceneId,elapsed=os.clock()-started,
   frames=summary(values),frame_times_ms=values,render_callback={frames=n,mean_ms=mean,max_ms=worst,rows=rows},
   before=before,after=after,viewport_unchanged=sameViewport,focus_preserved=focusBefore==focusLosses,action_ok=ok,error=if ok then nil else tostring(err)}
  emit(runId,sceneId,result)
  assert(ok,tostring(err));assert(sameViewport,"viewport changed during benchmark");assert(focusBefore==focusLosses,"window lost focus during sample")
  return result
 end
 local ok,err=pcall(function()
  emit(runId,"header",{role=role,source=revision,tier=d.detail,engine=version(),warm_seconds=warm,sample_seconds=seconds,
   harness_version=6,viewport={viewport.X,viewport.Y},mode="Free",trace_seconds=trace,clock="normal active simulation; start/end clocks recorded",rain={rainDay,rainHour},
   predator_flags={Wasp=WS:GetAttribute("Wasp"),Cat=WS:GetAttribute("Cat"),Bird=WS:GetAttribute("Bird"),Frog=WS:GetAttribute("Frog")},
   scope="seven static scenes, three seam probes and one continuous three-region walk; desktop Studio; not phone evidence"})
  for _,scene in scenes do
   freshScene(scene)
   local anchor=d.motor.pos;local region=d.world.region.id
   sample(scene.id,function() wait(seconds);assert(d.motor.mode=="attached" and d.world.region.id==region and (d.motor.pos-anchor).Magnitude<.5,"spider left fixture") end)
   wait(1)
  end
  -- Author-tested seam crossings from SelfTest's bench-patch scenario. Movement uses the real input/motor.
  local legs={{from="path_m4",to="pad_a2",z=-508},{from="pad_a2",to="pad_b2",z=-608},{from="pad_c2",to="meadow_a3",z=-810}}
  assert(waitFor(function() return d.fresh("free",false,nil) end,30));d.camera.mouse=false;d.life.clock.day=1;d.life.clock.hour=12
  for i,leg in legs do
   local at=Vector3.new(-60,Meadow.GROUND+HEIGHT,leg.z)
   setAt(leg.from,at,-Vector3.zAxis)
   assert(waitFor(function() return d.world:regionReady(leg.to) end,30),"destination not whole")
   wait(warm)
   sample("walk_"..i,function()
    d.input:simulate("Forward",true)
    local crossed=waitFor(function() return d.world.region.id==leg.to and d.motor.mode=="attached" and (d.motor.pos-at).Magnitude>4 end,12)
    d.input:simulate("Forward",false)
    assert(crossed,"did not cross "..leg.from.." to "..leg.to)
    wait(2)
   end)
  end
  -- Eighth audit scene: one uninterrupted real-input walk. No placement, reset or preloading during it.
  assert(waitFor(function() return d.fresh("free",false,nil) end,30));d.camera.mouse=false;d.title.seen=true
  d.life.clock.day,d.life.clock.hour=1,12;d.life:applyLight()
  local start=Vector3.new(-60,Meadow.GROUND+HEIGHT,-550)
  setAt("pad_a2",start,-Vector3.zAxis);wait(warm)
  local path,order,seen={}, {}, {};local routeBegan=os.clock();local lastRead=-1;local routeElapsed=0
  sample("walk_continuous",function()
   d.input:simulate("Forward",true)
   repeat
    Run.Heartbeat:Wait()
    local elapsed=os.clock()-routeBegan;local region=d.world.region.id
    assert(d.motor.mode=="attached","continuous walk detached")
    assert(math.abs(d.motor.pos.X-start.X)<1,"continuous walk drifted off course")
    if not seen[region] then seen[region]=true;table.insert(order,region) end
    if elapsed-lastRead>=1 then table.insert(path,{elapsed=elapsed,pos=xyz(d.motor.pos),region=region});lastRead=elapsed end
    assert(elapsed<120,"continuous walk stalled")
   until d.motor.pos.Z<=-720
   d.input:simulate("Forward",false)
   local elapsed=os.clock()-routeBegan;routeElapsed=elapsed
   table.insert(path,{elapsed=elapsed,pos=xyz(d.motor.pos),region=d.world.region.id})
   assert(elapsed>=60 and seen.pad_a2 and seen.pad_b2 and seen.pad_c2,"continuous walk too short or missing a required region")
  end)
  emit(runId,"continuous_route",{elapsed=routeElapsed,start=xyz(start),finish=xyz(d.motor.pos),distance=(d.motor.pos-start).Magnitude,
   regions=order,path=path,placement_calls_during_walk=0,fresh_calls_during_walk=0,required_regions={"pad_a2","pad_b2","pad_c2"}})
  -- Optional continuous free-play region cycle: no fresh-life resets during the trace.
  if trace>0 then
   local began=os.clock();local nextMove=began;local nextRead=began;local index=0;local reads=0
   while os.clock()-began<trace do
    if os.clock()>=nextMove then index=index%#scenes+1;setAt(scenes[index].region);nextMove=os.clock()+30 end
    if os.clock()>=nextRead then reads+=1;emit(runId,"trace_"..reads,{elapsed=os.clock()-began,state=compactSnapshot()});nextRead=os.clock()+10 end
    Run.Heartbeat:Wait()
   end
   emit(runId,"trace_end",{elapsed=os.clock()-began,reads=reads,state=compactSnapshot()})
  end
 end)
 d.input:clear();d.prof.stop();focusConnection:Disconnect()
 if ok then print("[CHET_PERF_DONE]",runId,role,revision,d.detail) else warn("[CHET_PERF_FAIL]",runId,tostring(err)) end
 WS:SetAttribute("BenchmarkFinished",true);WS:SetAttribute("BenchmarkPassed",ok)
end
