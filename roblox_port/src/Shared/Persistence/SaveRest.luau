--!strict
-- The last rest of a mode, as the server keeps it (ROBLOX-39): a retreat checkpoint (Checkpoint) in an envelope, one per mode.
-- The simulation runs on the client, so the server cannot know the rest is a true one. What it can do, and does, is refuse anything that
-- is not a whole, well-formed, sensible rest before it is stored: bounded size and depth, only plain values, the full checkpoint check
-- (Checkpoint.check: format, schema, windowsill, the spider's pose, every reference in the object graph, the books adding up) against a
-- stand-in world that names the same things the real one does, and the rules in the record agreeing with the mode it is filed under.
-- This is a boundary for corruption safety, not anti-cheat: this is a solo game with no economy, so a client that lies only affects its
-- own rest. A rest from a newer game build is refused here and, if it is already stored, left alone by SaveSession.
local SaveRules = require(script.Parent.Parent.Data.SaveRules)
local Species = require(script.Parent.Parent.Data.Species)
local Json = require(script.Parent.Json)
local Checkpoint = require(script.Parent.Checkpoint)
local SaveEnvelope = require(script.Parent.SaveEnvelope)

local SaveRest = {}

SaveRest.SCHEMA = 1

-- Counts the values in `v` and refuses anything that is not a plain string, boolean, finite number or table without a metatable, a
-- table met twice, or a structure deeper than `maxDepth` or larger than `maxNodes`. Cheap and bounded: a hostile payload is stopped
-- before anything encodes it. Returns the problem, or nil.
function SaveRest.bounded(v: any, maxNodes: number, maxDepth: number): string?
	local nodes = 0
	local seen: { [any]: boolean } = {}
	local problem: string? = nil
	local function walk(x: any, depth: number)
		if problem then return end
		nodes += 1
		if nodes > maxNodes then problem = "too many values"; return end
		local t = type(x)
		if t == "string" or t == "boolean" then return end
		if t == "number" then
			if x ~= x or x == math.huge or x == -math.huge then problem = "a number JSON cannot hold" end
			return
		end
		if t ~= "table" then problem = `a {typeof(x)}, which a save cannot hold`; return end
		if depth > maxDepth then problem = "nested too deeply"; return end
		if getmetatable(x) ~= nil then problem = "a table with a metatable"; return end
		if seen[x] then problem = "a table met twice"; return end
		seen[x] = true
		for k, y in x do
			if type(k) ~= "string" and type(k) ~= "number" then problem = "a key that is not a string or a number"; return end
			walk(y, depth + 1)
			if problem then return end
		end
	end
	walk(v, 1)
	return problem
end

-- The stand-in world: whatever a real client's world offers to Checkpoint.refs, in the same names. A record names these by string; the
-- server needs only that they exist. The species data is the real one (the record's profile references are paths into it).
local function noop() end
local function stubWorld(): Checkpoint.World
	return {
		motor = {}, 
		prey = { p = Species.fly_like_prototype, graph = { cast = noop, sweep = noop, overlap = noop }, probe = {} },
		sensor = { core = { cueEmitted = {} } },
		memory = { contactAcquired = {}, categoryChanged = {}, contactLost = {}, contactReacquired = {}, contactEnded = {} },
		needs = { onEnergyChanged = noop },
		life = { save = noop },
	} :: any
end
SaveRest.stubWorld = stubWorld

-- Every problem with a rest filed under `mode` ("main" or "free"); an empty list for a good one. Never raises.
function SaveRest.check(mode: any, record: any): { string }
	if mode ~= "main" and mode ~= "free" then return { "unknown mode" } end
	if type(record) ~= "table" then return { "the rest is not a table" } end
	local why = SaveRest.bounded(record, SaveRules.MAX_REST_NODES, SaveRules.MAX_DEPTH)
	if why then return { why } end
	local text, err = Json.canonical(record)
	if not text then return { "cannot be stored: " .. tostring(err) } end
	if #text > SaveRules.MAX_REST_CHARS then return { `the rest is {#text} characters; the limit is {SaveRules.MAX_REST_CHARS}` } end
	local rules = record.life_rules
	if type(rules) ~= "table" or rules.mode ~= mode then return { `the rules in this rest are not {mode}'s` } end
	local ok, result = pcall(function(): { string }
		local found = Checkpoint.check(record, stubWorld())
		return found
	end)
	if not ok then return { "the check raised: " .. tostring(result) } end
	return result :: { string }
end

-- The envelope spec of a rest of `mode`.
function SaveRest.spec(mode: string): SaveEnvelope.Spec
	return {
		kind = "rest_" .. mode, current = SaveRest.SCHEMA,
		migrations = {} :: { [number]: (any) -> any },
		validate = function(payload: any): ({ string }, any?) return SaveRest.check(mode, payload), payload end,
	}
end

SaveRest.SPECS = { main = SaveRest.spec("main"), free = SaveRest.spec("free") }

return SaveRest
