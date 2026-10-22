--!strict
-- Private server observations, independent of write credentials. The caller must
-- validate/bound a record before publishing it. Public results are deep copies;
-- at most one latest and one selected record are retained for each save slot.
local Json = require(script.Parent.Json)
local Rules = require(script.Parent.Parent.Data.SaveRules)
local Observation = {}
Observation.__index = Observation

local function slot(mode: any): boolean
 return type(mode)=="string" and table.find(Rules.MODES,mode)~=nil
end
local function serial(value: any): boolean
 return type(value)=="number" and value==value and value>=1 and value<=Rules.MAX_LIFE_SERIAL and value==math.floor(value)
end
local function validIdentity(value: any): boolean
 return type(value)=="table" and getmetatable(value)==nil
  and type(value.checksum)=="string" and #value.checksum==16
  and type(value.updatedAt)=="number" and value.updatedAt==value.updatedAt and math.abs(value.updatedAt)<math.huge
  and (value.life==nil or (type(value.life)=="string" and #value.life<=Rules.MAX_LIFE_TOKEN_CHARS))
  and (value.kind=="primary" or value.kind=="backup")
end
local function same(a: any,b: any): boolean
 return a~=nil and b~=nil and a.checksum==b.checksum and a.updatedAt==b.updatedAt and a.life==b.life and a.kind==b.kind
end
local function public(value: any): any
 if value==nil then return nil end
 return {id=value.id,record=Json.copy(value.record),protected=value.protected}
end

function Observation.new(sessionId: string): any
 assert(type(sessionId)=="string" and #sessionId>0,"observation owner required")
 return setmetatable({prefix=Json.checksum(sessionId),counter=0,latest={},choices={}},Observation)
end

function Observation.publish(self: any,mode: string,record: any,identity: any,protected: boolean?): any
 if not slot(mode) or type(record)~="table" or getmetatable(record)~=nil or not validIdentity(identity) or record.save_life~=identity.life then return nil end
 local current=self.latest[mode]
 if current and same(current.identity,identity) and current.protected==(protected==true) then return public(current) end
 if self.counter>=Rules.MAX_LIFE_SERIAL then self.latest[mode]=nil;return nil end
 self.counter+=1
 local value={id=self.prefix..":"..tostring(self.counter),record=Json.copy(record),protected=protected==true,
  identity={checksum=identity.checksum,updatedAt=identity.updatedAt,life=identity.life,kind=identity.kind}}
 self.latest[mode]=value
 return public(value)
end

function Observation.withdraw(self: any,mode: string)
 if slot(mode) then self.latest[mode]=nil end -- a selected old view stays immutable
end
function Observation.offer(self: any,mode: string): any
 return if slot(mode) then public(self.latest[mode]) else nil
end

function Observation.select(self: any,mode: string,intentSerial: any,offerId: any): (any,string?)
 if not slot(mode) or not serial(intentSerial) or type(offerId)~="string" or #offerId>Rules.MAX_LIFE_TOKEN_CHARS then return nil,"invalid" end
 local prior=self.choices[mode]
 if prior and intentSerial<prior.serial then return nil,"stale" end
 if prior and intentSerial==prior.serial then
  if prior.offer and prior.offer.id==offerId then return self:selection(mode),nil end
  return nil,"stale"
 end
 -- A higher explicit intent revokes the older selection even if its displayed
 -- offer has since disappeared. It must never bind to a newly discovered rest.
 local latest=self.latest[mode]
 self.choices[mode]={serial=intentSerial,offer=if latest and latest.id==offerId then latest else nil}
 if self.choices[mode].offer==nil then return nil,"changed" end
 return self:selection(mode),nil
end

function Observation.selection(self: any,mode: string): any
 local choice=if slot(mode) then self.choices[mode] else nil
 if not choice or not choice.offer then return nil end
 local value=public(choice.offer)
 value.serial=choice.serial;value.identity=Json.copy(choice.offer.identity)
 return value
end

-- Identity agreement only, NEVER permission to write: the session must also
-- own the lease and durably acknowledge the appropriate life/intent credential.
function Observation.matches(self: any,mode: string,identity: any): boolean
 if not slot(mode) or not validIdentity(identity) then return false end
 local choice,current=self.choices[mode],self.latest[mode]
 return choice~=nil and choice.offer~=nil and current~=nil and not choice.offer.protected and not current.protected
  and same(choice.offer.identity,identity) and same(current.identity,identity)
end

return Observation
