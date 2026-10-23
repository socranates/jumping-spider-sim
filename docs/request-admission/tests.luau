local Admission=require("./admission")
local passed,groups=0,0
local function check(value,why) passed+=1;assert(value,why or "admission assertion") end
local function group(name,fn)
 local before=passed;fn();groups+=1;print("ADMISSION_CASE",name,passed-before)
end
local function fixture(options)
 local f={time=0,read=100,write=100,starts={},lookup=nil}
 local cfg={now=function() if f.clock then return f.clock() end;return f.time end,available=function() if f.lookup then return f.lookup() end;return {read=f.read,write=f.write} end,
  actorRead=30,actorWrite=10,serverRead=60,serverWrite=30,headroom=1,maxActors=16,maxPending=64}
 for k,v in options or {} do cfg[k]=v end
 local g=Admission.new(cfg)
 local function provider(actor,kind,body)
  return function()
   if kind~="write" then check(f.read>0,"provider started without a read allowance");f.read-=1 end
   if kind~="read" then check(f.write>0,"provider started without a write allowance");f.write-=1 end
   table.insert(f.starts,{actor=actor,kind=kind,at=f.time})
   if body then return body() end
   return "value",nil,"third"
  end
 end
 return g,f,provider,cfg
end
local function open(g,actor,epoch) local s,why=g:open(actor,epoch or "epoch1");assert(s,why);return s end
local function request(g,s,kind) local t,why=g:request(s,kind);assert(t,why);return t end
group("zero-and-changing-allowance",function()
 local g,f,p=fixture();local s=open(g,"a");f.read=0
 local t=request(g,s,"read");check(not g:reserve(t));check(not g:dispatch(t,p("a","read")));check(#f.starts==0)
 f.read=2;check(g:reserve(t));f.read=1;check(not g:dispatch(t,p("a","read")));check(#f.starts==0)
 f.read=2;local ok,v=g:dispatch(t,p("a","read"));check(ok and v.n==3 and v[1]=="value" and v[2]==nil and v[3]=="third")
 check(#f.starts==1 and g:status(t)=="ended");check(not g:dispatch(t,p("a","read")))
end)
group("operation-types-and-headroom",function()
 local g,f,p=fixture();local s=open(g,"a");f.write=1
 check(g:dispatch(request(g,s,"read"),p("a","read")))
 local t=request(g,s,"update");check(not g:dispatch(t,p("a","update")));check(#f.starts==1)
 f.write=2;check(g:dispatch(t,p("a","update")));check(f.write==1 and #f.starts==2)
 f.read=0;f.write=2;check(g:dispatch(request(g,s,"write"),p("a","write")))
 local info=g:inspect();check(info.read==2 and info.write==2)
end)
group("per-actor-and-server-rolling-caps",function()
 local g,f,p=fixture({actorRead=1,serverRead=2});local a=open(g,"a");local b=open(g,"b")
 check(g:dispatch(request(g,a,"read"),p("a","read")))
 local ta=request(g,a,"read");check(not g:dispatch(ta,p("a","read")))
 check(g:dispatch(request(g,b,"read"),p("b","read")))
 local tb=request(g,b,"read");check(not g:dispatch(tb,p("b","read")))
 f.time=59.999;check(not g:dispatch(ta,p("a","read")))
 f.time=60;check(g:dispatch(ta,p("a","read")));check(g:dispatch(tb,p("b","read")));check(#f.starts==4)
end)
group("write-cap-does-not-block-independent-reads",function()
 local g,f,p=fixture({actorWrite=1});local a=open(g,"a");local b=open(g,"b")
 check(g:dispatch(request(g,a,"write"),p("a","write")))
 local old=request(g,a,"update");check(not g:dispatch(old,p("a","update")))
 check(g:dispatch(request(g,b,"read"),p("b","read")))
 check(#f.starts==2 and f.starts[2].kind=="read")
end)
group("fair-queue-and-abandoned-poller",function()
 local g,f,p=fixture();local a=open(g,"a");local b=open(g,"b")
 local first=request(g,a,"read");local nextOne=request(g,b,"read")
 check(not g:dispatch(nextOne,p("b","read")));check(#f.starts==0)
 check(g:dispatch(first,p("a","read")));check(g:dispatch(nextOne,p("b","read")))
 local abandoned=request(g,a,"read");local active=request(g,b,"read");f.time=2.001
 check(g:dispatch(active,p("b","read")));check(g:status(abandoned)=="queued")
 check(g:dispatch(abandoned,p("a","read")))
end)
group("reservation-and-pending-capacity",function()
 local g,f,p=fixture({serverRead=2,maxPending=3});local a=open(g,"a");local b=open(g,"b");local c=open(g,"c")
 local ta=request(g,a,"read");local tb=request(g,b,"read");local tc=request(g,c,"read")
 check(g:reserve(ta));check(g:reserve(tb));check(not g:reserve(tc));check(g:inspect().history==0)
 check(g:request(a,"read")==nil);check(g:cancel(ta));check(g:reserve(tc))
 check(g:dispatch(tb,p("b","read")));check(g:dispatch(tc,p("c","read")));check(#f.starts==2)
end)
group("reservation-expiry-is-terminal",function()
 local g,f,p=fixture();local a=open(g,"a");local b=open(g,"b")
 local old=request(g,a,"read");check(g:reserve(old));local waiting=request(g,b,"read")
 f.time=2;check(g:status(old)=="ended");check(not g:dispatch(old,p("a","read")))
 check(g:dispatch(waiting,p("b","read")));check(#f.starts==1)
end)
group("closed-visits-carry-debt",function()
 local g,f,p=fixture({actorRead=1});local a=open(g,"a","one")
 check(g:dispatch(request(g,a,"read"),p("a","read")));check(g:close(a));check(not g:close(a))
 check(g:open("a","one")==nil);local fresh=open(g,"a","two");local t=request(g,fresh,"read")
 check(not g:dispatch(t,p("a","read")));check(#f.starts==1)
 f.time=60;check(g:dispatch(t,p("a","read")));check(#f.starts==2)
end)
group("provider-yield-close-and-drain",function()
 local g,f,p=fixture({actorRead=1});local a=open(g,"a","one");local t=request(g,a,"read");local result
 local co=coroutine.create(function() result=table.pack(g:dispatch(t,p("a","read",function() coroutine.yield("provider");return "obsolete" end))) end)
 local ok,where=coroutine.resume(co);check(ok and where=="provider");check(g:inspect().started==1)
 check(g:close(a));check(g:open("a","two")==nil);check(not g:cancel(t))
 check(coroutine.resume(co));check(result[1]==false and result[2]==nil and result[3]=="provider completed after visit closed")
 local fresh=open(g,"a","two");check(not g:dispatch(request(g,fresh,"read"),p("a","read")));check(#f.starts==1)
end)
group("in-flight-capacity-is-reserved",function()
 local g,f,p=fixture();local a=open(g,"a");local b=open(g,"b");f.read=3
 local co=coroutine.create(function() check(g:dispatch(request(g,a,"read"),p("a","read",function() coroutine.yield();return true end))) end)
 check(coroutine.resume(co));local t=request(g,b,"read");check(not g:dispatch(t,p("b","read")));check(#f.starts==1)
 check(coroutine.resume(co));check(g:dispatch(t,p("b","read")));check(#f.starts==2)
end)
group("cancel-during-yielding-budget-query",function()
 local g,f,p=fixture();local a=open(g,"a");local t=request(g,a,"read");local result
 f.lookup=function() coroutine.yield("lookup");return {read=100,write=100} end
 local co=coroutine.create(function() result=table.pack(g:dispatch(t,p("a","read"))) end)
 local okay,where=coroutine.resume(co);check(okay and where=="lookup");check(g:cancel(t));check(coroutine.resume(co))
 check(result[1]==false and #f.starts==0 and g:inspect().history==0)
end)
group("reentrant-budget-query-cannot-admit-stale-state",function()
 local g,f,p=fixture();local a=open(g,"a");local b=open(g,"b");local ta=request(g,a,"read");local tb=request(g,b,"write");local entered=false
 f.lookup=function()
  if not entered then entered=true;check(g:dispatch(tb,p("b","write"))) end
  return {read=f.read,write=f.write}
 end
 check(not g:dispatch(ta,p("a","read")));check(#f.starts==1 and f.starts[1].actor=="b")
 check(g:dispatch(ta,p("a","read")));check(#f.starts==2)
end)
group("reentrant-clock-after-allowance-cannot-oversubscribe",function()
 local g,f,p=fixture();local a=open(g,"a");local b=open(g,"b")
 local tb=request(g,b,"read");local ta=request(g,a,"read");f.read=2
 local queried,inside=false,false
 f.lookup=function() queried=true;return {read=f.read,write=f.write} end
 f.clock=function()
  if queried and not inside then inside=true;check(g:dispatch(tb,p("b","read"))) end
  return f.time
 end
 check(not g:dispatch(ta,p("a","read")));check(#f.starts==1 and f.starts[1].actor=="b")
 f.clock=nil;f.lookup=nil;check(not g:dispatch(ta,p("a","read")));check(#f.starts==1)
end)
group("closed-scope-during-budget-query",function()
 local g,f,p=fixture();local a=open(g,"a");local t=request(g,a,"update")
 f.lookup=function() g:close(a);return {read=100,write=100} end
 check(not g:dispatch(t,p("a","update")));check(#f.starts==0 and g:inspect().history==0)
end)
group("provider-reentrancy-cannot-overlap-a-physical-actor",function()
 local g,f,p=fixture();local a=open(g,"a");local first=request(g,a,"read");local second=request(g,a,"update")
 check(g:dispatch(first,p("a","read",function()
  check(not g:dispatch(first,p("a","read")))
  check(not g:dispatch(second,p("a","update")))
  check(#f.starts==1)
 end)))
 check(g:dispatch(second,p("a","update")));check(#f.starts==2)
end)
group("ticket-expiry-during-budget-query",function()
 local g,f,p=fixture();local a=open(g,"a");local t=request(g,a,"read")
 f.lookup=function() f.time=120;return {read=100,write=100} end
 check(not g:dispatch(t,p("a","read")));check(#f.starts==0 and g:status(t)=="ended")
end)
group("provider-failure-is-charged",function()
 local g,f,p=fixture({actorRead=1});local a=open(g,"a")
 local okay,_,why=g:dispatch(request(g,a,"read"),p("a","read",function() error("synthetic provider failure") end))
 check(not okay and string.find(why,"synthetic provider failure",1,true));check(#f.starts==1 and g:inspect().history==1)
 check(not g:dispatch(request(g,a,"read"),p("a","read")))
end)
group("invalid-allowance-and-clock-refuse-without-start",function()
 local g,f,p=fixture();local a=open(g,"a");local t=request(g,a,"read")
 for _,v in {false,{read=0/0,write=100},{read=math.huge,write=100},{read=-1,write=100},{read="100",write=100},setmetatable({read=100,write=100},{})} do
  f.lookup=function() return v end;check(not g:dispatch(t,p("a","read")));check(#f.starts==0)
 end
 f.lookup=function() error("budget API unavailable") end;check(not g:dispatch(t,p("a","read")));check(#f.starts==0)
 f.lookup=nil;f.time=10;check(g:dispatch(t,p("a","read")))
 local nextOne=request(g,a,"read");f.time=9;check(not g:dispatch(nextOne,p("a","read")));check(g:status(nextOne)=="clock_unavailable")
 f.time=0/0;check(not g:dispatch(nextOne,p("a","read")));check(#f.starts==1)
 f.time=10;check(g:dispatch(nextOne,p("a","read")));check(#f.starts==2)
end)
group("bounded-memory-and-physical-actor-retention",function()
 local g,f,p=fixture({maxActors=1,maxPending=2});local a=open(g,"a")
 check(g:dispatch(request(g,a,"read"),p("a","read")));check(g:close(a));check(g:open("b","next")==nil)
 f.time=60;local b=open(g,"b","next");check(g:inspect().actors==1)
 local t=request(g,b,"read");f.time=180;check(g:status(t)=="ended");check(g:close(b));check(g:inspect().actors==0)
 for n=1,500 do
  local scope=open(g,"actor"..n,"e"..n);local pending=request(g,scope,"read");check(g:cancel(pending));check(g:close(scope));check(g:inspect().actors==0)
 end
 check(g:inspect().queued==0 and g:inspect().history==0 and #f.starts==1)
end)
group("opaque-handles-and-immutable-configuration",function()
 local g,f,p,cfg=fixture({actorRead=1});local a=open(g,"a");local t=request(g,a,"read")
 check(not g:dispatch({id=t.id},p("a","read")));check(g:request({id=a.id,actor="a",epoch="epoch1"},"read")==nil)
 check(not pcall(function() t.id=1 end));check(not pcall(function() a.actor="b" end))
 cfg.actorRead=1000;check(g:dispatch(t,p("a","read")));check(not g:dispatch(request(g,a,"read"),p("a","read")));check(#f.starts==1)
end)
group("independent-rolling-oracle",function()
 local g,f,p=fixture({actorRead=3,actorWrite=2,serverRead=5,serverWrite=3,headroom=2,maxActors=4,maxPending=16})
 local scopes={open(g,"a"),open(g,"b"),open(g,"c")};local queued={};local kinds={"read","update","write"}
 for tick=0,599 do
  f.time=tick*.5;f.read=20;f.write=20
  for i,scope in scopes do
   if not queued[i] then local kind=kinds[(tick+i)%3+1];queued[i]={ticket=request(g,scope,kind),kind=kind} end
   local t=queued[i].ticket;local success=g:dispatch(t,p(scope.actor,queued[i].kind))
   if success then queued[i]=nil elseif g:status(t)=="ended" then queued[i]=nil end
  end
  local read,write=0,0;local actors={}
  for _,start in f.starts do if f.time-start.at<60 then
   local a=actors[start.actor] or {read=0,write=0};actors[start.actor]=a
   if start.kind~="write" then read+=1;a.read+=1 end
   if start.kind~="read" then write+=1;a.write+=1 end
  end end
  check(read<=5 and write<=3,"independent server rolling quota exceeded")
  for _,a in actors do check(a.read<=3 and a.write<=2,"independent actor rolling quota exceeded") end
  check(g:inspect().queued<=3,"queue leaked in long interleaving")
 end
 check(#f.starts>15,"oracle never exercised replenished budgets")
end)
group("mixed-workload-does-not-spend-write-budget-on-reads",function()
 local g,f,p=fixture();local s=open(g,"a")
 for _=1,24 do check(g:dispatch(request(g,s,"read"),p("a","read"))) end
 for _=1,6 do check(g:dispatch(request(g,s,"update"),p("a","update"))) end
 check(#f.starts==30 and g:inspect().read==30 and g:inspect().write==6)
 -- The legacy aggregate10/min policy needs two60s waits for these same30
 -- starts. This is an admission-only synthetic comparison, not game timing.
 local legacyStarts={};local now=0
 for _=1,30 do
  local count=0;for _,at in legacyStarts do if now-at<60 then count+=1 end end
  if count>=10 then now+=60 end;table.insert(legacyStarts,now)
 end
 check(now==120 and f.time==0)
 print("ADMISSION_SYNTHETIC_MIX",#f.starts,"read_units=30 write_units=6 legacy_wait=120 candidate_wait=0")
end)
print("REQUEST_ADMISSION passed="..passed.." failed=0 groups="..groups)
