--!strict
-- The server's persistence service (ROBLOX-39): one SaveSession per player, and the only place a client's message is turned into anything
-- stored. It knows nothing of the engine: the players, the remotes, the clock, the sleep and the thread starter are handed in, so
-- tests/state.luau runs it on the in-memory backend with scripted clients. Persistence.server.luau wires the real ones.
--
-- Trust: the simulation runs on the client, so what a client sends is not authority; it is only a candidate that must be whole and
-- well-formed. Every message is checked before it touches a session (kind, size, depth, types, ranges, and for a rest the full checkpoint
-- check in SaveRest), is rate limited, and a malformed one is dropped and counted, never raised. This is a boundary for corruption safety,
-- not anti-cheat: it is a solo game with no economy, so a dishonest client can only change its own player's save.
--
-- Client to server (ToServer): { kind = "hello", v } | { kind = "progress", progress } | { kind = "rest", mode, record }
-- Server to client (ToClient): { kind = "loaded", v, status, reason, progress, rests = { main?, free? } }
--                              | { kind = "status", status, reason } | { kind = "rest", mode, record }
local SaveRules = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("SaveRules"))
local SaveSession = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Persistence"):WaitForChild("SaveSession"))

local SaveService = {}
SaveService.__index = SaveService

export type Player = { UserId: number, Name: string }
export type Config = {
	backend: any, now: () -> number, sleep: (number) -> (), spawn: ((...any) -> ...any, ...any) -> (),
	send: (Player, { [string]: any }) -> (), jobId: string?, log: ((string) -> ())?,
	keyOf: ((Player) -> string | number)?, -- the name a player's records are filed under (default: their UserId); the test place files each run under a fresh one
}

function SaveService.new(cfg: Config): any
	return setmetatable({ cfg = cfg, entries = {} :: { [any]: any }, counter = 0, departing = 0, stats = { dropped = 0, limited = 0, handled = 0 }, closing = false }, SaveService)
end

local function log(self: any, text: string)
	local l = self.cfg.log
	if l then l(text) end
end

local function bucket(burst: number, perSecond: number, now: number): any
	return { tokens = burst, last = now, burst = burst, rate = perSecond }
end

local function take(b: any, now: number): boolean
	b.tokens = math.min(b.burst, b.tokens + (now - b.last) * b.rate)
	b.last = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

local function sendTo(self: any, player: Player, msg: { [string]: any })
	local ok, err = pcall(self.cfg.send, player, msg)
	if not ok then log(self, "send failed: " .. tostring(err)) end
end

local function loadedMessage(session: any): { [string]: any }
	local snap = session:snapshot()
	return { kind = "loaded", v = SaveRules.PROTOCOL, status = snap.status, reason = snap.reason, progress = snap.progress, rests = snap.rests }
end

-- A player arrived: start their session (the load runs in its own thread) and wait for their hello.
function SaveService.addPlayer(self: any, player: Player)
	if self.entries[player] ~= nil then return end
	self.counter += 1
	local now = self.cfg.now()
	local sessionId = `{self.cfg.jobId or "local"}:{math.floor(now)}:{self.counter}`
	local entry: any = { player = player, hello = false, loaded = false, leaving = false, progressBucket = bucket(SaveRules.PROGRESS_BURST, SaveRules.PROGRESS_PER_SECOND, now), restBucket = bucket(SaveRules.REST_BURST, SaveRules.REST_PER_SECOND, now), helloBucket = bucket(3, 0.2, now) }
	entry.session = SaveSession.new({
		backend = self.cfg.backend, userId = if self.cfg.keyOf then self.cfg.keyOf(player) else player.UserId, sessionId = sessionId, now = self.cfg.now, sleep = self.cfg.sleep,
		log = function(text: string) log(self, text) end,
		onChange = function(status: string, reason: string?)
			if entry.loaded and entry.hello and not entry.leaving then sendTo(self, player, { kind = "status", status = status, reason = reason }) end
		end,
		onLoaded = function(_snap: any)
			if entry.hello and not entry.leaving then sendTo(self, player, loadedMessage(entry.session)) end
		end,
		onRest = function(mode: string, record: any)
			if entry.hello and not entry.leaving then sendTo(self, player, { kind = "rest", mode = mode, record = record }) end
		end,
	})
	self.entries[player] = entry
	self.cfg.spawn(function()
		local ok, err = pcall(function() entry.session:load() end)
		if not ok then
			log(self, "load raised: " .. tostring(err))
			entry.session:demote("load_failed", true)
		end
		entry.loaded = true
		if entry.leaving then
			local flushed, flushError = pcall(function() entry.session:flush() end)
			self.departing -= 1
			if not flushed then log(self, "flush raised: " .. tostring(flushError)) end
			return
		end
		if entry.hello then sendTo(self, player, loadedMessage(entry.session)) end
	end)
