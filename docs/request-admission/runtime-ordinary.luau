--!strict
-- Private single session owner. Factory/load/tick/selection/departure routing;
-- Optional schema3 entry is private; production remote/menu wiring remains closed.
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
local function sameIdentity(a:any,b:any):boolean
 return type(a)=="table" and type(b)=="table" and a.kind==b.kind and a.life==b.life and a.checksum==b.checksum and a.updatedAt==b.updatedAt
end
local function routeMatches(self:any):boolean
 local s=self.session;local r=self.route
 return r~=nil and s.backend==r.backend and s.backend.source==r.provider and s.backend.source==s.backend.boundSource
  and s._loadSerial==r.load and s.id==r.id and s.pkey==r.pkey and tostring(s.cfg.userId)==r.user
  and s.sched==r.scheduler and s.observations==r.observations and s.intents==r.intents
  and (s.recoveryOwner==nil or s.recoveryOwner==self.pipeline)
end
local function available(self:any):boolean
 local s=self.session
 return not Work.pulse() and not self.busy and not self.leaving and not self.intakeClosed and not s.closed and not s.flushing and not s.busy
  and not self.pipeline.busy and (s.backend.activeUpdates or 0)==0
  and (self.phase=="normal" or not self.scopeInvalid and routeMatches(self))
end
function Runtime.new(config:any,recovery:any):any
 if config.admission then
  assert(recovery.startupBudget==nil,"ordinary admission replaces the old startup budget")
  local lane=config.admission;local owned=table.clone(recovery)
  local function options(original:any):any
   local cfg=table.clone(original or {})
   assert(cfg.admission==nil or cfg.admission==lane,"Runtime children must share ordinary account lane")
   cfg.admission=lane;return cfg
  end
  assert(owned.lifecycleAdmission==nil or owned.lifecycleAdmission==lane,"Runtime lifecycle lane differs")
  owned.reader=options(recovery.reader);owned.pipeline=options(recovery.pipeline);owned.entryOptions=options(recovery.entryOptions)
  owned.saveOptions=options(recovery.saveOptions)
  owned.saveOptions.progress=options(owned.saveOptions.progress);owned.saveOptions.rest=options(owned.saveOptions.rest)
  owned.lifecycleAdmission=lane;recovery=owned
 end
 assert(type(config.sleep)=="function" and type(config.now)=="function","cooperative session clock/sleep required")
 assert(type(recovery)=="table" and type(recovery.rawBackend)=="table" and recovery.codec~=nil and recovery.template~=nil and recovery.context~=nil,"server recovery dependencies required")
 local cfg={};for key,value in config do cfg[key]=value end
 cfg.backend=Base.new(config.backend,tostring(config.userId))
 local s=Session.new(cfg)
 cfg.backend:bindSession(s)
 local self:any=setmetatable({session=s,config=cfg,recovery=recovery,phase="normal",busy=false,leaving=false,accepted=false},Runtime)
 self.pipeline=Pipeline.new(s,recovery.codec,recovery.rawBackend,recovery.template,recovery.context,recovery.pipeline)
 if recovery.startupBudget then recovery.startupBudget:attach(self) end
 return self
end
function Runtime.load(self:any):...any
 if not available(self) or self.phase~="normal" then return self.session.state,false end
 self.busy,self.loading=true,true;local result=table.pack(pcall(self.session.load,self.session));self.busy,self.loading=false,false
 if self.startup and (not result[1] or self.session.state~="active") then self.startup:close("initial load refused") end
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
 if self.freshWork then self.freshWork:cancel();self.freshWork=nil end
 if self.freshJob and self.freshJob.state=="pending" then self.freshWriter:cancel(self.freshJob) end
 if self.startup then self.startup:close("recovery ownership lost") end
 if self.saveLoop then self.saveLoop:cancel() end
 if self.entry and self.entryJob and self.entryJob.state=="pending" then self.entry:cancel(self.entryJob) end
 self.phase,self.problem="lost",why;self.pipeline.leaseLost=true
 -- The wrapper also fences an unadopted read phase. No normal flush/load can
 -- replay a whole stale snapshot after an ownership uncertainty.
 hold(self)
 self.result={requiresFreshSession=true,requiresPausedWorker=true,gameplayAuthorized=false,localProgressRetained=true}
 for _,r in self.session.intents.requests do if r.state=="writable" then self.session.intents:readonly(r,why) end end
