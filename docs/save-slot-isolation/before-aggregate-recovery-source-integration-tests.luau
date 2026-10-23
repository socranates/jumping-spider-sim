local Json=require("../src/Shared/Persistence/Json")
local Backend=require("../src/Server/DataStoreBackend")
local Scheduler=require("../src/Shared/Persistence/SaveScheduler")
local Rules=require("../src/Shared/Data/SaveRules")
local Archive=__archivePrototype
local Collector=__collectorPrototype
local Store=__archiveStorePrototype
local passed=0
local function check(ok,why) assert(ok,why);passed+=1 end
local function fixture()
 local ds={data={},cache={},cached={},requests=0,writes=0,log={},context="component",failAfterWrite=true}
 function ds:GetAsync(key,options)
  self.requests+=1;table.insert(self.log,{key=key,op="read",context=self.context,uncached=options~=nil and options.UseCache==false})
  if (options==nil or options.UseCache~=false) and self.cached[key] then return Json.copy(self.cache[key]) end
  local value=Json.copy(self.data[key]);self.cache[key]=Json.copy(value);self.cached[key]=true;return value
 end
 function ds:UpdateAsync(key,fn)
  self.requests+=1;local value=fn(Json.copy(self.data[key]))
  table.insert(self.log,{key=key,op="update",context=self.context})
  if value~=nil then self.data[key]=Json.copy(value);self.writes+=1 end
  if self.failAfterWrite and string.sub(key,1,3)=="A1_" and value~=nil then self.failAfterWrite=false;error("503: acknowledgement lost") end
  if value~=nil then self.cache[key]=Json.copy(value);self.cached[key]=true end
  return Json.copy(self.data[key])
 end
 ds.data.P_12345={schema=999,checksum="opaque-original",payload={future={"complete","unchanged"}},lock={session="lease-A",beat=0}}
 ds.data.R_12345_main={encoding="opaque-future",data="original current",backup={data="original backup"}}
 ds.data.R_12345_free="corrupt but preserved original"
 ds.cached.P_12345=true;ds.cache.P_12345={wrong="stale cached progress"}
 ds.cached.A1_12345_progress=true -- stale cached absence after an uncertain write
 local codecCalls=0
 local codec={decode=function() codecCalls+=1;error("source/archives must not be decoded") end,encode=function() codecCalls+=1;error("source/archives must not be re-encoded") end}
 return ds,Backend.new(ds,codec),function() return codecCalls end
end
local function sourceValues(ds)
 return {progress=ds.data.P_12345,main=ds.data.R_12345_main,free=ds.data.R_12345_free,easy=ds.data.R_12345_easy}
end
local function contents(ds)
 local value=Json.copy(sourceValues(ds));value.progress.lock.beat=nil;return Json.canonical(value)
end
do
 local ds,backend,codecCalls=fixture();local now=0;local original=contents(ds)
 local ownerEpoch=1;local scheduler=Scheduler.new()
 for _=1,Rules.REQUESTS_PER_MINUTE-2 do scheduler:begin(nil,now) end
 local collector=Collector.new(backend,"12345","lease-A",nil,{now=function() return now end,maxSeconds=300})
 local function fence() return ownerEpoch==1 and ds.data.P_12345.lock.session=="lease-A" and now-ds.data.P_12345.lock.beat<Rules.LOCK_STALE end
 local job=collector:begin("server-observation-under-owned-lease",fence)
 local repo=Store.new(backend,"12345");local publication=nil;local nextBeat=30;local heartbeats=0;local cpuWithoutBudget=0
 for _=1,600 do
  local before=ds.requests
  if now>=nextBeat and scheduler:budgetOk(now) then
   scheduler:begin(nil,now);ds.context="heartbeat"
   ds:UpdateAsync("P_12345",function(raw) raw.lock.beat=now;return raw end)
   ds.context="component";nextBeat=now+30;heartbeats+=1
  elseif job.state=="pending" then
   if not collector:wantsRead(job) then
    if not scheduler:budgetOk(now) then cpuWithoutBudget+=1 end
    check(not collector:step(job),"CPU-only collector step reported network traffic")
   elseif scheduler:budgetOk(now) then
    scheduler:begin(nil,now);collector:step(job)
   end
  elseif job.state=="complete" then
   if publication==nil then publication=assert(repo:begin(job.plan,fence))
   elseif publication.state=="pending" and scheduler:budgetOk(now) then
    scheduler:begin(nil,now);repo:step(publication)
   end
  else error("collection failed under stable owned source: "..job.state) end
  check(ds.requests-before<=1,"composed worker issued more than one request in a tick")
  check(#scheduler.started<=Rules.REQUESTS_PER_MINUTE,"composed worker exceeded minute admission budget")
  if publication and publication.state=="complete" then break end
  now+=1
 end
 check(job.state=="complete" and publication and publication.state=="complete","bounded source/publication pipeline never completed")
 check(now>=60 and heartbeats>=1 and cpuWithoutBudget>0,"fixture missed quota exhaustion, heartbeat drift or CPU progress without request allowance")
 check(job.plan.entries.progress.raw.lock.beat==0 and ds.data.P_12345.lock.beat>0,"archive discarded original heartbeat metadata")
 check(Archive.check(job.plan) and ds.data.A1_12345_index.complete,"complete archive or completion marker invalid")
 check(ds.data.A1_12345_main.raw.backup.data=="original backup" and ds.data.A1_12345_progress.progress.raw.payload.future[1]=="complete","opaque complete source/backup lost")
 check(contents(ds)==original and codecCalls()==0,"pipeline changed source content or invoked decoding")
 local archiveWrites=0
 for _,op in ds.log do
  if op.op=="read" then check(op.uncached,"source or archive verification used cached GetAsync")
  elseif op.context=="heartbeat" then check(op.key=="P_12345","heartbeat touched a rest/archive")
  else check(string.sub(op.key,1,3)=="A1_","collector/publisher wrote an original save key");archiveWrites+=1 end
 end
 check(archiveWrites==5 and not ds.failAfterWrite,"lost acknowledgement fixture did not publish exactly five archive values")
 print("RECOVERY_SOURCE_PIPELINE requests="..ds.requests.." heartbeat_writes="..heartbeats.." simulated_seconds="..now)
end
-- Source collection is not a durable commit. Changing authority after a fully
-- prepared source must still prevent publication, with originals untouched.
do
 local ds,backend=fixture();local allowed=true
 local c=Collector.new(backend,"12345","lease-A");local j=c:begin("observation-before-authority-change",function() return allowed end)
 for _=1,100 do if j.state~="pending" then break end;c:step(j) end
 check(j.state=="complete","source fixture did not complete")
 local original=Json.canonical(sourceValues(ds));allowed=false
 local repo=Store.new(backend,"12345");local publication=assert(repo:begin(j.plan,function() return allowed end))
 repo:step(publication)
 check(publication.state~="complete" and ds.writes==0 and ds.data.A1_12345_index==nil,"prepared raw source bypassed publication authority")
 check(Json.canonical(sourceValues(ds))==original,"authority refusal changed original save")
end
print("RECOVERY_SOURCE_INTEGRATION passed="..passed.." failed=0")
