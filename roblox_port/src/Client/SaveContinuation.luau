--!strict
-- Opt-in protocol3 state. No engine waits or DataStore access. The game supplies
-- bounded checkpoint validation and deep copies; callbacks never receive owners.
local Continuation={}
Continuation.__index=Continuation
export type Config={rules:any,copy:(any)->any,validate:(string,any,boolean)->boolean,
 onLoaded:((any)->())?,onOffer:((string,any)->())?,onDecision:((any)->())?,
 onRestore:((string,any)->boolean?)?,onStatus:((string,string?)->())?}
local function integer(n:any,max:number):boolean
 return type(n)=="number" and n==n and n>=1 and n<=max and n==math.floor(n)
end
local function slot(self:any,m:any):boolean return type(m)=="string" and table.find(self.cfg.rules.MODES,m)~=nil end
local function token(self:any,t:any):boolean return type(t)=="string" and #t>0 and #t<=self.cfg.rules.MAX_LIFE_TOKEN_CHARS end
local function callback(f:any,...:any) if f then f(...) end end
function Continuation.new(cfg:Config):any
 return setmetatable({cfg=cfg,epoch=nil,loadedSeq=0,statusSeq=0,st=nil,why=nil,offers={},offerSeq={},decisionSeq={},requests={},
  serial=0,buffer={},bufferEpoch=nil,lastLife=-1e9,lastRest=-1e9,lifeCursor=0,restCursor=0,refreshes={}},Continuation)
end
local function offerValue(self:any,mode:string,value:any):any
 if type(value)~="table" or not token(self,value.id) or type(value.protected)~="boolean" or not self.cfg.validate(mode,value.record,true) then return nil end
 return {id=value.id,record=self.cfg.copy(value.record),protected=value.protected}
end
function Continuation.offerInfo(self:any,mode:string):any
 local v=self.offers[mode]
 return if v then {id=v.id,protected=v.protected,playable=v.record.save_retired~=true} else nil
end
function Continuation.abandon(self:any,mode:string)
 self.requests[mode]=nil
end
function Continuation.offer(self:any,mode:string):any
 local v=self.offers[mode];return if v then self.cfg.copy(v) else nil
end
local function decisionValue(r:any):any
 return {mode=r.mode,kind=r.kind,serial=r.serial,offerId=r.offerId,revision=r.revision,state=r.state,reason=r.reason,credential=r.credential,life=r.life}
end
function Continuation.decision(self:any,mode:string):any
 local r=self.requests[mode];return if r then decisionValue(r) else nil
end
local function applyOffer(self:any,mode:any,value:any,seq:number,events:any)
 if not slot(self,mode) or seq<=(self.offerSeq[mode] or 0) then return end
 local v=if value~=nil then offerValue(self,mode,value) else nil
 if value~=nil and not v then return end
 self.offerSeq[mode]=seq;self.offers[mode]=v
 table.insert(events,function() if self.offerSeq[mode]==seq then callback(self.cfg.onOffer,mode,self:offer(mode)) end end)
