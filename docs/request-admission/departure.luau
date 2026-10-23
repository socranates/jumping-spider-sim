--!strict
-- Private recovery-only departure. Atomically preserve three-way local P
-- changes and release the owned lease; never write rests, archives or M1.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Json=require(Shared.Persistence.Json)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Progress=require(Shared.Persistence.SaveProgress)
local SaveRest=require(Shared.Persistence.SaveRest)
local Work=require(Shared.Persistence.SaveWork)
local Scheduler=require(Shared.Persistence.SaveScheduler)
local Stores=require(Shared.Persistence.SaveStores)
local Reconcile=require(Shared.Persistence.RecoveryProgressReconcilePrototype)
local Packet=require(script.Parent.RecoveryPacketPrototype)
local Operation=require(Shared.Persistence.RecoveryOperationAdmission)
local Departure={};Departure.__index=Departure
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function same(a:any,b:any):boolean
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b and (type(a)~="number" or a~=0 or 1/a==1/b) end
 if getmetatable(b)~=nil then return false end
 for k,v in a do if not same(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
local function freeze(v:any)
 if type(v)~="table" then return end
 for _,x in v do freeze(x) end
 if not table.isfrozen(v) then table.freeze(v) end
end
local function known(v:any,fields:any):boolean
 if type(v)~="table" or getmetatable(v)~=nil then return false end
 for k in v do if not fields[k] then return false end end
 return true
end
function Departure.new(owner:any,options:any?):any
 local cfg=options or {};local requests=cfg.maxRequests or 8;local timeout=cfg.timeout or Rules.FLUSH_DEADLINE
 assert(finite(requests) and requests%1==0 and requests>=1 and requests<=8,"invalid departure request cap")
 assert(finite(timeout) and timeout>0 and timeout<=Rules.FLUSH_DEADLINE,"invalid departure deadline")
 return setmetatable({owner=owner,session=owner.session,maxRequests=requests,timeout=timeout,admission=cfg.admission,busy=false},Departure)
end
function Departure.begin(self:any):(any?,string?)
 if Work.pulse() then return nil,"departure must run outside preparation" end
 local s=self.session;local now=s.now()
 if not finite(now) then return nil,"finite departure clock required" end
 for _,mode in Rules.MODES do
  if s.restPending[mode]~=nil or s.lifeRequests[mode] and not s.lifeRequests[mode].done then return nil,"finish existing rest/life work before recovery departure" end
 end
 local ticket,why=s.backend:sealDeparture(s,self.owner);if not ticket then return nil,why end
 local j={scope=ticket,state="pending",phase="drain",started=now,lastNow=now,deadline=now+self.timeout,requests=0,nextAt=now,failures=0}
 self.current=j;return j,nil
end
local function finish(self:any,j:any,state:string,why:string?,released:boolean?)
 if self.owner.lease then self.owner.lease:cancel() end
 if j.io then j.io:cancel();j.io=nil end;j.writeState=nil
 j.state,j.problem=state,why;j.scope.owner:finishDeparture(j.scope,released==true)
 j.result={progressPreserved=state=="preserved",leaseReleased=released==true,gameplayAuthorized=false,sessionClosed=true}
end
local function live(self:any,j:any):boolean
 local now=self.session.now()
 if self.current~=j or j.state~="pending" or not j.scope.owner:departureValid(j.scope)
  or not finite(now) or now<j.lastNow or now>=j.deadline then return false end
 j.lastNow=now;return true
end
-- A Runtime/service deadline path must call this, rather than writing the
-- job state directly and stranding a queued admission handle.
function Departure.expire(self:any,j:any):boolean
 if self.current~=j or j.state~="pending" then return false end
 local now=self.session.now()
 if finite(now) and now<j.deadline then return false end
 finish(self,j,"refused","departure deadline reached");return true
end
local function ownedRaw(self:any,raw:any):(boolean,string?)
 if SaveRest.bounded(raw,Rules.MAX_PROGRESS_NODES*2+64,Rules.MAX_DEPTH+2)
  or not known(raw,{format=true,kind=true,schema=true,updatedAt=true,payload=true,checksum=true,backup=true,lock=true,session=true})
  or not known(raw.lock,{session=true,beat=true}) then return false,"unsupported departure progress/lock" end
 local now=self.session.now();local lock=raw.lock
 if lock.session~=self.session.id or not finite(lock.beat) or now<lock.beat or now-lock.beat>=Rules.LOCK_STALE then return false,"fresh owned departure lease required" end
 return true,nil
end
local function backoff(self:any,j:any,why:any)
 j.failures+=1;j.nextAt=self.session.now()+Scheduler.backoff(j.failures,Stores.classify(tostring(why)))
 j.problem=tostring(why)
end
local function stepInner(self:any,j:any):boolean
 local s=self.session;local now=s.now()
 if not live(self,j) then finish(self,j,"refused","closed scope changed or departure deadline reached");return false end
 if s.busy or self.owner.busy or (s.backend.activeUpdates or 0)>0 then return false end
 if j.phase=="drain" then
  if self.owner.lease then self.owner.lease:cancel() end
  if self.owner.current and self.owner.current.state=="pending" then self.owner:cancel(self.owner.current) end
  if SaveRest.bounded(s.progress,Rules.MAX_PROGRESS_NODES,Rules.MAX_PROGRESS_DEPTH) or not finite(s.progressTime) then finish(self,j,"refused","final local progress exceeds bounds");return false end
  j.progress=Json.copy(s.progress);freeze(j.progress);j.time=s.progressTime;j.phase="write"
  return false
 end
 if self.admission and not j.io then
  local backend,scope,key=s.backend,j.scope,s.pkey
  local write,read=backend.departureUpdate,backend.departureRead
  j.io=Operation.new(s,self.admission,function() return live(self,j) end,{{object=j,field="requests",max=self.maxRequests}},
   {update={object=backend,fn=function(_backend:any,actual:string,transform:any):...any
     if actual~=key then return false,nil,"departure key differs" end
     return write(backend,scope,transform)
    end},readRawFresh={object=backend,fn=function(_backend:any,actual:string):...any
     if actual~=key then return false,nil,"departure key differs" end
     return read(backend,scope)
    end}})
 end
 if now<j.nextAt then return false end
 if j.requests>=self.maxRequests then finish(self,j,"refused","departure request cap reached");return false end
 -- Like the existing departure flush, this has its own hard cap/deadline and
 -- may exceed the rolling gameplay allowance. Every request is still charged.
 if not j.io then j.requests+=1;s.counters.requests+=1;s.sched:begin(nil,now) end;s.busy=true
 local called,ok,value,why=true,nil,nil,nil
 if j.phase=="write" then
  if not j.writeState then
   local evidence:any={}
   evidence.transform=function(old:any):any
   evidence.rejected=nil;j.expected=nil
   if not live(self,j) then evidence.rejected="departure scope changed during callback";return nil end
   local own,problem=ownedRaw(self,old);if not own then evidence.rejected=problem;return nil end
   local merged,errorText=Reconcile.pending(j.scope.pendingProgress,j.scope.base,j.progress,j.time,old,Packet.MAX_PROGRESS_CHARS)
   if not merged then evidence.rejected=errorText;return nil end
   local result=if merged.dirty then Envelope.make(Progress.SPEC,merged.progress,merged.progressTime,old,{session=old.session}) else Envelope.withLock(old,nil)
   local text=Json.canonical(result)
   if not text or #text>Rules.MAX_VALUE_CHARS then evidence.rejected="departure envelope exceeds storage budget";return nil end
   j.expected=Json.copy(result);freeze(j.expected);return result
   end
   j.writeState=evidence
  end
  local evidence=j.writeState
  if j.io then
   local state,result,asked=j.io:poll("update",s.pkey,evidence.transform);s.busy=false
   if state=="waiting" then return false end
   if state~="done" then finish(self,j,"refused","admitted departure write ended");return asked end
   ok,value,why=table.unpack(result,1,result.n)
  else called,ok,value,why=pcall(s.backend.departureUpdate,s.backend,j.scope,evidence.transform);s.busy=false end
  local rejected=evidence.rejected;j.writeState=nil
  if not live(self,j) then finish(self,j,"refused","departure changed while writing");return true end
  if rejected then finish(self,j,"refused",rejected);return true end
  -- A success return alone is insufficient, and a failed acknowledgement does
  -- not imply a failed commit. Always read uncached before any retry.
  j.lastWriteError=if called and ok==true then nil else tostring(if called then why else ok)
  j.phase="readback";return true
 end
 if j.io then
  local state,result,asked=j.io:poll("readRawFresh",s.pkey,nil);s.busy=false
  if state=="waiting" then return false end
  if state~="done" then finish(self,j,"refused","admitted departure readback ended");return asked end
  ok,value,why=table.unpack(result,1,result.n)
 else called,ok,value,why=pcall(s.backend.departureRead,s.backend,j.scope);s.busy=false end
 if not live(self,j) then finish(self,j,"refused","departure changed while reading");return true end
 if not called or ok~=true then backoff(self,j,if called then why else ok);return true end
 if j.expected~=nil and same(j.expected,value) then finish(self,j,"preserved",nil,true);return true end
 -- No release was verified. Retry only while the latest record still has our
 -- fresh lease; never overwrite an unlocked or newly owned record on a guess.
 local own,problem=ownedRaw(self,value)
 if not own then finish(self,j,"refused",problem or "departure readback differs");return true end
 j.phase="write";backoff(self,j,j.lastWriteError or "departure not observed; retrying owned progress");return true
end
function Departure.step(self:any,j:any):boolean
 if self.current~=j or j.state~="pending" or self.busy or Work.pulse() then return false end
 local priorBusy=self.session.busy
 self.busy=true;local okay,asked=pcall(stepInner,self,j);self.busy=false
 if not okay then self.session.busy=priorBusy;finish(self,j,"refused",tostring(asked));return false end
 return asked
end
return table.freeze(Departure)
