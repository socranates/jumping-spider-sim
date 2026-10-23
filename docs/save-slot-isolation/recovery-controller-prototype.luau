--!strict
-- Private archive-only controller. The server must call this INSTEAD OF the
-- ordinary session step while pending; no destination/life permission is granted.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Scheduler=require(Shared.Persistence.SaveScheduler)
local Stores=require(Shared.Persistence.SaveStores)
local Work=require(Shared.Persistence.SaveWork)
local Collector=require(script.Parent.RecoverySourceCollectorPrototype)
local Repository=require(script.Parent.RecoveryArchiveStorePrototype)
local Fence=require(script.Parent.RecoverySessionFencePrototype)
local Controller={};Controller.__index=Controller
local function finite(v:any):boolean return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function same(a:any,b:any):boolean
 local pulse=Work.pulse();if pulse then pulse() end
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b and (type(a)~="number" or a~=0 or 1/a==1/b) end
 for k,v in a do if not same(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
-- An archive keeps its first raw lock forever, even after a restart. Only these
-- two known metadata fields may drift. Unknown lock/envelope fields must agree.
local function originalContent(a:any,b:any):boolean
 for _,slot in {"progress","main","free","easy"} do
  local x,y=a.entries[slot].raw,b.entries[slot].raw
  if slot~="progress" then if not same(x,y) then return false end
  else
   if type(x)~="table" or type(y)~="table" or type(x.lock)~="table" or type(y.lock)~="table" then return false end
   for k,v in x do if k~="lock" and not same(v,y[k]) then return false end end
   for k in y do if k~="lock" and x[k]==nil then return false end end
   for k,v in x.lock do if k~="session" and k~="beat" and not same(v,y.lock[k]) then return false end end
   for k in y.lock do if k~="session" and k~="beat" and x.lock[k]==nil then return false end end
  end
 end
 return true
end
function Controller.new(session:any,options:any?):any
 local cfg=options or {};local timeout=cfg.timeout or 900;local maxRequests=cfg.maxRequests or 96
 assert(finite(timeout) and timeout>=1 and timeout<=900,"invalid recovery deadline")
 assert(finite(maxRequests) and maxRequests>=1 and maxRequests%1==0 and maxRequests<=96,"invalid recovery request cap")
 assert(type(session.backend.readFresh)=="function" and type(session.backend.readRawFresh)=="function","explicit fresh/raw backend required")
 return setmetatable({session=session,options=cfg,timeout=timeout,maxRequests=maxRequests,current=nil,busy=false},Controller)
end
local function clear(j:any)
 if j.collector and j.collection then j.collector:cancel(j.collection);j.collector.current=nil end
 if j.repository and j.publication then j.repository:cancel(j.publication) end
 if j.work then j.work:cancel() end
 j.collection,j.publication,j.work,j.sourcePlan=nil,nil,nil,nil
end
local function stop(j:any,state:string,why:string)
 j.state,j.problem=state,why;j.plan=nil;Fence.cancel(j.ticket);clear(j)
end
function Controller.cancel(self:any,j:any):boolean
 if self.current~=j or j.state~="pending" then return false end
 stop(j,"cancelled","recovery cancelled");return true
end
function Controller.begin(self:any,mode:string,serial:number,offerId:string,stamp:string):(any?,string?)
 if self.busy or self.session.busy or self.session.flushing then return nil,"save worker busy" end
 local ticket,why=Fence.capture(self.session,mode,serial,offerId);if not ticket then return nil,why end
 if self.current and self.current.state=="pending" then self:cancel(self.current) end
 local s=self.session;local now=s.now()
 local j:any={ticket=ticket,state="pending",phase="collect",started=now,nextAt=now,nextBeat=now,nextBeatAttempt=now,beatFailures=0,failures=0,requests=0,lastAck=nil,plan=nil}
 j.guard=function() return self.current==j and j.state=="pending" and not s.flushing and Fence.valid(ticket) end
 j.collector=Collector.new(s.backend,ticket.owner,ticket.sessionId,self.options.bounds,self.options.work)
 j.repository=Repository.new(s.backend,ticket.owner,self.options.publicationBounds)
 j.collection=j.collector:begin(stamp,j.guard);self.current=j
 return j,nil
end
local function reserve(self:any,j:any,now:number,heartbeat:boolean?):boolean
 local s=self.session
 if now<(if heartbeat then j.nextBeatAttempt else j.nextAt) or not s.sched:budgetOk(now) then return false end
 if j.requests>=self.maxRequests then stop(j,"refused","recovery request cap reached");return false end
 s.sched:begin(nil,now);s.counters.requests+=1;j.requests+=1;return true
end
local function delay(j:any,now:number,why:any)
 j.failures+=1;j.nextAt=now+Scheduler.backoff(j.failures,Stores.classify(tostring(why)))
 j.problem=tostring(why or "recovery request failed")
end
local function renewed(self:any,j:any,now:number):boolean
 local s=self.session;local outcome=""
 local called,ok,value,why=pcall(s.backend.update,s.backend,s.pkey,function(old:any):any
  outcome=""
  if not j.guard() then outcome="cancelled";return nil end
  local op=Envelope.open(s.pspec,old,false)
  if (op.status~="ok" and op.status~="migrated") or type(old)~="table" or type(old.lock)~="table"
   or old.lock.session~=s.id or not finite(old.lock.beat) or now<old.lock.beat or now-old.lock.beat>=Rules.LOCK_STALE then outcome="lost";return nil end
  outcome="owned"
  local lock={};for k,v in old.lock do lock[k]=v end;lock.session=s.id;lock.beat=now
  return Envelope.withLock(old,lock)
 end)
 if not j.guard() then stop(j,"cancelled","session/Continue changed");return true end
 if outcome=="lost" then stop(j,"refused","fresh lease ownership lost");return true end
 if not called or ok~=true then
  j.beatFailures+=1
  local errorText=tostring(if called then why else ok)
  j.nextBeatAttempt=now+Scheduler.backoff(j.beatFailures,Stores.classify(errorText));j.problem=errorText;return true
 end
 if outcome~="owned" or type(value)~="table" or type(value.lock)~="table" or value.lock.session~=s.id or value.lock.beat~=now then
  stop(j,"refused","lease acknowledgement invalid");return true
 end
 j.lastAck=now;j.nextBeat=now+Rules.HEARTBEAT;j.nextBeatAttempt=now;j.beatFailures=0;s.sched:beat(now)
 return true
end
local function selectedSource(self:any,j:any,plan:any):boolean
 local id=j.ticket.identity;local e=plan.entries[j.ticket.mode].raw
 if self.options.restCodec then
  local ok,value=pcall(self.options.restCodec.decode,self.options.restCodec,e,true)
  if not ok then return false end
  e=value
 end
 if type(e)~="table" then return false end
 if id.kind=="backup" then e=e.backup end
 return type(e)=="table" and e.checksum==id.checksum and e.updatedAt==id.updatedAt and type(e.payload)=="table" and e.payload.save_life==id.life
end
local function stepInner(self:any,j:any):boolean
 local s=self.session
 if not j.guard() then stop(j,"cancelled","session/Continue changed");return false end
 local now=s.now()
 if now-j.started>=self.timeout then stop(j,"refused","recovery deadline reached");return false end
 if j.lastAck==nil or now>=j.nextBeat then
  if reserve(self,j,now,true) then return renewed(self,j,now) end
  if j.state~="pending" then return false end
  if j.lastAck==nil then return false end -- no raw reads before the first acknowledged ownership check
  -- A full request bucket may delay renewal. CPU-only collection/comparison
  -- can still progress under the unexpired guard; no network work is admitted.
 end
 if j.phase=="compare" or j.phase=="select" then
  local selecting=j.phase=="select"
  j.work:step()
  if not j.guard() then stop(j,"cancelled","session/Continue changed");return false end
  if j.work.state=="pending" then return false end
  local result=j.work:take();j.work=nil
  if not result or not result[1] then stop(j,"refused",if selecting then "selected source changed" else "existing archive belongs to a different source observation");return false end
  j.phase=if selecting then "probe" else "archive";return false
 end
 if j.phase=="collect" then
  local c=j.collection
  if c.state=="complete" then
   if self.options.restCodec then
    j.sourcePlan=c.plan;j.work=Work.new(function() return selectedSource(self,j,c.plan) end,self.options.work);j.phase="select";return false
   end
   if not selectedSource(self,j,c.plan) then stop(j,"refused","selected source changed");return false end
   j.sourcePlan=c.plan;j.phase="probe";return false
  end
  if c.state=="retry" then
   if now<j.nextAt then return false end
   j.collector:retry(c)
  elseif c.state~="pending" then stop(j,"refused",c.reason or "raw collection refused");return false end
  local network=j.collector:wantsRead(c)
  if network and not reserve(self,j,now) then return false end
  j.collector:step(c)
  if j.state~="pending" then return network end
  if c.state=="retry" then delay(j,now,c.reason)
  elseif network then j.failures=0;j.problem=nil;j.nextAt=now end
  return network
 end
 if not reserve(self,j,now) then return false end
 if j.phase=="probe" then
  local called,ok,value,why=pcall(s.backend.readFresh,s.backend,"A1_"..j.ticket.owner.."_progress")
  if not j.guard() then stop(j,"cancelled","session/Continue changed");return true end
  if not called or ok~=true then delay(j,now,if called then why else ok);return true end
  local publication,errorText
  if value==nil then publication,errorText=j.repository:begin(j.sourcePlan,j.guard)
  else
   local sources={};for slot,e in j.sourcePlan.entries do sources[slot]={loaded=true,value=e.raw} end
   publication,errorText=j.repository:beginRecovery(sources,j.guard)
  end
  if not publication then stop(j,"refused",errorText or "archive preparation refused");return true end
  j.publication=publication;j.phase="archive";j.nextAt=now;j.failures=0;return true
 end
 local p=j.publication;local before=p.phase
 if p.state=="retry" then j.repository:retry(p) end
 j.repository:step(p)
 if not j.guard() then stop(j,"cancelled","session/Continue changed");return true end
 if p.state=="retry" then delay(j,now,p.problem)
 elseif p.state=="refused" or p.state=="cancelled" then stop(j,"refused",p.problem or "archive publication refused")
 elseif p.state=="complete" then
  j.plan=p.plan;j.state="ready";j.problem=nil;clear(j);Fence.cancel(j.ticket)
 elseif before=="recover" and p.phase=="write" then
  local original,current=j.sourcePlan,p.plan
  j.work=Work.new(function() return originalContent(original,current) end,self.options.work);j.phase="compare"
 else j.failures=0;j.nextAt=now;j.problem=nil end
 return true
end
function Controller.step(self:any,j:any):boolean
 local s=self.session
 if self.current~=j or j.state~="pending" or self.busy or s.busy then return false end
 self.busy=true;s.busy=true
 local ok,asked=pcall(stepInner,self,j)
 self.busy=false;s.busy=false
 if not ok then stop(j,"refused",tostring(asked));return false end
 return asked
end
return table.freeze(Controller)
