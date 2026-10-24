local Needs=require("../src/Shared/Life/NeedsModel")
local Loop=require("../src/Shared/Life/LifeLoop")
local Growth=require("../src/Shared/Life/Growth")
local Clock=require("../src/Shared/Life/LifeClock")
local Feeding=require("../src/Shared/Prey/Feeding")
local Species=require("../src/Shared/Data/Species")
local Prompts=require("../src/Shared/UI/ContextPrompts")
local Text=require("../src/Shared/UI/ControlText")
local Hud=require("../src/Client/SpiderHud")
local Meal=require("../src/Client/MealPresentation")
local Rig=require("../src/Shared/Rig/SpiderRig")
local FlyBodies=require("../src/Client/FlyBodies")
local Fly=require("../src/Shared/Prey/Fly")
local Sound=require("../src/Client/Soundscape")
local Cat=require("../src/Shared/Predator/Cat")
local CatBody=require("../src/Client/CatBody")
local ObjectRecord=require("../src/Shared/Persistence/ObjectRecord")
local PreyRandom=require("../src/Shared/Prey/PreyRandom")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL MEALS "..msg) end end
local function near(a,b) return math.abs(a-b)<1e-8 end
local function prey()
 return setmetatable({id="meal",state="CAPTURED",nutrition=.35,captureKey="once",profile=Species.fly_like_prototype,
 position=Vector3.new(0,.4,0),heading=-Vector3.zAxis,normal=Vector3.yAxis,previous=Vector3.zero}, {__index=Fly})
end
local n=Needs.new();n.energy=0
local f=Feeding.new(n);f:useGameRules();f.tapToFeed=true;f.held=prey();f.struggling=false
for _=1,100 do f:step(.1,true,false,function() error("escape") end) end
check(f.taken==0,"manual feeding cannot start without a bite")
f:press();for _=1,20 do f:step(.1,true,false,function() end) end
local bite=f.taken
check(bite>0 and bite<.35 and f.held~=nil,"one tap takes a bounded bite, not a whole fly")
check(f.bites==1,"one accepted tap yields one pulse")
f:press();f:step(.05,true,false,function() end)
local pulses=f.bites
f:press();f:step(.05,true,false,function() end)
check(f.bites==pulses+1,"faster valid taps still produce bite responses")
check(f.biteWindow<=.38,"repeated taps cannot bank future food")
-- Keep the interruption comparison at the amount swallowed so far.
bite=f.taken
f:press();f:step(.1,true,true,function() end)
check(near(f.taken,bite) and f.biteWindow==0,"movement cancels bite without nutrition")
f:press();f:step(.1,false,false,function() end)
check(near(f.taken,bite),"no feeding in air")
for _=1,50 do f:press();for _=1,5 do f:step(.1,true,false,function() end) end end
check(f.held==nil and f.mealsFinished==1 and near(f.taken,.35),"one meal resolves once, conserving all food")
check(f.granted<=f.taken+1e-8 and near(f.ledger.once,f.granted),"energy ledger conserved")
for _=1,10 do f:press();f:step(.1,true,false,function() end) end
check(f.mealsFinished==1,"taps after consumption cannot duplicate a meal")
local auto=Feeding.new();auto.tapToFeed=true;auto.auto=true;auto.held=prey();auto.feeding=true
for _=1,200 do auto:step(.1,true,false,function() end) end
check(auto.mealsFinished==1,"automatic accessibility feeding remains available")
local legacy=Feeding.new();legacy.held=prey();legacy:press();legacy:step(.1,true,false,function() end)
check(legacy.taken>0,"frozen controller retains toggle feeding")
-- A real graph commit clears constructor defaults: reproduce a pre-v50 rest.
local old=Feeding.new();old.bites=nil;old.biteWindow=nil;old.bitePulse=nil;old.tapToFeed=nil
local classes={Feeding=Feeding,Needs=Needs,PreyRandom=PreyRandom}
local graph,why=ObjectRecord.capture({feeding=old},classes,{})
assert(graph,table.concat(why or {},","))
local decoded,problems=ObjectRecord.decode(graph,classes,{})
assert(decoded,table.concat(problems or {},","))
local restored=Feeding.new()
assert(ObjectRecord.commit(decoded,{feeding=restored}))
check(restored.bites==nil,"old record actually removes new constructor defaults")
restored:useGameRules();restored.tapToFeed=true
check(restored.bites==0 and restored.biteWindow==0 and restored.bitePulse==0,"live restore initializes absent presentation fields")
restored.held=prey();restored:press();restored:step(.1,true,false,function() end)
check(restored.taken>0 and restored.bites==1,"old-rest feeding runs without nil counters")

