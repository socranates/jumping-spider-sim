-- Frozen serializer compatibility reference from ab8ca9577129e3d9583a0a8ab6824dae1a8cd014.
-- Keep independent of future encoder changes; CLI bundler supplies SaveWork.
--!strict
-- What a Roblox DataStore can hold, checked without the engine (ROBLOX-25), and the canonical text a checksum is taken over
-- (Godot's checkpoint_store.gd: sorted keys, full precision). A value is storable when it is a string, a boolean, a finite
-- number, a list (keys 1..n, no holes) or a table whose keys are all strings, made of storable values, with no table met
-- twice. Pure; tests/checkpoint.luau checks it.

local Work = require(script.Parent.SaveWork)
local Json = {}

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local ESC: { [string]: string } = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function quote(s: string): string
	if string.find(s, '[%c"\\]') == nil then return '"' .. s .. '"' end -- (ROBLOX-108: most strings need no escape)
	return '"' .. string.gsub(s, '[%c"\\]', function(c: string): string
		return ESC[c] or string.format("\\u%04x", string.byte(c))
	end) .. '"'
end

-- The kind of table: "list" (keys exactly 1..n; an empty table counts as a list), "object" (all keys strings) or nil.
local function shape(t: { [any]: any }, pulse: ((number?)->())?): string?
	local n, strings, others = 0, 0, 0
	for k in t do
  if pulse then pulse() end
		if type(k) == "string" then
			strings += 1
		elseif type(k) == "number" then
			others += 1
		else
			return nil
		end
		n += 1
	end
	if strings == n then return if n == 0 then "list" else "object" end
	if others == n then
		for i = 1, n do
   if pulse then pulse() end
			if t[i] == nil then return nil end
		end
		return "list"
	end
	return nil
end

-- The canonical JSON text of `v`, or nil and why it is not storable.
-- (ROBLOX-108: the path a problem names is kept as a stack of keys and spelt out only when there is a problem; it was a new string for every value, most of the
-- cost of a checkpoint's save, which runs on the frame the rest begins. The text and every message are as they were.)
function Json.canonical(v: any): (string?, string?)
 local pulse=Work.pulse()
	local seen: { [any]: boolean } = {}
	local problem: string? = nil
	local trail: { any } = {}
	local function where(): string
		local out = "value"
		for _, k in trail do
			if type(k) == "number" then out ..= `[{k}]` else out ..= `.{k}` end
		end
		return out
	end
	local function enc(x: any): string
  if pulse then pulse() end
		if problem then return "" end
		local t = type(x)
		if t == "string" then return quote(x) end
		if t == "boolean" then return if x then "true" else "false" end
		if t == "number" then
			if not finite(x) then
				problem = `{where()}: a number JSON cannot hold`
				return ""
			end
			if x == math.floor(x) and math.abs(x) < 2 ^ 53 then return string.format("%d", x) end
			return string.format("%.17g", x)
		end
		if t ~= "table" then
			problem = `{where()}: a {typeof(x)}`
			return ""
		end
		if getmetatable(x) ~= nil then
			problem = `{where()}: a table with a metatable`
			return ""
		end
		if seen[x] then
			problem = `{where()}: a table met twice`
			return ""
		end
		seen[x] = true
		local kind = shape(x,pulse)
		local depth = #trail + 1
		if kind == "list" then
			local parts = table.create(#x)
			for i, y in ipairs(x) do
				trail[depth] = i
				parts[i] = enc(y)
			end
			trail[depth] = nil
			return "[" .. table.concat(parts, ",") .. "]"
		elseif kind == "object" then
			local keys: { string } = {}
			for k in x do if pulse then pulse() end;table.insert(keys, k) end
			table.sort(keys)
			local parts = table.create(#keys)
			for i, k in keys do
				trail[depth] = k
				parts[i] = quote(k) .. ":" .. enc(x[k])
			end
			trail[depth] = nil
			return "{" .. table.concat(parts, ",") .. "}"
		end
		problem = `{where()}: a table with mixed or sparse keys`
		return ""
	end
	local text = enc(v)
	if problem then return nil, problem end
	return text, nil
end

-- A deep copy of a storable value (what a DataStore hands back is never the table that was given to it).
local function copy(v: any, pulse: ((number?)->())?): any
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do
  if pulse then pulse() end
  out[k] = if type(x) == "table" then copy(x,pulse) else x
 end
	return out
end
function Json.copy(v: any): any return copy(v,Work.pulse()) end

-- FNV-1a over the text, two independent 32-bit lanes, as 16 hex digits: enough to catch a record cut short or changed.
-- x * 16777619 (the FNV prime, 2^24 + 403) modulo 2^32, exactly, as ((x % 256) * 2^24 + x * 403) % 2^32: a plain product of two 32-bit numbers can exceed 2^53.
-- (ROBLOX-108: the bytes are read a block at a time and the multiply is written out in the loop: the same sums as before, one byte at a time, in less time.)
local BLOCK = 2048
function Json.checksum(text: string): string
 local pulse=Work.pulse()
	local a, b = 0x811c9dc5, 0x050c5d1f
	local n = #text
	local bxor = bit32.bxor
	local i0 = 1
	while i0 <= n do
  if pulse then pulse(64) end
		local i1 = math.min(n, i0 + BLOCK - 1)
		local bytes = { string.byte(text, i0, i1) }
		for j, c in bytes do
			local x = bxor(a, c)
			a = ((x % 256) * 16777216 + x * 403) % 4294967296
			local y = bxor(b, (c + i0 + j - 1) % 256)
			b = ((y % 256) * 16777216 + y * 403) % 4294967296
		end
		i0 = i1 + 1
	end
	return string.format("%08x%08x", a, b)
end

return Json
