local Work=require("../src/Shared/Persistence/SaveWork")
local Feeding=require("../src/Shared/Prey/Feeding")
local Growth=require("../src/Shared/Life/Growth")
local passedMeals=0
local function mealCheck(ok,why) assert(ok,why);passedMeals+=1 end
WorldMap.use("test_garden")
local old=gardenWorld();old.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
old.needs:useGameRules();old.prey.feeding:useGameRules()
old.needs.energy=.3;old.needs:grantEnergy(.1,"fly_1:1");old.needs:grantEnergy(.1,"rival_spider_meal")
old.needs.starvingHours=2.5;old.needs.starvingStreakH=1.2
old.prey.feeding.ledger["fly_1:1"]=.1;old.prey.feeding.granted=.1;old.prey.feeding.taken=.15;old.prey.feeding.mealsFinished=3
old.life.grantedSeen=old.needs.grantedTotal;old.life.growth.stage=1;old.life.growth.fedSinceMoult=1.2
local source=assert(Checkpoint.capture(old,123));local original=assert(Json.canonical(source))
WorldMap.use("preserve");local live=newWorld();live.garden={}
local active=WorldMap.regions();local before=fingerprint(live)
local problems,decoded=Checkpoint.inspectRecorded(source,live)
mealCheck(#problems==0 and decoded~=nil,"recorded Test Garden fixture did not inspect: "..table.concat(problems,";"))
local capsule=assert(__mealsPrototype.prepare(decoded,"A1_46001"));local text=assert(Json.canonical(capsule))
local prepared=assert(__mealsPrototype.decode(capsule));local n,f=prepared.needs,prepared.feeding
mealCheck(table.isfrozen(capsule) and table.isfrozen(capsule.graph.objects),"portable data is not frozen/owned")
mealCheck(n~=decoded.roots.needs and f~=decoded.roots.prey.feeding and f.needs==n,"portable reserves are aliased to source or feeding identity lost")
mealCheck(n.grantedBySource["@archive/A1_46001/fly_1:1"]==decoded.roots.needs.grantedBySource["fly_1:1"] and n.grantedBySource["fly_1:1"]==nil,"historical capture not moved into archive namespace")
mealCheck(n.grantedBySource["@archive/A1_46001/rival_spider_meal"]~=nil and f.ledger["@archive/A1_46001/fly_1:1"]==.1,"rival or feeding history lost")
mealCheck(f.mealsFinished==3 and f.taken==.15 and f.granted==.1 and prepared.grantedSeen==n.grantedTotal,"meal totals or growth cursor changed")
mealCheck(n.starvingHours==2.5 and n.starvingStreakH==1.2 and n.drainScale==old.needs.drainScale and n.moveCosts==true,"survival pacing/history lost")
mealCheck(f.rng.state==decoded.roots.prey.feeding.rng.state and f.rng~=decoded.roots.prey.feeding.rng,"struggle random stream changed or aliased")
mealCheck(capsule.graph.roots.prey==nil and capsule.graph.roots.garden==nil and capsule.graph.roots.life==nil,"old ecology leaked into portable meal graph")
-- Keep the same fresh fly id/capture key the old life used. The actual feeding
-- implementation must add new food under its own key without editing history.
local historical=n.grantedBySource["@archive/A1_46001/fly_1:1"]
local freshFly=live.prey.flies[1];freshFly.id="fly_1";freshFly.state="CAPTURED";freshFly.captureSerial=1;freshFly.captureKey="fly_1:1"
local nutrition=freshFly.nutrition;local count=0
f.held=freshFly;f.struggling=false;f.feeding=true;f.swallow=10;f.auto=true
while f.held and count<1000 do f:step(1/60,true,false,function() error("unexpected escape") end);count+=1 end
mealCheck(f.held==nil and f.mealsFinished==4 and freshFly.nutrition==0,"fresh same-id fly did not finish normally")
mealCheck(n.grantedBySource["fly_1:1"]~=nil and n.grantedBySource["@archive/A1_46001/fly_1:1"]==historical,"new capture merged with or erased historical energy")
mealCheck(math.abs(f.taken-.15-nutrition)<1e-6 and f.ledger["@archive/A1_46001/fly_1:1"]==.1,"new meal changed old feeding book or nutrition accounting")
mealCheck(math.abs(prepared.grantedSeen-decoded.roots.life.grantedSeen)<1e-9,"old food was marked new for growth")
mealCheck(Json.canonical(source)==original and fingerprint(live)~=before,"feeding test did not use fresh prey or source changed")
-- Independent decodes and repeated preparation do not alias or rebase twice.
local again=assert(__mealsPrototype.decode(capsule));again.needs.energy=0
mealCheck(Json.canonical(capsule)==text and assert(__mealsPrototype.decode(capsule)).needs.energy~=0,"consumer mutation changed capsule")
mealCheck(Json.canonical(assert(__mealsPrototype.prepare(decoded,"A1_46001")))==text,"same inspected source did not prepare deterministically")
for _,id in {"","bad/id",string.rep("a",65)} do mealCheck(__mealsPrototype.prepare(decoded,id)==nil,"invalid archive identity accepted") end
for _,mutate in {
 function(d) d.roots.needs.futureField=1 end,
 function(d) d.roots.prey.feeding.futureField=1 end,
 function(d) d.roots.prey.feeding.ledger=d.roots.needs.grantedBySource end,
 function(d) d.roots.life.grantedSeen=1e9 end,
 function(d) d.roots.prey.feeding.held={} end,
 function(d) d.roots.prey.feeding.struggling=true end,
 function(d) d.roots.prey.feeding.ledger[17]=.2 end,
 function(d) d.roots.prey.feeding.granted=100 end,
 function(d) d.roots.prey.feeding.rng={} end,
} do
 local p,d=Checkpoint.inspectRecorded(source,live);assert(#p==0 and d);mutate(d)
 mealCheck(__mealsPrototype.prepare(d,"A1_46001")==nil,"unsupported portable state accepted")
end
for _,mutate in {
 function(c) c.archive="bad/id";c.namespace=nil end,
 function(c) c.version=2 end,
 function(c) c.extra=true end,
 function(c) c.grantedSeen=1e9 end,
 function(c) c.graph.roots.prey=c.graph.roots.feeding end,
} do
 local c=Json.copy(capsule);mutate(c)
 local ok,value=pcall(__mealsPrototype.decode,c)
 mealCheck(ok and value==nil,"bad portable data raised or decoded")
end
-- Preparation can yield without changing either map or source.
local t=0;local function now() t+=.00001;return t end
local worker=Work.new(function() return __mealsPrototype.prepare(decoded,"A1_46001") end,{now=now,budget=.000001,maxSeconds=100,maxResumes=10000})
local suspensions=0
while worker.state=="pending" do
 worker:step();mealCheck(WorldMap.world()=="preserve" and WorldMap.regions()==active and Json.canonical(source)==original,"cooperative preparation changed live map or source")
 if worker.state=="pending" then suspensions+=1 end
end
local result=worker:take();mealCheck(result and result[1] and Json.canonical(result[1])==text and suspensions>0,"cooperative preparation changed portable data or never yielded")
local cancelled=Work.new(function() return __mealsPrototype.prepare(decoded,"A1_46001") end,{now=now,budget=.000001,maxSeconds=100})
cancelled:step();mealCheck(cancelled.state=="pending" and cancelled:cancel() and cancelled:take()==nil,"cancelled preparation exposed a capsule")
print("RECOVERY_MEALS passed="..passedMeals.." failed=0 suspensions="..suspensions)
