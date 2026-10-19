--!strict
-- Where checkpoints live (S02; Godot's scripts/persistence/checkpoint_store.gd; ROBLOX-25), behind a DataStore-shaped
-- interface. This build uses only MemoryDataStore, an in-memory stand-in with a Roblox DataStore's rules (GetAsync, SetAsync,
-- RemoveAsync that may raise, values copied in and out, only storable values, a size limit). No live DataStore is written:
-- the in-memory store lasts as long as the session. A real DataStore can take its place later without changing the rest.
--
-- Keys: <key> the current checkpoint; <key>.bak the previous valid one; <key>.tmp a write in progress (never read as a
-- checkpoint); <key>.aside.N something this build could not read, set aside unchanged (never deleted).
-- An entry is { format, checksum, checkpoint }; the checksum is taken over the checkpoint's canonical JSON, so an entry that
-- was cut short or changed is refused even if what is left still looks like a checkpoint.
-- Saving: the record is checked, written to the temporary key, read back and checked again (checksum and validation). Only
-- then does the current entry (if it is itself good) become the backup and the new one the current. A current entry that is
-- damaged, or made by a newer version, never pushes out a good backup: it is set aside unchanged. Loading never writes: the
-- current entry is tried, then the backup, and each refusal says why. A newer schema is reported and left as it is.
local Json = require(script.Parent.Json)

local CheckpointStore = {}
CheckpointStore.__index = CheckpointStore
CheckpointStore.FORMAT = "the-windowsill checkpoint"

-- ------------------------------------------------------------------------------------------------ the in-memory DataStore
local MemoryDataStore = {}
MemoryDataStore.__index = MemoryDataStore
CheckpointStore.MemoryDataStore = MemoryDataStore
-- A Roblox DataStore value may be at most 4,194,304 characters once encoded.
MemoryDataStore.MAX_CHARS = 4194304

function MemoryDataStore.new(): any
	return setmetatable({ data = {} :: { [string]: any }, writes = 0, failNext = 0, failReads = 0, sizes = {} :: { [string]: number } }, MemoryDataStore)
end

function MemoryDataStore.GetAsync(self: any, key: string): any
	if self.failReads > 0 then
		self.failReads -= 1
		error("MemoryDataStore: the read failed (a test asked it to)")
	end
	return Json.copy(self.data[key])
end

function MemoryDataStore.SetAsync(self: any, key: string, value: any)
	if self.failNext > 0 then
		self.failNext -= 1
		error("MemoryDataStore: the write failed (a test asked it to)")
	end
	local text, why = Json.canonical(value)
	if not text then error("MemoryDataStore: cannot store this value: " .. tostring(why)) end
	if #text > MemoryDataStore.MAX_CHARS then error(`MemoryDataStore: the value is {#text} characters, over the limit`) end
	self.data[key] = Json.copy(value)
	self.sizes[key] = #text
	self.writes += 1
end

function MemoryDataStore.RemoveAsync(self: any, key: string): any
	local old = self.data[key]
	self.data[key] = nil
	self.sizes[key] = nil
	return old
end

-- ------------------------------------------------------------------------------------------------ the checkpoint store
export type Result = { ok: boolean, message: string, errors: { string }, record: any?, source: string? }

-- `store` is DataStore-shaped (GetAsync, SetAsync, RemoveAsync). `validate(record)` returns the record's problems (an empty
-- list for a good one): the world's own checks (Checkpoint.check).
function CheckpointStore.new(store: any, validate: (any) -> { string }, key: string?): any
	return setmetatable({ store = store, validate = validate, key = key or "checkpoint", last = nil :: Result? }, CheckpointStore)
end

local function result(self: any, ok: boolean, message: string, errors: { string }?, extra: { [string]: any }?): Result
	local r: any = { ok = ok, message = message, errors = errors or {} }
	local more: { [string]: any } = extra or {}
	for k, v in more do r[k] = v end
	self.last = r
	return r
end

-- The entry for a record, or nil and why it cannot be stored.
function CheckpointStore.entry(record: any): (any?, string?)
	local text, why = Json.canonical(record)
	if not text then return nil, why end
	return { format = CheckpointStore.FORMAT, checksum = Json.checksum(text), checkpoint = record }, nil
