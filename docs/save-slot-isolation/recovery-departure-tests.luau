do
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local SaveSession=require("../src/Shared/Persistence/SaveSession")
local Progress=require("../src/Shared/Persistence/SaveProgress")
local Rules=require("../src/Shared/Data/SaveRules")
local Work=require("../src/Shared/Persistence/SaveWork")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function advance(b,clock,s,c,j,untilReady)
 for _=1,1000 do
  if untilReady and untilReady() or not untilReady and j.state~="pending" then return end
  local before=b.requests;c:step(j)
  check(b.requests-before<=1,"departure cohort made more than one request per step")
  clock.now+=1
 end
 error("departure cohort did not settle")
end
local function fixture(compressed,postRest)
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 b:poke("P_46001",Json.copy(rawProgress));b:poke("R_46001_main",if compressed then codec:encode(rest) else Json.copy(rest))
 b:poke("R_46001_free",{untouched="other-slot"})
 local w=__progressBaselinePrototype.new(b,"46001");local clock={now=200}
 local s=SaveSession.new({backend=w,userId=46001,sessionId="departure-A",now=function() return clock.now end})
 assert(s:load()=="active");s:enableOffers()
 local reader=__offerReaderPrototype.new(s,codec,fresh,{work={now=function() return 0 end}})
 local read=assert(reader:begin("main"));advance(b,clock,s,reader,read);assert(read.state=="offered",read.problem)
 assert(s:requestLife("continue","main",1,read.offer.id))
 local c=__pipelinePrototype.new(s,codec,b,template,fresh,{work={now=function() return 0 end}})
 local recovery=assert(c:begin("main",1,read.offer.id,read))
 if postRest then advance(b,clock,s,c,recovery,function() return recovery.phase=="commit" and recovery.child.phase=="progress" end) end
 local localProgress=Json.copy(s.progress);table.insert(localProgress.notebook.opened,"depart_local");localProgress.settings.MasterVolume=.4
 assert(s:setProgress(localProgress))
 return b,clock,s,w,c,recovery
end
local function nonProgress(b)
 local copy={};for k,v in b.data do if k~="P_46001" then copy[k]=v end end
 return Json.canonical(copy)
end
local function remoteChoice(b,clock)
 local q=Progress.default();q.notebook.opened={"depart_remote"};q.settings={SoundMuted=true,MasterVolume=.9}
 b:poke("P_46001",Envelope.make(Progress.SPEC,q,clock.now,nil,{lock={session="departure-A",beat=clock.now}}))
end
local function depart(b,clock,s,c,options)
 local d=__departurePrototype.new(c,options);local j=assert(d:begin())
 check(s.closed and s.flushing and not s:setProgress(Progress.default()),"departure did not close intake immediately")
 local before=b.requests;s:flush();s:load();s:step()
 check(b.requests==before and not s:requestLife("new","free",2,nil),"ordinary flush/load/worker/intake bypassed closed recovery")
 advance(b,clock,s,d,j)
 check(not s.flushing and not s.busy and not d.busy,"departure retained a running flag")
 check(j.requests<=d.maxRequests,"departure exceeded its cap")
 return d,j
end
-- Retained counterexample: generic flush cannot write through the enforced
-- hold, closes the session, and loses the opportunity to persist its local page.
do
 local b,clock,s,w,c=fixture(false,false);local old=Json.canonical(b.data.P_46001)
 s:flush()
 check(s.closed and Json.canonical(b.data.P_46001)==old and table.find(b.data.P_46001.payload.notebook.opened,"depart_local")==nil,"generic-flush counterexample no longer reproduced")
 check(w.held~=nil,"generic flush unexpectedly released held baseline")
