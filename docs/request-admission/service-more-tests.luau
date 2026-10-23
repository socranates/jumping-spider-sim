test("cancel-before-initial-transform-cannot-create-or-change-progress",function()
 local f=fixture({deferAdd=true});f.pauseInitialStage="before";local kept=Json.canonical(f.b.data);local once=false
 f.onSleep=function()
  if once then return end;once=true;f.server:removePlayer(f.player);f.releaseNative=true
 end
 f.server:addPlayer(f.player);f.onSleep=nil;closed(f)
 check(f.starts==2 and Json.canonical(f.b.data)==kept and f.owner.runtime.result.leaseReleased,"cancelled callback changed storage or failed fresh absence check")
end)
test("cancel-suspended-initial-rest-discards-it-and-cleans-owned-lock",function()
 local f=fixture({deferAdd=true});f.pauseInitialRest=true;local kept=nonP(f.b);local once=false
 f.onSleep=function()
  if once then return end;once=true
  check(f.native~=nil and f.owner.session.counters.requests==2 and f.starts==2,"initial rest was not pending/counted")
  f.server:removePlayer(f.player);f.releaseNative=true
 end
 f.server:addPlayer(f.player);f.onSleep=nil;closed(f)
 check(f.starts==5 and not f.owner.session.restLoaded.main and f.owner.runtime.result.leaseReleased and f.b.data.P_46001.lock==nil,"cancelled rest published or left an owned lock")
 check(nonP(f.b)==kept and #f.received==0,"cancelled rest changed another key or sent a late reply")
end)
test("closed-cleanup-waits-for-capacity-without-fake-attempts",function()
 local f=fixture({deferAdd=true});f.pauseInitialStage="after";local cancelled=false;local waits=0
 f.onSleep=function()
  if not cancelled then cancelled=true;f.server:removePlayer(f.player);f.releaseNative=true;f.budget.read=0;f.budget.write=0;return end
  local v=f.accounts.visits["46001"]
  if v.cleanup then
   waits+=1
   check(f.starts==1 and f.owner.session.counters.requests==1 and v.cleanup.requests==0 and v.cleanup.failures==0,"cleanup denial created provider attempts/failures")
   if waits==8 then f.budget.read=1000;f.budget.write=1000 end
  end
 end
 f.server:addPlayer(f.player);f.onSleep=nil;closed(f)
 check(waits==8 and f.starts==4 and f.owner.runtime.result.leaseReleased,"closed cleanup did not retain capacity wait")
end)
test("ambiguous-cleanup-write-probes-before-another-write",function()
 local f=fixture({deferAdd=true});f.pauseInitialStage="after";f.loseCleanupAck=true;local once=false
 f.onSleep=function() if not once then once=true;f.server:removePlayer(f.player);f.releaseNative=true end end
 f.server:addPlayer(f.player);f.onSleep=nil;closed(f)
 check(not f.loseCleanupAck and f.starts==4 and f.owner.runtime.result.leaseReleased and f.b.data.P_46001.lock==nil,"ambiguous cleanup retried blindly or lost exact release")
end)
test("foreign-lock-at-cleanup-is-never-released-or-overwritten",function()
 local f=fixture({deferAdd=true});f.pauseInitialStage="after";local once=false;local foreign
 f.onSleep=function()
  if once then return end;once=true;f.server:removePlayer(f.player)
  foreign=Envelope.withLock(f.b.data.P_46001,{session="another-server",beat=f.clock.now});f.b:poke("P_46001",foreign);f.releaseNative=true
 end
 f.server:addPlayer(f.player);f.onSleep=nil;closed(f)
 check(f.starts==2 and f.owner.runtime.result.leaseReleased and Json.canonical(f.b.data.P_46001)==Json.canonical(foreign),"cleanup touched a foreign lease")
end)
test("cleanup-deadline-retains-uncertain-lock-and-never-fakes-release",function()
 local f=fixture({deferAdd=true});f.pauseInitialStage="after";local once=false
 f.onSleep=function()
  if once then return end;once=true;f.server:removePlayer(f.player);f.budget.read=0;f.budget.write=0;f.releaseNative=true
 end
 local at=f.clock.now;f.server:addPlayer(f.player);f.onSleep=nil;closed(f)
 check(not f.owner.runtime.result.leaseReleased and f.starts==1 and f.b.data.P_46001.lock.session==f.owner.session.id,"deadline claimed release or changed uncertain storage")
 check(f.clock.now-at<=Rules.FLUSH_DEADLINE+.1,"initial cleanup exceeded its deadline")
 f.budget.read=1000;f.budget.write=1000;f.server:addPlayer(f.player)
 check(f.owner.session.state=="session" and not f.owner.session:isActive() and f.b.data.P_46001.lock.session~=f.owner.session.id,"rejoin stole an uncertain earlier lock")
 f.server:removePlayer(f.player);closed(f)
end)
test("removal-cancels-queued-normal-work-and-preserves-latest-progress",function()
 local f=fixture();local p=Json.copy(f.owner.session.progress);p.settings.MasterVolume=.32;assert(f.owner:setProgress(p))
 f.clock.now+=5;f.budget.write=0;f.server:step()
 check(f.owner.session._ordinaryContext and f.owner.session._ordinaryContext.phase=="admission","ordinary service did not retain queued work")
 f.budget.write=1000;local kept=nonP(f.b);f.server:removePlayer(f.player);closed(f)
 check(f.b.data.P_46001.payload.settings.MasterVolume==.32 and f.b.data.P_46001.lock==nil and nonP(f.b)==kept,"normal queued removal lost latest data or changed rests")
end)
test("another-actors-read-can-pass-a-blocked-write",function()
 local f=fixture();local other={UserId=46002,Name="other-actor"};f.server:addPlayer(other)
 local p=Json.copy(f.owner.session.progress);p.settings.MasterVolume=.39;assert(f.owner:setProgress(p));f.clock.now+=5;f.budget.write=0
 f.server:step();local a=f.owner.session.counters.requests;local b=f.extraOwner.session.counters.requests;local starts=f.starts
 f.extraOwner:enableOffers();assert(f.extraOwner:refreshOffer("main"));f.server:step()
 check(f.owner.session.counters.requests==a and f.extraOwner.session.counters.requests==b+1 and f.starts==starts+1,"blocked write stalled another account read or bypassed capacity")
 f.budget.write=1000;f.server:removePlayer(f.player);f.server:removePlayer(other);closed(f)
 check(f.b.data.P_46001.payload.settings.MasterVolume==.39,"cross-actor scheduling lost waiting progress")
end)
test("loaded-multi-actor-shutdown-closes-both-scopes",function()
 local f=fixture();local other={UserId=46002,Name="shutdown-other"};f.server:addPlayer(other)
 local p=Json.copy(f.owner.session.progress);p.settings.MasterVolume=.41;assert(f.owner:setProgress(p))
 p=Json.copy(f.extraOwner.session.progress);p.settings.MasterVolume=.61;assert(f.extraOwner:setProgress(p))
 f.server:shutdown();closed(f)
 check(f.accounts.closing and f.owner.session.closed and f.extraOwner.session.closed and f.b.data.P_46001.lock==nil and f.b.data.P_46002.lock==nil,"shutdown retained account authority")
 check(f.b.data.P_46001.payload.settings.MasterVolume==.41 and f.b.data.P_46002.payload.settings.MasterVolume==.61,"shutdown crossed or dropped account progress")
end)
test("failed-constructor-retains-complete-legacy-debt-for-rejoin",function()
 local options={deferAdd=true,initialFactoryFail=true,legacyHistory={199,199,199,199,199,199,199}}
 local f=fixture(options);check(f.server:addPlayer(f.player)==false,"failed constructor claimed success")
 local q=f.g:inspect();check(q.scopes==0 and q.read==7 and q.write==7 and (f.starts or 0)==0,"failed constructor erased or misclassified unknown debt")
 f.server:removePlayer(f.player);options.initialFactoryFail=false;f.server:addPlayer(f.player)
 q=f.g:inspect();accounted(f)
 check(f.seeds==1 and q.read==11 and q.write==8 and f.starts==4,"rejoin imported twice, reset debt or bypassed initial lane")
 f.server:removePlayer(f.player);closed(f)
end)
test("oversized-legacy-history-refuses-instead-of-truncating",function()
 local history={};for _=1,513 do table.insert(history,199) end
 local f=fixture({deferAdd=true,legacyHistory=history})
 check(f.server:addPlayer(f.player)==false and #f.owners==0 and (f.starts or 0)==0,"oversized history constructed an untyped owner")
 local q=f.g:inspect();check(q.scopes==0 and q.history==0,"oversized import silently adopted partial debt")
 f.server:removePlayer(f.player);closed(f)
end)
test("cancelling-history-lookup-does-not-forgive-known-debt",function()
 local f=fixture({deferAdd=true})
 f.historyHook=function() f.server:removePlayer(f.player);return {199,199,199} end
 f.server:addPlayer(f.player);f.historyHook=nil
 local q=f.g:inspect()
 check(q.scopes==0 and q.read==3 and q.write==3 and #f.owners==0 and (f.starts or 0)==0,"cancelled seed lost complete known debt or built an owner")
 closed(f)
end)
