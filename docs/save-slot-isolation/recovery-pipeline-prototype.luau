--!strict
-- Private accepted-intent owner: archive -> commit -> fresh witnesses -> local
-- progress adoption. Discovery/user deliberation precedes this bounded scope.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Scheduler=require(Shared.Persistence.SaveScheduler)
local Stores=require(Shared.Persistence.SaveStores)
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local Fence=require(Shared.Persistence.RecoverySessionFencePrototype)
local ArchiveController=require(Shared.Persistence.RecoveryControllerPrototype)
local Commit=require(script.Parent.RecoveryCommitControllerPrototype)
local Rebind=require(script.Parent.RecoverySessionRebindPrototype)
local Packet=require(script.Parent.RecoveryPacketPrototype)
local SaveRest=require(Shared.Persistence.SaveRest)
local Pipeline={};Pipeline.__index=Pipeline
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function same(a:any,b:any):boolean
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b and (type(a)~="number" or a~=0 or 1/a==1/b) end
 if getmetatable(b)~=nil then return false end
 for k,v in a do if not same(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
local function clean(j:any)
 if j.work then j.work:cancel() end
 if j.component and j.child then j.component:cancel(j.child) end
 if j.rebind then Fence.cancel(j.rebind.fence) end
 j.work,j.component,j.child,j.rebind,j.plan,j.anchor,j.rawP,j.rawR=nil,nil,nil,nil,nil,nil,nil,nil
end
local function stop(j:any,state:string,why:string)
 j.state,j.problem=state,why;Fence.cancel(j.ticket);clean(j)
 -- Preserve the enforced hold on failure. Silently resuming stale P writes
 -- would undo the safety of the storage transaction. Departure remains separate.
 j.result={requiresPausedWorker=true,gameplayAuthorized=false}
end
local function owned(self:any,fn:any):...any
 local s=self.session;s.busy=true;local result=table.pack(pcall(fn));s.busy=false
 if not result[1] then error(result[2],0) end
 return table.unpack(result,2,result.n)
end
function Pipeline.new(session:any,codec:any,rawBackend:any,template:any,context:any,options:any?):any
 local cfg=options or {};local requests=cfg.maxRequests or 96;local timeout=cfg.timeout or 900
 assert(type(session.backend.hold)=="function" and type(session.backend.run)=="function" and type(session.backend.permitted)=="function","tracked session backend required")
 assert(type(rawBackend.updateRaw)=="function" and type(rawBackend.readRawFresh)=="function","explicit raw adapter required")
 assert(finite(requests) and requests>=1 and requests<=96 and requests%1==0 and finite(timeout) and timeout>=1 and timeout<=900,"invalid total recovery bounds")
 local self:any=setmetatable({session=session,codec=codec,template=template,context=context,options=cfg,maxRequests=requests,timeout=timeout,busy=false},Pipeline)
 self.raw={readRawFresh=function(_adapter:any,key:string):(boolean,any,string?) return rawBackend:readRawFresh(key) end,
  updateRaw=function(_adapter:any,key:string,fn:any):(boolean,any,string?)
   local j=self.current
   if not j or not j.guard() or key~=j.ticket.rkey or not session.backend:permitted(j.held) then return false,nil,"raw write requires selected recovery owner" end
   return rawBackend:updateRaw(key,fn)
  end}
 return self
end
local function launch(self:any,j:any,phase:string,archive:any?):boolean
 local s=self.session;j.requests=s.counters.requests-j.startCount
 local left=self.maxRequests-j.requests;local seconds=self.timeout-(s.now()-j.started)
 if left<1 or seconds<1 then stop(j,"refused","total recovery bound reached");return false end
 if phase=="archive" then
  j.component=ArchiveController.new(s,{restCodec=self.codec,maxRequests=math.min(96,left),timeout=seconds,work=self.options.work})
  j.child=select(1,j.component:begin(j.ticket.mode,j.ticket.serial,j.ticket.offerId,"owner-"..Json.checksum(s.id..j.ticket.mode..tostring(j.ticket.serial)..j.ticket.offerId)))
 else
  j.component=Commit.new(s,self.codec,self.raw,self.template,self.context,{maxRequests=math.min(64,left),timeout=seconds,work=self.options.work})
  j.child=select(1,j.component:begin(j.ticket.mode,j.ticket.serial,j.ticket.offerId,archive))
 end
 if not j.child then stop(j,"refused","recovery stage admission refused");return false end
 j.phase=phase;return true
end
function Pipeline.begin(self:any,mode:string,serial:number,offerId:string,discovery:any):(any?,string?)
 local s=self.session
 if self.busy or s.busy or s.flushing or (s.backend.activeUpdates or 0)>0 or self.current and self.current.state=="pending" or s.recoveryOwner and s.recoveryOwner~=self then return nil,"another recovery owner is active" end
 if type(discovery)~="table" or discovery.state~="offered" or discovery.mode~=mode or discovery.sessionId~=s.id or discovery.load~=s._loadSerial
  or type(discovery.offer)~="table" or discovery.offer.id~=offerId then return nil,"current protected discovery required" end
 for _,slot in Rules.MODES do
  if s.restPending[slot]~=nil or s.lifeRequests[slot] and not s.lifeRequests[slot].done then return nil,"finish existing rest/life work before recovery" end
 end
 local ticket,why=Fence.capture(s,mode,serial,offerId);if not ticket then return nil,why end
 local held=s.backend.held
 if held~=nil and (not s.backend:valid(held) or held.session~=s) then Fence.cancel(ticket);return nil,"held baseline no longer belongs to this session" end
 if held==nil then held,why=s.backend:hold(s,true) end
 if not held then Fence.cancel(ticket);return nil,why end
 held.enforced=true
 local j:any={ticket=ticket,held=held,state="pending",started=s.now(),startCount=s.counters.requests,requests=0,nextAt=s.now(),nextBeatAttempt=s.now(),failures=0,beatFailures=0}
 self.current=j;s.recoveryOwner=self
 j.guard=function() return self.current==j and j.state=="pending" and s.recoveryOwner==self and not s.flushing and s.backend:valid(held) and Fence.valid(ticket) end
 -- Discovery is a protected observation, not current storage truth. A new M1
 -- probe chooses cold/resume even if that observation predates an interruption.
 j.phase="admitRead"
 return j,nil
end
function Pipeline.cancel(self:any,j:any):boolean
 if self.current~=j or j.state~="pending" then return false end
 stop(j,"cancelled","recovery owner cancelled");return true
end
local function charge(self:any,j:any,heartbeat:boolean?):boolean
 local s=self.session;local now=s.now();j.requests=s.counters.requests-j.startCount
 if now<(if heartbeat then j.nextBeatAttempt else j.nextAt) or not s.sched:budgetOk(now) then return false end
 if j.requests>=self.maxRequests then stop(j,"refused","total recovery request cap reached");return false end
 s.sched:begin(nil,now);s.counters.requests+=1;j.requests+=1;return true
end
local function resetWitnesses(j:any)
 if j.work then j.work:cancel() end
 if j.rebind then Fence.cancel(j.rebind.fence) end
 j.work,j.rebind,j.plan,j.rawP,j.rawR=nil,nil,nil,nil,nil;j.phase="capture"
end
local function renew(self:any,j:any):boolean
 local s=self.session;local now=s.now();local verdict=""
 local called,ok,value,why=pcall(s.backend.update,s.backend,s.pkey,function(old:any):any
  verdict="";if not j.guard() then verdict="changed";return nil end
  local opened=Envelope.open(s.pspec,old,false)
  if (opened.status~="ok" and opened.status~="migrated") or type(old)~="table" or type(old.lock)~="table" or old.lock.session~=s.id
   or not finite(old.lock.beat) or now<old.lock.beat or now-old.lock.beat>=Rules.LOCK_STALE then verdict="lost";return nil end
  verdict="owned";local lock=Json.copy(old.lock);lock.beat=now;return Envelope.withLock(old,lock)
 end)
 if not j.guard() then stop(j,"cancelled","session/intent changed during ownership check");return true end
 if verdict=="lost" then stop(j,"refused","owned recovery lease lost");return true end
 if not called or ok~=true then
  j.beatFailures+=1;j.nextBeatAttempt=now+Scheduler.backoff(j.beatFailures,Stores.classify(tostring(if called then why else ok)));return true
 end
 if verdict~="owned" or type(value)~="table" or type(value.lock)~="table" or value.lock.session~=s.id or value.lock.beat~=now then stop(j,"refused","ownership acknowledgement invalid");return true end
 s.sched:beat(now);j.beatFailures=0;j.nextBeatAttempt=now
 if j.rebind then resetWitnesses(j) end -- its P observation/issued serial changed
 return true
end
local function stepInner(self:any,j:any):boolean
 local s=self.session;local now=s.now();j.requests=s.counters.requests-j.startCount
 if not j.guard() then stop(j,"cancelled","session/intent changed");return false end
 if not finite(now) or now-j.started>=self.timeout then stop(j,"refused","total recovery deadline reached");return false end
 -- Each child already prioritizes its own heartbeat. The owner services only
 -- admission/adoption phases, avoiding duplicate renewal requests in one phase.
 if j.phase~="archive" and j.phase~="commit" and now-s.sched.lastBeat>=Rules.HEARTBEAT and charge(self,j,true) then return owned(self,function() return renew(self,j) end) end
 if j.state~="pending" then return false end
 if j.phase=="admitRead" then
  if not charge(self,j) then return false end
  local called,ok,value,why=owned(self,function() return pcall(s.backend.readRawFresh,s.backend,"M1_"..j.ticket.owner.."_"..j.ticket.mode) end)
  if not j.guard() then stop(j,"cancelled","session/intent changed during admission");return true end
  if not called or ok~=true then j.failures+=1;j.nextAt=now+Scheduler.backoff(j.failures,Stores.classify(tostring(if called then why else ok)));return true end
  if value==nil then launch(self,j,"archive")
  else
   if SaveRest.bounded(value,256,8) then stop(j,"refused","pending proposal exceeds structural bound");return true end
   local stored=Json.copy(value)
   j.work=Work.new(function():(any?,string?)
    local p,problem=Packet.open(stored,self.codec,self.context);if not p then return nil,problem end
    local id=j.ticket.identity
    if stored.owner~=j.ticket.owner or stored.slot~=j.ticket.mode or p.source.kind~=id.kind or p.source.checksum~=id.checksum
     or p.source.updatedAt~=id.updatedAt or p.save_life~=id.life then return nil,"pending proposal differs from selected original" end
    return {index={owner=stored.owner,checksum=stored.archive}},nil
   end,self.options.work);j.phase="admitWork"
  end
  return true
 end
 if j.phase=="admitWork" then
  owned(self,function() j.work:step() end)
  if not j.guard() then stop(j,"cancelled","session/intent changed");return false end
  if j.work.state=="pending" then return false end
  local result=j.work:take();j.work=nil
  if not result or not result[1] then stop(j,"refused",if result then tostring(result[2]) else "pending admission failed");return false end
  launch(self,j,"commit",result[1]);return false
 end
 if j.phase=="archive" or j.phase=="commit" then
  if j.requests>=self.maxRequests then stop(j,"refused","total recovery request cap reached");return false end
  local asked=j.component:step(j.child);j.requests=s.counters.requests-j.startCount
  if not j.guard() then stop(j,"cancelled","session/intent changed");return asked end
  if j.child.state=="refused" or j.child.state=="cancelled" then stop(j,"refused",j.child.problem or "recovery stage refused")
  elseif j.phase=="archive" and j.child.state=="ready" then
   local descriptor={index={owner=j.child.plan.index.owner,checksum=j.child.plan.index.checksum}}
   launch(self,j,"commit",descriptor)
  elseif j.phase=="commit" and j.child.state=="verified" then
   j.anchor=j.child.result.anchor;j.component,j.child=nil,nil;j.phase="capture"
  end
  return asked
 end
 if j.phase=="capture" then
  local why;j.rebind,why=Rebind.capture(s,j.held,j.ticket.mode,j.ticket.serial,j.ticket.offerId)
  if not j.rebind then stop(j,"refused",why or "rebind capture refused");return false end
  j.phase="witnessM1";return false
 end
 if j.phase=="prepare" then
  owned(self,function() j.work:step() end)
  if not j.guard() then stop(j,"cancelled","session/intent changed");return false end
  if j.work.state=="pending" then return false end
  local result=j.work:take();j.work=nil
  if not result or not result[1] then
   if not Rebind.valid(j.rebind) then resetWitnesses(j) else stop(j,"refused",if result then tostring(result[2]) else "rebind preparation failed") end
   return false
  end
  j.plan=result[1];j.phase="apply";return false
 end
 if j.phase=="apply" then
  local okay,result=owned(self,function() return Rebind.apply(j.plan) end)
  if not okay then
   if j.guard() and not Rebind.valid(j.rebind) then resetWitnesses(j) else stop(j,"refused",tostring(result)) end
   return false
  end
  j.result=result;j.state,j.problem="rebound",nil;s.recoveryOwner=nil;Fence.cancel(j.ticket);clean(j);return false
 end
 if not charge(self,j) then return false end
 local key=if j.phase=="witnessM1" then j.anchor.id elseif j.phase=="witnessR" then j.ticket.rkey else s.pkey
 local called,ok,value,why=owned(self,function() return pcall(s.backend.readRawFresh,s.backend,key) end)
 if not j.guard() then stop(j,"cancelled","session/intent changed during fresh read");return true end
 if not called or ok~=true then j.failures+=1;j.nextAt=now+Scheduler.backoff(j.failures,Stores.classify(tostring(if called then why else ok)));return true end
 if j.phase=="witnessM1" then
  if not same(j.anchor,value) then stop(j,"refused","immutable proposal changed before adoption");return true end
  j.phase="witnessR"
 elseif j.phase=="witnessR" then j.rawR=value;j.phase="witnessP"
 else
  j.rawP=value;j.work=Work.new(function() return Rebind.prepare(j.rebind,j.anchor,j.rawP,j.rawR,self.codec,self.context) end,self.options.work);j.phase="prepare"
 end
 j.failures=0;j.nextAt=now;return true
end
function Pipeline.step(self:any,j:any):boolean
 local s=self.session
 if self.current~=j or j.state~="pending" or self.busy or s.busy then return false end
 self.busy=true;local okay,asked=s.backend:run(j.held,function() return stepInner(self,j) end);self.busy=false
 j.requests=s.counters.requests-j.startCount
 if not okay then stop(j,"refused",tostring(asked));return false end
 return asked
end
return table.freeze(Pipeline)
