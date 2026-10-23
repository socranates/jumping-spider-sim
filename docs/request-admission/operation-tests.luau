do
local checks,groups=0,0
local function check(ok,why) assert(ok,why);checks+=1 end
local function test(name,fn) local before=checks;fn();groups+=1;print("OPERATION_CASE",name,checks-before) end
local function fixture(bindings)
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read
 local s={cfg={userId="a"},id="1",backend=b,sched=Scheduler.new(),counters={requests=0},now=function() return 100 end}
 local budget={read=0,write=0};local g=Admission.new({now=s.now,available=function() return budget end,actorRead=20,actorWrite=20,serverRead=40,serverWrite=40,headroom=0})
 local scope=assert(g:open("a","1"));assert(g:importLegacy(scope,{}));local parent={requests=0};local child={requests=0,state="pending"};local live=true
 local rows={{object=parent,field="requests",max=2},{object=child,field="requests",max=2}}
 local op=Operation.new(s,{gate=g,scope=scope},function() return live end,rows,bindings and bindings(b),{object=child,field="state",value="running"})
 return b,s,g,scope,budget,parent,child,op,function() live=false end
end
test("waiting-then-atomic-parent-child-and-marker",function()
 local b,s,g,scope,budget,parent,child,op=fixture()
 for _=1,20 do local state,result,asked=op:poll("readRawFresh","x",nil);check(state=="waiting" and not asked and result==nil,"denial did not wait") end
 check(s.counters.requests==0 and parent.requests==0 and child.requests==0 and child.state=="pending" and b.requests==0,"waiting spent counters/changed marker")
 check(g:inspect().queued==1,"pending operation duplicated")
 budget.read=80
 local state,result,asked=op:poll("readRawFresh","x",nil)
 check(state=="done" and result[1] and asked and b.requests==1,"admitted read did not start exactly once")
 check(s.counters.requests==1 and parent.requests==1 and child.requests==1 and child.state=="running","nested counters/marker were not atomic")
 op:poll("readRawFresh","x",nil);local before=b.requests
 state,result,asked=op:poll("readRawFresh","x",nil)
 check(state=="failed" and not asked and b.requests==before and parent.requests==2 and child.requests==2,"nested cap was bypassed")
end)
test("counter-cap-change-during-scheduler-bookkeeping",function()
 local b,s,g,scope,budget,parent,child,op=fixture();local begin=s.sched.begin
 s.sched.begin=function(self,name,now) local version=begin(self,name,now);parent.requests=2;return version end
 budget.read=80;local state,result,asked=op:poll("readRawFresh","x",nil)
 check(state=="failed" and not asked and b.requests==0,"changed nested cap started provider")
 check(s.counters.requests==0 and child.requests==0 and child.state=="pending","partial accounting occurred")
 check(#s.sched.started==1 and g:inspect().history==1,"bookkeeping debt was refunded")
end)
test("explicit-raw-adapter-without-rebinding-session",function()
 local rawCalls=0;local originalBackend=nil
 local b,s,g,scope,budget,parent,child,op=fixture(function(backend)
  originalBackend=backend;local raw={}
  raw.write=function(self,key,fn) rawCalls+=1;return backend:update(key,fn) end
  return {update={object=raw,fn=raw.write}}
 end)
 budget.read=80;budget.write=80
 local state,result,asked=op:poll("update","R_a_main",function() return {raw=true} end)
 check(state=="done" and result[1] and asked and rawCalls==1 and b.data.R_a_main.raw,"explicit raw adapter did not execute")
 check(s.backend==originalBackend and s.counters.requests==1 and parent.requests==1 and child.requests==1,"adapter rebound session/double counted")
 check(g:inspect().read==1 and g:inspect().write==1,"raw update cost was not typed")
end)
test("callback-retry-and-late-committed-result-fenced",function()
 local b,s,g,scope,budget,parent,child,op,cancel=fixture()
 budget.read=80;budget.write=80
 local update=b.update
 -- The binding is captured already. Supply cancellation from the transform;
 -- candidate must be refused even when the captured Memory backend retries.
 local calls=0;local state,result,asked=op:poll("update","x",function() calls+=1;cancel();return {bad=true} end)
 check(state=="cancelled" and result==nil and asked and b.data.x==nil and calls==1,"cancelled transform escaped")
 check(parent.requests==1 and child.requests==1 and s.counters.requests==1 and g:inspect().write==1,"cancelled provider debt changed")
end)
test("duplicate-rows-and-marker-counter-alias-refused",function()
 local b,s,g,scope,budget,parent,child,op=fixture();op:cancel()
 local lane={gate=g,scope=scope}
 check(not pcall(Operation.new,s,lane,function() return true end,{{object=parent,field="requests",max=2},{object=parent,field="requests",max=2}}),"duplicate nested counter accepted")
 check(not pcall(Operation.new,s,lane,function() return true end,{{object=s.counters,field="requests",max=2}}),"global counter could be charged twice")
 check(not pcall(Operation.new,s,lane,function() return true end,{{object=parent,field="requests",max=2}},nil,{object=parent,field="requests",value="running"}),"dispatch marker could overwrite a numeric counter")
 check(g:inspect().queued==0 and b.requests==0,"invalid rows queued/called provider")
end)
print("NESTED_OPERATION passed="..checks.." failed=0 groups="..groups)
end