end

local function handle(self: any, entry: any, msg: any)
	local now = self.cfg.now()
	local kind = msg.kind
	if kind == "hello" then
		if not take(entry.helloBucket, now) then self.stats.limited += 1; return end
		entry.hello = true
		if entry.loaded then sendTo(self, entry.player, loadedMessage(entry.session)) end
	elseif kind == "progress" then
		if not take(entry.progressBucket, now) then self.stats.limited += 1; return end
		if not entry.session:setProgress(msg.progress) then self.stats.dropped += 1 end
	elseif kind == "rest" then
		if not take(entry.restBucket, now) then self.stats.limited += 1; return end
		local mode = msg.mode
		if type(mode) ~= "string" or not entry.session:setRest(mode, msg.record) then self.stats.dropped += 1 end
	else
		self.stats.dropped += 1
	end
end

-- A message from a client. Never raises, whatever it holds.
function SaveService.onMessage(self: any, player: Player, msg: any)
	local entry = self.entries[player]
	if entry == nil or entry.leaving then return end
	if type(msg) ~= "table" or type(msg.kind) ~= "string" then
		self.stats.dropped += 1
		return
	end
	self.stats.handled += 1
	local ok, err = pcall(function(): any
		handle(self, entry, msg)
		return nil
	end)
	if not ok then
		self.stats.dropped += 1
		log(self, "a message raised: " .. tostring(err))
	end
end

-- The player left: write what is waiting, release the lock. Yields.
function SaveService.removePlayer(self: any, player: Player)
	local entry = self.entries[player]
	if entry == nil then return end
	self.entries[player] = nil
	entry.leaving = true
	self.departing += 1 -- BindToClose must also await a PlayerRemoving write already in flight.
	if not entry.loaded then return end -- the loading thread finishes the job (see addPlayer)
	local ok, err = pcall(function() entry.session:flush() end)
	self.departing -= 1
	if not ok then log(self, "flush raised: " .. tostring(err)) end
end

-- About once a second: every session does its periodic work in its own thread (a slow store does not hold up the others).
function SaveService.step(self: any)
	for _, entry in self.entries do
		if entry.loaded and not entry.leaving then
			self.cfg.spawn(function()
				local ok, err = pcall(function() entry.session:step() end)
				if not ok then log(self, "step raised: " .. tostring(err)) end
			end)
		end
	end
end

-- The server is closing: every session writes what is waiting, all at once, within the deadline. Yields until they are done or time is up.
function SaveService.shutdown(self: any)
	self.closing = true
	local deadline = self.cfg.now() + SaveRules.FLUSH_DEADLINE
	local pending = 0
	for player, entry in self.entries do
		entry.leaving = true
		if entry.loaded then
			pending += 1
			self.cfg.spawn(function()
				local ok, err = pcall(function() entry.session:flush(deadline) end)
				if not ok then log(self, "flush raised: " .. tostring(err)) end
				pending -= 1
			end)
		end
		self.entries[player] = nil
	end
	while (pending > 0 or self.departing > 0) and self.cfg.now() < deadline do
		self.cfg.sleep(0.25)
	end
end

function SaveService.statusOf(self: any, player: Player): (string?, string?)
	local entry = self.entries[player]
	if entry == nil then return nil, nil end
	local pair = { entry.session:status() }
	return pair[1], pair[2]
end

return SaveService
