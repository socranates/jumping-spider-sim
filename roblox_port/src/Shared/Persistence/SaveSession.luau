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
	backend: any, userId: number | string, sessionId: string, now: () -> number,
	sleep: ((number) -> ())?, log: ((string) -> ())?, progressSpec: SaveEnvelope.Spec?, -- (a test may hand in a later schema)
	onChange: ((string, string?) -> ())?, onLoaded: ((any) -> ())?, onRest: ((string, any) -> ())?, onLife: ((string,number,string) -> ())?,
}


function SaveSession.new(cfg: Config): any
	local sched = SaveScheduler.new()
	sched:track("progress", SaveRules.PROGRESS_DEBOUNCE)
	local rkey: { [string]: string } = {}
	for _, mode in SaveRules.MODES do
		sched:track("rest_" .. mode, SaveRules.REST_MIN_INTERVAL)
		rkey[mode] = `{SaveRules.KEY_REST}{cfg.userId}_{mode}`
	end
	return setmetatable({
		cfg = cfg, backend = cfg.backend, id = cfg.sessionId, now = cfg.now, pspec = cfg.progressSpec or SaveProgress.SPEC,
		pkey = SaveRules.KEY_PROGRESS .. tostring(cfg.userId),
		rkey = rkey,
		sched = sched,
		state = "loading", reason = nil :: string?, canRetry = false, retryAt = 0,
		progress = SaveProgress.default(), progressTime = 0, storedTime = 0,
		rests = {} :: { [string]: any }, lifeTokens = {} :: {[string]:string}, lifeRequests = {} :: {[string]:any},
		restBase = {} :: { [string]: number }, -- updatedAt of the rest this session last read or wrote (nil: unknown)
		restPending = {} :: { [string]: any }, restPendingTime = {} :: { [string]: number },
		restLoaded = {} :: { [string]: boolean }, restRetryAt = 0,
		restRejected = {} :: { [string]: boolean }, -- a locally kept rest the server could not accept
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

-- Every slot's rest has been read (or found missing) at least once.
function SaveSession.restsLoaded(self: any): boolean
	for _, mode in SaveRules.MODES do
		if not self.restLoaded[mode] then return false end
	end
	return true
end

function SaveSession.isActive(self: any): boolean
	return self.state == "active"
end

function SaveSession.status(self: any): (string, string?)
	if self.state == "session" then return SaveRules.STATUS.session, self.reason end
	if self.state == "loading" then return SaveRules.STATUS.saving, nil end
	if next(self.restRejected) ~= nil then return SaveRules.STATUS.saving, "rest_refused" end
	if self.busy or self.sched:anyDirty() or not SaveSession.restsLoaded(self) then
		local trouble = false
		for _, item in self.sched.items do
			if item.dirty and item.failures >= 3 then trouble = true end
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
					self.lifeTokens[mode] = op.payload.save_life
     self.rests[mode] = if SaveRest.isRetired(op.payload) then nil else op.payload
				elseif op.status == "missing" then
					self.restBase[mode] = 0
     self.lifeTokens[mode],self.rests[mode]=nil,nil
				else
					-- A readable backup is offered in memory only. Preserve the original unreadable record for recovery.
					self.restBase[mode] = op.updatedAt or 0
					local b = op.backup
					if b and (b.status == "ok" or b.status == "migrated") and not SaveRest.isRetired(b.payload) then self.rests[mode] = b.payload end
					log(self, `the {mode} rest is {op.status}: {op.reasons[1] or ""}`)
					self:demote(if op.status == "newer" then "newer" else "corrupt", false)
				end
				local request=self.lifeRequests[mode]
    local queued=self.restPending[mode]
    if (request and request.done and request.token~=self.lifeTokens[mode])
     or (queued and not SaveRest.isRetired(queued) and queued.save_life~=self.lifeTokens[mode]) then
     self:demote("other_session",false) -- another life won while ownership was unavailable; never relabel our queued world
    end
    if request and not request.done then self.rests[mode]=nil end
    -- a rest we hold unsent that is newer than the one stored stays pending; an older one is dropped
				local pending = self.restPendingTime[mode]
				if pending ~= nil and not SaveRest.isRetired(self.restPending[mode]) and (self.restBase[mode] or 0) > pending then
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
	local big = SaveRest.bounded(payload, SaveRules.MAX_PROGRESS_NODES, SaveRules.MAX_PROGRESS_DEPTH)
	if big then
		self.counters.rejected += 1
		log(self, "progress refused: " .. big)
		return false
	end
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

-- A session-local increasing intent makes retries idempotent and later New Life choices supersede earlier ones.
-- The marker goes through the same guarded UpdateAsync and backup path as a rest; never DeleteAsync.
function SaveSession.beginLife(self: any,mode: string,serial: any): boolean
 if self.closed or SaveRest.SPECS[mode]==nil or type(serial)~="number" or serial~=serial or serial<1 or serial>SaveRules.MAX_LIFE_SERIAL or serial~=math.floor(serial) then return false end
 local prior=self.lifeRequests[mode]
 if prior and serial<prior.serial then return false end
 if prior and serial==prior.serial then
  if prior.done and self.cfg.onLife then pcall(self.cfg.onLife,mode,serial,prior.token) end
  return true
 end
 local token=`{self.id}:{mode}:{serial}`
 if not SaveRest.validLife(token) then return false end
 self.lifeRequests[mode]={serial=serial,token=token,done=false}
 self.rests[mode],self.restRejected[mode]=nil,nil
 self.restPending[mode]={save_retired=true,save_life=token}
 self.restPendingTime[mode]=self.now()
 self.sched:markDirty("rest_"..mode,self.now());self:notify()
 return true
end

-- Legacy callers intentionally have no life credential; extra Lua return values are ignored here.
function SaveSession.setRest(self: any,mode: string,record: any): boolean
 return self:setRestForLife(mode,record,nil)
end
function SaveSession.setRestForLife(self: any, mode: string, record: any,lifeToken: string?): boolean
	if self.closed or SaveRest.SPECS[mode] == nil then return false end
 local request=self.lifeRequests[mode]
 if (request and not request.done) or lifeToken~=self.lifeTokens[mode] then
  self.counters.rejected+=1
  return false -- never let a late prior-life rest cross a retirement boundary
 end
 local problems = SaveRest.check(mode, record)
	if #problems > 0 then
		self.counters.rejected += 1
		log(self, `the {mode} rest was refused: {problems[1]}`)
		self.restRejected[mode] = true
		self:notify()
		return false
	end
	local now = self.now()
	self.restRejected[mode] = nil
	local stamped={}
 for key,value in record do stamped[key]=value end
 stamped.save_life=self.lifeTokens[mode]
 self.restPending[mode], self.restPendingTime[mode] = stamped, now
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
			self:demote("write_failed", false)
			return false
		end
		local wait = self.sched:failed("progress", now, class)
		log(self, `progress write failed ({class}, retry in {wait} s): {tostring(err)}`)
		return false
	end
	if outcome == "ok" then
		-- UpdateAsync yields after its callback. Keep progress that arrived while the request was in flight.
		self.progress = SaveProgress.merge(merged, self.progress, newTime, self.progressTime)
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
	-- Never overwrite a record whose load failed, including during shutdown.
	if not self.restLoaded[mode] or self.restBase[mode] == nil then return false end
	local name = "rest_" .. mode
	local record = self.restPending[mode]
	if record == nil then
		self.sched.items[name].dirty = false
		return true
	end
	if not SaveRest.isRetired(record) and record.save_life~=self.lifeTokens[mode] then
  self.restPending[mode],self.restPendingTime[mode]=nil,nil
  self.sched:abandon(name);self:demote("other_session",false)
  return false
 end
 local now = self.now()
 local version = self.sched:begin(name, now)
	self.counters.requests += 1
	local spec = SaveRest.SPECS[mode]
	local outcome = ""
	local newTime = now
 local expectedLife=self.lifeTokens[mode]
	local ok, _, err = self.backend:update(self.rkey[mode], function(old: any): any
		outcome = ""
		local op = SaveEnvelope.open(spec, old, false)
		if op.status == "newer" then outcome = "newer"; return nil end
		if op.status == "corrupt" or op.status == "invalid" then outcome = "corrupt"; return nil end
		if (op.status=="ok" or op.status=="migrated") and op.payload.save_life~=expectedLife and op.session~=self.id then
   outcome="superseded";return nil -- life identities protect even simultaneous writes with equal timestamps
  end
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
			self:demote("write_failed", false)
			return false
		end
		local wait = self.sched:failed(name, now, class)
		log(self, `{mode} rest write failed ({class}, retry in {wait} s): {tostring(err)}`)
		return false
	end
	if outcome == "ok" then
		self.restBase[mode] = newTime
		self.lifeTokens[mode]=record.save_life
  self.rests[mode] = if SaveRest.isRetired(record) then nil else record
  local request=self.lifeRequests[mode]
  if SaveRest.isRetired(record) and request and request.token==record.save_life then
   request.done=true
   if self.cfg.onLife then pcall(self.cfg.onLife,mode,request.serial,request.token) end
  end
  if self.restPending[mode] == record then self.restPending[mode], self.restPendingTime[mode] = nil, nil end
		self.sched:succeeded(name, now, version)
		self.counters.writes += 1
		return true
	end
	if outcome == "superseded" then
		self:demote("other_session", true)
	elseif outcome == "newer" then
		self:demote("newer", false)
	elseif outcome == "corrupt" then
		self:demote("corrupt", false)
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
		-- A failed rest read must not starve lock renewal for a live player.
		if self.sched:due("progress", now) then
			writeProgress(self, false) -- also renews the lock
		elseif self.sched:heartbeatDue(now) then
			heartbeat(self)
		elseif not SaveSession.restsLoaded(self) then
			if now >= self.restRetryAt and self.sched:budgetOk(now) then
				local before: { [string]: any } = {}
				for _, mode in SaveRules.MODES do before[mode] = self.rests[mode] end
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
		else
			did = false
			for _, mode in SaveRules.MODES do
				if self.sched:due("rest_" .. mode, now) then
					writeRest(self, mode)
					did = true
					break
				end
			end
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
	local rests: { [string]: any } = {}
	for _, mode in SaveRules.MODES do
  local request=self.lifeRequests[mode]
  if not request or request.done then rests[mode]=self.rests[mode] end
 end
 return { status = status, reason = reason, progress = self.progress, rests = rests, lives = Json.copy(self.lifeTokens) }
end

-- Leaving/shutdown keeps ownership until the pending records finish; a new visit must not load half a flush.
function SaveSession.flush(self: any, deadline: number?)
	if self.closed or self.flushing then return end
	self.flushing = true
	local sleep = self.cfg.sleep
	local limit = deadline or (self.now() + SaveRules.FLUSH_DEADLINE)
	while self.busy and self.now() < limit and sleep do sleep(0.25) end
	if self.busy or self.now() >= limit then
		self.closed, self.flushing = true, false
		return -- never overlap an in-flight request; its lock will expire if it cannot finish
	end
	if self.state == "active" then
		self.busy = true
		local attempt = 0
		while attempt < SaveRules.FLUSH_ATTEMPTS and self.state == "active" and self.now() < limit do
			attempt += 1
			-- Also checks ownership before touching a rest, even when progress itself is unchanged.
			local progressDone = writeProgress(self, false)
			local restsDone = true
			if progressDone and self.state == "active" then
				for _, mode in SaveRules.MODES do
					if self.restPending[mode] ~= nil then
						if self.now() >= limit or self.state ~= "active" or not writeRest(self, mode) then restsDone = false end
					end
				end
				if restsDone and self.state == "active" and self.now() < limit then
					if writeProgress(self, true) then break end -- release only after every rest has completed
				end
			end
			if self.now() >= limit or sleep == nil then break end
			sleep(math.min(SaveRules.FLUSH_BACKOFF * 2 ^ (attempt - 1), math.max(0, limit - self.now())))
		end
		self.busy = false
	end
	self.closed, self.flushing = true, false
	self:notify()
end

return SaveSession
