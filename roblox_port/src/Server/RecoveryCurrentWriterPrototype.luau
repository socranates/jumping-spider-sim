--!strict
-- Private schema3 continuation writer. Requires an already granted actual life
-- intent; this module never grants entry/credentials or rewrites archives/M1.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local SaveRest=require(Shared.Persistence.SaveRest)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Progress=require(Shared.Persistence.SaveProgress)
local Projection=require(Shared.Persistence.RecoveryProgressPrototype)
local Archive=require(Shared.Persistence.RecoveryArchivePrototype)
local ArchiveStore=require(Shared.Persistence.RecoveryArchiveStorePrototype)
local Scheduler=require(Shared.Persistence.SaveScheduler)
local Stores=require(Shared.Persistence.SaveStores)
local Packet=require(script.Parent.RecoveryPacketPrototype)
local Format=require(script.Parent.RecoveryRestFormatPrototype)
local Operation=require(Shared.Persistence.RecoveryOperationAdmission)
local Writer={};Writer.__index=Writer
local prepared:any=setmetatable({},{__mode="k"})
local captures:any=setmetatable({},{__mode="k"})
local function finite(v:any):boolean return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function whole(v:any):boolean return finite(v) and v>=1 and v<=Rules.MAX_LIFE_SERIAL and v%1==0 end
local function known(v:any,fields:any):boolean
 if type(v)~="table" or getmetatable(v)~=nil then return false end
 for k in v do if not fields[k] then return false end end
 return true
