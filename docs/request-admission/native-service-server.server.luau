-- Unpublished Studio diagnostic. Real RemoteEvents, synthetic memory store.
-- No DataStoreService access. Never publish this model or this script.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Players=game:GetService("Players")
assert(Run:IsStudio() and Run:IsServer() and game.PlaceId==0 and WS:GetAttribute("NewApplicationNative")==true)
assert(script.Parent.Persistence.Disabled,"ordinary persistence must stay disabled")
local tag=tostring(DateTime.now().UnixTimestampMillis)
WS:SetAttribute("NativeApplicationRun",tag)
WS:SetAttribute("NativeApplicationClockStart",WS:GetServerTimeNow())
WS:SetAttribute("NativeApplicationClockBase",200)
WS:SetAttribute("NativeApplicationClockScale",1)
local function now() return 200+(WS:GetServerTimeNow()-WS:GetAttribute("NativeApplicationClockStart"))*1 end
local diagnostic=Instance.new("Folder");diagnostic.Name="NewApplicationNative"
local ready=Instance.new("RemoteEvent");ready.Name="Ready";ready.Parent=diagnostic
local command=Instance.new("RemoteEvent");command.Name="Command";command.Parent=diagnostic
local report=Instance.new("RemoteEvent");report.Name="Report";report.Parent=diagnostic
local readyPlayer
ready.OnServerEvent:Connect(function(player) if not readyPlayer then readyPlayer=player end end)
diagnostic.Parent=RS

local Shared=RS:WaitForChild("Shared")
local function shared(area,name) return require(Shared[area][name]) end
local Json=shared("Persistence","Json")
local Memory=shared("Persistence","MemoryBackend")
local Envelope=shared("Persistence","SaveEnvelope")
local SaveRest=shared("Persistence","SaveRest")
local Progress=shared("Persistence","SaveProgress")
local Checkpoint=shared("Persistence","Checkpoint")
local LifeProjection=shared("Persistence","RecoveryLifePrototype")
local ArchiveStore=shared("Persistence","RecoveryArchiveStorePrototype")
local Rules=shared("Data","SaveRules")
local Species=shared("Data","Species")
local Layout=shared("Habitat","WindowsillLayout")
local Map=shared("World","WorldMap")
local Region=shared("World","Region")
local Build=shared("World","WorldBuild")
local Garden=shared("World","Garden")
local Director=shared("Prey","PreyDirector")
local Woodlouse=shared("Prey","Woodlouse")
local Motor=shared("Movement","SpiderMotor")
local Sensor=shared("Perception","Sensor")
local MemoryModel=shared("Perception","ObservationMemory")
local Needs=shared("Life","NeedsModel")
local Life=shared("Life","LifeLoop")
local Templates=require(script.Parent.RecoveryTemplates)
local Backend=require(script.Parent.DataStoreBackend)
local Raw=require(script.Parent.RecoveryRawBackendPrototype)
local Service=require(script.Parent.ReplacementServicePrototype)
local Gate=require(script.Parent.RequestAdmissionGate)
local Accounts=require(script.Parent.RecoveryAccountLifetimes)
local Owner=require(script.Parent.ReplacementOwnerPrototype)
local Policy=require(script.Parent.RecoveryNewLifePolicyPrototype)
local Format=require(script.Parent.RecoveryRestFormatPrototype)
local Entry=require(script.Parent.RecoveryEntryPrototype)
local Loop=require(script.Parent.RecoverySaveLoopPrototype)
local codec=require(script.Parent.RestCompression).engine()
local store=Memory.new();local originals={};local owners={};local errors={}
local optionsCreated,optionsDestroyed=0,0
local ds={}
local nativeStarts={};local providerActive=0
local function started(kind,key)
 table.insert(nativeStarts,{kind=kind,key=key,at=now()});providerActive+=1