end
for _,compressed in {false,true} do
 for _,postRest in {false,true} do
  local b,clock,s,w,c,recovery=fixture(compressed,postRest);remoteChoice(b,clock)
  local naive=Progress.merge(b.data.P_46001.payload,s.progress,clock.now,s.progressTime)
  check(naive.settings.SoundMuted==false,"stale-choice departure counterexample missing")
  local untouched=nonProgress(b);local start=b.requests;local d,j=depart(b,clock,s,c)
  local q=b.data.P_46001.payload
  check(j.state=="preserved" and j.result.progressPreserved and j.result.leaseReleased and not j.result.gameplayAuthorized,"departure did not verify atomic preserve/release: "..tostring(j.problem))
  check(b.requests-start==2 and j.requests==2 and b.data.P_46001.lock==nil and not s.lockHeld,"normal departure was not exactly one write plus uncached read")
  check(q.settings.SoundMuted==true and q.settings.MasterVolume==.4 and table.find(q.notebook.opened,"depart_local") and table.find(q.notebook.opened,"depart_remote"),"departure lost local progress or replayed stale remote choices")
  check(nonProgress(b)==untouched and recovery.state=="cancelled" and w.held~=nil and s.intents.requests.main.credential==nil,"departure changed rest/archive/proposal or enabled recovery")
  local before=b.requests;check(not c:step(recovery) and d:begin()==nil and not w:update(s.pkey,function() error("must not call") end) and b.requests==before,"closed departure reopened recovery or ordinary writes")
 end
end
for _,fault in {"lost-ack","before-write","read-failure","read-throw"} do
 local b,clock,s,w,c=fixture(true,true);remoteChoice(b,clock);local untouched=nonProgress(b);local before=b.writes
 if fault=="lost-ack" then b:fail({op="update",key=s.pkey,afterWrite=true,message="timeout"})
 elseif fault=="before-write" then b:fail({op="update",key=s.pkey,message="503 unavailable"})
 elseif fault=="read-failure" then b:fail({op="read",key=s.pkey,message="503 unavailable"})
 else
  local read=b.readRawFresh;local first=true
  b.readRawFresh=function(self,key) if first then first=false;error("synthetic read exception") end;return read(self,key) end
 end
 local d,j=depart(b,clock,s,c)
 check(j.state=="preserved" and b.writes-before==1 and j.requests==(if fault=="before-write" then 4 elseif fault=="lost-ack" then 2 else 3),"departure retry/readback mishandled "..fault..": "..tostring(j.problem))
 check(nonProgress(b)==untouched and b.data.P_46001.lock==nil,"departure retry altered other keys/failed release")
end
-- Callback replay must recompute from the final storage value and reset its
-- candidate; it must not retain the first discarded callback's proposed value.
do
 local b,clock,s,w,c=fixture(false,true);remoteChoice(b,clock);local update=b.update;local callbacks=0
 b.update=function(self,key,fn)
  return update(self,key,function(old)
   callbacks+=1;fn(Json.copy(old))
   local q=Json.copy(old.payload);table.insert(q.notebook.opened,"callback_page");q.settings.SoundMuted=true
   local changed=Envelope.make(Progress.SPEC,q,old.updatedAt,nil,{lock=Json.copy(old.lock)})
   return fn(changed)
  end)
 end
 local _,j=depart(b,clock,s,c)
 check(j.state=="preserved" and callbacks==1 and table.find(b.data.P_46001.payload.notebook.opened,"callback_page"),"replayed callback lost latest storage changes")
end
for _,bad in {"foreign","stale","future-beat","corrupt","newer","missing","unknown"} do
 local b,clock,s,w,c=fixture(false,false);local raw=Json.copy(b.data.P_46001)
 if bad=="foreign" then raw.lock={session="new-owner",beat=clock.now}
 elseif bad=="stale" then raw.lock.beat=clock.now-Rules.LOCK_STALE
 elseif bad=="future-beat" then raw.lock.beat=clock.now+100
 elseif bad=="corrupt" then raw.checksum="not-the-checksum"
 elseif bad=="newer" then raw.schema=Progress.SCHEMA+1
 elseif bad=="missing" then raw=nil
 else raw.unrecognized="preserve me" end
 b:poke(s.pkey,raw);local stored=Json.canonical(raw);local writes=b.writes;local untouched=nonProgress(b)
 local _,j=depart(b,clock,s,c)
 check(j.state=="refused" and not j.result.progressPreserved and not j.result.leaseReleased,"unsafe departure record accepted: "..bad)
 check(b.writes==writes and Json.canonical(b.data.P_46001)==stored and nonProgress(b)==untouched and w.held~=nil,"refused departure changed bytes: "..bad)
