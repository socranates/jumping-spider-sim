-- Unpublished observer of actual startup and protected Continue callbacks.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local Map=require(RS:WaitForChild("Shared").World.WorldMap)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and game.GameId==0 and WS:GetAttribute("LegacyStartupDiagnostic")==true)
 local run=tostring(math.floor(WS:GetServerTimeNow()*1000));local checks=0;local stage="startup"
 local function emit(kind,value)print("[LEGACY_STARTUP_"..kind.."]",run,Http:JSONEncode(value))end
 local function check(ok,why)checks+=1;assert(ok,why)end
 local function waitFor(fn,seconds)
  local deadline=os.clock()+(seconds or 180)
  repeat
   if fn()then return end
   assert(not d.saveState.broken,"save startup broke")
   local app=d.saveState.application;assert(not app or app.phase~="failed","application failed: "..tostring(app and app.problem))
   Run.Heartbeat:Wait()
  until os.clock()>=deadline
  error("legacy startup deadline at "..stage)
 end
 local diagnostic;local serial=0;local replies={}
 local function inspect(action)
  serial+=1;local ticket=serial;diagnostic.Command:FireServer(action or "inspect",ticket)
  waitFor(function()return replies[ticket]~=nil end,30);local result=replies[ticket];replies[ticket]=nil;return result
 end
 local function offered(mode)
  waitFor(function()return d.saveClient:offerInfo(mode)~=nil or d.saveClient.bound.offerErrors[mode]~=nil end)
  local info=d.saveClient:offerInfo(mode)
  check(info and info.protected and info.playable,"protected legacy "..mode.." offer missing from actual startup")
  return info
 end
 local ok,why=xpcall(function()
  check(d.saveState.application~=nil and d.saveState.application.client==d.saveClient,"startup did not bind the recovery application")
  diagnostic=RS:WaitForChild("NormalStartupDiagnostic",90);assert(diagnostic)
  diagnostic.Report.OnClientEvent:Connect(function(ticket,value)replies[ticket]=value end)
  waitFor(function()return WS:GetAttribute("SaveStartupReady")==true and d.saveClient:recoveryReady()
   and not d.saveClient:offerPending() and game:GetService("Players").LocalPlayer:GetAttribute("TitleReady")==true end)
  local initial=inspect();check(initial.ready and initial.archives==0,"legacy startup wrote an archive before selection")
  for _,mode in {"main","free","easy"}do check(initial.originalUnchanged[mode],"legacy startup changed original "..mode)end
  for index,mode in {"main","free","easy"}do
   stage=mode.."-offer";offered(mode);waitFor(function()return not d.saveClient:offerPending(mode)end)
   waitFor(function()return not d.navigation or d.navigation.status=="ready"end)
   d.title.seen=true;d.title:stop();d.openMenu(true)
   local generation=d.saveState.worldGeneration
   local choice=if mode=="main" then "Continue" elseif mode=="easy" then "ContinueEasy" else "Free"
   check(d.menu:choose(choice),"legacy Continue menu choice missing: "..mode)
   check(d.saveState.application:held(),"protected legacy selection did not pause before adoption")
   local request=d.saveClient:decision(mode)
   check(request and request.state=="readonly" and request.credential==nil,"legacy selection granted before verified entry")
   stage=mode.."-entry"
   waitFor(function()local r=d.saveClient:decision(mode);return r and r.state=="writable" and d.session.started and not d.saveState.application:held()end)
   waitFor(function()return not d.world.playerLoading and d.motor.mode=="attached"end)
   local region=Map.at(d.motor.pos)
   check(d.saveState.worldGeneration>generation and region~=nil and region.id==Map.HOME,"legacy source pose/ecology escaped into Preserve")
   check(d.life.growth.stage==1 and d.life.clock.day==3 and d.life.elapsed>=120,"legacy growth/clock/life progress was lost")
   check(math.abs(d.needs.grantedTotal-.25)<1e-8 and math.abs(d.life.grantedSeen-.25)<1e-8,"legacy nutrition or growth cursor was lost")
   local key="@archive/A1_qa_normal_startup/legacy_meal_"..mode
   check(d.needs.grantedBySource[key]==.25 and d.prey.feeding.ledger[key]==.25 and d.prey.feeding.mealsFinished==1,"legacy meal books were not namespaced/preserved")
   local state=inspect();check(state.archiveComplete and state.originalExact[mode],"immutable original archive differs or is incomplete: "..mode)
   stage=mode.."-save";local kept=d.life.save();waitFor(function()return not kept.pending end)
   check(kept.ok,"legacy current-world checkpoint preparation failed: "..tostring(kept.message))
   waitFor(function()local r=d.saveClient.bound.requests[mode];return r and r.candidate and r.candidate.stored end)
   state=inspect();check(state.originalExact[mode] and state.requests==state.starts,"legacy re-save changed original or lost request accounting")
   emit("MODE",{mode=mode,checks=checks,stage=d.life.growth.stage,food=d.needs.grantedTotal,starts=state.starts,archives=state.archives})
   if index<3 then
    stage=mode.."-replace";local epoch=d.saveClient.bound.epoch
    check(d.saveClient:requestReplacement(),"recovered life could not leave for another slot")
    waitFor(function()return d.saveClient.transition==nil and d.saveClient.bound.epoch~=epoch end)
    check(d.saveState.application:held() and not d.session.started,"legacy replacement silently resumed a spider")
   end
  end
  stage="finish";local final=inspect("finish")
  for _,mode in {"main","free","easy"}do check(final.originalExact[mode],"final archive changed: "..mode)end
  check(final.active==0 and final.gate.scopes==0 and final.gate.queued==0 and final.gate.started==0 and final.lockReleased,"legacy startup retained work/lock")
  check(final.optionsCreated==final.optionsDestroyed and final.requests==final.starts,"legacy startup leaked options/accounting")
  emit("PASS",{checks=checks,snapshot=final,real_storage=false,ordinary_ui=true})
 end,debug.traceback)
 local choices={};for _,choice in d.menu.choices do table.insert(choices,choice.id)end
 if not ok then emit("FAIL",{checks=checks,stage=stage,problem=tostring(why),client_phase=d.saveClient.phase,menu_choices=choices,
  offers_pending=d.saveClient:offerPending(),title_ready=game:GetService("Players").LocalPlayer:GetAttribute("TitleReady"),
  application_phase=d.saveState.application and d.saveState.application.phase,application_problem=d.saveState.application and d.saveState.application.problem})end
 WS:SetAttribute("LegacyStartupFinished",true);WS:SetAttribute("LegacyStartupPassed",ok)
end
