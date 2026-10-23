do
local function runRetirementChecks()
local Memory=require("../src/Shared/Persistence/MemoryBackend")
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
 local clock={now=200};local stored,refused=0,0
 local rt=__runtimePrototype.new({backend=b,userId=46001,sessionId="routine-"..mode,now=function() return clock.now end,sleep=function(dt) clock.now+=dt end,
  onStored=function() stored+=1 end,onRefused=function() refused+=1 end},
  {codec=codec,rawBackend=b,template=templateHere,context=context,entryFactory=__entryPrototype,saveFactory=__saveLoopPrototype,
   reader={work={now=function() return 0 end}},pipeline={work={now=function() return 0 end}},entryOptions={work={now=function() return 0 end}},
   saveOptions={work={now=function() return 0 end},progress={work={now=function() return 0 end}}}})
 assert(rt:load()=="active");local s=rt.session;s:enableOffers();assert(rt:discover(mode))
 local f={b=b,clock=clock,rt=rt,s=s,mode=mode,context=context,stored=function() return stored end,refused=function() return refused end}
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
for _,mode in Rules.MODES do
 local f=fixture(mode);local originals=nonOwned(f);choose(f,.67)
 local restSerial=1;local storedBefore=0
 if mode=="free" then
  check(checkpoint(f,1),"pre-retirement continued checkpoint refused");drive(f,function() return f.stored()==1 end);restSerial=2;storedBefore=1
 end
 local r=f.s.intents.requests[mode];local credential=r.credential;local life=r.life;local n=f.b.requests
 check(not f.rt:retireRecovered(mode,r.serial,"wrong",life,restSerial,2),"wrong credential queued retirement")
 for _,v in {0,1,1.5,0/0,math.huge,Rules.MAX_LIFE_SERIAL+1} do
  check(not f.rt:retireRecovered(mode,r.serial,credential,life,restSerial,v),"invalid New Life serial accepted")
 end
 check(f.b.requests==n,"retirement admission performed provider I/O")
 check(f.rt:retireRecovered(mode,r.serial,credential,life,restSerial,2),"explicit retirement was refused")
 check(not checkpoint(f,restSerial),"old rest accepted during retirement")
 check(not f.rt:retireRecovered(mode,r.serial,credential,life,restSerial,2),"duplicate retirement replaced work")
 drive(f,function() return f.rt.phase~="recovered" end)
 check(f.rt.phase=="retired" and f.rt.result.retired and not f.rt.result.gameplayAuthorized,"retirement did not install terminal route: "..tostring(f.rt.problem))
 local marker=codec:decode(f.b.data["R_46001_"..mode]);local opened=__restFormatPrototype.open(mode,marker,f.context)
 check(opened.status=="ok" and opened.payload.save_retired and opened.payload.save_life==f.s.id..":"..mode..":2","durable retirement marker differs")
 check(__restFormatPrototype.matchesProposal(opened.payload,f.rt.result.anchor,codec,f.context),"retirement lost original provenance")
 check(r.state=="changed" and r.reason=="life_retired" and not f.s.intents:authorized(mode,r.serial,credential,life),"old life authority survived retirement")
 check(f.s.rests[mode]==nil and f.rt.saveLoop.writer.current==nil and f.rt.result.checkpoint==nil and f.stored()==storedBefore,"retirement exposed old checkpoint or ordinary stored receipt")
 check(f.b.data.P_46001.payload.settings.MasterVolume==.67,"retirement preceded captured durable progress")
 check(not f.s:setRestForIntent(mode,{},life,r.serial,credential,2),"late old checkpoint accepted")
 local unchanged=Json.canonical(f.b.data["R_46001_"..mode]);for _=1,80 do tick(f) end
 check(f.rt.phase=="retired" and Json.canonical(f.b.data["R_46001_"..mode])==unchanged and nonOwned(f)==originals,"retired idle changed rest/archive")
 choose(f,.91);f.rt:flush();check(f.s.closed and f.rt.result.progressPreserved and f.b.data.P_46001.lock==nil and f.b.data.P_46001.payload.settings.MasterVolume==.91,"retired departure failed or lost later progress")
 local config={backend=f.b,userId=46001,sessionId="retired-return-"..mode,now=function() return f.clock.now end,sleep=function(dt) f.clock.now+=dt end}
 local dep={};for k,v in f.rt.recovery do dep[k]=v end;dep.currentFormat=__restFormatPrototype
 local rt=__runtimePrototype.new(config,dep);assert(rt:load()=="active");rt.session:enableOffers();assert(rt:discover(mode))
 local nextVisit={rt=rt,s=rt.session,b=f.b,clock=f.clock};drive(nextVisit,function() return rt.phase~="discovering" end)
 check(rt.phase=="offer_refused" and not rt.discovery.offer,"new visit offered retired checkpoint or its active backup")
 check(Json.canonical(f.b.data["R_46001_"..mode])==unchanged and nonOwned(f)==originals,"retired discovery mutated durable original")
 rt:flush()
