-- Live biological ladder; the frozen Godot checks remain in growth.luau.
local Growth=require("../src/Shared/Life/Growth")
local Loop=require("../src/Shared/Life/LifeLoop")
local Needs=require("../src/Shared/Life/NeedsModel")
local Session=require("../src/Shared/Life/LifeSession")
local Mating=require("../src/Shared/Life/Mating")
local Rig=require("../src/Shared/Rig/SpiderRig")
local Looks=require("../src/Shared/Data/Appearances")
local Watch=require("../src/Shared/Learning/NotebookWatch")
local Text=require("../src/Shared/UI/LifeText")
local Json=require("../src/Shared/Persistence/Json")
local passed,failed=0,0
local function check(v,msg) if v then passed+=1 else failed+=1;print("FAIL INSTARS "..msg) end end
local seeds={};local early=0
for seed=1,10000 do
 local adult=Growth.drawMaturity(seed);seeds[adult]=seeds[adult] or seed
 if adult==7 then early+=1 end
 check(adult==Growth.drawMaturity(seed),"deterministic maturity")
end
check(early>1300 and early<1700,`seven-instar draw frequency: {early}/10000`)
check(seeds[7]~=nil and seeds[8]~=nil,"both draws exercised")
for _,adult in {7,8} do for _,gentle in {false,true} do
 local g=Growth.new();g:useInstarRules(gentle,seeds[adult],true)
 local expected=if gentle then (if adult==7 then {2,3,4,8,10} else {2,3,4,6,8,10}) else (if adult==7 then {4,6,8,15,20} else {4,6,8,11,15,20})
 check(g:instar()==2 and g:adultStage()==adult-2,"start at the second instar")
 local needs=Needs.new(true,gentle);local life=Loop.new(needs);life.growth=g
 local noticed={};local watch=Watch.new({notice=function(_,name) noticed[name]=true end})
 local session=Session.new();session:begin("main",false)
 for stage=0,adult-3 do
  check(not g:isAdult() and not session:finishAdult(g),"not adult before final moult")
  check(g:mealGoal()==expected[stage+1],`instar {g:instar()} correct meal goal`)
  check(g:canRun()==(stage>=2) and g:canLock()==(stage>=5),"abilities gate on completed moults")
  check(Text.moultCounter(g)==`0/{expected[stage+1]} meals · until next moult`,"counter reads this stage")
  local remaining=g:readyAt()
  check(not g:eat(remaining-.0001) and not g.ready,"partial meal does not prematurely ready")
  check(g:eat(.0001) and not g:eat(.001) and g.ready,"ready emits once and remains sticky")
  check(g:beginMoult() and not g:canRun() and not g:canLock(),"moulting immobilizes abilities")
  g:passHours(4,Vector3.zero)
  local record=g:toRecord();local text=assert(Json.canonical(record));local back=Growth.new()
  check(back:load(record) and back.matureInstar==adult and back.lifeSeed==seeds[adult],"save preserves draw and seed")
  back:useInstarRules(gentle,seeds[if adult==7 then 8 else 7])
  check(back.matureInstar==adult and back.lifeSeed==seeds[adult] and Json.canonical(back:toRecord())==text,"restore/configuration never rerolls")
  check(back:passHours(8,Vector3.zero)=="moulted" and back.stage==stage+1,"interrupted moult finishes once")
  check(back:passHours(.01,Vector3.zero)=="" and #back.exuviae==stage+1,"no duplicate old skin")
  check(#Growth.problems(back:toRecord())==0,"all five/six old skins validate")
  g=back;life.growth=g
  watch:onLife("moulted",g.stage,g:isAdult())
  check((noticed.adult==true)==g:isAdult(),"notebook adult page waits for true maturity")
 end
 check(g:isAdult() and g:instar()==adult and #g.exuviae==adult-2,"exactly five or six playable moults")
 check(Text.moultCounter(g)==nil and not g:eat(10) and not g:beginMoult(),"no adult food goal or extra moult")
 check(session:finishAdult(g) and not session:finishAdult(g),"Easy opens once at true adulthood")
 local oldSeed=g.lifeSeed
 life.mating=Mating.new();life.mating.hatch_day=8
 Mating.carryOn(life,needs,0)
 check(life.growth.instarVersion==1 and life.growth.stage==0 and life.growth.lifeSeed~=oldSeed,"next generation gets a fresh saved draw")
 check(life.growth.gentleRules==gentle and not life.growth:canRun() and not life.growth:canLock(),"newborn retains difficulty, not abilities")
end end
-- Every old stage, both maturity draws, partial credit, readiness and interrupted moults.
for oldStage=0,3 do for _,adult in {7,8} do for _,ready in {false,true} do
 local old=Growth.new();old.stage=oldStage;old.fedSinceMoult=.75;old.ready=ready
 old.moultingHoursLeft=if ready and oldStage<3 then 7 else 0;old.softHoursLeft=2
 local record=old:toRecord();local bytes=assert(Json.canonical(record));local g=Growth.new();assert(g:load(record))
 g:useInstarRules(false,seeds[adult])
 check(g.stage==(if oldStage==3 then adult-2 else oldStage*2),"equivalent instar migration")
 check(g.fedSinceMoult==.75 and g.ready==ready and g.softHoursLeft==2 and g.moultingHoursLeft==old.moultingHoursLeft,"credit/readiness/timers survive migration")
 check(g:unlockedRun()==(oldStage>=1) and g:unlockedLock()==(oldStage>=2),"old earned abilities never regress")
 check(Json.canonical(record)==bytes,"source record untouched")
 check(#Growth.problems(g:toRecord())==0,"migrated record valid")
 if ready and oldStage<3 then
  check(not g:eat(.1) and g.ready,"additional food never cancels old readiness")
  check(g:passHours(7,Vector3.zero)=="moulted","already-running legacy moult still finishes")
 end
end end end
local g=Growth.new();g:useInstarRules(false,seeds[7],true)
do
 local fed=Growth.new();fed.fedSinceMoult=1.5;fed:useInstarRules(false,914)
 check(fed.ready and fed.fedSinceMoult==1.5,"old consumed credit above the new goal is immediately ready")
end
for _,mutation in {
 function(r)r.stage=6 end,function(r)r.mature_instar=9 end,function(r)r.instar_version=2 end,
 function(r)r.life_seed=0/0 end,function(r)r.life_seed=-1 end,function(r)r.life_seed=.5 end,
 function(r)r.gentle_rules="yes" end,function(r)r.earned_lock=1 end,
 function(r)r.instar_version=nil end,
} do
 local record=g:toRecord();mutation(record);local before=Json.canonical(g:toRecord())
 check(not g:load(record) and Json.canonical(g:toRecord())==before,"invalid ladder refused atomically")
end
-- Per-instar drawing advances on every moult, with no per-frame rescaling churn.
for id,look in Looks.profiles do for _,adult in {7,8} do for _,tier in {"full","low"} do
 local rig=Rig.new(workspace,nil,id,tier);local growth=Growth.new();growth:useInstarRules(false,seeds[adult],true)
 local old=0
 for stage=0,adult-2 do
  growth.stage=stage;rig:setLifeGrowth(growth)
  check(rig._growth>old or id=="rival_spider",`{id}: playable size increases at every moult`);old=rig._growth
  local epoch=rig._epoch;rig:setLifeGrowth(growth)
  check(rig._epoch==epoch,"stationary instar does not resize the rig again")
 end
 check(math.abs(rig._growth-rig:growthScale(3))<1e-9,"adult art endpoint preserved")
 rig:destroy()
end end end
print(`INSTARS early={early}/10000 passed={passed} failed={failed}`)
if failed>0 then error("instar checks failed") end
