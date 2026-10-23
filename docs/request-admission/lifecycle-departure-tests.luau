local Gate=__lifecycleGate
local groups=0
local function test(name,fn) local before=count;fn();groups+=1;print("LIFECYCLE_DEPARTURE_CASE",name,count-before) end
local function typed(compressed,postRest,configure,options)
 local b,clock,s,w,c,recovery=fixture(compressed,postRest)
 if configure then configure(b,clock,s,w,c) end
 local f={b=b,clock=clock,s=s,w=w,owner=c,recovery=recovery,budget={read=1000,write=1000}}
 f.g=Gate.new({now=s.now,available=function() return f.budget end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 f.scope=assert(f.g:open("46001",s.id));assert(f.g:importLegacy(f.scope,s.sched.started))
 local cfg={admission={gate=f.g,scope=f.scope}};for k,v in options or {} do cfg[k]=v end
 f.d=__departurePrototype.new(c,cfg);f.j=assert(f.d:begin());f.base={provider=b.requests,global=s.counters.requests}
 check(s.closed and s.flushing and not s:setProgress(Progress.default()),"typed departure reopened player intake")
 return f
end
local function step(f,advance)
 local before=f.b.requests;local asked=f.d:step(f.j)
 check(f.b.requests-before<=1,"departure started multiple providers")
 check(f.j.requests==f.s.counters.requests-f.base.global and f.j.requests==f.b.requests-f.base.provider,"departure/global/provider counts differ")
 check(not f.s.busy and not f.d.busy,"departure retained busy state")
 if advance~=false then f.clock.now+=1 end
 return asked
end
local function drive(f,done)
 for _=1,1000 do if done and done() or not done and f.j.state~="pending" then return end;step(f) end
 error("departure did not settle: "..f.j.phase)
end
local function finish(f)
 f.g:close(f.scope);local q=f.g:inspect();check(q.queued==0 and q.reserved==0 and q.started==0,"departure retained ticket/provider")
end

test("closed-departure-merges-and-releases-all-source-variants",function()
 for _,compressed in {false,true} do for _,post in {false,true} do
  local f=typed(compressed,post);remoteChoice(f.b,f.clock);local untouched=nonProgress(f.b)
  f.budget.read=0;f.budget.write=0;step(f,false)
  local before=f.b.requests
  for _=1,10 do check(not step(f,false),"closed departure wait started provider") end
  check(f.j.phase=="write" and f.j.requests==0 and f.j.failures==0 and f.b.requests==before,"departure wait consumed attempts/backoff")
  f.budget.read=1000;f.budget.write=1000;drive(f)
  local q=f.b.data.P_46001.payload
  check(f.j.state=="preserved" and f.j.result.leaseReleased and not f.j.result.gameplayAuthorized and f.s.closed and not f.s.flushing and not f.s.lockHeld,"departure failed preservation/release or reopened session")
  check(q.settings.SoundMuted==true and q.settings.MasterVolume==.4 and table.find(q.notebook.opened,"depart_local") and table.find(q.notebook.opened,"depart_remote"),"departure lost local/remote choices")
  check(f.j.requests==2 and f.j.io==nil and nonProgress(f.b)==untouched and f.b.data.P_46001.lock==nil,"departure changed other keys or retained handles")
  finish(f)
 end end
end)

test("unlocked-readback-waits-without-another-write",function()
 local f=typed(true,true);local writes=f.b.writes;drive(f,function() return f.j.phase=="readback" end)
 check(f.b.data.P_46001.lock==nil and f.s.lockHeld and f.j.state=="pending","departure inferred release from write ACK")
 f.budget.read=0;local requests=f.j.requests
 for _=1,12 do step(f,false) end
 check(f.j.requests==requests and f.b.writes==writes+1 and f.j.state=="pending" and f.s.flushing,"waiting departure repeated write or falsely verified release")
 f.budget.read=1000;drive(f)
 check(f.j.state=="preserved" and f.b.writes==writes+1,"departure did not verify unlocked exact readback")
 finish(f)
end)

test("ambiguous-departure-read-failure-and-callback-retry",function()
 for _,fault in {"lost-ack","before-write","read-failure","callback-retry"} do
  local f=typed(false,true);remoteChoice(f.b,f.clock);local untouched=nonProgress(f.b)
  if fault=="lost-ack" or fault=="before-write" then f.b:fail({op="update",key=f.s.pkey,afterWrite=fault=="lost-ack",message="timeout"})
  elseif fault=="read-failure" then f.b:fail({op="read",key=f.s.pkey,message="503 unavailable"})
  else
   local provider=f.b.update
   f.b.update=function(self,key,fn)
    return provider(self,key,function(old)
     fn(Json.copy(old));local q=Json.copy(old.payload);table.insert(q.notebook.opened,"callback_page")
     return fn(Envelope.make(Progress.SPEC,q,old.updatedAt,nil,{lock=Json.copy(old.lock)}))
    end)
   end
  end
  drive(f)
  check(f.j.state=="preserved" and f.b.data.P_46001.lock==nil and nonProgress(f.b)==untouched,"departure fault did not safely settle: "..fault.." "..tostring(f.j.problem))
  if fault=="callback-retry" then check(table.find(f.b.data.P_46001.payload.notebook.opened,"callback_page"),"replayed departure callback lost new storage data") end
  finish(f)
 end
end)

test("foreign-ownership-expiry-and-provider-cap-refuse-closed",function()
 for _,fault in {"foreign","deadline","cap","expired-queue"} do
  local f=typed(false,false,nil,if fault=="cap" then {maxRequests=1} else nil)
  if fault=="foreign" then f.b:poke(f.s.pkey,Envelope.withLock(f.b.data.P_46001,{session="foreign",beat=f.clock.now}))
  elseif fault=="deadline" then f.clock.now=f.j.deadline
  elseif fault=="expired-queue" then
   f.budget.read=0;step(f,false);step(f,false);check(f.g:inspect().queued==1,"departure request did not queue")
   f.clock.now=f.j.deadline;check(f.d:expire(f.j),"explicit expiry did not close queued departure")
  end
  local other=nonProgress(f.b);drive(f)
  check(f.j.state=="refused" and not f.j.result.progressPreserved and not f.j.result.leaseReleased and f.s.closed and not f.s.flushing and f.j.io==nil,"refused departure retained authority/handle")
  check(nonProgress(f.b)==other and f.j.requests<=f.d.maxRequests,"refused departure exceeded cap or changed other keys")
  finish(f)
 end
end)

test("suspended-committed-departure-expires-and-drains",function()
 local f=typed(false,true,function(b)
  local provider=b.update
  b.update=function(self,key,fn)
   local out=table.pack(provider(self,key,fn));if key=="P_46001" then coroutine.yield("departure-committed") end;return table.unpack(out,1,out.n)
  end
 end)
 step(f,false)
 local co=coroutine.create(function() return f.d:step(f.j) end);local ok,mark=coroutine.resume(co);assert(ok,mark)
 check(mark=="departure-committed" and f.s.busy and f.g:inspect().started==1,"departure did not retain suspended provider")
 local raw=Json.canonical(f.b.data.P_46001);f.clock.now=f.j.deadline;local debt=f.g:inspect()
 check(f.d:expire(f.j),"suspended departure did not expire")
 f.g:close(f.scope);check(f.g:open("46001","replacement")==nil,"new account epoch overlapped expired suspended departure")
 assert(coroutine.resume(co))
 check(f.j.state=="refused" and not f.j.result.progressPreserved and not f.j.result.leaseReleased and not f.s.busy and not f.d.busy,"expired provider result falsely verified release")
 check(Json.canonical(f.b.data.P_46001)==raw and f.s.closed,"expiry rolled back committed release or reopened intake")
 local replacement=assert(f.g:open("46001","replacement"));local after=f.g:inspect()
 check(after.read==debt.read and after.write==debt.write and after.started==0,"expired departure refunded debt")
 f.g:close(replacement)
end)

print("LIFECYCLE_DEPARTURE passed="..count.." failed=0 groups="..groups)
end
runLifecycleDepartureChecks()
end
