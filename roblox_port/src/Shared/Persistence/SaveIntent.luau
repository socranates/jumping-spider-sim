--!strict
-- Transient server decisions. Identity/lease validation and durable retirement
-- belong to SaveSession; this owner only enforces ordering and credentials.
local Json=require(script.Parent.Json)
local Rules=require(script.Parent.Parent.Data.SaveRules)
local Intent={}
Intent.__index=Intent

local function valid(mode: any,kind: any,serial: any,id: any): boolean
 return type(mode)=="string" and table.find(Rules.MODES,mode)~=nil and (kind=="continue" or kind=="new")
  and type(serial)=="number" and serial==serial and serial>=1 and serial<=Rules.MAX_LIFE_SERIAL and serial==math.floor(serial)
  and ((kind=="new" and id==nil) or (type(id)=="string" and #id>0 and #id<=Rules.MAX_LIFE_TOKEN_CHARS))
end

function Intent.new(owner: string,emit: ((any)->())?): any
 return setmetatable({requests={},prefix=Json.checksum(owner),counter=0,emit=emit},Intent)
end
function Intent.choose(self: any,mode: any,kind: any,serial: any,id: any): (any,boolean)
 if not valid(mode,kind,serial,id) then return nil,false end
 local old=self.requests[mode]
 if old and serial<old.serial then return nil,false end
 if old and serial==old.serial then
  if old.kind==kind and old.offerId==id then return old,false end
  return nil,false
 end
 local request={mode=mode,kind=kind,serial=serial,offerId=id,revision=1,state="readonly",reason=nil,credential=nil,life=nil,needsCheck=true,retireReady=false}
 self.requests[mode]=request
 return request,true
end
function Intent.notify(self: any,r: any)
 if self.requests[r.mode]~=r then return end
 if self.emit then pcall(self.emit,{mode=r.mode,kind=r.kind,serial=r.serial,offerId=r.offerId,revision=r.revision,state=r.state,reason=r.reason,credential=r.credential,life=r.life}) end
end
function Intent.readonly(self: any,r: any,reason: string?)
 if self.requests[r.mode]~=r or r.state=="changed" then return end
 if r.state~="readonly" or r.reason~=reason or r.credential~=nil then r.revision+=1 end
 r.state,r.reason,r.credential,r.retireReady,r.needsCheck="readonly",reason,nil,false,true
 self:notify(r)
end
function Intent.changed(self: any,r: any,reason: string)
 if self.requests[r.mode]~=r then return end
 if r.state~="changed" or r.reason~=reason then r.revision+=1 end
 r.state,r.reason,r.credential,r.retireReady,r.needsCheck="changed",reason,nil,false,false
 self:notify(r)
end
function Intent.grant(self: any,r: any,life: string?): boolean
 if self.requests[r.mode]~=r or r.state=="changed" or self.counter>=Rules.MAX_LIFE_SERIAL then return false end
 self.counter+=1;r.revision+=1
 r.state,r.reason,r.life,r.credential="writable",nil,life,`{self.prefix}:{r.mode}:{r.serial}:{self.counter}`
 r.needsCheck,r.retireReady=false,false
 r.receivedSerial,r.storedSerial,r.storedCredential=0,0,r.credential
 self:notify(r);return true
end
function Intent.authorized(self: any,mode: string,serial: any,credential: any,life: any): boolean
 local r=self.requests[mode]
 return r~=nil and r.state=="writable" and r.serial==serial and type(credential)=="string" and #credential>0
  and #credential<=Rules.MAX_LIFE_TOKEN_CHARS and r.credential==credential and r.life==life
end
function Intent.snapshot(self: any): any
 local out={}
 for mode,r in self.requests do
  out[mode]={mode=r.mode,kind=r.kind,serial=r.serial,offerId=r.offerId,revision=r.revision,state=r.state,reason=r.reason,credential=r.credential,life=r.life}
 end
 return out
end
return Intent
