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
local SaveObservation = require(script.Parent.SaveObservation)
local SaveIntent = require(script.Parent.SaveIntent)
local Request = require(script.Parent.OrdinaryRequestAdmission)

-- Rest observations that grant authority must bypass a provider's read cache.
-- MemoryBackend and other providers without a cache retain their read contract.
-- A failed fresh read is an error; it must never fall back to stale data.
local function readCurrent(self: any, key: string): (boolean, any, string?)
 return Request.request(self,"readFresh",key,nil,nil)
end

local function canonical(v: any): string
	return (Json.canonical(v)) or ""
end

local SaveSession = {}
SaveSession.__index = SaveSession

export type Config = {
	backend: any, userId: number | string, sessionId: string, now: () -> number,
	sleep: ((number) -> ())?, log: ((string) -> ())?, progressSpec: SaveEnvelope.Spec?, -- (a test may hand in a later schema)
	onChange: ((string, string?) -> ())?, onLoaded: ((any) -> ())?, onRest: ((string, any) -> ())?, onLife: ((string,number,string) -> ())?,
	onOffer: ((string,any) -> ())?,
	onDecision: ((any) -> ())?,
	onStored: ((string,number,string,number) -> ())?,
	onRefused: ((string,number,string,number,string) -> ())?,
 admission: any?,
}


function SaveSession.new(cfg: Config): any
	local sched = SaveScheduler.new()
	sched:track("progress", SaveRules.PROGRESS_DEBOUNCE)
	sched:track("release", 0) -- metadata-only cleanup after giving up an owned lease
	local rkey: { [string]: string } = {}
	for _, mode in SaveRules.MODES do
		sched:track("rest_" .. mode, SaveRules.REST_MIN_INTERVAL)
		rkey[mode] = `{SaveRules.KEY_REST}{cfg.userId}_{mode}`
	end
	local self:any=setmetatable({
		cfg = cfg, backend = cfg.backend, id = cfg.sessionId, now = cfg.now, pspec = cfg.progressSpec or SaveProgress.SPEC,
		pkey = SaveRules.KEY_PROGRESS .. tostring(cfg.userId),
		rkey = rkey,
		sched = sched,
		observations = SaveObservation.new(cfg.sessionId), offersEnabled = false,
		intents = SaveIntent.new(cfg.sessionId,cfg.onDecision),
		previewPending = {}, previewNextAt = {}, previewFailures = {},
		state = "loading", reason = nil :: string?, canRetry = false, retryAt = 0,
		progress = SaveProgress.default(), progressTime = 0, storedTime = 0,
		rests = {} :: { [string]: any }, lifeTokens = {} :: {[string]:string}, lifeRequests = {} :: {[string]:any},
		restRevision = {} :: { [string]: string }, -- checksum of the last successfully read/written envelope
		restBase = {} :: { [string]: number }, -- updatedAt of the rest this session last read or wrote (nil: unknown)
		restPending = {} :: { [string]: any }, restPendingTime = {} :: { [string]: number },
		restPendingTag = {} :: {[string]:any},
		restLoaded = {} :: { [string]: boolean }, restRetryAt = 0,
		restProtected = {} :: {[string]:string}, -- unreadable rest slots remain read-only for this visit
		restRejected = {} :: { [string]: boolean }, -- a locally kept rest the server could not accept
		lockHeld = false, busy = false, closed = false,
		lastStatus = "", lastReason = "",
		counters = { requests = 0, writes = 0, rejected = 0 },
	}, SaveSession)
 if cfg.admission then Request.attach(self,cfg.admission) end
 return self
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
	if self.offersEnabled then
		for _,r in self.intents.requests do
			if r.needsCheck and (r.failures or 0)>=3 then return SaveRules.STATUS.saving,"write_failed" end
		end
	end
	if next(self.restRejected) ~= nil then return SaveRules.STATUS.saving, "rest_refused" end
	if self.busy or self.sched:anyDirty() or not SaveSession.restsLoaded(self) then
		local trouble = false
		for _, item in self.sched.items do
			if item.dirty and item.failures >= 3 then trouble = true end
		end
		return SaveRules.STATUS.saving, if trouble then "write_failed" else nil
	end
	if next(self.restProtected) ~= nil then return SaveRules.STATUS.saving, "rest_protected" end
	return SaveRules.STATUS.saved, nil
end

function SaveSession.notify(self: any)
	local status, reason = self:status()
	local r = reason or ""
	local protected=canonical(self.restProtected)
	if status ~= self.lastStatus or r ~= self.lastReason or protected ~= self.lastProtected then
		self.lastProtected=protected
		self.lastStatus, self.lastReason = status, r
		local f = self.cfg.onChange
		if f then f(status, reason) end
	end
end

local function revokeIntents(self: any,reason: string?)
 if not self.offersEnabled then return end
 for mode,r in self.intents.requests do
  self.intents:readonly(r,reason)
  local pending=self.restPending[mode]
  if pending and not SaveRest.isRetired(pending) then
   self.restPending[mode],self.restPendingTime[mode],self.restPendingTag[mode]=nil,nil,nil;self.sched:abandon("rest_"..mode)
  end
 end
