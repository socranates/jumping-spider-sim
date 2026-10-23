local Admission=(function()
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
 assert(type(cfg)=="table" and getmetatable(cfg)==nil and type(cfg.now)=="function" and type(cfg.available)=="function","plain configuration, clock and current platform allowance required")
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
-- One-time transition from the aggregate scheduler. Every unknown operation is
-- conservatively charged as BOTH read and write, including departure overage.
-- Call before any typed request for this physical actor; never reseed on epoch
-- replacement. A server owner must switch every provider path together.
function Admission.importLegacy(self:any,scope:any,started:any):(boolean,string?)
 local now,why=clock(self);if not now then return false,why end
 if not self:live(scope) or type(started)~="table" or getmetatable(started)~=nil then return false,"live scope/plain history required" end
 local a=self.actors[scope.actor]
 if a.legacyImported then return false,"physical actor already seeded" end
 for _,r in self.tickets do if r.actor==scope.actor then return false,"seed before typed requests" end end
 for _,r in self.history do if r.actor==scope.actor then return false,"actor already has typed debt" end end
 local n=0;for key,t in started do
  if not integer(key,1,512) or not finite(t) or t>now then return false,"bounded past request history required" end
  n+=1
 end
 if n>512 then return false,"legacy history exceeds bound" end
 local rows={};for i=1,n do
  local t=started[i];if t==nil then return false,"dense history required" end
  if now-t<60 then table.insert(rows,{actor=scope.actor,kind="update",at=t}) end
 end
 -- Plain validated values require no callback between validation and adoption.
 for _,row in rows do table.insert(self.history,row) end
 a.legacyImported=true;changed(self);return true,nil
end
function Admission.legacyReady(self:any,scope:any):boolean
 return self:live(scope) and self.actors[scope.actor].legacyImported==true
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
-- Build once per admission attempt. No callback or yield can change these
-- totals while checking the earlier queue, so repeated history scans add no
-- safety and turn a busy queue into quadratic work.
local function ledger(self:any):any
 local all={read=0,write=0};local actors={};local held={read=0,write=0};local busy={}
 local function add(actor:string,w:any)
  local own=actors[actor];if not own then own={read=0,write=0};actors[actor]=own end
  all.read+=w.read;all.write+=w.write;own.read+=w.read;own.write+=w.write
 end
 for _,row in self.history do add(row.actor,weights[row.kind]) end
 for _,r in self.tickets do
  local w=weights[r.kind]
  if r.state=="started" then busy[r.actor]=true;held.read+=w.read;held.write+=w.write
  elseif r.state=="reserved" then add(r.actor,w);held.read+=w.read;held.write+=w.write end
 end
 return {all=all,actors=actors,held=held,busy=busy}
end
local function fits(self:any,r:any,available:any,totals:any):boolean
 if not current(self,r) then return false end
 if totals.busy[r.actor] then return false end
 local w=weights[r.kind];local all,held=totals.all,totals.held;local own=totals.actors[r.actor]
 for _,kind in {"read","write"} do
  if w[kind]>0 then
   local suffix=if kind=="read" then "Read" else "Write"
   local excluded=if r.state=="reserved" then w[kind] else 0
   if (if own then own[kind] else 0)-excluded+w[kind]>self.cfg["actor"..suffix] or all[kind]-excluded+w[kind]>self.cfg["server"..suffix]
    or available[kind]-held[kind]+excluded-self.headroom<w[kind] then return false end
  end
 end
 return true
end
local function allowance(self:any):(any?,string?)
 local version=self.version;local called,available=pcall(self.cfg.available)
 if self.version~=version then return nil,"admission changed during allowance lookup" end
 if not called or type(available)~="table" or getmetatable(available)~=nil or not finite(available.read) or not finite(available.write) or available.read<0 or available.write<0 then return nil,"current platform allowance unavailable" end
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
 local observedVersion=self.version
 now,why=clock(self);if not now then return nil,nil,why end
 if self.version~=observedVersion then return nil,nil,"admission changed during final clock check" end
 if not available or not current(self,r) then return nil,nil,problem or "request scope ended" end
 local totals=ledger(self)
 if not fits(self,r,available,totals) then return nil,nil,"waiting for admission" end
 local w=weights[r.kind]
 for _,earlier in self.queue do
  if earlier.order>=r.order then break end
  if earlier.state=="queued" and now-earlier.lastPoll<=self.reservationSeconds and fits(self,earlier,available,totals) then
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

end)()
local Facade=(function()
--!strict
-- Private polling facade. Waiting for admission makes no provider request and
-- does not impersonate a failed DataStore attempt. Existing backend transform
-- and physical-lease fences remain required underneath this additional guard.
local Facade={};Facade.__index=Facade
local kinds:{[string]:string}={readFresh="read",readRawFresh="read",update="update"}
function Facade.new(gate:any,scope:any,backend:any):any
 assert(gate:live(scope),"live physical visit required")
 local methods={}
 for method in kinds do assert(type(backend[method])=="function","backend method required: "..method);methods[method]=backend[method] end
 return setmetatable({gate=gate,scope=scope,backend=backend,methods=table.freeze(methods),jobs={},serial=0},Facade)
end
function Facade.begin(self:any,method:string,key:string,transform:((any)->any)?):(any?,string?)
 if not kinds[method] or type(key)~="string" or #key==0 or #key>50 or method=="update" and type(transform)~="function" then return nil,"bounded typed backend operation required" end
 local ticket,why=self.gate:request(self.scope,kinds[method]);if not ticket then return nil,why end
 self.serial+=1;local handle=table.freeze({id=self.serial})
 self.jobs[handle]={handle=handle,ticket=ticket,method=method,key=key,transform=transform,busy=false,started=false,cancelled=false}
 return handle,nil
end
local function live(self:any,r:any):boolean
 return self.jobs[r.handle]==r and not r.cancelled and self.gate:live(self.scope)
end
function Facade.cancel(self:any,handle:any):boolean
 local r=self.jobs[handle];if not r then return false end
 r.cancelled=true;self.gate:cancel(r.ticket)
 if not r.busy then self.jobs[handle]=nil end
 return true
end
function Facade.step(self:any,handle:any):(string,any?,string?)
 local r=self.jobs[handle];if not r then return "ended",nil,nil end
 if r.busy then return "waiting",nil,"provider already pending" end
 if not live(self,r) then self:cancel(handle);return "cancelled",nil,"visit ended" end
 r.busy=true
 local called,admitted,result,why=pcall(self.gate.dispatch,self.gate,r.ticket,function()
  if not live(self,r) then error("operation ended before provider",0) end
  r.started=true
  if r.method=="update" then
   return self.methods.update(self.backend,r.key,function(old:any):any
    if not live(self,r) then return nil end
    local value=r.transform(old)
    if not live(self,r) then return nil end
    return value
   end)
  end
  return self.methods[r.method](self.backend,r.key)
 end)
 r.busy=false
 if not live(self,r) then self.jobs[handle]=nil;self.gate:cancel(r.ticket);return "cancelled",nil,"operation ended during provider" end
 if not called then self.jobs[handle]=nil;self.gate:cancel(r.ticket);return "failed",nil,tostring(admitted) end
 if admitted then self.jobs[handle]=nil;return "done",result,nil end
 local state=self.gate:status(r.ticket)
 if state=="queued" or state=="reserved" or state=="clock_unavailable" then return "waiting",nil,why end
 self.jobs[handle]=nil;return "failed",nil,why
end
function Facade.inspect(self:any):any
 local jobs,busy,started=0,0,0
 for _,r in self.jobs do jobs+=1;if r.busy then busy+=1 end;if r.started then started+=1 end end
 return {jobs=jobs,busy=busy,started=started}
end
return table.freeze(Facade)

end)()
do

local passed,groups=0,0
local function check(value,why) passed+=1;assert(value,why or "admission assertion") end
local function group(name,fn)
 local before=passed;fn();groups+=1;print("ADMISSION_CASE",name,passed-before)
end
local function fixture(options)
 local f={time=0,read=100,write=100,starts={},lookup=nil}
 local cfg={now=function() if f.clock then return f.clock() end;return f.time end,available=function() if f.lookup then return f.lookup() end;return {read=f.read,write=f.write} end,
  actorRead=30,actorWrite=10,serverRead=60,serverWrite=30,headroom=1,maxActors=16,maxPending=64}
 for k,v in options or {} do cfg[k]=v end
 local g=Admission.new(cfg)
 local function provider(actor,kind,body)
  return function()
   if kind~="write" then check(f.read>0,"provider started without a read allowance");f.read-=1 end
   if kind~="read" then check(f.write>0,"provider started without a write allowance");f.write-=1 end
   table.insert(f.starts,{actor=actor,kind=kind,at=f.time})
   if body then return body() end
   return "value",nil,"third"
  end
 end
 return g,f,provider,cfg
