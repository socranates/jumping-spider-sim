local Json=require("../src/Shared/Persistence/Json")
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Collector=__collectorPrototype
local Archive=__archivePrototype
local passed=0
local function check(ok,why) assert(ok,why);passed+=1 end
local function fixture(session,bounds,work)
 local b=Memory.new();local fresh=b.read
 b.readRawFresh=function(self,key) return fresh(self,key) end
 b.read=function() error("ordinary cached/decoded read must not be used") end
 b:poke("P_12345",{schema=999,checksum="opaque",payload={unknown={"keep","everything"}},lock={session="lease-A",beat=10}})
 b:poke("R_12345_main",{encoding="future-compression",data="opaque-current",backup={data="opaque-backup",extra=true}})
 b:poke("R_12345_free","corrupt but storable original")
 return b,Collector.new(b,"12345",session,bounds,work)
end
local function raw(b) return assert(Json.canonical(b.data)) end
local function start(c,guard) return c:begin("intent/source observation",guard or function() return true end) end
local function step(c,j)
 local before=c.backend.requests;local wanted=c:wantsRead(j);local asked=c:step(j)
 local delta=c.backend.requests-before
 check(delta<=1,"one collection step issued multiple requests")
 check(not asked or delta==1,"request result disagrees with actual backend activity")
 check(wanted or delta==0,"CPU-only preparation made a backend request")
end
local function drive(c,j)
 for _=1,20000 do if j.state~="pending" then return end;step(c,j) end
 error("collection did not settle")
end
local function untilPhase(c,j,phase)
 for _=1,20000 do if j.phase==phase or j.state~="pending" then return end;step(c,j) end
 error("collection did not reach phase")
end
do
 local b,c=fixture();local before=raw(b);local j=start(c)
 check(j.plan==nil and next(j.sources)==nil,"unread slots looked loaded")
 step(c,j);check(j.sources.progress==nil and j.work~=nil,"raw API result was exposed before owned preparation")
 while j.cursor==1 and j.phase=="collect" and j.state=="pending" do step(c,j) end
 local captured=j.sources.progress
 check(captured.loaded and table.isfrozen(captured) and table.isfrozen(captured.value.payload.unknown),"raw snapshot is not owned/frozen")
 check(j.sources.main==nil and j.plan==nil,"unread slot fabricated or partial plan exposed")
 drive(c,j)
 check(j.state=="complete" and j.reads==8 and j.verified==4 and b.requests==8 and b.writes==0,"collection did not make exactly eight read-only observations")
 check(Archive.check(j.plan),"complete archive plan invalid")
 check(j.plan.entries.progress.raw.schema==999 and j.plan.entries.main.raw.backup.data=="opaque-backup","future/corrupt representation lost")
 check(j.plan.entries.free.raw=="corrupt but storable original" and not j.plan.entries.easy.present,"corrupt or physically missing value changed")
 check(raw(b)==before and next(j.sources)==nil,"collector changed original keys or retained duplicate raw buffers")
 for _,op in b.log do check(op.op=="read" and (op.key=="P_12345" or op.key=="R_12345_main" or op.key=="R_12345_free" or op.key=="R_12345_easy"),"unexpected operation/key") end
 local oldPlan=j.plan;local again=start(c);check(Archive.check(oldPlan) and not c:step(j),"new observation damaged a completed immutable plan")
 c:cancel(again)
end
-- Only an explicit same-session heartbeat exception is allowed; its original
-- raw metadata still belongs in the immutable archive, exactly as first read.
for _,kind in {"heartbeat","no-lease","foreign-lease","backward","setting","checksum","backup","unknown-lock","missing-lock","signed-zero"} do
 local b,c=fixture(if kind=="no-lease" then nil else "lease-A")
 if kind=="signed-zero" then b.data.P_12345.payload.zero=0 end
 local first=assert(Json.canonical(b.data.P_12345));local j=start(c);untilPhase(c,j,"verify")
 if kind=="foreign-lease" then b.data.P_12345.lock.session="lease-B"
 elseif kind=="backward" then b.data.P_12345.lock.beat=9
 elseif kind=="setting" then b.data.P_12345.payload.settings={SoundMuted=true}
 elseif kind=="checksum" then b.data.P_12345.checksum="changed"
 elseif kind=="backup" then b.data.P_12345.backup={unknown="new backup"}
 elseif kind=="unknown-lock" then b.data.P_12345.lock.newField=true
 elseif kind=="missing-lock" then b.data.P_12345.lock=nil
 elseif kind=="signed-zero" then b.data.P_12345.payload.zero=-1/math.huge
 else b.data.P_12345.lock.beat=11 end
 local changed=raw(b);drive(c,j)
 if kind=="heartbeat" then
  check(j.state=="complete" and Json.canonical(j.plan.entries.progress.raw)==first,"owned heartbeat destroyed original metadata or prevented stable-content collection")
 else check(j.state=="changed" and j.plan==nil and not c:retry(j),"changed source accepted: "..kind) end
 check(raw(b)==changed and b.writes==0,"verification rewrote changed source")
end
-- Every first-pass and verification failure remains unavailable/retryable,
-- never a fabricated physical absence or an implicitly rebased observation.
for _,phase in {"collect","verify"} do
 for _,slot in Archive.SLOTS do
  local b,c=fixture();local before=raw(b);local j=start(c)
  if phase=="verify" then untilPhase(c,j,"verify") end
  local key=if slot=="progress" then "P_12345" else "R_12345_"..slot
  b:fail({op="read",key=key,times=1});drive(c,j)
  check(j.state=="retry" and j.plan==nil,"failed read became missing or complete")
  if phase=="collect" then check(j.sources[slot]==nil,"failed first read marked source loaded") end
  check(c:retry(j),"transient raw read cannot retry")
  drive(c,j);check(j.state=="complete" and j.reads==9 and b.requests==9,"retry skipped or repeated a source observation")
  check(raw(b)==before and b.writes==0,"retry mutated original values")
 end
