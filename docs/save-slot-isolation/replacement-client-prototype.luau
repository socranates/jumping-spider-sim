--!strict
-- Optional adapter over the actual SaveClient/Continuation. A failed or timed
-- out transition stays read-only; it never resumes an older world implicitly.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Json = require(Shared.Persistence.Json)
local Progress = require(Shared.Persistence.SaveProgress)
local SaveRest = require(Shared.Persistence.SaveRest)
local Protocol = require(Shared.Persistence.ReplacementProtocolPrototype)
local Client = require(script.Parent.SaveClient)
local Continuation = require(script.Parent.SaveContinuation)
local Adapter = {}
Adapter.__index = function(_self: any, key: any): any return Adapter[key] or Client[key] end

local function failed(self: any, why: string)
 self.replacementProblem = why
 local t = self.transition
 if t then t.stage, t.problem = "failed", why end
 self.cfg.onStatus("session", "session_replacement")
end
local function rawSend(self: any, message: any)
 self.rawRemotes.server:FireServer(message)
end
local function send(self: any, message: any)
 if self.transition ~= nil then return end
 local ticket = self.sendTickets[coroutine.running() or self.mainThread]
 if ticket ~= nil and ticket ~= self.transportGeneration then return end
 if message.kind == "hello" then
  message.replacement = Protocol.VERSION
 elseif self.replacementEnabled then
  if not self.bound or not self.bound.epoch or message.epoch ~= nil and message.epoch ~= self.bound.epoch then return end
  message.epoch = self.bound.epoch
 end
 rawSend(self, message)
end
local function notify(self: any, message: any, owned: boolean?)
 if owned then Client.receiveOwned(self, message) else Client.receive(self, message) end
end
function Adapter.new(config: any, options: any): any
 assert(config.continuation and config.recovery and type(options) == "table" and type(options.onPause) == "function"
  and type(options.onReady) == "function", "replacement requires explicit application pause/menu callbacks")
 local cfg = {}; for key, value in config do cfg[key] = value end
 local self: any
 cfg.findRemotes = function(): any
  local raw = config.findRemotes(); if not raw then return nil end
  self.rawRemotes = raw
  local event = {}
  event.Connect = function(_event: any, _baseListener: any): any
   return raw.client.OnClientEvent:Connect(function(message: any)
    local result = table.pack(pcall(Adapter.receiveOwned, self, message))
    if not result[1] then failed(self, "replacement delivery failed: " .. tostring(result[2])) end
   end)
  end
  return {server={FireServer=function(_remote: any, message: any) send(self, message) end},client={OnClientEvent=event}}
 end
 self = Client.new(cfg); self.replacementOptions, self.replacementSerial = options, 0
 self.transportGeneration, self.sendTickets, self.mainThread = 0, {}, {}
 return setmetatable(self, Adapter)
end
local function closeOldClient(self: any)
 self.bound:closeOffers()
 for _, mode in self.cfg.rules.MODES do self.bound:abandon(mode) end
 self.recoveryChoice, self.recoveryOffer, self.recoverySequence = nil, nil, nil
 self.restPreparing, self.restUnsent, self.pendingRest, self.lifeRequests = {}, {}, {}, {}
end
function Adapter.requestReplacement(self: any): boolean
 if not self.replacementEnabled or self.transition ~= nil or not self:recoveryReady()
  or self.replacementSerial >= self.cfg.rules.MAX_LIFE_SERIAL then return false end
 local payload = self.cfg.build()
 if SaveRest.bounded(payload, self.cfg.rules.MAX_PROGRESS_NODES, self.cfg.rules.MAX_PROGRESS_DEPTH) ~= nil then return false end
 local _, clean = Progress.sanitize(payload); if not clean then return false end
 self.replacementSerial += 1
 local t = {epoch=self.bound.epoch,serial=self.replacementSerial,progress=Json.copy(clean),
  stage="preparing",started=self.cfg.now(),last=-math.huge}
 self.transition = t -- all outbound ordinary traffic stops before callbacks
 self.transportGeneration += 1
 closeOldClient(self) -- in-flight checkpoint/adoption fences fail immediately
 local ok, paused = pcall(self.replacementOptions.onPause, t.epoch, t.serial)
 if self.transition ~= t then return false end
 if not ok or paused ~= true then failed(self, "application did not confirm pause"); return false end
 t.stage = "requesting"; return true
end
local function control(self: any, message: any): boolean
 return Protocol.known(message, {kind=true,v=true,epoch=true,sequence=true,serial=true,id=true})
  and message.v == Protocol.VERSION and Protocol.serial(message.sequence) and Protocol.token(message.id)
