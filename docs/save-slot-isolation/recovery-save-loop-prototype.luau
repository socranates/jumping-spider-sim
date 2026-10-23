--!strict
-- Private single scheduler for recovered progress/rest/lease ownership.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Work=require(Shared.Persistence.SaveWork)
local SaveRest=require(Shared.Persistence.SaveRest)
local ProgressWriter=require(script.Parent.RecoveryRoutineProgressPrototype)
local RestWriter=require(script.Parent.RecoveryCurrentWriterPrototype)
local Lease=require(script.Parent.RecoveryReadLeasePrototype)
local Loop={};Loop.__index=Loop
function Loop.new(runtime:any):any
 local s=runtime.session;local r=runtime.entryJob.request
 local self:any=setmetatable({runtime=runtime,session=s,request=r,mode=r.mode,serial=r.serial,credential=r.credential,life=r.life,revision=r.revision,
  backend=s.backend,source=s.backend.source,held=s.backend.held,id=s.id,user=tostring(s.cfg.userId),key=s.pkey,rkey=s.rkey[r.mode],load=s._loadSerial,scheduler=s.sched,intents=s.intents,owner=s.recoveryOwner,
  rawRest=runtime.result.rawRest,archive=runtime.result.archive,anchor=runtime.result.anchor,state="active",busy=false,restNextAt=0,
  progressStoredVersion=if s.sched:isDirty("progress") then -1 else s.sched.items.progress.version,options=runtime.recovery.saveOptions or {}},Loop)
 self.progress=ProgressWriter.new(s,self.options.progress)
 self.writer=RestWriter.new(s,runtime.recovery.rawBackend,runtime.recovery.codec,runtime.recovery.context,self.options.rest)
 return self
end
local function scope(self:any):boolean
 local rt=self.runtime;local s=self.session
 return self.state=="active" and rt.saveLoop==self and rt.phase=="recovered" and not rt.leaving and not s.closed and not s.flushing and s.state=="active" and s.lockHeld
  and s.backend==self.backend and s.backend.source==self.source and s.backend.source==s.backend.boundSource and s.backend.boundSession==s
  and s.backend.held==self.held and self.held.enforced and s.backend:valid(self.held) and s.recoveryOwner==self.owner
  and s.id==self.id and s._loadSerial==self.load and s.pkey==self.key and s.rkey[self.mode]==self.rkey and tostring(s.cfg.userId)==self.user
  and s.sched==self.scheduler and s.intents==self.intents and s.intents.requests[self.mode]==self.request and self.request.revision==self.revision
  and s.intents:authorized(self.mode,self.serial,self.credential,self.life)
end
local function stopLease(self:any)
 if self.lease then self.lease:cancel() end;self.lease,self.leaseJob=nil,nil
end
local function lease(self:any):boolean
 if self.lease then return true end
 self.lease=Lease.new(self.session,function() return scope(self) and self.progressJob==nil and self.restJob==nil end,self.held)
 local j,why=self.lease:begin();self.leaseJob=j
 if not j then self.state,self.problem="lost",why;return false end
 return true
end
function Loop.cancel(self:any)
 if self.work then self.work:cancel();self.work=nil end
 if self.progressJob then self.progress:cancel(self.progressJob) end
 if self.restJob then self.writer:cancel(self.restJob) end
 self.pending,self.plan=nil,nil;stopLease(self);self.state="stopped"
end
function Loop.submit(self:any,mode:any,serial:any,credential:any,life:any,restSerial:any,record:any):boolean
 if Work.pulse() or self.busy or self.session.busy or not scope(self) or self.runtime.intakeClosed or self.pending or self.restJob
  or mode~=self.mode or serial~=self.serial or credential~=self.credential or life~=self.life
  or type(record)~="table" or SaveRest.bounded(record,Rules.MAX_REST_NODES,Rules.MAX_DEPTH) then return false end
 local handle=self.writer:capture(mode,serial,credential,life,restSerial);if not handle then return false end
 -- The message is transferred to this worker, as in the existing client queue;
 -- the server receiver must not retain/mutate the graph during preparation.
 self.pending={restSerial=restSerial,progressVersion=self.session.sched.items.progress.version}
 self.work=Work.new(function() return self.writer:prepare(handle,self.archive,self.anchor,self.rawRest,record) end,self.options.work)
 return true
