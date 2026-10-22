-- Local diagnostic only. One continuous Free life, region placements, no save backend.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
local Stats=game:GetService("Stats")
local Http=game:GetService("HttpService")
local UIS=game:GetService("UserInputService")
local Gui=game:GetService("GuiService")
local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
local Pond=require(game.ReplicatedStorage.Shared.World.Pond)
local function xyz(v) return {v.X,v.Y,v.Z} end
local function count(t) local n=0;for _ in t do n+=1 end;return n end
local function adler(s)
 local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;return b*65536+a
end
local function emit(run,kind,data)
 local s=Http:JSONEncode(data);local n=math.ceil(#s/250)
 print("[MEMTRACE_BEGIN]",run,kind,#s,n,adler(s))
 for i=1,n do print("[MEMTRACE_DATA]",run,kind,i,Http:JSONEncode(s:sub((i-1)*250+1,i*250))) end
 print("[MEMTRACE_END]",run,kind)
end
local function finite(n) return type(n)=="number" and n==n and n>=0 and n<math.huge end
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and WS:GetAttribute("MemoryTrace")==true,"local memory trace only")
 assert(WS:GetAttribute("SelfTest")==false and WS:GetAttribute("TestTarget")==false)
 local run=tostring(DateTime.now().UnixTimestampMillis)
 local duration=assert(WS:GetAttribute("TraceDurationSeconds"))
 local dwell=assert(WS:GetAttribute("TraceDwellSeconds"))
 local sampleEvery=15
 local profile=assert(WS:GetAttribute("TraceProfile"))
 local connections={}
 local ok,err=pcall(function()
  assert(duration==90 or duration==1800,"unexpected duration")
  assert((profile=="smoke" and duration==90 and dwell==3) or (profile=="long" and duration==1800 and dwell==30))
  assert(Map.world()=="preserve" and d.detail==WS:GetAttribute("Detail"))
  assert(Stats.MemoryTrackingEnabled==true,"category memory tracking unavailable; do not run blind for 30 minutes")
  local tags=Enum.DeveloperMemoryTag:GetEnumItems();table.sort(tags,function(a,b) return a.Name<b.Name end)
  local tagNames={};for _,tag in tags do table.insert(tagNames,tag.Name) end
  local function memory()
   local m={engine_mb=Stats:GetTotalMemoryUsageMb(),lua_gc_mib=gcinfo()/1024,instances=Stats.InstanceCount,tags_mb={}}
   assert(finite(m.engine_mb) and m.engine_mb>0 and finite(m.lua_gc_mib) and m.instances>0,"missing memory counters")
   for _,tag in tags do
    local value=Stats:GetMemoryUsageMbForTag(tag);assert(finite(value),"invalid memory tag "..tag.Name)
    m.tags_mb[tag.Name]=value
   end
   assert(m.tags_mb.LuaHeap~=nil and m.tags_mb.Instances~=nil,"required memory tags absent")
   return m
  end
  memory() -- Fail early on unsupported counters.
  d.title.seen=true;d.camera.mouse=false
  local attempts=0;local ready=false;local deadline=os.clock()+30
  repeat attempts+=1;if d.fresh("free",false,nil) then ready=true;break end;Run.Heartbeat:Wait() until os.clock()>deadline
  assert(ready,"cannot start the single trace life")
  local boot=os.clock();local changed=boot;local previous=WS.CurrentCamera.ViewportSize
  repeat
   Run.Heartbeat:Wait();local size=WS.CurrentCamera.ViewportSize
   if size~=previous then previous=size;changed=os.clock() end
   assert(os.clock()-boot<45,"viewport did not settle")
  until previous.X>=320 and previous.Y>=180 and os.clock()-boot>=10 and os.clock()-changed>=3
  local viewport=WS.CurrentCamera.ViewportSize
  local focusLosses=0
  table.insert(connections,UIS.WindowFocusReleased:Connect(function() focusLosses+=1 end))
  local regions={"sill","hut_desk","garden_b2","meadow_b2","pond_a2","hut_doorway","lamp_1"}
  local began=os.clock();local beganUtc=DateTime.now().UnixTimestampMillis
  local stopAt=began+duration
  local simStart=d.world.prey.clock;local lastSim=simStart;local activeAt=began
  local generation=d.life.generation or 0
  local phase="transition";local wanted="sill";local visit=0;local visitsDone=0;local placements=0
  local samples=0;local nextSample=began;local seen={};local minMemory=nil
  local frames=0;local frameSeconds=0;local maxFrame=0
  local windowFrames=0;local windowSeconds=0;local windowMax=0
  table.insert(connections,Run.RenderStepped:Connect(function(dt)
   frames+=1;frameSeconds+=dt;maxFrame=math.max(maxFrame,dt)
   windowFrames+=1;windowSeconds+=dt;windowMax=math.max(windowMax,dt)
  end))
  local function guards()
   assert(focusLosses==0,"Studio lost focus during trace")
   assert(WS.CurrentCamera.ViewportSize==viewport,"viewport changed during trace")
   assert(not Gui.MenuIsOpen and not d.menu:isShowing() and not d.caughtPanel:isShowing(),"trace paused by a menu")
   assert(d.session.started and d.session.mode=="free" and d.session.rules=="gentle" and not d.session.ended and not d.life.lifeOver,"life stopped or changed")
   assert(not d.life.resting and not d.life.growth:isMoulting(),"trace entered rest/moult")
   assert((d.life.generation or 0)==generation,"generation changed during trace")
   local sim=d.world.prey.clock
   assert(sim>=lastSim,"simulation clock reset: recovery/new life invalidates this trace")
   if sim>lastSim then lastSim=sim;activeAt=os.clock() end
   assert(os.clock()-activeAt<5,"simulation did not advance for five seconds")
   for _,key in {"Wasp","Cat","Bird","Frog"} do assert(WS:GetAttribute(key)==true,"predator flag changed: "..key) end
   for _,actor in {d.wasp,d.cat,d.bird,d.frog,d.crab} do assert(actor.enabled==true,"predator disabled") end
  end
  local function snapshot()
   local m=memory();local active={};for _,id in d.world.prey.active do table.insert(active,id) end;table.sort(active)
   local actors={};for _,f in d.world.prey:flies() do
    local kind=if f.profile and f.profile.body then f.profile.body.prey_kind or f.profile.id else "unknown"
    actors[kind]=(actors[kind] or 0)+1
   end
   local looks=d.world.looks;local sets=0
   if looks then for _,look in looks.looks do sets+=count(look.sets) end end
   return {elapsed=os.clock()-began,utc_ms=DateTime.now().UnixTimestampMillis,phase=phase,wanted=wanted,visit=visit,
    pos=xyz(d.motor.pos),mode=d.motor.mode,region=d.world.region.id,region_ready=d.world:regionReady(d.world.region.id),
    day=d.life.clock.day,hour=d.life.clock.hour,sim_seconds=d.world.prey.clock-simStart,
    mode_name=d.session.mode,rules=d.session.rules,stage=d.life.growth.stage,meals=d.prey.feeding.mealsFinished,
    memory=m,active_regions=active,actors=actors,initialized_regions=count(d.world.garden),directors_made=d.world.prey.made,
    predator_enabled={wasp=d.wasp.enabled,cat=d.cat.enabled,bird=d.bird.enabled,frog=d.frog.enabled,crab=d.crab.enabled},
    looks=if looks then {live_regions=count(looks.looks),live_sets=sets,jobs=#looks.jobs,made=looks.made,destroyed=looks.destroyed,plans=looks.plans} else nil,
    living_parts=if d.world.living then d.world.living.count else nil,focus_losses=focusLosses,
    viewport={viewport.X,viewport.Y},world_focus_reports=d.world.reports,placements=placements,
    frames={count=windowFrames,seconds=windowSeconds,max_ms=windowMax*1000}}
  end
  local function minima(m)
   if minMemory==nil then minMemory={engine_mb=m.engine_mb,lua_gc_mib=m.lua_gc_mib,instances=m.instances,tags_mb=table.clone(m.tags_mb)};return end
   for _,key in {"engine_mb","lua_gc_mib","instances"} do minMemory[key]=math.min(minMemory[key],m[key]) end
   for key,value in m.tags_mb do minMemory.tags_mb[key]=math.min(minMemory.tags_mb[key],value) end
  end
  local function takeSample()
   guards();samples+=1;local s=snapshot()
   if phase=="dwell" then minima(s.memory) end
   emit(run,"sample_"..samples,s)
   windowFrames=0;windowSeconds=0;windowMax=0
   nextSample=os.clock()+sampleEvery
  end
  local function pulse()
   Run.Heartbeat:Wait();guards()
   if os.clock()>=nextSample then takeSample() end
  end
  emit(run,"header",{harness_version=1,source=WS:GetAttribute("TraceSource"),profile=profile,tier=d.detail,engine=version(),
   duration_seconds=duration,dwell_seconds=dwell,sample_seconds=sampleEvery,regions=regions,viewport={viewport.X,viewport.Y},
   began_utc_ms=beganUtc,fresh_attempts_before_trace=attempts,fresh_successes_before_trace=1,fresh_calls_during_trace=0,
   recovery_calls_during_trace=0,forced_gc_calls=0,memory_tracking_enabled=Stats.MemoryTrackingEnabled,memory_tags=tagNames,
   mode="Free",persistence_disabled=true,scope="One continuous life with explicit region placements; not a walking tour, online-save test, phone test or FPS comparison"})
  while os.clock()<stopAt do
   visit+=1;wanted=regions[(visit-1)%#regions+1];phase="transition";minMemory=nil
   local region=assert(Map.region(wanted));local pos=region.spawn.pos+Vector3.yAxis*.31
   if wanted=="pond_a2" then local site=Pond.FROG_SITES[1];pos=assert(Pond.frogSeat(site,Map.regions()))-site.facing*4+Vector3.yAxis*.31 end
   local nextPlace=-math.huge;local moveBegan=os.clock()
   repeat
    if os.clock()>=nextPlace then d.place(pos,Vector3.yAxis);placements+=1;nextPlace=os.clock()+.25 end
    pulse()
    assert(os.clock()-moveBegan<30,"streaming did not reach "..wanted)
   until (d.world.region.id==wanted and d.world:regionReady(wanted) and d.motor.mode=="attached") or os.clock()>=stopAt
   if os.clock()>=stopAt then break end
   phase="dwell";local dwellBegan=os.clock();seen[wanted]=true
   emit(run,"arrival_"..visit,{elapsed=os.clock()-began,visit=visit,region=wanted,transition_seconds=os.clock()-moveBegan,placements=placements,pos=xyz(d.motor.pos)})
   repeat
    pulse()
    assert(Map.at(d.motor.pos)~=nil,"spider left the authored map")
    assert(d.world.region.id==wanted and (d.motor.pos-pos).Magnitude<8,"spider left the dwell fixture: "..wanted)
   until os.clock()-dwellBegan>=dwell or os.clock()>=stopAt
   if os.clock()-dwellBegan>=dwell then
    local s=snapshot();minima(s.memory);visitsDone+=1
    emit(run,"visit_"..visit,{elapsed=os.clock()-began,visit=visit,region=wanted,dwell_seconds=os.clock()-dwellBegan,
     memory_min=minMemory,state=s})
   end
  end
  takeSample();guards()
  local elapsed=os.clock()-began;local simulated=d.world.prey.clock-simStart
  assert(elapsed>=duration and frames>duration and simulated>=elapsed*.5,"insufficient active rendered/simulated time")
  assert(count(seen)==#regions,"not every required habitat was visited")
  emit(run,"final",{elapsed=elapsed,utc_ms=DateTime.now().UnixTimestampMillis,frames=frames,frame_seconds=frameSeconds,max_frame_ms=maxFrame*1000,
   sim_seconds=simulated,samples=samples,visits=visitsDone,placements=placements,visited=seen,focus_losses=focusLosses,
   viewport={viewport.X,viewport.Y},state=snapshot(),fresh_calls_during_trace=0,recovery_calls_during_trace=0,forced_gc_calls=0})
 end)
 for _,connection in connections do connection:Disconnect() end
 d.input:clear()
 if ok then print("[MEMTRACE_DONE]",run,profile,duration) else warn("[MEMTRACE_FAIL]",run,tostring(err)) end
 WS:SetAttribute("MemoryTraceFinished",true);WS:SetAttribute("MemoryTracePassed",ok)
end
