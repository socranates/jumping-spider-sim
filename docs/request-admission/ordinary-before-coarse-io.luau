--!strict
-- Private ordinary Session request bridge. Only its own admission yield may be
-- resumed by polling. Native/provider/observer yields must resume externally.
local Operation=require(script.Parent.RecoveryOperationAdmission)
local Scheduler=require(script.Parent.SaveScheduler)
local Rules=require(script.Parent.Parent.Data.SaveRules)
local IO={}
IO.ABORT=table.freeze({ordinaryRequestEnded=true})
local SIGNAL=table.freeze({ordinaryAdmissionWait=true})
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
function IO.attach(s:any,lane:any)
 assert(type(lane)=="table" and getmetatable(lane)==nil and lane.gate:live(lane.scope) and lane.gate:legacyReady(lane.scope)
  and lane.scope.actor==tostring(s.cfg.userId) and lane.scope.epoch==s.id,"seeded ordinary account lane required")
 assert(type(s.cfg.sleep)=="function" and s.state=="loading" and s.counters.requests==0 and #s.sched.started==0 and not s.ordinaryAdmission,
  "attach ordinary admission once before load with cooperative sleep")
 assert(s.sched.begin==Scheduler.begin and s.sched.budgetOk==Scheduler.budgetOk and s.sched._recoveryStartup==nil,"retire competing startup wrappers before ordinary admission")
 s.ordinaryAdmission=lane
end
local function live(s:any,c:any):boolean
 if s._ordinaryContext~=c or c.cancelled or s.closed or s.backend~=c.backend or s.sched~=c.scheduler or s.counters~=c.counters
  or s.id~=c.id or s.cfg~=c.config or tostring(s.cfg.userId)~=c.user or s.ordinaryAdmission~=c.lane then return false end
 local now=s.now()
 if not finite(now) or now<c.lastNow or now>=c.deadline then return false end
 c.lastNow=now;return true
end
local function cancel(s:any,c:any,why:string)
 c.cancelled,c.problem=true,why
 if c.io then c.io:cancel();c.io=nil end
 -- Closing an admission-only suspension has no native stack to drain.
 if (c.phase=="admission" or c.phase=="new") and coroutine.status(c.thread)=="suspended" then
  coroutine.close(c.thread);c.phase="done";s.busy=false
 end
end
local function collect(s:any,c:any)
 if c.phase=="done" and s._ordinaryContext==c then s._ordinaryContext=nil end
end
local function resume(s:any,c:any)
 if c.phase~="new" and c.phase~="admission" then return end
 if not live(s,c) then cancel(s,c,"ordinary scope/deadline ended");collect(s,c);return end
 c.phase="running"
 local okay,why=coroutine.resume(c.thread)
 if not okay then
  if c.io then c.io:cancel();c.io=nil end
  c.phase,c.failed,c.problem="done",true,tostring(why);s.busy=false
 end
end
local function start(s:any,kind:string,fn:any,args:any,deadline:number):any
 s.ordinaryFramesStarted=(s.ordinaryFramesStarted or 0)+1
 local c:any={kind=kind,phase="new",backend=s.backend,scheduler=s.sched,counters=s.counters,id=s.id,user=tostring(s.cfg.userId),config=s.cfg,
  lane=s.ordinaryAdmission,deadline=deadline,lastNow=s.now(),requests=0,maxRequests=64,cancelled=false}
 c.thread=coroutine.create(function()
  c.result=table.pack(pcall(fn,s,table.unpack(args,1,args.n)))
  if c.io then c.io:cancel();c.io=nil end
  if c.lostLease and not s.closed then s:demote("other_session",true) end
  c.phase="done"
 end)
 s._ordinaryContext=c;resume(s,c);return c
