--!strict
-- Private selection-scoped SaveService owner. Engine/menu installation remains gated.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Runtime=require(script.Parent.RecoveryRuntimePrototype)
local Owner={};Owner.__index=Owner
function Owner.new(config:any,emit:any,recovery:any,mode:string):any
 assert(type(emit)=="function" and table.find(Rules.MODES,mode),"server sender and recovery slot required")
 local rt=Runtime.new(config,recovery)
 return setmetatable({runtime=rt,session=rt.session,mode=mode,emit=emit,busy=false,closed=false,lastEntry=-math.huge},Owner)
end
local function alive(self:any):boolean
 return not self.closed and not self.session.closed and self.runtime.session==self.session and not self.runtime.leaving
end
function Owner.load(self:any):...any
 self.busy=true;local result=table.pack(pcall(self.runtime.load,self.runtime));self.busy=false
 if self.negotiated and self.session.restProtected[self.mode] then self.pendingDiscovery=true end
 if not result[1] then error(result[2],0) end;return table.unpack(result,2,result.n)
end
function Owner.enableOffers(self:any)
 if not alive(self) or self.negotiated then return end
 self.negotiated=true;self.session:enableOffers()
 if self.session.restProtected[self.mode] then self.pendingDiscovery=true end
end
function Owner.refreshOffer(self:any,mode:any):boolean
 if not alive(self) or type(mode)~="string" or not table.find(Rules.MODES,mode) then return false end
 local rt=self.runtime
 if mode==self.mode and self.session.restProtected[mode] then
  if rt.accepted then return false end
  if rt.phase=="normal" or rt.phase=="offered" or rt.phase=="offer_refused" then self.pendingDiscovery=true end
  return true
 end
 return rt.phase=="normal" and self.session:refreshOffer(mode)
end
function Owner.requestLife(self:any,kind:any,mode:any,serial:any,offerId:any):boolean
 if not alive(self) or type(mode)~="string" or not table.find(Rules.MODES,mode) then return false end
 local rt=self.runtime;local s=self.session;local r=s.intents.requests[mode]
 if rt.phase=="normal" and not self.pendingDiscovery and not s.restProtected[mode] then return s:requestLife(kind,mode,serial,offerId) end
 if r and r.kind==kind and r.serial==serial and r.offerId==offerId then s.intents:notify(r);return true end
 if self.busy or rt.busy or s.busy then
  -- A later real choice revokes the in-flight fence, but cannot resume normal
  -- writes over recovered data. Replacement/epoch transport is a separate gate.
  if not r or type(serial)~="number" or serial<=r.serial or not s:requestLife(kind,mode,serial,offerId) then return false end
  if rt.phase=="recovering" then rt:cancelRecovery() elseif rt.phase=="entering" then rt:cancelEntry() end
  s.intents:readonly(s.intents.requests[mode],"recovery_owner_switch_required");return true
 end
 if kind=="continue" and mode==self.mode and rt.phase=="offered" and rt.discovery and rt.discovery.offer and rt.discovery.offer.id==offerId then
  return rt:accept(mode,serial,offerId)~=nil
 end
 if rt.phase=="normal" and not self.pendingDiscovery and not s.restProtected[mode] then return s:requestLife(kind,mode,serial,offerId) end
 if r and type(serial)=="number" and serial>r.serial and s:requestLife(kind,mode,serial,offerId) then
  if rt.phase=="recovering" then rt:cancelRecovery() elseif rt.phase=="entering" then rt:cancelEntry() end
  if rt.saveLoop then rt.saveLoop:cancel() end
  rt.phase="held";s.intents:readonly(s.intents.requests[mode],"recovery_owner_switch_required");return true
 end
 return false
end
function Owner.setProgress(self:any,value:any):boolean
 return alive(self) and not self.runtime.intakeClosed and self.session:setProgress(value)
end
function Owner.beginLife(self:any,mode:any,serial:any):boolean
 return alive(self) and self.runtime.phase=="normal" and not self.pendingDiscovery and self.session:beginLife(mode,serial)
end
function Owner.setRestForLife(self:any,mode:any,record:any,life:any):boolean
 return alive(self) and self.runtime.phase=="normal" and not self.pendingDiscovery and self.session:setRestForLife(mode,record,life)
end
function Owner.setRestForIntent(self:any,mode:any,record:any,life:any,serial:any,credential:any,restSerial:any):boolean
 if not alive(self) then return false end
 if self.runtime.phase=="recovered" then
  if not self.session.intents:authorized(mode,serial,credential,life) or type(record)~="table" or getmetatable(record)~=nil then return false end
  local stamped={};local count=0
  for k,v in record do count+=1;if count>Rules.MAX_REST_NODES then return false end;stamped[k]=v end
  stamped.save_life=life -- authoritative root metadata, like normal Session intake
  return self.runtime:saveRecovered(mode,serial,credential,life,restSerial,stamped)
 end
 return self.runtime.phase=="normal" and not self.pendingDiscovery and self.session:setRestForIntent(mode,record,life,serial,credential,restSerial)
end
function Owner.applyRecovery(self:any,message:any):boolean
 return alive(self) and self.runtime:entryApplied(message)
end
function Owner.demote(self:any,why:string,retry:boolean)
 local rt=self.runtime
 if rt.phase=="recovering" then rt:cancelRecovery() elseif rt.phase=="entering" then rt:cancelEntry() end
 if rt.saveLoop then rt.saveLoop:cancel() end
 self.session:demote(why,retry)
end
local function step(self:any):boolean
 local rt=self.runtime;local s=self.session
 if self.pendingDiscovery and self.negotiated and s.state=="active" and not rt.accepted then
  if rt.phase=="offered" then rt:dismiss() end
  if rt.phase=="normal" or rt.phase=="offer_refused" then
   local j=rt:discover(self.mode);if j then self.pendingDiscovery=nil end
   return false
  end
 end
 if rt.phase=="entry_required" then rt:enter();return false end
 local asked=rt:step()
 if not alive(self) then return asked end
 local j=rt.entryJob;local now=s.now()
 if rt.phase=="entering" and j and j.state=="pending" and j.phase=="awaitApplied" and j.offer
  and (self.entryId~=j.offer.id or now-self.lastEntry>=Rules.CLIENT_LIFE_GAP) then
  self.entryId,self.lastEntry=j.offer.id,now -- callbacks may reenter with the exact ACK
  self.emit({kind="recovery_entry",offer=j.offer})
 end
 return asked
end
function Owner.step(self:any):boolean
 if not alive(self) or self.busy or self.runtime.busy or self.session.busy then return false end
 self.busy=true;local ok,asked=pcall(step,self);self.busy=false
 if not ok then self.problem=tostring(asked);self:demote("load_failed",false);return false end
 return asked
end
function Owner.flush(self:any,deadline:number?)
 self.closed=true;self.runtime:flush(deadline)
end
return table.freeze(Owner)