end

-- Goes session-only. Gameplay records stay in memory until ownership is recovered
-- (when `retry` is true); a queued metadata-only request may release our old lock.
function SaveSession.demote(self: any, reason: string, retry: boolean)
 self._loadSerial=(self._loadSerial or 0)+1 -- invalidate suspended older acquisitions/reads
	revokeIntents(self,reason)
	-- No yielding store call here: demotion can run inside a message callback.
	-- A later step/flush releases only a lock still owned by this exact session.
	if self.lockHeld then self.sched:markDirty("release", self.now()) end
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
local function attemptLock(self: any): (string, any, number?)
	local now = self.now()
	local verdict = ""
	local info: any = nil
local expected:string?=nil
 local ok, value, err = Request.request(self,"update",self.pkey, function(old: any): any
  now=self.now();expected=nil
  if type(now)~="number" or now~=now or math.abs(now)==math.huge then return nil end
  local op = SaveEnvelope.open(self.pspec, old)
		info = op
		verdict = op.status
		if op.status == "newer" or op.status == "corrupt" or op.status == "invalid" then return nil end
		if op.status == "missing" then
			verdict = "ok"
			local candidate=SaveEnvelope.make(self.pspec, SaveProgress.default(), now, nil, { lock = lockNow(self, now) })
   expected=canonical(candidate);return candidate
		end
		if SaveEnvelope.heldByOther(op.lock, self.id, now, SaveRules.LOCK_STALE) then
			verdict = "locked"
			return nil
		end
		verdict = "ok"
		local candidate=SaveEnvelope.withLock(old, lockNow(self, now));expected=canonical(candidate);return candidate
end,nil)
 if not ok then
  local class=SaveStores.classify(err)
  return if class=="config" then "config" else "failed",{err=err,class=class},nil
 end
 if verdict=="ok" then
  local at=self.now();local lock=if type(value)=="table" then value.lock else nil
  if not expected or expected=="" or canonical(value)~=expected or type(lock)~="table" or lock.session~=self.id
   or type(lock.beat)~="number" or lock.beat~=lock.beat or type(at)~="number" or at~=at or at<lock.beat or at-lock.beat>=SaveRules.LOCK_STALE then
   return "failed",{err="initial lease acknowledgement is not exact and fresh",class="service"},nil
  end
  return verdict,info,lock.beat
 end
 if verdict=="invalid" then verdict="corrupt" end
 return verdict,info,nil
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

local function protectRest(self: any,mode: string,reason: string)
 self.restProtected[mode]=reason
 self.restPending[mode],self.restPendingTime[mode],self.restRejected[mode],self.restPendingTag[mode]=nil,nil,nil,nil
 self.sched:abandon("rest_"..mode)
 -- Retain life request serials so delayed older intents cannot become fresh requests.
end

function SaveSession.protectedSlots(self: any): {[string]:string}
 return Json.copy(self.restProtected)
end

-- Negotiated transport enables previews explicitly. Legacy sessions do not
-- allocate/copy additional whole-world records or issue preview backend reads.
function SaveSession.enableOffers(self: any)
 if self.closed or self.offersEnabled then return end
 self.offersEnabled=true
 -- Negotiation closes the legacy write path, including messages queued before
 -- negotiation. A preview's persisted life identity is not a write credential.
 self.lifeRequests={}
 for _,mode in SaveRules.MODES do
  self.restPending[mode],self.restPendingTime[mode],self.restPendingTag[mode]=nil,nil,nil
  self.sched:abandon("rest_"..mode);self.previewPending[mode]=true
 end
end
function SaveSession.offer(self: any,mode: string): any
 return self.observations:offer(mode)
end
function SaveSession.refreshOffer(self: any,mode: any): boolean
 if self.closed or not self.offersEnabled or type(mode)~="string" or SaveRest.SPECS[mode]==nil then return false end
 self.previewPending[mode]=true;self.previewNextAt[mode]=0;return true
end

local function previewOne(self: any,mode: string)
 local ok,value,err=readCurrent(self,self.rkey[mode])
 if self.closed then return end -- departure can reach its deadline while a read yields
 if not ok then
  local failures=(self.previewFailures[mode] or 0)+1;self.previewFailures[mode]=failures
  self.previewNextAt[mode]=self.now()+SaveScheduler.backoff(failures,SaveStores.classify(err))
  return -- failed read does not invent an empty snapshot or change write bases
 end
 self.previewPending[mode],self.previewNextAt[mode],self.previewFailures[mode]=nil,nil,nil
 local op=SaveEnvelope.open(SaveRest.SPECS[mode],value)
 local opened: SaveEnvelope.Opened?=op
 local raw,protected,kind=value,false,"primary"
 if op.status~="ok" and op.status~="migrated" then
  opened,raw,protected,kind=op.backup,if type(value)=="table" then value.backup else nil,true,"backup"
 end
 if opened and (opened.status=="ok" or opened.status=="migrated") and (kind=="primary" or not SaveRest.isRetired(opened.payload)) and type(raw)=="table" then
  self.observations:publish(mode,opened.payload,{checksum=raw.checksum,updatedAt=opened.updatedAt,life=opened.payload.save_life,kind=kind},protected)
 else self.observations:withdraw(mode) end
 -- Never set rests/restLoaded/restBase/restRevision/lifeTokens from a preview.
 local callback=self.cfg.onOffer
 if callback then pcall(callback,mode,self.observations:offer(mode)) end