end
-- An accepted recovery write suspended in a real nested owner is drained, not
-- raced by a departure write; closing the session invalidates its callback.
do
 local b,clock,s,w,c,recovery=fixture(false,true)
 advance(b,clock,s,c,recovery,function() return recovery.child.child.phase=="write" end)
 local update=b.update;local paused=true
 b.update=function(self,key,fn) if paused then coroutine.yield("provider-paused") end;return update(self,key,fn) end
 local co=coroutine.create(function()
  for _=1,120 do
   c:step(recovery);clock.now+=1
   if recovery.state~="pending" then return recovery.state end
  end
  error("owner did not issue a provider write within the probe bound")
 end)
 local resumed,marker=coroutine.resume(co);assert(resumed,marker)
 check(marker=="provider-paused" and s.busy and c.busy and w.activeUpdates==1,"nested provider was not suspended")
 local d=__departurePrototype.new(c);local j=assert(d:begin());local requests=b.requests
 d:step(j);check(j.phase=="drain" and b.requests==requests,"departure raced suspended recovery provider")
 paused=false;assert(coroutine.resume(co));b.update=update
 check(w.activeUpdates==0 and not s.busy and not c.busy and recovery.state=="cancelled","closed recovery provider did not drain/cancel")
 local untouched=nonProgress(b);advance(b,clock,s,d,j)
 check(j.state=="preserved" and nonProgress(b)==untouched and table.find(b.data.P_46001.payload.notebook.opened,"depart_local"),"drained departure failed")
end
for _,change in {"provider","load","session-id","backend","owner","deadline","clock-backwards"} do
 local b,clock,s,w,c=fixture(false,false);local d=__departurePrototype.new(c);local j=assert(d:begin());local requests=b.requests
 if change=="provider" then w.source=Memory.new()
 elseif change=="load" then s._loadSerial+=1
 elseif change=="session-id" then s.id="different"
 elseif change=="backend" then s.backend=__progressBaselinePrototype.new(b,"46001")
 elseif change=="owner" then s.recoveryOwner={}
 elseif change=="deadline" then clock.now=j.deadline else clock.now-=1 end
 d:step(j)
 check(j.state=="refused" and b.requests==requests and not j.result.leaseReleased,"changed closed scope made a request: "..change)
end
-- When the deadline expires while a provider is suspended, a callback which
-- has not committed must refuse; no late acknowledgement can report success.
do
 local b,clock,s,w,c=fixture(false,false);local d=__departurePrototype.new(c);local j=assert(d:begin());d:step(j)
 local update=b.update;b.update=function(self,key,fn) coroutine.yield();return update(self,key,fn) end
 local old=Json.canonical(b.data.P_46001);local co=coroutine.create(function() return d:step(j) end)
 assert(coroutine.resume(co));check(w.activeUpdates==1,"departure provider did not suspend")
 clock.now=j.deadline;assert(coroutine.resume(co));b.update=update
 check(j.state=="refused" and w.activeUpdates==0 and Json.canonical(b.data.P_46001)==old and not s.busy and not d.busy,"expired in-flight departure committed or reported success")
end
for _,slot in Rules.MODES do
 for _,kind in {"rest","life"} do
  local b,clock,s,w,c=fixture(false,false)
  if kind=="rest" then s.restPending[slot]={pending=true} else s.lifeRequests[slot]={done=false} end
  local before=b.requests;local d=__departurePrototype.new(c)
  check(d:begin()==nil and not s.closed and b.requests==before,"departure silently dropped queued "..slot.." "..kind)
 end
