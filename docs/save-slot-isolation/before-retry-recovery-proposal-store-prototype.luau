--!strict
-- Private immutable M1 publication only. A caller must separately verify A1 and
-- source/intent/ownership fences; ready grants no selected-rest write authority.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local SaveRest=require(Shared.Persistence.SaveRest)
local Rules=require(Shared.Data.SaveRules)
local Packet=require(script.Parent.RecoveryPacketPrototype)
local Store={};Store.__index=Store
local function freeze(v:any)
 if type(v)~="table" then return end
 for _,x in v do freeze(x) end
 if not table.isfrozen(v) then table.freeze(v) end
end
local function scopeMatches(a:any,s:any):boolean
 return a.owner==s.owner and a.slot==s.slot and a.id==s.id and a.archive==s.archive and a.source==s.source
end
local function live(job:any):boolean
 if job.state=="cancelled" then return false end
 local ok,valid=pcall(job.fence)
 return ok and valid==true and job.state~="cancelled"
end
local function refuse(job:any,why:string)
 if job.state~="cancelled" then job.state,job.problem="refused",why end
end
function Store.new(backend:any,codec:any,context:any):any
 assert(type(backend.update)=="function" and type(backend.readRawFresh)=="function","proposal store requires uncached raw readback")
 return setmetatable({backend=backend,codec=codec,context=context},Store)
end
local function own(value:any):(any?,string?)
 -- M1 is a small header plus opaque compressed strings, never an expanded
 -- checkpoint graph. Bound before copying or checksumming hostile readbacks.
 local why=SaveRest.bounded(value,256,8);if why then return nil,why end
 local text,errorText=Json.canonical(value)
 if not text or #text>Rules.MAX_VALUE_CHARS then return nil,errorText or "proposal value exceeds bound" end
 local owned=Json.copy(value);freeze(owned);return owned,nil
end
-- The supplied candidate defines the exact archive/selected-source scope. An
-- already-persisted valid proposal in that scope wins even if a later encoding
-- or global observation differs. Its saved bytes and rare binding are reused.
function Store.begin(self:any,candidate:any,fence:any):(any?,string?)
 if Work.pulse() then return nil,"proposal storage must run outside preparation" end
 if type(fence)~="function" then return nil,"proposal storage needs a fence" end
 local owned,ownershipError=own(candidate)
 if not owned then return nil,ownershipError end
 local opened,why=Packet.open(owned,self.codec,self.context)
 if not opened then return nil,why end
 freeze(owned)
 return {repository=self,candidate=owned,scope={owner=owned.owner,slot=owned.slot,id=owned.id,archive=owned.archive,source=owned.source},
  fence=fence,state="pending",phase="read",requests=0,problem=nil},nil
end
function Store.cancel(self:any,job:any):boolean
 if job.repository~=self or job.state=="ready" or job.state=="cancelled" then return false end
 job.state,job.problem="cancelled","proposal publication cancelled";return true
end
function Store.retry(self:any,job:any):boolean
 if job.repository~=self or job.state~="retry" then return false end
 if not live(job) then refuse(job,"proposal authority/source changed");return false end
 job.state,job.phase,job.problem="pending","read",nil;return true
end
function Store.step(self:any,job:any):boolean
 if job.repository~=self or job.state~="pending" then return false end
 if Work.pulse() then refuse(job,"proposal storage must run outside preparation");return false end
 if not live(job) then refuse(job,"proposal authority/source changed");return false end
 job.state="running";job.requests+=1
 if job.phase=="write" then
  local called,ok,_value,why=pcall(self.backend.update,self.backend,job.scope.id,function(old:any):any
   if not live(job) or old~=nil then return nil end
   return job.candidate
  end)
  if (job.state::string)=="cancelled" then return false end
  if not live(job) then refuse(job,"proposal authority/source changed");return false end
  job.lastWriteError=if called and ok==true then nil else tostring(if called then why else ok)
  -- Both acknowledgements and ambiguous failures require fresh raw readback.
  job.phase,job.state="read","pending";return true
 end
 local called,ok,raw,why=pcall(self.backend.readRawFresh,self.backend,job.scope.id)
 if (job.state::string)=="cancelled" then return false end
 if not live(job) then refuse(job,"proposal authority/source changed");return false end
 if not called or ok~=true then
  job.state,job.problem="retry",tostring(if called then why else ok);return false
 end
 if raw==nil then
  if job.lastWriteError then job.state,job.problem="retry",job.lastWriteError;return false end
  job.phase,job.state="write","pending";return true
 end
 local owned,ownershipError=own(raw)
 if not owned then refuse(job,ownershipError or "proposal readback cannot be owned");return false end
 local payload,problem=Packet.open(owned,self.codec,self.context)
 if not payload then refuse(job,problem or "invalid stored proposal");return false end
 if not scopeMatches(owned,job.scope) then refuse(job,"a different proposal occupies this key");return false end
 -- Validation may cooperatively yield; revocation during CPU work also fences
 -- publication visibility. Only expose an owned immutable value after it ends.
 if not live(job) then refuse(job,"proposal authority/source changed");return false end
 freeze(owned);freeze(payload)
 job.anchor,job.payload,job.state,job.problem=owned,payload,"ready",nil
 return true
end
return table.freeze(Store)
