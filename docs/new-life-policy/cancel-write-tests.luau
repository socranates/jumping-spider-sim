-- Direct cancellation while the raw retirement provider is actually suspended
-- must revoke the exact callback fence. Merely setting job.state is insufficient.
do
 local f=fixture();local policy,job=start(f,"main")
 drivePolicy(f,job,function() return job.phase=="write" and f.owner.session.sched:budgetOk(f.clock.now) end)
 local kept=nonP(f.b);f.pauseUpdateKey="R_46001_main"
 local co=coroutine.create(function() f.tick() end);local okay,why=coroutine.resume(co);assert(okay,why)
 check(why=="new-write-paused" and policy.busy and f.owner.session.busy,"retirement provider did not actually suspend")
 check(policy:cancel(job),"in-flight New cancellation refused")
 okay,why=coroutine.resume(co);assert(okay,why)
 check(coroutine.status(co)=="dead" and job.state=="refused" and nonP(f.b)==kept,"cancelled in-flight retirement still changed the selected rest")
 local old=f.owner;local epoch=f.client.bound.epoch
 check(f.client:requestReplacement(),"cancelled write lost its acknowledged exit")
 f.drive(function() return f.client.transition==nil and f.client.bound.epoch~=epoch end)
 check(old:replacementClosed() and nonP(f.b)==kept,"cancelled write could not safely close the old owner")
 f.server:removePlayer(f.player)
end
