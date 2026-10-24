--!strict
-- Incoming protected observations may describe a recorded habitat. They are
-- inspected as portable history, never restored here or accepted as new rests.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rest=require(Shared.Persistence.SaveRest)
local Rules=require(Shared.Data.SaveRules)
local Json=require(Shared.Persistence.Json)
local Portable=require(Shared.Persistence.RecoveryLifePrototype)
local Validation={}
function Validation.new(current:(string,any,boolean)->boolean):(string,any,boolean,boolean?)->boolean
 return function(mode:string,record:any,received:boolean,protected:boolean?):boolean
  if not table.find(Rules.MODES,mode) then return false end
  if current(mode,record,received) then return true end
  if not received or protected~=true or type(record)~="table" or Rest.isRetired(record) then return false end
  if Rest.bounded(record,Rules.MAX_REST_NODES,Rules.MAX_DEPTH) then return false end
  local text=Json.canonical(record);if not text or #text>Rules.MAX_REST_CHARS then return false end
  local rules=record.life_rules
  if type(rules)~="table" or rules.mode~=(if mode=="free" then "free" else "main")
   or (mode=="easy" and rules.rules~="gentle") then return false end
  -- This identifier only namespaces a temporary validation capsule. The server
  -- independently chooses and verifies the real immutable archive identity.
  return Portable.prepare(record,Rest.stubWorld(),"A1_observed")~=nil
 end
end
return table.freeze(Validation)
