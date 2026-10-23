--!strict
-- Private recovery admission only. Never grants a life credential, writes a key,
-- renews a lease or authorizes destination replacement. Not wired to production.
local Rules=require(script.Parent.Parent.Data.SaveRules)
local Json=require(script.Parent.Json)
local Fence={}
local function finite(v:any):boolean return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function same(a:any,b:any):boolean
 return type(a)=="table" and type(b)=="table" and a.checksum==b.checksum and a.updatedAt==b.updatedAt and a.life==b.life and a.kind==b.kind
end
function Fence.capture(s:any,mode:string,serial:number,offerId:string):(any?,string?)
 if not table.find(Rules.MODES,mode) or s.closed or s.busy or s.state~="active" or not s.lockHeld or not s.offersEnabled then return nil,"session unavailable" end
 local now=s.now();local beat=s.sched.lastBeat
 if not finite(now) or not finite(beat) or now<beat or now-beat>=Rules.LOCK_STALE then return nil,"lease observation expired" end
 local r=s.intents.requests[mode];local choice=s.observations:selection(mode)
 if not r or r.kind~="continue" or r.serial~=serial or r.offerId~=offerId or r.state~="readonly" or r.credential~=nil
  or not choice or choice.id~=offerId or choice.serial~=serial or not same(choice.identity,r.base) then return nil,"selected Continue changed" end
 if s.restPending[mode]~=nil or s.lifeRequests[mode]~=nil then return nil,"destination work already pending" end
 -- Copy only fixed metadata, never a client supplied checkpoint or a full world.
 local id=table.freeze(Json.copy(choice.identity))
 local ticket={session=s,mode=mode,serial=serial,offerId=offerId,request=r,revision=r.revision,
  load=s._loadSerial,backend=s.backend,scheduler=s.sched,observations=s.observations,intents=s.intents,
  sessionId=s.id,owner=tostring(s.cfg.userId),pkey=s.pkey,rkey=s.rkey[mode],identity=id,
  protected=choice.protected,reason=r.reason,needsCheck=r.needsCheck,lastNow=now,cancelled=false}
 return ticket,nil
end
function Fence.cancel(t:any) t.cancelled=true end
local function current(t:any):boolean
 if t.cancelled then return false end
 local s=t.session;local r=t.request
 if s.closed or s.state~="active" or not s.lockHeld or not s.offersEnabled or s._loadSerial~=t.load
  or s.backend~=t.backend or s.sched~=t.scheduler or s.observations~=t.observations or s.intents~=t.intents
  or s.id~=t.sessionId or tostring(s.cfg.userId)~=t.owner or s.pkey~=t.pkey or s.rkey[t.mode]~=t.rkey
  or s.intents.requests[t.mode]~=r or r.kind~="continue" or r.state~="readonly" or r.credential~=nil
  or r.serial~=t.serial or r.offerId~=t.offerId or r.revision~=t.revision or r.reason~=t.reason or r.needsCheck~=t.needsCheck
  or not same(r.base,t.identity) or s.restPending[t.mode]~=nil or s.lifeRequests[t.mode]~=nil then return false end
 local now=s.now();local beat=s.sched.lastBeat
 if not finite(now) or not finite(beat) or now<t.lastNow or now<beat or now-beat>=Rules.LOCK_STALE then return false end
 t.lastNow=now
 local choice=s.observations:selection(t.mode)
 return choice~=nil and choice.serial==t.serial and choice.id==t.offerId and choice.protected==t.protected and same(choice.identity,t.identity)
end
function Fence.valid(t:any):boolean
 if t.cancelled then return false end
 local ok,allowed=pcall(current,t)
 if not ok or not allowed then t.cancelled=true;return false end
 return true
end
-- Called on an already bounded/frozen collector plan, before publication.
-- Does not claim current remote ownership: another server may take the lease
-- after these reads. A destination CAS still needs its own ownership fence.
function Fence.matchesPlan(t:any,plan:any):boolean
 if not Fence.valid(t) or type(plan)~="table" or type(plan.index)~="table" or plan.index.owner~=t.owner or type(plan.entries)~="table" then return false end
 local p=plan.entries.progress;local rest=plan.entries[t.mode]
 if type(p)~="table" or type(p.raw)~="table" or type(p.raw.lock)~="table" or type(rest)~="table" or type(rest.raw)~="table" then return false end
 local lock=p.raw.lock;local now=t.session.now()
 if lock.session~=t.sessionId or not finite(lock.beat) or now<lock.beat or now-lock.beat>=Rules.LOCK_STALE then return false end
 local source=if t.identity.kind=="backup" then rest.raw.backup else rest.raw
 return type(source)=="table" and source.checksum==t.identity.checksum and source.updatedAt==t.identity.updatedAt
  and type(source.payload)=="table" and source.payload.save_life==t.identity.life
end
return table.freeze(Fence)
