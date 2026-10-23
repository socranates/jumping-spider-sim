do
local Gate=__workerAdmission
local Reader=__offerReaderPrototype
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Session=require("../src/Shared/Persistence/SaveSession")
local Json=require("../src/Shared/Persistence/Json")
local passed,groups=0,0
local function check(ok,why) assert(ok,why);passed+=1 end
local function test(name,fn)
 local before=passed;fn();groups+=1;print("WORKER_ADMISSION_CASE",name,passed-before)
end
local function fixture(pending)
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 b:poke("P_46001",Json.copy(rawProgress));b:poke("R_46001_main",Json.copy(if pending then anchor.target else rest))
 if pending then
  b:poke(anchor.id,Json.copy(anchor))
  local parts={progress={format=__archiveStorePrototype.FORMAT,version=1,owner="46001",index=archive.index,progress=archive.entries.progress},main=archive.entries.main,
   free=archive.entries.free,easy=archive.entries.easy,index={format=__archiveStorePrototype.FORMAT,version=1,owner="46001",complete=true,index=archive.index}}
  for key,value in parts do b:poke("A1_46001_"..key,Json.copy(value)) end
 end
 local clock={now=200};local budget={read=0,write=0};local emitted=0
 local s=Session.new({backend=b,userId=46001,sessionId="typed-reader",now=function() return clock.now end,onOffer=function() emitted+=1 end})
 assert(s:load()=="active");s:enableOffers()
 local g=Gate.new({now=function() return clock.now end,available=function() return budget end,actorRead=40,actorWrite=40,serverRead=80,serverWrite=80,headroom=0})
 local scope=assert(g:open("46001",s.id));assert(g:importLegacy(scope,s.sched.started))
 local r=Reader.new(s,codec,fresh,{admission={gate=g,scope=scope},work={now=function() return 0 end}})
 local j=assert(r:begin("main"));local baseline={requests=s.counters.requests,provider=b.requests,history=#s.sched.started,bytes=Json.canonical(b.data),writes=b.writes}
 return b,clock,budget,s,g,scope,r,j,baseline,function() return emitted end
end
local function drive(r,j)
 for _=1,10000 do if j.state~="pending" then return end;r:step(j) end
 error("typed reader did not settle: "..tostring(j.phase).." "..tostring(j.problem))
end
test("actual-reader-zero-budget-retains-one-request",function()
 local b,clock,budget,s,g,scope,r,j,base,emitted=fixture(false)
 for _=1,50 do check(not r:step(j),"denied poll reported request") end
 check(j.requests==0 and j.failures==0 and j.phase=="rest","denial consumed attempts/backoff or changed phase")
 check(b.requests==base.provider and s.counters.requests==base.requests and #s.sched.started==base.history,"denial touched provider/accounting")
 check(g:inspect().queued==1,"waiting request duplicated or lost")
 budget.read=80;budget.write=80;drive(r,j)
 check(j.state=="offered" and j.requests==2 and emitted()==1,"cold typed discovery failed")
 check(b.requests-base.provider==2 and s.counters.requests-base.requests==2 and #s.sched.started-base.history==2,"typed request accounting differs from starts")
 check(b.writes==base.writes and Json.canonical(b.data)==base.bytes,"discovery wrote to storage")
 check(s.intents.requests.main==nil and s.lifeTokens.main==nil and g:inspect().queued==0,"discovery granted authority or leaked a ticket")
end)
test("actual-pending-reader-all-seven-fresh-reads",function()
 local b,clock,budget,s,g,scope,r,j,base=fixture(true)
 budget.read=80;drive(r,j)
 check(j.state=="offered" and j.pending and j.archivePlan~=nil and j.requests==7,"pending discovery skipped/rejected witnesses")
 check(b.requests-base.provider==7 and s.counters.requests-base.requests==7 and #s.sched.started-base.history==7,"seven witness accounting mismatch")
 check(Json.canonical(b.data)==base.bytes and b.writes==base.writes,"pending discovery modified originals")
 check(g:inspect().write==base.history,"read-only discovery spent typed write allowance")
end)
test("actual-reader-retries-only-provider-failures",function()
 local b,clock,budget,s,g,scope,r,j,base=fixture(false)
 b:fail({op="read",key="R_46001_main",times=1,message="503: unavailable"})
 budget.read=80;check(r:step(j) and j.requests==1 and j.failures==1,"actual failure did not count/backoff")
 local due=j.nextAt;check(due>clock.now,"provider failure has no backoff")
 for _=1,10 do check(not r:step(j),"backoff dispatched") end
 clock.now=due;budget.read=0
 for _=1,10 do check(not r:step(j),"budget wait dispatched") end
 check(j.requests==1 and j.failures==1 and j.nextAt==due,"capacity wait counted as failure")
 budget.read=80;drive(r,j)
 check(j.state=="offered" and j.requests==3 and b.requests-base.provider==3,"provider retry not preserved")
end)
test("actual-reader-cancel-deadline-and-visit-close",function()
 for _,kind in {"cancel","deadline","close","intent"} do
  local b,clock,budget,s,g,scope,r,j,base=fixture(false)
  r:step(j);check(g:inspect().queued==1,"no pending operation")
  if kind=="cancel" then r:cancel(j)
  elseif kind=="deadline" then clock.now+=300;r:step(j)
  elseif kind=="close" then g:close(scope);r:step(j)
  else assert(s:requestLife("new","main",1,nil));r:step(j) end
  budget.read=80;r:step(j)
  check(j.state~="pending" and j.state~="offered","obsolete queued discovery survived: "..kind)
  check(b.requests==base.provider and s.counters.requests==base.requests and j.requests==0,"obsolete queue started provider")
  check(g:inspect().queued==0,"cancelled queue leaked")
 end
end)
test("route-change-during-budget-query-refuses-provider",function()
 local b,clock,budget,s,g,scope,r,j,base=fixture(false)
 local queries=0
 g.cfg=table.freeze({now=g.cfg.now,actorRead=40,actorWrite=40,serverRead=80,serverWrite=80,available=function()
  queries+=1;s._loadSerial+=1;return {read=80,write=80}
 end})
 r:step(j)
 check(queries==1 and j.state=="cancelled","routing change during budget query not cancelled")
 check(j.requests==0 and s.counters.requests==base.requests and b.requests==base.provider,"obsolete job counted/called provider")
 check(g:inspect().history==base.history+1,"refused typed dispatch did not retain conservative gate debt")
end)
test("yielded-provider-cancel-and-visit-debt",function()
 local b,clock,budget,s,g,scope,r,j,base=fixture(false)
 local read=b.readRawFresh
 -- Methods are captured at construction: bind a reader after installing the test provider.
 r:cancel(j)
 b.readRawFresh=function(self,key) coroutine.yield("provider");return read(self,key) end
 r=Reader.new(s,codec,fresh,{admission={gate=g,scope=scope},work={now=function() return 0 end}});j=assert(r:begin("main"))
 budget.read=80;local co=coroutine.create(function() r:step(j) end)
 local okay,reason=coroutine.resume(co);check(okay and reason=="provider" and j.requests==1,"read did not suspend at actual provider")
 check(s.counters.requests==base.requests+1 and #s.sched.started==base.history+1,"suspended request not accounted once")
 r:cancel(j);g:close(scope)
 check(g:open("46001","next")==nil,"replacement opened before provider drained")
 check(coroutine.resume(co) and coroutine.status(co)=="dead","cancelled provider did not drain")
 check(j.state=="cancelled" and s:offer("main")==nil,"late provider published obsolete offer")
 local nextScope=assert(g:open("46001","next"))
 check(g:legacyReady(nextScope) and not g:importLegacy(nextScope,{}),"replacement reset/reseeded account debt")
 check(g:inspect().history==base.history+1,"late request debt lost")
end)
test("legacy-debt-validation-and-exact-rolling-boundary",function()
 local clock={now=100};local function gate()
  return Gate.new({now=function() return clock.now end,available=function() return {read=100,write=100} end,actorRead=2,actorWrite=2,serverRead=4,serverWrite=4,headroom=0})
 end
 for _,history in {{[2]=99},{[1]=101},{[1]=0/0},{[1]=math.huge},{foo=99},setmetatable({99},{})} do
  local g=gate();local scope=assert(g:open("a","1"))
  check(not g:importLegacy(scope,history) and not g:legacyReady(scope) and g:inspect().history==0,"bad import changed debt")
 end
 local g=gate();local scope=assert(g:open("a","1"));local history={40,99,99}
 check(g:importLegacy(scope,history) and g:inspect().read==2 and g:inspect().write==2,"legacy starts not conservatively weighted/pruned")
 history[2]=0;check(g:inspect().history==2,"legacy debt retained caller alias")
 local t=assert(g:request(scope,"read"));check(not g:dispatch(t,function() error("over cap") end),"legacy debt bypassed")
 clock.now=158.999;check(not g:dispatch(t,function() error("early") end),"legacy debt expired early")
 clock.now=159;check(g:dispatch(t,function() return true end),"legacy debt not released at exact boundary")
 local freshGate=gate();local freshScope=assert(freshGate:open("a","1"));assert(freshGate:request(freshScope,"read"))
 check(not freshGate:importLegacy(freshScope,{}),"import after typed intake allowed")
end)
test("actual-reader-thrown-provider-keeps-backoff",function()
 local b,clock,budget,s,g,scope,r,j,base=fixture(false)
 r:cancel(j);local read=b.readRawFresh;local attempts=0
 b.readRawFresh=function(self,key) attempts+=1;if attempts==1 then error("503: thrown provider",0) end;return read(self,key) end
 r=Reader.new(s,codec,fresh,{admission={gate=g,scope=scope},work={now=function() return 0 end}});j=assert(r:begin("main"))
 budget.read=80
 check(r:step(j) and j.state=="pending" and j.requests==1 and j.failures==1,"thrown provider bypassed the actual reader failure/backoff path")
 check(j.nextAt>clock.now and not r:step(j) and attempts==1,"throwing backend retried before backoff")
 clock.now=j.nextAt;drive(r,j)
 check(j.state=="offered" and j.requests==3 and attempts==3,"thrown backend did not recover through the actual reader")
 check(s.counters.requests==base.requests+3 and Json.canonical(b.data)==base.bytes,"throwing attempt count/original storage changed")
end)
print("WORKER_ADMISSION passed="..passed.." failed=0 groups="..groups)
end
