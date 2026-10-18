--!strict
-- The real store backend (ROBLOX-39): a thin adapter from a Roblox DataStore to the interface Shared/Persistence/MemoryBackend documents
-- (read and update, neither raises). It holds no logic of its own; it takes the DataStore object as an argument so a fake can stand in for
-- it (tests/state.luau runs it against one). Only the server requires this module: the server owns all DataStore access.
local DataStoreBackend = {}
DataStoreBackend.__index = DataStoreBackend

function DataStoreBackend.new(dataStore: any): any
	return setmetatable({ ds = dataStore }, DataStoreBackend)
end

-- GetAsync: ok, the value (nil when the key does not exist), the error text.
function DataStoreBackend.read(self: any, key: string): (boolean, any, string?)
	local ok, value = pcall(function(): any return self.ds:GetAsync(key) end)
	if not ok then return false, nil, tostring(value) end
	return true, value, nil
end

-- UpdateAsync: `transform(old)` returns the new value, or nil to leave the key as it is. Roblox may call it more than once.
function DataStoreBackend.update(self: any, key: string, transform: (any) -> any): (boolean, any, string?)
	local ok, value = pcall(function(): any
		local result = self.ds:UpdateAsync(key, transform)
		return result
	end)
	if not ok then return false, nil, tostring(value) end
	return true, value, nil
end

return DataStoreBackend
