--!strict
-- Private read-only legacy/pending-import discovery. Publishes only protected
-- observations; never restores a world, takes a lease or grants a credential.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local SaveRest=require(Shared.Persistence.SaveRest)
local Scheduler=require(Shared.Persistence.SaveScheduler)
local Stores=require(Shared.Persistence.SaveStores)
local Archive=require(Shared.Persistence.RecoveryArchivePrototype)
local ArchiveStore=require(Shared.Persistence.RecoveryArchiveStorePrototype)
local Life=require(Shared.Persistence.RecoveryLifePrototype)
local Packet=require(script.Parent.RecoveryPacketPrototype)
local Reader={};Reader.__index=Reader
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function owner(v:any):boolean return type(v)=="string" and #v>0 and #v<=32 and string.match(v,"^[%w_-]+$")~=nil end
local function same(a:any,b:any):boolean
 local pulse=Work.pulse();if pulse then pulse() end
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
-- The read-only equivalent of the archive repository's reconstruction. Exact
-- expected publication shapes, including the final index, are verified; no
-- repair/write is attempted from an offer-discovery path.
local function storedArchive(user:string,parts:any):(any?,string?)
 return ArchiveStore.checkPublished(user,parts)
end
function Reader.prepare(user:string,slot:string,raw:any,anchor:any,parts:any,codec:any,context:any,requestedKind:string?,currentFormat:any?,retiredNewLife:boolean?):(any?,string?)
 if not owner(user) or not table.find(Rules.MODES,slot) or requestedKind~=nil and requestedKind~="primary" and requestedKind~="backup" then return nil,"invalid recovery offer scope" end
 if SaveRest.bounded(raw,if currentFormat then Rules.MAX_REST_NODES*2+1024 else Archive.MAX_NODES,if currentFormat then Rules.MAX_DEPTH+6 else Archive.MAX_DEPTH+2) then return nil,"stored rest exceeds structural bound" end
 local selectedRaw=raw;local kind=requestedKind or "primary";local plan=nil;local pendingSource:any=nil
 if anchor~=nil then
  if SaveRest.bounded(anchor,256,8) then return nil,"pending proposal exceeds structural bound" end
  local payload,why=Packet.open(anchor,codec,context);if not payload then return nil,why end
  if anchor.owner~=user or anchor.slot~=slot then return nil,"pending proposal belongs to another owner/slot" end
  if currentFormat==nil and requestedKind~=nil and requestedKind~=payload.source.kind then return nil,"pending proposal selected a different original" end
  kind=payload.source.kind
  pendingSource=payload.source
  local recovered,errorText=storedArchive(user,parts);if not recovered then return nil,errorText end
  plan=recovered
  if anchor.archive~=plan.index.checksum or anchor.source~=plan.entries[slot].checksum or payload.archive.progress~=plan.entries.progress.checksum then return nil,"pending proposal/archive differs" end
  if currentFormat then
   local decoded,logical=pcall(codec.decode,codec,raw)
   if decoded then
    local op=currentFormat.open(slot,logical,context)
    if op.status=="ok" and type(op.payload)=="table" and (op.payload.format==Packet.FORMAT or op.payload.format==currentFormat.FORMAT) then
     if requestedKind=="backup" then return nil,"continued recovery requires explicit current-backup policy" end
     local current,problem
     if op.payload.format==Packet.FORMAT then
      if not same(raw,anchor.target) then return nil,"initial current packet differs from immutable target" end
      current,problem=currentFormat.fromProposal(anchor,codec,context)
     else
      current=op.payload
      if not currentFormat.matchesProposal(current,anchor,codec,context) then return nil,"continued provenance differs from original proposal" end
     end
     if not current then return nil,problem end
     if current.save_retired then
      if not retiredNewLife then return nil,"retired recovery requires explicit New Life" end
      local out={record={save_retired=true,save_life=current.save_life},identity={checksum=logical.checksum,updatedAt=logical.updatedAt,life=current.save_life,kind="primary"},
       pending=false,continued=true,retired=true,entryArchive=plan,protected=true,gameplayAuthorized=false,
       retiredState={rawRest=Json.copy(raw),anchor=Json.copy(anchor),current=Json.copy(current)}}
      freeze(out);return out,nil
     end
     if not current.checkpoint then return nil,"retired recovery requires explicit New Life" end
     local currentWhy=currentFormat.check(slot,current,context);if currentWhy then return nil,currentWhy end
     local out={record=Json.copy(current.checkpoint),identity={checksum=logical.checksum,updatedAt=logical.updatedAt,life=current.save_life,kind="primary"},
      pending=false,continued=true,entryArchive=plan,protected=true,gameplayAuthorized=false}
     freeze(out);return out,nil
    end
   end
  end
  if requestedKind~=nil and requestedKind~=payload.source.kind then return nil,"pending proposal selected a different original" end
  if not same(raw,plan.entries[slot].raw) and not same(raw,anchor.target) then return nil,"current rest differs from original and pending target" end
  selectedRaw=plan.entries[slot].raw
 end
 local ok,value=pcall(codec.decode,codec,selectedRaw,true);if not ok then return nil,tostring(value) end
 local header={kind=SaveRest.SPECS[slot].kind,current=SaveRest.SCHEMA,migrations={[1]=function(p:any):any return p end},validate=function(p:any):(any,any) return {},p end}
 local opened=Envelope.open(header,value);local selected=if kind=="backup" then opened.backup else opened
 local core=if kind=="backup" and type(value)=="table" then value.backup else value
 if not selected or (selected.status~="ok" and selected.status~="migrated") or type(core)~="table" then return nil,"selected original is unavailable" end
 local capsule,why=Life.prepare(selected.payload,context,"A1_"..user);if not capsule then return nil,why end
 if capsule.origin.world~="test_garden" then return nil,"ordinary Preserve save uses the normal reader" end
 local rules=selected.payload.life_rules
 if type(rules)~="table" or rules.mode~=(if slot=="free" then "free" else "main") or slot=="easy" and rules.rules~="gentle" then return nil,"original life and slot disagree" end
 if anchor~=nil then
  if pendingSource.checksum~=core.checksum or pendingSource.updatedAt~=selected.updatedAt or pendingSource.schema~=core.schema then return nil,"pending original identity differs" end
 end
 local out={record=Json.copy(selected.payload),identity={checksum=core.checksum,updatedAt=selected.updatedAt,life=selected.payload.save_life,kind=kind},
  pending=anchor~=nil,archivePlan=plan,protected=true,gameplayAuthorized=false}
 freeze(out);return out,nil