end
local function open(g,actor,epoch) local s,why=g:open(actor,epoch or "epoch1");assert(s,why);return s end
local function request(g,s,kind) local t,why=g:request(s,kind);assert(t,why);return t end
group("zero-and-changing-allowance",function()
 local g,f,p=fixture();local s=open(g,"a");f.read=0
 local t=request(g,s,"read");check(not g:reserve(t));check(not g:dispatch(t,p("a","read")));check(#f.starts==0)
 f.read=2;check(g:reserve(t));f.read=1;check(not g:dispatch(t,p("a","read")));check(#f.starts==0)
 f.read=2;local ok,v=g:dispatch(t,p("a","read"));check(ok and v.n==3 and v[1]=="value" and v[2]==nil and v[3]=="third")
 check(#f.starts==1 and g:status(t)=="ended");check(not g:dispatch(t,p("a","read")))
end)
group("operation-types-and-headroom",function()
 local g,f,p=fixture();local s=open(g,"a");f.write=1
 check(g:dispatch(request(g,s,"read"),p("a","read")))
 local t=request(g,s,"update");check(not g:dispatch(t,p("a","update")));check(#f.starts==1)
 f.write=2;check(g:dispatch(t,p("a","update")));check(f.write==1 and #f.starts==2)
 f.read=0;f.write=2;check(g:dispatch(request(g,s,"write"),p("a","write")))
 local info=g:inspect();check(info.read==2 and info.write==2)
end)
group("per-actor-and-server-rolling-caps",function()
 local g,f,p=fixture({actorRead=1,serverRead=2});local a=open(g,"a");local b=open(g,"b")
 check(g:dispatch(request(g,a,"read"),p("a","read")))
 local ta=request(g,a,"read");check(not g:dispatch(ta,p("a","read")))
 check(g:dispatch(request(g,b,"read"),p("b","read")))
 local tb=request(g,b,"read");check(not g:dispatch(tb,p("b","read")))
 f.time=59.999;check(not g:dispatch(ta,p("a","read")))
 f.time=60;check(g:dispatch(ta,p("a","read")));check(g:dispatch(tb,p("b","read")));check(#f.starts==4)
end)
group("write-cap-does-not-block-independent-reads",function()
 local g,f,p=fixture({actorWrite=1});local a=open(g,"a");local b=open(g,"b")
 check(g:dispatch(request(g,a,"write"),p("a","write")))
 local old=request(g,a,"update");check(not g:dispatch(old,p("a","update")))
 check(g:dispatch(request(g,b,"read"),p("b","read")))
 check(#f.starts==2 and f.starts[2].kind=="read")
end)
group("fair-queue-and-abandoned-poller",function()
 local g,f,p=fixture();local a=open(g,"a");local b=open(g,"b")
 local first=request(g,a,"read");local nextOne=request(g,b,"read")
 check(not g:dispatch(nextOne,p("b","read")));check(#f.starts==0)
 check(g:dispatch(first,p("a","read")));check(g:dispatch(nextOne,p("b","read")))
 local abandoned=request(g,a,"read");local active=request(g,b,"read");f.time=2.001
 check(g:dispatch(active,p("b","read")));check(g:status(abandoned)=="queued")
 check(g:dispatch(abandoned,p("a","read")))
end)
group("reservation-and-pending-capacity",function()
 local g,f,p=fixture({serverRead=2,maxPending=3});local a=open(g,"a");local b=open(g,"b");local c=open(g,"c")
 local ta=request(g,a,"read");local tb=request(g,b,"read");local tc=request(g,c,"read")
 check(g:reserve(ta));check(g:reserve(tb));check(not g:reserve(tc));check(g:inspect().history==0)
 check(g:request(a,"read")==nil);check(g:cancel(ta));check(g:reserve(tc))
 check(g:dispatch(tb,p("b","read")));check(g:dispatch(tc,p("c","read")));check(#f.starts==2)
end)
group("reservation-expiry-is-terminal",function()
 local g,f,p=fixture();local a=open(g,"a");local b=open(g,"b")
 local old=request(g,a,"read");check(g:reserve(old));local waiting=request(g,b,"read")
 f.time=2;check(g:status(old)=="ended");check(not g:dispatch(old,p("a","read")))
 check(g:dispatch(waiting,p("b","read")));check(#f.starts==1)
end)
group("closed-visits-carry-debt",function()
 local g,f,p=fixture({actorRead=1});local a=open(g,"a","one")
 check(g:dispatch(request(g,a,"read"),p("a","read")));check(g:close(a));check(not g:close(a))
 check(g:open("a","one")==nil);local fresh=open(g,"a","two");local t=request(g,fresh,"read")
 check(not g:dispatch(t,p("a","read")));check(#f.starts==1)
 f.time=60;check(g:dispatch(t,p("a","read")));check(#f.starts==2)
end)
group("provider-yield-close-and-drain",function()
 local g,f,p=fixture({actorRead=1});local a=open(g,"a","one");local t=request(g,a,"read");local result
 local co=coroutine.create(function() result=table.pack(g:dispatch(t,p("a","read",function() coroutine.yield("provider");return "obsolete" end))) end)
 local ok,where=coroutine.resume(co);check(ok and where=="provider");check(g:inspect().started==1)
 check(g:close(a));check(g:open("a","two")==nil);check(not g:cancel(t))
 check(coroutine.resume(co));check(result[1]==false and result[2]==nil and result[3]=="provider completed after visit closed")
 local fresh=open(g,"a","two");check(not g:dispatch(request(g,fresh,"read"),p("a","read")));check(#f.starts==1)
end)
group("in-flight-capacity-is-reserved",function()
 local g,f,p=fixture();local a=open(g,"a");local b=open(g,"b");f.read=3
 local co=coroutine.create(function() check(g:dispatch(request(g,a,"read"),p("a","read",function() coroutine.yield();return true end))) end)
 check(coroutine.resume(co));local t=request(g,b,"read");check(not g:dispatch(t,p("b","read")));check(#f.starts==1)
 check(coroutine.resume(co));check(g:dispatch(t,p("b","read")));check(#f.starts==2)
end)
group("cancel-during-yielding-budget-query",function()
 local g,f,p=fixture();local a=open(g,"a");local t=request(g,a,"read");local result
 f.lookup=function() coroutine.yield("lookup");return {read=100,write=100} end
 local co=coroutine.create(function() result=table.pack(g:dispatch(t,p("a","read"))) end)
 local okay,where=coroutine.resume(co);check(okay and where=="lookup");check(g:cancel(t));check(coroutine.resume(co))
 check(result[1]==false and #f.starts==0 and g:inspect().history==0)
end)
group("reentrant-budget-query-cannot-admit-stale-state",function()
 local g,f,p=fixture();local a=open(g,"a");local b=open(g,"b");local ta=request(g,a,"read");local tb=request(g,b,"write");local entered=false
 f.lookup=function()
  if not entered then entered=true;check(g:dispatch(tb,p("b","write"))) end
  return {read=f.read,write=f.write}
 end
 check(not g:dispatch(ta,p("a","read")));check(#f.starts==1 and f.starts[1].actor=="b")
 check(g:dispatch(ta,p("a","read")));check(#f.starts==2)
end)
group("reentrant-clock-after-allowance-cannot-oversubscribe",function()
 local g,f,p=fixture();local a=open(g,"a");local b=open(g,"b")
 local tb=request(g,b,"read");local ta=request(g,a,"read");f.read=2
 local queried,inside=false,false
 f.lookup=function() queried=true;return {read=f.read,write=f.write} end
 f.clock=function()
  if queried and not inside then inside=true;check(g:dispatch(tb,p("b","read"))) end
  return f.time
 end
 check(not g:dispatch(ta,p("a","read")));check(#f.starts==1 and f.starts[1].actor=="b")
 f.clock=nil;f.lookup=nil;check(not g:dispatch(ta,p("a","read")));check(#f.starts==1)
end)
group("closed-scope-during-budget-query",function()
 local g,f,p=fixture();local a=open(g,"a");local t=request(g,a,"update")
 f.lookup=function() g:close(a);return {read=100,write=100} end
 check(not g:dispatch(t,p("a","update")));check(#f.starts==0 and g:inspect().history==0)
end)
group("provider-reentrancy-cannot-overlap-a-physical-actor",function()
 local g,f,p=fixture();local a=open(g,"a");local first=request(g,a,"read");local second=request(g,a,"update")
 check(g:dispatch(first,p("a","read",function()
  check(not g:dispatch(first,p("a","read")))
  check(not g:dispatch(second,p("a","update")))
  check(#f.starts==1)
 end)))
 check(g:dispatch(second,p("a","update")));check(#f.starts==2)
end)
group("ticket-expiry-during-budget-query",function()
 local g,f,p=fixture();local a=open(g,"a");local t=request(g,a,"read")
 f.lookup=function() f.time=120;return {read=100,write=100} end
 check(not g:dispatch(t,p("a","read")));check(#f.starts==0 and g:status(t)=="ended")
end)
group("provider-failure-is-charged",function()
 local g,f,p=fixture({actorRead=1});local a=open(g,"a")
 local okay,_,why=g:dispatch(request(g,a,"read"),p("a","read",function() error("synthetic provider failure") end))
 check(not okay and string.find(why,"synthetic provider failure",1,true));check(#f.starts==1 and g:inspect().history==1)
 check(not g:dispatch(request(g,a,"read"),p("a","read")))
end)
group("invalid-allowance-and-clock-refuse-without-start",function()
 local g,f,p=fixture();local a=open(g,"a");local t=request(g,a,"read")
 for _,v in {false,{read=0/0,write=100},{read=math.huge,write=100},{read=-1,write=100},{read="100",write=100},setmetatable({read=100,write=100},{})} do
  f.lookup=function() return v end;check(not g:dispatch(t,p("a","read")));check(#f.starts==0)
 end
 f.lookup=function() error("budget API unavailable") end;check(not g:dispatch(t,p("a","read")));check(#f.starts==0)
 f.lookup=nil;f.time=10;check(g:dispatch(t,p("a","read")))
 local nextOne=request(g,a,"read");f.time=9;check(not g:dispatch(nextOne,p("a","read")));check(g:status(nextOne)=="clock_unavailable")
 f.time=0/0;check(not g:dispatch(nextOne,p("a","read")));check(#f.starts==1)
 f.time=10;check(g:dispatch(nextOne,p("a","read")));check(#f.starts==2)
end)
group("bounded-memory-and-physical-actor-retention",function()
 local g,f,p=fixture({maxActors=1,maxPending=2});local a=open(g,"a")
 check(g:dispatch(request(g,a,"read"),p("a","read")));check(g:close(a));check(g:open("b","next")==nil)
 f.time=60;local b=open(g,"b","next");check(g:inspect().actors==1)
 local t=request(g,b,"read");f.time=180;check(g:status(t)=="ended");check(g:close(b));check(g:inspect().actors==0)
 for n=1,500 do
  local scope=open(g,"actor"..n,"e"..n);local pending=request(g,scope,"read");check(g:cancel(pending));check(g:close(scope));check(g:inspect().actors==0)
 end
 check(g:inspect().queued==0 and g:inspect().history==0 and #f.starts==1)
end)
group("opaque-handles-and-immutable-configuration",function()
 local g,f,p,cfg=fixture({actorRead=1});local a=open(g,"a");local t=request(g,a,"read")
 check(not g:dispatch({id=t.id},p("a","read")));check(g:request({id=a.id,actor="a",epoch="epoch1"},"read")==nil)
 check(not pcall(function() t.id=1 end));check(not pcall(function() a.actor="b" end))
 cfg.actorRead=1000;check(g:dispatch(t,p("a","read")));check(not g:dispatch(request(g,a,"read"),p("a","read")));check(#f.starts==1)
end)
group("independent-rolling-oracle",function()
 local g,f,p=fixture({actorRead=3,actorWrite=2,serverRead=5,serverWrite=3,headroom=2,maxActors=4,maxPending=16})
 local scopes={open(g,"a"),open(g,"b"),open(g,"c")};local queued={};local kinds={"read","update","write"}
 for tick=0,599 do
  f.time=tick*.5;f.read=20;f.write=20
  for i,scope in scopes do
   if not queued[i] then local kind=kinds[(tick+i)%3+1];queued[i]={ticket=request(g,scope,kind),kind=kind} end
   local t=queued[i].ticket;local success=g:dispatch(t,p(scope.actor,queued[i].kind))
   if success then queued[i]=nil elseif g:status(t)=="ended" then queued[i]=nil end
  end
  local read,write=0,0;local actors={}
  for _,start in f.starts do if f.time-start.at<60 then
   local a=actors[start.actor] or {read=0,write=0};actors[start.actor]=a
   if start.kind~="write" then read+=1;a.read+=1 end
   if start.kind~="read" then write+=1;a.write+=1 end
  end end
  check(read<=5 and write<=3,"independent server rolling quota exceeded")
  for _,a in actors do check(a.read<=3 and a.write<=2,"independent actor rolling quota exceeded") end
  check(g:inspect().queued<=3,"queue leaked in long interleaving")
 end
 check(#f.starts>15,"oracle never exercised replenished budgets")
end)
group("mixed-workload-does-not-spend-write-budget-on-reads",function()
 local g,f,p=fixture();local s=open(g,"a")
 for _=1,24 do check(g:dispatch(request(g,s,"read"),p("a","read"))) end
 for _=1,6 do check(g:dispatch(request(g,s,"update"),p("a","update"))) end
 check(#f.starts==30 and g:inspect().read==30 and g:inspect().write==6)
 -- The legacy aggregate10/min policy needs two60s waits for these same30
 -- starts. This is an admission-only synthetic comparison, not game timing.
 local legacyStarts={};local now=0
 for _=1,30 do
  local count=0;for _,at in legacyStarts do if now-at<60 then count+=1 end end
  if count>=10 then now+=60 end;table.insert(legacyStarts,now)
 end
 check(now==120 and f.time==0)
 print("ADMISSION_SYNTHETIC_MIX",#f.starts,"read_units=30 write_units=6 legacy_wait=120 candidate_wait=0")
end)
print("REQUEST_ADMISSION passed="..passed.." failed=0 groups="..groups)

end
local optionEvents={created=0,destroyed=0}
local Instance={new=function(class)
 assert(class=="DataStoreGetOptions");optionEvents.created+=1
 local value={UseCache=true,destroyed=false}
 function value:Destroy() assert(not self.destroyed);self.destroyed=true;optionEvents.destroyed+=1 end
 return value
end}
local Backend=(function()
--!strict
-- Roblox DataStore adapter (read and update, neither raises). An optional storage codec handles only R_ rest keys;
-- transforms always see the original envelope. Failed decoding/compression never replaces an earlier stored value.
-- Store and codec are injected for boundary tests; only the server owns real DataStore access.
local DataStoreBackend = {}
DataStoreBackend.__index = DataStoreBackend

function DataStoreBackend.new(dataStore: any, restCodec: any?): any
	return setmetatable({ ds = dataStore, restCodec = restCodec }, DataStoreBackend)
end

local function restKey(key: string): boolean return string.sub(key,1,2)=="R_" end

-- GetAsync: ok, the value (nil when the key does not exist), the error text.
function DataStoreBackend.read(self: any, key: string): (boolean, any, string?)
	local ok, value = pcall(function(): any return self.ds:GetAsync(key) end)
	if not ok then return false, nil, tostring(value) end
	if self.restCodec and restKey(key) then
		local decoded, result=pcall(function(): any return self.restCodec:decode(value,true) end)
		if not decoded then return false,nil,tostring(result) end
		value=result
	end
	return true, value, nil
end

-- UpdateAsync: `transform(old)` returns the new value, or nil to leave the key as it is. Roblox may call it more than once.
function DataStoreBackend.update(self: any, key: string, transform: (any) -> any): (boolean, any, string?)
	local callbackError: string? = nil
	local ok, value = pcall(function(): any
		local useCodec=self.restCodec~=nil and restKey(key)
		local result = self.ds:UpdateAsync(key, function(stored: any): any
			-- Native UpdateAsync can log a thrown callback error and return nil to its caller.
			-- Catch inside the callback, cancel the write, then report the failure outside that API boundary.
			if callbackError ~= nil then return nil end
			local transformed, candidate = pcall(function(): any
				local old=if useCodec then self.restCodec:decode(stored) else stored
				local nextValue=transform(old)
				if nextValue==nil then return nil end
				return if useCodec then self.restCodec:encode(nextValue) else nextValue
			end)
			if not transformed then callbackError=tostring(candidate);return nil end
			return candidate
		end)
		if callbackError ~= nil then error(callbackError, 0) end
		if useCodec then return self.restCodec:decode(result) end
		return result
	end)
	if not ok then return false, nil, tostring(value) end
	return true, value, nil
end

-- Explicit verification/recovery reads. Ordinary cached reads are unchanged.
-- See Creator Hub data-store caching: UseCache=false is required to resolve an
-- ambiguous write against current backend state rather than a local cached copy.
local function freshValue(self:any,key:string):(boolean,any,string?)
 local options:DataStoreGetOptions?=nil
 local ok,value=pcall(function():any
  local request=Instance.new("DataStoreGetOptions")
  options=request;request.UseCache=false
  return self.ds:GetAsync(key,request)
 end)
 if options then options:Destroy() end
 if not ok then return false,nil,tostring(value) end
 return true,value,nil
end
function DataStoreBackend.readRawFresh(self:any,key:string):(boolean,any,string?)
 -- Preserve the whole stored representation before any rest codec or fallback.
 return freshValue(self,key)
end
function DataStoreBackend.readFresh(self:any,key:string):(boolean,any,string?)
 local ok,value,why=freshValue(self,key)
 if not ok then return false,nil,why end
 if self.restCodec and restKey(key) then
  local decoded,result=pcall(function():any return self.restCodec:decode(value,true) end)
  if not decoded then return false,nil,tostring(result) end
  value=result
 end
 return true,value,nil
end

return DataStoreBackend

end)()
do
-- Executed with the exact production DataStoreBackend and an injected store.
local passed,groups=0,0
local function check(v,why) passed+=1;assert(v,why or "backend admission assertion") end
local function group(name,fn) local before=passed;fn();groups+=1;print("ADMISSION_BACKEND_CASE",name,passed-before) end
local function copy(v) if type(v)~="table" then return v end;local out={};for k,x in v do out[k]=copy(x) end;return out end
local function fixture()
 local f={time=0,read=100,write=100,calls=0,callbacks=0,values={R_a_main={original=7,backup={original=3},unknown="retain"}},options=0,afterCallback=nil,beforeRead=nil,afterWrite=nil,fail=nil}
 local gate=Admission.new({now=function() return f.time end,available=function() return {read=f.read,write=f.write} end,actorRead=30,actorWrite=10,serverRead=60,serverWrite=30,headroom=1})
 local scope=assert(gate:open("a","one"));local ds={}
 function ds:GetAsync(key,options)
  check(options and options.UseCache==false,"verification read used a cached path")
  f.calls+=1;f.read-=1;f.options+=1
  if f.beforeRead then f.beforeRead() end
  if f.fail then error(f.fail) end
  return copy(f.values[key])
 end
 function ds:UpdateAsync(key,transform)
  f.calls+=1;f.read-=1;f.write-=1
  if f.fail then error(f.fail) end
  local candidate
  for i=1,2 do f.callbacks+=1;candidate=transform(copy(f.values[key]));if i==1 and f.afterCallback then f.afterCallback() end end
  if candidate~=nil then f.values[key]=copy(candidate) end
  if f.afterWrite then f.afterWrite() end
  return copy(f.values[key])
 end
 local backend=Backend.new(ds);local facade=Facade.new(gate,scope,backend)
 return gate,scope,facade,f,backend
end
group("zero-budget-is-pending-not-provider-failure",function()
 local g,s,io,f=fixture();f.read=0
 local h=assert(io:begin("readRawFresh","R_a_main"))
 for _=1,40 do check(io:step(h)=="waiting") end
 check(f.calls==0 and g:inspect().history==0 and io:inspect().started==0)
 f.read=2;local state,values=io:step(h);check(state=="done" and values[1]==true and values[2].original==7)
 check(f.calls==1 and g:inspect().read==1 and g:inspect().write==0 and io:inspect().jobs==0)
end)
group("fresh-read-and-typed-update-boundaries",function()
 local g,s,io,f,backend=fixture()
 check(io:begin("read","R_a_main")==nil);check(io:begin("update","R_a_main")==nil)
 -- Method identity is captured at facade construction.
 backend.readRawFresh=function() error("method was rebound") end
 for _,method in {"readRawFresh","readFresh"} do
  local state,v=io:step(assert(io:begin(method,"R_a_main")));check(state=="done" and v[1] and v[2].backup.original==3)
 end
 local state,v=io:step(assert(io:begin("update","R_a_main",function(old) old.original=8;return old end)))
 check(state=="done" and v[1] and v[2].original==8 and v[2].backup.original==3 and v[2].unknown=="retain")
 check(f.calls==3 and f.callbacks==2 and g:inspect().read==3 and g:inspect().write==1)
end)
group("cancelled-queued-operation-never-starts",function()
 local g,s,io,f=fixture();f.read=0
 local h=assert(io:begin("update","R_a_main",function() error("cancelled transform ran") end))
 check(io:step(h)=="waiting");check(io:cancel(h));f.read=100
 check(io:step(h)=="ended" and f.calls==0 and g:inspect().history==0)
 check(f.values.R_a_main.original==7 and f.values.R_a_main.unknown=="retain")
end)
group("yielding-read-cannot-return-an-obsolete-result",function()
 local g,s,io,f=fixture();f.beforeRead=function() coroutine.yield("read pending") end
 local h=assert(io:begin("readRawFresh","R_a_main"));local result
 local co=coroutine.create(function() result=table.pack(io:step(h)) end)
 local ok,where=coroutine.resume(co);check(ok and where=="read pending")
 check(io:step(h)=="waiting" and f.calls==1);check(io:cancel(h));check(coroutine.resume(co))
 check(result[1]=="cancelled" and result[2]==nil and io:inspect().jobs==0 and g:inspect().history==1)
end)
group("repeated-update-callback-rechecks-cancellation",function()
 local g,s,io,f=fixture();local h
 h=assert(io:begin("update","R_a_main",function(old) old.original=99;return old end))
 f.afterCallback=function() check(io:cancel(h)) end
 check(io:step(h)=="cancelled");check(f.callbacks==2 and f.calls==1)
 check(f.values.R_a_main.original==7 and f.values.R_a_main.backup.original==3 and f.values.R_a_main.unknown=="retain")
 check(g:inspect().read==1 and g:inspect().write==1 and io:inspect().jobs==0)
end)
group("scope-end-inside-transform-cancels-candidate",function()
 local g,s,io,f=fixture()
 local h=assert(io:begin("update","R_a_main",function(old) g:close(s);old.original=99;return old end))
 check(io:step(h)=="cancelled");check(f.values.R_a_main.original==7 and f.calls==1)
 local nextScope=assert(g:open("a","two"));check(g:live(nextScope) and not g:live(s));check(g:inspect().read==1 and g:inspect().write==1)
end)
group("ambiguous-ack-does-not-refund-or-report-success",function()
 local g,s,io,f=fixture();f.afterWrite=function() coroutine.yield("ack pending") end
 local h=assert(io:begin("update","R_a_main",function(old) old.original=9;return old end));local result
 local co=coroutine.create(function() result=table.pack(io:step(h)) end)
 local ok,where=coroutine.resume(co);check(ok and where=="ack pending" and f.values.R_a_main.original==9)
 check(g:close(s));check(g:open("a","two")==nil);check(coroutine.resume(co))
 check(result[1]=="cancelled" and result[2]==nil)
 check(g:inspect().read==1 and g:inspect().write==1 and f.calls==1)
 check(g:open("a","two")~=nil)
end)
group("actual-backend-errors-retain-provider-result",function()
 local g,s,io,f=fixture();f.fail="synthetic native adapter failure"
 local state,v=io:step(assert(io:begin("readFresh","R_a_main")))
 check(state=="done" and v[1]==false and v[2]==nil and string.find(v[3],f.fail,1,true))
 check(g:inspect().history==1 and f.calls==1 and io:inspect().jobs==0)
end)
check(optionEvents.created==optionEvents.destroyed and optionEvents.created>0,"production backend leaked read options")
print("ADMISSION_BACKEND passed="..passed.." failed=0 groups="..groups.." options="..optionEvents.created)

end
local Work=(function()
--!strict
-- Cooperative preparation only. Callers must own/hold stable inputs and gate
-- publication against their current intent. This scheduler does not snapshot
-- mutable inputs or make a function's side effects transactional.
-- Step at most once per frame. Budgets are soft: native calls and code without
-- pulse points cannot be preempted. Results remain private until take().
local Work={}
Work.__index=Work
type Pulse=(number?)->()
local active:{[thread]:Pulse}={}
local YIELD={}
local function positive(n:any):boolean
 return type(n)=="number" and n==n and n>0 and n<math.huge
end
function Work.pulse():Pulse?
 local co=coroutine.running()
 return if co then active[co] else nil
end
function Work.new(fn:()->...any,options:any?):any
 local cfg=options or {}
 local now=cfg.now or os.clock
 local budget=cfg.budget or .004
 local maxSeconds=cfg.maxSeconds or 60
 local maxResumes=cfg.maxResumes or 10000
 assert(positive(budget) and positive(maxSeconds) and positive(maxResumes) and maxResumes==math.floor(maxResumes),"invalid work bounds")
 local self:any=setmetatable({now=now,budget=budget,maxSeconds=maxSeconds,maxResumes=maxResumes,
  born=now(),deadline=0,resumes=0,units=0,state="pending",problem=nil,result=nil,thread=coroutine.create(fn)},Work)
 self.checkpoint=function(units:number?)
  self.units+=units or 1
  if self.units>=64 then
   self.units=0
   if self.now()>=self.deadline then coroutine.yield(YIELD) end
  end
 end
 return self
end
local function fail(self:any,problem:string)
 self.state,self.problem,self.thread,self.result="failed",problem,nil,nil
end
function Work.step(self:any):boolean
 if self.state~="pending" then return false end
 if self.resumes>=self.maxResumes or self.now()-self.born>=self.maxSeconds then fail(self,"preparation timed out");return false end
 local co=self.thread
 self.resumes+=1;self.deadline=self.now()+self.budget;self.state="running"
 active[co]=self.checkpoint
 local reply:any=table.pack(coroutine.resume(co))
 active[co]=nil -- remove even after an error or an unexpected yield
 if (self.state :: string)=="cancelled" then self.thread,self.result=nil,nil;return false end
 if not reply[1] then fail(self,tostring(reply[2]));return false end
 if self.now()-self.born>=self.maxSeconds then fail(self,"preparation timed out");return false end
 if coroutine.status(co)=="dead" then
  local result:any={n=reply.n-1}
  for i=2,reply.n do result[i-1]=reply[i] end
  self.result,self.thread,self.state=result,nil,"done"
 elseif reply.n==2 and reply[2]==YIELD then self.state="pending"
 else fail(self,"unexpected preparation yield");return false end
 return true
end
function Work.cancel(self:any):boolean
 if self.state=="consumed" or self.state=="failed" or self.state=="cancelled" then return false end
 self.state,self.thread,self.result="cancelled",nil,nil
 return true
end
function Work.take(self:any):any?
 if self.state~="done" then return nil end
 local result=self.result;self.result=nil;self.state="consumed"
 return result
end
return Work

end)()
local Json=(function()
--!strict
-- What a Roblox DataStore can hold, checked without the engine (ROBLOX-25), and the canonical text a checksum is taken over
-- (Godot's checkpoint_store.gd: sorted keys, full precision). A value is storable when it is a string, a boolean, a finite
-- number, a list (keys 1..n, no holes) or a table whose keys are all strings, made of storable values, with no table met
-- twice. Pure; tests/checkpoint.luau checks it.

local Work = Work
local Json = {}

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local ESC: { [string]: string } = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function quote(s: string): string
	if string.find(s, '[%c"\\]') == nil then return '"' .. s .. '"' end -- (ROBLOX-108: most strings need no escape)
	return '"' .. string.gsub(s, '[%c"\\]', function(c: string): string
		return ESC[c] or string.format("\\u%04x", string.byte(c))
	end) .. '"'
end

-- The kind of table: "list" (keys exactly 1..n; an empty table counts as a list), "object" (all keys strings) or nil.
local function shape(t: { [any]: any }, pulse: ((number?)->())?): string?
	local n, strings, others = 0, 0, 0
	for k in t do
  if pulse then pulse() end
		if type(k) == "string" then
			strings += 1
		elseif type(k) == "number" then
			others += 1
		else
			return nil
		end
		n += 1
	end
	if strings == n then return if n == 0 then "list" else "object" end
	if others == n then
		for i = 1, n do
   if pulse then pulse() end
			if t[i] == nil then return nil end
		end
		return "list"
	end
	return nil
end

-- The canonical JSON text of `v`, or nil and why it is not storable.
-- (ROBLOX-108: the path a problem names is kept as a stack of keys and spelt out only when there is a problem; it was a new string for every value, most of the
-- cost of a checkpoint's save, which runs on the frame the rest begins. The text and every message are as they were.)
-- One owned fragment buffer avoids a temporary buffer/string for every table.
-- Traversal, validation, number formatting, quoting and error paths stay the same.
function Json.canonical(v: any): (string?, string?)
 local pulse=Work.pulse()
 local seen: {[any]:boolean}={}
 local problem:string?=nil
 local trail:{any}={}
 local parts:{string}={}
 local function where():string
  local out="value"
  for _,k in trail do
   if type(k)=="number" then out..=`[{k}]` else out..=`.{k}` end
  end
  return out
 end
 local function enc(x:any)
  if pulse then pulse() end
  if problem then return end
  local t=type(x)
  if t=="string" then table.insert(parts,quote(x));return end
  if t=="boolean" then table.insert(parts,if x then "true" else "false");return end
  if t=="number" then
   if not finite(x) then problem=`{where()}: a number JSON cannot hold`;return end
   if x==math.floor(x) and math.abs(x)<2^53 then table.insert(parts,string.format("%d",x))
   else table.insert(parts,string.format("%.17g",x)) end
   return
  end
  if t~="table" then problem=`{where()}: a {typeof(x)}`;return end
  if getmetatable(x)~=nil then problem=`{where()}: a table with a metatable`;return end
  if seen[x] then problem=`{where()}: a table met twice`;return end
  seen[x]=true
  local kind=shape(x,pulse)
  local depth=#trail+1
  if kind=="list" then
   table.insert(parts,"[")
   for i,y in ipairs(x) do
    if i>1 then table.insert(parts,",") end
    trail[depth]=i;enc(y)
    if problem then break end
   end
   trail[depth]=nil;table.insert(parts,"]")
  elseif kind=="object" then
   local keys:{string}={}
   for k in x do if pulse then pulse() end;table.insert(keys,k) end
   table.sort(keys)
   table.insert(parts,"{")
   for i,k in keys do
    if i>1 then table.insert(parts,",") end
    trail[depth]=k;table.insert(parts,quote(k)..":");enc(x[k])
    if problem then break end
   end
   trail[depth]=nil;table.insert(parts,"}")
  else problem=`{where()}: a table with mixed or sparse keys` end
 end
 enc(v)
 if problem then return nil,problem end
 return table.concat(parts),nil
end


-- A deep copy of a storable value (what a DataStore hands back is never the table that was given to it).
local function copy(v: any, pulse: ((number?)->())?): any
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do
  if pulse then pulse() end
  out[k] = if type(x) == "table" then copy(x,pulse) else x
 end
	return out
end
function Json.copy(v: any): any return copy(v,Work.pulse()) end

-- FNV-1a over the text, two independent 32-bit lanes, as 16 hex digits: enough to catch a record cut short or changed.
-- x * 16777619 (the FNV prime, 2^24 + 403) modulo 2^32, exactly, as ((x % 256) * 2^24 + x * 403) % 2^32: a plain product of two 32-bit numbers can exceed 2^53.
-- (ROBLOX-108: the bytes are read a block at a time and the multiply is written out in the loop: the same sums as before, one byte at a time, in less time.)
local BLOCK = 2048
function Json.checksum(text: string): string
 local pulse=Work.pulse()
	local a, b = 0x811c9dc5, 0x050c5d1f
	local n = #text
	local bxor = bit32.bxor
	local i0 = 1
	while i0 <= n do
  if pulse then pulse(64) end
		local i1 = math.min(n, i0 + BLOCK - 1)
		local bytes = { string.byte(text, i0, i1) }
		for j, c in bytes do
			local x = bxor(a, c)
			a = ((x % 256) * 16777216 + x * 403) % 4294967296
			local y = bxor(b, (c + i0 + j - 1) % 256)
			b = ((y % 256) * 16777216 + y * 403) % 4294967296
		end
		i0 = i1 + 1
	end
	return string.format("%08x%08x", a, b)
end

return Json

end)()
local Rules=(function()
--!strict
-- Every number and name the persistent saves use (ROBLOX-39): store names, key prefixes, sizes, timings, limits. The logic is in
-- Shared/Persistence/Save*.luau; none of it carries a number of its own. Sizes were measured on real checkpoints (tests/state.luau
-- prints them; docs/HANDOFF-roblox-state.md records them).
local SaveRules = {}

-- ---------------------------------------------------------------- where it is kept
SaveRules.STORE_PRODUCTION = "Windowsill_v1"
SaveRules.STORE_TEST = "WindowsillTest_v1" -- Studio and the test place: Chet's runs never touch a real save
SaveRules.KEY_PROGRESS = "P_" -- P_<UserId>: the player's progress (small, precious)
SaveRules.KEY_REST = "R_" -- R_<UserId>_main, R_<UserId>_easy, R_<UserId>_free: the last rest of each slot (larger, replaceable)
-- The slots a rest is filed in (ROBLOX-91): the standard main life ("main": every save made before the Easy slot existed keeps this key, whatever its rules), the main
-- life on Easy's gentle rules ("easy": it used to share the main slot, so starting Easy wiped the standard rest) and free play ("free").
SaveRules.MODES = { "main", "free", "easy" } :: { string }
SaveRules.FORMAT = "the-windowsill save"
SaveRules.REMOTES_NAME = "SaveRemotes" -- the folder in ReplicatedStorage holding ToServer and ToClient

-- ---------------------------------------------------------------- sizes (characters of canonical JSON)
-- Expanded validation bounds, NOT the stored-value budget. The full preserve initialization is 2.28M characters.
-- Server/RestCompression bounds the actual compressed envelope INCLUDING its backup to 1.5M stored characters,
-- and checks its Zstd frame size before expanding (12M maximum). Old uncompressed records remain readable.
SaveRules.MAX_REST_CHARS = 5000000
SaveRules.MAX_REST_NODES = 600000 -- values a rest may hold, checked before encoding/checkpoint graph construction
SaveRules.MAX_DEPTH = 24
SaveRules.MAX_PROGRESS_CHARS = 16384
SaveRules.MAX_VALUE_CHARS = 4194304 -- Roblox's own limit on one stored value
SaveRules.MAX_PROGRESS_NODES = 1500 -- values a progress message may hold, counted before anything reads it
SaveRules.MAX_PROGRESS_DEPTH = 8
SaveRules.MAX_PAGES = 200 -- notebook ids kept (the book has 25 pages; room for the future)
SaveRules.MAX_ID_CHARS = 48
SaveRules.MAX_EYE_SECONDS = 1.0e9

-- ---------------------------------------------------------------- timing (seconds)
SaveRules.PROGRESS_DEBOUNCE = 30 -- at most one progress write in this time (events in between are coalesced)
SaveRules.REST_MIN_INTERVAL = 10 -- a key may be written about every 6 s; this leaves room
SaveRules.HEARTBEAT = 30 -- the session lock is refreshed this often
SaveRules.LOCK_STALE = 120 -- a lock older than this may be taken over by a newer session
SaveRules.BACKOFF_BASE = 2
SaveRules.BACKOFF_CAP = 60
SaveRules.RETRY_LOAD = 15 -- a session that could not load or lock tries again this often
SaveRules.FLUSH_ATTEMPTS = 4 -- tries at leaving or shutting down, with the backoff between
SaveRules.FLUSH_BACKOFF = 1
SaveRules.FLUSH_DEADLINE = 24 -- BindToClose has 30 s in all
SaveRules.REQUESTS_PER_MINUTE = 10 -- DataStore requests one player's session may start in a minute (the budget is 60 + 10 per player)

-- ---------------------------------------------------------------- what the client may send (per player)
SaveRules.PROGRESS_BURST = 6
SaveRules.PROGRESS_PER_SECOND = 0.5
SaveRules.REST_BURST = 2
SaveRules.REST_PER_SECOND = 0.2
SaveRules.LIFE_BURST = 2
SaveRules.LIFE_PER_SECOND = 0.2
SaveRules.MAX_LIFE_SERIAL = 1000000000
SaveRules.MAX_LIFE_TOKEN_CHARS = 160
SaveRules.CLIENT_LIFE_GAP = 5 -- retry one idempotent retirement intent until durable acknowledgement
SaveRules.PROTOCOL = 2 -- the version of the messages between client and server
SaveRules.OFFER_PROTOCOL = 3 -- explicit opt-in; older peers keep protocol 2 behavior
SaveRules.RECOVERY_PROTOCOL = 1 -- additional opt-in, not implied by offer protocol 3
SaveRules.CLIENT_HELLO_GAP = 2.5 -- the client says hello again this often until the server answers
SaveRules.CLIENT_HELLO_TRIES = 6
SaveRules.CLIENT_PROGRESS_GAP = 2 -- the client sends at most one progress message in this time
SaveRules.CLIENT_EYE_GAP = 30 -- and re-sends the eye-view seconds this often when they changed
SaveRules.CLIENT_WAIT_REMOTES = 1.5 -- the start menu waits this long for the server's remotes to appear
SaveRules.CLIENT_WAIT_REPLY = 4 -- and this long for the first reply after saying hello

-- ---------------------------------------------------------------- words for statuses
SaveRules.STATUS = { saved = "saved", saving = "saving", session = "session" } -- session: this visit only
SaveRules.REASONS = { "offline", "no_api", "load_failed", "other_session", "corrupt", "newer", "write_failed", "rest_refused", "rest_protected" } :: { string }

-- The slot a life's rests are filed in: free play's own, the main life on the gentle rules (Easy) its own, and the standard main life the key it always had.
function SaveRules.slotOf(mode: string, rules: string): string
	if mode == "free" then return "free" end
	if rules == "gentle" then return "easy" end
	return "main"
end

return SaveRules

end)()
local Memory=(function()
--!strict
-- The in-memory store backend (ROBLOX-39): the same interface as the real DataStore backend, with a Roblox DataStore's rules (values
-- copied in and out, only storable values, the size limit, UpdateAsync that may call its function more than once) and a way to make it
-- fail in every way the tests need. It is what the CLI tests run on and what a build without DataStore access falls back to (a session
-- that lasts as long as the server).
-- Interface (a backend is any table with these):
--   backend:read(key)              -> ok: boolean, value: any, err: string?
--   backend:update(key, transform) -> ok: boolean, value: any, err: string?     transform(old) returns the new value, or nil to cancel
-- A cancelled update is ok with value nil. Neither raises.
-- Faults: backend:fail{ op = "read"|"update"|"any", key = "<key or prefix*>"?, times = n?, message = "...", afterWrite = true? }. A fault with
-- afterWrite lets the write happen and then reports an error (a timeout that did not mean the write was lost). backend:poke(key, value) sets
-- a raw value (corrupt JSON, a half-written record). `backend.log` lists every request: { op, key, ok }.
local Json = Json
local SaveRules = Rules

local MemoryBackend = {}
MemoryBackend.__index = MemoryBackend

export type Fault = { op: string, key: string?, times: number, message: string, afterWrite: boolean? }

function MemoryBackend.new(): any
	return setmetatable({ data = {} :: { [string]: any }, faults = {} :: { Fault }, log = {} :: { any }, requests = 0, writes = 0, clock = 0 }, MemoryBackend)
end

function MemoryBackend.fail(self: any, fault: { [string]: any })
	table.insert(self.faults, { op = fault.op or "any", key = fault.key, times = fault.times or 1, message = fault.message or "503: the service is unavailable", afterWrite = fault.afterWrite })
end

function MemoryBackend.clearFaults(self: any)
	self.faults = {}
end

function MemoryBackend.poke(self: any, key: string, value: any)
	self.data[key] = value
end

local function matches(pattern: string?, key: string): boolean
	if pattern == nil then return true end
	if string.sub(pattern, -1) == "*" then return string.sub(key, 1, #pattern - 1) == string.sub(pattern, 1, #pattern - 1) end
	return pattern == key
end

-- The first live fault for this request, used up by one.
local function takeFault(self: any, op: string, key: string): Fault?
	for i, f in self.faults do
		if (f.op == "any" or f.op == op) and matches(f.key, key) and f.times > 0 then
			f.times -= 1
			if f.times == 0 then table.remove(self.faults, i) end
			return f
		end
	end
	return nil
end

function MemoryBackend.read(self: any, key: string): (boolean, any, string?)
	self.requests += 1
	local f = takeFault(self, "read", key)
	if f then
		table.insert(self.log, { op = "read", key = key, ok = false })
		return false, nil, f.message
	end
	table.insert(self.log, { op = "read", key = key, ok = true })
	return true, Json.copy(self.data[key]), nil
end

function MemoryBackend.update(self: any, key: string, transform: (any) -> any): (boolean, any, string?)
	self.requests += 1
	local f = takeFault(self, "update", key)
	if f and not f.afterWrite then
		table.insert(self.log, { op = "update", key = key, ok = false })
		return false, nil, f.message
	end
	local okT, new = pcall(transform, Json.copy(self.data[key]))
	if not okT then
		table.insert(self.log, { op = "update", key = key, ok = false })
		return false, nil, "the update function raised: " .. tostring(new)
	end
	if new == nil then
		table.insert(self.log, { op = "update", key = key, ok = true, cancelled = true })
		return true, nil, nil
	end
	local text, why = Json.canonical(new)
	if not text then
		table.insert(self.log, { op = "update", key = key, ok = false })
		return false, nil, "104: Cannot store this value: " .. tostring(why)
	end
	if #text > SaveRules.MAX_VALUE_CHARS then
		table.insert(self.log, { op = "update", key = key, ok = false })
		return false, nil, `105: the value is {#text} characters, over the limit`
	end
	self.data[key] = Json.copy(new)
	self.writes += 1
	if f and f.afterWrite then
		table.insert(self.log, { op = "update", key = key, ok = false, wrote = true })
		return false, nil, f.message
	end
	table.insert(self.log, { op = "update", key = key, ok = true })
	return true, Json.copy(new), nil
end

return MemoryBackend

end)()
local Scheduler=(function()
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
local SaveRules = Rules

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

end)()
local Worker=(function()
--!strict
-- Private bridge for a polled worker. One lane is owned by the server/account
-- visit, not by this job. The owner must route ALL provider work through it.
local Facade=Facade
local Worker={};Worker.__index=Worker
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
function Worker.new(session:any,job:any,lane:any,maxRequests:number,guard:()->boolean):any
 assert(type(lane)=="table" and getmetatable(lane)==nil,"trusted plain admission lane required")
 local gate,scope=lane.gate,lane.scope
 assert(gate:live(scope) and gate:legacyReady(scope) and scope.actor==tostring(session.cfg.userId) and scope.epoch==session.id,"seeded physical account visit required")
 local self:any=setmetatable({session=session,job=job,gate=gate,scope=scope,backend=session.backend,scheduler=session.sched,
  counters=session.counters,id=session.id,user=tostring(session.cfg.userId),maxRequests=maxRequests,guard=guard,closed=false,starts=0},Worker)
 local methods={}
 for _,name in {"readFresh","readRawFresh","update"} do methods[name]=session.backend[name];assert(type(methods[name])=="function","backend method required") end
 local function valid():boolean
  if self.closed or not gate:live(scope) then return false end
  local okay,live=pcall(guard)
  return okay and live==true and not self.closed and gate:live(scope) and session.backend==self.backend and session.sched==self.scheduler
   and session.counters==self.counters and session.id==self.id and tostring(session.cfg.userId)==self.user
 end
 self.valid=valid
 local wrapped={}
 for _,name in {"readFresh","readRawFresh","update"} do
  wrapped[name]=function(_backend:any,key:string,transform:any):...any
   local now=session.now()
   if not finite(now) or not valid() or job.requests>=maxRequests then error("worker scope/cap changed before provider",0) end
   -- No external callback between accounting and the captured backend method.
   self.scheduler:begin(nil,now);self.counters.requests+=1;job.requests+=1;self.starts+=1
   local returned
   if name=="update" then
    returned=table.pack(pcall(methods[name],self.backend,key,function(old:any):any
     if not valid() then return nil end
     local value=transform(old)
     if not valid() then return nil end
     return value
    end))
   else
    returned=table.pack(pcall(methods[name],self.backend,key))
   end
   -- A provider exception is an actual failed attempt. Preserve the worker's
   -- existing retry/backoff path rather than treating it as an admission denial.
   if not returned[1] then return false,nil,tostring(returned[2]) end
   return table.unpack(returned,2,returned.n)
  end
 end
 self.facade=Facade.new(gate,scope,wrapped)
 return self
end
function Worker.cancel(self:any)
 self.closed=true
 if self.handle then self.facade:cancel(self.handle);self.handle=nil end
end
function Worker.poll(self:any,method:string,key:string,transform:any):(string,any?,boolean)
 if not self.valid() then self:cancel();return "cancelled",nil,false end
 if self.handle and (self.method~=method or self.key~=key or self.transform~=transform) then self:cancel();return "failed",nil,false end
 if not self.handle then
  local handle=self.facade:begin(method,key,transform)
  if not handle then return "failed",nil,false end
  self.handle,self.method,self.key,self.transform=handle,method,key,transform
 end
 local before=self.starts
 local state,result=self.facade:step(self.handle)
 local asked=self.starts>before
 if state~="waiting" then self.handle=nil end
 if not self.valid() then self:cancel();return "cancelled",nil,asked end
 if state=="done" then return state,result,asked end
 return state,nil,asked
end
return table.freeze(Worker)

end)()
do
local Gate=Admission
local Worker=Worker


local checks,groups=0,0
local function check(ok,why) assert(ok,why);checks+=1 end
local function test(name,fn) local before=checks;fn();groups+=1;print("BRIDGE_CASE",name,checks-before) end
local function fixture(override)
 local clock={now=100};local budget={read=80,write=80};local live={value=true}
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read
 if override then override(b) end
 local s={cfg={userId="a"},id="visit",backend=b,sched=Scheduler.new(),counters={requests=0},now=function() return clock.now end}
 local g=Gate.new({now=s.now,available=function() return budget end,actorRead=20,actorWrite=20,serverRead=40,serverWrite=40,headroom=0})
 local scope=assert(g:open("a","visit"));assert(g:importLegacy(scope,{}));local j={requests=0}
 local w=Worker.new(s,j,{gate=g,scope=scope},2,function() return live.value end)
 return b,s,j,g,scope,w,live,clock,budget
end
test("job-cap-and-backend-error-tuple",function()
 local b,s,j,g,scope,w=fixture()
 b:fail({op="read",key="x",times=1,message="503: failed"})
 local state,result,asked=w:poll("readRawFresh","x",nil)
 check(state=="done" and result[1]==false and result[3]=="503: failed" and asked,"backend failure tuple was changed to admission success/failure")
 check(j.requests==1 and s.counters.requests==1 and #s.sched.started==1,"backend failure not accounted")
 state,result,asked=w:poll("readRawFresh","x",nil)
 check(state=="done" and result[1]==true and asked and j.requests==2,"second request did not start")
 local before=b.requests;state,result,asked=w:poll("readRawFresh","x",nil)
 check(state=="failed" and not asked and b.requests==before and j.requests==2,"worker cap did not refuse before provider")
end)
test("transform-retry-lifetime-fences",function()
 local transformCalls=0;local liveRef=nil;local candidates={}
 local b,s,j,g,scope,w,live=fixture(function(store)
  store.update=function(self,key,fn)
   candidates[1]=fn({old=true});candidates[2]=fn({old=true});return true,candidates[2],nil
  end
 end)
 liveRef=live
 local state,result,asked=w:poll("update","x",function(old)
  transformCalls+=1;liveRef.value=false;return {new=true}
 end)
 check(transformCalls==1 and candidates[1]==nil and candidates[2]==nil,"invalid transform escaped on first result/retry")
 check(state=="cancelled" and result==nil and asked and j.requests==1,"invalid update exposed result or lost debt")
 check(g:inspect().read==1 and g:inspect().write==1,"update not charged as both types")
end)
test("committed-write-cancelled-before-ack",function()
 local b,s,j,g,scope,w,live=fixture(function(store)
  local update=store.update
  store.update=function(self,key,fn)
   local returned=table.pack(update(self,key,fn));coroutine.yield("committed");return table.unpack(returned,1,returned.n)
  end
 end)
 local output=nil
 local co=coroutine.create(function() output=table.pack(w:poll("update","x",function() return {saved=true} end)) end)
 local okay,why=coroutine.resume(co)
 check(okay and why=="committed" and b.data.x.saved and j.requests==1,"write not committed before suspended acknowledgement")
 w:cancel();g:close(scope);check(g:open("a","next")==nil,"new owner started before committed write drained")
 check(coroutine.resume(co) and coroutine.status(co)=="dead","write acknowledgement did not drain")
 check(output[1]=="cancelled" and output[2]==nil and output[3]==true and b.data.x.saved,"cancel either exposed success or pretended to roll back storage")
 check(g:inspect().read==1 and g:inspect().write==1 and g:open("a","next")~=nil,"commit debt lost/replacement blocked after drain")
end)
test("pending-identity-and-method-capture",function()
 local b,s,j,g,scope,w,live,clock,budget=fixture()
 budget.read=0
 local state=w:poll("readRawFresh","x",nil);check(state=="waiting" and g:inspect().queued==1,"request was not queued")
 state=w:poll("readRawFresh","y",nil)
 check(state=="failed" and b.requests==0 and g:inspect().queued==0,"changed pending key silently reused ticket")
 local b2,s2,j2,g2,scope2,w2=fixture()
 b2.readRawFresh=function() error("mutated method ran") end
 local state2,result=w2:poll("readRawFresh","x",nil)
 check(state2=="done" and result[1]==true and j2.requests==1,"provider method was rebound after construction")
end)
test("counter-replacement-and-invalid-account-scope",function()
 local b,s,j,g,scope,w=fixture()
 s.counters={requests=0};local state,result,asked=w:poll("readRawFresh","x",nil)
 check(state=="cancelled" and not asked and b.requests==0,"counter ownership change was ignored")
 local other=assert(g:open("other","visit"));assert(g:importLegacy(other,{}))
 check(not pcall(Worker.new,s,j,{gate=g,scope=other},2,function() return true end),"foreign actor scope accepted")
end)
test("thrown-provider-is-a-counted-retryable-failure",function()
 local b,s,j,g,scope,w=fixture(function(store) store.readRawFresh=function() error("503: thrown provider",0) end end)
 local state,result,asked=w:poll("readRawFresh","x",nil)
 check(state=="done" and result and result[1]==false and result[3]=="503: thrown provider","provider exception lost the backend failure/backoff path")
 check(asked and j.requests==1 and s.counters.requests==1,"throwing provider was not charged")
 check(g:inspect().read==1 and g:inspect().write==0,"throwing read spent the wrong budget")
end)
print("ADMISSION_BRIDGE passed="..checks.." failed=0 groups="..groups)
end

local Startup=(function()
--!strict
-- Private bounded startup lane. One shared owner per server; never changes
-- platform rate limits or permissions, and never grants storage authority.
local Rules=Rules
local Work=Work
local Budget={};Budget.__index=Budget
local Ticket={};Ticket.__index=Ticket
local function finite(v:any):boolean return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function recent(list:any,now:number):any
 local out={};for _,time in list do if now-time<60 then table.insert(out,time) end end;return out
end
function Budget.new(query:any?,now:any,options:any?):any
 local cfg=options or {};local perSession=cfg.perSession or 20;local shared=cfg.shared or 40;local duration=cfg.duration or 45
 assert((query==nil or type(query)=="function") and type(now)=="function","server budget observer and clock required")
 assert(finite(perSession) and perSession>=1 and perSession<=20 and perSession%1==0 and finite(shared) and shared>=1 and shared<=40 and shared%1==0
  and finite(duration) and duration>=1 and duration<=45,"invalid startup bounds")
 return setmetatable({query=query,now=now,perSession=perSession,shared=shared,duration=duration,started={},users={},sampleAt=-math.huge,
  read=0,write=0,queries=0,granted=0,serial=0,lastNow=-math.huge},Budget)
end
function Budget.engine(now:any):any
 local ok,service,readType,writeType=pcall(function()
  local enums:any=Enum.DataStoreRequestType
  return game:GetService("DataStoreService"),enums.StandardRead,enums.StandardWrite
 end)
 local query=nil
 if ok and readType~=nil and writeType~=nil then
  query=function() return service:GetRequestBudgetForRequestType(readType),service:GetRequestBudgetForRequestType(writeType) end
 end
 return Budget.new(query,now)
end
function Ticket.close(self:any,reason:string?,success:boolean?):boolean
 if self.closed then return false end
 self.closed,self.reason,self.success=true,reason or "startup ended",success==true
 if not success then
  for _,time in self.startup do table.insert(self.normal,time) end -- failed/cancelled startup keeps its ordinary debt
 end
 return true
end
local function valid(t:any,now:number):boolean
 if t.closed then return false end
 local s=t.session;local rt=t.runtime
 if not finite(now) or now<t.lastNow or now>=t.deadline or rt.startup~=t or rt.leaving or rt.intakeClosed or rt.scopeInvalid or s.closed or s.flushing
  or s.backend~=t.backend or s.backend.source~=t.source or s.backend.source~=s.backend.boundSource or s.backend.boundSession~=s
  or s.sched~=t.scheduler or s.id~=t.id or tostring(s.cfg.userId)~=t.user or s.pkey~=t.key or s.intents~=t.intents then
  t:close("startup scope/clock/deadline ended");return false
 end
 if t.load==nil and rt.loading and s._loadSerial==1 then t.load=1 end
 if t.load~=nil and s._loadSerial~=t.load then t:close("startup load epoch changed");return false end
 for _,r in s.intents.requests do if r.state=="writable" then t:close("life already writable");return false end end
 for _,r in s.lifeRequests do if r.done then t:close("legacy life already writable");return false end end
 t.lastNow=now
 return rt.phase=="normal" and rt.loading==true and s._loadSerial==1
  or s.state=="active" and (rt.phase=="discovering" or rt.phase=="offered" or rt.phase=="entry_required" or rt.phase=="entering")
end
local function sample(self:any,now:number):boolean
 if now-self.sampleAt<.25 then return self.read>=5 and self.write>=5 end
 self.sampleAt=now;self.read,self.write=0,0;self.queries+=1
 if self.query==nil then return false end
 -- The engine observer is non-yielding. Reject a misconfigured yielding probe
 -- rather than introducing a yield between a caller's guard and its request.
 local co=coroutine.create(self.query);local ok,r,w=coroutine.resume(co)
 if coroutine.status(co)~="dead" then coroutine.close(co);return false end
 if not ok or not finite(r) or not finite(w) or r<0 or w<0 then return false end
 self.read,self.write=r,w;return r>=5 and w>=5
end
local function admitted(t:any,now:number):boolean
 if Work.pulse() or not valid(t,now) then return false end
 local self=t.gate;local serverNow=self.now()
 if not finite(serverNow) or serverNow<self.lastNow or serverNow<now or serverNow-now>1 then return false end
 self.lastNow=serverNow;self.started=recent(self.started,now)
 for user,record in self.users do if now-record.at>=60 then self.users[user]=nil end end
 if t.used>=self.perSession or #self.started>=self.shared or self.users[t.user] and self.users[t.user].serial~=t.serial then return false end
 return sample(self,now) and valid(t,now)
end
function Budget.attach(self:any,rt:any):any
 local s=rt.session;local sched=s.sched;local now=s.now()
 assert(not Work.pulse() and finite(now) and s.backend.boundSession==s and s.state=="loading" and s._loadSerial==nil
  and s.counters.requests==0 and #sched.started==0 and sched._recoveryStartup==nil and rt.startup==nil,"attach once before initial load")
 self.serial+=1
 local t:any=setmetatable({gate=self,serial=self.serial,runtime=rt,session=s,scheduler=sched,backend=s.backend,source=s.backend.source,id=s.id,user=tostring(s.cfg.userId),key=s.pkey,intents=s.intents,
  born=now,lastNow=now,deadline=now+self.duration,normal={},startup={},used=0,closed=false,normalRequests=0,startupRequests=0,forcedRequests=0},Ticket)
 local begin=sched.begin
 sched._recoveryStartup=t;rt.startup=t
 sched.budgetOk=function(_scheduler:any,time:number):boolean
  if _scheduler~=sched or not finite(time) or Work.pulse() then return false end
  t.normal=recent(t.normal,time);sched.started=recent(sched.started,time)
  if valid(t,time) then return admitted(t,time) or #sched.started<Rules.REQUESTS_PER_MINUTE end
  t.normal=recent(t.normal,time);return #t.normal<Rules.REQUESTS_PER_MINUTE
 end
 sched.begin=function(_scheduler:any,name:any,time:number):number
  assert(_scheduler==sched and finite(time),"finite owned scheduler request required")
  t.normal=recent(t.normal,time);sched.started=recent(sched.started,time)
  if admitted(t,time) then
   t.used+=1;t.startupRequests+=1;self.granted+=1;table.insert(self.started,time);table.insert(t.startup,time)
   t.firstStartupAt=t.firstStartupAt or time;self.users[t.user]={serial=t.serial,at=t.firstStartupAt}
   self.read-=1;self.write-=1 -- conservative worst case: UpdateAsync uses both
  else
   if (valid(t,time) and #sched.started>=Rules.REQUESTS_PER_MINUTE) or #t.normal>=Rules.REQUESTS_PER_MINUTE then t.forcedRequests+=1 end
   t.normalRequests+=1;table.insert(t.normal,time)
  end
  return begin(sched,name,time) -- retain the complete request history and dirty versions
 end
 return t
end
return table.freeze(Budget)

end)()
do
local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read
local s={cfg={userId="a"},id="startup-visit",backend=b,sched=Scheduler.new(),counters={requests=0},now=function() return 100 end,
 state="loading",intents={requests={}},lifeRequests={},pkey="P_a"}
b.source=b;b.boundSource=b;b.boundSession=s
local rt={session=s,phase="normal",loading=true};local live=true
local startup=Startup.new(function() live=false;return 80,80 end,s.now)
local startupTicket=startup:attach(rt);s._loadSerial=1
local gate=Admission.new({now=s.now,available=function() return {read=80,write=80} end,actorRead=20,actorWrite=20,serverRead=40,serverWrite=40,headroom=0})
local scope=assert(gate:open("a",s.id));assert(gate:importLegacy(scope,s.sched.started))
local j={requests=0};local worker=Worker.new(s,j,{gate=gate,scope=scope},4,function() return live end)
local state,result,asked=worker:poll("readRawFresh","x",nil)
assert(b.requests==0,"actual startup scheduler cancellation still started a provider")
assert(state=="cancelled" and result==nil and not asked and j.requests==0 and s.counters.requests==0,"actual startup callback produced a request/result")
assert(startupTicket.startupRequests==1 and startup.granted==1 and #s.sched.started==1,"actual startup wrapper was not exercised")
assert(gate:inspect().history==1 and gate:inspect().started==0,"ended startup dispatch refunded debt or failed to drain")
print("STARTUP_DISPATCH_GUARD passed=4 failed=0 groups=1 actual_startup_wrapper=true")
end
