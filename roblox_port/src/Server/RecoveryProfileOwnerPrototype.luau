--!strict
-- Server-authored profiles over ONE session/worker/quota. This remains private:
-- engine installation and replacement epochs are separate gates.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Data.SaveRules)
local Json = require(Shared.Persistence.Json)
local SaveRest = require(Shared.Persistence.SaveRest)
local BaseOwner = require(script.Parent.RecoveryServiceOwnerPrototype)
local Pipeline = require(script.Parent.RecoveryPipelinePrototype)
local ReadLease = require(script.Parent.RecoveryReadLeasePrototype)
local Options = require(script.Parent.RecoveryProfileAdmissionOptions)
local Profile = {}
Profile.__index = function(_self: any, key: any): any
 return Profile[key] or BaseOwner[key]
end

local function freeze(value: any)
 if type(value) ~= "table" or table.isfrozen(value) then return end
 for _, child in value do freeze(child) end
 table.freeze(value)
end
local function slot(mode: any): boolean
 return type(mode) == "string" and table.find(Rules.MODES, mode) ~= nil
end
local function validNewChoice(self:any,mode:any,serial:any,id:any):boolean
 if not slot(mode) or type(serial)~="number" or serial~=serial or serial<1 or serial>Rules.MAX_LIFE_SERIAL or serial%1~=0
  or type(id)~="string" or #id==0 or #id>Rules.MAX_LIFE_TOKEN_CHARS then return false end
 local observed=self.session.observations.latest[mode]
 return observed~=nil and observed.id==id and observed.protected==true
end
local function alive(self: any): boolean
 local rt, s = self.runtime, self.session
 return not self.closed and not s.closed and not rt.leaving and rt.session == s
end
local function dependencies(self: any, mode: string): any
 local out = {}; for key, value in self.common do out[key] = value end
 out.template, out.context = self.profiles[mode].template, self.profiles[mode].context
 return Options.bind(out,if self.session then self.session.ordinaryAdmission else self.admission)
end
function Profile.new(config: any, emit: any, common: any, profiles: any): any
 assert(type(common) == "table" and type(profiles) == "table" and getmetatable(profiles) == nil, "trusted server profiles required")
 for key in profiles do assert(slot(key), "unknown server profile") end
 local owned = {}
 for _, mode in Rules.MODES do
  local p = profiles[mode]
  assert(type(p) == "table" and getmetatable(p) == nil and p.context ~= nil
   and type(p.template) == "table" and SaveRest.bounded(p.template, Rules.MAX_REST_NODES, Rules.MAX_DEPTH) == nil,
   "bounded server template/context required for every slot")
  local template = Json.copy(p.template); freeze(template)
  owned[mode] = table.freeze({template = template, context = p.context})
 end
 local commonOwned = {}; for key, value in common do commonOwned[key] = value end
 local seed = {common = table.freeze(commonOwned), profiles = table.freeze(owned), admission = config.admission}
 local self = BaseOwner.new(config, emit, dependencies(seed, "main"), "main")
 self.common, self.profiles = seed.common, seed.profiles
 self.queue, self.lastChoiceSerial = {}, 0
 return setmetatable(self, Profile)
end
local function enqueueProtected(self: any)
 if not self.recoveryEnabled or self.runtime.accepted then return end
 for _, mode in Rules.MODES do
  if self.session.restProtected[mode] then self.queue[mode] = true end
 end
end
local function publishOrdinaryLoaded(self:any)
 if not self.negotiated or not self.session.offersEnabled then return end
 local s=self.session
 for _,mode in Rules.MODES do
  if s.restLoaded[mode] and not s.restProtected[mode] and s.restRevision[mode]~=nil then
   local record=s.rests[mode]
   if not record and SaveRest.validLife(s.lifeTokens[mode]) then record={save_retired=true,save_life=s.lifeTokens[mode]} end
   if record then
    local offer=s.observations:publish(mode,record,{kind="primary",checksum=s.restRevision[mode],updatedAt=s.restBase[mode],life=s.lifeTokens[mode]},false)
    if offer and s.cfg.onOffer then s.cfg.onOffer(mode,offer) end
   end
  end
 end
end
function Profile.enableOffers(self:any)
 BaseOwner.enableOffers(self);publishOrdinaryLoaded(self)
end
function Profile.load(self: any): ...any
 local result = table.pack(BaseOwner.load(self))
 self.pendingDiscovery = nil -- the base owner deliberately serves one slot
 enqueueProtected(self)
 publishOrdinaryLoaded(self)
 return table.unpack(result, 1, result.n)
end
function Profile.enableRecovery(self: any)
 if not alive(self) or self.recoveryEnabled then return end
 self.recoveryEnabled = true; enqueueProtected(self)
