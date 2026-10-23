--!strict
-- Adds quiescence to the private all-slot owner; never silently swaps a Session.
local Profile = require(script.Parent.RecoveryProfileOwnerPrototype)
local Rules = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("SaveRules"))
local Owner = {}
Owner.__index = function(_self: any, key: any): any
 return Owner[key] or Profile.__index(_self, key)
end
function Owner.new(config: any, emit: any, common: any, profiles: any): any
 return setmetatable(Profile.new(config, emit, common, profiles), Owner)
end
function Owner.prepareReplacement(self: any): boolean
 local rt, s = self.runtime, self.session
 if self.closed or s.closed or rt.leaving or not rt.accepted or rt.scopeInvalid or rt.pipeline.leaseLost
  or not s.backend:valid(s.backend.held) then return false end
 self.switchRequired, self.pendingSelection, self.queue = true, nil, {}
 rt.intakeClosed = true
 for _, r in s.intents.requests do s.intents:changed(r, "session_replacement") end
 if rt.reader and rt.discovery and rt.discovery.state == "pending" then rt.reader:cancel(rt.discovery) end
 if rt.phase == "recovering" then rt:cancelRecovery() elseif rt.phase == "entering" then rt:cancelEntry() end
 if rt.saveLoop then rt.saveLoop:cancel() end
 return true
end
function Owner.inheritReplacementDebt(self: any, debt: any)
 local s, rt = self.session, self.runtime
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
