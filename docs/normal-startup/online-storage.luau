-- Unpublished Studio adapter: real test storage, explicit synthetic keys only.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Players=game:GetService("Players")
local DSS=game:GetService("DataStoreService")
assert(Run:IsStudio() and Run:IsServer() and game.GameId==10771634917 and game.PlaceId==109879630247781)
assert(WS:GetAttribute("OnlineStartupDiagnostic")==true)
local USER="qa_s_74c52a1d98ef430b"
local CONTROL="Q1_"..USER
local Shared=RS:WaitForChild("Shared")
local Json=require(Shared.Persistence.Json)
local Rules=require(Shared.Data.SaveRules)
local Archive=require(Shared.Persistence.RecoveryArchiveStorePrototype)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Format=require(script.Parent.RecoveryRestFormatPrototype)
local codec=require(script.Parent.RestCompression).engine()
local raw=DSS:GetDataStore("WindowsillTest_v1")
local allowed={[CONTROL]=true,["P_"..USER]=true,["A1_"..USER.."_progress"]=true,["A1_"..USER.."_index"]=true}
for _,mode in Rules.MODES do for _,prefix in {"R_","A1_","M1_"}do allowed[prefix..USER.."_"..mode]=true end end
local Storage={};local attached;local cache={};local owners={};local starts={}
local active,created,destroyed,checks=0,0,0,0
local metadata;local originals;local rejoining=false;local selected;local armed=false;local leaving=false
local run=tostring(DateTime.now().UnixTimestampMillis)
local function now()return WS:GetServerTimeNow()end
local function emit(kind,value)print("[ONLINE_STARTUP_"..kind.."]",run,assert(Json.canonical(value)))end
local function check(ok,why)checks+=1;assert(ok,why)end
local function canonical(v)return assert(Json.canonical(v))end
local function digest(v)return Json.checksum(canonical(v))end
local function begin(kind,key)
 assert(allowed[key],"refusing non-synthetic key");active+=1
 table.insert(starts,{kind=kind,at=now(),key=key})
end
local ds={}
function ds:GetAsync(key,options)
 begin("read",key)
 assert(options and options.UseCache==false,"all diagnostic/game reads must be uncached")
 created+=1;options.Destroying:Connect(function()destroyed+=1 end)
 local ok,value=pcall(function()return raw:GetAsync(key,options)end)
 active-=1;assert(ok,value);cache[key]=Json.copy(value);return value
end
function ds:UpdateAsync(key,fn)
 begin("update",key)
 local ok,value=pcall(function()return raw:UpdateAsync(key,fn)end)
 active-=1;assert(ok,value);if value~=nil then cache[key]=Json.copy(value)end;return value
end
function Storage.loadStore()
 return ds,function()return {read=DSS:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardRead),
  write=DSS:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardWrite)}end
end
local function epoch(id)
 local scope=assert(attached.gate:open(USER,id))
 if not attached.gate:legacyReady(scope)then assert(attached.gate:importLegacy(scope,{}))end
 return scope
end
local function call(scope,kind,fn)
 local ticket=assert(attached.gate:request(scope,kind));local deadline=now()+120
 repeat
  local ok,result,why=attached.gate:dispatch(ticket,fn)
  if ok then return table.unpack(result,1,result.n)end
  local status=attached.gate:status(ticket)
  assert(status=="queued" or status=="reserved",why);task.wait(.025)
 until now()>=deadline
 attached.gate:cancel(ticket);error("online diagnostic admission expired")
end
local function fresh(scope,key)
 local options=Instance.new("DataStoreGetOptions");options.UseCache=false
 local ok,value=pcall(call,scope,"read",function()return ds:GetAsync(key,options)end)
 options:Destroy();assert(ok,value);return value
end
local function write(scope,key,value,before)
 call(scope,"update",function()return ds:UpdateAsync(key,function(old)
  assert(if old==nil or before==nil then old==before else canonical(old)==canonical(before),"synthetic CAS changed; refusing overwrite");return value
 end)end)
 check(canonical(fresh(scope,key))==canonical(value),"synthetic write readback changed")
