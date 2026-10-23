-- Generated fixture prefix is the actual replacement service/client harness.
local function originals(f)
 local rows={};for key,value in f.b.data do if string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_" then rows[key]=value end end
 return Json.canonical(rows)
end
local function current(f,mode)
 return f.server.base.entries[f.player].session.intents.requests[mode]
end
local function offered(f,mode)
 f.drive(function() return f.client:recoveryReady() and not f.client:offerPending(mode) and f.client:offerInfo(mode)~=nil end)
end
local function chooseNew(f,mode)
 offered(f,mode);local info=f.client:offerInfo(mode)
 check(f.client:beginLife(mode,info.id),"actual New intent refused")
 f.drive(function() return current(f,mode)~=nil and f.owner.mode==mode and f.owner.runtime.phase=="offered" end)
 local r=current(f,mode)
 check(r.kind=="new" and r.state=="readonly" and r.credential==nil,"New gained authority before retirement")
 return r
end
local function start(f,mode,options)
 local r=chooseNew(f,mode);local rt=f.owner.runtime
 local policy=__newLifePolicy.new(rt,options or {work={now=function() return 0 end}})
 local job,why=policy:begin(mode,r.serial,r.offerId);assert(job,why)
 f.owner.newLifePolicy,f.owner.newLifeJob=policy,job
 return policy,job,r
end
local function drivePolicy(f,job,done)
 for _=1,1800 do
  if done() then return end
  local before=f.b.requests;f.tick()
  check(f.b.requests-before<=1,"New worker issued multiple storage requests per service step")
  check(not f.owner.busy and not f.owner.session.busy,"New retained a provider busy flag")
  if job.state=="refused" then break end
 end
 local r=job.ticket.request;local s=f.owner.session;local rt=f.owner.runtime
 print("NEW_SCOPE_DIAGNOSTIC",Json.canonical({state=s.state,closed=s.closed,load=s._loadSerial,capturedLoad=job.ticket.load,
  sameRequest=s.intents.requests[job.ticket.mode]==r,reason=r.reason,capturedReason=job.ticket.reason,revision=r.revision,capturedRevision=job.ticket.revision,
  needsCheck=r.needsCheck,capturedNeedsCheck=job.ticket.needsCheck,held=s.backend:valid(job.held),kind=r.kind,ticketKind=job.ticket.intentKind,
  cancelled=job.ticket.cancelled,rtphase=rt.phase,pipelineSame=rt.pipeline==f.owner.newLifePolicy}))
 error("New did not settle: "..job.phase.." "..tostring(job.problem))
end
for _,mode in Rules.MODES do
 local f=fixture();local untouched={}
 for _,slot in Rules.MODES do untouched[slot]=Json.canonical(f.b.data["R_46001_"..slot]) end
 local policy,job,r=start(f,mode)
 drivePolicy(f,job,function() return job.state=="verified" end)
 check(job.result.requiresFreshSession and not job.result.gameplayAuthorized and r.credential==nil and r.state=="readonly","retirement invented new-life permission")
 check(f.owner.session.backend.held.enforced and not f.owner.session.backend:permitted(f.owner.session.backend.held),"New lost or leaked its enforcing hold")
 local marker=Envelope.open(SaveRest.SPECS[mode],codec:decode(f.b.data["R_46001_"..mode]))
 check(marker.status=="ok" and marker.payload.save_retired==true and marker.payload.checkpoint==nil,"New did not store an independently readable normal retired marker")
 check(Json.canonical(f.b.data["A1_46001_"..mode].raw)==untouched[mode],"New lost the entire original rest")
 for _,other in Rules.MODES do if other~=mode then check(Json.canonical(f.b.data["R_46001_"..other])==untouched[other],"New changed another slot") end end
 local kept=originals(f);local old=f.owner;local epoch=f.client.bound.epoch
 check(f.client:requestReplacement(),"retired New could not request a fresh session")
 f.drive(function() return f.client.transition==nil and f.client.bound.epoch~=epoch end)
 check(old:replacementClosed() and originals(f)==kept,"New replacement lost originals or overlapped owners")
 offered(f,mode);local info=f.client:offerInfo(mode)
 check(not info.protected and not info.playable,"fresh session reoffered the retired life")
 check(f.client:beginLife(mode,info.id),"actual fresh-session New refused normal marker")
 f.drive(function() local q=f.client:decision(mode);return q and q.state=="writable" end)
 local granted=f.client:decision(mode)
 check(granted.credential~=nil and granted.life==f.owner.session.id..":"..mode..":"..tostring(granted.serial)
  and granted.life~=marker.payload.save_life,"fresh session did not issue a distinct real New credential")
 local world=newWorld();world.garden={};world.life.mode=if mode=="free" then "free" else "main"
 world.life.rules=if mode=="main" then "standard" else "gentle";world.needs.gentle=mode~="main"
 check(f.client:sendRest(mode,assert(Checkpoint.capture(world,f.clock.now))),"new life could not submit its normal checkpoint")
 f.drive(function() local q=f.client.bound.requests[mode];return q.candidate and q.candidate.stored end)
 check(originals(f)==kept,"first writable new checkpoint changed originals")
 f.server:removePlayer(f.player)
 print("PROTECTED_NEW mode="..mode.." original_archived=true marker_verified=true old_closed=true real_new_credential=true normal_rest_stored=true")