end
function Loop.hasWork(self:any):boolean
 return self.pending~=nil or self.progressJob~=nil or self.restJob~=nil or self.session.sched:isDirty("progress")
end
local function lost(self:any,why:any)
 self:cancel();self.state,self.problem="lost",tostring(why)
end
local function refusePending(self:any,why:any)
 local pending=self.pending;self.pending,self.plan,self.work=nil,nil,nil;self.lastRefusal=tostring(why)
 if pending and self.session.cfg.onRefused then pcall(self.session.cfg.onRefused,self.mode,self.serial,self.credential,pending.restSerial,self.lastRefusal) end
end
local function stepInner(self:any):boolean
 local s=self.session
 if not scope(self) then lost(self,"recovered save scope changed");return false end
 if self.progressJob then
  local j=self.progressJob;local asked=self.progress:step(j)
  if not scope(self) then return asked end
  if j.state=="verified" then
   self.progressStoredVersion=math.max(self.progressStoredVersion,j.version)
   self.progressJob=nil;self.progress.current=nil;self.progress.lease,self.progress.leaseJob=nil,nil
  elseif j.state~="pending" then lost(self,j.problem or "recovered progress refused") end
  return asked
 end
 if self.restJob then
  local j=self.restJob;local asked=self.writer:step(j)
  if not scope(self) then return asked end
  if j.state=="verified" then
   local p=j.plan;local current=p.logical.payload
   self.rawRest=p.candidate;self.runtime.result.rawRest=p.candidate;self.runtime.result.current=current
   self.runtime.result.checkpoint=current.checkpoint;self.runtime.result.entryKind=current.entryKind
   s.rests[self.mode]=current.checkpoint;s.restLoaded[self.mode]=true;s.restBase[self.mode]=p.logical.updatedAt;s.restRevision[self.mode]=p.logical.checksum
   self.restNextAt=s.now()+Rules.REST_MIN_INTERVAL;self.restJob,self.pending,self.plan=nil,nil,nil;self.writer.current=nil
  elseif j.state~="pending" then lost(self,j.problem or "recovered rest refused") end
  return asked
 end
 if not lease(self) then return false end
 local asked=self.lease:step(self.leaseJob)
 if self.leaseJob.state=="lost" or self.leaseJob.state=="stopped" then lost(self,self.leaseJob.problem or "recovered idle lease lost");return asked end
 if asked then return true end
 if self.work then
  self.work:step()
  if not scope(self) then lost(self,"recovered preparation scope changed");return false end
  if self.work.state=="pending" then return false end
  local result=self.work:take();self.work=nil
  if not result or not result[1] then refusePending(self,if result then result[2] else "recovered rest preparation failed");return false end
  self.plan=result[1];return false
 end
 -- A checkpoint depends on its captured progress, not every subsequent eye-view
 -- tick. Later unrelated updates must not starve a ready bounded rest write.
 if self.pending and self.plan and self.progressStoredVersion>=self.pending.progressVersion and s.now()>=self.restNextAt then
  stopLease(self);local j,why=self.writer:begin(self.plan)
  if not j then lost(self,why or "recovered rest admission failed");return false end
  self.restJob=j;return false
 end
 if s.sched:isDirty("progress") then
  if not s.sched:due("progress",s.now()) then return false end
  stopLease(self);local j,why=self.progress:begin()
  if not j then lost(self,why or "recovered progress admission failed");return false end
  self.progressJob=j;return false
 end
 return false
end
function Loop.step(self:any):boolean
 if self.busy or self.session.busy or Work.pulse() then return false end
 self.busy=true;local ok,asked=pcall(stepInner,self);self.busy=false
 if not ok then lost(self,asked);return false end;return asked
end
return table.freeze(Loop)
