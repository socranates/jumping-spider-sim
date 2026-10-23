do
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local SaveSession=require("../src/Shared/Persistence/SaveSession")
local Progress=require("../src/Shared/Persistence/SaveProgress")
local Work=require("../src/Shared/Persistence/SaveWork")
local Base=__progressBaselinePrototype
local Rebind=__sessionRebindPrototype
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function drive(b,clock,s,c,j,hook)
 for _=1,900 do
  if j.state~="pending" then return end
  if hook then hook() end
  local before=b.requests;c:step(j)
  check(b.requests-before<=1,"rebind fixture controller exceeded one request")
  clock.now+=1
 end
 error("rebind fixture did not settle")
end
local function fixture(changeLocal,changeRemote)
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 b:poke("P_46001",Json.copy(rawProgress));b:poke("R_46001_main",Json.copy(anchor.target));b:poke(anchor.id,Json.copy(anchor))
 b:poke("A1_46001_progress",{format=__archiveStorePrototype.FORMAT,version=1,owner="46001",index=archive.index,progress=archive.entries.progress})
 for _,slot in {"main","free","easy"} do b:poke("A1_46001_"..slot,Json.copy(archive.entries[slot])) end
 b:poke("A1_46001_index",{format=__archiveStorePrototype.FORMAT,version=1,owner="46001",complete=true,index=archive.index})
 local wrapped=Base.new(b,"46001");local clock={now=200}
 local s=SaveSession.new({backend=wrapped,userId=46001,sessionId="rebind-A",now=function() return clock.now end})
 assert(s:load()=="active");s:enableOffers()
 local reader=__offerReaderPrototype.new(s,codec,fresh,{work={now=function() return 0 end}});local read=assert(reader:begin("main"));drive(b,clock,s,reader,read);assert(read.state=="offered",read.problem)
 assert(s:requestLife("continue","main",1,read.offer.id));local held=assert(wrapped:hold(s));local beforeBase=Json.canonical(held.base)
 local c=__commitControllerPrototype.new(s,codec,b,template,fresh,{work={now=function() return 0 end}});local j=assert(c:begin("main",1,read.offer.id,read.archivePlan))
 local changed=false
 drive(b,clock,s,c,j,function()
  if not changed and j.phase=="progress" then
   changed=true
   if changeLocal then changeLocal(s,clock) end
   if changeRemote then
    local q=Progress.default();q.notebook.opened={"remote_page"};q.settings={SoundMuted=true,MasterVolume=.9}
    changeRemote(q)
    b:poke("P_46001",Envelope.make(Progress.SPEC,q,clock.now,nil,{lock=Json.copy(b.data.P_46001.lock)}))
   end
  end
 end)
 assert(j.state=="verified",j.problem)
 check(Json.canonical(held.base)==beforeBase and Json.canonical(wrapped.latest)~=beforeBase,"recovery writes replaced held pre-recovery baseline")
 return b,clock,s,wrapped,held,read.offer.id,j.result.anchor
end
local function prepare(s,held,offerId,a)
 local t=assert(Rebind.capture(s,held,"main",1,offerId))
 local ok,praw=s.backend:readRawFresh("P_46001");assert(ok)
 local good,rraw=s.backend:readRawFresh("R_46001_main");assert(good)
 return t,assert(Rebind.prepare(t,a,praw,rraw,codec,fresh)),praw,rraw
end
do
 local b,clock,s,w,held,id,a=fixture(function(s)
  local q=Json.copy(s.progress);table.insert(q.notebook.opened,"local_page");assert(s:setProgress(q))
 end,function() end)
 local t,plan,praw=prepare(s,held,id,a)
 local naive=Progress.merge(praw.payload,s.progress,praw.updatedAt,s.progressTime)
 check(naive.settings.SoundMuted==false and plan.progress.settings.SoundMuted==true,"stale whole-snapshot counterexample missing/rebind reverted stored setting")
 check(plan.progress.settings.MasterVolume==.9 and table.find(plan.progress.notebook.opened,"local_page")~=nil and plan.dirty,"three-way merge lost remote choice/local page")
 local writes=b.writes;local oldR=Json.canonical(b.data.R_46001_main)
 local ok,result=Rebind.apply(plan)
 check(ok and not result.gameplayAuthorized and result.requiresSchema3Entry and result.entryKind=="rest","local adoption granted gameplay/failed")
 check(b.writes==writes and Json.canonical(b.data.R_46001_main)==oldR and s.intents.requests.main.credential==nil,"local rebind wrote a key/granted credential")
 check(s.progress.settings.SoundMuted==true and s.sched:isDirty("progress") and held.used and w.held==nil,"local progress/held baseline not adopted")
 check(not Rebind.apply(plan),"rebind plan reused")
 local done=false
 for _=1,120 do
  local q=b.data.P_46001.payload
  if table.find(q.notebook.opened,"local_page") then done=true;break end
  s:step();clock.now+=1
 end
 check(done and b.data.P_46001.payload.settings.SoundMuted==true and b.data.P_46001.payload.settings.MasterVolume==.9,"ordinary P save replayed stale choices after rebind")
 check(Json.canonical(b.data.R_46001_main)==oldR and s.intents.requests.main.credential==nil,"ordinary P resumption granted/wrote a rest")
