-- Local diagnostic only. Persistence must be disabled by the guarded builder.
local Run=game:GetService("RunService")
local P=game.ReplicatedStorage.Shared.Persistence
local Work=require(P.SaveWork)
local Json=require(P.Json)
local Checkpoint=require(P.Checkpoint)
local Store=require(P.CheckpointStore)
local SaveRest=require(P.SaveRest)
local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("SaveWorkProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis)
 local checks=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function run(name,fn)
  local work=Work.new(fn,{budget=.002,maxSeconds=120})
  local maxStep,maxGap,steps=0,0,0
  local begin=os.clock()
  while work.state=="pending" do
   maxGap=math.max(maxGap,Run.Heartbeat:Wait())
   local at=os.clock();work:step();steps+=1;maxStep=math.max(maxStep,os.clock()-at)
  end
  check(work.state=="done",name..": "..tostring(work.problem))
  print("[NATIVE_SAVE_WORK_STAGE]",id,name,steps,string.format("%.3f",maxStep*1000),string.format("%.3f",maxGap*1000),string.format("%.3f",(os.clock()-begin)*1000))
  return assert(work:take()),steps
 end
 local ok,problem=xpcall(function()
  print("[NATIVE_SAVE_WORK_BEGIN]",id)
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup failed")
  d.title.seen=true;d.session.finishedMain=true
  check(d.fresh("main",false,nil),"fresh life refused")
  d.openMenu()
  local attempts=0
  for _,r in Map.regions() do
   d.world.prey:directors(r.id);d.world.prey:bugs(r.id);d.world.prey:ambient(r.id)
   attempts+=1;if attempts%4==0 then Run.Heartbeat:Wait() end
  end
  local world={motor=d.motor,prey=d.prey,sensor=d.sensor,memory=d.memory,needs=d.needs,life=d.life,wasp=d.wasp,garden=d.world.garden,cat=d.cat,water=d.water}
  -- Capture is synchronous: the job below owns this finished plain record.
  -- Streaming readiness was not counted, so attempts are not resident regions.
  local record=assert(Checkpoint.capture(world,120))
  local expected=assert(Json.canonical(record));local hash=Json.checksum(expected)
  print("[NATIVE_SAVE_WORK_RECORD]",id,attempts,#expected,"resident_regions_unmeasured")
  local result,steps=run("copy_encode_hash",function()
   local copy=Json.copy(record);local text=assert(Json.canonical(copy))
   return copy,text,Json.checksum(text)
  end)
  check(steps>1 and result[1]~=record and result[2]==expected and result[3]==hash,"copy/bytes/hash changed")
  local checked,checksSteps=run("full_validation",function() return SaveRest.check("main",record,world) end)
  check(#checked[1]==0 and checksSteps>1,"full native record rejected")
  local current=d.currentStore();local original=d.stores.main
  local staging=Store.new(Store.MemoryDataStore.new(),function(r) return (Checkpoint.check(r,world)) end)
  local cancelled=Work.new(function() return staging:save(record) end,{budget=.000001,maxSeconds=120})
  cancelled:step();check(cancelled.state=="pending","cancel case did not pause")
  check(cancelled:cancel() and cancelled:take()==nil,"cancelled result escaped")
  check(d.currentStore()==current and d.stores.main==original,"cancel changed live store")
  local stored,storeSteps=run("private_store",function() return staging:save(record) end)
  check(stored[1].ok and storeSteps>1,"staging store failed")
  local loaded=staging:loadBest()
  check(loaded.ok and Json.canonical(loaded.record)==expected,"staged rest differs")
  check(d.currentStore()==current and d.stores.main==original,"private preparation replaced live store")
  print("[NATIVE_SAVE_WORK_DONE]",id,checks,"preparation_only")
 end,debug.traceback)
 if not ok then warn("[NATIVE_SAVE_WORK_FAIL]",id,tostring(problem)) end
 workspace:SetAttribute("SaveWorkProbeDone",true);workspace:SetAttribute("SaveWorkProbePassed",ok)
end
