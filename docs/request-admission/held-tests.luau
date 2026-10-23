local Gate=__heldGate
local groups=0
local function test(name,fn) local before=count;fn();groups+=1;print("HELD_ADMISSION_CASE",name,count-before) end
local function typed(refused,postRest,configure)
 local b,clock,s,w,c,recovery,read=fixture(refused,postRest)
 if configure then configure(b,clock,s,w,c) end
 local budget={read=1000,write=1000}
 local g=Gate.new({now=s.now,available=function() return budget end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 local scope=assert(g:open("46001",s.id));assert(g:importLegacy(scope,s.sched.started));local lane={gate=g,scope=scope}
 local idle=__idlePrototype.new(c,lane);local j=assert(idle:begin());c.options.admission=lane
 return {b=b,clock=clock,s=s,w=w,c=c,recovery=recovery,read=read,g=g,scope=scope,lane=lane,budget=budget,idle=idle,j=j,base={provider=b.requests,global=s.counters.requests}}
end
local function step(f,advance)
 local before=f.b.requests;local asked=f.idle:step(f.j)
 check(f.b.requests-before<=1,"held maintenance started multiple providers")
 check(f.j.requests==f.s.counters.requests-f.base.global and f.j.requests==f.b.requests-f.base.provider,"held/global/provider starts differ")
 check(not f.s.busy and not f.c.busy and not f.idle.busy and not f.w:permitted(f.recovery.held),"held worker retained busy state or leaked permit")
 if advance~=false then f.clock.now+=1 end
 return asked
end
local function finish(f)
 f.idle:cancel();f.g:close(f.scope);local q=f.g:inspect();check(q.queued==0 and q.reserved==0 and q.started==0,"held maintenance retained ticket/provider")
end

test("all-terminal-phases-maintain-only-the-owned-lock",function()
 for _,refused in {false,true} do for _,post in {false,true} do
  local f=typed(refused,post);local original=withoutLock(f.b);local localProgress=Json.canonical(f.s.progress);local baseline=Json.canonical(f.w.held.base)
  f.budget.read=0;f.budget.write=0;local before=f.b.requests
  for _=1,20 do check(not step(f,false),"zero capacity held worker started provider") end
  check(f.j.phase=="probe" and f.j.requests==0 and f.j.failures==0 and f.b.requests==before,"probe wait changed attempts/phase")
  f.budget.read=1000;f.budget.write=1000
  for _=1,480 do step(f);check(f.j.state=="pending","healthy terminal maintenance stopped: "..tostring(f.j.problem)) end
  check(f.j.requests>=15 and f.j.requests<=18 and f.clock.now-f.b.data.P_46001.lock.beat<31,"typed held lease cadence differs")
  check(withoutLock(f.b)==original and Json.canonical(f.s.progress)==localProgress and Json.canonical(f.w.held.base)==baseline,"maintenance changed immutable/storage/local progress")
  check(f.recovery.state==(if refused then "refused" else "cancelled") and f.s.intents.requests.main.credential==nil and not f.c.leaseLost,"held maintenance resumed recovery/granted authority")
  finish(f)
 end end
end)

test("stable-renewal-evidence-and-callback-replay-across-wait",function()
 local callbacks=0
 local f=typed(false,false,function(b)
  local provider=b.update;b.update=function(self,key,fn) return provider(self,key,function(old) callbacks+=1;fn(Json.copy(old));return fn(old) end) end
 end)
 step(f,false);check(f.j.phase=="renew","typed initial probe failed")
 f.clock.now=f.s.sched.lastBeat+Rules.HEARTBEAT;f.budget.write=0
 local n=f.j.requests;local original=withoutLock(f.b)
 for _=1,12 do check(not step(f,false),"queued held renewal started provider") end
 local evidence=f.j.updateState
 check(evidence and evidence.transform and f.j.requests==n and f.j.failures==0,"renewal wait lost callback or spent attempts")
 f.budget.write=1000;step(f,false)
 check(f.j.updateState==nil and callbacks==1 and f.j.requests==n+1 and f.j.state=="pending" and f.s.sched.lastBeat==f.b.data.P_46001.lock.beat,"renewal callback/evidence was not retained/recomputed")
 check(withoutLock(f.b)==original,"held callback replay changed payload/archive")
 finish(f)
end)

test("ambiguous-renewal-reprobes-with-provider-backoff",function()
 for _,after in {false,true} do
  local f=typed(false,false);step(f,false);f.clock.now=f.s.sched.lastBeat+Rules.HEARTBEAT
  local original=withoutLock(f.b);f.b:fail({op="update",key=f.s.pkey,afterWrite=after,message="timeout"});step(f,false)
  check(f.j.phase=="probe" and f.j.failures==1 and f.j.nextAt>f.clock.now and not f.c.leaseLost,"ambiguous renewal lost lease instead of fresh probe/backoff")
  local n=f.j.requests;check(not step(f,false) and f.j.requests==n,"backoff made provider attempt")
  f.clock.now=f.j.nextAt;f.budget.read=0
  for _=1,6 do step(f,false) end
  check(f.j.phase=="probe" and f.j.failures==1 and f.j.requests==n,"read allowance wait impersonated provider failure")
  f.budget.read=1000;step(f,false)
  check(f.j.state=="pending" and f.j.phase=="renew" and f.j.failures==0 and withoutLock(f.b)==original,"ambiguous renewal probe failed or altered payload")
  finish(f)
 end
end)

test("queued-probe-expiry-foreign-owner-and-route-loss-refuse",function()
 for _,why in {"expiry","foreign","load","backend","source","clock"} do
  local f=typed(false,false);f.budget.read=0;step(f,false);local before=f.b.requests;local start=f.clock.now
  if why=="expiry" then f.clock.now=f.j.expiresAt
  elseif why=="foreign" then f.b:poke(f.s.pkey,Envelope.withLock(f.b.data.P_46001,{session="foreign",beat=f.clock.now}));f.budget.read=1000
  elseif why=="load" then f.s._loadSerial+=1
  elseif why=="backend" then f.s.backend=__progressBaselinePrototype.new(f.b,"46001")
  elseif why=="source" then f.w.source=Memory.new()
  else f.clock.now-=1 end
  local raw=Json.canonical(f.b.data);f.idle:step(f.j)
  check(f.j.state=="lost" and f.c.leaseLost and f.j.io==nil and not f.j.result.gameplayAuthorized,"invalid held scope retained authority/queued work: "..why)
  check(Json.canonical(f.b.data)==raw and f.b.requests-before==(if why=="foreign" then 1 else 0),"invalid held scope wrote/requested: "..why)
  f.clock.now=math.max(f.clock.now,start)+1;finish(f)
 end
end)

test("cancel-suspended-committed-renewal-drains-account",function()
 local f=typed(false,false,function(b)
  local provider=b.update;b.update=function(self,key,fn) local out=table.pack(provider(self,key,fn));coroutine.yield("held-committed");return table.unpack(out,1,out.n) end
 end)
 step(f,false);f.clock.now=f.s.sched.lastBeat+Rules.HEARTBEAT
 local co=coroutine.create(function() return f.idle:step(f.j) end);local ok,mark=coroutine.resume(co);assert(ok,mark)
 check(mark=="held-committed" and f.s.busy and f.c.busy and f.g:inspect().started==1,"held provider did not retain busy/start scope")
 local raw=Json.canonical(f.b.data.P_46001);local debt=f.g:inspect()
 check(f.idle:cancel() and f.j.state=="stopped" and f.c.idleOwner==nil,"typed idle cancellation refused suspended operation")
 f.g:close(f.scope);check(f.g:open("46001","next-held")==nil,"replacement overlapped suspended held renewal")
 assert(coroutine.resume(co));check(not f.s.busy and not f.c.busy and not f.idle.busy and f.j.state=="stopped" and not f.c.leaseLost,"late held result resumed authority or retained busy flags")
 check(Json.canonical(f.b.data.P_46001)==raw,"cancel rolled back committed renewal")
 local scope=assert(f.g:open("46001","next-held"));local after=f.g:inspect();check(after.read==debt.read and after.write==debt.write,"held cancellation refunded debt")
 f.g:close(scope)
end)

test("explicit-retry-cancels-queued-idle-and-uses-shared-pipeline",function()
 local f=typed(false,true);step(f,false);f.clock.now=f.s.sched.lastBeat+Rules.HEARTBEAT;f.budget.write=0;step(f,false)
 check(f.j.io~=nil and f.g:inspect().queued==1,"retry fixture did not queue held renewal")
 local kept=Json.canonical({f.b.data.A1_46001_progress,f.b.data.A1_46001_main,f.b.data.A1_46001_index,f.b.data.M1_46001_main})
 assert(f.s:requestLife("continue","main",2,f.read.offer.id));local resumed=assert(f.c:begin("main",2,f.read.offer.id,f.read))
 check(f.j.state=="stopped" and f.j.io==nil and f.c.idleOwner==nil and not f.c.leaseLost,"retry did not clean terminal maintenance")
 f.budget.write=1000
 local global,provider=f.s.counters.requests,f.b.requests
 for _=1,3000 do
  if resumed.state~="pending" then break end
  local n=f.b.requests;f.c:step(resumed)
  check(f.b.requests-n<=1 and resumed.requests==f.s.counters.requests-global and resumed.requests==f.b.requests-provider,"retry root/global/provider accounting differs")
  f.clock.now+=1
 end
 check(resumed.state=="rebound" and not resumed.result.gameplayAuthorized and f.s.intents.requests.main.credential==nil,"held retry did not complete guarded rebind")
 check(Json.canonical({f.b.data.A1_46001_progress,f.b.data.A1_46001_main,f.b.data.A1_46001_index,f.b.data.M1_46001_main})==kept,"retry changed committed archive/proposal")
 finish(f)
end)

test("closed-departure-stops-held-route-and-preserves-local-choices",function()
 local f=typed(false,true);step(f,false);f.clock.now=f.s.sched.lastBeat+Rules.HEARTBEAT;f.budget.write=0;step(f,false)
 local q=Json.copy(f.s.progress);q.settings.MasterVolume=.3;assert(f.s:setProgress(q));local kept=withoutLock(f.b)
 local d=__departurePrototype.new(f.c,{admission=f.lane});local j=assert(d:begin());f.idle:step(f.j)
 check(f.j.state=="stopped" and f.j.io==nil and not f.c.leaseLost,"closed departure did not stop held operation")
 f.budget.write=1000
 for _=1,100 do if j.state~="pending" then break end;d:step(j);f.clock.now+=.25 end
 check(j.state=="preserved" and f.s.closed and not f.s.lockHeld and f.b.data.P_46001.payload.settings.MasterVolume==.3 and f.b.data.P_46001.lock==nil,"held departure lost local choice/release")
 check(f.s.intents.requests.main.credential==nil and j.io==nil,"held departure granted play or retained admission")
 finish(f)
end)

print("HELD_ADMISSION passed="..count.." failed=0 groups="..groups)
end
runHeldAdmissionChecks()
end