end
local function publication()
 local parts={};for _,part in {"progress","main","free","easy","index"}do parts[part]=cache["A1_"..USER.."_"..part]end
 return Archive.checkPublished(USER,parts)~=nil
end
local function snapshot(player)
 if selected==nil then selected=player end;assert(selected==player,"one diagnostic player only")
 local entry=attached.service.base.entries[player];local owner=entry and entry.owner
 if owner and not table.find(owners,owner)then table.insert(owners,owner)end
 local exact,unchanged,rests,prior={},{},{},{}
 local artifacts=0
 for key in allowed do if cache[key]~=nil and (string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_")then artifacts+=1 end end
 for _,mode in Rules.MODES do
  local value=cache["R_"..USER.."_"..mode];local archived=cache["A1_"..USER.."_"..mode]
  exact[mode]=archived~=nil and canonical(archived.raw)==originals[mode]
  unchanged[mode]=canonical(value)==originals[mode]
  if value~=nil then rests[mode]=digest(value)end
  if rejoining then
   local opened=Envelope.open(Format.spec(mode),codec:decode(value))
   check(opened.status=="ok" and opened.payload.format==Format.FORMAT,"rejoin checkpoint not continued schema3")
   prior[mode]=digest(opened.payload.checkpoint)
  end
 end
 local history={};for _,old in owners do table.insert(history,{epoch=old.session.id,closed=old:replacementClosed()})end
 return {user=USER,run=run,rejoining=rejoining,priorPayloadDigests=prior,ready=true,archives=artifacts,
  archiveComplete=publication(),originalExact=exact,originalUnchanged=unchanged,rests=rests,owners=history,
  starts=#starts,active=active,optionsCreated=created,optionsDestroyed=destroyed,gate=attached.gate:inspect(),checks=checks,
  epoch=owner and owner.session.id,phase=owner and owner.runtime.phase}
end
local folder=Instance.new("Folder");folder.Name="NormalStartupDiagnostic"
local command=Instance.new("RemoteEvent");command.Name="Command";command.Parent=folder
local report=Instance.new("RemoteEvent");report.Name="Report";report.Parent=folder
command.OnServerEvent:Connect(function(player,action,serial)
 if type(serial)~="number" or (action~="inspect" and action~="arm_leave")then return end
 local ok,value=xpcall(function()
  local state=snapshot(player)
  if action=="arm_leave"then
   check(not armed and publication(),"departure cannot arm before verified archive");armed=true
   task.delay(2,function()if player.Parent then player:Kick("Isolated ordinary-startup save diagnostic: actual departure")end end)
  end
  return state
 end,debug.traceback)
 if not ok then WS:SetAttribute("OnlineStartupServerFailed",true);emit("FAIL",{stage="command",problem=tostring(value)});return end
 report:FireClient(player,serial,value)
end)
folder.Parent=RS
local function departed(player)
 if player~=selected or leaving then return end;leaving=true
 local ok,why=xpcall(function()
  check(armed,"unarmed departure cannot qualify")
  -- Persistence's ordinary PlayerRemoving listener owns closure. Do not call it here.
  local deadline=now()+Rules.FLUSH_DEADLINE+3
  repeat task.wait(.025)until attached.gate:inspect().scopes==0 and active==0 or now()>=deadline
  check(attached.service.base.entries[player]==nil and attached.gate:inspect().scopes==0 and active==0,"ordinary PlayerRemoving failed to drain")
  local proof=epoch("online-startup-departure:"..run);local stored,immutable={},{}
  for key in allowed do if key~=CONTROL then
   local value=fresh(proof,key)
   if value~=nil then stored[key]=digest(value)end
   if value~=nil and (string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_")then immutable[key]=digest(value)end
  end end
  check(cache["P_"..USER]~=nil and cache["P_"..USER].lock==nil,"actual departure retained lock")
  check(publication(),"published original archive incomplete after departure")
  for _,mode in Rules.MODES do
   check(canonical(cache["A1_"..USER.."_"..mode].raw)==originals[mode],"departure changed original")
   local opened=Envelope.open(Format.spec(mode),codec:decode(cache["R_"..USER.."_"..mode]))
   check(opened.status=="ok" and opened.payload.format==Format.FORMAT and not opened.payload.save_retired,"saved life is not schema3 continued checkpoint")
  end
  if rejoining then
   for key,value in metadata.immutable do check(immutable[key]==value,"rejoin changed immutable artifact")end
   for _,mode in {"free","easy"}do local key="R_"..USER.."_"..mode;check(stored[key]==metadata.stored[key],"Main rejoin changed another slot")end
  end
  local nextMetadata={version=1,user=USER,state=if rejoining then "done" else "await_rejoin",originals=originals,
   stored=stored,immutable=immutable,run=run,actual_removals=1}
  write(proof,CONTROL,nextMetadata,metadata);attached.gate:close(proof)
  local ledger=attached.gate:inspect();local nr,nw,nh=0,0,0
  for _,row in starts do if now()-row.at<60 then nh+=1;nr+=1;if row.kind=="update"then nw+=1 end end end
  check(ledger.history==nh and ledger.read==nr and ledger.write==nw,"physical SDK/account ledger differs")
  check(ledger.scopes==0 and ledger.queued==0 and ledger.started==0 and active==0 and created==destroyed,"departure leaked scopes/providers/options")
  emit("DEPARTURE_PASS",{checks=checks,user=USER,state=nextMetadata.state,starts=#starts,optionsCreated=created,
   optionsDestroyed=destroyed,actual_removals=1,scopes=ledger.scopes,history=nh,read=nr,write=nw,lock_released=true,rejoining=rejoining})
  WS:SetAttribute("OnlineStartupServerPassed",true)
 end,debug.traceback)
 if not ok then WS:SetAttribute("OnlineStartupServerFailed",true);emit("FAIL",{stage="departure",problem=tostring(why)})end
end
function Storage.observe(composition)
 assert(attached==nil);attached=composition
 local scope=epoch("online-startup-setup:"..run);metadata=fresh(scope,CONTROL)
 if metadata==nil then
  for key in allowed do if key~=CONTROL then check(fresh(scope,key)==nil,"occupied namespace; no reset/reseed permitted")end end
  local staging={data={}};function staging:poke(key,value)assert(allowed[key] and self.data[key]==nil);self.data[key]=value end
  originals=require(script.Parent.NormalStartupLegacySeed)(staging,codec)
  for key,value in staging.data do write(scope,key,value,nil)end
  metadata={version=1,user=USER,state="seeded",originals=originals,stored={}}
  for key,value in staging.data do metadata.stored[key]=digest(value)end
  write(scope,CONTROL,metadata,nil)
 else
  check(type(metadata)=="table" and metadata.version==1 and metadata.user==USER and
   (metadata.state=="seeded" or metadata.state=="await_rejoin"),"terminal/unknown diagnostic control; no replay")
  originals=metadata.originals;rejoining=metadata.state=="await_rejoin"
  for key in allowed do if key~=CONTROL then
   local value=fresh(scope,key);local wanted=metadata.stored[key]
   check(if wanted then value~=nil and digest(value)==wanted else value==nil,"retained synthetic record changed; no reset")
  end end
  check(cache["P_"..USER].lock==nil,"retained lease not released")
 end
 attached.gate:close(scope)
 check(attached.gate:inspect().scopes==0 and active==0 and created==destroyed,"bootstrap did not drain")
 WS:SetAttribute("OnlineStartupRejoin",rejoining)
 Players.PlayerRemoving:Connect(departed)
 emit("BOOTSTRAP",{user=USER,rejoining=rejoining,starts=#starts,state=metadata.state,ordinary_persistence=true,real_storage=true})
end
return Storage
