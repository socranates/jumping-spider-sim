do
local function runReplacementChecks()
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Backend=require("../src/Server/DataStoreBackend")
local Client=require("../src/Client/SaveClient")
local Rules=require("../src/Shared/Data/SaveRules")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function nonP(b)
 local out={};for key,value in b.data do if key~="P_46001" then out[key]=value end end
 return Json.canonical(out)
end
local function fixture(options)
 options=options or {}
 local f={b=Memory.new(),clock={now=200},queue={},sent={},received={},owners={},errors={},logs={},requestTimes={},paused=false,pauses=0,menus=0,adoptions=0,cache={},drops=options.drops or {}}
 local player={UserId=46001,Name="replacement-wire"};f.player=player
 for _,mode in Rules.MODES do
  WorldMap.use("test_garden");local old=gardenWorld();old.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
  old.life.mode=if mode=="free" then "free" else "main";old.life.rules=if mode=="main" then "standard" else "gentle";old.needs.gentle=mode~="main"
  local record=assert(Checkpoint.capture(old,120));record.save_life="replacement-old-"..mode
  f.b:poke("R_46001_"..mode,codec:encode(Envelope.make(SaveRest.SPECS[mode],record,100,nil)))
 end
 WorldMap.use("preserve")
 f.progress=Json.copy(rawProgress.payload);f.progress.finished_main=true
 f.b:poke("P_46001",Envelope.make(Progress.SPEC,f.progress,100,nil))
 local ds={}
 local function requested()
  local now=f.clock.now;local recent={}
  for _,time in f.requestTimes do if now-time<60 then table.insert(recent,time) end end
  table.insert(recent,now);f.requestTimes=recent
  local t=f.server and f.server.transitions[player]
  local departing=false
  for _,owner in f.owners do if owner.runtime.leaving and owner.session.flushing then departing=true end end
  check(#recent<=Rules.REQUESTS_PER_MINUTE or t and t.stage=="closing" or departing,"replacement reset its rolling ordinary request allowance")
 end
 function ds:GetAsync(key,opts)
  requested()
  check(opts==nil or opts.UseCache==false,"replacement used a cached verification read")
  local ok,value,why=f.b:read(key);if not ok then error(why) end;return value
 end
 function ds:UpdateAsync(key,fn)
  local t=f.server and f.server.transitions[player]
  if f.pauseClose and t and t.stage=="closing" and key=="P_46001" then
   f.pauseClose=false;coroutine.yield("replacement-close-paused")
  end
  requested()
  local ok,value,why=f.b:update(key,fn);if not ok then error(why) end;return value
 end
 local server=__replacementService.new({backend=Backend.new(ds,codec),now=function() return f.clock.now end,sleep=function(dt)
   f.clock.now+=dt
   if f.resumeClose and coroutine.status(f.resumeClose)=="suspended" then local ok,why=coroutine.resume(f.resumeClose);assert(ok,why) end
  end,
  spawn=function(fn,...) fn(...) end,jobId="replacement-wire",
  keyOf=function()
   f.keyLookups=(f.keyLookups or 0)+1
   return if options.changingKey and f.keyLookups>1 then 46002 else 46001
  end,
  log=function(why)
   table.insert(f.logs,why)
   if string.find(why,"raised:",1,true) or string.find(why,"send failed:",1,true) then table.insert(f.errors,why) end
  end,
  send=function(_,message)
   table.insert(f.received,Json.copy(message))
   local key=if message.kind=="loaded" and message.replaced then "new_loaded" else message.kind
   if (f.drops[key] or 0)>0 then f.drops[key]-=1;return end
   table.insert(f.queue,Json.copy(message))
  end,
  ownerFactory=function(config,emit)
   if options.factoryFail and #f.owners>0 then error("synthetic replacement factory failure") end
   local prior=f.owner
   if prior then check(prior:replacementClosed(),"new owner constructed before exact old closure") end
   if options.pauseFactory and prior and not f.factoryPaused then f.factoryPaused=true;coroutine.yield("replacement-factory-paused") end
   local profiles={}
   for _,mode in Rules.MODES do
    local context=newWorld();context.garden={};context.life.mode=if mode=="free" then "free" else "main"
    context.life.rules=if mode=="main" then "standard" else "gentle";context.needs.gentle=mode~="main"
    profiles[mode]={context=context,template=assert(Checkpoint.capture(context,124))}
   end
   local deps={codec=codec,rawBackend=__rawBackendPrototype.new(ds),currentFormat=__restFormatPrototype,entryFactory=__entryPrototype,saveFactory=__saveLoopPrototype,
    reader={work={now=function() return 0 end}},pipeline={reuseCompleteOriginal=true,work={now=function() return 0 end}},
    entryOptions={work={now=function() return 0 end}},saveOptions={work={now=function() return 0 end},progress={work={now=function() return 0 end}}}}
   f.owner=__replacementOwner.new(config,emit,deps,profiles);table.insert(f.owners,f.owner);return f.owner
  end})
 f.server=server
 local client;local listener
 local remote={};function remote:FireServer(message)
  table.insert(f.sent,Json.copy(message))
  if (f.drops[message.kind] or 0)>0 then f.drops[message.kind]-=1;return end
  server:onMessage(player,Json.copy(message))
 end
 local event={};function event:Connect(fn) listener=fn;return {Disconnect=function() end} end
 local cfg={rules=Rules,now=function() return f.clock.now end,findRemotes=function() return {server=remote,client={OnClientEvent=event}} end,
  build=function()
   local snapshot=Json.copy(f.progress)
   if f.pauseBuild then f.pauseBuild=false;coroutine.yield("replacement-build-paused") end
   return snapshot
  end,
  onLoaded=function(msg) if msg.progress then f.progress=Json.copy(msg.progress) end end,
  onStatus=function() end,onRest=function() error("replacement used legacy restore") end,
  continuation={copy=Json.copy,validate=function(mode,record)
   if type(record)~="table" then return false end
   local context=f.owner.profiles[mode].context
   return #SaveRest.check(mode,record,context)==0 or __lifePrototype.prepare(record,context,"A1_46001")~=nil
  end,onRestore=function() error("replacement restored original instead of current entry") end},
  recovery={onSelected=function(mode,serial)
   f.selection={mode=mode,serial=serial,epoch=client.bound.epoch,request=client.bound.requests[mode]}
   f.world=newWorld();f.world.garden={};f.world.life.mode=if mode=="free" then "free" else "main"
   f.world.life.rules=if mode=="main" then "standard" else "gentle";f.world.needs.gentle=mode~="main"
   return true
  end,onEntry=function(offer,epoch)
   local selected=f.selection
   if not selected or selected.epoch~=epoch or client.bound.epoch~=epoch or client.bound.requests[offer.mode]~=selected.request then return end
   local ack=f.cache[offer.id]
   if not ack then
    local commit,why=__entryClientPrototype.prepare(offer,f.world,function()
     return client.bound.epoch==selected.epoch and client.bound.requests[offer.mode]==selected.request and selected.request.state=="readonly"
    end);assert(commit,why);ack=assert(commit());f.cache[offer.id]=ack;f.adoptions+=1
   end
   f.lastAck=ack
   if not f.holdRecoveryAck then check(client:sendRecoveryApplied(ack),"current entry receipt refused") end
  end}}
 if options.oldPeer then client=Client.new(cfg)
 else client=__replacementClient.new(cfg,{onPause=function()
  f.pauses+=1;f.paused=true;f.selection=nil;f.cache={}
  return not options.pauseFail
 end,onReady=function(oldEpoch,newEpoch)
  check(f.paused and oldEpoch~=newEpoch,"application activated an old epoch or unpaused world")
  if options.readyFail then return false end
  f.menus+=1;f.paused=false;return true
 end}) end
 f.client=client;server:addPlayer(player)
 function f.tick()
  client:update();server:step()
  while #f.queue>0 do listener(table.remove(f.queue,1)) end
  f.clock.now+=1
 end
 function f.drive(done)
  for _=1,2600 do if done() then return end;f.tick() end
  error("replacement did not settle: "..tostring(client.transition and client.transition.stage).."/"..f.owner.runtime.phase.."/"..tostring(f.owner.runtime.problem))
 end
 function f.offers()
  f.drive(function()
   for _,mode in Rules.MODES do if not client:offerInfo(mode) then return false end end
   return f.owner.runtime.phase=="offered" and next(f.owner.queue)==nil
  end)
 end
 function f.recover(mode)
  f.offers();assert(client:continueLife(mode,client:offerInfo(mode).id))
  f.drive(function() local decision=client:decision(mode);return decision and decision.state=="writable" end)
 end
 function f.begin()
  table.insert(f.progress.notebook.opened,"replacement_final_note")
  f.before=nonP(f.b);f.oldOwner=f.owner;f.oldEpoch=client.bound.epoch;f.oldBound=client.bound
  check(client:requestReplacement(),"negotiated application replacement refused")
 end
 return f
end
for _,mode in Rules.MODES do
 local f=fixture();f.recover(mode)
 local record=assert(Checkpoint.capture(f.world,f.clock.now))
 local pending=assert(f.client.bound:prepareCheckpoint(mode,record))
 local oldAck=Json.copy(f.lastAck);local oldGrant
 for _,message in f.received do if message.kind=="decision" and message.decision.state=="writable" then oldGrant=Json.copy(message) end end
 f.begin()
 check(not pending() and not f.client:sendRecoveryApplied(oldAck) and not f.client:continueLife(mode,"old"),"old work survived local quiescence")
 f.drive(function() return f.client.transition==nil and #f.owners==2 end)
 check(f.client.bound.epoch~=f.oldEpoch and f.client.bound~=f.oldBound and f.oldOwner:replacementClosed(),"fresh epoch did not follow verified closure")
 check(f.pauses==1 and f.menus==1 and not f.paused and f.client.bound.serial==0,"fresh menu was skipped, repeated or automatically selected a life")
 check(nonP(f.b)==f.before and table.find(f.b.data.P_46001.payload.notebook.opened,"replacement_final_note")~=nil,"transition lost final progress or changed rests/originals")
 local before=f.b.requests
 f.server:onMessage(f.player,{kind="progress",epoch=f.oldEpoch,progress=Progress.default()})
 f.server:onMessage(f.player,{kind="life_intent",epoch=f.oldEpoch,intent="new",mode=mode,serial=1})
 f.server:onMessage(f.player,oldAck);f.client:receiveOwned(oldGrant)
 check(f.b.requests==before and f.client:decision(mode)==nil and f.client.bound.epoch~=f.oldEpoch,"late old-epoch traffic gained authority")
 check(#f.errors==0,"replacement caught hidden service error: "..tostring(f.errors[1]))
 print("SESSION_REPLACEMENT mode="..mode.." old_closed=true fresh_epoch=true no_auto_choice=true final_progress=true originals_unchanged=true late_old_refused=true")
end
-- Lost control packets, including the new loaded reply, are idempotent. Only
-- one old flush and one new owner are created despite all retries.
do
 local f=fixture({drops={session_replace_request=1,session_replace_offer=1,session_replace_ack=1,session_replace_commit=1,session_replace_ready=1,new_loaded=1}})
 f.recover("main");f.begin();f.drive(function() return f.client.transition==nil and #f.owners==2 end)
 check(f.pauses==1 and f.menus==1 and #f.owners==2 and nonP(f.b)==f.before,"lost packets repeated application/owner or changed immutable data")
end
-- Forged ACKs/ready, malformed shapes and an old hello cannot bypass closure.
do
 local f=fixture();f.recover("main");f.begin();f.tick()
 local t=f.server.transitions[f.player];check(t and t.stage=="offered","fixture did not reach replacement offer")
 local before=f.b.requests
 f.server:onMessage(f.player,{kind="session_replace_ack",v=1,epoch=t.epoch,serial=t.serial,id="wrong"})
 f.server:onMessage(f.player,{kind="session_replace_ready",v=1,epoch=t.epoch,serial=t.serial,id=t.id})
 f.server:onMessage(f.player,{kind="session_replace_ack",v=1,epoch=t.epoch,serial=t.serial,id=t.id,unexpected=true})
 check(f.b.requests==before and #f.owners==1 and not f.owner.session.closed,"unverified control packet closed/replaced owner")
 f.drive(function() return f.client.transition.stage=="awaiting_loaded" end)
 local oldBound=f.client.bound
 f.client:receiveOwned({kind="loaded",v=Rules.OFFER_PROTOCOL,recovery=1,replacement=1,epoch="forged-new",sequence=1,
  replaced={epoch=t.epoch,serial=t.serial,id="wrong"},progress=Progress.default()})
 check(f.client.bound==oldBound and f.menus==0,"unmatched new handshake reset client state")
 f.drive(function() return f.client.transition==nil end)
end
-- A suspended old progress build must never be restamped with the new epoch.
do
 local f=fixture();f.recover("main");f.pauseBuild=true;f.client:markDirty()
 local co=coroutine.create(function() f.client:update() end)
 local ok,why=coroutine.resume(co);assert(ok,why);check(why=="replacement-build-paused","actual client progress build did not yield")
 f.begin();f.drive(function() return f.client.transition==nil end)
 local sent=#f.sent;ok,why=coroutine.resume(co);assert(ok,why)
 check(#f.sent==sent and nonP(f.b)==f.before,"late old update emitted under the new epoch")
end
do
 local f=fixture({pauseFail=true});f.recover("main");local before=#f.sent
 check(not f.client:requestReplacement() and f.client.transition.stage=="failed","failed application pause was acknowledged")
 for _=1,6 do f.tick() end
 check(#f.sent==before and #f.owners==1 and f.server.transitions[f.player]==nil,"failed local pause contacted or replaced server owner")
end
do
 local f=fixture();f.recover("main");f.begin();f.tick()
 f.b:fail({op="update",key="P_46001",times=30,message="503: departure unavailable"})
 f.drive(function() return f.client.transition and f.client.transition.stage=="failed" end)
 check(#f.owners==1 and nonP(f.b)==f.before and f.client.bound.epoch==f.oldEpoch,"failed departure installed a new owner or claimed rollback")
end
-- Removal while the actual closing UpdateAsync is suspended cannot start a new
-- visit. The base service's one departure counter drains when the call returns.
do
 local f=fixture();f.recover("main");f.begin();f.tick();f.pauseClose=true
 local co=coroutine.create(function() f.client:update() end)
 local ok,why=coroutine.resume(co);assert(ok,why);check(why=="replacement-close-paused","actual departure update did not suspend")
 check(f.server.base.departing==1 and f.server.base.entries[f.player]==nil,"closing owner was not removed/counting exactly once")
 f.server:removePlayer(f.player)
 ok,why=coroutine.resume(co);assert(ok,why)
 check(f.server.base.departing==0 and #f.owners==1 and f.server.base.entries[f.player]==nil and nonP(f.b)==f.before,"late close reopened a removed player")
end
do
 local f=fixture({oldPeer=true});f.recover("main")
 check(not f.server.peers[f.player].enabled,"old peer negotiated replacement")
 local oldEpoch=f.client.bound.epoch;local before=f.b.requests
 f.server:onMessage(f.player,{kind="hello",v=Rules.OFFER_PROTOCOL,recovery=1,replacement=1})
 f.server:onMessage(f.player,{kind="session_replace_request",v=1,epoch=oldEpoch,serial=1,progress=f.progress})
 check(not f.server.peers[f.player].enabled and #f.owners==1 and f.b.requests==before,"later hello upgraded old peer or began replacement")
end
-- The same visit can replace twice. Original archive ownership and monotonically
-- increasing transition serials survive a later import from another slot.
do
 local f=fixture();f.recover("main");f.begin();f.drive(function() return f.client.transition==nil end)
 local firstEpoch=f.client.bound.epoch
 f.recover("free");f.begin();f.drive(function() return f.client.transition==nil end)
 check(#f.owners==3 and f.client.bound.epoch~=firstEpoch and f.client.replacementSerial==2 and f.pauses==2 and f.menus==2,"second replacement reused a session/nonce or lost menu state")
 check(nonP(f.b)==f.before and f.owners[1]:replacementClosed() and f.owners[2]:replacementClosed(),"second replacement changed durable lives or overlapped owners")
end
do
 local f=fixture({readyFail=true});f.recover("main");f.begin()
 f.drive(function() return f.client.transition and f.client.transition.stage=="failed" end)
 check(f.paused and f.menus==0 and #f.owners==2 and next(f.client.bound.requests)==nil,"failed fresh-menu acknowledgement resumed gameplay")
end
do
 local f=fixture({drops={session_replace_ack=100}});f.recover("main");f.begin()
 f.drive(function() return f.client.transition and f.client.transition.stage=="failed" end)
 check(#f.owners==1 and f.paused and not f.oldOwner.session.closed and nonP(f.b)==f.before,"lost ACK timeout replaced or resumed old owner")
 check(f.clock.now-f.b.data.P_46001.lock.beat<Rules.LOCK_STALE,"awaiting ACK abandoned its lease")
 f.server:removePlayer(f.player)
 check(f.oldOwner:replacementClosed() and table.find(f.b.data.P_46001.payload.notebook.opened,"replacement_final_note")~=nil,"timed-out transition lost final progress on departure")
end
do
 local f=fixture();f.recover("main");f.begin();f.tick();f.pauseClose=true
 local co=coroutine.create(function() f.client:update() end)
 local ok,why=coroutine.resume(co);assert(ok,why);check(why=="replacement-close-paused","shutdown fixture did not suspend closure")
 f.resumeClose=co;f.server:shutdown()
 check(f.server.base.departing==0 and f.server.base.closing and #f.owners==1 and f.oldOwner:replacementClosed(),
  "shutdown did not drain exactly one replacement departure: "..f.oldOwner.runtime.phase.." "..tostring(Json.canonical(f.oldOwner.runtime.result)))
end
do
 local f=fixture({factoryFail=true});f.recover("main");f.begin()
 f.drive(function() return f.client.transition and f.client.transition.stage=="failed" end)
 check(f.paused and #f.owners==1 and f.oldOwner:replacementClosed() and f.server.base.entries[f.player]==nil and nonP(f.b)==f.before,"failed fresh factory escaped safe closed state")
end
do
 local f=fixture({pauseFactory=true});f.recover("main");f.begin()
 f.drive(function() return f.client.transition.stage=="awaiting_loaded" end)
 f.clock.now+=61 -- clear inherited quota debt so this coroutine reaches the factory
 local co=coroutine.create(function() f.client:update() end)
 local ok,why=coroutine.resume(co);assert(ok,why);check(why=="replacement-factory-paused","replacement factory did not suspend")
 local before=f.b.requests;f.server:removePlayer(f.player)
 ok,why=coroutine.resume(co);assert(ok,why)
 check(f.server.base.entries[f.player]==nil and f.server.transitions[f.player]==nil and f.b.requests==before and #f.owners==2,
  "late constructor acquired a lease or revived a removed player")
 check(f.owners[2].session.closed and f.owners[2].session.counters.requests==0,"cancelled unloaded owner was not discarded")
end
do
 local f=fixture({changingKey=true});f.recover("main");f.begin();f.drive(function() return f.client.transition==nil end)
 check(f.keyLookups==1 and tostring(f.owner.session.cfg.userId)=="46001" and f.b.data.P_46002==nil,"replacement re-evaluated physical account key")
end
print("SESSION_REPLACEMENT passed="..count.." failed=0")
end
runReplacementChecks()
end
