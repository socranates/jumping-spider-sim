--!strict
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Map=require(RS:WaitForChild("Shared").World.WorldMap)
local Probe=require(script.Parent.StartupPerfProbe)
return function(d:any)
 local diagnostic:any;local serial=0;local replies:any={}
 local function waitFor(fn:any,seconds:number?)
  local deadline=os.clock()+(seconds or 120)
  repeat
   if fn()then return end
   assert(not d.saveState.broken,"save application failed")
   Run.Heartbeat:Wait()
  until os.clock()>=deadline
  error("ordinary frame readiness deadline")
 end
 local function inspect(action:string?):any
  serial+=1;local ticket=serial;diagnostic.Command:FireServer(action or "inspect",ticket)
  waitFor(function()return replies[ticket]~=nil end,30);local v=replies[ticket];replies[ticket]=nil;return v
 end
 local function extra():any
  return {simulation=d.life.elapsed,loading=d.world.playerLoading==true,ended=d.session.ended==true,
   navigation=d.navigation and d.navigation.status,save_phase=d.saveState.application.phase,save_status=d.saveClient:status()}
 end
 local function sample(name:string,seconds:number)
  Probe.startSample(name);local began=os.clock();local elapsed=d.life.elapsed
  repeat Run.Heartbeat:Wait()until os.clock()-began>=seconds
  local result=extra();result.simulation_seconds=d.life.elapsed-elapsed
  Probe.endSample(result)
  assert(not result.loading and not result.ended and result.simulation_seconds>=seconds-.1,"sample did not run ordinary live simulation")
 end
 local ok,why=xpcall(function()
  Probe.ready(extra())
  Probe.startSample("startup-to-menu")
  diagnostic=assert(RS:WaitForChild("NormalStartupDiagnostic",90))
  diagnostic.Report.OnClientEvent:Connect(function(ticket:any,value:any)replies[ticket]=value end)
  waitFor(function()return WS:GetAttribute("SaveStartupReady")==true and d.saveClient.newLifeEnabled and d.saveClient:recoveryReady()
   and not d.saveClient:offerPending() and game:GetService("Players").LocalPlayer:GetAttribute("TitleReady")==true
   and (not d.navigation or d.navigation.status=="ready")end)
  Probe.endSample(extra())
  d.title.seen=true;d.title:stop();d.openMenu(true)
  assert(d.menu:choose("New"),"ordinary New missing")
  waitFor(function()return d.session.started and not d.saveState.application:held() and d.saveClient:decision("main") and d.saveClient:decision("main").state=="writable"end)
  waitFor(function()return not d.world.playerLoading and d.motor.mode=="attached"end)
  sample("home",30)
  for _,id in {"garden_a1","pond_a1"}do
   local region=Map.region(id)
   assert(region,"frame destination missing: "..id)
   Probe.startSample(id.."-arrival")
   d.place(region.spawn.pos+Vector3.new(0,.31,0),Vector3.yAxis)
   waitFor(function()return d.world.region and d.world.region.id==id and not d.world.playerLoading and d.motor.mode=="attached"
    and d.world.looks and d.world.looks:complete(id)end)
   Probe.endSample(extra());sample(id,30)
  end
  local final=inspect("finish")
  assert(final.active==0 and final.gate.scopes==0 and final.gate.started==0 and final.gate.queued==0 and final.optionsCreated==final.optionsDestroyed,"frame fixture leaked save work")
 end,debug.traceback)
 Probe.finish(ok,why)
end
