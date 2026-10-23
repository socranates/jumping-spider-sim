do
local function runProfileServiceChecks()
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Backend=require("../src/Server/DataStoreBackend")
local Service=require("../src/Server/SaveService")
local Client=require("../src/Client/SaveClient")
local Rules=require("../src/Shared/Data/SaveRules")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function fixture()
 local b=Memory.new();local profiles={}
 for _,mode in Rules.MODES do
  WorldMap.use("test_garden");local old=gardenWorld();old.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
  old.life.mode=if mode=="free" then "free" else "main";old.life.rules=if mode=="main" then "standard" else "gentle";old.needs.gentle=mode~="main"
  local record=assert(Checkpoint.capture(old,120));record.save_life="profile-wire-"..mode
  b:poke("R_46001_"..mode,codec:encode(Envelope.make(SaveRest.SPECS[mode],record,100,nil)))
  WorldMap.use("preserve");local context=newWorld();context.garden={}
  context.life.mode=old.life.mode;context.life.rules=old.life.rules;context.needs.gentle=mode~="main"
  profiles[mode]={context=context,template=assert(Checkpoint.capture(context,124))}
 end
 local gp=Json.copy(rawProgress.payload);gp.finished_main=true
 b:poke("P_46001",Envelope.make(Progress.SPEC,gp,100,nil))
 local ds={}
 function ds:GetAsync(key,opts)
  check(opts==nil or opts.UseCache==false,"profile service used cached verification read")
  local ok,value,why=b:read(key);if not ok then error(why) end;return value
 end
 function ds:UpdateAsync(key,fn) local ok,value,why=b:update(key,fn);if not ok then error(why) end;return value end
 local f={b=b,clock={now=200},queue={},errors={},entries=0,adoptions=0,receipts={},holdAck=true,profiles=profiles}
 local listener;local client
 local player={UserId=46001,Name="three-profile-wire"};f.player=player
 local service=Service.new({backend=Backend.new(ds,codec),now=function() return f.clock.now end,sleep=function(dt) f.clock.now+=dt end,
  spawn=function(fn,...) fn(...) end,jobId="three-profile-wire",
  log=function(why) if string.find(why,"raised:",1,true) or string.find(why,"send failed:",1,true) then table.insert(f.errors,why) end end,
  send=function(_,msg) table.insert(f.queue,Json.copy(msg)) end,
  ownerFactory=function(config,emit)
   local deps={codec=codec,rawBackend=__rawBackendPrototype.new(ds),currentFormat=__restFormatPrototype,entryFactory=__entryPrototype,saveFactory=__saveLoopPrototype,
    reader={work={now=function() return 0 end}},pipeline={reuseCompleteOriginal=true,work={now=function() return 0 end}},
    entryOptions={work={now=function() return 0 end}},saveOptions={work={now=function() return 0 end},progress={work={now=function() return 0 end}}}}
   f.owner=__profileOwnerPrototype.new(config,emit,deps,profiles);return f.owner
  end})
 f.service=service
 local remote={};function remote:FireServer(msg) service:onMessage(player,msg) end
 local event={};function event:Connect(fn) listener=fn;return {Disconnect=function() end} end
 client=Client.new({rules=Rules,now=function() return f.clock.now end,findRemotes=function() return {server=remote,client={OnClientEvent=event}} end,
  build=function() return f.owner.session.progress end,onLoaded=function() end,onStatus=function() end,onRest=function() error("profile protocol used legacy restore") end,
  continuation={copy=Json.copy,validate=function(mode,record)
   if type(record)~="table" then return false end
   if #SaveRest.check(mode,record,profiles[mode].context)==0 then return true end
   return __lifePrototype.prepare(record,profiles[mode].context,"A1_46001")~=nil
  end,onRestore=function() error("profile protocol restored legacy observation") end},
  recovery={onSelected=function(mode,serial)
   f.selected={mode=mode,serial=serial,request=client.bound.requests[mode],epoch=client.bound.epoch};return true
  end,onEntry=function(offer,epoch)
   f.entries+=1;local selected=f.selected
   if not selected or selected.mode~=offer.mode or selected.serial~=offer.serial or selected.epoch~=epoch or client.bound.requests[offer.mode]~=selected.request then return end
   local ack=f.receipts[offer.id]
   if not ack then
    local commit,why=__entryClientPrototype.prepare(offer,profiles[offer.mode].context,function()
     return client.bound.epoch==selected.epoch and client.bound.requests[offer.mode]==selected.request and selected.request.state=="readonly"
    end)
    assert(commit,why);ack=assert(commit());f.receipts[offer.id]=ack;f.adoptions+=1
   end
   f.ack=ack
   if not f.holdAck then check(client:sendRecoveryApplied(ack),"client refused current profile receipt") end
  end}})
 f.client=client;service:addPlayer(player);f.session=service.entries[player].session;f.scheduler=f.session.sched
 f.original={};for _,mode in Rules.MODES do f.original[mode]=Json.canonical(b.data["R_46001_"..mode]) end
 function f.pump()
  local before=b.requests;client:update();service:step()
  while #f.queue>0 do listener(table.remove(f.queue,1)) end
  check(b.requests-before<=1,"service profile visit overlapped requests")
  check(f.owner.session==f.session and service.entries[player].session==f.session and f.session.sched==f.scheduler,"service silently replaced session or quota")
  f.clock.now+=1
 end
 function f.drive(done)
  for _=1,2500 do if done() then return end;f.pump() end
  error("profile service did not settle: "..f.owner.runtime.phase.." "..tostring(f.owner.problem).." "..tostring(f.owner.runtime.problem))
 end
 f.drive(function()
  for _,mode in Rules.MODES do if not client:offerInfo(mode) then return false end end
  return next(f.owner.queue)==nil and f.owner.runtime.phase=="offered"
 end)
 return f
