test("removing-an-unstarted-load-task-does-not-start-storage",function()
 local f=fixture({deferAdd=true});f.deferSpawn=true;f.server:addPlayer(f.player)
 check(#f.tasks==1 and f.server.peers[f.player].installing==nil and not f.server.base.entries[f.player].loaded,"fixture did not return before deferred load")
 f.server:removePlayer(f.player)
 local ok,why=coroutine.resume(f.tasks[1]);assert(ok,why)
 check((f.starts or 0)==0 and f.owner.runtime.result.initialLoadCancelled and f.owner.runtime.result.leaseReleased,"removed deferred load started storage")
 closed(f)
end)
test("shutdown-cancels-a-deferred-load-after-addPlayer-returned",function()
 local f=fixture({deferAdd=true});f.deferSpawn=true;f.server:addPlayer(f.player)
 f.onSleep=function()
  if coroutine.status(f.tasks[1])=="suspended" then local ok,why=coroutine.resume(f.tasks[1]);assert(ok,why) end
 end
 f.server:shutdown();f.onSleep=nil;closed(f)
 check((f.starts or 0)==0 and f.owner.runtime.result.leaseReleased and f.owner.session.closed,"deferred shutdown load acquired a record")
end)
test("one-service-step-task-per-actor-can-be-queued",function()
 local f=fixture();local other={UserId=46002,Name="queued-other"};f.server:addPlayer(other)
 f.deferSpawn=true;local starts=f.starts
 for _=1,100 do f.server:step() end
 check(#f.tasks==2 and f.starts==starts,"service queued duplicate per-actor workers")
 for _,co in f.tasks do local ok,why=coroutine.resume(co);assert(ok,why);check(coroutine.status(co)=="dead","quiet service worker retained a coroutine") end
 f.tasks={};f.server:step();check(#f.tasks==2,"completed worker did not release its dispatch slot")
 for _,co in f.tasks do local ok,why=coroutine.resume(co);assert(ok,why) end
 f.deferSpawn=false;f.server:removePlayer(f.player);f.server:removePlayer(other);closed(f)
end)
test("pending-native-ordinary-work-does-not-spawn-redundant-workers",function()
 local f=fixture();local p=Json.copy(f.owner.session.progress);p.settings.MasterVolume=.22;assert(f.owner:setProgress(p))
 f.pauseInitialStage="after";f.clock.now+=5;f.server:step()
 check(f.native and f.owner.session.busy and f.g:inspect().started==1,"normal service did not suspend actual provider")
 local count=f.spawnCount;local starts=f.starts
 for _=1,100 do f.server:step() end
 check(f.spawnCount==count and f.starts==starts,"pending native work spawned redundant service workers")
 f.releaseNative=true;f.accounts.sleep(.025)
 check(not f.owner.session.busy and f.g:inspect().started==0,"mock engine did not drain the normal provider")
 f.server:removePlayer(f.player);closed(f)
 check(f.b.data.P_46001.payload.settings.MasterVolume==.22,"native service drain lost latest progress")
end)
test("initial-task-launch-failure-closes-scope-without-departure-leak",function()
 local f=fixture({deferAdd=true});f.failSpawn=true
 check(f.server:addPlayer(f.player)==false,"failed initial task launch claimed success")
 check((f.starts or 0)==0 and f.server.base.entries[f.player]==nil and f.owner.session.closed,"failed initial task launch left owner authority or storage")
 check(f.server.base.departing==0 and f.g:inspect().scopes==0,"failed initial task launch leaked departing count/scope")
 f.failSpawn=false;f.server:removePlayer(f.player);closed(f)
end)
test("step-launch-failure-releases-only-its-actor-dispatch-slot",function()
 local f=fixture();local entry=f.server.base.entries[f.player];f.failSpawn=true
 f.server:step();check(entry.working==false and not f.owner.session.closed,"step launch failure stranded its actor slot or closed a good owner")
 f.failSpawn=false;f.server:step();check(entry.working==false,"step dispatch did not recover after executor failure")
 f.server:removePlayer(f.player);closed(f)
end)
test("post-constructor-startup-wrapper-is-refused-before-registration",function()
 local f=fixture({deferAdd=true})
 f.configureOwner=function(owner)
  local begin=owner.session.sched.begin
  owner.session.sched.begin=function(...) return begin(...) end
 end
 check(f.server:addPlayer(f.player)==false and f.server.base.entries[f.player]==nil,"competing startup wrapper was registered")
 check((f.starts or 0)==0 and f.owner.session.closed and f.g:inspect().scopes==0,"competing wrapper retained authority or started storage")
 f.server:removePlayer(f.player);closed(f)
end)
