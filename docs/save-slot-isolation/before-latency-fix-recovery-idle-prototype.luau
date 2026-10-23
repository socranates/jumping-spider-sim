--!strict
-- Private terminal-held lease maintenance, separate from accepted recovery's
-- total transaction budget. Never resumes ordinary writes or changes payloads.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Json=require(Shared.Persistence.Json)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local SaveRest=require(Shared.Persistence.SaveRest)
local Work=require(Shared.Persistence.SaveWork)
local Scheduler=require(Shared.Persistence.SaveScheduler)
local Stores=require(Shared.Persistence.SaveStores)
local Idle={};Idle.__index=Idle
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function known(v:any,fields:any):boolean
 if type(v)~="table" or getmetatable(v)~=nil then return false end
 for k in v do if not fields[k] then return false end end
 return true
end
local function terminal(j:any):boolean return type(j)=="table" and (j.state=="cancelled" or j.state=="refused") end
local function stop(self:any,state:string,why:string)
 local j=self.current;j.state,j.problem=state,why
 j.result={requiresPausedWorker=true,requiresFreshSession=state=="lost",gameplayAuthorized=false,localProgressRetained=true}
 if self.owner.idleOwner==self then self.owner.idleOwner=nil end
 if state=="lost" then self.owner.leaseLost=true end
end
function Idle.new(owner:any):any return setmetatable({owner=owner,session=owner.session,busy=false},Idle) end
local function identity(self:any,j:any):boolean
 local s=self.session;local t=j.job.ticket
 return self.owner.current==j.job and terminal(j.job) and s.recoveryOwner==self.owner
  and s.backend==j.backend and j.backend:valid(j.job.held) and s._loadSerial==t.load and s.id==t.sessionId
  and tostring(s.cfg.userId)==t.owner and s.pkey==t.pkey and s.sched==t.scheduler
end
function Idle.begin(self:any):(any?,string?)
 local s=self.session;local job=self.owner.current;local now=s.now()
 if Work.pulse() or not finite(now) or self.busy or self.owner.busy or s.busy or s.closed or s.flushing
  or (s.backend.activeUpdates or 0)>0 or self.owner.idleOwner~=nil or self.owner.leaseLost or not terminal(job) then return nil,"terminal-held recovery scope required" end
 local j={job=job,backend=s.backend,state="pending",phase="probe",requests=0,lastNow=now,nextAt=now,failures=0,expiresAt=now+Rules.LOCK_STALE}
 if not identity(self,j) then return nil,"terminal-held recovery identity changed" end
 self.current=j;self.owner.idleOwner=self;return j,nil
end
function Idle.cancel(self:any):boolean
 if not self.current or self.current.state~="pending" or self.busy then return false end
 stop(self,"stopped","terminal-held maintenance superseded");return true
end
local function live(self:any,j:any):boolean
 local s=self.session;local now=s.now()
 if s.closed or s.flushing or self.owner.current~=j.job or not terminal(j.job) or s.recoveryOwner~=self.owner then
  stop(self,"stopped","recovery scope ended");return false
 end
 if not finite(now) or now<j.lastNow or now>=j.expiresAt or not identity(self,j) then
  stop(self,"lost","terminal-held identity or lease observation expired");return false
 end
 j.lastNow=now;return true
end
local function owned(self:any,raw:any):(boolean,string?)
 if SaveRest.bounded(raw,Rules.MAX_PROGRESS_NODES*2+64,Rules.MAX_DEPTH+2)
  or not known(raw,{format=true,kind=true,schema=true,updatedAt=true,payload=true,checksum=true,backup=true,lock=true,session=true})
  or not known(raw.lock,{session=true,beat=true}) then return false,"unsupported held progress/lock" end
 local op=Envelope.open(self.session.pspec,raw,false)
 if op.status~="ok" and op.status~="migrated" then return false,"held progress primary is "..op.status end
 local lock=raw.lock;local now=self.session.now()
 if lock.session~=self.session.id or not finite(lock.beat) or now<lock.beat or now-lock.beat>=Rules.LOCK_STALE then return false,"fresh owned held lease required" end
 return true,nil
end
local function failed(self:any,j:any,why:any)
 j.failures+=1;j.problem=tostring(why);j.nextAt=self.session.now()+Scheduler.backoff(j.failures,Stores.classify(j.problem))
end
local function stepInner(self:any,j:any):boolean
 if not live(self,j) then return false end
 local s=self.session;local now=s.now()
 if s.busy or self.owner.busy or (j.backend.activeUpdates or 0)>0 then return false end
 if now<j.nextAt or not s.sched:budgetOk(now) then return false end
 if j.phase=="renew" and now-s.sched.lastBeat<Rules.HEARTBEAT then return false end
 s.sched:begin(nil,now);s.counters.requests+=1;j.requests+=1
 s.busy,self.owner.busy=true,true
 local ran,asked=j.backend:run(j.job.held,function():boolean
  if j.phase=="probe" then
   local called,ok,value,why=pcall(j.backend.readRawFresh,j.backend,s.pkey)
   if not live(self,j) then return true end
   if not called or ok~=true then failed(self,j,if called then why else ok);return true end
   local good,problem=owned(self,value)
   if not good then stop(self,"lost",problem or "held probe refused");return true end
   s.sched:beat(value.lock.beat);j.expiresAt=value.lock.beat+Rules.LOCK_STALE
   j.phase,j.failures,j.problem,j.nextAt="renew",0,nil,s.now();return true
  end
  local rejection:string?=nil;local expected:string?=nil
  local called,ok,value,why=pcall(j.backend.update,j.backend,s.pkey,function(old:any):any
   rejection,expected=nil,nil
   if not live(self,j) then rejection="held scope changed during renewal";return nil end
   local good,problem=owned(self,old);if not good then rejection=problem;return nil end
   local candidate=Envelope.withLock(old,{session=s.id,beat=s.now()});expected=Json.canonical(candidate)
   return candidate
  end)
  if not live(self,j) then return true end
  if rejection then stop(self,"lost",rejection);return true end
  if not called or ok~=true then
   -- A renewal may have committed despite the failed acknowledgement. Probe
   -- uncached before another update; allow only a bounded uncertainty window.
   j.expiresAt=math.max(j.expiresAt,s.now()+Rules.LOCK_STALE);j.phase="probe"
   failed(self,j,if called then why else ok);return true
  end
  local good,problem=owned(self,value)
  if not good or expected==nil or Json.canonical(value)~=expected then stop(self,"lost",problem or "held renewal acknowledgement differs");return true end
  s.sched:beat(value.lock.beat);j.expiresAt=value.lock.beat+Rules.LOCK_STALE
  j.failures,j.problem,j.nextAt=0,nil,s.now();return true
 end)
 s.busy,self.owner.busy=false,false
 if not ran then stop(self,"lost",tostring(asked));return false end
 return asked
end
function Idle.step(self:any,j:any):boolean
 if self.current~=j or j.state~="pending" or self.busy or Work.pulse() then return false end
 local priorSession,priorOwner=self.session.busy,self.owner.busy
 self.busy=true;local ok,asked=pcall(stepInner,self,j);self.busy=false
 if not ok then
  self.session.busy,self.owner.busy=priorSession,priorOwner;stop(self,"lost",tostring(asked));return false
 end
 return asked
end
return table.freeze(Idle)
