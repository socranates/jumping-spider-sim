for _,mode in Rules.MODES do
 test("ordinary-normal-replacement-"..mode,function()
  local f=fixture({deferAdd=true})
  for _,slot in Rules.MODES do f.b.data["R_46001_"..slot]=nil end
  f.server:addPlayer(f.player)
  f.drive(function() return f.client.replacementEnabled and f.client.phase=="ready" and not f.client:offerPending() end)
  check(f.owner.runtime.phase=="normal" and not f.owner.runtime.accepted and f.owner.runtime.route==nil
   and f.owner.session.backend.held==nil,"ordinary fixture accidentally entered recovery")
  check(f.client:beginLife(mode),"ordinary fresh choice refused")
  f.drive(function() local r=f.client:decision(mode);return r and r.state=="writable" end)
  local record=Json.copy(f.owner.profiles[mode].template)
  check(f.client:sendRest(mode,record),"ordinary checkpoint refused")
  f.drive(function() local r=f.owner.session.intents.requests[mode];return r and r.storedSerial and r.storedSerial>0 end)
  local old=f.owner;local lane=old.session.ordinaryAdmission
  f.begin()
  f.drive(function()
   check(not f.client.transition or f.client.transition.stage~="failed","ordinary normal replacement refused")
   return f.client.transition==nil and #f.owners==2
  end)
  check(old:replacementClosed() and not f.g:live(lane.scope) and f.g:inspect().scopes==1,"ordinary replacement overlapped owners")
  check(f.seeds==1 and f.owner.session.ordinaryAdmission.scope~=lane.scope,"ordinary replacement reset account debt")
  check(nonP(f.b)==f.before and table.find(f.b.data.P_46001.payload.notebook.opened,"replacement_final_note"),"ordinary departure changed checkpoints or lost progress")
  check(not old.runtime.accepted and old.runtime.phase=="closed","ordinary departure fabricated recovered gameplay")
  accounted(f);check(#f.errors==0,"ordinary replacement hid a service exception")
  f.server:removePlayer(f.player);closed(f)
 end)
end
