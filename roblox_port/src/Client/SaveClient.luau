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
local SaveContinuation = require(script.Parent.SaveContinuation)
local SaveClient = {}
SaveClient.__index = SaveClient

export type Config = {
	rules: any, now: () -> number, findRemotes: () -> any?,
 continuation: any?, -- explicit opt-in; supplies bounded validation/copy and offer/decision/restore callbacks
	onLoaded: (any) -> (), onRest: (string, any) -> (), onStatus: (string, string?) -> (),
	build: () -> any, -- the progress to send now (called only when something changed and the gap allows)
}

function SaveClient.new(cfg: Config): any
	local now = cfg.now()
	local self:any = setmetatable({
		cfg = cfg, born = now, remotes = nil :: any, phase = "searching", helloAt = -1e9, helloTries = 0,
		protectedSlots = {} :: {[string]:string}, lifeTokens = {} :: {[string]:string}, lifeRequests = {} :: {[string]:any}, lifeSerial = 0,
  lastProgress = -1e9, dirty = false, pendingRest = {} :: { [string]: any }, lastRest = {} :: { [string]: number },
		st = nil :: string?, why = nil :: string?, sent = { progress = 0, rest = 0, hello = 0 },
	}, SaveClient)
 if cfg.continuation then
  local opt=cfg.continuation
  self.temporarySlots={}
  self.bound=SaveContinuation.new({rules=cfg.rules,copy=opt.copy,validate=opt.validate,
   onLoaded=function(msg:any) self.phase="ready";cfg.onLoaded(msg) end,
   onOffer=opt.onOffer,onDecision=opt.onDecision,onRestore=opt.onRestore,onStatus=cfg.onStatus})
 end
 return self
end

local function applyProtected(self: any,value: any)
 if type(value)~="table" then return end
 -- Protection is sticky for this visit, including across delayed/repeated loaded messages.
 local nextSlots=self.protectedSlots
 for _,mode in self.cfg.rules.MODES do
  local reason=value[mode]
  if reason=="newer" or reason=="corrupt" then
   nextSlots[mode]=reason
   self.pendingRest[mode],self.lifeRequests[mode]=nil,nil
  end
 end
 self.protectedSlots=nextSlots
end

local function receive(self: any, msg: any)
	if type(msg) ~= "table" or type(msg.kind) ~= "string" then return end
 if self.bound then
  if msg.kind=="loaded" and (msg.v==1 or msg.v==self.cfg.rules.PROTOCOL) and self.bound.epoch==nil then
   -- An older peer cannot authorize bound retirement/checkpoint writes. Its
   -- readable rests may still be used temporarily; notebook merging remains.
   self.legacyTemporary=true;self.phase="ready"
   local rests={}
   if type(msg.rests)=="table" then
    for _,mode in self.cfg.rules.MODES do
     if self.cfg.continuation.validate(mode,msg.rests[mode],false) then rests[mode]=self.cfg.continuation.copy(msg.rests[mode]) end
    end
   end
   self.cfg.onLoaded({progress=msg.progress,rests=rests})
   self.cfg.onStatus("session","offline")
  elseif not self.legacyTemporary then self.bound:receive(msg) end
  return
 end
	if msg.kind == "loaded" then
  applyProtected(self,msg.protected)
		self.phase = "ready"
		self.st, self.why = msg.status, msg.reason
		if type(msg.lives)=="table" then
   for mode,token in msg.lives do if not self.lifeRequests[mode] and type(token)=="string" then self.lifeTokens[mode]=token end end
  end
  self.cfg.onLoaded(msg)
		self.cfg.onStatus(msg.status, msg.reason)
	elseif msg.kind == "status" then
  applyProtected(self,msg.protected)
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

function SaveClient.beginLife(self: any,mode: string,offerId: string?)
 if self.bound then
  self.activeSlot=mode
  if self.legacyTemporary then return false end
  self.bound:abandon(mode)
  local accepted=self.bound:choose(mode,"new",offerId)
  self.temporarySlots[mode]=not accepted or nil
  return accepted
 end
 if self.protectedSlots[mode] then self.pendingRest[mode]=nil;return end
 self.lifeSerial+=1
 self.lifeRequests[mode]={serial=self.lifeSerial,done=false,last=-1e9}
 self.pendingRest[mode]=nil -- an unsent rest belongs to the life being retired
 self.lastRest[mode]=nil
