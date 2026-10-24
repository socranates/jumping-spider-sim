--!strict
-- Adds quiescence to the private all-slot owner; never silently swaps a Session.
local Profile = require(script.Parent.RecoveryProfileOwnerPrototype)
local Rules = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("SaveRules"))
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ordinary=require(Shared.Persistence.OrdinaryRequestAdmission)
local Owner = {}
Owner.__index = function(_self: any, key: any): any
 return Owner[key] or Profile.__index(_self, key)
end
function Owner.new(config: any, emit: any, common: any, profiles: any): any
 return setmetatable(Profile.new(config, emit, common, profiles), Owner)
end
function Owner.prepareReplacement(self: any, finalProgress: any?): boolean
 local rt, s = self.runtime, self.session
 -- A selected observation may be left before migration accepts any writes.
 -- Its held physical lease still requires the same verified departure; only
 -- an acknowledged fresh session may open the next choice screen.
 if self.closed or s.closed or rt.leaving or rt.scopeInvalid or rt.pipeline.leaseLost then return false end
 local held=s.backend.held
 local normal=held==nil and rt.phase=="normal"
 local normalRoute:any=nil
 if normal then
  if rt.accepted or not self.recoveryEnabled or rt.route~=nil or s.state~="active" or not s.lockHeld then return false end
  normalRoute={backend=s.backend,provider=s.backend.source,load=s._loadSerial,id=s.id,pkey=s.pkey,user=tostring(s.cfg.userId),
   scheduler=s.sched,observations=s.observations,intents=s.intents,lastNow=s.now(),pipeline=rt.pipeline}
 elseif held==nil and (rt.accepted or not self.recoveryEnabled or not rt.route
  or (rt.phase~="discovering" and rt.phase~="offered" and rt.phase~="offer_refused")) then return false end
 local function normalCurrent():boolean
  local r=normalRoute
  return not normal or self.session==s and self.runtime==rt and rt.phase=="normal" and not rt.accepted and rt.route==nil
   and s.backend==r.backend and s.backend.source==r.provider and s.backend.source==s.backend.boundSource
   and s._loadSerial==r.load and s.id==r.id and s.pkey==r.pkey and tostring(s.cfg.userId)==r.user
   and s.sched==r.scheduler and s.observations==r.observations and s.intents==r.intents and rt.pipeline==r.pipeline
   and s.recoveryOwner==nil and s.now()>=r.lastNow
 end
 if not normalCurrent() then return false end
 if held~=nil and not s.backend:valid(held) then return false end
 -- The replacement transport supplies one validated final snapshot through
 -- this explicit path. Ordinary intake may already be closed by a pending New
 -- policy; reopening it just to capture departure progress would allow stale
 -- traffic too. This only updates local P for the same guarded departure.
 if finalProgress~=nil and not s:setProgress(finalProgress) then return false end
 if not normalCurrent() or self.closed or s.closed or rt.leaving or rt.scopeInvalid or rt.pipeline.leaseLost
  or s.backend.held~=held or held~=nil and not s.backend:valid(held) then return false end
 self.switchRequired, self.pendingSelection, self.queue, self.replacementPending = true, nil, {}, true
 rt.intakeClosed = true
 for _, r in s.intents.requests do s.intents:changed(r, "session_replacement") end
 if rt.reader and rt.discovery and rt.discovery.state == "pending" then rt.reader:cancel(rt.discovery) end
 if (rt.phase :: string) == "recovering" then rt:cancelRecovery() elseif (rt.phase :: string) == "entering" then rt:cancelEntry() end
 if rt.saveLoop then rt.saveLoop:cancel() end
 if held==nil then
  -- An ordinary worker or observed read phase keeps an ordinary lease without an
  -- enforcing baseline. Stop intake, drain its provider, then take a distinct
  -- closed-departure hold. Never relabel it as an accepted migration.
  local deadline=s.now()+Rules.FLUSH_DEADLINE
  while self.busy or rt.busy or s.busy or rt.pipeline.busy or (s.backend.activeUpdates or 0)>0
   or s.ordinaryAdmission and not Ordinary.quiesce(s)
   or rt.lease and rt.lease.busy or rt.reader and rt.reader.busy do
   if not normalCurrent() or self.closed or rt.leaving or s.now()>=deadline then return false end
   rt.config.sleep(math.min(.025,math.max(0,deadline-s.now())))
  end
  if not normalCurrent() or self.closed or s.closed or rt.leaving or rt.scopeInvalid or rt.pipeline.leaseLost or s.now()>=deadline then return false end
  if rt.lease then rt.lease:cancel() end
  if rt.reader and rt.discovery and rt.discovery.state=="pending" then rt.reader:cancel(rt.discovery) end
  held=s.backend:hold(s,true);if not held then return false end
  s.recoveryOwner=rt.pipeline
  if normal then
   -- A departure-only route, never a selected or accepted recovery. The same
   -- exact baseline/CAS/readback path closes this ordinary session's lease.
   normalRoute.pipeline=nil;rt.route=normalRoute;rt.phase="held"
  end
 end
 self.replacementReady=true
 return true
end
function Owner.inheritReplacementDebt(self: any, debt: any)
 local s, rt = self.session, self.runtime
 assert(not s.ordinaryAdmission,"typed replacement debt belongs to the account service")
 assert(s.state == "loading" and s.counters.requests == 0 and type(debt) == "table" and #debt <= 64, "unloaded replacement owner required")
 local copy = {}
 for _, time in debt do
  assert(type(time) == "number" and time == time and time <= s.now() and s.now() - time < 60, "recent finite request debt required")
  table.insert(copy, time)
 end
 assert(#copy + 1 + #Rules.MODES <= Rules.REQUESTS_PER_MINUTE, "replacement load requires reserved ordinary budget")
 s.sched.started = copy
 if rt.startup then
  rt.startup:close("replacement retains ordinary request debt")
  rt.startup.normal = table.clone(copy) -- a new epoch cannot reopen a startup lane
 end
end
function Owner.replacementClosed(self: any): boolean
 local rt, s = self.runtime, self.session
 local result = rt.result
 return s.closed and not s.flushing and not s.lockHeld and rt.phase == "closed" and not rt.busy and not s.busy
  and not rt.pipeline.busy and (s.backend.activeUpdates or 0) == 0 and type(result) == "table"
  and result.progressPreserved == true and result.leaseReleased == true and result.sessionClosed == true
end
return table.freeze(Owner)
