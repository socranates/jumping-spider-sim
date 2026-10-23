drive(function() return client:recoveryReady() and client.newLifeEnabled and not client:offerPending() and d.session.started and client:offerInfo("easy")~=nil end)
d.session.started=false;d.openMenu(true);holdAck=false
local function has(id) for _,choice in d.menu.choices do if choice.id==id then return true end end;return false end
local function originals()
 local rows={};for key,value in b.data do if string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_" then rows[key]=value end end
 return Json.canonical(rows)
end
-- First recover a real living spider. A menu choice from that world must close
-- its exact old owner and offer fresh choices before choosing a different life.
check(d.menu:choose("Continue"),"initial actual Continue missing")
drive(function() return app.phase=="playing" end)
check(app.recoveredPlaying and d.life.recoveryHistory~=nil,"actual recovered-playing route was not established")
local prior=owners[#owners];local epoch=client.bound.epoch;local kept=originals();local life=d.life
d.openMenu(true);check(d.menu:choose("New") and app.phase=="replacing" and app:held(),"recovered menu New bypassed old-owner replacement")
check(d.life==life and d.session.started,"recovered menu replaced the world before closure")
drive(function() return app.phase=="menu" and client.transition==nil end)
check(prior:replacementClosed() and client.bound.epoch~=epoch and originals()==kept and not d.session.started,"recovered menu lost original or silently started a life")
for _,mode in {"main","free","easy"} do
 d.openMenu() -- exercise actual refresh requests after an ordinary life begins
 if mode=="free" then
  drive(function() local owner=owners[#owners];return owner.runtime.phase=="discovering" and owner.backgroundOrdinaryMode=="main" end)
  check(client:sendRest("main",assert(Checkpoint.capture(app.entry.cfg.world,clock.now))),"background refresh discarded a granted ordinary rest")
  drive(function() local r=client.bound.requests.main;return r.candidate and r.candidate.stored end)
  check(owners[#owners].session.intents.requests.main.state=="writable","background refresh revoked ordinary authority")
 end
 drive(function() return not client:offerPending(mode) and client:offerInfo(mode)~=nil end)
 d.openMenu(true)
 local choice=if mode=="main" then "New" elseif mode=="easy" then "Easy" else "NewFree"
 local info=client:offerInfo(mode);check(info.protected and info.playable and has(choice),"protected New mode missing from actual menu: "..mode)
 local before={};for _,slot in Rules.MODES do before[slot]=Json.canonical(b.data["R_46001_"..slot]) end
 local prior=owners[#owners];local epoch=client.bound.epoch;local elapsed,energy=d.life.elapsed,d.needs.energy
 check(d.menu:choose(choice),"actual New choice refused")
 if app.phase~="new" then check(d.menu:choose(choice),"actual New confirmation missing") end
 check(app.phase=="new" and app:held() and d.menu:isShowing(),"protected New did not hold the actual world")
 local operation=assert(client.newLife);local req=operation.request
 check(req.credential==nil and req.kind=="new" and client.activeSlot==mode,"New claimed a grant before the marker")
 -- Wrong identities, old epochs and unsolicited fields cannot advance New.
 for _,bad in {"epoch","serial","offerId","mode","extra"} do
  local packet={kind="new_life_state",v=1,epoch=epoch,mode=mode,serial=operation.serial,offerId=operation.offerId,sequence=100000,state="verified"}
  if bad=="epoch" then packet.epoch="stale" elseif bad=="serial" then packet.serial+=1 elseif bad=="offerId" then packet.offerId="wrong"
  elseif bad=="mode" then packet.mode="wrong" else packet.extra=true end
  client:receive(packet)
  check(app.phase=="new" and client.newLife==operation and app:held(),"invalid New reply advanced actual application")
 end
 d.menu:hide();for _=1,10 do frame(1/60) end
 check(app:held() and d.life.elapsed==elapsed and d.needs.energy==energy and req.credential==nil,"hidden New screen advanced or granted old world")
 check(not d.fresh("main",false,nil) and not d.saveState.beginLocalReturn("main","menu"),"held New admitted a world reset")
 drive(function() return app.phase=="menu" and client.transition==nil and client.bound.epoch~=epoch end)
 check(prior:replacementClosed() and app:held() and not d.session.started,"New did not close old owner before fresh choices")
 local marker=Envelope.open(SaveRest.SPECS[mode],codec:decode(b.data["R_46001_"..mode]))
 check(marker.status=="ok" and marker.payload.save_retired==true and Json.canonical(b.data["A1_46001_"..mode].raw)==oldBytes[mode],"actual New lost original or skipped verified marker")
 for _,other in Rules.MODES do if other~=mode then check(Json.canonical(b.data["R_46001_"..other])==before[other],"actual New changed sibling rest") end end
 local archive=originals()
 drive(function() return not client:offerPending(mode) and client:offerInfo(mode)~=nil end)
 check(not client:offerInfo(mode).protected and not client:offerInfo(mode).playable,"fresh menu reoffered retired protected life")
 d.openMenu(true);local freshChoice=if mode=="main" then "New" elseif mode=="easy" then "Easy" else "Free"
 check(d.menu:choose(freshChoice),"fresh explicit New choice missing")
 if app:choosing() then check(d.menu:choose(freshChoice),"fresh explicit New confirmation missing") end
 check(app.phase=="playing" and not app:held() and d.session.started and client.activeSlot==mode,"fresh actual New did not release its current-world hold")
 drive(function() local r=client:decision(mode);return r and r.state=="writable" end)
 local granted=client:decision(mode)
 check(granted.credential~=nil and granted.life~=marker.payload.save_life,"new actual world did not receive a distinct real credential")
 check(client:sendRest(mode,assert(Checkpoint.capture(app.entry.cfg.world,clock.now))),"new actual world could not send normal checkpoint")
 drive(function() local r=client.bound.requests[mode];return r.candidate and r.candidate.stored end)
 check(originals()==archive,"new normal rest changed immutable originals")
 print("NEW_APPLICATION mode="..mode.." actual_menu=true original_retained=true old_closed=true explicit_fresh_choice=true writable=true normal_rest_stored=true")
 d.openMenu()
end
check(#errors==0,"hidden New application service error: "..tostring(errors[1]))
server:removePlayer(player);check(owners[#owners].session.closed and b.data.P_46001.lock==nil,"actual New application did not release final lease")
catalog:close()
print("NEW_APPLICATION passed="..count.." failed=0")
end
runNewApplicationChecks()
end