end

local function readRests(self: any, maxReads: number?)
 local generation=self._loadSerial
 local start=self.restReadCursor or 1
 local reads=0
 for offset=0,#SaveRules.MODES-1 do
  local index=(start+offset-1)%#SaveRules.MODES+1
  local mode=SaveRules.MODES[index]
  if not self.restLoaded[mode] then
   if maxReads and reads>=maxReads then break end
   reads+=1;self.restReadCursor=index%#SaveRules.MODES+1
			local ok, value, err = readCurrent(self,self.rkey[mode])
   if self.closed or self.state~="active" or not self.lockHeld or self._loadSerial~=generation then return end
			if not ok then
				log(self, `could not read the {mode} rest: {tostring(err)}`)
				self.restRetryAt = self.now() + SaveScheduler.backoff(1, SaveStores.classify(err))
			else
				local spec = SaveRest.SPECS[mode]
				local op = SaveEnvelope.open(spec, value)
				self.restLoaded[mode] = true
				if op.status == "ok" or op.status == "migrated" then
					self.restBase[mode] = op.updatedAt
     self.restRevision[mode] = value.checksum
					self.lifeTokens[mode] = op.payload.save_life
     self.rests[mode] = if SaveRest.isRetired(op.payload) then nil else op.payload
				elseif op.status == "missing" then
					self.restBase[mode] = 0
     self.restRevision[mode] = nil
     self.lifeTokens[mode],self.rests[mode]=nil,nil
				else
					-- A readable backup is offered in memory only. Preserve the original unreadable record for recovery.
					self.restBase[mode] = op.updatedAt or 0
					self.rests[mode],self.lifeTokens[mode]=nil,nil
					local b = op.backup
					if b and (b.status == "ok" or b.status == "migrated") and not SaveRest.isRetired(b.payload) then self.rests[mode] = b.payload end
					log(self, `the {mode} rest is {op.status}: {op.reasons[1] or ""}`)
					protectRest(self,mode,if op.status == "newer" then "newer" else "corrupt")
				end
				local request=self.lifeRequests[mode]
    -- Bind consent to the life AND revision observed when New Life was chosen.
    -- Reacquiring a lease must not silently authorize retiring a different save.
    -- Own retirement markers remain idempotent after an ambiguous write response.
    if not self.offersEnabled and request and not request.done and (op.status=="ok" or op.status=="migrated")
     and (not request.observed or request.baseLife~=op.payload.save_life
      or request.baseTime~=(op.updatedAt or 0) or request.baseRevision~=value.checksum) and op.session~=self.id then
     self:demote("other_session",false)
    end
    local queued=self.restPending[mode]
    if not self.offersEnabled and not self.restProtected[mode] and ((request and request.done and request.token~=self.lifeTokens[mode])
     or (queued and not SaveRest.isRetired(queued) and queued.save_life~=self.lifeTokens[mode])) then
     self:demote("other_session",false) -- another life won while ownership was unavailable; never relabel our queued world
    end
    if request and not request.done then self.rests[mode]=nil end
    -- a rest we hold unsent that is newer than the one stored stays pending; an older one is dropped
				local pending = self.restPendingTime[mode]
				if pending ~= nil and not SaveRest.isRetired(self.restPending[mode]) and (self.restBase[mode] or 0) > pending then
					self.restPending[mode], self.restPendingTime[mode],self.restPendingTag[mode] = nil, nil,nil
					self.sched.items["rest_" .. mode].dirty = false
				end
			end
		end
	end
end

-- Loads the player's records. Yields (backend calls). Returns the state: "active" or "session".
local function loadOriginal(self: any, deferRests: boolean?): (string,boolean?)
	if self.closed then return self.state,false end
 self._loadSerial=(self._loadSerial or 0)+1
 local ticket=self._loadSerial
	revokeIntents(self,"revalidating")
	local verdict, info, acquiredBeat = attemptLock(self)
 if self.closed or self._loadSerial~=ticket then return self.state,false end
	local first = self.state == "loading"
	if verdict == "ok" then
		self.sched:abandon("release") -- a deliberate successful load owns the lease again
		adoptStored(self, info)
		self.state, self.reason, self.lockHeld, self.canRetry = "active", nil, true, false
		self.sched:beat(acquiredBeat)
		self.restLoaded = {} -- read again: another session may have written a rest while this one could not
  self.restRetryAt=0
  self.restReloading=deferRests==true
  if not deferRests then readRests(self) end
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
if self.closed or self._loadSerial~=ticket then return self.state,false end
 if self.state=="active" and self.now()-self.sched.lastBeat>=SaveRules.LOCK_STALE then
  self:demote("other_session",true);return self.state,false
 end
 if first or self.state == "active" then self:notify() end
	return self.state,true
end

