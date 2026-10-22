-- Diagnostic only: real client save path under CLI shim, not native FPS evidence.
local Layout=require("../src/Shared/Habitat/WindowsillLayout")
local Map=require("../src/Shared/World/WorldMap")
local Json=require("../src/Shared/Persistence/Json")
local Checkpoint=require("../src/Shared/Persistence/Checkpoint")
local ObjectRecord=require("../src/Shared/Persistence/ObjectRecord")
local Store=require("../src/Shared/Persistence/CheckpointStore")
local metrics={}
local phase="boot"
local function watch(module,name,label)
 local original=module[name]
 module[name]=function(...)
  local at=os.clock()
  local reply=table.pack(original(...))
  local key=phase..":"..label
  local row=metrics[key] or {calls=0,seconds=0,maxSeconds=0,chars=0}
  local cost=os.clock()-at
  row.calls+=1;row.seconds+=cost;row.maxSeconds=math.max(row.maxSeconds,cost)
  if type(reply[1])=="string" then row.chars+=#reply[1] end
  metrics[key]=row
  return table.unpack(reply,1,reply.n)
 end
end
for _,name in {"canonical","copy","checksum"} do watch(Json,name,"Json."..name) end
for _,name in {"capture","check"} do watch(Checkpoint,name,"Checkpoint."..name) end
for _,name in {"capture","decode"} do watch(ObjectRecord,name,"ObjectRecord."..name) end
for _,name in {"GetAsync","SetAsync","RemoveAsync"} do watch(Store.MemoryDataStore,name,"Memory."..name) end
local WorldBuild=require("../src/Shared/World/WorldBuild")
workspace:ClearAllChildren()
workspace:SetAttribute("World","preserve")
Map.use("preserve")
WorldBuild.world(workspace,Map.SEED)
local loaded=require("../src/Client/SpiderClient.client")
local d=ClientStubs.driver
local frame=ClientStubs.renderSteps.SpiderSim
for _=1,5000 do
 frame(1/60)
 if game:GetService("Players").LocalPlayer:GetAttribute("TitleReady")==true then break end
end
assert(game:GetService("Players").LocalPlayer:GetAttribute("TitleReady")==true,"preserve startup failed")
d.title.seen=true;d.session.finishedMain=true
assert(d.fresh("main",false,nil))
d.place(Vector3.new(-25.5,.31,6))
for _=1,6 do frame(1/60) end
d.openMenu()
local attempts=0
for _,r in Map.regions() do
 d.world.prey:directors(r.id);d.world.prey:bugs(r.id);d.world.prey:ambient(r.id)
 attempts+=1
end
d.place(Vector3.new(-25.5,.31,6));d.motor.vel=Vector3.zero
d.life.clock.hour=12;d.needs.energy=.9
-- Immediate back-to-back resumes: inclusive timings exclude no deliberate waits,
-- but include scheduler/OS overhead and nested operations. Never add rows together.
d.saveState.rest.cfg.workOptions={budget=.002,maxSeconds=1000}
for _,name in {"first","replacement"} do
 phase=name..".capture"
 local at=os.clock();local token=d.life.save()
 assert(token.pending,token.message)
 print("PROFILE_CAPTURE",name,(os.clock()-at)*1000)
 phase=name..".prepare"
 local steps,total,worst=0,0,0
 while token.pending and steps<10000 do
  at=os.clock();d.saveState.rest:update();local cost=os.clock()-at
  total+=cost;worst=math.max(worst,cost);steps+=1
 end
 assert(token.ok and not token.pending,"profile preparation failed")
 phase=name..".verify"
 local rest=d.currentStore():loadBest();assert(rest.ok)
 local text=assert(Json.canonical(rest.record))
 assert(attempts==233 and #text>1000000,"fixture did not create a large preserve save")
 print("PROFILE_REST",name,#text,steps,total*1000,worst*1000,attempts)
end
local keys={};for key in metrics do table.insert(keys,key) end;table.sort(keys)
for _,key in keys do
 local r=metrics[key]
 print("PROFILE_CALL",key,r.calls,r.seconds*1000,r.maxSeconds*1000,r.chars)
end
print("PROFILE_PASS")