Clock.game.clockScale=60
local s={inRetreat=true,attached=true,still=true,holding=false,feeding=false}
for _,gentle in {false,true} do for _,energy in {0,.55,1} do for _,rest in {false,true} do
 local needs=Needs.new(true,gentle);needs:useGameRules();needs.energy=energy
 local l=Loop.new(needs);l:useGameRules()
 local start=(l.clock.day-1)*24+l.clock.hour
 local elapsed=0
 for i=1,2000 do
  needs:advance(.25,false);l:step(.25,s,rest and not l.resting,false)
  elapsed=(l.clock.day-1)*24+l.clock.hour-start
  if i==20 then
   local record=needs:toRecord();local saved=l:toRecord()
   local restored=Needs.new(true,gentle);restored:useGameRules();assert(restored:load(record))
   local nextLife=Loop.new(restored);nextLife:useGameRules();assert(nextLife:load(saved))
   needs,l=restored,nextLife
  end
  if l.lifeOver or elapsed>=75 then break end
 end
 check(if gentle then not l.lifeOver else l.lifeOver and elapsed<=72.5,`survival bound gentle={gentle} initial={energy} rest={rest} hours={elapsed}`)
 if l.lifeOver then
  local count=0;for _,e in l:drainEvents() do if e.kind=="starved" then count+=1 end end
  check(count==1,"starvation emits once across save/restore")
  l:step(.25,s,false,false);local again=0;for _,e in l:drainEvents() do if e.kind=="starved" then again+=1 end end
  check(again==0,"no repeated death event")
 end
end end end
Clock.game.clockScale=1
local legacyLife=Loop.new(Needs.new(true,false));legacyLife.needs.starvingStreakH=47
check(not legacyLife:starved(),"frozen life thresholds unchanged")

local p=Prompts.new()
local state={enabled=true,blocked=false,device="keyboard",day=1,hour=12,held=false,resting=false,canRest=false,home="hut_crack"}
check(p:step(.1,state)==nil,"no routine daytime instructions")
state.held=true;state.canEat=true;state.struggling=true
for _,device in {"keyboard","gamepad","touch"} do
 state.device=device;local v=p:step(.1,state);check(v and string.find(v.hint,if device=="touch" then "Grip" else Text.name(device,"feed"),1,true)~=nil,"actual grip key: "..device)
end
Text.setPadStyle("playstation");state.device="gamepad";check(string.find(p:step(.1,state).hint,"L3",1,true)~=nil,"PlayStation L3")
Text.setPadStyle("xbox");state.device="keyboard";state.struggling=false
check(p:step(.1,state).hint=="Tap E: eat","subdued meal prompt")
state.enabled=false;check(p:step(.1,state)==nil,"settings opt-out")
state.enabled=true;state.held=false;state.hour=19
check(p:step(.1,state).hint=="It is getting dark. Find a home for the night.","dusk asks player to discover a home")
for _=1,100 do p:step(.1,state) end
check(p:step(.1,state)==nil,"away prompt clears promptly")
state.canRest=true;check(p:step(.1,state).hint=="E: rest","correct rest key at retreat")
state.resting=true;check(p:step(.1,state)==nil,"rest clears night prompt")
state.resting=false;state.day=2;state.hour=1;check(p:step(.1,state)==nil,"midnight does not reset dismissed night")
state.hour=12;check(p:step(.1,state)==nil,"daytime clears")
state.hour=19;check(p:step(.1,state)~=nil,"next dusk returns")
state.blocked=true;check(p:step(.1,state)==nil,"no prompts through modal/death/sleep")
local gui=Instance.new("Folder");local hud=Hud.new(gui)
hud:update({minimal=true,device="keyboard",food=.5,dot=true,contextPrompt={hint="Tap E: eat"},status={"Noise"}},.1)
check(hud.promptHint.Visible and hud.promptHint.Text=="Tap E: eat","only explicit contextual prompt passes minimal HUD")
check(not hud.status.Visible and not hud.foodText.Visible,"reserve remains wordless, other status suppressed")
hud:update({minimal=true,device="keyboard",food=.5,dot=true},.1)
check(not hud.promptHint.Visible,"context prompt clears on drop/finish")

