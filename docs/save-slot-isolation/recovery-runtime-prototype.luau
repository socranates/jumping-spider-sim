--!strict
-- Private single session owner. Factory/load/tick/selection/departure routing;
-- schema-3 entry and remote protocol/menu integration deliberately remain closed.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Session=require(Shared.Persistence.SaveSession)
local Rules=require(Shared.Data.SaveRules)
local Work=require(Shared.Persistence.SaveWork)
local Base=require(script.Parent.RecoveryProgressBaselinePrototype)
local Reader=require(script.Parent.RecoveryOfferReaderPrototype)
local Pipeline=require(script.Parent.RecoveryPipelinePrototype)
local Idle=require(script.Parent.RecoveryIdlePrototype)
local Departure=require(script.Parent.RecoveryDeparturePrototype)
local ReadLease=require(script.Parent.RecoveryReadLeasePrototype)
local Runtime={};Runtime.__index=Runtime
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function routeMatches(self:any):boolean
 local s=self.session;local r=self.route
 return r~=nil and s.backend==r.backend and s.backend.source==r.provider and s.backend.source==s.backend.boundSource
  and s._loadSerial==r.load and s.id==r.id and s.pkey==r.pkey and tostring(s.cfg.userId)==r.user
  and s.sched==r.scheduler and s.observations==r.observations and s.intents==r.intents
  and (s.recoveryOwner==nil or s.recoveryOwner==self.pipeline)
end
local function available(self:any):boolean
 local s=self.session
 return not Work.pulse() and not self.busy and not self.leaving and not s.closed and not s.flushing and not s.busy
  and not self.pipeline.busy and (s.backend.activeUpdates or 0)==0
  and (self.phase=="normal" or not self.scopeInvalid and routeMatches(self))
end
function Runtime.new(config:any,recovery:any):any
 assert(type(config.sleep)=="function" and type(config.now)=="function","cooperative session clock/sleep required")
 assert(type(recovery)=="table" and type(recovery.rawBackend)=="table" and recovery.codec~=nil and recovery.template~=nil and recovery.context~=nil,"server recovery dependencies required")
 local cfg={};for key,value in config do cfg[key]=value end
 cfg.backend=Base.new(config.backend,tostring(config.userId))
 local s=Session.new(cfg)
 cfg.backend:bindSession(s)
 local self:any=setmetatable({session=s,config=cfg,recovery=recovery,phase="normal",busy=false,leaving=false,accepted=false},Runtime)
 self.pipeline=Pipeline.new(s,recovery.codec,recovery.rawBackend,recovery.template,recovery.context,recovery.pipeline)
 return self
end
function Runtime.load(self:any):...any
 if not available(self) or self.phase~="normal" then return self.session.state,false end
 self.busy=true;local result=table.pack(pcall(self.session.load,self.session));self.busy=false
 if not result[1] then error(result[2],0) end
 return table.unpack(result,2,result.n)
end
local function stopLease(self:any)
 if self.lease then self.lease:cancel() end
 if self.idle then self.idle:cancel() end
 self.lease,self.leaseJob,self.idle,self.idleJob=nil,nil,nil,nil
end
local function hold(self:any):(any?,string?)
 local s=self.session;local held=s.backend.held;local why
 if self.scopeInvalid or not routeMatches(self) then return nil,"routing identity changed before hold" end
 if held==nil then held,why=s.backend:hold(s,true) end
 if held and not s.backend:valid(held) then return nil,"recovery routing baseline changed" end
 if held then held.enforced=true;s.recoveryOwner=self.pipeline end
 return held,why
end
local function lost(self:any,why:string)
 self.phase,self.problem="lost",why;self.pipeline.leaseLost=true
 -- The wrapper also fences an unadopted read phase. No normal flush/load can
 -- replay a whole stale snapshot after an ownership uncertainty.
 hold(self)
 self.result={requiresFreshSession=true,requiresPausedWorker=true,gameplayAuthorized=false,localProgressRetained=true}
end
local function startReadLease(self:any):boolean
 local component
 component=ReadLease.new(self.session,function():boolean
  return self.lease==component and not self.leaving and (self.phase=="discovering" or self.phase=="offered" or self.phase=="offer_refused" or self.phase=="entry_required")
 end,self.session.backend.held)
 self.lease=component;local job,why=component:begin()
 if not job then lost(self,why or "read phase lease unavailable");return false end
 self.leaseJob=job;return true
