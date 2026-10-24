--!strict
-- Optional adapter over the actual SaveService. The old owner is removed and
-- verifiably closed before the real service may construct/load the next one.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Data.SaveRules)
local Json = require(Shared.Persistence.Json)
local SaveRest = require(Shared.Persistence.SaveRest)
local Service = require(script.Parent.SaveService)
local Protocol = require(Shared.Persistence.ReplacementProtocolPrototype)
local Adapter = {}; Adapter.__index = Adapter

local function emit(self: any, player: any, t: any, kind: string)
 if self.closing or self.peers[player] ~= t.peer then return end
 t.entry.sequence += 1
 self.send(player, {kind = kind, v = Protocol.VERSION, epoch = t.epoch, sequence = t.entry.sequence, serial = t.serial, id = t.id})
 t.last = self.now()
end
local function reply(self: any, player: any, t: any)
 emit(self, player, t, if t.stage == "offered" then "session_replace_offer" elseif t.stage == "closed" then "session_replace_commit" else "session_replace_failed")
end
function Adapter.new(config: any): any
 assert(type(config.ownerFactory) == "function", "replacement requires an explicit server owner factory")
 local self: any = setmetatable({peers = {}, transitions = {}, debts = {}, installations = {}, send = config.send, now = config.now,
  spawn = config.spawn, accounts=config.accountLifetimes, counter = 0, closing = false}, Adapter)
 local cfg = {}; for key, value in config do cfg[key] = value end
 cfg.keyOf = function(player: any): any
  local p = self.peers[player]
  assert(p and not self.closing, "owner construction has no live visit")
  if p and p.installing then return p.installing.user end -- preserve the physical account key
  local user = if config.keyOf then config.keyOf(player) else player.UserId
  assert(self.peers[player] == p and not self.closing, "account lookup outlived its visit")
  -- Initial construction needs the same lifetime fence as replacement. The
  -- service has not registered an entry yet when a cooperative factory yields.
  local installation: any = {player=player,peer=p,user=user}
  self.installations[tostring(user)], p.installing = installation, installation
  return user
 end
 cfg.ownerFactory = function(ownerConfig: any, emitter: any): any
  local key = tostring(ownerConfig.userId); local installation = self.installations[key]
  if installation then installation.sessionId = ownerConfig.sessionId end
  local visit
  if self.accounts then
   assert(installation,"typed construction needs a live installation")
   visit=self.accounts:open(ownerConfig.userId,ownerConfig.sessionId,ownerConfig.backend,function()
    return self.installations[key]==installation and self.peers[installation.player]==installation.peer and not self.closing
   end)
   installation.visit=visit
   ownerConfig=table.clone(ownerConfig);ownerConfig.admission=visit.lane
  end
  local okay,owned=pcall(config.ownerFactory,ownerConfig,emitter)
  if not okay then if self.accounts then self.accounts:failed(visit) end;error(owned,0) end
  if installation and (self.installations[key] ~= installation or self.peers[installation.player] ~= installation.peer or self.closing) then
   -- The factory contract is an unloaded owner; discard without flushing or
   -- acquiring a lease if a cooperative constructor outlives its player.
   assert(owned.session.counters.requests == 0 and owned.session.state == "loading", "cancelled factory performed storage work")
   owned.closed, owned.session.closed, owned.runtime.leaving, owned.runtime.phase = true, true, true, "closed"
   if self.accounts then self.accounts:failed(visit) end
   error("replacement constructor scope ended", 0)
  end
  if self.accounts then self.accounts:bind(visit,owned) end
  local debt = self.debts[key]
  if config.newLifeFactory then owned:installNewLifeFactory(config.newLifeFactory) end
  if debt then assert(not self.accounts,"typed debt must remain in account gate");owned:inheritReplacementDebt(debt); self.debts[key] = nil end
  return owned
 end
 cfg.send = function(player: any, message: any)
  local p = self.peers[player]
  if not p or self.transitions[player] ~= nil or p.newLife~=nil then return end
  if message.kind == "loaded" then
   message.replacement = if p.enabled then Protocol.VERSION else nil
   message.newLife = if p.newEnabled then Protocol.NEW_VERSION else nil
   if p.previous then
    message.replaced = {epoch = p.previous.epoch, serial = p.previous.serial, id = p.previous.id}
   end
  end
  self.send(player, message)
 end
 self.base = Service.new(cfg)
 return self
end
function Adapter.addPlayer(self: any, player: any)
 if self.closing or self.peers[player] then return end
 local p: any = {enabled = false, frozen = false, serial = 0}
 self.peers[player] = p
 local installed = pcall(self.base.addPlayer, self.base, player)
 local installation = p.installing
 if installation then
  if self.accounts and not installed then self.accounts:failed(installation.visit) end
  local key = tostring(installation.user)
  if self.installations[key] == installation then self.installations[key] = nil end
  p.installing = nil
 end
 if self.peers[player] ~= p or self.closing then
  local orphan = self.base.entries[player]
  if installation and orphan and orphan.session.id == installation.sessionId then pcall(self.base.removePlayer, self.base, player) end
  return false
 end
 if not installed then
  p.failed = true
  local orphan = self.base.entries[player]
  if installation and orphan and orphan.session.id == installation.sessionId then pcall(self.base.removePlayer, self.base, player) end
 end
 return installed
