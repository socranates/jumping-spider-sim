--!strict
-- One player's save session (ROBLOX-39): loads their records through a store backend, keeps their progress and rests in memory, and writes
-- them back safely. All the decisions are here, with no engine in them: the backend (a real DataStore or the in-memory one), the clock and
-- the sleep are handed in, so the tests drive every failure.
--
-- What it promises
--   * Nothing stored is ever replaced by a default, a guess or a lesser copy. The first thing a session does is an UpdateAsync that reads the
--     progress record and takes its lock; a record that cannot be read, is corrupt (checksum), is invalid, is made by a NEWER build, or is
--     held by a live session makes the session session-only: it keeps the player's progress in memory, tells them, and writes nothing.
--   * Writes are UpdateAsync that merge (pages are a union, eye time the longest, a finished life stays) and refuse to touch a lock another
--     live session holds. A previous good version is kept inside the value as its backup.
--   * One lock, one heartbeat: the progress record carries { session, beat }. A newer session may take it over once the beat is LOCK_STALE
--     old; the older one finds out at its next write or heartbeat and goes read-only. A read-only or failed-to-load session tries again
--     every RETRY_LOAD seconds and, once it holds the lock, merges what it kept with what is stored.
--   * Rests are separate values (one per mode): replaceable, with their own backup. A rest is written only if nobody wrote a newer one
--     since this session read it.
-- States: "loading", "active", "session" (session-only: `reason` says why: offline, no_api, load_failed, other_session, corrupt, newer).
local SaveRules = require(script.Parent.Parent.Data.SaveRules)
local SaveEnvelope = require(script.Parent.SaveEnvelope)
local SaveProgress = require(script.Parent.SaveProgress)
local SaveRest = require(script.Parent.SaveRest)
local SaveScheduler = require(script.Parent.SaveScheduler)
local SaveStores = require(script.Parent.SaveStores)
local Json = require(script.Parent.Json)

local function canonical(v: any): string
	return (Json.canonical(v)) or ""
end

local SaveSession = {}
SaveSession.__index = SaveSession

export type Config = {
	backend: any, userId: number, sessionId: string, now: () -> number,
	sleep: ((number) -> ())?, log: ((string) -> ())?, progressSpec: SaveEnvelope.Spec?, -- (a test may hand in a later schema)
	onChange: ((string, string?) -> ())?, onLoaded: ((any) -> ())?, onRest: ((string, any) -> ())?,
}


function SaveSession.new(cfg: Config): any
	local sched = SaveScheduler.new()
	sched:track("progress", SaveRules.PROGRESS_DEBOUNCE)
	sched:track("rest_main", SaveRules.REST_MIN_INTERVAL)
	sched:track("rest_free", SaveRules.REST_MIN_INTERVAL)
	return setmetatable({
		cfg = cfg, backend = cfg.backend, id = cfg.sessionId, now = cfg.now, pspec = cfg.progressSpec or SaveProgress.SPEC,
		pkey = SaveRules.KEY_PROGRESS .. tostring(cfg.userId),
		rkey = { main = `{SaveRules.KEY_REST}{cfg.userId}_main`, free = `{SaveRules.KEY_REST}{cfg.userId}_free` },
		sched = sched,
		state = "loading", reason = nil :: string?, canRetry = false, retryAt = 0,
		progress = SaveProgress.default(), progressTime = 0, storedTime = 0,
		rests = { main = nil, free = nil } :: { [string]: any },
		restBase = {} :: { [string]: number }, -- updatedAt of the rest this session last read or wrote (nil: unknown)
		restPending = {} :: { [string]: any }, restPendingTime = {} :: { [string]: number },
		restLoaded = {} :: { [string]: boolean }, restRetryAt = 0,
		lockHeld = false, busy = false, closed = false,
		lastStatus = "", lastReason = "",
		counters = { requests = 0, writes = 0, rejected = 0 },
	}, SaveSession)
end

local function log(self: any, text: string)
	local l = self.cfg.log
	if l then l(`[save {self.cfg.userId}] {text}`) end
end

local function lockNow(self: any, now: number): { [string]: any }
	return { session = self.id, beat = now }
end

function SaveSession.isActive(self: any): boolean
	return self.state == "active"
end