end
local cost={samples={},counts={},trace={},provider={},steps={},phases={}}
local previousStepKey,previousStepTime
local function stepState(owner)
 if not owner then return "none",false,0 end
 local rt=owner.runtime;local s=owner.session
 local key=rt.phase..":"..tostring(rt.job and rt.job.phase)..":"..tostring(rt.entryJob and rt.entryJob.phase)..":"..tostring(rt.discovery and rt.discovery.phase)
 local recent=0;local at=s.now()
 -- Observe without calling budgetOk, which prunes the live scheduler array.
 for _,started in s.sched.started do if at-started<60 then recent+=1 end end
 return key,recent>=Rules.REQUESTS_PER_MINUTE,s.counters.requests
end
local function measuredStep(service,owner)
 local key,full,requests=stepState(owner);local at=os.clock()
 if previousStepKey then cost.steps[previousStepKey].elapsed_seconds+=at-previousStepTime end
 local row=cost.steps[key]
 if not row then row={calls=0,seconds=0,max_seconds=0,budget_full_calls=0,request_starts=0,elapsed_seconds=0};cost.steps[key]=row end
 if previousStepKey~=key then table.insert(cost.phases,{name=key,t=WS:GetServerTimeNow(),budget_full=full,requests=requests}) end
 previousStepKey,previousStepTime=key,at
 service:step()
 local elapsed=os.clock()-at;row.calls+=1;row.seconds+=elapsed;row.max_seconds=math.max(row.max_seconds,elapsed)
 if full then row.budget_full_calls+=1 end
 if owner then row.request_starts+=math.max(0,owner.session.counters.requests-requests) end
end
local function wire(message)
 local kind=tostring(message.kind);local mode=message.mode or message.decision and message.decision.mode or "none"
 local key=kind..":"..tostring(mode);cost.counts[key]=(cost.counts[key] or 0)+1
 if not cost.samples[key] then
  local at=os.clock();local owned=Json.copy(message)
  cost.samples[key]={message=owned,copy_seconds=os.clock()-at}
 end
 if #cost.trace>=4096 then error("diagnostic server packet bound exceeded") end
 table.insert(cost.trace,{kind=kind,epoch=message.epoch,sequence=message.sequence,mode=mode,t=WS:GetServerTimeNow()})
end
local function provider(kind,started)
 local row=cost.provider[kind]
 if not row then row={calls=0,seconds=0,max_seconds=0};cost.provider[kind]=row end
 local elapsed=os.clock()-started;row.calls+=1;row.seconds+=elapsed;row.max_seconds=math.max(row.max_seconds,elapsed)
