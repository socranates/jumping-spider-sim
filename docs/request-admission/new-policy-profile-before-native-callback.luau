--!strict
-- Explicit protected New, before playable adoption. Complete originals are
-- preserved before replacing only the selected R with an ordinary retired
-- marker. No world adoption, new-life credential or session replacement here.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Json=require(Shared.Persistence.Json)
local SaveRest=require(Shared.Persistence.SaveRest)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Work=require(Shared.Persistence.SaveWork)
local Scheduler=require(Shared.Persistence.SaveScheduler)
local Stores=require(Shared.Persistence.SaveStores)
local Fence=require(Shared.Persistence.RecoverySessionFencePrototype)
local ArchiveController=require(Shared.Persistence.RecoveryControllerPrototype)
local ArchiveStore=require(Shared.Persistence.RecoveryArchiveStorePrototype)
local Reader=require(script.Parent.RecoveryOfferReaderPrototype)
local Lease=require(script.Parent.RecoveryReadLeasePrototype)
local ProgressWriter=require(script.Parent.RecoveryRoutineProgressPrototype)
local Operation=require(Shared.Persistence.RecoveryOperationAdmission)
local Policy={};Policy.__index=Policy
local PARTS={"progress","main","free","easy","index"}
local function finite(v:any):boolean return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function same(a:any,b:any):boolean return Json.canonical(a)==Json.canonical(b) end
local function freeze(v:any)
 if type(v)~="table" then return end
 local pulse=Work.pulse();if pulse then pulse() end
 for _,child in v do freeze(child) end
 table.freeze(v)
end
function Policy.new(runtime:any,options:any?):any
 local cfg=options or {};local s=runtime.session;local source=s.backend.source;local raw=runtime.recovery.rawBackend
 local lane=s.ordinaryAdmission or runtime.recovery.lifecycleAdmission
 if lane then
  cfg=table.clone(cfg)
  assert(cfg.admission==nil or cfg.admission==lane,"New policy must share ordinary account lane")
  cfg.admission=lane
 end
 local requests,seconds=cfg.maxRequests or 96,cfg.timeout or 900
 assert(finite(requests) and requests>=1 and requests<=96 and requests%1==0 and finite(seconds) and seconds>=1 and seconds<=900,"bounded New policy required")
 assert(raw==source or source.ds~=nil and raw.backend and raw.backend.ds==source.ds,"New must use the same physical store")
 return setmetatable({runtime=runtime,session=s,codec=runtime.recovery.codec,raw=raw,context=runtime.recovery.context,
  currentFormat=runtime.recovery.currentFormat,options=cfg,maxRequests=requests,timeout=seconds,busy=false},Policy)
end
local function basicScope(self:any,j:any):boolean
 local rt,s=self.runtime,self.session
 return self.current==j and rt.pipeline==self and s.recoveryOwner==self and rt.newLifePolicy==self and not rt.leaving
  and not s.closed and not s.flushing and s.backend==j.backend and s.backend.source==j.provider and s.backend.source==s.backend.boundSource
  and s.backend.held==j.held and s.backend:valid(j.held) and s.sched==j.scheduler and s.id==j.ticket.sessionId and s._loadSerial==j.ticket.load
  and tostring(s.cfg.userId)==j.ticket.owner and s.pkey==j.ticket.pkey and s.rkey[j.ticket.mode]==j.ticket.rkey
end
local function scope(self:any,j:any):boolean
 if not basicScope(self,j) or not Fence.valid(j.ticket) then return false end
 if self.options.admission then
  local now=self.session.now()
  if not finite(now) or now<j.lastNow or j.state=="pending" and now>=j.deadline then return false end
  j.lastNow=now
 end
 return true
end
local function stop(self:any,j:any,why:any)
 Fence.cancel(j.ticket) -- revoke an already-issued retirement callback too
 for _,name in {"io","rawIO"} do if j[name] then j[name]:cancel();j[name]=nil end end
 j.writeState=nil
 if j.work then j.work:cancel();j.work=nil end
 if j.archive and j.child then j.archive:cancel(j.child) end
 if j.progress and j.progressJob then j.progress:cancel(j.progressJob) end
 if self.lease then self.lease:cancel();self.lease,self.leaseJob=nil,nil end
 j.state,j.problem="refused",tostring(why)
 self.runtime.intakeClosed=false -- only lease maintenance/replacement remains available
 j.result={gameplayAuthorized=false,requiresFreshSession=true,originalPreservationVerified=false}