end
local function drop(self: any) self.base.stats.dropped += 1 end
local function newReply(self:any,player:any,p:any)
 local n=p.newLife;local entry=self.base.entries[player]
 if not n or not entry or entry.owner~=n.owner or self.transitions[player] then return end
 local state=if n.refused then "refused" else n.owner:newLifeStatus() or "refused"
 entry.sequence+=1;n.last=self.now();n.state=state
 self.send(player,{kind="new_life_state",v=Protocol.NEW_VERSION,epoch=n.epoch,sequence=entry.sequence,mode=n.mode,serial=n.serial,offerId=n.offerId,state=state})
end
local function scope(t: any, message: any): boolean
 return message.v == Protocol.VERSION and message.epoch == t.epoch and message.serial == t.serial and message.id == t.id
end
local function ordinaryHello(self: any, player: any)
 self.base:onMessage(player, {kind = "hello", v = Rules.OFFER_PROTOCOL, recovery = Rules.RECOVERY_PROTOCOL})
end
local function closeOld(self: any, player: any, t: any)
 if t.stage ~= "offered" then return end
 t.stage = "closing" -- before an inline or yielding spawn can reenter
 self.spawn(function()
  local ok = pcall(self.base.removePlayer, self.base, player)
  local good = ok and t.owner:replacementClosed()
  if self.transitions[player] ~= t or self.peers[player] ~= t.peer or self.closing then return end
  t.stage = if good then "closed" else "failed"
  reply(self, player, t)
 end)
end
function Adapter.onMessage(self: any, player: any, message: any)
 local p, t = self.peers[player], self.transitions[player]
 if not p or self.closing or type(message) ~= "table" then return end
 local entry = self.base.entries[player]
 if t then
  if not Protocol.known(message, {kind=true,v=true,epoch=true,serial=true,id=true,progress=true}) then drop(self); return end
  if message.kind == "session_replace_request" and message.v == Protocol.VERSION and message.epoch == t.epoch and message.serial == t.serial then
   if t.stage ~= "closing" and t.stage ~= "preparing" then reply(self, player, t) end; return
  end
  if not scope(t, message) then drop(self); return end
  if message.kind == "session_replace_ack" and t.stage == "offered" then closeOld(self, player, t); return end
  if message.kind == "session_replace_ready" and t.stage == "closed" then
   if not t.owner:replacementClosed() or self.base.entries[player] ~= nil then drop(self); return end
   local debt = {}; local now = self.now()
   if not self.accounts then
   for _, time in t.owner.session.sched.started do
    if time > now or time ~= time then t.stage = "failed"; reply(self, player, t); return end
    if now - time < 60 then table.insert(debt, time) end
   end
   -- Initial load starts one lock request and three rest reads. Wait without a
   -- live owner, then carry the remaining rolling debt into the new scheduler.
   if #debt + 1 + #Rules.MODES > Rules.REQUESTS_PER_MINUTE then return end
   end
   -- Old late callbacks still refer to an entry whose leaving flag stays true.
   -- Base addPlayer supplies a genuinely new Session ID and bound load config.
   self.transitions[player] = nil; p.previous = {epoch=t.epoch,serial=t.serial,id=t.id}
   local key = tostring(t.owner.session.cfg.userId)
   if not self.accounts then self.debts[key] = debt end
   local installation: any = {player=player,peer=p,user=t.owner.session.cfg.userId}
   self.installations[key], p.installing = installation, installation
   local installed = pcall(self.base.addPlayer, self.base, player)
   if self.installations[key] == installation then self.installations[key] = nil end
   p.installing = nil
   if self.peers[player] ~= p or self.closing then
    local orphan = self.base.entries[player]
    if orphan and orphan.session.id == installation.sessionId then pcall(self.base.removePlayer, self.base, player) end
    return
   end
   if not installed then
    if self.accounts then self.accounts:failed(installation.visit) end
    self.debts[key] = nil; self.transitions[player] = t; t.stage = "failed"
    if self.base.entries[player] then pcall(self.base.removePlayer, self.base, player) end
    reply(self, player, t); return
   end
   ordinaryHello(self, player); return
  end
  drop(self); return
 end
 if not entry then drop(self); return end
 if message.kind == "hello" and not p.frozen and not entry.hello
  and (message.v == 1 or message.v == Rules.PROTOCOL or message.v == Rules.OFFER_PROTOCOL) then
  p.frozen = true
  p.enabled = message.v == Rules.OFFER_PROTOCOL and message.recovery == Rules.RECOVERY_PROTOCOL and message.replacement == Protocol.VERSION
   and entry.owner ~= nil and type(entry.owner.prepareReplacement) == "function" and type(entry.owner.replacementClosed) == "function"
   and type(entry.owner.inheritReplacementDebt) == "function"
  p.newEnabled=p.enabled and message.newLife==Protocol.NEW_VERSION and entry.owner.newLifeFactory~=nil
 end
 if message.kind == "session_replace_ready" and p.enabled and p.previous and scope(p.previous, message)
  and Protocol.known(message, {kind=true,v=true,epoch=true,serial=true,id=true}) then
  ordinaryHello(self, player); return -- retry a lost new-epoch loaded reply
 end
 if p.enabled and message.kind ~= "hello" and message.epoch ~= entry.session.id then drop(self); return end
 if message.kind=="new_life_request" then
  if not p.newEnabled or not Protocol.known(message,{kind=true,v=true,epoch=true,mode=true,serial=true,offerId=true,progress=true})
   or message.v~=Protocol.NEW_VERSION or not Protocol.serial(message.serial) or not Protocol.token(message.offerId)
   or not table.find(Rules.MODES,message.mode) or SaveRest.bounded(message.progress,Rules.MAX_PROGRESS_NODES,Rules.MAX_PROGRESS_DEPTH) then drop(self);return end
  local n=p.newLife
  if n then
   if n.owner~=entry.owner or n.epoch~=message.epoch or n.mode~=message.mode or n.serial~=message.serial or n.offerId~=message.offerId then drop(self);return end
   if self.now()-n.last>=Protocol.RETRY then newReply(self,player,p) end;return
  end
  n={owner=entry.owner,epoch=message.epoch,mode=message.mode,serial=message.serial,offerId=message.offerId,last=-math.huge};p.newLife=n
  local good,accepted=pcall(entry.owner.prepareNewLife,entry.owner,message.mode,message.serial,message.offerId,message.progress)
  if not good or not accepted then n.refused=true end
  newReply(self,player,p);return
 end
 if p.newLife and message.kind~="session_replace_request" then drop(self);return end
 if message.kind ~= "session_replace_request" then self.base:onMessage(player, message); return end
 if not p.enabled or not Protocol.known(message, {kind=true,v=true,epoch=true,serial=true,progress=true})
  or message.v ~= Protocol.VERSION or not Protocol.serial(message.serial) or message.serial <= p.serial
  or SaveRest.bounded(message.progress, Rules.MAX_PROGRESS_NODES, Rules.MAX_PROGRESS_DEPTH) ~= nil then drop(self); return end
 local now = self.now()
 if p.last ~= nil and now - p.last < Protocol.RETRY then drop(self); return end
 p.last, p.serial = now, message.serial
 self.counter += 1
 t = {peer=p,entry=entry,owner=entry.owner,epoch=entry.session.id,serial=message.serial,
  id=Json.checksum(entry.session.id .. ":" .. tostring(message.serial) .. ":" .. tostring(self.counter)),
  stage="preparing",started=now,last=-math.huge}
 self.transitions[player] = t -- ordinary output/intake closes before callbacks
 p.newLife=nil -- no late New reply may revive work across replacement
 local okay,prepared=pcall(entry.owner.prepareReplacement,entry.owner,message.progress)
 if self.transitions[player]~=t or self.peers[player]~=p or self.closing or t.stage~="preparing" then return end
 t.stage=if okay and prepared==true then "offered" else "failed"
 reply(self, player, t)
