--!strict
-- Private server admission candidate. No production caller installs this yet.
-- One gate must own all participating actors on a server. Platform allowance is
-- an observation, never a platform reservation or permission to skip save fences.
local Admission={};Admission.__index=Admission
local weights:{[string]:{[string]:number}}={read={read=1,write=0},write={read=0,write=1},update={read=1,write=1}}
local function finite(v:any):boolean return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function integer(v:any,lo:number,hi:number):boolean return finite(v) and v%1==0 and v>=lo and v<=hi end
local function token(v:any,max:number):boolean return type(v)=="string" and #v>0 and #v<=max end
function Admission.new(cfg:any):any
 assert(type(cfg)=="table" and type(cfg.now)=="function" and type(cfg.available)=="function","clock and current platform allowance required")
 for _,name in {"actorRead","actorWrite","serverRead","serverWrite"} do assert(integer(cfg[name],1,10000),"explicit finite policy limit required: "..name) end
 local headroom=cfg.headroom or 2;local actors=cfg.maxActors or 16;local pending=cfg.maxPending or 64
 local reservation=cfg.reservationSeconds or 2;local lifetime=cfg.ticketSeconds or 120
 assert(integer(headroom,0,100) and integer(actors,1,64) and integer(pending,1,256),"bounded gate capacity required")
 assert(finite(reservation) and reservation>0 and reservation<=10 and finite(lifetime) and lifetime>=reservation and lifetime<=300,"bounded ticket lifetimes required")
 local policy={now=cfg.now,available=cfg.available,actorRead=cfg.actorRead,actorWrite=cfg.actorWrite,serverRead=cfg.serverRead,serverWrite=cfg.serverWrite}
 return setmetatable({cfg=table.freeze(policy),headroom=headroom,maxActors=actors,maxPending=pending,reservationSeconds=reservation,ticketSeconds=lifetime,
  actors={},scopes={},tickets={},queue={},history={},nextId=0,version=0,lastNow=-math.huge},Admission)
end
local function changed(self:any) self.version+=1 end
local function current(self:any,r:any):boolean
 return r~=nil and self.tickets[r.ticket]==r and self.scopes[r.scope]~=nil and self.actors[r.actor].scope==r.scope
end
local function remove(self:any,r:any)
 self.tickets[r.ticket]=nil;changed(self)
end
local function sweep(self:any,now:number)
 local history={}
 for _,row in self.history do if now-row.at<60 then table.insert(history,row) end end
 self.history=history
 local queue={}
 for _,r in self.queue do
  if self.tickets[r.ticket]==r and r.state~="started" then
   if not current(self,r) or now>=r.deadline or r.state=="reserved" and now>=r.expires then remove(self,r)
   else
    table.insert(queue,r)
   end
  end
 end
 self.queue=queue
 local used={}
 for _,row in history do used[row.actor]=true end
 for _,r in self.tickets do used[r.actor]=true end
 for actor,a in self.actors do if not a.scope and not used[actor] then self.actors[actor]=nil;changed(self) end end
end
local function clock(self:any):(number?,string?)
 local called,now=pcall(self.cfg.now)
 if not called or not finite(now) or now<self.lastNow then return nil,"clock unavailable or moved backwards" end
 self.lastNow=now;sweep(self,now);return now,nil
end
local function size(t:any):number local n=0;for _ in t do n+=1 end;return n end
function Admission.open(self:any,actor:string,epoch:string):(any?,string?)
 if not token(actor,32) or not token(epoch,96) then return nil,"invalid actor/epoch" end
 local now,why=clock(self);if not now then return nil,why end
 local a=self.actors[actor]
 if a then
  if a.scope then return nil,"actor already has an open visit" end
  if a.lastEpoch==epoch then return nil,"fresh visit epoch required" end
  for _,r in self.tickets do if r.actor==actor and r.state=="started" then return nil,"previous provider must drain" end end
 elseif size(self.actors)>=self.maxActors then return nil,"actor capacity retains recent debt" end
 if self.nextId>=9007199254740000 then return nil,"identity space exhausted" end
 self.nextId+=1
 local scope=table.freeze({id=self.nextId,actor=actor,epoch=epoch})
 a=a or {};a.scope=scope;a.lastEpoch=epoch;self.actors[actor]=a;self.scopes[scope]=true;changed(self)
 return scope,nil
end
function Admission.close(self:any,scope:any):boolean
 if self.scopes[scope]==nil then return false end
 self.scopes[scope]=nil;self.actors[scope.actor].scope=nil;changed(self)
 for _,r in self.tickets do if r.scope==scope and r.state~="started" then remove(self,r) end end
 -- Started calls remain charged and keep their physical actor until they drain.
 return true
end
function Admission.request(self:any,scope:any,kind:string):(any?,string?)
 local now,why=clock(self);if not now then return nil,why end
 if self.scopes[scope]==nil or not weights[kind] then return nil,"live scope and known operation required" end
 if size(self.tickets)>=self.maxPending then return nil,"pending request capacity reached" end
 if self.nextId>=9007199254740000 then return nil,"identity space exhausted" end
 self.nextId+=1
 local ticket=table.freeze({id=self.nextId})
 local r={ticket=ticket,scope=scope,actor=scope.actor,kind=kind,state="queued",deadline=now+self.ticketSeconds,order=self.nextId,lastPoll=now}
 self.tickets[ticket]=r;table.insert(self.queue,r);changed(self);return ticket,nil