end
function Profile.installNewLifeFactory(self:any,factory:any)
 assert(self.session.state=="loading" and not self.newLifeFactory and type(factory)=="table" and type(factory.new)=="function","trusted pre-load New policy factory required")
 self.newLifeFactory=factory
end
function Profile.prepareNewLife(self:any,mode:any,serial:any,id:any,progress:any):boolean
 if not alive(self) or not self.newLifeFactory or not self.recoveryEnabled or self.runtime.accepted or self.replacementPending
  or not validNewChoice(self,mode,serial,id) then return false end
 local prior=self.newLifeRequest
 if prior then return prior.mode==mode and prior.serial==serial and prior.id==id end
 if not self:setProgress(progress) or not self:requestLife("new",mode,serial,id) then return false end
 self.newLifeRequest={mode=mode,serial=serial,id=id,state="pending"}
 return true
end
function Profile.newLifeStatus(self:any):any
 local n=self.newLifeRequest
 if not n then return nil end
 local r=self.session.intents.requests[n.mode]
 if not alive(self) or not r or r.kind~="new" or r.serial~=n.serial or r.offerId~=n.id or r.state~="readonly" or r.credential~=nil then return "refused" end
 if self.newLifeJob then return if self.newLifeJob.state=="verified" then "verified" elseif self.newLifeJob.state=="pending" then "pending" else "refused" end
 return n.state
end
function Profile.refreshOffer(self: any, mode: any): boolean
 if not alive(self) or not slot(mode) then return false end
 if not self.recoveryEnabled then return BaseOwner.refreshOffer(self, mode) end
 if self.runtime.accepted then return false end
 if self.session.restProtected[mode] then self.queue[mode] = true; return true end
 return self.runtime.phase == "normal" and self.session:refreshOffer(mode)
end
local function cancelReader(self: any)
 local rt = self.runtime
 if rt.reader and rt.discovery and rt.discovery.state == "pending" then rt.reader:cancel(rt.discovery) end
end
local function stopLease(rt: any)
 if rt.lease then rt.lease:cancel() end
 if rt.idle then rt.idle:cancel() end
 rt.lease, rt.leaseJob, rt.idle, rt.idleJob = nil, nil, nil, nil
end
-- A read can be cancelled from a reentrant choice callback. Binding is deferred
-- until its provider has returned, its guard has refused publication, and every
-- component has dropped its worker lock.
local function canBind(self: any): boolean
 local rt, s = self.runtime, self.session
 if not alive(self) or self.busy or rt.busy or s.busy or s._ordinaryContext~=nil or s.flushing or s.state ~= "active" or not s.lockHeld
  or rt.accepted or rt.intakeClosed or rt.scopeInvalid or rt.pipeline.busy or rt.pipeline.leaseLost
  or (s.backend.activeUpdates or 0) > 0 or s.backend.held ~= nil or s.recoveryOwner ~= nil
  or rt.reader and rt.reader.busy or rt.lease and rt.lease.busy
  or rt.discovery and rt.discovery.state == "pending" or rt.pipeline.current and rt.pipeline.current.state == "pending"
  or rt.phase ~= "normal" and rt.phase ~= "offered" and rt.phase ~= "offer_refused" then return false end
 local r = rt.route
 return r == nil or s.backend == r.backend and s.backend.source == r.provider and s.backend.source == s.backend.boundSource
  and s._loadSerial == r.load and s.id == r.id and s.pkey == r.pkey and tostring(s.cfg.userId) == r.user
  and s.sched == r.scheduler and s.observations == r.observations and s.intents == r.intents
end
local function bind(self: any, mode: string): boolean
 if not canBind(self) then return false end
 local rt, deps = self.runtime, dependencies(self, mode)
 -- A new pipeline is essential: it captures the destination/context in new().
 local pipeline = Pipeline.new(self.session, deps.codec, deps.rawBackend, deps.template, deps.context, deps.pipeline)
 stopLease(rt); rt.pipeline, rt.recovery = pipeline, deps; self.mode = mode
 return true
end
local function ordinary(self: any): boolean
 if not canBind(self) then return false end
 local rt = self.runtime
 stopLease(rt)
 rt.phase, rt.route, rt.reader, rt.discovery, rt.problem = "normal", nil, nil, nil, nil
 self.readJob, self.readingChoice, self.pendingSelection = nil, nil, nil
 self.queue = {} -- gameplay takes priority over optional background discovery
 return true
