-- Actual controller/menu/RemoteEvent integration, unpublished Studio only.
-- Clock x10 and a yielding memory store: not online throughput or FPS evidence.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Player=game:GetService("Players").LocalPlayer
local Shared=RS:WaitForChild("Shared")
local Json=require(Shared.Persistence.Json)
local Rest=require(Shared.Persistence.SaveRest)
local Portable=require(Shared.Persistence.RecoveryLifePrototype)
local Client=require(script.Parent.ReplacementClientPrototype)
local Entry=require(script.Parent.RecoveryGameEntryPrototype)
local function frames(n) for _=1,n do Run.Heartbeat:Wait() end end
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and WS:GetAttribute("NewApplicationNative")==true)
 local tag;local checks=0;local app;local client;local diagnostics
 local replies={};local serial=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function waitFor(done,seconds,allowHeldFailure)
  local deadline=os.clock()+(seconds or 150)
  repeat
   if done() then return end
   if WS:GetAttribute("NativeApplicationServerFailed") then error("native server diagnostic failed") end
   if not allowHeldFailure and app and app.phase=="failed" then error("native application held failure: "..tostring(app.problem)) end
   if client and client.transition and client.transition.stage=="failed" then error("native replacement failed: "..tostring(client.transition.problem)) end
   Run.Heartbeat:Wait()
  until os.clock()>=deadline
  error("native wait expired app="..tostring(app and app.phase).." entry="..tostring(app and app.entry.job and app.entry.job.problem).." status="..tostring(client and client:status()))
 end
 local function inspect(action)
  serial+=1;local ticket=serial
  diagnostics.Command:FireServer(action or "inspect",ticket)
  waitFor(function() return replies[ticket]~=nil end,45,true)
  local result=replies[ticket];replies[ticket]=nil;return result
 end
 local function has(id) for _,choice in d.menu.choices do if choice.id==id then return true end end;return false end
 local function offered(mode)
  waitFor(function() return not client:offerPending(mode) and client:offerInfo(mode)~=nil end)
 end
 local function stableArchive(a,b) return Json.canonical(a.archives)==Json.canonical(b.archives) end
 local function paused()
  local elapsed,energy,position=d.life.elapsed,d.needs.energy,d.motor.pos
  d.menu:hide();frames(20)
  check(app:held() and d.life.elapsed==elapsed and d.needs.energy==energy and d.motor.pos==position,"hidden native menu resumed held simulation")
  -- The replacement choice menu intentionally admits an explicit fresh choice.
  -- Probe reset refusal only while an operation owns the world; never turn the
  -- menu-pause test itself into that explicit fresh choice.
  if app:busy() then check(not d.fresh("main",false,nil),"native busy world admitted reset") end
  check(not d.saveState.beginLocalReturn("main","menu"),"native held world admitted local return")
  if app:choosing() then d.openMenu(true) else app:render() end
  frames(2);check(d.menu:isShowing(),"native progress/error menu did not return")
 end
 local function newMenu(mode)
  offered(mode);d.openMenu(true)
  local choice=if mode=="main" then "New" elseif mode=="easy" then "Easy" else "NewFree"
  if mode=="free" and not has(choice) then choice="Free" end
  check(d.menu:choose(choice),"actual native New choice missing: "..mode)
  if app.phase~="new" then check(d.menu:choose(choice),"native New confirmation missing") end
  check(app.phase=="new" and app:held(),"native protected New did not pause before reset")
 end
 local function freshNew(mode)
  offered(mode);d.openMenu(true)
  local choice=if mode=="main" then "New" elseif mode=="easy" then "Easy" else "Free"
  check(d.menu:choose(choice),"native explicit fresh choice missing")
  if app:choosing() then check(d.menu:choose(choice),"native fresh confirmation missing") end
  waitFor(function() local r=client:decision(mode);return r and r.state=="writable" end)
  check(app.phase=="playing" and not app:held() and client.activeSlot==mode and client:decision(mode).credential~=nil,"native fresh world lacked real save grant")
  d.title:stop()
  waitFor(function() return d.world.playerLoading~=true and d.motor.mode=="attached" end,60)
  local kept=d.life.save()
  waitFor(function() return not kept.pending end,90)
  check(kept.ok,"actual native life.save failed: "..tostring(kept.message))
  waitFor(function() local r=client.bound.requests[mode];return r and r.candidate and r.candidate.stored end)
  check(client:decision(mode).state=="writable","native normal checkpoint lost its grant")
 end
 local ok,why=xpcall(function()
  diagnostics=RS:WaitForChild("NewApplicationNative",90);assert(diagnostics,"native setup channel missing")
  for _,name in {"Ready","Command","Report"} do assert(diagnostics:WaitForChild(name,30),name) end
  tag=WS:GetAttribute("NativeApplicationRun")
  diagnostics.Report.OnClientEvent:Connect(function(ticket,value) if type(ticket)=="number" and type(value)=="table" and value.run==tag then replies[ticket]=value end end)
  local start=assert(WS:GetAttribute("NativeApplicationClockStart"))
  local installed,problem=d.saveState.installRecovery({
   client=function(cfg,options)
    cfg.now=function() return 200+(WS:GetServerTimeNow()-start)*10 end
    local validate=cfg.continuation.validate
    cfg.continuation.validate=function(mode,record,retired)
     if validate(mode,record,retired) then return true end
     return Portable.prepare(record,Rest.stubWorld(),"A1_46001")~=nil
    end
    return Client.new(cfg,options)
   end,
   entry=function(cfg) return Entry.new(cfg) end,
  })
  check(installed,"native application installed too late: "..tostring(problem))
  app=d.saveState.application;client=app.client
  print("[NEW_APP_NATIVE_CLIENT_BEGIN]",tag,"clock_scale=10 real_remotes=true codec=engine")
  diagnostics.Ready:FireServer()
  waitFor(function() return client.newLifeEnabled and client:recoveryReady() and Player:GetAttribute("TitleReady")==true and client:offerInfo("easy")~=nil and not client:offerPending() end,180)
  d.title.seen=true;d.title:stop();d.session.started=false;d.openMenu(true)
  check(not d.saveState.installRecovery({}),"native live transport rebound")
  local before=inspect();local epoch=client.bound.epoch
  -- No yielding between selection and exit: the Continue packet is abandoned
  -- before the controller's next frame can send it.
  check(d.menu:choose("Continue") and app.phase=="entry","native early Continue missing")
  check(d.menu:choose("RecoveryExit"),"native preaccept exit missing")
  waitFor(function() return app.phase=="menu" and client.transition==nil and client.bound.epoch~=epoch end)
  local after=inspect()
  check(Json.canonical(before.rests)==Json.canonical(after.rests) and not after.archiveComplete and after.owners[#after.owners-1].closed,"native early exit changed source or overlapped owners")
  paused()

  -- Real adoption waits for a real server grant even after the menu is hidden.
  offered("main");d.openMenu(true);check(d.menu:choose("Continue"),"native main Continue missing")
  waitFor(function() return app.entry.job and app.entry.job.phase=="applied" end)
  check(app.phase=="entry" and app:held(),"native adoption resumed before grant")
  paused();after=inspect("release_ack")
  check(after.archiveComplete and after.originalExact.main and after.originalExact.free and after.originalExact.easy,"native archive did not retain complete original rests")
  waitFor(function() return app.phase=="playing" end)
  check(app.recoveredPlaying and not app:held(),"native matching grant did not resume recovered world")
  local lifeTime=d.life.elapsed;frames(5);check(d.life.elapsed>lifeTime,"native granted simulation did not tick")
  before=inspect();epoch=client.bound.epoch
  d.openMenu(true);check(d.menu:choose("New") and app.phase=="replacing","native recovered menu reset before closure")
  waitFor(function() return app.phase=="menu" and client.transition==nil and client.bound.epoch~=epoch end)
  after=inspect();check(stableArchive(before,after) and after.owners[#after.owners-1].closed and not d.session.started,"native playing-world exit changed archive or silently selected")

  for _,mode in {"main","free"} do
   d.openMenu();offered(mode);before=inspect();epoch=client.bound.epoch
   newMenu(mode);paused()
   waitFor(function() return app.phase=="menu" and client.transition==nil and client.bound.epoch~=epoch end)
   after=inspect();check(after.originalExact[mode] and after.owners[#after.owners-1].closed and app:held() and not d.session.started,"native New failed archive/closure/fresh hold")
   local kept=after;freshNew(mode);after=inspect()
   check(stableArchive(kept,after) and after.originalExact[mode],"native normal stored checkpoint changed original archive")
   print("[NEW_APP_NATIVE_NEW_STORED]",tag,mode,"actual_menu real_grant life_save stored_ack immutable_original")
  end

  -- A partial real adoption failure must preserve its held screen and exit.
  d.openMenu();offered("easy");d.openMenu(true)
  local prepare=app.entry.cfg.prepareAdoption
  app.entry.cfg.prepareAdoption=function(record,stamp)
   local commit,errorText=prepare(record,stamp);if not commit then return nil,errorText end
   return function() local applied=commit();assert(applied);return false,"synthetic native error after actual adoption" end
  end
  check(d.menu:choose("ContinueEasy"),"native partial-adoption Easy choice missing")
  -- A normal active life first asks for explicit confirmation.
  if app.phase~="entry" then check(d.menu:choose("ContinueEasy"),"native Easy confirmation missing") end
  waitFor(function() return app.phase=="failed" end)
  check(app:held() and d.menu:isShowing() and has("RecoveryExit"),"native partial failure hid safe exit")
  paused();before=inspect();epoch=client.bound.epoch
  check(d.menu:choose("RecoveryExit"),"native partial failure exit missing")
  waitFor(function() return app.phase=="menu" and client.transition==nil and client.bound.epoch~=epoch end)
  after=inspect();check(stableArchive(before,after) and after.owners[#after.owners-1].closed,"native partial failure exit changed archive or overlapped owners")
  app.entry.cfg.prepareAdoption=prepare
  newMenu("easy");paused();epoch=client.bound.epoch
  waitFor(function() return app.phase=="menu" and client.transition==nil and client.bound.epoch~=epoch end)
  before=inspect();freshNew("easy");after=inspect()
  check(stableArchive(before,after) and after.originalExact.easy,"native Easy New changed original/proposal")
  print("[NEW_APP_NATIVE_NEW_STORED]",tag,"easy","actual_menu real_grant life_save stored_ack immutable_original")
  epoch=client.bound.epoch;local generation=d.saveState.worldGeneration;local credential=client:decision("easy").credential
  inspect("replay_old");frames(5)
  check(client.bound.epoch==epoch and d.saveState.worldGeneration==generation and client:decision("easy").credential==credential,"native obsolete decision changed new world/authority")
  inspect("finish");frames(3);after=inspect()
  check(after.lockReleased and after.errors==0 and after.optionsCreated>0 and after.optionsCreated==after.optionsDestroyed,"native cleanup failed or leaked GetOptions")
  print("[NEW_APP_NATIVE_CLIENT_PASS]",tag,checks,Json.canonical({server_checks=after.checks,options=after.optionsCreated,clock_scale=10,real_remote_events=true,memory_store=true,engine_codec=true,online=false}))
 end,debug.traceback)
 WS:SetAttribute("NativeApplicationFinished",true);WS:SetAttribute("NativeApplicationPassed",ok)
 if not ok then warn("[NEW_APP_NATIVE_CLIENT_FAIL]",tag,tostring(why)) end
end