end
function Policy.begin(self:any,mode:string,serial:number,offerId:string):(any?,string?)
 local rt,s=self.runtime,self.session
 if Work.pulse() or self.current or rt.newLifePolicy or self.busy or rt.busy or s.busy or rt.accepted or rt.leaving or s.closed or s.flushing
  or rt.pipeline.busy or (s.backend.activeUpdates or 0)>0 or rt.reader and rt.reader.busy or rt.lease and rt.lease.busy
  or not rt.route or (rt.phase~="offered" and rt.phase~="offer_refused") then return nil,"observed idle New scope required" end
 local ticket,why=Fence.capture(s,mode,serial,offerId,"new");if not ticket then return nil,why end
 if not ticket.protected then return nil,"ordinary New uses the normal session" end
 local held=s.backend.held
 if held==nil then held,why=s.backend:hold(s,true) end
 if not held or not s.backend:valid(held) then return nil,why or "New baseline unavailable" end
 held.enforced=true
 if rt.lease then rt.lease:cancel() end
 if rt.reader and rt.discovery and rt.discovery.state=="pending" then rt.reader:cancel(rt.discovery) end
 rt.intakeClosed=true;rt.pipeline=self;rt.newLifePolicy=self;s.recoveryOwner=self
 local j={ticket=ticket,held=held,backend=s.backend,provider=s.backend.source,scheduler=s.sched,state="pending",phase="source",
  started=s.now(),startCount=s.counters.requests,nextAt=s.now(),failures=0,requests=0,parts={},part=1}
 j.lastNow=j.started;j.deadline=j.started+self.timeout
 self.current=j;rt.phase="new_retirement"
 self.lease=Lease.new(s,function() return scope(self,j) and (j.state=="pending" or j.state=="verified") end,held,self.options.admission)
 self.leaseJob=assert(self.lease:begin())
 return j,nil
end
function Policy.cancel(self:any,j:any):boolean
 if self.current~=j or j.state~="pending" then return false end
 stop(self,j,"protected New cancelled; current scope remains closed");return true
end
local function reserve(self:any,j:any):boolean
 local s=self.session;local now=s.now()
 if now<j.nextAt or not self.options.admission and not s.sched:budgetOk(now) then return false end
 if s.counters.requests-j.startCount>=self.maxRequests then stop(self,j,"protected New request limit");return false end
 if not self.options.admission then s.sched:begin(nil,now);s.counters.requests+=1 end;return true
end
local function delay(j:any,now:number,why:any)
 j.failures+=1;j.nextAt=now+Scheduler.backoff(j.failures,Stores.classify(tostring(why)));j.problem=tostring(why)
end
local function read(self:any,j:any,key:string):(boolean,any)
 if not reserve(self,j) then return false,nil end
 local s=self.session;s.busy=true
 local called,ok,value,why=true,nil,nil,nil
 if j.io then
  local state,result,asked=j.io:poll("readRawFresh",key,nil);s.busy=false
  if state=="waiting" then return false,nil end
  if state~="done" then stop(self,j,"admitted New read ended");return asked,nil end
  ok,value,why=table.unpack(result,1,result.n)
 else called,ok,value,why=pcall(s.backend.readRawFresh,s.backend,key);s.busy=false end
 if not scope(self,j) then stop(self,j,"New scope changed during read");return true,nil end
 if not called or ok~=true then delay(j,s.now(),if called then why else ok);return true,nil end
 j.failures,j.nextAt,j.problem=0,s.now(),nil;return true,{value=value}
end
local function prepareSource(self:any,j:any)
 j.work=Work.new(function()
  local result,why=Reader.prepare(j.ticket.owner,j.ticket.mode,j.raw,j.anchor,j.parts,self.codec,self.context,j.ticket.identity.kind,self.currentFormat,true)
  if not result then return nil,why end
  local id=result.identity;local chosen=j.ticket.identity
  if id.kind~=chosen.kind or id.checksum~=chosen.checksum or id.updatedAt~=chosen.updatedAt or id.life~=chosen.life then return nil,"displayed New observation changed" end
  return result,nil
 end,self.options.work);j.phase="prepareSource"
end
local function prepareMarker(self:any,j:any)
 j.work=Work.new(function()
  local payload={save_retired=true,save_life=self.session.id..":"..j.ticket.mode..":"..tostring(j.ticket.serial)}
  local logical=Envelope.make(SaveRest.SPECS[j.ticket.mode],payload,math.max(j.started,self.session.now()),nil,{session=self.session.id})
  local raw=self.codec:encode(logical);freeze(raw);freeze(logical)
  return {raw=raw,logical=logical},nil
 end,self.options.work);j.phase="prepareMarker"
