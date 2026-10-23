do
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Backend=require("../src/Server/DataStoreBackend")
local Writer=__progressWriterPrototype
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local plan=assert(Writer.prepare(anchor,codec,fresh))
local function fixture(initial)
 local b=Memory.new();local ds={requests=0,log={}}
 b:poke(anchor.id,Json.copy(anchor));b:poke(plan.rkey,Json.copy(anchor.target))
 b:poke(plan.pkey,initial or Envelope.withLock(rawProgress,{session="owned",beat=190}))
 function ds:GetAsync(key,options)
  self.requests+=1;table.insert(self.log,{op="read",key=key,uncached=options~=nil and options.UseCache==false})
  if options==nil or options.UseCache~=false then error("cached verification forbidden") end
  local ok,v,e=b:read(key);if not ok then error(e) end;return v
 end
 function ds:UpdateAsync(key,fn)
  self.requests+=1;table.insert(self.log,{op="update",key=key})
  local ok,v,e=b:update(key,fn);if not ok then error(e) end;return v
 end
 local clock=200;local adapter=Backend.new(ds,{encode=function() error("P used rest codec") end,decode=function() error("raw verification used rest codec") end})
 return b,ds,Writer.new(adapter,"owned",function() return clock end),function(t) clock=t end
end
local function begin(w,p,f) return assert(w:begin(p or plan,f or function() return true end)) end
local function step(ds,w,j)
 local before=ds.requests;w:step(j);check(ds.requests-before<=1,"progress step exceeded one request")
end
local function drive(ds,w,j)
 for _=1,20 do if j.state~="pending" then return end;step(ds,w,j) end
 error("progress absorption did not settle")
end
local function env(payload,time) return Envelope.make(Progress.SPEC,payload,time,nil,{lock={session="owned",beat=190}}) end
do
 local b,ds,w=fixture();local old=Json.canonical(b.data[plan.pkey]);local r=Json.canonical(b.data[plan.rkey]);local m=Json.canonical(b.data[anchor.id]);local j=begin(w);drive(ds,w,j)
 local opened=Envelope.open(Progress.SPEC,b.data[plan.pkey],false)
 check(j.state=="globalVerified" and j.requests==4 and b.writes==1,"first absorption failed")
 check(opened.payload.notebook.opened[2]=="later_page" and opened.payload.rare.serial==p.binding.serial,"portable notebook/rare history not absorbed")
 check(opened.updatedAt==110 and b.data[plan.pkey].lock.beat==190,"absorption promoted choices to wall clock or refreshed lease")
 check(Json.canonical(b.data[plan.rkey])==r and Json.canonical(b.data[anchor.id])==m,"P writer changed rest/proposal")
 local writes=b.writes;local again=begin(w);drive(ds,w,again)
 check(again.state=="globalVerified" and b.writes==writes,"replay wrote another progress envelope")
 local backup=b.data[plan.pkey].backup
 check(backup and backup.checksum==rawProgress.checksum,"previous P primary not retained as standard backup")
 for _,op in ds.log do check(op.op~="update" or op.key==plan.pkey,"P writer updated another key");if op.op=="read" then check(op.uncached,"P verification cached") end end
