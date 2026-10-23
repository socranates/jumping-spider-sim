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
WS:SetAttribute("NativeApplicationClockScale",10)
local function now() return 200+(WS:GetServerTimeNow()-WS:GetAttribute("NativeApplicationClockStart"))*10 end
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
local Owner=require(script.Parent.ReplacementOwnerPrototype)
local Policy=require(script.Parent.RecoveryNewLifePolicyPrototype)
local Format=require(script.Parent.RecoveryRestFormatPrototype)
local Entry=require(script.Parent.RecoveryEntryPrototype)
local Loop=require(script.Parent.RecoverySaveLoopPrototype)
local codec=require(script.Parent.RestCompression).engine()
local store=Memory.new();local originals={};local owners={};local errors={}
local optionsCreated,optionsDestroyed=0,0
local ds={}
function ds:GetAsync(key,options)
 if options then
  assert(options.UseCache==false,"cached verification read")
  optionsCreated+=1;options.Destroying:Connect(function() optionsDestroyed+=1 end)
 end
 task.wait(.01) -- actual provider yield, not an online latency claim
 local ok,value,why=store:read(key);assert(ok,why);return value
end
function ds:UpdateAsync(key,fn)
 task.wait(.01)
 local ok,value,why=store:update(key,fn);assert(ok,why);return value
end
local checks=0
local function check(ok,why) checks+=1;assert(ok,why) end
local function digest(value) return Json.checksum(assert(Json.canonical(value))) end
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
  errors=#errors,lockReleased=store.data.P_46001 and store.data.P_46001.lock==nil,checks=checks}
end
local ok,why=xpcall(function()
 print("[NEW_APP_NATIVE_SERVER_BEGIN]",tag,"clock_scale=10 storage=memory codec=engine")
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
 service=Service.new({backend=Backend.new(ds,codec),now=now,sleep=task.wait,spawn=task.spawn,jobId="native-new-app",keyOf=function() return 46001 end,
  log=function(message) if string.find(message,"raised:",1,true) or string.find(message,"send failed:",1,true) then table.insert(errors,message) end;warn("[NEW_APP_NATIVE_SERVICE]",message) end,
  send=function(player,message)
   if message.kind=="decision" and message.decision and message.decision.kind=="continue" and message.decision.state=="writable" and not staleDecision then staleDecision=Json.copy(message) end
   toClient:FireClient(player,message)
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
 selectedPlayer=readyPlayer;service:addPlayer(selectedPlayer)
 folder.Parent=RS -- only after the actual application confirms installation
 WS:SetAttribute("NativeApplicationServerReady",true)
 Players.PlayerRemoving:Connect(function(player) service:removePlayer(player) end)
 game:BindToClose(function() service:shutdown() end)
 while selectedPlayer.Parent and not WS:GetAttribute("NativeApplicationFinished") do task.wait(.05);service:step() end
 print("[NEW_APP_NATIVE_SERVER_END]",tag,Json.canonical(snapshot()))
end,debug.traceback)
if not ok then WS:SetAttribute("NativeApplicationServerFailed",true);warn("[NEW_APP_NATIVE_SERVER_FAIL]",tag,tostring(why)) end
