--!strict
-- The in-memory store backend (ROBLOX-39): the same interface as the real DataStore backend, with a Roblox DataStore's rules (values
-- copied in and out, only storable values, the size limit, UpdateAsync that may call its function more than once) and a way to make it
-- fail in every way the tests need. It is what the CLI tests run on and what a build without DataStore access falls back to (a session
-- that lasts as long as the server).
-- Interface (a backend is any table with these):
--   backend:read(key)              -> ok: boolean, value: any, err: string?
--   backend:update(key, transform) -> ok: boolean, value: any, err: string?     transform(old) returns the new value, or nil to cancel
-- A cancelled update is ok with value nil. Neither raises.
-- Faults: backend:fail{ op = "read"|"update"|"any", key = "<key or prefix*>"?, times = n?, message = "...", afterWrite = true? }. A fault with
-- afterWrite lets the write happen and then reports an error (a timeout that did not mean the write was lost). backend:poke(key, value) sets
-- a raw value (corrupt JSON, a half-written record). `backend.log` lists every request: { op, key, ok }.
local Json = require(script.Parent.Json)
local SaveRules = require(script.Parent.Parent.Data.SaveRules)

local MemoryBackend = {}
MemoryBackend.__index = MemoryBackend

export type Fault = { op: string, key: string?, times: number, message: string, afterWrite: boolean? }

function MemoryBackend.new(): any
	return setmetatable({ data = {} :: { [string]: any }, faults = {} :: { Fault }, log = {} :: { any }, requests = 0, writes = 0, clock = 0 }, MemoryBackend)
end

function MemoryBackend.fail(self: any, fault: { [string]: any })
	table.insert(self.faults, { op = fault.op or "any", key = fault.key, times = fault.times or 1, message = fault.message or "503: the service is unavailable", afterWrite = fault.afterWrite })
end

function MemoryBackend.clearFaults(self: any)
	self.faults = {}
end

function MemoryBackend.poke(self: any, key: string, value: any)
	self.data[key] = value
end

local function matches(pattern: string?, key: string): boolean
	if pattern == nil then return true end
	if string.sub(pattern, -1) == "*" then return string.sub(key, 1, #pattern - 1) == string.sub(pattern, 1, #pattern - 1) end
	return pattern == key
end

-- The first live fault for this request, used up by one.
local function takeFault(self: any, op: string, key: string): Fault?
	for i, f in self.faults do
		if (f.op == "any" or f.op == op) and matches(f.key, key) and f.times > 0 then
			f.times -= 1
			if f.times == 0 then table.remove(self.faults, i) end
			return f
		end
	end
	return nil
end

function MemoryBackend.read(self: any, key: string): (boolean, any, string?)
	self.requests += 1
	local f = takeFault(self, "read", key)
	if f then
		table.insert(self.log, { op = "read", key = key, ok = false })
		return false, nil, f.message
	end
	table.insert(self.log, { op = "read", key = key, ok = true })
	return true, Json.copy(self.data[key]), nil
end

function MemoryBackend.update(self: any, key: string, transform: (any) -> any): (boolean, any, string?)
	self.requests += 1
	local f = takeFault(self, "update", key)
	if f and not f.afterWrite then
		table.insert(self.log, { op = "update", key = key, ok = false })
		return false, nil, f.message
	end
	local okT, new = pcall(transform, Json.copy(self.data[key]))
	if not okT then
		table.insert(self.log, { op = "update", key = key, ok = false })
		return false, nil, "the update function raised: " .. tostring(new)
	end
	if new == nil then
		table.insert(self.log, { op = "update", key = key, ok = true, cancelled = true })
		return true, nil, nil
	end
	local text, why = Json.canonical(new)
	if not text then
		table.insert(self.log, { op = "update", key = key, ok = false })
		return false, nil, "104: Cannot store this value: " .. tostring(why)
	end
	if #text > SaveRules.MAX_VALUE_CHARS then
		table.insert(self.log, { op = "update", key = key, ok = false })
		return false, nil, `105: the value is {#text} characters, over the limit`
	end
	self.data[key] = Json.copy(new)
	self.writes += 1
	if f and f.afterWrite then
		table.insert(self.log, { op = "update", key = key, ok = false, wrote = true })
		return false, nil, f.message
	end
	table.insert(self.log, { op = "update", key = key, ok = true })
	return true, Json.copy(new), nil
end

return MemoryBackend
