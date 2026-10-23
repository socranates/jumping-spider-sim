do
local function runApplicationGameChecks()
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Backend=require("../src/Server/DataStoreBackend")
local Templates=require("../src/Server/RecoveryTemplates")
local Build=require("../src/Shared/World/WorldBuild")
local Rules=require("../src/Shared/Data/SaveRules")
local Client=require("../src/Client/SaveClient")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local b=Memory.new();local clock={now=200};local packets={};local owners={};local errors={};local holdAck=true
local oldBytes={}
for _,mode in Rules.MODES do
 WorldMap.use("test_garden");local old=gardenWorld();old.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
 old.life.mode=if mode=="free" then "free" else "main";old.life.rules=if mode=="main" then "standard" else "gentle";old.needs.gentle=mode~="main"
 local record=assert(Checkpoint.capture(old,120));record.save_life="application-old-"..mode
 local envelope=codec:encode(Envelope.make(SaveRest.SPECS[mode],record,100,nil))
 b:poke("R_46001_"..mode,envelope);oldBytes[mode]=Json.canonical(envelope)
end
local progress=Json.copy(rawProgress.payload);progress.finished_main=true
b:poke("P_46001",Envelope.make(Progress.SPEC,progress,100,nil))
-- A separate actual game is installed before its first transport update. Any
-- preceding test's diagnostic scene is discarded, never a real player's data.
for _,child in workspace:GetChildren() do if child~=workspace.CurrentCamera then child:Destroy() end end
local player=game:GetService("Players").LocalPlayer
for _,child in player:FindFirstChild("PlayerGui"):GetChildren() do child:Destroy() end
WorldMap.use("preserve");workspace:SetAttribute("World","preserve");workspace:SetAttribute("SaveWait",true)
Build.world(workspace)
local catalog
local ds={}
function ds:GetAsync(key,opts) check(opts==nil or opts.UseCache==false,"application used cached storage reads");local ok,v,why=b:read(key);if not ok then error(why) end;return v end
function ds:UpdateAsync(key,fn) local ok,v,why=b:update(key,fn);if not ok then error(why) end;return v end
local server=__replacementService.new({backend=Backend.new(ds,codec),now=function() return clock.now end,sleep=function(dt) clock.now+=dt end,
 spawn=function(fn,...) fn(...) end,jobId="application-wire",keyOf=function() return 46001 end,
 log=function(why) if string.find(why,"raised:",1,true) or string.find(why,"send failed:",1,true) then table.insert(errors,why) end end,
 send=function(_,msg) table.insert(packets,Json.copy(msg)) end,
 ownerFactory=function(config,emit)
  if #owners>0 then check(owners[#owners]:replacementClosed(),"actual menu constructed overlapping owners") end
  local profiles=assert(catalog:profiles())
  local deps={codec=codec,rawBackend=__rawBackendPrototype.new(ds),currentFormat=__restFormatPrototype,entryFactory=__entryPrototype,saveFactory=__saveLoopPrototype,
   reader={work={now=function() return 0 end}},pipeline={reuseCompleteOriginal=true,work={now=function() return 0 end}},
   entryOptions={work={now=function() return 0 end}},saveOptions={work={now=function() return 0 end},progress={work={now=function() return 0 end}}}}
  local owner=__replacementOwner.new(config,emit,deps,profiles);table.insert(owners,owner);return owner
 end})
