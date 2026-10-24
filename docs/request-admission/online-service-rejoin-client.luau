if WS:GetAttribute("OnlineServiceRejoin")==true then
 local source=inspect()
 check(source.rejoining and source.priorPayloadDigests~=nil,"rejoin source proof unavailable")
 for _,mode in {"main","free","easy"} do
  local offered=client.bound:offer(mode)
  check(offered~=nil and not offered.protected and not offered.record.save_retired,"rejoin did not offer stored ordinary life")
  check(Json.checksum((assert(Json.canonical(offered.record))))==source.priorPayloadDigests[mode],"rejoin network offer changed stored checkpoint")
 end
 local priorGeneration=d.saveState.worldGeneration
 d.openMenu(true);check(d.menu:choose("Continue"),"actual rejoin Continue missing")
 waitFor(function()
  local decision=client:decision("main")
  return decision and decision.state=="writable" and d.session.started and d.saveState.restore.job==nil and not d.world.playerLoading
 end,180)
 check(not d.saveState.broken and d.saveState.worldGeneration>priorGeneration,"actual rejoin world restore did not commit")
 check(appliedRestDigest==source.priorPayloadDigests.main,"actual restore callback did not receive the stored life")
 check(client:decision("main").life==client.bound.requests.main.selected.save_life,"rejoin grant changed life lineage")
 d.title:stop()
 local kept=d.life.save();waitFor(function() return not kept.pending end,120)
 check(kept.ok,"rejoined life could not prepare checkpoint")
 waitFor(function() local request=client.bound.requests.main;return request and request.candidate and request.candidate.stored end,180)
 check(client:decision("main").state=="writable","rejoined stored checkpoint lost its credential")
 inspect("arm_leave");reportCost()
 print("[NEW_APP_NATIVE_CLIENT_PASS]",tag,checks,Json.canonical({server_checks=source.checks,clock_scale=1,real_remote_events=true,memory_store=false,engine_codec=true,online=true,rejoin=true}))
 return
end
