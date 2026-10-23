do
local function runFreshLifeChecks()
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Backend=require("../src/Server/DataStoreBackend")
local Rules=require("../src/Shared/Data/SaveRules")
local Rare=require("../src/Shared/Life/RareDirector")
local Mating=require("../src/Shared/Life/Mating")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function equal(a,b) return Json.canonical(a)==Json.canonical(b) end
local function tick(f)
 local n=f.b.requests;f.rt:step()
 check(f.b.requests-n<=1,"routine router made multiple requests per step")
 check(#f.s.sched.started<=Rules.REQUESTS_PER_MINUTE+(if f.rt.leaving then 8 else 0),"routine router exceeded quota plus bounded departure allowance")
 check(not f.rt.busy and not f.s.busy,"routine router retained busy flags")
 if f.s.backend.held then check(not f.s.backend:permitted(f.s.backend.held),"routine router leaked permit") end
 f.clock.now+=1
end
local function drive(f,done)
 for _=1,1600 do if done() then return end;tick(f) end
 error("routine router failed to settle: "..f.rt.phase.." "..tostring(f.rt.problem).." "..tostring(f.rt.saveLoop and f.rt.saveLoop.problem))
end
local function fixture(mode)
 mode=mode or "main"
 WorldMap.use("test_garden");local old=gardenWorld();old.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
 old.life.mode=if mode=="free" then "free" else "main";old.life.rules=if mode=="main" then "standard" else "gentle";old.needs.gentle=mode~="main"
 local src=assert(Checkpoint.capture(old,123));src.save_life="routine-life-"..mode
 WorldMap.use("preserve");local context=newWorld();context.life.mode=old.life.mode;context.life.rules=old.life.rules;context.needs.gentle=mode~="main"
 local templateHere=assert(Checkpoint.capture(context,124));local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 local gp=Json.copy(rawProgress.payload);gp.settings.MasterVolume=.2;if mode=="easy" then gp.finished_main=true end
 b:poke("P_46001",Envelope.make(Progress.SPEC,gp,100,nil));b:poke("R_46001_"..mode,codec:encode(Envelope.make(SaveRest.SPECS[mode],src,100,nil)))
 local ds={}
 function ds:GetAsync(key,options)
  check(options==nil or options.UseCache==false,"native facade received cached verification read")
  local ok,value,why=b:read(key);if not ok then error(why) end;return value
 end
 function ds:UpdateAsync(key,transform)
  local ok,value,why=b:update(key,transform);if not ok then error(why) end;return value
 end
 local normal=Backend.new(ds,codec);local raw=__rawBackendPrototype.new(ds)
 local clock={now=200};local stored,refused=0,0
 local rt=__runtimePrototype.new({backend=normal,userId=46001,sessionId="routine-"..mode,now=function() return clock.now end,sleep=function(dt) clock.now+=dt end,
  onStored=function() stored+=1 end,onRefused=function() refused+=1 end},
  {codec=codec,rawBackend=raw,template=templateHere,context=context,entryFactory=__entryPrototype,saveFactory=__saveLoopPrototype,
   reader={work={now=function() return 0 end}},pipeline={work={now=function() return 0 end}},entryOptions={work={now=function() return 0 end}},
   saveOptions={work={now=function() return 0 end},progress={work={now=function() return 0 end}}}})
 assert(rt:load()=="active");local s=rt.session;s:enableOffers();assert(rt:discover(mode))
 local f={b=b,normal=normal,raw=raw,clock=clock,rt=rt,s=s,mode=mode,context=context,stored=function() return stored end,refused=function() return refused end}
 drive(f,function() return rt.phase~="discovering" end);assert(rt.phase=="offered",rt.problem);assert(rt:accept(mode,1,rt.discovery.offer.id))
 drive(f,function() return rt.phase~="recovering" end);assert(rt.phase=="entry_required",rt.problem)
 local j=assert(rt:enter());drive(f,function() return j.state~="pending" or j.phase=="awaitApplied" end);assert(j.state=="pending",j.problem)
 f.world=newWorld();f.world.life.mode=old.life.mode;f.world.life.rules=old.life.rules;f.world.needs.gentle=mode~="main"
 local commit=assert(__entryClientPrototype.prepare(j.offer,f.world,function() return true end));assert(rt:entryApplied(assert(commit())))
 drive(f,function() return rt.phase~="entering" end);assert(rt.phase=="recovered",rt.problem)
 check(rt.saveLoop~=nil and s.backend.held.enforced,"routine owner did not retain barrier")
 return f
end
local function choose(f,value)
 local q=Json.copy(f.s.progress);q.settings.MasterVolume=value;assert(f.s:setProgress(q))
end
local function checkpoint(f,serial)
 local r=f.s.intents.requests[f.mode];local record=assert(Checkpoint.capture(f.world,f.clock.now));record.save_life=r.life
 return f.rt:saveRecovered(f.mode,r.serial,r.credential,r.life,serial,record),record
end
local function nonOwned(f)
 local q={};for k,v in f.b.data do if k~="P_46001" and k~="R_46001_"..f.mode then q[k]=v end end;return Json.canonical(q)
end
local function retire(f)
 local r=f.s.intents.requests[f.mode];assert(f.rt:retireRecovered(f.mode,r.serial,r.credential,r.life,1,2))
 drive(f,function() return f.rt.phase~="recovered" end);assert(f.rt.phase=="retired",f.rt.problem)
end
local function marker(f)
 assert(f.rt:prepareFreshLife());drive(f,function() return f.rt.phase~="freshening" end)
 assert(f.rt.phase=="fresh_ready",f.rt.problem)
end
local function loadedReplacement(f,id)
 local rt,why=f.rt:replaceFreshLife(id);assert(rt,why)
 check(f.s.closed and not f.s.lockHeld and f.rt.result.progressPreserved and f.rt.result.leaseReleased,"replacement started before old owner closed/released")
 check(not rt.session.closed and rt.session.id==id and rt.session.backend~=f.s.backend and rt.session.backend.source==f.normal,"replacement reused old session/sidecar/provider")
 local n=f.b.requests;check(f.rt:replaceFreshLife(id)==rt and f.b.requests==n,"replacement retry constructed or loaded another owner")
 check(f.rt:replaceFreshLife(id.."-other")==nil,"replacement allowed another identity")
 assert(rt:load()=="active");rt.session:enableOffers()
 local nextVisit={rt=rt,s=rt.session,b=f.b,clock=f.clock,mode=f.mode}
 drive(nextVisit,function() return rt.session:offer(f.mode)~=nil end)
 return nextVisit
end
for _,mode in Rules.MODES do
 local f=fixture(mode);local original=nonOwned(f);local r=f.s.intents.requests[mode];local oldCredential=r.credential
 local n=f.b.requests;check(f.rt:prepareFreshLife()==nil and f.b.requests==n,"active life was rewritten as fresh marker")
 retire(f);choose(f,.73);marker(f)
 local opened=Envelope.open(SaveRest.SPECS[mode],codec:decode(f.b.data["R_46001_"..mode]))
 check(opened.status=="ok" and opened.schema==SaveRest.SCHEMA and opened.payload.save_retired and opened.payload.save_life==f.s.id..":"..mode..":2","normal marker not independently readable")
 check(opened.payload.checkpoint==nil and opened.payload.provenance==nil and opened.payload.format==nil,"fresh marker smuggled old life data")
 check(nonOwned(f)==original and r.state=="changed" and r.credential==nil and not f.rt.result.gameplayAuthorized,"marker changed archive or granted a life")
 n=f.b.requests;check(f.rt:replaceFreshLife(f.s.id)==nil and f.b.requests==n,"replacement reused old server identity")
 local nextVisit=loadedReplacement(f,"fresh-life-"..mode);local rt,s=nextVisit.rt,nextVisit.s
 check(s.progress.settings.MasterVolume==.73,"replacement lost latest old-session progress")
 check(rt:requestFreshLife(),"actual displayed marker New Life refused")
 local nextRequest=s.intents.requests[mode]
 check(nextRequest.kind=="new" and nextRequest.serial==2 and nextRequest.state=="readonly" and nextRequest.credential==nil,"New Life granted before normal durable retirement")
 drive(nextVisit,function() return nextRequest.state=="writable" or s.state~="active" end)
 check(nextRequest.state=="writable" and nextRequest.life=="fresh-life-"..mode..":"..mode..":2" and nextRequest.credential~=oldCredential,"normal New Life did not issue a distinct actual credential")
 local _state,loaded=f.rt:load();check(not f.s:setRestForIntent(mode,{},r.life,r.serial,oldCredential,2) and loaded==false and f.s.closed,"closed old owner revived")
 local world=newWorld();world.life.mode=if mode=="free" then "free" else "main";world.life.rules=if mode=="main" then "standard" else "gentle";world.needs.gentle=mode~="main"
 check(world.life.recoveryHistory==nil,"fresh world inherited recovered history")
 local record=assert(Checkpoint.capture(world,f.clock.now))
 check(s:setRestForIntent(mode,record,nextRequest.life,nextRequest.serial,nextRequest.credential,1),"new life could not queue a normal checkpoint")
 drive(nextVisit,function() return nextRequest.storedSerial==1 or s.state~="active" end)
 local stored=Envelope.open(SaveRest.SPECS[mode],codec:decode(f.b.data["R_46001_"..mode]))
 check(nextRequest.storedSerial==1 and stored.status=="ok" and stored.payload.save_life==nextRequest.life and not stored.payload.save_retired,"new normal checkpoint did not store")
 check(nonOwned(f)==original,"fresh life changed immutable original archive/proposal or other slots")
 rt:flush();check(s.closed and f.b.data.P_46001.lock==nil,"fresh normal departure failed")
 local cfg={};for k,v in rt.config do cfg[k]=v end;cfg.backend=f.normal;cfg.sessionId="fresh-rejoin-"..mode
 local third=__runtimePrototype.new(cfg,rt.recovery);assert(third:load()=="active");third.session:enableOffers()
 local again={rt=third,s=third.session,b=f.b,clock=f.clock,mode=mode};drive(again,function() return third.session:offer(mode)~=nil end)
 local offer=third.session:offer(mode);check(not offer.protected and offer.record.save_life==nextRequest.life,"normal new-life rest not offered on later visit")
 check(third.session:requestLife("continue",mode,1,offer.id),"normal Continue refused after fresh life")
 drive(again,function() return third.session.intents.requests[mode].state=="writable" end)
 check(third.session.intents.requests[mode].life==nextRequest.life and nonOwned(f)==original,"later Continue revived imported life or altered originals")
 third:flush()
end
for _,afterWrite in {false,true} do
 local f=fixture();retire(f);assert(f.rt:prepareFreshLife())
 drive(f,function() return f.rt.freshJob and f.rt.freshJob.phase=="write" and f.s.sched:budgetOk(f.clock.now) end)
 f.b:fail({op="update",key="R_46001_main",afterWrite=afterWrite,message="timeout"})
 drive(f,function() return f.rt.phase~="freshening" end)
 check(f.rt.phase=="fresh_ready" and not f.rt.result.gameplayAuthorized,"ambiguous fresh marker did not verify without grant")
 f.rt:flush()
end
-- A changed checkpoint cannot be turned into an ordinary retirement marker.
do
 local f=fixture();retire(f);assert(f.rt:prepareFreshLife())
 drive(f,function() return f.rt.freshJob and f.rt.freshJob.phase=="write" end)
 local raw=Json.copy(f.b.data.R_46001_main);raw.session="another-writer";f.b:poke("R_46001_main",raw)
 drive(f,function() return f.rt.phase~="freshening" end)
 check(f.rt.phase=="lost" and equal(f.b.data.R_46001_main,raw) and f.rt:replaceFreshLife("not-allowed")==nil,"fresh bridge overwrote changed rest or replaced failed owner")
 f.rt:flush()
end
-- Even after safe replacement, selection must match the exact bridge marker.
do
 local f=fixture();retire(f);marker(f);local nextVisit=loadedReplacement(f,"changed-before-new-life")
 local logical=codec:decode(f.b.data.R_46001_main);local raw=Envelope.make(SaveRest.SPECS.main,Json.copy(logical.payload),logical.updatedAt+1,logical,{session="other-marker"});f.b:poke("R_46001_main",codec:encode(raw))
 nextVisit.s:refreshOffer("main");drive(nextVisit,function() return nextVisit.s.previewPending.main==nil end)
 local n=f.b.requests;check(not nextVisit.rt:requestFreshLife() and f.b.requests==n,"fresh choice silently rebound to changed marker")
 nextVisit.rt:flush()
end
-- An unverified release must not create a second owner.
do
 local f=fixture();retire(f);marker(f)
 local raw=Json.copy(f.b.data.P_46001);raw.lock={session="foreign-owner",beat=f.clock.now};f.b:poke("P_46001",raw)
 local replacement=f.rt:replaceFreshLife("blocked-release",f.clock.now+8)
 check(replacement==nil and f.rt.replacement==nil and f.s.closed,"failed release created fresh session")
end
-- A new server can resume an explicit New Life after a crash/visit ended at schema3 retirement.
do
 local f=fixture();retire(f);local original=nonOwned(f);f.rt:flush();assert(f.s.closed)
 local dep={};for k,v in f.rt.recovery do dep[k]=v end;dep.currentFormat=__restFormatPrototype;dep.freshWriterFactory=__currentWriterPrototype
 local cfg={backend=f.normal,userId=46001,sessionId="retired-cold-resume",now=function() return f.clock.now end,sleep=function(dt) f.clock.now+=dt end}
 local rt=__runtimePrototype.new(cfg,dep);assert(rt:load()=="active");rt.session:enableOffers();assert(rt:discoverNewLife("main"))
 local resumed={rt=rt,s=rt.session,b=f.b,normal=f.normal,clock=f.clock,mode="main"}
 drive(resumed,function() return rt.phase~="discovering" end)
 check(rt.phase=="offered" and rt.discovery.retired and rt.discovery.offer.record.save_retired,"retired New Life not offered explicitly")
 local offer=rt.discovery.offer;check(rt:accept("main",1,offer.id)==nil,"retired observation admitted Continue")
 check(rt:acceptRetiredFresh("main",1,offer.id)~=nil,"cold explicit New Life choice refused")
 check(rt.retiredRequest.state=="readonly" and rt.retiredRequest.credential==nil and not rt.result.gameplayAuthorized,"cold retirement manufactured a life credential")
 marker(resumed);local nextVisit=loadedReplacement(resumed,"cold-fresh-life")
 check(nextVisit.rt:requestFreshLife(),"cold replacement New Life refused")
 drive(nextVisit,function() return nextVisit.s.intents.requests.main.state=="writable" end)
 check(nextVisit.s.intents.requests.main.life=="cold-fresh-life:main:1" and nonOwned(f)==original,"cold New Life used stale request serial or changed originals")
 nextVisit.rt:flush()
end
print("RECOVERY_FRESH_LIFE passed="..count.." failed=0")
end
runFreshLifeChecks()
end
