--!strict
-- Unpublished Studio/memory fixture. Seeds, swallowed-food credits and safe
-- placement are scripted. Ordinary rest input, growth ticks, checkpoint writes,
-- local return, rendering and unlock notices run live. No hunting/FPS claim.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
local Growth=require(RS.Shared.Life.Growth)
local Clock=require(RS.Shared.Life.LifeClock)
local Probe=require(script.Parent.MatrixProbe)
return function(d:any)
 assert(Run:IsStudio() and Run:IsClient() and game.PlaceId==0 and game.GameId==0)
 local tag=tostring(DateTime.now().UnixTimestampMillis)
 local original=Clock.advanceMoult
 local factor=1
 local function emit(kind:string,value:any)print("[INSTAR_HUNGER_"..kind.."]",tag,Http:JSONEncode(value))end
 local function waitFor(test:()->boolean,seconds:number?)
  local deadline=os.clock()+(seconds or 90)
  repeat if test() then return end;Run.Heartbeat:Wait() until os.clock()>deadline
  error("instar/hunger fixture deadline")
 end
 local function pause(seconds:number)
  local deadline=os.clock()+seconds
  repeat Run.Heartbeat:Wait() until os.clock()>deadline
 end
 local function tap(action:string)
  d.input:simulate(action,true,"instar-hunger");pause(.07)
  d.input:simulate(action,false,"instar-hunger");pause(.07)
 end
 local function checkpointReady():boolean
  local result=d.life.checkpointResult
  return result~=nil and result.ok==true and not result.pending
 end
 local function returnRest()
  d.returnToCheckpoint()
  waitFor(function():boolean
   local result=d.saveState.localReturnResult
   return result~=nil and result.ok==true and not result.pending and d.saveState.localRestore.job==nil and not d.world.playerLoading
  end)
 end
 local function fresh(mode:string,easy:boolean)
  d.openMenu(true)
  waitFor(function():boolean return not d.saveState.application:busy() end)
  local slot=if mode=="free" then "free" elseif easy then "easy" else "main"
  assert(d.fresh(mode,easy,nil,d.saveState.menuOffers[slot]),"new life refused")
  waitFor(function():boolean
   return not d.menu:isShowing() and not d.world.playerLoading and not d.title:holding() and not d.saveState.application:held()
  end)
  d.place(Vector3.new(-25.5,.31,6),Vector3.yAxis);d.world:refocus()
  waitFor(function():boolean return d.motor.mode=="attached" and not d.world.playerLoading and d.world:inRetreat(d.motor.pos)=="sill_crevice" end)
 end
 local connection;local diagnostic;local replies={}
 local okay,why=xpcall(function()
  Probe.ready({fixture="instar-hunger",online=false,scripted_food_credit=true})
  diagnostic=assert(RS:WaitForChild("NormalStartupDiagnostic",90))
  connection=diagnostic.Report.OnClientEvent:Connect(function(ticket:any,value:any)replies[ticket]=value end)
  waitFor(function():boolean return WS:GetAttribute("SaveStartupReady")==true and d.saveClient.newLifeEnabled and not d.saveClient:offerPending() and Players.LocalPlayer:GetAttribute("TitleReady")==true end)
  Clock.advanceMoult=function(self:any,dt:number):number return original(self,dt*factor)end
  local seeds={};for seed=1,100 do seeds[Growth.drawMaturity(seed)]=seed end
  for _,case in {{adult=8,mode="main",easy=false},{adult=7,mode="main",easy=false},{adult=8,mode="free",easy=false}} do
   fresh(case.mode,case.easy)
   local g=Growth.new();g:useInstarRules(d.needs.gentle,seeds[case.adult],true);d.life.growth=g
   assert(not g:canRun() and not g:canLock())
   for stage=1,g:adultStage() do
    if d.life.resting then tap("Cancel");waitFor(function():boolean return not d.life.resting end)end
    local goal=g:mealGoal()
    d.life.mealFood=goal*Growth.FLY_FOOD
    waitFor(function():boolean return g.ready end,5)
    local prior=d.life.checkpointResult
    factor=.001;tap("Feed")
    waitFor(function():boolean return g:isMoulting() and d.life.checkpointResult~=prior and checkpointReady()end)
    assert(not g:canRun() and not g:canLock())
    if stage==1 then
     local seed=g.lifeSeed;returnRest();g=d.life.growth
     assert(g.lifeSeed==seed and g.matureInstar==case.adult and g:isMoulting() and g.stage==0 and g.ready)
     emit("RESTORED",{adult=case.adult,mode=case.mode,stage=g.stage,seed=g.lifeSeed,moulting=g.moultingHoursLeft})
    end
    factor=12
    waitFor(function():boolean return g.stage==stage and not g:isMoulting()end,20)
    factor=1;pause(.2)
    assert(g:canRun()==(stage>=2) and g:canLock()==(stage>=5))
    assert(#g.exuviae==stage and g.fedSinceMoult==0 and g:isAdult()==(stage==g:adultStage()))
    if stage==2 then assert(string.find(d.life.notice,"You can now run",1,true))end
    if stage==5 then assert(string.find(d.life.notice,"You can now lock on",1,true))end
    local scales=require(RS.Shared.Data.Appearances).instars[d.appearance()][case.adult]
    assert(math.abs(d.rig()._growth-scales[stage+1])<1e-6)
    emit("MOULT",{adult=case.adult,mode=case.mode,stage=stage,instar=g:instar(),goal=goal,can_run=g:canRun(),can_lock=g:canLock(),size=d.rig()._growth,adult_now=g:isAdult(),skins=#g.exuviae})
    waitFor(checkpointReady)
   end
   assert(d.session.finishedMain and g:isAdult())
   emit("ADULT",{adult=case.adult,mode=case.mode,skins=#g.exuviae,seed=g.lifeSeed})
  end
  local player=Players.LocalPlayer
  for _,food in {1,.55,.1} do
   d.needs.energy=food;player:SetAttribute("HungerDisplay","veil");pause(3)
   local edge=d.hud.hungerEdges[1]
   assert(not d.hud.food.Visible and not d.hud.foodText.Visible)
   emit("VEIL",{food=food,shown=edge.Visible,extent=edge.Size.X.Scale,opacity=1-edge.BackgroundTransparency})
  end
  -- Keep this view available long enough for a screenshot, then verify fallback.
  emit("SCREENSHOT_READY",{food=d.needs.energy});pause(20)
  player:SetAttribute("HungerDisplay","bar");pause(.5)
  assert(d.hud.food.Visible and not d.hud.hungerEdges[1].Visible)
  emit("BAR",{reserve=d.needs.energy,fill=d.hud.foodFill.Size.X.Scale})
  player:SetAttribute("HungerDisplay","veil")
  diagnostic.Command:FireServer("finish",1)
  waitFor(function():boolean return replies[1]~=nil end,30)
  local final=replies[1]
  assert(final.active==0 and final.gate.scopes==0 and final.optionsCreated==final.optionsDestroyed)
  emit("CLEANUP",final)
 end,debug.traceback)
 Clock.advanceMoult=original;d.input:clear();if connection then connection:Disconnect()end
 emit(if okay then "PASS" else "FAIL",{problem=if okay then nil else tostring(why)})
 Probe.finish(okay,why)
end
