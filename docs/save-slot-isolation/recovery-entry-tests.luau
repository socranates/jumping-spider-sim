do
local function runEntryChecks()
local Entry=__entryPrototype;local Client=__entryClientPrototype
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Rules=require("../src/Shared/Data/SaveRules")
local Mating=require("../src/Shared/Life/Mating")
local Mate=require("../src/Shared/Predator/Mate")
local Work=require("../src/Shared/Persistence/SaveWork")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function equal(a,b) return Json.canonical(a)==Json.canonical(b) end
local function fixture(mode,stage,options)
 mode=mode or "main";stage=stage or "none"
 WorldMap.use("test_garden");local old=gardenWorld();old.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
 old.life.mode=if mode=="free" then "free" else "main";old.life.rules=if mode=="main" then "standard" else "gentle";old.needs.gentle=mode~="main"
 if stage~="none" then
  old.life.growth.stage=3;old.life.mating=Mating.new();old.life.mating.stage=stage;old.life.mate=Mate.new()
  if stage=="courted" then old.life.mate.state="pair";old.life.mate.scene=true;old.life.mate.meter=1 end
  if stage=="hatched" then old.life.mating.hatch_day=old.life.clock.day;old.life.mating.hatch_hour=7;old.life.mating.brood=3 end
 end
 local src=assert(Checkpoint.capture(old,123));src.save_life="entry-life-"..mode.."-"..stage
 WorldMap.use("preserve");local context=newWorld();context.life.mode=old.life.mode;context.life.rules=old.life.rules;context.needs.gentle=mode~="main"
 local target=assert(Checkpoint.capture(context,124))
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 local rkey="R_46001_"..mode
 local gp=Json.copy(rawProgress.payload);if mode=="easy" then gp.finished_main=true end
 b:poke("P_46001",Envelope.make(Progress.SPEC,gp,rawProgress.updatedAt,nil));b:poke(rkey,codec:encode(Envelope.make(SaveRest.SPECS[mode],src,100,nil)))
 local clock={now=200};local decisions=0
 local deps={codec=codec,rawBackend=b,template=target,context=context,reader={work={now=function() return 0 end}},pipeline={work={now=function() return 0 end}},entryFactory=Entry,entryOptions=options or {work={now=function() return 0 end}}}
 local rt=__runtimePrototype.new({backend=b,userId=46001,sessionId="entry-"..mode.."-"..stage,now=function() return clock.now end,sleep=function(dt) clock.now+=dt end,
  onDecision=function(d) if d.state=="writable" then decisions+=1 end end},deps)
 assert(rt:load()=="active");local s=rt.session;s:enableOffers();assert(rt:discover(mode))
 for _=1,1400 do if rt.phase~="discovering" then break end;rt:step();clock.now+=1 end
 assert(rt.phase=="offered",rt.problem);assert(rt:accept(mode,1,rt.discovery.offer.id))
 for _=1,1400 do if rt.phase~="recovering" then break end;rt:step();clock.now+=1 end
 assert(rt.phase=="entry_required",rt.problem)
 local clientWorld=newWorld();clientWorld.life.mode=old.life.mode;clientWorld.life.rules=old.life.rules;clientWorld.needs.gentle=mode~="main"
 return {b=b,clock=clock,rt=rt,s=s,mode=mode,rkey=rkey,context=context,world=clientWorld,current=true,decisions=function() return decisions end}