end
local function receive(self: any, message: any, owned: boolean?)
 if type(message) ~= "table" then return end
 local t = self.transition
 if not t then
  notify(self, message, owned)
  if message.kind == "loaded" and not self.replacementFrozen and self.bound and self.bound.epoch == message.epoch then
   self.replacementFrozen = true
   self.replacementEnabled = message.replacement == Protocol.VERSION and self:recoveryReady()
  end
  return
 end
 if t.stage == "failed" or t.stage == "preparing" then return end
 if message.kind == "loaded" and t.stage == "awaiting_loaded" then
  local previous = message.replaced
  if message.v ~= self.cfg.rules.OFFER_PROTOCOL or message.recovery ~= self.cfg.rules.RECOVERY_PROTOCOL
   or message.replacement ~= Protocol.VERSION or not Protocol.token(message.epoch) or message.epoch == t.epoch
   or not Protocol.serial(message.sequence) or not Protocol.known(previous,{epoch=true,serial=true,id=true})
   or previous.epoch ~= t.epoch or previous.serial ~= t.serial or previous.id ~= t.id then return end
  local old = self.bound
  self.bound = Continuation.new(old.cfg)
  self.activeSlot, self.temporarySlots, self.protectedSlots, self.lifeTokens = nil, {}, {}, {}
  self.phase = "hello"; t.stage = "activating"
  notify(self, message, owned)
  if self.transition ~= t or self.bound.epoch ~= message.epoch then failed(self, "new handshake refused"); return end
  local ok, ready = pcall(self.replacementOptions.onReady, t.epoch, message.epoch, t.serial)
  if self.transition ~= t then return end
  if not ok or ready ~= true then failed(self, "application did not confirm fresh menu"); return end
  self.previousReplacement = {epoch=t.epoch,id=t.id,serial=t.serial}
  self.transition = nil
  return
 end
 if not control(self, message) or message.epoch ~= t.epoch or message.serial ~= t.serial
  or message.sequence <= (t.sequence or 0) or t.id ~= nil and message.id ~= t.id then return end
 if message.kind == "session_replace_offer" and (t.stage == "requesting" or t.stage == "acknowledging") then
  t.id, t.sequence, t.stage, t.last = message.id, message.sequence, "acknowledging", -math.huge
 elseif message.kind == "session_replace_commit" and (t.stage == "acknowledging" or t.stage == "awaiting_loaded") then
  if not t.id then return end
  t.sequence, t.stage, t.last = message.sequence, "awaiting_loaded", -math.huge
 elseif message.kind == "session_replace_failed" then
  t.sequence = message.sequence; failed(self, "server could not verify old departure")
 end
end
function Adapter.receive(self: any, message: any) receive(self, message, false) end
function Adapter.receiveOwned(self: any, message: any) receive(self, message, true) end
function Adapter.update(self: any)
 local t = self.transition
 if not t then
  local thread = coroutine.running() or self.mainThread
  local previous = self.sendTickets[thread]
  self.sendTickets[thread] = self.transportGeneration
  local ok, why = pcall(Client.update, self)
  self.sendTickets[thread] = previous
  if not ok then error(why, 0) end
  return
 end
 local now = self.cfg.now()
 if t.stage == "failed" then return end
 if now < t.started or now - t.started >= Protocol.TIMEOUT then failed(self, "replacement deadline reached"); return end
 if t.stage == "failed" or t.stage == "preparing" or t.stage == "activating" or now - t.last < Protocol.RETRY then return end
 t.last = now
 if t.stage == "requesting" then
  rawSend(self, {kind="session_replace_request",v=Protocol.VERSION,epoch=t.epoch,serial=t.serial,progress=t.progress})
 elseif t.stage == "acknowledging" then
  rawSend(self, {kind="session_replace_ack",v=Protocol.VERSION,epoch=t.epoch,serial=t.serial,id=t.id})
 elseif t.stage == "awaiting_loaded" then
  rawSend(self, {kind="session_replace_ready",v=Protocol.VERSION,epoch=t.epoch,serial=t.serial,id=t.id})
 end
end
function Adapter.beginLife(self: any, mode: string, id: string?): any
 if self.transition then return false end; return Client.beginLife(self, mode, id)
end
function Adapter.continueLife(self: any, mode: string, id: string): boolean
 return self.transition == nil and Client.continueLife(self, mode, id)
end
function Adapter.sendRest(self: any, mode: string, record: any): any
 if self.transition then return false end; return Client.sendRest(self, mode, record)
end
function Adapter.prepareRest(self: any, mode: string, record: any, token: any): any
 if self.transition then return nil end; return Client.prepareRest(self, mode, record, token)
end
function Adapter.sendRecoveryApplied(self: any, receipt: any): boolean
 return self.transition == nil and Client.sendRecoveryApplied(self, receipt)
end
function Adapter.status(self: any): (string?, string?)
 if self.transition then return "session", "session_replacement" end
 return Client.status(self)
end
return table.freeze(Adapter)
