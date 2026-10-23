do
local function runRejoinChecks()
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Rules=require("../src/Shared/Data/SaveRules")
local Mating=require("../src/Shared/Life/Mating")
local Mate=require("../src/Shared/Predator/Mate")
local Rare=require("../src/Shared/Life/RareDirector")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function equal(a,b) return Json.canonical(a)==Json.canonical(b) end
local function tick(f)
 local n=f.b.requests;f.rt:step()
 check(f.b.requests-n<=1,"rejoin router made multiple requests per step")
 check(#f.s.sched.started<=Rules.REQUESTS_PER_MINUTE,"rejoin router exceeded shared quota")
 check(not f.rt.busy and not f.s.busy,"rejoin router retained busy flags")
 if f.s.backend.held then check(not f.s.backend:permitted(f.s.backend.held),"rejoin leaked permit") end
 f.clock.now+=1
end
local function drive(f,done)
 for _=1,2000 do if done() then return end;tick(f) end
 error("rejoin did not settle: "..f.rt.phase.." "..tostring(f.rt.problem))
end
local function visit(b,clock,mode,serial,kind)
 local w=newWorld();w.life.mode=if mode=="free" then "free" else "main";w.life.rules=if mode=="main" then "standard" else "gentle";w.needs.gentle=mode~="main"
 local stored=0
 local rt=__runtimePrototype.new({backend=b,userId=46001,sessionId="rejoin-"..mode.."-"..serial,now=function() return clock.now end,sleep=function(dt) clock.now+=dt end,onStored=function() stored+=1 end},
  {codec=codec,rawBackend=b,template=assert(Checkpoint.capture(w,clock.now)),context=w,currentFormat=__restFormatPrototype,
   entryFactory=__entryPrototype,saveFactory=__saveLoopPrototype,reader={work={now=function() return 0 end}},pipeline={work={now=function() return 0 end}},
   entryOptions={work={now=function() return 0 end}},saveOptions={work={now=function() return 0 end},progress={work={now=function() return 0 end}}}})
 local f={b=b,clock=clock,rt=rt,s=rt.session,mode=mode,context=w,stored=function() return stored end,startRequests=b.requests,startTime=clock.now}
 assert(rt:load()=="active");rt.session:enableOffers();assert(rt:discover(mode,kind))
 drive(f,function() return rt.phase~="discovering" end)
 return f
end
local function enter(f)
 local rt=f.rt;assert(rt.phase=="offered",rt.problem)
 local raw=Json.canonical(f.b.data["R_46001_"..f.mode]);local continued=rt.discovery.continued
 assert(rt:accept(f.mode,1,rt.discovery.offer.id))
 if rt.phase=="recovering" then drive(f,function() return rt.phase~="recovering" end) end
 assert(rt.phase=="entry_required",rt.problem)
 if not continued then raw=Json.canonical(f.b.data["R_46001_"..f.mode]) end
 local j=assert(rt:enter());drive(f,function() return j.state~="pending" or j.phase=="awaitApplied" end)
 assert(j.state=="pending",j.problem)
 local w=newWorld();w.life.mode=if f.mode=="free" then "free" else "main";w.life.rules=if f.mode=="main" then "standard" else "gentle";w.needs.gentle=f.mode~="main"
 local commit,why=__entryClientPrototype.prepare(j.offer,w,function() return true end);assert(commit,why)
 assert(rt:entryApplied(assert(commit())));drive(f,function() return rt.phase~="entering" end)
 check(rt.phase=="recovered" and rt.result.gameplayAuthorized,"rejoin did not grant actual life: "..tostring(rt.problem))
 check(Json.canonical(f.b.data["R_46001_"..f.mode])==raw,"entry replayed/replaced current rest")
 f.world=w;return j
end
local function originals(b)
 local q={};for k,v in b.data do if string.sub(k,1,3)=="A1_" or string.sub(k,1,3)=="M1_" then q[k]=v end end;return Json.canonical(q)
end
local function nonPUpdates(b,start)
 local n=0;for i=start+1,#b.log do local row=b.log[i];if row.op=="update" and row.key~="P_46001" then n+=1 end end;return n
end
local function advance(f,serial,value,nextGeneration,scene)
 local l=f.world.life
 if nextGeneration then
  l.growth.stage=3;l.mating=Mating.new();l.mating.stage="hatched";l.mating.hatch_day=l.clock.day;l.mating.brood=3
  Mating.carryOn(l,f.world.needs,f.world.prey.feeding.mealsFinished)
  local q=Json.copy(f.s.progress);Rare.ensureLife(q.rare,l);assert(f.s:setProgress(q))
 end
 if scene then
  l.growth.stage=3;l.mating=Mating.new();l.mating.stage=scene
  if scene=="courted" then l.mate=Mate.new();l.mate.scene=true;l.mate.state="pair";l.mate.meter=1
  else l.mating.hatch_day=l.clock.day;l.mating.hatch_hour=7;l.mating.brood=3 end
 else l:step(.2,{inRetreat=true,attached=true,still=true,holding=false,feeding=false,position=f.world.motor.pos},false,false) end
 local q=Json.copy(f.s.progress);q.settings.MasterVolume=value;table.insert(q.notebook.opened,"visit_"..serial);assert(f.s:setProgress(q))
 local r=f.s.intents.requests[f.mode];local record=assert(Checkpoint.capture(f.world,f.clock.now));record.save_life=r.life
 assert(f.rt:saveRecovered(f.mode,r.serial,r.credential,r.life,serial,record))
 drive(f,function() return r.storedSerial==serial or f.rt.phase~="recovered" end)
 check(f.rt.phase=="recovered" and r.storedSerial==serial,"rejoined life could not save: "..tostring(f.rt.problem))
 return {generation=l.generation,elapsed=l.elapsed,rareSerial=l.rareSerial,mating=if l.mating then l.mating.stage else "none"}
end
local function initial(mode,compressed,backup)
 WorldMap.use("test_garden");local old=gardenWorld();old.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
 old.life.mode=if mode=="free" then "free" else "main";old.life.rules=if mode=="main" then "standard" else "gentle";old.needs.gentle=mode~="main"
 local record=assert(Checkpoint.capture(old,123));record.save_life="rejoin-original-"..mode
 WorldMap.use("preserve")
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 local g=Json.copy(rawProgress.payload);if mode=="easy" then g.finished_main=true end
 b:poke("P_46001",Envelope.make(Progress.SPEC,g,100,nil))
 local raw=Envelope.make(SaveRest.SPECS[mode],record,100,Envelope.make(SaveRest.SPECS[mode],record,90,nil))
 if backup then raw.checksum="corrupt-primary" end
 b:poke("R_46001_"..mode,if compressed then codec:encode(raw) else raw)
 local clock={now=200};local f=visit(b,clock,mode,1,if backup then "backup" else nil)
 check(not f.rt.discovery.continued,"cold legacy source was mislabeled continued")
 enter(f);return f
end
for _,mode in Rules.MODES do
 for _,compressed in {false,true} do
  local first=initial(mode,compressed);local b,clock=first.b,first.clock;local kept=originals(b)
  local expected=advance(first,1,.55,true)
  first.rt:flush();assert(first.s.closed and first.rt.result.progressPreserved)
  if not compressed then b:poke("R_46001_"..mode,codec:decode(b.data["R_46001_"..mode])) end
  clock.now+=1;local start=#b.log;local second=visit(b,clock,mode,2)
  check(second.rt.phase=="offered" and second.rt.discovery.continued and not second.rt.discovery.pending,"continued checkpoint was not discovered")
  check(second.rt.discovery.archivePlan==nil and second.s.restProtected[mode],"discovery retained archive copy or opened ordinary writes")
  local selected=second.rt.discovery.identity
  enter(second)
  check(second.rt.pipeline.current==nil and second.rt.job==nil and second.rt.continuedSelection.identity==selected,"returning session started original migration")
  check(second.world.life.generation==expected.generation and second.world.life.elapsed==expected.elapsed and second.world.life.rareSerial==expected.rareSerial,"rejoin reset current life to original imported snapshot")
  check(second.s.progress.settings.MasterVolume==.55 and originals(b)==kept and nonPUpdates(b,start)==0,"rejoin rewrote original/selected data or settings")
  do
   local r=second.s.intents.requests[mode];local writer=__currentWriterPrototype.new(second.s,b,codec,second.context)
   local handle=assert(writer:capture(mode,r.serial,r.credential,r.life,1))
   local future=Json.copy(codec:decode(b.data["R_46001_"..mode]));future.future_data={must_survive=true}
   check(writer:prepare(handle,second.rt.result.archive,second.rt.result.anchor,future,second.rt.result.checkpoint)==nil,"writer accepted unsupported current envelope fields")
  end
  print("RECOVERY_REJOIN visit="..mode.." compressed="..tostring(compressed).." requests="..(b.requests-second.startRequests).." simulated_seconds="..(clock.now-second.startTime))
  expected=advance(second,1,.66,false);second.rt:flush();assert(second.rt.result.progressPreserved)
  clock.now+=1;start=#b.log;local third=visit(b,clock,mode,3);enter(third)
  check(third.world.life.generation==expected.generation and third.world.life.elapsed==expected.elapsed and third.s.progress.settings.MasterVolume==.66,"third visit replayed an older rest/choice")
  check(originals(b)==kept and nonPUpdates(b,start)==0,"third visit modified archived/proposal/rest keys")
  third.rt:flush();check(third.s.closed and third.rt.result.progressPreserved,"third visit departure failed")
 end
end
-- Rejoining immediately after import, before the first continued checkpoint,
-- also uses entry-only proof instead of replaying the original target writer.
do
 local f=initial("main",true);local b,clock=f.b,f.clock;local kept=originals(b);f.rt:flush();clock.now+=1
 local start=#b.log;local nextVisit=visit(b,clock,"main",2);check(nextVisit.rt.discovery.continued,"initial schema3 packet not recognized for entry-only rejoin")
 enter(nextVisit);check(nonPUpdates(b,start)==0 and originals(b)==kept,"initial-packet rejoin recommitted import")
 nextVisit.rt:flush()
end
for _,scene in {"courted","hatched"} do
 local f=initial("main",true);local expected=advance(f,1,.5,false,scene);local b,clock=f.b,f.clock;f.rt:flush();clock.now+=1
 local nextVisit=visit(b,clock,"main",2);enter(nextVisit)
 check(nextVisit.world.life.mating.stage==expected.mating and nextVisit.rt.result.entryKind==(if scene=="courted" then "mating" else "hatching"),"returning current scene was replaced by original scene")
 nextVisit.rt:flush()
end
for _,fault in {"corrupt-current","future-envelope","retired","missing-archive","missing-proposal","explicit-backup","current-replaced","choice-replaced"} do
 local f=initial("main",true);advance(f,1,.5,true);local b,clock=f.b,f.clock;local current=f.rt.result.current;f.rt:flush();clock.now+=1
 if fault=="corrupt-current" then local logical=codec:decode(b.data.R_46001_main);logical.checksum="bad";b:poke("R_46001_main",codec:encode(logical))
 elseif fault=="future-envelope" then local logical=codec:decode(b.data.R_46001_main);logical.future_data={must_survive=true};b:poke("R_46001_main",logical)
 elseif fault=="retired" then b:poke("R_46001_main",codec:encode(Envelope.make(__restFormatPrototype.spec("main",f.context),assert(__restFormatPrototype.retire(current,"retired-new-token",f.context)),clock.now,nil)))
 elseif fault=="missing-archive" then b:poke("A1_46001_free",nil)
 elseif fault=="missing-proposal" then b:poke("M1_46001_main",nil) end
 local raw=Json.canonical(b.data.R_46001_main);local kept=originals(b);local start=#b.log
 local nextVisit=visit(b,clock,"main",2,if fault=="explicit-backup" then "backup" else nil)
 if fault=="current-replaced" or fault=="choice-replaced" then
  assert(nextVisit.rt.phase=="offered",nextVisit.rt.problem);assert(nextVisit.rt:accept("main",1,nextVisit.rt.discovery.offer.id))
  if fault=="current-replaced" then
   local record=Json.copy(current.checkpoint);record.created_at+=1
   local changed=Envelope.make(__restFormatPrototype.spec("main",nextVisit.context),assert(__restFormatPrototype.advance(current,record,nextVisit.context)),clock.now+1,codec:decode(b.data.R_46001_main))
   b:poke("R_46001_main",codec:encode(changed));raw=Json.canonical(b.data.R_46001_main)
  else nextVisit.s.observations.choices.main=Json.copy(nextVisit.s.observations.choices.main) end
  local job,why=nextVisit.rt:enter()
  if job then drive(nextVisit,function() return nextVisit.rt.phase~="entering" or job.phase=="awaitApplied" end);check(job.state~="pending" and job.state~="verified","changed selected rest reached client application")
  else check(why~=nil,"changed selection did not explain refusal") end
 else check(nextVisit.rt.phase=="offer_refused","invalid/retired current rest fell back to original import: "..fault) end
 check(nextVisit.s.intents.requests.main==nil or nextVisit.s.intents.requests.main.credential==nil,"invalid rejoin granted a life")
 check(Json.canonical(b.data.R_46001_main)==raw and originals(b)==kept and nonPUpdates(b,start)==0,"invalid rejoin repaired/replayed data: "..fault)
 nextVisit.rt:flush()
end
do
 local f=initial("main",true,true);local b,clock=f.b,f.clock;local kept=originals(b);f.rt:flush();clock.now+=1
 local nextVisit=visit(b,clock,"main",2,"primary");check(nextVisit.rt.discovery.continued,"original-backup import blocked current primary rejoin")
 enter(nextVisit);check(originals(b)==kept,"backup-origin rejoin changed archived damaged primary")
 nextVisit.rt:flush()
end
print("RECOVERY_REJOIN passed="..count.." failed=0")
end
runRejoinChecks()
end
