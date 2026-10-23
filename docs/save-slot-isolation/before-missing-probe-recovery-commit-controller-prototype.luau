--!strict
-- Private post-archive coordinator. begin requires the archive controller's
-- completed plan, then independently reconstructs/read-verifies its A1 keys.
-- No entry/credential or ordinary-worker resumption is granted by verified.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local SaveRest=require(Shared.Persistence.SaveRest)
local Scheduler=require(Shared.Persistence.SaveScheduler)
local Stores=require(Shared.Persistence.SaveStores)
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local Fence=require(Shared.Persistence.RecoverySessionFencePrototype)
local ArchiveStore=require(Shared.Persistence.RecoveryArchiveStorePrototype)
local Packet=require(script.Parent.RecoveryPacketPrototype)
local ProposalStore=require(script.Parent.RecoveryProposalStorePrototype)
local RestWriter=require(script.Parent.RecoveryRestWriterPrototype)
local ProgressWriter=require(script.Parent.RecoveryProgressWriterPrototype)
local Controller={};Controller.__index=Controller
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function same(a:any,b:any):boolean
 local pulse=Work.pulse();if pulse then pulse() end
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b and (type(a)~="number" or a~=0 or 1/a==1/b) end
 if getmetatable(b)~=nil then return false end
 for k,v in a do if not same(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
local function release(j:any)
 if j.work then j.work:cancel() end
 if j.child and j.component then j.component:cancel(j.child) end
 j.work,j.child,j.component,j.plan,j.anchor,j.restPlan,j.progressPlan=nil,nil,nil,nil,nil,nil,nil
end
local function stop(j:any,state:string,why:string)
 j.state,j.problem=state,why;Fence.cancel(j.ticket);release(j)
end
function Controller.new(session:any,codec:any,rawBackend:any,template:any,context:any,options:any?):any
 local cfg=options or {};local maxRequests=cfg.maxRequests or 64;local timeout=cfg.timeout or 900
 assert(type(session.backend.readRawFresh)=="function" and type(session.backend.readFresh)=="function","fresh/raw session backend required")
 assert(finite(maxRequests) and maxRequests>=1 and maxRequests<=64 and maxRequests%1==0,"invalid commit request cap")
 assert(finite(timeout) and timeout>=1 and timeout<=900,"invalid commit deadline")
 return setmetatable({session=session,codec=codec,rawBackend=rawBackend,template=template,context=context,options=cfg,
  maxRequests=maxRequests,timeout=timeout,current=nil,busy=false},Controller)
end
function Controller.begin(self:any,mode:string,serial:number,offerId:string,archivePlan:any):(any?,string?)
 local s=self.session
 if self.busy or s.busy or s.flushing or self.current and self.current.state=="pending" then return nil,"recovery worker busy" end
 local ticket,why=Fence.capture(s,mode,serial,offerId);if not ticket then return nil,why end
 if type(archivePlan)~="table" or type(archivePlan.index)~="table" or archivePlan.index.owner~=ticket.owner then Fence.cancel(ticket);return nil,"completed archive plan required" end
 -- The incoming descriptor is not trusted as durability evidence. The first
 -- stage rebuilds A1 from its own stored anchor/parts and verifies every key.
 local j:any={ticket=ticket,state="pending",phase="archive",started=s.now(),nextAt=s.now(),nextBeatAttempt=s.now(),
  failures=0,beatFailures=0,requests=0,expectedArchive=archivePlan.index.checksum,acked=false}
 self.current=j
 j.guard=function() return self.current==j and j.state=="pending" and not s.flushing and Fence.valid(ticket) end
 j.component=ArchiveStore.new(s.backend,ticket.owner)
 j.child,why=j.component:beginRecovery(nil,j.guard)
 if not j.child then stop(j,"refused",why or "archive readback preparation refused");return nil,j.problem end
 return j,nil
end
function Controller.cancel(self:any,j:any):boolean
 if self.current~=j or j.state~="pending" then return false end
 stop(j,"cancelled","recovery commit cancelled");return true
end
local function reserve(self:any,j:any,heartbeat:boolean?):boolean
 local s=self.session;local now=s.now()
 if now<(if heartbeat then j.nextBeatAttempt else j.nextAt) or not s.sched:budgetOk(now) then return false end
 if j.requests>=self.maxRequests then stop(j,"refused","commit request cap reached");return false end
 s.sched:begin(nil,now);s.counters.requests+=1;j.requests+=1;return true
end
local function renew(self:any,j:any):boolean
 local s=self.session;local now=s.now();local verdict=""
 local called,ok,value,why=pcall(s.backend.update,s.backend,s.pkey,function(old:any):any
  verdict=""
  if not j.guard() then verdict="revoked";return nil end
  local opened=Envelope.open(s.pspec,old,false)
  if (opened.status~="ok" and opened.status~="migrated") or type(old)~="table" or type(old.lock)~="table"
   or old.lock.session~=s.id or not finite(old.lock.beat) or now<old.lock.beat or now-old.lock.beat>=Rules.LOCK_STALE then verdict="lost";return nil end
  verdict="owned";local lock=Json.copy(old.lock);lock.beat=now;return Envelope.withLock(old,lock)
 end)
 if not j.guard() then stop(j,"cancelled","session/selected Continue changed");return true end
 if verdict=="lost" then stop(j,"refused","remote lease ownership lost");return true end
 if not called or ok~=true then
  j.beatFailures+=1;j.nextBeatAttempt=now+Scheduler.backoff(j.beatFailures,Stores.classify(tostring(if called then why else ok)));return true
 end
 if verdict~="owned" or type(value)~="table" or type(value.lock)~="table" or value.lock.session~=s.id or value.lock.beat~=now then stop(j,"refused","lease acknowledgement invalid");return true end
 s.sched:beat(now);j.acked=true;j.renewalSerial=(j.renewalSerial or 0)+1;j.beatFailures=0;j.nextBeatAttempt=now;return true
end
local function selected(self:any,j:any,plan:any):boolean
 local ok,raw=pcall(self.codec.decode,self.codec,plan.entries[j.ticket.mode].raw,true);if not ok then return false end
 local identity=j.ticket.identity
 local core=if identity.kind=="backup" and type(raw)=="table" then raw.backup else raw
 return type(core)=="table" and core.checksum==identity.checksum and core.updatedAt==identity.updatedAt
  and type(core.payload)=="table" and core.payload.save_life==identity.life
end
local function worker(self:any,j:any,fn:any,phase:string)
 j.work=Work.new(fn,self.options.work);j.phase=phase
end
local function prepareWriters(self:any,j:any)
 worker(self,j,function():(any?,string?)
  local rest,why=RestWriter.prepare(j.plan,j.anchor,self.codec,self.context);if not rest then return nil,why end
  local progress,errorText=ProgressWriter.prepare(j.anchor,self.codec,self.context);if not progress then return nil,errorText end
  return {rest=rest,progress=progress},nil
 end,"writers")
end
local function stepInner(self:any,j:any):boolean
 local s=self.session;local now=s.now()
 if not j.guard() then stop(j,"cancelled","session/selected Continue changed");return false end
 if not finite(now) or now-j.started>=self.timeout then stop(j,"refused","commit deadline reached");return false end
 if not j.acked or now-s.sched.lastBeat>=Rules.HEARTBEAT then
  if reserve(self,j,true) then return renew(self,j) end
  if j.state~="pending" or not j.acked then return false end
 end
 if j.work then
  j.work:step()
  if not j.guard() then stop(j,"cancelled","session/selected Continue changed");return false end
  if j.work.state=="pending" then return false end
  local result=j.work:take();j.work=nil
  if not result or not result[1] then stop(j,"refused",if result then tostring(result[2]) else "recovery preparation failed");return false end
  if j.phase=="inspect" then
   j.anchor=result[1];j.component=ProposalStore.new(s.backend,self.codec,self.context)
   local why;j.child,why=j.component:begin(j.anchor,j.guard)
   if not j.child then stop(j,"refused",why or "proposal preparation refused");return false end
   j.phase="proposal"
  elseif j.phase=="writers" then
   j.restPlan,j.progressPlan=result[1].rest,result[1].progress
   j.component=RestWriter.new(self.rawBackend);j.child=assert(j.component:begin(j.restPlan,j.guard));j.phase="rest"
  end
  return false
 end
 if j.phase=="probe" then
  if not reserve(self,j) then return false end
  local called,ok,value,why=pcall(s.backend.readRawFresh,s.backend,"M1_"..j.ticket.owner.."_"..j.ticket.mode)
  if not j.guard() then stop(j,"cancelled","session/selected Continue changed");return true end
  if not called or ok~=true then j.failures+=1;j.nextAt=now+Scheduler.backoff(j.failures,Stores.classify(tostring(if called then why else ok)));return true end
  if SaveRest.bounded(value,256,8) or SaveRest.bounded(s.progress,Rules.MAX_PROGRESS_NODES,Rules.MAX_DEPTH) then stop(j,"refused","proposal/session progress exceeds preparation bound");return true end
  local stored=Json.copy(value);local incoming=Json.copy(s.progress);local incomingTime=s.progressTime;local stamp=now
  worker(self,j,function():(any?,string?)
   if not selected(self,j,j.plan) then return nil,"archive differs from selected original" end
   if stored~=nil then
    local payload,problem=Packet.open(stored,self.codec,self.context)
    if not payload then return nil,problem end
    if stored.owner~=j.ticket.owner or stored.slot~=j.ticket.mode or stored.archive~=j.plan.index.checksum
     or stored.source~=j.plan.entries[j.ticket.mode].checksum or payload.source.kind~=j.ticket.identity.kind then return nil,"stored proposal belongs to another selected source" end
    return stored,nil
   end
   return Packet.prepare(j.ticket.owner,j.ticket.mode,j.plan,incoming,incomingTime,self.template,self.context,self.codec,j.ticket.identity.kind,stamp)
  end,"inspect");j.failures=0;j.nextAt=now;return true
 end
 if j.phase=="finalRest" then
  if not reserve(self,j) then return false end
  local called,ok,value,why=pcall(s.backend.readRawFresh,s.backend,j.ticket.rkey)
  if not j.guard() then stop(j,"cancelled","session/selected Continue changed");return true end
  if not called or ok~=true then j.failures+=1;j.nextAt=now+Scheduler.backoff(j.failures,Stores.classify(tostring(if called then why else ok)));return true end
  if not same(j.anchor.target,value) then stop(j,"refused","recovered rest changed before commit verification");return true end
  j.phase="finalLease";return true
 end
 if j.phase=="finalLease" then
  if not reserve(self,j,true) then return false end
  local before=j.renewalSerial or 0;renew(self,j)
  if j.state=="pending" and (j.renewalSerial or 0)>before then
   j.result={anchor=j.anchor,requiresSessionRebind=true,gameplayAuthorized=false};j.state,j.problem="verified",nil
   Fence.cancel(j.ticket);release(j)
  end
  return true
 end
 if not reserve(self,j) then return false end
 local child=j.child;local component=j.component
 if child.state=="retry" then component:retry(child) end
 component:step(child)
 if not j.guard() then stop(j,"cancelled","session/selected Continue changed");return true end
 if child.state=="retry" then
  j.failures+=1;j.nextAt=now+Scheduler.backoff(j.failures,Stores.classify(tostring(child.problem)));j.problem=child.problem
 elseif child.state=="refused" or child.state=="cancelled" then stop(j,"refused",child.problem or "recovery stage refused")
 elseif j.phase=="archive" and child.state=="complete" then
  if child.plan.index.checksum~=j.expectedArchive then stop(j,"refused","durable archive differs from completed plan");return true end
  j.plan=child.plan;j.component,j.child=nil,nil;j.phase="probe";j.failures=0;j.nextAt=now
 elseif j.phase=="proposal" and child.state=="ready" then
  j.anchor=child.anchor;j.component,j.child=nil,nil;prepareWriters(self,j)
 elseif j.phase=="rest" and child.state=="restVerified" then
  j.component=ProgressWriter.new(s.backend,s.id,s.now);j.child=assert(j.component:begin(j.progressPlan,j.guard));j.phase="progress"
 elseif j.phase=="progress" and child.state=="globalVerified" then
  j.component,j.child=nil,nil;j.phase="finalRest";j.failures=0;j.nextAt=now
 else j.failures=0;j.nextAt=now;j.problem=nil end
 return true
end
function Controller.step(self:any,j:any):boolean
 local s=self.session
 if self.current~=j or j.state~="pending" or self.busy or s.busy then return false end
 self.busy=true;s.busy=true;local ok,asked=pcall(stepInner,self,j);self.busy=false;s.busy=false
 if not ok then stop(j,"refused",tostring(asked));return false end
 return asked
end
return table.freeze(Controller)