end
local function tick(f)
 local n=f.b.requests;f.rt:step()
 check(f.b.requests-n<=1,"entry router made multiple requests in one step")
 check(#f.s.sched.started<=Rules.REQUESTS_PER_MINUTE,"entry exceeded rolling quota")
 check(not f.rt.busy and not f.s.busy,"entry retained busy flags")
 check(not f.s.backend:permitted(f.s.backend.held),"entry leaked scoped permit")
 f.clock.now+=1
end
local function drive(f,done)
 for _=1,1500 do if done() then return end;tick(f) end
 error("entry failed to settle: "..f.rt.phase.."/"..tostring(f.rt.entryJob and f.rt.entryJob.phase).." "..tostring(f.rt.problem))
end
local function offered(f)
 local j=assert(f.rt:enter());drive(f,function() return j.state~="pending" or j.phase=="awaitApplied" end)
 assert(j.state=="pending",j.problem);return j
end
local function apply(f,j)
 local before=fingerprint(f.world)
 local commit,why=Client.prepare(j.offer,f.world,function() return f.current end);assert(commit,why)
 check(fingerprint(f.world)==before and f.s.intents.requests[f.mode].credential==nil,"entry preparation changed world or granted authority")
 local ack,errorText=commit();assert(ack,errorText)
 check(commit()==nil,"prepared entry applied twice")
 return ack
end
for _,mode in Rules.MODES do
 for _,stage in {"none","courted","hatched"} do
  local f=fixture(mode,stage);local stored=Json.canonical(f.b.data[f.rkey]);local j=offered(f)
  check(j.offer.entryKind==(if stage=="courted" then "mating" elseif stage=="hatched" then "hatching" else "rest"),"entry scene differs")
  check(f.rt.phase=="entering" and f.decisions()==0 and f.s.intents.requests[mode].state=="readonly","entry granted before application")
  local ack=apply(f,j)
  check(f.world.life.recoveryHistory~=nil and f.world.life.mode==(if mode=="free" then "free" else "main") and f.world.needs.gentle==(mode~="main"),"actual checkpoint restore lost history or mode")
  if stage~="none" then check(f.world.life.mating.stage==stage,"actual scene restore lost mating/hatching state") end
  check(f.rt:entryApplied(ack) and not f.rt:entryApplied(ack),"entry acknowledgement not exact/single-use")
  drive(f,function() return f.rt.phase~="entering" end)
  check(f.rt.phase=="recovered" and j.state=="verified" and f.rt.result.gameplayAuthorized and not f.rt.result.requiresSchema3Entry,"entry did not grant actual life: "..tostring(j.problem))
  local r=f.s.intents.requests[mode]
  check(f.s.intents:authorized(mode,r.serial,r.credential,j.result.current.save_life) and f.decisions()==1,"entry failed actual intent grant/decision")
  check(j.prepared==nil and j.parts==nil and j.rawProgress==nil and j.result.checkpoint==j.result.current.checkpoint,"completed entry retained duplicate preparation graphs")
  check(Json.canonical(f.b.data[f.rkey])==stored and f.s.backend.held.enforced,"entry changed rest or dropped ordinary-write barrier")
  local before=f.b.requests;local called=false
  check(not f.s.backend:update(f.s.pkey,function() called=true;return {} end) and not called and f.b.requests==before,"recovered route opened ordinary P writes")
  local record=assert(Checkpoint.capture(f.world,f.clock.now));record.save_life=r.life
  local writer=__currentWriterPrototype.new(f.s,f.b,codec,f.context)
  local capture=assert(writer:capture(mode,r.serial,r.credential,r.life,1))
  local plan=assert(writer:prepare(capture,j.result.archive,j.result.anchor,f.b.data[f.rkey],record))
  local saved=assert(writer:begin(plan))
  for _=1,300 do if saved.state~="pending" then break end;writer:step(saved);f.clock.now+=1 end
  check(saved.state=="verified","real entry credential could not save continuation: "..tostring(saved.problem))
  -- Runtime remains the owner for idle and departure; no concurrent writer.
  for _=1,70 do tick(f) end
  check(f.rt.phase=="recovered" and f.decisions()==1,"idle route reopened normal worker/regranted")
  f.rt:flush();check(f.s.closed and f.rt.phase=="closed" and f.rt.result.progressPreserved and f.b.data.P_46001.lock==nil,"recovered departure failed")
 end
end
for _,fault in {"part","index","proposal","rest","progress","revoked","closed","provider","epoch"} do
 local f=fixture();local j=assert(f.rt:enter())
 if fault=="part" then f.b:poke("A1_46001_main",{lost=true})
 elseif fault=="index" then f.b:poke("A1_46001_index",{complete=false})
 elseif fault=="proposal" then f.b:poke("M1_46001_main",{invalid=true})
 elseif fault=="rest" then f.b:poke(f.rkey,{invalid=true})
 elseif fault=="progress" then f.b:poke(f.s.pkey,Envelope.withLock(f.b.data[f.s.pkey],{session="other",beat=f.clock.now}))
 elseif fault=="revoked" then f.s.intents:changed(f.s.intents.requests.main,"new choice")
 elseif fault=="closed" then f.s.closed=true
 elseif fault=="provider" then f.s.backend.source=Memory.new()
 else f.s._loadSerial+=1 end
 for _=1,400 do if f.rt.phase~="entering" or j.state~="pending" then break end;tick(f) end
 check(f.decisions()==0 and f.s.intents.requests.main.credential==nil,"broken entry granted: "..fault)
end
do
 local f=fixture();local j=offered(f);local ack=apply(f,j)
 for _,edit in {function(m) m.id="stale" end,function(m) m.epoch="old" end,function(m) m.mode="free" end,function(m) m.serial+=1 end,function(m) m.revision+=1 end,function(m) m.identity.updatedAt+=1 end,function(m) m.extra=true end} do
  local changed=Json.copy(ack);edit(changed);check(not f.rt:entryApplied(changed),"mismatched applied receipt accepted")
 end
 assert(f.rt:cancelEntry());check(not f.rt:entryApplied(ack) and f.decisions()==0,"cancelled entry accepted old receipt")
 check(j.prepared==nil and j.parts==nil and j.rawRest==nil and j.offer==nil,"cancelled entry retained prepared graphs")
 local nextJob=offered(f);check(nextJob.nonce~=j.nonce and not f.rt:entryApplied(ack),"retry reused entry identity")
 f.rt:flush();check(f.s.closed and f.decisions()==0,"departure during application granted life")
end
for _,fault in {"rest-after-apply","owner-after-apply","clock","deadline","client-selection"} do
 local f=fixture();local j=offered(f);local ack=apply(f,j)
 if fault=="client-selection" then
  local commit=assert(Client.prepare(j.offer,f.world,function() return f.current end));f.current=false
  check(commit()==nil,"stale client selection applied")
  f.rt:cancelEntry()
 else
  assert(f.rt:entryApplied(ack))
  if fault=="rest-after-apply" then f.b:poke(f.rkey,{changed=true})
  elseif fault=="owner-after-apply" then f.b:poke(f.s.pkey,Envelope.withLock(f.b.data[f.s.pkey],{session="other",beat=f.clock.now}))
  elseif fault=="clock" then f.clock.now-=1
  else f.clock.now=j.deadline end
  drive(f,function() return f.rt.phase~="entering" end)
 end
 check(f.decisions()==0 and f.s.intents.requests.main.credential==nil,"late/changed application was granted: "..fault)
 check(j.prepared==nil and j.parts==nil and j.offer==nil,"invalidated entry retained prepared graphs: "..fault)
end
do
 local f=fixture();local j=assert(f.rt:enter());local read=f.b.readRawFresh
 f.b.readRawFresh=function(self,key) if key=="M1_46001_main" then coroutine.yield("entry-read-paused") end;return read(self,key) end
 while not f.s.sched:budgetOk(f.clock.now) do f.clock.now+=1 end
 -- A due metadata renewal takes its own step before entry reads.
 while j.requests==0 do
  local co=coroutine.create(function() return f.rt:step() end);local ok,marker=coroutine.resume(co);assert(ok,marker)
  if marker=="entry-read-paused" then
   check(f.rt.busy and f.s.busy,"entry read did not hold busy flags")
   f.rt:flush(f.clock.now+2);assert(coroutine.resume(co))
   check(f.s.closed and f.rt.phase=="closed" and f.decisions()==0 and not f.s.busy and not f.rt.busy,"late entry read reopened closed route")
   break
  end
  f.clock.now+=1
 end
end
do
 local f=fixture();local j=offered(f);local ack=apply(f,j);assert(f.rt:entryApplied(ack))
 f.s.intents.emit=function(d)
  if d.state=="writable" then coroutine.yield("decision-paused") end
 end
 local co
 for _=1,300 do
  co=coroutine.create(function() f.rt:step() end);local ok,marker=coroutine.resume(co);assert(ok,marker)
  if marker=="decision-paused" then break end;f.clock.now+=1
 end
 check(f.rt.phase=="recovered" and f.rt.busy,"route was not committed before decision notification")
 f.rt:flush(f.clock.now+2);local outcome=f.rt.result;assert(coroutine.resume(co))
 check(f.s.closed and f.rt.phase=="closed" and f.rt.result==outcome and not f.rt.busy,"late decision callback reopened/replaced departure")
end
do
 local f=fixture();local j=offered(f)
 for _=1,100 do tick(f) end
 check(j.phase=="awaitApplied" and f.rt.phase=="entering" and f.clock.now-f.b.data.P_46001.lock.beat<31 and f.decisions()==0,"waiting client lost lease or gained premature permission")
 local ack=apply(f,j);assert(f.rt:entryApplied(ack))
 f.b:fail({op="read",key=f.rkey,message="503 unavailable"})
 drive(f,function() return f.rt.phase~="entering" end)
 check(f.rt.phase=="recovered" and f.decisions()==1,"final uncached read retry failed")
end
do
 local f=fixture();local j=offered(f);local original=fingerprint(f.world)
 local time=0;local work=Work.new(function() return Client.prepare(j.offer,f.world,function() return f.current end) end,{now=function() time+=.001;return time end,budget=.003,maxSeconds=120,maxResumes=20000})
 while work.state=="pending" do work:step() end
 local result=assert(work:take());check(result[1]~=nil and work.resumes>1 and fingerprint(f.world)==original,"cooperative preparation mutated world or failed")
 f.current=false;check(result[1]()==nil and fingerprint(f.world)==original,"superseded cooperative application changed world")
 local bad=Json.copy(j.offer);bad.entryKind="wrong";check(Client.prepare(bad,f.world,function() return true end)==nil,"incorrect client scene accepted")
 bad=Json.copy(j.offer);bad.checkpoint=nil;check(Client.prepare(bad,f.world,function() return true end)==nil,"missing client checkpoint accepted")
end
do
 local f=fixture(nil,nil,{maxRequests=1});local j=assert(f.rt:enter());drive(f,function() return f.rt.phase~="entering" end)
 check(j.state=="refused" and j.requests==1 and f.decisions()==0,"entry cap failed")
end
print("RECOVERY_ENTRY passed="..count.." failed=0")
end
runEntryChecks()
end
