-- Native startup observer. It does not install/rebind a client or construct a service.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and game.GameId==0 and WS:GetAttribute("NormalStartupDiagnostic")==true)
 local run=tostring(math.floor(WS:GetServerTimeNow()*1000));local checks=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function emit(kind,value) print("[NORMAL_STARTUP_"..kind.."]",run,Http:JSONEncode(value)) end
 local function waitFor(fn,seconds)
  local deadline=os.clock()+(seconds or 120)
  repeat
   if fn() then return end
   assert(not d.saveState.broken,"save startup broke")
   Run.Heartbeat:Wait()
  until os.clock()>=deadline
  error("normal startup deadline")
 end
 local serial=0;local replies={};local diagnostic
 local function inspect(action)
  serial+=1;local ticket=serial
  diagnostic.Command:FireServer(action or "inspect",ticket)
  waitFor(function() return replies[ticket]~=nil end,30)
  local result=replies[ticket];replies[ticket]=nil;return result
 end
 local function save()
  waitFor(function() return not d.world.playerLoading and d.motor.mode=="attached" end)
  local kept=d.life.save();waitFor(function() return not kept.pending end)
  check(kept.ok,"actual life checkpoint preparation failed: "..tostring(kept.message))
  waitFor(function() local r=d.saveClient.bound.requests.main;return r and r.candidate and r.candidate.stored end)
 end
 local ok,why=xpcall(function()
  check(d.saveState.application~=nil and d.saveState.application.client==d.saveClient,"normal client did not bind before observer")
  check(not d.saveState.installRecovery({}),"startup client allowed a second installation")
  diagnostic=RS:WaitForChild("NormalStartupDiagnostic",90);assert(diagnostic)
  diagnostic.Report.OnClientEvent:Connect(function(ticket,value) replies[ticket]=value end)
  waitFor(function() return WS:GetAttribute("SaveStartupReady")==true and not d.saveClient:waiting() end)
  check(d.saveClient.newLifeEnabled and d.saveClient:recoveryReady(),"normal server did not negotiate complete features")
  local before=inspect();check(before.ready and before.active==0,"normal service was not installed/drained")
  waitFor(function() return not d.navigation or d.navigation.status=="ready" end)
  d.title.seen=true;d.title:stop();d.openMenu(true)
  check(d.menu:choose("New"),"normal Main menu choice missing")
  if not d.session.started then check(d.menu:choose("New"),"normal Main confirmation missing") end
  d.title:stop()
  if WS:GetAttribute("DiagnosticUnavailable")==true then
   waitFor(function() return d.saveClient:status()=="session" end)
   check(before.sessionState=="session" and before.sessionReason=="no_api","unavailable startup did not report no_api")
   check(d.session.started and not d.saveState.application:held(),"unavailable saving prevented local play")
   local time=d.life.elapsed;for _=1,8 do Run.Heartbeat:Wait() end
   check(d.life.elapsed>time,"unavailable saving froze simulation")
   local final=inspect("finish")
   check(next(final.rests)==nil and not final.lockReleased and final.archives==0,"unavailable adapter invented stored data")
   check(final.active==0 and final.gate.scopes==0 and final.optionsCreated==final.optionsDestroyed,"unavailable startup retained work")
   emit("PASS",{checks=checks,mode="no_api",snapshot=final,real_storage=false});return
  end
  waitFor(function() local r=d.saveClient:decision("main");return r and r.state=="writable" end)
  check(d.session.started and not d.saveState.application:held(),"fresh normal Main did not run")
  save();local originalPosition=d.motor.pos;before=inspect()
  check(before.epoch==d.saveClient.bound.epoch and before.requests==before.starts,"startup provider accounting or epoch differs")
  check(before.archives==0 and next(before.rests)~=nil,"fresh checkpoint changed recovery archives or was not stored")
  local epoch=d.saveClient.bound.epoch
  check(d.saveClient:requestReplacement(),"normal ordinary owner refused replacement")
  waitFor(function() return d.saveClient.transition==nil and d.saveClient.bound.epoch~=epoch end)
  local after=inspect()
  check(after.owners[1].closed and after.epoch~=before.epoch and after.gate.scopes==1,"startup replacement overlapped owners")
  check(d.saveState.application:held() and not d.session.started,"replacement silently resumed a spider")
  local generation=d.saveState.worldGeneration
  d.place(originalPosition+Vector3.new(2,0,0))
  waitFor(function() return not d.saveClient:offerPending("main") end)
  d.openMenu(true);check(d.menu:choose("Continue"),"stored ordinary Continue missing")
  waitFor(function() return d.session.started and not d.saveState.restore.job and not d.world.playerLoading end)
  check((d.motor.pos-originalPosition).Magnitude<.001 and d.saveState.worldGeneration>generation,"normal Continue did not restore the actual stored pose")
  save();after=inspect()
  check(after.archives==0 and after.requests==after.starts,"ordinary re-save changed archive or lost accounting")
  local final=inspect("finish")
  check(final.active==0 and final.gate.scopes==0 and final.lockReleased,"normal startup owner did not close/release")
  check(final.optionsCreated==final.optionsDestroyed and final.requests==final.starts,"normal startup leaked read options or request accounting")
  emit("PASS",{checks=checks,mode="fresh-replace-continue-save",snapshot=final,real_storage=false})
 end,debug.traceback)
 if not ok then emit("FAIL",{checks=checks,problem=tostring(why)}) end
 WS:SetAttribute("NormalStartupFinished",true);WS:SetAttribute("NormalStartupPassed",ok)
end