end
local function startReadLease(self:any):boolean
 local component
 component=ReadLease.new(self.session,function():boolean
  return self.lease==component and not self.leaving and (self.phase=="discovering" or self.phase=="offered" or self.phase=="offer_refused" or self.phase=="entry_required" or self.phase=="entering" or self.phase=="recovered" or self.phase=="retired" or self.phase=="fresh_ready")
 end,self.session.backend.held,self.recovery.lifecycleAdmission)
 self.lease=component;local job,why=component:begin()
 if not job then lost(self,why or "read phase lease unavailable");return false end
 self.leaseJob=job;return true
end
function Runtime.discover(self:any,mode:string,kind:string?,retiredNewLife:boolean?):(any?,string?)
 if not available(self) or (self.phase~="normal" and self.phase~="offered" and self.phase~="offer_refused" and self.phase~="held") or self.pipeline.leaseLost then return nil,"discovery routing unavailable" end
 for _,slot in Rules.MODES do
  if self.session.restPending[slot]~=nil or self.session.lifeRequests[slot] and not self.session.lifeRequests[slot].done then return nil,"finish existing rest/life work before discovery" end
 end
 local options={};for k,v in self.recovery.reader or {} do options[k]=v end;options.retiredNewLife=retiredNewLife==true
 local reader=Reader.new(self.session,self.recovery.codec,self.recovery.context,options,self.recovery.currentFormat)
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
 if not d or d.retired or d.state~="offered" or d.mode~=mode or not d.offer or d.offer.id~=offerId then return nil,"current server discovery required" end
 if not self.session:requestLife("continue",mode,serial,offerId) then return nil,"selected Continue refused" end
 if d.continued then
  -- A returning schema3 checkpoint already has a durable original archive and
  -- proposal. Bind the real selected observation; never recommit M1.target.
  local s=self.session;local r=s.intents.requests[mode];local choice=s.observations.choices[mode];local id=d.identity
  if not available(self) or self.discovery~=d or self.phase~="offered" or not r or r.kind~="continue" or r.state~="readonly" or r.credential~=nil
   or r.serial~=serial or r.offerId~=offerId or not r.protected or not choice or choice.serial~=serial or not choice.offer or choice.offer.id~=offerId
   or not choice.offer.protected or not sameIdentity(choice.offer.identity,id) or not sameIdentity(r.base,id) or id.kind~="primary" then return nil,"continued selection changed" end
  local held,why=hold(self);if not held then return nil,why end
  local archive=self.reader:takeContinuedArchive(d);if not archive then return nil,"continued archive proof unavailable" end
  self.continuedSelection=table.freeze({mode=mode,serial=serial,offerId=offerId,identity=id,choice=choice,request=r,revision=r.revision,archive=archive})
  stopLease(self);self.accepted=true;self.phase,self.problem="entry_required",nil
  self.result={requiresSchema3Entry=true,gameplayAuthorized=false,continued=true}
  if not startReadLease(self) then return nil,self.problem end
  return self.continuedSelection,nil
 end
 if self.startup then self.startup:close("legacy migration uses ordinary budget") end
 local j,why=self.pipeline:begin(mode,serial,offerId,d);if not j then return nil,why end
 stopLease(self);self.accepted=true;self.phase,self.problem="recovering",nil;self.job=j
 return j,nil
end
function Runtime.cancelRecovery(self:any):boolean
 if self.leaving or self.phase~="recovering" or not self.job then return false end
 if not self.pipeline:cancel(self.job) then return false end
 self.phase="held";return true -- idle starts only after any provider drains
end
-- Optional private server entry owner. Dependency injection keeps the existing
-- default entry gate closed until its client protocol is explicitly installed.
function Runtime.enter(self:any):(any?,string?)
 if not available(self) or self.phase~="entry_required" or not self.recovery.entryFactory then return nil,"schema3 entry unavailable" end
 local entry=self.recovery.entryFactory.new(self,self.recovery.entryOptions)
 local j,why=entry:begin();if not j then return nil,why end
 self.entry,self.entryJob=entry,j;self.phase,self.problem="entering",nil;return j,nil
end
function Runtime.entryApplied(self:any,msg:any):boolean
 return available(self) and self.phase=="entering" and self.entry:applied(self.entryJob,msg)
