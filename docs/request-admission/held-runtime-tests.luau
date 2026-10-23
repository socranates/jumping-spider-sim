local Gate=__heldGate
local groups=0
local function test(name,fn) local before=count;fn();groups+=1;print("HELD_RUNTIME_CASE",name,count-before) end
test("actual-Runtime-cancel-holds-maintains-and-departs-through-one-lane",function()
 local b,clock,rt,s=fixture(false)
 assert(rt:discover("main"))
 for _=1,1400 do if rt.phase~="discovering" then break end;rt:step();clock.now+=1 end
 assert(rt.phase=="offered",rt.problem)
 local budget={read=1000,write=1000}
 local g=Gate.new({now=s.now,available=function() return budget end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 local scope=assert(g:open("46001",s.id));assert(g:importLegacy(scope,s.sched.started));local lane={gate=g,scope=scope}
 rt.pipeline.options.admission=lane;rt.recovery.lifecycleAdmission=lane
 if rt.lease then rt.lease:cancel() end
 assert(rt:accept("main",1,rt.discovery.offer.id));assert(rt:cancelRecovery())
 rt:step();check(rt.phase=="held" and rt.idle~=nil and rt.idle.admission==lane,"Runtime did not bind held maintenance lane")
 local original=Json.canonical({b.data.R_46001_main,b.data.R_46001_free});local global,provider=s.counters.requests,b.requests
 for _=1,100 do
  local before=b.requests;rt:step()
  check(b.requests-before<=1 and b.requests-provider==s.counters.requests-global,"Runtime held route escaped provider accounting")
  check(rt.phase=="held" and rt.idleJob.state=="pending" and not s.busy and not rt.busy,"Runtime held route stopped/leaked busy state")
  clock.now+=1
 end
 check(clock.now-b.data.P_46001.lock.beat<31 and s.intents.requests.main.credential==nil,"Runtime held route expired/granted entry")
 local idle=rt.idle;rt:flush()
 check(rt.phase=="closed" and s.closed and rt.result.progressPreserved and rt.result.leaseReleased and idle.current.state=="stopped" and idle.current.io==nil,"Runtime held departure did not close/clean")
 check(Json.canonical({b.data.R_46001_main,b.data.R_46001_free})==original,"Runtime held departure changed rest slots")
 g:close(scope);local q=g:inspect();check(q.queued==0 and q.started==0,"Runtime held route retained tickets")
end)
print("HELD_RUNTIME passed="..count.." failed=0 groups="..groups)
end
runHeldRuntimeChecks()
end