end
function Admission.cancel(self:any,ticket:any):boolean
 local r=self.tickets[ticket]
 if not r or r.state=="started" then return false end
 remove(self,r);return true
end
function Admission.status(self:any,ticket:any):string
 local now=clock(self);if not now then return "clock_unavailable" end
 local r=self.tickets[ticket];return if r then r.state else "ended"
end
function Admission.live(self:any,scope:any):boolean
 return self.scopes[scope]~=nil and self.actors[scope.actor]~=nil and self.actors[scope.actor].scope==scope
end
local function amounts(self:any,actor:string,exclude:any):(any,any,any)
 local all={read=0,write=0};local own={read=0,write=0};local held={read=0,write=0}
 for _,row in self.history do
  local w=weights[row.kind];all.read+=w.read;all.write+=w.write
  if row.actor==actor then own.read+=w.read;own.write+=w.write end
 end
 for _,r in self.tickets do
  local w=weights[r.kind]
  if r.state=="started" then
   -- A budget query may not yet reflect an in-flight start. Conservatively
   -- subtract it until provider completion; never refund its rolling history.
   held.read+=w.read;held.write+=w.write
  elseif r~=exclude and r.state=="reserved" then
   all.read+=w.read;all.write+=w.write;held.read+=w.read;held.write+=w.write
   if r.actor==actor then own.read+=w.read;own.write+=w.write end
  end
 end
 return all,own,held
end
local function fits(self:any,r:any,available:any):boolean
 if not current(self,r) then return false end
 for _,other in self.tickets do
  if other~=r and other.actor==r.actor and other.state=="started" then return false end
 end
 local w=weights[r.kind];local all,own,held=amounts(self,r.actor,r)
 for _,kind in {"read","write"} do
  if w[kind]>0 then
   local suffix=if kind=="read" then "Read" else "Write"
   if own[kind]+w[kind]>self.cfg["actor"..suffix] or all[kind]+w[kind]>self.cfg["server"..suffix]
    or available[kind]-held[kind]-self.headroom<w[kind] then return false end
  end
 end
 return true
end
local function allowance(self:any):(any?,string?)
 local version=self.version;local called,available=pcall(self.cfg.available)
 if self.version~=version then return nil,"admission changed during allowance lookup" end
 if not called or type(available)~="table" or not finite(available.read) or not finite(available.write) or available.read<0 or available.write<0 then return nil,"current platform allowance unavailable" end
 return {read=math.floor(available.read),write=math.floor(available.write)},nil
end
local function admit(self:any,ticket:any):(any?,number?,string?)
 local now,why=clock(self);if not now then return nil,nil,why end
 local r=self.tickets[ticket]
 if not current(self,r) or (r.state~="queued" and r.state~="reserved") then return nil,nil,"request ended or already started" end
 r.lastPoll=now;changed(self)
 local available,problem=allowance(self)
 -- A test/provider lookup can yield or reenter. Revalidate clock, scope,
 -- ticket lifetime, local reservations and rolling debt after that boundary.
 now,why=clock(self);if not now then return nil,nil,why end
 if not available or not current(self,r) then return nil,nil,problem or "request scope ended" end
 if not fits(self,r,available) then return nil,nil,"waiting for admission" end
 local w=weights[r.kind]
 for _,earlier in self.queue do
  if earlier.order>=r.order then break end
  if earlier.state=="queued" and now-earlier.lastPoll<=self.reservationSeconds and fits(self,earlier,available) then
   local e=weights[earlier.kind]
   if e.read*w.read>0 or e.write*w.write>0 then return nil,nil,"earlier eligible request has priority" end
  end
 end
 return r,now,nil
end
function Admission.reserve(self:any,ticket:any):(boolean,string?)
 local r,now,why=admit(self,ticket);if not r then return false,why end
 if r.state=="queued" then r.state="reserved";r.expires=now+self.reservationSeconds;changed(self) end
 return true,nil
end
function Admission.dispatch(self:any,ticket:any,provider:()->...any):(boolean,any,string?)
 assert(type(provider)=="function","provider operation required")
 local r,now,why=admit(self,ticket);if not r then return false,nil,why end
 -- No user callback/yield occurs between this local reservation commit and
 -- invocation of the provider. Provider must begin its actual operation now;
 -- the existing backend still owns transform/lifetime/lease fences.
 r.state="started";table.insert(self.history,{actor=r.actor,kind=r.kind,at=now});changed(self)
 local returned=table.pack(pcall(provider))
 local live=current(self,r)
 remove(self,r)
 if not live then return false,nil,"provider completed after visit closed" end
 if not returned[1] then return false,nil,tostring(returned[2]) end
 local result={n=returned.n-1};for i=2,returned.n do result[i-1]=returned[i] end
 return true,result,nil
end
function Admission.inspect(self:any):any
 local now,why=clock(self);if not now then return nil,why end
 local queued,reserved,started=0,0,0
 for _,r in self.tickets do if r.state=="queued" then queued+=1 elseif r.state=="reserved" then reserved+=1 else started+=1 end end
 local all=amounts(self,"",nil)
 return {actors=size(self.actors),scopes=size(self.scopes),queued=queued,reserved=reserved,started=started,history=#self.history,read=all.read,write=all.write}
end
return table.freeze(Admission)
