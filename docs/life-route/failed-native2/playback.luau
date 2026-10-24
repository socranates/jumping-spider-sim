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
local Probe=require(script.Parent.MatrixProbe)
return function(d:any)
 assert(Run:IsStudio()and Run:IsClient()and game.PlaceId==0 and game.GameId==0)
 local tag=tostring(DateTime.now().UnixTimestampMillis)
 local connection;local diagnostic;local replies={};local serial=0;local meals=0
 local clock:any=nil;local advance:any=nil;local moultAdvance:any=nil
 local awakeFactor,moultFactor=1,1
 local function emit(kind:string,value:any)print("[LIFE_ROUTE_"..kind.."]",tag,Http:JSONEncode(value))end
 local function facts():any
  local g=d.life.growth
  return{mode=d.session.mode,rules=d.session.rules,stage=g.stage,food=g.fedSinceMoult,ready=g.ready,
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
  emit("DEADLINE",facts());error("life-route deadline")
 end
 local function tap(action:string)
  d.input:simulate(action,true,"life-route");pause(.07)
  d.input:simulate(action,false,"life-route");pause(.07)
 end
 local function unbindClock()
  if clock then clock.advance=advance;clock.advanceMoult=moultAdvance end
  clock=nil;advance=nil;moultAdvance=nil;awakeFactor=1;moultFactor=1
 end
 local function bindClock()
  unbindClock();clock=d.life.clock;advance=clock.advance;moultAdvance=clock.advanceMoult
  local original,originalMoult=advance,moultAdvance
  clock.advance=function(self:any,dt:number,asleep:boolean):number return original(self,dt*awakeFactor,asleep)end
  clock.advanceMoult=function(self:any,dt:number):number return originalMoult(self,dt*moultFactor)end
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
  assert(math.abs(d.life.growth.fedSinceMoult-beforeFood-.3)<1e-6,"swallowed growth credit lost at full reserve")
  assert(d.meal.husk~=nil,"no husk after meal")
  emit("MEAL",facts())
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
 local okay,why=xpcall(function()
  Probe.ready({fixture="life-route",online=false})
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
