-- Real client/local return loop on shim services; no native/network proof.
local Layout=require("../src/Shared/Habitat/WindowsillLayout")
local Json=require("../src/Shared/Persistence/Json")
local Checkpoint=require("../src/Shared/Persistence/Checkpoint")
local awaitRest=require("./studio/AwaitRest")
local awaitReturn=require("./studio/AwaitReturn")
local pieces={};for _,p in Layout.PIECES do table.insert(pieces,{name=p.id,lo=p.lo,hi=p.hi,profile=p.profile}) end
BoxWorld.folder("Windowsill",pieces)
local loaded=require("../src/Client/SpiderClient.client")
local d=ClientStubs.driver;local frame=ClientStubs.renderSteps.SpiderSim
for _=1,30 do frame(1/60) end
local clock=0
local options={budget=.001,maxSeconds=1000,now=function() clock+=.0001;return clock end}
d.saveState.rest.cfg.workOptions=options;d.saveState.localRestore.cfg.workOptions=options
local passed,failed=0,0
local function check(ok,why) if ok then passed+=1 else failed+=1;print("FAIL LOCAL_RETURN "..why) end end
local function finish() return awaitReturn(d,function() frame(0) end) end
local function fresh(mode)
 assert(d.fresh(mode or "main",false,nil));d.place(Vector3.new(-25.5,.31,6))
 for _=1,6 do frame(1/60) end;d.life.clock.hour=12;d.needs.energy=.8
end
local function save()
 local t=d.life.save();assert(awaitRest(t,function() frame(0) end).ok,"fixture rest failed")
 return assert(d.currentStore():loadBest().record)