end
function Runtime.cancelEntry(self:any):boolean
 if self.leaving or self.phase~="entering" or not self.entry:cancel(self.entryJob) then return false end
 self.phase,self.problem="entry_required","entry cancelled";return true
end
function Runtime.saveRecovered(self:any,mode:any,serial:any,credential:any,life:any,restSerial:any,record:any):boolean
 return available(self) and self.phase=="recovered" and self.saveLoop~=nil and self.saveLoop:submit(mode,serial,credential,life,restSerial,record)
end
function Runtime.dismiss(self:any):boolean
 if not available(self) or self.accepted or (self.phase~="offered" and self.phase~="offer_refused" and self.phase~="discovering") then return false end
 if self.discovery and self.discovery.state=="pending" then self.reader:cancel(self.discovery) end
 if self.discovery and self.discovery.offer then
  local latest=self.session.observations.latest[self.discovery.mode]
  if latest and latest.id==self.discovery.offer.id then self.session.observations:withdraw(self.discovery.mode) end
 end
 if self.startup then self.startup:close("discovery dismissed") end
 stopLease(self);self.phase,self.discovery,self.reader="normal",nil,nil;return true
end
local function enterHeld(self:any)
 self.phase="held"
 if not self.idle then
  local idle=Idle.new(self.pipeline,self.recovery.lifecycleAdmission);local j,why=idle:begin()
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
 if self.phase=="recovered" and self.saveLoop then
  local asked=self.saveLoop:step()
  if not self.leaving and not s.closed and self.saveLoop.state=="lost" then lost(self,self.saveLoop.problem or "recovered save loop lost") end
  return asked
 end
 if self.phase=="freshening" then
  if self.freshWork then
   self.freshWork:step();if self.freshWork.state=="pending" then return false end
   local result=self.freshWork:take();self.freshWork=nil
   if not result or not result[1] then lost(self,if result then result[2] else "fresh marker preparation failed");return false end
   local j,why=self.freshWriter:begin(result[1]);if not j then lost(self,why or "fresh marker admission failed");return false end
   self.freshJob=j;return false
  end
  local j=self.freshJob;local asked=self.freshWriter:step(j)
  if self.leaving or s.closed then return asked end
  if j.state=="verified" then
   self.freshMarker,self.freshLogical=j.plan.candidate,j.plan.logical;self.phase="fresh_ready";self.freshWriter.current=nil
  elseif j.state~="pending" then lost(self,j.problem or "fresh marker refused") end
  return asked
 end
 if (self.phase=="retired" or self.phase=="fresh_ready") and self.lease==nil and not startReadLease(self) then return false end
 local lease,leaseJob=self.lease,self.leaseJob
 local asked=lease:step(leaseJob)
 if self.leaving or s.closed or self.lease~=lease or self.leaseJob~=leaseJob then return asked end
 if leaseJob.state=="lost" then lost(self,leaseJob.problem or "read lease lost");return asked end
 if asked then return true end
 if self.phase=="entering" then
  asked=self.entry:step(self.entryJob)
  if self.leaving or s.closed then return asked end
  if self.entryJob.state=="verified" then
   self.phase,self.result="recovered",self.entryJob.result
   if self.startup then self.startup:close("playable entry verified",true) end
   if self.recovery.saveFactory then stopLease(self);self.saveLoop=self.recovery.saveFactory.new(self) end
   -- A decision callback may yield. Install the completed route first so late
   -- completion cannot reopen a session closed by departure during notification.
   self.result.decisionPending=false;s.intents:notify(self.entryJob.request)
  elseif self.entryJob.state~="pending" then self.phase,self.problem="entry_required",self.entryJob.problem end
  return asked
 end
 if self.phase~="discovering" then return false end
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
-- Explicit server-routed end-of-life/New Life barrier; no fresh-life grant.
function Runtime.retireRecovered(self:any,mode:any,serial:any,credential:any,life:any,restSerial:any,newLifeSerial:any):boolean
 if not available(self) or self.phase~="recovered" or not self.saveLoop then return false end
 return self.saveLoop:retire(mode,serial,credential,life,restSerial,newLifeSerial)
end
-- Explicit New Life discovery may expose a retired marker, never Continue.
function Runtime.discoverNewLife(self:any,mode:string):(any?,string?)
 if not self.recovery.currentFormat or not self.recovery.freshWriterFactory then return nil,"fresh-life recovery dependencies required" end
 return self:discover(mode,nil,true)