end
for _,stamp in {110,150} do
 local latest=Progress.default();latest.notebook.opened={"current_page"};latest.appearance="current_skin";latest.settings={SoundMuted=true,MasterVolume=.9};latest.rare={serial=9,claimed={current_animal=9},once={current_once=true},blocked=true}
 local b,ds,w=fixture(env(latest,stamp));local j=begin(w);drive(ds,w,j);local q=assert(Envelope.open(Progress.SPEC,b.data[plan.pkey],false).payload)
 check(j.state=="globalVerified" and q.settings.SoundMuted==true and q.settings.MasterVolume==.9 and q.appearance=="current_skin","replay overwrote current/equal-time choices")
 check(q.rare.serial==9 and q.rare.claimed.current_animal==9 and q.rare.once.current_once and q.rare.blocked,"rare high-water/once/blocked history lost")
 check(#q.notebook.opened==3 and q.notebook.opened[1]=="current_page","stored-first lossless notebook union changed")
 local writes=b.writes;local again=begin(w);drive(ds,w,again);check(again.state=="globalVerified" and b.writes==writes,"merged current progress replay not idempotent")
end
do
 local b,ds,w=fixture();local first=begin(w);drive(ds,w,first)
 local q=Json.copy(b.data[plan.pkey].payload);q.settings.SoundMuted=true;q.settings.MasterVolume=.95
 b:poke(plan.pkey,env(q,110));local writes=b.writes;local j=begin(w);drive(ds,w,j)
 check(j.state=="globalVerified" and b.writes==writes and b.data[plan.pkey].payload.settings.SoundMuted==true,"same-tick later setting reverted on replay")
end
do
 local v=Progress.default();v.prefs={SoundMuted=true};v.settings=nil;v.settings_version=nil
 local spec={kind="progress",current=1,migrations={},validate=function(x) return {},x end}
 local b,ds,w=fixture(Envelope.make(spec,v,100,nil,{lock={session="owned",beat=190}}));local j=begin(w);drive(ds,w,j)
 check(j.state=="globalVerified" and b.data[plan.pkey].schema==2 and b.data[plan.pkey].payload.settings.SoundMuted==false,"supported schema1 preference mapping not composed")
end
for _,after in {false,true} do
 local b,ds,w=fixture();b:fail({op="update",key=plan.pkey,afterWrite=after,message="timeout"});local j=begin(w);drive(ds,w,j)
 if after then check(j.state=="globalVerified" and b.writes==1,"lost P ack not resolved by fresh readback")
 else check(j.state=="retry" and b.writes==0,"failed P write verified");check(w:retry(j),"P write retry refused");drive(ds,w,j);check(j.state=="globalVerified" and b.writes==1,"P retry not idempotent") end
end
do
 local b,ds,w=fixture();local j=begin(w);step(ds,w,j);step(ds,w,j);step(ds,w,j)
 b:fail({op="read",key=plan.pkey});step(ds,w,j)
 check(j.state=="retry" and b.writes==1,"P failed verification became globalVerified")
 check(w:retry(j),"P readback retry refused");drive(ds,w,j);check(j.state=="globalVerified" and b.writes==1,"readback retry wrote twice")
end
for _,mutate in {
 function(v) v.lock.session="other" end,
 function(v) v.lock.beat=80 end,
 function(v) v.lock.beat=201 end,
 function(v) v.lock.unknown=true end,
 function(v) v.unknown=true end,
 function(v) v.checksum="corrupt" end,
 function(v) v.schema=99 end,
} do
 local raw=env(Progress.default(),100);mutate(raw);local b,ds,w=fixture(raw);local before=Json.canonical(raw);local j=begin(w);drive(ds,w,j)
 check(j.state=="refused" and b.writes==0 and Json.canonical(b.data[plan.pkey])==before,"unsupported/unowned progress overwritten")
end
for _,field in {"unknown","settings","notebook","rare"} do
 local q=Progress.default()
 if field=="unknown" then q.unknown={precious=true}
 elseif field=="settings" then q.settings={FutureSetting=true}
 elseif field=="notebook" then q.notebook.unknown={precious=true}
 else q.rare={serial=1,claimed={},once={},unknown=true} end
 local raw=env(q,100);local b,ds,w=fixture(raw);local j=begin(w);drive(ds,w,j)
 check(j.state=="refused" and b.writes==0 and Json.canonical(b.data[plan.pkey])==Json.canonical(raw),"unknown payload content dropped")
end
do
 local q=Progress.default();for i=1,200 do table.insert(q.notebook.opened,"full_"..i) end
 local b,ds,w=fixture(env(q,150));local j=begin(w);drive(ds,w,j)
 check(j.state=="refused" and b.writes==0 and #b.data[plan.pkey].payload.notebook.opened==200,"notebook overflow trimmed history")
end
for _,field in {"claimed","once"} do
 local logical=codec:decode(anchor.target);logical.payload.progress.rare[field].pending_claim=if field=="claimed" then 1 else true
 local candidate=Json.copy(anchor);candidate.target=codec:encode(Envelope.make(__packetPrototype.spec("main",fresh),logical.payload,200,nil));seal(candidate)
 local pending=assert(Writer.prepare(candidate,codec,fresh));local q=Progress.default();q.rare={serial=64,claimed={},once={}}
 for i=1,64 do q.rare[field]["old_"..i]=if field=="claimed" then i else true end
 local b,ds,w=fixture(env(q,150));b:poke(anchor.id,candidate);b:poke(plan.rkey,candidate.target);local j=begin(w,pending);drive(ds,w,j)
 check(j.state=="refused" and b.writes==0,"rare union overflow was truncated/blocked instead of lossless refusal")
end
for _,key in {plan.pkey,plan.rkey,anchor.id} do
 local b,ds,w=fixture();b:poke(key,nil);local j=begin(w);drive(ds,w,j)
 check(j.state=="refused" and b.writes==0 and b.data[key]==nil,"missing dependency was defaulted")
end
do
 local b,ds,w=fixture();local j=begin(w);step(ds,w,j);step(ds,w,j)
 local update=ds.UpdateAsync
 ds.UpdateAsync=function(self,key,fn)
  local discarded=fn(Json.copy(b.data[key]));check(discarded~=nil,"first P callback did not prepare union")
  local changed=Envelope.withLock(b.data[key],{session="takeover",beat=200});b:poke(key,changed);return update(self,key,fn)
 end
 drive(ds,w,j);check(j.state=="refused" and b.writes==0 and b.data[plan.pkey].lock.session=="takeover","replayed P callback wrote across lease takeover")
end
do
 local b,ds,w=fixture();local j=begin(w);step(ds,w,j);step(ds,w,j)
 local update=ds.UpdateAsync
 ds.UpdateAsync=function(self,key,fn)
  local q=Progress.default();q.notebook.opened={"concurrent_page"};q.settings={MasterVolume=.8};b:poke(key,env(q,160));return update(self,key,fn)
 end
 drive(ds,w,j);check(j.state=="globalVerified" and b.data[plan.pkey].payload.notebook.opened[1]=="concurrent_page" and b.data[plan.pkey].payload.settings.MasterVolume==.8,"callback merged stale P instead of latest")
end
do
 local b,ds,w,setTime=fixture();local j=begin(w);step(ds,w,j);step(ds,w,j);setTime(310);drive(ds,w,j)
 check(j.state=="refused" and b.writes==0,"expired lease allowed P absorption")
end
do
 local b,ds,w=fixture();local live=true;local j=begin(w,nil,function() return live end);step(ds,w,j);step(ds,w,j)
 local update=ds.UpdateAsync;ds.UpdateAsync=function(self,key,fn) live=false;return update(self,key,fn) end
 drive(ds,w,j);check(j.state=="refused" and b.writes==0,"revoked P callback wrote")
end
do
 local b,ds,w=fixture();local j=begin(w);step(ds,w,j);step(ds,w,j)
 local update=ds.UpdateAsync;ds.UpdateAsync=function(self,key,fn) w:cancel(j);return update(self,key,fn) end
 step(ds,w,j);check(j.state=="cancelled" and b.writes==0 and not w:retry(j),"cancelled P operation resurrected")
 check(w:begin(Json.copy(plan),function() return true end)==nil,"forged progress preparation handle accepted")
end
check(Json.canonical(archive)==original,"progress writer changed original archive")
print("RECOVERY_PROGRESS_WRITER passed="..count.." failed=0")
end
