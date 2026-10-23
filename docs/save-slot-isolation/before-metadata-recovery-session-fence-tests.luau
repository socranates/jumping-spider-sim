local passedFence=0
local function checkFence(ok,why) assert(ok,why);passedFence+=1 end
local function fixtureFence(backup)
 local clock={now=100};local b=MemoryBackend.new();b.readRawFresh=b.read;b.readFresh=b.read
 local rec=realRest(1,"main");rec.save_life="old-garden-life"
 local value=SaveEnvelope.make(SaveRest.SPECS.main,rec,90,nil)
 if backup then value=SaveEnvelope.make(SaveRest.SPECS.main,Json.copy(rec),95,value);value.checksum="broken-current" end
 b:poke("R_45001_main",value)
 local s=SaveSession.new({backend=b,userId=45001,sessionId="recovery-A",now=function() return clock.now end})
 checkFence(s:load()=="active","actual session failed to load")
 s:enableOffers();s:step()
 local offer=assert(s:offer("main"));checkFence(s:requestLife("continue","main",1,offer.id),"actual Continue failed")
 local ticket=assert(__sessionFence.capture(s,"main",1,offer.id))
 return s,b,clock,ticket,offer
end
do
 local s,b,clock,t,offer=fixtureFence();local before=b.requests
 checkFence(__sessionFence.valid(t),"current real session not admitted")
 checkFence(b.requests==before and s.intents.requests.main.credential==nil,"fence issued request or granted permission")
 clock.now+=30;s.sched:beat(clock.now)
 checkFence(__sessionFence.valid(t),"acknowledged heartbeat incorrectly revoked observation")
 local c=__collectorPrototype.new(b,"45001",s.id);local j=c:begin("selected-old-garden",function() return __sessionFence.valid(t) end)
 for _=1,100 do if j.state~="pending" then break end;c:step(j) end
 checkFence(j.state=="complete" and __sessionFence.matchesPlan(t,j.plan),"actual-session source collection did not bind")
 local mismatch=Json.copy(j.plan);mismatch.entries.main.raw.payload.save_life="other-life"
 checkFence(not __sessionFence.matchesPlan(t,mismatch),"mismatched source life accepted")
 mismatch=Json.copy(j.plan);mismatch.entries.progress.raw.lock.session="other-owner"
 checkFence(not __sessionFence.matchesPlan(t,mismatch),"foreign raw owner accepted")
 mismatch=Json.copy(j.plan);mismatch.entries.progress.raw.lock.beat=clock.now-SaveRules.LOCK_STALE
 checkFence(not __sessionFence.matchesPlan(t,mismatch),"expired raw ownership accepted")
 __sessionFence.cancel(t);checkFence(not __sessionFence.valid(t),"cancelled ticket stayed active")
end
local mutations={
 demote=function(s) s:demote("other_session",true) end,
 reload=function(s) s:load(true) end,
 close=function(s) s.closed=true end,
 new_life=function(s) s:requestLife("new","main",2,nil) end,
 regrant=function(s) s.intents:grant(s.intents.requests.main,"old-garden-life") end,
 changed=function(s) s.intents:changed(s.intents.requests.main,"rest_changed") end,
 readonly=function(s) s.intents:readonly(s.intents.requests.main,"offline") end,
 pending=function(s) s.restPending.main={} end,
 backend=function(s) s.backend=MemoryBackend.new() end,
 owner=function(s) s.cfg.userId=999 end,
 source=function(s) s.intents.requests.main.base.checksum="0000000000000000" end,
 clear=function(s) s.observations:clearSelection("main",2) end,
 expired=function(s,b,c) c.now+=SaveRules.LOCK_STALE end,
 backwards=function(s,b,c) c.now-=1 end,
}
for name,mutate in mutations do
 local s,b,clock,t=fixtureFence();local c=__collectorPrototype.new(b,"45001",s.id)
 local j=c:begin("before-"..name,function() return __sessionFence.valid(t) end)
 local original=Json.canonical(b.data)
 local raw=b.readRawFresh;local suspended=false
 b.readRawFresh=function(self,key)
  local ok,value,err=raw(self,key);suspended=true;coroutine.yield("raw-suspended");return ok,value,err
 end
 local thread=coroutine.create(function() c:step(j) end)
 local ok,why=coroutine.resume(thread);checkFence(ok and suspended and why=="raw-suspended","did not suspend actual backend result")
 mutate(s,b,clock)
 checkFence(not __sessionFence.valid(t),"changed session admitted: "..name)
 checkFence(coroutine.resume(thread),"resume failed: "..name)
 checkFence(j.state~="complete" and j.plan==nil and j.work==nil,"stale result started CPU preparation: "..name)
 -- Reload may renew the original lock; other mutations make no backend write.
 if name~="reload" then checkFence(Json.canonical(b.data)==original,"invalidated work edited source: "..name) end
end
do
 local s,b,clock,t,offer=fixtureFence()
 checkFence(__sessionFence.capture(s,"main",2,offer.id)==nil,"unselected serial accepted")
 checkFence(__sessionFence.capture(s,"main",1,"wrong")==nil,"wrong offer accepted")
 s.busy=true;checkFence(__sessionFence.capture(s,"main",1,offer.id)==nil,"capture entered running session worker")
end
do
 local s,b,clock,t=fixtureFence(true)
 checkFence(t.identity.kind=="backup" and t.protected,"actual protected backup was not selected")
 local c=__collectorPrototype.new(b,"45001",s.id);local j=c:begin("protected-backup",function() return __sessionFence.valid(t) end)
 for _=1,100 do if j.state~="pending" then break end;c:step(j) end
 checkFence(j.state=="complete" and __sessionFence.matchesPlan(t,j.plan),"backup identity did not match untouched raw envelope")
 local changed=Json.copy(j.plan);changed.entries.main.raw.backup.checksum="0000000000000000"
 checkFence(not __sessionFence.matchesPlan(t,changed),"different backup identity admitted")
end
do
 local s,b,clock,t=fixtureFence();clock.now+=SaveRules.LOCK_STALE
 checkFence(not __sessionFence.valid(t),"expired ticket still valid")
 s.sched:beat(clock.now)
 checkFence(not __sessionFence.valid(t),"expired ticket resurrected after a later heartbeat")
 local s2,b2,c2,t2=fixtureFence();s2.now=function() error("clock unavailable") end
 checkFence(not __sessionFence.valid(t2),"failed clock did not refuse")
 s2.now=function() return c2.now end
 checkFence(not __sessionFence.valid(t2),"failed clock ticket resurrected")
end
print("RECOVERY_SESSION_FENCE passed="..passedFence.." failed=0")
