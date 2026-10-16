--!strict
-- What a Roblox DataStore can hold, checked without the engine (ROBLOX-25), and the canonical text a checksum is taken over
-- (Godot's checkpoint_store.gd: sorted keys, full precision). A value is storable when it is a string, a boolean, a finite
-- number, a list (keys 1..n, no holes) or a table whose keys are all strings, made of storable values, with no table met
-- twice. Pure; tests/checkpoint.luau checks it.

local Json = {}

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local ESC: { [string]: string } = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function quote(s: string): string
	return '"' .. string.gsub(s, '[%c"\\]', function(c: string): string
		return ESC[c] or string.format("\\u%04x", string.byte(c))
	end) .. '"'
end

-- The kind of table: "list" (keys exactly 1..n; an empty table counts as a list), "object" (all keys strings) or nil.
local function shape(t: { [any]: any }): string?
	local n, strings, others = 0, 0, 0
	for k in t do
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
			if t[i] == nil then return nil end
		end
		return "list"
	end
	return nil
end

-- The canonical JSON text of `v`, or nil and why it is not storable.
function Json.canonical(v: any): (string?, string?)
	local seen: { [any]: boolean } = {}
	local problem: string? = nil
	local function enc(x: any, path: string): string
		if problem then return "" end
		local t = type(x)
		if t == "string" then return quote(x) end
		if t == "boolean" then return if x then "true" else "false" end
		if t == "number" then
			if not finite(x) then
				problem = `{path}: a number JSON cannot hold`
				return ""
			end
			if x == math.floor(x) and math.abs(x) < 2 ^ 53 then return string.format("%d", x) end
			return string.format("%.17g", x)
		end
		if t ~= "table" then
			problem = `{path}: a {typeof(x)}`
			return ""
		end
		if getmetatable(x) ~= nil then
			problem = `{path}: a table with a metatable`
			return ""
		end
		if seen[x] then
			problem = `{path}: a table met twice`
			return ""
		end
		seen[x] = true
		local kind = shape(x)
		if kind == "list" then
			local parts = table.create(#x)
			for i, y in ipairs(x) do parts[i] = enc(y, `{path}[{i}]`) end
			return "[" .. table.concat(parts, ",") .. "]"
		elseif kind == "object" then
			local keys: { string } = {}
			for k in x do table.insert(keys, k) end
			table.sort(keys)
			local parts = table.create(#keys)
			for i, k in keys do parts[i] = quote(k) .. ":" .. enc(x[k], `{path}.{k}`) end
			return "{" .. table.concat(parts, ",") .. "}"
		end
		problem = `{path}: a table with mixed or sparse keys`
		return ""
	end
	local text = enc(v, "value")
	if problem then return nil, problem end
	return text, nil
end

-- A deep copy of a storable value (what a DataStore hands back is never the table that was given to it).
function Json.copy(v: any): any
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[k] = Json.copy(x) end
	return out
end

-- FNV-1a over the text, two independent 32-bit lanes, as 16 hex digits: enough to catch a record cut short or changed.
-- x * 16777619 (the FNV prime, 2^24 + 403) modulo 2^32, exactly: a plain product of two 32-bit numbers can exceed 2^53.
local function fnvMul(x: number): number
	return ((x % 256) * 16777216 + x * 403) % 4294967296
end

function Json.checksum(text: string): string
	local a, b = 0x811c9dc5, 0x050c5d1f
	for i = 1, #text do
		local c = string.byte(text, i)
		a = fnvMul(bit32.bxor(a, c))
		b = fnvMul(bit32.bxor(b, (c + i) % 256))
	end
	return string.format("%08x%08x", a, b)
end

return Json