function SaveSession.status(self: any): (string, string?)
	if self.state == "session" then return SaveRules.STATUS.session, self.reason end
	if self.state == "loading" then return SaveRules.STATUS.saving, nil end
	if self.busy or self.sched:anyDirty() then
		local trouble = false
		for _, name in { "progress", "rest_main", "rest_free" } do
			if self.sched.items[name].dirty and self.sched.items[name].failures >= 3 then trouble = true end
		end
		return SaveRules.STATUS.saving, if trouble then "write_failed" else nil
	end
	return SaveRules.STATUS.saved, nil
end

function SaveSession.notify(self: any)
	local status, reason = self:status()
	local r = reason or ""
	if status ~= self.lastStatus or r ~= self.lastReason then
		self.lastStatus, self.lastReason = status, r
		local f = self.cfg.onChange
		if f then f(status, reason) end
	end
end

-- Goes session-only. The progress in memory stays; nothing more is written until the lock is held again (when `retry` is true).
function SaveSession.demote(self: any, reason: string, retry: boolean)
	if self.state == "session" and self.reason == reason then return end
	log(self, "session-only: " .. reason)
	self.state, self.reason, self.lockHeld = "session", reason, false
	self.canRetry = retry
	self.retryAt = self.now() + SaveRules.RETRY_LOAD
	self:notify()
end

-- ---------------------------------------------------------------- loading
-- One try at reading the progress record and taking its lock. Returns a verdict:
--   "ok" (held), "locked", "newer", "corrupt", "failed" (the store failed: class in .errClass), "config".
local function attemptLock(self: any): (string, any)
	local now = self.now()
	local verdict = ""
	local info: any = nil
	self.sched:begin(nil, now)
	self.counters.requests += 1
	local ok, _, err = self.backend:update(self.pkey, function(old: any): any
		local op = SaveEnvelope.open(self.pspec, old)
		info = op
		verdict = op.status
		if op.status == "newer" or op.status == "corrupt" or op.status == "invalid" then return nil end
		if op.status == "missing" then
			verdict = "ok"
			return SaveEnvelope.make(self.pspec, SaveProgress.default(), now, nil, { lock = lockNow(self, now) })
		end
		if SaveEnvelope.heldByOther(op.lock, self.id, now, SaveRules.LOCK_STALE) then
			verdict = "locked"
			return nil
		end
		verdict = "ok"
		return SaveEnvelope.withLock(old, lockNow(self, now))
	end)
	if not ok then
		local class = SaveStores.classify(err)
		return if class == "config" then "config" else "failed", { err = err, class = class }
	end
	if verdict == "invalid" then verdict = "corrupt" end
	return verdict, info
end

local function adoptStored(self: any, info: any)
	-- The progress in memory (kept while the session was session-only, or sent by the client before the load finished) is merged into what is stored.
	local stored: any = if info and info.payload then info.payload else SaveProgress.default()
	local storedTime = if info and info.updatedAt then info.updatedAt else 0
	local mem = self.progress
	self.progress = SaveProgress.merge(stored, mem, storedTime, self.progressTime)
	self.storedTime = storedTime
	if not SaveProgress.same(self.progress, stored) then
		self.sched:markDirty("progress", self.now())
	end
end

