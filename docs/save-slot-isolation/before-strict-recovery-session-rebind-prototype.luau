--!strict
-- Private local adoption after storage verification. No backend calls, schema-3
-- entry, world mutation or life/write credential is issued by this helper.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Progress=require(Shared.Persistence.SaveProgress)
local Projection=require(Shared.Persistence.RecoveryProgressPrototype)
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local Fence=require(Shared.Persistence.RecoverySessionFencePrototype)
local Packet=require(script.Parent.RecoveryPacketPrototype)
local SaveRest=require(Shared.Persistence.SaveRest)
local Rebind={}
local plans:any=setmetatable({},{__mode="k"})
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
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
local function known(v:any,fields:any):boolean
 if type(v)~="table" or getmetatable(v)~=nil then return false end
 for k in v do if not fields[k] then return false end end
 return true
end
function Rebind.capture(session:any,baseline:any,mode:string,serial:number,offerId:string):(any?,string?)
 if Work.pulse() then return nil,"capture must run outside preparation" end
 if type(baseline)~="table" or type(baseline.owner)~="table" or not baseline.owner:valid(baseline) or baseline.session~=session then return nil,"held baseline required" end
 local fence,why=Fence.capture(session,mode,serial,offerId);if not fence then return nil,why end
 local ticket={session=session,baseline=baseline,fence=fence,progress=session.progress,time=session.progressTime,
  version=session.sched.items.progress.version,issued=baseline.owner.issued,used=false}
 return ticket,nil
end
function Rebind.valid(t:any):boolean
 local s=t.session
 return not t.used and t.baseline.owner:valid(t.baseline) and t.baseline.owner.issued==t.issued and Fence.valid(t.fence)
  and not s.flushing and s.progress==t.progress and s.progressTime==t.time and s.sched.items.progress.version==t.version
end
function Rebind.prepare(t:any,anchor:any,rawProgress:any,rawRest:any,codec:any,context:any):(any?,string?)
 if not Rebind.valid(t) then return nil,"session changed before rebind preparation" end
 local s=t.session;local payload,why=Packet.open(anchor,codec,context);if not payload then return nil,why end
 local identity=t.fence.identity
 if anchor.owner~=t.fence.owner or anchor.slot~=t.fence.mode or not same(rawRest,anchor.target)
  or payload.source.kind~=identity.kind or payload.source.checksum~=identity.checksum or payload.source.updatedAt~=identity.updatedAt
  or payload.save_life~=identity.life then return nil,"selected recovered target differs" end
 local now=s.now()
 if not known(rawProgress,{format=true,kind=true,schema=true,updatedAt=true,payload=true,checksum=true,backup=true,lock=true,session=true})
  or not known(rawProgress.lock,{session=true,beat=true}) or rawProgress.lock.session~=s.id
  or not finite(now) or not finite(rawProgress.lock.beat) or now<rawProgress.lock.beat or now-rawProgress.lock.beat>=Rules.LOCK_STALE then return nil,"owned fresh progress observation required" end
 local covered,problem=Projection.mergePending(rawProgress,payload.progress,payload.progressTime)
 if not covered or covered.changed then return nil,problem or "pending global proposal has not been absorbed" end
 -- Three-way choice merge. Only values changed from the acknowledged pre-
 -- recovery baseline are local choices; unchanged stale fields must not replay.
 local base,errorText=Projection.mergePending(t.baseline.base,Progress.default(),t.baseline.base.updatedAt);if not base then return nil,errorText end
 if SaveRest.bounded(t.progress,Rules.MAX_PROGRESS_NODES,Rules.MAX_DEPTH) then return nil,"local progress exceeds bound" end
 local current,currentError=Projection.mergePending(Envelope.make(Progress.SPEC,t.progress,t.time,nil),Progress.default(),t.time)
 if not current then return nil,currentError end
 local delta=Json.copy(current.progress);delta.settings={};delta.appearance=nil
 for key,value in current.progress.settings do if base.progress.settings[key]~=value then delta.settings[key]=value end end
 if current.progress.appearance~=base.progress.appearance then delta.appearance=current.progress.appearance end
 local merged,mergeError=Projection.mergePending(rawProgress,delta,t.time);if not merged then return nil,mergeError end
 if t.time==rawProgress.updatedAt then
  for key,value in delta.settings do merged.progress.settings[key]=value end
  if delta.appearance~=nil then merged.progress.appearance=delta.appearance end
 end
 local text=Json.canonical(merged.progress);if not text or #text>Packet.MAX_PROGRESS_CHARS then return nil,"rebound progress exceeds budget" end
 local opened=Envelope.open(Progress.SPEC,rawProgress,false)
 local dirty=not Progress.same(merged.progress,opened.payload)
 local plan={progress=merged.progress,progressTime=if dirty then math.max(t.time,rawProgress.updatedAt) else rawProgress.updatedAt,
  rawProgress=Json.copy(rawProgress),dirty=dirty,checkpoint=Json.copy(payload.checkpoint),entryKind=payload.entryKind,save_life=payload.save_life}
 freeze(plan)
 if not Rebind.valid(t) then return nil,"session changed during rebind preparation" end
 plans[plan]=t;return plan,nil
end
function Rebind.apply(plan:any):(boolean,any)
 local t=plans[plan];if not t then return false,"unknown or consumed rebind plan" end
 if Work.pulse() then return false,"rebind application must run outside preparation" end
 plans[plan]=nil
 if not Rebind.valid(t) then return false,"session changed before rebind application" end
 local s=t.session;local now=s.now();local beat=plan.rawProgress.lock.beat
 if not finite(now) or now<beat or now-beat>=Rules.LOCK_STALE then return false,"progress observation expired" end
 if not t.baseline.owner:adopt(t.baseline,plan.rawProgress) then return false,"baseline ownership changed" end
 -- No yielding call or callback between the final checks and these assignments.
 s.progress=plan.progress;s.progressTime=plan.progressTime;s.storedTime=plan.rawProgress.updatedAt
 if plan.dirty then if not s.sched:isDirty("progress") then s.sched:markDirty("progress",now) end
 else s.sched:succeeded("progress",now,t.version) end
 t.used=true;Fence.cancel(t.fence)
 return true,{checkpoint=plan.checkpoint,entryKind=plan.entryKind,save_life=plan.save_life,requiresSchema3Entry=true,gameplayAuthorized=false}
end
return table.freeze(Rebind)
