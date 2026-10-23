--!strict
-- Private server half of schema3 entry. A client-applied receipt is a solo-game
-- protocol acknowledgement, not anti-cheat proof of another machine's world.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local SaveRest=require(Shared.Persistence.SaveRest)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Progress=require(Shared.Persistence.SaveProgress)
local Scheduler=require(Shared.Persistence.SaveScheduler)
local Stores=require(Shared.Persistence.SaveStores)
local Archive=require(Shared.Persistence.RecoveryArchivePrototype)
local ArchiveStore=require(Shared.Persistence.RecoveryArchiveStorePrototype)
local Projection=require(Shared.Persistence.RecoveryProgressPrototype)
local Packet=require(script.Parent.RecoveryPacketPrototype)
local Format=require(script.Parent.RecoveryRestFormatPrototype)
local Entry={};Entry.__index=Entry
local function finite(v:any):boolean return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function same(a:any,b:any):boolean
 local pulse=Work.pulse();if pulse then pulse() end
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b and (type(a)~="number" or a~=0 or 1/a==1/b) end
 if getmetatable(b)~=nil then return false end
 for k,v in a do if not same(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
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
function Entry.new(runtime:any,options:any?):any
 local s=runtime.session;local cfg=options or {}
 assert(s.backend.boundSession==s and type(s.backend.run)=="function","bound recovery runtime required")
 local requests=cfg.maxRequests or 24;local timeout=cfg.timeout or 240
 assert(finite(requests) and requests>=1 and requests%1==0 and requests<=24 and finite(timeout) and timeout>=1 and timeout<=240,"invalid entry limits")
 return setmetatable({runtime=runtime,session=s,codec=runtime.recovery.codec,context=runtime.recovery.context,options=cfg,maxRequests=requests,timeout=timeout,busy=false},Entry)
end
local function scope(self:any,j:any):boolean
 local rt=self.runtime;local s=self.session;local r=j.request
 return (rt.phase=="entry_required" or rt.phase=="entering") and not rt.leaving and not rt.scopeInvalid
  and not s.closed and not s.flushing and s.state=="active" and s.lockHeld and s.offersEnabled
  and s.backend==j.backend and s.backend.source==j.source and s.backend.source==s.backend.boundSource and s.backend.boundSession==s
  and s.backend.held==j.held and s.backend:valid(j.held) and s.recoveryOwner==j.owner
  and s._loadSerial==j.load and s.id==j.id and tostring(s.cfg.userId)==j.user and s.pkey==j.pkey and s.rkey[j.mode]==j.rkey
  and s.sched==j.scheduler and s.intents==j.intents and s.intents.requests[j.mode]==r and r.revision==j.revision
  and r.kind=="continue" and r.serial==j.serial and r.state=="readonly" and r.credential==nil
  and (j.selection==nil or rt.continuedSelection==j.selection and s.observations.choices[j.mode]==j.selection.choice and j.selection.choice.offer.id==j.selection.offerId
   and j.selection.choice.serial==j.serial and j.selection.request==r and j.selection.revision==r.revision)
  and self.codec==rt.recovery.codec and self.context==rt.recovery.context
end
function Entry.begin(self:any):(any?,string?)
 local rt=self.runtime;local s=self.session;local now=s.now()
 if Work.pulse() or self.busy or s.busy or rt.busy or rt.phase~="entry_required" or self.current~=nil or not (rt.continuedSelection or rt.job) or not rt.result
  or (s.backend.activeUpdates or 0)>0 or not finite(now) or not finite(s.sched.lastBeat) or now<s.sched.lastBeat or now-s.sched.lastBeat>=Rules.LOCK_STALE then return nil,"entry routing unavailable" end
 local selected=rt.continuedSelection or rt.job.ticket;local mode=selected.mode;local r=s.intents.requests[mode]
 if not r or r.serial~=selected.serial or r.offerId~=selected.offerId or rt.result.gameplayAuthorized~=false or not rt.result.requiresSchema3Entry then return nil,"rebound/continued selection required" end
 local n=(rt.entrySerial or 0)+1;if n>Rules.MAX_LIFE_SERIAL then return nil,"entry serial exhausted" end
 local j={state="pending",phase="proposal",backend=s.backend,source=s.backend.source,held=s.backend.held,owner=s.recoveryOwner,load=s._loadSerial,id=s.id,user=tostring(s.cfg.userId),
  pkey=s.pkey,rkey=s.rkey[mode],scheduler=s.sched,intents=s.intents,mode=mode,serial=r.serial,request=r,revision=r.revision,
  selection=rt.continuedSelection,nonce=Json.checksum(s.id)..":"..n,started=now,lastNow=now,deadline=now+self.timeout,requests=0,nextAt=now,failures=0,parts={}}
 if j.held==nil or j.pkey~="P_"..j.user or j.rkey~="R_"..j.user.."_"..mode or not scope(self,j) then return nil,"entry identity unavailable" end
 if j.selection then
  local a=j.selection.archive
  if type(a)~="table" or not table.isfrozen(a) then return nil,"verified continued archive required" end
  j.cachedArchive=a
  j.parts={progress={format=ArchiveStore.FORMAT,version=1,owner=j.user,index=a.index,progress=a.entries.progress},main=a.entries.main,free=a.entries.free,easy=a.entries.easy}
 end
 rt.entrySerial=n;self.current=j;return j,nil
end
local function live(self:any,j:any):boolean
 local now=self.session.now()
 if self.current~=j or j.state~="pending" or not scope(self,j) or not finite(now) or now<j.lastNow or now>=j.deadline
  or now<self.session.sched.lastBeat or now-self.session.sched.lastBeat>=Rules.LOCK_STALE then return false end
 j.lastNow=now;return true
end
local function refuse(j:any,why:string)
 if j.work then j.work:cancel();j.work=nil end
 j.prepared,j.parts,j.anchor,j.rawRest,j.rawProgress,j.cachedArchive=nil,nil,nil,nil,nil,nil
 j.offer=nil;if j.state~="cancelled" then j.state,j.problem="refused",why end
end
function Entry.cancel(self:any,j:any):boolean
 if self.current~=j or j.state~="pending" then return false end
 j.state,j.problem="cancelled","entry cancelled";refuse(j,j.problem);return true
end
local function progress(self:any,j:any,raw:any,prepared:any?):(boolean,string?)
 if SaveRest.bounded(raw,Rules.MAX_PROGRESS_NODES*2+64,Rules.MAX_DEPTH+2) or not known(raw,{format=true,kind=true,schema=true,updatedAt=true,payload=true,checksum=true,backup=true,lock=true,session=true})
  or not known(raw.lock,{session=true,beat=true}) then return false,"unsupported entry progress" end
 local now=self.session.now();local lock=raw.lock
 if lock.session~=j.id or not finite(lock.beat) or now<lock.beat or now-lock.beat>=Rules.LOCK_STALE then return false,"fresh owned entry progress required" end
 if prepared then
  local covered,why=Projection.mergePending(raw,prepared.packet.progress,prepared.packet.progressTime)
  if not covered or covered.changed then return false,why or "proposal progress is not covered" end
  local op=Envelope.open(Progress.SPEC,raw,false);local ledger=if op.payload then op.payload.rare else nil;local l=prepared.life
  if not ledger or ledger.serial<l.rareSerial or l.rareVisit and (ledger.claimed[l.rareVisit.id] or 0)<l.rareVisit.serial then return false,"entry rare progress is not covered" end
 end
 return true,nil
end
local function prepare(self:any,j:any):(any?,string?)
 local p,why=Packet.open(j.anchor,self.codec,self.context);if not p then return nil,why end
 if j.anchor.owner~=j.user or j.anchor.slot~=j.mode then return nil,"entry proposal scope differs" end
 local a=j.parts.progress
 if not known(a,{format=true,version=true,owner=true,index=true,progress=true}) or a.format~=ArchiveStore.FORMAT or a.version~=1 or a.owner~=j.user or type(a.progress)~="table" then return nil,"entry archive anchor differs" end
 local sources={};for _,slot in Archive.SLOTS do
  local part=if slot=="progress" then a.progress else j.parts[slot]
  if type(part)~="table" then return nil,"entry archive part absent" end
  sources[slot]={loaded=true,value=part.raw}
 end
 local archive,problem=Archive.prepare(j.user,a.index.observation,sources);if not archive then return nil,problem end
 if not same(a.index,archive.index) or not same(a.progress,archive.entries.progress) then return nil,"entry archive anchor changed" end
 for _,slot in {"main","free","easy"} do if not same(j.parts[slot],archive.entries[slot]) then return nil,"entry archive part changed" end end
 if j.cachedArchive then
  local valid,archiveWhy=Archive.check(j.cachedArchive);if not valid or not same(j.cachedArchive.index,archive.index) then return nil,archiveWhy or "continued archive cache changed" end
  archive=j.cachedArchive -- retain one owned original snapshot, not a second copy
 end
 if not same(j.parts.index,{format=ArchiveStore.FORMAT,version=1,owner=j.user,complete=true,index=archive.index})
  or j.anchor.archive~=archive.index.checksum or j.anchor.source~=archive.entries[j.mode].checksum or p.archive.progress~=archive.entries.progress.checksum then return nil,"entry complete archive differs from proposal" end
 local called,logical=pcall(self.codec.decode,self.codec,j.rawRest);if not called then return nil,tostring(logical) end
 local op=Format.open(j.mode,logical,self.context)
 if op.status~="ok" or not op.payload or op.payload.save_retired then return nil,"active schema3 entry required" end
 local current
 if op.payload.format==Packet.FORMAT then
  if not same(j.rawRest,j.anchor.target) then return nil,"initial entry rest differs from proposal" end
  current,why=Format.fromProposal(j.anchor,self.codec,self.context)
 else current=op.payload;if not Format.matchesProposal(current,j.anchor,self.codec,self.context) then return nil,"entry provenance differs" end end
 if not current then return nil,why end
 if j.selection then
  local id=j.selection.identity
  if id.kind~="primary" or id.checksum~=logical.checksum or id.updatedAt~=logical.updatedAt or id.life~=current.save_life then return nil,"continued rest differs from selected observation" end
 end
 local bad,details=Format.check(j.mode,current,self.context);if bad then return nil,bad end
 local life=details.decoded.roots.life
 if not finite(life.rareSerial) or life.rareSerial<p.binding.serial or life.rareGeneration~=(life.generation or 0) then return nil,"entry rare generation differs" end
 local result={archive=archive,anchor=Json.copy(j.anchor),rawRest=Json.copy(j.rawRest),identity={checksum=logical.checksum,updatedAt=logical.updatedAt},current=current,
  packet={progress=Json.copy(p.progress),progressTime=p.progressTime},life=life}
 local good,errorText=progress(self,j,j.rawProgress,result);if not good then return nil,errorText end
 result.offer={v=1,id=j.nonce,epoch=j.id,mode=j.mode,serial=j.serial,revision=j.revision,entryKind=current.entryKind,life=current.save_life,
  identity={checksum=logical.checksum,updatedAt=logical.updatedAt},checkpoint=current.checkpoint}
 -- Decoded classes need not cross the wire or survive preparation.
 result.life={rareSerial=life.rareSerial,rareVisit=Json.copy(life.rareVisit)}
 freeze(result);return result,nil
end
function Entry.applied(self:any,j:any,msg:any):boolean
 if Work.pulse() or self.busy or self.session.busy or not live(self,j) or j.phase~="awaitApplied" or SaveRest.bounded(msg,40,4)
  or not known(msg,{kind=true,v=true,id=true,epoch=true,mode=true,serial=true,revision=true,identity=true}) then return false end
 local o=j.offer
 if msg.kind~="recovery_applied" or msg.v~=1 or msg.id~=o.id or msg.epoch~=o.epoch or msg.mode~=o.mode or msg.serial~=o.serial or msg.revision~=o.revision or not same(msg.identity,o.identity) then return false end
 j.offer=nil;j.phase="finalRest";return true
end
local function stepInner(self:any,j:any):boolean
 local s=self.session
 if not live(self,j) then refuse(j,"entry scope/deadline changed");return false end
 if j.phase=="awaitApplied" then return false end
 if j.phase=="prepare" then
  j.work:step();if not live(self,j) then refuse(j,"entry changed during preparation");return false end
  if j.work.state=="pending" then return false end
  local result=j.work:take();j.work=nil
  if not result or not result[1] then refuse(j,if result then tostring(result[2]) else "entry preparation failed");return false end
  j.prepared=result[1];j.offer=j.prepared.offer;j.parts,j.anchor,j.rawRest,j.rawProgress,j.cachedArchive=nil,nil,nil,nil,nil;j.phase="awaitApplied";return false
 end
 local now=s.now();if now<j.nextAt or not s.sched:budgetOk(now) then return false end
 if j.requests>=self.maxRequests then refuse(j,"entry request cap reached");return false end
 local key=if j.phase=="proposal" then "M1_"..j.user.."_"..j.mode elseif j.phase=="archive" then "A1_"..j.user.."_"..j.part
  elseif j.phase=="rest" or j.phase=="finalRest" then j.rkey else j.pkey
 s.sched:begin(nil,now);s.counters.requests+=1;j.requests+=1
 local called,ok,value,why=pcall(j.backend.readRawFresh,j.backend,key)
 if not live(self,j) then refuse(j,"entry changed during fresh read");return true end
 if not called or ok~=true then j.failures+=1;j.nextAt=s.now()+Scheduler.backoff(j.failures,Stores.classify(tostring(if called then why else ok)));return true end
 j.failures,j.nextAt=0,s.now()
 if j.phase=="proposal" then
  if SaveRest.bounded(value,256,8) then refuse(j,"entry proposal exceeds bound");return true end
  j.anchor=value;j.phase,j.part="archive",if j.cachedArchive then "index" else "progress"
 elseif j.phase=="archive" then
  if SaveRest.bounded(value,Archive.MAX_NODES,Archive.MAX_DEPTH+8) then refuse(j,"entry archive exceeds bound");return true end
  j.parts[j.part]=value
  local nextPart={progress="main",main="free",free="easy",easy="index"};j.part=nextPart[j.part]
  if not j.part then j.phase="rest" end
 elseif j.phase=="rest" then
  if SaveRest.bounded(value,Rules.MAX_REST_NODES*2+1024,Rules.MAX_DEPTH+6) then refuse(j,"entry rest exceeds bound");return true end
  j.rawRest=value;j.phase="progress"
 elseif j.phase=="progress" then
  local good,problem=progress(self,j,value);if not good then refuse(j,problem or "entry progress refused");return true end
  j.rawProgress=value;j.work=Work.new(function() return prepare(self,j) end,self.options.work);j.phase="prepare"
 elseif j.phase=="finalRest" then
  if not same(value,j.prepared.rawRest) then refuse(j,"entry rest changed after client application");return true end
  j.phase="finalProgress"
 else
  local good,problem=progress(self,j,value,j.prepared);if not good then refuse(j,problem or "entry final progress refused");return true end
  -- Grant has a user callback; defer notification until Runtime has installed the
  -- completed state. No yield/callback occurs inside this final commit boundary.
  local intents=s.intents;local emit=intents.emit;intents.emit=nil
  local granted,accepted=pcall(intents.grant,intents,j.request,j.prepared.current.save_life);intents.emit=emit
  if not granted or not accepted then refuse(j,"entry life grant failed");return true end
  local p=j.prepared
  s.lifeTokens[j.mode]=p.current.save_life;s.restLoaded[j.mode]=true;s.restBase[j.mode]=p.identity.updatedAt;s.restRevision[j.mode]=p.identity.checksum
  j.state,j.problem="verified",nil
  j.result={checkpoint=p.current.checkpoint,entryKind=p.current.entryKind,save_life=p.current.save_life,credential=j.request.credential,
   archive=p.archive,anchor=p.anchor,rawRest=p.rawRest,current=p.current,requiresSchema3Entry=false,gameplayAuthorized=true,clientAppliedAcknowledged=true,decisionPending=true}
  j.prepared=nil
 end
 return true
end
function Entry.step(self:any,j:any):boolean
 local s=self.session
 if self.current~=j or j.state~="pending" or self.busy or s.busy or Work.pulse() or (s.backend.activeUpdates or 0)>0 then return false end
 self.busy,s.busy=true,true;local ok,asked=s.backend:run(j.held,function() return stepInner(self,j) end);self.busy,s.busy=false,false
 if not ok then refuse(j,tostring(asked));return false end
 return asked
end
return table.freeze(Entry)
