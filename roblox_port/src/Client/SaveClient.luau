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
-- beginLife(mode): discard old queued rests, retry a serial intent, and hold new rests until durable acknowledgement.
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
		lifeTokens = {} :: {[string]:string}, lifeRequests = {} :: {[string]:any}, lifeSerial = 0,
  lastProgress = -1e9, dirty = false, pendingRest = {} :: { [string]: any }, lastRest = {} :: { [string]: number },
		st = nil :: string?, why = nil :: string?, sent = { progress = 0, rest = 0, hello = 0 },
	}, SaveClient)
end

local function receive(self: any, msg: any)
	if type(msg) ~= "table" or type(msg.kind) ~= "string" then return end
	if msg.kind == "loaded" then
		self.phase = "ready"
		self.st, self.why = msg.status, msg.reason
		if type(msg.lives)=="table" then
   for mode,token in msg.lives do if not self.lifeRequests[mode] and type(token)=="string" then self.lifeTokens[mode]=token end end
  end
  self.cfg.onLoaded(msg)
		self.cfg.onStatus(msg.status, msg.reason)
	elseif msg.kind == "status" then
		self.st, self.why = msg.status, msg.reason
		self.cfg.onStatus(msg.status, msg.reason)
	elseif msg.kind == "life" then
  local request=self.lifeRequests[msg.mode]
  if request and request.serial==msg.serial and type(msg.token)=="string" and #msg.token>0 and #msg.token<=self.cfg.rules.MAX_LIFE_TOKEN_CHARS then
   request.done=true;self.lifeTokens[msg.mode]=msg.token
  end
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

function SaveClient.beginLife(self: any,mode: string)
 self.lifeSerial+=1
 self.lifeRequests[mode]={serial=self.lifeSerial,done=false,last=-1e9}
 self.pendingRest[mode]=nil -- an unsent rest belongs to the life being retired
 self.lastRest[mode]=nil
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
	if self.st ~= nil then
  if self.st=="saved" then for _,request in self.lifeRequests do if not request.done then return "saving",nil end end end
  return self.st,self.why
 end
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
	if self.phase=="ready" then
  for mode,request in self.lifeRequests do
   if not request.done and t-request.last>=rules.CLIENT_LIFE_GAP then
    request.last=t
    self.remotes.server:FireServer({kind="begin_life",mode=mode,serial=request.serial})
   end
  end
 end
 for mode, record in self.pendingRest do
  local request=self.lifeRequests[mode]
  if request and not request.done then continue end
		if t - (self.lastRest[mode] or -1e9) >= rules.CLIENT_PROGRESS_GAP * 2 then
			self.pendingRest[mode] = nil
			self.lastRest[mode] = t
			self.sent.rest += 1
			self.remotes.server:FireServer({ kind = "rest", mode = mode, record = record, life = self.lifeTokens[mode] })
		end
	end
end

return SaveClient
