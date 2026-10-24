-- Real client and storage pipeline on shim services. Synthetic hatch fixtures;
-- this does not establish native rendering or real DataStore durability.
local Layout=require("../src/Shared/Habitat/WindowsillLayout")
local Mating=require("../src/Shared/Life/Mating")
local Store=require("../src/Shared/Persistence/CheckpointStore")
local Json=require("../src/Shared/Persistence/Json")
local SaveRest=require("../src/Shared/Persistence/SaveRest")
local awaitRest=require("./studio/AwaitRest")
local awaitReturn=require("./studio/AwaitReturn")
local pieces={}
for _,p in Layout.PIECES do table.insert(pieces,{name=p.id,lo=p.lo,hi=p.hi,profile=p.profile}) end
BoxWorld.folder("Windowsill",pieces)
assert(pcall(function() require("../src/Client/SpiderClient.client") end),"client failed to load")
local d=assert(ClientStubs.driver)
local frame=ClientStubs.renderSteps.SpiderSim
for _=1,30 do frame(1/60) end
local passed,failed=0,0
local function check(v,why) if v then passed+=1 else failed+=1;print("FAIL GENERATION_CHECKPOINT "..why) end end
local function pump() frame(0) end
local clock=0
d.saveState.rest.cfg.workOptions={budget=.001,maxSeconds=1000,now=function() clock+=.0001;return clock end}
d.saveState.localRestore.cfg.workOptions=d.saveState.rest.cfg.workOptions
local home=Vector3.new(-25.5,.31,6)
local function parent()
 assert(d.fresh("main",false,nil))
 d.place(home);for _=1,6 do frame(1/60) end
 local life=d.life
 life.clock.day,life.clock.hour=6,7
 life.growth.stage=life.growth:adultStage();d.needs.energy=.8
 life.mating=Mating.normalize({stage="guarding",sac_day=4,guard_day=2,mates=1})
 local kept=life:makeCheckpoint();assert(awaitRest(kept,pump).ok,"parent rest fixture refused")
 local source=d.currentStore()
 local before=assert(Json.canonical(source.store.data))
 life.mating=Mating.normalize({stage="hatched",sac_day=4,guard_day=2,hatch_day=6,hatch_hour=7,brood=9,mates=1})
 life.resting=true;life.asleep=false;life.restSeconds=1
 for _=1,3 do frame(1/60) end
 assert(d.mateLegs.phase=="card" and d.caughtPanel:isShowing(),"hatch card fixture missing")
 d.caughtPanel:update(10)
 return source,before
end
local function carry()
 assert(d.caughtPanel:choose("Carry"),"Carry fixture refused")
 assert(d.saveState.birth and d.saveState.birth.result.pending,"child baseline did not start")
 return d.saveState.birth.result,d.life.growth.lifeSeed
end

