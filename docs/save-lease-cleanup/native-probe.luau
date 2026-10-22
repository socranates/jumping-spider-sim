-- Local Studio-only synthetic save session regression; Persistence is disabled. Never publish.
local Run=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local SaveRules=require(Shared.Data.SaveRules)
local Json=require(Shared.Persistence.Json)
local SaveSession=require(Shared.Persistence.SaveSession)
local SaveEnvelope=require(Shared.Persistence.SaveEnvelope)
local SaveProgress=require(Shared.Persistence.SaveProgress)
local SaveRest=require(Shared.Persistence.SaveRest)
local MemoryBackend=require(Shared.Persistence.MemoryBackend)
local Checkpoint=require(Shared.Persistence.Checkpoint)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("LeaseCleanupProbe")==true)
 local runId=tostring(DateTime.now().UnixTimestampMillis)
 local checks,cases=0,0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function case(name,fn) fn();cases+=1;print("[LEASE_CLEANUP_NATIVE_CASE]",runId,cases,name,checks) end
 -- Missing backend values are compared explicitly; nil is not a JSON document.
 local function canon(value) if value==nil then return "<missing>" end;return assert(Json.canonical(value)) end
 local function prog(ids) local p=SaveProgress.default();p.notebook.opened=Json.copy(ids);return p end
 local function newEnv()
  local e={t=100000,backend=MemoryBackend.new(),logs={}}
  e.now=function() return e.t end;e.sleep=function(s) e.t+=s end;return e
 end
 local function newSession(e,uid,id,extra)
  local cfg={backend=e.backend,userId=uid,sessionId=id,now=e.now,sleep=e.sleep,log=function(text) table.insert(e.logs,text) end}
  for k,v in extra or {} do cfg[k]=v end
  return SaveSession.new(cfg)
 end
 local function run(e,s,seconds) for _=1,seconds do e.t+=1;s:step() end end
 local records={}
 local function realRest(_ticks,mode) return Json.copy(assert(records[mode])) end
 local ok,problem=pcall(function()
  print("[LEASE_CLEANUP_NATIVE_BEGIN]",runId)
  local deadline=os.clock()+45
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.RenderStepped:Wait() end
  assert(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup never became ready")
  d.title.seen=true;d.session.finishedMain=true
  for _,mode in {"main","free","easy"} do
   assert(d.fresh(if mode=="easy" then "main" else mode,mode=="easy",nil),"native mode refused")
   local roots={motor=d.motor,prey=d.prey,sensor=d.sensor,memory=d.memory,needs=d.needs,life=d.life,wasp=d.wasp,garden=d.world.garden,cat=d.cat,water=d.water}
   local record,why=Checkpoint.capture(roots,120);assert(record,why)
   assert(#SaveRest.check(mode,record)==0,"native capture did not validate")
   records[mode]=record;d.openMenu();Run.RenderStepped:Wait()
  end
-- Appended to the default state suite; uses its real-rest and backend fixtures.
local function releaseQueued(s)
 local item=s.sched.items.release;return item~=nil and item.dirty
end
case("rejected unseen retirement releases its acquired lease without changing any saved life",function()
 for i,mode in SaveRules.MODES do
  local e=newEnv();local uid=1200+i;local owner=newSession(e,uid,"owner")
  owner:load();assert(owner:setRest(mode,realRest(120,mode)));run(e,owner,15)
  local visitor=newSession(e,uid,"visitor")
  check(visitor:load()=="session" and not visitor.restLoaded[mode],mode..": live owner prevents initial slot read")
  assert(visitor:beginLife(mode,1));owner:flush(e.t+20)
  check(visitor:load()=="session" and not visitor.canRetry,mode..": unseen retirement is still refused after acquisition")
  local pkey="P_"..uid;local rkey="R_"..uid.."_"..mode
  local progress=Json.copy(e.backend.data[pkey]);local rest=canon(e.backend.data[rkey])
  check(progress.lock.session==visitor.id,mode..": regression actually acquired the abandoned lease")
  visitor:step()
  check(canon(e.backend.data[pkey])==canon(SaveEnvelope.withLock(progress,nil)),mode..": only owned lock metadata was released")
  check(canon(e.backend.data[rkey])==rest and not visitor.lifeRequests[mode].done,mode..": checkpoint, backup and refused acknowledgement untouched")
  local nextVisit=newSession(e,uid,"next-visit")
  check(nextVisit:load()=="active",mode..": next visit loads immediately without waiting120 seconds")
  check(canon(nextVisit.rests[mode])==canon(owner.rests[mode]),mode..": next visit receives the preserved life")
 end
end)

local function cleanupFixture(uid)
 local e=newEnv();local s=newSession(e,uid,"cleanup");assert(s:load()=="active")
 local raw=e.backend.data[s.pkey]
 raw=Json.copy(SaveEnvelope.make(SaveProgress.SPEC,raw.payload,e.t,raw,{lock=raw.lock}))
 assert(Json.canonical(raw),"fixture must be a storable tree, not shared payload references")
 raw.extra_metadata={preserve="unchanged"};e.backend:poke(s.pkey,raw)
 -- Queue local candidates that cleanup must never merge or acknowledge.
 s:setProgress(prog({"unsaved-local-page"}));assert(s:beginLife("main",1))
 return e,s,raw
end

case("session-only cleanup preserves progress, backup and unknown envelope metadata",function()
 local e,s,raw=cleanupFixture(1210)
 s:demote("other_session",false);local writes=e.backend.writes
 check(s:step(),"one queued cleanup request executes")
 check(canon(e.backend.data[s.pkey])==canon(SaveEnvelope.withLock(raw,nil)),"no local progress merge or backup rewrite")
 check(e.backend.data[s.rkey.main]==nil and not s.lifeRequests.main.done,"unsent rest/retirement never written or acknowledged")
 check(e.backend.writes==writes+1,"only the lock removal writes")
 local requests=e.backend.requests;s:step();s:step()
 check(e.backend.requests==requests,"completed cleanup has no recurring requests")
end)

case("lease cleanup refuses another owner even when its beat is stale",function()
 for i,beat in {100000,1} do
  local e,s,raw=cleanupFixture(1210+i);s:demote("other_session",false)
  local foreign=SaveEnvelope.withLock(raw,{session="other-owner",beat=beat});e.backend:poke(s.pkey,foreign)
  local writes=e.backend.writes;s:step()
  check(canon(e.backend.data[s.pkey])==canon(foreign),"foreign ownership metadata stays intact")
  check(e.backend.writes==writes,"foreign lock cleanup is a cancelled transform")
 end
end)

case("retried cleanup callback rechecks the latest owner",function()
 local e,s,raw=cleanupFixture(1213);s:demote("other_session",false)
 local update=e.backend.update;local calls=0
 local foreign=SaveEnvelope.withLock(raw,{session="replacement",beat=e.t})
 e.backend.update=function(self,key,transform)
  local discarded=transform(Json.copy(raw));calls+=1
  assert(discarded and discarded.lock==nil,"first speculative callback would release ours")
  self:poke(key,foreign)
  return update(self,key,function(latest) calls+=1;return transform(latest) end)
 end
 s:step()
 check(calls==2,"fixture reruns callback after a concurrent owner change")
 check(canon(e.backend.data[s.pkey])==canon(foreign),"final callback never releases a replacement owner")
end)

case("cleanup retries transient failure with backoff and resolves a lost success response",function()
 for i,afterWrite in {false,true} do
  local e,s,raw=cleanupFixture(1213+i);s:demote("other_session",true)
  e.backend:fail({op="update",key=s.pkey,times=1,afterWrite=afterWrite,message="lost cleanup response"})
  s:step();local requests=e.backend.requests;local writes=e.backend.writes
  check(releaseQueued(s),"uncertain cleanup remains queued")
  e.t+=1;s:step()
  check(e.backend.requests==requests,"neither cleanup retry nor reacquisition bypasses backoff")
  e.t+=1;s:step()
  check(not releaseQueued(s) and e.backend.data[s.pkey].lock==nil,"retry converges on released ownership")
  check(canon(e.backend.data[s.pkey])==canon(SaveEnvelope.withLock(raw,nil)),"ambiguous responses cannot rewrite progress/backup")
  check(e.backend.writes==writes+(if afterWrite then 0 else 1),"lost committed success does not duplicate a write")
 end
end)

case("metadata cleanup follows request budget and cannot renew a lease while waiting",function()
 local e,s=cleanupFixture(1216);s:demote("other_session",true)
 s.sched.started=table.create(SaveRules.REQUESTS_PER_MINUTE,e.t)
 local requests=e.backend.requests;e.t+=SaveRules.RETRY_LOAD;s:step()
 check(e.backend.requests==requests,"exhausted budget prevents cleanup and reacquisition")
 e.t+=61;s:step()
 check(e.backend.requests==requests+1 and e.backend.data[s.pkey].lock==nil,"one budgeted request releases rather than reacquires")
 check(s.state=="session","release is not a false recovery notification")
end)

case("unknown or damaged progress is never rewritten just to remove its lock",function()
 for i,kind in {"newer","corrupt","missing"} do
  local e,s,raw=cleanupFixture(1216+i);s:demote("other_session",false)
  if kind=="newer" then raw.schema=SaveProgress.SPEC.current+1
  elseif kind=="corrupt" then raw.checksum="damaged"
  else raw=nil end
  e.backend:poke(s.pkey,raw);local before=canon(raw);local writes=e.backend.writes;s:step()
  check(canon(e.backend.data[s.pkey])==before,kind..": unreadable or missing raw value retained")
  check(e.backend.writes==writes,kind..": cleanup never manufactures a default record")
 end
end)

case("successful explicit reload cancels stale cleanup and keeps the renewed active lease",function()
 local e,s=cleanupFixture(1220);s:demote("other_session",true)
 -- No queued retirement on this fixture: exercise successful deliberate reload.
 s.lifeRequests={};s.restPending={};s.restPendingTime={};s.sched:abandon("rest_main")
 check(s:load()=="active","same session can deliberately recover ownership")
 local requests=e.backend.requests;s:step()
 check(not releaseQueued(s) and e.backend.data[s.pkey].lock.session==s.id,"active ownership is not released by old cleanup")
 check(e.backend.requests<=requests+1,"only ordinary progress scheduling may run after reload")
end)

case("departure cleanup preserves dirty candidates and respects its deadline",function()
 for i,fail in {false,true} do
  local e,s,raw=cleanupFixture(1220+i);s:demote("other_session",false)
  if fail then e.backend:fail({op="update",key=s.pkey,times=10,message="offline"}) end
  local requests=e.backend.requests;local deadline=e.t+.5;s:flush(deadline)
  check(s.closed and e.t<=deadline,"departure completes without overrunning its sleep deadline")
  check(e.backend.requests==requests+1,"bounded departure made one cleanup attempt in this half-second window")
  check(canon(e.backend.data[s.pkey])==canon(if fail then raw else SaveEnvelope.withLock(raw,nil)),"departure changes no saved candidate")
  check(e.backend.data[s.rkey.main]==nil and not s.lifeRequests.main.done,"departure never flushes a refused life")
 end
end)

  assert(cases==9 and checks==62,"native case/assertion count changed")
  print("[LEASE_CLEANUP_NATIVE_DONE]",runId,cases,checks)
 end)
 if not ok then warn("[LEASE_CLEANUP_NATIVE_FAIL]",runId,tostring(problem)) end
 workspace:SetAttribute("LeaseCleanupProbeDone",true);workspace:SetAttribute("LeaseCleanupProbePassed",ok)
end
