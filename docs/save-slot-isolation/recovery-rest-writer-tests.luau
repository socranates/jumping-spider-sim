do
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Backend=require("../src/Server/DataStoreBackend")
local Writer=__restWriterPrototype
local Raw=__rawBackendPrototype
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function fixture()
 local b=Memory.new();local ds={requests=0,options=0,log={},cache={}}
 b:poke("R_46001_main",Json.copy(rest));b:poke("P_46001",Json.copy(rawProgress));b:poke("R_46001_free",{untouched=true})
 function ds:GetAsync(key,options)
  self.requests+=1;self.options+=1;table.insert(self.log,{op="read",key=key,uncached=options~=nil and options.UseCache==false})
  if options==nil or options.UseCache~=false then return Json.copy(self.cache[key]) end
  local ok,value,why=b:read(key);if not ok then error(why) end;return value
 end
 function ds:UpdateAsync(key,fn)
  self.requests+=1;table.insert(self.log,{op="update",key=key})
  local ok,value,why=b:update(key,fn);if not ok then error(why) end;return value
 end
 local codecCalls=0
 local normal=Backend.new(ds,{decode=function() codecCalls+=1;error("ordinary rest path decoded raw CAS") end,
  encode=function() codecCalls+=1;error("ordinary rest path re-encoded raw CAS") end})
 local raw=Raw.new(ds)
 return b,ds,raw,Writer.new(raw),normal,function() return codecCalls end
end
local plan=assert(Writer.prepare(archive,anchor,codec,fresh))
local function begin(w,p,f) return assert(w:begin(p or plan,f or function() return true end)) end
local function step(ds,w,j)
 local before=ds.requests;w:step(j);check(ds.requests-before<=1,"rest step exceeded one request")
end
local function drive(ds,w,j)
 for _=1,20 do if j.state~="pending" then return end;step(ds,w,j) end
 error("rest replacement did not settle")
end
local function published(b) b:poke(anchor.id,Json.copy(anchor)) end
do
 local b,ds,raw,w,normal,codecCalls=fixture()
 local oldP=Json.canonical(b.data.P_46001);local oldOther=Json.canonical(b.data.R_46001_free)
 -- Compose the real adapter boundary with prior M1 publication, including its
 -- uncached readback, before exact selected-rest replacement.
 local pub=__proposalStorePrototype.new(normal,codec,fresh);local p=assert(pub:begin(anchor,function() return true end))
 for _=1,5 do if p.state=="pending" then pub:step(p) end end
 check(p.state=="ready","M1 publication did not compose with real adapter")
 ds.cache[plan.key]=Json.copy(rest) -- stale original must not hide the write
 local j=begin(w);drive(ds,w,j)
 check(j.state=="restVerified" and j.requests==3 and Json.canonical(b.data[plan.key])==Json.canonical(anchor.target),"selected raw rest was not replaced/read back exactly")
 check(Json.canonical(b.data.P_46001)==oldP and Json.canonical(b.data.R_46001_free)==oldOther,"raw writer touched another save key")
 check(codecCalls()==0,"raw replacement invoked normal rest codec")
 local writes=b.writes;local again=begin(w);drive(ds,w,again)
 check(again.state=="restVerified" and b.writes==writes,"interrupted restart rewrote/re-encoded target")
 for _,op in ds.log do if op.op=="read" then check(op.uncached,"verification used cached GetAsync") end end
end
for _,mutate in {
 function(v) v.backup.payload.save_life="changed-backup" end,
 function(v) v.updatedAt+=1 end,
 function(v) v.unknown="new-field" end,
} do
 local b,ds,raw,w=fixture();published(b);local changed=Json.copy(rest);mutate(changed);b:poke(plan.key,changed)
 local before=Json.canonical(changed);local j=begin(w);drive(ds,w,j)
 check(j.state=="refused" and b.writes==0 and Json.canonical(b.data[plan.key])==before,"changed original was overwritten")
