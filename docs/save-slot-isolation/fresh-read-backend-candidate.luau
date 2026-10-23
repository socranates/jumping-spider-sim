--!strict
-- Roblox DataStore adapter (read and update, neither raises). An optional storage codec handles only R_ rest keys;
-- transforms always see the original envelope. Failed decoding/compression never replaces an earlier stored value.
-- Store and codec are injected for boundary tests; only the server owns real DataStore access.
local DataStoreBackend = {}
DataStoreBackend.__index = DataStoreBackend

function DataStoreBackend.new(dataStore: any, restCodec: any?): any
	return setmetatable({ ds = dataStore, restCodec = restCodec }, DataStoreBackend)
end

local function restKey(key: string): boolean return string.sub(key,1,2)=="R_" end

-- GetAsync: ok, the value (nil when the key does not exist), the error text.
function DataStoreBackend.read(self: any, key: string): (boolean, any, string?)
	local ok, value = pcall(function(): any return self.ds:GetAsync(key) end)
	if not ok then return false, nil, tostring(value) end
	if self.restCodec and restKey(key) then
		local decoded, result=pcall(function(): any return self.restCodec:decode(value,true) end)
		if not decoded then return false,nil,tostring(result) end
		value=result
	end
	return true, value, nil
end

-- UpdateAsync: `transform(old)` returns the new value, or nil to leave the key as it is. Roblox may call it more than once.
function DataStoreBackend.update(self: any, key: string, transform: (any) -> any): (boolean, any, string?)
	local callbackError: string? = nil
	local ok, value = pcall(function(): any
		local useCodec=self.restCodec~=nil and restKey(key)
		local result = self.ds:UpdateAsync(key, function(stored: any): any
			-- Native UpdateAsync can log a thrown callback error and return nil to its caller.
			-- Catch inside the callback, cancel the write, then report the failure outside that API boundary.
			if callbackError ~= nil then return nil end
			local transformed, candidate = pcall(function(): any
				local old=if useCodec then self.restCodec:decode(stored) else stored
				local nextValue=transform(old)
				if nextValue==nil then return nil end
				return if useCodec then self.restCodec:encode(nextValue) else nextValue
			end)
			if not transformed then callbackError=tostring(candidate);return nil end
			return candidate
		end)
		if callbackError ~= nil then error(callbackError, 0) end
		if useCodec then return self.restCodec:decode(result) end
		return result
	end)
	if not ok then return false, nil, tostring(value) end
	return true, value, nil
end

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

return DataStoreBackend