end
function Runtime.acceptRetiredFresh(self:any,mode:string,serial:number,offerId:string):(any?,string?)
 if not available(self) or self.phase~="offered" or not self.recovery.freshWriterFactory then return nil,"retired New Life offer required" end
 local d=self.discovery;local s=self.session
 if not d or d.state~="offered" or not d.retired or d.mode~=mode or not d.offer or d.offer.id~=offerId then return nil,"current retired offer required" end
 if not s:requestLife("new",mode,serial,offerId) then return nil,"explicit New Life choice refused" end
 local r=s.intents.requests[mode];local choice=s.observations.choices[mode]
 if not available(self) or self.discovery~=d or self.phase~="offered" or not r or r.kind~="new" or r.state~="readonly" or r.credential~=nil or not r.protected
  or r.serial~=serial or r.offerId~=offerId or not choice or choice.serial~=serial or not choice.offer or choice.offer.id~=offerId
  or not sameIdentity(choice.offer.identity,d.identity) or not sameIdentity(r.base,d.identity) then return nil,"retired selection changed" end
 local held,why=hold(self);if not held then return nil,why end
 local archive=self.reader:takeContinuedArchive(d);local state=self.reader:takeRetiredState(d)
 if not archive or not state then return nil,"retired original proof unavailable" end
 self.retiredSelection=table.freeze({request=r,choice=choice,identity=d.identity});self.retiredRequest=r;self.retiredMode=mode
 self.result={retired=true,rawRest=state.rawRest,anchor=state.anchor,current=state.current,archive=archive,gameplayAuthorized=false}
 stopLease(self);self.phase="retired";self.accepted=true
 local options=table.clone(if self.recovery.saveOptions then self.recovery.saveOptions.rest or {} else {})
 if self.recovery.lifecycleAdmission then
  assert(options.admission==nil or options.admission==self.recovery.lifecycleAdmission,"fresh writer must share lifecycle lane")
  options.admission=self.recovery.lifecycleAdmission
 end
 self.freshWriter=self.recovery.freshWriterFactory.new(s,self.recovery.rawBackend,self.recovery.codec,self.recovery.context,options)
 if not startReadLease(self) then return nil,self.problem end
 return self.retiredSelection,nil
end
function Runtime.prepareFreshLife(self:any):(any?,string?)
 if not available(self) or self.phase~="retired" or (self.saveLoop==nil and self.freshWriter==nil) then return nil,"verified retirement required" end
 self.freshWriter=if self.saveLoop then self.saveLoop.writer else self.freshWriter
 local handle,why=self.freshWriter:captureRetired(self);if not handle then return nil,why end
 stopLease(self);self.phase="freshening"
 local options=if self.recovery.saveOptions then self.recovery.saveOptions.work else nil
 self.freshWork=Work.new(function() return self.freshWriter:prepareFresh(handle,self.result.archive,self.result.anchor,self.result.rawRest) end,options)
 return handle,nil
end
-- Close and drain the old owner before constructing a normal replacement.
function Runtime.replaceFreshLife(self:any,newId:string,deadline:number?):(any?,string?)
 if self.replacement then
  if self.replacement.session.id==newId then return self.replacement,nil end
  return nil,"replacement already selected"
 end
 if not available(self) or self.phase~="fresh_ready" or type(newId)~="string" or #newId<1 or #newId>96 or not string.match(newId,"^[%w_-]+$") or newId==self.session.id then return nil,"distinct fresh server session required" end
 -- A direct replacement cannot reuse the old account epoch's lane. Its
 -- service owner must close/drain that epoch and construct a fresh lane first.
 if self.recovery.lifecycleAdmission then return nil,"service-owned admission replacement required" end
 local source=self.session.backend.source;local marker=self.freshLogical;local mode=if self.saveLoop then self.saveLoop.mode else self.retiredMode
 local serial=if self.retiredRequest then self.retiredRequest.serial else tonumber(string.match(marker.payload.save_life,":(%d+)$"))
 if not serial or serial<1 or serial>Rules.MAX_LIFE_SERIAL then return nil,"retired New Life serial missing" end
 self:flush(deadline)
 local s=self.session
 if (self.phase::string)~="closed" or not s.closed or s.flushing or s.lockHeld or self.busy or s.busy or self.pipeline.busy or self.saveLoop~=nil and self.saveLoop.busy
  or (s.backend.activeUpdates or 0)>0 or s.backend.source~=source or source~=s.backend.boundSource
  or not self.result.progressPreserved or not self.result.leaseReleased then return nil,"old owner did not drain and release" end
 local cfg={};for k,v in self.config do cfg[k]=v end;cfg.backend=source;cfg.sessionId=newId
 local replacement=Runtime.new(cfg,self.recovery)
 replacement.freshStart=table.freeze({mode=mode,serial=serial,identity=table.freeze({kind="primary",checksum=marker.checksum,updatedAt=marker.updatedAt,life=marker.payload.save_life})})
 self.replacement=replacement;return replacement,nil