end
for _,cap in {1,2} do
 local b,clock,s,w,c=fixture(false,false);b:fail({op="update",key=s.pkey,times=5,message="503 unavailable"})
 local _,j=depart(b,clock,s,c,{maxRequests=cap})
 check(j.state=="refused" and j.requests==cap and not j.result.progressPreserved,"departure cap treated an unverified write as saved")
end
do
 local b,clock,s,w,c=fixture(false,false);local d=__departurePrototype.new(c)
 local job=Work.new(function() return d:begin() end,{now=function() return 0 end})
 while job.state=="pending" do job:step() end
 local result=job:take();check(result and result[1]==nil and not s.closed,"preparation yielded into departure I/O authority")
end
-- Terminal-held recovery can depart without reopening its ordinary worker.
for _,terminal in {"cancelled","refused"} do
 local b,clock,s,w,c,recovery=fixture(true,true)
 if terminal=="cancelled" then assert(c:cancel(recovery))
 else c.maxRequests=1;c:step(recovery);assert(recovery.state=="refused") end
 local before=nonProgress(b);local _,j=depart(b,clock,s,c)
 check(j.state=="preserved" and recovery.state==terminal and nonProgress(b)==before,"terminal-held departure failed: "..terminal)
end
-- Legal recovered progress may exceed the older 16K client-message budget.
-- Preserve it whole using the packet's 32K bound; never trim pages/history.
do
 local b,clock,s,w,c=fixture(false,false);local q=Json.copy(s.progress)
 while #q.notebook.opened<200 do table.insert(q.notebook.opened,string.rep("p",44)..string.format("%04d",#q.notebook.opened)) end
 q.rare={serial=1,claimed={},once={}}
 for i=1,64 do q.rare.claimed[string.rep("c",61)..string.format("%03d",i)]=1;q.rare.once[string.rep("o",61)..string.format("%03d",i)]=true end
 q.settings.SoundMuted=true;q.settings.MasterVolume=.9
 b:poke(s.pkey,Envelope.make(Progress.SPEC,q,clock.now,nil,{lock={session=s.id,beat=clock.now}}))
 check(#assert(Json.canonical(q))>16384,"wide departure fixture is too small")
 local _,j=depart(b,clock,s,c)
 check(j.state=="preserved" and #b.data.P_46001.payload.notebook.opened==200 and b.data.P_46001.payload.rare.once[string.rep("o",61).."064"],"wide recovered progress was refused/trimmed")
end
do
 local b,clock,s,w,c=fixture(false,false);local q=Progress.default()
 for i=1,200 do table.insert(q.notebook.opened,"remote_"..i) end
 b:poke(s.pkey,Envelope.make(Progress.SPEC,q,clock.now,nil,{lock={session=s.id,beat=clock.now}}))
 local old=Json.canonical(b.data.P_46001);local _,j=depart(b,clock,s,c)
 check(j.state=="refused" and Json.canonical(b.data.P_46001)==old,"over-capacity departure silently trimmed precious history")
end
do
 local b,clock,s,w,c=fixture(false,false)
 local raw=Envelope.make(Progress.SPEC,s.progress,clock.now,b.data.P_46001,{lock={session=s.id,beat=clock.now}})
 b:poke(s.pkey,raw);local expected=Envelope.withLock(raw,nil);local _,j=depart(b,clock,s,c)
 check(j.state=="preserved" and Json.canonical(b.data.P_46001)==Json.canonical(expected),"already-covered progress rotated backup/checksum/time unnecessarily")
end
do
 local b,clock,s,w,c=fixture(false,false);local read=b.readRawFresh
 b.readRawFresh=function(self,key)
  local current=Json.copy(self.data[key]);current.lock={session="new-arrival",beat=clock.now};self:poke(key,current)
  return read(self,key)
 end
 local writes=b.writes;local _,j=depart(b,clock,s,c)
 check(j.state=="refused" and not j.result.progressPreserved and b.writes-writes==1 and b.data.P_46001.lock.session=="new-arrival","ambiguous release readback overwrote a new arrival or falsely verified")
end
print("RECOVERY_DEPARTURE passed="..count.." failed=0")
end
