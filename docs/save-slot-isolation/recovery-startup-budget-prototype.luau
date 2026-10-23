--!strict
-- Private bounded startup lane. One shared owner per server; never changes
-- platform rate limits or permissions, and never grants storage authority.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Work=require(Shared.Persistence.SaveWork)
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
