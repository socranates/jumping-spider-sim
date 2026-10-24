-- Unpublished Studio diagnostic. Real RemoteEvents, synthetic memory store.
-- No DataStoreService access. Never publish this model or this script.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Players=game:GetService("Players")
assert(Run:IsStudio() and Run:IsServer() and game.GameId==10771634917 and game.PlaceId==109879630247781 and WS:GetAttribute("NewApplicationNative")==true)
assert(script.Parent.Persistence.Disabled,"ordinary persistence must stay disabled")
local tag=tostring(DateTime.now().UnixTimestampMillis)
WS:SetAttribute("NativeApplicationRun",tag)
WS:SetAttribute("NativeApplicationClockStart",WS:GetServerTimeNow())
WS:SetAttribute("NativeApplicationClockBase",200)
WS:SetAttribute("NativeApplicationClockScale",1)
local function now() return WS:GetServerTimeNow() end
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
local TEST_USER="qa_3cb3b30963a84dc6";local CONTROL_KEY="Q1_"..TEST_USER
local allowedKeys={[CONTROL_KEY]=true,["P_"..TEST_USER]=true,["A1_"..TEST_USER.."_progress"]=true,["A1_"..TEST_USER.."_index"]=true}
for _,mode in Rules.MODES do for _,prefix in {"R_","A1_","M1_"} do allowedKeys[prefix..TEST_USER.."_"..mode]=true end end
local store={data={}};local originals={};local owners={};local errors={}
local optionsCreated,optionsDestroyed=0,0
local DataStores=game:GetService("DataStoreService")
local actual=DataStores:GetDataStore("WindowsillTest_v1")
local ds={};local nativeStarts={};local providerActive=0
local function nativeStart(kind,key)
 assert(allowedKeys[key],"refusing a key outside the unique synthetic namespace")
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
 print("[NATIVE_COST_SERVER_END]",tag,Json.canonical({packets=#cost.trace,clock_scale=1,online=true}))
end

function ds:GetAsync(key,options)
 nativeStart("read",key);local at=os.clock()
 if options then assert(options.UseCache==false);optionsCreated+=1;options.Destroying:Connect(function() optionsDestroyed+=1 end) end
 local ok,value=pcall(function() return actual:GetAsync(key,options) end)
 providerActive-=1;provider("read",at);assert(ok,value)
 store.data[key]=Json.copy(value);return value
end
function ds:UpdateAsync(key,fn)
 nativeStart("update",key);local at=os.clock()
 local ok,value=pcall(function() return actual:UpdateAsync(key,fn) end)
 providerActive-=1;provider("update",at);assert(ok,value)
 if value~=nil then store.data[key]=Json.copy(value) end;return value
end
local checks=0
local function check(ok,why) checks+=1;assert(ok,why) end
local function digest(value) return Json.checksum(assert(Json.canonical(value))) end
-- Explicit synthetic policy, not claimed Roblox platform budgets.
local gate=Gate.new({now=now,available=function() return {read=DataStores:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardRead),write=DataStores:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardWrite)} end,
 actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=2})
local accounts=Accounts.new(gate,{now=now,sleep=task.wait,legacyHistory=function() return {} end})
local holdAck=true;local staleDecision;local service;local catalog;local selectedPlayer
-- Diagnostic I/O uses its own short account epoch on the SAME physical ledger.
-- It does not reopen a Session or grant gameplay authority.
local function diagnosticEpoch(id)
 local scope=assert(gate:open(TEST_USER,id))
 if not gate:legacyReady(scope) then assert(gate:importLegacy(scope,{})) end
 return scope
end
local function diagnosticCall(scope,kind,fn)
 local ticket=assert(gate:request(scope,kind))
 local deadline=now()+120
 while now()<deadline do
  local okay,result,problem=gate:dispatch(ticket,fn)
  if okay then return table.unpack(result,1,result.n) end
  local status=gate:status(ticket)
  assert(status=="queued" or status=="reserved",problem)
  task.wait(.025)
 end
 gate:cancel(ticket);error("diagnostic admission expired")
end
local function fresh(scope,key)
 local request=Instance.new("DataStoreGetOptions");request.UseCache=false
 local ok,value=pcall(diagnosticCall,scope,"read",function() return ds:GetAsync(key,request) end)
 request:Destroy();assert(ok,value);return value
end
local setup=diagnosticEpoch("online-setup:"..tag)
local metadata=fresh(setup,CONTROL_KEY)
local rejoining=metadata~=nil
if rejoining then
 assert(type(metadata)=="table" and metadata.version==1 and metadata.user==TEST_USER and metadata.state=="await_rejoin","unexpected test control state; no overwrite")
 originals=metadata.originals
 for key,expected in metadata.stored do
  assert(allowedKeys[key] and key~=CONTROL_KEY,"unknown retained test key")
  assert(digest(fresh(setup,key))==expected,"online leave/rejoin changed stored value: "..key)
 end
 check(store.data["P_"..TEST_USER].lock==nil,"previous real departure retained lock")
 print("[ONLINE_SERVICE_REJOIN_SOURCE]",tag,TEST_USER,"exact_uncached_storage_match")
else
 for key in allowedKeys do if key~=CONTROL_KEY then assert(fresh(setup,key)==nil,"fresh diagnostic namespace already has data; refusing overwrite") end end
end
local function seed(key,value)
 assert(not rejoining and key~=CONTROL_KEY,"rejoin cannot seed or reset a record")
 diagnosticCall(setup,"update",function()
  return ds:UpdateAsync(key,function(old) assert(old==nil,"seed key raced; no overwrite");return value end)
 end)
 assert(Json.canonical(fresh(setup,key))==Json.canonical(value),"initial synthetic record readback changed")
end
WS:SetAttribute("OnlineServiceRejoin",rejoining)
local priorPayloadDigests={}
if rejoining then
 for _,mode in Rules.MODES do
  local raw=store.data["R_"..TEST_USER.."_"..mode]
  local opened=Envelope.open(SaveRest.SPECS[mode],codec:decode(raw))
  assert(opened.status=="ok" and not SaveRest.isRetired(opened.payload),"rejoin missing ordinary stored life")
  priorPayloadDigests[mode]=digest(opened.payload)
 end
end

local function snapshot()
 local saved={};local rests={};local complete=false;local exact={}
 for key,value in store.data do if string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_" then saved[key]=digest(value) end end
 local parts={};for _,part in {"progress","main","free","easy","index"} do parts[part]=store.data["A1_qa_3cb3b30963a84dc6_"..part] end
 if parts.index then complete=ArchiveStore.checkPublished("qa_3cb3b30963a84dc6",parts)~=nil end
 for _,mode in Rules.MODES do
  local raw=store.data["R_qa_3cb3b30963a84dc6_"..mode];rests[mode]=digest(raw)
  local archive=store.data["A1_qa_3cb3b30963a84dc6_"..mode];exact[mode]=archive~=nil and Json.canonical(archive.raw)==originals[mode]
 end
 local history={};for _,owner in owners do table.insert(history,{id=owner.session.id,closed=owner:replacementClosed(),phase=owner.runtime.phase}) end
 local current=owners[#owners]
 return {run=tag,rejoining=rejoining,priorPayloadDigests=priorPayloadDigests,archives=saved,archiveComplete=complete,originalExact=exact,rests=rests,owners=history,
  epoch=current and current.session.id,phase=current and current.runtime.phase,optionsCreated=optionsCreated,optionsDestroyed=optionsDestroyed,
  errors=#errors,accountGate=gate:inspect(),providerActive=providerActive,nativeStarts=#nativeStarts,lockReleased=store.data.P_qa_3cb3b30963a84dc6 and store.data.P_qa_3cb3b30963a84dc6.lock==nil,checks=checks}
end
local ok,why=xpcall(function()
 print("[NEW_APP_NATIVE_SERVER_BEGIN]",tag,"clock_scale=1 storage=WindowsillTest_v1 online=true codec=engine")
 local world=assert(WS:WaitForChild("World",90),"main server world unavailable")
 if not rejoining then
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
  check(LifeProjection.prepare(record,SaveRest.stubWorld(),"A1_qa_3cb3b30963a84dc6")~=nil,"synthetic native legacy record invalid")
  local raw=codec:encode(Envelope.make(SaveRest.SPECS[mode],record,100,nil))
  originals[mode]=assert(Json.canonical(raw));seed("R_qa_3cb3b30963a84dc6_"..mode,raw)
 end
 if casts.probe then casts.probe:Destroy() end
 motor:destroy()
 container:Destroy();Map.use("preserve")
 local progress=Progress.default();progress.finished_main=true;seed("P_qa_3cb3b30963a84dc6",Envelope.make(Progress.SPEC,progress,100,nil))
 end
 gate:close(setup)
 catalog=assert(Templates.new(world))
 local folder=Instance.new("Folder");folder.Name=Rules.REMOTES_NAME
 local toServer=Instance.new("RemoteEvent");toServer.Name="ToServer";toServer.Parent=folder
 local toClient=Instance.new("RemoteEvent");toClient.Name="ToClient";toClient.Parent=folder
 service=Service.new({backend=Backend.new(ds,codec),now=now,sleep=task.wait,spawn=task.spawn,accountLifetimes=accounts,jobId="native-new-app",keyOf=function() return "qa_3cb3b30963a84dc6" end,
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
  elseif action=="arm_leave" then
   task.delay(2,function() if selectedPlayer.Parent then selectedPlayer:Kick("Isolated save diagnostic: real departure") end end)
  elseif action~="inspect" then return end
  report:FireClient(player,serial,snapshot())
 end)
 local deadline=os.clock()+90
 repeat task.wait(.05) until readyPlayer or os.clock()>=deadline
 check(readyPlayer~=nil and #Players:GetPlayers()==1,"one ready diagnostic client required")
 selectedPlayer=readyPlayer;service:addPlayer(selectedPlayer)
 folder.Parent=RS -- only after the actual application confirms installation
 WS:SetAttribute("NativeApplicationServerReady",true)
local actualRemovals=0
local leaving=false
local function departed(player)
 if player~=selectedPlayer or leaving then return end
 leaving=true;actualRemovals+=1
 print("[ONLINE_SERVICE_PLAYER_REMOVING]",tag,TEST_USER,actualRemovals)
 local old=owners[#owners]
 service:removePlayer(player)
 local deadline=now()+Rules.FLUSH_DEADLINE+2
 repeat task.wait(.025) until gate:inspect().scopes==0 and providerActive==0 or now()>=deadline
 check(old.session.closed and gate:inspect().scopes==0 and providerActive==0,"actual departure failed to close/drain owner")
 local proof=diagnosticEpoch("online-after-leave:"..tag)
 local stored={};local immutable={}
 for key in allowedKeys do
  if key~=CONTROL_KEY then
   local raw=fresh(proof,key)
   if raw~=nil then stored[key]=digest(raw) end
   if string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_" then immutable[key]=digest(raw) end
  end
 end
 local p=store.data["P_"..TEST_USER]
 check(p~=nil and p.lock==nil,"uncached departure proof retained lock")
 for _,mode in Rules.MODES do
  local archive=store.data["A1_"..TEST_USER.."_"..mode]
  check(archive~=nil and Json.canonical(archive.raw)==originals[mode],"actual departure changed original archive")
  local rest=Envelope.open(SaveRest.SPECS[mode],codec:decode(store.data["R_"..TEST_USER.."_"..mode]))
  check(rest.status=="ok" and not SaveRest.isRetired(rest.payload),"actual departure did not retain ordinary checkpoint")
 end
 if rejoining then
  for key,value in metadata.immutable do check(immutable[key]==value,"rejoined save changed immutable archive/proposal") end
  for _,mode in {"free","easy"} do local key="R_"..TEST_USER.."_"..mode;check(stored[key]==metadata.stored[key],"rejoined Main save changed another current slot") end
 end
 local nextMetadata={version=1,user=TEST_USER,state=if rejoining then "done" else "await_rejoin",originals=originals,
  stored=stored,immutable=immutable,epoch=old.session.id,playerRemovals=actualRemovals,run=tag}
 diagnosticCall(proof,"update",function()
  return ds:UpdateAsync(CONTROL_KEY,function(current)
   assert(if rejoining then Json.canonical(current)==Json.canonical(metadata) else current==nil,"control state changed; refusing overwrite")
   return nextMetadata
  end)
 end)
 check(Json.canonical(fresh(proof,CONTROL_KEY))==Json.canonical(nextMetadata),"online departure control readback changed")
 gate:close(proof)
 check(gate:inspect().scopes==0 and gate:inspect().started==0 and providerActive==0,"online final verification scope survived")
 print("[ONLINE_SERVICE_DEPARTURE_PASS]",tag,Json.canonical({user=TEST_USER,state=nextMetadata.state,actual_removals=actualRemovals,
  lock_released=true,scopes=gate:inspect().scopes,provider_active=providerActive,stored_keys=(function() local n=0;for _ in stored do n+=1 end;return n end)()}))
 WS:SetAttribute("NativeApplicationFinished",true)
end
Players.PlayerRemoving:Connect(function(player)
 local ok,problem=xpcall(function() departed(player) end,debug.traceback)
 if not ok then WS:SetAttribute("NativeApplicationServerFailed",true);warn("[NEW_APP_NATIVE_SERVER_FAIL]",tag,problem) end
end)
game:BindToClose(function()
 if selectedPlayer and not leaving then departed(selectedPlayer) end
 service:shutdown()
end)

 while not WS:GetAttribute("NativeApplicationFinished") and not WS:GetAttribute("NativeApplicationServerFailed") do Run.Heartbeat:Wait();measuredStep(service,owners[#owners]) end
 check(providerActive==0,"provider did not drain at final departure")
 local ledger=gate:inspect();local nr,nw,nh=0,0,0
 for _,row in nativeStarts do if now()-row.at<60 then nh+=1;nr+=1;if row.kind=="update" then nw+=1 end end end
 check(ledger.history==nh and ledger.read==nr and ledger.write==nw,"native SDK ledger mismatch")
 check(ledger.started==0 and ledger.scopes==0,"native service scope survived departure")
 print("[NATIVE_SERVICE_LEDGER]",tag,Json.canonical({starts=#nativeStarts,history=nh,read=nr,write=nw,active=providerActive,scopes=ledger.scopes}))
assert(optionsCreated==optionsDestroyed and #errors==0 and actualRemovals==1,"online departure leaked options/errors or was not a real removal")
 print("[ONLINE_SERVICE_SERVER_PASS]",tag,Json.canonical({checks=checks,rejoining=rejoining,user=TEST_USER,optionsCreated=optionsCreated,optionsDestroyed=optionsDestroyed,errors=#errors,actual_removals=actualRemovals}))
 reportCost()
end,debug.traceback)
if not ok then WS:SetAttribute("NativeApplicationServerFailed",true);warn("[NEW_APP_NATIVE_SERVER_FAIL]",tag,tostring(why)) end
