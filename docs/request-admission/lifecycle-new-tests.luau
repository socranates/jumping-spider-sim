local Gate=__lifecycleGate
local groups=0
local function test(name,fn) local before=count;fn();groups+=1;print("LIFECYCLE_NEW_CASE",name,count-before) end
local function typed(mode,continued,configure,options)
 local f=fixture()
 if continued then f.recover(mode);f.begin();f.drive(function() return f.client.transition==nil end) end
 local r=chooseNew(f,mode);local rt=f.owner.runtime;local s=f.owner.session
 if configure then configure(f,rt,s) end
 f.budget={read=1000,write=1000};f.g=Gate.new({now=s.now,available=function() return f.budget end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 f.scope=assert(f.g:open("46001",s.id));assert(f.g:importLegacy(f.scope,s.sched.started))
 local cfg={work={now=function() return 0 end},admission={gate=f.g,scope=f.scope}};for k,v in options or {} do cfg[k]=v end
 local policy=__newLifePolicy.new(rt,cfg);local j=assert(policy:begin(mode,r.serial,r.offerId))
 f.owner.newLifePolicy,f.owner.newLifeJob=policy,j
 f.policy,f.j,f.s,f.rt,f.r=policy,j,s,rt,r;f.base={provider=f.b.requests,global=s.counters.requests}
 return f
end
local function step(f,advance)
 local before=f.b.requests;local asked=f.policy:step(f.j)
 check(f.b.requests-before<=1,"New started multiple providers")
 check(f.j.requests==f.s.counters.requests-f.base.global and f.j.requests==f.b.requests-f.base.provider,"New root/global/provider counts differ")
 check(not f.policy.busy and not f.s.busy and not f.s.backend:permitted(f.j.held),"New retained busy state or permit")
 if advance~=false then f.clock.now+=1 end
 return asked
end
local function driveTyped(f,done)
 for _=1,4000 do if done and done() or not done and f.j.state~="pending" then return end;step(f);assert(f.j.state~="refused",tostring(f.j.problem)) end
 error("typed New did not settle: "..f.j.phase)
end
local function finish(f)
 if f.j.state=="pending" then f.policy:cancel(f.j) end
 if f.policy.lease then f.policy.lease:cancel() end
 f.g:close(f.scope);local q=f.g:inspect();check(q.queued==0 and q.reserved==0 and q.started==0,"New retained admission handles")
end
local function updates(f,key)
 local n=0;for _,row in f.b.log do if row.op=="update" and row.key==key then n+=1 end end;return n
end

test("all-modes-preserve-original-before-retirement",function()
 for _,mode in Rules.MODES do
  local f=typed(mode);local original=Json.canonical(f.b.data["R_46001_"..mode]);local other={}
  for _,slot in Rules.MODES do if slot~=mode then other[slot]=Json.canonical(f.b.data["R_46001_"..slot]) end end
  f.budget.read=0;f.budget.write=0;local before=f.b.requests
  for _=1,12 do check(not step(f,false),"zero-capacity New started storage") end
  check(f.j.phase=="source" and f.j.failures==0 and f.j.requests==0 and f.b.requests==before,"New wait consumed attempts/phase")
  f.budget.read=1000;f.budget.write=1000;driveTyped(f)
  check(f.j.state=="verified" and f.j.result.retired and not f.j.result.gameplayAuthorized and f.r.credential==nil,"New granted gameplay or failed retirement")
  check(Json.canonical(f.b.data["A1_46001_"..mode].raw)==original and f.b.data.A1_46001_index.complete,"New failed to preserve complete original")
  for slot,value in other do check(Json.canonical(f.b.data["R_46001_"..slot])==value,"New changed another rest slot") end
  local marker=Envelope.open(SaveRest.SPECS[mode],codec:decode(f.b.data["R_46001_"..mode]))
  check(marker.status=="ok" and marker.payload.save_retired and marker.payload.checkpoint==nil,"retirement marker is not ordinary-readable")
  check(f.j.io==nil and f.j.rawIO==nil,"verified retirement retained write/read operations")
  finish(f)
 end
end)

test("continued-new-reuses-exact-originals-and-proposal",function()
 local f=typed("main",true);local kept=originals(f);driveTyped(f)
 check(f.j.state=="verified" and originals(f)==kept and f.r.credential==nil,"continued New changed immutable originals or granted a life")
 finish(f)
end)

test("queued-retirement-and-readback-keep-exact-cas",function()
 for _,phase in {"write","readback"} do
  local f=typed("main");driveTyped(f,function() return f.j.phase==phase end)
  local before,attempts,failures,writes=f.b.requests,f.j.requests,f.j.failures,updates(f,"R_46001_main")
  f.budget.read=0;f.budget.write=0
  for _=1,10 do check(not step(f,false),"retirement wait started provider") end
  check(f.j.phase==phase and f.j.requests==attempts and f.j.failures==failures and f.b.requests==before and f.r.credential==nil,"retirement wait advanced state/attempts/authority")
  f.budget.read=1000;f.budget.write=1000;driveTyped(f)
  check(f.j.state=="verified","retirement did not verify after capacity returned")
  if phase=="readback" then check(updates(f,"R_46001_main")==writes,"readback wait repeated retirement CAS") end
  finish(f)
 end
end)

test("lost-retirement-ack-probes-before-retry",function()
 for _,after in {false,true} do
  local f=typed("main");driveTyped(f,function() return f.j.phase=="write" end)
  f.b:fail({op="update",key="R_46001_main",afterWrite=after,message="timeout"})
  driveTyped(f,function() return f.j.phase=="readback" end)
  f.budget.read=0;local n=f.b.requests
  for _=1,8 do step(f,false) end
  check(f.j.state=="pending" and f.b.requests==n and f.j.phase=="readback","lost ACK became verified without fresh read")
  f.budget.read=1000;driveTyped(f);check(f.j.result.retired and f.r.credential==nil,"ambiguous retirement granted or failed")
  finish(f)
 end
end)

test("queued-new-cancel-selection-change-and-cap",function()
 for _,why in {"cancel","selection","cap","deadline"} do
  local f=typed("main");f.budget.read=0;f.budget.write=0;step(f,false)
  local before=f.b.requests;local original=nonP(f.b)
  if why=="cancel" then f.policy:cancel(f.j)
  elseif why=="selection" then f.s.intents:changed(f.r,"test change")
  elseif why=="cap" then f.policy.maxRequests=1;f.s.counters.requests+=1
  else f.clock.now=f.j.deadline end
  f.policy:step(f.j)
  check(f.j.state=="refused" and f.j.io==nil and f.j.rawIO==nil and f.b.requests==before and nonP(f.b)==original,"cancelled/changed/bounded New reached storage")
  check(f.r.credential==nil and f.j.held.enforced,"refused New granted authority or dropped hold")
  finish(f)
 end
end)

test("cancel-suspended-committed-retirement-withholds-result-and-drains",function()
 local f=typed("main",false,function(x,rt)
  local raw=rt.recovery.rawBackend;local provider=raw.updateRaw
  raw.updateRaw=function(self,key,fn)
   local out=table.pack(provider(self,key,fn))
   if x.pause and key=="R_46001_main" then x.pause=false;coroutine.yield("retirement-committed") end
   return table.unpack(out,1,out.n)
  end
 end)
 driveTyped(f,function() return f.j.phase=="write" end);f.pause=true
 local co=coroutine.create(function() return f.policy:step(f.j) end);local ok,mark=coroutine.resume(co);assert(ok,mark)
 check(mark=="retirement-committed" and f.s.busy and f.g:inspect().started==1,"retirement did not suspend after commit")
 local raw=Json.canonical(f.b.data.R_46001_main);local kept=originals(f);local debt=f.g:inspect()
 f.policy:cancel(f.j);f.g:close(f.scope)
 check(f.g:open("46001","next-epoch")==nil,"replacement overlapped suspended New provider")
 assert(coroutine.resume(co))
 check(f.j.state=="refused" and not f.j.result.gameplayAuthorized and not f.j.result.originalPreservationVerified and f.r.credential==nil,"cancelled retirement published success/grant")
 check(Json.canonical(f.b.data.R_46001_main)==raw and originals(f)==kept and not f.s.busy,"cancel rolled back committed marker/originals or retained busy state")
 local nextScope=assert(f.g:open("46001","next-epoch"));local after=f.g:inspect()
 check(after.read==debt.read and after.write==debt.write and after.started==0,"retirement cancel refunded debt")
 f.g:close(nextScope)
end)

test("verified-new-departure-cancels-queued-maintenance-first",function()
 local f=typed("main");driveTyped(f);local kept=originals(f)
 f.clock.now+=Rules.HEARTBEAT;f.budget.write=0;f.policy:step(f.j)
 check(f.g:inspect().queued==1,"verified New maintenance did not queue")
 local q=Json.copy(f.s.progress);q.settings.MasterVolume=.5;assert(f.s:setProgress(q))
 local d=__departurePrototype.new(f.policy,{admission=f.policy.options.admission});local j=assert(d:begin())
 f.budget.write=1000;d:step(j)
 check(j.phase=="write" and j.requests==0 and f.g:inspect().queued==0,"departure did not cancel queued owner maintenance before writing")
 d:step(j);check(j.phase=="readback" and j.requests==1,"old maintenance blocked eligible departure write")
 d:step(j)
 check(j.state=="preserved" and f.s.closed and not f.s.lockHeld and f.b.data.P_46001.payload.settings.MasterVolume==.5 and originals(f)==kept,"verified New departure lost latest progress/originals or failed release")
 finish(f)
end)

print("LIFECYCLE_NEW passed="..count.." failed=0 groups="..groups)
end
runLifecycleNewChecks()
end