end
fresh();local record=save();local originalStore=d.currentStore();local storeText=assert(Json.canonical(originalStore.store.data))
d.place(Vector3.new(-5,.31,0));d.life.clock.hour=14
local point=d.motor.pos;local hour=d.life.clock.hour
local canonical=Json.canonical;local calls=0
Json.canonical=function(...) calls+=1;return canonical(...) end
d.openMenu();assert(d.menu:choose("Continue"));Json.canonical=canonical
local first=d.saveState.localReturnResult
check(calls==0 and first.pending and d.saveState.localRestore.job~=nil,"local Continue queues without synchronous encoding")
check(d.currentStore()==originalStore and d.motor.pos==point and d.life.clock.hour==hour,"pending return preserves current world/store")
frame(1/60)
check(first.pending and d.motor.pos==point and d.life.clock.hour==hour,"preparing menu pauses simulation across frames")
assert(d.menu:choose("CancelRestore"))
check(first.cancelled and d.saveState.localRestore.job==nil and d.motor.pos==point,"cancel retains running spider")
check(Json.canonical(originalStore.store.data)==storeText,"cancel preserves exact current/backup bytes")
assert(d.menu:choose("Continue"));check(finish().ok,"local Continue finishes")
check(math.abs(d.life.clock.hour-12)<.001,"completed return restores captured clock")
check(d.life.resting==false and d.currentStore()==originalStore and not d.menu:isShowing(),"direct callback rest restores state without replacing store")
check(Json.canonical(originalStore.store.data)==storeText,"successful local return makes no store writes")
-- Backspace uses the same queued path when a rest exists.
d.place(point);local reset=ClientStubs.actions.SpiderReset
reset("",Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.Backspace,UserInputType=Enum.UserInputType.Keyboard})
frame(0);reset("",Enum.UserInputState.End,{KeyCode=Enum.KeyCode.Backspace,UserInputType=Enum.UserInputType.Keyboard})
check(d.saveState.localRestore.job~=nil and d.motor.pos==point,"Backspace starts a private return")
assert(finish().ok);check((d.motor.pos-point).Magnitude>1,"Backspace commits saved position")
-- Store mutations or a new life invalidate an obsolete return, rather than rebinding it.
d.place(point);d.openMenu();assert(d.menu:choose("Continue"));local stale=d.saveState.localReturnResult
originalStore.store:RemoveAsync("absent");frame(0)
check(stale.cancelled and d.motor.pos==point and d.menu:isShowing(),"mutation fencing keeps spider and asks for a new choice")
d.openMenu();assert(d.menu:choose("Continue"));local obsolete=d.saveState.localReturnResult
assert(d.fresh("main",false,nil));frame(0)
check(obsolete.cancelled and d.saveState.localRestore.job==nil,"new life cancels old return")
-- A failed decoder cannot discard the current live world or any local data.
fresh();save();d.place(point);d.openMenu();local source=d.currentStore();local bytes=assert(Json.canonical(source.store.data))
local prepare=Checkpoint.prepare;Checkpoint.prepare=function() return nil,{"synthetic decoder failure"} end
assert(d.menu:choose("Continue"));local bad=finish();Checkpoint.prepare=prepare
check(not bad.ok and not bad.pending and d.motor.pos==point and d.currentStore()==source,"decoder failure preserves world/store")
check(Json.canonical(source.store.data)==bytes,"decoder failure leaves all store bytes intact")
-- Cancelling Back on the end screen returns to that end screen, with no revival.
d.endLife("starved");check(d.session.ended and d.caughtPanel:isShowing(),"fixture ended")
for _=1,300 do frame(1/60) end
assert(d.caughtPanel:choose("Back"));local endToken=d.saveState.localReturnResult
check(endToken.pending and d.session.ended and d.menu:isShowing(),"end-screen Back waits without reviving")
assert(d.menu:choose("CancelRestore"))
check(endToken.cancelled and d.session.ended and d.caughtPanel:isShowing() and not d.menu:isShowing(),"end cancellation restores original end screen")
assert(d.caughtPanel:choose("Back"));assert(finish().ok)
check(not d.session.ended and not d.caughtPanel:isShowing() and not d.menu:isShowing(),"end-screen Back revives only at validated commit")
-- Checksum-invalid current data can use a valid backup, without rewriting either.
d.life.clock.hour=13;save();source=d.currentStore()
local healthy=source.store:GetAsync("checkpoint")
local broken=source.store:GetAsync("checkpoint");broken.checksum="cut-short";source.store:SetAsync("checkpoint",broken)
bytes=assert(Json.canonical(source.store.data));d.place(point);d.openMenu()
local decodes=0;prepare=Checkpoint.prepare
Checkpoint.prepare=function(...) decodes+=1;return prepare(...) end
assert(d.menu:choose("Continue"));assert(finish().ok);Checkpoint.prepare=prepare
check(math.abs(d.life.clock.hour-12)<.001 and decodes==1,"backup is selected and decoded once")
check(Json.canonical(source.store.data)==bytes,"backup recovery preserves corrupt current and valid backup bytes")
-- A checksum-valid newer schema is protected even when an older backup exists.
local newer=Json.copy(healthy);newer.checkpoint.schema_version=Checkpoint.SCHEMA_VERSION+1
newer.checksum=Json.checksum(assert(Json.canonical(newer.checkpoint)));source.store:SetAsync("checkpoint",newer)
bytes=assert(Json.canonical(source.store.data));d.place(point);d.openMenu();assert(d.menu:choose("Continue"));local protected=finish()
check(not protected.ok and d.motor.pos==point,"newer current schema is refused rather than silently falling back")
check(Json.canonical(source.store.data)==bytes,"newer current and its backup stay byte-identical")
source.store:SetAsync("checkpoint",healthy)
-- Selecting a different local slot leaves the old slot active until commit.
fresh("free");d.needs.energy=.3;save();local freeStore=d.currentStore()
d.openMenu();assert(d.menu:choose("Continue"))
check(d.currentStore()==freeStore and d.session.mode=="free","cross-slot preparation keeps current Free play world")
assert(finish().ok)
check(d.currentStore()==source and d.session.mode=="main" and not d.needs.gentle,"local main slot restores its own rules")
d.openMenu();assert(d.menu:choose("Free"));assert(finish().ok)
check(d.currentStore()==freeStore and d.session.mode=="free" and d.needs.gentle and d.needs.energy<.4,"local Free play restores independent reserves/rules")
d.openMenu();assert(d.menu:choose("Continue"));assert(finish().ok)
-- Local returns remain useful when persistent saving has failed for this visit.
local previousWarn=warn;getfenv().warn=function() end;d.saveState.fail("synthetic transport failure");getfenv().warn=previousWarn
d.place(point);d.openMenu();assert(d.menu:choose("Continue"));assert(finish().ok)
check(d.saveState.broken and (d.motor.pos-point).Magnitude>1,"local return works with broken network saving")
-- Recovery's real adoption path uses the same preparation/commit as an ordinary
-- return, but must retain a separate hold until a matching authority grant.
fresh();local recovered=save();d.place(point);d.openMenu(true)
local oldHold=d.saveState.pauseRecovery();local currentHold=d.saveState.pauseRecovery()
check(not oldHold.held() and currentHold.held() and not oldHold.release(),"obsolete recovery handle cannot release a replacement hold")
local generation=d.saveState.worldGeneration;local priorStore=d.currentStore()
local adopt=assert(d.saveState.restore.cfg.prepare(recovered,{mode="main"}));assert(adopt())
check(d.saveState.worldGeneration==generation+1 and d.currentStore()~=priorStore,"actual recovery adoption retains the intentional generation/store transition")
local elapsed,needsTime,energy=d.life.elapsed,d.needs.elapsedS,d.needs.energy
d.menu:hide();for _=1,60 do frame(1/60) end
check(currentHold.held() and d.life.elapsed==elapsed and d.needs.elapsedS==needsTime and d.needs.energy==energy,"hiding all menus does not resume a held adopted world")
check(not oldHold.release() and currentHold.held(),"late release does not clear the current adopted-world hold")
check(currentHold.release() and not currentHold.release() and not currentHold.held(),"current recovery release is single-use")
for _=1,2 do frame(1/60) end
check(d.life.elapsed>elapsed and d.needs.elapsedS>needsTime,"explicit current release resumes the actual game loop")
print("RECOVERY_ENTRY_HOLD actual_adoption=true generation_increment=1 menu_hidden=true stale_release_refused=true explicit_current_release_resumes=true")
print(`LOCAL_RETURN passed={passed} failed={failed}`)
assert(failed==0,"local return failures")
