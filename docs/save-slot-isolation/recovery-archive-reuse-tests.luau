do
local function runArchiveReuseChecks()
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
local function fixture(mode,reuse)
 mode=mode or "main"
 WorldMap.use("test_garden");local old=gardenWorld();old.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
 old.life.mode=if mode=="free" then "free" else "main";old.life.rules=if mode=="main" then "standard" else "gentle";old.needs.gentle=mode~="main"
 local src=assert(Checkpoint.capture(old,123));src.save_life="routine-life-"..mode
 WorldMap.use("preserve");local context=newWorld();context.life.mode=old.life.mode;context.life.rules=old.life.rules;context.needs.gentle=mode~="main"
 local templateHere=assert(Checkpoint.capture(context,124));local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 local gp=Json.copy(rawProgress.payload);gp.settings.MasterVolume=.2;gp.finished_main=true
 b:poke("P_46001",Envelope.make(Progress.SPEC,gp,100,nil))
 WorldMap.use("test_garden")
 for _,slot in Rules.MODES do
  old.life.mode=if slot=="free" then "free" else "main";old.life.rules=if slot=="main" then "standard" else "gentle";old.needs.gentle=slot~="main"
  local record=assert(Checkpoint.capture(old,123));record.save_life="reuse-origin-"..slot
  b:poke("R_46001_"..slot,codec:encode(Envelope.make(SaveRest.SPECS[slot],record,100,nil)))
 end
 old.life.mode=if mode=="free" then "free" else "main";old.life.rules=if mode=="main" then "standard" else "gentle";old.needs.gentle=mode~="main"
 WorldMap.use("preserve")
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
   reader={work={now=function() return 0 end}},pipeline={reuseCompleteOriginal=reuse==true,work={now=function() return 0 end}},entryOptions={work={now=function() return 0 end}},
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
local function archives(b)
 local q={};for k,v in b.data do if string.sub(k,1,3)=="A1_" then q[k]=v end end;return Json.canonical(q)
end
local function otherRests(b,mode)
 local q={};for _,slot in Rules.MODES do if slot~=mode then q[slot]=b.data["R_46001_"..slot] end end;return Json.canonical(q)
end
local function newVisit(first,mode,id,reuse)
 local world=newWorld();world.life.mode=if mode=="free" then "free" else "main";world.life.rules=if mode=="main" then "standard" else "gentle";world.needs.gentle=mode~="main"
 local dep={};for k,v in first.rt.recovery do dep[k]=v end
 dep.template=assert(Checkpoint.capture(world,first.clock.now));dep.context=world;dep.currentFormat=__restFormatPrototype
 dep.pipeline={reuseCompleteOriginal=reuse==true,work={now=function() return 0 end}}
 local rt=__runtimePrototype.new({backend=first.normal,userId=46001,sessionId=id,now=function() return first.clock.now end,sleep=function(dt) first.clock.now+=dt end},dep)
 assert(rt:load()=="active");rt.session:enableOffers();assert(rt:discover(mode))
 local f={rt=rt,s=rt.session,b=first.b,normal=first.normal,raw=first.raw,clock=first.clock,mode=mode,context=world}
 drive(f,function() return rt.phase~="discovering" end);assert(rt.phase=="offered",rt.problem)
 return f
end
local function enter(f)
 local rt=f.rt;assert(rt.phase=="entry_required",rt.problem)
 local j=assert(rt:enter());drive(f,function() return j.state~="pending" or j.phase=="awaitApplied" end)
 assert(j.state=="pending",j.problem)
 f.world=newWorld();f.world.life.mode=f.context.life.mode;f.world.life.rules=f.context.life.rules;f.world.needs.gentle=f.mode~="main"
 local apply=assert(__entryClientPrototype.prepare(j.offer,f.world,function() return true end));assert(rt:entryApplied(assert(apply())))
 drive(f,function() return rt.phase~="entering" end);assert(rt.phase=="recovered",rt.problem)
 check(f.s.intents.requests[f.mode].state=="writable" and f.rt.result.gameplayAuthorized,"later slot did not receive actual entry-issued authority")
