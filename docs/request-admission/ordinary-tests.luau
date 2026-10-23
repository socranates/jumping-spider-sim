local Gate=__ordinaryGate
local Session=require("../src/Shared/Persistence/SaveSession")
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Progress=require("../src/Shared/Persistence/SaveProgress")
local Envelope=require("../src/Shared/Persistence/SaveEnvelope")
local Rules=require("../src/Shared/Data/SaveRules")
local Json=require("../src/Shared/Persistence/Json")
local checks,groups=0,0
local function check(ok,why) assert(ok,why);checks+=1 end
local function test(name,fn) local before=checks;fn();groups+=1;print("ORDINARY_CASE",name,checks-before) end
local function fixture(configure)
 local f={clock={now=100},budget={read=1000,write=1000},b=Memory.new(),stored=0,decisions={}}
 local b=f.b;b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 local cfg={backend=b,userId=47002,sessionId="ordinary-actor",now=function() return f.clock.now end,sleep=function(dt) f.clock.now+=dt;if f.onSleep then f.onSleep() end end,
  onStored=function() f.stored+=1 end,onDecision=function(r) table.insert(f.decisions,r) end}
 f.g=Gate.new({now=cfg.now,available=function() return f.budget end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 f.scope=assert(f.g:open("47002",cfg.sessionId));assert(f.g:importLegacy(f.scope,{}));cfg.admission={gate=f.g,scope=f.scope}
 if configure then configure(f,cfg) end
 f.s=Session.new(cfg);return f
end
local function step(f,advance)
 local before=f.b.requests;local asked=f.s:step()
 check(f.b.requests-before<=1,"ordinary step started more than one provider")
 check(f.s.counters.requests==f.b.requests,"ordinary/global/provider starts differ")
 if advance~=false then f.clock.now+=1 end
 return asked
end
local function settle(f,done)
 for _=1,1000 do if done() then return end;step(f) end;error("ordinary did not settle")
end
local function choose(f,v)
 local p=Json.copy(f.s.progress);p.settings.MasterVolume=v;assert(f.s:setProgress(p))
end
local function finish(f)
 f.s:flush(f.clock.now+24);f.g:close(f.scope)
 local q=f.g:inspect();check(q.queued==0 and q.started==0,"ordinary cleanup retained provider/admission")
end

test("synchronous-load-waits-without-fake-attempts",function()
 local f=fixture();f.budget.read=0;f.budget.write=0;local sleeps=0
 f.onSleep=function()
  sleeps+=1;check(f.b.requests==0 and f.s.counters.requests==0 and f.s.state=="loading","capacity denial became a provider failure/default load")
  if sleeps==8 then f.budget.read=1000;f.budget.write=1000 end
 end
 local state,applied=f.s:load();f.onSleep=nil
 check(state=="active" and applied and sleeps==8 and f.b.requests==4 and f.s.counters.requests==4,"typed initial load did not complete exact four requests")
 check(f.b.data.P_47002.lock.beat>=100.2-1e-6 and f.s.sched.lastBeat==f.b.data.P_47002.lock.beat,"load used pre-admission clock for ownership")
 finish(f)
end)

test("polled-write-retains-newer-choice-and-logical-version",function()
 local f=fixture();assert(f.s:load()=="active");choose(f,.4)
 f.budget.write=0;local before=f.b.requests;local version=f.s.sched.items.progress.version
 for _=1,12 do check(not step(f,false),"queued progress started provider") end
 check(f.b.requests==before and f.s.sched:isDirty("progress") and f.s.sched.items.progress.failures==0 and not f.s.busy,"progress wait lost dirty/version/backoff or retained busy scope")
 choose(f,.8);f.budget.write=1000;step(f,false)
 check(f.s.sched.items.progress.sentVersion==version and f.s.sched:isDirty("progress"),"write marked a newer logical version durable")
 settle(f,function() return not f.s.sched:isDirty("progress") end)
 check(f.b.data.P_47002.payload.settings.MasterVolume==.8,"queued write lost current player choice")
 finish(f)
end)

test("native-yield-is-not-resumed-by-polling",function()
 local paused=false;local resumes=0
 local f=fixture(function(x)
  local provider=x.b.update
  x.b.update=function(self,key,fn)
   if paused then paused=false;coroutine.yield("native-ordinary");resumes+=1 end
   return provider(self,key,fn)
  end
 end)
 assert(f.s:load()=="active");choose(f,.6);paused=true
 f.s:step();local c=f.s._ordinaryContext
 check(c and c.phase=="provider" and f.s.busy and f.g:inspect().started==1,"provider did not suspend in distinct native phase")
 for _=1,10 do check(not f.s:step() and resumes==0,"polling manually resumed native provider") end
 choose(f,.9);assert(coroutine.resume(c.thread))
 check(c.phase=="done" and not f.s.busy and resumes==1,"native provider failed to finish externally")
 settle(f,function() return not f.s.sched:isDirty("progress") end)
 check(f.b.data.P_47002.payload.settings.MasterVolume==.9,"native write lost newer choice")
 finish(f)
end)

test("ordinary-preview-and-intent-validation-wait-without-grant",function()
 local f=fixture();assert(f.s:load()=="active");f.s:enableOffers();f.budget.read=0
 local before=f.b.requests;for _=1,8 do step(f,false) end
 check(f.b.requests==before and f.s:offer("main")==nil and f.s.previewFailures.main==nil,"queued preview invented empty rest/provider failure")
 f.budget.read=1000;settle(f,function() return next(f.s.previewPending)==nil end)
 assert(f.s:requestLife("new","main",1,nil));local r=f.s.intents.requests.main;f.budget.read=0
 for _=1,8 do step(f,false) end
 check(r.credential==nil and r.needsCheck and (r.failures or 0)==0,"queued intent read granted or failed")
 f.budget.read=1000;settle(f,function() return r.state=="writable" end)
 check(r.credential~=nil and r.life~=nil,"actual normal New did not receive durable marker credential")
 finish(f)
end)

test("flush-cancels-admission-and-closes-with-exact-progress",function()
 local f=fixture();assert(f.s:load()=="active");choose(f,.7);f.budget.write=0
 step(f,false);check(f.s._ordinaryContext.phase=="admission","flush fixture did not wait on admission")
 f.onSleep=function() f.budget.write=1000 end
 f.s:flush(f.clock.now+24);f.onSleep=nil
 check(f.s.closed and not f.s.flushing and not f.s.busy and not f.s.lockHeld and f.b.data.P_47002.lock==nil and f.b.data.P_47002.payload.settings.MasterVolume==.7,"flush lost current choice or did not release")
 f.g:close(f.scope);local q=f.g:inspect();check(q.queued==0 and q.started==0,"flush retained queued request")
end)

test("expired-acquisition-ack-and-slow-rest-load-do-not-grant-active",function()
 for _,where in {"after-update","rest"} do
  local f=fixture(function(x)
   if where=="after-update" then
    local update=x.b.update;x.b.update=function(self,key,fn) local out=table.pack(update(self,key,fn));x.clock.now+=121;return table.unpack(out,1,out.n) end
   else
    local read=x.b.readFresh;local once=true;x.b.readFresh=function(self,key) local out=table.pack(read(self,key));if once then once=false;x.clock.now+=121 end;return table.unpack(out,1,out.n) end
   end
  end)
  local state=f.s:load()
  check(state~="active" and not f.s.lockHeld,"expired stored ownership was treated as current")
  f.g:close(f.scope);local q=f.g:inspect();check(q.queued==0 and q.started==0,"expired loader retained operation")
 end
end)

test("retry-load-after-ambiguous-acquisition-uses-existing-step-context",function()
 for _,after in {false,true} do
  local f=fixture();f.b:fail({op="update",key="P_47002",afterWrite=after,message="timeout"})
  check(f.s:load()=="session" and f.s.canRetry,"failed acquisition was not retryable")
  settle(f,function() return f.s.state=="active" and f.s:restsLoaded() end)
  check(f.s.lockHeld and f.b.data.P_47002.lock.session==f.s.id and f.s.sched.lastBeat==f.b.data.P_47002.lock.beat,"ordinary step retry failed to reacquire/read")
  finish(f)
 end
end)

test("credentialed-rest-wait-keeps-receipt-and-fences-expired-ownership",function()
 for _,expire in {false,true} do
  local f=fixture();assert(f.s:load()=="active");f.s:enableOffers()
  settle(f,function() return next(f.s.previewPending)==nil end)
  assert(f.s:requestLife("new","main",1,nil));local r=f.s.intents.requests.main
  settle(f,function() return r.state=="writable" end)
  local record=Json.copy(template);record.save_life=r.life
  check(f.s:setRestForIntent("main",record,r.life,r.serial,r.credential,1),"normal credentialed checkpoint refused")
  f.budget.write=0
  settle(f,function() return f.s._ordinaryContext and f.s._ordinaryContext.io and f.s._ordinaryContext.io.key==f.s.rkey.main end)
  local raw=Json.canonical(f.b.data.R_47002_main);local count=f.b.requests
  for _=1,8 do step(f,false) end
  check(f.stored==0 and f.b.requests==count,"queued ordinary rest acknowledged or retried")
  if expire then
   f.clock.now+=Rules.LOCK_STALE+1
   local foreign=Envelope.withLock(f.b.data.P_47002,{session="foreign",beat=f.clock.now});f.b:poke("P_47002",foreign)
   f.budget.write=1000;step(f,false)
   check(f.s.state=="session" and r.credential==nil and f.stored==0 and f.b.requests==count and Json.canonical(f.b.data.R_47002_main)==raw,"expired queued rest reached provider/granted saved receipt")
   check(Json.canonical(f.b.data.P_47002)==Json.canonical(foreign),"expired rest modified foreign progress")
   f.g:close(f.scope)
  else
   f.budget.write=1000;settle(f,function() return f.stored==1 end)
   check(r.storedSerial==1 and r.storedCredential==r.credential and f.s.restPending.main==nil,"normal exact stored receipt/cache missing")
   finish(f)
  end
 end
end)

test("closed-load-during-capacity-wait-never-invents-a-record",function()
 local f=fixture();f.budget.write=0
 f.onSleep=function() f.s.closed=true end
 local _,applied=f.s:load()
 check(not applied and f.s.closed and f.s.counters.requests==0 and f.b.requests==0 and next(f.b.data)==nil,"closed waiting constructor acquired/wrote defaults")
 f.g:close(f.scope);local q=f.g:inspect();check(q.queued==0 and q.started==0,"closed waiting constructor retained queued work")
end)

test("late-native-load-result-is-discarded-after-close",function()
 local f=fixture(function(x)
  local provider=x.b.update
  x.b.update=function(self,key,fn) local out=table.pack(provider(self,key,fn));coroutine.yield("load-committed");return table.unpack(out,1,out.n) end
 end)
 local closed=false
 f.onSleep=function()
  if not closed then closed=true;f.s.closed=true;local c=f.s._ordinaryContext;check(c.phase=="provider","load was not suspended at provider");assert(coroutine.resume(c.thread)) end
 end
 local state,applied=f.s:load()
 check(state=="loading" and not applied and not f.s.lockHeld and f.s.counters.requests==1 and f.b.requests==1,"late constructor adopted/granted or issued rest reads")
 f.g:close(f.scope);local q=f.g:inspect();check(q.queued==0 and q.started==0,"closed native constructor failed to drain")
end)

test("shared-gate-allows-another-actors-read-while-write-is-blocked",function()
 local clock={now=100};local budget={read=1000,write=1000};local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read
 local g=Gate.new({now=function() return clock.now end,available=function() return budget end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 local sessions,scopes={},{}
 for _,uid in {47003,47004} do
  local id="ordinary-shared-"..uid;local scope=assert(g:open(tostring(uid),id));assert(g:importLegacy(scope,{}));table.insert(scopes,scope)
  local s=Session.new({backend=b,userId=uid,sessionId=id,now=function() return clock.now end,sleep=function(dt) clock.now+=dt end,admission={gate=g,scope=scope}})
  assert(s:load()=="active");table.insert(sessions,s)
 end
 local a,z=sessions[1],sessions[2];local p=Json.copy(a.progress);p.settings.MasterVolume=.4;assert(a:setProgress(p))
 budget.write=0;check(not a:step() and a._ordinaryContext.phase=="admission" and not a.busy,"first actor did not yield capacity")
 local n=b.requests;z:enableOffers();check(z:step() and b.requests==n+1 and z.previewPending.main==nil,"one blocked writer prevented another actor's read")
 check(a.counters.requests==4 and z.counters.requests==5 and g:inspect().queued==1,"shared account/resource accounting differs")
 budget.write=1000;check(a:step() and b.data.P_47003.payload.settings.MasterVolume==.4,"blocked actor failed to resume through shared gate")
 for _,s in sessions do s:flush() end
 for _,scope in scopes do g:close(scope) end
 local q=g:inspect();check(q.queued==0 and q.started==0,"shared actors did not clean up")
end)

test("reentrant-close-after-load-notification-does-not-deadlock",function()
 local once=true
 local f=fixture(function(x,cfg)
  cfg.onChange=function()
   if once then once=false;x.s:flush(x.clock.now+24) end
  end
 end)
 local _,applied=f.s:load()
 check(f.s.closed and not applied and not f.s.lockHeld and f.b.data.P_47002.lock==nil and not f.s.busy,"reentrant load close deadlocked or reported usable constructor")
 f.g:close(f.scope);local q=f.g:inspect();check(q.queued==0 and q.started==0,"reentrant close retained operation")
end)

test("flush-drains-native-write-before-preserving-newer-choice",function()
 local f=fixture(function(x)
  local provider=x.b.update;x.b.update=function(self,key,fn)
   local out=table.pack(provider(self,key,fn));if x.pause then x.pause=false;coroutine.yield("progress-written") end;return table.unpack(out,1,out.n)
  end
 end)
 assert(f.s:load()=="active");choose(f,.7);f.pause=true;f.s:step();local c=f.s._ordinaryContext
 check(c.phase=="provider" and f.s.busy and f.b.data.P_47002.payload.settings.MasterVolume==.7,"flush fixture did not suspend after progress commit")
 choose(f,.3);local resumed=false
 f.onSleep=function() if not resumed then resumed=true;check(f.s.flushing,"flush did not close its route before drain");assert(coroutine.resume(c.thread)) end end
 f.s:flush();f.onSleep=nil
 check(resumed and f.s.closed and not f.s.busy and not f.s.flushing and f.b.data.P_47002.lock==nil and f.b.data.P_47002.payload.settings.MasterVolume==.3,"native drain/flush lost later authored choice or release")
 f.g:close(f.scope);local q=f.g:inspect();check(q.queued==0 and q.started==0,"native drain/flush retained operation")
end)

test("quiet-polling-does-not-allocate-driver-stacks",function()
 local f=fixture();assert(f.s:load()=="active");local frames=f.s.ordinaryFramesStarted;local calls=f.b.requests
 for _=1,120 do check(not f.s:step(),"quiet step made a provider request") end
 check(f.s.ordinaryFramesStarted==frames and f.b.requests==calls and not f.s.busy,"quiet polling created request fibers or changed provider count")
 finish(f)
end)

test("post-attachment-startup-wrapper-is-refused-before-provider",function()
 local f=fixture();local original=f.s.sched.begin
 f.s.sched.begin=function(...) return original(...) end
 local state,applied=f.s:load()
 check(state=="loading" and not applied and f.b.requests==0 and f.s.counters.requests==0,"ordinary path allowed a competing startup wrapper")
 f.g:close(f.scope);local q=f.g:inspect();check(q.queued==0 and q.started==0,"refused wrapper retained admission")
end)

test("coarse-clock-wait-can-span-several-timer-quanta",function()
 local f=fixture(function(x,cfg)
  cfg.now=function() return math.floor(x.clock.now) end
  x.g.now=cfg.now
 end)
 f.budget.read=0;f.budget.write=0;local sleeps=0
 f.onSleep=function()
  sleeps+=1;check(f.s.counters.requests==0 and f.b.requests==0,"coarse-clock wait started a request without allowance")
  if sleeps==8 then f.budget.read=1000;f.budget.write=1000 end
 end
 local state,applied=f.s:load();f.onSleep=nil
 check(state=="active" and applied and sleeps==8,"coarse clock wait did not finish initial load")
 check(f.s.sched.lastBeat==100 and f.b.requests==4 and f.s.counters.requests==4,"coarse clock changed request/lock timing")
 finish(f)
end)

print("ORDINARY_SESSION passed="..checks.." failed=0 groups="..groups)
