do
local function runServiceOwnerChecks()
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Backend=require("../src/Server/DataStoreBackend")
local Service=require("../src/Server/SaveService")
local Client=require("../src/Client/SaveClient")
local Rules=require("../src/Shared/Data/SaveRules")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function fixture(mode,reentrant,oldPeer)
 WorldMap.use("test_garden");local old=gardenWorld();old.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
 old.life.mode=if mode=="free" then "free" else "main";old.life.rules=if mode=="main" then "standard" else "gentle";old.needs.gentle=mode~="main"
 local source=assert(Checkpoint.capture(old,123));source.save_life="service-original-"..mode
 WorldMap.use("preserve");local context=newWorld();context.life.mode=old.life.mode;context.life.rules=old.life.rules;context.needs.gentle=mode~="main"
 local b=Memory.new();local gp=Json.copy(rawProgress.payload);gp.finished_main=true;gp.settings.MasterVolume=.2
 b:poke("P_46001",Envelope.make(Progress.SPEC,gp,100,nil));b:poke("R_46001_"..mode,codec:encode(Envelope.make(SaveRest.SPECS[mode],source,100,nil)))
 local ds={}
 function ds:GetAsync(key,options) check(options==nil or options.UseCache==false,"service verification used cached datastore read");local ok,value,why=b:read(key);if not ok then error(why) end;return value end
 function ds:UpdateAsync(key,fn) local ok,value,why=b:update(key,fn);if not ok then error(why) end;return value end
 local normal=Backend.new(ds,codec);local raw=__rawBackendPrototype.new(ds);local clock={now=200};local queue={};local listener;local deliver;local client
 local f={b=b,clock=clock,world=context,mode=mode,entries=0,applied=0,hold=true,acks={},cache={},packets={},errors={}}
 local player={UserId=46001,Name="service-wire-"..mode};f.player=player
 local service=Service.new({backend=normal,now=function() return clock.now end,sleep=function(dt) clock.now+=dt end,spawn=function(fn,...) fn(...) end,jobId="service-wire",
  log=function(why)
   f.logs=f.logs or {};table.insert(f.logs,why)
   if string.find(why,"raised:",1,true) or string.find(why,"send failed:",1,true) then table.insert(f.errors,why) end
  end,
  send=function(_player,msg)
   table.insert(f.packets,{kind=msg.kind,epoch=msg.epoch,sequence=msg.sequence})
   if reentrant and msg.kind=="recovery_entry" and listener then deliver(Json.copy(msg)) else table.insert(queue,Json.copy(msg)) end
  end,
  ownerFactory=function(config,emit)
   local dependencies={codec=codec,rawBackend=raw,template=assert(Checkpoint.capture(context,124)),context=context,currentFormat=__restFormatPrototype,
    entryFactory=__entryPrototype,saveFactory=__saveLoopPrototype,reader={work={now=function() return 0 end}},pipeline={reuseCompleteOriginal=true,work={now=function() return 0 end}},
    entryOptions={work={now=function() return 0 end}},saveOptions={work={now=function() return 0 end},progress={work={now=function() return 0 end}}}}
   local result=__serviceOwnerPrototype.new(config,emit,dependencies,mode);f.owner=result;return result
  end})
 f.service=service
 local remote={};function remote:FireServer(msg) service:onMessage(player,msg) end
 local event={};function event:Connect(fn) listener=fn;return {Disconnect=function() end} end
 client=Client.new({rules=Rules,now=function() return clock.now end,findRemotes=function() return {server=remote,client={OnClientEvent=event}} end,
  onLoaded=function(msg) f.loaded=msg.progress end,onRest=function() error("bound client used legacy restore") end,onStatus=function() end,build=function() return f.owner.session.progress end,
  continuation={copy=Json.copy,validate=function(slot,record,retired)
   if type(record)~="table" then return false end
   if retired and record.save_retired then return #SaveRest.SPECS[slot].validate(record)==0 end
   if #SaveRest.check(slot,record,context)==0 then return true end
   local rules=record.life_rules;if type(rules)~="table" or rules.mode~=(if slot=="free" then "free" else "main") or slot=="easy" and rules.rules~="gentle" then return false end
   return __lifePrototype.prepare(record,context,"A1_46001")~=nil
  end,
  onRestore=function() if oldPeer then return true end;error("negotiated recovery restored the legacy observation") end},
  recovery=if not oldPeer then {onSelected=function(slot,serial)
   f.selected={request=client.bound.requests[slot],epoch=client.bound.epoch,mode=slot,serial=serial};return true
  end,onEntry=function(offer,epoch,_sequence)
  f.entries+=1
  local selection=f.selected
  if not selection or epoch~=client.bound.epoch or offer.epoch~=epoch or client.bound.requests[mode]~=selection.request or offer.serial~=selection.serial then return end
  local receipt=f.cache[offer.id]
  if not receipt then
   local commit,why=__entryClientPrototype.prepare(offer,context,function() return client.bound.epoch==selection.epoch and client.bound.requests[mode]==selection.request and selection.request.state=="readonly" end)
   check(commit~=nil,"wire entry preparation failed: "..tostring(why));receipt=assert(commit());f.applied+=1;f.cache[offer.id]=receipt
  end
  if f.hold then table.insert(f.acks,Json.copy(receipt)) else check(client:sendRecoveryApplied(receipt),"actual client refused current receipt") end
 end} else nil})
 f.client=client
 deliver=function(msg) listener(msg) end
 service:addPlayer(player);f.session=service.entries[player].session
 function f.pump()
  local before=b.requests;client:update();service:step()
  while #queue>0 do deliver(table.remove(queue,1)) end
  check(b.requests-before<=1,"service owner overlapped or batched storage work")
  check(not f.owner.busy and not f.owner.runtime.busy and not f.session.busy,"service owner retained a worker lock")
  clock.now+=1
 end
 function f.drive(done)
  for _=1,2500 do if done() then return end;f.pump() end
  error("service wire failed to settle: "..f.owner.runtime.phase.." "..tostring(f.owner.runtime.problem).." "..tostring(f.owner.problem))
 end
 return f