end
local function recover(f)
 local rt=f.rt;local start=#f.b.log;assert(rt:accept(f.mode,1,rt.discovery.offer.id))
 drive(f,function() return rt.phase~="recovering" or rt.job.phase=="archive" end)
 local originalJob=if rt.phase=="recovering" then rt.job.child else nil;local archiveStart=#f.b.log;local started=f.clock.now
 drive(f,function() return rt.phase~="recovering" or rt.job.phase~="archive" end)
 if originalJob and originalJob.reusedOriginal then
  check(originalJob.state=="ready","reused complete archive was not ready")
  for i=archiveStart+1,#f.b.log do
   local row=f.b.log[i]
   check(not (row.op=="update" and string.sub(row.key,1,3)=="A1_"),"reuse wrote immutable archive")
   check(not (row.op=="read" and string.sub(row.key,1,2)=="R_" and row.key~="R_46001_"..f.mode),"reuse read unrelated current rest")
  end
  print("RECOVERY_ARCHIVE_REUSE slot="..f.mode.." archive_requests="..originalJob.requests.." archive_simulated_seconds="..(f.clock.now-started))
 end
 drive(f,function() return rt.phase~="recovering" end)
 for i=start+1,#f.b.log do local row=f.b.log[i];check(not (row.op=="update" and string.sub(row.key,1,3)=="A1_" and originalJob and originalJob.reusedOriginal),"later import republished immutable archive") end
 return originalJob
end
-- The former strict source-matrix path is the reproducible counterexample.
do
 local first=fixture("main",false);local oldArchive=archives(first.b);first.rt:flush()
 local later=newVisit(first,"free","strict-later-slot",false);assert(later.rt:accept("free",1,later.rt.discovery.offer.id))
 drive(later,function() return later.rt.phase~="recovering" end)
 check(later.rt.phase=="held" and later.s.intents.requests.free.credential==nil,"strict counterexample unexpectedly entered later slot")
 check(archives(first.b)==oldArchive and first.b.data.M1_46001_free==nil,"strict refusal changed original archive/proposal")
 later.rt:flush()
end
-- Recover main, start and save a fresh main life, then import the untouched free/easy originals.
do
 local first=fixture("main",true);local oldArchive=archives(first.b);local firstProposal=Json.canonical(first.b.data.M1_46001_main)
 retire(first);marker(first);local normal=loadedReplacement(first,"new-main-before-other-slots");assert(normal.rt:requestFreshLife())
 drive(normal,function() return normal.s.intents.requests.main.state=="writable" end)
 local r=normal.s.intents.requests.main;local world=newWorld();local q=Json.copy(normal.s.progress);Rare.beginLife(q.rare,world.life);q.settings.MasterVolume=.77;q.notebook.opened={"later_original_slot"};assert(normal.s:setProgress(q))
 drive(normal,function() return not normal.s.sched:isDirty("progress") end)
 assert(normal.s:setRestForIntent("main",assert(Checkpoint.capture(world,first.clock.now)),r.life,r.serial,r.credential,1))
 drive(normal,function() return r.storedSerial==1 end);normal.rt:flush()
 local freshMain=Json.canonical(first.b.data.R_46001_main);local serial=first.b.data.P_46001.payload.rare.serial
 for _,mode in {"free","easy"} do
  local f=newVisit(first,mode,"later-original-"..mode,true);local other=otherRests(f.b,mode)
  local archivedJob=recover(f);check(archivedJob and archivedJob.reusedOriginal,"later slot did not reuse complete original archive")
  check(f.rt.phase=="entry_required","later import refused: "..tostring(f.rt.problem))
  enter(f)
  check(f.world.life.recoveryHistory.origin.save_life=="reuse-origin-"..mode and f.s.progress.settings.MasterVolume==.77,"later import used another life or old global choices")
  check(f.s.progress.rare.serial>=serial,"later import rewound global rare serial");serial=f.s.progress.rare.serial
  check(otherRests(f.b,mode)==other and archives(f.b)==oldArchive and Json.canonical(f.b.data.M1_46001_main)==firstProposal,"later import altered another live slot or original archive/proposal")
  check(Json.canonical(f.b.data.R_46001_main)==freshMain,"later import overwrote the fresh main life with archived main")
  f.rt:flush();check(f.s.closed and f.rt.result.progressPreserved,"later-slot departure failed")
 end
