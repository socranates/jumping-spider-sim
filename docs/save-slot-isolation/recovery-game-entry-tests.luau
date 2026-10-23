do
local function runActualGameEntryChecks()
local Client=require("../src/Client/SaveClient")
local Service=require("../src/Server/SaveService")
local Backend=require("../src/Server/DataStoreBackend")
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Rules=require("../src/Shared/Data/SaveRules")
local Work=require("../src/Shared/Persistence/SaveWork")
local Mating=require("../src/Shared/Life/Mating")
local Mate=require("../src/Shared/Predator/Mate")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function archived(b)
 local records={}
 for k,v in b.data do if string.sub(k,1,3)=="A1_" or string.sub(k,1,3)=="M1_" then records[k]=v end end
 return assert(Json.canonical(records))
end
-- Observe the world's actual capture argument; do not construct an imitation of
-- SpiderClient's private checkpointWorld or replace any production adoption.
workspace:SetAttribute("World","preserve");WorldMap.use("preserve")
local actualWorld
local capture=Checkpoint.capture
Checkpoint.capture=function(world,...) actualWorld=world;return capture(world,...) end
-- Keep the game's lexical SaveClient and this visit's real transport identical.
-- The proxy swaps isolated visits in the harness only; it forwards both reads
-- and writes, including the activeSlot mutation performed by real adoption.
local createClient=Client.new;local activeSaveClient;local bootstrap
Client.new=function(cfg)
 bootstrap=createClient(cfg);activeSaveClient=bootstrap
 return setmetatable({}, {__index=function(_,k) return activeSaveClient[k] end,__newindex=function(_,k,v) activeSaveClient[k]=v end})
end
local loaded=require("../src/Client/SpiderClient.client")
Client.new=createClient
local d=assert(ClientStubs.driver);local frame=ClientStubs.renderSteps.SpiderSim
for _=1,2000 do frame(1/60);if actualWorld then break end end
Checkpoint.capture=capture
print("RECOVERY_ACTUAL_GAME startup capture="..tostring(actualWorld~=nil).." navigation="..tostring(d.navigation and d.navigation.status).." loading="..tostring(d.world.playerLoading).." motor="..d.motor.mode)
assert(actualWorld and actualWorld.life==d.life and actualWorld.motor==d.motor,"actual checkpoint capture world missing")
local function freshGame(mode)
 d.session.finishedMain=true
 assert(d.fresh(if mode=="free" then "free" else "main",mode=="easy",nil))
 for _=1,5 do frame(1/60) end
 d.life.clock.hour=12;d.needs.energy=.55
 d.openMenu(true)
