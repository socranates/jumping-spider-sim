--!strict
-- Unpublished native support exercise. Authored arrivals between independent
-- routes; all measured route movement and hops use the real input path.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local Map=require(RS.Shared.World.WorldMap)
local Hut=require(RS.Shared.World.Hut)
local Probe=require(script.Parent.MatrixProbe)
local routes={
 {id="path_west",region="path_m1",axis="X",goal=-115,action="Left"},
 {id="path_east",region="path_m2",axis="X",goal=-5,action="Right"},
 {id="path_north",region="path_m4",axis="Z",goal=-536,action="Forward"},
 {id="pad_meadow",region="pad_c2",axis="Z",goal=-838,action="Forward",start=Vector3.new(-20,Hut.GROUND,-808)},
 {id="mown_north",region="mown_e1",axis="Z",goal=-750,action="Forward"},
 {id="mown_south",region="mown_e1",axis="Z",goal=-610,action="Back"},
}
return function(d:any)
 assert(Run:IsStudio()and Run:IsClient()and game.PlaceId==0 and game.GameId==0 and WS:GetAttribute("MatrixPerf")==true)
 local tag=tostring(DateTime.now().UnixTimestampMillis)
 local function emit(kind:string,value:any)print("[SEAM_"..kind.."]",tag,Http:JSONEncode(value))end
 local function live():boolean
  return d.session.started and not d.life.lifeOver and not d.session.ended and not d.menu:isShowing()and not d.title:holding()
 end
 local function waitFor(fn:()->boolean,seconds:number?)
  local untilAt=os.clock()+(seconds or 90)
  repeat
   if fn()then return end
   assert(not d.saveState.broken,"save application failed")
   Run.Heartbeat:Wait()
  until os.clock()>=untilAt
  error("seam readiness deadline")
 end
 local serial=0;local replies={};local diagnostic;local connection
 local function inspect(action:string):any
  serial+=1;local ticket=serial;diagnostic.Command:FireServer(action,ticket)
  waitFor(function():boolean return replies[ticket]~=nil end,30)
  local value=replies[ticket];replies[ticket]=nil;return value
 end
 local function point(p:Vector3):{number}return{p.X,p.Y,p.Z}end
 local function state():any
  local kinds={};local projected=0
  for _,fly in d.world.prey:flies()do
   local kind=fly.profile and fly.profile.body and fly.profile.body.prey_kind or "unknown"
   kinds[kind]=(kinds[kind]or 0)+1
   local _,inView=WS.CurrentCamera:WorldToViewportPoint(fly.position)
   if inView then projected+=1 end
  end
  return{position=point(d.motor.pos),up=point(d.motor.up),region=d.world.region.id,mode=d.motor.mode,
   live=live(),loading=d.world.playerLoading,detail=d.detail,prey=kinds,prey_projected=projected,
   fov=WS.CurrentCamera.FieldOfView,viewport={WS.CurrentCamera.ViewportSize.X,WS.CurrentCamera.ViewportSize.Y}}
 end
 local function arrive(route:any)
  waitFor(function():boolean return not d.saveState.application:busy()end)
  d.openMenu(true)
  local info=d.saveClient:offerInfo("free")
  assert(not info or not info.protected,"must not bypass protected New")
  local previous=d.saveClient:decision("free")
  assert(d.fresh("free",false,nil,d.saveState.menuOffers.free),"fresh fixture refused")
  local selected=d.saveClient:decision("free")
  assert(selected and selected.kind=="new"and(not previous or selected.serial>previous.serial))
  waitFor(function():boolean
   local value=d.saveClient:decision("free")
   return value and value.state=="writable"and not d.saveState.application:held()
  end)
  local region=assert(Map.region(route.region));local pos=route.start or region.spawn.pos
  d.life.clock.day,d.life.clock.hour=2,12
  d.life.clock.advance=function(_self:any,_seconds:number,_asleep:boolean):number return 0 end
  d.place(pos+Vector3.yAxis*.31,Vector3.yAxis);d.cam:snap()
  d.cam.mouse=false;d.cam.yaw=0;d.cam.elevation=math.rad(25);d.cam.framing:reset();d.cam:tick(0)
  waitFor(function():boolean return d.world.region.id==route.region and live()and not d.world.playerLoading and d.motor.mode=="attached"and d.world.looks:complete(route.region)end)
  local started=d.life.elapsed
  repeat Run.Heartbeat:Wait()until d.life.elapsed-started>=3
  assert(math.abs(WS.CurrentCamera.FieldOfView-65)<.001)
  emit("ARRIVAL",{route=route.id,state=state()})
 end
 local failures={};local results={};local lostFocus=0
 local focus=game:GetService("UserInputService").WindowFocusReleased:Connect(function()lostFocus+=1 end)
 local okay,why=xpcall(function()
  Probe.ready(state())
  diagnostic=assert(RS:WaitForChild("NormalStartupDiagnostic",90))
  connection=diagnostic.Report.OnClientEvent:Connect(function(ticket:any,value:any)replies[ticket]=value end)
  waitFor(function():boolean
   return WS:GetAttribute("SaveStartupReady")==true and d.saveClient.newLifeEnabled and d.saveClient:recoveryReady()
    and not d.saveClient:offerPending()and Players.LocalPlayer:GetAttribute("TitleReady")==true and(not d.navigation or d.navigation.status=="ready")
  end)
  d.title.seen=true;d.title:stop();d.openMenu(true);assert(d.menu:choose("Free"))
  waitFor(function():boolean return live()and not d.saveState.application:held()end)
  emit("BEGIN",{routes=#routes,detail=d.detail,storage="unbound yielding memory only"})
  for _,route in routes do
   local passed,problem=xpcall(function()
    arrive(route)
    local started=os.clock();local sim=d.life.elapsed;local initial=d.motor.pos
    local frames,loading=0,0;local modes={};local visited={};local minY=initial.Y;local maxStep=0;local prior=initial
    local from=if route.axis=="X"then initial.X else initial.Z
    local sign=if route.goal>from then 1 else -1
    local reached=false
    Probe.startSample(route.id)
    d.input:simulate(route.action,true,"seam")
    repeat
     Run.Heartbeat:Wait();frames+=1;visited[d.world.region.id]=true
     modes[d.motor.mode]=(modes[d.motor.mode]or 0)+1
     if d.world.playerLoading then loading+=1 end
     minY=math.min(minY,d.motor.pos.Y);maxStep=math.max(maxStep,(d.motor.pos-prior).Magnitude);prior=d.motor.pos
     local coordinate=if route.axis=="X"then d.motor.pos.X else d.motor.pos.Z
     reached=(coordinate-route.goal)*sign>=0
    until reached or os.clock()-started>=65 or not live()or minY<Hut.GROUND-4
    d.input:simulate(route.action,false,"seam")
    local result={route=route.id,goal=route.goal,reached=reached,wall_seconds=os.clock()-started,simulation=d.life.elapsed-sim,
     frames=frames,loading_frames=loading,modes=modes,visited=visited,min_y=minY,max_step=maxStep,start=point(initial)}
    table.insert(results,result);emit("WALK",result);emit("STATE",{route=route.id,when="walk_end",state=state()});Probe.endSample(result)
    assert(reached and live()and minY>=Hut.GROUND-4,"route did not cross safely; inspect WALK evidence")
    assert(d.motor.mode=="attached","walk ended without attachment")
    -- A single short press follows the same event path as Space/A/touch Jump.
    -- No target override or growth/aim assist is injected.
    local last=d.jump.last;local tick=last and last.tick or -1
    local hopStart=d.motor.pos;local hopModes={};local hopFrames=0;local left=false
    d.input:simulate("Jump",true,"seam");Run.Heartbeat:Wait();d.input:simulate("Jump",false,"seam")
    local deadline=os.clock()+8
    repeat
     Run.Heartbeat:Wait();hopFrames+=1;hopModes[d.motor.mode]=(hopModes[d.motor.mode]or 0)+1
     if d.motor.mode~="attached"then left=true end
    until(left and d.motor.mode=="attached")or os.clock()>=deadline or not live()
    local jump=d.jump.last
    local hop={route=route.id,frames=hopFrames,modes=hopModes,left_support=left,
     result=jump and jump.kind,fresh=jump and jump.tick>tick,distance=(d.motor.pos-hopStart).Magnitude}
    emit("HOP",hop);emit("STATE",{route=route.id,when="hop_end",state=state()})
    assert(jump and jump.tick>tick and jump.kind=="launched"and left and d.motor.mode=="attached"and live(),"tap-hop did not launch/land; inspect HOP evidence")
    local untilAt=os.clock()+8;repeat Run.Heartbeat:Wait()until os.clock()>=untilAt
   end,debug.traceback)
   d.input:clear()
   if not passed then table.insert(failures,route.id..": "..tostring(problem));emit("FAILURE",{route=route.id,problem=string.sub(tostring(problem),1,400)});emit("STATE",{route=route.id,when="failure",state=state()})end
  end
  local final=inspect("finish")
  assert(final.active==0 and final.gate.scopes==0 and final.gate.started==0 and final.gate.queued==0 and final.optionsCreated==final.optionsDestroyed,"seam save fixture leaked work")
 end,debug.traceback)
 d.input:clear();focus:Disconnect();if connection then connection:Disconnect()end
 emit("END",{completed=okay and #failures==0,problem=if okay then nil else string.sub(tostring(why),1,400),failures=#failures,walks=#results,focus_lost=lostFocus,detail=d.detail})
 Probe.finish(okay and #failures==0,string.sub(if not okay then tostring(why)else table.concat(failures,"\n"),1,400))
end
