local Json=require("../src/Shared/Persistence/Json")
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
 local ds=fakeStore();check(not pcall(function() Store.new({read=function() end,update=function() end},"u1") end),"cached-only backend admitted")
 local created={};local originalNew=Instance.new
 Instance.new=function(class,...)
  local value=originalNew(class,...)
  if class=="DataStoreGetOptions" then
   local destroy=value.Destroy
   value.Destroy=function(self) self._freshOptionDestroyed=true;return destroy(self) end
   table.insert(created,value)
  end
  return value
 end
 local backend=Backend.new(ds);backend:readRawFresh("P_x");ds.failRead=true;backend:readRawFresh("P_x")
 Instance.new=originalNew
 check(#created==2 and created[1]._freshOptionDestroyed and created[2]._freshOptionDestroyed,"read options leaked on success/error")
end
print("FRESH_RAW_READ passed="..passed.." failed=0")
