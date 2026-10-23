do
local function runStartupChecks()
local Budget=__startupBudgetPrototype
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Rules=require("../src/Shared/Data/SaveRules")
local Work=require("../src/Shared/Persistence/SaveWork")
local count=0;local serial=0
local function check(ok,why) assert(ok,why);count+=1 end
local function equal(a,b) return Json.canonical(a)==Json.canonical(b) end
local function bare(clock,gate,user)
 serial+=1;local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 local rt=__runtimePrototype.new({backend=b,userId=user or 46001,sessionId="startup-policy-"..serial,now=function() return clock.now end,sleep=function(dt) clock.now+=dt end},
  {codec=codec,rawBackend=b,template=template,context=fresh,currentFormat=__restFormatPrototype,entryFactory=__entryPrototype,saveFactory=__saveLoopPrototype,startupBudget=gate})
 return rt,rt.session,rt.startup
end
local function policy(clock,query,options,user)
 local gate=Budget.new(query,function() return clock.now end,options);local rt,s,t=bare(clock,gate,user)
 -- Scheduler-only tests model initial-load admission, not storage authority.
 rt.loading=true;s._loadSerial=1
 return gate,rt,s,t
end
do
 local clock={now=200};local q=0
 local gate,rt,s,t=policy(clock,function() q+=1;return 100,100 end)
 for _=1,100 do check(s.sched:budgetOk(clock.now),"valid budget poll refused") end
 check(q==1 and t.used==0 and #s.sched.started==0,"polling consumed requests/credits or repeatedly called engine")
 for _=1,20 do check(s.sched:budgetOk(clock.now),"startup allowance ended early");s.sched:begin(nil,clock.now) end
 check(t.used==20 and gate.granted==20 and #s.sched.started==20 and not s.sched:budgetOk(clock.now),"startup allowance unbounded or history erased")
 t:close("playable entry verified",true);rt.loading=false;rt.phase="recovered"
 for _=1,10 do check(s.sched:budgetOk(clock.now),"successful startup charged gameplay debt");s.sched:begin(nil,clock.now) end
 check(not s.sched:budgetOk(clock.now) and t.used==20 and #t.normal==10 and #s.sched.started==30,"ordinary ten-request allowance changed or startup restarted")
 clock.now+=61;check(s.sched:budgetOk(clock.now) and #s.sched.started==0,"rolling request history did not prune")
 check(not pcall(gate.attach,gate,rt),"scheduler accepted a second startup attachment")
 local other=Budget.new(function() return 100,100 end,function() return clock.now end)
 local untouched=bare(clock,gate,46009)
 check(not pcall(other.attach,other,untouched),"another owner attached to the same untouched scheduler")
end
for _,case in {
 {name="no-observer",query=nil,expected=0},
 {name="read-low",query=function() return 4,100 end,expected=0},
 {name="write-low",query=function() return 100,4 end,expected=0},
 {name="one-credit",query=function() return 5,5 end,expected=1},
 {name="invalid",query=function() return 0/0,100 end,expected=0},
 {name="error",query=function() error("unsupported budget enum") end,expected=0},
 {name="yield",query=function() coroutine.yield("must-not-yield") end,expected=0},
} do
 local clock={now=200};local gate,rt,s,t=policy(clock,case.query)
 local admitted=0
 for _=1,30 do if not s.sched:budgetOk(clock.now) then break end;s.sched:begin(nil,clock.now);admitted+=1 end
 check(t.used==case.expected and admitted==10 and t.forcedRequests==0,"missing/unsafe native budget accelerated beyond baseline: "..case.name)
end
do
 local clock={now=200};local gate=Budget.new(function() return 100,100 end,function() return clock.now end)
 local _,s1,t1=bare(clock,gate,46001);local rt1=t1.runtime;rt1.loading=true;s1._loadSerial=1
 local rt2,s2,t2=bare(clock,gate,46002);rt2.loading=true;s2._loadSerial=1
 local rt3,s3,t3=bare(clock,gate,46003);rt3.loading=true;s3._loadSerial=1
 for _=1,20 do assert(s1.sched:budgetOk(clock.now));s1.sched:begin(nil,clock.now) end
 for _=1,20 do assert(s2.sched:budgetOk(clock.now));s2.sched:begin(nil,clock.now) end
 for _=1,10 do assert(s3.sched:budgetOk(clock.now));s3.sched:begin(nil,clock.now) end
 check(t1.used==20 and t2.used==20 and t3.used==0 and #gate.started==40 and not s3.sched:budgetOk(clock.now),"shared server cap was exceeded")
end
do
 local clock={now=200};local gate=Budget.new(function() return 100,100 end,function() return clock.now end)
 local rt,s,t=bare(clock,gate);rt.loading=true;s._loadSerial=1
 s.sched:begin(nil,clock.now);t:close("done",true)
 local nextRt,nextS,nextT=bare(clock,gate);nextRt.loading=true;nextS._loadSerial=1
 nextS.sched:begin(nil,clock.now)
 check(nextT.used==0,"same-timestamp new session bypassed user cooldown")
 clock.now+=61;local later,laterS,laterT=bare(clock,gate);later.loading=true;laterS._loadSerial=1;laterS.sched:begin(nil,clock.now)
 check(laterT.used==1,"new visit did not regain startup eligibility after cooldown")
end
for _,fault in {"expired","closed","provider","load","writable","clock"} do
 local clock={now=200};local gate,rt,s,t=policy(clock,function() return 100,100 end)
 for _=1,8 do assert(s.sched:budgetOk(clock.now));s.sched:begin(nil,clock.now) end
 if fault=="expired" then clock.now+=46 elseif fault=="closed" then s.closed=true
 elseif fault=="provider" then s.backend.source=Memory.new() elseif fault=="load" then s._loadSerial=2
 elseif fault=="writable" then s.intents.requests.main={state="writable"} else clock.now-=1 end
 s.sched:budgetOk(clock.now)
 check(t.closed and not t.success and t.used==8 and #t.normal==8,"failed startup lost ordinary debt or retained credits: "..fault)
end
do
 local clock={now=200};local gate,rt,s,t=policy(clock,function() return 100,100 end)
 local before=gate.queries;local work=Work.new(function() return s.sched:budgetOk(clock.now) end,{now=function() return 0 end})
 while work.state=="pending" do work:step() end
 check(work:take()[1]==false and gate.queries==before and t.used==0,"preparation probed/admitted engine budget")
 local other=Budget.new(function() return 100,100 end,function() return clock.now+.0001 end)
 local fr,fs,ft=bare(clock,other,46004);fr.loading=true;fs._loadSerial=1;fs.sched:begin(nil,clock.now)
 check(ft.used==1,"matching fractional clocks were incorrectly refused")
end
-- Full returning-session tests use the actual load, current reader, archive
-- proof, client checkpoint application, grant and ordinary post-entry saving.
local function full(queryMode)
 local b=Memory.new();local clock={now=200};local native={read=100,write=100}
 local read,update=b.read,b.update
 b.read=function(self,key) native.read-=1;return read(self,key) end
 b.update=function(self,key,fn) native.read-=1;native.write-=1;return update(self,key,fn) end
 b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 local packet=assert(__packetPrototype.open(anchor,codec,fresh))
 local current=assert(__restFormatPrototype.fromProposal(anchor,codec,fresh))
 b:poke("P_46001",Envelope.make(Progress.SPEC,packet.progress,199,nil));b:poke("R_46001_main",codec:encode(Envelope.make(__restFormatPrototype.spec("main",fresh),current,199,nil)))
 b:poke("M1_46001_main",Json.copy(anchor))
 b:poke("A1_46001_progress",{format=__archiveStorePrototype.FORMAT,version=1,owner="46001",index=archive.index,progress=archive.entries.progress})
 for _,slot in {"main","free","easy"} do b:poke("A1_46001_"..slot,Json.copy(archive.entries[slot])) end
 b:poke("A1_46001_index",{format=__archiveStorePrototype.FORMAT,version=1,owner="46001",complete=true,index=archive.index})
 local query=if queryMode=="healthy" then function() return native.read,native.write end elseif queryMode=="low" then function() return 0,0 end else nil
 local gate=Budget.new(query,function() return clock.now end)
 local stored=0
 local rt=__runtimePrototype.new({backend=b,userId=46001,sessionId="startup-full-"..queryMode,now=function() return clock.now end,sleep=function(dt) clock.now+=dt end,onStored=function() stored+=1 end},
  {codec=codec,rawBackend=b,template=template,context=fresh,currentFormat=__restFormatPrototype,entryFactory=__entryPrototype,saveFactory=__saveLoopPrototype,startupBudget=gate,
   reader={work={now=function() return 0 end}},entryOptions={work={now=function() return 0 end}},saveOptions={work={now=function() return 0 end},progress={work={now=function() return 0 end}}}})
 local s=rt.session
 local function tick()
  local n=b.requests;rt:step()
  check(b.requests-n<=1 and not rt.busy and not s.busy,"startup router overlapped requests or retained busy state")
  local t=rt.startup
  check(t.used<=20 and #gate.started<=40 and t.forcedRequests==0,"startup/global bounds or ordinary admission bypassed")
  if s.backend.held then check(not s.backend:permitted(s.backend.held),"startup leaked backend permit") end
  clock.now+=1
 end
 local function drive(done)
  for _=1,600 do if done() then return end;tick() end;error("startup did not settle: "..rt.phase.." "..tostring(rt.problem))
 end
 local raw=Json.canonical(b.data.R_46001_main);local archiveText=Json.canonical(b.data.A1_46001_progress);local begun=b.requests;local born=clock.now
 assert(rt:load()=="active");s:enableOffers();assert(rt:discover("main"));drive(function() return rt.phase~="discovering" end)
 assert(rt.phase=="offered",rt.problem);assert(rt:accept("main",1,rt.discovery.offer.id));local j=assert(rt:enter())
 drive(function() return j.state~="pending" or j.phase=="awaitApplied" end);assert(j.state=="pending",j.problem)
 local world=newWorld();local commit=assert(__entryClientPrototype.prepare(j.offer,world,function() return true end));assert(rt:entryApplied(assert(commit())))
 drive(function() return rt.phase~="entering" end)
 check(rt.phase=="recovered" and rt.startup.closed and (queryMode~="healthy" or rt.startup.success),"startup did not terminate at actual playable entry")
 check(Json.canonical(b.data.R_46001_main)==raw and Json.canonical(b.data.A1_46001_progress)==archiveText,"startup relaxed restoration proof or changed originals")
 print("RECOVERY_STARTUP case="..queryMode.." requests="..(b.requests-begun).." simulated_seconds="..(clock.now-born).." startup_requests="..rt.startup.used)
 if queryMode=="healthy" then check(clock.now-born<30 and b.requests-begun<=20 and rt.startup.used>10,"budget headroom did not remove minute-long wait")
 else check(rt.startup.used==0 and clock.now-born>=60,"unsupported/empty budget accelerated startup") end
 local q=Json.copy(s.progress);q.settings.MasterVolume=.44;assert(s:setProgress(q))
 local r=s.intents.requests.main;world.life:step(.1,{inRetreat=true,attached=true,still=true,holding=false,feeding=false,position=world.motor.pos},false,false)
 local record=assert(Checkpoint.capture(world,clock.now));record.save_life=r.life
 assert(rt:saveRecovered("main",r.serial,r.credential,r.life,1,record))
 drive(function() return stored==1 or rt.phase~="recovered" end)
 check(rt.phase=="recovered" and stored==1 and b.data.P_46001.payload.settings.MasterVolume==.44,"ordinary saving failed after startup lane closed")
 check(rt.startup.used<=20 and #rt.startup.normal<=Rules.REQUESTS_PER_MINUTE,"startup budget reopened during gameplay")
 rt:flush();check(s.closed and rt.result.progressPreserved and b.data.P_46001.lock==nil,"startup-enabled departure lost progress")
end
full("healthy");full("low");full("unknown")
print("RECOVERY_STARTUP passed="..count.." failed=0")
end
runStartupChecks()
end