function SaveSession.load(self:any,deferRests:boolean?):(string,boolean?)
 if self.ordinaryAdmission then return Request.load(self,loadOriginal,deferRests) end
 return loadOriginal(self,deferRests)
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
local function beginLife(self: any,mode: string,serial: any): boolean
 if self.closed or SaveRest.SPECS[mode]==nil or type(serial)~="number" or serial~=serial or serial<1 or serial>SaveRules.MAX_LIFE_SERIAL or serial~=math.floor(serial) then return false end
 if self.restProtected[mode] then self.counters.rejected+=1;return false end
 local prior=self.lifeRequests[mode]
 if prior and serial<prior.serial then return false end
 if prior and serial==prior.serial then
  if prior.done and self.cfg.onLife then pcall(self.cfg.onLife,mode,serial,prior.token) end
  return true
 end
 local token=`{self.id}:{mode}:{serial}`
 if not SaveRest.validLife(token) then return false end
 self.lifeRequests[mode]={serial=serial,token=token,done=false,observed=self.restLoaded[mode]==true,baseLife=self.lifeTokens[mode],baseTime=self.restBase[mode] or 0,baseRevision=self.restRevision[mode]}
 self.rests[mode],self.restRejected[mode],self.restPendingTag[mode]=nil,nil,nil
 self.restPending[mode]={save_retired=true,save_life=token}
 self.restPendingTime[mode]=self.now()
 self.sched:markDirty("rest_"..mode,self.now());self:notify()
 return true
end

function SaveSession.beginLife(self: any,mode: string,serial: any): boolean
 if self.offersEnabled then return false end
 return beginLife(self,mode,serial)
end

-- Never yields. Only an exact displayed observation (or an explicitly empty-
-- only New Life request) can be bound. Ownership validation is budgeted later.
function SaveSession.requestLife(self: any,kind: any,mode: any,serial: any,offerId: any): boolean
 if self.closed or not self.offersEnabled then return false end
 if mode=="easy" and not self.progress.finished_main then return false end
 local r,created=self.intents:choose(mode,kind,serial,offerId)
 if not r then return false end
 if not created then self.intents:notify(r);return true end
 self.restPending[mode],self.restPendingTime[mode],self.restRejected[mode],self.lifeRequests[mode],self.restPendingTag[mode]=nil,nil,nil,nil,nil
 self.sched:abandon("rest_"..mode)
 if offerId~=nil then
  local selected=self.observations:select(mode,serial,offerId)
  if not selected then self.intents:changed(r,"offer_changed");return true end
  if kind=="continue" and SaveRest.isRetired(selected.record) then self.intents:changed(r,"no_rest");return true end
  r.base,r.protected=selected.identity,selected.protected
 else
  self.observations:clearSelection(mode,serial);r.missingOnly=true
 end
 if kind=="continue" and r.protected then r.needsCheck=false;r.reason="rest_protected" end
 if self.state=="session" and self.reason=="other_session" then self.canRetry=true;self.retryAt=self.now() end
 self.intents:notify(r)
 return true
end

-- Legacy callers intentionally have no life credential; extra Lua return values are ignored here.
function SaveSession.setRest(self: any,mode: string,record: any): boolean
 return self:setRestForLife(mode,record,nil)
end
local function queueRest(self: any, mode: string, record: any,lifeToken: string?,tag: any?): boolean
	if self.closed or SaveRest.SPECS[mode] == nil then return false end
 if self.restProtected[mode] then self.counters.rejected+=1;return false end
 local request=self.lifeRequests[mode]
 if (request and not request.done) or lifeToken~=self.lifeTokens[mode] then
  self.counters.rejected+=1
  return false -- never let a late prior-life rest cross a retirement boundary
 end
-- Validate the exact stored candidate, including our identity metadata, against both size and node caps.
 local stamped=record
 local copyProblem: string?=nil
 if type(record)=="table" and getmetatable(record)==nil then
  stamped={}
  local count=0
  for key,value in record do
   count+=1
   if count>SaveRules.MAX_REST_NODES then copyProblem="too many root values";break end
   stamped[key]=value
  end
  stamped.save_life=self.lifeTokens[mode]
 end
 local problems = if copyProblem then {copyProblem} else SaveRest.check(mode, stamped)
	if #problems > 0 then
		self.counters.rejected += 1
		log(self, `the {mode} rest was refused: {problems[1]}`)
		self.restRejected[mode] = true
		if tag and self.cfg.onRefused then pcall(self.cfg.onRefused,mode,tag.serial,tag.credential,tag.restSerial,"invalid_checkpoint") end
		self:notify()
		return false
	end
	local now = self.now()
	if tag then
		local r=self.intents.requests[mode]
		if not r or not self.intents:authorized(mode,tag.serial,tag.credential,lifeToken) then return false end
		r.receivedSerial=tag.restSerial
	end
	self.restRejected[mode] = nil
 self.restPending[mode], self.restPendingTime[mode] = stamped, now
 self.restPendingTag[mode]=tag
	self.sched:markDirty("rest_" .. mode, now)
	self:notify()
	return true
end

