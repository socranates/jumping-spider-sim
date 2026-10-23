-- Private server correctness checks; no real DataStore calls. Never publish.
local Run=game:GetService("RunService")
assert(Run:IsStudio() and Run:IsServer() and game.PlaceId==0 and workspace:GetAttribute("RecoveryStoreProbe")==true)
local Shared=game.ReplicatedStorage.Shared
local __archivePrototype=require(script.Parent.RecoveryArchivePrototype)
local __archiveStorePrototype=require(script.Parent.RecoveryArchiveStorePrototype)
local __freshBackend=require(script.Parent.FreshReadBackendPrototype)
local id=tostring(DateTime.now().UnixTimestampMillis)
local ok,err=xpcall(function()
 print("[NATIVE_RECOVERY_STORE_BEGIN]",id)
 local function protocol()
local Json=require(Shared.Persistence.Json)
local Memory=require(Shared.Persistence.MemoryBackend)
local Work=require(Shared.Persistence.SaveWork)
local Archive=__archivePrototype
local Store=__archiveStorePrototype
local passed=0
local function check(ok,why) assert(ok,why);passed+=1 end
local function sources()
 return {progress={loaded=true,value={schema=999,payload={opened={"spider"}},lock={session="old",beat=1}}},
  main={loaded=true,value={schema=2,data="opaque compressed current",backup={data="complete original backup"}}},
  free={loaded=true,value="corrupt original"},easy={loaded=true}}
end
local function fixture()
 local raw=sources();local backend=Memory.new()
 -- MemoryBackend has no cache; keep the production protocol explicit.
 backend.readFresh=function(self,key) return self:read(key) end
 backend:poke("P_12345",Json.copy(raw.progress.value))
 for _,slot in {"main","free","easy"} do backend:poke("R_12345_"..slot,Json.copy(raw[slot].value)) end
 local plan=assert(Archive.prepare("12345","observed-original-matrix",raw))
 return backend,Store.new(backend,"12345"),plan,raw
end
local function originals(b)
 return Json.canonical({progress=b.data.P_12345,main=b.data.R_12345_main,free=b.data.R_12345_free,easy=b.data.R_12345_easy})
end
local function step(repo,job)
 local before=repo.backend.requests;repo:step(job)
 check(repo.backend.requests-before<=1,"a step used more than one backend request")
end
local function drive(repo,job)
 for _=1,100 do if job.state~="pending" then return end;step(repo,job) end
 error("archive job did not settle")
end
local function begin(repo,plan,fence) return assert(repo:begin(plan,fence or function() return true end)) end
do
 local b,r,p=fixture();local before=originals(b);local j=begin(r,p)
 drive(r,j)
 check(j.state=="complete" and j.verified==5 and j.requests==10,"publication not verified")
 check(b.data.A1_12345_index.complete and b.writes==5,"manifest was not last and complete")
 check(originals(b)==before,"original save keys changed")
 for _,op in b.log do check(string.sub(op.key,1,3)=="A1_","publication accessed a source save key") end
 local writes=b.writes;local again=begin(r,p);drive(r,again)
 check(again.state=="complete" and b.writes==writes,"idempotent publication rewrote an archive")
 local recovered=assert(r:beginRecovery(nil,function() return true end));drive(r,recovered)
 check(recovered.state=="complete" and Json.canonical(recovered.plan)==Json.canonical(p) and b.writes==writes,"complete archive could not recover independently of source reads")
end
for _,fault in {
 {op="update",key="A1_12345_progress",message="before write"},
 {op="update",key="A1_12345_progress",message="ambiguous after write",afterWrite=true},
 {op="read",key="A1_12345_progress",message="read unavailable"},
 {op="update",key="A1_12345_index",message="manifest acknowledgement lost",afterWrite=true},
} do
 local b,r,p=fixture();local before=originals(b);b:fail(fault)
 local j=begin(r,p);drive(r,j)
 if j.state=="retry" then check(b.data.A1_12345_index==nil,"unverified manifest published");check(r:retry(j),"retry refused");drive(r,j) end
 check(j.state=="complete" and b.writes==5 and originals(b)==before,"fault recovery lost/duplicated/changed data")
end
do
 local b,r,p=fixture();local mutable=Json.copy(p);local j=begin(r,mutable)
 mutable.entries.main.raw.data="later caller mutation"
 drive(r,j)
 check(j.state=="complete" and b.data.A1_12345_main.raw.data==p.entries.main.raw.data,"publication did not own its input")
end
do
 local b,r,p=fixture();local j=begin(r,p);step(r,j);step(r,j)
 b:poke("A1_12345_main","foreign archive value");local writes=b.writes
 drive(r,j)
 check(j.state=="refused" and b.data.A1_12345_main=="foreign archive value" and b.data.A1_12345_index==nil and b.writes==writes,"conflicting value overwritten")
end
do
 local b,r,p=fixture();local read=b.read;local once=false
 b.read=function(self,key)
  if key=="A1_12345_progress" and not once then once=true;self.data[key].progress.raw.payload.opened[1]="damaged archival copy" end
  return read(self,key)
 end
 local before=originals(b);local j=begin(r,p);drive(r,j)
 check(j.state=="refused" and b.data.A1_12345_index==nil and originals(b)==before,"bad readback was trusted")
end
for _,when in {"before","callback","after"} do
 local b,r,p=fixture();local permitted=when~="before";local update=b.update
 if when~="before" then
  b.update=function(self,key,fn)
   if when=="callback" then permitted=false end
   local ok,value,why=update(self,key,fn)
   if when=="after" then permitted=false end
   return ok,value,why
  end
 end
 local before=originals(b);local j=begin(r,p,function() return permitted end);drive(r,j)
 check(j.state=="refused" and b.data.A1_12345_index==nil and originals(b)==before,"stale authority published a complete archive")
 if when~="after" then check(b.writes==0,"write happened after fence refusal") end
end
do
 local b,r,p=fixture();local update=b.update;local j
 b.update=function(self,key,fn) check(not r:step(j),"reentrant step admitted");return update(self,key,fn) end
 j=begin(r,p);drive(r,j)
 check(j.state=="complete" and j.requests==10,"reentrant backend doubled requests")
end
do
 local b,r,p=fixture();local update=b.update;local callbacks=0
 b.update=function(self,key,fn)
  for _=1,3 do callbacks+=1;fn(Json.copy(self.data[key])) end
  return update(self,key,fn)
 end
 local j=begin(r,p);drive(r,j)
 check(j.state=="complete" and b.writes==5 and callbacks==15,"repeated transform changed publication")
end
for _,cancelWhen in {"before","callback","after"} do
 local b,r,p=fixture();local j;local update=b.update
 if cancelWhen~="before" then
  b.update=function(self,key,fn)
   if cancelWhen=="callback" then r:cancel(j) end
   local ok,value,why=update(self,key,fn)
   if cancelWhen=="after" then r:cancel(j) end
   return ok,value,why
  end
 end
 local before=originals(b);j=begin(r,p)
 if cancelWhen=="before" then r:cancel(j) end
 drive(r,j)
 check(j.state=="cancelled" and b.data.A1_12345_index==nil and originals(b)==before,"cancellation published or changed original saves")
 local requests=b.requests;check(not r:step(j) and b.requests==requests,"cancelled job resumed")
end
for _,winner in {1,2} do
 local b,r,p,raw=fixture();local other=Store.new(b,"12345");raw.main.value.data="another source"
 local p2=assert(Archive.prepare("12345","different-observation",raw))
 local jobs={begin(r,p),begin(other,p2)};local repos={r,other}
 for _=1,20 do
  for _,i in {winner,3-winner} do if jobs[i].state=="pending" then step(repos[i],jobs[i]) end end
 end
 check(jobs[winner].state=="complete" and jobs[3-winner].state=="refused" and b.writes==5,"competing plans both published or overwrote a part")
end
do
 local b,r,p=fixture();local j
 j=begin(r,p,function() if j then r:cancel(j) end;return true end)
 drive(r,j)
 check(j.state=="cancelled" and b.requests==0 and b.data.A1_12345_index==nil,"cancellation inside the authority fence was overwritten or admitted a request")
end
do
 local b,r,p,raw=fixture();local abandoned=begin(r,p)
 for _=1,4 do step(r,abandoned) end -- anchor and main verified; process stops here
 local newer=Json.copy(raw);newer.progress.value.lock.beat=999
 local recovered=assert(Store.new(b,"12345"):beginRecovery(newer,function() return true end))
 local resumedRepo=recovered.repository;drive(resumedRepo,recovered)
 check(recovered.state=="complete" and b.writes==5 and recovered.plan.entries.progress.raw.lock.beat==1,"restart lost original progress observation or duplicated parts")
 check(Json.canonical(recovered.plan)==Json.canonical(p),"restart changed the source archive")
end
do
 local b,r,p,raw=fixture();local abandoned=begin(r,p);step(r,abandoned);step(r,abandoned)
 local missing=assert(r:beginRecovery(nil,function() return true end));drive(r,missing)
 check(missing.state=="refused" and b.data.A1_12345_index==nil,"missing original source guessed")
 local changed=Json.copy(raw);changed.main.value.data="foreign newer rest"
 local stale=assert(r:beginRecovery(changed,function() return true end));local writes=b.writes;drive(r,stale)
 check(stale.state=="refused" and b.writes==writes and b.data.A1_12345_index==nil,"changed original was mixed into archive")
 local healthy=assert(r:beginRecovery(raw,function() return true end));drive(r,healthy)
 check(healthy.state=="complete","healthy retry after source read became available failed")
end
do
 local b,r,p=fixture();local before=b.requests
 local tiny=Store.new(b,"12345",{value=50});check(tiny:begin(p,function() return true end)==nil and b.requests==before,"per-artifact bound bypassed")
 tiny=Store.new(b,"12345",{total=50});check(tiny:begin(p,function() return true end)==nil and b.requests==before,"aggregate publication bound bypassed")
 check(r:begin(p,nil)==nil and Store.new(b,"other"):begin(p,function() return true end)==nil,"missing fence/foreign owner admitted")
 local worker=Work.new(function() return r:begin(p,function() return true end) end)
 worker:step();local reply=worker:take()
 check(reply and reply[1]==nil and b.requests==before,"publication began in a preparation worker")
end
-- Real coroutine suspension models backend calls that yield to another server
-- callback, rather than only synchronous callbacks that toggle a test flag.
do
 local b,r,p=fixture();local update=b.update
 b.update=function(self,key,fn) coroutine.yield("network update");return update(self,key,fn) end
 local before=originals(b);local j=begin(r,p)
 local co=coroutine.create(function() return r:step(j) end)
 local ok,marker=coroutine.resume(co)
 check(ok and marker=="network update" and j.state=="running","update did not suspend")
 check(not r:step(j) and r:cancel(j),"suspended update was reentered or could not cancel")
 ok=coroutine.resume(co)
 check(ok and coroutine.status(co)=="dead" and j.state=="cancelled" and b.writes==0 and originals(b)==before,"cancelled in-flight update wrote or published")
end
do
 local b,r,p=fixture();local permitted=true;local j=begin(r,p,function() return permitted end)
 step(r,j) -- progress anchor written; now suspend its readback
 local read=b.read
 b.read=function(self,key)
  local ok,value,why=read(self,key);coroutine.yield("network read");return ok,value,why
 end
 local co=coroutine.create(function() return r:step(j) end)
 local ok,marker=coroutine.resume(co)
 check(ok and marker=="network read" and j.state=="running","read did not suspend")
 permitted=false;ok=coroutine.resume(co)
 check(ok and j.state=="refused" and b.data.A1_12345_index==nil,"authority lost during read still verified publication")
end
do
 local b,r,p=fixture();local j=begin(r,p)
 for _=1,9 do step(r,j) end -- completion marker written, its readback not acknowledged
 check(j.index==5 and j.phase=="read" and j.state=="pending" and b.data.A1_12345_index.complete,"final acknowledgement fixture invalid")
 local read=b.read
 b.read=function(self,key)
  local ok,value,why=read(self,key);coroutine.yield("final readback");return ok,value,why
 end
 local co=coroutine.create(function() return r:step(j) end)
 local ok,marker=coroutine.resume(co)
 check(ok and marker=="final readback" and r:cancel(j),"final readback did not suspend/cancel")
 ok=coroutine.resume(co)
 check(ok and j.state=="cancelled" and j.verified==4,"cancelled final read reported completion")
 b.read=read
 local recovered=assert(r:beginRecovery(nil,function() return true end));drive(r,recovered)
 check(recovered.state=="complete" and b.writes==5,"acknowledgement loss could not recover the committed archive")
end
print("RECOVERY_ARCHIVE_STORE passed="..passed.." failed=0")
return passed end
 local function freshReads()
local Json=require(Shared.Persistence.Json)
local Backend=__freshBackend
local Archive=__archivePrototype
local Store=__archiveStorePrototype
local passed=0
local function check(ok,why) assert(ok,why);passed+=1 end
local function fakeStore()
 local ds={data={},cache={},cached={},calls={},requests=0,writes=0,failRead=false,failAfterWrite=false,damageOnRead=nil}
 function ds:GetAsync(key,options)
  self.requests+=1;table.insert(self.calls,{key=key,uncached=options~=nil and options.UseCache==false})
  if self.failRead then error("503: read unavailable") end
  if self.damageOnRead==key then self.damageOnRead=nil;self.data[key].progress.raw.changed="foreign damage" end
  if options==nil or options.UseCache~=false then
   if self.cached[key] then return Json.copy(self.cache[key]) end
  end
  local value=Json.copy(self.data[key]);self.cache[key]=Json.copy(value);self.cached[key]=true
  return value
 end
 function ds:UpdateAsync(key,fn)
  self.requests+=1
  local value=fn(Json.copy(self.data[key]))
  if value~=nil then self.data[key]=Json.copy(value);self.writes+=1 end
  if self.failAfterWrite and value~=nil then self.failAfterWrite=false;error("503: acknowledgement lost after write") end
  if value~=nil then self.cache[key]=Json.copy(value);self.cached[key]=true end
  return Json.copy(self.data[key])
 end
 return ds
end
do
 local ds=fakeStore();local decoded=0
 local codec={decode=function(_,value,recover)
  decoded+=1;assert(recover==true)
  return {recovered=true,payload=value.backup.payload}
 end}
 local backend=Backend.new(ds,codec)
 ds.data.R_u_main={schema=2,data="corrupt current",unknown="keep this too",backup={payload={stage=1}}}
 local raw=assert(Json.canonical(ds.data.R_u_main))
 local ok,value=backend:read("R_u_main")
 check(ok and value.recovered and decoded==1,"ordinary read contract changed")
 ok,value=backend:readRawFresh("R_u_main")
 check(ok and Json.canonical(value)==raw and decoded==1,"raw read decoded or lost current/backup fields")
 check(ds.calls[#ds.calls].uncached,"raw read used cache")
 ds.data.R_u_main.backup.payload.stage=2
 ok,value=backend:read("R_u_main")
 check(ok and value.payload.stage==1,"fixture did not retain a stale cached value")
 ok,value=backend:readFresh("R_u_main")
 check(ok and value.payload.stage==2 and ds.calls[#ds.calls].uncached,"fresh decoded read returned cached state")
 check(Json.canonical(ds.data.R_u_main)~=raw,"fixture source update absent")
 local current=assert(Json.canonical(ds.data.R_u_main));ok,value=backend:readRawFresh("R_u_main")
 check(ok and Json.canonical(value)==current,"fresh raw read did not preserve current stored representation")
 value.unknown="caller mutation"
 check(Json.canonical(ds.data.R_u_main)==current,"raw read shared the store's tree")
 ok,value=backend:readRawFresh("P_missing")
 check(ok and value==nil,"missing raw source did not stay missing")
 ds.failRead=true
 local why;ok,value,why=backend:readRawFresh("R_u_main")
 check(not ok and value==nil and type(why)=="string","raw read error escaped or looked missing")
 ds.failRead=false;codec.decode=function() error("bad compressed source") end
 ok,value=backend:readFresh("R_u_main")
 check(not ok and value==nil,"fresh codec error escaped")
 ok,value=backend:readRawFresh("R_u_main")
 check(ok and Json.canonical(value)==current,"raw read depended on a working codec")
end
local function makePlan()
 return assert(Archive.prepare("u1","observed-source",{
  progress={loaded=true,value={schema=999,payload={unknown="preserve"}}},
  main={loaded=true,value="opaque rest"},free={loaded=true},easy={loaded=true},
 }))
end
local function drive(repo,job,ds)
 for _=1,40 do
  if job.state~="pending" then return end
  local before=ds.requests;repo:step(job)
  check(ds.requests-before<=1,"adapter step made multiple requests")
 end
 error("adapter publication did not settle")
end
do
 local ds=fakeStore();ds.cached.A1_u1_progress=true -- stale cached physical absence
 local codec={decode=function() error("archive key passed through rest codec") end,encode=function() error("archive key compressed") end}
 local backend=Backend.new(ds,codec);local repo=Store.new(backend,"u1");local plan=makePlan()
 ds.failAfterWrite=true
 local job=assert(repo:begin(plan,function() return true end));drive(repo,job,ds)
 check(job.state=="complete" and job.verified==5 and ds.writes==5,"uncached readback did not resolve lost acknowledgement")
 for _,call in ds.calls do check(call.uncached and string.sub(call.key,1,3)=="A1_","archive read used cache or a source key") end
 check(ds.data.A1_u1_index.complete,"completion marker absent")
end
do
 local ds=fakeStore();local backend=Backend.new(ds);local repo=Store.new(backend,"u1")
 local job=assert(repo:begin(makePlan(),function() return true end));repo:step(job)
 ds.damageOnRead="A1_u1_progress" -- cache still holds the apparently correct pre-damage copy
 repo:step(job)
 check(job.state=="refused" and ds.data.A1_u1_index==nil,"cached data hid a damaged archival copy")
end
do
 local ds=fakeStore()
 check(not pcall(function() Store.new({read=function() end,update=function() end},"u1") end),"cached-only backend admitted")
 local destroyed=0;local get=ds.GetAsync
 ds.GetAsync=function(self,key,options)
  assert(options~=nil and options.UseCache==false,"native uncached options absent")
  options.Destroying:Connect(function() destroyed+=1 end)
  return get(self,key,options)
 end
 local backend=Backend.new(ds)
 backend:readRawFresh("P_x");ds.failRead=true;backend:readRawFresh("P_x")
 task.wait()
 check(destroyed==2,"native options were not cleaned up on success and error")
end
print("FRESH_RAW_READ passed="..passed.." failed=0")
return passed end
 local a,b=protocol(),freshReads()
 assert(a==272 and b==32,"unexpected native assertion count")
 print("[NATIVE_RECOVERY_STORE_PASS]",id,a+b)
end,debug.traceback)
if not ok then warn("[NATIVE_RECOVERY_STORE_FAIL]",id,tostring(err)) end
