do
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Session=require("../src/Shared/Persistence/SaveSession")
local Progress=require("../src/Shared/Persistence/SaveProgress")
local Rules=require("../src/Shared/Data/SaveRules")
local Work=require("../src/Shared/Persistence/SaveWork")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function fixture(compressed,empty)
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 if not empty then b:poke("P_46001",Json.copy(rawProgress));b:poke("R_46001_main",if compressed then codec:encode(rest) else Json.copy(rest));b:poke("R_46001_free",{untouched="other-slot"}) end
 local clock={now=200};local cfg={backend=b,userId=46001,sessionId="runtime-A",now=function() return clock.now end,sleep=function(dt) clock.now+=dt end}
 local rt=__runtimePrototype.new(cfg,{codec=codec,rawBackend=b,template=template,context=fresh,reader={work={now=function() return 0 end}},pipeline={work={now=function() return 0 end}}})
 check(cfg.backend==b and rt.session.backend~=b and rt.session.backend.base==nil,"factory mutated caller or loaded before tracking installed")
 assert(rt:load()=="active");rt.session:enableOffers()
 check(rt.session.backend.base~=nil,"factory did not track the actual initial load acknowledgement")
 return b,clock,rt,rt.session
end
local function tick(b,clock,rt)
 local before=b.requests;rt:step();check(b.requests-before<=1,"router made multiple requests in one step")
 check(#rt.session.sched.started<=Rules.REQUESTS_PER_MINUTE,"router exceeded shared rolling allowance")
 check(not rt.busy and not rt.session.busy,"router retained a busy flag")
 if rt.session.backend.held then check(not rt.session.backend:permitted(rt.session.backend.held),"router leaked a permit") end
 clock.now+=1
end
local function drive(b,clock,rt,done)
 for _=1,1400 do if done() then return end;tick(b,clock,rt) end
 error("router did not settle in phase "..rt.phase..": "..tostring(rt.problem))
end
local function nonP(b)
 local q={};for k,v in b.data do if k~="P_46001" then q[k]=v end end;return Json.canonical(q)
end
local function offer(b,clock,rt)
 local read=assert(rt:discover("main"));drive(b,clock,rt,function() return rt.phase~="discovering" end)
 check(rt.phase=="offered" and read.state=="offered" and read.offer.protected,"router failed actual protected discovery: "..tostring(rt.problem))
 return read
end
for _,compressed in {false,true} do
 local b,clock,rt,s=fixture(compressed);local read=offer(b,clock,rt)
 local normal=s.step;local normalCalls=0;s.step=function(self) normalCalls+=1;return normal(self) end
 local original=nonP(b);local progress=Json.copy(s.progress);table.insert(progress.notebook.opened,"runtime_menu");assert(s:setProgress(progress))
 for _=1,150 do tick(b,clock,rt) end
 check(rt.phase=="offered" and clock.now-b.data.P_46001.lock.beat<31 and nonP(b)==original and s.observations.latest.main.id==read.offer.id and normalCalls==0,"offered wait lost lease/stable observation or ran ordinary worker")
 assert(rt:accept("main",1,read.offer.id));drive(b,clock,rt,function() return rt.phase~="recovering" end)
 check(rt.phase=="entry_required" and rt.result.requiresSchema3Entry and not rt.result.gameplayAuthorized,"router opened gameplay or failed recovery: "..tostring(rt.problem))
 check(s.backend.held~=nil and s.backend.held.enforced and s.recoveryOwner==rt.pipeline and s.intents.requests.main.credential==nil,"router did not rehold progress before schema-3 entry")
 local stored=nonP(b);local before=b.requests;local called=false
 check(not s.backend:update(s.pkey,function() called=true;return {} end) and not called and b.requests==before,"entry wait opened ordinary writes")
 local state,loaded=rt:load();check(state=="active" and loaded==false and rt:discover("main")==nil and not rt:dismiss() and b.requests==before,"entry wait allowed load/discovery/dismiss bypass")
 for _=1,150 do tick(b,clock,rt) end
 check(rt.phase=="entry_required" and normalCalls==0 and nonP(b)==stored and clock.now-b.data.P_46001.lock.beat<31,"entry wait changed storage or stopped lease")
 progress=Json.copy(s.progress);progress.settings.MasterVolume=.33;assert(s:setProgress(progress))
 rt:flush()
 check(rt.phase=="closed" and s.closed and rt.result.progressPreserved and b.data.P_46001.lock==nil and nonP(b)==stored,"routed recovered departure failed")
 local nextVisit=Session.new({backend=b,userId=46001,sessionId="next-runtime",now=function() return clock.now end})
 check(nextVisit:load()=="active" and table.find(nextVisit.progress.notebook.opened,"runtime_menu") and nextVisit.progress.settings.MasterVolume==.33,"next session failed global-progress load after routed recovery")
 before=b.requests;rt:step();check(b.requests==before,"closed runtime did more work")
end
-- Normal healthy visits retain their normal progress/rest flush path.
do
 local b,clock,rt,s=fixture(false,true);local q=Json.copy(s.progress);q.notebook.opened={"normal_path"};assert(s:setProgress(q))
 for _=1,40 do tick(b,clock,rt) end
 check(table.find(b.data.P_46001.payload.notebook.opened,"normal_path"),"normal worker no longer saves healthy progress")
 rt:flush();check(s.closed and b.data.P_46001.lock==nil,"normal departure did not use ordinary flush")
end
-- Dismissal before acceptance preserves the original and returns to normal.
do
 local b,clock,rt,s=fixture(false);local read=offer(b,clock,rt);local original=nonP(b)
 check(rt:dismiss() and rt.phase=="normal" and not rt.accepted,"unaccepted discovery could not be dismissed")
 local q=Json.copy(s.progress);q.notebook.opened={"dismissed_page"};assert(s:setProgress(q));rt:flush()
 check(s.closed and nonP(b)==original and table.find(b.data.P_46001.payload.notebook.opened,"dismissed_page"),"unaccepted departure changed original/lost ordinary progress")
end
-- Long cooperative discovery waits renew the existing lease without previews.
do
 local b,clock,rt,s=fixture(true);local read=assert(rt:discover("main"));local step=rt.reader.step;local remaining=150
 rt.reader.step=function(self,j) if remaining>0 then remaining-=1;return false end;return step(self,j) end
 drive(b,clock,rt,function() return rt.phase~="discovering" end)
 check(rt.phase=="offered" and read.state=="offered" and clock.now-s.sched.lastBeat<31,"long discovery lost its lease")
 rt:flush();check(s.closed and b.data.P_46001.lock==nil,"unaccepted offered departure failed")
end
-- Cancel/retry goes through actual session selection and pending M1 discovery.
do
 local b,clock,rt,s=fixture(false);local read=offer(b,clock,rt);local job=assert(rt:accept("main",1,read.offer.id))
 drive(b,clock,rt,function() return job.phase=="commit" and job.child.phase=="progress" end)
 check(rt:cancelRecovery() and rt.phase=="held","routing cancellation failed")
 for _=1,150 do tick(b,clock,rt) end
 check(rt.phase=="held" and rt.idleJob.state=="pending" and s.backend.held~=nil,"cancelled route did not maintain terminal hold")
 local nextRead=assert(rt:discover("main"));drive(b,clock,rt,function() return rt.phase~="discovering" end)
 check(rt.phase=="offered" and nextRead.pending,"held route failed actual pending proposal rediscovery")
 assert(rt:accept("main",2,nextRead.offer.id));drive(b,clock,rt,function() return rt.phase~="recovering" end)
 check(rt.phase=="entry_required","routing retry failed to rebind: "..tostring(rt.problem));rt:flush()
end
-- A read-only provider may yield, but another worker/admission must not overlap.
do
 local b,clock,rt,s=fixture(false);local read=assert(rt:discover("main"));rt:step() -- initial P lease probe
 local rawRead=b.readRawFresh;b.readRawFresh=function(self,key) if key=="R_46001_main" then coroutine.yield("reader-paused") end;return rawRead(self,key) end
 local co=coroutine.create(function() return rt:step() end);local ok,marker=coroutine.resume(co);assert(ok,marker)
 check(marker=="reader-paused" and rt.busy and s.busy,"reader was not suspended")
 local before=b.requests;check(rt:discover("main")==nil and rt:accept("main",1,"missing")==nil and not rt:step() and b.requests==before,"suspended discovery admitted overlapping work")
 local resumed=false
 rt.config.sleep=function(dt) clock.now+=dt;if not resumed then resumed=true;assert(coroutine.resume(co));b.readRawFresh=rawRead end end
 rt:flush(clock.now+3)
 check(s.closed and rt.phase=="closed" and not rt.busy and not s.busy and b.data.P_46001.lock==nil,"ordinary flush did not drain cancelled discovery")
end
-- Departure can end at its deadline even if a recovery provider never returns.
do
 local b,clock,rt,s=fixture(false);local read=offer(b,clock,rt);local job=assert(rt:accept("main",1,read.offer.id))
 drive(b,clock,rt,function() return job.phase=="commit" and job.child.phase=="progress" and job.child.child.phase=="write" and s.sched:budgetOk(clock.now) and clock.now-s.sched.lastBeat<30 end)
 local update=b.update;b.update=function(self,key,fn) coroutine.yield("recovery-paused");return update(self,key,fn) end
 local co=coroutine.create(function() return rt:step() end);local ok,marker=coroutine.resume(co);assert(ok,marker)
 check(marker=="recovery-paused" and rt.busy and s.busy,"recovery provider did not suspend")
 local before=nonP(b);rt:flush(clock.now+2)
 check(s.closed and rt.phase=="closed" and not rt.result.progressPreserved and not rt.result.leaseReleased and clock.now>=rt.departureJob.deadline,"deadline flush waited forever or falsely verified")
 local finalResult=rt.result;assert(coroutine.resume(co));b.update=update
 check(not rt.busy and not s.busy and nonP(b)==before,"late recovery provider changed stored rests/proposals after close")
 check(rt.phase=="closed" and rt.result==finalResult,"late recovery completion reopened/replaced a closed routing result")
end
for _,mode in Rules.MODES do
 for _,kind in {"rest","life"} do
  local b,clock,rt,s=fixture(false)
  if kind=="rest" then s.restPending[mode]={pending=true} else s.lifeRequests[mode]={done=false} end
  local before=b.requests;check(rt:discover("main")==nil and b.requests==before and s.backend.held==nil,"discovery admitted unrelated "..kind.." work in "..mode)
 end
end
for _,after in {false,true} do
 local b,clock,rt,s=fixture(false);local read=offer(b,clock,rt)
 if after then assert(rt:accept("main",1,read.offer.id));drive(b,clock,rt,function() return rt.phase~="recovering" end) end
 local raw=Envelope.withLock(b.data.P_46001,{session="foreign",beat=clock.now});b:poke(s.pkey,raw);clock.now+=31
 rt:step();check(rt.phase=="lost" and rt.pipeline.leaseLost and s.backend.held~=nil,"router did not fence foreign read/entry phase")
 local before=b.requests;check(rt:discover("main")==nil and rt:accept("main",2,read.offer.id)==nil and not rt:step() and b.requests==before,"lost runtime reopened ordinary recovery")
 rt:flush();check(s.closed and Json.canonical(b.data.P_46001)==Json.canonical(raw),"lost-scope departure overwrote foreign progress")
end
do
 local b,clock,rt,s=fixture(false);local read=offer(b,clock,rt);local before=b.requests
 check(rt:accept("main",1,"wrong-id")==nil and rt.phase=="offered" and b.requests==before,"stale/unrecognized offer accepted")
 local work=Work.new(function() return rt:accept("main",1,read.offer.id) end,{now=function() return 0 end})
 while work.state=="pending" do work:step() end
 check(work:take()~=nil and not rt.accepted and b.requests==before,"preparation acquired routing authority")
end
-- Discovery/offer lease faults use uncached probes rather than ordinary steps.
for _,fault in {"lost-ack","before-write","slow-ack"} do
 local b,clock,rt,s=fixture(false);offer(b,clock,rt)
 clock.now=math.max(clock.now,s.sched.lastBeat+30)
 local baseline=nonP(b);local update=b.update
 if fault=="lost-ack" then b:fail({op="update",key=s.pkey,afterWrite=true,message="timeout"})
 elseif fault=="before-write" then b:fail({op="update",key=s.pkey,message="503 unavailable"})
 else b.update=function(self,key,fn) clock.now+=60;local out=table.pack(update(self,key,fn));clock.now+=35;return table.unpack(out,1,out.n) end end
 rt:step();b.update=update
 if fault~="slow-ack" then
  check(rt.leaseJob.phase=="probe","read lease did not probe an ambiguous acknowledgement")
  for _=1,80 do tick(b,clock,rt) end
 end
 check(rt.phase=="offered" and nonP(b)==baseline and clock.now-b.data.P_46001.lock.beat<36,"read lease fault lost ownership/changed originals: "..fault)
 rt:flush();check(s.closed,"read lease fault prevented ordinary departure")
end
-- The same shutdown fence applies to a lease callback which is still yielding.
do
 local b,clock,rt,s=fixture(false);offer(b,clock,rt);clock.now=math.max(clock.now,s.sched.lastBeat+30)
 local update=b.update;b.update=function(self,key,fn) coroutine.yield("read-lease-paused");return update(self,key,fn) end
 local co=coroutine.create(function() return rt:step() end);local ok,marker=coroutine.resume(co);assert(ok,marker)
 check(marker=="read-lease-paused" and rt.busy and s.busy,"read lease did not suspend")
 local resumed=false
 rt.config.sleep=function(dt) clock.now+=dt;if not resumed then resumed=true;assert(coroutine.resume(co));b.update=update end end
 rt:flush(clock.now+3)
 check(rt.phase=="closed" and s.closed and not rt.busy and not s.busy and rt.problem==nil and b.data.P_46001.lock==nil,"late read lease reopened/errored during ordinary shutdown")
end
for _,field in {"provider","load","owner","clock"} do
 local b,clock,rt,s=fixture(false);offer(b,clock,rt);local before=b.requests
 if field=="provider" then s.backend.source=Memory.new()
 elseif field=="load" then s._loadSerial+=1
 elseif field=="owner" then s.recoveryOwner={}
 else clock.now=rt.route.lastNow-1 end
 rt:step();check(rt.phase=="lost" and rt.pipeline.leaseLost and b.requests==before,"read routing identity change made a request: "..field)
 rt:flush();check(rt.phase=="closed" and s.closed and not rt.result.progressPreserved,"changed read routing scope falsely preserved progress")
end
-- Departure may arrive before another tick can observe an epoch change. It
-- must not fall through to normal whole-snapshot merging in that old scope.
do
 local b,clock,rt,s=fixture(false);offer(b,clock,rt)
 local localProgress=Json.copy(s.progress);table.insert(localProgress.notebook.opened,"stale_scope_page");assert(s:setProgress(localProgress))
 local remote=Progress.default();remote.notebook.opened={"new_scope_page"};remote.settings.SoundMuted=true
 b:poke(s.pkey,Envelope.make(Progress.SPEC,remote,clock.now,nil,{lock={session=s.id,beat=clock.now}}))
 s._loadSerial+=1;local stored=Json.canonical(b.data);local before=b.requests
 rt:flush()
 check(s.closed and rt.phase=="closed" and not rt.result.progressPreserved and b.requests==before and Json.canonical(b.data)==stored,"direct old-scope departure reached normal flush/replayed stale choices")
end
-- Factory-bound initial loads are drained before ordinary flush, or fenced
-- after the closing deadline so they cannot create an orphaned late lease.
for _,drain in {true,false} do
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 local clock={now=200};local co;local resumed=false
 local cfg={backend=b,userId=46001,sessionId="loading-runtime",now=function() return clock.now end,sleep=function(dt)
  clock.now+=dt
  if drain and not resumed then resumed=true;assert(coroutine.resume(co)) end
 end}
 local rt=__runtimePrototype.new(cfg,{codec=codec,rawBackend=b,template=template,context=fresh});local s=rt.session
 local update=b.update;local pause=true
 b.update=function(self,key,fn) if pause then coroutine.yield("initial-load-paused") end;return update(self,key,fn) end
 co=coroutine.create(function() return rt:load() end);local ok,marker=coroutine.resume(co);assert(ok,marker)
 check(marker=="initial-load-paused" and rt.busy and not s.busy and s.backend.activeUpdates==1,"initial load did not expose the separate owner busy state")
 pause=false;rt:flush(clock.now+2)
 if drain then
  check(resumed and not rt.busy and s.closed and rt.phase=="closed" and b.data.P_46001.lock==nil,"ordinary flush did not drain the initial load")
 else
  check(not resumed and s.closed and rt.phase=="closed" and not rt.result.progressPreserved and b.data.P_46001==nil,"loading deadline started an overlapping save")
  local before=b.writes;assert(coroutine.resume(co))
  check(not rt.busy and s.backend.activeUpdates==0 and b.writes==before and b.data.P_46001==nil and rt.phase=="closed","late initial load acquired a lease after closure")
 end
 b.update=update
end
print("RECOVERY_RUNTIME passed="..count.." failed=0")
end
