--!strict
-- Private recovered progress worker. Never invokes the ordinary whole-snapshot
-- worker or releases its enforced hold; failed jobs retain departure provenance.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local SaveRest=require(Shared.Persistence.SaveRest)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Progress=require(Shared.Persistence.SaveProgress)
local Reconcile=require(Shared.Persistence.RecoveryProgressReconcilePrototype)
local Packet=require(script.Parent.RecoveryPacketPrototype)
local Lease=require(script.Parent.RecoveryReadLeasePrototype)
local Scheduler=require(Shared.Persistence.SaveScheduler)
local Stores=require(Shared.Persistence.SaveStores)
local Operation=require(Shared.Persistence.RecoveryOperationAdmission)
local Writer={};Writer.__index=Writer
local function finite(v:any):boolean return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function known(v:any,fields:any):boolean
 if type(v)~="table" or getmetatable(v)~=nil then return false end
 for k in v do if not fields[k] then return false end end;return true
end
local function freeze(v:any)
 if type(v)~="table" then return end
 local pulse=Work.pulse();if pulse then pulse() end
 for _,x in v do freeze(x) end
 if not table.isfrozen(v) then table.freeze(v) end
end
local function body(a:any):string? return if type(a)=="table" then Json.canonical(Envelope.withLock(a,nil)) else nil end
function Writer.new(session:any,options:any?):any
 local cfg=options or {};assert(session.backend.boundSession==session,"factory-bound session required")
 return setmetatable({session=session,options=cfg,busy=false},Writer)
end
local function scope(self:any,j:any):boolean
 local s=self.session
 return not s.closed and not s.flushing and s.state=="active" and s.lockHeld and s.backend==j.backend and s.backend.source==j.source and s.backend.source==s.backend.boundSource
  and s.backend.boundSession==s and s.backend:progressValid(j.reservation) and s.recoveryOwner==j.owner and s.sched==j.scheduler
  and s._loadSerial==j.load and s.id==j.id and s.pkey==j.key and tostring(s.cfg.userId)==j.user
end
function Writer.begin(self:any):(any?,string?)
 local s=self.session;local now=s.now()
 if Work.pulse() or self.busy or s.busy or s.closed or s.flushing or self.current and self.current.state=="pending" or (s.backend.activeUpdates or 0)>0
  or not finite(now) or now<s.sched.lastBeat or now-s.sched.lastBeat>=Rules.LOCK_STALE then return nil,"routine progress unavailable" end
 if SaveRest.bounded(s.progress,Rules.MAX_PROGRESS_NODES,Rules.MAX_PROGRESS_DEPTH) then return nil,"routine progress exceeds bound" end
 local snap=Envelope.make(Progress.SPEC,Json.copy(s.progress),s.progressTime,nil);freeze(snap)
 local t,why=s.backend:reserveProgress(s.backend.held,snap);if not t then return nil,why end
 local j={state="pending",phase="write",reservation=t,backend=s.backend,source=s.backend.source,owner=s.recoveryOwner,scheduler=s.sched,load=s._loadSerial,id=s.id,key=s.pkey,user=tostring(s.cfg.userId),
  version=s.sched.items.progress.version,started=now,lastNow=now,deadline=now+180,startCount=s.counters.requests,nextAt=now,failures=0,requests=0}
 self.current=j
 local lease=Lease.new(s,function() return self.current==j and j.state=="pending" and scope(self,j) end,t.held,self.options.admission)
 j.lease=lease;self.lease=lease;self.leaseJob=assert(lease:begin());return j,nil
end
local function live(self:any,j:any):boolean
 local now=self.session.now()
 if self.current~=j or j.state~="pending" or not scope(self,j) or not finite(now) or now<j.lastNow or now>=j.deadline then return false end
 j.lastNow=now;return true
end
local function fail(j:any,why:string)
 if j.lease then j.lease:cancel() end
 if j.io then j.io:cancel();j.io=nil end;j.writeState=nil
 if j.work then j.work:cancel();j.work=nil end
 j.state,j.problem="refused",why;j.expected,j.confirmed,j.adoption=nil,nil,nil
