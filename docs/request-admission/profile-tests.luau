local groups=0
local function test(name,fn) local before=count;fn();groups+=1;print("PROFILE_ADMISSION_CASE",name,count-before) end
local function lanes(f)
 local r=f.rt.recovery
 check(f.s.ordinaryAdmission==f.lane and r.reader.admission==f.lane and r.pipeline.admission==f.lane
  and f.rt.pipeline.options.admission==f.lane and r.entryOptions.admission==f.lane and r.saveOptions.admission==f.lane
  and r.saveOptions.progress.admission==f.lane and r.saveOptions.rest.admission==f.lane and r.lifecycleAdmission==f.lane,
  "profile rebind dropped account lane")
end
local function finish(f)
 f.owner:flush(f.clock.now+24);f.g:close(f.scope)
 local q=f.g:inspect();check(q.queued==0 and q.started==0,"profile retained admission/native work")
end
local function originals(f)
 local rows={};for key,value in f.b.data do if string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_" then rows[key]=value end end
 return Json.canonical(rows)
end
local function applied(f,mode)
 f.drive(function() return f.rt.phase=="entering" and f.rt.entryJob.phase=="awaitApplied" end)
 local job=f.rt.entryJob;local world=newWorld();world.garden={}
 world.life.mode=if mode=="free" then "free" else "main";world.life.rules=if mode=="main" then "standard" else "gentle";world.needs.gentle=mode~="main"
 local commit,why=__entryClientPrototype.prepare(job.offer,world,function() return true end);assert(commit,why)
 check(f.owner:applyRecovery(assert(commit())),"profile refused actual client application")
 f.drive(function() return f.rt.phase=="recovered" end)
 check(f.s.intents.requests[mode].state=="writable" and f.rt.saveLoop.options.admission==f.lane,"profile entry did not grant guarded saving")
 return world
end

test("profile-discovery-waits-and-keeps-caller-options",function()
 local f=fixture();f.budget.read=0;f.budget.write=0;local before=f.b.requests;local kept=nonP(f.b)
 for _=1,12 do
  f.tick();check(f.b.requests==before,"profile discovery started storage without capacity")
 end
 lanes(f)
 check(f.rt.reader.options.admission==f.lane and f.rt.lease.admission==f.lane and f.s.counters.requests==4,"profile reader/lease bypassed construction lane")
 check(f.common.reader.admission==nil and f.common.pipeline.admission==nil and f.common.saveOptions.admission==nil
  and f.common.saveOptions.progress.admission==nil and f.common.saveOptions.rest==nil and f.common.lifecycleAdmission==nil,"profile changed caller options")
 check(nonP(f.b)==kept and not f.rt.accepted,"queued profile discovery changed data/authority")
 f.budget.read=1000;f.budget.write=1000;f.all();lanes(f)
 for _,mode in Rules.MODES do check(f.s:offer(mode)~=nil and f.s:offer(mode).protected,"all-slot discovery lost an offer") end
 check(nonP(f.b)==kept,"read-only profile discovery changed originals")
 finish(f)
end)

for _,mode in Rules.MODES do
 test("fresh-selection-entry-and-saving-"..mode,function()
  local f=fixture();f.all();local offer=f.s:offer(mode)
  assert(f.owner:requestLife("continue",mode,1,offer.id));f.budget.read=0;f.budget.write=0
  local before=f.b.requests
  for _=1,8 do f.tick();check(f.b.requests==before,"profile selection bypassed capacity") end
  lanes(f);check(not f.rt.accepted and f.s.intents.requests[mode].credential==nil,"waiting profile selection granted authority")
  f.budget.read=1000;f.budget.write=1000
  local world=applied(f,mode);lanes(f)
  check(f.rt.pipeline.context==f.profiles[mode].context and f.rt.pipeline.template==f.owner.profiles[mode].template,"profile selected another destination")
  local kept=originals(f);local p=Json.copy(f.s.progress);p.settings.MasterVolume=.7;assert(f.owner:setProgress(p))
  local record=assert(Checkpoint.capture(world,126));local request=f.s.intents.requests[mode]
  assert(f.owner:setRestForIntent(mode,record,request.life,request.serial,request.credential,1))
  f.drive(function() return request.storedSerial==1 end)
  check(originals(f)==kept and f.b.data.P_46001.payload.settings.MasterVolume==.7,"profile save changed originals/lost latest settings")
  finish(f);check(originals(f)==kept and f.rt.result.progressPreserved and f.rt.result.leaseReleased,"profile closed departure lost originals or exact release")
 end)
end

test("post-accept-switch-hold-uses-the-shared-lane",function()
 local f=fixture();f.all();assert(f.owner:requestLife("continue","main",1,f.s:offer("main").id))
 f.drive(function() return f.rt.phase=="entering" and f.rt.entryJob.phase=="awaitApplied" end)
 assert(f.owner:requestLife("continue","free",2,f.s:offer("free").id))
 f.budget.read=0;f.budget.write=0;local before=f.b.requests;local kept=nonP(f.b)
 for _=1,16 do f.tick();check(f.b.requests==before,"profile switch lease started storage without capacity") end
 check(f.owner.switchLease.admission==f.lane and f.owner.switchLeaseJob.requests==0 and f.g:inspect().queued==1,"profile switch lease lost retained typed wait")
 check(f.s.intents.requests.main.credential==nil and f.s.intents.requests.free.credential==nil and f.rt.phase=="held","profile switch wait granted another life")
 f.budget.read=1000;f.budget.write=1000
 for _=1,90 do f.tick() end
 check(nonP(f.b)==kept and f.owner.switchLeaseJob.requests>=2 and f.clock.now-f.b.data.P_46001.lock.beat<Rules.LOCK_STALE,"typed profile switch hold lost lease or changed saves")
 finish(f);check(nonP(f.b)==kept and f.b.data.P_46001.lock==nil,"profile switch departure changed data or failed release")
end)