local meal=Meal.new(workspace,workspace)
local rig=Rig.new(workspace,workspace,nil,"low")
rig.mealHeld=true;rig.mealPulse=1;rig:update(CFrame.new(0,.5,0),.1,true,false)
check(rig:mouthFrame().Position~=nil,"animated low-tier mouth frame")
local held=prey();local feeding={held=held,bites=1}
local pulse=meal:pulse(.05,feeding,false);check(pulse>0,"bite animates on actual bite")
meal:update(.1,feeding,rig:mouthFrame(),false)
local bodies=FlyBodies.new(workspace,"low");bodies:draw({held},0,nil,false,meal.heldView)
local size=bodies.rigs.meal.parts[1].Size.Magnitude
for _,part in bodies.rigs.meal.parts do if part.Name=="Shadow" then check(part.Transparency==1,"held subdued prey has no floating perched shadow") end end
held.state="PERCHED";bodies:draw({held},.05,nil,false)
for _,part in bodies.rigs.meal.parts do if part.Name=="Shadow" then check(part.Transparency<1,"released perched prey restores its ground shadow") end end
held.state="CAPTURED";bodies:draw({held},.06,nil,false,meal.heldView)
held.nutrition=.01;meal:update(.1,feeding,rig:mouthFrame(),false);bodies:draw({held},.1,nil,false,meal.heldView)
check(bodies.rigs.meal.parts[1].Size.Magnitude<size,"meal visibly shrinks without changing nutrition")
held.state="CONSUMED";feeding.held=nil;meal:update(.1,feeding,rig:mouthFrame(),false)
check(meal.husk~=nil and #meal.husk:GetChildren()==3,"bounded three-part husk")
for _,part in meal.husk:GetChildren() do check(not part.CanCollide and not part.CanQuery and not part.CastShadow,"husk cannot affect movement or perception") end
local age=meal.age;meal:update(1,feeding,rig:mouthFrame(),true);check(meal.age==age,"pause freezes husk")
meal:update(4,feeding,rig:mouthFrame(),false);check(meal.husk==nil,"husk cleaned up")
meal:reset();check(meal.previous==nil and meal.heldView.id==nil,"new life clears presentation")
local sound=Sound.new(workspace);sound:setVolumes(1,1,1,1)
sound:updateMeal(1,0,false,false,1);check(sound.bite.Playing and sound.bite.Volume<=.05,"soft bite voice")
sound:updateMeal(2,0,false,true,1);check(not sound.bite.Playing,"mute stops bite")
sound:updateMeal(2,0,false,false,1);check(not sound.bite.Playing,"muted bite never replays")
sound:setVolumes(0,1,1,1);sound:updateMeal(3,1,false,false,1);check(not sound.bite.Playing,"master volume respected")
local cat=Cat.new(914);cat.pose="sit"
local catBody=CatBody.new(workspace,"low")
catBody:draw(cat,0,1/60,0,0,cat.pos+Vector3.new(500,0,0))
local last=catBody.last
cat.pos+=Vector3.xAxis
catBody:draw(cat,.02,1/60,1,0,cat.pos+Vector3.new(500,0,0))
check(catBody.last==last and catBody.voices.bell.Volume>0,"distant cat defers geometry while audio stays responsive")
local moved=catBody.world[1].Position
cat.pos+=Vector3.xAxis
catBody:draw(cat,.03,1/60,0,0,cat.pos+Vector3.new(500,0,0))
check((catBody.world[1].Position-moved-Vector3.xAxis).Magnitude<1e-8,"cached distant pose travels smoothly every frame")
for i=1,6 do catBody:draw(cat,i/60,1/60,0,0,cat.pos+Vector3.new(500,0,0)) end
check(catBody.last==cat.pos,"far geometry refreshes at bounded 10 Hz")
cat.pos+=Vector3.xAxis;catBody:draw(cat,.2,1/60,0,0,cat.pos)
check(catBody.last==cat.pos,"near camera refreshes immediately")

-- The actual client's input, new-life, death panel and lineage path, not just the models.
local Layout=require("../src/Shared/Habitat/WindowsillLayout")
workspace:ClearAllChildren()
local pieces={};for _,piece in Layout.PIECES do table.insert(pieces,{name=piece.id,lo=piece.lo,hi=piece.hi,profile=piece.profile}) end
BoxWorld.folder("Windowsill",pieces)
local loaded,loadError=pcall(function() require("../src/Client/SpiderClient.client") end)
assert(loaded,loadError)
local d=assert(ClientStubs.driver)
local frame=assert(ClientStubs.renderSteps.SpiderSim)
local function frames(n) for _=1,n do frame(1/60) end end
frames(5)
check(d.fresh("main",false),"real client begins Normal")
check(d.prey.feeding.tapToFeed and d.life.starveAfterH==12,"fresh applies live meal and survival rules")
d.place(Vector3.new(-5,.31,-9));frames(10)
local caught=d.prey.flies[1];assert(caught)
caught.state="CAPTURED";caught.captureKey="client-bite"
d.prey.feeding:capture(caught);d.prey.feeding.struggling=false;d.prey.feeding.feeding=false
local before=caught.nutrition
d.input:simulate("Feed",true);frames(3);d.input:simulate("Feed",false);frames(30)
check(caught.nutrition<before and caught.nutrition>0,"real E input takes a partial bite")
check(d.meal.heldView.id==caught.id,"client wires held meal to drawer")
check((d.meal.heldView.frame.Position-d.rig():mouthFrame().Position).Magnitude<.01,"meal follows animated jaw frame")
-- A press means Eat while prey is held, even if that tick consumes the final
-- bite. Rest/moult requires a subsequent empty-jaws press, not reusing Eat.
check(d.fresh("main",false),"new life for final-bite context")
d.place(Vector3.new(-25.5,.31,6));frames(10)
local last=d.prey.flies[1];assert(last)
last.state="CAPTURED";last.captureKey="client-final-bite";last.nutrition=.0001
local jaws=d.prey.feeding;jaws:capture(last);jaws.struggling=false;jaws.feeding=false
d.life.growth.fedSinceMoult=d.life.growth:readyAt()-Growth.rivalCredit(last.nutrition)
-- This fixture isolates input context; real rest preparation/storage has its
-- own suites and native route. Do not start a second save fixture here.
local saveForBite=d.life.save
d.life.save=function() return {ok=true,message="Input-context fixture rest"} end
d.input:simulate("Feed",true);frames(1);d.input:simulate("Feed",false);frames(3)
check(jaws.held==nil and last.state=="CONSUMED"and d.life.growth.ready,"last bite finishes the meal and earns moult readiness")
check(not d.life.resting and not d.life.growth:isMoulting(),"Eat finishing in the Crack does not also Rest or moult")
d.input:simulate("Feed",true);frames(2);d.input:simulate("Feed",false)
check(d.life.resting and d.life.growth:isMoulting(),"a new empty-jaws press still rests and begins the ready moult")
d.life.save=saveForBite
check(d.fresh("main",false),"new life after meal")
d.needs.energy=0;d.needs.starvingStreakH=12.1;frames(3)
check(d.life.lifeOver and d.session.ended and d.caughtPanel:isShowing(),"starvation reaches death screen")
check(d.session.summary and d.session.summary.cause=="starved","starvation records correct lineage cause")
check(d.fresh("free",false),"Free play starts after death")
d.needs.energy=0;d.needs.starvingStreakH=100;frames(3)
check(not d.life.lifeOver and not d.session.ended,"Free play cannot starve through real client")
print(`MEALS passed={passed} failed={failed}`)
if failed>0 then error("feeding/survival/context failed") end
