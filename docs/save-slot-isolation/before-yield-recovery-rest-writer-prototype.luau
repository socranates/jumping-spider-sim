--!strict
-- Private exact selected-R CAS, not a complete multi-key transaction. Verified
-- A1 publication and remote lease/intent integration are separate prerequisites.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local Archive=require(Shared.Persistence.RecoveryArchivePrototype)
local Packet=require(script.Parent.RecoveryPacketPrototype)
local Writer={};Writer.__index=Writer
local prepared:any=setmetatable({},{__mode="k"})
local function freeze(v:any)
 if type(v)~="table" then return end
 for _,x in v do freeze(x) end
 if not table.isfrozen(v) then table.freeze(v) end
end
local function same(a:any,b:any):boolean
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b and (type(a)~="number" or a~=0 or 1/a==1/b) end
 if getmetatable(b)~=nil then return false end
 for k,v in a do if not same(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
-- Pure preparation can run under SaveWork; caller inputs must remain stable.
-- A prepared handle owns its data and is not a lease/archive-durability token.
function Writer.prepare(archive:any,anchor:any,codec:any,context:any):(any?,string?)
 local valid,why=Archive.check(archive);if not valid then return nil,why end
 local payload,problem=Packet.open(anchor,codec,context);if not payload then return nil,problem end
 local slot=anchor.slot;local entry=archive.entries[slot]
 if anchor.owner~=archive.index.owner or anchor.archive~=archive.index.checksum or not entry.present
  or anchor.source~=entry.checksum or payload.archive.progress~=archive.entries.progress.checksum then return nil,"proposal/archive source differs" end
 local plan={key="R_"..anchor.owner.."_"..slot,expected=Json.copy(entry.raw),anchor=Json.copy(anchor)}
 freeze(plan);prepared[plan]=true;return plan,nil
end
function Writer.new(backend:any):any
 assert(type(backend.updateRaw)=="function" and type(backend.readRawFresh)=="function","exact raw update and uncached raw readback required")
 return setmetatable({backend=backend},Writer)
end
local function live(j:any):boolean
 if j.state=="cancelled" then return false end
 local ok,result=pcall(j.fence);return ok and result==true and j.state~="cancelled"
end
local function refuse(j:any,why:string)
 if j.state~="cancelled" then j.state,j.problem="refused",why end
end
function Writer.begin(self:any,plan:any,fence:any):(any?,string?)
 if Work.pulse() then return nil,"rest writing must run outside preparation" end
 if not prepared[plan] or type(fence)~="function" then return nil,"owned preparation and fence required" end
 return {repository=self,plan=plan,fence=fence,state="pending",phase="proposal",requests=0},nil
end
function Writer.cancel(self:any,j:any):boolean
 if j.repository~=self or j.state=="restVerified" or j.state=="cancelled" then return false end
 j.state,j.problem="cancelled","rest replacement cancelled";return true
end
function Writer.retry(self:any,j:any):boolean
 if j.repository~=self or j.state~="retry" then return false end
 if not live(j) then refuse(j,"rest authority/source changed");return false end
 j.state,j.phase,j.problem="pending","proposal",nil;return true
end
function Writer.step(self:any,j:any):boolean
 if j.repository~=self or j.state~="pending" then return false end
 if Work.pulse() then refuse(j,"rest writing must run outside preparation");return false end
 if not live(j) then refuse(j,"rest authority/source changed");return false end
 j.state="running";j.requests+=1
 local p=j.plan
 if j.phase=="write" then
  local called,ok,_value,why=pcall(self.backend.updateRaw,self.backend,p.key,function(old:any):any
   if not live(j) then return nil end
   if same(p.anchor.target,old) then return nil end
   if same(p.expected,old) then return p.anchor.target end
   return nil
  end)
  if (j.state::string)=="cancelled" then return false end
  if not live(j) then refuse(j,"rest authority/source changed");return false end
  j.lastWriteError=if called and ok==true then nil else tostring(if called then why else ok)
  j.state,j.phase="pending","readback";return true
 end
 local key=if j.phase=="proposal" then p.anchor.id else p.key
 local called,ok,value,why=pcall(self.backend.readRawFresh,self.backend,key)
 if (j.state::string)=="cancelled" then return false end
 if not live(j) then refuse(j,"rest authority/source changed");return false end
 if not called or ok~=true then j.state,j.problem="retry",tostring(if called then why else ok);return false end
 if j.phase=="proposal" then
  if not same(p.anchor,value) then refuse(j,"immutable proposal missing or different");return false end
  j.state,j.phase="pending","write";return true
 end
 if same(p.anchor.target,value) then j.state,j.problem="restVerified",nil;return true end
 if same(p.expected,value) then j.state,j.problem="retry",j.lastWriteError or "original rest remains; explicit backoff/retry required";return false end
 refuse(j,"selected rest changed; no replacement authorized");return false
end
return table.freeze(Writer)
