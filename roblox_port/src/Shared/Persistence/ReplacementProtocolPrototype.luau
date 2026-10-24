--!strict
-- Private optional transport capability; ordinary peers keep their protocol.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Data.SaveRules)
local Protocol = {VERSION = 1, RETRY = Rules.CLIENT_LIFE_GAP, TIMEOUT = 120, NEW_VERSION = 1, NEW_TIMEOUT = 960}
function Protocol.token(value: any): boolean
 return type(value) == "string" and #value > 0 and #value <= Rules.MAX_LIFE_TOKEN_CHARS
end
function Protocol.serial(value: any): boolean
 return type(value) == "number" and value == value and value >= 1 and value <= Rules.MAX_LIFE_SERIAL and value % 1 == 0
end
function Protocol.known(value: any, fields: any): boolean
 if type(value) ~= "table" or getmetatable(value) ~= nil then return false end
 local count = 0
 for key in value do count += 1; if count > 9 or not fields[key] then return false end end
 return true
end
return table.freeze(Protocol)
