--!strict
-- When a save is written (ROBLOX-39): only decisions, no store and no clock of its own (the caller passes `now`, in seconds). It keeps, for
-- each thing worth saving, whether it has changed since the last good write, the earliest time to try again, and how often it has failed;
-- plus the lock's heartbeat and the one-minute request budget.
--   * a change marks the thing dirty; progress is written at most once per PROGRESS_DEBOUNCE (changes in between are coalesced into the
--     one write), a rest at most once per REST_MIN_INTERVAL (a key takes a write about every 6 s)
--   * a failure keeps it dirty and waits BACKOFF_BASE * 2^(failures - 1) seconds, up to BACKOFF_CAP (a throttle waits twice as long; a
--     configuration error waits the cap)
--   * a success clears it, unless it changed again while the write was in flight (the version counter), when it stays dirty
--   * the budget: at most REQUESTS_PER_MINUTE requests started in any minute; leaving the game or shutting down may go past it
local SaveRules = require(script.Parent.Parent.Data.SaveRules)

local SaveScheduler = {}
SaveScheduler.__index = SaveScheduler

export type Item = { dirty: boolean, version: number, sentVersion: number, nextAt: number, lastWriteAt: number, failures: number, minInterval: number, lastClass: string }

function SaveScheduler.new(): any
	return setmetatable({ items = {} :: { [string]: Item }, started = {} :: { number }, lastBeat = -1e9 }, SaveScheduler)
end

function SaveScheduler.track(self: any, name: string, minInterval: number)
	self.items[name] = { dirty = false, version = 0, sentVersion = 0, nextAt = 0, lastWriteAt = -1e9, failures = 0, minInterval = minInterval, lastClass = "" }
end

-- Something changed. The first change of a clean item sets when it is due; later changes keep that time (they join the same write).
function SaveScheduler.markDirty(self: any, name: string, now: number)
	local it: Item = self.items[name]
	it.version += 1
	if not it.dirty then
		it.dirty = true
		it.nextAt = math.max(now, it.lastWriteAt + it.minInterval)
	end
end

function SaveScheduler.isDirty(self: any, name: string): boolean
	return self.items[name].dirty
end

function SaveScheduler.anyDirty(self: any): boolean
	for _, it in self.items do if it.dirty then return true end end
	return false
end

function SaveScheduler.failures(self: any, name: string): number
	return self.items[name].failures
end

-- How many requests were started in the last minute.
local function recent(self: any, now: number): number
	local keep: { number } = {}
	for _, t in self.started do if now - t < 60 then table.insert(keep, t) end end
	self.started = keep
	return #keep
end

function SaveScheduler.budgetOk(self: any, now: number): boolean
	return recent(self, now) < SaveRules.REQUESTS_PER_MINUTE
end

-- A request is starting (counts against the budget). Returns the version being written, to hand back to `succeeded`.
function SaveScheduler.begin(self: any, name: string?, now: number): number
	table.insert(self.started, now)
	if name == nil then return 0 end
	local it: Item = self.items[name]
	it.sentVersion = it.version
	return it.version
end

-- Is this item due: dirty, its time has come, and the budget allows a request?
function SaveScheduler.due(self: any, name: string, now: number): boolean
	local it: Item = self.items[name]
	return it.dirty and now >= it.nextAt and self:budgetOk(now)
end

function SaveScheduler.succeeded(self: any, name: string, now: number, version: number)
	local it: Item = self.items[name]
	it.failures = 0
	it.lastWriteAt = now
	it.lastClass = ""
	if it.version == version then
		it.dirty = false
	else -- changed while it was being written: still dirty, due once the interval has passed
		it.nextAt = math.max(now, now + it.minInterval)
	end
end

function SaveScheduler.backoff(failures: number, class: string): number
	local n = math.max(failures, 1)
	local base = SaveRules.BACKOFF_BASE * 2 ^ (n - 1)
	if class == "throttle" then base *= 2 end
	if class == "config" then base = SaveRules.BACKOFF_CAP end
	return math.min(base, SaveRules.BACKOFF_CAP)
end

function SaveScheduler.failed(self: any, name: string, now: number, class: string): number
	local it: Item = self.items[name]
	it.failures += 1
	it.lastClass = class
	local wait = SaveScheduler.backoff(it.failures, class)
	it.nextAt = now + wait
	return wait
end

-- Gives up on an item whose current content can never be stored (class "value"): clean again, nothing pending.
function SaveScheduler.abandon(self: any, name: string)
	local it: Item = self.items[name]
	it.dirty = false
	it.failures = 0
end

function SaveScheduler.heartbeatDue(self: any, now: number): boolean
	return now - self.lastBeat >= SaveRules.HEARTBEAT and self:budgetOk(now)
end

function SaveScheduler.beat(self: any, now: number)
	self.lastBeat = now
end

return SaveScheduler
