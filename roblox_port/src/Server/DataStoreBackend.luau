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
		local decoded, result=pcall(function(): any return self.restCodec:decode(value) end)
		if not decoded then return false,nil,tostring(result) end
		value=result
	end
	return true, value, nil
end

-- UpdateAsync: `transform(old)` returns the new value, or nil to leave the key as it is. Roblox may call it more than once.
function DataStoreBackend.update(self: any, key: string, transform: (any) -> any): (boolean, any, string?)
	local ok, value = pcall(function(): any
		local useCodec=self.restCodec~=nil and restKey(key)
		local result = self.ds:UpdateAsync(key, function(stored: any): any
			local old=if useCodec then self.restCodec:decode(stored) else stored
			local nextValue=transform(old)
			if nextValue==nil then return nil end
			return if useCodec then self.restCodec:encode(nextValue) else nextValue
		end)
		if useCodec then return self.restCodec:decode(result) end
		return result
	end)
	if not ok then return false, nil, tostring(value) end
	return true, value, nil
end

return DataStoreBackend
