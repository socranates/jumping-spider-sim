--!strict
-- Unpublished unbound Studio/memory fixture. Parent age and hatching are
-- synthetic; ordinary Carry/Follow, landing, save workers and Back run live.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local Mating=require(RS.Shared.Life.Mating)
local WorldMap=require(RS.Shared.World.WorldMap)
local Probe=require(script.Parent.MatrixProbe)
return function(d:any)
 assert(Run:IsStudio() and Run:IsClient() and game.PlaceId==0 and game.GameId==0)
 local tag=tostring(DateTime.now().UnixTimestampMillis)
 local diagnostic;local connection;local replies={}
 local function emit(kind:string,value:any) print("[GENERATION_CHECKPOINT_"..kind.."]",tag,Http:JSONEncode(value)) end
 local function waitFor(fn:()->boolean,seconds:number?)
  local deadline=os.clock()+(seconds or 90)
  repeat if fn() then return end;Run.Heartbeat:Wait() until os.clock()>deadline
  error("generation checkpoint fixture deadline")
 end
 local function pause(seconds:number)
  local deadline=os.clock()+seconds
  repeat Run.Heartbeat:Wait() until os.clock()>=deadline
 end
 local function fresh(mode:string,easy:boolean)
  d.openMenu(true)
  waitFor(function():boolean return not d.saveState.application:busy() end)
  local slot=if mode=="free" then "free" elseif easy then "easy" else "main"
  assert(d.fresh(mode,easy,nil,d.saveState.menuOffers[slot]))
  waitFor(function():boolean return not d.menu:isShowing() and not d.world.playerLoading and not d.title:holding() and not d.saveState.application:held() end)
  d.place(Vector3.new(-25.5,.31,6),Vector3.yAxis);d.world:refocus()
  waitFor(function():boolean return d.motor.mode=="attached" and not d.world.playerLoading end)
  pause(.15)
 end
 local workClock=0
 local originalOptions=d.saveState.rest.cfg.workOptions
 local okay,why=xpcall(function()
  Probe.ready({fixture="generation-checkpoint",online=false,synthetic_parent=true})
  diagnostic=assert(RS:WaitForChild("NormalStartupDiagnostic",90))
  connection=diagnostic.Report.OnClientEvent:Connect(function(ticket:any,value:any) replies[ticket]=value end)
  waitFor(function():boolean return WS:GetAttribute("SaveStartupReady")==true and d.saveClient.newLifeEnabled and not d.saveClient:offerPending() and Players.LocalPlayer:GetAttribute("TitleReady")==true end)
  for _,case in {{mode="main",easy=false,choice="Carry"},{mode="main",easy=true,choice="Carry"},{mode="free",easy=false,choice="Follow"}} do
   fresh(case.mode,case.easy)
   local life=d.life
   life:stopRest();life.clock.day,life.clock.hour=6,7
   life.growth.stage=life.growth:adultStage();d.needs.energy=.8
   life.mating=Mating.normalize({stage="guarding",sac_day=4,guard_day=2,mates=1})
   local parent=life:makeCheckpoint()
   waitFor(function():boolean return parent.pending~=true end);assert(parent.ok,"parent fixture save refused")
   life.mating=Mating.normalize({stage="hatched",sac_day=4,guard_day=2,hatch_day=6,hatch_hour=7,brood=9,mates=1})
   waitFor(function():boolean return d.mateLegs.phase=="card" and d.caughtPanel:isShowing() end)
   d.caughtPanel:update(10)
   d.saveState.rest.cfg.workOptions={budget=.001,maxSeconds=1000,now=function():number workClock+=.00001;return workClock end}
   assert(d.caughtPanel:choose(case.choice),"generation choice refused")
   waitFor(function():boolean return Mating.generation(life)==1 and d.saveState.birth~=nil end,45)
   local seed=life.growth.lifeSeed
   local zone,region=life.start_zone,life.start_region
   local at=d.motor.pos
   local entries=#d.notebook:entriesFor("eggs_and_wind")
   assert(d.saveState.birth.result.pending,"fixture must exercise Back while the baseline is pending")
   assert(not life.resting and not life.asleep and life.growth.stage==0 and life.mating.stage=="none")
   d.returnToCheckpoint()
   local result=d.saveState.localReturnResult
   assert(result and result.pending and d.saveState.birthReturning(),"Back did not queue")
   emit("QUEUED",{mode=case.mode,easy=case.easy,choice=case.choice,seed=seed,zone=zone,region=region,x=at.X,y=at.Y,z=at.Z})
   life.generation=77 -- return must truly apply; ignoring Back cannot pass
   waitFor(function():boolean return result.pending~=true and d.saveState.localRestore.job==nil and not d.world.playerLoading end)
   assert(result.ok,"queued Back failed")
   pause(.15)
   assert(Mating.generation(life)==1 and life.growth.lifeSeed==seed and life.mating.stage=="none" and not life.resting)
   assert(d.motor.mode=="attached" and (d.motor.pos-at).Magnitude<1)
   assert(life.start_zone==zone and life.start_region==region and #d.notebook:entriesFor("eggs_and_wind")==entries)
   assert(d.mateLegs.phase=="" and not d.caughtPanel:isShowing() and d.prey.feeding.held==nil)
   if region then assert(d.world.region.id==region and WorldMap.inRetreat(d.motor.pos)==nil) end
   emit("RETURNED",{mode=case.mode,easy=case.easy,choice=case.choice,generation=life.generation,seed=life.growth.lifeSeed,zone=zone,region=region,attached=d.motor.mode=="attached",distance=(d.motor.pos-at).Magnitude,entries=entries})
   d.saveState.rest.cfg.workOptions=originalOptions
  end
  diagnostic.Command:FireServer("finish",1)
  waitFor(function():boolean return replies[1]~=nil end,30)
  local final=replies[1]
  assert(final.active==0 and final.gate.scopes==0 and final.optionsCreated==final.optionsDestroyed)
  emit("CLEANUP",final)
 end,debug.traceback)
 d.saveState.rest.cfg.workOptions=originalOptions
 d.input:clear();if connection then connection:Disconnect() end
 emit(if okay then "PASS" else "FAIL",{problem=if okay then nil else tostring(why)})
 Probe.finish(okay,why)
end
