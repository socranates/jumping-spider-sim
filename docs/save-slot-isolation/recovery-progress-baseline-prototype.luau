--!strict
-- Private backend sidecar. Capture the session's acknowledged P baseline before
-- recovery writes change storage without adopting those changes into memory.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Json=require(Shared.Persistence.Json)
local SaveRest=require(Shared.Persistence.SaveRest)
local Rules=require(Shared.Data.SaveRules)
local Work=require(Shared.Persistence.SaveWork)
local Baseline={};Baseline.__index=Baseline
local function same(a:any,b:any):boolean
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b and (type(a)~="number" or a~=0 or 1/a==1/b) end
 if getmetatable(b)~=nil then return false end
 for k,v in a do if not same(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
local function freeze(v:any)
 if type(v)~="table" then return end
 for _,x in v do freeze(x) end
 if not table.isfrozen(v) then table.freeze(v) end
end
function Baseline.new(backend:any,user:string):any
 assert(type(user)=="string" and #user>0 and #user<=32 and string.match(user,"^[%w_-]+$"),"invalid baseline owner")
 assert(type(backend.update)=="function" and type(backend.readRawFresh)=="function" and type(backend.readFresh)=="function" and type(backend.read)=="function","baseline needs guarded update and explicit reads")
 return setmetatable({source=backend,boundSource=backend,user=user,pkey="P_"..user,issued=0,acknowledged=0,activeUpdates=0,base=nil,held=nil,
  permits=setmetatable({},{__mode="k"}),main={}},Baseline)
end
local function updateProvider(self:any,key:string,fn:any,raw:boolean?):(boolean,any,string?)
 self.activeUpdates+=1
 local method=if raw then self.source.updateRaw else self.source.update
 local result=table.pack(pcall(method,self.source,key,fn));self.activeUpdates-=1
 if not result[1] then return false,nil,tostring(result[2]) end
 return table.unpack(result,2,result.n)
end
local function authorized(self:any,key:string):boolean
 local held=self.held
 if held==nil or not held.enforced or (key~=self.pkey and string.sub(key,1,#self.user+3)~="R_"..self.user.."_") then return true end
 return self:permitted(held)
end
function Baseline.read(self:any,key:string):(boolean,any,string?)
 if self.source~=self.boundSource then return false,nil,"backend provider changed" end
 return self.source:read(key)
end
function Baseline.readFresh(self:any,key:string):(boolean,any,string?)
 if self.source~=self.boundSource then return false,nil,"backend provider changed" end
 return self.source:readFresh(key)
end
function Baseline.readRawFresh(self:any,key:string):(boolean,any,string?)
 if self.source~=self.boundSource then return false,nil,"backend provider changed" end
 return self.source:readRawFresh(key)
end
function Baseline.updateRaw(self:any,key:string,fn:any):(boolean,any,string?)
 if self.source~=self.boundSource then return false,nil,"backend provider changed" end
 if not authorized(self,key) then return false,nil,"recovery owner required for this save" end
 if type(self.source.updateRaw)~="function" then return false,nil,"raw update adapter unavailable" end
 return updateProvider(self,key,fn,true)
end
function Baseline.update(self:any,key:string,fn:any):(boolean,any,string?)
 if self.source~=self.boundSource then return false,nil,"backend provider changed" end
 if not authorized(self,key) then return false,nil,"recovery owner required for this save" end
 if key~=self.pkey then return updateProvider(self,key,fn) end
 self.issued+=1;local serial=self.issued;local candidate:any=nil
 local ok,value,why=updateProvider(self,key,function(old:any):any candidate=nil;candidate=fn(old);return candidate end)
 -- Observe only an exact positively acknowledged result; neither a discarded
 -- callback candidate nor a lost acknowledgement can advance the baseline.
 if ok and type(candidate)=="table" and type(value)=="table" and serial>self.acknowledged
  and not SaveRest.bounded(candidate,Rules.MAX_PROGRESS_NODES*2+64,Rules.MAX_DEPTH+2)
  and not SaveRest.bounded(value,Rules.MAX_PROGRESS_NODES*2+64,Rules.MAX_DEPTH+2) and same(candidate,value) then
  local text=Json.canonical(value)
  if text and #text<=Rules.MAX_VALUE_CHARS then
   local owned=Json.copy(value);freeze(owned);self.acknowledged=serial;self.latest=owned
   if self.held==nil then self.base=owned end
  end
 end
 return ok,value,why
end
function Baseline.hold(self:any,session:any,enforced:boolean?):(any?,string?)
 if Work.pulse() then return nil,"baseline hold must run outside preparation" end
 if self.source~=self.boundSource or self.held~=nil or self.base==nil or session.backend~=self or tostring(session.cfg.userId)~=self.user or session.state~="active" or not session.lockHeld then return nil,"acknowledged session baseline unavailable" end
 local ticket={owner=self,session=session,base=self.base,load=session._loadSerial,used=false,enforced=enforced==true}
 self.held=ticket;return ticket,nil
end
function Baseline.valid(self:any,ticket:any):boolean
 return self.source==self.boundSource and type(ticket)=="table" and self.held==ticket and ticket.owner==self and not ticket.used and ticket.session.backend==self and ticket.session._loadSerial==ticket.load
  and not ticket.session.closed and ticket.session.state=="active" and ticket.session.lockHeld
end
function Baseline.permitted(self:any,ticket:any):boolean
 return self:valid(ticket) and self.permits[coroutine.running() or self.main]==ticket
end
-- Scoped permits survive native yields on their own coroutine, never authorizing
-- an unrelated caller. A failed callback restores the previous permit too.
function Baseline.run(self:any,ticket:any,fn:any):...any
 if not self:valid(ticket) or type(fn)~="function" then return false,"recovery baseline scope unavailable" end
 local co=coroutine.running() or self.main;local prior=self.permits[co];self.permits[co]=ticket
 local result=table.pack(pcall(fn));self.permits[co]=prior
 return table.unpack(result,1,result.n)
end
-- Called only by the atomic local rebind after its guards pass. Default holds
-- track history; enforcing holds additionally require a scoped run for writes.
function Baseline.adopt(self:any,ticket:any,raw:any):boolean
 if not self:valid(ticket) or type(raw)~="table" or not table.isfrozen(raw) then return false end
 self.base=raw;self.held=nil;ticket.used=true;return true
end
-- Departure is a distinct, closed scope. It cannot revive a recovery permit or
-- enable the ordinary worker, and can touch only this owner's progress key.
function Baseline.sealDeparture(self:any,session:any,owner:any):(any?,string?)
 if Work.pulse() then return nil,"departure must run outside preparation" end
 local held=self.held
 if type(owner)~="table" or self.departure~=nil or not self:valid(held) or held.session~=session or not held.enforced
  or session.recoveryOwner~=owner or owner.session~=session then return nil,"current enforced recovery owner required" end
 local ticket={owner=self,session=session,recovery=owner,held=held,base=held.base,load=session._loadSerial,id=session.id,used=false}
 -- All public session intake/load/flush paths check closed before proceeding.
 -- Already-issued calls may finish; the departure owner drains them before
 -- capturing final local progress or making another request.
 session.closed,session.flushing=true,true;self.departure=ticket
 return ticket,nil
end
function Baseline.departureValid(self:any,t:any):boolean
 return type(t)=="table" and self.departure==t and t.owner==self and not t.used and self.held==t.held
  and self.source==self.boundSource and t.session.backend==self and t.session._loadSerial==t.load and t.session.id==t.id
  and t.session.closed and t.session.flushing and t.session.state=="active" and t.session.lockHeld
  and t.session.recoveryOwner==t.recovery and t.session.pkey==self.pkey and tostring(t.session.cfg.userId)==self.user
end
function Baseline.departureUpdate(self:any,t:any,fn:any):(boolean,any,string?)
 if Work.pulse() or not self:departureValid(t) then return false,nil,"closed departure scope unavailable" end
 return updateProvider(self,self.pkey,function(old:any):any
  if not self:departureValid(t) then return nil end
  return fn(old)
 end)
end
function Baseline.departureRead(self:any,t:any):(boolean,any,string?)
 if Work.pulse() or not self:departureValid(t) then return false,nil,"closed departure scope unavailable" end
 return self.source:readRawFresh(self.pkey)
end
function Baseline.finishDeparture(self:any,t:any,released:boolean):boolean
 if self.departure~=t or t.used then return false end
 t.used=true;t.session.flushing=false
 if released then t.session.lockHeld=false end
 return true -- closed and the enforced hold deliberately remain in place
end
return table.freeze(Baseline)