end
function Adapter.step(self: any)
 if self.closing then return end
 self.base:step() -- an awaiting-ACK owner maintains only its held lease
 for player,p in self.peers do
  if p.newLife and not self.transitions[player] then
   local state=if p.newLife.refused then "refused" else p.newLife.owner:newLifeStatus() or "refused"
   if state~=p.newLife.state or self.now()-p.newLife.last>=Protocol.RETRY then newReply(self,player,p) end
  end
 end
 for player, t in self.transitions do
  if t.stage=="preparing" and self.now()-t.started<Protocol.TIMEOUT then continue end
  if t.stage ~= "closing" and self.now() - t.last >= Protocol.RETRY then
   if self.now() - t.started >= Protocol.TIMEOUT then t.stage = "failed" end
   reply(self, player, t)
  end
 end
end
function Adapter.removePlayer(self: any, player: any)
 local p = self.peers[player]
 if p and p.installing then
  local key = tostring(p.installing.user)
  if self.accounts then self.accounts:cancel(key,p.installing.sessionId) end
  if self.installations[key] == p.installing then self.installations[key], self.debts[key] = nil, nil end
 end
 self.peers[player], self.transitions[player] = nil, nil
 self.base:removePlayer(player) -- a close already in flight is counted by base
end
function Adapter.shutdown(self: any)
 self.closing=true
 if self.accounts then
  self.accounts:closeIntake()
  for user,installation in self.installations do self.accounts:cancel(user,installation.sessionId) end
 end
 self.peers, self.transitions, self.installations, self.debts = {}, {}, {}, {}
 self.base:shutdown()
 if self.accounts then self.accounts:finishShutdown() end
end
function Adapter.statusOf(self: any, player: any): (string?, string?)
 if self.transitions[player] then return "session", "session_replacement" end
 return self.base:statusOf(player)
end
return table.freeze(Adapter)
