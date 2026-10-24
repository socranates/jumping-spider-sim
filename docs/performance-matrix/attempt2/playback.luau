--!strict
-- Unpublished controlled workload. Ordinary simulation/creatures stay enabled.
-- Fresh Free play lives, fixed weather clocks and authored scene arrivals are
-- benchmark fixtures, not a natural life, device or manual-walk proof.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local Map=require(RS.Shared.World.WorldMap)
local Environment=require(RS.Shared.World.Environment)
local Probe=require(script.Parent.MatrixProbe)
local scenes={
 {id="sill_dawn",region="sill",day=1,hour=6,yaw=0},
 {id="hut_lamp_night",region="hut_desk",day=1,hour=21,yaw=math.pi},
 {id="garden_rain",region="garden_a1",day=4,hour=9,yaw=math.pi/4},
 {id="meadow_wind",region="meadow_a3",day=2,hour=12,yaw=0},
 {id="pond_active",region="pond_a1",day=1,hour=12,yaw=0},
 {id="can",region="bin",day=1,hour=12,yaw=0},
 {id="doorway",region="hut_doorway",day=1,hour=12,yaw=math.pi/2},
 {id="bench_lamppost_night",region="lamp_1",day=1,hour=21,yaw=math.pi/2},
}
return function(d:any)
 assert(Run:IsStudio() and Run:IsClient() and game.PlaceId==0 and game.GameId==0 and WS:GetAttribute("MatrixPerf")==true)
 local connection;local serial=0;local replies={};local diagnostic
 local function waitFor(fn:()->boolean,seconds:number?)
  local untilAt=os.clock()+(seconds or 120)
  repeat
   if fn() then return end
   assert(not d.saveState.broken,"save application failed")
   Run.Heartbeat:Wait()
  until os.clock()>=untilAt
  error("matrix readiness deadline")
 end
 local function inspect(action:string):any
  serial+=1;local ticket=serial;diagnostic.Command:FireServer(action,ticket)
  waitFor(function():boolean return replies[ticket]~=nil end,30)
  local value=replies[ticket];replies[ticket]=nil;return value
 end
 local function live():boolean
  return d.session.started and not d.world.playerLoading and not d.life.lifeOver and not d.session.ended
   and not d.menu:isShowing() and not d.title:holding()
 end
 local function extra():any
  local weather=d.world.living.state
  return {region=d.world.region.id,position={d.motor.pos.X,d.motor.pos.Y,d.motor.pos.Z},
   mode=d.motor.mode,simulation=d.life.elapsed,live=live(),detail=d.detail,
   clock={d.life.clock.day,d.life.clock.hour},rain=weather and weather.rain,
   wind=weather and weather.wind.Magnitude,cat_enabled=d.cat and d.cat.enabled,
   viewport={WS.CurrentCamera.ViewportSize.X,WS.CurrentCamera.ViewportSize.Y}}
 end
 local function freshAt(scene:any)
  waitFor(function():boolean return not d.saveState.application:busy() end)
  -- Use the actual displayed offer identity. A bare fresh() deliberately
  -- refuses to choose New once an offer has arrived (save_continuation test).
  d.openMenu(true)
  local info=d.saveClient:offerInfo("free")
  assert(not info or not info.protected,"benchmark must not skip protected-New workflow")
  local previous=d.saveClient:decision("free")
  local displayed=d.saveState.menuOffers.free
  print("[MATRIX_CHOICE]",Http:JSONEncode({scene=scene.id,has_offer=info~=nil,
   displayed=displayed~=nil,previous_serial=previous and previous.serial}))
  assert(d.fresh("free",false,nil,displayed),"fresh free-play fixture refused")
  local selected=d.saveClient:decision("free")
  assert(selected and selected.kind=="new" and (not previous or selected.serial>previous.serial),"fresh fixture failed to submit a new intent")
  waitFor(function():boolean
   local decision=d.saveClient:decision("free")
   return decision~=nil and decision.state=="writable" and not d.saveState.application:held()
  end)
  local clock=d.life.clock
  clock.day,clock.hour=scene.day,scene.hour
  -- Freeze only the weather clock; action ticks, animation and AI remain live.
  clock.advance=function(_self:any,_seconds:number,_asleep:boolean):number return 0 end
  d.cam.mouse=false;d.cam.yaw=scene.yaw;d.cam.elevation=math.rad(25)
  local region=assert(Map.region(scene.region))
  d.place(region.spawn.pos+Vector3.yAxis*.31,Vector3.yAxis)
  d.cam:snap()
  waitFor(function():boolean
   return d.world.region.id==scene.region and live() and d.motor.mode=="attached"
    and d.world.looks:complete(scene.region)
  end)
  local warm=d.life.elapsed
  repeat Run.Heartbeat:Wait() until d.life.elapsed-warm>=5
  assert(live() and d.cat.enabled,"ordinary creatures or simulation not enabled")
  local weather=Environment.sample(scene.day,scene.hour,914)
  if scene.id=="garden_rain" then assert(weather.rain>.65,"rain fixture is dry")end
  if scene.id=="meadow_wind" then assert(weather.wind.Magnitude>2.4 and weather.rain<.01,"wind fixture differs")end
  print("[MATRIX_SCENE]",Http:JSONEncode({scene=scene.id,variant=WS:GetAttribute("MatrixVariant"),state=extra()}))
 end
 local okay,problem=xpcall(function()
  Probe.ready(extra())
  diagnostic=assert(RS:WaitForChild("NormalStartupDiagnostic",90))
  connection=diagnostic.Report.OnClientEvent:Connect(function(ticket:any,value:any)replies[ticket]=value end)
  waitFor(function():boolean
   return WS:GetAttribute("SaveStartupReady")==true and d.saveClient.newLifeEnabled and d.saveClient:recoveryReady()
    and not d.saveClient:offerPending() and Players.LocalPlayer:GetAttribute("TitleReady")==true
    and (not d.navigation or d.navigation.status=="ready")
  end)
  d.title.seen=true;d.title:stop();d.openMenu(true)
  assert(d.menu:choose("Free"),"ordinary Free play choice missing")
  waitFor(function():boolean return live() and not d.saveState.application:held() end)
  for _,scene in scenes do
   freshAt(scene);Probe.startSample(scene.id)
   local elapsed=d.life.elapsed
   repeat Run.Heartbeat:Wait()until d.life.elapsed-elapsed>=20
   assert(live() and d.motor.mode=="attached","stationary sample lost ordinary live support")
   local value=extra();value.simulation_seconds=d.life.elapsed-elapsed
   Probe.endSample(value)
  end
  -- Drive the real input state. No transport during the measured walk.
  freshAt({id="three_region_walk",region="garden_a1",day=2,hour=12,yaw=0})
  Probe.startSample("three_region_walk")
  local elapsed=d.life.elapsed;local start=d.motor.pos;local visited={garden_a1=true}
  d.input:simulate("Right",true,"matrix")
  repeat
   Run.Heartbeat:Wait();visited[d.world.region.id]=true
  until visited.garden_a3 or d.life.elapsed-elapsed>=90 or not live()
  d.input:simulate("Right",false,"matrix")
  local value=extra();value.simulation_seconds=d.life.elapsed-elapsed
  value.visited=visited;value.distance=(d.motor.pos-start).Magnitude
  Probe.endSample(value)
  assert(live() and visited.garden_a1 and visited.garden_a2 and visited.garden_a3,"three-region walk did not complete; inspect its actual trace")
  local final=inspect("finish")
  assert(final.active==0 and final.gate.scopes==0 and final.gate.started==0 and final.gate.queued==0
   and final.optionsCreated==final.optionsDestroyed,"matrix save fixture leaked work")
 end,debug.traceback)
 if connection then connection:Disconnect() end
 d.input:clear()
 Probe.finish(okay,problem)
end