end
local function valid(kind: any, mode: any, serial: any, offerId: any): boolean
 return slot(mode) and (kind == "new" or kind == "continue") and type(serial) == "number" and serial == serial
  and serial >= 1 and serial <= Rules.MAX_LIFE_SERIAL and serial % 1 == 0
  and (kind == "new" and offerId == nil or type(offerId) == "string"
   and #offerId > 0 and #offerId <= Rules.MAX_LIFE_TOKEN_CHARS)
end
function Profile.requestLife(self: any, kind: any, mode: any, serial: any, offerId: any): boolean
 if not alive(self) or not valid(kind, mode, serial, offerId) or not self.session.offersEnabled
  or mode == "easy" and not self.session.progress.finished_main then return false end
 local prior = self.choice
 if serial <= self.lastChoiceSerial then
  if prior and serial == prior.serial and kind == prior.kind and mode == prior.mode and offerId == prior.offerId then
   local r = self.session.intents.requests[mode]; if r then self.session.intents:notify(r) end
   return true
  end
  return false
 end
 local choice = {kind = kind, mode = mode, serial = serial, offerId = offerId}
 self.backgroundOrdinaryMode=nil -- an explicit choice supersedes optional discovery
 self.choice, self.lastChoiceSerial = choice, serial -- before callbacks can reenter
 if not self.session:requestLife(kind, mode, serial, offerId) then return false end
 if self.choice ~= choice then return true end
 local s, rt = self.session, self.runtime
 choice.request = s.intents.requests[mode]
 for other, r in s.intents.requests do
  if other ~= mode then
   s.intents:changed(r, "choice_superseded")
   if self.choice ~= choice then return true end
  end
 end
 if self.choice ~= choice then return true end
 cancelReader(self)
 if rt.accepted then
  -- No profile switch after writes. Revoke the old request immediately, retain
  -- the owned hold, and require a separately negotiated replacement epoch.
  self.switchRequired = true; self.pendingSelection = nil; self.queue = {}
  if rt.phase == "recovering" then rt:cancelRecovery() elseif rt.phase == "entering" then rt:cancelEntry() end
  if rt.saveLoop then rt.saveLoop:cancel() end
  s.intents:readonly(choice.request, "recovery_owner_switch_required")
  return true
 end
 if choice.request.state == "changed" then self.pendingSelection = nil; return true end
 self.pendingSelection = choice
 self.queue[mode] = if s.restProtected[mode] then true else nil
 return true
end
function Profile.setRestForIntent(self:any,mode:any,record:any,life:any,serial:any,credential:any,restSerial:any):boolean
 local rt,s=self.runtime,self.session
 -- Optional protected-slot reads must not discard checkpoints from an already
 -- granted ordinary life. Queue them on that same Session; writes resume once
 -- the bounded background read returns to the normal worker.
 if alive(self) and not rt.accepted and not rt.intakeClosed and s.backend.held==nil
  and s.intents:authorized(mode,serial,credential,life) then
  return s:setRestForIntent(mode,record,life,serial,credential,restSerial)
 end
 return BaseOwner.setRestForIntent(self,mode,record,life,serial,credential,restSerial)
end
function Profile.applyRecovery(self: any, message: any): boolean
 local choice, job = self.choice, self.runtime.entryJob
 if self.switchRequired or not choice or not job or not job.offer
  or choice.mode ~= job.offer.mode or choice.serial ~= job.offer.serial then return false end
 return BaseOwner.applyRecovery(self, message)
end
local function processChoice(self: any)
 local choice, rt = self.pendingSelection, self.runtime
 if not choice or self.choice ~= choice then return end
 local request = self.session.intents.requests[choice.mode]
 if request ~= choice.request or request.state == "changed" then self.pendingSelection = nil; return end
 if not self.session.restProtected[choice.mode] then ordinary(self); return end
 if choice.kind ~= "continue" then
  if self.mode ~= choice.mode and not bind(self, choice.mode) then return end
  -- New keeps the exact displayed observation for its separately admitted
  -- retirement policy. A background Continue discovery must not replace an
  -- explicitly observed retired source or invalidate that New selection.
  self.queue = {} -- an explicit New selection takes priority over background offers
  if self.newLifeRequest and rt.phase=="normal" then
   -- A cached protected observation may have been read while an ordinary life
   -- remained writable. Establish the same tracked read scope without replacing
   -- that exact observation; Policy.begin re-reads and verifies its raw source.
   local s=self.session
   rt.route={backend=s.backend,provider=s.backend.source,load=s._loadSerial,id=s.id,pkey=s.pkey,user=tostring(s.cfg.userId),scheduler=s.sched,observations=s.observations,intents=s.intents,lastNow=s.now()}
   rt.phase="offered"
  end
  self.session.intents:readonly(request, "protected_new_life_requires_policy"); self.pendingSelection = nil; return
 end
 if self.readingChoice ~= choice or self.readJob ~= rt.discovery or not self.readJob or self.readJob.state == "pending" then return end
 local job = self.readJob
 self.pendingSelection = nil
 if job.state ~= "offered" or not job.offer or job.offer.id ~= choice.offerId then
  self.session.intents:changed(request, "offer_changed"); return
 end
 local accepted, why = rt:accept(choice.mode, choice.serial, choice.offerId)
 if not accepted then self.session.intents:readonly(request, why or "recovery_selection_refused") end
end
local function stepSwitchHold(self: any): boolean
 local rt, s = self.runtime, self.session
 if rt.phase == "lost" or rt.phase == "closed" or rt.pipeline.busy or (s.backend.activeUpdates or 0) > 0 then return false end
 if not self.switchLease then
  -- A rebound pipeline is not a cancelled pipeline. Its terminal-transaction
  -- Idle helper cannot maintain this entry hold. Use the existing lease-only
  -- helper, which can renew metadata without restoring/granting/writing rests.
  stopLease(rt); rt.phase = "held"
  local lease = ReadLease.new(s, function(): boolean
   return alive(self) and self.switchRequired == true and rt.phase == "held"
  end, s.backend.held, s.ordinaryAdmission)
  local job, why = lease:begin()
  if not job then rt.phase, rt.problem = "lost", why; rt.pipeline.leaseLost = true; return false end
  self.switchLease, self.switchLeaseJob = lease, job
  rt.lease, rt.leaseJob = lease, job -- departure retains the same worker identity
 end
 self.busy = true
 local ok, asked = pcall(self.switchLease.step, self.switchLease, self.switchLeaseJob)
 self.busy = false
 if not ok or self.switchLeaseJob.state == "lost" then
  rt.phase, rt.problem = "lost", if ok then self.switchLeaseJob.problem else tostring(asked)
  rt.pipeline.leaseLost = true; return false
 end
 return asked
end
function Profile.step(self: any): boolean
 if not alive(self) or self.busy or self.runtime.busy or self.session.busy then return false end
 local rt = self.runtime
 if not self.recoveryEnabled then return BaseOwner.step(self) end
 if self.replacementPending and not self.replacementReady then return false end
 if self.switchRequired and (rt.accepted or self.replacementPending) then
  return stepSwitchHold(self)
 end
 if self.newLifePolicy then return self.newLifePolicy:step(self.newLifeJob) end
 if rt.phase=="normal" and self.pendingSelection then
  for _,mode in Rules.MODES do
   if self.session.restPending[mode] or self.session.lifeRequests[mode] and not self.session.lifeRequests[mode].done then return BaseOwner.step(self) end
  end
 end
 processChoice(self)
 local n=self.newLifeRequest
 if n and n.state=="pending" and not self.pendingSelection and self.mode==n.mode and (rt.phase=="offered" or rt.phase=="offer_refused") then
  local okay,policy,job,why=pcall(function():...any
   local worker=self.newLifeFactory.new(rt)
   assert(not self.session.ordinaryAdmission or worker.options and worker.options.admission==self.session.ordinaryAdmission,"New factory dropped ordinary account lane")
   local work,problem=worker:begin(n.mode,n.serial,n.id)
   return worker,work,problem
  end)
  if okay and job then self.newLifePolicy,self.newLifeJob=policy,job
  else n.state,n.problem="refused",tostring(if okay then why else policy) end
  return false
 end
 if rt.accepted then return BaseOwner.step(self) end
 if canBind(self) then
  local pending = self.pendingSelection
  local mode = if pending and self.queue[pending.mode] then pending.mode else nil
  if not mode then for _, candidate in Rules.MODES do if self.queue[candidate] then mode = candidate; break end end end
  if mode and not pending then
   for _,slotMode in Rules.MODES do
    if self.session.restPending[slotMode] or self.session.lifeRequests[slotMode] and not self.session.lifeRequests[slotMode].done then return BaseOwner.step(self) end
   end
  end
  if mode and self.negotiated and bind(self, mode) then
   -- The trusted New policy can observe a persisted retirement marker for New
   -- only; Runtime.accept still refuses to Continue a retired discovery.
   local job, why = rt:discover(mode,nil,self.newLifeFactory~=nil)
   if job then
    if not pending then
     for slotMode,r in self.session.intents.requests do if r.state=="writable" and not self.session.restProtected[slotMode] then self.backgroundOrdinaryMode=slotMode;break end end
    end
    self.queue[mode] = nil; self.readJob = job
    self.readingChoice = if pending and pending.mode == mode then pending else nil
   else self.problem = why end
   return false
  end
 end
 local asked=BaseOwner.step(self)
 local background=self.backgroundOrdinaryMode
 if background and not self.pendingSelection and not rt.accepted and (rt.phase=="offered" or rt.phase=="offer_refused") and bind(self,background) then
  -- Keep the published observation. Runtime.dismiss would withdraw it, which
  -- makes the menu rediscover the same slot indefinitely.
  stopLease(rt);rt.phase,rt.route,rt.reader,rt.discovery,rt.problem="normal",nil,nil,nil,nil
  self.readJob,self.readingChoice,self.backgroundOrdinaryMode=nil,nil,nil
 end
 return asked
end
return table.freeze(Profile)
