test("initial-admission-expiry-is-retryable-without-fake-provider-failure",function()
 local f=fixture({deferAdd=true});f.budget.read=0;f.budget.write=0;local at=f.clock.now
 f.server:addPlayer(f.player)
 print("ACCOUNT_ADMISSION_TIMEOUT",Json.canonical({state=f.owner.session.state,canRetry=f.owner.session.canRetry,elapsed=f.clock.now-at,starts=f.starts or 0,closed=f.owner.session.closed}))
 check(f.owner.session.state=="session" and f.owner.session.canRetry==true,"admission timeout left initial owner loading without retry")
 check((f.starts or 0)==0 and f.owner.session.counters.requests==0 and f.clock.now-at<=180.1,"admission timeout invented a provider attempt or missed its bound")
 f.budget.read=1000;f.budget.write=1000;f.clock.now+=Rules.RETRY_LOAD
 for _=1,8 do f.server:step();f.clock.now+=1 end
 check(f.owner.session:isActive() and f.starts==4 and f.owner.session.counters.requests==4,"admission expiry retry failed to load exact records on its existing lane")
 f.server:removePlayer(f.player);closed(f)
end)