end
function Writer.cancel(self:any,j:any):boolean
 if self.current~=j or j.state~="pending" then return false end
 fail(j,"routine progress cancelled");if self.lease then self.lease:cancel() end;return true
end
local function owned(self:any,j:any,raw:any):(boolean,string?)
 if SaveRest.bounded(raw,Rules.MAX_PROGRESS_NODES*2+64,Rules.MAX_DEPTH+2)
  or not known(raw,{format=true,kind=true,schema=true,updatedAt=true,payload=true,checksum=true,backup=true,lock=true,session=true})
  or not known(raw.lock,{session=true,beat=true}) then return false,"unsupported routine progress" end
 local now=self.session.now();local lock=raw.lock
 if lock.session~=j.id or not finite(lock.beat) or now<lock.beat or now-lock.beat>=Rules.LOCK_STALE then return false,"fresh routine ownership required" end
 local op=Envelope.open(Progress.SPEC,raw,false)
 if op.status~="ok" and op.status~="migrated" then return false,"unsupported routine primary" end
 return true,nil
end
local function stepInner(self:any,j:any):boolean
 local s=self.session
 if not live(self,j) then fail(j,"routine progress scope/deadline changed");return false end
 j.requests=s.counters.requests-j.startCount;if j.requests>=16 then fail(j,"routine progress request cap reached");return false end
 if self.options.admission and not j.io then
  j.io=Operation.new(s,self.options.admission,function() return live(self,j) end,{{object=j,field="requests",max=16}})
 end
 local asked=self.lease:step(self.leaseJob)
 j.requests=s.counters.requests-j.startCount
 if self.leaseJob.state=="lost" or self.leaseJob.state=="stopped" then fail(j,self.leaseJob.problem or "routine lease lost");return asked end
 if asked then return true end
 if j.phase=="adopt" then
  if not j.work then
   j.localRef,j.localTime,j.localVersion=s.progress,s.progressTime,s.sched.items.progress.version
   local localCopy=Json.copy(s.progress)
   j.work=Work.new(function()
    local merged,why=Reconcile.prepare(j.reservation.snapshot,localCopy,j.localTime,j.confirmed,Packet.MAX_PROGRESS_CHARS)
    if not merged then return nil,why end
    freeze(merged);return merged,nil
   end,self.options.work)
  end
  j.work:step()
  if not live(self,j) then fail(j,"routine changed during adoption");return false end
  if j.work.state=="pending" then return false end
  local result=j.work:take();j.work=nil
  if not result or not result[1] then fail(j,if result then tostring(result[2]) else "routine adoption failed");return false end
  if s.progress~=j.localRef or s.progressTime~=j.localTime or s.sched.items.progress.version~=j.localVersion then return false end
  local merged=result[1]
  if not s.backend:advanceProgress(j.reservation,j.confirmed) then fail(j,"routine baseline changed");return false end
  -- No callback/yield in the baseline/local/scheduler adoption boundary.
  s.progress=merged.progress;s.progressTime=merged.progressTime;s.storedTime=j.confirmed.updatedAt
  s.sched:succeeded("progress",s.now(),if merged.dirty then j.version else j.localVersion)
  j.state,j.problem="verified",nil;j.result={progressPreserved=true,localChangesPending=merged.dirty}
  j.expected,j.confirmed,j.localRef=nil,nil,nil;self.lease:cancel();if j.io then j.io:cancel();j.io=nil end;return false
 end
 local now=s.now();if now<j.nextAt or not j.io and not s.sched:budgetOk(now) then return false end
 if not j.io then s.sched:begin(nil,now);s.counters.requests+=1 end
 if j.phase=="write" then
  if not j.writeState then
   local evidence:any={}
   evidence.transform=function(old:any):any
   j.expected=nil;evidence.rejected=nil
   if not live(self,j) then evidence.rejected="routine callback changed";return nil end
   local own,problem=owned(self,j,old);if not own then evidence.rejected=problem;return nil end
   local t=j.reservation
   local merged,errorText=Reconcile.prepare(t.base,t.snapshot.payload,t.snapshot.updatedAt,old,Packet.MAX_PROGRESS_CHARS)
   if not merged then evidence.rejected=errorText;return nil end
   local candidate=if merged.dirty then Envelope.make(Progress.SPEC,merged.progress,merged.progressTime,old,{session=s.id,lock={session=s.id,beat=s.now()}})
    else Envelope.withLock(old,{session=s.id,beat=s.now()})
   local text=Json.canonical(candidate);if not text or #text>Rules.MAX_VALUE_CHARS then evidence.rejected="routine envelope exceeds bound";return nil end
   j.expected=Json.copy(candidate);freeze(j.expected)
   self.leaseJob.expiresAt=math.max(self.leaseJob.expiresAt,candidate.lock.beat+Rules.LOCK_STALE)
   return candidate
   end
   j.writeState=evidence
  end
  local evidence=j.writeState
  local called,ok,value,why=true,nil,nil,nil
  s.busy=true
  if j.io then
   local state,result,started=j.io:poll("update",j.key,evidence.transform)
   s.busy=false
   if state=="waiting" then return false end
   if state~="done" then fail(j,"routine admitted write ended");return started end
   ok,value,why=table.unpack(result,1,result.n)
  else called,ok,value,why=pcall(s.backend.update,s.backend,j.key,evidence.transform);s.busy=false end
  local rejected=evidence.rejected;j.writeState=nil
  if not live(self,j) then fail(j,"routine changed during write");return true end
  if rejected then fail(j,rejected);return true end
  if called and ok==true and j.expected and body(value)==body(j.expected) then
   local own=owned(self,j,value)
   if own then s.sched:beat(value.lock.beat);self.leaseJob.expiresAt=value.lock.beat+Rules.LOCK_STALE end
  end
  j.lastError=if called and ok==true then nil else tostring(if called then why else ok)
  j.phase="readback";return true
 end
 local called,ok,value,why=true,nil,nil,nil
 s.busy=true
 if j.io then
  local state,result,started=j.io:poll("readRawFresh",j.key,nil);s.busy=false
  if state=="waiting" then return false end
  if state~="done" then fail(j,"routine admitted readback ended");return started end
  ok,value,why=table.unpack(result,1,result.n)
 else called,ok,value,why=pcall(s.backend.readRawFresh,s.backend,j.key);s.busy=false end
 if not live(self,j) then fail(j,"routine changed during readback");return true end
 if not called or ok~=true then
  j.failures+=1;j.nextAt=s.now()+Scheduler.backoff(j.failures,Stores.classify(tostring(if called then why else ok)));return true
 end
 local own,problem=owned(self,j,value);if not own then fail(j,problem or "routine readback lost ownership");return true end
 if j.expected and body(value)==body(j.expected) then
  s.sched:beat(value.lock.beat);self.leaseJob.expiresAt=value.lock.beat+Rules.LOCK_STALE
  j.confirmed=Json.copy(value);freeze(j.confirmed);j.phase="adopt";return true
 end
 j.failures+=1;j.nextAt=s.now()+Scheduler.backoff(j.failures,Stores.classify(j.lastError or "routine write not observed"));j.phase="write";return true
end
function Writer.step(self:any,j:any):boolean
 local s=self.session
 if self.current~=j or j.state~="pending" or self.busy or s.busy or Work.pulse() or (s.backend.activeUpdates or 0)>0 then return false end
 self.busy=true
 -- Lease.step owns its own busy scope. The remaining callback scope still sets
 -- s.busy across native yields, so departure drains providers before its write.
 local ok,asked=s.backend:run(j.reservation.held,function() return stepInner(self,j) end)
 self.busy=false;if not ok then s.busy=false;fail(j,tostring(asked));return false end
 if j.state~="pending" and self.lease then self.lease:cancel() end
 return asked
end
return table.freeze(Writer)