local remoteFolder=Instance.new("Folder");remoteFolder.Name=Rules.REMOTES_NAME
local toServer=Instance.new("Folder");toServer.Name="ToServer";toServer.Parent=remoteFolder
local listener
rawset(toServer,"FireServer",function(_,msg)
 if msg.kind=="recovery_applied" and holdAck then return end
 server:onMessage(player,Json.copy(msg))
end)
local toClient=Instance.new("Folder");toClient.Name="ToClient";toClient.Parent=remoteFolder
rawset(toClient,"OnClientEvent",{Connect=function(_,fn) listener=fn;return {Disconnect=function() end} end})
remoteFolder.Parent=game:GetService("ReplicatedStorage")
local loaded=require("../src/Client/SpiderClient.client")
local d=assert(ClientStubs.driver)
-- CLI shares WorldMap between the two simulated roles. Author the server's
-- catalog after client construction's map selection, unlike separate VMs.
local authoredRoot=Instance.new("Folder");authoredRoot.Name="AuthoritativeRecoveryGeometry";authoredRoot.Parent=workspace
Build.region(assert(WorldMap.region(WorldMap.HOME)),authoredRoot)
catalog=assert(Templates.new(authoredRoot))
local ok,why=d.saveState.installRecovery({client=function(cfg,options)
 cfg.now=function() return clock.now end
 local validate=cfg.continuation.validate
 cfg.continuation.validate=function(mode,record,retired)
  if validate(mode,record,retired) then return true end
  local profile=assert(catalog:profiles())[mode]
  return __lifePrototype.prepare(record,profile.context,"A1_46001")~=nil
 end
 return __replacementClient.new(cfg,options)
end,entry=function(cfg)
 cfg.workOptions={now=function() return 0 end}
 return __gameEntryPrototype.new(cfg)
end})
check(ok,"actual application installation failed: "..tostring(why))
local app=d.saveState.application;local client=app.client
local frame=ClientStubs.renderSteps.SpiderSim
check(server:addPlayer(player)~=false,"initial application server owner construction failed")
local function pump(dt)
 server:step()
 while #packets>0 do assert(listener,"real client did not connect");listener(table.remove(packets,1)) end
 frame(dt or 1/60);clock.now+=1
