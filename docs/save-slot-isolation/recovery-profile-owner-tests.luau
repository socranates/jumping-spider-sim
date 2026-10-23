do
local function runProfileOwnerChecks()
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Rules=require("../src/Shared/Data/SaveRules")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function nonP(b)
 local out={};for key,value in b.data do if key~="P_46001" then out[key]=value end end
 return Json.canonical(out)
end
local function fixture(options)
 options=options or {}
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 local profiles={};local sources={}
 for _,mode in Rules.MODES do
  WorldMap.use("test_garden");local old=gardenWorld();old.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
  old.life.mode=if mode=="free" then "free" else "main";old.life.rules=if mode=="main" then "standard" else "gentle";old.needs.gentle=mode~="main"
  local record=assert(Checkpoint.capture(old,120));record.save_life="profile-original-"..mode;sources[mode]=record
  if options.empty~=mode then b:poke("R_46001_"..mode,codec:encode(Envelope.make(SaveRest.SPECS[mode],record,100,nil))) end
  WorldMap.use("preserve");local context=newWorld();context.garden={}
  context.life.mode=old.life.mode;context.life.rules=old.life.rules;context.needs.gentle=mode~="main"
  profiles[mode]={context=context,template=assert(Checkpoint.capture(context,124))}
 end
 local progress=Json.copy(rawProgress.payload);progress.finished_main=not options.lockedEasy
 b:poke("P_46001",Envelope.make(Progress.SPEC,progress,100,nil))
 local clock={now=200};local messages={};local f={b=b,clock=clock,profiles=profiles,sources=sources,messages=messages}
 local common={codec=codec,rawBackend=b,currentFormat=__restFormatPrototype,entryFactory=__entryPrototype,saveFactory=__saveLoopPrototype,
  reader={work={now=function() return 0 end}},pipeline={reuseCompleteOriginal=true,work={now=function() return 0 end}},
  entryOptions={work={now=function() return 0 end}},saveOptions={work={now=function() return 0 end},progress={work={now=function() return 0 end}}}}
 local owner=__profileOwnerPrototype.new({backend=b,userId=46001,sessionId="profiles-A",now=function() return clock.now end,sleep=function(dt) clock.now+=dt end},
  function(msg) table.insert(messages,msg) end,common,profiles)
 f.owner=owner;f.s=owner.session;f.rt=owner.runtime
 check(owner:load()=="active","profile load refused")
 owner:enableOffers();if not options.oldPeer then owner:enableRecovery() end
 f.original=nonP(b);f.originalSlots={}
 for _,mode in Rules.MODES do f.originalSlots[mode]=Json.canonical(b.data["R_46001_"..mode]) end
 f.session=owner.session;f.scheduler=owner.session.sched;f.backend=owner.session.backend
 f.observations=f.s.observations;f.intents=f.s.intents
 function f.tick()
  local before=b.requests;owner:step()
  check(b.requests-before<=1,"profile owner issued parallel/batched requests")
  check(#f.s.sched.started<=Rules.REQUESTS_PER_MINUTE,"profile owner multiplied the request quota")
  check(owner.session==f.session and f.s.sched==f.scheduler and f.s.backend==f.backend and f.s.observations==f.observations and f.s.intents==f.intents,"profile switch replaced session/quota/observation identity")
  check(not owner.busy and not f.rt.busy and not f.s.busy,"profile worker retained busy lock")
  clock.now+=1
 end
 function f.drive(done)
  for _=1,1800 do if done() then return end;f.tick() end
  error("profile did not settle: "..f.rt.phase.." "..tostring(f.rt.problem).." "..tostring(owner.problem))
 end
 function f.all()
  f.drive(function()
   for _,mode in Rules.MODES do if options.empty~=mode and not f.s:offer(mode) then return false end end
   return f.rt.phase=="offered" and next(owner.queue)==nil
  end)
 end
 return f
end
-- All slots become visible in one visit, with one owner and stable offer IDs.
do
 local f=fixture();f.all();local ids={}
 for _,mode in Rules.MODES do ids[mode]=f.s:offer(mode).id;check(f.s:offer(mode).protected,"slot was not protected") end
 check(nonP(f.b)==f.original,"read-only discovery touched rest/archive/proposal bytes")
 for _=1,12 do for _,mode in Rules.MODES do assert(f.owner:refreshOffer(mode)) end end
 f.all()
 for _,mode in Rules.MODES do check(f.s:offer(mode).id==ids[mode],"unchanged slot was withdrawn or assigned another offer ID") end
 check(nonP(f.b)==f.original and not f.rt.accepted,"menu refresh accepted or changed a rest")
 check(f.owner.profiles.main.template~=f.profiles.main.template and table.isfrozen(f.owner.profiles.main.template),"server template was not an owned immutable copy")
end
-- Each selection must re-read the exact displayed offer with its own captured
-- destination, never merely change runtime.recovery.context after new().
for _,mode in Rules.MODES do
 local f=fixture();f.all();local offer=f.s:offer(mode)
 check(f.owner:requestLife("continue",mode,1,offer.id),"profile Continue refused")
 check(not f.rt.accepted,"Continue was accepted without a new read")
 f.drive(function() return f.rt.phase=="entering" and f.rt.entryJob.phase=="awaitApplied" end)
 check(f.rt.pipeline.context==f.profiles[mode].context and f.rt.pipeline.template==f.owner.profiles[mode].template,"pipeline retained another profile")
 local job=f.rt.entryJob;local world=newWorld();world.garden={}
 world.life.mode=if mode=="free" then "free" else "main";world.life.rules=if mode=="main" then "standard" else "gentle";world.needs.gentle=mode~="main"
 local commit,why=__entryClientPrototype.prepare(job.offer,world,function() return true end);assert(commit,why)
 local ack=assert(commit());check(f.owner:applyRecovery(ack),"profile rejected exact applied receipt")
 f.drive(function() return f.rt.phase=="recovered" end)
 local r=f.s.intents.requests[mode]
 check(r.state=="writable" and world.life.mode==(if mode=="free" then "free" else "main") and world.needs.gentle==(mode~="main"),"selected profile did not become its own playable life")
 for _,other in Rules.MODES do
  if other~=mode then
   check(Json.canonical(f.b.data["R_46001_"..other])==f.originalSlots[other],"selected recovery wrote another current slot: "..mode.." -> "..other)
   for _,request in f.b.log do check(request.op~="update" or request.key~="R_46001_"..other,"request log contains another slot update") end
  end
 end
 print("RECOVERY_PROFILE mode="..mode.." one_session=true fresh_selection=true matching_pipeline=true entry_granted=true")
end
-- Rapid cross-slot choices are globally ordered, even though SaveIntent itself
-- intentionally keeps per-slot serials. Idempotent retries do not start work.
do
 local f=fixture();f.all();local main,free,easy=f.s:offer("main"),f.s:offer("free"),f.s:offer("easy")
 assert(f.owner:requestLife("continue","main",3,main.id))
 assert(f.owner:requestLife("continue","free",4,free.id))
 check(not f.owner:requestLife("continue","easy",3,easy.id),"cross-slot stale serial accepted")
 check(not f.owner:requestLife("continue","easy",4,easy.id),"same serial was reused for another slot")
 check(f.s.intents.requests.main.state=="changed","superseded Main intent remained authorizable")
 check(f.owner:requestLife("continue","free",4,free.id),"exact retry refused")
 f.drive(function() return f.rt.accepted end)
 check(f.rt.job.ticket.mode=="free" and f.rt.job.ticket.serial==4,"older choice won acceptance")
end
-- The old provider is still suspended when a different slot is chosen. Its
-- completion cannot publish, rebind, start a second provider or gain authority.
do
 local f=fixture();f.all();local main,free=f.s:offer("main"),f.s:offer("free")
 assert(f.owner:requestLife("continue","main",1,main.id));f.tick()
 local old=f.rt.discovery;local read=f.b.readRawFresh;local paused=false
 f.b.readRawFresh=function(self,key)
  if key=="R_46001_main" and not paused then paused=true;coroutine.yield("profile-read-paused") end
  return read(self,key)
 end
 local co=coroutine.create(function() return f.owner:step() end)
 for _=1,100 do
  local ok,marker=coroutine.resume(co);assert(ok,marker)
  if marker=="profile-read-paused" then break end
  check(coroutine.status(co)=="dead","unexpected profile yield");f.clock.now+=1
  co=coroutine.create(function() return f.owner:step() end)
 end
 check(paused and f.rt.busy and f.s.busy,"fixture did not suspend actual read")
 assert(f.owner:requestLife("continue","free",2,free.id))
 local pipeline=f.rt.pipeline;local before=f.b.requests
 check(not f.owner:step() and f.b.requests==before and f.rt.pipeline==pipeline,"new choice rebound during yielded read")
 local ok,why=coroutine.resume(co);assert(ok,why)
 check(old.state=="cancelled" and f.s:offer("main").id==main.id,"late read published or withdrew an existing offer")
 f.drive(function() return f.rt.accepted end)
 check(f.rt.job.ticket.mode=="free" and f.s.intents.requests.main.state=="changed","drained Main read defeated Free choice")
end
-- A displayed identity changing before the fresh selection read is never an
-- invitation to silently import the new identity.
do
 local f=fixture();f.all();local displayed=f.s:offer("main")
 local replacement=Json.copy(f.sources.main);replacement.save_life="external-change"
 f.b:poke("R_46001_main",codec:encode(Envelope.make(SaveRest.SPECS.main,replacement,101,nil)))
 assert(f.owner:requestLife("continue","main",1,displayed.id))
 f.drive(function() return f.s.intents.requests.main.state=="changed" end)
 check(not f.rt.accepted and f.s:offer("main").id~=displayed.id and f.b.data.A1_46001_progress==nil,"changed displayed offer was automatically accepted")
end
-- Before acceptance, a new ordinary empty-slot choice can drain discovery and
-- resume the same normal worker. After acceptance, replacement remains gated.
do
 local f=fixture({empty="free"});f.all();local before=Json.canonical(f.b.data.R_46001_main)
 assert(f.owner:requestLife("new","free",1,nil))
 f.drive(function() local r=f.s.intents.requests.free;return r and r.state=="writable" end)
 check(f.rt.phase=="normal" and Json.canonical(f.b.data.R_46001_main)==before and f.b.data.A1_46001_progress==nil,"ordinary empty choice changed protected Main")
end
do
 local f=fixture();f.all();local main,free=f.s:offer("main"),f.s:offer("free")
 assert(f.owner:requestLife("continue","main",1,main.id))
 f.drive(function() return f.rt.phase=="entering" and f.rt.entryJob.phase=="awaitApplied" end)
 local oldOffer=Json.copy(f.rt.entryJob.offer)
 local ack={kind="recovery_applied",v=oldOffer.v,id=oldOffer.id,epoch=oldOffer.epoch,mode=oldOffer.mode,serial=oldOffer.serial,revision=oldOffer.revision,identity=oldOffer.identity}
 assert(f.owner:requestLife("continue","free",2,free.id))
 check(not f.owner:applyRecovery(ack) and f.owner.switchRequired,"late prior-slot receipt accepted")
 local preserved=nonP(f.b)
 for _=1,150 do f.tick() end
 check(f.rt.phase=="held" and f.s.backend.held~=nil and f.s.intents.requests.main.credential==nil and f.s.intents.requests.free.credential==nil,
  "post-write switch escaped owned hold: "..f.rt.phase.."/"..tostring(f.rt.problem))
 check(nonP(f.b)==preserved and f.clock.now-f.b.data.P_46001.lock.beat<Rules.LOCK_STALE,"replacement wait changed rests/archive or abandoned its lease")
 f.owner:flush(f.clock.now+15)
 check(f.s.closed and f.rt.phase=="closed" and f.b.data.P_46001.lock==nil and nonP(f.b)==preserved,"replacement hold did not take closed departure")
end
do
 local f=fixture({lockedEasy=true});f.all();local easy=f.s:offer("easy")
 check(not f.owner:requestLife("continue","easy",1,easy.id) and f.owner.lastChoiceSerial==0,"ineligible Easy consumed choice serial")
end
do
 local f=fixture({oldPeer=true});for _=1,6 do f.tick() end
 check(f.rt.discovery==nil and not f.rt.accepted and f.b.data.A1_46001_progress==nil,"old peer started profile discovery")
end
-- A decision callback can choose again while older requests are being revoked.
-- The outer revocation loop must immediately give way to that newer choice.
do
 local f=fixture();f.all();local main,free,easy=f.s:offer("main"),f.s:offer("free"),f.s:offer("easy")
 assert(f.owner:requestLife("continue","main",1,main.id))
 assert(f.owner:requestLife("continue","free",2,free.id))
 local reentered=false
 f.s.intents.emit=function(message)
  if not reentered and message.mode=="free" and message.reason=="choice_superseded" then
   reentered=true;assert(f.owner:requestLife("continue","easy",4,easy.id))
  end
 end
 assert(f.owner:requestLife("continue","main",3,main.id))
 check(reentered and f.owner.choice.mode=="easy" and f.s.intents.requests.easy.state=="readonly","outer callback revoked a newer choice")
 f.drive(function() return f.rt.accepted end)
 check(f.rt.job.ticket.mode=="easy" and f.rt.job.ticket.serial==4,"reentrant later choice was not the accepted choice")
end
do
 local f=fixture()
 local invalid={main=f.profiles.main,free=f.profiles.free}
 local ok=pcall(__profileOwnerPrototype.new,{},function() end,{},invalid)
 check(not ok,"incomplete trusted profile catalog was admitted")
 invalid.easy=f.profiles.easy;invalid.client_supplied=f.profiles.main
 ok=pcall(__profileOwnerPrototype.new,{},function() end,{},invalid)
 check(not ok,"unknown profile key was admitted")
end
print("RECOVERY_PROFILE_OWNER passed="..count.." failed=0")
end
runProfileOwnerChecks()
end