end
local function reportCost()
 for key,row in cost.samples do
  local at=os.clock();local text=assert(Json.canonical(row.message))
  print("[NATIVE_COST_SERVER_PAYLOAD]",tag,Json.canonical({key=key,canonical_bytes=#text,copy_seconds=row.copy_seconds,encode_seconds=os.clock()-at,count=cost.counts[key]}))
 end
 for key,row in cost.provider do row.key=key;print("[NATIVE_COST_SERVER_PROVIDER]",tag,Json.canonical(row)) end
 for key,row in cost.steps do row.key=key;print("[NATIVE_COST_SERVER_STEP]",tag,Json.canonical(row)) end
 for _,row in cost.phases do print("[NATIVE_COST_SERVER_PHASE]",tag,Json.canonical(row)) end
 for _,row in cost.trace do print("[NATIVE_COST_SERVER_TRACE]",tag,Json.canonical(row)) end
 print("[NATIVE_COST_SERVER_END]",tag,Json.canonical({packets=#cost.trace,clock_scale=1,online=false}))
end

function ds:GetAsync(key,options)
 started("read",key)
 local started=os.clock()
 if options then
  assert(options.UseCache==false,"cached verification read")
  optionsCreated+=1;options.Destroying:Connect(function() optionsDestroyed+=1 end)
 end
 task.wait(.01) -- actual provider yield, not an online latency claim
 local ok,value,why=store:read(key);assert(ok,why);provider("read",started);providerActive-=1;return value
end
function ds:UpdateAsync(key,fn)
 started("update",key)
 local started=os.clock()
 task.wait(.01)
 local ok,value,why=store:update(key,fn);assert(ok,why);provider("update",started);providerActive-=1;return value
end
local checks=0
local function check(ok,why) checks+=1;assert(ok,why) end
local function digest(value) return Json.checksum(assert(Json.canonical(value))) end
-- Explicit synthetic policy, not claimed Roblox platform budgets.
local gate=Gate.new({now=now,available=function() return {read=1000,write=1000} end,
 actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
local accounts=Accounts.new(gate,{now=now,sleep=task.wait,legacyHistory=function() return {} end})
local holdAck=true;local staleDecision;local service;local catalog;local selectedPlayer
local function snapshot()
 local saved={};local rests={};local complete=false;local exact={}
 for key,value in store.data do if string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_" then saved[key]=digest(value) end end
 local parts={};for _,part in {"progress","main","free","easy","index"} do parts[part]=store.data["A1_46001_"..part] end
 if parts.index then complete=ArchiveStore.checkPublished("46001",parts)~=nil end
 for _,mode in Rules.MODES do
  local raw=store.data["R_46001_"..mode];rests[mode]=digest(raw)
  local archive=store.data["A1_46001_"..mode];exact[mode]=archive~=nil and Json.canonical(archive.raw)==originals[mode]
 end
 local history={};for _,owner in owners do table.insert(history,{id=owner.session.id,closed=owner:replacementClosed(),phase=owner.runtime.phase}) end
 local current=owners[#owners]
 return {run=tag,archives=saved,archiveComplete=complete,originalExact=exact,rests=rests,owners=history,
  epoch=current and current.session.id,phase=current and current.runtime.phase,optionsCreated=optionsCreated,optionsDestroyed=optionsDestroyed,
  errors=#errors,accountGate=gate:inspect(),providerActive=providerActive,nativeStarts=#nativeStarts,lockReleased=store.data.P_46001 and store.data.P_46001.lock==nil,checks=checks}
end
local ok,why=xpcall(function()
 print("[NEW_APP_NATIVE_SERVER_BEGIN]",tag,"clock_scale=1 storage=memory codec=engine")
 local world=assert(WS:WaitForChild("World",90),"main server world unavailable")
 -- Build the synthetic old garden from actual engine collision and modules.
 -- No live player's save or played client is a source for these records.
 Map.use("test_garden")
 local container=Instance.new("Folder");container.Name="SyntheticLegacyCapture";container.Parent=WS
 local root=Build.world(container,Map.SEED)
 local casts=Director.casts(root)
 local prey=Director.engine(root,Species.fly_like_prototype,914,4,true,nil,casts)
 local bed=assert(Map.region("bed_a"));local spec=Garden.prey(bed)
 local bedPrey=Director.engine(root,Species.fungus_gnat_prototype,spec.seed,spec.target,false,spec,casts);bedPrey.feeding=prey.feeding
 local soil,boxes=nil,{}
 for _,piece in Region.pieces(bed) do
  if piece.id=="bed_a_soil" then soil={min=piece.lo,max=piece.hi} elseif piece.lo.Y<=-89.99 then table.insert(boxes,{min=piece.lo,max=piece.hi}) end
 end
 local bugs=Woodlouse.new(Garden.bugs(bed),soil,boxes)
 local memory=MemoryModel.new();local sensor=Sensor.new(memory);sensor:configureFrom(Species.phidippus_audax_prototype.perception)
 local needs=Needs.new(true,false);prey.feeding.needs=needs
 local motor=Motor.new({world=root,surfaces=shared("Data","Surfaces"),profile=Species.phidippus_audax_prototype,spawn=Layout.SPAWN,
  heading=Layout.SPAWN_HEADING,boundsMin=Layout.PLAY_BOUNDS_MIN,boundsMax=Layout.PLAY_BOUNDS_MAX})
 motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
 local life=Life.new(needs,nil)
 local old={motor=motor,prey=prey,sensor=sensor,memory=memory,needs=needs,life=life,garden={bed_a={prey=bedPrey,bugs=bugs}}}
 for _,mode in Rules.MODES do
  life.mode=if mode=="free" then "free" else "main";life.rules=if mode=="main" then "standard" else "gentle";needs.gentle=mode~="main"
  local record=assert(Checkpoint.capture(old,120));record.save_life="native-original-"..mode
  check(LifeProjection.prepare(record,SaveRest.stubWorld(),"A1_46001")~=nil,"synthetic native legacy record invalid")
  local raw=codec:encode(Envelope.make(SaveRest.SPECS[mode],record,100,nil))
  originals[mode]=assert(Json.canonical(raw));store:poke("R_46001_"..mode,raw)
 end
 if casts.probe then casts.probe:Destroy() end
 motor:destroy()
 container:Destroy();Map.use("preserve")
 local progress=Progress.default();progress.finished_main=true;store:poke("P_46001",Envelope.make(Progress.SPEC,progress,100,nil))
 catalog=assert(Templates.new(world))
 local folder=Instance.new("Folder");folder.Name=Rules.REMOTES_NAME
 local toServer=Instance.new("RemoteEvent");toServer.Name="ToServer";toServer.Parent=folder
 local toClient=Instance.new("RemoteEvent");toClient.Name="ToClient";toClient.Parent=folder
 service=Service.new({backend=Backend.new(ds,codec),now=now,sleep=task.wait,spawn=task.spawn,accountLifetimes=accounts,jobId="native-new-app",keyOf=function() return 46001 end,
  log=function(message) if string.find(message,"raised:",1,true) or string.find(message,"send failed:",1,true) then table.insert(errors,message) end;warn("[NEW_APP_NATIVE_SERVICE]",message) end,
  send=function(player,message)
   if message.kind=="decision" and message.decision and message.decision.kind=="continue" and message.decision.state=="writable" and not staleDecision then staleDecision=Json.copy(message) end
   wire(message);toClient:FireClient(player,message)
  end,
  newLifeFactory={new=function(runtime) return Policy.new(runtime,{work={budget=.002,maxSeconds=120}}) end},
  ownerFactory=function(config,emit)
   if #owners>0 then check(owners[#owners]:replacementClosed(),"native overlapping save owners") end
   local profiles=assert(catalog:profiles())
   local deps={codec=codec,rawBackend=Raw.new(ds),currentFormat=Format,entryFactory=Entry,saveFactory=Loop,
    reader={work={budget=.002,maxSeconds=120}},pipeline={reuseCompleteOriginal=true,work={budget=.002,maxSeconds=120}},
    entryOptions={work={budget=.002,maxSeconds=120}},saveOptions={work={budget=.002,maxSeconds=120},progress={work={budget=.002,maxSeconds=120}}}}
   local owner=Owner.new(config,emit,deps,profiles);table.insert(owners,owner);return owner
  end})
 toServer.OnServerEvent:Connect(function(player,message)
  if holdAck and type(message)=="table" and message.kind=="recovery_applied" then return end
  service:onMessage(player,message)
 end)
 command.OnServerEvent:Connect(function(player,action,serial)
  if player~=selectedPlayer or type(serial)~="number" then return end
  if action=="release_ack" then holdAck=false
  elseif action=="hold_ack" then holdAck=true
  elseif action=="replay_old" then if staleDecision then toClient:FireClient(player,Json.copy(staleDecision)) end
  elseif action=="finish" then service:removePlayer(player);WS:SetAttribute("NativeApplicationFinished",true)
  elseif action~="inspect" then return end
  report:FireClient(player,serial,snapshot())
 end)
 local deadline=os.clock()+90
 repeat task.wait(.05) until readyPlayer or os.clock()>=deadline
 check(readyPlayer~=nil and #Players:GetPlayers()==1,"one ready diagnostic client required")
 -- Native initial-load cancellation after an actual committed lock. Keep it
 -- separate from the single player's application owner sequence.
 local function preflight(deferred)
  local user=if deferred then 46003 else 46002
  local serviceTest;local who={UserId=user};local owned;local completed=false;local suspended=false
  local startedCount=0;local active=0;local backendStore=Memory.new()
  local record=Envelope.make(Progress.SPEC,Progress.default(),100,nil)
  backendStore:poke("P_"..user,record)
  local mock={}
  function mock:GetAsync(key,options)
   if options then assert(options.UseCache==false) end
   startedCount+=1;active+=1;task.wait(.02)
   local ok,value,problem=backendStore:read(key);active-=1;assert(ok,problem);return value
  end
  function mock:UpdateAsync(key,fn)
   startedCount+=1;active+=1
   local ok,value,problem=backendStore:update(key,fn);assert(ok,problem)
   if not deferred and not suspended then
    suspended=true
    -- Service removal runs in another native task while this provider's
    -- committed stack remains suspended. No coroutine.resume in the test.
    task.delay(.02,function() serviceTest:removePlayer(who);completed=true end)
    task.wait(.15)
   else task.wait(.02) end
   active-=1;return value
  end
  local g=Gate.new({now=now,available=function() return {read=1000,write=1000} end,
   actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
  local a=Accounts.new(g,{now=now,sleep=task.wait,legacyHistory=function() return {} end})
  local launched=0
  serviceTest=Service.new({backend=Backend.new(mock,codec),now=now,sleep=task.wait,accountLifetimes=a,
   keyOf=function() return user end,jobId="native-cancel",send=function() end,
   spawn=function(fn,...)
    launched+=1
    if deferred then task.delay(.2,fn,...) else task.spawn(fn,...) end
   end,
   ownerFactory=function(config,emit)
    owned=Owner.new(config,emit,{codec=codec,rawBackend=Raw.new(mock),currentFormat=Format,entryFactory=Entry,saveFactory=Loop},assert(catalog:profiles()))
    return owned
   end})
  serviceTest:addPlayer(who)
  if deferred then serviceTest:removePlayer(who);completed=true end
  local expires=os.clock()+30
  repeat task.wait(.025) until completed and owned and owned.session.closed and not owned.session.busy and g:inspect().scopes==0 or os.clock()>=expires
  task.wait(.3) -- permit deferred task to execute and prove it remains inert
  check(completed and owned and owned.session.closed and not owned.session.busy,"native initial cancellation did not close")
  check(active==0 and g:inspect().started==0 and g:inspect().scopes==0,"native cancelled provider/scope failed to drain")
  local raw=backendStore.data["P_"..user]
  local retained=Json.copy(raw);retained.lock=nil
  check(raw.lock==nil and Json.canonical(retained)==Json.canonical(record),"native cancellation changed progress or retained lock")
  check(if deferred then startedCount==0 else suspended and startedCount>1,"native cancellation boundary not exercised")
  check(launched>=1,"native executor not used")
  print("[NATIVE_SERVICE_PREFLIGHT]",tag,Json.canonical({deferred=deferred,starts=startedCount,active=active,scopes=g:inspect().scopes,closed=owned.session.closed}))
 end
 preflight(false);preflight(true)

 selectedPlayer=readyPlayer;service:addPlayer(selectedPlayer)
 folder.Parent=RS -- only after the actual application confirms installation
 WS:SetAttribute("NativeApplicationServerReady",true)
 Players.PlayerRemoving:Connect(function(player) service:removePlayer(player) end)
 game:BindToClose(function() service:shutdown() end)
 while selectedPlayer.Parent and not WS:GetAttribute("NativeApplicationFinished") do Run.Heartbeat:Wait();measuredStep(service,owners[#owners]) end
 check(providerActive==0,"provider did not drain at final departure")
 local ledger=gate:inspect();local nr,nw,nh=0,0,0
 for _,row in nativeStarts do if now()-row.at<60 then nh+=1;nr+=1;if row.kind=="update" then nw+=1 end end end
 check(ledger.history==nh and ledger.read==nr and ledger.write==nw,"native SDK ledger mismatch")
 check(ledger.started==0 and ledger.scopes==0,"native service scope survived departure")
 print("[NATIVE_SERVICE_LEDGER]",tag,Json.canonical({starts=#nativeStarts,history=nh,read=nr,write=nw,active=providerActive,scopes=ledger.scopes}))
 print("[NEW_APP_NATIVE_SERVER_END]",tag,Json.canonical(snapshot()));reportCost()
end,debug.traceback)
if not ok then WS:SetAttribute("NativeApplicationServerFailed",true);warn("[NEW_APP_NATIVE_SERVER_FAIL]",tag,tostring(why)) end
