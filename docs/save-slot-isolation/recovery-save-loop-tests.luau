do
local function runSaveLoopChecks()
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
 check(#f.s.sched.started<=Rules.REQUESTS_PER_MINUTE,"routine router exceeded rolling quota")
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
 local f=fixture(mode);local originals=nonOwned(f);local l=f.world.life
 l.growth.stage=3;l.mating=Mating.new();l.mating.stage="hatched";l.mating.hatch_day=l.clock.day;l.mating.brood=3
 local generation=Mating.carryOn(l,f.world.needs,f.world.prey.feeding.mealsFinished)
 local q=Json.copy(f.s.progress);Rare.ensureLife(q.rare,l);q.settings.MasterVolume=.4;q.notebook.opened={"routine_page"};assert(f.s:setProgress(q))
 local accepted,record=checkpoint(f,1);check(accepted,"routine checkpoint not accepted")
 check(not checkpoint(f,2),"overlapping checkpoint was accepted")
 drive(f,function() return f.stored()==1 or f.rt.phase~="recovered" end)
 check(f.rt.phase=="recovered" and f.stored()==1,"routine checkpoint did not store: "..tostring(f.rt.problem))
 check(f.b.data.P_46001.payload.rare.serial>=l.rareSerial and f.b.data.P_46001.payload.settings.MasterVolume==.4,"checkpoint preceded durable current rare/progress")
 check(f.rt.result.current.checkpoint==f.s.rests[mode] and f.rt.result.current.checkpoint.save_life==record.save_life and f.world.life.generation==generation,"rest cache/life identity not adopted")
 local op=Envelope.open(__restFormatPrototype.spec(mode,f.context),codec:decode(f.b.data["R_46001_"..mode]))
 check(op.status=="ok" and __restFormatPrototype.matchesProposal(op.payload,f.rt.result.anchor,codec,f.context),"routine rest lost provenance")
 check(nonOwned(f)==originals and f.s.backend.pendingProgress==nil,"routine save changed archives or retained global reservation")
 local a=f.s.backend.held.base
 for _=1,145 do tick(f) end
 check(f.rt.phase=="recovered" and f.clock.now-f.b.data.P_46001.lock.beat<31 and f.s.backend.held.base==a,"idle handoff lost lease or advanced acknowledged baseline on metadata only")
 local r=f.s.intents.requests[mode];local before=f.b.requests
 check(not f.rt:saveRecovered(mode,r.serial,"bad",r.life,2,record) and f.b.requests==before,"wrong credential reached provider")
 local bad=Json.copy(record);bad.kind="invalid"
 check(f.rt:saveRecovered(mode,r.serial,r.credential,r.life,2,bad),"bounded invalid candidate did not reach preparation")
 drive(f,function() return f.refused()==1 end)
 check(f.rt.phase=="recovered" and r.storedSerial==1 and not f.rt.saveLoop.pending,"invalid preparation lost live credential or advanced stored serial")
 choose(f,.6);drive(f,function() return not f.s.sched:isDirty("progress") and f.s.backend.pendingProgress==nil end)
 check(f.s.progress.settings.MasterVolume==.6 and f.b.data.P_46001.payload.settings.MasterVolume==.6,"routine choice was not saved/adopted")
 f.rt:flush();check(f.s.closed and f.rt.result.progressPreserved and f.b.data.P_46001.lock==nil and nonOwned(f)==originals,"routine departure failed")
end
-- A write may commit B, lose its ACK, and have the player choose A again.
do
 local f=fixture();choose(f,.4);check(checkpoint(f,1),"streaming-progress checkpoint refused")
 for _=1,400 do
  if f.stored()==1 or f.rt.phase~="recovered" then break end
  local q=Json.copy(f.s.progress);q.notebook.eye_seconds+=.01;assert(f.s:setProgress(q));tick(f)
 end
 check(f.rt.phase=="recovered" and f.stored()==1,"newer notebook updates starved captured checkpoint progress")
 check(f.s.sched:isDirty("progress"),"later notebook progress was falsely marked durable")
 f.rt:flush();check(f.s.closed and f.rt.result.progressPreserved and f.b.data.P_46001.payload.notebook.eye_seconds==f.s.progress.notebook.eye_seconds,"departure lost later notebook updates")
end
for _,closeEarly in {false,true} do
 for _,afterWrite in {false,true} do
  local f=fixture();choose(f,.8)
  drive(f,function() return f.rt.saveLoop.progressJob~=nil and f.rt.saveLoop.progressJob.phase=="write" and f.s.sched:budgetOk(f.clock.now) end)
  local j=f.rt.saveLoop.progressJob
  f.b:fail({op="update",key="P_46001",afterWrite=afterWrite,message="timeout"})
  drive(f,function() return j.phase=="readback" or j.state~="pending" end);assert(j.state=="pending",j.problem)
  choose(f,.2)
  if closeEarly then
   j.nextAt=f.clock.now+200 -- force departure to reconcile an unresolved write
   f.rt:flush(f.clock.now+8)
   check(f.s.closed and f.rt.result.progressPreserved and f.b.data.P_46001.lock==nil,"unresolved choice departure failed")
  else
   drive(f,function() return not f.s.sched:isDirty("progress") and f.s.backend.pendingProgress==nil or f.rt.phase~="recovered" end)
   check(f.rt.phase=="recovered","in-flight choice caused lost route: "..tostring(f.rt.problem))
  end
  check(f.s.progress.settings.MasterVolume==.2 and f.b.data.P_46001.payload.settings.MasterVolume==.2,"A-B-A choice lost after ambiguous write")
 end
end
-- Local edits during an actual yielded provider are preserved, not just edits
-- between sequential test steps. Closing drains the call before final P.
do
 local f=fixture();choose(f,.8)
 drive(f,function() return f.rt.saveLoop.progressJob~=nil and f.rt.saveLoop.progressJob.phase=="write" and f.s.sched:budgetOk(f.clock.now) end)
 local raw=f.b.update
 f.b.update=function(self,key,fn)
  local out=table.pack(raw(self,key,fn));if key=="P_46001" then coroutine.yield("routine-written-paused") end;return table.unpack(out,1,out.n)
 end
 local co
 for _=1,50 do
  co=coroutine.create(function() return f.rt:step() end);local ok,mark=coroutine.resume(co);assert(ok,mark)
  if mark=="routine-written-paused" then break end;f.clock.now+=1
 end
 check(f.s.busy and f.rt.busy,"routine provider did not retain busy scope")
 choose(f,.2);local resumed=false
 f.rt.config.sleep=function(dt) f.clock.now+=dt;if not resumed then resumed=true;f.b.update=raw;assert(coroutine.resume(co)) end end
 f.rt:flush(f.clock.now+12)
 check(f.s.closed and f.rt.result.progressPreserved and f.b.data.P_46001.payload.settings.MasterVolume==.2 and f.b.data.P_46001.lock==nil,"yielding routine departure lost last choice")
end
do
 local f=fixture();choose(f,.8)
 drive(f,function() return f.rt.saveLoop.progressJob~=nil end)
 local foreign=Envelope.withLock(f.b.data.P_46001,{session="foreign",beat=f.clock.now});f.b:poke("P_46001",foreign)
 drive(f,function() return f.rt.phase~="recovered" end)
 check(f.rt.phase=="lost" and f.s.intents.requests.main.state=="readonly" and equal(f.b.data.P_46001,foreign),"foreign owner was changed or retained write authority")
 f.rt:flush(f.clock.now+4);check(f.s.closed and equal(f.b.data.P_46001,foreign),"lost-owner departure changed foreign progress")
end
-- The pure pending merge covers an authored reversion in the exact same tick.
do
 local f=fixture();choose(f,.8)
 drive(f,function() local j=f.rt.saveLoop.progressJob;return j and j.phase=="write" and f.rt.saveLoop.progress.leaseJob.phase=="renew" and f.s.sched:budgetOk(f.clock.now) end)
 local future=Json.copy(f.b.data.P_46001);future.future_data={must_survive=true};f.b:poke("P_46001",future)
 drive(f,function() return f.rt.phase~="recovered" or f.s.backend.pendingProgress==nil end)
 check(f.rt.phase=="lost" and equal(f.b.data.P_46001,future),"routine callback erased unsupported envelope fields after its lease probe")
end
do
 local base=Json.copy(rawProgress.payload);base.settings.MasterVolume=.2
 local b=Envelope.make(Progress.SPEC,base,100,nil)
 local changed=Json.copy(base);changed.settings.MasterVolume=.8;local snap=Envelope.make(Progress.SPEC,changed,101,nil)
 for _,remote in {b,Envelope.make(Progress.SPEC,changed,101,b)} do
  local merged=assert(__progressReconcilePrototype.pending({base=b,snapshot=snap},b,base,101,remote,100000))
  check(merged.progress.settings.MasterVolume==.2,"same-tick reversal lost in pending reconciliation")
 end
end
print("RECOVERY_SAVE_LOOP passed="..count.." failed=0")
end
runSaveLoopChecks()
end
