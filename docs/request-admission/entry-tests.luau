local Gate=__workerAdmission
local Lease=__readLeasePrototype
local groups=0
local function test(name,fn) local before=count;fn();groups+=1;print("ENTRY_ADMISSION_CASE",name,count-before) end
local function install(f)
 local rt,s=f.rt,f.s
 assert(rt.phase=="entry_required" and not rt.busy and not s.busy)
 assert(rt.lease:cancel())
 local budget={read=0,write=0}
 local gate=Gate.new({now=s.now,available=function() return budget end,actorRead=40,actorWrite=40,serverRead=80,serverWrite=80,headroom=0})
 local scope=assert(gate:open("46001",s.id));assert(gate:importLegacy(scope,s.sched.started))
 local lane={gate=gate,scope=scope};rt.recovery.entryOptions.admission=lane
 rt.lease=Lease.new(s,function() return not rt.leaving and (rt.phase=="entry_required" or rt.phase=="entering" or rt.phase=="recovered") end,s.backend.held,lane)
 rt.leaseJob=assert(rt.lease:begin())
 return gate,scope,budget,lane
end
local function driveTyped(f,done)
 for _=1,20000 do
  if done() then return end
  local before=f.b.requests;f.rt:step()
  check(f.b.requests-before<=1,"typed coordinator started more than one provider per step")
  check(not f.rt.busy and not f.s.busy and not f.s.backend:permitted(f.s.backend.held),"typed coordinator leaked busy/permit state")
 end
 error("typed entry did not settle: "..tostring(f.rt.phase).." "..tostring(f.rt.entryJob and f.rt.entryJob.problem))