end
function IO.request(s:any,method:string,key:string,transform:any,name:string?):(boolean,any,string?)
 local backend=s.backend
 local fn=if method=="update" then backend.update else backend.readFresh or backend.read
 local item=if name then s.sched.items[name] else nil
 local version=if item then item.version else nil
 if not s.ordinaryAdmission then
  s.sched:begin(name,s.now());s.counters.requests+=1
  return fn(backend,key,transform)
 end
 local c=s._ordinaryContext
 if not c or coroutine.running()~=c.thread or not live(s,c) then error(IO.ABORT,0) end
 local serial=s._loadSerial
 local j={requests=0}
 local function valid():boolean
  if not live(s,c) or s._loadSerial~=serial or name~=nil and (s.sched.items[name]~=item or item.version<version) then return false end
  if s.sched.begin~=Scheduler.begin or s.sched.budgetOk~=Scheduler.budgetOk or s.sched._recoveryStartup~=nil then return false end
  if key~=s.pkey and s.state=="active" and s.lockHeld and c.lastNow-s.sched.lastBeat>=Rules.LOCK_STALE then c.lostLease=true;return false end
  return true
 end
 local proofBeat:any=nil
 local wrapped=if method=="update" then function(old:any):any
  proofBeat=nil
  local candidate=transform(old)
  if type(candidate)=="table" and type(candidate.lock)=="table" and candidate.lock.session==s.id then proofBeat=candidate.lock.beat end
  return candidate
 end else nil
 local bindings={}
 for _,route in {"readFresh","readRawFresh","update"} do
  local provider=if route=="update" then backend.update elseif route=="readRawFresh" then backend.readRawFresh or backend.readFresh or backend.read else backend.readFresh or backend.read
  bindings[route]={object=backend,fn=function(_backend:any,actual:string,callback:any):...any
   -- Operation has validated/counted this dispatch. The captured plain item
   -- receives the logical version selected BEFORE waiting, not a newer one.
   if item then item.sentVersion=version end
   return provider(backend,actual,callback)
  end}
 end
 local op=Operation.new(s,c.lane,valid,{{object=j,field="requests",max=1},{object=c,field="requests",max=c.maxRequests}},bindings)
 c.io=op
 while true do
  local busy=s.busy;c.phase="provider";s.busy=true
  local state,result=op:poll(method,key,wrapped)
  s.busy=busy
  if state=="done" then
   c.io=nil;op:cancel();c.phase="running"
   if result[1]==true and finite(proofBeat) and c.lastNow-proofBeat>=Rules.LOCK_STALE then c.lostLease=true;error(IO.ABORT,0) end
   return table.unpack(result,1,3)
  end
  if state~="waiting" then c.io=nil;op:cancel();error(IO.ABORT,0) end
  if not valid() then c.io=nil;op:cancel();error(IO.ABORT,0) end
  s.busy=false
  if c.kind=="step" then
   c.phase="admission";coroutine.yield(SIGNAL)
  else
   -- Synchronous load/flush owners may be closing and no longer receive ticks.
   -- Their timer yields resume through the engine, never through resume().
   c.phase="external_wait";local before=s.now()
   s.cfg.sleep(math.min(.025,math.max(0,c.deadline-before)))
   if s.now()<=before then c.io=nil;op:cancel();error(IO.ABORT,0) end
  end
  s.busy=busy
  if not valid() then c.io=nil;op:cancel();error(IO.ABORT,0) end
 end
end
function IO.step(s:any,fn:any,ready:any):boolean
 if s._ordinaryContext and s._ordinaryContext.phase=="done" then collect(s,s._ordinaryContext) end
 if s.closed or s.flushing then return false end
 local before=s.counters.requests;local c=s._ordinaryContext
 if c then
  if c.kind~="step" then return false end
  if not live(s,c) and c.phase~="done" then cancel(s,c,"ordinary step ended") end
  resume(s,c);collect(s,c)
 else
  if s.busy then return false end
  if ready and not ready(s,s.now()) then s:notify();return s.counters.requests>before end
  c=start(s,"step",fn,table.pack(),s.now()+180);collect(s,c)
 end
 return s.counters.requests>before
end
local function wait(s:any,c:any)
 while c.phase~="done" do
  if not live(s,c) then cancel(s,c,"ordinary wait scope/deadline ended");break end
  resume(s,c)
  if c.phase~="done" then
   local before=s.now();s.cfg.sleep(math.min(.025,math.max(0,c.deadline-before)))
   if c.phase=="admission" and s.now()<=before then cancel(s,c,"ordinary sleep did not advance clock");break end
  end
 end
 collect(s,c)
end
function IO.load(s:any,fn:any,defer:any):(string,boolean?)
 local running=s._ordinaryContext
 if running and running.kind=="step" and coroutine.running()==running.thread then return fn(s,defer) end
 if s._ordinaryContext and s._ordinaryContext.phase=="done" then collect(s,s._ordinaryContext) end
 if s.closed or s._ordinaryContext or s.flushing then return s.state,false end
 local c=start(s,"load",fn,table.pack(defer),s.now()+180);wait(s,c)
 if s.closed or c.cancelled or c.failed or not c.result or not c.result[1] then
  if c.result and not c.result[1] and c.result[2]~=IO.ABORT then error(c.result[2],0) end
  return s.state,false
 end
 return table.unpack(c.result,2,c.result.n)
end
function IO.flush(s:any,fn:any,deadline:any)
 if s.closed or s.flushing then return end
 local limit=deadline or s.now()+Rules.FLUSH_DEADLINE
 if not finite(limit) or limit<=s.now() then s.closed=true;return end
 local prior=s._ordinaryContext
 if prior and coroutine.running()==prior.thread then
  if prior.phase=="provider" or s.busy then
   cancel(s,prior,"reentrant close during provider");s.closed,s.flushing=true,false;return
  end
  prior.kind,prior.deadline="flush",math.min(prior.deadline,limit)
  fn(s,limit);return
 end
 if prior then
  s.flushing=true
  if prior.phase=="admission" then cancel(s,prior,"ordinary admission superseded by flush") end
  -- A native provider may finish/adopt before the flush. Never resume it from
  -- here and never allow a second request to overlap it.
  while prior.phase~="done" and s.now()<limit do s.cfg.sleep(math.min(.025,math.max(0,limit-s.now()))) end
  if prior.phase~="done" then
   cancel(s,prior,"ordinary drain deadline reached");s.closed,s.flushing=true,false;return
  end
  collect(s,prior);s.flushing=false
 end
 local c=start(s,"flush",fn,table.pack(limit),limit);wait(s,c)
 if c.cancelled or c.failed or not c.result or not c.result[1] then s.closed,s.flushing=true,false end
end
return table.freeze(IO)
