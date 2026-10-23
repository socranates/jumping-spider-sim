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
  local before=b.requests;c:step(j);check(b.requests-before<=1,"idle cohort made more than one request per step");clock.now+=1
 end
 error("idle cohort did not settle")
end
local function fixture(refused,postRest)
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 b:poke("P_46001",Json.copy(rawProgress));b:poke("R_46001_main",Json.copy(rest));b:poke("R_46001_free",{untouched="other-slot"})
 local w=__progressBaselinePrototype.new(b,"46001");local clock={now=200}
 local s=SaveSession.new({backend=w,userId=46001,sessionId="idle-A",now=function() return clock.now end})
 assert(s:load()=="active");s:enableOffers()
 local reader=__offerReaderPrototype.new(s,codec,fresh,{work={now=function() return 0 end}})
 local read=assert(reader:begin("main"));advance(b,clock,s,reader,read);assert(read.state=="offered",read.problem)
 assert(s:requestLife("continue","main",1,read.offer.id))
 local c=__pipelinePrototype.new(s,codec,b,template,fresh,{work={now=function() return 0 end}})
 local recovery=assert(c:begin("main",1,read.offer.id,read))
 if postRest then advance(b,clock,s,c,recovery,function() return recovery.phase=="commit" and recovery.child.phase=="progress" end) end
 if refused then c.maxRequests=1;c:step(recovery);assert(recovery.state=="refused");c.maxRequests=96 else assert(c:cancel(recovery)) end
 return b,clock,s,w,c,recovery,read
end
local function start(c)
 local idle=__idlePrototype.new(c);local j=assert(idle:begin());return idle,j