end

-- Reads an entry: the record, or nil and why not. `newer` is true when it was made by a newer version (left as it is).
function CheckpointStore.read(self: any, entry: any): (any?, { string }, boolean)
	if entry == nil then return nil, { "there is none" }, false end
	if type(entry) ~= "table" or entry.format ~= CheckpointStore.FORMAT then return nil, { "not a checkpoint entry" }, false end
	local text = Json.canonical(entry.checkpoint)
	if not text or Json.checksum(text) ~= entry.checksum then return nil, { "the checksum does not match: the entry was cut short or changed" }, false end
	local problems = self.validate(entry.checkpoint)
	if #problems > 0 then
		local newer = string.find(problems[1], "newer version", 1, true) ~= nil
		return nil, problems, newer
	end
	return entry.checkpoint, {}, false
end

local function try(fn: () -> ...any): (boolean, any)
	return pcall(fn)
end

-- Sets aside an entry this build could not read: never deleted, never overwritten. Returns the key used, or "".
function CheckpointStore._setAside(self: any, entry: any): string
	for i = 1, 50 do
		local k = `{self.key}.aside.{i}`
		local ok, existing = try(function() return self.store:GetAsync(k) end)
		if ok and existing == nil then
			local wrote = try(function() self.store:SetAsync(k, entry) end)
			return if wrote then k else ""
		end
	end
	return ""
end

-- Writes `record` as the current checkpoint, keeping the previous good one as the backup.
function CheckpointStore.save(self: any, record: any): Result
	local problems = self.validate(record)
	if #problems > 0 then return result(self, false, "the checkpoint is not valid", problems) end
	local entry, why = CheckpointStore.entry(record)
	if not entry then return result(self, false, "the checkpoint cannot be stored", { why :: string }) end
	local tmp, main, bak = self.key .. ".tmp", self.key, self.key .. ".bak"
	local wrote, err = try(function() self.store:SetAsync(tmp, entry) end)
	if not wrote then return result(self, false, "the checkpoint could not be written", { tostring(err) }) end
	local readOk, back = try(function() return self.store:GetAsync(tmp) end)
	local again, againProblems = nil, { "it could not be read back" }
	if readOk then again, againProblems = self:read(back) end
	if not again then return result(self, false, "the checkpoint did not read back correctly", againProblems) end
	local curOk, current = try(function() return self.store:GetAsync(main) end)
	if not curOk then return result(self, false, "the current checkpoint could not be read", { tostring(current) }) end
	if current ~= nil then
		local good, _, _ = self:read(current)
		if good then
			local moved, merr = try(function() self.store:SetAsync(bak, current) end)
			if not moved then return result(self, false, "the previous checkpoint could not be kept as the backup", { tostring(merr) }) end
		elseif self:_setAside(current) == "" then
			return result(self, false, "a damaged checkpoint could not be set aside, so it was left in place", {})
		end
	end
	local placed, perr = try(function() self.store:SetAsync(main, entry) end)
	if not placed then return result(self, false, "the checkpoint could not be put in place", { tostring(perr) }) end
	try(function() self.store:RemoveAsync(tmp) end)
	return result(self, true, "Last rest kept.", {}) -- (ROBLOX-92: the player's word for a checkpoint is the last rest)
end

-- The newest good checkpoint: { ok, record, source = "current" | "backup", message, errors }. Never writes.
function CheckpointStore.loadBest(self: any): Result
	local errors: { string } = {}
	for _, which in { { self.key, "current" }, { self.key .. ".bak", "backup" } } do
		local ok, entry = try(function() return self.store:GetAsync(which[1]) end)
		if not ok then
			table.insert(errors, `{which[2]}: it could not be read ({tostring(entry)})`)
			continue
		end
		local record, problems, newer = self:read(entry)
		if record then
			return result(self, true, if which[2] == "current" then "the last rest" else "the backup of the last rest (the newest could not be used)", errors, { record = record, source = which[2] })
		end
		for _, p in problems do table.insert(errors, `{which[2]}: {p}`) end
		if newer then
			return result(self, false, "the last rest was made by a newer version of the game; it was left as it is", errors)
		end
	end
	return result(self, false, "no last rest to return to", errors)
end

return CheckpointStore