end
for _,mode in {"false","error","cancel-before","cancel-read","supersede-read"} do
 local b,c=fixture();local j
 local guard=function() return true end
 if mode=="false" then guard=function() return false end
 elseif mode=="error" then guard=function() error("fence failed") end end
 j=start(c,guard)
 if mode=="cancel-before" then c:cancel(j)
 elseif mode=="cancel-read" or mode=="supersede-read" then
  local read=b.readRawFresh
  b.readRawFresh=function(self,key)
   if mode=="cancel-read" then c:cancel(j) else c:begin("new intent",function() return true end) end
   return read(self,key)
  end
 end
 step(c,j)
 check(j.plan==nil and (j.state=="refused" or j.state=="cancelled"),"invalidated collection published a result")
 check(b.requests==(if mode=="cancel-read" or mode=="supersede-read" then 1 else 0),"invalidation admitted another request")
end
do
 local b,c=fixture();local first=b.readRawFresh;local suspended=false;local inFlight,peak=0,0
 b.readRawFresh=function(self,key)
  inFlight+=1;peak=math.max(peak,inFlight)
  if not suspended then suspended=true;coroutine.yield("raw-request-pending") end
  local ok,value,why=first(self,key);inFlight-=1;return ok,value,why
 end
 local j=start(c);local co=coroutine.create(function() return c:step(j) end)
 local ok,signal=coroutine.resume(co);check(ok and signal=="raw-request-pending" and c.busy,"raw request did not suspend")
 check(not c:step(j),"reentrant collection started another request")
 c:cancel(j);local newer=start(c);check(not c:step(newer),"new intent overlapped a suspended backend request")
 ok=coroutine.resume(co);check(ok and coroutine.status(co)=="dead" and j.state=="cancelled" and j.plan==nil,"old request revived cancelled intent")
 drive(c,newer);check(newer.state=="complete" and peak==1 and b.requests==9,"new intent could not safely resume after old request finished")
end
local function cooperative(maxResumes)
 local clock=0;local function now() clock+=.00001;return clock end
 local b,c=fixture(nil,nil,{now=now,budget=.0000001,maxSeconds=1000,maxResumes=maxResumes or 100000})
 b.data.P_12345.large={};for i=1,1000 do b.data.P_12345.large[i]="raw"..i end
 return b,c
end
do
 local b,c=cooperative();local before=raw(b);local j=start(c)
 step(c,j);local worker=j.work;step(c,j)
 check(worker.state=="pending" and worker.resumes==1 and not c.busy,"raw preparation did not yield/release worker admission")
 check(c:cancel(j) and worker.state=="cancelled" and j.work==nil and j.plan==nil and next(j.sources)==nil,"CPU cancellation retained work or published partial data")
 local newer=start(c);drive(c,newer)
 check(newer.state=="complete" and raw(b)==before,"cancelled preparation poisoned the next observation")
end
do
 local b,c=cooperative();local j=start(c);untilPhase(c,j,"prepare");local worker=j.work
 check(j.verified==4 and j.reads==8 and j.plan==nil,"plan exposed before final bounded preparation")
 c:cancel(j);check(worker.state=="cancelled" and j.plan==nil and b.writes==0,"final preparation cancellation committed data")
end
do
 local b,c=cooperative(1);local j=start(c);drive(c,j)
 check(j.state=="refused" and j.work==nil and j.plan==nil and b.requests==1,"timed-out raw preparation made progress or leaked work")
end
-- Freeze owned snapshots before another request; a later mutation of even an
-- aliasing injected backend cannot change the earlier observation.
do
 local b,c=fixture();b.readRawFresh=function(self,key) self.requests+=1;return true,self.data[key],nil end
 local j=start(c)
 while j.cursor==1 and j.phase=="collect" do step(c,j) end
 local owned=j.sources.progress.value;b.data.P_12345.payload.unknown[1]="changed"
 check(owned.payload.unknown[1]=="keep" and table.isfrozen(owned.payload.unknown),"source snapshot shared backend's mutable value")
 drive(c,j);check(j.state=="changed" and j.plan==nil,"later raw mutation silently rebased observation")
end
do
 local b,c=fixture();local rawSources={}
 for _,slot in Archive.SLOTS do rawSources[slot]={loaded=true,value=b.data[if slot=="progress" then "P_12345" else "R_12345_"..slot]} end
 local full=assert(Archive.prepare("12345","intent/source observation",rawSources))
 c=Collector.new(b,"12345",nil,{total=full.characters-1});local j=start(c);drive(c,j)
 check(j.state=="refused" and j.plan==nil and b.writes==0,"aggregate bound was bypassed by isolated slot copies")
end
do
 local b=Memory.new()
 check(not pcall(function() Collector.new(b,"12345") end),"cached/decoded-only backend admitted")
 b.readRawFresh=function(self,key) return self:read(key) end
 for _,owner in {"","../other-owner",string.rep("x",33)} do check(not pcall(function() Collector.new(b,owner) end),"invalid owner admitted") end
 check(not pcall(function() Collector.new(b,"12345",nil,{unknown=5}) end),"unknown bounds admitted")
 check(b.requests==0 and b.writes==0,"constructor made service requests")
end
print("RECOVERY_SOURCE_COLLECTOR passed="..passed.." failed=0")
