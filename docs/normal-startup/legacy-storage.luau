-- Unpublished native test adapter. No DataStoreService access or real keys.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
assert(Run:IsStudio() and game.PlaceId==0 and game.GameId==0 and WS:GetAttribute("NormalStartupDiagnostic")==true)
local Shared=RS:WaitForChild("Shared")
local Json=require(Shared.Persistence.Json)
local Archive=require(Shared.Persistence.RecoveryArchiveStorePrototype)
local Memory=require(Shared.Persistence.MemoryBackend)
local store=Memory.new()
local Storage={};local attached;local owners={}
local originals,expected
local codec=require(script.Parent.RestCompression).engine()
local starts,active,created,destroyed=0,0,0,0
local ds={}
function ds:GetAsync(key,options)
 assert(string.find(key,"qa_normal_startup",1,true),"outside diagnostic keys")
 starts+=1;active+=1
 if options then
  assert(options.UseCache==false);created+=1
  options.Destroying:Connect(function() destroyed+=1 end)
 end
 task.wait(.001)
 active-=1
 if WS:GetAttribute("DiagnosticUnavailable")==true then error("403: Studio API access is disabled") end
 local okay,value,why=store:read(key);assert(okay,why);return value
end
function ds:UpdateAsync(key,fn)
 assert(string.find(key,"qa_normal_startup",1,true),"outside diagnostic keys")
 starts+=1;active+=1
 if WS:GetAttribute("DiagnosticUnavailable")==true then active-=1;error("403: Studio API access is disabled") end
 local caller=coroutine.running();local returned
 task.spawn(function()
  assert(coroutine.running()~=caller)
  returned=table.pack(pcall(store.update,store,key,fn))
 end)
 repeat task.wait(.001) until returned~=nil
 active-=1;assert(returned[1],returned[2]);assert(returned[2],returned[4])
 return returned[3]
end
function Storage.loadStore()
 assert(originals==nil);originals,expected=require(script.Parent.NormalStartupLegacySeed)(store,codec)
 return ds,function() return {read=1000,write=1000} end
end
local folder=Instance.new("Folder");folder.Name="NormalStartupDiagnostic"
local command=Instance.new("RemoteEvent");command.Name="Command";command.Parent=folder
local report=Instance.new("RemoteEvent");report.Name="Report";report.Parent=folder
local function snapshot(player)
 local entry=attached and attached.service.base.entries[player]
 local owner=entry and entry.owner
 if owner and not table.find(owners,owner) then table.insert(owners,owner) end
 local history={};local requests=0
 for _,old in owners do
  requests+=old.session.counters.requests
  table.insert(history,{epoch=old.session.id,closed=old:replacementClosed()})
 end
 local rests={};local archives=0
 for key,value in store.data do
  if string.sub(key,1,2)=="R_" then rests[key]=Json.checksum((assert(Json.canonical(value)))) end
  if string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_" then archives+=1 end
 end
 local exact,unchanged={},{}
 for mode,original in originals or {} do
  local archive=store.data["A1_qa_normal_startup_"..mode]
  exact[mode]=archive~=nil and Json.canonical(archive.raw)==original
  unchanged[mode]=Json.canonical(store.data["R_qa_normal_startup_"..mode])==original
 end
 local parts={};for _,part in {"progress","main","free","easy","index"}do parts[part]=store.data["A1_qa_normal_startup_"..part]end
 local published=Archive.checkPublished("qa_normal_startup",parts)
 local progress=store.data.P_qa_normal_startup
 return {archiveComplete=published~=nil,originalExact=exact,originalUnchanged=unchanged,expected=expected,ready=attached~=nil,epoch=owner and owner.session.id,sessionState=owner and owner.session.state,
  sessionReason=owner and owner.session.reason,phase=owner and owner.runtime.phase,owners=history,requests=requests,
  starts=starts,active=active,optionsCreated=created,optionsDestroyed=destroyed,rests=rests,archives=archives,
  gate=attached and attached.gate:inspect(),lockReleased=progress~=nil and progress.lock==nil}
end
command.OnServerEvent:Connect(function(player,action,serial)
 if type(serial)~="number" or (action~="inspect" and action~="finish") then return end
 if action=="finish" then assert(attached);snapshot(player);attached.service:removePlayer(player) end
 report:FireClient(player,serial,snapshot(player))
end)
folder.Parent=RS
function Storage.observe(composition)
 assert(attached==nil);attached=composition
end
return Storage
