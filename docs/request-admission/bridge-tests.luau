do
local Gate=__workerAdmission
local Worker=__workerBridge
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Scheduler=require("../src/Shared/Persistence/SaveScheduler")
local checks,groups=0,0
local function check(ok,why) assert(ok,why);checks+=1 end
local function test(name,fn) local before=checks;fn();groups+=1;print("BRIDGE_CASE",name,checks-before) end
local function fixture(override)
 local clock={now=100};local budget={read=80,write=80};local live={value=true}
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read
 if override then override(b) end
 local s={cfg={userId="a"},id="visit",backend=b,sched=Scheduler.new(),counters={requests=0},now=function() return clock.now end}
 local g=Gate.new({now=s.now,available=function() return budget end,actorRead=20,actorWrite=20,serverRead=40,serverWrite=40,headroom=0})
 local scope=assert(g:open("a","visit"));assert(g:importLegacy(scope,{}));local j={requests=0}
 local w=Worker.new(s,j,{gate=g,scope=scope},2,function() return live.value end)
 return b,s,j,g,scope,w,live,clock,budget
end
test("job-cap-and-backend-error-tuple",function()
 local b,s,j,g,scope,w=fixture()
 b:fail({op="read",key="x",times=1,message="503: failed"})
 local state,result,asked=w:poll("readRawFresh","x",nil)
 check(state=="done" and result[1]==false and result[3]=="503: failed" and asked,"backend failure tuple was changed to admission success/failure")
 check(j.requests==1 and s.counters.requests==1 and #s.sched.started==1,"backend failure not accounted")
 state,result,asked=w:poll("readRawFresh","x",nil)
 check(state=="done" and result[1]==true and asked and j.requests==2,"second request did not start")
 local before=b.requests;state,result,asked=w:poll("readRawFresh","x",nil)
 check(state=="failed" and not asked and b.requests==before and j.requests==2,"worker cap did not refuse before provider")
end)
test("transform-retry-lifetime-fences",function()
 local transformCalls=0;local liveRef=nil;local candidates={}
 local b,s,j,g,scope,w,live=fixture(function(store)
  store.update=function(self,key,fn)
   candidates[1]=fn({old=true});candidates[2]=fn({old=true});return true,candidates[2],nil
  end
 end)
 liveRef=live
 local state,result,asked=w:poll("update","x",function(old)
  transformCalls+=1;liveRef.value=false;return {new=true}
 end)
 check(transformCalls==1 and candidates[1]==nil and candidates[2]==nil,"invalid transform escaped on first result/retry")
 check(state=="cancelled" and result==nil and asked and j.requests==1,"invalid update exposed result or lost debt")
 check(g:inspect().read==1 and g:inspect().write==1,"update not charged as both types")
end)
test("committed-write-cancelled-before-ack",function()
 local b,s,j,g,scope,w,live=fixture(function(store)
  local update=store.update
  store.update=function(self,key,fn)
   local returned=table.pack(update(self,key,fn));coroutine.yield("committed");return table.unpack(returned,1,returned.n)
  end
 end)
 local output=nil
 local co=coroutine.create(function() output=table.pack(w:poll("update","x",function() return {saved=true} end)) end)
 local okay,why=coroutine.resume(co)
 check(okay and why=="committed" and b.data.x.saved and j.requests==1,"write not committed before suspended acknowledgement")
 w:cancel();g:close(scope);check(g:open("a","next")==nil,"new owner started before committed write drained")
 check(coroutine.resume(co) and coroutine.status(co)=="dead","write acknowledgement did not drain")
 check(output[1]=="cancelled" and output[2]==nil and output[3]==true and b.data.x.saved,"cancel either exposed success or pretended to roll back storage")
 check(g:inspect().read==1 and g:inspect().write==1 and g:open("a","next")~=nil,"commit debt lost/replacement blocked after drain")
end)
test("pending-identity-and-method-capture",function()
 local b,s,j,g,scope,w,live,clock,budget=fixture()
 budget.read=0
 local state=w:poll("readRawFresh","x",nil);check(state=="waiting" and g:inspect().queued==1,"request was not queued")
 state=w:poll("readRawFresh","y",nil)
 check(state=="failed" and b.requests==0 and g:inspect().queued==0,"changed pending key silently reused ticket")
 local b2,s2,j2,g2,scope2,w2=fixture()
 b2.readRawFresh=function() error("mutated method ran") end
 local state2,result=w2:poll("readRawFresh","x",nil)
 check(state2=="done" and result[1]==true and j2.requests==1,"provider method was rebound after construction")
end)
test("counter-replacement-and-invalid-account-scope",function()
 local b,s,j,g,scope,w=fixture()
 s.counters={requests=0};local state,result,asked=w:poll("readRawFresh","x",nil)
 check(state=="cancelled" and not asked and b.requests==0,"counter ownership change was ignored")
 local other=assert(g:open("other","visit"));assert(g:importLegacy(other,{}))
 check(not pcall(Worker.new,s,j,{gate=g,scope=other},2,function() return true end),"foreign actor scope accepted")
end)
print("ADMISSION_BRIDGE passed="..checks.." failed=0 groups="..groups)
end
