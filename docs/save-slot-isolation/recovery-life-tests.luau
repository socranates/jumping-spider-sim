do
local Mating=require("../src/Shared/Life/Mating")
local Mate=require("../src/Shared/Predator/Mate")
local Rival=require("../src/Shared/Predator/RivalSpider")
local RareCatalog=require("../src/Shared/Data/RareSightings")
local passedLife=0
local function lifeCheck(ok,why) assert(ok,why);passedLife+=1 end
local beforeLife=fingerprint(live);local activeLife=WorldMap.regions()
local capsule=assert(__lifePrototype.prepare(source,live,"A1_46001"));local text=assert(Json.canonical(capsule))
local result=assert(__lifePrototype.decode(capsule))
lifeCheck(result.life.needs==result.needs and result.feeding.needs==result.needs,"life/feeding/reserve identity lost")
lifeCheck(result.life.growth.stage==decoded.roots.life.growth.stage and result.life.growth.fedSinceMoult==decoded.roots.life.growth.fedSinceMoult,"growth state changed")
lifeCheck(result.life.grantedSeen==decoded.roots.life.grantedSeen and result.life.clock.day==decoded.roots.life.clock.day and result.life.clock.hour==decoded.roots.life.clock.hour,"food cursor or life clock changed")
lifeCheck(result.life.save==nil and result.life.mate==nil and result.life.rival==nil and #result.life.events==0,"live callbacks/actors/events leaked into portable life")
lifeCheck(result.origin.world=="test_garden" and result.origin.region=="bed_a" and table.isfrozen(capsule.graph.objects),"recorded origin/ownership lost")
lifeCheck(Json.canonical(source)==original and fingerprint(live)==beforeLife and WorldMap.regions()==activeLife,"life preparation changed source or live map")
for _,mode in {"main","free","easy"} do
 for _,stage in {"none","courted","mated","sac","guarding","hatched"} do
  WorldMap.use("test_garden")
  local w=gardenWorld();w.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
  local l=w.life;l.mode=if mode=="free" then "free" else "main";l.rules=if mode=="main" then "standard" else "gentle";w.needs.gentle=mode~="main"
  l.growth:useGameRules(mode~="main");l.growth.stage=3;l.growth.exuviae={Vector3.new(11,-90,-50)}
  l.clock.day=8;l.clock.hour=19.5;l.clock.sleeping=true;l.asleep=true;l.resting=true;l.restSeconds=33;l.elapsed=1234;l.checkpoints=17
  l.generation=2;l.born=6;l.mealsBase=4;w.prey.feeding.mealsFinished=7;l.cold_day=7
  l.rareSerial=7;l.rareGeneration=2;l.rareBorn=1;l.rareVisit={id=RareCatalog.luna.id,serial=7,day=7,hour=20.5}
  l.rival=Rival.new();l.rival.contests=5;l.rival.grips=2
  l.mate=Mate.new();l.mate.meter=.4;l.mate.scale=.93
  l.mating=Mating.new();l.mating.stage=stage;l.mating.courts=2;l.mating.rejections=1;l.mating.cut_ins=1
  if stage=="courted" then l.mate.state="pair";l.mate.scene=true end
  if stage=="sac" or stage=="guarding" then l.mating.sac_day=7;l.mating.guard_day=if stage=="sac" then 1 else 2 end
  if stage=="hatched" then l.mating.hatch_day=8;l.mating.hatch_hour=7;l.mating.brood=14 end
  local record=assert(Checkpoint.capture(w,123));record.save_life="historical-"..mode.."-"..stage
  local kept=assert(Json.canonical(record));WorldMap.use("preserve");local regions=WorldMap.regions()
  local c,why=__lifePrototype.prepare(record,live,"A1_46001");lifeCheck(c~=nil,"life stage failed: "..mode.."/"..stage..": "..tostring(why))
  local d=assert(__lifePrototype.decode(c));local x=d.life
  lifeCheck(x.clock.day==8 and x.clock.hour==19.5 and x.clock.sleeping==true and x.asleep==false,"recovery reset clock progress or retained UI asleep flag")
  lifeCheck(x.growth:isAdult() and x.growth:canRun() and x.growth:canLock() and x.growth.gameRules==true,"instar/unlock/rules changed")
  lifeCheck(x.generation==2 and x.born==6 and x.mealsBase==4 and x.cold_day==7 and x.restSeconds==33 and x.checkpoints==17,"generation grace or rest history lost")
  local born,meals=Mating.grace(x,d.feeding.mealsFinished);lifeCheck(born==6 and meals==3,"generation protection restarted")
  lifeCheck(x.mating.stage==stage and x.mating.courts==2 and x.mating.rejections==1 and x.mating.cut_ins==1,"mating stage/counters lost")
  lifeCheck(x.mating.brood==l.mating.brood and x.mating.hatch_day==l.mating.hatch_day,"brood history rerolled")
  lifeCheck(x.rareSerial==7 and x.rareGeneration==2 and x.rareBorn==1 and x.rareVisit.serial==7 and x.rareVisit.day==7,"rare visit identity/history changed")
  lifeCheck(x.needs.gentle==(mode~="main") and x.mode==l.mode and x.rules==l.rules,"mode or survival rules changed")
  lifeCheck(x.mate==nil and x.rival==nil and d.history.rival.contests==5 and d.history.mate.meter==.4 and #d.history.skins==1 and #x.growth.exuviae==0,"historical encounter/skin state dropped or activated")
  lifeCheck(d.origin.save_life==record.save_life and Json.canonical(record)==kept and WorldMap.regions()==regions,"saved identity/source/map changed")
 end
end
-- A moult in progress must retain remaining hours and continue from that point,
-- leaving its next skin at the destination rather than an old garden position.
WorldMap.use("test_garden")
local w=gardenWorld();w.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
w.life.resting=true;w.life.growth:useGameRules();w.life.growth.stage=1;w.life.growth.ready=true;w.life.growth.moultingHoursLeft=6
w.life.growth.fedSinceMoult=3;w.life.growth.exuviae={Vector3.new(11,-90,-50)}
local record=assert(Checkpoint.capture(w,123));WorldMap.use("preserve")
local d=assert(__lifePrototype.decode(assert(__lifePrototype.prepare(record,live,"A1_46001"))))
lifeCheck(d.life.resting and d.life.growth:isMoulting() and d.life.growth.moultingHoursLeft==6,"moult restarted or was cancelled")
local at=Vector3.new(1,2,3);lifeCheck(d.life.growth:passHours(6,at)=="moulted" and d.life.growth.stage==2 and d.life.growth.softHoursLeft==10,"moult did not finish at retained time")
lifeCheck(#d.history.skins==1 and #d.life.growth.exuviae==1 and d.life.growth.exuviae[1]==at,"old skin moved into new habitat or new skin lost")
-- Return data is independent; no consuming it may edit the frozen capsule.
result.life.clock.day=999
result.origin.region="consumer-change"
lifeCheck(assert(__lifePrototype.decode(capsule)).life.clock.day~=999 and Json.canonical(capsule)==text,"consumer mutation edited portable life")
lifeCheck(assert(__lifePrototype.decode(capsule)).origin.region=="bed_a","consumer mutation edited origin")
local p,sourceDecoded=Checkpoint.inspectRecorded(source,live);assert(#p==0)
for _,edit in {
 function(r) r.world_map.world="unknown" end,
 function(r) r.schema_version=999 end,
 function(r) r.life_rules.rules="gentle" end,
} do local r=Json.copy(source);edit(r);lifeCheck(__lifePrototype.prepare(r,live,"A1_46001")==nil,"invalid source accepted") end
for _,edit in {
 function(c) c.origin.world="unknown" end,
 function(c) c.archive="another" end,
 function(c) c.version=2 end,
 function(c) c.extra=true end,
 function(c) c.origin.extra=true end,
 function(c) c.origin.save_life="bad/token" end,
} do local c=Json.copy(capsule);edit(c);local ok,v=pcall(__lifePrototype.decode,c);lifeCheck(ok and v==nil,"bad portable capsule raised or decoded") end
for _,class in {"LifeLoop","LifeClock","Growth"} do
 local r=Json.copy(source);local found=false
 for _,object in r.world.objects do if object.c==class then table.insert(object.e,{"futureField",true});found=true;break end end
 lifeCheck(found,"unknown-field fixture missing class")
 local problems,decoded=Checkpoint.inspectRecorded(r,live)
 lifeCheck(#problems==0 and decoded~=nil,"unknown-field fixture was not a valid source graph")
 lifeCheck(__lifePrototype.prepare(r,live,"A1_46001")==nil,"unknown portable field silently omitted")
end
do
 local r=Json.copy(source);r.wasp=WaspDirector.defaultRecord();r.wasp.last_visit_day=3;r.wasp.last_visit_slot=1;r.wasp.visits=4;r.wasp.escapes=2
 local c=assert(__lifePrototype.prepare(r,live,"A1_46001"));local d=assert(__lifePrototype.decode(c))
 lifeCheck(d.history.wasp.visits==4 and d.history.wasp.escapes==2 and d.history.wasp.last_visit_day==3,"wasp visit/escape history lost")
end
local time=0;local function now() time+=.00001;return time end
local worker=Work.new(function() return __lifePrototype.prepare(source,live,"A1_46001") end,{now=now,budget=.00001,maxSeconds=1000,maxResumes=10000})
local suspended=0
while worker.state=="pending" do
 worker:step();lifeCheck(WorldMap.world()=="preserve" and Json.canonical(source)==original,"suspended life projection changed source/map")
 if worker.state=="pending" then suspended+=1 end
end
local r=worker:take();lifeCheck(r and r[1] and Json.canonical(r[1])==text and suspended>0,"cooperative life projection failed or changed data")
print("RECOVERY_LIFE passed="..passedLife.." failed=0 suspensions="..suspended)
end