end
local function fixture(mode,options)
 options=options or {}
 activeSaveClient=bootstrap
 freshGame(mode)
 WorldMap.use("test_garden");local old=gardenWorld();old.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
 old.life.mode=if mode=="free" then "free" else "main";old.life.rules=if mode=="main" then "standard" else "gentle";old.needs.gentle=mode~="main"
 if options.mainGentle then old.life.rules="gentle";old.needs.gentle=true end
 if options.stage then
  old.life.growth.stage=3;old.life.mating=Mating.new();old.life.mating.stage=options.stage;old.life.mate=Mate.new()
  if options.stage=="courted" then old.life.mate.state="pair";old.life.mate.scene=true;old.life.mate.meter=1 end
  if options.stage=="hatched" then old.life.mating.hatch_day=old.life.clock.day;old.life.mating.hatch_hour=7;old.life.mating.brood=3 end
 end
 local source=assert(Checkpoint.capture(old,120));source.save_life="actual-game-old-"..mode
 WorldMap.use("preserve")
 -- The server authors a pristine destination. A checkpoint captured after
 -- playing actual startup is correctly rejected as an already-played template.
 local context=newWorld();context.garden={}
 context.life.mode=old.life.mode;context.life.rules=old.life.rules;context.needs.gentle=mode~="main"
 local target=assert(Checkpoint.capture(context,124))
 local b=Memory.new();local gp=Json.copy(rawProgress.payload);gp.finished_main=true
 b:poke("P_46001",Envelope.make(Progress.SPEC,gp,100,nil));b:poke("R_46001_"..mode,codec:encode(Envelope.make(SaveRest.SPECS[mode],source,100,nil)))
 local original=Json.canonical(b.data["R_46001_"..mode])
 local ds={}
 function ds:GetAsync(key,opts) check(opts==nil or opts.UseCache==false,"actual-game path used a cached verification read");local ok,v,why=b:read(key);if not ok then error(why) end;return v end
 function ds:UpdateAsync(key,fn) local ok,v,why=b:update(key,fn);if not ok then error(why) end;return v end
 local clock={now=200};local packets={};local listener;local client;local adapter
 local f={b=b,clock=clock,entries=0,adoptions=0,acks=0,holdAck=true,appliedBeforeGrant=false,source=source,original=original,errors={}}
 local player={UserId=46001,Name="actual-game-entry-"..mode};f.player=player
 local service=Service.new({backend=Backend.new(ds,codec),now=function() return clock.now end,sleep=function(dt) clock.now+=dt end,spawn=function(fn,...) fn(...) end,jobId="actual-game-entry",
  log=function(why) if string.find(why,"raised:",1,true) or string.find(why,"send failed:",1,true) then table.insert(f.errors,why) end end,
  send=function(_,msg) table.insert(packets,Json.copy(msg)) end,
  ownerFactory=function(config,emit)
   local deps={codec=codec,rawBackend=__rawBackendPrototype.new(ds),template=target,context=context,currentFormat=__restFormatPrototype,
    entryFactory=__entryPrototype,saveFactory=__saveLoopPrototype,reader={work={now=function() return 0 end}},pipeline={reuseCompleteOriginal=true,work={now=function() return 0 end}},
    entryOptions={work={now=function() return 0 end}},saveOptions={work={now=function() return 0 end},progress={work={now=function() return 0 end}}}}
   f.owner=__serviceOwnerPrototype.new(config,emit,deps,mode);return f.owner
  end})
 f.service=service
 local remote={}
 function remote:FireServer(msg)
  if msg.kind=="recovery_applied" then
   f.acks+=1
   if f.holdAck then return end
  end
  service:onMessage(player,msg)
  if msg.kind=="recovery_applied" and options.reentrant and not f.reentering then
   f.reentering=true
   for _=1,200 do
    service:step()
    while #packets>0 do listener(table.remove(packets,1)) end
    clock.now+=1
    if adapter.job.phase=="granted" then break end
   end
   f.reentrantGrant=adapter.job.phase=="granted";f.reentering=false
   if options.loseSendResult then error("synthetic lost send result after actual grant") end
  end
 end
 local event={};function event:Connect(fn) listener=fn;return {Disconnect=function() end} end
 client=Client.new({rules=Rules,now=function() return clock.now end,findRemotes=function() return {server=remote,client={OnClientEvent=event}} end,
  onLoaded=function() end,onRest=function() error("actual game used a legacy restoration") end,onStatus=function() end,build=function() return f.owner.session.progress end,
  continuation={copy=Json.copy,validate=function(slot,record,retired)
   if type(record)~="table" then return false end
   if retired and record.save_retired then return #SaveRest.SPECS[slot].validate(record)==0 end
   if #SaveRest.check(slot,record,actualWorld)==0 then return true end
   return __lifePrototype.prepare(record,context,"A1_46001")~=nil
  end,onRestore=function() error("actual game restored a legacy observation") end,
  onDecision=function(decision) if adapter then adapter:decision(decision) end end},
  recovery={onSelected=function(slot,serial) return adapter:select(slot,serial) end,onEntry=function(offer,epoch,sequence)
   f.entries+=1;f.lastOffer=Json.copy(offer)
   if options.badScene then offer.entryKind="invalid-scene" end
   adapter:entry(offer,epoch,sequence)
  end}})
 local optionsClock=0
 activeSaveClient=client
 adapter=__gameEntryPrototype.new({client=function() return d.saveClient end,state=d.saveState,world=actualWorld,now=function() return clock.now end,maxSeconds=options.maxSeconds or 1200,
  workOptions=if options.cooperative then {now=function() optionsClock+=.0001;return optionsClock end,budget=.002,maxSeconds=1000,maxResumes=100000} else {now=function() return 0 end},
  prepareAdoption=function(record,stamp)
   if options.prepareProblem then return nil,"synthetic actual-adoption preparation refusal" end
   local commit,why=d.saveState.restore.cfg.prepare(record,stamp)
   if not commit then return nil,why end
   return function()
    f.adoptions+=1
    local ok,problem=commit()
    if options.afterAdopt then options.afterAdopt(f,adapter,client,d) end
    return ok,problem
   end
  end})
 f.client=client;f.adapter=adapter;service:addPlayer(player)
 function f.pump(dt)
  client:update();service:step()
  while #packets>0 do
   local msg=table.remove(packets,1)
   if options.delayGrant and msg.kind=="decision" and msg.decision.state=="writable" then f.delayedGrant=msg else listener(msg) end
  end
  adapter:update();frame(dt or 0);clock.now+=1
  local phase=tostring(adapter.job and adapter.job.phase).."/"..f.owner.runtime.phase
  if phase~=f.lastPhase then
   f.lastPhase=phase
   print("RECOVERY_ACTUAL_GAME phase="..phase.." now="..clock.now.." entries="..f.entries.." problem="..tostring(f.owner.runtime.problem).." adapter="..tostring(adapter.job and adapter.job.problem))
  end
 end
 function f.deliver(msg) listener(msg) end
 function f.drive(done)
  for _=1,2500 do
   if done() then return end
   if (adapter.job and adapter.job.phase=="held") or f.owner.runtime.phase=="held" then break end
   f.pump()
  end
  error("actual game entry did not settle: "..tostring(adapter.job and adapter.job.phase).."/"..f.owner.runtime.phase.."/"..tostring(adapter.job and adapter.job.problem).." server="..tostring(f.owner.runtime.problem).." owner="..tostring(f.owner.problem))
 end
 function f.choose()
  f.drive(function() return client:offerInfo(mode)~=nil and f.owner.runtime.phase=="offered" end)
  local offer=client:offerInfo(mode);assert(offer.protected)
  check(client:continueLife(mode,offer.id),"actual game protected choice refused")
  check(adapter.job.hold.held() and adapter.job.phase=="selected","actual choice did not acquire a pause")
 end
 function f.close()
  service:removePlayer(player)
  if adapter.job then adapter.job.hold.release() end -- diagnostic cleanup only, not a gameplay cancellation path
  d.menu:hide()
 end
 return f
