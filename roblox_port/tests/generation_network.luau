-- Real client -> real SaveService/SaveSession -> MemoryBackend -> fresh owned
-- Continue. Shim transport/clock, not Roblox networking or a live DataStore.
local Layout=require("../src/Shared/Habitat/WindowsillLayout")
local Mating=require("../src/Shared/Life/Mating")
local Rules=require("../src/Shared/Data/SaveRules")
local Json=require("../src/Shared/Persistence/Json")
local MemoryBackend=require("../src/Shared/Persistence/MemoryBackend")
local SaveSession=require("../src/Shared/Persistence/SaveSession")
local SaveService=require("../src/Server/SaveService")
local awaitRest=require("./studio/AwaitRest")
local passed,failed=0,0
local function check(v,why) if v then passed+=1 else failed+=1;print("FAIL GENERATION_NETWORK "..why) end end
local pieces={}
for _,p in Layout.PIECES do table.insert(pieces,{name=p.id,lo=p.lo,hi=p.hi,profile=p.profile}) end
BoxWorld.folder("Windowsill",pieces)
workspace:SetAttribute("SaveWait",true)
local player=game:GetService("Players").LocalPlayer
local backend=MemoryBackend.new()
local now=100000
local outgoing,incoming,handlers={},{},{}
local sent={}
local folder=Instance.new("Folder");folder.Name=Rules.REMOTES_NAME
local toServer=Instance.new("Folder");toServer.Name="ToServer"
rawset(toServer,"FireServer",function(_,msg) table.insert(outgoing,Json.copy(msg));table.insert(sent,Json.copy(msg)) end)
toServer.Parent=folder
local toClient=Instance.new("Folder");toClient.Name="ToClient"
rawset(toClient,"OnClientEvent",{Connect=function(_,fn) table.insert(handlers,fn) end})
toClient.Parent=folder;folder.Parent=game:GetService("ReplicatedStorage")
local service=SaveService.new({backend=backend,now=function() return now end,sleep=function(dt) now+=dt end,
 spawn=function(fn,...) fn(...) end,send=function(_,msg) table.insert(incoming,Json.copy(msg)) end,jobId="generation-fixture"})
service:addPlayer(player)
assert(pcall(function() require("../src/Client/SpiderClient.client") end),"client failed to load")
local d=assert(ClientStubs.driver)
local frame=ClientStubs.renderSteps.SpiderSim
d.saveClient.cfg.now=function() return now end
local workClock=0
d.saveState.rest.cfg.workOptions={budget=.001,maxSeconds=1000,now=function() workClock+=.0001;return workClock end}
local function pump()
 now+=.25
 local messages=outgoing;outgoing={}
 for _,msg in messages do service:onMessage(player,msg) end
 service:step()
 local replies=incoming;incoming={}
 for _,msg in replies do for _,fn in handlers do fn(msg) end end
 frame(0)
end
local function untilReady(fn,why)
 for _=1,10000 do if fn() then return end;pump() end
 error("fixture timed out: "..why)
end
untilReady(function() return d.saveClient.phase=="ready" and not d.saveClient:offerPending() end,"initial ownership negotiation")
for _=1,120 do frame(1/60) end -- establish the client's initial attached snapshot
assert(d.fresh("main",false,nil),"fresh fixture refused")
untilReady(function() local r=d.saveClient.bound.requests.main;return r and r.state=="writable" end,"owned new life")
d.place(Vector3.new(-25.5,.31,6));for _=1,6 do frame(1/60) end
local life=d.life
life.clock.day,life.clock.hour=6,7;life.growth.stage=life.growth:adultStage();d.needs.energy=.8
life.mating=Mating.normalize({stage="guarding",sac_day=4,guard_day=2,mates=1})
assert(awaitRest(life:makeCheckpoint(),pump).ok)
local owner=service.entries[player].session
untilReady(function() return owner.rests.main~=nil and d.saveClient:status()=="saved" end,"parent checkpoint stored")
local parent=assert(Json.canonical(owner.rests.main))
life.mating=Mating.normalize({stage="hatched",sac_day=4,guard_day=2,hatch_day=6,hatch_hour=7,brood=9,mates=1})
for _=1,3 do frame(1/60) end
d.caughtPanel:update(10);assert(d.caughtPanel:choose("Carry"),"Carry fixture refused")
local seed=life.growth.lifeSeed
local birth=assert(d.saveState.birth).result
check(birth.pending and Json.canonical(owner.rests.main)==parent,"server still has parent while newborn baseline prepares")
check(d.saveClient:status()=="saving","pending generation cannot claim online durability")
assert(awaitRest(birth,pump).ok)
untilReady(function() return owner.rests.main and owner.rests.main.checkpoint_origin=="generation_start" and d.saveClient:status()=="saved" end,"newborn stored with acknowledgement")
local rests=0
for _,msg in sent do if msg.kind=="rest" and msg.record.checkpoint_origin=="generation_start" then
 rests+=1
 check(msg.serial~=nil and msg.credential~=nil and msg.restSerial~=nil,"automatic generation save uses the existing owned request credential")
end end
check(rests>=1 and owner.rests.main.checkpoint_origin=="generation_start","automatic birth reaches the actual server storage path")
service:removePlayer(player)
check(owner.closed,"departing visit flushes and closes before rejoin")
local nextVisit=SaveSession.new({backend=backend,userId=player.UserId,sessionId="generation-rejoin",now=function() return now end,sleep=function(dt) now+=dt end})
check(nextVisit:load()=="active","fresh visit takes the released lease")
nextVisit:enableOffers()
for _=1,4 do now+=1;nextVisit:step() end
local offer=assert(nextVisit:offer("main"),"rejoin offer missing")
check(offer.record and offer.record.checkpoint_origin=="generation_start","fresh visit offers newborn rather than parent")
assert(nextVisit:requestLife("continue","main",1,offer.id))
for _=1,3 do now+=1;nextVisit:step() end
local choice=assert(nextVisit.intents.requests.main)
check(choice.state=="writable" and choice.credential~=nil,"new visit Continue independently earns its own authority")
local record=nextVisit.rests.main
local graph=record.world.objects[record.world.roots.life["$o"]]
local generation,growthRef,matingRef
for _,e in graph.e do if e[1]=="generation" then generation=e[2] elseif e[1]=="growth" then growthRef=e[2] elseif e[1]=="mating" then matingRef=e[2] end end
local foundSeed,stage
for _,e in record.world.objects[growthRef["$o"]].e do if e[1]=="lifeSeed" then foundSeed=e[2] end end
for _,e in record.world.objects[matingRef["$o"]].e do if e[1]=="stage" then stage=e[2] end end
check(generation==1 and foundSeed==seed and stage=="none","fresh Continue round trip retains exact child seed and generation without another hatch")
nextVisit:flush(now+20)
print(`GENERATION_NETWORK passed={passed} failed={failed}`)
assert(failed==0,"generation network failures")
