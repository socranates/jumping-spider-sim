--!strict
-- Unpublished Studio/memory route. Successful full-housefly captures and safe
-- Crack arrivals are fixture setup; struggle, taps, swallowed food, growth,
-- rest admission, checkpoint preparation and adult unlock use ordinary ticks.
-- No stage/energy/food counters are assigned; no mating outcome is forced.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
local Fly=require(RS.Shared.Prey.Fly)
local Species=require(RS.Shared.Data.Species)
local LifeClock=require(RS.Shared.Life.LifeClock)
local Rules=require(RS.Shared.Data.MatingRules)
local Mate=require(RS.Shared.Predator.Mate)
local Mating=require(RS.Shared.Life.Mating)
local Probe=require(script.Parent.MatrixProbe)
return function(d:any)
 assert(Run:IsStudio()and Run:IsClient()and game.PlaceId==0 and game.GameId==0)
 local tag=tostring(DateTime.now().UnixTimestampMillis)
 local connection;local diagnostic;local replies={};local serial=0;local meals=0
 local advance:any=nil;local moultAdvance:any=nil
 local awakeFactor,moultFactor=1,1
 local checking="startup"
 local function matingStage():string return d.life.mating.stage end
 local function familyPhase():string return d.mateLegs.phase end
 local function emit(kind:string,value:any)print("[FAMILY_ROUTE_"..kind.."]",tag,Http:JSONEncode(value))end
 local function facts():any
  local g=d.life.growth
  local m=d.life.mating or {}
  local mate=d.life.mate or {}
  return{checking=checking,generation=Mating.generation(d.life),mating=m.stage,ready_day=m.ready_day,guard_day=m.guard_day,sac_day=m.sac_day,hatch_day=m.hatch_day,brood=m.brood,visits=m.visits,rejections=m.rejections or 0,cut_ins=m.cut_ins or 0,phase=d.mateLegs.phase,mate_state=mate.state,meter=mate.meter,sees=d.mateLegs.drive and d.mateLegs.drive.sees or false,resting=d.life.resting,asleep=d.life.asleep,checkpoint=d.life.checkpointResult and {ok=d.life.checkpointResult.ok,pending=d.life.checkpointResult.pending,message=d.life.checkpointResult.message},mode=d.session.mode,rules=d.session.rules,stage=g.stage,food=g.fedSinceMoult,ready=g.ready,
   goal=g:mealGoal(),soft=g.softHoursLeft,moulting=g.moultingHoursLeft,energy=d.needs.energy,
   meals=d.prey.feeding.mealsFinished,can_run=g:canRun(),can_lock=g:canLock(),
   day=d.life.clock.day,hour=d.life.clock.hour,counter=d.hud.moultProgress.Text,
   finished_main=d.session.finishedMain,ended=d.session.ended}
 end
 local function pause(seconds:number)
  local untilAt=os.clock()+seconds
  repeat Run.Heartbeat:Wait();assert(not d.saveState.broken,"save application failed")until os.clock()>=untilAt
 end
 local function waitFor(fn:()->boolean,seconds:number?)
  local untilAt=os.clock()+(seconds or 90)
  repeat if fn()then return end;pause(0)until os.clock()>=untilAt
  emit("DEADLINE",facts());error("family-route deadline")
 end
 local function tap(action:string)
  d.input:simulate(action,true,"family-route");pause(.07)
  d.input:simulate(action,false,"family-route");pause(.07)
 end
 local function unbindClock()
  if advance then LifeClock.advance=advance;LifeClock.advanceMoult=moultAdvance end
  advance=nil;moultAdvance=nil;awakeFactor=1;moultFactor=1
 end
 local function bindClock()
  -- The class is outside the saved object graph. Per-instance closures correctly
  -- fail ObjectRecord's unnamed-function guard and cannot test real checkpoints.
  unbindClock();advance=LifeClock.advance;moultAdvance=LifeClock.advanceMoult
  local original,originalMoult=advance,moultAdvance
  LifeClock.advance=function(self:any,dt:number,asleep:boolean):number return original(self,dt*awakeFactor,asleep)end
  LifeClock.advanceMoult=function(self:any,dt:number):number return originalMoult(self,dt*moultFactor)end
 end
 local function fresh(mode:string,easy:boolean)
  unbindClock();waitFor(function():boolean return not d.saveState.application:busy()end)
  d.openMenu(true)
  local slot=if mode=="free"then"free"elseif easy then"easy"else"main"
  assert(d.fresh(mode,easy,nil,d.saveState.menuOffers[slot]),"fresh route refused")
  waitFor(function():boolean
   local decision=d.saveClient:decision(slot)
   return decision~=nil and decision.state=="writable"and not d.saveState.application:held()
    and not d.world.playerLoading and not d.menu:isShowing()and not d.title:holding()
  end)
  d.place(Vector3.new(-25.5,.31,6),Vector3.yAxis)
  waitFor(function():boolean return d.motor.mode=="attached"and d.world:inRetreat(d.motor.pos)=="sill_crevice"end)
  bindClock()
  assert(d.life.growth.stage==0 and not d.life.growth:canRun()and not d.life.growth:canLock())
  emit("FRESH",facts())
 end
 local function eat()
  awakeFactor=1;moultFactor=1
  if d.life.resting then tap("Cancel");waitFor(function():boolean return not d.life.resting end)end
  assert(not d.prey.feeding.held and not d.session.ended and d.motor.mode=="attached")
  meals+=1
  -- A new full-profile fly is presented as a successful catch. A private perch
  -- keeps fixture construction from stealing a real live fly's occupied perch.
  local perch={id="route_capture_"..meals,position=d.motor.pos,normal=Vector3.yAxis,shelter=0,food=1,occupant="",reserved="",valid=true}
  local fly=Fly.new("route_meal_"..meals,100000+meals,914+meals*997,perch,d.prey.graph,Species.fly_like_prototype,d.prey.now)
  assert(math.abs(fly.nutrition-.35)<1e-9)
  fly.flight:release();perch.occupant=""
  fly.state="CAPTURED";fly.captureSerial+=1;fly.captureKey=fly.id..":"..fly.captureSerial;fly.velocity=Vector3.zero
  table.insert(d.prey.flies,fly);d.prey.captures+=1
  local feeding=d.prey.feeding;local beforeFood=d.life.growth.fedSinceMoult
  local beforeMeals=feeding.mealsFinished;local beforeTaken=feeding.taken;local beforeBites=feeding.bites
  assert(not feeding.auto,"route requires manual taps")
  feeding:capture(fly)
  local partial=false;local sawStruggle=false;local untilAt=os.clock()+25
  repeat
   sawStruggle=sawStruggle or feeding.struggling
   tap("Feed")
   partial=partial or(fly.nutrition>0 and fly.nutrition<.35)
   assert(not d.session.ended,"route died while eating")
  until feeding.held==nil or os.clock()>=untilAt
  assert(feeding.held==nil and fly.state=="CONSUMED"and fly.nutrition==0,"full fly not eaten")
  pause(.15)
  assert(partial and sawStruggle and feeding.bites>beforeBites,"meal bypassed struggle or bites")
  assert(feeding.mealsFinished==beforeMeals+1 and math.abs(feeding.taken-beforeTaken-.35)<1e-6)
  assert(math.abs(d.life.growth.fedSinceMoult-beforeFood-(if d.life.growth:isAdult()then 0 else .3))<1e-6,"swallowed growth credit lost at full reserve")
  assert(d.meal.husk~=nil,"no husk after meal")
  emit(if Mating.generation(d.life)>0 then"NEXT_MEAL"elseif d.life.growth:isAdult()then"ADULT_MEAL"else"MEAL",facts())
 end
 local function moult(stage:number)
  local g=d.life.growth
  assert(g.ready and g.stage==stage-1 and not g:isMoulting())
  moultFactor=8;tap("Feed")
  waitFor(function():boolean return g:isMoulting()end,5)
  assert(not g:canRun()and not g:canLock(),"moult left movement unlock active")
  emit("MOULT_START",facts())
  waitFor(function():boolean return g.stage==stage and not g:isMoulting()end,15)
  pause(.1)
  assert(g:isSoft()and g.fedSinceMoult==0 and #g.exuviae==stage)
  assert(g:canRun()==(stage>=1)and g:canLock()==(stage>=2))
  assert(d.rig().model:GetAttribute("GrowthStage")==stage,"drawn rig missed instar")
  emit("MOULT_END",facts())
  awakeFactor=120
  waitFor(function():boolean return not g:isSoft()end,30)
  awakeFactor=1;moultFactor=1
  waitFor(function():boolean
   local r=d.life.checkpointResult
   return r~=nil and not r.pending and r.ok==true
  end,120)
  assert(d.currentStore():loadBest().ok and not d.session.ended,"moult checkpoint missing")
  emit("HARDENED",facts())
 end
 local function home()
  checking="return to Crack"
  d.place(Vector3.new(-25.5,.31,6),Vector3.yAxis);d.world:refocus()
  waitFor(function():boolean return d.motor.mode=="attached"and not d.world.playerLoading and d.world:inRetreat(d.motor.pos)=="sill_crevice"end)
 end
 local function rest()
  checking="retained rest"
  if d.life.resting then tap("Cancel");waitFor(function():boolean return not d.life.resting end)end
  local old=d.life.checkpointResult
  tap("Feed");assert(d.life.resting,"empty-jaws Rest refused")
  waitFor(function():boolean
   local r=d.life.checkpointResult
   return r~=nil and r~=old and r.ok==true and not r.pending
  end,120)
  assert(d.currentStore():loadBest().ok,"no retained rest")
 end
 local function refill()
  checking="adult refuel"
  while d.needs.energy<.9 do eat()end
 end
 local function nextMorning(day:number)
  checking="advance to morning"
  awakeFactor=120
  waitFor(function():boolean return d.life.clock.day>=day and d.life.clock.hour>=7 and d.life.clock.hour<10 end,45)
  awakeFactor=1
  assert(not d.session.ended,"life ended across night")
 end
 local function restoreLocal()
  checking="restore retained rest"
  d.returnToCheckpoint()
  waitFor(function():boolean
   local r=d.saveState.localReturnResult
   return r~=nil and r.ok==true and not r.pending and d.saveState.localRestore.job==nil
    and not d.menu:isShowing()and not d.world.playerLoading
  end,120)
  assert(not d.saveState.restoreError and not d.session.ended,"local return refused")
 end
 local function reproduce(mode:string)
  checking="adult eligibility"
  assert(Rules.game.on==true,"Normal acceptance rules disabled")
  local generation=Mating.generation(d.life)
  home();refill();rest()
  assert(d.life.mating.ready_day>0,"fed adult rest did not schedule a mate")
  emit("ELIGIBLE",facts())
  for attempt=1,4 do
   if matingStage()=="mated"then break end
   local wanted=math.max(d.life.mating.ready_day,(d.life.mating.away_day or 0)+1)
   nextMorning(wanted)
   home();refill()
   if d.life.resting then tap("Cancel")end
   checking="mate arrival"
   local at=Mate.arriveAt()
   d.place(at+Vector3.zAxis*12,Vector3.yAxis);d.world:refocus()
   waitFor(function():boolean return not d.world.playerLoading and d.motor.mode=="attached"and d.world:creatureLive(d.life.mate.region)and Mate.courtable(d.life.mate)end,30)
   emit("VISITOR",facts())
   local mate=d.life.mate
   -- Only the player's approach and facing are scripted. The mate's position,
   -- senses, meter, seeded decision, rival interference and scene remain live.
   local near=mate.position+Vector3.zAxis*2.1
   d.place(near,Vector3.yAxis);d.motor.heading=-Vector3.zAxis;d.world:refocus()
   checking="live courtship"
   local untilAt=os.clock()+35
   repeat
    local delta=mate.position-d.motor.pos
    local flat=delta-d.motor.up*delta:Dot(d.motor.up)
    if flat.Magnitude>.05 then d.motor.heading=flat.Unit end
    pause(.05)
    assert(not d.session.ended,"spider died during courtship")
   until matingStage()=="courted"or matingStage()=="mated"or not Mate.courtable(mate)or os.clock()>=untilAt
   emit("COURT_RESULT",facts())
   if matingStage()=="courted"or matingStage()=="mated"then
    checking="mating scene"
    waitFor(function():boolean return matingStage()=="mated"and not d.mateLegs.couple.active end,30)
    assert(d.mateLegs.stage.rig~=nil,"mate not drawn")
    emit("MATED",facts());break
   end
   assert(mate.reason=="rejected"or mate.reason=="cut","courtship never progressed")
   emit("REFUSED",facts())
   home();refill();rest()
  end
  assert(matingStage()=="mated","four natural courts did not produce mating")
  home();refill();rest()
  checking="egg sac morning"
  awakeFactor=120
  waitFor(function():boolean return matingStage()=="sac"end,45)
  awakeFactor=1;pause(.2)
  assert(d.life.mating.guard_day==1 and d.mateLegs.stage.sac~=nil,"first guard day or drawn sac missing")
  emit("SAC",facts())
  home();refill();rest()
  checking="second guard morning";awakeFactor=120
  waitFor(function():boolean return matingStage()=="guarding"end,45)
  awakeFactor=1;pause(.2)
  assert(d.life.mating.guard_day==Rules.guardDays,"guard days skipped")
  emit("GUARDING",facts())
  -- Keep and reopen this actual guarded family before the hatching. Its
  -- seeded brood must survive reconstruction, not a hand-built save fixture.
  home();refill();rest()
  local expectedBrood=Mating.broodSize(914,generation,d.life.mating.sac_day+Rules.guardDays)
  local sacDay=d.life.mating.sac_day
  restoreLocal()
  assert(matingStage()=="guarding"and d.life.mating.sac_day==sacDay,"guarded family changed on return")
  emit("GUARD_RESTORED",facts())
  checking="hatching morning";awakeFactor=120
  waitFor(function():boolean return matingStage()=="hatched"end,45)
  awakeFactor=1;pause(.2)
  assert(d.life.mating.brood==expectedBrood and d.life.mating.hatch_day==sacDay+Rules.guardDays,"brood or hatch day rerolled")
  assert(familyPhase()=="scene"and #d.mateLegs.stage.plan>0,"hatching scene missing")
  emit("HATCHED",facts())
  checking="hatching card"
  waitFor(function():boolean return familyPhase()=="card"and d.caughtPanel:isShowing()and d.caughtPanel.seconds>=5 end,45)
  emit("FAMILY_CARD",facts())
  local hatchDay=d.life.mating.hatch_day
  local mealBase=d.prey.feeding.mealsFinished
  local choice=if mode=="free"then"Follow"else"Carry"
  assert(d.caughtPanel:choose(choice),"family choice refused")
  checking="next generation"
  waitFor(function():boolean return Mating.generation(d.life)==generation+1 and familyPhase()==""and not d.caughtPanel:isShowing()and not d.world.playerLoading and d.motor.mode=="attached"end,45)
  -- Carry is a UI callback between ticks. Observe the ordinary fixed tick's
  -- existing rule admission before checking gameplay or attempting any food.
  -- No return/save is allowed to repair this transition for the test.
  waitFor(function():boolean return d.life.growth.gameRules==true and d.life.growth:mealGoal()==7 end,2)
  assert(d.life.growth.stage==0 and not d.life.growth:canRun()and not d.life.growth:canLock())
  assert(d.life.growth:mealGoal()==7 and d.life.growth.gameRules==true,"new generation reverted to frozen three-meal rules")
  assert(d.life.born==hatchDay-1 and d.life.mealsBase==mealBase and matingStage()=="none")
  assert(d.needs.energy>.5 and d.needs.energy<=.55 and d.needs.starvingStreakH==0)
  assert(d.rig().model:GetAttribute("GrowthStage")==0 and d.mateLegs.stage.sac==nil,"old family presentation survived")
  emit("GENERATION",facts())
  for _=1,3 do eat()end
  assert(not d.life.growth.ready and not d.life.growth:isMoulting()and d.life.growth:mealGoal()==7,"three meals prematurely complete a new generation's first moult")
  home();rest();restoreLocal()
  assert(Mating.generation(d.life)==generation+1 and d.life.growth.stage==0 and d.life.mealsBase==mealBase and d.life.born==hatchDay-1)
  assert(d.life.growth:mealGoal()==7 and not d.life.growth.ready and math.abs(d.life.growth.fedSinceMoult-.9)<1e-6,"new generation food changed on local return")
  emit("GENERATION_RESTORED",facts())
 end
 local okay,why=xpcall(function()
  Probe.ready({fixture="family-route",online=false})
  diagnostic=assert(RS:WaitForChild("NormalStartupDiagnostic",90))
  connection=diagnostic.Report.OnClientEvent:Connect(function(ticket:any,value:any)replies[ticket]=value end)
  waitFor(function():boolean return WS:GetAttribute("SaveStartupReady")==true and d.saveClient.newLifeEnabled and not d.saveClient:offerPending()and Players.LocalPlayer:GetAttribute("TitleReady")==true end)
  emit("BEGIN",{scripted_catches=true,manual_struggle_and_eating=true,awake_factor=120,moult_factor=8,online=false})
  for _,mode in {"normal","easy","free"}do
   fresh(if mode=="free"then"free"else"main",mode=="easy")
   local targets={7,10,if mode=="normal"then 5 else 3}
   for stage,goal in targets do
    assert(d.life.growth:mealGoal()==goal)
    for i=1,goal do
     eat();assert(d.life.growth.ready==(i==goal),"moult ready at wrong full-meal count")
     assert(d.life.growth.stage==stage-1,"food alone changed instar")
    end
    moult(stage)
   end
   assert(d.life.growth:isAdult()and d.session.finishedMain,"adult did not unlock Easy")
   emit("ADULT",facts())
   reproduce(mode)
  end
  unbindClock();serial+=1;diagnostic.Command:FireServer("finish",serial)
  waitFor(function():boolean return replies[serial]~=nil end,30)
  local final=replies[serial]
  assert(final.active==0 and final.gate.scopes==0 and final.gate.started==0 and final.gate.queued==0 and final.optionsCreated==final.optionsDestroyed)
  emit("CLEANUP",final)
 end,debug.traceback)
 unbindClock();d.input:clear();if connection then connection:Disconnect()end
 emit(if okay then"PASS"else"FAIL",{problem=if okay then nil else tostring(why)})
 Probe.finish(okay,why)
end
