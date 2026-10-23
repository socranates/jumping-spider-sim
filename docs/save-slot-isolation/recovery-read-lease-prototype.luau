--!strict
-- Private lease-only routing for read/entry phases, outside an accepted recovery
-- transaction. Unlike normal SaveSession.step, it never merges payloads/previews.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local SaveRest=require(Shared.Persistence.SaveRest)
local Json=require(Shared.Persistence.Json)
local Scheduler=require(Shared.Persistence.SaveScheduler)
local Stores=require(Shared.Persistence.SaveStores)
local Work=require(Shared.Persistence.SaveWork)
local Lease={};Lease.__index=Lease
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function known(v:any,fields:any):boolean
 if type(v)~="table" or getmetatable(v)~=nil then return false end
 for key in v do if not fields[key] then return false end end
 return true
end
function Lease.new(session:any,enabled:any,held:any?):any
 assert(type(enabled)=="function","server scope guard required")
 return setmetatable({session=session,enabled=enabled,held=held,busy=false},Lease)
end
local function identity(self:any,j:any):boolean
 local s=self.session
 return s.backend==j.backend and j.backend.source==j.backend.boundSource and j.backend.held==self.held
  and s._loadSerial==j.load and s.sched==j.scheduler and s.id==j.id and s.pkey==j.pkey and tostring(s.cfg.userId)==j.user
  and s.state=="active" and s.lockHeld and s.recoveryOwner==j.recoveryOwner and (self.held==nil or j.backend:valid(self.held))
end
function Lease.begin(self:any):(any?,string?)
 local s=self.session;local now=s.now()
 if Work.pulse() or self.current~=nil or not finite(now) or s.closed or s.flushing or s.busy or (s.backend.activeUpdates or 0)>0 then return nil,"read lease scope unavailable" end
 local j={state="pending",phase="probe",backend=s.backend,load=s._loadSerial,scheduler=s.sched,id=s.id,pkey=s.pkey,user=tostring(s.cfg.userId),recoveryOwner=s.recoveryOwner,lastNow=now,expiresAt=now+Rules.LOCK_STALE,nextAt=now,failures=0,requests=0}
 if not identity(self,j) or not self.enabled() then return nil,"read lease identity unavailable" end
 self.current=j;return j,nil
end
function Lease.cancel(self:any):boolean
 if not self.current or self.current.state~="pending" or self.busy then return false end
 self.current.state="stopped";return true
end
local function live(self:any,j:any):boolean
 local s=self.session;local now=s.now()
 if s.closed or s.flushing or not self.enabled() then j.state,j.problem="stopped","read lease scope ended";return false end
 if not finite(now) or now<j.lastNow or now>=j.expiresAt or not identity(self,j) then j.state,j.problem="lost","read lease identity/observation expired";return false end
 j.lastNow=now;return true
end
local function owned(self:any,raw:any):(boolean,string?)
 if SaveRest.bounded(raw,Rules.MAX_PROGRESS_NODES*2+64,Rules.MAX_DEPTH+2)
  or not known(raw,{format=true,kind=true,schema=true,updatedAt=true,payload=true,checksum=true,backup=true,lock=true,session=true})
  or not known(raw.lock,{session=true,beat=true}) then return false,"unsupported read lease progress/lock" end
 local opened=Envelope.open(self.session.pspec,raw,false)
 if opened.status~="ok" and opened.status~="migrated" then return false,"read lease primary is "..opened.status end
 local now=self.session.now();local lock=raw.lock
 if lock.session~=self.session.id or not finite(lock.beat) or now<lock.beat or now-lock.beat>=Rules.LOCK_STALE then return false,"fresh owned read lease required" end
 return true,nil
end
local function fail(self:any,j:any,why:any)
 j.failures+=1;j.problem=tostring(why);j.nextAt=self.session.now()+Scheduler.backoff(j.failures,Stores.classify(j.problem))
end
local function request(self:any,j:any):boolean
 local s=self.session
 if j.phase=="probe" then
  local called,ok,value,why=pcall(j.backend.readRawFresh,j.backend,s.pkey)
  if not live(self,j) then return true end
  if not called or ok~=true then fail(self,j,if called then why else ok);return true end
  local good,problem=owned(self,value)
  if not good then j.state,j.problem="lost",problem;return true end
  s.sched:beat(value.lock.beat);j.expiresAt=value.lock.beat+Rules.LOCK_STALE;j.phase="renew"
 else
  local rejected:string?=nil;local expected:string?=nil
  local called,ok,value,why=pcall(j.backend.update,j.backend,s.pkey,function(old:any):any
   rejected,expected=nil,nil
   if not live(self,j) then rejected="read lease scope changed";return nil end
   local good,problem=owned(self,old);if not good then rejected=problem;return nil end
   local candidate=Envelope.withLock(old,{session=s.id,beat=s.now()});expected=Json.canonical(candidate)
   if not expected then rejected="read lease candidate is not storable";return nil end
   j.expiresAt=math.max(j.expiresAt,candidate.lock.beat+Rules.LOCK_STALE);return candidate
  end)
  if not live(self,j) then return true end
  if rejected then j.state,j.problem="lost",rejected;return true end
  if not called or ok~=true then
   j.expiresAt=math.max(j.expiresAt,s.now()+Rules.LOCK_STALE);j.phase="probe";fail(self,j,if called then why else ok);return true
  end
  local good,problem=owned(self,value)
  if not good or expected==nil or Json.canonical(value)~=expected then j.state,j.problem="lost",problem or "read lease acknowledgement differs";return true end
  s.sched:beat(value.lock.beat);j.expiresAt=value.lock.beat+Rules.LOCK_STALE
 end
 j.failures,j.problem,j.nextAt=0,nil,s.now();return true
end
function Lease.step(self:any,j:any):boolean
 local s=self.session
 if self.current~=j or j.state~="pending" or self.busy or s.busy or (j.backend.activeUpdates or 0)>0 or Work.pulse() then return false end
 if not live(self,j) then return false end
 local now=s.now()
 if now<j.nextAt or not s.sched:budgetOk(now) or j.phase=="renew" and now-s.sched.lastBeat<Rules.HEARTBEAT then return false end
 s.sched:begin(nil,now);s.counters.requests+=1;j.requests+=1;self.busy,s.busy=true,true
 local okay,asked
 if self.held then okay,asked=j.backend:run(self.held,function() return request(self,j) end)
 else okay,asked=pcall(request,self,j) end
 self.busy,s.busy=false,false
 if not okay then j.state,j.problem="lost",tostring(asked);return false end
 return asked
end
return table.freeze(Lease)
