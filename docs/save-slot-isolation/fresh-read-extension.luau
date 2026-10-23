-- Explicit verification/recovery reads. Ordinary cached reads are unchanged.
-- See Creator Hub data-store caching: UseCache=false is required to resolve an
-- ambiguous write against current backend state rather than a local cached copy.
local function freshValue(self:any,key:string):(boolean,any,string?)
 local options:DataStoreGetOptions?=nil
 local ok,value=pcall(function():any
  local request=Instance.new("DataStoreGetOptions")
  options=request;request.UseCache=false
  return self.ds:GetAsync(key,request)
 end)
 if options then options:Destroy() end
 if not ok then return false,nil,tostring(value) end
 return true,value,nil
end
function DataStoreBackend.readRawFresh(self:any,key:string):(boolean,any,string?)
 -- Preserve the whole stored representation before any rest codec or fallback.
 return freshValue(self,key)
end
function DataStoreBackend.readFresh(self:any,key:string):(boolean,any,string?)
 local ok,value,why=freshValue(self,key)
 if not ok then return false,nil,why end
 if self.restCodec and restKey(key) then
  local decoded,result=pcall(function():any return self.restCodec:decode(value,true) end)
  if not decoded then return false,nil,tostring(result) end
  value=result
 end
 return true,value,nil
end