function SaveSession.setRestForLife(self: any,mode: string,record: any,lifeToken: string?): boolean
 if self.offersEnabled then self.counters.rejected+=1;return false end
 return queueRest(self,mode,record,lifeToken)
end
local function storedReceipt(self: any,mode: string,r: any)
 if self.intents.requests[mode]~=r or r.state~="writable" or (r.storedSerial or 0)<1 or r.storedCredential~=r.credential then return end
 if self.cfg.onStored then pcall(self.cfg.onStored,mode,r.serial,r.credential,r.storedSerial) end
end
function SaveSession.setRestForIntent(self: any,mode: string,record: any,lifeToken: any,serial: any,credential: any,restSerial: any?): boolean
 if self.closed or not self.offersEnabled or self.state~="active" or not self.lockHeld or not self.intents:authorized(mode,serial,credential,lifeToken) then
  self.counters.rejected+=1;return false
 end
 local r=self.intents.requests[mode]
 -- Direct trusted model callers may omit a ticket. The wire service always
 -- requires one; each ticket denotes one immutable candidate for this grant.
 local ticket=if restSerial==nil then (r.receivedSerial or 0)+1 else restSerial
 if type(ticket)~="number" or ticket~=ticket or ticket<1 or ticket>SaveRules.MAX_LIFE_SERIAL or ticket~=math.floor(ticket) then return false end
 if ticket<=(r.receivedSerial or 0) then
  if ticket<=(r.storedSerial or 0) then storedReceipt(self,mode,r);return true end
  return ticket==r.receivedSerial -- duplicate queued candidate, never replace it
 end
 return queueRest(self,mode,record,lifeToken,{serial=serial,credential=credential,restSerial=ticket})
end

local function identityOf(op: any,raw: any): any
 if op.status=="missing" then return {missing=true} end
 if op.status~="ok" and op.status~="migrated" then return nil end
 return {checksum=raw.checksum,updatedAt=op.updatedAt or 0,life=op.payload.save_life,kind="primary"}
end
local function sameIdentity(a: any,b: any): boolean
 if not a or not b then return false end
 if a.missing or b.missing then return a.missing==true and b.missing==true end
 return a.checksum==b.checksum and a.updatedAt==b.updatedAt and a.life==b.life and a.kind==b.kind
end
local function intentAllows(self: any,mode: string,record: any,r: any,tag: any?): boolean
 if not r or self.intents.requests[mode]~=r or self.state~="active" or not self.lockHeld or r.needsCheck then return false end
 if SaveRest.isRetired(record) then
  local request=self.lifeRequests[mode]
  return r.kind=="new" and r.retireReady==true and request~=nil and request.serial==r.serial and request.token==record.save_life
 end
 return r.state=="writable" and r.credential~=nil and r.life==record.save_life and tag~=nil and tag.serial==r.serial and tag.credential==r.credential
end

-- One read under ownership, never a write or an implicit rebase to a foreign
-- observation. New without an offer means "only if physically missing".
local function validateIntent(self: any,r: any)
 local mode=r.mode
 if r.protected or self.restProtected[mode] then
  if r.kind=="new" then self.intents:changed(r,"rest_protected") else self.intents:readonly(r,"rest_protected");r.needsCheck=false end
  return
 end
 local ok,raw,err=readCurrent(self,self.rkey[mode])
 if self.closed or self.intents.requests[mode]~=r or self.state~="active" or not self.lockHeld then return end
 if not ok then
  r.failures=(r.failures or 0)+1;r.nextAt=self.now()+SaveScheduler.backoff(r.failures,SaveStores.classify(err));return
 end
 local op=SaveEnvelope.open(SaveRest.SPECS[mode],raw)
 local identity=identityOf(op,raw)
 local request=self.lifeRequests[mode]
 local ownMarker=r.kind=="new" and request and op.status=="ok" and op.session==self.id
  and SaveRest.isRetired(op.payload) and op.payload.save_life==request.token
 local basis=r.expected or r.base
 local agrees=(basis~=nil and sameIdentity(basis,identity)) or (basis==nil and r.missingOnly and op.status=="missing")
 local knownOwn=op.session==self.id and sameIdentity(r.ambiguous,identity)
 if not agrees and not ownMarker and not knownOwn then
  self.intents:changed(r,"rest_changed");self.previewPending[mode]=true;self.previewNextAt[mode]=0
  self:demote("other_session",false);return
 end
 r.failures,r.nextAt,r.needsCheck,r.expected,r.ambiguous=0,nil,false,identity,nil
 self.restLoaded[mode]=true;self.restBase[mode]=op.updatedAt or 0
 self.restRevision[mode]=if type(raw)=="table" then raw.checksum else nil
 self.lifeTokens[mode]=if op.payload then op.payload.save_life else nil
 if ownMarker then
  request.done=true;self.restPending[mode],self.restPendingTime[mode],self.restPendingTag[mode]=nil,nil,nil;self.sched:abandon("rest_"..mode)
  r.established=true
  self.intents:grant(r,request.token)
 elseif r.kind=="continue" or r.established then
  if not op.payload or (SaveRest.isRetired(op.payload) and not r.established) then self.intents:changed(r,"rest_changed");return end
  self.intents:grant(r,self.lifeTokens[mode])
 else
  r.retireReady=true
  if not beginLife(self,mode,r.serial) then self.intents:changed(r,"rest_protected") end
 end
