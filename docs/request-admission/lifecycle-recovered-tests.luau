local Gate=__lifecycleGate
local groups=0
local function test(name,fn) local before=count;fn();groups+=1;print("LIFECYCLE_RECOVERED_CASE",name,count-before) end
local function typed(mode,configure)
 local f=fixture(mode);f.rt.saveLoop:cancel();if configure then configure(f) end
 f.budget={read=1000,write=1000}
 f.g=Gate.new({now=f.s.now,available=function() return f.budget end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 f.scope=assert(f.g:open("46001",f.s.id));assert(f.g:importLegacy(f.scope,f.s.sched.started))
 f.lane={gate=f.g,scope=f.scope};f.rt.recovery.saveOptions.admission=f.lane;f.rt.recovery.lifecycleAdmission=f.lane
 f.rt.saveLoop=__saveLoopPrototype.new(f.rt);f.base={provider=f.b.requests,global=f.s.counters.requests}
 return f
end
local function step(f,advance)
 local n=f.b.requests;local asked=f.rt:step()
 check(f.b.requests-n<=1,"recovered lifecycle started multiple providers")
 check(f.b.requests-f.base.provider==f.s.counters.requests-f.base.global,"recovered lifecycle provider/global count differs")
 check(not f.s.busy and not f.rt.busy and not f.s.backend:permitted(f.s.backend.held),"recovered lifecycle retained busy/permit state")
 if advance~=false then f.clock.now+=1 end
 return asked
end
local function drive(f,done)
 for _=1,2000 do if done() then return end;step(f) end;error("recovered lifecycle did not settle: "..f.rt.phase.." "..tostring(f.rt.problem))
end
local function finish(f)
 if f.rt.saveLoop then f.rt.saveLoop:cancel() end
 if f.rt.lease then f.rt.lease:cancel() end
 f.g:close(f.scope);local q=f.g:inspect();check(q.queued==0 and q.reserved==0 and q.started==0,"recovered lifecycle retained ticket/provider")
end
test("all-modes-retire-fresh-marker-and-closed-departure",function()
 for _,mode in Rules.MODES do
  local f=typed(mode);local kept=nonOwned(f);local r=f.s.intents.requests[mode]
  check(f.rt:retireRecovered(mode,r.serial,r.credential,r.life,1,2),"recovered retirement refused")
  drive(f,function() return f.rt.phase~="recovered" end)
  check(f.rt.phase=="retired" and f.rt.result.retired and r.credential==nil and nonOwned(f)==kept,"recovered retirement lost originals or retained credential")
  step(f,false);check(f.rt.lease.admission==f.lane,"retired idle lease omitted lifecycle lane")
  check(f.rt:prepareFreshLife()~=nil,"fresh marker preparation refused")
  drive(f,function() return f.rt.phase~="freshening" end)
  check(f.rt.phase=="fresh_ready" and SaveRest.isRetired(f.rt.freshLogical.payload) and nonOwned(f)==kept,"fresh marker failed or changed originals")
  local requests=f.b.requests;local replacement,why=f.rt:replaceFreshLife("new-typed-epoch")
  check(replacement==nil and why=="service-owned admission replacement required" and f.b.requests==requests,"direct replacement reused old lane or bypassed admission")
  f.rt:flush(f.clock.now+24)
  check(f.rt.phase=="closed" and f.s.closed and f.rt.result.progressPreserved and f.rt.result.leaseReleased and f.b.data.P_46001.lock==nil and nonOwned(f)==kept,"typed retired departure failed")
  check(f.rt.departure.admission==f.lane and f.rt.departureJob.io==nil,"Runtime did not supply/clean departure lane")
  finish(f)
 end
end)

test("unresolved-aba-progress-is-reconciled-by-typed-departure",function()
 for _,after in {false,true} do
  local f=typed();local loop=f.rt.saveLoop;choose(f,.8)
  drive(f,function() return loop.progressJob and loop.progressJob.phase=="write" and loop.progress.leaseJob.phase=="renew" end)
  f.b:fail({op="update",key=f.s.pkey,afterWrite=after,message="timeout"})
  drive(f,function() return loop.progressJob.phase=="readback" end);choose(f,.2)
  loop.progressJob.nextAt=f.clock.now+200
  f.rt:flush(f.clock.now+12)
  check(f.s.closed and f.rt.result.progressPreserved and f.rt.result.leaseReleased and f.b.data.P_46001.payload.settings.MasterVolume==.2 and f.b.data.P_46001.lock==nil,"typed departure lost pending A-B-A choice")
  check(f.rt.departure.admission==f.lane and f.rt.departureJob.io==nil,"pending-progress departure escaped shared gate")
  finish(f)
 end
end)

test("Runtime-flush-deadline-cancels-queued-departure",function()
 local f=typed();f.budget.read=0;f.budget.write=0
 -- Calling depart first supplies the real closed scope; flush then owns the
 -- bounded polling/deadline branch and must clean the queued operation.
 check(f.rt:depart(f.clock.now+2)~=nil,"Runtime departure did not begin")
 f.rt:step();f.rt:step();check(f.g:inspect().queued==1,"Runtime departure did not queue")
 f.rt:flush(f.clock.now+2)
 check(f.rt.phase=="closed" and f.s.closed and not f.s.flushing and not f.rt.result.progressPreserved and f.rt.departureJob.io==nil,"Runtime timeout stranded queued departure")
 finish(f)
end)

test("returning-retired-offer-binds-fresh-writer-and-lease",function()
 local f=typed();local r=f.s.intents.requests.main
 assert(f.rt:retireRecovered("main",r.serial,r.credential,r.life,1,2))
 drive(f,function() return f.rt.phase=="retired" end)
 local kept=nonOwned(f);f.rt:flush();finish(f)
 local rt=__runtimePrototype.new({backend=f.b,userId=46001,sessionId="return-retired",now=function() return f.clock.now end,sleep=function(dt) f.clock.now+=dt end},
  {codec=codec,rawBackend=f.b,template=f.rt.recovery.template,context=f.context,currentFormat=__restFormatPrototype,freshWriterFactory=__currentWriterPrototype,
   reader={work={now=function() return 0 end}},pipeline={work={now=function() return 0 end}},saveOptions={work={now=function() return 0 end}}})
 assert(rt:load()=="active");rt.session:enableOffers();assert(rt:discoverNewLife("main"))
 for _=1,1800 do if rt.phase~="discovering" then break end;rt:step();f.clock.now+=1 end
 check(rt.phase=="offered" and rt.discovery.retired,"returned schema3 retirement was not New-only")
 -- This is a second explicit quiescent test boundary after legacy load and
 -- discovery. It does not claim an all-provider service replacement lane.
 local s=rt.session;local budget={read=1000,write=1000}
 local g=Gate.new({now=s.now,available=function() return budget end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 local scope=assert(g:open("46001",s.id));assert(g:importLegacy(scope,s.sched.started));local lane={gate=g,scope=scope}
 if rt.lease then rt.lease:cancel() end;rt.lease,rt.leaseJob=nil,nil;rt.recovery.lifecycleAdmission=lane
 assert(rt:acceptRetiredFresh("main",2,rt.discovery.offer.id))
 check(rt.freshWriter.admission==lane and rt.lease.admission==lane,"returning fresh writer/read lease escaped lifecycle lane")
 assert(rt:prepareFreshLife())
 local global,provider=s.counters.requests,f.b.requests
 for _=1,1200 do
  if rt.phase~="freshening" then break end
  local before=f.b.requests;rt:step();check(f.b.requests-before<=1 and f.b.requests-provider==s.counters.requests-global,"returning fresh marker provider/global counts differ")
  f.clock.now+=1
 end
 check(rt.phase=="fresh_ready" and SaveRest.isRetired(rt.freshLogical.payload) and nonOwned(f)==kept,"returning fresh marker changed originals or failed")
 rt:flush();check(s.closed and rt.result.progressPreserved and rt.result.leaseReleased,"returning retired departure did not preserve/release")
 g:close(scope);local q=g:inspect();check(q.queued==0 and q.started==0,"returning retired flow retained admission work")
end)

print("LIFECYCLE_RECOVERED passed="..count.." failed=0 groups="..groups)
end
runLifecycleRecoveredChecks()
end