test("profile-bind-drains-an-ordinary-admission-suspension",function()
 local f=fixture({oldPeer=true});local pipeline=f.rt.pipeline
 local p=Json.copy(f.s.progress);p.settings.MasterVolume=.45;assert(f.owner:setProgress(p));f.clock.now+=5;f.budget.write=0
 f.owner:step();check(f.s._ordinaryContext and f.s._ordinaryContext.phase=="admission" and not f.s.busy,"fixture did not queue ordinary progress")
 f.owner:enableRecovery();local before=f.b.requests
 for _=1,8 do f.tick();check(f.rt.pipeline==pipeline and f.b.requests==before,"profile rebound over pending ordinary I/O") end
 f.budget.write=1000;f.all()
 check(f.b.data.P_46001.payload.settings.MasterVolume==.45 and f.s._ordinaryContext==nil,"profile rebind lost or stranded ordinary choice")
 lanes(f);finish(f)
end)

test("suspended-profile-read-drains-before-a-new-choice",function()
 local f=fixture();f.all();assert(f.owner:requestLife("continue","main",1,f.s:offer("main").id));f.tick()
 local old=f.rt.discovery;local read=f.b.readRawFresh;local paused=false
 f.b.readRawFresh=function(self,key)
  local result=table.pack(read(self,key))
  if key=="R_46001_main" and not paused then paused=true;coroutine.yield("typed-profile-provider") end
  return table.unpack(result,1,result.n)
 end
 local co
 for _=1,100 do
  co=coroutine.create(function() return f.owner:step() end);local ok,marker=coroutine.resume(co);assert(ok,marker)
  if marker=="typed-profile-provider" then break end
  check(coroutine.status(co)=="dead","unexpected profile provider yield");f.clock.now+=1
 end
 check(paused and f.g:inspect().started==1 and f.s.counters.requests==f.b.requests,"profile native start was not counted/retained")
 assert(f.owner:requestLife("continue","free",2,f.s:offer("free").id));local pipeline=f.rt.pipeline;local before=f.b.requests
 check(not f.owner:step() and f.rt.pipeline==pipeline and f.b.requests==before,"profile manually resumed provider or rebound during it")
 local ok,why=coroutine.resume(co);assert(ok,why)
 check(old.state=="cancelled" and f.g:inspect().started==0,"cancelled profile provider did not drain")
 f.drive(function() return f.rt.accepted end)
 check(f.rt.job.ticket.mode=="free" and f.rt.job.ticket.serial==2,"late Main result defeated newer Free choice")
 lanes(f);finish(f)
end)

test("protected-new-factory-inherits-lane-after-rebind",function()
 local cfg={work={now=function() return 0 end}}
 local f=fixture({newLifeFactory={new=function(rt) return __newLifePolicy.new(rt,cfg) end}});f.all();local offer=f.s:offer("free")
 local anchor=Json.canonical(f.b.data.M1_46001_free)
 assert(f.owner:prepareNewLife("free",1,offer.id,Json.copy(f.s.progress)))
 f.drive(function() return f.owner.newLifeJob~=nil or f.owner.newLifeRequest.state=="refused" end)
 check(f.owner.newLifeJob~=nil,"New factory did not inherit account lane")
 local policy,job=f.owner.newLifePolicy,f.owner.newLifeJob;lanes(f)
 check(policy.options.admission==f.lane and cfg.admission==nil,"New factory dropped lane or modified caller configuration")
 f.budget.read=0;f.budget.write=0;local before=f.b.requests
 for _=1,12 do f.tick();check(f.b.requests==before and job.requests==0,"protected New factory bypassed typed capacity") end
 f.budget.read=1000;f.budget.write=1000;f.drive(function() return f.owner:newLifeStatus()=="verified" end)
 check(not job.result.gameplayAuthorized and f.s.intents.requests.free.credential==nil,"protected New manufactured gameplay authority")
 check(Json.canonical(f.b.data.A1_46001_free.raw)==f.originalSlots.free and Json.canonical(f.b.data.M1_46001_free)==anchor,
  "protected New did not preserve original/proposal")
 local kept=originals(f);finish(f);check(originals(f)==kept,"protected New departure changed originals")
end)

test("a-factory-without-admission-refuses-before-begin",function()
 local began=false
 local f=fixture({newLifeFactory={new=function() return {options={},begin=function() began=true;error("unbound New began") end} end}})
 f.all();assert(f.owner:prepareNewLife("free",1,f.s:offer("free").id,Json.copy(f.s.progress)))
 f.drive(function() return f.owner.newLifeRequest.state=="refused" end)
 check(not began and f.owner.newLifeJob==nil and f.s.intents.requests.free.credential==nil,"unbound New factory began work or granted authority")
 check(string.find(f.owner.newLifeRequest.problem,"New factory dropped ordinary account lane",1,true)~=nil,"unbound New refusal lost its reason")
 finish(f)
end)

test("conflicting-profile-dependencies-refuse-before-storage",function()
 local seen
 local ok=pcall(fixture,{configureCommon=function(common,f) seen=f;common.reader.admission={} end})
 check(not ok and seen.b.requests==0,"conflicting profile lane started storage")
 seen.g:close(seen.scope)
 ok=pcall(fixture,{configureCommon=function(common,f) seen=f;common.startupBudget={} end})
 check(not ok and seen.b.requests==0,"old startup owner survived profile admission")
 seen.g:close(seen.scope)
end)
print("PROFILE_ADMISSION passed="..count.." failed=0 groups="..groups)
end
runProfileAdmissionChecks()
end
