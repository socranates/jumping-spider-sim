--!strict
-- Private recovery adapter. Reuse the production protected UpdateAsync boundary
-- without a rest codec so callbacks see and return exact stored representations.
local Backend=require(script.Parent.DataStoreBackend)
local Raw={};Raw.__index=Raw
function Raw.new(dataStore:any):any
 return setmetatable({backend=Backend.new(dataStore)},Raw)
end
function Raw.readRawFresh(self:any,key:string):(boolean,any,string?)
 return self.backend:readRawFresh(key)
end
function Raw.updateRaw(self:any,key:string,transform:(any)->any):(boolean,any,string?)
 -- This escape hatch is deliberately unavailable for progress/archive/proposal
 -- keys. Only a selected normal mode rest key may be replaced through it.
 local owner,slot=string.match(key,"^R_([%w_-]+)_([%a]+)$")
 if not owner or #owner>32 or (slot~="main" and slot~="free" and slot~="easy") then return false,nil,"invalid raw rest key" end
 return self.backend:update(key,transform)
end
return table.freeze(Raw)
