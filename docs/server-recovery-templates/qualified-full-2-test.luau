do
local function runServerTemplateRecoveryChecks()
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Backend=require("../src/Server/DataStoreBackend")
local Client=require("../src/Client/SaveClient")
local Rules=require("../src/Shared/Data/SaveRules")
local count=0
local Templates=require("../src/Server/RecoveryTemplates")
local Build=require("../src/Shared/World/WorldBuild")
WorldMap.use("preserve")
local authoredRoot=Instance.new("Folder");authoredRoot.Name="AuthoritativeRecoveryGeometry";authoredRoot.Parent=workspace
Build.region(assert(WorldMap.region(WorldMap.HOME)),authoredRoot)
local cache,problem=Templates.new(authoredRoot);assert(cache,problem)
local initialProfiles=assert(cache:profiles())
local authoredBytes={};for _,mode in Rules.MODES do authoredBytes[mode]=Json.canonical(initialProfiles[mode].template) end
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
   if options.initialFactoryFail and #f.owners==0 then error("synthetic initial factory failure") end
   if options.factoryFail and #f.owners>0 then error("synthetic replacement factory failure") end
   local prior=f.owner
   if prior then check(prior:replacementClosed(),"new owner constructed before exact old closure") end
   if not f.factoryPaused and (options.pauseFactory and prior or options.pauseInitialFactory and not prior) then
    f.factoryPaused=true;coroutine.yield("replacement-factory-paused")
   end
   local profiles=assert(cache:profiles())
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
 f.client=client;if not options.deferAdd then server:addPlayer(player) end
 function f.tick()
  client:update();server:step()
  while #f.queue>0 do listener(table.remove(f.queue,1)) end
  f.clock.now+=1
 end
 function f.drive(done)
  for _=1,2600 do if done() then return end;f.tick() end
  error("replacement did not settle: "..tostring(client.transition and client.transition.stage).."/"..f.owner.runtime.phase.."/"..tostring(f.owner.runtime.problem).." entry="..tostring(f.owner.runtime.entryJob and f.owner.runtime.entryJob.problem).." client="..tostring(client.replacementProblem))
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
 check(f.adoptions==1 and f.world.life.recoveryHistory~=nil and f.world.garden~=nil,"authored template did not enter actual recovered life")
 local record=assert(Checkpoint.capture(f.world,f.clock.now))
 check(f.client:sendRest(mode,record),"authored recovered life refused its next rest")
 f.drive(function() local r=f.client.bound.requests[mode];return r.candidate and r.candidate.stored end)
 check(f.owner.session.intents.requests[mode].storedSerial==1,"authored life lacked real stored acknowledgement")
 f.begin();f.drive(function() return f.client.transition==nil and #f.owners==2 end)
 check(nonP(f.b)==f.before and f.oldOwner:replacementClosed(),"authored profile replacement changed durable lives")
 local rows=assert(cache:profiles())
 for _,slot in Rules.MODES do check(Json.canonical(rows[slot].template)==authoredBytes[slot],"recovery/rest/replacement mutated cached authored template") end
 f.server:removePlayer(f.player)
 check(f.owner.session.closed,"authored fresh owner did not close")
 print("SERVER_TEMPLATE_RECOVERY mode="..mode.." authored_geometry=true actual_entry=true stored_rest=true replacement=true cache_unchanged=true")
end
cache:close();authoredRoot:Destroy()
print("SERVER_TEMPLATE_RECOVERY passed="..count.." failed=0")
end
runServerTemplateRecoveryChecks()
end