end
-- A migration already has an immutable archive/proposal. Retiring it must keep
-- those exact bytes, including subsequent current rest changes.
do
 local f=fixture();f.recover("main");f.begin();f.drive(function() return f.client.transition==nil end)
 local kept=originals(f)
 local policy,job,r=start(f,"main")
 drivePolicy(f,job,function() return job.state=="verified" end)
 check(originals(f)==kept and r.credential==nil,"continued New rewrote its archive/proposal or granted early")
 f.server:removePlayer(f.player)
end
for _,afterWrite in {false,true} do
 local f=fixture();local policy,job=start(f,"main")
 drivePolicy(f,job,function() return job.phase=="write" and f.owner.session.sched:budgetOk(f.clock.now) end)
 f.b:fail({op="update",key="R_46001_main",afterWrite=afterWrite,message="timeout"})
 drivePolicy(f,job,function() return job.state=="verified" end)
 check(job.result.retired and not job.result.gameplayAuthorized,"ambiguous New write was not resolved by fresh readback")
 f.server:removePlayer(f.player)
end
do
 local f=fixture();local policy,job=start(f,"main")
 drivePolicy(f,job,function() return job.phase=="write" end)
 local foreign=Json.copy(f.b.data.R_46001_main);foreign.session="other-writer";f.b:poke("R_46001_main",foreign)
 for _=1,1800 do f.tick();if job.state~="pending" then break end end
 check(job.state=="refused" and Json.canonical(f.b.data.R_46001_main)==Json.canonical(foreign),"New overwrote a concurrently changed rest")
 f.server:removePlayer(f.player)
end
do
 local f=fixture();local policy,job,r=start(f,"main")
 local kept=nonP(f.b);local before=f.b.requests
 f.owner.session.intents:changed(r,"newer_choice")
 f.tick()
 check(job.state=="refused" and f.b.requests==before and nonP(f.b)==kept,"superseded New made storage changes")
 f.server:removePlayer(f.player)
end
-- Ordinary offers must remain visible beside protected slots, without granting
-- authority from a loaded snapshot or waiting for the ordinary worker to run.
do
 local f=fixture({ordinaryMode="free"});offered(f,"free")
 local info=f.client:offerInfo("free");local protected=Json.canonical(f.b.data.R_46001_main)
 check(not info.protected and info.playable and current(f,"free")==nil,"ordinary loaded offer was hidden or granted authority")
 check(f.client:beginLife("free",info.id),"mixed ordinary New choice refused")
 f.drive(function() local q=f.client:decision("free");return q and q.state=="writable" end)
 check(Json.canonical(f.b.data.R_46001_main)==protected and f.b.data.A1_46001_progress==nil,"ordinary New changed a protected sibling")
 f.server:removePlayer(f.player)
