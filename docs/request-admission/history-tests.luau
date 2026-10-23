do
local checks=0
local function check(ok,why) assert(ok,why);checks+=1 end
for _,kind in {"worker","operation"} do
 local clock={now=100};local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read
 local s={cfg={userId="a"},id="history",backend=b,sched=Scheduler.new(),counters={requests=0},now=function() return clock.now end}
 local g=Admission.new({now=s.now,available=function() return {read=10000,write=10000} end,actorRead=1000,actorWrite=1000,serverRead=1000,serverWrite=1000,headroom=0})
 local scope=assert(g:open("a",s.id));assert(g:importLegacy(scope,{}));local j={requests=0}
 local io=if kind=="worker" then Worker.new(s,j,{gate=g,scope=scope},1000,function() return true end)
  else Operation.new(s,{gate=g,scope=scope},function() return true end,{{object=j,field="requests",max=1000}})
 for _=1,180 do
  clock.now+=1;local state,result,asked=io:poll("readRawFresh","x",nil)
  check(state=="done" and result[1] and asked,"history cleanup changed request result")
  check(#s.sched.started<=60,"typed scheduler request history grows without bound")
 end
 check(b.requests==180 and j.requests==180 and s.counters.requests==180,"cleanup changed lifetime counters")
 check(#s.sched.started==60 and s.sched.started[1]==221 and s.sched.started[60]==280,"rolling cleanup removed the wrong timestamps")
 check(g:inspect().history==60 and g:inspect().read==60,"cleanup reset typed rolling debt")
 io:cancel();g:close(scope);local nextScope=assert(g:open("a","next"))
 check(g:legacyReady(nextScope) and g:inspect().read==60,"replacement discarded retained rolling debt")
 for _,bad in {{[2]=99},{0/0},setmetatable({99},{})} do
  local backend=Memory.new();backend.readFresh=backend.read;backend.readRawFresh=backend.read
  local session={cfg={userId="b"},id="bad-history",backend=backend,sched=Scheduler.new(),counters={requests=0},now=function() return 100 end}
  local gate=Admission.new({now=session.now,available=function() return {read=100,write=100} end,actorRead=10,actorWrite=10,serverRead=20,serverWrite=20,headroom=0})
  local visit=assert(gate:open("b",session.id));assert(gate:importLegacy(visit,{}));local job={requests=0}
  local operation=if kind=="worker" then Worker.new(session,job,{gate=gate,scope=visit},10,function() return true end)
   else Operation.new(session,{gate=gate,scope=visit},function() return true end,{{object=job,field="requests",max=10}})
  session.sched.started=bad
  local state,result,asked=operation:poll("readRawFresh","x",nil)
  check(state=="failed" and result==nil and not asked and backend.requests==0 and job.requests==0 and session.counters.requests==0,"malformed bookkeeping history still started a provider")
  check(session.sched.started==bad and gate:inspect().history==1,"malformed history was erased or admitted debt refunded")
 end
end
print("TYPED_HISTORY passed="..checks.." failed=0 groups=2")
end
