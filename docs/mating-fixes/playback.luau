--!strict
-- Synthetic adult/pair fixtures for native contact only. Not a natural life or hunt.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
local Mate=require(RS.Shared.Predator.Mate)
local Mating=require(RS.Shared.Life.Mating)
local Rules=require(RS.Shared.Data.MatingRules)
local Probe=require(script.Parent.MatrixProbe)
return function(d:any)
 assert(Run:IsStudio()and game.PlaceId==0 and game.GameId==0)
 local tag=tostring(DateTime.now().UnixTimestampMillis)
 local contactMonitor:any=nil;local connection:any=nil;local serial=0;local replies:any={};local results={}
 local function emit(kind:string,value:any)print("[MATING_CONTACT_"..kind.."]",tag,Http:JSONEncode(value))end
 local function pause(seconds:number)
  local stop=os.clock()+seconds;repeat Run.Heartbeat:Wait()until os.clock()>=stop
 end
 local function waitFor(fn:()->boolean,seconds:number?)
  local stop=os.clock()+(seconds or 90)
  repeat if fn()then return end;Run.Heartbeat:Wait()until os.clock()>=stop
  error("mating contact deadline")
 end
 local function tap(action:string)
  d.input:simulate(action,true,"mating-contact");pause(.08);d.input:simulate(action,false,"mating-contact");pause(.08)
 end
 local okay,why=xpcall(function()
  Probe.ready({fixture="synthetic-adult-mating-contact",online=false})
  local diagnostic=assert(RS:WaitForChild("NormalStartupDiagnostic",90))
  connection=diagnostic.Report.OnClientEvent:Connect(function(ticket:any,value:any)replies[ticket]=value end)
  waitFor(function():boolean return WS:GetAttribute("SaveStartupReady")==true and d.saveClient.newLifeEnabled and not d.saveClient:offerPending()and Players.LocalPlayer:GetAttribute("TitleReady")==true end)
  for _,playerSex in {"female","male"}do
   for _,skip in {false,true}do
    waitFor(function():boolean return not d.saveState.application:busy()end)
    d.openMenu(true);assert(d.fresh("free",false,nil,d.saveState.menuOffers.free))
    waitFor(function():boolean return not d.saveState.application:held()and not d.world.playerLoading and not d.menu:isShowing()and not d.title:holding()end)
    d.spiderPick.switch(if playerSex=="male"then"maratus_volans_male"else"first_spider")
    d.life.growth.stage=3;d.needs.energy=.9;d.life.clock.day=3;d.life.clock.hour=9
    local mate=Mate.new();local at=mate.position
    d.place(at+Vector3.xAxis*2,Vector3.yAxis);d.motor.heading=-Vector3.xAxis;d.world:refocus()
    waitFor(function():boolean return not d.world.playerLoading and d.motor.mode=="attached"and d.world:creatureLive(mate.region)end)
    mate.sex=Mate.opposite(playerSex);mate.scale=Mate.scaleFor(914,1,mate.sex)
    mate.state="pair";mate.scene=true;mate.elapsed=0;mate.heading=Vector3.xAxis
    d.life.mate=mate;d.life.mating=Mating.normalize({stage="courted",player_sex=playerSex,ready_day=1,mates=1,visits=1,visit_day=3})
    waitFor(function():boolean return d.mateLegs.couple.active and d.mateLegs.stage.rig~=nil end,10)
    local radius=d.mateLegs.clearance();local minGap=math.huge;local samples=0;local lostSupport=0
    contactMonitor=Run.Heartbeat:Connect(function()
     if mate.state=="leaving"then
      minGap=math.min(minGap,(mate.position-d.motor.pos).Magnitude);samples+=1
      if d.motor.mode~="attached"then lostSupport+=1 end
     end
    end)
    emit("PAIR",{player_sex=playerSex,skip=skip,player={d.motor.pos.X,d.motor.pos.Y,d.motor.pos.Z},mate={mate.position.X,mate.position.Y,mate.position.Z},radius=d.mateLegs.clearance()})
    if skip then pause(4.5);tap("Cancel")end
    waitFor(function():boolean return d.life.mating.stage=="mated"and not d.mateLegs.couple.active end,25)
    -- Script camera facing, then use the real held Forward input for 3 seconds.
    local stop=os.clock()+3
    d.input:simulate("Forward",true,"mating-contact")
    repeat
     local delta=mate.position-d.motor.pos
     d.cam.yaw=math.atan2(-delta.X,-delta.Z)-d.cam.framing.assist
     Run.Heartbeat:Wait()
    until os.clock()>=stop
    d.input:simulate("Forward",false,"mating-contact")
    assert(samples>0,"no departure samples")
    assert(minGap>=radius-.05,"native partner contact violated clearance")
    assert(lostSupport==0,"contact pushed player off support")
    -- Stay still while the visitor uses the ordinary exit route.
    waitFor(function():boolean return mate.state=="away"end,110)
    contactMonitor:Disconnect();contactMonitor=nil
    assert(minGap>=radius-.05 and lostSupport==0,"contact failed later in departure")
    local exitGap=(mate.position-Mate.exitAt()).Magnitude
    assert(exitGap<=Rules.exitRadius+.1,"mate left by timeout rather than reaching its exit")
    local result={player_sex=playerSex,mate_sex=mate.sex,skipped=skip,radius=radius,min_gap=minGap,samples=samples,lost_support=lostSupport,exit_gap=exitGap,reason=mate.reason,stage=d.life.mating.stage}
    table.insert(results,result);emit("ROUTE",result)
    if playerSex=="male"then
     local stage=d.life.mating.stage
     assert(Mating.woke(d.life,4)==""and d.life.mating.stage==stage and not Mating.hasSac(d.life.mating))
     emit("MALE_NO_SAC",{sex=d.life.mating.player_sex,stage=d.life.mating.stage})
    end
   end
  end
  serial+=1;diagnostic.Command:FireServer("finish",serial)
  waitFor(function():boolean return replies[serial]~=nil end,30)
  local final=replies[serial]
  assert(final.active==0 and final.gate.scopes==0 and final.optionsCreated==final.optionsDestroyed)
  emit("CLEANUP",final)
 end,debug.traceback)
 if contactMonitor then contactMonitor:Disconnect()end
 d.input:clear();if connection then connection:Disconnect()end
 emit(if okay then"PASS"else"FAIL",{problem=if okay then nil else tostring(why),routes=results})
 Probe.finish(okay,why)
end
