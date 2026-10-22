local Life=require("../src/Shared/Life/LifeLoop")
local Needs=require("../src/Shared/Life/NeedsModel")
local Store=require("../src/Shared/Persistence/CheckpointStore")
local Json=require("../src/Shared/Persistence/Json")
local Client=require("../src/Client/SaveClient")
local Rules=require("../src/Shared/Data/SaveRules")
local Work=require("../src/Shared/Persistence/SaveWork")
local passed,failed=0,0
local function check(ok,why) if ok then passed+=1 else failed+=1;print("FAIL LOCAL_REST "..why) end end
local life=Life.new(Needs.new(true,false))
life.morningText="Morning, day 2."
local first={ok=false,pending=true,message=""}
life.save=function() return first end
life:makeCheckpoint()
check(life.checkpoints==0 and life.checkpointResult==first and #life:drainEvents()==0,"pending is neither kept nor a failed checkpoint event")
check(life.morningText=="" and first.morning=="Morning, day 2.","pending rest retains its own morning message")
local second=life:beginCheckpoint({ok=false,pending=true,message=""})
check(first.cancelled and not first.pending and life._checkpointPending==second,"new pending rest cancels only its predecessor")
check(not life:finishCheckpoint(first,{ok=true,message="obsolete"}) and life.checkpoints==0,"late completion cannot claim a superseded rest")
check(life:finishCheckpoint(second,{ok=true,message="Last rest kept."}) and life.checkpoints==1 and second.ok and not second.pending,"actual completion publishes the mutable result once")
check(not life:finishCheckpoint(second,{ok=true,message="again"}) and #life:drainEvents()==1,"repeated completion cannot increment or announce twice")
local third=life:beginCheckpoint({ok=false,pending=true,message=""})
check(life:finishCheckpoint(third,{ok=false,message="synthetic failure"}) and life.checkpoints==1 and string.find(life.notice,"not kept",1,true),"failed preparation reports failure without claiming a rest")
local fourth=life:beginCheckpoint({ok=false,pending=true,message=""})
check(not life:cancelCheckpoint(third) and life._checkpointPending==fourth,"old cancellation cannot erase a new pending token")
check(life:cancelCheckpoint(fourth) and fourth.cancelled and life.checkpointResult==nil,"explicit cancellation finalizes the result without a success notice")

local memory=Store.MemoryDataStore.new()
local unlock=life:beginCheckpoint({ok=false,pending=true,message=""})
life:showNotice("You can now run.")
local noticeSeconds=life.noticeSeconds
assert(life:finishCheckpoint(unlock,{ok=true,message="Last rest kept."}))
check(life.notice=="You can now run." and life.noticeSeconds==noticeSeconds,"delayed success preserves a newer ability notice and its duration")
check(unlock.noticeRevision==nil and life.checkpoints==2,"completion clears private notice tracking and counts once")
local bad=life:beginCheckpoint({ok=false,pending=true,message=""})
life:showNotice("The new skin has hardened.")
assert(life:finishCheckpoint(bad,{ok=false,message="synthetic failure"}))
check(string.find(life.notice,"new skin",1,true) and string.find(life.notice,"not kept",1,true),"delayed failure remains visible alongside the newer gameplay notice")
local base=Store.new(memory,function() return {} end)
assert(base:save({value=1}).ok);assert(base:save({value=2}).ok)
memory:SetAsync("checkpoint.aside.1",{preserve={version=99}})
local original=assert(Json.canonical(memory.data));local revision=memory.revision
local fork=base:forkMemory()
check(fork.store~=memory and fork.store.data~=memory.data and fork.store.data.checkpoint==memory.data.checkpoint,"memory fork shares only store-owned immutable entries")
local removed=fork.store:RemoveAsync("checkpoint.aside.1");removed.preserve.version=0
check(memory.data["checkpoint.aside.1"].preserve.version==99,"remove returns a defensive copy across forks")
local got=fork.store:GetAsync("checkpoint");got.checkpoint.value=900
check(memory.data.checkpoint.checkpoint.value==2,"read cannot mutate shared stored values")
assert(fork:save({value=3}).ok)
check(Json.canonical(memory.data)==original and memory.revision==revision,"private writes and cleanup leave source contents and revision intact")
check(fork.store.data.checkpoint.checkpoint.value==3 and fork.store.data["checkpoint.bak"].checkpoint.value==2,"new rest keeps previous valid rest as backup")
local nextFork=fork:forkMemory();assert(nextFork:save({value=4}).ok)
check(fork.store.data.checkpoint.checkpoint.value==3 and nextFork.store.data["checkpoint.bak"].checkpoint.value==3,"successive forks retain independent current/backup values")
memory:RemoveAsync("absent");check(memory.revision>revision,"removal participates in source mutation fencing")

local client=Client.new({rules=Rules,now=function() return 0 end,findRemotes=function() return nil end,build=function() return {} end,
 onLoaded=function() end,onRest=function() end,onStatus=function() end,
 continuation={copy=Json.copy,validate=function(_,r) return type(r)=="table" and Json.canonical(r)~=nil end}})
local seq=0
local function receive(msg) seq+=1;msg.epoch="local-rest";msg.sequence=seq;if msg.kind=="loaded" then msg.v=3 end;Client.receive(client,msg) end
receive({kind="loaded",status="saved",offers={main={id="a",protected=false,record={value=1}}}})
assert(client:continueLife("main","a"));local r=client.bound.requests.main
receive({kind="decision",decision={mode="main",kind="continue",serial=r.serial,offerId="a",revision=1,state="writable",credential="grant",life="life"}})
check(client:status()=="saved","fixture begins with a confirmed permission and no new rest")
local token={};client:beginRestPreparation("main",token)
check(client:status()=="saving","local preparation suppresses an old Saved state")
local data={items={}};for i=1,1000 do data.items[i]={i=i} end
local clock=0
local function prepare()
 return Work.new(function() return client:prepareRest("main",data,token) end,{budget=.001,maxSeconds=1000,now=function() clock+=.001;return clock end})
end
local function finish(job)
 for _=1,10000 do if job.state~="pending" then break end;job:step() end
 check(job.state=="done","network candidate preparation completes")
 return assert(job:take())[1]
end
local job=prepare();job:step()
check(job.state=="pending" and r.candidate==nil,"partial network preparation changes no ticket")
local admit=finish(job)
check(r.candidate==nil and admit() and not admit() and r.ticket==1,"private candidate is admitted atomically and once")
client:endRestPreparation("main",token,true,true)
check(client:status()=="saving","admission still cannot claim durable storage")
local packet
client.bound:update(10,function(p) if p.kind=="rest" then packet=p end end)
assert(packet)
receive({kind="stored",mode="main",serial=r.serial,credential="grant",restSerial=packet.restSerial})
check(client:status()=="saved","only the exact stored receipt confirms the current candidate")
token={};client:beginRestPreparation("main",token);client:endRestPreparation("main",token,true,false)
local st,why=client:status()
check(st=="saving" and why=="rest_refused","kept local rest with no admitted candidate cannot show Saved")
token={};client:beginRestPreparation("main",token);client:endRestPreparation("main",token,false,false)
check(client:status()=="saving","a failed later local attempt cannot clear an older unsent rest")
token={};client:beginRestPreparation("main",token);job=prepare();job:step()
assert(client:beginLife("main","a"));local newer=client.bound.requests.main
admit=finish(job)
check(not admit() and newer.candidate==nil and newer.ticket==0,"old preparation cannot attach to a new life")
local latestToken={};client:beginRestPreparation("main",latestToken)
check(not client:endRestPreparation("main",token,true,true) and client.restPreparing.main.token==latestToken,"late completion cannot clear a new pending marker")
token=latestToken;job=prepare();job:step()
assert(client:sendRest("main",{newer=true}));local latestCandidate=newer.candidate
admit=finish(job)
check(not admit() and newer.candidate==latestCandidate,"ticket fence prevents an older preparation replacing a later candidate")
print(`LOCAL_REST passed={passed} failed={failed}`)
assert(failed==0,"local rest failures")
