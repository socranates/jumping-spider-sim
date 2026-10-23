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

end)()
local Facade=(function()
--!strict
-- Private polling facade. Waiting for admission makes no provider request and
-- does not impersonate a failed DataStore attempt. Existing backend transform
-- and physical-lease fences remain required underneath this additional guard.
local Facade={};Facade.__index=Facade
local kinds={readFresh="read",readRawFresh="read",update="update"}
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
 for _,v in {false,{read=0/0,write=100},{read=math.huge,write=100},{read=-1,write=100},{read="100",write=100}} do
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