end
for _,after in {false,true} do
 local b,ds,raw,w=fixture();published(b);b:fail({op="update",key=plan.key,afterWrite=after,message="lost acknowledgement"})
 local j=begin(w);drive(ds,w,j)
 if after then check(j.state=="restVerified" and b.writes==1,"lost write acknowledgement not resolved")
 else
  check(j.state=="retry" and b.writes==0,"failed write claimed verified")
  check(w:retry(j),"failed write cannot retry");drive(ds,w,j)
  check(j.state=="restVerified" and b.writes==1,"retry did not replace original once")
 end
end
do
 local b,ds,raw,w=fixture();published(b);local j=begin(w);step(ds,w,j);step(ds,w,j)
 b:fail({op="read",key=plan.key});step(ds,w,j)
 check(j.state=="retry" and b.writes==1,"failed readback granted verification")
 check(w:retry(j),"readback retry refused");drive(ds,w,j)
 check(j.state=="restVerified" and b.writes==1,"readback restart rewrote target")
end
for _,missing in {true,false} do
 local b,ds,raw,w=fixture()
 if not missing then b:poke(anchor.id,second) end
 local j=begin(w);drive(ds,w,j)
 check(j.state=="refused" and b.writes==0,"missing/different persisted M1 authorized rest write")
end
do
 local b,ds,raw,w=fixture();published(b);local j=begin(w);local k=begin(w)
 step(ds,w,j);step(ds,w,k);step(ds,w,j);step(ds,w,k);drive(ds,w,j);drive(ds,w,k)
 check(j.state=="restVerified" and k.state=="restVerified" and b.writes==1,"competing recovery wrote twice")
end
for _,point in {"before","callback","afterwrite","readback"} do
 local b,ds,raw,w=fixture();published(b);local live=true;local j=begin(w,nil,function() return live end)
 if point=="before" then live=false
 else
  step(ds,w,j)
  if point=="readback" then
   step(ds,w,j);local read=raw.readRawFresh
   raw.readRawFresh=function(self,key) local ok,v,e=read(self,key);live=false;return ok,v,e end
  else
   local update=raw.updateRaw
   raw.updateRaw=function(self,key,fn)
    if point=="callback" then live=false end
    local ok,v,e=update(self,key,fn);live=false;return ok,v,e
   end
  end
 end
 drive(ds,w,j);check(j.state=="refused","revoked rest operation claimed verification")
 if point=="before" or point=="callback" then check(b.writes==0,"revoked callback wrote") end
end
do
 local b,ds,raw,w=fixture();published(b);local j=begin(w);step(ds,w,j)
 local update=raw.updateRaw;raw.updateRaw=function(self,key,fn) w:cancel(j);return update(self,key,fn) end
 step(ds,w,j);check(j.state=="cancelled" and b.writes==0,"reentrant cancel wrote/restored job")
 check(not w:retry(j),"cancelled writer resurrected")
 check(w:begin(Json.copy(plan),function() return true end)==nil,"forged preparation handle accepted")
 local ran=false;local ok=raw:updateRaw("P_46001",function() ran=true;return {} end)
 check(ok==false and not ran,"raw escape hatch allowed progress writes")
 local threw=raw:updateRaw(plan.key,function() error("intentional callback error") end)
 check(threw==false,"production protected callback error was swallowed")
end
do
 local b,ds,raw,w=fixture();published(b);b:poke(plan.key,nil);local j=begin(w);drive(ds,w,j)
 check(j.state=="refused" and b.writes==0 and b.data[plan.key]==nil,"missing selected source was replaced by a default")
end
do
 local b,ds,raw,w=fixture();published(b);local j=begin(w);step(ds,w,j)
 local update=ds.UpdateAsync;local changed=Json.copy(rest);changed.extra="concurrent write"
 ds.UpdateAsync=function(self,key,fn)
  local discarded=fn(Json.copy(rest));check(discarded~=nil,"first callback did not see original")
  b:poke(key,changed);return update(self,key,fn)
 end
 drive(ds,w,j)
 check(j.state=="refused" and b.writes==0 and Json.canonical(b.data[plan.key])==Json.canonical(changed),"replayed callback overwrote concurrent final value")
