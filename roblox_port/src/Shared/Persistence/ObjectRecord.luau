--!strict
-- ObjectRecord (ROBLOX-25): the state of a few live objects as one plain record that a DataStore could hold, and back.
-- The world's state is a graph of Luau tables (flies point at their perches, a flight at its fly and back, the feeding at the
-- needs it grants to). Writing a record by hand for each module would miss a field sooner or later, and a missed field is a
-- checkpoint that comes back different. So this walks the graph from named roots and records every table once, keeping who
-- points at what, cycles included. Nothing is guessed:
--   * a table with a metatable is recorded only if its metatable is one of the named `classes`; anything else is refused;
--   * functions, Instances and any other engine value are refused unless they are named `refs` (the running program's own
--     things: the world's raycast closures, a probe part, a Signal with its listeners, the species data). A ref is kept as its
--     name and comes back as whatever has that name when the record is restored;
--   * numbers that JSON cannot hold (infinities, NaN) and Vector3 values are written as small tagged tables.
-- The record: { format = FORMAT, roots = { name = { ["$o"] = i } }, objects = { { c = class?, e = { { key, value }, ... } } } },
-- where every key is a string or a finite number, and every value a string, boolean, finite number, or one of
-- { ["$o"] = i } (the i-th object), { ["$r"] = name }, { ["$v"] = { x, y, z } }, { ["$n"] = "inf" | "-inf" | "nan" }.
-- Entries are sorted, so the same state always gives the same record.
-- Restoring is in two steps. `decode` checks the whole record and builds every object fresh, touching nothing live; a record
-- with any problem is refused there, with the reasons. `commit` then moves the fresh roots' contents into the live root tables
-- (so everything else that holds a live root keeps holding the right table) and cannot fail part way.

local ObjectRecord = {}

ObjectRecord.FORMAT = "object-record-1"
-- Refuse graphs larger than this many tables (a runaway reference would otherwise record the whole program).
ObjectRecord.MAX_OBJECTS = 20000

export type Record = { format: string, roots: { [string]: any }, objects: { any } }
export type Decoded = { roots: { [string]: any }, objects: { any } }

local V3META: any = if type((Vector3 :: any).zero) == "table" then getmetatable((Vector3 :: any).zero) else nil

local function isVector3(v: any): boolean
	return typeof(v) == "Vector3" or (V3META ~= nil and type(v) == "table" and getmetatable(v) == V3META)
end

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local function encodeNumber(x: number): any
	if finite(x) then return x end
	return { ["$n"] = if x ~= x then "nan" elseif x > 0 then "inf" else "-inf" }
end

local function keyLess(a: any, b: any): boolean
	local ka, kb = a[1], b[1]
	if type(ka) == type(kb) then return ka < kb end
	return type(ka) == "number" -- numbers before strings
end

-- Records the graph reachable from `roots`. `classes`: name -> metatable. `refs`: name -> value. Returns the record, or nil
-- and the reason (with the path to the first thing it could not record).
function ObjectRecord.capture(roots: { [string]: any }, classes: { [string]: any }, refs: { [string]: any }): (Record?, string?)
	local classOf: { [any]: string } = {}
	for name, mt in classes do classOf[mt] = name end
	local refOf: { [any]: string } = {}
	for name, v in refs do
		if refOf[v] == nil then refOf[v] = name end
	end
	local index: { [any]: number } = {}
	local objects: { any } = {}
	local queue: { any } = {}
	local paths: { [any]: string } = {}
	local problem: string? = nil

	local function value(v: any, path: string): any
		if problem then return nil end
		local t = type(v)
		if t == "string" or t == "boolean" then return v end
		if t == "number" then return encodeNumber(v) end
		local ref = refOf[v]
		if ref ~= nil then return { ["$r"] = ref } end
		if isVector3(v) then
			return { ["$v"] = { encodeNumber(v.X), encodeNumber(v.Y), encodeNumber(v.Z) } }
		end
		if t == "table" then
			local mt = getmetatable(v)
			if mt ~= nil and classOf[mt] == nil then
				problem = `{path}: a table of a class this record does not know`
				return nil
			end
			local i = index[v]
			if i == nil then
				if #objects >= ObjectRecord.MAX_OBJECTS then
					problem = `{path}: more than {ObjectRecord.MAX_OBJECTS} tables`
					return nil
				end
				i = #objects + 1
				index[v] = i
				objects[i] = false
				paths[v] = path
				table.insert(queue, v)
			end
			return { ["$o"] = i }
		end
		problem = `{path}: a {typeof(v)} with no name to keep it by`
		return nil
	end

	local out: Record = { format = ObjectRecord.FORMAT, roots = {}, objects = objects }
	local rootNames: { string } = {}
	for name in roots do table.insert(rootNames, name) end
	table.sort(rootNames)
	for _, name in rootNames do
		local v = roots[name]
		if type(v) ~= "table" or refOf[v] ~= nil or isVector3(v) then
			return nil, `root {name} is not an object`
		end
		out.roots[name] = value(v, name)
	end
	local q = 1
	while q <= #queue and not problem do
		local obj = queue[q]
		q += 1
		local entries: { any } = {}
		local path = paths[obj]
		-- Keys in sorted order, so tables are numbered in the same order whatever the hash order of the live tables.
		local keys: { any } = {}
		for k in obj do
			local kt = type(k)
			if not ((kt == "string") or (kt == "number" and finite(k))) then
				problem = `{path}: a key that is not a string or a finite number`
				break
			end
			table.insert(keys, { k })
		end
		table.sort(keys, keyLess)
		for _, key in keys do
			if problem then break end
			local k = key[1]
			local enc = value(obj[k], `{path}.{k}`)
			if problem then break end
			table.insert(entries, { k, enc })
		end
		local mt = getmetatable(obj)
		objects[index[obj]] = if mt ~= nil then { c = classOf[mt], e = entries } else { e = entries }
	end
	if problem then return nil, problem end
	return out, nil
end

local function decodeNumber(x: any): (number?, string?)
	if type(x) == "number" then
		if finite(x) then return x, nil end
		return nil, "a number JSON cannot hold, written bare"
	end
	if type(x) == "table" then
		local n = x["$n"]
		if n == "inf" then return math.huge, nil end
		if n == "-inf" then return -math.huge, nil end
		if n == "nan" then return 0 / 0, nil end
	end
	return nil, "not a number"
end

local function only(t: any, key: string): boolean
	local count = 0
	for _ in t do count += 1 end
	return count == 1 and t[key] ~= nil
end

-- Checks `record` and builds every object fresh (nothing live is touched). Returns the fresh objects and roots, or nil and
-- every problem found.
function ObjectRecord.decode(record: any, classes: { [string]: any }, refs: { [string]: any }): (Decoded?, { string })
	local problems: { string } = {}
	local function bad(text: string)
		if #problems < 20 then table.insert(problems, text) end
	end
	if type(record) ~= "table" or record.format ~= ObjectRecord.FORMAT then
		return nil, { "not an object record of this format" }
	end
	local objects, roots = record.objects, record.roots
	if type(objects) ~= "table" or type(roots) ~= "table" then
		return nil, { "the record has no objects or roots" }
	end
	local n = #objects
	if n > ObjectRecord.MAX_OBJECTS then
		return nil, { "too many objects" }
	end
	for k in objects do
		if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then
			return nil, { "the objects are not a list" }
		end
	end
	local fresh: { any } = table.create(n)
	for i = 1, n do fresh[i] = {} end

	local function value(v: any, where: string): any
		local t = type(v)
		if t == "string" or t == "boolean" then return v end
		if t == "number" then
			if not finite(v) then bad(`{where}: a bare number JSON cannot hold`) end
			return v
		end
		if t ~= "table" then
			bad(`{where}: a {t}`)
			return nil
		end
		if only(v, "$o") then
			local i = v["$o"]
			if type(i) ~= "number" or i < 1 or i > n or i ~= math.floor(i) then
				bad(`{where}: points at no object`)
				return nil
			end
			return fresh[i]
		end
		if only(v, "$r") then
			local name = v["$r"]
			if type(name) ~= "string" or refs[name] == nil then
				bad(`{where}: names '{tostring(name)}', which this world does not have`)
				return nil
			end
			return refs[name]
		end
		if only(v, "$v") then
			local xyz = v["$v"]
			if type(xyz) ~= "table" or #xyz ~= 3 then
				bad(`{where}: a vector without three numbers`)
				return nil
			end
			local x, e1 = decodeNumber(xyz[1])
			local y, e2 = decodeNumber(xyz[2])
			local z, e3 = decodeNumber(xyz[3])
			if e1 or e2 or e3 then
				bad(`{where}: a vector with {e1 or e2 or e3}`)
				return nil
			end
			return Vector3.new(x :: number, y :: number, z :: number)
		end
		if only(v, "$n") then
			local x, e = decodeNumber(v)
			if e then bad(`{where}: {e}`) end
			return x
		end
		bad(`{where}: a table that is none of the record's kinds`)
		return nil
	end

	for i = 1, n do
		local o = objects[i]
		local where = `object {i}`
		if type(o) ~= "table" or type(o.e) ~= "table" then
			bad(`{where}: not an object`)
			continue
		end
		if o.c ~= nil then
			if type(o.c) ~= "string" or classes[o.c] == nil then
				bad(`{where}: of class '{tostring(o.c)}', which this build does not know`)
				continue
			end
		end
		local target = fresh[i]
		for j, entry in o.e do
			if type(entry) ~= "table" or #entry ~= 2 then
				bad(`{where}, entry {j}: not a key and a value`)
				continue
			end
			local k = entry[1]
			if not (type(k) == "string" or (type(k) == "number" and finite(k))) then
				bad(`{where}, entry {j}: a key that is not a string or a finite number`)
				continue
			end
			if target[k] ~= nil then
				bad(`{where}: the key {k} twice`)
				continue
			end
			target[k] = value(entry[2], `{where}.{k}`)
		end
		if o.c ~= nil and classes[o.c] then
			setmetatable(target, classes[o.c])
		end
	end
	local out: { [string]: any } = {}
	for name, v in roots do
		if type(name) ~= "string" then
			bad("a root without a name")
			continue
		end
		local r = value(v, `root {name}`)
		if type(r) ~= "table" then
			bad(`root {name} is not an object`)
		end
		out[name] = r
	end
	if #problems > 0 then return nil, problems end
	return { roots = out, objects = fresh }, problems
end

-- Moves a decoded world into the live one: every live root (by name) ends up with exactly the fresh root's contents and
-- metatable, and every fresh reference to a fresh root now points at the live root. `live` must name every decoded root.
-- Plain table work only: it cannot fail part way. Returns false (and changes nothing) if a root is missing from `live`.
function ObjectRecord.commit(decoded: Decoded, live: { [string]: any }): boolean
	local swap: { [any]: any } = {}
	for name, fresh in decoded.roots do
		local target = live[name]
		if type(target) ~= "table" then return false end
		swap[fresh] = target
	end
	for _, o in decoded.objects do
		for k, v in o do
			local to = swap[v]
			if to ~= nil then o[k] = to end
		end
	end
	for fresh, target in swap do
		table.clear(target)
		for k, v in fresh do target[k] = v end
		setmetatable(target, getmetatable(fresh))
	end
	return true
end

-- Every plain table reachable from `root` (not through a metatable), named by its path from `name`: the species data a
-- record should keep by name rather than copy.
function ObjectRecord.constants(name: string, root: any, into: { [string]: any }?): { [string]: any }
	local out = into or {}
	local seen: { [any]: boolean } = {}
	local function walk(v: any, path: string)
		if type(v) ~= "table" or seen[v] or isVector3(v) then return end
		seen[v] = true
		out[path] = v
		for k, x in v do
			if type(k) == "string" or type(k) == "number" then walk(x, `{path}.{k}`) end
		end
	end
	walk(root, name)
	return out
end

return ObjectRecord