local function readRests(self: any)
	for _, mode in SaveRules.MODES do
		if not self.restLoaded[mode] then
			local ok, value, err = self.backend:read(self.rkey[mode])
			self.sched:begin(nil, self.now())
			self.counters.requests += 1
			if not ok then
				log(self, `could not read the {mode} rest: {tostring(err)}`)
				self.restRetryAt = self.now() + SaveScheduler.backoff(1, SaveStores.classify(err))
			else
				local spec = SaveRest.SPECS[mode]
				local op = SaveEnvelope.open(spec, value)
				self.restLoaded[mode] = true
				if op.status == "ok" or op.status == "migrated" then
					self.restBase[mode] = op.updatedAt
					self.rests[mode] = op.payload
				elseif op.status == "missing" then
					self.restBase[mode] = 0
				else
					-- unreadable or made by a newer build: the backup, if it is good, is what the player returns to; the damaged value is replaced
					-- by the next rest (a newer build's value is never written over: see writeRest)
					self.restBase[mode] = op.updatedAt or 0
					local b = op.backup
					if b and (b.status == "ok" or b.status == "migrated") then self.rests[mode] = b.payload end
					log(self, `the {mode} rest is {op.status}: {op.reasons[1] or ""}`)
					if op.status == "newer" then self.restNewer = true end
				end
				-- a rest we hold unsent that is newer than the one stored stays pending; an older one is dropped
				local pending = self.restPendingTime[mode]
				if pending ~= nil and (self.restBase[mode] or 0) > pending then
					self.restPending[mode], self.restPendingTime[mode] = nil, nil
					self.sched.items["rest_" .. mode].dirty = false
				end
			end
		end
	end
end

-- Loads the player's records. Yields (backend calls). Returns the state: "active" or "session".
function SaveSession.load(self: any): string
	if self.closed then return self.state end
	local verdict, info = attemptLock(self)
	local first = self.state == "loading"
	if verdict == "ok" then
		adoptStored(self, info)
		self.state, self.reason, self.lockHeld, self.canRetry = "active", nil, true, false
		self.sched:beat(self.now())
		self.restLoaded = {} -- read again: another session may have written a rest while this one could not
		readRests(self)
		if self.restNewer then
			self:demote("newer", false)
			self.restNewer = false
		end
	elseif verdict == "locked" then
		if info and info.payload then self.progress = SaveProgress.merge(info.payload, self.progress, info.updatedAt or 0, self.progressTime) end
		self.state = "session"
		self:demote("other_session", true)
	elseif verdict == "newer" then
		self.state = "session"
		self:demote("newer", false)
	elseif verdict == "corrupt" then
		-- the stored record is left exactly as it is. If its backup is good the player sees that much of their notebook meanwhile.
		local b = info and info.backup
		if b and (b.status == "ok" or b.status == "migrated") then self.progress = SaveProgress.merge(b.payload, self.progress, b.updatedAt or 0, self.progressTime) end
		log(self, "the progress record is not readable: " .. tostring(info and info.reasons and info.reasons[1]))
		self.state = "session"
		self:demote("corrupt", false)
	elseif verdict == "config" then
		self.state = "session"
		self:demote("no_api", false)
	else
		log(self, "could not load: " .. tostring(info and info.err))
		self.state = "session"
		self:demote("load_failed", true)
	end
	if first or self.state == "active" then self:notify() end
	return self.state
end

-- ---------------------------------------------------------------- what the client gives and what is known
function SaveSession.setProgress(self: any, payload: any): boolean
	if self.closed then return false end
	local problems, clean = SaveProgress.sanitize(payload)
	if clean == nil then
		self.counters.rejected += 1
		log(self, "progress refused: " .. tostring(problems[1]))
		return false
	end
	local now = self.now()
	local merged = SaveProgress.merge(self.progress, clean, self.progressTime, now)
	if not SaveProgress.same(merged, self.progress) then
		self.progress = merged
		self.progressTime = now
		self.sched:markDirty("progress", now)
		self:notify()
	end
	return true
end

function SaveSession.setRest(self: any, mode: string, record: any): boolean
	if self.closed or (mode ~= "main" and mode ~= "free") then return false end
	local problems = SaveRest.check(mode, record)
	if #problems > 0 then
		self.counters.rejected += 1
		log(self, `the {mode} rest was refused: {problems[1]}`)
		return false
	end
	local now = self.now()
	self.restPending[mode], self.restPendingTime[mode] = record, now
	self.sched:markDirty("rest_" .. mode, now)
	self:notify()
	return true
end

-- ---------------------------------------------------------------- writing
-- Writes the progress (merged with what is stored). `release`: also let go of the lock. Returns true when it is stored.
local function writeProgress(self: any, release: boolean): boolean
	local now = self.now()
	local version = self.sched:begin("progress", now)
	self.counters.requests += 1
	local outcome = ""
	local merged: any = nil
	local newTime = now
	local ok, _, err = self.backend:update(self.pkey, function(old: any): any
		outcome = ""
		local op = SaveEnvelope.open(self.pspec, old, false)
		if op.status == "newer" then outcome = "newer"; return nil end
		if op.status == "corrupt" or op.status == "invalid" then outcome = "corrupt"; return nil end
		if op.status ~= "missing" and SaveEnvelope.heldByOther(op.lock, self.id, now, SaveRules.LOCK_STALE) then outcome = "locked"; return nil end
		local base: any = if op.payload then op.payload else SaveProgress.default()
		local baseTime = op.updatedAt or 0
		merged = SaveProgress.merge(base, self.progress, baseTime, self.progressTime)
		newTime = math.max(now, baseTime)
		outcome = "ok"
		local lock = if release then nil else lockNow(self, now)
		if op.status ~= "missing" and SaveProgress.same(merged, base) and op.status == "ok" then
			return SaveEnvelope.withLock(old, lock) -- nothing new to say: only the lock moves (payload, checksum and backup untouched)
		end
		return SaveEnvelope.make(self.pspec, merged, newTime, old, { lock = lock })
	end)
	if not ok then
		local class = SaveStores.classify(err)
		if class == "value" then
			log(self, "the progress record cannot be stored: " .. tostring(err))
			self.sched:abandon("progress")
			return false
		end
		local wait = self.sched:failed("progress", now, class)
		log(self, `progress write failed ({class}, retry in {wait} s): {tostring(err)}`)
		return false
	end
	if outcome == "ok" then
		self.progress = merged
		self.storedTime = newTime
		self.sched:succeeded("progress", now, version)
		self.sched:beat(now)
		self.counters.writes += 1
		if release then self.lockHeld = false end
		return true
	end
	if outcome == "locked" then
		self:demote("other_session", true)
	elseif outcome == "newer" then
		self:demote("newer", false)
	elseif outcome == "corrupt" then
		self:demote("corrupt", false)
	end
	return false
end

local function writeRest(self: any, mode: string): boolean
	local name = "rest_" .. mode
	local record = self.restPending[mode]
	if record == nil then
		self.sched.items[name].dirty = false
		return true
	end
	local now = self.now()
	local version = self.sched:begin(name, now)
	self.counters.requests += 1
	local spec = SaveRest.SPECS[mode]
	local outcome = ""
	local newTime = now
	local ok, _, err = self.backend:update(self.rkey[mode], function(old: any): any
		outcome = ""
		local op = SaveEnvelope.open(spec, old, false)
		if op.status == "newer" then outcome = "newer"; return nil end
		local base = self.restBase[mode]
		if (op.status == "ok" or op.status == "migrated") and base ~= nil and (op.updatedAt or 0) > base and op.session ~= self.id then
			outcome = "superseded"
			return nil
		end
		if (op.status == "ok") and canonical(op.payload) == canonical(record) then
			-- already stored (an earlier try whose answer was lost): nothing to write, and the backup must not become a copy of it
			newTime = op.updatedAt or now
			outcome = "ok"
			return nil
		end
		newTime = math.max(now, op.updatedAt or 0)
		outcome = "ok"
		return SaveEnvelope.make(spec, record, newTime, old, { session = self.id })
	end)
	if not ok then
		local class = SaveStores.classify(err)
		if class == "value" then
			log(self, `the {mode} rest cannot be stored: {tostring(err)}`)
			self.restPending[mode], self.restPendingTime[mode] = nil, nil
			self.sched:abandon(name)
			return false
		end
		local wait = self.sched:failed(name, now, class)
		log(self, `{mode} rest write failed ({class}, retry in {wait} s): {tostring(err)}`)
		return false
	end
	if outcome == "ok" then
		self.restBase[mode] = newTime
		self.rests[mode] = record
		if self.restPending[mode] == record then self.restPending[mode], self.restPendingTime[mode] = nil, nil end
		self.sched:succeeded(name, now, version)
		self.counters.writes += 1
		return true
	end
	if outcome == "superseded" then
		self:demote("other_session", true)
	elseif outcome == "newer" then
		self:demote("newer", false)
	end
	return false
end

-- Refreshes the lock when no write has done it lately.
local function heartbeat(self: any)
	local now = self.now()
	self.sched:begin(nil, now)
	self.counters.requests += 1
	local outcome = ""
	local ok, _, err = self.backend:update(self.pkey, function(old: any): any
		outcome = ""
		local op = SaveEnvelope.open(self.pspec, old, false)
		if op.status == "missing" then outcome = "missing"; return nil end
		if op.status == "newer" then outcome = "newer"; return nil end
		if op.status == "corrupt" or op.status == "invalid" then outcome = "corrupt"; return nil end
		if SaveEnvelope.heldByOther(op.lock, self.id, now, SaveRules.LOCK_STALE) then outcome = "locked"; return nil end
		outcome = "ok"
		return SaveEnvelope.withLock(old, lockNow(self, now))
	end)
	if not ok then
		log(self, "heartbeat failed: " .. tostring(err))
		self.sched:beat(now - SaveRules.HEARTBEAT + 5) -- try again in a few seconds
		return
	end
	self.sched:beat(now)
	if outcome == "locked" then self:demote("other_session", true)
	elseif outcome == "newer" then self:demote("newer", false)
	elseif outcome == "corrupt" then self:demote("corrupt", false) end
end

-- One pass of the periodic work; the server calls it about once a second. Does at most one request per call. Returns whether it asked.
local function stepInner(self: any): boolean
	local now = self.now()
	local did = true
	if self.state == "session" then
		if self.canRetry and now >= self.retryAt and self.sched:budgetOk(now) then
			self.retryAt = now + SaveRules.RETRY_LOAD
			local wasReason = self.reason
			self:load()
			if SaveSession.isActive(self) then
				log(self, `holds the record again (was: {tostring(wasReason)})`)
				local f = self.cfg.onLoaded
				if f then f(self:snapshot()) end
			end
		else
			did = false
		end
	elseif self.state == "active" then
		if not self.restLoaded.main or not self.restLoaded.free then
			if now >= self.restRetryAt and self.sched:budgetOk(now) then
				local before = { main = self.rests.main, free = self.rests.free }
				readRests(self)
				for _, mode in SaveRules.MODES do
					if self.rests[mode] ~= nil and before[mode] == nil then
						local f = self.cfg.onRest
						if f then f(mode, self.rests[mode]) end
					end
				end
			else
				did = false
			end
		elseif self.sched:due("progress", now) then
			writeProgress(self, false)
		elseif self.sched:due("rest_main", now) then
			writeRest(self, "main")
		elseif self.sched:due("rest_free", now) then
			writeRest(self, "free")
		elseif self.sched:heartbeatDue(now) then
			heartbeat(self)
		else
			did = false
		end
	else
		did = false
	end
	return did
end

function SaveSession.step(self: any): boolean
	if self.closed or self.busy then return false end
	self.busy = true
	local ok, did = pcall(stepInner, self)
	self.busy = false
	if not ok then
		log(self, "step failed: " .. tostring(did))
		return false
	end
	self:notify()
	return did :: boolean
end

-- The state to hand the client: progress, the rests found, and the status.
function SaveSession.snapshot(self: any): any
	local status, reason = self:status()
	return { status = status, reason = reason, progress = self.progress, rests = { main = self.rests.main, free = self.rests.free } }
end

-- Leaving or shutting down: write whatever is waiting (progress first, then the rests), release the lock, retrying a few times with the
-- backoff, never beyond `deadline` (an absolute time). Yields. After this the session is closed.
function SaveSession.flush(self: any, deadline: number?)
	local sleep = self.cfg.sleep
	local limit = deadline or (self.now() + SaveRules.FLUSH_DEADLINE)
	-- let a write already in flight finish
	local waited = 0
	while self.busy and self.now() < limit and sleep do
		sleep(0.25)
		waited += 1
		if waited > 200 then break end
	end
	if self.state == "active" and not self.closed then
		self.busy = true
		local attempt = 0
		local progressDone, restsDone = false, { main = false, free = false }
		while attempt < SaveRules.FLUSH_ATTEMPTS and self.state == "active" do
			attempt += 1
			if not progressDone then progressDone = writeProgress(self, true) end
			if self.state ~= "active" then break end
			for _, mode in SaveRules.MODES do
				if not restsDone[mode] then
					restsDone[mode] = (self.restPending[mode] == nil) or writeRest(self, mode)
				end
			end
			if progressDone and restsDone.main and restsDone.free then break end
			if self.now() >= limit or sleep == nil then break end
			sleep(SaveRules.FLUSH_BACKOFF * 2 ^ (attempt - 1))
		end
		self.busy = false
	end
	self.closed = true
	self:notify()
end

return SaveSession
