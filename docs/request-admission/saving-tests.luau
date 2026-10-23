local Gate=__savingGate
local groups=0
local function test(name,fn) local before=count;fn();groups+=1;print("SAVING_ADMISSION_CASE",name,count-before) end
local function typed(mode,configure)
 local f=fixture(mode)
 -- Explicit test boundary after actual entry, before any recovered save step.
 -- Old discovery/entry/departure factories are not represented as installed.
 f.rt.saveLoop:cancel()
 if configure then configure(f) end
 f.budget={read=1000,write=1000}
 f.g=Gate.new({now=f.s.now,available=function() return f.budget end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 f.scope=assert(f.g:open("46001",f.s.id));assert(f.g:importLegacy(f.scope,f.s.sched.started))
 f.rt.recovery.saveOptions.admission={gate=f.g,scope=f.scope}
 f.rt.saveLoop=__saveLoopPrototype.new(f.rt)
 f.base={provider=f.b.requests,global=f.s.counters.requests}
 check(f.rt.saveLoop.progress.options.admission==f.rt.recovery.saveOptions.admission and f.rt.saveLoop.writer.admission==f.rt.recovery.saveOptions.admission,"saving children did not share lane")
 return f
end
local function step(f,advance)
 local before=f.b.requests;local asked=f.rt:step()
 check(f.b.requests-before<=1,"saving started multiple providers in one step")
 check(f.b.requests-f.base.provider==f.s.counters.requests-f.base.global,"saving provider/global starts differ")
 check(not f.rt.busy and not f.s.busy and not f.s.backend:permitted(f.s.backend.held),"saving leaked busy state or permission")
 if advance~=false then f.clock.now+=1 end
 return asked
end
local function untilDone(f,done)
 for _=1,2000 do if done() then return end;step(f);assert(f.rt.phase=="recovered",tostring(f.rt.problem)) end
 error("saving did not settle: "..tostring(f.rt.saveLoop.problem))
end
local function updates(f,key)
 local n=0;for _,row in f.b.log do if row.op=="update" and row.key==key then n+=1 end end;return n
end
local function finish(f)
 f.rt.saveLoop:cancel();f.g:close(f.scope)
 local q=f.g:inspect();check(q.queued==0 and q.reserved==0 and q.started==0,"saving cleanup retained ticket/provider")
end

test("all-modes-progress-checkpoint-and-idle-lease",function()
 for _,mode in Rules.MODES do
  local f=typed(mode);local originals=nonOwned(f);choose(f,.6);check(checkpoint(f,1),"typed checkpoint refused")
  untilDone(f,function() return f.stored()==1 end)
  check(f.b.data.P_46001.payload.settings.MasterVolume==.6 and f.s.progress.settings.MasterVolume==.6,"progress was not durable before rest")
  check(f.s.intents.requests[mode].storedSerial==1 and equal(f.b.data["R_46001_"..mode],f.rt.saveLoop.rawRest),"stored rest receipt/cache differs")
  check(nonOwned(f)==originals and f.s.backend.pendingProgress==nil,"saving changed immutable originals or retained reservation")
  for _=1,145 do step(f) end
  check(f.clock.now-f.b.data.P_46001.lock.beat<31,"typed idle lease expired")
  check(f.rt.saveLoop.lease.admission==f.rt.recovery.saveOptions.admission,"idle lease omitted shared lane")
  finish(f)
 end
end)

test("queued-progress-keeps-later-player-choice-and-debounce",function()
 local f=typed();local loop=f.rt.saveLoop;choose(f,.3)
 untilDone(f,function() return not f.s.sched:isDirty("progress") and f.s.backend.pendingProgress==nil end)
 choose(f,.8)
 local before=f.b.requests
 -- The ordinary debounce still applies, even with abundant provider capacity.
 for _=1,15 do step(f) end
 check(loop.progressJob==nil and f.b.data.P_46001.payload.settings.MasterVolume==.3,"typed route bypassed debounce")
 untilDone(f,function() return loop.progressJob~=nil and loop.progress.leaseJob.phase=="renew" end)
 local j=loop.progressJob;f.budget.write=0;local n=f.b.requests;local failures=j.failures
 for _=1,12 do check(not step(f,false),"queued progress write started provider") end
 check(j.phase=="write" and j.failures==failures and f.b.requests==n and j.requests==1,"queued progress consumed failure/counter")
 choose(f,.2);check(f.s.sched:isDirty("progress"),"newer queued choice was cleared")
 f.budget.write=1000
 untilDone(f,function() return not f.s.sched:isDirty("progress") and f.s.backend.pendingProgress==nil end)
 check(f.s.progress.settings.MasterVolume==.2 and f.b.data.P_46001.payload.settings.MasterVolume==.2,"queued A-B-A authored choice was lost")
 check(f.b.requests>before and j.state=="verified" and j.io==nil,"progress did not verify/clean up")
 finish(f)
end)

test("rest-readback-and-final-witness-waits-never-ack-early",function()
 for _,phase in {"proposal","write","readback","finalLease"} do
  local f=typed();check(checkpoint(f,1),"waiting checkpoint refused")
  local loop=f.rt.saveLoop
  untilDone(f,function() return loop.restJob~=nil and loop.restJob.phase==phase end)
  local j=loop.restJob;f.budget.read=0;f.budget.write=0
  local before,attempts,failures,writes=f.b.requests,j.requests,j.failures,updates(f,f.s.rkey.main)
  for _=1,15 do check(not step(f,false),"rest capacity wait started request") end
  check(j.phase==phase and j.requests==attempts and j.failures==failures and f.b.requests==before,"rest wait advanced attempts/state")
  check(f.stored()==0 and (f.s.intents.requests.main.storedSerial or 0)==0,"rest was acknowledged before final witness")
  f.budget.read=1000;f.budget.write=1000;untilDone(f,function() return f.stored()==1 end)
  check(j.state=="verified" and j.io==nil and j.rawIO==nil,"verified rest retained operation")
  if phase=="readback" or phase=="finalLease" then check(updates(f,f.s.rkey.main)==writes,"readback wait repeated CAS") end
  finish(f)
 end
end)

test("ambiguous-progress-and-rest-acks-require-fresh-readback",function()
 for _,after in {false,true} do
  local f=typed();local loop=f.rt.saveLoop;choose(f,.8)
  untilDone(f,function() return loop.progressJob~=nil and loop.progress.leaseJob.phase=="renew" and loop.progressJob.phase=="write" end)
  f.b:fail({op="update",key=f.s.pkey,afterWrite=after,message="timeout"})
  untilDone(f,function() return loop.progressJob.phase=="readback" end);choose(f,.2)
  untilDone(f,function() return not f.s.sched:isDirty("progress") and f.s.backend.pendingProgress==nil end)
  check(f.s.progress.settings.MasterVolume==.2 and f.b.data.P_46001.payload.settings.MasterVolume==.2,"ambiguous progress lost later choice")
  check(checkpoint(f,1),"ambiguous rest checkpoint refused")
  untilDone(f,function() return loop.restJob~=nil and loop.restJob.phase=="write" end)
  f.b:fail({op="update",key=f.s.rkey.main,afterWrite=after,message="timeout"})
  untilDone(f,function() return loop.restJob.phase=="readback" end)
  f.budget.read=0;local n=f.b.requests
  for _=1,10 do step(f,false) end
  check(f.stored()==0 and f.b.requests==n,"ambiguous rest was acknowledged without readback")
  f.budget.read=1000;untilDone(f,function() return f.stored()==1 end)
  check(equal(f.b.data[f.s.rkey.main],loop.rawRest),"ambiguous rest did not settle exactly")
  finish(f)
 end
end)

test("captured-checkpoint-not-starved-by-later-notebook-progress",function()
 local f=typed();local loop=f.rt.saveLoop;choose(f,.4);check(checkpoint(f,1),"streaming checkpoint refused")
 for _=1,400 do
  if f.stored()==1 then break end
  local q=Json.copy(f.s.progress);q.notebook.eye_seconds+=.01;assert(f.s:setProgress(q));step(f)
 end
 check(f.stored()==1 and f.s.sched:isDirty("progress"),"later ticks starved checkpoint or were falsely durable")
 local nextAt=loop.restNextAt;check(nextAt>f.clock.now,"rest interval was not set")
 check(checkpoint(f,2),"second ordered checkpoint refused")
 local prior=updates(f,f.s.rkey.main)
 while f.clock.now<nextAt do step(f);check(updates(f,f.s.rkey.main)==prior,"rest interval was bypassed") end
 untilDone(f,function() return f.stored()==2 end)
 check(f.s.intents.requests.main.storedSerial==2,"second ordered receipt missing")
 finish(f)
end)

test("queued-cancel-and-foreign-owner-never-publish-stored-receipt",function()
 for _,cancel in {false,true} do
  local f=typed();check(checkpoint(f,1),"cancel checkpoint refused")
  local loop=f.rt.saveLoop;untilDone(f,function() return loop.restJob~=nil and loop.restJob.phase=="write" end)
  local j=loop.restJob;local old=Json.canonical(f.b.data[f.s.rkey.main]);f.budget.write=0
  for _=1,5 do step(f,false) end
  if cancel then
   loop:cancel();f.g:close(f.scope);f.budget.write=1000;loop.writer:step(j)
   check(j.state=="cancelled" and Json.canonical(f.b.data[f.s.rkey.main])==old,"cancelled queued rest wrote")
  else
   local foreign=Envelope.withLock(f.b.data.P_46001,{session="foreign",beat=f.clock.now});f.b:poke(f.s.pkey,foreign)
   f.budget.write=1000
   for _=1,200 do if f.rt.phase~="recovered" then break end;step(f) end
   check(f.rt.phase=="lost" and equal(f.b.data.P_46001,foreign),"foreign owner was changed or retained authority")
  end
  check(f.stored()==0,"cancelled/foreign-owner rest acknowledged")
  finish(f)
 end
end)

print("SAVING_ADMISSION passed="..count.." failed=0 groups="..groups)
end
runSavingAdmissionChecks()
end