end
for _,fault in {"selected-changed","complete-corrupt","complete-part-missing","index-missing"} do
 local first=fixture("main",true);first.rt:flush()
 if fault=="selected-changed" then
  local logical=codec:decode(first.b.data.R_46001_free);logical.session="changed-original-metadata";first.b:poke("R_46001_free",codec:encode(logical))
 elseif fault=="complete-corrupt" then local p=Json.copy(first.b.data.A1_46001_index);p.complete=false;first.b:poke("A1_46001_index",p)
 elseif fault=="complete-part-missing" then first.b:poke("A1_46001_easy",nil)
 else first.b:poke("A1_46001_index",nil) end
 local f=newVisit(first,"free","reuse-refuse-"..fault,true);local original=archives(first.b);local raw=Json.canonical(first.b.data.R_46001_free)
 recover(f)
 check(f.rt.phase=="held" and f.s.intents.requests.free.credential==nil,"unsafe original reuse entered: "..fault)
 check(archives(first.b)==original and Json.canonical(first.b.data.R_46001_free)==raw and first.b.data.M1_46001_free==nil,"unsafe reuse changed original/source: "..fault)
 f.rt:flush()
end
-- Even an unsupported unrelated current record is irrelevant to read-only reuse.
do
 local first=fixture("main",true);first.rt:flush();first.b:poke("R_46001_main",{format=Rules.FORMAT,kind=SaveRest.SPECS.main.kind,schema=99,updatedAt=first.clock.now,unknown="untouched future life"})
 local current=Json.canonical(first.b.data.R_46001_main);local original=archives(first.b);local f=newVisit(first,"free","unrelated-future-slot",true)
 check(f.s.restProtected.main=="newer","future unrelated slot was not protected")
 local j=recover(f);check(j and j.reusedOriginal and f.rt.phase=="entry_required","unrelated future slot prevented read-only original reuse")
 enter(f);check(Json.canonical(first.b.data.R_46001_main)==current and archives(first.b)==original,"future unrelated slot or original archive was changed")
 f.rt:flush()
end
-- Revoking consent while an actual adapter read yields cancels reuse before any write.
do
 local first=fixture("main",true);first.rt:flush();local f=newVisit(first,"free","reuse-yield-cancel",true)
 local original=archives(first.b);local raw=Json.canonical(first.b.data.R_46001_free)
 assert(f.rt:accept("free",1,f.rt.discovery.offer.id))
 drive(f,function() return f.rt.job.phase=="archive" and f.rt.job.child.phase=="originalRead" and f.rt.job.child.originalSlot=="free" and f.s.sched:budgetOk(f.clock.now) end)
 local read=first.normal.readRawFresh;local paused=false
 first.normal.readRawFresh=function(self,key)
  if key=="A1_46001_free" and not paused then paused=true;coroutine.yield("reuse read") end
  return read(self,key)
 end
 local thread=coroutine.create(function() f.rt:step() end);local ok,why=coroutine.resume(thread)
 check(ok and why=="reuse read" and f.s.busy,"archive read did not yield under real worker serialization")
 check(f.s:requestLife("new","free",2,nil),"replacement consent did not supersede old Continue")
 check(coroutine.resume(thread) and coroutine.status(thread)=="dead","revoked archive read failed to resume")
 first.normal.readRawFresh=read
 check(f.rt.phase=="held" and not f.s.busy and not f.rt.busy and not f.s.backend:permitted(f.s.backend.held),"revoked archive reuse retained worker/permit or entered")
 check(archives(first.b)==original and Json.canonical(first.b.data.R_46001_free)==raw and first.b.data.M1_46001_free==nil,"revoked reuse wrote archive/source/proposal")
 f.rt:flush()
end
print("RECOVERY_ARCHIVE_REUSE passed="..count.." failed=0")
end
runArchiveReuseChecks()
end
