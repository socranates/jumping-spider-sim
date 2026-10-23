--!strict
-- Server-owned account visits. Closed initial-load cleanup has metadata-only
-- authority over its captured P key; no session is reopened for cleanup.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Rest=require(Shared.Persistence.SaveRest)
local Scheduler=require(Shared.Persistence.SaveScheduler)
local Stores=require(Shared.Persistence.SaveStores)
local Operation=require(Shared.Persistence.RecoveryOperationAdmission)
local Ordinary=require(Shared.Persistence.OrdinaryRequestAdmission)
local Accounts={};Accounts.__index=Accounts
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function enabled(fn:any):boolean local ok,value=pcall(fn);return ok and value==true end
function Accounts.new(gate:any,config:any):any
 assert(type(config)=="table" and type(config.now)=="function" and type(config.sleep)=="function" and type(config.legacyHistory)=="function",
  "trusted account clock, cooperative sleep and complete legacy history required")
 return setmetatable({gate=gate,now=config.now,sleep=config.sleep,history=config.legacyHistory,visits={},closing=false},Accounts)
end
local function finish(self:any,v:any,released:boolean?,problem:string?)
 if v.closed then return end
 if v.cleanup and v.cleanup.io then v.cleanup.io:cancel();v.cleanup.io=nil end
 self.gate:close(v.scope);v.closed,v.closedAt,v.problem=true,self.now(),problem
 if v.owner then
  local s,rt=v.owner.session,v.owner.runtime
  v.owner.closed=true;Ordinary.stop(s)
  s.closed,s.flushing=true,false;rt.leaving,rt.phase=true,"closed"
  if released then s.lockHeld=false end
  if v.cancelled then rt.result={initialLoadCancelled=true,leaseReleased=released==true,progressPreserved=false,sessionClosed=true,gameplayAuthorized=false} end
 end
end
function Accounts.open(self:any,user:any,id:string,source:any,live:any):any
 assert(type(live)=="function" and type(source)=="table","trusted visit source and guard required")
 local key=tostring(user);local now=self.now();assert(finite(now),"finite account clock required")
 local last,deadline=now,now+180
 while true do
  now=self.now();assert(finite(now) and now>=last and now<deadline and not self.closing and enabled(live),"account construction ended")
  last=now
  -- Closed diagnostics are not the debt ledger. Drop their registry rows;
  -- Gate retains physical history and in-flight calls independently.
  for actor,v in self.visits do if v.closed then self.visits[actor]=nil end end
  local scope,why=self.gate:open(key,id)
  if scope then
   local v={user=key,id=id,source=source,scope=scope,lane={gate=self.gate,scope=scope},guard=live,closed=false}
   self.visits[key]=v
   if not self.gate:legacyReady(scope) then
    v.seeding=true
    local ok,history=pcall(self.history,key)
    v.seeding=false
    if not ok or not self.gate:live(scope) then finish(self,v,false,"legacy import scope ended");error("legacy import scope ended",0) end
    -- A cancelled constructor still owes its complete known history. No
    -- provider can start before this seed, and cancellation cannot erase it.
    local seeded,problem=self.gate:importLegacy(scope,history)
    if not seeded then finish(self,v,false,tostring(problem));error(problem,0) end
   end
   if self.closing or not enabled(live) or not self.gate:live(scope) then finish(self,v,false,"account construction ended");error("account construction ended",0) end
   return v
  end
  assert(why=="actor already has an open visit" or why=="previous provider must drain" or why=="actor capacity retains recent debt",why)
  self.sleep(math.min(.025,math.max(0,deadline-now)))
 end
end
function Accounts.failed(self:any,v:any)
 if v and not v.closed then
  if v.owner then
   assert(v.session.state=="loading" and v.session.counters.requests==0,"failed constructor performed storage work")
   v.owner.closed,v.session.closed,v.owner.runtime.leaving,v.owner.runtime.phase=true,true,true,"closed"
  end
  finish(self,v,false,"constructor failed or was cancelled")
 end
end
local function identity(self:any,v:any):boolean
 local s=v.session;local owner=v.owner
 return not v.closed and self.visits[v.user]==v and self.gate:live(v.scope) and s~=nil and owner.session==s and owner.runtime.session==s
  and s.id==v.id and tostring(s.cfg.userId)==v.user and s.backend==v.backend and s.sched==v.scheduler and s.counters==v.counters
  and s.pkey==v.key and v.backend.source==v.source and v.backend.source==v.backend.boundSource
  and s.sched.begin==Scheduler.begin and s.sched.budgetOk==Scheduler.budgetOk and s.sched._recoveryStartup==nil
end
local function cleanable(self:any,v:any):boolean
 local s=v.session;local now=self.now()
 return identity(self,v) and v.cancelled and s.closed and v.owner.runtime.leaving and finite(now) and now>=v.lastNow and now<v.deadline
end
local function own(self:any,v:any,raw:any):(boolean,boolean)
 local s=v.session
 if Rest.bounded(raw,Rules.MAX_PROGRESS_NODES*2+64,Rules.MAX_DEPTH+2) then return false,false end
 local op=Envelope.open(s.pspec,raw,false)
 if op.status=="missing" then return true,false end
 if op.status~="ok" and op.status~="migrated" then return false,false end
 return true,type(op.lock)=="table" and op.lock.session==v.id
