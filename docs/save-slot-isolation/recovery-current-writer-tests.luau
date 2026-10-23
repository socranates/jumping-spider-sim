do
local function runCurrentWriterChecks()
local Writer=__currentWriterPrototype
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Rules=require("../src/Shared/Data/SaveRules")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function equal(a,b) return Json.canonical(a)==Json.canonical(b) end
local function fixture(options)
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 b:poke("P_46001",Json.copy(rawProgress));b:poke("R_46001_main",codec:encode(rest));b:poke("R_46001_free",{untouched="other-slot"})
 local clock={now=200};local receipts=0
 local rt=__runtimePrototype.new({backend=b,userId=46001,sessionId="current-writer",now=function() return clock.now end,sleep=function(dt) clock.now+=dt end,
  onStored=function() receipts+=1 end},{codec=codec,rawBackend=b,template=template,context=fresh,reader={work={now=function() return 0 end}},pipeline={work={now=function() return 0 end}}})
 assert(rt:load()=="active");local s=rt.session;s:enableOffers();assert(rt:discover("main"))
 for _=1,1400 do if rt.phase~="discovering" then break end;rt:step();clock.now+=1 end
 assert(rt.phase=="offered",rt.problem);assert(rt:accept("main",1,rt.discovery.offer.id))
 for _=1,1400 do if rt.phase~="recovering" then break end;rt:step();clock.now+=1 end
 assert(rt.phase=="entry_required",rt.problem)
 local a=b.data.M1_46001_main;local initial=assert(__restFormatPrototype.fromProposal(a,codec,fresh))
 local sources={};for _,slot in __packetArchive.SLOTS do
  local entry=if slot=="progress" then b.data.A1_46001_progress.progress else b.data["A1_46001_"..slot]
  sources[slot]={loaded=true,value=entry.raw}
 end
 local arc=assert(__packetArchive.prepare("46001",b.data.A1_46001_index.index.observation,sources))
 local w=Writer.new(s,b,codec,fresh,options)
 local r=s.intents.requests.main
 check(w:capture("main",r.serial,"no-entry-credential",initial.save_life,1)==nil and r.state=="readonly","read-only runtime gained a write credential")
 -- Explicit test-only permission through the actual intent owner. No schema3
 -- gameplay entry is implemented by this fixture, Runtime, or writer.
 assert(s.intents:grant(r,initial.save_life))
 local live=newWorld();assert(Checkpoint.restore(initial.checkpoint,live))
 live.life:step(.1,{inRetreat=true,attached=true,still=true,holding=false,feeding=false,position=live.motor.pos},false,false)
 local record=assert(Checkpoint.capture(live,clock.now));record.save_life=initial.save_life
 local function prepare(serial,prior,current)
  local handle=assert(w:capture("main",r.serial,r.credential,r.life,serial))
  return assert(w:prepare(handle,arc,a,prior or b.data.R_46001_main,current or record))
 end
 return {b=b,clock=clock,rt=rt,s=s,r=r,w=w,a=a,arc=arc,initial=initial,live=live,record=record,prepare=prepare,receipts=function() return receipts end}
