local Json=require("../src/Shared/Persistence/Json")
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Work=require("../src/Shared/Persistence/SaveWork")
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
