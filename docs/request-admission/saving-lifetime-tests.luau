test("yielded-progress-retains-newer-player-choice",function()
 local f=typed(nil,function(x)
  local provider=x.b.update
  x.b.update=function(self,key,fn)
   local out=table.pack(provider(self,key,fn))
   if x.pause and key=="P_46001" then x.pause=false;coroutine.yield("progress-committed") end
   return table.unpack(out,1,out.n)
  end
 end)
 local loop=f.rt.saveLoop;choose(f,.8)
 untilDone(f,function() return loop.progressJob and loop.progressJob.phase=="write" and loop.progress.leaseJob.phase=="renew" end)
 local j=loop.progressJob;f.pause=true
 local co=coroutine.create(function() return f.rt:step() end);local ok,mark=coroutine.resume(co);assert(ok,mark)
 check(mark=="progress-committed" and f.s.busy and f.rt.busy and f.g:inspect().started==1,"progress provider did not retain lifetime/busy scope")
 local before=f.b.requests;check(not f.rt:step() and f.b.requests==before,"progress yield permitted overlapping provider")
 choose(f,.2);assert(coroutine.resume(co))
 check(j.phase=="readback" and j.state=="pending" and f.g:inspect().started==0,"yielded progress did not drain into readback")
 untilDone(f,function() return not f.s.sched:isDirty("progress") and f.s.backend.pendingProgress==nil end)
 check(f.s.progress.settings.MasterVolume==.2 and f.b.data.P_46001.payload.settings.MasterVolume==.2,"actual yielding write erased later authored choice")
 finish(f)
end)

test("committed-rest-cancel-drains-before-account-replacement",function()
 local f=typed(nil,function(x)
  local provider=x.b.updateRaw
  x.b.updateRaw=function(self,key,fn)
   local out=table.pack(provider(self,key,fn))
   if x.pause and key=="R_46001_main" then x.pause=false;coroutine.yield("rest-committed") end
   return table.unpack(out,1,out.n)
  end
 end)
 check(checkpoint(f,1),"yielded rest checkpoint refused")
 local loop=f.rt.saveLoop;untilDone(f,function() return loop.restJob and loop.restJob.phase=="write" end)
 local j=loop.restJob;f.pause=true
 local co=coroutine.create(function() return f.rt:step() end);local ok,mark=coroutine.resume(co);assert(ok,mark)
 check(mark=="rest-committed" and f.s.busy and f.g:inspect().started==1,"raw rest did not suspend after physical commit")
 local committed=Json.canonical(f.b.data.R_46001_main);local debt=f.g:inspect()
 loop:cancel();f.g:close(f.scope)
 check(f.g:open("46001","replacement")==nil,"replacement began while old raw write was suspended")
 assert(coroutine.resume(co))
 check(coroutine.status(co)=="dead" and not f.s.busy and not f.rt.busy and j.state=="cancelled","cancelled raw provider did not drain cleanly")
 check(f.stored()==0 and (f.s.intents.requests.main.storedSerial or 0)==0 and Json.canonical(f.b.data.R_46001_main)==committed,"cancelled result acknowledged or rolled back committed rest")
 local replacement=assert(f.g:open("46001","replacement"));local after=f.g:inspect()
 check(after.read==debt.read and after.write==debt.write and after.queued==0 and after.started==0,"cancel/replacement refunded request debt")
 f.g:close(replacement)
end)

test("typed-progress-does-not-reenter-old-aggregate-limiter",function()
 local f=typed();local loop=f.rt.saveLoop
 local rows={requests=0};local op=__savingOperation.new(f.s,f.rt.recovery.saveOptions.admission,function() return f.rt.phase=="recovered" end,{{object=rows,field="requests",max=20}})
 -- Real additional uncached provider starts through the very same account gate.
 for _=1,12 do local state=op:poll("readRawFresh",f.s.pkey,nil);check(state=="done","shared typed read refused") end
 op:cancel()
 check(not f.s.sched:budgetOk(f.clock.now),"test did not saturate old aggregate history")
 choose(f,.7)
 -- First step probes the idle lease; second must start the progress job even
 -- though the old scheduler's aggregate quota remains exhausted.
 for _=1,3 do step(f,false) end
 check(loop.progressJob~=nil,"progress still depended on obsolete aggregate capacity")
 untilDone(f,function() return not f.s.sched:isDirty("progress") and f.s.backend.pendingProgress==nil end)
 check(f.b.data.P_46001.payload.settings.MasterVolume==.7,"typed progress failed beyond old aggregate limit")
 finish(f)
end)

test("thrown-provider-keeps-progress-readback-retry-and-cap",function()
 local f=typed(nil,function(x)
  local provider=x.b.update
  x.b.update=function(self,key,fn)
   if x.throw and key=="P_46001" then x.throw=false;error("503 unavailable",0) end
   return provider(self,key,fn)
  end
 end)
 local loop=f.rt.saveLoop;choose(f,.8)
 untilDone(f,function() return loop.progressJob and loop.progressJob.phase=="write" and loop.progress.leaseJob.phase=="renew" end)
 local j=loop.progressJob;f.throw=true
 -- An exception before MemoryBackend starts is still a charged provider
 -- attempt. Adjust only the test's physical-Memory-call comparison baseline.
 local before=f.s.counters.requests;f.rt:step();f.base.global+=1
 check(j.phase=="readback" and j.state=="pending" and f.s.counters.requests==before+1,"throw did not retain charged attempt/readback protocol")
 step(f)
 check(j.failures==1 and j.phase=="write" and j.nextAt>f.clock.now-1,"failed progress readback omitted backoff")
 local n=f.s.counters.requests
 step(f,false);check(f.s.counters.requests==n,"backoff made a new provider attempt")
 untilDone(f,function() return not f.s.sched:isDirty("progress") and f.s.backend.pendingProgress==nil end)
 check(f.b.data.P_46001.payload.settings.MasterVolume==.8,"thrown provider prevented retry settlement")
 finish(f)
end)

test("queued-current-rest-cap-and-deadline-cleanup",function()
 for _,kind in {"cap","deadline","identity"} do
  local f=typed();check(checkpoint(f,1),"limited rest refused at submission")
  local loop=f.rt.saveLoop;untilDone(f,function() return loop.restJob and loop.restJob.phase=="proposal" end)
  local j=loop.restJob;f.budget.read=0;step(f,false)
  local before=f.b.requests
  if kind=="cap" then loop.writer.maxRequests=1;j.requests=1
  elseif kind=="deadline" then f.clock.now=j.deadline
  else f.s._loadSerial+=1 end
  -- Direct owner step avoids Runtime's broader route refusal obscuring the
  -- worker's own cancellation/expiry behavior.
  loop.writer:step(j)
  check(j.state=="refused" and j.io==nil and j.rawIO==nil and f.b.requests==before and f.stored()==0,"limited/changed current rest leaked queued work")
  finish(f)
 end
end)