end
function Runtime.discover(self:any,mode:string,kind:string?):(any?,string?)
 if not available(self) or (self.phase~="normal" and self.phase~="offered" and self.phase~="offer_refused" and self.phase~="held") or self.pipeline.leaseLost then return nil,"discovery routing unavailable" end
 for _,slot in Rules.MODES do
  if self.session.restPending[slot]~=nil or self.session.lifeRequests[slot] and not self.session.lifeRequests[slot].done then return nil,"finish existing rest/life work before discovery" end
 end
 local reader=Reader.new(self.session,self.recovery.codec,self.recovery.context,self.recovery.reader)
 local job,why=reader:begin(mode,kind);if not job then return nil,why end
 if self.phase=="normal" then
  local s=self.session
  self.route={backend=s.backend,provider=s.backend.source,load=s._loadSerial,id=s.id,pkey=s.pkey,user=tostring(s.cfg.userId),scheduler=s.sched,observations=s.observations,intents=s.intents,lastNow=s.now()}
 end
 stopLease(self);self.reader,self.discovery=reader,job;self.phase,self.problem="discovering",nil
 if not startReadLease(self) then reader:cancel(job);return nil,self.problem end
 return job,nil
end
function Runtime.accept(self:any,mode:string,serial:number,offerId:string):(any?,string?)
 if not available(self) or (self.phase~="offered" and self.phase~="held") then return nil,"offered recovery scope required" end
 local d=self.discovery
 if not d or d.state~="offered" or d.mode~=mode or not d.offer or d.offer.id~=offerId then return nil,"current server discovery required" end
 if not self.session:requestLife("continue",mode,serial,offerId) then return nil,"selected Continue refused" end
 local j,why=self.pipeline:begin(mode,serial,offerId,d);if not j then return nil,why end
 stopLease(self);self.accepted=true;self.phase,self.problem="recovering",nil;self.job=j
 return j,nil
end
function Runtime.cancelRecovery(self:any):boolean
 if self.leaving or self.phase~="recovering" or not self.job then return false end
 if not self.pipeline:cancel(self.job) then return false end
 self.phase="held";return true -- idle starts only after any provider drains
end
function Runtime.dismiss(self:any):boolean
 if not available(self) or self.accepted or (self.phase~="offered" and self.phase~="offer_refused" and self.phase~="discovering") then return false end
 if self.discovery and self.discovery.state=="pending" then self.reader:cancel(self.discovery) end
 if self.discovery and self.discovery.offer then
  local latest=self.session.observations.latest[self.discovery.mode]
  if latest and latest.id==self.discovery.offer.id then self.session.observations:withdraw(self.discovery.mode) end
 end
 stopLease(self);self.phase,self.discovery,self.reader="normal",nil,nil;return true
end
local function enterHeld(self:any)
 self.phase="held"
 if not self.idle then
  local idle=Idle.new(self.pipeline);local j,why=idle:begin()
  if not j then lost(self,why or "held maintenance unavailable");return end
  self.idle,self.idleJob=idle,j
 end
end
local function stepInner(self:any):boolean
 local s=self.session
 if self.departureJob then
  local asked=self.departure:step(self.departureJob)
  if self.departureJob.state~="pending" then self.phase,self.result="closed",self.departureJob.result end
  return asked
 end
 if self.leaving or s.closed or self.phase=="lost" or self.phase=="closed" then return false end
 if self.phase=="normal" then return s:step() end
 if self.phase=="recovering" then
  local asked=self.pipeline:step(self.job)
  if self.leaving or s.closed then return asked end -- a yielded call may outlive flush
  if self.job.state=="rebound" then
   local held,why=hold(self)
   if not held then lost(self,why or "post-rebind hold unavailable")
   else self.phase,self.result="entry_required",self.job.result;startReadLease(self) end
  elseif self.job.state~="pending" then enterHeld(self) end
  return asked
 end
 if self.phase=="held" then
  enterHeld(self);if (self.phase::string)=="lost" then return false end
  local asked=self.idle:step(self.idleJob)
  if self.idleJob.state=="lost" then lost(self,self.idleJob.problem or "held lease lost") end
  return asked
 end
 local lease,leaseJob=self.lease,self.leaseJob
 local asked=lease:step(leaseJob)
 if self.leaving or s.closed or self.lease~=lease or self.leaseJob~=leaseJob then return asked end
 if leaseJob.state=="lost" then lost(self,leaseJob.problem or "read lease lost");return asked end
 if asked or self.phase~="discovering" then return asked end
 asked=self.reader:step(self.discovery)
 if self.leaving or s.closed then return asked end
 if self.discovery.state=="offered" then self.phase="offered"
 elseif self.discovery.state~="pending" then self.phase,self.problem="offer_refused",self.discovery.problem end
 return asked