end
-- Connect the real client before delivering the server's pending load reply.
frame(1/60)
local function drive(done)
 for _=1,3000 do
  if done() then return end
  if client.transition and client.transition.stage=="failed" then break end
  pump()
 end
 error("application did not settle: "..app.phase.."/"..tostring(app.problem).." owner="..tostring(owners[#owners] and owners[#owners].runtime.phase).." entry="..tostring(app.entry.job and app.entry.job.problem).." status="..tostring(client:status()))
end
drive(function() return client:recoveryReady() and not client:offerPending() and d.session.started and client:offerInfo("easy")~=nil end)
-- SilkPlayback marks a diagnostic place: its normal startup skips the title.
-- Open the actual title menu once; all later fresh menus are production callbacks.
d.session.started=false;d.openMenu(true)
check(d.menu:isShowing(),"actual initial title menu was unavailable")
check(not d.saveState.installRecovery({}),"live client was rebound")
local function has(id) for _,choice in d.menu.choices do if choice.id==id then return true end end;return false end
local function frozen()
 local elapsed,energy,generation=d.life.elapsed,d.needs.energy,d.saveState.worldGeneration
 d.menu:hide();for _=1,20 do frame(1/60) end
 check(app:held() and d.life.elapsed==elapsed and d.needs.energy==energy,"hidden real screen advanced held world")
 d.returnToCheckpoint();check(d.saveState.worldGeneration==generation,"reset bypassed application hold")
 check(not d.fresh("main",false,nil),"busy recovery started an unrelated life")
 check(not d.saveState.beginLocalReturn("main","menu"),"busy recovery returned an old local rest")
end
local function replace()
 local prior=owners[#owners];local epoch=client.bound.epoch
 check(d.menu:choose("RecoveryExit"),"actual error/progress screen lacked exit action")
 drive(function() return app.phase=="menu" and client.transition==nil end)
 check(prior:replacementClosed() and client.bound.epoch~=epoch and not d.session.started and app:held(),"fresh real menu was not fenced by exact departure/new epoch")
 check(not has("Resume") and not has("Controls") and d.menu:isShowing(),"fresh menu offered old-world resume")
 local elapsed=d.life.elapsed;d.menu:hide();for _=1,10 do frame(1/60) end
 check(app:held() and d.life.elapsed==elapsed,"hiding fresh menu resumed retired session")
 d.openMenu(true)
 return prior
end
-- Exit immediately after selection, before a recovery request can be sent.
-- This must close the observed owner as safely as a later accepted migration.
local untouched={};for _,mode in Rules.MODES do untouched[mode]=Json.canonical(b.data["R_46001_"..mode]) end
check(d.menu:choose("Continue") and app.phase=="entry" and not owners[#owners].runtime.accepted,"early exit fixture already accepted migration")
replace()
for _,mode in Rules.MODES do check(Json.canonical(b.data["R_46001_"..mode])==untouched[mode] and b.data["A1_46001_"..mode]==nil,"preaccept exit changed original rest/archive") end
for _,mode in {"main","free","easy"} do
 drive(function() return not client:offerPending(mode) and client:offerInfo(mode)~=nil end)
 local choice=if mode=="main" then "Continue" elseif mode=="free" then "Free" else "ContinueEasy"
 local prepare=app.entry.cfg.prepareAdoption
 if mode=="easy" then
  app.entry.cfg.prepareAdoption=function(record,stamp)
   local commit,why=prepare(record,stamp);if not commit then return nil,why end
   return function() local ok=commit();assert(ok);return false,"synthetic failure after actual adoption" end
  end
 end
 check(d.menu:choose(choice),"actual menu did not offer selected protected slot: "..mode)
 if mode=="easy" then
  drive(function() return app.phase=="failed" end)
  check(app:held() and d.menu:isShowing() and has("RecoveryExit"),"partial adoption failure lost visible safe exit")
 else
  drive(function() return app.entry.job and app.entry.job.phase=="applied" end)
  check(app.phase=="entry" and app:held() and d.menu:isShowing() and has("RecoveryExit"),"actual adopted world lacked held progress/exit screen")
 end
 check(client.activeSlot==mode and d.session.mode==(if mode=="free" then "free" else "main"),"real application adopted another slot")
 frozen()
 if mode=="main" then
  holdAck=false;drive(function() return app.phase=="playing" end)
  check(not app:held() and not d.menu:isShowing(),"real matching grant did not resume actual screen")
  local elapsed=d.life.elapsed;for _=1,3 do frame(1/60) end;check(d.life.elapsed>elapsed,"granted real world did not tick")
  -- Exercise the same explicit application exit from a safely held screen.
  app:fail("diagnostic exit from granted life");holdAck=true
 end
 local archive=Json.canonical(b.data["A1_46001_"..mode])
 check(archive~=nil,"selected original was not archived")
 replace()
 check(Json.canonical(b.data["A1_46001_"..mode])==archive,"actual exit changed immutable original")
 print("RECOVERY_APPLICATION_GAME mode="..mode.." actual_menu=true actual_callbacks=true held_until_grant_or_exit=true closed_owner_before_fresh_menu=true")
 app.entry.cfg.prepareAdoption=prepare
end
-- The fresh choice screen does not release on visibility alone. A confirmed
-- new life in its new epoch deliberately changes the world and releases once.
check(app:choosing() and app:held(),"final fresh menu was not held")
local generation=d.saveState.worldGeneration
check(d.menu:choose("New"),"fresh menu lacked New")
if app:choosing() then check(d.menu:choose("New"),"explicit New confirmation missing") end
check(app.phase=="playing" and not app:held() and d.session.started and d.saveState.worldGeneration>generation and client.activeSlot=="main","explicit new-epoch choice could not resume")
drive(function() local r=client:decision("main");return r and r.reason=="protected_new_life_requires_policy" end)
check(client:status()=="session" and client:decision("main").credential==nil,"unimplemented protected New policy claimed saving authority")
check(#errors==0,"application service caught hidden failure: "..tostring(errors[1]))
server:removePlayer(player)
local final=owners[#owners]
check(final.session.closed and not final.session.flushing and not final.session.lockHeld and final.runtime.phase=="closed" and b.data.P_46001.lock==nil,"final ordinary application owner did not close/release its lease")
catalog:close()
print("RECOVERY_APPLICATION_GAME passed="..count.." failed=0")
end
runApplicationGameChecks()
end