end

-- ---------------------------------------------------------------- writing
-- Writes the progress (merged with what is stored). `release`: also let go of the lock. Returns true when it is stored.
local function writeProgress(self: any, release: boolean): boolean
	local now = self.now()
	local version = self.sched.items.progress.version
	local outcome = ""
	local merged: any = nil
	local newTime = now
	local ok, _, err = Request.request(self,"update",self.pkey, function(old: any): any
  now=self.now()
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
	end,"progress")
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
	if self.restProtected[mode] or not self.restLoaded[mode] or self.restBase[mode] == nil then return false end
	local name = "rest_" .. mode
	local record = self.restPending[mode]
	local tag=self.restPendingTag[mode]
	if record == nil then
		self.sched.items[name].dirty = false
		return true
	end
	local bound=if self.offersEnabled then self.intents.requests[mode] else nil
	if self.offersEnabled and not intentAllows(self,mode,record,bound,tag) then return false end
	if not SaveRest.isRetired(record) and record.save_life~=self.lifeTokens[mode] then
  self.restPending[mode],self.restPendingTime[mode],self.restPendingTag[mode]=nil,nil,nil
  self.sched:abandon(name);self:demote("other_session",false)
  return false
 end
 local now = self.now()
 local version = self.sched.items[name].version
	local spec = SaveRest.SPECS[mode]
	local outcome = ""
	local newTime = now
 local expectedLife=self.lifeTokens[mode]
 local expectedRevision=self.restRevision[mode]
 local writtenRevision: string?=nil
 local observed: any=nil
	local ok, _, err = Request.request(self,"update",self.rkey[mode], function(old: any): any
  now=self.now()
		outcome = ""
  observed=nil
  if self.offersEnabled and not intentAllows(self,mode,record,bound,tag) then outcome="intent_changed";return nil end
  if self.restProtected[mode] then outcome="protected";return nil end
		local op = SaveEnvelope.open(spec, old, false)
		if op.status == "newer" then outcome = "newer"; return nil end
		if op.status == "corrupt" or op.status == "invalid" then outcome = "corrupt"; return nil end
  if bound then
   local identity=identityOf(op,old)
   local knownAmbiguous=op.session==self.id and sameIdentity(bound.ambiguous,identity)
   local sameOwnRecord=op.session==self.id and op.payload~=nil and canonical(op.payload)==canonical(record)
   if not sameIdentity(bound.expected,identity) and not knownAmbiguous and not sameOwnRecord then outcome="superseded";return nil end
   observed=identity
  end
		if (op.status=="ok" or op.status=="migrated") and op.payload.save_life~=expectedLife and op.session~=self.id then
   outcome="superseded";return nil -- life identities protect even simultaneous writes with equal timestamps
  end
  if (op.status=="ok" or op.status=="migrated") and op.session~=self.id and old.checksum~=expectedRevision then
   outcome="superseded";return nil -- equal timestamps/legacy identities do not prove unchanged contents
  end
  local base = self.restBase[mode]
		if (op.status == "ok" or op.status == "migrated") and base ~= nil and (op.updatedAt or 0) > base and op.session ~= self.id then
			outcome = "superseded"
			return nil
		end
		if (op.status == "ok") and canonical(op.payload) == canonical(record) then
			-- already stored (an earlier try whose answer was lost): nothing to write, and the backup must not become a copy of it
			newTime = op.updatedAt or now
   writtenRevision=old.checksum
			outcome = "ok"
			return nil
		end
		newTime = math.max(now, op.updatedAt or 0)
		outcome = "ok"
		local made=SaveEnvelope.make(spec, record, newTime, old, { session = self.id })
  writtenRevision=made.checksum
  return made
	end,name)
	if not ok then
  if bound and self.intents.requests[mode]==bound then
   if observed then bound.expected=observed end
   if writtenRevision then bound.ambiguous={checksum=writtenRevision,updatedAt=newTime,life=record.save_life,kind="primary"} end
  end
		local class = SaveStores.classify(err)
		if class == "value" then
			log(self, `the {mode} rest cannot be stored: {tostring(err)}`)
			self.restPending[mode], self.restPendingTime[mode],self.restPendingTag[mode] = nil, nil,nil
			self.sched:abandon(name)
			self:demote("write_failed", false)
			return false
		end
		local wait = self.sched:failed(name, now, class)
		log(self, `{mode} rest write failed ({class}, retry in {wait} s): {tostring(err)}`)
		return false
	end
	if outcome == "ok" then
  if bound and self.intents.requests[mode]==bound then
   -- The store may finish before ownership is revoked but answer afterward.
   -- Remember our confirmed authored revision without re-enabling permission.
   bound.expected={checksum=writtenRevision,updatedAt=newTime,life=record.save_life,kind="primary"};bound.ambiguous=nil
  end
  if bound and not intentAllows(self,mode,record,bound,tag) then return false end
		self.restBase[mode] = newTime
  self.restRevision[mode] = writtenRevision
		self.lifeTokens[mode]=record.save_life
  self.rests[mode] = if SaveRest.isRetired(record) then nil else record
  local request=self.lifeRequests[mode]
  if SaveRest.isRetired(record) and request and request.token==record.save_life then
   request.done=true
   if not self.offersEnabled and self.cfg.onLife then pcall(self.cfg.onLife,mode,request.serial,request.token) end
  end
  if bound then
   bound.expected={checksum=writtenRevision,updatedAt=newTime,life=record.save_life,kind="primary"};bound.ambiguous=nil
   if SaveRest.isRetired(record) then bound.established=true;self.intents:grant(bound,record.save_life) end
   if tag then bound.storedSerial=tag.restSerial;bound.storedCredential=tag.credential;storedReceipt(self,mode,bound) end
   self.observations:publish(mode,record,bound.expected,false)
   if self.cfg.onOffer then pcall(self.cfg.onOffer,mode,self.observations:offer(mode)) end
  end
  if self.restPending[mode] == record then self.restPending[mode], self.restPendingTime[mode],self.restPendingTag[mode] = nil, nil,nil end
		self.sched:succeeded(name, now, version)
		self.counters.writes += 1
		return true
	end
	if outcome == "superseded" then
		if bound then self.intents:changed(bound,"rest_changed");self.previewPending[mode]=true;self.previewNextAt[mode]=0 end
		self:demote("other_session", bound==nil)
	elseif outcome == "newer" then
		protectRest(self,mode,"newer")
	elseif outcome == "corrupt" then
		protectRest(self,mode,"corrupt")
	end
	return false