end
for _,mode in Rules.MODES do
 local f=fixture(mode,mode=="free");local b=f.b;local before=b.requests
 f.service:onMessage(f.player,{kind="recovery_applied",v=1,id="forged"})
 check(b.requests==before,"pre-handshake receipt reached storage")
 f.drive(function() return f.client:offerInfo(mode)~=nil and f.owner.runtime.phase=="offered" end)
 check(b.data.A1_46001_progress==nil and b.data["M1_46001_"..mode]==nil,"read-only service discovery published archive/proposal")
 local offer=f.client:offerInfo(mode);check(offer.protected and offer.playable,"actual client did not receive protected legacy offer")
 check(f.client:continueLife(mode,offer.id),"actual bound client did not select recovery Continue")
 check(f.applied==0,"legacy record was restored before current entry preparation")
 f.drive(function() return f.entries>=2 end)
 check(f.applied==1 and f.client:decision(mode).state=="readonly" and f.session.intents.requests[mode].credential==nil,"entry resend applied twice or granted before ACK")
 before=b.requests;local bad=Json.copy(f.acks[1]);bad.id="wrong-nonce";f.service:onMessage(f.player,bad)
 check(b.requests==before and f.session.intents.requests[mode].credential==nil,"wrong receipt reached storage or granted authority")
 f.clock.now+=5;f.hold=false
 if mode~="free" then check(f.client:sendRecoveryApplied(f.acks[1]),"actual client refused queued receipt") end -- Free ACK returns reentrantly from the next entry resend
 f.drive(function() local d=f.client:decision(mode);return d and d.state=="writable" end)
 local d=f.client:decision(mode);check(f.session.intents:authorized(mode,d.serial,d.credential,d.life) and f.owner.runtime.phase=="recovered","wire decision was not the actual server entry grant")
 check(f.applied==1 and f.world.life.recoveryHistory~=nil,"wire path did not apply exactly one current checkpoint: "..mode.." applied="..f.applied.." history="..tostring(f.world.life.recoveryHistory~=nil))
 local original={};for k,v in b.data do if string.sub(k,1,3)=="A1_" or string.sub(k,1,3)=="M1_" then original[k]=v end end;local kept=Json.canonical(original)
 local record=assert(Checkpoint.capture(f.world,f.clock.now));check(record.save_life==nil,"fixture should exercise server metadata stamping")
 check(f.client:sendRest(mode,record),"actual client did not queue recovered checkpoint")
 f.drive(function() local r=f.client.bound.requests[mode];return r.candidate and r.candidate.stored end)
 check(f.session.intents.requests[mode].storedSerial==1,"wire stored receipt did not follow verified current write")
 check(f.applied==1,"stored receipt replayed entry")
 if mode=="easy" then f.service:shutdown() else f.service:removePlayer(f.player) end
 check(f.session.closed and f.owner.runtime.phase=="closed" and b.data.P_46001.lock==nil,"service removal bypassed recovered closed departure")
 before=b.requests;f.service:onMessage(f.player,Json.copy(f.acks[1]));check(b.requests==before,"late removed-player receipt touched storage")
 local current={};for k,v in b.data do if string.sub(k,1,3)=="A1_" or string.sub(k,1,3)=="M1_" then current[k]=v end end
 check(Json.canonical(current)==kept,"wire saves/departure changed original archive/proposal")
 check(#f.errors==0,"service caught a hidden owner error: "..tostring(f.errors[1]))
end
for _,mode in Rules.MODES do
 local f=fixture(mode,false,true);f.drive(function() return f.client:connected() end)
 check(not f.client:recoveryReady() and f.owner.negotiated and not f.owner.recoveryEnabled,"older offer client negotiated recovery")
 for _=1,10 do f.pump() end
 check(f.owner.runtime.phase=="normal" and f.owner.runtime.discovery==nil and f.entries==0,"old peer started private recovery discovery")
 f.clock.now+=5;f.service:onMessage(f.player,{kind="hello",v=3,recovery=1})
 f.service:onMessage(f.player,{kind="life_intent",intent="continue",mode=mode,serial=1,offerId="unobserved"})
 check(not f.owner.recoveryEnabled and not f.owner.runtime.accepted,"later hello or intent upgraded an old peer")
 for k in f.b.data do check(string.sub(k,1,3)~="A1_" and string.sub(k,1,3)~="M1_","unnegotiated peer wrote recovery archive/proposal") end
 check(#f.errors==0,"old peer caught hidden owner error")
 f.service:removePlayer(f.player)
 check(f.session.closed and f.owner.runtime.phase=="closed","old peer departure did not close owner")
end
print("RECOVERY_SERVICE_OWNER passed="..count.." failed=0")
end
runServiceOwnerChecks()
end
