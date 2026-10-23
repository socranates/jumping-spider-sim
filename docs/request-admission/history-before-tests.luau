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
end
print("TYPED_HISTORY passed="..checks.." failed=0 groups=2")
end