end

function SaveClient.sendRest(self: any, mode: string, record: any)
 if self.bound then return if self.legacyTemporary then false else self.bound:checkpoint(mode,record) end
 if self.protectedSlots[mode] then return end
	self.pendingRest[mode] = record
end

function SaveClient.continueLife(self:any,mode:string,id:string):boolean
 if not self.bound or self.legacyTemporary then return false end
 local accepted=self.bound:choose(mode,"continue",id)
 if accepted then self.activeSlot=mode;self.temporarySlots[mode]=nil elseif self.bound.requests[mode]==nil then self.temporarySlots[mode]=true end
 return accepted
end
-- Cancelling deferred Continue may revoke only that exact local request.
function SaveClient.abortContinue(self:any,mode:string,serial:number,epoch:string?):boolean
 if epoch~=nil and (not self.bound or self.bound.epoch~=epoch) then return false end
 local r=self.bound and self.bound.requests[mode]
 if not r or r.kind~="continue" or r.serial~=serial then return false end
 self.bound:abandon(mode);self.temporarySlots[mode]=true
 return true
end
function SaveClient.offerInfo(self:any,mode:string):any
 return if self.bound then self.bound:offerInfo(mode) else nil
end
function SaveClient.isTemporary(self:any,mode:string):boolean
 return self.bound~=nil and (self.legacyTemporary==true or self.temporarySlots[mode]==true)
end
function SaveClient.decision(self:any,mode:string):any
 return if self.bound then self.bound:decision(mode) else nil
end
function SaveClient.offer(self:any,mode:string):any
 return if self.bound then self.bound:offer(mode) else nil
end
function SaveClient.refreshOffer(self:any,mode:string)
 if self.bound and not self.legacyTemporary then self.bound:refresh(mode) end
end
function SaveClient.waiting(self: any): boolean
 if self.bound and self.bound.epoch~=nil then return false end
	local t = self.cfg.now()
	local rules = self.cfg.rules
	if self.phase == "searching" then return t - self.born < rules.CLIENT_WAIT_REMOTES end
	if self.phase == "hello" then return t - self.born < rules.CLIENT_WAIT_REMOTES + rules.CLIENT_WAIT_REPLY and self.helloTries <= rules.CLIENT_HELLO_TRIES end
	return false
end

function SaveClient.status(self: any): (string?, string?)
 if self.bound and (self.bound.epoch~=nil or self.legacyTemporary) then
  if self.legacyTemporary then return "session","unsupported_save" end
  if (self.activeSlot and self.temporarySlots[self.activeSlot]) or (not self.activeSlot and next(self.temporarySlots)~=nil) then return "session","temporary_life" end
  return self.bound:status(self.activeSlot)
 end
	if self.st ~= nil then
  if self.st=="saved" then for _,request in self.lifeRequests do if not request.done then return "saving",nil end end end
  return self.st,self.why
 end
	if self.phase == "searching" and self.cfg.now() - self.born >= self.cfg.rules.CLIENT_WAIT_REMOTES then return "session", "offline" end
	if self.phase == "hello" and not self:waiting() then return "session", "offline" end
	return nil, nil
end

function SaveClient.connected(self: any): boolean
	return self.phase == "ready" or (self.bound~=nil and self.bound.epoch~=nil)
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
		self.remotes.server:FireServer({ kind = "hello", v = if self.bound then rules.OFFER_PROTOCOL else rules.PROTOCOL })
	end
	if self.dirty and (not self.bound or self.bound.epoch~=nil or self.legacyTemporary) and t - self.lastProgress >= rules.CLIENT_PROGRESS_GAP then
		self.dirty = false
		self.lastProgress = t
		local payload = self.cfg.build()
		if payload ~= nil then
			self.sent.progress += 1
			self.remotes.server:FireServer({ kind = "progress", progress = payload })
		end
	end
 if self.bound then
  if not self.legacyTemporary then self.bound:update(t,function(msg:any) self.remotes.server:FireServer(msg) end) end
  return
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
