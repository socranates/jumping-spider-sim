do
local passed=0
local function check(ok,why) assert(ok,why);passed+=1 end
local function fixture()
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read
 local s={cfg={userId="a"},id="1",backend=b,sched=Scheduler.new(),counters={requests=0},now=function() return 100 end}
 local g=Admission.new({now=s.now,available=function() return {read=80,write=80} end,actorRead=20,actorWrite=20,serverRead=40,serverWrite=40,headroom=0})
 local scope=assert(g:open("a","1"));assert(g:importLegacy(scope,{}));local j={requests=0};local live=true
 local w=Worker.new(s,j,{gate=g,scope=scope},4,function() return live end)
 return b,s,j,g,scope,w,function() live=false end
end
do
 local b,s,j,g,scope,w,cancel=fixture();local begin=s.sched.begin
 s.sched.begin=function(self,name,now) local version=begin(self,name,now);cancel();return version end
 local state,result,asked=w:poll("readRawFresh","x",nil)
 check(b.requests==0,"scheduler cancellation still started a provider")
 check(state=="cancelled" and result==nil and not asked and j.requests==0 and s.counters.requests==0,"cancelled bookkeeping exposed/charged a provider result")
 check(#s.sched.started==1 and g:inspect().history==1,"conservative pre-dispatch debt was incorrectly refunded")
end
do
 local b,s,j,g,scope,w,cancel=fixture();local begin=s.sched.begin;local output=nil
 s.sched.begin=function(self,name,now) coroutine.yield("bookkeeping");return begin(self,name,now) end
 local co=coroutine.create(function() output=table.pack(w:poll("update","x",function() return {bad=true} end)) end)
 local okay,why=coroutine.resume(co);check(okay and why=="bookkeeping" and b.requests==0,"bookkeeping did not yield before provider")
 w:cancel();g:close(scope);check(g:open("a","next")==nil,"replacement opened over a suspended admitted dispatch")
 check(coroutine.resume(co) and coroutine.status(co)=="dead","cancelled bookkeeping did not drain")
 check(b.requests==0 and b.data.x==nil and j.requests==0 and s.counters.requests==0,"cancelled bookkeeping still invoked a write")
 check(output[1]=="cancelled" and output[2]==nil and not output[3] and g:inspect().history==1,"ended bookkeeping exposed success/refunded debt")
 check(g:open("a","next")~=nil,"replacement stayed blocked after bookkeeping drained")
end
print("DISPATCH_GUARD passed="..passed.." failed=0 groups=2")
end