local source,before=parent()
-- The parent can reach the ending with food in its jaws. Conserved nutrition
-- stays in the world; it is never assigned to the newborn or paid twice.
local feeding=d.prey.feeding
local fly=d.prey.flies[1]
fly.state="HELD";fly.captureKey="generation-fixture";fly.nutrition=.12
feeding.held=fly;feeding.feeding=true;feeding.struggling=true;feeding.swallow=.4
local granted,finished=feeding.granted,feeding.mealsFinished
local taken=feeding.taken
local child,seed=carry()
check(feeding.held==nil and not feeding.feeding and not feeding.struggling and feeding.swallow==0,"newborn inherits neither prey nor feeding/struggle")
check(fly.state~="HELD" and fly.nutrition==.12 and feeding.granted==granted and feeding.taken==taken and feeding.mealsFinished==finished,"release conserves unfinished nutrition and awards no meal")
check(d.life.mealsBase==finished and d.life.growth.fedSinceMoult==0 and not d.life.growth.ready,"newborn has no parent's growth credit")
check(not d.life.resting and not d.life.asleep and d.life.restSeconds==0,"newborn begins awake and free to move")
check(d.currentStore()==source and Json.canonical(source.store.data)==before,"private baseline leaves parent and backup intact while pending")
d.returnToCheckpoint();local waiting=d.saveState.localReturnResult
check(waiting.pending and d.saveState.birth.returnRequested~=nil,"Back waits behind generation preparation")
d.life.generation=77
check(awaitReturn(d,pump)==waiting and waiting.ok and not waiting.pending,"queued Back really commits one return")
check(d.life.generation==1 and d.life.mating.stage=="none" and d.life.growth.lifeSeed==seed,"return restores exact newborn instead of hatching again")
local best=d.currentStore():loadBest()
check(best.ok and best.record.checkpoint_origin=="generation_start" and #SaveRest.check("main",best.record)==0,"generation record accepted by server validator")
check(Json.canonical(d.currentStore().store.data["checkpoint.bak"])==Json.canonical(source.store.data.checkpoint),"exact parent checkpoint remains the backup")
local generationStore=d.currentStore()
for _=1,5 do pump() end
check(d.currentStore()==generationStore and d.saveState.birth==nil and d.saveState.birthReturn==nil,"generation baseline commits once")

-- New-life replacement revokes the worker and the queued return together.
source,before=parent();child=carry();d.returnToCheckpoint();waiting=d.saveState.localReturnResult
assert(d.fresh("main",false,nil));local freshStore=d.currentStore()
for _=1,30 do pump() end
check(child.cancelled and waiting.cancelled and not waiting.pending,"new life finalizes both pending tokens")
check(d.life.generation==nil and d.currentStore()==freshStore and d.saveState.birth==nil,"late worker cannot replace a newer life")
check(Json.canonical(source.store.data)==before,"cancelled work leaves original parent bytes untouched")

-- Faulted local storage keeps the living child and refuses the unsafe Back.
source,before=parent()
local originalFork=Store.forkMemory
local oldWarn=warn;local warnings={};getfenv().warn=function(v) table.insert(warnings,tostring(v)) end
Store.forkMemory=function(self) local fork=originalFork(self);fork.store.failNext=1;return fork end
child,seed=carry();d.returnToCheckpoint();waiting=d.saveState.localReturnResult
awaitRest(child,pump);Store.forkMemory=originalFork
check(not child.ok and not child.pending and not waiting.pending and not waiting.ok,"save failure finishes baseline and queued Back as failures")
check(d.life.generation==1 and d.life.growth.lifeSeed==seed and d.saveState.birth.failed,"failed save keeps the child alive")
check(d.currentStore()==source and Json.canonical(source.store.data)==before,"failed baseline never mutates parent/backup bytes")
check(not d.saveState.beginLocalReturn(nil,"reset") and d.life.mating.stage=="none","Back after failure cannot reload parent")
check(d.menu.line.Text~="Returning to the last rest" and string.find(d.menu.summary.Text,"The new spider could not be kept",1,true)~=nil,"failed queued Back replaces the preparation screen with readable failure feedback")
-- An ordinary later rest provides recovery without another generation grant.
local recover=d.life:makeCheckpoint();assert(awaitRest(recover,pump).ok)
check(d.saveState.birth==nil and d.currentStore():loadBest().record.checkpoint_origin==nil,"successful later rest clears failed generation guard")
check(d.saveState.restoreError==nil,"successful child rest clears the obsolete failure notice")
d.returnToCheckpoint();check(awaitReturn(d,pump).ok and d.life.generation==1,"later child rest can be returned to normally")
getfenv().warn=oldWarn
check(#warnings==1 and string.find(warnings[1],"last rest preparation failed",1,true)~=nil,"only injected storage failure warns")

-- Revision revocation is cancellation, not an exception: it must not strand Back.
source,before=parent();child,seed=carry();d.returnToCheckpoint();waiting=d.saveState.localReturnResult
source.store:RemoveAsync("absent");pump()
check(child.cancelled and not waiting.pending and not waiting.ok and d.saveState.birth.failed,"revision cancellation does not leave a pending return forever")
check(d.life.generation==1 and d.life.growth.lifeSeed==seed and not d.saveState.beginLocalReturn(nil,"reset"),"cancelled baseline still guards against parent replay")
check(d.menu.line.Text~="Returning to the last rest" and string.find(d.menu.summary.Text,"The new spider could not be kept",1,true)~=nil,"revision cancellation also removes the stale preparation screen")

-- Superseding generation preparation with an ordinary rest may satisfy Back;
-- the old worker cannot overwrite the newer child snapshot.
source,before=parent();child,seed=carry();d.returnToCheckpoint();waiting=d.saveState.localReturnResult
local replacement=d.life:makeCheckpoint();assert(awaitRest(replacement,pump).ok)
check(child.cancelled and awaitReturn(d,pump).ok and not waiting.pending,"successful replacement child checkpoint fulfils queued Back")
check(d.life.generation==1 and d.life.growth.lifeSeed==seed and d.saveState.birth==nil,"replacement never restores parent or creates another child")

source,before=parent();child,seed=carry();d.returnToCheckpoint();waiting=d.saveState.localReturnResult
check(d.saveState.birthReturning() and d.menu:isShowing(),"queued Back exposes the ordinary cancellable preparation screen")
d.saveState.cancelLocalReturn(true)
check(waiting.cancelled and not waiting.pending and not d.saveState.birthReturning() and not d.menu:isShowing(),"Cancel resumes the child without cancelling its baseline")
assert(awaitRest(child,pump).ok)
d.life.generation=7
for _=1,5 do pump() end
check(d.life.generation==7 and d.life.growth.lifeSeed==seed,"cancelled Back is never replayed after baseline completion")

print(`GENERATION_CHECKPOINT passed={passed} failed={failed}`)
assert(failed==0,"generation checkpoint failures")