end
for _,afterWrite in {false,true} do
 local f=fixture();local r=f.s.intents.requests.main;local originals=nonOwned(f)
 assert(f.rt:retireRecovered("main",r.serial,r.credential,r.life,1,2))
 drive(f,function() return f.rt.saveLoop.restJob and f.rt.saveLoop.restJob.phase=="write" and f.s.sched:budgetOk(f.clock.now) end)
 f.b:fail({op="update",key="R_46001_main",afterWrite=afterWrite,message="timeout"})
 drive(f,function() return f.rt.phase~="recovered" end)
 check(f.rt.phase=="retired" and nonOwned(f)==originals,"ambiguous retirement failed to verify idempotently")
 f.rt:flush()
end
-- A competing checkpoint must never be retired based on an older capture.
do
 local f=fixture();local r=f.s.intents.requests.main;assert(f.rt:retireRecovered("main",r.serial,r.credential,r.life,1,2))
 drive(f,function() return f.rt.saveLoop.restJob and f.rt.saveLoop.restJob.phase=="write" end)
 local foreign=Json.copy(f.b.data.R_46001_main);foreign.session="foreign";f.b:poke("R_46001_main",foreign)
 drive(f,function() return f.rt.phase~="recovered" end)
 check(f.rt.phase=="lost" and equal(f.b.data.R_46001_main,foreign),"retirement overwrote changed raw checkpoint")
 check(r.state~="writable","failed retirement retained writable authority")
 f.rt:flush()
end
-- Cancellation during preparation cannot publish a marker.
do
 local f=fixture();local r=f.s.intents.requests.main;local before=Json.canonical(f.b.data.R_46001_main)
 assert(f.rt:retireRecovered("main",r.serial,r.credential,r.life,1,2));f.rt:depart(f.clock.now+8)
 drive(f,function() return f.rt.phase=="closed" end)
 check(Json.canonical(f.b.data.R_46001_main)==before,"departure during preparation published retirement")
end
-- Retirement is installed before a yielding decision; late completion cannot revive it.
do
 local f=fixture();local r=f.s.intents.requests.main;local oldCredential=r.credential
 assert(f.rt:retireRecovered("main",r.serial,r.credential,r.life,1,2))
 drive(f,function() return f.rt.saveLoop.restJob and f.rt.saveLoop.restJob.phase=="finalLease" and f.s.sched:budgetOk(f.clock.now) end)
 f.s.intents.emit=function(message) if message.reason=="life_retired" then coroutine.yield("retired callback") end end
 local thread=coroutine.create(function() f.rt:step() end)
 local ok,why=coroutine.resume(thread);check(ok and why=="retired callback" and coroutine.status(thread)=="suspended","retirement decision did not yield at installed boundary")
 check(f.rt.phase=="retired" and f.rt.result.retired and r.credential==nil and not f.s.intents:authorized("main",r.serial,oldCredential,r.life),"yielded retirement retained old authority")
 check(not checkpoint(f,2),"yielded decision accepted old-life checkpoint")
 f.rt:depart(f.clock.now);check(f.rt.phase=="closed" and f.s.closed,"departure during retirement decision failed to close")
 check(coroutine.resume(thread) and coroutine.status(thread)=="dead" and f.rt.phase=="closed" and f.s.closed,"late retirement callback revived closed route")
end
print("RECOVERY_RETIREMENT passed="..count.." failed=0")
end
runRetirementChecks()
end
