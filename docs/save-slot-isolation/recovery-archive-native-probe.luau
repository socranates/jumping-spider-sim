-- Private correctness test; no persistent read/write. Never publish.
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local Shared=game.ReplicatedStorage.Shared
local __archivePrototype=require(script.Parent.RecoveryArchivePrototype)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("RecoveryArchiveProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis)
 local ok,err=xpcall(function()
  print("[NATIVE_RECOVERY_ARCHIVE_BEGIN]",id)
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.Heartbeat:Wait() end
  assert(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup failed")
  d.title.seen=true;assert(d.fresh("main",false,nil),"fresh refused");d.openMenu()
  assert(d.menu:isShowing(),"test not paused")
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local Archive=__archivePrototype
local passed=0
local function check(ok,why) assert(ok,why);passed+=1 end
local function sources()
 return {
  progress={loaded=true,value={format="the-windowsill save",kind="progress",schema=999,checksum="opaque",payload={unknown={1,2,"untouched"}},lock={session="old",beat=10}}},
  main={loaded=true,value={format="the-windowsill save",kind="rest_main",schema=2,encoding="zstd-base64-2",bytes=999,data="opaque-not-decoded",backup={schema=87,data="original backup"}}},
  free={loaded=true,value="corrupt but preserved exactly"},
  easy={loaded=true},
 }
end
local input=sources();local original=assert(Json.canonical(input))
local plan,why=Archive.prepare("12345","observed-source-identities",input)
check(plan~=nil,why)
check(Archive.check(plan),"fresh archive plan invalid")
for i,slot in Archive.SLOTS do
 local entry=plan.entries[slot];local desc=plan.index.entries[i]
 check(entry.present==(input[slot].value~=nil),slot.." presence changed")
 check(Json.canonical(entry.raw)==Json.canonical(input[slot].value),slot.." original raw value changed")
 check(desc.slot==slot and desc.key=="A1_12345_"..slot and #desc.key<=50,"descriptor key/order changed")
 check(table.isfrozen(entry) and table.isfrozen(desc),"mutable archive metadata")
end
check(table.isfrozen(plan) and table.isfrozen(plan.entries) and table.isfrozen(plan.index) and table.isfrozen(plan.index.entries),"mutable archive plan")
check(plan.entries.progress.raw~=input.progress.value and plan.entries.progress.raw.payload~=input.progress.value.payload
 and plan.entries.progress.raw.lock~=input.progress.value.lock,"raw nested structures shared")
check(table.isfrozen(plan.entries.progress.raw.payload.unknown) and not pcall(function() plan.entries.progress.raw.payload.unknown[1]=9 end),"nested raw value mutable")
check(Json.canonical(input)==original,"preparation changed originals")
local frozen=assert(Json.canonical(plan))
input.progress.value.payload.unknown[1]=88;input.main.value.backup.data="later edit"
check(Json.canonical(plan)==frozen and Archive.check(plan),"input mutation changed archive")
for _,edit in {
 function(p) p.version=2 end,
 function(p) p.index.version=2 end,
 function(p) p.index.observation="other" end,
 function(p) p.entries.main.raw.data="tampered" end,
 function(p) p.entries.main.raw.backup.data="tampered backup" end,
 function(p) p.entries.free.checksum="wrong" end,
 function(p) p.entries.easy.present=true end,
 function(p) p.entries.easy.raw="invented" end,
 function(p) p.index.entries[1].key="foreign" end,
 function(p) p.index.entries[1].characters+=1 end,
 function(p) p.index.entries[5]={} end,
 function(p) p.entries.foreign={} end,
 function(p) p.entries.main.extra={} end,
 function(p) p.characters+=1 end,
 function(p) p.nodes+=1 end,
 function(p) p.extra={} end,
} do
 local corrupt=Json.copy(plan);edit(corrupt)
 check(not Archive.check(corrupt),"changed archive accepted")
end
for _,owner in {"",string.rep("x",33),"u/foreign","with space",1,false} do
 check(Archive.prepare(owner,"stamp",sources())==nil,"invalid owner accepted")
end
for _,slot in Archive.SLOTS do
 local raw=sources();raw[slot]=nil
 check(Archive.prepare("u1","stamp",raw)==nil,"missing source silently archived")
 raw=sources();raw[slot].loaded=false
 check(Archive.prepare("u1","stamp",raw)==nil,"unavailable source silently archived")
end
for _,raw in {function() end,math.huge,0/0,setmetatable({x=1},{}),{[1]="one",[3]="hole"},{[1]="one",x="mixed"}} do
 local s=sources();s.main.value=raw
 check(Archive.prepare("u1","stamp",s)==nil,"non-storable raw value accepted")
end
local cyclic={};cyclic.self=cyclic
local shared={};local alias={a=shared,b=shared}
for _,raw in {cyclic,alias} do local s=sources();s.main.value=raw;check(Archive.prepare("u1","stamp",s)==nil,"unbounded/aliased raw graph accepted") end
for _,options in {{entry=50},{total=plan.characters-1},{nodes=8},{depth=1},{entry=Archive.MAX_ENTRY_CHARS+1},{total=-1},{nodes=.5}} do
 check(Archive.prepare("12345","observed-source-identities",sources(),options)==nil,"archive size/shape bound bypassed")
end
local unknown=sources();unknown.elsewhere={loaded=true,value="keep"}
check(Archive.prepare("u1","stamp",unknown)==nil,"unknown slot silently omitted")
local incomplete=sources();incomplete.main.err="failed read"
check(Archive.prepare("u1","stamp",incomplete)==nil,"unknown read metadata silently ignored")
-- Exercise actual cooperative preparation and cancellation, without a backend.
local large=sources();large.main.value={}
for i=1,400 do large.main.value[i]={i,"opaque item "..i} end
local before=assert(Json.canonical(large));local clock=0
local function now() clock+=.00001;return clock end
local worker=Work.new(function() return Archive.prepare("u1","snapshot",large) end,{now=now,budget=.0001,maxSeconds=1000,maxResumes=10000})
local suspensions=0
while worker.state=="pending" do worker:step();if worker.state=="pending" then suspensions+=1 end end
local reply=worker:take()
check(reply~=nil and reply[1]~=nil and Archive.check(reply[1]) and suspensions>0,"cooperative archive preparation failed")
check(Json.canonical(large)==before,"cooperative preparation changed source")
local cancelled=Work.new(function() return Archive.prepare("u1","snapshot",large) end,{now=now,budget=.0001,maxSeconds=1000})
cancelled:step()
check(cancelled.state=="pending" and cancelled:cancel() and cancelled:take()==nil and Json.canonical(large)==before,"cancelled plan escaped or changed source")
print("RECOVERY_ARCHIVE passed="..passed.." failed=0 suspensions="..suspensions)

 check(Archive.check(Http:JSONDecode(assert(Json.canonical(plan)))),"native plan JSON round trip")
 for _,slot in Archive.SLOTS do
  local raw=plan.entries[slot].raw
  local copy=if raw~=nil then Http:JSONDecode(Http:JSONEncode(raw)) else nil
  check(Json.canonical(copy)==Json.canonical(raw),"native raw JSON round trip "..slot)
 end
 local Checkpoint=require(Shared.Persistence.Checkpoint)
 local Rest=require(Shared.Persistence.SaveRest)
 local Progress=require(Shared.Persistence.SaveProgress)
 local Envelope=require(Shared.Persistence.SaveEnvelope)
 local world={motor=d.motor,prey=d.prey,sensor=d.sensor,memory=d.memory,needs=d.needs,life=d.life,garden=d.world.garden}
 local record=assert(Checkpoint.capture(world,0));local beforeWorld=assert(Json.canonical(record))
 assert(#Rest.check("main",record,world)==0,"actual client checkpoint invalid")
 local raw=sources()
 raw.progress.value=Envelope.make(Progress.SPEC,Progress.default(),0,nil)
 local prior=Envelope.make(Rest.SPECS.main,record,0,nil)
 raw.main.value=Envelope.make(Rest.SPECS.main,Json.copy(record),1,prior)
 local rawBefore=assert(Json.canonical(raw))
 local actual,problem=Archive.prepare("synthetic_native","raw-source-before-decode",raw)
 check(actual~=nil and Archive.check(actual),problem or "actual envelope archive refused")
 check(Json.canonical(actual.entries.main.raw)==Json.canonical(raw.main.value),"actual envelope/backup changed")
 check(Json.canonical(raw)==rawBefore,"actual raw sources changed")
 check(Json.canonical(assert(Checkpoint.capture(world,0)))==beforeWorld,"archive changed the live client")
 assert(passed==82,"unexpected native assertion count "..passed)
 print("[NATIVE_RECOVERY_ARCHIVE_PASS]",id,passed)
 end,debug.traceback)
 if not ok then warn("[NATIVE_RECOVERY_ARCHIVE_FAIL]",id,tostring(err)) end
end