end
local function cleanup(self:any,v:any)
 if v.closed then return end
 local s=v.session
 if not identity(self,v) then finish(self,v,false,"cancelled load routing changed");return end
 while s.busy or v.backend.activeUpdates>0 or s._ordinaryContext and s._ordinaryContext.phase~="done" do
  if not cleanable(self,v) then finish(self,v,false,"cancelled provider drain deadline");return end
  v.lastNow=self.now();self.sleep(math.min(.025,math.max(0,v.deadline-v.lastNow)))
 end
 Ordinary.quiesce(s)
 if s.counters.requests==0 then finish(self,v,true);return end
 local j:any={requests=0,phase="probe",failures=0,nextAt=self.now()};v.cleanup=j
 -- The actual DataStoreBackend preserves P envelopes without its R codec.
 -- Capture that progress updater and a raw uncached read; bindings reject
 -- every key except this visit's P key. There is no R/raw-write fallback.
 local source=v.source;local update,read=source.update,source.readRawFresh
 if type(update)~="function" or type(read)~="function" then finish(self,v,false,"closed load requires explicit progress update/fresh raw adapters");return end
 while cleanable(self,v) and j.requests<6 do
  local now=self.now();v.lastNow=now
  if now<j.nextAt then self.sleep(math.min(.025,math.max(0,math.min(j.nextAt,v.deadline)-now)));continue end
  if not j.io then
   local function guard():boolean return cleanable(self,v) end
   j.io=Operation.new(s,v.lane,guard,{{object=j,field="requests",max=6}},
    {update={object=source,fn=function(_source:any,key:string,transform:any):...any
     if key~=v.key then return false,nil,"closed cleanup key differs" end
     return update(source,key,transform)
    end},readRawFresh={object=source,fn=function(_source:any,key:string):...any
     if key~=v.key then return false,nil,"closed cleanup key differs" end
     return read(source,key)
    end}})
   if j.phase=="release" then
    j.transform=function(old:any):any
     local valid,owned=own(self,v,old)
     if not valid or not owned then return nil end
     return Envelope.withLock(old,nil)
    end
   end
  end
  local method=if j.phase=="release" then "update" else "readRawFresh"
  local io=j.io;local state,result=io:poll(method,v.key,j.transform)
  if v.closed or j.io~=io then io:cancel();return end
  if state=="waiting" then self.sleep(math.min(.025,math.max(0,v.deadline-self.now())));continue end
  j.io:cancel();j.io=nil;j.transform=nil
  if state~="done" then finish(self,v,false,"cancelled cleanup request ended");return end
  if j.phase=="release" then
   -- An ambiguous update always gets a fresh probe before another write.
   j.phase="verify"
  elseif result[1]==true then
   local valid,owned=own(self,v,result[2])
   if not valid then finish(self,v,false,"closed cleanup found protected/corrupt progress");return end
   if not owned then finish(self,v,true);return end
   j.phase="release"
  else
   j.failures+=1;j.nextAt=self.now()+Scheduler.backoff(j.failures,Stores.classify(tostring(result[3])))
  end
 end
 finish(self,v,false,"closed cleanup deadline or request cap")
end
function Accounts.cancel(self:any,user:any,id:string,deadline:number?)
 local v=self.visits[tostring(user)]
 if not v or v.id~=id or v.closed then return end
 if not v.owner then
  if v.seeding then v.cancelled=true else finish(self,v,false,"constructor cancelled") end
  return
 end
 local now=self.now();local limit=deadline or now+Rules.FLUSH_DEADLINE
 assert(finite(now) and finite(limit),"finite cancellation deadline required")
 if v.cancelled then v.deadline=math.min(v.deadline,limit);return end
 v.cancelled,v.lastNow,v.deadline=true,now,math.min(limit,now+Rules.FLUSH_DEADLINE)
 local s=v.session;s.closed=true;s._loadSerial=(s._loadSerial or 0)+1;v.owner.runtime.leaving=true
 Ordinary.stop(s)
end
function Accounts.bind(self:any,v:any,owner:any)
 assert(not self.closing and not v.closed and self.visits[v.user]==v and enabled(v.guard) and self.gate:legacyReady(v.scope),"live account construction required")
 local s=owner.session
 assert(s.state=="loading" and s.counters.requests==0 and s.id==v.id and tostring(s.cfg.userId)==v.user and s.ordinaryAdmission==v.lane
  and s.backend.source==v.source and s.backend.source==s.backend.boundSource,"unloaded owner must retain physical account lane")
 v.owner,v.session,v.backend,v.scheduler,v.counters,v.key=owner,s,s.backend,s.sched,s.counters,s.pkey
 assert(s.sched.begin==Scheduler.begin and s.sched.budgetOk==Scheduler.budgetOk and s.sched._recoveryStartup==nil,"retire startup scheduler wrappers before account binding")
 local load,flush=owner.load,owner.flush
 owner.cancelLoading=function(_owner:any,deadline:number?) self:cancel(v.user,v.id,deadline) end
 owner.load=function(_owner:any,...:any):...any
  if v.cancelled or v.closed then if not v.closed then cleanup(self,v) end;return s.state,false end
  local result=table.pack(pcall(load,owner,...))
  if v.cancelled then cleanup(self,v) end
  if not result[1] then error(result[2],0) end
  return table.unpack(result,2,result.n)
 end
 owner.flush=function(_owner:any,deadline:number?)
  if v.closed then return end
  if v.cancelled then cleanup(self,v);return end
  local result=table.pack(pcall(flush,owner,deadline))
  finish(self,v,nil,if result[1] then nil else tostring(result[2]))
  if not result[1] then error(result[2],0) end
 end
end
function Accounts.closeIntake(self:any) self.closing=true end
function Accounts.finishShutdown(self:any)
 assert(self.closing,"close account intake before finishing shutdown")
 for _,v in self.visits do if not v.closed then finish(self,v,false,"shutdown ended with pending account visit") end end
end
return table.freeze(Accounts)
