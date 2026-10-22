-- Real client loop on shim services; not native rendering/network evidence.
local Layout=require("../src/Shared/Habitat/WindowsillLayout")
local Json=require("../src/Shared/Persistence/Json")
local Store=require("../src/Shared/Persistence/CheckpointStore")
local awaitRest=require("./studio/AwaitRest")
local pieces={}
for _,p in Layout.PIECES do table.insert(pieces,{name=p.id,lo=p.lo,hi=p.hi,profile=p.profile}) end
BoxWorld.folder("Windowsill",pieces)
local loaded=require("../src/Client/SpiderClient.client")
local d=ClientStubs.driver
local frame=ClientStubs.renderSteps.SpiderSim
for _=1,30 do frame(1/60) end
local passed,failed=0,0
local function check(ok,why) if ok then passed+=1 else failed+=1;print("FAIL LOCAL_REST_CLIENT "..why) end end
local clock=0
d.saveState.rest.cfg.workOptions={budget=.001,maxSeconds=1000,now=function() clock+=.0001;return clock end}
local function ready()
 assert(d.fresh("main",false,nil))
 d.place(Vector3.new(-25.5,.31,6));for _=1,6 do frame(1/60) end
 d.life.clock.hour=12;d.needs.energy=.9
end
local function rest()
 local t=d.life.save();assert(t.pending,"fixture rest refused: "..t.message);return t
end
local function finish(t) return awaitRest(t,function() frame(1/60) end) end
ready()
local source=d.currentStore();local before=assert(Json.canonical(source.store.data))
local count=d.life.checkpoints
local tick,elapsed=d.prey.tick,d.life.elapsed
local first=rest()
check(not first.ok and d.life.checkpoints==count,"capture does not announce success")
frame(1/60)
check(first.pending and d.saveState.rest.job~=nil,"large private preparation spans actual frames")
check(d.prey.tick>tick and d.life.elapsed>elapsed,"simulation advances while local storage prepares")
check(d.currentStore()==source and Json.canonical(source.store.data)==before,"pending work changes neither visible store nor old data")
check(finish(first).ok and d.currentStore()~=source and d.life.checkpoints==count+1,"completed rest publishes once")
local kept=d.currentStore();local record=kept:loadBest()
check(record.ok,"published rest passes full checkpoint validation")
local capturedTick,capturedElapsed
for _,entry in record.record.world.objects[record.record.world.roots.prey["$o"]].e do if entry[1]=="tick" then capturedTick=entry[2] end end
for _,entry in record.record.world.objects[record.record.world.roots.life["$o"]].e do if entry[1]=="elapsed" then capturedElapsed=entry[2] end end
check(capturedTick==tick and capturedElapsed==elapsed and d.prey.tick>tick,"committed checkpoint retains capture-time state while live simulation advances")
local keptText=assert(Json.canonical(kept.store.data.checkpoint))
local second=rest();frame(1/60);local latest=rest()
check(second.cancelled and not second.pending and d.currentStore()==kept,"superseded preparation cannot publish")
assert(finish(latest).ok)
check(Json.canonical(d.currentStore().store.data["checkpoint.bak"])==keptText,"replacement retains previous exact rest as backup")
check(d.life.checkpoints==count+2,"superseded job never increments rest count")
local old=d.currentStore();local revoked=rest();old.store:RemoveAsync("absent");frame(1/60)
check(revoked.cancelled and d.currentStore()==old,"source revision change cancels obsolete private preparation")
local newLife=rest();assert(d.fresh("main",false,nil));frame(1/60)
check(newLife.cancelled and d.life._checkpointPending==nil,"world replacement finalizes pending token")
-- A storage failure must leave the previous committed store and its backups intact.
d.place(Vector3.new(-25.5,.31,6));for _=1,6 do frame(1/60) end;d.life.clock.hour=12
local originalFork=Store.forkMemory
local previousWarn=warn;local warnings={};getfenv().warn=function(message) table.insert(warnings,message) end
Store.forkMemory=function(self) local fork=originalFork(self);fork.store.failNext=1;return fork end
local stable=d.currentStore();local stableText=assert(Json.canonical(stable.store.data));count=d.life.checkpoints
local bad=rest();finish(bad);Store.forkMemory=originalFork
check(not bad.ok and not bad.pending and not bad.cancelled,"failed preparation reports a final failure")
check(d.currentStore()==stable and Json.canonical(stable.store.data)==stableText and d.life.checkpoints==count,"failed preparation preserves current and backup bytes")
-- Network failure disables persistence for the visit, not local last-rest storage.
d.saveState.fail("synthetic transport failure")
local offline=rest();check(d.saveState.broken and offline.pending,"local preparation starts after transport failure")
check(finish(offline).ok and d.currentStore()~=stable,"local rest still finishes when network path is broken")
getfenv().warn=previousWarn
check(#warnings==2 and string.find(warnings[1],"last rest preparation failed",1,true) and string.find(warnings[2],"saving is off",1,true),"only the two injected failures warn")
print(`LOCAL_REST_CLIENT passed={passed} failed={failed}`)
assert(failed==0,"local rest client failures")