end
function Reader.new(session:any,codec:any,context:any,options:any?,currentFormat:any?):any
 local cfg=options or {};local timeout=cfg.timeout or 300;local maxRequests=cfg.maxRequests or 16
 assert(type(session.backend.readRawFresh)=="function","uncached raw reads required")
 assert(finite(timeout) and timeout>=1 and timeout<=300 and finite(maxRequests) and maxRequests>=1 and maxRequests<=16 and maxRequests%1==0,"invalid offer reader limits")
 return setmetatable({session=session,codec=codec,context=context,currentFormat=currentFormat,options=cfg,timeout=timeout,maxRequests=maxRequests,busy=false,current=nil},Reader)
end
local function clean(j:any)
 if j.work then j.work:cancel() end
 j.work,j.raw,j.anchor,j.parts=nil,nil,nil,nil
end
local function stop(j:any,state:string,why:string) j.state,j.problem=state,why;clean(j) end
function Reader.begin(self:any,mode:string,kind:string?):(any?,string?)
 local s=self.session
 if not table.find(Rules.MODES,mode) or kind~=nil and kind~="primary" and kind~="backup" then return nil,"invalid recovery offer request" end
 local user=tostring(s.cfg.userId)
 if not owner(user) or s.rkey[mode]~="R_"..user.."_"..mode or s.pkey~="P_"..user then return nil,"invalid server recovery key scope" end
 if self.busy or s.busy or s.closed or s.state~="active" or not s.lockHeld or not s.offersEnabled or self.current and self.current.state=="pending" then return nil,"offer reader unavailable" end
 local j:any={state="pending",phase="rest",mode=mode,kind=kind,started=s.now(),nextAt=s.now(),requests=0,failures=0,parts={},
  load=s._loadSerial,backend=s.backend,observations=s.observations,intents=s.intents,scheduler=s.sched,sessionId=s.id,user=tostring(s.cfg.userId),
  latest=s.observations.latest[mode],choice=s.observations.choices[mode],request=s.intents.requests[mode],rkey=s.rkey[mode],pkey=s.pkey}
 self.current=j
 j.guard=function()
  return self.current==j and j.state=="pending" and not s.closed and s.state=="active" and s.lockHeld and s.offersEnabled
   and s._loadSerial==j.load and s.backend==j.backend and s.observations==j.observations and s.intents==j.intents and s.sched==j.scheduler
   and s.id==j.sessionId and tostring(s.cfg.userId)==j.user and s.rkey[mode]==j.rkey and s.pkey==j.pkey and s.observations.latest[mode]==j.latest
   and s.observations.choices[mode]==j.choice and s.intents.requests[mode]==j.request
 end
 return j,nil
