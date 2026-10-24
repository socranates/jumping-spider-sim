local mutations={
 {"session-id",function(f) local s=f.owner.session;local v=s.id;s.id="changed";return function()s.id=v end end},
 {"progress-key",function(f) local s=f.owner.session;local v=s.pkey;s.pkey="P_other";return function()s.pkey=v end end},
 {"account",function(f) local s=f.owner.session;local v=s.cfg.userId;s.cfg.userId=999;return function()s.cfg.userId=v end end},
 {"provider",function(f) local b=f.owner.session.backend;local v=b.source;b.source={};return function()b.source=v end end},
 {"scheduler",function(f) local s=f.owner.session;local v=s.sched;s.sched={};return function()s.sched=v end end},
 {"observations",function(f) local s=f.owner.session;local v=s.observations;s.observations={};return function()s.observations=v end end},
 {"intents",function(f) local s=f.owner.session;local v=s.intents;s.intents={};return function()s.intents=v end end},
 {"load",function(f) local s=f.owner.session;local v=s._loadSerial;s._loadSerial+=1;return function()s._loadSerial=v end end},
 {"pipeline",function(f) local rt=f.owner.runtime;local v=rt.pipeline;rt.pipeline={leaseLost=false,busy=false};return function()rt.pipeline=v end end},
}
for _,mutation in mutations do
 test("ordinary-replacement-drain-fences-"..mutation[1],function()
  local f=fixture({deferAdd=true})
  for _,mode in Rules.MODES do f.b.data["R_46001_"..mode]=nil end
  f.server:addPlayer(f.player)
  f.drive(function()return f.client.replacementEnabled and f.client.phase=="ready" and not f.client:offerPending()end)
  local starts=f.starts;local before=Json.canonical(f.b.data);local restore
  f.owner.busy=true
  f.onSleep=function()
   assert(restore==nil);restore=mutation[2](f);f.owner.busy=false
  end
  local okay=f.owner:prepareReplacement(f.progress)
  check(restore~=nil and okay==false,"changed normal route was accepted after a drain yield")
  restore();f.onSleep=nil
  check(f.starts==starts and Json.canonical(f.b.data)==before and f.owner.session.backend.held==nil,"refused route started storage or took a hold")
  f.server:removePlayer(f.player);closed(f)
 end)
end