end
for _,mode in Rules.MODES do for _,stage in {"rest","courted","hatched"} do
 local f=fixture(mode,{stage=if stage=="rest" then nil else stage,reentrant=mode=="free",loseSendResult=mode=="free"});f.choose();local gen=d.saveState.worldGeneration;local store=d.currentStore()
 f.drive(function() return f.adapter.job.phase=="applied" end)
 local j=f.adapter.job
 local archive=archived(f.b)
 check(f.adoptions==1 and d.saveState.worldGeneration==gen+1 and d.currentStore()~=store,"real adoption/generation/store missing: "..mode)
 check(d.session.mode==(if mode=="free" then "free" else "main") and d.session.rules==(if mode=="main" then "standard" else "gentle"),"real adopted mode/rules differ")
 check(d.saveClient.bound==f.client.bound and d.saveClient.activeSlot==mode and not d.saveState.broken,"game and adapter used different transport ownership")
 if stage~="rest" then check(d.life.mating.stage==stage,"actual scene progress was not restored") end
 check(f.owner.session.intents.requests[mode].credential==nil and j.hold.held(),"actual world resumed before authoritative server grant")
 local elapsed,energy,needs=d.life.elapsed,d.needs.energy,d.needs.elapsedS
 d.menu:hide();for _=1,60 do frame(1/60) end
 check(d.life.elapsed==elapsed and d.needs.elapsedS==needs and d.needs.energy==energy,"hidden-menu adopted world advanced")
 local ack=f.acks;f.drive(function() return f.acks>ack end)
 check(f.adoptions==1 and f.adapter.job.receipt==j.receipt and j.hold.held(),"entry retry reapplied or released the actual world")
 check(not f.adapter:decision({state="writable",mode=mode,kind="continue",serial=j.serial,offerId=j.offerId,revision=j.entry.revision+1,credential="invented",life=j.life}),"unprocessed caller grant released pause")
 f.holdAck=false;f.drive(function() return j.phase=="granted" end)
 check(f.owner.runtime.phase=="recovered" and not j.hold.held() and f.adoptions==1,"matching real server grant did not release current hold")
 if mode=="free" then check(f.reentrantGrant==true and j.problem==nil,"real reentrant grant was lost or overwritten by a lost send result") end
 for _=1,3 do frame(1/60) end
 if stage=="rest" then check(d.life.elapsed>elapsed and d.needs.elapsedS>needs,"real granted world did not resume")
 elseif stage=="courted" then check(d.mateLegs.couple.active==true,"real restored pair renderer did not take over after grant")
 else check(d.mateLegs.phase=="card" and d.caughtPanel:isShowing(),"real restored hatching card did not take over after grant") end
 check(#f.errors==0,"actual game transport caught an owner failure")
 print("RECOVERY_ACTUAL_GAME mode="..mode.." scene="..stage.." real_adoption=true generation_delta=1 applied_once=true menu_hidden_hold=true actual_server_grant=true")
 f.close()
 check(archived(f.b)==archive,"actual adoption/grant/departure changed original archive or proposal")
end end
-- Cooperative cancellation must not publish a prepared world or permit a late ACK.
do
 local f=fixture("main",{cooperative=true});f.choose()
 f.drive(function() return f.adapter.job.phase=="preparing" and f.adapter.job.work.resumes>=1 end)
 local j=f.adapter.job;local gen=d.saveState.worldGeneration;local store=d.currentStore();local at=d.motor.pos
 check(j.work.state=="pending","cooperative game preparation did not yield")
 f.adapter:cancel();for _=1,6 do f.pump(1/60) end
 check(f.adoptions==0 and d.currentStore()==store and d.saveState.worldGeneration==gen and d.motor.pos==at,"cancelled preparation changed actual world/store")
 check(j.phase=="held" and j.hold.held() and f.acks==0,"cancelled game entry released or acknowledged")
 f.close()
end
-- Invalid scene and failed preparation cannot change or acknowledge the world.
for _,options in {{badScene=true},{prepareProblem=true}} do
 local f=fixture("main",options);f.choose();local gen=d.saveState.worldGeneration;local store=d.currentStore()
 f.drive(function() return f.adapter.job.phase=="held" end)
 check(f.adoptions==0 and f.acks==0 and d.currentStore()==store and d.saveState.worldGeneration==gen and f.adapter.job.hold.held(),"refused game preparation changed or acknowledged state")
 f.close()
end
-- Reentrant new choice at the commit boundary invalidates the old receipt.
do
 local f=fixture("main",{afterAdopt=function(_,_,client) client:beginLife("free") end});f.choose()
 f.drive(function() return f.adapter.job.phase=="held" end)
 check(f.adoptions==1 and f.acks==0 and f.adapter.job.hold.held(),"reentrant new choice acknowledged or resumed the obsolete adoption")
 f.close()
end
-- Even a real old server grant must not release after a newer global choice.
do
 local f=fixture("main",{delayGrant=true});f.choose();f.drive(function() return f.adapter.job.phase=="applied" end)
 f.holdAck=false;f.drive(function() return f.delayedGrant~=nil end)
 local j=f.adapter.job;local elapsed=d.life.elapsed
 check(f.owner.runtime.phase=="recovered" and j.hold.held(),"delayed grant fixture did not hold before delivery")
 f.client:beginLife("free");f.deliver(f.delayedGrant);f.adapter:update()
 for _=1,30 do frame(1/60) end
 check(j.phase=="held" and j.hold.held() and d.life.elapsed==elapsed,"late authoritative grant resumed after a different choice")
 f.close()
end
-- An extra world generation change during adoption is not the permitted +1.
do
 local f=fixture("main",{afterAdopt=function(_,_,_,driver) driver.saveState.worldGeneration+=1 end});f.choose()
 f.drive(function() return f.adapter.job.phase=="held" end)
 check(f.adoptions==1 and f.acks==0 and f.adapter.job.hold.held(),"extra adoption generation escaped the fence")
 f.close()
end
-- Deadline failure before adoption keeps the original spider and remains held.
do
 local f=fixture("main",{maxSeconds=1});f.choose();local store=d.currentStore();f.clock.now+=2;f.adapter:update()
 check(f.adapter.job.phase=="held" and f.adoptions==0 and d.currentStore()==store and f.adapter.job.hold.held(),"selection timeout resumed or adopted")
 f.close()
end
-- A gentle Main life from before Easy had a key keeps Main authority. The real
-- game's transport view and its active local store must agree after adoption.
do
 local f=fixture("main",{mainGentle=true});f.choose()
 local easyStore=d.stores.easy;local easyBytes=assert(Json.canonical(easyStore.store.data))
 f.drive(function() return f.adapter.job.phase=="applied" end)
 local j=f.adapter.job;local archive=archived(f.b)
 check(d.session.rules=="gentle" and d.needs.gentle and f.client.activeSlot=="main" and d.currentStore()==d.stores.main,"legacy Main/gentle adopted a different physical slot or rules")
 f.holdAck=false;f.drive(function() return j.phase=="granted" end)
 local decision=f.client:decision("main")
 check(decision.state=="writable" and f.owner.session.intents:authorized("main",decision.serial,decision.credential,decision.life),"legacy gentle Main did not receive Main authority")
 local result=d.life.save()
 f.drive(function() return not result.pending end)
 check(result.ok and d.currentStore()==d.stores.main,"actual legacy Main rest was not kept locally in Main")
 f.drive(function() local r=f.client.bound.requests.main;return r.candidate and r.candidate.stored end)
 check(f.owner.session.intents.requests.main.storedSerial==1 and f.b.data.R_46001_easy==nil,"actual legacy Main rest was not acknowledged from its owning key")
 check(d.stores.easy==easyStore and Json.canonical(easyStore.store.data)==easyBytes,"actual legacy Main entry/rest changed the Easy store")
 f.close();check(archived(f.b)==archive,"legacy Main continuation changed immutable original archive/proposal")
 print("RECOVERY_ACTUAL_GAME legacy_main_gentle=true same_physical_slot=true actual_rest_stored=true easy_unchanged=true")
end
-- Deadline callback race: delivery happens before the next adapter update.
do
 local f=fixture("main",{delayGrant=true});f.choose();f.drive(function() return f.adapter.job.phase=="applied" end)
 f.holdAck=false;f.drive(function() return f.delayedGrant~=nil end)
 local j=f.adapter.job
 f.clock.now=j.born+f.adapter.maxSeconds
 f.deliver(f.delayedGrant)
 check(j.hold.held() and j.phase=="applied","late grant callback released before deadline update")
 f.adapter:update()
 check(j.phase=="held" and j.hold.held(),"expired actual adoption did not remain held")
 print("RECOVERY_ACTUAL_GAME deadline_callback_before_update_refused=true")
 f.close()
end
print("RECOVERY_ACTUAL_GAME passed="..count.." failed=0")
end
runActualGameEntryChecks()
end
