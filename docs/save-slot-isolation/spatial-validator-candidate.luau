-- Candidate helper for Checkpoint; generic ObjectRecord number tagging stays unchanged.
local V3META: any = if type((Vector3 :: any).zero)=="table" then getmetatable((Vector3 :: any).zero) else nil
local function finiteVector(value: any): boolean
 if not (typeof(value)=="Vector3" or (V3META~=nil and type(value)=="table" and getmetatable(value)==V3META)) then return false end
 return finite(value.X) and finite(value.Y) and finite(value.Z)
end
