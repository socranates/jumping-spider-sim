--!strict
-- Private P absorption only. No life/gameplay grant or cross-key atomicity.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local Rules=require(Shared.Data.SaveRules)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Progress=require(Shared.Persistence.SaveProgress)
local SaveRest=require(Shared.Persistence.SaveRest)
local Projection=require(Shared.Persistence.RecoveryProgressPrototype)
local Packet=require(script.Parent.RecoveryPacketPrototype)
local Operation=require(Shared.Persistence.RecoveryOperationAdmission)
local Writer={};Writer.__index=Writer
local prepared:any=setmetatable({},{__mode="k"})
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
function Writer.prepare(anchor:any,codec:any,context:any):(any?,string?)
 local payload,why=Packet.open(anchor,codec,context);if not payload then return nil,why end
 local plan={anchor=Json.copy(anchor),progress=Json.copy(payload.progress),progressTime=payload.progressTime,
  pkey="P_"..anchor.owner,rkey="R_"..anchor.owner.."_"..anchor.slot}
 freeze(plan);prepared[plan]=true;return plan,nil
end
function Writer.new(backend:any,session:string,now:()->number,admission:any?):any
 assert(type(backend.update)=="function" and type(backend.readRawFresh)=="function","guarded update/uncached readback required")
 assert(type(session)=="string" and #session>0 and #session<=256 and type(now)=="function","session/clock required")
 if admission then assert(backend==admission.session.backend and session==admission.session.id,"typed progress backend/epoch mismatch") end
 return setmetatable({backend=backend,session=session,now=now,admission=admission},Writer)
end
local function live(j:any):boolean
 if j.state=="cancelled" then return false end
 local ok,result=pcall(j.fence);return ok and result==true and j.state~="cancelled"
end
local function refuse(j:any,why:string)
 if j.state~="cancelled" then j.state,j.problem="refused",why end
 if j.io then j.io:cancel();j.io=nil end;j.writeState=nil
end
local function merged(self:any,plan:any,raw:any):(any?,string?)
 if SaveRest.bounded(raw,Rules.MAX_PROGRESS_NODES*2+64,Rules.MAX_DEPTH+2) then return nil,"progress envelope exceeds bound" end
 if not known(raw,{format=true,kind=true,schema=true,updatedAt=true,payload=true,checksum=true,backup=true,lock=true,session=true})
  or not known(raw.lock,{session=true,beat=true}) then return nil,"unsupported progress envelope/lock" end
 local now=self.now();local lock=raw.lock
 if not finite(now) or not finite(lock.beat) or lock.session~=self.session or now<lock.beat or now-lock.beat>=Rules.LOCK_STALE then return nil,"fresh owned progress lease required" end
 local result,why=Projection.mergePending(raw,plan.progress,plan.progressTime);if not result then return nil,why end
 local text=Json.canonical(result.progress)
 if not text or #text>Packet.MAX_PROGRESS_CHARS or SaveRest.bounded(result.progress,Rules.MAX_PROGRESS_NODES,Rules.MAX_PROGRESS_DEPTH) then return nil,"merged progress exceeds packet budget" end
 return result,nil
end
function Writer.begin(self:any,plan:any,fence:any):(any?,string?)
 if Work.pulse() then return nil,"progress writing must run outside preparation" end
 if not prepared[plan] or type(fence)~="function" then return nil,"owned preparation and fence required" end
 local j:any={repository=self,plan=plan,fence=fence,state="pending",phase="proposal",requests=0}
 if self.admission then
  local ctx=self.admission;assert(plan.anchor.owner==tostring(ctx.session.cfg.userId),"typed progress account mismatch")
  local rows={};for _,row in ctx.rows do table.insert(rows,row) end;table.insert(rows,{object=j,field="requests",max=ctx.maxRequests})
  j.io=Operation.new(ctx.session,ctx.lane,function() return (j.state=="pending" or j.state=="running") and live(j) end,rows,nil,{object=j,field="state",value="running"})
 end
 return j,nil
end
function Writer.cancel(self:any,j:any):boolean
 if j.repository~=self or j.state=="globalVerified" or j.state=="cancelled" then return false end
 j.state,j.problem="cancelled","progress absorption cancelled"
 if j.io then j.io:cancel();j.io=nil end;j.writeState=nil;return true
end
function Writer.retry(self:any,j:any):boolean
 if j.repository~=self or j.state~="retry" then return false end
 if not live(j) then refuse(j,"progress intent changed");return false end
 j.state,j.phase,j.problem="pending","proposal",nil;return true
end
function Writer.step(self:any,j:any):boolean
 if j.repository~=self or j.state~="pending" then return false end
 if Work.pulse() then refuse(j,"progress writing must run outside preparation");return false end
 if not live(j) then refuse(j,"progress intent changed");return false end
 if not j.io then j.state="running";j.requests+=1 end;local p=j.plan
 if j.phase=="write" then
  if not j.writeState then
   local evidence:any={}
   evidence.transform=function(old:any):any
   evidence.problem=nil
   if not live(j) then evidence.problem="progress intent changed";return nil end
   local result,problem=merged(self,p,old)
   if not result then evidence.problem=problem;return nil end
   if not result.changed then return nil end
   return Envelope.make(Progress.SPEC,result.progress,result.progressTime,old,{lock=Json.copy(old.lock),session=old.session})
   end
   j.writeState=evidence
  end
  local evidence=j.writeState
  local called,ok,_value,why=true,nil,nil,nil
  if j.io then
   local state,result,asked=j.io:poll("update",p.pkey,evidence.transform)
   if state=="waiting" then return false end
   if state~="done" then refuse(j,"admitted progress write ended");return asked end
   ok,_value,why=table.unpack(result,1,result.n)
  else called,ok,_value,why=pcall(self.backend.update,self.backend,p.pkey,evidence.transform) end
  local finalProblem=evidence.problem;j.writeState=nil
  if (j.state::string)=="cancelled" then return false end
  if not live(j) then refuse(j,"progress intent changed");return false end
  if finalProblem then refuse(j,finalProblem);return false end
  j.lastWriteError=if called and ok==true then nil else tostring(if called then why else ok)
  j.state,j.phase="pending","readback";return true
 end
 local key=if j.phase=="proposal" then p.anchor.id elseif j.phase=="rest" then p.rkey else p.pkey
 local called,ok,value,why=true,nil,nil,nil
 if j.io then
  local state,result,asked=j.io:poll("readRawFresh",key,nil)
  if state=="waiting" then return false end
  if state~="done" then refuse(j,"admitted progress read ended");return asked end
  ok,value,why=table.unpack(result,1,result.n)
 else called,ok,value,why=pcall(self.backend.readRawFresh,self.backend,key) end
 if (j.state::string)=="cancelled" then return false end
 if not live(j) then refuse(j,"progress intent changed");return false end
 if not called or ok~=true then j.state,j.problem="retry",tostring(if called then why else ok);return false end
 if j.phase=="proposal" then
  if not same(p.anchor,value) then refuse(j,"immutable proposal missing or different");return false end
  j.state,j.phase="pending","rest";return true
 elseif j.phase=="rest" then
  if not same(p.anchor.target,value) then refuse(j,"selected recovered rest not verified");return false end
  j.state,j.phase="pending","write";return true
 end
 local result,problem=merged(self,p,value)
 if not result then refuse(j,problem or "progress readback invalid");return false end
 if result.changed then j.state,j.problem="retry",j.lastWriteError or "proposal not yet absorbed; explicit backoff/retry required";return false end
 if not live(j) then refuse(j,"progress intent changed");return false end
 j.state,j.problem="globalVerified",nil;if j.io then j.io:cancel();j.io=nil end;return true
end
return table.freeze(Writer)