end
local function tick(f,j)
 local before=f.b.requests;f.w:step(j)
 check(f.b.requests-before<=1,"multiple requests in one writer step")
 check(#f.s.sched.started<=Rules.REQUESTS_PER_MINUTE,"writer exceeded shared rolling quota")
 check(not f.s.busy and not f.w.busy and not f.s.backend:permitted(f.s.backend.held),"writer leaked busy state or permit")
 f.clock.now+=1
end
local function drive(f,j,phase)
 for _=1,400 do if j.state~="pending" or phase and j.phase==phase then return end;tick(f,j) end
 error("writer did not settle: "..j.phase)
end
local function untouched(f)
 local q={};for k,v in f.b.data do if k~=f.s.pkey and k~=f.s.rkey.main then q[k]=v end end;return Json.canonical(q)
end
do
 local f=fixture();local plan=f.prepare(1);local original=untouched(f)
 check(table.isfrozen(plan) and table.isfrozen(plan.candidate) and table.isfrozen(plan.anchor),"prepared plan is mutable")
 check(not pcall(function() plan.candidate={} end),"prepared root could be replaced")
 check(f.w:prepare({},f.arc,f.a,f.b.data.R_46001_main,f.record)==nil,"forged capture was accepted")
 local j=assert(f.w:begin(plan));check(f.w:begin(plan)==nil,"preparation was reused")
 drive(f,j)
 check(j.state=="verified" and j.result.stored and not j.result.gameplayAuthorized,"current rest not verified: "..tostring(j.problem))
 check(equal(f.b.data.R_46001_main,plan.candidate) and untouched(f)==original,"selected rest incorrect or immutable artifacts changed")
 check(f.r.storedSerial==1 and f.receipts()==1,"missing/duplicate exact stored receipt")
 for _=1,5 do tick(f,j) end
 check(f.receipts()==1 and f.w:capture("main",1,f.r.credential,f.r.life,1)==nil,"terminal replay/old serial accepted")
 local p2=f.prepare(2);local j2=assert(f.w:begin(p2));drive(f,j2)
 check(j2.state=="verified" and equal(p2.expected,p2.candidate) and f.receipts()==2,"exact no-op rest/backup was not preserved")
 f.live.life:step(.2,{inRetreat=true,attached=true,still=true,holding=false,feeding=false,position=f.live.motor.pos},false,false)
 local nextRecord=assert(Checkpoint.capture(f.live,f.clock.now));nextRecord.save_life=f.r.life
 local p3=f.prepare(3,nil,nextRecord);local j3=assert(f.w:begin(p3));drive(f,j3)
 check(j3.state=="verified" and not equal(p3.expected,p3.candidate) and untouched(f)==original,"subsequent continuation failed")
 local op=Envelope.open(__restFormatPrototype.spec("main",fresh),codec:decode(f.b.data.R_46001_main))
 check(op.status=="ok" and __restFormatPrototype.matchesProposal(op.payload,f.a,codec,fresh),"continued rest lost provenance")
end
for _,fault in {"rest-lost-ack","rest-no-write","lease-lost-ack","readback-fail"} do
 local f=fixture();local p=f.prepare(1);local j=assert(f.w:begin(p));local original=untouched(f)
 local target=if fault=="lease-lost-ack" then "lease" elseif fault=="readback-fail" then "readback" else "write"
 drive(f,j,target);assert(j.state=="pending",j.problem)
 if fault=="readback-fail" then f.b:fail({op="read",key=f.s.rkey.main,message="503 unavailable"})
 else f.b:fail({op="update",key=if fault=="lease-lost-ack" then f.s.pkey else f.s.rkey.main,afterWrite=fault~="rest-no-write",message="timeout"}) end
 tick(f,j);drive(f,j)
 check(j.state=="verified" and f.receipts()==1 and untouched(f)==original,"ambiguous service outcome not safely resolved: "..fault.." "..tostring(j.problem))
end
for _,fault in {"proposal","archive","rest","foreign-lease","expired-lease","rare-uncovered","revoked","closed","provider","load","intent","clock","cancel"} do
 local f=fixture();local p=f.prepare(1);local j=assert(f.w:begin(p));local before=Json.canonical(f.b.data.R_46001_main)
 if fault=="proposal" then f.b:poke(f.a.id,{changed=true})
 elseif fault=="archive" then f.b:poke("A1_46001_index",{changed=true})
 elseif fault=="rest" then f.b:poke(f.s.rkey.main,{foreign=true});before=Json.canonical(f.b.data.R_46001_main)
 elseif fault=="foreign-lease" then f.b:poke(f.s.pkey,Envelope.withLock(f.b.data[f.s.pkey],{session="foreign",beat=f.clock.now}))
 elseif fault=="expired-lease" then f.clock.now+=Rules.LOCK_STALE
 elseif fault=="rare-uncovered" then
  local old=f.b.data[f.s.pkey];local q=Json.copy(old.payload);q.rare.serial=0;q.rare.claimed={}
  f.b:poke(f.s.pkey,Envelope.make(Progress.SPEC,q,old.updatedAt,nil,{lock=old.lock}))
 elseif fault=="revoked" then f.s.intents:readonly(f.r,"test revocation")
 elseif fault=="closed" then f.s.closed=true
 elseif fault=="provider" then f.s.backend.source=Memory.new()
 elseif fault=="load" then f.s._loadSerial+=1
 elseif fault=="intent" then f.s.intents.requests.main=Json.copy(f.r)
 elseif fault=="clock" then f.clock.now-=1
 else assert(f.w:cancel(j)) end
 drive(f,j)
 check(j.state~="verified" and f.receipts()==0 and Json.canonical(f.b.data.R_46001_main)==before,"invalidated writer acknowledged/overwrote: "..fault)
end
-- Lease ownership can change after a committed R; final read must suppress ACK,
-- without an unsafe compensating write into another owner's rest.
do
 local f=fixture();local p=f.prepare(1);local j=assert(f.w:begin(p));drive(f,j,"finalLease")
 assert(j.state=="pending",j.problem);local written=Json.canonical(f.b.data.R_46001_main)
 f.b:poke(f.s.pkey,Envelope.withLock(f.b.data[f.s.pkey],{session="new-owner",beat=f.clock.now}))
 drive(f,j);check(j.state=="refused" and f.receipts()==0 and Json.canonical(f.b.data.R_46001_main)==written,"post-write takeover acknowledged or rolled back")
end
for _,phase in {"lease","write","readback"} do
 local f=fixture();local p=f.prepare(1);local j=assert(f.w:begin(p));drive(f,j,phase)
 while not f.s.sched:budgetOk(f.clock.now) do f.clock.now+=1 end
 local before=Json.canonical(f.b.data.R_46001_main);local fn=if phase=="write" then f.b.updateRaw elseif phase=="lease" then f.b.update else f.b.readRawFresh
 local function pause(self,...) coroutine.yield("writer-paused");return fn(self,...) end
 if phase=="write" then f.b.updateRaw=pause elseif phase=="lease" then f.b.update=pause else f.b.readRawFresh=pause end
 local co=coroutine.create(function() f.w:step(j) end);local ok,marker=coroutine.resume(co);assert(ok,marker)
 check(marker=="writer-paused" and f.s.busy and f.w.busy,"provider did not suspend at "..phase)
 local requests=f.b.requests;check(not f.w:step(j) and f.b.requests==requests,"concurrent step overlapped provider")
 f.s.closed=true;assert(coroutine.resume(co))
 check(j.state=="refused" and f.receipts()==0 and not f.s.busy and not f.w.busy and Json.canonical(f.b.data.R_46001_main)==before,"late provider wrote/acknowledged after close: "..phase)
end
do
 local f=fixture({maxRequests=1});local j=assert(f.w:begin(f.prepare(1)));drive(f,j)
 check(j.state=="refused" and j.requests==1 and f.receipts()==0,"request cap failed")
end
do
 local f=fixture({timeout=1});local j=assert(f.w:begin(f.prepare(1)));drive(f,j)
 check(j.state=="refused" and f.receipts()==0,"deadline failed")
 check(not pcall(Writer.new,f.s,Memory.new(),codec,fresh),"unrelated physical store was accepted")
end
print("RECOVERY_CURRENT_WRITER passed="..count.." failed=0")
end
runCurrentWriterChecks()
end