end
local function tick(b,clock,s,idle,j)
 local before=b.requests;idle:step(j)
 check(b.requests-before<=1,"idle step made more than one request")
 check(#s.sched.started<=Rules.REQUESTS_PER_MINUTE,"idle exceeded shared rolling request quota")
 check(not s.busy and not idle.busy and not idle.owner.busy,"idle left a busy flag")
 check(not s.backend:permitted(j.job.held),"idle leaked a recovery permit")
 clock.now+=1
end
local function withoutLock(b)
 local copy=Json.copy(b.data);copy.P_46001.lock=nil;return Json.canonical(copy)
end
-- The old terminal owner does nothing: the lease expires during a menu wait.
do
 local b,clock,s,w,c,recovery=fixture(false,false);local beat=b.data.P_46001.lock.beat
 for _=1,Rules.LOCK_STALE+1 do c:step(recovery);clock.now+=1 end
 check(clock.now-beat>=Rules.LOCK_STALE,"unmaintained terminal lease did not expire as expected")
 local other=SaveSession.new({backend=b,userId=46001,sessionId="new-visit",now=function() return clock.now end})
 check(other:load()=="active" and b.data.P_46001.lock.session=="new-visit","expired terminal counterexample did not permit actual takeover")
end
for _,refused in {false,true} do
 for _,postRest in {false,true} do
  local b,clock,s,w,c,recovery=fixture(refused,postRest);local unchanged=withoutLock(b);local progress=Json.canonical(s.progress);local baseline=Json.canonical(w.held.base)
  local idle,j=start(c);local requests=b.requests;local began=clock.now
  for _=1,480 do tick(b,clock,s,idle,j);check(j.state=="pending","healthy terminal maintenance stopped: "..tostring(j.problem)) end
  check(b.requests-requests<=18 and b.requests-requests>=15,"idle maintenance was not approximately two renewals per minute")
  check(withoutLock(b)==unchanged and Json.canonical(s.progress)==progress and Json.canonical(w.held.base)==baseline,"idle heartbeat changed payload/backup/archive/rest/local choices")
  check(clock.now-b.data.P_46001.lock.beat<Rules.HEARTBEAT+1 and not c.leaseLost and s.recoveryOwner==c,"idle failed to retain its fresh lease")
  check(recovery.state==(if refused then "refused" else "cancelled") and s.intents.requests.main.credential==nil,"maintenance resumed a terminal transaction/granted gameplay")
  local before=b.requests;local invoked=false
  check(not w:update(s.pkey,function() invoked=true;return {} end) and not invoked and b.requests==before,"maintenance reopened ordinary progress writes")
  local other=SaveSession.new({backend=b,userId=46001,sessionId="blocked-visit",now=function() return clock.now end})
  check(other:load()=="session" and other.reason=="other_session" and b.data.P_46001.lock.session==s.id,"maintained lease was acquired by another actual session")
 end
end
-- A fresh selected retry stops the idle helper, reuses the held baseline and
-- continues through the actual pipeline, not a separate diagnostic shortcut.
do
 local b,clock,s,w,c,recovery,read=fixture(false,true);local idle,j=start(c)
 for _=1,75 do tick(b,clock,s,idle,j) end
 assert(s:requestLife("continue","main",2,read.offer.id))
 local resumed=assert(c:begin("main",2,read.offer.id,read))
 check(j.state=="stopped" and c.idleOwner==nil and not c.leaseLost,"explicit recovery retry did not stop idle maintenance")
 local before=b.requests;idle:step(j);check(b.requests==before,"superseded idle scope made a request")
 advance(b,clock,s,c,resumed)
 check(resumed.state=="rebound" and w.held==nil and s.recoveryOwner==nil,"maintained retry failed to complete: "..tostring(resumed.problem))
end
-- Unsaved local choices stay in memory while held, then departure's three-way
-- writer persists them without replaying unrelated stale choices.
do
 local b,clock,s,w,c=fixture(false,true)
 local q=Progress.default();q.notebook.opened={"idle_remote"};q.settings={SoundMuted=true,MasterVolume=.9}
 b:poke(s.pkey,Envelope.make(Progress.SPEC,q,clock.now,nil,{lock={session=s.id,beat=clock.now}}))
 local idle,j=start(c);for _=1,80 do tick(b,clock,s,idle,j) end
 local localProgress=Json.copy(s.progress);table.insert(localProgress.notebook.opened,"idle_local");localProgress.settings.MasterVolume=.3;assert(s:setProgress(localProgress))
 local d=__departurePrototype.new(c);local departure=assert(d:begin());local before=b.requests
 idle:step(j);check(j.state=="stopped" and b.requests==before,"departure did not stop terminal maintenance before more I/O")
 advance(b,clock,s,d,departure)
 local stored=b.data.P_46001.payload
 check(departure.state=="preserved" and stored.settings.SoundMuted==true and stored.settings.MasterVolume==.3 and table.find(stored.notebook.opened,"idle_local") and table.find(stored.notebook.opened,"idle_remote"),"maintenance/departure lost local or remote progress")
 local wrapped=__progressBaselinePrototype.new(b,"46001")
 local freshSession=SaveSession.new({backend=wrapped,userId=46001,sessionId="after-idle-departure",now=function() return clock.now end})
 check(freshSession:load()=="active" and table.find(freshSession.progress.notebook.opened,"idle_local") and freshSession.progress.settings.SoundMuted==true,"new actual session did not load preserved global progress")
end
for _,fault in {"lost-ack","before-write","probe-failure","probe-throw","callback-replay"} do
 local b,clock,s,w,c=fixture(false,false);local idle,j=start(c)
 tick(b,clock,s,idle,j);check(j.phase=="renew","initial uncached probe failed")
 clock.now=math.max(clock.now,s.sched.lastBeat+Rules.HEARTBEAT)
 local untouched=withoutLock(b);local requests=j.requests
 if fault=="lost-ack" then b:fail({op="update",key=s.pkey,afterWrite=true,message="timeout"})
 elseif fault=="before-write" then b:fail({op="update",key=s.pkey,message="503 unavailable"})
 elseif fault=="callback-replay" then
  local update=b.update;b.update=function(self,key,fn) return update(self,key,function(old) fn(Json.copy(old));return fn(old) end) end
 else
  b:fail({op="update",key=s.pkey,afterWrite=true,message="timeout"})
  if fault=="probe-failure" then b:fail({op="read",key=s.pkey,message="503 unavailable"})
  else
   local read=b.readRawFresh;local first=true
   b.readRawFresh=function(self,key) if first then first=false;error("synthetic uncached failure") end;return read(self,key) end
  end
 end
 for _=1,100 do tick(b,clock,s,idle,j) end
 check(j.state=="pending" and j.requests-requests<12 and withoutLock(b)==untouched and clock.now-b.data.P_46001.lock.beat<Rules.HEARTBEAT+1,"idle fault recovery failed/changed payload: "..fault..": "..tostring(j.problem))
end
for _,bad in {"foreign","stale","future","corrupt","newer","missing","unknown"} do
 local b,clock,s,w,c,recovery,read=fixture(false,false);local idle,j=start(c);local raw=Json.copy(b.data.P_46001)
 if bad=="foreign" then raw.lock={session="foreign",beat=clock.now}
 elseif bad=="stale" then raw.lock.beat=clock.now-Rules.LOCK_STALE
 elseif bad=="future" then raw.lock.beat=clock.now+10
 elseif bad=="corrupt" then raw.checksum="broken"
 elseif bad=="newer" then raw.schema=999
 elseif bad=="missing" then raw=nil
 else raw.unsupported="untouched" end
 b:poke(s.pkey,raw);local before=Json.canonical(b.data);local writes=b.writes;tick(b,clock,s,idle,j)
 check(j.state=="lost" and c.leaseLost and j.result.requiresFreshSession and not j.result.gameplayAuthorized,"unsafe held lease was not fenced: "..bad)
 local requests=b.requests;local resumed,why=c:begin("main",1,read.offer.id,read)
 check(resumed==nil and why=="recovery lease lost; fresh session required" and b.requests==requests,"lost held scope admitted recovery again")
 check(b.writes==writes and Json.canonical(b.data)==before and w.held~=nil,"unsafe idle probe changed data/released barrier: "..bad)
end
-- A clock jump beyond expiry must not reacquire an expired own lease.
do
 local b,clock,s,w,c=fixture(false,false);local idle,j=start(c);tick(b,clock,s,idle,j)
 clock.now=j.expiresAt;local before=b.requests;idle:step(j)
 check(j.state=="lost" and b.requests==before and c.leaseLost,"expired idle observation made a request")
end
-- Exhausted shared quota: wait, never bypass it, and fail closed at expiry.
do
 local b,clock,s,w,c=fixture(false,false);local idle,j=start(c)
 s.sched.started={};for _=1,Rules.REQUESTS_PER_MINUTE do table.insert(s.sched.started,clock.now) end
 local before=b.requests;for _=1,59 do tick(b,clock,s,idle,j) end
 check(j.requests==0 and b.requests==before,"idle bypassed rolling gameplay allowance")
 for _=1,10 do tick(b,clock,s,idle,j) end
 check(j.requests>=1 and j.state=="pending","idle never resumed when shared quota freed")
end
-- Native-style provider yields isolate the permit and serialize a user retry.
do
 local b,clock,s,w,c,recovery,read=fixture(false,false);local idle,j=start(c);tick(b,clock,s,idle,j)
 clock.now=s.sched.lastBeat+Rules.HEARTBEAT
 local update=b.update;b.update=function(self,key,fn) coroutine.yield("idle-provider-paused");return update(self,key,fn) end
 local co=coroutine.create(function() return idle:step(j) end)
 local ok,marker=coroutine.resume(co);assert(ok,marker)
 check(marker=="idle-provider-paused" and s.busy and c.busy and idle.busy and w.activeUpdates==1,"idle provider did not suspend")
 local before=b.requests;check(c:begin("main",1,read.offer.id,read)==nil and b.requests==before and not w:permitted(recovery.held),"yielding idle leaked admission/permit")
 local d=__departurePrototype.new(c);local departure=assert(d:begin());d:step(departure)
 check(departure.phase=="drain" and b.requests==before,"departure raced an idle renewal")
 assert(coroutine.resume(co));b.update=update
 check(j.state=="stopped" and not s.busy and not c.busy and not idle.busy and w.activeUpdates==0,"closed idle provider did not drain")
 advance(b,clock,s,d,departure);check(departure.state=="preserved","departure failed after idle provider drain")
end
for _,change in {"provider","load","id","backend","scheduler","clock"} do
 local b,clock,s,w,c=fixture(false,false);local idle,j=start(c);local before=b.requests
 if change=="provider" then w.source=Memory.new()
 elseif change=="load" then s._loadSerial+=1
 elseif change=="id" then s.id="replaced"
 elseif change=="backend" then s.backend=__progressBaselinePrototype.new(b,"46001")
 elseif change=="scheduler" then s.sched={}
 else clock.now-=1 end
 idle:step(j);check(j.state=="lost" and b.requests==before and c.leaseLost,"changed held identity made a request: "..change)
end
do
 local b,clock,s,w,c=fixture(false,false);local idle,j=start(c)
 local duplicate=__idlePrototype.new(c);check(duplicate:begin()==nil,"duplicate idle owner admitted")
 local before=b.requests;local work=Work.new(function() return idle:step(j) end,{now=function() return 0 end})
 while work.state=="pending" do work:step() end
 check(work:take()~=nil and b.requests==before,"preparation context issued idle I/O")
 check(idle:cancel() and j.state=="stopped" and c.idleOwner==nil and not c.leaseLost,"explicit idle cancellation lost the lease claim")
end
-- A slow provider can run a still-valid callback later, then return after the
-- previous beat's expiry. A verified newer beat, not the old beat, owns that
-- acknowledgement window. This must not falsely fence a healthy owner.
do
 local b,clock,s,w,c=fixture(false,false);local idle,j=start(c);tick(b,clock,s,idle,j)
 clock.now=s.sched.lastBeat+Rules.HEARTBEAT
 local update=b.update
 b.update=function(self,key,fn)
  clock.now+=60
  local result=table.pack(update(self,key,fn))
  clock.now+=35
  return table.unpack(result,1,result.n)
 end
 idle:step(j);b.update=update
 check(j.state=="pending" and not c.leaseLost and s.sched.lastBeat==b.data.P_46001.lock.beat and clock.now-s.sched.lastBeat==35,"slow acknowledged renewal falsely expired the owner")
end
print("RECOVERY_IDLE passed="..count.." failed=0")
end