end
-- Invalid durability proofs must be found before the destructive marker CAS.
do
 local f=fixture();local policy,job=start(f,"main");local raw=Json.canonical(f.b.data.R_46001_main)
 drivePolicy(f,job,function() return job.phase=="proofArchive" end)
 f.b.data.A1_46001_main=nil
 for _=1,1800 do f.tick();if job.state=="refused" then break end end
 check(job.state=="refused" and Json.canonical(f.b.data.R_46001_main)==raw,"New retired a source without complete original proof")
 f.server:removePlayer(f.player)
end
-- Cancellation closes preparation, retains the owner/lease, and can still use
-- the acknowledged session replacement instead of trapping the player.
do
 local pulseClock=0
 local f=fixture();local policy,job=start(f,"main",{work={now=function() pulseClock+=.00001;return pulseClock end,budget=.000001,maxSeconds=2000,maxResumes=100000}})
 drivePolicy(f,job,function() return job.phase=="prepareSource" end)
 f.tick();check(job.work and job.work.state=="pending","source preparation did not yield")
 local kept=nonP(f.b);check(policy:cancel(job),"cooperative New cancellation refused")
 for _=1,150 do f.tick() end
 check(job.state=="refused" and nonP(f.b)==kept and not policy.leaseLost,"cancelled New changed originals or abandoned its owned lease")
 local old=f.owner;local epoch=f.client.bound.epoch;check(f.client:requestReplacement(),"cancelled New lost safe exit")
 f.drive(function() return f.client.transition==nil and f.client.bound.epoch~=epoch end)
 check(old:replacementClosed() and nonP(f.b)==kept,"cancelled New exit failed closure/original preservation")
 f.server:removePlayer(f.player)
end
-- An interrupted schema3 retirement is explicitly observed for New only. It
-- must retain the existing complete A1/M1 rather than archiving a marker.
do
 local first=fixture();first.recover("main")
 local request=current(first,"main");local rt=first.owner.runtime
 check(rt:retireRecovered("main",request.serial,request.credential,request.life,1,2),"retired source fixture refused real retirement")
 first.drive(function() return rt.phase=="retired" end)
 first.server:removePlayer(first.player)
 local seed=Json.copy(first.b.data);seed.R_46001_free=nil;seed.R_46001_easy=nil
 local f=fixture({seedStore=seed});f.drive(function() return f.owner.runtime.phase=="offer_refused" and next(f.owner.queue)==nil end)
 check(f.client:offerInfo("main")==nil,"retired recovery was offered as Continue")
 local read,why=f.owner.runtime:discoverNewLife("main");assert(read,why)
 f.drive(function() return read.state=="offered" end)
 check(read.retired and read.continued,"explicit retired discovery lost provenance")
 local kept=originals(f);local policy,job=start(f,"main")
 drivePolicy(f,job,function() return job.state=="verified" end)
 check(originals(f)==kept,"retired source was substituted for its original archive")
 f.server:removePlayer(f.player)
end
-- A proposal changed after source preparation cannot be trusted at retirement.
do
 local f=fixture();f.recover("main");f.begin();f.drive(function() return f.client.transition==nil end)
 local policy,job=start(f,"main");local raw=Json.canonical(f.b.data.R_46001_main)
 drivePolicy(f,job,function() return job.phase=="proofArchive" end)
 local changed=Json.copy(f.b.data.M1_46001_main);changed.owner="someone-else";f.b:poke("M1_46001_main",changed)
 for _=1,1800 do f.tick();if job.state=="refused" then break end end
 check(job.state=="refused" and Json.canonical(f.b.data.R_46001_main)==raw,"changed immutable proposal was ignored")
 f.server:removePlayer(f.player)