end

-- Giving up a conflicting life must not leave a freshly acquired progress lock
-- blocking the next visit until expiry. This writes no progress/rest candidate:
-- preserve the entire raw envelope and backup, changing only our own lock.
local function releaseOwnedLock(self: any): boolean
	local now = self.now()
	local version = self.sched.items.release.version
	local released = false
	local ok, _, err = Request.request(self,"update",self.pkey, function(old: any): any
		released = false -- UpdateAsync may invoke this callback more than once
		if self.state ~= "session" then return nil end
		local op = SaveEnvelope.open(self.pspec, old, false)
		if op.status ~= "ok" and op.status ~= "migrated" then return nil end
		if type(op.lock) ~= "table" or op.lock.session ~= self.id then return nil end
		released = true
		return SaveEnvelope.withLock(old, nil)
	end,"release")
	if not ok then
		local class = SaveStores.classify(err)
		local wait = self.sched:failed("release", now, class)
		log(self, `lease cleanup failed ({class}, retry in {wait} s): {tostring(err)}`)
		return false
	end
	self.sched:succeeded("release", now, version)
	if released then self.counters.writes += 1 end
	return true
end

-- Refreshes the lock when no write has done it lately.
local function heartbeat(self: any)
	local now = self.now()
	local outcome = ""
	local ok, _, err = Request.request(self,"update",self.pkey, function(old: any): any
  now=self.now()
		outcome = ""
		local op = SaveEnvelope.open(self.pspec, old, false)
		if op.status == "missing" then outcome = "missing"; return nil end
		if op.status == "newer" then outcome = "newer"; return nil end
		if op.status == "corrupt" or op.status == "invalid" then outcome = "corrupt"; return nil end
		if SaveEnvelope.heldByOther(op.lock, self.id, now, SaveRules.LOCK_STALE) then outcome = "locked"; return nil end
		outcome = "ok"
		return SaveEnvelope.withLock(old, lockNow(self, now))
	end,nil)
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

local function capacity(self:any,now:number):boolean
 return self.ordinaryAdmission~=nil or self.sched:budgetOk(now)
end
local function due(self:any,name:string,now:number):boolean
 if not self.ordinaryAdmission then return self.sched:due(name,now) end
 local item=self.sched.items[name];return item.dirty and now>=item.nextAt
end
local function beatDue(self:any,now:number):boolean
 return now-self.sched.lastBeat>=SaveRules.HEARTBEAT and capacity(self,now)
end

