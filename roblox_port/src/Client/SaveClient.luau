--!strict
-- The client's side of persistent saves (ROBLOX-39). It looks for the server's remotes, says hello, hears the saved state, and sends the
-- player's progress and rests up, throttled. It never decides what is saved (the server owns the DataStore and checks everything it is
-- sent) and the game never waits on it for long: with no remotes, no reply, or a server that says saving is off, the game plays exactly as
-- it did before saves existed, with the notebook and rests lasting the session.
--   * update(now): once per frame. Finds the remotes, says hello (again every CLIENT_HELLO_GAP seconds until answered, CLIENT_HELLO_TRIES times),
--     sends queued progress and rests when their gaps allow.
--   * waiting(): the start menu may wait while this is true: the remotes are being looked for (CLIENT_WAIT_REMOTES seconds) or the first reply
--     is awaited (CLIENT_WAIT_REPLY seconds). It is never true for long.
--   * status(): ("saved" | "saving" | "session", reason). Before any reply: nil. With no server: ("session", "offline").
-- `cfg.rules` is Data/SaveRules; `cfg.findRemotes()` returns { server, client } (RemoteEvents) or nil; the callbacks hand the server's messages up.
local SaveClient = {}
SaveClient.__index = SaveClient

export type Config = {
	rules: any, now: () -> number, findRemotes: () -> any?,
	onLoaded: (any) -> (), onRest: (string, any) -> (), onStatus: (string, string?) -> (),
	build: () -> any, -- the progress to send now (called only when something changed and the gap allows)
}

function SaveClient.new(cfg: Config): any
	local now = cfg.now()
	return setmetatable({
		cfg = cfg, born = now, remotes = nil :: any, phase = "searching", helloAt = -1e9, helloTries = 0,
		lastProgress = -1e9, dirty = false, pendingRest = {} :: { [string]: any }, lastRest = {} :: { [string]: number },
		st = nil :: string?, why = nil :: string?, sent = { progress = 0, rest = 0, hello = 0 },
	}, SaveClient)
end

local function receive(self: any, msg: any)
	if type(msg) ~= "table" or type(msg.kind) ~= "string" then return end
	if msg.kind == "loaded" then
		self.phase = "ready"
		self.st, self.why = msg.status, msg.reason
		self.cfg.onLoaded(msg)
		self.cfg.onStatus(msg.status, msg.reason)
	elseif msg.kind == "status" then
		self.st, self.why = msg.status, msg.reason
		self.cfg.onStatus(msg.status, msg.reason)
	elseif msg.kind == "rest" then
		if type(msg.mode) == "string" then self.cfg.onRest(msg.mode, msg.record) end
	end
end
SaveClient.receive = receive

local function connect(self: any, remotes: any)
	self.remotes = remotes
	self.phase = "hello"
	local ev = remotes.client.OnClientEvent
	ev:Connect(function(msg: any)
		local ok = pcall(receive, self, msg)
		if not ok then self.cfg.onStatus("session", "offline") end
	end)
end

function SaveClient.markDirty(self: any)
	self.dirty = true
end

function SaveClient.sendRest(self: any, mode: string, record: any)
	self.pendingRest[mode] = record
end

function SaveClient.waiting(self: any): boolean
	local t = self.cfg.now()
	local rules = self.cfg.rules
	if self.phase == "searching" then return t - self.born < rules.CLIENT_WAIT_REMOTES end
	if self.phase == "hello" then return t - self.born < rules.CLIENT_WAIT_REMOTES + rules.CLIENT_WAIT_REPLY and self.helloTries <= rules.CLIENT_HELLO_TRIES end
	return false
end

function SaveClient.status(self: any): (string?, string?)
	if self.st ~= nil then return self.st, self.why end
	if self.phase == "searching" and self.cfg.now() - self.born >= self.cfg.rules.CLIENT_WAIT_REMOTES then return "session", "offline" end
	if self.phase == "hello" and not self:waiting() then return "session", "offline" end
	return nil, nil
end

function SaveClient.connected(self: any): boolean
	return self.phase == "ready"
end

function SaveClient.update(self: any)
	local t = self.cfg.now()
	local rules = self.cfg.rules
	if self.phase == "searching" then
		local remotes = self.cfg.findRemotes()
		if remotes ~= nil then
			connect(self, remotes)
		else
			return
		end
	end
	if self.phase == "hello" and t - self.helloAt >= rules.CLIENT_HELLO_GAP and self.helloTries < rules.CLIENT_HELLO_TRIES then
		self.helloAt = t
		self.helloTries += 1
		self.sent.hello += 1
		self.remotes.server:FireServer({ kind = "hello", v = rules.PROTOCOL })
	end
	if self.dirty and t - self.lastProgress >= rules.CLIENT_PROGRESS_GAP then
		self.dirty = false
		self.lastProgress = t
		local payload = self.cfg.build()
		if payload ~= nil then
			self.sent.progress += 1
			self.remotes.server:FireServer({ kind = "progress", progress = payload })
		end
	end
	for mode, record in self.pendingRest do
		if t - (self.lastRest[mode] or -1e9) >= rules.CLIENT_PROGRESS_GAP * 2 then
			self.pendingRest[mode] = nil
			self.lastRest[mode] = t
			self.sent.rest += 1
			self.remotes.server:FireServer({ kind = "rest", mode = mode, record = record })
		end
	end
end

return SaveClient