end
local function same(a:any,b:any):boolean
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b and (type(a)~="number" or a~=0 or 1/a==1/b) end
 if getmetatable(b)~=nil then return false end
 for k,v in a do if not same(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
local function freeze(v:any)
 local pulse=Work.pulse();if pulse then pulse() end
 if type(v)~="table" then return end
 for _,x in v do freeze(x) end
 if not table.isfrozen(v) then table.freeze(v) end
end
local function store(source:any,raw:any):any
 if raw==source then return source end
 if type(source.ds)=="table" or typeof(source.ds)=="Instance" then
  if type(raw.backend)=="table" and raw.backend.ds==source.ds then return source.ds end
 end
 return nil
end
function Writer.new(session:any,raw:any,codec:any,context:any,options:any?):any
 local cfg=options or {};local requests=cfg.maxRequests or 16;local timeout=cfg.timeout or 180
 assert(type(session.backend.run)=="function" and session.backend.boundSession==session,"factory-bound tracked session required")
 assert(type(raw.updateRaw)=="function" and type(raw.readRawFresh)=="function" and store(session.backend.source,raw)~=nil,"raw adapter must use the same physical store")
 assert(whole(requests) and requests<=16 and finite(timeout) and timeout>=1 and timeout<=180,"invalid current rest limits")
 return setmetatable({session=session,raw=raw,codec=codec,context=context,maxRequests=requests,timeout=timeout,admission=cfg.admission,busy=false,store=store(session.backend.source,raw)},Writer)
end
local function valid(self:any,t:any):boolean
 local s=self.session;local r=t.request
 return not t.cancelled and s.backend==t.backend and s.backend.source==t.source and s.backend.source==s.backend.boundSource
  and store(t.source,self.raw)==t.store and self.raw==t.raw and self.codec==t.codec and self.context==t.context
  and s._loadSerial==t.load and s.id==t.id and tostring(s.cfg.userId)==t.user and s.pkey==t.pkey and s.rkey[t.mode]==t.key
  and s.sched==t.scheduler and s.intents==t.intents and s.recoveryOwner==t.owner and s.backend.held==t.held
  and (t.held==nil or s.backend:valid(t.held)) and not s.closed and not s.flushing and s.state=="active" and s.lockHeld
  and s.intents.requests[t.mode]==r and (r.kind=="continue" or t.retiredRuntime~=nil and r.kind=="new") and r.revision==t.revision
  and (t.retiredRuntime~=nil and t.retiredRuntime.session==s and not t.retiredRuntime.leaving
   and (t.retiredRuntime.phase=="retired" or t.retiredRuntime.phase=="freshening") and t.retiredRuntime.result.retired==true
   and t.retiredRuntime.result.rawRest==t.retiredRaw and t.retiredRuntime.result.archive==t.retiredArchive and t.retiredRuntime.result.anchor==t.retiredAnchor
   and r.credential==nil and (r.state=="changed" and r.reason=="life_retired"
    or r.kind=="new" and r.state=="readonly" and r.protected==true and t.retiredSelection~=nil
     and t.retiredRuntime.retiredSelection==t.retiredSelection and t.retiredSelection.request==r
     and s.observations.choices[t.mode]==t.retiredSelection.choice and t.retiredSelection.choice.offer.id==r.offerId
     and same(r.base,t.retiredSelection.identity) and same(t.retiredSelection.choice.offer.identity,t.retiredSelection.identity))
   or t.retiredRuntime==nil and s.intents:authorized(t.mode,t.serial,t.credential,t.life))
  and (r.receivedSerial or 0)==(if t.started then t.restSerial else t.received)
end
function Writer.capture(self:any,mode:string,serial:number,credential:string,life:any,restSerial:number):(any?,string?)
 local s=self.session
 if Work.pulse() or self.busy or s.busy or s.closed or s.flushing or (s.backend.activeUpdates or 0)>0
  or self.current and (self.current.state=="pending") or not table.find(Rules.MODES,mode) or not whole(restSerial)
  or not s.offersEnabled or not s.intents:authorized(mode,serial,credential,life) then return nil,"writable current life required" end
 local r=s.intents.requests[mode];local now=s.now();local held=s.backend.held
 if r.kind~="continue" or restSerial<=(r.receivedSerial or 0) or not finite(now) or not finite(s.sched.lastBeat)
  or now<s.sched.lastBeat or now-s.sched.lastBeat>=Rules.LOCK_STALE or held~=nil and not s.backend:valid(held) then return nil,"fresh ordered continuation scope required" end
 local t={backend=s.backend,source=s.backend.source,raw=self.raw,store=self.store,codec=self.codec,context=self.context,
  load=s._loadSerial,id=s.id,user=tostring(s.cfg.userId),pkey=s.pkey,key=s.rkey[mode],scheduler=s.sched,intents=s.intents,owner=s.recoveryOwner,held=held,
  mode=mode,serial=serial,credential=credential,life=life,restSerial=restSerial,received=r.receivedSerial or 0,request=r,revision=r.revision,created=now,started=false,cancelled=false}
 if t.pkey~="P_"..t.user or t.key~="R_"..t.user.."_"..mode or not valid(self,t) then return nil,"continuation identity changed" end
 local handle=table.freeze({});captures[handle]={writer=self,ticket=t};return handle,nil
end
function Writer.captureRetired(self:any,runtime:any):(any?,string?)
 local s=self.session;local loop=runtime.saveLoop;local r=if loop then loop.request else runtime.retiredRequest;local now=s.now();local held=s.backend.held
 if Work.pulse() or self.busy or s.busy or s.closed or s.flushing or (s.backend.activeUpdates or 0)>0 or self.current and self.current.state=="pending"
  or runtime.session~=s or runtime.phase~="retired" or runtime.leaving or runtime.intakeClosed or not runtime.result.retired
  or (loop~=nil and (loop.state~="retired" or loop.writer~=self)) or (loop==nil and runtime.freshWriter~=self) or not r or r.credential~=nil
  or not finite(now) or not finite(s.sched.lastBeat) or now<s.sched.lastBeat or now-s.sched.lastBeat>=Rules.LOCK_STALE then return nil,"verified retired owner required" end
 local restSerial=(r.receivedSerial or 0)+1;if not whole(restSerial) then return nil,"retirement ticket exhausted" end
 local t={backend=s.backend,source=s.backend.source,raw=self.raw,store=self.store,codec=self.codec,context=self.context,
  load=s._loadSerial,id=s.id,user=tostring(s.cfg.userId),pkey=s.pkey,key=s.rkey[r.mode],scheduler=s.sched,intents=s.intents,owner=s.recoveryOwner,held=held,
  mode=r.mode,serial=r.serial,credential=nil,life=if loop then r.life else runtime.result.current.provenance.originLife,restSerial=restSerial,received=r.receivedSerial or 0,request=r,revision=r.revision,created=now,started=false,cancelled=false,
  retiredRuntime=runtime,retiredSelection=runtime.retiredSelection,retiredRaw=runtime.result.rawRest,retiredArchive=runtime.result.archive,retiredAnchor=runtime.result.anchor}
 if t.pkey~="P_"..t.user or t.key~="R_"..t.user.."_"..t.mode or not valid(self,t) then return nil,"retired identity changed" end
 local handle=table.freeze({});captures[handle]={writer=self,ticket=t};return handle,nil
end
local function prepare(self:any,handle:any,originalArchive:any,anchor:any,priorRaw:any,record:any,retirement:string?,fresh:boolean?):(any?,string?)
 local captured=captures[handle];local t=if captured and captured.writer==self then captured.ticket else nil
 if not t or t.started or not valid(self,t) or (fresh==true)~=(t.retiredRuntime~=nil) then return nil,"current life changed before preparation" end
 local checked,why=Archive.check(originalArchive);if not checked then return nil,why end
 local packet,errorText=Packet.open(anchor,self.codec,self.context);if not packet then return nil,errorText end
 if anchor.owner~=t.user or anchor.slot~=t.mode or packet.save_life~=t.life or anchor.archive~=originalArchive.index.checksum
  or anchor.source~=originalArchive.entries[t.mode].checksum or packet.archive.progress~=originalArchive.entries.progress.checksum then return nil,"original archive/proposal differs" end
 if SaveRest.bounded(priorRaw,Rules.MAX_REST_NODES*2+1024,Rules.MAX_DEPTH+6) then return nil,"current stored rest exceeds bound" end
 local decoded,logical=pcall(self.codec.decode,self.codec,priorRaw)
 if not decoded then return nil,tostring(logical) end
 local opened=Format.open(t.mode,logical,self.context)
 if opened.status~="ok" or not opened.payload or (opened.payload.save_retired==true)~=(fresh==true) then return nil,"expected schema3 life/retirement required" end
 local prior
 if opened.payload.format==Packet.FORMAT then
  if not same(priorRaw,anchor.target) then return nil,"initial stored rest differs from immutable target" end
  prior,errorText=Format.fromProposal(anchor,self.codec,self.context)
 else
  prior=opened.payload
  if not Format.matchesProposal(prior,anchor,self.codec,self.context) then return nil,"current provenance differs from immutable proposal" end
 end
 if not prior then return nil,errorText end
 if retirement and (not SaveRest.validLife(retirement) or retirement==t.life) then return nil,"distinct server retirement token required" end
 local nextRest:any=nil;local problem:string?=nil
 if fresh then nextRest={save_retired=true,save_life=prior.save_life}
 elseif retirement then nextRest,problem=Format.retire(prior,retirement,self.context) else nextRest,problem=Format.advance(prior,record,self.context) end
 if not nextRest then return nil,problem end
 if not fresh and not retirement and nextRest.save_life~=t.life then return nil,"checkpoint differs from granted life" end
 local requiredRare
 if fresh then
  if #SaveRest.SPECS[t.mode].validate(nextRest)>0 then return nil,"invalid ordinary retirement marker" end
  requiredRare={serial=packet.binding.serial,visit=nil}
 else
  local bad,details=Format.check(t.mode,nextRest,self.context);if bad then return nil,bad end
  local activeDetails:any=details
  if retirement then
   local priorProblem,priorDetails=Format.check(t.mode,prior,self.context)
   if priorProblem then return nil,priorProblem end
   activeDetails=priorDetails
  end
  local l=activeDetails.decoded.roots.life
  if not finite(l.rareSerial) or l.rareSerial<packet.binding.serial or l.rareGeneration~=(l.generation or 0) then return nil,"current rare generation is not bound" end
  requiredRare={serial=l.rareSerial,visit=Json.copy(l.rareVisit)}
 end
 local spec=if fresh then SaveRest.SPECS[t.mode] else Format.spec(t.mode,self.context)
 local nextLogical=if same(opened.payload,nextRest) then logical else Envelope.make(spec,nextRest,math.max(t.created,logical.updatedAt),logical,{session=t.id})
 local candidate=priorRaw
 if not same(opened.payload,nextRest) then
  local encoded,result=pcall(self.codec.encode,self.codec,nextLogical)
  if not encoded then return nil,tostring(result) end
  candidate=result
 end -- preserve exact no-op bytes/backup
 local plan={fresh=fresh==true,retirement=retirement,anchor=Json.copy(anchor),archiveIndex={format=ArchiveStore.FORMAT,version=1,owner=t.user,complete=true,index=Json.copy(originalArchive.index)},
  expected=Json.copy(priorRaw),candidate=Json.copy(candidate),logical=Json.copy(nextLogical),packetProgress=Json.copy(packet.progress),packetTime=packet.progressTime,
  rare=requiredRare}
 freeze(plan.anchor);freeze(plan.archiveIndex);freeze(plan.expected);freeze(plan.candidate);freeze(plan.logical);freeze(plan.packetProgress);freeze(plan.rare)
 if not valid(self,t) then return nil,"current life changed during preparation" end
 captures[handle]=nil;table.freeze(plan);prepared[plan]={writer=self,ticket=t};return plan,nil
end
function Writer.prepare(self:any,handle:any,originalArchive:any,anchor:any,priorRaw:any,record:any):(any?,string?)
 return prepare(self,handle,originalArchive,anchor,priorRaw,record,nil,false)
end
function Writer.prepareFresh(self:any,handle:any,originalArchive:any,anchor:any,priorRaw:any):(any?,string?)
 return prepare(self,handle,originalArchive,anchor,priorRaw,nil,nil,true)
end
function Writer.prepareRetirement(self:any,handle:any,originalArchive:any,anchor:any,priorRaw:any,newLifeSerial:number):(any?,string?)
 local capture=captures[handle];local t=if capture and capture.writer==self then capture.ticket else nil
 if not t or not whole(newLifeSerial) or newLifeSerial<=t.serial then return nil,"later explicit New Life serial required" end
 return prepare(self,handle,originalArchive,anchor,priorRaw,nil,`{t.id}:{t.mode}:{newLifeSerial}`,false)
end
function Writer.begin(self:any,plan:any):(any?,string?)
 local preparedScope=prepared[plan];local t=if preparedScope and preparedScope.writer==self then preparedScope.ticket else nil
 if Work.pulse() or self.busy or self.session.busy or not t or t.started or not valid(self,t)
  or self.current and self.current.state=="pending" then return nil,"owned current preparation required" end
 local now=self.session.now()
 if not finite(now) or now<self.session.sched.lastBeat or now-self.session.sched.lastBeat>=Rules.LOCK_STALE then return nil,"continuation observation expired" end
 prepared[plan]=nil;t.started=true;t.request.receivedSerial=t.restSerial
 local j={plan=plan,ticket=t,state="pending",phase="proposal",started=now,lastNow=now,deadline=now+self.timeout,expiresAt=self.session.sched.lastBeat+Rules.LOCK_STALE,nextAt=now,failures=0,requests=0}
 self.current=j;return j,nil
end
local function clean(j:any)
 for _,name in {"io","rawIO"} do if j[name] then j[name]:cancel();j[name]=nil end end
 j.leaseState,j.writeState=nil,nil
end
function Writer.cancel(self:any,j:any):boolean
 if self.current~=j or j.state~="pending" then return false end
 j.state,j.problem="cancelled","current rest cancelled";j.ticket.cancelled=true;clean(j);return true
end
local function live(self:any,j:any):boolean
 local now=self.session.now()
 if j.state~="pending" or not valid(self,j.ticket) or not finite(now) or now<j.lastNow or now>=j.deadline or now>=j.expiresAt then return false end
 j.lastNow=now;return true
end
local function refuse(j:any,why:string)
 if j.state~="cancelled" then j.state,j.problem="refused",why end;clean(j)
end
local function progress(self:any,j:any,raw:any):(boolean,string?)
 if SaveRest.bounded(raw,Rules.MAX_PROGRESS_NODES*2+64,Rules.MAX_DEPTH+2)
  or not known(raw,{format=true,kind=true,schema=true,updatedAt=true,payload=true,checksum=true,backup=true,lock=true,session=true})
  or not known(raw.lock,{session=true,beat=true}) then return false,"unsupported current progress/lock" end
 local now=self.session.now();local lock=raw.lock
 if lock.session~=j.ticket.id or not finite(lock.beat) or now<lock.beat or now-lock.beat>=Rules.LOCK_STALE then return false,"fresh owned progress required" end
 local covered,why=Projection.mergePending(raw,j.plan.packetProgress,j.plan.packetTime)
 if not covered or covered.changed then return false,why or "original proposal not covered by durable progress" end
 local op=Envelope.open(Progress.SPEC,raw,false);local ledger=if op.payload then op.payload.rare else nil;local required=j.plan.rare
 if not ledger or ledger.serial<required.serial or required.visit and (ledger.claimed[required.visit.id] or 0)<required.visit.serial then return false,"current rare binding is not durably covered" end
 return true,nil
end
local function retry(self:any,j:any,phase:string,why:any)
 j.failures+=1;j.phase=phase;j.problem=tostring(why);j.nextAt=self.session.now()+Scheduler.backoff(j.failures,Stores.classify(j.problem))
end
local function nextPhase(j:any,phase:string) j.phase,j.failures,j.problem,j.nextAt=phase,0,nil,j.lastNow end
local function stepInner(self:any,j:any):boolean
 local s=self.session
 if not live(self,j) then refuse(j,"current life/scope/deadline changed");return false end
 local now=s.now()
 if self.admission and not j.io then
  local rows={{object=j,field="requests",max=self.maxRequests}}
  local guard=function() return live(self,j) end
  j.io=Operation.new(s,self.admission,guard,rows)
  j.rawIO=Operation.new(s,self.admission,guard,rows,{update={object=self.raw,fn=self.raw.updateRaw}})
 end
 if now<j.nextAt or not j.io and not s.sched:budgetOk(now) then return false end
 if j.requests>=self.maxRequests then refuse(j,"current rest request cap reached");return false end
 if j.phase~="lease" and j.phase~="leaseRead" and not (j.io and j.io.handle or j.rawIO and j.rawIO.handle) and now-s.sched.lastBeat>=Rules.HEARTBEAT then j.afterLease=j.phase;j.phase="lease" end
 if not j.io then s.sched:begin(nil,now);s.counters.requests+=1;j.requests+=1 end
 if j.phase=="lease" then
  if not j.leaseState then
   local evidence:any={}
   evidence.transform=function(old:any):any
   evidence.rejected,evidence.expected=nil,nil
   if not live(self,j) then evidence.rejected="current scope changed during lease";return nil end
   local good,problem=progress(self,j,old);if not good then evidence.rejected=problem;return nil end
   evidence.expected=Envelope.withLock(old,{session=s.id,beat=s.now()});j.expiresAt=math.max(j.expiresAt,evidence.expected.lock.beat+Rules.LOCK_STALE);return evidence.expected
   end
   j.leaseState=evidence
  end
  local evidence=j.leaseState
  local called,ok,value,why=true,nil,nil,nil
  if j.io then
   local state,result,asked=j.io:poll("update",s.pkey,evidence.transform)
   if state=="waiting" then return false end
   if state~="done" then refuse(j,"current admitted lease ended");return asked end
   ok,value,why=table.unpack(result,1,result.n)
  else called,ok,value,why=pcall(s.backend.update,s.backend,s.pkey,evidence.transform) end
  local rejected,expected=evidence.rejected,evidence.expected;j.leaseState=nil
  if not live(self,j) then refuse(j,"current scope changed after lease");return true end
  if rejected then refuse(j,rejected);return true end
  if not called or ok~=true then retry(self,j,"leaseRead",if called then why else ok);return true end
  local good,problem=progress(self,j,value)
  if not good or not same(expected,value) then refuse(j,problem or "current lease acknowledgement differs");return true end
  s.sched:beat(value.lock.beat);j.expiresAt=value.lock.beat+Rules.LOCK_STALE
  local phase=j.afterLease or "write";j.afterLease=nil;nextPhase(j,phase);return true
 end
 if j.phase=="write" then
  if not j.writeState then
   local evidence:any={}
   evidence.transform=function(old:any):any
   evidence.changed=false
   if not live(self,j) or s.now()-s.sched.lastBeat>=Rules.LOCK_STALE then return nil end
   if same(old,j.plan.candidate) then return nil end
   if not same(old,j.plan.expected) then evidence.changed=true;return nil end
   return j.plan.candidate
   end
   j.writeState=evidence
  end
  local evidence=j.writeState
  local called,ok,_value,why=true,nil,nil,nil
  if j.rawIO then
   local state,result,asked=j.rawIO:poll("update",j.ticket.key,evidence.transform)
   if state=="waiting" then return false end
   if state~="done" then refuse(j,"current admitted raw write ended");return asked end
   ok,_value,why=table.unpack(result,1,result.n)
  else called,ok,_value,why=pcall(self.raw.updateRaw,self.raw,j.ticket.key,evidence.transform) end
  local changed=evidence.changed;j.writeState=nil
  if not live(self,j) then refuse(j,"current scope changed during rest write");return true end
  if changed then refuse(j,"current stored rest changed");return true end
  j.lastWriteError=if called and ok==true then nil else tostring(if called then why else ok)
  nextPhase(j,"readback");return true
 end
 local key=if j.phase=="proposal" then j.plan.anchor.id elseif j.phase=="archive" then "A1_"..j.ticket.user.."_index"
  elseif j.phase=="readback" then j.ticket.key else s.pkey
 local called,ok,value,why=true,nil,nil,nil
 if j.io then
  local state,result,asked=j.io:poll("readRawFresh",key,nil)
  if state=="waiting" then return false end
  if state~="done" then refuse(j,"current admitted read ended");return asked end
  ok,value,why=table.unpack(result,1,result.n)
 else called,ok,value,why=pcall(s.backend.readRawFresh,s.backend,key) end
 if not live(self,j) then refuse(j,"current scope changed during uncached read");return true end
 if not called or ok~=true then retry(self,j,j.phase,if called then why else ok);return true end
 if j.phase=="proposal" then
  if not same(value,j.plan.anchor) then refuse(j,"immutable proposal changed");return true end
  nextPhase(j,"archive")
 elseif j.phase=="archive" then
  if not same(value,j.plan.archiveIndex) then refuse(j,"complete archive index changed");return true end
  nextPhase(j,"lease")
 elseif j.phase=="leaseRead" then
  local good,problem=progress(self,j,value);if not good then refuse(j,problem or "current progress probe refused");return true end
  s.sched:beat(value.lock.beat);j.expiresAt=value.lock.beat+Rules.LOCK_STALE
  local phase=j.afterLease or "write";j.afterLease=nil;nextPhase(j,phase)
 elseif j.phase=="readback" then
  if same(value,j.plan.candidate) then nextPhase(j,"finalLease")
  elseif same(value,j.plan.expected) then retry(self,j,"proposal",j.lastWriteError or "current rest not observed")
  else refuse(j,"current rest readback differs") end
 else
  local good,problem=progress(self,j,value);if not good then refuse(j,problem or "final progress ownership changed");return true end
  local t=j.ticket;local r=t.request
  if (r.storedSerial or 0)>=t.restSerial then refuse(j,"current rest receipt superseded");return true end
  r.storedSerial,r.storedCredential=t.restSerial,t.credential
  j.state,j.problem="verified",nil;clean(j);j.result={stored=true,restSerial=t.restSerial,credential=t.credential,life=t.life,
   identity={checksum=j.plan.logical.checksum,updatedAt=j.plan.logical.updatedAt,life=j.plan.logical.payload.save_life},retired=j.plan.retirement~=nil,freshMarker=j.plan.fresh,gameplayAuthorized=false}
  if not j.plan.retirement and not j.plan.fresh and s.cfg.onStored then pcall(s.cfg.onStored,t.mode,t.serial,t.credential,t.restSerial) end
 end
 return true
end
function Writer.step(self:any,j:any):boolean
 local s=self.session
 if self.current~=j or j.state~="pending" or self.busy or s.busy or (s.backend.activeUpdates or 0)>0 or Work.pulse() then return false end
 self.busy,s.busy=true,true
 local ok,asked
 if j.ticket.held then ok,asked=s.backend:run(j.ticket.held,function() return stepInner(self,j) end) else ok,asked=pcall(stepInner,self,j) end
 self.busy,s.busy=false,false
 if not ok then refuse(j,tostring(asked));return false end
 return asked
end
return table.freeze(Writer)
