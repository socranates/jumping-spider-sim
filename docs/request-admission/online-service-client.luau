-- Actual controller/menu/RemoteEvent integration, unpublished Studio only.
-- Real clock and a yielding real isolated test store: not online throughput or FPS evidence.
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
 assert(Run:IsStudio() and game.GameId==10771634917 and game.PlaceId==109879630247781 and WS:GetAttribute("NewApplicationNative")==true)
 local tag;local checks=0;local app;local client;local diagnostics
 local appliedRestDigest;local replies={};local serial=0
 -- Diagnostic observer: no gameplay/schema/authority changes. Snapshots and
 -- post-run canonical encodes have separately reported overhead.
 local cost={samples={},counts={},trace={},updates={},gaps={},phases={},marks={},copySeconds=0}
 local function stage()
  return (app and app.phase or "boot")..":"..(app and app.entry.job and app.entry.job.phase or "none")..":"..tostring(client and client.activeSlot)
 end
 local function mark(name)
  table.insert(cost.marks,{name=name,t=WS:GetServerTimeNow()})
 end
 local function wire(direction,message)
  local kind=tostring(message.kind)
  local mode=message.mode or message.decision and message.decision.mode or "none"
  local key=direction..":"..kind..":"..tostring(mode)
  cost.counts[key]=(cost.counts[key] or 0)+1
  if not cost.samples[key] then
   local at=os.clock();local owned=Json.copy(message);local elapsed=os.clock()-at
   cost.copySeconds+=elapsed;cost.samples[key]={message=owned,copy_seconds=elapsed}
  end
  if #cost.trace>=4096 then error("diagnostic packet trace bound exceeded") end
  table.insert(cost.trace,{direction=direction,kind=kind,epoch=message.epoch,sequence=message.sequence,mode=mode,t=WS:GetServerTimeNow()})
 end
 local function observedRemotes(find)
  return function()
   local raw=find();if not raw then return nil end
   return {server={FireServer=function(_,message)
    wire("out",message);raw.server:FireServer(message)
   end},client={OnClientEvent={Connect=function(_,callback)
    return raw.client.OnClientEvent:Connect(function(message)
     -- Timestamp before copying: send-to-callback excludes this snapshot cost.
     local arrived=WS:GetServerTimeNow();wire("in",message);cost.trace[#cost.trace].t=arrived
     callback(message)
    end)
   end}}}
  end
 end
 local observerConnection
 local function watch(object,name)
  local original=object.update
  object.update=function(self,...)
   local key=name..":"..stage();local row=cost.updates[key]
   if not row then row={calls=0,seconds=0,max_seconds=0};cost.updates[key]=row end
   local at=os.clock();original(self,...);local elapsed=os.clock()-at
   row.calls+=1;row.seconds+=elapsed;row.max_seconds=math.max(row.max_seconds,elapsed)
  end
 end
 local function observeApplication()
  watch(app,"application");watch(app.entry,"entry");watch(client,"save_client")
  local previous
  observerConnection=Run.Heartbeat:Connect(function(dt)
   local key=stage();local row=cost.gaps[key]
   if not row then row={frames=0,seconds=0,max_seconds=0,over_50ms=0};cost.gaps[key]=row end
   row.frames+=1;row.seconds+=dt;row.max_seconds=math.max(row.max_seconds,dt)
   if dt>.05 then row.over_50ms+=1 end
   if previous~=key then table.insert(cost.phases,{name=key,t=WS:GetServerTimeNow()});previous=key end
  end)
 end
 local function reportCost()
  if observerConnection then observerConnection:Disconnect() end
  for key,row in cost.samples do
   local at=os.clock();local text=assert(Json.canonical(row.message));local elapsed=os.clock()-at
   print("[NATIVE_COST_CLIENT_PAYLOAD]",tag,Json.canonical({key=key,canonical_bytes=#text,copy_seconds=row.copy_seconds,encode_seconds=elapsed,count=cost.counts[key]}))
  end
  for key,row in cost.updates do row.key=key;print("[NATIVE_COST_CLIENT_UPDATE]",tag,Json.canonical(row)) end
  for key,row in cost.gaps do row.key=key;print("[NATIVE_COST_CLIENT_GAP]",tag,Json.canonical(row)) end
  for _,row in cost.trace do print("[NATIVE_COST_CLIENT_TRACE]",tag,Json.canonical(row)) end
  for _,row in cost.phases do print("[NATIVE_COST_CLIENT_PHASE]",tag,Json.canonical(row)) end
  for _,row in cost.marks do print("[NATIVE_COST_CLIENT_MARK]",tag,Json.canonical(row)) end
  print("[NATIVE_COST_CLIENT_END]",tag,Json.canonical({copy_seconds=cost.copySeconds,packets=#cost.trace,clock_scale=1,online=true}))
 end

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
  mark(mode.."_checkpoint_begin");local kept=d.life.save()
  waitFor(function() return not kept.pending end,90)
  mark(mode.."_checkpoint_prepared")
  check(kept.ok,"actual native life.save failed: "..tostring(kept.message))
  waitFor(function() local r=client.bound.requests[mode];return r and r.candidate and r.candidate.stored end)
  mark(mode.."_checkpoint_stored")
  check(client:decision(mode).state=="writable","native normal checkpoint lost its grant")
 end
 local ok,why=xpcall(function()
  diagnostics=RS:WaitForChild("NewApplicationNative",90);assert(diagnostics,"native setup channel missing")
  for _,name in {"Ready","Command","Report"} do assert(diagnostics:WaitForChild(name,30),name) end
  tag=WS:GetAttribute("NativeApplicationRun")
  diagnostics.Report.OnClientEvent:Connect(function(ticket,value) if type(ticket)=="number" and type(value)=="table" and value.run==tag then replies[ticket]=value end end)
  local installed,problem=d.saveState.installRecovery({
   client=function(cfg,options)
    cfg.now=function() return WS:GetServerTimeNow() end
    local restore=cfg.continuation.onRestore
    cfg.continuation=table.clone(cfg.continuation)
    cfg.continuation.onRestore=function(mode,record,serial)
     appliedRestDigest=Json.checksum((assert(Json.canonical(record))))
     return restore(mode,record,serial)
    end
    local validate=cfg.continuation.validate
    cfg.continuation.validate=function(mode,record,retired)
     if validate(mode,record,retired) then return true end
     return Portable.prepare(record,Rest.stubWorld(),"A1_qa_3cb3b30963a84dc6")~=nil
    end
    cfg.findRemotes=observedRemotes(cfg.findRemotes)
    return Client.new(cfg,options)
   end,
   entry=function(cfg) return Entry.new(cfg) end,
  })
  check(installed,"native application installed too late: "..tostring(problem))
  app=d.saveState.application;client=app.client;observeApplication()
  print("[NEW_APP_NATIVE_CLIENT_BEGIN]",tag,"clock_scale=1 real_remotes=true codec=engine")
  diagnostics.Ready:FireServer()
  waitFor(function() return client.newLifeEnabled and client:recoveryReady() and Player:GetAttribute("TitleReady")==true and client:offerInfo("easy")~=nil and not client:offerPending() end,180)
  d.title.seen=true;d.title:stop();d.session.started=false;d.openMenu(true)
  check(not d.saveState.installRecovery({}),"native live transport rebound")
if WS:GetAttribute("OnlineServiceRejoin")==true then
 local source=inspect()
 check(source.rejoining and source.priorPayloadDigests~=nil,"rejoin source proof unavailable")
 for _,mode in {"main","free","easy"} do
  local offered=client.bound:offer(mode)
  check(offered~=nil and not offered.protected and not offered.record.save_retired,"rejoin did not offer stored ordinary life")
  check(Json.checksum((assert(Json.canonical(offered.record))))==source.priorPayloadDigests[mode],"rejoin network offer changed stored checkpoint")
 end
 local priorGeneration=d.saveState.worldGeneration
 d.openMenu(true);check(d.menu:choose("Continue"),"actual rejoin Continue missing")
 waitFor(function()
  local decision=client:decision("main")
  return decision and decision.state=="writable" and d.session.started and d.saveState.restore.job==nil and not d.world.playerLoading
 end,180)
 check(not d.saveState.broken and d.saveState.worldGeneration>priorGeneration,"actual rejoin world restore did not commit")
 check(appliedRestDigest==source.priorPayloadDigests.main,"actual restore callback did not receive the stored life")
 check(client:decision("main").life==client.bound.requests.main.selected.save_life,"rejoin grant changed life lineage")
 d.title:stop()
 local kept=d.life.save();waitFor(function() return not kept.pending end,120)
 check(kept.ok,"rejoined life could not prepare checkpoint")
 waitFor(function() local request=client.bound.requests.main;return request and request.candidate and request.candidate.stored end,180)
 check(client:decision("main").state=="writable","rejoined stored checkpoint lost its credential")
 inspect("arm_leave");reportCost()
 print("[NEW_APP_NATIVE_CLIENT_PASS]",tag,checks,Json.canonical({server_checks=source.checks,clock_scale=1,real_remote_events=true,memory_store=false,engine_codec=true,online=true,rejoin=true}))
 return
end

  local before=inspect();local epoch=client.bound.epoch;local after
  if not WS:GetAttribute("OnlineServiceResumePartial") then
  -- No yielding between selection and exit: the Continue packet is abandoned
  -- before the controller's next frame can send it.
  check(d.menu:choose("Continue") and app.phase=="entry","native early Continue missing")
  check(d.menu:choose("RecoveryExit"),"native preaccept exit missing")
  waitFor(function() return app.phase=="menu" and client.transition==nil and client.bound.epoch~=epoch end)
  after=inspect()
  check(Json.canonical(before.rests)==Json.canonical(after.rests) and not after.archiveComplete and after.owners[#after.owners-1].closed,"native early exit changed source or overlapped owners")
  paused()

  -- Real adoption waits for a real server grant even after the menu is hidden.
  offered("main");d.openMenu(true);mark("main_continue_choice");check(d.menu:choose("Continue"),"native main Continue missing")
  waitFor(function() return app.entry.job and app.entry.job.phase=="applied" end)
  mark("main_adoption_applied")
  check(app.phase=="entry" and app:held(),"native adoption resumed before grant")
  paused();mark("main_release_ack");after=inspect("release_ack")
  check(after.archiveComplete and after.originalExact.main and after.originalExact.free and after.originalExact.easy,"native archive did not retain complete original rests")
  waitFor(function() return app.phase=="playing" end)
  mark("main_recovered_playing")
  check(app.recoveredPlaying and not app:held(),"native matching grant did not resume recovered world")
  local lifeTime=d.life.elapsed;frames(5);check(d.life.elapsed>lifeTime,"native granted simulation did not tick")
  before=inspect();epoch=client.bound.epoch
  d.openMenu(true);check(d.menu:choose("New") and app.phase=="replacing","native recovered menu reset before closure")
  waitFor(function() return app.phase=="menu" and client.transition==nil and client.bound.epoch~=epoch end)
  after=inspect();check(stableArchive(before,after) and after.owners[#after.owners-1].closed and not d.session.started,"native playing-world exit changed archive or silently selected")

  end -- initial recovery was already observed in the retained failed run
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
  epoch=client.bound.epoch;newMenu("easy");paused()
  waitFor(function() return app.phase=="menu" and client.transition==nil and client.bound.epoch~=epoch end)
  before=inspect();freshNew("easy");after=inspect()
  check(stableArchive(before,after) and after.originalExact.easy,"native Easy New changed original/proposal")
  print("[NEW_APP_NATIVE_NEW_STORED]",tag,"easy","actual_menu real_grant life_save stored_ack immutable_original")
  epoch=client.bound.epoch;local generation=d.saveState.worldGeneration;local credential=client:decision("easy").credential
  inspect("replay_old");frames(5)
  check(client.bound.epoch==epoch and d.saveState.worldGeneration==generation and client:decision("easy").credential==credential,"native obsolete decision changed new world/authority")
  inspect("arm_leave");frames(3);after=inspect()
  check(not after.lockReleased and after.errors==0 and after.optionsCreated>0,"native cleanup failed or leaked GetOptions")
  reportCost()
  print("[NEW_APP_NATIVE_CLIENT_PASS]",tag,checks,Json.canonical({server_checks=after.checks,options=after.optionsCreated,clock_scale=1,real_remote_events=true,memory_store=false,engine_codec=true,online=true}))
 end,debug.traceback)
 WS:SetAttribute("NativeApplicationClientFinished",true);WS:SetAttribute("NativeApplicationPassed",ok)
 if not ok then
  warn("[NEW_APP_NATIVE_CLIENT_FAIL]",tag,tostring(why))
  local seen,observation=pcall(inspect)
  if seen then print("[ONLINE_SERVICE_FAILURE_DETAIL]",tag,Json.canonical({detail=observation.detail,gate=observation.accountGate,providerActive=observation.providerActive})) end
 end
end