end
do
 local b,clock,s,w,held,id,a=fixture(function(s)
  local q=Json.copy(s.progress);q.settings.SoundMuted=true;q.appearance="local_skin";assert(s:setProgress(q))
 end,function(q) q.settings.SoundMuted=false end)
 local t,plan,praw=prepare(s,held,id,a)
 check(s.progressTime==praw.updatedAt and plan.progress.settings.SoundMuted==true and plan.progress.appearance=="local_skin","same-tick genuinely changed local choices lost")
 check(plan.progress.settings.MasterVolume==.9,"unchanged/missing local setting replaced remote value")
 check(Rebind.apply(plan) and s.progress.settings.SoundMuted==true,"changed choice adoption failed")
end
do
 local b,clock,s,w,held,id,a=fixture(nil,nil)
 s.sched:markDirty("progress",clock.now) -- its observation is already covered
 local t,plan=prepare(s,held,id,a);check(not plan.dirty,"covered snapshot still needs an unnecessary P write")
 local ok,result=Rebind.apply(plan)
 check(ok and not s.sched:isDirty("progress") and s.progress.rare.serial>=1 and s.storedTime==b.data.P_46001.updatedAt,"covered progress not synchronized/acknowledged")
end
do
 local b,clock,s,w,held,id,a=fixture(nil,nil);local t,plan=prepare(s,held,id,a)
 local q=Json.copy(s.progress);q.settings.MasterVolume=.4;assert(s:setProgress(q));local current=s.progress
 check(not Rebind.apply(plan) and s.progress==current and w.held==held and not held.used,"late local input was overwritten or baseline released")
 check(not Rebind.apply(plan),"stale failed plan could retry invisibly")
 local nextTicket,nextPlan=prepare(s,held,id,a);check(Rebind.apply(nextPlan) and s.progress.settings.MasterVolume==.4,"explicit fresh preparation lost late choice")
end
do
 local b,clock,s,w,held,id,a=fixture(nil,nil);local t=assert(Rebind.capture(s,held,"main",1,id))
 local _,praw=w:readRawFresh("P_46001");local _,rraw=w:readRawFresh("R_46001_main")
 local wrong=Json.copy(praw);wrong.lock.session="other"
 check(Rebind.prepare(t,a,wrong,rraw,codec,fresh)==nil,"foreign progress lease adopted")
 wrong=Json.copy(praw);wrong.lock.beat=1
 check(Rebind.prepare(t,a,wrong,rraw,codec,fresh)==nil,"expired progress observation adopted")
 wrong=Json.copy(praw);wrong.future=true
 check(Rebind.prepare(t,a,wrong,rraw,codec,fresh)==nil,"unknown envelope protocol adopted")
 check(Rebind.prepare(t,a,Envelope.withLock(rawProgress,{session=s.id,beat=clock.now}),rraw,codec,fresh)==nil,"unabsorbed global proposal adopted")
 check(Rebind.prepare(t,a,praw,second.target,codec,fresh)==nil,"different target bytes adopted")
 local plan=assert(Rebind.prepare(t,a,praw,rraw,codec,fresh));clock.now+=121
 check(not Rebind.apply(plan) and w.held==held,"expired final observation applied")
end
do
 local b,clock,s,w,held,id,a=fixture(nil,nil);local t,plan=prepare(s,held,id,a)
 assert(w:update("P_46001",function(old) return Envelope.withLock(old,{session=s.id,beat=clock.now}) end))
 check(not Rebind.apply(plan) and w.held==held,"intervening P operation did not invalidate prepared rebind")
end
do
 local b=Memory.new();b.readRawFresh=b.read;b.readFresh=b.read;local w=Base.new(b,"900")
 local first=Envelope.make(Progress.SPEC,Progress.default(),1,nil);assert(w:update("P_900",function() return first end))
 local before=w.base;b:fail({op="update",key="P_900",afterWrite=true,message="timeout"})
 local ok=w:update("P_900",function() return Envelope.make(Progress.SPEC,Progress.default(),2,nil) end)
 check(not ok and w.base==before and w.acknowledged==1,"ambiguous write advanced acknowledged baseline")
 local plain=b.update;local suspended=true
 b.update=function(self,key,fn) local ok,v,e=plain(self,key,fn);if suspended then suspended=false;coroutine.yield() end;return ok,v,e end
 local older=coroutine.create(function() w:update("P_900",function() return Envelope.make(Progress.SPEC,Progress.default(),3,nil) end) end)
 assert(coroutine.resume(older));assert(w:update("P_900",function() return Envelope.make(Progress.SPEC,Progress.default(),4,nil) end));assert(coroutine.resume(older))
 check(w.base.updatedAt==4 and w.acknowledged==4,"older delayed acknowledgement replaced newer baseline")
end
do
 local b,clock,s,w,held,id,a=fixture(nil,nil);local t=assert(Rebind.capture(s,held,"main",1,id))
 local _,praw=w:readRawFresh("P_46001");local _,rraw=w:readRawFresh("R_46001_main")
 local ticks=0;local function now() ticks+=.000001;return ticks end
 local worker=Work.new(function() return Rebind.prepare(t,a,praw,rraw,codec,fresh) end,{now=now,budget=.000001,maxSeconds=100,maxResumes=10000})
 worker:step();check(worker.state=="pending","cooperative rebind fixture did not yield")
 local q=Json.copy(s.progress);q.settings.MasterVolume=.3;assert(s:setProgress(q));local current=s.progress
 while worker.state=="pending" do worker:step() end
 local result=worker:take()
 check(result and result[1]==nil and s.progress==current and w.held==held,"in-flight local input became visible as a partial rebind")
end
print("RECOVERY_SESSION_REBIND passed="..count.." failed=0")
end