end
local function applyDecision(self:any,d:any,seq:number,events:any)
 if type(d)~="table" or not slot(self,d.mode) or seq<=(self.decisionSeq[d.mode] or 0) then return end
 local r=self.requests[d.mode]
 if not r or d.serial~=r.serial or d.kind~=r.kind or d.offerId~=r.offerId or not integer(d.revision,self.cfg.rules.MAX_LIFE_SERIAL) or d.revision<r.revision then return end
 if d.state~="writable" and d.state~="readonly" and d.state~="changed" then return end
 if d.reason~=nil and (type(d.reason)~="string" or #d.reason>160) then return end
 if d.state=="writable" and (not token(self,d.credential) or (d.life~=nil and not token(self,d.life))) then return end
 if r.state=="changed" then return end
 -- Same revision is an idempotent snapshot, not a second competing decision.
 if d.revision==r.revision and r.seenDecision then
  if d.state~=r.state or d.credential~=r.credential or d.life~=r.life or d.reason~=r.reason then return end
 end
 self.decisionSeq[d.mode]=seq;r.revision=d.revision;r.seenDecision=true
 local credential=if d.state=="writable" then d.credential else nil
 local state:string=d.state
 -- A later session-only status revokes an earlier grant even when packets reorder.
 if state=="writable" and self.st=="session" and self.statusSeq>=seq then state="readonly";credential=nil end
 if credential~=r.credential and r.candidate then r.candidate.stored=false;r.candidate.refused=false;r.candidate.sentCredential=nil;r.candidate.last=-1e9;r.candidate.receiptSeq=0 end
 r.state,r.reason,r.credential,r.life,r.authoritySeq=state,d.reason,credential,d.life,seq
 table.insert(events,function() if self.requests[d.mode]==r and self.decisionSeq[d.mode]==seq then callback(self.cfg.onDecision,decisionValue(r)) end end)
end
local function applyStatus(self:any,msg:any,seq:number,events:any)
 if seq<=self.statusSeq or (msg.status~="saved" and msg.status~="saving" and msg.status~="session") then return end
 if msg.reason~=nil and (type(msg.reason)~="string" or #msg.reason>160) then return end
 self.statusSeq,self.st,self.why=seq,msg.status,msg.reason
 if self.st=="session" then
  for _,r in self.requests do
   if seq>=(r.authoritySeq or 0) and r.state~="changed" then
    r.state,r.credential,r.reason="readonly",nil,msg.reason
    if r.candidate then r.candidate.stored=false;r.candidate.sentCredential=nil end
   end
  end
 end
 table.insert(events,function() if self.statusSeq==seq then local st,why=self:status();callback(self.cfg.onStatus,st,why) end end)
end
local function applyReceipt(self:any,msg:any,seq:number)
 if not slot(self,msg.mode) then return end
 local r=self.requests[msg.mode];local c=r and r.candidate
 if not c or r.state~="writable" or not r.credential or msg.serial~=r.serial or msg.credential~=r.credential or c.sentCredential~=r.credential
  or msg.restSerial~=c.serial or seq<=(c.receiptSeq or 0) then return end
 if msg.kind=="refused" and msg.reason~="invalid_checkpoint" then return end
 c.receiptSeq=seq;c.stored=msg.kind=="stored";c.refused=msg.kind=="refused"
end
local function dispatch(self:any,msg:any,events:any)
 local seq=msg.sequence
 if msg.kind=="offer" then applyOffer(self,msg.mode,msg.offer,seq,events)
 elseif msg.kind=="decision" then applyDecision(self,msg.decision,seq,events)
 elseif msg.kind=="status" then applyStatus(self,msg,seq,events)
 elseif msg.kind=="stored" or msg.kind=="refused" then applyReceipt(self,msg,seq) end
end
function Continuation.receive(self:any,msg:any):boolean
 if type(msg)~="table" or not token(self,msg.epoch) or not integer(msg.sequence,self.cfg.rules.MAX_LIFE_SERIAL) then return false end
 local events={}
 if self.epoch==nil then
  if msg.kind~="loaded" then
   local key=if msg.kind=="status" then "status" elseif (msg.kind=="offer" and slot(self,msg.mode)) then "offer:"..msg.mode
    elseif msg.kind=="decision" and type(msg.decision)=="table" and slot(self,msg.decision.mode) then "decision:"..msg.decision.mode else nil
   if not key then return false end
   if self.bufferEpoch==nil then self.bufferEpoch=msg.epoch end
   if msg.epoch~=self.bufferEpoch then return false end
   local old=self.buffer[key]
   -- Copy only bounded known shapes, never an unbounded unknown wire packet.
   local v:any=nil
   if msg.kind=="offer" then
    local offer=if msg.offer~=nil then offerValue(self,msg.mode,msg.offer) else nil
    if msg.offer~=nil and not offer then return false end
    v={kind="offer",mode=msg.mode,offer=offer}
   elseif msg.kind=="status" then
    if msg.status~="saved" and msg.status~="saving" and msg.status~="session" then return false end
    if msg.reason~=nil and (type(msg.reason)~="string" or #msg.reason>160) then return false end
    v={kind="status",status=msg.status,reason=msg.reason}
   else
    -- No local intent exists before a handshake, so an unsolicited decision
    -- cannot grant anything and is unnecessary to retain.
    return false
   end
   v.epoch,v.sequence=msg.epoch,msg.sequence
   if not old or msg.sequence>old.sequence then self.buffer[key]=v end
   return true
  end
  if msg.v~=self.cfg.rules.OFFER_PROTOCOL then return false end
  self.epoch=msg.epoch
 end
 if msg.epoch~=self.epoch then return false end
 if msg.kind=="loaded" then
  if msg.v~=self.cfg.rules.OFFER_PROTOCOL or msg.sequence<=self.loadedSeq then return false end
  self.loadedSeq=msg.sequence
  applyStatus(self,msg,msg.sequence,events)
  for _,mode in self.cfg.rules.MODES do
   applyOffer(self,mode,if type(msg.offers)=="table" then msg.offers[mode] else nil,msg.sequence,events)
   local d=if type(msg.decisions)=="table" then msg.decisions[mode] else nil
   if d then applyDecision(self,d,msg.sequence,events) end
  end
  -- Progress is separately sanitized by the consumer. Do not expose arbitrary
  -- loaded tables, raw rests or credentials through the legacy onLoaded path.
  local progress=msg.progress
  table.insert(events,function() if self.loadedSeq==msg.sequence then callback(self.cfg.onLoaded,{progress=progress}) end end)
  local pending=self.buffer;self.buffer={};self.bufferEpoch=nil
  for _,v in pending do if v.epoch==self.epoch then dispatch(self,v,events) end end
 else dispatch(self,msg,events) end
 for _,f in events do f() end
 return true
end
function Continuation.choose(self:any,mode:string,kind:string,id:string?):boolean
 if not self.epoch or not slot(self,mode) or (kind~="new" and kind~="continue") or self.serial>=self.cfg.rules.MAX_LIFE_SERIAL then return false end
 local offer=self.offers[mode]
 if id~=nil and (not offer or offer.id~=id) then return false end
 if kind=="continue" and (not offer or offer.id~=id or offer.record.save_retired==true) then return false end
 if kind=="new" and offer~=nil and id==nil then return false end
 self.serial+=1
 local r={mode=mode,kind=kind,serial=self.serial,offerId=id,revision=0,state="readonly",reason=nil,credential=nil,life=nil,
  last=-1e9,ticket=0,selected=if kind=="continue" and offer and id then self.cfg.copy(offer.record) else nil}
 self.requests[mode]=r;self.decisionSeq[mode]=0
 -- Commit the complete intent before callbacks; a callback can choose another
 -- life immediately. Restore only here, once per explicit user choice.
 if kind=="continue" and self.cfg.onRestore then
  local ok,result=pcall(self.cfg.onRestore,mode,self.cfg.copy(r.selected))
  if not ok or result==false then
   if self.requests[mode]==r then self.requests[mode]=nil end
   return false
  end
 end
 return true
end
function Continuation.refresh(self:any,mode:string)
 if slot(self,mode) then self.refreshes[mode]=true end
end
function Continuation.checkpoint(self:any,mode:string,record:any):boolean
 local r=self.requests[mode]
 if not r or not self.cfg.validate(mode,record,false) or r.ticket>=self.cfg.rules.MAX_LIFE_SERIAL then return false end
 local copy=self.cfg.copy(record);r.ticket+=1
 r.candidate={serial=r.ticket,record=copy,last=-1e9,stored=false,refused=false,receiptSeq=0,sentCredential=nil}
 return true
end
function Continuation.status(self:any,mode:string?):(string,string?)
 if self.st==nil then return "session","offline" end
 if self.st=="session" then return self.st,self.why end
 for m,r in self.requests do
  if mode==nil or mode==m then
   if r.state=="changed" then return "session","save_changed" end
   if r.state~="writable" or not r.credential then
    if r.reason==nil or r.reason=="revalidating" then return "saving",nil end
    return "session",r.reason
   end
   if r.candidate and r.candidate.refused then return "saving","rest_refused" end
   if r.candidate and not r.candidate.stored then return "saving",self.why end
  end
 end
 return self.st,self.why
end
function Continuation.update(self:any,now:number,send:(any)->())
 if not self.epoch then return end
 local modes=self.cfg.rules.MODES
 if now-self.lastLife>=self.cfg.rules.CLIENT_LIFE_GAP then
  -- Intent and refresh share the server bucket. Round robin across both kinds
  -- and all slots; repeated temporary intent retries cannot starve refreshes.
  for _=1,#modes*2 do
   self.lifeCursor=self.lifeCursor%(#modes*2)+1
   local i=math.floor((self.lifeCursor-1)/2)+1;local mode=modes[i];local r=self.requests[mode]
   local packet:any=nil
   if self.lifeCursor%2==1 then
    if r and r.state=="readonly" and now-r.last>=self.cfg.rules.CLIENT_LIFE_GAP then
     r.last=now;packet={kind="life_intent",intent=r.kind,mode=mode,serial=r.serial,offerId=r.offerId}
    end
   elseif self.refreshes[mode] then self.refreshes[mode]=nil;packet={kind="refresh_offer",mode=mode} end
   if packet then self.lastLife=now;send(packet);break end
  end
 end
 if now-self.lastRest>=math.max(5,self.cfg.rules.CLIENT_PROGRESS_GAP*2) then
  for _=1,#modes do
   self.restCursor=self.restCursor%#modes+1
   local mode=modes[self.restCursor];local r=self.requests[mode];local c=r and r.candidate
   if r and r.state=="writable" and r.credential and c and not c.stored and not c.refused then
    c.last=now;c.sentCredential=r.credential;self.lastRest=now
    send({kind="rest",mode=mode,record=self.cfg.copy(c.record),life=r.life,serial=r.serial,credential=r.credential,restSerial=c.serial});break
   end
  end
 end
end
return Continuation