end
test("all-modes-hold-until-final-fresh-witnesses",function()
 for _,mode in Rules.MODES do
  local f=fixture(mode);local g,scope,budget=install(f);local base=f.s.counters.requests;local reads=f.b.requests
  local j=assert(f.rt:enter());local original=Json.canonical(f.b.data)
  for _=1,20 do check(not f.rt:step(),"zero-capacity entry reported a start") end
  check(j.requests==0 and f.rt.leaseJob.requests==0 and f.s.counters.requests==base and f.b.requests==reads,"capacity waits consumed provider attempts")
  check(g:inspect().queued==2 and j.failures==0 and f.rt.leaseJob.failures==0,"entry/lease did not retain exactly one pending operation each")
  check(f.s.intents.requests[mode].credential==nil and f.decisions()==0,"capacity denial granted play permission")
  budget.read=80;budget.write=80
  driveTyped(f,function() return j.state~="pending" or j.phase=="awaitApplied" end)
  check(j.state=="pending" and j.offer~=nil and j.requests==8 and f.rt.leaseJob.requests==1,"entry omitted an initial fresh witness")
  local commit=assert(Client.prepare(j.offer,f.world,function() return f.current end));local ack=assert(commit())
  check(f.rt:entryApplied(ack) and not f.rt:entryApplied(ack),"client application receipt was not single-use")
  budget.read=0;local savedCount=f.s.counters.requests
  for _=1,20 do check(not f.rt:step(),"final-witness wait started a provider") end
  check(j.phase=="finalRest" and j.requests==8 and f.decisions()==0 and f.s.intents.requests[mode].credential==nil,"application acknowledgement bypassed fresh storage validation")
  check(f.s.counters.requests==savedCount and g:inspect().queued==1,"final-witness wait consumed attempts or lost operation")
  budget.read=80;driveTyped(f,function() return j.state~="pending" end)
  check(f.rt.phase=="recovered" and j.state=="verified" and j.requests==10 and f.decisions()==1,"typed entry did not grant after exact final witnesses")
  check(f.s.counters.requests-base==11 and f.b.requests-reads==11,"entry/lease starts and counters differ")
  check(Json.canonical(f.b.data)==original and j.io==nil and g:inspect().queued==0,"read-only entry changed storage or leaked operations")
  check(f.rt.result.gameplayAuthorized and f.s.intents:authorized(mode,j.serial,j.request.credential,j.result.current.save_life),"real intent credential missing")
  print("ENTRY_ADMISSION mode="..mode.." actual_runtime=true client_applied=true fresh_final_reads=true granted_once=true")
 end
end)
test("cancelled-entry-and-expired-wait-never-read",function()
 for _,kind in {"cancel","deadline","route","gate"} do
  local f=fixture();local g,scope,budget=install(f);local j=assert(f.rt:enter())
  f.rt:step();local requests=f.s.counters.requests;local provider=f.b.requests
  if kind=="cancel" then assert(f.rt:cancelEntry())
  elseif kind=="deadline" then f.clock.now=j.deadline;f.rt.entry:step(j)
  elseif kind=="route" then f.s._loadSerial+=1;f.rt.entry:step(j)
  else g:close(scope);f.rt.entry:step(j) end
  budget.read=80;f.rt.entry:step(j)
  check(j.state~="pending" and j.state~="verified" and j.io==nil,"ended entry retained pending authority")
  check(f.s.counters.requests==requests and f.b.requests==provider and j.requests==0,"obsolete entry called provider")
  check(f.s.intents.requests.main.credential==nil,"obsolete entry granted a credential")
  f.rt.lease:cancel();g:close(scope);check(g:inspect().queued==0,"ended entry/lease leaked a ticket")
 end
end)
test("lease-transform-and-evidence-survive-capacity-waits",function()
 local f=fixture();local g,scope,budget=install(f);local lease,j=f.rt.lease,f.rt.leaseJob
 local starts=f.s.counters.requests;local provider=f.b.requests;budget.read=80
 check(lease:step(j) and j.phase=="renew" and j.requests==1,"typed lease did not prove its original lock")
 local before=Json.copy(f.b.data.P_46001);before.lock=nil
 f.clock.now=f.s.sched.lastBeat+Rules.HEARTBEAT
 for _=1,20 do check(not lease:step(j),"no-write-capacity renewal dispatched") end
 local transform=j.updateState.transform
 check(transform~=nil and j.requests==1 and f.s.counters.requests==starts+1 and f.b.requests==provider+1,"renewal wait spent attempts")
 lease:step(j);check(j.updateState.transform==transform and g:inspect().queued==1,"renewal transform/ticket was replaced while waiting")
 budget.write=80;check(lease:step(j) and j.state=="pending" and j.requests==2 and j.updateState==nil,"retained renewal evidence was lost")
 local after=Json.copy(f.b.data.P_46001);after.lock=nil
 check(equal(before,after) and f.b.data.P_46001.lock.beat==f.clock.now and f.s.sched.lastBeat==f.clock.now,"lease renewal changed payload or ignored exact acknowledgement")
 check(f.s.counters.requests==starts+2 and f.b.requests==provider+2,"lease counted waiting polls")
end)
test("ambiguous-renewal-reprobes-without-payload-change",function()
 local f=fixture();local g,scope,budget=install(f);local lease,j=f.rt.lease,f.rt.leaseJob
 budget.read=80;budget.write=80;assert(lease:step(j));f.clock.now=f.s.sched.lastBeat+Rules.HEARTBEAT
 f.b:fail({op="update",key=f.s.pkey,times=1,message="503: ambiguous renewal",afterWrite=true})
 check(lease:step(j) and j.phase=="probe" and j.failures==1 and j.requests==2,"ambiguous renewal did not retain charged probe/retry path")
 check(f.b.data.P_46001.lock.beat==f.clock.now,"committed renewal was pretended lost")
 local due=j.nextAt;check(due>f.clock.now and not lease:step(j),"ambiguous renewal skipped backoff")
 f.clock.now=due;check(lease:step(j) and j.phase=="renew" and j.failures==0 and j.requests==3,"fresh probe did not establish committed renewal")
end)
test("cancellation-during-committed-renewal-drains-owner",function()
 local f=fixture();local g,scope,budget=install(f);local lease,j=f.rt.lease,f.rt.leaseJob
 budget.read=80;budget.write=80;assert(lease:step(j));f.clock.now=f.s.sched.lastBeat+Rules.HEARTBEAT
 local update=f.b.update
 f.b.update=function(self,key,fn)
  local result=table.pack(update(self,key,fn));coroutine.yield("renewal-committed");return table.unpack(result,1,result.n)
 end
 local co=coroutine.create(function() lease:step(j) end);local okay,why=coroutine.resume(co)
 check(okay and why=="renewal-committed" and j.requests==2 and f.b.data.P_46001.lock.beat==f.clock.now,"actual lease did not reach committed suspended renewal")
 check(lease:cancel() and j.state=="stopped","busy typed renewal could not revoke its callback authority")
 g:close(scope);check(g:open("46001","next")==nil,"replacement opened over an in-flight lease provider")
 check(coroutine.resume(co) and coroutine.status(co)=="dead","cancelled renewal did not drain")
 check(j.state=="stopped" and j.io==nil and not f.s.busy and not lease.busy and f.s.backend.activeUpdates==0,"late renewal reopened work/leaked flags")
 check(g:open("46001","next")~=nil and f.b.data.P_46001.lock.beat==f.clock.now,"drained renewal debt/committed storage was discarded")
end)
test("lease-expiry-or-route-change-refuses-queued-provider",function()
 for _,kind in {"expiry","route","gate"} do
  local f=fixture();local g,scope,budget=install(f);local lease,j=f.rt.lease,f.rt.leaseJob
  lease:step(j);local provider=f.b.requests;local starts=f.s.counters.requests
  if kind=="expiry" then f.clock.now=j.expiresAt
  elseif kind=="route" then f.s._loadSerial+=1
  else g:close(scope) end
  budget.read=80;lease:step(j)
  check(j.state~="pending" and j.io==nil,"invalid queued lease retained operation")
  check(j.requests==0 and f.b.requests==provider and f.s.counters.requests==starts,"invalid queued lease called provider")
  check(g:inspect().queued==0,"invalid lease leaked a queue ticket")
 end
end)
print("ENTRY_ADMISSION passed="..count.." failed=0 groups="..groups)
end
runEntryAdmissionChecks()
end