end
function Reader.cancel(self:any,j:any):boolean
 if self.current~=j or j.state~="pending" then return false end
 stop(j,"cancelled","recovery offer cancelled");return true
end
-- Consumed only after Runtime binds the actual selected Continue. The plan was
-- built from this reader's uncached full publication; it never crosses the wire.
function Reader.takeContinuedArchive(self:any,j:any):any?
 if Work.pulse() or self.current~=j or j.state~="offered" or not j.continued or not j.entryArchive then return nil end
 local plan=j.entryArchive;j.entryArchive=nil;return plan
end
function Reader.takeRetiredState(self:any,j:any):any?
 if Work.pulse() or self.current~=j or j.state~="offered" or not j.retired or not j.retiredState then return nil end
 local state=j.retiredState;j.retiredState=nil;return state
end
local function prepare(self:any,j:any)
 j.work=Work.new(function() return Reader.prepare(j.user,j.mode,j.raw,j.anchor,j.parts,self.codec,self.context,j.kind,self.currentFormat,self.options.retiredNewLife==true) end,self.options.work);j.phase="prepare"
end
local function stepInner(self:any,j:any):boolean
 local s=self.session;local now=s.now()
 if not j.guard() then stop(j,"cancelled","session/offer/intent changed");return false end
 if not finite(now) or now-j.started>=self.timeout then stop(j,"refused","offer reader deadline reached");return false end
 if j.work then
  j.work:step()
  if not j.guard() then stop(j,"cancelled","session/offer/intent changed");return false end
  if j.work.state=="pending" then return false end
  local result=j.work:take();j.work=nil
  if not result or not result[1] then stop(j,"refused",if result then tostring(result[2]) else "offer preparation failed");return false end
  local found=result[1];local offer=s.observations:publish(j.mode,found.record,found.identity,true)
  if not offer then stop(j,"refused","protected offer publication refused");return false end
  j.offer,j.archivePlan,j.pending,j.continued=offer,found.archivePlan,found.pending,found.continued==true
  j.entryArchive=found.entryArchive;j.retired=found.retired==true;j.retiredState=found.retiredState
  j.identity=table.freeze(Json.copy(found.identity));j.state,j.problem="offered",nil;clean(j)
  -- No callbacks before the observation is stable and staging has been released.
  if s.cfg.onOffer then pcall(s.cfg.onOffer,j.mode,offer) end
  return false
 end
 if now<j.nextAt or not s.sched:budgetOk(now) then return false end
 if j.requests>=self.maxRequests then stop(j,"refused","offer reader request cap reached");return false end
 local key=if j.phase=="rest" then s.rkey[j.mode] elseif j.phase=="proposal" then "M1_"..j.user.."_"..j.mode else "A1_"..j.user.."_"..j.phase
 s.sched:begin(nil,now);s.counters.requests+=1;j.requests+=1
 local called,ok,value,why=pcall(s.backend.readRawFresh,s.backend,key)
 if not j.guard() then stop(j,"cancelled","session/offer/intent changed");return true end
 if not called or ok~=true then j.failures+=1;j.nextAt=now+Scheduler.backoff(j.failures,Stores.classify(tostring(if called then why else ok)));return true end
 -- A real backend returns an isolated owned value. CPU preparation performs all
 -- bounds/copying before publication; provider results must remain stable.
 if j.phase=="rest" then j.raw=value;j.phase="proposal"
 elseif j.phase=="proposal" then j.anchor=value;if value==nil then prepare(self,j) else j.phase="progress" end
 else
  j.parts[j.phase]=value
  local order={progress="main",main="free",free="easy",easy="index"}
  if j.phase=="index" then prepare(self,j) else j.phase=order[j.phase] end
 end
 j.failures=0;j.nextAt=now;return true
end
function Reader.step(self:any,j:any):boolean
 local s=self.session
 if self.current~=j or j.state~="pending" or self.busy or s.busy then return false end
 self.busy=true;s.busy=true;local ok,asked=pcall(stepInner,self,j);self.busy=false;s.busy=false
 if not ok then stop(j,"refused",tostring(asked));return false end
 return asked
end
return table.freeze(Reader)
