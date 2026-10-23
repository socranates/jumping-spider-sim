do
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local SaveSession=require("../src/Shared/Persistence/SaveSession")
local Base=__progressBaselinePrototype
local Owner=__pipelinePrototype
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function tick(b,clock,s,component,j)
 local before=b.requests;component:step(j)
 check(b.requests-before<=1,"owner step made more than one request")
 check(#s.sched.started<=10,"owner exceeded shared minute quota")
 if j.startCount then check(j.requests<=component.maxRequests,"combined request cap exceeded") end
 if s.backend.held then check(not s.backend:permitted(s.backend.held),"recovery permit leaked after step") end
 clock.now+=1
end
local function drive(b,clock,s,c,j,hook)
 for _=1,1000 do
  if j.state~="pending" then return end
  if hook then hook() end
  tick(b,clock,s,c,j)
 end
 error("recovery owner did not settle")
end
local function fixture(compressed,options)
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 b:poke("P_46001",Json.copy(rawProgress));b:poke("R_46001_main",if compressed then codec:encode(rest) else Json.copy(rest));b:poke("R_46001_free",{unselected="preserved"})
 local wrapped=Base.new(b,"46001");local clock={now=200}
 local s=SaveSession.new({backend=wrapped,userId=46001,sessionId="pipeline-A",now=function() return clock.now end})
 assert(s:load()=="active");s:enableOffers()
 local reader=__offerReaderPrototype.new(s,codec,fresh,{work={now=function() return 0 end}});local discovered=assert(reader:begin("main"));drive(b,clock,s,reader,discovered);assert(discovered.state=="offered",discovered.problem)
 assert(s:requestLife("continue","main",1,discovered.offer.id))
 local cfg=options or {};cfg.work=cfg.work or {now=function() return 0 end}
 local owner=Owner.new(s,codec,b,template,fresh,cfg);local j=assert(owner:begin("main",1,discovered.offer.id,discovered))
 return b,clock,s,wrapped,owner,j,discovered
end
local function archives(b) return Json.canonical({b.data.A1_46001_progress,b.data.A1_46001_main,b.data.A1_46001_free,b.data.A1_46001_easy,b.data.A1_46001_index}) end
for _,compressed in {false,true} do
 local b,clock,s,w,c,j=fixture(compressed);local other=Json.canonical(b.data.R_46001_free);drive(b,clock,s,c,j)
 check(j.state=="rebound" and j.result.requiresSchema3Entry and not j.result.gameplayAuthorized,"combined cold owner failed: "..tostring(j.problem))
 check(w.held==nil and s.recoveryOwner==nil and s.progress.rare.serial>=1,"successful owner did not adopt/release progress")
 check(Json.canonical(b.data.R_46001_free)==other and s.intents.requests.main.credential==nil,"owner changed another slot/granted rest authority")
 check(j.work==nil and j.component==nil and j.anchor==nil and not s.busy and not c.busy,"completed owner retained staging/busy state")
 print("RECOVERY_PIPELINE cold_compressed="..tostring(compressed).." requests="..j.requests.." simulated_seconds="..(clock.now-j.started))
end
do
 local b,clock,s,w,c,j=fixture(false);local before=b.requests;local called=false
 local ok=w:update("P_46001",function() called=true;return {} end)
 local other=w:update("R_46001_free",function() called=true;return {} end)
 check(not ok and not other and not called and b.requests==before,"unscoped ordinary P/R write reached backend")
 local ran,why=w:run(j.held,function() error("intentional owner error") end)
 check(not ran and string.find(why,"intentional owner error")~=nil and not w:permitted(j.held),"failed scoped call leaked a permit")
 local co=coroutine.create(function() return w:run(j.held,function() coroutine.yield("scope-held");return true end) end)
 assert(coroutine.resume(co));check(not w:permitted(j.held),"another coroutine inherited owner permit");assert(coroutine.resume(co))
 check(not w:permitted(j.held),"resumed scope leaked permit")
 drive(b,clock,s,c,j);check(j.state=="rebound","owner failed after isolated permission probes")
end
do
 local b,clock,s,w,c,j,oldDiscovery=fixture(false)
 for _=1,900 do
  if j.phase=="commit" and j.child.phase=="progress" then break end
  tick(b,clock,s,c,j);assert(j.state=="pending",j.problem)
 end
 check(b.data.M1_46001_main~=nil and j.phase=="commit","fixture missed post-rest interruption")
 local saved=Json.canonical(b.data.M1_46001_main);local original=archives(b)
 check(c:cancel(j) and w.held~=nil and s.recoveryOwner==c,"cancellation released unsafe ordinary writes")
 -- Reuse the original displayed observation on purpose: storage admission must
 -- discover M1 rather than trust this now-stale cold/pending flag.
 assert(s:requestLife("continue","main",2,oldDiscovery.offer.id))
 local resumed=assert(c:begin("main",2,oldDiscovery.offer.id,oldDiscovery));drive(b,clock,s,c,resumed)
 check(resumed.state=="rebound" and Json.canonical(b.data.M1_46001_main)==saved and archives(b)==original,"stale-offer resume recomputed proposal/changed archive: "..tostring(resumed.problem))
end
do
 local b,clock,s,w,c,j=fixture(true);local changed=false
 drive(b,clock,s,c,j,function()
  if not changed and j.phase=="apply" then changed=true;local q=Json.copy(s.progress);q.settings.MasterVolume=.42;assert(s:setProgress(q)) end
 end)
 check(changed and j.state=="rebound" and s.progress.settings.MasterVolume==.42 and s.sched:isDirty("progress"),"owner failed to retry stale local-adoption plan")
end
do
 local b,clock,s,w,c,j=fixture(false,{maxRequests=2});drive(b,clock,s,c,j)
 check(j.state=="refused" and j.requests==2 and w.held~=nil and j.result.requiresPausedWorker,"combined cap did not retain protected ownership")
 local before=b.requests;local ok=w:update("P_46001",function() return {} end)
 check(not ok and b.requests==before,"failed owner silently resumed ordinary P writes")
end
do
 local b,clock,s,w,c,j=fixture(false,{timeout=2});drive(b,clock,s,c,j)
 check(j.state=="refused" and string.find(j.problem,"deadline")~=nil and b.data.M1_46001_main==nil,"combined deadline not enforced")
end
do
 local b,clock,s,w,c,j=fixture(false);b:fail({op="read",key="M1_46001_main",times=1,message="503: unavailable"});drive(b,clock,s,c,j)
 check(j.state=="rebound","admission read retry/default handling failed")
end
do
 local b,clock,s,w,c,j=fixture(false);local taken=false
 drive(b,clock,s,c,j,function()
  if not taken and j.phase=="witnessP" then taken=true;b:poke("P_46001",Envelope.withLock(b.data.P_46001,{session="takeover",beat=clock.now})) end
 end)
 check(taken and j.state=="refused" and w.held~=nil and not j.result.gameplayAuthorized,"fresh adoption witness accepted foreign lease")
end
print("RECOVERY_PIPELINE passed="..count.." failed=0")
end