-- One pass of the periodic work; the server calls it about once a second. Does at most one request per call. Returns whether it asked.
local function stepInner(self: any): boolean
	local now = self.now()
	local did = true
	if self.state == "session" then
		if self.sched:isDirty("release") then
			if due(self,"release",now) then releaseOwnedLock(self) else did = false end
		elseif self.canRetry and now >= self.retryAt and capacity(self,now) then
			self.retryAt = now + SaveRules.RETRY_LOAD
			local wasReason = self.reason
			local _,applied=self:load(true) -- one lock request; subsequent steps read the rest slots
			if applied and not self.closed and SaveSession.isActive(self) then
				log(self, `holds the record again (was: {tostring(wasReason)})`)
				local f = self.cfg.onLoaded
				if f then f(self:snapshot()) end
			end
		else
			did = false
		end
	elseif self.state == "active" then
		-- A failed rest read must not starve lock renewal for a live player.
		if due(self,"progress",now) then
			writeProgress(self, false) -- also renews the lock
		elseif beatDue(self,now) then
			heartbeat(self)
		elseif not SaveSession.restsLoaded(self) then
			if now >= self.restRetryAt and capacity(self,now) then
				local before: { [string]: any } = {}
    local beforeLoaded: {[string]:boolean} = {}
				for _, mode in SaveRules.MODES do before[mode] = self.rests[mode];beforeLoaded[mode]=self.restLoaded[mode]==true end
    local generation=self._loadSerial
				readRests(self,1)
    if self.closed or self.state~="active" or not self.lockHeld or self._loadSerial~=generation then return true end
				for _, mode in SaveRules.MODES do
					if self.restLoaded[mode] and self.rests[mode] ~= nil and (before[mode] == nil or (self.restReloading and not beforeLoaded[mode])) then
						local f = self.cfg.onRest
						if f then f(mode, self.rests[mode]) end
					end
				end
    if self.restReloading and self.state=="active" and SaveSession.restsLoaded(self) then
     self.restReloading=false
    end
			else
				did = false
			end
		else
			did = false
			if self.offersEnabled and capacity(self,now) then
				for _,mode in SaveRules.MODES do
					local r=self.intents.requests[mode]
					if r and r.needsCheck and now>=(r.nextAt or 0) then validateIntent(self,r);did=true;break end
				end
			end
			if not did then
				for _, mode in SaveRules.MODES do
					if due(self,"rest_"..mode,now) then
						writeRest(self, mode)
						did = true
						break
					end
				end
			end
		end
	else
		did = false
	end
	if not did and self.offersEnabled and (self.state=="session" or self.state=="active") and capacity(self,now) then
		for _,mode in SaveRules.MODES do
			if self.previewPending[mode] and now>=(self.previewNextAt[mode] or 0) then
				previewOne(self,mode);did=true;break -- at most one preview request per step
			end
		end
	end
	return did
end

local function stepOriginal(self: any): boolean
	if self.closed or self.busy then return false end
	self.busy = true
	local ok, did = pcall(stepInner, self)
	self.busy = false
	if not ok then
if (did::any)~=Request.ABORT then log(self,"step failed: "..tostring(did)) end
		return false
	end
	if not self.closed then self:notify() end
	return did :: boolean
end

local function workDue(self:any,now:number):boolean
 if self.state=="session" then
  if self.sched:isDirty("release") then if due(self,"release",now) then return true end
  elseif self.canRetry and now>=self.retryAt then return true end
 elseif self.state=="active" then
  if due(self,"progress",now) or beatDue(self,now) then return true end
  if not self:restsLoaded() then if now>=self.restRetryAt then return true end
  else
   if self.offersEnabled then for _,r in self.intents.requests do if r.needsCheck and now>=(r.nextAt or 0) then return true end end end
   for _,mode in SaveRules.MODES do if due(self,"rest_"..mode,now) then return true end end
  end
 end
 if self.offersEnabled and (self.state=="active" or self.state=="session") then
  for _,mode in SaveRules.MODES do if self.previewPending[mode] and now>=(self.previewNextAt[mode] or 0) then return true end end
 end
 return false
end
function SaveSession.step(self:any):boolean
 if self.ordinaryAdmission then return Request.step(self,stepOriginal,workDue) end
 return stepOriginal(self)
end

-- The state to hand the client: progress, the rests found, and the status.
function SaveSession.snapshot(self: any): any
	local status, reason = self:status()
	local rests: { [string]: any } = {}
	for _, mode in SaveRules.MODES do
  local request=self.lifeRequests[mode]
  if (not request or request.done) and (not self.restReloading or self.restLoaded[mode]) then rests[mode]=self.rests[mode] end
 end
 return { status = status, reason = reason, progress = self.progress, rests = rests, lives = Json.copy(self.lifeTokens), protected = self:protectedSlots() }
end

-- Leaving/shutdown keeps ownership until the pending records finish; a new visit must not load half a flush.
local function flushOriginal(self: any, deadline: number?)
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
				if self.offersEnabled then
					for _,mode in SaveRules.MODES do
						local r=self.intents.requests[mode]
						if r and r.needsCheck and self.state=="active" and self.now()<limit then validateIntent(self,r) end
						if r and r.needsCheck then restsDone=false end
					end
				end
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
	-- Demotion during the flush above also comes through here. No rest/progress
	-- merge is allowed after demotion, even on departure; cleanup is metadata only.
	if self.state == "session" and self.sched:isDirty("release") then
		self.busy = true
		local attempt = 0
		while attempt < SaveRules.FLUSH_ATTEMPTS and self.now() < limit do
			attempt += 1
			if releaseOwnedLock(self) then break end
			if sleep == nil or self.now() >= limit then break end
			sleep(math.min(SaveRules.FLUSH_BACKOFF * 2 ^ (attempt - 1), math.max(0, limit - self.now())))
		end
		self.busy = false
	end
	self.closed, self.flushing = true, false
	self:notify()
end

function SaveSession.flush(self:any,deadline:number?)
 if self.ordinaryAdmission then Request.flush(self,flushOriginal,deadline) else flushOriginal(self,deadline) end
end

return SaveSession
