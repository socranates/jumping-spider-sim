-- Unpublished diagnostic: ordinary controller/rendering, no storage service.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local Map=require(RS.Shared.World.WorldMap)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and game.GameId==0 and WS:GetAttribute("StartupPerf")==true)
 local run=tostring(math.floor(WS:GetServerTimeNow()*1000))
 local function emit(kind,value) print("[STARTUP_FRAME_"..kind.."]",run,Http:JSONEncode(value)) end
 local function waitFor(fn,seconds)
  local untilAt=os.clock()+seconds
  repeat if fn() then return end;Run.Heartbeat:Wait() until os.clock()>=untilAt
  error("diagnostic readiness deadline")
 end
 local function sample(name,seconds)
  d.prof.start()
  local frames,total,worst,over50=0,0,0,0
  local outliers={};local started=os.clock();local elapsed=d.life.elapsed
  emit("BEGIN",{name=name,seconds=seconds,position={d.motor.pos.X,d.motor.pos.Y,d.motor.pos.Z}})
  local connection=Run.Heartbeat:Connect(function(dt)
   frames+=1;total+=dt;worst=math.max(worst,dt)
   if dt>.05 then
    over50+=1
    if #outliers<20 then table.insert(outliers,{at=os.clock()-started,dt=dt,loading=d.world.playerLoading==true,ended=d.session.ended==true}) end
   end
  end)
  repeat Run.Heartbeat:Wait() until os.clock()-started>=seconds
  connection:Disconnect();d.prof.stop()
  local rows,n,mean,cpuWorst=d.prof.rows()
  table.sort(rows,function(a,b) return a.mean>b.mean end)
  for _,row in rows do emit("PART",{name=name,part=row.name,mean_ms=row.mean,worst_ms=row.worst}) end
  emit("END",{name=name,frames=frames,render_frames=n,seconds=total,worst_ms=worst*1000,over_50ms=over50,
   render_mean_ms=mean,render_worst_ms=cpuWorst,simulation_seconds=d.life.elapsed-elapsed,
   ended=d.session.ended==true,loading=d.world.playerLoading==true,outliers=outliers})
 end
 local ok,why=xpcall(function()
  emit("READY",{detail=d.detail,clock_scale=1,storage="disabled",source="bd67582b5d53473f067244fc1e2e1f94adde173b"})
  sample("startup-held",12)
  waitFor(function() return not d.saveClient:waiting() and (not d.navigation or d.navigation.status=="ready") end,90)
  d.title.seen=true;d.title:stop()
  assert(d.fresh("main",false,nil),"ordinary fresh Main refused")
  d.title:stop()
  waitFor(function() return not d.world.playerLoading and d.motor.mode=="attached" end,60)
  sample("main-home",25)
  local destination
  for _,region in Map.regions(Map.SEED) do
   if region.id=="hut_garden" then destination=region end
  end
  if destination and not d.session.ended then
   d.place(destination.spawn.pos+Vector3.new(0,.31,0),destination.spawn.up)
   waitFor(function() return not d.world.playerLoading and d.motor.mode=="attached" end,60)
   sample("garden",25)
  else emit("SKIP",{name="garden",reason=if d.session.ended then "life-ended" else "destination-not-authored"}) end
  emit("PASS",{storage="disabled",foreground_required=true,device="local-laptop",representative_fps_proved=false})
 end,debug.traceback)
 if not ok then emit("FAIL",{problem=tostring(why)}) end
 WS:SetAttribute("StartupPerfFinished",true);WS:SetAttribute("StartupPerfPassed",ok)
end
