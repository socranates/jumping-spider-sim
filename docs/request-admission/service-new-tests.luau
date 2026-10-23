for _,mode in Rules.MODES do
 test("actual-protected-new-and-fresh-checkpoint-"..mode,function()
  local f=fixture({newLife=true});f.offers();local info=f.client:offerInfo(mode);local before={}
  for _,slot in Rules.MODES do before[slot]=Json.canonical(f.b.data["R_46001_"..slot]) end
  check(f.client.newLifeEnabled and info.protected and f.client:prepareNewLife(mode,info.id),"actual protected New was not negotiated/selected")
  f.drive(function() return f.newState=="verified" end)
  local old=f.owner;local lane=old.session.ordinaryAdmission
  check(old.newLifePolicy.options.admission==lane and old.newLifeJob.result.requiresFreshSession and not old.newLifeJob.result.gameplayAuthorized,"service New lost its lane or manufactured a grant")
  check(Json.canonical(f.b.data["A1_46001_"..mode].raw)==before[mode] and f.client.newLife.request.credential==nil,"service New lost original bytes or granted the retired life")
  for _,other in Rules.MODES do if other~=mode then check(Json.canonical(f.b.data["R_46001_"..other])==before[other],"service New changed another current slot") end end
  local rows={};for key,value in f.b.data do if string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_" then rows[key]=value end end
  local kept=Json.canonical(rows)
  check(f.client:requestReplacement(),"verified New could not request a fresh service epoch")
  f.drive(function() return f.client.transition==nil and #f.owners==2 end)
  check(old:replacementClosed() and not f.g:live(lane.scope) and f.seeds==1,"New replacement did not close/drain without reseeding")
  f.drive(function() return not f.client:offerPending(mode) and f.client:offerInfo(mode)~=nil end)
  local fresh=f.client:offerInfo(mode)
  check(not fresh.protected and not fresh.playable and f.client:beginLife(mode,fresh.id),"fresh epoch did not expose an explicit ordinary New")
  f.drive(function() local r=f.client:decision(mode);return r and r.state=="writable" end)
  local world=newWorld();world.garden={};world.life.mode=if mode=="free" then "free" else "main"
  world.life.rules=if mode=="main" then "standard" else "gentle";world.needs.gentle=mode~="main"
  check(f.client:sendRest(mode,assert(Checkpoint.capture(world,f.clock.now))),"fresh client checkpoint refused")
  f.drive(function() local r=f.owner.session.intents.requests[mode];return r and r.storedSerial and r.storedSerial>0 end)
  rows={};for key,value in f.b.data do if string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_" then rows[key]=value end end
  check(Json.canonical(rows)==kept and #f.errors==0,"fresh service checkpoint changed immutable data or hid an error")
  f.server:removePlayer(f.player);closed(f)
 end)
end
