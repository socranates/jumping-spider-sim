test("polled-load-admission-expiry-remains-retryable",function()
 local f=fixture({deferAdd=true});f.budget.read=0;f.budget.write=0
 f.server:addPlayer(f.player)
 check(f.owner.session.state=="session" and f.owner.session.canRetry,"initial timeout did not become retryable")
 f.clock.now+=Rules.RETRY_LOAD
 for _=1,121 do f.server:step();f.clock.now+=1 end
 print("ACCOUNT_RETRY_TIMEOUT",Json.canonical({state=f.owner.session.state,canRetry=f.owner.session.canRetry,starts=f.starts or 0}))
 check(f.owner.session.state=="session" and f.owner.session.canRetry,"polled admission timeout left retry loading without retry")
 f.clock.now+=Rules.RETRY_LOAD;f.server:step();f.clock.now+=181;f.server:step()
 check(f.owner.session.state=="session" and f.owner.session.canRetry and (f.starts or 0)==0,"cancelled polled load context stranded loading or spent storage")
 f.budget.read=1000;f.budget.write=1000;f.clock.now+=Rules.RETRY_LOAD
 for _=1,8 do f.server:step();f.clock.now+=1 end
 check(f.owner.session:isActive() and f.starts==4,"repeated outage did not recover on the same account lane")
 f.server:removePlayer(f.player);closed(f)
end)