end
for _,kind in {"primary","backup"} do
 local compressed=codec:encode(rest)
 local a=assert(__packetArchive.prepare("46001","compressed-original-"..kind,{progress={loaded=true,value=rawProgress},main={loaded=true,value=compressed},free={loaded=true},easy={loaded=true}}))
 local candidate=assert(__packetPrototype.prepare("46001","main",a,incoming,110,template,fresh,codec,kind,200))
 local preparedPlan=assert(Writer.prepare(a,candidate,codec,fresh))
 local b,ds,raw,w,normal,codecCalls=fixture();b:poke(candidate.id,candidate);b:poke(preparedPlan.key,compressed)
 local before=Json.canonical(a);local j=begin(w,preparedPlan);drive(ds,w,j)
 check(j.state=="restVerified" and codecCalls()==0,"compressed original/explicit backup was not raw-replaced")
 check(Json.canonical(a)==before and a.entries.main.raw.backup~=nil,"compressed original archive/backup changed")
end
for _,slot in {"main","easy","free"} do
 local problems,d=Checkpoint.inspectRecorded(source,fresh);assert(#problems==0 and d)
 d.roots.life.mode=if slot=="free" then "free" else "main";d.roots.life.rules=if slot=="main" then "standard" else "gentle";d.roots.needs.gentle=slot~="main"
 local record=Json.copy(source);record.world=assert(ObjectRecord.capture(d.roots,Checkpoint.CLASSES,Checkpoint.refs(fresh)));record.life_rules={mode=d.roots.life.mode,rules=d.roots.life.rules}
 local globals=Progress.default();globals.finished_main=true
 local sources={progress={loaded=true,value=Envelope.make(Progress.SPEC,globals,100,nil)},main={loaded=true},free={loaded=true},easy={loaded=true}}
 sources[slot].value=Envelope.make(SaveRest.SPECS[slot],record,90,nil)
 local a=assert(__packetArchive.prepare("46001","writer-slot-"..slot,sources))
 local candidate=assert(__packetPrototype.prepare("46001",slot,a,incoming,110,template,fresh,codec,"primary",200))
 local preparedPlan=assert(Writer.prepare(a,candidate,codec,fresh));local b,ds,raw,w=fixture()
 b:poke(candidate.id,candidate);b:poke(preparedPlan.key,sources[slot].value)
 local j=begin(w,preparedPlan);drive(ds,w,j)
 check(j.state=="restVerified" and preparedPlan.key=="R_46001_"..slot,"mode slot replacement failed")
end
local Work=require("../src/Shared/Persistence/SaveWork")
local ticks=0;local function now() ticks+=.000001;return ticks end
local worker=Work.new(function() return Writer.prepare(archive,anchor,codec,fresh) end,{now=now,budget=.000001,maxSeconds=100,maxResumes=10000})
local suspensions=0
while worker.state=="pending" do worker:step();if worker.state=="pending" then suspensions+=1 end end
local preparedResult=worker:take()
check(preparedResult and preparedResult[1] and Json.canonical(preparedResult[1])==Json.canonical(plan) and suspensions>0,"cooperative writer preparation changed result/failed")
local cancelled=Work.new(function() return Writer.prepare(archive,anchor,codec,fresh) end,{now=now,budget=.000001,maxSeconds=100})
cancelled:step();check(cancelled.state=="pending" and cancelled:cancel() and cancelled:take()==nil,"cancelled preparation exposed writer handle")
check(Json.canonical(archive)==original,"rest writer preparation changed original archive")
print("RECOVERY_REST_WRITER passed="..count.." failed=0 suspensions="..suspensions)
end