end
function Runtime.step(self:any):boolean
 if self.busy or self.session.busy or self.pipeline.busy or Work.pulse() then return false end
 if self.route and self.phase~="normal" and self.phase~="closed" and not self.leaving then
  local now=self.session.now()
  if not finite(now) or now<self.route.lastNow or not routeMatches(self) then
   self.scopeInvalid=true;lost(self,"routing identity or clock changed");return false
  end
  self.route.lastNow=now
 end
 self.busy=true;local ok,asked=pcall(stepInner,self);self.busy=false
 if not ok then
  if self.leaving or self.session.closed then self.problem=tostring(asked) else lost(self,tostring(asked)) end
  return false
 end
 return asked
end
function Runtime.depart(self:any,deadline:number?):(any?,string?)
 if Work.pulse() then return nil,"departure must run outside preparation" end
 if self.departureJob then return self.departureJob,nil end
 if self.leaving or self.session.closed then return nil,"session already leaving" end
 local now=self.session.now();local untilAt=deadline or now+Rules.FLUSH_DEADLINE
 if not finite(now) or not finite(untilAt) then return nil,"finite departure deadline required" end
 if self.route and self.phase~="normal" and (now<self.route.lastNow or not routeMatches(self)) then self.scopeInvalid=true end
 self.leaving=true;self.flushDeadline=untilAt
 if self.reader and self.discovery and self.discovery.state=="pending" then self.reader:cancel(self.discovery) end
 if untilAt<=now or self.scopeInvalid then
  self.session.closed,self.session.flushing=true,false;self.phase="closed"
  self.result={progressPreserved=false,leaseReleased=false,sessionClosed=true,gameplayAuthorized=false};return nil,"departure deadline or routing scope unavailable"
 end
 if self.session.backend.held==nil and not self.accepted and self.phase~="lost" then
  stopLease(self);return nil,"normal flush required"
 end
 local d=Departure.new(self.pipeline,{timeout=math.min(Rules.FLUSH_DEADLINE,untilAt-now)})
 local j,why=d:begin()
 if not j then
  self.session.closed,self.session.flushing=true,false;self.phase="closed"
  self.result={progressPreserved=false,leaseReleased=false,sessionClosed=true,gameplayAuthorized=false,problem=why};return nil,why
 end
 self.departure,self.departureJob=d,j;return j,nil
end
function Runtime.flush(self:any,deadline:number?)
 local j,why=self:depart(deadline)
 if not j then
  if why=="normal flush required" then
   -- SaveSession.load does not set the normal worker's busy flag. The factory
   -- owner must drain that entire call before entering its ordinary flush.
   while self.busy and self.session.now()<self.flushDeadline do self.config.sleep(math.min(.25,math.max(0,self.flushDeadline-self.session.now()))) end
   if self.busy or self.session.now()>=self.flushDeadline then
    self.session.closed,self.session.flushing=true,false;self.phase="closed"
    self.result={progressPreserved=false,leaseReleased=false,sessionClosed=true,gameplayAuthorized=false}
   else self.session:flush(self.flushDeadline);self.phase="closed" end
  end
  return
 end
 while j.state=="pending" do
  if self.session.now()>=j.deadline then
   j.scope.owner:finishDeparture(j.scope,false);j.state,j.problem="refused","routing departure deadline reached"
   j.result={progressPreserved=false,leaseReleased=false,sessionClosed=true,gameplayAuthorized=false}
   self.phase,self.result="closed",j.result;break
  end
  self:step()
  if j.state=="pending" then self.config.sleep(math.min(.25,math.max(0,j.deadline-self.session.now()))) end
 end
end
return table.freeze(Runtime)