end
-- Scope changes and remote lease loss never authorize a marker or touch a
-- foreign progress record. Refusal does not silently reopen the ordinary owner.
for _,fault in {"lease","account","load","provider"} do
 local f=fixture();local policy,job=start(f,"main");local kept=nonP(f.b)
 if fault=="lease" then
  local foreign=Json.copy(f.b.data.P_46001);foreign.lock={session="foreign-session",beat=f.clock.now};f.b:poke("P_46001",foreign)
 elseif fault=="account" then f.owner.session.cfg.userId=46002
 elseif fault=="load" then f.owner.session._loadSerial+=1
 else f.owner.session.backend.source={} end
 local foreign=Json.canonical(f.b.data.P_46001)
 for _=1,100 do f.tick();if job.state=="refused" then break end end
 check(job.state=="refused" and current(f,"main").credential==nil and nonP(f.b)==kept,"invalid "..fault.." scope made New durable")
 for _=1,100 do f.tick() end
 check(Json.canonical(f.b.data.P_46001)==foreign,"invalid "..fault.." scope renewed foreign progress")
 f.server:removePlayer(f.player)
end
for _,limits in {{maxRequests=1},{timeout=1}} do
 local f=fixture();limits.work={now=function() return 0 end};local policy,job=start(f,"main",limits)
 local before=f.b.requests;local kept=nonP(f.b)
 for _=1,10 do f.tick();if job.state=="refused" then break end end
 check(job.state=="refused" and nonP(f.b)==kept and f.b.requests-before<=1,"New exceeded its request/deadline cap")
 f.server:removePlayer(f.player)
end
-- Progress arriving after the first P verification is retained by the actual
-- final replacement payload/departure rather than an earlier snapshot.
do
 local f=fixture();local policy,job=start(f,"main")
 drivePolicy(f,job,function() return job.phase=="proofArchive" end)
 table.insert(f.progress.notebook.opened,"new_policy_late_note")
 drivePolicy(f,job,function() return job.state=="verified" end)
 local kept=originals(f);local old=f.owner;local epoch=f.client.bound.epoch
 check(f.client:requestReplacement(),"late progress replacement refused")
 f.drive(function() return f.client.transition==nil and f.client.bound.epoch~=epoch end)
 check(old:replacementClosed() and table.find(f.b.data.P_46001.payload.notebook.opened,"new_policy_late_note")~=nil and originals(f)==kept,"New lost final captured progress")
 f.server:removePlayer(f.player)
end
-- Actual provider suspension: replacement cannot overlap owners, and the
-- returning old read cannot continue into an archive or retirement write.
do
 local f=fixture();local policy,job=start(f,"main");local kept=nonP(f.b)
 drivePolicy(f,job,function() return job.phase=="source" and policy.leaseJob.phase=="renew" and f.owner.session.sched:budgetOk(f.clock.now) end)
 local before=f.b.requests
 check(not f.owner:prepareReplacement({}) and f.b.requests==before and job.state=="pending" and not f.owner.replacementPending,"invalid final progress began New replacement")
 table.insert(f.progress.notebook.opened,"new_provider_final_note")
 f.pauseReadKey="R_46001_main"
 local co=coroutine.create(function() f.tick() end);local ok,why=coroutine.resume(co);assert(ok,why)
 check(why=="new-provider-paused" and policy.busy and f.owner.session.busy,"New provider did not actually suspend")
 f.resumeRead=co;local old=f.owner;local epoch=f.client.bound.epoch
 check(f.client:requestReplacement(),"in-flight New could not request safe replacement")
 f.drive(function() return f.client.transition==nil and f.client.bound.epoch~=epoch end)
 check(coroutine.status(co)=="dead" and old:replacementClosed() and nonP(f.b)==kept
  and table.find(f.b.data.P_46001.payload.notebook.opened,"new_provider_final_note")~=nil,"late New provider revived the old owner, changed originals or lost final progress")
 f.server:removePlayer(f.player)
end
-- The active credential path is not a substitute for explicit readonly New.
do
 local f=fixture();offered(f,"main");local info=f.client:offerInfo("main")
 check(f.owner:requestLife("continue","main",1,info.id),"Continue control fixture refused")
 local before=f.b.requests;local policy=__newLifePolicy.new(f.owner.runtime,{work={now=function() return 0 end}})
 check(policy:begin("main",1,info.id)==nil and f.b.requests==before,"Continue was silently reinterpreted as New")
 f.server:removePlayer(f.player)
end
print("PROTECTED_NEW passed="..count.." failed=0")
end
runProtectedNewChecks()
end