end
-- Use the real normal observation and intent path; never synthesize a grant.
function Runtime.requestFreshLife(self:any):boolean
 if not available(self) or self.phase~="normal" or not self.freshStart or self.session.state~="active" or not self.session.offersEnabled then return false end
 local f=self.freshStart;local s=self.session;local observed=s.observations.latest[f.mode]
 if not observed or observed.protected or not sameIdentity(observed.identity,f.identity) or observed.record.save_retired~=true then return false end
 return s:requestLife("new",f.mode,f.serial,observed.id)
end
function Runtime.depart(self:any,deadline:number?):(any?,string?)
 if Work.pulse() then return nil,"departure must run outside preparation" end
 if self.departureJob then return self.departureJob,nil end
 if self.leaving or self.session.closed then return nil,"session already leaving" end
 local now=self.session.now();local untilAt=deadline or now+Rules.FLUSH_DEADLINE
 if not finite(now) or not finite(untilAt) then return nil,"finite departure deadline required" end
 if self.route and self.phase~="normal" and (now<self.route.lastNow or not routeMatches(self)) then self.scopeInvalid=true end
 if self.startup then self.startup:close("session departing") end
 if self.freshWork then self.freshWork:cancel();self.freshWork=nil end
 if self.freshJob and self.freshJob.state=="pending" then self.freshWriter:cancel(self.freshJob) end
 self.leaving=true;self.flushDeadline=untilAt
 if self.saveLoop then self.saveLoop:cancel() end
 if self.entry and self.entryJob and self.entryJob.state=="pending" then self.entry:cancel(self.entryJob) end
 if self.reader and self.discovery and self.discovery.state=="pending" then self.reader:cancel(self.discovery) end
 if untilAt<=now or self.scopeInvalid then
  self.session.closed,self.session.flushing=true,false;self.phase="closed"
  self.result={progressPreserved=false,leaseReleased=false,sessionClosed=true,gameplayAuthorized=false};return nil,"departure deadline or routing scope unavailable"
 end
 if self.session.backend.held==nil and not self.accepted and self.phase~="lost" then
  stopLease(self);return nil,"normal flush required"
 end
 stopLease(self)
 local d=Departure.new(self.pipeline,{timeout=math.min(Rules.FLUSH_DEADLINE,untilAt-now),admission=self.recovery.lifecycleAdmission})
 local j,why=d:begin()
 if not j then
  self.session.closed,self.session.flushing=true,false;self.phase="closed"
  self.result={progressPreserved=false,leaseReleased=false,sessionClosed=true,gameplayAuthorized=false,problem=why};return nil,why
 end
 self.departure,self.departureJob=d,j;return j,nil
end
function Runtime.flush(self:any,deadline:number?)
 if self.saveLoop and self.phase=="recovered" and not self.leaving then
  local limit=deadline or self.session.now()+Rules.FLUSH_DEADLINE
  local drainUntil=self.session.now()+math.max(0,(limit-self.session.now())/2)
  self.intakeClosed=true
  while self.saveLoop:hasWork() and self.phase=="recovered" and self.session.now()<drainUntil do
   self:step()
   if self.saveLoop:hasWork() then self.config.sleep(math.min(.25,math.max(0,drainUntil-self.session.now()))) end
  end
  deadline=limit
 end
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
   self.departure:expire(j)
   self.phase,self.result="closed",j.result;break
  end
  self:step()
  if j.state=="pending" then self.config.sleep(math.min(.25,math.max(0,j.deadline-self.session.now()))) end
 end
end
return table.freeze(Runtime)
