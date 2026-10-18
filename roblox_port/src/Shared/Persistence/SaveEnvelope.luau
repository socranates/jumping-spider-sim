--!strict
-- The versioned envelope every stored save travels in (ROBLOX-39), and how it is opened without ever guessing.
--   { format, kind, schema, updatedAt, payload, checksum, backup?, lock?, session? }
-- `checksum` is taken over the canonical JSON of { kind, schema, updatedAt, payload } (Json.checksum, the checkpoint store's own), so a
-- value that was cut short, changed or written by something else is refused even if what is left still looks like a save. `backup`
-- is the previous good version of the same kind (schema, updatedAt, payload, checksum), kept inside the same value; `lock` and
-- `session` are outside the checksum on purpose (the lock is refreshed without touching the payload).
-- Opening gives a status and never raises:
--   missing ... nothing is stored
--   ok ......... a good save of the schema this build writes
--   migrated ... a good older save, carried forward in memory (the migration table of its kind); nothing is written by opening
--   newer ...... made by a newer build: left exactly as it is, never read past its header, never written
--   corrupt .... not a save, a wrong kind, a bad checksum, or a number that is not a schema
--   invalid .... the checksum is right but the contents are not (or no migration leads from its schema)
-- A spec describes one kind: { kind, current, migrations = { [from] = function(payload) -> payload of schema from + 1 }, validate }.
-- `validate(payload)` returns (problems, cleaned payload): an empty list is a good one.
local Json = require(script.Parent.Json)
local SaveRules = require(script.Parent.Parent.Data.SaveRules)

local SaveEnvelope = {}

export type Spec = {
	kind: string, current: number,
	migrations: { [number]: (any) -> any },
	validate: (any) -> ({ string }, any?),
}
export type Opened = {
	status: string, payload: any?, schema: number?, updatedAt: number?, reasons: { string },
	lock: any?, session: string?, backup: Opened?, migratedFrom: number?,
}

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function checksumOf(kind: string, schema: number, updatedAt: number, payload: any): string?
	local text = Json.canonical({ kind = kind, schema = schema, updatedAt = updatedAt, payload = payload })
	if not text then return nil end
	return Json.checksum(text)
end

-- The core of a save: what the checksum covers, plus the checksum.
function SaveEnvelope.core(spec: Spec, payload: any, updatedAt: number): { [string]: any }
	return { schema = spec.current, updatedAt = updatedAt, payload = payload, checksum = checksumOf(spec.kind, spec.current, updatedAt, payload) }
end

-- Whether a stored value is a save of this kind with an intact checksum, whatever its schema (used to keep a backup).
local function intact(spec: Spec, v: any): boolean
	if type(v) ~= "table" or v.format ~= SaveRules.FORMAT or v.kind ~= spec.kind then return false end
	if not finite(v.schema) or v.schema < 1 or v.schema ~= math.floor(v.schema) or not finite(v.updatedAt) then return false end
	return checksumOf(spec.kind, v.schema, v.updatedAt, v.payload) == v.checksum and v.checksum ~= nil
end

local function openCore(spec: Spec, v: any, withBackup: boolean): Opened
	local function out(status: string, reasons: { string }, extra: { [string]: any }?): Opened
		local o: any = { status = status, reasons = reasons }
		if extra then for k, x in extra do o[k] = x end end
		return o
	end
	if v == nil then return out("missing", { "nothing is stored" }) end
	if type(v) ~= "table" or v.format ~= SaveRules.FORMAT then return out("corrupt", { "not a save of this game" }) end
	if v.kind ~= spec.kind then return out("corrupt", { `a {tostring(v.kind)} where a {spec.kind} was expected` }) end
	local schema = v.schema
	if not finite(schema) or schema < 1 or schema ~= math.floor(schema) then return out("corrupt", { "the schema is not a whole number" }) end
	local lock = if type(v.lock) == "table" then v.lock else nil
	local session = if type(v.session) == "string" then v.session else nil
	if schema > spec.current then
		return out("newer", { `made by a newer version of the game (schema {schema}; this one reads up to {spec.current})` }, { schema = schema, updatedAt = if finite(v.updatedAt) then v.updatedAt else nil, lock = lock, session = session })
	end
	if not finite(v.updatedAt) or type(v.checksum) ~= "string" or checksumOf(spec.kind, schema, v.updatedAt, v.payload) ~= v.checksum then
		local extra: any = { schema = schema, lock = lock, session = session }
		if withBackup and v.backup ~= nil then
			local b = v.backup
			if type(b) == "table" then
				extra.backup = openCore(spec, { format = v.format, kind = v.kind, schema = b.schema, updatedAt = b.updatedAt, payload = b.payload, checksum = b.checksum }, false)
			end
		end
		return out("corrupt", { "the checksum does not match: the save was cut short or changed" }, extra)
	end
	-- the stored form is intact: carry it forward to the schema this build uses
	-- (a copy: a migration that edits its argument in place must not change the stored value it was given)
	local payload: any = if schema < spec.current then Json.copy(v.payload) else v.payload
	local from = schema
	while from < spec.current do
		local step = spec.migrations[from]
		if step == nil then return out("invalid", { `no migration from schema {from}` }, { schema = schema, updatedAt = v.updatedAt, lock = lock, session = session }) end
		local ok, moved = pcall(step, payload)
		if not ok or moved == nil then return out("invalid", { `the migration from schema {from} failed` }, { schema = schema, updatedAt = v.updatedAt, lock = lock, session = session }) end
		payload = moved
		from += 1
	end
	local okV, problems, cleaned = pcall(spec.validate, payload)
	local list: { string } = if okV then (problems :: any) else { "validation raised: " .. tostring(problems) }
	local extra: any = { schema = schema, updatedAt = v.updatedAt, lock = lock, session = session }
	if #list > 0 then return out("invalid", list, extra) end
	extra.payload = if cleaned ~= nil then cleaned else payload
	if schema < spec.current then extra.migratedFrom = schema end
	return out(if schema < spec.current then "migrated" else "ok", {}, extra)
end

-- Opens a stored value. Its backup (if any) is opened too, one level deep, so a caller can fall back without a second look.
-- `wantBackup` false skips opening the backup (a write path that only needs the current value).
function SaveEnvelope.open(spec: Spec, v: any, wantBackup: boolean?): Opened
	local want = wantBackup ~= false
	local o = openCore(spec, v, want)
	if want and type(v) == "table" and o.backup == nil and v.backup ~= nil and o.status ~= "newer" and o.status ~= "missing" then
		local b = v.backup
		if type(b) == "table" then
			o.backup = openCore(spec, { format = v.format, kind = v.kind, schema = b.schema, updatedAt = b.updatedAt, payload = b.payload, checksum = b.checksum }, false)
		end
	end
	return o
end

-- The raw backup core of a stored value, when it is itself intact (so it may be kept as the next backup).
local function backupCoreOf(spec: Spec, v: any): { [string]: any }?
	if not intact(spec, v) then return nil end
	return { schema = v.schema, updatedAt = v.updatedAt, payload = v.payload, checksum = v.checksum }
end

-- A new stored value: `payload` at the current schema, the previous good value of the same kind as its backup. `prior` is the raw
-- stored value (or nil). When the prior is not intact its own backup, if intact, stays the backup. Never raises.
function SaveEnvelope.make(spec: Spec, payload: any, updatedAt: number, prior: any, extras: { [string]: any }?): { [string]: any }
	local c = SaveEnvelope.core(spec, payload, updatedAt)
	local env: { [string]: any } = { format = SaveRules.FORMAT, kind = spec.kind, schema = c.schema, updatedAt = c.updatedAt, payload = c.payload, checksum = c.checksum }
	local backup = backupCoreOf(spec, prior)
	if backup == nil and type(prior) == "table" and type(prior.backup) == "table" then
		backup = backupCoreOf(spec, { format = SaveRules.FORMAT, kind = spec.kind, schema = prior.backup.schema, updatedAt = prior.backup.updatedAt, payload = prior.backup.payload, checksum = prior.backup.checksum })
	end
	env.backup = backup
	if extras then for k, x in extras do env[k] = x end end
	return env
end

-- The same stored value with only the lock (and who holds it) changed: payload, checksum and backup are carried over untouched.
-- `lock` nil releases it.
function SaveEnvelope.withLock(v: any, lock: { [string]: any }?): any
	local out: { [string]: any } = {}
	for k, x in v do out[k] = x end
	out.lock = lock
	return out
end

-- Is this lock held by a live session other than `me` at time `now`? A lock nobody refreshed for LOCK_STALE seconds is not.
function SaveEnvelope.heldByOther(lock: any, me: string, now: number, staleAfter: number): boolean
	if type(lock) ~= "table" then return false end
	if type(lock.session) ~= "string" or lock.session == me then return false end
	if not finite(lock.beat) then return false end -- a lock with no readable beat protects nothing
	return now - lock.beat <= staleAfter
end

SaveEnvelope.intact = intact
return SaveEnvelope
