-- Isolated actual-client save-cost attribution. Never publish this diagnostic.
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local Json=require(Shared.Persistence.Json)
local Checkpoint=require(Shared.Persistence.Checkpoint)
local Objects=require(Shared.Persistence.ObjectRecord)
local Store=require(Shared.Persistence.CheckpointStore)
local Map=require(Shared.World.WorldMap)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("SaveCostProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis)
 local metrics,undo={},{}
 local phase="setup"
 local accumulated,stepStart=0,nil
 local function cpuNow()
  if string.find(phase,".prepare",1,true) then
   return accumulated+(if stepStart then os.clock()-stepStart else 0)
  end
  return os.clock()
 end
 local function watch(module,name,label)
  local original=module[name]
  table.insert(undo,function() module[name]=original end)
  module[name]=function(...)
   local key=phase..":"..label;local at=cpuNow()
   local reply=table.pack(original(...));local cost=cpuNow()-at
   local r=metrics[key] or {calls=0,seconds=0,worst=0,chars=0}
   r.calls+=1;r.seconds+=cost;r.worst=math.max(r.worst,cost)
   if type(reply[1])=="string" then r.chars+=#reply[1] end
   metrics[key]=r
   return table.unpack(reply,1,reply.n)
  end
 end
 local manager=d.saveState.rest;local update=manager.update
 local checks=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local ok,problem=xpcall(function()
  print("[NATIVE_SAVE_COST_BEGIN]",id)
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup failed")
  d.title.seen=true;d.session.finishedMain=true;check(d.fresh("main",false,nil),"fresh refused")
  d.place(Vector3.new(-25.5,.31,6));for _=1,6 do Run.Heartbeat:Wait() end
  d.openMenu()
  local attempts=0
  for _,r in Map.regions() do
   d.world.prey:directors(r.id);d.world.prey:bugs(r.id);d.world.prey:ambient(r.id)
   attempts+=1;if attempts%4==0 then Run.Heartbeat:Wait() end
  end
  d.place(Vector3.new(-25.5,.31,6));d.motor.vel=Vector3.zero;d.life.clock.hour=12;d.needs.energy=.9
  for _,name in {"canonical","copy","checksum"} do watch(Json,name,"Json."..name) end
  for _,name in {"capture","check"} do watch(Checkpoint,name,"Checkpoint."..name) end
  for _,name in {"capture","decode"} do watch(Objects,name,"ObjectRecord."..name) end
  for _,name in {"GetAsync","SetAsync","RemoveAsync"} do watch(Store.MemoryDataStore,name,"Memory."..name) end
  for _,name in {"first","replacement"} do
   phase=name..".capture"
   local old=d.currentStore();local count=d.life.checkpoints
   local at=os.clock();local token=d.life.save();local captureMs=(os.clock()-at)*1000
   check(token.pending and not token.ok and d.currentStore()==old,"capture published early")
   print("[NATIVE_SAVE_COST_CAPTURE]",id,name,string.format("%.3f",captureMs))
   phase=name..".prepare"
   accumulated=0;local steps,worst,gap=0,0,0
   manager.update=function(self)
    stepStart=os.clock();update(self);local cost=os.clock()-stepStart
    accumulated+=cost;steps+=1;worst=math.max(worst,cost);stepStart=nil
   end
   at=os.clock();deadline=at+120
   while token.pending and os.clock()<deadline do gap=math.max(gap,Run.Heartbeat:Wait()) end
   manager.update=update
   check(not token.pending and token.ok and steps>1,"preparation failed or did not span frames")
   check(d.currentStore()~=old and d.life.checkpoints==count+1,"rest publication not exactly once")
   print("[NATIVE_SAVE_COST_WORK]",id,name,steps,string.format("%.3f",accumulated*1000),string.format("%.3f",worst*1000),string.format("%.3f",gap*1000),string.format("%.3f",(os.clock()-at)*1000))
   phase=name..".verify"
   local best=d.currentStore():loadBest();check(best.ok,"committed rest invalid")
   local text=assert(Json.canonical(best.record))
   print("[NATIVE_SAVE_COST_RECORD]",id,name,#text,attempts,"resident_regions_unmeasured")
  end
  local keys={};for key in metrics do table.insert(keys,key) end;table.sort(keys)
  for _,key in keys do
   local r=metrics[key]
   print("[NATIVE_SAVE_COST_CALL]",id,key,r.calls,string.format("%.3f",r.seconds*1000),string.format("%.3f",r.worst*1000),r.chars)
  end
  print("[NATIVE_SAVE_COST_PASS]",id,checks,"inclusive_rows_overlap_not_fps")
 end,debug.traceback)
 manager.update=update;stepStart=nil
 for i=#undo,1,-1 do undo[i]() end
 if not ok then warn("[NATIVE_SAVE_COST_FAIL]",id,tostring(problem)) end
end
