--!strict
-- Observe construction/readiness and ten seconds of the ordinary title.
-- No transport, chosen life, skipped intro, clock override or player save.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Players=game:GetService("Players")
local Probe=require(script.Parent.MatrixProbe)
return function(d:any)
 local lost=0;local focus=game:GetService("UserInputService").WindowFocusReleased:Connect(function()lost+=1 end)
 local connection;local replies={};local serial=0;local diagnostic
 local function waitFor(fn:()->boolean,seconds:number)
  local deadline=os.clock()+seconds
  repeat if fn()then return end;Run.Heartbeat:Wait()until os.clock()>=deadline
  error("startup-clock readiness deadline")
 end
 local function facts():any
  return{title_ready=Players.LocalPlayer:GetAttribute("TitleReady")==true,navigation=d.navigation and d.navigation.status,
   save_ready=WS:GetAttribute("SaveStartupReady")==true,save_status=d.saveClient:status(),loading=d.world.playerLoading,
   region=d.world.region.id,menu=d.menu:isShowing(),title_holding=d.title:holding(),detail=d.detail}
 end
 local okay,why=xpcall(function()
  Probe.ready(facts())
  diagnostic=assert(RS:WaitForChild("NormalStartupDiagnostic",90))
  connection=diagnostic.Report.OnClientEvent:Connect(function(ticket:any,value:any)replies[ticket]=value end)
  waitFor(function():boolean
   return WS:GetAttribute("SaveStartupReady")==true and d.saveClient.newLifeEnabled and d.saveClient:recoveryReady()
    and not d.saveClient:offerPending()and Players.LocalPlayer:GetAttribute("TitleReady")==true
    and(not d.navigation or d.navigation.status=="ready")
  end,90)
  Probe.mark("title-ready");Probe.note("READY",facts())
  local began=os.clock();repeat Run.Heartbeat:Wait()until os.clock()-began>=10
  serial+=1;diagnostic.Command:FireServer("finish",serial)
  waitFor(function():boolean return replies[serial]~=nil end,30)
  local final=replies[serial]
  assert(final.active==0 and final.gate.scopes==0 and final.gate.started==0 and final.gate.queued==0 and final.optionsCreated==final.optionsDestroyed,"startup fixture leaked save work")
  Probe.note("CLEANUP",{active=final.active,scopes=final.gate.scopes,focus_lost=lost,life_started=d.session.started})
 end,debug.traceback)
 focus:Disconnect();if connection then connection:Disconnect()end
 Probe.finish(okay,why)
end