end
for _,mode in Rules.MODES do
 local f=fixture();local info=f.client:offerInfo(mode)
 check(info.protected and info.playable and f.client:recoveryReady(),"actual client did not receive three usable recovery offers")
 check(f.client:continueLife(mode,info.id),"actual client refused profile Continue")
 f.drive(function() return f.entries>=2 end)
 check(f.adoptions==1 and f.client:decision(mode).state=="readonly","resends applied twice or granted before receipt")
 f.holdAck=false;check(f.client:sendRecoveryApplied(f.ack),"actual client refused held receipt")
 f.drive(function() return f.client:decision(mode).state=="writable" end)
 local current=f.client:decision(mode)
 check(f.session.intents:authorized(mode,current.serial,current.credential,current.life),"profile client grant did not match actual server authority")
 local archives={};for key,value in f.b.data do if string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_" then archives[key]=value end end
 local archiveBytes=Json.canonical(archives)
 local record=assert(Checkpoint.capture(f.profiles[mode].context,f.clock.now))
 check(f.client:sendRest(mode,record),"actual client refused profile next rest")
 f.drive(function() local r=f.client.bound.requests[mode];return r.candidate and r.candidate.stored end)
 check(f.session.intents.requests[mode].storedSerial==1,"selected profile next rest lacked stored acknowledgement")
 for _,other in Rules.MODES do if other~=mode then check(Json.canonical(f.b.data["R_46001_"..other])==f.original[other],"actual service wrote another profile") end end
 f.service:removePlayer(f.player)
 check(f.session.closed and f.b.data.P_46001.lock==nil,"profile service departure did not release lease")
 local after={};for key,value in f.b.data do if string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_" then after[key]=value end end
 check(Json.canonical(after)==archiveBytes and #f.errors==0,"profile service changed originals/proposals or caught a hidden error")
 print("RECOVERY_PROFILE_SERVICE mode="..mode.." three_offers=true same_session=true apply_once=true actual_grant=true stored_ack=true other_slots_unchanged=true")
end
print("RECOVERY_PROFILE_SERVICE passed="..count.." failed=0")
end
runProfileServiceChecks()
end
