local groups=0
local function test(name,fn) local before=count;fn();groups+=1;print("ACCOUNT_SERVICE_CASE",name,count-before) end
local function accounted(f)
 local total=0;for _,owner in f.owners do total+=owner.session.counters.requests end
 check(total==(f.starts or 0),"service/provider dispatch totals differ")
end
local function closed(f)
 accounted(f);local q=f.g:inspect()
 check(q.scopes==0 and q.queued==0 and q.started==0 and f.server.base.departing==0,"service retained scope/provider/departure")
end
test("initial-owner-and-normal-removal-use-one-account-lane",function()
 local f=fixture();local lane=f.owner.session.ordinaryAdmission
 check(lane and f.accounts.visits["46001"].lane==lane and f.seeds==1,"service did not seed/bind before initial load")
 check(f.owner.session.state=="active" and f.b.data.P_46001.lock.session==f.owner.session.id,"initial service owner did not acquire its own lease")
 accounted(f);f.server:removePlayer(f.player);closed(f)
 check(f.b.data.P_46001.lock==nil and f.owner.session.closed,"normal service removal did not release")
end)
test("cancel-capacity-wait-before-any-storage-start",function()
 local f=fixture({deferAdd=true});f.budget.read=0;f.budget.write=0;local once=false
 f.onSleep=function()
  if once then return end;once=true
  check(f.owner.session.counters.requests==0 and (f.starts or 0)==0,"initial wait consumed storage")
  f.server:removePlayer(f.player)
 end
 f.server:addPlayer(f.player);f.onSleep=nil;closed(f)
 check(once and f.owner.session.closed and not f.owner.session:isActive() and f.server.base.entries[f.player]==nil,"cancelled initial wait revived owner")
 check(f.owner.runtime.result.initialLoadCancelled and f.owner.runtime.result.leaseReleased and (f.starts or 0)==0,"empty initial cancellation did not close without I/O")
end)
test("cancel-after-initial-commit-drains-and-releases-only-the-lock",function()
 local f=fixture({deferAdd=true});f.pauseInitialStage="after";local once=false;local original=Json.copy(f.b.data.P_46001);local kept=nonP(f.b)
 f.onSleep=function()
  if once then return end;once=true
  check(f.native~=nil and f.g:inspect().started==1 and f.owner.session.counters.requests==1,"actual committed load was not pending/counted")
  f.server:removePlayer(f.player);f.releaseNative=true
 end
 f.server:addPlayer(f.player);f.onSleep=nil;closed(f)
 local v=f.accounts.visits["46001"]
 print("ACCOUNT_INITIAL_CLEANUP",Json.canonical({problem=v.problem,result=f.owner.runtime.result,phase=v.cleanup and v.cleanup.phase,requests=v.cleanup and v.cleanup.requests,
  lock=f.b.data.P_46001.lock,logs=f.logs,started=f.starts,context=f.owner.session._ordinaryContext and f.owner.session._ordinaryContext.phase}))
 check(f.owner.runtime.result.leaseReleased and f.b.data.P_46001.lock==nil and not f.owner.session.lockHeld,"closed initial cleanup did not verify release")
 check(Json.canonical(f.b.data.P_46001.payload)==Json.canonical(original.payload) and f.b.data.P_46001.checksum==original.checksum and nonP(f.b)==kept,"closed cleanup changed payload/checksum or another key")
 check(f.starts==4 and #f.received==0,"cancelled committed load sent output or miscounted cleanup")
end)
print("ACCOUNT_SERVICE passed="..count.." failed=0 groups="..groups)
end
runAccountServiceChecks()
end