end
local function stepInner(self:any,j:any):boolean
 local s=self.session;local now=s.now()
 j.requests=s.counters.requests-j.startCount
 if j.state=="refused" then
  if self.leaseLost or not basicScope(self,j) then self.leaseLost=true;return false end
  if not self.lease then
   self.lease=Lease.new(s,function() return j.state=="refused" and basicScope(self,j) end,j.held,self.options.admission)
   local leaseJob,why=self.lease:begin()
   if not leaseJob then self.leaseLost=true;j.problem=why;return false end
   self.leaseJob=leaseJob
  end
  local asked=self.lease:step(self.leaseJob)
  if self.leaseJob.state=="lost" or self.leaseJob.state=="stopped" then self.leaseLost=true end
  return asked
 end
 if not scope(self,j) then stop(self,j,"protected New selection/session changed");return false end
 if j.state=="pending" and (not finite(now) or now-j.started>=self.timeout or s.counters.requests-j.startCount>=self.maxRequests) then stop(self,j,"protected New total bound");return false end
 if self.options.admission and j.state=="pending" and not j.io then
  local rows={{object=j,field="requests",max=self.maxRequests}}
  local guard=function() return j.state=="pending" and scope(self,j) end
  j.io=Operation.new(s,self.options.admission,guard,rows)
  j.rawIO=Operation.new(s,self.options.admission,guard,rows,{update={object=self.raw,fn=self.raw.updateRaw}})
 end
 if j.phase~="archive" and j.phase~="progressStart" and j.phase~="progress" then
  if not self.lease then
   self.lease=Lease.new(s,function() return scope(self,j) and (j.state=="pending" or j.state=="verified") end,j.held,self.options.admission)
   self.leaseJob=assert(self.lease:begin())
  end
  local asked=self.lease:step(self.leaseJob)
  if self.leaseJob.state=="lost" or self.leaseJob.state=="stopped" then self.leaseLost=true;stop(self,j,self.leaseJob.problem or "New lease unavailable");return asked end
  if asked or j.state=="verified" then return asked end
 end
 if j.work then
  j.work:step();if not scope(self,j) then stop(self,j,"New preparation scope changed");return false end
  if j.work.state=="pending" then return false end
  local values=j.work:take();j.work=nil
  if not values or not values[1] then stop(self,j,values and values[2] or "New preparation failed");return false end
  if j.phase=="prepareMarker" then j.marker=values[1];j.phase="write";return false end
  if j.phase=="proofWork" then prepareMarker(self,j);return false end
  j.source=values[1]
  self.lease:cancel();self.lease,self.leaseJob=nil,nil -- child archive/progress owns the same scheduler's lease
  if j.source.continued then
   j.original=j.source.entryArchive;j.phase="progressStart"
  else
   j.archive=ArchiveController.new(s,{intentKind="new",restCodec=self.codec,reuseCompleteOriginal=true,work=self.options.work,admission=self.options.admission})
   local child,why=j.archive:begin(j.ticket.mode,j.ticket.serial,j.ticket.offerId,"new-"..Json.checksum(s.id..j.ticket.offerId..tostring(j.ticket.serial)))
   if not child then stop(self,j,why);return false end
   j.child,j.phase=child,"archive"
  end
  return false
 end
 if j.phase=="source" then
  local did,row=read(self,j,s.rkey[j.ticket.mode]);if row then j.raw=row.value;j.phase="anchor" end;return did
 elseif j.phase=="anchor" then
  local did,row=read(self,j,"M1_"..j.ticket.owner.."_"..j.ticket.mode)
  if row then j.anchor=row.value;if j.anchor==nil then prepareSource(self,j) else j.phase="parts" end end;return did
 elseif j.phase=="parts" then
  local part=PARTS[j.part];local did,row=read(self,j,"A1_"..j.ticket.owner.."_"..part)
  if row then j.parts[part]=row.value;j.part+=1;if j.part>#PARTS then prepareSource(self,j) end end;return did
 elseif j.phase=="archive" then
  local did=j.archive:step(j.child)
  if not scope(self,j) then stop(self,j,"New archive selection changed");return did end
  if j.child.state=="ready" then
   j.original=j.child.plan
   if not same(j.original.entries[j.ticket.mode].raw,j.raw) then stop(self,j,"complete original differs from selected source") else j.phase="progressStart" end
  elseif j.child.state~="pending" then stop(self,j,j.child.problem or "New archive refused") end
  return did
 elseif j.phase=="progressStart" then
  j.progress=ProgressWriter.new(s,{work=self.options.work,admission=self.options.admission});local child,why=j.progress:begin()
  if not child then stop(self,j,why) else j.progressJob,j.phase=child,"progress" end;return false
 elseif j.phase=="progress" then
  local did=j.progress:step(j.progressJob)
  if not scope(self,j) then stop(self,j,"New progress scope changed");return did end
  if j.progressJob.state=="verified" then
   if s.sched:isDirty("progress") then j.phase="progressStart" else j.proofParts={};j.proofPart=1;j.phase="proofArchive" end
  elseif j.progressJob.state~="pending" then stop(self,j,j.progressJob.problem or "New progress refused") end
  return did
 elseif j.phase=="proofArchive" then
  local part=PARTS[j.proofPart];local did,row=read(self,j,"A1_"..j.ticket.owner.."_"..part)
  if row then j.proofParts[part]=row.value;j.proofPart+=1;if j.proofPart>#PARTS then j.phase="proofAnchor" end end;return did
 elseif j.phase=="proofAnchor" then
  local did,row=read(self,j,"M1_"..j.ticket.owner.."_"..j.ticket.mode)
  if row then
   j.work=Work.new(function()
    local plan,why=ArchiveStore.checkPublished(j.ticket.owner,j.proofParts)
    if not plan then return nil,why end
    if not same(plan.index,j.original.index) or not same(plan.entries,j.original.entries) or not same(row.value,j.anchor) then return nil,"immutable original/proposal changed before retirement" end
    return true,nil
   end,self.options.work);j.phase="proofWork"
  end
  return did
 elseif j.phase=="write" then
  if not reserve(self,j) then return false end
  if not j.writeState then
   local evidence:any={}
   evidence.transform=function(old:any):any
   evidence.rejected=nil
   if not scope(self,j) or not s.backend:permitted(j.held) then evidence.rejected="New write scope ended";return nil end
   if same(old,j.marker.raw) then return old end
   if not same(old,j.raw) then evidence.rejected="selected rest changed before retirement";return nil end
   return j.marker.raw
   end
   j.writeState=evidence
  end
  local evidence=j.writeState
  local called,ok,_value,why=true,nil,nil,nil;s.busy=true
  if j.rawIO then
   local state,result,asked=j.rawIO:poll("update",s.rkey[j.ticket.mode],evidence.transform);s.busy=false
   if state=="waiting" then return false end
   if state~="done" then stop(self,j,"admitted New retirement ended");return asked end
   ok,_value,why=table.unpack(result,1,result.n)
  else called,ok,_value,why=pcall(self.raw.updateRaw,self.raw,s.rkey[j.ticket.mode],evidence.transform);s.busy=false end
  local rejected=evidence.rejected;j.writeState=nil
  if not scope(self,j) then stop(self,j,"New scope ended during retirement");return true end
  if rejected then stop(self,j,rejected);return true end
  j.lastWriteError=if called and ok==true then nil else tostring(if called then why else ok)
  j.phase="readback";return true
 elseif j.phase=="readback" then
  local did,row=read(self,j,s.rkey[j.ticket.mode]);if not row then return did end
  if same(row.value,j.marker.raw) then
   j.state,j.problem="verified",nil
   for _,name in {"io","rawIO"} do if j[name] then j[name]:cancel();j[name]=nil end end
   self.runtime.intakeClosed=false -- replacement may preserve final progress; this worker never resumes ordinary save work
   j.result={retired=true,rawRest=j.marker.raw,marker=j.marker.logical,originalArchive=j.original,
    requiresFreshSession=true,gameplayAuthorized=false,progressPreserved=true}
   return did
  end
  if not same(row.value,j.raw) then stop(self,j,"retirement readback changed");return did end
  j.phase="write";delay(j,s.now(),j.lastWriteError or "retirement not observed");return did
 end
 stop(self,j,"unknown protected New phase");return false
end
function Policy.step(self:any,j:any):boolean
 local s=self.session
 if self.current~=j or (j.state~="pending" and j.state~="verified" and j.state~="refused") or self.busy or s.busy or Work.pulse() then return false end
 self.busy=true;local okay,asked=s.backend:run(j.held,function() return stepInner(self,j) end);self.busy=false
 if not okay then s.busy=false;stop(self,j,asked);return false end
 j.requests=s.counters.requests-j.startCount
 return asked
end
return table.freeze(Policy)
