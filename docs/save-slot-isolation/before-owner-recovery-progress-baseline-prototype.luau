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
 return setmetatable({source=backend,user=user,pkey="P_"..user,issued=0,acknowledged=0,base=nil,held=nil},Baseline)
end
function Baseline.read(self:any,key:string):(boolean,any,string?) return self.source:read(key) end
function Baseline.readFresh(self:any,key:string):(boolean,any,string?) return self.source:readFresh(key) end
function Baseline.readRawFresh(self:any,key:string):(boolean,any,string?) return self.source:readRawFresh(key) end
function Baseline.updateRaw(self:any,key:string,fn:any):(boolean,any,string?)
 if type(self.source.updateRaw)~="function" then return false,nil,"raw update adapter unavailable" end
 return self.source:updateRaw(key,fn)
end
function Baseline.update(self:any,key:string,fn:any):(boolean,any,string?)
 if key~=self.pkey then return self.source:update(key,fn) end
 self.issued+=1;local serial=self.issued;local candidate:any=nil
 local ok,value,why=self.source:update(key,function(old:any):any candidate=nil;candidate=fn(old);return candidate end)
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
function Baseline.hold(self:any,session:any):(any?,string?)
 if Work.pulse() then return nil,"baseline hold must run outside preparation" end
 if self.held~=nil or self.base==nil or session.backend~=self or tostring(session.cfg.userId)~=self.user or session.state~="active" or not session.lockHeld then return nil,"acknowledged session baseline unavailable" end
 local ticket={owner=self,session=session,base=self.base,load=session._loadSerial,used=false}
 self.held=ticket;return ticket,nil
end
function Baseline.valid(self:any,ticket:any):boolean
 return type(ticket)=="table" and self.held==ticket and ticket.owner==self and not ticket.used and ticket.session.backend==self and ticket.session._loadSerial==ticket.load
end
-- Called only by the atomic local rebind after its guards pass. Holding is not
-- a write lock; the integration owner must pause ordinary session work meanwhile.
function Baseline.adopt(self:any,ticket:any,raw:any):boolean
 if not self:valid(ticket) or type(raw)~="table" or not table.isfrozen(raw) then return false end
 self.base=raw;self.held=nil;ticket.used=true;return true
end
return table.freeze(Baseline)
